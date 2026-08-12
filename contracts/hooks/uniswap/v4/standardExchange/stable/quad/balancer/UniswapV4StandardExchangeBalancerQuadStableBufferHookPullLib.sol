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

    function pull(address token, address from, uint256 amount) external {
        if (amount == 0) return;
        uint256 allowance = IERC20(token).allowance(from, address(this));
        if (allowance >= amount) {
            IERC20(token).safeTransferFrom(from, address(this), amount);
            return;
        }
        IAllowanceTransfer(PERMIT2).transferFrom(from, address(this), uint160(amount), token);
    }

    function pullMany(address[4] memory tokens, address from, uint256[4] memory amounts) external {
        for (uint256 i; i < 4; ++i) {
            uint256 amount = amounts[i];
            if (amount == 0) continue;
            address token = tokens[i];
            uint256 allowance = IERC20(token).allowance(from, address(this));
            if (allowance >= amount) {
                IERC20(token).safeTransferFrom(from, address(this), amount);
            } else {
                IAllowanceTransfer(PERMIT2).transferFrom(from, address(this), uint160(amount), token);
            }
        }
    }

    function pullManyDynamic(address[] memory tokens, address from, uint256[] memory amounts) external {
        uint256 n = tokens.length;
        require(amounts.length == n, "len");
        for (uint256 i; i < n; ++i) {
            uint256 amount = amounts[i];
            if (amount == 0) continue;
            address token = tokens[i];
            uint256 allowance = IERC20(token).allowance(from, address(this));
            if (allowance >= amount) {
                IERC20(token).safeTransferFrom(from, address(this), amount);
            } else {
                IAllowanceTransfer(PERMIT2).transferFrom(from, address(this), uint160(amount), token);
            }
        }
    }
}
