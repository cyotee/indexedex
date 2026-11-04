Ask: Act only as MiniMax’s independent council member on the exact requested model route and produce the complete Weir implementation/testing-plan contribution - wanted: complete WI/AC coverage in the designated response file. For you: active `apply_patch` was unavailable, so the brief’s explicit fallback applies. No project file was changed. The complete contribution follows inline.

# MiniMax independent implementation and testing plan: Weir source import

## 1. Independent position, authority, and limits

This is MiniMax's independent, implementer-facing plan contribution for the frozen Weir baseline-copy stage. It is a plan, not implementation authorization, a second PRD, a compiler-success claim, an economic-safety claim, or legal clearance.

I read the complete `brief.md`, the complete frozen `inputs/PRD.md`, all three complete frozen domain sources, the admitted repository guidance, and the relevant current Crane/V4 test patterns. I did not read peer originals, delegate, run a project command, build, test, query an RPC, inspect Git, or verify deployment/license claims beyond the supplied evidence.

Labels used below:

- **SOURCE OBSERVATION** means directly observed in the admitted frozen source or current repository file named in the row.
- **SUPPLIED EVIDENCE** means a fact supplied by the frozen PRD/brief and not independently re-attested here.
- **PROPOSED** means a future name, file, helper, test, command, or sequencing decision recommended by this plan.
- **UNVERIFIED GATE** means a future proof that was not run in this assignment.

### Authority and decisions

1. **Authority order.** The frozen owner-clarified PRD revision `weir-import-prd-owner-clarifications-20261029`, its three pinned source files, the brief's settled owner requirements, and the repository rules control. Generic Crane wrapper, facet, ERC-20/ERC-4626, preview-equals-execute, profile, and cache-clearing examples do not apply to this standalone source import.
2. **Scope.** Import exactly the three domain files to the requested destination; prove faithful behavior with a real canonical PoolManager; preserve source limitations; record unresolved release gates.
3. **Exclusions.** No ERC-20/ERC-4626, NAV issuance, Rate Provider, SE/Diamond/registry wiring, factory product, strict single-output exit, hook-only path, economic repair, extra guard, rescue/sweep method, strict swap consumption, share-cap change, native-sync repair, or dependency/config rewrite.
4. **Dependency decision.** Use the versioned `@crane/contracts/external/openzeppelin-contracts-v5/` family and canonical `@crane/contracts/protocols/dexes/uniswap/v4/` surfaces already selected by the PRD. Keep the frozen Weir GPL `LiquidityAmounts`; do not substitute the canonical namesake. Make only the PRD's 22 import rewrites, the five free-struct qualifications, and any separately recorded WI-06 compilation-only scope/memory-struct changes.
5. **Test-system decision.** Deploy the real canonical `PoolManager` through Crane's CREATE3 artifact-loading route and the actual standalone Weir as the protocol-port SUT in `TestBase_WeirVaults`. No manager mock, Weir replacement, `vm.mockCall`, SUT inheritance, etching, storage injection, or fabricated manager delta is acceptable.
6. **Evidence separation.** Compiler success, hermetic behavior proof, actual local fork parity, hostile characterization, and release/license clearance are five separate gates. Passing one is not a substitute for another.

### Unverified gates at the end of this assignment

| Gate | Current status | Required future proof |
|---|---|---|
| Import compilation | UNVERIFIED GATE | Default-profile build succeeds without config/viaIR changes, or the exact compiler blocker is recorded. |
| Exact source transform | UNVERIFIED GATE | Machine comparison proves only the allowlisted import/type/WI-06 changes and records original/adjusted hashes. |
| ABI/storage/dependency behavior | UNVERIFIED GATE | Compiled ABI matches the manifest; inherited layout and every used canonical dependency surface match the frozen behavior. |
| Hermetic money-path proof | UNVERIFIED GATE | Real-manager tests execute every reachable AC with exact assertions. |
| Local chain-4663 parity | BLOCKED here | Archive-capable RPC state and the configured Alchemy key are unavailable in this process; a missing state/credential is NOT RUN, never pass. |
| Upstream suite/audit equivalence | UNVERIFIED GATE | The frozen corpus contains no upstream Git pin, tests, or audit; no claim of upstream-suite or audit parity is permitted. |
| BUSL/version/legal disposition | UNVERIFIED GATE | Full declarations, version-to-declaration provenance, Additional Use Grant applicability, and release policy are resolved by an authorized owner. |
| Adversarial reachability | UNVERIFIED GATE | Each branch is either executed on the real manager or recorded as a precise reachability gap without fabricating state. |

## 2. Proposed future file inventory

Paths marked **PROPOSED** do not exist merely because this plan names them. Existing paths are current repository observations and should be reused where listed.

### Production and provenance

| Path | Status | Single purpose / edit boundary |
|---|---|---|
| `contracts/protocols/strategy/weir/WeirVaults.sol` | PROPOSED destination; source exists in the frozen corpus | Faithful domain import with only PRD-authorized transformations. |
| `contracts/protocols/strategy/weir/base/WeirBase.sol` | PROPOSED destination; source exists in the frozen corpus | Faithful base import; no payment/ownership redesign. |
| `contracts/protocols/strategy/weir/libraries/LiquidityAmounts.sol` | PROPOSED destination; source exists in the frozen corpus | Frozen GPL Weir library; never replace by name with the canonical library. |
| `contracts/protocols/strategy/weir/VENDOR.md` | PROPOSED | Frozen 39-file inventory, full applicable declarations, upstream/version evidence, deployment provenance, import policy, transformations, compiler differences, and unresolved gates. |
| `contracts/protocols/strategy/weir/import-manifest.json` | PROPOSED machine artifact | Original/adjusted hashes, exact 22 import rewrites, five type qualifications, every WI-06 hunk and diagnostic, original-to-local map, and machine-comparison inputs. It must not contain prose-only “approval.” |
| `contracts/protocols/strategy/weir/VERIFICATION.md` | PROPOSED release ledger | AC/WI evidence index, exact commands and results, fork status, license status, and unresolved risks. It records evidence; it does not convert a gap into approval. |

### Test support

| Path | Status | Single purpose / edit boundary |
|---|---|---|
| `contracts/protocols/strategy/weir/test/bases/TestBase_WeirVaults.sol` | PROPOSED | Owns the real manager/SUT, sorted pools, actors, token funding, and fixture reset. This is the sole owner of shared fixture APIs. |
| `contracts/protocols/strategy/weir/test/behaviors/Behavior_WeirVaults.sol` | PROPOSED | Exact surface/behavior helpers over the concrete `WeirVaults`; no duplicate public interface and no ERC-20 surface. |
| `contracts/protocols/strategy/weir/test/observers/WeirStateObserver.sol` | PROPOSED | Read-only snapshot of vault ledger, idle, total/assigned shares, Weir salt-zero position, manager unlock/deltas, physical balances, and unassigned receipts. It never injects state. |
| `contracts/protocols/strategy/weir/test/routers/WeirAuxiliaryRouter.sol` | PROPOSED | Real `IUnlockCallback` router for exact settlement, donations, seeding liquidity, swaps, nested unlock, stale sync, and caught-versus-bubbled failures. |
| `contracts/protocols/strategy/weir/test/hooks/WeirObservationHook.sol` | PROPOSED | Valid mined hook address; records applicable manager/hook calls, `hookData`, caller, owner, parameters, and event order. |
| `contracts/protocols/strategy/weir/test/hooks/WeirReturnDeltaHook.sol` | PROPOSED | Separate valid mined hook with return-delta permission; returns a chosen delta and settles the hook's real manager debt. |
| `contracts/protocols/strategy/weir/test/tokens/WeirHostileReturnToken.sol` | PROPOSED | Peripheral-only false/no-return/explicit-revert/short-delivery/callback modes. It is not the SUT. |
| `contracts/protocols/strategy/weir/test/receivers/WeirCallbackReceiver.sol` | PROPOSED | Role-configurable token/hook/treasury/payer/output-recipient callback target with exact caller and intermediate-view recording. |
| `contracts/protocols/strategy/weir/test/receivers/WeirRejectingReceiver.sol` | PROPOSED | Native/ERC-20 rejection fixtures with explicit or empty revert data. |
| `contracts/protocols/strategy/weir/test/handlers/WeirVaultsHandler.sol` | PROPOSED | Deterministic supported-domain state machine for AC63; keeps exact expected ledger and classifies outcomes. |
| `contracts/protocols/strategy/weir/test/oracles/WeirIndependentOracle.sol` | PROPOSED | Full-width, stage-preserving integer oracle; must not import Weir `LiquidityAmounts` or call `previewRedeem`. |
| `test/foundry/spec/protocols/strategy/weir/fixtures/weir_swap_vectors.json` | PROPOSED | Independently derived exact tick traversal/rounding vectors with provenance, not a copied production output. |
| `scripts/verify-weir-source-import.py` | PROPOSED | Deterministic transform/ABI verifier; it is a fidelity gate, not a prose/hash-copy unit test. |
| `scripts/test_verify_weir_source_import.py` | PROPOSED | Unit tests for the verifier's allowlist behavior and rejection of unlisted edits. |

