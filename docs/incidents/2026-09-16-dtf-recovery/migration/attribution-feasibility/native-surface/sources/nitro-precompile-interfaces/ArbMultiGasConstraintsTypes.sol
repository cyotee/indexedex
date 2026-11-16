// Copyright 2025, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE
// SPDX-License-Identifier: BUSL-1.1

pragma solidity >=0.4.21 <0.9.0;

/// @title ArbMultiGasConstraintsTypes
/// @notice Type definitions for configuring and inspecting multi-dimensional gas pricing constraints.
/// @dev These structures are shared by the `ArbOwner` and `ArbGasInfo` precompiles.
library ArbMultiGasConstraintsTypes {
    /// @notice Enumerates the distinct resource kinds used for multi-dimensional gas accounting.
    /// @dev The numeric values of this enum must remain consistent with the corresponding
    /// @dev The values defined here must stay synchronized with `go-ethereum/arbitrum/multigas/resources.go`.
    enum ResourceKind {
        Unknown,
        Computation,
        HistoryGrowth,
        StorageAccessRead,
        StorageAccessWrite,
        StorageGrowth,
        SingleDim,
        L2Calldata,
        WasmComputation
    }

    /// @notice Defines the relative contribution of a specific resource type within a constraint.
    /// @param resource  The resource kind being weighted.
    /// @param weight    The proportional weight that determines this resource kind’s influence on backlog growth.
    struct WeightedResource {
        ResourceKind resource;
        uint64 weight;
    }

    /// @notice Describes a single pricing constraint that applies to one or more weighted resources.
    /// @param resources             The list of weighted resources that participate in this constraint.
    /// @param adjustmentWindowSecs  Time window (seconds) over which the price rises by a factor of e if demand is 2x the target (uint64, seconds)
    /// @param targetPerSec          The target gas usage per second for this constraint (uint64, gas/sec).
    /// @param backlog               The current or initial backlogfor this constraint (uint64, gas units).
    struct ResourceConstraint {
        WeightedResource[] resources;
        uint32 adjustmentWindowSecs;
        uint64 targetPerSec;
        uint64 backlog;
    }
}
