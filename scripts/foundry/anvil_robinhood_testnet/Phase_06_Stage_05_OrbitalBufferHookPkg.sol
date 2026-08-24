// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixtureEconomics} from "./FixtureEconomics.sol";
import {LaunchState} from "./LaunchState.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage as IOrbitalHookPkg
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookDFPkg as OrbitalHookDFPkg
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHook_FactoryService as OrbitalHookFS
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol";

/// @title Phase_06_Stage_05_OrbitalBufferHookPkg
library Phase_06_Stage_05_OrbitalBufferHookPkg {
    using BetterEfficientHashLib for bytes;

    function execute(LaunchState storage s) internal {
        IVaultRegistryDeployment reg = IVaultRegistryDeployment(address(s.indexedexManager));
        IVaultFeeOracleQuery feeOracle = IVaultFeeOracleQuery(address(s.indexedexManager));
        IFacet depositFacet = OrbitalHookFS.deployDepositFacet(s.create3Factory);
        IFacet withdrawFacet = OrbitalHookFS.deployWithdrawFacet(s.create3Factory);
        IFacet seFacet = OrbitalHookFS.deploySeFacet(s.create3Factory);
        IFacet hooksFacet = OrbitalHookFS.deployHooksFacet(s.create3Factory);
        IOrbitalHookPkg.PkgInit memory init_;
        init_.vaultRegistryDeployment = reg;
        init_.vaultFeeOracleQuery = feeOracle;
        init_.depositFacet = depositFacet;
        init_.withdrawFacet = withdrawFacet;
        init_.seFacet = seFacet;
        init_.hooksFacet = hooksFacet;
        init_.erc20Facet = s.erc20Facet;
        init_.erc5267Facet = s.erc5267Facet;
        init_.erc2612Facet = s.erc2612Facet;
        init_.multiAssetBasicVaultFacet = s.multiAssetBasicVaultFacet;
        init_.multiAssetStandardVaultFacet = s.multiAssetStandardVaultFacet;
        init_.multiStepOwnableFacet = s.multiStepOwnableFacet;
        s.orbitalHookPkg = reg.deployPkg(
            type(OrbitalHookDFPkg).creationCode,
            abi.encode(init_),
            abi.encode(type(IOrbitalHookPkg).name, FixtureEconomics.SALT_NS)._hash()
        );
    }
}
