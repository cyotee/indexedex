# IResupplyPair Interface Reference

Complete interface for Resupply lending pairs.

## State View Functions

```solidity
// Collateral
function collateralContract() external view returns (address);
function totalCollateral() external view returns (uint256);
function userCollateralBalance(address user) external view returns (uint256);

// Borrowing
function asset() external view returns (address);  // reUSD
function totalBorrowShares() external view returns (uint256);
function totalBorrowAmount() external view returns (uint256);
function userBorrowShares(address user) external view returns (uint256);

// Configuration
function maxLTV() external view returns (uint256);
function liquidationFee() external view returns (uint256);
function borrowLimit() external view returns (uint256);
function oracle() external view returns (address);
function rateCalculator() external view returns (address);

// Interest
function currentRate() external view returns (uint256);
function lastAccrueTime() external view returns (uint256);
```

## Core Operations

```solidity
// Collateral management
function addCollateralVault(uint256 _collateralAmount, address _borrower) external;
function removeCollateralVault(uint256 _collateralAmount, address _receiver) external;

// Borrowing
function borrow(
    uint256 _borrowAmount,
    uint256 _underlyingAmount,
    address _receiver
) external returns (uint256 shares);

// Repayment
function repay(uint256 _shares, address _borrower) external returns (uint256 amountRepaid);

// Liquidation
function liquidate(address _borrower) external returns (uint256 collateralForLiquidator);
```

## Advanced Operations

```solidity
// Leveraged position (borrow → swap → add collateral)
function leveragedPosition(
    address _swapperAddress,
    uint256 _borrowAmount,
    uint256 _minCollateralReceived,
    bytes calldata _swapData
) external returns (uint256 collateralReceived);

// Repay using collateral (remove collateral → swap → repay)
function repayWithCollateral(
    address _swapperAddress,
    uint256 _collateralToSwap,
    uint256 _minAssetReceived,
    bytes calldata _swapData
) external returns (uint256 assetReceived);
```

## Helper Functions

```solidity
// Convert between shares and amounts
function getBorrowAmount(uint256 shares) external view returns (uint256);
function getBorrowShares(uint256 amount) external view returns (uint256);

// Health checking
function isSolvent(address borrower) external view returns (bool);
function getHealthFactor(address borrower) external view returns (uint256);

// Interest accrual
function accrue() external;
```

## Reward Functions

```solidity
// Reward claiming
function getReward(address _account, address _forwardTo) external;

// Reward tracking
function rewardTokens() external view returns (address[] memory);
function earned(address account, address token) external view returns (uint256);
```

## Events

```solidity
event AddCollateral(address indexed borrower, uint256 amount);
event RemoveCollateral(address indexed borrower, address indexed receiver, uint256 amount);
event Borrow(address indexed borrower, address indexed receiver, uint256 amount, uint256 shares);
event Repay(address indexed borrower, uint256 amount, uint256 shares);
event Liquidate(address indexed borrower, address indexed liquidator, uint256 debt, uint256 collateral);
event AccrueInterest(uint256 interestEarned, uint256 newRate);
```

## Usage Examples

### Basic Borrow Flow

```solidity
// 1. Approve collateral
IERC20(collateralVault).approve(pair, collateralAmount);

// 2. Add collateral
IResupplyPair(pair).addCollateralVault(collateralAmount, msg.sender);

// 3. Borrow reUSD
uint256 shares = IResupplyPair(pair).borrow(borrowAmount, 0, msg.sender);
```

### Repay and Withdraw

```solidity
// 1. Approve reUSD
IERC20(reUSD).approve(pair, repayAmount);

// 2. Get shares for amount
uint256 shares = IResupplyPair(pair).getBorrowShares(repayAmount);

// 3. Repay
IResupplyPair(pair).repay(shares, msg.sender);

// 4. Remove collateral
IResupplyPair(pair).removeCollateralVault(collateralAmount, msg.sender);
```
