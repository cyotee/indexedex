// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {PonsV4QuoteAssertions} from "test/foundry/spec/protocols/dexes/uniswap/v4/pons/UniswapV4StandardExchange_PonsV2Pool.t.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/tokens/ERC721/IERC721.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {IPositionDescriptor} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionDescriptor.sol";
import {IWETH9} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/external/IWETH9.sol";
import {PositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PositionManager.sol";
import {PositionDescriptor} from "@crane/contracts/protocols/dexes/uniswap/v4/PositionDescriptor.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {HookMiner} from "@crane/contracts/protocols/dexes/uniswap/v4/utils/HookMiner.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";

import {PonsV2FeeEscrow} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2FeeEscrow.sol";
import {PonsV2BuybackVault} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2BuybackVault.sol";
import {PonsV2LaunchLocker} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2LaunchLocker.sol";
import {PonsV2MemeHook} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/hooks/PonsV2MemeHook.sol";
import {PonsV2LaunchFactory} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2LaunchFactory.sol";
import {PonsV2LaunchDeployer} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2LaunchDeployer.sol";
import {PonsV2GraduationExecutor} from
    "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2GraduationExecutor.sol";
import {PonsV2LauncherToken} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2LauncherToken.sol";
import {PonsV2BondingCurve} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2BondingCurve.sol";
import {
    GraduationPhase,
    IPonsV2LaunchFactory
} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/interfaces/ILaunchpadV2.sol";

import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IUniswapV4StandardExchangeLiquidReserve} from
    "contracts/protocols/dexes/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserve.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {UniswapV4SeDecimalsHelpers} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/UniswapV4SeDecimalsHelpers.sol";

/**
 * @title UniswapV4StandardExchange_PonsV2Pool_Decimals
 * @notice T10.1–T10.7 with launch token 18 and mintable quote at `_tokenBDecimals` (not native ETH).
 *         Combo wrappers are `P18_R6` and `P18_R9` only.
 */
