// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721Receiver} from "@crane/contracts/interfaces/IERC721Receiver.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {TestBase_UniswapV4DetfMigration_Adversarial} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration_Adversarial.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {IERC721Errors} from "@crane/contracts/interfaces/IERC721Errors.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation}
    from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";

/// @notice Controllable external ERC20 only. The parent, children, pools and SEs are real.
contract MigrationHostileContribution is SimpleMintableERC20 {
    bool public shortReceipt;
    address public watchedParent;
    address public callback;
    bytes public payload;
    bool public callbackSucceeded;
    bytes public callbackReason;
    constructor() SimpleMintableERC20("External hostile contribution fixture", "HOSTILE") {}
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
    function arm(bool short_, address parent_, address callback_, bytes calldata payload_) external {
        shortReceipt = short_; watchedParent = parent_; callback = callback_; payload = payload_;
    }
    function transferFrom(address from_, address to_, uint256 amount_) external override returns (bool) {
        uint256 allowed_ = allowance[from_][msg.sender];
        require(allowed_ >= amount_, "allowance");
        if (allowed_ != type(uint256).max) allowance[from_][msg.sender] = allowed_ - amount_;
        bool trigger_ = msg.sender == watchedParent;
        _transfer(from_, to_, trigger_ && shortReceipt ? amount_ - 1 : amount_);
        if (trigger_ && callback != address(0)) (callbackSucceeded, callbackReason) = callback.call(payload);
        return true;
    }
    function claim(IDetfBondNFT bond_, uint256 id_, address recipient_) external returns (uint256) {
        return bond_.claimPrincipal(id_, recipient_);
    }
}

