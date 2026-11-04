# PairToken baseline implementation and test plan

Status: planning output requested by PT-CONFORM-02. This file is not a normative companion to the PRD, not a requirements change, and not implementation, test execution, deployment, or legal clearance.

| Item | Value |
| --- | --- |
| Behavioral authority | `docs/research/pairtoken-unified-prd-r2-20261027/handoff/PRD.md` |
| PRD identity | pairtoken-unified-prd-r2 |
| PRD SHA-256 | `088ba325456c1ce4a93cbe0fc9625e1119352dbb8b209455460322b11d052d8d` |
| This plan | maps work and evidence; it does not override a tagged requirement |
| Source consultation | not an input. Do not open PairToken source, Sourcify output, or review excerpts to resolve a behavior gap |

If this plan and the PRD disagree, the PRD wins. Delete or correct the plan. Do not "fix" the PRD from an implementation preference.

## 1. What a conformance claim may say

PairToken-local conformance means the specified external behavior, integer results, ABI, events, failures, rollback, and dependency-call ordering hold against the harness in section 5. It does not mean whole-system equivalence.

Whole-system equivalence additionally needs an identified manager, factory, fee manager, hook, and currency whose behavior matches the premises a scenario depends on. This plan does not identify those deployments and does not claim that equivalence.

No claim in the later evidence index may say bytecode identity, factory-clone parity, hook safety, nonstandard-token safety, legal clearance, or source nonexposure. Those are outside this plan.

Documented scenarios are expected observations. A passing test is evidence only after it has been run and its result recorded. This document does not record any such run.

## 2. Source-preserving work and rejected changes

The implementation preserves the specified baseline. The following are not adopted. Adopting any of them later is a product decision that must name the requirement it supersedes. It must not be described as source equivalence.

| Rejected change | Requirement it would supersede |
| --- | --- |
| `getRate`, target normalization, ERC-4626, IRateProvider | PT-ABSENT-01, PT-VIEW-05, PT-SCOPE-03 |
| Per-holder fee claim, fee index, fee debt | PT-SCOPE-01, PT-SCOPE-03, PT-ABSENT-01 |
| Oracle or TWAP admission, manipulation-resistance guarantee | PT-ABSENT-01, PT-SCOPE-03 |
| Permit or signature approval | PT-ABSENT-01 |
| External mint, burn, rescue, sweep, pause, range change, rebalance | PT-ABSENT-01, PT-SCOPE-02, PT-EXIT-05 |
| Manager or factory setter | PT-ABSENT-01 |
| `NotFactory` used as a guard | PT-INIT-03, PT-ERROR-01 |
| Local checks for code existence, currency order, pool readiness, hook policy, or positive spacing | PT-INIT-02, PT-INIT-03, PT-AC-04 |
| Fee-rate clamp, collected-fee cap, or principal-spending guard | PT-COMP-02, PT-AC-68 |
| Fee-on-transfer or rebasing token ban | PT-BAL-07, PT-ABSENT-02 |
| Armed callback flag, entered-flag check on the callback, nonce | PT-CB-01, PT-ABSENT-02 |
| Crane facet, CREATE3 factory, DFPkg, or registry registration | PT-ABSENT-02, PT-SCOPE-02 |
| Transient-storage opcodes for the entered flag, reservation, or skip-add flag | PT-STATE-02 |
| Public reservation, skip-add, or entered getter | PT-API-BASE; extra public surface is out of this plan |
| 2300-gas stipend on native payout or paired refund | PT-BAL-05, PT-BAL-06 |
| Post-receipt share recomputation | PT-DEP-05 |
| Zap leftover refund or genesis dead mint on zap | PT-ZAP-04 |
| Compound tick-movement guard | PT-DEP-02, PT-COMP-05 |
| Positive-addition guard on an established paired deposit | PT-DEP-04 |
| Clamping basket price into the tick range | PT-VIEW-02, PT-AC-33 |
| Replacing amount0 sorting or amount1 absolute difference with an idealized in-range formula | PT-MATH-02, PT-VIEW-02 |
| OpenZeppelin, Solmate, or Uniswap ERC-20 as the share implementation | PT-ERC20-02, PT-ERC20-03 |
| Uniswap math library as authority over the PRD formulas | PT-MATH-04, PT-CONFORM-02 |

No deliberate behavioral deviation is proposed.

## 3. Recorded decisions

These are planning choices required to build a harness and a local contract. They are not discovered PairToken facts. If a later identified deployment disagrees, report the mismatch. Do not consult target source to resolve it.

| ID | Decision |
| --- | --- |
| D-ABI | Call the manager with the stored key, a parameter group, and empty hook data, as PT-CB-03 and PT-DEPENDS-03 require. Local interface: `unlock(bytes) returns (bytes)`; `modifyLiquidity(PoolKey, ModifyLiquidityParams, bytes) returns (int256 callerDelta, int256 feesAccrued)`; `swap(PoolKey, SwapParams, bytes) returns (int256)`; `sync(address)`; `settle() payable returns (uint256)`; `take(address, address, uint256)`; `extsload(bytes32) view returns (bytes32)`. `ModifyLiquidityParams` is `(int24 tickLower, int24 tickUpper, int256 liquidityDelta, bytes32 salt)`. `SwapParams` is `(bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96)`. Currencies are `address`. Address zero is native. |
| D-ABI-PIN | At implementation time, compare D-ABI selectors with one pinned public Uniswap v4-core `IPoolManager` commit and write the commit in the evidence index. A selector mismatch stops the whole-system port. It does not change the local harness, and it is not resolved from PairToken source. |
| D-UNLOCK | `unlock` returns the callback's `bytes` directly. The harness must not wrap those bytes again. This is the PT-CB-02 reading. A real manager that wraps them is a whole-system mismatch. |
| D-DELTA | A balance delta is an `int256`. Currency0 is the high 128 bits, currency1 the low 128 bits, both signed. This is PT-DEPENDS-03. |
| D-SOLC | Compile with the repository root `foundry.toml` compiler, currently solc 0.8.35. Do not add a Foundry profile. `foundry.toml` permits only the default and fork gates and says not to add package profiles. PT-ERROR-03 names Solidity 0.8.26 ABI and panic behavior. The evidence index must show that overflow panic, initialization division panic, custom-error selectors, enum decode failure, and empty MD/MU reverts still match that 0.8.26 contract. A 0.8.35 difference that changes one of those observables is a reported mismatch, not a reason to edit the PRD or add a profile. Bytecode identity with a 0.8.26 build is not claimed. |
| D-VIAIR | Leave `via_ir` false. Fix stack-too-deep with structs or internal frames. That restructuring must not change an observable. |
| D-FACTORY | No clone factory, governance, default fee, or atomic-create flow is implemented. Tests deploy the instance and call `initialize`. Factory-clone parity stays blocked. |
| D-HOOK | No hook contract is written. Hook effects appear only as scripted manager deltas and failures. |
| D-MATH | Implement PT-MATH from the PRD formulas and coefficient table. A published math library is an optional aid only after the independent oracle passes. Library disagreement is a failed implementation, not a PRD amendment. |
| D-SURFACE | Implement the specified public ABI and `receive`. No fallback. No extra public or external function. `NotFactory` is declared and has no revert path. |
| D-PACKAGING | Place the baseline in the root Foundry source tree, outside Crane packaging. Tests may use `new` because this plan is not an IndexedEx production deployment. CREATE3, diamond facets, and registry registration are not part of the local claim. |

### Unknowns that stay unknown

Do not invent a value for any of these.

- Factory owner, governance, default `protocolFeeBps`, `maxZapBps`, `maxZapTickMove`, or clone transaction sequence.
- Fee-manager accounting, recipient, and whether `notify` pulls tokens.
- Manager swap math, fee processing, lock rules, pool validation, and hook permissions.
- Live prices, balances, liquidity, and user payouts.
- Whether a named manager deployment uses the D-ABI selectors and the PT-VIEW-01 slot formula.
- License clearance or a source-unexposed workflow.

## 4. Where the later code goes

Root `foundry.toml` sets `src = 'contracts'` and `test = 'test/foundry/spec'`. Use:

