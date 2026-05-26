// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IRouter} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IRouter.sol";
import {IRouterCommon} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IRouterCommon.sol";

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";

contract BalancerV3SinglePoolStandardExchange is IStandardExchange {
    using BetterSafeERC20 for IERC20;

    IRouter public immutable router;
    address public immutable pool;
    IERC20 public immutable bptToken;

    IERC20[] internal _poolTokens;
    mapping(address => uint256) internal _tokenIndexPlusOne;

    constructor(IRouter router_, address pool_, IERC20 bptToken_, IERC20[] memory poolTokens_) {
        router = router_;
        pool = pool_;
        bptToken = bptToken_;

        for (uint256 index = 0; index < poolTokens_.length; index++) {
            IERC20 token = poolTokens_[index];
            _poolTokens.push(token);
            _tokenIndexPlusOne[address(token)] = index + 1;
        }
    }

    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        if (amountIn == 0) {
            return 0;
        }

        if (address(tokenOut) == address(bptToken) && _supportsPoolToken(tokenIn)) {
            uint256[] memory amountsIn = _amountsIn(tokenIn, amountIn);
            amountOut = _queryAddLiquidityUnbalanced(amountsIn);
            return amountOut;
        }

        if (address(tokenIn) == address(bptToken) && _supportsPoolToken(tokenOut)) {
            amountOut = _queryRemoveLiquiditySingleTokenExactIn(amountIn, tokenOut);
            return amountOut;
        }

        revert InvalidRoute(address(tokenIn), address(tokenOut));
    }

    function exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut) {
        _checkDeadline(deadline);

        address payoutRecipient = recipient == address(0) ? msg.sender : recipient;

        if (address(tokenOut) == address(bptToken) && _supportsPoolToken(tokenIn)) {
            uint256 actualAmountIn = _receiveExactIn(tokenIn, amountIn, pretransferred);
            _approvePermit2ToRouter(tokenIn);
            amountOut = router.addLiquidityUnbalanced(pool, _amountsIn(tokenIn, actualAmountIn), minAmountOut, false, "");
            bptToken.safeTransfer(payoutRecipient, amountOut);
            return amountOut;
        }

        if (address(tokenIn) == address(bptToken) && _supportsPoolToken(tokenOut)) {
            uint256 actualBptIn = _receiveExactIn(tokenIn, amountIn, pretransferred);
            _approvePermit2ToRouter(tokenIn);
            uint256 minSingleTokenOut = minAmountOut == 0 ? 1 : minAmountOut;
            amountOut =
                router.removeLiquiditySingleTokenExactIn(pool, actualBptIn, tokenOut, minSingleTokenOut, false, "");
            tokenOut.safeTransfer(payoutRecipient, amountOut);
            return amountOut;
        }

        revert InvalidRoute(address(tokenIn), address(tokenOut));
    }

    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        if (amountOut == 0) {
            return 0;
        }

        if (address(tokenOut) == address(bptToken) && _supportsPoolToken(tokenIn)) {
            amountIn = _queryAddLiquiditySingleTokenExactOut(tokenIn, amountOut);
            return amountIn;
        }

        if (address(tokenIn) == address(bptToken) && _supportsPoolToken(tokenOut)) {
            amountIn = _queryRemoveLiquiditySingleTokenExactOut(tokenOut, amountOut);
            return amountIn;
        }

        revert InvalidRoute(address(tokenIn), address(tokenOut));
    }

    function exchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountIn) {
        _checkDeadline(deadline);

        address payoutRecipient = recipient == address(0) ? msg.sender : recipient;
        uint256 depositedAmount = _receiveMaxIn(tokenIn, maxAmountIn, pretransferred);

        if (address(tokenOut) == address(bptToken) && _supportsPoolToken(tokenIn)) {
            _approvePermit2ToRouter(tokenIn);
            amountIn = router.addLiquiditySingleTokenExactOut(pool, tokenIn, depositedAmount, amountOut, false, "");
            if (amountIn > maxAmountIn) {
                revert MaxAmountExceeded(maxAmountIn, amountIn);
            }
            _refundUnused(tokenIn, depositedAmount, amountIn, msg.sender);
            bptToken.safeTransfer(payoutRecipient, amountOut);
            return amountIn;
        }

        if (address(tokenIn) == address(bptToken) && _supportsPoolToken(tokenOut)) {
            _approvePermit2ToRouter(tokenIn);
            amountIn = router.removeLiquiditySingleTokenExactOut(pool, depositedAmount, tokenOut, amountOut, false, "");
            if (amountIn > maxAmountIn) {
                revert MaxAmountExceeded(maxAmountIn, amountIn);
            }
            _refundUnused(tokenIn, depositedAmount, amountIn, msg.sender);
            tokenOut.safeTransfer(payoutRecipient, amountOut);
            return amountIn;
        }

        revert InvalidRoute(address(tokenIn), address(tokenOut));
    }

    function _supportsPoolToken(IERC20 token_) internal view returns (bool) {
        return _tokenIndexPlusOne[address(token_)] != 0;
    }

    function _amountsIn(IERC20 tokenIn_, uint256 amountIn_) internal view returns (uint256[] memory amountsIn_) {
        uint256 tokenIndexPlusOne = _tokenIndexPlusOne[address(tokenIn_)];
        if (tokenIndexPlusOne == 0) {
            revert InvalidRoute(address(tokenIn_), address(bptToken));
        }

        amountsIn_ = new uint256[](_poolTokens.length);
        amountsIn_[tokenIndexPlusOne - 1] = amountIn_;
    }

    function _checkDeadline(uint256 deadline_) internal view {
        if (deadline_ < block.timestamp) {
            revert DeadlineExceeded(deadline_, block.timestamp);
        }
    }

    function _receiveExactIn(IERC20 tokenIn_, uint256 amountIn_, bool pretransferred_) internal returns (uint256) {
        if (!pretransferred_) {
            tokenIn_.safeTransferFrom(msg.sender, address(this), amountIn_);
        }
        return amountIn_;
    }

    function _receiveMaxIn(IERC20 tokenIn_, uint256 maxAmountIn_, bool pretransferred_) internal returns (uint256) {
        if (!pretransferred_) {
            tokenIn_.safeTransferFrom(msg.sender, address(this), maxAmountIn_);
        }
        return maxAmountIn_;
    }

    function _refundUnused(IERC20 tokenIn_, uint256 depositedAmount_, uint256 usedAmount_, address refundRecipient_) internal {
        if (depositedAmount_ > usedAmount_) {
            tokenIn_.safeTransfer(refundRecipient_, depositedAmount_ - usedAmount_);
        }
    }

    function _approvePermit2ToRouter(IERC20 token_) internal {
        token_.forceApprove(address(router), type(uint256).max);
        token_.forceApprove(address(IRouterCommon(address(router)).getPermit2()), type(uint256).max);
        IAllowanceTransfer(address(IRouterCommon(address(router)).getPermit2())).approve(
            address(token_), address(router), type(uint160).max, type(uint48).max
        );
    }

    function _queryAddLiquidityUnbalanced(uint256[] memory amountsIn_) internal view returns (uint256 amountOut_) {
        (bool success, bytes memory data) = address(router).staticcall(
            abi.encodeWithSelector(IRouter.queryAddLiquidityUnbalanced.selector, pool, amountsIn_, address(this), "")
        );
        require(success, "query add liquidity failed");
        amountOut_ = abi.decode(data, (uint256));
    }

    function _queryAddLiquiditySingleTokenExactOut(IERC20 tokenIn_, uint256 amountOut_)
        internal
        view
        returns (uint256 amountIn_)
    {
        (bool success, bytes memory data) = address(router).staticcall(
            abi.encodeWithSelector(
                IRouter.queryAddLiquiditySingleTokenExactOut.selector, pool, tokenIn_, amountOut_, address(this), ""
            )
        );
        require(success, "query single token add failed");
        amountIn_ = abi.decode(data, (uint256));
    }

    function _queryRemoveLiquiditySingleTokenExactIn(uint256 amountIn_, IERC20 tokenOut_)
        internal
        view
        returns (uint256 amountOut_)
    {
        (bool success, bytes memory data) = address(router).staticcall(
            abi.encodeWithSelector(
                IRouter.queryRemoveLiquiditySingleTokenExactIn.selector, pool, amountIn_, tokenOut_, address(this), ""
            )
        );
        require(success, "query single token remove failed");
        amountOut_ = abi.decode(data, (uint256));
    }

    function _queryRemoveLiquiditySingleTokenExactOut(IERC20 tokenOut_, uint256 amountOut_)
        internal
        view
        returns (uint256 amountIn_)
    {
        (bool success, bytes memory data) = address(router).staticcall(
            abi.encodeWithSelector(
                IRouter.queryRemoveLiquiditySingleTokenExactOut.selector, pool, tokenOut_, amountOut_, address(this), ""
            )
        );
        require(success, "query exact out remove failed");
        amountIn_ = abi.decode(data, (uint256));
    }
}