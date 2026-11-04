// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {
    NativeStandardYieldMoneyTarget,
    NativeStandardYieldRewardsTarget
} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {NativeStandardYieldErrors} from "contracts/vaults/standard/sy/NativeStandardYieldErrors.sol";
import {UniswapV4PairTokenStandardExchangeVaultExecution as Execution} from "./UniswapV4PairTokenStandardExchangeVaultExecution.sol";
import {UniswapV4PairTokenStandardExchangeVaultRepo as Repo} from "./UniswapV4PairTokenStandardExchangeVaultRepo.sol";
import {UniswapV4PairTokenStandardExchangeVaultTypes as Types} from "./UniswapV4PairTokenStandardExchangeVaultTypes.sol";

// tag::UniswapV4PairTokenStandardExchangeVaultSYMoneyTarget[]
/// @notice Native-capable SY execution through the sole share token and family engine.
contract UniswapV4PairTokenStandardExchangeVaultSYMoneyTarget is
    NativeStandardYieldMoneyTarget,
    NativeStandardYieldRewardsTarget
{
    // tag::deposit-20e8c565[]
    /// @notice Native input reserves exact msg.value; ERC-20 input carries no value.
    /// @custom:signature deposit(address,address,uint256,uint256)
    /// @custom:selector 0x20e8c565
    function deposit(address receiver_, address tokenIn_, uint256 amount_, uint256 minimum_)
        public payable override returns (uint256 shares_)
    {
        Repo._requireIdle();
        if (receiver_ == address(0) || receiver_ == address(this)) revert NativeStandardYieldErrors.InvalidSYReceiver();
        if (amount_ == 0) revert NativeStandardYieldErrors.ZeroSYAmount();
        if (!isValidTokenIn(tokenIn_)) revert NativeStandardYieldErrors.InvalidSYToken(tokenIn_);
        if (msg.value != (tokenIn_ == address(0) ? amount_ : 0)) {
            revert NativeStandardYieldErrors.UnsupportedNativePayment();
        }
        shares_ = _standardRoute(IERC20(tokenIn_), amount_, IERC20(address(this)), minimum_, receiver_, false);
        if (shares_ == 0) revert NativeStandardYieldErrors.ZeroSYAmount();
        emit IStandardizedYield.Deposit(msg.sender, receiver_, tokenIn_, amount_, shares_);
    }
    // end::deposit-20e8c565[]

    // tag::redeem-769f8e5d[]
    /// @notice Preserve canonical holder/internal-balance validation and SY redemption event.
    /// @custom:signature redeem(address,uint256,address,uint256,bool)
    /// @custom:selector 0x769f8e5d
    function redeem(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_, bool internalBalance_)
        public override returns (uint256)
    {
        Repo._requireIdle();
        if (receiver_ == address(this)) revert NativeStandardYieldErrors.InvalidSYReceiver();
        return super.redeem(receiver_, shares_, tokenOut_, minimum_, internalBalance_);
    }
    // end::redeem-769f8e5d[]

    // tag::isValidTokenIn-fa5a4f06[]
    /// @custom:signature isValidTokenIn(address)
    /// @custom:selector 0xfa5a4f06
    function isValidTokenIn(address token_) public view override returns (bool) {
        Types.Config memory config_ = Repo._layoutStruct().config;
        address raw0_ = Currency.unwrap(config_.poolKey.currency0);
        return token_ == raw0_ || token_ == Currency.unwrap(config_.poolKey.currency1)
            || (raw0_ == address(0) && token_ == config_.wrappedNative);
    }
    // end::isValidTokenIn-fa5a4f06[]

    // tag::isValidTokenOut-784367d6[]
    /// @custom:signature isValidTokenOut(address)
    /// @custom:selector 0x784367d6
    function isValidTokenOut(address token_) public view override returns (bool) {
        return isValidTokenIn(token_);
    }
    // end::isValidTokenOut-784367d6[]

    function _standardRoute(
        IERC20 in_, uint256 amount_, IERC20 out_, uint256 minimum_, address receiver_, bool internal_
    ) internal override returns (uint256 received_) {
        received_ = Execution.exchangeIn(
            address(in_), amount_, address(out_), minimum_, receiver_, internal_, block.timestamp, true
        );
        if (received_ < minimum_) revert NativeStandardYieldErrors.SYMinimumNotMet(minimum_, received_);
    }

    function _redeemVaultHeld(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_)
        internal override returns (uint256 received_)
    {
        received_ = Execution.exchangeIn(
            address(this), shares_, tokenOut_, minimum_, receiver_, true, block.timestamp, true
        );
        if (received_ < minimum_) revert NativeStandardYieldErrors.SYMinimumNotMet(minimum_, received_);
    }

    function _exchangeIn(
        IERC20 in_, uint256 amount_, IERC20 out_, uint256 minimum_,
        address recipient_, bool prepaid_, uint256 deadline_
    ) internal override returns (uint256) {
        return Execution.exchangeIn(
            address(in_), amount_, address(out_), minimum_, recipient_, prepaid_, deadline_, true
        );
    }
}
// end::UniswapV4PairTokenStandardExchangeVaultSYMoneyTarget[]
