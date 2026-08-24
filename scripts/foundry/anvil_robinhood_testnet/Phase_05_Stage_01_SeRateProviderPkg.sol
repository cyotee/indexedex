// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchState} from "./LaunchState.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    StandardExchangeRateProvider_FactoryService
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProvider_FactoryService.sol";

/// @title Phase_05_Stage_01_SeRateProviderPkg
/// @notice Shared SE rate-provider DFPkg.
library Phase_05_Stage_01_SeRateProviderPkg {
    using StandardExchangeRateProvider_FactoryService for ICreate3FactoryProxy;

    function execute(LaunchState storage s) internal {
        IFacet rateProviderFacet = s.create3Factory.deployStandardExchangeRateProviderFacet();
        s.rateProviderPkg =
            s.create3Factory.deployStandardExchangeRateProviderDFPkg(rateProviderFacet, s.diamondPackageFactory);
    }
}
