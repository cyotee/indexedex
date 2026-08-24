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
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage as ICpHookPkg
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    IUniswapV4SingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";
import {
    UniswapV4SingleStandardExchangeDETF_Component_FactoryService as CpDetfFS
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETF_Component_FactoryService.sol";

/// @title Phase_06_Stage_07_CpDetfPkg
library Phase_06_Stage_07_CpDetfPkg {
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using CpDetfFS for ICreate3FactoryProxy;
    using CpDetfFS for IVaultRegistryDeployment;

    function execute(LaunchState storage s) internal {
        require(_live(s.cpHookPkg), "Phase 06-07: cpHookPkg");
        require(_live(s.bondNftVaultPkg), "Phase 06-07: bondNftVaultPkg");
        require(_live(s.rebasingClaimTokenPkg), "Phase 06-07: rebasingClaimTokenPkg");
        IVaultRegistryDeployment reg = IVaultRegistryDeployment(address(s.indexedexManager));
        IFacet multiAssetBasic = s.create3Factory.deployMultiAssetBasicVaultFacet();
        IFacet multiAssetStd = s.create3Factory.deployMultiAssetStandardVaultFacet();
        IFacet exchangeInFacet = CpDetfFS.deployExchangeInFacet(s.create3Factory);
        IUniswapV4SingleStandardExchangeDETDFPkg.PkgInit memory init_;
        init_.erc20Facet = s.erc20Facet;
        init_.erc5267Facet = s.erc5267Facet;
        init_.erc2612Facet = s.erc2612Facet;
        init_.multiAssetBasicVaultFacet = multiAssetBasic;
        init_.multiAssetStandardVaultFacet = multiAssetStd;
        init_.exchangeInFacet = exchangeInFacet;
        init_.feeOracle = IVaultFeeOracleQuery(address(s.indexedexManager));
        init_.vaultRegistryDeployment = reg;
        init_.poolManager = IPoolManager(RobinhoodCanonicalLib.poolManager());
        init_.hookPkg = ICpHookPkg(s.cpHookPkg);
        init_.bondNftVaultPkg = IDetfSelfNftInventoryDFPkg(s.bondNftVaultPkg);
        init_.rebasingClaimTokenPkg = IRebasingClaimTokenDFPkg(s.rebasingClaimTokenPkg);
        init_.diamondFactory = s.diamondPackageFactory;
        s.cpDetfPkg = address(CpDetfFS.deployPkg(reg, init_));
    }

    function _live(address a) private view returns (bool) {
        return a != address(0) && a.code.length > 0;
    }
}
