Ask: Act as the independent Kimi council author for the WeirVaults source-import PRD - wanted: a complete source-grounded PRD contribution. For you: The complete contribution follows. It is based on the full brief, manifest, three domain sources, and four frozen inherited OpenZeppelin implementations; no files were written and no builds or tests were run. Now: no task remains. Next: no task remains.

# Kimi Independent Contribution: WeirVaults Source-Import PRD

## 1. Status and Evidence

This is an independent PRD authoring contribution. It does not authorize implementation.

### Evidence read completely

- `brief.md`
- `source-snapshot/manifest.json`, including all 1,825 lines, the ABI, compiler settings, metadata identifiers, and all 39 file records.
- `source-snapshot/sources/src/WeirVaults.sol.txt`, 427 lines.
- `source-snapshot/sources/src/base/WeirBase.sol.txt`, 88 lines.
- `source-snapshot/sources/src/libraries/LiquidityAmounts.sol.txt`, 68 lines.
- Frozen inherited executable implementations:
  - `Ownable2Step.sol.txt`
  - `Ownable.sol.txt`
  - `Pausable.sol.txt`
  - `ReentrancyGuard.sol.txt`

No peer originals or feedback were read. No repository dependency-compatibility claim is made because the candidate IndexedEx dependency implementations were not compared in this pass. No builds, tests, bytecode reproduction, live transactions, upstream Git history, upstream tests, or audit evidence were supplied or executed.

### Source abbreviations

- **W**: `source-snapshot/sources/src/WeirVaults.sol.txt`
- **B**: `source-snapshot/sources/src/base/WeirBase.sol.txt`
- **L**: `source-snapshot/sources/src/libraries/LiquidityAmounts.sol.txt`
- **M**: `source-snapshot/manifest.json`
- **O2**: frozen `access/Ownable2Step.sol.txt`
- **OO**: frozen `access/Ownable.sol.txt`
- **OP**: frozen `utils/Pausable.sol.txt`
- **OR**: frozen `utils/ReentrancyGuard.sol.txt`

### Requirement classes

- **F — Fidelity:** mandatory preservation of the frozen baseline, including awkward observable behavior.
- **L — Limitation:** mandatory documentation and, where feasible, executable characterization; not permission to repair.
- **X — Excluded improvement:** separately desirable work that is outside this import.

---

## 2. Objective and Scope

Import the three frozen Weir domain sources into:

- `contracts/protocols/strategy/weir/WeirVaults.sol`
- `contracts/protocols/strategy/weir/base/WeirBase.sol`
- `contracts/protocols/strategy/weir/libraries/LiquidityAmounts.sol`

The result must be a faithful standalone baseline using the actual Uniswap V4 PoolManager, with production-first tests that prove source-level behavior and explicitly characterize source limitations.

The import must not add an ERC20/ERC4626 wrapper, Rate Provider, Diamond or Standard Exchange integration, registry integration, proxy, fee removal, dead-share removal, hook-only unlocked path, strict single-token exit guarantee, new simulator, optimization, or economic repair.

---

## 3. Normative Requirements

### WV-001 — Frozen provenance and integrity (F)

The implementation record MUST identify chain `4663`, address `0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110`, the Sourcify creation/runtime `match`, retrieval time, and these SHA-256 pins:

- W: `23de61301729d2950ba110e15cdce5e383fc4e5aacb0b906ee845390bd0e0180`
- B: `f14c1ef0fe9913f0d99e872f108ab3d7b84f44050d449d2b72049ad20a08b498`
- L: `f482702fecb1b6dc5c82b9ad918a4f991ce5b8c4d0c1144b448c25fbaad3093d`

The release notes MUST state that content-addressed verified source is the pin, not a verified upstream Git revision, audit, test suite, independent bytecode reproduction, or transaction-parity result.

**Source:** M `sourceUrl`, `match`, `creationMatch`, `runtimeMatch`, `files`.

### WV-002 — Faithful source import (F)

The three domain files MUST preserve their executable statements, declaration order, types, constants, license headers, compiler pragmas, comments that document limitations, and external behavior.

Byte-for-byte copies are preferred. If import-path-only edits are necessary to use existing canonical dependencies, the release evidence MUST contain a mechanical diff proving that no executable statement, type, visibility, mutability, event, error, or arithmetic expression changed. No behavioral “cleanup” is permitted.

No second production copy of Weir or private OpenZeppelin/V4 dependency tree is permitted.

**Source:** W 1-427; B 1-88; L 1-68.

### WV-003 — IndexedEx compilation versus upstream reproduction (F/L)

The normal import MUST compile under current IndexedEx defaults: solc `0.8.35`, optimizer runs `1`, `via_ir=false`, without adding a profile or enabling viaIR.

The PRD MUST NOT require deployed-bytecode equality under those settings. Any optional upstream reproduction is separate evidence using solc `0.8.26+commit.8a97fa7a`, optimizer `800`, Cancun, `viaIR=true`, and `metadata.bytecodeHash=none`.

Source/ABI/arithmetic fidelity and upstream compiler reproducibility MUST be reported separately.

**Source:** M `metadata.compiler`, `metadata.settings`.

### WV-004 — Dependency compatibility gate (F)

