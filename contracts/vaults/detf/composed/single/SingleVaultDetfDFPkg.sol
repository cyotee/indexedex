// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IERC20 as OZIERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVault as IBalancerVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {
    IWeightedPool8020Factory
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool8020Factory.sol";
import {
    PoolRoleAccounts,
    TokenConfig,
    TokenType
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {BetterAddress} from "@crane/contracts/utils/BetterAddress.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";
import {MultiStepOwnableRepo} from "@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import "contracts/constants/Indexedex_CONSTANTS.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRICHIR} from "contracts/interfaces/IRICHIR.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISingleVaultDetf} from "contracts/interfaces/ISingleVaultDetf.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IRICHIRDFPkg} from "contracts/vaults/protocol/RICHIRDFPkg.sol";
import {ISuperChainBridgeTokenRegistry} from "@crane/contracts/protocols/l2s/superchain/registries/token/bridge/ISuperChainBridgeTokenRegistry.sol";
import {IStandardBridge} from "@crane/contracts/interfaces/protocols/l2s/superchain/IStandardBridge.sol";
import {ICrossDomainMessenger} from "@crane/contracts/interfaces/protocols/l2s/superchain/ICrossDomainMessenger.sol";
import {VaultFeeType} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {SingleVaultDetfRepo} from "contracts/vaults/detf/composed/single/SingleVaultDetfRepo.sol";
import {
    ISingleVaultDetfBonding
} from "contracts/vaults/detf/composed/single/SingleVaultDetfBondingTarget.sol";
import {DetfSuperchainBridgeRepo} from "contracts/vaults/detf/DetfSuperchainBridgeRepo.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/reusable/nft/IDetfSelfNftInventoryDFPkg.sol";
import {
    IStandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";
import {IUniswapV4StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";

interface ISingleVaultDetfDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    error NotCalledByRegistry(address caller);

    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;

        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;

        IFacet singleVaultDetfExchangeInFacet;
        IFacet singleVaultDetfExchangeInQueryFacet;
        IFacet singleVaultDetfInfoFacet;
        IFacet singleVaultDetfExchangeOutFacet;
        IFacet singleVaultDetfBondingFacet;

        IFacet operableFacet;

        IVaultFeeOracleQuery feeOracle;

        IVaultRegistryDeployment vaultRegistryDeployment;

        IPermit2 permit2;

        IBalancerVault balancerV3Vault;
        IBalancerV3StandardExchangeRouterPrepay balancerV3PrepayRouter;
        IWeightedPool8020Factory weightedPool8020Factory;

        ISuperChainBridgeTokenRegistry bridgeTokenRegistry;
        IStandardBridge standardBridge;
        ICrossDomainMessenger messenger;
        address localRelayer;
        address peerRelayer;
        
        IUniswapV4StandardExchangeDFPkg wethRichVaultPkg;
        IDetfSelfNftInventoryDFPkg detfNFTVaultPkg;
        IRICHIRDFPkg richirPkg;
        IStandardExchangeRateProviderDFPkg rateProviderPkg;
        IDiamondPackageCallBackFactory diamondFactory;
        IERC20 wethToken;
    }

    struct PkgArgs {
        string name;
        string symbol;
        IERC20 richToken;
        uint256 richInitialDepositAmount;
        uint256 wethInitialDepositAmount;
        PoolKey wethRichPoolKey;
        uint24 wethRichWidthMultiplier;
    }

    function deployVault(
        string memory name,
        string memory symbol,
        IERC20 richToken,
        PoolKey memory wethRichPoolKey,
        uint24 wethRichWidthMultiplier
    ) external returns (address vault);
}

