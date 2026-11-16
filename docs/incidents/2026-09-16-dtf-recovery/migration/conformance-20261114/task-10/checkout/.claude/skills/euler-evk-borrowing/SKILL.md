---
name: EVK Borrowing
description: This skill should be used when the user asks about "borrow", "repay", "debt", "pullDebt", "dToken", "owed", "interest accrual", "debtOf", or needs to understand EVault borrowing operations.
version: 0.1.0
---

# EVK Borrowing Operations

EVaults extend ERC-4626 with borrowing functionality. Users can borrow underlying assets against enabled collateral, with debt tracked via interest accumulator.

## Overview

```
┌──────────────────────────────────────────────────────────────┐
│                   BORROWING FLOW                             │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Borrower Account                                            │
│  ├── Collateral: [Vault A, Vault B] (enabled in EVC)         │
│  └── Controller: Vault C (this EVault)                       │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                     EVault (Controller)                 │ │
│  │                                                         │ │
│  │   borrow(assets) ──► Check LTV, send assets             │ │
│  │   repay(assets)  ──► Receive assets, reduce debt        │ │
│  │   pullDebt(assets, from) ──► Transfer debt between      │ │
│  │                              accounts                   │ │
│  │                                                         │ │
│  │   Debt Tracking:                                        │ │
│  │   ├── User owedExact = principal * accumulator          │ │
│  │   ├── Interest accrues continuously                     │ │
│  │   └── DToken represents debt externally                 │ │
│  │                                                         │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  Status Check (via EVC):                                     │
│  └── checkAccountStatus() verifies LTV after batch          │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Interest Accumulator

```solidity
// Debt is tracked as principal with accumulator for interest

struct VaultStorage {
    uint48 lastInterestAccumulatorUpdate;
    uint144 interestAccumulator;  // Scaled by 1e27 (RAY)

    uint168 totalBorrows;  // Total debt principal (internal units)
    // ...
}

struct UserStorage {
    uint256 borrowed;             // User's debt principal
    uint256 interestAccumulator;  // User's snapshot of accumulator
    // ...
}

// Calculate current debt owed
function debtOf(address account) public view returns (uint256) {
    UserStorage memory user = users[account];
    VaultCache memory cache = loadVault();

    // owed = principal * (currentAccumulator / userAccumulator)
    return user.borrowed.mulDiv(
        cache.interestAccumulator,
        user.interestAccumulator,
        Math.Rounding.Up
    );
}

// Total borrows with accrued interest
function totalBorrows() public view returns (uint256) {
    VaultCache memory cache = loadVault();
    return cache.totalBorrows;  // Already includes accrued interest
}
```

## Interest Accrual

```solidity
// Cache.sol - Interest accrues on each operation

function loadVault() internal view returns (VaultCache memory cache) {
    // Load from storage
    cache.lastInterestAccumulatorUpdate = vaultStorage.lastInterestAccumulatorUpdate;
    cache.interestAccumulator = vaultStorage.interestAccumulator;
    cache.totalBorrows = vaultStorage.totalBorrows;
    cache.cash = asset().balanceOf(address(this));

    // Accrue interest if time has passed
    uint256 elapsed = block.timestamp - cache.lastInterestAccumulatorUpdate;
    if (elapsed > 0 && cache.totalBorrows > 0) {
        // Get interest rate from IRM
        uint256 borrowRate = getInterestRate(cache);

        // Calculate interest factor
        uint256 interestFactor = borrowRate * elapsed / SECONDS_PER_YEAR;

        // Update accumulator
        uint256 newAccumulator = cache.interestAccumulator.mulDiv(
            1e27 + interestFactor,
            1e27,
            Math.Rounding.Up
        );

        // Update total borrows
        uint256 interest = cache.totalBorrows.mulDiv(
            interestFactor,
            1e27,
            Math.Rounding.Up
        );

        // Protocol fee
        uint256 feeAmount = interest * cache.interestFee / 1e18;

        cache.interestAccumulator = uint144(newAccumulator);
        cache.totalBorrows += interest;
        cache.lastInterestAccumulatorUpdate = uint48(block.timestamp);
    }
}
```

## Borrow

```solidity
/// @notice Borrow underlying assets
/// @param assets Amount to borrow
/// @param receiver Address to receive borrowed assets
/// @return Amount borrowed (same as input)
function borrow(uint256 assets, address receiver)
    external
    virtual
    use(MODULE_BORROWING)
    returns (uint256)
{}

