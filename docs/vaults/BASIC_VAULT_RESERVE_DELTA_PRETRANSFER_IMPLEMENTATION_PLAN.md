# Implementation Plan — Basic Vault Reserve-Delta Pretransfer

| Field | Value |
|-------|--------|
| **Status** | **READY TO EXECUTE** |
| **Date** | 2026-08-10 |
| **Kind** | Execute plan (orchestrator + worktree implementers) |
| **Normative law** | [`BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md`](./BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md) — **only** product law; this plan does not reopen §1.1 |
| **Primary CODE** | `contracts/vaults/basic/BasicVaultCommon.sol` |
| **Primary storage** | `MultiAssetBasicVaultRepo` (`_reserveOfToken` / `_vaultTokens`, slot `indexedex.vaults.basic`) |
| **Shared error** | `ISecurePullErrors.TransferDeltaInsufficient(claimed, observedDelta)` — reuse; **no** new underflow error |
| **Worktree / branch prefix** | `fix_reserve_delta_` / `fix_reserve_delta/<slice>` |
| **Merge model** | Rebase onto `main` → fast-forward `main` (linear history) |
| **Max concurrent implementers** | **3** (after Wave 0 ships serially) |
| **Skills** | `crane-testing`, `indexedex-testing`, `crane-adversarial-testing`, `indexedex-adversarial-testing` |

---

## 0. Executive summary

**Problem:** `pretransferred=true` uses in-call `balBefore` only, so transfer-before-call push always sees delta `0`. Absolute free credit is correctly forbidden, but durable `reserveOfToken` was never wired as the push baseline.

**Fix (once):** In `BasicVaultCommon`:

1. Pretransfer credits `claimed` only when `claimed ≤ U` where `U = balanceOf − reserveOfToken`.
2. Pull path still credits in-call pull delta only.
3. Every money route ends with **full expected-hold** reserve sync (`R := balanceOf` for each `_vaultTokens` entry).
4. Unclaimed push surplus is **absorbed** (not refunded). Retained compound/sleeve dust is **booked** via that sync.

**Inheritance:** Uni V2 / Camelot / Aerodrome / Aave Stata SE commons inherit; route authors add one end-of-workflow sync call. Wave 0 does **not** migrate DETF nested SE to push.

---

## 1. Locked product law (do not re-litigate)

Copy into every subagent prompt. Full text: PRD §1.1 / §4.

| ID | Implementer rule |
|----|------------------|
| **L-RSRV-CALLER** | Any caller may pass `pretransferred=true`. No principal gate. |
| **L-RSRV-SYNC-WHEN** | Sync at **end** of successful money workflow after `_refundExcess`. **No** post-return modifier. |
| **L-RSRV-SYNC-ROUTES** | **Every** deposit / withdraw / compound / harvest / rebalance / zap / fee-compound / other balance-mutating money path. Not view/quote. |
| **L-RSRV-HOLD-SET** | Expected-hold = underlyings + package sleeve + compound/rebalance residuals. **Not** vault share token. |
| **L-RSRV-SYNC-FULL** | Sync **full** expected-hold set every money op — **not** route-touched-only. |
| **L-RSRV-ABSORB** | `claimed < U` surplus → absorb into `R` at sync. **No** refund of `U − claimed`. Refund only exact-out `max > used`. |
| **L-RSRV-COMPOUND-DUST** | Retained compound dust included in end-of-op `R` (booked → I1). |
| **L-RSRV-DUST** | Crude recovery only for **not-yet-synced** / **non-expected-hold** inventory. |
| **L-RSRV-BOOTSTRAP** | Init `R = 0`; live balance fully unbooked until claim/sync. |
| **L-RSRV-DETF-W0** | Nested DETF → SE stays `forceApprove` + `pretransferred=false`. |
| **L-RSRV-UNIT-SUT** | Law proven once under `test/foundry/spec/vaults/basic/**` via minimal production-storage SUT; SE packages reuse commons. |
| **L-RSRV-NO-UNDERFLOW-BRANCH** | **No** `ReserveAccountingUnderflow`, **no** intentional assert branch for `B < R`. Enforce INV-R1 in **tests**. Compute `U = B - R` normally. Never silent-clamp. |

