// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeDETFBondingTarget.sol";
import {
    IUniswapV4SingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeDETFInfoTarget.sol";

/// @notice Catalog I1 for legacy Uni V4 Single SE DETF secure pull (WP-I-DETF-SSE-UV4-001).
/// @dev Anti-theater: I1 never transfers in-call; exact TransferDeltaInsufficient selector; proxy calls.
contract Adversarial_UniswapV4SingleSE_Legacy_TrustFlag_Test is TestBase_UniswapV4SingleStandardExchangeDETF {
    address internal attacker;
    address internal aliceAdv;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("attacker");
        aliceAdv = makeAddr("aliceAdv");
        _deployBackingSeAndSeed();
    }

    function _openLive() internal returns (address instance_) {
        // Open mode: mint/burn gates always pass so I1 pull is exercised (CP peer: _openArgs).
        instance_ = _deployDetfInstance(TickMath.getSqrtPriceAtTick(0), ThresholdMode.Open);
        uint256 seedIn_ = 500 ether;
        ERC20PermitMintableStub(address(pairToken)).mint(aliceAdv, seedIn_);
        vm.startPrank(aliceAdv);
        pairToken.approve(instance_, seedIn_);
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(address(pairToken)),
            seedIn_,
            IERC20(instance_),
            0,
            aliceAdv,
            false,
            block.timestamp + 1 days
        );
        vm.stopPrank();
        assertTrue(IUniswapV4SingleStandardExchangeDETFInfo(instance_).isReserveLive(), "live");
    }

    function _fundPair(address to_, uint256 amount_) internal returns (uint256) {
        ERC20PermitMintableStub(address(pairToken)).mint(to_, amount_);
        return amount_;
    }

    function _mintPairTo(address instance_, address user_, uint256 pairIn_) internal returns (uint256 out_) {
        ERC20PermitMintableStub(address(pairToken)).mint(user_, pairIn_);
        vm.startPrank(user_);
        pairToken.approve(instance_, pairIn_);
        out_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(address(pairToken)),
            pairIn_,
            IERC20(instance_),
            0,
            user_,
            false,
            block.timestamp + 1 days
        );
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*  I1: pretransferred=true, inventory present, no in-call transfer       */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 mint: donate pairToken inventory; attacker claims pretransfer without transfer → delta 0.
    function test_I1_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        address instance_ = _openLive();
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
            block.timestamp + 1 days
        );

        assertEq(IERC20(instance_).balanceOf(attacker), attDetfBefore_, "I1: no free detfToken mint");
        assertEq(pairToken.balanceOf(instance_), invBefore_, "I1: inventory unchanged (no in-call transfer)");
    }

    /// @notice I1 burn: free detfToken on diamond cannot fund pretransfer burn extract.
    function test_I1_burn_pretransferred_true_usesOnlyCallerTransferredDetf() public {
        address instance_ = _openLive();
        uint256 minted_ = _mintPairTo(instance_, aliceAdv, 40 ether);
        assertGt(minted_, 0, "minted detfToken");
        uint256 donateAmt_ = minted_ / 2;
        if (donateAmt_ == 0) donateAmt_ = minted_;

        // Free detfToken inventory on diamond (may stack on pre-existing residual).
        uint256 freeBeforeDonate_ = IERC20(instance_).balanceOf(instance_);
        vm.prank(aliceAdv);
        IERC20(instance_).transfer(instance_, donateAmt_);
        uint256 freeBal_ = IERC20(instance_).balanceOf(instance_);
        assertEq(freeBal_, freeBeforeDonate_ + donateAmt_, "free detf inventory after donate");
        assertGt(freeBal_, 0, "free detf present");
        assertEq(IERC20(instance_).balanceOf(attacker), 0, "attacker has 0 detfToken");

        uint256 shareBefore_ = IERC20(address(backingSeVault)).balanceOf(instance_);
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
            block.timestamp + 1 days
        );

        assertEq(IERC20(instance_).balanceOf(instance_), freeBal_, "free detf still on diamond");
        assertEq(IERC20(address(backingSeVault)).balanceOf(instance_), shareBefore_, "I1 burn: inventory intact");
        assertEq(pairToken.balanceOf(attacker), pairBefore_, "I1 burn: no free pair extract");
    }

    /// @notice I1 bond: donated pair inventory cannot fund free pretransfer openBond.
    function test_I1_bond_pretransferred_inventoryNoTransfer_reverts() public {
        address instance_ = _openLive();
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
        IUniswapV4SingleStandardExchangeDETFBonding(instance_).openBond(
            claimed_,
            30 days,
            attacker,
            true,
            block.timestamp + 1 days
        );

        assertEq(pairToken.balanceOf(instance_), claimed_, "bond I1: inventory unchanged");
    }
}
