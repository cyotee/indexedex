# WeirVaults source-import implementation and testing plan

Revision: `weir-import-plan-draft-r1`
Path: `docs/research/weir-source-import-plan-20261029-01a18660/coordinator/draft.md`
Status: frozen coordinator draft for one advisory pass. Not implementation authorization. Not a replacement PRD.

This draft synthesizes four independent originals. The coordinator is not a fifth vote. Agreement, a coordinator decision, and an unverified gate are labeled separately. Member dissent that was not adopted is in section 2.

## 0. Identity and authority

Council: `weir-source-import-plan-20261029-01a18660`.
Coordinator: invoking session `01a18660-756f-7c57-b112-de7a5348283c`.
Future publication target: `contracts/protocols/strategy/weir/WEIR_VAULT_SOURCE_IMPORT_IMPLEMENTATION_AND_TEST_PLAN.md`. This draft is not that file.

Originals read completely before this draft:

| Member | Artifact | Characters | AC rows | WI mentions |
|---|---|---|---|---|
| Astra | `members/astra/response.md` | 75,770 | 69 | 37 |
| Grok | `members/grok/response.md` | 71,641 | 69 | 37 |
| Kimi | `members/kimi/response.md` | 57,773 | 69 | 37 |
| MiniMax | `members/minimax/response.md` | 64,123 | 69 | 37 |

Authority order for the future implementer:

1. Frozen owner-clarified PRD, revision `weir-import-prd-owner-clarifications-20261029`, at `docs/research/weir-source-import-plan-20261029-01a18660/inputs/PRD.md`. Coordinator-supplied SHA-256 `c9316907a22d3ea0c2568aed74053a8911812fc1a6c424d162cb805e3ab4a551`, 96,598 characters. Supplied identity. This draft did not re-hash it. All 37 WI requirements and all 69 AC rows stay. This plan adds none and drops none.
2. Frozen domain sources, not a paraphrase: `docs/research/weir-source-import-prd-20261029-01a18660/source-snapshot/sources/src/WeirVaults.sol.txt`, `src/base/WeirBase.sol.txt`, `src/libraries/LiquidityAmounts.sol.txt`.
3. Root profile, artifact, and cache law in `CLAUDE.md` and `docs/testing/ARTIFACT_BUILDS.md`, plus the owner baseline-scope override.
4. Canonical Crane files only after the WP-00 compatibility gate. A behavior-changing mismatch stops the import. It is not a silent Weir edit and not a silent canonical edit.

Evidence classes used here:

- Source observation: read in this coordinator pass from a named current file or the frozen domain text.
- Member source observation: reported by one or more originals from their own reads. Adopted where the originals agree and this pass did not contradict it. The implementer re-reads the frozen function before encoding a test.
- Supplied evidence: PRD or brief statement not re-executed here.
- Coordinator decision: a choice among real alternatives. Advisory may object. It is not a member vote.
- Unverified gate: a future proof. Absence of a run is not a pass.

### Scope

Copy the three domain files to the owner path. Apply the 22 import rewrites below, the one added `PoolOperation` import, and the five free-struct qualifications. Compile at the observed default settings: solc `0.8.35`, optimizer on, `optimizer_runs = 1`, `via_ir = false`. Prove the copy with a real canonical `PoolManager` and an honest fork gate.

### Exclusions

No ERC-20 or ERC-4626 wrapping, Rate Provider, NAV issuance, Standard Exchange, Diamond, or registry wiring. No hook-only already-unlocked path, genesis-share removal, fee removal, inbound balance-delta repair, native `sync(0)`, extra reentrancy guard, exact-ratio zap, strict single-token exit, viaIR, new Foundry profile, `FOUNDRY_TEST` change, cache deletion, production factory deployment of Weir, license scrub, or economic repair.

A failing test is fixed by fixing the import or by recording an unreachable branch. It is not fixed by weakening the assertion or by changing business logic.

Generic skill examples this plan does not follow: a private dependency tree under `contracts/external/weir/`, a Service or Aware or DFPkg wrapper, fork layout that requires `ETH_RPC_URL`, `preview == execute` as a universal gate, `IndexedexTest` parentage, facet or package declaration tests, ERC-20 `name`/`symbol`/`decimals` policy tests, and registry deployment. The PRD selects `CraneTest` directly. V3 FullSpread is a different family and is not a template. Do not restore deleted legacy V4 Standard Exchange or V4 FullSpread families.

### Unverified gates

| Gate | Status in this draft | What closes it |
|---|---|---|
| Frozen hashes, Sourcify match, deployment receipt, public-RPC historical-state failure | Supplied evidence | Not re-executed here. Do not treat a receipt as archive parity. |
| Six OZ v5 files byte-identical; SafeERC20 used-path match | Supplied evidence | WP-00 re-hashes and diffs used paths. A mismatch stops acceptance. |
| FullMath revert bytes, position-key preimage, Currency transfer wrapper, Pool.donate fee growth | Unverified | WP-00 reads the bodies and names the actual error envelope. Do not guess selectors. |
| solc 0.8.35 / runs 1 / viaIR false compilation | Unverified | WP-02 build exit 0, or the exact diagnostic is the recorded blocker. |
| Generated ABI, storage layout, resolved import graph | Unverified | WP-02 machine comparison. |
| Hermetic money-path proof | Unverified | WP-04 through WP-07. |
| Chain 4663 archive parity | Blocked-archive | No `ALCHEMY_KEY` in this process. AC65 is NOT RUN until an archive alias works. Never a skip, never a substituted chain. |
| Upstream Git pin, upstream tests, upstream audit | Absent | Do not invent them. Do not claim an upstream suite ran. |
| BUSL production clearance | Blocked-release | June 15, 2027 is a latest calendar date, not an expiry proof. No legal clearance sentence. |

## 1. Source observations that bind the plan

Read in this coordinator pass:

- `PoolManager` constructor is `constructor(address initialOwner)`.
- `initialize` rejects `tickSpacing < MIN_TICK_SPACING` and `CurrenciesOutOfOrderOrEqual` when currency0 is not strictly less than currency1. It calls `key.fee.getInitialLPFee()`.
- `LPFeeLibrary.isValid` is `self <= MAX_LP_FEE` (`1000000`). Fee 0 is a valid static fee. `DYNAMIC_FEE_FLAG` is `0x800000`, not 0. F0 may use fee 0. If `initialize` still reverts for a hookless fee-0 key, stop and report. Do not pick another fee and keep calling the fixture F0.
- `PoolOperation.sol` free structs, field order: `ModifyLiquidityParams` is `tickLower`, `tickUpper`, `liquidityDelta`, `salt`. `SwapParams` is `zeroForOne`, `amountSpecified`, `sqrtPriceLimitX96`.
- Frozen W uses `IPoolManager.ModifyLiquidityParams` at lines 264, 292, 323, and 349, and `IPoolManager.SwapParams({ zeroForOne, amountSpecified: -int256(amountIn), sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1 })` at line 397. Those five qualifications become the free names. Named swap fields stay. Do not switch the swap to positional encoding.
- Hook permission constants in `libraries/Hooks.sol`: before/after add are `1 << 11` and `1 << 10`; before/after remove `1 << 9` and `1 << 8`; before/after swap `1 << 7` and `1 << 6`; after-add and after-remove return-delta `1 << 1` and `1 << 0`. A return-delta bit without its base permission fails `isValidHookAddress`. Tests use the `Hooks.*_FLAG` constants, not copied shifts, except when an assertion must show the mined address bits.
- `HookMiner` at `lib/crane/contracts/protocols/dexes/uniswap/v4/hooks/public/utils/HookMiner.sol` is MIT and exposes salt search. The path `.../v4-core/test/utils/HookMiner.sol` does not exist. `lib/crane/contracts/protocols/dexes/uniswap/v4/utils/HookMiner.sol` also exists; the public utils file is the selected miner because its header was read.
- `CraneTest.setUp` calls `InitDevService.initEnv` and populates `create3Factory`. Hermetic tests call it and then do not use the factory to deploy Weir.
- Current supported tests construct `new PoolManager(address(this))`, including `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol`. Product bases such as orbital, Wings SE, and the multi-pool TWAP base deploy the same constructor arguments through `create3Factory.create3WithArgs` and `ArtifactCreationCode`. Both are real managers. Section 2 selects one.
- Root `foundry.toml`: default and fork profiles share `out` and `cache_forge`; both use solc `0.8.35`, optimizer runs 1, `via_ir = false`. Default fuzz `runs = 16`. Invariant `runs = 16`, `depth = 8`. Fork `test = 'test/foundry/fork'`. `[profile.default.fmt] skip = ["lib/"]` is unrelated. Do not edit it.
- RPC aliases present: `robinhood_mainnet`, `robinhood_mainnet_public` (same public URL), `robinhood_mainnet_alchemy` (`${ALCHEMY_KEY}`). No `WEIR_RPC_URL`.
- `ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK` is the shared pin. The reference Weir address is a test-local literal from the PRD. Do not edit `ROBINHOOD_MAIN.sol`.
- `docs/testing/ARTIFACT_BUILDS.md` requires `scripts/forge-artifacts.py` build-before-test, one writer at a time, no cache deletion, no package profile.

Member source observations adopted only where the originals agree, and still re-read by the implementer before encoding:

