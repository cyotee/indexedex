// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
interface IComposedStableCommonDetfBonding {
    function bond(IERC20 tokenIn, uint256 amountIn, uint256 duration, address recipient, uint256 deadline) external returns (uint256 tokenId, uint256 principal);
    function initializeReserve(uint256 stableBpt, uint256 commonBpt, uint256 duration, address recipient, uint256 deadline) external returns (uint256 tokenId, uint256 principal);
    function previewBond(IERC20 tokenIn, uint256 amountIn, uint256 duration) external view returns (uint256 principal, uint256 liquidityDetf, uint256 pot);
    function previewInitializeReserve(uint256 stableBpt, uint256 commonBpt, uint256 duration) external view returns (uint256 principal, uint256 liquidityDetf, uint256 pot);
    function acceptedBondTokens() external view returns (address[] memory);
    function isAcceptedBondToken(IERC20 token) external view returns (bool);
}
