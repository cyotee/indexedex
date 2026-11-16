---
name: Uniswap V4 Architecture
description: This skill should be used when the user asks about "Uniswap V4 architecture", "V4 overview", "singleton pattern", "V3 vs V4 differences", or needs a high-level understanding of how Uniswap V4 works.
version: 0.1.0
---

# Uniswap V4 Architecture

## Overview

Uniswap V4 represents a fundamental architectural shift from V3. Instead of deploying a separate contract per pool, V4 uses a singleton PoolManager that manages all pools internally. This enables hooks—customizable callbacks that let developers extend pool behavior.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         UNISWAP V4 ARCHITECTURE                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                        ┌─────────────────────────┐                          │
│                        │     User / Router       │                          │
│                        └───────────┬─────────────┘                          │
│                                    │                                         │
│                                    │ unlock(callbackData)                    │
│                                    ▼                                         │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                          POOL MANAGER                                 │   │
│  │                     (Singleton Contract)                              │   │
│  │                                                                       │   │
│  │  ┌─────────────────────────────────────────────────────────────────┐ │   │
│  │  │ Pool States: mapping(PoolId => Pool.State)                      │ │   │
│  │  │                                                                  │ │   │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐        │ │   │
│  │  │  │ Pool A   │  │ Pool B   │  │ Pool C   │  │ Pool D   │  ...   │ │   │
│  │  │  │ ETH/USDC │  │ ETH/DAI  │  │ WBTC/ETH │  │ Custom   │        │ │   │
│  │  │  │ 0.3% fee │  │ 0.3% fee │  │ 0.05%    │  │ +Hooks   │        │ │   │
│  │  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘        │ │   │
│  │  └─────────────────────────────────────────────────────────────────┘ │   │
│  │                                                                       │   │
│  │  Operations: initialize | modifyLiquidity | swap | donate            │   │
│  │                                                                       │   │
│  │  Accounting: sync | settle | take | clear | mint | burn             │   │
│  │                                                                       │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                    │                              │                          │
│                    │ Hook Callbacks               │ ERC6909 LP Tokens        │
│                    ▼                              ▼                          │
│  ┌────────────────────────┐          ┌────────────────────────┐             │
│  │     Hook Contract      │          │   LP Token Holders     │             │
│  │  (Optional per pool)   │          │   (ERC6909 balances)   │             │
│  └────────────────────────┘          └────────────────────────┘             │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## V3 vs V4 Comparison

| Feature | V3 | V4 |
|---------|-----|-----|
| **Architecture** | Distributed (one contract per pool) | Singleton (one PoolManager for all) |
| **Pool Identity** | Contract address | PoolKey hash → PoolId |
| **LP Tokens** | ERC721 NFT positions | ERC6909 multi-token |
| **Token Transfers** | Immediate per operation | Flash accounting (deferred) |
| **Customization** | None | Hooks (14 callback points) |
| **Fees** | Static per pool | Static + Dynamic (hook-controlled) |
| **Gas Efficiency** | Separate storage per pool | Shared + transient storage |
| **Factory** | UniswapV3Factory | Not needed (pools are internal) |
| **Transient Storage** | Not used | Core to flash accounting |

## Core Components

### PoolManager

The singleton contract managing all pools:

```solidity
contract PoolManager is IPoolManager, ProtocolFees, NoDelegateCall, ERC6909Claims {
    using Pool for Pool.State;
    using Hooks for IHooks;

    // All pools stored in single mapping
    mapping(PoolId id => Pool.State) internal _pools;

    // Entry point for all state-changing operations
    function unlock(bytes calldata data) external returns (bytes memory) {
        if (Lock.isUnlocked()) AlreadyUnlocked.selector.revertWith();

        Lock.unlock();

        // Call back to user's contract
        bytes memory result = IUnlockCallback(msg.sender).unlockCallback(data);

        // Verify all deltas are settled
        if (NonzeroDeltaCount.read() != 0) CurrencyNotSettled.selector.revertWith();

        Lock.lock();
        return result;
    }
}
```

### PoolKey

Uniquely identifies a pool:

```solidity
struct PoolKey {
    Currency currency0;      // First token (sorted)
    Currency currency1;      // Second token (sorted)
    uint24 fee;              // LP fee in hundredths of bps (max 1,000,000 = 100%)
    int24 tickSpacing;       // Tick spacing for positions
    IHooks hooks;            // Hook contract (address encodes permissions)
}

// PoolId = keccak256(abi.encode(PoolKey))
type PoolId is bytes32;
```

### Flash Accounting

Operations don't transfer tokens immediately. Instead:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        FLASH ACCOUNTING FLOW                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  1. User calls unlock()                                                      │
│     ├─ Lock.unlock() sets transient IS_UNLOCKED = true                      │
│     └─ Calls user's unlockCallback()                                        │
│                                                                              │
│  2. Inside callback, user performs operations:                              │
│     ├─ swap() → updates currency deltas (transient storage)                 │
│     ├─ modifyLiquidity() → updates currency deltas                          │
│     └─ No actual ERC20 transfers yet!                                       │
│                                                                              │
│  3. User settles deltas:                                                     │
│     ├─ If owe tokens: sync(currency) + settle()                             │
│     │   └─ Transfers tokens TO PoolManager                                  │
│     └─ If owed tokens: take(currency, recipient, amount)                    │
│         └─ Transfers tokens FROM PoolManager                                │
│                                                                              │
│  4. Callback returns                                                         │
│     ├─ PoolManager checks NonzeroDeltaCount == 0                            │
│     └─ Lock.lock() resets transient state                                   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Hooks System

