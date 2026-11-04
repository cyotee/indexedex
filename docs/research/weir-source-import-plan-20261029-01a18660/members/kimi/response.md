# Kimi independent original: WeirVaults implementation and testing plan

## 0. Status, authority, and evidence boundaries

This is an implementer-facing plan for the owner-clarified frozen PRD, not implementation authorization, a replacement PRD, or a claim that any gate has run. The destination for the coordinator's synthesized plan remains `contracts/protocols/strategy/weir/WEIR_VAULT_SOURCE_IMPORT_IMPLEMENTATION_AND_TEST_PLAN.md`; this original proposes the work, not that file's contents verbatim.

The authority is the complete frozen `inputs/PRD.md`, revision `weir-import-prd-owner-clarifications-20261029`, and the three complete frozen domain sources. I also read the required repository rules, artifact-build guidance, canonical porting/verification/testing guidance, and the existing test/deployment patterns named below. The coordinator-supplied PRD SHA-256 is treated as supplied identity, not independently recomputed attestation.

Evidence labels used here:

- **Source observation:** directly visible in frozen W/B/L: modifier and validation order, storage declarations, arithmetic/casts, callback control flow, use of the first `modifyLiquidity` return, idle settlement, events, and native/ERC20 plumbing.
- **Verified existing repository input:** read in this pass: `CraneTest`, canonical `PoolManager` and `PoolOperation`, the V4 test routers, `HookMiner`, `ERC20PermitMintableStub`, `Behavior_IERC165`, the ERC4626 handler, `TransientStateLibrary` lock observation, `ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK`, `foundry.toml`, and `remappings.txt`.
- **Supplied PRD evidence:** source/deployment hashes and receipts, dependency comparisons, license declarations, and the earlier fork-pin build/fmt result. These are planning inputs, not tests run by this member.
- **Unverified gate:** compilation, transformed-source equivalence, generated ABI/storage layout, every runtime assertion, actual resolved license graph, upstream parity, and archive-backed fork parity remain future work.

### Fixed scope and exclusions

Import only W/B/L into the requested standalone Weir tree, using the 22 exact import rewrites and five free-struct constructions. Preserve the frozen Weir `LiquidityAmounts`, notices, comments, inheritance/storage order, arithmetic staging, casts, calls, and failure behavior. Use solc 0.8.35, optimizer runs 1, and `viaIR=false`; only lexical scopes and internal memory structs are available if compilation requires them, each with its original diagnostic and equivalence evidence.

Do not add an ERC20/ERC4626 surface, Rate Provider, NAV issuance, SE/Diamond/registry wiring, proxy lifecycle, production factory, strict single-output guarantee, already-unlocked-hook route, native-sync repair, additional reentrancy guards, rescue/sweep, economic repair, private dependency tree, package profile, or new RPC variable. Do not restore retired V4/FullSpread families. Characterization tests never authorize remediation.

Release-blocking unknowns must remain explicit: actual canonical compatibility, compiler/ABI/storage proof, full license/version/grant disposition, missing upstream Git/tests/audit, unreachable adversarial constructions, and archive state/credentials. A failed or unavailable gate is not a pass.

## 1. Concrete file inventory

All names in the proposed tables are **proposed future paths**, not existing files. Existing paths listed separately were read or are identified by the frozen PRD.

### 1.1 Production and provenance

| Proposed path | Purpose | Owner |
|---|---|---|
| `contracts/protocols/strategy/weir/WeirVaults.sol` | Faithful W import; only allowlisted transformations and necessary WI-06 edits. | WP1/WP2 |
| `contracts/protocols/strategy/weir/base/WeirBase.sol` | Faithful B import. | WP1/WP2 |
| `contracts/protocols/strategy/weir/libraries/LiquidityAmounts.sol` | Faithful GPL L import, never the canonical namesake. | WP1/WP2 |
| `contracts/protocols/strategy/weir/VENDOR.md` | Frozen 39-file provenance, deployment evidence, actual graph/license disposition, import/refactor log, missing upstream evidence, and release limits. | WP1, updated WP2/WP7/WP8 |
| `contracts/protocols/strategy/weir/IMPORT_TRANSFORM.json` | Machine-consumable 22 import rewrites, five type replacements, original/adjusted hashes, and WI-06 diff/diagnostic identifiers; no prose-pinning test. | WP1/WP2 |
| `contracts/protocols/strategy/weir/RELEASE_EVIDENCE.md` | Final command results, AC/WI disposition, campaign seeds/counters, fork status, unresolved gates, and separate release clearances. | WP8 |

The frozen `.sol.txt` corpus remains research input and outside production compilation. No second production domain tree or copied OZ/V4 dependency tree is created.

### 1.2 Test infrastructure under `contracts/protocols/strategy/weir/test/`

| Proposed path | Purpose |
|---|---|
| `bases/TestBase_WeirVaults.sol` | `CraneTest`-first hermetic setup, real canonical manager, actual standalone Weir, sorted ERC20/native pools, external liquidity, F0-F3 helpers, and common actors. |
| `bases/TestBase_WeirVaultsRobinhoodFork.sol` | Local-only chain4663 preflight, reference/copy role mapping, common fresh-pool setup, and full-state snapshot branches. |
| `Behavior_WeirVaults.sol` | Exact assertion entry points following the existing `Behavior_IERC165` style; no production behavior and no loosely typed tolerances. |
| `WeirObservation.sol` | Snapshot/observer types and ghost ledger for users, Weir, treasuries, routers, hooks, manager deltas, positions, physical inventory, and unassigned receipts. |
| `WeirTestOracle.sol` | Independent staged integer arithmetic for liquidity, shares, burn/idle, fees, deposit balancing, and pending-fee vectors; never calls Weir or its L as an expectation oracle. |
| `LiquidityAmountsExposure.sol` | Pure exposure of the actual imported L for AC42-45/47 only; it does not replace or subclass Weir. |
| `WeirAuxiliaryRouter.sol` | Real `IUnlockCallback` peripheral for external liquidity, exact-input swaps, seeded `donate`, and settlement of its own debts/credits. |
| `WeirCatchRouter.sol` | Real unlock owner for open-sync, nested-unlock, caught/bubbling Weir calls, and earlier/later outer effects. |
| `WeirHook.sol` | Legitimate recording/return-delta hook with mined permissions, caller/hookData logs, and controlled hook-owned settlement; no SUT mocks. |
| `WeirControlledToken.sol` | Peripheral exact-transfer token plus configurable false/no-return/revert/short-delivery and callback modes. Ordinary fixtures use the existing mintable token instead. |
| `WeirCallbackReceiver.sol` | Payer/treasury/recipient/receiver that can reject native, change owner-authorized settings, reenter, and record intermediate views. |
| `WeirVaultsHandler.sol` | Supported-domain deterministic handler with bounded actors/pools and successful-action counters. |
| `WeirVaultsHostileHandler.sol` | Separate hostile campaign handler; records exact classified outcomes rather than applying ordinary invariants to hostile states. |

### 1.3 Specs, fixtures, and fork suites

Proposed hermetic specs under `test/foundry/spec/protocols/strategy/weir/`:

