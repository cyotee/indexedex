// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IBasicVault {
    /**
     * @dev Returns the tokens this vault will accept/produce for exchanges.
     * @custom:selector 0x9d63848a
     */
    function vaultTokens() external view returns (address[] memory tokens_);

    /**
     * @custom:selector 0x46f910ac
     */
    function reserveOfToken(address token) external view returns (uint256 reserve_);

    /**
     * @custom:selector 0x75172a8b
     */
    function reserves() external view returns (uint256[] memory reserves_);
}
