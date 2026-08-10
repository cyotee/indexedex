// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";

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

/// @title Script_09_DeployRateProviders
/// @notice SE rate providers for buffered legs (shares → pairToken).
contract Script_09_DeployRateProviders is DeploymentBase {
    using StandardExchangeRateProvider_FactoryService for ICreate3FactoryProxy;

    string internal constant CRANE_FOUNDATION_FILE = "01_crane_foundation.json";
    string internal constant TOKENS_FILE = "04_test_tokens.json";
    string internal constant V3_SE_FILE = "07_univ3_se.json";
    string internal constant V4_SE_FILE = "08_univ4_se.json";
    string internal constant ARTIFACT_FILE = "09_rate_providers.json";

    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;
    IStandardExchangeRateProviderDFPkg private rateProviderPkg;

    address private rp_v3Se_tt0_tt1;
    address private rp_v4Se_tt4_tt5;

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        _loadPrior();
        _logHeader("Stage 09: Rate Providers");

        if (_loadExisting()) {
            _exportJson();
            _logResults();
            return;
        }

        address uniV3Se = _readAddress(V3_SE_FILE, "uniV3Se_tt0_tt1");
        address uniV4Se = _readAddress(V4_SE_FILE, "uniV4Se_tt4_tt5");
        address tt0 = _readAddress(TOKENS_FILE, "tt0");
        address tt4 = _readAddress(TOKENS_FILE, "tt4");

        vm.startBroadcast();
        IFacet rateProviderFacet = create3Factory.deployStandardExchangeRateProviderFacet();
        rateProviderPkg = create3Factory.deployStandardExchangeRateProviderDFPkg(
            rateProviderFacet, diamondPackageFactory
        );

        // RP quotes SE shares → pairToken for Weighted binding
        rp_v3Se_tt0_tt1 = address(
            rateProviderPkg.deployRateProvider(IStandardExchange(uniV3Se), IERC20(tt0))
        );
        rp_v4Se_tt4_tt5 = address(
            rateProviderPkg.deployRateProvider(IStandardExchange(uniV4Se), IERC20(tt4))
        );
        vm.label(rp_v3Se_tt0_tt1, "rp_v3Se_tt0_tt1");
        vm.label(rp_v4Se_tt4_tt5, "rp_v4Se_tt4_tt5");
        vm.stopBroadcast();

        // D14: rate must be live (shares → pairToken preview works). Fail stage if zero.
        uint256 rateV3 = IRateProvider(rp_v3Se_tt0_tt1).getRate();
        uint256 rateV4 = IRateProvider(rp_v4Se_tt4_tt5).getRate();
        require(rateV3 > 0, "D14: V3 SE rate provider getRate()==0");
        require(rateV4 > 0, "D14: V4 SE rate provider getRate()==0");
        _logUint("rp_v3Se_tt0_tt1 getRate:", rateV3);
        _logUint("rp_v4Se_tt4_tt5 getRate:", rateV4);

        _exportJson();
        _logResults();
    }

    function _loadPrior() internal {
        create3Factory = ICreate3FactoryProxy(_readAddress(CRANE_FOUNDATION_FILE, "create3Factory"));
        diamondPackageFactory =
            IDiamondPackageCallBackFactory(_readAddress(CRANE_FOUNDATION_FILE, "diamondPackageFactory"));
    }

    function _loadExisting() internal returns (bool) {
        (address pkg, bool okPkg) = _readAddressSafe(ARTIFACT_FILE, "rateProviderPkg");
        (address rpA, bool okA) = _readAddressSafe(ARTIFACT_FILE, "rp_v3Se_tt0_tt1");
        (address rpB, bool okB) = _readAddressSafe(ARTIFACT_FILE, "rp_v4Se_tt4_tt5");
        if (!okPkg || !okA || !okB || pkg.code.length == 0 || rpA.code.length == 0 || rpB.code.length == 0) {
            return false;
        }
        rateProviderPkg = IStandardExchangeRateProviderDFPkg(pkg);
        rp_v3Se_tt0_tt1 = rpA;
        rp_v4Se_tt4_tt5 = rpB;
        return true;
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("rp", "rateProviderPkg", address(rateProviderPkg));
        json = vm.serializeAddress("rp", "rp_v3Se_tt0_tt1", rp_v3Se_tt0_tt1);
        json = vm.serializeAddress("rp", "rp_v4Se_tt4_tt5", rp_v4Se_tt4_tt5);
        json = vm.serializeUint("rp", "chainId", block.chainid);
        json = vm.serializeString("rp", "notes", "V3 SE RP targets TT0; V4 SE RP targets TT4");
        _writeJson(json, ARTIFACT_FILE);
    }

    function _logResults() internal view {
        _logAddress("rp_v3Se_tt0_tt1:", rp_v3Se_tt0_tt1);
        _logAddress("rp_v4Se_tt4_tt5:", rp_v4Se_tt4_tt5);
        _logComplete("Stage 09");
    }
}
