// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {IDetfProtocolNftInventoryPolicy} from "contracts/vaults/detf/inventory/IDetfProtocolNftInventoryPolicy.sol";

interface IComposedStableCommonDetfBondNFTVault is IProtocolNFTVault, IDetfProtocolNftInventoryPolicy {

    function deploymentTimestamp() external view returns (uint256 timestamp);
}