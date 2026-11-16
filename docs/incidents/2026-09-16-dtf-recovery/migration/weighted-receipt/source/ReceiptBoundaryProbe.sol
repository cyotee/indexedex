// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

interface IReceiptBoundarySource {
    function transferFrom(address from_, address to_, uint256 amount_) external returns (bool);
    function gonsOf(address account_) external view returns (uint256);
    function exchangeIn(
        address tokenIn_, uint256 amount_, address tokenOut_, uint256 minimum_,
        address recipient_, bool pretransferred_, uint256 deadline_
    ) external returns (uint256);
}

/// @notice Disposable custody/rollback witness, not a Migration adapter or credit implementation.
contract ReceiptBoundaryProbe {
    address constant RECEIPT = 0x4Fa4974a8a09660258B8edD430B51C1620eBFE5c;
    address constant BACKING = 0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7;

    error LateFailure(uint256 receivedGons);
    error ProtectedGons(uint256 actualDebit, uint256 bookedGons);

    function pullThenFail(uint256 nativeAmount_) external {
        uint256 before_ = IReceiptBoundarySource(RECEIPT).gonsOf(address(this));
        require(IReceiptBoundarySource(RECEIPT).transferFrom(msg.sender, address(this), nativeAmount_));
        revert LateFailure(IReceiptBoundarySource(RECEIPT).gonsOf(address(this)) - before_);
    }

    function unstakeProtecting(uint256 nativeAmount_, uint256 bookedGons_) external returns (uint256 out_) {
        uint256 before_ = IReceiptBoundarySource(RECEIPT).gonsOf(address(this));
        out_ = IReceiptBoundarySource(RECEIPT).exchangeIn(
            RECEIPT, nativeAmount_, BACKING, nativeAmount_, address(this), false, block.timestamp
        );
        uint256 debit_ = before_ - IReceiptBoundarySource(RECEIPT).gonsOf(address(this));
        if (debit_ > bookedGons_) revert ProtectedGons(debit_, bookedGons_);
    }
}
