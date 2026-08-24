// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage as IOrbitalHookPkg
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";
import {
    UniswapV4StandardExchangeOrbitalDETF_Component_FactoryService as OrbitalDetfFS
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETF_Component_FactoryService.sol";

/// @title Phase_06_Stage_09_OrbitalDetfPkg
library Phase_06_Stage_09_OrbitalDetfPkg {
    using OrbitalDetfFS for IVaultRegistryDeployment;

    function execute(LaunchState storage s) internal {
        require(_live(s.orbitalHookPkg), "Phase 06-09: orbitalHookPkg");
        require(_live(s.bondNftVaultPkg), "Phase 06-09: bondNftVaultPkg");
        require(_live(s.rebasingClaimTokenPkg), "Phase 06-09: rebasingClaimTokenPkg");
        IVaultRegistryDeployment reg = IVaultRegistryDeployment(address(s.indexedexManager));
        IFacet exchangeInFacet = OrbitalDetfFS.deployExchangeInFacet(s.create3Factory);
        IFacet bondingFacet = OrbitalDetfFS.deployBondingFacet(s.create3Factory);
        IFacet infoFacet = OrbitalDetfFS.deployInfoFacet(s.create3Factory);
        IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgInit memory init_;
        init_.erc20Facet = s.erc20Facet;
        init_.erc5267Facet = s.erc5267Facet;
        init_.erc2612Facet = s.erc2612Facet;
        init_.multiAssetBasicVaultFacet = s.multiAssetBasicVaultFacet;
        init_.multiAssetStandardVaultFacet = s.multiAssetStandardVaultFacet;
        init_.exchangeInFacet = exchangeInFacet;
        init_.bondingFacet = bondingFacet;
        init_.infoFacet = infoFacet;
        init_.feeOracle = IVaultFeeOracleQuery(address(s.indexedexManager));
        init_.vaultRegistryDeployment = reg;
        init_.poolManager = IPoolManager(RobinhoodCanonicalLib.poolManager());
        init_.hookPkg = IOrbitalHookPkg(s.orbitalHookPkg);
        init_.bondNftVaultPkg = IDetfSelfNftInventoryDFPkg(s.bondNftVaultPkg);
        init_.rebasingClaimTokenPkg = IRebasingClaimTokenDFPkg(s.rebasingClaimTokenPkg);
        init_.diamondFactory = s.diamondPackageFactory;
        s.orbitalDetfPkg = address(OrbitalDetfFS.deployPkg(reg, init_));
    }

    function _live(address a) private view returns (bool) {
        return a != address(0) && a.code.length > 0;
    }
}
