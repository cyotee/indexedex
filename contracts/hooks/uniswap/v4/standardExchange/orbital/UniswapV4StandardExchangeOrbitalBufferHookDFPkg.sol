// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {MultiStepOwnableRepo} from "@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {ERC2535Repo} from "@crane/contracts/introspection/ERC2535/ERC2535Repo.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {
    UniswapV4HookDiamondCreate2Lib as Create2Lib
} from "contracts/hooks/uniswap/v4/factory/libs/UniswapV4HookDiamondCreate2Lib.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookInitFacet
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/facets/UniswapV4StandardExchangeOrbitalBufferHookInitFacet.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";

/**
 * @title UniswapV4StandardExchangeOrbitalBufferHookDFPkg
 * @notice Hook diamond package: vault pair + package-as-init at deploy; production facets at finalize.
 * @dev deployVault → registry.deployHookVault → hook CREATE2 factory. Salt excludes package address.
 *      postDeploy is a no-op. Product doors via deployPair; ABI via finalizeInitialization.
 */
contract UniswapV4StandardExchangeOrbitalBufferHookDFPkg is
    UniswapV4StandardExchangeOrbitalBufferHookInitFacet,
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
{
    using BetterEfficientHashLib for bytes;

    bytes32 public constant PRODUCT_ID = keccak256("uv4-se-orbital-buffer-hook");
    bytes4 public constant HOOK_VAULT_TYPE =
        bytes4(keccak256("UniswapV4StandardExchangeOrbitalBufferHook"));

    IVaultRegistryDeployment public immutable VAULT_REGISTRY_DEPLOYMENT;
    IVaultFeeOracleQuery public immutable VAULT_FEE_ORACLE_QUERY;
    IFacet public immutable DEPOSIT_FACET;
    IFacet public immutable WITHDRAW_FACET;
    IFacet public immutable SE_FACET;
    IFacet public immutable HOOKS_FACET;
    IFacet public immutable ERC20_FACET;
    IFacet public immutable ERC5267_FACET;
    IFacet public immutable ERC2612_FACET;
    IFacet public immutable MULTI_ASSET_BASIC_VAULT_FACET;
    IFacet public immutable MULTI_ASSET_STANDARD_VAULT_FACET;
    IFacet public immutable MULTI_STEP_OWNABLE_FACET;
    IUniswapV4StandardExchangeOrbitalBufferHookPackage private immutable SELF;

    constructor(PkgInit memory init) {
        if (
            address(init.vaultRegistryDeployment) == address(0)
                || address(init.vaultFeeOracleQuery) == address(0)
                || address(init.depositFacet) == address(0) || address(init.withdrawFacet) == address(0)
                || address(init.seFacet) == address(0) || address(init.hooksFacet) == address(0)
                || address(init.erc20Facet) == address(0) || address(init.erc5267Facet) == address(0)
                || address(init.erc2612Facet) == address(0)
                || address(init.multiAssetBasicVaultFacet) == address(0)
                || address(init.multiAssetStandardVaultFacet) == address(0)
                || address(init.multiStepOwnableFacet) == address(0)
        ) {
            revert ZeroAddress();
        }
        VAULT_REGISTRY_DEPLOYMENT = init.vaultRegistryDeployment;
        VAULT_FEE_ORACLE_QUERY = init.vaultFeeOracleQuery;
        DEPOSIT_FACET = init.depositFacet;
        WITHDRAW_FACET = init.withdrawFacet;
        SE_FACET = init.seFacet;
        HOOKS_FACET = init.hooksFacet;
        ERC20_FACET = init.erc20Facet;
        ERC5267_FACET = init.erc5267Facet;
        ERC2612_FACET = init.erc2612Facet;
        MULTI_ASSET_BASIC_VAULT_FACET = init.multiAssetBasicVaultFacet;
        MULTI_ASSET_STANDARD_VAULT_FACET = init.multiAssetStandardVaultFacet;
        MULTI_STEP_OWNABLE_FACET = init.multiStepOwnableFacet;
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
                | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );
    }

    function isExpectedInstance(address proxy, bytes calldata) external view returns (bool) {
        if (proxy.code.length == 0) return false;
        return (uint160(proxy) & Create2Lib.FLAG_MASK) == (requiredHookFlags() & Create2Lib.FLAG_MASK);
    }

    function packageName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeOrbitalBufferHookDFPkg).name;
    }

    function facetInterfaces()
        public
        pure
        override(IDiamondFactoryPackage, UniswapV4StandardExchangeOrbitalBufferHookInitFacet)
        returns (bytes4[] memory interfaces)
    {
        interfaces = new bytes4[](10);
        interfaces[0] = type(IERC20).interfaceId;
        interfaces[1] = type(IERC20Metadata).interfaceId;
        interfaces[2] = type(IERC20Permit).interfaceId;
        interfaces[3] = type(IERC5267).interfaceId;
        interfaces[4] = type(IStandardExchangeIn).interfaceId;
        interfaces[5] = type(IStandardExchangeOut).interfaceId;
        interfaces[6] = type(IBasicVault).interfaceId;
        interfaces[7] = type(IStandardVault).interfaceId;
        interfaces[8] = type(IMultiStepOwnable).interfaceId;
        interfaces[9] = HOOK_VAULT_TYPE;
    }

    function facetAddresses() public view returns (address[] memory facets) {
        facets = new address[](11);
        facets[0] = address(MULTI_STEP_OWNABLE_FACET);
        facets[1] = address(MULTI_ASSET_BASIC_VAULT_FACET);
        facets[2] = address(MULTI_ASSET_STANDARD_VAULT_FACET);
        facets[3] = address(SELF);
        facets[4] = address(HOOKS_FACET);
        facets[5] = address(DEPOSIT_FACET);
        facets[6] = address(WITHDRAW_FACET);
        facets[7] = address(SE_FACET);
        facets[8] = address(ERC20_FACET);
        facets[9] = address(ERC5267_FACET);
        facets[10] = address(ERC2612_FACET);
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
        cuts = new IDiamond.FacetCut[](4);
        cuts[0] = IDiamond.FacetCut({
            facetAddress: address(MULTI_STEP_OWNABLE_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: MULTI_STEP_OWNABLE_FACET.facetFuncs()
        });
        cuts[1] = IDiamond.FacetCut({
            facetAddress: address(MULTI_ASSET_BASIC_VAULT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: MULTI_ASSET_BASIC_VAULT_FACET.facetFuncs()
        });
        cuts[2] = IDiamond.FacetCut({
            facetAddress: address(MULTI_ASSET_STANDARD_VAULT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: MULTI_ASSET_STANDARD_VAULT_FACET.facetFuncs()
        });
        cuts[3] = IDiamond.FacetCut({
            facetAddress: address(SELF),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: facetFuncs()
        });
    }

    function productionFacetCuts() public view returns (IDiamond.FacetCut[] memory cuts) {
        cuts = new IDiamond.FacetCut[](7);
        cuts[0] = IDiamond.FacetCut({
            facetAddress: address(HOOKS_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: HOOKS_FACET.facetFuncs()
        });
        cuts[1] = IDiamond.FacetCut({
            facetAddress: address(DEPOSIT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: DEPOSIT_FACET.facetFuncs()
        });
        cuts[2] = IDiamond.FacetCut({
            facetAddress: address(WITHDRAW_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: WITHDRAW_FACET.facetFuncs()
        });
        cuts[3] = IDiamond.FacetCut({
            facetAddress: address(SE_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: SE_FACET.facetFuncs()
        });
        cuts[4] = IDiamond.FacetCut({
            facetAddress: address(ERC20_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC20_FACET.facetFuncs()
        });
        cuts[5] = IDiamond.FacetCut({
            facetAddress: address(ERC5267_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC5267_FACET.facetFuncs()
        });
        cuts[6] = IDiamond.FacetCut({
            facetAddress: address(ERC2612_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC2612_FACET.facetFuncs()
        });
    }

    function finalizeInitialization() public override nonReentrant returns (bool) {
        Repo.Layout storage l = Repo._layout();
        if (l.initializationFinalized) revert InitializationAlreadyFinalized();
        if (
            !isPairPoolLive(l.token0, l.token1) || !isPairPoolLive(l.token1, l.token2)
                || !isPairPoolLive(l.token0, l.token2)
        ) {
            revert ProductDoorsNotLive();
        }

        IDiamond.FacetCut[] memory cuts = new IDiamond.FacetCut[](8);
        cuts[0] = IDiamond.FacetCut({
            facetAddress: address(SELF),
            action: IDiamond.FacetCutAction.Remove,
            functionSelectors: facetFuncs()
        });
        IDiamond.FacetCut[] memory adds = productionFacetCuts();
        cuts[1] = adds[0];
        cuts[2] = adds[1];
        cuts[3] = adds[2];
        cuts[4] = adds[3];
        cuts[5] = adds[4];
        cuts[6] = adds[5];
        cuts[7] = adds[6];

        ERC2535Repo._processFacetCuts(cuts);
        emit IDiamond.DiamondCut(cuts, address(0), "");
        emit InitializationFinalized(address(this));
        l.initializationFinalized = true;
        return true;
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
        // PRODUCT_ID + pm + feeOracle + tokens[3] + ses[3] + rps[3] — no package/facet addresses.
        return keccak256(
            abi.encode(
                PRODUCT_ID,
                a.poolManager,
                a.feeOracle,
                a.token0,
                a.token1,
                a.token2,
                a.se0,
                a.se1,
                a.se2,
                a.rp0,
                a.rp1,
                a.rp2,
                a.ownerOnlyLiquidity,
                a.owner
            )
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
        string memory name_ = _lpName(a.token0, a.token1, a.token2);
        string memory symbol_ = _lpSymbol(a.token0, a.token1, a.token2);
        ERC20Repo._initialize(name_, symbol_, 18);
        EIP712Repo._initialize(name_, "1");

        address[] memory vaultTokens = new address[](3);
        vaultTokens[0] = a.token0;
        vaultTokens[1] = a.token1;
        vaultTokens[2] = a.token2;
        MultiAssetBasicVaultRepo._initialize(vaultTokens);

        StandardVaultRepo._initialize(
            VAULT_FEE_ORACLE_QUERY,
            vaultFeeTypeIds(),
            vaultTypes(),
            abi.encode(a.token0, a.token1, a.token2)._hash()
        );
    }

    function _initProductBindings(PkgArgs memory a) private {
        Repo.BindingsInit memory b;
        b.poolManager = a.poolManager;
        b.feeOracle = a.feeOracle;
        b.token0 = a.token0;
        b.token1 = a.token1;
        b.token2 = a.token2;
        b.se0 = a.se0;
        b.se1 = a.se1;
        b.se2 = a.se2;
        b.rp0 = a.rp0;
        b.rp1 = a.rp1;
        b.rp2 = a.rp2;
        b.decimals0 = _readDecimals(a.token0);
        b.decimals1 = _readDecimals(a.token1);
        b.decimals2 = _readDecimals(a.token2);
        b.tickSpacing = a.tickSpacing;
        b.sqrtPriceX96 = a.sqrtPriceX96;
        b.ownerOnlyLiquidity = a.ownerOnlyLiquidity;
        MultiStepOwnableRepo._initialize(a.owner, 1 days);
        Repo._initializeBindings(b);
    }

    function _lpName(address t0, address t1, address t2) private view returns (string memory) {
        return string.concat(
            "SE Orbital ", _safeSymbol(t0), "-", _safeSymbol(t1), "-", _safeSymbol(t2)
        );
    }

    function _lpSymbol(address t0, address t1, address t2) private view returns (string memory) {
        return string.concat("SEORB-", _safeSymbol(t0), "-", _safeSymbol(t1), "-", _safeSymbol(t2));
    }

    /// @notice Zero PoolManager inits. Factory still calls this then freezes the proxy.
    function postDeploy(address) public returns (bool) {
        return true;
    }

    function name() public pure returns (string memory) {
        return "UniswapV4StandardExchangeOrbitalBufferHook";
    }

    function vaultFeeTypeIds() public pure returns (bytes32) {
        return bytes32(0);
    }

    function vaultTypes() public pure returns (bytes4[] memory typeIDs) {
        typeIDs = new bytes4[](5);
        typeIDs[0] = type(IBasicVault).interfaceId;
        typeIDs[1] = type(IStandardVault).interfaceId;
        typeIDs[2] = type(IStandardExchangeIn).interfaceId;
        typeIDs[3] = type(IStandardExchangeOut).interfaceId;
        typeIDs[4] = HOOK_VAULT_TYPE;
    }

    function vaultDeclaration() public pure returns (IStandardVaultPkg.VaultPkgDeclaration memory decl) {
        decl = IStandardVaultPkg.VaultPkgDeclaration({
            name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()
        });
    }

    function _validateArgs(PkgArgs memory a) private view {
        if (
            a.poolManager == address(0) || a.feeOracle == address(0) || a.token0 == address(0)
                || a.token1 == address(0) || a.token2 == address(0) || a.owner == address(0)
        ) {
            revert ZeroAddress();
        }
        if (a.token0 == a.token1 || a.token1 == a.token2 || a.token0 == a.token2) {
            revert SameToken();
        }
        // RP only allowed on SE legs
        if (
            (a.rp0 != address(0) && a.se0 == address(0))
                || (a.rp1 != address(0) && a.se1 == address(0))
                || (a.rp2 != address(0) && a.se2 == address(0))
        ) {
            revert RateProviderWithoutSE();
        }
        // Min SE (remediation H7): ≥1 buffered leg required — zero-SE raw-only rejected.
        if (a.se0 == address(0) && a.se1 == address(0) && a.se2 == address(0)) {
            revert MinOneStandardExchange();
        }
        // Non-zero SEs pairwise distinct
        if (a.se0 != address(0) && a.se0 == a.se1) revert SameStandardExchange();
        if (a.se0 != address(0) && a.se0 == a.se2) revert SameStandardExchange();
        if (a.se1 != address(0) && a.se1 == a.se2) revert SameStandardExchange();
        // SE must list token in vaultTokens when non-zero
        _requireSeOwnsToken(a.se0, a.token0);
        _requireSeOwnsToken(a.se1, a.token1);
        _requireSeOwnsToken(a.se2, a.token2);
    }

    function _requireSeOwnsToken(address se, address token) private view {
        if (se == address(0)) return;
        if (se == token) revert InvalidSE();
        try IBasicVault(se).vaultTokens() returns (address[] memory tokens) {
            bool found;
            for (uint256 i; i < tokens.length; ++i) {
                if (tokens[i] == token) {
                    found = true;
                    break;
                }
            }
            if (!found) revert InvalidSE();
        } catch {
            revert InvalidSE();
        }
    }

    function _safeSymbol(address token) private view returns (string memory) {
        try IERC20Metadata(token).symbol() returns (string memory s) {
            if (bytes(s).length > 0) return s;
        } catch {}
        return _addressFragment(token);
    }

    function _addressFragment(address token) private pure returns (string memory) {
        bytes16 hexSymbols = "0123456789abcdef";
        bytes memory b = new bytes(6);
        uint160 v = uint160(token);
        for (uint256 i = 0; i < 6; i++) {
            b[5 - i] = hexSymbols[v & 0xf];
            v >>= 4;
        }
        return string(b);
    }

    function _readDecimals(address token) private view returns (uint8) {
        try IERC20Metadata(token).decimals() returns (uint8 d) {
            return d;
        } catch {
            return 18;
        }
    }
}
