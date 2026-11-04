# Astra original: Weir source-import implementation and testing plan

## Identity, question, and authority

Member: Astra, independent original for `weir-source-import-plan-20261029-01a18660`, dated 2026-10-29. Requested route: `chatgpt-subscription/gpt-6-astra:high`. This is the assigned member identity, not an independently obtained runtime-route attestation: no private runtime or authentication metadata was inspected, and no model or provider substitution was requested or performed by this contribution.

Question: how should an implementer faithfully import the owner-clarified Weir baseline, establish dependency compatibility, and discharge all 37 WI requirements and 69 AC rows without silently converting it into another product?

Authority is the complete frozen `inputs/PRD.md`, revision `weir-import-prd-owner-clarifications-20261029`. Its supplied SHA-256 is `c9316907a22d3ea0c2568aed74053a8911812fc1a6c424d162cb805e3ab4a551`; the supplied size is 96,598 characters. These are coordinator identity evidence, not my independent hash attestation. I read the entire brief, entire frozen PRD including appendices, and all 427/88/68 lines of W/B/L. W, B, and L below mean the three frozen domain files identified in the PRD, not an alternate upstream tree.

This is an implementation/testing-plan contribution, not another PRD, implementation authorization, an audit, or a declaration that tests passed. Every newly named file, class, method, fixture, and work package below is **proposed**, unless explicitly described as inspected existing infrastructure. No new peer original was read.

### Evidence classes

| Class | Meaning in this contribution |
|---|---|
| Source observation | Direct reading of the frozen W/B/L or the specifically identified current repository source. It establishes what the text says, not successful execution. |
| Supplied evidence | The PRD/brief reports prior source hashes, license research, deployment records, or the prior shared-constant checks. I did not rerun those checks. |
| Proposed construction | A future fixture, algorithm, file, or sequence supported by the source. Even a numerically concrete construction is unrun here. |
| Unverified gate | Compilation, ABI/layout generation, behavior, adversarial reachability, archive parity, or release disposition still requiring evidence. |

The source import remains standalone. Do not add ERC20/ERC4626, a Rate Provider, NAV issuance, SE/Diamond conversion, a manager registry entry, unlocked-hook adaptation, strict single-output execution, rescue methods, or economic repairs. Keep the original comments, but do not adopt their economic claims as invariants.

The brief explicitly resolves generic-rule conflicts. In particular, `crane-porting/SKILL.md` says "After large moves: `rm -rf cache out` then `forge build`" and lists a minimum Service wrapper. `crane-porting-verification/SKILL.md` says "Preview parity ... preview == execute result." Those are generic requirements in those files, but are expressly overridden here by the root warm-artifact law and WI-07/WI-25: preserve `out/` and `cache_forge/`, add no wrapper, and test preview's own formula rather than unconditional execution equality. Likewise, generic fork examples under `spec` and RPC environment-variable examples do not replace the root `fork` profile and configured aliases.

## Source observations that determine the plan

1. W's deposit and withdrawal callbacks compound before their user action. Deposit's share-recipient credit occurs only after unlock returns and slippage passes, before refunds. Withdrawal debits the caller before unlock, while its liquidity/total-share reduction occurs later in `_withdraw`. These are distinct observable phases.
2. W uses the **first** `modifyLiquidity` return for all accounting. The inspected canonical manager first combines principal and fees, then applies the hook return delta. The second return remains informational `feesAccrued`. A test that equates these returns cannot validate hook behavior.
3. The inspected `Hooks.sol` dispatches `liquidityDelta <= 0` through remove-liquidity hooks. A zero poke therefore uses applicable before/after-remove callbacks, not an invented poke callback. W's `createVault` only reads manager state and records a vault; it does not initialize a pool or call a hook.
4. B pays native currency with payable `settle` and no native sync. The inspected manager permits `sync` even while locked and rejects positive native value when a non-native sync remains current. This gives a concrete same-transaction ordering test.
5. The inspected canonical `StateLibrary` derives pool/tick/position slots using `BetterEfficientHashLib`; slot constants alone are insufficient. `Position.calculatePositionKey` hashes 58 packed bytes: owner, two signed three-byte ticks, and salt.
6. Canonical `BalanceDelta` has two signed `int128` components. Positive fee components cannot exceed `2^127-1`; a test inventing a positive component above `2^128-1` is invalid. The later `int256`/`uint256` idle conversion is a different issue.
7. `CraneTest.setUp()` calls `BetterTest.setUp()` before `InitDevService.initEnv`; its factory bootstrap is real. The inspected supported Orbital TestBase deploys the canonical PoolManager using `create3Factory.create3WithArgs` and `ArtifactCreationCode.creationCode`. Its complete inheritance tree also deploys unrelated vault components and hook packages, so do not inherit that product fixture wholesale.
8. The installed `Vm.sol` exposes `snapshotState`, `revertToState`, `startStateDiffRecording`, `stopAndReturnStateDiff`, `expectCall`, `record`, `accesses`, and log recording. `AccountAccess` includes caller, callee, calldata, value, depth, and a reverted flag; recorded balance changes include reverted changes. Such records are observation data, not committed state or receipt evidence.
9. The inspected `MintableERC20Decimals` uses `Error("allowance")` and `Error("balance")`, not OZ typed insufficient-balance errors. Tests using this existing peripheral must assert its real errors.

Inspected existing paths, in addition to all required guidance:

- `lib/crane/contracts/test/CraneTest.sol` and the bootstrap portion of `lib/crane/contracts/InitDevService.sol`.
- `contracts/hooks/uniswap/v4/orbital/TestBase_UniswapV4OrbitalSwapHook.sol`, especially its manager deployment at lines 93-97.
- `test/foundry/spec/hooks/uniswap/v4/factory/TestBase_UniswapV4HookDiamondPackageCallBackFactory.sol`; it is package/registry infrastructure, not the selected standalone-manager base.
- `lib/crane/contracts/introspection/ERC165/Behavior_IERC165.sol` and `lib/crane/contracts/tokens/ERC20/TestBase_ERC20.sol`, for actual Behavior and Handler patterns, not as claims that Weir implements those standards.
- Canonical V4 `PoolManager.sol`, `types/PoolOperation.sol`, `types/BalanceDelta.sol`, `types/Currency.sol`, `libraries/Hooks.sol`, `TransientStateLibrary.sol`, relevant `StateLibrary.sol` and `Pool.sol` sections, `Position.sol`, `SwapMath.sol`, `CustomRevert.sol`, and the forward-price portion of `TickMath.sol`.
- The used portions of versioned OZ-v5 `SafeERC20.sol`; the six-file byte-identity comparison remains supplied PRD evidence pending the future fidelity gate.
- `contracts/test/stubs/SimpleMintableERC20.sol`, `MintableERC20Decimals.sol`, the installed `lib/crane/lib/forge-std/src/Vm.sol` observation/snapshot definitions, root `foundry.toml`, `remappings.txt`, and the fork-pin portion of `ROBINHOOD_MAIN.sol`.

The focused fixture search found a usable manager deployment pattern. It does not prove that no other suitable fixture exists. No retired V4 or FullSpread implementation is needed.

## Proposed file inventory and ownership

Abbreviations in this plan:

- **D** = `contracts/protocols/strategy/weir/`
- **H** = `contracts/protocols/strategy/weir/test/`
- **S** = `test/foundry/spec/protocols/strategy/weir/`
- **F** = `test/foundry/fork/protocols/strategy/weir/`
- **E** = `contracts/protocols/strategy/weir/test/evidence/`

These abbreviations expand to exact proposed paths, not existing artifacts.

