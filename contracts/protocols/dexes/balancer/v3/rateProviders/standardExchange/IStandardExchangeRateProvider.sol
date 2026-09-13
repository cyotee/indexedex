// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";

interface IStandardExchangeRateProvider is IRateProvider {
    function reserveVault() external view returns (IStandardExchange);
    function rateTarget() external view returns (IERC20);
}
