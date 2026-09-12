// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";

/// @notice Fund both sides of an empty liquidity SE before validating single-token DETF routes.
library Phase_07_Stage_04_FeeAccrualLiquiditySeed {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    struct Config {
        address vault;
        address actor;
        address dtf;
        address weth;
        uint256 wethInput;
        uint256 maxDtfInput;
        uint256 deadline;
    }

    function quote(IPoolManager manager_, PoolKey memory key_, Config memory c_)
        internal view returns (address[] memory tokens_, uint256[] memory amounts_, uint256 shares_)
    {
        require(IERC20(c_.vault).totalSupply() == 0, "Liquidity seed: already initialized");
        require(c_.wethInput > 0 && c_.maxDtfInput > 0, "Liquidity seed: missing limits");
        require(c_.actor != address(0) && c_.deadline > block.timestamp, "Liquidity seed: actor/deadline");
        require(Currency.unwrap(key_.currency0) == address(0) && Currency.unwrap(key_.currency1) == c_.dtf, "Liquidity seed: wrong pool");
        (uint160 price_,,,) = manager_.getSlot0(key_.toId());
        uint256 dtfInput_ = Math.mulDiv(c_.wethInput, price_, 1 << 96, Math.Rounding.Ceil);
        dtfInput_ = Math.mulDiv(dtfInput_, price_, 1 << 96, Math.Rounding.Ceil);
        require(dtfInput_ > 0 && dtfInput_ <= c_.maxDtfInput, "Liquidity seed: DTF limit");
        tokens_ = IBasicVault(c_.vault).vaultTokens();
        require(tokens_.length == 2, "Liquidity seed: two assets required");
        amounts_ = new uint256[](2);
        uint256 found_;
        for (uint256 i_; i_ < 2; ++i_) {
            if (tokens_[i_] == c_.weth) { amounts_[i_] = c_.wethInput; found_ |= 1; }
            else if (tokens_[i_] == c_.dtf) { amounts_[i_] = dtfInput_; found_ |= 2; }
            require(IERC20(tokens_[i_]).balanceOf(c_.actor) >= amounts_[i_], "Liquidity seed: insufficient funding");
        }
        require(found_ == 3, "Liquidity seed: wrong assets");
        shares_ = IStandardExchangeInMulti(c_.vault).previewExchangeInManyToOne(tokens_, amounts_, IERC20(c_.vault));
        require(shares_ > 0, "Liquidity seed: zero shares");
    }

    function execute(IPoolManager manager_, PoolKey memory key_, Config memory c_)
        internal returns (uint256 shares_, uint256 dtfInput_)
    {
        (address[] memory tokens_, uint256[] memory amounts_, uint256 minimum_) = quote(manager_, key_, c_);
        for (uint256 i_; i_ < 2; ++i_) {
            require(IERC20(tokens_[i_]).approve(c_.vault, 0), "Liquidity seed: reset approval");
            require(IERC20(tokens_[i_]).approve(c_.vault, amounts_[i_]), "Liquidity seed: approval");
            if (tokens_[i_] == c_.dtf) dtfInput_ = amounts_[i_];
        }
        uint256 before_ = IERC20(c_.vault).balanceOf(c_.actor);
        shares_ = IStandardExchangeInMulti(c_.vault).exchangeInManyToOne(
            tokens_, amounts_, IERC20(c_.vault), minimum_, c_.actor, false, c_.deadline
        );
        require(shares_ >= minimum_ && IERC20(c_.vault).balanceOf(c_.actor) == before_ + shares_, "Liquidity seed: short shares");
        for (uint256 i_; i_ < 2; ++i_) require(IERC20(tokens_[i_]).approve(c_.vault, 0), "Liquidity seed: clear approval");
    }
}
