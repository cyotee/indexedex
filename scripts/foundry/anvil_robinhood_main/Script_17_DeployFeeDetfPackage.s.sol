// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";

import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage as ICpPkg
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg as CpDFPkg
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as CpFS
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";

import {
    IUniswapV4SingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";
import {
    UniswapV4SingleStandardExchangeDETF_Component_FactoryService as CpDetfFS
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETF_Component_FactoryService.sol";

/// @title Script_08_DeployFeeDetfPackage
/// @notice Buffer CP hook DFPkg + CP fee-DETF DFPkg via manager registry only.
contract Script_17_DeployFeeDetfPackage is DeploymentBase {
    using BetterEfficientHashLib for bytes;
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using CpDetfFS for ICreate3FactoryProxy;
    using CpDetfFS for IVaultRegistryDeployment;

    string internal constant CRANE_FOUNDATION_FILE = "01_crane_foundation.json";
    string internal constant CORE_FILE = "02_indexedex_core.json";
    string internal constant CHILDREN_FILE = "11_detf_children.json";
    string internal constant ARTIFACT_FILE = "17_fee_detf_packages.json";

    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;
    address private indexedexManager;
    IFacet private erc20Facet;
    IFacet private erc2612Facet;
    IFacet private erc5267Facet;
    IFacet private multiAssetBasicVaultFacet;
    IFacet private multiAssetStandardVaultFacet;

    address private bufferCpHookPkg;
    address private chirDetfPkg;
    address private bondNftVaultPkg;
    address private rebasingClaimTokenPkg;

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        RobinhoodCanonicalLib.requireCanonicalPins();
        _loadPrior();
        _logHeader("Stage 17: Buffer CP hook + CP DETF packages");

        if (_loadExisting()) {
            _exportJson();
            _logResults();
            return;
        }

        IVaultRegistryDeployment reg = IVaultRegistryDeployment(indexedexManager);
        IVaultFeeOracleQuery feeOracle = IVaultFeeOracleQuery(indexedexManager);
        IPoolManager pm = IPoolManager(RobinhoodCanonicalLib.poolManager());

        vm.startBroadcast();

        // Buffer CP hook package (registry path; no FactoryService.deployPackage under broadcast).
        {
            IFacet seFacet = CpFS.deploySeFacet(create3Factory);
            IFacet depositFacet = CpFS.deployDepositFacet(create3Factory);
            IFacet withdrawFacet = CpFS.deployWithdrawFacet(create3Factory);
            bufferCpHookPkg = reg.deployPkg(
                type(CpDFPkg).creationCode,
                abi.encode(
                    ICpPkg.PkgInit({
                        vaultRegistryDeployment: reg,
                        vaultFeeOracleQuery: feeOracle,
                        seFacet: seFacet,
                        depositFacet: depositFacet,
                        withdrawFacet: withdrawFacet,
                        erc20Facet: erc20Facet,
                        erc5267Facet: erc5267Facet,
                        erc2612Facet: erc2612Facet,
                        multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                        multiAssetStandardVaultFacet: multiAssetStandardVaultFacet
                    })
                ),
                abi.encode(type(ICpPkg).name, "AnvilFeeDetf")._hash()
            );
        }

        // CP DETF package via registry FactoryService
        {
            IFacet multiAssetBasicVaultFacetDetf = create3Factory.deployMultiAssetBasicVaultFacet();
            IFacet multiAssetStandardVaultFacetDetf = create3Factory.deployMultiAssetStandardVaultFacet();
            IFacet exchangeInFacet = CpDetfFS.deployExchangeInFacet(create3Factory);
            chirDetfPkg = address(
                CpDetfFS.deployPkg(
                    reg,
                    IUniswapV4SingleStandardExchangeDETDFPkg.PkgInit({
                        erc20Facet: erc20Facet,
                        erc5267Facet: erc5267Facet,
                        erc2612Facet: erc2612Facet,
                        multiAssetBasicVaultFacet: multiAssetBasicVaultFacetDetf,
                        multiAssetStandardVaultFacet: multiAssetStandardVaultFacetDetf,
                        exchangeInFacet: exchangeInFacet,
                        feeOracle: feeOracle,
                        vaultRegistryDeployment: reg,
                        poolManager: pm,
                        hookPkg: ICpPkg(bufferCpHookPkg),
                        bondNftVaultPkg: IDetfSelfNftInventoryDFPkg(bondNftVaultPkg),
                        rebasingClaimTokenPkg: IRebasingClaimTokenDFPkg(rebasingClaimTokenPkg),
                        diamondFactory: diamondPackageFactory
                    })
                )
            );
        }

        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPrior() internal {
        create3Factory = ICreate3FactoryProxy(_readAddress(CRANE_FOUNDATION_FILE, "create3Factory"));
        diamondPackageFactory =
            IDiamondPackageCallBackFactory(_readAddress(CRANE_FOUNDATION_FILE, "diamondPackageFactory"));
        indexedexManager = _readAddress(CORE_FILE, "indexedexManager");
        erc20Facet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc20Facet"));
        erc2612Facet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc2612Facet"));
        erc5267Facet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc5267Facet"));
        multiAssetBasicVaultFacet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "multiAssetBasicVaultFacet"));
        multiAssetStandardVaultFacet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "multiAssetStandardVaultFacet"));
        bondNftVaultPkg = _readAddress(CHILDREN_FILE, "bondNftVaultPkg");
        rebasingClaimTokenPkg = _readAddress(CHILDREN_FILE, "rebasingClaimTokenPkg");
    }

    function _loadExisting() internal returns (bool) {
        if (_force()) return false;
        (address a, bool okA) = _readAddressSafe(ARTIFACT_FILE, "bufferCpHookPkg");
        (address b, bool okB) = _readAddressSafe(ARTIFACT_FILE, "chirDetfPkg");
        if (!(okA && okB) || a.code.length == 0 || b.code.length == 0) return false;
        bufferCpHookPkg = a;
        chirDetfPkg = b;
        // Children pkgs always come from stage 11 (shared with lab DETFs)
        bondNftVaultPkg = _readAddress(CHILDREN_FILE, "bondNftVaultPkg");
        rebasingClaimTokenPkg = _readAddress(CHILDREN_FILE, "rebasingClaimTokenPkg");
        return true;
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("pkgs", "bufferCpHookPkg", bufferCpHookPkg);
        json = vm.serializeAddress("pkgs", "chirDetfPkg", chirDetfPkg);
        json = vm.serializeAddress("pkgs", "bondNftVaultPkg", bondNftVaultPkg);
        json = vm.serializeAddress("pkgs", "rebasingClaimTokenPkg", rebasingClaimTokenPkg);
        json = vm.serializeUint("pkgs", "chainId", block.chainid);
        json = vm.serializeString(
            "pkgs",
            "notes",
            "constantProduct/single Buffer CP hook + fee-DETF packages via registry"
        );
        _writeJson(json, ARTIFACT_FILE);
    }

    function _logResults() internal view {
        _logAddress("bufferCpHookPkg:", bufferCpHookPkg);
        _logAddress("chirDetfPkg:", chirDetfPkg);
        _logComplete("Stage 17");
    }
}
