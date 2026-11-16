// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRouter} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IRouter.sol";
import {IPoolFactory} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPoolFactory.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

interface IAerodromeStandardExchangeDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {

    error NotCalledByRegistry(address caller);

    error NotAerodromeV1Pool(IPool pool);

    error PoolMustNotBeStable(IPool pool);

    error PoolCreationFailed();

    error RecipientRequiredForDeposit();

    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet erc4626Facet;
        // IFacet erc4626BasicVaultFacet;
        IFacet multiAssetBasicVaultFacet;
        // IFacet erc4626StandardVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet aerodromeStandardExchangeInFacet;
        IFacet aerodromeStandardExchangeOutFacet;
        IFacet aerodromeStandardExchangeOutQueryFacet;
        IVaultFeeOracleQuery vaultFeeOracleQuery;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPermit2 permit2;
        IRouter aerodromeRouter;
        IPoolFactory aerodromePoolFactory;
    }

    struct PkgArgs {
        IPool reserveAsset;
    }

    struct DeployWithPoolResult {
        bool poolExists;
        uint256 proportionalA;
        uint256 proportionalB;
        uint256 expectedLP;
    }

    function deployVault(IPool pool) external returns (address vault);

    function deployVault(IERC20 tokenA, uint256 tokenAAmount, IERC20 tokenB, uint256 tokenBAmount, address recipient)
        external
        returns (address vault);

    function previewDeployVault(IERC20 tokenA, uint256 tokenAAmount, IERC20 tokenB, uint256 tokenBAmount)
        external
        view
        returns (DeployWithPoolResult memory result);
}
