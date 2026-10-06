// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

/// @notice CREATE3 component deployment using freshly built runtime artifacts.
library UniswapV4UpperLowerWingsStandardExchangeVaultComponent_FactoryService {
    function deployQueryFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return IFacet(factory_.create3WithArgs(
            ArtifactCreationCode.creationCode(factory_, "UniswapV4UpperLowerWingsStandardExchangeVaultQueryFacet.sol:UniswapV4UpperLowerWingsStandardExchangeVaultQueryFacet"),
            "", keccak256("UniswapV4UpperLowerWingsStandardExchangeVault.QueryFacet")
        ));
    }
    function deployExecutionDelegate(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return IFacet(factory_.create3WithArgs(
            ArtifactCreationCode.creationCode(factory_, "UniswapV4UpperLowerWingsStandardExchangeVaultExecutionDelegate.sol:UniswapV4UpperLowerWingsStandardExchangeVaultExecutionDelegate"),
            "", keccak256("UniswapV4UpperLowerWingsStandardExchangeVault.ExecutionDelegate")
        ));
    }

    function deployInFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return IFacet(factory_.create3WithArgs(
            ArtifactCreationCode.creationCode(factory_, "UniswapV4UpperLowerWingsStandardExchangeVaultInFacet.sol:UniswapV4UpperLowerWingsStandardExchangeVaultInFacet"),
            "", keccak256("UniswapV4UpperLowerWingsStandardExchangeVault.InFacet")
        ));
    }

    function deployOutFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return IFacet(factory_.create3WithArgs(
            ArtifactCreationCode.creationCode(factory_, "UniswapV4UpperLowerWingsStandardExchangeVaultOutFacet.sol:UniswapV4UpperLowerWingsStandardExchangeVaultOutFacet"),
            "", keccak256("UniswapV4UpperLowerWingsStandardExchangeVault.OutFacet")
        ));
    }

    function deploySYFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return IFacet(factory_.create3WithArgs(
            ArtifactCreationCode.creationCode(factory_, "UniswapV4UpperLowerWingsStandardExchangeVaultSYFacet.sol:UniswapV4UpperLowerWingsStandardExchangeVaultSYFacet"),
            "", keccak256("UniswapV4UpperLowerWingsStandardExchangeVault.SYFacet")
        ));
    }

    function deployRebalanceFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return IFacet(factory_.create3WithArgs(
            ArtifactCreationCode.creationCode(factory_, "UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceFacet.sol:UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceFacet"),
            "", keccak256("UniswapV4UpperLowerWingsStandardExchangeVault.RebalanceFacet")
        ));
    }

    function deployTransitionFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return IFacet(factory_.create3WithArgs(
            ArtifactCreationCode.creationCode(factory_, "UniswapV4UpperLowerWingsStandardExchangeVaultTransitionFacet.sol:UniswapV4UpperLowerWingsStandardExchangeVaultTransitionFacet"),
            "", keccak256("UniswapV4UpperLowerWingsStandardExchangeVault.TransitionFacet")
        ));
    }
    function deployEconomicFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return IFacet(factory_.create3WithArgs(
            ArtifactCreationCode.creationCode(factory_, "UniswapV4UpperLowerWingsStandardExchangeVaultEconomicFacet.sol:UniswapV4UpperLowerWingsStandardExchangeVaultEconomicFacet"),
            "", keccak256("UniswapV4UpperLowerWingsStandardExchangeVault.EconomicFacet")
        ));
    }
}
