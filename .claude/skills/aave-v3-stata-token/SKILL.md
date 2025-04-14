---
name: Aave V3 StataToken
description: This skill should be used when the user asks about "StataToken", "static aToken", "ERC4626", "ERC-4626", "StataTokenV2", "StataTokenFactory", "wrapped aToken", "yield-bearing vault", or needs to understand Aave V3's ERC4626 wrapper.
version: 0.1.0
---

# Aave V3 StataToken (Static aToken)

StataToken is an ERC-4626 compliant wrapper for Aave aTokens. It provides a standardized vault interface for aTokens, enabling integration with any ERC-4626 compatible protocol.

## Overview

```
┌──────────────────────────────────────────────────────────────┐
│                      STATA TOKEN                             │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────┐      wraps      ┌─────────────┐             │
│  │   aToken    │ ──────────────► │ StataToken  │             │
│  │  (aUSDC)    │                 │ (stataUSDC) │             │
│  └─────────────┘                 └─────────────┘             │
│                                                              │
│  Features:                                                   │
│  • Full ERC-4626 compatibility                               │
│  • Maintains liquidity mining eligibility                    │
│  • Upgradeable by governance                                 │
│  • Permissionless deployment via factory                     │
│  • Price feed (latestAnswer) for integrations                │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Why StataToken?

aTokens have a rebasing balance (grows over time), which can be problematic for:
- DeFi protocols expecting static balances
- Bridging to other chains
- LP positions in AMMs
- Accounting systems

StataToken solves this by wrapping aTokens with a static balance that accrues value.

## Contract Architecture

```solidity
// Inheritance chain
StataTokenV2
├── ERC20AaveLMUpgradeable     // Liquidity mining forwarding
├── ERC4626StataTokenUpgradeable // ERC-4626 implementation
├── PausableUpgradeable        // Emergency pause
├── RescuableUpgradeable       // Token rescue
└── ERC20PermitUpgradeable     // Permit support
```

## ERC-4626 Interface

```solidity
interface IERC4626 {
    // Asset info
    function asset() external view returns (address);

    // Deposit/Withdraw
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function mint(uint256 shares, address receiver) external returns (uint256 assets);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);

    // Accounting
    function totalAssets() external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);

    // Preview
    function previewDeposit(uint256 assets) external view returns (uint256);
    function previewMint(uint256 shares) external view returns (uint256);
    function previewWithdraw(uint256 assets) external view returns (uint256);
    function previewRedeem(uint256 shares) external view returns (uint256);

    // Limits
    function maxDeposit(address receiver) external view returns (uint256);
    function maxMint(address receiver) external view returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
    function maxRedeem(address owner) external view returns (uint256);
}
```

## StataToken Extensions

Beyond ERC-4626, StataToken adds:

```solidity
interface IStataTokenV2 {
    // Direct aToken deposits/withdrawals
    function depositATokens(uint256 assets, address receiver) external returns (uint256);
    function redeemATokens(uint256 shares, address receiver, address owner) external returns (uint256);

    // Deposit with permit
    function depositWithPermit(
        uint256 assets,
        address receiver,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256);

    // Price feed (Chainlink-compatible)
    function latestAnswer() external view returns (int256);

    // Claim liquidity mining rewards
    function claimRewards(address receiver, address[] calldata rewardTokens) external;

    // Refresh reward tokens
    function refreshRewardTokens() external;

    // Getters
    function aToken() external view returns (address);
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}
```

## Deposit Flows

### Deposit Underlying (USDC → stataUSDC)

```solidity
// 1. Approve StataToken for underlying
USDC.approve(stataUSDC, amount);

// 2. Deposit underlying
uint256 shares = stataUSDC.deposit(amount, receiver);

// Internally:
// - Transfers USDC to StataToken
// - Supplies to Aave Pool (gets aUSDC)
// - Mints stata shares to receiver
```

### Deposit aTokens (aUSDC → stataUSDC)

```solidity
// 1. Approve StataToken for aToken
aUSDC.approve(stataUSDC, amount);

// 2. Deposit aTokens directly
uint256 shares = stataUSDC.depositATokens(amount, receiver);

// Internally:
// - Transfers aUSDC to StataToken
// - Mints stata shares to receiver
```

## Withdrawal Flows

### Withdraw to Underlying (stataUSDC → USDC)

```solidity
// Withdraw specific amount of underlying
uint256 shares = stataUSDC.withdraw(amount, receiver, owner);

// Or redeem specific amount of shares
uint256 assets = stataUSDC.redeem(shares, receiver, owner);

// Internally:
// - Burns stata shares
// - Withdraws from Aave Pool
// - Transfers underlying to receiver
```

### Redeem to aTokens (stataUSDC → aUSDC)

```solidity
uint256 assets = stataUSDC.redeemATokens(shares, receiver, owner);

// Internally:
// - Burns stata shares
// - Transfers aTokens to receiver (no Aave withdrawal)
```

## Share Price / Exchange Rate

```solidity
// StataToken share price grows as aToken accrues interest
// shares = assets / exchangeRate

