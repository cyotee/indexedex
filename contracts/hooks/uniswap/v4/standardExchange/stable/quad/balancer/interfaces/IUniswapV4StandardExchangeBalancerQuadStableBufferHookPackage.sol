// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    IUniswapV4HookDiamondPackage
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackage.sol";

/**
 * @title IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage
 * @notice DFPkg interface for SE Balancer Quad Stable Buffer Hook (hook diamond package).
 * @dev PkgInit / PkgArgs on interface (Crane rule). Exactly four tokens; ≥1 SE; immutable baseAmp.
 *      Deploy: package → registry.deployHookVault → shared hook CREATE2 factory.
 */
interface IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage is
    IUniswapV4HookDiamondPackage,
    IStandardVaultPkg
{
    error ZeroAddress();
    error SameToken();
    error TokensNotAscending();
    error ZeroStandardExchangeRequired();
    error SameStandardExchange();
    error RateProviderWithoutSE();
    error InvalidSE();
    error InvalidDecimals();
    error ArrayLengthMismatch();
    error InvalidAmp();

    struct PkgInit {
        IVaultRegistryDeployment vaultRegistryDeployment;
        IVaultFeeOracleQuery vaultFeeOracleQuery;
        IFacet liquidityFacet;
        IFacet seFacet;
        IFacet hooksFacet;
        /// @dev ERC20PermitDFPkg parity: LP share is the hook diamond.
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
    }

    /// @notice Binding for one immortal hook instance (exactly 4 tokens, ≥1 SE).
    /// @dev poolManager + feeOracle from factory-scope wiring; still passed for init.
    ///      Salt identity: PRODUCT_ID + tokens + SEs + RPs + baseAmp (no package/facet addresses).
    struct PkgArgs {
        address poolManager;
        address feeOracle;
        address[4] tokens;
        address[4] standardExchanges;
        address[4] rateProviders;
        uint256 baseAmp;
    }

    function VAULT_REGISTRY_DEPLOYMENT() external view returns (IVaultRegistryDeployment);
    function LIQUIDITY_FACET() external view returns (IFacet);
    function SE_FACET() external view returns (IFacet);
    function HOOKS_FACET() external view returns (IFacet);
    function PRODUCT_ID() external pure returns (bytes32);

    /// @notice Product path: package → Vault Registry.deployHookVault → hook factory.
    function deployVault(PkgArgs memory args, uint256 mineNonce) external returns (address vault);

    /// @notice Gas-risky auto-mine convenience. Prefer deployVault with premined mineNonce.
    function deployVaultAutoMine(PkgArgs memory args) external returns (address vault);
}
