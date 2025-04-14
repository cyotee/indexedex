// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";

import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {ERC20MintBurnOwnableFacet} from "@crane/contracts/tokens/ERC20/ERC20MintBurnOwnableFacet.sol";
import {IERC20PermitMintBurnLockedOwnableDFPkg} from
    "@crane/contracts/tokens/ERC20/ERC20PermitMintBurnLockedOwnableDFPkg.sol";
import {ERC20PermitMintBurnLockedOwnableDFPkg} from
    "@crane/contracts/tokens/ERC20/ERC20PermitMintBurnLockedOwnableDFPkg.sol";
import {IWeightedPool8020Factory} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool8020Factory.sol";

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {WeightedPool8020Factory} from "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPool8020Factory.sol";
import {IVault as IBalancerV3Vault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRouter} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRouter.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IBalancerV3StandardExchangeRouterProxy} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {IBalancerV3StandardExchangeRouterPrepay} from
    "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";

import {IStandardExchangeRateProviderDFPkg} from
    "contracts/protocols/dexes/balancer/v3/rateProviders/StandardExchangeRateProviderDFPkg.sol";

import {Seigniorage_Component_FactoryService} from "contracts/vaults/seigniorage/Seigniorage_Component_FactoryService.sol";
import {ISeigniorageDETFDFPkg} from "contracts/vaults/seigniorage/SeigniorageDETFDFPkg.sol";
import {ISeigniorageNFTVaultDFPkg} from "contracts/vaults/seigniorage/SeigniorageNFTVaultDFPkg.sol";

