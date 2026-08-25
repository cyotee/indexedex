// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixtureEconomics} from "./FixtureEconomics.sol";
import {LaunchState} from "./LaunchState.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage as IQuadHookPkg
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg as QuadHookDFPkg
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService as QuadHookFS
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService.sol";

/// @title Phase_06_Stage_06_CurveQuadBufferHookPkg
/// @notice Curve Quad buffer hook DFPkg + liquidity/exit/SE/hooks facets.
library Phase_06_Stage_06_CurveQuadBufferHookPkg {
    using BetterEfficientHashLib for bytes;

    function execute(LaunchState storage s) internal {
        IVaultRegistryDeployment reg = IVaultRegistryDeployment(address(s.indexedexManager));
        IVaultFeeOracleQuery feeOracle = IVaultFeeOracleQuery(address(s.indexedexManager));
        IFacet joinFacet = QuadHookFS.deployJoinFacet(s.create3Factory);
        IFacet exitFacet = QuadHookFS.deployExitFacet(s.create3Factory);
        IFacet seFacet = QuadHookFS.deploySeFacet(s.create3Factory);
        IFacet hooksFacet = QuadHookFS.deployHooksFacet(s.create3Factory);
        IQuadHookPkg.PkgInit memory init_;
        init_.vaultRegistryDeployment = reg;
        init_.vaultFeeOracleQuery = feeOracle;
        init_.liquidityFacet = joinFacet;
        init_.exitFacet = exitFacet;
        init_.seFacet = seFacet;
        init_.hooksFacet = hooksFacet;
        init_.erc20Facet = s.erc20Facet;
        init_.erc5267Facet = s.erc5267Facet;
        init_.erc2612Facet = s.erc2612Facet;
        init_.multiAssetBasicVaultFacet = s.multiAssetBasicVaultFacet;
        init_.multiAssetStandardVaultFacet = s.multiAssetStandardVaultFacet;
        init_.multiStepOwnableFacet = s.multiStepOwnableFacet;
        s.curveQuadHookPkg = reg.deployPkg(
            type(QuadHookDFPkg).creationCode,
            abi.encode(init_),
            abi.encode(type(IQuadHookPkg).name, FixtureEconomics.SALT_NS)._hash()
        );
    }
}