// In Borrowing.sol module
function borrow(uint256 assets, address receiver) external returns (uint256) {
    VaultCache memory cache = initOperation(OP_BORROW);

    address account = msgSender();  // EVC-authenticated borrower

    // Check cash available
    if (assets > cache.cash) revert InsufficientCash();

    // Check borrow cap
    uint256 newTotalBorrows = cache.totalBorrows + assets;
    if (newTotalBorrows > borrowCap()) revert BorrowCapExceeded();

    // Calculate principal to add
    uint256 principal = assets.mulDiv(
        1e27,
        cache.interestAccumulator,
        Math.Rounding.Up
    );

    // Update user debt
    UserStorage storage user = users[account];

    // If first borrow or accumulator changed, settle existing debt first
    if (user.borrowed > 0 && user.interestAccumulator != cache.interestAccumulator) {
        uint256 currentDebt = user.borrowed.mulDiv(
            cache.interestAccumulator,
            user.interestAccumulator,
            Math.Rounding.Up
        );
        user.borrowed = currentDebt.mulDiv(
            1e27,
            cache.interestAccumulator,
            Math.Rounding.Up
        );
    }

    user.borrowed += principal;
    user.interestAccumulator = cache.interestAccumulator;

    // Update vault state
    cache.totalBorrows = newTotalBorrows;
    cache.cash -= assets;

    updateVault(cache);

    // Transfer to receiver
    asset().safeTransfer(receiver, assets);

    // Enable controller if not already
    // (vault must be borrower's controller to enforce health)
    evc.enableController(account, address(this));

    // Schedule status checks
    requireAccountStatusCheck(account);
    requireVaultStatusCheck();

    emit Borrow(account, receiver, assets);

    return assets;
}
```

## Repay

```solidity
/// @notice Repay borrowed assets
/// @param assets Amount to repay (type(uint256).max for full repay)
/// @param receiver Account whose debt to repay
/// @return Amount actually repaid
function repay(uint256 assets, address receiver)
    external
    virtual
    use(MODULE_BORROWING)
    returns (uint256)
{}

// In Borrowing.sol module
function repay(uint256 assets, address receiver) external returns (uint256) {
    VaultCache memory cache = initOperation(OP_REPAY);

    address account = msgSender();
    UserStorage storage user = users[receiver];

    // Calculate current debt
    uint256 currentDebt = user.borrowed.mulDiv(
        cache.interestAccumulator,
        user.interestAccumulator,
        Math.Rounding.Up
    );

    // Cap at current debt
    if (assets > currentDebt) assets = currentDebt;
    if (assets == 0) return 0;

    // Calculate principal being repaid
    uint256 principalRepaid = assets.mulDiv(
        1e27,
        cache.interestAccumulator,
        Math.Rounding.Down  // Round down principal = round up remaining debt
    );

    // Update user debt
    uint256 newPrincipal = currentDebt.mulDiv(
        1e27,
        cache.interestAccumulator,
        Math.Rounding.Up
    ) - principalRepaid;

    user.borrowed = newPrincipal;
    user.interestAccumulator = cache.interestAccumulator;

    // Update vault state
    cache.totalBorrows -= assets;
    cache.cash += assets;

    // Transfer from payer
    asset().safeTransferFrom(account, address(this), assets);

    updateVault(cache);

    // If fully repaid, can disable controller
    if (user.borrowed == 0) {
        // Let account disable controller themselves
    }

    // Schedule checks
    requireAccountStatusCheck(receiver);
    requireVaultStatusCheck();

    emit Repay(account, receiver, assets);

    return assets;
}
```

## Pull Debt

```solidity
/// @notice Pull debt from another account to caller
/// @dev Requires the "from" account to have authorized the pull
/// @param assets Amount of debt to pull
/// @param from Account to pull debt from
/// @return Amount of debt pulled
function pullDebt(uint256 assets, address from)
    external
    virtual
    use(MODULE_BORROWING)
    returns (uint256)
{}

// In Borrowing.sol module
function pullDebt(uint256 assets, address from) external returns (uint256) {
    VaultCache memory cache = initOperation(OP_PULL_DEBT);

    address account = msgSender();  // Account receiving debt

    UserStorage storage fromUser = users[from];
    UserStorage storage toUser = users[account];

    // Calculate from's current debt
    uint256 fromDebt = fromUser.borrowed.mulDiv(
        cache.interestAccumulator,
        fromUser.interestAccumulator,
        Math.Rounding.Up
    );

    // Cap at available debt
    if (assets > fromDebt) assets = fromDebt;
    if (assets == 0) return 0;

    // Calculate principal being transferred
    uint256 principalTransferred = assets.mulDiv(
        1e27,
        cache.interestAccumulator,
        Math.Rounding.Up
    );

    // Reduce from's debt
    uint256 fromNewPrincipal = fromDebt.mulDiv(
        1e27,
        cache.interestAccumulator,
        Math.Rounding.Up
    ) - principalTransferred;

    fromUser.borrowed = fromNewPrincipal;
    fromUser.interestAccumulator = cache.interestAccumulator;

    // Increase to's debt
    uint256 toDebt = toUser.borrowed.mulDiv(
        cache.interestAccumulator,
        toUser.interestAccumulator,
        Math.Rounding.Up
    );
    uint256 toNewPrincipal = (toDebt + assets).mulDiv(
        1e27,
        cache.interestAccumulator,
        Math.Rounding.Up
    );

    toUser.borrowed = toNewPrincipal;
    toUser.interestAccumulator = cache.interestAccumulator;

    updateVault(cache);

    // Enable controller for new borrower
    evc.enableController(account, address(this));

    // Schedule checks for both accounts
    requireAccountStatusCheck(from);
    requireAccountStatusCheck(account);

    emit PullDebt(account, from, assets);

    return assets;
}
```

## Touch (Force Interest Accrual)

```solidity
/// @notice Force interest accrual without other operations
function touch() external virtual use(MODULE_BORROWING) {}

