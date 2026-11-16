// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IUniswapV4HookStagedPairInit} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {IUniswapV4HookDiamondPackageCallBackFactory as HookFactory} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {IUniswapV4StandardExchangeWeightedBufferHookPackage as Package} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {UniswapV4StandardExchangeWeightedBufferHookTestDeployLib as Deploy} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTestDeployLib.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";
import {RateProviderFixtureLib} from "contracts/test/libs/RateProviderFixtureLib.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";

/// @notice Real weighted package adapter sharing the H/P fixture's PoolManager.
library FullSpreadSameManagerWeightedFixture {
    function deploy(SeMatrixFixture.Ctx memory c, address manager, address vault, address face, address raw, address owner)
        external returns (address hook)
    {
        (HookFactory factory, Package pkg) = _package(c);
        Package.PkgArgs memory args;
        args.poolManager = manager;
        args.feeOracle = address(c.indexedexManager);
        args.n = 2;
        args.tokens = new address[](2);
        args.tokens[0] = face < raw ? face : raw;
        args.tokens[1] = face < raw ? raw : face;
        args.weights = new uint256[](2);
        args.weights[0] = 0.5e18;
        args.weights[1] = 0.5e18;
        args.standardExchanges = new address[](2);
        args.standardExchanges[face < raw ? 0 : 1] = vault;
        args.rateProviders = RateProviderFixtureLib.providersFor(c.create3Factory, c.create3Factory.diamondPackageFactory(), args.tokens, args.standardExchanges);
        args.tokenDecimals = HookPkgArgsDecimalsLib.tokenDecimals(args.tokens);
        args.seDecimals = HookPkgArgsDecimalsLib.seDecimals(args.standardExchanges);
        args.ownerOnlyLiquidity = true;
        args.owner = owner;
        hook = Deploy.deployHookInstance(factory, pkg, args);
        IUniswapV4HookStagedPairInit(hook).deployPair(face, raw);
        require(IUniswapV4HookStagedPairInit(hook).finalizeInitialization(), "weighted finalized");
    }

    function _package(SeMatrixFixture.Ctx memory c) private returns (HookFactory, Package) {
        return Deploy.deployFactoryAndPackage(c.create3Factory, c.owner, address(c.indexedexManager),
            c.erc20Facet, c.erc5267Facet, c.erc2612Facet, c.multiAssetBasicVaultFacet, c.multiAssetStandardVaultFacet,
            IFacetRegistry(address(c.create3Factory)).canonicalFacet(type(IMultiStepOwnable).interfaceId));
    }
}
