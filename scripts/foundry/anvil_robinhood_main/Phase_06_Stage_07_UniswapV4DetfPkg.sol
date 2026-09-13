// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {DetfPkgFactoryService} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";

import {LaunchState} from "./LaunchState.sol";

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/IRebasingClaimTokenDFPkg.sol";
import {IUniswapV4DetfBondNFTVaultDFPkg} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/IUniswapV4DetfBondNFTVaultDFPkg.sol";
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
        _requireCurrentDependency(
            s.bondNftVaultPkg, "UniswapV4DetfBondNFTVaultDFPkg", "UniswapV4DetfBondNFTVaultFacet"
        );
        _requireCurrentDependency(
            s.rebasingClaimTokenPkg, "RebasingClaimTokenDFPkg", "RebasingClaimTokenFacet"
        );
        IVaultRegistryDeployment reg = IVaultRegistryDeployment(address(s.indexedexManager));
        IFacet[5] memory productFacets = UniswapV4Detf_Facet_FactoryService.deployUniswapV4DetfFacets(s.create3Factory);
        IUniswapV4DetfDFPkg.PkgInit memory init_ = IUniswapV4DetfDFPkg.PkgInit({
            erc20Facet: s.erc20Facet,
            erc5267Facet: s.erc5267Facet,
            erc2612Facet: s.erc2612Facet,
            multiAssetBasicVaultFacet: s.multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: s.multiAssetStandardVaultFacet,
            productFacets: productFacets,
            feeOracle: IVaultFeeOracleQuery(address(s.indexedexManager)),
            vaultRegistryDeployment: reg,
            bondNftVaultPkg: IUniswapV4DetfBondNFTVaultDFPkg(s.bondNftVaultPkg),
            rebasingClaimTokenPkg: IRebasingClaimTokenDFPkg(s.rebasingClaimTokenPkg),
            syPkg: DetfPkgFactoryService.deployDETFSYComponents(
                s.create3Factory, reg, IVaultFeeOracleQuery(address(s.indexedexManager)),
                s.erc5267Facet, s.erc2612Facet
            )
        });
        s.uniV4DetfPkg = address(UniswapV4Detf_Pkg_FactoryService.deployUniswapV4DetfDFPkg(reg, init_));
    }

    /// @dev Fail before product deployment if a skipped dependency still has old code.
    function _requireCurrentDependency(address pkg_, string memory name_, string memory facetName_) private view {
        IDiamondFactoryPackage pkg = IDiamondFactoryPackage(pkg_);
        require(keccak256(bytes(pkg.packageName())) == keccak256(bytes(name_)), "Phase 06-07: wrong dependency package");
        // These dependency facets have no library links or immutable constructor values.
        // Read their artifacts directly so release validation needs no implementation imports.
        Vm vm_ = Vm(VM_ADDRESS);
        string memory artifact_ = vm_.readFile(
            string.concat(vm_.projectRoot(), "/out/", facetName_, ".sol/", facetName_, ".json")
        );
        bytes memory expected = vm_.parseJsonBytes(artifact_, ".deployedBytecode.object");
        require(expected.length != 0, "Phase 06-07: missing dependency artifact");
        bytes32 expectedHash = keccak256(expected);
        address[] memory facets = pkg.facetAddresses();
        for (uint256 i; i < facets.length; ++i) {
            if (facets[i].codehash == expectedHash) return;
        }
        revert("Phase 06-07: stale dependency facet; run 06-01 and 06-02");
    }

    function _live(address a) private view returns (bool) {
        return a != address(0) && a.code.length > 0;
    }
}
