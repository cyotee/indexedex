// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {
    TestBase_UniswapV4DualSEBCPHook as TestBase
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol";

/**
 * @title Adversarial DoD: dual SE buffer CP pretransfer trust flags (I1 / I3).
 * @dev Catalog I1/I3: pretransfer must not free-extract dual SE book / pair inventory
 *      (L-GAPS-11 / WP-I-HOOK-DUAL-001). Production package → registry → hook factory proxy only.
 */
contract UniswapV4DualSEBCPHook_Adversarial_Test is TestBase {
    address internal attacker;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("attacker");
    }

    /* ---------------------------------------------------------------------- */
    /*  I1: pretransferred=true, inventory present, no in-call transfer       */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 c0→c1: donate free c0 inventory; unfunded pretransfer cannot free-extract SE book.
    function test_I1_pretransferred_c0ToC1_inventoryNoInCallTransfer_revertsDelta0() public {
        _depositBoth(200 ether, 200 ether);
        address c0 = dual.currency0();
        address c1 = dual.currency1();
        uint256 claimed_ = 5 ether;

        _mintAndDonate(c0, attacker, claimed_);
        assertGe(IERC20(c0).balanceOf(hook), claimed_, "c0 inventory on hook");
        assertEq(IERC20(c0).balanceOf(attacker), 0, "attacker drained");
        assertEq(IERC20(c0).allowance(attacker, hook), 0, "no allowance");

        uint256 claim0Before_ = dual.claimSupplyCurrency0();
        uint256 claim1Before_ = dual.claimSupplyCurrency1();
        uint256 c1AttBefore_ = IERC20(c1).balanceOf(attacker);
        uint256 c0HookBefore_ = IERC20(c0).balanceOf(hook);
        uint256 se0HookBefore_ = IERC20(_seForCurrency(c0)).balanceOf(hook);
        uint256 se1HookBefore_ = IERC20(_seForCurrency(c1)).balanceOf(hook);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(c0), claimed_, IERC20(c1), 0, attacker, true, block.timestamp + 1
        );

        assertEq(IERC20(c1).balanceOf(attacker), c1AttBefore_, "I1: no free c1 extract");
        assertEq(dual.claimSupplyCurrency0(), claim0Before_, "I1: c0 SE book not free-spent");
        assertEq(dual.claimSupplyCurrency1(), claim1Before_, "I1: c1 SE book intact");
        assertEq(IERC20(c0).balanceOf(hook), c0HookBefore_, "I1: c0 inventory unchanged");
        assertEq(IERC20(_seForCurrency(c0)).balanceOf(hook), se0HookBefore_, "I1: se0 unmoved");
        assertEq(IERC20(_seForCurrency(c1)).balanceOf(hook), se1HookBefore_, "I1: se1 unmoved");
    }

    /// @notice I1 c1→c0: donate free c1; unfunded pretransfer cannot free-extract opposite SE book.
    function test_I1_pretransferred_c1ToC0_inventoryNoInCallTransfer_revertsDelta0() public {
        _depositBoth(200 ether, 200 ether);
        address c0 = dual.currency0();
        address c1 = dual.currency1();
        uint256 claimed_ = 5 ether;

        _mintAndDonate(c1, attacker, claimed_);
        assertGe(IERC20(c1).balanceOf(hook), claimed_, "c1 inventory on hook");
        assertEq(IERC20(c1).balanceOf(attacker), 0);
        assertEq(IERC20(c1).allowance(attacker, hook), 0);

        uint256 claim0Before_ = dual.claimSupplyCurrency0();
        uint256 claim1Before_ = dual.claimSupplyCurrency1();
        uint256 c0AttBefore_ = IERC20(c0).balanceOf(attacker);
        uint256 c1HookBefore_ = IERC20(c1).balanceOf(hook);
        uint256 se0HookBefore_ = IERC20(_seForCurrency(c0)).balanceOf(hook);
        uint256 se1HookBefore_ = IERC20(_seForCurrency(c1)).balanceOf(hook);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(c1), claimed_, IERC20(c0), 0, attacker, true, block.timestamp + 1
        );

        assertEq(IERC20(c0).balanceOf(attacker), c0AttBefore_, "I1: no free c0 extract");
        assertEq(dual.claimSupplyCurrency0(), claim0Before_, "I1: c0 SE book intact");
        assertEq(dual.claimSupplyCurrency1(), claim1Before_, "I1: c1 SE book intact");
        assertEq(IERC20(c1).balanceOf(hook), c1HookBefore_, "I1: c1 inventory unmoved");
        assertEq(IERC20(_seForCurrency(c0)).balanceOf(hook), se0HookBefore_, "I1: se0 unmoved");
        assertEq(IERC20(_seForCurrency(c1)).balanceOf(hook), se1HookBefore_, "I1: se1 unmoved");
    }

    /// @notice I1 exact-out c0→c1: unfunded pretransfer cannot free-extract SE book / refund inventory.
    function test_I1_pretransferred_exchangeOut_c0ToC1_revertsDelta0() public {
        _depositBoth(200 ether, 200 ether);
        address c0 = dual.currency0();
        address c1 = dual.currency1();
        uint256 wantOut_ = 1 ether;

        // Absolute inventory theater: seed c0 so balance covers post-donation quote without in-call transfer.
        // Quote AFTER donation — donating free c0 does not reprice SE book, but keep order explicit.
        _mintAndDonate(c0, attacker, 50 ether);

        uint256 needIn_ = IStandardExchangeOut(hook).previewExchangeOut(IERC20(c0), IERC20(c1), wantOut_);
        assertGt(needIn_, 0);
        assertGe(IERC20(c0).balanceOf(hook), needIn_, "inventory covers claimed amountIn");

        uint256 claim0Before_ = dual.claimSupplyCurrency0();
        uint256 claim1Before_ = dual.claimSupplyCurrency1();
        uint256 c1AttBefore_ = IERC20(c1).balanceOf(attacker);
        uint256 c0HookBefore_ = IERC20(c0).balanceOf(hook);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, needIn_, uint256(0)
            )
        );
        IStandardExchangeOut(hook).exchangeOut(
            IERC20(c0), needIn_, IERC20(c1), wantOut_, attacker, true, block.timestamp + 1
        );

        assertEq(IERC20(c1).balanceOf(attacker), c1AttBefore_, "I1 out: no free c1");
        assertEq(dual.claimSupplyCurrency0(), claim0Before_, "I1 out: c0 SE book intact");
        assertEq(dual.claimSupplyCurrency1(), claim1Before_, "I1 out: c1 SE book intact");
        assertEq(IERC20(c0).balanceOf(hook), c0HookBefore_, "I1 out: c0 unmoved (no refund extract)");
    }

    /* ---------------------------------------------------------------------- */
    /*  I3: residual inventory cannot fund second free pretransfer credit     */
    /* ---------------------------------------------------------------------- */

    /// @notice I3: residual free c0 after honest path cannot fund a second free pretransfer c0→c1.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer_c0ToC1() public {
        _depositBoth(200 ether, 200 ether);
        address c0 = dual.currency0();
        address c1 = dual.currency1();

        // Residual free c0 that remains after honest swap (donation not consumed by !pretransfer).
        uint256 residualSeed_ = 4 ether;
        _mintAndDonate(c0, address(this), residualSeed_);

        uint256 honestIn_ = 3 ether;
        if (c0 == address(tokenA)) tokenA.mint(user, honestIn_);
        else tokenB.mint(user, honestIn_);

        vm.startPrank(user);
        IERC20(c0).approve(hook, honestIn_);
        uint256 out_ = IStandardExchangeIn(hook).exchangeIn(
            IERC20(c0), honestIn_, IERC20(c1), 0, user, false, block.timestamp + 1
        );
        vm.stopPrank();
        assertGt(out_, 0, "honest c0->c1 ok");

        uint256 residual_ = IERC20(c0).balanceOf(hook);
        assertGe(residual_, residualSeed_, "residual c0 remains");
        uint256 claim0Before_ = dual.claimSupplyCurrency0();
        uint256 claim1Before_ = dual.claimSupplyCurrency1();
        uint256 c1AttBefore_ = IERC20(c1).balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, residualSeed_, uint256(0)
            )
        );
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(c0), residualSeed_, IERC20(c1), 0, attacker, true, block.timestamp + 1
        );

        assertEq(IERC20(c0).balanceOf(hook), residual_, "I3 residual unmoved");
        assertEq(dual.claimSupplyCurrency0(), claim0Before_, "I3 c0 SE book not free-spent");
        assertEq(dual.claimSupplyCurrency1(), claim1Before_, "I3 c1 SE book intact");
        assertEq(IERC20(c1).balanceOf(attacker), c1AttBefore_, "I3 no free c1");
    }

    /* ---------------------------------------------------------------------- */
    /*                              helpers                                   */
    /* ---------------------------------------------------------------------- */

    function _seForCurrency(address currency) internal view returns (address) {
        if (currency == dual.token0()) return dual.standardExchange0();
        if (currency == dual.token1()) return dual.standardExchange1();
        revert("unknown currency");
    }

    function _mintAndDonate(address token, address from, uint256 amount) internal {
        if (token == address(tokenA)) {
            tokenA.mint(from, amount);
        } else if (token == address(tokenB)) {
            tokenB.mint(from, amount);
        } else {
            revert("unknown token");
        }
        if (from == address(this)) {
            IERC20(token).transfer(hook, amount);
        } else {
            vm.prank(from);
            IERC20(token).transfer(hook, amount);
        }
    }

}
