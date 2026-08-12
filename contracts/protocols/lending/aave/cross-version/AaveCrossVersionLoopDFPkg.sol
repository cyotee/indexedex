// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {BetterEfficientHashLib} from '@crane/contracts/utils/BetterEfficientHashLib.sol';
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";

import {IPool} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPool.sol";
import {IPoolAddressesProvider} from
    "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPoolAddressesProvider.sol";
import {IAaveOracle} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IAaveOracle.sol";
import {ISpoke} from "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/ISpoke.sol";
import {IHub} from "@crane/contracts/protocols/lending/aave/v4/hub/interfaces/IHub.sol";
import {IAaveOracle as IAaveOracleV4} from
    "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/IAaveOracle.sol";

import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {VaultFeeType} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";

import {IAaveCrossVersionLoopVault} from "contracts/interfaces/IAaveCrossVersionLoopVault.sol";
import {AaveV36PoolAwareRepo} from "contracts/protocols/lending/aave/cross-version/AaveV36PoolAwareRepo.sol";
import {AaveV4SpokeAwareRepo} from "contracts/protocols/lending/aave/cross-version/AaveV4SpokeAwareRepo.sol";
import {LoopPositionRepo} from "contracts/protocols/lending/aave/cross-version/LoopPositionRepo.sol";
import {AaveV36Service} from "contracts/protocols/lending/aave/cross-version/AaveV36Service.sol";
import {AaveV4Service} from "contracts/protocols/lending/aave/cross-version/AaveV4Service.sol";

interface IAaveCrossVersionLoopDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    error NotValidPair(address tokenA, address tokenB);
    error TokenNotUsableOnV3(address token);
    error TokenNotUsableOnV4(address token);

    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet exchangeInFacet;
        IFacet exchangeOutFacet;
        IFacet rebalanceFacet;
        IFacet markerFacet;
        IPool v36Pool;
        IPoolAddressesProvider v36AddressesProvider;
        IAaveOracle v36Oracle;
        ISpoke v4Spoke;
        IHub v4Hub;
        IAaveOracleV4 v4Oracle;
        IVaultFeeOracleQuery vaultFeeOracleQuery;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPermit2 permit2;
    }

    struct PkgArgs {
        address tokenA;
        address tokenB;
    }

    function deployVault(IERC20 tokenA, IERC20 tokenB) external returns (address vault);
}

/**
 * @title AaveCrossVersionLoopDFPkg
 * @author cyotee doge <doge.cyotee>
 * @notice Diamond Factory Package for the Aave V3.6 / V4 cross-version carry loop vault. Validates a
 *         token pair is usable on both versions, deploys the proxy through the VaultRegistry, and
 *         wires the vault's repos in `initAccount` (PRD architecture + decisions 32). Sources are
 *         immutable (resolved at package deploy); v4 asset/reserve ids are resolved at init.
 */
