// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {DETFFundedStakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";

/// @title IDetfBondNFT
/// @notice Fixed DETF principal, funded staking rewards and linear sDETF payouts.
interface IDetfBondNFT is IERC721 {
    function detf() external view returns (address);
    function lpToken() external view returns (IERC20);
    function initializeReservedBondNfts(address feeTo_, address creator_) external returns (uint256);
    function reservedBondNftsWired() external view returns (bool);

    /// @notice DETF-only: pull freshly minted principal and stake it into this new position.
    function createFundedPosition(uint256 principal_, uint256 duration_, address recipient_)
        external returns (uint256 tokenId_);
    function positionOf(uint256 tokenId_) external view returns (DETFFundedStakingMath.BondPosition memory);
    function previewClaim(uint256 tokenId_) external view returns (DETFFundedStakingMath.BondClaim memory);
    function claimPrincipal(uint256 tokenId_, address recipient_) external returns (uint256 principal_);
    function claimRewards(uint256 tokenId_, address recipient_) external returns (uint256 rewards_);
    function claimBond(uint256 tokenId_, address recipient_)
        external returns (uint256 principal_, uint256 rewards_);

    /// @notice Only the DETF can move reserve assets; funded bond DETF/sDETF is excluded.
    function transferHeldToken(IERC20 token_, address to_, uint256 amount_) external;

    event BondPurchased(
        uint256 indexed tokenId, address indexed recipient, uint256 principal, uint256 start, uint256 duration
    );
    event BondClaimed(
        uint256 indexed tokenId, address indexed recipient, uint256 principal, uint256 rewards
    );
}

/// @notice Common child-token getter, independent of a family's legacy route interfaces.
interface IDetfStakingToken {
    function rebasingClaimToken() external view returns (IERC20);
}