### Hermetic and fork specs

| Path | Status | Primary coverage |
|---|---|---|
| `test/foundry/spec/protocols/strategy/weir/WeirVaultsSurface.t.sol` | PROPOSED | AC01-08, AC10-11, AC26-27, AC46, AC52-53, AC62, AC68-69 as noted below. |
| `test/foundry/spec/protocols/strategy/weir/LiquidityAmounts.t.sol` | PROPOSED | AC39, AC42-47 library portions. |
| `test/foundry/spec/protocols/strategy/weir/WeirVaultsDepositTransfer.t.sol` | PROPOSED | AC09-20, AC36, AC48-49, AC54-56. |
| `test/foundry/spec/protocols/strategy/weir/WeirVaultsWithdrawCompound.t.sol` | PROPOSED | AC21-35, AC37, AC57, AC59-61, AC67. |
| `test/foundry/spec/protocols/strategy/weir/WeirVaultsViews.t.sol` | PROPOSED | AC08, AC38-41, AC46. |
| `test/foundry/spec/protocols/strategy/weir/WeirVaultsInvariant.t.sol` | PROPOSED | AC63-64. |
| `test/foundry/fork/protocols/strategy/weir/WeirVaultsForkParity.t.sol` | PROPOSED | AC65 only; local fork profile, no live write. |

### Verified existing dependencies and patterns

The following current paths are verified existing and may be consumed without copying a second dependency tree:

- Canonical V4 manager/interface/types/libraries: `lib/crane/contracts/protocols/dexes/uniswap/v4/{PoolManager.sol,interfaces/IPoolManager.sol,types/PoolOperation.sol,types/PoolKey.sol,types/PoolId.sol,types/Currency.sol,types/BalanceDelta.sol,libraries/StateLibrary.sol,libraries/Position.sol,libraries/TickMath.sol,interfaces/callback/IUnlockCallback.sol}` plus the common Uniswap `FullMath`, `FixedPoint96`, and `FixedPoint128` libraries.
- Versioned OZ V5 family: `lib/crane/contracts/external/openzeppelin-contracts-v5/`.
- `lib/crane/contracts/test/CraneTest.sol`, `contracts/utils/foundry/ArtifactCreationCode.sol`, `contracts/test/stubs/SimpleMintableERC20.sol`, `lib/crane/contracts/protocols/dexes/uniswap/v4/hooks/public/base/BaseHook.sol`, and `lib/crane/contracts/protocols/dexes/uniswap/v4/hooks/public/utils/HookMiner.sol`.
- `contracts/test/bases/TestBase_UniswapV4WingsSeSurface.sol` and `contracts/test/bases/TestBase_UniswapV4MultiPoolTwapOracle.sol` are verified examples of deploying the canonical PoolManager through Crane CREATE3 and of a real unlock harness. They are read-only references, not dependencies: do not import their DETF/SE/oracle product wiring.
- `lib/crane/contracts/protocols/dexes/uniswap/v4/hooks/public/dependencies/v4-core/test/{PoolSwapTest.sol,PoolModifyLiquidityTest.sol,utils/CurrencySettler.sol}` are read-only settlement-pattern references. Do not silently copy unlicensed helper source into the Weir test tree.

Do not restore retired V4/FullSpread families or infer authority from the historical Ethereum-mainnet fork fixture.

## 3. Ordered work packages

### WP1 — Freeze provenance and perform the mechanical import

- **Depends on:** WP0 (authority/scope lock).
- **Allowed paths:** the three production files, `VENDOR.md`, `import-manifest.json`, `scripts/verify-weir-source-import.py`, and its Python unit test.
- **Single-owner interface:** the import-manifest owner is the only editor of the transform allowlist and adjusted hashes.
- **Steps:**
  1. Copy the three frozen source bodies to the three requested destinations without a semantic rewrite.
  2. Apply exactly the PRD's 22 import rewrites: 15 in `WeirVaults.sol`, five in `WeirBase.sol`, and two in `LiquidityAmounts.sol`; the two relative Weir imports remain textually unchanged.
  3. Import `ModifyLiquidityParams` and `SwapParams` as free types from canonical `types/PoolOperation.sol`; replace only the five obsolete qualifications at W lines 264, 292, 323, 349, and 397.
  4. Keep the frozen GPL header and body of Weir `LiquidityAmounts`; route only its two dependencies to canonical Uniswap libraries.
  5. Build with solc 0.8.35, optimizer runs 1, `viaIR=false`. If compilation fails only because of lexical scope/stack depth, apply explicit block scopes or internal memory structs. Record the original diagnostic, exact hunk, and semantic equivalence argument. Do not change persistent storage, public ABI, arithmetic order, casts, calls, fees, recipients, events, errors, or notices.
  6. Generate `import-manifest.json` from the actual transform, including original SHA-256, adjusted SHA-256, all 22 import rows, five qualification rows, each WI-06 hunk, and compiler diagnostics.
- **Outputs:** three imports, VENDOR/transform evidence, verifier.
- **Exit evidence:** `python3 scripts/verify-weir-source-import.py --import-manifest contracts/protocols/strategy/weir/import-manifest.json --abi out/WeirVaults.sol/WeirVaults.json --check` succeeds; the diff contains no unlisted hunk. A compile failure is a reported blocker, never a green claim.
- **Parallelism:** prose/license transcription may proceed beside code import only if the manifest owner reconciles hashes; source edits are single-writer.

### WP2 — Prove dependency, ABI, layout, and failure compatibility

- **Depends on:** WP1.
- **Allowed paths:** test-only compatibility spec and the import manifest; no canonical dependency edit unless the owner opens a separate decision.
- **Single-owner interface:** the compatibility spec owns the canonical used-surface checklist consumed by every later test lane.
- **Steps:**
  1. Compare compiled ABI to the frozen manifest: exactly 27 function entries, constructor, payable receive, 11 events, and 18 listed errors; verify tuple field order, mutability, outputs, and event indexing.
  2. Capture compiled storage layout for `Ownable2Step`/`Ownable`, `Pausable`, `ReentrancyGuard`, and Weir state in inheritance order. Prove there is no mixed Context/Ownable family and no namespaced storage shift.
  3. Prove the canonical `PoolOperation` structs have the same field order/types/ABI as the frozen nested structs and that the five changed qualifications select the same external selectors.
  4. Prove canonical `StateLibrary`/`Position` reads the actual manager's pool, tick, position, and fee-growth state. Do not certify from `POOLS_SLOT` or visible offsets alone; compare position key, signed tick encoding, hash function, and live `extsload` results.
  5. Prove used `FullMath` overflow/empty-revert behavior, `FixedPoint96/128` constants, `TickMath` extrema/rounding, `Currency` transfer errors, and `BalanceDelta` int128 semantics.
  6. Prove the selected OZ files retain the six byte-identical frozen bodies stated by the PRD and that the selected SafeERC20 `safeTransfer`, `safeTransferFrom`, and `_callOptionalReturn` paths preserve typed failures and no-return acceptance.
- **Exit evidence:** machine ABI/layout artifacts plus exact behavior tests. Any observable canonical mismatch stops at a separate owner decision; do not “fix” Weir to match it.
- **Parallelism:** ABI, storage, OZ, and V4-used-surface checks may run in parallel after the compiled artifact exists.

