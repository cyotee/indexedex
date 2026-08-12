// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {FixtureEconomics} from "./FixtureEconomics.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {IDETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultDFPkg.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/common/factory/DetfComponentFactoryService.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";

/// @title Script_07_DeployFeeDetfChildren
/// @notice Bond NFT vault DFPkg + rebasing claim DFPkg + default bond terms.
contract Script_07_DeployFeeDetfChildren is DeploymentBase {
    using DetfFacetFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for IVaultRegistryDeployment;
    using VaultComponentFactoryService for ICreate3FactoryProxy;

    string internal constant CRANE_FOUNDATION_FILE = "01_crane_foundation.json";
    string internal constant CORE_FILE = "02_indexedex_core.json";
    string internal constant ARTIFACT_FILE = "07_detf_children.json";

    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;
    address private indexedexManager;
    IFacet private erc20Facet;
    IFacet private erc2612Facet;
    IFacet private erc5267Facet;
    IFacet private erc4626BasicVaultFacet;
    IFacet private erc4626StandardVaultFacet;

    address private bondNftVaultPkg;
    address private rebasingClaimTokenPkg;

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        _loadPrior();
        _logHeader("Stage 07: DETF children (bond NFT + rebasing claim)");

        if (_loadExisting()) {
            _exportJson();
            _logResults();
            return;
        }

        vm.startBroadcast();
        _deployRebasingClaimTokenPkg();
        _deployBondNftVaultPkg();
        _setDefaultBondTerms();
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
        erc4626BasicVaultFacet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc4626BasicVaultFacet"));
        erc4626StandardVaultFacet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc4626StandardVaultFacet"));
    }

    function _loadExisting() internal returns (bool) {
        if (_force()) return false;
        (address a, bool okA) = _readAddressSafe(ARTIFACT_FILE, "bondNftVaultPkg");
        (address b, bool okB) = _readAddressSafe(ARTIFACT_FILE, "rebasingClaimTokenPkg");
        if (!okA || !okB || a.code.length == 0 || b.code.length == 0) return false;
        bondNftVaultPkg = a;
        rebasingClaimTokenPkg = b;
        return true;
    }

    function _deployRebasingClaimTokenPkg() internal {
        IFacet claimFacet_ = create3Factory.deployRebasingClaimTokenFacet();
        IRebasingClaimTokenDFPkg pkg = create3Factory.deployRebasingClaimTokenDFPkg(
            DetfComponentFactoryService.buildRICHIRPkgInit(
                erc20Facet, erc5267Facet, erc2612Facet, claimFacet_, diamondPackageFactory
            )
        );
        rebasingClaimTokenPkg = address(pkg);
        vm.label(rebasingClaimTokenPkg, "RebasingClaimTokenPkg");
    }

    function _deployBondNftVaultPkg() internal {
        IFacet detfNFTVaultFacet = create3Factory.deployDETFNFTVaultFacet();
        IFacet erc721FacetDetf =
            IFacet(create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("FeeDetf_ERC721Facet")));

        IDETFNFTVaultDFPkg.PkgInit memory nftPkgInit = DetfComponentFactoryService.buildDETFNFTVaultPkgInit(
            erc721FacetDetf,
            erc4626BasicVaultFacet,
            erc4626StandardVaultFacet,
            detfNFTVaultFacet,
            IVaultFeeOracleQuery(indexedexManager),
            IVaultRegistryDeployment(indexedexManager)
        );

        bondNftVaultPkg = address(
            IVaultRegistryDeployment(indexedexManager).deployDETFNFTVaultDFPkg(nftPkgInit)
        );
        vm.label(bondNftVaultPkg, "BondNftVaultPkg");
    }

    function _setDefaultBondTerms() internal {
        try IVaultFeeOracleManager(indexedexManager).setDefaultBondTerms(
            BondTerms({
                minLockDuration: FixtureEconomics.DEFAULT_MIN_LOCK,
                maxLockDuration: FixtureEconomics.DEFAULT_MAX_LOCK,
                minBonusPercentage: 0,
                maxBonusPercentage: 0.5e18
            })
        ) {} catch {}
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("detfChildren", "bondNftVaultPkg", bondNftVaultPkg);
        json = vm.serializeAddress("detfChildren", "rebasingClaimTokenPkg", rebasingClaimTokenPkg);
        json = vm.serializeUint("detfChildren", "minLock", FixtureEconomics.DEFAULT_MIN_LOCK);
        json = vm.serializeUint("detfChildren", "maxLock", FixtureEconomics.DEFAULT_MAX_LOCK);
        json = vm.serializeUint("detfChildren", "chainId", block.chainid);
        _writeJson(json, ARTIFACT_FILE);
    }

    function _logResults() internal view {
        _logAddress("bondNftVaultPkg:", bondNftVaultPkg);
        _logAddress("rebasingClaimTokenPkg:", rebasingClaimTokenPkg);
        _logComplete("Stage 07");
    }
}
