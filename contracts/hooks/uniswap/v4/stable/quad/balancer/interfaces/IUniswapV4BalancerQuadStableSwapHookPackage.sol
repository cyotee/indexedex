// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    IUniswapV4HookDiamondPackage
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackage.sol";

/**
 * @title IUniswapV4BalancerQuadStableSwapHookPackage
 * @notice DFPkg interface for Uniswap V4 Balancer Quad Stable Swap Hook (hook diamond package).
 * @dev PkgInit / PkgArgs on interface (Crane rule). Shared LP = ERC20PermitDFPkg facets + MultiAsset vault.
 *      Deploy: package → registry.deployHookVault → shared hook CREATE2 factory.
 *      Math identity: Balancer StableMath (AMP 1e3) — not Curve classic.
 */
interface IUniswapV4BalancerQuadStableSwapHookPackage is IUniswapV4HookDiamondPackage, IStandardVaultPkg {
    error ZeroAddress();
    error InvalidToken();
    error InvalidTokenOrder();
    error InvalidFee();
    error InvalidAmp();

    event PairPoolsEnsured(address indexed hook, uint8 createdCount, uint8 alreadyLiveCount);

    struct PkgInit {
        IVaultRegistryDeployment vaultRegistryDeployment;
        IVaultFeeOracleQuery vaultFeeOracleQuery;
        IFacet hooksFacet;
        IFacet liquidityFacet;
        /// @dev ERC20PermitDFPkg parity: LP share is the hook diamond.
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
    }

    /// @notice Binding for one immortal hook instance (salt identity).
    /// @dev Tokens must be strict address ascending. rateProviders[i] may be address(0).
    struct PkgArgs {
        address poolManager;
        address token0;
        address token1;
        address token2;
        address token3;
        uint24 lpFeePips;
        uint256 baseAmp;
        address[4] rateProviders;
    }

    function VAULT_REGISTRY_DEPLOYMENT() external view returns (IVaultRegistryDeployment);
    function HOOKS_FACET() external view returns (IFacet);
    function LIQUIDITY_FACET() external view returns (IFacet);
    function PRODUCT_ID() external pure returns (bytes32);

    /// @notice Product path: package → Vault Registry.deployHookVault → hook factory.
    function deployVault(PkgArgs memory args, uint256 mineNonce) external returns (address vault);

    /// @notice Gas-risky auto-mine convenience. Prefer deployVault with premined mineNonce.
    function deployVaultAutoMine(PkgArgs memory args) external returns (address vault);

    /// @notice Permissionless ensure of all six pair doors for a live hook proxy.
    function ensurePairPools(address hook)
        external
        returns (PoolKey[6] memory poolKeys, uint8 createdCount);

    /// @notice Pure key construction for the six pair doors (does not initialize).
    function pairPoolKeys(address hook) external view returns (PoolKey[6] memory keys);
}
