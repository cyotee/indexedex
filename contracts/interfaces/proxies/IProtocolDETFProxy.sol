// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";

/**
 * @title IProtocolDETFProxy
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Unified proxy interface for Protocol DETF (CHIR token).
 * @dev Combines all interfaces that the Protocol DETF Diamond implements.
 */
interface IProtocolDETFProxy is
    IProtocolDETF,
    IERC20,
    IERC20Metadata,
    IERC20Permit,
    IERC5267,
    IERC4626,
    IStandardExchangeIn,
    IStandardExchangeOut,
    IBasicVault,
    IStandardVault
{}