### Invariants (tests must prove)

| ID | After every successful money route |
|----|-------------------------------------|
| **INV-R1** | For every expected-hold `T`: `R(T) == balanceOf(T)` |
| **INV-R2** | Never credit `claimed` when `claimed > U` |
| **INV-R4** | Compound/sleeve residuals remaining on vault are in `R` |

### Forbidden

- Absolute `balanceOf >= claimed` free credit without subtracting `R`
- Route-touched-only sync
- Refund of unclaimed push surplus
- Production underflow product error
- DETF push migration in this program’s Wave 0–2
- Mocking SUT vaults / manager / registry
- `via_ir`

---

## 2. Target CODE shape (locked design)

### 2.1 `BasicVaultCommon.sol` (canonical)

```solidity
// Imports
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
// keep BetterSafeERC20, Permit2AwareRepo, ISecurePullErrors

function _bookedReserve(IERC20 token) internal view returns (uint256) {
    return MultiAssetBasicVaultRepo._reserveOfToken(address(token));
}

function _unbookedSurplus(IERC20 token) internal view returns (uint256) {
    // B - R under Solidity 0.8 checked math; no special product error (L-RSRV-NO-UNDERFLOW-BRANCH)
    return token.balanceOf(address(this)) - MultiAssetBasicVaultRepo._reserveOfToken(address(token));
}

function _syncReserveToBalance(IERC20 token) internal {
    MultiAssetBasicVaultRepo._updateReserve(token, token.balanceOf(address(this)));
}

function _syncAllExpectedHoldReserves() internal {
    address[] memory tokens = MultiAssetBasicVaultRepo._vaultTokens();
    for (uint256 i; i < tokens.length; ++i) {
        IERC20 t = IERC20(tokens[i]);
        MultiAssetBasicVaultRepo._updateReserve(t, t.balanceOf(address(this)));
    }
}

function _secureTokenTransfer(IERC20 tokenIn, uint256 amountTokenToDeposit, bool pretransferred)
    internal virtual returns (uint256 actualIn)
{
    uint256 R = MultiAssetBasicVaultRepo._reserveOfToken(address(tokenIn));
    uint256 B0 = tokenIn.balanceOf(address(this));

    if (!pretransferred) {
        // existing ERC20 allowance → else Permit2 pull
        // ...
        uint256 B1 = tokenIn.balanceOf(address(this));
        return B1 - B0; // FoT-safe; do NOT add prior U
    }

    // pretransferred == true — durable baseline
    uint256 U = B0 - R;
    if (amountTokenToDeposit > U) {
        revert ISecurePullErrors.TransferDeltaInsufficient(amountTokenToDeposit, U);
    }
    return amountTokenToDeposit;
}

// _refundExcess unchanged: only when pretransferred && maxAmount > usedAmount
```

**NatSpec:** rewrite to describe reserve-delta (not in-call-only). Document absorb vs exact-out refund.

### 2.2 Route authors (all money entrypoints)

```text
1. _secureTokenTransfer / business logic (DEX, mint, burn, compound, …)
2. _refundExcess(...) when exact-out max > used   // optional
3. _syncAllExpectedHoldReserves()                 // MANDATORY full set
return
```

Order is normative: **refund before full-set sync**.

### 2.3 Expected-hold set source

| Source | Rule |
|--------|------|
| Default | `MultiAssetBasicVaultRepo._vaultTokens()` from package `_initialize(vaultTokens)` |
| Package must register | Underlyings + sleeve + any token that may sit as compound/rebalance residual **before** production use |
| Mid-lifecycle add | If a package later holds a new residual token, call `_addVaultToken` (or re-init path) so full-set sync covers it — **do not** invent a second reserve map |
| Vault share | **Never** add `address(this)` to expected-hold for this program |

