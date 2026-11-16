// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

interface IWrappedStandardExchangeRateProvider is IRateProvider {
	function rateSubject() external view returns (IERC4626);
	function standardExchange() external view returns (IStandardExchangeIn);
	function rateTarget() external view returns (IERC20);
}