- Deposit modifier order is pause, then reentrancy, then deadline. Body rejects a zero recipient before auto-create, checks `msg.value` against native legs, pulls currency0 then currency1, then unlocks. The callback compounds before the deposit action.
- Withdraw has no pause check. Body order is zap, recipient, exists, nonzero shares, then checked debit of the caller. Minima run after settlement.
- Compound writes `uint64(block.timestamp)` before the zero-liquidity return. Gross fees are the positive components of the first `modifyLiquidity` return, not the informational second return. Cuts are taken in currency order. A native treasury callback can change the stored treasury before the second take.
- `createVault` reads slot0 and does not call a pool hook. Zero liquidity skips the poke. Zero computed reinvestment skips the add. A zero zap input skips the swap.
- Genesis keeps 1000 shares with no holder. Later shares are `floor(newL * postCompoundT / postCompoundL)`. Idle is not in that denominator.
- Idle update is the source cast of `int256(oldIdle) + net` into `uint256`. A negative sum wraps. It is not a `SafeCast` revert.
- Direct donations, self-treasury cuts, and self-recipient withdrawal proceeds are physical receipts. They are not idle and not new shares unless the source books them.

## 2. Coordinator decisions and what was not adopted

### Selected

1. Hermetic manager route is `poolManager = new PoolManager(address(this))` after `CraneTest.setUp()`, inside proposed `TestBase_WeirVaults`. Weir is `new WeirVaults(poolManager, treasury, owner)`. No mock, no etch, no storage injection, no `vm.mockCall` of either.
2. Do not inherit orbital, Wings, TWAP, Pons, dual, or weighted TestBases. They confirm routes. They also pull product wiring this import does not have.
3. CREATE3 via `ArtifactCreationCode` is a verified alternative and is not selected. Direct construction binds the test to the canonical source the compiler imports. CREATE3 loads creation bytecode from `out/` and can run a stale artifact. The brief allows a minimal real-port deployment. Weir itself is not factory-deployed.
4. External liquidity, donations, swaps, stale sync, nested unlock, and caught calls go through two owned `IUnlockCallback` peripherals: `WeirPoolRouter` and `WeirCallRouter`. Do not import `PoolSwapTest`, `PoolModifyLiquidityTest`, `CurrencySettler`, or `Deployers` from the v4-core test tree, and do not copy those files into the Weir tree.
5. Ordinary tokens reuse `contracts/test/stubs/SimpleMintableERC20.sol`. A local token exists only for false return, empty return, explicit revert, short delivery, and token callbacks.
6. Hooks are two peripherals, mined with the selected `HookMiner` and deployed by the test contract. `WeirObserveHook` records calls and hookData. `WeirReturnDeltaHook` is a separate contract with return-delta permissions and settles its own hook debt. No etch. No donate or initialize permission unless that test needs it.
7. One human provenance file, `VENDOR.md`. One human release ledger, `IMPORT_EVIDENCE.md`. Machine fidelity lives in `evidence/*.json` plus `test/tools/check_fidelity.py`. Do not also create `VERIFICATION.md`, `RELEASE_EVIDENCE.md`, and a second transform markdown.
8. Expectations come from `WeirMathOracle`, a test-only Solidity library that does not import Weir, the copied `LiquidityAmounts`, `previewRedeem`, `FullMath`, or `ConstProdUtils`. A Python wide-integer script writes committed fixtures. Forge tests do not shell out. If the script, the Solidity oracle, and canonical `FullMath` disagree, stop. That is a dependency or oracle defect, not a Weir edit.
9. Swap outputs are not taken from Weir and not from `x*y=k`. Until `swap-golden.json` exists from independent tick-step floors, AC15 swap subcases, AC16, AC24, AC25, and AC37 are not passable. Do not stub them.
10. Fuzz and invariant budgets stay at the observed 16 runs and depth 8. Do not edit `foundry.toml` to buy coverage. Handlers must hit their dimensions inside that budget. A campaign of only rejected calls fails the package.
11. Fork execution uses `FOUNDRY_PROFILE=fork`, `vm.rpcUrl("robinhood_mainnet_alchemy")`, and `ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK`. Missing key or pruned history reverts `ForkPreflightBlocked`. No `vm.skip`. No `assertTrue(true)`. Public-alias receipt checks are not parity.
12. Artifact writers are serialized. Never run two `forge build`, `forge test`, or `scripts/forge-artifacts.py` processes against the shared `out`/`cache_forge` pair. Never delete those directories. Never pass `--via-ir`. Never set `FOUNDRY_TEST`.

### Not adopted, and why

| Proposal | From | Disposition |
|---|---|---|
| Deploy the manager through CREATE3 and `ArtifactCreationCode` | MiniMax; Astra's orbital citation | Not selected. The route is real. Direct construction is the fidelity choice. Advisory may show a concrete reason this fails `CraneTest` law; none was found in the brief or in the current `new PoolManager` tests. |
| Reuse `PoolSwapTest` / `PoolModifyLiquidityTest` | Kimi | Not selected. Donate, open sync, and caught nested unlock are outside those routers. MiniMax correctly warned against copying upstream test helpers. Owned routers keep one settlement implementation. |
| `v4-core/test/utils/HookMiner.sol` | Kimi | Path does not exist. Use the public utils miner. |
| Three overlapping release markdown files | Grok, Kimi, MiniMax, each naming a different ledger | Collapsed to `VENDOR.md` plus `IMPORT_EVIDENCE.md`. Machine JSON keeps the allowlist out of prose tests. |
| Fork base that inherits hermetic `setUp` and then forks | Risk in any "parent first, then fork" recipe | Not selected. `createSelectFork` replaces chain state and would wipe factories and a locally deployed manager. Fork setup forks first, then calls `CraneTest.setUp()`, then binds the reference manager. It does not deploy a second manager. |
| A Forge test that goes green when the build failed | Avoided by all four, restated here | AC03 is the build command. A failed build is a blocker, not a skipped test. |
| Pinning PRD prose or the plan text with a unit test | Forbidden by the brief | `check_fidelity.py` compares source tokens, ABI JSON, and allowlisted hunks only. |

## 3. File inventory

Proposed paths do not exist because this plan names them. Existing paths were read or were identified by the PRD and are not copied into a private tree.

### Production and provenance

| Path | Status | Owner |
|---|---|---|
| `contracts/protocols/strategy/weir/WeirVaults.sol` | Proposed | WP-01, WP-02 |
| `contracts/protocols/strategy/weir/base/WeirBase.sol` | Proposed | WP-01, WP-02 |
| `contracts/protocols/strategy/weir/libraries/LiquidityAmounts.sol` | Proposed copy of the frozen GPL library, not the canonical namesake | WP-01, WP-02 |
| `contracts/protocols/strategy/weir/VENDOR.md` | Proposed | WP-00 notes land here in the same change as the copy; WP-09 completes the release section |
| `contracts/protocols/strategy/weir/IMPORT_EVIDENCE.md` | Proposed | WP-09 only |
| `contracts/protocols/strategy/weir/evidence/import-transform.json` | Proposed machine allowlist | WP-01, WP-02 |
| `contracts/protocols/strategy/weir/evidence/dependency-compatibility.json` | Proposed | WP-00 result, written with the copy |
| `contracts/protocols/strategy/weir/evidence/abi-baseline.json` | Proposed verbatim ABI array from the frozen manifest, not hand-rewritten | WP-01 |
| `contracts/protocols/strategy/weir/evidence/acceptance-results.json` | Proposed command ledger | WP-09 |

No second domain tree. Frozen `.sol.txt` files stay research references and are not compiled. No `IWeirVaults`, Service, AwareRepo, facet, or DFPkg.

### Import allowlist

The 22 rows are the PRD allowlist. Two relative Weir imports stay textually unchanged. Do not convert them to Crane aliases.

| File | Frozen specifier | Selected specifier |
|---|---|---|
| W | `@openzeppelin/contracts/access/Ownable2Step.sol` | `@crane/contracts/external/openzeppelin-contracts-v5/access/Ownable2Step.sol` |
| W | `@openzeppelin/contracts/utils/Pausable.sol` | `@crane/contracts/external/openzeppelin-contracts-v5/utils/Pausable.sol` |
| W | `@openzeppelin/contracts/utils/ReentrancyGuard.sol` | `@crane/contracts/external/openzeppelin-contracts-v5/utils/ReentrancyGuard.sol` |
| W | `v4-core/src/interfaces/IPoolManager.sol` | `@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol` |
| W | `v4-core/src/libraries/StateLibrary.sol` | `@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol` |
| W | `v4-core/src/libraries/TickMath.sol` | `@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol` |
| W | `v4-core/src/libraries/FullMath.sol` | `@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol` |
| W | `v4-core/src/libraries/FixedPoint96.sol` | `@crane/contracts/protocols/dexes/uniswap/libraries/FixedPoint96.sol` |
| W | `v4-core/src/libraries/FixedPoint128.sol` | `@crane/contracts/protocols/dexes/uniswap/libraries/FixedPoint128.sol` |
| W | `v4-core/src/types/PoolKey.sol` | `@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol` |
| W | `v4-core/src/types/PoolId.sol` | `@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol` |
| W | `v4-core/src/types/Currency.sol` | `@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol` |
| W | `v4-core/src/types/BalanceDelta.sol` | `@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol` |
| W | `./base/WeirBase.sol` | `./base/WeirBase.sol` |
| W | `./libraries/LiquidityAmounts.sol` | `./libraries/LiquidityAmounts.sol` |
| B | `@openzeppelin/contracts/token/ERC20/IERC20.sol` | `@crane/contracts/external/openzeppelin-contracts-v5/token/ERC20/IERC20.sol` |
| B | `@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol` | `@crane/contracts/external/openzeppelin-contracts-v5/token/ERC20/utils/SafeERC20.sol` |
| B | `v4-core/src/interfaces/IPoolManager.sol` | `@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol` |
| B | `v4-core/src/interfaces/callback/IUnlockCallback.sol` | `@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol` |
| B | `v4-core/src/types/Currency.sol` | `@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol` |
| L | `v4-core/src/libraries/FullMath.sol` | `@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol` |
| L | `v4-core/src/libraries/FixedPoint96.sol` | `@crane/contracts/protocols/dexes/uniswap/libraries/FixedPoint96.sol` |

