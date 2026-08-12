// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {AaveCrossVersionLoopExchangeBase} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeBase.sol";
import {CrossVersionLoopExecutor} from "contracts/protocols/lending/aave/cross-version/CrossVersionLoopExecutor.sol";
import {CrossVersionLoopService} from "contracts/protocols/lending/aave/cross-version/CrossVersionLoopService.sol";

/**
 * @title AaveCrossVersionLoopExchangeInTarget
 * @author cyotee doge <doge.cyotee>
 * @notice Deposit entry for the cross-version loop vault (PRD decisions 10, 11, 13): `exchangeIn`
 *         takes one pair token, builds the leveraged cross-version position via the executor, and
 *         mints LP-style proportional shares priced off live NAV, with a MINIMUM_LIQUIDITY
 *         first-deposit lock (decision 21). v1 is tokenA-in / A-first.
 */
contract AaveCrossVersionLoopExchangeInTarget is AaveCrossVersionLoopExchangeBase, IStandardExchangeIn {
    /// @inheritdoc IStandardExchangeIn
    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        CrossVersionLoopExecutor.Market memory m = _market();
        if (address(tokenOut) != address(this) || address(tokenIn) != address(m.tokenA)) {
            revert ExchangeInNotAvailable();
        }
        uint256 navBefore = CrossVersionLoopExecutor.navUsd(m);
        uint256 depositValue = CrossVersionLoopExecutor.valueUsd(m, tokenIn, amountIn);
        amountOut = CrossVersionLoopService.sharesForDeposit(navBefore, ERC20Repo._totalSupply(), depositValue);
        if (ERC20Repo._totalSupply() == 0) {
            amountOut = amountOut > MINIMUM_LIQUIDITY ? amountOut - MINIMUM_LIQUIDITY : 0;
        }
    }

    /// @inheritdoc IStandardExchangeIn
    function exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut) {
        if (deadline < block.timestamp) revert DeadlineExceeded(deadline, block.timestamp);
        CrossVersionLoopExecutor.Market memory m = _market();
        if (address(tokenOut) != address(this) || address(tokenIn) != address(m.tokenA)) {
            revert ExchangeInNotAvailable();
        }

        if (!pretransferred) {
            tokenIn.transferFrom(msg.sender, address(this), amountIn);
        }

        uint256 navBefore = CrossVersionLoopExecutor.navUsd(m);
        uint256 supplyBefore = ERC20Repo._totalSupply();
        uint256 depositValue = CrossVersionLoopExecutor.valueUsd(m, tokenIn, amountIn);

        CrossVersionLoopExecutor.depositLoopAFirst(m, amountIn, _loopConfig());

        amountOut = CrossVersionLoopService.sharesForDeposit(navBefore, supplyBefore, depositValue);

        if (supplyBefore == 0) {
            ERC20Repo._mint(address(1), MINIMUM_LIQUIDITY);
            amountOut = amountOut > MINIMUM_LIQUIDITY ? amountOut - MINIMUM_LIQUIDITY : 0;
        }

        if (amountOut < minAmountOut) revert MinAmountNotMet(minAmountOut, amountOut);
        ERC20Repo._mint(recipient, amountOut);
    }
}
