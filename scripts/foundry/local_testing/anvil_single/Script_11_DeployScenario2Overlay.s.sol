// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LocalTestingDeploymentBase} from "../shared/LocalTestingDeploymentBase.sol";
import {ManifestEntry} from "../shared/ManifestEntry.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TokenConfig, TokenType} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeRateProviderDFPkg} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";
import {IBalancerV3ConstantProductPoolStandardVaultPkg} from "contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPoolStandardVaultPkg.sol";

/// @title Script_11_DeployScenario2Overlay
/// @notice Deploys Scenario 2: rate providers and Balancer const-prod pools on top of Scenario 1 UniV2 vaults.
///         - Pool 1 pairs TTA with the UniV2 TTA/TTB vault token rated in TTB.
///         - Pool 2 pairs TTB with the UniV2 TTB/WETH vault token rated in WETH.
contract Script_11_DeployScenario2Overlay is LocalTestingDeploymentBase {
    string internal constant PROTOCOLS_BASE_FILE = "03_protocols_base.json";
    string internal constant FOUNDATION_PACKAGES_FILE = "05_foundation_packages.json";
    string internal constant FOUNDATION_ASSETS_FILE = "06_foundation_assets.json";
    string internal constant SCENARIO_1_FILE = "10_scenario_1.json";
    string internal constant ARTIFACT_FILE = "11_scenario_2.json";

    IStandardExchangeRateProviderDFPkg private rateProviderPkg;
    IBalancerV3ConstantProductPoolStandardVaultPkg private balConstProdPkg;

    address private ttA;
    address private ttB;
    address private weth;
    address private abVault;
    address private bWethVault;

    address private uniAbRpB;
    address private uniBWethRpWeth;
    address private balUniAbWithA;
    address private balUniBWethWithB;

    function run() external {
        _loadConfig();
        _loadDependencies();

        _logHeader("Stage 11: Deploy Scenario 2 Overlay");

        if (_loadExistingScenario()) {
            _exportJson();
            _logResults();
            return;
        }

        vm.startBroadcast();
        _deployRateProviders();
        _deployPools();
        vm.stopBroadcast();

        _exportJson();
        _exportFragments();
        _logResults();
    }

    function _loadDependencies() internal {
        rateProviderPkg = IStandardExchangeRateProviderDFPkg(_readAddress(FOUNDATION_PACKAGES_FILE, "rateProviderPkg"));
        balConstProdPkg = IBalancerV3ConstantProductPoolStandardVaultPkg(
            _readAddress(FOUNDATION_PACKAGES_FILE, "balancerV3ConstantProductPoolStandardVaultPkg")
        );
        ttA = _readAddress(FOUNDATION_ASSETS_FILE, "testTokenA");
        ttB = _readAddress(FOUNDATION_ASSETS_FILE, "testTokenB");
        weth = _readAddress(PROTOCOLS_BASE_FILE, "weth");
        abVault = _readAddress(SCENARIO_1_FILE, "uniV2AbVault");
        bWethVault = _readAddress(SCENARIO_1_FILE, "uniV2BWethVault");

        require(address(rateProviderPkg) != address(0), "Rate provider pkg not found - run Script_05 first");
        require(address(balConstProdPkg) != address(0), "Balancer const-prod pkg not found - run Script_05 first");
        require(ttA != address(0), "Test Token A not found - run Script_06 first");
        require(ttB != address(0), "Test Token B not found - run Script_06 first");
        require(weth != address(0), "WETH not found - run Script_03 first");
        require(abVault != address(0) && bWethVault != address(0), "Scenario 1 vaults not found - run Script_10 first");
    }

    function _loadExistingScenario() internal returns (bool) {
        (address abRp, bool hasAbRp) = _readAddressSafe(ARTIFACT_FILE, "uniV2AbRpB");
        (address bWethRp, bool hasBWethRp) = _readAddressSafe(ARTIFACT_FILE, "uniV2BWethRpWeth");
        (address abPool, bool hasAbPool) = _readAddressSafe(ARTIFACT_FILE, "balUniAbWithA");
        (address bWethPool, bool hasBWethPool) = _readAddressSafe(ARTIFACT_FILE, "balUniBWethWithB");

        if (!hasAbRp || !hasBWethRp || !hasAbPool || !hasBWethPool) {
            return false;
        }

        if (abRp.code.length == 0 || bWethRp.code.length == 0 || abPool.code.length == 0 || bWethPool.code.length == 0) {
            return false;
        }

        uniAbRpB = abRp;
        uniBWethRpWeth = bWethRp;
        balUniAbWithA = abPool;
        balUniBWethWithB = bWethPool;
        return true;
    }

    function _standardTokenConfig(address token) internal pure returns (TokenConfig memory cfg) {
        cfg = TokenConfig({
            token: IERC20(token),
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });
    }

    function _vaultTokenConfig(address vaultToken, address rateProvider) internal pure returns (TokenConfig memory cfg) {
        cfg = TokenConfig({
            token: IERC20(vaultToken),
            tokenType: TokenType.WITH_RATE,
            rateProvider: IRateProvider(rateProvider),
            paysYieldFees: false
        });
    }

    function _deployRateProviders() internal {
        uniAbRpB = address(rateProviderPkg.deployRateProvider(IStandardExchange(abVault), IERC20(ttB)));
        uniBWethRpWeth = address(rateProviderPkg.deployRateProvider(IStandardExchange(bWethVault), IERC20(weth)));
    }

    function _deployPool(address underlyingToken, address vaultToken, address vaultTokenRateProvider)
        internal
        returns (address pool)
    {
        TokenConfig[] memory cfg = new TokenConfig[](2);
        cfg[0] = _standardTokenConfig(underlyingToken);
        cfg[1] = _vaultTokenConfig(vaultToken, vaultTokenRateProvider);
        pool = balConstProdPkg.deployVault(cfg, address(0));
    }

    function _deployPools() internal {
        balUniAbWithA = _deployPool(ttA, abVault, uniAbRpB);
        balUniBWethWithB = _deployPool(ttB, bWethVault, uniBWethRpWeth);
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("scenario2", "testTokenA", ttA);
        json = vm.serializeAddress("scenario2", "testTokenB", ttB);
        json = vm.serializeAddress("scenario2", "weth", weth);
        json = vm.serializeAddress("scenario2", "uniV2AbVault", abVault);
        json = vm.serializeAddress("scenario2", "uniV2BWethVault", bWethVault);
        json = vm.serializeAddress("scenario2", "uniV2AbRpB", uniAbRpB);
        json = vm.serializeAddress("scenario2", "uniV2BWethRpWeth", uniBWethRpWeth);
        json = vm.serializeAddress("scenario2", "balUniAbWithA", balUniAbWithA);
        json = vm.serializeAddress("scenario2", "balUniBWethWithB", balUniBWethWithB);
        json = vm.serializeAddress("scenario2", "owner", owner);
        json = vm.serializeAddress("scenario2", "deployer", deployer);
        json = vm.serializeUint("scenario2", "chainId", block.chainid);
        json = vm.serializeString("scenario2", "networkProfile", _networkProfile());
        _writeJson(json, ARTIFACT_FILE);
    }

    function _exportFragments() internal {
        _writeBalancerPoolFragment(
            "balUniAbWithA",
            balUniAbWithA,
            "Balancer TTA + UniV2 AB Vault",
            "balUniAbA"
        );
        _writeBalancerPoolFragment(
            "balUniBWethWithB",
            balUniBWethWithB,
            "Balancer TTB + UniV2 BWETH Vault",
            "balUniBWethB"
        );
    }

    function _writeBalancerPoolFragment(
        string memory key,
        address poolAddr,
        string memory name,
        string memory symbol
    ) internal {
        if (poolAddr == address(0)) return;
        string[] memory tags = new string[](0);
        ManifestEntry memory entry = ManifestEntry({
            chainId: block.chainid,
            addr: poolAddr,
            name: name,
            symbol: symbol,
            decimals: 18,
            tags: tags
        });
        _writeManifestEntry("pools/balancerV3", key, entry);
    }

    function _logResults() internal view {
        _logString("Artifact:", ARTIFACT_FILE);
        _logAddress("UniV2 A/B Rate Provider targeting TTB:", uniAbRpB);
        _logAddress("UniV2 B/WETH Rate Provider targeting WETH:", uniBWethRpWeth);
        _logAddress("Balancer Pool TTA + UniV2 A/B Vault:", balUniAbWithA);
        _logAddress("Balancer Pool TTB + UniV2 B/WETH Vault:", balUniBWethWithB);
        _logComplete("Stage 11");
    }
}