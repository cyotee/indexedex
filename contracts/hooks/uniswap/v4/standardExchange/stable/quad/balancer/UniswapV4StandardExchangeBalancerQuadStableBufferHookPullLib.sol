// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IAllowanceTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";

/**
 * @title UniswapV4StandardExchangeBalancerQuadStableBufferHookPullLib
 * @notice LP / SE funding: transferFrom if allowance else Permit2 AllowanceTransfer only.
 * @dev No SignatureTransfer / no permit2Data on join ABI.
 */
library UniswapV4StandardExchangeBalancerQuadStableBufferHookPullLib {
    using SafeERC20 for IERC20;

    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    error InvalidTransferAmount();
    error InvalidN();

    function pull(address token, address from, uint256 amount) external { _pull(token, from, amount); }

    function _pull(address token, address from, uint256 amount) private {
        if (amount == 0) return;
        uint256 beforeBalance = IERC20(token).balanceOf(address(this));
        if (IERC20(token).allowance(from, address(this)) >= amount) {
            IERC20(token).safeTransferFrom(from, address(this), amount);
        } else {
            if (amount > type(uint160).max) revert InvalidTransferAmount();
            IAllowanceTransfer(PERMIT2).transferFrom(from, address(this), uint160(amount), token);
        }
        if (IERC20(token).balanceOf(address(this)) - beforeBalance != amount) revert InvalidTransferAmount();
    }

    function pullMany(address[] memory tokens, address from, uint256[] memory amounts) external {
        _pullMany(tokens, from, amounts);
    }

    function pullManyDynamic(address[] memory tokens, address from, uint256[] memory amounts) external {
        _pullMany(tokens, from, amounts);
    }

    function _pullMany(address[] memory tokens, address from, uint256[] memory amounts) private {
        if (tokens.length != amounts.length) revert InvalidN();
        for (uint256 i; i < tokens.length; ++i) _pull(tokens[i], from, amounts[i]);
    }
}
