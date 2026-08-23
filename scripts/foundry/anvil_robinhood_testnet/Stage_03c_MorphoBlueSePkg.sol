// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixtureEconomics} from "./FixtureEconomics.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IMorpho} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {Morpho} from "@crane/contracts/external/morpho/blue/Morpho.sol";
import {AdaptiveCurveIrm} from "@crane/contracts/external/morpho/blue-irm/AdaptiveCurveIrm.sol";
import {OracleMock} from "@crane/contracts/external/morpho/blue/mocks/OracleMock.sol";
import {ORACLE_PRICE_SCALE} from "@crane/contracts/external/morpho/blue/libraries/ConstantsLib.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IMorphoBlueStandardExchangeDFPkg
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchangeDFPkg.sol";
import {
    MorphoBlue_Component_FactoryService
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlue_Component_FactoryService.sol";

/// @title Stage_03c_MorphoBlueSePkg
/// @notice Morpho Blue SE DFPkg. If the 46630 Morpho pin has no code, deploys a rehearsal Morpho.
library Stage_03c_MorphoBlueSePkg {
    using MorphoBlue_Component_FactoryService for ICreate3FactoryProxy;
    using MorphoBlue_Component_FactoryService for IIndexedexManagerProxy;

    Vm internal constant vm = Vm(VM_ADDRESS);

    function execute(LaunchState storage s, address owner_) internal {
        _bindMorpho(s, owner_);
        _deploySePkg(s);
    }

    function _bindMorpho(LaunchState storage s, address owner_) private {
        address pin = RobinhoodCanonicalLib.morpho();
        if (pin.code.length > 0) {
            s.morpho = pin;
            s.morphoIrm = RobinhoodCanonicalLib.morphoIrm();
            s.morphoOracle = RobinhoodCanonicalLib.morphoOracleFactory();
            s.morphoLocal = false;
            return;
        }
        IMorpho morpho_ = IMorpho(address(new Morpho(owner_)));
        AdaptiveCurveIrm irm_ = new AdaptiveCurveIrm(address(morpho_));
        OracleMock oracle_ = new OracleMock();
        oracle_.setPrice(ORACLE_PRICE_SCALE);
        morpho_.enableIrm(address(irm_));
        morpho_.enableLltv(FixtureEconomics.MORPHO_LLTV);
        s.morpho = address(morpho_);
        s.morphoIrm = address(irm_);
        s.morphoOracle = address(oracle_);
        s.morphoLocal = true;
        vm.label(s.morpho, "Morpho-rehearsal");
        vm.label(s.morphoIrm, "AdaptiveCurveIrm");
        vm.label(s.morphoOracle, "OracleMock");
    }

    function _deploySePkg(LaunchState storage s) private {
        if (s.morphoBlueSePkg != address(0) && s.morphoBlueSePkg.code.length > 0) return;
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