- `WeirSourceAndSurface.t.sol`
- `WeirDeposit.t.sol`
- `WeirWithdrawCompound.t.sol`
- `WeirViewsAndMath.t.sol`
- `WeirNativeAccessHooks.t.sol`
- `WeirInvariant.t.sol`
- `WeirHostileInvariant.t.sol`
- `fixtures/frozen-metadata-abi.json` (verbatim ABI extracted from the admitted manifest, with provenance)
- `fixtures/arithmetic-vectors.json` (F0-F3, library, cast, and rounding vectors)
- `fixtures/swap-vectors.json` (committed exact tick-traversal vectors and provenance)
- `oracle/weir_reference.py` (test-only wide-integer vector generator; not a production simulator)

Proposed fork spec: `test/foundry/fork/protocols/strategy/weir/WeirRobinhoodParityFork.t.sol`.

### 1.4 Verified existing components to reuse

- `lib/crane/contracts/test/CraneTest.sol`: parent setup and normal factory bootstrap; it does not make Weir a Diamond product.
- `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol`: real hermetic manager. Its direct deployment in a protocol TestBase is the allowed protocol-port route.
- `.../v4/hooks/public/dependencies/v4-core/test/PoolSwapTest.sol` and `PoolModifyLiquidityTest.sol`: real unlock/settlement routers for external liquidity and swaps. Use them where their assertions fit; the proposed auxiliary router adds only missing donate/catch/sync operations.
- `.../v4/utils/HookMiner.sol` and `.../v4/libraries/Hooks.sol`: mine actual permission bits; do not etch a hook address.
- `lib/crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol`: ordinary exact-transfer, selectable-decimal tokens.
- `.../v4/libraries/TransientStateLibrary.sol`: observe manager lock state after top-level completion.
- `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol`: chain and shared pin `76_197_114`; existing aliases are in root `foundry.toml`.

No speculative consumer interface, duplicate manager, wrapper, facet, package, or alternate dependency tree is part of this inventory.

## 2. Ordered work packages and ownership

WP1 and WP2 are serial. WP3's oracle and harness tracks may proceed in parallel after WP1, but no money-path assertion runs before WP2 accepts source/dependency/ABI/storage compatibility. WP4 and WP5 may then develop in parallel against the frozen WP3 interfaces. All artifact/build writers are serialized. WP6 follows stable deterministic suites; WP7 is independent of campaign count but requires WP2 and archive inputs; WP8 is last.

| WP | Allowed edit paths and single-owner interface | Dependencies and detailed work | Expected output / exit evidence |
|---|---|---|---|
| **WP1: faithful import and provenance** | Only the three production paths, `VENDOR.md`, `IMPORT_TRANSFORM.json`. Owner publishes the exact transformation manifest consumed by WP2. | Verify frozen inputs against supplied identifiers; copy W/B/L; apply exactly 22 import rewrites plus `ModifyLiquidityParams` four times and `SwapParams` once as free types; retain relative Weir imports and L; record original/adjusted hashes and every diff. Do not fix source quirks. | Three files at only the requested destination; transform manifest accounts for every changed byte; VENDOR records all 39 frozen entries and supplied deployment/license evidence. AC01 static diff passes before WP2. |
| **WP2: compile, ABI, storage, dependency, and graph gate** | WP1 paths only for authorized WI-06 edits; `VENDOR.md`, `IMPORT_TRANSFORM.json`, frozen ABI fixture. No shared dependency/config edits. | Run default artifact build. If stack depth fails, record the exact diagnostic and use only lexical scopes/internal memory structs, then rerun AC01. Compare generated ABI to frozen metadata: 27 functions, constructor, receive, 11 events, 18 errors, tuples/mutability/indexing. Prove source declaration/inheritance storage order and canonical used surfaces: PoolOperation fields, StateLibrary hashing/position key/tick encoding/slots, math/revert behavior, sequential OZ layout and SafeERC20 used paths. Traverse actual runtime/test graphs. | Default build succeeds without viaIR/config edits, or exact blocker stops later money-path claims. ABI/layout and dependency evidence accepted; AC02/03/68/69 and static portions of AC04 complete. Any behavior-changing mismatch is escalated, not patched around. |
| **WP3: real-manager TestBase, observers, and independent oracle** | Only proposed `test/` infrastructure and spec fixture/oracle files. One owner freezes TestBase fixture methods, observation structs, Behavior entry points, and oracle function signatures before WP4/WP5. | Call `CraneTest.setUp()` first; deploy real manager and actual Weir; reuse real routers; initialize sorted pools and native pool; create salt-zero Weir positions through deposits; add donate/catch routers and mined hook. Implement independent MD and exact swap goldens, ghost accounting, exact event/error/snapshot assertions. | Hermetic F0-F3 fixtures reproduce static derivations; harness has no SUT inheritance/etch/storage injection/mockCall. Oracle tests pass against committed independent vectors. Manager lock/delta observers and rollback snapshots are ready. |
| **WP4: deterministic surface, money paths, views, and arithmetic** | Four deterministic spec files only; no WP3 interface changes without returning to WP3 owner. | Implement AC05-53's non-hostile portions in dependency order: construction/views, deposit/genesis, withdrawal/compound, math/native-independent behavior. Establish expected values before calls from pre-state and independent fixtures. | AC05-47 rows mapped below pass with exact state/balance/delta/event/error evidence; static derivations are not reported as runtime until executed. |
| **WP5: native, access, hooks, rollback, and hostile characterization** | `WeirNativeAccessHooks.t.sol` and approved peripheral doubles only. | Implement AC48-62 and AC67; real callbacks, valid hook permissions, open-sync ordering, caught versus bubbling failures, self-treasury/self-recipient accounting, return-delta hooks, and exact call-subtree rollback. Keep unsupported token/hook assumptions explicit. | Every reachable branch has exact success/failure evidence; unreachable prescribed states have a precise gap, not injected state or a universal safety claim. |
| **WP6: supported and hostile stateful campaigns** | Handler files, two invariant specs, campaign evidence section. | Use at least three users and two pools sharing one currency, both directions, native/ERC20, donations, transfers, compounds, pause and ownership transitions. Bound inputs to productive cases and count successes and expected reverts. Separate hostile handler/invariants. Record seed, runs/depth and minimized failures. | AC63/64 and fuzz portion of AC47 pass with nonempty successful-action coverage; each failure class and rollback boundary is classified. |
| **WP7: local Robinhood fork parity** | Proposed fork base/spec and VENDOR/fork evidence only. No production source or network config edits. | Preflight archive alias, pin/hash/chain/code; create fresh tokens/pool on reference manager; align fee/pause/roles legitimately; snapshot full fork state; run identical reference/copy sequences with mapped addresses and restoration between branches. | AC65 exact parity evidence, or NOT RUN/BLOCKED naming missing archive inputs/roles. Public deployment-record availability is never reported as transaction parity. |
| **WP8: release evidence and disposition** | `VENDOR.md`, `RELEASE_EVIDENCE.md`, plan traceability updates only. | Reconcile all 37 WI and 69 AC rows to artifacts/results, rerun required gates after any change, distinguish compiler/hermetic/fork/security/licensing, and record unresolved upstream/economic/release limits. | AC66 release review. No production-safety, legal-clearance, upstream-suite, gas, or deployment-readiness claim beyond evidence. |

## 3. Exact hermetic deployment and fixture topology

