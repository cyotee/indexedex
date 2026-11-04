I read this as the Grok original for the Weir import plan. apply_patch is not an active tool, so the complete contribution is this response. I'll stop when that original is delivered.

# Grok original: WeirVaults source-import implementation and testing plan

## Identity

Member: Grok. This is the independent implementation and testing plan original for council `weir-source-import-plan-20261029-01a18660`. It is planning only. It does not implement, does not edit the PRD or source, and does not authorize implementation. The coordinator publishes `contracts/protocols/strategy/weir/WEIR_VAULT_SOURCE_IMPORT_IMPLEMENTATION_AND_TEST_PLAN.md`. No peer original was read.

Session identity is the instructed Grok member. This original does not independently attest a provider route slug.

Frozen PRD: `docs/research/weir-source-import-plan-20261029-01a18660/inputs/PRD.md`, revision `weir-import-prd-owner-clarifications-20261029`. Coordinator SHA-256 `c9316907a22d3ea0c2568aed74053a8911812fc1a6c424d162cb805e3ab4a551`, 96,598 characters. That hash is supplied identity. This original did not hash the file.

Evidence labels used below:

- Source observation: read in this pass from the frozen domain files or the current canonical tree.
- Supplied evidence: PRD or brief statement not re-executed here.
- Proposed: a name or path that does not exist yet.
- Unverified gate: a future proof. Absence of a run is not a pass.

## 1. Authority, scope, exclusions, gates

Authority order for the future implementer:

1. Owner-clarified PRD, including all 37 WI requirements and all 69 AC rows. This plan does not add a WI or an AC, and it does not drop one.
2. Frozen domain sources, not a paraphrase: `src/WeirVaults.sol.txt` (427 lines), `src/base/WeirBase.sol.txt` (88 lines), `src/libraries/LiquidityAmounts.sol.txt` (68 lines), all read completely in this pass.
3. Root profile, artifact, and cache law in `CLAUDE.md` and `docs/testing/ARTIFACT_BUILDS.md`, plus the owner baseline-scope override.
4. Canonical Crane files only after the compatibility gate. A mismatch is a stop, not a silent Weir edit.

Generic skill examples that this plan explicitly does not follow:

- `crane-porting` default destination `contracts/external/<protocol>/`, private-tree expansion, Service/Aware/DFPkg wrapper minimum, and `rm -rf cache out`.
- `crane-porting-verification` fork layout under `test/foundry/spec/.../fork`, `ETH_RPC_URL`, and `preview == execute` as a universal gate.
- `crane-testing` / IndexedEx law requiring `IndexedexTest`, facet declaration tests, package declaration tests, ERC20 `name`/`symbol`/`decimals` policy tests, and registry deployment. The PRD selects `CraneTest` directly and forbids that product wiring.
- Any restoration of the deleted legacy V4 Standard Exchange family or either deleted V4 FullSpread family. V3 FullSpread is a different family and is out of scope, not a template.

In scope: copy the three domain files to the owner path, apply the 22 import rewrites, the one added `PoolOperation` import, and the five free-struct qualifications, compile at solc 0.8.35 / optimizer runs 1 / `via_ir = false`, and prove the copy with real-manager tests and an honest fork gate.

Out of scope: ERC20/ERC4626 wrapping, Rate Provider, NAV issuance, SE/Diamond/registry, hook-only unlocked path, genesis-share removal, fee removal, inbound balance-delta repair, native `sync(0)`, extra reentrancy guards, exact-ratio zap, strict single-token exit, viaIR, a new Foundry profile, `FOUNDRY_TEST` changes, cache deletion, production factory deployment of Weir, license scrubbing, and economic repair. A failing test is fixed by fixing the import or by recording an unreachable branch. It is not fixed by weakening the assertion or by changing business logic.

This plan is not implementation authorization. Compiler success, hermetic proof, fork parity, security characterization, and release clearance are separate gates. None was run here.

### Unverified gates carried from supplied evidence

- Frozen file hashes, Sourcify match, deployment receipt, and the public RPC historical-state failure. This original made no hash, RPC, or transaction call.
- Coordinator comparison that six OZ v5 files are byte-identical and that SafeERC20 used paths match. Those files were not re-read here.
- FullMath revert bytes, Position key bytes, Currency transfer wrapper, and Pool.donate fee-growth. Not re-derived from those bodies here, except the Pool.initialize comment that initial protocol fee is 0.
- `ALCHEMY_KEY` is absent in the authoring process. Fork execution is not claimed.
- Upstream Git pin, upstream tests, and upstream audit are absent. Do not invent them.
- Business Source production clearance is not established. June 15, 2027 is a latest calendar date, not an expiry proof.

## 2. File inventory

### Production, proposed, required by WI-01 and WI-03

| Path | Status |
|---|---|
| `contracts/protocols/strategy/weir/WeirVaults.sol` | Proposed |
| `contracts/protocols/strategy/weir/base/WeirBase.sol` | Proposed |
| `contracts/protocols/strategy/weir/libraries/LiquidityAmounts.sol` | Proposed copy of frozen GPL library, not the canonical namesake |
| `contracts/protocols/strategy/weir/VENDOR.md` | Proposed. Co-located. Do not also create `contracts/external/weir/` |

No second domain tree. Frozen `.sol.txt` files stay research references and are not compiled.

### Test infrastructure, proposed names, following verified `TestBase_` / `Behavior_` / `Handler` shape

Owner directory: `contracts/protocols/strategy/weir/test/`.

| Proposed path | Role |
|---|---|
| `test/bases/TestBase_WeirVaults.sol` | Hermetic setup. Inherits verified `CraneTest`. Does not inherit `IndexedexTest` |
| `test/peripherals/WeirAuxRouter.sol` | Real `IUnlockCallback`. Donate, external liquidity, sync, nested-unlock owner. Not a manager mock |
| `test/peripherals/WeirExactERC20.sol` | Mintable exact-transfer non-rebasing peripheral |
| `test/peripherals/WeirHostileERC20.sol` | False, empty return, explicit revert, short delivery |
| `test/peripherals/WeirRejectReceiver.sol` | Rejects native with known revert bytes |
| `test/peripherals/WeirCallbackActor.sol` | Payer, token, treasury, or recipient that calls back into Weir |
| `test/peripherals/WeirObserveHook.sol` | Records hookData and applicable callbacks. Separate return-delta mode |
| `test/peripherals/WeirLiquidityAmountsHarness.sol` | Exposes the copied L library. Not a vault |
| `test/behaviors/Behavior_WeirVaults.sol` | Exact ledger, event, and inventory assertions. Not an `IFacet` declaration behavior |
| `test/handlers/Handler_WeirVaults.sol` | Supported-domain invariant handler |
| `test/handlers/Handler_WeirVaultsHostile.sol` | Separate hostile campaign |
| `test/oracle/WeirMathOracle.sol` | Independent integer oracle. Test-only. Weir production files must not import it |

Do not invent `IWeirVaults`, a Service, an AwareRepo, a facet, or a DFPkg. Tests call the concrete copied contract.

### Spec and fork tests, proposed under verified profile roots

Verified roots, source observation of root `foundry.toml`: default `test = 'test/foundry/spec'`; fork `test = 'test/foundry/fork'`. The `weir` subdirectories are proposed.

| Proposed file | Contract | ACs |
|---|---|---|
| `test/foundry/spec/protocols/strategy/weir/WeirVaults_Provenance.t.sol` | `WeirVaults_ProvenanceTest` | AC01, AC02, AC03, AC68, AC69 |
| `test/foundry/spec/protocols/strategy/weir/WeirVaults_Surface.t.sol` | `WeirVaults_SurfaceTest` | AC04 is not this file; AC05-AC08, AC62 |
| `test/foundry/spec/protocols/strategy/weir/WeirVaults_Deposit.t.sol` | `WeirVaults_DepositTest` | AC09-AC20 |
| `test/foundry/spec/protocols/strategy/weir/WeirVaults_Withdraw.t.sol` | `WeirVaults_WithdrawTest` | AC21-AC27, AC37 |
| `test/foundry/spec/protocols/strategy/weir/WeirVaults_CompoundInventory.t.sol` | `WeirVaults_CompoundInventoryTest` | AC28-AC36 |
| `test/foundry/spec/protocols/strategy/weir/WeirVaults_ViewsMath.t.sol` | `WeirVaults_ViewsMathTest` | AC38-AC47 |
| `test/foundry/spec/protocols/strategy/weir/WeirVaults_NativeAccess.t.sol` | `WeirVaults_NativeAccessTest` | AC48-AC53 |
| `test/foundry/spec/protocols/strategy/weir/WeirVaults_CallbackHook.t.sol` | `WeirVaults_CallbackHookTest` | AC54-AC61 |
| `test/foundry/spec/protocols/strategy/weir/WeirVaults_Invariant.t.sol` | `WeirVaults_InvariantTest` | AC63 |
| `test/foundry/spec/protocols/strategy/weir/WeirVaults_Hostile.t.sol` | `WeirVaults_HostileTest` | AC64, AC67 |
| `test/foundry/spec/protocols/strategy/weir/fixtures/swap-golden.json` | none | Provenance for swap vectors. Not prose |
| `test/foundry/fork/protocols/strategy/weir/WeirVaults_ForkParity.t.sol` | `WeirVaults_ForkParityTest` | AC65 |

