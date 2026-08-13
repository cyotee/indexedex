// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";

/// @title IUniV4DetfRebasingClaim
/// @notice Public surface of the Uni V4 DETF rebasing claim package (ERC-20 is the LP manager).
interface IUniV4DetfRebasingClaim {
    /// @notice Deposit pairToken or detfToken; mint rebasing tokens from ZapOut-to-pair contribution.
    function deposit(IERC20 tokenIn, uint256 amountIn, uint256 minRebasingOut, address recipient)
        external
        returns (uint256 rebasingTokensMinted);

    /// @notice Burn rebasing tokens → pairToken only via redeem ladder.
    function redeem(uint256 rebasingAmount, uint256 minPairOut, address recipient)
        external
        returns (uint256 pairOut);

    /// @notice Preview deposit mint.
    function previewDeposit(IERC20 tokenIn, uint256 amountIn) external view returns (uint256 rebasingTokensMinted);

    /// @notice Preview redeem pair obligation.
    function previewRedeem(uint256 rebasingAmount) external view returns (uint256 pairOut);

    /// @notice Full-exit ZapOut-to-pair valuation of managed reserve.
    function zapOutToPair() external view returns (uint256 pairValue);

    /// @notice DETF-only: absorb bond sell proceeds into wings; mint rebasing tokens to recipient.
    function absorbBondProceeds(uint256 pairAmount, uint256 detfAmount, address rebasingRecipient)
        external
        returns (uint256 rebasingTokensMinted);

    /// @notice DETF-only: deposit DETF as donation (mint 0 rebasing tokens).
    function donateDetf(uint256 detfAmount) external;

    function pairToken() external view returns (IERC20);
    function detfToken() external view returns (IERC20);
    function listingPoolKey() external view returns (PoolKey memory);
    function owner() external view returns (address);

    /* -------------------- Hook-LP principal (additive; CP wings unchanged) -------------------- */

    /// @notice Optional post-init: bind fungible hook LP as claim principal.
    function initializeHookLp(IERC20 reserveLp_) external;

    /// @notice DETF-only: absorb hook LP into this package; mint rebasing from Δ LP.
    function absorbHookLp(uint256 lpAmount, address rebasingRecipient) external returns (uint256 rebasingTokensMinted);

    function reserveLp() external view returns (IERC20);
}