Existing canonical OpenZeppelin and V4 dependencies SHOULD be reused only after comparing the actual candidate sources against the frozen versions for:

- ABI and custom-error compatibility.
- Type widths and tuple layouts.
- Storage and inheritance behavior where relevant.
- Arithmetic, rounding, casts, overflow, and revert behavior.
- PoolManager unlock, delta, settlement, position-key, and hook semantics.

A same-named `LiquidityAmounts`, `StateLibrary`, `Position`, or OpenZeppelin file is not sufficient evidence. A substitution that changes behavior is a deviation requiring a separate explicit decision. No new submodule, private clone, or global alias/config rewrite is authorized.

**Source:** W 3-17, 29-36, 221-235, 238-404; B 3-8, 14-88; L 3-68; M `metadata.sources`.

### WV-005 — License and notice preservation (F/L)

All SPDX headers and notices MUST remain intact. Release documentation MUST include the complete per-file license map from M, comprising:

- 37 MIT files, including W and B.
- `src/libraries/LiquidityAmounts.sol`: GPL-2.0-or-later.
- `lib/v4-core/src/libraries/Position.sol`: BUSL-1.1.

No blanket MIT label, license scrubbing, clean-room claim, automatic legal clearance, or relicensing is permitted. Dependency and license disposition MUST be recorded before an eventual copied-source release.

**Source:** W 1; B 1; L 1; M `metadata.sources.*.license`, `files`.

### WV-006 — Complete ABI preservation (F)

The imported contract MUST expose exactly the frozen constructor, payable receive, 27 public/external functions, struct tuple layouts, events, errors, and mutability enumerated in Section 4.

No ERC20 share methods, approvals, allowances, ERC4626 methods, registry methods, preview-deposit method, zap-specific preview, or additional admin surface may be added.

**Source:** M `metadata.output.abi`; W 29-227, 408-427; B 18-40; O2 28-67; OO 26-100; OP 23-119.

### WV-007 — State, constants, structs, events, and errors (F)

The implementation MUST preserve:

- `BPS = 10_000` internally.
- `MAX_PERF_FEE_BPS = 1_000`.
- `MIN_SHARES = 1_000`.
- Initial `perfFeeBps = 500`.
- Per-PoolId vaults and per-user shares.
- Append-only `allVaults`.
- Exact struct field order and `Action` enum values `DEPOSIT=0`, `WITHDRAW=1`, `COMPOUND=2`.
- Exact event and error signatures, including inherited errors and `SafeERC20FailedOperation(address)` surfacing through token operations.

**Source:** W 32-99; M ABI.

### WV-008 — Vault creation and registry lifecycle (F)

`createVault` MUST remain callable by anyone, including while paused. It MUST:

- Derive the PoolId from the complete PoolKey.
- Revert `VaultExists` on a duplicate.
- Revert `PoolNotInitialized` when slot0 sqrt price is zero.
- Use `TickMath.minUsableTick` and `maxUsableTick` for the pool’s tick spacing.
- Store one vault per PoolId, append the ID once, and emit `VaultCreated`.

A deposit into a nonexistent but initialized pool MUST attempt creation inline; any later deposit failure MUST roll back that creation.

**Source:** W 145-156, 159-183.

### WV-009 — Deposit funding, payer, recipient, and native value (F)

Deposit MUST preserve modifier order and behavior: `whenNotPaused`, `nonReentrant`, then deadline validation.

It MUST reject a zero recipient, check native value against all native legs, pull ERC20 funds from `msg.sender`, issue shares to `p.recipient`, and refund unused currency to `msg.sender`, not the recipient. `Deposited.user` is the recipient.

`msg.value` MUST equal the sum of native `amount0` and `amount1` exactly. Excess native value and underpayment both revert `BadNativeAmount`. Native currency remains unwrapped.

**Source:** W 159-183; B 30-33, 40-54, 79-88.

### WV-010 — Deposit compounding, zap, cushion, and issuance (F)

Every successful manager-backed deposit MUST compound before calculating and adding new liquidity.

The implementation MUST preserve:

- Optional same-pool exact-input balancing swap.
- Two-unit-per-currency liquidity cushion: amounts `0`, `1`, or `2` contribute zero; larger amounts contribute `amount - 2`.
- First-deposit requirement `liquidity > 1_000`.
- First-deposit shares `liquidity - 1_000`, with 1,000 unassigned shares retained in `totalShares`.
- Later issuance `floor(newLiquidity * totalShares / existingLiquidity)`.
- `ZeroShares` for internal zero or too-small genesis liquidity.
- Outer `Slippage` when returned shares are below `minShares`.
- `used0` and `used1` derived from negative signed manager deltas, followed by refunds of `amount - used`.

The genesis shares are not an ERC20 balance and are not assigned to a dead address.

**Source:** W 221-275, 365-404.

### WV-011 — Withdrawal and share burning (F)

Withdrawal MUST remain available while paused and MUST preserve:

- Deadline and reentrancy guards.
- `BadZap` for `zapTo > 2`.
- Zero-recipient, unknown-vault, zero-share, and insufficient-share behavior.
- Compounding before pro-rata withdrawal.
- Liquidity and idle amounts calculated with floor division.
- Share deduction before manager unlock, with full rollback on any failure.
- Salt-zero position reduction only when calculated liquidity is nonzero.
- Idle payment into the manager before optional zap.
- Final `min0`/`min1` checks and `Withdrawn` event.

