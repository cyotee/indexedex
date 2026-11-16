// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeRateProviderDFPkg} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/IStandardExchangeRateProviderDFPkg.sol";
import {IStandardExchangeRateProvider} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/IStandardExchangeRateProvider.sol";

library Phase_07_Stage_03_FeeAccrualRateProviders {
    function execute(IDiamondPackageCallBackFactory factory, IStandardExchangeRateProviderDFPkg pkg,
        address vault, address target
    ) internal returns (address provider) {
        bytes memory args = abi.encode(IStandardExchangeRateProviderDFPkg.PkgArgs({
            reserveVault: IStandardExchange(vault), rateSubject: IERC20(address(0)), rateTarget: IERC20(target)
        }));
        provider = factory.calcAddress(IDiamondFactoryPackage(address(pkg)), args);
        if (provider.code.length == 0) {
            require(address(pkg.deployRateProvider(IStandardExchange(vault), IERC20(target))) == provider, "Provider: prediction mismatch");
        }
        require(address(IStandardExchangeRateProvider(provider).reserveVault()) == vault, "Provider: wrong subject");
        require(address(IStandardExchangeRateProvider(provider).rateTarget()) == target, "Provider: wrong target");
        // Empty SEs legitimately quote zero. Nonzero rate is a post-bootstrap requirement.
    }
}
