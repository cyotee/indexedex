// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {BetterAddress} from "@crane/contracts/utils/BetterAddress.sol";
import {Creation} from "@crane/contracts/utils/Creation.sol";
import {IFactoryCallBack} from "@crane/contracts/interfaces/IFactoryCallBack.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {MinimalDiamondCallBackProxy} from "@crane/contracts/proxies/MinimalDiamondCallBackProxy.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {
    DiamondFactoryPackageAdaptor
} from "@crane/contracts/factories/diamondPkg/utils/DiamondFactoryPackageAdaptor.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {ERC2535Repo} from "@crane/contracts/introspection/ERC2535/ERC2535Repo.sol";
import {ERC165Repo} from "@crane/contracts/introspection/ERC165/ERC165Repo.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

import {
    IUniswapV4HookDiamondPackage
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackage.sol";
import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    IUniswapV4HookFlags
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookFlags.sol";
import {
    UniswapV4HookDiamondCreate2Lib as Create2Lib
} from "contracts/hooks/uniswap/v4/factory/libs/UniswapV4HookDiamondCreate2Lib.sol";
import {UniswapV4HookFlagsRepo} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookFlagsRepo.sol";

/**
 * @title UniswapV4HookDiamondPackageCallBackFactory
 * @notice CREATE2 deploys MinimalDiamondCallBackProxy diamonds at V4 flag-mined addresses.
 * @dev Parallel to Crane DiamondPackageCallBackFactory. Salt excludes package address (P19 process-then-salt).
 *
 *      Production product path (IndexedEx standard):
 *        HookPackage.deployVault(typedArgs, mineNonce)
 *          → VaultRegistry.deployHookVault(pkg, encodedArgs, mineNonce)
 *            → this.deployWithMineNonce(...)
 *            → register vault
 *      Wire factory once: setHookDiamondPackageFactory(this) on the manager.
 *      Premine mineNonce off-chain; auto-mine deploy is gas-risky (tests / convenience only).
 *      Direct calls to deploy* are permissionless and do not register the vault.
 */
contract UniswapV4HookDiamondPackageCallBackFactory is
    IUniswapV4HookDiamondPackageCallBackFactory,
    IFactoryCallBack
{
    using BetterAddress for address;
    using Creation for address;
    using DiamondFactoryPackageAdaptor for IDiamondFactoryPackage;

    bytes32 public constant PROXY_INIT_HASH = keccak256(type(MinimalDiamondCallBackProxy).creationCode);
    uint160 public constant FLAG_MASK = Create2Lib.FLAG_MASK;
    uint256 public constant MAX_LOOP = Create2Lib.MAX_LOOP;

    IFacet public immutable ERC165_FACET;
    IFacet public immutable DIAMOND_LOUPE_FACET;
    IFacet public immutable ERC8109_INTROSPECTION_FACET;
    IFacet public immutable POST_DEPLOY_HOOK_FACET;
    IFacet public immutable HOOK_FLAGS_FACET;

    IFactoryCallBack private immutable SELF;

    mapping(address account => IUniswapV4HookDiamondPackage pkg) public pkgOfAccount;
    mapping(address account => bytes pkgArgs) public pkgArgsOfAccount;

    struct DeployCtx {
        IUniswapV4HookDiamondPackage pkg;
        bytes processed;
        bytes32 packageSalt;
        uint256 mineNonce;
        uint160 requiredFlags;
        address predicted;
    }

    constructor(InitArgs memory init) {
        if (
            address(init.erc165Facet) == address(0) || address(init.diamondLoupeFacet) == address(0)
                || address(init.erc8109IntrospectionFacet) == address(0)
                || address(init.postDeployHookFacet) == address(0) || address(init.hookFlagsFacet) == address(0)
        ) {
            revert ZeroAddress();
        }
        ERC165_FACET = init.erc165Facet;
        DIAMOND_LOUPE_FACET = init.diamondLoupeFacet;
        ERC8109_INTROSPECTION_FACET = init.erc8109IntrospectionFacet;
        POST_DEPLOY_HOOK_FACET = init.postDeployHookFacet;
        HOOK_FLAGS_FACET = init.hookFlagsFacet;
        SELF = this;
    }

    function previewFinalSalt(bytes32 packageSalt, uint256 mineNonce) public pure returns (bytes32) {
        return Create2Lib.previewFinalSalt(packageSalt, mineNonce);
    }

    /// @dev P19: processArgs → calcSalt(processed) → finalSalt with mineNonce.
    function calcAddress(IUniswapV4HookDiamondPackage pkg, bytes calldata pkgArgs, uint256 mineNonce)
        public
        returns (address)
    {
        DeployCtx memory ctx = _prepare(pkg, pkgArgs);
        ctx.mineNonce = mineNonce;
        return Create2Lib.predictAddress(address(this), PROXY_INIT_HASH, ctx.packageSalt, mineNonce);
    }

    /// @notice Auto-mine from mineNonce 0 then deploy. Prefer deployWithMineNonce in production.
    /// @dev Uses Create2Lib.findMineNonce (assembly, no per-iteration memory growth).
    function deploy(IUniswapV4HookDiamondPackage pkg, bytes calldata pkgArgs) public returns (address) {
        DeployCtx memory ctx = _prepare(pkg, pkgArgs);
        ctx.mineNonce = Create2Lib.findMineNonce(
            address(this), PROXY_INIT_HASH, ctx.packageSalt, ctx.requiredFlags, MAX_LOOP
        );
        ctx.predicted =
            Create2Lib.predictAddress(address(this), PROXY_INIT_HASH, ctx.packageSalt, ctx.mineNonce);
        return _deployAt(ctx);
    }

    function deployWithMineNonce(IUniswapV4HookDiamondPackage pkg, bytes calldata pkgArgs, uint256 mineNonce)
        public
        returns (address)
    {
        DeployCtx memory ctx = _prepare(pkg, pkgArgs);
        ctx.mineNonce = mineNonce;
        ctx.predicted =
            Create2Lib.predictAddress(address(this), PROXY_INIT_HASH, ctx.packageSalt, mineNonce);
        uint160 got = uint160(ctx.predicted) & FLAG_MASK;
        if (got != ctx.requiredFlags) {
            revert InvalidHookFlags(ctx.predicted, got, ctx.requiredFlags);
        }
        return _deployAt(ctx);
    }

    function _prepare(IUniswapV4HookDiamondPackage pkg, bytes calldata pkgArgs)
        private
        returns (DeployCtx memory ctx)
    {
        if (address(pkg) == address(0)) revert ZeroAddress();
        ctx.pkg = pkg;
        IDiamondFactoryPackage basePkg = IDiamondFactoryPackage(address(pkg));
        ctx.processed = basePkg._processArgs(pkgArgs);
        ctx.packageSalt = basePkg._calcSalt(ctx.processed);
        ctx.requiredFlags = pkg.requiredHookFlags() & FLAG_MASK;
    }

    function _deployAt(DeployCtx memory ctx) private returns (address proxy) {
        if (ctx.predicted.isContract()) {
            if (!ctx.pkg.isExpectedInstance(ctx.predicted, ctx.processed)) {
                revert HookDeployCollision(ctx.predicted);
            }
            return ctx.predicted;
        }

        bytes32 finalSalt = Create2Lib.previewFinalSalt(ctx.packageSalt, ctx.mineNonce);
        pkgOfAccount[ctx.predicted] = ctx.pkg;
        pkgArgsOfAccount[ctx.predicted] = ctx.processed;
        ctx.pkg.updatePkg(ctx.predicted, ctx.processed);

        proxy = address(new MinimalDiamondCallBackProxy{salt: finalSalt}());
        if (ctx.predicted != proxy) {
            revert DeploymentAddressMismatch(ctx.predicted, proxy);
        }

        ctx.pkg.postDeploy(ctx.predicted);
        IPostDeployAccountHook(ctx.predicted).postDeploy();
        emit HookDiamondDeployed(
            ctx.predicted, address(ctx.pkg), ctx.packageSalt, ctx.mineNonce, ctx.requiredFlags
        );
        return ctx.predicted;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](4);
        interfaces[0] = type(IERC165).interfaceId;
        interfaces[1] = type(IDiamondLoupe).interfaceId;
        interfaces[2] = type(IERC8109Introspection).interfaceId;
        interfaces[3] = type(IUniswapV4HookFlags).interfaceId;
    }

    function facetCuts() public view returns (IDiamond.FacetCut[] memory facetCuts_) {
        facetCuts_ = new IDiamond.FacetCut[](5);
        facetCuts_[0] = _addCut(ERC165_FACET);
        facetCuts_[1] = _addCut(DIAMOND_LOUPE_FACET);
        facetCuts_[2] = IDiamond.FacetCut({
            facetAddress: address(ERC8109_INTROSPECTION_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: _erc8109Funcs()
        });
        facetCuts_[3] = _addCut(POST_DEPLOY_HOOK_FACET);
        facetCuts_[4] = _addCut(HOOK_FLAGS_FACET);
    }

    function _addCut(IFacet facet) private view returns (IDiamond.FacetCut memory cut) {
        cut.facetAddress = address(facet);
        cut.action = IDiamond.FacetCutAction.Add;
        cut.functionSelectors = facet.facetFuncs();
    }

    function _erc8109Funcs() private pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](1);
        funcs[0] = IERC8109Introspection.functionFacetPairs.selector;
    }

    function initAccount() external returns (bool) {
        (IDiamondFactoryPackage pkg, bytes memory pkgArgs) = SELF.pkgConfig();
        return initAccount(pkg, pkgArgs);
    }

    function initAccount(IDiamondFactoryPackage pkg, bytes memory pkgArgs) public returns (bool) {
        IDiamond.FacetCut[] memory baseCuts = facetCuts();
        ERC2535Repo._processFacetCuts(baseCuts);
        ERC165Repo._registerInterfaces(facetInterfaces());
        emit IDiamond.DiamondCut(baseCuts, address(SELF), abi.encodeWithSelector(IFactoryCallBack.initAccount.selector));

        IDiamondFactoryPackage.DiamondConfig memory config = pkg.diamondConfig();
        ERC2535Repo._processFacetCuts(config.facetCuts);
        ERC165Repo._registerInterfaces(config.interfaces);

        UniswapV4HookFlagsRepo._set(IUniswapV4HookDiamondPackage(address(pkg)).requiredHookFlags() & FLAG_MASK);

        pkg._initAccount(pkgArgs);
        emit IDiamond.DiamondCut(
            config.facetCuts, address(pkg), abi.encodeWithSelector(IDiamondFactoryPackage.initAccount.selector, pkgArgs)
        );
        return true;
    }

    function pkgConfig() public view returns (IDiamondFactoryPackage pkg, bytes memory args) {
        pkg = IDiamondFactoryPackage(address(pkgOfAccount[msg.sender]));
        args = pkgArgsOfAccount[msg.sender];
    }

    function postDeploy(address) public returns (bool) {
        ERC2535Repo._processFacetCuts(postDeployFacetCuts());
        return true;
    }

    function postDeployFacetCuts() public view returns (IDiamond.FacetCut[] memory facetCuts_) {
        facetCuts_ = new IDiamond.FacetCut[](1);
        facetCuts_[0] = IDiamond.FacetCut({
            facetAddress: address(POST_DEPLOY_HOOK_FACET),
            action: IDiamond.FacetCutAction.Remove,
            functionSelectors: POST_DEPLOY_HOOK_FACET.facetFuncs()
        });
    }
}