The share owner is `msg.sender`; token recipient is `p.recipient`.

**Source:** W 186-203, 221-235, 278-316.

### WV-012 — Withdraw zap and partial-fill behavior (F/L)

`zapTo` MUST remain:

- `0`: no withdraw zap; both currencies may be returned.
- `1`: swap positive currency1 proceeds toward currency0.
- `2`: swap positive currency0 proceeds toward currency1.

The swap uses exact input and extreme price limits. There is no guarantee of complete input consumption or exactly one nonzero output. Partial fills, hook effects, rounding, and residual currency MUST be characterized rather than repaired. Slippage protection is only the final `min0`/`min1` check.

**Source:** W 61-70, 278-316, 391-404.

### WV-013 — Compound, fees, idle balances, and timestamps (F)

`compound` MUST remain permissionless and nonReentrant. Every compound callback MUST set `lastCompound = uint64(block.timestamp)` before the zero-liquidity early return.

For nonzero vault liquidity, the implementation MUST preserve:

- Zero-liquidity-delta fee harvest at the full-range, salt-zero position.
- Positive fee deltas converted through `uint128`.
- Per-currency treasury cut `floor(fee * perfFeeBps / 10_000)`.
- Reinvestment of post-fee amounts plus idle balances using the two-unit cushion.
- Signed net-delta settlement.
- Idle updates from signed deltas.
- `Compounded` only when gross `f0` or `f1` is nonzero, even if idle-only liquidity was added.

No fee is separately charged on deposit or withdrawal; pending harvest fees are subject to the performance cut because those operations compound first.

**Source:** W 206-210, 221-235, 319-362.

### WV-014 — View and preview limits (F/L)

`previewRedeem` MUST remain a limited quote based on current recorded vault liquidity, current slot0 price, recorded idle balances, and floor-divided pro-rata amounts.

It MUST NOT be described as including pending fees or simulating:

- The mandatory pre-withdraw compound.
- Treasury fee cuts.
- Manager modify-liquidity rounding.
- A withdraw zap or hook behavior.
- Price movement or slippage.
- Actual recipient proceeds.

Unknown vaults and zero total shares return `(0,0)`. The function does not validate `shares <= totalShares` or a user’s balance. There is no deposit, zap, or maintenance preview with execution parity.

`pendingFees` returns gross pending fees before performance fee, excludes idle, and returns `(0,0)` when recorded vault liquidity is zero.

**Source:** W 108-140, 278-362.

### WV-015 — Per-pool transferable non-ERC20 shares (F/L)

`transferShares` MUST preserve direct per-PoolId balance transfers without allowances or ERC20 events. It MUST leave `totalShares` unchanged, reject zero recipients, use checked subtraction, and emit `SharesTransferred`.

Shares for different pools MUST remain independent even when pools share currencies. Zero-share transfers, including for unknown IDs, are not explicitly rejected. Pausing does not block transfers.

**Source:** W 78-88, 212-217.

### WV-016 — Ownership, pause, and reentrancy inheritance (F)

The import MUST preserve OpenZeppelin behavior:

- Nonzero initial owner and `OwnershipTransferred` on construction.
- Two-step ownership transfer, pending-owner replacement, zero-address cancellation, and pending-owner clearing on acceptance or renunciation.
- `OwnableUnauthorizedAccount(account)` and `OwnableInvalidOwner(address)`.
- Owner-only treasury, fee, pause, and unpause functions.
- Initially unpaused state; repeated pause/unpause errors and pause events.
- Only deposit has `whenNotPaused`.
- One shared nonReentrant guard for deposit, withdraw, and compound.
- `createVault`, `transferShares`, ownership/admin functions, views, receive, and the callback are not protected by `nonReentrant`.

No unguarded function may be described as guarded.

**Source:** W 29, 159-210, 408-427; O2 33-67; OO 38-100; OP 43-119; OR 47-87.

### WV-017 — Callback and settlement provenance (F)

`unlockCallback` MUST accept calls only from the immutable PoolManager and decode the exact `(Action, PoolId, bytes)` envelope. Direct non-manager calls revert `NotPoolManager`.

Every manager operation MUST use the real unlock/settle/take/sync flow. ERC20 payment uses `sync`, token transfer, then `settle`; native payment uses payable `settle`. Positive net deltas are taken to the designated recipient and negative deltas are paid.

Ordinary nested `PoolManager.unlock` attempts MUST retain the real manager’s already-unlocked failure behavior.

**Source:** B 18-37, 56-77; W 221-235.

### WV-018 — Arithmetic and cast fidelity (F/L)

The custom `LiquidityAmounts` implementation MUST retain its exact FullMath formulas, input ordering, range branches, floor rounding, and `"liquidity overflow"` revert string.

The PRD MUST require characterization of:

- Pro-rata `uint256`-to-`uint128` casts.
- Positive fee `int256`-to-`uint128` casts.
- `uint64(block.timestamp)`.
- Signed delta negation and integer conversions.
- Exact-input `uint256`-to-`int256` conversion.
- Division rounding for shares, idle, and fees.
- Tiny deposits and withdrawals that produce zero liquidity or zero output.

