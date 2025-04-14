// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IERC721Metadata} from "@crane/contracts/interfaces/IERC721Metadata.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";

/**
 * @title IProtocolNFTVaultProxy
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Unified proxy interface for Protocol NFT Vault.
 * @dev Combines all interfaces that the Protocol NFT Vault Diamond implements.
 */
interface IProtocolNFTVaultProxy is IProtocolNFTVault, IERC721Metadata {}
