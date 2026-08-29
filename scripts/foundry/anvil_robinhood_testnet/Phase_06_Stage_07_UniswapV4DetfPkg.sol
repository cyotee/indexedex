// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchState} from "./LaunchState.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {IUniswapV4DetfBondNFTVaultDFPkg} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/UniswapV4DetfBondNFTVaultDFPkg.sol";
import {
    IUniswapV4DetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {
    UniswapV4Detf_Facet_FactoryService
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Facet_FactoryService.sol";
import {
    UniswapV4Detf_Pkg_FactoryService
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Pkg_FactoryService.sol";

/// @title Phase_06_Stage_07_UniswapV4DetfPkg
/// @notice Unified Uni V4 DETF DFPkg. One package for every in-scope SE buffer hook.
library Phase_06_Stage_07_UniswapV4DetfPkg {
    function execute(LaunchState storage s) internal {
        require(_live(s.bondNftVaultPkg), "Phase 06-07: bondNftVaultPkg");
        require(_live(s.rebasingClaimTokenPkg), "Phase 06-07: rebasingClaimTokenPkg");
        IVaultRegistryDeployment reg = IVaultRegistryDeployment(address(s.indexedexManager));
        IFacet productFacet = UniswapV4Detf_Facet_FactoryService.deployUniswapV4DetfFacet(s.create3Factory);
        IUniswapV4DetfDFPkg.PkgInit memory init_ = IUniswapV4DetfDFPkg.PkgInit({
            erc20Facet: s.erc20Facet,
            erc5267Facet: s.erc5267Facet,
            erc2612Facet: s.erc2612Facet,
            multiAssetBasicVaultFacet: s.multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: s.multiAssetStandardVaultFacet,
            productFacet: productFacet,
            feeOracle: IVaultFeeOracleQuery(address(s.indexedexManager)),
            vaultRegistryDeployment: reg,
            bondNftVaultPkg: IUniswapV4DetfBondNFTVaultDFPkg(s.bondNftVaultPkg),
            rebasingClaimTokenPkg: IRebasingClaimTokenDFPkg(s.rebasingClaimTokenPkg)
        });
        s.uniV4DetfPkg = address(UniswapV4Detf_Pkg_FactoryService.deployUniswapV4DetfDFPkg(reg, init_));
    }

    function _live(address a) private view returns (bool) {
        return a != address(0) && a.code.length > 0;
    }
}
