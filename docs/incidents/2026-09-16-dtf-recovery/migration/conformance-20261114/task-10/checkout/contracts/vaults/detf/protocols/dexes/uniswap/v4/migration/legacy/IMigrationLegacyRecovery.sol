// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Exact historical one-word exchange ABI, not today's two-output standard exchange.
interface IMigrationLegacyExchange {
    function exchangeIn(
        address tokenIn_, uint256 amountIn_, address tokenOut_, uint256 minimum_,
        address recipient_, bool pretransferred_, uint256 deadline_
    ) external returns (uint256);
}

interface IMigrationWeightedLp is IMigrationLegacyExchange {
    function feeTo() external view returns (address);
}

interface IMigrationWeightedClaims {
    function claimBond(uint256 tokenId_, address recipient_) external returns (uint256 principal_, uint256 rewards_);
    function claimPrincipal(uint256 tokenId_, address recipient_) external returns (uint256);
    function claimRewards(uint256 tokenId_, address recipient_) external returns (uint256);
}

/// @notice Historical WD settlement called before either WS custody baseline.
interface IMigrationWeightedSynchronization {
    function synchronizeRewards() external;
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

/// @notice Authenticated historical staking SY route; shares and returned receipt units are native nine decimals.
interface IMigrationWeightedSy {
    function redeem(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_, bool internalBalance_)
        external returns (uint256 amountOut_);
}

/// @notice Authenticated W-SD ERC4626 own-share exit; native 28-decimal shares return 18-decimal DTF.
interface IMigrationDtfCustodySe {
    function redeem(uint256 shares_, address receiver_, address owner_) external returns (uint256 assets_);
}

/// @notice Executed pinned claim-vault layouts; native19 shares pay native9 static SY.
/// @dev Runtime and controlled-wallet traces authenticate these calls, not current-source equivalence.
interface IMigrationClaimVault {
    function deposit(uint256 assets_, address receiver_) external returns (uint256 shares_);
    function redeem(uint256 shares_, address receiver_, address owner_) external returns (uint256 assets_);
    function previewDeposit(uint256 assets_) external view returns (uint256 shares_);
    function previewRedeem(uint256 shares_) external view returns (uint256 assets_);
}

interface IMigrationEarlierClaims {
    function claimRewards(uint256 tokenId_, address recipient_) external returns (uint256);
}

interface IMigrationEarlierSynchronization {
    function compoundProtocolRewards() external returns (uint256 detfIn_, uint256 lpOut_);
}

interface IMigrationEarlierRedemption {
    function redeemClaim(uint256 amount_, address tokenOut_, uint256 minimum_, address recipient_, uint256 deadline_)
        external returns (uint256);
}

interface IMigrationEarlierSale {
    /// @return originalShares_ Retired original LP accounting shares, NOT receipt output.
    function sellPositionToDetfNft(uint256 tokenId_, address recipient_) external returns (uint256 originalShares_);
}

interface IMigrationEarlierReceipt {
    function sharesOf(address account_) external view returns (uint256);
    function totalShares() external view returns (uint256);
    function redemptionRate() external view returns (uint256);
}
