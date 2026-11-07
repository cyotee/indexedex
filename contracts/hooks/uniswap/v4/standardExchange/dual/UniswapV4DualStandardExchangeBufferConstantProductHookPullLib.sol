// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ISignatureTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IAllowanceTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";

/**
 * @title UniswapV4DualStandardExchangeBufferConstantProductHookPullLib
 * @notice External Permit2 / ERC-20 pull helpers (size offload for mined hook).
 */
library UniswapV4DualStandardExchangeBufferConstantProductHookPullLib {
    using SafeERC20 for IERC20;

    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    error InvalidPermit2Data();

    function _requireDelta(address token, uint256 beforeBalance, uint256 amount) private view {
        uint256 received = IERC20(token).balanceOf(address(this)) - beforeBalance;
        if (received != amount) revert ISecurePullErrors.TransferDeltaInsufficient(amount, received);
    }

    function pullErc20Dual(address currency0, address currency1, uint256 amount0, uint256 amount1)
        external
    {
        uint256 before0 = IERC20(currency0).balanceOf(address(this));
        uint256 before1 = IERC20(currency1).balanceOf(address(this));
        IERC20(currency0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(currency1).safeTransferFrom(msg.sender, address(this), amount1);
        _requireDelta(currency0, before0, amount0);
        _requireDelta(currency1, before1, amount1);
    }

    function pullErc20Single(address tokenIn, uint256 amountIn) external {
        uint256 beforeIn = IERC20(tokenIn).balanceOf(address(this));
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        _requireDelta(tokenIn, beforeIn, amountIn);
    }

    function pullPermit2SignatureDual(
        address currency0,
        address currency1,
        uint256 amount0,
        uint256 amount1,
        bytes calldata permit2Data
    ) external {
        (ISignatureTransfer.PermitBatchTransferFrom memory permit, bytes memory signature) =
            abi.decode(permit2Data, (ISignatureTransfer.PermitBatchTransferFrom, bytes));
        if (permit.permitted.length != 2) revert InvalidPermit2Data();
        if (permit.permitted[0].token != currency0 || permit.permitted[1].token != currency1) {
            revert InvalidPermit2Data();
        }
        ISignatureTransfer.SignatureTransferDetails[] memory details =
            new ISignatureTransfer.SignatureTransferDetails[](2);
        details[0] = ISignatureTransfer.SignatureTransferDetails({
            to: address(this), requestedAmount: amount0
        });
        details[1] = ISignatureTransfer.SignatureTransferDetails({
            to: address(this), requestedAmount: amount1
        });
        uint256 before0 = IERC20(currency0).balanceOf(address(this));
        uint256 before1 = IERC20(currency1).balanceOf(address(this));
        ISignatureTransfer(PERMIT2).permitTransferFrom(permit, details, msg.sender, signature);
        _requireDelta(currency0, before0, amount0);
        _requireDelta(currency1, before1, amount1);
    }

    function pullPermit2SignatureSingle(
        address tokenIn,
        uint256 amountIn,
        bytes calldata permit2Data
    ) external {
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory signature) =
            abi.decode(permit2Data, (ISignatureTransfer.PermitTransferFrom, bytes));
        if (permit.permitted.token != tokenIn) revert InvalidPermit2Data();
        ISignatureTransfer.SignatureTransferDetails memory details = ISignatureTransfer
            .SignatureTransferDetails({to: address(this), requestedAmount: amountIn});
        uint256 beforeIn = IERC20(tokenIn).balanceOf(address(this));
        ISignatureTransfer(PERMIT2).permitTransferFrom(permit, details, msg.sender, signature);
        _requireDelta(tokenIn, beforeIn, amountIn);
    }

    function pullPermit2AllowanceDual(
        address currency0,
        address currency1,
        uint256 amount0,
        uint256 amount1
    ) external {
        uint256 before0 = IERC20(currency0).balanceOf(address(this));
        uint256 before1 = IERC20(currency1).balanceOf(address(this));
        IAllowanceTransfer(PERMIT2).transferFrom(
            msg.sender, address(this), uint160(amount0), currency0
        );
        IAllowanceTransfer(PERMIT2).transferFrom(
            msg.sender, address(this), uint160(amount1), currency1
        );
        _requireDelta(currency0, before0, amount0);
        _requireDelta(currency1, before1, amount1);
    }

    function pullPermit2AllowanceSingle(address tokenIn, uint256 amountIn) external {
        uint256 beforeIn = IERC20(tokenIn).balanceOf(address(this));
        IAllowanceTransfer(PERMIT2).transferFrom(
            msg.sender, address(this), uint160(amountIn), tokenIn
        );
        _requireDelta(tokenIn, beforeIn, amountIn);
    }
}