### 2.4 Aerodrome

- **Delete** `_secureTokenTransfer` override if it only documents in-call delta and calls `super` (super implements law).
- Keep `_excessToken*` for **compound product accounting** only.
- Full-set end sync books live balances (including residual dust) → I1 protects them.
- Do **not** credit pretransfer from `balance − excessToken`.

### 2.5 Unit SUT (L-RSRV-UNIT-SUT)

**Do not invent a new production vault DFPkg** unless grep proves no viable path.

**Canonical unit surface:**

1. Upgrade `BasicVaultCommonHarness` in `test/foundry/spec/vaults/basic/BasicVaultCommon_TokenTransfer.t.sol` (or extract shared harness file) to:
   - `MultiAssetBasicVaultRepo._initialize(expectedHoldTokens)`
   - Expose: `secureTokenTransfer`, `refundExcess`, `syncAllExpectedHoldReserves`, `bookedReserve`, `unbookedSurplus`
   - Expose **`moneyIn`** (or equivalent): pull/pretransfer → optional “use”/refund → `_syncAllExpectedHoldReserves` — models production route contract for INV-R1 / I3 / absorb
2. Keep hermetic (no fork required) for Wave 0 unit suite.
3. Production inheritance proven in Wave 1 on real SE diamonds (manager registry deploy).

---

## 3. Waves & work packages

### Wave 0 — Commons (serial, ship-blocking)

| Slice | WP | Work | Primary touch set | DoD |
|-------|-----|------|-------------------|-----|
| `common` | **WP-RSRV-0** | Reserve-delta + helpers in `BasicVaultCommon`; NatSpec | `contracts/vaults/basic/BasicVaultCommon.sol` | Compiles; algorithm matches PRD §4.2 |
| `common` | **WP-RSRV-0b** | Amend CLONE_API_FREEZE + pointer docs | `docs/testing/coverage-audit/CLONE_API_FREEZE.md`; optional gap-closure / agent law pointer | Docs describe `U = B − R` for BasicVault family; full-set sync; absorb; no underflow error |
| `common` | **WP-RSRV-0c** | Unit law tests + harness | `test/foundry/spec/vaults/basic/**` | All §7 matrix rows below green |

**Branch:** `fix_reserve_delta/common`  
**Commit subject:** `fix_reserve_delta(common): reserve-delta pretransfer + full-set sync helpers`

#### Wave 0 unit test matrix (WP-RSRV-0c)

| Test | Expect |
|------|--------|
| Pull `false` + approve | credit = received; after `moneyIn`/sync: `R == B` |
| Pull Permit2 when allowance low | Success (existing Permit2 suite path if present) |
| Push then `true`, `claimed = push` | Success; credit = claimed; after sync `R == B` |
| Push then `true`, `claimed < push` | Success; **no** refund of surplus; after sync absorb (I3) |
| Booked inventory (`R == B`), `true`, no push | `TransferDeltaInsufficient(claimed, 0)` (I1) |
| `claimed > U` | `TransferDeltaInsufficient(claimed, U)` with exact args (I2) |
| Exact-out: max push, partial use, `_refundExcess`, sync | Caller refunded unused **credit**; then `R == B` |
| FoT pull | credit = actual delta |
| Pull with prior unbooked `U` | credit = pull delta only (not `U + pull`) |
| Bootstrap `R = 0` | push/`true` may claim full live balance |
| Full-set sync books multi-token hold set | all expected-hold tokens satisfy INV-R1 |

**Acceptance (Wave 0):**

```bash
forge test --match-path 'test/foundry/spec/vaults/basic/**' -vv
```

**Also update** existing TrustFlags / TokenTransfer tests that still encode in-call-only I1 semantics:

