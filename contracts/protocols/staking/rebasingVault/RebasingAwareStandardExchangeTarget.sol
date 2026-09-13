// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IRebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626.sol";
import {RebasingAwareERC4626Repo} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626Repo.sol";
import {RebasingAwareERC4626Common} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626Common.sol";

contract RebasingAwareStandardExchangeTarget is
    ReentrancyLockModifiers,
    IStandardExchangeIn,
    IStandardExchangeOut
{
    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        public
        view
        returns (uint256 amountOut)
    {
        RebasingAwareERC4626Common.requireUnlocked();
        if (amountIn == 0) return 0;
        (bool assetIn, bool shareIn) = _classify(tokenIn, tokenOut);
        RebasingAwareERC4626Common.Book memory book = RebasingAwareERC4626Common.liveBook();
        if (assetIn) return RebasingAwareERC4626Common.sharesForDeposit(amountIn, book);
        if (shareIn) return RebasingAwareERC4626Common.assetsForRedeem(amountIn, book);
        revert IStandardExchangeErrors.InvalidRoute(address(tokenIn), address(tokenOut));
    }

    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        public
        view
        returns (uint256 amountIn)
    {
        RebasingAwareERC4626Common.requireUnlocked();
        if (amountOut == 0) return 0;
        (bool assetIn, bool shareIn) = _classify(tokenIn, tokenOut);
        RebasingAwareERC4626Common.Book memory book = RebasingAwareERC4626Common.liveBook();
        if (assetIn) return RebasingAwareERC4626Common.assetsForMint(amountOut, book);
        if (shareIn) return RebasingAwareERC4626Common.sharesForWithdraw(amountOut, book);
        revert IStandardExchangeErrors.InvalidRoute(address(tokenIn), address(tokenOut));
    }

    function exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) public nonReentrant returns (uint256 amountOut) {
        if (amountIn == 0) revert IRebasingAwareERC4626.ZeroOperationAmount();
        (bool assetIn, bool shareIn) = _classify(tokenIn, tokenOut);
        if (!assetIn && !shareIn) {
            revert IStandardExchangeErrors.InvalidRoute(address(tokenIn), address(tokenOut));
        }
        RebasingAwareERC4626Common.requireReceiver(recipient, shareIn);
        RebasingAwareERC4626Common.requireDeadline(deadline);
        if (assetIn && pretransferred) {
            revert IRebasingAwareERC4626.AssetPretransferNotSupported();
        }
        if (assetIn) {
            return RebasingAwareERC4626Common.executeDeposit(amountIn, recipient, minAmountOut, false);
        }
        RebasingAwareERC4626Common.ShareSource source = pretransferred
            ? RebasingAwareERC4626Common.ShareSource.PublicBalanceRefundExcess
            : RebasingAwareERC4626Common.ShareSource.CallerOrApprovedOwner;
        address owner = pretransferred ? address(this) : msg.sender;
        return RebasingAwareERC4626Common.executeRedeem(
            amountIn, recipient, owner, minAmountOut, source, false
        );
    }

    function exchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) public nonReentrant returns (uint256 amountIn) {
        if (amountOut == 0) revert IRebasingAwareERC4626.ZeroOperationAmount();
        (bool assetIn, bool shareIn) = _classify(tokenIn, tokenOut);
        if (!assetIn && !shareIn) {
            revert IStandardExchangeErrors.InvalidRoute(address(tokenIn), address(tokenOut));
        }
        RebasingAwareERC4626Common.requireReceiver(recipient, shareIn);
        RebasingAwareERC4626Common.requireDeadline(deadline);
        if (assetIn && pretransferred) {
            revert IRebasingAwareERC4626.AssetPretransferNotSupported();
        }
        if (assetIn) {
            return RebasingAwareERC4626Common.executeMint(amountOut, recipient, maxAmountIn, false);
        }
        RebasingAwareERC4626Common.ShareSource source = pretransferred
            ? RebasingAwareERC4626Common.ShareSource.PublicBalanceRefundExcess
            : RebasingAwareERC4626Common.ShareSource.CallerOrApprovedOwner;
        address owner = pretransferred ? address(this) : msg.sender;
        return RebasingAwareERC4626Common.executeWithdraw(
            amountOut, recipient, owner, maxAmountIn, source, false
        );
    }

    function _classify(IERC20 tokenIn, IERC20 tokenOut)
        private
        view
        returns (bool assetIn, bool shareIn)
    {
        address asset_ = address(RebasingAwareERC4626Repo._asset());
        address share_ = address(this);
        assetIn = address(tokenIn) == asset_ && address(tokenOut) == share_;
        shareIn = address(tokenIn) == share_ && address(tokenOut) == asset_;
    }
}
