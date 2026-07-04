// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/// @title MockStandardExchange
/// @notice Test stub implementing IStandardExchangeIn and IStandardExchangeOut.
///         Supports a configurable support matrix and per-pair WAD rates.
///         tokenOut transfers come from the mock's own pre-loaded balance.
contract MockStandardExchange {
    /* ---------------------------------------------------------------------- */
    /*                                Storage                                  */
    /* ---------------------------------------------------------------------- */

    /// @dev Supported (tokenIn, tokenOut) pairs — both directions must be added explicitly.
    mapping(address => mapping(address => bool)) private _supported;

    /// @dev Exchange rate: tokenOut per tokenIn, expressed as WAD (1e18 = 1:1).
    mapping(address => mapping(address => uint256)) private _rate;

    /* ---------------------------------------------------------------------- */
    /*                             Constructor                                 */
    /* ---------------------------------------------------------------------- */

    /// @param tokensIn_  Tokens this mock accepts as input.
    /// @param tokensOut_ Corresponding tokens this mock provides as output (same indices).
    constructor(IERC20[] memory tokensIn_, IERC20[] memory tokensOut_) {
        require(tokensIn_.length == tokensOut_.length, "MockStandardExchange: length mismatch");
        for (uint256 i = 0; i < tokensIn_.length; i++) {
            _supported[address(tokensIn_[i])][address(tokensOut_[i])] = true;
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                              Test Helpers                               */
    /* ---------------------------------------------------------------------- */

    /// @notice Sets the exchange rate for a (tokenIn, tokenOut) pair.
    /// @param rateWad_ WAD-scaled rate: amountOut = amountIn * rateWad / 1e18.
    function setRate(IERC20 tokenIn_, IERC20 tokenOut_, uint256 rateWad_) external {
        _rate[address(tokenIn_)][address(tokenOut_)] = rateWad_;
    }

    /* ---------------------------------------------------------------------- */
    /*                         IStandardExchangeIn subset                      */
    /* ---------------------------------------------------------------------- */

    /// @notice Preview: amountOut = amountIn * rate / 1e18.
    function previewExchangeIn(IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_)
        external
        view
        returns (uint256 amountOut_)
    {
        amountOut_ = amountIn_ * _rate[address(tokenIn_)][address(tokenOut_)] / 1e18;
    }

    /// @notice Executes an exchange-in: pulls tokenIn (unless pretransferred), transfers tokenOut
    ///         from this contract's pre-loaded balance.
    function exchangeIn(
        IERC20 tokenIn_,
        uint256 amountIn_,
        IERC20 tokenOut_,
        uint256 minAmountOut_,
        address recipient_,
        bool pretransferred_,
        uint256 /*deadline_*/
    ) external returns (uint256 amountOut_) {
        if (!pretransferred_) {
            tokenIn_.transferFrom(msg.sender, address(this), amountIn_);
        }
        amountOut_ = amountIn_ * _rate[address(tokenIn_)][address(tokenOut_)] / 1e18;
        require(amountOut_ >= minAmountOut_, "MockStandardExchange: slippage");
        tokenOut_.transfer(recipient_, amountOut_);
    }

    /* ---------------------------------------------------------------------- */
    /*                        IStandardExchangeOut subset                      */
    /* ---------------------------------------------------------------------- */

    /// @notice Preview inverse: amountIn = amountOut * 1e18 / rate.
    function previewExchangeOut(IERC20 tokenIn_, IERC20 tokenOut_, uint256 amountOut_)
        external
        view
        returns (uint256 amountIn_)
    {
        uint256 rate_ = _rate[address(tokenIn_)][address(tokenOut_)];
        require(rate_ > 0, "MockStandardExchange: no rate");
        amountIn_ = amountOut_ * 1e18 / rate_;
    }

    /// @notice Executes an exchange-out: computes required tokenIn, pulls it, sends tokenOut.
    function exchangeOut(
        IERC20 tokenIn_,
        uint256 maxAmountIn_,
        IERC20 tokenOut_,
        uint256 amountOut_,
        address recipient_,
        bool pretransferred_,
        uint256 /*deadline_*/
    ) external returns (uint256 amountIn_) {
        uint256 rate_ = _rate[address(tokenIn_)][address(tokenOut_)];
        require(rate_ > 0, "MockStandardExchange: no rate");
        amountIn_ = amountOut_ * 1e18 / rate_;
        require(amountIn_ <= maxAmountIn_, "MockStandardExchange: slippage");
        if (!pretransferred_) {
            tokenIn_.transferFrom(msg.sender, address(this), amountIn_);
        }
        tokenOut_.transfer(recipient_, amountOut_);
    }
}
