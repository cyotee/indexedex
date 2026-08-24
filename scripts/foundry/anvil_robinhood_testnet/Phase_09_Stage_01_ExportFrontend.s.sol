// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {ROBINHOOD_TESTNET} from "@crane/contracts/constants/networks/ROBINHOOD_TESTNET.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";

/// @title Phase_09_Stage_01_ExportFrontend
/// @notice Always rewrite JSON. No txs. Live rehearsal Morpho + V3 factory + pkgs + facade + tokens + Uni V4 SEs + DETFs.
contract Phase_09_Stage_01_ExportFrontend is LaunchStageBase {
    string internal constant FRONTEND_DIR = "frontend/packages/protocol/src/addresses/chain/46630";

    function run() external {
        _start("Phase 09 Stage 01: Export frontend");
        RobinhoodCanonicalLib.requireCanonicalPins();
        _loadPhasePriorForExport(s);
        if (!_hasCode(s.dtfClaim) && _hasCode(s.dtfDetf)) {
            s.dtfClaim = address(IDetf(s.dtfDetf).rebasingClaimToken());
        }
        require(_hasCode(s.dtfClaim), "DTF-CLAIM required (wire DTF-DETF claim)");
        vm.createDir(FRONTEND_DIR, true);
        _writePlatform();
        _writeBaseTokens();
        _writeStrategyVaults();
        _writeProtocolDetfs();
        _writeFeaturedFee();
        _logComplete("Phase 09 Stage 01");
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
        json = vm.serializeAddress("p", "vaultRegistry", address(s.indexedexManager));
        json = vm.serializeAddress("p", "rateProviderPkg", address(s.rateProviderPkg));
        json = vm.serializeAddress("p", "twapOraclePkg", address(s.twapOraclePkg));
        json = vm.serializeAddress("p", "twapOracle", address(s.twapOracle));
        json = vm.serializeAddress("p", "twapAdapterFactory", s.twapAdapterFactory);
        json = vm.serializeAddress("p", "uniV4SePkg", address(s.uniV4SePkg));
        json = vm.serializeAddress("p", "v3Factory", s.v3Factory);
        json = vm.serializeAddress("p", "uniswapV3Factory", s.v3Factory);
        json = vm.serializeAddress("p", "uniV3SePkg", s.uniV3SePkg);
        json = vm.serializeAddress("p", "cpHookPkg", s.cpHookPkg);
        json = vm.serializeAddress("p", "cpDetfPkg", s.cpDetfPkg);
        json = vm.serializeAddress("p", "curveQuadHookPkg", s.curveQuadHookPkg);
        json = vm.serializeAddress("p", "curveQuadDetfPkg", s.curveQuadDetfPkg);
        json = vm.serializeAddress("p", "orbitalHookPkg", s.orbitalHookPkg);
        json = vm.serializeAddress("p", "orbitalDetfPkg", s.orbitalDetfPkg);
        json = vm.serializeAddress("p", "weightedHookPkg", s.weightedHookPkg);
        json = vm.serializeAddress("p", "weightedDetfPkg", s.weightedDetfPkg);
        json = vm.serializeAddress("p", "morpho", s.morpho);
        json = vm.serializeAddress("p", "morphoBlue", s.morpho);
        json = vm.serializeAddress("p", "morphoIrm", s.morphoIrm);
        json = vm.serializeAddress("p", "morphoOracle", s.morphoOracle);
        json = vm.serializeAddress("p", "morphoBlueSePkg", s.morphoBlueSePkg);
        json = vm.serializeAddress("p", "bondNftVaultPkg", s.bondNftVaultPkg);
        json = vm.serializeAddress("p", "rebasingClaimTokenPkg", s.rebasingClaimTokenPkg);
        json = vm.serializeAddress("p", "TTUSDG", s.ttUSDG);
        json = vm.serializeAddress("p", "TTUSDE", s.ttUSDE);
        json = vm.serializeAddress("p", "TTWETH", s.ttWETH);
        json = vm.serializeAddress("p", "DTF", s.ttRICH);
        json = vm.serializeAddress("p", "TTNVDA", s.ttNVDA);
        json = vm.serializeAddress("p", "TTMSFT", s.ttMSFT);
        json = vm.serializeAddress("p", "TTAAPL", s.ttAAPL);
        json = vm.serializeAddress("p", "TTGOOGL", s.ttGOOGL);
        json = vm.serializeAddress("p", "TTAMZN", s.ttAMZN);
        json = vm.serializeAddress("p", "TTMETA", s.ttMETA);
        json = vm.serializeAddress("p", "TTTSLA", s.ttTSLA);
        json = vm.serializeAddress("p", "DTF-DETF", s.dtfDetf);
        json = vm.serializeAddress("p", "DTF-CLAIM", s.dtfClaim);
        json = vm.serializeAddress("p", "rebasingClaimToken", s.dtfClaim);
        json = vm.serializeAddress("p", "seUsdeWeth", s.seUsdeWeth);
        json = vm.serializeAddress("p", "seUsdgWeth", s.seUsdgWeth);
        json = vm.serializeAddress("p", "seUsdgUsde", s.seUsdgUsde);
        json = vm.serializeAddress("p", "seRichWeth", s.seRichWeth);
        json = vm.serializeAddress("p", "TTDOL-Q", s.ttDolQ);
        json = vm.serializeAddress("p", "$$DETF", s.ttDolQ);
        if (_hasCode(s.ttDolQ)) {
            json = vm.serializeAddress("p", "I$$DETF", address(IDetf(s.ttDolQ).rebasingClaimToken()));
        }
        json = vm.serializeAddress("p", "deployer", deployer);
        json = vm.serializeAddress("p", "uiWallet", uiWallet);
        json = vm.serializeString("p", "networkProfile", _networkProfile());
        json = vm.serializeString("p", "rpcUrl", "http://127.0.0.1:8545");
        vm.writeJson(json, _frontendPath("platform.json"));
        _writeJson(json, FILE_09_01);
    }

    function _writeBaseTokens() internal {
        string memory body = string.concat(
            _tok("Test Token USDG", "TTUSDG", s.ttUSDG, '["token","testToken"]'),
            ",",
            _tok("Test Token USDE", "TTUSDE", s.ttUSDE, '["token","testToken"]'),
            ",",
            _tok("Test Token WETH", "TTWETH", s.ttWETH, '["token","testToken"]'),
            ",",
            _tok("Test Token DTF", "DTF", s.ttRICH, '["token","testToken"]'),
            ",",
            _tok("Test Claim DTF-CLAIM", "DTF-CLAIM", s.dtfClaim, '["token","claim"]'),
            _sevenToks(),
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
        if (_hasCode(s.ttDolQ)) {
            address dolQClaim = address(IDetf(s.ttDolQ).rebasingClaimToken());
            if (_hasCode(dolQClaim)) {
                body = string.concat(body, ",", _tok("Infinite Double Dollar", "I$$DETF", dolQClaim, '["token","claim"]'));
            }
        }
        vm.writeFile(_frontendPath("base-tokens.tokenlist.json"), _list("IndexedEx Robinhood Testnet Base Tokens", body));
    }

    function _writeStrategyVaults() internal {
        string memory body = string.concat(
            _tok("Test SE TTUSDE/TTWETH", "SE-TTUSDE-TTWETH", s.seUsdeWeth, '["vault","se","strat"]'),
            ",",
            _tok("Test SE TTUSDG/TTWETH", "SE-TTUSDG-TTWETH", s.seUsdgWeth, '["vault","se","strat"]'),
            ",",
            _tok("Test SE TTUSDG/TTUSDE", "SE-TTUSDG-TTUSDE", s.seUsdgUsde, '["vault","se","strat"]'),
            ",",
            _tok("Test SE DTF/TTWETH", "SE-DTF-TTWETH", s.seRichWeth, '["vault","se","strat"]')
        );
        vm.writeFile(
            _frontendPath("strategy-vaults.tokenlist.json"), _list("IndexedEx Robinhood Testnet Strategy Vaults", body)
        );
    }

    function _writeProtocolDetfs() internal {
        string memory body = string.concat(
            _tok("Test DETF DTF-DETF", "DTF-DETF", s.dtfDetf, '["vault","detf"]'),
            ",",
            _tok("Double Dollar DETF", "$$DETF", s.ttDolQ, '["vault","detf"]')
        );
        vm.writeFile(
            _frontendPath("protocol-detfs.tokenlist.json"), _list("IndexedEx Robinhood Testnet Protocol DETFs", body)
        );
    }

    function _writeFeaturedFee() internal {
        string memory body = _tok("Test DETF DTF-DETF", "DTF-DETF", s.dtfDetf, '["vault","detf","fee"]');
        vm.writeFile(
            _frontendPath("featured-fee-detfs.tokenlist.json"),
            _list("IndexedEx Robinhood Testnet Featured Fee DETFs", body)
        );
    }

    function _sevenToks() private view returns (string memory extra) {
        extra = _sevenTok("Test Token NVDA", "TTNVDA", s.ttNVDA);
        extra = string.concat(extra, _sevenTok("Test Token MSFT", "TTMSFT", s.ttMSFT));
        extra = string.concat(extra, _sevenTok("Test Token AAPL", "TTAAPL", s.ttAAPL));
        extra = string.concat(extra, _sevenTok("Test Token GOOGL", "TTGOOGL", s.ttGOOGL));
        extra = string.concat(extra, _sevenTok("Test Token AMZN", "TTAMZN", s.ttAMZN));
        extra = string.concat(extra, _sevenTok("Test Token META", "TTMETA", s.ttMETA));
        extra = string.concat(extra, _sevenTok("Test Token TSLA", "TTTSLA", s.ttTSLA));
    }

    function _sevenTok(string memory name, string memory symbol, address addr) private view returns (string memory) {
        if (!_hasCode(addr)) return "";
        return string.concat(",", _tok(name, symbol, addr, '["token","testToken"]'));
    }

    function _tok(string memory name, string memory symbol, address addr, string memory tags)
        private
        pure
        returns (string memory)
    {
        return string.concat(
            '{"chainId":46630,"address":"',
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
            '","timestamp":"0","version":{"major":1,"minor":0,"patch":0},"keywords":["indexedex","46630"],"tokens":[',
            tokens,
            "]}"
        );
    }
}