| Proposed file(s) | Purpose and sole owner |
|---|---|
| `D/WeirVaults.sol`, `D/base/WeirBase.sol`, `D/libraries/LiquidityAmounts.sol` | Three authorized domain imports only. Import owner, WP1. |
| `D/VENDOR.md` | All 39 original records, actual resolved graphs, mappings, licenses, deployment provenance, compiler differences, limitations. Evidence owner, WP0/WP8. |
| `E/import-transform.json`, `E/import-transform.patch`, `E/dependency-compatibility.json`, `E/abi-baseline.json`, `E/storage-layout.json`, `E/resolved-graphs.json`, `E/acceptance-results.json` | Machine-consumed provenance, complete allowed diff, comparison outputs, and result ledger. Evidence owner controls schema; build owner supplies actual compiler outputs. |
| `H/tools/check-fidelity.py` | Focused source transformation, ABI normalization, graph and layout comparison checks. No prose-pinning or whole-doc hash tests. Evidence owner. |
| `H/bases/TestBase_WeirVaults.sol` | CraneTest parent setup, real manager and Weir, actors, sorted pools, approved peripheral funding. Harness owner, WP2. |
| `H/behaviors/Behavior_WeirVaults.sol` | Exact public tuple, ledger, event, and snapshot comparisons in the existing `expect_*`/`isValid_*` style. Uses actual Weir types; no invented production interface. Harness owner. |
| `H/observers/WeirObserver.sol` | Read-only snapshots of Weir, manager state/transient state, tracked balances and allowances. Harness owner. |
| `H/peripherals/WeirPoolRouter.sol` | Real `IUnlockCallback` router for donation, auxiliary liquidity and swaps; owns and settles its deltas. Harness owner. |
| `H/peripherals/WeirCallRouter.sol` | Caught/uncaught call boundary, pre-call sync, nested-unlock experiment, explicit result records. Harness owner. |
| `H/peripherals/WeirCallbackActor.sol`, `WeirTestToken.sol`, `WeirTestHook.sol` in the same directory | Finite programmed callbacks/rejections/token-return modes and legitimate permissioned hooks. Callback owner, WP5, after WP2 publishes the observation contract. |
| `H/peripherals/WeirLiquidityAmountsExposure.sol` | Pure exposure of the actual copied library for AC42-47; never a replacement or subclassed Weir. Oracle owner, WP3. |
| `H/oracles/weir_oracle.py`, `H/oracles/fixtures.json` | Independent integer model and committed machine vectors with provenance and intermediate results. Oracle owner. No dependency installation or production simulator. |
| `H/handlers/WeirSupportedHandler.sol`, `H/handlers/WeirHostileHandler.sol` | Separate supported-domain ghost ledger and hostile outcome tracking. Campaign owner, WP6. |
| `S/WeirSurface.t.sol`, `S/WeirDependencies.t.sol` | Constructors, ABI-facing behavior, dependency state reads and inherited behavior. WP1/WP2 and WP4. |
| `S/WeirDeposit.t.sol`, `S/WeirWithdrawal.t.sol`, `S/WeirCompoundInventory.t.sol`, `S/WeirViewsMath.t.sol` | Ordinary deterministic lifecycle, arithmetic, views, and inventory. Lifecycle/oracle owners, WP3/WP4. |
| `S/WeirNativeTokens.t.sol`, `S/WeirAccessCallbacks.t.sol`, `S/WeirHooks.t.sol` | Plumbing, access, callback and hook characterizations. WP5. |
| `S/WeirSupportedInvariant.t.sol`, `S/WeirHostileInvariant.t.sol` | Distinct stateful campaigns. WP6. |
| `F/WeirRobinhoodParity.t.sol` | Local-only pinned reference/copy branches; inherits the setup/Behavior vocabulary without deploying a second manager. WP7. |
| `H/evidence/receipts/` | Actual local transaction receipt evidence for rollback/log persistence if collected; never fabricated from `recordLogs`. Build/evidence owner, WP8. |

Reuse the existing mintable tokens for ordinary fixtures; the new token file is only for behavior those tokens cannot express, such as no-return or intentionally short delivery. Do not duplicate a manager, OZ tree, V4 tree, or ordinary ERC20 implementation. No production factory, interface, Service, facet, storage repository, or package is added.

## Ordered work packages

The later implementation coordinator assigns one owner to each writable unit. This original does not launch those tracks.

### WP0 - Freeze fidelity and dependency evidence

**Allowed edits:** VENDOR and E evidence/tooling only. **Dependencies:** owner authorization to implement, frozen inputs readable.

1. Record original file identities and all 39 manifest entries, including original metadata keccak and SHA values. Keep original and adjusted hashes separate.
2. Build the exact import transformation specification from the PRD's 22 table entries. Two are deliberately unchanged relative Weir imports; do not convert those to Crane aliases. Add the canonical free-type import and exactly four `ModifyLiquidityParams` construction replacements plus one `SwapParams` replacement.
3. Compare nested versus free struct field order, widths and ABI encoding. Compare all used manager interfaces/types, FullMath behavior, tick/amount semantics, packed deltas, currencies and state reads. Compare the six specified OZ files separately from SafeERC20's three used paths. Do not claim whole-file SafeERC20 equality.
4. Specify expected ABI from frozen metadata, not from the eventual local contract. Canonicalize only permitted source qualifications in `internalType`; retain actual ABI tuple types, outputs, mutability, event indexing and error arguments.
5. Specify the sequential inherited/domain storage comparison and manager-layout checks. Immutable manager is a separate binding, not an extra persistent slot. Internal memory structs must not introduce storage variables.
6. Preserve the verified deployment and license evidence as supplied. Mark archive reads and version-to-license links unresolved.

**Output/exit:** a reviewable transformation allowlist and compatibility ledger with a row for every used dependency surface. Text agreement can unlock copying; an unresolved behavior-changing canonical mismatch blocks acceptance and requires a separate owner decision. No shared-library fix or private dependency clone is authorized by this package.

### WP1 - Import, compile, and establish the surface

**Allowed edits:** exactly the three D Solidity files; necessary machine evidence supplied to WP0's owner. **Dependencies:** WP0 mapping decision.

1. Copy the three frozen files without cleanup. Apply only the import/type adjustments.
2. Run the artifact-aware build with the unchanged root configuration: solc 0.8.35, optimizer 1, viaIR false. Record success or exact diagnostic.
3. If stack depth fails, first shorten temporary lifetimes with lexical scopes. If insufficient, group common temporaries in internal memory structs. Keep an expression/call-order correspondence for each change. Do not cache treasury across both takes, move minima earlier, regroup arithmetic, substitute casts, or change the storage/public parameter types.
4. Rebuild after each meaningful compilation adjustment. Compare generated ABI, inheritance/storage layout, constants and error/event surface against WP0. Explain every transformed source hunk.
5. Establish the initial `WeirSurface`/`WeirDependencies` deployment smoke before money-path assertions: constructors, code existence, immutable binding, initialized pool read, and an independently located salt-zero position.

**Output/exit:** actual clean compile plus approved diff, 27 functions/11 events/18 ABI errors, constructor/receive, preserved layout and type mappings. Bytecode equality with solc 0.8.26/viaIR true is not required. An exact compile blocker remains a blocker, not a reason to enable viaIR.

### WP2 - Real topology and observation contract

**Allowed edits:** TestBase, Behavior, observer and the two routers; basic surface/dependency fixture tests. **Dependencies:** WP1 usable types and artifacts; source-level fixture planning can occur earlier.

1. Parent CraneTest setup first. Assert nonzero real bootstrap factories rather than reconstructing their internals.
2. Reuse the inspected Orbital manager deployment mechanism in the smaller Weir base, not its unrelated product inheritance. Use the canonical manager's source-qualified artifact identity if the short name is ambiguous; refresh that concrete manager artifact before deployment. Constructor owner is a fixture actor. Deploy actual standalone Weir with that manager and explicit owner/treasury under the protocol-port allowance.
3. Create sorted distinct ERC20s, native/positive-address pools, a hookless fee-zero spacing-1 pool, a fee-bearing pool, and distinct shared-currency keys `(A,B)` and `(A,C)` with `A<B<C`. Each is initialized through real `manager.initialize` before `createVault`.
4. Give peripheral routers real funds/approvals. They call `unlock`, perform actual operations, settle/take their own deltas and return only when their unlock can close.
5. Publish the observation record before downstream test work: pool key/id; actor roles; stored Vault; all tracked shares; physical balances/allowances; manager sqrt/tick/fees/ticks/bitmap/Weir position/checkpoints; transient deltas for Weir/router/hook; lock state; expected event sequence; exact failed-call boundary. Use canonical data types rather than duplicate authoritative manager state.
6. Demonstrate negative and positive tick hashing with raw read-only manager storage observations. Derive pool and position locations independently with ordinary encoding/hash operations; compare to StateLibrary results and compiler layout. Do not let the StateLibrary under test be both expected and actual.

**Output/exit:** a real setup smoke, exact snapshot comparators, F0-ready fixture, settled donation router, and evidence that actual Weir owns the salt-zero position. No SUT inheritance, etching, storage writes or manager-return mocking.

### WP3 - Independent integer oracle and library checks

**Allowed edits:** library exposure, oracle/fixtures, `WeirViewsMath.t.sol`. **Dependencies:** WP0's arithmetic contract; integration against WP2 when ready.

Use Python standard-library arbitrary integers for wide products, with explicit checked-width operations and separately modeled casts. Emit machine vectors consumed by Solidity tests; regeneration must be deterministic and offline. Do not call production L, FullMath, TickMath, preview, or execution to manufacture expected outputs. The Solidity exposure is the actual side of the comparison only.

The oracle's exact stages and swap coverage are defined below. **Exit:** F0-F3 and AC39/42-47 vectors, stage-specific failures, exact swap/tick-crossing vectors, and documented bounds where a fuzz vector is or is not lifecycle-reachable. A numerical helper test is not proof that a real vault reaches the vector.

### WP4 - Ordinary lifecycle and inventory

**Allowed edits:** surface/dependency, deposit, withdrawal and compound/inventory suites; no shared harness changes except through its owner. **Dependencies:** WP1/WP2 and relevant WP3 vectors.

