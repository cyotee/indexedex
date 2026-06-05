// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";

/* -------------------------------------------------------------------------- */
/*                                OpenZeppelin                                */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {TokenConfig, TokenType} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IBalancerV3ConstantProductPoolStandardVaultPkg} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPoolStandardVaultPkg.sol";

/// @title Script_12_DeployBalancerConstProdVaultTokenPools
/// @notice Deploys Balancer V3 constant-product pools:
///         1. Token-only pools (AB/AC/BC) - first time in anvil_sepolia
///         2. UniV2 vault-token pools (combining test token + vault)
/// @dev Note: In anvil_sepolia, Aerodrome vaults are not yet deployed, so we only deploy
///         UniV2 vault-token pools. Aerodrome would require additional vault deployment stage.
/// @dev Run:
///      forge script scripts/foundry/anvil_sepolia/Script_12_DeployBalancerConstProdVaultTokenPools.s.sol \
///        --rpc-url http://127.0.0.1:8545 --broadcast --unlocked --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 -vvv
contract Script_12_DeployBalancerConstProdVaultTokenPools is DeploymentBase {
    /* ---------------------------------------------------------------------- */
    /*                                  Inputs                                */
    /* ---------------------------------------------------------------------- */

    IBalancerV3ConstantProductPoolStandardVaultPkg private balConstProdPkg;

    // Underlying test tokens
    address private ttA;
    address private ttB;
    address private ttC;

    // UniV2 Standard Exchange vaults
    address private abVault;
    address private acVault;
    address private bcVault;

    // Rate providers for UniV2 vaults
    address private uniAbRpA;
    address private uniAbRpB;
    address private uniAcRpA;
    address private uniAcRpC;
    address private uniBcRpB;
    address private uniBcRpC;

    /* ---------------------------------------------------------------------- */
    /*                                 Outputs                                */
    /* ---------------------------------------------------------------------- */

    // Balancer const-prod token-only pools
    address private balancerAbPool;
    address private balancerAcPool;
    address private balancerBcPool;

    // UniV2 vault-token pools
    address private balUniAbWithA;
    address private balUniAbWithB;
    address private balUniAcWithA;
    address private balUniAcWithC;
    address private balUniBcWithB;
    address private balUniBcWithC;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 12: Deploy Balancer V3 ConstProd Pools");

        vm.startBroadcast();
        _deployTokenOnlyPools();
        _deployVaultTokenPools();
        vm.stopBroadcast();

        _exportJson();
        _exportTokenlist();
        _exportSummary();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        balConstProdPkg = IBalancerV3ConstantProductPoolStandardVaultPkg(
            _readAddress("04_balancer_v3.json", "balancerV3ConstantProductPoolStandardVaultPkg")
        );
        require(address(balConstProdPkg) != address(0), "Balancer const-prod pkg not found");

        ttA = _readAddress("07_test_tokens.json", "testTokenA");
        ttB = _readAddress("07_test_tokens.json", "testTokenB");
        ttC = _readAddress("07_test_tokens.json", "testTokenC");
        require(ttA != address(0) && ttB != address(0) && ttC != address(0), "Test tokens not found");

        abVault = _readAddress("09_strategy_vaults.json", "abVault");
        acVault = _readAddress("09_strategy_vaults.json", "acVault");
        bcVault = _readAddress("09_strategy_vaults.json", "bcVault");
        require(abVault != address(0) && acVault != address(0) && bcVault != address(0), "UniV2 vaults not found");

        uniAbRpA = _readAddress("11_standard_exchange_rate_providers.json", "uniAbRpA");
        uniAbRpB = _readAddress("11_standard_exchange_rate_providers.json", "uniAbRpB");
        uniAcRpA = _readAddress("11_standard_exchange_rate_providers.json", "uniAcRpA");
        uniAcRpC = _readAddress("11_standard_exchange_rate_providers.json", "uniAcRpC");
        uniBcRpB = _readAddress("11_standard_exchange_rate_providers.json", "uniBcRpB");
        uniBcRpC = _readAddress("11_standard_exchange_rate_providers.json", "uniBcRpC");

        require(
            uniAbRpA != address(0) && uniAbRpB != address(0) && uniAcRpA != address(0) && uniAcRpC != address(0)
                && uniBcRpB != address(0) && uniBcRpC != address(0),
            "UniV2 rate providers not found"
        );
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

    function _deployTokenOnlyPool(address token0, address token1) internal returns (address pool) {
        TokenConfig[] memory cfg = new TokenConfig[](2);
        cfg[0] = _standardTokenConfig(token0);
        cfg[1] = _standardTokenConfig(token1);
        pool = balConstProdPkg.deployVault(cfg, address(0));
    }

    function _deployVaultTokenPool(address underlyingToken, address vaultToken, address vaultTokenRateProvider)
        internal
        returns (address pool)
    {
        TokenConfig[] memory cfg = new TokenConfig[](2);
        cfg[0] = _standardTokenConfig(underlyingToken);
        cfg[1] = _vaultTokenConfig(vaultToken, vaultTokenRateProvider);
        pool = balConstProdPkg.deployVault(cfg, address(0));
    }

    function _deployTokenOnlyPools() internal {
        // AB: balanced (1:1)
        balancerAbPool = _deployTokenOnlyPool(ttA, ttB);
        // AC: unbalanced (10:1)
        balancerAcPool = _deployTokenOnlyPool(ttA, ttC);
        // BC: extreme unbalanced (100:1)
        balancerBcPool = _deployTokenOnlyPool(ttB, ttC);

        vm.label(balancerAbPool, "Balancer ConstProd AB Pool (token-only)");
        vm.label(balancerAcPool, "Balancer ConstProd AC Pool (token-only)");
        vm.label(balancerBcPool, "Balancer ConstProd BC Pool (token-only)");
    }

    function _deployVaultTokenPools() internal {
        // UniV2: AB
        // - pool(ttA, abVault) where abVault is WITH_RATE quoted in ttB (opposing)
        balUniAbWithA = _deployVaultTokenPool(ttA, abVault, uniAbRpB);
        // - pool(ttB, abVault) where abVault is WITH_RATE quoted in ttA (opposing)
        balUniAbWithB = _deployVaultTokenPool(ttB, abVault, uniAbRpA);

        // UniV2: AC
        balUniAcWithA = _deployVaultTokenPool(ttA, acVault, uniAcRpC);
        balUniAcWithC = _deployVaultTokenPool(ttC, acVault, uniAcRpA);

        // UniV2: BC
        balUniBcWithB = _deployVaultTokenPool(ttB, bcVault, uniBcRpC);
        balUniBcWithC = _deployVaultTokenPool(ttC, bcVault, uniBcRpB);

        vm.label(balUniAbWithA, "Balancer UniV2 AB vault + ttA");
        vm.label(balUniAbWithB, "Balancer UniV2 AB vault + ttB");
        vm.label(balUniAcWithA, "Balancer UniV2 AC vault + ttA");
        vm.label(balUniAcWithC, "Balancer UniV2 AC vault + ttC");
        vm.label(balUniBcWithB, "Balancer UniV2 BC vault + ttB");
        vm.label(balUniBcWithC, "Balancer UniV2 BC vault + ttC");
    }

    function _exportJson() internal {
        string memory json;

        json = vm.serializeAddress("", "balancerV3ConstantProductPoolStandardVaultPkg", address(balConstProdPkg));

        // Token-only pools
        json = vm.serializeAddress("", "balancerAbPool", balancerAbPool);
        json = vm.serializeAddress("", "balancerAcPool", balancerAcPool);
        json = vm.serializeAddress("", "balancerBcPool", balancerBcPool);

        // UniV2 vault-token pools
        json = vm.serializeAddress("", "balUniAbWithA", balUniAbWithA);
        json = vm.serializeAddress("", "balUniAbWithB", balUniAbWithB);
        json = vm.serializeAddress("", "balUniAcWithA", balUniAcWithA);
        json = vm.serializeAddress("", "balUniAcWithC", balUniAcWithC);
        json = vm.serializeAddress("", "balUniBcWithB", balUniBcWithB);
        json = vm.serializeAddress("", "balUniBcWithC", balUniBcWithC);

        _writeJson(json, "12_balancer_const_prod_vault_token_pools.json");
    }

    function _tokenlistEntry(string memory chainIdStr, address pool, string memory name, string memory symbol)
        internal
        view
        returns (string memory)
    {
        string memory resolvedName = _escapeJsonString(_safeName(pool, name));
        return string.concat(
            "  {\n",
            "    \"chainId\": ",
            chainIdStr,
            ",\n",
            "    \"address\": \"",
            vm.toString(pool),
            "\",\n",
            "    \"name\": \"",
            resolvedName,
            "\",\n",
            "    \"symbol\": \"",
            symbol,
            "\",\n",
            "    \"decimals\": 18\n",
            "  }"
        );
    }

    function _safeName(address token, string memory fallbackName) internal view returns (string memory) {
        if (token.code.length == 0) return fallbackName;
        try IERC20Metadata(token).name() returns (string memory n) {
            if (bytes(n).length > 0) return n;
        } catch {}
        return fallbackName;
    }

    function _escapeJsonString(string memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        bytes memory out;
        for (uint256 i = 0; i < b.length; i++) {
            uint8 c = uint8(b[i]);

            if (c == uint8(bytes1('"'))) {
                out = bytes.concat(out, bytes("\\\""));
            } else if (c == uint8(bytes1('\\'))) {
                out = bytes.concat(out, bytes("\\\\"));
            } else if (c == 0x08) {
                out = bytes.concat(out, bytes("\\b"));
            } else if (c == 0x0C) {
                out = bytes.concat(out, bytes("\\f"));
            } else if (c == 0x0A) {
                out = bytes.concat(out, bytes("\\n"));
            } else if (c == 0x0D) {
                out = bytes.concat(out, bytes("\\r"));
            } else if (c == 0x09) {
                out = bytes.concat(out, bytes("\\t"));
            } else if (c < 0x20) {
                out = bytes.concat(out, bytes(_escapeControl(c)));
            } else {
                out = bytes.concat(out, bytes1(bytes1(c)));
            }
        }
        return string(out);
    }

    function _escapeControl(uint8 c) internal pure returns (string memory) {
        bytes memory out = new bytes(6);
        out[0] = bytes1('\\');
        out[1] = bytes1('u');
        out[2] = bytes1('0');
        out[3] = bytes1('0');
        out[4] = _hexChar(c >> 4);
        out[5] = _hexChar(c & 0x0F);
        return string(out);
    }

    function _hexChar(uint8 nibble) internal pure returns (bytes1) {
        return nibble < 10 ? bytes1(nibble + 0x30) : bytes1(nibble + 0x57);
    }

    function _exportTokenlist() internal {
        _ensureOutDir();

        string memory chainIdStr = vm.toString(block.chainid);

        // Avoid stack-too-deep by building the JSON incrementally.
        string memory tokenlist = "[\n";

        // Token-only pools
        tokenlist = string.concat(
            tokenlist,
            _tokenlistEntry(chainIdStr, balancerAbPool, "ab BalancerV3 ConstProd Pool", "abBalancerV3ConstProdPool"),
            ",\n"
        );
        tokenlist = string.concat(
            tokenlist,
            _tokenlistEntry(chainIdStr, balancerAcPool, "ac BalancerV3 ConstProd Pool", "acBalancerV3ConstProdPool"),
            ",\n"
        );
        tokenlist = string.concat(
            tokenlist,
            _tokenlistEntry(chainIdStr, balancerBcPool, "bc BalancerV3 ConstProd Pool", "bcBalancerV3ConstProdPool"),
            ",\n"
        );

        // UniV2 vault-token pools
        tokenlist = string.concat(
            tokenlist,
            _tokenlistEntry(chainIdStr, balUniAbWithA, "UniV2 AB Vault + ttA BalancerV3 Pool", "uniAbVault_ttA_BalancerPool"),
            ",\n"
        );
        tokenlist = string.concat(
            tokenlist,
            _tokenlistEntry(chainIdStr, balUniAbWithB, "UniV2 AB Vault + ttB BalancerV3 Pool", "uniAbVault_ttB_BalancerPool"),
            ",\n"
        );
        tokenlist = string.concat(
            tokenlist,
            _tokenlistEntry(chainIdStr, balUniAcWithA, "UniV2 AC Vault + ttA BalancerV3 Pool", "uniAcVault_ttA_BalancerPool"),
            ",\n"
        );
        tokenlist = string.concat(
            tokenlist,
            _tokenlistEntry(chainIdStr, balUniAcWithC, "UniV2 AC Vault + ttC BalancerV3 Pool", "uniAcVault_ttC_BalancerPool"),
            ",\n"
        );
        tokenlist = string.concat(
            tokenlist,
            _tokenlistEntry(chainIdStr, balUniBcWithB, "UniV2 BC Vault + ttB BalancerV3 Pool", "uniBcVault_ttB_BalancerPool"),
            ",\n"
        );
        tokenlist = string.concat(
            tokenlist,
            _tokenlistEntry(chainIdStr, balUniBcWithC, "UniV2 BC Vault + ttC BalancerV3 Pool", "uniBcVault_ttC_BalancerPool"),
            "\n]\n"
        );

        vm.writeFile(string.concat(OUT_DIR, "/12_balancer_all_pools.tokenlist.json"), tokenlist);
    }

    function _exportSummary() internal {
        string memory json;

        // Factories
        json = vm.serializeAddress("summary", "create3Factory", _readAddress("01_factories.json", "create3Factory"));
        json = vm.serializeAddress(
            "summary",
            "diamondPackageFactory",
            _readAddress("01_factories.json", "diamondPackageFactory")
        );

        // Core
        json = vm.serializeAddress("summary", "feeCollector", _readAddress("03_core_proxies.json", "feeCollector"));
        json = vm.serializeAddress("summary", "indexedexManager", _readAddress("03_core_proxies.json", "indexedexManager"));

        // Packages
        json = vm.serializeAddress("summary", "uniswapV2Pkg", _readAddress("05_uniswap_v2.json", "uniswapV2Pkg"));
        json = vm.serializeAddress("summary", "aerodromePkg", _readAddress("06_aerodrome.json", "aerodromePkg"));
        json = vm.serializeAddress(
            "summary",
            "balancerV3StandardExchangeRouter",
            _readAddress("04_balancer_v3.json", "balancerV3StandardExchangeRouter")
        );
        json = vm.serializeAddress("summary", "balancerV3Router", _readAddress("04_balancer_v3.json", "balancerV3Router"));
        json = vm.serializeAddress("summary", "rateProviderPkg", _readAddress("04_balancer_v3.json", "rateProviderPkg"));
        json = vm.serializeAddress(
            "summary",
            "balancerV3ConstantProductPoolStandardVaultPkg",
            _readAddress("04_balancer_v3.json", "balancerV3ConstantProductPoolStandardVaultPkg")
        );

        // Tokens
        json = vm.serializeAddress("summary", "testTokenA", ttA);
        json = vm.serializeAddress("summary", "testTokenB", ttB);
        json = vm.serializeAddress("summary", "testTokenC", ttC);

        // UniV2 pools + vaults
        json = vm.serializeAddress("summary", "abPool", _readAddress("08_pools.json", "abPool"));
        json = vm.serializeAddress("summary", "acPool", _readAddress("08_pools.json", "acPool"));
        json = vm.serializeAddress("summary", "bcPool", _readAddress("08_pools.json", "bcPool"));

        json = vm.serializeAddress("summary", "abVault", abVault);
        json = vm.serializeAddress("summary", "acVault", acVault);
        json = vm.serializeAddress("summary", "bcVault", bcVault);

        // Aerodrome pools
        json = vm.serializeAddress("summary", "aeroAbPool", _readAddress("08_pools.json", "aeroAbPool"));
        json = vm.serializeAddress("summary", "aeroAcPool", _readAddress("08_pools.json", "aeroAcPool"));
        json = vm.serializeAddress("summary", "aeroBcPool", _readAddress("08_pools.json", "aeroBcPool"));

        // Balancer const-prod token-only pools
        json = vm.serializeAddress("summary", "balancerAbPool", balancerAbPool);
        json = vm.serializeAddress("summary", "balancerAcPool", balancerAcPool);
        json = vm.serializeAddress("summary", "balancerBcPool", balancerBcPool);

        // Balancer vault-token pools
        json = vm.serializeAddress("summary", "balUniAbWithA", balUniAbWithA);
        json = vm.serializeAddress("summary", "balUniAbWithB", balUniAbWithB);
        json = vm.serializeAddress("summary", "balUniAcWithA", balUniAcWithA);
        json = vm.serializeAddress("summary", "balUniAcWithC", balUniAcWithC);
        json = vm.serializeAddress("summary", "balUniBcWithB", balUniBcWithB);
        json = vm.serializeAddress("summary", "balUniBcWithC", balUniBcWithC);

        // External protocols
        json = vm.serializeAddress("summary", "permit2", address(permit2));
        json = vm.serializeAddress("summary", "weth9", address(weth));
        json = vm.serializeAddress("summary", "uniswapV2Factory", address(uniswapV2Factory));
        json = vm.serializeAddress("summary", "uniswapV2Router", address(uniswapV2Router));
        json = vm.serializeAddress("summary", "balancerV3Vault", address(balancerV3Vault));

        _writeJson(json, "deployment_summary.json");
    }

    function _logResults() internal view {
        _logAddress("Balancer ConstProd AB Pool (token-only):", balancerAbPool);
        _logAddress("Balancer ConstProd AC Pool (token-only):", balancerAcPool);
        _logAddress("Balancer ConstProd BC Pool (token-only):", balancerBcPool);

        _logAddress("Balancer UniV2 AB vault + ttA:", balUniAbWithA);
        _logAddress("Balancer UniV2 AB vault + ttB:", balUniAbWithB);
        _logAddress("Balancer UniV2 AC vault + ttA:", balUniAcWithA);
        _logAddress("Balancer UniV2 AC vault + ttC:", balUniAcWithC);
        _logAddress("Balancer UniV2 BC vault + ttB:", balUniBcWithB);
        _logAddress("Balancer UniV2 BC vault + ttC:", balUniBcWithC);

        _logComplete("Stage 12");
    }
}