AC04 and AC66 are static release records in `VENDOR.md` and a proposed `contracts/protocols/strategy/weir/IMPORT_EVIDENCE.md`. They are not Forge tests that can go green by skipping. AC03's compile gate is the build command, with the provenance test only asserting that a successful artifact exists and that `via_ir` was not enabled. A failed build is reported. It is not turned into a passing test.

### Verified existing routes used, and routes refused

Use these existing files. Do not copy them into a private tree.

| Existing path | Use |
|---|---|
| `lib/crane/contracts/test/CraneTest.sol` | Parent setup. `setUp` calls `BetterTest.setUp` then `InitDevService.initEnv` once |
| `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol` | The only manager. Constructor is `constructor(address initialOwner)` |
| `lib/crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol` | Free `ModifyLiquidityParams` and `SwapParams` |
| `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol` | Reads. `POOLS_SLOT = bytes32(uint256(6))`. Position key via `Position.calculatePositionKey`. Pool-state hash uses `._hash()` |
| `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol` | Extrema and usable ticks |
| `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol` | Flag constants and address validity |
| `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol` | Errors `CurrencyNotSettled`, `AlreadyUnlocked`, `NonzeroNativeValue`, `PoolNotInitialized` |
| `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol` | `CHAIN_ID = 4663`, `DEFAULT_FORK_BLOCK = 76_197_114`, `UNISWAP_V4_POOL_MANAGER = 0x8366a39CC670B4001A1121B8F6A443A643e40951` |
| `lib/crane/lib/forge-std/src/Vm.sol` | `rpcUrl`, `createSelectFork`, `snapshotState`, `revertToState` |
| Root `foundry.toml` | Two profiles only. RPC aliases below |

Refused as setup parents, even though they exist:

- Orbital, weighted, dual, and decimal V4 hook TestBases. They deploy `new PoolManager(address(this))`, which confirms the constructor, but they pull vault or hook product wiring.
- `TestBase_PonsFamilyV2`. Same constructor shape, launchpad owner story.
- `lib/crane/contracts/protocols/dexes/uniswap/v4/hooks/public/dependencies/v4-core/test/utils/Deployers.sol`. Do not import a second manager tree.
- `TestBase_UniswapV4EthereumMainnetFork` and its quote tolerance. Supplied PRD finding, not a chain 4663 fixture.
- `contracts/test/bases/TestBase_UniswapV4WingsSeSurface.sol`. Supported SE family, not this import.
- Deleted legacy V4 SE and V4 FullSpread paths. Do not recreate `test/foundry/spec/protocol/dexes/uniswap/v4/`.

Decision: hermetic manager route is a minimal real-port deployment of the canonical `PoolManager` inside proposed `TestBase_WeirVaults`, after `CraneTest.setUp()`. It is not a mock and not a subclass of a product TestBase.

### Canonical import targets, selected by the PRD

The 22 rewrites are the PRD allowlist. This original did not re-open every target body. WP-00 must confirm each file exists before the copy is accepted. Paths already opened in this pass are TickMath, StateLibrary, PoolOperation, IPoolManager, PoolManager, Hooks, and ProtocolFees. The OZ v5 paths and `uniswap/libraries/FullMath.sol`, `FixedPoint96.sol`, and `FixedPoint128.sol` are PRD-selected and still an existence-and-body gate.

Additional import, not one of the 22 rewrites: `WeirVaults.sol` imports `{ModifyLiquidityParams, SwapParams}` from `@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol`. Five qualifications change, and nothing else:

- Frozen W:264, W:292, W:323, W:349 `IPoolManager.ModifyLiquidityParams` becomes free `ModifyLiquidityParams`. Source observation: those are the deposit add, withdraw remove, compound poke, and compound reinvestment calls.
- Frozen W:397 `IPoolManager.SwapParams` becomes free `SwapParams`.

Field order read from canonical `PoolOperation.sol`: modify is `tickLower`, `tickUpper`, `liquidityDelta`, `salt`; swap is `zeroForOne`, `amountSpecified`, `sqrtPriceLimitX96`. Equivalence to the frozen nested structs remains an unverified diff gate. Do not change values, call order, storage, or selectors.

## 3. Work packages

Artifact writers are serialized. Default and fork profiles share `out` and `cache_forge`. Never run two `forge build`, `forge test`, or `scripts/forge-artifacts.py` processes against that pair at once. Never delete those directories. Never set `FOUNDRY_TEST`. Never add a profile. Never pass `--via-ir`.

### WP-00. Compatibility gate

Depends on nothing. Blocks WP-01 acceptance.

Allowed edits: none in production. Notes may be drafted only in the future `VENDOR.md` after WP-01 creates it. Until then the gate result is a review record the implementer writes into `VENDOR.md` in the same change as the copy.

Single owner: the import owner. No parallel editor of the three domain files.

Steps:

1. Confirm the 22 target files and `PoolOperation.sol` exist. Confirm canonical `LiquidityAmounts` is not used as the Weir library.
2. Diff frozen nested `ModifyLiquidityParams` and `SwapParams` against `PoolOperation.sol` field order, types, and ABI encoding. Record the diff. Stop if encoding differs.
3. Diff used StateLibrary surface: `POOLS_SLOT`, `getSlot0`, `getPositionInfo`, `getFeeGrowthInside`, position-key preimage, signed tick encoding, and the `._hash()` helper. Matching slot 6 is not enough. A later hermetic round-trip must show `getSlot0` nonzero after real `initialize`, and `getPositionInfo` returning Weir as owner at salt zero after a real add.
4. Re-hash the six claimed byte-identical OZ files and diff SafeERC20 `safeTransfer`, `safeTransferFrom`, and `_callOptionalReturn` only. Do not mix Context families. Do not upgrade to 5.6.1.
5. Read `Pool.donate` fee-growth and protocol-fee skim. Source observation already: `Pool.sol` says the initial protocol fee is 0 and does not set it; `ProtocolFees` leaves `protocolFeeController` unset. The test must still assert the fresh pool protocol fee is 0 before F1. If donate of 20 into sole liquidity `K` does not accrue gross 20, stop and report a manager-math mismatch. Do not edit Weir so the test matches 20.
6. Read Currency transfer and CustomRevert wrapping enough to name the actual error envelope for AC50 and reverting hooks. Do not guess selectors.

Exit: a written pass/fail per surface. Any behavior-changing mismatch stops the import. Expected output is a compatibility section, not a green test.

Parallel: none with WP-01 file writes. Reading may overlap WP-03 design.

### WP-01. Domain copy

Depends on WP-00 pass. Single owner of the three Solidity files and `VENDOR.md`.

Allowed edits: only the four proposed production paths.

Steps:

1. Copy frozen bodies. Keep SPDX, comments, storage order, inheritance order `WeirBase, Ownable2Step, Pausable, ReentrancyGuard`, constants, and function order.
2. Apply the 22 specifier rewrites and the relative Weir imports unchanged.
3. Add the `PoolOperation` import and the five qualification edits. No other token edits.
4. `VENDOR.md` records frozen identifiers, all 39 transitive entries, metadata keccak256 and SHA-256 values from the manifest, original-to-local map, both hash columns, the 22 rewrites, the added import, the five qualifications, compiler settings, license declarations, deployment table, chosen RPC alias, and missing upstream Git/tests/audit. Frozen-byte hashes and adjusted production hashes stay distinct.

Exit: `git diff` against the frozen texts shows only the allowlist, or the work stops. This original does not run git. The future implementer records the diff in `VENDOR.md`.

### WP-02. Compile, and WI-06 only after a diagnostic

Depends on WP-01. Same single owner. Serialized artifact writer.

Allowed edits: the three domain files only if the compiler demands it, plus the `VENDOR.md` diagnostic record. No `foundry.toml` edit.

Steps:

1. Seed a new worktree from warm `out/` and `cache_forge/` if the checkout is cold. Do not delete either.
2. Run the focused artifact command in section 11. Wait for process exit. A quiet solc is not a hang.
3. If the build succeeds, record that WI-06 was not used.
4. If it fails on stack depth, apply only lexical scopes or internal memory structs around existing temporaries. Preserve ABI, storage, inheritance, checked order, casts, calls, fees, events, errors, and notices. Record the diagnostic and the exact diff. Rebuild.
5. Do not pre-apply WI-06 "just in case". Do not enable viaIR. A behavior-changing fix is a separate decision and is out of this plan.

Exit: build exit 0 under the observed default settings, or a recorded blocker. No money-path test is accepted before this exit.

Parallel after exit, on disjoint files: WP-03 already designed; WP-04, WP-05, WP-06, and WP-08 may be authored in parallel. Only one of them may invoke the artifact writer at a time. Execution of money-path assertions waits for WP-04 ABI identity.

### WP-03. Topology and shared test surface

Depends on WP-00 for manager choice, and on WP-02 before any test is executed. Design may proceed beside WP-01.

Single owner of `TestBase_WeirVaults.sol`, `WeirAuxRouter.sol`, `WeirMathOracle.sol`, and `Behavior_WeirVaults.sol`. Other authors call this surface. They do not declare a second manager, a second Weir, or an oracle that calls `previewRedeem` or `LiquidityAmounts`.

Allowed edits: `contracts/protocols/strategy/weir/test/**` only.