Implement every ordinary AC row, starting with F0-F3, then fee-bearing zaps, minima, recipient attribution, shared currencies and self-directed receipts. Include pause/ownership cases in cooperation with WP5 rather than a second conflicting fixture. Compare exact emitted data and manager calls, not just final share supply.

**Exit:** all ordinary reachable rows pass with independently calculated balances; every conditional row has either an executed construction or an explicit reachability record. Do not weaken an assertion to absorb a mismatch.

### WP5 - Callback, hook, native and hostile characterizations

**Allowed edits:** callback peripherals and native/access/hook suites. **Dependencies:** stable WP2 observation schema and WP3 arithmetic. May run beside WP4 in disjoint files.

Use the concrete sequences below. Every callback record identifies the real caller, its share ownership, owner/pending-owner status, trigger phase, catch/bubble policy, and hook permissions. Classify the exact nested error envelope. Separate real negative-delta settlement failures from the positive-hook-credit and wrapped-idle constructions.

**Exit:** executable callback matrix, exact rollback evidence at each chosen boundary, and an honest outcome for AC23/25/33/41/60/67. A helper that returns a fake manager delta is not evidence.

### WP6 - Deterministic campaigns

**Allowed edits:** two handlers and two invariant suites. **Dependencies:** validated operation primitives from WP4/WP5.

Use at least three users and two shared-currency pools, plus a native pool. Each handler operation computes its expected result or exact failure from pre-state, registers expectations before acting, then updates ghost state only for committed effects. Track successful operation counts by kind, currency direction, actor and pool; include donations, transfer-to-Weir, self-treasury/self-recipient, pause and ownership transitions.

Run the repository default campaign first: inspected settings are fuzz runs 16, invariant runs 16, depth 8. Add deterministic scripted multi-action regressions so those small defaults cannot accidentally omit a required path. Proposed expanded release campaign is 256 invariant runs at depth 64 and 1,024 arithmetic fuzz cases, using the installed runner's verified overrides rather than editing profiles. Record a fixed campaign seed, for example `0x57454952`, resolved settings, successes, rejected actions and minimized failures. Verify supported syntax before adding a future command; no unverified flags are prescribed here.

**Exit:** useful successful sequences, exact error classification, reproducible smallest counterexamples, and separated ordinary/hostile conclusions. All-revert campaigns fail the campaign-quality gate.

### WP7 - Local reference parity

**Allowed edits:** the F suite and its result records. **Dependencies:** WP1-4, archive-capable configured alias, legitimate role equivalence. It can be authored beside later hermetic work but must not compete for shared artifact writes.

Follow the pinned recipe below. **Exit:** actual exact reference/copy branch comparisons, or BLOCKED with the particular missing archive/role/state prerequisite. Missing credentials are not a waiver and must not be converted into a returning "passing" test.

### WP8 - Serialized validation and release record

**Allowed edits:** VENDOR, E outputs and result ledger, no product/config repairs. **Dependencies:** all earlier outputs.

One build owner serializes every writer of shared `out/` and `cache_forge/`, including default/fork builds. Run focused checks before broad gates. Preserve prior failures as classified findings. Resolve actual production versus test dependency graphs and complete the WI/AC ledger; record receipt-level evidence separately from Forge instrumentation.

**Exit:** compiler, hermetic, parity, characterization and license statuses stated independently. Incomplete archive, license provenance or unreachable required branches remain visible gates. This package does not declare deployment readiness by implication.

### Parallelism and handoffs

WP0 defines the evidence schema. WP1 owns domain edits. WP2 alone owns shared fixture interfaces. WP3 can derive arithmetic in parallel with WP1/WP2, but must not assume a helper exists until the harness owner publishes it. WP4 and WP5 can proceed concurrently after that handoff. WP6 consumes their stable actions. WP7 is independent of hostile implementation once ordinary parity primitives are stable. WP8 integrates all evidence. Never run independent Forge writers in the same artifact tree, and do not edit shared fixture files from multiple tracks.

## Exact fixture and oracle design

### Baseline topology

The manager and Weir are real contracts with distinct addresses. The manager protocol-fee configuration is zero for F0-F3; static LP fee is zero, tick spacing is 1, hook is zero, sqrt price is `Q=2^96`. Weir is the sole position for the fee-donation anchors. Additional router-owned LP positions belong only in fixtures that explicitly need external liquidity; never quietly add them to F1/F2 and change the fee allocation.

Weir's position identity is `(Weir address, stored lower tick, stored upper tick, bytes32(0))`. Payer, share recipient, share owner, output recipient, donor, treasury, current owner, pending owner, callback actor and hook are separately named roles. Defaults keep them distinct. Tests deliberately merge roles only for a named subcase.

Ordinary ERC20 funding uses real mint/approve/transfer methods. Native actor funding is fixture funding; economic transfers thereafter use actual calls. Never use balance/storage cheatcodes to manufacture Weir or manager accounting. Direct donations are real transfers to Weir. Pool donations are funded manager operations through the auxiliary router.

### Integer stages

The independent model needs separate operations for:

- Checked uint256 multiplication/addition/subtraction and division; encode `Panic(0x11)` versus `Panic(0x12)` at the source stage.
- Full-width `MD(x,y,d)`, requiring nonzero denominator and a uint256 result; expected frozen FullMath failures have empty revert data.
- Explicit low-bit narrowing to uint128 and uint64, two's-complement same-width casts, checked int256 addition/negation, and signed int128 delta bounds.
- The library's `_toUint128` exact-representability requirement with `Error("liquidity overflow")`; this is not equivalent to W's unchecked explicit narrowing.
- `L0` with its inner `floor(A*B/Q)`, followed by a second MD and immediate uint128 check; `L1` and its own immediate check; only then the interior minimum.
- Downward reverse-amount conversion, with the final division by A kept separate. Model positive manager mint costs with upward rounding and removal principal with downward rounding.
- Fee growth subtraction modulo `2^256`, then full-width multiply/divide by `H=2^128`. Do not substitute stored Weir liquidity for actual position liquidity when evaluating pendingFees.
- The deposit nested-floor balancing heuristic, the at-most-one swap, post-swap sizing, checked issuance formula, original refund subtraction and signed payer-credit path.

Derive tick constants/fixture prices independently using high-precision integer/rational methods with bounded error and the protocol's prescribed stage rounding; do not assume the exact real-number expression rounded once always equals the staged TickMath algorithm. Where a fixture relies on a particular rounded tick boundary, record its derivation and both adjacent comparisons. Committed golden values require that provenance; a trace copied from the local SUT is not an independent oracle.

For exact-input swap vectors, model the initialized bitmap search and uninitialized word boundaries, target clamping, active liquidity, fee pips, upward input/downward output rounding, amount remaining, crossing signs and fee-growth-outside updates. In each step, effective input after fee is `floor(remaining*(1,000,000-fee)/1,000,000)`. Reaching a target charges the corresponding rounded-up fee; a step exhausting the input assigns the unused effective-input difference as the fee according to the source. Crossing left sets tick to `tickNext-1`; other non-boundary movement uses the corresponding tick interval. Include zero-liquidity travel and stopping at the global limit. Keep protocol fees zero for the anchor vectors, and record that precondition instead of assuming it on a live fork.

A single constant-product equation cannot replace this traversal. The model is test-only; it adds no public production quote interface.

### Anchors and exact ledgers

| Fixture | Construction | Exact primary ledger |
|---|---|---|
| F0 | Sorted hookless pool described above; payer A deposits `K+2` each, `K=1,048,576`, recipient B. | L=T=K; B shares 1,047,576; mint debt K each; refund 2 each to A; idle zero; reserve 1,000 belongs to no address. |
| F0 exit | B withdraws all assigned shares to C, no zap/fees. | Burn 1,047,576 liquidity/shares; C gets 1,047,575 each; L=T=1,000; B zero; idle zero. |
| F1 | From F0, router unlocks, donates `(20,0)`, pays exact donor debt via sync/transfer/settle and closes. Then separate Weir compound. | Gross `(20,0)`; cut `(1,0)`; added L zero; idle `(19,0)`; T unchanged; event `(20,0,0)`. Next unchanged compound has no event, same idle, updated timestamp. |
| F2 | From F1, router donates `(0,20)` and closes; then compound. | Cut `(0,1)`; r=(19,19); cushioned=(17,17); added L=17; idle=(2,2); T=K. |
| F3 | Restore F1; another payer deposits K+2 each without zap. | Mint K shares; L=T=2K; old idle0 remains 19; new holder's idle0 claim is 9, without an idle buy-in charge. |
| Self treasury | F1 with treasury equal to Weir. | Recorded idle0=19, but physical Weir currency0 increases 20: 19 assigned idle plus 1 unassigned cut. Repeating compound does not book the extra unit. |
| Self recipient | F0 exit to Weir. | Both 1,047,575 receipts are unassigned physical inventory; idle zero, L=T=1,000, holder ledger zero. |

