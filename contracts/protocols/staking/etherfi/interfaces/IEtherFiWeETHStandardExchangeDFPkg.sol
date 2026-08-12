// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

interface IEtherFiWeETHStandardExchangeDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    error NotCalledByRegistry(address caller);
    error ZeroAddress();

    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet erc4626Facet;
        IFacet erc4626StandardVaultFacet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet exchangeInFacet;
        IFacet exchangeOutFacet;
        IFacet markerFacet;
        IFacet rebalanceFacet;
        IVaultFeeOracleQuery vaultFeeOracleQuery;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPermit2 permit2;
    }

    struct PkgArgs {
        address eETH;
        address weETH;
        address weth;
        address liquidityPool;
        address withdrawRequestNFT;
        address redemptionManager;
    }

    function deployVault(
        address eETH,
        address weETH,
        address weth,
        address liquidityPool,
        address withdrawRequestNFT,
        address redemptionManager
    ) external returns (address vault);
}