- `test_secureTokenTransfer_pretransferred_returnsAmount` — **booked** inventory case: seed + **sync** then `true` → delta 0 error; **and** separate happy path: push then `true` without prior sync of that push.
- Shortfall tests: expected `observedDelta` arg becomes `U = B − R`, not in-call 0 when unbooked inventory exists.

---

### Wave 1 — SE inheritors + sync call sites

**Depends on:** Wave 0 on `main`.

Each slice: grep all money entrypoints; append `_syncAllExpectedHoldReserves()` after refunds; prove INV-R1 sample asserts; green pretransfer/refund filters.

| Slice | WP | Package | Touch set (start; expand via grep) | DoD |
|-------|-----|---------|--------------------------------------|-----|
| `se-u2` | **WP-RSRV-1-U2** | Uni V2 SE | `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchange{In,Out}Target.sol`, `...Common.sol` | Every money branch full-set sync; pretransfer+refund specs green |
| `se-aero` | **WP-RSRV-1-AERO** | Aerodrome V1 SE | `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchange{Common,In,Out}Target.sol` (+ compound targets if separate) | Delete/align override; compound residual booked; pretransfer specs green |
| `se-cam` | **WP-RSRV-1-CAM** | Camelot V2 SE | `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchange{Common,In,Out}Target.sol` | Full-set sync; pretransfer+deposit green |
| `se-aave` | **WP-RSRV-1-AAVE** | Aave Stata SE | `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchange*.sol` | Hold-set includes stata/underlying as package already registers; full-set sync; pretransfer green |
| `se-other` | **WP-RSRV-1-OTHER** | Any remaining `is BasicVaultCommon` | Grep-proven list | No money route without end full-set sync |

**Grep inventory (run at start of Wave 1):**

```bash
rg -n 'is BasicVaultCommon|BasicVaultCommon' contracts --glob '*.sol'
rg -n '_secureTokenTransfer\(|_refundExcess\(|function exchange|function compound|function harvest' \
  contracts/protocols/dexes/uniswap/v2 \
  contracts/protocols/dexes/aerodrome/v1 \
  contracts/protocols/dexes/camelot/v2 \
  contracts/protocols/lending/aave/v3.6 \
  --glob '*.sol'
```

**Known call-site notes:**

| Package | Notes |
|---------|--------|
| Uni V2 Out | Has commented `_updateReserve` — replace with `_syncAllExpectedHoldReserves()` after refunds on **all** branches, not one-off |
| Aerodrome | Override currently only `return super`; prefer **delete override**. Compound paths that move token0/token1 dust **must** still full-set sync |
| Aave Stata | Confirm DFPkg `vaultTokens` includes tokens that can remain as inventory |

**Parallelism:** after Wave 0, run up to **3** of `{se-u2, se-aero, se-cam}` then `{se-aave, se-other}`.

**Acceptance (per slice):**

```bash
# Uni V2 example — adjust path per slice
forge test --match-path 'test/foundry/spec/protocol/dexes/uniswap/v2/**' --match-test 'pretransfer|Refund|refund|Pretransfer' -vv
forge test --match-path 'test/foundry/spec/protocol/dexes/aerodrome/v1/**' --match-test 'pretransfer|Pretransfer|compound|Compound' -vv
forge test --match-path 'test/foundry/spec/protocol/dexes/camelot/**' --match-test 'pretransfer|Pretransfer' -vv
forge test --match-path 'test/foundry/spec/protocol/lending/aave/**' --match-test 'pretransfer|Pretransfer' -vv
```

Add at least one explicit INV-R1 assert after a successful money op per package TestBase helper if not already present.

---

### Wave 2 — Routers & integration

**Depends on:** Wave 1 packages used by routers (at minimum Uni V2 / Balancer SE underlying vaults green).