For each currency, ordinary compound accounting separates gross F, cut C, old idle I and add caller delta D: sizing inventory `R=F-C+I`, settlement net `N=F-C+D`, new idle is the exact source cast of `int256(I)+N`. External treasury means physical Weir change N. A self-directed cut adds C physically but not to idle. Additional callback transfers require their own ledger entries.

Deposit payer spend is `used-positiveManagerCredit`, not just the emitted `used` value. Its full physical flow includes initial pull, compound flows, manager settlement, positive payer credit and outer refund. The share recipient need receive no tokens.

For each physical currency c after supported successful top-level completion:

`WeirPhysical(c) = sum(recordedIdle for c in every tracked vault) + independently tracked unassigned(c)`.

Track initial unassigned inventory, direct donations, self-treasury cuts and self-recipient proceeds separately. Manager-held position assets are outside that equality. Include shares held by Weir in the assigned-share sum; do not invent a redeeming actor for those stranded shares. After genesis, assigned shares sum to `T-1,000`, not T, and zero-address shares remain zero.

The equality is restricted to exact-transfer nonrebasing inputs and ordinary supported hooks without additional unmodeled movements. No universal `idle<=2`, zero unwanted output, nonnegative cast safety, preview equality or NAV fairness assertion is permitted.

## Callback and hook constructions

### Permissioned hooks and observations

Deploy peripheral hooks at real CREATE2 addresses whose low 14 bits match the selected canonical permissions. Mine the salt deterministically before deployment, validate address/permission consistency, and initialize the pool only after real code exists. Do not etch code at a convenient address. A peripheral CREATE2 deployment is not a new production Weir deployment system.

Use two permission sets: an observing non-delta hook, and a return-delta hook with the matching after-add/after-remove callback bits plus their return-delta bits. Every callback checks the actual manager caller and returns the exact canonical selector and response shape. For Weir operations the callback's sender argument is Weir. Record original hookData bytes, liquidity delta, salt, input caller delta and informational fees. Keep initialization observations separate from operation observations.

With a funded nonzero-L vault, observe zero-poke before/after-remove, positive reinvest before/after-add, and the user add/remove/swap in their real order. For zero L, there is no poke; for calculated zero reinvestment, there is no add. No swap occurs for zap false, zero imbalance, or a rounded-zero chosen sale amount. Removal is conditional on nonzero removed liquidity. Use manager calldata observations as well as hook records; do not mutate a recorder from an actual static view call.

### Real return-delta settlement

The inspected hook calculation is `callerDelta = preHookDelta - hookDelta`. The manager accounts hookDelta to the hook **after** the hook returns. Therefore a hook can close its eventual positive credit by calling `take` during the callback, temporarily creating its own matching debt; or close an eventual negative hook delta by prepaying with sync/transfer/settle. The resulting hook transient balance must be zero when unlock finishes.

Three concrete proposed cases:

1. **Positive first-return fee distinction:** on a zero poke with no actual position fee, a funded hook prepays e units and returns hookDelta `-e`. The returned Weir caller component is `+e`, although informational fees are zero. Compute Weir's cut, idle and settlement from that first component. Pick e within int128 bounds and settle both parties exactly.
2. **Ignored negative zero-poke component:** a hook takes one unit and returns hookDelta `+1` on zero poke. It closes its own eventual delta, but Weir sees `-1`, converts gross fees to zero and may leave that debt unsettled. In a no-idle/no-other-fee fixture, expect the outer real unlock to reject with `CurrencyNotSettled`, with full subtree rollback. Do not blame an intentionally unclosed hook delta.
3. **AC67 concrete candidate:** reproduce F1 in a pool with a valid return-delta hook disabled during setup. Recorded idle is `(19,0)`, L=T=K. Donate one real currency0 unit directly to Weir, tracked as unassigned, making physical currency0 20. Donate 20 currency1 through the funded pool router. Enable the hook only for the next positive reinvestment add, not the preceding zero poke. Compound sees gross `(0,20)`, cut `(0,1)`, sizes 17 liquidity from `(19,19)`, and has principal add delta `(-17,-17)`. In after-add, the hook takes 3 currency0 and returns `(3,0)` hook delta; its own `-3` take is later offset by `+3`. Weir's first add return is `(-20,-17)`, net is `(-20,2)`, and signed old-idle-plus-net is `(-1,2)`. The source casts idle0 to `2^256-1`. Physical Weir pays its real 20 currency0 and receives 2 currency1; hook receives 3; external treasury receives 1 currency1; L becomes K+17 and T stays K. No fake return or storage injection is involved.

The third sequence is a source-derived, unexecuted candidate, not a proven exploit or passing test. Its integration gate must assert all intermediate values and final closed deltas. If a real-manager earlier failure prevents the precondition, preserve that exact failure and mark the wrapped-idle branch unresolved. Never substitute an expected cast revert.

### Actual callback roles

| Trigger | Actual callback actor and preparation | Required observations |
|---|---|---|
| ERC20 pull/payment/refund | Programmed token contract. Allocate shares to the token itself if it will transfer shares. Give it actual ownership through two-step acceptance only in the owner case. | Guarded reentry, token's own share transfers, correct caller/access error, catch versus bubble. Ordinary ERC20 receipt does not call the recipient. |
| Manager hook | Real permissioned hook called by manager, with sender Weir. | Guard precedence, hookData, create/read/transfer calls with the hook's own shares, manager-wrapped hook failure. |
| Native treasury take | Receiver is treasury and actual current owner in AC57. Seed both fee components with a positive first cut. | cut0 paid to old treasury; callback calls setTreasury(T2); cut1 paid to T2. Both cut amounts were computed before the first take, while destinations are read separately. |
| Native withdrawal take | Output receiver; shares belong to the initiating withdrawer unless explicitly transferred. | Caller debit already occurred; later `_withdraw` state is observable; failed receiver is wrapped by manager. |
| Native deposit refund | Payer contract, not necessarily share recipient. Use positive-refund and zero-refund fixtures. | Recipient shares already credited before positive refund; failed refund becomes B.NativeTransferFailed; zero refund makes no call. |

Give actors the needed funds/approvals and configure callbacks before triggering the operation. Guarded deposit, withdrawal and compound reentry is distinct from unguarded transferShares, createVault, views, receive and administration. A paused deposit rejects with EnforcedPause before the reentrancy guard; an unpaused guarded reentry rejects before its deadline/body validation. An unauthorized setter fails its own ownership check, not an invented guard.

For AC57, native currency is necessarily sorted currency0. Use real native and ERC20 pool donations yielding two positive cuts; arrange that the first receiver has current ownership before the test. If later settlement fails, the earlier treasury setter rolls back with its ancestor.

### Native stale sync and nested unlock

For AC51 outside-unlock variant, `WeirCallRouter` first syncs a non-native token, then calls a native/ERC20 deposit on an empty initialized vault, with positive native debt and no intervening ERC20 manager settlement. ERC20 pulls into Weir do not clear manager sync. Weir's first native payment then encounters NonzeroNativeValue. A router that catches the failure retains its earlier sync within that same transaction; the reverted Weir subtree does not. If the router bubbles, its earlier sync and outer markers revert too. Transient sync is not a cross-transaction persistent denial-of-service claim.

For callback variant, a valid after-add hook, or an actual transfer callback before native payment, syncs a non-native currency and returns without clearing it. Use a no-return-delta observing hook so no unrelated debt explains the failure. Record the last sync and absence of a clearing settle/sync(0). The source remains unchanged.

For AC58, an independent router first owns a real manager unlock and calls ordinary compound on a known vault. The guard is not already entered, so the inner unlock reaches AlreadyUnlocked. Caught failure leaves the router's unlock open; it can finish its own allowed actions and settle before returning. A hook reentering during active Weir compound instead reaches Weir's reentrancy guard first. Hook-originated bubbling wraps the underlying error; a direct router call need not. Outsiders calling unlockCallback get NotPoolManager before decoding valid or malformed bytes.

### Reachability and exact failure boundaries

AC23 is not an excuse to inject a tiny-liquidity state. In the ordinary domain, genesis gives L=T; compounding only raises L; issuance `floor(l*T/L)` preserves L>=T; withdrawing s<=T removes `floor(L*s/T)>=s` and preserves L>=T on the remainder. Thus a positive valid withdrawal does not normally have zero removed liquidity. Record this invariant-based exclusion and search only admitted real actions for an exceptional branch. An independent arithmetic example does not discharge the lifecycle row.

For AC25, start near each relevant usable boundary and choose a large holder withdrawal versus the small remaining position, so the selected zap amount exceeds the exact traversal capacity to the global limit. Prove that inequality with the oracle before execution. Both residual output currencies can be positive. Keep the two directions separate.

For AC33, use a fee-zero pool with spacing greater than one, accrue enough one-sided idle by a real donation, and move the price with real swaps beyond that vault's usable range while remaining within global limits. Choose idle magnitude from the oracle so reinvestment is positive there. Fee-zero price movement avoids introducing a new positive fee; a default F1 nineteen-unit idle need not be large enough near an extreme. Exact construction, price movement, zero pending fees and positive reinvestment remain runtime gates.