/// @title Script_15_DeploySeigniorageDETFS
/// @notice Deploys Seigniorage DETF infra and one DETF per Standard Exchange vault (UniV2 + Aerodrome strategy vaults)
/// @dev Run: forge script scripts/foundry/anvil_sepolia/Script_15_DeploySeigniorageDETFS.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --unlocked --sender <DEV_ADDRESS>
contract Script_15_DeploySeigniorageDETFS is DeploymentBase {
    using Seigniorage_Component_FactoryService for ICreate3FactoryProxy;

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
    IStandardExchangeRateProviderDFPkg private rateProviderPkg;

    /* ---------------------------------------------------------------------- */
    /*                            Deployed infra                               */
    /* ---------------------------------------------------------------------- */

    address private weightedPool8020Factory;
    IFacet private seigniorageExchangeInFacet;
    IFacet private seigniorageExchangeOutFacet;
    IFacet private seigniorageUnderwritingFacet;
    IFacet private seigniorageNFTVaultFacet;

    IFacet private erc721Facet;
    IFacet private erc20MintBurnOwnableFacet;

    IERC20PermitMintBurnLockedOwnableDFPkg private seigniorageTokenPkg;
    ISeigniorageNFTVaultDFPkg private seigniorageNFTVaultPkg;
    ISeigniorageDETFDFPkg private seigniorageDetfPkg;

    /* ---------------------------------------------------------------------- */
    /*                              Deployed vaults                            */
    /* ---------------------------------------------------------------------- */

    address private detf_abVault;
    address private detf_acVault;
    address private detf_bcVault;
    address private detf_aeroAbVault;
    address private detf_aeroAcVault;
    address private detf_aeroBcVault;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 15: Deploy Seigniorage DETFs");

        vm.startBroadcast();

        _deployWeightedPool8020Factory();
        _deployFacets();
        _deployTokenPkg();
        _deployPkgs();
        _deployDetfs();

        vm.stopBroadcast();

        _exportJson();
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
        rateProviderPkg = IStandardExchangeRateProviderDFPkg(_readAddress("04_balancer_v3.json", "rateProviderPkg"));

        require(address(create3Factory) != address(0), "Create3Factory not found");
        require(address(diamondPackageFactory) != address(0), "DiamondPackageFactory not found");
        require(address(vaultRegistry) != address(0), "VaultRegistry not found");
        require(address(feeOracle) != address(0), "FeeOracle not found");
        require(address(balancerV3StandardExchangeRouter) != address(0), "BalancerV3Router not found");
        require(address(rateProviderPkg) != address(0), "RateProviderPkg not found");
    }

    function _deployWeightedPool8020Factory() internal {
        bytes32 salt = keccak256("SeigniorageWeightedPool8020Factory");
        bytes memory initCode = type(WeightedPool8020Factory).creationCode;
        bytes memory initArgs = abi.encode(IBalancerV3Vault(address(balancerV3Vault)), uint32(365 days), "Factory v1", "8020Pool v1");

        weightedPool8020Factory = create3Factory.create3WithArgs(initCode, initArgs, salt);
        require(weightedPool8020Factory != address(0), "WeightedPool8020Factory deploy failed");

        vm.label(weightedPool8020Factory, "WeightedPool8020Factory");
    }

    function _deployFacets() internal {
        seigniorageExchangeInFacet = create3Factory.deploySeigniorageDETFExchangeInFacet();
        seigniorageExchangeOutFacet = create3Factory.deploySeigniorageDETFExchangeOutFacet();
        seigniorageUnderwritingFacet = create3Factory.deploySeigniorageDETFUnderwritingFacet();
        seigniorageNFTVaultFacet = create3Factory.deploySeigniorageNFTVaultFacet();

        // ERC721 facet needed by Seigniorage NFT Vault
        {
            bytes32 facetSalt = keccak256("SeigniorageERC721Facet");
            erc721Facet = IFacet(create3Factory.deployFacet(type(ERC721Facet).creationCode, facetSalt));
            vm.label(address(erc721Facet), "SeigniorageERC721Facet");
        }

        // ERC20 mint/burn facet needed by the seigniorage reward token package
        {
            bytes32 facetSalt = keccak256("SeigniorageERC20MintBurnOwnableFacet");
            erc20MintBurnOwnableFacet =
                IFacet(create3Factory.deployFacet(type(ERC20MintBurnOwnableFacet).creationCode, facetSalt));
            vm.label(address(erc20MintBurnOwnableFacet), "SeigniorageERC20MintBurnOwnableFacet");
        }
    }

    function _deployTokenPkg() internal {
        bytes32 pkgSalt = keccak256("ERC20PermitMintBurnLockedOwnableDFPkg");

        IERC20PermitMintBurnLockedOwnableDFPkg.PkgInit memory pkgInit = IERC20PermitMintBurnLockedOwnableDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            erc20MintBurnOwnableFacet: erc20MintBurnOwnableFacet,
            diamondFactory: diamondPackageFactory
        });

        seigniorageTokenPkg = IERC20PermitMintBurnLockedOwnableDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(ERC20PermitMintBurnLockedOwnableDFPkg).creationCode,
                    abi.encode(pkgInit),
                    pkgSalt
                )
            )
        );
        require(address(seigniorageTokenPkg) != address(0), "Seigniorage token pkg deploy failed");
        vm.label(address(seigniorageTokenPkg), "ERC20PermitMintBurnLockedOwnableDFPkg");
    }

    function _deployPkgs() internal {
        // Seigniorage NFT vault package (registered via vault registry)
        {
            ISeigniorageNFTVaultDFPkg.PkgInit memory nftPkgInit = Seigniorage_Component_FactoryService
                .buildSeigniorageNFTVaultPkgInit(
                    erc721Facet,
                    erc4626BasicVaultFacet,
                    erc4626StandardVaultFacet,
                    seigniorageNFTVaultFacet,
                    feeOracle,
                    vaultRegistry
                );

            seigniorageNFTVaultPkg = Seigniorage_Component_FactoryService.deploySeigniorageNFTVaultDFPkg(vaultRegistry, nftPkgInit);
            require(address(seigniorageNFTVaultPkg) != address(0), "Seigniorage NFT vault pkg deploy failed");
        }

        // Seigniorage DETF package (registered via vault registry)
        {
            Seigniorage_Component_FactoryService.SeigniorageDETFPkgInitParams memory params;
            params.erc20Facet = erc20Facet;
            params.erc5267Facet = erc5267Facet;
            params.erc2612Facet = erc2612Facet;
            params.erc4626BasicVaultFacet = erc4626BasicVaultFacet;
            params.erc4626StandardVaultFacet = erc4626StandardVaultFacet;
            params.seigniorageDETFExchangeInFacet = seigniorageExchangeInFacet;
            params.seigniorageDETFExchangeOutFacet = seigniorageExchangeOutFacet;
            params.seigniorageDETFUnderwritingFacet = seigniorageUnderwritingFacet;
            params.feeOracle = feeOracle;
            params.vaultRegistryDeployment = vaultRegistry;
            params.permit2 = permit2;
            params.balancerV3Vault = balancerV3Vault;

            // The router is a diamond proxy; call through the proxy address
            params.balancerV3Router = IRouter(address(balancerV3StandardExchangeRouter));
            params.balancerV3PrepayRouter = IBalancerV3StandardExchangeRouterPrepay(address(balancerV3StandardExchangeRouter));

            // Canonical 80/20 factory deployed on fork
            params.weightedPool8020Factory = IWeightedPool8020Factory(weightedPool8020Factory);
            params.diamondFactory = diamondPackageFactory;
            params.seigniorageTokenPkg = seigniorageTokenPkg;
            params.seigniorageNFTVaultPkg = seigniorageNFTVaultPkg;
            params.reserveVaultRateProviderPkg = rateProviderPkg;

            ISeigniorageDETFDFPkg.PkgInit memory detfPkgInit = Seigniorage_Component_FactoryService
                .buildSeigniorageDETFPkgInit(params);

            seigniorageDetfPkg = Seigniorage_Component_FactoryService.deploySeigniorageDETFDFPkg(vaultRegistry, detfPkgInit);
            require(address(seigniorageDetfPkg) != address(0), "Seigniorage DETF pkg deploy failed");
        }
    }

    function _deployDetfs() internal {
        // Read from stage 09 (anvil_sepolia) instead of stage 07 (anvil_base_main)
        IStandardExchangeProxy abVault = IStandardExchangeProxy(_readAddress("09_strategy_vaults.json", "abVault"));
        IStandardExchangeProxy acVault = IStandardExchangeProxy(_readAddress("09_strategy_vaults.json", "acVault"));
        IStandardExchangeProxy bcVault = IStandardExchangeProxy(_readAddress("09_strategy_vaults.json", "bcVault"));

        // Try to read aerodrome vaults - may be in the same file or may not exist
        (address aeroAbVault, bool aeroAbExists) = _readAddressSafe("09_strategy_vaults.json", "aeroAbVault");
        (address aeroAcVault, bool aeroAcExists) = _readAddressSafe("09_strategy_vaults.json", "aeroAcVault");
        (address aeroBcVault, bool aeroBcExists) = _readAddressSafe("09_strategy_vaults.json", "aeroBcVault");

        detf_abVault = _deployDetfForReserveVault(abVault);
        detf_acVault = _deployDetfForReserveVault(acVault);
        detf_bcVault = _deployDetfForReserveVault(bcVault);
        
        if (aeroAbExists && aeroAbVault != address(0)) {
            detf_aeroAbVault = _deployDetfForReserveVault(IStandardExchangeProxy(aeroAbVault));
        }
        if (aeroAcExists && aeroAcVault != address(0)) {
            detf_aeroAcVault = _deployDetfForReserveVault(IStandardExchangeProxy(aeroAcVault));
        }
        if (aeroBcExists && aeroBcVault != address(0)) {
            detf_aeroBcVault = _deployDetfForReserveVault(IStandardExchangeProxy(aeroBcVault));
        }
    }

    function _deployDetfForReserveVault(IStandardExchangeProxy reserveVault) internal returns (address deployed) {
        if (address(reserveVault) == address(0)) {
            return address(0);
        }
        
        // Choose a "rate target" that the reserve vault can quote into.
        // For StandardExchange vaults, we can usually use the underlying LP's token0.
        address lp = IERC4626(address(reserveVault)).asset();
        address token0 = _tryToken0(lp);
        require(token0 != address(0), "Could not resolve LP token0");

        string memory rvSymbol;
        try IERC20Metadata(address(reserveVault)).symbol() returns (string memory s) {
            rvSymbol = s;
        } catch {
            rvSymbol = "RV";
        }

        string memory detfSymbol = string.concat("SDETF-", rvSymbol);

        ISeigniorageDETFDFPkg.PkgArgs memory args = ISeigniorageDETFDFPkg.PkgArgs({
            name: "",
            symbol: detfSymbol,
            reserveVault: reserveVault,
            reserveVaultRateTarget: IERC20Metadata(token0)
        });

        deployed = vaultRegistry.deployVault(IStandardVaultPkg(address(seigniorageDetfPkg)), abi.encode(args));
        require(deployed != address(0), "DETF deploy failed");
    }

    function _tryToken0(address pool) internal view returns (address token0) {
        // token0() selector: 0x0dfe1681
        (bool ok, bytes memory ret) = pool.staticcall(abi.encodeWithSelector(0x0dfe1681));
        if (!ok || ret.length < 32) return address(0);
        token0 = abi.decode(ret, (address));
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("", "weightedPool8020Factory", weightedPool8020Factory);

        json = vm.serializeAddress("", "seigniorageExchangeInFacet", address(seigniorageExchangeInFacet));
        json = vm.serializeAddress("", "seigniorageExchangeOutFacet", address(seigniorageExchangeOutFacet));
        json = vm.serializeAddress("", "seigniorageUnderwritingFacet", address(seigniorageUnderwritingFacet));
        json = vm.serializeAddress("", "seigniorageNFTVaultFacet", address(seigniorageNFTVaultFacet));
        json = vm.serializeAddress("", "erc721Facet", address(erc721Facet));
        json = vm.serializeAddress("", "erc20MintBurnOwnableFacet", address(erc20MintBurnOwnableFacet));

        json = vm.serializeAddress("", "seigniorageTokenPkg", address(seigniorageTokenPkg));
        json = vm.serializeAddress("", "seigniorageNFTVaultPkg", address(seigniorageNFTVaultPkg));
        json = vm.serializeAddress("", "seigniorageDetfPkg", address(seigniorageDetfPkg));

        json = vm.serializeAddress("", "detf_abVault", detf_abVault);
        json = vm.serializeAddress("", "detf_acVault", detf_acVault);
        json = vm.serializeAddress("", "detf_bcVault", detf_bcVault);
        json = vm.serializeAddress("", "detf_aeroAbVault", detf_aeroAbVault);
        json = vm.serializeAddress("", "detf_aeroAcVault", detf_aeroAcVault);
        json = vm.serializeAddress("", "detf_aeroBcVault", detf_aeroBcVault);

        _writeJson(json, "15_seigniorage_detfs.json");
    }

    function _logResults() internal view {
        _logAddress("WeightedPool8020Factory:", weightedPool8020Factory);
        _logAddress("SeigniorageDETFDFPkg:", address(seigniorageDetfPkg));

        _logAddress("DETF (abVault):", detf_abVault);
        _logAddress("DETF (acVault):", detf_acVault);
        _logAddress("DETF (bcVault):", detf_bcVault);
        _logAddress("DETF (aeroAbVault):", detf_aeroAbVault);
        _logAddress("DETF (aeroAcVault):", detf_aeroAcVault);
        _logAddress("DETF (aeroBcVault):", detf_aeroBcVault);

        _logComplete("Stage 15");
    }
}