Published surface, proposed names:

- `setUp()` calls `CraneTest.setUp()` first, then deploys manager and Weir if still zero.
- `initHookless(PoolKey key, uint160 sqrtP) returns (PoolId)`.
- `initObserveHookPool(...)` and `initReturnDeltaHookPool(...)`.
- `WeirAuxRouter.donate(PoolKey,uint256,uint256,address payer)`.
- `WeirAuxRouter.addLiquidity(PoolKey,int24,int24,int256,bytes32,address payer)`.
- `WeirAuxRouter.syncThen(Currency,address target,bytes data)` for AC51.
- `WeirAuxRouter.callWhileUnlocked(address target,bytes data)` for AC58.
- `WeirMathOracle` pure functions listed in section 5. No Weir import.
- `Behavior_WeirVaults.assertClosedInventory(...)`, `assertPosition(...)`, `assertNoSubtreeEffects(...)`.
- `snap()` wraps verified `vm.snapshotState`. `restore(uint256)` wraps verified `vm.revertToState`.

Exit: one compiling TestBase that deploys a real manager and a real Weir, with labels, and with no `vm.mockCall`, etch, or storage write against either.

### WP-04. Surface, ABI, library

Depends on WP-02 and WP-03. Owner of `WeirVaults_Provenance.t.sol`, `WeirVaults_Surface.t.sol`, and the L harness.

Blocks acceptance of WP-05 assertions. Authoring may overlap.

Exit: AC01-AC03, AC05-AC08, AC42-AC45, AC68 machine checks pass, or the failing check is a recorded compatibility stop. AC04 is not closed here.

### WP-05. Money paths

Depends on WP-04 ABI and storage identity. Owner of deposit, withdraw, compound, and views files.

Exit: F0-F3 and the non-callback money ACs match the independent oracle. A mismatch against the oracle fails. A mismatch against PRD prose where the oracle and the source agree is a PRD-note, not a Weir edit. F1 gross-20 is accepted only if the real donate produces 20. Otherwise stop at the manager-math gate.

### WP-06. Callbacks, native, hostile

Depends on WP-03 router and WP-05 fixtures. Owner of native, callback, and hostile files. May be authored earlier. Do not execute against a mock manager.

Exit: each reachable hostile case has an exact error or an exact balance trace. Unreachable cases have a written gap. No AC63 invariant is asserted inside this package.

### WP-07. Supported-domain invariants

Depends on WP-05 actions and the ghost rules in section 8. Owner of the invariant file and `Handler_WeirVaults.sol`.

Exit: campaign log with seed, configured runs 16, depth 8, success count greater than zero, and the smallest failing sequence if any. A campaign of only rejected calls fails the package.

### WP-08. Fork parity

Depends on WP-02 compile of the copy, and on the hermetic artifact writer being idle. Owner of the fork file only.

Isolated `FOUNDRY_PROFILE=fork`. Do not overlap a default-profile build.

Exit: either a compared parity trace, or `ForkPreflightBlocked` classified NOT RUN/BLOCKED. Never a skip, never a substituted chain, never a pass.

### WP-09. Release record

Depends on WP-04 through WP-08 having an honest status, including blocked and gap statuses. Owner of `IMPORT_EVIDENCE.md` and the VENDOR release section. No production logic edits.

Exit: AC66 map filled with file, command, or explicit unresolved gate for every WI and AC. No safety or legal clearance sentence.

Parallel summary: after WP-02, tracks A surface, B money, C callback, and D fork-authoring are disjoint files. Builds are not parallel. Fork execution is last among artifact jobs. WP-09 is last and does not rerun a green build just to touch prose.

## 4. Deployment and topology

`TestBase_WeirVaults.setUp`:

1. `CraneTest.setUp()`. Factories exist so the ladder is satisfied. They are not used to deploy Weir, the manager, tokens, hooks, or the router. No registry call. No `indexedexManager`. No proxy.
2. `poolManager = new PoolManager(address(this))` if unset. Verified constructor. `address(this)` is the protocol-fee owner. Do not set a protocol fee. Assert fresh pools report protocol fee 0.
3. `weir = new WeirVaults(poolManager, treasury, owner)` if unset. Nonzero treasury and owner for the happy fixture. AC05 deploys separate instances for the zero-address cases, including zero manager, which must be stored and not rejected.
4. Deploy three exact ERC20 peripherals and sort every key. `currency0 < currency1` is required. Source observation: `initialize` reverts `CurrenciesOutOfOrderOrEqual` otherwise. Native is address zero, so it is currency0. Shared-currency pair is `(A,B)` and `(A,C)` with `A < B < C`.
5. `vm.label` every deployed address. Idempotent zero-address guards.

Pool creation is not `createVault`. The test calls `poolManager.initialize(key, sqrtP)` directly. Source observation: `initialize` is not `onlyWhenUnlocked`; it calls `beforeInitialize` and `afterInitialize`. For hookless keys the hook address is zero, which is valid only if `isValidHookAddress` accepts it for that fee. F0 uses fee 0 and tick spacing 1. Spacing 1 is inside the observed `MIN_TICK_SPACING`..`MAX_TICK_SPACING`. Whether fee 0 passes `getInitialLPFee` and hook validation is an unverified gate: if `initialize` rejects fee 0, stop with a dependency report. Do not pick a different fee and still call the fixture F0.

F0 price input is `TickMath.getSqrtPriceAtTick(0)`. The test asserts that return equals `FixedPoint96.Q96` once. If it does not, stop. Expected liquidity is computed by `WeirMathOracle` from the returned price, not by calling Weir.

`createVault` then reads slot0, stores `minUsableTick(spacing)` and `maxUsableTick(spacing)`, pushes `allVaults`, and emits `VaultCreated`. Source observation: spacing 1 yields `MIN_TICK` and `MAX_TICK` because both divide evenly by 1. It does not call a pool hook.

Position owner is the Weir address. Salt is `bytes32(0)`. Ticks are the stored full-range ticks. Assert with `StateLibrary.getPositionInfo(manager, id, address(weir), tickLower, tickUpper, bytes32(0))`. The payer and the share recipient must not be that position owner.

External liquidity and donations go through `WeirAuxRouter`, which is the unlock caller and the position owner for its own adds. It settles its own debts before returning. Direct transfers to Weir or to the manager are not donations.

Hooks are peripherals deployed by CREATE2 so the address flags match `Hooks` permissions. Do not etch Weir or the manager. Do not etch a hook if CREATE2 works. Confirm the installed Vm CREATE2 helper name before use; do not invent a cheatcode. After deploy, require `isValidHookAddress(fee)`.

Observe-hook flags, source observation of `Hooks.sol`: before/after add (`1 << 11`, `1 << 10`), before/after remove (`1 << 9`, `1 << 8`), before/after swap (`1 << 7`, `1 << 6`). Return-delta mode also sets after-add and after-remove return-delta bits (`1 << 1`, `1 << 0`) and must keep the matching after flags, because the validity check rejects a return-delta bit without its base permission. Do not add donate or initialize permissions unless that test needs them.

No SUT inheritance. No `vm.mockCall` of Weir or the manager. No storage injection. No fabricated `BalanceDelta`.

## 5. Independent oracle

`WeirMathOracle` is a test-only pure library. It does not import Weir, `LiquidityAmounts`, `previewRedeem`, `FullMath`, or `ConstProdUtils`. It implements full-width `MD(x,y,d) = floor(x*y/d)` with limb arithmetic, empty revert on `d = 0` or overflow, matching the PRD FullMath contract as a specification. If this oracle and canonical `FullMath` disagree on a vector, that is a dependency mismatch, not a Weir change.

Stage rules, from the PRD arithmetic section and the frozen L source:

- Sort bounds first, inside each function, as the source does.
- `L0(A,B,a) = U128(MD(a, MD(A,B,Q), B-A))`.
- `L1(A,B,a) = U128(MD(a,Q,B-A))`.
- `U128` reverts `Error("liquidity overflow")` when the value does not fit. Narrow each branch before `min`. An unused larger branch still reverts.
- `A0(A,B,l) = floor(MD(l*Q, B-A, B) / A)`.
- `A1(A,B,l) = MD(l, B-A, Q)`.
- Deposit cushion: `amount > 2 ? amount - 2 : 0`, applied before L, at the post-zap price.
- Genesis: if `l <= 1000` revert `ZeroShares`; else user shares `l - 1000`, total shares become `l`. The 1000 reserve has no holder.
- Later shares: `floor(l * T / Lp)` with checked mul/div. Idle is not in the denominator.
- Withdraw: `uint128(floor(Lp*s/T))`, idle claims `floor(I*s/T)`, then subtract. Zero removed liquidity skips the manager remove. Zero claims still burn shares if minima are zero.
- Fee cut: `floor(gross * bps / 10000)` per currency. Default bps 500, cap 1000.
- Idle update: `uint256(int256(oldIdle) + net)`. Negative sums wrap to a large uint256. This is not a cast revert.
- `int128`, `uint128`, and `int256` stay distinct. A positive `int128` fits `uint128`. Do not synthesize a fee above `2^128-1`.
- Timestamp store is `uint64(block.timestamp)`.