No replacement library may be assumed equivalent by name.

**Source:** L 11-68; W 117-140, 238-275, 278-362, 365-404.

### WV-019 — Production-first hermetic test policy (F)

Tests MUST deploy the actual imported WeirVaults and a real V4 PoolManager. They MUST NOT mock or replace the SUT, etch it, subclass it to replace behavior, inject its storage, or fabricate manager deltas.

A reusable `TestBase_WeirVaults` MAY extend `CraneTest` if existing fixtures add unrelated product wiring. Test infrastructure MUST live with the protocol and specifications under `test/foundry/spec/protocols/strategy/weir/`.

Assertions MUST include exact balances, per-pool ledgers, real position state, events, revert data, callback provenance, manager currency-delta closure, and complete rollback. Expected arithmetic MUST come from independent calculations or precomputed integers, not from calling the SUT or its helper to generate its own expected result.

### WV-020 — Deterministic fuzz and invariant campaigns (F)

The suite MUST include reproducible, bounded campaigns across multiple users and at least two pools, including a shared-currency pair and native/ERC20 coverage where supported by the real manager.

Handlers MUST cover creation, paired and single-sided deposits, zap/no-zap, all withdraw choices, explicit and implicit compounds, real fee accrual through swaps, transfers, pause/unpause, owner changes, fee/treasury changes, deadlines, and bounded tiny amounts.

Seeds, runs, depth, manager/pool fixtures, and failure classifications MUST be recorded. Reverting operations MUST either be intentionally classified with exact rollback assertions or bounded away; they MUST NOT be silently discarded to manufacture a pass.

### WV-021 — Fork parity and release evidence (F/L)

Hermetic CI MUST NOT require RPC or secrets. Any deployed-reference comparison MUST be local-only under `test/foundry/fork/`, using `FOUNDRY_PROFILE=fork`, a pinned chain/block/state, explicit provenance, matching inputs, and equivalent starting position, inventory, fees, and roles.

Unavailable RPC or state MUST be reported as missing evidence, never replaced with a fabricated result. Release evidence MUST include source diffs, ABI comparison, dependency decisions, license map, default-profile build/test output, deterministic campaign parameters, and documented limitations.

---

## 4. Complete External and Inherited Surface

The ABI comparison MUST cover every row below.

| Surface | Mutability | Required behavior and locator |
|---|---|---|
| `constructor(IPoolManager,address,address)` | nonpayable | Sets immutable manager, nonzero treasury and owner; initial fee 500. No explicit zero-manager check. W 101-105; B 18, 35-37; OO 38-45 |
| `receive()` | payable | Accepts native currency without wrapping or event. B 40 |
| `MAX_PERF_FEE_BPS()` | view | Returns `1_000`. W 35 |
| `MIN_SHARES()` | view | Returns `1_000`. W 36 |
| `poolManager()` | view | Returns immutable manager. B 18 |
| `treasury()` | view | Returns current treasury. W 78 |
| `perfFeeBps()` | view | Returns current fee, initially 500. W 79 |
| `owner()` | view | Current owner. OO 56-58 |
| `pendingOwner()` | view | Current pending owner. O2 33-35 |
| `paused()` | view | Current pause flag. OP 74-76 |
| `sharesOf(PoolId,address)` | view | Per-pool, per-user shares. W 81 |
| `allVaults(uint256)` | view | Array getter; out-of-range access retains Solidity panic behavior. W 82 |
| `vaultCount()` | view | Number of created pool IDs. W 112-114 |
| `vault(PoolId)` | view | Returns complete Vault tuple; unknown IDs return zero values. W 108-110 |
| `pendingFees(PoolId)` | view | Gross pending position fees before performance fee. W 130-140 |
| `previewRedeem(PoolId,uint256)` | view | Limited current-state, pre-pending-fee quote. W 117-127 |
| `createVault(PoolKey)` | nonpayable | Permissionless initialized-pool registration. W 145-156 |
| `deposit(DepositParams)` | payable | Pause/deadline/reentrancy-guarded funding and issuance. W 159-183 |
| `withdraw(WithdrawParams)` | nonpayable | Share burning, compound, liquidity removal, optional zap. W 186-203 |
| `compound(PoolKey,bytes)` | nonpayable | Permissionless fee/idle compounding. W 206-210 |
| `transferShares(PoolId,address,uint256)` | nonpayable | Direct non-ERC20 balance transfer. W 212-217 |
| `unlockCallback(bytes)` | nonpayable | PoolManager-only action dispatcher. B 25-29; W 221-235 |
| `setTreasury(address)` | nonpayable | Owner-only, nonzero, emits `TreasurySet`. W 408-412 |
| `setPerfFee(uint16)` | nonpayable | Owner-only, maximum 1,000, emits `PerfFeeSet`. W 414-418 |
| `pause()` | nonpayable | Owner-only; affects deposit only. W 420-422; OP 103-110 |
| `unpause()` | nonpayable | Owner-only; requires paused state. W 424-427; OP 115-119 |
| `transferOwnership(address)` | nonpayable | Owner-only two-step start or zero-address cancellation. O2 43-46 |
| `acceptOwnership()` | nonpayable | Pending owner accepts and clears pending state. O2 52-67 |
| `renounceOwnership()` | nonpayable | Owner becomes zero and pending owner is cleared. OO 76-79; O2 52-55 |

