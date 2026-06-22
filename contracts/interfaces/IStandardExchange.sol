// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";

/**
 * @title IStandardExchange
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Combined interface for standard exchange operations (both in and out).
 */
interface IStandardExchange is IStandardExchangeIn, IStandardExchangeOut {}