Additional import, not one of the 22: `{ModifyLiquidityParams, SwapParams}` from `@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol`. Five qualifications, nothing else. Do not edit `IPoolManager` to nest the structs. Do not invent a `PoolOperation` library namespace.

`import-transform.json` records those 22 rows, the added import, the five qualifications with frozen line numbers, original and adjusted SHA-256 for each domain file, and every WI-06 hunk with its compiler diagnostic. `check_fidelity.py` fails if the production diff contains any other token change. Comments and notices stay.

### Test infrastructure

Owner directory: `contracts/protocols/strategy/weir/test/`.

| Proposed path | Role |
|---|---|
| `bases/TestBase_WeirVaults.sol` | Hermetic setup. Inherits `CraneTest` only. Does not inherit `IndexedexTest` or a product TestBase |
| `bases/TestBase_WeirVaultsRobinhoodFork.sol` | Fork-first setup. Does not inherit the hermetic manager deployment |
| `behaviors/Behavior_WeirVaults.sol` | Exact ledger, event, error, and inventory assertions. Not an `IFacet` behavior |
| `observers/WeirObserver.sol` | Read-only snapshots. No state injection |
| `oracles/WeirMathOracle.sol` | Independent integer oracle. No Weir import |
| `oracles/weir_oracle.py` | Test-only wide-integer fixture generator. Not a production simulator and not called by Forge |
| `oracles/fixtures/arithmetic-vectors.json` | Committed F0-F3, library, cast, and rounding vectors |
| `oracles/fixtures/swap-golden.json` | Committed tick-traversal vectors. Provenance in the JSON, not in prose |
| `tools/check_fidelity.py` | Allowlist and ABI comparison. Stdlib only. No prose pin |
| `peripherals/WeirPoolRouter.sol` | Donate, external liquidity, exact-input swap. Settles its own debts |
| `peripherals/WeirCallRouter.sol` | Open sync, nested unlock, caught and bubbling Weir calls |
| `peripherals/WeirHostileToken.sol` | False, empty return, explicit revert, short delivery, callback mode |
| `peripherals/WeirCallbackActor.sol` | Payer, treasury, recipient, or token that calls back into Weir |
| `peripherals/WeirRejectReceiver.sol` | Rejects native with known revert bytes |
| `peripherals/WeirObserveHook.sol` | Recording hook |
| `peripherals/WeirReturnDeltaHook.sol` | Return-delta hook that settles its own debt |
| `peripherals/WeirLiquidityAmountsExposure.sol` | Exposes the copied library. Not a vault |
| `handlers/Handler_WeirVaults.sol` | Supported-domain handler |
| `handlers/Handler_WeirVaultsHostile.sol` | Separate hostile campaign |

### Spec and fork tests

| Proposed file | Contract | Primary ACs |
|---|---|---|
| `test/foundry/spec/protocols/strategy/weir/WeirVaults_Provenance.t.sol` | `WeirVaults_ProvenanceTest` | AC02, AC68, AC69 record. AC01 and AC03 are commands, not green skips |
| `test/foundry/spec/protocols/strategy/weir/WeirVaults_Surface.t.sol` | `WeirVaults_SurfaceTest` | AC05-AC08, AC62 |
| `test/foundry/spec/protocols/strategy/weir/WeirVaults_Deposit.t.sol` | `WeirVaults_DepositTest` | AC09-AC20, AC36, AC48-AC49 where the deposit file owns the fixture |
| `test/foundry/spec/protocols/strategy/weir/WeirVaults_Withdraw.t.sol` | `WeirVaults_WithdrawTest` | AC21-AC27, AC37 |
| `test/foundry/spec/protocols/strategy/weir/WeirVaults_CompoundInventory.t.sol` | `WeirVaults_CompoundInventoryTest` | AC28-AC36 |
| `test/foundry/spec/protocols/strategy/weir/WeirVaults_ViewsMath.t.sol` | `WeirVaults_ViewsMathTest` | AC38-AC47 |
| `test/foundry/spec/protocols/strategy/weir/WeirVaults_NativeAccess.t.sol` | `WeirVaults_NativeAccessTest` | AC48-AC53, AC62 if not already closed |
| `test/foundry/spec/protocols/strategy/weir/WeirVaults_CallbackHook.t.sol` | `WeirVaults_CallbackHookTest` | AC54-AC61, AC67 |
| `test/foundry/spec/protocols/strategy/weir/WeirVaults_Invariant.t.sol` | `WeirVaults_InvariantTest` | AC63 |
| `test/foundry/spec/protocols/strategy/weir/WeirVaults_Hostile.t.sol` | `WeirVaults_HostileTest` | AC64 |
| `test/foundry/fork/protocols/strategy/weir/WeirVaults_ForkParity.t.sol` | `WeirVaults_ForkParityTest` | AC65 |

AC04 and AC66 are static release records. They are not Forge tests that can go green by skipping.

### Existing files used, not copied

| Existing path | Use |
|---|---|
| `lib/crane/contracts/test/CraneTest.sol` | Parent setup |
| `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol` | The only manager |
| `lib/crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol` | Free struct import |
| `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol` | Position and slot0 reads |
| `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol` | Extrema and usable ticks |
| `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol` | Flag constants and address validity |
| `lib/crane/contracts/protocols/dexes/uniswap/v4/hooks/public/utils/HookMiner.sol` | Salt search |
| `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol` | Manager errors |
| `contracts/test/stubs/SimpleMintableERC20.sol` | Ordinary exact-transfer token |
| `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol` | Chain id, shared pin, manager constant |
| `lib/crane/lib/forge-std/src/Vm.sol` | `rpcUrl`, `createSelectFork`, `snapshotState`, `revertToState` |
| Root `foundry.toml` | Two profiles only |

Refused as setup parents: orbital, Wings, TWAP, Pons, dual, and weighted TestBases; v4-core `Deployers.sol`; `TestBase_UniswapV4EthereumMainnetFork`; deleted legacy V4 paths.

## 4. Work packages

### WP-00. Compatibility gate

Depends on nothing. Blocks WP-01 acceptance. No production Solidity edits. The written result is `dependency-compatibility.json`, committed in the same change as the copy.

Single owner. Reading may overlap WP-03 design. No parallel editor of the three domain files.

1. Confirm the 22 target files and `PoolOperation.sol` exist. Confirm the canonical `LiquidityAmounts` is not on the Weir import path.
2. Diff frozen nested `ModifyLiquidityParams` and `SwapParams` against `PoolOperation.sol` field order, types, and ABI encoding. Stop if encoding differs. This draft already observed matching field names and order; the implementer still records the diff.
3. Diff the used `StateLibrary` surface: pool slot, `getSlot0`, position info, fee growth inside, position-key preimage, signed tick encoding, and the hash helper. Matching a slot number is not enough. A later hermetic round-trip must show `getSlot0` nonzero after real `initialize`, and the position owner as Weir at salt zero after a real add.
4. Re-hash the six claimed byte-identical OZ files. Diff SafeERC20 `safeTransfer`, `safeTransferFrom`, and `_callOptionalReturn` only. Do not mix Context families. Do not upgrade to 5.6.1.
5. Read `Pool.donate` fee growth and protocol-fee skim. Fresh pools must report protocol fee 0. If a donate of 20 into sole liquidity does not accrue gross 20, stop and report a manager-math mismatch. Do not edit Weir so the test matches 20.
6. Read Currency transfer and `CustomRevert` wrapping enough to name the actual error envelope for AC50 and reverting hooks. Do not guess selectors.

Exit: a written pass or fail per surface. Any behavior-changing mismatch stops the import.

### WP-01. Domain copy

Depends on WP-00 pass. Single owner of the three Solidity files, `VENDOR.md`, and the evidence JSON files.

1. Copy frozen bodies. Keep SPDX, comments, storage order, inheritance order `WeirBase, Ownable2Step, Pausable, ReentrancyGuard`, constants, and function order.
2. Apply the 22 specifier rewrites. Leave the two relative imports unchanged.
3. Add the `PoolOperation` import and the five qualification edits. No other token edits.
4. `VENDOR.md` records frozen identifiers, all 39 transitive entries, metadata keccak256 and SHA-256 values from the manifest, the original-to-local map, both hash columns, the 22 rewrites, the added import, the five qualifications, compiler settings, license declarations, the deployment table, the chosen RPC alias, and the missing upstream Git, tests, and audit. Frozen-byte hashes and adjusted production hashes stay distinct.
5. `check_fidelity.py` must exit 0 against the allowlist. An unlisted hunk stops the work.

