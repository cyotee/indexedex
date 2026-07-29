// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title IEtherFiWithdrawRequestNFT
 * @notice Integration surface for ether.fi WithdrawRequestNFT (async exits).
 */
interface IEtherFiWithdrawRequestNFT {
    struct WithdrawRequest {
        uint96 amountOfEEth;
        uint96 shareOfEEth;
        bool isValid;
        uint32 feeGwei;
    }

    function claimWithdraw(uint256 requestId) external;

    function getRequest(uint256 requestId) external view returns (WithdrawRequest memory);

    function isFinalized(uint256 requestId) external view returns (bool);

    function ownerOf(uint256 requestId) external view returns (address);
}