contract MigrationHostileContributionTest is TestBase_UniswapV4DetfMigration_Adversarial {
    /// @notice Catches phantom donation credit and any partial token movement on a short receipt.
    function test_L2_FoT_forbidden() public {
        MigrationHostileContribution token_ = MigrationHostileContribution(pairB);
        _armContribution(true, address(0), "");
        bytes32 before_ = _adversarialState(address(this), 3);
        IERC20[] memory tokens_ = new IERC20[](1);
        tokens_[0] = IERC20(pairB);
        uint256[] memory amounts_ = new uint256[](1);
        amounts_[0] = 1 ether;
        uint256 payerBefore_ = token_.balanceOf(address(this));
        uint256 parentBefore_ = token_.balanceOf(detf);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1 ether, 1 ether - 1));
        migration.donateMigrationCapital(tokens_, amounts_, 0, 0, block.timestamp);
        assertEq(token_.balanceOf(address(this)), payerBefore_);
        assertEq(token_.balanceOf(detf), parentBefore_);
        assertEq(migration.migrationDonationInventory(IERC20(pairB)), 0);
        assertEq(IERC20(detf).totalSupply(), 0);
        _assertAdversarialUnchanged(before_, address(this), 3);
    }

    /// @notice Catches a cross-child claim borrowing the outer synchronization privilege.
    function test_tokenCallbackCannotBorrowLockedParentChildSynchronization() public {
        _fundAndCapture();
        uint256 principal_ = _configure(pairB, 1 ether, bytes32("external-owner"));
        uint256 id_ = _issue(pairB);
        vm.warp(block.timestamp + 90 days);
        MigrationHostileContribution token_ = MigrationHostileContribution(pairB);
        token_.arm(false, detf, address(bonds), abi.encodeCall(IDetfBondNFT.claimPrincipal, (id_, address(this))));
        IERC20[] memory tokens_ = new IERC20[](1);
        tokens_[0] = IERC20(pairB);
        uint256[] memory amounts_ = new uint256[](1);
        amounts_[0] = 1 ether;
        uint256 gons_ = receipt.gonsOf(address(bonds));
        migration.donateMigrationCapital(tokens_, amounts_, 0, 1, block.timestamp);
        assertFalse(token_.callbackSucceeded());
        assertEq(token_.callbackReason(), abi.encodeWithSignature("NotAuthorized(address)", address(bonds)));
        assertEq(bonds.positionOf(id_).claimedPrincipal, 0);
        assertEq(receipt.gonsOf(address(bonds)), gons_);
        // The same genuine contract holder succeeds after the outer transaction is finished.
        assertEq(token_.claim(IDetfBondNFT(address(bonds)), id_, address(this)), principal_);
        assertEq(receipt.balanceOf(address(this)), principal_);
    }

    /// @notice N1: catches a token callback replacing prices between payment and settlement.
    function test_N1_unauthorizedPricingCallbackCannotMutateBookOrCredit() public {
        _fundAndCapture();
        _configure(address(this), 1 ether, bytes32("priced-original"));
        bytes memory book_ = abi.encode(migration.migrationWeightedPricing());
        bytes memory config_ = abi.encode(migration.independentAllocation(address(this)));
        uint256 supply_ = IERC20(detf).totalSupply();
        _armContribution(false, detf, abi.encodeCall(Allocation.setMigrationWeightedPricing, (_manualInputs())));
        IERC20[] memory tokens_ = new IERC20[](1);
        tokens_[0] = IERC20(pairB);
        uint256[] memory amounts_ = new uint256[](1);
        amounts_[0] = 1 ether;
        migration.donateMigrationCapital(tokens_, amounts_, 0, 1, block.timestamp);
        MigrationHostileContribution token_ = MigrationHostileContribution(pairB);
        assertFalse(token_.callbackSucceeded());
        assertEq(token_.callbackReason(), abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, pairB));
        assertEq(abi.encode(migration.migrationWeightedPricing()), book_);
        assertEq(abi.encode(migration.independentAllocation(address(this))), config_);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(receipt.stakingState().totalGons, 0);
    }

    /// @notice Catches source-address spoofing creating credit from an unrelated external token.
    function test_sourceSpoofingPreservesEveryRollbackDomain() public {
        _fundAndCapture();
        bytes32 before_ = _adversarialState(address(this), 3);
        Migration.WeightedSyEntitlementInput[] memory rows_ = new Migration.WeightedSyEntitlementInput[](1);
        rows_[0] = Migration.WeightedSyEntitlementInput(bytes32("spoof"), address(this), pairB,
            1, 1 ether, 0, bytes32("synthetic"), true);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.UnsupportedWeightedSySource.selector, block.chainid, pairB));
        allocation.configureWeightedSyEntitlements(rows_, pricingId);
        _assertAdversarialUnchanged(before_, address(this), 3);
        assertFalse(migration.weightedSyEntitlement(bytes32("spoof")).configured);
    }

    /// @notice Catches a first funded child escaping rollback when the second receiver rejects.
    function test_failedSecondChildFundingRollsBackWholeBatch() public {
        _fundAndCapture();
        _configure(address(this), 1 ether, bytes32("first"));
        _configure(address(bonds), 1 ether, bytes32("rejecting-second"));
        bytes32 before_ = _adversarialState(address(this), 3);
        bytes32 childBefore_ = _adversarialState(address(bonds), 4);
        Migration.IndependentIssuanceRequest[] memory rows_ = new Migration.IndependentIssuanceRequest[](2);
        rows_[0] = Migration.IndependentIssuanceRequest(address(this),
            migration.independentAllocation(address(this)).configurationId);
        rows_[1] = Migration.IndependentIssuanceRequest(address(bonds),
            migration.independentAllocation(address(bonds)).configurationId);
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(bonds)));
        allocation.issueIndependentAllocations(rows_);
        _assertAdversarialUnchanged(before_, address(this), 3);
        _assertAdversarialUnchanged(childBefore_, address(bonds), 4);
    }

    /// @notice A0/K1: catches donation inventory being mistaken for first issuance or personal credit.
    function test_A0_K1_donationBeforeFirstIssuanceNeverCreditsNextWallet() public {
        IERC20(pairB).transfer(detf, 1 ether);
        assertEq(IERC20(detf).totalSupply(), 0);
        _fundAndCapture();
        uint256 quote_ = migration.previewOriginalCredit(1 ether, 1 ether);
        uint256 supply_ = IERC20(detf).totalSupply();
        assertEq(_configure(address(this), 1 ether, bytes32("first-paid-original")), quote_);
        assertEq(IERC20(detf).totalSupply(), supply_, "no issuance on load");
        uint256 id_ = _issue(address(this));
        assertEq(bonds.positionOf(id_).principal, quote_);
        assertEq(IERC20(detf).totalSupply() - supply_, quote_);
        assertEq(receipt.gonsOf(address(bonds)), quote_ * receipt.stakingState().gonsPerUnit);
        assertEq(migration.independentAllocation(pairB).totalCredit, 0);
    }
}
