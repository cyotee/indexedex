// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";

import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {AaveCrossVersionLoopExchangeBase} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeBase.sol";
import {CrossVersionLoopExecutor} from "contracts/protocols/lending/aave/cross-version/CrossVersionLoopExecutor.sol";
import {CrossVersionLoopService} from "contracts/protocols/lending/aave/cross-version/CrossVersionLoopService.sol";

/**
 * @title AaveCrossVersionLoopExchangeOutTarget
 * @author cyotee doge <doge.cyotee>
 * @notice Withdraw exit for the cross-version loop vault (PRD decisions 11, 14, 15): `exchangeOut`
 *         burns LP-style shares and delivers one pair token, freed via the never-borrow rule from the
 *         HF buffer. All-or-revert: a request exceeding what is currently freeable reverts (decision
 *         15). v1 services tokenA out from the V3 buffer; larger deleverage-served withdrawals and
 *         the oracle-sourced withdrawal fee (decision 18) are later refinements.
 */
contract AaveCrossVersionLoopExchangeOutTarget is AaveCrossVersionLoopExchangeBase, IStandardExchangeOut {
    /// @dev Shares required to redeem `amountOut` of tokenA, rounded up so the burn never under-charges.
    function _sharesForAmountOut(CrossVersionLoopExecutor.Market memory m, uint256 amountOut)
        internal
        view
        returns (uint256)
    {
        uint256 nav = CrossVersionLoopExecutor.navUsd(m);
        uint256 supply = ERC20Repo._totalSupply();
        if (nav == 0 || supply == 0) return 0;
        uint256 valueOut = CrossVersionLoopExecutor.valueUsd(m, m.tokenA, amountOut);
        return (valueOut * supply + nav - 1) / nav;
    }

    /// @inheritdoc IStandardExchangeOut
    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        CrossVersionLoopExecutor.Market memory m = _market();
        if (address(tokenIn) != address(this) || address(tokenOut) != address(m.tokenA)) {
            revert ExchangeOutNotAvailable();
        }
        // Serviceable only if the requested amount is within the currently-freeable buffer (decision 15).
        if (amountOut > CrossVersionLoopExecutor.maxWithdrawableA(m)) {
            revert AmountOutNotMet(amountOut, CrossVersionLoopExecutor.maxWithdrawableA(m));
        }
        amountIn = _sharesForAmountOut(m, amountOut);
    }

    /// @inheritdoc IStandardExchangeOut
    function exchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountIn) {
        if (deadline < block.timestamp) revert DeadlineExceeded(deadline, block.timestamp);
        CrossVersionLoopExecutor.Market memory m = _market();
        if (address(tokenIn) != address(this) || address(tokenOut) != address(m.tokenA)) {
            revert ExchangeOutNotAvailable();
        }

        uint256 freeable = CrossVersionLoopExecutor.maxWithdrawableA(m);
        if (amountOut > freeable) revert AmountOutNotMet(amountOut, freeable); // all-or-revert (decision 15)

        amountIn = _sharesForAmountOut(m, amountOut);
        if (amountIn > maxAmountIn) revert MaxAmountExceeded(maxAmountIn, amountIn);

        // Burn shares from the caller (or the vault, if pretransferred), then free + deliver tokenA.
        ERC20Repo._burn(pretransferred ? address(this) : msg.sender, amountIn);
        CrossVersionLoopExecutor.withdrawA(m, amountOut);
        tokenOut.transfer(recipient, amountOut);
    }
}