- `contracts/pairtoken-baseline/PairToken.sol`
- `contracts/pairtoken-baseline/PairTokenMath.sol`
- `contracts/pairtoken-baseline/interfaces/IPairTokenDependencies.sol`
- `test/foundry/spec/pairtoken-baseline/` for harnesses and tests

Do not put this baseline under `lib/crane`. Do not register a package, facet, or vault. Do not edit the PRD or the r1 archive. Do not add entries to `ignored_error_codes` to silence this work.

There is no existing `contract PairToken` outside dependencies. Do not convert an IndexedEx vault into this baseline.

Later test command, after implementation is separately authorized:

```
forge test --match-path test/foundry/spec/pairtoken-baseline/*
```

Do not add a Foundry profile for that filter.

## 5. Dependency harness

The harness is not a pool engine. It records calls and returns scripted results. It must not contain a copied manager implementation. The system under test is the PairToken instance. Doubles stand in only for contracts the PRD names as dependencies.

### 5.1 Scripted manager

Implements D-ABI.

- `unlock` calls back `unlockCallback` and returns the callback bytes unchanged.
- `modifyLiquidity` records key, ticks, salt, liquidity delta, and hook data, and returns scripted caller and fee deltas.
- `swap` records direction, amount, and price limit, and returns a scripted delta. It can update the stored slot0 tick and price before returning, so a later extsload sees the after-swap tick.
- `sync`, `settle`, and `take` record arguments and value. `settle` returns a scripted paid amount. The instance must not use that paid amount to change shares.
- `extsload` is a view. Slot0 is at `B`, active-pool liquidity at `B+3`, and the position word at the PT-VIEW-01 position slot. `B = keccak256(abi.encode(poolId, bytes32(uint256(6))))`. The position key is the packed hash of `(instance, tickLower, tickUpper, bytes32(0))` with widths 20, 3, 3, and 32 bytes. The position slot is `keccak256(abi.encode(positionKey, bytes32(uint256(B) + 6)))`.
- Price is the low 160 bits of slot0. Tick is the next 24 bits, signed.
- The double can revert with a distinctive error. That error must propagate. It must not be rewritten as `MinOut`, `MinShares`, or `TransferFailed`.

### 5.2 Scripted factory

Four nonpayable views, each scriptable and each able to revert: `feeManager() returns (address)`, `protocolFeeBps() returns (uint16)`, `maxZapBps() returns (uint16)`, `maxZapTickMove() returns (int24)`. No defaults are built into the instance.

### 5.3 Scripted fee manager

`notify(address token, uint256 amount, bytes32 poolId) payable`. Modes: succeed and pull, succeed and not pull, revert, and accept native value without returning it. No distribution policy is implemented.

### 5.4 Scripted ERC-20

Modes required by the scenarios: honest transfer, empty successful return, false return, malformed nonempty return, one-byte return, 32-byte word equal to 1 followed by extra bytes, fee-on-transfer, balance decrease, and a callback into the instance.

### 5.5 Trace

Every dependency call appends kind, target, value, and calldata, in order. Kinds include extsload, unlock, modify, swap, sync, settle, take, balanceOf, transferFrom, transfer, approve, notify, refund, and payout.

A callee cannot see whether the instance used `STATICCALL`. For PT-VIEW-01 and PT-BAL-01, archive a Foundry trace excerpt that shows `STATICCALL` for `extsload` and token `balanceOf`. Do not add a production guard so the instance can assert this itself.

Native gas forwarding is observed behaviorally. The recipient `receive` writes storage. A 2300-gas stipend would fail that write. Success is the observation. Do not invent a gas number. Calldata must be empty, and value must equal the specified amount.

### 5.6 What the harness must not do

- Do not mock or subclass the instance to expose reservation, skip-add, or entered.
- Do not etch instance storage.
- Do not use a live PoolManager as the expected-value oracle for a local claim.
- Do not treat a successful scripted swap as proof of the integer formulas.

## 6. Implementation work

Recommended order is a build sequence, not a normative requirement. Each step is done only when its named tests exist and pass. This plan does not perform those steps.

Internal layout is free. External behavior is not. One instance contract plus a pure math library is enough. Do not split the public ABI across facets.

### WP-MATH

Implement `MD`, `MU`, `A0down`, `A0up`, `A1down`, `A1up`, `L0`, `L1`, `Fit`, `T`, floor square root, and `U128` as specified.

Traps:

- `MD` and `MU` use a full-precision product. Denominator zero, a result above `uint256`, and `MU` upward overflow are empty reverts, not panic and not custom errors. Native `/` is the wrong failure for denominator zero.
- Checked `uint256` multiplication remains on the genesis product, the retention product `shares * 9990`, the protocol fee product, and both cap products (`reserve * maxZapBps`). Do not rewrite those as `MD`.
- Amount0 sorts endpoints and reverts `InvalidPrice()` when the lower endpoint is zero, including when liquidity is zero. Amount1 uses the absolute difference and does not apply that check.
- `A1up` adds one only when the product has a nonzero remainder modulo `Q96`.
- Inside-range `Fit` checks both candidates before taking the minimum. An overflowing candidate is `SafeCastOverflow()`, even if the other candidate fits.
- Equal bounds fail through the `MD` empty revert. That data must differ from the initialization division panic.
- `T` uses the PRD coefficient table and the specified floors. `T(0) = Q96`. `T` at the tick extrema must equal the PT-CONST-02 sqrt extrema. Out-of-range ticks revert `InvalidTick(int24)` with the supplied tick.
- Floor square root runs only after the checked genesis product succeeds.
- Settlement of a negative delta negates at checked 128-bit width. Widening `int128` minimum to `int256` before negation would hide the required overflow. Removal and collection return values still use `U128`.
- Swap amount encoding is `int256(x)` then checked negation. Do not add an explicit `x < 2^255` reject. `x = 2^255` fails negation. `x > 2^255` encodes as positive `2^256 - x`.

### WP-TOKEN

Implement name, symbol, decimals, supply, balances, allowances, `approve`, `transfer`, and `transferFrom` as specified.

Traps:

- `transfer` checks destination before balance. `transferFrom` subtracts a finite allowance before destination and balance. Maximum allowance is not decreased. There is no caller-equals-owner bypass.
- Recipient balance addition on transfer and mint is modulo `2^256`. Burn decreases supply modulo `2^256`. Other ordinary arithmetic stays checked.
- Allowance consumption emits no `Approval`.
- No fee sync, manager call, or initialization check on these methods.
- Mint and burn are internal only.

### WP-INIT

Storage concepts: metadata, supply, balances, allowances, initialized, factory, manager, full key, pool id, tick bounds, native reservation, entered flag, skip-add flag. Reservation, entered, and skip-add are ordinary storage, not transient storage. Position liquidity and price are not cached.

`initialize` stores the key as supplied. It does not sort currencies, reject equals, require code, initialize a pool, or fund a position. Pool id is `keccak256(abi.encode(currency0, currency1, fee, tickSpacing, hooks))`. Bounds use trunc-toward-zero division as specified. Salt is always zero and is not an argument. The caller becomes factory. No initialization event.

Already-initialized is checked before the zero-manager check. A failed first initialization leaves the uninitialized zero state.

### WP-READ

`positionLiquidity`, `basket`, `previewDeposit`, and `previewRedeem` follow PT-VIEW and PT-QUOTE.

Traps:

- Basket reads price, then position liquidity, then idle0, then idle1. It does not clamp price. Zero liquidity skips the principal terms.
- Uncollected fees are not added to the basket.
- `previewDeposit` returns the gross quote. It does not subtract dead shares, compound, pull, or check `minShares`.
- `previewRedeem(0)` and zero supply return `(0,0)` with no basket read. An oversized share request is not an ownership reject.
- No zap preview and no `getRate`.

### WP-FUNDS

Idle, pull, payout, refund, and approval helpers follow section 11.

Traps:

