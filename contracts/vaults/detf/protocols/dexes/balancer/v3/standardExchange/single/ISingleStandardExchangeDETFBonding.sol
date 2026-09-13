// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/// @notice Only duration-specific purchase and authorized reserve donation routes remain outside SE.
interface ISingleStandardExchangeDETFBonding {
    function bond(IERC20 tokenIn, uint256 amountIn, uint256 duration, address recipient, bool prepaid, uint256 deadline)
        external returns (uint256 tokenId, uint256 protocolLpAdded);
    function previewBond(IERC20 tokenIn, uint256 amountIn, uint256 duration)
        external view returns (uint256 principal, uint256 liquidityDetf, uint256 rewardPot);
    function acceptedBondTokens() external view returns (address[] memory);
    function joinDonatedCapital(IERC20 token, uint256 amount, uint256 deadline) external returns (uint256);
    function previewJoinDonatedCapital(IERC20 token, uint256 amount) external view returns (uint256);
    function notifyReserveDonated() external;
    function donate(IERC20 token, uint256 amount, bool prepaid) external;
}
