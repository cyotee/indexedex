// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {ReentrancyLockRepo} from "@crane/contracts/access/reentrancy/ReentrancyLockRepo.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {AaveCrossVersionLoopExchangeBase} from "./AaveCrossVersionLoopExchangeBase.sol";
import {CrossVersionLoopExecutor} from "./CrossVersionLoopExecutor.sol";
import {LoopPositionRepo} from "./LoopPositionRepo.sol";

/// @notice Exact-output withdrawals and native SY reuse the canonical funded standard routes.
contract AaveCrossVersionLoopExchangeOutTarget is
    AaveCrossVersionLoopExchangeBase, IStandardExchangeOut, NativeStandardYieldTarget
{
    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external view returns (uint256 amountIn)
    {
        ReentrancyLockRepo._onlyUnlocked();
        CrossVersionLoopExecutor.Market memory m = _market();
        if (address(tokenIn) != address(this) || tokenOut != m.tokenA) revert ExchangeOutNotAvailable();
        _requireFreeable(m, amountOut);
        return _sharesForAmountOut(m, amountOut);
    }

    function exchangeOut(IERC20 tokenIn, uint256 maxAmountIn, IERC20 tokenOut, uint256 amountOut,
        address recipient, bool pretransferred, uint256 deadline)
        external nonReentrant returns (uint256 amountIn)
    {
        _requireExchange(deadline, amountOut, recipient);
        CrossVersionLoopExecutor.Market memory m = _market();
        if (address(tokenIn) != address(this) || tokenOut != m.tokenA) revert ExchangeOutNotAvailable();
        _requireFreeable(m, amountOut);
        amountIn = _sharesForAmountOut(m, amountOut);
        if (amountIn > maxAmountIn) revert MaxAmountExceeded(maxAmountIn, amountIn);
        _burnWithdrawalShares(amountIn, pretransferred);
        _withdrawAndPay(m, amountOut, recipient);
    }

    function getTokensIn() public view override returns (address[] memory tokens_) {
        tokens_ = new address[](1);
        tokens_[0] = address(LoopPositionRepo._tokenA());
    }

    function getTokensOut() public view override returns (address[] memory) { return getTokensIn(); }
    function yieldToken() external pure override returns (address) { return address(0); }

    /// @dev The existing native position accounting unit is USD at oracle-base precision 8.
    /// The vault identifies that composite position; it is not an ERC20 accounting-asset address.
    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        return (IStandardizedYield.AssetType.LIQUIDITY, address(this), 8);
    }

    function exchangeRate() external view override returns (uint256) {
        ReentrancyLockRepo._onlyUnlocked();
        uint256 supply_ = ERC20Repo._totalSupply();
        return supply_ == 0 ? 1e18 : Math.mulDiv(CrossVersionLoopExecutor.navUsd(_market()), 1e18, supply_);
    }
}
