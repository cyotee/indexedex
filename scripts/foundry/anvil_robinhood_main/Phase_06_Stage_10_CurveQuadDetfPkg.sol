// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage as IQuadHookPkg
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableDETF_Component_FactoryService as QuadDetfFS
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETF_Component_FactoryService.sol";

/// @title Phase_06_Stage_10_CurveQuadDetfPkg
/// @notice Curve Quad Stable DETF DFPkg. No DETF instance.
library Phase_06_Stage_10_CurveQuadDetfPkg {
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using QuadDetfFS for ICreate3FactoryProxy;
    using QuadDetfFS for IVaultRegistryDeployment;

    function execute(LaunchState storage s) internal {
        require(_live(s.curveQuadHookPkg), "Phase 06-10: curveQuadHookPkg");
        require(_live(s.bondNftVaultPkg), "Phase 06-10: bondNftVaultPkg");
        require(_live(s.rebasingClaimTokenPkg), "Phase 06-10: rebasingClaimTokenPkg");
        IVaultRegistryDeployment reg = IVaultRegistryDeployment(address(s.indexedexManager));
        IFacet multiAssetBasic = s.create3Factory.deployMultiAssetBasicVaultFacet();
        IFacet multiAssetStd = s.create3Factory.deployMultiAssetStandardVaultFacet();
        IFacet exchangeInFacet = QuadDetfFS.deployExchangeInFacet(s.create3Factory);
        IFacet bondingFacet = QuadDetfFS.deployBondingFacet(s.create3Factory);
        IFacet compoundFacet = QuadDetfFS.deployCompoundFacet(s.create3Factory);
        IFacet infoFacet = QuadDetfFS.deployInfoFacet(s.create3Factory);
        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgInit memory init_;
        init_.erc20Facet = s.erc20Facet;
        init_.erc5267Facet = s.erc5267Facet;
        init_.erc2612Facet = s.erc2612Facet;
        init_.multiAssetBasicVaultFacet = multiAssetBasic;
        init_.multiAssetStandardVaultFacet = multiAssetStd;
        init_.exchangeInFacet = exchangeInFacet;
        init_.bondingFacet = bondingFacet;
        init_.compoundFacet = compoundFacet;
        init_.infoFacet = infoFacet;
        init_.feeOracle = IVaultFeeOracleQuery(address(s.indexedexManager));
        init_.vaultRegistryDeployment = reg;
        init_.poolManager = IPoolManager(RobinhoodCanonicalLib.poolManager());
        init_.hookPkg = IQuadHookPkg(s.curveQuadHookPkg);
        init_.bondNftVaultPkg = IDetfSelfNftInventoryDFPkg(s.bondNftVaultPkg);
        init_.rebasingClaimTokenPkg = IRebasingClaimTokenDFPkg(s.rebasingClaimTokenPkg);
        init_.diamondFactory = s.diamondPackageFactory;
        s.curveQuadDetfPkg = address(QuadDetfFS.deployPkg(reg, init_));
    }

    function _live(address a) private view returns (bool) {
        return a != address(0) && a.code.length > 0;
    }
}
