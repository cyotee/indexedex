// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

// Crane IERC20 imported below

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";

import {
    TestBase_BalancerV3Fork_StrategyVault
} from "test/foundry/fork/base_main/balancer/v3/TestBase_BalancerV3Fork_StrategyVault.sol";

/**
 * @title BalancerV3Fork_VaultDeposit_Test
 * @notice Fork tests for the Strategy Vault Deposit route on Base mainnet.
 * @dev Mirrors `BalancerV3StandardExchangeRouter_VaultDeposit.t.sol`, but uses:
 *      - live Balancer V3 Vault/Router bytecode on Base
 *      - a live Aerodrome-backed strategy vault deployed during fork setup
 */
contract BalancerV3Fork_VaultDeposit_Test is TestBase_BalancerV3Fork_StrategyVault {
    uint256 internal constant DEPOSIT_AMOUNT = 100e18;

    /* ---------------------------------------------------------------------- */
    /*                          ExactIn Deposit Tests                         */
    /* ---------------------------------------------------------------------- */

    function test_fork_vaultDeposit_exactIn_daiToShares() public {
        dai.mint(alice, DEPOSIT_AMOUNT);

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 daiBalBefore = dai.balanceOf(alice);
        uint256 shareBalBefore = IERC20(address(daiUsdcVault)).balanceOf(alice);

        uint256 sharesReceived = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(daiUsdcVault)),
            _noVault(),
            DEPOSIT_AMOUNT,
            1,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        uint256 daiBalAfter = dai.balanceOf(alice);
        uint256 shareBalAfter = IERC20(address(daiUsdcVault)).balanceOf(alice);

        assertEq(daiBalBefore - daiBalAfter, DEPOSIT_AMOUNT, "Fork: DAI not spent correctly");
        assertEq(shareBalAfter - shareBalBefore, sharesReceived, "Fork: Shares not received correctly");
        assertGt(sharesReceived, 0, "Fork: Should receive shares");
    }

    function test_fork_vaultDeposit_exactIn_usdcToShares() public {
        usdc.mint(alice, DEPOSIT_AMOUNT);

        vm.startPrank(alice);

        usdc.approve(address(permit2), type(uint256).max);
        permit2.approve(address(usdc), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 usdcBalBefore = usdc.balanceOf(alice);
        uint256 shareBalBefore = IERC20(address(daiUsdcVault)).balanceOf(alice);

        uint256 sharesReceived = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(usdc)),
            daiUsdcVault,
            IERC20(address(daiUsdcVault)),
            _noVault(),
            DEPOSIT_AMOUNT,
            1,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        uint256 usdcBalAfter = usdc.balanceOf(alice);
        uint256 shareBalAfter = IERC20(address(daiUsdcVault)).balanceOf(alice);

        assertEq(usdcBalBefore - usdcBalAfter, DEPOSIT_AMOUNT, "Fork: USDC not spent correctly");
        assertEq(shareBalAfter - shareBalBefore, sharesReceived, "Fork: Shares not received correctly");
        assertGt(sharesReceived, 0, "Fork: Should receive shares");
    }

    function test_fork_vaultDeposit_exactIn_queryVsExec() public {
        dai.mint(alice, DEPOSIT_AMOUNT);

        vm.prank(address(0), address(0));
        uint256 expectedShares = seRouter.querySwapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(daiUsdcVault)),
            _noVault(),
            DEPOSIT_AMOUNT,
            alice,
            ""
        );

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 actualShares = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(daiUsdcVault)),
            _noVault(),
            DEPOSIT_AMOUNT,
            1,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        assertApproxEqAbs(actualShares, expectedShares, 1, "Fork: Query vs exec mismatch");
    }

    function test_fork_vaultDeposit_exactIn_slippage_reverts() public {
        dai.mint(alice, DEPOSIT_AMOUNT);

        vm.prank(address(0), address(0));
        uint256 expectedShares = seRouter.querySwapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(daiUsdcVault)),
            _noVault(),
            DEPOSIT_AMOUNT,
            alice,
            ""
        );

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 unreasonableMin = expectedShares * 2;

        vm.expectRevert();
        seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(daiUsdcVault)),
            _noVault(),
            DEPOSIT_AMOUNT,
            unreasonableMin,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();
    }

    function test_fork_vaultDeposit_exactIn_multipleDeposits() public {
        dai.mint(alice, DEPOSIT_AMOUNT * 3);

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 shares1 = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(daiUsdcVault)),
            _noVault(),
            DEPOSIT_AMOUNT,
            1,
            _deadline(),
            false,
            ""
        );

        uint256 shares2 = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(daiUsdcVault)),
            _noVault(),
            DEPOSIT_AMOUNT,
            1,
            _deadline(),
            false,
            ""
        );

        uint256 shares3 = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(daiUsdcVault)),
            _noVault(),
            DEPOSIT_AMOUNT,
            1,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        uint256 totalShares = IERC20(address(daiUsdcVault)).balanceOf(alice);
        assertEq(totalShares, shares1 + shares2 + shares3, "Fork: Total shares mismatch");

        assertApproxEqRel(shares1, shares2, 0.1e18, "Fork: Deposit consistency issue");
    }

    /* ---------------------------------------------------------------------- */
    /*                          ExactOut Deposit Tests                        */
    /* ---------------------------------------------------------------------- */

    function test_fork_vaultDeposit_exactOut_notSupported() public {
        dai.mint(alice, DEPOSIT_AMOUNT * 2);

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 exactSharesWanted = 1000e18;

        vm.expectRevert(
            abi.encodeWithSelector(
                IStandardExchangeErrors.RouteNotSupported.selector,
                address(dai),
                address(daiUsdcVault),
                IStandardExchangeOut.previewExchangeOut.selector
            )
        );

        seRouter.swapSingleTokenExactOut(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(daiUsdcVault)),
            _noVault(),
            exactSharesWanted,
            DEPOSIT_AMOUNT * 2,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                        Router Safety Tests                             */
    /* ---------------------------------------------------------------------- */

    function test_fork_vaultDeposit_routerNoRetention() public {
        dai.mint(alice, DEPOSIT_AMOUNT);

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 routerDaiBefore = dai.balanceOf(address(seRouter));
        uint256 routerSharesBefore = IERC20(address(daiUsdcVault)).balanceOf(address(seRouter));

        seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(daiUsdcVault)),
            _noVault(),
            DEPOSIT_AMOUNT,
            1,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        uint256 routerDaiAfter = dai.balanceOf(address(seRouter));
        uint256 routerSharesAfter = IERC20(address(daiUsdcVault)).balanceOf(address(seRouter));

        assertEq(routerDaiAfter, routerDaiBefore, "Fork: Router should not retain DAI");
        assertEq(routerSharesAfter, routerSharesBefore, "Fork: Router should not retain shares");
    }

    function test_fork_vaultDeposit_deadline_reverts() public {
        dai.mint(alice, DEPOSIT_AMOUNT);

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 expiredDeadline = block.timestamp - 1;

        vm.expectRevert();
        seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(daiUsdcVault)),
            _noVault(),
            DEPOSIT_AMOUNT,
            1,
            expiredDeadline,
            false,
            ""
        );

        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                            Fuzz Tests                                  */
    /* ---------------------------------------------------------------------- */

    function testFuzz_fork_vaultDeposit_exactIn(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1e18, 1000e18);

        dai.mint(alice, depositAmount);

        vm.startPrank(alice);

        dai.approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), address(seRouter), type(uint160).max, type(uint48).max);

        uint256 sharesReceived = seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(daiUsdcVault)),
            _noVault(),
            depositAmount,
            1,
            _deadline(),
            false,
            ""
        );

        vm.stopPrank();

        assertGt(sharesReceived, 0, "Fork: Should receive shares");
        assertEq(IERC20(address(daiUsdcVault)).balanceOf(alice), sharesReceived, "Fork: Share balance mismatch");
    }
}
