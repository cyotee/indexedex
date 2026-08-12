// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {
    TokenInfo, TokenType
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";

import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";
import {ResearchTelemetry} from "scripts/foundry/research/harness/ResearchTelemetry.sol";

/**
 * @title DualLiquidityV4Swapper
 * @notice Research-only V4 exact-in swap via PoolManager unlock callback.
 */
contract DualLiquidityV4Swapper is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;

    IPoolManager internal immutable poolManager;

    constructor(IPoolManager poolManager_) {
        poolManager = poolManager_;
    }

    /// @dev `amountIn` exact-in of tokenIn; zeroForOne if tokenIn is currency0.
    function swapExactIn(PoolKey memory key_, address tokenIn_, uint256 amountIn_) external {
        bool zeroForOne = tokenIn_ == Currency.unwrap(key_.currency0);
        poolManager.unlock(abi.encode(key_, zeroForOne, amountIn_, msg.sender));
    }

    function unlockCallback(bytes calldata data_) external returns (bytes memory) {
        require(msg.sender == address(poolManager), "not pm");
        (PoolKey memory key_, bool zeroForOne_, uint256 amountIn_, address payer_) =
            abi.decode(data_, (PoolKey, bool, uint256, address));

        BalanceDelta delta = poolManager.swap(
            key_,
            SwapParams({
                zeroForOne: zeroForOne_,
                amountSpecified: -int256(amountIn_),
                sqrtPriceLimitX96: zeroForOne_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            bytes("")
        );

        // Settle input (negative delta) from payer; take output to payer.
        _settle(key_.currency0, delta.amount0(), payer_);
        _settle(key_.currency1, delta.amount1(), payer_);
        return abi.encode(delta);
    }

    function _settle(Currency currency_, int128 amountDelta_, address payer_) internal {
        if (amountDelta_ < 0) {
            uint256 amt = uint128(-amountDelta_);
            poolManager.sync(currency_);
            address tok = Currency.unwrap(currency_);
            // Pull from payer into this contract then PM (payer approved this).
            IERC20(tok).transferFrom(payer_, address(this), amt);
            IERC20(tok).transfer(address(poolManager), amt);
            poolManager.settle();
        } else if (amountDelta_ > 0) {
            poolManager.take(currency_, payer_, uint128(amountDelta_));
        }
    }
}

/**
 * @title ResearchFixture_DualLiquidity
 * @notice Fork research harness for DualLiquidity Linked Cross-Version vault.
 * @dev Pure rates world via constructor flag → `PkgArgs.useRateProviders`.
 *
 * Residual formula (locked):
 *   midA = live[indexPair] * 1e18 / live[indexA]   // pair-leg live per vaultA-leg live
 *   midIndexA = midA_t / midA_0
 *   rateA = SE redeem lens for vaultA → commonToken (1e18 share preview), or pool RP when rates on
 *   rateIndexA = rateA_t / rateA_0
 *   residualA = midIndexA * rateIndexA / 1e18 - 1   (in 1e18 fixed-point: midIndex*rateIndex/1e18 - 1e18 then /1e18)
 *
 *   Under R+: mid tracks 1/rate ⇒ residualA ≈ 0.
 *   Under R−: mid freezes ⇒ residualA ≈ rateIndexA - 1 (sign depends on tilt).
 *
 * Share book mark (canonical full-value exit): previewExchangeIn(shares → reserve BPT).
 */
contract ResearchFixture_DualLiquidity is TestBase_DualLiquidityLinkedCrossVersionUniswapVault {
    /// @dev Pure-state rate policy for this instance (homogeneous three reserve legs).
    bool public immutable ratesOn;

    uint256 public constant TRADE_STEPS = 12;
    uint256 public constant TRADE_SIZE = 500e18; // modest Mode A exact-in on V4 common→tokenA
    uint256 public constant BOOK_DEPOSIT = 5_000e18; // commonToken into DualLiquidity after bootstrap

    uint256 public constant RESERVE_SWAP_FEE = 0.003e18; // package weighted-pool create fee

    DualLiquidityV4Swapper public swapper;
    address public researchAlice;

    // t0 baselines
    uint256 public initMidA;
    uint256 public initRateA;
    uint256 public initPortfolioBpt;
    uint256 public portfolio0Bpt;

    uint256 public step;
    uint8 public researchModeId; // 0=A, 1=B, 2=C
    /// @dev 1 = v1 residual/preview campaign; 2 = linked volume + share-book.
    uint8 public researchVersion = 1;
    bool public telemetryReady;
    ResearchTelemetry.RunPaths public runPaths;

    // Mode B last step fields
    uint256 public lastPreviewOut;
    uint256 public lastExecOut;
    string public lastRoute;

    // Volume attribution (v2): prev snapshot for step deltas
    uint256 public prevLiveVaultA;
    uint256 public prevLiveVaultB;
    uint256 public prevLivePairVault;
    uint256 public prevAliceShares;
    uint256 public prevDiamondBpt;

    /// @dev Locked attribution stack — reserve live SE shares + alice shares + diamond BPT.
    string public constant ATTRIBUTION_MODEL = "reserve_live_plus_alice_shares";

    constructor(bool ratesOn_) {
        ratesOn = ratesOn_;
    }

    function setResearchVersion(uint8 version_) external {
        researchVersion = version_;
    }

    /// @inheritdoc TestBase_DualLiquidityLinkedCrossVersionUniswapVault
    function _useRateProviders() internal view override returns (bool) {
        return ratesOn;
    }

    /// @dev Prevent Foundry auto-setUp on Script inheritance; call bootstrapResearch().
    function setUp() public virtual override {
        // intentionally empty
    }

    /**
     * @notice Full fork bootstrap: deploy DualLiquidity with constructor rates flag, bootstrap reserve,
     *         deposit research book for alice.
     */
    function bootstrapResearch() public {
        TestBase_DualLiquidityLinkedCrossVersionUniswapVault.setUp();
        _bootstrapReserve();
        swapper = new DualLiquidityV4Swapper(poolManager);

        // Endow alice with DualLiquidity shares via commonToken deposit.
        researchAlice = makeAddr("dlResearchAlice");
        vm.label(researchAlice, "dlResearchAlice");
        _depositCommon(researchAlice, BOOK_DEPOSIT);

        researchModeId = 0;
        telemetryReady = false;
    }

    function setResearchModeId(uint8 modeId_) external {
        researchModeId = modeId_;
    }

    /* ---------------------------------------------------------------------- */
    /*                         Reserve mid / residual                          */
    /* ---------------------------------------------------------------------- */

    function reservePool() public view returns (address) {
        return _reservePool();
    }

    function indexOfToken(address pool_, address token_) public view returns (uint256) {
        IERC20[] memory toks = vault.getPoolTokens(pool_);
        for (uint256 i = 0; i < toks.length; i++) {
            if (address(toks[i]) == token_) return i;
        }
        revert("dl research: token not in pool");
    }

    /// @notice midA = live[pairVault] * 1e18 / live[vaultA] (pair-leg per A-leg live units).
    function midA() public view returns (uint256) {
        address pool_ = _reservePool();
        uint256[] memory live = vault.getCurrentLiveBalances(pool_);
        uint256 iA = indexOfToken(pool_, _vaultAShare());
        uint256 iP = indexOfToken(pool_, _pairVaultShare());
        uint256 liveA = live[iA];
        uint256 liveP = live[iP];
        if (liveA == 0) return 0;
        return liveP * 1e18 / liveA;
    }

    function _vaultAShare() internal view returns (address) {
        // vaultA is the V4 SE for common/tokenA — its address is the share token
        address[] memory vt = IBasicVault(linkedVault).vaultTokens();
        // tokens: self, vaultA, vaultB, pairVault, reserve — order from product PRD
        // Prefer matching via pool membership
        address pool_ = _reservePool();
        IERC20[] memory legs = vault.getPoolTokens(pool_);
        // vaultA is the SE that accepts commonToken+tokenA; identify by trying which is not pair
        // Stable approach: read from first bootstrap — vaultA is V4 for poolKeyA
        // TestBase stores no public vaultA; recover as the pool token that is a V4 vault.
        // Convention from DFPkg: all three are SE shares. Use vaultTokens() indices 1,2,3.
        require(vt.length >= 5, "dl research: vaultTokens");
        return vt[1]; // vaultA
    }

    function _vaultBShare() internal view returns (address) {
        address[] memory vt = IBasicVault(linkedVault).vaultTokens();
        return vt[2];
    }

    function _pairVaultShare() internal view returns (address) {
        address[] memory vt = IBasicVault(linkedVault).vaultTokens();
        return vt[3];
    }

    /**
     * @notice SE rate lens for vaultA → commonToken: amount of commonToken out for 1e18 vaultA shares.
     * @dev When rates on, prefer Balancer rate provider on the pool token if non-zero; else preview redeem.
     *      When rates off, always use preview redeem (off-pool lens; not wired into TokenConfig).
     */
    function rateA() public view returns (uint256) {
        address pool_ = _reservePool();
        address shareA = _vaultAShare();
        if (ratesOn) {
            (, TokenInfo[] memory info,,) = vault.getPoolTokenInfo(pool_);
            uint256 iA = indexOfToken(pool_, shareA);
            if (address(info[iA].rateProvider) != address(0)) {
                return IRateProvider(address(info[iA].rateProvider)).getRate();
            }
        }
        // Off-pool / fallback: preview redeem 1e18 shareA → commonToken
        try IStandardExchangeIn(shareA).previewExchangeIn(IERC20(shareA), 1e18, commonToken) returns (uint256 out) {
            if (out > 0) return out;
        } catch {}
        return 1e18;
    }

    function midIndexA() public view returns (uint256) {
        require(telemetryReady && initMidA > 0, "dl research: no init mid");
        uint256 m = midA();
        if (m == 0) return 0;
        return m * 1e18 / initMidA;
    }

    function rateIndexA() public view returns (uint256) {
        require(telemetryReady && initRateA > 0, "dl research: no init rate");
        return rateA() * 1e18 / initRateA;
    }

    /// @notice residualA = midIndexA * rateIndexA / 1e18 - 1e18 (1e18 fixed-point residual).
    function residualA() public view returns (int256) {
        uint256 midI = midIndexA();
        uint256 rateI = rateIndexA();
        uint256 prod = midI * rateI / 1e18;
        return int256(prod) - int256(1e18);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Share book (BPT full exit)                      */
    /* ---------------------------------------------------------------------- */

    /// @notice Canonical full-value exit preview: DualLiquidity shares → reserve BPT amount.
    function markShareBookBpt(address who_) public view returns (uint256 bptOut) {
        uint256 sh = IERC20(linkedVault).balanceOf(who_);
        if (sh == 0) return 0;
        address pool_ = _reservePool();
        bptOut = IStandardExchangeIn(linkedVault).previewExchangeIn(IERC20(linkedVault), sh, IERC20(pool_));
    }

    /// @notice Alias for v2 share-book hero field name (same as markShareBookBpt).
    function markFullExit(address who_) public view returns (uint256) {
        return markShareBookBpt(who_);
    }

    /* ---------------------------------------------------------------------- */
    /*                    Volume attribution (v2 nested legs)                  */
    /* ---------------------------------------------------------------------- */

    /// @notice Reserve-pool live balance of vaultA SE share (attribution surface).
    function liveVaultA() public view returns (uint256) {
        return _liveOfShare(_vaultAShare());
    }

    function liveVaultB() public view returns (uint256) {
        return _liveOfShare(_vaultBShare());
    }

    function livePairVault() public view returns (uint256) {
        return _liveOfShare(_pairVaultShare());
    }

    function balAliceShares() public view returns (uint256) {
        return IERC20(linkedVault).balanceOf(researchAlice);
    }

    /// @notice Free reserve BPT held by DualLiquidity diamond (not alice's share claim).
    function balDiamondBpt() public view returns (uint256) {
        return _totalReserveBpt();
    }

    function _liveOfShare(address share_) private view returns (uint256) {
        address pool_ = _reservePool();
        uint256[] memory live = vault.getCurrentLiveBalances(pool_);
        return live[indexOfToken(pool_, share_)];
    }

    function _captureVolumePrev() private {
        prevLiveVaultA = liveVaultA();
        prevLiveVaultB = liveVaultB();
        prevLivePairVault = livePairVault();
        prevAliceShares = balAliceShares();
        prevDiamondBpt = balDiamondBpt();
    }

    /* ---------------------------------------------------------------------- */
    /*                              Mode A drive                               */
    /* ---------------------------------------------------------------------- */

    /// @notice Exact-in swap on V4 commonToken → tokenA market (tilts vaultA SE rate).
    function swapLegMarketA(uint256 amountIn_) public {
        PoolKey memory key = _poolKey(commonToken, tokenA);
        address bob_ = makeAddr("dlResearchBob");
        _fund(commonToken, bob_, amountIn_);
        vm.startPrank(bob_);
        commonToken.approve(address(swapper), amountIn_);
        swapper.swapExactIn(key, address(commonToken), amountIn_);
        vm.stopPrank();
    }

    /// @notice Optional V2 pair tilt (tokenA → tokenB).
    function swapPairV2(uint256 amountIn_) public {
        address bob_ = makeAddr("dlResearchBob");
        _fund(tokenA, bob_, amountIn_);
        vm.startPrank(bob_);
        tokenA.approve(address(v2Router), amountIn_);
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        v2Router.swapExactTokensForTokens(amountIn_, 0, path, bob_, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                              Mode B drive                               */
    /* ---------------------------------------------------------------------- */

    /// @notice Deposit commonToken → DualLiquidity shares; records preview vs exec.
    function depositCommonRoute(address who_, uint256 amountIn_) public returns (uint256 execOut_) {
        lastRoute = "deposit_common";
        lastPreviewOut = IStandardExchangeIn(linkedVault).previewExchangeIn(commonToken, amountIn_, IERC20(linkedVault));
        _fund(commonToken, who_, amountIn_);
        vm.startPrank(who_);
        commonToken.approve(linkedVault, amountIn_);
        execOut_ = IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, amountIn_, IERC20(linkedVault), 0, who_, false, block.timestamp
        );
        vm.stopPrank();
        lastExecOut = execOut_;
    }

    /// @notice Mode B helper: deposit as the research alice book.
    function depositCommonAlice(uint256 amountIn_) external returns (uint256) {
        return depositCommonRoute(researchAlice, amountIn_);
    }

    /// @notice Deposit tokenA → DualLiquidity shares (linked-token route).
    function depositTokenARoute(address who_, uint256 amountIn_) public returns (uint256 execOut_) {
        lastRoute = "deposit_tokenA";
        lastPreviewOut =
            IStandardExchangeIn(linkedVault).previewExchangeIn(tokenA, amountIn_, IERC20(linkedVault));
        _fund(tokenA, who_, amountIn_);
        vm.startPrank(who_);
        tokenA.approve(linkedVault, amountIn_);
        execOut_ = IStandardExchangeIn(linkedVault).exchangeIn(
            tokenA, amountIn_, IERC20(linkedVault), 0, who_, false, block.timestamp
        );
        vm.stopPrank();
        lastExecOut = execOut_;
    }

    function depositTokenAAlice(uint256 amountIn_) external returns (uint256) {
        return depositTokenARoute(researchAlice, amountIn_);
    }

    /// @notice Deposit tokenB → DualLiquidity shares (linked-token route).
    function depositTokenBRoute(address who_, uint256 amountIn_) public returns (uint256 execOut_) {
        lastRoute = "deposit_tokenB";
        lastPreviewOut =
            IStandardExchangeIn(linkedVault).previewExchangeIn(tokenB, amountIn_, IERC20(linkedVault));
        _fund(tokenB, who_, amountIn_);
        vm.startPrank(who_);
        tokenB.approve(linkedVault, amountIn_);
        execOut_ = IStandardExchangeIn(linkedVault).exchangeIn(
            tokenB, amountIn_, IERC20(linkedVault), 0, who_, false, block.timestamp
        );
        vm.stopPrank();
        lastExecOut = execOut_;
    }

    function depositTokenBAlice(uint256 amountIn_) external returns (uint256) {
        return depositTokenBRoute(researchAlice, amountIn_);
    }

    /// @notice Mint pairVault shares with tokenA, then deposit those shares → DualLiquidity shares.
    function depositPairShareRoute(address who_, uint256 amountIn_) public returns (uint256 execOut_) {
        lastRoute = "deposit_pairShare";
        address pairShare_ = _pairVaultShare();
        _fund(tokenA, who_, amountIn_);
        vm.startPrank(who_);
        tokenA.approve(pairShare_, amountIn_);
        uint256 gotShare_ = IStandardExchangeIn(pairShare_).exchangeIn(
            tokenA, amountIn_, IERC20(pairShare_), 0, who_, false, block.timestamp
        );
        lastPreviewOut =
            IStandardExchangeIn(linkedVault).previewExchangeIn(IERC20(pairShare_), gotShare_, IERC20(linkedVault));
        IERC20(pairShare_).approve(linkedVault, gotShare_);
        execOut_ = IStandardExchangeIn(linkedVault).exchangeIn(
            IERC20(pairShare_), gotShare_, IERC20(linkedVault), 0, who_, false, block.timestamp
        );
        vm.stopPrank();
        lastExecOut = execOut_;
    }

    function depositPairShareAlice(uint256 amountIn_) external returns (uint256) {
        return depositPairShareRoute(researchAlice, amountIn_);
    }

    /// @notice Mint vaultA shares with commonToken, then deposit those shares → DualLiquidity shares.
    function depositVaultAShareRoute(address who_, uint256 amountIn_) public returns (uint256 execOut_) {
        lastRoute = "deposit_vaultAShare";
        address shareA_ = _vaultAShare();
        _fund(commonToken, who_, amountIn_);
        vm.startPrank(who_);
        commonToken.approve(shareA_, amountIn_);
        uint256 gotShare_ = IStandardExchangeIn(shareA_).exchangeIn(
            commonToken, amountIn_, IERC20(shareA_), 0, who_, false, block.timestamp
        );
        lastPreviewOut =
            IStandardExchangeIn(linkedVault).previewExchangeIn(IERC20(shareA_), gotShare_, IERC20(linkedVault));
        IERC20(shareA_).approve(linkedVault, gotShare_);
        execOut_ = IStandardExchangeIn(linkedVault).exchangeIn(
            IERC20(shareA_), gotShare_, IERC20(linkedVault), 0, who_, false, block.timestamp
        );
        vm.stopPrank();
        lastExecOut = execOut_;
    }

    function depositVaultAShareAlice(uint256 amountIn_) external returns (uint256) {
        return depositVaultAShareRoute(researchAlice, amountIn_);
    }

    /// @notice Product-surface swap tokenA → tokenB (no DualLiquidity share mint; volume driver).
    function swapTokenATokenBRoute(address who_, uint256 amountIn_) public returns (uint256 execOut_) {
        lastRoute = "swap_tokenA_tokenB";
        lastPreviewOut = IStandardExchangeIn(linkedVault).previewExchangeIn(tokenA, amountIn_, tokenB);
        _fund(tokenA, who_, amountIn_);
        vm.startPrank(who_);
        tokenA.approve(linkedVault, amountIn_);
        execOut_ = IStandardExchangeIn(linkedVault).exchangeIn(
            tokenA, amountIn_, tokenB, 0, who_, false, block.timestamp
        );
        vm.stopPrank();
        lastExecOut = execOut_;
    }

    function swapTokenATokenBAlice(uint256 amountIn_) external returns (uint256) {
        return swapTokenATokenBRoute(researchAlice, amountIn_);
    }

    /* ---------------------------------------------------------------------- */
    /*                              Telemetry                                  */
    /* ---------------------------------------------------------------------- */

    function initTelemetry(string memory runId_) public {
        initMidA = midA();
        require(initMidA > 0, "dl research: midA=0 at init");
        initRateA = rateA();
        require(initRateA > 0, "dl research: rateA=0 at init");

        initPortfolioBpt = markShareBookBpt(researchAlice);
        portfolio0Bpt = initPortfolioBpt;
        require(portfolio0Bpt > 0, "dl research: empty book");

        telemetryReady = true;
        step = 0;
        _captureVolumePrev();
        runPaths = ResearchTelemetry.initRun("dualLiquidityLinkedCrossVersion", runId_);
        ResearchTelemetry.writeMeta(runPaths, _buildMetaJson(runId_));
        sample("init");
    }

    function sample(string memory action_) public {
        require(telemetryReady, "dl research: telemetry not ready");
        string memory line =
            string.concat(_sampleHead(action_), _sampleMids(), _sampleVolume(), _sampleBook());
        ResearchTelemetry.appendLine(runPaths, line);
        _captureVolumePrev();
        step += 1;
        lastPreviewOut = 0;
        lastExecOut = 0;
        lastRoute = "";
    }

    function _sampleHead(string memory action_) private view returns (string memory) {
        return string.concat(
            "{\"step\":",
            ResearchTelemetry.u(step),
            ",\"action\":\"",
            action_,
            "\",\"useRateProviders\":",
            ratesOn ? "true" : "false",
            ",\"researchVersion\":",
            ResearchTelemetry.u(researchVersion),
            ","
        );
    }

    function _sampleMids() private view returns (string memory) {
        return string.concat(
            "\"rateA\":\"",
            ResearchTelemetry.u(rateA()),
            "\",\"rateAIndex\":\"",
            ResearchTelemetry.u(rateIndexA()),
            "\",\"midA\":\"",
            ResearchTelemetry.u(midA()),
            "\",\"midAIndex\":\"",
            ResearchTelemetry.u(midIndexA()),
            "\",\"residualA\":\"",
            _i(residualA()),
            "\","
        );
    }

    function _sampleVolume() private view returns (string memory) {
        uint256 la = liveVaultA();
        uint256 lb = liveVaultB();
        uint256 lp = livePairVault();
        uint256 as_ = balAliceShares();
        uint256 db = balDiamondBpt();
        return string.concat(
            "\"liveVaultA\":\"",
            ResearchTelemetry.u(la),
            "\",\"liveVaultB\":\"",
            ResearchTelemetry.u(lb),
            "\",\"livePairVault\":\"",
            ResearchTelemetry.u(lp),
            "\",\"balAliceShares\":\"",
            ResearchTelemetry.u(as_),
            "\",\"balDiamondBpt\":\"",
            ResearchTelemetry.u(db),
            "\",\"dLiveVaultA\":\"",
            _i(int256(la) - int256(prevLiveVaultA)),
            "\",\"dLiveVaultB\":\"",
            _i(int256(lb) - int256(prevLiveVaultB)),
            "\",\"dLivePairVault\":\"",
            _i(int256(lp) - int256(prevLivePairVault)),
            "\",\"dBalAliceShares\":\"",
            _i(int256(as_) - int256(prevAliceShares)),
            "\",\"dBalDiamondBpt\":\"",
            _i(int256(db) - int256(prevDiamondBpt)),
            "\","
        );
    }

    function _sampleBook() private view returns (string memory) {
        uint256 exitBpt = markShareBookBpt(researchAlice);
        int256 totalPnl = int256(exitBpt) - int256(portfolio0Bpt);
        // pnlNorm: 1e18 fixed-point fraction totalPnl/portfolio0
        int256 pnlNorm_ = portfolio0Bpt == 0 ? int256(0) : (totalPnl * int256(1e18)) / int256(portfolio0Bpt);
        return string.concat(
            "\"portfolio0Bpt\":\"",
            ResearchTelemetry.u(portfolio0Bpt),
            "\",\"portfolioExitBpt\":\"",
            ResearchTelemetry.u(exitBpt),
            "\",\"markFullExit\":\"",
            ResearchTelemetry.u(exitBpt),
            "\",\"totalPnlBpt\":\"",
            _i(totalPnl),
            "\",\"pnlNorm\":\"",
            _i(pnlNorm_),
            "\",\"previewOut\":\"",
            ResearchTelemetry.u(lastPreviewOut),
            "\",\"execOut\":\"",
            ResearchTelemetry.u(lastExecOut),
            "\",\"previewGap\":\"",
            _i(int256(lastExecOut) - int256(lastPreviewOut)),
            "\",\"route\":\"",
            lastRoute,
            "\",\"routeTag\":\"",
            lastRoute,
            "\",\"shareBal\":\"",
            ResearchTelemetry.u(IERC20(linkedVault).balanceOf(researchAlice)),
            "\",\"reserveBpt\":\"",
            ResearchTelemetry.u(_totalReserveBpt()),
            "\"}"
        );
    }

    function _buildMetaJson(string memory runId_) internal view returns (string memory) {
        string memory modeLabel =
            researchModeId == 1 ? "B_product_routes" : (researchModeId == 2 ? "C_arb" : "A_leg_uni");
        string memory part1 = string.concat(
            "{\"product\":\"dualLiquidityLinkedCrossVersion\",\"scenarioFamily\":\"dualLiquidityLinkedCrossVersion\",",
            "\"researchVersion\":",
            ResearchTelemetry.u(researchVersion),
            ",\"attributionModel\":\"",
            ATTRIBUTION_MODEL,
            "\",\"rateProviderMode\":\"",
            ratesOn ? "on" : "off",
            "\",\"useRateProviders\":",
            ratesOn ? "true" : "false",
            ",\"mode\":\"",
            modeLabel,
            "\",\"runId\":\"",
            runId_,
            "\","
        );
        string memory part2 = string.concat(
            "\"tradeSteps\":",
            ResearchTelemetry.u(TRADE_STEPS),
            ",\"tradeSize\":\"",
            ResearchTelemetry.u(TRADE_SIZE),
            "\",\"bookDeposit\":\"",
            ResearchTelemetry.u(BOOK_DEPOSIT),
            "\",\"reserveSwapFee\":\"",
            ResearchTelemetry.u(RESERVE_SWAP_FEE),
            "\",\"portfolio0Bpt\":\"",
            ResearchTelemetry.u(portfolio0Bpt),
            "\",\"initMidA\":\"",
            ResearchTelemetry.u(initMidA),
            "\",\"initRateA\":\"",
            ResearchTelemetry.u(initRateA),
            "\",\"residualFormula\":\"midA=live[pair]/live[vaultA]; residualA=midIndexA*rateIndexA/1e18-1\",",
            "\"scenariosDoc\":\"research/scenarios/dualLiquidityLinkedCrossVersion/\",",
            "\"note\":\"DualLiquidity research. stamp_meta.py adds gitCommit.\"}"
        );
        return string.concat(part1, part2);
    }

    function _i(int256 v) internal pure returns (string memory) {
        if (v < 0) {
            return string.concat("-", ResearchTelemetry.u(uint256(-v)));
        }
        return ResearchTelemetry.u(uint256(v));
    }
}