### WP-02. Compile, then ABI and layout

Depends on WP-01. Same single owner. Serialized artifact writer.

Allowed edits: the three domain files only if the compiler demands a WI-06 edit, plus the evidence record. No `foundry.toml` edit.

1. Seed a new worktree from warm `out/` and `cache_forge/` if the checkout is cold. Do not delete either.
2. Run the focused artifact command in section 11. Wait for process exit. A quiet solc is not a hang.
3. If the build succeeds, record that WI-06 was not used.
4. If it fails on stack depth, apply only lexical scopes or internal memory structs around existing temporaries. Preserve ABI, storage, inheritance, checked order, casts, calls, fees, events, errors, and notices. Record the diagnostic and the exact diff. Rebuild. Re-run `check_fidelity.py`.
5. Do not pre-apply WI-06. Do not enable viaIR. A behavior-changing diagnostic is a separate owner decision and is out of this plan.
6. Compare the compiled ABI with `abi-baseline.json`: 27 function entries, constructor, receive, 11 events, 18 listed errors, same tuples, indexing, and mutability. Canonicalize only `internalType` qualifications the manifest lists.
7. Record source declaration and inheritance storage order. The immutable manager is a constructor binding, not an extra persistent slot. Internal memory structs must not add storage variables.

Exit: build exit 0 under the observed default settings, or a recorded blocker. No money-path assertion is accepted before this exit.

After this exit, WP-04, WP-05, WP-06, and WP-08 may be authored in parallel on disjoint files. Only one of them may invoke the artifact writer at a time. Money-path assertions wait for WP-04 ABI identity.

### WP-03. Topology, routers, oracle, behavior

Depends on WP-00 for the manager choice. Design may proceed beside WP-01. No test execution before WP-02. Single owner of the TestBase, both routers, the observer, the behavior library, and `WeirMathOracle`. Other authors call this surface. They do not declare a second manager, a second Weir, or an oracle that calls `previewRedeem` or the production library.

Published surface:

- `setUp()` calls `CraneTest.setUp()` first, then deploys the manager and Weir if still zero.
- `initHookless(PoolKey key, uint160 sqrtP) returns (PoolId)`.
- `initObserveHookPool(...)` and `initReturnDeltaHookPool(...)`.
- `WeirPoolRouter.donate`, `addLiquidity`, and `swapExactIn`.
- `WeirCallRouter.syncThen`, `callWhileUnlocked`, and `callCaught`.
- `WeirMathOracle` pure functions in section 5. No Weir import.
- `Behavior_WeirVaults.assertClosedInventory`, `assertPosition`, `assertNoSubtreeEffects`.
- `snap()` wraps `vm.snapshotState`. `restore(uint256)` wraps `vm.revertToState`.

Exit: one compiling TestBase that deploys a real manager and a real Weir, with labels, and with no mock, etch, or storage write against either.

### WP-04. Surface, ABI, library

Depends on WP-02 and WP-03. Owner of provenance, surface, and the library exposure. Blocks acceptance of WP-05 assertions. Authoring may overlap.

Exit: AC02, AC05-AC08, AC42-AC45, and AC68 machine checks pass, or the failing check is a recorded compatibility stop. AC01 and AC03 are command records, not this exit. AC04 is not closed here.

### WP-05. Money paths

Depends on WP-04 ABI and storage identity. Owner of deposit, withdraw, compound, and views files.

Exit: F0-F3 and the non-callback money ACs match the independent oracle. A mismatch against the oracle fails. A mismatch against PRD prose where the oracle and the source agree is a PRD note, not a Weir edit. F1 gross-20 is accepted only if the real donate produces 20. Otherwise stop at the manager-math gate.

### WP-06. Native, access, callbacks, hostile

Depends on WP-03 routers and WP-05 fixtures. Owner of native, callback, and hostile files. May be authored earlier. Do not execute against a mock manager.

Exit: each reachable hostile case has an exact error or an exact balance trace. Unreachable cases have a written gap. No AC63 invariant is asserted inside this package.

### WP-07. Supported-domain invariants

Depends on WP-05 actions and the ghost rules in section 8. Owner of the invariant file and `Handler_WeirVaults`.

Exit: campaign log with seed, configured runs 16, depth 8, success count greater than zero, and the smallest failing sequence if any. A campaign of only rejected calls fails the package.

### WP-08. Fork parity

Depends on WP-02 compile of the copy, and on the hermetic artifact writer being idle. Owner of the fork base and fork file only.

Isolated `FOUNDRY_PROFILE=fork`. Do not overlap a default-profile build.

Exit: either a compared parity trace, or `ForkPreflightBlocked` classified NOT RUN/BLOCKED. Never a skip, never a substituted chain, never a pass.

### WP-09. Release record

Depends on WP-04 through WP-08 having an honest status, including blocked and gap statuses. Owner of `IMPORT_EVIDENCE.md` and the VENDOR release section. No production logic edits.

Exit: AC66 map filled with a file, a command, or an explicit unresolved gate for every WI and AC. No safety or legal clearance sentence.

Parallel summary: after WP-02, surface, money, callback, and fork-authoring tracks are disjoint files. Builds are not parallel. Fork execution is last among artifact jobs. WP-09 is last and does not rerun a green build just to touch prose.

## 5. Deployment and topology

`TestBase_WeirVaults.setUp`:

1. `CraneTest.setUp()`. Factories exist so the ladder is satisfied. They are not used to deploy Weir, the manager, tokens, hooks, or the routers. No registry call. No `indexedexManager`. No proxy.
2. `poolManager = new PoolManager(address(this))` if unset. `address(this)` is the protocol-fee owner. Do not set a protocol fee. Assert fresh pools report protocol fee 0.
3. `weir = new WeirVaults(poolManager, treasury, owner)` if unset. Nonzero treasury and owner for the happy fixture. AC05 deploys separate instances for the zero-address cases, including zero manager, which must be stored and not rejected.
4. Deploy three `SimpleMintableERC20` and sort every key. `currency0 < currency1` is required. Native is address zero, so it is currency0 when it is in the pair. Shared-currency pair is `(A,B)` and `(A,C)` with `A < B < C`.
5. `vm.label` every deployed address. Idempotent zero-address guards.

Pool creation is not `createVault`. The test calls `poolManager.initialize(key, sqrtP)` directly. For hookless keys the hook address is zero. F0 uses fee 0 and tick spacing 1. Fee 0 is a valid static fee. Spacing 1 is the intended full-range fixture. If `initialize` rejects that key, stop. Do not relabel a different fee as F0.

F0 price input is `TickMath.getSqrtPriceAtTick(0)`. The test asserts that return equals `FixedPoint96.Q96` once. If it does not, stop. Expected liquidity is computed by `WeirMathOracle` from the returned price, not by calling Weir.

`createVault` then reads slot0, stores `minUsableTick(spacing)` and `maxUsableTick(spacing)`, pushes `allVaults`, and emits `VaultCreated`. It does not call a pool hook. Position owner is the Weir address. Salt is `bytes32(0)`. Ticks are the stored full-range ticks. The payer and the share recipient must not be that position owner.

External liquidity and donations go through `WeirPoolRouter`, which is the unlock caller and the position owner for its own adds. It settles its own debts before returning. Direct transfers to Weir or to the manager are not donations.

Hooks are deployed by the test contract using a salt from `HookMiner.find`. The deployer argument is the address that actually executes `new`. After deploy, require `Hooks.isValidHookAddress`. Do not etch Weir, the manager, or the hook.

Observe-hook permissions: before and after add, remove, and swap. Return-delta mode also sets after-add and after-remove return-delta flags and keeps the matching after flags. Do not add donate or initialize permissions unless that test needs them.

No SUT inheritance. No `vm.mockCall` of Weir or the manager. No storage injection. No fabricated `BalanceDelta`.

### Oracle rules

`WeirMathOracle` implements full-width `MD(x,y,d) = floor(x*y/d)` with limb arithmetic, empty revert on `d = 0` or overflow, matching the PRD FullMath contract as a specification. If this oracle and canonical `FullMath` disagree on a vector, that is a dependency mismatch, not a Weir change.

Stage rules, from the PRD arithmetic section and the frozen library:

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
- Idle update: `uint256(int256(oldIdle) + net)`. Negative sums wrap to a large uint256.
- `int128`, `uint128`, and `int256` stay distinct. A positive `int128` fits `uint128`. Do not synthesize a fee above `2^128-1`.
- Timestamp store is `uint64(block.timestamp)`.

Deposit balancing, member source observation of `_balance`, to be re-read before encoding: `V = MD(MD(a0,P,Q),P,Q)`. If `V > a1`, sell `floor((a0 - MD(MD(a1,Q,P),Q,P)) / 2)` of currency0. If `a1 > V`, sell `floor((a1-V)/2)` of currency1. Otherwise no swap. A computed input of 0 returns before the swap. Sizing then uses signed returned deltas and the post-swap slot0. This is not an optimizer and not a constant-product oracle.

### Anchors

