// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
import {UniswapV3FullSpreadStandardExchangeVaultCommon} from "./UniswapV3FullSpreadStandardExchangeVaultCommon.sol";
import {UniswapV3FullSpreadStandardExchangeVaultPlanner as Planner} from "./UniswapV3FullSpreadStandardExchangeVaultPlanner.sol";
import {IUniswapV3FullSpreadStandardExchangeVault as IVault} from "./interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";
import {IStandardExchangeBundleIn, IStandardExchangeBundleOut} from "../v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";

contract UniswapV3FullSpreadStandardExchangeVaultBundleTarget is
    UniswapV3FullSpreadStandardExchangeVaultCommon, ReentrancyLockModifiers
{
    function exchangeBundleInForSingleOut(
        uint256[] calldata amountsIn_, address tokenOut_, uint256 minimum_,
        address recipient_, bool pretransferred_, uint256 deadline_
    ) external nonReentrant returns (uint256 amountOut_, uint256[] memory refunded_) {
        _deadline(deadline_);
        _requireNotDisabled();
        if (amountsIn_.length != 2) revert IStandardExchangeBundleIn.AmountsLengthMismatch();
        if (tokenOut_ != address(this)) revert IStandardExchangeBundleIn.ExchangeBundleInForSingleOutNotAvailable();
        _recipient(recipient_);
        address token0_ = _token0();
        address token1_ = _token1();
        if (pretransferred_) {
            LocalCreditLib.requirePretransferCaller(msg.sender);
            // V4 bundle contract: reject either over-maximum atomically, before funding either leg.
            if (amountsIn_[0] > _unbooked(token0_, 0) || amountsIn_[1] > _unbooked(token1_, 1)) revert();
        }
        _fund(token0_, amountsIn_[0], 0, pretransferred_);
        _fund(token1_, amountsIn_[1], 1, pretransferred_);
        Planner.Plan memory plan_ = Planner.planBundleIn(amountsIn_[0], amountsIn_[1]);
        if (plan_.failed) revert IVault.MinLiquidityNotMet();
        if (plan_.amountOut < minimum_) {
            revert IStandardExchangeBundleIn.MinAmountNotMetAt(0, minimum_, plan_.amountOut);
        }
        _add(plan_);
        _mintShares(plan_, recipient_);
        _pay(token0_, 0, msg.sender, plan_.refund0);
        _pay(token1_, 1, msg.sender, plan_.refund1);
        _close();
        refunded_ = new uint256[](2);
        refunded_[0] = plan_.refund0;
        refunded_[1] = plan_.refund1;
        emit IVault.PairDeposited(msg.sender);
        return (plan_.amountOut, refunded_);
    }

    function exchangeBundleOut(
        address tokenIn_, uint256 amountIn_, address[] calldata tokensOut_, uint256[] calldata minima_,
        address recipient_, bool pretransferred_, uint256 deadline_
    ) external nonReentrant returns (uint256[] memory amountsOut_, uint256 refunded_) {
        _deadline(deadline_);
        address token0_ = _token0();
        address token1_ = _token1();
        bool withdrawal_ = tokenIn_ == address(this) && tokensOut_.length == 2
            && ((tokensOut_[0] == token0_ && tokensOut_[1] == token1_)
                || (tokensOut_[0] == token1_ && tokensOut_[1] == token0_));
        if (!withdrawal_) _requireNotDisabled();
        if (tokensOut_.length != 2 || minima_.length != 2) revert IStandardExchangeBundleOut.TokenAmountsLengthMismatch();
        if (tokensOut_[0] == tokensOut_[1]) revert IStandardExchangeBundleOut.DuplicateOutput();
        if (!withdrawal_) revert IStandardExchangeBundleOut.ExchangeBundleOutNotAvailable();
        _recipient(recipient_);
        if (pretransferred_) LocalCreditLib.requirePretransferCaller(msg.sender);
        _requireShares(amountIn_);
        Planner.Plan memory plan_ = Planner.planBundleOut(amountIn_);
        uint256 index0_ = tokensOut_[0] == token0_ ? 0 : 1;
        if (plan_.failed || plan_.out0 < minima_[index0_]) {
            revert IStandardExchangeBundleIn.MinAmountNotMetAt(index0_, minima_[index0_], plan_.failed ? 0 : plan_.out0);
        }
        if (plan_.out1 < minima_[1 - index0_]) {
            revert IStandardExchangeBundleIn.MinAmountNotMetAt(1 - index0_, minima_[1 - index0_], plan_.out1);
        }
        _remove(plan_);
        _pay(token0_, 0, recipient_, plan_.out0);
        _pay(token1_, 1, recipient_, plan_.out1);
        _close();
        amountsOut_ = new uint256[](2);
        amountsOut_[index0_] = plan_.out0;
        amountsOut_[1 - index0_] = plan_.out1;
        emit IVault.PairRedeemed(msg.sender);
        return (amountsOut_, 0);
    }
}
