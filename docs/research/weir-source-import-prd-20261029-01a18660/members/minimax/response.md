# WeirVaults source-import PRD — independent council contribution (MiniMax M3)

Member: MiniMax (`minimax/MiniMax-M3`). Run: `docs/research/weir-source-import-prd-20261029-01a18660/`.
Status: original independent authoring pass. No peer originals or feedback were read. Nothing was
implemented, copied into production, built, tested, deployed, or written outside this file.

---

## 1. Scope, identity, and limits of this contribution

This contribution is a **PRD authoring input** for a faithful baseline source import of the upstream
`WeirVaults` contract into `contracts/protocols/strategy/weir/`. It is:

- **not** an implementation plan that authorizes code changes,
- **not** an adaptation of Weir into an ERC20/ERC4626 wrapper, Rate Provider, Diamond/SE family,
  registry-integrated vault, or fee-free variant,
- **not** a remediation of any upstream defect. Upstream defects and awkward behavior are recorded
  here as **characterization obligations** (tests that pin the observed baseline behavior), never as
  defects to fix.

Terminology used throughout:

| Term | Meaning here |
|---|---|
| **Baseline** | The exact upstream source pinned by the coordinator's Sourcify retrieval (39 files, content-addressed) |
| **Import** | Copying the three domain source files into `contracts/protocols/strategy/weir/` with only enumerated, approved deviations |
| **Faithful** | Observable behavior, ABI shape, and arithmetic match the baseline; source text may differ only by the enumerated deviations in §5 |
| **Characterization** | A test that pins what the baseline *does*, including what a reasonable reviewer would call a bug |
| **Deviation** | Any change to baseline source text or dependency selection that is not a pure import-path rewrite |

**Requirement prefix taxonomy** (used in every section):

- `F-xx` — Import fidelity requirement (the copy must reproduce baseline behavior).
- `D-xx` — Dependency, compiler, and compatibility requirement.
- `L-xx` — License and provenance requirement.
- `B-xx` — Behavioral contract requirement (a normative statement of one observable behavior).
- `R-xx` — Upstream risk register entry (known limitation; characterize, do not repair).
- `X-xx` — Explicitly excluded improvement (would need separate approval and its own PRD).
- `T-xx` — Test topology and test-content requirement.
- `V-xx` — Reproducible validation command requirement.

Every requirement below is normative: "must" / "must not" are binding on the implementing pass.

---

## 2. Evidence actually read (and what was *not* read)

### 2.1 Frozen primary evidence read in full

| Path | Lines | SHA-256 | SPDX (file header) |
|---|---|---|---|
| `source-snapshot/sources/src/WeirVaults.sol.txt` | 427 (+ trailing newline) | `23de61301729d2950ba110e15cdce5e383fc4e5aacb0b906ee845390bd0e0180` | MIT |
| `source-snapshot/sources/src/base/WeirBase.sol.txt` | 93 | `f14c1ef0fe9913f0d99e872f108ab3d7b84f44050d449d2b72049ad20a08b498` | MIT |
| `source-snapshot/sources/src/libraries/LiquidityAmounts.sol.txt` | 61 | `f482702fecb1b6dc5c82b9ad918a4f991ce5b8c4d0c1144b448c25fbaad3093d` | **GPL-2.0-or-later** |
| `source-snapshot/manifest.json` | 1825 | (39 file entries) | license inventory + compiler settings |

I read the complete text of all three domain files and the complete manifest, including the embedded
upstream metadata: compiler `0.8.26+commit.8a97fa7a`, `optimizer {enabled, runs: 800}`,
`evmVersion: cancun`, `viaIR: true`, `metadata.bytecodeHash: none`, `compilationTarget:
{ "src/WeirVaults.sol": "WeirVaults" }`, upstream remappings (`v4-core/=lib/v4-core/`,
`@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/`), the full upstream ABI, and the
39-entry license inventory.

### 2.2 Repository evidence read (dependency candidates, as the brief requires)

- `lib/crane/contracts/protocols/dexes/uniswap/v4/` — Crane's **ported** v4 stack:
  `PoolManager.sol`, `interfaces/IPoolManager.sol`, `types/{Currency,PoolKey,PoolId,BalanceDelta,PoolOperation}.sol`,
  `libraries/{StateLibrary,Position,TickMath,LiquidityAmounts,Pool,Hooks,Lock,CustomRevert,LiquidityMath}.sol`,
  `interfaces/callback/IUnlockCallback.sol`, `Extsload.sol`, `ERC6909Claims.sol`.
- `lib/crane/contracts/protocols/dexes/uniswap/libraries/{FullMath,FixedPoint96,FixedPoint128,SafeCast,BitMath}.sol`.
- `lib/crane/contracts/external/openzeppelin-contracts/` (package `version: 4.9.6`, but the files
  themselves are a **mixed** tree — see §5.4) and `lib/crane/lib/openzeppelin-contracts/` (**5.6.1**).
- `lib/crane/contracts/test/CraneTest.sol`, `lib/crane/contracts/protocols/dexes/uniswap/v4/hooks/public/dependencies/v4-core/test/{PoolTestBase,PoolModifyLiquidityTest,PoolSwapTest}.sol` + `utils/{Deployers,CurrencySettler}.sol`.
- `lib/crane/test/foundry/fork/ethereum_main/uniswapV4/TestBase_UniswapV4Fork.sol` and
  `UniswapV4PortedPoolManagerParity_Fork.t.sol`.
- Repo rules: `CLAUDE.md`, `.github/ASSISTANT_RULES.md`, `.github/ASSISTANT_CODING.md`,
  `.github/ASSISTANT_TESTS.md`, `docs/testing/ARTIFACT_BUILDS.md`, `scripts/forge-artifacts.py` usage.
- `lib/crane/.claude/skills/crane-porting/SKILL.md` + `references/dependency-routing.md`,
  `lib/crane/.claude/skills/crane-porting-verification/SKILL.md`.
- Root `foundry.toml`, root `remappings.txt`, `lib/crane/remappings.txt`.

### 2.3 Evidence limits (must appear verbatim in the final PRD)

1. The Sourcify record (chain `4663`, `0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110`,
   `match`/`creationMatch`/`runtimeMatch`, `verifiedAt 2026-09-30T03:34:14Z`) is **registry metadata**,
   not an independent bytecode reproduction, audit, or live transaction.
2. **No upstream Git repository, revision, source test suite, or audit was supplied or verified.**
   The baseline is the content-addressed source snapshot. "Faithful" can therefore mean "matches the
   pinned source", never "matches upstream's intended behavior".
3. **No runtime result in this document is asserted as observed.** Every expected value below is
   derived from the frozen source text, from the upstream ABI in the manifest, or from an explicitly
   stated formula. Where a number can only be obtained by running the code, the PRD requires the test
   to compute it from an independent oracle and record it — it does not pre-state the number.
4. Upstream compiled with `solc 0.8.26`, optimizer 800, **Cancun**, `viaIR=true`,
   `metadata.bytecodeHash=none`. This repo compiles with `solc 0.8.35`, optimizer runs 1,
   **`via_ir=false` (forbidden to enable)**, no `evm_version` pin, default metadata hash.
   **Exact deployed bytecode equality is therefore not an acceptance criterion** and must not be
   asserted anywhere in the PRD or the test suite.
5. Chain `4663` is **not** among this repo's `foundry.toml` `[rpc_endpoints]`. A fork comparison
   against the deployed instance at `0x9bb6A5…` on chain 4663 is currently **unreachable**; the fork
   gate must target an available chain and record the gap rather than fabricate parity.

---

## 3. Environment reality check (what the import actually faces)

These are the facts that shape every requirement below.

