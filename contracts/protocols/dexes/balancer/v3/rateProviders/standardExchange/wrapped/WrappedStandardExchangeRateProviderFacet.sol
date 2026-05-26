// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

import {
	WrappedStandardExchangeRateProviderTarget,
	IWrappedStandardExchangeRateProvider
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/wrapped/WrappedStandardExchangeRateProviderTarget.sol";

contract WrappedStandardExchangeRateProviderFacet is WrappedStandardExchangeRateProviderTarget, IFacet {
	function facetName() public pure returns (string memory name_) {
		return type(WrappedStandardExchangeRateProviderFacet).name;
	}

	function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
		interfaces_ = new bytes4[](2);
		interfaces_[0] = type(IRateProvider).interfaceId;
		interfaces_[1] = type(IWrappedStandardExchangeRateProvider).interfaceId;
	}

	function facetFuncs() public pure returns (bytes4[] memory funcs_) {
		funcs_ = new bytes4[](4);
		funcs_[0] = IRateProvider.getRate.selector;
		funcs_[1] = IWrappedStandardExchangeRateProvider.rateSubject.selector;
		funcs_[2] = IWrappedStandardExchangeRateProvider.standardExchange.selector;
		funcs_[3] = IWrappedStandardExchangeRateProvider.rateTarget.selector;
	}

	function facetMetadata()
		external
		pure
		returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory functions_)
	{
		name_ = facetName();
		interfaces_ = facetInterfaces();
		functions_ = facetFuncs();
	}
}