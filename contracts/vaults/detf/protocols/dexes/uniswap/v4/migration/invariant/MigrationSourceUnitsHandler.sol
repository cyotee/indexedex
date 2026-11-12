// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MigrationSourceUnitsLedger} from "./MigrationSourceUnitsLedger.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
import {IERC721Receiver} from "@crane/contracts/interfaces/IERC721Receiver.sol";
import {IERC721Errors} from "@crane/contracts/interfaces/IERC721Errors.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation}
    from "../interfaces/IUniswapV4DetfMigration.sol";
import {IMigrationWeightedReceipt, IMigrationWeightedSynchronization} from "../legacy/IMigrationLegacyRecovery.sol";
import {MigrationLegacyRecoveryLib as Legacy} from "../legacy/MigrationLegacyRecoveryLib.sol";

/// @notice Actual fixed-source pulls, canonical-origin exclusion and exact independent credit.
/// @dev This contract is a synthetic ordinary original wallet, never a claimed-SY source wallet.
contract MigrationSourceUnitsHandler is MigrationSourceUnitsLedger, IERC721Receiver {
    bool internal rejectBond;
    bool private initialized;
    uint256 public callbacks;
    uint256 public enrollmentRejections;
    uint256[2] internal creditAnchors;

    constructor(Migration m_) MigrationSourceUnitsLedger(m_) {}

    /// @notice Original eligible units and credit anchors are explicit fixture inputs.
    function initialize(uint256[9] calldata quantities_, uint256[2] calldata credits_) external {
        require(!initialized, "one fixture initialization");
        initialized = true;
        creditAnchors = credits_;
        for (uint256 i_; i_ < 9; ++i_) {
            Row storage r_ = rows[i_];
            r_.origin = keccak256(abi.encode("stateful fixed source original", source(i_)));
            r_.originalQ = quantities_[i_]; r_.q = quantities_[i_];
            r_.originalC = credits_[0]; r_.c = credits_[0];
            r_.walletFloor = units(i_, address(this)) - quantities_[i_];
            r_.custodyFloor = units(i_, address(parent));
            IERC20(source(i_)).approve(address(parent), type(uint256).max);
            r_.allowance = type(uint256).max;
            _configure(i_, 0);
        }
        assertAll();
    }

    function _input(uint256 i_, uint256 variant_) internal view returns (Migration.WeightedLiquidEntitlementInput memory) {
        return Migration.WeightedLiquidEntitlementInput(rows[i_].origin, address(this), source(i_),
            rows[i_].originalQ, (variant_ + 1) * 0.01 ether, 0,
            keccak256("synthetic complete original; genuine admitted acquisition; no historical award"), true);
    }

    function _configure(uint256 i_, uint256 variant_) private {
        Migration.WeightedLiquidEntitlementInput[] memory inputs_ = new Migration.WeightedLiquidEntitlementInput[](1);
        inputs_[0] = _input(i_, variant_);
        vm.prank(currentOwner);
        _invoke(abi.encodeWithSelector(configSelector(i_), inputs_));
        rows[i_].originalC = creditAnchors[variant_]; rows[i_].c = creditAnchors[variant_];
        rows[i_].configuration = keccak256(abi.encode(block.chainid, address(parent), parent.migrationSnapshot().id, inputs_[0]));
        rows[i_].entitlementHash = keccak256(abi.encode(true, inputs_[0], rows[i_].configuration, rows[i_].originalC));
    }

    /// @notice Actual full replacements and every competing fixed-source representation.
    function enrollmentWitness() external {
        for (uint256 i_; i_ < 9; ++i_) {
            _configure(i_, 1); _configure(i_, 0);
            for (uint256 j_; j_ < 9; ++j_) {
                if (j_ == i_) continue;
                Migration.WeightedLiquidEntitlementInput[] memory inputs_ = new Migration.WeightedLiquidEntitlementInput[](1);
                inputs_[0] = _input(i_, 0); inputs_[0].source = source(j_);
                vm.prank(currentOwner);
                _reject(abi.encodeWithSelector(configSelector(j_), inputs_),
                    abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, rows[i_].origin));
                ++enrollmentRejections;
            }
            Migration.IndependentAllocationInput[] memory a_ = new Migration.IndependentAllocationInput[](1);
            a_[0].recipient = OTHER; a_[0].evidenceId = bytes32("distinct recipient cannot alias");
            a_[0].entitlements = new Migration.OriginalEntitlement[](1);
            a_[0].entitlements[0] = Migration.OriginalEntitlement(rows[i_].origin, 0.01 ether, 0, bytes32("alias"));
            vm.prank(currentOwner);
            _reject(abi.encodeCall(Allocation.configureIndependentAllocations, (a_)),
                abi.encodeWithSelector(Migration.DuplicateOriginalEntitlement.selector, rows[i_].origin));
            ++enrollmentRejections;
        }
        assertAll();
    }

    function surrender(uint256 index_, uint256 seed_) public {
        uint256 i_ = index_ % 9;
        _settleSource(i_);
        uint256 max_ = nativeMaximum(i_);
        if (max_ == 0) { rejectExcess(i_); return; }
        uint256 n_ = max_ / (seed_ % 4 + 1);
        if (n_ == 0) n_ = 1;
        uint256 q_ = eligibleUnits(i_, n_);
        Row storage r_ = rows[i_];
        uint256 c_ = q_ == r_.q ? r_.c : Math.mulDiv(r_.c, q_, r_.q);
        if (c_ == 0) {
            _reject(_payload(i_, r_.origin, n_, 0), abi.encodeWithSelector(invalidRecord(i_), r_.origin));
            ++rejectionCounts[i_];
        } else {
            bytes memory result_ = _invoke(_payload(i_, r_.origin, n_, c_));
            (uint256 id_, uint256 paid_) = abi.decode(result_, (uint256, uint256));
            assertEq(paid_, c_);
            r_.q -= q_; r_.c -= c_; r_.delivered += c_; r_.inventory += q_;
            r_.allowance -= n_;
            if (i_ == 2) wsNative = r_.inventory / IMigrationWeightedReceipt(source(i_)).stakingState().gonsPerUnit;
            issued += c_; positionGons += c_ * k;
            positions.push(Position(id_, c_, 0, c_ * k, block.timestamp, address(this), false));
            ++surrenderSuccesses[i_];
        }
        assertAll();
    }

    function missingRecord(uint256 index_) public {
        uint256 i_ = index_ % 9;
        bytes32 before_ = economicState();
        _reject(_payload(i_, bytes32("absent"), 1, 0), abi.encodeWithSelector(invalidRecord(i_), bytes32("absent")));
        assertEq(economicState(), before_); ++rejectionCounts[i_];
        assertAll();
    }

    function rejectControls(uint256 index_) public {
        uint256 i_ = index_ % 9;
        missingRecord(i_); _settleSource(i_);
        uint256 n_ = nativeMaximum(i_) / 4;
        if (n_ == 0) { rejectExcess(i_); return; }
        IERC20(source(i_)).approve(address(parent), 0);
        bytes32 before_ = economicState();
        _reject(_payload(i_, rows[i_].origin, n_, 0),
            i_ == 3 || i_ >= 6 ? abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(parent), 0, n_)
                : abi.encodeWithSignature("TransferFromFailed()"));
        assertEq(economicState(), before_); ++rejectionCounts[i_];
        IERC20(source(i_)).approve(address(parent), type(uint256).max);
        rows[i_].allowance = type(uint256).max;
        assertTrue(IERC20(source(i_)).transfer(OTHER, n_));
        before_ = economicState();
        vm.prank(OTHER);
        _reject(_payload(i_, rows[i_].origin, n_, 0),
            abi.encodeWithSelector(wrongWallet(i_), OTHER, address(this)));
        assertEq(economicState(), before_); ++rejectionCounts[i_];
        vm.prank(OTHER); assertTrue(IERC20(source(i_)).transfer(address(this), n_));
        transfers += 2;
        assertAll();
    }

    function rejectExcess(uint256 index_) public {
        uint256 i_ = index_ % 9;
        _settleSource(i_);
        uint256 n_ = nativeMaximum(i_) + 1;
        bytes memory error_ = (i_ == 2 || i_ == 3) && rows[i_].q == 0
            ? abi.encodeWithSelector(invalidRecord(i_), rows[i_].origin)
            : abi.encodeWithSelector(quantityError(i_), eligibleUnits(i_, n_), rows[i_].q);
        bytes32 before_ = economicState();
        _reject(_payload(i_, rows[i_].origin, n_, 0), error_);
        assertEq(economicState(), before_); ++rejectionCounts[i_];
        assertAll();
    }

    function failedIssuance(uint256 index_) public {
        uint256 i_ = index_ % 9;
        _settleSource(i_);
        uint256 n_ = nativeMaximum(i_) / 2;
        if (n_ == 0) { rejectExcess(i_); return; }
        uint256 q_ = eligibleUnits(i_, n_);
        uint256 credit_ = q_ == rows[i_].q ? rows[i_].c : Math.mulDiv(rows[i_].c, q_, rows[i_].q);
        bytes32 before_ = economicState();
        if (credit_ == 0) {
            _reject(_payload(i_, rows[i_].origin, n_, 0), abi.encodeWithSelector(invalidRecord(i_), rows[i_].origin));
            assertEq(economicState(), before_); ++rejectionCounts[i_]; assertAll();
            return;
        }
        rejectBond = true;
        vm.expectCall(address(receipt), abi.encodeWithSignature(
            "exchangeIn(address,uint256,address,uint256,address,bool,uint256)", address(parent), credit_,
            address(receipt), credit_, address(bonds), false, block.timestamp));
        _reject(_payload(i_, rows[i_].origin, n_, credit_),
            abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(this)));
        rejectBond = false;
        assertEq(economicState(), before_); ++rejectionCounts[i_]; ++fundingRollbacks[i_];
        assertAll();
    }

    function removedConfiguration(uint256 index_) public {
        uint256 i_ = index_ % 9;
        Migration.WeightedLiquidEntitlementInput[] memory a_ = new Migration.WeightedLiquidEntitlementInput[](1);
        a_[0] = _input(i_, 1);
        bytes32 before_ = economicState();
        vm.prank(currentOwner);
        _reject(abi.encodeWithSelector(configSelector(i_), a_),
            abi.encodeWithSignature("NoTargetFor(bytes4)", configSelector(i_)));
        assertEq(economicState(), before_); ++rejectionCounts[i_];
        assertAll();
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        require(msg.sender == address(bonds), "actual new funded bond child");
        _reject(abi.encodeCall(Migration.surrenderMigrationWeightedLiquid, (rows[0].origin, 1, 0, block.timestamp)),
            abi.encodeWithSignature("IsLocked()"));
        _reject(abi.encodeCall(Allocation.activateMigration, ()),
            abi.encodeWithSignature("NoTargetFor(bytes4)", Allocation.activateMigration.selector));
        ++callbacks;
        return rejectBond ? bytes4(0) : IERC721Receiver.onERC721Received.selector;
    }

    function _settleSource(uint256 i_) internal {
        if (i_ == 2) IMigrationWeightedSynchronization(Legacy.WEIGHTED_DETF).synchronizeRewards();
    }
    function _payload(uint256 i_, bytes32 origin_, uint256 n_, uint256 min_) internal view returns (bytes memory) {
        return abi.encodeWithSelector(surrenderSelector(i_), origin_, n_, min_, block.timestamp);
    }
    function _invoke(bytes memory payload_) internal returns (bytes memory result_) {
        bool ok_; (ok_, result_) = address(parent).call(payload_);
        if (!ok_) assembly ("memory-safe") { revert(add(result_, 32), mload(result_)) }
    }
    function _reject(bytes memory payload_, bytes memory expected_) internal {
        (bool ok_, bytes memory actual_) = address(parent).call(payload_);
        assertFalse(ok_, "invalid action unexpectedly succeeded");
        assertEq(actual_, expected_, "exact rejected action error");
    }
    function economicState() public view returns (bytes32) {
        bytes memory state_ = abi.encode(IERC20(address(parent)).totalSupply(), receipt.stakingState(),
            receipt.gonsOf(address(bonds)), IERC20(address(parent)).balanceOf(address(receipt)));
        for (uint256 i_; i_ < 9; ++i_) {
            (bool ok_, bytes memory surrender_) = address(parent).staticcall(abi.encodeWithSelector(querySelector(i_), rows[i_].origin));
            require(ok_, "actual retained query");
            state_ = abi.encode(state_, surrender_, units(i_, address(this)), units(i_, address(parent)), units(i_, OTHER),
                IERC20(source(i_)).allowance(address(this), address(parent)), recovery.migrationRecoveryInventory(source(i_)));
        }
        return keccak256(abi.encode(state_, recovery.migrationRecoveryGons(), recovery.migrationEarlierReceiptInternalShares(),
            IERC20(Legacy.DTF).balanceOf(address(parent)), IERC20(Legacy.WEIGHTED_SY).balanceOf(address(parent))));
    }
}
