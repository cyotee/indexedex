// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { betterconsole as console } from "@crane/contracts/utils/vm/foundry/tools/betterconsole.sol";

import {DeploymentBase} from "./DeploymentBase.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {BASE_MAIN} from "@crane/contracts/constants/networks/BASE_MAIN.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {ERC20PermitDFPkg, IERC20PermitDFPkg} from "@crane/contracts/tokens/ERC20/ERC20PermitDFPkg.sol";
import {IWeightedPool8020Factory} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool8020Factory.sol";
import {WeightedPool8020Factory} from "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPool8020Factory.sol";

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
import {IAerodromeStandardExchangeDFPkg} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol";

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";

import {BaseProtocolDETFRepo} from "contracts/vaults/protocol/BaseProtocolDETFRepo.sol";
import {BaseProtocolDETF_Component_FactoryService} from "contracts/vaults/protocol/BaseProtocolDETF_Component_FactoryService.sol";
import {BaseProtocolDETF_Facet_FactoryService} from "contracts/vaults/protocol/BaseProtocolDETF_Facet_FactoryService.sol";
import {BaseProtocolDETF_Pkg_FactoryService} from "contracts/vaults/protocol/BaseProtocolDETF_Pkg_FactoryService.sol";
import {IBaseProtocolDETFDFPkg} from "contracts/vaults/protocol/BaseProtocolDETFDFPkg.sol";
import {IProtocolNFTVaultDFPkg} from "contracts/vaults/protocol/ProtocolNFTVaultDFPkg.sol";
import {IRICHIRDFPkg} from "contracts/vaults/protocol/RICHIRDFPkg.sol";

