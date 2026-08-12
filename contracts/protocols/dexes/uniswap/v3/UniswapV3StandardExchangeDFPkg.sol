// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {VaultFeeType} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {UniswapV3PoolAwareRepo} from "contracts/protocols/dexes/uniswap/v3/UniswapV3PoolAwareRepo.sol";
import {UniswapV3FactoryAwareRepo} from "contracts/protocols/dexes/uniswap/v3/UniswapV3FactoryAwareRepo.sol";
import {UniswapV3VaultRepo} from "contracts/protocols/dexes/uniswap/v3/UniswapV3VaultRepo.sol";
import {
    IUniswapV3StandardExchangePositionImport
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangePositionImportTarget.sol";

interface IUniswapV3StandardExchangeDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    error NotCalledByRegistry(address caller);
    error InvalidPoolFactory(address poolFactory, address expectedFactory);

    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet uniswapV3StandardExchangeInFacet;
        IFacet uniswapV3StandardExchangeInQueryFacet;
        IFacet uniswapV3StandardExchangeOutFacet;
        IFacet uniswapV3StandardExchangePositionImportFacet;
        IVaultFeeOracleQuery vaultFeeOracleQuery;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPermit2 permit2;
        IUniswapV3Factory uniswapV3Factory;
    }

    struct PkgArgs {
        IUniswapV3Pool pool;
        uint24 widthMultiplier;
    }

    function deployVault(IUniswapV3Pool pool, uint24 widthMultiplier) external returns (address vault);
}

/**
 * @title UniswapV3StandardExchangeDFPkg
 * @notice Diamond Factory Package for Uniswap V3 Standard Exchange vaults.
 */
