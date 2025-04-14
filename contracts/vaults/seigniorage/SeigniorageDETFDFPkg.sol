// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IERC20 as OZIERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {
    PoolRoleAccounts,
    TokenConfig,
    TokenType
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IRouter} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRouter.sol";
import {IVault as IBalancerVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IWeightedPool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
// import {PoolRoleAccounts, TokenConfig, TokenType} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {WeightedPool} from "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPool.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {
    IWeightedPool8020Factory
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool8020Factory.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {
    IERC20PermitMintBurnLockedOwnableDFPkg
} from "@crane/contracts/tokens/ERC20/ERC20PermitMintBurnLockedOwnableDFPkg.sol";
// import {IWeightedPool8020Factory} from "contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool8020Factory.sol";

import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import "contracts/constants/Indexedex_CONSTANTS.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {ISeigniorageDETF} from "contracts/interfaces/ISeigniorageDETF.sol";
import {ISeigniorageNFTVault} from "contracts/interfaces/ISeigniorageNFTVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {VaultFeeType} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {ISeigniorageDETFUnderwriting} from "contracts/vaults/seigniorage/SeigniorageDETFUnderwritingTarget.sol";
import {SeigniorageDETFRepo} from "contracts/vaults/seigniorage/SeigniorageDETFRepo.sol";
import {ISeigniorageNFTVaultDFPkg} from "contracts/vaults/seigniorage/SeigniorageNFTVaultDFPkg.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {
    IStandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/StandardExchangeRateProviderDFPkg.sol";

interface IWeightedPool8020FactoryExtended is IWeightedPool8020Factory {
    function getDeploymentAddress(bytes memory constructorArgs, bytes32 salt) external view returns (address);
    function getPoolVersion() external view returns (string memory);
    function getVault() external view returns (IBalancerVault);
}

/**
 * @title ISeigniorageDETFDFPkg
 * @notice Interface for Seigniorage DETF Diamond Factory Package.
 */
interface ISeigniorageDETFDFPkg is IDiamondFactoryPackage {
    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;

        IFacet erc4626BasicVaultFacet;
        IFacet erc4626StandardVaultFacet;

        IFacet seigniorageDETFExchangeInFacet;
        IFacet seigniorageDETFExchangeOutFacet;
        IFacet seigniorageDETFUnderwritingFacet;

        IVaultFeeOracleQuery feeOracle;
        IVaultRegistryDeployment vaultRegistryDeployment;

        IPermit2 permit2;

        IBalancerVault balancerV3Vault;
        IRouter balancerV3Router;
        IBalancerV3StandardExchangeRouterPrepay balancerV3PrepayRouter;

        /// @notice Balancer V3 factory used to create the canonical 80/20 reserve pool.
        IWeightedPool8020Factory weightedPool8020Factory;

        IDiamondPackageCallBackFactory diamondFactory;

        /// @notice Package used to deploy the seigniorage reward token (sRBT) during DETF init.
        IERC20PermitMintBurnLockedOwnableDFPkg seigniorageTokenPkg;
        /// @notice Package used to deploy the seigniorage NFT vault during DETF init.
        ISeigniorageNFTVaultDFPkg seigniorageNFTVaultPkg;

        /// @notice Package used to deploy a StandardExchange-backed Balancer rate provider for the reserve vault token.
        IStandardExchangeRateProviderDFPkg reserveVaultRateProviderPkg;
    }

    struct PkgArgs {
        string name;
        string symbol;
        IStandardExchangeProxy reserveVault;
        IERC20Metadata reserveVaultRateTarget;
        /// @notice Rate provider configured for the reserve vault token in the Balancer pool.
        // IRateProvider reserveVaultRateProvider;
        /// @notice Swap fee used when creating the reserve pool.
        // uint256 swapFeePercentage;
        // address[] reserveVaultTokens;
        // uint256 selfIndexInReservePool;
        // uint256 selfReservePoolWeight;
        // uint256 reserveVaultIndexInReservePool;
        // uint256 reserveVaultReservePoolWeight;
    }

    error NotCalledByRegistry(address caller);
}

/**
 * @title SeigniorageDETFDFPkg
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Diamond Factory Package for deploying Seigniorage DETF vaults.
 */
