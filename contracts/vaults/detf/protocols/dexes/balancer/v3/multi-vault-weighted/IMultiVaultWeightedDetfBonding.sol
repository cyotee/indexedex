// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

interface IMultiVaultWeightedDetfBonding {
    function bond(IERC20 tokenIn, uint256 amountIn, uint256 duration, address recipient, bool prepaid, uint256 deadline)
        external returns (uint256 tokenId, uint256 protocolLpAdded);
    function initializeReserve(uint256[] calldata amounts, uint256 duration, address recipient, uint256 deadline)
        external returns (uint256 tokenId, uint256 protocolLpAdded);
    function previewBond(IERC20 tokenIn, uint256 amountIn, uint256 duration)
        external view returns (uint256 principal, uint256 liquidityDetf, uint256 rewardPot);
    function previewInitializeReserve(uint256[] calldata amounts, uint256 duration)
        external view returns (uint256 principal, uint256 liquidityDetf, uint256 rewardPot);
    function acceptedBondTokens() external view returns (address[] memory);
    function joinDonatedCapital(IERC20 token, uint256 amount, uint256 deadline) external returns (uint256);
    function previewJoinDonatedCapital(IERC20 token, uint256 amount) external view returns (uint256);
    function notifyReserveDonated() external;
    function donate(IERC20 token, uint256 amount, bool prepaid) external;
}
