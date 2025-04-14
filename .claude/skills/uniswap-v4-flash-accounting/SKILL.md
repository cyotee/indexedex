---
name: Uniswap V4 Flash Accounting
description: This skill should be used when the user asks about "flash accounting", "settle", "take", "sync", "transient storage", "currency deltas", "unlock pattern", or needs to understand the deferred settlement mechanism.
version: 0.1.0
---

# Uniswap V4 Flash Accounting

## Overview

Flash accounting is V4's mechanism for deferring token transfers until the end of a transaction. Instead of transferring tokens on every operation, the PoolManager tracks cumulative deltas per currency in transient storage. Users settle all debts before the unlock callback returns.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       FLASH ACCOUNTING FLOW                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Traditional (V3):                                                          │
│  ─────────────────                                                          │
│  swap() → transfer tokenIn → transfer tokenOut → done                       │
│  addLiquidity() → transfer token0 → transfer token1 → done                  │
│  (Each operation = immediate transfers)                                      │
│                                                                              │
│  Flash Accounting (V4):                                                      │
│  ─────────────────────                                                      │
│  unlock() ──┐                                                                │
│             │                                                                │
│             ├── swap() ────────► delta[ETH] += 1                            │
│             │                    delta[USDC] -= 1000                        │
│             │                                                                │
│             ├── swap() ────────► delta[ETH] += 0.5                          │
│             │                    delta[DAI] -= 500                          │
│             │                                                                │
│             ├── addLiquidity() ► delta[ETH] -= 2                            │
│             │                    delta[USDC] += 800                         │
│             │                                                                │
│             │  (Net: ETH=-0.5, USDC=-200, DAI=-500)                        │
│             │                                                                │
│             ├── sync(ETH) + settle() ► pay 0.5 ETH                          │
│             ├── sync(USDC) + settle() ► pay 200 USDC                        │
│             └── sync(DAI) + settle() ► pay 500 DAI                          │
│                                                                              │
│  ◄── callback returns, NonzeroDeltaCount must == 0                          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Transient Storage

V4 uses EIP-1153 transient storage (`tstore`/`tload`) for temporary state:

```solidity
// Lock state
library Lock {
    // Using a constant slot ensures predictable storage
    bytes32 internal constant IS_UNLOCKED_SLOT =
        bytes32(uint256(keccak256("Lock.IS_UNLOCKED_SLOT")) - 1);

    function unlock() internal {
        assembly {
            tstore(IS_UNLOCKED_SLOT, true)
        }
    }

    function lock() internal {
        assembly {
            tstore(IS_UNLOCKED_SLOT, false)
        }
    }

    function isUnlocked() internal view returns (bool unlocked) {
        assembly {
            unlocked := tload(IS_UNLOCKED_SLOT)
        }
    }
}
```

### Currency Delta Tracking

```solidity
library CurrencyDelta {
    /// @notice Compute storage slot for a (target, currency) pair
    function _computeSlot(address target, Currency currency) internal pure returns (bytes32 slot) {
        assembly {
            mstore(0, target)
            mstore(32, currency)
            slot := keccak256(0, 64)
        }
    }

    /// @notice Get the current delta for a target and currency
    function getDelta(Currency currency, address target) internal view returns (int256 delta) {
        bytes32 slot = _computeSlot(target, currency);
        assembly {
            delta := tload(slot)
        }
    }

    /// @notice Apply a delta change
    function applyDelta(Currency currency, address target, int128 delta)
        internal
        returns (int256 previous, int256 next)
    {
        bytes32 slot = _computeSlot(target, currency);
        assembly {
            previous := tload(slot)
        }
        next = previous + delta;
        assembly {
            tstore(slot, next)
        }
    }
}
```

### Nonzero Delta Count

Tracks how many currencies have non-zero deltas:

```solidity
library NonzeroDeltaCount {
    bytes32 internal constant NONZERO_DELTA_COUNT_SLOT =
        bytes32(uint256(keccak256("NonzeroDeltaCount.NONZERO_DELTA_COUNT_SLOT")) - 1);

    function read() internal view returns (uint256 count) {
        assembly {
            count := tload(NONZERO_DELTA_COUNT_SLOT)
        }
    }

    function increment() internal {
        assembly {
            let count := tload(NONZERO_DELTA_COUNT_SLOT)
            tstore(NONZERO_DELTA_COUNT_SLOT, add(count, 1))
        }
    }

    function decrement() internal {
        assembly {
            let count := tload(NONZERO_DELTA_COUNT_SLOT)
            tstore(NONZERO_DELTA_COUNT_SLOT, sub(count, 1))
        }
    }
}
```