### WP3 — Establish the real-manager TestBase and observation fixtures

- **Depends on:** WP2.
- **Allowed paths:** `contracts/protocols/strategy/weir/test/**` except the oracle/handler surfaces owned by WP4/WP7.
- **Single-owner interface:** `TestBase_WeirVaults` owns fixture reset and exposes only stable helpers such as `_initPool`, `_fund`, `_deposit`, `_donate`, `_withdraw`, `_readVaultState`, and `_assertUnlockedSettled`.
- **Steps:**
  1. `TestBase_WeirVaults` inherits `CraneTest`; call `CraneTest.setUp()` first and retain its normal factory bootstrap.
  2. Deploy the canonical `PoolManager` with the verified route `create3Factory.create3WithArgs(ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"), abi.encode(address(this)), salt)`. This avoids `new` for the shared Crane manager and keeps artifact use explicit.
  3. Deploy the actual standalone `WeirVaults` directly in the TestBase under the brief's explicit protocol-port exception. Do not invent a Weir factory, proxy, DFPkg, registry, or manager.
  4. Use `SimpleMintableERC20` for ordinary exact-transfer ERC-20 currencies and address zero for native. Sort currencies before every key; initialize hookless fee-zero tick-spacing-1 pools at `Q = 2^96` for F0-F3.
  5. Build `WeirAuxiliaryRouter` as a real `IUnlockCallback`: it must settle exact ERC-20 debt with `sync`/transfer/`settle`, settle native debt with value, seed liquidity, donate, swap, deliberately retain a non-native sync, and catch or bubble nested failures.
  6. Build separately permissioned observation and return-delta hooks at valid mined addresses. Use `HookMiner.find` with exact flag bits and `BaseHook`; never etch a hook to a fake address.
  7. Build peripheral hostile token/receiver fixtures only outside the SUT. Give each callback actor an explicit caller identity and role rather than impersonating an arbitrary account.
  8. Subscribe with `vm.expectEmit`, `vm.expectCall`, and `vm.recordLogs` before triggers. `WeirStateObserver` reads only real state and manager deltas.
- **Exit evidence:** a smoke test proves parent setup ran, manager code exists, Weir binds that manager, a sorted pool initializes, F0 deposits, the Weir-owned salt-zero position is created, and the manager is relocked with zero deltas after the top-level call.
- **Parallelism:** router, receiver/token, and hook helpers may be developed in parallel, but their public interfaces are frozen by the TestBase owner before downstream suites use them.

### WP4 — Build the independent oracle and arithmetic/static suites

- **Depends on:** WP3.
- **Allowed paths:** oracle/helper files, `LiquidityAmounts.t.sol`, `WeirVaultsSurface.t.sol`, and the swap-vector fixture.
- **Single-owner interface:** the oracle owner supplies exact expected values to all other test lanes.
- **Rules:** no import of Weir `LiquidityAmounts`; no call to `previewRedeem`; no use of the production helper as its own oracle; preserve nested floors, `int128`/`uint128`/`int256` distinctions, checked overflow/underflow, explicit narrowing, and final division stage.
- **Anchor vectors to implement exactly:**

| Vector | Independent construction | Exact expected anchor |
|---|---|---|
| F0 | Fresh hookless fee-zero pool at `Q`, tick spacing 1, exact-transfer ERC-20 pair; deposit `2^20+2` each without zap. | `L=K=1,048,576`; `T=K`; recipient `K-1,000=1,047,576`; manager costs `K` each; refunds `2` each; idle `(0,0)`. Full assigned-share withdrawal returns `1,047,575` each and leaves `L=T=1,000`. |
| F1 | F0, then a real unlocked-router `donate(key,20,0,hookData)` with exact donor settlement, then compound. | gross `(20,0)`, cut `(1,0)`, idle0 `19`, added liquidity `0`, unchanged `L`, `Compounded(id,20,0,0)`; second compound has no event and leaves idle0 `19`. |
| F2 | F1 post-state, then donate exactly 20 currency1 and compound. | gross `(0,20)`, cut `(0,1)`, candidate `(19,19)`, cushioned `(17,17)`, added `17`, idle `(2,2)`, `T` unchanged, `Compounded(id,0,20,17)`. |
| F3 | F1 post-state, then a second user deposits `K+2` of both without zap. | second user receives `K`; `L=T=2K`; idle0 stays `19`; second user's proportional idle0 claim is `floor(19/2)=9`. This characterizes dilution, not NAV fairness. |

- **Swap oracle:** commit exact input, pre-swap tick/sqrt price, next tick, liquidity consumed, fee amount, output, and post-swap tick/sqrt price for each fixture. Derive these independently or record the independent derivation; never capture them from the SUT and bless the result.
- **Exit evidence:** explicit AC42-AC47 vectors and boundary tests, plus a fixed seed and reduced numeric domain so every rejected case is understood. Fuzzing may widen domains only after the boundary vector passes.

### WP5 — Implement the ordinary lifecycle and accounting suites

- **Depends on:** WP4.
- **Allowed paths:** deposit/transfer, withdraw/compound, inventory, and views specs.
- **Steps:** implement AC09-AC18, AC21-AC41, and AC46 in isolated fixtures first; assert every affected balance, ledger, position, timestamp, manager delta, return, and event. Keep principal, fees, hook deltas, idle, refunds, and unassigned receipts in separate ghost accounts.
- **Exit evidence:** focused real-manager tests pass with exact values and exact error selectors. No assertion relies only on “changed,” a tolerance, or a preview call.

### WP6 — Implement callback, native, access, reentrancy, and hostile characterization suites

- **Depends on:** WP5.
- **Allowed paths:** access/callback/native/hostile specs and narrowly scoped receiver/token/hook helpers.
- **Steps:** implement AC19-AC20, AC26-AC27, AC48-AC62, and the conditional branches of AC23, AC25, AC33, AC50, AC51, AC57, AC60, and AC67. Keep supported-domain and hostile expectations in separate test methods.
- **Exit evidence:** every reached branch has an exact error or accounting trace; every unreachable branch has a precise gap statement tied to the attempted real-manager construction.

### WP7 — Run deterministic supported and hostile campaigns

- **Depends on:** WP5 and WP6.
- **Allowed paths:** handler and invariant specs.
- **Single-owner interface:** the handler owner maintains the ghost ledger and action classification used by both campaigns.
- **Supported campaign:** at least three users, two pools sharing one currency, exact-transfer non-rebasing tokens, both directions, native/ERC-20 paths, donations, transfers, compounds, pauses, and owner transitions. The campaign must contain successful state-changing actions, not only rejected calls.
- **Hostile campaign:** callbacks, rejecting receivers, short delivery, return deltas, partial fills, pause/owner changes. It records exact characterized outcomes; it does not reuse supported-domain invariants.
- **Exit evidence:** fixed seed, run/depth settings, successful/rejected action counts, expected revert classes, scenario-to-AC trace, and smallest failing sequence for any failure.

### WP8 — Build the local chain-4663 parity harness

- **Depends on:** WP1-WP3; it may run in parallel with WP5-WP7 after the base fixture interfaces freeze.
- **Allowed paths:** `test/foundry/fork/protocols/strategy/weir/**` and a fork-only base under the same test tree.
- **Exit evidence:** exact return/revert/event and mapped balance/position comparisons for reference and copy branches, or an honest BLOCKED/NOT RUN record.

### WP9 — Run the exact validation sequence and publish the evidence ledger

- **Depends on:** WP1-WP8 as applicable.
- **Allowed paths:** generated `out/`/`cache_forge/`, `VERIFICATION.md`, and the evidence rows in the manifest. Do not change compiler/profile settings to make a gate pass.
- **Artifact writers:** serialize all Forge commands that can write `out/` or `cache_forge/`. Parallel test authoring is allowed; parallel artifact writers are not.
- **Exit evidence:** the exact commands below, their exit status, focused and broader results, separate fork status, license status, and AC66 ledger.

## 4. Concrete callback, hook, and role design

### Real operation sequences

