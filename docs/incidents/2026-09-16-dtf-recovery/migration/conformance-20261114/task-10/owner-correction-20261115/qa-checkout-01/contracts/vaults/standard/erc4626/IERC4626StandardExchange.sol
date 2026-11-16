// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";

/**
 * @title IERC4626StandardExchange
 * @notice Marker for generic ERC-4626 Standard Exchange vaults.
 * @dev SE asset is the protocol vault; vaultTokens = [protocolVault, asset()].
 */
interface IERC4626StandardExchange {
    function protocolVault() external view returns (IERC4626);
}