contract SingleVaultDetfDFPkg is ISingleVaultDetfDFPkg {
    using BetterAddress for address[];
    using BetterEfficientHashLib for bytes;

    bytes32 private constant _DEPLOYMENT_CONFIG_SLOT = keccak256("indexedex.vaults.detf.composed.single.pkg.deployment.config");

    uint256 private constant _EIGHTY = 80e16;
    uint256 private constant _TWENTY = 20e16;

    struct DeploymentConfig {
        PoolKey wethRichPoolKey;
        uint24 wethRichWidthMultiplier;
    }

    struct DerivedDeployment {
        IStandardExchange wethRichVault;
        IRateProvider vaultRateProvider;
        address reservePool;
        IDETFNFTVault detfNFTVault;
        uint256 detfNFTId;
        IRICHIR richirToken;
        uint256 detfIndex;
        uint256 vaultTokenIndex;
    }

    IFacet immutable ERC20_FACET;
    IFacet immutable ERC5267_FACET;
    IFacet immutable ERC2612_FACET;
    IFacet immutable MULTI_ASSET_BASIC_VAULT_FACET;
    IFacet immutable MULTI_ASSET_STANDARD_VAULT_FACET;
    IFacet immutable SINGLE_VAULT_DETF_EXCHANGE_IN_FACET;
    IFacet immutable SINGLE_VAULT_DETF_EXCHANGE_IN_QUERY_FACET;
    IFacet immutable SINGLE_VAULT_DETF_INFO_FACET;
    IFacet immutable SINGLE_VAULT_DETF_EXCHANGE_OUT_FACET;
    IFacet immutable SINGLE_VAULT_DETF_BONDING_FACET;
    IFacet immutable OPERABLE_FACET;
    IVaultFeeOracleQuery immutable VAULT_FEE_ORACLE_QUERY;
    IVaultRegistryDeployment immutable VAULT_REGISTRY_DEPLOYMENT;
    IPermit2 immutable PERMIT2;
    IBalancerVault immutable BALANCER_V3_VAULT;
    IBalancerV3StandardExchangeRouterPrepay immutable BALANCER_V3_PREPAY_ROUTER;
    IWeightedPool8020Factory immutable WEIGHTED_POOL_8020_FACTORY;
    ISuperChainBridgeTokenRegistry immutable BRIDGE_TOKEN_REGISTRY;
    IStandardBridge immutable STANDARD_BRIDGE;
    ICrossDomainMessenger immutable BRIDGE_MESSENGER;
    address immutable LOCAL_RELAYER;
    address immutable PEER_RELAYER;
    IUniswapV4StandardExchangeDFPkg immutable WETH_RICH_VAULT_PKG;
    IDetfSelfNftInventoryDFPkg immutable PROTOCOL_NFT_VAULT_PKG;
    IRICHIRDFPkg immutable RICHIR_PKG;
    IStandardExchangeRateProviderDFPkg immutable RATE_PROVIDER_PKG;
    IERC20 immutable WETH_TOKEN;

    function _deploymentConfigLayout() internal pure returns (DeploymentConfig storage layout_) {
        bytes32 slot_ = _DEPLOYMENT_CONFIG_SLOT;
        assembly {
            layout_.slot := slot_
        }
    }

    constructor(PkgInit memory pkgInit) {
        ERC20_FACET = pkgInit.erc20Facet;
        ERC5267_FACET = pkgInit.erc5267Facet;
        ERC2612_FACET = pkgInit.erc2612Facet;
        MULTI_ASSET_BASIC_VAULT_FACET = pkgInit.multiAssetBasicVaultFacet;
        MULTI_ASSET_STANDARD_VAULT_FACET = pkgInit.multiAssetStandardVaultFacet;
        SINGLE_VAULT_DETF_EXCHANGE_IN_FACET = pkgInit.singleVaultDetfExchangeInFacet;
        SINGLE_VAULT_DETF_EXCHANGE_IN_QUERY_FACET = pkgInit.singleVaultDetfExchangeInQueryFacet;
        SINGLE_VAULT_DETF_INFO_FACET = pkgInit.singleVaultDetfInfoFacet;
        SINGLE_VAULT_DETF_EXCHANGE_OUT_FACET = pkgInit.singleVaultDetfExchangeOutFacet;
        SINGLE_VAULT_DETF_BONDING_FACET = pkgInit.singleVaultDetfBondingFacet;
        OPERABLE_FACET = pkgInit.operableFacet;
        VAULT_FEE_ORACLE_QUERY = pkgInit.feeOracle;
        VAULT_REGISTRY_DEPLOYMENT = pkgInit.vaultRegistryDeployment;
        PERMIT2 = pkgInit.permit2;
        BALANCER_V3_VAULT = pkgInit.balancerV3Vault;
        BALANCER_V3_PREPAY_ROUTER = pkgInit.balancerV3PrepayRouter;
        WEIGHTED_POOL_8020_FACTORY = pkgInit.weightedPool8020Factory;
        BRIDGE_TOKEN_REGISTRY = pkgInit.bridgeTokenRegistry;
        STANDARD_BRIDGE = pkgInit.standardBridge;
        BRIDGE_MESSENGER = pkgInit.messenger;
        LOCAL_RELAYER = pkgInit.localRelayer;
        PEER_RELAYER = pkgInit.peerRelayer;
        WETH_RICH_VAULT_PKG = pkgInit.wethRichVaultPkg;
        PROTOCOL_NFT_VAULT_PKG = pkgInit.detfNFTVaultPkg;
        RICHIR_PKG = pkgInit.richirPkg;
        RATE_PROVIDER_PKG = pkgInit.rateProviderPkg;
        WETH_TOKEN = pkgInit.wethToken;
    }

    function name() public pure returns (string memory) {
        return packageName();
    }

    function vaultFeeTypeIds() public pure returns (bytes32 vaultFeeTypeIds_) {
        return VaultTypeUtils._insertFeeTypeId(vaultFeeTypeIds_, VaultFeeType.USAGE, type(ISingleVaultDetf).interfaceId);
    }

    function vaultTypes() public pure returns (bytes4[] memory typeIDs) {
        return facetInterfaces();
    }

    function vaultDeclaration() public pure returns (VaultPkgDeclaration memory declaration) {
        return VaultPkgDeclaration({name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()});
    }

    function packageName() public pure returns (string memory name_) {
        return type(SingleVaultDetfDFPkg).name;
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](10);
        facetAddresses_[0] = address(ERC20_FACET);
        facetAddresses_[1] = address(ERC5267_FACET);
        facetAddresses_[2] = address(ERC2612_FACET);
        facetAddresses_[3] = address(MULTI_ASSET_BASIC_VAULT_FACET);
        facetAddresses_[4] = address(MULTI_ASSET_STANDARD_VAULT_FACET);
        facetAddresses_[5] = address(SINGLE_VAULT_DETF_EXCHANGE_IN_FACET);
        facetAddresses_[6] = address(SINGLE_VAULT_DETF_EXCHANGE_IN_QUERY_FACET);
        facetAddresses_[7] = address(SINGLE_VAULT_DETF_INFO_FACET);
        facetAddresses_[8] = address(SINGLE_VAULT_DETF_EXCHANGE_OUT_FACET);
        facetAddresses_[9] = address(SINGLE_VAULT_DETF_BONDING_FACET);
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](10);
        interfaces_[0] = type(IERC20).interfaceId;
        interfaces_[1] = type(IERC20Metadata).interfaceId;
        interfaces_[2] = type(IERC20Permit).interfaceId;
        interfaces_[3] = type(IERC5267).interfaceId;
        interfaces_[4] = type(IBasicVault).interfaceId;
        interfaces_[5] = type(IStandardVault).interfaceId;
        interfaces_[6] = type(IStandardExchangeIn).interfaceId;
        interfaces_[7] = type(IStandardExchangeOut).interfaceId;
        interfaces_[8] = type(IProtocolDETF).interfaceId;
        interfaces_[9] = type(ISingleVaultDetf).interfaceId ^ type(ISingleVaultDetfBonding).interfaceId ^ type(IOperable).interfaceId;
    }

    function packageMetadata()
        public
        view
        returns (string memory name_, bytes4[] memory interfaces_, address[] memory facets_)
    {
        name_ = packageName();
        interfaces_ = facetInterfaces();
        facets_ = facetAddresses();
    }

    function facetCuts() public view returns (IDiamond.FacetCut[] memory facetCuts_) {
        facetCuts_ = new IDiamond.FacetCut[](10);
        facetCuts_[0] = IDiamond.FacetCut(address(ERC20_FACET), IDiamond.FacetCutAction.Add, ERC20_FACET.facetFuncs());
        facetCuts_[1] = IDiamond.FacetCut(address(ERC5267_FACET), IDiamond.FacetCutAction.Add, ERC5267_FACET.facetFuncs());
        facetCuts_[2] = IDiamond.FacetCut(address(ERC2612_FACET), IDiamond.FacetCutAction.Add, ERC2612_FACET.facetFuncs());
        facetCuts_[3] = IDiamond.FacetCut(address(MULTI_ASSET_BASIC_VAULT_FACET), IDiamond.FacetCutAction.Add, MULTI_ASSET_BASIC_VAULT_FACET.facetFuncs());
        facetCuts_[4] = IDiamond.FacetCut(address(MULTI_ASSET_STANDARD_VAULT_FACET), IDiamond.FacetCutAction.Add, MULTI_ASSET_STANDARD_VAULT_FACET.facetFuncs());
        facetCuts_[5] = IDiamond.FacetCut(address(SINGLE_VAULT_DETF_EXCHANGE_IN_FACET), IDiamond.FacetCutAction.Add, SINGLE_VAULT_DETF_EXCHANGE_IN_FACET.facetFuncs());
        facetCuts_[6] = IDiamond.FacetCut(address(SINGLE_VAULT_DETF_EXCHANGE_IN_QUERY_FACET), IDiamond.FacetCutAction.Add, SINGLE_VAULT_DETF_EXCHANGE_IN_QUERY_FACET.facetFuncs());
        facetCuts_[7] = IDiamond.FacetCut(address(SINGLE_VAULT_DETF_INFO_FACET), IDiamond.FacetCutAction.Add, SINGLE_VAULT_DETF_INFO_FACET.facetFuncs());
        facetCuts_[8] = IDiamond.FacetCut(address(SINGLE_VAULT_DETF_EXCHANGE_OUT_FACET), IDiamond.FacetCutAction.Add, SINGLE_VAULT_DETF_EXCHANGE_OUT_FACET.facetFuncs());
        facetCuts_[9] = IDiamond.FacetCut(address(SINGLE_VAULT_DETF_BONDING_FACET), IDiamond.FacetCutAction.Add, SINGLE_VAULT_DETF_BONDING_FACET.facetFuncs());
    }

    function diamondConfig() public view returns (DiamondConfig memory config_) {
        config_ = DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt_) {
        return abi.encode(pkgArgs)._hash();
    }

    function processArgs(bytes memory pkgArgs) public view returns (bytes memory processedPkgArgs_) {
        if (msg.sender != address(VAULT_REGISTRY_DEPLOYMENT)) {
            revert NotCalledByRegistry(msg.sender);
        }
        return pkgArgs;
    }

    function updatePkg(address, bytes memory) public pure returns (bool) {
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory args = abi.decode(initArgs, (PkgArgs));

        BalancerV3VaultAwareRepo._initialize(BALANCER_V3_VAULT);
        Permit2AwareRepo._initialize(PERMIT2);
        DetfSuperchainBridgeRepo._initialize(
            DetfSuperchainBridgeRepo.BridgeConfig({
                bridgeTokenRegistry: BRIDGE_TOKEN_REGISTRY,
                standardBridge: STANDARD_BRIDGE,
                messenger: BRIDGE_MESSENGER,
                localRelayer: LOCAL_RELAYER,
                peerRelayer: PEER_RELAYER
            })
        );
        ERC20Repo._initialize(
            bytes(args.name).length == 0 ? "Single Vault DETF CHIR" : args.name,
            bytes(args.symbol).length == 0 ? "CHIR" : args.symbol,
            18
        );
        EIP712Repo._initialize(ERC20Repo._name(), "1");

        SingleVaultDetfRepo._initialize(
            VAULT_FEE_ORACLE_QUERY,
            BALANCER_V3_PREPAY_ROUTER,
            args.richToken,
            WETH_TOKEN,
            1005e15,
            995e15
        );
        _deploymentConfigLayout().wethRichPoolKey = args.wethRichPoolKey;
        _deploymentConfigLayout().wethRichWidthMultiplier = args.wethRichWidthMultiplier;

        MultiStepOwnableRepo._initialize(address(this), 1 days);
    }

    function postDeploy(address expectedProxy) public returns (bool) {
        if (address(this) != expectedProxy) {
            IPostDeployAccountHook(expectedProxy).postDeploy();
            return true;
        }

        _postDeployProxyContext();
        return true;
    }

    function _postDeployProxyContext() internal {
        DeploymentConfig storage deployCfg = _deploymentConfigLayout();
        PkgArgs memory args;
        args.wethRichPoolKey = deployCfg.wethRichPoolKey;
        args.wethRichWidthMultiplier = deployCfg.wethRichWidthMultiplier;
        DerivedDeployment memory derived = _deployOwnedComposition(args);

        {
            address[] memory contents = new address[](3);
            contents[0] = address(this);
            contents[1] = address(derived.wethRichVault);
            contents[2] = derived.reservePool;
            MultiAssetBasicVaultRepo._initialize(contents);
            StandardVaultRepo._initialize(
                VAULT_FEE_ORACLE_QUERY,
                vaultFeeTypeIds(),
                vaultTypes(),
                abi.encode(contents._sort())._hash()
            );
        }

        SingleVaultDetfRepo._initializeDependencies(
            derived.wethRichVault,
            derived.vaultRateProvider,
            abi.encode(args.wethRichPoolKey)._hash()
        );
        SingleVaultDetfRepo._initializeReservePool(
            derived.reservePool,
            derived.detfIndex,
            derived.vaultTokenIndex,
            _EIGHTY,
            _TWENTY,
            derived.detfNFTVault,
            derived.detfNFTId
        );
        SingleVaultDetfRepo._setRichirToken(derived.richirToken);
    }

    function _deployOwnedComposition(PkgArgs memory args) internal returns (DerivedDeployment memory deployment_) {
        deployment_.wethRichVault = IStandardExchange(
            WETH_RICH_VAULT_PKG.deployVault(args.wethRichPoolKey, args.wethRichWidthMultiplier)
        );
        deployment_.vaultRateProvider = RATE_PROVIDER_PKG.deployRateProvider(
            deployment_.wethRichVault,
            WETH_TOKEN
        );
        deployment_.reservePool = _createReservePool(deployment_.wethRichVault, deployment_.vaultRateProvider);

        deployment_.detfNFTVault = IDETFNFTVault(
            PROTOCOL_NFT_VAULT_PKG.deployVault(
                string.concat("Protocol NFT Vault of ", ERC20Repo._name()),
                string.concat("pNFT-", ERC20Repo._symbol()),
                IProtocolDETF(address(this)),
                IERC20(deployment_.reservePool),
                IERC20(address(this)),
                9,
                address(this)
            )
        );
        deployment_.detfNFTId = deployment_.detfNFTVault.initializeDETFNFT();
        deployment_.richirToken = IRICHIR(
            RICHIR_PKG.deployToken(
                IProtocolDETF(address(this)),
                deployment_.detfNFTVault,
                WETH_TOKEN,
                deployment_.detfNFTId,
                address(this)
            )
        );
        (deployment_.detfIndex, deployment_.vaultTokenIndex) = address(this) < address(deployment_.wethRichVault)
            ? (0, 1)
            : (1, 0);
    }

    function _createReservePool(IStandardExchange wethRichVault_, IRateProvider vaultRateProvider_)
        internal
        returns (address reservePool_)
    {
        TokenConfig memory highWeightTokenConfig = TokenConfig({
            token: OZIERC20(address(this)),
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });

        TokenConfig memory lowWeightTokenConfig = TokenConfig({
            token: OZIERC20(address(wethRichVault_)),
            tokenType: TokenType.WITH_RATE,
            rateProvider: vaultRateProvider_,
            paysYieldFees: false
        });

        PoolRoleAccounts memory roleAccounts;
        roleAccounts.pauseManager = address(VAULT_FEE_ORACLE_QUERY.feeTo());
        roleAccounts.swapFeeManager = roleAccounts.pauseManager;
        roleAccounts.poolCreator = roleAccounts.pauseManager;

        uint256 swapFeePercentage =
            VAULT_FEE_ORACLE_QUERY.defaultDexSwapFeeOfTypeId(type(ISingleVaultDetfBonding).interfaceId);
        if (swapFeePercentage == 0) {
            swapFeePercentage = VAULT_FEE_ORACLE_QUERY.defaultDexSwapFee();
        }
        if (swapFeePercentage == 0) {
            swapFeePercentage = DEFAULT_DEX_FEE;
        }

        reservePool_ = WEIGHTED_POOL_8020_FACTORY.create(
            highWeightTokenConfig,
            lowWeightTokenConfig,
            roleAccounts,
            swapFeePercentage
        );
    }

    function deployVault(
        string memory name_,
        string memory symbol_,
        IERC20 richToken_,
        PoolKey memory wethRichPoolKey_,
        uint24 wethRichWidthMultiplier_
    ) external returns (address vault_) {
        vault_ = VAULT_REGISTRY_DEPLOYMENT.deployVault(
            ISingleVaultDetfDFPkg(address(this)),
            abi.encode(
                PkgArgs({
                    name: name_,
                    symbol: symbol_,
                    richToken: richToken_,
                    richInitialDepositAmount: 0,
                    wethInitialDepositAmount: 0,
                    wethRichPoolKey: wethRichPoolKey_,
                    wethRichWidthMultiplier: wethRichWidthMultiplier_
                })
            )
        );
    }
}