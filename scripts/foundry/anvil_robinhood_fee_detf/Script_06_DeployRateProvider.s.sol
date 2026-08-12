// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {
    StandardExchangeRateProvider_FactoryService
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProvider_FactoryService.sol";
import {
    IStandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";

/// @title Script_06_DeployRateProvider
/// @notice SE share -> WETH rate provider for optional oracle paths (CP DETF does not require RP in PkgArgs).
contract Script_06_DeployRateProvider is DeploymentBase {
    using StandardExchangeRateProvider_FactoryService for ICreate3FactoryProxy;

    string internal constant CRANE_FOUNDATION_FILE = "01_crane_foundation.json";
    string internal constant SE_FILE = "05_univ3_se_rich.json";
    string internal constant ARTIFACT_FILE = "06_rate_provider.json";

    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;
    IStandardExchangeRateProviderDFPkg private rateProviderPkg;
    address private rp_se_rich_weth;
    address private uniV3Se_rich;
    address private weth;

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        _loadPrior();
        _logHeader("Stage 06: Rate provider (SE shares -> WETH)");

        if (_loadExisting()) {
            _exportJson();
            _logResults();
            return;
        }

        vm.startBroadcast();
        IFacet rateProviderFacet = create3Factory.deployStandardExchangeRateProviderFacet();
        rateProviderPkg = create3Factory.deployStandardExchangeRateProviderDFPkg(
            rateProviderFacet, diamondPackageFactory
        );
        rp_se_rich_weth = address(
            rateProviderPkg.deployRateProvider(IStandardExchange(uniV3Se_rich), IERC20(weth))
        );
        vm.label(rp_se_rich_weth, "rp_se_rich_weth");
        vm.stopBroadcast();

        // SE is intentionally empty until first bond / post-buy seed — rate may be 0.
        try IRateProvider(rp_se_rich_weth).getRate() returns (uint256 rate) {
            _logUint("rp_se_rich_weth getRate (0 ok if SE empty):", rate);
        } catch {
            _logString("rp_se_rich_weth getRate:", "call failed (SE empty expected pre-bond)");
        }

        _exportJson();
        _logResults();
    }

    function _loadPrior() internal {
        create3Factory = ICreate3FactoryProxy(_readAddress(CRANE_FOUNDATION_FILE, "create3Factory"));
        diamondPackageFactory =
            IDiamondPackageCallBackFactory(_readAddress(CRANE_FOUNDATION_FILE, "diamondPackageFactory"));
        uniV3Se_rich = _readAddress(SE_FILE, "uniV3Se_rich");
        weth = RobinhoodCanonicalLib.weth();
        require(uniV3Se_rich != address(0), "missing uniV3Se_rich");
    }

    function _loadExisting() internal returns (bool) {
        if (_force()) return false;
        (address pkg, bool okPkg) = _readAddressSafe(ARTIFACT_FILE, "rateProviderPkg");
        (address rp, bool okRp) = _readAddressSafe(ARTIFACT_FILE, "rp_se_rich_weth");
        if (!okPkg || !okRp || pkg.code.length == 0 || rp.code.length == 0) return false;
        rateProviderPkg = IStandardExchangeRateProviderDFPkg(pkg);
        rp_se_rich_weth = rp;
        return true;
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("rp", "rateProviderPkg", address(rateProviderPkg));
        json = vm.serializeAddress("rp", "rp_se_rich_weth", rp_se_rich_weth);
        json = vm.serializeAddress("rp", "uniV3Se_rich", uniV3Se_rich);
        json = vm.serializeAddress("rp", "weth", weth);
        json = vm.serializeUint("rp", "chainId", block.chainid);
        json = vm.serializeString("rp", "notes", "SE shares -> WETH; optional for CP fee-DETF");
        _writeJson(json, ARTIFACT_FILE);
    }

    function _logResults() internal view {
        _logAddress("rp_se_rich_weth:", rp_se_rich_weth);
        _logComplete("Stage 06");
    }
}