These are member-recomputed integers, not test results. They become assertions only after `WeirMathOracle` reproduces them and, where noted, the real manager delta agrees.

Using canonical `TickMath` constants: `MIN_SQRT_PRICE = 4295128739`, `Q = 2^96`, `K = 2^20 = 1048576`. Spacing 1 yields `MIN_TICK` and `MAX_TICK` because both divide evenly by 1. That last sentence is a member source observation and must be re-checked against `TickMath.minUsableTick`.

| Anchor | Value | Gate |
|---|---|---|
| F0 liquidity from `K` of each token at `P = Q`, full range | `L0 = L1 = K` | Oracle. Manager charge of `K` per side is the PRD claim. If the real add delta is not `K`, used and refund follow the real delta. Liquidity is checked separately |
| F0 recipient shares | `1047576` | Oracle, after the real liquidity is `K` |
| F0 refund | `2` each, if the manager charges `K` | Real add delta |
| F0 full assigned withdrawal, no fee, no zap | Removes `1047576` liquidity and returns `1047575` each. Residual `L = T = 1000`, idle 0 | Oracle amounts. Residual shares follow genesis |
| Liquidity 7 at that range | `6` each | Oracle. Supports the AC39 quote claim |
| AC42 `A=Q`, `B=2Q`, amount 3 | `L0=6`, `L1=3`; reverse at liquidity 7 is amount0 `3`, amount1 `7` | Oracle, not a call to the copied library |
| AC43 interior `(3,4)` at `P=Q`, bounds `Q/2` and `2Q` | `min(6,8)=6`; amounts for liquidity 7 are `(3,3)` | Oracle |
| AC39 `s = 2^128+7` at `L=T=K` | Checked product fits; `uint128` truncation of the quotient is 7 | Oracle |
| AC39 `s = 2^236` | Product is `2^256`, checked mul panics `0x11` | Oracle |
| F3, given idle0 19 and `L=T=K` | Second user receives `K` shares; claim `floor(19/2)=9` | Only if F1 actually leaves idle0 19 |

F1 gross 20 and F2 added liquidity 17 are supplied derivations. They become expected values only after a real donate and the independent fee formula agree.

## 6. AC01-AC69

Every row is one AC. Subcases are named methods, not a range of ACs. Primary assertion is the exact result. Every success also runs the closed-inventory check unless the row is static or is an intermediate callback observation. Every failure compares the reverting subtree to a pre-call snapshot. Reachability uses: Static, Executable, Conditional, Gap-if-unreachable, Blocked-archive, Blocked-release.