contract AaveCrossVersionLoopDFPkg is IAaveCrossVersionLoopDFPkg {
    using BetterEfficientHashLib for bytes;

    // struct PkgInit {
    //     IFacet erc20Facet;
    //     IFacet erc5267Facet;
    //     IFacet erc2612Facet;
    //     IFacet multiAssetBasicVaultFacet;
    //     IFacet multiAssetStandardVaultFacet;
    //     IFacet exchangeInFacet;
    //     IFacet exchangeOutFacet;
    //     IFacet rebalanceFacet;
    //     IFacet markerFacet;
    //     IPool v36Pool;
    //     IPoolAddressesProvider v36AddressesProvider;
    //     IAaveOracle v36Oracle;
    //     ISpoke v4Spoke;
    //     IHub v4Hub;
    //     IAaveOracleV4 v4Oracle;
    //     IVaultFeeOracleQuery vaultFeeOracleQuery;
    //     IVaultRegistryDeployment vaultRegistryDeployment;
    //     IPermit2 permit2;
    // }

    AaveCrossVersionLoopDFPkg public immutable SELF;

    IFacet internal immutable ERC20_FACET;
    IFacet internal immutable ERC5267_FACET;
    IFacet internal immutable ERC2612_FACET;
    IFacet internal immutable MULTI_ASSET_BASIC_VAULT_FACET;
    IFacet internal immutable MULTI_ASSET_STANDARD_VAULT_FACET;
    IFacet internal immutable EXCHANGE_IN_FACET;
    IFacet internal immutable EXCHANGE_OUT_FACET;
    IFacet internal immutable REBALANCE_FACET;
    IFacet internal immutable MARKER_FACET;

    IPool internal immutable V36_POOL;
    IPoolAddressesProvider internal immutable V36_PROVIDER;
    IAaveOracle internal immutable V36_ORACLE;
    ISpoke internal immutable V4_SPOKE;
    IHub internal immutable V4_HUB;
    IAaveOracleV4 internal immutable V4_ORACLE;

    IVaultFeeOracleQuery internal immutable VAULT_FEE_ORACLE_QUERY;
    IVaultRegistryDeployment internal immutable VAULT_REGISTRY_DEPLOYMENT;
    IPermit2 internal immutable PERMIT2;

    constructor(PkgInit memory p) {
        SELF = this;
        ERC20_FACET = p.erc20Facet;
        ERC5267_FACET = p.erc5267Facet;
        ERC2612_FACET = p.erc2612Facet;
        MULTI_ASSET_BASIC_VAULT_FACET = p.multiAssetBasicVaultFacet;
        MULTI_ASSET_STANDARD_VAULT_FACET = p.multiAssetStandardVaultFacet;
        EXCHANGE_IN_FACET = p.exchangeInFacet;
        EXCHANGE_OUT_FACET = p.exchangeOutFacet;
        REBALANCE_FACET = p.rebalanceFacet;
        MARKER_FACET = p.markerFacet;
        V36_POOL = p.v36Pool;
        V36_PROVIDER = p.v36AddressesProvider;
        V36_ORACLE = p.v36Oracle;
        V4_SPOKE = p.v4Spoke;
        V4_HUB = p.v4Hub;
        V4_ORACLE = p.v4Oracle;
        VAULT_FEE_ORACLE_QUERY = p.vaultFeeOracleQuery;
        VAULT_REGISTRY_DEPLOYMENT = p.vaultRegistryDeployment;
        PERMIT2 = p.permit2;
    }

    /* ----------------------------- deployVault ----------------------------- */

    /// @inheritdoc IAaveCrossVersionLoopDFPkg
    function deployVault(IERC20 tokenA, IERC20 tokenB) external returns (address vault) {
        if (address(tokenA) == address(0) || address(tokenB) == address(0) || address(tokenA) == address(tokenB)) {
            revert NotValidPair(address(tokenA), address(tokenB));
        }
        _validatePairUsable(address(tokenA));
        _validatePairUsable(address(tokenB));
        vault = VAULT_REGISTRY_DEPLOYMENT.deployVault(
            SELF, abi.encode(PkgArgs({tokenA: address(tokenA), tokenB: address(tokenB)}))
        );
    }

    /// @dev Both tokens must be listed + usable (collateral, borrowable, active) on BOTH versions.
    function _validatePairUsable(address token) internal view {
        // V3.6
        if (V36_POOL.getReserveAToken(token) == address(0) || !AaveV36Service.canLeverage(V36_POOL, token)) {
            revert TokenNotUsableOnV3(token);
        }
        // V4 (getAssetId/getReserveId revert if not listed)
        uint256 assetId = V4_HUB.getAssetId(token);
        uint256 reserveId = V4_SPOKE.getReserveId(address(V4_HUB), assetId);
        if (!AaveV4Service.canLeverage(V4_SPOKE, reserveId)) revert TokenNotUsableOnV4(token);
    }

    /* ------------------------------ initAccount ---------------------------- */

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory a = abi.decode(initArgs, (PkgArgs));

        AaveV36PoolAwareRepo._initialize(V36_POOL, V36_PROVIDER, V36_ORACLE);
        AaveV4SpokeAwareRepo._initialize(V4_SPOKE, V4_HUB, V4_ORACLE);
        _wireV4Ids(a.tokenA);
        _wireV4Ids(a.tokenB);

        LoopPositionRepo._initialize(IERC20(a.tokenA), IERC20(a.tokenB));

        address[] memory tokens = new address[](2);
        tokens[0] = a.tokenA;
        tokens[1] = a.tokenB;
        MultiAssetBasicVaultRepo._initialize(tokens);

        StandardVaultRepo._initialize(
            VAULT_FEE_ORACLE_QUERY, vaultFeeTypeIds(), vaultTypes(), keccak256(abi.encode(a.tokenA, a.tokenB))
        );

        ERC20Repo._initialize("Aave Cross-Version Carry Loop", "axCARRY", 18);
        VaultFeeOracleQueryAwareRepo._initialize(VAULT_FEE_ORACLE_QUERY);
        Permit2AwareRepo._initialize(PERMIT2);
    }

    function _wireV4Ids(address token) internal {
        uint256 assetId = V4_HUB.getAssetId(token);
        uint256 reserveId = V4_SPOKE.getReserveId(address(V4_HUB), assetId);
        AaveV4SpokeAwareRepo._setTokenIds(token, assetId, reserveId);
    }

    /* --------------------------- IStandardVaultPkg ------------------------- */

    function name() public pure returns (string memory) {
        return type(AaveCrossVersionLoopDFPkg).name;
    }

    function vaultFeeTypeIds() public pure returns (bytes32 ids) {
        ids = VaultTypeUtils._insertFeeTypeId(ids, VaultFeeType.LENDING, type(IAaveCrossVersionLoopVault).interfaceId);
    }

    function vaultTypes() public pure returns (bytes4[] memory) {
        return facetInterfaces();
    }

    function vaultDeclaration() public pure returns (VaultPkgDeclaration memory) {
        return VaultPkgDeclaration({name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()});
    }

    /* ------------------------- IDiamondFactoryPackage ---------------------- */

    function packageName() public pure returns (string memory) {
        return type(AaveCrossVersionLoopDFPkg).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](3);
        interfaces[0] = type(IStandardExchangeIn).interfaceId;
        interfaces[1] = type(IStandardExchangeOut).interfaceId;
        interfaces[2] = type(IAaveCrossVersionLoopVault).interfaceId;
    }

    function facetCuts() public view returns (IDiamond.FacetCut[] memory cuts) {
        IFacet[9] memory fs = [
            ERC20_FACET,
            ERC5267_FACET,
            ERC2612_FACET,
            MULTI_ASSET_BASIC_VAULT_FACET,
            MULTI_ASSET_STANDARD_VAULT_FACET,
            EXCHANGE_IN_FACET,
            EXCHANGE_OUT_FACET,
            REBALANCE_FACET,
            MARKER_FACET
        ];
        cuts = new IDiamond.FacetCut[](9);
        for (uint256 i; i < 9; ++i) {
            cuts[i] = IDiamond.FacetCut({
                facetAddress: address(fs[i]),
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: fs[i].facetFuncs()
            });
        }
    }

    function facetAddresses() external view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](0);
    }

    function diamondConfig() public view returns (DiamondConfig memory config) {
        config = IDiamondFactoryPackage.DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32) {
        return keccak256(pkgArgs);
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }

    function packageMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces, address[] memory facets)
    {
        name_ = packageName();
        interfaces = facetInterfaces();
        facets = new address[](0);
    }

    function processArgs(bytes memory pkgArgs) public pure returns (bytes memory) {
        return pkgArgs;
    }

    function updatePkg(address, bytes memory) public pure returns (bool) {
        return true;
    }
}
