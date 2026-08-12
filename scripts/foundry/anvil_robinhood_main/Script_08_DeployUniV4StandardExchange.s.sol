// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {FixtureGraph} from "./FixtureGraph.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";

import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IUniswapV4StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";
import {
    UniswapV4_Component_FactoryService
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol";
import {
    IUniswapV4StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserve.sol";

/// @title Script_08_DeployUniV4StandardExchange
/// @notice Deploy Uni V4 SE DFPkg on RH PoolManager + vault instances for TT4/TT5 and TT6/TT7.
contract Script_08_DeployUniV4StandardExchange is DeploymentBase {
    using UniswapV4_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV4_Component_FactoryService for IFacet;
    using UniswapV4_Component_FactoryService for IIndexedexManagerProxy;

    uint256 internal constant DEFAULT_V4_LIQUID_RESERVE_PCT = 0.2e18;

    string internal constant CRANE_FOUNDATION_FILE = "01_crane_foundation.json";
    string internal constant CORE_FILE = "02_indexedex_core.json";
    string internal constant TOKENS_FILE = "04_test_tokens.json";
    string internal constant ARTIFACT_FILE = "08_univ4_se.json";

    ICreate3FactoryProxy private create3Factory;
    IIndexedexManagerProxy private indexedexManager;
    IFacet private erc20Facet;
    IFacet private erc2612Facet;
    IFacet private erc5267Facet;
    IFacet private multiAssetBasicVaultFacet;
    IFacet private multiAssetStandardVaultFacet;

    IUniswapV4StandardExchangeDFPkg private uniV4SePkg;
    address private uniV4Se_tt4_tt5;
    address private uniV4Se_tt6_tt7;

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        RobinhoodCanonicalLib.requireCanonicalPins();
        _loadPrior();
        _logHeader("Stage 08: Uni V4 Standard Exchange");

        if (_loadExisting()) {
            _exportJson();
            _logResults();
            return;
        }

        address tt4 = _readAddress(TOKENS_FILE, "tt4");
        address tt5 = _readAddress(TOKENS_FILE, "tt5");
        address tt6 = _readAddress(TOKENS_FILE, "tt6");
        address tt7 = _readAddress(TOKENS_FILE, "tt7");

        PoolKey memory keyA = _buildKey(tt4, tt5);
        PoolKey memory keyB = _buildKey(tt6, tt7);

        vm.startBroadcast();
        _deployPkg();

        uniV4Se_tt4_tt5 = address(
            IStandardExchangeProxy(uniV4SePkg.deployVault(keyA, FixtureGraph.V4_SE_WIDTH_MULTIPLIER))
        );
        uniV4Se_tt6_tt7 = address(
            IStandardExchangeProxy(uniV4SePkg.deployVault(keyB, FixtureGraph.V4_SE_WIDTH_MULTIPLIER))
        );
        vm.label(uniV4Se_tt4_tt5, "uniV4Se_tt4_tt5");
        vm.label(uniV4Se_tt6_tt7, "uniV4Se_tt6_tt7");

        _seedSe(uniV4Se_tt4_tt5, tt4, 100_000e18);
        _seedSe(uniV4Se_tt4_tt5, tt5, 100_000e18);
        vm.stopBroadcast();

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
        (address pkg, bool okPkg) = _readAddressSafe(ARTIFACT_FILE, "uniV4SePkg");
        (address seA, bool okA) = _readAddressSafe(ARTIFACT_FILE, "uniV4Se_tt4_tt5");
        if (!okPkg || !okA || pkg.code.length == 0 || seA.code.length == 0) return false;
        uniV4SePkg = IUniswapV4StandardExchangeDFPkg(pkg);
        uniV4Se_tt4_tt5 = seA;
        (address seB, bool okB) = _readAddressSafe(ARTIFACT_FILE, "uniV4Se_tt6_tt7");
        if (okB) uniV4Se_tt6_tt7 = seB;
        return true;
    }

    function _deployPkg() internal {
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentageOfTypeId(
            type(IUniswapV4StandardExchangeLiquidReserve).interfaceId, DEFAULT_V4_LIQUID_RESERVE_PCT
        );

        // Sequential field writes avoid stack-too-deep (no via_ir).
        IUniswapV4StandardExchangeDFPkg.PkgInit memory pkgInit;
        pkgInit.erc20Facet = erc20Facet;
        pkgInit.erc5267Facet = erc5267Facet;
        pkgInit.erc2612Facet = erc2612Facet;
        pkgInit.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        pkgInit.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        pkgInit.uniswapV4StandardExchangeInFacet = create3Factory.deployUniswapV4StandardExchangeInFacet();
        pkgInit.uniswapV4StandardExchangeInQueryFacet = create3Factory.deployUniswapV4StandardExchangeInQueryFacet();
        pkgInit.uniswapV4StandardExchangePositionImportFacet =
            create3Factory.deployUniswapV4StandardExchangePositionImportFacet();
        pkgInit.uniswapV4StandardExchangeOutFacet = create3Factory.deployUniswapV4StandardExchangeOutFacet();
        pkgInit.uniswapV4StandardExchangeOutQueryFacet = create3Factory.deployUniswapV4StandardExchangeOutQueryFacet();
        pkgInit.uniswapV4StandardExchangeLiquidReserveFacet =
            create3Factory.deployUniswapV4StandardExchangeLiquidReserveFacet();
        pkgInit.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(indexedexManager));
        pkgInit.vaultRegistryDeployment = IVaultRegistryDeployment(address(indexedexManager));
        pkgInit.permit2 = IPermit2(RobinhoodCanonicalLib.permit2());
        pkgInit.poolManager = IPoolManager(RobinhoodCanonicalLib.poolManager());

        uniV4SePkg = indexedexManager.deployUniswapV4StandardExchangeDFPkg(pkgInit);
    }

    function _buildKey(address a, address b) internal pure returns (PoolKey memory key) {
        (address token0, address token1) = a < b ? (a, b) : (b, a);
        key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: FixtureGraph.V4_POOL_FEE,
            tickSpacing: FixtureGraph.V4_TICK_SPACING,
            hooks: IHooks(address(0))
        });
    }

    function _seedSe(address se, address token, uint256 amount) internal {
        IERC20(token).approve(se, type(uint256).max);
        IStandardExchangeIn(se).exchangeIn(
            IERC20(token), amount, IERC20(se), 0, deployer, false, block.timestamp + 1 hours
        );
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("univ4se", "uniV4SePkg", address(uniV4SePkg));
        json = vm.serializeAddress("univ4se", "uniV4Se_tt4_tt5", uniV4Se_tt4_tt5);
        json = vm.serializeAddress("univ4se", "uniV4Se_tt6_tt7", uniV4Se_tt6_tt7);
        json = vm.serializeAddress("univ4se", "poolManager", RobinhoodCanonicalLib.poolManager());
        json = vm.serializeUint("univ4se", "chainId", block.chainid);
        _writeJson(json, ARTIFACT_FILE);
    }

    function _logResults() internal view {
        _logAddress("uniV4SePkg:", address(uniV4SePkg));
        _logAddress("uniV4Se_tt4_tt5:", uniV4Se_tt4_tt5);
        _logComplete("Stage 08");
    }
}