| AC | Test or gate | Construction | Primary assertion | WP | Reachability |
|---|---|---|---|---|---|
| AC01 | `check_fidelity.py` plus the allowlist diff | Three production files against frozen texts | No unlisted edit. Notices and comments remain. Both hash columns exist. WI-06 scopes, if any, do not change ABI or storage | WP-01, WP-02 | Static |
| AC02 | `WeirVaults_ProvenanceTest.test_AC02_abiEqualsManifest` | Compiled artifact ABI against `abi-baseline.json` | 27 functions, constructor, receive, 11 events, 18 listed errors, same tuples, indexing, and mutability | WP-04 | Executable after compile |
| AC03 | Focused build command | Default profile only | Exit 0, `via_ir=false`, or the exact diagnostic is the recorded blocker. No business-logic diff hidden in a green claim | WP-02 | Unverified until the build exits |
| AC04 | `VENDOR.md` license section | Inspect full declarations and the resolved graph | 39 frozen entries accounted. GPL and AGPL marked open-source. BUSL marked source-available. Change date recorded as 2027-06-15 or earlier ENS or anniversary condition. Old GPL versus new MIT ambiguity kept. No inferred expiry or grant | WP-09 | Blocked-release for clearance. The import may still complete |
| AC05 | `test_AC05_validDeploy`; `test_AC05_zeroTreasury`; `test_AC05_zeroOwner`; `test_AC05_zeroManager` | Four separate deployments | Valid: fee 500, cap 1000, `MIN_SHARES` 1000, paused false, count 0, ownership event. Zero treasury `ZeroAddress`. Zero owner `OwnableInvalidOwner(0)`. Zero manager stored, no new reject | WP-04 | Executable |
| AC06 | `test_AC06_twoKeysSharedCurrency` | Two initialized pools differing in one key field, one shared currency | Distinct ids, usable ticks, exists true, zero accounting, array order, count +1 each, exact `VaultCreated` | WP-04 | Executable |
| AC07 | `test_AC07_duplicate`; `test_AC07_uninitialized`; `test_AC07_arrayOob` | Second create; create before initialize; `allVaults(count)` | `VaultExists`; `PoolNotInitialized`; `Panic(0x32)`. No extra array entry or log | WP-04 | Executable |
| AC08 | `test_AC08_unknown`; `test_AC08_emptyCreated` | Unknown id, then created vault before any deposit | Unknown struct default, quotes `(0,0)`, shares 0. Empty created keeps key, ticks, exists; quotes stay `(0,0)` | WP-04 | Executable |
| AC09 | `test_AC09_F0_payerNotRecipient` | F0, payer A, recipient B, `A != B`, no zap | Recipient shares `1047576` if real liquidity is `K`. A gets both refunds. Event user is B. Salt-zero position owner is Weir. Neither A nor B owns it | WP-05 | Executable if fee-0 initialize works |
| AC10 | `test_AC10_raw1002`; `test_AC10_raw1003` | Fresh tick-zero fee-zero pools, paired raw inputs | 1002 reverts `ZeroShares` at liquidity 1000. 1003 mints liquidity 1001, one user share, refund 2 each | WP-05 | Executable |
| AC11 | `test_AC11_amounts012_fresh`; `test_AC11_amounts012_existing`; `test_AC11_oneSided_token0`; `test_AC11_oneSided_token1` | Fresh and existing vaults, interior price for one-sided | Zero resulting liquidity or shares reverts `ZeroShares`. Transfers and idle do not create a false success | WP-05 | Executable |
| AC12 | `test_AC12_secondPairedDeposit` | F0 then the same paired deposit, no fees | Second user receives `K` shares. Liquidity and total shares `2K`. Reserve gap stays 1000. First ledger unchanged | WP-05 | Executable |
| AC13 | `test_AC13_depositAfterRealFees` | Real donate or swap fees, then paired deposit | Compound applies cut, liquidity, and idle first. New shares are `floor(newL * postCompoundT / postCompoundL)`. Pre-compound L is not the price base | WP-05 | Executable once donate path works |
| AC14 | `test_AC14_F3_idleDilution` | F3 sequence | F3 integers, including the second user's idle0 claim of 9, and no extra payment for old idle. Do not fail a NAV assertion | WP-05 | Conditional on F1 |
| AC15 | `test_AC15_balancedNoSwap`; `test_AC15_xZero`; `test_AC15_currency0Heavy`; `test_AC15_currency1Heavy`; `test_AC15_singleSided0`; `test_AC15_singleSided1` | External liquidity, four imbalance shapes plus an `x=0` input | Direction and input match the nested-floor rule. Zero and no imbalance do not swap. Otherwise one swap. Sizing uses returned deltas and post-swap price | WP-05 | No-swap Executable. Swap subcases blocked on the tick oracle, not waived |
| AC16 | `test_AC16_zapFeesStayWithPayer` | Existing Weir liquidity in a fee-bearing pool, another payer zaps. Separate earlier fees from this swap's fees | First modify return includes same-call fees on old liquidity. Those fees reduce used input or credit the payer. No second cut. No incumbent share credit | WP-05 | Conditional on tick oracle and a fee-bearing initialize |
| AC17 | `test_AC17_minSharesEqual`; `test_AC17_minSharesPlusOne` | Successful deposit with computed shares S, replay at `minShares = S` and `S+1` | Equality succeeds. `S+1` reverts `Slippage` after callback work. Rollback includes auto-created vault, treasury fees, pulls, and refunds | WP-05 | Executable |
| AC18 | `test_AC18_transferOther`; `test_AC18_transferSelf`; `test_AC18_transferWeir`; `test_AC18_zeroUnknown`; `test_AC18_zeroRecipient`; `test_AC18_overspend` | Shares in one pool | Per-pool conservation and exact `SharesTransferred`. Self transfer unchanged after the debit check. Weir may hold stranded shares. Unknown zero transfer succeeds. Zero recipient `ZeroAddress`. Overspend `Panic(0x11)` | WP-05 | Executable |
| AC19 | `test_AC19_pausedDeposit`; `test_AC19_pausedOtherOps` | Pause a funded vault | Deposit `EnforcedPause`. Create, transfer, compound, withdraw, views, and receive keep their own outcomes | WP-05 | Executable |
| AC20 | `test_AC20_pausedBeatsReentrantAndDeadline`; `test_AC20_expiredBeatsRecipient`; `test_AC20_zeroRecipient` | Combined invalid inputs, then isolated cases | Paused before reentrancy before deadline. Body: recipient before auto-create, native check, and pulls. Unpaused expired zero recipient is `Expired`. Future deadline zero recipient is `ZeroAddress` | WP-05 | Executable |
| AC21 | `test_AC21_F0_fullWithdraw` | F0, zapTo 0, recipient differs from owner | Output `(1047575,1047575)` if the oracle amount holds. Recipient paid. Caller ledger 0. `L=T=1000`. Idle 0. Event user is the caller | WP-05 | Executable |
| AC22 | `test_AC22_subsetAfterFees` | Real fees and idle, withdraw a proper subset | Compound first. Burn and idle claims floor against post-compound total. No last-user sweep | WP-05 | Executable |
| AC23 | `test_AC23_zeroRemovedLiquidity`; `test_AC23_idleWithoutLiquidity`; `test_AC23_zeroOutputBurn` | Real fee or idle state, tiny share count chosen by the oracle | If removed liquidity is 0, no manager remove. Nonzero idle claim is still paid. All-zero claims can burn for zero output when both minima are 0. If a branch cannot be reached, record the gap | WP-05 | Gap-if-unreachable per branch |
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
| AC34 | `test_AC34_directDonations`; `test_AC34_selfRecipientWithdraw` | ERC-20 and native donations around F0. Separate full F0 withdrawal to recipient Weir, no zap, no fees | Donations alone do not change shares, idle, fees, or quotes. Self-recipient withdrawal delivers the F0 remainder to Weir, idle stays `(0,0)`, `L=T=1000`, holder shares 0. Receipts are unassigned. Receive emits no vault event | WP-05 | Executable |
| AC35 | `test_AC35_sharedCurrencyIsolation` | Two funded vaults share a currency. Accrue and operate on one | Only the selected vault's accounting and position change. Physical balance equals the sum of recorded idle for that currency plus tracked unassigned inventory | WP-05 | Executable |
| AC36 | `test_AC36_noAllowance`; `test_AC36_noBalance` | Pre-existing inventory, exact-transfer token, missing allowance or missing payer balance | Token-specific exact failure. Inventory is not a substitute. No new shares and no inventory loss. Short delivery is AC55, not a safety claim here | WP-05 | Executable |
| AC37 | `test_AC37_exitSwapFeesRemain` | Burn, then zap in a fee-bearing pool | Exit-swap fees accrue to remaining real liquidity. They are not allocated to burned shares and are not auto-compounded again. Later pending and compound match the floor formula | WP-05 | Conditional on tick oracle |
| AC38 | `test_AC38_previewZero`; `test_AC38_previewFraction`; `test_AC38_previewAllTotal`; `test_AC38_previewAboveCaller` | F0 and fee or idle variants | Independent downward amounts plus floored idle. No ownership check. No state change. `totalShares=0` does not read the manager | WP-05 | Executable |
| AC39 | `test_AC39_shareCastFits`; `test_AC39_shareProductOverflow`; `test_AC39_zeroTotalShortCircuit` | `L=T=K`, idle 0, then a separate zero-total vault | First quotes liquidity 7, which is 6 units each at the F0 range. Second `Panic(0x11)`, not a cast error. Zero total returns `(0,0)`, not division panic | WP-05 | Executable |
| AC40 | `test_AC40_previewOmitsFees`; `test_AC40_previewOmitsZap`; `test_AC40_equalityWhenPrerequisitesHold` | Pending fees, then a withdrawal that compounds. Separate zap fixture. Separate no-pending no-zap fixture | Preview and execution each match their own formula. Equality is required only in the no-pending, no-maintenance, no-zap fixture | WP-05 | Executable |
| AC41 | `test_AC41_pendingInside`; `test_AC41_pendingBelow`; `test_AC41_pendingAbove`; `test_AC41_modularWrapVector` | Real position with fee growth. Wrap vector is independent math if a live wrap cannot be reached | `floor(((inside-last) mod 2^256) * positionL / 2^128)` per currency, gross of performance fee, no state change | WP-05 | Inside Executable. Range and wrap Gap-if-unreachable |
| AC42 | `test_AC42_boundsOrdered`; `test_AC42_boundsReversed` | Exposure harness, `A=Q`, `B=2Q`, amount 3 | `L0=6`, `L1=3` both orders. Liquidity 7 converts to amount0 3 and amount1 7 | WP-04 | Executable |
| AC43 | `test_AC43_interiorMin`; `test_AC43_atLower`; `test_AC43_atUpper` | Bounds `Q/2` and `2Q`, amounts `(3,4)`, then `P=A` and `P=B` | Liquidity 6. Amounts for liquidity 7 are `(3,3)`. Boundaries take the source outer branch | WP-04 | Executable |
| AC44 | `test_AC44_overflowAmount0Branch`; `test_AC44_overflowAmount1Branch` | Interior `P=Q`, amounts `(2^127,1)` then `(1,2^127)` | `Error("liquidity overflow")` on the overflowing branch even though the other branch fits | WP-04 | Executable |
| AC45 | `test_AC45_equalBounds`; `test_AC45_amount0DivByZero` | Equal nonzero bounds. Separate `A=0`, `B=Q`, liquidity 1 | Empty FullMath revert, then `Panic(0x12)`. No new invalid-range error | WP-04 | Executable |
| AC46 | `test_AC46_timestampMax`; `test_AC46_timestampWrap`; `test_AC46_timestampWrapPlus`; `test_AC46_deadlineEqual`; `test_AC46_deadlineMinusOne` | Empty known vault. Separate valid deposit and withdraw fixtures | Stored timestamps `2^64-1`, 0, 7. Deadline equality accepted. `t-1` is `Expired` and restores the prior timestamp | WP-05 | Executable |
| AC47 | `test_AC47_fuzzOracleDomain` | Fuzz inside the independent valid domain, plus explicit overflow bounds | Nested-floor and cast results, exact error class. Raw units, no decimal normalization | WP-05 | Executable. Configured fuzz runs are 16. Do not edit `foundry.toml` |
| AC48 | `test_AC48_nativePaired`; `test_AC48_nativeZap`; `test_AC48_nativeValueLow`; `test_AC48_nativeValueHigh`; `test_AC48_erc20ValueRejected` | Native/ERC-20 pool, then ERC-20/ERC-20 with value 1 | Correct value settles and refunds native with no WETH. Wrong value `BadNativeAmount`. Payer receives the native refund when the recipient differs | WP-06 | Executable |
| AC49 | `test_AC49_rejectingRefund`; `test_AC49_zeroRefundNoCall` | Payer contract rejects native | Nonzero refund: `NativeTransferFailed` and full rollback. Zero refund: no refund call and no failure from a rejecting receive | WP-06 | Executable |
| AC50 | `test_AC50_rejectingTake` | Native output or treasury cut to a receiver with known revert bytes | Manager currency-transfer envelope and nested receiver bytes, not `NativeTransferFailed`. No retained burn or fee cut | WP-06 | Executable. Selector is whatever Currency and CustomRevert actually emit |
| AC51 | `test_AC51_syncBeforeUnlock_caught`; `test_AC51_syncBeforeUnlock_uncaught`; `test_AC51_syncDuringCallback_caught`; `test_AC51_syncDuringCallback_uncaught` | Non-native sync left open, then a Weir call that native-pays | `NonzeroNativeValue` because Weir does not `sync` native. Failed Weir subtree rolls back. A router sync survives only if the router catches. An uncaught revert rolls back the transaction. An inner failure does not close a router-owned unlock. No `sync(0)` repair | WP-06 | Executable |
| AC52 | `test_AC52_ownerMatrix`; `test_AC52_feeBounds`; `test_AC52_treasuryZeroAndRepeat` | Owner, non-owner, pending owner. Fees 0, 500, 1000, 1001 | Only current owner succeeds. Unauthorized is `OwnableUnauthorizedAccount(caller)` before body checks. 1001 is `FeeTooHigh`. Zero treasury is `ZeroAddress`. Accepted setters emit, including no-change | WP-06 | Executable |
| AC53 | `test_AC53_startReplaceCancelAccept`; `test_AC53_wrongAccepter`; `test_AC53_renounceWhilePaused` | Two-step ownership, then a separate pause-then-renounce fixture | Pending and current transitions and events match OZ. Wrong accepter error includes the caller. Pending cleared on accept and renounce. Former owner cannot unpause | WP-06 | Executable |
| AC54 | `test_AC54_reenterOnPull`; `test_AC54_reenterOnHook`; `test_AC54_reenterOnTake`; `test_AC54_reenterOnRefund`; paused twins of each | Real token, hook, treasury, recipient, or payer callbacks | Guarded reentry is `ReentrancyGuardReentrantCall` where reached. Paused deposit fails `EnforcedPause` first. A caught nested rejection can leave the outer call successful. A bubbling rejection rolls back at the failed boundary | WP-06 | Executable |
| AC55 | `test_AC55_falseReturn`; `test_AC55_noReturnDelivered`; `test_AC55_explicitRevert`; `test_AC55_shortDelivery`; `test_AC55_shortDeliveryWithInventory` | Hostile token modes. Inventory seeded only in the last subcase | False is `SafeERC20FailedOperation(token)` at Weir's SafeERC20 site. Explicit revert bytes bubble. Empty return with real delivery is accepted. Short delivery is characterized: no inbound balance check, may spend inventory or fail later. No safety claim | WP-06 | Executable |
| AC56 | `test_AC56_callbackTransferShares`; `test_AC56_callbackCreateVault`; `test_AC56_callbackViews`; `test_AC56_ownerCallbackSetters` | Give the callback contract its own shares and, for the setter case, current ownership | Unguarded surfaces use their own checks. A token-driven transfer moves the token caller's shares, not another user's | WP-06 | Executable |
| AC57 | `test_AC57_treasuryChangesBetweenTakes` | Native currency0, both fee components positive, first cut strictly positive. Initial treasury is the current owner and changes treasury to T2 in its native callback | Cuts computed before either take. First native cut reaches the old treasury. Second cut uses T2. An ERC-20 transfer alone is not a recipient callback. If the outer call reverts, the setter rolls back too | WP-06 | Executable |
| AC58 | `test_AC58_outsiderCallback`; `test_AC58_nestedUnlockCaught`; `test_AC58_nestedUnlockBubbles`; `test_AC58_guardedReentry` | Outsider calls `unlockCallback`. Router owns unlock and calls `compound`. Separate reentry from an active Weir call | Outsider `NotPoolManager` before decode. Nested unlock `AlreadyUnlocked`. Guarded reentry hits the guard first. A caught failure leaves the router unlock open until the router finishes | WP-06 | Executable |
| AC59 | `test_AC59_hookOrder`; `test_AC59_zeroLiquiditySkipsPoke`; `test_AC59_zeroReinvestSkipsAdd`; `test_AC59_createVaultNoHook`; `test_AC59_revertingHook` | Nonzero-L vault, observe hook, positive reinvestment. Separate zero-L and zero-reinvest fixtures | Supplied hookData unchanged. Applicable poke precedes reinvestment, then the user action. Zero L skips poke. Zero calculated add skips reinvestment. `createVault` does not call the pool hook. Reverting hook uses the real wrapped error and the real rollback boundary | WP-06 | Executable. Wrapper selector unverified until read from `Hooks.sol` |
| AC60 | `test_AC60_firstReturnNotFeesAccrued`; `test_AC60_negativeComponentUnsettled` | Return-delta hook. Hook settles its own hook delta. One case leaves Weir a negative component | Gross fee uses positive first-return components, not the informational second return. An unsettled negative Weir component ends in `CurrencyNotSettled` unless the source settlement pays it | WP-06 | Executable if the hook can return that delta. Otherwise Gap-if-unreachable |
| AC61 | `test_AC61_observeOnTreasuryTake`; `test_AC61_observeOnWithdrawSettle`; `test_AC61_observeOnDepositRefund` | Hostile receiver reads views and shares during those calls | Withdrawal debit precedes callback compounding. Deposit recipient credit precedes outer refunds. Do not claim every phase matches the end-of-transaction invariant | WP-06 | Executable |
| AC62 | `test_AC62_nonpayableValue`; `test_AC62_receive` | Low-level calls with value. Separate empty-calldata value | Nonpayable dispatch fails with the compiled target's actual revert bytes, not a made-up selector. Receive succeeds and does not change the ledger | WP-04 | Executable |
| AC63 | `invariant_AC63_supportedDomain` | Handler, at least 3 users and 2 pools, shared currency, exact-transfer tokens, no return-delta and no short delivery | After successful top-level completion, outside callbacks: recorded L equals salt-zero position L; assigned-share sum equals `T-1000` after genesis and 0 before; physical inventory reconciles; unlock deltas are closed. Classified failures use the subtree boundary. Hostile cases are excluded | WP-07 | Executable. Configured invariant runs 16, depth 8 |
| AC64 | `invariant_AC64_hostileCampaign` | Separate handler: callbacks, rejects, short delivery, return-delta, partial fills, pause, owner changes | Exact classified success or failure. Supported-domain invariants are not asserted across hostile assumptions | WP-06 | Executable for constructed cases. Partial fills depend on the tick oracle |
| AC65 | `test_AC65_forkPreflight`; `test_AC65_forkParitySelectedPool` | Fork recipe in section 10 | Preflight matches chain, block, hash, and code, or reverts `ForkPreflightBlocked`. Parity compares selected-pool returns, reverts, events, and mapped balances. No production key. No storage injection | WP-08 | Blocked-archive until an archive alias works |
| AC66 | `IMPORT_EVIDENCE.md` map | After the other packages have statuses | Every WI and AC points to a test, a static check, or an explicit unresolved gate. Hermetic and fork statuses are separate. No upstream-parity or production-safety claim | WP-09 | Static |
| AC67 | `test_AC67_wrappedIdleOrGap` | Return-delta pool, real idle, construct `int256(oldIdle)+net = -1`, donated physical currency pays the debt, hook settles its own deltas | If reached, recorded idle is `2^256-1`, not a cast revert. Assert physical balance and any later revert with full rollback. If not reached, record the precise gap. Do not claim fail-closed | WP-06 | Gap-if-unreachable until constructed |
| AC68 | `test_AC68_ozFileIdentity`; `test_AC68_storageLayout`; `test_AC68_tokenReturnMatrix` | Hash the six files. Read compiler storage layout. Run true, false, empty, and reverting token cases plus owner, pause, and guard cases | File identity holds or the import stops. SafeERC20 need not equal the whole frozen file. Used paths keep typed failures. No mixed Context and no namespaced 5.6.1 guard | WP-04 | Executable as a gate. Identity itself is unverified in this draft |
| AC69 | `test_AC69_resolvedGraphRecord` | After build, traverse compiler input sources | Frozen 39-file map stays provenance. Actual graph separately records StateLibrary's hashing helper and literal BSL or AGPL headers reached. Test-only AGPL is distinguished from runtime | WP-04, WP-09 | Executable as a record. License disposition remains Blocked-release |