| Fact | Evidence | Consequence |
|---|---|---|
| Repo default profile: `solc = "0.8.35"`, `optimizer_runs = 1`, `via_ir = false`, `src = contracts`, `test = test/foundry/spec`, `cache_path = cache_forge`, `out = out` | root `foundry.toml` | Weir's pragmas (`^0.8.26`, `^0.8.24`) are satisfied by 0.8.35; viaIR is unavailable and forbidden |
| Root `remappings.txt` has **no** `v4-core/` and **no** `@openzeppelin/contracts/` mapping | root `remappings.txt` | Weir's literal import paths **do not resolve** in this repo; every import must be rewritten |
| Root remappings available: `forge-std/`, `@crane/`, `contracts/solady/`, `contracts/external/solady/`, `contracts/protocols/launchpads/uniswap/continuous-clearing/`, `tests/`, `@battlechain-contracts/` | root `remappings.txt` | `@crane/=lib/crane/` is the only route to Crane trees; `@crane/lib/openzeppelin-contracts/…` also resolves (5.6.1 tree) |
| Crane's v4 tree is a **port**, not upstream `v4-core`; there is no `lib/v4-core` in this repo | glob of `lib/crane/lib/*` | Upstream `v4-core/src/...` imports must be re-pointed at Crane's port; **type and storage compatibility with upstream v4-core may not be assumed** |
| Crane's `IPoolManager` imports `ModifyLiquidityParams`/`SwapParams` from `types/PoolOperation.sol` as **free structs**; upstream v4-core declares them **nested inside the interface** | `interfaces/IPoolManager.sol:14` vs frozen `lib/v4-core/src/interfaces/IPoolManager.sol.txt:124-141,150-160` | Weir's `IPoolManager.ModifyLiquidityParams(...)` / `IPoolManager.SwapParams({...})` **do not compile** against Crane. This is the **free PoolOperation struct migration** |
| Crane's `types/PoolOperation.sol` `ModifyLiquidityParams` fields = `(int24 tickLower, int24 tickUpper, int256 liquidityDelta, bytes32 salt)`; `SwapParams` fields = `(bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96)` — identical order/types to upstream nested structs | `types/PoolOperation.sol:9-27` vs frozen upstream | Migration is **encoding-identical**: ABI tuples and behavior unchanged |
| Crane's v4 `LiquidityAmounts` provides only `getLiquidityForAmount0/1` and `getLiquidityForAmounts`; it has **no** `getAmountsForLiquidity`, `getAmount0ForLiquidity`, `getAmount1ForLiquidity` | `libraries/LiquidityAmounts.sol` (full file read) vs frozen `src/libraries/LiquidityAmounts.sol.txt:43,48,53` | `previewRedeem` calls `LiquidityAmounts.getAmountsForLiquidity` (frozen `WeirVaults.sol.txt:120-123`) → **the incomplete V4 LiquidityAmounts API** blocks a symbol-level substitution. The import **must carry the baseline GPL `LiquidityAmounts.sol`** |
| Crane's v4 `LiquidityAmounts` uses `SafeCast.toUint128` (custom error `SafeCastOverflow`) while the baseline GPL copy uses `require(..., "liquidity overflow")` | Crane `libraries/LiquidityAmounts.sol:11-35` vs frozen `src/libraries/LiquidityAmounts.sol.txt:11-13` | Substituting changes **revert data** → the brief's "do not casually substitute" rule is binding |
| Crane's `uniswap/libraries/FullMath.sol` differs from frozen upstream `v4-core/src/libraries/FullMath.sol` in **guard order** (Crane: `prod1==0` fast path first with `require(denominator > 0)`; upstream: `require(denominator > prod1)` first) | both files read in full | Same arithmetic; **revert-data path ordering differs** → must be proven by differential test, not asserted |
| Crane's `uniswap/libraries/{FixedPoint96,FixedPoint128}.sol` are **byte-identical (normalized)** to the frozen upstream files | normalized diff | Safe to reuse |
| Crane's `types/PoolKey.sol` is **identical (normalized)** to frozen upstream `types/PoolKey.sol` | normalized diff | PoolId derivation and pool identity are safe to reuse |
| Crane's `StateLibrary` computes pool-state slots via `BetterEfficientHashLib` (**AGPL-3.0-or-later**) `._hash()` = `keccak256(bytes)`, upstream uses `keccak256(abi.encodePacked(...))` | `libraries/StateLibrary.sol:1-6,326-341` vs frozen upstream tail | **Hash-equivalent** (same 32-byte input → same slot) but pulls **AGPL-3.0-or-later** into the closure |
| Crane's `libraries/Position.sol` SPDX is `BSL-1.1`; the frozen upstream `v4-core` `Position.sol` SPDX is `BUSL-1.1` | both file headers read | **License identifier changes** on the route to Crane's tree |
| Two OZ trees exist: `lib/crane/contracts/external/openzeppelin-contracts` (package 4.9.6, but `Pausable.sol` is **v4-style** with string reverts and `SafeERC20.sol` is 4.9.3) and `lib/crane/lib/openzeppelin-contracts` (**5.6.1**, v5-style custom errors) | both trees read | Weir's frozen OZ is **v5.1.0-era**; the 4.9.6-package tree **changes revert data** (`"Pausable: paused"` string instead of `EnforcedPause()`) |
| Frozen upstream OZ versions: `Ownable` v5.0.0, `Ownable2Step` v5.1.0, `Pausable` v5.0.0, `ReentrancyGuard` v5.1.0 (sequential `_status` slot), `SafeERC20` v5.1.0, `IERC20` v5.1.0, `Address` v5.1.0, `Context` v5.0.1, `Errors` v5.1.0 | frozen file headers | ReentrancyGuard v5.5/5.6 moves the guard to an **ERC-7201 namespaced slot** → Weir's **storage layout shifts** |
| Root `foundry.toml` `[rpc_endpoints]` has no chain `4663` | root `foundry.toml` | Deployed-instance fork parity is currently impossible; document, do not fake |
| `contracts/protocols/strategy/weir/` exists but is **empty** | glob | Production destination is pre-created; no conflicting baseline files |
| `test/foundry/spec/protocols/` has `staking, dexes, l2s, pol, messaging, balancer, cdps, lending` — **no `strategy/`**; `test/foundry/fork/` exists | glob | New test tree `test/foundry/spec/protocols/strategy/weir/` is required by the brief |
| No `IndexedexTest` base exists anywhere in `lib/crane` | grep `contract IndexedexTest` → 0 hits | The gold test ladder tops out at `CraneTest` |
| `CraneTest` is **AGPL-3.0-or-later** and its `setUp()` runs `InitDevService.initEnv(address(this))` (diamond factories) | `lib/crane/contracts/test/CraneTest.sol` | Repo law prefers the `CraneTest` ladder, but that env is unrelated product wiring for a standalone vault |
| Root `contracts/` currently imports OZ via `@crane/contracts/external/openzeppelin-contracts/...` (6 hits) and Crane-native `@crane/contracts/access/...`; **no** root contract imports `@crane/lib/openzeppelin-contracts/...` | grep over `contracts/` | The 5.6.1 tree is reachable but **not an established root convention** |
| `scripts/forge-artifacts.py` exists with `plan`/`build`/`test` subcommands and `--test-root`, `--consumer`, `--skip` | script header + `docs/testing/ARTIFACT_BUILDS.md` | Reproducible targeted build/test commands exist and must be used |

---

## 4. Import fidelity requirements (`F-xx`)

**F-01** The import must copy exactly the three baseline domain files into
`contracts/protocols/strategy/weir/`, preserving upstream relative layout so that the baseline's own
relative imports resolve unchanged:
`contracts/protocols/strategy/weir/WeirVaults.sol`,
`contracts/protocols/strategy/weir/base/WeirBase.sol`,
`contracts/protocols/strategy/weir/libraries/LiquidityAmounts.sol`.

**F-02** Each copied file's first line (SPDX identifier) and `pragma` line must be preserved byte-for-byte
from the frozen snapshot. The import must not add, remove, or alter SPDX identifiers or license headers.

**F-03** The three file bodies must be identical to the frozen snapshot **except** for the enumerated
deviations in §5 (import-path rewrites and the free-struct migration). The implementing pass must
produce and attach a per-file diff against `source-snapshot/sources/**` so a reviewer can confirm that
no other edit exists. A diff that contains any change not listed in §5 is a blocking defect.

**F-04** The import must not copy any of the other 36 upstream files (OZ and v4-core sources) into the
repository. Those dependencies are resolved to canonical in-repo trees per §5, and §6 records the
resulting license map.

**F-05** The public ABI of the imported contract must match the upstream ABI recorded in the manifest:
same function/method names, same argument order and types, same struct field order and names
(`DepositParams`, `WithdrawParams`, `Vault`), same event topics and payloads, same error names and
parameter lists. In particular the `Vault` struct order must remain
`key, tickLower, tickUpper, liquidity, totalShares, idle0, idle1, lastCompound, exists`.

**F-06** The import must not add an ERC20/ERC4626 wrapper, share token, `RateProvider`, Diamond facet,
registry integration, fee removal, dead-share removal, hook-only path, strict single-token guarantee,
simulator, optimization, or economic repair. Each of these is enumerated in §8 (`X-xx`).

**F-07** The import must not introduce an owner, admin, operator, or fee-setter beyond the baseline's
`onlyOwner` surface (`setTreasury`, `setPerfFee`, `pause`, `unpause`, plus inherited
`transferOwnership`/`acceptOwnership`/`renounceOwnership`).

**F-08** The import must not be registered, deployed, or wired into any factory, package, or registry in
this baseline. The imported contract is a standalone upstream contract with a constructor
`(IPoolManager, address treasury, address owner)`.

**F-09** The import must preserve the baseline's `receive() external payable {}` on `WeirBase` and the
contract's ability to hold unaccounted native balance.

