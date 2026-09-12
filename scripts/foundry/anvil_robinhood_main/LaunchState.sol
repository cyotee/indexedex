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
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {
    IUniswapV4MultiPoolTwapOracleDFPkg
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracleDFPkg.sol";

/// @title LaunchState
/// @notice Architecture bag: factories, manager, TWAP, SE pkgs, hook pkgs, DETF pkgs.
/// @dev TokenStaking package fields are opt-in (Phase 06-08 / 08-01). No Protocol DETF instances.
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
    IFacet twapOracleFacet;
    IUniswapV4MultiPoolTwapOracleDFPkg twapOraclePkg;
    IUniswapV4MultiPoolTwapOracle twapOracle;
    address twapAdapterFactory;
    address cpHookPkg;
    IUniswapV4StandardExchangeDFPkg uniV4SePkg;
    address morphoBlueSePkg;
    address uniV3SePkg;
    address uniV2SePkg;
    address bondNftVaultPkg;
    address rebasingClaimTokenPkg;
    address uniV4DetfPkg;
    address weightedHookPkg;
    address orbitalHookPkg;
    address curveQuadHookPkg;
    IFacet tokenStakingFacet;
    IFacet rebasingAwareErc4626Facet;
    IFacet rebasingAwareSeFacet;
    IFacet rebasingAwareSyFacet;
    IFacet rebasingAwareMetadataFacet;
    IFacet rebasingAwareQuoteFacet;
    address rebasingAwareErc4626Pkg;
    string rebasingAwareReleaseId;
    bytes32 rebasingAwareConstructorFingerprint;
    bytes32 rebasingAwareImplFingerprint;
    address tokenStakingPkg;
    address tokenStaking;
}
