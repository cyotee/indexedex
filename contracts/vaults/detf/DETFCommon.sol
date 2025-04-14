// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                   Imports                                  */
/* -------------------------------------------------------------------------- */

/* --------------------------- Imported Constants --------------------------- */

/* ----------------------------- Imported Types ----------------------------- */

/* ---------------------------- Imported Events ----------------------------- */

/* ----------------------------- Imported Errors ---------------------------- */

/* --------------------------- Imported Interfaces -------------------------- */

import {IProtocolDETFErrors} from "contracts/interfaces/IProtocolDETFErrors.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";

/* --------------------------- Imported Libraries --------------------------- */

/* --------------------------- Imported Contracts --------------------------- */

/* -------------------------------------------------------------------------- */
/*                                  Contracts                                 */
/* -------------------------------------------------------------------------- */

abstract contract DETFCommon is IStandardExchangeErrors, IProtocolDETFErrors {

}
