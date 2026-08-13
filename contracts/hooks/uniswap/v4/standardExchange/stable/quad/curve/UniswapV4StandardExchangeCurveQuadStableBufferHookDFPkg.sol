// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    IStandardExchangeMultiAssetLiquidity
} from "contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {
    UniswapV4HookDiamondCreate2Lib as Create2Lib
} from "contracts/hooks/uniswap/v4/factory/libs/UniswapV4HookDiamondCreate2Lib.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookPairPoolLib.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";

/**
 * @title UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg
 * @notice Hook diamond package: ERC20Permit LP + MultiAsset vault + SE Quad Stable product facets.
 * @dev deployVault → registry.deployHookVault → hook CREATE2 factory. Salt excludes package address.
 *      postDeploy ensures all 6 pair doors with DYNAMIC_FEE_FLAG.
 */
contract UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg is
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage
{
    using BetterEfficientHashLib for bytes;

    bytes32 public constant PRODUCT_ID = keccak256("UniswapV4StandardExchangeCurveQuadStableBufferHook");
    bytes4 public constant HOOK_VAULT_TYPE =
        bytes4(keccak256("UniswapV4StandardExchangeCurveQuadStableBufferHook"));

    IVaultRegistryDeployment public immutable VAULT_REGISTRY_DEPLOYMENT;
    IVaultFeeOracleQuery public immutable VAULT_FEE_ORACLE_QUERY;
    IFacet public immutable LIQUIDITY_FACET;
    IFacet public immutable EXIT_FACET;
    IFacet public immutable SE_FACET;
    IFacet public immutable HOOKS_FACET;
    IFacet public immutable ERC20_FACET;
    IFacet public immutable ERC5267_FACET;
    IFacet public immutable ERC2612_FACET;
    IFacet public immutable MULTI_ASSET_BASIC_VAULT_FACET;
    IFacet public immutable MULTI_ASSET_STANDARD_VAULT_FACET;
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage private immutable SELF;

    constructor(PkgInit memory init) {
        if (
            address(init.vaultRegistryDeployment) == address(0)
                || address(init.vaultFeeOracleQuery) == address(0)
                || address(init.liquidityFacet) == address(0) || address(init.exitFacet) == address(0)
                || address(init.seFacet) == address(0)
                || address(init.hooksFacet) == address(0) || address(init.erc20Facet) == address(0)
                || address(init.erc5267Facet) == address(0) || address(init.erc2612Facet) == address(0)
                || address(init.multiAssetBasicVaultFacet) == address(0)
                || address(init.multiAssetStandardVaultFacet) == address(0)
        ) {
            revert ZeroAddress();
        }
        VAULT_REGISTRY_DEPLOYMENT = init.vaultRegistryDeployment;
        VAULT_FEE_ORACLE_QUERY = init.vaultFeeOracleQuery;
        LIQUIDITY_FACET = init.liquidityFacet;
        EXIT_FACET = init.exitFacet;
        SE_FACET = init.seFacet;
        HOOKS_FACET = init.hooksFacet;
        ERC20_FACET = init.erc20Facet;
        ERC5267_FACET = init.erc5267Facet;
        ERC2612_FACET = init.erc2612Facet;
        MULTI_ASSET_BASIC_VAULT_FACET = init.multiAssetBasicVaultFacet;
        MULTI_ASSET_STANDARD_VAULT_FACET = init.multiAssetStandardVaultFacet;
        SELF = this;
    }

    function deployVault(PkgArgs memory args, uint256 mineNonce) public returns (address vault) {
        vault = VAULT_REGISTRY_DEPLOYMENT.deployHookVault(
            IStandardVaultPkg(address(SELF)), abi.encode(args), mineNonce
        );
    }

    function deployVaultAutoMine(PkgArgs memory args) public returns (address vault) {
        vault = VAULT_REGISTRY_DEPLOYMENT.deployHookVaultAutoMine(
            IStandardVaultPkg(address(SELF)), abi.encode(args)
        );
    }

    function requiredHookFlags() public pure returns (uint160 flags) {
        return uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
                | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.BEFORE_DONATE_FLAG
        );
    }

    function isExpectedInstance(address proxy, bytes calldata) external view returns (bool) {
        if (proxy.code.length == 0) return false;
        return (uint160(proxy) & Create2Lib.FLAG_MASK) == (requiredHookFlags() & Create2Lib.FLAG_MASK);
    }

    function packageName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](10);
        interfaces[0] = type(IERC20).interfaceId;
        interfaces[1] = type(IERC20Metadata).interfaceId;
        interfaces[2] = type(IERC20Permit).interfaceId;
        interfaces[3] = type(IERC5267).interfaceId;
        interfaces[4] = type(IStandardExchangeIn).interfaceId;
        interfaces[5] = type(IStandardExchangeOut).interfaceId;
        interfaces[6] = type(IStandardExchangeMultiAssetLiquidity).interfaceId;
        interfaces[7] = type(IBasicVault).interfaceId;
        interfaces[8] = type(IStandardVault).interfaceId;
        interfaces[9] = HOOK_VAULT_TYPE;
    }

    function facetAddresses() public view returns (address[] memory facets) {
        facets = new address[](9);
        facets[0] = address(ERC20_FACET);
        facets[1] = address(ERC5267_FACET);
        facets[2] = address(ERC2612_FACET);
        facets[3] = address(MULTI_ASSET_BASIC_VAULT_FACET);
        facets[4] = address(MULTI_ASSET_STANDARD_VAULT_FACET);
        facets[5] = address(HOOKS_FACET);
        facets[6] = address(LIQUIDITY_FACET);
        facets[7] = address(EXIT_FACET);
        facets[8] = address(SE_FACET);
    }

    function packageMetadata()
        public
        view
        returns (string memory name_, bytes4[] memory interfaces, address[] memory facets)
    {
        name_ = packageName();
        interfaces = facetInterfaces();
        facets = facetAddresses();
    }

    function facetCuts() public view returns (IDiamond.FacetCut[] memory cuts) {
        cuts = new IDiamond.FacetCut[](9);
        cuts[0] = IDiamond.FacetCut({
            facetAddress: address(ERC20_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC20_FACET.facetFuncs()
        });
        cuts[1] = IDiamond.FacetCut({
            facetAddress: address(ERC5267_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC5267_FACET.facetFuncs()
        });
        cuts[2] = IDiamond.FacetCut({
            facetAddress: address(ERC2612_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC2612_FACET.facetFuncs()
        });
        cuts[3] = IDiamond.FacetCut({
            facetAddress: address(MULTI_ASSET_BASIC_VAULT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: MULTI_ASSET_BASIC_VAULT_FACET.facetFuncs()
        });
        cuts[4] = IDiamond.FacetCut({
            facetAddress: address(MULTI_ASSET_STANDARD_VAULT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: MULTI_ASSET_STANDARD_VAULT_FACET.facetFuncs()
        });
        cuts[5] = IDiamond.FacetCut({
            facetAddress: address(HOOKS_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: HOOKS_FACET.facetFuncs()
        });
        cuts[6] = IDiamond.FacetCut({
            facetAddress: address(LIQUIDITY_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: LIQUIDITY_FACET.facetFuncs()
        });
        cuts[7] = IDiamond.FacetCut({
            facetAddress: address(EXIT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: EXIT_FACET.facetFuncs()
        });
        cuts[8] = IDiamond.FacetCut({
            facetAddress: address(SE_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: SE_FACET.facetFuncs()
        });
    }

    function diamondConfig() public view returns (IDiamondFactoryPackage.DiamondConfig memory config) {
        config = IDiamondFactoryPackage.DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function processArgs(bytes memory pkgArgs) public view returns (bytes memory) {
        PkgArgs memory a = abi.decode(pkgArgs, (PkgArgs));
        _validateArgs(a);
        return pkgArgs;
    }

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt) {
        PkgArgs memory a = abi.decode(pkgArgs, (PkgArgs));
        // PRODUCT_ID + tokens + SEs + RPs + baseAmp — no package/facet addresses; no PM/oracle.
        return keccak256(
            abi.encode(PRODUCT_ID, a.tokens, a.standardExchanges, a.rateProviders, a.baseAmp)
        );
    }

    function updatePkg(address, bytes memory) public pure returns (bool) {
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory a = abi.decode(initArgs, (PkgArgs));
        _validateArgs(a);
        _initLpAndVault(a);
        _initProductBindings(a);
    }

    function _initLpAndVault(PkgArgs memory a) private {
        string memory name_ = _lpName(a.tokens);
        string memory symbol_ = _lpSymbol(a.tokens);
        ERC20Repo._initialize(name_, symbol_, 18);
        EIP712Repo._initialize(name_, "1");
        address[] memory toks = new address[](4);
        toks[0] = a.tokens[0];
        toks[1] = a.tokens[1];
        toks[2] = a.tokens[2];
        toks[3] = a.tokens[3];
        MultiAssetBasicVaultRepo._initialize(toks);
        StandardVaultRepo._initialize(
            VAULT_FEE_ORACLE_QUERY, vaultFeeTypeIds(), vaultTypes(), abi.encode(toks)._hash()
        );
    }

    function _initProductBindings(PkgArgs memory a) private {
        uint256[4] memory invScales;
        uint256[4] memory ratedScales;
        uint8[4] memory pairDecimals;
        uint8[4] memory invDecimals;

        for (uint8 i; i < 4; ++i) {
            uint8 pd = _readDecimals(a.tokens[i]);
            if (pd < 6 || pd > 18) revert InvalidDecimals();
            pairDecimals[i] = pd;
            ratedScales[i] = Math.baseScaleFromDecimals(pd);
            if (a.standardExchanges[i] == address(0)) {
                invDecimals[i] = pd;
                invScales[i] = ratedScales[i];
            } else {
                uint8 sd = _readDecimals(a.standardExchanges[i]);
                if (sd < 6 || sd > 18) revert InvalidDecimals();
                invDecimals[i] = sd;
                invScales[i] = Math.baseScaleFromDecimals(sd);
            }
        }

        Repo._initializeBindings(
            a.poolManager,
            a.feeOracle,
            a.tokens,
            a.standardExchanges,
            a.rateProviders,
            a.baseAmp,
            invScales,
            ratedScales,
            pairDecimals,
            invDecimals
        );
    }

    function _lpName(address[4] memory toks) private pure returns (string memory) {
        // Keep under 64 chars; SEQS prefix locked.
        toks;
        return "SEQS Quad Stable Buffer Hook LP";
    }

    function _lpSymbol(address[4] memory toks) private pure returns (string memory) {
        toks;
        return "SEQS-LP";
    }

    function postDeploy(address proxy) public returns (bool) {
        IUniswapV4StandardExchangeCurveQuadStableBufferHook h =
            IUniswapV4StandardExchangeCurveQuadStableBufferHook(proxy);
        address[] memory toks = h.tokens();
        PairPoolLib.ensureAllPairPools(h.poolManager(), proxy, toks, 0);
        return true;
    }

    function name() public pure returns (string memory) {
        return "UniswapV4StandardExchangeCurveQuadStableBufferHook";
    }

    function vaultFeeTypeIds() public pure returns (bytes32) {
        return bytes32(0);
    }

    function vaultTypes() public pure returns (bytes4[] memory typeIDs) {
        typeIDs = new bytes4[](6);
        typeIDs[0] = type(IBasicVault).interfaceId;
        typeIDs[1] = type(IStandardVault).interfaceId;
        typeIDs[2] = type(IStandardExchangeIn).interfaceId;
        typeIDs[3] = type(IStandardExchangeOut).interfaceId;
        typeIDs[4] = type(IStandardExchangeMultiAssetLiquidity).interfaceId;
        typeIDs[5] = HOOK_VAULT_TYPE;
    }

    function vaultDeclaration() public pure returns (IStandardVaultPkg.VaultPkgDeclaration memory decl) {
        decl = IStandardVaultPkg.VaultPkgDeclaration({
            name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()
        });
    }

    function _validateArgs(PkgArgs memory a) private view {
        if (a.poolManager == address(0) || a.feeOracle == address(0)) revert ZeroAddress();
        if (a.baseAmp == 0 || a.baseAmp >= Math.MAX_AMP) revert InvalidAmp();

        uint256 seCount;
        for (uint8 i; i < 4; ++i) {
            if (a.tokens[i] == address(0)) revert ZeroAddress();
            if (i > 0 && a.tokens[i] <= a.tokens[i - 1]) revert TokensNotAscending();
            for (uint8 j = i + 1; j < 4; ++j) {
                if (a.tokens[i] == a.tokens[j]) revert SameToken();
            }

            if (a.rateProviders[i] != address(0) && a.standardExchanges[i] == address(0)) {
                revert RateProviderWithoutSE();
            }

            uint8 pd = _readDecimals(a.tokens[i]);
            if (pd < 6 || pd > 18) revert InvalidDecimals();

            if (a.standardExchanges[i] != address(0)) {
                unchecked {
                    ++seCount;
                }
                for (uint8 j = i + 1; j < 4; ++j) {
                    if (
                        a.standardExchanges[j] != address(0)
                            && a.standardExchanges[i] == a.standardExchanges[j]
                    ) {
                        revert SameStandardExchange();
                    }
                }
                _requireSeOwnsToken(a.standardExchanges[i], a.tokens[i]);
                uint8 sd = _readDecimals(a.standardExchanges[i]);
                if (sd < 6 || sd > 18) revert InvalidDecimals();
            }
        }
        if (seCount == 0) revert ZeroStandardExchangeRequired();
    }

    function _requireSeOwnsToken(address se, address token) private view {
        if (se == token) revert InvalidSE();
        try IBasicVault(se).vaultTokens() returns (address[] memory toks) {
            bool found;
            for (uint256 i; i < toks.length; ++i) {
                if (toks[i] == token) {
                    found = true;
                    break;
                }
            }
            if (!found) revert InvalidSE();
        } catch {
            revert InvalidSE();
        }
    }

    function _readDecimals(address token) private view returns (uint8) {
        try IERC20Metadata(token).decimals() returns (uint8 d) {
            return d;
        } catch {
            return 18;
        }
    }
}
