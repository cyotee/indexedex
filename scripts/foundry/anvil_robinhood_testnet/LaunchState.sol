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
/// @notice In-memory / storage bag shared by group libraries and Script_SimulateLaunch.
/// @dev Demo products: required fee DETF `TTCHIR` and USD quad `TTDOL-Q`.
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
    address orbitalHookPkg;
    address orbitalDetfPkg;
    address weightedHookPkg;
    address weightedDetfPkg;
    address erc20MinterFacade;
    address tokenPkg;
    address ttUSDG;
    address ttUSDE;
    address ttWETH;
    address ttRICH;
    address seUsdeWeth;
    address seUsdgWeth;
    address seUsdgUsde;
    address seRichWeth;
    address rpUsdeWeth;
    address rpUsdgWeth;
    address rpUsdgUsde;
    address rpRichWeth;
    address v4Seeder;
    address ttChir;
    address ttRichir;
    address ttDolQ;
    /// @notice DETF PkgArgs.creator. Bound to the deployer so reserved bond NFT id 2 is that EOA.
    address creator;
}
