// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixtureEconomics} from "./FixtureEconomics.sol";
import {LaunchState} from "./LaunchState.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage as ICpHookPkg
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg as CpHookDFPkg
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as CpHookFS
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";

/// @title Phase_06_Stage_03_CpBufferHookPkg
/// @notice CP single SE buffer hook DFPkg + facets.
library Phase_06_Stage_03_CpBufferHookPkg {
    using BetterEfficientHashLib for bytes;

    function execute(LaunchState storage s) internal {
        IVaultRegistryDeployment reg = IVaultRegistryDeployment(address(s.indexedexManager));
        IVaultFeeOracleQuery feeOracle = IVaultFeeOracleQuery(address(s.indexedexManager));
        IFacet seFacet = CpHookFS.deploySeFacet(s.create3Factory);
        IFacet depositFacet = CpHookFS.deployDepositFacet(s.create3Factory);
        IFacet withdrawFacet = CpHookFS.deployWithdrawFacet(s.create3Factory);
        ICpHookPkg.PkgInit memory init_;
        init_.vaultRegistryDeployment = reg;
        init_.vaultFeeOracleQuery = feeOracle;
        init_.seFacet = seFacet;
        init_.depositFacet = depositFacet;
        init_.withdrawFacet = withdrawFacet;
        init_.erc20Facet = s.erc20Facet;
        init_.erc5267Facet = s.erc5267Facet;
        init_.erc2612Facet = s.erc2612Facet;
        init_.multiAssetBasicVaultFacet = s.multiAssetBasicVaultFacet;
        init_.multiAssetStandardVaultFacet = s.multiAssetStandardVaultFacet;
        init_.multiStepOwnableFacet = s.multiStepOwnableFacet;
        s.cpHookPkg = reg.deployPkg(
            type(CpHookDFPkg).creationCode,
            abi.encode(init_),
            abi.encode(type(ICpHookPkg).name, FixtureEconomics.SALT_NS)._hash()
        );
    }
}