For AC41 below/above-range tests, spacing greater than one leaves a real price interval outside the stored usable range. Spacing-1 full-range assumptions must not manufacture an inaccessible upper state. Fee-growth wrap can be checked by independent arithmetic vectors if a practical real sequence cannot reach it; label that boundary.

Every failure has a named low-level call boundary. Snapshot immediately before that invocation, including allowances, actual balances, all relevant vault/position/tick/fee state, pending ownership, treasury, timestamps and peripheral side effects. Assert return status and complete revert data, then compare committed state. For caught nested rejection inside a successful outer operation, only the failed subtree restores; do not require the entire outer operation to disappear.

Register call/event/state recording before triggers. Use `AccountAccess.depth` and `reverted` to distinguish earlier router effects, failed child effects and later router effects. Verify actual post-state as well as records. `recordLogs` may expose attempted/reverted emissions: it is never proof of receipt persistence. For claims about persisted receipt logs, collect real local transaction receipts through the later local validation runner and compare against the call-tree outcome; if that evidence is not collected, mark receipt-level verification unperformed. Do not claim that debug logs survived the revert. No sleeps, polling delays or timing-luck tests are needed; timestamp tests use explicit deterministic VM time changes because time is the behavior under test.

## Complete AC-to-test plan

All test paths and names below are proposed. A table name such as `Deposit::test_AC09` means class `WeirDepositTest`, file `S/WeirDeposit.t.sol`, method `test_AC09`. The analogous prefixes expand to `WeirSurfaceTest`, `WeirDependenciesTest`, `WeirWithdrawalTest`, `WeirCompoundInventoryTest`, `WeirViewsMathTest`, `WeirNativeTokensTest`, `WeirAccessCallbacksTest`, and `WeirHooksTest` in the inventory above. Multiple named subcases may be split into suffixed methods; they are not optional.

Status **P** means a source-supported proposed construction, not executed; **C** means a conditional/reachability subgate remains; **G** means a static/build/release gate unperformed; **B** means a supplied external blocker. Every success also uses the complete WP2 ledger/event/delta checks. Every failure uses the boundary snapshot discipline above and full encoded errors, not catch-all expectRevert.

