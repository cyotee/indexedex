---
name: Uniswap V4 PoolManager
description: This skill should be used when the user asks about "PoolManager", "unlock", "unlockCallback", "singleton", "pool operations", or needs to understand the core PoolManager contract.
version: 0.1.0
---

# Uniswap V4 PoolManager

## Overview

The PoolManager is the singleton contract at the heart of Uniswap V4. It manages all pool state, enforces the unlock pattern for flash accounting, and coordinates hook callbacks.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         POOLMANAGER CONTRACT                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Inheritance:                                                                │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ IPoolManager ◄── ProtocolFees ◄── NoDelegateCall ◄── ERC6909Claims │    │
│  │                                           ▲                          │    │
│  │                                           │                          │    │
│  │                                      Extsload ◄── Exttload           │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  State:                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ mapping(PoolId => Pool.State) _pools     // All pool states         │    │
│  │ mapping(Currency => uint256) _reserves   // Token reserves          │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  Transient State (via tstore/tload):                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ Lock.IS_UNLOCKED                         // Lock state              │    │
│  │ CurrencyDelta[target][currency]          // Per-user deltas         │    │
│  │ NonzeroDeltaCount                        // Open delta count        │    │
│  │ CurrencyReserves.synced                  // Synced currency         │    │
│  │ CurrencyReserves.reservesOf              // Synced reserves         │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Unlock Pattern

All state-changing operations must occur within an `unlock()` callback:

```solidity
/// @notice Unlocks the PoolManager and calls the callback
/// @param data Arbitrary data to pass to the callback
/// @return result The return value from the callback
function unlock(bytes calldata data) external returns (bytes memory result) {
    if (Lock.isUnlocked()) AlreadyUnlocked.selector.revertWith();

    Lock.unlock();

    // Call back to the sender's unlockCallback function
    result = IUnlockCallback(msg.sender).unlockCallback(data);

    // Ensure all currency deltas have been settled
    if (NonzeroDeltaCount.read() != 0) CurrencyNotSettled.selector.revertWith();

    Lock.lock();
}
```

### Implementing unlockCallback

```solidity
contract MyRouter is IUnlockCallback {
    IPoolManager public immutable poolManager;

    function doSwap(PoolKey calldata key, IPoolManager.SwapParams calldata params)
        external
        returns (BalanceDelta delta)
    {
        // Encode operation data
        bytes memory data = abi.encode(key, params);

        // Enter the unlock context
        bytes memory result = poolManager.unlock(data);

        // Decode result
        delta = abi.decode(result, (BalanceDelta));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(poolManager));

        // Decode operation
        (PoolKey memory key, IPoolManager.SwapParams memory params) =
            abi.decode(data, (PoolKey, IPoolManager.SwapParams));

        // Perform swap
        BalanceDelta delta = poolManager.swap(key, params, "");

        // Settle deltas
        _settleDeltas(key, delta);

        return abi.encode(delta);
    }
}
```

## Core Operations

### Initialize Pool

```solidity
/// @notice Initialize a new pool
/// @param key The pool key (tokens, fee, tickSpacing, hooks)
/// @param sqrtPriceX96 The initial sqrt price
/// @return tick The initial tick
function initialize(PoolKey memory key, uint160 sqrtPriceX96)
    external
    noDelegateCall
    returns (int24 tick)
{
    // Validate pool key
    if (key.currency0 >= key.currency1) {
        CurrenciesOutOfOrderOrEqual.selector.revertWith(
            Currency.unwrap(key.currency0),
            Currency.unwrap(key.currency1)
        );
    }

    // Validate tick spacing
    TickSpacing.validateTickSpacing(key.tickSpacing);

    // Validate hook address encoding matches permissions
    key.hooks.validateHookPermissions(key);

    // Call beforeInitialize hook if enabled
    if (key.hooks.hasPermission(Hooks.BEFORE_INITIALIZE_FLAG)) {
        if (key.hooks.beforeInitialize(msg.sender, key, sqrtPriceX96) != IHooks.beforeInitialize.selector) {
            Hooks.InvalidHookResponse.selector.revertWith();
        }
    }

    // Get or create pool state
    PoolId id = key.toId();
    tick = _pools[id].initialize(sqrtPriceX96, _fetchProtocolFee(key), _fetchLPFee(key));

    // Call afterInitialize hook if enabled
    if (key.hooks.hasPermission(Hooks.AFTER_INITIALIZE_FLAG)) {
        if (key.hooks.afterInitialize(msg.sender, key, sqrtPriceX96, tick) != IHooks.afterInitialize.selector) {
            Hooks.InvalidHookResponse.selector.revertWith();
        }
    }

    emit Initialize(id, key.currency0, key.currency1, key.fee, key.tickSpacing, key.hooks, sqrtPriceX96, tick);
}
```

