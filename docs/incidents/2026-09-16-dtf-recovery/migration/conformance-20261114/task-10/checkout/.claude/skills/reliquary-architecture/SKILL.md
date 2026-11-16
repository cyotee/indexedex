---
name: reliquary-architecture
description: This skill should be used when the user asks about "Reliquary", "maturity-based incentives", "Relic NFT", "level", "curve multiplier", "rolling rewarder", or needs to understand how Reliquary's ERC-721 position management and time-weighted reward system works.
license: MIT
---

# Reliquary Architecture

## Conceptual Overview

Reliquary is a maturity-based incentive system for ERC-20 LP tokens. Instead of a simple staking pool, positions earn increasing reward multipliers as they age. Each position is an ERC-721 "Relic" NFT.

**Core idea**: LP tokens deposited into Reliquary earn rewards that grow over time based on a configurable **curve**. The longer you leave a position, the higher your multiplier — creating time-locked incentive alignment.

---

## Core Concepts

### Relics (ERC-721 NFTs)

Every position is an NFT. This allows:
- **Transferability** of positions without withdrawing liquidity
- **Composable** — relics can be traded without affecting the underlying LP position's maturity
- **Split/Merge** — split one relic into two (same maturity), merge two into one

### Maturity & Levels

A position's `entry` timestamp records when it was created. The `level` is derived from `block.timestamp - entry` — so it increases automatically over time.

The **curve** maps level (seconds of age) to a reward multiplier. A simple linear curve: `multiplier = 1e18 + level * slope`.

### Curves (`ICurves`)

`getFunction(uint256 _level) → uint256 multiplier`

| Curve | File | Description |
|-------|------|-------------|
| `LinearCurve` | `curves/LinearCurve.sol` | `slope * level + minMultiplier` — strictly increasing |
| `LinearPlateauCurve` | `curves/LinearPlateauCurve.sol` | Linear until plateau, then flat |
| `PolynomialPlateauCurve` | `curves/PolynomialPlateauCurve.sol` | Polynomial that plateaus at a max multiplier |

**Constraint**: `curve.getFunction(0)` must be > 0. Decreasing curves are not supported (they would break split/shift when combined with `allowPartialWithdrawals=false`).

---

## Pool Structure (`PoolInfo`)

```
PoolInfo {
  string  name
  uint256 accRewardPerShare   // accumulated reward per share (scaled by 1e41)
  uint256 totalLpSupplied     // total effective LP units (amount * multiplier)
  address nftDescriptor       // returns tokenURI for the NFT
  address rewarder             // external rewarder contract (or address(0))
  address poolToken           // ERC-20 token deposited into this pool
  uint40  lastRewardTime
  bool    allowPartialWithdrawals  // if false, split/shift disabled
  uint96  allocPoint          // share of emission pool receives
  ICurves curve
}
```

---

## Access Control

Three roles (keccak256 constants):

| Role | Hash | Who Has It | Functions |
|------|------|------------|-----------|
| `DEFAULT_ADMIN_ROLE` | `0x00` | Deployer | `addPool`, role admin |
| `OPERATOR` | `keccak256("OPERATOR")` | Granted by admin | `modifyPool` |
| `EMISSION_RATE` | `keccak256("EMISSION_RATE")` | Granted by admin | `setEmissionRate` |

**Deployer gets `DEFAULT_ADMIN_ROLE` in constructor.**

---

## Reward Calculation

Constants:
- `ACC_REWARD_PRECISION = 1e41`
- `MAX_SUPPLY_ALLOWED = 100e9 ether`

Per-pool reward per second:
```
rewardPerSecond = emissionRate * pool.allocPoint / totalAllocPoint
```

Position effective balance: `effectiveAmount = position.amount * curve.getFunction(position.level)`

Pending reward:
```
pending = effectiveAmount * accRewardPerShare / ACC_REWARD_PRECISION + rewardCredit - rewardDebt
```

**Important**: Actual payout is `min(pending, rewardToken.balanceOf(Reliquary))` — if the contract is underfunded, users receive less than `pendingReward()` shows.

---

## Harvesting

There is **no separate `harvest()` function**. Harvesting is embedded in `deposit()`, `withdraw()`, and `update()` by passing a non-zero `_harvestTo` address.

```
reliquary.withdraw(amount, relicId, harvestTo);  // withdraw + harvest in one tx
reliquary.update(relicId, harvestTo);            // harvest-only (no deposit/withdraw)
```

---

## Rewarder System

Reliquary supports **external rewarders** via hooks. When a pool has a `rewarder != address(0)`, Reliquary calls hook methods after every state change.

### `IRewarder` Hooks

