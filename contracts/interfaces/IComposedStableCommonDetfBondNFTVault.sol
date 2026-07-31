// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IDetfNftInventoryPolicy} from "contracts/vaults/detf/common/inventory/IDetfNftInventoryPolicy.sol";

interface IComposedStableCommonDetfBondNFTVault is IDETFNFTVault, IDetfNftInventoryPolicy {

    function deploymentTimestamp() external view returns (uint256 timestamp);
}