### Currency Reserves

Tracks synced currency for settlement:

```solidity
library CurrencyReserves {
    bytes32 internal constant CURRENCY_SLOT =
        bytes32(uint256(keccak256("CurrencyReserves.CURRENCY_SLOT")) - 1);
    bytes32 internal constant RESERVES_OF_SLOT =
        bytes32(uint256(keccak256("CurrencyReserves.RESERVES_OF_SLOT")) - 1);

    function getSyncedCurrency() internal view returns (Currency currency) {
        assembly {
            currency := tload(CURRENCY_SLOT)
        }
    }

    function getSyncedReserves() internal view returns (uint256 reserves) {
        assembly {
            reserves := tload(RESERVES_OF_SLOT)
        }
    }

    function syncCurrencyAndReserves(Currency currency, uint256 reserves) internal {
        assembly {
            tstore(CURRENCY_SLOT, currency)
            tstore(RESERVES_OF_SLOT, reserves)
        }
    }

    function resetCurrency() internal {
        assembly {
            tstore(CURRENCY_SLOT, 0)
        }
    }
}
```

## Settlement Functions

### Sync

Checkpoints the current balance before transfer:

```solidity
/// @notice Sync balance of a currency for settlement
function sync(Currency currency) external {
    if (currency.isAddressZero()) {
        // Native currency (ETH) - use contract balance
        CurrencyReserves.syncCurrencyAndReserves(currency, address(this).balance);
    } else {
        // ERC20 - query token balance
        uint256 balance = currency.balanceOfSelf();
        CurrencyReserves.syncCurrencyAndReserves(currency, balance);
    }
}
```

### Settle

Pay tokens to reduce negative delta:

```solidity
/// @notice Settle a currency debt by paying tokens
function settle() external payable onlyWhenUnlocked returns (uint256 paid) {
    return _settle(msg.sender);
}

/// @notice Settle on behalf of another address
function settleFor(address recipient) external payable onlyWhenUnlocked returns (uint256 paid) {
    return _settle(recipient);
}

function _settle(address recipient) internal returns (uint256 paid) {
    Currency currency = CurrencyReserves.getSyncedCurrency();

    // Calculate payment = new balance - synced balance
    uint256 reservesBefore = CurrencyReserves.getSyncedReserves();
    uint256 reservesNow = currency.balanceOfSelf();
    paid = reservesNow - reservesBefore;

    // Apply negative delta (reduce debt)
    _accountDelta(currency, -(paid.toInt128()), recipient);

    // Clear synced currency
    CurrencyReserves.resetCurrency();
}
```

### Take

Withdraw tokens from positive delta:

```solidity
/// @notice Take tokens owed to the caller
function take(Currency currency, address to, uint256 amount) external onlyWhenUnlocked {
    // Apply positive delta (increase debt, offset by taking)
    _accountDelta(currency, amount.toInt128(), msg.sender);

    // Transfer tokens out
    currency.transfer(to, amount);
}
```

### Clear

Forfeit a positive delta without taking:

```solidity
/// @notice Clear a positive delta without taking tokens
function clear(Currency currency, uint256 amount) external onlyWhenUnlocked {
    int256 current = currency.getDelta(msg.sender);

    // Verify clearing exact positive amount
    int128 amountDelta = amount.toInt128();
    if (amountDelta != current || current < 0) {
        MustClearExactPositiveDelta.selector.revertWith();
    }

    // Zero out the delta
    _accountDelta(currency, -amountDelta, msg.sender);
}
```

## Delta Accounting

```solidity
/// @notice Internal delta accounting with nonzero count management
function _accountDelta(Currency currency, int128 delta, address target) internal {
    if (delta == 0) return;

    (int256 previous, int256 next) = currency.applyDelta(target, delta);

    // Update nonzero count
    if (previous == 0 && next != 0) {
        NonzeroDeltaCount.increment();
    } else if (previous != 0 && next == 0) {
        NonzeroDeltaCount.decrement();
    }
}

/// @notice Account deltas from pool operations
function _accountPoolBalanceDelta(PoolKey memory key, BalanceDelta delta, address target) internal {
    _accountDelta(key.currency0, delta.amount0(), target);
    _accountDelta(key.currency1, delta.amount1(), target);
}
```