**F-10** The import must preserve the baseline's constructor-time validation exactly: `treasury ==
address(0)` reverts `ZeroAddress()`; `owner` is passed to `Ownable(_owner)`, so a zero owner reverts
`OwnableInvalidOwner(address(0))`; **no** validation of `_pm` is added.

**F-11** The import must not change `MAX_PERF_FEE_BPS = 1_000`, `MIN_SHARES = 1_000`, or the default
`perfFeeBps = 500`.

**F-12** The import must not change any internal function's semantics, including the private helpers
`_deposit`, `_withdraw`, `_compound`, `_balance`, `_swap`, `_pull`, `_pay`, `_take`, `_settle`,
`_send`, `_checkNative`.

**F-13** The import must not introduce `block.timestamp` dependence beyond what the baseline already
has (`v.lastCompound = uint64(block.timestamp)`, and `checkDeadline`).

**F-14** The import must not add reentrancy protection to any function that the baseline leaves
unguarded, and must not remove protection the baseline has. Specifically: `nonReentrant` on `deposit`,
`withdraw`, `compound`; `whenNotPaused` on `deposit` only; `onlyPoolManager` on `unlockCallback`;
`onlyOwner` on the four admin setters.

**F-15** The import must not alter the baseline's use of `bytes32(0)` as the position salt on every
`modifyLiquidity` call (frozen `WeirVaults.sol.txt:257-259, 292-294`) — one salt-zero full-range
position per pool.

**F-16** The import must not change the two-unit liquidity cushion (`a0 > 2 ? a0 - 2 : 0` and the
`r0 > 2 ? r0 - 2 : 0` form) in `_deposit` and `_compound`.

**F-17** The import must preserve the baseline's `uint64 lastCompound` field width and the
`uint64(block.timestamp)` truncation, and must not widen it to `uint256`.

**F-18** The import must not add a `totalSupply()`/`balanceOf()`/`transfer`/`approve` surface. Baseline
shares are a per-`PoolId` internal mapping exposed only via `sharesOf(PoolId,address)` and
`transferShares`.

---

## 5. Dependency, compiler, and compatibility requirements (`D-xx`)

### 5.1 The two blocking gaps

**D-01 (free PoolOperation struct migration — blocking).** Baseline `WeirVaults.sol.txt` calls
`IPoolManager.ModifyLiquidityParams(v.tickLower, v.tickUpper, int256(uint256(liq)), bytes32(0))`
(lines 257-259 and 292-294) and `IPoolManager.SwapParams({...})` (lines 393-397). Crane's
`IPoolManager` declares these as free structs imported from
`@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol`
(`interfaces/IPoolManager.sol:14`), and upstream v4-core declares them nested in the interface
(frozen `lib/v4-core/src/interfaces/IPoolManager.sol.txt:124-141` and `150-160`). The baseline text
therefore **does not compile** against Crane's `IPoolManager`.

Required migration, and the **only** permitted form of it:

- import `{ModifyLiquidityParams, SwapParams}` from
  `@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol`;
- replace `IPoolManager.ModifyLiquidityParams(` → `ModifyLiquidityParams(` and
  `IPoolManager.SwapParams(` → `SwapParams(` at the four call sites;
- retain the `IPoolManager` import for the `poolManager` immutable type and the
  `IPoolManager.ModifyLiquidityParams` / `IPoolManager.SwapParams` references removed accordingly;
- keep every argument list, field name, and value unchanged.

Because the struct field order and types are identical between upstream nested structs and Crane's
free structs, the ABI tuple encoding and the runtime behavior are unchanged. This deviation must be
recorded in the import's deviation ledger with the four call-site line references.

**D-02 (incomplete V4 LiquidityAmounts API — blocking for `previewRedeem`).** Baseline
`previewRedeem` calls `LiquidityAmounts.getAmountsForLiquidity(...)` (frozen
`WeirVaults.sol.txt:120-123`), and the baseline GPL `LiquidityAmounts.sol` provides
`getAmount0ForLiquidity`, `getAmount1ForLiquidity`, `getAmountsForLiquidity` (lines 43, 48, 53).
Crane's v4 `libraries/LiquidityAmounts.sol` provides **none** of those three. Therefore:

- the import **must** carry the baseline `src/libraries/LiquidityAmounts.sol` file (GPL-2.0-or-later)
  as copied source, with its `v4-core/src/libraries/{FullMath,FixedPoint96}.sol` imports re-pointed
  at Crane's `@crane/contracts/protocols/dexes/uniswap/libraries/{FullMath,FixedPoint96}.sol`;
- the import **must not** substitute Crane's `LiquidityAmounts` for it: the two differ in overflow
  revert data (`"liquidity overflow"` string vs `SafeCastOverflow()` custom error) and in the
  `unchecked`/cast structure, and the baseline's `getAmount0ForLiquidity` uses a different
  `mulDiv`-then-divide shape (`src/libraries/LiquidityAmounts.sol.txt:43-46`);
- the import **must not** add the three missing functions to Crane's library (that would be an
  upstream-tree modification and a dependency mutation outside this baseline).

### 5.2 v4 dependency routing

**D-03** All `v4-core/src/...` imports must be re-pointed at Crane's ported tree, mapping:

| Baseline import | Canonical in-repo path |
|---|---|
| `v4-core/src/interfaces/IPoolManager.sol` | `@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol` |
| `v4-core/src/libraries/StateLibrary.sol` | `…/v4/libraries/StateLibrary.sol` |
| `v4-core/src/libraries/TickMath.sol` | `…/v4/libraries/TickMath.sol` |
| `v4-core/src/libraries/FullMath.sol` | `@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol` |
| `v4-core/src/libraries/FixedPoint96.sol` | `@crane/contracts/protocols/dexes/uniswap/libraries/FixedPoint96.sol` |
| `v4-core/src/libraries/FixedPoint128.sol` | `@crane/contracts/protocols/dexes/uniswap/libraries/FixedPoint128.sol` |
| `v4-core/src/types/PoolKey.sol` | `…/v4/types/PoolKey.sol` |
| `v4-core/src/types/PoolId.sol` | `…/v4/types/PoolId.sol` |
| `v4-core/src/types/Currency.sol` | `…/v4/types/Currency.sol` |
| `v4-core/src/types/BalanceDelta.sol` | `…/v4/types/BalanceDelta.sol` |
| `v4-core/src/interfaces/callback/IUnlockCallback.sol` | `…/v4/interfaces/callback/IUnlockCallback.sol` |
| `v4-core/src/libraries/{CustomRevert,SafeCast,BitMath,LiquidityMath}.sol` (transitive) | `…/v4/libraries/…` and `…/uniswap/libraries/…` |

**D-04** The import must not add a `v4-core` submodule, a `v4-core/` remapping, a global alias, or any
`foundry.toml`/`remappings.txt` edit. The brief forbids it and the repo's profile law forbids new
profiles.

**D-05** The import must not assume upstream-v4-core type, storage-layout, or arithmetic equivalence
with Crane's port. Each of the following must be **proven by test** before the import is considered
compatible (see `T-xx` and `AC-xx`):

- `PoolId` derivation (`keccak256(abi.encode(PoolKey))`) — Crane's `PoolIdLibrary.toId` uses
  `keccak256(poolKey, 0xa0)` over the identical 5-slot struct, and `types/PoolKey.sol` is
  normalized-identical to upstream; `AC-30` pins it.
- Pool-state slot derivation — Crane's `StateLibrary._getPoolStateSlot` hashes the same packed bytes
  with `keccak256` (via `BetterEfficientHashLib._hash`), so slots coincide; `AC-31` proves
  `pendingFees`/`previewRedeem` read the same values an independent oracle computes.
- `StateLibrary.getPositionInfo(manager, poolId, owner, tickLower, tickUpper, salt)` and
  `getFeeGrowthInside(manager, poolId, tickLower, tickUpper)` signatures and return tuples — identical
  to upstream as read; `AC-32` pins the fee-growth accounting.
- `TickMath` price/tick conversions — Crane's port differs in imports (`BitMath` from the uniswap
  tree, `CustomRevert` dropped) and the frozen upstream file declares `using CustomRevert for bytes4`
  while Crane's declares the errors inline; `AC-33` pins `getSqrtPriceAtTick` against independently
  computed vectors and pins the revert **data** of `InvalidTick`/`InvalidSqrtPrice`.
- `FullMath.mulDiv` — Crane's guard order differs from upstream's; `AC-34` is a differential test
  comparing both orders over a boundary set (including `denominator == 0`, `prod1 == 0`, and
  `denominator <= prod1`) and asserting identical results **and** identical revert data.
- `BalanceDelta` encoding (`type BalanceDelta is int256`, `amount0()`/`amount1()` packing) — Crane's
  `types/BalanceDelta.sol` is normalized-identical to upstream except the `SafeCast` import path.

**D-06** The import must use Crane's real `PoolManager` (`…/v4/PoolManager.sol`, constructor
`(address initialOwner)`, `NoDelegateCall` + transient-storage `Lock`) as the production v4 manager
in all hermetic tests. Tests must not mock, etch, or subclass the manager, and must not inject
storage.

**D-07** The import must not assume the manager's `settle()`/`take()`/`sync()`/`unlock()` semantics
carry over unchanged from upstream v4-core; the frozen baseline uses the **post-ERC6909Claims** API
(`settle()` with no currency argument, `take(currency,to,amount)`, `sync(currency)`), which Crane's
interface also declares (`interfaces/IPoolManager.sol:172,180,184`). Native settlement in
`WeirBase._pay` (`poolManager.settle{value: amount}()`) and ERC20 settlement
(`sync` → `transfer` → `settle`) must be proven against the real manager (`AC-20`, `AC-21`).

**D-08** Because upstream compiled with `viaIR=true` and this repo forbids `via_ir`, the import must
compile under the repo default profile with **no** profile change, and the implementing pass must
record whether the compiler emitted any stack-too-deep condition and how it was resolved **without**
enabling viaIR and without changing `foundry.toml` (the repo's stated remedy is structs/helper
frames; if such a restructure is required, it is a **deviation** requiring a recorded decision, and
it must be behavior-neutral and covered by the §9 test matrix).

**D-09** The import must not assert or test deployed-bytecode equality against the upstream build.
The PRD must state the compiler delta (0.8.26/800/viaIR/Cancun vs 0.8.35/1/no-viaIR) and treat
**source + ABI + arithmetic parity** as the acceptance target.

**D-10** The import must not pin `evm_version` or enable `via_ir`; if the compiler's default EVM
version for `solc 0.8.35` is insufficient for Crane's transient-storage `Lock` (`tstore`/`tload`),
that is a **blocking incompatibility to escalate**, not a license to edit `foundry.toml`. The
implementing pass must record the effective `evm_version` used.

### 5.3 OpenZeppelin routing

**D-11** The import must select **one** OZ source tree for all five OZ imports and record it. The
frozen baseline is v5.1.0-era. Two candidates exist in-repo and they are **not** interchangeable:

| Candidate | Pausable | SafeERC20 | ReentrancyGuard | Verdict |
|---|---|---|---|---|
| `@crane/contracts/external/openzeppelin-contracts/…` (package 4.9.6) | **v4-style** `require(!paused(), "Pausable: paused")` → string revert | 4.9.3 `_callOptionalReturn` | 5.5.0 namespaced | **Rejected by default**: changes `deposit`'s paused-revert data away from `EnforcedPause()` |
| `@crane/lib/openzeppelin-contracts/contracts/…` (**5.6.1**) | v5.3.0 `EnforcedPause()` / `ExpectedPause()` ✓ | 5.5.0 ✓ | 5.5.0 namespaced ✓ | **Recommended**, subject to D-12 |

**D-12** The recommended OZ routing is `@crane/lib/openzeppelin-contracts/contracts/…` (OZ 5.6.1),
because the upstream ABI in the manifest lists `EnforcedPause()`, `ExpectedPause()`,
`SafeERC20FailedOperation(address)`, `OwnableInvalidOwner(address)`,
`OwnableUnauthorizedAccount(address)`, and `ReentrancyGuardReentrantCall()` — v5 semantics. Using the
4.9.6-package tree would replace `EnforcedPause()` with a string revert, changing observable
behavior and the ABI. The adopting pass must record the chosen tree and treat the following as
**recorded deviations** (not silent): ReentrancyGuard v5.1.0 → v5.5/5.6 (ERC-7201 namespaced slot
instead of a sequential `_status` slot); `SafeERC20` v5.1.0 → v5.5.0 (adds `to.code.length == 0`
check and `SafeERC20FailedDecreaseAllowance`); `Address` v5.1.0 → v5.6.1 (`LowLevelCall` internals).

**D-13** Because the OZ `ReentrancyGuard` change moves the guard out of the sequential storage range,
the imported contract's **storage layout differs from the upstream deployment**: `WeirVaults`'s own
variables (`treasury`, `perfFeeBps`, `_vaults`, `sharesOf`, `allVaults`) shift by one slot relative to
the baseline. The import must record the post-import storage layout and must not claim layout
compatibility with the deployed instance. Direct slot reads of a live upstream deployment are
therefore invalid against the imported build.

**D-14** The import must not vendor OZ sources into `contracts/protocols/strategy/weir/`, must not
create a private OZ/v4 clone, and must not add a submodule or a global alias. Only the three domain
files are copied.

**D-15** The import must not add `SafeERC20`-style wrappers, permit lists, or token allowlists
(the repo's weird-token law forbids FoT/rebasing underlyings; Weir must make **no** claim of FoT or
rebasing support, and the PRD must say so explicitly).

**D-16** The import must not use `@crane/contracts/external/openzeppelin-contracts/…` for `Pausable`
or `SafeERC20` without a recorded, explicit decision to accept the revert-data change, because the
baseline's frozen ABI asserts the v5 error surface.

### 5.4 Canonical dependency decisions (to be stated in the final PRD)

| Dependency | Baseline | Decision | Deviation? |
|---|---|---|---|
| `IPoolManager`, `StateLibrary`, `TickMath`, `PoolKey`, `PoolId`, `Currency`, `BalanceDelta`, `IUnlockCallback` | upstream `v4-core` | Crane's ported v4 tree | Yes — port, not upstream; compatibility proven by `AC-30..AC-34` |
| `ModifyLiquidityParams`, `SwapParams` | nested in upstream `IPoolManager` | Crane free structs in `types/PoolOperation.sol` | Yes — `D-01`, encoding-identical |
| `FullMath`, `FixedPoint96`, `FixedPoint128` | upstream `v4-core` | Crane's uniswap tree | `FixedPoint96/128` identical; `FullMath` guard order differs → `AC-34` |
| `LiquidityAmounts` | baseline GPL file (3 domain file) | **Copy baseline file** | No substitution → `D-02` |
| OZ (5 files) | v5.1.0-era | OZ 5.6.1 tree under `@crane/lib/openzeppelin-contracts/` | Yes — `D-11..D-13` |
| `Position` (via `StateLibrary`) | upstream `BUSL-1.1` | Crane's `BSL-1.1` | Yes — license identifier change → `L-05` |
| `BetterEfficientHashLib` (via Crane `StateLibrary`) | not present upstream | AGPL-3.0-or-later enters closure | Yes — `L-04` |

---

## 6. License and provenance requirements (`L-xx`)

**L-01** The import must preserve the SPDX identifier of every copied file exactly:
`MIT` on `WeirVaults.sol` and `base/WeirBase.sol`; **`GPL-2.0-or-later`** on `libraries/LiquidityAmounts.sol`.

**L-02** The import must not relabel, scrub, relicense, or "clean-room" any file, and must not apply a
blanket MIT label to the package.

**L-03** The final PRD must state plainly that the imported package **mixes licenses**: two MIT
files, one GPL-2.0-or-later file, plus transitive `BUSL-1.1`/`BSL-1.1` (Position) and
`AGPL-3.0-or-later` (`BetterEfficientHashLib`, reached through Crane's `StateLibrary`), and MIT for
OZ 5.6.1.

**L-04 (AGPL contamination — blocking for release).** Because `WeirVaults.sol` links Crane's
`StateLibrary`, which imports `BetterEfficientHashLib` (**AGPL-3.0-or-later**), the deployed artifact's
dependency closure would contain AGPL-3.0-or-later code. The import may proceed for authoring and
testing, but the PRD must require a **license disposition decision before any release or external
distribution**, and must not assert that the artifact is MIT-clean, permissively licensed, or
"cleared". This is a documented upstream-routing consequence, not a Weir defect.

**L-05 (Position license identifier change).** Upstream `v4-core`'s `Position.sol` is `BUSL-1.1`;
Crane's ported `Position.sol` is `BSL-1.1`. The PRD must record that the route to Crane's tree changes
the Position license identifier, and must not present the closure as the upstream `BUSL-1.1` map.

**L-06 (GPL-2.0-or-later linking into an MIT-labelled contract — blocking for release).** Baseline
`WeirVaults.sol` is MIT and statically links the GPL-2.0-or-later `LiquidityAmounts.sol`. The
combination is therefore not MIT-only. The PRD must require an explicit license disposition before
release and must not represent the imported contract as MIT-licensed in its entirety. Replacing the
GPL library is **not** a permissible shortcut (see `D-02` and `X-11`).

**L-07** The import must record the full transitive license map of the **imported artifact's closure**
(the three domain files plus every file reachable through their imports), naming each file, its SPDX
identifier, and its source tree. The map must be produced from the actual resolved import graph, not
from the upstream manifest alone.

**L-08** The PRD must record the upstream provenance limit from §2.3 as a permanent caveat: content-
addressed verified source is the pin; no upstream repository, revision, test suite, or audit was
supplied or verified; the Sourcify record is registry metadata.

**L-09** The import must not add license headers to files it does not own or modify, and must not
remove or edit headers in shared trees (OZ, Crane's v4 tree) to resolve `L-04`/`L-05`/`L-06`.

**L-10** The PRD must state that license disposition is a **release gate**, not an authoring gate, and
that no legal clearance is implied by this document.

---

## 7. Behavioral contract requirements (`B-xx`)

Each entry states one observable behavior, cites its locator in the frozen snapshot, and is a
normative obligation on the import. Locators are `source-snapshot/sources/src/…` line numbers.

### 7.1 Vault lifecycle and identity

- **B-01** `createVault` (frozen `WeirVaults.sol.txt:145-157`) is permissionless; reverts
  `VaultExists()` if the pool already has a vault; reverts `PoolNotInitialized()` when the manager's
  `getSlot0(id)` returns `sqrtPriceX96 == 0`; sets `tickLower = TickMath.minUsableTick(tickSpacing)`
  and `tickUpper = TickMath.maxUsableTick(tickSpacing)`; appends to `allVaults`; emits
  `VaultCreated(id, key)`. `allVaults` is append-only with no removal path.
- **B-02** `deposit` auto-creates the vault when missing (`:167-168`) and therefore surfaces
  `PoolNotInitialized()` for an uninitialized pool through the deposit path.
- **B-03** `deposit` credits shares to `p.recipient` (`:176`) but pulls funds from `msg.sender`
  (`:170-171`) and refunds `msg.sender` (`:177-178`). Payer and recipient may differ; the **refund
  always goes to the payer**.
- **B-04** `deposit` reverts `ZeroAddress()` when `p.recipient == address(0)` (`:165-166`) — the payer
  may be any address; only the recipient is validated.
- **B-05** `deposit` reverts `Slippage()` when `shares < p.minShares` **or** `shares == 0` (`:174-175`).
- **B-06** `withdraw` reverts `NoVault()` for an unknown pool, `ZeroShares()` for `p.shares == 0`,
  `BadZap()` for `p.zapTo > 2`, `ZeroAddress()` for `p.recipient == address(0)` (`:187-193`), in that
  order.
- **B-07** `withdraw` debits `sharesOf[id][msg.sender]` (`:194`) — only the holder may withdraw; the
  **recipient of the payout need not be the holder**. Insufficient shares revert with the Solidity
  arithmetic panic (`0x11`), not a custom error.
- **B-08** `compound` is permissionless, requires an existing vault (`NoVault()`), takes **no**
  deadline and is **not** pausable (`:206-210`).
- **B-09** `transferShares` moves per-pool shares between addresses, reverts `ZeroAddress()` for a zero
  recipient, and underflows with panic `0x11` when the sender lacks shares (`:212-217`). It performs
  **no** vault-existence check, takes **no** deadline, is **not** pausable, and is **not**
  `nonReentrant`. Shares are per-`PoolId` and cannot move between pools.

### 7.2 Fees, shares, and the 1,000 locked shares

- **B-10** On the **first** deposit into a vault (`v.totalShares == 0`), the baseline requires
  `liq > MIN_SHARES` (else `ZeroShares()`), issues `shares = liq - MIN_SHARES`, and sets
  `v.totalShares = MIN_SHARES` **before** adding the issued shares, so the vault permanently carries
  **1,000 shares that no address owns** (`:249-256`, then `:264-265`). These locked shares are never
  redeemable and permanently dilute every later holder.
- **B-11** For every later deposit, `shares = (liq * v.totalShares) / v.liquidity` computed against the
  **pre-deposit** `v.liquidity` (`:257`, `:262-263`), i.e. liquidity-ratio issuance, with integer
  truncation toward zero.
- **B-12** The performance fee is `cut = fees * perfFeeBps / 10_000` on harvested fees only
  (`:335-336`); it is not charged on deposits or withdrawals. `setPerfFee` reverts `FeeTooHigh()` above
  `MAX_PERF_FEE_BPS = 1000`; `setPerfFee(0)` is legal. `setTreasury` reverts `ZeroAddress()` for the
  zero address. The treasury receives the cut directly from the manager via `_take` (`:337-338`).
- **B-13** `pendingFees` returns `(0,0)` when `v.liquidity == 0` (`:131`), otherwise
  `FullMath.mulDiv(feeGrowthInside - lastFeeGrowth, positionLiquidity, FixedPoint128.Q128)` computed
  inside `unchecked` (`:132-141`). It reports **pre-performance-fee** fees.
- **B-14** `pendingFees` and `_compound` use **different fee bases**: `pendingFees` derives from
  `getFeeGrowthInside` deltas, while `_compound` takes the **second** return value of
  `modifyLiquidity` (`feesAccrued`) (`:326-331`). The two can disagree.

### 7.3 Zap, balancing, and rounding

- **B-15** `deposit` with `p.zap == true` first runs `_balance` (`:240-241`, helper at `:365-389`),
  which values `amount0` in currency1 terms via two `FullMath.mulDiv`s against `sqrtPriceX96`, then
  swaps **half** the excess of the larger side (`x = (excess) / 2`) in the pool. Only **half** the
  imbalance is corrected — the residual ratio error is absorbed by the position's smaller side and the
  leftover becomes idle dust. If the computed `x == 0`, **no swap occurs** and the function returns
  `(0, 0, a0, a1)` unchanged (`:374`, `:378`).
- **B-16** The `_balance` branch direction is asymmetric in its arithmetic: the `amount0`-heavy branch
  computes the excess in currency0 units from `amount1`'s value (`:372`) while the `amount1`-heavy
  branch subtracts the currency1-valued `amount0` (`:376`). The exact `x` formulas must be preserved.
- **B-17** `_swap` uses **exact-input** semantics (`amountSpecified = -int256(amountIn)`) with the
  price limit at `MIN_SQRT_PRICE + 1` / `MAX_SQRT_PRICE - 1` (`:391-400`), so a thin pool can fill
  **partially** and yield a different output than the naive expectation.
- **B-18** `_deposit` subtracts a **two-unit cushion** from each side before computing liquidity
  (`a0 > 2 ? a0 - 2 : 0`, same for `a1`) (`:245-249`); `_compound` does the same for its re-added
  amounts (`:340-344`).
- **B-19** `previewRedeem` uses the **current** `sqrtPriceX96` and the vault's stored ticks, computes
  `liq = uint128((v.liquidity * shares) / v.totalShares)`, adds `idle * shares / v.totalShares`
  (`:117-128`), returns `(0,0)` when `v.totalShares == 0`, and **excludes pending fees** — as the
  baseline NatSpec states. It is a view only; it performs no swap, no cushion, and no rounding
  reconciliation against the actual withdrawal path.

### 7.4 Settlement, deltas, and native handling

- **B-20** `WeirBase._settle` pays a negative net with `_pay` and takes a positive net with `_take` to
  the given recipient (`:73-77`; `base/WeirBase.sol.txt:73-77`). A **positive** net in `_deposit`
  is credited to the **depositor** (`msg.sender` at deposit time), not to `p.recipient`
  (`WeirVaults.sol.txt:250-256`).
- **B-21** `_checkNative` requires `msg.value` to equal **exactly** the sum of the native legs
  (`base/WeirBase.sol.txt:50-54`); over- and under-payment both revert `BadNativeAmount()`. If both
  pool currencies are ERC20, `msg.value` must be exactly `0`.
- **B-22** Native currency is never pulled by `_pull` (the `isAddressZero()` early return at
  `base/WeirBase.sol.txt:44-48`); it arrives only as `msg.value`. ERC20 legs are pulled with
  `safeTransferFrom` from `msg.sender` and therefore require an allowance.
- **B-23** `_pay` settles native with `poolManager.settle{value: amount}()` and ERC20 with
  `sync(currency)` → `transfer` → `settle()` (`base/WeirBase.sol.txt:56-66`).
- **B-24** `_send` refunds with a raw `to.call{value: amount}("")` for native and reverts
  `NativeTransferFailed()` on failure, **without bubbling the callee's revert data**
  (`base/WeirBase.sol.txt:79-86`). ERC20 refunds use `safeTransfer`.
- **B-25** `checkDeadline` reverts `Expired()` only when `block.timestamp > deadline` — a deadline
  exactly equal to the block timestamp **passes** (`base/WeirBase.sol.txt:30-32`). `deposit` and
  `withdraw` use it; `compound` and `transferShares` do not.

### 7.5 Callback, ordering, and guard surfaces

- **B-26** `unlockCallback` is `onlyPoolManager` and reverts `NotPoolManager()` for any other caller
  (`WeirVaults.sol.txt:221-236`; `base/WeirBase.sol.txt:25-28`). It decodes
  `(Action, PoolId, bytes)`; `Action.COMPOUND` passes the raw `hookData` bytes as `inner`, whereas
  `DEPOSIT`/`WITHDRAW` pass `abi.encode`d parameter structs.
- **B-27** Ordering inside the callback is fixed: `_compound` runs **before** `_deposit` and **before**
  `_withdraw` (`:233-234`, `:236`). Deposit and withdrawal therefore always compound pending fees
  first, at the pre-operation pool price, and the deposit's liquidity is computed against the
  **post-compound** liquidity.
- **B-28** `nonReentrant` is on `deposit`, `withdraw`, and `compound` only (`:159-165`, `:186-193`,
  `:206`). A reentrant call to one of those from inside the callback reverts
  `ReentrancyGuardReentrantCall()`. `transferShares`, `createVault`, the views, and the admin setters
  are unguarded.
- **B-29** Only `deposit` carries `whenNotPaused` (`:162`). `withdraw`, `compound`, and
  `transferShares` succeed **while paused** — matching the baseline NatSpec ("Withdrawals work while
  paused").
- **B-30** `unlockCallback` does **not** carry `nonReentrant`; the only guard on it is
  `onlyPoolManager`. An ordinary nested `poolManager.unlock` (a manager that is already unlocked)
  fails with the manager's own `AlreadyUnlocked()`, and the baseline surfaces it unmodified.

---

## 8. Upstream risk register (`R-xx`) — characterize, do not repair

Each entry is a limitation of the pinned baseline. The import must **preserve** the behavior and add a
characterization test; the PRD must **not** authorize a fix, and no test may be written that demands a
safety property the source does not implement.

| ID | Limitation (with locator) | Observable effect | Characterization obligation |
|---|---|---|---|
| **R-01** | Performance fee computed from `modifyLiquidity`'s **`feesAccrued`** return value, which upstream's own interface docs warn "can be artificially inflated by a malicious actor" (`:326-331`; frozen `IPoolManager.sol.txt:142-160`) | A donation to the pool inflates `feesAccrued` → the vault may attempt to take a performance fee on value it never earned and to re-add liquidity backed by nothing; the resulting negative net must be settled by the vault, and the operation can revert | Characterize: donate to a pool with a Weir position, then `compound`; assert the exact revert (or exact success) and the resulting `idle0/idle1`, `v.liquidity`, and treasury balance, from an independently computed oracle |
| **R-02** | `pendingFees` computes `in0 - last0` inside `unchecked` (`:138-141`) | A decrease in fee growth wraps to a near-`2^256` value; `pendingFees` can report astronomically large fees | Characterize the wrap and record the reported value; do not assert a "safe" bound the source does not provide |
| **R-03** | `v.idle0 = uint256(int256(v.idle0) + net0)` — signed-to-unsigned cast of a possibly negative sum (`:357-358`) | If `net0 < -idle0`, the cast wraps and `idle0` becomes enormous; later withdrawals would claim dust the contract does not hold | Characterize the reachable path; assert the invariant the source actually maintains (`idle` converging to ≤ 2 per side after a successful compound) and the exact post-condition values |
| **R-04** | `_balance` swaps only **half** the excess (`:372-380`) | The position is left off-ratio; the smaller side caps liquidity and the remainder becomes idle dust, so the depositor's effective liquidity is strictly below the naive expectation | Characterize: assert the exact `used0/used1`, shares, and idle for a single-sided zap deposit, computed from an independent constant-product oracle |
| **R-05** | Exact-input swaps with a hard price limit (`:391-400`) | Thin pools can fill partially; the realized output differs from the naive expectation, and the remainder stays in the pool | Characterize with a deliberately thin pool; assert exact deltas, not approximate ones |
| **B-19`/`R-06`** | `previewRedeem` excludes pending fees, performs no swap, applies no cushion, and truncates | `previewRedeem` output can differ materially from the executed `withdraw` output | Characterize the **divergence** (both numbers, independently computed) and state that the baseline promises no preview parity; do **not** write a preview==execute assertion |
| **R-07** | 1,000 permanently unowned shares (`:249-256`, `:264-265`) and the corresponding stranded liquidity after a full withdrawal | The first depositor's effective ownership is `(liq - 1000) / liq`; after all holder shares are withdrawn, ~1,000 units of liquidity and the 1,000 shares remain permanently locked | Characterize: assert `totalShares`, `v.liquidity`, and the residual locked position after a full withdrawal |
| **R-08** | `shares = (liq * v.totalShares) / v.liquidity` divides by `v.liquidity` whenever `v.totalShares != 0` (`:257`, `:262`) | A vault whose liquidity reaches 0 while `totalShares != 0` would divide by zero (panic `0x12`) on the next deposit | Characterize whether the baseline can reach `v.liquidity == 0` with `v.totalShares != 0` (the 1,000 locked shares make the state non-empty) and record the exact outcome |
| **R-09** | `uint128((v.liquidity * shares) / v.totalShares)` casts down (`:120`, `:280`) | Values above `2^128` truncate silently; `previewRedeem` for oversized `shares` returns a wrapped number | Characterize the truncation boundary; no repair |
| **R-10** | `share`/`total` ratios truncate toward zero at every step (`:262`, `:280-283`, `:118-124`) | Repeated small operations leak value to the pool and to the residual locked shares | Characterize with a repeated small-deposit/withdraw sequence; assert the exact final ledger |
| **R-11** | `_send` for native swallows the callee's revert reason (`:79-86`) | A failing native recipient yields `NativeTransferFailed()` with no underlying data; a recipient that reverts on receive blocks refunds | Characterize both the revert selector and the absence of bubbled data |
| **R-12** | `transferShares` has no vault-existence check and no `nonReentrant` (`:212-217`) | Shares of a non-existent pool can be moved if the sender's balance allows; a reentrant `transferShares` during a callback is unguarded | Characterize the unguarded surface; state plainly that the baseline does not guard it |
| **R-13** | `allVaults` grows without bound and has no removal path (`:156`, `:82`) | Gas cost of the array getter grows with the number of vaults | Low severity; characterize only the length/ordering invariant |
| **R-14** | `unlockCallback` falls through to the withdraw branch for any action value that is neither `COMPOUND` nor `DEPOSIT` (`:221-236`) | Only reachable through a malicious/incorrect manager; the manager is trusted | Document; test the `onlyPoolManager` boundary, not the fall-through |
| **R-15** | `pendingFees` and `_compound` use different fee bases (B-14) | The fee figure shown to users can differ from the fee actually harvested | Characterize both values for the same state |

---

## 9. Explicitly excluded improvements (`X-xx`)

These are **not** in this baseline. Each would change behavior or scope and therefore requires a
separate, explicitly approved PRD. The import must not implement, stub, or "prepare for" any of them.

- **X-01** ERC20/ERC4626 wrapper or transferable share token.
- **X-02** A `RateProvider` or any adapter that makes the vault's rate queryable by other IndexedEx code.
- **X-03** Diamond / Standard Exchange conversion, `DFPkg` packaging, `Component_FactoryService` wiring.
- **X-04** IndexedEx manager/registry integration, vault-registry registration, or `new`-in-production changes.
- **X-05** Removing the performance fee, or changing `perfFeeBps` default/cap semantics.
- **X-06** Removing the 1,000 locked genesis shares (the "dead share" removal).
- **X-07** A hook-only deposit path for already-unlocked pools.
- **X-08** A strict single-token guarantee (e.g., guaranteeing a one-token exit), which the baseline
  does not provide — `previewRedeem` and `withdraw` may return both currencies.
- **X-09** A new swap simulator, an off-chain quoting service, or any TWAP/price-adapter dependency.
- **X-10** Gas/size optimization, `unchecked` refactors, or `viaIR`-driven restructuring.
- **X-11** Replacing the baseline GPL `LiquidityAmounts` with Crane's MIT `LiquidityAmounts` (or any
  other same-named implementation). This changes overflow revert data and rounding — see `D-02`.
- **X-12** Fixing any item in §8. Each is a *characterization target*, not a work item.
- **X-13** Any change to the frozen snapshot files under `docs/research/…/source-snapshot/` — they are
  research references, not production Solidity, and are not compiled.

---

## 10. Acceptance criteria (`AC-xx`)

Format: precondition → action → exact expected result. Expected values are stated as formulas,
selectors, or invariants — never as runtime numbers this document did not observe. Every AC is a
hermetic test unless marked otherwise.

### 10.1 Import fidelity

| ID | Precondition | Action | Exact expected result |
|---|---|---|---|
| AC-01 | Import committed | `sha256sum` of the three copied files vs the frozen manifest | Byte-identical to the frozen texts **except** for the §5 deviations; the deviation ledger lists every differing line and nothing else |
| AC-02 | Import committed | Read the first two lines of each copied file | SPDX identifiers `MIT`, `MIT`, `GPL-2.0-or-later`; pragmas `^0.8.26`, `^0.8.26`, `^0.8.24` |
| AC-03 | Import committed | Compare the imported contract's ABI to the manifest ABI | Same function/method set, same argument order/types, same struct field order, same event topics and payloads, same error names and parameters |
| AC-04 | Import committed | `forge inspect <WeirVaults> abi` | Contains no function absent from the manifest ABI (e.g. no `totalSupply`, `balanceOf`, `transfer`, `approve`) |
| AC-05 | Import committed | Grep the import for the excluded features | No `ERC4626`, `ERC20`, `RateProvider`, `registerVault`, `registry`, `create3`, `diamond`, `Facet` token in the copied files |

### 10.2 Vault lifecycle

| ID | Precondition | Action | Exact expected result |
|---|---|---|---|
| AC-06 | Real manager; pool initialized; no vault | `createVault(key)` | `vault(id).exists == true`; `tickLower == TickMath.minUsableTick(tickSpacing)`; `tickUpper == TickMath.maxUsableTick(tickSpacing)`; `vaultCount() == 1`; `allVaults(0) == id`; `VaultCreated(id, key)` emitted |
| AC-07 | Vault exists | `createVault(key)` again | Revert `VaultExists()` |
| AC-08 | Pool not initialized (fresh manager, no `initialize`) | `createVault(key)` | Revert `PoolNotInitialized()` |
| AC-09 | Pool initialized, no vault | `deposit(...)` | Vault auto-created; `vaultCount() == 1`; `VaultCreated` emitted; then the deposit's own events |
| AC-10 | Vault exists | `deposit` with `p.recipient == address(0)` | Revert `ZeroAddress()` |
| AC-11 | Pool initialized, no vault | `deposit` into an uninitialized pool | Revert `PoolNotInitialized()` |

### 10.3 Deposit semantics

| ID | Precondition | Action | Exact expected result |
|---|---|---|---|
| AC-12 | Real manager; initialized pool; two funded ERC20 accounts | Two-sided `deposit` with `zap=false`, `minShares=0`, `deadline = now` | `Deposited(id, recipient, shares, used0, used1)` with `shares` equal to `getLiquidityForAmounts(sqrtP, sqrt(lower), sqrt(upper), a0-2, a1-2)` computed by the test's own oracle; `sharesOf[id][recipient] == shares`; the depositor's token deltas equal `used0`/`used1`; the manager's currency delta for both currencies closes to zero |
| AC-13 | Same, with `p.minShares = shares + 1` | `deposit` | Revert `Slippage()` |
| AC-14 | Same, with `p.deadline = block.timestamp - 1` | `deposit` | Revert `Expired()` |
| AC-15 | Same, with `p.deadline = block.timestamp` | `deposit` | **Succeeds** (`checkDeadline` uses `>`, not `>=`) |
| AC-16 | Native pool (currency0 = address(0)); `msg.value` != native leg | `deposit` | Revert `BadNativeAmount()` — for both over- and under-payment |
| AC-17 | ERC20-only pool; `msg.value = 1` | `deposit` | Revert `BadNativeAmount()` |
| AC-18 | Vault exists; `p.recipient = B`, payer = `A` | `deposit` | `sharesOf[id][B]` increases; `A`'s balance decreases by exactly `used0`/`used1`; **no** refund is sent to `B`; any refund goes to `A` |
| AC-19 | Real manager; vault exists | `deposit` where the oracle-computed liquidity is `<= 1000` on a fresh vault | Revert `ZeroShares()` |
| AC-20 | Vault exists; paused by owner | `deposit` | Revert `EnforcedPause()` (v5 selector) — **not** a `"Pausable: paused"` string (this AC is the guard on `D-11`/`D-12`) |
| AC-21 | Vault exists; paused by owner | `withdraw` | **Succeeds** (withdrawals work while paused) |
| AC-22 | Vault exists; `msg.sender` holds shares | `withdraw` with `p.recipient = C` | `C` receives the payout; `msg.sender`'s share balance decreases; `Withdrawn(id, msg.sender, shares, out0, out1)` — the event's `user` field is the **withdrawer**, not the recipient |
| AC-23 | Vault exists | `withdraw` with `p.shares == 0` | Revert `ZeroShares()` |
| AC-24 | Vault exists | `withdraw` with `p.zapTo == 3` | Revert `BadZap()` |
| AC-25 | Vault exists | `withdraw` with `p.recipient == address(0)` | Revert `ZeroAddress()` |
| AC-26 | Vault exists; holder's balance < `p.shares` | `withdraw` | Panic `0x11` (arithmetic underflow), not a custom error |
| AC-27 | Unknown pool id | `withdraw` | Revert `NoVault()` |

### 10.4 Withdrawal, zap, and preview

| ID | Precondition | Action | Exact expected result |
|---|---|---|---|
| AC-28 | Vault with liquidity; holder | `withdraw` with `zapTo=0`, `min0=min1=0` | `out0`/`out1` equal the oracle's `getAmountsForLiquidity` result for the withdrawn liquidity, plus the proportional idle; the manager's currency delta closes to zero; the recipient's balances increase by exactly `out0`/`out1` |
| AC-29 | Same | `withdraw` with `zapTo=1` | All value delivered as currency0: the currency1 leg is swapped in-pool via exact input; `out1 == 0`; the swap's price impact and any residual are reflected exactly |
| AC-30 | Same | `withdraw` with `zapTo=2` | Mirror of AC-29: `out0 == 0`, all value as currency1 |
| AC-31 | Vault with liquidity | `withdraw` with `min0` above the realized `out0` | Revert `Slippage()` |
| AC-32 | Vault with liquidity | `previewRedeem(id, shares)` | Equals the oracle's `getAmountsForLiquidity(currentSqrtP, …)` plus proportional idle, and **excludes** pending fees; a companion case asserts the value differs from the executed withdrawal when fees are pending (divergence is the contract under test) |
| AC-33 | Vault with liquidity and pending fees | `pendingFees(id)` | Equals `mulDiv(feeGrowthInside - lastFeeGrowth, positionLiquidity, Q128)` from the test's own fee-growth oracle; returns `(0,0)` when `v.liquidity == 0` |

### 10.5 Composition, fees, and idle accounting

| ID | Precondition | Action | Exact expected result |
|---|---|---|---|
| AC-34 | Vault with liquidity and unharvested fees | `compound(key, "")` | `Compounded(id, fees0, fees1, liquidityAdded)`; treasury receives exactly `fees * perfFeeBps / 10_000` per side; `v.liquidity` increases by the oracle-computed `liq`; `v.idle0`/`idle1` equal the oracle's residual (≤ 2 per side on the success path); the manager's delta closes to zero; `v.lastCompound == uint64(block.timestamp)` |
| AC-35 | Vault with liquidity; `perfFeeBps = 500` | `compound` | Treasury cut is exactly `floor(fees * 500 / 10_000)` per side |
| AC-36 | Vault with liquidity; `perfFeeBps = 0` | `compound` | Treasury cut is `0`; all fees re-enter the position |
| AC-37 | Owner | `setPerfFee(1001)` | Revert `FeeTooHigh()`; `setPerfFee(1000)` succeeds and emits `PerfFeeSet(1000)` |
| AC-38 | Owner | `setTreasury(address(0))` | Revert `ZeroAddress()`; `setTreasury(T)` succeeds and emits `TreasurySet(T)` |
| AC-39 | Non-owner | `setTreasury`, `setPerfFee`, `pause`, `unpause` | Each reverts `OwnableUnauthorizedAccount(caller)` |
| AC-40 | Vault exists | `compound` on an unknown pool | Revert `NoVault()` |

### 10.6 Shares, transfers, and callbacks

| ID | Precondition | Action | Exact expected result |
|---|---|---|---|
| AC-41 | Holder `A` with `s` shares | `transferShares(id, B, s)` | `sharesOf[id][A] == 0`, `sharesOf[id][B] == s`, `SharesTransferred(id, A, B, s)` emitted |
| AC-42 | Holder with fewer shares | `transferShares(id, B, s+1)` | Panic `0x11` |
| AC-43 | Any caller | `transferShares(id, address(0), n)` | Revert `ZeroAddress()` |
| AC-44 | Any non-manager | `unlockCallback(data)` | Revert `NotPoolManager()` |
| AC-45 | Vault exists | `deposit` where the oracle-computed `liq <= 1000` on a **non-first** deposit | `shares == 0` → the baseline's own `ZeroShares()` path (`:256`) fires — pin which branch is taken |
| AC-46 | Fresh vault, first deposit | `deposit` with oracle `liq = L > 1000` | `sharesOf[id][recipient] == L - 1000`; `vault(id).totalShares == L`; the 1,000-share gap is owned by no address |
| AC-47 | Second deposit into a vault | `deposit` | `shares == floor(liq * totalShares / v.liquidity)` computed against the **pre-deposit** `v.liquidity`, from the test's own oracle |

### 10.7 Compatibility and dependency gates

| ID | Precondition | Action | Exact expected result |
|---|---|---|---|
| AC-48 | Real Crane `PoolManager` | `PoolId` derivation vs `keccak256(abi.encode(key))` | Identical for the test's pool keys (proves Crane's port matches upstream pool identity) |
| AC-49 | Real manager; vault with position | `pendingFees` and `previewRedeem` vs an oracle that reads the manager's position state through the **same** slot scheme | Identical values (proves Crane's `StateLibrary` slot derivation equals upstream's `keccak256(abi.encodePacked(...))` despite the `BetterEfficientHashLib` route) |
| AC-50 | Frozen upstream `TickMath` vectors | `getSqrtPriceAtTick` at the tick boundaries | Matches independently computed Q64.96 values; out-of-range ticks revert with the **same revert data** as upstream's `InvalidTick`/`InvalidSqrtPrice` encoding (this is the check that Crane's inline errors match upstream's `CustomRevert` encoding) |
| AC-51 | Boundary inputs: `denominator == 0`, `prod1 == 0`, `denominator <= prod1`, `prod0` overflow | `FullMath.mulDiv` under Crane's guard order vs the upstream guard order | Identical results **and** identical revert data for every case (guards `D-05`) |
| AC-52 | Real manager; native pool | ERC20 `settle` path (`sync` → `transfer` → `settle`) and native `settle{value:}` path | Both settle; the manager's currency delta closes to zero in each case; no residual `CurrencyNotSettled` |
| AC-53 | Compiled artifact | Storage layout of the imported contract | Recorded and diffed against the baseline layout expectation; the known one-slot shift from the OZ `ReentrancyGuard` change (`D-13`) is documented, not silently accepted |
| AC-54 | Compiled artifact | `forge inspect <WeirVaults> storage-layout` / `abi` | Layout and ABI recorded in the import's evidence file; **no** claim of deployed-bytecode equality (`D-09`) |
| AC-55 | Full import | `forge build` under the default profile | Succeeds with the repo's default `solc 0.8.35` / `optimizer_runs 1` / `via_ir=false`; no `foundry.toml` edit was needed or made |

### 10.8 Risk characterization (`R-xx`)

| ID | Scenario | Exact expected result (characterization) |
|---|---|---|
| AC-56 | Donate to the pool, then `compound` | Record the exact revert selector (or success), plus `v.liquidity`, `idle0/idle1`, treasury balance, and manager delta closure — computed from an independent oracle (`R-01`) |
| AC-57 | Force `feeGrowthInside < lastFeeGrowth` and read `pendingFees` | Record the reported (wrapped) value; assert the wrap, not a safe bound (`R-02`) |
| AC-58 | Drive `net0 + idle0 < 0` in `_compound` | Record `idle0` after the operation and whether the uint256 wrap occurs (`R-03`) |
| AC-59 | Single-sided zap deposit | Record `used0`, `used1`, shares, and idle; assert the half-excess heuristic's exact effect (`R-04`, `B-15`) |
| AC-60 | Deliberately thin pool, zap deposit | Record the realized swap output and the resulting shares; assert partial-fill behavior (`R-05`) |
| AC-61 | Vault with pending fees | `previewRedeem` vs executed `withdraw` — record both, assert they differ, and assert the baseline's documented exclusions (`R-06`) |
| AC-62 | Full withdrawal by the only holder | Record `totalShares`, `v.liquidity`, the residual position, and the permanently locked 1,000 units (`R-07`) |
| AC-63 | Vault at minimal liquidity; next deposit | Record whether a division by zero (panic `0x12`) is reachable and under what state (`R-08`) |
| AC-64 | `previewRedeem` with oversized `shares` | Record the truncated result (`R-09`) |
| AC-65 | Repeated small deposit/withdraw sequence | Record the exact final ledger of shares, liquidity, idle, and pool balances (`R-10`) |
| AC-66 | Native refund to a contract that reverts on receive | Revert `NativeTransferFailed()` with **no bubbled inner data (`R-11`) |
| AC-67 | Reentrant `transferShares` from a hostile token/hook during a callback | Succeeds (no guard) — characterize the unguarded surface (`R-12`) |
| AC-68 | Same state, `pendingFees` vs the fee actually harvested by `compound` | Record both; assert the bases differ (`R-15`, `B-14`) |

### 10.9 Fork gate (local-only, separate from hermetic CI)

| ID | Precondition | Action | Exact expected result |
|---|---|---|---|
| AC-69 | `FOUNDRY_PROFILE=fork`, RPC configured for an **available** chain, pinned block | Run the fork suite | Only parity that can be computed from matching inputs is asserted: same inputs → same outputs vs the **same** live deployment with an equivalent starting position, inventory, fees, and roles. Raw comparisons between unrelated live states are invalid |
| AC-70 | Chain `4663` RPC unavailable (current repo state) | Attempt the deployed-instance comparison | **Skip with a recorded reason** in the suite's NatSpec ("chain 4663 not in `[rpc_endpoints]`; deployed instance not reachable"), not a fabricated result |
| AC-71 | Fork suite present | `forge test` under the **default** profile | The fork suite is **not** executed by the default profile and CI does not depend on RPC or secrets |

---

## 11. Test topology and content requirements (`T-xx`)

**T-01** Production source lives at `contracts/protocols/strategy/weir/` with upstream's relative
layout (`base/`, `libraries/`).

**T-02** Hermetic tests live at `test/foundry/spec/protocols/strategy/weir/`, mirroring the
production tree (the brief's path). Fork tests live at `test/foundry/fork/` and are excluded from the
default profile.

**T-03** A dedicated `TestBase_WeirVaults` must own all setup: deploy the **real** Crane
`PoolManager` (`new PoolManager(address(this))`, as `UniswapV4PortedPoolManagerParity_Fork.t.sol:48`
does), deploy the **real** imported `WeirVaults`, initialize pools, and fund ERC20/native accounts.
The SUT must never be mocked, etched, subclassed, or storage-injected.

**T-04** The TestBase must extend the repo's gold ladder. `CraneTest` is the top of the available
ladder (no `IndexedexTest` exists in this repo). `CraneTest` is AGPL-3.0-or-later and its `setUp()`
runs `InitDevService.initEnv(address(this))`, which deploys diamond/DFPkg infrastructure that is
**unrelated product wiring** for a standalone upstream vault. The adopting pass must therefore choose
one of: (a) extend `CraneTest` and accept the unrelated init (closest to the repo ladder), or
(b) extend `forge-std/Test` directly and record the deviation from LR-7's gold chain with its
justification (this is the brief's "dedicated `TestBase_WeirVaults`" allowance). The choice and the
reason must appear in the import's evidence file. Test files inherit AGPL-3.0-or-later from
`CraneTest` — acceptable, since test sources are not distributed as production artifacts; if (b) is
chosen, the test file's SPDX must be stated.

**T-05** The TestBase must reuse Crane's existing v4 test infrastructure rather than reinventing it:
`…/v4/hooks/public/dependencies/v4-core/test/PoolTestBase.sol`, `PoolModifyLiquidityTest.sol`,
`PoolSwapTest.sol`, `utils/Deployers.sol`, `utils/CurrencySettler.sol`. No new v4 harness may be
written when these cover the need.

**T-06** The TestBase must provide mintable ERC20 harness tokens and a native-currency account.
Harness doubles are permitted **outside** the SUT (mintable ERC20, reentrancy token, fee-on-transfer
token for limitation characterization). The suite must make **no** claim that Weir supports
fee-on-transfer or rebasing tokens; the repo's weird-token law forbids FoT/rebasing underlyings
anyway.

**T-07** Every test must assert **exact** values: balances, share ledger, vault struct fields,
manager currency-delta closure per currency, event topics and payloads, revert selectors/panic
codes/string data, `callback` provenance (`msg.sender == poolManager` for `unlockCallback`), and
complete rollback (including transfers and refunds) after every revert.

**T-08** Expected values must come from an **independent oracle** implemented in the test —
closed-form Uniswap math computed in the test with documented constants, or a separately maintained
reference implementation — never from calling the SUT or the SUT's own helpers. The oracle must not
import the library under test for the quantity it is verifying; where the oracle necessarily mirrors
production math (e.g. `getLiquidityForAmounts`), the suite must additionally pin **hand-checked
vectors** so a shared bug cannot pass both sides.

**T-09** The suite must include deterministic fuzzing over user, pool, amount, tick-spacing, and
`perfFeeBps` dimensions, and an invariant campaign asserting: manager currency deltas close to zero
after every successful operation; `v.totalShares >= sum(sharesOf)`; `v.liquidity` and `v.idle0/1` are
non-negative as `uint256` and non-wrapped; `vaultCount() == allVaults.length` and every `allVaults`
entry exists. Invariants must be stated as invariants of the baseline — not of an idealized vault.

**T-10** The suite must cover, at minimum, the scenario families named in the brief and §7:
multiple pools; full-range ticks with salt-zero position ownership; the 1,000 locked genesis shares;
default 500 bps and the 1,000 bps cap; liquidity-ratio issuance; idle claims; separate payer vs
recipient; compound ordering; the two-unit cushion; signed deltas and rounding; each of the three
withdraw zap choices; fees at zero and at nonzero liquidity; the `uint64` timestamp; preview vs
executed withdrawal; native handling; pausing affecting deposit only; transferable per-pool
non-ERC20 balances; the absence of an arbitrary full-consumption guarantee; and ordinary nested-unlock
failure.

**T-11** The suite must include the callback/guard matrix: `unlockCallback` from a non-manager
(`NotPoolManager()`); reentrant `deposit`/`withdraw`/`compound` from inside the callback
(`ReentrancyGuardReentrantCall()`); reentrant `transferShares` (unguarded — characterized, not
blocked); `pause`/`unpause` authority matrix; `setTreasury`/`setPerfFee` authority matrix; and
`checkDeadline` boundaries (`== now` passes, `- 1` reverts `Expired()`).

**T-12** The suite must include a hostile-peripheral set: a token whose `transfer`/`transferFrom`
returns `false` (exercising `SafeERC20FailedOperation(address)`), a receiver that reverts on native
receive (exercising `NativeTransferFailed()` with no bubbled data), a token with a fee, and a
re-entrant receiver — used to characterize limitations, and never to assert a fix.

**T-13** The fork gate must live under `test/foundry/fork/`, run only under `FOUNDRY_PROFILE=fork`,
use a **pinned chain and block** with the provenance recorded in the test's NatSpec, and never be
reachable from hermetic CI. It must not depend on RPC secrets in the default profile.

**T-14** The suite must not contain any test asserting ERC20 compliance, ERC4626 semantics, NAV
safety, a guaranteed single-token exit, or preview==executed-withdrawal parity. Those are
baseline-absent properties and asserting them would manufacture a failing test against faithful
source.

---

## 12. Reproducible validation commands (`V-xx`)

Proposed commands for the implementing pass. **None were run in this contribution** (the brief
forbids builds/tests in the authoring phase). The commands follow the repo's artifact workflow and
profile law.

**V-01** Confirm the compiler/toolchain posture before anything else, without editing config:

```bash
forge config --json | jq '{solc, optimizer_runs, via_ir, evm_version, src, test, cache_path, out}'
```

Expect `via_ir: false`, `optimizer_runs: 1`, `solc 0.8.35`, `cache_path: cache_forge`, `out: out`,
`src: contracts`, `test: test/foundry/spec`. Record the effective `evm_version` (`D-10`).

**V-02** Plan the targeted compile (no compilation, no writes):

```bash
python3 scripts/forge-artifacts.py plan contracts/protocols/strategy/weir/WeirVaults.sol \
  --test-root test/foundry/spec/protocols/strategy/weir
```

**V-03** Build the import and refresh its runtime artifacts, then run the Weir suite:

```bash
python3 scripts/forge-artifacts.py build contracts/protocols/strategy/weir/WeirVaults.sol \
  --consumer 'test/foundry/spec/protocols/strategy/weir/**/*.t.sol'

python3 scripts/forge-artifacts.py test \
  contracts/protocols/strategy/weir/WeirVaults.sol \
  contracts/protocols/strategy/weir/base/WeirBase.sol \
  contracts/protocols/strategy/weir/libraries/LiquidityAmounts.sol \
  --test-root test/foundry/spec/protocols/strategy/weir -- -vv
```

**V-04** Full-build fallback (never deletes `out/` or `cache_forge/`, never enables `via_ir`):

```bash
forge build
forge test --match-path 'test/foundry/spec/protocols/strategy/weir/**' -vv
```

**V-05** Fork gate, local-only:

```bash
FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/**/*Weir*' -vv
```

Requires `ALCHEMY_KEY` (or another configured endpoint) and a pinned block; the suite must skip with
a recorded reason when chain `4663` is unreachable (`AC-70`).

**V-06** Evidence capture (append to the import's evidence file — no production edits):

```bash
forge inspect contracts/protocols/strategy/weir/WeirVaults.sol:WeirVaults abi
forge inspect contracts/protocols/strategy/weir/WeirVaults.sol:WeirVaults storage-layout
sha256sum contracts/protocols/strategy/weir/WeirVaults.sol \
          contracts/protocols/strategy/weir/base/WeirBase.sol \
          contracts/protocols/strategy/weir/libraries/LiquidityAmounts.sol
```

**V-07** Constraints the implementing pass must not violate: no `foundry.toml` edit; no new profile;
no `via_ir`; no deletion of `out/`/`cache_forge/`; no `remappings.txt` edit; no submodule; no
`git` commit as part of this import; no dependency installation. `forge`/`solc` cold compiles in this
monorepo commonly take 20–40+ minutes with little output — **wait for process exit**; never kill a
compile for appearing idle.

**V-08** In a fresh worktree, seed `cache_forge/` and `out/` from a warm checkout before the first
compile (repo law), e.g. `rsync -a "${REPO}/cache_forge/" "${WT}/cache_forge/"` and
`rsync -a "${REPO}/out/" "${WT}/out/"`.

**V-09** The import's evidence file must record, verbatim: the compiler settings used; the effective
`evm_version`; the three file SHA-256s and their diff against the frozen snapshot; the resolved
import graph with each file's SPDX identifier; the storage layout and ABI dumps; the exact test
commands and their exit status; and the §2.3 provenance limits.

**V-10** The import must not claim release readiness. Release additionally requires the license
disposition in `L-04`/`L-06` and, per the repo's deployment law, a separate authorized deployment
path. This PRD authorizes neither.

---

## 13. Acceptance gate summary (what "done" means for the import)

1. The three files exist at the specified path, with the enumerated deviations only (`F-01..F-03`,
   `AC-01..AC-03`).
2. The build succeeds under the repo default profile with no config edit (`D-08`, `AC-55`).
3. Every `AC-xx` in §10 has a corresponding test; every `R-xx` in §8 has a characterization test that
   asserts the **baseline** behavior, not a fixed behavior (`T-07..T-14`).
4. The two blocking compatibility gaps are closed by the enumerated migrations, not by symbol
   substitution (`D-01`, `D-02`).
5. The license map (§6) and the provenance limits (§2.3) are recorded in the import's evidence file.
6. The fork gate either passes on an available chain with pinned provenance or records its
   unavailability; no result is fabricated (`AC-69..AC-71`).

---

## 14. Questions the coordinator should carry into synthesis

1. **OZ tree selection.** §5.3 recommends the OZ 5.6.1 tree under `@crane/lib/openzeppelin-contracts/`
   to preserve the upstream v5 error surface (`EnforcedPause()`, `SafeERC20FailedOperation(address)`),
   at the cost of a recorded ReentrancyGuard storage-layout shift. The repo's dominant root
   convention is `@crane/contracts/external/openzeppelin-contracts/…`, which is the **4.9.6-package**
   tree with v4-style `Pausable`. Which becomes the recorded decision? (`D-11`, `D-12`)
2. **License gates.** `L-04` (AGPL via `BetterEfficientHashLib` through Crane's `StateLibrary`) and
   `L-06` (GPL-2.0-or-later `LiquidityAmounts` linked into an MIT-labelled contract) are release
   blockers, not authoring blockers. Confirm they are carried as such.
3. **TestBase ladder.** `T-04` offers two options because `CraneTest`'s diamond-factory init is
   unrelated wiring for a standalone vault. Which is recorded?
4. **Chain 4663 fork.** The deployed upstream instance lives on a chain with no configured RPC
   endpoint. Confirm the fork gate is scoped to an available chain with the deployed-instance
   comparison explicitly recorded as unavailable (`AC-70`).
5. **Deviation ledger.** `D-01` and `D-02` are the only permitted source-text deviations. Confirm
   that the final PRD enumerates them (and only them) as approved deviations.

---

## 15. Self-assessment of this contribution

- **Strongest evidence**: the two blocking compile gaps (`D-01` free `PoolOperation` structs,
  `D-02` incomplete V4 `LiquidityAmounts` API) are derived from reading the frozen call sites
  against the actual Crane interface and library files; the `previewRedeem` dependency on
  `getAmountsForLiquidity` makes `D-02` unavoidable.
- **Strongest risk flagged**: `R-01` — the performance fee is computed from `modifyLiquidity`'s
  `feesAccrued` return, which upstream's own interface documentation warns is donation-inflatable.
  That is a characterization target, not a fix.
- **Weakest area / most likely revision point**: the OZ tree selection (`D-11`/`D-12`) and its
  storage-layout consequence (`D-13`) depend on a repo-level routing decision I did not make; and
  the exact revert-data equivalence between upstream's `CustomRevert`-based errors and Crane's
  inline errors is asserted as a **test obligation** (`AC-50`) rather than as a verified fact,
  because I did not execute code.
- **Not done, deliberately**: no build, test, deploy, install, git operation, production copy, peer
  reading, delegation, or external message. No runtime number in this document is presented as
  observed.

This contribution is an input to the coordinator's synthesized PRD. It does not authorize
implementation.