- Native idle is balance minus reservation, checked. ERC-20 idle is `balanceOf`. Paired idle reads are currency0 then currency1.
- A zero pull makes no token call and returns zero. A native pull returns the nominal amount and does not measure a balance delta. A nonzero ERC-20 pull returns the checked post-minus-pre difference. A lower post-balance is a checked subtraction failure, not `TransferFailed`, and not a clamp to zero.
- Pull and manager-payment helpers accept empty success or a decoded true. False or a failed call is `TransferFailed`. Malformed nonempty data is a decode failure.
- Payout is different. Native payout is an empty-calldata call that forwards remaining gas. ERC-20 payout accepts empty data or a first 32-byte word equal to 1; extra bytes are allowed; short data fails. Failures use `WrappedError`, with `bytes4(0)` and `NativeTransferFailed()` for native, and `transfer` plus `ERC20TransferFailed()` for ERC-20. `reason` is the complete raw returndata.
- Paired refund clears the reservation, then calls the sender, not the recipient, with remaining gas. Failure is `TransferFailed`, not `WrappedError`. Zero skips the call.
- Approval helper returns false on a failed or false call. Malformed data reverts. No zero-first retry.
- `receive` accepts value from any sender and emits nothing. It does not authenticate the manager.

### WP-CB

`unlockCallback` checks the sender before decoding. There is no armed flag. None, including from the manager, reverts `NotPoolManager`. Out-of-range or malformed ABI fails decode.

Operations:

- Add, including an explicit zero, is a nonnegative `modifyLiquidity`. Used amounts are `max(int256(fee) - int256(callerDelta), 0)` after widening. The returned used payload does not reprice paired shares.
- Remove and Collect return `U128` of caller deltas, not the used-amount formula. Collect ignores its inner payload and uses a zero liquidity change. Reported collection is the caller delta, not `feesAccrued`.
- Deploy reads price and tick first. A zero swap makes no swap call and no second tick read. A positive swap uses the PT-MATH-05 signed amount and the specified price limit, with empty hook data. Output is the positive part of the opposite delta, else zero. Deltas are resolved before the after-tick read. The after tick is not reread after the subsequent add.
- Skip-add returns zero used amounts and zero addition, and does not read idle balances.
- Otherwise Deploy reads idle0 then idle1, fits liquidity at the price it already holds, and adds only when that fit is positive.
- Settlement per currency: negative native calls payable `settle`; negative ERC-20 calls `sync`, then transfer, then `settle`; positive calls `take` to the instance; zero makes no settlement call.
- A compound's Collect and Deploy are separate unlocks. A later Add, Remove, or redemption Deploy is another unlock. Pulls, mints, burns, notifications, and payouts stay outside those callbacks.

### WP-COMP

Public `compound` is permissionless and guarded. The same behavior runs at the deposit and redemption checkpoints. It does not run on transfer, approval, views, or a bare donation.

Traps:

- Zero position liquidity skips Collect and reports collection `(0,0)`. It can still Deploy.
- Protocol routing runs only when a reported collection amount is positive. It reads `feeManager()` then `protocolFeeBps()`, even if the manager address is zero. A zero manager or zero rate skips routing. A zero computed amount skips that currency. There is no local cap at 10000.
- Native `notify` failure is caught and reports zero. ERC-20 approval false reports zero without `notify`. ERC-20 `notify` failure attempts `approve(feeManager, 0)`, ignores that Boolean, and reports zero. A cleanup decode failure propagates. Factory getter failures and arithmetic failures propagate. Do not document that fee-manager failure can never block a user.
- Successful `notify` reports the attempted amount. It is not proof of a pull, and the success path does not reset the allowance.
- The attempted protocol amount can exceed collected fees and idle principal. Preserve the PT-AC-68 underflow. Do not add a clamp.
- After routing, read idle0 then idle1. Both at most 1000 skips Deploy. Otherwise compute the ratio swap. Ties select token0. A chosen leftover at most 1000, or zero active-pool liquidity, makes the swap amount zero but does not skip Deploy.
- The compound cap is `floor(floor(activeReserve * maxZapBps / 10000) / 4)`, using active-pool liquidity, not the vault basket. No compound tick guard.
- `Compounded` is emitted only when a reported collection amount or the reported addition is positive. A swap alone does not emit it. Public `compound` returns the gross collection pair. Compound mints no shares.
- Fees returned by a later add in the same compound are settled and do not start a second protocol cut.

### WP-ENTRY

`deposit` and `zapDeposit` take the entered guard before body checks.

Paired order: recipient, native value, reserve `msg.value`, compound, quote, gross `minShares`, pulls, fit and optional Add, zero-supply nonzero-add check, mint, refund, `Deposit`.

Traps:

- The native reservation hides incoming principal from the compound that runs before the pull.
- Shares are fixed at the post-compound quote. Measured receipts change funding and event amounts only.
- Genesis compares `minShares` with gross shares, then mints 1000 to `DEAD` and the remainder to `to`. The return value is the net amount.
- Zero snapshotted supply with zero computed addition is `BadGenesis` after the pull. Positive snapshotted supply may add zero liquidity and still mint.
- Unselected excess is not pulled. Unused pulled funds stay idle. There is no universal ERC-20 refund.
- Native refund goes to `msg.sender` after the mint and before `Deposit`.

Zap order: recipient, token, native value, reserve, compound, nonzero supply and both reserves, nominal cap, pull, clear reservation, Deploy with `floor(v / 2)`, absolute tick movement against the then-read limit, share quote, `minShares`, mint, `Deposit`.

Traps:

- Zap does not bootstrap genesis and does not mint dead shares.
- The cap uses the input side of the vault basket, not active-pool liquidity. Equality with the cap passes. Zero input is `ZapTooLarge` and short-circuits that cap read. A `uint16` above 10000 is not clamped.
- If both stored currencies equal the input, currency0 wins.
- Tick equality passes. A negative limit is not locally rejected. The after tick is the Deploy return, not a post-add reread.
- Issued shares use Deploy's add-used amounts and the pre-zap basket and supply. Old idle included in those used amounts changes the mint. No zap refund.
- Zero issued shares is `MinShares` even when `minShares` is zero.

### WP-EXIT

Shared order: guard, recipient, zap token check before compound, compound, nonzero shares and supply, idle0, idle1, burn the caller, payout math, then position-liquidity read, optional remove, minima, payout, `Redeem`.

Traps:

- Allowance does not authorize burning another holder.
- `payout = floor(s * 9990 / 10000)` with checked multiplication, before the liquidity read. `ell` is the low 128 bits of `MD(L, payout, S)`, not a checked cast. Remove only if `ell > 0`.
- Idle fractions and the liquidity fraction round separately. No extra removal compensates.
- Paired route skips a zero payout call. Chosen-leg route still attempts a zero selected transfer.
- Chosen-leg sale is a skip-add Deploy of the unwanted amount, with no zap cap and no tick guard. Partial fill can succeed. `Redeem` amounts are the pre-swap pair. The return value is the selected output.
- Dead shares remain. There is no last-holder sweep.
- A rejected payout rolls back the burn and the earlier compound. Native payout failure is `WrappedError`, not the refund's `TransferFailed`.

### WP-SURFACE

Declare every PT-ERROR-01 error with an empty argument list, including unused `NotFactory`. Declare `WrappedError(address,bytes4,bytes,bytes)`, `NativeTransferFailed()`, `ERC20TransferFailed()`, `InvalidTick(int24)`, `InvalidPrice()`, and `SafeCastOverflow()`.

Events are non-anonymous, with the specified fields and indexing. No other event is added.

Guard only `deposit`, `zapDeposit`, `redeem`, `redeemZap`, and `compound`. Set the flag before the body and clear it on the success path. Failure rollback clears it. Views, ERC-20, `initialize`, `receive`, and the callback are outside the guard.

Unknown selectors have no fallback.

## 7. Test architecture

Tests use `forge-std` `Test` plus the harness in section 5. Do not use a Crane or IndexedEx vault base. Those bases import registry and diamond assumptions this baseline excludes.

Each acceptance test deploys a fresh instance. Expected integers come from an independent oracle, not from calling production math helpers.

The tick oracle is a script that parses the coefficient table from the PRD file whose hash is above, and writes fixtures. Do not hand-copy the sixteen-plus coefficients into a second Solidity table and treat agreement as independence. Boundary equalities `T(0) = Q96` and the two sqrt extrema are additional checks.

Forbidden oracles:

