// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {FixtureGraph} from "./FixtureGraph.sol";

/// @title Script_14_ExportFrontendArtifacts
/// @notice Merge stage JSONs into chain/4663 platform.json + tokenlists.
contract Script_14_ExportFrontendArtifacts is DeploymentBase {
    string internal constant FRONTEND_DIR = "frontend/packages/protocol/src/addresses/chain/4663";
    string internal constant ARTIFACT_FILE = "14_frontend_export.json";

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        _logHeader("Stage 14: Export frontend artifacts (chain/4663)");

        vm.createDir(FRONTEND_DIR, true);

        _writePlatformJson();
        _writeBaseTokensTokenlist();
        _writeStrategyVaultsTokenlist();
        _writeProtocolDetfsTokenlist();

        string memory json;
        json = vm.serializeString("export", "frontendDir", FRONTEND_DIR);
        json = vm.serializeUint("export", "chainId", block.chainid);
        json = vm.serializeAddress("export", "deployer", deployer);
        json = vm.serializeAddress("export", "uiWallet", uiWallet);
        _writeJson(json, ARTIFACT_FILE);

        _logString("Frontend dir:", FRONTEND_DIR);
        _logComplete("Stage 14");
    }

    function _writePlatformJson() internal {
        string memory p = "platform";
        string memory out;

        // Preflight / RH pins
        out = vm.serializeUint(p, "chainId", uint256(4663));
        out = vm.serializeAddress(p, "poolManager", RobinhoodCanonicalLib.poolManager());
        out = vm.serializeAddress(p, "v3Factory", RobinhoodCanonicalLib.v3Factory());
        out = vm.serializeAddress(p, "v3Npm", RobinhoodCanonicalLib.v3Npm());
        out = vm.serializeAddress(p, "permit2", RobinhoodCanonicalLib.permit2());
        out = vm.serializeAddress(p, "weth", RobinhoodCanonicalLib.weth());
        out = vm.serializeAddress(p, "weth9", RobinhoodCanonicalLib.weth());
        out = vm.serializeAddress(p, "universalRouter", RobinhoodCanonicalLib.universalRouter());
        out = vm.serializeAddress(p, "positionManagerV4", RobinhoodCanonicalLib.positionManagerV4());

        // Stage 01
        out = vm.serializeAddress(p, "create3Factory", _safeRead("01_crane_foundation.json", "create3Factory"));
        out = vm.serializeAddress(p, "diamondPackageFactory", _safeRead("01_crane_foundation.json", "diamondPackageFactory"));
        out = vm.serializeAddress(p, "craneFactory", _safeRead("01_crane_foundation.json", "create3Factory"));
        out = vm.serializeAddress(p, "craneDiamondFactory", _safeRead("01_crane_foundation.json", "diamondPackageFactory"));

        // Stage 02
        out = vm.serializeAddress(p, "feeCollector", _safeRead("02_indexedex_core.json", "feeCollector"));
        out = vm.serializeAddress(p, "indexedexManager", _safeRead("02_indexedex_core.json", "indexedexManager"));
        out = vm.serializeAddress(p, "vaultRegistry", _safeRead("02_indexedex_core.json", "vaultRegistry"));
        out = vm.serializeAddress(p, "vaultFeeOracle", _safeRead("02_indexedex_core.json", "vaultFeeOracle"));

        // Stage 03
        out = vm.serializeAddress(p, "hookFactory", _safeRead("03_hook_factory.json", "hookFactory"));

        // Tokens
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

        // SE
        out = vm.serializeAddress(p, "uniV3Se_tt0_tt1", _safeRead("07_univ3_se.json", "uniV3Se_tt0_tt1"));
        out = vm.serializeAddress(p, "uniV3SePkg", _safeRead("07_univ3_se.json", "uniV3SePkg"));
        out = vm.serializeAddress(p, "uniV4Se_tt4_tt5", _safeRead("08_univ4_se.json", "uniV4Se_tt4_tt5"));
        out = vm.serializeAddress(p, "uniV4SePkg", _safeRead("08_univ4_se.json", "uniV4SePkg"));

        // RP
        out = vm.serializeAddress(p, "rp_v3Se_tt0_tt1", _safeRead("09_rate_providers.json", "rp_v3Se_tt0_tt1"));
        out = vm.serializeAddress(p, "rp_v4Se_tt4_tt5", _safeRead("09_rate_providers.json", "rp_v4Se_tt4_tt5"));
        out = vm.serializeAddress(p, "rateProviderPkg", _safeRead("09_rate_providers.json", "rateProviderPkg"));

        // Hook pkgs
        out = vm.serializeAddress(p, "cpHookPkg", _safeRead("10_hook_packages.json", "cpHookPkg"));
        out = vm.serializeAddress(p, "orbitalHookPkg", _safeRead("10_hook_packages.json", "orbitalHookPkg"));
        out = vm.serializeAddress(p, "weightedHookPkg", _safeRead("10_hook_packages.json", "weightedHookPkg"));
        out = vm.serializeAddress(p, "singleSeBufferHookPkg", _safeRead("10_hook_packages.json", "singleSeBufferHookPkg"));

        // DETF pkgs
        out = vm.serializeAddress(p, "cpDetfPkg", _safeRead("12_detf_packages.json", "cpDetfPkg"));
        out = vm.serializeAddress(p, "orbitalDetfPkg", _safeRead("12_detf_packages.json", "orbitalDetfPkg"));
        out = vm.serializeAddress(p, "weightedDetfPkg", _safeRead("12_detf_packages.json", "weightedDetfPkg"));
        out = vm.serializeAddress(p, "bondNftVaultPkg", _safeRead("11_detf_children.json", "bondNftVaultPkg"));
        out = vm.serializeAddress(p, "rebasingClaimTokenPkg", _safeRead("11_detf_children.json", "rebasingClaimTokenPkg"));

        // Demos
        out = vm.serializeAddress(p, "weightedBufferN8", _safeRead("13_inert_demos.json", "weightedBufferN8"));
        out = vm.serializeAddress(p, "singleSeBuffer_v3", _safeRead("13_inert_demos.json", "singleSeBuffer_v3"));
        out = vm.serializeAddress(p, "singleSeBuffer_v4", _safeRead("13_inert_demos.json", "singleSeBuffer_v4"));
        out = vm.serializeAddress(p, "cpDetfGentle", _safeRead("13_inert_demos.json", "cpDetfGentle"));
        out = vm.serializeAddress(p, "cpDetfLaunchRich", _safeRead("13_inert_demos.json", "cpDetfLaunchRich"));
        out = vm.serializeAddress(p, "orbitalDetfGentle", _safeRead("13_inert_demos.json", "orbitalDetfGentle"));
        out = vm.serializeAddress(p, "orbitalDetfLaunchRich", _safeRead("13_inert_demos.json", "orbitalDetfLaunchRich"));
        out = vm.serializeAddress(p, "weightedDetfGentle", _safeRead("13_inert_demos.json", "weightedDetfGentle"));
        out = vm.serializeAddress(p, "weightedDetfLaunchRich", _safeRead("13_inert_demos.json", "weightedDetfLaunchRich"));

        out = vm.serializeAddress(p, "deployer", deployer);
        out = vm.serializeAddress(p, "owner", owner);
        out = vm.serializeAddress(p, "uiWallet", uiWallet);
        out = vm.serializeString(p, "networkProfile", _networkProfile());
        out = vm.serializeString(p, "rpcUrl", "http://127.0.0.1:8545");

        vm.writeJson(out, string.concat(FRONTEND_DIR, "/platform.json"));
        // Also copy under deployments
        _writeJson(out, "platform.json");
    }

    function _writeBaseTokensTokenlist() internal {
        string memory list = "baseTokens";
        string memory out;
        out = vm.serializeString(list, "name", "Indexedex Robinhood Anvil Base Tokens");
        out = vm.serializeUint(list, "chainId", uint256(4663));

        // Build tokens array as JSON manually via nested serialize is hard; write simple file
        string memory tokensJson = "[";
        for (uint8 i; i < 8; ++i) {
            address addr = _safeRead("04_test_tokens.json", FixtureGraph.tokenSymbol(i));
            if (i > 0) tokensJson = string.concat(tokensJson, ",");
            tokensJson = string.concat(
                tokensJson,
                '{"chainId":4663,"address":"',
                _addrToString(addr),
                '","name":"',
                FixtureGraph.tokenName(i),
                '","symbol":"',
                FixtureGraph.tokenSymbol(i),
                '","decimals":18,"tags":["token","testToken"]}'
            );
        }
        tokensJson = string.concat(tokensJson, "]");

        string memory full = string.concat(
            '{"name":"Indexedex Robinhood Anvil Base Tokens","timestamp":"',
            vm.toString(block.timestamp),
            '","version":{"major":1,"minor":0,"patch":0},"keywords":["indexedex","tokens","robinhood"],"tokens":',
            tokensJson,
            "}"
        );
        vm.writeFile(string.concat(FRONTEND_DIR, "/base-tokens.tokenlist.json"), full);
    }

    function _writeStrategyVaultsTokenlist() internal {
        address v3 = _safeRead("07_univ3_se.json", "uniV3Se_tt0_tt1");
        address v4 = _safeRead("08_univ4_se.json", "uniV4Se_tt4_tt5");
        string memory full = string.concat(
            '{"name":"Indexedex Robinhood Anvil Strategy Vaults","timestamp":"',
            vm.toString(block.timestamp),
            '","version":{"major":1,"minor":0,"patch":0},"keywords":["indexedex","strategy","vault"],"tokens":[',
            _vaultEntry(v3, "Uni V3 SE TT0/TT1", "uv3se01"),
            ",",
            _vaultEntry(v4, "Uni V4 SE TT4/TT5", "uv4se45"),
            ",",
            _vaultEntry(_safeRead("13_inert_demos.json", "weightedBufferN8"), "Weighted Buffer n=8", "wgtBuf8"),
            ",",
            _vaultEntry(_safeRead("13_inert_demos.json", "singleSeBuffer_v3"), "Single SE Buffer V3", "sseBufV3"),
            ",",
            _vaultEntry(_safeRead("13_inert_demos.json", "singleSeBuffer_v4"), "Single SE Buffer V4", "sseBufV4"),
            "]}"
        );
        vm.writeFile(string.concat(FRONTEND_DIR, "/strategy-vaults.tokenlist.json"), full);
    }

    function _writeProtocolDetfsTokenlist() internal {
        string memory full = string.concat(
            '{"name":"Indexedex Robinhood Anvil Protocol DETFs","timestamp":"',
            vm.toString(block.timestamp),
            '","version":{"major":1,"minor":0,"patch":0},"keywords":["indexedex","detf"],"tokens":[',
            _vaultEntry(_safeRead("13_inert_demos.json", "cpDetfGentle"), "Gentle UniV4 CP DETF", "gCPDETF"),
            ",",
            _vaultEntry(_safeRead("13_inert_demos.json", "cpDetfLaunchRich"), "LaunchRich UniV4 CP DETF", "lrCPDETF"),
            ",",
            _vaultEntry(_safeRead("13_inert_demos.json", "orbitalDetfGentle"), "Gentle UniV4 Orb DETF", "gOrbDETF"),
            ",",
            _vaultEntry(_safeRead("13_inert_demos.json", "orbitalDetfLaunchRich"), "LaunchRich UniV4 Orb DETF", "lrOrbDETF"),
            ",",
            _vaultEntry(_safeRead("13_inert_demos.json", "weightedDetfGentle"), "Gentle UniV4 Wgt DETF n8", "gWgtDETF"),
            ",",
            _vaultEntry(_safeRead("13_inert_demos.json", "weightedDetfLaunchRich"), "LaunchRich UniV4 Wgt DETF n8", "lrWgtDETF"),
            "]}"
        );
        vm.writeFile(string.concat(FRONTEND_DIR, "/protocol-detfs.tokenlist.json"), full);
    }

    function _vaultEntry(address addr, string memory name, string memory symbol)
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
            '","decimals":18,"tags":["vault"]}'
        );
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
