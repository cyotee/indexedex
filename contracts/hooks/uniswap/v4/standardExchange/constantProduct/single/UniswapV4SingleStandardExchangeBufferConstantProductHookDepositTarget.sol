// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookPullLib as PullLib
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookPullLib.sol";

import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol";

/// @title UniswapV4SingleStandardExchangeBufferConstantProductHookDepositTarget
/// @notice Proportional and unbalanced CP deposits with shared reserve accounting.
abstract contract UniswapV4SingleStandardExchangeBufferConstantProductHookDepositTarget is
    UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon
{
    /// @notice CP joinProportional entry point.
    function joinProportional(uint256[] calldata amounts, address to, uint256 sharesMin, uint256 deadline)
        external
        onlyLiquidityOwner
        nonReentrant
        accrueProtocolFee
        returns (uint256 shares, uint256[] memory usedAmounts)
    {
        Repo.Layout storage l = Repo._layout();
        if (amounts.length != 2) revert InvalidRoute();
        uint256 amt0 = l.currency0 == l.rawToken ? amounts[0] : amounts[1];
        uint256 amt1 = l.currency0 == l.rawToken ? amounts[1] : amounts[0];
        PullLib.pullErc20Dual(l.currency0, l.currency1, amt0, amt1);
        uint256 used0;
        uint256 used1;
        (shares, used0, used1) = _deposit(amt0, amt1, to, sharesMin, deadline);
        usedAmounts = new uint256[](2);
        usedAmounts[0] = l.currency0 == l.rawToken ? used0 : used1;
        usedAmounts[1] = l.currency0 == l.rawToken ? used1 : used0;
    }

    /// @notice CP joinUnbalanced entry point.
    function joinUnbalanced(
        address[] calldata tokensIn,
        uint256[] calldata amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) external onlyLiquidityOwner nonReentrant accrueProtocolFee returns (uint256 shares) {
        JoinUnbalancedAcc memory acc = _accumulateJoin(tokensIn, amounts);
        _requireFirstJoinFullBook(acc);
        if (acc.seShare > 0) {
            PullLib.pullErc20Single(Repo._layout().rawToken, acc.raw);
            PullLib.pullErc20Single(Repo._layout().standardExchange, acc.seShare);
            (shares,,) = _depositWithSeShares(acc.raw, acc.seShare, to, sharesMin, deadline);
            return shares;
        }
        Repo.Layout storage l = Repo._layout();
        uint256 amt0 = l.currency0 == l.rawToken ? acc.raw : acc.pair;
        uint256 amt1 = l.currency0 == l.rawToken ? acc.pair : acc.raw;
        PullLib.pullErc20Dual(l.currency0, l.currency1, amt0, amt1);
        (shares,,) = _deposit(amt0, amt1, to, sharesMin, deadline);
    }

    /// @notice CP deposit entry point.
    function deposit(uint256 amount0, uint256 amount1, address to, uint256 minLpAmount, uint256 deadline)
        external
        onlyLiquidityOwner
        nonReentrant
        accrueProtocolFee
        returns (uint256 lpAmount, uint256 used0, uint256 used1)
    {
        PullLib.pullErc20Dual(currency0(), currency1(), amount0, amount1);
        return _deposit(amount0, amount1, to, minLpAmount, deadline);
    }

    /// @notice CP depositWithPermit2Signature entry point.
    function depositWithPermit2Signature(
        uint256 amount0,
        uint256 amount1,
        address to,
        uint256 minLpAmount,
        uint256 deadline,
        bytes calldata permit2Data
    )
        external
        onlyLiquidityOwner
        nonReentrant
        accrueProtocolFee
        returns (uint256 lpAmount, uint256 used0, uint256 used1)
    {
        PullLib.pullPermit2SignatureDual(currency0(), currency1(), amount0, amount1, permit2Data);
        return _deposit(amount0, amount1, to, minLpAmount, deadline);
    }

    /// @notice CP depositWithPermit2Allowance entry point.
    function depositWithPermit2Allowance(
        uint256 amount0,
        uint256 amount1,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    )
        external
        onlyLiquidityOwner
        nonReentrant
        accrueProtocolFee
        returns (uint256 lpAmount, uint256 used0, uint256 used1)
    {
        PullLib.pullPermit2AllowanceDual(currency0(), currency1(), amount0, amount1);
        return _deposit(amount0, amount1, to, minLpAmount, deadline);
    }

    /// @notice CP depositWithSeShares entry point.
    function depositWithSeShares(uint256 amountRaw, uint256 amountSe, address to, uint256 minLpAmount, uint256 deadline)
        external
        onlyLiquidityOwner
        nonReentrant
        accrueProtocolFee
        returns (uint256 lpAmount, uint256 usedRaw, uint256 usedSe)
    {
        Repo.Layout storage l = Repo._layout();
        PullLib.pullErc20Single(l.rawToken, amountRaw);
        PullLib.pullErc20Single(l.standardExchange, amountSe);
        return _depositWithSeShares(amountRaw, amountSe, to, minLpAmount, deadline);
    }
}
