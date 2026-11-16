// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IMorphoBlueStandardExchangeDFPkg
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchangeDFPkg.sol";
import {
    MorphoBlue_Component_FactoryService
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlue_Component_FactoryService.sol";

/// @title Phase_05_Stage_05_MorphoBlueStandardExchangePkg
/// @notice Morpho Blue SE DFPkg. Morpho host is PkgArgs at vault deploy. No vaults.
library Phase_05_Stage_05_MorphoBlueStandardExchangePkg {
    using MorphoBlue_Component_FactoryService for ICreate3FactoryProxy;
    using MorphoBlue_Component_FactoryService for IIndexedexManagerProxy;

    function execute(LaunchState storage s) internal {
        IFacet erc4626Facet = s.create3Factory.deployMorphoBlueERC4626Facet();
        IFacet inFacet = s.create3Factory.deployMorphoBlueStandardExchangeInFacet();
        IFacet outFacet = s.create3Factory.deployMorphoBlueStandardExchangeOutFacet();
        IFacet markerFacet = s.create3Factory.deployMorphoBlueStandardExchangeMarkerFacet();
        IMorphoBlueStandardExchangeDFPkg.PkgInit memory init_;
        init_.erc20Facet = s.erc20Facet;
        init_.erc5267Facet = s.erc5267Facet;
        init_.erc2612Facet = s.erc2612Facet;
        init_.morphoBlueErc4626Facet = erc4626Facet;
        init_.multiAssetBasicVaultFacet = s.multiAssetBasicVaultFacet;
        init_.multiAssetStandardVaultFacet = s.multiAssetStandardVaultFacet;
        init_.exchangeInFacet = inFacet;
        init_.exchangeOutFacet = outFacet;
        init_.markerFacet = markerFacet;
        init_.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(s.indexedexManager));
        init_.vaultRegistryDeployment = IVaultRegistryDeployment(address(s.indexedexManager));
        init_.permit2 = IPermit2(RobinhoodCanonicalLib.permit2());
        s.morphoBlueSePkg = address(s.indexedexManager.deployMorphoBlueStandardExchangeDFPkg(init_));
    }
}
