// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {TestBase_FeeAccrualComposition} from "contracts/test/bases/TestBase_FeeAccrualComposition.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {
    TokenStakingMigrationAdapter as Adapter
} from "contracts/protocols/staking/token/TokenStakingMigrationAdapter.sol";
import {Test} from "forge-std/Test.sol";

/// @notice Stateful driver of real adapter calls; no mocked protocol contracts.
contract MigrationAdapterHandler is Test {
    Adapter public immutable adapter;
    IERC20 public immutable token;
    IERC20 public immutable claim;
    address public immutable staking;
    uint256 public mintedBatches;
    uint256 public consumedBatches;
    uint256 public donated;

    constructor(Adapter adapter_) {
        adapter = adapter_;
        token = adapter_.stakingToken();
        claim = IERC20(adapter_.rebasingClaimToken());
        staking = adapter_.staking();
    }

    function mintBatch(uint96 seed_) external {
        if (adapter.totalSupply() != 0) return;
        uint256 amount_ = bound(uint256(seed_), 0.001 ether, 1 ether);
        if (token.balanceOf(staking) < amount_) return;
        vm.prank(staking);
        adapter.mint(token, amount_, 1, staking, false, block.timestamp);
        ++mintedBatches;
    }

    function consumeBatch() external {
        uint256 receipts_ = adapter.totalSupply();
        if (receipts_ == 0) return;
        uint256 expected_ = IStandardizedYield(address(claim)).previewDeposit(address(adapter.detfToken()), receipts_);
        vm.startPrank(staking);
        adapter.approve(address(adapter), receipts_);
        uint256 out_ =
            adapter.exchangeIn(IERC20(address(adapter)), receipts_, claim, expected_, staking, false, block.timestamp);
        adapter.approve(address(adapter), 0);
        vm.stopPrank();
        assertEq(out_, expected_);
        ++consumedBatches;
    }

    function donate(uint64 seed_) external {
        uint256 available_ = token.balanceOf(address(this));
        if (available_ == 0) return;
        uint256 amount_ = bound(uint256(seed_), 1, available_);
        token.transfer(address(adapter), amount_);
        donated += amount_;
    }

    function unauthorizedClaim() external {
        vm.expectRevert(abi.encodeWithSelector(Adapter.Unauthorized.selector, address(this)));
        adapter.exchangeIn(IERC20(address(adapter)), 1, claim, 0, staking, false, block.timestamp);
    }
}

