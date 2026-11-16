// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IEIP712} from "@crane/contracts/interfaces/IEIP712.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {MigrationGenesisCapitalBase} from "./MigrationGenesisCapital.t.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {MigrationPermit2Callback} from "./MigrationPermit2Callback.sol";
import {Vm} from "forge-std/Vm.sol";

/// @notice Genuine canonical Permit2 execution through the installed bond proxy selectors.
/// @dev StdCheats.deployCodeTo runs the genuine counterparty constructor at its canonical
/// address. No SUT is etched; no foreign cached domain or signature stub is installed.
contract MigrationPermit2Test is MigrationGenesisCapitalBase {
    address internal constant CANONICAL = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    uint256 internal constant DONOR_KEY = 0x18548;
    uint256 internal constant AMOUNT = 0.01 ether;
    address internal donor;
    IDetfNftReserveDonation internal donation;

    function _deployContributionFixture() internal override returns (address) {
        return create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "MigrationPermit2Callback.sol:MigrationPermit2Callback"),
            "", keccak256("migration.permit2.callback")
        );
    }

    function setUp() public virtual override {
        super.setUp();
        vm.chainId(31337);
        vm.warp(1 days);
        deployCodeTo("lib/crane/contracts/protocols/utils/permit2/BetterPermit2.sol:BetterPermit2", CANONICAL);
        donor = vm.addr(DONOR_KEY);
        donation = IDetfNftReserveDonation(address(bonds));
        IERC20(pairB).transfer(donor, 10 ether);
        vm.prank(donor);
        IERC20(pairB).approve(CANONICAL, 10 ether);
        _fundAndCapture();
        vm.prank(donor);
        IAllowanceTransfer(CANONICAL).approve(pairB, address(bonds), uint160(1 ether), uint48(block.timestamp + 1 days));
    }

    function _domain(uint256 chain_) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)"),
            keccak256("Permit2"), chain_, CANONICAL
        ));
    }

    function test_V1_canonicalRuntimeAndDomainIdentity() public {
        assertGt(CANONICAL.code.length, 0);
        emit log_named_bytes32("canonical Permit2 runtime keccak256", CANONICAL.codehash);
        uint256[3] memory chains_ = [uint256(31337), uint256(1), uint256(31338)];
        for (uint256 i_; i_ < chains_.length; ++i_) {
            vm.chainId(chains_[i_]);
            assertEq(IEIP712(CANONICAL).DOMAIN_SEPARATOR(), _domain(chains_[i_]));
            emit log_named_uint("domain chain ID", chains_[i_]);
            emit log_named_bytes32("canonical domain", IEIP712(CANONICAL).DOMAIN_SEPARATOR());
        }
        vm.chainId(31337);
    }

    function _signature(uint256 nonce_, uint256 deadline_, address spender_) internal view returns (bytes memory) {
        ISignatureTransfer.PermitTransferFrom memory permit_ = ISignatureTransfer.PermitTransferFrom(
            ISignatureTransfer.TokenPermissions(pairB, AMOUNT), nonce_, deadline_
        );
        bytes32 permissions_ = keccak256(abi.encode(
            keccak256("TokenPermissions(address token,uint256 amount)"), pairB, AMOUNT
        ));
        bytes32 data_ = keccak256(abi.encode(
            keccak256("PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"),
            permissions_, spender_, nonce_, deadline_
        ));
        (uint8 v_, bytes32 r_, bytes32 s_) = vm.sign(
            DONOR_KEY, keccak256(abi.encodePacked("\x19\x01", _domain(block.chainid), data_))
        );
        return abi.encode(permit_, abi.encodePacked(r_, s_, v_));
    }

    function _permitState(address account_) internal view returns (bytes32) {
        (uint160 amount_, uint48 expiry_, uint48 nonce_) =
            IAllowanceTransfer(CANONICAL).allowance(account_, pairB, address(bonds));
        return keccak256(abi.encode(
            _capitalState(), amount_, expiry_, nonce_, ISignatureTransfer(CANONICAL).nonceBitmap(account_, 0),
            IERC20(pairB).balanceOf(account_), IERC20(pairB).allowance(account_, CANONICAL),
            IERC20(detf).balanceOf(account_), receipt.balanceOf(account_),
            bonds.migrationAccountingPhase(), receipt.migrationAccountingPhase()
        ));
    }

    function _positive(bool signature_, uint256 nonce_) internal {
        uint256 donorBefore_ = IERC20(pairB).balanceOf(donor);
        uint256 approvalBefore_ = IERC20(pairB).allowance(donor, CANONICAL);
        uint256 lpBefore_ = IERC20(migration.hook()).balanceOf(address(bonds));
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        uint256 gonsBefore_ = receipt.stakingState().totalGons;
        uint256 quote_ = donation.previewDonate(IERC20(pairB), AMOUNT);
        assertGt(quote_, 0);
        bytes memory signatureData_ = _signature(nonce_, block.timestamp, address(bonds));
        vm.recordLogs();
        vm.prank(donor);
        uint256 lp_ = signature_
            ? donation.donateWithPermit2Signature(IERC20(pairB), AMOUNT, 1, block.timestamp, signatureData_)
            : donation.donateWithPermit2Allowance(IERC20(pairB), AMOUNT, 1, block.timestamp);
        assertEq(donorBefore_ - IERC20(pairB).balanceOf(donor), AMOUNT);
        assertEq(approvalBefore_ - IERC20(pairB).allowance(donor, CANONICAL), AMOUNT);
        uint256 mintedToBond_;
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter == migration.hook() && logs_[i_].topics.length == 3
                && logs_[i_].topics[0] == keccak256("Transfer(address,address,uint256)")
                && logs_[i_].topics[1] == bytes32(0)
                && logs_[i_].topics[2] == bytes32(uint256(uint160(address(bonds))))) {
                mintedToBond_ += abi.decode(logs_[i_].data, (uint256));
            }
        }
        assertEq(IERC20(migration.hook()).balanceOf(address(bonds)) - lpBefore_, mintedToBond_);
        assertEq(IERC20(migration.hook()).balanceOf(donor), 0);
        assertEq(lp_, quote_, "reported primary donation join matches preview");
        emit log_named_uint("pre-pull ordinary donation preview", quote_);
        assertEq(IERC20(detf).totalSupply(), supplyBefore_, "donation cannot mint personal principal");
        assertEq(receipt.stakingState().totalGons, gonsBefore_);
        assertEq(IERC20(pairB).balanceOf(address(bonds)), 0);
        assertEq(IERC20(pairB).allowance(address(bonds), detf), 0);
        assertEq(IERC20(pairB).allowance(detf, migration.hook()), 0);
        (uint160 remaining_,, uint48 nonceAfter_) = IAllowanceTransfer(CANONICAL).allowance(donor, pairB, address(bonds));
        assertEq(remaining_, signature_ ? 1 ether : 1 ether - AMOUNT);
        assertEq(nonceAfter_, 0, "transferFrom does not consume signed-allowance nonce");
        assertEq(ISignatureTransfer(CANONICAL).nonceBitmap(donor, 0), signature_ ? uint256(1) << nonce_ : 0);
        emit log_named_uint("donor paid", AMOUNT);
        emit log_named_uint("bond LP received", lp_);
        emit log_named_uint("total bond LP including residual joins", mintedToBond_);
        emit log_named_uint("remaining ERC20 approval", IERC20(pairB).allowance(donor, CANONICAL));
        emit log_named_uint("remaining Permit2 allowance", remaining_);
        emit log_named_uint("signature nonce bitmap", ISignatureTransfer(CANONICAL).nonceBitmap(donor, 0));
    }

    function test_V1_allowanceDonationPaysOnlyReserve() public { _positive(false, 0); }
    function test_V1_signatureDonationPaysOnlyReserve() public { _positive(true, 7); }

    function test_V1_allowanceDeadlineFailureRollsBack() public {
        bytes32 before_ = _permitState(donor);
        vm.prank(donor);
        vm.expectPartialRevert(bytes4(keccak256("DeadlineExceeded(uint256,uint256)")));
        donation.donateWithPermit2Allowance(IERC20(pairB), AMOUNT, 1, block.timestamp - 1);
        assertEq(_permitState(donor), before_);
    }

    function test_V1_allowanceExpiryWithValidRouteRollsBack() public {
        vm.prank(donor);
        IAllowanceTransfer(CANONICAL).approve(pairB, address(bonds), uint160(1 ether), uint48(block.timestamp - 1));
        bytes32 before_ = _permitState(donor);
        vm.prank(donor);
        vm.expectPartialRevert(IAllowanceTransfer.AllowanceExpired.selector);
        donation.donateWithPermit2Allowance(IERC20(pairB), AMOUNT, 1, block.timestamp);
        assertEq(_permitState(donor), before_);
    }

    function test_V1_allowanceWrongCallerCannotSpendDonorApproval() public {
        address other_ = makeAddr("unapproved donor");
        IERC20(pairB).transfer(other_, AMOUNT);
        vm.startPrank(other_);
        IERC20(pairB).approve(CANONICAL, AMOUNT);
        IAllowanceTransfer(CANONICAL).approve(pairB, address(bonds), 0, uint48(block.timestamp + 1 days));
        vm.stopPrank();
        bytes32 before_ = _permitState(donor);
        bytes32 otherBefore_ = _permitState(other_);
        vm.prank(other_);
        vm.expectPartialRevert(IAllowanceTransfer.InsufficientAllowance.selector);
        donation.donateWithPermit2Allowance(IERC20(pairB), AMOUNT, 1, block.timestamp);
        assertEq(_permitState(donor), before_);
        assertEq(_permitState(other_), otherBefore_);
    }

    function test_V1_allowanceDownstreamMinimumRestoresApprovalAndReserve() public {
        bytes32 before_ = _permitState(donor);
        vm.prank(donor);
        vm.expectPartialRevert(bytes4(keccak256("MinAmountNotMet(uint256,uint256)")));
        donation.donateWithPermit2Allowance(IERC20(pairB), AMOUNT, type(uint256).max, block.timestamp);
        assertEq(_permitState(donor), before_);
        _positive(false, 0);
    }

    function _rejectSignature(bytes memory signature_, address caller_, bytes4 error_) internal {
        bytes32 before_ = _permitState(donor);
        bytes32 callerBefore_ = _permitState(caller_);
        vm.prank(caller_);
        vm.expectPartialRevert(error_);
        donation.donateWithPermit2Signature(IERC20(pairB), AMOUNT, 1, block.timestamp, signature_);
        assertEq(_permitState(donor), before_);
        assertEq(_permitState(caller_), callerBefore_);
    }

    function test_V1_signatureExpiredWithValidOuterDeadlineRollsBack() public {
        _rejectSignature(_signature(8, block.timestamp - 1, address(bonds)), donor, bytes4(keccak256("SignatureExpired(uint256)")));
    }

    function test_V1_signatureWrongSpenderRollsBackNonce() public {
        _rejectSignature(_signature(8, block.timestamp, detf), donor, bytes4(keccak256("InvalidSigner()")));
    }

    function test_V1_signatureWrongDomainRollsBackNonce() public {
        vm.chainId(31338);
        bytes memory data_ = _signature(8, block.timestamp, address(bonds));
        vm.chainId(31337);
        _rejectSignature(data_, donor, bytes4(keccak256("InvalidSigner()")));
    }

    function test_V1_signatureWrongCallerRollsBackBothAccounts() public {
        address thief_ = makeAddr("signature thief");
        IERC20(pairB).transfer(thief_, AMOUNT);
        vm.prank(thief_);
        IERC20(pairB).approve(CANONICAL, AMOUNT);
        _rejectSignature(_signature(8, block.timestamp, address(bonds)), thief_, bytes4(keccak256("InvalidSigner()")));
    }

    function test_V1_signatureReplayPreservesCommittedFirstDonation() public {
        _positive(true, 7);
        _rejectSignature(_signature(7, block.timestamp, address(bonds)), donor, bytes4(keccak256("InvalidNonce()")));
    }

    function test_V1_signatureDownstreamMinimumRestoresNonceAndReserve() public {
        bytes memory data_ = _signature(7, block.timestamp, address(bonds));
        bytes32 before_ = _permitState(donor);
        vm.prank(donor);
        vm.expectPartialRevert(bytes4(keccak256("MinAmountNotMet(uint256,uint256)")));
        donation.donateWithPermit2Signature(IERC20(pairB), AMOUNT, type(uint256).max, block.timestamp, data_);
        assertEq(_permitState(donor), before_);
        _positive(true, 7);
    }

    function _callbackRollback(bool signature_) internal {
        MigrationPermit2Callback(pairB).arm(detf, address(bonds));
        bytes32 before_ = _permitState(donor);
        bytes memory data_ = _signature(7, block.timestamp, address(bonds));
        vm.expectCall(detf, abi.encodeWithSignature("synchronizeRewards()"));
        vm.prank(donor);
        vm.expectPartialRevert(bytes4(keccak256("TransferFromFailed()")));
        if (signature_) donation.donateWithPermit2Signature(IERC20(pairB), AMOUNT, 1, block.timestamp, data_);
        else donation.donateWithPermit2Allowance(IERC20(pairB), AMOUNT, 1, block.timestamp);
        assertEq(_permitState(donor), before_);
        MigrationPermit2Callback(pairB).arm(address(0), address(0));
        _positive(signature_, 7);
    }

    function test_V1_allowanceCallbackFailureRollsBackEverything() public { _callbackRollback(false); }
    function test_V1_signatureCallbackFailureRestoresNonce() public { _callbackRollback(true); }
}