contract SeigniorageDETFDFPkg is ISeigniorageDETFDFPkg, IStandardVaultPkg {
    using BetterEfficientHashLib for bytes;
    using BetterSafeERC20 for IERC20;
    using BetterSafeERC20 for IERC20Metadata;
    using SeigniorageDETFRepo for SeigniorageDETFRepo.Storage;

    uint256 private constant _EIGHTY = 80e16; // 80%
    uint256 private constant _TWENTY = 20e16; // 20%

    // Balancer V3 pools revert if swapFeePercentage is below their minimum.
    // We use a conservative tiny floor to avoid misconfigured fee-oracle defaults.
    uint256 private constant _MIN_BALANCER_SWAP_FEE_PERCENTAGE = 10_000_000_000_000; // 1e13

    SeigniorageDETFDFPkg SELF;

    IFacet immutable ERC20_FACET;
    IFacet immutable ERC5267_FACET;
    IFacet immutable ERC2612_FACET;

    IFacet immutable ERC4626_BASIC_VAULT_FACET;
    IFacet immutable ERC4626_STANDARD_VAULT_FACET;

    IFacet immutable SEIGNIORAGE_DETF_EXCHANGE_IN_FACET;
    IFacet immutable SEIGNIORAGE_DETF_EXCHANGE_OUT_FACET;
    IFacet immutable SEIGNIORAGE_DETF_UNDERWRITING_FACET;

    IVaultFeeOracleQuery immutable VAULT_FEE_ORACLE_QUERY;
    IVaultRegistryDeployment immutable VAULT_REGISTRY_DEPLOYMENT;

    IPermit2 immutable PERMIT2;

    IBalancerVault immutable BALANCER_V3_VAULT;
    // IRouter immutable BALANCER_V3_ROUTER;
    IBalancerV3StandardExchangeRouterPrepay immutable BALANCER_V3_PREPAY_ROUTER;

    IWeightedPool8020Factory immutable WEIGHTED_POOL_8020_FACTORY;

    IDiamondPackageCallBackFactory immutable DIAMOND_FACTORY;

    IERC20PermitMintBurnLockedOwnableDFPkg immutable SEIGNIORAGE_TOKEN_PKG;
    ISeigniorageNFTVaultDFPkg immutable SEIGNIORAGE_NFT_VAULT_PKG;
    IStandardExchangeRateProviderDFPkg immutable RESERVE_VAULT_RATE_PROVIDER_PKG;

    constructor(PkgInit memory pkgInit) {
        SELF = this;
        ERC20_FACET = pkgInit.erc20Facet;
        ERC5267_FACET = pkgInit.erc5267Facet;
        ERC2612_FACET = pkgInit.erc2612Facet;

        ERC4626_BASIC_VAULT_FACET = pkgInit.erc4626BasicVaultFacet;
        ERC4626_STANDARD_VAULT_FACET = pkgInit.erc4626StandardVaultFacet;

        SEIGNIORAGE_DETF_EXCHANGE_IN_FACET = pkgInit.seigniorageDETFExchangeInFacet;
        SEIGNIORAGE_DETF_EXCHANGE_OUT_FACET = pkgInit.seigniorageDETFExchangeOutFacet;
        SEIGNIORAGE_DETF_UNDERWRITING_FACET = pkgInit.seigniorageDETFUnderwritingFacet;

        VAULT_FEE_ORACLE_QUERY = pkgInit.feeOracle;
        VAULT_REGISTRY_DEPLOYMENT = pkgInit.vaultRegistryDeployment;
        PERMIT2 = pkgInit.permit2;
        BALANCER_V3_VAULT = pkgInit.balancerV3Vault;
        // BALANCER_V3_ROUTER = pkgInit.balancerV3Router;
        BALANCER_V3_PREPAY_ROUTER = pkgInit.balancerV3PrepayRouter;

        WEIGHTED_POOL_8020_FACTORY = pkgInit.weightedPool8020Factory;

        DIAMOND_FACTORY = pkgInit.diamondFactory;
        SEIGNIORAGE_TOKEN_PKG = pkgInit.seigniorageTokenPkg;
        SEIGNIORAGE_NFT_VAULT_PKG = pkgInit.seigniorageNFTVaultPkg;
        RESERVE_VAULT_RATE_PROVIDER_PKG = pkgInit.reserveVaultRateProviderPkg;
    }

    /* ---------------------------------------------------------------------- */
    /*                              IStandardVaultPkg                          */
    /* ---------------------------------------------------------------------- */

    function name() public pure returns (string memory) {
        return packageName();
    }

    function vaultFeeTypeIds() public pure returns (bytes32 vaultFeeTypeIds_) {
        vaultFeeTypeIds_ =
            VaultTypeUtils._insertFeeTypeId(vaultFeeTypeIds_, VaultFeeType.USAGE, type(ISeigniorageDETF).interfaceId);
        vaultFeeTypeIds_ = VaultTypeUtils._insertFeeTypeId(
            vaultFeeTypeIds_, VaultFeeType.SEIGNIORAGE, type(ISeigniorageDETF).interfaceId
        );
    }

    function vaultTypes() public pure returns (bytes4[] memory typeIDs) {
        return facetInterfaces();
    }

    function vaultDeclaration() public pure returns (VaultPkgDeclaration memory declaration) {
        return VaultPkgDeclaration({name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()});
    }

    /* ---------------------------------------------------------------------- */
    /*                       IDiamondFactoryPackage                           */
    /* ---------------------------------------------------------------------- */

    function packageName() public pure returns (string memory name_) {
        return type(SeigniorageDETFDFPkg).name;
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](8);
        facetAddresses_[0] = address(ERC20_FACET);
        facetAddresses_[1] = address(ERC5267_FACET);
        facetAddresses_[2] = address(ERC2612_FACET);
        facetAddresses_[3] = address(ERC4626_BASIC_VAULT_FACET);
        facetAddresses_[4] = address(ERC4626_STANDARD_VAULT_FACET);
        facetAddresses_[5] = address(SEIGNIORAGE_DETF_EXCHANGE_IN_FACET);
        facetAddresses_[6] = address(SEIGNIORAGE_DETF_EXCHANGE_OUT_FACET);
        facetAddresses_[7] = address(SEIGNIORAGE_DETF_UNDERWRITING_FACET);
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](11);
        interfaces[0] = type(IERC20).interfaceId;
        interfaces[1] = type(IERC20Metadata).interfaceId;
        interfaces[2] = type(IERC20Metadata).interfaceId ^ type(IERC20).interfaceId;
        interfaces[3] = type(IERC20Permit).interfaceId;
        interfaces[4] = type(IERC5267).interfaceId;
        interfaces[5] = type(ISeigniorageDETF).interfaceId;
        interfaces[6] = type(IStandardExchangeIn).interfaceId;
        interfaces[7] = type(IStandardExchangeOut).interfaceId;
        interfaces[8] = type(ISeigniorageDETFUnderwriting).interfaceId;
        interfaces[9] = type(IBasicVault).interfaceId;
        interfaces[10] = type(IStandardVault).interfaceId;
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

    function facetCuts() public view returns (IDiamond.FacetCut[] memory facetCuts_) {
        facetCuts_ = new IDiamond.FacetCut[](8);

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
            facetAddress: address(ERC4626_BASIC_VAULT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC4626_BASIC_VAULT_FACET.facetFuncs()
        });
        facetCuts_[4] = IDiamond.FacetCut({
            facetAddress: address(ERC4626_STANDARD_VAULT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC4626_STANDARD_VAULT_FACET.facetFuncs()
        });
        facetCuts_[5] = IDiamond.FacetCut({
            facetAddress: address(SEIGNIORAGE_DETF_EXCHANGE_IN_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: SEIGNIORAGE_DETF_EXCHANGE_IN_FACET.facetFuncs()
        });
        facetCuts_[6] = IDiamond.FacetCut({
            facetAddress: address(SEIGNIORAGE_DETF_EXCHANGE_OUT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: SEIGNIORAGE_DETF_EXCHANGE_OUT_FACET.facetFuncs()
        });
        facetCuts_[7] = IDiamond.FacetCut({
            facetAddress: address(SEIGNIORAGE_DETF_UNDERWRITING_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: SEIGNIORAGE_DETF_UNDERWRITING_FACET.facetFuncs()
        });
    }

    function diamondConfig() public view returns (DiamondConfig memory config) {
        config = IDiamondFactoryPackage.DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt) {
        return abi.encode(pkgArgs)._hash();
    }

    function processArgs(bytes memory pkgArgs) public view returns (bytes memory processedPkgArgs) {
        if (msg.sender != address(VAULT_REGISTRY_DEPLOYMENT)) {
            revert NotCalledByRegistry(msg.sender);
        }
        return pkgArgs;
    }

    function updatePkg(address, bytes memory) public pure virtual returns (bool) {
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        BalancerV3VaultAwareRepo._initialize(BALANCER_V3_VAULT);
        Permit2AwareRepo._initialize(PERMIT2);

        PkgArgs memory args = abi.decode(initArgs, (PkgArgs));

        if (bytes(args.name).length == 0) {
            args.name = "Seigniorage DETF of ";
            args.name = string.concat(args.name, args.reserveVault.name());
        }

        if (bytes(args.symbol).length == 0) {
            args.symbol = "SDETF";
        }

        ERC20Repo._initialize(args.name, args.symbol, 18);

        EIP712Repo._initialize(args.name, "1");

        address seigniorageToken = SEIGNIORAGE_TOKEN_PKG.deployToken(
            string.concat("Seigniorage RBT of ", args.name),
            string.concat("sRBT-", args.symbol),
            18,
            address(this),
            abi.encode(address(this))._hash()
        );

        SeigniorageDETFRepo._initialize(
            VAULT_FEE_ORACLE_QUERY,
            BALANCER_V3_PREPAY_ROUTER,
            IStandardExchange(address(args.reserveVault)),
            IERC20(address(args.reserveVaultRateTarget)),
            IERC20MintBurn(seigniorageToken)
        );
    }

    function postDeploy(address expectedProxy) public returns (bool) {
        // Detect if we're inside the proxy yet.
        if (address(this) != expectedProxy) {
            // console.log("StandardExchangeSingleVaultSeigniorageDETFDFPkg postDeploy call to proxy");
            // We're not in the proxy yet, so call the proxy to DEELGATECALL to this function.
            IPostDeployAccountHook(expectedProxy).postDeploy();

            // Prevent running postDeploy logic against the package contract's storage.
            return true;
        }

        SeigniorageDETFRepo.Storage storage detfStorage = SeigniorageDETFRepo._layout();

        address reservePool;
        {
            IRateProvider reserveVaultRateProvider = RESERVE_VAULT_RATE_PROVIDER_PKG.deployRateProvider(
                // IStandardExchange reserveVault,
                SeigniorageDETFRepo._reserveVault(detfStorage),
                // IERC20 rateTarget
                SeigniorageDETFRepo._reserveVaultRateTarget(detfStorage)
            );

            // Create and register the reserve pool using the canonical 80/20 factory.
            TokenConfig memory highWeightTokenConfig = TokenConfig({
                token: OZIERC20(expectedProxy),
                tokenType: TokenType.STANDARD,
                rateProvider: IRateProvider(address(0)),
                paysYieldFees: false
            });

            TokenConfig memory lowWeightTokenConfig = TokenConfig({
                token: OZIERC20(address(SeigniorageDETFRepo._reserveVault(detfStorage))),
                tokenType: TokenType.WITH_RATE,
                rateProvider: reserveVaultRateProvider,
                paysYieldFees: false
            });

            PoolRoleAccounts memory roleAccounts;
            roleAccounts.pauseManager = address(VAULT_FEE_ORACLE_QUERY.feeTo());
            roleAccounts.swapFeeManager = roleAccounts.pauseManager;
            roleAccounts.poolCreator = roleAccounts.pauseManager;

            uint256 swapFeePercentage =
                VAULT_FEE_ORACLE_QUERY.defaultDexSwapFeeOfTypeId(type(ISeigniorageDETFUnderwriting).interfaceId);
            if (swapFeePercentage == 0) {
                swapFeePercentage = VAULT_FEE_ORACLE_QUERY.defaultDexSwapFee();
            }
            if (swapFeePercentage < _MIN_BALANCER_SWAP_FEE_PERCENTAGE) {
                swapFeePercentage = _MIN_BALANCER_SWAP_FEE_PERCENTAGE;
            }

            reservePool = WEIGHTED_POOL_8020_FACTORY.create(
                highWeightTokenConfig, lowWeightTokenConfig, roleAccounts, swapFeePercentage
            );
        }

        ERC4626Repo._initialize(IERC20(reservePool), 18, 9);

        address nft;
        {
            ERC20Repo.Storage storage erc20Storage = ERC20Repo._layout();

            nft = SEIGNIORAGE_NFT_VAULT_PKG.deployVault(
                // string memory name,
                string.concat("Seigniorage NFT Vault of ", ERC20Repo._name(erc20Storage)),
                // string memory symbol,
                string.concat("sNFT-", ERC20Repo._symbol(erc20Storage)),
                // ISeigniorageDETF detfToken,
                ISeigniorageDETF(address(this)),
                // IERC20 claimToken,
                IERC20(address(SeigniorageDETFRepo._reserveVault(detfStorage))),
                // IERC20 lpToken,
                IERC20(reservePool),
                // IERC20MintBurn rewardToken,
                SeigniorageDETFRepo._seigniorageToken(detfStorage),
                // uint8 decimalOffset,
                9,
                // address owner
                address(this)
            );
        }

        (uint256 selfIndexInReservePool_, uint256 reserveVaultIndexInReservePool_) =
            address(this) < address(SeigniorageDETFRepo._reserveVault(detfStorage)) ? (0, 1) : (1, 0);

        detfStorage._initialize(
            selfIndexInReservePool_, _EIGHTY, reserveVaultIndexInReservePool_, _TWENTY, ISeigniorageNFTVault(nft)
        );

        return true;
    }

    // function _initializeSeigniorageRepo(
    //     PkgArgs memory args,
    //     address predictedReservePool,
    //     IERC20MintBurn seigniorageToken,
    //     ISeigniorageNFTVault seigniorageNFTVault
    // ) internal {
    //     SeigniorageDETFRepo._initialize(
    //         BALANCER_V3_VAULT,
    //         BALANCER_V3_ROUTER,
    //         BALANCER_V3_PREPAY_ROUTER,
    //         args.reserveVault,
    //         args.reserveVaultRateTarget,
    //         args.reserveVaultTokens,
    //         args.selfIndexInReservePool,
    //         args.selfReservePoolWeight,
    //         args.reserveVaultIndexInReservePool,
    //         args.reserveVaultReservePoolWeight,
    //         seigniorageToken,
    //         seigniorageNFTVault,
    //         VAULT_FEE_ORACLE_QUERY
    //     );

    //     SeigniorageDETFRepo._setReservePool(IWeightedPool(predictedReservePool));
    // }

    // function _predictReservePool(PkgArgs memory args, address detfToken) internal view returns (address) {
    //     // Mirror WeightedPool8020Factory.getPool() but without calling IERC20Metadata(symbol) on `detfToken`.
    //     // We hardcode the 80/20 orientation as:
    //     // - DETF token: 80%
    //     // - reserve vault token: 20%
    //     // The constructor args include token symbols, but we can safely use:
    //     // - args.symbol for the DETF (we set it during initAccount)
    //     // - reserveVault symbol() (contract already exists)

    //     IWeightedPool8020FactoryExtended factory = IWeightedPool8020FactoryExtended(address(WEIGHTED_POOL_8020_FACTORY));

    //     IBalancerVault factoryVault = factory.getVault();
    //     if (address(factoryVault) != address(BALANCER_V3_VAULT)) {
    //         revert ReservePoolVaultMismatch(address(BALANCER_V3_VAULT), address(factoryVault));
    //     }

    //     uint256[] memory weights = new uint256[](2);
    //     // Tokens must be sorted for the weights array inside constructor args.
    //     // The factory compares addresses directly.
    //     uint256 detfIdx = detfToken > address(args.reserveVault) ? 1 : 0;
    //     uint256 reserveVaultIdx = detfIdx == 0 ? 1 : 0;

    //     weights[detfIdx] = 80e16;
    //     weights[reserveVaultIdx] = 20e16;

    //     string memory highWeightTokenSymbol = args.symbol;
    //     string memory lowWeightTokenSymbol = IERC20Metadata(address(args.reserveVault)).safeSymbol();

    //     bytes memory constructorArgs = abi.encode(
    //         WeightedPool.NewPoolParams({
    //             name: string.concat("Balancer 80 ", highWeightTokenSymbol, " 20 ", lowWeightTokenSymbol),
    //             symbol: string.concat("B-80", highWeightTokenSymbol, "-20", lowWeightTokenSymbol),
    //             numTokens: 2,
    //             normalizedWeights: weights,
    //             version: factory.getPoolVersion()
    //         }),
    //         factoryVault
    //     );

    //     // Salt must match WeightedPool8020Factory's deterministic address derivation.
    //     bytes32 salt = keccak256(abi.encode(block.chainid, detfToken, address(args.reserveVault)));
    //     return factory.getDeploymentAddress(constructorArgs, salt);
    // }
}
