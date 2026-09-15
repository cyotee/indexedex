// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangePretransfer} from "../IStandardExchangePretransfer.sol";
import {IUniswapV4StandardExchangeDFPkgV2} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/IUniswapV4StandardExchangeDFPkgV2.sol";

import {IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {WETHAwareRepo} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETHAwareRepo.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {VaultFeeType} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {UniswapV4PoolManagerAwareRepoV2} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4PoolManagerAwareRepoV2.sol";
import {UniswapV4PoolKeyAwareRepoV2} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4PoolKeyAwareRepoV2.sol";
import {UniswapV4PositionRepoV2} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4PositionRepoV2.sol";
import {
    IUniswapV4StandardExchangePositionImportV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4StandardExchangeInTargetV2.sol";
import {
    IUniswapV4StandardExchangeLiquidReserveV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserveV2.sol";
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {
    UniswapV4TwapOracleAwareRepo
} from "contracts/oracles/uniswap/v4/twap/aware/UniswapV4TwapOracleAwareRepo.sol";



contract UniswapV4StandardExchangeDFPkgV2 is IUniswapV4StandardExchangeDFPkgV2 {
    using BetterEfficientHashLib for bytes;

    IFacet immutable ERC20_FACET;
    IFacet immutable ERC5267_FACET;
    IFacet immutable ERC2612_FACET;
    IFacet immutable MULTI_ASSET_BASIC_VAULT_FACET;
    IFacet immutable MULTI_ASSET_STANDARD_VAULT_FACET;
    IFacet immutable UNISWAP_V4_STANDARD_EXCHANGE_IN_FACET;
    IFacet immutable UNISWAP_V4_STANDARD_EXCHANGE_IN_QUERY_FACET;
    IFacet immutable UNISWAP_V4_STANDARD_EXCHANGE_POSITION_IMPORT_FACET;
    IFacet immutable UNISWAP_V4_STANDARD_EXCHANGE_OUT_FACET;
    IFacet immutable UNISWAP_V4_STANDARD_EXCHANGE_OUT_QUERY_FACET;
    IFacet immutable UNISWAP_V4_STANDARD_EXCHANGE_LIQUID_RESERVE_FACET;
    IFacet immutable UNISWAP_V4_STANDARD_EXCHANGE_IN_MULTI_FACET;
    IFacet immutable UNISWAP_V4_STANDARD_EXCHANGE_IN_MULTI_QUERY_FACET;
    IFacet immutable UNISWAP_V4_STANDARD_EXCHANGE_OUT_MULTI_FACET;
    IFacet immutable UNISWAP_V4_STANDARD_EXCHANGE_OUT_MULTI_QUERY_FACET;
    IVaultFeeOracleQuery immutable VAULT_FEE_ORACLE_QUERY;
    IVaultRegistryDeployment immutable VAULT_REGISTRY_DEPLOYMENT;
    IPermit2 immutable PERMIT2;
    IPoolManager immutable POOL_MANAGER;
    IPositionManager immutable POSITION_MANAGER;
    IUniswapV4MultiPoolTwapOracle immutable TWAP_ORACLE;
    IWETH immutable WETH;

    constructor(PkgInit memory pkgInit) {
        ERC20_FACET = pkgInit.erc20Facet;
        ERC5267_FACET = pkgInit.erc5267Facet;
        ERC2612_FACET = pkgInit.erc2612Facet;
        MULTI_ASSET_BASIC_VAULT_FACET = pkgInit.multiAssetBasicVaultFacet;
        MULTI_ASSET_STANDARD_VAULT_FACET = pkgInit.multiAssetStandardVaultFacet;
        UNISWAP_V4_STANDARD_EXCHANGE_IN_FACET = pkgInit.uniswapV4StandardExchangeInFacet;
        UNISWAP_V4_STANDARD_EXCHANGE_IN_QUERY_FACET = pkgInit.uniswapV4StandardExchangeInQueryFacet;
        UNISWAP_V4_STANDARD_EXCHANGE_POSITION_IMPORT_FACET = pkgInit.uniswapV4StandardExchangePositionImportFacet;
        UNISWAP_V4_STANDARD_EXCHANGE_OUT_FACET = pkgInit.uniswapV4StandardExchangeOutFacet;
        UNISWAP_V4_STANDARD_EXCHANGE_OUT_QUERY_FACET = pkgInit.uniswapV4StandardExchangeOutQueryFacet;
        UNISWAP_V4_STANDARD_EXCHANGE_LIQUID_RESERVE_FACET = pkgInit.uniswapV4StandardExchangeLiquidReserveFacet;
        UNISWAP_V4_STANDARD_EXCHANGE_IN_MULTI_FACET = pkgInit.uniswapV4StandardExchangeInMultiFacet;
        UNISWAP_V4_STANDARD_EXCHANGE_IN_MULTI_QUERY_FACET = pkgInit.uniswapV4StandardExchangeInMultiQueryFacet;
        UNISWAP_V4_STANDARD_EXCHANGE_OUT_MULTI_FACET = pkgInit.uniswapV4StandardExchangeOutMultiFacet;
        UNISWAP_V4_STANDARD_EXCHANGE_OUT_MULTI_QUERY_FACET = pkgInit.uniswapV4StandardExchangeOutMultiQueryFacet;
        VAULT_FEE_ORACLE_QUERY = pkgInit.vaultFeeOracleQuery;
        VAULT_REGISTRY_DEPLOYMENT = pkgInit.vaultRegistryDeployment;
        PERMIT2 = pkgInit.permit2;
        POOL_MANAGER = pkgInit.poolManager;
        POSITION_MANAGER = pkgInit.positionManager;
        if (address(pkgInit.twapOracle) == address(0)) {
            revert ZeroTwapOracle();
        }
        if (pkgInit.twapOracle.poolManager() != address(pkgInit.poolManager)) {
            revert TwapOraclePoolManagerMismatch();
        }
        TWAP_ORACLE = pkgInit.twapOracle;
        if (address(pkgInit.weth) == address(0)) {
            revert ZeroWeth();
        }
        WETH = pkgInit.weth;
    }

    function name() public pure override returns (string memory) {
        return packageName();
    }

    /// @dev V4-specific USAGE fee type id so liquid % type default does not hit all standard vaults.
    function vaultFeeTypeIds() public pure override returns (bytes32 vaultFeeTypeIds_) {
        return VaultTypeUtils._insertFeeTypeId(
            vaultFeeTypeIds_, VaultFeeType.USAGE, type(IUniswapV4StandardExchangeLiquidReserveV2).interfaceId
        );
    }

    function vaultTypes() public pure override returns (bytes4[] memory typeIDs) {
        return facetInterfaces();
    }

    function vaultDeclaration() public pure override returns (VaultPkgDeclaration memory declaration) {
        return VaultPkgDeclaration({name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()});
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](16);
        interfaces[15] = type(IStandardExchangePretransfer).interfaceId;
        interfaces[0] = type(IERC20).interfaceId;
        interfaces[1] = type(IERC20Metadata).interfaceId;
        interfaces[2] = type(IERC20).interfaceId ^ type(IERC20Metadata).interfaceId;
        interfaces[3] = type(IERC5267).interfaceId;
        interfaces[4] = type(IERC20Permit).interfaceId;
        interfaces[5] = type(IStandardVault).interfaceId;
        interfaces[6] = type(IStandardExchangeIn).interfaceId;
        interfaces[7] = type(IStandardExchangeOut).interfaceId;
        interfaces[8] = type(IUniswapV4StandardExchangePositionImportV2).interfaceId;
        interfaces[9] = type(IUniswapV4StandardExchangeLiquidReserveV2).interfaceId;
        interfaces[10] = type(IStandardExchangeInMulti).interfaceId;
        interfaces[11] = type(IStandardExchangeOutMulti).interfaceId;
        interfaces[12] = type(IStandardExchangeTransitionQuote).interfaceId;
        interfaces[13] = type(IStandardizedYield).interfaceId;
        interfaces[14] = type(IStandardExchangeExternalQuote).interfaceId;
    }

    function packageName() public pure override returns (string memory) {
        return type(UniswapV4StandardExchangeDFPkgV2).name;
    }

    function facetCuts() public view override returns (IDiamond.FacetCut[] memory facetCuts_) {
        facetCuts_ = new IDiamond.FacetCut[](15);
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
            facetAddress: address(UNISWAP_V4_STANDARD_EXCHANGE_IN_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: UNISWAP_V4_STANDARD_EXCHANGE_IN_FACET.facetFuncs()
        });
        facetCuts_[6] = IDiamond.FacetCut({
            facetAddress: address(UNISWAP_V4_STANDARD_EXCHANGE_IN_QUERY_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: UNISWAP_V4_STANDARD_EXCHANGE_IN_QUERY_FACET.facetFuncs()
        });
        facetCuts_[7] = IDiamond.FacetCut({
            facetAddress: address(UNISWAP_V4_STANDARD_EXCHANGE_POSITION_IMPORT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: UNISWAP_V4_STANDARD_EXCHANGE_POSITION_IMPORT_FACET.facetFuncs()
        });
        facetCuts_[8] = IDiamond.FacetCut({
            facetAddress: address(UNISWAP_V4_STANDARD_EXCHANGE_OUT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: UNISWAP_V4_STANDARD_EXCHANGE_OUT_FACET.facetFuncs()
        });
        facetCuts_[9] = IDiamond.FacetCut({
            facetAddress: address(UNISWAP_V4_STANDARD_EXCHANGE_OUT_QUERY_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: UNISWAP_V4_STANDARD_EXCHANGE_OUT_QUERY_FACET.facetFuncs()
        });
        facetCuts_[10] = IDiamond.FacetCut({
            facetAddress: address(UNISWAP_V4_STANDARD_EXCHANGE_LIQUID_RESERVE_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: UNISWAP_V4_STANDARD_EXCHANGE_LIQUID_RESERVE_FACET.facetFuncs()
        });
        facetCuts_[11] = IDiamond.FacetCut({
            facetAddress: address(UNISWAP_V4_STANDARD_EXCHANGE_IN_MULTI_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: UNISWAP_V4_STANDARD_EXCHANGE_IN_MULTI_FACET.facetFuncs()
        });
        facetCuts_[12] = IDiamond.FacetCut({
            facetAddress: address(UNISWAP_V4_STANDARD_EXCHANGE_IN_MULTI_QUERY_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: UNISWAP_V4_STANDARD_EXCHANGE_IN_MULTI_QUERY_FACET.facetFuncs()
        });
        facetCuts_[13] = IDiamond.FacetCut({
            facetAddress: address(UNISWAP_V4_STANDARD_EXCHANGE_OUT_MULTI_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: UNISWAP_V4_STANDARD_EXCHANGE_OUT_MULTI_FACET.facetFuncs()
        });
        facetCuts_[14] = IDiamond.FacetCut({
            facetAddress: address(UNISWAP_V4_STANDARD_EXCHANGE_OUT_MULTI_QUERY_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: UNISWAP_V4_STANDARD_EXCHANGE_OUT_MULTI_QUERY_FACET.facetFuncs()
        });
    }

    function diamondConfig() public view override returns (DiamondConfig memory config) {
        config = DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory pkgArgs) public pure override returns (bytes32) {
        return abi.encode(pkgArgs)._hash();
    }

    function processArgs(bytes memory pkgArgs) public view returns (bytes memory processedPkgArgs) {
        if (msg.sender != address(VAULT_REGISTRY_DEPLOYMENT)) {
            revert NotCalledByRegistry(msg.sender);
        }
        if (TWAP_ORACLE.poolManager() != address(POOL_MANAGER)) {
            revert TwapOraclePoolManagerMismatch();
        }
        return pkgArgs;
    }

    function updatePkg(address, bytes memory) external pure returns (bool) {
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory decodedArgs = abi.decode(initArgs, (PkgArgs));

        address[] memory tokens = new address[](2);
        tokens[0] = _erc20Face(Currency.unwrap(decodedArgs.poolKey.currency0));
        tokens[1] = _erc20Face(Currency.unwrap(decodedArgs.poolKey.currency1));

        MultiAssetBasicVaultRepo._initialize(tokens);
        StandardVaultRepo._initialize(
            VAULT_FEE_ORACLE_QUERY, vaultFeeTypeIds(), vaultTypes(), abi.encode(tokens)._hash()
        );
        VaultFeeOracleQueryAwareRepo._initialize(VAULT_FEE_ORACLE_QUERY);
        Permit2AwareRepo._initialize(PERMIT2);
        UniswapV4PoolManagerAwareRepoV2._initialize(POOL_MANAGER);
        UniswapV4TwapOracleAwareRepo._initialize(TWAP_ORACLE);
        UniswapV4PoolKeyAwareRepoV2._initialize(decodedArgs.poolKey);
        UniswapV4PositionRepoV2._initialize(bytes32(0));
        UniswapV4PositionRepoV2._setAuthorizedPositionManager(POSITION_MANAGER);
        WETHAwareRepo._initialize(WETH);

        _approvePoolManagerIfErc20(tokens[0]);
        _approvePoolManagerIfErc20(tokens[1]);

        string memory name_ =
            string.concat("UniV4 Vault of (", _symbolOrToken(tokens[0]), " / ", _symbolOrToken(tokens[1]), ")");
        ERC20Repo._initialize(name_, "UV4X", 18);
        EIP712Repo._initialize(name_, "1");
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](15);
        facetAddresses_[0] = address(ERC20_FACET);
        facetAddresses_[1] = address(ERC5267_FACET);
        facetAddresses_[2] = address(ERC2612_FACET);
        facetAddresses_[3] = address(MULTI_ASSET_BASIC_VAULT_FACET);
        facetAddresses_[4] = address(MULTI_ASSET_STANDARD_VAULT_FACET);
        facetAddresses_[5] = address(UNISWAP_V4_STANDARD_EXCHANGE_IN_FACET);
        facetAddresses_[6] = address(UNISWAP_V4_STANDARD_EXCHANGE_IN_QUERY_FACET);
        facetAddresses_[7] = address(UNISWAP_V4_STANDARD_EXCHANGE_POSITION_IMPORT_FACET);
        facetAddresses_[8] = address(UNISWAP_V4_STANDARD_EXCHANGE_OUT_FACET);
        facetAddresses_[9] = address(UNISWAP_V4_STANDARD_EXCHANGE_OUT_QUERY_FACET);
        facetAddresses_[10] = address(UNISWAP_V4_STANDARD_EXCHANGE_LIQUID_RESERVE_FACET);
        facetAddresses_[11] = address(UNISWAP_V4_STANDARD_EXCHANGE_IN_MULTI_FACET);
        facetAddresses_[12] = address(UNISWAP_V4_STANDARD_EXCHANGE_IN_MULTI_QUERY_FACET);
        facetAddresses_[13] = address(UNISWAP_V4_STANDARD_EXCHANGE_OUT_MULTI_FACET);
        facetAddresses_[14] = address(UNISWAP_V4_STANDARD_EXCHANGE_OUT_MULTI_QUERY_FACET);
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

    function deployVault(PoolKey memory poolKey) external override returns (address vault) {
        vault = VAULT_REGISTRY_DEPLOYMENT.deployVault(
            IUniswapV4StandardExchangeDFPkgV2(address(this)), abi.encode(PkgArgs({poolKey: poolKey}))
        );
    }

    function _erc20Face(address token) internal view returns (address) {
        if (token == address(0)) {
            return address(WETH);
        }
        return token;
    }

    function _approvePoolManagerIfErc20(address token) internal {
        // Vault tokens are ERC-20 faces. Native ETH is mapped to WETH before approve.
        if (token == address(0)) {
            return;
        }
        IERC20(token).approve(address(PERMIT2), type(uint256).max);
        PERMIT2.approve(token, address(POOL_MANAGER), type(uint160).max, type(uint48).max);
    }

    function _symbolOrToken(address token) internal view returns (string memory symbol_) {
        if (token == address(0)) {
            return "ETH";
        }
        try IERC20Metadata(token).symbol() returns (string memory fetchedSymbol) {
            return fetchedSymbol;
        } catch {
            return "TOKEN";
        }
    }
}
