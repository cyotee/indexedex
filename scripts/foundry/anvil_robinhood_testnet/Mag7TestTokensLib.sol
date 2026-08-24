// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixtureEconomics} from "./FixtureEconomics.sol";
import {LaunchState} from "./LaunchState.sol";

import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {
    IERC20MintBurnOwnableOperableDFPkg
} from "@crane/contracts/tokens/ERC20/ERC20MintBurnOwnableOperableDFPkg.sol";

/// @title Mag7TestTokensLib
/// @notice Mag7 mintable stand-ins. Facade is a global operator. 1e6 of each plus TTWETH to deployer.
library Mag7TestTokensLib {
    uint256 internal constant MINT_AMOUNT = 1_000_000 ether;

    struct SevenTokens {
        address ttNVDA;
        address ttMSFT;
        address ttAAPL;
        address ttGOOGL;
        address ttAMZN;
        address ttMETA;
        address ttTSLA;
    }

    function execute(LaunchState storage s, address deployer_, SevenTokens memory existing)
        internal
        returns (SevenTokens memory tokens)
    {
        require(s.tokenPkg != address(0) && s.tokenPkg.code.length > 0, "Stage_04b: tokenPkg missing");
        require(
            s.erc20MinterFacade != address(0) && s.erc20MinterFacade.code.length > 0, "Stage_04b: facade missing"
        );
        require(s.ttWETH != address(0) && s.ttWETH.code.length > 0, "Stage_04b: TTWETH missing");

        IERC20MintBurnOwnableOperableDFPkg tokenPkg = IERC20MintBurnOwnableOperableDFPkg(s.tokenPkg);
        tokens.ttNVDA = _deployIfNeeded(tokenPkg, deployer_, existing.ttNVDA, "Test Token NVDA", "TTNVDA");
        tokens.ttMSFT = _deployIfNeeded(tokenPkg, deployer_, existing.ttMSFT, "Test Token MSFT", "TTMSFT");
        tokens.ttAAPL = _deployIfNeeded(tokenPkg, deployer_, existing.ttAAPL, "Test Token AAPL", "TTAAPL");
        tokens.ttGOOGL = _deployIfNeeded(tokenPkg, deployer_, existing.ttGOOGL, "Test Token GOOGL", "TTGOOGL");
        tokens.ttAMZN = _deployIfNeeded(tokenPkg, deployer_, existing.ttAMZN, "Test Token AMZN", "TTAMZN");
        tokens.ttMETA = _deployIfNeeded(tokenPkg, deployer_, existing.ttMETA, "Test Token META", "TTMETA");
        tokens.ttTSLA = _deployIfNeeded(tokenPkg, deployer_, existing.ttTSLA, "Test Token TSLA", "TTTSLA");

        _setGlobalFacade(s.erc20MinterFacade, tokens.ttNVDA);
        _setGlobalFacade(s.erc20MinterFacade, tokens.ttMSFT);
        _setGlobalFacade(s.erc20MinterFacade, tokens.ttAAPL);
        _setGlobalFacade(s.erc20MinterFacade, tokens.ttGOOGL);
        _setGlobalFacade(s.erc20MinterFacade, tokens.ttAMZN);
        _setGlobalFacade(s.erc20MinterFacade, tokens.ttMETA);
        _setGlobalFacade(s.erc20MinterFacade, tokens.ttTSLA);
        _setGlobalFacade(s.erc20MinterFacade, s.ttUSDG);
        _setGlobalFacade(s.erc20MinterFacade, s.ttUSDE);
        _setGlobalFacade(s.erc20MinterFacade, s.ttWETH);
        _setGlobalFacade(s.erc20MinterFacade, s.ttRICH);

        _mintTo(tokens.ttNVDA, deployer_);
        _mintTo(tokens.ttMSFT, deployer_);
        _mintTo(tokens.ttAAPL, deployer_);
        _mintTo(tokens.ttGOOGL, deployer_);
        _mintTo(tokens.ttAMZN, deployer_);
        _mintTo(tokens.ttMETA, deployer_);
        _mintTo(tokens.ttTSLA, deployer_);
        _mintTo(s.ttWETH, deployer_);
    }

    function _deployIfNeeded(
        IERC20MintBurnOwnableOperableDFPkg tokenPkg,
        address owner_,
        address existing,
        string memory name_,
        string memory symbol_
    ) private returns (address token) {
        if (existing != address(0) && existing.code.length > 0) return existing;
        token = tokenPkg.deployToken(name_, symbol_, 18, owner_, _salt(symbol_));
    }

    function _setGlobalFacade(address facade, address token) private {
        if (token == address(0) || token.code.length == 0) return;
        if (IOperable(token).isOperator(facade)) return;
        IOperable(token).setOperator(facade, true);
    }

    function _mintTo(address token, address to) private {
        if (token == address(0) || token.code.length == 0) return;
        if (IERC20(token).balanceOf(to) >= MINT_AMOUNT) return;
        IERC20MintBurn(token).mint(to, MINT_AMOUNT);
    }

    function _salt(string memory symbol) private pure returns (bytes32) {
        return keccak256(abi.encode(FixtureEconomics.SALT_NS, symbol));
    }
}
