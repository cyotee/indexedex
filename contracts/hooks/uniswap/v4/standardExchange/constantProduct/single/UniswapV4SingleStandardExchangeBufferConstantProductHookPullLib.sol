// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ISignatureTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IAllowanceTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";

/**
 * @title UniswapV4SingleStandardExchangeBufferConstantProductHookPullLib
 * @notice ERC-20 + Permit2 pull helpers for dual-currency pool-order deposits.
 */
library UniswapV4SingleStandardExchangeBufferConstantProductHookPullLib {
    using SafeERC20 for IERC20;

    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    error InvalidPermit2Data();

    function pullErc20Dual(address currency0, address currency1, uint256 amount0, uint256 amount1)
        external
    {
        IERC20(currency0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(currency1).safeTransferFrom(msg.sender, address(this), amount1);
    }

    function pullErc20Single(address tokenIn, uint256 amountIn) external {
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
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
        details[0] =
            ISignatureTransfer.SignatureTransferDetails({to: address(this), requestedAmount: amount0});
        details[1] =
            ISignatureTransfer.SignatureTransferDetails({to: address(this), requestedAmount: amount1});
        ISignatureTransfer(PERMIT2).permitTransferFrom(permit, details, msg.sender, signature);
    }

    function pullPermit2SignatureSingle(address tokenIn, uint256 amountIn, bytes calldata permit2Data)
        external
    {
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory signature) =
            abi.decode(permit2Data, (ISignatureTransfer.PermitTransferFrom, bytes));
        if (permit.permitted.token != tokenIn) revert InvalidPermit2Data();
        ISignatureTransfer.SignatureTransferDetails memory details = ISignatureTransfer
            .SignatureTransferDetails({to: address(this), requestedAmount: amountIn});
        ISignatureTransfer(PERMIT2).permitTransferFrom(permit, details, msg.sender, signature);
    }

    function pullPermit2AllowanceDual(
        address currency0,
        address currency1,
        uint256 amount0,
        uint256 amount1
    ) external {
        IAllowanceTransfer(PERMIT2).transferFrom(
            msg.sender, address(this), uint160(amount0), currency0
        );
        IAllowanceTransfer(PERMIT2).transferFrom(
            msg.sender, address(this), uint160(amount1), currency1
        );
    }

    function pullPermit2AllowanceSingle(address tokenIn, uint256 amountIn) external {
        IAllowanceTransfer(PERMIT2).transferFrom(
            msg.sender, address(this), uint160(amountIn), tokenIn
        );
    }
}
