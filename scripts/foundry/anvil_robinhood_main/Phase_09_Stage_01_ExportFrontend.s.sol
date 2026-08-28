// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";

/// @title Phase_09_Stage_01_ExportFrontend
/// @notice Always rewrite JSON. No txs. Architecture packages only. No tokens or DETF instances.
contract Phase_09_Stage_01_ExportFrontend is LaunchStageBase {
    string internal constant FRONTEND_DIR = "frontend/packages/protocol/src/addresses/chain/4663";
    address internal constant PONS = 0x39dBED3a2bd333467115dE45665cC57F813C4571;

    function run() external {
        _start("Phase 09 Stage 01: Export frontend");
        RobinhoodCanonicalLib.requireCanonicalPins();
        _loadPhasePriorForExport(s);
        vm.createDir(FRONTEND_DIR, true);
        _writePlatform();
        _writeBaseTokens();
        _writeEmptyList("strategy-vaults.tokenlist.json", "IndexedEx Robinhood Strategy Vaults");
        _writeEmptyList("protocol-detfs.tokenlist.json", "IndexedEx Robinhood Protocol DETFs");
        _writeEmptyList("featured-fee-detfs.tokenlist.json", "IndexedEx Robinhood Featured Fee DETFs");
        _logComplete("Phase 09 Stage 01");
    }

    function _frontendPath(string memory file) internal pure returns (string memory) {
        return string.concat(FRONTEND_DIR, "/", file);
    }

    function _writePlatform() internal {
        string memory json;
        json = vm.serializeUint("p", "chainId", uint256(4663));
        json = vm.serializeAddress("p", "weth", RobinhoodCanonicalLib.weth());
        json = vm.serializeAddress("p", "permit2", RobinhoodCanonicalLib.permit2());
        json = vm.serializeAddress("p", "poolManager", RobinhoodCanonicalLib.poolManager());
        json = vm.serializeAddress("p", "positionManagerV4", RobinhoodCanonicalLib.positionManagerV4());
        json = vm.serializeAddress("p", "universalRouter", RobinhoodCanonicalLib.universalRouter());
        json = vm.serializeAddress("p", "indexedexManager", address(s.indexedexManager));
        json = vm.serializeAddress("p", "feeCollector", address(s.feeCollector));
        json = vm.serializeAddress("p", "hookFactory", address(s.hookFactory));
        json = vm.serializeAddress("p", "create3Factory", address(s.create3Factory));
        json = vm.serializeAddress("p", "diamondPackageFactory", address(s.diamondPackageFactory));
        json = vm.serializeAddress("p", "vaultRegistry", address(s.indexedexManager));
        json = vm.serializeAddress("p", "vaultFeeOracle", address(s.indexedexManager));
        json = vm.serializeAddress("p", "rateProviderPkg", address(s.rateProviderPkg));
        json = vm.serializeAddress("p", "twapOraclePkg", address(s.twapOraclePkg));
        json = vm.serializeAddress("p", "twapOracle", address(s.twapOracle));
        json = vm.serializeAddress("p", "twapAdapterFactory", s.twapAdapterFactory);
        json = vm.serializeAddress("p", "uniV4SePkg", address(s.uniV4SePkg));
        json = vm.serializeAddress("p", "morphoBlueSePkg", s.morphoBlueSePkg);
        address morpho_ = RobinhoodCanonicalLib.morpho();
        if (_hasCode(morpho_)) {
            json = vm.serializeAddress("p", "morpho", morpho_);
            json = vm.serializeAddress("p", "morphoBlue", morpho_);
        }
        address irm_ = RobinhoodCanonicalLib.morphoIrm();
        if (_hasCode(irm_)) json = vm.serializeAddress("p", "morphoIrm", irm_);
        address v3_ = RobinhoodCanonicalLib.v3Factory();
        if (_hasCode(v3_)) {
            json = vm.serializeAddress("p", "v3Factory", v3_);
            json = vm.serializeAddress("p", "uniswapV3Factory", v3_);
        }
        json = vm.serializeAddress("p", "cpHookPkg", s.cpHookPkg);
        json = vm.serializeAddress("p", "weightedHookPkg", s.weightedHookPkg);
        json = vm.serializeAddress("p", "curveQuadHookPkg", s.curveQuadHookPkg);
        json = vm.serializeAddress("p", "uniV4DetfPkg", s.uniV4DetfPkg);
        json = vm.serializeAddress("p", "bondNftVaultPkg", s.bondNftVaultPkg);
        json = vm.serializeAddress("p", "rebasingClaimTokenPkg", s.rebasingClaimTokenPkg);
        json = vm.serializeAddress("p", "deployer", deployer);
        json = vm.serializeAddress("p", "owner", owner);
        json = vm.serializeAddress("p", "uiWallet", uiWallet);
        json = vm.serializeString("p", "networkProfile", _networkProfile());
        json = vm.serializeString("p", "rpcUrl", "https://rpc.mainnet.chain.robinhood.com");
        vm.writeJson(json, _frontendPath("platform.json"));
        _writeJson(json, FILE_09_01);
    }

    function _writeBaseTokens() internal {
        string memory body = string.concat(
            _tok("Wrapped Ether", "WETH", RobinhoodCanonicalLib.weth(), '["weth"]'),
            ",",
            _tok("Pons", "PONS", PONS, '["token"]')
        );
        vm.writeFile(_frontendPath("base-tokens.tokenlist.json"), _list("IndexedEx Robinhood Base Tokens", body));
    }

    function _writeEmptyList(string memory file, string memory name) internal {
        vm.writeFile(_frontendPath(file), _list(name, ""));
    }

    function _tok(string memory name, string memory symbol, address addr, string memory tags)
        private
        pure
        returns (string memory)
    {
        return string.concat(
            '{"chainId":4663,"address":"',
            vm.toString(addr),
            '","name":"',
            name,
            '","symbol":"',
            symbol,
            '","decimals":18,"tags":',
            tags,
            "}"
        );
    }

    function _list(string memory name, string memory tokens) private pure returns (string memory) {
        return string.concat(
            '{"name":"',
            name,
            '","timestamp":"0","version":{"major":1,"minor":0,"patch":0},"keywords":["indexedex","4663"],"tokens":[',
            tokens,
            "]}"
        );
    }
}
