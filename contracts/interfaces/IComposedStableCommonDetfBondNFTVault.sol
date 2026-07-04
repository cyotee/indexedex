// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IDetfProtocolNftInventoryPolicy} from "contracts/vaults/detf/inventory/IDetfProtocolNftInventoryPolicy.sol";

interface IComposedStableCommonDetfBondNFTVault is IDETFNFTVault, IDetfProtocolNftInventoryPolicy {

    function deploymentTimestamp() external view returns (uint256 timestamp);
}