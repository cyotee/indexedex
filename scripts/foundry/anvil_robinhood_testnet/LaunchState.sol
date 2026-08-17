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
    address orbitalHookPkg;
    address weightedHookPkg;
    address singleSeBufferHookPkg;
    IUniswapV4StandardExchangeDFPkg uniV4SePkg;
    address bondNftVaultPkg;
    address rebasingClaimTokenPkg;
    address cpDetfPkg;
    address orbitalDetfPkg;
    address weightedDetfPkg;
    address curveQuadHookPkg;
    address curveQuadDetfPkg;
    address erc20MinterFacade;
    address tokenPkg;
    address ttUSDG;
    address ttUSDE;
    address ttNVDA;
    address ttMSFT;
    address ttAAPL;
    address ttGOOGL;
    address ttAMZN;
    address ttMETA;
    address ttTSLA;
    address ttSMH;
    address ttSPY;
    address ttVTI;
    address ttQQQ;
    address ttRICH;
    address seNvdaUsdg;
    address seSpyUsdg;
    address seUsdeWeth;
    address seUsdgWeth;
    address seUsdgUsde;
    address seM7Usdg;
    address seIdxUsdg;
    address seRichWeth;
    address rpNvdaUsdg;
    address rpSpyUsdg;
    address rpUsdeWeth;
    address rpUsdgWeth;
    address rpUsdgUsde;
    address rpM7Usdg;
    address rpIdxUsdg;
    address rpRichWeth;
    address v4Seeder;
    address ttNvdaS;
    address ttNvdaSmhO;
    address ttIdxQ;
    address ttM7W;
    address ttDolQ;
    address ttNestW;
    address ttBetaO;
    address ttIdxWrap;
    address ttM7Wrap;
    address ttRichS;
}
