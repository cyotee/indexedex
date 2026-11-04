apply_patch was not active in this session, so no file was written; per the boundary, the complete feedback is inline below.

# Feedback — Weir source-import PRD, draft r1

**Member:** minimax · **Round:** single advisory on the coordinator's consolidated draft (`pairtoken-weir-source-import-prd-20261029-01a18660-r1`)
**Sources read by me:** the consolidated draft, the four member originals, the coordinator's source notes, the frozen source snapshot (`WeirVaults`, `WeirBase`, vendored `LiquidityAmounts`, frozen `IPoolManager`), the canonical CPM/Port sources, the repo's OpenZeppelin v5 tree, `foundry.toml`, `remappings.txt`, `ASSISTANT_*.md`. Peer feedback was not read.

---

## Disposition

**SUPPORT WITH CORRECTIONS.**

The draft is faithful, implementable, and materially better than my own original on the two points where my original was wrong (the performance-fee basis and chain-4663 RPC availability). Its load-bearing numeric anchors F0/F1/F2/F3 are not asserted — I recomputed them from the frozen vendored library and the frozen compound routine by exact integer arithmetic, and every one reproduces. The import route (versioned OpenZeppelin v5 tree), the retention of the vendored `LiquidityAmounts`, the five-site `PoolOperation` struct migration, the "first return = `callerDelta`" rule, the explicit-cast characterization, and the native-sync characterization are all correct and are the right calls for a source import.

The corrections below are precision and implementability, not redesign. None requires reinstating a behavior-changing dependency upgrade, and none asserts a safety property the import does not have. The highest-value one is the import-manifest shape (C1): the frozen files import `v4-core/src/...` and `@openzeppelin/contracts/...`, and both specifier shapes need a *path-level* rewrite, not a symbol-name substitution — the failure mode the coordinator explicitly warned about.

---

## Material corrections

### C1 — WI-03 import manifest: pin path-level rewrites for every external specifier (material, implementability)

**Required:** WI-03's manifest must enumerate, per frozen file, the exact target path in this repo, and must state the two non-obvious rewrites explicitly:

1. **Canonical v4: drop the `src/` segment.** The frozen vendored library imports `v4-core/src/libraries/FullMath.sol` and `v4-core/src/libraries/FixedPoint96.sol` (verified, frozen `src/libraries/LiquidityAmounts.sol.txt` lines 4–5), and the frozen source's other external imports use the same `v4-core/src/...` shape (`types/Currency.sol`, `interfaces/IPoolManager.sol`, `interfaces/callback/IUnlockCallback.sol`, `types/PoolId.sol`). The canonical port in this repo has **no `src/` level** (e.g. `@crane/contracts/protocols/dexes/uniswap/v4/libraries/FullMath.sol`). A symbol-name-only substitution leaves `v4-core/src/...` unresolvable.
2. **OpenZeppelin v5 tree: drop the `contracts/` segment.** The frozen files import `@openzeppelin/contracts/access/Ownable2Step.sol` (and the `token/ERC20/...` family). The versioned tree in this repo is `lib/crane/contracts/external/openzeppelin-contracts-v5/` with layout `access/`, `utils/`, `token/ERC20/`, `interfaces/` — **there is no `contracts/` directory inside it** (verified by tree inspection). The rewrite target is `@crane/contracts/external/openzeppelin-contracts-v5/access/Ownable2Step.sol`, etc. A rewrite to `.../openzeppelin-contracts-v5/contracts/access/...` does not exist.
3. **The frozen `IPoolManager` is replaced wholesale, not migrated.** The frozen snapshot's `IPoolManager` (locator PM) defines `ModifyLiquidityParams`/`SwapParams` as *nested* structs (PM:122–130, PM:146–153); the canonical interface has free structs in `types/PoolOperation.sol` with **identical field order and types** (`tickLower, tickUpper, liquidityDelta, salt`; `zeroForOne, amountSpecified, sqrtPriceLimitX96`), so encoding is unchanged — but every `IPoolManager.ModifyLiquidityParams` reference must become `PoolOperation.ModifyLiquidityParams`. The manifest must record that the frozen PM file's own nested structs are not migrated and that the canonical interface is substituted wholesale.
4. **One local import changes shape.** The frozen `SafeERC20` (v5.1.0) imports `Address` from `../../../utils/Address.sol` and **never uses it** (my only `Address.` hit in the snapshot is the import line itself); the versioned tree's `SafeERC20` (v5.2.0) has no `Address` import. The manifest must record this difference so the import diff is not read as a dropped dependency, and so no `Address` import is reintroduced.