1. **Deposit:** `deposit` modifier order is pause -> nonReentrant -> deadline; body validates recipient, may create the ledger vault, checks native value, pulls currency0 then currency1, and calls `poolManager.unlock`. The manager calls `Weir.unlockCallback` as the unlock owner. The callback first compounds, then performs the deposit action. A zap swap precedes liquidity sizing; add-liquidity returns the first caller delta used for settlement. After the manager callback closes, the recipient receives shares and the payer receives refunds.
2. **Withdrawal:** the caller's shares are debited before `unlock`; the callback first compounds, then removes liquidity, pays idle into the manager, optionally swaps, settles final deltas, and returns positive outputs. The caller—not the recipient—is the `Withdrawn.user`. Minima are checked after settlement.
3. **Compound:** `compound` opens the manager unlock; the callback first records `lastCompound`, pokes a nonzero position with zero liquidity delta, takes currency0 then currency1 cuts to the treasury addresses read at those call sites, optionally adds liquidity, updates idle, settles, and emits only if a positive fee component was harvested.
4. **Create vault:** `createVault` only reads slot0 and writes the Weir ledger. It never calls a pool hook and never creates a per-pool contract.

### Hook contracts and observations

- **PROPOSED `WeirObservationHook`:** valid flags for the exact applicable observations, such as after-add, after-remove, after-swap, and donate. Each callback records `msg.sender == manager`, the `sender` supplied by the manager, Weir address, `PoolKey`, parameters, and the exact `hookData` bytes. The hook returns the correct selector and never mutates deltas.
- **PROPOSED `WeirReturnDeltaHook`:** separate address with the relevant return-delta flag. It returns a deliberately chosen signed component and then settles the hook's own real manager debt before the unlock closes. The test distinguishes the manager's first `callerDelta` from the second informational `feesAccrued`: Weir uses the first return for net settlement. If Weir leaves a negative component unsettled, the real manager must produce `CurrencyNotSettled`; the test records that source outcome rather than repairing it.
- **Zero-delta operations:** a zero-liquidity poke is conditional on nonzero stored liquidity; a zero calculated reinvestment is conditional on the two-unit cushion branch; an add/remove/swap operation occurs only when its source condition is reached. `createVault` has no hook callback. Tests assert actual applicable hook calls, not an invented “dedicated poke hook.”
- **Reverting hook:** the expected error is the canonical manager's wrapped hook error with the hook's original revert data. The rollback boundary is the real failed manager/Weir call subtree.

### Callback actors and authority

| Actor | Actual role | Required assertions |
|---|---|---|
| `WeirCallbackReceiver` as token | ERC-20 transfer source/callback | Caller is the token; any guarded Weir reentry sees the token as `msg.sender`; share transfer can move only the token caller's shares. |
| `WeirCallbackReceiver` as hook | Hook callback | Caller is the manager; supplied hookData and parameters are exact; actual Weir is the manager's `sender` argument. |
| `WeirCallbackReceiver` as treasury | Native treasury/current owner | First currency cut reaches the old treasury; a setter called by the current owner can change treasury before the second cut, so the second cut reaches the new treasury. If the outer call later fails, the setter and both cuts roll back together. |
| `WeirCallbackReceiver` as output recipient | Withdrawal recipient | It observes the caller's share debit and intermediate vault state; it cannot see a false end-of-transaction invariant. |
| `WeirCallbackReceiver` as payer | Native payer/refund recipient | A nonzero native refund invokes it after the share credit; rejecting it yields `NativeTransferFailed`; zero refund makes no call. |
| Auxiliary router | Independent unlock owner | Calling Weir while the router owns the unlock reaches `AlreadyUnlocked`; a caught failure does not close the router's unlock. |
| Outsider | Non-manager callback caller | `NotPoolManager()` occurs before malformed-data decoding. |

### Native stale-sync and nested-unlock sequences

- **Stale non-native sync:** an auxiliary router syncs an ERC-20 currency, then invokes a real Weir path that must pay native currency from idle. Because Weir does not sync native, the canonical manager can reject with `NonzeroNativeValue`. Test both a caught inner failure (earlier outer router effects can persist until the outer owner settles/closes) and an uncaught failure (the enclosing transaction rolls back). Do not add `sync(address(0))`.
- **Nested unlock:** while the auxiliary router owns the real manager unlock, call ordinary Weir `compound`; the manager rejects with `AlreadyUnlocked` before Weir's callback. This is distinct from reentering a guarded Weir method while Weir itself owns the unlock.
- **Guard order:** paused deposit fails `EnforcedPause` before reentrancy; an active guarded reentry reaches `ReentrancyGuardReentrantCall`; `createVault`, `transferShares`, views, and owner methods are not assumed guarded.

## 5. Independent accounting and reconciliation rules

Use a per-currency ghost ledger with these buckets:

1. assigned user balances;
2. treasury receipts;
3. recorded idle by vault;
4. independently tracked unassigned physical receipts: direct donations, self-treasury cuts delivered to Weir, self-recipient withdrawals delivered to Weir, and any deliberately documented test receipt;
5. manager position assets, tracked separately from Weir-held physical assets.

For each supported-domain currency after a successful top-level completion outside callbacks:

- `physicalBalance(Weir,c) = sum(recordedIdle_c by vault) + unassignedReceipts_c`;
- the Weir salt-zero position liquidity equals the selected vault's recorded liquidity;
- before genesis, assigned shares and `totalShares` are zero; after genesis, `sum(sharesOf[v,*]) = totalShares - 1,000`;
- the manager is relocked and `currencyDelta(Weir,c) == 0` for every currency used by the completed unlock;
- all recipients, including Weir itself, are included in the ledger.

This equality is limited to exact-transfer, non-rebasing supported inputs after successful top-level completion. Do not apply it to the hostile wrapped-idle case, a short-delivery token, a caught mid-unlock state, or a manager position asset. Never assert universal `idle <= 2`, zero unwanted output, nonnegative cast safety, NAV fairness, or one-token completion.

## 6. Rollback and event-proof discipline

- Use `vm.snapshotState()` before the exact failed invocation and `vm.revertToState()` only to continue after assertions; the current forge-std API exposes both.
- For a direct Weir failure, assert the snapshot-equivalent state after failure: vault existence, shares, liquidity, idle, `lastCompound`, token/native balances, allowances, treasury receipts, recipient balances, and manager position/deltas.
- Subscribe with `vm.recordLogs()` before the trigger. Reverted inner logs must not survive. A caught inner failure may coexist with successful outer-router logs; an uncaught failure removes the whole transaction's logs.
- Debug traces and captured console logs are diagnostic evidence only. Receipt/log survival requires the actual log collection or a fork receipt assertion.
- Never move a minimum check earlier or catch a revert to manufacture a clean state; preserve source validation and call order.

## 7. Local fork parity recipe

1. Use only `FOUNDRY_PROFILE=fork` and the existing `robinhood_mainnet_alchemy` alias through `vm.rpcUrl("robinhood_mainnet_alchemy")` with `ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK`. Do not add `WEIR_RPC_URL`, a second Weir block constant, or a substitute chain.
2. Preflight `ALCHEMY_KEY` presence and archive access. If absent or historical code is unavailable, record the fork test NOT RUN/BLOCKED; never skip it as a pass.
3. On the fork, assert chain ID 4663, block number 76,197,114, supplied block hash, non-empty code at reference Weir `0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110`, non-empty code at manager `0x8366a39CC670B4001A1121B8F6A443A643e40951`, and the reference Weir's `poolManager()` getter equals the manager.
4. Use a fresh selected hookless pool and fresh exact-transfer peripheral tokens where feasible. Confirm the selected PoolId is absent from the reference Weir before the sequence. Initialize the pool locally on the forked manager; deploy the local copy of Weir against the same manager.
5. Align local actor roles to the supplied reference owner/treasury `0x3234DEA52cc05cba7830B5305151C50AD34e9018` through local impersonation only. No production private key is needed or permitted.
6. Create equivalent base state, then `uint256 referenceSnapshot = vm.snapshotState();`. Run the reference branch, capture exact returns/reverts/events and before/after mapped state. Revert with `vm.revertToState(referenceSnapshot)`, create a new snapshot, and run the copy branch from the same base.
7. Compare the mapped pool aggregate and selected deltas, reference Weir position owner `0x9bb6...` versus copy Weir position owner, branch-local `allVaults` entry, recipient balances, and treasury receipts. Do not assume global `allVaults` prefixes or unrelated positions are equal.
8. A reference role/setup mismatch is a precise blocked parity action, not permission to use a production key, inject storage, or weaken equivalence.