| Slice | WP | Work | Touch set | DoD |
|-------|-----|------|-----------|-----|
| `rtr-bal` | **WP-RSRV-2-BAL** | Balancer V3 SE router suites under reserve-delta law | `test/foundry/spec/protocol/dexes/balancer/v3/routers/**`; router CODE only if product intent broken (prefer vault fix only) | Deposit / pass-through / batch / permit2 / transient green **without** rewriting to approve+pull-only |
| `rtr-refund` | **WP-RSRV-2-REFUND** | `StandardExchangeOut_Refund` + UniV2 router refund | `test/foundry/spec/vaults/StandardExchangeOut_Refund.t.sol` + related | Pretransfer refund + **refund-before-sync** order proven |

**Acceptance:**

```bash
forge test --match-path 'test/foundry/spec/protocol/dexes/balancer/v3/routers/**' -vv
forge test --match-path 'test/foundry/spec/vaults/StandardExchangeOut_Refund.t.sol' -vv
```

**Router product intent (locked):** keep transfer/Permit2 **to vault** + `exchange*(..., true)`. Only change CODE if amounts/claimed mismatch law; do not convert hot path to forceApprove+false.

---

### Wave 3 — Clones / DETF (later; not blocking Wave 0–2 merge)

| Slice | WP | Work | Note |
|-------|-----|------|------|
| `detf-push` | **WP-RSRV-3-DETF** | DETF nested SE → push + `true`; DETF-local pull baseline | **Product law:** [`DETF_NESTED_SE_PUSH_PRETRANSFER_PRD.md`](./DETF_NESTED_SE_PUSH_PRETRANSFER_PRD.md). Execute plan TBD. Prerequisite: Waves 0–2 SE reserve-delta green. |
| `clone-u4` | **WP-RSRV-3-U4-HOOK** | Uni V3/V4 SE, Slipstream, hooks peers that clone pull | Amend CLONE checklist; align to reserve-delta **or** document non-BasicVault package-local book. Companion to DETF push PRD (not in that PRD’s mandatory DoD). |
| `clone-other` | **WP-RSRV-3-OTHER** | EtherFi / Rocket / other SE with MultiAsset book | Ensure full-set sync + hold-set registration for sleeve tokens |

Do **not** start Wave 3 DETF push until Waves 0–2 acceptance green on `main` unless owner explicitly prioritizes.

---

## 4. Documentation deliverables (WP-RSRV-0b)

| Doc | Change |
|-----|--------|
| `docs/testing/coverage-audit/CLONE_API_FREEZE.md` | Replace pure in-call delta for **BasicVault family** with: `U = B − R`; credit claimed iff `claimed ≤ U`; full expected-hold end-sync; absorb; I1 = **booked** inventory; no underflow product error. Keep shared error type. |
| `docs/testing/TEST_COVERAGE_GAP_CLOSURE_PRD.md` or impl plan pointer | One line: L-GAPS-9 pretransfer baseline refined to booked reserve for BasicVault-family packages (link this PRD/plan). |
| `docs/agent/INDEXEDEX_AGENT_LAW.md` | Pointer only if pull section exists — no full paste. |
| This plan | Progress checkboxes updated by orchestrator as slices land. |

### CLONE_API_FREEZE normative snippet (paste target)

```text
BasicVault-family (MultiAssetBasicVaultRepo):
  R = reserveOfToken[token]
  B = balanceOf(vault)
  U = B - R
  pretransferred: credit claimed iff claimed <= U else TransferDeltaInsufficient(claimed, U)
  !pretransferred: credit pull delta only
  end of every money route: for each vaultToken T: R[T] = balanceOf(T)
  unclaimed surplus absorbed; compound dust booked via sync
  I1 tests: R synced to B before free-credit attempt
```

Non-BasicVault clones: either adopt same durable baseline **or** remain package-local with explicit checklist exception (Wave 3).

---

## 5. Orchestrator protocol

### 5.1 Naming

