// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {
    IUniswapV4HookDiamondPackage
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackage.sol";

/**
 * @title IUniswapV4HookDiamondPackageCallBackFactory
 * @notice CREATE2 factory for immutable Uniswap V4 hook diamond proxies (package-out-of-salt + flag mining).
 */
interface IUniswapV4HookDiamondPackageCallBackFactory {
    struct InitArgs {
        IFacet erc165Facet;
        IFacet diamondLoupeFacet;
        IFacet erc8109IntrospectionFacet;
        IFacet postDeployHookFacet;
        IFacet hookFlagsFacet;
    }

    error HookMineExhausted();
    error HookDeployCollision(address proxy);
    error InvalidHookFlags(address predicted, uint160 got, uint160 want);
    error ZeroAddress();
    error DeploymentAddressMismatch(address expected, address actual);

    event HookDiamondDeployed(
        address indexed proxy,
        address indexed pkg,
        bytes32 packageSalt,
        uint256 mineNonce,
        uint160 flags
    );

    function PROXY_INIT_HASH() external view returns (bytes32);
    function FLAG_MASK() external pure returns (uint160);
    function MAX_LOOP() external pure returns (uint256);

    function ERC165_FACET() external view returns (IFacet);
    function DIAMOND_LOUPE_FACET() external view returns (IFacet);
    function ERC8109_INTROSPECTION_FACET() external view returns (IFacet);
    function POST_DEPLOY_HOOK_FACET() external view returns (IFacet);
    function HOOK_FLAGS_FACET() external view returns (IFacet);

    /// @notice Gas-risky auto-mine from mineNonce 0. Prefer deployWithMineNonce in production.
    function deploy(IUniswapV4HookDiamondPackage pkg, bytes calldata pkgArgs) external returns (address proxy);

    /// @notice Production path: deploy with off-chain premined mineNonce.
    function deployWithMineNonce(IUniswapV4HookDiamondPackage pkg, bytes calldata pkgArgs, uint256 mineNonce)
        external
        returns (address proxy);

    /// @dev Not view: applies processArgs then calcSalt (P19). Identity processArgs packages still work.
    function calcAddress(IUniswapV4HookDiamondPackage pkg, bytes calldata pkgArgs, uint256 mineNonce)
        external
        returns (address predicted);

    function previewFinalSalt(bytes32 packageSalt, uint256 mineNonce) external pure returns (bytes32 finalSalt);

    function facetInterfaces() external pure returns (bytes4[] memory interfaces);
    function facetCuts() external view returns (IDiamond.FacetCut[] memory facetCuts_);
    function postDeployFacetCuts() external view returns (IDiamond.FacetCut[] memory facetCuts_);

    function pkgOfAccount(address account) external view returns (IUniswapV4HookDiamondPackage);
    function pkgArgsOfAccount(address account) external view returns (bytes memory);
}
