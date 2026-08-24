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
    IUniswapV4StandardExchangeWeightedBufferHookPackage as IWeightedHookPkg
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {
    IUniswapV4StandardExchangeWeightedDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol";
import {
    UniswapV4StandardExchangeWeightedDETF_Component_FactoryService as WeightedDetfFS
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETF_Component_FactoryService.sol";

/// @title Phase_06_Stage_08_WeightedDetfPkg
library Phase_06_Stage_08_WeightedDetfPkg {
    using WeightedDetfFS for IVaultRegistryDeployment;

    function execute(LaunchState storage s) internal {
        require(_live(s.weightedHookPkg), "Phase 06-08: weightedHookPkg");
        require(_live(s.bondNftVaultPkg), "Phase 06-08: bondNftVaultPkg");
        require(_live(s.rebasingClaimTokenPkg), "Phase 06-08: rebasingClaimTokenPkg");
        IVaultRegistryDeployment reg = IVaultRegistryDeployment(address(s.indexedexManager));
        IFacet exchangeInFacet = WeightedDetfFS.deployExchangeInFacet(s.create3Factory);
        IFacet bondingFacet = WeightedDetfFS.deployBondingFacet(s.create3Factory);
        IFacet compoundFacet = WeightedDetfFS.deployCompoundFacet(s.create3Factory);
        IFacet infoFacet = WeightedDetfFS.deployInfoFacet(s.create3Factory);
        IUniswapV4StandardExchangeWeightedDETDFPkg.PkgInit memory init_;
        init_.erc20Facet = s.erc20Facet;
        init_.erc5267Facet = s.erc5267Facet;
        init_.erc2612Facet = s.erc2612Facet;
        init_.multiAssetBasicVaultFacet = s.multiAssetBasicVaultFacet;
        init_.multiAssetStandardVaultFacet = s.multiAssetStandardVaultFacet;
        init_.exchangeInFacet = exchangeInFacet;
        init_.bondingFacet = bondingFacet;
        init_.compoundFacet = compoundFacet;
        init_.infoFacet = infoFacet;
        init_.feeOracle = IVaultFeeOracleQuery(address(s.indexedexManager));
        init_.vaultRegistryDeployment = reg;
        init_.poolManager = IPoolManager(RobinhoodCanonicalLib.poolManager());
        init_.hookPkg = IWeightedHookPkg(s.weightedHookPkg);
        init_.bondNftVaultPkg = IDetfSelfNftInventoryDFPkg(s.bondNftVaultPkg);
        init_.rebasingClaimTokenPkg = IRebasingClaimTokenDFPkg(s.rebasingClaimTokenPkg);
        init_.diamondFactory = s.diamondPackageFactory;
        s.weightedDetfPkg = address(WeightedDetfFS.deployPkg(reg, init_));
    }

    function _live(address a) private view returns (bool) {
        return a != address(0) && a.code.length > 0;
    }
}
