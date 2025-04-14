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

import {IRICHIR} from "contracts/interfaces/IRICHIR.sol";

/**
 * @title IRICHIRProxy
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Unified proxy interface for RICHIR rebasing token.
 * @dev Combines all interfaces that the RICHIR Diamond implements.
 */
interface IRICHIRProxy is IRICHIR, IERC20Permit, IERC5267 {}