Deposit balancing, source observation of `_balance`: `V = MD(MD(a0,P,Q),P,Q)`. If `V > a1`, sell `floor((a0 - MD(MD(a1,Q,P),Q,P)) / 2)` of currency0. If `a1 > V`, sell `floor((a1-V)/2)` of currency1. Otherwise no swap. A computed input of 0 returns before the swap. Sizing then uses signed returned deltas and the post-swap slot0. This is not an optimizer and not a constant-product oracle.

Swap outputs are not taken from Weir and not from `x*y=k`. For no-swap fixtures the integer oracle is enough. For one-swap fixtures, WP-05 must first extract canonical `Pool` step rounding into the same limb oracle, or commit `swap-golden.json` with the formula, the fee, the liquidity, the start price, the limit, and the stage-by-stage floors. No price tolerance. Until that oracle exists, AC15 swap subcases, AC16, AC24, AC25, and AC37 are not passable. Do not stub them.

### Recomputed anchors

Using canonical `TickMath` constants read in this pass: `MIN_SQRT_PRICE = 4295128739`, `MAX_SQRT_PRICE` as in that file, `minUsableTick(1) = MIN_TICK`, `maxUsableTick(1) = MAX_TICK`, `Q = 2^96`, `K = 2^20 = 1048576`.

| Anchor | Recomputed result | Label |
|---|---|---|
| F0 liquidity from `K` of each token at `P = Q`, full range | `L0 = L1 = K` | Recomputed here. Not a test run |
| F0 recipient shares | `1047576` | Recomputed |
| F0 refund | `2` each, if the manager charges `K` per side | Manager charge is the PRD claim. Test must read the real add delta. If it is not `K`, the oracle for used/refund follows the real delta rules, and the liquidity claim is separately checked |
| F0 full assigned withdrawal, no fee, no zap | Removes `1047576` liquidity and returns `1047575` each. Residual `L = T = 1000`, idle 0 | Amounts recomputed. Residual shares follow the genesis rule |
| Liquidity 7 at that same range | `6` each | Recomputed. Supports AC39's quote claim |
| AC42 `A=Q`, `B=2Q`, amount 3 | `L0=6`, `L1=3`; reverse at liquidity 7 is amount0 `3`, amount1 `7` | Recomputed from the formulas, not by calling L |
| AC43 interior `(3,4)` at `P=Q`, bounds `Q/2` and `2Q` | `min(6,8)=6`; amounts for liquidity 7 are `(3,3)` | Recomputed |
| AC39 `s = 2^128+7` at `L=T=K` | Checked product fits; `uint128` truncation of the quotient is 7 | Recomputed |
| AC39 `s = 2^236` | Product is `2^256`, checked mul panics `0x11` | Recomputed |
| F3 share and idle claim, given idle0 19 and `L=T=K` | Second user receives `K` shares; claim `floor(19/2)=9` | Arithmetic confirmed only if F1 actually leaves idle0 19 |

F1 gross 20 and F2 added liquidity 17 are supplied derivations. They become expected values only after a real donate and the independent fee formula agree. `K` dividing `2^128` was checked as arithmetic. It does not by itself prove `Pool.donate`.

## 6. AC01-AC69 rows

Every row is one AC. Subcases are named methods, not a range of ACs. Primary assertion is the exact result. Every success also runs the WI-33 inventory check unless the row is static or is an intermediate callback observation. Every failure compares the reverting subtree to a pre-call snapshot. Reachability uses: Static, Executable, Conditional, Gap-if-unreachable, Blocked-archive, Blocked-release.