contract UniswapV3StandardExchangeDFPkg is IUniswapV3StandardExchangeDFPkg {
    using BetterEfficientHashLib for bytes;

    IFacet immutable ERC20_FACET;
    IFacet immutable ERC5267_FACET;
    IFacet immutable ERC2612_FACET;
    IFacet immutable MULTI_ASSET_BASIC_VAULT_FACET;
    IFacet immutable MULTI_ASSET_STANDARD_VAULT_FACET;
    IFacet immutable UNISWAP_V3_STANDARD_EXCHANGE_IN_FACET;
    IFacet immutable UNISWAP_V3_STANDARD_EXCHANGE_IN_QUERY_FACET;
    IFacet immutable UNISWAP_V3_STANDARD_EXCHANGE_OUT_FACET;
    IFacet immutable UNISWAP_V3_STANDARD_EXCHANGE_POSITION_IMPORT_FACET;
    IVaultFeeOracleQuery immutable VAULT_FEE_ORACLE_QUERY;
    IVaultRegistryDeployment immutable VAULT_REGISTRY_DEPLOYMENT;
    IPermit2 immutable PERMIT2;
    IUniswapV3Factory immutable UNISWAP_V3_FACTORY;

    constructor(PkgInit memory pkgInit) {
        ERC20_FACET = pkgInit.erc20Facet;
        ERC5267_FACET = pkgInit.erc5267Facet;
        ERC2612_FACET = pkgInit.erc2612Facet;
        MULTI_ASSET_BASIC_VAULT_FACET = pkgInit.multiAssetBasicVaultFacet;
        MULTI_ASSET_STANDARD_VAULT_FACET = pkgInit.multiAssetStandardVaultFacet;
        UNISWAP_V3_STANDARD_EXCHANGE_IN_FACET = pkgInit.uniswapV3StandardExchangeInFacet;
        UNISWAP_V3_STANDARD_EXCHANGE_IN_QUERY_FACET = pkgInit.uniswapV3StandardExchangeInQueryFacet;
        UNISWAP_V3_STANDARD_EXCHANGE_OUT_FACET = pkgInit.uniswapV3StandardExchangeOutFacet;
        UNISWAP_V3_STANDARD_EXCHANGE_POSITION_IMPORT_FACET = pkgInit.uniswapV3StandardExchangePositionImportFacet;
        VAULT_FEE_ORACLE_QUERY = pkgInit.vaultFeeOracleQuery;
        VAULT_REGISTRY_DEPLOYMENT = pkgInit.vaultRegistryDeployment;
        PERMIT2 = pkgInit.permit2;
        UNISWAP_V3_FACTORY = pkgInit.uniswapV3Factory;
    }

    function name() public pure override returns (string memory) {
        return packageName();
    }

    function vaultFeeTypeIds() public pure override returns (bytes32 vaultFeeTypeIds_) {
        return VaultTypeUtils._insertFeeTypeId(vaultFeeTypeIds_, VaultFeeType.USAGE, type(IStandardVault).interfaceId);
    }

    function vaultTypes() public pure override returns (bytes4[] memory typeIDs) {
        return facetInterfaces();
    }

    function vaultDeclaration() public pure override returns (VaultPkgDeclaration memory declaration) {
        return VaultPkgDeclaration({name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()});
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](9);
        interfaces[0] = type(IERC20).interfaceId;
        interfaces[1] = type(IERC20Metadata).interfaceId;
        interfaces[2] = type(IERC20).interfaceId ^ type(IERC20Metadata).interfaceId;
        interfaces[3] = type(IERC5267).interfaceId;
        interfaces[4] = type(IERC20Permit).interfaceId;
        interfaces[5] = type(IStandardVault).interfaceId;
        interfaces[6] = type(IStandardExchangeIn).interfaceId;
        interfaces[7] = type(IStandardExchangeOut).interfaceId;
        interfaces[8] = type(IUniswapV3StandardExchangePositionImport).interfaceId;
    }

    function packageName() public pure override returns (string memory) {
        return type(UniswapV3StandardExchangeDFPkg).name;
    }

    function facetCuts() public view override returns (IDiamond.FacetCut[] memory facetCuts_) {
        facetCuts_ = new IDiamond.FacetCut[](9);
        facetCuts_[0] = IDiamond.FacetCut({
            facetAddress: address(ERC20_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC20_FACET.facetFuncs()
        });
        facetCuts_[1] = IDiamond.FacetCut({
            facetAddress: address(ERC5267_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC5267_FACET.facetFuncs()
        });
        facetCuts_[2] = IDiamond.FacetCut({
            facetAddress: address(ERC2612_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC2612_FACET.facetFuncs()
        });
        facetCuts_[3] = IDiamond.FacetCut({
            facetAddress: address(MULTI_ASSET_BASIC_VAULT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: MULTI_ASSET_BASIC_VAULT_FACET.facetFuncs()
        });
        facetCuts_[4] = IDiamond.FacetCut({
            facetAddress: address(MULTI_ASSET_STANDARD_VAULT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: MULTI_ASSET_STANDARD_VAULT_FACET.facetFuncs()
        });
        facetCuts_[5] = IDiamond.FacetCut({
            facetAddress: address(UNISWAP_V3_STANDARD_EXCHANGE_IN_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: UNISWAP_V3_STANDARD_EXCHANGE_IN_FACET.facetFuncs()
        });
        facetCuts_[6] = IDiamond.FacetCut({
            facetAddress: address(UNISWAP_V3_STANDARD_EXCHANGE_IN_QUERY_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: UNISWAP_V3_STANDARD_EXCHANGE_IN_QUERY_FACET.facetFuncs()
        });
        facetCuts_[7] = IDiamond.FacetCut({
            facetAddress: address(UNISWAP_V3_STANDARD_EXCHANGE_OUT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: UNISWAP_V3_STANDARD_EXCHANGE_OUT_FACET.facetFuncs()
        });
        facetCuts_[8] = IDiamond.FacetCut({
            facetAddress: address(UNISWAP_V3_STANDARD_EXCHANGE_POSITION_IMPORT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: UNISWAP_V3_STANDARD_EXCHANGE_POSITION_IMPORT_FACET.facetFuncs()
        });
    }

    function diamondConfig() public view override returns (DiamondConfig memory config) {
        config = DiamondConfig({facetCuts: facetCuts(), interfaces: new bytes4[](0)});
    }

    function calcSalt(bytes memory pkgArgs) public pure override returns (bytes32) {
        return abi.encode(pkgArgs)._hash();
    }

    function processArgs(bytes memory pkgArgs) public view returns (bytes memory processedPkgArgs) {
        if (msg.sender != address(VAULT_REGISTRY_DEPLOYMENT)) {
            revert NotCalledByRegistry(msg.sender);
        }
        return pkgArgs;
    }

    function updatePkg(address, bytes memory) external pure returns (bool) {
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory decodedArgs = abi.decode(initArgs, (PkgArgs));

        address poolFactory = decodedArgs.pool.factory();
        if (poolFactory != address(UNISWAP_V3_FACTORY)) {
            revert InvalidPoolFactory(poolFactory, address(UNISWAP_V3_FACTORY));
        }

        address token0 = decodedArgs.pool.token0();
        address token1 = decodedArgs.pool.token1();
        address[] memory tokens = new address[](2);
        tokens[0] = token0;
        tokens[1] = token1;

        MultiAssetBasicVaultRepo._initialize(tokens);
        StandardVaultRepo._initialize(VAULT_FEE_ORACLE_QUERY, vaultFeeTypeIds(), vaultTypes(), abi.encode(tokens)._hash());
        VaultFeeOracleQueryAwareRepo._initialize(VAULT_FEE_ORACLE_QUERY);
        Permit2AwareRepo._initialize(PERMIT2);
        UniswapV3FactoryAwareRepo._initialize(UNISWAP_V3_FACTORY);
        UniswapV3PoolAwareRepo._initialize(decodedArgs.pool);
        UniswapV3VaultRepo._initialize(decodedArgs.widthMultiplier);

        string memory name_ = string.concat(
            "UniV3 Vault of (", _symbolOrToken(token0), " / ", _symbolOrToken(token1), " ", _feeLabel(decodedArgs.pool.fee()), ")"
        );
        ERC20Repo._initialize(name_, "UV3X", 18);
        EIP712Repo._initialize(name_, "1");
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](9);
        facetAddresses_[0] = address(ERC20_FACET);
        facetAddresses_[1] = address(ERC5267_FACET);
        facetAddresses_[2] = address(ERC2612_FACET);
        facetAddresses_[3] = address(MULTI_ASSET_BASIC_VAULT_FACET);
        facetAddresses_[4] = address(MULTI_ASSET_STANDARD_VAULT_FACET);
        facetAddresses_[5] = address(UNISWAP_V3_STANDARD_EXCHANGE_IN_FACET);
        facetAddresses_[6] = address(UNISWAP_V3_STANDARD_EXCHANGE_IN_QUERY_FACET);
        facetAddresses_[7] = address(UNISWAP_V3_STANDARD_EXCHANGE_OUT_FACET);
        facetAddresses_[8] = address(UNISWAP_V3_STANDARD_EXCHANGE_POSITION_IMPORT_FACET);
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

    function deployVault(IUniswapV3Pool pool, uint24 widthMultiplier) external override returns (address vault) {
        vault = VAULT_REGISTRY_DEPLOYMENT.deployVault(
            IUniswapV3StandardExchangeDFPkg(address(this)),
            abi.encode(PkgArgs({pool: pool, widthMultiplier: widthMultiplier}))
        );
    }

    function _symbolOrToken(address token) internal view returns (string memory symbol_) {
        try IERC20Metadata(token).symbol() returns (string memory fetchedSymbol) {
            return fetchedSymbol;
        } catch {
            return "TOKEN";
        }
    }

    function _feeLabel(uint24 fee) internal pure returns (string memory) {
        if (fee == 100) return "0.01%";
        if (fee == 500) return "0.05%";
        if (fee == 3000) return "0.3%";
        if (fee == 10000) return "1%";
        return "fee";
    }
}