abstract contract UniswapV4StandardExchange_PonsV2Pool_Decimals is UniswapV4SeDecimalsHelpers, PonsV4QuoteAssertions {
    using PoolIdLibrary for PoolKey;

    uint256 internal constant PONS_V2_LAUNCH_FEE = 0.0005 ether;
    uint256 internal constant PONS_V2_SUPPLY = 1_000_000_000 ether;
    uint256 internal constant PONS_V2_CURVE_FEE_BPS = 100;
    uint24 internal constant PONS_V2_POOL_FEE = 0;
    int24 internal constant PONS_V2_TICK_SPACING = 60;

    uint160 internal constant MEME_HOOK_FLAGS = uint160(
        Hooks.BEFORE_INITIALIZE_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG
    );

    IPositionManager internal ponsPositionManager;
    IPositionDescriptor internal ponsPositionDescriptor;

    PonsV2FeeEscrow internal ponsV2FeeEscrow;
    PonsV2MemeHook internal ponsV2MemeHook;
    PonsV2BuybackVault internal ponsV2BuybackVault;
    PonsV2LaunchLocker internal ponsV2Locker;
    PonsV2LaunchFactory internal ponsV2Factory;
    PonsV2LaunchDeployer internal ponsV2LaunchDeployer;
    PonsV2GraduationExecutor internal ponsV2GraduationExecutor;

    address internal ponsV2Owner;
    address internal ponsV2FeeSink;
    address internal ponsV2Launcher;
    uint256 internal ponsV2LaunchConfigId;

    MintableERC20Decimals internal quoteToken;
    address internal launchToken;
    address internal launchCurve;
    PoolKey internal graduatedPoolKey;
    IStandardExchangeProxy internal ponsSe;

    function setUp() public virtual override {
        super.setUp();
        quoteToken = new MintableERC20Decimals("Quote", "QTE", _tokenBDecimals());
        _deployPonsV2OnIndexedExPoolManager();
        _approveQuotePairAndGraduate();
        ponsSe = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(graduatedPoolKey));
        vm.label(address(ponsSe), "UniV4Se_ponsV2_decimals");
        uint256 quote_ = _uB(1) / 1000;
        quoteToken.mint(address(this), quote_);
        address[] memory tokens_ = ponsSe.vaultTokens();
        uint256[] memory amounts_ = new uint256[](2);
        for (uint256 i_; i_ < 2; ++i_) {
            amounts_[i_] = tokens_[i_] == launchToken ? 10_000 ether : quote_;
            IERC20(tokens_[i_]).approve(address(ponsSe), amounts_[i_]);
        }
        IStandardExchangeInMulti se_ = IStandardExchangeInMulti(address(ponsSe));
        uint256 preview_ = se_.previewExchangeInManyToOne(tokens_, amounts_, IERC20(address(ponsSe)));
        assertGt(preview_, 0);
        assertEq(se_.exchangeInManyToOne(tokens_, amounts_, IERC20(address(ponsSe)), preview_, address(this), false, _deadline()), preview_, "actual two-token activation");
    }

    function _phantomQuote() internal view returns (uint256) {
        return _uB(1);
    }

    function _graduationThreshold() internal view returns (uint256) {
        return (42 * (10 ** uint256(_tokenBDecimals()))) / 10;
    }

    function _deployPonsV2OnIndexedExPoolManager() internal {
        ponsV2Owner = makeAddr("ponsV2Owner");
        ponsV2FeeSink = makeAddr("ponsV2FeeSink");
        ponsV2Launcher = makeAddr("ponsV2Launcher");

        ponsPositionDescriptor =
            new PositionDescriptor(IPoolManager(address(poolManager)), address(weth), bytes32("ETH"));
        ponsPositionManager = IPositionManager(
            address(
                new PositionManager(
                    IPoolManager(address(poolManager)),
                    IAllowanceTransfer(address(permit2)),
                    100_000,
                    ponsPositionDescriptor,
                    IWETH9(address(weth))
                )
            )
        );

        ponsV2FeeEscrow = new PonsV2FeeEscrow();

        bytes memory hookArgs =
            abi.encode(IPoolManager(address(poolManager)), ponsV2FeeEscrow, ponsV2FeeSink, ponsV2Owner);
        (address predictedHook, bytes32 hookSalt) =
            HookMiner.find(address(this), MEME_HOOK_FLAGS, type(PonsV2MemeHook).creationCode, hookArgs);
        ponsV2MemeHook = new PonsV2MemeHook{salt: hookSalt}(
            IPoolManager(address(poolManager)), ponsV2FeeEscrow, ponsV2FeeSink, ponsV2Owner
        );
        require(address(ponsV2MemeHook) == predictedHook, "hook address mismatch");

        vm.startPrank(ponsV2Owner);
        ponsV2BuybackVault = new PonsV2BuybackVault(ponsV2Owner, ponsV2MemeHook, ponsV2FeeEscrow);
        ponsV2Locker = new PonsV2LaunchLocker(ponsV2Owner, address(ponsPositionManager));

        ponsV2Factory = new PonsV2LaunchFactory(
            ponsV2Owner,
            IPoolManager(address(poolManager)),
            ponsPositionManager,
            IAllowanceTransfer(address(permit2)),
            ponsV2Locker,
            ponsV2MemeHook,
            ponsV2FeeEscrow,
            ponsV2BuybackVault,
            PONS_V2_LAUNCH_FEE
        );

        ponsV2LaunchDeployer = new PonsV2LaunchDeployer(address(ponsV2Factory));
        ponsV2GraduationExecutor = new PonsV2GraduationExecutor(
            ponsPositionManager, IAllowanceTransfer(address(permit2)), ponsV2Locker, address(ponsV2Factory)
        );

        ponsV2MemeHook.setFactory(address(ponsV2Factory));
        ponsV2MemeHook.setBuybackVault(ponsV2BuybackVault);
        ponsV2BuybackVault.setFactory(address(ponsV2Factory));
        ponsV2Locker.setFactory(address(ponsV2Factory));
        ponsV2Factory.setLaunchDeployer(ponsV2LaunchDeployer);
        ponsV2Factory.setGraduationExecutor(ponsV2GraduationExecutor);

        ponsV2LaunchConfigId = ponsV2Factory.addLaunchConfig(
            PonsV2LaunchFactory.LaunchConfig({
                supply: PONS_V2_SUPPLY,
                curveFeeBps: PONS_V2_CURVE_FEE_BPS,
                phantomQuote: 1 ether,
                graduationThreshold: 4.2 ether,
                poolFee: PONS_V2_POOL_FEE,
                tickSpacing: PONS_V2_TICK_SPACING,
                enabled: true
            })
        );
        ponsV2Factory.setPairTokenEconomics(
            address(quoteToken), _phantomQuote(), _graduationThreshold(), _tokenBDecimals()
        );
        ponsV2Factory.setPairTokenApproved(address(quoteToken), true);
        ponsV2Factory.setSnipeTaxStartBps(0);
        ponsV2Factory.setLaunchEnabled(true);
        vm.stopPrank();

        vm.deal(ponsV2Launcher, 100 ether);
        vm.deal(address(this), 100 ether);
    }

    function _approveQuotePairAndGraduate() internal {
        PonsV2LaunchFactory.TokenParams memory params = _defaultV2TokenParams("Pons Se Wrap", "PSEW");
        vm.prank(ponsV2Launcher);
        (launchToken, launchCurve) = ponsV2Factory.launchToken{value: PONS_V2_LAUNCH_FEE}(
            params, ponsV2LaunchConfigId, address(quoteToken)
        );

        uint256 quoteIn = _uB(10);
        quoteToken.mint(address(this), quoteIn);
        quoteToken.approve(launchCurve, quoteIn);
        PonsV2BondingCurve(payable(launchCurve)).buy(quoteIn, 0, address(this));

        IPonsV2LaunchFactory.LaunchedToken memory rec = ponsV2Factory.getLaunchedToken(launchToken);
        if (rec.phase == GraduationPhase.NotGraduated) {
            ponsV2Factory.graduate(launchToken);
            rec = ponsV2Factory.getLaunchedToken(launchToken);
        }
        if (rec.phase == GraduationPhase.Swept) {
            ponsV2Factory.createGraduatedPool(launchToken);
        }
        rec = ponsV2Factory.getLaunchedToken(launchToken);
        require(rec.phase == GraduationPhase.PoolCreated, "pons v2 not PoolCreated");

        graduatedPoolKey = _poolKeyForLaunch(launchToken, rec);
    }

    function _poolKeyForLaunch(address token, IPonsV2LaunchFactory.LaunchedToken memory rec)
        internal
        view
        returns (PoolKey memory key)
    {
        address token0;
        address token1;
        if (rec.pairToken < token) {
            token0 = rec.pairToken;
            token1 = token;
        } else {
            token0 = token;
            token1 = rec.pairToken;
        }
        key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: rec.poolFee,
            tickSpacing: rec.tickSpacing,
            hooks: IHooks(address(ponsV2MemeHook))
        });
    }

    function _defaultV2TokenParams(string memory name_, string memory symbol_)
        internal
        pure
        returns (PonsV2LaunchFactory.TokenParams memory)
    {
        return PonsV2LaunchFactory.TokenParams({
            name: name_,
            symbol: symbol_,
            logo: "ipfs://logo",
            description: "hermetic pons v2 Uni V4 SE wrap decimals",
            socials: PonsV2LauncherToken.Socials({
                twitter: "https://x.com/pons",
                telegram: "",
                discord: "",
                website: "https://pons.family",
                farcaster: ""
            }),
            creatorFeeRecipient: address(0),
            creatorTaxBps: 137,
            buybackEnabled: false,
            expectedEconomics: bytes32(0),
            salt: keccak256(abi.encodePacked(name_, symbol_, "decimals"))
        });
    }

    function _fullRangeTicks() internal view returns (int24 minTick, int24 maxTick) {
        minTick = TickMath.minUsableTick(graduatedPoolKey.tickSpacing);
        maxTick = TickMath.maxUsableTick(graduatedPoolKey.tickSpacing);
    }

    function _seLiquidity(address owner_) internal view returns (uint128 liq) {
        (int24 minTick, int24 maxTick) = _fullRangeTicks();
        (liq,,) = StateLibrary.getPositionInfo(
            IPoolManager(address(poolManager)),
            graduatedPoolKey.toId(),
            owner_,
            minTick,
            maxTick,
            bytes32(0)
        );
    }

    function test_T10_1_samePoolManager_ponsFactoryAndSePkg() public view {
        assertEq(
            address(ponsV2Factory.poolManager()),
            address(poolManager),
            "T10.1: factory PM != SE PkgInit PM"
        );
        (uint160 sqrtPriceX96,,,) =
            StateLibrary.getSlot0(IPoolManager(address(poolManager)), graduatedPoolKey.toId());
        assertGt(sqrtPriceX96, 0, "T10.1: graduated pool missing on that PM");
    }

    function test_T10_2_graduatedPoolKey_memeHook_feeZero() public view {
        IPonsV2LaunchFactory.LaunchedToken memory rec = ponsV2Factory.getLaunchedToken(launchToken);
        assertEq(uint8(rec.phase), uint8(GraduationPhase.PoolCreated), "T10.2: phase");
        assertEq(address(graduatedPoolKey.hooks), address(ponsV2MemeHook), "T10.2: meme hook");
        assertEq(uint256(graduatedPoolKey.fee), 0, "T10.2: fee == 0");
        assertEq(rec.pairToken, address(quoteToken), "T10.2: mintable quote not native ETH");
        assertEq(quoteToken.decimals(), _tokenBDecimals(), "T10.2: quote decimals");
    }

    function test_T10_3_seDeployOnGraduatedKey_registers() public view {
        assertTrue(address(ponsSe) != address(0), "T10.3: vault");
        assertTrue(indexedexManager.isVault(address(ponsSe)), "T10.3: registered");
        address[] memory tokens = IBasicVault(address(ponsSe)).vaultTokens();
        assertEq(tokens.length, 2, "T10.3: two vault tokens");
        bool hasQuote = tokens[0] == address(quoteToken) || tokens[1] == address(quoteToken);
        bool hasLaunch = tokens[0] == launchToken || tokens[1] == launchToken;
        assertTrue(hasQuote, "T10.3: quote face");
        assertTrue(hasLaunch, "T10.3: launch token face");
    }

    function test_T10_4_previewExchangeIn_eq_exchangeIn_quoteToShare() public {
        uint256 amountIn = _uB(1);
        quoteToken.mint(address(this), amountIn);
        quoteToken.approve(address(ponsSe), amountIn);

        uint256 preview = IStandardExchangeIn(address(ponsSe)).previewExchangeIn(
            IERC20(address(quoteToken)), amountIn, IERC20(address(ponsSe))
        );
        uint256 shares = IStandardExchangeIn(address(ponsSe)).exchangeIn(
            IERC20(address(quoteToken)),
            amountIn,
            IERC20(address(ponsSe)),
            preview,
            address(this),
            false,
            _deadline()
        );
        assertEq(shares, preview, "T10.4: preview != execute");
        assertGt(shares, 0, "T10.4: shares");
    }

    function test_T10_5_previewExchangeOut_eq_exchangeOut() public {
        test_T10_4_previewExchangeIn_eq_exchangeIn_quoteToShare();
        uint256 shares = IERC20(address(ponsSe)).balanceOf(address(this));
        uint256 wantOut = IStandardExchangeIn(address(ponsSe)).previewExchangeIn(IERC20(address(ponsSe)), shares / 4, IERC20(address(quoteToken)));
        require(wantOut > 0, "T10.5: need shares");

        IERC20(address(ponsSe)).approve(address(ponsSe), shares);
        uint256 previewIn = IStandardExchangeOut(address(ponsSe)).previewExchangeOut(
            IERC20(address(ponsSe)), IERC20(address(quoteToken)), wantOut
        );
        uint256 used = IStandardExchangeOut(address(ponsSe)).exchangeOut(
            IERC20(address(ponsSe)),
            previewIn,
            IERC20(address(quoteToken)),
            wantOut,
            address(this),
            false,
            _deadline()
        );
        assertEq(used, previewIn, "T10.5: preview != execute");
        assertGt(used, 0, "T10.5: used shares");
    }

    function test_T10_6_swapOnSe_doesNotRevertFromMemeHookFee() public {
        uint256 amount_ = _uB(1) / 4;
        quoteToken.mint(address(this), amount_);
        // A policy change applies only to future launches; this pool retains its frozen cuts.
        vm.prank(ponsV2Owner);
        ponsV2MemeHook.setHookFeeBps(777);
        _assertPonsSwapQuotes(address(ponsSe), IERC20(address(quoteToken)), IERC20(launchToken), amount_);
    }

    function test_T10_7_lockerKeepsGraduationNft_seHasOwnPosition() public {
        uint256 lockerNft = ponsV2Locker.lockedPositions(launchToken);
        assertGt(lockerNft, 0, "T10.7: locker nft id");
        assertEq(
            IERC721(address(ponsPositionManager)).ownerOf(lockerNft),
            address(ponsV2Locker),
            "T10.7: locker still owns NFT"
        );

        test_T10_4_previewExchangeIn_eq_exchangeIn_quoteToShare();
        IUniswapV4StandardExchangeLiquidReserve liquid =
            IUniswapV4StandardExchangeLiquidReserve(address(ponsSe));
        (uint256 dep0, uint256 dep1) = liquid.deployedReserve();
        if (dep0 + dep1 == 0 && _seLiquidity(address(ponsSe)) == 0) {
            liquid.rebalanceLiquidReserve();
            (dep0, dep1) = liquid.deployedReserve();
        }
        assertTrue(
            dep0 + dep1 > 0 || _seLiquidity(address(ponsSe)) > 0
                || liquid.localReserve(address(quoteToken)) + liquid.localReserve(launchToken) > 0,
            "T10.7: SE own inventory"
        );
        assertEq(
            IERC721(address(ponsPositionManager)).ownerOf(lockerNft),
            address(ponsV2Locker),
            "T10.7: locker NFT unchanged"
        );
    }
}
