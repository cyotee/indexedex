// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchIo} from "./LaunchIo.sol";
import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {ROBINHOOD_TESTNET} from "@crane/contracts/constants/networks/ROBINHOOD_TESTNET.sol";

/// @title Script_09_ExportFrontend
/// @notice Writes chain/46630 platform + tokenlists. No on-chain txs.
contract Script_09_ExportFrontend is LaunchIo {
    LaunchState internal s;

    string internal constant FRONTEND_DIR = "frontend/packages/protocol/src/addresses/chain/46630";

    function run() external {
        _loadConfig();
        _requireRobinhoodTestnet();
        RobinhoodCanonicalLib.requireCanonicalPins();
        require(_loadFactories(s), "run Script_01 first");
        require(_loadPlatform(s), "run Script_02 first");
        require(_loadUniV4Packages(s), "run Script_03 first");
        require(_loadTokens(s), "run Script_04 first");
        require(_loadLeafPools(s), "run Script_05 first");
        require(_loadLeafDetfs(s), "run Script_06 first");
        require(_loadNestDetfs(s), "run Script_07 first");
        require(_loadFeeSink(s), "run Script_08 first");
        _logHeader("Group 09: Frontend export (46630)");

        vm.createDir(FRONTEND_DIR, true);
        _writePlatform();
        _writeBaseTokens();
        _writeStrategyVaults();
        _writeProtocolDetfs();
        _writeFeaturedFee();
        _exportSummary();
        _logComplete("Group 09");
    }

    function _frontendPath(string memory file) internal pure returns (string memory) {
        return string.concat(FRONTEND_DIR, "/", file);
    }

    function _writePlatform() internal {
        string memory json;
        json = vm.serializeUint("p", "chainId", uint256(46630));
        json = vm.serializeAddress("p", "weth", RobinhoodCanonicalLib.weth());
        json = vm.serializeAddress("p", "permit2", RobinhoodCanonicalLib.permit2());
        json = vm.serializeAddress("p", "poolManager", RobinhoodCanonicalLib.poolManager());
        json = vm.serializeAddress("p", "positionManagerV4", RobinhoodCanonicalLib.positionManagerV4());
        json = vm.serializeAddress("p", "universalRouter", RobinhoodCanonicalLib.universalRouter());
        json = vm.serializeAddress("p", "indexedexManager", address(s.indexedexManager));
        json = vm.serializeAddress("p", "feeCollector", address(s.feeCollector));
        json = vm.serializeAddress("p", "hookFactory", address(s.hookFactory));
        json = vm.serializeAddress("p", "erc20MinterFacade", s.erc20MinterFacade);
        json = vm.serializeAddress("p", "create3Factory", address(s.create3Factory));
        json = vm.serializeAddress("p", "diamondPackageFactory", address(s.diamondPackageFactory));
        json = vm.serializeAddress("p", "TTUSDG", s.ttUSDG);
        json = vm.serializeAddress("p", "TTUSDE", s.ttUSDE);
        json = vm.serializeAddress("p", "TTNVDA", s.ttNVDA);
        json = vm.serializeAddress("p", "TTMSFT", s.ttMSFT);
        json = vm.serializeAddress("p", "TTAAPL", s.ttAAPL);
        json = vm.serializeAddress("p", "TTGOOGL", s.ttGOOGL);
        json = vm.serializeAddress("p", "TTAMZN", s.ttAMZN);
        json = vm.serializeAddress("p", "TTMETA", s.ttMETA);
        json = vm.serializeAddress("p", "TTTSLA", s.ttTSLA);
        json = vm.serializeAddress("p", "TTSMH", s.ttSMH);
        json = vm.serializeAddress("p", "TTSPY", s.ttSPY);
        json = vm.serializeAddress("p", "TTVTI", s.ttVTI);
        json = vm.serializeAddress("p", "TTQQQ", s.ttQQQ);
        json = vm.serializeAddress("p", "TTRICH", s.ttRICH);
        json = vm.serializeAddress("p", "seNvdaUsdg", s.seNvdaUsdg);
        json = vm.serializeAddress("p", "seSpyUsdg", s.seSpyUsdg);
        json = vm.serializeAddress("p", "seUsdeWeth", s.seUsdeWeth);
        json = vm.serializeAddress("p", "seUsdgWeth", s.seUsdgWeth);
        json = vm.serializeAddress("p", "seUsdgUsde", s.seUsdgUsde);
        json = vm.serializeAddress("p", "seIdxUsdg", s.seIdxUsdg);
        json = vm.serializeAddress("p", "seRichWeth", s.seRichWeth);
        json = vm.serializeAddress("p", "TTNVDA-S", s.ttNvdaS);
        json = vm.serializeAddress("p", "TTNVDA-SMH-O", s.ttNvdaSmhO);
        json = vm.serializeAddress("p", "TTIDX-Q", s.ttIdxQ);
        json = vm.serializeAddress("p", "TTBETA-O", s.ttBetaO);
        json = vm.serializeAddress("p", "TTIDX-WRAP", s.ttIdxWrap);
        json = vm.serializeAddress("p", "TTDOL-Q", s.ttDolQ);
        json = vm.serializeAddress("p", "TTRICH-S", s.ttRichS);
        json = vm.serializeAddress("p", "deployer", deployer);
        json = vm.serializeAddress("p", "uiWallet", uiWallet);
        json = vm.serializeString("p", "networkProfile", _networkProfile());
        json = vm.serializeString("p", "rpcUrl", "http://127.0.0.1:8545");
        vm.writeJson(json, _frontendPath("platform.json"));
        _writeJson(json, FILE_EXPORT);
    }

    function _writeBaseTokens() internal {
        string memory body = string.concat(
            _tok("Test Token USDG", "TTUSDG", s.ttUSDG, '["token","testToken"]'),
            ",",
            _tok("Test Token USDE", "TTUSDE", s.ttUSDE, '["token","testToken"]'),
            ",",
            _tok("Test Token NVDA", "TTNVDA", s.ttNVDA, '["token","testToken"]'),
            ",",
            _tok("Test Token MSFT", "TTMSFT", s.ttMSFT, '["token","testToken"]'),
            ",",
            _tok("Test Token AAPL", "TTAAPL", s.ttAAPL, '["token","testToken"]'),
            ",",
            _tok("Test Token GOOGL", "TTGOOGL", s.ttGOOGL, '["token","testToken"]'),
            ",",
            _tok("Test Token AMZN", "TTAMZN", s.ttAMZN, '["token","testToken"]'),
            ",",
            _tok("Test Token META", "TTMETA", s.ttMETA, '["token","testToken"]'),
            ",",
            _tok("Test Token TSLA", "TTTSLA", s.ttTSLA, '["token","testToken"]'),
            ",",
            _tok("Test Token SMH", "TTSMH", s.ttSMH, '["token","testToken"]'),
            ",",
            _tok("Test Token SPY", "TTSPY", s.ttSPY, '["token","testToken"]'),
            ",",
            _tok("Test Token VTI", "TTVTI", s.ttVTI, '["token","testToken"]'),
            ",",
            _tok("Test Token QQQ", "TTQQQ", s.ttQQQ, '["token","testToken"]'),
            ",",
            _tok("Test Token RICH", "TTRICH", s.ttRICH, '["token","testToken"]'),
            ",",
            _tok("Wrapped Ether", "WETH", RobinhoodCanonicalLib.weth(), '["weth"]'),
            ",",
            _tok("Faucet TSLA", "TSLA", ROBINHOOD_TESTNET.FAUCET_TSLA, '["rh-faucet"]'),
            ",",
            _tok("Faucet AMZN", "AMZN", ROBINHOOD_TESTNET.FAUCET_AMZN, '["rh-faucet"]'),
            ",",
            _tok("Faucet PLTR", "PLTR", ROBINHOOD_TESTNET.FAUCET_PLTR, '["rh-faucet"]'),
            ",",
            _tok("Faucet NFLX", "NFLX", ROBINHOOD_TESTNET.FAUCET_NFLX, '["rh-faucet"]'),
            ",",
            _tok("Faucet AMD", "AMD", ROBINHOOD_TESTNET.FAUCET_AMD, '["rh-faucet"]')
        );
        vm.writeFile(_frontendPath("base-tokens.tokenlist.json"), _list("IndexedEx Robinhood Testnet Base Tokens", body));
    }

    function _writeStrategyVaults() internal {
        string memory body = string.concat(
            _tok("Test SE TTNVDA/TTUSDG", "SE-TTNVDA-TTUSDG", s.seNvdaUsdg, '["vault","se"]'),
            ",",
            _tok("Test SE TTSPY/TTUSDG", "SE-TTSPY-TTUSDG", s.seSpyUsdg, '["vault","se"]'),
            ",",
            _tok("Test SE TTUSDE/WETH", "SE-TTUSDE-WETH", s.seUsdeWeth, '["vault","se"]'),
            ",",
            _tok("Test SE TTUSDG/WETH", "SE-TTUSDG-WETH", s.seUsdgWeth, '["vault","se"]'),
            ",",
            _tok("Test SE TTUSDG/TTUSDE", "SE-TTUSDG-TTUSDE", s.seUsdgUsde, '["vault","se"]'),
            ",",
            _tok("Test SE TTIDX-Q/TTUSDG", "SE-TTIDX-Q-TTUSDG", s.seIdxUsdg, '["vault","se"]'),
            ",",
            _tok("Test SE TTRICH/WETH", "SE-TTRICH-WETH", s.seRichWeth, '["vault","se"]')
        );
        vm.writeFile(_frontendPath("strategy-vaults.tokenlist.json"), _list("IndexedEx Robinhood Testnet Strategy Vaults", body));
    }

    function _writeProtocolDetfs() internal {
        string memory body = string.concat(
            _tok("Test DETF NVDA Single", "TTNVDA-S", s.ttNvdaS, '["vault","detf"]'),
            ",",
            _tok("Test DETF NVDA SMH Orbital", "TTNVDA-SMH-O", s.ttNvdaSmhO, '["vault","detf"]'),
            ",",
            _tok("Test DETF Index Quad", "TTIDX-Q", s.ttIdxQ, '["vault","detf"]'),
            ",",
            _tok("Test DETF Beta Nest", "TTBETA-O", s.ttBetaO, '["vault","detf"]'),
            ",",
            _tok("Test DETF Index Wrap", "TTIDX-WRAP", s.ttIdxWrap, '["vault","detf"]'),
            ",",
            _tok("Test DETF Dollar Quad", "TTDOL-Q", s.ttDolQ, '["vault","detf"]'),
            ",",
            _tok("Test DETF RICH Single", "TTRICH-S", s.ttRichS, '["vault","detf"]')
        );
        vm.writeFile(_frontendPath("protocol-detfs.tokenlist.json"), _list("IndexedEx Robinhood Testnet Protocol DETFs", body));
    }

    function _writeFeaturedFee() internal {
        vm.writeFile(
            _frontendPath("featured-fee-detfs.tokenlist.json"),
            '{"name":"IndexedEx Robinhood Testnet Featured Fee DETFs","timestamp":"0","version":{"major":1,"minor":0,"patch":0},"keywords":["indexedex","detf"],"tokens":[]}'
        );
    }

    function _exportSummary() internal {
        string memory json;
        json = vm.serializeUint("x", "chainId", uint256(46630));
        json = vm.serializeAddress("x", "erc20MinterFacade", s.erc20MinterFacade);
        json = vm.serializeAddress("x", "TTNVDA-S", s.ttNvdaS);
        json = vm.serializeAddress("x", "TTRICH-S", s.ttRichS);
        json = vm.serializeString("x", "frontendDir", FRONTEND_DIR);
        _writeJson(json, FILE_EXPORT);
    }

    function _tok(string memory name, string memory symbol, address addr, string memory tags)
        private
        pure
        returns (string memory)
    {
        return string.concat(
            '{"chainId":46630,"address":"',
            _toHex(addr),
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
            '","timestamp":"0","version":{"major":1,"minor":0,"patch":0},"keywords":["indexedex","46630"],"tokens":[',
            tokens,
            "]}"
        );
    }

    function _toHex(address addr) private pure returns (string memory) {
        return vm.toString(addr);
    }
}
