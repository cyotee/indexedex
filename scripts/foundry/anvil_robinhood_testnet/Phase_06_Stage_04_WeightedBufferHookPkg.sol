// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixtureEconomics} from "./FixtureEconomics.sol";
import {LaunchState} from "./LaunchState.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage as IWeightedHookPkg
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookDFPkg as WeightedHookDFPkg
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHook_FactoryService as WeightedHookFS
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_FactoryService.sol";

/// @title Phase_06_Stage_04_WeightedBufferHookPkg
library Phase_06_Stage_04_WeightedBufferHookPkg {
    using BetterEfficientHashLib for bytes;

    function execute(LaunchState storage s) internal {
        IVaultRegistryDeployment reg = IVaultRegistryDeployment(address(s.indexedexManager));
        IVaultFeeOracleQuery feeOracle = IVaultFeeOracleQuery(address(s.indexedexManager));
        IFacet joinFacet = WeightedHookFS.deployJoinFacet(s.create3Factory);
        IFacet exitFacet = WeightedHookFS.deployExitFacet(s.create3Factory);
        IFacet seFacet = WeightedHookFS.deploySeFacet(s.create3Factory);
        IFacet hooksFacet = WeightedHookFS.deployHooksFacet(s.create3Factory);
        IWeightedHookPkg.PkgInit memory init_;
        init_.vaultRegistryDeployment = reg;
        init_.vaultFeeOracleQuery = feeOracle;
        init_.joinFacet = joinFacet;
        init_.exitFacet = exitFacet;
        init_.seFacet = seFacet;
        init_.hooksFacet = hooksFacet;
        init_.erc20Facet = s.erc20Facet;
        init_.erc5267Facet = s.erc5267Facet;
        init_.erc2612Facet = s.erc2612Facet;
        init_.multiAssetBasicVaultFacet = s.multiAssetBasicVaultFacet;
        init_.multiAssetStandardVaultFacet = s.multiAssetStandardVaultFacet;
        init_.multiStepOwnableFacet = s.multiStepOwnableFacet;
        s.weightedHookPkg = reg.deployPkg(
            type(WeightedHookDFPkg).creationCode,
            abi.encode(init_),
            abi.encode(type(IWeightedHookPkg).name, FixtureEconomics.SALT_NS)._hash()
        );
    }
}