- PairToken source, Sourcify, or a deployed bytecode diff.
- A live PoolManager.
- A property that encodes a rejected repair, such as "fee rate above 10000 always reverts" or "preview equals the later redemption."

Fuzz is allowed only for identities the PRD states, such as full-precision `MD` against an independent wide product. Fuzz does not replace a named scenario.

### 7.1 Evidence classes

| Class | Observation |
| --- | --- |
| E-INT | Integer return, stored value, or scripted request amount |
| E-ABI | Selector, mutability, return shape, or absence of a selector |
| E-EVT | Emitter, indexed fields, values, and local order |
| E-REV | Revert data and rollback of balances, allowances, supply, and dependency state |
| E-ORD | Recorded dependency-call order, or a static-call trace excerpt |
| E-PLAN | Planning constraint satisfied by this document or by the evidence index, not by a runtime success |

Event order is a partial order. Filter logs by the instance address, and interleave the refund or payout trace when the requirement places a call between logs. Do not require the absence of dependency logs between instance logs.

Rollback assertions cover share balances, supply, allowances, token balances, and native balances. Reservation is not public. Its evidence is that compound idle excludes the reserved value, and that a failed later step restores balances.

### 7.2 Numeric fixtures

These are independent calculations for the later tests. They are not extra requirements.

| Fixture | Arithmetic | Result |
| --- | --- | --- |
| Spacing 60 | trunc(`-887272 / 60`) * 60 and trunc(`887272 / 60`) * 60 | `-887220`, `887220` |
| Spacing -60 | same trunc-toward-zero formula | `-887220`, `887220`; initialization must not reject the sign |
| PT-AC-12 | `min(floor(100*10000/3000), floor(500*10000/7000))`; then `ceil(333*7000/10000)` | gross 333, selected `(100, 234)` |
| PT-AC-23 | `floor(1000*9990/10000)`; `floor(50000*999/10000)`; idle floors | payout 999, removal request 4995, idle contributions `(10, 9)` |
| PT-AC-08 | `sqrt(2000*2000)` | gross 2000; mint 1000 dead and 1000 net |
| One-reserve quote | supply 10000, reserves `(0, 5000)`, amounts `(100, 250)` | gross 500, selected `(0, 250)` |
| Both-reserves-zero quote | supply 50, amounts `(9, 16)` | gross 12, no dead mint |
| Genesis boundary | `sqrt(1000*1000)` and `sqrt(1001*1001)` | 1000 rejects `BadGenesis`; 1001 passes the size guard |
| Overflow product | `2^128 * 2^128` | checked multiplication fails |
| Zap cap | `floor(100000*100/10000)` | 1000 |
| Zap swap | `floor(999/2)` | 499 |
| Protocol cut | `floor(10000*250/10000)`, `floor(5000*250/10000)` | `(250, 125)`; public return stays `(10000, 5000)` |
| Compound cap | `floor(floor(10000*100/10000)/4)` | 25, and a tie selects token0 |
| PT-AC-68 | `floor(100*20000/10000)` | attempted native notify 200, then checked idle underflow |
| Q96 | `2^96` | `79228162514264337593543950336` |

`previewDeposit` and the deposit share check use gross shares. `minShares = 2000` can succeed while the recipient receives 1000. `minShares = 2001` rejects. Do not compare the minimum with the net mint.

### 7.3 Scenario premises

Unless a row says otherwise, dependency calls succeed, no unrelated state changes, and a revert restores earlier effects in that transaction.

