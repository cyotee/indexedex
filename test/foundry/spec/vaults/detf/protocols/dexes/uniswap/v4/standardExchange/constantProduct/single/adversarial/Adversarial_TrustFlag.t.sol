// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";

/// @notice Catalog I1–I3 for Uniswap V4 Single SE CP DETF secure pull (WP-I-DETF-SSE-CP-001).
/// @dev Anti-theater: I1 never transfers in-call; exact TransferDeltaInsufficient selector; proxy calls.
contract Adversarial_UniswapV4SingleSE_CP_TrustFlag_Test is TestBase_UniswapV4SingleStandardExchangeDETF {
    address internal attacker;
    address internal victim;
    address internal aliceAdv;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");
        aliceAdv = makeAddr("aliceAdv");
    }

    function _openLiveOpenThreshold() internal returns (address instance_) {
        instance_ = _deployDetfInstance(_openArgs());
        pairToken.mint(aliceAdv, 5_000_000 ether);
        vm.startPrank(aliceAdv);
        pairToken.approve(instance_, type(uint256).max);
        IUniswapV4SingleStandardExchangeDETF(instance_).bond(
            IERC20(address(pairToken)),
            500 ether,
            DEFAULT_MIN_LOCK,
            aliceAdv,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(IUniswapV4SingleStandardExchangeDETF(instance_).isReserveLive(), "live");
    }

    function _fundPair(address to_, uint256 amount_) internal returns (uint256) {
        pairToken.mint(to_, amount_);
        return amount_;
    }

    function _mintPairTo(address instance_, address user_, uint256 pairIn_) internal returns (uint256 out_) {
        pairToken.mint(user_, pairIn_);
        vm.startPrank(user_);
        pairToken.approve(instance_, pairIn_);
        out_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(address(pairToken)),
            pairIn_,
            IERC20(instance_),
            0,
            user_,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*  I1: pretransferred=true, inventory present, no in-call transfer       */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 mint: donate pairToken inventory; attacker claims pretransfer without transfer → delta 0.
    function test_I1_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 claimed_ = _fundPair(attacker, 80 ether);
        assertGt(claimed_, 0, "funded claim");

        // Donate pair inventory so absolute balance >= claimed (absolute-credit theater would pass).
        vm.prank(attacker);
        pairToken.transfer(instance_, claimed_);
        assertEq(pairToken.balanceOf(instance_), claimed_, "inventory present");
        assertEq(pairToken.balanceOf(attacker), 0, "attacker drained");
        assertEq(pairToken.allowance(attacker, instance_), 0, "no allowance");

        uint256 attDetfBefore_ = IERC20(instance_).balanceOf(attacker);
        uint256 invBefore_ = pairToken.balanceOf(instance_);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(address(pairToken)),
            claimed_,
            IERC20(instance_),
            0,
            attacker,
            true,
            block.timestamp + 1 hours
        );

        assertEq(IERC20(instance_).balanceOf(attacker), attDetfBefore_, "I1: no free detfToken mint");
        assertEq(pairToken.balanceOf(instance_), invBefore_, "I1: inventory unchanged (no in-call transfer)");
    }

    /// @notice I1 burn: free detfToken on diamond cannot fund pretransfer burn extract.
    function test_I1_burn_pretransferred_true_usesOnlyCallerTransferredDetf() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 minted_ = _mintPairTo(instance_, aliceAdv, 40 ether);
        assertGt(minted_, 0, "minted detfToken");
        uint256 donateAmt_ = minted_ / 2;
        if (donateAmt_ == 0) donateAmt_ = minted_;

        // Free detfToken inventory on diamond (may stack on pre-existing residual join dust).
        uint256 freeBeforeDonate_ = IERC20(instance_).balanceOf(instance_);
        vm.prank(aliceAdv);
        IERC20(instance_).transfer(instance_, donateAmt_);
        uint256 freeBal_ = IERC20(instance_).balanceOf(instance_);
        assertEq(freeBal_, freeBeforeDonate_ + donateAmt_, "free detf inventory after donate");
        assertGt(freeBal_, 0, "free detf present");
        assertEq(IERC20(instance_).balanceOf(attacker), 0, "attacker has 0 detfToken");

        address hook_ = IUniswapV4SingleStandardExchangeDETF(instance_).reserveHook();
        uint256 lpBefore_ = IERC20(hook_).balanceOf(instance_);
        uint256 pairBefore_ = pairToken.balanceOf(attacker);

        // Claim the full free inventory without an in-call transfer (absolute-credit theater).
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, freeBal_, uint256(0)
            )
        );
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_),
            freeBal_,
            IERC20(address(pairToken)),
            0,
            attacker,
            true,
            block.timestamp + 1 hours
        );

        assertEq(IERC20(instance_).balanceOf(instance_), freeBal_, "free detf still on diamond");
        assertEq(IERC20(hook_).balanceOf(instance_), lpBefore_, "I1 burn: LP intact");
        assertEq(pairToken.balanceOf(attacker), pairBefore_, "I1 burn: no free pair extract");
    }

    /// @notice I1 bond: donated pair inventory cannot fund free pretransfer bond.
    function test_I1_bond_pretransferred_inventoryNoTransfer_reverts() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 claimed_ = _fundPair(attacker, 60 ether);
        vm.prank(attacker);
        pairToken.transfer(instance_, claimed_);
        assertEq(pairToken.balanceOf(instance_), claimed_);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IUniswapV4SingleStandardExchangeDETF(instance_).bond(
            IERC20(address(pairToken)),
            claimed_,
            DEFAULT_MIN_LOCK,
            attacker,
            true,
            block.timestamp + 1 hours
        );

        assertEq(pairToken.balanceOf(instance_), claimed_, "bond I1: inventory unchanged");
    }

    /* ---------------------------------------------------------------------- */
    /*  I2: claimed > observedDelta                                           */
    /* ---------------------------------------------------------------------- */

    /// @notice I2: pretransferred short/zero delta reverts with exact selector + args.
    function test_I2_pretransferred_claimedGtDelta0_reverts() public {
        address instance_ = _openLiveOpenThreshold();
        // Seed inventory (absolute would satisfy claimed) but no inbound delta.
        uint256 donated_ = _fundPair(aliceAdv, 50 ether);
        vm.prank(aliceAdv);
        pairToken.transfer(instance_, donated_);

        uint256 claimed_ = donated_;
        assertGt(claimed_, 0);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(address(pairToken)),
            claimed_,
            IERC20(instance_),
            0,
            attacker,
            true,
            block.timestamp + 1 hours
        );
    }

    /* ---------------------------------------------------------------------- */
    /*  I3: residual inventory cannot fund second free pretransfer            */
    /* ---------------------------------------------------------------------- */

    /// @notice I3: after honest pull, residual donation cannot fund a second free pretransfer credit.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer() public {
        address instance_ = _openLiveOpenThreshold();

        // Pre-seed residual inventory that remains after an honest mint joins only the pulled amount.
        uint256 residual_ = _fundPair(aliceAdv, 30 ether);
        vm.prank(aliceAdv);
        pairToken.transfer(instance_, residual_);
        assertEq(pairToken.balanceOf(instance_), residual_, "residual seeded");

        // Honest first mint via pull path (not pretransfer).
        uint256 victimIn_ = _fundPair(victim, 20 ether);
        vm.startPrank(victim);
        pairToken.approve(instance_, victimIn_);
        uint256 out_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(address(pairToken)),
            victimIn_,
            IERC20(instance_),
            0,
            victim,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(out_, 0, "honest mint ok");
        // Residual donation (plus any mint dust) remains free on diamond — not free-creditable.
        uint256 residualAfter_ = pairToken.balanceOf(instance_);
        assertGe(residualAfter_, residual_, "residual still free after honest mint");

        // Second call: pretransferred against residual free balance, no new inbound transfer.
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, residualAfter_, uint256(0)
            )
        );
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(address(pairToken)),
            residualAfter_,
            IERC20(instance_),
            0,
            attacker,
            true,
            block.timestamp + 1 hours
        );

        assertEq(pairToken.balanceOf(instance_), residualAfter_, "I3: residual not free-credited");
    }
}