/// @title Script_16_DeployProtocolDETF (Public Sepolia)
/// @notice Deploys the Base Protocol DETF instance required for bridge config and UI testing.
contract Script_16_DeployProtocolDETF is DeploymentBase {
	using BetterEfficientHashLib for bytes;

	/* ---------------------------------------------------------------------- */
	/*                                 Constants                               */
	/* ---------------------------------------------------------------------- */

	uint256 private constant RICH_TOTAL_SUPPLY = 1_000_000_000e18;
	uint256 private constant INITIAL_WETH_DEPOSIT = 10e18;
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
	IAerodromeStandardExchangeDFPkg private aerodromePkg;
	IStandardExchangeRateProviderDFPkg private rateProviderPkg;

	// Stage 15 output (re-used)
	IWeightedPool8020Factory private weightedPool8020Factory;

	/* ---------------------------------------------------------------------- */
	/*                            Deployed infra                               */
	/* ---------------------------------------------------------------------- */

	IFacet private protocolExchangeInFacet;
	IFacet private protocolExchangeInQueryFacet;
	IFacet private protocolExchangeOutFacet;
	IFacet private protocolBondingFacet;
	IFacet private protocolBondingQueryFacet;
	IFacet private protocolNFTVaultFacet;
	IFacet private richirFacet;

	IFacet private erc721Facet;

	IERC20PermitDFPkg private richTokenPkg;

	IProtocolNFTVaultDFPkg private protocolNFTVaultPkg;
	IRICHIRDFPkg private richirPkg;
	IBaseProtocolDETFDFPkg private protocolDetfPkg;

	/* ---------------------------------------------------------------------- */
	/*                              Deployed addresses                          */
	/* ---------------------------------------------------------------------- */

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
		console.log("[Stage 16][BASE] Checkpoint: begin run()");
		console.log("[Stage 16][BASE] Checkpoint: calling _setup()");
		_setup();
		console.log("[Stage 16][BASE] Checkpoint: _setup() complete");
		console.log("[Stage 16][BASE] Checkpoint: calling _loadPreviousDeployments()");
		_loadPreviousDeployments();
		console.log("[Stage 16][BASE] Checkpoint: _loadPreviousDeployments() complete");

		_logHeader("Stage 16: Deploy Protocol DETF (CHIR) - Public Sepolia");
		console.log("[Stage 16][BASE] Checkpoint: starting broadcast");

		vm.startBroadcast();

		console.log("[Stage 16][BASE] Checkpoint: deploying facets");
		_deployFacets();
		console.log("[Stage 16][BASE] Checkpoint: facets deployed");
		console.log("[Stage 16][BASE] Checkpoint: deploying RICH token");
		_deployRichToken();
		console.log("[Stage 16][BASE] Checkpoint: RICH token deployed");
		console.log("[Stage 16][BASE] Checkpoint: deploying packages");
		_deployWeightedPool8020FactoryIfNeeded();
		_deployPkgs();
		console.log("[Stage 16][BASE] Checkpoint: packages deployed");
		console.log("[Stage 16][BASE] Checkpoint: approving initial funding");
		_approveInitialFunding();
		console.log("[Stage 16][BASE] Checkpoint: initial funding approved");
		console.log("[Stage 16][BASE] Checkpoint: deploying Protocol DETF");
		_deployProtocolDetf();
		console.log("[Stage 16][BASE] Checkpoint: Protocol DETF deployed");

		vm.stopBroadcast();
		console.log("[Stage 16][BASE] Checkpoint: broadcast stopped");

		_exportJson();
		console.log("[Stage 16][BASE] Checkpoint: json exported");
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
			_readAddress("04_dex_packages.json", "balancerV3StandardExchangeRouter")
		);
		aerodromePkg = IAerodromeStandardExchangeDFPkg(_readAddress("04_dex_packages.json", "aerodromePkg"));
		rateProviderPkg = IStandardExchangeRateProviderDFPkg(_readAddress("04_dex_packages.json", "rateProviderPkg"));

		// Stage 15 may not exist in public sepolia
		(address weightedPoolFactoryAddr, bool wpExists) = _readAddressSafe("15_seigniorage_detfs.json", "weightedPool8020Factory");
		if (wpExists && weightedPoolFactoryAddr != address(0)) {
			weightedPool8020Factory = IWeightedPool8020Factory(weightedPoolFactoryAddr);
		}

		require(address(create3Factory) != address(0), "Create3Factory not found");
		require(address(diamondPackageFactory) != address(0), "DiamondPackageFactory not found");
		require(address(vaultRegistry) != address(0), "VaultRegistry not found");
		require(address(feeOracle) != address(0), "FeeOracle not found");
		require(address(balancerV3StandardExchangeRouter) != address(0), "BalancerV3Router not found");
		require(address(aerodromePkg) != address(0), "Aerodrome pkg not found");
		require(address(rateProviderPkg) != address(0), "RateProvider pkg not found");
	}

	function _deployWeightedPool8020FactoryIfNeeded() internal {
		if (address(weightedPool8020Factory) != address(0)) {
			return;
		}

		bytes32 salt = keccak256("SeigniorageWeightedPool8020Factory");
		bytes memory initCode = type(WeightedPool8020Factory).creationCode;
		bytes memory initArgs = abi.encode(
			balancerV3Vault,
			uint32(365 days),
			"Factory v1",
			"8020Pool v1"
		);

		weightedPool8020Factory = IWeightedPool8020Factory(create3Factory.create3WithArgs(initCode, initArgs, salt));
		require(address(weightedPool8020Factory) != address(0), "WeightedPool8020Factory deploy failed");
		vm.label(address(weightedPool8020Factory), "WeightedPool8020Factory");
	}

	function _deployFacets() internal {
		console.log("[Stage 16][BASE] Deploy facet: BaseProtocolDETFExchangeInFacet");
		protocolExchangeInFacet = BaseProtocolDETF_Facet_FactoryService.deployBaseProtocolDETFExchangeInFacet(create3Factory);
		console.log("[Stage 16][BASE] Deployed facet", address(protocolExchangeInFacet));
		console.log("[Stage 16][BASE] Deploy facet: BaseProtocolDETFExchangeInQueryFacet");
		protocolExchangeInQueryFacet = BaseProtocolDETF_Facet_FactoryService.deployBaseProtocolDETFExchangeInQueryFacet(create3Factory);
		console.log("[Stage 16][BASE] Deployed facet", address(protocolExchangeInQueryFacet));
		console.log("[Stage 16][BASE] Deploy facet: BaseProtocolDETFExchangeOutFacet");
		protocolExchangeOutFacet = BaseProtocolDETF_Facet_FactoryService.deployBaseProtocolDETFExchangeOutFacet(create3Factory);
		console.log("[Stage 16][BASE] Deployed facet", address(protocolExchangeOutFacet));
		console.log("[Stage 16][BASE] Deploy facet: BaseProtocolDETFBondingFacet");
		protocolBondingFacet = BaseProtocolDETF_Facet_FactoryService.deployBaseProtocolDETFBondingFacet(create3Factory);
		console.log("[Stage 16][BASE] Deployed facet", address(protocolBondingFacet));
		console.log("[Stage 16][BASE] Deploy facet: BaseProtocolDETFBondingQueryFacet");
		protocolBondingQueryFacet = BaseProtocolDETF_Facet_FactoryService.deployBaseProtocolDETFBondingQueryFacet(create3Factory);
		console.log("[Stage 16][BASE] Deployed facet", address(protocolBondingQueryFacet));
		console.log("[Stage 16][BASE] Deploy facet: ProtocolNFTVaultFacet");
		protocolNFTVaultFacet = BaseProtocolDETF_Facet_FactoryService.deployProtocolNFTVaultFacet(create3Factory);
		console.log("[Stage 16][BASE] Deployed facet", address(protocolNFTVaultFacet));
		console.log("[Stage 16][BASE] Deploy facet: RICHIRFacet");
		richirFacet = BaseProtocolDETF_Facet_FactoryService.deployRICHIRFacet(create3Factory);
		console.log("[Stage 16][BASE] Deployed facet", address(richirFacet));

		// ERC721 facet needed by Protocol NFT Vault
		{
			console.log("[Stage 16][BASE] Deploy facet: ProtocolDETF_ERC721Facet");
			bytes32 facetSalt = keccak256("ProtocolDETF_ERC721Facet");
			erc721Facet = IFacet(create3Factory.deployFacet(type(ERC721Facet).creationCode, facetSalt));
			vm.label(address(erc721Facet), "ProtocolDETF_ERC721Facet");
			console.log("[Stage 16][BASE] Deployed facet", address(erc721Facet));
		}
	}

	function _deployRichToken() internal {
		console.log("[Stage 16][BASE] Deploy package: ERC20PermitDFPkg(RICH)");
		IERC20PermitDFPkg.PkgInit memory pkgInit = IERC20PermitDFPkg.PkgInit({
			erc20Facet: erc20Facet,
			erc5267Facet: erc5267Facet,
			erc2612Facet: erc2612Facet
		});

		richTokenPkg = IERC20PermitDFPkg(
			address(
				create3Factory.deployPackageWithArgs(
					type(ERC20PermitDFPkg).creationCode,
					abi.encode(pkgInit),
					abi.encode(type(ERC20PermitDFPkg).name)._hash()
				)
			)
		);
		require(address(richTokenPkg) != address(0), "RICH token pkg deploy failed");
		vm.label(address(richTokenPkg), "ERC20PermitDFPkg(RICH)");
		console.log("[Stage 16][BASE] Deployed package", address(richTokenPkg));

		// Deploy the RICH token proxy and mint initial supply to `owner`.
		IERC20PermitDFPkg.PkgArgs memory richArgs = IERC20PermitDFPkg.PkgArgs({
			name: "Rich Token",
			symbol: "RICH",
			decimals: 18,
			totalSupply: RICH_TOTAL_SUPPLY,
			recipient: owner,
			optionalSalt: bytes32(0)
		});

		console.log("[Stage 16][BASE] Deploy proxy: RICH");
		richToken = diamondPackageFactory.deploy(IDiamondFactoryPackage(address(richTokenPkg)), abi.encode(richArgs));
		require(richToken != address(0), "RICH token deploy failed");
		vm.label(richToken, "RICH");
		console.log("[Stage 16][BASE] Deployed proxy", richToken);
	}

	function _deployPkgs() internal {
		// Protocol NFT Vault package
		{
			console.log("[Stage 16][BASE] Build/deploy package: ProtocolNFTVaultDFPkg");
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
			console.log("[Stage 16][BASE] Deployed package", address(protocolNFTVaultPkg));
		}

		// RICHIR package
		{
			console.log("[Stage 16][BASE] Build/deploy package: RICHIRDFPkg");
			IRICHIRDFPkg.PkgInit memory richirPkgInit = BaseProtocolDETF_Component_FactoryService.buildRICHIRPkgInit(
				erc20Facet,
				erc5267Facet,
				erc2612Facet,
				richirFacet,
				diamondPackageFactory
			);

			richirPkg = BaseProtocolDETF_Pkg_FactoryService.deployRICHIRDFPkg(create3Factory, richirPkgInit);
			require(address(richirPkg) != address(0), "RICHIR pkg deploy failed");
			console.log("[Stage 16][BASE] Deployed package", address(richirPkg));
		}

		// Protocol DETF package
		{
			console.log("[Stage 16][BASE] Build/deploy package: BaseProtocolDETFDFPkg");
			BaseProtocolDETF_Component_FactoryService.ProtocolDETFFacets memory facets;
			facets.erc20Facet = erc20Facet;
			facets.erc5267Facet = erc5267Facet;
			facets.erc2612Facet = erc2612Facet;
			facets.erc4626BasicVaultFacet = erc4626BasicVaultFacet;
			facets.erc4626StandardVaultFacet = erc4626StandardVaultFacet;
			facets.protocolDETFExchangeInFacet = protocolExchangeInFacet;
			facets.protocolDETFExchangeInQueryFacet = protocolExchangeInQueryFacet;
			facets.protocolDETFExchangeOutFacet = protocolExchangeOutFacet;
			facets.protocolDETFBondingFacet = protocolBondingFacet;
			facets.protocolDETFBondingQueryFacet = protocolBondingQueryFacet;

			BaseProtocolDETF_Component_FactoryService.ProtocolDETFInfra memory infra;
			infra.feeOracle = feeOracle;
			infra.vaultRegistryDeployment = vaultRegistry;
			infra.permit2 = permit2;
			infra.balancerV3Vault = balancerV3Vault;
			infra.balancerV3Router = IRouter(address(balancerV3Router));
			infra.balancerV3PrepayRouter = IBalancerV3StandardExchangeRouterPrepay(address(balancerV3StandardExchangeRouter));
			infra.weightedPool8020Factory = weightedPool8020Factory;
			infra.diamondFactory = diamondPackageFactory;

			BaseProtocolDETF_Component_FactoryService.ProtocolDETFPkgs memory pkgs;
			pkgs.aerodromeStandardExchangeDFPkg = aerodromePkg;
			pkgs.protocolNFTVaultPkg = protocolNFTVaultPkg;
			pkgs.richirPkg = richirPkg;
			pkgs.rateProviderPkg = rateProviderPkg;

			IBaseProtocolDETFDFPkg.PkgInit memory detfPkgInit = BaseProtocolDETF_Component_FactoryService.buildProtocolDETFPkgInit(
				facets,
				infra,
				pkgs
			);

			protocolDetfPkg = BaseProtocolDETF_Pkg_FactoryService.deployBaseProtocolDETFDFPkg(vaultRegistry, detfPkgInit);
			require(address(protocolDetfPkg) != address(0), "Protocol DETF pkg deploy failed");
			console.log("[Stage 16][BASE] Deployed package", address(protocolDetfPkg));
		}
	}

	function _approveInitialFunding() internal {
		if (INITIAL_WETH_DEPOSIT > 0) {
			weth.deposit{value: INITIAL_WETH_DEPOSIT}();
			weth.approve(address(permit2), type(uint256).max);
			permit2.approve(address(weth), address(protocolDetfPkg), uint160(INITIAL_WETH_DEPOSIT), type(uint48).max);
		}

		if (INITIAL_RICH_DEPOSIT > 0) {
			IERC20(richToken).approve(address(permit2), type(uint256).max);
			permit2.approve(richToken, address(protocolDetfPkg), uint160(INITIAL_RICH_DEPOSIT), type(uint48).max);
		}
	}

	function _deployProtocolDetf() internal {
		IBaseProtocolDETFDFPkg.PkgArgs memory args = IBaseProtocolDETFDFPkg.PkgArgs({
			name: "Protocol DETF CHIR",
			symbol: "CHIR",
			protocolConfig: BaseProtocolDETFRepo.ProtocolConfig({
				richToken: richToken,
				richInitialDepositAmount: INITIAL_RICH_DEPOSIT,
				richMintChirPercent: ONE_WAD,
				wethToken: address(weth),
				wethInitialDepositAmount: INITIAL_WETH_DEPOSIT,
				wethMintChirPercent: ONE_WAD
			}),
			bridgeInitData: bytes(""),
			funder: owner
		});

		protocolDetf = vaultRegistry.deployVault(IStandardVaultPkg(address(protocolDetfPkg)), abi.encode(args));
		require(protocolDetf != address(0), "Protocol DETF deploy failed");
		vm.label(protocolDetf, "ProtocolDETF(CHIR)");

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

		json = vm.serializeAddress("", "richToken", richToken);
		json = vm.serializeAddress("", "richTokenPkg", address(richTokenPkg));

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
		_logAddress("RICH:", richToken);
		_logAddress("ProtocolDETF (CHIR):", protocolDetf);
		_logAddress("Protocol NFT Vault:", protocolNftVault);
		_logAddress("RICHIR:", richirToken);
		_logAddress("Reserve Pool:", reservePool);
		_logComplete("Stage 16 (Public Sepolia)");
	}
}
