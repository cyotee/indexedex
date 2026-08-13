// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRouter} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IRouter.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {InitDevService} from "@crane/contracts/InitDevService.sol";
import {
    TestBase_BalancerV3_8020WeightedPool
} from "@crane/contracts/protocols/dexes/balancer/v3/test/bases/TestBase_BalancerV3_8020WeightedPool.sol";

import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {
    BalancerV3SinglePoolStandardExchange
} from "contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol";

/// @dev Same-tx helper: push `used` then claim a fat max (E6). Atomic so a blocked refund reverts the push.
contract SinglePoolE6Helper {
    function exchangeOutAfterTransfer(
        IStandardExchange adapter_,
        IERC20 tokenIn_,
        uint256 transferAmt_,
        uint256 maxAmountIn_,
        IERC20 tokenOut_,
        uint256 amountOut_,
        address recipient_
    ) external returns (uint256 amountIn_) {
        if (transferAmt_ > 0) {
            tokenIn_.transferFrom(msg.sender, address(adapter_), transferAmt_);
        }
        amountIn_ = adapter_.exchangeOut(
            tokenIn_, maxAmountIn_, tokenOut_, amountOut_, recipient_, true, block.timestamp + 1 hours
        );
    }
}

/// @notice WP-SEC-I-BAL-SINGLE-001 / SEC-SE-BAL-001: I1 skip-pull, E6 claimed-max refund, M3 leftover max approve.
/// @dev CREATE3 adapter on gold `TestBase_BalancerV3_8020WeightedPool` (real vault + router + pool).
///      I1 seeds booked inventory and does **not** transfer in-call. Happy push+true is not I1.
contract Adversarial_BalancerV3SinglePoolSE_Test is TestBase_BalancerV3_8020WeightedPool {
    uint256 internal constant BOOKED = 1_000e18;
    uint256 internal constant DUST_JOIN = 1e18;

    IStandardExchange internal adapter;
    IERC20 internal bpt;
    address internal attacker;
    SinglePoolE6Helper internal e6Helper;

    function setUp() public virtual override {
        TestBase_BalancerV3_8020WeightedPool.setUp();
        if (address(create3Factory) == address(0)) {
            (create3Factory, diamondPackageFactory) = InitDevService.initEnv(address(this));
            diamondFactory = diamondPackageFactory;
        }
        initDaiUsdc8020WeightedPool();

        attacker = makeAddr("attacker");
        e6Helper = new SinglePoolE6Helper();
        adapter = _deployAdapter();
        bpt = IERC20(address(daiUsdc8020WeightedPool));
    }

    function _deployAdapter() internal returns (IStandardExchange adapter_) {
        IERC20[] memory poolTokens_ = new IERC20[](2);
        poolTokens_[0] = IERC20(daiUsdc8020WeightedPoolTokens[0]);
        poolTokens_[1] = IERC20(daiUsdc8020WeightedPoolTokens[1]);
        adapter_ = IStandardExchange(
            create3Factory.create3WithArgs(
                type(BalancerV3SinglePoolStandardExchange).creationCode,
                abi.encode(
                    IRouter(address(router)),
                    address(daiUsdc8020WeightedPool),
                    IERC20(address(daiUsdc8020WeightedPool)),
                    poolTokens_
                ),
                keccak256("BalancerV3SinglePoolStandardExchange")
            )
        );
    }

    /// @dev Donate residual then honest !pretransferred join so end-sync books R == leftover B.
    function _bookDaiResidual(uint256 residual_) internal {
        dai.mint(address(adapter), residual_);
        vm.startPrank(alice);
        dai.approve(address(adapter), DUST_JOIN);
        uint256 out_ = adapter.exchangeIn(
            dai, DUST_JOIN, bpt, 0, alice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(out_, 0, "book residual: honest join ok");
        assertGe(dai.balanceOf(address(adapter)), residual_, "seed remains after honest join");
    }

    function _assertNoMaxAllowances(IERC20 token_) internal view {
        assertTrue(
            token_.allowance(address(adapter), address(router)) != type(uint256).max,
            "M3: ERC20 router allowance must not stay max"
        );
        assertTrue(
            token_.allowance(address(adapter), address(permit2)) != type(uint256).max,
            "M3: ERC20 Permit2 allowance must not stay max"
        );
        (uint160 permitAmt_,,) =
            IPermit2(address(permit2)).allowance(address(adapter), address(token_), address(router));
        assertTrue(permitAmt_ != type(uint160).max, "M3: Permit2 packed allowance must not stay uint160.max");
        assertEq(token_.allowance(address(adapter), address(router)), 0, "M3: router allowance reset");
        assertEq(token_.allowance(address(adapter), address(permit2)), 0, "M3: Permit2 ERC20 allowance reset");
        assertEq(permitAmt_, 0, "M3: Permit2 packed amount reset");
    }

    /* ---------------------------------------------------------------------- */
    /*  I1: booked inventory, no in-call transfer, pretransferred=true        */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 exchangeIn: booked pair inventory cannot free-credit a join.
    function test_I1_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        _bookDaiResidual(BOOKED);

        uint256 invBefore_ = dai.balanceOf(address(adapter));
        assertGe(invBefore_, BOOKED, "absolute inventory present (anti-theater)");
        uint256 claimed_ = BOOKED;
        uint256 attBptBefore_ = bpt.balanceOf(attacker);
        assertEq(dai.balanceOf(attacker), 0, "attacker drained");
        assertEq(dai.allowance(attacker, address(adapter)), 0, "no allowance");

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        adapter.exchangeIn(dai, claimed_, bpt, 0, attacker, true, block.timestamp + 1 hours);

        assertEq(bpt.balanceOf(attacker), attBptBefore_, "I1: no free BPT");
        assertEq(dai.balanceOf(address(adapter)), invBefore_, "I1: inventory unchanged (no in-call transfer)");
    }

    /// @notice I1 exchangeOut: booked inventory cannot fund an exact-out join.
    function test_I1_exchangeOut_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        _bookDaiResidual(BOOKED);

        uint256 invBefore_ = dai.balanceOf(address(adapter));
        uint256 claimed_ = 50e18;
        uint256 amountOut_ = 1e18;
        uint256 attBptBefore_ = bpt.balanceOf(attacker);
        uint256 attDaiBefore_ = dai.balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        adapter.exchangeOut(dai, claimed_, bpt, amountOut_, attacker, true, block.timestamp + 1 hours);

        assertEq(bpt.balanceOf(attacker), attBptBefore_, "I1 out: no free BPT");
        assertEq(dai.balanceOf(attacker), attDaiBefore_, "I1 out: attacker not refunded R");
        assertEq(dai.balanceOf(address(adapter)), invBefore_, "I1 out: inventory unchanged");
    }

    /* ---------------------------------------------------------------------- */
    /*  E6: fat claimed max + transfer only used; refund must not pay R       */
    /* ---------------------------------------------------------------------- */

    /// @notice E6: seed booked R; transfer only `used`; fat max refund must not skim R.
    /// @dev Avoid adapter.previewExchangeOut — router query* staticcall reverts on this mock.
    function test_E6_refund_fatMax_transferOnlyUsed_doesNotPayBooked() public {
        _bookDaiResidual(BOOKED);

        uint256 amountOut_ = 1e18;
        uint256 used_ = 10e18;
        uint256 fatMax_ = used_ + 50e18;
        assertLe(fatMax_ - used_, BOOKED, "current CODE refund can pay from R without reverting");

        uint256 bookedBefore_ = dai.balanceOf(address(adapter));
        dai.mint(attacker, used_);
        vm.prank(attacker);
        dai.approve(address(e6Helper), used_);

        uint256 attDaiBefore_ = dai.balanceOf(attacker);
        uint256 attBptBefore_ = bpt.balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, fatMax_, used_)
        );
        e6Helper.exchangeOutAfterTransfer(adapter, dai, used_, fatMax_, bpt, amountOut_, attacker);

        assertEq(dai.balanceOf(address(adapter)), bookedBefore_, "E6: booked R stays (push reverted with op)");
        assertEq(dai.balanceOf(attacker), attDaiBefore_, "E6: attacker not paid R");
        assertEq(bpt.balanceOf(attacker), attBptBefore_, "E6: no BPT from skim-join");
    }

    /* ---------------------------------------------------------------------- */
    /*  M3: leftover router / Permit2 allowance after a successful op         */
    /* ---------------------------------------------------------------------- */

    /// @notice M3: successful join must not leave max router/Permit2 allowance on adapter inventory.
    function test_M_allowance_not_max_after_exchangeIn() public {
        uint256 amountIn_ = 20e18;
        vm.startPrank(alice);
        dai.approve(address(adapter), amountIn_);
        uint256 out_ = adapter.exchangeIn(dai, amountIn_, bpt, 0, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertGt(out_, 0, "honest join");

        _assertNoMaxAllowances(dai);
    }

    /// @notice M3: successful exact-out join must not leave max allowance.
    function test_M_allowance_not_max_after_exchangeOut() public {
        uint256 amountOut_ = 1e18;
        uint256 maxIn_ = 20e18;
        vm.startPrank(alice);
        dai.approve(address(adapter), maxIn_);
        uint256 in_ = adapter.exchangeOut(dai, maxIn_, bpt, amountOut_, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertGt(in_, 0, "honest exact-out");
        assertLe(in_, maxIn_, "used <= max");

        _assertNoMaxAllowances(dai);
    }
}
