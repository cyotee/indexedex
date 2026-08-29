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
/// @notice In-memory / storage bag shared by Phase Stage libraries.
/// @dev Demo products: required fee DETF `DTF-DETF` and USD quad `TTDOL-Q`.
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
    address bondNftVaultPkg;
    address rebasingClaimTokenPkg;
    address uniV4DetfPkg;
    address curveQuadHookPkg;
    address orbitalHookPkg;
    address weightedHookPkg;
    address morpho;
    address morphoIrm;
    address morphoOracle;
    address morphoBlueSePkg;
    /// @notice True when 03c deployed Morpho Blue on this chain (pin had no code).
    bool morphoLocal;
    address v3Factory;
    address uniV3SePkg;
    /// @notice True when 03d deployed UniswapV3Factory on this chain (no canonical V3).
    bool v3Local;
    address erc20MinterFacade;
    address tokenPkg;
    address ttUSDG;
    address ttUSDE;
    address ttWETH;
    address ttRICH;
    address ttNVDA;
    address ttMSFT;
    address ttAAPL;
    address ttGOOGL;
    address ttAMZN;
    address ttMETA;
    address ttTSLA;
    address seUsdeWeth;
    address seUsdgWeth;
    address seUsdgUsde;
    address seRichWeth;
    address rpUsdeWeth;
    address rpUsdgWeth;
    address rpUsdgUsde;
    address rpRichWeth;
    address v4Seeder;
    address dtfDetf;
    address dtfClaim;
    address ttDolQ;
    /// @notice DETF PkgArgs.creator. Bound to the deployer so reserved bond NFT id 2 is that EOA.
    address creator;
}
