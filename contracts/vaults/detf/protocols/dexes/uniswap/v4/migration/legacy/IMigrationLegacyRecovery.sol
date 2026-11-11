// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Exact historical one-word exchange ABI, not today's two-output standard exchange.
interface IMigrationLegacyExchange {
    function exchangeIn(
        address tokenIn_, uint256 amountIn_, address tokenOut_, uint256 minimum_,
        address recipient_, bool pretransferred_, uint256 deadline_
    ) external returns (uint256);
}

interface IMigrationWeightedClaims {
    function claimBond(uint256 tokenId_, address recipient_) external returns (uint256 principal_, uint256 rewards_);
    function claimPrincipal(uint256 tokenId_, address recipient_) external returns (uint256);
    function claimRewards(uint256 tokenId_, address recipient_) external returns (uint256);
}

interface IMigrationWeightedReceipt is IMigrationLegacyExchange {
    struct StakingState {
        uint256 totalGons;
        uint256 gonsPerUnit;
        uint256 accountedBacking;
        uint256 allocationDust;
        uint256 stakingDust;
        uint256 feeWeight;
        uint256 creatorWeight;
    }
    function gonsOf(address account_) external view returns (uint256);
    function stakingState() external view returns (StakingState memory);
}

interface IMigrationEarlierClaims {
    function claimRewards(uint256 tokenId_, address recipient_) external returns (uint256);
}

interface IMigrationEarlierSale {
    /// @return originalShares_ Retired original LP accounting shares, NOT receipt output.
    function sellPositionToDetfNft(uint256 tokenId_, address recipient_) external returns (uint256 originalShares_);
}

interface IMigrationEarlierReceipt {
    function sharesOf(address account_) external view returns (uint256);
}
