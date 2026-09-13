// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";

interface IStandardExchangeRateProviderDFPkg is IDiamondFactoryPackage {
    struct PkgInit {
        IFacet rateProviderFacet;
        IDiamondPackageCallBackFactory diamondFactory;
    }

    struct PkgArgs {
        IStandardExchange reserveVault;
        /// @dev Optional share subject for rate quotes; address(0) → vault address (self-share SE vaults).
        IERC20 rateSubject;
        IERC20 rateTarget;
    }

    function deployRateProvider(IStandardExchange reserveVault, IERC20 rateTarget)
        external
        returns (IRateProvider rateProviderAddress);

    function deployRateProvider(IStandardExchange reserveVault, IERC20 rateSubject, IERC20 rateTarget)
        external
        returns (IRateProvider rateProviderAddress);
}
