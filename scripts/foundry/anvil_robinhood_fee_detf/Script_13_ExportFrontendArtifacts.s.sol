// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {FixtureEconomics} from "./FixtureEconomics.sol";

/// @title Script_13_ExportFrontendArtifacts
/// @notice Export chain/4663 platform.json + tokenlists for fee-DETF launch (no Balancer).
contract Script_13_ExportFrontendArtifacts is DeploymentBase {
    string internal constant FRONTEND_DIR = "frontend/packages/protocol/src/addresses/chain/4663";
    string internal constant ARTIFACT_FILE = "13_frontend_export.json";

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        _logHeader("Stage 13: Export frontend artifacts (chain/4663 fee-DETF)");

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
        json = vm.serializeAddress("export", "rich", _safeRead("04_pons_rich.json", "rich"));
        json = vm.serializeAddress("export", "chir", _safeRead("09_chir_instance.json", "chir"));
        json = vm.serializeAddress("export", "reserveHook", _safeRead("09_chir_instance.json", "reserveHook"));
        json = vm.serializeAddress("export", "uniV3Se_rich", _safeRead("05_univ3_se_rich.json", "uniV3Se_rich"));
        json = vm.serializeUint("export", "creationPairPerDetfWad", FixtureEconomics.creationPairPerDetfWad());
        _writeJson(json, ARTIFACT_FILE);

        _logString("Frontend dir:", FRONTEND_DIR);
        _logComplete("Stage 13");
    }

    function _writePlatformJson() internal {
        string memory p = "platform";
        string memory out;

        out = vm.serializeUint(p, "chainId", uint256(4663));
        out = vm.serializeString(p, "networkProfile", _networkProfile());
        out = vm.serializeString(p, "rpcUrl", "http://127.0.0.1:8545");

        // RH pins
        out = vm.serializeAddress(p, "poolManager", RobinhoodCanonicalLib.poolManager());
        out = vm.serializeAddress(p, "v3Factory", RobinhoodCanonicalLib.v3Factory());
        out = vm.serializeAddress(p, "v3Npm", RobinhoodCanonicalLib.v3Npm());
        out = vm.serializeAddress(p, "permit2", RobinhoodCanonicalLib.permit2());
        out = vm.serializeAddress(p, "weth", RobinhoodCanonicalLib.weth());
        out = vm.serializeAddress(p, "weth9", RobinhoodCanonicalLib.weth());
        out = vm.serializeAddress(p, "universalRouter", RobinhoodCanonicalLib.universalRouter());
        out = vm.serializeAddress(p, "positionManagerV4", RobinhoodCanonicalLib.positionManagerV4());
        out = vm.serializeAddress(p, "v3SwapRouter", RobinhoodCanonicalLib.v3SwapRouter());

        // Crane / core
        out = vm.serializeAddress(p, "create3Factory", _safeRead("01_crane_foundation.json", "create3Factory"));
        out = vm.serializeAddress(p, "diamondPackageFactory", _safeRead("01_crane_foundation.json", "diamondPackageFactory"));
        out = vm.serializeAddress(p, "craneFactory", _safeRead("01_crane_foundation.json", "create3Factory"));
        out = vm.serializeAddress(p, "craneDiamondFactory", _safeRead("01_crane_foundation.json", "diamondPackageFactory"));
        out = vm.serializeAddress(p, "feeCollector", _safeRead("02_indexedex_core.json", "feeCollector"));
        out = vm.serializeAddress(p, "indexedexManager", _safeRead("02_indexedex_core.json", "indexedexManager"));
        out = vm.serializeAddress(p, "vaultRegistry", _safeRead("02_indexedex_core.json", "vaultRegistry"));
        out = vm.serializeAddress(p, "vaultFeeOracle", _safeRead("02_indexedex_core.json", "vaultFeeOracle"));
        out = vm.serializeAddress(p, "hookFactory", _safeRead("03_hook_factory.json", "hookFactory"));

        // pons / RICH
        out = vm.serializeAddress(p, "ponsFactory", FixtureEconomics.PONS_FACTORY);
        out = vm.serializeAddress(p, "rich", _safeRead("04_pons_rich.json", "rich"));
        out = vm.serializeAddress(p, "richWethPool", _safeRead("04_pons_rich.json", "pool"));

        // SE / RP
        out = vm.serializeAddress(p, "uniV3Se_rich", _safeRead("05_univ3_se_rich.json", "uniV3Se_rich"));
        out = vm.serializeAddress(p, "uniV3SePkg", _safeRead("05_univ3_se_rich.json", "uniV3SePkg"));
        out = vm.serializeAddress(p, "rp_se_rich_weth", _safeRead("06_rate_provider.json", "rp_se_rich_weth"));

        // Packages
        out = vm.serializeAddress(p, "bufferCpHookPkg", _safeRead("08_fee_detf_packages.json", "bufferCpHookPkg"));
        out = vm.serializeAddress(p, "chirDetfPkg", _safeRead("08_fee_detf_packages.json", "chirDetfPkg"));
        out = vm.serializeAddress(p, "bondNftVaultPkg", _safeRead("07_detf_children.json", "bondNftVaultPkg"));
        out = vm.serializeAddress(p, "rebasingClaimTokenPkg", _safeRead("07_detf_children.json", "rebasingClaimTokenPkg"));

        // CHIR instance
        out = vm.serializeAddress(p, "chir", _safeRead("09_chir_instance.json", "chir"));
        out = vm.serializeAddress(p, "feeDetf", _safeRead("09_chir_instance.json", "chir"));
        out = vm.serializeAddress(p, "reserveHook", _safeRead("09_chir_instance.json", "reserveHook"));
        out = vm.serializeUint(p, "creationPairPerDetfWad", FixtureEconomics.creationPairPerDetfWad());
        out = vm.serializeString(p, "feeDetfTemplate", "launch-rich");

        out = vm.serializeAddress(p, "deployer", deployer);
        out = vm.serializeAddress(p, "owner", owner);
        out = vm.serializeAddress(p, "uiWallet", uiWallet);

        vm.writeJson(out, string.concat(FRONTEND_DIR, "/platform.json"));
        _writeJson(out, "platform.json");
    }

    function _writeBaseTokensTokenlist() internal {
        address weth = RobinhoodCanonicalLib.weth();
        address rich = _safeRead("04_pons_rich.json", "rich");
        string memory full = string.concat(
            '{"name":"Indexedex Robinhood Fee-DETF Base Tokens","timestamp":"',
            vm.toString(block.timestamp),
            '","version":{"major":1,"minor":0,"patch":0},"keywords":["indexedex","tokens","robinhood","fee-detf"],"tokens":[',
            _tokenEntry(weth, "Wrapped Ether", "WETH", '["token","weth"]'),
            ",",
            _tokenEntry(rich, "RICH", "RICH", '["token","pons-launch","rich"]'),
            "]}"
        );
        vm.writeFile(string.concat(FRONTEND_DIR, "/base-tokens.tokenlist.json"), full);
    }

    function _writeStrategyVaultsTokenlist() internal {
        address se = _safeRead("05_univ3_se_rich.json", "uniV3Se_rich");
        string memory full = string.concat(
            '{"name":"Indexedex Robinhood Fee-DETF Strategy Vaults","timestamp":"',
            vm.toString(block.timestamp),
            '","version":{"major":1,"minor":0,"patch":0},"keywords":["indexedex","strategy","vault","fee-detf"],"tokens":[',
            _vaultEntry(se, "Uni V3 SE RICH/WETH", "uv3seRICH", '["vault","se"]'),
            "]}"
        );
        vm.writeFile(string.concat(FRONTEND_DIR, "/strategy-vaults.tokenlist.json"), full);
    }

    function _writeProtocolDetfsTokenlist() internal {
        address chir = _safeRead("09_chir_instance.json", "chir");
        string memory full = string.concat(
            '{"name":"Indexedex Robinhood Fee-DETF Protocol DETFs","timestamp":"',
            vm.toString(block.timestamp),
            '","version":{"major":1,"minor":0,"patch":0},"keywords":["indexedex","detf","fee-detf"],"tokens":[',
            _vaultEntry(chir, "IndexedEx Fee DETF", "CHIR", '["vault","detf","fee-detf"]'),
            "]}"
        );
        vm.writeFile(string.concat(FRONTEND_DIR, "/protocol-detfs.tokenlist.json"), full);
    }

    function _writeFeaturedFeeDetfsTokenlist() internal {
        address chir = _safeRead("09_chir_instance.json", "chir");
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

    function _safeRead(string memory file, string memory key) internal view returns (address) {
        (address a,) = _readAddressSafe(file, key);
        return a;
    }
}