| AC | Proposed test or static gate | Construction and required subcases | Primary exact assertion | WP; status |
|---|---|---|---|---|
| AC01 | `check-fidelity.py`: transform gate | Compare all three imports to frozen bytes; apply only the enumerated imports, five free-type constructions and recorded necessary scope/memory refactors. | No unexplained hunk; original notices/comments and storage/ABI preserved; original/adjusted hashes and diagnostic-linked refactor diffs present. | WP0/1; G |
| AC02 | ABI gate; `Surface::test_AC02` | Frozen manifest ABI versus compiled artifact, independent of local source enumeration; exercise inherited/public entries. | Exactly 27 functions, constructor, payable receive, 11 indexed-event definitions and 18 ABI errors; tuples, outputs and mutability match. | WP0/1/4; G/P |
| AC03 | Build gate | Default build before tests; repeat after each authorized stack-depth fix. | Exit zero with 0.8.35/runs1/viaIR=false and unchanged config, otherwise exact blocker; no default-bytecode identity demand. | WP1/8; G |
| AC04 | VENDOR release-license gate | Frozen 39-file records plus actual full declarations and provenance links. | 2027-06-15/earlier ENS or anniversary conditions recorded; old GPL versus newer MIT ambiguity retained; no invented grant or clearance. | WP0/8; G |
| AC05 | `Surface::test_AC05` | Valid deployment; separate zero-treasury, zero-owner and zero-manager deployments. | Bindings/defaults/count/paused state and OwnershipTransferred exact; ZeroAddress; OwnableInvalidOwner(0); zero manager accepted by constructor. | WP1/4; P |
| AC06 | `Surface::test_AC06` | Initialize distinct full keys, including `(A,B)` and `(A,C)` sharing A; create in known order. | Independent PoolIds/ticks, exists=true, zero accounting, ordered allVaults/count, one exact VaultCreated each. | WP2/4; P |
| AC07 | `Surface::test_AC07` | Duplicate key, uninitialized key, and indexed access at count. | VaultExists, PoolNotInitialized, Panic(0x32), with no extra entries or committed creation event. | WP4; P |
| AC08 | `Surface::test_AC08` | Unknown ID and separately a known empty vault. | Default unknown struct/zero shares/zero quote pairs; empty vault retains key/ticks/exists; zero-L/supply reads short-circuit. | WP4; P |
| AC09 | `Deposit::test_AC09` | F0 with distinct payer A and recipient B. | K liquidity/total, B=1,047,576 shares, A refunds2 each, idle0/1=0; salt-zero owner Weir; Deposited.user=B. | WP3/4; P |
| AC10 | `Deposit::test_AC10` | Fresh independent fixtures with paired amounts1,002 and1,003. | First calculated L1,000 then ZeroShares; second L1,001/user shares1/refunds2 each. | WP3/4; P |
| AC11 | `Deposit::test_AC11` | Fresh/existing vault; pairs using0/1/2; each one-sided non-zap at interior price. | Resulting zero-liquidity/share cases revert ZeroShares in both directions; pulled funds and prior idle cannot turn them into success. | WP4; P |
| AC12 | `Deposit::test_AC12` | F0 then identical paired entry without fees. | Second gets K; L=T=2K; old ledger unchanged; assigned sum=T-1,000. | WP4; P |
| AC13 | `Deposit::test_AC13` | Generate real fees before paired entry, with positive compounding where selected. | Compound precedes sizing/issuance; minted=floor(newL*postCompoundT/postCompoundL); exact cuts/idle and event order. | WP3/4; P |
| AC14 | `Deposit::test_AC14` | F3 from a restored F1 state. | Second shares K, L=T=2K, idle0=19, new share holder idle claim9, no idle buy-in charge. | WP4; P |
| AC15 | `Deposit::test_AC15` | Real external LP fixture; balanced, token0-heavy, token1-heavy, each single-sided, and chosen x=0. | Nested-floor sale direction/input, zero calls in no-swap cases, one swap otherwise; exact post-price sizing/shares/refunds. | WP3/4; P |
| AC16 | `Deposit::test_AC16` | Existing Weir liquidity in a fee-bearing pool; second actor zaps, separating old pending fees from fees generated by that zap. | First add return includes the latter fees; payer debt reduced or payer credited; no second cut/incumbent credit; event used fields and payer spend reconciled. | WP3/4; P |
| AC17 | `Deposit::test_AC17` | Equivalent fixtures for minShares=S and S+1; include absent vault and existing fee-bearing vault subcases. | Equality succeeds; S+1 Slippage after callback; rollback includes creation where applicable, cuts, pulls, shares and would-be refunds. | WP4; P |
| AC18 | `Deposit::test_AC18` | Funded holder transfers to other/self/Weir; zero unknown-pool transfer; zero recipient; excess amount. | Exact ledgers/events; self sufficient balance required; stranded Weir shares tracked; unknown zero succeeds; ZeroAddress/Panic(0x11). | WP4; P |
| AC19 | `AccessCallbacks::test_AC19` | Pause funded deployment; try deposit, create another valid pool vault, transfer, compound, withdraw, views and plain receive. | Deposit EnforcedPause; each other operation follows its own validations; no blanket pause. | WP4/5; P |
| AC20 | `AccessCallbacks::test_AC20` | Combine paused/reentrant/expired/zero-recipient conditions, then remove earlier failures; actual callback supplies reentry. | Pause precedes guard precedes deadline; Expired before body; ZeroAddress before creation/native/pulls when deadline valid. | WP5; P |
| AC21 | `Withdrawal::test_AC21` | F0 full assigned-share exit, owner and recipient distinct, no zap. | Recipient1,047,575 each; owner zero; L=T1,000; idle zero; Withdrawn.user=owner. | WP4; P |
| AC22 | `Withdrawal::test_AC22` | Real accrued fees and idle; proper subset s. | Post-compound L/T used; independently floored removal and each idle claim; exact remaining state and output; no residual sweep. | WP3/4; P |
| AC23 | `Withdrawal::test_AC23` plus reachability record | Try admitted real-action tiny withdrawals; establish L>=T ordinary-domain argument; no injected ledger. | If removed L=0 is reached, no modify removal; idle-only claim paid; all-zero claims may burn for0 at minima0. Otherwise record each unreachable subcase, not a green fabricated test. | WP3/4/5; C |
| AC24 | `Withdrawal::test_AC24` | Restore equivalent ample-liquidity state for zap0/1/2. | No swap / sell positive token1 / sell positive token0; exact input, signed deltas and both outputs. | WP3/4; P |
| AC25 | `Withdrawal::test_AC25` | Near-boundary finite-liquidity fixtures, both directions, oracle-proven requested input above limit capacity. | Partial consumption and positive residual delivered with no full-consumption failure; exact tick/price and two-currency settlement. | WP3/4; C |
| AC26 | `Withdrawal::test_AC26` | Equivalent state with output(a,b); minima(a,b), (a+1,b), (a,b+1). | Equality succeeds; each violation Slippage after settlement; exact burn/position/timestamp/cuts/idle/recipient rollback. | WP4; P |
| AC27 | `Withdrawal::test_AC27` | Valid deadline with progressively removed zap3/zero-recipient/unknown/zero-shares/insufficient-balance conditions; expired repeat. | BadZap, ZeroAddress, NoVault, ZeroShares, Panic(0x11); Expired precedes body. | WP4; P |
| AC28 | `CompoundInventory::test_AC28` | Known empty vault compound by unrelated actor at t then t+1. | uint64 timestamp updates; no poke, take, add, transfers or Compounded event. | WP4; P |
| AC29 | `CompoundInventory::test_AC29` | Compound unknown key. | NoVault before unlock, no state/timestamp mutation. | WP4; P |
| AC30 | `CompoundInventory::test_AC30` | F1 followed by unchanged compound. | Gross20/cut1/idle19/no L addition/first exact event; second no event, timestamp advances. | WP4; P |
| AC31 | `CompoundInventory::test_AC31` | F2. | Gross(0,20), cut(0,1), added17, idle(2,2), T unchanged and exact physical movements. | WP4; P |
| AC32 | `CompoundInventory::test_AC32` | Real fees at floor thresholds; fee0/500/1,000; F1 self-treasury and repeat. | Gross19/20 at500 produces cut0/1; self-treasury physical20 versus idle19/unassigned1; no repeated cut merely for idle spending. | WP4; P |
| AC33 | `CompoundInventory::test_AC33` | Large one-sided idle, fee-zero real price movement into deployable one-sided range, no new positive fee. | Added L positive, T fixed, exact changed idle, no Compounded; prove no fee contamination and no no-op substitution. | WP3/4; C |
| AC34 | `CompoundInventory::test_AC34` | Direct ERC20/native donations before/after F0 at fixed pool state; separate F0 exit to Weir. | No share/idle/quote/fee change from donations; exit receipts1,047,575 each unassigned, L=T1,000/idle0; receive no vault event. | WP4; P |
| AC35 | `CompoundInventory::test_AC35` | Two funded `(A,B)`/`(A,C)` vaults, distinct fee/idle histories; operate on one. | Other accounting/position unchanged; shared physical A=sum idleA+independent unassignedA. | WP4; P |
| AC36 | `NativeTokens::test_AC36` | Seed real inventory; exact-transfer payer lacks allowance or balance. | Existing chosen token's Error("allowance")/Error("balance"), full rollback, no inventory-funded successful pull; hostile delivery tested separately. | WP5; P |
| AC37 | `Withdrawal::test_AC37` | Fee-bearing burn then exit zap; remaining position nonzero. | Fee growth/checkpoint math attributes zap fees to remaining L; no retroactive burned-share credit or second automatic harvest. | WP3/4; P |
| AC38 | `ViewsMath::test_AC38` | F0 and fee/idle states; s0/fraction/T/more than caller owns; zero-supply state. | Exact downward principal+independently floored idle; no ownership check/mutation; no manager read in zero-supply branch. | WP3/4; P |
| AC39 | `ViewsMath::test_AC39` | L=T=2^20 idle0; s=2^128+7, s=2^236; arbitrary s at zero T. | First truncates liq to7 and quotes6 each; second checked product Panic(0x11); zero T returns(0,0). | WP3; P |
| AC40 | `ViewsMath::test_AC40` | Real pending fees; preview and actual exit from equivalent starting state, with/without zap; separate no-maintenance equality case. | Independent preview formula excludes pending/compound/zap; execution formula separately exact; equality only under proven prerequisites. | WP3/4; P |
| AC41 | `ViewsMath::test_AC41` | Real checkpoint/growth observations, inside and reachable outside usable ranges; separate modular-wrap arithmetic vectors. | Gross floor(((inside-last) mod2^256)*actualPositionL/H), unchanged state; label wrap/reachability limitations. | WP3/4; P/C |
| AC42 | `ViewsMath::test_AC42` | Actual L exposure, A=Q/B=2Q, input3, reverse bounds, liquidity7. | L0=6, L1=3; reverse amounts0=3/1=7 in both bound orders. | WP3; P |
| AC43 | `ViewsMath::test_AC43` | A=Q/2/B=2Q/P=Q/amounts(3,4); liquidity7; P=A/B branches. | Interior min(6,8)=6, reverse(3,3); correct outer branch at each equality. | WP3; P |
| AC44 | `ViewsMath::test_AC44` | Same interior bounds; (2^127,1), then(1,2^127). | Error("liquidity overflow") from each respective candidate before minimum, despite other candidate fitting. | WP3; P |
| AC45 | `ViewsMath::test_AC45` | Equal nonzero bounds for liquidity; separate reverse amount0 at A0/BQ/liquidity1. | First FullMath empty revert; second final division Panic(0x12), not a new range error. | WP3; P |
| AC46 | `ViewsMath::test_AC46` | Empty compound at2^64-1,2^64,2^64+7; otherwise-valid deposit/withdraw deadline t/t-1. | Stored timestamps2^64-1,0,7; equality accepted, expired rejected; failed call restores old timestamp. | WP3/4; P |
| AC47 | `ViewsMath::testFuzz_AC47` | Bounded valid arithmetic domains plus explicit overflow boundaries; tokens with non-18 decimals. | Exact staged values/casts/errors; raw units unchanged by decimals; lifecycle and pure-vector reachability distinguished. | WP3/6; P |
| AC48 | `NativeTokens::test_AC48` | Native/ERC20 paired and zapped deposits; correct value and +/-1; ERC20/ERC20 value1; payer!=recipient. | Exact native settle/refund without WETH; wrong value BadNativeAmount; payer gets refund. | WP5; P |
| AC49 | `NativeTokens::test_AC49` | Rejecting payer receive with positive refund; separate reachable zero-refund case. | Positive refund B.NativeTransferFailed and full rollback; zero refund makes no receive call and does not fail solely for rejection. | WP5; P/C |
| AC50 | `NativeTokens::test_AC50` | Native output and treasury take to receiver reverting known bytes. | Full WrappedError(target,selector0,reason,NativeTransferFailed context) from manager, not bare B error; no committed burn/cut. | WP5; P |
| AC51 | `NativeTokens::test_AC51` | Router stale ERC20 sync before native pay; separate actual hook/token sync during unlock; catch/bubble variants with no intervening clear. | NonzeroNativeValue at real settle; failed-subtree restore; earlier caught-router sync persists only in that transaction; outer unlock ownership unchanged. | WP5; P |
| AC52 | `AccessCallbacks::test_AC52` | Owner/nonowner/pending-owner setter matrix; fees0/500/1,000/1,001; treasury0/repeated value; repeated pause/unpause. | Full unauthorized caller argument before body checks; FeeTooHigh/ZeroAddress; accepted no-change events; EnforcedPause/ExpectedPause repeats. | WP5; P |
| AC53 | `AccessCallbacks::test_AC53` | Start/replace/cancel/accept/renounce; wrong accepter; paused then renounced separate state. | Exact owner/pending/events; pending cleared on accept/renounce; former owner cannot unpause renounced state. | WP5; P |
| AC54 | `AccessCallbacks::test_AC54` | Token/hook/treasury/output/payer triggers try deposit/withdraw/compound; actual roles, paused/unpaused, caught/bubbled. | ReentrancyGuardReentrantCall where reached; paused deposit EnforcedPause; exact wrappers and correct outer success versus rollback boundary. | WP5; P |
| AC55 | `NativeTokens::test_AC55` | False, real no-return delivery, explicit revert, short/no-delivery success; with/without donated same-token inventory. | SafeERC20FailedOperation at Weir sites; exact revert bubbling; no-return accepted; exact later failure or spending of existing inventory without safety claim. | WP5; P |
| AC56 | `AccessCallbacks::test_AC56` | Real callback invokes transfer/create/views; actual owner callback invokes setters/ownership; insufficient-role/share controls. | Token/hook moves its own shares; correct independent access/balance errors; exact creation/event ordering/intermediate views; no invented guard. | WP5; P |
| AC57 | `AccessCallbacks::test_AC57` | Native0/ERC20 pool, both cuts positive, old treasury is current-owner receiver changing to T2 on first take. | cut0 old treasury, cut1 T2; both computed at pre-callback fee; outer failure reverses setter. | WP5; P |
| AC58 | `AccessCallbacks::test_AC58` | Outsider valid/malformed callback; independent real unlock router compound catch/bubble; active Weir reentry. | NotPoolManager before decode; AlreadyUnlocked for independent inner unlock; guard first during active Weir; direct/wrapped bytes exact, no inner relock claim. | WP5; P |
| AC59 | `Hooks::test_AC59` | Non-delta permissioned hook, positive reinvest, own add/remove/swap; zero-L/zero-add/no-swap controls; separate create and reverting hook. | Exact bytes/params and actual poke-remove/reinvest-add/action order; no create hook; exact wrapped failure and rollback. | WP5; P |
| AC60 | `Hooks::test_AC60` | Settled hook-funded positive caller delta distinct from fees; settled-hook negative zero-poke case. | Positive first-return basis; informational fees not substituted; unhandled negative Weir delta gives CurrencyNotSettled in the specified no-other-flow case. | WP5; P/C |
| AC61 | `AccessCallbacks::test_AC61` | Callback receiver records views/shares at treasury, output and refund phases. | Withdrawal caller already debited during compound; deposit recipient already credited at refund; exact phase state, no universal atomic-view assertion. | WP5; P |
| AC62 | `NativeTokens::test_AC62` | Low-level native-value calls to nonpayable methods; empty-calldata value separately. | Actual compiled dispatch failure bytes pinned from target evidence, no invented domain selector; receive succeeds with unchanged ledger. | WP5; P |
| AC63 | `WeirSupportedInvariantTest::invariant_AC63`, `WeirSupportedInvariant.t.sol` | >=3 users, shared-currency pools/native, exact-transfer nonrebasing inputs, supported hook assumptions; complete successful actions. | StoredL=positionL; assigned=T-1,000 after genesis incl Weir; physical idle+unassigned equality; closed deltas/lock only after own top-level completion. | WP6; P |
| AC64 | `WeirHostileInvariantTest::invariant_AC64`, `WeirHostileInvariant.t.sol` | Separate callback/reject/short-delivery/return-delta/partial-fill/pause/owner campaigns. | Each success has its exact accounting trace, each failure its exact envelope/boundary; no unsupported ordinary invariant across hostile assumptions. | WP6; P/C |
| AC65 | `WeirRobinhoodParityTest::test_AC65_*`, `F/WeirRobinhoodParity.t.sol` | Configured alias, chain4663, shared pin, archive code, selected pool/role equivalence, snapshot-separated reference/copy sequences. | Exact mapped returns/reverts/events/balances/positions; direct deployment provenance; missing archive/credentials or roles BLOCKED, never skip-as-pass. | WP7; B |
| AC66 | Final acceptance ledger gate | Review actual outputs of every WI/AC, build/hermetic/fork and dependency/license records. | Each test/static gate has evidence or explicit unresolved status; compiler/hermetic success not mislabeled upstream parity or production safety. | WP8; G |
| AC67 | `Hooks::test_AC67` | Concrete F1 + direct1 + pool donation(0,20) + after-add hookDelta(3,0) candidate above, hook settles itself. | If reached, idle0=2^256-1, physical0=0/physical1=2, L=K+17/T=K and closed hook/Weir deltas; otherwise exact blocker and reachability gap. | WP3/5; C |
| AC68 | Dependency comparison gate; `Dependencies::test_AC68` | Six specified V5 whole files; SafeERC20 used paths separately; generated ABI/layout; true/false/no-return/revert tokens; owner/pause/guard cases. | No mixed Context tree or namespaced guard upgrade; sequential storage and used behavior preserved, not whole SafeERC20-file identity. | WP0/1/5; G/P |
| AC69 | Resolved graph/license gate | Traverse actual production and test roots after build; keep original39 inventory independent. | Runtime StateLibrary hashing helper and literal BSL/AGPL declarations represented; test-only graph separate; unresolved disposition explicit. | WP0/8; G |