**Evidence:** frozen `LiquidityAmounts.sol.txt` lines 4–5; v5 tree listing; canonical `PoolOperation` field order; `Address.` grep over the snapshot SafeERC20.
**Unverified by me:** the repo's exact v4 remapping alias string — I did not re-read the remapping table in this round. The manifest must carry the authoritative alias, not my recollection.

### C2 — AC68: byte-identity wording must distinguish file equality from used-surface identity (material, acceptance-criteria implementability)

**Required:** AC68 must not require byte-exact file equality for `SafeERC20`, because it can never pass: the frozen file is v5.1.0 and the versioned tree's file is v5.2.0, with a different version header and one fewer (unused) import. The acceptance must be split:

- **Byte-exact** (I verified, normalized comparison of the six files against their frozen counterparts): `access/Ownable2Step.sol`, `access/Ownable.sol`, `utils/Context.sol`, `utils/Pausable.sol`, `utils/ReentrancyGuard.sol`, `token/ERC20/IERC20.sol`. Note that `token/ERC20/IERC20.sol` is **not** the same file as the snapshot's `interfaces/IERC20.sol` — the manifest must pin the `token/ERC20/` target and must not let the rewrite drift to `interfaces/IERC20.sol`.
- **Used-surface identity** for `token/ERC20/utils/SafeERC20.sol`: `safeTransfer`, `safeTransferFrom`, and the complete `_callOptionalReturn` path Weir uses are text-identical between the frozen v5.1.0 file and the versioned v5.2.0 file (verified). The version difference and the dropped unused `Address` import are the only differences.
- **Consequence worth recording:** because the versioned tree is the same OZ generation, the custom-error selectors carry over unchanged (`OwnableUnauthorizedAccount`, `OwnableInvalidOwner`, `EnforcedPause`, `ExpectedPause`, `ReentrancyGuardReentrantCall`, `SafeERC20FailedOperation`), so AC02's inherited-error list does not need renaming.

If AC68 currently reads as "byte-identical" for all seven, change it to the split above; otherwise the acceptance criterion is unsatisfiable by construction.

### C3 — AC51: the native-sync trigger is not limited to "a legitimate outer transaction router" (material, characterization precision)

**Required:** AC51's precondition should be phrased as *any caller that can leave the manager's synced-currency slot set to a non-native currency*, not as a scenario requiring a "legitimate outer transaction router". The verified part is the failure path: Weir's native `_pay` calls `poolManager.settle{value: amount}()` with no preceding native `sync`, and the canonical manager's native settle reverts `NonzeroNativeValue()` when the synced currency is non-native and `msg.value > 0` (verified against CPM `sync` at 228–237 and `_settle` at 298–312).

**Still to be pinned by the test notes (unverified by me):** whether CPM's `sync` is callable outside an unlocked context (i.e. permissionless poisoning by a third party) and whether `settle` resets the synced-currency slot. Those two facts decide whether this is a third-party denial-of-service on native-pair deposits or only a self-inflicted ordering hazard. The draft's existing "no intervening action clears sync" caveat is right and must be kept; the actor description should be loosened accordingly.

**Must not change:** the contract behavior. No native `sync` may be added as a "repair" — that is a behavior change and is out of scope for a source import. The import reproduces the frozen `_pay` exactly, and AC51 characterizes the consequence.

### C4 — AC39: name the three distinct preview failure modes, and keep them separate from the library's checked cast (material, precision)

The preview path and the vendored library use **two different overflow behaviors**, and one acceptance criterion cannot cover both.