function convertToShares(uint256 assets) public view returns (uint256) {
    return assets.mulDiv(totalSupply() + 1, totalAssets() + 1, Math.Rounding.Down);
}

function convertToAssets(uint256 shares) public view returns (uint256) {
    return shares.mulDiv(totalAssets() + 1, totalSupply() + 1, Math.Rounding.Down);
}

// latestAnswer returns price for integrations
function latestAnswer() external view returns (int256) {
    // Returns: underlying_price × exchangeRate
    // Where underlying_price comes from AaveOracle
    return int256(getAssetPrice() * exchangeRate() / 1e18);
}
```

## Liquidity Mining

StataToken forwards Aave liquidity mining rewards:

```solidity
// ERC20AaveLMUpgradeable tracks scaled balances
// and computes reward shares for each holder

// Claim accumulated rewards
function claimRewards(address receiver, address[] calldata rewardTokens) external {
    for (uint256 i = 0; i < rewardTokens.length; i++) {
        uint256 reward = _claimReward(msg.sender, rewardTokens[i]);
        IERC20(rewardTokens[i]).safeTransfer(receiver, reward);
    }
}

// Refresh if new rewards added after StataToken creation
function refreshRewardTokens() external {
    // Permissionless - anyone can call
    // Syncs reward tokens from IncentivesController
}
```

## StataTokenFactory

Permissionless factory for deploying StataTokens:

```solidity
contract StataTokenFactory {
    // Deploy a new StataToken for any aToken
    function createStataToken(address aToken) external returns (address) {
        // Validate aToken is legitimate
        require(IPool(pool).getReserveAToken(underlying) == aToken, "Invalid aToken");

        // Deploy proxy with standard implementation
        address stataToken = Clones.clone(implementation);

        // Initialize
        IStataTokenV2(stataToken).initialize(
            aToken,
            string.concat("Static ", IERC20Metadata(aToken).name()),
            string.concat("stata", IERC20Metadata(aToken).symbol())
        );

        return stataToken;
    }

    // Get deployed StataToken for an asset
    function getStataToken(address underlying) external view returns (address);
}
```

## Pool Constraints

StataToken respects Aave Pool limitations:

```solidity
function maxDeposit(address) public view returns (uint256) {
    // Check supply cap
    uint256 supplyCap = pool.getConfiguration(underlying).getSupplyCap();
    if (supplyCap == 0) return type(uint256).max;

    uint256 currentSupply = aToken.scaledTotalSupply().rayMul(pool.getReserveNormalizedIncome(underlying));
    if (currentSupply >= supplyCap) return 0;

    return supplyCap - currentSupply;
}

function maxWithdraw(address owner) public view returns (uint256) {
    // Limited by available liquidity in Pool
    uint256 balance = convertToAssets(balanceOf(owner));
    uint256 availableLiquidity = IERC20(underlying).balanceOf(address(aToken));

    return balance < availableLiquidity ? balance : availableLiquidity;
}
```

## Pausability

Emergency pause functionality:

```solidity
// Only emergency admin can pause
function pause() external onlyRole(EMERGENCY_ADMIN_ROLE) {
    _pause();
}

function unpause() external onlyRole(EMERGENCY_ADMIN_ROLE) {
    _unpause();
}

// When paused:
// - No minting (deposit/mint)
// - No burning (withdraw/redeem)
// - No transfers
// - No reward claims
```

## Rescuable

Token rescue for stuck funds:

```solidity
// Rescue ERC20 tokens accidentally sent to contract
// Cannot rescue the underlying aToken
function emergencyTokenTransfer(
    address token,
    address to,
    uint256 amount
) external onlyRole(POOL_ADMIN_ROLE) {
    require(token != address(aToken), "Cannot rescue aToken");
    IERC20(token).safeTransfer(to, amount);
}
```

## Integration Example

```solidity
// Using StataToken with any ERC-4626 compatible protocol

// Example: Deposit to a yield aggregator
contract YieldAggregator {
    function depositToStata(
        IERC4626 stataToken,
        uint256 amount
    ) external {
        // Get underlying asset
        address underlying = stataToken.asset();

        // Transfer underlying from user
        IERC20(underlying).transferFrom(msg.sender, address(this), amount);

        // Approve and deposit
        IERC20(underlying).approve(address(stataToken), amount);
        uint256 shares = stataToken.deposit(amount, address(this));

        // Now we hold stataToken shares
        // Balance is static but value grows over time
    }
}
```

## Events

```solidity
// ERC-4626 events
event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
event Withdraw(address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);

// Reward events
event RewardsClaimed(address indexed user, address indexed rewardToken, uint256 amount);
```

## Reference Files

- `src/contracts/extensions/stata-token/StataTokenV2.sol` - Main implementation
- `src/contracts/extensions/stata-token/ERC4626StataTokenUpgradeable.sol` - ERC-4626 logic
- `src/contracts/extensions/stata-token/ERC20AaveLMUpgradeable.sol` - Liquidity mining
- `src/contracts/extensions/stata-token/StataTokenFactory.sol` - Deployment factory
- `src/contracts/extensions/stata-token/interfaces/IStataTokenV2.sol` - Interface