The zero-refund AC49 subcase needs a genuine input/caller-delta construction rather than setting input equal to an assumed mint debt despite the two-unit cushion. A return-delta hook can increase one native liability to consume the declared amount, provided its own credit is taken and every delta closes; alternatively use an independently solved zap fixture. Preserve the actual construction and do not hide a missing subcase behind the positive-refund test.

## Complete WI traceability

| WI | Work packages | Required artifact and exit evidence |
|---|---|---|
| WI-01 | WP0/1 | Only three production domain paths; research text stays outside compilation; AC01. |
| WI-02 | WP0/1/8 | Full transformation diff and ABI/layout/order correspondence; AC01/02/03/68. |
| WI-03 | WP0/7/8 | VENDOR with39 records, adjusted hashes, compiler diagnostics, license/deployment/alias and missing-evidence fields; AC01/04/65/66/69. |
| WI-04 | WP0/1/2/3 | Free-type equivalence, dependency used-surface table, independent slot/hash/rounding tests; AC01/02/68/69. |
| WI-05 | WP0/8 | Full applicable notices/declarations and unresolved version/grant disposition; AC04/69. |
| WI-06 | WP1/8 | Unchanged solc/runs/viaIR configuration; actual clean compile or exact blocker; scope/memory refactor proof; AC01/03. |
| WI-07 | WP0/1/8 | Scope review rejects wrapping, registry/adaptation and economic repair; exact ABI and exclusions disposition; AC02/66. |
| WI-08 | WP2/4 | Independent key/tick/position ownership and ordered creation checks; AC06/07/09/35/63. |
| WI-09 | WP0/1/4 | Generated tuple/storage/enum mapping evidence, not source-name similarity; AC02/06. |
| WI-10 | WP1/4/5 | Baseline ABI inventory and calls including constructor/getters/inheritance/receive; AC02/05/08/62. |
| WI-11 | WP2/4/5 | Real unlock/callback ordering and provenance, compound hookData encoding, nested-unlock tests; AC13/29/58/59. |
| WI-12 | WP4/5 | Pull/native/recipient/share/refund/event order and exact payer ledger; AC09/17/20/48/61. |
| WI-13 | WP3/4/6 | Cushion/genesis vectors and unassigned reserve ledger; AC09/10/11/63. |
| WI-14 | WP3/4 | Post-compound liquidity-based share issuance and F3 idle dilution; AC12/13/14. |
| WI-15 | WP3/4/5 | Signed first-return settlement, payer credits and same-swap fee attribution; AC09/16/60. |
| WI-16 | WP4/5/6 | Transfer/self/unknown-zero/Weir-holder/access cases and exact event; AC18/56/63. |
| WI-17 | WP4/5 | Validation/debit/compound/minima/event attribution; AC21/26/27/61. |
| WI-18 | WP3/4 | Separate proportional floors, idle prepay, conditional removal and reachability; AC21/22/23/24. |
| WI-19 | WP3/4 | Nested-floor one-swap balancing and each withdrawal direction; AC15/24/59. |
| WI-20 | WP3/4 | Negative exact input, hard limits and actual returned deltas; AC15/24/25. |
| WI-21 | WP3/4/5 | Timestamp-first behavior, zero-L short circuit, first-return positive-int128 harvest; AC28/30/46/60. |
| WI-22 | WP3/4/5 | Per-currency cuts, site-specific treasury reads, retained-fee/idle/add ledger and exact casts; AC31/32/57/67. |
| WI-23 | WP4/5 | Conditional Compounded events, event order, deposit/exit swap fee phases; AC16/30/31/33/37/59. |
| WI-24 | WP4/5/6 | Separate physical and assigned inventory across pools/self-directed receipts; AC14/32/34/35/36/63/67. |
| WI-25 | WP3/4 | Independent preview/pending/default semantics and oversized input behavior; AC07/08/38/39/40/41. |
| WI-26 | WP4/5 | Current-owner-only setters, fee bounds, repeat events, deposit-only pause; AC19/52. |
| WI-27 | WP1/5 | Constructor/transfer/replace/cancel/accept/renounce transitions with exact inherited errors/events; AC05/52/53/68. |
| WI-28 | WP5/6 | Real caller/role callback matrix, guarded versus unguarded and phase observations; AC54/56/57/58/61/64. |
| WI-29 | WP2/5 | Exact native/ERC20 payment/refund/take/return modes and stale sync; AC48/49/50/51/55/62. |
| WI-30 | WP4/5/8 | Deadline equality and failed-subtree/outer-transaction rollback evidence, separate receipt status; AC17/20/26/27/46/49/50/51/54. |
| WI-31 | WP0/1/3/5 | ABI error inventory plus full propagated errors/panics, staged casts/overflow; AC02/39/42/43/44/45/46/47/50/55/62/67. |
| WI-32 | WP2/8 | CraneTest parent-first real manager/standalone Weir; forbidden-injection review and fixture smoke; all runtime suites. |
| WI-33 | WP2/4/5/6 | Complete exact snapshots, ordered real calls/hookData, required closed deltas at correct boundary; every runtime AC. |
| WI-34 | WP3/4 | Independent arithmetic/golden-vector provenance, F0-F3, tick traversal and distinct fee/principal ledgers; AC09/14/15/24/39/42/43/44/47. |
| WI-35 | WP3/4/5/6 | Characterization versus supported invariants, explicit conditional reachability and exact failures; AC14/23/25/33/55/60/64/67. |
| WI-36 | WP6/8 | Recorded seeds/runs/depth, successful-action counters, outcome classifications and minimized sequences; AC47/63/64/66. |
| WI-37 | WP1/7/8 | Artifact build-before-test logs, default/fork separation, alias/shared pin/archive parity records and warm-cache preservation; AC03/65/66/69. |