| AC | Proposed test | Construction and precondition | Primary exact assertion | WP | Reachability |
|---|---|---|---|---|---|
| AC01 | Static diff plus `test_AC01_allowlistOnly` | Compare the three production files with the frozen texts after the allowlist | No unlisted edit. Notices and comments remain. `VENDOR.md` has both hash columns and any WI-06 diagnostic. Scopes, if any, do not change ABI or storage | WP-01, WP-02 | Static |
| AC02 | `test_AC02_abiEqualsManifest` | Compile, read the artifact ABI, compare with a machine copy of manifest `output.abi` taken from the frozen snapshot, not hand-rewritten | 27 functions, constructor, receive, 11 events, 18 listed errors, same tuples, indexing, and mutability. Propagated errors are not required to be absent from the ABI beyond the manifest | WP-04 | Executable after compile |
| AC03 | Build command, not a green skip | Default profile only | Exit 0, `via_ir=false`, or the exact diagnostic is the recorded blocker. No business-logic diff hidden in a green claim | WP-02 | Unverified until the build exits |
| AC04 | `VENDOR.md` license section. No Forge pass | Inspect full declarations and the resolved graph | 39 frozen entries accounted. GPL/AGPL marked open-source. BUSL marked source-available. Change date recorded as 2027-06-15 or earlier ENS/anniversary condition. Old GPL versus new MIT ambiguity kept. No inferred expiry or grant | WP-09 | Blocked-release for clearance. The import may still complete |
| AC05 | `test_AC05_validDeploy`; `test_AC05_zeroTreasury`; `test_AC05_zeroOwner`; `test_AC05_zeroManager` | Four separate deployments | Valid: fee 500, cap 1000, `MIN_SHARES` 1000, paused false, count 0, ownership event. Zero treasury `ZeroAddress`. Zero owner `OwnableInvalidOwner(0)`. Zero manager stored, no new reject | WP-04 | Executable |
| AC06 | `test_AC06_twoKeysSharedCurrency` | Two initialized pools differing in one key field, one shared currency | Distinct ids, usable ticks, exists true, zero accounting, array order, count +1 each, exact `VaultCreated` | WP-04 | Executable |
| AC07 | `test_AC07_duplicate`; `test_AC07_uninitialized`; `test_AC07_arrayOob` | Second create; create before initialize; `allVaults(count)` | `VaultExists`; `PoolNotInitialized`; `Panic(0x32)`. No extra array entry or log | WP-04 | Executable |
| AC08 | `test_AC08_unknown`; `test_AC08_emptyCreated` | Unknown id, then created vault before any deposit | Unknown struct default, quotes `(0,0)`, shares 0. Empty created keeps key, ticks, exists; quotes stay `(0,0)` | WP-04 | Executable |
| AC09 | `test_AC09_F0_payerNotRecipient` | F0, payer A, recipient B, `A != B`, no zap | Recipient shares `1047576`, A gets both refunds, event user B, salt-zero position owner is Weir, neither A nor B owns it. Used and refund follow the real add delta | WP-05 | Executable if fee-0 initialize works |
| AC10 | `test_AC10_raw1002`; `test_AC10_raw1003` | Fresh tick-zero fee-zero pools, paired raw inputs | 1002 reverts `ZeroShares` at liquidity 1000. 1003 mints liquidity 1001, one user share, refund 2 each | WP-05 | Executable |
| AC11 | `test_AC11_amounts012_fresh`; `test_AC11_amounts012_existing`; `test_AC11_oneSided_token0`; `test_AC11_oneSided_token1` | Fresh and existing vaults, interior price for one-sided | Zero resulting liquidity or shares reverts `ZeroShares`. Transfers and idle do not create a false success | WP-05 | Executable |
| AC12 | `test_AC12_secondPairedDeposit` | F0 then the same paired deposit, no fees | Second user receives `K` shares. Liquidity and total shares `2K`. Reserve gap stays 1000. First ledger unchanged | WP-05 | Executable |
| AC13 | `test_AC13_depositAfterRealFees` | Real donate or swap fees, then paired deposit | Compound applies cut, liquidity, and idle first. New shares are `floor(newL * postCompoundT / postCompoundL)`. Pre-compound L is not the price base | WP-05 | Executable once donate path works |
| AC14 | `test_AC14_F3_idleDilution` | F3 sequence | F3 integers, including the second user's idle0 claim of 9, and no extra payment for old idle. Do not fail a NAV assertion | WP-05 | Conditional on F1 |
| AC15 | `test_AC15_balancedNoSwap`; `test_AC15_xZero`; `test_AC15_currency0Heavy`; `test_AC15_currency1Heavy`; `test_AC15_singleSided0`; `test_AC15_singleSided1` | External liquidity, four imbalance shapes plus an `x=0` input | Direction and input match the nested-floor rule. Zero and no imbalance do not swap. Otherwise one swap. Sizing uses returned deltas and post-swap price. Shares, settlement, and refunds match the oracle | WP-05 | No-swap Executable. Swap subcases blocked on the tick oracle, not waived |
| AC16 | `test_AC16_zapFeesStayWithPayer` | Existing Weir liquidity in a fee-bearing pool, another payer zaps. Separate earlier fees from this swap's fees | First modify return includes same-call fees on old liquidity. Those fees reduce used input or credit the payer. No second cut. No incumbent share credit. Event used values match the source | WP-05 | Conditional on tick oracle and a fee-bearing initialize |
| AC17 | `test_AC17_minSharesEqual`; `test_AC17_minSharesPlusOne` | Successful deposit with computed shares S, replay at `minShares = S` and `S+1` | Equality succeeds. `S+1` reverts `Slippage` after callback work. Rollback includes auto-created vault, treasury fees, pulls, and refunds | WP-05 | Executable |
| AC18 | `test_AC18_transferOther`; `test_AC18_transferSelf`; `test_AC18_transferWeir`; `test_AC18_zeroUnknown`; `test_AC18_zeroRecipient`; `test_AC18_overspend` | Shares in one pool | Per-pool conservation and exact `SharesTransferred`. Self transfer unchanged after the debit check. Weir may hold stranded shares. Unknown zero transfer succeeds. Zero recipient `ZeroAddress`. Overspend `Panic(0x11)` | WP-05 | Executable |
| AC19 | `test_AC19_pausedDeposit`; `test_AC19_pausedOtherOps` | Pause a funded vault | Deposit `EnforcedPause`. Create, transfer, compound, withdraw, views, and receive keep their own outcomes | WP-05 | Executable |
| AC20 | `test_AC20_pausedBeatsReentrantAndDeadline`; `test_AC20_expiredBeatsRecipient`; `test_AC20_zeroRecipient` | Combined invalid inputs, then isolated cases | Paused before reentrancy before deadline. Body: recipient before auto-create, native check, and pulls. Unpaused expired zero recipient is `Expired`. Future deadline zero recipient is `ZeroAddress` | WP-05 | Executable |
| AC21 | `test_AC21_F0_fullWithdraw` | F0, zapTo 0, recipient differs from owner | Output `(1047575,1047575)` if the oracle amount holds. Recipient paid. Caller ledger 0. `L=T=1000`. Idle 0. Event user is the caller | WP-05 | Executable |
| AC22 | `test_AC22_subsetAfterFees` | Real fees and idle, withdraw a proper subset | Compound first. Burn and idle claims floor against post-compound total. No last-user sweep | WP-05 | Executable |
| AC23 | `test_AC23_zeroRemovedLiquidity`; `test_AC23_idleWithoutLiquidity`; `test_AC23_zeroOutputBurn` | Real fee/idle state, tiny share count chosen by the oracle | If removed liquidity is 0, no manager remove. Nonzero idle claim is still paid. All-zero claims can burn for zero output when both minima are 0. If a branch cannot be reached, record the gap | WP-05 | Gap-if-unreachable per branch |
| AC24 | `test_AC24_zap0`; `test_AC24_zap1`; `test_AC24_zap2` | Equivalent withdrawals, ample external liquidity | No swap, or sell positive currency1, or sell positive currency0. Input is that positive pre-zap net. Both outputs match signed swap deltas | WP-05 | Conditional on tick oracle |
| AC25 | `test_AC25_partialFill_zeroForOne`; `test_AC25_partialFill_oneForZero` | Price near a usable boundary, finite external liquidity, requested zap input exceeds consumption before the global limit | Swap stops at the limit or exhausted liquidity. Unsold currency is delivered. No full-consumption revert | WP-05 | Conditional on tick oracle |
| AC26 | `test_AC26_minimaEqual`; `test_AC26_min0PlusOne`; `test_AC26_min1PlusOne` | Replay the same start state | Equality succeeds. Each one-unit violation reverts `Slippage` and restores shares, position, timestamp, fees, idle, recipient balances, and persistent logs, even though payment happened before the check | WP-05 | Executable |
| AC27 | `test_AC27_zap3`; `test_AC27_recipient0`; `test_AC27_unknown`; `test_AC27_zeroShares`; `test_AC27_insufficient`; `test_AC27_expiredFirst` | Valid deadline, then remove earlier faults. Separate expired fixture | Ordered: `BadZap`, `ZeroAddress`, `NoVault`, `ZeroShares`, `Panic(0x11)`. Expired deadline is `Expired` before the body | WP-05 | Executable |
| AC28 | `test_AC28_emptyCompoundTwice` | Known empty vault, warp to `t` then `t+1` | `lastCompound` updates. No poke, no transfer, no `Compounded`, no empty-position error | WP-05 | Executable |
| AC29 | `test_AC29_unknownCompound` | Unknown key | `NoVault` before unlock. No timestamp write | WP-05 | Executable |
| AC30 | `test_AC30_F1`; `test_AC30_F1_secondCompound` | Aux donate 20 currency0, then compound, then compound again | First: gross 20, cut 1, idle 19, L unchanged, exact event, only if real donate accrues 20. Second: no event, idle unchanged, timestamp updated | WP-05 | Conditional on donate math |
| AC31 | `test_AC31_F2` | From accepted F1 state, donate 20 currency1, compound | Gross `(0,20)`, cut `(0,1)`, added 17, idle `(2,2)`, total shares unchanged, exact event and payments | WP-05 | Conditional on F1 |
| AC32 | `test_AC32_fee0`; `test_AC32_fee500`; `test_AC32_fee1000`; `test_AC32_gross19`; `test_AC32_gross20`; `test_AC32_selfTreasuryF1` | Real donations near the rounding boundary. Self-treasury extends F1 | Cut is `floor(f*bps/10000)`. Gross 19 at 500 bps cuts 0. Gross 20 cuts 1. Self-treasury: recorded idle 19, added 0, `T=K`, physical receipt 20, extra 1 unassigned. A later no-fee compound does not book that 1 to idle | WP-05 | Conditional on donate math |
| AC33 | `test_AC33_idleOnlyAdd` | One-sided idle from real fees, then a real swap moves price so it can be deployed, with no new positive harvest in the compound under test | L and idle change by the oracle. T fixed. No `Compounded`. Fees from the price-moving swaps are not counted as this compound's harvest | WP-05 | Conditional. Gap if no such fixture exists |
| AC34 | `test_AC34_directDonations`; `test_AC34_selfRecipientWithdraw` | ERC20 and native donations around F0. Separate full F0 withdrawal to recipient Weir, no zap, no fees | Donations alone do not change shares, idle, fees, or quotes. Self-recipient withdrawal delivers `1047575` each to Weir, idle stays `(0,0)`, `L=T=1000`, holder shares 0. Receipts are unassigned. Receive emits no vault event | WP-05 | Executable |
| AC35 | `test_AC35_sharedCurrencyIsolation` | Two funded vaults share a currency. Accrue and operate on one | Only the selected vault's accounting and position change. Physical balance equals the sum of recorded idle for that currency plus tracked unassigned inventory | WP-05 | Executable |
| AC36 | `test_AC36_noAllowance`; `test_AC36_noBalance` | Pre-existing inventory, exact-transfer token, missing allowance or missing payer balance | Token-specific exact failure. Inventory is not a substitute. No new shares and no inventory loss. Short delivery is AC55, not a safety claim here | WP-05 | Executable |
| AC37 | `test_AC37_exitSwapFeesRemain` | Burn, then zap in a fee-bearing pool | Exit-swap fees accrue to remaining real liquidity. They are not allocated to burned shares and are not auto-compounded again. Later pending and compound match the floor formula | WP-05 | Conditional on tick oracle |
| AC38 | `test_AC38_previewZero`; `test_AC38_previewFraction`; `test_AC38_previewAllTotal`; `test_AC38_previewAboveCaller` | F0 and fee/idle variants | Independent downward amounts plus floored idle. No ownership check. No state change. `totalShares=0` does not read the manager | WP-05 | Executable |
| AC39 | `test_AC39_shareCastFits`; `test_AC39_shareProductOverflow`; `test_AC39_zeroTotalShortCircuit` | `L=T=K`, idle 0, then a separate zero-total vault | First quotes liquidity 7, which is 6 units each at the F0 range. Second `Panic(0x11)`, not a cast error. Zero total returns `(0,0)`, not division panic | WP-05 | Executable |
| AC40 | `test_AC40_previewOmitsFees`; `test_AC40_previewOmitsZap`; `test_AC40_equalityWhenPrerequisitesHold` | Pending fees, then a withdrawal that compounds. Separate zap fixture. Separate no-pending no-zap fixture | Preview and execution each match their own formula. Equality is required only in the no-pending, no-maintenance, no-zap fixture | WP-05 | Executable |
| AC41 | `test_AC41_pendingInside`; `test_AC41_pendingBelow`; `test_AC41_pendingAbove`; `test_AC41_modularWrapVector` | Real position with fee growth. Wrap vector is independent math if a live wrap cannot be reached | `floor(((inside-last) mod 2^256) * positionL / 2^128)` per currency, gross of performance fee, no state change | WP-05 | Inside Executable. Range and wrap Gap-if-unreachable |
| AC42 | `test_AC42_boundsOrdered`; `test_AC42_boundsReversed` | Harness, `A=Q`, `B=2Q`, amount 3 | `L0=6`, `L1=3` both orders. Liquidity 7 converts to amount0 3 and amount1 7 | WP-04 | Executable |
| AC43 | `test_AC43_interiorMin`; `test_AC43_atLower`; `test_AC43_atUpper` | Bounds `Q/2` and `2Q`, amounts `(3,4)`, then `P=A` and `P=B` | Liquidity 6. Amounts for liquidity 7 are `(3,3)`. Boundaries take the source outer branch | WP-04 | Executable |
| AC44 | `test_AC44_overflowAmount0Branch`; `test_AC44_overflowAmount1Branch` | Interior `P=Q`, amounts `(2^127,1)` then `(1,2^127)` | `Error("liquidity overflow")` on the overflowing branch even though the other branch fits | WP-04 | Executable |
| AC45 | `test_AC45_equalBounds`; `test_AC45_amount0DivByZero` | Equal nonzero bounds. Separate `A=0`, `B=Q`, liquidity 1 | Empty FullMath revert, then `Panic(0x12)`. No new invalid-range error | WP-04 | Executable |
| AC46 | `test_AC46_timestampMax`; `test_AC46_timestampWrap`; `test_AC46_timestampWrapPlus`; `test_AC46_deadlineEqual`; `test_AC46_deadlineMinusOne` | Empty known vault. Separate valid deposit and withdraw fixtures | Stored timestamps `2^64-1`, 0, 7. Deadline equality accepted. `t-1` is `Expired` and restores the prior timestamp | WP-05 | Executable |
| AC47 | `test_AC47_fuzzOracleDomain` | Fuzz inside the independent valid domain, plus explicit overflow bounds | Nested-floor and cast results, exact error class. Raw units, no decimal normalization | WP-05 | Executable. Configured fuzz runs are 16. Do not edit `foundry.toml` to raise them |
| AC48 | `test_AC48_nativePaired`; `test_AC48_nativeZap`; `test_AC48_nativeValueLow`; `test_AC48_nativeValueHigh`; `test_AC48_erc20ValueRejected` | Native/ERC20 pool, then ERC20/ERC20 with value 1 | Correct value settles and refunds native with no WETH. Wrong value `BadNativeAmount`. Payer receives the native refund when the recipient differs | WP-06 | Executable |
| AC49 | `test_AC49_rejectingRefund`; `test_AC49_zeroRefundNoCall` | Payer contract rejects native | Nonzero refund: `NativeTransferFailed` and full rollback. Zero refund: no refund call and no failure from a rejecting receive | WP-06 | Executable |
| AC50 | `test_AC50_rejectingTake` | Native output or treasury cut to a receiver with known revert bytes | Manager currency-transfer envelope and nested receiver bytes, not `NativeTransferFailed`. No retained burn or fee cut | WP-06 | Executable. Selector is whatever Currency/CustomRevert actually emit. Do not invent it |
| AC51 | `test_AC51_syncBeforeUnlock_caught`; `test_AC51_syncBeforeUnlock_uncaught`; `test_AC51_syncDuringCallback_caught`; `test_AC51_syncDuringCallback_uncaught` | Non-native sync left open, then a Weir call that native-pays | `NonzeroNativeValue` because Weir does not `sync` native. Failed Weir subtree rolls back. A router sync survives only if the router catches. An uncaught revert rolls back the transaction. An inner failure does not close a router-owned unlock. No `sync(0)` repair | WP-06 | Executable |
| AC52 | `test_AC52_ownerMatrix`; `test_AC52_feeBounds`; `test_AC52_treasuryZeroAndRepeat` | Owner, non-owner, pending owner. Fees 0, 500, 1000, 1001 | Only current owner succeeds. Unauthorized is `OwnableUnauthorizedAccount(caller)` before body checks. 1001 is `FeeTooHigh`. Zero treasury is `ZeroAddress`. Accepted setters emit, including no-change | WP-06 | Executable |
| AC53 | `test_AC53_startReplaceCancelAccept`; `test_AC53_wrongAccepter`; `test_AC53_renounceWhilePaused` | Two-step ownership, then a separate pause-then-renounce fixture | Pending and current transitions and events match OZ. Wrong accepter error includes the caller. Pending cleared on accept and renounce. Former owner cannot unpause | WP-06 | Executable |
| AC54 | `test_AC54_reenterOnPull`; `test_AC54_reenterOnHook`; `test_AC54_reenterOnTake`; `test_AC54_reenterOnRefund`; paused twins of each | Real token, hook, treasury, recipient, or payer callbacks | Guarded reentry is `ReentrancyGuardReentrantCall` where reached. Paused deposit fails `EnforcedPause` first. A caught nested rejection can leave the outer call successful. A bubbling rejection rolls back at the failed boundary. Assert the actual caller and the actual wrapper | WP-06 | Executable |
| AC55 | `test_AC55_falseReturn`; `test_AC55_noReturnDelivered`; `test_AC55_explicitRevert`; `test_AC55_shortDelivery`; `test_AC55_shortDeliveryWithInventory` | Hostile token modes. Inventory seeded only in the last subcase | False is `SafeERC20FailedOperation(token)` at Weir's SafeERC20 site. Explicit revert bytes bubble. Empty return with real delivery is accepted. Short delivery is characterized: no inbound balance check, may spend inventory or fail later. No safety claim | WP-06 | Executable |
| AC56 | `test_AC56_callbackTransferShares`; `test_AC56_callbackCreateVault`; `test_AC56_callbackViews`; `test_AC56_ownerCallbackSetters` | Give the callback contract its own shares and, for the setter case, current ownership | Unguarded surfaces use their own checks. A token-driven transfer moves the token caller's shares, not another user's. Exact errors on insufficient authority or balance | WP-06 | Executable |
| AC57 | `test_AC57_treasuryChangesBetweenTakes` | Native currency0, both fee components positive, first cut strictly positive. Initial treasury is the current owner and changes treasury to T2 in its native callback | Cuts computed before either take. First native cut reaches the old treasury. Second cut uses T2. An ERC20 transfer alone is not a recipient callback. If the outer call reverts, the setter rolls back too | WP-06 | Executable |
| AC58 | `test_AC58_outsiderCallback`; `test_AC58_nestedUnlockCaught`; `test_AC58_nestedUnlockBubbles`; `test_AC58_guardedReentry` | Outsider calls `unlockCallback`. Router owns unlock and calls `compound`. Separate reentry from an active Weir call | Outsider `NotPoolManager` before decode. Nested unlock `AlreadyUnlocked`. Guarded reentry hits the guard first. A caught failure leaves the router unlock open until the router finishes. No invented inner relock | WP-06 | Executable |
| AC59 | `test_AC59_hookOrder`; `test_AC59_zeroLiquiditySkipsPoke`; `test_AC59_zeroReinvestSkipsAdd`; `test_AC59_createVaultNoHook`; `test_AC59_revertingHook` | Nonzero-L vault, observe hook, positive reinvestment. Separate zero-L and zero-reinvest fixtures | Supplied hookData unchanged. Applicable poke precedes reinvestment, then the user action. Record real manager hook calls. Zero L skips poke. Zero calculated add skips reinvestment. `createVault` does not call the pool hook. Reverting hook uses the real wrapped error and the real rollback boundary | WP-06 | Executable. Wrapper selector unverified until read from `Hooks.sol` |
| AC60 | `test_AC60_firstReturnNotFeesAccrued`; `test_AC60_negativeComponentUnsettled` | Return-delta hook. Hook settles its own hook delta. One case leaves Weir a negative component | Gross fee uses positive first-return components, not the informational second return. An unsettled negative Weir component ends in `CurrencyNotSettled` unless the source settlement pays it | WP-06 | Executable if the hook can return that delta. Otherwise Gap-if-unreachable |
| AC61 | `test_AC61_observeOnTreasuryTake`; `test_AC61_observeOnWithdrawSettle`; `test_AC61_observeOnDepositRefund` | Hostile receiver reads views and shares during those calls | Withdrawal debit precedes callback compounding. Deposit recipient credit precedes outer refunds. Do not claim every phase matches the end-of-transaction invariant | WP-06 | Executable |
| AC62 | `test_AC62_nonpayableValue`; `test_AC62_receive` | Low-level calls with value. Separate empty-calldata value | Nonpayable dispatch fails with the compiled target's actual revert bytes, not a made-up selector. Receive succeeds and does not change the ledger | WP-04 | Executable |
| AC63 | `invariant_AC63_supportedDomain` | Handler, at least 3 users and 2 pools, shared currency, exact-transfer tokens, no return-delta and no short delivery | After successful top-level completion, outside callbacks: recorded L equals salt-zero position L; assigned-share sum equals `T-1000` after genesis and 0 before; physical inventory reconciles; unlock deltas are closed. Classified failures use the subtree boundary. Hostile cases are excluded | WP-07 | Executable. Configured invariant runs 16, depth 8 |
| AC64 | `invariant_AC64_hostileCampaign` | Separate handler: callbacks, rejects, short delivery, return-delta, partial fills, pause, owner changes | Exact classified success or failure. Supported-domain invariants are not asserted across hostile assumptions | WP-06 | Executable for constructed cases. Partial fills depend on the tick oracle |
| AC65 | `test_AC65_forkPreflight`; `test_AC65_forkParitySelectedPool` | Fork recipe in section 10 | Preflight matches chain, block, hash, and code, or reverts `ForkPreflightBlocked`. Parity compares selected-pool returns, reverts, events, and mapped balances. No production key. No storage injection | WP-08 | Blocked-archive until an archive alias works. Not a pass now |
| AC66 | `IMPORT_EVIDENCE.md` map | After the other packages have statuses | Every WI and AC points to a test, a static check, or an explicit unresolved gate. Hermetic and fork statuses are separate. No upstream-parity or production-safety claim | WP-09 | Static |
| AC67 | `test_AC67_wrappedIdleOrGap` | Return-delta pool, F1/F2-style real idle, construct `int256(oldIdle)+net = -1`, donated physical currency pays the debt, hook settles its own deltas | If reached, recorded idle is `2^256-1`, not a cast revert. Assert physical balance and any later revert with full rollback. If not reached, record the precise gap. Do not claim fail-closed | WP-06 | Gap-if-unreachable until constructed |
| AC68 | `test_AC68_ozFileIdentity`; `test_AC68_storageLayout`; `test_AC68_tokenReturnMatrix` | Hash the six files. Read compiler storage layout. Run true, false, empty, and reverting token cases plus owner, pause, and guard cases | File identity holds or the import stops. SafeERC20 need not equal the whole frozen v5.1 file. Used paths keep typed failures. No mixed Context and no namespaced 5.6.1 guard | WP-04 | Executable as a gate. Identity itself is unverified in this original |
| AC69 | `test_AC69_resolvedGraphRecord` | After build, traverse compiler input sources | Frozen 39-file map stays provenance. Actual graph separately records StateLibrary's hashing helper and literal BSL/AGPL headers reached. Test-only AGPL is distinguished from runtime | WP-04, WP-09 | Executable as a record. License disposition remains Blocked-release |