### Modify Liquidity

```solidity
struct ModifyLiquidityParams {
    int24 tickLower;       // Lower tick of position
    int24 tickUpper;       // Upper tick of position
    int256 liquidityDelta; // Amount to add (positive) or remove (negative)
    bytes32 salt;          // Salt for position uniqueness
}

/// @notice Modify liquidity for a position
function modifyLiquidity(
    PoolKey memory key,
    ModifyLiquidityParams memory params,
    bytes calldata hookData
) external onlyWhenUnlocked noDelegateCall returns (BalanceDelta callerDelta, BalanceDelta feesAccrued) {
    PoolId id = key.toId();
    Pool.State storage pool = _pools[id];

    pool.checkPoolInitialized();

    // Determine if adding or removing liquidity
    bool isAddingLiquidity = params.liquidityDelta > 0;

    // Call appropriate before hook
    if (isAddingLiquidity) {
        if (key.hooks.hasPermission(Hooks.BEFORE_ADD_LIQUIDITY_FLAG)) {
            bytes4 selector = key.hooks.beforeAddLiquidity(msg.sender, key, params, hookData);
            if (selector != IHooks.beforeAddLiquidity.selector) {
                Hooks.InvalidHookResponse.selector.revertWith();
            }
        }
    } else {
        if (key.hooks.hasPermission(Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG)) {
            bytes4 selector = key.hooks.beforeRemoveLiquidity(msg.sender, key, params, hookData);
            if (selector != IHooks.beforeRemoveLiquidity.selector) {
                Hooks.InvalidHookResponse.selector.revertWith();
            }
        }
    }

    // Execute liquidity modification
    (BalanceDelta principalDelta, BalanceDelta feeDelta) = pool.modifyLiquidity(
        Pool.ModifyLiquidityParams({
            owner: msg.sender,
            tickLower: params.tickLower,
            tickUpper: params.tickUpper,
            liquidityDelta: params.liquidityDelta,
            tickSpacing: key.tickSpacing,
            salt: params.salt
        })
    );

    // Apply deltas to caller
    callerDelta = principalDelta + feeDelta;
    feesAccrued = feeDelta;

    // Account for deltas
    _accountPoolBalanceDelta(key, callerDelta, msg.sender);

    // Call appropriate after hook
    BalanceDelta hookDelta;
    if (isAddingLiquidity) {
        if (key.hooks.hasPermission(Hooks.AFTER_ADD_LIQUIDITY_FLAG)) {
            (bytes4 selector, BalanceDelta returnDelta) = key.hooks.afterAddLiquidity(
                msg.sender, key, params, callerDelta, feesAccrued, hookData
            );
            if (selector != IHooks.afterAddLiquidity.selector) {
                Hooks.InvalidHookResponse.selector.revertWith();
            }
            hookDelta = returnDelta;
        }
    } else {
        // Similar for remove liquidity...
    }

    // Apply hook delta if any
    if (hookDelta != BalanceDeltaLibrary.ZERO_DELTA) {
        callerDelta = callerDelta + hookDelta;
        _accountPoolBalanceDelta(key, hookDelta, address(key.hooks));
    }

    emit ModifyLiquidity(id, msg.sender, params.tickLower, params.tickUpper, params.liquidityDelta, params.salt);
}
```

### Swap

```solidity
struct SwapParams {
    bool zeroForOne;           // true = token0→token1, false = token1→token0
    int256 amountSpecified;    // Negative = exact input, Positive = exact output
    uint160 sqrtPriceLimitX96; // Price limit for slippage protection
}

/// @notice Execute a swap
function swap(PoolKey memory key, SwapParams memory params, bytes calldata hookData)
    external
    onlyWhenUnlocked
    noDelegateCall
    returns (BalanceDelta swapDelta)
{
    // ... validation and hook calls ...
    // See uniswap-v4-swaps skill for full implementation
}
```

### Donate

```solidity
/// @notice Donate tokens to in-range liquidity providers
function donate(PoolKey memory key, uint256 amount0, uint256 amount1, bytes calldata hookData)
    external
    onlyWhenUnlocked
    noDelegateCall
    returns (BalanceDelta delta)
{
    PoolId id = key.toId();
    Pool.State storage pool = _pools[id];

    pool.checkPoolInitialized();

    // Call beforeDonate hook
    if (key.hooks.hasPermission(Hooks.BEFORE_DONATE_FLAG)) {
        bytes4 selector = key.hooks.beforeDonate(msg.sender, key, amount0, amount1, hookData);
        if (selector != IHooks.beforeDonate.selector) {
            Hooks.InvalidHookResponse.selector.revertWith();
        }
    }

    // Execute donation
    delta = pool.donate(amount0, amount1);

    // Account for deltas (donations are negative for caller)
    _accountPoolBalanceDelta(key, delta, msg.sender);

    // Call afterDonate hook
    if (key.hooks.hasPermission(Hooks.AFTER_DONATE_FLAG)) {
        bytes4 selector = key.hooks.afterDonate(msg.sender, key, amount0, amount1, hookData);
        if (selector != IHooks.afterDonate.selector) {
            Hooks.InvalidHookResponse.selector.revertWith();
        }
    }

    emit Donate(id, msg.sender, amount0, amount1);
}
```