| Item | Pattern | Example |
|------|---------|---------|
| Worktree | `.worktrees/fix_reserve_delta_<slice>` | `.worktrees/fix_reserve_delta_common` |
| Branch | `fix_reserve_delta/<slice>` | `fix_reserve_delta/common` |
| Commit | `fix_reserve_delta(<slice>): <imperative>` | `fix_reserve_delta(common): reserve-delta + full-set sync` |

### 5.2 Worktree seed (non-negotiable)

Before first `forge` in a new/empty worktree:

```bash
# REPO = warm primary checkout; WT = worktree root
rsync -a "${REPO}/cache_forge/" "${WT}/cache_forge/"
rsync -a "${REPO}/out/" "${WT}/out/"
rm -rf "${WT}/lib/crane" && ln -s "${REPO}/lib/crane" "${WT}/lib/crane"
```

After green forge, copy `cache_forge/` + `out/` **back** to warm seed.

### 5.3 Forge patience (non-negotiable)

- Cold monorepo compile: **20–40+ minutes** is normal.
- **Never kill** `forge` / `solc` for “no progress.”
- Timeouts: **hours** (2–4h) for first compile, not 10–20 minutes.
- Prefer one long-running command + completion notification.

### 5.4 Concurrency

```text
Wave 0: serial (common only) — slots_free = 1
Wave 1: slots_free = 3; queue se-u2, se-aero, se-cam, se-aave, se-other
Wave 2: slots_free ≤ 2; rtr-bal, rtr-refund (can parallel if touch sets disjoint)
Wave 3: deferred
```

Never two implementers on the same primary CODE files (`BasicVaultCommon.sol` only in Wave 0).

### 5.5 Merge

1. Subagent completes + acceptance forge green in worktree  
2. Orchestrator: `git rebase main` in worktree  
3. Re-run acceptance if rebase non-trivial  
4. Fast-forward `main`  
5. Remove worktree; update §9 progress table  

---

## 6. Subagent prompt template

```text
You implement slice `<SLICE>` of docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md
Normative law: docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md §1.1 + §4 only.

Hard rules:
- No via_ir. No mock SUT vaults/manager/registry.
- pretransferred credit: claimed <= (balance - reserveOfToken); else TransferDeltaInsufficient(claimed, U)
- End every money route: _syncAllExpectedHoldReserves() after _refundExcess
- Full expected-hold set only (MultiAssetBasicVaultRepo._vaultTokens)
- Absorb unclaimed push surplus; do not refund U - claimed
- No ReserveAccountingUnderflow / no production B<R assert branch
- DETF nested SE: leave forceApprove + pretransferred=false (Wave 0–2)
- Seed cache_forge + out before forge; never kill long forge/solc
- Touch only: <TOUCH_SET>
- DoD: <DOD>
- Acceptance: <FORGE_CMD>

Do not reopen product OQs. If blocked by product ambiguity not in PRD, stop with NEEDS_OWNER.
```

---

## 7. Test expectation migrations (anti-theater)

| Old (i-common) | New (this program) |
|----------------|--------------------|
| Seed inventory, no push, `true` → expect free credit | **I1 booked:** sync/`R=B` first → `TransferDeltaInsufficient(claimed, 0)` |
| Seed inventory, no push, `true` → expect delta 0 always | If inventory is **unbooked** (`R=0`), push-equivalent `U=B` is a **valid happy path** (bootstrap / dust recovery) |
| In-call balBefore-only happy for router push | Transfer to vault then `true` succeeds when `claimed ≤ U` |
| Aerodrome reserved dust free / string error | Booked residual → I1 shared error after sync |
| Nested DETF transfer+true | **Still** approve+false in Wave 0–2 |

---