## 7. WI-01 through WI-37

| WI | Closed by | Evidence | Does not close it |
|---|---|---|---|
| WI-01 | WP-01 | Three files at the owner paths, no second tree, frozen texts not compiled | A copy under `contracts/external` |
| WI-02 | WP-01, WP-02, AC01 | Allowlisted diff only, plus recorded WI-06 edits if diagnosed | A cleanup that still passes tests |
| WI-03 | WP-01 `VENDOR.md`, AC69 | Both hash columns, 39 entries, deployment table, missing upstream evidence | Adjusted hashes presented as frozen hashes |
| WI-04 | WP-00, AC42-AC45, AC68, hermetic round-trip | Surface diffs and runtime reads | Path resolution alone, or a slot number alone |
| WI-05 | AC04, AC69 | Full declarations and resolved graph recorded | A MIT label, a scrub, or a clearance sentence |
| WI-06 | WP-02 | Default settings, diagnostic, exact diff, fidelity rerun | viaIR, a storage redesign, or a preemptive refactor |
| WI-07 | Scope check in WP-09 | No wrapper, registry, NAV, repair, or simulator in the diff | A characterization test used as a reason to fix |
| WI-08 | AC06, AC07, AC09 | Real initialize, permissionless create, salt-zero Weir position | A mocked slot0 |
| WI-09 | AC02, AC68 | ABI tuples and storage layout artifact | A renamed field with the same test names |
| WI-10 | AC02, AC05, AC62 | Manifest ABI compare, including zero-manager acceptance | An invented `balanceOf` or ERC-4626 test |
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
| WI-29 | AC48-AC51, AC55, AC62 | Native is address zero. Exact `msg.value`. Sync, transfer, settle for ERC-20. No native sync. Take failures keep the manager envelope | WETH, or relabeling `NonzeroNativeValue` as `NativeTransferFailed` |
| WI-30 | AC17, AC26, AC46, AC51, AC54 | Snapshot at the failed call subtree. Caught outer effects remain. Debug logs are not receipts | `expectRevert()` with no error, or a sleep |
| WI-31 | AC02, AC39, AC42-AC47, AC55 | Exact errors, panics, checked math, modular fee growth | `FullMath` substituted for a checked product, or SafeCast substituted for a source cast |
| WI-32 | WP-03, AC63 | Real Weir, real canonical manager, CraneTest parent, peripherals only outside the SUT | Mock, etch, or storage injection |
| WI-33 | Behavior helper used by every success row | Integer balances, shares, idle, position, timestamp, treasury, deltas, events, hookData | A lock-closed assert during a callback or during unguarded create, transfer, or views |
| WI-34 | WP-05 oracle | Independent limb math and pre-state. Swap goldens have provenance | `previewRedeem` or the production L library as the expected value |
| WI-35 | AC23, AC25, AC33, AC55, AC60, AC64, AC67 | Limitation asserted, or gap recorded | A fabricated pass or a repair |
| WI-36 | AC47, AC63, AC64 | Seed, runs 16, depth 8, success count, failing sequence | An all-revert campaign, or a `foundry.toml` edit to inflate runs |
| WI-37 | Section 11 commands, AC65 | Build before test. Fork under the fork profile and the shared pin. Missing archive is blocked | A receipt check called parity, or a skip called pass |

## 8. Callbacks, inventory, and rollback

Roles are concrete. Payer is `msg.sender` of deposit. Share recipient may differ. Share owner is `msg.sender` of withdraw and of `transferShares`. Treasury is the stored address at each `take`. Hook is the pool key's hook, not Weir.

The sequences below are adopted from agreeing member source observations. The implementer re-reads the frozen functions before encoding them. A disagreement with the frozen text wins over this section.

Deposit, unpaused, future deadline, nonzero recipient:

