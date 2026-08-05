// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    UniswapV4SingleStandardExchangeDETFCommon
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETFCommon.sol";
import {
    UniswapV4SingleStandardExchangeDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETFRepo.sol";

/// @title UniswapV4SingleStandardExchangeDETFExchangeOutTarget
/// @notice Primary burn: free DETF → pair only. Uses effectiveSupply; does NOT realize expansion.
abstract contract UniswapV4SingleStandardExchangeDETFExchangeOutTarget is
    UniswapV4SingleStandardExchangeDETFCommon
{
    using BetterSafeERC20 for IERC20;

    function _burnDetfExactIn(
        uint256 detfIn_,
        IERC20 tokenOut_,
        uint256 minOut_,
        address recipient_,
        bool pretransferred_,
        uint256 /* deadline_ */
    ) internal returns (uint256 amountOut_) {
        _requireReserveLive();
        if (!_isBurningAllowed()) {
            Repo.Storage storage s0 = Repo._layoutStruct();
            revert Repo.BurningNotAllowed(_syntheticPrice(), s0.burnThreshold);
        }
        if (recipient_ == address(0)) recipient_ = msg.sender;

        Repo.Storage storage s = Repo._layoutStruct();
        // Pair only.
        if (address(tokenOut_) != address(s.pairToken)) {
            revert Repo.InvalidRoute(IERC20(address(this)), tokenOut_);
        }

        if (!pretransferred_) {
            IERC20(address(this)).safeTransferFrom(msg.sender, address(this), detfIn_);
        }

        // Debt-inclusive burn: lpOut = detfBurned * protocolLp / (totalSupply + pending)
        // Does NOT call _realizeExpansionIfNeeded.
        uint256 pending_ = _previewPendingExpansionMint();
        uint256 supply_ = ERC20Repo._totalSupply();
        uint256 effectiveSupply_ = supply_ + pending_;
        uint256 protocolLp_ = _protocolLp();
        if (protocolLp_ == 0 || effectiveSupply_ == 0) revert Repo.EmptyProtocolLp();

        uint256 lpOut_ = detfIn_ * protocolLp_ / effectiveSupply_;
        if (lpOut_ == 0) revert Repo.EmptyProtocolLp();

        _burnDetf(address(this), detfIn_);
        _ensureProtocolLpOnDiamond(lpOut_);
        amountOut_ = _withdrawSinglePair(lpOut_, recipient_);

        if (amountOut_ < minOut_) {
            revert IStandardExchangeErrors.MinAmountNotMet(minOut_, amountOut_);
        }
    }

    function _previewBurnDetfExactIn(uint256 detfIn_, IERC20 tokenOut_)
        internal
        view
        returns (uint256 amountOut_)
    {
        if (!Repo._layoutStruct().isReserveLive) return 0;
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(tokenOut_) != address(s.pairToken)) return 0;
        uint256 pending_ = _previewPendingExpansionMint();
        uint256 supply_ = ERC20Repo._totalSupply();
        uint256 effectiveSupply_ = supply_ + pending_;
        uint256 protocolLp_ = _protocolLp();
        if (protocolLp_ == 0 || effectiveSupply_ == 0 || detfIn_ == 0) return 0;
        uint256 lpOut_ = detfIn_ * protocolLp_ / effectiveSupply_;
        if (lpOut_ == 0) return 0;
        amountOut_ = IHook(s.reserveHook).previewWithdrawSingle(lpOut_, address(s.pairToken));
    }
}