1. `TestBase_WeirVaults.setUp()` calls `CraneTest.setUp()` before any other setup. Existing factories are therefore initialized normally, but standalone Weir is not registered, proxied, or converted into a package.
2. Deploy canonical `PoolManager` with a test protocol-fee owner, then deploy actual `WeirVaults(manager, treasury, owner)` in the TestBase under the protocol-port allowance. Label all addresses. Do not subclass Weir, etch SUT/manager code, write their storage, or mock their calls/deltas.
3. Deploy ordinary tokens with the existing mintable stub, including non-18-decimal cases. Sort each pair by currency address; use distinct A/B and A/C pools with A<B<C for shared-currency tests. Create native/token and token/token pools without WETH wrapping.
4. Initialize hookless fee-zero F0 at `P=Q`, tick spacing 1. Initialize separate fee-bearing and externally liquid pools for zap/partial-fill tests. Native currency is address zero and participates in normal currency sorting.
5. Use real `PoolSwapTest`/`PoolModifyLiquidityTest` or the minimal auxiliary router to fund external positions and swaps. Their unlock owners settle all of their own deltas. Seed fees through `manager.donate` inside an actual router unlock, not by transferring to Weir or merely settling into the manager.
6. Weir positions arise only through actual deposits/reinvestment. Assert owner `address(weir)`, stored full-range ticks, and `bytes32(0)` salt; neither payer nor recipient owns that position.
7. For hooked pools, choose only the flags needed by the scenario, mine the address with existing `HookMiner`, and deploy the real hook at that address. Record hook calls and settle hook-owned deltas. Do not use a hook address with return-delta flags lacking their corresponding action flags.
8. F0-F3 are separate snapshot-descended fixtures, not one stateful test whose later failure contaminates earlier evidence. F2 and F3 both start from F1's post-compound state.

Common successful-call observation includes pre/post user and recipient balances, all share ledgers including Weir, total shares, vault liquidity/idle/timestamp, real position liquidity/checkpoints, treasury balances, manager deltas for every participant, return values, and exact events. After the top-level unlock-owning operation, use `TransientStateLibrary.isUnlocked(manager)` and participant deltas to prove closure. Do not apply that checkpoint inside callbacks or to unguarded calls made under someone else's unlock.

## 4. Independent arithmetic, observation, and reconciliation design

### 4.1 Oracle rules

`WeirTestOracle.sol` and the test-only wide-integer generator must implement the PRD formulas independently from pre-operation state:

- Implement full-width `MD(x,y,d)` without importing production FullMath or L. Preserve each nested floor and each narrowing stage. Distinguish `int128` BalanceDelta components, `uint128` liquidity/positive fee conversion, `int256` settlement nets, and checked `uint256` products/casts.
- For interior liquidity, independently narrow L0 and L1 before choosing the minimum so AC44 can require overflow in an otherwise unused larger candidate. For reverse conversion, preserve the final division stage and exact failure class.
- Compute deposit balancing from pre-swap spot price, then size from returned signed swap deltas and post-swap price. Do not substitute a constant-product approximation, NAV formula, optimal-ratio solver, or a call to Weir preview/execution as its own expectation.
- Compute issuance from post-compound `T/Lp`, withdrawal liquidity and idle floors separately, and fee cuts per harvest. Keep principal, same-call fees, earlier fees, hook deltas, idle, manager credits, and outer refunds as separate ledger terms.
- For swaps, either independently execute exact V4 tick traversal and rounding in the test-only reference generator or use committed `swap-vectors.json` goldens whose pool state, tick crossings, input, provenance, and expected signed deltas are recorded. Never infer expected partial fills from requested input or constant-product math.

`fixtures/arithmetic-vectors.json` includes F0-F3, AC39/42-46, fee threshold, and raw-decimal vectors. `swap-vectors.json` covers balanced/heavy/single-sided entries, zero input, both withdrawal zap directions, price-limit stops, and exhausted-liquidity partial fills. Generator version and vector hash are release evidence. Numeric fixtures are expectations to verify, not pre-existing test results.

### 4.2 Behavior and ghost ledger

`Behavior_WeirVaults.sol` exposes exact comparisons for full Vault tuples, position tuples, events (emitter/topics/data), typed errors/panics/revert bytes, manager calls, hookData, and balance/delta transitions. `WeirObservation.sol` tracks:

- every assigned share recipient, explicitly including Weir itself;
- the unassigned 1,000 genesis reserve as `T - sum(assigned)`, never `sharesOf(id,0)`;
- per-pool idle and the mapping from physical currency to all pools using it;
- independently tracked direct ERC20/native donations, treasury cuts delivered to Weir, withdrawal proceeds delivered to Weir, and other legitimate unassigned receipts;
- principal/fees/idle/hook deltas separately, plus actual manager deltas for Weir, routers, and hooks.

For an ordinary successful compound phase, independently calculate `Rj`, `Nj`, new recorded idle, cut, physical treasury receipt, and self-treasury unassigned receipt. For deposit, distinguish event `used` from payer net spend after unused-input refund and positive manager credit. For withdrawal, use signed burn + paid idle + zap nets, with minima applied to positive outputs only.

### 4.3 Rollback and asynchronous discipline

Take EVM snapshots with the installed Foundry `vm.snapshotState()` for fixture isolation and restore with `revertToState`/`revertToStateAndDelete` as appropriate; these are not substitutes for asserting the actual failed call's rollback.

For each failure case, identify the reverting invocation boundary before triggering it. Use a low-level call or real catch router where an inner failure must be caught, and compare the complete pre-call observation with the post-failure observation at that boundary. Cover vault creation, shares, liquidity, idle, timestamps, allowances/transfers, native value, treasury cuts, hook effects, and manager deltas. An uncaught failure rolls back the enclosing transaction; a caught inner failure preserves earlier/later successful outer effects and does not close the router's independently owned unlock. A caught rejected reentrant call may allow the outer Weir operation to succeed.

Subscribe to Foundry events/logs and register exact expectations before the action. No sleeps, polling, or timing-luck synchronization. `vm.recordLogs`/`getRecordedLogs` can support execution-log diagnosis but is not receipt-persistence proof; receipt-log claims require an actual receipt in the local-chain evidence path. Never move minima earlier to simplify rollback.

### 4.4 Ordinary invariants versus hostile characterization

Only after successful top-level completion, outside callbacks, and for exact-transfer nonrebasing tokens with no invariant-breaking hook effects:

- stored vault liquidity equals Weir's real salt-zero position liquidity;
- assigned shares sum to `T-1,000` after genesis and to `T` before genesis;
- for each physical currency, Weir's balance equals the sum of every pool's recorded idle for that currency plus independently tracked unassigned inventory; manager-held position assets are separate;
- all participants' required unlock deltas are zero and the manager is relocked.

Shares held by Weir remain ledger claims, not physical inventory. Multiple pools sharing a currency never get separate physical-balance assertions that double-count it. Direct donations and self-directed cuts/withdrawal receipts remain unassigned until source behavior says otherwise.

Do **not** assert universal `idle<=2`, zero unwanted zap output, nonnegative cast safety, strict full input consumption, NAV fairness, or preview==execute. AC55/60/64/67 hostile return-delta, short-delivery, callback, and wrapped-idle states are separate exact characterizations.

## 5. Callback, hook, and failure-sequence plan

