// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
interface IUniswapV4UpperLowerWingsStandardExchangeVaultEconomic {
    function sleeveState() external view returns (uint256 local, uint256 required, uint256 percentage, bool unavailable);
    function positionInventory(uint8 slot) external view returns (uint256 principal0, uint256 principal1, uint256 fee0, uint256 fee1);
}
