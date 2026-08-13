// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {FixtureGraph} from "./FixtureGraph.sol";
import {FixtureEconomics} from "./FixtureEconomics.sol";

/// @dev Minimal views for DETF → reserve hook export (all Uni V4 SE DETF families).
interface IDetfReserveHookView {
    function reserveHook() external view returns (address);
}

interface IErc20MetaView {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
}

/// @title Script_22_ExportFrontendArtifacts
/// @notice Merge lab demos + fee-DETF (CHIR) into chain/4663 platform.json + tokenlists.
/// @dev Strategy vaults include standalone buffers/SEs **and** every DETF reserveHook
///      (ConstProd / Orbital / Weighted / fee) so Earn lists all pools.
contract Script_22_ExportFrontendArtifacts is DeploymentBase {
    string internal constant FRONTEND_DIR = "frontend/packages/protocol/src/addresses/chain/4663";
    string internal constant ARTIFACT_FILE = "22_frontend_export.json";

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        _logHeader("Stage 22: Export frontend artifacts (lab + fee-DETF chain/4663)");

        vm.createDir(FRONTEND_DIR, true);

        _writePlatformJson();
        _writeBaseTokensTokenlist();
        _writeStrategyVaultsTokenlist();
        _writeProtocolDetfsTokenlist();
        _writeFeaturedFeeDetfsTokenlist();

        string memory json;
        json = vm.serializeString("export", "frontendDir", FRONTEND_DIR);
        json = vm.serializeUint("export", "chainId", block.chainid);
        json = vm.serializeAddress("export", "deployer", deployer);
        json = vm.serializeAddress("export", "uiWallet", uiWallet);
        json = vm.serializeAddress("export", "chir", _safeRead("18_chir_instance.json", "chir"));
        json = vm.serializeAddress("export", "rich", _safeRead("14_pons_rich.json", "rich"));
        json = vm.serializeString("export", "networkProfile", _networkProfile());
        _writeJson(json, ARTIFACT_FILE);

        _logString("Frontend dir:", FRONTEND_DIR);
        _logComplete("Stage 22");
    }

    function _writePlatformJson() internal {
        string memory p = "platform";
        string memory out;

        out = vm.serializeUint(p, "chainId", uint256(4663));
        out = vm.serializeAddress(p, "poolManager", RobinhoodCanonicalLib.poolManager());
        out = vm.serializeAddress(p, "v3Factory", RobinhoodCanonicalLib.v3Factory());
        out = vm.serializeAddress(p, "v3Npm", RobinhoodCanonicalLib.v3Npm());
        out = vm.serializeAddress(p, "permit2", RobinhoodCanonicalLib.permit2());
        out = vm.serializeAddress(p, "weth", RobinhoodCanonicalLib.weth());
        out = vm.serializeAddress(p, "weth9", RobinhoodCanonicalLib.weth());
        out = vm.serializeAddress(p, "universalRouter", RobinhoodCanonicalLib.universalRouter());
        out = vm.serializeAddress(p, "positionManagerV4", RobinhoodCanonicalLib.positionManagerV4());
        out = vm.serializeAddress(p, "v3SwapRouter", FixtureEconomics.PONS_V3_SWAP_ROUTER);

        // Crane / core / hook factory
        out = vm.serializeAddress(p, "create3Factory", _safeRead("01_crane_foundation.json", "create3Factory"));
        out = vm.serializeAddress(p, "diamondPackageFactory", _safeRead("01_crane_foundation.json", "diamondPackageFactory"));
        out = vm.serializeAddress(p, "craneFactory", _safeRead("01_crane_foundation.json", "create3Factory"));
        out = vm.serializeAddress(p, "craneDiamondFactory", _safeRead("01_crane_foundation.json", "diamondPackageFactory"));
        out = vm.serializeAddress(p, "feeCollector", _safeRead("02_indexedex_core.json", "feeCollector"));
        out = vm.serializeAddress(p, "indexedexManager", _safeRead("02_indexedex_core.json", "indexedexManager"));
        out = vm.serializeAddress(p, "vaultRegistry", _safeRead("02_indexedex_core.json", "vaultRegistry"));
        out = vm.serializeAddress(p, "vaultFeeOracle", _safeRead("02_indexedex_core.json", "vaultFeeOracle"));
        out = vm.serializeAddress(p, "hookFactory", _safeRead("03_hook_factory.json", "hookFactory"));

        // Lab TT0–TT7
        for (uint8 i; i < 8; ++i) {
            out = vm.serializeAddress(p, FixtureGraph.tokenSymbol(i), _safeRead("04_test_tokens.json", FixtureGraph.tokenSymbol(i)));
        }
        out = vm.serializeAddress(p, "tt0", _safeRead("04_test_tokens.json", "tt0"));
        out = vm.serializeAddress(p, "tt1", _safeRead("04_test_tokens.json", "tt1"));
        out = vm.serializeAddress(p, "tt2", _safeRead("04_test_tokens.json", "tt2"));
        out = vm.serializeAddress(p, "tt3", _safeRead("04_test_tokens.json", "tt3"));
        out = vm.serializeAddress(p, "tt4", _safeRead("04_test_tokens.json", "tt4"));
        out = vm.serializeAddress(p, "tt5", _safeRead("04_test_tokens.json", "tt5"));
        out = vm.serializeAddress(p, "tt6", _safeRead("04_test_tokens.json", "tt6"));
        out = vm.serializeAddress(p, "tt7", _safeRead("04_test_tokens.json", "tt7"));

        // Lab SE
        out = vm.serializeAddress(p, "uniV3Se_tt0_tt1", _safeRead("07_univ3_se.json", "uniV3Se_tt0_tt1"));
        out = vm.serializeAddress(p, "uniV3SePkg", _safeRead("07_univ3_se.json", "uniV3SePkg"));
        out = vm.serializeAddress(p, "uniV4Se_tt4_tt5", _safeRead("08_univ4_se.json", "uniV4Se_tt4_tt5"));
        out = vm.serializeAddress(p, "uniV4SePkg", _safeRead("08_univ4_se.json", "uniV4SePkg"));

        // Lab RP
        out = vm.serializeAddress(p, "rp_v3Se_tt0_tt1", _safeRead("09_rate_providers.json", "rp_v3Se_tt0_tt1"));
        out = vm.serializeAddress(p, "rp_v4Se_tt4_tt5", _safeRead("09_rate_providers.json", "rp_v4Se_tt4_tt5"));
        out = vm.serializeAddress(p, "rateProviderPkg", _safeRead("09_rate_providers.json", "rateProviderPkg"));

        // Lab hook / DETF packages
        out = vm.serializeAddress(p, "cpHookPkg", _safeRead("10_hook_packages.json", "cpHookPkg"));
        out = vm.serializeAddress(p, "orbitalHookPkg", _safeRead("10_hook_packages.json", "orbitalHookPkg"));
        out = vm.serializeAddress(p, "weightedHookPkg", _safeRead("10_hook_packages.json", "weightedHookPkg"));
        out = vm.serializeAddress(p, "singleSeBufferHookPkg", _safeRead("10_hook_packages.json", "singleSeBufferHookPkg"));
        out = vm.serializeAddress(p, "cpDetfPkg", _safeRead("12_detf_packages.json", "cpDetfPkg"));
        out = vm.serializeAddress(p, "orbitalDetfPkg", _safeRead("12_detf_packages.json", "orbitalDetfPkg"));
        out = vm.serializeAddress(p, "weightedDetfPkg", _safeRead("12_detf_packages.json", "weightedDetfPkg"));
        out = vm.serializeAddress(p, "bondNftVaultPkg", _safeRead("11_detf_children.json", "bondNftVaultPkg"));
        out = vm.serializeAddress(p, "rebasingClaimTokenPkg", _safeRead("11_detf_children.json", "rebasingClaimTokenPkg"));

        // Lab inert demos
        out = vm.serializeAddress(p, "weightedBufferN8", _safeRead("13_inert_demos.json", "weightedBufferN8"));
        out = vm.serializeAddress(p, "singleSeBuffer_v3", _safeRead("13_inert_demos.json", "singleSeBuffer_v3"));
        out = vm.serializeAddress(p, "singleSeBuffer_v4", _safeRead("13_inert_demos.json", "singleSeBuffer_v4"));
        out = vm.serializeAddress(p, "cpDetfGentle", _safeRead("13_inert_demos.json", "cpDetfGentle"));
        out = vm.serializeAddress(p, "cpDetfLaunchRich", _safeRead("13_inert_demos.json", "cpDetfLaunchRich"));
        out = vm.serializeAddress(p, "orbitalDetfGentle", _safeRead("13_inert_demos.json", "orbitalDetfGentle"));
        out = vm.serializeAddress(p, "orbitalDetfLaunchRich", _safeRead("13_inert_demos.json", "orbitalDetfLaunchRich"));
        out = vm.serializeAddress(p, "weightedDetfGentle", _safeRead("13_inert_demos.json", "weightedDetfGentle"));
        out = vm.serializeAddress(p, "weightedDetfLaunchRich", _safeRead("13_inert_demos.json", "weightedDetfLaunchRich"));

        // Fee-DETF path (stages 14–20)
        out = vm.serializeAddress(p, "ponsFactory", FixtureEconomics.PONS_FACTORY);
        out = vm.serializeAddress(p, "rich", _safeRead("14_pons_rich.json", "rich"));
        out = vm.serializeAddress(p, "richWethPool", _safeRead("14_pons_rich.json", "pool"));
        out = vm.serializeAddress(p, "uniV3Se_rich", _safeRead("15_univ3_se_rich.json", "uniV3Se_rich"));
        out = vm.serializeAddress(p, "uniV3SePkg_rich", _safeRead("15_univ3_se_rich.json", "uniV3SePkg"));
        out = vm.serializeAddress(p, "rp_se_rich_weth", _safeRead("16_fee_detf_rate_provider.json", "rp_se_rich_weth"));
        out = vm.serializeAddress(p, "bufferCpHookPkg", _safeRead("17_fee_detf_packages.json", "bufferCpHookPkg"));
        out = vm.serializeAddress(p, "chirDetfPkg", _safeRead("17_fee_detf_packages.json", "chirDetfPkg"));
        out = vm.serializeAddress(p, "chir", _safeRead("18_chir_instance.json", "chir"));
        out = vm.serializeAddress(p, "feeDetf", _safeRead("18_chir_instance.json", "chir"));
        out = vm.serializeAddress(p, "reserveHook", _safeRead("18_chir_instance.json", "reserveHook"));
        // DETF-owned reserve pools (hooks) — same addresses listed under strategy-vaults.
        out = vm.serializeAddress(p, "chirReserveHook", _tryReserveHook(_safeRead("18_chir_instance.json", "chir")));
        out = vm.serializeAddress(p, "cpDetfGentleReserveHook", _tryReserveHook(_safeRead("13_inert_demos.json", "cpDetfGentle")));
        out = vm.serializeAddress(
            p, "cpDetfLaunchRichReserveHook", _tryReserveHook(_safeRead("13_inert_demos.json", "cpDetfLaunchRich"))
        );
        out = vm.serializeAddress(
            p, "orbitalDetfGentleReserveHook", _tryReserveHook(_safeRead("13_inert_demos.json", "orbitalDetfGentle"))
        );
        out = vm.serializeAddress(
            p,
            "orbitalDetfLaunchRichReserveHook",
            _tryReserveHook(_safeRead("13_inert_demos.json", "orbitalDetfLaunchRich"))
        );
        out = vm.serializeAddress(
            p, "weightedDetfGentleReserveHook", _tryReserveHook(_safeRead("13_inert_demos.json", "weightedDetfGentle"))
        );
        out = vm.serializeAddress(
            p,
            "weightedDetfLaunchRichReserveHook",
            _tryReserveHook(_safeRead("13_inert_demos.json", "weightedDetfLaunchRich"))
        );
        out = vm.serializeUint(p, "creationPairPerDetfWad", FixtureEconomics.creationPairPerDetfWad());
        out = vm.serializeString(p, "feeDetfTemplate", "launch-rich");

        out = vm.serializeAddress(p, "deployer", deployer);
        out = vm.serializeAddress(p, "owner", owner);
        out = vm.serializeAddress(p, "uiWallet", uiWallet);
        out = vm.serializeString(p, "networkProfile", _networkProfile());
        out = vm.serializeString(p, "rpcUrl", "http://127.0.0.1:8545");

        vm.writeJson(out, string.concat(FRONTEND_DIR, "/platform.json"));
        _writeJson(out, "platform.json");
    }

    function _writeBaseTokensTokenlist() internal {
        address weth = RobinhoodCanonicalLib.weth();
        address rich = _safeRead("14_pons_rich.json", "rich");

        string memory tokensJson = "[";
        for (uint8 i; i < 8; ++i) {
            address addr = _safeRead("04_test_tokens.json", FixtureGraph.tokenSymbol(i));
            if (i > 0) tokensJson = string.concat(tokensJson, ",");
            tokensJson = string.concat(
                tokensJson,
                _tokenEntry(addr, FixtureGraph.tokenName(i), FixtureGraph.tokenSymbol(i), '["token","testToken"]')
            );
        }
        tokensJson = string.concat(
            tokensJson,
            ",",
            _tokenEntry(weth, "Wrapped Ether", "WETH", '["token","weth"]'),
            ",",
            _tokenEntry(rich, "RICH", "RICH", '["token","pons-launch","rich"]'),
            "]"
        );

        string memory full = string.concat(
            '{"name":"Indexedex Robinhood Anvil Base Tokens","timestamp":"',
            vm.toString(block.timestamp),
            '","version":{"major":1,"minor":0,"patch":0},"keywords":["indexedex","tokens","robinhood","fee-detf"],"tokens":',
            tokensJson,
            "}"
        );
        vm.writeFile(string.concat(FRONTEND_DIR, "/base-tokens.tokenlist.json"), full);
    }

    function _writeStrategyVaultsTokenlist() internal {
        address v3 = _safeRead("07_univ3_se.json", "uniV3Se_tt0_tt1");
        address v4 = _safeRead("08_univ4_se.json", "uniV4Se_tt4_tt5");
        address seRich = _safeRead("15_univ3_se_rich.json", "uniV3Se_rich");

        // Standalone strategy pools first, then every DETF-owned reserve hook (pool).
        string memory tokensJson = string.concat(
            _vaultEntry(v3, "Uni V3 SE TT0/TT1", "uv3se01", '["vault","se","strat"]'),
            ",",
            _vaultEntry(v4, "Uni V4 SE TT4/TT5", "uv4se45", '["vault","se","strat"]'),
            ",",
            _vaultEntry(seRich, "Uni V3 SE RICH/WETH", "uv3seRICH", '["vault","se","strat","fee-detf"]'),
            ",",
            _vaultEntry(
                _safeRead("13_inert_demos.json", "weightedBufferN8"),
                "Weighted Buffer n=8",
                "wgtBuf8",
                '["vault","strat"]'
            ),
            ",",
            _vaultEntry(
                _safeRead("13_inert_demos.json", "singleSeBuffer_v3"),
                "Single SE Buffer V3",
                "sseBufV3",
                '["vault","strat"]'
            ),
            ",",
            _vaultEntry(
                _safeRead("13_inert_demos.json", "singleSeBuffer_v4"),
                "Single SE Buffer V4",
                "sseBufV4",
                '["vault","strat"]'
            )
        );

        // DETF reserve hooks — product pools created in DETF postDeploy (not standalone demos).
        // Tags: strat → Earn preferred strategy catalog; detf-reserve → owned by a DETF.
        tokensJson = _appendDetfReserveHook(
            tokensJson,
            _safeRead("18_chir_instance.json", "chir"),
            "Fee DETF Reserve (ConstProd)",
            "chirReserve",
            '["vault","strat","detf-reserve","fee-detf"]'
        );
        tokensJson = _appendDetfReserveHook(
            tokensJson,
            _safeRead("13_inert_demos.json", "cpDetfGentle"),
            "Gentle ConstProd DETF Reserve",
            "gConstProdReserve",
            '["vault","strat","detf-reserve"]'
        );
        tokensJson = _appendDetfReserveHook(
            tokensJson,
            _safeRead("13_inert_demos.json", "cpDetfLaunchRich"),
            "LaunchRich ConstProd DETF Reserve",
            "lrConstProdReserve",
            '["vault","strat","detf-reserve"]'
        );
        tokensJson = _appendDetfReserveHook(
            tokensJson,
            _safeRead("13_inert_demos.json", "orbitalDetfGentle"),
            "Gentle Orbital DETF Reserve",
            "gOrbReserve",
            '["vault","strat","detf-reserve","orbital"]'
        );
        tokensJson = _appendDetfReserveHook(
            tokensJson,
            _safeRead("13_inert_demos.json", "orbitalDetfLaunchRich"),
            "LaunchRich Orbital DETF Reserve",
            "lrOrbReserve",
            '["vault","strat","detf-reserve","orbital"]'
        );
        tokensJson = _appendDetfReserveHook(
            tokensJson,
            _safeRead("13_inert_demos.json", "weightedDetfGentle"),
            "Gentle Weighted DETF Reserve n8",
            "gWgtReserve",
            '["vault","strat","detf-reserve"]'
        );
        tokensJson = _appendDetfReserveHook(
            tokensJson,
            _safeRead("13_inert_demos.json", "weightedDetfLaunchRich"),
            "LaunchRich Weighted DETF Reserve n8",
            "lrWgtReserve",
            '["vault","strat","detf-reserve"]'
        );

        string memory full = string.concat(
            '{"name":"Indexedex Robinhood Anvil Strategy Vaults","timestamp":"',
            vm.toString(block.timestamp),
            '","version":{"major":1,"minor":0,"patch":0},"keywords":["indexedex","strategy","vault","fee-detf","detf-reserve"],"tokens":[',
            tokensJson,
            "]}"
        );
        vm.writeFile(string.concat(FRONTEND_DIR, "/strategy-vaults.tokenlist.json"), full);
    }

    /// @dev Append DETF.reserveHook() as a strategy vault row when present on-chain.
    function _appendDetfReserveHook(
        string memory tokensJson_,
        address detf_,
        string memory fallbackName_,
        string memory fallbackSymbol_,
        string memory tagsJson_
    ) internal view returns (string memory) {
        address hook_ = _tryReserveHook(detf_);
        if (hook_ == address(0)) return tokensJson_;

        string memory name_ = fallbackName_;
        string memory symbol_ = fallbackSymbol_;
        try IErc20MetaView(hook_).name() returns (string memory n_) {
            if (bytes(n_).length > 0) name_ = n_;
        } catch {}
        try IErc20MetaView(hook_).symbol() returns (string memory s_) {
            if (bytes(s_).length > 0) symbol_ = s_;
        } catch {}

        return string.concat(tokensJson_, ",", _vaultEntry(hook_, name_, symbol_, tagsJson_));
    }

    function _tryReserveHook(address detf_) internal view returns (address hook_) {
        if (detf_ == address(0) || detf_.code.length == 0) return address(0);
        try IDetfReserveHookView(detf_).reserveHook() returns (address h_) {
            if (h_ != address(0) && h_.code.length > 0) return h_;
        } catch {}
        return address(0);
    }

    function _writeProtocolDetfsTokenlist() internal {
        address chir = _safeRead("18_chir_instance.json", "chir");
        string memory full = string.concat(
            '{"name":"Indexedex Robinhood Anvil Protocol DETFs","timestamp":"',
            vm.toString(block.timestamp),
            '","version":{"major":1,"minor":0,"patch":0},"keywords":["indexedex","detf","fee-detf"],"tokens":[',
            _vaultEntry(chir, "IndexedEx Fee DETF", "CHIR", '["vault","detf","fee-detf"]'),
            ",",
            _vaultEntry(
                _safeRead("13_inert_demos.json", "cpDetfGentle"),
                "Gentle UniV4 ConstProd DETF",
                "gConstProdDETF",
                '["vault","detf"]'
            ),
            ",",
            _vaultEntry(
                _safeRead("13_inert_demos.json", "cpDetfLaunchRich"),
                "LaunchRich UniV4 ConstProd DETF",
                "lrConstProdDETF",
                '["vault","detf"]'
            ),
            ",",
            _vaultEntry(_safeRead("13_inert_demos.json", "orbitalDetfGentle"), "Gentle UniV4 Orb DETF", "gOrbDETF", '["vault","detf"]'),
            ",",
            _vaultEntry(
                _safeRead("13_inert_demos.json", "orbitalDetfLaunchRich"),
                "LaunchRich UniV4 Orb DETF",
                "lrOrbDETF",
                '["vault","detf"]'
            ),
            ",",
            _vaultEntry(_safeRead("13_inert_demos.json", "weightedDetfGentle"), "Gentle UniV4 Wgt DETF n8", "gWgtDETF", '["vault","detf"]'),
            ",",
            _vaultEntry(
                _safeRead("13_inert_demos.json", "weightedDetfLaunchRich"),
                "LaunchRich UniV4 Wgt DETF n8",
                "lrWgtDETF",
                '["vault","detf"]'
            ),
            "]}"
        );
        vm.writeFile(string.concat(FRONTEND_DIR, "/protocol-detfs.tokenlist.json"), full);
    }

    function _writeFeaturedFeeDetfsTokenlist() internal {
        address chir = _safeRead("18_chir_instance.json", "chir");
        string memory full = string.concat(
            '{"name":"Indexedex Robinhood Featured Fee DETFs","timestamp":"',
            vm.toString(block.timestamp),
            '","version":{"major":1,"minor":0,"patch":0},"keywords":["indexedex","featured","fee-detf"],"tokens":[',
            _vaultEntry(chir, "IndexedEx Fee DETF", "CHIR", '["vault","detf","fee-detf","featured"]'),
            "]}"
        );
        vm.writeFile(string.concat(FRONTEND_DIR, "/featured-fee-detfs.tokenlist.json"), full);
    }

    function _tokenEntry(address addr, string memory name, string memory symbol, string memory tagsJson)
        internal
        pure
        returns (string memory)
    {
        return string.concat(
            '{"chainId":4663,"address":"',
            _addrToString(addr),
            '","name":"',
            name,
            '","symbol":"',
            symbol,
            '","decimals":18,"tags":',
            tagsJson,
            "}"
        );
    }

    function _vaultEntry(address addr, string memory name, string memory symbol, string memory tagsJson)
        internal
        pure
        returns (string memory)
    {
        return _tokenEntry(addr, name, symbol, tagsJson);
    }

    function _addrToString(address addr) internal pure returns (string memory) {
        bytes16 hexSymbols = "0123456789abcdef";
        bytes memory buffer = new bytes(42);
        buffer[0] = "0";
        buffer[1] = "x";
        uint160 value = uint160(addr);
        for (uint256 i = 41; i > 1; --i) {
            buffer[i] = hexSymbols[value & 0xf];
            value >>= 4;
        }
        return string(buffer);
    }

    function _safeRead(string memory file, string memory key) internal view returns (address) {
        (address a,) = _readAddressSafe(file, key);
        return a;
    }
}
