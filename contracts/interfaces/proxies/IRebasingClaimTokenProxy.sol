// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";

/**
 * @title IRebasingClaimTokenProxy
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Unified proxy interface for rebasing claim token rebasing token.
 * @dev Combines all interfaces that the rebasing claim token Diamond implements.
 */
interface IRebasingClaimTokenProxy is IRebasingClaimToken, IERC20Permit, IERC5267 {}
