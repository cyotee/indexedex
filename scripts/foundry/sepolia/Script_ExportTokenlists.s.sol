// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";

/// @notice Exports segmented tokenlists for public Ethereum Sepolia.
/// @dev Writes JSON arrays (TokenListEntry[]) into stable filenames so the frontend can
///      consume correlated lists (tokens, pools, vaults) without scraping stage outputs.
contract Script_ExportTokenlists is DeploymentBase {
    string internal constant UI_PREFIX = "sepolia";

    struct OptionalWethVaultTokenPools {
        address balUniWethcWithWeth;
        address balUniWethcWithC;
        address balAeroWethcWithWeth;
        address balAeroWethcWithC;
        bool hasAll;
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Helpers                                  */
    /* -------------------------------------------------------------------------- */

    function _hexChar(uint8 v) internal pure returns (bytes1) {
        return v < 10 ? bytes1(v + 0x30) : bytes1(v + 0x57);
    }

    function _escapeControl(uint8 c) internal pure returns (string memory) {
        bytes memory out = new bytes(6);
        out[0] = 0x5c; // \
        out[1] = 0x75; // u
        out[2] = 0x30; // 0
        out[3] = 0x30; // 0
        out[4] = _hexChar(c >> 4);
        out[5] = _hexChar(c & 0x0f);
        return string(out);
    }

    function _escapeJsonString(string memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        string memory out = "";
        for (uint256 i = 0; i < b.length; i++) {
            uint8 c = uint8(b[i]);

            if (c == 0x22) {
                out = string.concat(out, "\\\"");
            } else if (c == 0x5c) {
                out = string.concat(out, "\\\\");
            } else if (c == 0x08) {
                out = string.concat(out, "\\b");
            } else if (c == 0x0c) {
                out = string.concat(out, "\\f");
            } else if (c == 0x0a) {
                out = string.concat(out, "\\n");
            } else if (c == 0x0d) {
                out = string.concat(out, "\\r");
            } else if (c == 0x09) {
                out = string.concat(out, "\\t");
            } else if (c < 0x20) {
                out = string.concat(out, _escapeControl(c));
            } else {
                out = string.concat(out, string(abi.encodePacked(bytes1(c))));
            }
        }
        return out;
    }

    function _tokenName(address token, string memory fallbackName) internal view returns (string memory) {
        if (token.code.length == 0) return fallbackName;

        try IERC20Metadata(token).name() returns (string memory n) {
            if (bytes(n).length == 0) return fallbackName;
            return n;
        } catch {
            return fallbackName;
        }
    }

    function _tokenlistEntry(string memory chainIdStr, address token, string memory name, string memory symbol)
        internal
        view
        returns (string memory)
    {
        // NOTE: `name` should be the on-chain `token.name()` value. This helper supports a fallback name
        // (passed in as `name`) when a token does not implement `name()`.
        string memory escapedName = _escapeJsonString(_tokenName(token, name));
        string memory escapedSymbol = _escapeJsonString(symbol);

        return string.concat(
            "  {\n",
            "    \"chainId\": ",
            chainIdStr,
            ",\n",
            "    \"address\": \"",
            vm.toString(token),
            "\",\n",
            "    \"name\": \"",
            escapedName,
            "\",\n",
            "    \"symbol\": \"",
            escapedSymbol,
            "\",\n",
            "    \"decimals\": 18\n",
            "  }"
        );
    }

    function _writeTokenlist(string memory filename, string[] memory entries) internal {
        string memory out = "[\n";
        for (uint256 i = 0; i < entries.length; i++) {
            out = string.concat(out, entries[i]);
            if (i + 1 < entries.length) out = string.concat(out, ",\n");
            else out = string.concat(out, "\n");
        }
        out = string.concat(out, "]\n");
        vm.writeFile(string.concat(OUT_DIR, "/", filename), out);
    }

    function _writeEmptyTokenlist(string memory filename) internal {
        vm.writeFile(string.concat(OUT_DIR, "/", filename), "[]\n");
    }

    function _uiTokenlistFilename(string memory suffix) internal pure returns (string memory) {
        return string.concat(UI_PREFIX, "-", suffix);
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Run                                     */
    /* -------------------------------------------------------------------------- */

    function _exportTestTokens(string memory chainIdStr) internal {
        address ttA = _readAddress("07_test_tokens.json", "testTokenA");
        address ttB = _readAddress("07_test_tokens.json", "testTokenB");
        address ttC = _readAddress("07_test_tokens.json", "testTokenC");
        string[] memory entries = new string[](3);
        entries[0] = _tokenlistEntry(chainIdStr, ttA, "Test Token A", "TTA");
        entries[1] = _tokenlistEntry(chainIdStr, ttB, "Test Token B", "TTB");
        entries[2] = _tokenlistEntry(chainIdStr, ttC, "Test Token C", "TTC");
        _writeTokenlist(_uiTokenlistFilename("tokens.tokenlist.json"), entries);
    }

    function _exportPools(string memory chainIdStr) internal {
        address abPool = _readAddress("08_pools.json", "abPool");
        address acPool = _readAddress("08_pools.json", "acPool");
        address bcPool = _readAddress("08_pools.json", "bcPool");
        {
            (address uniWethcPool, bool okUniWethcPool) = _readAddressSafe("17_weth_ttc_pools.json", "uniWethcPool");
            bool hasUniWethcPool = okUniWethcPool && uniWethcPool != address(0);

            string[] memory entries = new string[](hasUniWethcPool ? 4 : 3);
            entries[0] = _tokenlistEntry(chainIdStr, abPool, "ab UniV2 Pool", "abUniV2Pool");
            entries[1] = _tokenlistEntry(chainIdStr, acPool, "ac UniV2 Pool", "acUniV2Pool");
            entries[2] = _tokenlistEntry(chainIdStr, bcPool, "bc UniV2 Pool", "bcUniV2Pool");

            if (hasUniWethcPool) {
                entries[3] = _tokenlistEntry(chainIdStr, uniWethcPool, "wethc UniV2 Pool", "wethcUniV2Pool");
            }
            _writeTokenlist(_uiTokenlistFilename("uniV2pool.tokenlist.json"), entries);
        }

        address aeroAbPool = _readAddress("08_pools.json", "aeroAbPool");
        address aeroAcPool = _readAddress("08_pools.json", "aeroAcPool");
        address aeroBcPool = _readAddress("08_pools.json", "aeroBcPool");
        {
            (address aeroWethcPool, bool okAeroWethcPool) = _readAddressSafe("17_weth_ttc_pools.json", "aeroWethcPool");
            bool hasAeroWethcPool = okAeroWethcPool && aeroWethcPool != address(0);

            string[] memory entries = new string[](hasAeroWethcPool ? 4 : 3);
            entries[0] = _tokenlistEntry(chainIdStr, aeroAbPool, "ab Aerodrome Pool", "aeroAbPool");
            entries[1] = _tokenlistEntry(chainIdStr, aeroAcPool, "ac Aerodrome Pool", "aeroAcPool");
            entries[2] = _tokenlistEntry(chainIdStr, aeroBcPool, "bc Aerodrome Pool", "aeroBcPool");

            if (hasAeroWethcPool) {
                entries[3] = _tokenlistEntry(chainIdStr, aeroWethcPool, "wethc Aerodrome Pool", "aeroWethcPool");
            }
            _writeTokenlist(_uiTokenlistFilename("aerodrome-pools.tokenlist.json"), entries);
        }
    }

    function _exportStrategyVaults(string memory chainIdStr) internal {
        address abVault = _readAddress("09_strategy_vaults.json", "abVault");
        address acVault = _readAddress("09_strategy_vaults.json", "acVault");
        address bcVault = _readAddress("09_strategy_vaults.json", "bcVault");
        {
            (address uniWethcVault, bool okUniWethcVault) = _readAddressSafe("18_weth_ttc_vaults.json", "uniWethcVault");
            bool hasUniWethcVault = okUniWethcVault && uniWethcVault != address(0);

            string[] memory entries = new string[](hasUniWethcVault ? 4 : 3);
            entries[0] = _tokenlistEntry(chainIdStr, abVault, "ab UniV2 Pool Strategy Vault", "abSV");
            entries[1] = _tokenlistEntry(chainIdStr, acVault, "ac UniV2 Pool Strategy Vault", "acSV");
            entries[2] = _tokenlistEntry(chainIdStr, bcVault, "bc UniV2 Pool Strategy Vault", "bcSV");

            if (hasUniWethcVault) {
                entries[3] = _tokenlistEntry(chainIdStr, uniWethcVault, "wethc UniV2 Pool Strategy Vault", "wethcSV");
            }
            _writeTokenlist(_uiTokenlistFilename("strategy-vaults.tokenlist.json"), entries);
        }

        address aeroAbVault = _readAddress("09_strategy_vaults.json", "aeroAbVault");
        address aeroAcVault = _readAddress("09_strategy_vaults.json", "aeroAcVault");
        address aeroBcVault = _readAddress("09_strategy_vaults.json", "aeroBcVault");
        {
            (address aeroWethcVault, bool okAeroWethcVault) = _readAddressSafe("18_weth_ttc_vaults.json", "aeroWethcVault");
            bool hasAeroWethcVault = okAeroWethcVault && aeroWethcVault != address(0);

            string[] memory entries = new string[](hasAeroWethcVault ? 4 : 3);
            entries[0] = _tokenlistEntry(chainIdStr, aeroAbVault, "ab Aerodrome Pool Strategy Vault", "aeroAbSV");
            entries[1] = _tokenlistEntry(chainIdStr, aeroAcVault, "ac Aerodrome Pool Strategy Vault", "aeroAcSV");
            entries[2] = _tokenlistEntry(chainIdStr, aeroBcVault, "bc Aerodrome Pool Strategy Vault", "aeroBcSV");

            if (hasAeroWethcVault) {
                entries[3] = _tokenlistEntry(chainIdStr, aeroWethcVault, "wethc Aerodrome Pool Strategy Vault", "aeroWethcSV");
            }
            _writeTokenlist(_uiTokenlistFilename("aerodrome-strategy-vaults.tokenlist.json"), entries);
        }
    }

    function _exportBalancerConstProdPools(string memory chainIdStr) internal {
        // Note: Balancer const prod pools stage numbers differ between anvil_base_main and anvil_sepolia
        // This tries to read from stage 13 if exists, otherwise stage 12
        (address balAbPool, bool okBalAb) = _readAddressSafe("13_balancer_const_prod_vault_token_pools.json", "balancerAbPool");
        if (!okBalAb || balAbPool == address(0)) {
            (balAbPool, okBalAb) = _readAddressSafe("12_balancer_const_prod_vault_token_pools.json", "balancerAbPool");
        }

        (address balAcPool, bool okBalAc) = _readAddressSafe("13_balancer_const_prod_vault_token_pools.json", "balancerAcPool");
        if (!okBalAc || balAcPool == address(0)) {
            (balAcPool, okBalAc) = _readAddressSafe("12_balancer_const_prod_vault_token_pools.json", "balancerAcPool");
        }

        (address balBcPool, bool okBalBc) = _readAddressSafe("13_balancer_const_prod_vault_token_pools.json", "balancerBcPool");
        if (!okBalBc || balBcPool == address(0)) {
            (balBcPool, okBalBc) = _readAddressSafe("12_balancer_const_prod_vault_token_pools.json", "balancerBcPool");
        }

        (address balancerWethcPool, bool okWethcPool) = _readAddressSafe("17_weth_ttc_pools.json", "balancerWethcPool");
        bool hasWethcPool = okWethcPool && balancerWethcPool != address(0);

        bool hasConstProdPools = okBalAb && okBalAc && okBalBc && balAbPool != address(0) && balAcPool != address(0)
            && balBcPool != address(0);

        if (hasConstProdPools) {
            string[] memory entries = new string[](hasWethcPool ? 4 : 3);
            entries[0] = _tokenlistEntry(chainIdStr, balAbPool, "ab BalancerV3 ConstProd Pool", "abBalancerV3ConstProdPool");
            entries[1] = _tokenlistEntry(chainIdStr, balAcPool, "ac BalancerV3 ConstProd Pool", "acBalancerV3ConstProdPool");
            entries[2] = _tokenlistEntry(chainIdStr, balBcPool, "bc BalancerV3 ConstProd Pool", "bcBalancerV3ConstProdPool");

            if (hasWethcPool) {
                entries[3] = _tokenlistEntry(chainIdStr, balancerWethcPool, "wethc BalancerV3 ConstProd Pool", "wethcBalancerV3ConstProdPool");
            }
            _writeTokenlist(_uiTokenlistFilename("balancerv3-constprod-pools.tokenlist.json"), entries);
        } else {
            _writeEmptyTokenlist(_uiTokenlistFilename("balancerv3-constprod-pools.tokenlist.json"));
        }
    }

    function _exportBalancerVaultTokenPools(string memory chainIdStr) internal {
        // Sepolia Stage 12 currently exports only UniV2 vault-token pools.
        // Stage 20 adds the WETH/TTC UniV2 + Aerodrome vault-token pools.
        (address balUniWethcWithWeth, bool okUniWeth) = _readAddressSafe("20_weth_ttc_balancer_vault_token_pools.json", "balUniWethcWithWeth");
        (address balUniWethcWithC, bool okUniTtc) = _readAddressSafe("20_weth_ttc_balancer_vault_token_pools.json", "balUniWethcWithC");
        (address balAeroWethcWithWeth, bool okAeroWeth) = _readAddressSafe("20_weth_ttc_balancer_vault_token_pools.json", "balAeroWethcWithWeth");
        (address balAeroWethcWithC, bool okAeroTtc) = _readAddressSafe("20_weth_ttc_balancer_vault_token_pools.json", "balAeroWethcWithC");

        bool hasWethcVaultTokenPools = okUniWeth && okUniTtc && okAeroWeth && okAeroTtc
            && balUniWethcWithWeth != address(0) && balUniWethcWithC != address(0)
            && balAeroWethcWithWeth != address(0) && balAeroWethcWithC != address(0);

        string[] memory entries = new string[](hasWethcVaultTokenPools ? 10 : 6);
        entries[0] = _tokenlistEntry(
            chainIdStr,
            _readAddress("12_balancer_const_prod_vault_token_pools.json", "balUniAbWithA"),
            "UniV2 AB Vault + ttA BalancerV3 Pool",
            "uniAbVault_ttA_BalancerPool"
        );
        entries[1] = _tokenlistEntry(
            chainIdStr,
            _readAddress("12_balancer_const_prod_vault_token_pools.json", "balUniAbWithB"),
            "UniV2 AB Vault + ttB BalancerV3 Pool",
            "uniAbVault_ttB_BalancerPool"
        );
        entries[2] = _tokenlistEntry(
            chainIdStr,
            _readAddress("12_balancer_const_prod_vault_token_pools.json", "balUniAcWithA"),
            "UniV2 AC Vault + ttA BalancerV3 Pool",
            "uniAcVault_ttA_BalancerPool"
        );
        entries[3] = _tokenlistEntry(
            chainIdStr,
            _readAddress("12_balancer_const_prod_vault_token_pools.json", "balUniAcWithC"),
            "UniV2 AC Vault + ttC BalancerV3 Pool",
            "uniAcVault_ttC_BalancerPool"
        );
        entries[4] = _tokenlistEntry(
            chainIdStr,
            _readAddress("12_balancer_const_prod_vault_token_pools.json", "balUniBcWithB"),
            "UniV2 BC Vault + ttB BalancerV3 Pool",
            "uniBcVault_ttB_BalancerPool"
        );
        entries[5] = _tokenlistEntry(
            chainIdStr,
            _readAddress("12_balancer_const_prod_vault_token_pools.json", "balUniBcWithC"),
            "UniV2 BC Vault + ttC BalancerV3 Pool",
            "uniBcVault_ttC_BalancerPool"
        );

        if (hasWethcVaultTokenPools) {
            entries[6] = _tokenlistEntry(
                chainIdStr,
                balUniWethcWithWeth,
                "UniV2 WETH/TTC Vault + WETH BalancerV3 Pool",
                "uniWethcVault_weth_BalancerPool"
            );
            entries[7] = _tokenlistEntry(
                chainIdStr,
                balUniWethcWithC,
                "UniV2 WETH/TTC Vault + TTC BalancerV3 Pool",
                "uniWethcVault_ttc_BalancerPool"
            );
            entries[8] = _tokenlistEntry(
                chainIdStr,
                balAeroWethcWithWeth,
                "Aerodrome WETH/TTC Vault + WETH BalancerV3 Pool",
                "aeroWethcVault_weth_BalancerPool"
            );
            entries[9] = _tokenlistEntry(
                chainIdStr,
                balAeroWethcWithC,
                "Aerodrome WETH/TTC Vault + TTC BalancerV3 Pool",
                "aeroWethcVault_ttc_BalancerPool"
            );
        }

        _writeTokenlist(_uiTokenlistFilename("balancerv3-vault-token-pools.tokenlist.json"), entries);
    }

    function _baseBalancerCombinedEntries(string memory chainIdStr) internal view returns (string[] memory entries) {
        entries = new string[](9);
        entries[0] =
            _tokenlistEntry(chainIdStr, _readAddress("12_balancer_const_prod_vault_token_pools.json", "balancerAbPool"), "ab BalancerV3 ConstProd Pool", "abBalancerV3ConstProdPool");
        entries[1] =
            _tokenlistEntry(chainIdStr, _readAddress("12_balancer_const_prod_vault_token_pools.json", "balancerAcPool"), "ac BalancerV3 ConstProd Pool", "acBalancerV3ConstProdPool");
        entries[2] =
            _tokenlistEntry(chainIdStr, _readAddress("12_balancer_const_prod_vault_token_pools.json", "balancerBcPool"), "bc BalancerV3 ConstProd Pool", "bcBalancerV3ConstProdPool");
        entries[3] = _tokenlistEntry(
            chainIdStr,
            _readAddress("12_balancer_const_prod_vault_token_pools.json", "balUniAbWithA"),
            "UniV2 AB Vault + ttA BalancerV3 Pool",
            "uniAbVault_ttA_BalancerPool"
        );
        entries[4] = _tokenlistEntry(
            chainIdStr,
            _readAddress("12_balancer_const_prod_vault_token_pools.json", "balUniAbWithB"),
            "UniV2 AB Vault + ttB BalancerV3 Pool",
            "uniAbVault_ttB_BalancerPool"
        );
        entries[5] = _tokenlistEntry(
            chainIdStr,
            _readAddress("12_balancer_const_prod_vault_token_pools.json", "balUniAcWithA"),
            "UniV2 AC Vault + ttA BalancerV3 Pool",
            "uniAcVault_ttA_BalancerPool"
        );
        entries[6] = _tokenlistEntry(
            chainIdStr,
            _readAddress("12_balancer_const_prod_vault_token_pools.json", "balUniAcWithC"),
            "UniV2 AC Vault + ttC BalancerV3 Pool",
            "uniAcVault_ttC_BalancerPool"
        );
        entries[7] = _tokenlistEntry(
            chainIdStr,
            _readAddress("12_balancer_const_prod_vault_token_pools.json", "balUniBcWithB"),
            "UniV2 BC Vault + ttB BalancerV3 Pool",
            "uniBcVault_ttB_BalancerPool"
        );
        entries[8] = _tokenlistEntry(
            chainIdStr,
            _readAddress("12_balancer_const_prod_vault_token_pools.json", "balUniBcWithC"),
            "UniV2 BC Vault + ttC BalancerV3 Pool",
            "uniBcVault_ttC_BalancerPool"
        );
    }

    function _fullBalancerCombinedEntries(
        string memory chainIdStr,
        address balUniWethcWithWeth,
        address balUniWethcWithC,
        address balAeroWethcWithWeth,
        address balAeroWethcWithC
    ) internal view returns (string[] memory entries) {
        entries = new string[](13);

        string[] memory baseEntries = _baseBalancerCombinedEntries(chainIdStr);
        for (uint256 i = 0; i < 9; i++) {
            entries[i] = baseEntries[i];
        }

        entries[9] = _tokenlistEntry(
            chainIdStr,
            balUniWethcWithWeth,
            "UniV2 WETH/TTC Vault + WETH BalancerV3 Pool",
            "uniWethcVault_weth_BalancerPool"
        );
        entries[10] = _tokenlistEntry(
            chainIdStr,
            balUniWethcWithC,
            "UniV2 WETH/TTC Vault + TTC BalancerV3 Pool",
            "uniWethcVault_ttc_BalancerPool"
        );
        entries[11] = _tokenlistEntry(
            chainIdStr,
            balAeroWethcWithWeth,
            "Aerodrome WETH/TTC Vault + WETH BalancerV3 Pool",
            "aeroWethcVault_weth_BalancerPool"
        );
        entries[12] = _tokenlistEntry(
            chainIdStr,
            balAeroWethcWithC,
            "Aerodrome WETH/TTC Vault + TTC BalancerV3 Pool",
            "aeroWethcVault_ttc_BalancerPool"
        );
    }

    function _hasBalancerConstProdPools() internal view returns (bool) {
        (address balAbPool, bool okBalAb) = _readAddressSafe("12_balancer_const_prod_vault_token_pools.json", "balancerAbPool");
        (address balAcPool, bool okBalAc) = _readAddressSafe("12_balancer_const_prod_vault_token_pools.json", "balancerAcPool");
        (address balBcPool, bool okBalBc) = _readAddressSafe("12_balancer_const_prod_vault_token_pools.json", "balancerBcPool");

        return okBalAb && okBalAc && okBalBc && balAbPool != address(0) && balAcPool != address(0)
            && balBcPool != address(0);
    }

    function _loadOptionalWethVaultTokenPools() internal view returns (OptionalWethVaultTokenPools memory pools) {
        bool okUniWeth;
        bool okUniTtc;
        bool okAeroWeth;
        bool okAeroTtc;

        (pools.balUniWethcWithWeth, okUniWeth) =
            _readAddressSafe("20_weth_ttc_balancer_vault_token_pools.json", "balUniWethcWithWeth");
        (pools.balUniWethcWithC, okUniTtc) =
            _readAddressSafe("20_weth_ttc_balancer_vault_token_pools.json", "balUniWethcWithC");
        (pools.balAeroWethcWithWeth, okAeroWeth) =
            _readAddressSafe("20_weth_ttc_balancer_vault_token_pools.json", "balAeroWethcWithWeth");
        (pools.balAeroWethcWithC, okAeroTtc) =
            _readAddressSafe("20_weth_ttc_balancer_vault_token_pools.json", "balAeroWethcWithC");

        pools.hasAll = okUniWeth && okUniTtc && okAeroWeth && okAeroTtc
            && pools.balUniWethcWithWeth != address(0) && pools.balUniWethcWithC != address(0)
            && pools.balAeroWethcWithWeth != address(0) && pools.balAeroWethcWithC != address(0);
    }

    function _exportBalancerCombinedPools(string memory chainIdStr) internal {
        if (!_hasBalancerConstProdPools()) {
            _writeEmptyTokenlist(_uiTokenlistFilename("balancerv3-pools.tokenlist.json"));
            return;
        }

        OptionalWethVaultTokenPools memory pools = _loadOptionalWethVaultTokenPools();
        string[] memory entries;

        if (pools.hasAll) {
            entries = _fullBalancerCombinedEntries(
                chainIdStr,
                pools.balUniWethcWithWeth,
                pools.balUniWethcWithC,
                pools.balAeroWethcWithWeth,
                pools.balAeroWethcWithC
            );
        } else {
            entries = _baseBalancerCombinedEntries(chainIdStr);
        }

        _writeTokenlist(_uiTokenlistFilename("balancerv3-pools.tokenlist.json"), entries);
    }

    function _exportBalancerPools(string memory chainIdStr) internal {
        _exportBalancerConstProdPools(chainIdStr);
        _exportBalancerVaultTokenPools(chainIdStr);
        _exportBalancerCombinedPools(chainIdStr);
    }

    function _exportERC4626Vaults(string memory chainIdStr) internal {
        // ERC4626 vaults (Permit package) can be optional; keep the file present for import stability.
        // If Stage 14 hasn't been run, export an empty list.
        (address ttaVault, bool okA) = _readAddressSafe("14_erc4626_permit_vaults.json", "erc4626VaultTTA");
        (address ttbVault, bool okB) = _readAddressSafe("14_erc4626_permit_vaults.json", "erc4626VaultTTB");
        (address ttcVault, bool okC) = _readAddressSafe("14_erc4626_permit_vaults.json", "erc4626VaultTTC");

        if (!(okA && okB && okC) || ttaVault == address(0) || ttbVault == address(0) || ttcVault == address(0)) {
            _writeEmptyTokenlist(_uiTokenlistFilename("erc4626.tokenlist.json"));
            return;
        }

        string[] memory entries = new string[](3);
        entries[0] = _tokenlistEntry(chainIdStr, ttaVault, "TTA ERC4626 Vault", "ttaERC4626Vault");
        entries[1] = _tokenlistEntry(chainIdStr, ttbVault, "TTB ERC4626 Vault", "ttbERC4626Vault");
        entries[2] = _tokenlistEntry(chainIdStr, ttcVault, "TTC ERC4626 Vault", "ttcERC4626Vault");
        _writeTokenlist(_uiTokenlistFilename("erc4626.tokenlist.json"), entries);
    }

    function _exportSeigniorageDetfs(string memory chainIdStr) internal {
        (address detfAb, bool okAb) = _readAddressSafe("15_seigniorage_detfs.json", "detf_abVault");
        (address detfAc, bool okAc) = _readAddressSafe("15_seigniorage_detfs.json", "detf_acVault");
        (address detfBc, bool okBc) = _readAddressSafe("15_seigniorage_detfs.json", "detf_bcVault");
        (address detfAeroAb, bool okAeroAb) = _readAddressSafe("15_seigniorage_detfs.json", "detf_aeroAbVault");
        (address detfAeroAc, bool okAeroAc) = _readAddressSafe("15_seigniorage_detfs.json", "detf_aeroAcVault");
        (address detfAeroBc, bool okAeroBc) = _readAddressSafe("15_seigniorage_detfs.json", "detf_aeroBcVault");

        if (!(okAb && okAc && okBc && okAeroAb && okAeroAc && okAeroBc)) {
            _writeEmptyTokenlist(_uiTokenlistFilename("seigniorage-detfs.tokenlist.json"));
            return;
        }

        if (
            detfAb == address(0) || detfAc == address(0) || detfBc == address(0) || detfAeroAb == address(0)
                || detfAeroAc == address(0) || detfAeroBc == address(0)
        ) {
            _writeEmptyTokenlist(_uiTokenlistFilename("seigniorage-detfs.tokenlist.json"));
            return;
        }

        string[] memory entries = new string[](6);
        entries[0] = _tokenlistEntry(chainIdStr, detfAb, "Seigniorage DETF (abVault)", "sdetfAb");
        entries[1] = _tokenlistEntry(chainIdStr, detfAc, "Seigniorage DETF (acVault)", "sdetfAc");
        entries[2] = _tokenlistEntry(chainIdStr, detfBc, "Seigniorage DETF (bcVault)", "sdetfBc");
        entries[3] = _tokenlistEntry(chainIdStr, detfAeroAb, "Seigniorage DETF (aeroAbVault)", "sdetfAeroAb");
        entries[4] = _tokenlistEntry(chainIdStr, detfAeroAc, "Seigniorage DETF (aeroAcVault)", "sdetfAeroAc");
        entries[5] = _tokenlistEntry(chainIdStr, detfAeroBc, "Seigniorage DETF (aeroBcVault)", "sdetfAeroBc");
        _writeTokenlist(_uiTokenlistFilename("seigniorage-detfs.tokenlist.json"), entries);
    }

    function _exportProtocolDetf(string memory chainIdStr) internal {
        (address chir, bool okChir) = _readAddressSafe("16_protocol_detf.json", "protocolDetf");
        (address rich, bool okRich) = _readAddressSafe("16_protocol_detf.json", "richToken");
        (address richir, bool okRichir) = _readAddressSafe("16_protocol_detf.json", "richirToken");

        if (!(okChir && okRich && okRichir)) {
            _writeEmptyTokenlist(_uiTokenlistFilename("protocol-detf.tokenlist.json"));
            return;
        }
        if (chir == address(0) || rich == address(0) || richir == address(0)) {
            _writeEmptyTokenlist(_uiTokenlistFilename("protocol-detf.tokenlist.json"));
            return;
        }

        string[] memory entries = new string[](3);
        entries[0] = _tokenlistEntry(chainIdStr, chir, "Protocol DETF (CHIR)", "CHIR");
        entries[1] = _tokenlistEntry(chainIdStr, rich, "RICH Token", "RICH");
        entries[2] = _tokenlistEntry(chainIdStr, richir, "RICHIR Token", "RICHIR");
        _writeTokenlist(_uiTokenlistFilename("protocol-detf.tokenlist.json"), entries);
    }

    function _writeMarker() internal {
        // Write a small summary marker file for stage skip logic.
        string memory json = vm.serializeUint("summary", "chainId", block.chainid);
        json = vm.serializeString("summary", "exportedAt", vm.toString(block.timestamp));
        _writeJson(json, "export_tokenlists.json");
    }

    function run() external {
        _setup();
        _ensureOutDir();
        _logHeader("Export Segmented Tokenlists");

        string memory chainIdStr = vm.toString(block.chainid);

        _exportTestTokens(chainIdStr);
        _exportPools(chainIdStr);
        _exportStrategyVaults(chainIdStr);
        _exportBalancerPools(chainIdStr);
        _exportERC4626Vaults(chainIdStr);
        _exportSeigniorageDetfs(chainIdStr);
        _exportProtocolDetf(chainIdStr);
        _writeMarker();

        _logComplete("Export Segmented Tokenlists");
    }
}