```
onDeposit(ICurves curve, uint256 relicId, uint256 depositAmount, uint256 oldAmount, uint256 oldLevel, uint256 newLevel)
onWithdraw(ICurves curve, uint256 relicId, uint256 withdrawalAmount, uint256 oldAmount, uint256 oldLevel, uint256 newLevel)
onUpdate(ICurves curve, uint256 relicId, uint256 amount, uint256 oldLevel, uint256 newLevel)
onSplit(ICurves curve, uint256 fromId, uint256 newId, uint256 amount, uint256 fromAmount, uint256 level)
onShift(ICurves curve, uint256 fromId, uint256 toId, uint256 amount, uint256 oldFromAmount, uint256 oldToAmount, uint256 fromLevel, uint256 oldToLevel, uint256 newToLevel)
onMerge(ICurves curve, uint256 fromId, uint256 toId, uint256 fromAmount, uint256 toAmount, uint256 fromLevel, uint256 oldToLevel, uint256 newLevel)
onReward(uint256 relicId, address to)
```

### `RollingRewarder` (child)

Time-based reward distribution. Key features:
- Owner funds the contract with reward tokens via `fund(amount)`
- Tokens distributed linearly over `distributionPeriod` (default: 7 days)
- `rewardPerSecond` scaled by `REWARD_PER_SECOND_PRECISION = 10_000` (allows fractional rates)
- Per-position bookkeeping via `rewardDebt` and `rewardCredit`

Constructor: `constructor(address _rewardToken, address _reliquary, uint8 _poolId)`
- `parent = msg.sender` (the ParentRollingRewarder that deployed it)
- `poolId` is immutable — set at construction

Admin: `fund(amount)`, `updateDistributionPeriod(seconds)` — both `onlyOwner` (owner of parent)

### `ParentRollingRewarder` (manager)

Manages multiple `RollingRewarder` children (one per reward token).

Constructor: `constructor()` (Ownable — owner set to `msg.sender`)

Deploy: `ParentRollingRewarder pr = new ParentRollingRewarder()`
Add child: `pr.createChild(rewardToken)` → deploys a new `RollingRewarder` as a child
Fund child: `child.fund(amount)` — owner must approve child to pull rewardToken

Reliquary integration: When `addPool(rewarder=address(pr))` is called, Reliquary calls `pr.initialize(poolId)`, which stores `reliquary = msg.sender` (the Reliquary address). Only the Reliquary can call the rewarder hooks.

---

## Position Operations

| Operation | Function | Constraints |
|----------|----------|-------------|
| Create + deposit | `createRelicAndDeposit(to, poolId, amount)` | Creates NFT, deposits in one tx |
| Deposit more | `deposit(amount, relicId, harvestTo)` | Must be approved/owner of relic |
| Withdraw | `withdraw(amount, relicId, harvestTo)` | Partial withdrawals allowed if pool allows |
| Harvest only | `update(relicId, harvestTo)` | harvestTo non-zero → pay rewards |
| Split | `split(fromId, amount, to)` | `allowPartialWithdrawals == true`, amount > 0 |
| Shift | `shift(fromId, toId, amount)` | Same pool, partial withdrawals allowed |
| Merge | `merge(fromId, toId)` | Same pool, burns fromId |
| Burn | `burn(relicId)` | `amount == 0 && pending == 0 && rewarder.pendingTokens == 0` |
| Emergency | `emergencyWithdraw(relicId)` | Owner only, no rewards paid, burns NFT |

---

## Bootstrap Requirement

When `addPool` is called, it **automatically creates a 1 wei deposit** into the new pool via `createRelicAndDeposit(_to, newPoolId_, 1)`. This means:
- The caller of `addPool` must hold and approve at least 1 unit of the pool token
- The minted Relic goes to `_to` address

---

## Key Files

```
contracts/protocols/staking/reliquary/v1/
├── Reliquary.sol                              # Core contract
├── interfaces/IReliquary.sol                  # Interface + structs + errors
├── interfaces/ICurves.sol                      # Curve interface (getFunction)
├── interfaces/IRewarder.sol                    # Rewarder hook interface
├── interfaces/IRollingRewarder.sol             # RollingRewarder interface
├── interfaces/IParentRollingRewarder.sol        # ParentRollingRewarder interface
├── curves/
│   ├── LinearCurve.sol
│   ├── LinearPlateauCurve.sol
│   └── PolynomialPlateauCurve.sol
├── rewarders/
│   ├── RollingRewarder.sol
│   └── ParentRollingRewarder.sol
├── helpers/
│   ├── DepositHelperERC4626.sol               # ERC4626 vault helper
│   ├── DepositHelperReaperVault.sol           # Reaper-style vault helper
│   └── DepositHelperReaperBPT.sol             # BPT zap helper
└── services/
    └── ReliquaryService.sol                   # Internal reward math library
```

---

## See Also

- `skill:reliquary-deployment` — practical deployment and usage guide
- `contracts/protocols/staking/reliquary/v1/test/bases/TestBase_Reliquary.sol` — test deployment pattern
