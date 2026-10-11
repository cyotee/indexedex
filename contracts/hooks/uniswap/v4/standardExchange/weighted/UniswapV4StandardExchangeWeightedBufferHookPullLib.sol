// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IAllowanceTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";

import {ISignatureTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";

/**
 * @title UniswapV4StandardExchangeWeightedBufferHookPullLib
 * @notice Exact-receipt funding for weighted hooks.
 * @dev SE joins use allowance funding (Q24); raw weighted joins also support signed batches.
 */
library UniswapV4StandardExchangeWeightedBufferHookPullLib {
    using SafeERC20 for IERC20;

    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    error InvalidTransferAmount();
    error InvalidPermit2Data();

    /// @notice Pull `amount` of `token` from `from` to this contract.
    function pull(address token, address from, uint256 amount) external {
        _pull(token, from, amount);
    }

    function _pull(address token, address from, uint256 amount) private {
        if (amount == 0) return;
        uint256 beforeBalance = IERC20(token).balanceOf(address(this));
        uint256 allowance = IERC20(token).allowance(from, address(this));
        if (allowance >= amount) {
            IERC20(token).safeTransferFrom(from, address(this), amount);
        } else {
            if (amount > type(uint160).max) revert InvalidTransferAmount();
            IAllowanceTransfer(PERMIT2).transferFrom(from, address(this), uint160(amount), token);
        }
        _requireReceived(token, amount, beforeBalance);
    }

    function _requireReceived(address token, uint256 amount, uint256 beforeBalance) private view {
        uint256 afterBalance = IERC20(token).balanceOf(address(this));
        uint256 received = afterBalance > beforeBalance ? afterBalance - beforeBalance : 0;
        if (received != amount) {
            revert ISecurePullErrors.TransferDeltaInsufficient(amount, received);
        }
    }

    /// @notice Pull many tokens (binding order). Skips zero amounts.
    function pullMany(address[] memory tokens, address from, uint256[] memory amounts) external {
        uint256 n = tokens.length;
        require(amounts.length == n, "len");
        for (uint256 i; i < n; ++i) {
            _pull(tokens[i], from, amounts[i]);
        }
    }
    function pullSignatureBatch(
        address[] memory tokens,
        address from,
        uint256[] memory used,
        bytes calldata permit2Data
    ) external {
        (, ISignatureTransfer.PermitBatchTransferFrom memory permit, bytes memory signature) =
            abi.decode(permit2Data, (uint8, ISignatureTransfer.PermitBatchTransferFrom, bytes));
        uint256 n;
        for (uint256 i; i < tokens.length; ++i) {
            if (used[i] > 0) ++n;
        }
        if (permit.permitted.length != n) revert InvalidPermit2Data();

        ISignatureTransfer.SignatureTransferDetails[] memory details =
            new ISignatureTransfer.SignatureTransferDetails[](n);
        uint256[] memory beforeBalances = new uint256[](n);
        uint256 k;
        for (uint256 i; i < tokens.length; ++i) {
            if (used[i] == 0) continue;
            if (permit.permitted[k].token != tokens[i]) revert InvalidPermit2Data();
            beforeBalances[k] = IERC20(tokens[i]).balanceOf(address(this));
            details[k] = ISignatureTransfer.SignatureTransferDetails({
                to: address(this),
                requestedAmount: used[i]
            });
            ++k;
        }
        ISignatureTransfer(PERMIT2).permitTransferFrom(permit, details, from, signature);
        for (uint256 i; i < n; ++i) {
            _requireReceived(permit.permitted[i].token, details[i].requestedAmount, beforeBalances[i]);
        }
    }


}