| ID | Premise the harness must supply | Observation |
| --- | --- | --- |
| PT-AC-01 | Fresh instance, no `initialize` | Empty metadata, zero stored fields, constants available, `previewRedeem(0)` is `(0,0)` with no manager read, `receive` and zero-value ERC-20 are not initialization-gated |
| PT-AC-02 | Caller A, nonzero manager, spacing 60 | Factory A, key and metadata stored, bounds `-887220` and `887220`, pool id is the independent ABI hash, supply 0, no initialization log |
| PT-AC-03 | Repeat initialize, including with manager zero; separate fresh manager zero; separate fresh spacing zero | `AlreadyInitialized`; `ZeroAddress`; division failure with initialized still false |
| PT-AC-04 | Nonzero manager with no code, unsorted or equal currencies, arbitrary hook, spacing -60 | No invented local reject. Bounds follow the formula. Later manager failure is independent |
| PT-AC-05 | Allowance 10, spender moves 4; then insufficient allowance and insufficient balance | Allowance 6, balances move 4, consumption emits `Transfer` only. Failure restores allowance. Self-transfer still consumes allowance |
| PT-AC-06 | Maximum allowance; zero and self transfers; zero destination | Maximum allowance unchanged. Zero destination fails. Finite insufficient `transferFrom` to address zero fails on allowance first |
| PT-AC-07 | Transfer while the manager would report fees if collected | No unlock, no notify, no fee-debt field. Buyer receives the transferred shares only |
| PT-AC-08 | Zero supply, basket reads succeed, amounts `(2000,2000)` | Preview gross 2000. `minShares` 2000 mints 1000 dead and 1000 net. `minShares` 2001 is `MinShares` and mints nothing |
| PT-AC-09 | `sqrt` at most 1000; separately a larger quote whose post-pull fit is zero because the funding leg receipt is zero and price is one-sided | First fails `BadGenesis` in preview. Second fails `BadGenesis` after the pull and rolls back |
| PT-AC-10 | Positive supply, both basket reserves zero | Geometric mean, no dead mint, no genesis size guard. A zero quote can preview and must fail `MinShares` on deposit |
| PT-AC-11 | Positive supply, exactly one reserve zero | Quote uses the other leg only. Paired entry does not require both input amounts to be nonzero |
| PT-AC-12 | Supply 10000, basket `(3000,7000)`, amounts `(100,500)` | Gross 333, selected `(100,234)`. Token1 pull is 234, not 500 |
| PT-AC-13 | Quote accepted, token delivers less than selected | Shares stay at the quote. Event amount is the measurement. A later manager revert is left as a manager revert |
| PT-AC-14 | Native currency0, `msg.value` equals requested amount0, quote selects less, sender differs from recipient | Compound idle excludes the reservation. Refund of the remainder goes to the sender after mint. Refund rejection is `TransferFailed` and rolls back |
| PT-AC-15 | Wrong native value; value sent when currency0 is not native; zero recipient; value sent to a nonpayable method | `NativeMismatch` before compound. Zero recipient wins over the value check. Nonpayable value fails at dispatch, not `NativeMismatch` |
| PT-AC-16 | Pulled or pre-existing idle exceeds fit; established entry computes zero addition with a positive quote | Unused funds stay idle. No positive-add guard and no ERC-20 refund |
| PT-AC-17 | Zap before positive supply and both positive reserves | `BadGenesis` after compound. No genesis mint |
| PT-AC-18 | Input-side basket reserve 100000, `maxZapBps` 100 | Cap 1000. 1001 and 0 fail `ZapTooLarge`. 1000 passes that check. Zero input does not read `maxZapBps` when compound did not already read it |
| PT-AC-19 | Nominal zap accepted, measured receipt 999 | Swap request 499. Mint uses add-used amounts and the pre-zap snapshot. No leftover refund |
| PT-AC-20 | Script tick movement equal to the limit, above it, and a nonnegative movement against a negative limit | Equality passes. The other two are `ZapMovesPrice` and roll back the pull, swap, and add |
| PT-AC-21 | Idle already present and Deploy reports used amounts above the new receipt | Mint uses those used amounts against the pre-zap basket, not a depositor-only balance |
| PT-AC-22 | Zero-supply amounts `2^128`, `2^128` | Checked product fails. A full-precision square root must not make this succeed |
| PT-AC-23 | Supply 10000, burn 1000, liquidity 50000, idle `(101,99)` | Removal request 4995, idle contributions `(10,9)`, return is scripted removal deltas plus those contributions, burn is 1000 |
| PT-AC-24 | Burn one share, zero minima, dependencies succeed, payout rounds to zero | No removal and no idle payout. Paired route skips zero calls. Chosen-leg route still attempts the zero transfer. Burn succeeds |
| PT-AC-25 | Same burn with a positive minimum | `MinOut`, shares and compound effects restored. Not a zero-liquidity error |
| PT-AC-26 | Owner approved the caller; caller has no shares | Allowance is not a redemption right. Caller balance check fails. Owner balance unchanged |
| PT-AC-27 | Chosen-leg exit, manager returns a partial fill, skip-add set | Success if the selected total meets `minOut` and payout succeeds. No complete-fill check. No add during that Deploy. Unconsumed input stays idle |
| PT-AC-28 | Separate exits selecting each currency; one unrelated token | Either currency works. Unrelated token is `BadToken` before compound. Event amounts are the pre-swap pair |
| PT-AC-29 | Preview with zero shares or zero supply; preview above supply | Zero cases skip the basket read. Oversize has no ownership cap |
| PT-AC-30 | Preview, then a compound that changes liquidity, then redeem | The test must not require equality. One scripted case must show inequality |
| PT-AC-31 | Direct donation of a pool currency and of a third token | Supply unchanged. Pool-currency idle can increase basket and later redemption. Third token is not in the basket. No rescue selector |
| PT-AC-32 | Ordinary holders redeem; dead shares remain | No sweep. Remaining supply includes dead shares |
| PT-AC-33 | Slot0 price below the lower tick and above the upper tick | Basket uses raw price, amount0 sorting, and amount1 absolute difference. No clamp. Fit's one-sided branch is a separate math test |
| PT-AC-34 | Zero position liquidity with idle; separately positive position liquidity and caller delta different from fee delta | Zero position skips Collect and can Deploy. Positive position collects with a zero liquidity change and reports caller deltas. No share mint |
| PT-AC-35 | Collection `(10000,5000)`, rate 250, notify succeeds | Notify amounts `(250,125)`. Return remains `(10000,5000)`. Event fee fields are the gross collection, not the net |
| PT-AC-36 | Positive collection with zero fee manager; separately both collections zero | First reads both routing getters and skips notify. Second does not read those two getters. A later ratio cap may still read `maxZapBps` |
| PT-AC-37 | ERC-20 notify succeeds and pulls nothing | Reported protocol amount is the attempt. Allowance remains. No success-path reset |
| PT-AC-38 | Native notify reverts; ERC-20 notify reverts after approval; cleanup approval returns malformed data | Caught failures report zero. Malformed cleanup aborts. Caught native value remains in the instance |
| PT-AC-39 | Approval helper false; malformed approval data; factory getter revert | False skips notify and reports zero. Malformed data and getter failure abort rather than being caught as notify failures |
| PT-AC-40 | Both idles 1000; separately one idle 1001 | First skips Deploy. Second runs Deploy even if the ratio swap amount is zero |
| PT-AC-41 | Chosen leftover at most 1000; separately active-pool liquidity zero | Swap amount becomes zero at that checkpoint. Deploy is not suppressed by that zero swap |
| PT-AC-42 | Converted leftovers equal; active reserve 10000 and `maxZapBps` 100 | Token0 is chosen. Cap is 25. No basket-cap substitution and no tick guard |
| PT-AC-43 | Collection zero, addition zero, swap nonzero | No `Compounded` event |
| PT-AC-44 | Add after the collection checkpoint returns new fee deltas | Used amount is widened fee minus caller delta. No second protocol-rate read |
| PT-AC-45 | Unrelated sender sends valid or malformed callback data; manager calls back with no armed flag | Unrelated sender is `NotPoolManager` before decode. Manager is not rejected for a missing armed flag |
| PT-AC-46 | Manager sends None, each valid operation, malformed payload, and Collect with garbage payload | None is `NotPoolManager`. Malformed data is ABI failure. Collect ignores payload. Explicit zero Add still calls `modifyLiquidity` |
| PT-AC-47 | Caller delta `-1` with settlement success; separately caller delta equal to `int128` minimum | Return is `2^128-1`. Minimum fails checked 128-bit negation |
| PT-AC-48 | Opposite swap delta zero or negative | Reported swap output is zero. Actual deltas are still settled. No positive-output guard |
| PT-AC-49 | Negative ERC-20 delta, negative native delta, positive delta, zero delta | Sync then transfer then settle; native settle has value and no sync; positive take to the instance; zero has neither path. Hook data empty |
| PT-AC-50 | Compound plus entry or exit that collects, deploys, and adds or removes | Separate unlocks. Pulls, mints, and burns are outside the callback |
| PT-AC-51 | During a manager callback, call a guarded entry and call share `transfer` | Guarded call is `Reentrancy` before its body checks, including a zero recipient. Share transfer is not rejected by the flag |
| PT-AC-52 | Payout returns one byte `0x01`; payout returns 32 zero bytes; pull returns malformed data; pull returns false | Payout uses `WrappedError` and preserves the short or false returndata. Malformed pull is a decode failure. False pull is `TransferFailed` |
| PT-AC-53 | Payout token taxes the transfer | Minimum and event use the nominal amount. No recipient-balance compensation |
| PT-AC-54 | A later minimum, refund, or payout fails after compound, mint, or burn; separately a notify failure is caught | Uncaught failure restores state and logs. Caught notify failure can let the outer operation succeed |
| PT-AC-55 | `T(0)`; tick 887273; equal fit bounds; one inside-range candidate above `uint128` | `Q96`; `InvalidTick`; empty `MD` revert distinct from initialization panic; `SafeCastOverflow` without using the smaller candidate to dodge it |
| PT-AC-56 | Swap amount `2^255` and `2^255+1` | Negation failure at `2^255`. Above that, the recorded signed word is positive `2^256-x`. No added upper-bound guard |
| PT-AC-57 | Genesis deposit, zap deposit, zap redeem, and allowance consumption | Instance logs match section 12 schemas, indexing, gross/net distinctions, and local order. Zap `Redeem` amounts are not the final one-token output |
| PT-AC-58 | Call `getRate`, `claimFees`, administrative mint, and rescue selectors | No such function. Unknown selector has no fallback |
| PT-AC-59 | Native paired entry, value equals requested amount0, quote selects less, sender differs from recipient; separate case where refund is zero | Deposit native amount is the selected nominal amount. Nonzero refund is cleared and sent to the caller after mint and before `Deposit`. Zero refund makes no call |
| PT-AC-60 | ERC-20 pull returns true and leaves the balance unchanged | Pull result and Deposit amount are zero. Quoted positive shares still mint if later steps succeed |
| PT-AC-61 | ERC-20 pull returns true and the balance decreases | Checked subtraction fails. Not clamped, and not reclassified as `TransferFailed`. Compound effects roll back |
| PT-AC-62 | Reach basket, paired add, redemption, compound, Deploy add, and skip-add Deploy | Idle pairs read currency0 then currency1. Paired add reads a fresh price after the idle pair. Deploy uses its held price. Redemption samples idle before burn and reads liquidity after payout math. Skip-add reads no idle pair. An earlier `BadToken` reads none |
| PT-AC-63 | Zap Deploy succeeds with zero used amounts, zero addition, and an acceptable tick move | `MinShares` even when `minShares` is zero. Pull, swap, and compound roll back. No dead mint and no leftover refund |
| PT-AC-64 | Chosen-leg output zero with zero minimum and a successful zero transfer; paired outputs zero | Chosen-leg still calls the selected transfer and emits the pre-swap pair. Paired route skips each zero payout |
| PT-AC-65 | Native payout, including a zero-value chosen-leg payout, is rejected by the recipient | `WrappedError` targets the recipient, selector `bytes4(0)`, raw reason bytes, and `NativeTransferFailed()` details. Not `TransferFailed`. Burn and compound roll back |
| PT-AC-66 | Zero position liquidity, idle above 1000, Deploy reports addition A | No Collect and no routing getter reads. Return `(0,0)`. Event `Compounded(0,0,0,0,A)`. No share mint. `maxZapBps` may be read |
| PT-AC-67 | Zero position liquidity, idle trigger, Deploy addition zero | No Collect, return `(0,0)`, Deploy still runs, no `Compounded`, no mint |
| PT-AC-68 | Native collection `(100,0)`, rate 20000, fee manager keeps 200, reservation `R>=100`, pre-notify balance `R+100` | Idle subtraction underflows and the whole transaction rolls back, including the 200 payment. Do not make this succeed with a clamp |

