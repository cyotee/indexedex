// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { betterconsole as console } from "@crane/contracts/utils/vm/foundry/tools/betterconsole.sol";

import {DeploymentBase as AnvilDeploymentBase} from "../../anvil_sepolia/DeploymentBase.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ETHEREUM_SEPOLIA} from "@crane/contracts/constants/networks/ETHEREUM_SEPOLIA.sol";
import {BASE_SEPOLIA} from "@crane/contracts/constants/networks/BASE_SEPOLIA.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {ICrossDomainMessenger} from "@crane/contracts/interfaces/protocols/l2s/superchain/ICrossDomainMessenger.sol";
import {IStandardBridge} from "@crane/contracts/interfaces/protocols/l2s/superchain/IStandardBridge.sol";
import {ISuperChainBridgeTokenRegistry} from "@crane/contracts/interfaces/ISuperChainBridgeTokenRegistry.sol";

import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {IERC20MinterFacade} from "@crane/contracts/tokens/ERC20/IERC20MinterFacade.sol";
import {IWeightedPool8020Factory} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool8020Factory.sol";

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IRouter} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRouter.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IBalancerV3StandardExchangeRouterProxy} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {IBalancerV3StandardExchangeRouterPrepay} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";

import {
	IStandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/StandardExchangeRateProviderDFPkg.sol";
import {IUniswapV2StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol";

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";

import {BaseProtocolDETFRepo} from "contracts/vaults/protocol/BaseProtocolDETFRepo.sol";
import {BaseProtocolDETF_Component_FactoryService} from "contracts/vaults/protocol/BaseProtocolDETF_Component_FactoryService.sol";
import {BaseProtocolDETF_Facet_FactoryService} from "contracts/vaults/protocol/BaseProtocolDETF_Facet_FactoryService.sol";
import {BaseProtocolDETF_Pkg_FactoryService} from "contracts/vaults/protocol/BaseProtocolDETF_Pkg_FactoryService.sol";
import {EthereumProtocolDETF_Component_FactoryService} from "contracts/vaults/protocol/EthereumProtocolDETF_Component_FactoryService.sol";
import {EthereumProtocolDETF_Facet_FactoryService} from "contracts/vaults/protocol/EthereumProtocolDETF_Facet_FactoryService.sol";
import {EthereumProtocolDETF_Pkg_FactoryService} from "contracts/vaults/protocol/EthereumProtocolDETF_Pkg_FactoryService.sol";
import {IEthereumProtocolDETFDFPkg} from "contracts/vaults/protocol/EthereumProtocolDETFDFPkg.sol";
import {IProtocolNFTVaultDFPkg} from "contracts/vaults/protocol/ProtocolNFTVaultDFPkg.sol";
import {IRICHIRDFPkg} from "contracts/vaults/protocol/RICHIRDFPkg.sol";
import {ProtocolDETFSuperchainBridgeRepo} from "contracts/vaults/protocol/ProtocolDETFSuperchainBridgeRepo.sol";

/// @title Script_16_DeployProtocolDETF (Public Sepolia - DemoWETH)
/// @notice Deploys the Protocol DETF (CHIR) using DemoWETH as the DETF base asset on public Sepolia.
contract Script_16_DeployProtocolDETF is AnvilDeploymentBase {
	/* ---------------------------------------------------------------------- */
	/*                                 Constants                               */
	/* ---------------------------------------------------------------------- */

	// Initial liquidity used by the Protocol DETF package during deployment.
	uint256 private constant INITIAL_DEMO_WETH_DEPOSIT = 10e18;
	uint256 private constant INITIAL_RICH_DEPOSIT = 10e18;

	uint256 private constant ONE_WAD = 1e18;

	/* ---------------------------------------------------------------------- */
	/*                                 Inputs                                  */
	/* ---------------------------------------------------------------------- */

	ICreate3FactoryProxy private create3Factory;
	IDiamondPackageCallBackFactory private diamondPackageFactory;
	IVaultRegistryDeployment private vaultRegistry;
	IVaultFeeOracleQuery private feeOracle;

	// Shared facets
	IFacet private erc20Facet;
	IFacet private erc2612Facet;
	IFacet private erc5267Facet;
	IFacet private erc4626BasicVaultFacet;
	IFacet private erc4626StandardVaultFacet;

	// Stage 04 outputs
	IBalancerV3StandardExchangeRouterProxy private balancerV3StandardExchangeRouter;
	IUniswapV2StandardExchangeDFPkg private uniswapV2Pkg;
	IStandardExchangeRateProviderDFPkg private rateProviderPkg;

	// Stage 15 output (re-used)
	IWeightedPool8020Factory private weightedPool8020Factory;
	IERC20MinterFacade private erc20MinterFacade;

	/* ---------------------------------------------------------------------- */
	/*                            Deployed infra                               */
	/* ---------------------------------------------------------------------- */

	IFacet private protocolExchangeInFacet;
	IFacet private protocolExchangeInQueryFacet;
	IFacet private protocolExchangeOutFacet;
	IFacet private protocolBondingFacet;
	IFacet private protocolBridgeFacet;
	IFacet private protocolBondingQueryFacet;
	IFacet private protocolNFTVaultFacet;
	IFacet private richirFacet;

	IFacet private erc721Facet;

	IProtocolNFTVaultDFPkg private protocolNFTVaultPkg;
	IRICHIRDFPkg private richirPkg;
	IEthereumProtocolDETFDFPkg private protocolDetfPkg;

	/* ---------------------------------------------------------------------- */
	/*                              Deployed addresses                          */
	/* ---------------------------------------------------------------------- */

	address private demoWeth;
	address private richToken;
	address private protocolDetf;

	address private protocolNftVault;
	address private richirToken;
	address private reservePool;
	address private chirWethVault;
	address private richChirVault;

	function run() external virtual {
		_runProtocolDetfStage16();
	}

	function _runProtocolDetfStage16() internal {
		console.log("[Stage 16][ETH] Checkpoint: begin run()");
		console.log("[Stage 16][ETH] Checkpoint: calling _setup()");
		_setup();
		console.log("[Stage 16][ETH] Checkpoint: _setup() complete");
		console.log("[Stage 16][ETH] Checkpoint: calling _loadPreviousDeployments()");
		_loadPreviousDeployments();
		console.log("[Stage 16][ETH] Checkpoint: _loadPreviousDeployments() complete");
		console.log("[Stage 16][ETH] create3Factory", address(create3Factory));
		console.log("[Stage 16][ETH] diamondPackageFactory", address(diamondPackageFactory));
		console.log("[Stage 16][ETH] vaultRegistry", address(vaultRegistry));
		console.log("[Stage 16][ETH] feeOracle", address(feeOracle));
		console.log("[Stage 16][ETH] balancerV3StandardExchangeRouter", address(balancerV3StandardExchangeRouter));
		console.log("[Stage 16][ETH] uniswapV2Pkg", address(uniswapV2Pkg));
		console.log("[Stage 16][ETH] rateProviderPkg", address(rateProviderPkg));
		console.log("[Stage 16][ETH] weightedPool8020Factory", address(weightedPool8020Factory));

		_logHeader("Stage 16: Deploy Protocol DETF (CHIR) - Public Sepolia");
		console.log("[Stage 16][ETH] Checkpoint: starting broadcast");

		vm.startBroadcast();

		console.log("[Stage 16][ETH] Checkpoint: deploying facets");
		_deployFacets();
		console.log("[Stage 16][ETH] Checkpoint: facets deployed");
		console.log("[Stage 16][ETH] Checkpoint: deploying packages");
		_deployPkgs();
		console.log("[Stage 16][ETH] Checkpoint: packages deployed");
		console.log("[Stage 16][ETH] Checkpoint: approving initial funding");
		_approveInitialFunding();
		console.log("[Stage 16][ETH] Checkpoint: initial funding approved");
		console.log("[Stage 16][ETH] Checkpoint: deploying Protocol DETF");
		_deployProtocolDetf();
		console.log("[Stage 16][ETH] Checkpoint: Protocol DETF deployed");

		vm.stopBroadcast();
		console.log("[Stage 16][ETH] Checkpoint: broadcast stopped");

		_exportJson();
		console.log("[Stage 16][ETH] Checkpoint: json exported");
		_logResults();
	}

	function _loadPreviousDeployments() internal {
		create3Factory = ICreate3FactoryProxy(_readAddress("01_factories.json", "create3Factory"));
		diamondPackageFactory = IDiamondPackageCallBackFactory(_readAddress("01_factories.json", "diamondPackageFactory"));

		vaultRegistry = IVaultRegistryDeployment(_readAddress("03_core_proxies.json", "vaultRegistry"));
		feeOracle = IVaultFeeOracleQuery(_readAddress("03_core_proxies.json", "vaultFeeOracle"));

		erc20Facet = IFacet(_readAddress("02_shared_facets.json", "erc20Facet"));
		erc2612Facet = IFacet(_readAddress("02_shared_facets.json", "erc2612Facet"));
		erc5267Facet = IFacet(_readAddress("02_shared_facets.json", "erc5267Facet"));
		erc4626BasicVaultFacet = IFacet(_readAddress("02_shared_facets.json", "erc4626BasicVaultFacet"));
		erc4626StandardVaultFacet = IFacet(_readAddress("02_shared_facets.json", "erc4626StandardVaultFacet"));

		balancerV3StandardExchangeRouter = IBalancerV3StandardExchangeRouterProxy(
			_readAddress("04_balancer_v3.json", "balancerV3StandardExchangeRouter")
		);
		
		uniswapV2Pkg = IUniswapV2StandardExchangeDFPkg(_readAddress("05_uniswap_v2.json", "uniswapV2Pkg"));
		
		rateProviderPkg = IStandardExchangeRateProviderDFPkg(_readAddress("04_balancer_v3.json", "rateProviderPkg"));
		erc20MinterFacade = IERC20MinterFacade(_readAddress("07_test_tokens.json", "erc20MinterFacade"));
		demoWeth = _readAddress("07_test_tokens.json", "demoWeth");
		richToken = _readAddress("07_test_tokens.json", "richToken");

		// Try to read from stage 15 (may not exist if stage 15 hasn't run)
		(address weightedPoolFactoryAddr, bool wpExists) = _readAddressSafe("15_seigniorage_detfs.json", "weightedPool8020Factory");
		if (wpExists && weightedPoolFactoryAddr != address(0)) {
			weightedPool8020Factory = IWeightedPool8020Factory(weightedPoolFactoryAddr);
		}

		require(address(create3Factory) != address(0), "Create3Factory not found");
		require(address(diamondPackageFactory) != address(0), "DiamondPackageFactory not found");
		require(address(vaultRegistry) != address(0), "VaultRegistry not found");
		require(address(feeOracle) != address(0), "FeeOracle not found");
		require(address(balancerV3StandardExchangeRouter) != address(0), "BalancerV3Router not found");
		require(address(uniswapV2Pkg) != address(0), "UniswapV2 pkg not found");
		require(address(rateProviderPkg) != address(0), "RateProvider pkg not found");
		require(address(erc20MinterFacade) != address(0), "ERC20MinterFacade not found");
		require(demoWeth != address(0), "DemoWETH not found");
		require(richToken != address(0), "RICH not found");
		
		// weightedPool8020Factory may be zero if stage 15 hasn't been run
	}

	function _deployFacets() internal {
		console.log("[Stage 16][ETH] Deploy facet: EthereumProtocolDETFExchangeInFacet");
		protocolExchangeInFacet = EthereumProtocolDETF_Facet_FactoryService.deployEthereumProtocolDETFExchangeInFacet(create3Factory);
		console.log("[Stage 16][ETH] Deployed facet", address(protocolExchangeInFacet));
		console.log("[Stage 16][ETH] Deploy facet: EthereumProtocolDETFExchangeInQueryFacet");
		protocolExchangeInQueryFacet = EthereumProtocolDETF_Facet_FactoryService.deployEthereumProtocolDETFExchangeInQueryFacet(create3Factory);
		console.log("[Stage 16][ETH] Deployed facet", address(protocolExchangeInQueryFacet));
		console.log("[Stage 16][ETH] Deploy facet: EthereumProtocolDETFExchangeOutFacet");
		protocolExchangeOutFacet = EthereumProtocolDETF_Facet_FactoryService.deployEthereumProtocolDETFExchangeOutFacet(create3Factory);
		console.log("[Stage 16][ETH] Deployed facet", address(protocolExchangeOutFacet));
		console.log("[Stage 16][ETH] Deploy facet: EthereumProtocolDETFBondingFacet");
		protocolBondingFacet = EthereumProtocolDETF_Facet_FactoryService.deployEthereumProtocolDETFBondingFacet(create3Factory);
		console.log("[Stage 16][ETH] Deployed facet", address(protocolBondingFacet));
		console.log("[Stage 16][ETH] Deploy facet: EthereumProtocolDETFBridgeFacet");
		protocolBridgeFacet = EthereumProtocolDETF_Facet_FactoryService.deployEthereumProtocolDETFBridgeFacet(create3Factory);
		console.log("[Stage 16][ETH] Deployed facet", address(protocolBridgeFacet));
		console.log("[Stage 16][ETH] Deploy facet: EthereumProtocolDETFBondingQueryFacet");
		protocolBondingQueryFacet = EthereumProtocolDETF_Facet_FactoryService.deployEthereumProtocolDETFBondingQueryFacet(create3Factory);
		console.log("[Stage 16][ETH] Deployed facet", address(protocolBondingQueryFacet));
		console.log("[Stage 16][ETH] Deploy facet: ProtocolNFTVaultFacet");
		protocolNFTVaultFacet = BaseProtocolDETF_Facet_FactoryService.deployProtocolNFTVaultFacet(create3Factory);
		console.log("[Stage 16][ETH] Deployed facet", address(protocolNFTVaultFacet));
		console.log("[Stage 16][ETH] Deploy facet: RICHIRFacet");
		richirFacet = BaseProtocolDETF_Facet_FactoryService.deployRICHIRFacet(create3Factory);
		console.log("[Stage 16][ETH] Deployed facet", address(richirFacet));

		// ERC721 facet needed by Protocol NFT Vault
		{
			console.log("[Stage 16][ETH] Deploy facet: ProtocolDETF_ERC721Facet");
			bytes32 facetSalt = keccak256("ProtocolDETF_ERC721Facet");
			erc721Facet = IFacet(create3Factory.deployFacet(type(ERC721Facet).creationCode, facetSalt));
			vm.label(address(erc721Facet), "ProtocolDETF_ERC721Facet");
			console.log("[Stage 16][ETH] Deployed facet", address(erc721Facet));
		}
	}

	function _deployPkgs() internal {
		// Protocol NFT Vault package
		{
			console.log("[Stage 16][ETH] Build/deploy package: ProtocolNFTVaultDFPkg");
			IProtocolNFTVaultDFPkg.PkgInit memory nftPkgInit = BaseProtocolDETF_Component_FactoryService.buildProtocolNFTVaultPkgInit(
				erc721Facet,
				erc4626BasicVaultFacet,
				erc4626StandardVaultFacet,
				protocolNFTVaultFacet,
				feeOracle,
				vaultRegistry
			);

			protocolNFTVaultPkg = BaseProtocolDETF_Pkg_FactoryService.deployProtocolNFTVaultDFPkg(vaultRegistry, nftPkgInit);
			require(address(protocolNFTVaultPkg) != address(0), "Protocol NFT vault pkg deploy failed");
			console.log("[Stage 16][ETH] Deployed package", address(protocolNFTVaultPkg));
		}

		// RICHIR package
		{
			console.log("[Stage 16][ETH] Build/deploy package: RICHIRDFPkg");
			IRICHIRDFPkg.PkgInit memory richirPkgInit = BaseProtocolDETF_Component_FactoryService.buildRICHIRPkgInit(
				erc20Facet,
				erc5267Facet,
				erc2612Facet,
				richirFacet,
				diamondPackageFactory
			);

			richirPkg = BaseProtocolDETF_Pkg_FactoryService.deployRICHIRDFPkg(create3Factory, richirPkgInit);
			require(address(richirPkg) != address(0), "RICHIR pkg deploy failed");
			console.log("[Stage 16][ETH] Deployed package", address(richirPkg));
		}

		// Protocol DETF package
		{
			console.log("[Stage 16][ETH] Build/deploy package: EthereumProtocolDETFDFPkg");
			EthereumProtocolDETF_Component_FactoryService.EthereumProtocolDETFFacets memory facets;
			facets.erc20Facet = erc20Facet;
			facets.erc5267Facet = erc5267Facet;
			facets.erc2612Facet = erc2612Facet;
			facets.erc4626BasicVaultFacet = erc4626BasicVaultFacet;
			facets.erc4626StandardVaultFacet = erc4626StandardVaultFacet;
			facets.protocolDETFExchangeInFacet = protocolExchangeInFacet;
			facets.protocolDETFExchangeInQueryFacet = protocolExchangeInQueryFacet;
			facets.protocolDETFExchangeOutFacet = protocolExchangeOutFacet;
			facets.protocolDETFBondingFacet = protocolBondingFacet;
			facets.protocolDETFBridgeFacet = protocolBridgeFacet;
			facets.protocolDETFBondingQueryFacet = protocolBondingQueryFacet;

			EthereumProtocolDETF_Component_FactoryService.EthereumProtocolDETFInfra memory infra;
			infra.feeOracle = feeOracle;
			infra.vaultRegistryDeployment = vaultRegistry;
			infra.permit2 = permit2;
			infra.balancerV3Vault = balancerV3Vault;
			// Use the canonical Balancer V3 Router for pool initialization (not our custom exchange router)
			infra.balancerV3Router = IRouter(ETHEREUM_SEPOLIA.BALANCER_V3_ROUTER);
			infra.balancerV3PrepayRouter = IBalancerV3StandardExchangeRouterPrepay(address(balancerV3StandardExchangeRouter));
			infra.weightedPool8020Factory = weightedPool8020Factory;
			infra.diamondFactory = diamondPackageFactory;

			EthereumProtocolDETF_Component_FactoryService.EthereumProtocolDETFPkgs memory pkgs;
			pkgs.uniswapV2StandardExchangeDFPkg = uniswapV2Pkg;
			pkgs.protocolNFTVaultPkg = protocolNFTVaultPkg;
			pkgs.richirPkg = richirPkg;
			pkgs.rateProviderPkg = rateProviderPkg;

			IEthereumProtocolDETFDFPkg.PkgInit memory detfPkgInit = EthereumProtocolDETF_Component_FactoryService.buildEthereumProtocolDETFPkgInit(
				facets,
				infra,
				pkgs,
				_bridgePkgConfig()
			);

			protocolDetfPkg = EthereumProtocolDETF_Pkg_FactoryService.deployEthereumProtocolDETFDFPkg(vaultRegistry, detfPkgInit);
			require(address(protocolDetfPkg) != address(0), "Protocol DETF pkg deploy failed");
			console.log("[Stage 16][ETH] Deployed package", address(protocolDetfPkg));
		}
	}

	function _approveInitialFunding() internal {
		console.log("[Stage 16][ETH] Mint/approve funding: DemoWETH", INITIAL_DEMO_WETH_DEPOSIT);
		if (INITIAL_DEMO_WETH_DEPOSIT > 0) {
			erc20MinterFacade.mintToken(IERC20MintBurn(demoWeth), INITIAL_DEMO_WETH_DEPOSIT, owner);
			IERC20(demoWeth).approve(address(permit2), type(uint256).max);
			permit2.approve(demoWeth, address(protocolDetfPkg), uint160(INITIAL_DEMO_WETH_DEPOSIT), type(uint48).max);
		}

		console.log("[Stage 16][ETH] Approve funding: RICH", INITIAL_RICH_DEPOSIT);
		if (INITIAL_RICH_DEPOSIT > 0) {
			IERC20(richToken).approve(address(permit2), type(uint256).max);
			permit2.approve(richToken, address(protocolDetfPkg), uint160(INITIAL_RICH_DEPOSIT), type(uint48).max);
		}
	}

	function _deployProtocolDetf() internal {
		console.log("[Stage 16][ETH] Deploy vault: ProtocolDETF(CHIR)");
		IEthereumProtocolDETFDFPkg.PkgArgs memory args = IEthereumProtocolDETFDFPkg.PkgArgs({
			name: "Protocol DETF CHIR",
			symbol: "CHIR",
			protocolConfig: BaseProtocolDETFRepo.ProtocolConfig({
				richToken: richToken,
				richInitialDepositAmount: INITIAL_RICH_DEPOSIT,
				richMintChirPercent: ONE_WAD,
				wethToken: demoWeth,
				wethInitialDepositAmount: INITIAL_DEMO_WETH_DEPOSIT,
				wethMintChirPercent: ONE_WAD
			}),
			funder: owner
		});

		protocolDetf = vaultRegistry.deployVault(IStandardVaultPkg(address(protocolDetfPkg)), abi.encode(args));
		require(protocolDetf != address(0), "Protocol DETF deploy failed");
		vm.label(protocolDetf, "ProtocolDETF(CHIR)");
		console.log("[Stage 16][ETH] Deployed vault", protocolDetf);

		IProtocolDETF detf = IProtocolDETF(protocolDetf);
		protocolNftVault = address(detf.protocolNFTVault());
		richirToken = address(detf.richirToken());
		reservePool = detf.reservePool();
		chirWethVault = address(detf.chirWethVault());
		richChirVault = address(detf.richChirVault());

		vm.label(protocolNftVault, "ProtocolNFTVault");
		vm.label(richirToken, "RICHIR");
		vm.label(reservePool, "CHIR Reserve Pool");
		vm.label(chirWethVault, "CHIR/WETH Vault");
		vm.label(richChirVault, "RICH/CHIR Vault");
	}

	function _exportJson() internal {
		string memory json;

		json = vm.serializeAddress("", "demoWeth", demoWeth);
		json = vm.serializeAddress("", "richToken", richToken);

		json = vm.serializeAddress("", "protocolDetfPkg", address(protocolDetfPkg));
		json = vm.serializeAddress("", "protocolNFTVaultPkg", address(protocolNFTVaultPkg));
		json = vm.serializeAddress("", "richirPkg", address(richirPkg));

		json = vm.serializeAddress("", "protocolDetf", protocolDetf);
		json = vm.serializeAddress("", "protocolNftVault", protocolNftVault);
		json = vm.serializeAddress("", "richirToken", richirToken);
		json = vm.serializeAddress("", "reservePool", reservePool);
		json = vm.serializeAddress("", "chirWethVault", chirWethVault);
		json = vm.serializeAddress("", "richChirVault", richChirVault);

		_writeJson(json, "16_protocol_detf.json");
	}

	function _logResults() internal view {
		_logAddress("DemoWETH:", demoWeth);
		_logAddress("RICH:", richToken);
		_logAddress("ProtocolDETF (CHIR):", protocolDetf);
		_logAddress("Protocol NFT Vault:", protocolNftVault);
		_logAddress("RICHIR:", richirToken);
		_logAddress("Reserve Pool:", reservePool);
		_logComplete("Stage 16 (Public Sepolia - DemoWETH)");
	}

	function _bridgePkgConfig() internal view returns (ProtocolDETFSuperchainBridgeRepo.BridgeConfig memory bridgeConfig) {
		string memory remoteOutDir = _requiredEnvString("REMOTE_OUT_DIR");
		address bridgeRegistry = _readAddress("24_superchain_bridge.json", "bridgeTokenRegistry");
		address localRelayer = _readAddress("24_superchain_bridge.json", "tokenTransferRelayer");
		address peerRelayer = _readAddressFromDir(remoteOutDir, "24_superchain_bridge.json", "tokenTransferRelayer");

		bridgeConfig = ProtocolDETFSuperchainBridgeRepo.BridgeConfig({
			bridgeTokenRegistry: ISuperChainBridgeTokenRegistry(bridgeRegistry),
			standardBridge: IStandardBridge(payable(ETHEREUM_SEPOLIA.BASE_L1_STANDARD_BRIDGE)),
			messenger: ICrossDomainMessenger(ETHEREUM_SEPOLIA.BASE_L1_CROSS_DOMAIN_MESSENGER),
			localRelayer: localRelayer,
			peerRelayer: peerRelayer
		});
	}

	function _requiredEnvString(string memory key) internal view returns (string memory value) {
		value = vm.envString(key);
		require(bytes(value).length > 0, "Missing required env string");
	}

	function _readAddressFromDir(string memory outDir, string memory file, string memory key) internal view returns (address) {
		string memory json = vm.readFile(string.concat(outDir, "/", file));
		return vm.parseJsonAddress(json, string.concat(".", key));
	}
}
