// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockRepo} from "@crane/contracts/access/reentrancy/ReentrancyLockRepo.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {AaveCrossVersionLoopExchangeBase} from "./AaveCrossVersionLoopExchangeBase.sol";
import {CrossVersionLoopExecutor} from "./CrossVersionLoopExecutor.sol";
import {CrossVersionLoopService} from "./CrossVersionLoopService.sol";

/// @notice Canonical tokenA deposit and share redemption at the vault's retained live NAV.
contract AaveCrossVersionLoopExchangeInTarget is AaveCrossVersionLoopExchangeBase, IStandardExchangeIn {
    using SafeERC20 for IERC20;

    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external view returns (uint256 amountOut)
    {
        ReentrancyLockRepo._onlyUnlocked();
        CrossVersionLoopExecutor.Market memory m = _market();
        if (address(tokenIn) == address(this) && tokenOut == m.tokenA) return _amountForShares(m, amountIn);
        if (address(tokenOut) != address(this) || tokenIn != m.tokenA) revert ExchangeInNotAvailable();
        uint256 supply_ = ERC20Repo._totalSupply();
        amountOut = CrossVersionLoopService.sharesForDeposit(CrossVersionLoopExecutor.navUsd(m), supply_,
            CrossVersionLoopExecutor.valueUsd(m, tokenIn, amountIn));
        if (supply_ == 0) amountOut = amountOut > MINIMUM_LIQUIDITY ? amountOut - MINIMUM_LIQUIDITY : 0;
    }

    function exchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut, uint256 minAmountOut,
        address recipient, bool pretransferred, uint256 deadline)
        external nonReentrant returns (uint256 amountOut)
    {
        _requireExchange(deadline, amountIn, recipient);
        CrossVersionLoopExecutor.Market memory m = _market();
        if (address(tokenIn) == address(this) && tokenOut == m.tokenA) {
            amountOut = _amountForShares(m, amountIn);
            if (amountOut == 0) revert ZeroLoopAmount();
            if (amountOut < minAmountOut) revert MinAmountNotMet(minAmountOut, amountOut);
            _burnWithdrawalShares(amountIn, pretransferred);
            _withdrawAndPay(m, amountOut, recipient);
            return amountOut;
        }
        if (address(tokenOut) != address(this) || tokenIn != m.tokenA) revert ExchangeInNotAvailable();
        if (pretransferred) revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, 0);
        return _depositInput(m, amountIn, minAmountOut, recipient);
    }

    function _depositInput(CrossVersionLoopExecutor.Market memory m, uint256 amountIn,
        uint256 minAmountOut, address recipient) private returns (uint256 amountOut)
    {
        IERC20 tokenIn = m.tokenA;
        uint256 nav_ = CrossVersionLoopExecutor.navUsd(m);
        uint256 supply_ = ERC20Repo._totalSupply();
        uint256 before_ = tokenIn.balanceOf(address(this));
        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        uint256 received_ = tokenIn.balanceOf(address(this)) - before_;
        if (received_ < amountIn) revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, received_);
        amountOut = CrossVersionLoopService.sharesForDeposit(nav_, supply_,
            CrossVersionLoopExecutor.valueUsd(m, tokenIn, amountIn));
        if (supply_ == 0) {
            if (amountOut <= MINIMUM_LIQUIDITY) revert ZeroLoopAmount();
            amountOut -= MINIMUM_LIQUIDITY;
            ERC20Repo._mint(address(1), MINIMUM_LIQUIDITY);
        }
        if (amountOut == 0) revert ZeroLoopAmount();
        if (amountOut < minAmountOut) revert MinAmountNotMet(minAmountOut, amountOut);
        CrossVersionLoopExecutor.depositLoopAFirst(m, amountIn, _loopConfig());
        ERC20Repo._mint(recipient, amountOut);
    }
}
