// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV3FullSpreadStandardExchangeVaultDFPkg} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/IUniswapV3FullSpreadStandardExchangeVaultDFPkg.sol";

import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {IUniswapV3FullSpreadStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";
import {IStandardExchangeBundleIn, IStandardExchangeBundleOut} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
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
import {IStandardExchangeStateQuote} from "contracts/interfaces/IStandardExchangeStateQuote.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {VaultFeeType} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {UniswapV3FullSpreadStandardExchangeVaultPoolAwareRepo} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultPoolAwareRepo.sol";
import {UniswapV3FullSpreadStandardExchangeVaultFactoryAwareRepo} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultFactoryAwareRepo.sol";
import {
    IUniswapV3FullSpreadStandardExchangeVaultPositionImport
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol";
import {
    IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.sol";



/**
 * @title UniswapV3FullSpreadStandardExchangeVaultDFPkg
 * @notice New-vault accounting package, with 14 disjoint facet cuts.
 * @dev Retired selectors: localReserve, deployedReserve, actualLiquidReservePercentage,
 * targetLiquidReservePercentage, rebalanceLiquidReserve, exchangeInManyToOne,
 * previewExchangeInManyToOne, exchangeOutOneToMany, previewExchangeOutOneToMany,
 * quoteState, quoteTransition, quoteShareBalance, quoteTotalSupply, quoteAssets,
 * quoteExternalDeposit, quoteExternalExchange, captureFrozenQuoteInputs,
 * exchangeRate, assetInfo, deposit, redeem, claimRewards, accruedRewards,
 * rewardIndexesCurrent, rewardIndexesStored, getRewardTokens, isValidTokenIn,
 * isValidTokenOut, yieldToken, getTokensIn, getTokensOut, previewDeposit,
 * previewRedeem. No getRate or unlockCallback is installed.
 */
contract UniswapV3FullSpreadStandardExchangeVaultDFPkg is IUniswapV3FullSpreadStandardExchangeVaultDFPkg {
    using BetterEfficientHashLib for bytes;

    IFacet immutable ERC20_FACET;
    IFacet immutable ERC5267_FACET;
    IFacet immutable ERC2612_FACET;
    IFacet immutable MULTI_ASSET_BASIC_VAULT_FACET;
    IFacet immutable MULTI_ASSET_STANDARD_VAULT_FACET;
    IFacet immutable UNISWAP_V3_STANDARD_EXCHANGE_IN_FACET;
    IFacet immutable UNISWAP_V3_STANDARD_EXCHANGE_IN_QUERY_FACET;
    IFacet immutable UNISWAP_V3_STANDARD_EXCHANGE_OUT_FACET;
    IFacet immutable UNISWAP_V3_STANDARD_EXCHANGE_OUT_QUERY_FACET;
    IFacet immutable UNISWAP_V3_STANDARD_EXCHANGE_POSITION_IMPORT_FACET;
    IFacet immutable RESERVE_FACET;
    IFacet immutable BUNDLE_FACET;
    IFacet immutable BUNDLE_QUERY_FACET;
    IFacet immutable MAINTENANCE_FACET;
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
        UNISWAP_V3_STANDARD_EXCHANGE_OUT_QUERY_FACET = pkgInit.uniswapV3StandardExchangeOutQueryFacet;
        UNISWAP_V3_STANDARD_EXCHANGE_POSITION_IMPORT_FACET = pkgInit.uniswapV3StandardExchangePositionImportFacet;
        RESERVE_FACET = pkgInit.uniswapV3StandardExchangeLiquidReserveFacet;
        BUNDLE_FACET = pkgInit.uniswapV3StandardExchangeInMultiFacet;
        BUNDLE_QUERY_FACET = pkgInit.uniswapV3StandardExchangeInMultiQueryFacet;
        MAINTENANCE_FACET = pkgInit.uniswapV3StandardExchangeOutMultiFacet;
        VAULT_FEE_ORACLE_QUERY = pkgInit.vaultFeeOracleQuery;
        VAULT_REGISTRY_DEPLOYMENT = pkgInit.vaultRegistryDeployment;
        PERMIT2 = pkgInit.permit2;
        UNISWAP_V3_FACTORY = pkgInit.uniswapV3Factory;
    }

    function name() public pure override returns (string memory) {
        return packageName();
    }

    function vaultFeeTypeIds() public pure override returns (bytes32 vaultFeeTypeIds_) {
        // Historical fee identity only: its sleeve API is deliberately not installed.
        return VaultTypeUtils._insertFeeTypeId(
            vaultFeeTypeIds_, VaultFeeType.USAGE, type(IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve).interfaceId
        );
    }

    function vaultTypes() public pure override returns (bytes4[] memory typeIDs) {
        return facetInterfaces();
    }

    function vaultDeclaration() public pure override returns (VaultPkgDeclaration memory declaration) {
        return VaultPkgDeclaration({name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()});
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](14);
        interfaces[0] = type(IERC20).interfaceId;
        interfaces[1] = type(IERC20Metadata).interfaceId;
        interfaces[2] = type(IERC20).interfaceId ^ type(IERC20Metadata).interfaceId;
        interfaces[3] = type(IERC5267).interfaceId;
        interfaces[4] = type(IERC20Permit).interfaceId;
        interfaces[5] = type(IStandardVault).interfaceId;
        interfaces[6] = type(IStandardExchangeIn).interfaceId;
        interfaces[7] = type(IStandardExchangeOut).interfaceId;
        interfaces[8] = type(IUniswapV3FullSpreadStandardExchangeVaultPositionImport).interfaceId;
        interfaces[9] = type(IBasicVault).interfaceId;
        interfaces[10] = type(IStandardExchangeBundleIn).interfaceId;
        interfaces[11] = type(IStandardExchangeBundleOut).interfaceId;
        interfaces[12] = type(IUniswapV3FullSpreadStandardExchangeVault).interfaceId;
        interfaces[13] = type(IStandardExchangeStateQuote).interfaceId;
    }

    function packageName() public pure override returns (string memory) {
        return "UniswapV3FullSpreadStandardExchangeVaultDFPkg.v4Accounting.v2";
    }

    function facetCuts() public view override returns (IDiamond.FacetCut[] memory facetCuts_) {
        address[] memory facets = facetAddresses();
        facetCuts_ = new IDiamond.FacetCut[](facets.length);
        for (uint256 i; i < facets.length; ++i) {
            bytes4[] memory selectors;
            if (i == 3) {
                selectors = new bytes4[](1);
                selectors[0] = IBasicVault.vaultTokens.selector;
            } else {
                selectors = IFacet(facets[i]).facetFuncs();
            }
            facetCuts_[i] = IDiamond.FacetCut({
                facetAddress: facets[i],
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: selectors
            });
        }
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
        UniswapV3FullSpreadStandardExchangeVaultFactoryAwareRepo._initialize(UNISWAP_V3_FACTORY);
        UniswapV3FullSpreadStandardExchangeVaultPoolAwareRepo._initialize(decodedArgs.pool);

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
        facetAddresses_ = new address[](14);
        facetAddresses_[0] = address(ERC20_FACET);
        facetAddresses_[1] = address(ERC5267_FACET);
        facetAddresses_[2] = address(ERC2612_FACET);
        facetAddresses_[3] = address(MULTI_ASSET_BASIC_VAULT_FACET);
        facetAddresses_[4] = address(MULTI_ASSET_STANDARD_VAULT_FACET);
        facetAddresses_[5] = address(UNISWAP_V3_STANDARD_EXCHANGE_IN_FACET);
        facetAddresses_[6] = address(UNISWAP_V3_STANDARD_EXCHANGE_IN_QUERY_FACET);
        facetAddresses_[7] = address(UNISWAP_V3_STANDARD_EXCHANGE_OUT_FACET);
        facetAddresses_[8] = address(UNISWAP_V3_STANDARD_EXCHANGE_OUT_QUERY_FACET);
        facetAddresses_[9] = address(UNISWAP_V3_STANDARD_EXCHANGE_POSITION_IMPORT_FACET);
        facetAddresses_[10] = address(RESERVE_FACET);
        facetAddresses_[11] = address(BUNDLE_FACET);
        facetAddresses_[12] = address(BUNDLE_QUERY_FACET);
        facetAddresses_[13] = address(MAINTENANCE_FACET);
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

    function deployVault(IUniswapV3Pool pool) external override returns (address vault) {
        vault = VAULT_REGISTRY_DEPLOYMENT.deployVault(
            IUniswapV3FullSpreadStandardExchangeVaultDFPkg(address(this)), abi.encode(PkgArgs({pool: pool}))
        );
    }

    function _symbolOrToken(address token) internal view returns (string memory symbol_) {
        return IERC20Metadata(token).symbol();
    }

    function _feeLabel(uint24 fee) internal pure returns (string memory) {
        if (fee == 100) return "0.01%";
        if (fee == 500) return "0.05%";
        if (fee == 3000) return "0.3%";
        if (fee == 10000) return "1%";
        return "fee";
    }
}