## 7. WI-01 through WI-37 traceability

| WI | Closed by | Evidence | Does not close it |
|---|---|---|---|
| WI-01 | WP-01 | Three files at the owner paths, no second tree, frozen texts not compiled | A copy under `contracts/external` |
| WI-02 | WP-01, WP-02, AC01 | Allowlisted diff only, plus recorded WI-06 edits if diagnosed | A cleanup that still passes tests |
| WI-03 | WP-01 `VENDOR.md`, AC69 | Both hash columns, 39 entries, deployment table, missing upstream evidence | Adjusted hashes presented as frozen hashes |
| WI-04 | WP-00, AC42-AC45, AC68, hermetic round-trip | Surface diffs and runtime reads | Path resolution alone, or slot 6 alone |
| WI-05 | AC04, AC69 | Full declarations and resolved graph recorded | A MIT label, a scrub, or a clearance sentence |
| WI-06 | WP-02 | Default settings, diagnostic, exact diff, fidelity rerun | viaIR, a storage redesign, or a preemptive refactor |
| WI-07 | Scope check in WP-09 | No wrapper, registry, NAV, repair, or simulator in the diff | A characterization test used as a reason to fix |
| WI-08 | AC06, AC07, AC09 | Real initialize, permissionless create, salt-zero Weir position | A mocked slot0 |
| WI-09 | AC02, AC68 | ABI tuples and storage layout artifact | A renamed field with the same test names |
| WI-10 | AC02, AC05, AC62 | Manifest ABI compare, including zero-manager acceptance | An invented `balanceOf` or ERC4626 test |
| WI-11 | AC29, AC58, AC59 | Real unlock, `NotPoolManager`, `AlreadyUnlocked`, hookData passed through | A mock callback |
| WI-12 | AC09, AC17, AC20, AC48, AC61 | Modifier order, recipient credit, payer refund, payer credits | Crediting the recipient for manager credits |
| WI-13 | AC09, AC10, AC11 | Genesis formula and no holder for the 1000 reserve | A burn-address credit |
| WI-14 | AC12, AC13, AC14 | `floor(l*T/Lp)` after compound, idle excluded | NAV issuance |
| WI-15 | AC16, AC60 | First caller delta, not feesAccrued, not principal-only | A second fee cut |
| WI-16 | AC18, AC56 | Unguarded transfer, Weir can hold shares | An allowance model |
| WI-17 | AC21, AC26, AC27, AC61 | Debit before unlock, minima after settlement, event user is caller | Moving the minima earlier |
| WI-18 | AC21-AC25 | Separate floors, skip zero remove, pay idle before zap | A last-user sweep |
| WI-19 | AC15, AC24 | Nested-floor direction, one swap maximum, zero input skips | An exact-ratio solver |
| WI-20 | AC24, AC25 | Negative `int256(amountIn)`, limits `MIN_SQRT_PRICE+1` and `MAX_SQRT_PRICE-1`, partial fills kept | A consumption equality check |
| WI-21 | AC28, AC30, AC46 | Timestamp first, zero-L return, positive int128 fee components | A manufactured oversized delta |
| WI-22 | AC30-AC33, AC67 | Cut, cushion, idle cast, settle to Weir, shares unchanged | Booking a self-cut as extra idle |
| WI-23 | AC13, AC16, AC30, AC33, AC37 | Event only for positive harvest. Deposit swap fees stay in deposit settlement. Exit swap fees stay with the remainder | Using the event as a complete fee ledger |
| WI-24 | AC14, AC32, AC34, AC35, AC63 | Per-vault idle, unassigned donations, self-cuts, self-receipts, shared-currency sum | A rescue function or a universal `idle<=2` assert |
| WI-25 | AC08, AC38-AC41 | Stored vault, zero-total short circuit, preview formula, pending gross formula | Preview used as the execution oracle |
| WI-26 | AC19, AC52, AC53 | Owner-only setters, pause covers deposit only, repeat pause errors | A blanket pause |
| WI-27 | AC05, AC52, AC53 | Two-step ownership, pending has no current power, renounce sticks | A one-step transfer |
| WI-28 | AC54, AC56, AC58, AC61 | Guard only on deposit, withdraw, compound. Callback observations are not end-state invariants | A new guard |
| WI-29 | AC48-AC51, AC55, AC62 | Native is address zero. Exact msg.value. Sync/transfer/settle for ERC20. No native sync. Take failures keep the manager envelope | WETH, or relabeling `NonzeroNativeValue` as `NativeTransferFailed` |
| WI-30 | AC17, AC26, AC46, AC51, AC54 | Snapshot at the failed call subtree. Caught outer effects remain. Debug logs are not receipts | `expectRevert()` with no error, or a sleep |
| WI-31 | AC02, AC39, AC42-AC47, AC55 | Exact errors, panics, checked math, modular fee growth | `FullMath` substituted for a checked product, or SafeCast substituted for a source cast |
| WI-32 | WP-03, AC63 | Real Weir, real canonical manager, CraneTest parent, peripherals only outside the SUT | Mock, etch, or storage injection |
| WI-33 | Behavior helper used by every success row | Integer balances, shares, idle, position, timestamp, treasury, deltas, events, hookData | A lock-closed assert during a callback or during unguarded create/transfer/views |
| WI-34 | WP-05 oracle | Independent limb math and pre-state. Swap goldens have provenance | `previewRedeem` or the production L library as the expected value |
| WI-35 | AC23, AC25, AC33, AC55, AC60, AC64, AC67 | Limitation asserted, or gap recorded | A fabricated pass or a repair |
| WI-36 | AC47, AC63, AC64 | Seed, runs 16, depth 8, success count, failing sequence | An all-revert campaign, or a `foundry.toml` edit to inflate runs |
| WI-37 | Section 11 commands, AC65 | Build before test. Fork under the fork profile and the shared pin. Missing archive is blocked | A receipt check called parity, or a skip called pass |