// In Borrowing.sol
function touch() external {
    VaultCache memory cache = initOperation(OP_TOUCH);
    updateVault(cache);
    // Interest accrued in initOperation
}
```

## DToken (Debt Token)

```solidity
// DToken.sol - External view of debt

contract DToken is IERC20 {
    address public immutable eVault;

    constructor(address _eVault) {
        eVault = _eVault;
    }

    /// @notice Debt balance of an account
    function balanceOf(address account) external view returns (uint256) {
        return IEVault(eVault).debtOf(account);
    }

    /// @notice Total debt outstanding
    function totalSupply() external view returns (uint256) {
        return IEVault(eVault).totalBorrows();
    }

    /// @notice Transfer debt to another account
    /// @dev Receiver becomes borrower, must have collateral
    function transfer(address to, uint256 amount) external returns (bool) {
        address from = msg.sender;

        // Use EVC to transfer debt
        IEVault(eVault).pullDebt(amount, from);

        return true;
    }

    // Metadata
    function name() external view returns (string memory) {
        return string.concat("Debt: ", IEVault(eVault).name());
    }

    function symbol() external view returns (string memory) {
        return string.concat("d", IEVault(eVault).symbol());
    }

    function decimals() external view returns (uint8) {
        return IEVault(eVault).decimals();
    }
}
```

## Account Status Check

```solidity
// Liquidation.sol - Called by EVC at batch end

/// @notice Check if account is healthy (LTV within limits)
function checkAccountStatus(
    address account,
    address[] calldata collaterals
) external view returns (bytes4) {
    // Get account's debt value
    uint256 debtValue = getAccountDebtValue(account);

    if (debtValue == 0) {
        return ACCOUNT_STATUS_CHECK_SELECTOR;  // No debt = healthy
    }

    // Get collateral value with LTV haircuts
    uint256 collateralValue = 0;
    for (uint i = 0; i < collaterals.length; i++) {
        address collateral = collaterals[i];

        // Get LTV for this collateral
        LTVConfig memory ltv = ltvLookup[collateral];
        if (ltv.borrowLTV == 0) continue;  // Not accepted as collateral

        // Get collateral balance
        uint256 balance = IEVault(collateral).balanceOf(account);
        if (balance == 0) continue;

        // Get collateral value in unit of account
        uint256 value = oracle.getQuote(
            balance,
            IEVault(collateral).asset(),
            unitOfAccount
        );

        // Apply LTV haircut
        collateralValue += value * ltv.borrowLTV / 1e18;
    }

    // Check health
    if (collateralValue < debtValue) {
        revert AccountUnhealthy();  // Will revert entire batch
    }

    return ACCOUNT_STATUS_CHECK_SELECTOR;  // 0xe90a5c72
}
```

## Borrow Rate

```solidity
/// @notice Current borrow APY
function borrowAPY() public view returns (uint256) {
    VaultCache memory cache = loadVault();
    return getInterestRate(cache);
}

/// @notice Current supply APY
function supplyAPY() public view returns (uint256) {
    VaultCache memory cache = loadVault();
    uint256 borrowRate = getInterestRate(cache);

    // Supply APY = borrow rate * utilization * (1 - fee)
    uint256 utilization = cache.totalBorrows * 1e18 / (cache.cash + cache.totalBorrows);
    uint256 supplyRate = borrowRate * utilization / 1e18;

    return supplyRate * (1e18 - cache.interestFee) / 1e18;
}
```

## Events

```solidity
event Borrow(address indexed account, address indexed receiver, uint256 assets);
event Repay(address indexed sender, address indexed receiver, uint256 assets);
event PullDebt(address indexed from, address indexed to, uint256 assets);
event InterestAccrued(uint256 interestAccumulator, uint256 totalBorrows, uint256 feeShares);
```

## Reference Files

- `euler-vault-kit/src/EVault/modules/Borrowing.sol` - Borrowing module
- `euler-vault-kit/src/EVault/DToken.sol` - Debt token
- `euler-vault-kit/src/EVault/shared/BorrowUtils.sol` - Borrow utilities
- `euler-vault-kit/src/EVault/shared/Cache.sol` - Interest accrual
