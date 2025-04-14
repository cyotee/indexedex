// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";

contract Script_ExportTokenlists is DeploymentBase {
    string internal constant UI_PREFIX = "public_sepolia";

    function run() external {
        _setup();
        _ensureOutDir();

        string memory chainIdStr = vm.toString(block.chainid);

        _exportTestTokens(chainIdStr);
        _exportUniV2Pools(chainIdStr);
        _exportAerodromePools(chainIdStr);
        _exportStrategyVaults(chainIdStr);
        _exportAerodromeStrategyVaults(chainIdStr);
        _exportBalancerPools(chainIdStr);
        _exportERC4626Vaults(chainIdStr);
        _exportSeigniorageDetfs(chainIdStr);
        _exportProtocolDetf(chainIdStr);
    }

    function _uiTokenlistFilename(string memory suffix) internal pure returns (string memory) {
        return string.concat(UI_PREFIX, "-", suffix);
    }

    function _tokenName(address token, string memory fallbackName) internal view returns (string memory) {
        if (token.code.length == 0) return fallbackName;
        try IERC20Metadata(token).name() returns (string memory n) {
            return bytes(n).length == 0 ? fallbackName : n;
        } catch {
            return fallbackName;
        }
    }

    function _escapeJsonString(string memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        bytes memory out;
        for (uint256 i = 0; i < b.length; i++) {
            uint8 c = uint8(b[i]);
            if (c == uint8(bytes1('"'))) out = bytes.concat(out, bytes("\\\""));
            else if (c == uint8(bytes1('\\'))) out = bytes.concat(out, bytes("\\\\"));
            else if (c == 0x08) out = bytes.concat(out, bytes("\\b"));
            else if (c == 0x0C) out = bytes.concat(out, bytes("\\f"));
            else if (c == 0x0A) out = bytes.concat(out, bytes("\\n"));
            else if (c == 0x0D) out = bytes.concat(out, bytes("\\r"));
            else if (c == 0x09) out = bytes.concat(out, bytes("\\t"));
            else if (c < 0x20) out = bytes.concat(out, bytes(""));
            else out = bytes.concat(out, bytes1(bytes1(c)));
        }
        return string(out);
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
            out = i + 1 < entries.length ? string.concat(out, ",\n") : string.concat(out, "\n");
        }
        out = string.concat(out, "]\n");
        vm.writeFile(string.concat(_outDir(), "/", filename), out);
    }

    function _writeEmptyTokenlist(string memory filename) internal {
        vm.writeFile(string.concat(_outDir(), "/", filename), "[]\n");
    }

    function _exportTestTokens(string memory chainIdStr) internal {
        string[] memory entries = new string[](3);
        entries[0] = _tokenlistEntry(chainIdStr, _readAddress("05_test_tokens.json", "testTokenA"), "Test Token A", "TTA");
        entries[1] = _tokenlistEntry(chainIdStr, _readAddress("05_test_tokens.json", "testTokenB"), "Test Token B", "TTB");
        entries[2] = _tokenlistEntry(chainIdStr, _readAddress("05_test_tokens.json", "testTokenC"), "Test Token C", "TTC");
        _writeTokenlist(_uiTokenlistFilename("tokens.tokenlist.json"), entries);
    }

    function _exportUniV2Pools(string memory chainIdStr) internal {
        string[] memory entries = new string[](3);
        entries[0] = _tokenlistEntry(chainIdStr, _readAddress("06_pools.json", "abPool"), "ab UniV2 Pool", "abUniV2Pool");
        entries[1] = _tokenlistEntry(chainIdStr, _readAddress("06_pools.json", "acPool"), "ac UniV2 Pool", "acUniV2Pool");
        entries[2] = _tokenlistEntry(chainIdStr, _readAddress("06_pools.json", "bcPool"), "bc UniV2 Pool", "bcUniV2Pool");
        _writeTokenlist(_uiTokenlistFilename("uniV2pool.tokenlist.json"), entries);
    }

    function _exportAerodromePools(string memory chainIdStr) internal {
        string[] memory entries = new string[](3);
        entries[0] = _tokenlistEntry(chainIdStr, _readAddress("06_pools.json", "aeroAbPool"), "ab Aerodrome Pool", "aeroAbPool");
        entries[1] = _tokenlistEntry(chainIdStr, _readAddress("06_pools.json", "aeroAcPool"), "ac Aerodrome Pool", "aeroAcPool");
        entries[2] = _tokenlistEntry(chainIdStr, _readAddress("06_pools.json", "aeroBcPool"), "bc Aerodrome Pool", "aeroBcPool");
        _writeTokenlist(_uiTokenlistFilename("aerodrome-pools.tokenlist.json"), entries);
    }

    function _exportStrategyVaults(string memory chainIdStr) internal {
        string[] memory entries = new string[](3);
        entries[0] = _tokenlistEntry(chainIdStr, _readAddress("07_strategy_vaults.json", "abVault"), "ab UniV2 Pool Strategy Vault", "abSV");
        entries[1] = _tokenlistEntry(chainIdStr, _readAddress("07_strategy_vaults.json", "acVault"), "ac UniV2 Pool Strategy Vault", "acSV");
        entries[2] = _tokenlistEntry(chainIdStr, _readAddress("07_strategy_vaults.json", "bcVault"), "bc UniV2 Pool Strategy Vault", "bcSV");
        _writeTokenlist(_uiTokenlistFilename("strategy-vaults.tokenlist.json"), entries);
    }

    function _exportAerodromeStrategyVaults(string memory chainIdStr) internal {
        string[] memory entries = new string[](3);
        entries[0] = _tokenlistEntry(chainIdStr, _readAddress("08_aerodrome_strategy_vaults.json", "aeroAbVault"), "ab Aerodrome Pool Strategy Vault", "aeroAbSV");
        entries[1] = _tokenlistEntry(chainIdStr, _readAddress("08_aerodrome_strategy_vaults.json", "aeroAcVault"), "ac Aerodrome Pool Strategy Vault", "aeroAcSV");
        entries[2] = _tokenlistEntry(chainIdStr, _readAddress("08_aerodrome_strategy_vaults.json", "aeroBcVault"), "bc Aerodrome Pool Strategy Vault", "aeroBcSV");
        _writeTokenlist(_uiTokenlistFilename("aerodrome-strategy-vaults.tokenlist.json"), entries);
    }

    function _exportBalancerPools(string memory chainIdStr) internal {
        string[] memory constProdEntries = new string[](3);
        constProdEntries[0] = _tokenlistEntry(chainIdStr, _readAddress("12_balancer_const_prod_vault_token_pools.json", "balancerAbPool"), "ab BalancerV3 ConstProd Pool", "abBalancerV3ConstProdPool");
        constProdEntries[1] = _tokenlistEntry(chainIdStr, _readAddress("12_balancer_const_prod_vault_token_pools.json", "balancerAcPool"), "ac BalancerV3 ConstProd Pool", "acBalancerV3ConstProdPool");
        constProdEntries[2] = _tokenlistEntry(chainIdStr, _readAddress("12_balancer_const_prod_vault_token_pools.json", "balancerBcPool"), "bc BalancerV3 ConstProd Pool", "bcBalancerV3ConstProdPool");
        _writeTokenlist(_uiTokenlistFilename("balancerv3-constprod-pools.tokenlist.json"), constProdEntries);

        string[] memory vaultTokenEntries = new string[](12);
        vaultTokenEntries[0] = _tokenlistEntry(chainIdStr, _readAddress("12_balancer_const_prod_vault_token_pools.json", "balUniAbWithA"), "UniV2 AB Vault + ttA BalancerV3 Pool", "uniAbVault_ttA_BalancerPool");
        vaultTokenEntries[1] = _tokenlistEntry(chainIdStr, _readAddress("12_balancer_const_prod_vault_token_pools.json", "balUniAbWithB"), "UniV2 AB Vault + ttB BalancerV3 Pool", "uniAbVault_ttB_BalancerPool");
        vaultTokenEntries[2] = _tokenlistEntry(chainIdStr, _readAddress("12_balancer_const_prod_vault_token_pools.json", "balUniAcWithA"), "UniV2 AC Vault + ttA BalancerV3 Pool", "uniAcVault_ttA_BalancerPool");
        vaultTokenEntries[3] = _tokenlistEntry(chainIdStr, _readAddress("12_balancer_const_prod_vault_token_pools.json", "balUniAcWithC"), "UniV2 AC Vault + ttC BalancerV3 Pool", "uniAcVault_ttc_BalancerPool");
        vaultTokenEntries[4] = _tokenlistEntry(chainIdStr, _readAddress("12_balancer_const_prod_vault_token_pools.json", "balUniBcWithB"), "UniV2 BC Vault + ttB BalancerV3 Pool", "uniBcVault_ttB_BalancerPool");
        vaultTokenEntries[5] = _tokenlistEntry(chainIdStr, _readAddress("12_balancer_const_prod_vault_token_pools.json", "balUniBcWithC"), "UniV2 BC Vault + ttC BalancerV3 Pool", "uniBcVault_ttc_BalancerPool");
        vaultTokenEntries[6] = _tokenlistEntry(chainIdStr, _readAddress("12_balancer_const_prod_vault_token_pools.json", "balAeroAbWithA"), "Aerodrome AB Vault + ttA BalancerV3 Pool", "aeroAbVault_ttA_BalancerPool");
        vaultTokenEntries[7] = _tokenlistEntry(chainIdStr, _readAddress("12_balancer_const_prod_vault_token_pools.json", "balAeroAbWithB"), "Aerodrome AB Vault + ttB BalancerV3 Pool", "aeroAbVault_ttB_BalancerPool");
        vaultTokenEntries[8] = _tokenlistEntry(chainIdStr, _readAddress("12_balancer_const_prod_vault_token_pools.json", "balAeroAcWithA"), "Aerodrome AC Vault + ttA BalancerV3 Pool", "aeroAcVault_ttA_BalancerPool");
        vaultTokenEntries[9] = _tokenlistEntry(chainIdStr, _readAddress("12_balancer_const_prod_vault_token_pools.json", "balAeroAcWithC"), "Aerodrome AC Vault + ttC BalancerV3 Pool", "aeroAcVault_ttc_BalancerPool");
        vaultTokenEntries[10] = _tokenlistEntry(chainIdStr, _readAddress("12_balancer_const_prod_vault_token_pools.json", "balAeroBcWithB"), "Aerodrome BC Vault + ttB BalancerV3 Pool", "aeroBcVault_ttB_BalancerPool");
        vaultTokenEntries[11] = _tokenlistEntry(chainIdStr, _readAddress("12_balancer_const_prod_vault_token_pools.json", "balAeroBcWithC"), "Aerodrome BC Vault + ttC BalancerV3 Pool", "aeroBcVault_ttc_BalancerPool");
        _writeTokenlist(_uiTokenlistFilename("balancerv3-vault-token-pools.tokenlist.json"), vaultTokenEntries);

        string[] memory combinedEntries = new string[](15);
        combinedEntries[0] = constProdEntries[0];
        combinedEntries[1] = constProdEntries[1];
        combinedEntries[2] = constProdEntries[2];
        for (uint256 i = 0; i < 12; i++) {
            combinedEntries[3 + i] = vaultTokenEntries[i];
        }
        _writeTokenlist(_uiTokenlistFilename("balancerv3-pools.tokenlist.json"), combinedEntries);
    }

    function _exportERC4626Vaults(string memory chainIdStr) internal {
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
        if (!(okChir && okRich && okRichir) || chir == address(0) || rich == address(0) || richir == address(0)) {
            _writeEmptyTokenlist(_uiTokenlistFilename("protocol-detf.tokenlist.json"));
            return;
        }

        string[] memory entries = new string[](3);
        entries[0] = _tokenlistEntry(chainIdStr, chir, "Protocol DETF (CHIR)", "CHIR");
        entries[1] = _tokenlistEntry(chainIdStr, rich, "RICH Token", "RICH");
        entries[2] = _tokenlistEntry(chainIdStr, richir, "RICHIR Token", "RICHIR");
        _writeTokenlist(_uiTokenlistFilename("protocol-detf.tokenlist.json"), entries);
    }
}
