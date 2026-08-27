// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {
    IUniswapV3StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeDFPkg.sol";
import {
    UniswapV3_Component_FactoryService
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3_Component_FactoryService.sol";

/// @title Script_05_DeployUniV3SeOnRichPool
/// @notice Uni V3 SE DFPkg + vault on pons RICH/WETH pool.
/// @dev Do not seed SE inventory here — stage 10 market buy moves the mid; pre-buy seed leaves
///      managed ticks out-of-range and later exchangeIn/bond hits _depositQuote div-by-zero.
///      First bond (stage 11) funds the empty SE at the post-buy mid.
contract Script_05_DeployUniV3SeOnRichPool is DeploymentBase {
    using UniswapV3_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV3_Component_FactoryService for IIndexedexManagerProxy;

    string internal constant CRANE_FOUNDATION_FILE = "01_crane_foundation.json";
    string internal constant CORE_FILE = "02_indexedex_core.json";
    string internal constant PONS_FILE = "04_pons_rich.json";
    string internal constant ARTIFACT_FILE = "05_univ3_se_rich.json";

    ICreate3FactoryProxy private create3Factory;
    IIndexedexManagerProxy private indexedexManager;
    IFacet private erc20Facet;
    IFacet private erc2612Facet;
    IFacet private erc5267Facet;
    IFacet private multiAssetBasicVaultFacet;
    IFacet private multiAssetStandardVaultFacet;

    IUniswapV3StandardExchangeDFPkg private uniV3SePkg;
    address private uniV3Se_rich;
    address private rich;
    address private pool;
    address private weth;

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        RobinhoodCanonicalLib.requireCanonicalPins();
        _loadPrior();
        _logHeader("Stage 05: Uni V3 SE on RICH/WETH pool");

        if (_loadExisting()) {
            _exportJson();
            _logResults();
            return;
        }

        vm.startBroadcast();
        _deployPkg();
        uniV3Se_rich = address(IStandardExchangeProxy(uniV3SePkg.deployVault(IUniswapV3Pool(pool))));
        vm.label(uniV3Se_rich, "uniV3Se_rich");
        vm.stopBroadcast();

        _assertVaultTokens();

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
        rich = _readAddress(PONS_FILE, "rich");
        pool = _readAddress(PONS_FILE, "pool");
        weth = RobinhoodCanonicalLib.weth();
        require(rich != address(0) && pool != address(0), "missing pons RICH/pool - run stage 04");
    }

    function _loadExisting() internal returns (bool) {
        if (_force()) return false;
        (address pkg, bool okPkg) = _readAddressSafe(ARTIFACT_FILE, "uniV3SePkg");
        (address se, bool okSe) = _readAddressSafe(ARTIFACT_FILE, "uniV3Se_rich");
        if (!okPkg || !okSe || pkg.code.length == 0 || se.code.length == 0) return false;
        uniV3SePkg = IUniswapV3StandardExchangeDFPkg(pkg);
        uniV3Se_rich = se;
        return true;
    }

    function _deployPkg() internal {
        IFacet inFacet = create3Factory.deployUniswapV3StandardExchangeInFacet();
        IFacet inQueryFacet = create3Factory.deployUniswapV3StandardExchangeInQueryFacet();
        IFacet outFacet = create3Factory.deployUniswapV3StandardExchangeOutFacet();
        IFacet outQueryFacet = create3Factory.deployUniswapV3StandardExchangeOutQueryFacet();
        IFacet posImportFacet = create3Factory.deployUniswapV3StandardExchangePositionImportFacet();
        IFacet liquidReserveFacet = create3Factory.deployUniswapV3StandardExchangeLiquidReserveFacet();
        IFacet inMultiFacet = create3Factory.deployUniswapV3StandardExchangeInMultiFacet();
        IFacet inMultiQueryFacet = create3Factory.deployUniswapV3StandardExchangeInMultiQueryFacet();
        IFacet outMultiFacet = create3Factory.deployUniswapV3StandardExchangeOutMultiFacet();
        IFacet outMultiQueryFacet = create3Factory.deployUniswapV3StandardExchangeOutMultiQueryFacet();

        IUniswapV3StandardExchangeDFPkg.PkgInit memory pkgInit;
        pkgInit.erc20Facet = erc20Facet;
        pkgInit.erc5267Facet = erc5267Facet;
        pkgInit.erc2612Facet = erc2612Facet;
        pkgInit.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        pkgInit.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        pkgInit.uniswapV3StandardExchangeInFacet = inFacet;
        pkgInit.uniswapV3StandardExchangeInQueryFacet = inQueryFacet;
        pkgInit.uniswapV3StandardExchangeOutFacet = outFacet;
        pkgInit.uniswapV3StandardExchangeOutQueryFacet = outQueryFacet;
        pkgInit.uniswapV3StandardExchangePositionImportFacet = posImportFacet;
        pkgInit.uniswapV3StandardExchangeLiquidReserveFacet = liquidReserveFacet;
        pkgInit = UniswapV3_Component_FactoryService.attachUniswapV3StandardExchangeMultiFacets(
            pkgInit, inMultiFacet, inMultiQueryFacet, outMultiFacet, outMultiQueryFacet
        );
        pkgInit.vaultFeeOracleQuery = indexedexManager;
        pkgInit.vaultRegistryDeployment = indexedexManager;
        pkgInit.permit2 = IPermit2(RobinhoodCanonicalLib.permit2());
        pkgInit.uniswapV3Factory = IUniswapV3Factory(RobinhoodCanonicalLib.v3Factory());

        uniV3SePkg = indexedexManager.deployUniswapV3StandardExchangeDFPkg(pkgInit);
    }

    function _assertVaultTokens() internal view {
        address[] memory tokens = IBasicVault(uniV3Se_rich).vaultTokens();
        bool hasWeth;
        bool hasRich;
        for (uint256 i; i < tokens.length; ++i) {
            if (tokens[i] == weth) hasWeth = true;
            if (tokens[i] == rich) hasRich = true;
        }
        require(hasWeth && hasRich, "uniV3Se vaultTokens must contain WETH and RICH");
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("univ3se", "uniV3SePkg", address(uniV3SePkg));
        json = vm.serializeAddress("univ3se", "uniV3Se_rich", uniV3Se_rich);
        json = vm.serializeAddress("univ3se", "rich", rich);
        json = vm.serializeAddress("univ3se", "pool", pool);
        json = vm.serializeAddress("univ3se", "weth", weth);
        json = vm.serializeUint("univ3se", "chainId", block.chainid);
        _writeJson(json, ARTIFACT_FILE);
    }

    function _logResults() internal view {
        _logAddress("uniV3SePkg:", address(uniV3SePkg));
        _logAddress("uniV3Se_rich:", uniV3Se_rich);
        _logComplete("Stage 05");
    }
}
