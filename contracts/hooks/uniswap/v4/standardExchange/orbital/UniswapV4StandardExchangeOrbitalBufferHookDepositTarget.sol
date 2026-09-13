// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4StandardExchangeOrbitalBufferHookDepositCore} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDepositCore.sol";

/// @notice Liquidity execution entrypoints. Shared core retains the accounting and checks.
abstract contract UniswapV4StandardExchangeOrbitalBufferHookDepositTarget is UniswapV4StandardExchangeOrbitalBufferHookDepositCore {
    function addLiquidity(
        uint256 a0Max,
        uint256 a1Max,
        uint256 a2Max,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) external returns (uint256 shares, uint256 a0, uint256 a1, uint256 a2) {
        return _entryAddLiquidity(a0Max, a1Max, a2Max, to, sharesMin, deadline, permit2Data);
    }



    function depositFlexible(
        uint256 amount0,
        bool amount0IsSeShare,
        uint256 amount1,
        bool amount1IsSeShare,
        uint256 amount2,
        bool amount2IsSeShare,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) external returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2) {
        return _entryDepositFlexible(amount0, amount0IsSeShare, amount1, amount1IsSeShare, amount2, amount2IsSeShare, to, sharesMin, deadline);
    }

    function joinProportional(
        uint256[] calldata amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) external returns (uint256 shares, uint256[] memory usedAmounts) {
        return _entryJoinProportional(amounts, to, sharesMin, deadline);
    }

    function joinUnbalanced(
        address[] calldata tokensIn,
        uint256[] calldata amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) external returns (uint256 shares) {
        return _entryJoinUnbalanced(tokensIn, amounts, to, sharesMin, deadline);
    }





}