- **Deposit:** actual payer supplies native/allowances; recipient may differ. Weir pulls payer funds, unlocks, pre-compounds, optionally swaps once, adds liquidity, and uses the add call's **first** signed caller delta (not second `feesAccrued`) in settlement. Positive manager credits go to payer; outer unused-input refunds also go to payer. Only then are shares credited to recipient and `Deposited` emitted naming recipient. AC16 separately accounts fees earned by old liquidity during the deposit's own zap.
- **Withdraw:** caller's shares are debited before unlock. Pre-compound, compute post-compound proportional burn/idle, remove if nonzero, pay idle into manager, optionally zap, and settle final nets to recipient. Minima are checked after settlement; event names caller. AC37 observes exit-swap fees on remaining liquidity rather than reallocating them to burned shares.
- **Compound:** anyone calls Weir, which owns this unlock. Zero stored liquidity writes timestamp and returns without a poke/event. Nonzero liquidity performs zero-delta modify first; hook observes the real poke and unchanged hookData. Positive components of the first return drive gross fees/cuts; second return is not substituted. Treasury cut 0 precedes cut 1, optional reinvestment follows, settlement goes to Weir, and event emission depends on positive gross fee, not liquidity added.
- **Hook observations:** a valid recording hook covers applicable zero-delta remove-style poke, positive add, negative remove, and swap calls. Record the manager as immediate caller and Weir/router as the hook's sender argument, full params, and identical hookData. Zero-L and zero-calculated-add cases skip their respective operations. `createVault` only reads slot0/writes/emits and triggers no pool hook; initialization is separate setup. Hook reverts assert the real wrapper and exact rollback.
- **Native treasury switch:** with both cuts positive, initial treasury is a callback-capable current owner. The first native `take` invokes its receiver, which calls `setTreasury(T2)` with actual owner authority; the second cut uses T2. If a later failure propagates, the treasury setter and both cuts roll back.
- **Nested unlock/guard order:** outsider callback calls fail `NotPoolManager` before malformed-byte decoding. An independent real unlock owner calling ordinary Weir compound reaches manager `AlreadyUnlocked`; reentry during an active Weir operation reaches the Weir nonReentrant guard first. Test direct, manager-wrapped, and hook-wrapped envelopes as actually observed. Catch and propagate variants must preserve the correct unlock owner.
- **Open sync:** `WeirCatchRouter` syncs a nonnative currency before a positive native-pay Weir call, then either catches or propagates the manager's native-value failure. A second construction leaves sync open from a legitimate callback during unlock. No intervening clear and no `sync(0)` repair are allowed. Earlier router effects persist only in the caught variant.

## 6. Local fork parity recipe

1. Use only `FOUNDRY_PROFILE=fork` and `test/foundry/fork/**`. Resolve `vm.rpcUrl("robinhood_mainnet_alchemy")` (or another already configured, verified archive-capable Robinhood alias) and fork at `ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK`. Do not add `WEIR_RPC_URL`, a private block constant, or a substitute chain.
2. Before any parity action, require chain ID 4663, block number 76,197,114 and supplied block hash, and nonempty code at reference Weir `0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110` and manager `0x8366a39CC670B4001A1121B8F6A443A643e40951`. Record actual alias/block/hash and code checks. The two public aliases' historical-state failure means they cannot satisfy this preflight.
3. Deploy fresh exact-transfer peripheral tokens and initialize a new hookless pool on the reference manager whose PoolId is absent from both reference Weir and the deployed copy. Deploy the copy against that same manager. Map reference constructor/owner/treasury/user addresses to explicit local copy roles; use local impersonation, never production private keys.
4. Read reference fee/pause/role state and align equivalent conditions through legitimate local calls where required. Record selected-pool position, inventory, fee checkpoints, token funding, allowances, and role provenance. Do not assume global `allVaults` prefixes or unrelated positions match.
5. Complete common setup, then take a full `snapshotState`. Run the reference sequence and capture exact returns/reverts/events, selected-pool balances/deltas/positions, and mapped user/treasury balances. Restore the full snapshot and run the identical copy sequence with only the documented address mapping. Repeat independently for create/deposit/compound/withdraw and native/ERC20 where feasible.
6. Never inject source/storage, use a production wallet key, send a live write, or compare against a different chain. Missing archive state, credentials, or necessary role equivalence fails preflight or is recorded **NOT RUN/BLOCKED** with the exact action; it is not skipped as pass and does not waive hermetic failures.

## 7. Build, test, and evidence commands

These are future commands, not commands run for this original. Seed a new/empty worktree from warm `out/` and `cache_forge/` before its first compile. Preserve both directories, configured source/test paths, and default/fork isolation; serialize writers. Never delete caches, change `FOUNDRY_TEST`, add a profile, enable viaIR, or kill a slow compiler for silence.

After the three production edits, run the focused build-before-test workflow with every edited source:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/protocols/strategy/weir/WeirVaults.sol \
  contracts/protocols/strategy/weir/base/WeirBase.sol \
  contracts/protocols/strategy/weir/libraries/LiquidityAmounts.sol \
  --test-root test/foundry/spec/protocols/strategy/weir
```

Then run the required broader hermetic gates in order, only after the preceding gate succeeds:

```bash
forge build
forge test --match-path 'test/foundry/spec/protocols/strategy/weir/**' -vvv
forge test
```

Fork build and local-only fork tests are a separate evidence ladder:

```bash
FOUNDRY_PROFILE=fork forge build
FOUNDRY_PROFILE=fork forge test \
  --match-path 'test/foundry/fork/protocols/strategy/weir/**' -vvv
