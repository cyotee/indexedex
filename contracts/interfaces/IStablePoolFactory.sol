// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IBasePoolFactory} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBasePoolFactory.sol";
import {TokenConfig, PoolRoleAccounts} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";

/// @notice Balancer V3 stable pool factory surface used by IndexedEx packages.
interface IStablePoolFactory is IBasePoolFactory {
    function create(
        string memory name,
        string memory symbol,
        TokenConfig[] memory tokens,
        uint256 amplificationParameter,
        PoolRoleAccounts memory roleAccounts,
        uint256 swapFeePercentage,
        address poolHooksContract,
        bool enableDonation,
        bool disableUnbalancedLiquidity,
        bytes32 salt
    ) external returns (address pool);
}
