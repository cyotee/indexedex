// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_ERC4626StandardExchange} from
    "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";

/// @dev ERC-4626 receipt that gifts `gift` extra shares to the recipient during transferFrom
///      (non-SUT harness), mirroring GiftingERC20 but as a valid ERC-4626 receipt token so it
///      can back a ReceiptBackedERC4626 adapter. Used to prove the adapter's pull fails closed.
contract GiftingYieldERC4626 is SimpleYieldERC4626 {
    uint256 public gift;

    constructor(SimpleMintableERC20 asset_) SimpleYieldERC4626(asset_) {}

    function setGift(uint256 gift_) external {
        gift = gift_;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        if (gift > 0 && balanceOf[from] >= gift) {
            _transfer(from, to, gift);
        }
        return true;
    }
}

/**
 * @title APEX 2026-09-17 R5.3 — ReceiptBacked ERC4626 resting credit.
 * @notice `deposit()` snapshots `backingBefore = _totalReceiptBacking()` BEFORE pulling the
 *         depositor's receipts and prices the mint on that snapshot. So receipt backing added
 *         out-of-band (a donation, i.e. a "callout") between one depositor's arrival and the
 *         next is NOT credited to the in-flight depositor — it rests to existing holders and is
 *         claimed on a later redemption. A donation delivered DURING the pull fails closed
 *         (delta != assets -> TransferDeltaInsufficient), so it cannot be gamed into extra credit.
 *
 * RED: against a build that priced the mint on the post-pull / post-donation supply-to-backing
 *      ratio, the second depositor would capture a slice of the donation (sharesC would price
 *      1:1 and holders' convertToAssets would not rise), and a build without the pull's
 *      fail-closed delta check would silently absorb the mid-pull gift instead of reverting.
 */