- **Bare cast, truncating.** `previewRedeem` computes `liq = uint128((uint256(v.liquidity) * shares) / v.totalShares)`. With `liquidity = totalShares = 2^20` and `shares = 2^128 + 7` I recomputed: the product is `2^148 + 7·2^20` (no uint256 overflow), the quotient is `2^128 + 7`, and the **bare `uint128` conversion truncates to `7`** — silent, no revert. If AC39 asserts a revert at this fixture, it is wrong; the correct expectation is the truncated value.
- **Product overflow, checked.** The multiplication overflows uint256 only when `shares > 2^256 / 2^20 = 2^236`; there it reverts with `Panic(0x11)`. That is a different fixture from the truncation one.
- **Division by zero.** `totalShares == 0` (a vault with no shares yet) makes the quotient divide by zero → `Panic(0x12)`.
- **Library-level checked cast, different contract.** The vendored library's `_toUint128` is `require((y = uint128(x)) == x, "liquidity overflow")` (frozen `LiquidityAmounts.sol.txt` lines 11–13) — it **reverts with a string** on overflow. That is the `_toUint128` inside `getLiquidityForAmount0/1`, not the preview's bare cast.

AC39 should name these four expectations separately and say which one is the "preview overflow" it means. They are observably different to a caller (silent truncation vs. `Panic(0x11)` vs. `Panic(0x12)` vs. `Error("liquidity overflow")`), and a test that asserts one of them while describing another will pass for the wrong reason.

### C5 — F1/AC30: pin the donation entry point and the donor's execution context (material, implementability)

F1 assumes "donate exactly 20 currency0 units through the manager" and a "real auxiliary router". Two facts must be pinned or the fixture is not constructible:

