// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";

/// @notice Exports segmented tokenlists for the local Anvil Base-main fork.
/// @dev Writes JSON arrays (TokenListEntry[]) into stable filenames so the frontend can
///      consume correlated lists (tokens, pools, vaults) without scraping stage outputs.
contract Script_14_ExportTokenlists is DeploymentBase {
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

    /* -------------------------------------------------------------------------- */
    /*                                    Run                                     */
    /* -------------------------------------------------------------------------- */

    function _exportTestTokens(string memory chainIdStr) internal {
        address ttA = _readAddress("05_test_tokens.json", "testTokenA");
        address ttB = _readAddress("05_test_tokens.json", "testTokenB");
        address ttC = _readAddress("05_test_tokens.json", "testTokenC");
        string[] memory entries = new string[](3);
        entries[0] = _tokenlistEntry(chainIdStr, ttA, "Test Token A", "TTA");
        entries[1] = _tokenlistEntry(chainIdStr, ttB, "Test Token B", "TTB");
        entries[2] = _tokenlistEntry(chainIdStr, ttC, "Test Token C", "TTC");
        _writeTokenlist("anvil_base_main-tokens.tokenlist.json", entries);
    }

    function _exportPools(string memory chainIdStr) internal {
        address abPool = _readAddress("06_pools.json", "abPool");
        address acPool = _readAddress("06_pools.json", "acPool");
        address bcPool = _readAddress("06_pools.json", "bcPool");
        {
            string[] memory entries = new string[](3);
            entries[0] = _tokenlistEntry(chainIdStr, abPool, "ab UniV2 Pool", "abUniV2Pool");
            entries[1] = _tokenlistEntry(chainIdStr, acPool, "ac UniV2 Pool", "acUniV2Pool");
            entries[2] = _tokenlistEntry(chainIdStr, bcPool, "bc UniV2 Pool", "bcUniV2Pool");
            _writeTokenlist("anvil_base_main-uniV2pool.tokenlist.json", entries);
        }

        address aeroAbPool = _readAddress("06_pools.json", "aeroAbPool");
        address aeroAcPool = _readAddress("06_pools.json", "aeroAcPool");
        address aeroBcPool = _readAddress("06_pools.json", "aeroBcPool");
        {
            string[] memory entries = new string[](3);
            entries[0] = _tokenlistEntry(chainIdStr, aeroAbPool, "ab Aerodrome Pool", "aeroAbPool");
            entries[1] = _tokenlistEntry(chainIdStr, aeroAcPool, "ac Aerodrome Pool", "aeroAcPool");
            entries[2] = _tokenlistEntry(chainIdStr, aeroBcPool, "bc Aerodrome Pool", "aeroBcPool");
            _writeTokenlist("anvil_base_main-aerodrome-pools.tokenlist.json", entries);
        }
    }

    function _exportStrategyVaults(string memory chainIdStr) internal {
        address abVault = _readAddress("07_strategy_vaults.json", "abVault");
        address acVault = _readAddress("07_strategy_vaults.json", "acVault");
        address bcVault = _readAddress("07_strategy_vaults.json", "bcVault");
        {
            string[] memory entries = new string[](3);
            entries[0] = _tokenlistEntry(chainIdStr, abVault, "ab UniV2 Pool Strategy Vault", "abSV");
            entries[1] = _tokenlistEntry(chainIdStr, acVault, "ac UniV2 Pool Strategy Vault", "acSV");
            entries[2] = _tokenlistEntry(chainIdStr, bcVault, "bc UniV2 Pool Strategy Vault", "bcSV");
            _writeTokenlist("anvil_base_main-strategy-vaults.tokenlist.json", entries);
        }

        address aeroAbVault = _readAddress("08_aerodrome_strategy_vaults.json", "aeroAbVault");
        address aeroAcVault = _readAddress("08_aerodrome_strategy_vaults.json", "aeroAcVault");
        address aeroBcVault = _readAddress("08_aerodrome_strategy_vaults.json", "aeroBcVault");
        {
            string[] memory entries = new string[](3);
            entries[0] = _tokenlistEntry(chainIdStr, aeroAbVault, "ab Aerodrome Pool Strategy Vault", "aeroAbSV");
            entries[1] = _tokenlistEntry(chainIdStr, aeroAcVault, "ac Aerodrome Pool Strategy Vault", "aeroAcSV");
            entries[2] = _tokenlistEntry(chainIdStr, aeroBcVault, "bc Aerodrome Pool Strategy Vault", "aeroBcSV");
            _writeTokenlist("anvil_base_main-aerodrome-strategy-vaults.tokenlist.json", entries);
        }
    }

    function _exportBalancerPools(string memory chainIdStr) internal {
        {
            string[] memory entries = new string[](3);
            entries[0] = _tokenlistEntry(
                chainIdStr,
                _readAddress("12_balancer_const_prod_vault_token_pools.json", "balancerAbPool"),
                "ab BalancerV3 ConstProd Pool",
                "abBalancerV3ConstProdPool"
            );
            entries[1] = _tokenlistEntry(
                chainIdStr,
                _readAddress("12_balancer_const_prod_vault_token_pools.json", "balancerAcPool"),
                "ac BalancerV3 ConstProd Pool",
                "acBalancerV3ConstProdPool"
            );
            entries[2] = _tokenlistEntry(
                chainIdStr,
                _readAddress("12_balancer_const_prod_vault_token_pools.json", "balancerBcPool"),
                "bc BalancerV3 ConstProd Pool",
                "bcBalancerV3ConstProdPool"
            );
            _writeTokenlist("anvil_base_main-balancerv3-constprod-pools.tokenlist.json", entries);
        }

        {
            string[] memory entries = new string[](12);
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
            entries[6] = _tokenlistEntry(
                chainIdStr,
                _readAddress("12_balancer_const_prod_vault_token_pools.json", "balAeroAbWithA"),
                "Aerodrome AB Vault + ttA BalancerV3 Pool",
                "aeroAbVault_ttA_BalancerPool"
            );
            entries[7] = _tokenlistEntry(
                chainIdStr,
                _readAddress("12_balancer_const_prod_vault_token_pools.json", "balAeroAbWithB"),
                "Aerodrome AB Vault + ttB BalancerV3 Pool",
                "aeroAbVault_ttB_BalancerPool"
            );
            entries[8] = _tokenlistEntry(
                chainIdStr,
                _readAddress("12_balancer_const_prod_vault_token_pools.json", "balAeroAcWithA"),
                "Aerodrome AC Vault + ttA BalancerV3 Pool",
                "aeroAcVault_ttA_BalancerPool"
            );
            entries[9] = _tokenlistEntry(
                chainIdStr,
                _readAddress("12_balancer_const_prod_vault_token_pools.json", "balAeroAcWithC"),
                "Aerodrome AC Vault + ttC BalancerV3 Pool",
                "aeroAcVault_ttC_BalancerPool"
            );
            entries[10] = _tokenlistEntry(
                chainIdStr,
                _readAddress("12_balancer_const_prod_vault_token_pools.json", "balAeroBcWithB"),
                "Aerodrome BC Vault + ttB BalancerV3 Pool",
                "aeroBcVault_ttB_BalancerPool"
            );
            entries[11] = _tokenlistEntry(
                chainIdStr,
                _readAddress("12_balancer_const_prod_vault_token_pools.json", "balAeroBcWithC"),
                "Aerodrome BC Vault + ttC BalancerV3 Pool",
                "aeroBcVault_ttC_BalancerPool"
            );
            _writeTokenlist("anvil_base_main-balancerv3-vault-token-pools.tokenlist.json", entries);
        }

        {
            // Combined list consumed by the current frontend
            string[] memory entries = new string[](15);
            entries[0] = _tokenlistEntry(
                chainIdStr,
                _readAddress("12_balancer_const_prod_vault_token_pools.json", "balancerAbPool"),
                "ab BalancerV3 ConstProd Pool",
                "abBalancerV3ConstProdPool"
            );
            entries[1] = _tokenlistEntry(
                chainIdStr,
                _readAddress("12_balancer_const_prod_vault_token_pools.json", "balancerAcPool"),
                "ac BalancerV3 ConstProd Pool",
                "acBalancerV3ConstProdPool"
            );
            entries[2] = _tokenlistEntry(
                chainIdStr,
                _readAddress("12_balancer_const_prod_vault_token_pools.json", "balancerBcPool"),
                "bc BalancerV3 ConstProd Pool",
                "bcBalancerV3ConstProdPool"
            );
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
            entries[9] = _tokenlistEntry(
                chainIdStr,
                _readAddress("12_balancer_const_prod_vault_token_pools.json", "balAeroAbWithA"),
                "Aerodrome AB Vault + ttA BalancerV3 Pool",
                "aeroAbVault_ttA_BalancerPool"
            );
            entries[10] = _tokenlistEntry(
                chainIdStr,
                _readAddress("12_balancer_const_prod_vault_token_pools.json", "balAeroAbWithB"),
                "Aerodrome AB Vault + ttB BalancerV3 Pool",
                "aeroAbVault_ttB_BalancerPool"
            );
            entries[11] = _tokenlistEntry(
                chainIdStr,
                _readAddress("12_balancer_const_prod_vault_token_pools.json", "balAeroAcWithA"),
                "Aerodrome AC Vault + ttA BalancerV3 Pool",
                "aeroAcVault_ttA_BalancerPool"
            );
            entries[12] = _tokenlistEntry(
                chainIdStr,
                _readAddress("12_balancer_const_prod_vault_token_pools.json", "balAeroAcWithC"),
                "Aerodrome AC Vault + ttC BalancerV3 Pool",
                "aeroAcVault_ttC_BalancerPool"
            );
            entries[13] = _tokenlistEntry(
                chainIdStr,
                _readAddress("12_balancer_const_prod_vault_token_pools.json", "balAeroBcWithB"),
                "Aerodrome BC Vault + ttB BalancerV3 Pool",
                "aeroBcVault_ttB_BalancerPool"
            );
            entries[14] = _tokenlistEntry(
                chainIdStr,
                _readAddress("12_balancer_const_prod_vault_token_pools.json", "balAeroBcWithC"),
                "Aerodrome BC Vault + ttC BalancerV3 Pool",
                "aeroBcVault_ttC_BalancerPool"
            );
            _writeTokenlist("anvil_base_main-balancerv3-pools.tokenlist.json", entries);
        }
    }

    function _exportERC4626Vaults(string memory chainIdStr) internal {
        // ERC4626 vaults (Permit package) can be optional; keep the file present for import stability.
        // If Stage 15 hasn't been run, export an empty list.
        (address ttaVault, bool okA) = _readAddressSafe("15_erc4626_permit_vaults.json", "erc4626VaultTTA");
        (address ttbVault, bool okB) = _readAddressSafe("15_erc4626_permit_vaults.json", "erc4626VaultTTB");
        (address ttcVault, bool okC) = _readAddressSafe("15_erc4626_permit_vaults.json", "erc4626VaultTTC");

        if (!(okA && okB && okC) || ttaVault == address(0) || ttbVault == address(0) || ttcVault == address(0)) {
            _writeEmptyTokenlist("anvil_base_main-erc4626.tokenlist.json");
            return;
        }

        string[] memory entries = new string[](3);
        entries[0] = _tokenlistEntry(chainIdStr, ttaVault, "TTA ERC4626 Vault", "ttaERC4626Vault");
        entries[1] = _tokenlistEntry(chainIdStr, ttbVault, "TTB ERC4626 Vault", "ttbERC4626Vault");
        entries[2] = _tokenlistEntry(chainIdStr, ttcVault, "TTC ERC4626 Vault", "ttcERC4626Vault");
        _writeTokenlist("anvil_base_main-erc4626.tokenlist.json", entries);
    }

    function _exportSeigniorageDetfs(string memory chainIdStr) internal {
        (address detfAb, bool okAb) = _readAddressSafe("15_seigniorage_detfs.json", "detf_abVault");
        (address detfAc, bool okAc) = _readAddressSafe("15_seigniorage_detfs.json", "detf_acVault");
        (address detfBc, bool okBc) = _readAddressSafe("15_seigniorage_detfs.json", "detf_bcVault");
        (address detfAeroAb, bool okAeroAb) = _readAddressSafe("15_seigniorage_detfs.json", "detf_aeroAbVault");
        (address detfAeroAc, bool okAeroAc) = _readAddressSafe("15_seigniorage_detfs.json", "detf_aeroAcVault");
        (address detfAeroBc, bool okAeroBc) = _readAddressSafe("15_seigniorage_detfs.json", "detf_aeroBcVault");

        if (!(okAb && okAc && okBc && okAeroAb && okAeroAc && okAeroBc)) {
            _writeEmptyTokenlist("anvil_base_main-seigniorage-detfs.tokenlist.json");
            return;
        }

        if (
            detfAb == address(0) || detfAc == address(0) || detfBc == address(0) || detfAeroAb == address(0)
                || detfAeroAc == address(0) || detfAeroBc == address(0)
        ) {
            _writeEmptyTokenlist("anvil_base_main-seigniorage-detfs.tokenlist.json");
            return;
        }

        string[] memory entries = new string[](6);
        entries[0] = _tokenlistEntry(chainIdStr, detfAb, "Seigniorage DETF (abVault)", "sdetfAb");
        entries[1] = _tokenlistEntry(chainIdStr, detfAc, "Seigniorage DETF (acVault)", "sdetfAc");
        entries[2] = _tokenlistEntry(chainIdStr, detfBc, "Seigniorage DETF (bcVault)", "sdetfBc");
        entries[3] = _tokenlistEntry(chainIdStr, detfAeroAb, "Seigniorage DETF (aeroAbVault)", "sdetfAeroAb");
        entries[4] = _tokenlistEntry(chainIdStr, detfAeroAc, "Seigniorage DETF (aeroAcVault)", "sdetfAeroAc");
        entries[5] = _tokenlistEntry(chainIdStr, detfAeroBc, "Seigniorage DETF (aeroBcVault)", "sdetfAeroBc");
        _writeTokenlist("anvil_base_main-seigniorage-detfs.tokenlist.json", entries);
    }

    function _writeMarker() internal {
        // Write a small summary marker file for stage skip logic.
        string memory json = vm.serializeUint("summary", "chainId", block.chainid);
        json = vm.serializeString("summary", "exportedAt", vm.toString(block.timestamp));
        _writeJson(json, "14_export_tokenlists.json");
    }

    function run() external {
        _setup();
        _ensureOutDir();
        _logHeader("Stage 14: Export Segmented Tokenlists");

        string memory chainIdStr = vm.toString(block.chainid);

        _exportTestTokens(chainIdStr);
        _exportPools(chainIdStr);
        _exportStrategyVaults(chainIdStr);
        _exportBalancerPools(chainIdStr);
        _exportERC4626Vaults(chainIdStr);
        _exportSeigniorageDetfs(chainIdStr);
        _writeMarker();

        _logComplete("Stage 14: Export Segmented Tokenlists");
    }
}