### 7.4 Additional tests

Scenarios do not exhaust the requirements. These tests are required as well.

| Test | Covers |
| --- | --- |
| `test_PT_MATH_md_mu` | Full-precision product, empty reverts, checked products not rewritten as `MD` |
| `test_PT_MATH_amounts` | Sorting, `InvalidPrice`, absolute amount1, `A1up` remainder |
| `test_PT_MATH_fit` | Three price branches and inside-range cast failure |
| `test_PT_MATH_tick_oracle` | PRD-parsed coefficient oracle, including both extrema |
| `test_PT_CONST_01` | Exact constant values, including the dead address |
| `test_PT_GET_all` | Every getter, view and nonpayable, no manager write |
| `test_PT_API_mutability` | Payable set is only deposit, zapDeposit, and receive |
| `test_PT_VIEW_slots` | Instance extsload slots equal the independent PT-VIEW-01 derivation |
| `test_PT_ERROR_selectors` | Declared errors exist. `NotFactory` has no producing path in the specified calls |
| `test_PT_ERROR_precedence` | The PT-ERROR-02 pairs, one invalid condition at a time |
| `test_PT_ABSENT_surface` | PT-ABSENT-01 selectors and no fallback |
| `test_PT_GAS_forwarding` | Native payout and refund succeed when the recipient writes storage |
| `test_PT_INIT_negative_spacing` | Spacing -60 is not locally rejected |
| `test_PT_ZAP_equal_currencies` | Equal stored currencies take the currency0 branch |
| `test_PT_EXIT_skip_add` | Skip-add is set only for the redemption Deploy and does not suppress a later add after successful return |

`test_PT_ERROR_selectors` cannot prove a universal absence of `NotFactory` by execution alone. The evidence index also includes a review note that the identifier appears only in its declaration. Say that limit. Do not claim a proof the tests do not have.

### 7.5 Static-call and compiler evidence

Archive a trace excerpt for one basket read and one ERC-20 idle read showing `STATICCALL`. That excerpt is the PT-VIEW-01 and PT-BAL-01 call-kind evidence.

Archive the compiler version used. Include one overflow panic, one initialization division panic, one empty `MD` revert, and one custom-error selector. State whether those encodings match the Solidity 0.8.26 contract named in PT-ERROR-03. If they do not, the local conformance claim is blocked on D-SOLC rather than silently passed.

## 8. Evidence map

Work packages are the responsibilities in section 6. `WP-PLAN` is this document. `WP-HARNESS` is section 5. Classes are in section 7.1. A planned test name is not a passed test.

