// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.35;

interface IEdProbeToken {
    function balanceOf(address) external view returns (uint256);
    function transferFrom(address, address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
    function exchangeIn(address, uint256, address, uint256, address, bool, uint256)
        external returns (uint256);
}

/// @notice Disposable source-mechanics witness. Not a Migration implementation.
contract EdCustodyProbe {
    IEdProbeToken constant ED = IEdProbeToken(0xaf0E1967c8F755c747615c5427108Bc549CA1122);
    IEdProbeToken constant DTF = IEdProbeToken(0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01);
    address public immutable original;
    error WrongWallet();
    error DeltaMismatch();
    error LateFailure();
    event Pulled(uint256 amount);
    event Converted(uint256 input, uint256 output);

    constructor(address original_) {
        original = original_;
    }

    function pull(uint256 q, bool failLate) external {
        if (msg.sender != original) revert WrongWallet();
        uint256 senderBefore = ED.balanceOf(original);
        uint256 custodyBefore = ED.balanceOf(address(this));
        if (!ED.transferFrom(original, address(this), q)) revert DeltaMismatch();
        if (senderBefore - ED.balanceOf(original) != q
            || ED.balanceOf(address(this)) - custodyBefore != q) revert DeltaMismatch();
        emit Pulled(q);
        if (failLate) revert LateFailure();
    }

    // Exact fixed-source route, with fixed recipient and a late rollback witness.
    function convert(uint256 q, uint256 minimum, uint256 deadline, bool failLate) external {
        if (msg.sender != original) revert WrongWallet();
        uint256 edBefore = ED.balanceOf(address(this));
        uint256 dtfBefore = DTF.balanceOf(address(this));
        if (!ED.approve(address(ED), q)) revert DeltaMismatch();
        uint256 output = ED.exchangeIn(
            address(ED), q, address(DTF), minimum, address(this), false, deadline
        );
        if (!ED.approve(address(ED), 0)) revert DeltaMismatch();
        if (edBefore - ED.balanceOf(address(this)) != q
            || DTF.balanceOf(address(this)) - dtfBefore != output) revert DeltaMismatch();
        emit Converted(q, output);
        if (failLate) revert LateFailure();
    }
}