## Accounting Functions

### Sync

Checkpoints the current ERC20 balance before settlement:

```solidity
/// @notice Sync the balance of a currency
function sync(Currency currency) external {
    // Store current balance in transient storage
    if (currency.isAddressZero()) {
        // Native currency - use contract balance
        CurrencyReserves.syncCurrencyAndReserves(currency, address(this).balance);
    } else {
        // ERC20 - query balance
        uint256 balance = IERC20Minimal(Currency.unwrap(currency)).balanceOf(address(this));
        CurrencyReserves.syncCurrencyAndReserves(currency, balance);
    }
}
```

### Settle

Pay tokens owed to the PoolManager:

```solidity
/// @notice Settle a currency debt
function settle() external payable onlyWhenUnlocked returns (uint256 paid) {
    return _settle(msg.sender);
}

function _settle(address recipient) internal returns (uint256 paid) {
    Currency currency = CurrencyReserves.getSyncedCurrency();

    // Calculate how much was paid
    uint256 reservesBefore = CurrencyReserves.getSyncedReserves();
    uint256 reservesNow = currency.balanceOfSelf();
    paid = reservesNow - reservesBefore;

    // Update delta
    _accountDelta(currency, -(paid.toInt128()), recipient);

    // Clear synced state
    CurrencyReserves.resetCurrency();
}
```

### Take

Withdraw tokens owed to the caller:

```solidity
/// @notice Take tokens from the PoolManager
function take(Currency currency, address to, uint256 amount) external onlyWhenUnlocked {
    // Update delta (positive = owed to caller, taking makes it less positive)
    _accountDelta(currency, amount.toInt128(), msg.sender);

    // Transfer tokens
    currency.transfer(to, amount);
}
```

### Clear

Settle an exact positive delta:

```solidity
/// @notice Clear a positive delta by forfeiting tokens
function clear(Currency currency, uint256 amount) external onlyWhenUnlocked {
    int256 current = currency.getDelta(msg.sender);

    // Can only clear positive deltas (tokens owed to caller)
    int128 amountDelta = amount.toInt128();
    if (amountDelta != current) {
        MustClearExactPositiveDelta.selector.revertWith();
    }

    // Zero out the delta without taking tokens
    _accountDelta(currency, -amountDelta, msg.sender);
}
```

### Mint / Burn (ERC6909)

```solidity
/// @notice Mint ERC6909 LP tokens
function mint(address to, uint256 id, uint256 amount) external onlyWhenUnlocked {
    // Decrease caller's delta (they're depositing tokens as LP)
    _accountDelta(CurrencyLibrary.fromId(id), amount.toInt128(), msg.sender);
    _mint(to, id, amount);
}

/// @notice Burn ERC6909 LP tokens
function burn(address from, uint256 id, uint256 amount) external onlyWhenUnlocked {
    // Increase caller's delta (they're withdrawing tokens from LP)
    _accountDelta(CurrencyLibrary.fromId(id), -(amount.toInt128()), msg.sender);
    _burn(from, id, amount);
}
```

## Modifiers

```solidity
/// @notice Prevents function execution if not unlocked
modifier onlyWhenUnlocked() {
    if (!Lock.isUnlocked()) ManagerLocked.selector.revertWith();
    _;
}
```

## Events

```solidity
event Initialize(
    PoolId indexed id,
    Currency indexed currency0,
    Currency indexed currency1,
    uint24 fee,
    int24 tickSpacing,
    IHooks hooks,
    uint160 sqrtPriceX96,
    int24 tick
);

event ModifyLiquidity(
    PoolId indexed id,
    address indexed sender,
    int24 tickLower,
    int24 tickUpper,
    int256 liquidityDelta,
    bytes32 salt
);

event Swap(
    PoolId indexed id,
    address indexed sender,
    int128 amount0,
    int128 amount1,
    uint160 sqrtPriceX96,
    uint128 liquidity,
    int24 tick,
    uint24 fee
);

event Donate(PoolId indexed id, address indexed sender, uint256 amount0, uint256 amount1);
```

## Reference Files

- `src/PoolManager.sol` - Main contract
- `src/interfaces/IPoolManager.sol` - Interface
- `src/interfaces/callback/IUnlockCallback.sol` - Callback interface
- `src/libraries/Lock.sol` - Lock state management
- `src/libraries/CurrencyDelta.sol` - Delta tracking
