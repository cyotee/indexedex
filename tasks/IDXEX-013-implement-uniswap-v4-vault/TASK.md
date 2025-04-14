# Task IDXEX-013: Implement Uniswap V4 Standard Exchange Vault

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-01-13
**Type:** Implementation
**Dependencies:** None
**Worktree:** `feature/implement-uniswap-v4-vault`
**Origin:** Code review finding from IDXEX-005 (no implementation exists)

---

## Description

Design and implement a concentrated liquidity vault for Uniswap V4 hookless pools.

**SCOPE LIMITATION:** Only support pools where `PoolKey.hooks == address(0)`. Pools with custom hooks introduce reentrancy, fee extraction, and delta manipulation risks that are out of scope.

(Created from code review of IDXEX-005 which found no V4 implementation exists)

## Key V4 Concepts to Address

### 1. PoolManager Singleton Architecture
- V4 uses a single `PoolManager` contract for all pools (vs V3's factory pattern)
- All liquidity operations go through `unlock()` -> callback pattern
- Must implement `IUnlockCallback.unlockCallback(bytes calldata data)`

### 2. ERC-6909 Multi-Token Standard
- V4 uses ERC-6909 for internal balance accounting (not ERC-20)
- Token IDs derived from currency addresses
- Vault must handle both ERC-20 deposits AND ERC-6909 claim tokens
- Withdrawals should return ERC-20 (unwrap from ERC-6909)

### 3. Delta Settlement Pattern
- Operations accumulate deltas during unlock callback
- Must `settle()` negative deltas (tokens owed to pool)
- Must `take()` positive deltas (tokens owed to user)
- Flash accounting: deltas must net to zero before callback returns

### 4. Hookless Pool Restriction
- SCOPE: Only support pools where `PoolKey.hooks == address(0)`
- Must validate and revert if hooks are present
- Pools with hooks introduce reentrancy and fee extraction risks

### 5. Position Management
- Positions identified by: `PoolKey` + `tickLower` + `tickUpper` + `salt`
- Use `IPoolManager.modifyLiquidity()` for add/remove
- Track position via `PoolKey` hash for upgrade stability

## User Stories

### US-IDXEX-013.1: V4 Vault Core Implementation

As a developer, I want to implement Uniswap V4 vault contracts so that users can provide concentrated liquidity to V4 pools.

**Acceptance Criteria:**
- [ ] Vault implements `IUnlockCallback`
- [ ] `unlockCallback()` validates caller is PoolManager
- [ ] Delta settlement is correct (settle/take pattern)
- [ ] Hookless pool enforcement with revert on hooks != address(0)
- [ ] Tests pass
- [ ] Build succeeds

### US-IDXEX-013.2: ERC-6909 Support

As a developer, I want the vault to handle both ERC-20 and ERC-6909 inputs so that users have flexibility in how they deposit.

**Acceptance Criteria:**
- [ ] Correct token-id derivation for ERC-6909
- [ ] Deposits work for both ERC-20 and ERC-6909 inputs
- [ ] Previews work for both input types
- [ ] Withdrawals return ERC-20 as specified

## Files to Create

**Protocol Layer:**
```
contracts/protocols/dexes/uniswap/v4/
├── UniswapV4StandardExchangeCommon.sol
├── UniswapV4StandardExchangeInFacet.sol
├── UniswapV4StandardExchangeOutFacet.sol
├── UniswapV4StandardExchangeRepo.sol
└── UniswapV4_Component_FactoryService.sol
```

**Vault Layer:**
```
contracts/vaults/concentrated/uniswap/v4/
├── UniswapV4ConcentratedVaultDFPkg.sol
├── UniswapV4ConcentratedVaultFacet.sol
├── UniswapV4ConcentratedVaultRepo.sol
├── UniswapV4ConcentratedVaultTarget.sol
└── TestBase_UniswapV4ConcentratedVault.sol
```

**Tests:**
```
test/foundry/spec/protocols/dexes/uniswap/v4/
└── UniswapV4StandardExchange_*.t.sol

test/foundry/fork/ethereum_main/uniswap/v4/
└── UniswapV4Fork_*.t.sol
```

## Key Interfaces

```solidity
// From Uniswap V4
interface IUnlockCallback {
    function unlockCallback(bytes calldata data) external returns (bytes memory);
}

// Vault must validate
struct PoolKey {
    Currency currency0;
    Currency currency1;
    uint24 fee;
    int24 tickSpacing;
    IHooks hooks;  // MUST be address(0) for this vault
}
```

## Invariants to Maintain

| Invariant | Description |
|-----------|-------------|
| Callback Safety | Only PoolManager can call `unlockCallback()` |
| Delta Conservation | All deltas settle to zero before callback returns |
| Hookless Enforcement | Revert if `PoolKey.hooks != address(0)` |
| ERC-6909 Parity | Preview amounts match actual deposit/withdraw amounts |
| Position Stability | Position ID derivation stable across upgrades |

## Dependencies

- Uniswap V4 Core: `v4-core` contracts (PoolManager, types)
- Uniswap V4 Periphery: `v4-periphery` (optional helpers)
- May need new remappings in `foundry.toml` and `remappings.txt`

## Testing Requirements

- Fork tests against Ethereum mainnet (V4 is live)
- Test ERC-20 and ERC-6909 input paths
- Test hook rejection explicitly
- Test delta settlement edge cases

## Completion Criteria

- [ ] All contracts implemented following existing patterns
- [ ] `unlockCallback()` is secure (caller validation, delta settlement)
- [ ] Hookless pool enforcement works
- [ ] ERC-6909 support complete
- [ ] Spec tests pass
- [ ] Fork tests pass on Ethereum mainnet
- [ ] Build succeeds

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