### Required tuple and enum layouts

| Type | Ordered fields |
|---|---|
| `Vault` | `PoolKey key`; `int24 tickLower`; `int24 tickUpper`; `uint128 liquidity`; `uint256 totalShares`; `uint256 idle0`; `uint256 idle1`; `uint64 lastCompound`; `bool exists` |
| `DepositParams` | `PoolKey key`; `uint256 amount0`; `uint256 amount1`; `bool zap`; `uint256 minShares`; `address recipient`; `uint256 deadline`; `bytes hookData` |
| `WithdrawParams` | `PoolKey key`; `uint256 shares`; `uint8 zapTo`; `uint256 min0`; `uint256 min1`; `address recipient`; `uint256 deadline`; `bytes hookData` |
| `PoolKey` | `Currency currency0`; `Currency currency1`; `uint24 fee`; `int24 tickSpacing`; `IHooks hooks` |
| `Action` | `DEPOSIT=0`; `WITHDRAW=1`; `COMPOUND=2` |

**Source:** W 38-76; M ABI.

### Required custom events

- `VaultCreated(PoolId indexed, PoolKey)`
- `Deposited(PoolId indexed, address indexed user, uint256 shares, uint256 used0, uint256 used1)`
- `Withdrawn(PoolId indexed, address indexed user, uint256 shares, uint256 out0, uint256 out1)`
- `Compounded(PoolId indexed, uint256 fees0, uint256 fees1, uint128 liquidityAdded)`
- `SharesTransferred(PoolId indexed, address indexed from, address indexed to, uint256 shares)`
- `TreasurySet(address)`
- `PerfFeeSet(uint16)`
- `OwnershipTransferStarted(address indexed,address indexed)`
- `OwnershipTransferred(address indexed,address indexed)`
- `Paused(address)`
- `Unpaused(address)`

### Required errors

- Weir: `NoVault`, `VaultExists`, `PoolNotInitialized`, `Slippage`, `ZeroShares`, `ZeroAddress`, `FeeTooHigh`, `BadZap`.
- WeirBase: `NotPoolManager`, `Expired`, `BadNativeAmount`, `NativeTransferFailed`.
- Inherited: `OwnableInvalidOwner(address)`, `OwnableUnauthorizedAccount(address)`, `EnforcedPause`, `ExpectedPause`, `ReentrancyGuardReentrantCall`.
- Token plumbing: `SafeERC20FailedOperation(address)`.
- Arithmetic/library failures must retain the applicable Solidity panic or `"liquidity overflow"` string.

---

## 5. Acceptance and Test Matrix

All state-changing failure rows MUST assert complete rollback: token/native balances, allowances, shares, vault fields, registry entries, manager deltas, real position liquidity, treasury balances, pending ownership, and emitted events as applicable.

### ABI, construction, and lifecycle

| ID | Preconditions and action | Exact expected result |
|---|---|---|
| AC-WV-001 | Compare imported sources with frozen pins. | Hashes match exact copies, or the only diff is the approved import-path mechanical diff; SPDX and executable lines are unchanged. |
| AC-WV-002 | Build and inspect ABI under default IndexedEx settings. | Build succeeds without viaIR; ABI exactly matches M, including 27 functions, constructor, payable receive, tuples, events, errors, and mutability. |
| AC-WV-003 | Deploy with valid manager, treasury, and owner. | Manager/treasury/owner are exact; fee is 500; constants are 1,000 and 1,000; paused is false; pending owner and vault count are zero; `OwnershipTransferred(0,owner)` is emitted. |
| AC-WV-004 | Deploy separately with zero treasury and zero owner. | Zero treasury reverts `ZeroAddress`; zero owner reverts `OwnableInvalidOwner(0)`. |
| AC-WV-005 | Deploy with zero manager and otherwise valid arguments. | Construction succeeds because no zero-manager check exists; record this limitation without adding a check. |
| AC-WV-006 | Create a vault for an uninitialized pool. | `PoolNotInitialized`; no registry entry, state, or event. |
| AC-WV-007 | Any nonowner creates an initialized pool vault while paused. | Correct PoolId; usable full-range ticks; exists true; count increments once; exact `VaultCreated`; other vault fields zero. |
| AC-WV-008 | Create the same PoolId twice. | Second call reverts `VaultExists`; count, key, ticks, and event stream unchanged. |
| AC-WV-009 | Query unknown IDs and out-of-range `allVaults`. | `vault` returns a zero tuple; `pendingFees` and `previewRedeem` return zeros; shares are zero; out-of-range array access reverts `Panic(0x32)`. |
| AC-WV-010 | Deposit into a nonexistent initialized pool, then repeat with a forced later failure. | Success emits `VaultCreated` before `Deposited`; failure rolls back the inline creation and leaves count zero. |

### Deposit and native funding