1. Pause modifier, then reentrancy, then deadline.
2. Reject zero recipient. Auto-create if absent. That create reads slot0 and does not call a hook.
3. Check `msg.value` against native legs only. Pull currency0, then currency1, from the payer. Zero and native pulls skip ERC-20.
4. `poolManager.unlock` encodes `DEPOSIT`, id, and `(params, payer)`.
5. Manager calls `unlockCallback`. Any other caller has already failed `NotPoolManager`.
6. Callback compounds first with `params.hookData`, then deposits.
7. Zap, if requested, may swap once with the same hookData. Then slot0 is read again. Liquidity is sized. `modifyLiquidity` uses stored ticks, positive `int256` liquidity, salt zero, same hookData.
8. First return is added to the zap nets. Used amount is the negative part. Settlement pays a negative net from Weir's pulled funds and takes a positive net to the payer, not the recipient.
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
4. Cut currency0, then currency1, by `take` to the treasury address read at that call.
5. Reinvest only if cushioned inventory is positive and computed liquidity is positive. The second modify is skipped when liquidity is 0.
6. Idle is the source cast of `int256(old)+net`. Settle nets to `address(this)`.
7. Emit `Compounded` only when a harvested positive component is nonzero. Idle-only adds do not emit.

Hook settlement is real. `modifyLiquidity` accounts `callerDelta` to Weir and a nonzero hook delta to the hook. The hook must settle its own debt inside the callback, while the manager is unlocked. Weir's source settlement is not changed to cover hook debt. If Weir's own component stays negative, the manager's unlock exit reverts `CurrencyNotSettled`.

### Inventory after a closed unlock

Ordinary domain only: exact-transfer, non-rebasing tokens, no return-delta that wraps idle, and only after a successful deposit, withdraw, or compound has returned and the manager is locked again.

For each physical currency `c`:

`balance(weir, c) = sum of recorded idle claims denominated in c + ghost unassigned(c)`

Unassigned includes direct donations, treasury cuts delivered to Weir, and withdrawal proceeds delivered to Weir. Those are not idle and not new shares. Shares held by Weir are assigned and belong in the share sum, not in unassigned. Position principal sits in the manager and is not part of this balance. Manager deltas for that unlock are zero.

Assigned-share sum equals `T - 1000` after genesis and 0 before it. Do not look for a zero-address balance. Do not assert `idle <= 2`, zero unwanted output, nonnegative cast safety, or NAV fairness. AC67 is outside this equality. Shared-currency tests reconcile each currency across all vaults, not per vault.

### Rollback

Before every failing-call test, read the affected slots and balances, start log recording, and take `vm.snapshotState()`. Subscribe `expectEmit` before a call that is expected to succeed. Do not sleep, poll, or wait on time. Warp with `vm.warp` when the timestamp is the input.

Boundaries:

- Uncaught Weir revert: the call subtree loses vault creation, share and idle writes, timestamp, pulls, refunds, treasury cuts, position changes, and hook effects. Proof is the post-call state matching the pre-call reads. A debug log buffer captured during the reverted call is not a receipt.
- Caught by an outer router: earlier and later successful router effects remain. The Weir subtree matches its own pre-call reads. A caught reentrant rejection does not by itself undo a successful outer Weir call that already finished.
- Minima and `Slippage` happen after external settlement. The test must show those effects still disappear when the outer call reverts. Do not reorder the source to make the test easier.
- Do not snapshot only the whole transaction when the AC asks for a caught inner boundary, and do not do the reverse.

If a later local receipt is actually collected, store it under `contracts/protocols/strategy/weir/test/evidence/receipts/`. Do not fabricate that directory from `recordLogs`.

## 9. Fork parity

Supplied reference. Manager and pin also appear in `ROBINHOOD_MAIN.sol`. The Weir address was not added to that file.

- Chain 4663.
- Reference Weir `0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110`. Test-local literal. Do not edit `ROBINHOOD_MAIN.sol`.
- Manager `0x8366a39CC670B4001A1121B8F6A443A643e40951`.
- Block `76_197_114`, hash `0x07be1214c2742ebcea7a61d8065020e88c4b66b5fc96a753ff022a00aa2c8c1d`, time `2026-09-30T03:33:23Z`.
- Deploy tx `0xa92ae44ce73b159a3aa3d6c8e2920b4c4771d784a253313a35d2fd9c4fad351a`.
- Owner and treasury `0x3234DEA52cc05cba7830B5305151C50AD34e9018`.
- Direct creation, not a factory. Supplied receipt evidence. This draft did not refetch it.

Recipe:

1. Finish hermetic artifact jobs.
2. `FOUNDRY_PROFILE=fork forge build`, then the fork test command in section 11.
3. In the fork TestBase, `vm.createSelectFork(vm.rpcUrl("robinhood_mainnet_alchemy"), ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK)` before `CraneTest.setUp()`. Do not deploy a local manager and then fork. Do not call the hermetic `setUp`.
4. Preflight: chain id 4663, block number equals the shared pin, block hash equals the supplied hash, reference Weir code nonempty, manager code nonempty, manager address equals the constant. `blockhash(block.number)` is not a current-header proof. Any failure reverts `ForkPreflightBlocked(reason)`. No `vm.skip`. A public-alias receipt is not a substitute. If `vm.rpcUrl` reverts because the key is absent, that failure is BLOCKED, not a pass.
5. Deploy two fresh exact-transfer peripherals on the fork, sort them, and initialize a hookless pool on the reference manager. The selected id must be absent from reference `vault(id).exists`.
6. Deploy the copy with that same manager, a test owner, and a test treasury. Align fee and pause with local `vm.prank` on the copy owner. Do not impersonate a production key to send a live transaction. Local `vm.prank` of the reference owner is allowed only if a parity action needs an owner-only reference call, and it still writes nothing to the real network.
7. `snapshotState` after both contracts and the fresh pool exist, before the action.
8. Run the action on the reference. Record returns, reverts, events, and mapped balances in memory that survives `revertToState`, or in an external comparison record that is not fork storage written after the snapshot. `revertToState`. Run the same action on the copy. Compare selected-pool deltas under an explicit map: reference Weir to copy Weir, same payer, recipient, and pool key. Do not compare `allVaults` prefixes or unrelated positions.
9. If reference role state blocks an equivalent setup, record that action as blocked. Do not inject code or storage. Do not use a production private key.

Missing key or pruned history is NOT RUN/BLOCKED. This draft does not claim the fork passed.

## 10. Commands and separated gates

Future commands, from the repository root. Not run for this draft. Settings are the observed default.

Focused build before focused tests, after domain edits:

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

Fidelity command, after the copy and after any WI-06 edit:

```bash
python3 contracts/protocols/strategy/weir/test/tools/check_fidelity.py \
  --frozen docs/research/weir-source-import-prd-20261029-01a18660/source-snapshot/sources \
  --imported contracts/protocols/strategy/weir \
  --manifest contracts/protocols/strategy/weir/evidence/import-transform.json \
  --abi out/WeirVaults.sol/WeirVaults.json \
  --abi-baseline contracts/protocols/strategy/weir/evidence/abi-baseline.json
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

Do not launch the fork test as a fake successful skip when archive preflight fails. Record it as blocked. Default tests remain hermetic with no RPC and no secrets. Keep `FOUNDRY_TEST`, compiler settings, and profiles unchanged.

Gate meanings:

| Claim | Minimum evidence |
|---|---|
| Source fidelity | Allowlisted transformation, baseline ABI, storage and inheritance, used-dependency compatibility |
| Compiler success | Actual target-settings build exit 0. It does not reproduce upstream 0.8.26, optimizer 800, viaIR bytecode |
| Hermetic proof | Spec suite exits 0 with exact integers. A gap row is a written gap, not a passing assertion |
| Reference parity | Archive-backed selected-pool comparison after preflight. Otherwise blocked |
| Security characterization | AC55, AC60, AC64, and AC67 describe behavior. They are not a safety clearance |
| Receipt-level rollback | An actual local receipt if that claim is made. `recordLogs` is not that receipt |
| Release clearance | AC04, AC66, and AC69. GPL and AGPL are open-source. BUSL production use stays unresolved |

## 11. Limits

- This draft did not compile, test, hash the PRD, call RPC, or deploy.
- F0 liquidity, F0 redemption amounts, AC39 truncation, and AC42-AC43 integers are member-recomputed from TickMath constants and the PRD formulas. They are not test results. F1 and F2 remain conditional on `Pool.donate`.
- Callback order in section 8 is adopted from agreeing originals, not re-derived line by line in this coordinator pass. The frozen source wins.
- A canonical mismatch outside the 22 rewrites, the added `PoolOperation` import, the five qualifications, and a diagnosed WI-06 scope or memory-struct edit stops the work.
- Unavailable upstream suite and audit stay unavailable.
- Unreachable adversarial branches stay gaps. AC23, AC33, AC41 wrap, AC60, and AC67 are the named gap points.
- License and archive inputs can block release or parity without blocking a faithful hermetic import. They cannot be waived.
- Do not silently expand product behavior. Do not weaken a failing test. Do not pin this plan or the PRD with a prose test.
- Preservation traps the tests must lock, not fix: idle dilution, deposit swap fees staying with the payer, first return rather than informational fees, unassigned genesis shares, shared-currency custody, per-harvest fee flooring, partial zap fills, preview not equaling execution, native pay without `sync(0)`, unguarded create and transfer, and comments that overclaim economic safety.

This draft proposes a complete work order. It neither replaces the PRD nor authorizes implementation.
