// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {IStataTokenV2} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/stata-token/interfaces/IStataTokenV2.sol";
import {IAaveV3StataStandardVault} from "contracts/interfaces/IAaveV3StataStandardVault.sol";
import {AaveV3StataStandardExchangeCommon} from "./AaveV3StataStandardExchangeCommon.sol";

/// @notice Exact-output redemption through the same proportional Stata backing as exact-input/SY exits.
contract AaveV3StataStandardExchangeOutTarget is AaveV3StataStandardExchangeCommon, ReentrancyLockModifiers, IStandardExchangeOut {
    using SafeERC20 for IERC20;
    error InvalidStataRoute(address tokenIn, address tokenOut);
    error InvalidStataPayment();
    error StataMaximumExceeded(uint256 maximum, uint256 required);

    function _stata() internal view returns (IStataTokenV2) {
        return IStataTokenV2(IAaveV3StataStandardVault(address(this)).stataToken());
    }

    function previewExchangeOut(IERC20 in_, IERC20 out_, uint256 amount_) external view returns (uint256) {
        return _requiredShares(in_, out_, amount_);
    }

    function _requiredShares(IERC20 in_, IERC20 out_, uint256 amount_) internal view returns (uint256) {
        IStataTokenV2 stata_ = _stata();
        if (address(in_) != address(this) || (address(out_) != address(stata_) && address(out_) != stata_.asset() && address(out_) != stata_.aToken())) {
            revert InvalidStataRoute(address(in_), address(out_));
        }
        if (amount_ == 0) return 0;
        uint256 needed_ = address(out_) == address(stata_) ? amount_ : stata_.previewWithdraw(amount_);
        uint256 held_ = IERC20(address(stata_)).balanceOf(address(this));
        return Math.mulDiv(needed_, ERC20Repo._totalSupply(), held_, Math.Rounding.Ceil);
    }

    function exchangeOut(IERC20 in_, uint256 maximum_, IERC20 out_, uint256 amount_, address to_, bool prepaid_, uint256 deadline_)
        external nonReentrant returns (uint256 spent_)
    {
        if (amount_ == 0 || to_ == address(0) || block.timestamp > deadline_) revert InvalidStataPayment();
        spent_ = _requiredShares(in_, out_, amount_);
        if (spent_ > maximum_) revert StataMaximumExceeded(maximum_, spent_);
        _secureSelfBurn(msg.sender, spent_, prepaid_);
        IStataTokenV2 stata_ = _stata();
        if (address(out_) == address(stata_)) out_.safeTransfer(to_, amount_);
        else if (address(out_) == stata_.asset()) stata_.withdraw(amount_, to_, address(this));
        else {
            // Preserve the existing underlying withdrawal/supply route for exact aToken output.
            stata_.withdraw(amount_, address(this), address(this));
            IERC20 base_ = IERC20(stata_.asset());
            base_.forceApprove(address(stata_.POOL()), amount_);
            stata_.POOL().supply(stata_.asset(), amount_, to_, 0);
            base_.forceApprove(address(stata_.POOL()), 0);
        }
        _collectAndForwardRewards();
        _syncAllExpectedHoldReserves();
    }
}
