// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";

interface IUniswapV4FullSpreadStandardExchangeVaultDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc2612Facet;
        IFacet erc5267Facet;
        IFacet basicVaultFacet;
        IFacet standardVaultFacet;
        IFacet moneyFacet;
        IFacet quoteFacet;
        IFacet outFacet;
        IFacet queryFacet;
        IFacet callbackFacet;
        IFacet uniswapV4ProtocolAwareFacet;
        IFacet uniswapV4SinglePositionAwareFacet;
        IPoolManager poolManager;
        address positionDescriptor;
        address positionManager;
        address quoter;
        address stateView;
        address reservesLens;
        address universalRouter;
        IVaultRegistryDeployment registry;
        IVaultFeeOracleQuery oracle;
        IWETH weth;
        IDiamondPackageCallBackFactory diamondFactory;
        address[6] linkedLibraries;
    }

    struct PkgArgs {
        PoolKey poolKey;
    }

    error InvalidComponent();
    error InvalidPoolKey();
    error NotCalledByRegistry();
    error InvalidInitializationContext();
    error AlreadyInitialized();

    function bindingHash() external view returns (bytes32);
    function deployVault(PkgArgs memory args_) external returns (address vault);
}