- the exact entry point used to create the donation (a manager `donate`-style call if the canonical manager exposes one, versus a settle-based donation through an auxiliary contract), and
- that the donor executes **inside an unlocked context** (the manager's currency-reserves accounting is only meaningful while unlocked), so the auxiliary donor must be a contract whose callback runs under the manager's unlock, not an EOA.

The arithmetic itself is confirmed: with a single position of liquidity `K = 2^20` and `H = 2^128`, `K` divides `H`, so a 20-unit donation yields exactly 20 units of gross accrued currency0 fee (`floor(20·H/K · K/H) = 20`, recomputed exactly), the500 bps cut is `floor(20·500/10000) = 1`, `r0 = 19`, cushioned `17`, and `l0 = l1 = 17` → added liquidity `17`, final idle `(2,2)`. All of F1/F2 reproduce.

### C6 — AC70: state the fork's hard preconditions (material, implementability)

AC70 is directionally right — chain 4663 *is* Robinhood Chain mainnet and this repo does configure `robinhood_mainnet`, `robinhood_mainnet_public`, and `robinhood_mainnet_alchemy` for it (verified in root `foundry.toml`; my original's "no configured endpoint" claim was wrong). To make the fork reproducible, the criterion must additionally state:

- the **pinned block number**, and the requirement that the chosen RPC serves **archive state** at that block (a public endpoint may not);
- **which alias** is used, and that the alchemy variant requires the operator's key;
- that state-changing fork operations need an **owner key** for the deployed Weir on 4663;
- that the 4663 addresses of the **deployed Weir and the canonical manager are not in this repository** and must be sourced separately (the draft already notes this; it should be listed as an input, not an assumption).

### C7 — AC35: restate the "shared-currency" reconciliation (precision)

`AC35` asserts a reconciliation for a "physical shared-currency balance". The canonical manager sorts pool currencies, so `currency0 == currency1` is very likely unreachable, which makes the shared-currency form of the invariant vacuous. Either state the configuration in which the two currencies coincide, or restate the criterion as the two-currency invariant (`balance(currency0) == idle0 + unassigned0`, and likewise for currency1) and drop the shared-currency wording. A vacuous invariant in an acceptance list is worse than no invariant, because it reads as coverage.

---

## Confirmed as correct (no change needed)

- **Fee basis = first return.** `W:322` binds `(BalanceDelta fees,)` — the **first** tuple element of `modifyLiquidity`, i.e. `callerDelta`, not the second `feesAccrued`. The draft's WI-15/WI-21 ("the first return value", "the positive portions of the poke's first caller-delta return") is right, and the corresponding withdrawal/add sites (`W:263`, `W:348`) also use the first return. The variable is named `fees`; the value is `callerDelta`. My original said `feesAccrued` — that was my error.
- **Fee denominator.** `cut = floor(grossPositiveFee · perfFeeBps / 10_000)`, default 500 bps, cap 1 000 bps, computed on the *gross* positive components only, with the cut taken to the treasury via `_take` before the net settlement (`W:327–330`). Matches WI-22 and the draft's constants (`MIN_SHARES = 1000`, `MAX_PERF_FEE_BPS = 1000`, `BPS = 10_000`).
- **Explicit cast vs checked arithmetic.** `uint256(int256(v.idle0) + net0)` — the `int256` addition is checked (may revert with `Panic(0x11)`), the `int256`→`uint256` conversion is a wrapping reinterpret that yields `2^256-1` for `-1` and does not revert by itself. AC67's "exactly 2^256-1; it is not an automatic cast revert" is exactly right, as is the refusal to conclude `idle <= 2` or fail-closed accounting from it.
- **Compound ledger and event.** `W:319–361` reproduced line by line: `lastCompound` is written *before* the zero-liquidity early return; gross fee is the positive part of the poke's first return; the cut goes to treasury; `r = gross - cut + idle`; the cushion is `> 2` on the *candidate inventory*; added liquidity is `min(l0, l1)`; `idle` is updated by `cast(int256(idle) + net)`; `Compounded(id, f0, f1, liq)`. My arithmetic reproduces F1/F2 exactly.
- **F0 and F3.** Deposit `K+2` each → cushion 2 each → `K` each → `l0 = l1 = K = 1 048 576`, liquidity `K`, total shares `K`, recipient shares `K - 1000 = 1 047 576`. Full withdrawal removes liquidity `1 047 576` and returns `(1 047 575, 1 047 575)` — the `K-1 001` figure depends on the **vendored** library's downward rounding and is therefore a direct consequence of the draft's decision to retain that library; using the canonical (incomplete) port library or v3-periphery formulas would produce different numbers. Second depositor at the F1 state: `floor(K·T/L) = K` shares, and the proportional idle0 claim `floor(19/2) = 9`, as the draft states.
- **AC58.** The canonical manager's `unlock` reverts `AlreadyUnlocked()` when already unlocked, so a nested ordinary compound issued from another unlock surfaces the *manager's* error; Weir's own `nonReentrant` guard fires first only for re-entry into a Weir entrypoint already executing. AC58's split matches. The test should assert the exact selector through propagated revert data, not a generic revert.
- **AC60.** With a hook attached, `callerDelta` and `feesAccrued` diverge, and since Weir's gross fee is the positive part of `callerDelta`, the **perf-fee base is hook-influenced** where a pool hook is configured. This is reachable, not hypothetical — the frozen source passes `hookData` on every liquidity and swap call. The draft characterizes it; it must not be converted into a "we are safe from fee inflation" claim.
- **Residual outputs (WI-20/AC25).** After a withdrawal zap, both returned output currencies can remain positive; no full-consumption revert may be added. Consistent with the frozen `_withdraw` netting.
- **Genesis / reserve accounting.** `totalShares` is set to the reserve `1 000` and then incremented by the issued shares, so after genesis `T - 1000` is the assigned total and the `1 000` difference is the reserve; a full withdrawal leaves `T = 1 000` and `L = 1 000`. AC63's invariant is consistent provided the tracked sum includes Weir-held (stranded) shares per AC18.

---

## Dispositions of my original proposal (`members/minimax/response.md`)

**Adopted by the draft and retained without change:** the versioned OpenZeppelin v5 route (rejecting the 5.6.1 generic tree, whose `Pausable` string-revert and namespaced `ReentrancyGuard` storage changes would be behavior changes); retention of the vendored `LiquidityAmounts`; the five-site `PoolOperation` struct migration; the "first return = `callerDelta`" fee rule; the explicit-cast characterization; the native-sync characterization; the refusal to infer safety properties from the import; the fork-on-4663 plan with the repo's existing aliases; and the numbered acceptance-criteria style.

**Corrected by the draft — my original was wrong, and the draft wins:**

| My original | Draft | Ground |
|---|---|---|
| Perf fee derives from the second return `feesAccrued`, inheriting upstream's donation-inflation warning | Perf fee derives from the **first** return (`callerDelta`) | `W:322` binds the first tuple element; the local variable name `fees` misled me |
| A donation "artificially inflates" the fee basis | Donation increases the position's **real** claim; the cut is taken from that claim | Fee growth is position-accurate; `F1` models it as 20 → cut 1 → idle 19 |
| Chain 4663 has no configured RPC endpoint | `robinhood_mainnet`, `robinhood_mainnet_public`, `robinkey…_alchemy` are configured for 4663 | root `foundry.toml` |
| Struct-construction sites at W:263/292/323/349/395 | The five *type-construction* lines are W:264, 292, 323, 349 (`ModifyLiquidityParams`) and W:397 (`SwapParams`) | My numbers were the call-site lines; the qualified constructions sit one line later, and there are five, not four |
| `WeirBase` 93 lines, `LiquidityAmounts` 61 lines | 88 and 68 content lines | My counts included the trailing newline segment and the wrong file boundaries; the draft matches the frozen corpus |

**Adopted from the draft that I had left open or under-specified:** the import-path shape for the versioned v5 tree (my original named the family but not the missing `contracts/` segment); the explicit separation of file-level vs used-surface identity for `SafeERC20`; the fork preconditions; and the F3 refinement adding the `floor(19/2) = 9` proportional idle claim.

---

## What was not adopted, and what I did not take from others

**Not adopted from my own original, and correctly absent from the draft:** the OpenZeppelin 5.6.1 generic-tree option; symbol-name-only import substitution; hardening the `uint256(int256(...))` cast; repairing the native `settle` path with a native `sync`; substituting the canonical port's incomplete `LiquidityAmounts` for the vendored copy; and any `IUnlockCallback`/`PoolOperation` behavior change. Each would change the import's behavior, which is out of scope.

**Peer originals** were read earlier for context only. The draft's consolidation is the coordinator's; I do not attest to the internal reasoning of the other members, and I read no peer feedback. Where the draft's content matches an original I saw, I have not independently re-derived it, and I have not credited it to its author here.

---

## Remaining concerns (characterization, not fixes)

1. **Perf-fee base is hook-sensitive.** `callerDelta` includes hook deltas, so a pool with a hook can move the gross-fee base that the 500 bps cut is taken from. AC60 covers it; the PRD must not present the fee path as hook-independent.
2. **Native-sync hazard reachability is unresolved** (C3). Until CPM's `sync` modifier and `settle` reset semantics are pinned, AC51 should be read as an ordering hazard with a possibly-permissionless trigger, not as a proven third-party DoS — and not as a proven non-issue.
3. **Two overflow idioms coexist** (C4): silent truncation in the preview path, string-revert `"liquidity overflow"` in the vendored library. A single "overflow" acceptance row would pass for the wrong reason.
4. **The `2^256-1` idle state is observable but not characterized end to end.** AC67's fixture reaches it, and the draft correctly declines to call it fail-closed. The reconciliation consequences (subsequent compounds reinterpreting `int256(idle0)`, settlement against physical balances) are characterization work still open, and the draft's "physical balances reconcile to idle + unassigned" wording (AC35) should be tied to it.
5. **Unassigned/inventory tracking is the weakest-evidenced area.** The draft's ghost-accounting requirement (AC18, AC35) spans share transfers to Weir itself, residual outputs, and post-zap net amounts; it is the area most likely to produce a test that passes for the wrong reason if the ledger is reconstructed loosely.

---

## Limits of this advisory

- **No commands, builds, or tests were run.** No `forge build`, no `forge test`, no fork, no RPC query to chain 4663. Every numeric claim above is either (a) read off the frozen source text, (b) read off the canonical CPM/v4 sources in this repo, or (c) an exact-integer recomputation of the frozen library and compound routine performed in-process.
- **No peer feedback was read**; no second round is requested.
- **The draft's SHA-256 is coordinator-supplied provenance**, not independent attestation by me. I read the draft file in this session and did not re-hash it.
- **Explicitly unverified by me in this round:** (i) the repo's exact v4 remapping alias string; (ii) whether CPM's `sync` is callable outside an unlocked context and whether `settle` resets the synced-currency slot; (iii) whether the canonical manager exposes a `donate` entry point; (iv) whether the canonical manager sorts currencies so that `currency0 == currency1` is unreachable; (v) the `nonReentrant` modifier lines on Weir's entrypoints, which AC58's ordering claim depends on; (vi) an independent recount of the manifest ABI (my manifest-ABI checker failed to parse the artifact's ABI block in this round, so AC02's 27/11/18 counts are internally consistent with the draft's appendix but unverified against the frozen artifact).
- This advisory **neither replaces my original** (`members/minimax/response.md`, preserved) **nor authorizes implementation**. It stops here.