```

The existing `fmt.skip` configuration warning is unrelated and must not trigger a config fix here. Report separately: (a) compiler and static fidelity success, (b) real-manager hermetic proof, (c) actual archive-backed fork parity or BLOCKED, (d) adversarial/security characterization with reachability gaps, and (e) license/release disposition. None substitutes for another.

## 8. Complete AC01-AC69 execution matrix

Status meanings: **PLANNED** = executable future hermetic/static test, not run; **STATIC** = non-runtime evidence gate; **CONDITIONAL** = attempt with real contracts and record an exact reachability gap if the prescribed state cannot be built; **BLOCKED-INPUT** = currently lacks archive credentials/state; **RELEASE** = final evidence review. Every successful runtime row also applies WI-33 observations; every failure row applies WI-30 at its named boundary.

| AC | Proposed file/class/method or gate | Construction / precondition | Primary exact assertion | WP | Status |
|---|---|---|---|---|---|
| AC01 | Static import-transform gate; `IMPORT_TRANSFORM.json` | Normalize only the 22 imports, five free-type uses, and recorded WI-06 diffs against frozen W/B/L. | No unlisted edit; comments/notices/storage/business behavior retained; hashes and actual diagnostics recorded. | 1/2 | STATIC |
| AC02 | `WeirSourceAndSurface.test_AC02_ABIAndSurfaceExactlyMatchesFrozenMetadata` | Compare compiled ABI and surface with verbatim frozen metadata ABI. | Exactly 27 functions, constructor, receive, 11 events, 18 errors; tuples, outputs, mutability and indexing identical. | 2 | PLANNED |
| AC03 | Default-profile build gate | Build with solc 0.8.35/runs1/viaIR=false; record and narrowly fix only actual stack-depth diagnostics. | Build succeeds without config/viaIR change and fidelity/behavior checks rerun, or exact blocker is reported. | 2 | STATIC |
| AC04 | License disposition gate in VENDOR | Inspect frozen 39 entries and actual graph's full declarations/version links. | All entries and BUSL date/ENS/grant/anniversary plus GPL-old/MIT-new ambiguity recorded; no inferred clearance. | 1/8 | STATIC |
| AC05 | `WeirSourceAndSurface.test_AC05_ConstructorBindingsAndZeroAddressCases` | Valid manager/treasury/owner; independent zero treasury, zero owner, zero manager deployments. | Getters/defaults/events exact; zero treasury `ZeroAddress`, zero owner `OwnableInvalidOwner(0)`, zero manager accepted. | 4 | PLANNED |
| AC06 | `WeirSourceAndSurface.test_AC06_CreateDistinctVaultsAndSharedCurrency` | Two initialized keys differing in a complete field, including shared currency. | Distinct IDs/ticks, zero accounting, exists, ordered array/count, exact `VaultCreated`. | 4 | PLANNED |
| AC07 | `WeirSourceAndSurface.test_AC07_CreateFailuresAndArrayBounds` | Duplicate key, uninitialized key, `allVaults(count)`. | `VaultExists`, `PoolNotInitialized`, `Panic(0x32)` respectively; no extra entries/logs. | 4 | PLANNED |
| AC08 | `WeirSourceAndSurface.test_AC08_UnknownAndEmptyVaultViews` | Unknown PoolId and empty created vault. | Unknown full default struct/zero quotes/shares; created key/ticks/exists retained with zero quotes. | 4 | PLANNED |
| AC09 | `WeirDeposit.test_AC09_F0PayerRecipientGenesisAndRefunds` | F0, payer A != recipient B. | K liquidity/T, B gets K-1000, A gets two-unit refunds and pays K each; event B; Weir salt-zero position. | 4 | PLANNED |
| AC10 | `WeirDeposit.test_AC10_GenesisThreshold1002And1003` | Fresh tick-zero pools, paired 1,002 then 1,003 inputs. | First `ZeroShares`; second L=1001, one user share, two-unit refunds. | 4 | PLANNED |
| AC11 | `WeirDeposit.test_AC11_ZeroOneTwoAndOneSidedInputs` | Fresh/existing vaults; 0/1/2 legs and one-sided non-zap deposits at interior price in both token directions. | Every zero resulting liquidity/share branch reverts `ZeroShares`; no credit from transfers or idle. | 4 | PLANNED |
| AC12 | `WeirDeposit.test_AC12_SecondPairedIssuance` | F0 followed by identical fee-free paired deposit. | Second shares K; L=T=2K; reserve difference 1000; first holder unchanged. | 4 | PLANNED |
| AC13 | `WeirDeposit.test_AC13_PrecompoundBeforeIssuance` | Real pending fees before paired deposit. | Pre-compound state applied first; shares=floor(newL*postCompoundT/postCompoundL), not pre-compound denominator. | 4 | PLANNED |
| AC14 | `WeirDeposit.test_AC14_F3IdleDilution` | F1 post-compound then second K+2 paired deposit. | Second shares K, L=T=2K, idle0=19, second user's idle0 claim 9; no NAV charge. | 4 | PLANNED |
| AC15 | `WeirDeposit.test_AC15_ZapDirectionsZeroAndPostSwapSizing` | External-liquidity pool; balanced, 0-heavy, 1-heavy, single-sided, and x=0 cases. | Exact nested-floor direction/input, at most one swap, returned deltas and post-swap price drive exact shares/refunds. | 4 | PLANNED |
| AC16 | `WeirDeposit.test_AC16_SameSwapFeesStayWithPayer` | Existing Weir liquidity in fee-bearing pool; another payer zaps. | Same-zap fees appear in add first return, reduce payer used/become credit; no second cut or incumbent credit. | 4 | PLANNED |
| AC17 | `WeirDeposit.test_AC17_MinSharesEqualityAndLateRollback` | Equivalent fixtures with minShares S and S+1. | Equality succeeds; S+1 `Slippage` after callback and restores auto-creation, funds, fees, position and logs at Weir call boundary. | 4 | PLANNED |
| AC18 | `WeirDeposit.test_AC18_TransferRecipientsUnknownZeroSelfAndOverspend` | Shares in one pool; transfer to user/self/Weir; zero on unknown; zero recipient; overspend. | Per-pool conservation/events, self unchanged after balance check, Weir shares tracked, unknown zero succeeds, `ZeroAddress`, `Panic(0x11)`. | 4 | PLANNED |
| AC19 | `WeirDeposit.test_AC19_PauseOnlyDeposits` | Funded paused vault; invoke every listed surface. | Deposit `EnforcedPause`; create/transfer/compound/withdraw/views/receive retain independent outcomes. | 4 | PLANNED |
| AC20 | `WeirDeposit.test_AC20_DepositValidationOrder` | Simultaneous paused/reentrant/expired/zero-recipient/native-invalid combinations and isolated replays. | Pause, guard, deadline precedence; recipient before auto-create/native/pull; exact specified errors. | 4 | PLANNED |
| AC21 | `WeirWithdrawCompound.test_AC21_F0FullAssignedWithdrawal` | F0 user burns all assigned shares, zap0, different recipient. | Outputs 1,047,575 each; caller ledger zero; L=T=1000; idle zero; event caller. | 4 | PLANNED |
| AC22 | `WeirWithdrawCompound.test_AC22_PostCompoundProportionalBurnAndIdle` | Real fees/idle then proper-subset withdrawal. | Compound first; liquidity and idle floors independently use post-compound T; exact state/recipient amounts, no sweep. | 4 | PLANNED |
| AC23 | `WeirWithdrawCompound.test_AC23_TinyWithdrawalConditionalBranches` | Real fee/idle states sized for zero removed L with nonzero idle, and all-zero claims. | No removal when L=0; nonzero idle still paid; zero-output burn allowed at minima zero; otherwise exact gap. | 4 | CONDITIONAL |
| AC24 | `WeirWithdrawCompound.test_AC24_ZapModesAndSignedSettlement` | Equivalent zap0/1/2 withdrawals with ample liquidity. | No swap / sell 1 for 0 / sell 0 for 1; exact requested positive leg and signed-delta outputs/settlement. | 4 | PLANNED |
| AC25 | `WeirWithdrawCompound.test_AC25_PartialFillsBothDirections` | Price near each usable boundary with finite liquidity and oversized real zap input. | Swap stops at limit/exhaustion; unsold currency remains positive and is delivered in both directions; no consumption revert. | 4 | PLANNED |
| AC26 | `WeirWithdrawCompound.test_AC26_MinimaEqualityAndRollback` | Replay outputs (a,b), minima (a,b), (a+1,b), (a,b+1). | Equality succeeds; each excess `Slippage` restores shares, position, timestamp, fees, idle, balances and logs despite prior payment. | 4 | PLANNED |
| AC27 | `WeirWithdrawCompound.test_AC27_WithdrawValidationOrder` | Valid deadline; zap3, zero recipient, unknown key, zero shares, insufficient balance; expired variant. | Ordered `BadZap`, `ZeroAddress`, `NoVault`, `ZeroShares`, `Panic(0x11)`; deadline first when expired. | 4 | PLANNED |
| AC28 | `WeirWithdrawCompound.test_AC28_EmptyCompoundTimestampNoPoke` | Known empty vault; anyone compounds at t and t+1. | uint64 timestamps update; no manager poke, fees, transfers, event, or empty-position error. | 4 | PLANNED |
| AC29 | `WeirWithdrawCompound.test_AC29_UnknownCompoundNoVault` | Unknown key compound. | `NoVault` before unlock; no timestamp/state change. | 4 | PLANNED |
| AC30 | `WeirWithdrawCompound.test_AC30_F1DonationCutAndSecondNoEvent` | Real donate20 currency0 through auxiliary unlock, then compound twice. | First gross20/cut1/idle19/L unchanged/event exact; second no event, idle19, timestamp updated. | 4 | PLANNED |
| AC31 | `WeirWithdrawCompound.test_AC31_F2Reinvest` | From F1, donate20 currency1 and compound. | Gross(0,20), cut(0,1), added17, idle(2,2), T unchanged, exact event/payments. | 4 | PLANNED |
| AC32 | `WeirWithdrawCompound.test_AC32_FeeThresholdsAndSelfTreasury` | Real gross19/20 and bps0/500/1000; F1 with treasury=Weir. | Per-currency floor cuts (0/1 at500); self-treasury physical receipt20, idle19, extra1 unassigned and never auto-booked. | 4 | PLANNED |
| AC33 | `WeirWithdrawCompound.test_AC33_IdleOnlyAdditionNoEvent` | Accrue one-sided idle, move price by real swaps, choose compound with no newly harvested positive component. | Exact idle-only L/idle change, T fixed, no `Compounded`; distinguish price-swap fees or record gap. | 4 | CONDITIONAL |
| AC34 | `WeirWithdrawCompound.test_AC34_DonationsAndSelfRecipientUnassigned` | Direct ERC20/native donations before/after F0; F0 full withdrawal to Weir. | Donations change no ledger/quote; self-withdrawal returns 1,047,575 each physically, idle0/1 zero, L=T=1000, receipts unassigned; receive no vault event. | 4 | PLANNED |
| AC35 | `WeirWithdrawCompound.test_AC35_SharedCurrencyIsolation` | Fund A/B and A/C, independently accrue idle and operate one. | Only selected vault changes in ordinary case; physical A equals both idle claims plus tracked unassigned inventory. | 4 | PLANNED |
| AC36 | `WeirWithdrawCompound.test_AC36_MissingAllowanceOrBalanceDespiteInventory` | Preseed Weir inventory; exact-transfer deposit without allowance or payer balance. | Token-specific exact failure, no shares or inventory loss; short delivery deferred to AC55. | 4 | PLANNED |
| AC37 | `WeirWithdrawCompound.test_AC37_ExitSwapFeesRemainForRemainingPosition` | Burn then zap in fee-bearing pool; inspect remaining position checkpoints/growth. | Exit-swap fees belong to remaining real liquidity, not burned shares or automatic second harvest; exact later pending/compound floors. | 4 | PLANNED |
| AC38 | `WeirViewsAndMath.test_AC38_PreviewFractionsAndOversizedOwnership` | F0 and fee/idle variants; shares zero/fraction/all T/more than caller owns. | Exact independent downward amounts plus idle floors; no ownership check/mutation; T=0 avoids manager reads. | 4 | PLANNED |
| AC39 | `WeirViewsAndMath.test_AC39_PreviewCastAndCheckedProductBoundaries` | F0 L=T=2^20; s=2^128+7, then 2^236; separate T=0. | First truncates to L=7 and quotes6/6; second `Panic(0x11)`; zero supply returns(0,0). | 4 | PLANNED |
| AC40 | `WeirViewsAndMath.test_AC40_PreviewVsCompoundAndZap` | Pending fees before preview and actual no-zap/zap withdrawals; controlled no-maintenance equality fixture. | Preview excludes pending/maintenance/zap and uses its formula; execution uses separate formula; equality only in valid fixture. | 4 | PLANNED |
| AC41 | `WeirViewsAndMath.test_AC41_PendingFeesRangesAndModularVectors` | Real nonzero position and fee growth below/inside/above range where reachable; independent modular vectors. | Exact modular fee-growth subtraction and Q128 floor using actual position L, gross of fee, no mutation. | 4 | PLANNED |
| AC42 | `WeirViewsAndMath.test_AC42_LibraryAnchorAndSortedBounds` | Actual L exposure, A=Q,B=2Q, amount3, reversed bounds; reverse at L=7. | L0=6,L1=3 in both orders; amount0=3,amount1=7. | 4 | PLANNED |
| AC43 | `WeirViewsAndMath.test_AC43_LibraryInteriorAndBoundaryBranches` | Bounds Q/2,2Q; P=Q amounts(3,4); L=7; P=A and P=B. | Interior L=min(6,8)=6 and amounts(3,3); exact outer branch at both boundaries. | 4 | PLANNED |
| AC44 | `WeirViewsAndMath.test_AC44_SeparateNarrowingOverflow` | Interior P=Q, bounds Q/2,2Q; amounts(2^127,1) then(1,2^127). | Each reverts `Error("liquidity overflow")` in its own overflowing branch before minimum. | 4 | PLANNED |
| AC45 | `WeirViewsAndMath.test_AC45_LibraryFailureStages` | Equal nonzero bounds for liquidity; A=0,B=Q,L=1 amount0 conversion. | FullMath empty revert for zero denominator, then final `/A` `Panic(0x12)`; no new range error. | 4 | PLANNED |
| AC46 | `WeirViewsAndMath.test_AC46_TimestampTruncationAndDeadlineEquality` | Empty compound at 2^64-1,2^64,2^64+7; valid deposit/withdraw deadlines t and t-1. | Stored timestamps max/0/7; equality accepted, t-1 `Expired`, failed calls restore prior timestamp. | 4 | PLANNED |
| AC47 | `WeirViewsAndMath.test_AC47_FuzzArithmeticRawUnits` | Independent valid-domain fuzz for L and deposit/withdraw proportions plus overflow boundaries and non-18-decimal raw units. | Exact nested-floor/cast result and error class for every case; no decimal normalization. | 4/6 | PLANNED |
| AC48 | `WeirNativeAccessHooks.test_AC48_NativeValueAndRefund` | Native/ERC20 paired and zapped deposits with exact, +/-1 value; ERC20/ERC20 value1; payer != recipient. | Correct native paths settle/refund without WETH; wrong values `BadNativeAmount`; native refund to payer. | 5 | PLANNED |
| AC49 | `WeirNativeAccessHooks.test_AC49_RejectingPayerRefund` | Payer contract rejects nonzero native refund; zero-refund replay. | Nonzero refund `NativeTransferFailed()` and full rollback; zero refund makes no call and succeeds despite receiver. | 5 | PLANNED |
| AC50 | `WeirNativeAccessHooks.test_AC50_ManagerTakeErrorEnvelope` | Native output/treasury cut to rejecting receiver with known nested bytes. | Exact manager currency-transfer wrapper/nested bytes, not Weir refund error; no retained burn/cut after failure. | 5 | PLANNED |
| AC51 | `WeirNativeAccessHooks.test_AC51_OpenERC20SyncNativePay` | Router pre-sync and legitimate callback open-sync before positive native pay; caught and uncaught variants. | Real `NonzeroNativeValue` envelope; Weir subtree rollback; earlier sync persists only when caught; outer unlock ownership preserved. | 5 | PLANNED |
| AC52 | `WeirNativeAccessHooks.test_AC52_AdminMatrix` | Owner/nonowner/pending owner; bps0/500/1000/1001; zero/repeated treasury. | Only owner succeeds; typed unauthorized error before body; cap/zero errors; accepted no-change setters emit exact values. | 5 | PLANNED |
| AC53 | `WeirNativeAccessHooks.test_AC53_OwnershipLifecycle` | Start/replace/cancel/accept/renounce, wrong accepter, pause-then-renounce fixture. | Exact current/pending transitions/events/errors; pending cleared; former owner cannot unpause after renunciation. | 5 | PLANNED |
| AC54 | `WeirNativeAccessHooks.test_AC54_GuardedReentryCaughtAndBubbled` | Actual token/hook/treasury/recipient/payer callbacks at pull/hook/take/refund; paused variants. | Guarded reentry exact guard error where reached; paused deposit `EnforcedPause`; caught may succeed, bubbling rolls back exact boundary. | 5 | PLANNED |
| AC55 | `WeirNativeAccessHooks.test_AC55_TokenReturnAndShortDelivery` | Token false/no-return-with-delivery/explicit revert/success-short-delivery; separate preseeded inventory. | False typed SafeERC20 error, revert bytes bubble, real no-return accepted; exact short-delivery balances/outcome with no safety claim. | 5 | PLANNED |
| AC56 | `WeirNativeAccessHooks.test_AC56_UnguardedCallbacksAndRoles` | Legitimate callbacks invoke transfer/create/views; actual owner invokes setters/ownership with needed shares/roles. | Only native access/balance checks apply; token caller moves own shares; exact caller/order/intermediate views/errors. | 5 | PLANNED |
| AC57 | `WeirNativeAccessHooks.test_AC57_NativeTreasuryChangesBetweenCuts` | Native currency0, both cuts positive, first receiver is current owner and sets T2. | Both cuts precomputed; first paid old treasury, second T2; any propagated failure rolls back setter and payments. | 5 | PLANNED |
| AC58 | `WeirNativeAccessHooks.test_AC58_CallbackCallerNestedUnlockAndGuardOrder` | Outsider valid/malformed callback bytes; real unlock owner calls compound caught/uncaught; active-operation reentry. | Outsider `NotPoolManager` before decode; nested `AlreadyUnlocked`; active reentry guard first; exact direct/wrapped errors and unlock state. | 5 | PLANNED |
| AC59 | `WeirNativeAccessHooks.test_AC59_HookDataOrderingAndZeroDeltaOperations` | Nonzero-L recording-hook pool; positive reinvestment plus zero-L/zero-add cases and reverting hook. | Unchanged bytes; actual poke before reinvestment/user action; zero cases skip; createVault no hook; exact wrapped failure/rollback. | 5 | PLANNED |
| AC60 | `WeirNativeAccessHooks.test_AC60_ReturnDeltaFirstReturnAndSettlement` | Legitimate return-delta hook makes poke caller delta differ from informational fees, including negative component; hook settles its own deltas. | Gross uses positive first-return components; any unaccounted negative Weir delta causes real `CurrencyNotSettled`; exact source outcome. | 5 | PLANNED |
| AC61 | `WeirNativeAccessHooks.test_AC61_IntermediateViews` | Hostile receiver observes during treasury payment, withdrawal settlement, deposit refund. | Exact intermediate states: withdrawal debit before compound, deposit recipient credit before refund; no end-state invariant asserted mid-callback. | 5 | PLANNED |
| AC62 | `WeirNativeAccessHooks.test_AC62_NonpayableAndReceive` | Low-level native-value calls to each nonpayable baseline method; separate empty-calldata native transfer. | Nonpayable dispatch's concrete compiled revert data; receive succeeds with unchanged ledger and no invented domain error. | 5 | PLANNED |
| AC63 | `WeirInvariant.invariant_AC63_SupportedDomainLedgerAndSettlement` | Deterministic handler, >=3 users, >=2 pools/shared currency, exact-transfer tokens, all ordinary actions/donations. | At successful top-level checkpoints only: L=positionL, assigned=T-1000, physical shared-currency reconciliation, closed deltas/relock; rollback classes exact. | 6 | PLANNED |
| AC64 | `WeirHostileInvariant.invariant_AC64_HostileOutcomesClassified` | Separate hostile callbacks/rejects/short-delivery/return-delta/partial-fill/pause/owner campaigns. | Every outcome has exact success ledger or classified error/trace; ordinary invariants are not applied across hostile assumptions. | 6 | PLANNED |
| AC65 | `WeirRobinhoodParityFork.test_AC65_ReferenceVsCopyParity` | Archive chain4663 at shared pin/hash, code preflight, fresh pool/tokens, mapped roles, full snapshot branches. | Exact reference/copy returns/reverts/events and mapped balances/positions; direct deployment evidence recorded; missing inputs BLOCKED, never pass. | 7 | BLOCKED-INPUT |
| AC66 | Final release evidence review | Reconcile VENDOR, transform/ABI/layout/graph, commands, all test/campaign/fork evidence and open gates. | Every WI/AC has actual evidence or explicit unresolved gate; no excessive parity/safety/legal claim. | 8 | RELEASE |
| AC67 | `WeirNativeAccessHooks.test_AC67_NegativeIdleSumWrapsWhenReachable` | Valid return-delta pool, real add/reinvestment with oldIdle+net=-1, independently donated physical funds, hook settles itself. | If reached, idle=2^256-1 and exact physical/delta ledger; any earlier/later failure rolls back; otherwise precise reachability gap, no fail-closed claim. | 5 | CONDITIONAL |
| AC68 | `WeirSourceAndSurface.test_AC68_CanonicalOZUsedSurfaceAndSequentialLayout` plus dependency runtime cases | Separate six byte-identical V5 files from SafeERC20 used paths; compile layout/ABI and token/owner/pause/guard cases. | Six file identities and sequential inherited storage; SafeERC20 true/false/no-return/revert parity; no mixed Context or namespaced upgrade. | 2/5 | PLANNED |
| AC69 | Actual resolved import-graph and license gate | Traverse production and test graphs after build against original 39-file map. | Runtime-only additions such as hashing helper/BSL/AGPL and test-only dependencies distinguished; every license/gate explicit. | 2/8 | STATIC |

## 9. Complete WI01-WI37 traceability map

| WI | Work packages / artifacts | Acceptance and evidence linkage |
|---|---|---|
| WI-01 Domain destination | WP1 three exact production paths; frozen corpus untouched. | AC01; tree/static gate proves no second domain tree. |
| WI-02 Source preservation | WP1 transform manifest; WP2 WI-06 diffs, ABI/layout and behavior reruns. | AC01-03, AC68; all runtime suites guard behavior. |
| WI-03 Provenance record | WP1/WP2/WP7 VENDOR, transform JSON, deployment and graph evidence. | AC01, AC04, AC65, AC66, AC69. |
| WI-04 Dependency routing | WP2 canonical used-surface comparison, PoolOperation field proof, StateLibrary/hash/layout checks, frozen L retained. | AC02-03, AC42-45, AC68-69; mismatch stops import acceptance. |
| WI-05 License disposition | WP1 inventory, WP2 actual graph, WP8 release disposition. | AC04, AC69; unresolved links remain release gates. |
| WI-06 Compiler contract | WP2 default build and only authorized stack refactors with diagnostics. | AC01, AC03 and subsequent fidelity/behavior suites. |
| WI-07 Exclusions | WP1/WP2 static surface/tree review and WP8 scope review. | AC02 proves no invented surface; AC66 confirms no excluded adaptation/remediation. |
| WI-08 Pool identity and position | WP3 sorted initialized pools and real salt-zero position observers; WP4 creation/deposit tests. | AC06-09, AC35, AC63. |
| WI-09 Struct and enum layout | WP2 ABI tuple/layout comparison and WP4 full-Vault observations. | AC02, AC06, AC08. |
| WI-10 Surface inventory | WP2 generated ABI; WP4/WP5 constructor, views, getters, users, callback, admin, ownership and receive tests. | AC02, AC05-08, AC62. |
| WI-11 Unlock and callback provenance | WP3 real manager unlock topology; WP4 pre-compound ordering; WP5 nested/caught callback tests. | AC13, AC28-29, AC51, AC54, AC58-59. |
| WI-12 Deposit ordering and attribution | WP4 payer/recipient fixtures and validation/rollback observations. | AC09, AC17, AC19-20, AC36, AC48-49, AC54, AC61. |
| WI-13 Liquidity sizing and genesis | WP3 independent L oracle; WP4 threshold/F0 fixtures. | AC09-11, AC63. |
| WI-14 Subsequent issuance | WP4 post-compound denominator and idle-dilution fixtures. | AC12-14. |
| WI-15 Signed deposit settlement | WP3 signed ledger oracle; WP4 zap/same-call fee cases; WP5 return-delta characterization. | AC09, AC15-16, AC60. |
| WI-16 Per-pool transfers | WP4 transfer matrix and ghost share ledger; WP5 legitimate callback transfers. | AC18-19, AC56, AC63. |
| WI-17 Withdrawal entry | WP4 validation/minima/rollback and caller/recipient attribution. | AC21-27, AC34, AC37, AC61. |
| WI-18 Proportional burn and idle | WP3 independent burn/idle floors; WP4 removal/pay/zap settlement cases. | AC21-26, AC34, AC63. |
| WI-19 Zap heuristic | WP3 pre/post price oracle and exact swap goldens; WP4 direction fixtures. | AC15, AC24-25. |
| WI-20 Swap limits and partial fills | WP4 real externally liquid pools, price-limit/exhaustion cases and signed outputs. | AC15, AC24-25. |
| WI-21 Compound order and zero liquidity | WP4 zero-L/timestamp/donation cases; WP5 hook poke and return-delta observations. | AC28-31, AC46, AC59-60. |
| WI-22 Fee and reinvestment accounting | WP3 fee/idle oracle; WP4 F1/F2/threshold/idle-only; WP5 treasury and wrapped-idle cases. | AC13, AC22, AC30-33, AC57, AC60, AC67. |
| WI-23 Events and phase attribution | WP3 exact event subscription; WP4 deposit/withdraw/compound phase fixtures. | AC13, AC16, AC30-33, AC37, AC59. |
| WI-24 Inventory partition | WP3 multi-pool/unassigned ghost ledger; WP4 donations/self receipts/shared currency; WP6 reconciliation. | AC14, AC32, AC34-36, AC55, AC63, AC67. |
| WI-25 View semantics | WP4 unknown/empty views, independent preview and pending-fee state/range vectors. | AC08, AC38-41. |
| WI-26 Administration | WP5 owner/pause setter matrix and callback authority cases. | AC19, AC52-54, AC56-57. |
| WI-27 Ownership | WP4 constructor and WP5 complete two-step/renunciation lifecycle; WP2 OZ identity. | AC05, AC52-53, AC56, AC68. |
| WI-28 Guard coverage | WP5 real callback reentry into guarded/unguarded groups and intermediate observations. | AC54, AC56-61, AC63-64. |
| WI-29 Native and ERC20 plumbing | WP5 native values/refunds/take envelopes/open sync/token return cases. | AC34, AC36, AC48-51, AC55, AC57, AC62. |
| WI-30 Deadline and rollback | WP3 boundary snapshot framework; every WP4/WP5 failure row and caught/uncaught router design. | AC17, AC20, AC26-27, AC46, AC49-51, AC54, AC57-60, AC63. |
| WI-31 Errors and arithmetic fidelity | WP2 ABI/errors/dependency behavior; WP4 math/panics; WP5 propagated envelopes; no bare expectRevert. | AC02, AC39, AC42-47, AC50, AC55, AC62, AC67-68. |
| WI-32 Real system under test | WP3 CraneTest + actual manager/Weir, real routers/hooks and peripheral-only doubles. | Common precondition for AC05-64; static harness review in AC66. |
| WI-33 Exact observations | WP3 Behavior/WeirObservation; all successful/failure rows use full state/delta/event evidence. | All runtime AC rows, especially AC59 and AC63. |
| WI-34 Independent expectations | WP3 independent oracle, wide-integer generator and committed arithmetic/swap fixtures. | AC09-47 and AC67; no SUT-derived expected values. |
| WI-35 Characterization discipline | WP4 conditional branch gaps; WP5 hostile doubles/hooks; WP6 separate campaigns. | AC23, AC25, AC33, AC35-36, AC51, AC55, AC60, AC64, AC67. |
| WI-36 Campaigns and release record | WP6 productive handlers, counters, seeds/settings/minimization; WP8 evidence ledger. | AC47, AC63-64, AC66. |
| WI-37 Build and local fork gates | WP2 artifact workflow, WP7 isolated fork profile/alias/shared pin/archive preflight. | AC03, AC65, AC69; blocked fork never treated as pass. |

## 10. Limits, escalation rules, and completion criteria

- A canonical mismatch outside the 22 imports/five free types/authorized WI-06 techniques is a stop-and-report decision, not permission to edit Weir or shared dependencies until behavior happens to pass.
- Compiler success proves only compilation under local settings. It does not reproduce upstream bytecode, establish runtime fidelity, or clear licensing. ABI equality alone does not prove storage reads or math equivalence.
- No upstream Git pin, upstream test suite, or audit is supplied. Do not claim those suites were ported or that an audit exists. Independently authored tests are evidence only for what they execute.
- If AC23/33/67 or another prescribed hostile branch cannot be reached through real manager/token/hook interactions, preserve the test as a documented reachability investigation and report the exact missing construction. Never etch/store/mock a pass or convert the gap into a safety assertion.
- The source's comments about locked shares, inflation blocking, hooked pools, or growing share value remain source text, not acceptance properties. No NAV fairness, universal hook compatibility, idle bound, full-consumption, or economic-safety conclusion is permitted.
- Actual resolved BUSL/BSL, GPL, AGPL, ENS/grant/version provenance and distribution implications require explicit release disposition. GPL/AGPL are open source; BUSL is source-available with its declared restrictions. No automatic June 2027 expiry, grant coverage, old-GPL/new-MIT selection, or legal clearance is inferred.
- Fork deployment receipts and public block/transaction reads are not archive transaction parity. Absent `ALCHEMY_KEY`/archive state, AC65 remains NOT RUN/BLOCKED while hermetic results retain their own separate status.

The implementation phase is complete for this baseline only when WP1-WP6 evidence is green, every AC/WI is accounted for, and all unresolved WP7/WP8 gates are stated verbatim. Production release remains separately gated; a faithful, well-characterized copy is not a declaration of economic safety or deployment readiness.