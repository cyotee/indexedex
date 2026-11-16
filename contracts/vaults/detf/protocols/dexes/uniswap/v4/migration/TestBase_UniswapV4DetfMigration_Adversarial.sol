// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {TestBase_UniswapV4DetfMigration} from "./TestBase_UniswapV4DetfMigration.sol";

/// @notice External callback controls; the deployed token is never a substitute for a product.
interface IMigrationHostileContribution {
    function arm(bool shortReceipt, address parent, address callback, bytes calldata payload) external;
}

/// @notice Shared real-registry hostile currency and complete rollback observations.
/// @dev Migration has no generic user-calldata forwarding surface (M1-M3).
/// Stage 1 owner purchase hard-rejects public pretransfer, including excess (I1-I3).
/// Donation/bootstrap has no max-minus-used refund (E6); donation theft is tested as K1.
/// Legacy-source successes remain pinned forks; a synthetic token cannot waive a source category.
abstract contract TestBase_UniswapV4DetfMigration_Adversarial is TestBase_UniswapV4DetfMigration {
    function _deployContributionFixture() internal virtual override returns (address) {
        return create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "MigrationHostileContribution.t.sol:MigrationHostileContribution"),
            "", keccak256("migration.hostile.external")
        );
    }

    function _armContribution(bool short_, address callback_, bytes memory payload_) internal {
        IMigrationHostileContribution(pairB).arm(short_, detf, callback_, payload_);
    }

    /// @dev Independent observation of assets, booked inventory, allocation, issuance, funding and routes.
    /// Includes the next NFT owner to detect an escaped child mint even when supply is restored.
    function _adversarialState(address actor_, uint256 nextId_) internal view returns (bytes32) {
        // Unset pricing is a valid pre-bootstrap state whose exact getter error must also stay unchanged.
        (bool priced_, bytes memory pricing_) = detf.staticcall(abi.encodeWithSignature("migrationWeightedPricing()"));
        bytes32 custody_ = keccak256(abi.encode(
            IERC20(pairA).balanceOf(actor_), IERC20(pairB).balanceOf(actor_),
            IERC20(pairA).balanceOf(detf), IERC20(pairB).balanceOf(detf),
            IERC20(pairA).allowance(actor_, detf), IERC20(pairB).allowance(actor_, detf),
            migration.migrationDonationInventory(IERC20(pairA)),
            migration.migrationDonationInventory(IERC20(pairB)),
            IERC20(migration.hook()).balanceOf(address(bonds))
        ));
        bytes32 credit_ = keccak256(abi.encode(
            migration.independentAllocation(actor_), migration.independentIssuance(actor_),
            priced_, pricing_, migration.migrationOwnerFirstBondTokenId(),
            migration.migrationActivated()
        ));
        bytes32 funding_ = keccak256(abi.encode(
            IERC20(detf).totalSupply(), IERC20(detf).balanceOf(address(receipt)),
            receipt.stakingState(), receipt.gonsOf(actor_), receipt.gonsOf(address(bonds)),
            receipt.gonsOf(address(receipt)), bonds.attributedBondGons(),
            IERC721(address(bonds)).ownerOf(nextId_)
        ));
        return keccak256(abi.encode(custody_, credit_, funding_, IDiamondLoupe(detf).facets()));
    }

    function _assertAdversarialUnchanged(bytes32 before_, address actor_, uint256 nextId_) internal view {
        assertEq(_adversarialState(actor_, nextId_), before_,
            "rollback: custody credit supply backing gons NFT and cuts");
    }
}
