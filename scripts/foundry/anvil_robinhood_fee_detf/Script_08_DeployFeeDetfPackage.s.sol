// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {DetfPkgFactoryService} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";

import {DeploymentBase} from "./DeploymentBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/IRebasingClaimTokenDFPkg.sol";
import {IUniswapV4DetfBondNFTVaultDFPkg} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/IUniswapV4DetfBondNFTVaultDFPkg.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";

import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage as ICpPkg
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";

import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as CpFS
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";

import {
    IUniswapV4DetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {
    UniswapV4Detf_Facet_FactoryService
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Facet_FactoryService.sol";
import {
    UniswapV4Detf_Pkg_FactoryService
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Pkg_FactoryService.sol";

/// @title Script_08_DeployFeeDetfPackage
/// @notice Buffer CP hook DFPkg + CP fee-DETF DFPkg via manager registry only.
contract Script_08_DeployFeeDetfPackage is DeploymentBase {
    using BetterEfficientHashLib for bytes;
    using VaultComponentFactoryService for ICreate3FactoryProxy;

    string internal constant CRANE_FOUNDATION_FILE = "01_crane_foundation.json";
    string internal constant CORE_FILE = "02_indexedex_core.json";
    string internal constant CHILDREN_FILE = "07_detf_children.json";
    string internal constant ARTIFACT_FILE = "08_fee_detf_packages.json";

    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;
    address private indexedexManager;
    IFacet private erc20Facet;
    IFacet private erc2612Facet;
    IFacet private erc5267Facet;
    IFacet private multiAssetBasicVaultFacet;
    IFacet private multiAssetStandardVaultFacet;
    IFacet private multiStepOwnableFacet;

    address private bufferCpHookPkg;
    address private chirDetfPkg;
    address private bondNftVaultPkg;
    address private rebasingClaimTokenPkg;

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        RobinhoodCanonicalLib.requireCanonicalPins();
        _loadPrior();
        _logHeader("Stage 08: Buffer CP hook + CP DETF packages");

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
                ArtifactCreationCode.creationCode(create3Factory, "UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol:UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg"),
                abi.encode(
                    ICpPkg.PkgInit({
                        vaultRegistryDeployment: reg,
                        vaultFeeOracleQuery: feeOracle,
                        seFacet: seFacet,
                        depositFacet: depositFacet,
                        depositSingleFacet: CpFS.deployDepositSingleFacet(create3Factory),
                        depositPreviewFacet: CpFS.deployDepositPreviewFacet(create3Factory),
                        withdrawFacet: withdrawFacet,
                        erc20Facet: erc20Facet,
                        erc5267Facet: erc5267Facet,
                        erc2612Facet: erc2612Facet,
                        multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                        multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
                        multiStepOwnableFacet: multiStepOwnableFacet
                    })
                ),
                abi.encode(type(ICpPkg).name, "AnvilFeeDetf")._hash()
            );
        }

        {
            IFacet[5] memory productFacets = UniswapV4Detf_Facet_FactoryService.deployUniswapV4DetfFacets(create3Factory);
            chirDetfPkg = address(
                UniswapV4Detf_Pkg_FactoryService.deployUniswapV4DetfDFPkg(
                    reg,
                    IUniswapV4DetfDFPkg.PkgInit({
                        erc20Facet: erc20Facet,
                        erc5267Facet: erc5267Facet,
                        erc2612Facet: erc2612Facet,
                        multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                        multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
                        productFacets: productFacets,
                        feeOracle: feeOracle,
                        vaultRegistryDeployment: reg,
                        bondNftVaultPkg: IUniswapV4DetfBondNFTVaultDFPkg(bondNftVaultPkg),
                        rebasingClaimTokenPkg: IRebasingClaimTokenDFPkg(rebasingClaimTokenPkg),
                        syPkg: DetfPkgFactoryService.deployDETFSYComponents(
                            create3Factory, reg, feeOracle, erc5267Facet, erc2612Facet
                        )
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
        multiStepOwnableFacet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "multiStepOwnableFacet"));
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
        _logComplete("Stage 08");
    }
}
