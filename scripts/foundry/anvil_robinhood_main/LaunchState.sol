// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    IStandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";
import {IUniswapV4StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";

/// @title LaunchState
/// @notice In-memory bag for architecture groups and Script_SimulateArchitecture.
/// @dev Packages only. No token or DETF instance fields.
struct LaunchState {
    ICreate3FactoryProxy create3Factory;
    IDiamondPackageCallBackFactory diamondPackageFactory;
    IUniswapV4HookDiamondPackageCallBackFactory hookFactory;
    IFacet hookFlagsFacet;
    IFacet erc20Facet;
    IFacet erc2612Facet;
    IFacet erc5267Facet;
    IFacet erc4626Facet;
    IFacet erc4626BasicVaultFacet;
    IFacet erc4626StandardVaultFacet;
    IFacet multiAssetBasicVaultFacet;
    IFacet multiAssetStandardVaultFacet;
    IFacet multiStepOwnableFacet;
    IFacet operableFacet;
    IFacet diamondCutFacet;
    IFeeCollectorProxy feeCollector;
    IIndexedexManagerProxy indexedexManager;
    IStandardExchangeRateProviderDFPkg rateProviderPkg;
    address cpHookPkg;
    IUniswapV4StandardExchangeDFPkg uniV4SePkg;
    address bondNftVaultPkg;
    address rebasingClaimTokenPkg;
    address cpDetfPkg;
    address curveQuadHookPkg;
    address curveQuadDetfPkg;
}
