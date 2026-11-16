// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";

interface IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    struct PkgInit {
        IFacet[] facets;
        IPoolManager poolManager;
        IVaultRegistryDeployment registry;
        IVaultFeeOracleQuery oracle;
        IPermit2 permit2;
    }
    struct PkgArgs { PoolKey poolKey; address targetToken; }
    error InvalidComponent();
    error NotCalledByRegistry();
    error ImmutablePackage();
    function bindingHash() external view returns (bytes32);
    function deployVault(PkgArgs memory args) external returns (address);
}
