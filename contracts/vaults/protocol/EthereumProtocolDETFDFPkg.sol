// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IERC20 as OZIERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IRouter} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRouter.sol";
import {IVault as IBalancerVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IWeightedPool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {
    PoolRoleAccounts,
    TokenConfig,
    TokenType
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {ICrossDomainMessenger} from "@crane/contracts/interfaces/protocols/l2s/superchain/ICrossDomainMessenger.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IStandardBridge} from "@crane/contracts/interfaces/protocols/l2s/superchain/IStandardBridge.sol";
import {ISuperChainBridgeTokenRegistry} from "@crane/contracts/interfaces/ISuperChainBridgeTokenRegistry.sol";
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
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import "contracts/constants/Indexedex_CONSTANTS.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {IRICHIR} from "contracts/interfaces/IRICHIR.sol";
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
import {IBaseProtocolDETFBonding} from "contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol";
import {BaseProtocolDETFRepo} from "contracts/vaults/protocol/BaseProtocolDETFRepo.sol";
import {ProtocolDETFSuperchainBridgeRepo} from "contracts/vaults/protocol/ProtocolDETFSuperchainBridgeRepo.sol";
import {IProtocolNFTVaultDFPkg} from "contracts/vaults/protocol/ProtocolNFTVaultDFPkg.sol";
import {IRICHIRDFPkg} from "contracts/vaults/protocol/RICHIRDFPkg.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {
    IStandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/StandardExchangeRateProviderDFPkg.sol";
import {
    IUniswapV2StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol";

/**
 * @title IEthereumProtocolDETFDFPkg
 * @notice Interface for Ethereum Protocol DETF Diamond Factory Package.
 * @dev Uses Uniswap V2 for exchange vaults instead of Aerodrome (Base).
 */
interface IEthereumProtocolDETFDFPkg is IDiamondFactoryPackage {
    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;

        IFacet erc4626BasicVaultFacet;
        IFacet erc4626StandardVaultFacet;

        IFacet protocolDETFExchangeInFacet;
        IFacet protocolDETFExchangeInQueryFacet;
        IFacet protocolDETFExchangeOutFacet;
        IFacet protocolDETFBondingFacet;
        IFacet protocolDETFBridgeFacet;
        IFacet protocolDETFBondingQueryFacet;

        IVaultFeeOracleQuery feeOracle;
        IVaultRegistryDeployment vaultRegistryDeployment;

        IPermit2 permit2;

        IBalancerVault balancerV3Vault;
        IRouter balancerV3Router;
        IBalancerV3StandardExchangeRouterPrepay balancerV3PrepayRouter;

        /// @notice Balancer V3 factory used to create the canonical 80/20 reserve pool.
        IWeightedPool8020Factory weightedPool8020Factory;

        IDiamondPackageCallBackFactory diamondFactory;

        /// @notice Package used to deploy the RICH token during DETF init.
        IUniswapV2StandardExchangeDFPkg uniswapV2StandardExchangeDFPkg;
        /// @notice Package used to deploy the Protocol NFT Vault during DETF init.
        IProtocolNFTVaultDFPkg protocolNFTVaultPkg;
        /// @notice Package used to deploy the RICHIR rebasing token during DETF init.
        IRICHIRDFPkg richirPkg;

        /// @notice Package used to deploy a StandardExchange-backed Balancer rate provider.
        IStandardExchangeRateProviderDFPkg rateProviderPkg;

        ProtocolDETFSuperchainBridgeRepo.BridgeConfig bridgeConfig;
    }

    struct PkgArgs {
        string name;
        string symbol;
        BaseProtocolDETFRepo.ProtocolConfig protocolConfig;

        /// @notice Address to pull initial deposit funds from (Permit2 owner)
        address funder;
    }

    error NotCalledByRegistry(address caller);
}

/**
 * @title EthereumProtocolDETFDFPkg
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Diamond Factory Package for deploying Ethereum Protocol DETF (CHIR) vaults.
 * @dev Uses Uniswap V2 Standard Exchange for DEX integration (vs Aerodrome on Base).
 */
contract EthereumProtocolDETFDFPkg is IEthereumProtocolDETFDFPkg, IStandardVaultPkg {
    using BetterEfficientHashLib for bytes;
    using BetterSafeERC20 for IERC20;
    using BetterSafeERC20 for IERC20Metadata;
    using BaseProtocolDETFRepo for BaseProtocolDETFRepo.Storage;

    uint256 private constant _EIGHTY = 80e16; // 80%
    uint256 private constant _TWENTY = 20e16; // 20%
    uint256 private constant _MIN_BALANCER_SWAP_FEE_PERCENTAGE = 1e13;

    address immutable SELF;

    IFacet immutable ERC20_FACET;
    IFacet immutable ERC5267_FACET;
    IFacet immutable ERC2612_FACET;

    IFacet immutable ERC4626_BASIC_VAULT_FACET;
    IFacet immutable ERC4626_STANDARD_VAULT_FACET;

    IFacet immutable PROTOCOL_DETF_EXCHANGE_IN_FACET;
    IFacet immutable PROTOCOL_DETF_EXCHANGE_IN_QUERY_FACET;
    IFacet immutable PROTOCOL_DETF_EXCHANGE_OUT_FACET;
    IFacet immutable PROTOCOL_DETF_BONDING_FACET;
    IFacet immutable PROTOCOL_DETF_BRIDGE_FACET;
    IFacet immutable PROTOCOL_DETF_BONDING_QUERY_FACET;

    IVaultFeeOracleQuery immutable VAULT_FEE_ORACLE_QUERY;
    IVaultRegistryDeployment immutable VAULT_REGISTRY_DEPLOYMENT;

    IPermit2 immutable PERMIT2;

    IBalancerVault immutable BALANCER_V3_VAULT;
    IRouter immutable BALANCER_V3_ROUTER;
    IBalancerV3StandardExchangeRouterPrepay immutable BALANCER_V3_PREPAY_ROUTER;

    IWeightedPool8020Factory immutable WEIGHTED_POOL_8020_FACTORY;

    IDiamondPackageCallBackFactory immutable DIAMOND_FACTORY;

    IUniswapV2StandardExchangeDFPkg immutable UNISWAP_V2_STANDARD_EXCHANGE_DFPKG;
    IProtocolNFTVaultDFPkg immutable PROTOCOL_NFT_VAULT_PKG;
    IRICHIRDFPkg immutable RICHIR_PKG;
    IStandardExchangeRateProviderDFPkg immutable RATE_PROVIDER_PKG;

    ISuperChainBridgeTokenRegistry immutable BRIDGE_TOKEN_REGISTRY;
    IStandardBridge immutable BRIDGE_STANDARD_BRIDGE;
    ICrossDomainMessenger immutable BRIDGE_MESSENGER;
    address immutable BRIDGE_LOCAL_RELAYER;
    address immutable BRIDGE_PEER_RELAYER;

    constructor(PkgInit memory pkgInit) {
        SELF = address(this);
        ERC20_FACET = pkgInit.erc20Facet;
        ERC5267_FACET = pkgInit.erc5267Facet;
        ERC2612_FACET = pkgInit.erc2612Facet;

        ERC4626_BASIC_VAULT_FACET = pkgInit.erc4626BasicVaultFacet;
        ERC4626_STANDARD_VAULT_FACET = pkgInit.erc4626StandardVaultFacet;

        PROTOCOL_DETF_EXCHANGE_IN_FACET = pkgInit.protocolDETFExchangeInFacet;
        PROTOCOL_DETF_EXCHANGE_IN_QUERY_FACET = pkgInit.protocolDETFExchangeInQueryFacet;
        PROTOCOL_DETF_EXCHANGE_OUT_FACET = pkgInit.protocolDETFExchangeOutFacet;
        PROTOCOL_DETF_BONDING_FACET = pkgInit.protocolDETFBondingFacet;
        PROTOCOL_DETF_BRIDGE_FACET = pkgInit.protocolDETFBridgeFacet;
        PROTOCOL_DETF_BONDING_QUERY_FACET = pkgInit.protocolDETFBondingQueryFacet;

        VAULT_FEE_ORACLE_QUERY = pkgInit.feeOracle;
        VAULT_REGISTRY_DEPLOYMENT = pkgInit.vaultRegistryDeployment;
        PERMIT2 = pkgInit.permit2;
        BALANCER_V3_VAULT = pkgInit.balancerV3Vault;
        BALANCER_V3_ROUTER = pkgInit.balancerV3Router;
        BALANCER_V3_PREPAY_ROUTER = pkgInit.balancerV3PrepayRouter;

        WEIGHTED_POOL_8020_FACTORY = pkgInit.weightedPool8020Factory;

        DIAMOND_FACTORY = pkgInit.diamondFactory;
        UNISWAP_V2_STANDARD_EXCHANGE_DFPKG = pkgInit.uniswapV2StandardExchangeDFPkg;
        PROTOCOL_NFT_VAULT_PKG = pkgInit.protocolNFTVaultPkg;
        RICHIR_PKG = pkgInit.richirPkg;
        RATE_PROVIDER_PKG = pkgInit.rateProviderPkg;
        BRIDGE_TOKEN_REGISTRY = pkgInit.bridgeConfig.bridgeTokenRegistry;
        BRIDGE_STANDARD_BRIDGE = pkgInit.bridgeConfig.standardBridge;
        BRIDGE_MESSENGER = pkgInit.bridgeConfig.messenger;
        BRIDGE_LOCAL_RELAYER = pkgInit.bridgeConfig.localRelayer;
        BRIDGE_PEER_RELAYER = pkgInit.bridgeConfig.peerRelayer;
    }

    /* ---------------------------------------------------------------------- */
    /*                              IStandardVaultPkg                          */
    /* ---------------------------------------------------------------------- */

    function name() public pure returns (string memory) {
        return packageName();
    }

    function vaultFeeTypeIds() public pure returns (bytes32 vaultFeeTypeIds_) {
        vaultFeeTypeIds_ =
            VaultTypeUtils._insertFeeTypeId(vaultFeeTypeIds_, VaultFeeType.USAGE, type(IProtocolDETF).interfaceId);
        vaultFeeTypeIds_ =
            VaultTypeUtils._insertFeeTypeId(vaultFeeTypeIds_, VaultFeeType.BOND, type(IProtocolDETF).interfaceId);
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
        return type(EthereumProtocolDETFDFPkg).name;
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](11);
        facetAddresses_[0] = address(ERC20_FACET);
        facetAddresses_[1] = address(ERC5267_FACET);
        facetAddresses_[2] = address(ERC2612_FACET);
        facetAddresses_[3] = address(ERC4626_BASIC_VAULT_FACET);
        facetAddresses_[4] = address(ERC4626_STANDARD_VAULT_FACET);
        facetAddresses_[5] = address(PROTOCOL_DETF_EXCHANGE_IN_FACET);
        facetAddresses_[6] = address(PROTOCOL_DETF_EXCHANGE_IN_QUERY_FACET);
        facetAddresses_[7] = address(PROTOCOL_DETF_EXCHANGE_OUT_FACET);
        facetAddresses_[8] = address(PROTOCOL_DETF_BONDING_FACET);
        facetAddresses_[9] = address(PROTOCOL_DETF_BRIDGE_FACET);
        facetAddresses_[10] = address(PROTOCOL_DETF_BONDING_QUERY_FACET);
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](11);
        interfaces[0] = type(IERC20).interfaceId;
        interfaces[1] = type(IERC20Metadata).interfaceId;
        interfaces[2] = type(IERC20Metadata).interfaceId ^ type(IERC20).interfaceId;
        interfaces[3] = type(IERC20Permit).interfaceId;
        interfaces[4] = type(IERC5267).interfaceId;
        interfaces[5] = type(IProtocolDETF).interfaceId;
        interfaces[6] = type(IStandardExchangeIn).interfaceId;
        interfaces[7] = type(IStandardExchangeOut).interfaceId;
        interfaces[8] = type(IBaseProtocolDETFBonding).interfaceId;
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
        facetCuts_ = new IDiamond.FacetCut[](11);

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
            facetAddress: address(PROTOCOL_DETF_EXCHANGE_IN_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: PROTOCOL_DETF_EXCHANGE_IN_FACET.facetFuncs()
        });
        facetCuts_[6] = IDiamond.FacetCut({
            facetAddress: address(PROTOCOL_DETF_EXCHANGE_IN_QUERY_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: PROTOCOL_DETF_EXCHANGE_IN_QUERY_FACET.facetFuncs()
        });
        facetCuts_[7] = IDiamond.FacetCut({
            facetAddress: address(PROTOCOL_DETF_EXCHANGE_OUT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: PROTOCOL_DETF_EXCHANGE_OUT_FACET.facetFuncs()
        });
        facetCuts_[8] = IDiamond.FacetCut({
            facetAddress: address(PROTOCOL_DETF_BONDING_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: PROTOCOL_DETF_BONDING_FACET.facetFuncs()
        });
        facetCuts_[9] = IDiamond.FacetCut({
            facetAddress: address(PROTOCOL_DETF_BRIDGE_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: PROTOCOL_DETF_BRIDGE_FACET.facetFuncs()
        });
        facetCuts_[10] = IDiamond.FacetCut({
            facetAddress: address(PROTOCOL_DETF_BONDING_QUERY_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: PROTOCOL_DETF_BONDING_QUERY_FACET.facetFuncs()
        });
    }

    function diamondConfig() public view returns (DiamondConfig memory config) {
        config = IDiamondFactoryPackage.DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt) {
        return abi.encode(pkgArgs)._hash();
    }

    function processArgs(bytes memory pkgArgs) public view virtual returns (bytes memory processedPkgArgs) {
        if (msg.sender != address(VAULT_REGISTRY_DEPLOYMENT)) {
            revert NotCalledByRegistry(msg.sender);
        }
        return pkgArgs;
    }

    function updatePkg(address expectedProxy, bytes memory pkgArgs) public virtual returns (bool) {
        PkgArgs memory args = abi.decode(pkgArgs, (PkgArgs));

        if (args.funder == address(0)) {
            revert("EthereumProtocolDETFDFPkg: no funder");
        }

        // Pull initial WETH/RICH into the package using Permit2 (spender = this package).
        // User must have:
        // 1) ERC20 approval to Permit2, and
        // 2) Permit2 allowance to this package.
        if (args.protocolConfig.wethInitialDepositAmount > 0) {
            PERMIT2.transferFrom(
                args.funder,
                address(this),
                uint160(args.protocolConfig.wethInitialDepositAmount),
                args.protocolConfig.wethToken
            );
            // Permit2 will later transfer funds from the package to the proxy.
            // This requires the package to approve Permit2 as an ERC20 spender.
            IERC20(args.protocolConfig.wethToken).safeApprove(address(PERMIT2), 0);
            IERC20(args.protocolConfig.wethToken)
                .safeApprove(address(PERMIT2), args.protocolConfig.wethInitialDepositAmount);
            PERMIT2.approve(
                args.protocolConfig.wethToken,
                expectedProxy,
                uint160(args.protocolConfig.wethInitialDepositAmount),
                type(uint48).max
            );
        }

        if (args.protocolConfig.richInitialDepositAmount > 0) {
            PERMIT2.transferFrom(
                args.funder,
                address(this),
                uint160(args.protocolConfig.richInitialDepositAmount),
                args.protocolConfig.richToken
            );
            IERC20(args.protocolConfig.richToken).safeApprove(address(PERMIT2), 0);
            IERC20(args.protocolConfig.richToken)
                .safeApprove(address(PERMIT2), args.protocolConfig.richInitialDepositAmount);
            PERMIT2.approve(
                args.protocolConfig.richToken,
                expectedProxy,
                uint160(args.protocolConfig.richInitialDepositAmount),
                type(uint48).max
            );
        }

        return true;
    }

    function initAccount(bytes memory initArgs) public {
        BalancerV3VaultAwareRepo._initialize(BALANCER_V3_VAULT);
        Permit2AwareRepo._initialize(PERMIT2);

        PkgArgs memory args = abi.decode(initArgs, (PkgArgs));

        if (bytes(args.name).length == 0) {
            args.name = "Protocol DETF CHIR";
        }

        if (bytes(args.symbol).length == 0) {
            args.symbol = "CHIR";
        }

        ERC20Repo._initialize(args.name, args.symbol, 18);

        EIP712Repo._initialize(args.name, "1");

        // Initialize Protocol DETF repo with default deadband thresholds.
        // mintThreshold = 1.005e18 (upper deadband bound)
        // burnThreshold = 0.995e18 (lower deadband bound)
        BaseProtocolDETFRepo._initialize(
            VAULT_FEE_ORACLE_QUERY,
            BALANCER_V3_PREPAY_ROUTER,
            args.protocolConfig,
            1005e15, // mintThreshold = 1.005e18
            995e15 // burnThreshold = 0.995e18
        );

        ProtocolDETFSuperchainBridgeRepo._initialize(
            ProtocolDETFSuperchainBridgeRepo.BridgeConfig({
                bridgeTokenRegistry: BRIDGE_TOKEN_REGISTRY,
                standardBridge: BRIDGE_STANDARD_BRIDGE,
                messenger: BRIDGE_MESSENGER,
                localRelayer: BRIDGE_LOCAL_RELAYER,
                peerRelayer: BRIDGE_PEER_RELAYER
            })
        );
    }

    function postDeploy(address expectedProxy) public returns (bool) {
        // Detect if we're inside the proxy yet.
        if (address(this) != expectedProxy) {
            // We're not in the proxy yet, so call the proxy to DELEGATECALL to this function.
            IPostDeployAccountHook(expectedProxy).postDeploy();
            // Prevent running postDeploy logic against the package contract's storage.
            return true;
        }

        _postDeployProxyContext(expectedProxy);
        return true;
    }

    function _postDeployProxyContext(address expectedProxy) internal {
        BaseProtocolDETFRepo.Storage storage detfStorage = BaseProtocolDETFRepo._layout();
        BaseProtocolDETFRepo.ProtocolConfig memory cfg = BaseProtocolDETFRepo._protocolConfig(detfStorage);

        _fundProxyAndDeployExchangeVaults(detfStorage, expectedProxy, cfg);
        _deployReservePoolAndFinalize(detfStorage);
    }

    function _fundProxyAndDeployExchangeVaults(
        BaseProtocolDETFRepo.Storage storage detfStorage,
        address expectedProxy,
        BaseProtocolDETFRepo.ProtocolConfig memory cfg
    ) internal {
        // Pull initial deposit funds from the package into the proxy using Permit2 (spender = this proxy).
        // Allowance was prepared in updatePkg().
        if (cfg.wethInitialDepositAmount > 0) {
            PERMIT2.transferFrom(SELF, address(this), uint160(cfg.wethInitialDepositAmount), cfg.wethToken);
        }
        if (cfg.richInitialDepositAmount > 0) {
            PERMIT2.transferFrom(SELF, address(this), uint160(cfg.richInitialDepositAmount), cfg.richToken);
        }

        // Deploy CHIR/WETH and RICH/CHIR Standard Exchange vaults.
        uint256 chirForWeth = cfg.wethInitialDepositAmount * cfg.wethMintChirPercent / ONE_WAD;
        uint256 chirForRich = cfg.richInitialDepositAmount * cfg.richMintChirPercent / ONE_WAD;

        if (chirForWeth > 0) {
            ERC20Repo._mint(address(this), chirForWeth);
        }
        if (chirForRich > 0) {
            ERC20Repo._mint(address(this), chirForRich);
        }

        // Approve Uniswap V2 DFPkg to move underlying tokens + CHIR out of this proxy.
        if (cfg.wethInitialDepositAmount > 0) {
            IERC20(cfg.wethToken).safeApprove(address(UNISWAP_V2_STANDARD_EXCHANGE_DFPKG), 0);
            IERC20(cfg.wethToken).safeApprove(address(UNISWAP_V2_STANDARD_EXCHANGE_DFPKG), cfg.wethInitialDepositAmount);
        }
        if (cfg.richInitialDepositAmount > 0) {
            IERC20(cfg.richToken).safeApprove(address(UNISWAP_V2_STANDARD_EXCHANGE_DFPKG), 0);
            IERC20(cfg.richToken).safeApprove(address(UNISWAP_V2_STANDARD_EXCHANGE_DFPKG), cfg.richInitialDepositAmount);
        }
        if (chirForWeth + chirForRich > 0) {
            ERC20Repo._approve(address(this), address(UNISWAP_V2_STANDARD_EXCHANGE_DFPKG), chirForWeth + chirForRich);
        }

        address chirWethVaultAddr = UNISWAP_V2_STANDARD_EXCHANGE_DFPKG.deployVault(
            IERC20(cfg.wethToken), cfg.wethInitialDepositAmount, IERC20(address(this)), chirForWeth, expectedProxy
        );

        address richChirVaultAddr = UNISWAP_V2_STANDARD_EXCHANGE_DFPKG.deployVault(
            IERC20(cfg.richToken), cfg.richInitialDepositAmount, IERC20(address(this)), chirForRich, expectedProxy
        );

        BaseProtocolDETFRepo._initializeExchangeVaults(
            detfStorage,
            IStandardExchange(chirWethVaultAddr),
            IStandardExchange(richChirVaultAddr),
            IERC20(cfg.wethToken),
            IERC20(cfg.richToken)
        );
    }

    function _deployReservePoolAndFinalize(BaseProtocolDETFRepo.Storage storage detfStorage) internal {
        address reservePool;
        address nftVault;
        address richir;
        uint256 protocolNFTId;

        {
            // Create the 80/20 reserve pool from the two Standard Exchange vault tokens.
            IRateProvider chirWethRateProvider = RATE_PROVIDER_PKG.deployRateProvider(
                BaseProtocolDETFRepo._chirWethVault(detfStorage), BaseProtocolDETFRepo._chirWethRateTarget(detfStorage)
            );

            IRateProvider richChirRateProvider = RATE_PROVIDER_PKG.deployRateProvider(
                BaseProtocolDETFRepo._richChirVault(detfStorage), BaseProtocolDETFRepo._richChirRateTarget(detfStorage)
            );

            TokenConfig memory highWeightTokenConfig = TokenConfig({
                token: OZIERC20(address(BaseProtocolDETFRepo._chirWethVault(detfStorage))),
                tokenType: TokenType.WITH_RATE,
                rateProvider: chirWethRateProvider,
                paysYieldFees: false
            });

            TokenConfig memory lowWeightTokenConfig = TokenConfig({
                token: OZIERC20(address(BaseProtocolDETFRepo._richChirVault(detfStorage))),
                tokenType: TokenType.WITH_RATE,
                rateProvider: richChirRateProvider,
                paysYieldFees: false
            });

            PoolRoleAccounts memory roleAccounts;
            roleAccounts.pauseManager = address(VAULT_FEE_ORACLE_QUERY.feeTo());
            roleAccounts.swapFeeManager = roleAccounts.pauseManager;
            roleAccounts.poolCreator = roleAccounts.pauseManager;

            uint256 swapFeePercentage =
                VAULT_FEE_ORACLE_QUERY.defaultDexSwapFeeOfTypeId(type(IBaseProtocolDETFBonding).interfaceId);
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

        // Seed the reserve pool with initial liquidity from the vault shares
        // created in _fundProxyAndDeployExchangeVaults()
        _initializeReservePoolLiquidity(detfStorage, reservePool);

        ERC4626Repo._initialize(IERC20(reservePool), 18, 9);

        {
            nftVault = PROTOCOL_NFT_VAULT_PKG.deployVault(
                string.concat("Protocol NFT Vault of ", ERC20Repo._name()),
                string.concat("pNFT-", ERC20Repo._symbol()),
                IProtocolDETF(address(this)),
                IERC20(reservePool),
                IERC20(address(this)),
                9,
                address(this)
            );

            protocolNFTId = IProtocolNFTVault(nftVault).initializeProtocolNFT();

            richir = RICHIR_PKG.deployToken(
                IProtocolDETF(address(this)),
                IProtocolNFTVault(nftVault),
                detfStorage.wethToken,
                protocolNFTId,
                address(this)
            );
        }

        {
            (uint256 chirWethVaultIndex_, uint256 richChirVaultIndex_) =
                address(detfStorage.chirWethVault) < address(detfStorage.richChirVault) ? (0, 1) : (1, 0);

            BaseProtocolDETFRepo._initializeReservePool(
                detfStorage,
                chirWethVaultIndex_,
                _EIGHTY,
                richChirVaultIndex_,
                _TWENTY,
                IProtocolNFTVault(nftVault),
                IRICHIR(richir),
                protocolNFTId
            );
        }
    }

    /**
     * @notice Initialize the reserve pool with vault shares held by this contract.
     * @dev The vault shares were minted to this contract (CHIR proxy) during
     *      _fundProxyAndDeployExchangeVaults(). This function seeds the Balancer
     *      80/20 pool with those shares so bonding operations can succeed.
     */
    function _initializeReservePoolLiquidity(BaseProtocolDETFRepo.Storage storage detfStorage, address reservePool)
        internal
    {
        // Get vault token addresses (the ERC20 tokens that represent shares)
        address chirWethVault = address(detfStorage.chirWethVault);
        address richChirVault = address(detfStorage.richChirVault);

        // Get the vault share balances held by this contract
        uint256 chirWethShares = IERC20(chirWethVault).balanceOf(address(this));
        uint256 richChirShares = IERC20(richChirVault).balanceOf(address(this));

        // Skip initialization if EITHER vault has no shares (pool requires both tokens)
        if (chirWethShares == 0 || richChirShares == 0) {
            return;
        }

        // Build token arrays in sorted order (Balancer requires tokens sorted by address)
        OZIERC20[] memory tokens;
        uint256[] memory exactAmountsIn;

        if (chirWethVault < richChirVault) {
            tokens = new OZIERC20[](2);
            tokens[0] = OZIERC20(chirWethVault);
            tokens[1] = OZIERC20(richChirVault);

            exactAmountsIn = new uint256[](2);
            exactAmountsIn[0] = chirWethShares;
            exactAmountsIn[1] = richChirShares;
        } else {
            tokens = new OZIERC20[](2);
            tokens[0] = OZIERC20(richChirVault);
            tokens[1] = OZIERC20(chirWethVault);

            exactAmountsIn = new uint256[](2);
            exactAmountsIn[0] = richChirShares;
            exactAmountsIn[1] = chirWethShares;
        }

        // Approve Permit2 to move vault tokens from this contract
        if (chirWethShares > 0) {
            IERC20(chirWethVault).safeApprove(address(PERMIT2), 0);
            IERC20(chirWethVault).safeApprove(address(PERMIT2), chirWethShares);
            // Grant Permit2 allowance to Balancer Router
            PERMIT2.approve(chirWethVault, address(BALANCER_V3_ROUTER), uint160(chirWethShares), type(uint48).max);
        }
        if (richChirShares > 0) {
            IERC20(richChirVault).safeApprove(address(PERMIT2), 0);
            IERC20(richChirVault).safeApprove(address(PERMIT2), richChirShares);
            // Grant Permit2 allowance to Balancer Router
            PERMIT2.approve(richChirVault, address(BALANCER_V3_ROUTER), uint160(richChirShares), type(uint48).max);
        }

        // Initialize the Balancer pool with the vault shares
        // BPT tokens are minted to this contract (CHIR proxy)
        BALANCER_V3_ROUTER.initialize(
            reservePool,
            tokens,
            exactAmountsIn,
            0, // minBptAmountOut - accept any amount on initialization
            false, // wethIsEth - vault tokens are not WETH
            bytes("") // userData - no additional data needed
        );
    }
}