/// @notice Adapter against registered production 60/20/20 DETF, Pons liquidity and 28-decimal custody.
/// @dev Pranks drive the historical caller ABI; native historical staking is separately exercised on a fork.
///      J/package gates are inapplicable to the approved standalone adapter. O/Permit2, E6/refunds,
///      CROPS/disable and public AMM valuation are absent. Immutable production dependencies have no
///      arbitrary callback configuration; access tests reject all non-staking callback callers.
contract TokenStakingMigrationAdapterTest is TestBase_FeeAccrualComposition {
    Adapter internal adapter;
    IERC20 internal claim;
    MigrationAdapterHandler internal handler;

    function setUp() public override {
        super.setUp();
        _bootstrap();
        adapter = new Adapter(address(staking), IERC20(address(dtf)), IERC20(detf), detfInfo.rebasingClaimToken());
        claim = IERC20(adapter.rebasingClaimToken());
        dtf.transfer(address(staking), 100_000 ether);
        vm.prank(address(staking));
        dtf.approve(address(adapter), type(uint256).max);
        handler = new MigrationAdapterHandler(adapter);
        dtf.transfer(address(handler), 100 ether);
        targetContract(address(handler));
        bytes4[] memory selectors_ = new bytes4[](4);
        selectors_[0] = handler.mintBatch.selector;
        selectors_[1] = handler.consumeBatch.selector;
        selectors_[2] = handler.donate.selector;
        selectors_[3] = handler.unauthorizedClaim.selector;
        targetSelector(FuzzSelector(address(handler), selectors_));
    }

    function _mintReceipts(uint256 amount_) internal returns (uint256 receipts_) {
        vm.prank(address(staking));
        receipts_ = adapter.mint(IERC20(address(dtf)), amount_, 1, address(staking), false, block.timestamp);
    }

    function _quote(uint256 amount_) internal view returns (uint256) {
        return IStandardizedYield(address(claim)).previewDeposit(detf, amount_);
    }

    function _consume(uint256 amount_) internal returns (uint256 received_) {
        uint256 expected_ = _quote(amount_);
        vm.startPrank(address(staking));
        adapter.approve(address(adapter), amount_);
        received_ = adapter.exchangeIn(
            IERC20(address(adapter)), amount_, claim, expected_, address(staking), false, block.timestamp
        );
        adapter.approve(address(adapter), 0);
        vm.stopPrank();
    }

    function _assertSettled() internal view {
        assertEq(adapter.totalSupply(), 0);
        assertEq(adapter.balanceOf(address(staking)), 0);
        assertEq(adapter.allowance(address(staking), address(adapter)), 0);
        assertEq(dtf.allowance(address(adapter), detf), 0);
        assertEq(IERC20(detf).allowance(address(adapter), address(claim)), 0);
        assertEq(claim.balanceOf(address(adapter)), 0);
    }

    function test_adapter_metadataAndBindings() public view {
        assertEq(adapter.staking(), address(staking));
        assertEq(address(adapter.stakingToken()), address(dtf));
        assertEq(address(adapter.detfToken()), detf);
        assertEq(adapter.rebasingClaimToken(), address(claim));
        assertEq(adapter.decimals(), 9);
        assertEq(adapter.name(), "Token Staking Migration Receipt");
        assertEq(adapter.symbol(), "TSMR");
        assertEq(adapter.fundedStakingToken(), detfInfo.rebasingClaimToken());
        assertEq(IStakedDETF(adapter.fundedStakingToken()).detf(), detf);
        assertEq(IStandardizedYield(address(claim)).yieldToken(), adapter.fundedStakingToken());
    }

    function test_adapter_invalidConstructor() public {
        address funded_ = adapter.fundedStakingToken();
        vm.expectRevert(Adapter.InvalidConfiguration.selector);
        new Adapter(address(0), IERC20(address(dtf)), IERC20(detf), funded_);
        vm.expectRevert(Adapter.InvalidConfiguration.selector);
        new Adapter(address(staking), IERC20(address(weth)), IERC20(detf), funded_);
        vm.expectRevert(Adapter.InvalidConfiguration.selector);
        new Adapter(address(staking), IERC20(address(dtf)), IERC20(detf), detf);
    }

    function test_adapter_unauthorizedMintExchangeApproval() public {
        vm.expectRevert(abi.encodeWithSelector(Adapter.Unauthorized.selector, address(this)));
        adapter.mint(IERC20(address(dtf)), 1 ether, 0, address(staking), false, block.timestamp);
        vm.expectRevert(abi.encodeWithSelector(Adapter.Unauthorized.selector, address(this)));
        adapter.exchangeIn(IERC20(address(adapter)), 1, claim, 0, address(staking), false, block.timestamp);
        vm.expectRevert(abi.encodeWithSelector(Adapter.Unauthorized.selector, address(this)));
        adapter.approve(address(adapter), 0);
    }

    function test_adapter_rejectsPretransferWithInventory() public {
        dtf.transfer(address(adapter), 10 ether);
        vm.startPrank(address(staking));
        vm.expectRevert(Adapter.PretransferUnsupported.selector);
        adapter.mint(IERC20(address(dtf)), 1 ether, 0, address(staking), true, block.timestamp);
        vm.expectRevert(Adapter.PretransferUnsupported.selector);
        adapter.exchangeIn(IERC20(address(adapter)), 1, claim, 0, address(staking), true, block.timestamp);
        vm.stopPrank();
        assertEq(dtf.balanceOf(address(adapter)), 10 ether);
        _assertSettled();
    }

    function test_adapter_rejectsZeroExpiredWrongRouteAndRecipient() public {
        vm.startPrank(address(staking));
        vm.expectRevert(Adapter.ZeroAmount.selector);
        adapter.mint(IERC20(address(dtf)), 0, 0, address(staking), false, block.timestamp);
        vm.expectRevert(Adapter.ZeroAmount.selector);
        adapter.exchangeIn(IERC20(address(adapter)), 0, claim, 0, address(staking), false, block.timestamp);
        vm.expectRevert(abi.encodeWithSelector(Adapter.DeadlineExpired.selector, block.timestamp - 1));
        adapter.mint(IERC20(address(dtf)), 1, 0, address(staking), false, block.timestamp - 1);
        vm.expectRevert(Adapter.InvalidRoute.selector);
        adapter.mint(IERC20(detf), 1, 0, address(staking), false, block.timestamp);
        vm.expectRevert(Adapter.InvalidRoute.selector);
        adapter.exchangeIn(IERC20(detf), 1, claim, 0, address(staking), false, block.timestamp);
        vm.expectRevert(Adapter.InvalidRoute.selector);
        adapter.exchangeIn(IERC20(address(adapter)), 1, IERC20(detf), 0, address(staking), false, block.timestamp);
        vm.expectRevert(Adapter.InvalidRecipient.selector);
        adapter.mint(IERC20(address(dtf)), 1, 0, address(this), false, block.timestamp);
        vm.expectRevert(Adapter.InvalidRecipient.selector);
        adapter.exchangeIn(IERC20(address(adapter)), 1, claim, 0, address(this), false, block.timestamp);
        vm.stopPrank();
    }

    function test_adapter_receiptsRequireBackingAndCannotTransfer() public {
        uint256 receipts_ = _mintReceipts(1 ether);
        assertEq(IERC20(detf).balanceOf(address(adapter)), receipts_);
        assertEq(adapter.balanceOf(address(staking)), receipts_);
        vm.startPrank(address(staking));
        vm.expectRevert(Adapter.PendingReceipts.selector);
        adapter.mint(IERC20(address(dtf)), 1 ether, 0, address(staking), false, block.timestamp);
        vm.expectRevert(Adapter.NontransferableReceipt.selector);
        adapter.transfer(address(this), 1);
        vm.expectRevert(Adapter.InvalidApproval.selector);
        adapter.approve(address(this), receipts_);
        vm.expectRevert(Adapter.InvalidApproval.selector);
        adapter.approve(address(adapter), receipts_ + 1);
        vm.expectRevert(Adapter.InvalidReceiptAmount.selector);
        adapter.exchangeIn(IERC20(address(adapter)), receipts_ - 1, claim, 0, address(staking), false, block.timestamp);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(adapter), 0, receipts_)
        );
        adapter.exchangeIn(IERC20(address(adapter)), receipts_, claim, 0, address(staking), false, block.timestamp);
        vm.stopPrank();
        uint256 expected_ = _quote(receipts_);
        assertEq(_consume(receipts_), expected_);
        vm.prank(address(staking));
        vm.expectRevert(Adapter.InvalidReceiptAmount.selector);
        adapter.exchangeIn(IERC20(address(adapter)), receipts_, claim, 0, address(staking), false, block.timestamp);
        _assertSettled();
    }

    function test_adapter_failedClaimMinimumPreservesReceipts() public {
        uint256 receipts_ = _mintReceipts(1 ether);
        uint256 quote_ = _quote(receipts_);
        vm.startPrank(address(staking));
        adapter.approve(address(adapter), receipts_);
        vm.expectRevert(abi.encodeWithSignature("MinimumOutputNotMet(uint256,uint256)", quote_ + 1, quote_));
        adapter.exchangeIn(
            IERC20(address(adapter)), receipts_, claim, quote_ + 1, address(staking), false, block.timestamp
        );
        vm.stopPrank();
        assertEq(adapter.totalSupply(), receipts_);
        assertEq(adapter.allowance(address(staking), address(adapter)), receipts_);
        assertEq(IERC20(detf).balanceOf(address(adapter)), receipts_);
        assertEq(IERC20(detf).allowance(address(adapter), address(claim)), 0);
        uint256 expected_ = _quote(receipts_);
        assertEq(_consume(receipts_), expected_);
    }

    function test_adapter_failedMintMinimumPreservesInput() public {
        uint256 before_ = dtf.balanceOf(address(staking));
        uint256 quote_ = IStandardExchangeIn(detf).previewExchangeIn(IERC20(address(dtf)), 1 ether, IERC20(detf));
        vm.prank(address(staking));
        vm.expectRevert(abi.encodeWithSignature("MinAmountNotMet(uint256,uint256)", quote_ + 1, quote_));
        adapter.mint(IERC20(address(dtf)), 1 ether, quote_ + 1, address(staking), false, block.timestamp);
        assertEq(dtf.balanceOf(address(staking)), before_);
        assertEq(dtf.balanceOf(address(adapter)), 0);
        _assertSettled();
    }

    /// @notice Donations before issuance or between the two legs cannot be credited or swept.
    function testFuzz_adapter_donationsAndConservation(uint96 amountSeed_, uint64 donationSeed_) public {
        uint256 amount_ = bound(uint256(amountSeed_), 0.001 ether, 10 ether);
        uint256 donation_ = bound(uint256(donationSeed_), 1, 1 ether);
        dtf.transfer(address(adapter), donation_);
        uint256 before_ = dtf.balanceOf(address(staking));
        uint256 receipts_ = _mintReceipts(amount_);
        assertEq(before_ - dtf.balanceOf(address(staking)), amount_);
        assertEq(adapter.totalSupply(), receipts_);
        uint256 extra_ = _buyDetfDonation();
        uint256 claimBefore_ = claim.balanceOf(address(staking));
        uint256 expected_ = _quote(receipts_);
        assertEq(_consume(receipts_), expected_);
        assertEq(claim.balanceOf(address(staking)) - claimBefore_, expected_);
        assertEq(dtf.balanceOf(address(adapter)), donation_);
        assertEq(IERC20(detf).balanceOf(address(adapter)), extra_);
        _assertSettled();
    }

    function _buyDetfDonation() internal returns (uint256 extra_) {
        dtf.approve(detf, 1 ether);
        extra_ = IStandardExchangeIn(detf)
            .exchangeIn(IERC20(address(dtf)), 1 ether, IERC20(detf), 1, address(adapter), false, block.timestamp);
    }

    /// @notice Stateful repeated batches conserve backing and consume only their own receipts.
    function testFuzz_adapter_batchSequence(uint256 seed_) public {
        uint256 totalClaims_;
        for (uint256 i_; i_ < 8; ++i_) {
            seed_ = uint256(keccak256(abi.encode(seed_, i_)));
            uint256 amount_ = bound(seed_, 0.001 ether, 2 ether);
            uint256 receipts_ = _mintReceipts(amount_);
            assertEq(IERC20(detf).balanceOf(address(adapter)), adapter.totalSupply());
            totalClaims_ += _consume(receipts_);
            _assertSettled();
        }
        // Static SY units remain unchanged across rewards synchronization in later batches.
        assertEq(claim.balanceOf(address(staking)), totalClaims_);
        assertEq(dtf.balanceOf(address(adapter)), 0);
        assertEq(IERC20(detf).balanceOf(address(adapter)), 0);
    }

    /// @notice Every outstanding receipt is held by staking and backed by exactly one raw DETF unit.
    function invariant_adapter_backingAndReceiptOwnership() public view {
        assertEq(IERC20(detf).balanceOf(address(adapter)), adapter.totalSupply());
        assertEq(adapter.balanceOf(address(staking)), adapter.totalSupply());
        assertEq(handler.mintedBatches() - handler.consumedBatches(), adapter.totalSupply() == 0 ? 0 : 1);
    }

    /// @notice Donations persist untouched; downstream allowances and receipt approvals never remain open.
    function invariant_adapter_noResidualAuthorityOrDonationCredit() public view {
        assertEq(dtf.balanceOf(address(adapter)), handler.donated());
        assertEq(dtf.allowance(address(adapter), detf), 0);
        assertEq(IERC20(detf).allowance(address(adapter), address(claim)), 0);
        assertEq(adapter.allowance(address(staking), address(adapter)), 0);
        assertEq(claim.balanceOf(address(adapter)), 0);
    }
}