## 8. Exact future validation commands

Run from the repository root. These are proposed future commands from the frozen PRD/`ARTIFACT_BUILDS.md`; they were not run here.

```bash
# Transform/import verifier after its manifest exists
python3 scripts/verify-weir-source-import.py \
  --import-manifest contracts/protocols/strategy/weir/import-manifest.json \
  --abi out/WeirVaults.sol/WeirVaults.json \
  --check

# Compile-only refresh before the focused test workflow exists
python3 scripts/forge-artifacts.py build \
  contracts/protocols/strategy/weir/WeirVaults.sol

# Focused build-before-test workflow
python3 scripts/forge-artifacts.py test \
  contracts/protocols/strategy/weir/WeirVaults.sol \
  --test-root test/foundry/spec/protocols/strategy/weir

# Focused hermetic execution after the artifact helper succeeds
forge test --match-path 'test/foundry/spec/protocols/strategy/weir/**' -vvv

# Broader release gates
forge build
forge test

# Local-only fork profile
FOUNDRY_PROFILE=fork forge build
FOUNDRY_PROFILE=fork forge test \
  --match-path 'test/foundry/fork/protocols/strategy/weir/**' -vvv
```

For several focused files, repeat `--test-root` on the single `forge-artifacts.py test` invocation, as documented by `ARTIFACT_BUILDS.md`; do not run concurrent writers to `out/` or `cache_forge/`. Seed a new worktree from warm `out/` and `cache_forge/`; never delete either directory, change `FOUNDRY_TEST`, add a profile, or enable viaIR. The existing `fmt.skip` warning is unrelated and must not be “fixed” in this workstream.

The release ledger must report these outcomes separately:

1. compiler/import resolution;
2. source-transform and ABI/layout fidelity;
3. hermetic real-manager behavior;
4. actual local fork parity;
5. hostile characterization;
6. license and release clearance.

## 9. Complete WI01-WI37 traceability

| WI | Planned work package / artifact | Required future evidence |
|---|---|---|
| WI-01 | WP1; exact three destination paths | Machine path/import check; no second production tree; frozen references remain outside production compilation. |
| WI-02 | WP1 transform verifier and manifest | Only allowlisted changes; notices/comments/business logic retained; adjusted diff review. |
| WI-03 | WP1 `VENDOR.md`, `import-manifest.json`, WP9 `VERIFICATION.md` | All 39 entries, hashes, mappings, transformations, diagnostics, licenses, deployment provenance, alias, and missing upstream evidence. |
| WI-04 | WP2 dependency/ABI/layout gate | Used-surface proof for OZ/V4/types/math/state; no private dependency tree or config change. |
| WI-05 | WP1 provenance plus WP9 release disposition | Full GPL/AGPL/BUSL inventory and unresolved version/grant/production-use gates; no automatic clearance. |
| WI-06 | WP1 compiler-refactor ledger | Exact diagnostics and lexical-scope/memory-struct diffs; business/ABI/storage equivalence; viaIR remains false. |
| WI-07 | WP0 scope lock and WP9 exclusions | No new product behavior or economic/security repair; exclusions reviewed against the diff. |
| WI-08 | WP3 pool fixture; WP5 lifecycle create tests | Distinct PoolIds, usable ticks, one array append, exact event, Weir-owned salt-zero position. |
| WI-09 | WP2 ABI/layout; WP5 ledger assertions | Exact ordered structs/enums and independent share/idle mappings. |
| WI-10 | WP2/WP4 surface suite | Exactly the baseline ABI; no invented ERC-20/4626 or manager validation. |
| WI-11 | WP3 router/hook; WP6 callback suite | Manager-only callback, compound-first ordering, unchanged hookData, real nested-unlock error. |
| WI-12 | WP5 deposit suite | Modifier/body order, payer pulls, recipient credit, manager credit attribution, refunds, event user. |
| WI-13 | WP4 oracle; WP5 genesis suite | Frozen liquidity sizing, `ZeroShares`, reserve shares assigned to no address. |
| WI-14 | WP5 issuance suite | Exact `floor(newL*T/Lp)`, idle excluded, zero-share rejection. |
| WI-15 | WP5/WP6 settlement suite | First caller delta, positive credits, used/refund split, no second-return substitution. |
| WI-16 | WP5 transfer suite | Exact ledger conservation/events, unknown-pool zero transfer, zero recipient and panic cases. |
| WI-17 | WP5 withdrawal suite | Validation/debit/compound/settle/minimum/event order; checked underflow retained. |
| WI-18 | WP5 proportional burn suite | Exact liquidity/idle floors, zero-removal skip, idle payment before zap, final signed settlement. |
| WI-19 | WP5 zap suite | Nested-floor balance heuristic, at most one swap, post-swap sizing, zap directions. |
| WI-20 | WP5 swap suite | Exact amount/limit encoding, returned-delta accounting, partial fill and residual output. |
| WI-21 | WP5 compound suite | Timestamp-before-liquidity check, zero-L no-op, zero-delta poke, int128 gross-fee conversion. |
| WI-22 | WP5/WP6 fee/reinvestment suite | Exact cut/order, net-plus-idle sizing, source idle cast, treasury and settlement recipients. |
| WI-23 | WP5 event/attribution suite | Event only for positive gross fee; idle-only add silent; deposit/withdraw ordering and no second cut. |
| WI-24 | WP5/WP7 inventory suite | Per-vault idle versus physical receipts, shared currency, self-directed receipts, no donation credit or sweep. |
| WI-25 | WP4/WP5 view suite | Unknown/empty defaults, preview formula, pending-fee gross formula and modular subtraction. |
| WI-26 | WP6 admin suite | Owner-only, validation order, no-change events, pause scope and repeated transitions. |
| WI-27 | WP6 ownership suite | Two-step transitions, replacement/cancellation, wrong accepter, renunciation effects. |
| WI-28 | WP6 guard matrix | Only three guarded methods; callback reentry distinctions and intermediate-state caveat. |
| WI-29 | WP3/WP6 native/token plumbing | Exact native value, no wrapping, sync/transfer/settle ordering, positive/negative/zero net, manager error envelopes. |
| WI-30 | WP6 rollback matrix | Deadline equality, exact failed-subtree state/log rollback, caught versus uncaught outer effects. |
| WI-31 | WP2/WP4/WP6 error/arithmetic suite | Exact 18 errors plus propagated dependency errors/panics; no generic revert matcher or safer-cast substitution. |
| WI-32 | WP3 TestBase | Actual Weir and real canonical manager; no SUT mock/etch/injection. |
| WI-33 | WP3 observers and WP5-WP7 assertions | Exact balances/ledgers/positions/deltas/events/order; closed deltas only after successful top-level completion. |
| WI-34 | WP4 independent oracle | No production-helper/preview oracle; checked staged rounding; committed independent swap vectors. |
| WI-35 | WP5-WP7 characterization discipline | Actual limitation asserted or exact reachability gap; supported and hostile tests separated. |
| WI-36 | WP7 campaigns | Users/pools/directions/native/donations/transfers/compounds/pause/owner; seed/depth/counts/reverts/shrunk sequence. |
| WI-37 | WP8/WP9 fork and build gates | Default/fork profiles, shared alias/pin, warm artifacts, artifact-before-test, honest BLOCKED status. |

## 10. Dedicated AC01-AC69 implementation/testing map

Reachability notation: **P** planned real-manager hermetic test; **S** static/machine gate; **C** conditional real-manager reachability with an explicit gap if not constructible; **F** local fork; **U** unresolved/unverified at issue.