## 8. Callback sequences and inventory

Roles are concrete. Payer is `msg.sender` of deposit. Share recipient may differ. Share owner is `msg.sender` of withdraw and of `transferShares`. Treasury is the stored address at each `take`. Hook is the pool key's hook, not Weir.

Deposit, unpaused, future deadline, nonzero recipient:

1. Pause modifier, then reentrancy, then deadline.
2. Reject zero recipient. Auto-create if absent. That create reads slot0 and does not call a hook.
3. Check msg.value against native legs only. Pull currency0, then currency1, from the payer. Zero and native pulls skip ERC20.
4. `poolManager.unlock` encodes `DEPOSIT`, id, and `(params, payer)`.
5. Manager calls `unlockCallback`. Any other caller has already failed `NotPoolManager`.
6. Callback compounds first with `params.hookData`, then deposits.
7. Zap, if requested, may swap once with the same hookData. Then slot0 is read again. Liquidity is sized. `modifyLiquidity` uses stored ticks, positive `int256` liquidity, salt zero, same hookData.
8. First return is added to the zap nets. Used amount is the negative part. `_settle` pays a negative net from Weir's pulled funds and takes a positive net to the payer, not the recipient.
9. Callback returns `(shares, used0, used1)`.
10. Outer check rejects `shares < minShares` or `shares == 0` with `Slippage`.
11. Credit only the recipient. Refund `declared - used` to the payer. Emit `Deposited` with user equal to the recipient.

Withdraw:

1. Reentrancy, then deadline. No pause check.
2. Body order: zapTo, recipient, exists, nonzero shares, then checked debit of the caller.
3. Unlock. Callback compounds, then withdraws.
4. Floors use post-compound state. Idle is paid into the manager before a zap. Zap 1 sells positive currency1. Zap 2 sells positive currency0. Zap 0 does not swap. A zero amount does not swap.
5. Settle both final nets to the recipient. Return only the positive parts.
6. Outer minima run after settlement. Emit `Withdrawn` with user equal to the caller.

Compound:

1. Exists check, then unlock. No pause check. Anyone may call.
2. Write `uint64(block.timestamp)` before the zero-liquidity return.
3. Nonzero liquidity pokes with delta 0 and the supplied hookData. Gross fees are the positive first-return components, cast through `uint128`.
4. Cut currency0, then currency1, by `take` to the treasury address read at that call. A native treasury callback can change storage before the second take. AC57 locks that order.
5. Reinvest only if cushioned inventory is positive and computed liquidity is positive. The second modify is skipped when liquidity is 0. That skip is conditional, not a missing hook.
6. Idle is the source cast of `int256(old)+net`. Settle nets to `address(this)`.
7. Emit `Compounded` only when a harvested positive component is nonzero. Idle-only adds do not emit.

