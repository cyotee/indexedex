// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';

interface IComposedStableCommonDetfBonding {
    function acceptedBondTokens() external view returns (address[] memory tokens);
    function isAcceptedBondToken(IERC20 token) external view returns (bool isAccepted);
    function bond(IERC20 tokenIn, uint256 amountIn, uint256 lockDuration, address recipient, bool wethAsEth, uint256 deadline)
        external
        payable
        returns (uint256 tokenId, uint256 shares);
    function sellNFT(uint256 tokenId, address recipient) external returns (uint256 richirMinted);
}