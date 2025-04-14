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

import {
    TokenConfig,
    TokenType
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IBalancerV3ConstantProductPoolStandardVaultPkg} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPoolStandardVaultPkg.sol";

/// @title Script_09_DeployBalancerConstProdPools
/// @notice Deploys 3 Balancer V3 constant-product pools (as vault-proxies) for (ttA/ttB), (ttA/ttC), (ttB/ttC)
contract Script_09_DeployBalancerConstProdPools is DeploymentBase {
    // Inputs
    IBalancerV3ConstantProductPoolStandardVaultPkg private balConstProdPkg;

    address private ttA;
    address private ttB;
    address private ttC;

    // Deployed pools (pool == vault proxy address)
    address private balAbPool;
    address private balAcPool;
    address private balBcPool;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 9: Deploy Balancer V3 ConstProd Pools");

        vm.startBroadcast();
        _deployPools();
        vm.stopBroadcast();

        _exportJson();
        _exportTokenlist();
        _exportSummary();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        balConstProdPkg = IBalancerV3ConstantProductPoolStandardVaultPkg(
            _readAddress("04_dex_packages.json", "balancerV3ConstantProductPoolStandardVaultPkg")
        );
        require(address(balConstProdPkg) != address(0), "Balancer const-prod pkg not found");

        ttA = _readAddress("05_test_tokens.json", "testTokenA");
        ttB = _readAddress("05_test_tokens.json", "testTokenB");
        ttC = _readAddress("05_test_tokens.json", "testTokenC");
        require(ttA != address(0) && ttB != address(0) && ttC != address(0), "Test tokens not found");
    }

    function _standardTokenConfig(address token) internal pure returns (TokenConfig memory cfg) {
        cfg = TokenConfig({
            token: IERC20(token),
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });
    }

    function _deployPools() internal {
        TokenConfig[] memory cfg;

        cfg = new TokenConfig[](2);
        cfg[0] = _standardTokenConfig(ttA);
        cfg[1] = _standardTokenConfig(ttB);
        balAbPool = balConstProdPkg.deployVault(cfg, address(0));

        cfg = new TokenConfig[](2);
        cfg[0] = _standardTokenConfig(ttA);
        cfg[1] = _standardTokenConfig(ttC);
        balAcPool = balConstProdPkg.deployVault(cfg, address(0));

        cfg = new TokenConfig[](2);
        cfg[0] = _standardTokenConfig(ttB);
        cfg[1] = _standardTokenConfig(ttC);
        balBcPool = balConstProdPkg.deployVault(cfg, address(0));
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("", "balancerAbPool", balAbPool);
        json = vm.serializeAddress("", "balancerAcPool", balAcPool);
        json = vm.serializeAddress("", "balancerBcPool", balBcPool);
        _writeJson(json, "09_balancer_const_prod_pools.json");
    }

    function _exportTokenlist() internal {
        _ensureOutDir();

        string memory chainIdStr = vm.toString(block.chainid);

        // Tokenlist schema matches other `*.tokenlist.json` files: array of { chainId, address, name, symbol, decimals }
        // Prefer on-chain token.name() when available (fallback to the provided label).
        string memory abName = _escapeJsonString(_safeName(balAbPool, "ab BalancerV3 ConstProd Pool"));
        string memory acName = _escapeJsonString(_safeName(balAcPool, "ac BalancerV3 ConstProd Pool"));
        string memory bcName = _escapeJsonString(_safeName(balBcPool, "bc BalancerV3 ConstProd Pool"));

        string memory tokenlist = string.concat(
            "[\n",
            "  {\n",
            "    \"chainId\": ",
            chainIdStr,
            ",\n",
            "    \"address\": \"",
            vm.toString(balAbPool),
            "\",\n",
            "    \"name\": \"",
            abName,
            "\",\n",
            "    \"symbol\": \"abBalancerV3ConstProdPool\",\n",
            "    \"decimals\": 18\n",
            "  },\n",
            "  {\n",
            "    \"chainId\": ",
            chainIdStr,
            ",\n",
            "    \"address\": \"",
            vm.toString(balAcPool),
            "\",\n",
            "    \"name\": \"",
            acName,
            "\",\n",
            "    \"symbol\": \"acBalancerV3ConstProdPool\",\n",
            "    \"decimals\": 18\n",
            "  },\n",
            "  {\n",
            "    \"chainId\": ",
            chainIdStr,
            ",\n",
            "    \"address\": \"",
            vm.toString(balBcPool),
            "\",\n",
            "    \"name\": \"",
            bcName,
            "\",\n",
            "    \"symbol\": \"bcBalancerV3ConstProdPool\",\n",
            "    \"decimals\": 18\n",
            "  }\n",
            "]\n"
        );

        vm.writeFile(string.concat(OUT_DIR, "/09_balancer_const_prod_pools.tokenlist.json"), tokenlist);
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
        json = vm.serializeAddress("summary", "uniswapV2Pkg", _readAddress("04_dex_packages.json", "uniswapV2Pkg"));
        json = vm.serializeAddress("summary", "aerodromePkg", _readAddress("04_dex_packages.json", "aerodromePkg"));
        json = vm.serializeAddress(
            "summary",
            "balancerV3StandardExchangeRouter",
            _readAddress("04_dex_packages.json", "balancerV3StandardExchangeRouter")
        );
        json = vm.serializeAddress("summary", "balancerV3Router", _readAddress("04_dex_packages.json", "balancerV3Router"));
        json = vm.serializeAddress(
            "summary",
            "balancerV3ConstantProductPoolStandardVaultPkg",
            _readAddress("04_dex_packages.json", "balancerV3ConstantProductPoolStandardVaultPkg")
        );

        // Tokens
        json = vm.serializeAddress("summary", "testTokenA", ttA);
        json = vm.serializeAddress("summary", "testTokenB", ttB);
        json = vm.serializeAddress("summary", "testTokenC", ttC);

        // UniV2 pools + vaults
        json = vm.serializeAddress("summary", "abPool", _readAddress("06_pools.json", "abPool"));
        json = vm.serializeAddress("summary", "acPool", _readAddress("06_pools.json", "acPool"));
        json = vm.serializeAddress("summary", "bcPool", _readAddress("06_pools.json", "bcPool"));

        json = vm.serializeAddress("summary", "abVault", _readAddress("07_strategy_vaults.json", "abVault"));
        json = vm.serializeAddress("summary", "acVault", _readAddress("07_strategy_vaults.json", "acVault"));
        json = vm.serializeAddress("summary", "bcVault", _readAddress("07_strategy_vaults.json", "bcVault"));

        // Aerodrome pools + vaults
        json = vm.serializeAddress("summary", "aeroAbPool", _readAddress("06_pools.json", "aeroAbPool"));
        json = vm.serializeAddress("summary", "aeroAcPool", _readAddress("06_pools.json", "aeroAcPool"));
        json = vm.serializeAddress("summary", "aeroBcPool", _readAddress("06_pools.json", "aeroBcPool"));

        json = vm.serializeAddress("summary", "aeroAbVault", _readAddress("08_aerodrome_strategy_vaults.json", "aeroAbVault"));
        json = vm.serializeAddress("summary", "aeroAcVault", _readAddress("08_aerodrome_strategy_vaults.json", "aeroAcVault"));
        json = vm.serializeAddress("summary", "aeroBcVault", _readAddress("08_aerodrome_strategy_vaults.json", "aeroBcVault"));

        // Balancer const-prod pools
        json = vm.serializeAddress("summary", "balancerAbPool", balAbPool);
        json = vm.serializeAddress("summary", "balancerAcPool", balAcPool);
        json = vm.serializeAddress("summary", "balancerBcPool", balBcPool);

        // External protocols
        json = vm.serializeAddress("summary", "permit2", address(permit2));
        json = vm.serializeAddress("summary", "weth9", address(weth));
        json = vm.serializeAddress("summary", "uniswapV2Factory", address(uniswapV2Factory));
        json = vm.serializeAddress("summary", "uniswapV2Router", address(uniswapV2Router));
        json = vm.serializeAddress("summary", "balancerV3Vault", address(balancerV3Vault));

        _writeJson(json, "deployment_summary.json");
    }

    function _logResults() internal view {
        _logAddress("Balancer A-B ConstProd Pool:", balAbPool);
        _logAddress("Balancer A-C ConstProd Pool:", balAcPool);
        _logAddress("Balancer B-C ConstProd Pool:", balBcPool);
        _logComplete("Stage 9");
    }
}
