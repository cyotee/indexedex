// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeMultiAssetLiquidity as ILiq} from
    "contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook as TB_CP} from
    "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";

/// @notice p4-hooks observation (map hooks-cp-single-dual H6): on the CP single hook, a pretransferred trade whose
///         input is the RAW leg is quoted against a raw reserve that already contains the caller's pretransfer
///         (exact-in: out = y*a/(x+2a) instead of y*a/(x+a); exact-out: the whole pretransferred maxIn inflates x).
///         previewExchangeIn/Out (no pretransfer flag) therefore over-promises; value goes to LPs (self-harm / DoS).
contract P4PretransferQuote_CP is TB_CP {
    address internal constant LP = address(0x1111);
    address internal constant TRADER = address(0x7777);
    AtomicPretransferCaller internal integrator;

    function setUp() public override {
        super.setUp();
        _initPool();
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setVaultDexSwapFee(hook, 3e15);
        rawToken.mint(LP, 100_000e18);
        pairToken.mint(LP, 100_000e18);
        vm.startPrank(LP);
        rawToken.approve(hook, type(uint256).max);
        pairToken.approve(hook, type(uint256).max);
        uint256[] memory a = new uint256[](2);
        a[0] = 100_000e18; // raw
        a[1] = 100_000e18; // pair
        ILiq(hook).joinProportional(a, LP, 0, block.timestamp + 1 hours);
        vm.stopPrank();
        integrator = new AtomicPretransferCaller();
        vm.prank(TRADER);
        rawToken.approve(address(integrator), type(uint256).max);
        vm.prank(TRADER);
        rawToken.approve(hook, type(uint256).max);
    }

    function _exactIn(uint256 a, bool pre) internal returns (uint256 q, uint256 got) {
        IERC20 r = IERC20(address(rawToken));
        IERC20 p = IERC20(address(pairToken));(q,) = IStandardExchangeIn(hook).previewExchangeIn(r, a, p);
        rawToken.mint(TRADER, a);
        uint256 b0 = p.balanceOf(TRADER);
        if (pre) {
            integrator.consumePretransfer(
                r, TRADER, hook, a,
                abi.encodeCall(IStandardExchangeIn.exchangeIn, (r, a, p, 0, TRADER, true, block.timestamp + 1 hours))
            );
        } else {
            vm.prank(TRADER);IStandardExchangeIn(hook).exchangeIn(r, a, p, 0, TRADER, false, block.timestamp + 1 hours);
        }
        got = p.balanceOf(TRADER) - b0;
    }

    function test_cp_pretransferredRawExactIn_underpaysPreview() public {
        uint256[3] memory sizes = [uint256(1_000e18), 10_000e18, 30_000e18];
        for (uint256 s; s < 3; ++s) {
            uint256 snap = vm.snapshotState();
            (uint256 q0, uint256 g0) = _exactIn(sizes[s], false);
            vm.revertToState(snap);
            (uint256 q1, uint256 g1) = _exactIn(sizes[s], true);
            vm.revertToState(snap);
            console2.log("raw->pair exact-in size", sizes[s]);
            console2.log("  pull path     preview / got", q0, g0);
            console2.log("  pretransfer   preview / got", q1, g1);
            console2.log("  pretransfer shortfall (bps of preview)", (q1 - g1) * 10000 / q1);
            assertEq(g0, q0, "pull path matches preview");
            assertLt(g1, q1, "pretransferred raw-in pays less than preview");
        }
    }

    function test_cp_pretransferredRawExactOut_overchargesPreview() public {
        IERC20 r = IERC20(address(rawToken));
        IERC20 p = IERC20(address(pairToken));
        uint256 out = 10_000e18;
        uint256 q = IStandardExchangeOut(hook).previewExchangeOut(r, p, out);
        uint256[4] memory mult = [uint256(100), 101, 150, 300];
        for (uint256 m; m < 4; ++m) {
            uint256 snap = vm.snapshotState();
            uint256 maxIn = q * mult[m] / 100;
            rawToken.mint(TRADER, maxIn);
            try integrator.consumePretransfer(
                r, TRADER, hook, maxIn,
                abi.encodeCall(IStandardExchangeOut.exchangeOut, (r, maxIn, p, out, TRADER, true, block.timestamp + 1 hours))
            ) returns (bytes memory ret) {
                uint256 used = abi.decode(ret, (uint256));
                console2.log("exact-out maxIn % of preview", mult[m]);
                console2.log("  preview / used", q, used);
                console2.log("  overcharge (bps of preview)", (used - q) * 10000 / q);
                assertGt(used, q, "pretransferred raw-in exact-out charges more than preview");
            } catch {
                console2.log("exact-out maxIn % of preview REVERTS", mult[m]);
            }
            vm.revertToState(snap);
        }
    }
}