| ID | Preconditions and action | Exact expected result |
|---|---|---|
| AC-WV-011 | Deposit with zero recipient. | `ZeroAddress`; no creation, transfer, unlock, or shares. |
| AC-WV-012 | Deposit while paused; separately use expired and equal-to-current deadlines. | Paused call reverts `EnforcedPause`; `block.timestamp > deadline` reverts `Expired`; equality proceeds subject to other checks. |
| AC-WV-013 | Native deposit with exact, insufficient, and excess `msg.value`. | Only exact sum of native legs proceeds; both mismatches revert `BadNativeAmount` with no funds or state changes. |
| AC-WV-014 | ERC20-only deposit with nonzero `msg.value`. | `BadNativeAmount`; no allowance consumption or vault changes. |
| AC-WV-015 | Payer and recipient differ; include unused refund in both currencies. | Payer funds all pulled amounts and receives every refund; recipient receives shares only; payer share balance is unchanged; event user is recipient. |
| AC-WV-016 | First non-zap deposit with independently calculated `L > 1_000`. | Uses cushioned amounts; minted shares are exactly `L-1_000`; totalShares and vault liquidity become `L`; recipient has `L-1_000`; 1,000 shares remain unassigned. Assert precomputed integer fixture values. |
| AC-WV-017 | First deposits producing `L=1_000` and, where fixture construction permits, `L=1_001`. | `1_000` reverts `ZeroShares`; `1_001` mints exactly one share and retains 1,000 unassigned shares. |
| AC-WV-018 | Second deposit after known compound state. | Shares equal `floor(newL * totalSharesBefore / liquidityBefore)` using post-compound, pre-deposit values; exact new liquidity, totalShares, event, used amounts, and refunds match independent integers. |
| AC-WV-019 | Deposit whose nonzero returned shares are below `minShares`. | `Slippage`; complete rollback including pulled funds, swaps, fees, treasury cut, inline creation, and manager deltas. |
| AC-WV-020 | Exercise amounts around the cushion: 0, 1, 2, 3 and larger fixed values. | Liquidity helper receives 0 for 0/1/2 and `amount-2` otherwise; exact issuance/refunds demonstrate the withheld units. |
| AC-WV-021 | Paired deposit with `zap=false`. | No balancing swap occurs; liquidity is determined by the limiting cushioned side; unused side is refunded exactly. |
| AC-WV-022 | Single-sided deposits in each direction with `zap=true`. | Swap direction and exact input match the source heuristic; output, cushioned liquidity, shares, signed settlement, used amounts, and refund equal independently calculated values. |
| AC-WV-023 | Force a price-limited or hook-affected partial zap. | No full-consumption assumption: actual deltas and leftovers are asserted; success occurs if final checks pass, otherwise exact revert and rollback. |
| AC-WV-024 | Add native/ERC20 donations before deposits. | Donations do not directly increase shares, totalShares, liquidity, or idle; subsequent actual use or non-use is accounted exactly without treating donations as user principal. |
| AC-WV-025 | Use hostile fee-on-transfer or rebasing peripheral tokens. | Record actual source/manager behavior and exact failure or accounting outcome; no support claim and no expectation of a repair. |

### Withdrawal and shares

| ID | Preconditions and action | Exact expected result |
|---|---|---|
| AC-WV-026 | Exercise invalid zap, zero recipient, unknown vault, zero shares, and insufficient shares separately. | Respectively `BadZap`, `ZeroAddress`, `NoVault`, `ZeroShares`, and checked-subtraction `Panic(0x11)`; all state unchanged. |
| AC-WV-027 | Withdraw both tokens after pending fees accrue. | Compound occurs first; then `L=floor(liquidity*shares/totalShares)` and idle shares use floor division; exact position reduction, outputs, fee cut, remaining idle, totalShares, and `Withdrawn`. |
| AC-WV-028 | Share owner and token recipient differ. | Owner’s shares decrease; recipient receives all final proceeds; event user is owner. |
| AC-WV-029 | Withdraw with `zapTo=1` and `zapTo=2`. | Correct source currency is swapped in the correct direction using exact positive input; final outputs and residuals equal actual manager deltas; no strict zero-opposite-output assertion. |
| AC-WV-030 | Set `min0` or `min1` one unit above actual output. | `Slippage`; burned shares, fees, treasury transfers, idle updates, position changes, and swaps all roll back. |
| AC-WV-031 | Withdraw while paused. | Succeeds exactly as unpaused, subject to normal checks. |
| AC-WV-032 | Withdraw a tiny share amount producing zero liquidity and zero idle. | No modify-liquidity call is required for zero `L`; shares burn and `Withdrawn(…,0,0)` occur when minimums are zero. |
| AC-WV-033 | Withdraw every user-held share after genesis. | User share sum becomes zero; totalShares remains 1,000; remaining real position liquidity belongs to the unassigned genesis shares and cannot be withdrawn through a user balance. |
| AC-WV-034 | Transfer shares normally, to self, with zero amount, to zero address, and above balance. | Normal/self/zero behavior matches checked ledger arithmetic and exact event; zero recipient gives `ZeroAddress`; excess gives `Panic(0x11)`; totalShares never changes. |
| AC-WV-035 | Zero-share transfer for an unknown PoolId and ordinary transfers while paused. | Both are accepted by source logic; exact event is emitted and no vault is created. |