`createVault` has no hook callback. Initialization is setup and may call initialize hooks. Zero-liquidity compound has no poke. Zero reinvestment has no add hook. Zero zap input has no swap hook.

AC51 is a same-transaction ordering case. `sync` is external and has no unlock guard. Native `_pay` calls `settle{value: amount}` without clearing a synced ERC20. `_settle` reverts `NonzeroNativeValue` when msg.value is positive and the synced currency is non-native. A router that synced, called Weir, and caught the revert keeps its sync. A sync inside the reverting Weir subtree does not survive that subtree. Uncaught propagation reverts the transaction. This is not a cross-transaction denial-of-service proof and not a reason to add `sync(0)`.

AC58's nested unlock is different. If the router already owns the unlock, Weir's `poolManager.unlock` reverts `AlreadyUnlocked` before Weir native-pays. A caught `AlreadyUnlocked` leaves the router unlock open. The manager relocks only when the router returns and the nonzero-delta count is zero.

Hook settlement is real. `modifyLiquidity` accounts `callerDelta` to Weir and a nonzero hook delta to the hook. The hook must settle its own debt inside the callback, while the manager is unlocked. Weir's source settlement is not changed to cover hook debt. If Weir's own component stays negative, the manager's unlock exit reverts `CurrencyNotSettled`.

### Inventory after a closed unlock

Ordinary domain only: exact-transfer, non-rebasing tokens, no return-delta that wraps idle, and only after a successful deposit, withdraw, or compound has returned and the manager is locked again.

For each physical currency `c`:

`balance(weir, c) = sum of recorded idle claims denominated in c + ghost unassigned(c)`

Unassigned includes direct donations, treasury cuts delivered to Weir, and withdrawal proceeds delivered to Weir. Those are not idle and not new shares. Shares held by Weir are assigned and belong in the share sum, not in unassigned. Position principal sits in the manager and is not part of this balance. Manager deltas for that unlock are zero.

Assigned-share sum equals `T - 1000` after genesis and 0 before it. Do not look for a zero-address balance. Do not assert `idle <= 2`, zero unwanted output, nonnegative cast safety, or NAV fairness. AC67 is outside this equality. Shared-currency tests reconcile each currency across all vaults, not per vault.

## 9. Rollback

Before every failing-call test, read the affected slots and balances, start log recording, and take `vm.snapshotState()`. Subscribe `expectEmit` before a call that is expected to succeed. Do not sleep, poll, or wait on time. Warp with `vm.warp` when the timestamp is the input.

Boundaries:

- Uncaught Weir revert: the call subtree loses vault creation, share and idle writes, timestamp, pulls, refunds, treasury cuts, position changes, and hook effects. Proof is the post-call state matching the pre-call reads. A debug log buffer captured during the reverted call is not a receipt.
- Caught by an outer router: earlier and later successful router effects remain. The Weir subtree matches its own pre-call reads. A caught reentrant rejection does not by itself undo a successful outer Weir call that already finished.
- Minima and `Slippage` happen after external settlement. The test must show those effects still disappear when the outer call reverts. Do not reorder the source to make the test easier.
- Do not snapshot only the whole transaction when the AC asks for a caught inner boundary, and do not do the reverse.

## 10. Fork parity

Supplied reference, also matched by constants read in `ROBINHOOD_MAIN.sol` for the manager and the pin:

- Chain 4663.
- Reference Weir `0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110`. This address was not found in the portion of `ROBINHOOD_MAIN.sol` read here. Keep it as a test-local literal cited to the PRD. Do not edit `ROBINHOOD_MAIN.sol`.
- Manager `0x8366a39CC670B4001A1121B8F6A443A643e40951`.
- Block `76_197_114`, hash `0x07be1214c2742ebcea7a61d8065020e88c4b66b5fc96a753ff022a00aa2c8c1d`, time `2026-09-30T03:33:23Z`.
- Deploy tx `0xa92ae44ce73b159a3aa3d6c8e2920b4c4771d784a253313a35d2fd9c4fad351a`.
- Owner and treasury `0x3234DEA52cc05cba7830B5305151C50AD34e9018`.
- Direct creation, not a factory. Supplied receipt evidence. This original did not refetch it.

Aliases read from root `foundry.toml`: `robinhood_mainnet`, `robinhood_mainnet_public`, and `robinhood_mainnet_alchemy`. The first two are the same public URL. The Alchemy alias interpolates `${ALCHEMY_KEY}`. Do not add `WEIR_RPC_URL`. Do not hardcode an endpoint. Do not use the testnet alias.

Recipe:

1. Finish hermetic artifact jobs.
2. `FOUNDRY_PROFILE=fork forge build`, then the fork test command in section 11.
3. `vm.createSelectFork(vm.rpcUrl("robinhood_mainnet_alchemy"), ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK)`.
4. Preflight: chain id 4663, block number equals the shared pin, block hash equals the supplied hash, reference Weir code nonempty, manager code nonempty, manager address equals the constant. Any failure reverts `ForkPreflightBlocked(reason)`. No `vm.skip`. No `assertTrue(true)`. A public-alias receipt is not a substitute.
5. Deploy two fresh exact-transfer peripherals on the fork, sort them, and initialize a hookless pool on the reference manager. The selected id must be absent from reference `vault(id).exists`.
6. Deploy the copy with that same manager, a test owner, and a test treasury. Align fee and pause with local `vm.prank` on the copy owner. Do not impersonate a production key to send a live transaction. Local `vm.prank` of the reference owner is allowed only if a parity action needs an owner-only reference call, and it still writes nothing to the real network.
7. `snapshotState` after both contracts and the fresh pool exist, before the action.
8. Run the action on the reference. Record returns, reverts, events, and mapped balances. `revertToState`. Run the same action on the copy. Compare selected-pool deltas under an explicit map: reference Weir to copy Weir, same payer, recipient, and pool key. Do not compare `allVaults` prefixes or unrelated positions.
9. If reference role state blocks an equivalent setup, record that action as blocked. Do not inject code or storage. Do not use a production private key.

Missing key or pruned history is NOT RUN/BLOCKED. This original does not claim the fork passed.

## 11. Commands and separated gates

Future commands, from the repository root. Not run in this original. Settings are the observed default: solc `0.8.35`, optimizer on, `optimizer_runs = 1`, `via_ir = false`, `cache_path = 'cache_forge'`, `out = 'out'`.

Focused build before focused tests, after domain edits:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/protocols/strategy/weir/WeirVaults.sol \
  contracts/protocols/strategy/weir/base/WeirBase.sol \
  contracts/protocols/strategy/weir/libraries/LiquidityAmounts.sol \
  --test-root test/foundry/spec/protocols/strategy/weir
```

Broader hermetic gates, only after that writer exits, and not overlapped:

```bash
forge build
forge test --match-path 'test/foundry/spec/protocols/strategy/weir/**' -vvv
forge test
```

Fork, only after the default-profile writer is idle:

```bash
FOUNDRY_PROFILE=fork forge build
FOUNDRY_PROFILE=fork forge test \
  --match-path 'test/foundry/fork/protocols/strategy/weir/**' -vvv
```

`[profile.default.fmt] skip = ["lib/"]` was read. The brief calls the existing fmt warning unrelated. Do not edit that config.

Gate meanings:

- Compiler success: the default build exits 0. It does not reproduce upstream 0.8.26, optimizer 800, viaIR bytecode.
- Hermetic proof: the spec suite exits 0 with exact integers. A gap row is a written gap, not a passing assertion.
- Fork parity: only a green fork-profile run after preflight. Otherwise blocked.
- Security characterization: AC55, AC60, AC64, and AC67 describe behavior. They are not a safety clearance.
- Release clearance: AC04, AC66, and AC69. GPL and AGPL are open-source. BUSL production use stays unresolved. No automatic legal clearance.

Fuzz and invariant settings stay at the observed `runs = 16` and `depth = 8`. Handlers must hit their dimensions inside that budget. Do not change `foundry.toml` to buy coverage.

## 12. Limits and risks

- This original did not compile, test, hash, call RPC, or read the other members.
- F0 liquidity, F0 redemption amounts, AC39 truncation, and AC42-AC43 integers were recomputed from TickMath constants and the PRD formulas. They are not test results. F1 and F2 remain conditional on `Pool.donate`.
- A canonical mismatch outside the 22 rewrites, the added `PoolOperation` import, and the five qualifications stops the work. It does not authorize a Weir behavior edit or a canonical edit.
- Unavailable upstream suite and audit stay unavailable. Do not backfill from memory.
- Unreachable adversarial branches stay gaps. AC23, AC41 wrap, AC60, and AC67 are the named gap points.
- License and archive inputs can block release or parity without blocking a faithful hermetic import. They cannot be waived.
- Do not silently expand product behavior. Do not weaken a failing test. Do not pin PRD prose with a test. Machine ABI and allowlist diffs are legitimate fidelity gates.
- Preservation traps the tests must lock, not fix: idle dilution, deposit swap fees staying with the payer, first return rather than informational fees, unassigned genesis shares, shared-currency custody, per-harvest fee flooring, partial zap fills, preview not equaling execution, native pay without `sync(0)`, unguarded create and transfer, and comments that overclaim economic safety.

Stop. This is the complete Grok original.