| AC | Proposed test/class/method or static gate | Construction / precondition | Primary exact assertion | WP | Reachability |
|---|---|---|---|---|---|
| AC01 | `scripts/verify-weir-source-import.py --check`; `WeirVaultsSurface.t.sol::test_AC01_sourceTransformAllowlist` | Frozen three files, local three files, manifest, and any WI-06 hunks | Exactly the 22 imports, five qualifications, and recorded WI-06 hunks; no unlisted edit; notices/comments retained; original and adjusted hashes/diagnostics recorded | WP1 | S/U |
| AC02 | `WeirVaultsSurface.t.sol::test_AC02_compiledABIMatchesManifest` | Fresh default-profile artifact | Exactly 27 functions, constructor, receive, 11 events, 18 listed errors; exact tuple/mutability/indexing | WP2 | S/U |
| AC03 | WP1/WP9 build gate | Copied source and default profile | Build succeeds with 0.8.35/runs1/viaIR false, or exact remaining compiler blocker; no green claim from failure | WP1, WP9 | U |
| AC04 | WP1 manifest/WP9 license disposition gate | All 39 frozen entries plus resolved graph | Every entry accounted for; full GPL/AGPL/BUSL parameters, 2027-06-15-or-earlier ENS/anniversary conditions, old-GPL/new-MIT ambiguity, and no inferred grant/clearance | WP1, WP9 | S/U |
| AC05 | `WeirVaultsSurface.t.sol::test_AC05_constructorAndInitialState` | Valid manager/treasury/owner; isolated zero treasury, zero owner, zero manager cases | Valid getters/fee=500/cap=1000/MIN=1000/paused=false/count=0 and ownership event; `ZeroAddress`, `OwnableInvalidOwner(0)`, and zero manager accepted | WP3, WP4 | P |
| AC06 | `WeirVaultsDepositTransfer.t.sol::test_AC06_createDistinctVaults` | Two initialized complete keys, including shared currency | Distinct IDs/ticks/existence/zero accounting; ordered array entries; count increments once; exact `VaultCreated` | WP5 | P |
| AC07 | `WeirVaultsSurface.t.sol::test_AC07_createFailures` | Duplicate, uninitialized key, and `allVaults(count)` | `VaultExists`, `PoolNotInitialized`, `Panic(0x32)`; no extra entry/log | WP5 | P |
| AC08 | `WeirVaultsViews.t.sol::test_AC08_unknownAndEmptyViews` | Unknown ID and known empty created vault | Unknown struct/defaults and quote pairs `(0,0)`; empty vault keeps key/ticks/exists but quotes remain `(0,0)` | WP5 | P |
| AC09 | `WeirVaultsDepositTransfer.t.sol::test_AC09_F0RecipientDiffersFromPayer` | F0; payer A, recipient B | All F0 integers; B gets 1,047,576 shares; A gets both refunds; event user B; salt-zero position owner Weir | WP4, WP5 | P |
| AC10 | `WeirVaultsDepositTransfer.t.sol::test_AC10_genesisThreshold` | Fresh fee-zero tick-zero pool with 1,002 each, then fresh 1,003 each | 1,002 computes liquidity 1,000 then `ZeroShares`; 1,003 mints liquidity 1,001, one user share, refunds 2 each | WP4, WP5 | P |
| AC11 | `WeirVaultsDepositTransfer.t.sol::test_AC11_zeroLiquidityAndOneSidedBranches` | Fresh/existing vaults; amount pairs 0/1/2 and one-sided interior-price non-zap deposits in both directions | Every zero-liquidity/share branch is `ZeroShares`; no false success from transfers or idle | WP4, WP5 | P |
| AC12 | `WeirVaultsDepositTransfer.t.sol::test_AC12_secondIdenticalDeposit` | F0, then second identical paired deposit without fees | Second gets K; L=T=2K; reserve difference 1000; first recipient ledger unchanged | WP4, WP5 | P |
| AC13 | `WeirVaultsDepositTransfer.t.sol::test_AC13_depositAfterRealFees` | Real pending fees, then paired deposit | Pre-compound cut/liquidity/idle first; shares `floor(newL*postCompoundT/postCompoundL)`; no pre-compound-L pricing | WP5 | P |
| AC14 | `WeirVaultsDepositTransfer.t.sol::test_AC14_F3IdleDilution` | F3 | Exactly F3, including new user's nine-unit idle0 claim and no separate old-idle payment | WP4, WP5 | P |
| AC15 | `WeirVaultsDepositTransfer.t.sol::test_AC15_zapMatrix` | Initialized pool with liquidity; balanced, c0-heavy, c1-heavy, single-sided zaps, and x=0 imbalance | Exact nested-floor direction/input; no swap for zero/no imbalance; one swap otherwise; post-swap sizing and exact shares/refunds from independent oracle | WP4, WP5 | P |
| AC16 | `WeirVaultsDepositTransfer.t.sol::test_AC16_depositSwapFeeAttribution` | Existing Weir liquidity in fee-bearing pool; second payer zaps in | Same-call incumbent fees are separated from prior fees; payer bears/receives them through used input; no second cut or incumbent-share credit; exact event used values | WP5 | P |
| AC17 | `WeirVaultsDepositTransfer.t.sol::test_AC17_minSharesAndRollback` | Normal deposit with computed S; fresh equal-S and S+1 fixtures | S succeeds; S+1 is `Slippage` after callback work and restores auto-created vault, fees, funds, shares, position, idle, timestamp, and logs | WP5, WP6 | P |
| AC18 | `WeirVaultsDepositTransfer.t.sol::test_AC18_transferSharesMatrix` | Known pool shares; other user, self, Weir, unknown-pool zero, zero recipient, overspend | Exact ledger/event; self transfer unchanged after balance check; Weir can hold shares; unknown zero transfer succeeds; `ZeroAddress`; `Panic(0x11)` | WP5 | P |
| AC19 | `WeirVaultsAccessCallbacks.t.sol::test_AC19_pauseScope` | Funded vault, paused | Deposit `EnforcedPause`; create/transfer/compound/withdraw/views/receive retain independent outcomes; no blanket pause | WP6 | P |
| AC20 | `WeirVaultsDepositTransfer.t.sol::test_AC20_modifierAndBodyPrecedence` | Paused+reentrant+expired+zero recipient, then isolated valid-deadline cases | Paused precedes reentrancy, then deadline, then recipient; expired+zero recipient is `Expired`; future deadline+zero recipient is `ZeroAddress` | WP6 | P |
| AC21 | `WeirVaultsWithdrawCompound.t.sol::test_AC21_F0FullAssignedWithdrawal` | F0; assigned holder withdraws all, zap 0, recipient differs | `(1,047,575,1,047,575)` to recipient; holder zero; L=T=1000; idle zero; event user owner/caller | WP4, WP5 | P |
| AC22 | `WeirVaultsWithdrawCompound.t.sol::test_AC22_postCompoundSubsetWithIdle` | Real fee/idle state; proper subset | Compound first; separate post-compound liquidity/idle floors; exact state and recipient amounts; no last-user sweep | WP5 | P |
| AC23 | `WeirVaultsWithdrawCompound.t.sol::test_AC23_tinyWithdrawalBranches` | Real fee/idle state and tiny share request | If proportional liquidity is zero, no manager removal; nonzero idle claim is still paid; all-zero claims may burn for zero output; if no real branch is constructible, record the gap | WP5 | C/U |
| AC24 | `WeirVaultsWithdrawCompound.t.sol::test_AC24_withdrawZapDirections` | Separate equivalent zap 0/1/2 fixtures with ample liquidity | No swap / sell c1 for c0 / sell c0 for c1; exact input and signed-delta settlement/outputs | WP4, WP5 | P |
| AC25 | `WeirVaultsWithdrawCompound.t.sol::test_AC25_partialFillBothDirections` | Price near usable boundary, finite liquidity, requested input exceeds consumption before global limit | Swap stops at limit or exhausted liquidity; unsold currency remains positive output and is delivered; no consumption-equality revert; both directions | WP4, WP5 | C/U |
| AC26 | `WeirVaultsWithdrawCompound.t.sol::test_AC26_withdrawMinimaRollback` | Equivalent fixtures with minima `(a,b)`, `(a+1,b)`, `(a,b+1)` | Equality succeeds; each one-unit violation is `Slippage` and restores shares, position, timestamp, fees, idle, recipient balances, and logs | WP5, WP6 | P |
| AC27 | `WeirVaultsWithdrawCompound.t.sol::test_AC27_withdrawValidationOrder` | Valid deadline; zap 3, zero recipient, unknown key, zero shares, insufficient balance; expired variant | `BadZap`, `ZeroAddress`, `NoVault`, `ZeroShares`, `Panic(0x11)` as earlier conditions are removed; expired precedes body | WP6 | P |
| AC28 | `WeirVaultsWithdrawCompound.t.sol::test_AC28_emptyVaultCompoundTimestamp` | Known empty vault; compound at t then t+1 | Stored uint64 timestamps update; no poke, fee, transfer, or `Compounded`; no empty-position error | WP5 | P |
| AC29 | `WeirVaultsWithdrawCompound.t.sol::test_AC29_unknownVaultCompound` | Unknown key | `NoVault` before unlock; no timestamp/state change | WP5 | P |
| AC30 | `WeirVaultsWithdrawCompound.t.sol::test_AC30_F1CompoundTwice` | F1 and second no-change compound | Gross 20/cut 1/idle 19/L unchanged/exact first event; second no event and idle unchanged, timestamp updated | WP4, WP5 | P |
| AC31 | `WeirVaultsWithdrawCompound.t.sol::test_AC31_F2Compound` | F2 | Gross `(0,20)`, cut `(0,1)`, added 17, idle `(2,2)`, T unchanged, exact event and physical payments | WP4, WP5 | P |
| AC32 | `WeirVaultsWithdrawCompound.t.sol::test_AC32_feeThresholdsAndSelfTreasury` | Real donations/swaps near 19/20; fees 0/500/1000; treasury=Weir | Cut `floor(f*bps/10000)`; self-treasury F1 records idle 19 and physical receipt 20 with one unassigned; repeat does not book it; no fee merely for spending idle | WP5 | P |
| AC33 | `WeirVaultsWithdrawCompound.t.sol::test_AC33_idleOnlyReinvestment` | Real one-sided idle; price moved without newly harvested positive fee | Exact idle-only L/idle change, T fixed, no `Compounded`; distinct from no-op and from price-move fees | WP4, WP5 | C/U |
| AC34 | `WeirVaultsInventory.t.sol::test_AC34_donationsAndSelfRecipient` | Direct ERC-20/native donations before/after F0; separate F0 withdrawal to Weir | Donations create no shares/idle/fee or quote change; self withdrawal delivers 1,047,575 each to Weir with L=T=1000, idle zero, unassigned receipts; receive emits no vault event | WP5 | P |
| AC35 | `WeirVaultsInventory.t.sol::test_AC35_sharedCurrencyVaults` | Two funded vaults share currency; accrue/operate one | Only selected ledger/position changes; physical shared balance equals idle plus tracked unassigned receipts | WP5, WP7 | P |
| AC36 | `WeirVaultsDepositTransfer.t.sol::test_AC36_missingAllowanceOrBalance` | Pre-existing inventory plus no allowance and no payer balance | Exact token failure; no shares and no inventory loss; inventory cannot substitute for payer transfer; short delivery remains AC55 | WP5 | P |
| AC37 | `WeirVaultsWithdrawCompound.t.sol::test_AC37_exitSwapFeeCheckpoint` | Burn shares then zap in fee-bearing pool; inspect remaining position | Exit-swap fees accrue to remaining real liquidity, not burned shares, and are not auto-compounded again; later pending/compound reflect exact floors | WP5 | P |
| AC38 | `WeirVaultsViews.t.sol::test_AC38_previewRedeemMatrix` | F0 and fee/idle variants; zero, fraction, total, oversized share requests | Independent downward liquidity amount plus floored idle; no ownership/mutation; zero-T short-circuit | WP4, WP5 | P |
| AC39 | `WeirVaultsViews.t.sol::test_AC39_previewOverflowBoundaries` | F0 L=T=2^20; s=2^128+7 then 2^236; separately zero-T | First product fits, quotient truncates to L=7 and quote 6/6; second is `Panic(0x11)`; zero-T returns `(0,0)`; library errors remain separate | WP4 | P |
| AC40 | `WeirVaultsViews.t.sol::test_AC40_previewIsNotExecuteSimulation` | Pending fees; preview versus actual withdrawal with/without zap and a no-fee equality prerequisite | Preview follows only its formula; execution follows compound/zap formula; no unconditional equality requirement | WP4, WP5 | P |
| AC41 | `WeirVaultsViews.t.sol::test_AC41_pendingFees` | Real nonzero position/fee growth; below/inside/above ranges where reachable; independent modular vectors | `floor(((inside-last) mod 2^256)*positionL/H)` per currency, gross and view-only | WP4, WP5 | P/C |
| AC42 | `LiquidityAmounts.t.sol::test_AC42_numericAnchor` | Actual frozen L with A=Q,B=2Q, amount 3; reverse bounds | L0=6,L1=3 in either order; reverse amounts at L=7 are 3 and 7 | WP4 | P |
| AC43 | `LiquidityAmounts.t.sol::test_AC43_interiorAndBoundaryBranches` | A=Q/2,B=2Q,P=Q, amounts 3/4; P=A and P=B | L=min(6,8)=6; amounts 3/3; exact outer branch selection | WP4 | P |
| AC44 | `LiquidityAmounts.t.sol::test_AC44_eachBranchOverflow` | Interior bounds; amounts `(2^127,1)` and `(1,2^127)` | Each reverts `Error("liquidity overflow")` in the overflowing branch; no wide-minimum rescue | WP4 | P |
| AC45 | `LiquidityAmounts.t.sol::test_AC45_zeroDenominators` | Equal nonzero bounds; separate A=0,B=Q,L=1 amount0 conversion | Equal-bound FullMath empty revert; amount0 final division is `Panic(0x12)`; no invented range error | WP4 | P |
| AC46 | `WeirVaultsSurface.t.sol::test_AC46_timestampAndDeadlineBoundaries` | Empty vault at 2^64-1/2^64/2^64+7; deposit/withdraw deadline t and t-1 | Stored 2^64-1/0/7; deadline equality accepted; t-1 `Expired`; reverted calls restore prior timestamp | WP5, WP6 | P |
| AC47 | `LiquidityAmounts.t.sol::testFuzz_AC47_libraryArithmetic` plus deposit/withdraw proportion fuzz | Independent valid raw-unit domains and explicit overflow boundaries | Exact nested-floor/cast result and exact error class; non-18-decimal units remain raw; fixed seed/reject budget recorded | WP4, WP7 | P/U |
| AC48 | `WeirVaultsAccessCallbacks.t.sol::test_AC48_nativeAndERC20ValuePaths` | Native and ERC-20 pools; paired/zapped correct value, value-1/value+1; ERC-20 pair with value 1 | Correct native settlement/refund without WETH; wrong value `BadNativeAmount`; payer receives native refund even when recipient differs | WP6 | P |
| AC49 | `WeirVaultsAccessCallbacks.t.sol::test_AC49_rejectingNativeRefund` | Native payer contract rejects nonzero refund; zero-refund variant | Nonzero refund is `NativeTransferFailed` and full deposit/fee/position rollback; zero refund makes no rejecting call and succeeds | WP6 | P |
| AC50 | `WeirVaultsAccessCallbacks.t.sol::test_AC50_managerTakeRejectionEnvelope` | Native output or treasury cut to receiver with known revert bytes | Exact manager currency-transfer error and nested receiver bytes, not `NativeTransferFailed`; no retained burn/cut | WP6 | P/C |
| AC51 | `WeirVaultsAccessCallbacks.t.sol::test_AC51_staleNonNativeSync` | Router syncs ERC-20 before positive native-pay Weir call; legitimate callback leaves sync open; caught and uncaught variants | `NonzeroNativeValue`; failed Weir subtree rolls back; caught outer sync/effects can persist until outer settlement; uncaught transaction rolls back; inner failure does not close outer unlock | WP6 | P/C |
| AC52 | `WeirVaultsAccessCallbacks.t.sol::test_AC52_adminSetterMatrix` | Owner/nonowner/pending owner; fees 0/500/1000/1001; zero/repeated treasury | Only current owner; unauthorized error precedes body; `FeeTooHigh`; `ZeroAddress`; exact events including no-change setters | WP6 | P |
| AC53 | `WeirVaultsAccessCallbacks.t.sol::test_AC53_ownershipTransitions` | Start/replace/cancel/accept/renounce; wrong accepter; paused renounce | Exact current/pending transitions/events; wrong accepter includes caller; pending clears on accept/renounce; former owner cannot unpause after renunciation | WP6 | P |
| AC54 | `WeirVaultsAccessCallbacks.t.sol::test_AC54_callbackReentryMatrix` | Token/hook/treasury/output/payer callbacks during pull, manager hook, take/refund; unpaused/paused | Guarded reentry is `ReentrancyGuardReentrantCall`; paused deposit is `EnforcedPause`; caught nested rejection may allow outer success; bubbling rolls back at the actual boundary; no forged manager callback | WP6 | P |
| AC55 | `WeirVaultsAccessCallbacks.t.sol::test_AC55_hostileTokenReturnModes` | Token false/no-return/explicit revert/short or no delivery; pre-existing same-token inventory case | False -> `SafeERC20FailedOperation(token)`; explicit bytes bubble; real no-return delivery accepted; short/no delivery has exact balances and no free-share or safety inference | WP6 | P |
| AC56 | `WeirVaultsAccessCallbacks.t.sol::test_AC56_unguardedCallbackSurfaces` | Callback calls transferShares/createVault/views; current-owner callback calls setters/ownership; caller owns its shares/roles | Unguarded surfaces use their own access/balance checks; token-driven transfer moves token caller's shares only; exact caller, ledger, event order, and intermediate views; exact insufficient-authority/balance errors | WP6 | P |
| AC57 | `WeirVaultsWithdrawCompound.t.sol::test_AC57_nativeTreasuryChangesBeforeSecondCut` | Native pool with both positive cuts; treasury receiver is current owner and sets treasury T2 in native callback | Cuts computed before takes; c0 reaches old treasury, c1 reaches T2; setter/outer failure rolls back as applicable | WP6 | P |
| AC58 | `WeirVaultsAccessCallbacks.t.sol::test_AC58_callbackProvenanceAndNestedUnlock` | Outsider valid/malformed callback; auxiliary unlock owner calls compound caught/propagated; active Weir reentry | Outsider `NotPoolManager` before decode; independent nested unlock `AlreadyUnlocked`; active guarded reentry hits its guard first; caught failure leaves owner unlock open until completion | WP6 | P |
| AC59 | `WeirVaultsWithdrawCompound.t.sol::test_AC59_hookCallsAndOrder` | Existing nonzero-L vault; valid observation hook; positive reinvestment and zero-L/zero-reinvestment cases | Exact hookData and applicable poke/add/remove/swap calls/order; no dedicated poke hook; zero-L skips poke; zero add skips reinvestment; createVault invokes no pool hook; reverting hook has exact wrapper and rollback | WP6 | P |
| AC60 | `WeirVaultsWithdrawCompound.t.sol::test_AC60_returnDeltaVsInformationalFees` | Legitimate return-delta hook; valid negative caller component; hook settles own debt | Gross fee logic uses positive first-return components; source uses first caller delta; an unaccounted negative Weir component yields actual `CurrencyNotSettled` | WP4, WP6 | P/C |
| AC61 | `WeirVaultsAccessCallbacks.t.sol::test_AC61_intermediateObserverStates` | Hostile receiver observes views/shares during treasury payment, withdrawal settlement, deposit refund | Exact source phases: withdrawal caller debit precedes callback compounding; deposit recipient credit precedes outer refund; no universal atomic-view invariant | WP6 | P |
| AC62 | `WeirVaultsSurface.t.sol::test_AC62_payabilitySurface` | Low-level calls with value to nonpayable methods; separate empty-calldata value | Nonpayable dispatch fails with compiled target revert data, not an invented domain error; receive succeeds and changes no ledger | WP4, WP6 | P |
| AC63 | `WeirVaultsInvariant.t.sol::test_invariant_AC63_supportedDomain` plus handler | Three users, two shared-currency pools, exact-transfer tokens, deposits/transfers/withdrawals/compounds/donations | After successful top-level completion only: Weir salt-zero position L equals vault L; assigned sum=T-1000 after genesis/0 before; physical inventory reconciles including unassigned receipts and Weir-held shares; manager unlocked=false and deltas zero | WP7 | P |
| AC64 | `WeirVaultsInvariant.t.sol::test_invariant_AC64_hostileCharacterization` plus separate hostile handler | Callbacks, rejects, short delivery, return deltas, partial fills, pause/owner changes | Exact characterized ledger/error for each reached case; supported invariants not asserted across hostile assumptions; complete outcome trace | WP7 | P |
| AC65 | `WeirVaultsForkParity.t.sol::test_AC65_referenceCopyParity` | Local chain-4663 fork, shared pin, archive alias, fresh pool/tokens, reference and copy branches | Direct-create/reference/manager code and block facts; equivalent local state; exact mapped returns/reverts/events/balances/positions; missing archive state/role is BLOCKED | WP8 | F/U |
| AC66 | `VERIFICATION.md::AC66_releaseLedger` | All implementation/test/static/fork/license outputs | Every WI/AC maps to a real test/static check or explicit unresolved gate; hermetic/build results separate from fork/security/license status; no overclaim | WP9 | S/U |
| AC67 | `WeirVaultsWithdrawCompound.t.sol::test_AC67_negativeIdleCastReachability` | Real return-delta hook; construct oldIdle+net=-1 with donated physical currency and hook settlement | If reached, recorded idle is exactly 2^256-1, not an automatic cast revert; exact physical/hook/Weir deltas and rollback; if not constructible, exact reachability gap | WP4, WP6 | C/U |
| AC68 | WP2 OZ identity/behaviour gate plus owner/pause/guard/token suite | Six frozen OZ files compared separately from SafeERC20 used paths; compiled layout and token modes | Six files retain identity/sequential inherited storage; SafeERC20 v5.2 retains used-path typed failures/revert behavior; no mixed Context or namespaced upgrade | WP2, WP6 | S/P/U |
| AC69 | WP1/WP9 `scripts/verify-weir-source-import.py` graph/import check | Actual resolved production and test import graphs after build | Frozen 39-file map retained; actual canonical runtime graph separately records StateLibrary helper and literal BSL/AGPL headers; test-only graph distinguished; every license gate explicit | WP1, WP2, WP9 | S/U |

