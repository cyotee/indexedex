// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IFeeCollectorSingleTokenPush} from "contracts/interfaces/IFeeCollectorSingleTokenPush.sol";
import {IFeeCollectorManager} from "contracts/interfaces/IFeeCollectorManager.sol";

interface IFeeCollectorProxy is IFeeCollectorSingleTokenPush, IFeeCollectorManager {}