## Settlement Patterns

### Pattern 1: Basic Swap Settlement

```solidity
function unlockCallback(bytes calldata data) external returns (bytes memory) {
    (PoolKey memory key, IPoolManager.SwapParams memory params) =
        abi.decode(data, (PoolKey, IPoolManager.SwapParams));

    // Execute swap
    BalanceDelta delta = poolManager.swap(key, params, "");

    // Settle: we owe input token, we're owed output token
    if (params.zeroForOne) {
        // Owe token0 (negative delta), owed token1 (positive delta)
        if (delta.amount0() < 0) {
            // Pay token0
            key.currency0.transfer(address(poolManager), uint256(-delta.amount0()));
            poolManager.sync(key.currency0);
            poolManager.settle();
        }
        if (delta.amount1() > 0) {
            // Take token1
            poolManager.take(key.currency1, msg.sender, uint256(delta.amount1()));
        }
    } else {
        // Opposite direction
        if (delta.amount1() < 0) {
            key.currency1.transfer(address(poolManager), uint256(-delta.amount1()));
            poolManager.sync(key.currency1);
            poolManager.settle();
        }
        if (delta.amount0() > 0) {
            poolManager.take(key.currency0, msg.sender, uint256(delta.amount0()));
        }
    }

    return abi.encode(delta);
}
```

### Pattern 2: Multi-Hop Optimization

```solidity
function multiHopSwap(SwapStep[] calldata steps) external {
    bytes memory data = abi.encode(steps);
    poolManager.unlock(data);
}

function unlockCallback(bytes calldata data) external returns (bytes memory) {
    SwapStep[] memory steps = abi.decode(data, (SwapStep[]));

    // Execute all swaps - deltas accumulate
    for (uint i = 0; i < steps.length; i++) {
        poolManager.swap(steps[i].key, steps[i].params, "");
    }

    // Only settle NET deltas at the end
    // Intermediate tokens cancel out!
    _settleAllDeltas();

    return "";
}
```

### Pattern 3: Add Liquidity with ERC6909

```solidity
function unlockCallback(bytes calldata data) external returns (bytes memory) {
    // Add liquidity
    (BalanceDelta delta, ) = poolManager.modifyLiquidity(key, params, "");

    // Pay tokens
    if (delta.amount0() < 0) {
        currency0.transfer(address(poolManager), uint256(-delta.amount0()));
        poolManager.sync(currency0);
        poolManager.settle();
    }
    if (delta.amount1() < 0) {
        currency1.transfer(address(poolManager), uint256(-delta.amount1()));
        poolManager.sync(currency1);
        poolManager.settle();
    }

    // Optionally mint ERC6909 LP tokens
    // poolManager.mint(recipient, currencyId, amount);

    return "";
}
```

## Benefits of Flash Accounting

1. **Gas Efficiency**: Only transfer net amounts, not intermediate balances
2. **Multi-Pool Operations**: Execute complex multi-hop swaps in single transaction
3. **Atomic Composability**: All-or-nothing execution across multiple pools
4. **Flash Loan Native**: Borrow tokens within callback, repay before return
5. **Reduced Token Approvals**: Only approve to PoolManager once

## TransientStateLibrary

External view functions for transient state:

```solidity
library TransientStateLibrary {
    function getSyncedReserves(IPoolManager manager) internal view returns (uint256) {
        return uint256(manager.exttload(CurrencyReserves.RESERVES_OF_SLOT));
    }

    function getSyncedCurrency(IPoolManager manager) internal view returns (Currency) {
        return Currency.wrap(address(uint160(uint256(manager.exttload(CurrencyReserves.CURRENCY_SLOT)))));
    }

    function getNonzeroDeltaCount(IPoolManager manager) internal view returns (uint256) {
        return uint256(manager.exttload(NonzeroDeltaCount.NONZERO_DELTA_COUNT_SLOT));
    }

    function isUnlocked(IPoolManager manager) internal view returns (bool) {
        return manager.exttload(Lock.IS_UNLOCKED_SLOT) != bytes32(0);
    }
}
```

## Reference Files

### v4-core
- `src/libraries/Lock.sol` - Lock state
- `src/libraries/CurrencyDelta.sol` - Delta tracking
- `src/libraries/NonzeroDeltaCount.sol` - Delta counter
- `src/libraries/CurrencyReserves.sol` - Synced reserves
- `src/libraries/TransientStateLibrary.sol` - External views