Hooks are external contracts that receive callbacks at key lifecycle points:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           HOOK LIFECYCLE                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  INITIALIZE                                                                  │
│  ───────────                                                                │
│  beforeInitialize() ──► Pool.initialize() ──► afterInitialize()            │
│                                                                              │
│  ADD LIQUIDITY                                                              │
│  ─────────────                                                              │
│  beforeAddLiquidity() ──► Pool.modifyLiquidity() ──► afterAddLiquidity()   │
│                                            │                                 │
│                                            └──► Hook can return delta       │
│                                                                              │
│  REMOVE LIQUIDITY                                                           │
│  ────────────────                                                           │
│  beforeRemoveLiquidity() ──► Pool.modifyLiquidity() ──► afterRemove...()   │
│                                               │                              │
│                                               └──► Hook can return delta    │
│                                                                              │
│  SWAP                                                                        │
│  ────                                                                        │
│  beforeSwap() ──► Pool.swap() ──► afterSwap()                               │
│       │                               │                                      │
│       ├──► Can modify swap amount     └──► Can modify unspecified amount    │
│       └──► Can override fee                                                  │
│                                                                              │
│  DONATE                                                                      │
│  ──────                                                                      │
│  beforeDonate() ──► Pool.donate() ──► afterDonate()                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Address-Encoded Permissions

Hook permissions are encoded in the contract address itself:

```solidity
// Permission flags checked via: uint160(hookAddress) & FLAG != 0
uint160 constant BEFORE_INITIALIZE_FLAG = 1 << 13;
uint160 constant AFTER_INITIALIZE_FLAG = 1 << 12;
uint160 constant BEFORE_ADD_LIQUIDITY_FLAG = 1 << 11;
uint160 constant AFTER_ADD_LIQUIDITY_FLAG = 1 << 10;
uint160 constant BEFORE_REMOVE_LIQUIDITY_FLAG = 1 << 9;
uint160 constant AFTER_REMOVE_LIQUIDITY_FLAG = 1 << 8;
uint160 constant BEFORE_SWAP_FLAG = 1 << 7;
uint160 constant AFTER_SWAP_FLAG = 1 << 6;
uint160 constant BEFORE_DONATE_FLAG = 1 << 5;
uint160 constant AFTER_DONATE_FLAG = 1 << 4;
uint160 constant BEFORE_SWAP_RETURNS_DELTA_FLAG = 1 << 3;
uint160 constant AFTER_SWAP_RETURNS_DELTA_FLAG = 1 << 2;
uint160 constant AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG = 1 << 1;
uint160 constant AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG = 1 << 0;
```

Hooks are deployed to specific addresses using CREATE2 mining (HookMiner).

## ERC6909 LP Tokens

V4 replaces NFT positions with ERC6909 multi-token balances:

```solidity
// Each (owner, id) pair has a balance
// id is derived from currency
mapping(address owner => mapping(uint256 id => uint256 balance)) public balanceOf;

// Users can claim their LP tokens
function mint(address to, uint256 id, uint256 amount) external onlyWhenUnlocked {
    _mint(to, id, amount);
}

function burn(address from, uint256 id, uint256 amount) external onlyWhenUnlocked {
    _burn(from, id, amount);
}
```

## Transient Storage (EIP-1153)

V4 uses transient storage for temporary state:

```solidity
// Lock state
library Lock {
    bytes32 constant IS_UNLOCKED_SLOT = 0x...;

    function unlock() internal {
        assembly { tstore(IS_UNLOCKED_SLOT, true) }
    }

    function lock() internal {
        assembly { tstore(IS_UNLOCKED_SLOT, false) }
    }

    function isUnlocked() internal view returns (bool unlocked) {
        assembly { unlocked := tload(IS_UNLOCKED_SLOT) }
    }
}

// Currency deltas per user
library CurrencyDelta {
    function _computeSlot(address target, Currency currency) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(target, currency));
    }

    function getDelta(Currency currency, address target) internal view returns (int256 delta) {
        bytes32 slot = _computeSlot(target, currency);
        assembly { delta := tload(slot) }
    }
}
```

## Key Architectural Decisions

1. **Singleton Pattern**: All pools in one contract reduces deployment costs and enables cross-pool optimizations

2. **Flash Accounting**: Deferring token transfers until callback end reduces transfer count and enables complex multi-pool operations

3. **Address-Encoded Hooks**: Baking permissions into addresses enables O(1) permission checks without storage reads

4. **Transient Storage**: Using tstore/tload for temporary state eliminates storage costs for unlock state

5. **ERC6909**: Multi-token standard is more gas-efficient than NFTs for fungible LP positions

6. **Dynamic Fees**: Hooks can implement custom fee logic, enabling TWAP fees, volume-based fees, etc.

## Reference Files

### v4-core
- `src/PoolManager.sol` - Singleton pool manager
- `src/libraries/Pool.sol` - Pool state machine
- `src/libraries/Hooks.sol` - Hook permission handling
- `src/types/PoolKey.sol` - Pool identification

### v4-periphery
- `src/base/BaseHook.sol` - Hook base contract
- `src/utils/HookMiner.sol` - Address mining utility