## Local fork parity recipe

The following are **supplied deployment facts**, not RPC results from this contribution:

- Chain4663; reference Weir `0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110`.
- Direct deployment transaction `0xa92ae44ce73b159a3aa3d6c8e2920b4c4771d784a253313a35d2fd9c4fad351a`, successful top-level creation, block76,197,114.
- Block hash `0x07be1214c2742ebcea7a61d8065020e88c4b66b5fc96a753ff022a00aa2c8c1d`; timestamp2026-09-30T03:33:23Z.
- Constructor manager `0x8366a39CC670B4001A1121B8F6A443A643e40951`; owner and treasury `0x3234DEA52cc05cba7830B5305151C50AD34e9018`.
- The shared `ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK` is now76_197_114; I observed that constant in the current file. Its prior build/fmt/diagnostic pass is supplied evidence.

Do not repeat a conditional factory search: the reference was independently directly deployed. A `createVault` call records a pool in that one deployment; it does not create another vault contract.

1. Use `FOUNDRY_PROFILE=fork` and the F path only. Resolve an existing alias with `vm.rpcUrl`, preferentially `robinhood_mainnet_alchemy` when its operator-provided key and archive state are available. The inspected aliases also include `robinhood_mainnet` and `robinhood_mainnet_public`; supplied evidence says both public aliases failed historical-state access. Do not inspect private credentials, print credential-bearing URLs, invent `WEIR_RPC_URL`, or select another chain.
2. Create/select the local fork using the shared constant. Verify chain ID, block number and actual header hash through the chosen archive input. `blockhash(block.number)` is not a current-header proof. Read code at reference and manager, then reference `poolManager()`, fee, pause, owner, pending owner and treasury. Missing state or a differing immutable manager is an explicit failed prerequisite.
3. Preserve CraneTest parent-first setup while binding this fixture to the live reference manager; do not accidentally deploy a local replacement manager. Factory/bootstrap state must belong to the selected local fork context or be explicitly valid there before using it.
4. Deploy fresh exact-transfer peripheral tokens locally and initialize a new hookless pool on that **same reference manager**. Assert selected PoolId absent from reference and copy before either branch. Fresh tokens eliminate unrelated reference balances in those currencies. Do not overwrite code at the reference address.
5. Deploy the copy against that manager. Read actual roles rather than assuming constructor defaults still apply at end-of-block state. Locally impersonate the current owner only for legitimate alignment calls; no production private key is needed. Use the same treasury/fee/pause policy for each branch or an explicit mapping. If renunciation or unavailable state prevents alignment, list the affected action as blocked.
6. Establish one full baseline snapshot after both deployments, pool initialization, actor funding, approvals, role alignment and any shared auxiliary LP setup, but before selected-pool creation in either Weir. Selected positions/idle/shares start empty in both. Record unrelated reference allVaults prefix rather than requiring copy's global count to equal it.
7. Run the reference branch: create, paired deposit with distinct recipient, fee donation/compound, second entry, transfer, partial/no-zap and zapped withdrawals, and selected failures. Capture exact outputs, reverts, event topics/data/emitter, deltas, position/checkpoint/tick state and physical inventory.
8. Restore the **full fork state** with `revertToState` and require its success. Do not restore just Weir storage. Keep reference observations in test memory or an external comparison record whose retention does not change SUT state; test-contract storage written after snapshot would itself be reverted.
9. Run the same sequence on the copy at the same timestamps, inputs, fees and funded starting state. Map reference-Weir address to copy-Weir address in emitters, manager position owner, approvals, share recipient if self, and actor labels. PoolId stays the same because both use the same peripheral tokens/key/manager. Compare absolute selected-pool state and mapped changes to global arrays/balances; do not normalize away real behavioral differences.
10. Repeat snapshots for expected-failure and administration branches. Native parity needs explicit initial-balance delta treatment because the live reference can already hold unrelated native inventory; keep fresh-token parity and native attribution separate. A source hash/receipt match is not a transaction parity pass.

No Alchemy key or archive code result is available in the supplied process evidence. AC65 is therefore currently BLOCKED, not waived. Implementing its future suite is useful but does not discharge the gate.

## Future validation commands and evidence separation

These commands are **future instructions**, not commands run in this council contribution. They follow the read `docs/testing/ARTIFACT_BUILDS.md`. From the repository root, pass every edited production source and the selected suite:

```bash
python3 scripts/forge-artifacts.py plan \
  contracts/protocols/strategy/weir/WeirVaults.sol \
  contracts/protocols/strategy/weir/base/WeirBase.sol \
  contracts/protocols/strategy/weir/libraries/LiquidityAmounts.sol \
  --test-root test/foundry/spec/protocols/strategy/weir

python3 scripts/forge-artifacts.py test \
  contracts/protocols/strategy/weir/WeirVaults.sol \
  contracts/protocols/strategy/weir/base/WeirBase.sol \
  contracts/protocols/strategy/weir/libraries/LiquidityAmounts.sol \
  --test-root test/foundry/spec/protocols/strategy/weir -- -vv
```

For an initial manager artifact missing from the current warm outputs, include its concrete canonical source as an additional positional build input, or use the documented consumer discovery route with a literal source-qualified manager artifact ID. Do not rely on a dynamically constructed ID being discovered automatically. The focused helper must build all selected runtime artifacts and stop on build failure before tests.

After focused suites and source/dependency gates, the import is broad enough to justify the required release-level commands, executed serially:

```bash
forge build
forge test --match-path 'test/foundry/spec/protocols/strategy/weir/**' -vvv
forge test

FOUNDRY_PROFILE=fork forge build
FOUNDRY_PROFILE=fork forge test \
  --match-path 'test/foundry/fork/protocols/strategy/weir/**' -vvv
```

Do not launch the fork test as a fake successful skip when archive preflight fails; record it as blocked. Default tests remain hermetic with no RPC/secrets. Keep `FOUNDRY_TEST`, compiler settings and profiles unchanged. No package profile, viaIR fallback, out/cache deletion or unrelated fmt.skip warning repair. New or empty worktrees first receive both warm `out/` and `cache_forge/` under root rules. Slow high-CPU compilation is not a reason to kill the compiler. Retain exact command, resolved settings, exit code and output for each actual run.

Prior failures mentioned in ARTIFACT_BUILDS are historical supplied observations, not proven current failures. If the wider suite fails, determine whether the import caused it; report actual unrelated failures without changing or weakening those tests in this scope.

The final release record must state these independently:

| Claim | Minimum evidence |
|---|---|
| Source fidelity | Exact allowlisted transformation, baseline ABI, storage/inheritance and used dependency compatibility artifacts. |
| Compiler success | Actual target-settings build exit0, with every necessary compilation refactor recorded. |
| Hermetic behavioral proof | Actual passing real-manager deterministic suites and useful campaigns; conditional gaps explicit. |
| Reference parity | Archive-backed selected-pool reference/copy execution and full snapshot isolation, not source metadata. |
| Security characterization | Exact demonstrated limitations and failure boundaries under stated peripheral assumptions; not a universal safety certificate. |
| Receipt-level rollback | Actual local receipt evidence if claimed; debug log capture alone is insufficient. |
| Release licensing | Complete original/actual graph disposition and actual version-linked declarations; no inference from top-level MIT or elapsed deployment time. |

## Limits, unresolved gates, and conclusion

The important implementation decision is to establish compatibility and observation before adding money-path assertions. The three-file import is small; dependency equivalence, exact integer expectations and real callback settlement are the substantive work.

The following remain unverified:

- Actual solc0.8.35/runs1/viaIR=false compilation and whether scopes/memory structs suffice.
- Generated ABI/storage agreement, complete used-body equivalence and actual resolved production/test import graphs.
- Execution of every proposed numeric, callback and hook construction, especially AC23/25/33/41/49/60/67 conditional subcases.
- Archive state/code, actual reference role state and fork parity. Supplied public deployment receipts do not close these.
- Full applicable license/version links for frozen Position and canonical literal BSL headers, any applicable ENS/grant/earlier-anniversary condition, and release disposition. The supplied GPL/AGPL declarations are open-source declarations, not restrictions to erase; the plan provides no legal clearance.
- Upstream Git pin, portable upstream test suite and audit evidence absent from the supplied corpus. Do not invent those or claim an upstream suite was run.
- Receipt-level rollback evidence beyond future Forge state/call instrumentation.

No implementation, source/config/PRD change, command, build, test, RPC/web request, Git operation, deployment, wallet action, delegation or peer-original reading was performed for this contribution. Its only authored artifact is this assigned response. All 37 WI and all 69 AC IDs are mapped above; mapping a gate is not passing it.

This original proposes a complete work order and test construction strategy while preserving every frozen requirement. It neither replaces the PRD nor authorizes implementation, and it requests no additional council round.