| ID | Work | Evidence | Class |
| --- | --- | --- | --- |
| PT-CONFORM-01 | WP-PLAN | Section 1. Tests must not let a success example override an earlier guard or dependency failure | E-PLAN |
| PT-CONFORM-02 | WP-PLAN | This document is the mapping, assumption list, interface list, and source-preserving boundary | E-PLAN |
| PT-CONFORM-03 | WP-PLAN | Sections 1, 7, and 8. The later evidence index distinguishes local conformance from whole-system equivalence | E-PLAN |
| PT-SCOPE-01 | WP-TOKEN, WP-COMP | PT-AC-07, PT-AC-31, PT-AC-34 | E-INT |
| PT-SCOPE-02 | WP-INIT, WP-SURFACE | PT-AC-02, PT-AC-58, no range or rebalance selector | E-ABI |
| PT-SCOPE-03 | WP-READ, WP-TOKEN | PT-AC-07, PT-AC-10, PT-AC-29 | E-INT |
| PT-SCOPE-04 | WP-INIT, WP-FUNDS | `test_PT_CONST_01`, PT-AC-14, no decimals call in the trace | E-INT, E-ORD |
| PT-STATE-01 | WP-INIT | PT-AC-01, PT-AC-02 | E-ABI |
| PT-STATE-02 | WP-ENTRY, WP-EXIT, WP-CB | PT-AC-14, PT-AC-51, `test_PT_EXIT_skip_add`. Flags are storage; no transient-storage opcode in the baseline | E-ORD |
| PT-CONST-01 | WP-INIT | `test_PT_CONST_01` | E-INT |
| PT-CONST-02 | WP-MATH | `test_PT_CONST_02` inside `test_PT_MATH_tick_oracle` | E-INT |
| PT-API-BASE | WP-SURFACE | `test_PT_API_mutability`, `test_PT_GET_all` | E-ABI |
| PT-API-01 | WP-INIT | PT-AC-02 | E-ABI |
| PT-API-02 | WP-TOKEN | PT-AC-05 | E-ABI |
| PT-API-03 | WP-TOKEN | PT-AC-06 | E-ABI |
| PT-API-04 | WP-TOKEN | PT-AC-05 | E-ABI |
| PT-API-05 | WP-INIT | PT-AC-02 | E-ABI |
| PT-API-06 | WP-INIT | PT-AC-02 unwrap | E-ABI |
| PT-API-07 | WP-INIT | PT-AC-02 unwrap | E-ABI |
| PT-API-08 | WP-READ | `test_PT_VIEW_slots` | E-ABI |
| PT-API-09 | WP-READ | PT-AC-33 | E-ABI |
| PT-API-10 | WP-READ | PT-AC-08 | E-ABI |
| PT-API-11 | WP-READ | PT-AC-01, PT-AC-29 | E-ABI |
| PT-API-12 | WP-ENTRY | PT-AC-08 | E-ABI |
| PT-API-13 | WP-ENTRY | PT-AC-19 | E-ABI |
| PT-API-14 | WP-EXIT | PT-AC-23 | E-ABI |
| PT-API-15 | WP-EXIT | PT-AC-28 | E-ABI |
| PT-API-16 | WP-COMP | PT-AC-35 | E-ABI |
| PT-API-17 | WP-CB | PT-AC-45 | E-ABI |
| PT-API-18 | WP-FUNDS | PT-AC-01 | E-ABI |
| PT-GET-BASE | WP-INIT | `test_PT_GET_all` | E-ABI |
| PT-GET-01 | WP-INIT | `test_PT_GET_all` | E-ABI |
| PT-GET-02 | WP-INIT | `test_PT_GET_all` | E-ABI |
| PT-GET-03 | WP-INIT | `test_PT_CONST_01` | E-INT |
| PT-GET-04 | WP-INIT | PT-AC-08, PT-AC-32 | E-INT |
| PT-GET-05 | WP-TOKEN | PT-AC-05 | E-INT |
| PT-GET-06 | WP-TOKEN | PT-AC-05 | E-INT |
| PT-GET-07 | WP-INIT | `test_PT_CONST_01` | E-INT |
| PT-GET-08 | WP-INIT | `test_PT_CONST_01` | E-INT |
| PT-GET-09 | WP-INIT | `test_PT_CONST_01` | E-INT |
| PT-GET-10 | WP-INIT | `test_PT_CONST_01` | E-INT |
| PT-GET-11 | WP-INIT | `test_PT_CONST_01` | E-INT |
| PT-GET-12 | WP-INIT | PT-AC-02 | E-ABI |
| PT-GET-13 | WP-INIT | PT-AC-02 | E-ABI |
| PT-GET-14 | WP-INIT | PT-AC-02 | E-INT |
| PT-GET-15 | WP-INIT | PT-AC-02 | E-INT |
| PT-GET-16 | WP-INIT | PT-AC-02 | E-INT |
| PT-GET-17 | WP-INIT | PT-AC-01, PT-AC-02 | E-ABI |
| PT-MATH-01 | WP-MATH | `test_PT_MATH_md_mu`, PT-AC-22 | E-INT, E-REV |
| PT-MATH-02 | WP-MATH | `test_PT_MATH_amounts`, PT-AC-33 | E-INT, E-REV |
| PT-MATH-03 | WP-MATH | `test_PT_MATH_fit`, PT-AC-55 | E-INT, E-REV |
| PT-MATH-04 | WP-MATH | `test_PT_MATH_tick_oracle` | E-INT, E-REV |
| PT-MATH-05 | WP-MATH, WP-CB | PT-AC-47, PT-AC-56 | E-INT, E-REV |
| PT-INIT-01 | WP-INIT | PT-AC-02, PT-AC-03 | E-REV |
| PT-INIT-02 | WP-INIT | PT-AC-02, PT-AC-03, PT-AC-04, `test_PT_INIT_negative_spacing` | E-INT, E-REV |
| PT-INIT-03 | WP-INIT | PT-AC-01, PT-AC-04, `test_PT_ERROR_selectors` | E-REV |
| PT-PERM-01 | WP-SURFACE | PT-AC-51 | E-REV |
| PT-VIEW-01 | WP-READ | `test_PT_VIEW_slots`, static-call trace excerpt | E-ORD |
| PT-VIEW-02 | WP-READ | PT-AC-33, PT-AC-62 | E-INT, E-ORD |
| PT-VIEW-03 | WP-READ | PT-AC-08 | E-INT |
| PT-VIEW-04 | WP-READ | PT-AC-01, PT-AC-29 | E-INT, E-ORD |
| PT-VIEW-05 | WP-READ | PT-AC-30 | E-INT |
| PT-QUOTE-01 | WP-READ | PT-AC-08, PT-AC-09, PT-AC-10, PT-AC-11, PT-AC-12, PT-AC-22 | E-INT, E-REV |
| PT-DEP-01 | WP-ENTRY | PT-AC-14, PT-AC-15, PT-AC-59 | E-REV, E-ORD |
| PT-DEP-02 | WP-ENTRY | PT-AC-08, PT-AC-15 | E-INT, E-ORD |
| PT-DEP-03 | WP-ENTRY | PT-AC-16, PT-AC-62 | E-ORD |
| PT-DEP-04 | WP-ENTRY | PT-AC-08, PT-AC-09, PT-AC-10 | E-INT, E-REV |
| PT-DEP-05 | WP-ENTRY | PT-AC-13, PT-AC-59, PT-AC-60 | E-INT, E-EVT |
| PT-ZAP-01 | WP-ENTRY | PT-AC-17, `test_PT_ZAP_equal_currencies` | E-REV |
| PT-ZAP-02 | WP-ENTRY | PT-AC-17, PT-AC-18 | E-REV, E-ORD |
| PT-ZAP-03 | WP-ENTRY | PT-AC-19, PT-AC-20 | E-INT, E-REV |
| PT-ZAP-04 | WP-ENTRY | PT-AC-19, PT-AC-21, PT-AC-63 | E-INT, E-REV |
| PT-EXIT-01 | WP-EXIT | PT-AC-26, PT-AC-62 | E-REV, E-ORD |
| PT-EXIT-02 | WP-EXIT | PT-AC-23, PT-AC-24 | E-INT |
| PT-EXIT-03 | WP-EXIT | PT-AC-25, PT-AC-64 | E-REV, E-ORD |
| PT-EXIT-04 | WP-EXIT | PT-AC-27, PT-AC-28, PT-AC-64 | E-INT, E-EVT |
| PT-EXIT-05 | WP-EXIT | PT-AC-24, PT-AC-27, PT-AC-32 | E-INT |
| PT-COMP-01 | WP-COMP | PT-AC-34, PT-AC-07 | E-ORD |
| PT-COMP-02 | WP-COMP | PT-AC-35, PT-AC-36, PT-AC-68 | E-INT, E-REV |
| PT-COMP-03 | WP-COMP | PT-AC-37, PT-AC-38, PT-AC-39 | E-INT, E-REV |
| PT-COMP-04 | WP-COMP | PT-AC-40, PT-AC-41, PT-AC-42, PT-AC-62 | E-INT, E-ORD |
| PT-COMP-05 | WP-COMP | PT-AC-41, PT-AC-42 | E-INT |
| PT-COMP-06 | WP-COMP | PT-AC-43, PT-AC-66, PT-AC-67 | E-EVT |
| PT-ERC20-01 | WP-TOKEN | PT-AC-05 | E-EVT |
| PT-ERC20-02 | WP-TOKEN | PT-AC-06, PT-AC-07 | E-INT |
| PT-ERC20-03 | WP-TOKEN | PT-AC-05, PT-AC-06 | E-REV |
| PT-ERC20-04 | WP-TOKEN | PT-AC-08, PT-AC-23 | E-EVT |
| PT-CB-01 | WP-CB | PT-AC-45 | E-REV |
| PT-CB-02 | WP-CB | PT-AC-46 | E-ABI, E-REV |
| PT-CB-03 | WP-CB | PT-AC-44, PT-AC-47 | E-INT |
| PT-CB-04 | WP-CB | PT-AC-48, PT-AC-56 | E-INT, E-ORD |
| PT-CB-05 | WP-CB | PT-AC-62, PT-AC-63 | E-ORD |
| PT-CB-06 | WP-CB | PT-AC-49, PT-AC-47 | E-ORD, E-REV |
| PT-CB-07 | WP-CB | PT-AC-50 | E-ORD |
| PT-BAL-01 | WP-FUNDS | PT-AC-31, PT-AC-62, static-call trace | E-ORD |
| PT-BAL-02 | WP-FUNDS | PT-AC-59, PT-AC-60, PT-AC-61 | E-INT, E-REV |
| PT-BAL-03 | WP-FUNDS | PT-AC-52 | E-REV |
| PT-BAL-04 | WP-FUNDS | PT-AC-39 | E-REV |
| PT-BAL-05 | WP-FUNDS | PT-AC-52, PT-AC-53, PT-AC-65, `test_PT_GAS_forwarding` | E-REV |
| PT-BAL-06 | WP-FUNDS | PT-AC-14, PT-AC-59, PT-AC-65 | E-REV, E-ORD |
| PT-BAL-07 | WP-FUNDS | PT-AC-13, PT-AC-53. No allowlist function is added | E-PLAN, E-INT |
| PT-EVENT-01 | WP-SURFACE | PT-AC-57 | E-EVT |
| PT-EVENT-02 | WP-ENTRY, WP-EXIT | PT-AC-57, PT-AC-59, PT-AC-28 | E-EVT |
| PT-EVENT-03 | WP-ENTRY, WP-EXIT, WP-COMP | PT-AC-57 | E-EVT, E-ORD |
| PT-ERROR-01 | WP-SURFACE | `test_PT_ERROR_selectors` | E-REV |
| PT-ERROR-02 | WP-SURFACE | `test_PT_ERROR_precedence`, PT-AC-15 | E-REV, E-ORD |
| PT-ERROR-03 | WP-MATH, WP-FUNDS | PT-AC-55, PT-AC-52, PT-AC-61, compiler evidence in section 7.5 | E-REV |
| PT-ERROR-04 | WP-ENTRY, WP-EXIT, WP-COMP | PT-AC-54, PT-AC-20, PT-AC-25 | E-REV |
| PT-ABSENT-01 | WP-SURFACE | PT-AC-58, `test_PT_ABSENT_surface` | E-ABI |
| PT-ABSENT-02 | WP-PLAN | Section 2 rejects Crane, CREATE3, registry, armed callback, and fee-on-transfer bans as inherited work | E-PLAN |
| PT-AC-BASE | WP-HARNESS | Section 7.3 states premises and rollback. Passing tests later record execution; this row does not | E-PLAN |
| PT-AC-01 | WP-HARNESS | `test_PT_AC_01` | E-ABI, E-ORD |
| PT-AC-02 | WP-HARNESS | `test_PT_AC_02` | E-INT, E-ABI |
| PT-AC-03 | WP-HARNESS | `test_PT_AC_03` | E-REV |
| PT-AC-04 | WP-HARNESS | `test_PT_AC_04` | E-REV |
| PT-AC-05 | WP-HARNESS | `test_PT_AC_05` | E-INT, E-EVT, E-REV |
| PT-AC-06 | WP-HARNESS | `test_PT_AC_06` | E-INT, E-REV |
| PT-AC-07 | WP-HARNESS | `test_PT_AC_07` | E-ORD |
| PT-AC-08 | WP-HARNESS | `test_PT_AC_08` | E-INT, E-EVT |
| PT-AC-09 | WP-HARNESS | `test_PT_AC_09` | E-REV |
| PT-AC-10 | WP-HARNESS | `test_PT_AC_10` | E-INT, E-REV |
| PT-AC-11 | WP-HARNESS | `test_PT_AC_11` | E-INT |
| PT-AC-12 | WP-HARNESS | `test_PT_AC_12` | E-INT, E-ORD |
| PT-AC-13 | WP-HARNESS | `test_PT_AC_13` | E-INT, E-EVT, E-REV |
| PT-AC-14 | WP-HARNESS | `test_PT_AC_14` | E-ORD, E-REV |
| PT-AC-15 | WP-HARNESS | `test_PT_AC_15` | E-REV, E-ORD |
| PT-AC-16 | WP-HARNESS | `test_PT_AC_16` | E-INT, E-ORD |
| PT-AC-17 | WP-HARNESS | `test_PT_AC_17` | E-REV |
| PT-AC-18 | WP-HARNESS | `test_PT_AC_18` | E-REV, E-ORD |
| PT-AC-19 | WP-HARNESS | `test_PT_AC_19` | E-INT |
| PT-AC-20 | WP-HARNESS | `test_PT_AC_20` | E-REV |
| PT-AC-21 | WP-HARNESS | `test_PT_AC_21` | E-INT |
| PT-AC-22 | WP-HARNESS | `test_PT_AC_22` | E-REV |
| PT-AC-23 | WP-HARNESS | `test_PT_AC_23` | E-INT, E-EVT |
| PT-AC-24 | WP-HARNESS | `test_PT_AC_24` | E-INT, E-ORD |
| PT-AC-25 | WP-HARNESS | `test_PT_AC_25` | E-REV |
| PT-AC-26 | WP-HARNESS | `test_PT_AC_26` | E-REV |
| PT-AC-27 | WP-HARNESS | `test_PT_AC_27` | E-INT, E-ORD |
| PT-AC-28 | WP-HARNESS | `test_PT_AC_28` | E-REV, E-EVT |
| PT-AC-29 | WP-HARNESS | `test_PT_AC_29` | E-INT, E-ORD |
| PT-AC-30 | WP-HARNESS | `test_PT_AC_30` | E-INT |
| PT-AC-31 | WP-HARNESS | `test_PT_AC_31` | E-INT, E-ABI |
| PT-AC-32 | WP-HARNESS | `test_PT_AC_32` | E-INT |
| PT-AC-33 | WP-HARNESS | `test_PT_AC_33` | E-INT |
| PT-AC-34 | WP-HARNESS | `test_PT_AC_34` | E-ORD, E-INT |
| PT-AC-35 | WP-HARNESS | `test_PT_AC_35` | E-INT, E-EVT |
| PT-AC-36 | WP-HARNESS | `test_PT_AC_36` | E-ORD |
| PT-AC-37 | WP-HARNESS | `test_PT_AC_37` | E-INT |
| PT-AC-38 | WP-HARNESS | `test_PT_AC_38` | E-REV, E-INT |
| PT-AC-39 | WP-HARNESS | `test_PT_AC_39` | E-REV |
| PT-AC-40 | WP-HARNESS | `test_PT_AC_40` | E-ORD |
| PT-AC-41 | WP-HARNESS | `test_PT_AC_41` | E-ORD, E-INT |
| PT-AC-42 | WP-HARNESS | `test_PT_AC_42` | E-INT, E-ORD |
| PT-AC-43 | WP-HARNESS | `test_PT_AC_43` | E-EVT |
| PT-AC-44 | WP-HARNESS | `test_PT_AC_44` | E-INT, E-ORD |
| PT-AC-45 | WP-HARNESS | `test_PT_AC_45` | E-REV |
| PT-AC-46 | WP-HARNESS | `test_PT_AC_46` | E-REV, E-ABI |
| PT-AC-47 | WP-HARNESS | `test_PT_AC_47` | E-INT, E-REV |
| PT-AC-48 | WP-HARNESS | `test_PT_AC_48` | E-INT, E-ORD |
| PT-AC-49 | WP-HARNESS | `test_PT_AC_49` | E-ORD |
| PT-AC-50 | WP-HARNESS | `test_PT_AC_50` | E-ORD |
| PT-AC-51 | WP-HARNESS | `test_PT_AC_51` | E-REV |
| PT-AC-52 | WP-HARNESS | `test_PT_AC_52` | E-REV |
| PT-AC-53 | WP-HARNESS | `test_PT_AC_53` | E-INT, E-EVT |
| PT-AC-54 | WP-HARNESS | `test_PT_AC_54` | E-REV |
| PT-AC-55 | WP-HARNESS | `test_PT_AC_55` | E-INT, E-REV |
| PT-AC-56 | WP-HARNESS | `test_PT_AC_56` | E-REV, E-INT |
| PT-AC-57 | WP-HARNESS | `test_PT_AC_57` | E-EVT, E-ORD |
| PT-AC-58 | WP-HARNESS | `test_PT_AC_58` | E-ABI |
| PT-AC-59 | WP-HARNESS | `test_PT_AC_59` | E-INT, E-EVT, E-ORD |
| PT-AC-60 | WP-HARNESS | `test_PT_AC_60` | E-INT, E-EVT |
| PT-AC-61 | WP-HARNESS | `test_PT_AC_61` | E-REV |
| PT-AC-62 | WP-HARNESS | `test_PT_AC_62` | E-ORD |
| PT-AC-63 | WP-HARNESS | `test_PT_AC_63` | E-REV |
| PT-AC-64 | WP-HARNESS | `test_PT_AC_64` | E-ORD, E-EVT |
| PT-AC-65 | WP-HARNESS | `test_PT_AC_65` | E-REV |
| PT-AC-66 | WP-HARNESS | `test_PT_AC_66` | E-EVT, E-ORD |
| PT-AC-67 | WP-HARNESS | `test_PT_AC_67` | E-EVT, E-ORD |
| PT-AC-68 | WP-HARNESS | `test_PT_AC_68` | E-REV |
| PT-DEPENDS-01 | WP-HARNESS | Section 5.2. PT-AC-18 and PT-AC-36 observe the specified reads and no invented defaults | E-PLAN, E-ORD |
| PT-DEPENDS-02 | WP-HARNESS | Section 5.3. PT-AC-37 and PT-AC-38 bound what success and failure prove | E-PLAN |
| PT-DEPENDS-03 | WP-HARNESS | Section 5.1 and D-ABI. PT-AC-49 observes the specified calls. The double is not a manager engine | E-PLAN, E-ORD |
| PT-DEPENDS-04 | WP-PLAN, WP-HARNESS | Section 3. PT-AC-44 uses hook-altered fee deltas without a local hook allowlist | E-PLAN |
| PT-DEPENDS-05 | WP-PLAN | Section 3 unknowns. PT-AC-53 is conditional on the scripted token, not a live-currency guarantee | E-PLAN |
| PT-HANDOFF-01 | WP-PLAN | The PRD remains the only behavioral input. This plan is separate and non-normative. No requirement is silently changed | E-PLAN |
| PT-HANDOFF-02 | WP-PLAN | No implementation, test run, deployment, or legal determination is claimed here. Unknown external behavior stays in section 3 | E-PLAN |

## 9. Later evidence index

When implementation and tests are separately authorized, add an evidence index next to the test results. It is not a second PRD. It must contain:

- Compiler version and the D-SOLC comparison.
- Pinned public manager-interface commit, or an explicit statement that only the local harness was tested.
- Every `test_PT_AC_01` through `test_PT_AC_68` result.
- The additional tests in section 7.4.
- The static-call trace excerpt.
- Unresolved mismatches. A partial run is not complete equivalence.
- Deviations: none, unless a later product decision names the superseded requirement.

A coverage script must extract tagged IDs from the PRD and fail if any ID is absent from section 8. Group abbreviations in scenario tables, such as `PT-API` without a number, are not extra IDs.

## 10. Stop conditions

This plan is complete as a planning document when every tagged requirement and acceptance ID appears in section 8 and the decisions in section 3 are explicit.

Implementation is not started by this file. Factory-clone parity, whole-system manager equivalence, hook safety, token safety, and legal clearance remain blocked. Do not fill those blocks from target source.