## 11. Limits, risks, and release disposition

- The frozen corpus has no upstream Git pin, upstream tests, or audit. This plan can prove the copied baseline against the frozen corpus and real dependencies; it cannot claim upstream-suite, audit, or economic-safety equivalence.
- Compiler success may require the authorized WI-06 lexical/memory-struct changes. Their business equivalence is a review obligation, not a machine-proven universal theorem; any behavior-changing diagnostic is a separate owner decision.
- A canonical V4 or OZ mismatch outside the PRD's accepted route blocks import acceptance. Do not edit Weir or shared canonical code opportunistically.
- Tiny-withdrawal, price-move-without-fee, return-delta, stale-sync, rejecting-manager-take, and negative-idle-cast branches may be unreachable under real-manager constraints. Report the exact attempted construction and gap; never inject state or weaken the requirement.
- Archive RPC state and `ALCHEMY_KEY` are unavailable in this process. Actual fork parity is BLOCKED here and must remain distinct from hermetic proof.
- BUSL version-to-declaration provenance, Additional Use Grant applicability, and production-use rights are unresolved owner/legal gates. GPL/AGPL are open-source declarations, but no combined-work conclusion follows.
- Default-build bytecode identity is not required or claimed. The upstream viaIR/optimizer-800 build is not the local target, and local viaIR remains false.
- No deployment, gas benchmark, formal proof, economic fairness result, wrapper/registry readiness, or production release clearance follows from this plan.

**Recommendation:** execute WP1-WP3 as the smallest decision-complete path to a compileable, provenance-bound, real-manager baseline; do not begin money-path assertions until WP2 and WP3 close. Then execute WP4-WP7 as exact characterization, WP8 as an honestly blocked-or-executed local parity gate, and WP9 as the release-evidence ledger. Any canonical mismatch, unreachable adversarial branch, missing archive input, or unresolved release right remains visible rather than being converted into a presumed pass.

Now: No task remains; the complete contribution is delivered inline because active `apply_patch` was unavailable.

Next: No task remains.