contract ReceiptBackedERC4626_RestingCredit_Test is TestBase_ERC4626StandardExchange {
    SimpleMintableERC20 internal underlying;
    SimpleYieldERC4626 internal protocolVault;
    address internal se;

    address internal holderA = address(0xA11CE);
    address internal holderC = address(0xC0FFEE);
    address internal donor = address(0xD0);

    function setUp() public override {
        TestBase_ERC4626StandardExchange.setUp();
        underlying = new SimpleMintableERC20("Underlying", "UND");
        protocolVault = new SimpleYieldERC4626(underlying);
        se = _deployERC4626SE(address(protocolVault));

        // Fee-exact accounting: zero BOTH the global default and the per-vault usage fee.
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, 0);
        vm.stopPrank();
    }

    // R5.3 test 1: donated ("callout") backing is not credited to an in-flight depositor.
    function test_R5_3_calloutAddedBacking_notCreditedToInFlightDepositor() public {
        // Holder A seeds the adapter 1:1 (first deposit).
        uint256 receiptsA = _acquireReceipts(holderA, 100 ether);
        vm.prank(holderA);
        uint256 sharesA = IERC4626(se).deposit(receiptsA, holderA);
        assertEq(sharesA, receiptsA, "first deposit mints 1:1");

        uint256 assetsA_beforeDonation = IERC4626(se).convertToAssets(sharesA);

        // Out-of-band donation of receipts directly to the adapter (rests to holders).
        uint256 donation = _acquireReceipts(donor, 40 ether);
        vm.prank(donor);
        IERC20(address(protocolVault)).transfer(se, donation);

        // Holder C deposits AFTER the donation.
        uint256 receiptsC = _acquireReceipts(holderC, 60 ether);
        uint256 backingBeforeC = IERC4626(se).totalAssets(); // includes donation
        uint256 supplyPreMint = IERC20(se).totalSupply();
        vm.prank(holderC);
        uint256 sharesC = IERC4626(se).deposit(receiptsC, holderC);

        // C is priced on the pre-mint snapshot (which already absorbed the donation into backing).
        assertEq(
            sharesC,
            (receiptsC * supplyPreMint) / backingBeforeC,
            "C priced on backingBefore snapshot, not 1:1"
        );
        // The donation diluted C's shares below the naive 1:1 it would have received pre-donation.
        assertLt(sharesC, receiptsC, "donated backing NOT credited to the in-flight depositor");

        // The donation rested to the existing holder: A's shares are worth more receipts now.
        assertGt(
            IERC4626(se).convertToAssets(sharesA),
            assetsA_beforeDonation,
            "donation rests to existing holder A"
        );
    }

    // R5.3 test 2: a later redemption lets the resting holder claim the added backing, with no
    // over-withdrawal and only dust residual.
    function test_R5_3_secondRedemption_holdersClaimAddedBacking() public {
        uint256 receiptsA = _acquireReceipts(holderA, 100 ether);
        vm.prank(holderA);
        uint256 sharesA = IERC4626(se).deposit(receiptsA, holderA);

        uint256 donation = _acquireReceipts(donor, 40 ether);
        vm.prank(donor);
        IERC20(address(protocolVault)).transfer(se, donation);

        uint256 receiptsC = _acquireReceipts(holderC, 60 ether);
        vm.prank(holderC);
        uint256 sharesC = IERC4626(se).deposit(receiptsC, holderC);

        // Holder A redeems first and claims principal + the full donation slice (sole pre-donation
        // holder). Redeem via maxRedeem to absorb the 1-wei backing/supply rounding cap.
        uint256 redeemA = IERC4626(se).maxRedeem(holderA);
        assertApproxEqAbs(redeemA, sharesA, 2, "A can redeem essentially all shares");
        vm.prank(holderA);
        uint256 assetsA = IERC4626(se).redeem(redeemA, holderA, holderA);
        assertGt(assetsA, receiptsA, "A claims a share of the added (donated) backing");
        assertApproxEqAbs(assetsA, receiptsA + donation, 1e6, "A claims principal + donation");

        // Holder C, who paid the raised price, redeems ~principal (captured none of the donation).
        uint256 redeemC = IERC4626(se).maxRedeem(holderC);
        assertApproxEqAbs(redeemC, sharesC, 2, "C can redeem essentially all shares");
        vm.prank(holderC);
        uint256 assetsC = IERC4626(se).redeem(redeemC, holderC, holderC);
        assertApproxEqRel(assetsC, receiptsC, 0.01e18, "C redeems ~principal, no free donation");

        // No over-withdrawal: total paid out <= total backing; residual receipts are dust.
        assertLe(assetsA + assetsC, receiptsA + donation + receiptsC, "no over-withdrawal");
        assertLe(IERC20(address(protocolVault)).balanceOf(se), 1e6, "residual backing is dust");
    }

    // R5.3 test 3: a donation delivered DURING the pull fails closed on the deposit path.
    function test_R5_3_donationDuringPull_failsClosed() public {
        SimpleMintableERC20 gAsset = new SimpleMintableERC20("GUnderlying", "GUND");
        GiftingYieldERC4626 giftingVault = new GiftingYieldERC4626(gAsset);
        address gse = _deployERC4626SE(address(giftingVault));

        // Acquire receipts BEFORE arming the gift so acquisition is unaffected.
        gAsset.mint(holderA, 200 ether);
        vm.startPrank(holderA);
        gAsset.approve(address(giftingVault), type(uint256).max);
        giftingVault.deposit(200 ether, holderA);
        IERC20(address(giftingVault)).approve(gse, type(uint256).max);
        vm.stopPrank();

        uint256 depositAmt = 50 ether;
        uint256 gift = 5 ether;
        giftingVault.setGift(gift);

        // The adapter observes delta == depositAmt + gift != depositAmt and reverts fail-closed.
        vm.prank(holderA);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, depositAmt, depositAmt + gift
            )
        );
        IERC4626(gse).deposit(depositAmt, holderA);
    }

    function _acquireReceipts(address who, uint256 underlyingAmt) internal returns (uint256 receipts) {
        underlying.mint(who, underlyingAmt);
        vm.startPrank(who);
        underlying.approve(address(protocolVault), type(uint256).max);
        receipts = protocolVault.deposit(underlyingAmt, who);
        IERC20(address(protocolVault)).approve(se, type(uint256).max);
        vm.stopPrank();
    }
}
