// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixtureEconomics} from "./FixtureEconomics.sol";
import {LaunchState} from "./LaunchState.sol";

import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage as IBalancerHookPkg
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg as BalancerHookDFPkg
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHook_FactoryService as BalancerHookFS
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_FactoryService.sol";

/// @title Phase_06_Stage_09_BalancerStableBufferHookPkg
/// @notice Balancer Stable buffer hook DFPkg + liquidity/exit/SE/hooks facets.
library Phase_06_Stage_09_BalancerStableBufferHookPkg {
    using BetterEfficientHashLib for bytes;

    function execute(LaunchState storage s) internal returns (address pkg) {
        IVaultRegistryDeployment reg = IVaultRegistryDeployment(address(s.indexedexManager));
        IVaultFeeOracleQuery feeOracle = IVaultFeeOracleQuery(address(s.indexedexManager));
        IFacet liquidityFacet = BalancerHookFS.deployLiquidityFacet(s.create3Factory);
        IFacet seFacet = BalancerHookFS.deploySeFacet(s.create3Factory);
        IFacet hooksFacet = BalancerHookFS.deployHooksFacet(s.create3Factory);
        IBalancerHookPkg.PkgInit memory init_;
        init_.vaultRegistryDeployment = reg;
        init_.vaultFeeOracleQuery = feeOracle;
        init_.liquidityFacet = liquidityFacet;
        init_.exitFacet = BalancerHookFS.deployExitFacet(s.create3Factory);
        init_.queryFacet = BalancerHookFS.deployQueryFacet(s.create3Factory);
        init_.seFacet = seFacet;
        init_.hooksFacet = hooksFacet;
        init_.erc20Facet = s.erc20Facet;
        init_.erc5267Facet = s.erc5267Facet;
        init_.erc2612Facet = s.erc2612Facet;
        init_.multiAssetBasicVaultFacet = s.multiAssetBasicVaultFacet;
        init_.multiAssetStandardVaultFacet = s.multiAssetStandardVaultFacet;
        bytes memory initCode_ = type(BalancerHookDFPkg).creationCode;
        bytes memory initArgs_ = abi.encode(init_);
        pkg = reg.deployPkg(
            initCode_,
            initArgs_,
            ArtifactCreationCode.releaseSalt(abi.encode(type(IBalancerHookPkg).name, FixtureEconomics.SALT_NS)._hash(), initCode_, initArgs_)
        );
    }
}
