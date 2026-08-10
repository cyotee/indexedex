// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {FixtureGraph} from "./FixtureGraph.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";

import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    IUniswapV3StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeDFPkg.sol";
import {
    UniswapV3_Component_FactoryService
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3_Component_FactoryService.sol";

/// @title Script_07_DeployUniV3StandardExchange
/// @notice Deploy Uni V3 SE DFPkg via manager registry + vault instances.
contract Script_07_DeployUniV3StandardExchange is DeploymentBase {
    using UniswapV3_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV3_Component_FactoryService for IIndexedexManagerProxy;

    string internal constant CRANE_FOUNDATION_FILE = "01_crane_foundation.json";
    string internal constant CORE_FILE = "02_indexedex_core.json";
    string internal constant TOKENS_FILE = "04_test_tokens.json";
    string internal constant V3_POOLS_FILE = "05_univ3_pools.json";
    string internal constant ARTIFACT_FILE = "07_univ3_se.json";

    ICreate3FactoryProxy private create3Factory;
    IIndexedexManagerProxy private indexedexManager;
    IFacet private erc20Facet;
    IFacet private erc2612Facet;
    IFacet private erc5267Facet;
    IFacet private multiAssetBasicVaultFacet;
    IFacet private multiAssetStandardVaultFacet;

    IUniswapV3StandardExchangeDFPkg private uniV3SePkg;
    address private uniV3Se_tt0_tt1;
    address private uniV3Se_tt2_tt3;

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        RobinhoodCanonicalLib.requireCanonicalPins();
        _loadPrior();
        _logHeader("Stage 07: Uni V3 Standard Exchange");

        if (_loadExisting()) {
            _exportJson();
            _logResults();
            return;
        }

        address poolA = _readAddress(V3_POOLS_FILE, "v3SePoolA");
        address poolB = _readAddress(V3_POOLS_FILE, "v3SePoolB");
        address tt0 = _readAddress(TOKENS_FILE, "tt0");
        address tt1 = _readAddress(TOKENS_FILE, "tt1");

        vm.startBroadcast();
        _deployPkg();
        uniV3Se_tt0_tt1 = address(
            IStandardExchangeProxy(
                uniV3SePkg.deployVault(IUniswapV3Pool(poolA), FixtureGraph.V3_SE_WIDTH_MULTIPLIER)
            )
        );
        uniV3Se_tt2_tt3 = address(
            IStandardExchangeProxy(
                uniV3SePkg.deployVault(IUniswapV3Pool(poolB), FixtureGraph.V3_SE_WIDTH_MULTIPLIER)
            )
        );
        vm.label(uniV3Se_tt0_tt1, "uniV3Se_tt0_tt1");
        vm.label(uniV3Se_tt2_tt3, "uniV3Se_tt2_tt3");

        // Seed SE inventory with pair token exchangeIn (both sides for a healthy position).
        _seedSe(uniV3Se_tt0_tt1, tt0, 500_000e18);
        _seedSe(uniV3Se_tt0_tt1, tt1, 500_000e18);
        // Optional second SE instance also needs inventory for multi-leg demos.
        address tt2 = _readAddress(TOKENS_FILE, "tt2");
        address tt3 = _readAddress(TOKENS_FILE, "tt3");
        _seedSe(uniV3Se_tt2_tt3, tt2, 100_000e18);
        _seedSe(uniV3Se_tt2_tt3, tt3, 100_000e18);
        vm.stopBroadcast();

        // D14 precursor: shares → pairToken preview must work for StandardExchangeRateProvider.
        uint256 supply = IERC20(uniV3Se_tt0_tt1).totalSupply();
        require(supply > 0, "V3 SE seed produced zero shares");
        uint256 quote = supply < 1e18 ? supply : 1e18;
        uint256 pairOut =
            IStandardExchangeIn(uniV3Se_tt0_tt1).previewExchangeIn(IERC20(uniV3Se_tt0_tt1), quote, IERC20(tt0));
        require(pairOut > 0, "V3 SE shares->pairToken preview is zero (RP getRate would be 0)");
        _logUint("V3 SE seed shares:", supply);
        _logUint("V3 SE preview 1e18 shares->TT0:", pairOut);

        _exportJson();
        _logResults();
    }

    function _loadPrior() internal {
        create3Factory = ICreate3FactoryProxy(_readAddress(CRANE_FOUNDATION_FILE, "create3Factory"));
        indexedexManager = IIndexedexManagerProxy(_readAddress(CORE_FILE, "indexedexManager"));
        erc20Facet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc20Facet"));
        erc2612Facet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc2612Facet"));
        erc5267Facet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc5267Facet"));
        multiAssetBasicVaultFacet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "multiAssetBasicVaultFacet"));
        multiAssetStandardVaultFacet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "multiAssetStandardVaultFacet"));
    }

    function _loadExisting() internal returns (bool) {
        (address pkg, bool okPkg) = _readAddressSafe(ARTIFACT_FILE, "uniV3SePkg");
        (address seA, bool okA) = _readAddressSafe(ARTIFACT_FILE, "uniV3Se_tt0_tt1");
        if (!okPkg || !okA || pkg.code.length == 0 || seA.code.length == 0) return false;
        uniV3SePkg = IUniswapV3StandardExchangeDFPkg(pkg);
        uniV3Se_tt0_tt1 = seA;
        (address seB, bool okB) = _readAddressSafe(ARTIFACT_FILE, "uniV3Se_tt2_tt3");
        if (okB) uniV3Se_tt2_tt3 = seB;
        return true;
    }

    function _deployPkg() internal {
        IFacet inFacet = create3Factory.deployUniswapV3StandardExchangeInFacet();
        IFacet inQueryFacet = create3Factory.deployUniswapV3StandardExchangeInQueryFacet();
        IFacet outFacet = create3Factory.deployUniswapV3StandardExchangeOutFacet();
        IFacet posImportFacet = create3Factory.deployUniswapV3StandardExchangePositionImportFacet();

        IUniswapV3StandardExchangeDFPkg.PkgInit memory pkgInit;
        pkgInit.erc20Facet = erc20Facet;
        pkgInit.erc5267Facet = erc5267Facet;
        pkgInit.erc2612Facet = erc2612Facet;
        pkgInit.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        pkgInit.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        pkgInit.uniswapV3StandardExchangeInFacet = inFacet;
        pkgInit.uniswapV3StandardExchangeInQueryFacet = inQueryFacet;
        pkgInit.uniswapV3StandardExchangeOutFacet = outFacet;
        pkgInit.uniswapV3StandardExchangePositionImportFacet = posImportFacet;
        pkgInit.vaultFeeOracleQuery = indexedexManager;
        pkgInit.vaultRegistryDeployment = indexedexManager;
        pkgInit.permit2 = IPermit2(RobinhoodCanonicalLib.permit2());
        pkgInit.uniswapV3Factory = IUniswapV3Factory(RobinhoodCanonicalLib.v3Factory());

        uniV3SePkg = indexedexManager.deployUniswapV3StandardExchangeDFPkg(pkgInit);
    }

    function _seedSe(address se, address token, uint256 amount) internal {
        IERC20(token).approve(se, type(uint256).max);
        IStandardExchangeIn(se).exchangeIn(
            IERC20(token), amount, IERC20(se), 0, deployer, false, block.timestamp + 1 hours
        );
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("univ3se", "uniV3SePkg", address(uniV3SePkg));
        json = vm.serializeAddress("univ3se", "uniV3Se_tt0_tt1", uniV3Se_tt0_tt1);
        json = vm.serializeAddress("univ3se", "uniV3Se_tt2_tt3", uniV3Se_tt2_tt3);
        json = vm.serializeUint("univ3se", "chainId", block.chainid);
        _writeJson(json, ARTIFACT_FILE);
    }

    function _logResults() internal view {
        _logAddress("uniV3SePkg:", address(uniV3SePkg));
        _logAddress("uniV3Se_tt0_tt1:", uniV3Se_tt0_tt1);
        _logComplete("Stage 07");
    }
}