### Compound, fees, and previews

| ID | Preconditions and action | Exact expected result |
|---|---|---|
| AC-WV-036 | Call compound for unknown vault and for an existing zero-liquidity vault. | Unknown gives `NoVault`; zero-liquidity vault updates `lastCompound` to the current `uint64` timestamp and returns without harvest or `Compounded`. |
| AC-WV-037 | Accrue known fees and compound at default 500 bps. | Treasury receives `floor(f*500/10_000)` per currency; post-cut fees plus prior idle are reinvested with cushion; event contains gross fees and exact added liquidity. |
| AC-WV-038 | Use fee amounts 19 and 20 at 500 bps, then 9 and 10 at 1,000 bps. | Cuts are respectively 0, 1, 0, and 1, proving per-currency floor behavior at zero/nonzero boundaries. |
| AC-WV-039 | Compound with idle balances but no newly accrued fees. | Eligible idle is reinvested; `lastCompound` and liquidity update; no `Compounded` event because both gross fees are zero. |
| AC-WV-040 | Deposit and withdraw with pending fees. | `Compounded`, when gross fees exist, precedes the corresponding user event; issuance/burn calculations use post-compound liquidity and idle state. |
| AC-WV-041 | Owner sets fee 0, 1,000, and 1,001; nonowner and zero-treasury cases are included. | 0 and 1,000 succeed with `PerfFeeSet`; 1,001 gives `FeeTooHigh`; nonowner admin calls give `OwnableUnauthorizedAccount(caller)`; zero treasury gives `ZeroAddress`. |
| AC-WV-042 | Change treasury/fee after fees accrue but before compound. | Next compound uses the new treasury and fee; previous checkpoints do not preserve the old settings. |
| AC-WV-043 | Compare `pendingFees` immediately before compound. | View returns gross fees before performance cut and excludes idle; compound treasury cut and event reconcile exactly to that view subject to unchanged state. |
| AC-WV-044 | Preview fixed shares at a fixed slot0 and known liquidity/idle. | Outputs equal independent current-position math plus floor-divided idle; zero shares returns zero; unknown vault returns zero. |
| AC-WV-045 | Accrue pending fees without changing recorded liquidity, then preview and withdraw. | Preview excludes pending fees; actual withdrawal compounds first and therefore need not equal preview. The test must not assert preview/withdraw parity. |
| AC-WV-046 | Preview after price movement and with `shares > totalShares` within cast-safe bounds. | Price-dependent amounts follow current slot0; excess-share input is not explicitly rejected and returns the formulaic quote, not a valid redemption promise. |

### Multi-pool, callback, reentrancy, and math

| ID | Preconditions and action | Exact expected result |
|---|---|---|
| AC-WV-047 | Create at least two pools sharing one currency; operate both. | IDs and `allVaults` order are exact; shares, idle, fees, liquidity, and events remain pool-scoped; shared token balances reconcile globally. |
| AC-WV-048 | Inspect real manager positions after operations in each pool. | Position owner is WeirVaults, ticks are the stored usable full-range ticks, salt is `bytes32(0)`, and manager liquidity equals recorded vault liquidity after each successful operation. |
| AC-WV-049 | Call `unlockCallback` directly from a non-manager. | `NotPoolManager`; no vault, token, or manager changes. |
| AC-WV-050 | Attempt nested manager unlock from a real hook/callback path. | The ordinary real-manager already-unlocked failure is preserved and externally observed revert data is recorded; no special already-unlocked Weir path appears. |
| AC-WV-051 | Reenter deposit, withdraw, and compound through hostile hooks/receivers. | Guarded reentry produces `ReentrancyGuardReentrantCall` or the real manager’s exact propagated equivalent; outer operation rolls back completely. |
| AC-WV-052 | Attempt reentry into `transferShares` and `createVault`. | Tests record actual unguarded behavior rather than expecting `ReentrancyGuardReentrantCall`; any resulting ledger changes must reconcile exactly. |
| AC-WV-053 | Force a rejecting native refund receiver and send native directly to `receive()`. | Refund failure produces `NativeTransferFailed` with full rollback; plain native receive succeeds and increases contract balance without shares or events. |
| AC-WV-054 | Unit-test `LiquidityAmounts` below, at, inside, and above range boundaries with reversed sqrt inputs and overflow inputs. | Exact independent FullMath results and floor rounding; reversed bounds normalize identically; excessive liquidity reverts with `"liquidity overflow"`. |
| AC-WV-055 | Exercise signed-delta, tiny-value, and narrowing-cast boundaries feasible with the real manager; use a separate arithmetic harness only for library-level boundaries. | Exact signed pay/take behavior and applicable panic/revert data; no mocked manager deltas or injected SUT state. |
| AC-WV-056 | Run deterministic multi-user/multi-pool fuzz and invariant campaigns, then optional pinned fork parity. | Every successful step reconciles independent balances/ledgers/positions; every classified failure rolls back; seeds and evidence are reported; unavailable fork state is documented rather than simulated. |

---

## 6. Deterministic Invariants and Handler Rules

The campaign MUST track ghost state independently per PoolId and user.

### Required invariants after successful operations

