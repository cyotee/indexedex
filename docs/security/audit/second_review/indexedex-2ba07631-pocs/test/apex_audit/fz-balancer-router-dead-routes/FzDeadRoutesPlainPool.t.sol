// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// Business-logic adjudication variant for APEX-2026-046.
// Production-shaped config: no buffer pool (no deploy script deploys one). Instead a plain Balancer V3
// 50/50 weighted pool [SE shares, DAI] (the shape the Base mainnet / anvil_base_main "vault-token pool"
// stages build), the IndexedEx SE router diamond, and the Aerodrome DAI/USDC SE vault.
// Question: do route 2 exact-in, route 3 exact-out and route 2 exact-out fail without the buffer hook?

import {console2} from "forge-std/console2.sol";
import {IERC20 as OZIERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {TestBase_BalancerV3StandardExchangeRouter} from
    "contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol";

contract FzDeadRoutesPlainPool is TestBase_BalancerV3StandardExchangeRouter {
    address internal shPool;
    OZIERC20 internal sh;

    function setUp() public override {
        super.setUp();
        sh = OZIERC20(address(daiUsdcVault));
        // LP acquires SE shares through the router's pass-through deposit route.
        _mintAndApprove(address(dai), lp, 3_000e18);
        vm.prank(lp);
        uint256 s = _swapExactIn(address(daiUsdcVault), dai, daiUsdcVault, sh, _noVault(), 3_000e18, 0);
        console2.log("lp shares", s);

        address[] memory toks = new address[](2);
        (toks[0], toks[1]) = address(sh) < address(dai) ? (address(sh), address(dai)) : (address(dai), address(sh));
        shPool = _createWeightedPool("SH-DAI", "SH-DAI", toks, lp, "shDaiPool");

        dai.mint(lp, 10_000e18);
        vm.startPrank(lp);
        sh.approve(address(permit2), type(uint256).max);
        permit2.approve(address(sh), address(router), type(uint160).max, type(uint48).max);
        OZIERC20(address(dai)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(router), type(uint160).max, type(uint48).max);
        (OZIERC20[] memory pt,,,) = vault.getPoolTokenInfo(shPool);
        uint256[] memory amts = new uint256[](2);
        for (uint256 i; i < 2; ++i) amts[i] = address(pt[i]) == address(sh) ? s : s * 2; // ~value balanced
        router.initialize(shPool, pt, amts, 0, false, bytes(""));
        vm.stopPrank();
    }

    function _try(bytes memory cd) internal returns (bool ok, bytes memory ret) {
        (ok, ret) = address(seRouter).call(cd);
    }

    function test_plainPool_routes() public {
        address u = makeAddr("user");
        _mintAndApprove(address(usdc), u, 10_000e18);
        _mintAndApprove(address(dai), u, 10_000e18);
        uint256[4] memory sizes = [uint256(1e18), 10e18, 50e18, 200e18];
        for (uint256 i; i < sizes.length; ++i) {
            // Route 2 exact-in: USDC -> SE deposit -> pool swap shares->DAI
            vm.prank(u);
            (bool ok, bytes memory ret) = _try(abi.encodeWithSelector(
                seRouter.swapSingleTokenExactIn.selector,
                shPool, usdc, daiUsdcVault, dai, _noVault(), sizes[i], 0, _deadline(), false, bytes("")
            ));
            console2.log("route2 exactIn size/ok", sizes[i], ok);
            if (!ok) console2.logBytes(ret);

            // Route 3 exact-out: DAI -> pool swap -> shares -> SE withdraw -> exact USDC
            vm.prank(u);
            (ok, ret) = _try(abi.encodeWithSelector(
                seRouter.swapSingleTokenExactOut.selector,
                shPool, dai, _noVault(), usdc, daiUsdcVault, sizes[i], 5_000e18, _deadline(), false, bytes("")
            ));
            console2.log("route3 exactOut size/ok", sizes[i], ok);
            if (!ok) console2.logBytes(ret);

            // Route 2 exact-out: USDC -> SE exact-out mint -> pool swap shares->exact DAI
            vm.prank(u);
            (ok, ret) = _try(abi.encodeWithSelector(
                seRouter.swapSingleTokenExactOut.selector,
                shPool, usdc, daiUsdcVault, dai, _noVault(), sizes[i], 5_000e18, _deadline(), false, bytes("")
            ));
            console2.log("route2 exactOut size/ok", sizes[i], ok);
            if (!ok) console2.logBytes(ret);
        }
    }
}