## 8. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Missed sync on a money branch | Wave 1 grep checklist; full-set helper single call reduces partial forget; INV-R1 tests |
| Dual meaning of public `reserveOfToken` | BasicVault family = ERC20 book; Wave 3 packages with economic reserve meaning document exception |
| Gas SSTORE full set | Accepted (L-RSRV-SYNC-FULL); no implementer shortcut to touched-only |
| Harness ≠ diamond | Wave 0 harness uses **production repo storage**; Wave 1 proves real SE diamonds |
| Slipstream / Uni V3/V4 still broken | Expected until Wave 3; CLONE_API_FREEZE states BasicVault-family first |
| Adversarial suites still in-call-only | Update expectations when suite fails under new law; keep I1 booked semantics |

---

## 9. Progress log (orchestrator updates)

| Slice | WP(s) | Status | Commit / notes |
|-------|-------|--------|----------------|
| `common` | WP-RSRV-0, 0b, 0c | **DONE** | Reserve-delta + full-set sync helpers; basic/** 25/25 green |
| `se-u2` | WP-RSRV-1-U2 | **DONE** | End-route full-set sync; pretransfer/refund green |
| `se-aero` | WP-RSRV-1-AERO | **DONE** | Override deleted; compound residual booked I1; pretransfer/compound green |
| `se-cam` | WP-RSRV-1-CAM | **DONE** | Full-set sync; pretransfer green |
| `se-aave` | WP-RSRV-1-AAVE | **DONE** | DFPkg hold-set init; full-set sync; pretransfer green |
| `se-other` | WP-RSRV-1-OTHER | **DONE** | Grep inventory: only UniV2/Aero/Camelot/Aave inherit BasicVaultCommon for money routes |
| `rtr-bal` | WP-RSRV-2-BAL | **DONE** | Balancer V3 SE routers 197/197 green (push + true intent kept) |
| `rtr-refund` | WP-RSRV-2-REFUND | **DONE** | StandardExchangeOut_Refund 8/8 green |
| `detf-push` | WP-RSRV-3-DETF | **DONE** | Nested push+true all 9 families; local durable U=B−R; hooks WH; plan EXECUTED |
| `clone-u4` | WP-RSRV-3-U4-HOOK | DEFERRED | |
| `clone-other` | WP-RSRV-3-OTHER | DEFERRED | |

---

## 10. Definition of done (program)

Waves **0–2** closed when:

1. `BasicVaultCommon` implements PRD §4.2 + full-set sync helpers.  
2. `test/foundry/spec/vaults/basic/**` green under reserve-delta law.  
3. All `is BasicVaultCommon` SE packages end every money route with full-set sync.  
4. Aerodrome compound residuals booked (I1), override not free-crediting.  
5. Balancer SE router + refund suites green without approve+pull rewrite.  
6. CLONE_API_FREEZE amended for BasicVault family.  
7. DETF still nested `false` (no accidental push migration).  
8. Progress table above shows Wave 0–2 slices **DONE** on `main`.

Wave 3 is a **follow-on program**, not required for this DoD.

---

## 11. First action (start here)

1. Create worktree `fix_reserve_delta/common` from current `main`; seed `cache_forge/` + `out/`.  
2. Implement WP-RSRV-0 CODE in `BasicVaultCommon.sol`.  
3. Upgrade harness + rewrite `test/foundry/spec/vaults/basic/**` (WP-RSRV-0c).  
4. Amend CLONE_API_FREEZE (WP-RSRV-0b).  
5. Run acceptance; commit; FF `main`.  
6. Fan out Wave 1 (≤3 parallel SE slices).

**Executor start command:**

> Execute `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md` Wave 0 (`common`) first; then Wave 1 SE slices with ≤3 worktrees; seed caches; never kill long forge runs.

---

## 12. Approval

| Role | Expectation |
|------|-------------|
| Product | Law fixed in PRD; plan only sequences CODE/tests/docs |
| Implementer | Follow §2 CODE shape and §1 law; no product forks |
| Reviewer | Reject PRs that reintroduce absolute credit, skip full-set sync, refund unclaimed surplus, add underflow product API, or migrate DETF push early |
| Orchestrator | Linear history; Wave 0 serial; progress in §9 |