1. `allVaults` contains no duplicate PoolId, and every listed ID has `exists=true`.
2. For every initialized vault with shares,  
   `totalShares = 1_000 + sum(all user sharesOf)`.
3. `transferShares` conserves the sum of user shares and does not change `totalShares`.
4. Recorded vault liquidity equals the real full-range, salt-zero manager position liquidity after the operation closes.
5. Shares and idle for one PoolId never change solely because of an operation on another PoolId.
6. Manager currency deltas attributable to WeirVaults close to zero after each unlock.
7. Treasury receipts equal the independently calculated per-currency fee cut for each compound.
8. A failed classified operation leaves the complete pre-operation snapshot unchanged.
9. Pausing blocks deposit only; it does not unexpectedly block withdraw, compound, transferShares, createVault, receive, or views.
10. No invariant may assume ERC20 totalSupply, strict one-token withdrawal, preview/execution parity, donation immunity, or monotonic share value beyond what exact source arithmetic establishes.

### Required handler dimensions

- At least three users with distinct payer/recipient combinations.
- At least two pools, including shared currency and different fee/tick-spacing configurations.
- Hookless and appropriately hooked pools.
- Native and ERC20 funding paths supported by valid V4 currency ordering.
- Single-sided and paired deposits; zap true/false.
- Every withdraw `zapTo` value and invalid values in negative tests.
- Real swaps to generate fees before explicit and implicit compounds.
- Tiny values, rounding boundaries, deadlines, slippage boundaries, and insufficient balances.
- Pause and ownership/admin transitions.
- Bounded donations and hostile peripheral behavior in dedicated campaigns, not mixed into base solvency invariants without classification.

---

## 7. Preservation Risks and Excluded Repairs

| Classification | Risk or limitation | Required treatment |
|---|---|---|
| F/L | Verified source has no supplied upstream Git revision, tests, or audit. | Preserve provenance limits; do not infer security or transaction parity. |
| F/L | GPL-2.0-or-later and BUSL-1.1 occur in the transitive source set. | Preserve notices and require explicit release disposition. |
| F/L | IndexedEx compiler settings differ from upstream. | Test source/ABI/arithmetic behavior; do not demand default bytecode equality. |
| F/L | 1,000 genesis shares are unassigned rather than held by a dead address. | Preserve ledger behavior and test the invariant; no dead-share redesign. |
| F/L | Preview excludes pending fees and lacks zap/maintenance parity. | Document narrowly and test divergence; no new simulator. |
| F/L | Deposit and withdraw zaps use heuristics and extreme price limits. | Characterize partial fills and residuals; no guaranteed full consumption. |
| F/L | Pausing blocks only deposits. | Preserve and test the exact pause matrix. |
| F/L | `createVault` and `transferShares` are outside the reentrancy guard. | Characterize actual reentry; do not claim global reentrancy protection. |
| F/L | Shares are transferable per-pool balances but not ERC20. | No ERC20 events, allowances, wrapper, or compliance assertions. |
| F/L | Idle balances and donations can create accounting or inventory subtleties. | Assert actual balances and ledger treatment; no economic repair. |
| F/L | Narrowing casts, signed conversions, and floor rounding can revert or produce dust. | Characterize exact boundaries; do not silently change math. |
| F/L | No explicit constructor zero-manager check exists. | Record behavior; do not add validation in the faithful import. |
| F/L | Ordinary nested manager unlock fails. | Preserve manager behavior; no hook-only already-unlocked path. |
| F/L | FoT/rebasing tokens are not claimed as supported. | Hostile tests characterize behavior only. |
| X | ERC20/ERC4626, Rate Provider, Diamond/SE, registry, or proxy adaptation. | Separate approved requirements and implementation. |
| X | Fee removal, genesis-share removal, strict single-token guarantee, optimization, or economic repair. | Excluded from this baseline entirely. |

---

## 8. Future Validation Commands

These commands are proposed for the implementation phase; they were not run during authoring.

```sh
forge build
forge test --match-path 'test/foundry/spec/protocols/strategy/weir/**/*.sol' --fuzz-runs 1000 --fuzz-seed 20261029 --invariant-runs 256 --invariant-depth 64
```

For separately available pinned fork evidence:

```sh
FOUNDRY_PROFILE=fork forge build
FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/protocols/strategy/weir/**/*.sol' -vvv
```

The fork command MUST NOT become a hermetic CI prerequisite. Warm `out/` and cache artifacts MUST NOT be deleted merely to accelerate or simplify validation, and slow compilation MUST NOT be killed from impatience.

---

## 9. Release Evidence Checklist

A release candidate is documented only when it provides:

- Frozen-source hash comparison and any import-only diff.
- Exact ABI, tuple, event, and error comparison.
- Dependency compatibility decisions with actual source evidence.
- Full 39-file license inventory and disposition.
- Default-profile build and hermetic test results.
- Real-manager position and manager-delta reconciliation.
- Multi-user and multi-pool deterministic fuzz/invariant parameters and results.
- Exact rollback, pause, ownership, callback, native, zap, and preview-limit evidence.
- Separate fork-parity evidence or an explicit unavailable-state report.
- A limitations section that does not convert source quirks into silently approved fixes.
