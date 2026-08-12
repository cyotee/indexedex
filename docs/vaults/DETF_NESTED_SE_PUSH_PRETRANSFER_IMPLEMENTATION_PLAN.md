# Implementation Plan — DETF Nested SE Push Pretransfer

| Field | Value |
|-------|--------|
| **Status** | **DONE** |
| **Date** | 2026-08-10 |
| **Kind** | Execute plan (orchestrator + worktree / subagent implementers) |
| **Normative law** | [`DETF_NESTED_SE_PUSH_PRETRANSFER_PRD.md`](./DETF_NESTED_SE_PUSH_PRETRANSFER_PRD.md) — **only** product law; this plan does not reopen PRD §1.1 / §9 |
| **Parent program** | Wave 3 / `detf-push` of [`BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md`](./BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md) (Waves 0–2 prerequisite) |
| **Shared error** | `ISecurePullErrors.TransferDeltaInsufficient(claimed, observedDelta)` — reuse; no new free-credit API |
| **Worktree / branch prefix** | `fix_detf_push_` / `fix_detf_push/<slice>` |
| **Merge model** | Worktree → rebase onto `main` → fast-forward `main` (linear history) |
| **Max concurrent implementers** | **3 worktrees and 3 live subagents** (L-DETF-PARALLEL) |
| **Skills** | `crane-testing`, `indexedex-testing`, `crane-adversarial-testing`, `indexedex-adversarial-testing` |

---

## 0. Executive summary

**Problem:** DETF nested fund paths still use `forceApprove(host) + exchange*(..., pretransferred=false)` so nested Standard Exchange (and similar hosts) measure an in-call pull. That was correct under in-call-only pretransfer; it is **obsolete** after BasicVault-family hosts implement durable `U = B − R`.

**Fix (program):**

1. **Nested fund:** `token.safeTransfer(host, amount)` → `host.exchange*(..., true)` on every pretransfer-flag host.
2. **DETF-local push:** each family Common’s `_pullToken` / `_secureTokenTransfer` uses `U = B − R` for **expected-hold** tokens; end every successful money route with hold-set sync **after** outer refund re-forward.
3. **Outer exact-out only:** re-forward **caller-paid** unused input to **DETF-entry `msg.sender`**, with `maxIn − used == balance-delta` assert.
4. **Host-first:** upgrade any still in-call-only IndexedEx nested host on `main` **before** migrating that call site.
5. **All nine production DETF family packages** migrate (DoD). Parallelize directory-disjoint slices under ≤3 live agents.

**Does not change:** DETF fees, thresholds, bond maturity, economics; Crane-vendored ports; absolute free credit law.

---

## 1. Locked product law (do not re-litigate)

Copy into every subagent prompt. Full text: PRD §1.1 / §4 / §9.

| ID | Implementer rule |
|----|------------------|
| **L-DETF-PUSH-NESTED** | Push + `pretransferred=true` for every nested `exchange*` (or equivalent with flag) on push-capable hosts. |
| **L-DETF-PUSH-GAS** | No `forceApprove`/`approve` to that host **for the pushed asset fund path**. Bond NFT / claim / non-push hosts may keep approve. |
| **L-DETF-ZERO-NESTED** | `amountIn == 0` → **skip entire nested call**. |
| **L-DETF-NESTED-REFUND** | Host refunds unused to `msg.sender` (= DETF). Host never refunds end user. |
| **L-DETF-REFUND-OUTER** | **Only outermost** DETF exact-out/burn re-forwards to entry `msg.sender`. Intermediate hops do not re-forward outward. |
| **L-DETF-REFUND-SCOPE** | Re-forward **caller-paid** unused input only — not arbitrary vault dust. |
| **L-DETF-EXACT-OUT-PARTIAL** | Partial `maxIn` is success: assert + re-forward; replace residual-hard-reverts. |
| **L-DETF-END-ORDER** | (1) nested calls (2) outer re-forward (3) full hold-set sync on post-re-forward balances. |
| **L-DETF-HOLD-SET** | Hold-set from **implemented residual inventory** (may be subset of processable; may be empty). Document in W0; register into MultiAsset for sync. |
| **L-DETF-LOCAL-PUSH** | DETF `pretransferred=true`: `claimed ≤ U = B − R`. Book via `MultiAssetBasicVaultRepo` where already used. |
| **L-DETF-LOCAL-PULL** | `false`: pull delta only; do not add prior unbooked `U`. |
| **L-DETF-LOCAL-I1** | Booked `R == B` + `true` without new push → `TransferDeltaInsufficient(claimed, 0)`. |
| **L-DETF-HOST-UPGRADE** | Host upgrade **on `main` first**, then call-site. No permanent `false`. No port edits. |
| **L-DETF-PARALLEL** | Worktrees + subagents; **≤3 concurrent** each. Queue overflow. One owner per family directory. |
| **L-DETF-TEST-EXPLICIT** | Dedicated T-NEST-1…8 + T-LOCAL-PUSH/I1 per family — not “suite still green.” |
| **L-DETF-NO-MOCK-SUT** | Production-first TestBases; no mock DETF/SE/manager/registry. |
| **L-DETF-NO-VIA-IR** | Forbidden. |
| **L-DETF-NO-PORT-EDITS** | No Crane-vendored / `contracts/external` reference rewrites. |
| **L-DETF-ROLE-NAMES** | `rateAsset`, `pairToken`, `underlyingVault` / `standardExchangeVault`, `vaultShare`, `detfToken`, `reservePool` / `reserveBpt`, `rebasingClaimToken`. |
| **L-DETF-PUSH-OPACITY** | No concrete SE vault type imports into DETF. |

### Forbidden

- Nested `forceApprove(host) + false` solely for pull-window (push-flag hosts)
- `transfer(host) + false` (double-fund)
- Intermediate hop re-forward as the only outer refund path
- Stranding outermost caller-paid unused input on DETF
- Absolute free credit / inventing second reserve map
- Editing ports; `via_ir`; SUT mocks
- Dual-owning a family Common or `detf/common/core/**` in parallel
- Spawning a **4th** live implementer subagent or worktree

---

## 2. Target CODE shape (per family)

### 2.1 Nested exchange-in (canonical)

```solidity
// amountIn_ == 0 → return / skip call (L-DETF-ZERO-NESTED)
tokenIn_.safeTransfer(address(host_), amountIn_);
amountOut_ = host_.exchangeIn(
    tokenIn_, amountIn_, tokenOut_, minOut_, recipient_, true, deadline_
);
// no forceApprove(host_, amountIn_) on this path
```

### 2.2 Nested exchange-out hop

```solidity
// Intermediate hops: push + true; host refunds unused to DETF; do NOT re-forward to outer caller
if (maxIn_ == 0) { /* skip entire nested call */ }
tokenIn_.safeTransfer(address(host_), maxIn_);
amountInUsed_ = host_.exchangeOut(
    tokenIn_, maxIn_, tokenOut_, amountOut_, recipient_, true, deadline_
);
```

### 2.3 Outermost exact-out re-forward (caller-paid token)

```solidity
// outerCaller = msg.sender at DETF entry (always)
// Isolate measure window carefully (no other tokenIn ops)
uint256 balBefore = tokenIn.balanceOf(address(this));
// ... final nested hop(s) consuming caller-paid tokenIn ...
uint256 refundFromReturn = maxIn - amountInUsed; // or equivalent
uint256 refundFromBal = tokenIn.balanceOf(address(this)) - balBefore;
require(refundFromReturn == refundFromBal); // mismatch → revert
if (refundFromReturn > 0) {
    tokenIn.safeTransfer(outerCaller, refundFromReturn);
}
// then _syncAllExpectedHoldReserves() (hold-set only)
```

### 2.4 DETF-local pull / push (inside each Common)

```solidity
// R from MultiAssetBasicVaultRepo (hold-set tokens)
// !pretransferred: pull; credit = balanceAfter - B0 only
// pretransferred: U = B0 - R; if claimed > U revert TransferDeltaInsufficient(claimed, U); credit = claimed
// End of successful money route: after outer re-forward, for T in EXPECTED_HOLD_SET: R[T] = balanceOf(T)
```

### 2.5 Family-local helper (recommended; not monorepo lib)

Small internal `_nestedExchangeInPush` / outer refund helper on Common is OK. **Do not** extract monorepo `SecurePullLib`.

### 2.6 Allowance cleanup

Remove dead nested fund-path approves. Keep bond NFT / claim / non-pretransfer host approves.

---

## 3. Waves and work packages

### 3.1 Wave diagram

```text
W0 INV ──► WH HOST (main) ──► WR BAL-SE (reference)
                                    │
                                    ▼
                         WP pool (≤3 concurrent worktrees/subagents):
                         BAL-MV | BAL-MB | BAL-CS | DUAL
                         U4-SE  | U4-CP  | U4-W  | U4-O
                                    │
                                    ▼
                              WT DOCS → ADV
```

### 3.2 Work package index

| WP | Slice | Wave | Mode |
|----|-------|------|------|
| WP-DETF-PUSH-0 | INV | W0 | Serial (orchestrator; read-only fan-out OK) |
| WP-DETF-PUSH-HOST | HOST | WH | Serial gate; optional ≤3 disjoint host sub-slices |
| WP-DETF-PUSH-BAL-SE | BAL-SE | WR | Serial reference |
| WP-DETF-PUSH-BAL-MV | BAL-MV | WP | Parallel pool |
| WP-DETF-PUSH-BAL-MB | BAL-MB | WP | Parallel pool |
| WP-DETF-PUSH-BAL-CS | BAL-CS | WP | Parallel pool |
| WP-DETF-PUSH-DUAL | DUAL | WP | Parallel pool |
| WP-DETF-PUSH-U4-SE | U4-SE | WP | Parallel pool |
| WP-DETF-PUSH-U4-CP | U4-CP | WP | Parallel pool |
| WP-DETF-PUSH-U4-W | U4-W | WP | Parallel pool |
| WP-DETF-PUSH-U4-O | U4-O | WP | Parallel pool |
| WP-DETF-PUSH-DOCS | DOCS | WT | Serial tail |
| WP-DETF-PUSH-ADV | ADV | WT | After families (may start BAL-SE ADV early if slot free) |

**LOCAL is not a separate WP** — implement DETF-local durable push **inside each family slice**.

---

## 4. Slice cards

### 4.0 INV — WP-DETF-PUSH-0

| Field | Value |
|-------|--------|
| **Owner** | Orchestrator (or single read-only worktree) |
| **Touch** | Docs only (this plan progress + inventory appendix). No production CODE. |
| **DoD** | Tables filled: nested site inventory; host push-readiness; per-family + per-host EXPECTED_HOLD_SET; final parallel touch-set confirmation |

**Normative greps:**

```bash
rg -n 'forceApprove|pretransferred=false|Nested SE' contracts/vaults/detf --glob '*.sol'
rg -n '\.exchangeIn\(|\.exchangeOut\(' contracts/vaults/detf --glob '*.sol'
rg -n '_pullToken|_secureTokenTransfer|_updateReserve|MultiAssetBasicVaultRepo' contracts/vaults/detf --glob '*.sol'
```

**Deliverable tables (fill during W0; templates below):**

#### Table A — Nested fund sites (seed; re-grep)

| File | Function / area | Host | Current pattern | Host reserve-delta? | Slice |
|------|-----------------|------|-----------------|---------------------|-------|
| `.../balancer/v3/standardExchange/single/*` | In/Out/Bond nested SE | `standardExchangeVault` | pull then exchange; migrate to push+true | Y if BasicVault SE (confirm) | BAL-SE |
| `.../multi-vault-weighted/*` | Leg `underlyingVaults[i].exchangeIn` | leg vaults | nested exchange | confirm | BAL-MV |
| `.../mixedBuffer/*` | Bonding nested false + forceApprove | leg vaults | forceApprove + false | confirm | BAL-MB |
| `.../stable/common/ComposedStableCommonDetfCommon.sol` | routed entry/exit, exit pricer, reserve router | multi-hop hosts | forceApprove + false | confirm per host | BAL-CS |
| `.../crossVersion/v2/*Exchange*Target.sol` | nested vault exchange | leg vaults | `false` | confirm | DUAL |
| `.../uniswap/v4/standardExchange/single/*` | nested SE + comments | SE | forceApprove + false | confirm | U4-SE |
| `.../constantProduct/single/*` | nested SE + hook | SE / reserveHook | forceApprove + false | confirm | U4-CP |
| `.../weighted/*` | SE + hook | SE / reserveHook | forceApprove + false | confirm | U4-W |
| `.../orbital/*` | dual SE + hook | SE / reserveHook | forceApprove + false | confirm | U4-O |

#### Table B — EXPECTED_HOLD_SET (per contract; fill in W0)

| Contract / family | Processable (`vaultTokens`) summary | **Hold-set (booked R)** | Notes (holds nothing?) |
|-------------------|-------------------------------------|-------------------------|------------------------|
| BAL-SE DETF | detfToken, seShare, reserveBpt (DFPkg) | **seShare + reserveBpt** (+ detfToken booked for I1 share burns) | end-sync full MultiAsset set |
| BAL-MV DETF | multi vaultShares + reserveBpt + detf | vaultShares[] + reserveBpt (+ detf I1) | MultiAsset init |
| BAL-MB DETF | buffer + vaultShares + reserveBpt | buffer residuals + reserveBpt | MultiAsset init |
| BAL-CS DETF | multi-hop vault tokens + reserve BPTs | residual inventory from DFPkg tokens_ | multi-hop; end-sync |
| DUAL vault | contents from DFPkg | hold-set = MultiAsset contents | sync helper on Common |
| U4-SE / U4-CP / U4-W / U4-O | pair/SE share/reserve LP tokens | DFPkg MultiAsset vaultTokens | subset OK; detf share I1 |
| Nested SE / hooks / exit pricers | SE full-set; hooks raw+pair (pair may virtual R) | SE: full-set; hooks: face pull + product sync | empty residual face OK |

#### Table C — Host readiness

| Host package / type | Used by slices | Durable push today? | WH action |
|---------------------|----------------|---------------------|-----------|
| BasicVault-family SE (UniV2/Aero/Camelot/Aave Stata, etc.) | BAL-*, U4-*, DUAL | **Y** (Waves 0–2 DONE) | None |
| Reserve entry / pool routers / exit pricers (CS) | BAL-CS | **Y** as IStandardExchangeIn hosts (SE-shaped / production packages) | Call-sites migrated push+true |
| Uni V4 reserve / buffer hooks | U4-CP, U4-W, U4-O | **Y** after WH | `_securePull` durable face U (virtual R > B → U=face) |

**Prerequisite check:** parent plan Wave 0–2 slices `common`, `se-*`, `rtr-*` **DONE** on `main` before WH/WR assume SE push works.

---

### 4.1 HOST — WP-DETF-PUSH-HOST

| Field | Value |
|-------|--------|
| **Wave** | WH |
| **Touch** | Only IndexedEx production host packages flagged in Table C as not push-ready. **Never** `contracts/external` / Crane ports. |
| **DoD** | Each blocked host lands durable push + tests on `main` before any dependent family slice starts |
| **Parallel** | ≤3 if host directories are disjoint; else serial |

Implement host upgrades using parent PRD law (`U = B − R`, full-set or documented hold-set sync). Prefer same patterns as BasicVault family when host is BasicVault-shaped.

---

### 4.2 Family slice template (BAL-SE and WP pool)

Every family slice implements **all** of:

1. Nested push + `true` on pretransfer-flag hosts  
2. DETF-local durable pull/push + hold-set end-sync (from W0 table)  
3. Outer refund re-forward where exact-out exists  
4. Zero-amount skip entire nested call  
5. Partial maxIn success path (no residual-hard-revert)  
6. Explicit tests T-NEST-1…8 + T-LOCAL-PUSH + T-LOCAL-I1  
7. Hermetic family suite green  
8. NatSpec / comments: remove “must use false for L-GAPS-9” on nested SE  

| Slice | Production root | Primary CODE | TestBase / hermetic acceptance (start here) |
|-------|-----------------|--------------|-----------------------------------------------|
| **BAL-SE** | `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/` | `*Common.sol`, `*ExchangeIn*`, `*ExchangeOut*`, `*Bonding*` | `forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/**'` |
| **BAL-MV** | `.../balancer/v3/multi-vault-weighted/` | Common + Bonding + Exchange* | `.../multi-vault-weighted/**` |
| **BAL-MB** | `.../balancer/v3/mixedBuffer/` | Common + Bonding + Exchange* | `.../mixedBuffer/**` |
| **BAL-CS** | `.../balancer/v3/stable/common/` | `ComposedStableCommonDetfCommon.sol`, Exchange*, OutQuery | `.../stable/common/**` |
| **DUAL** | `.../balancer/v3/uniswap/v4/crossVersion/v2/` | Common + ExchangeIn/Out targets | Hermetic if present; else `FOUNDRY_PROFILE=fork` path under `test/foundry/fork/**/crossVersion/v2/**` (document in slice notes) |
| **U4-SE** | `.../uniswap/v4/standardExchange/single/` | Common + ExchangeIn + Bonding | `.../uniswap/v4/standardExchange/single/**` |
| **U4-CP** | `.../uniswap/v4/standardExchange/constantProduct/single/` | Common + ExchangeIn + Bonding | `.../constantProduct/single/**` |
| **U4-W** | `.../uniswap/v4/standardExchange/weighted/` | Common + ExchangeIn/Out + Bonding | `.../weighted/**` |
| **U4-O** | `.../uniswap/v4/standardExchange/orbital/` | Common + ExchangeIn/Out + Bonding | `.../orbital/**` |

**Suggested WP fill order after WR** (reorder by Table C host readiness):

1. U4-SE, BAL-MV, BAL-MB  
2. U4-CP, DUAL, BAL-CS  
3. U4-W, U4-O  

---

### 4.3 BAL-SE reference detail (WR)

| Field | Value |
|-------|--------|
| **Why first** | Clearest Single-SE nested path; establishes LOCAL + nested push + test IDs |
| **CODE pattern** | See §2; mirror into other families |
| **Tests to add** | New file(s) under family hermetic path, e.g. `SingleStandardExchangeDETF_NestedPush.t.sol` (name flexible) covering T-NEST-1…8 + T-LOCAL-* |
| **DoD** | Grep clean for nested fund forceApprove+false on SE; explicit tests green; hermetic suite green; hold-set registered + end-sync |

---

### 4.4 DOCS — WP-DETF-PUSH-DOCS

| Doc | Change |
|-----|--------|
| This plan | Progress §9 updated |
| Parent reserve-delta plan | `detf-push` → **DONE** when program closes |
| Gap-closure plan / PRD notes | One-line supersession: nested SE push+true required; forceApprove+false was Wave 0–2 workaround |
| Family NatSpec / PRDs | Remove nested-false mandate; describe push+true |
| `CLONE_API_FREEZE.md` | Nested callers must push+true when host is reserve-delta |
| PRD | Already law; no re-open |

---

### 4.5 ADV — WP-DETF-PUSH-ADV

| Field | Value |
|-------|--------|
| **Scope** | Nested I1/I2, DETF-local I1, outer refund re-forward, no nested approve on fund path |
| **Placement** | Prefer per-family `adversarial/` under existing trees; catalog negatives green |
| **Timing** | After each family CODE is mergeable; can trail WP pool without blocking next family if slots allow |

---

## 5. Test matrix (explicit — L-DETF-TEST-EXPLICIT)

| ID | Assertion |
|----|-----------|
| **T-NEST-1** | Nested happy: push+true; host INV-R1 after op where host books reserves |
| **T-NEST-2** | Nested short: push &lt; claimed → host `TransferDeltaInsufficient(claimed, U)` |
| **T-NEST-3** | Nested I1: host booked, nested `true` without new push → revert |
| **T-NEST-4** | No nested approve for pushed asset on production fund path (static + runtime where practical) |
| **T-NEST-5** | Outermost exact-out: unused **caller-paid** input to **entry** `msg.sender`; return-value refund == balance delta |
| **T-NEST-6** | Outer re-forward completes before hold-set sync (post-re-forward `R == B` for hold-set) |
| **T-NEST-7** | Zero `amountIn`: nested host call **not** invoked |
| **T-NEST-8** | Partial `maxIn` succeeds (no residual-hard-revert on unused input) |
| **T-LOCAL-PUSH** | Transfer-to-DETF + `true` when `claimed ≤ U_detf`; after route hold-set `R == B` |
| **T-LOCAL-I1** | Booked DETF inventory + `true` without new push reverts |
| **T-ECON** | Representative mint/burn/bond within existing fee/rounding tolerances |

**Anti-theater:** hermetic suite green alone is **not** DoD without the T-NEST/T-LOCAL IDs above.

**Profiles:** default hermetic `forge test`. Fork only where family has no hermetic suite (document; DUAL may be fork-primary today). No `via_ir`.

---

## 6. Orchestrator protocol

### 6.1 Naming

| Item | Pattern | Example |
|------|---------|---------|
| Worktree | `.worktrees/fix_detf_push_<slice>` | `.worktrees/fix_detf_push_bal_se` |
| Branch | `fix_detf_push/<slice>` | `fix_detf_push/bal_se` |
| Commit | `fix_detf_push(<slice>): <imperative>` | `fix_detf_push(bal_se): nested push + local reserve` |

### 6.2 Worktree seed (non-negotiable)

```bash
# REPO = warm primary checkout; WT = worktree root
rsync -a "${REPO}/cache_forge/" "${WT}/cache_forge/"
rsync -a "${REPO}/out/" "${WT}/out/"
rm -rf "${WT}/lib/crane" && ln -s "${REPO}/lib/crane" "${WT}/lib/crane"
```

After green forge, copy `cache_forge/` + `out/` **back** to warm seed.

### 6.3 Forge patience (non-negotiable)

- Cold monorepo compile: **20–40+ minutes** is normal.
- **Never kill** `forge` / `solc` for “no progress.”
- Timeouts: **hours** (2–4h) for first compile.
- Prefer one long-running command + completion notification.

### 6.4 Concurrency

```text
W0:  serial INV
WH:  ≤3 only for disjoint HOST packages; else serial
WR:  serial BAL-SE (slots_free = 1)
WP:  slots_free = 3; queue BAL-MV, BAL-MB, BAL-CS, DUAL, U4-SE, U4-CP, U4-W, U4-O
WT:  DOCS serial; ADV without exceeding total ≤3 live with remaining WP
```

Never two agents on the same family directory or on `contracts/vaults/detf/common/core/**`.

### 6.5 Merge

1. Subagent completes + acceptance forge green in worktree  
2. Orchestrator: `git rebase main` in worktree  
3. Re-run acceptance if rebase non-trivial  
4. Fast-forward `main`  
5. Remove worktree; update §9 progress table  
6. Start next queued slice if slot free and host-ready  

---

## 7. Subagent prompt template

```text
You implement slice `<SLICE>` of
docs/vaults/DETF_NESTED_SE_PUSH_PRETRANSFER_IMPLEMENTATION_PLAN.md

Normative law ONLY:
docs/vaults/DETF_NESTED_SE_PUSH_PRETRANSFER_PRD.md §1.1 + §4 + §9

Hard rules:
- Nested fund: safeTransfer(host) + exchange*(..., true) on pretransfer-flag hosts
- amountIn == 0: skip entire nested call
- No forceApprove to host for pushed fund path
- Outermost exact-out only: refund = maxIn - used; require == balance delta; transfer entry msg.sender
- Intermediate hops: do NOT re-forward outward
- DETF-local: U = B - R; pull delta only on false; end-sync hold-set AFTER outer re-forward
- Hold-set from W0 table for this family (subset/empty OK); MultiAssetBasicVaultRepo
- No absolute free credit; shared TransferDeltaInsufficient
- No via_ir; no mock DETF/SE/manager/registry; no port edits
- No concrete SE vault imports into DETF
- DETF role names only
- Explicit T-NEST-1..8 + T-LOCAL-PUSH + T-LOCAL-I1
- Seed cache_forge + out before forge; never kill long forge/solc
- Touch only: <TOUCH_SET>
- DoD: <DOD>
- Acceptance: <FORGE_CMD>
- If nested host not push-ready: STOP with NEEDS_HOST (do not leave permanent false)

Do not reopen product OQs. If blocked by product ambiguity not in PRD, stop with NEEDS_OWNER.
```

---

## 8. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Host not push-ready | W0 Table C; WH first; family blocked until main has host |
| Multi-hop re-forward bugs | L-DETF-REFUND-OUTER; T-NEST-5 |
| Residual-hard-revert fights partial maxIn | L-DETF-EXACT-OUT-PARTIAL; T-NEST-8 |
| Hold-set = all vaultTokens by mistake | W0 CODE inventory; subset/empty documented |
| Dust-sweep scope creep | L-DETF-REFUND-SCOPE |
| Theater tests | L-DETF-TEST-EXPLICIT; reject “suite green only” |
| Dual edits to shared core | Serialize `detf/common/core` under orchestrator |
| Overload system | ≤3 worktrees + ≤3 subagents hard cap |
| Opacity / port edits | Reviewer reject list |
| Economics drift | No fee/threshold/bond changes in touch set |

---

## 9. Progress log (orchestrator updates)

| Slice | WP | Wave | Status | Commit / notes |
|-------|-----|------|--------|----------------|
| INV | WP-DETF-PUSH-0 | W0 | **DONE** | Tables A–C filled 2026-08-10; parent Waves 0–2 DONE; SE hosts Y; UniV4 hooks upgraded durable face pull |
| HOST | WP-DETF-PUSH-HOST | WH | **DONE** | Uni V4 buffer hooks `_securePull` → durable face U; SE BasicVault already Y |
| BAL-SE | WP-DETF-PUSH-BAL-SE | WR | **DONE** | Nested push+true; local U=B−R; hold-set sync; NestedPush.t.sol T-NEST/T-LOCAL |
| BAL-MV | WP-DETF-PUSH-BAL-MV | WP | **DONE** | Local durable pull + end-sync; nested SE already push+true |
| BAL-MB | WP-DETF-PUSH-BAL-MB | WP | **DONE** | Nested bonding push+true; local durable pull |
| BAL-CS | WP-DETF-PUSH-BAL-CS | WP | **DONE** | Nested vault/router/pricer push+true; local durable; partial exact-out residual hard-revert removed |
| DUAL | WP-DETF-PUSH-DUAL | WP | **DONE** | Nested push+true; local durable; NestedPush.t.sol under fork (FOUNDRY_PROFILE=fork) |
| U4-SE | WP-DETF-PUSH-U4-SE | WP | **REMOVED** | Listing-family Uni V4 Single SE DETF deleted (no liquidity-holding reserve); slice obsolete |
| U4-CP | WP-DETF-PUSH-U4-CP | WP | **DONE** | Nested SE push+true; local durable |
| U4-W | WP-DETF-PUSH-U4-W | WP | **DONE** | Nested SE+hook exchangeIn push+true; local durable |
| U4-O | WP-DETF-PUSH-U4-O | WP | **DONE** | Nested SE+hook exchangeIn push+true; local durable |
| DOCS | WP-DETF-PUSH-DOCS | WT | **DONE** | Progress §9; parent detf-push DONE; CLONE freeze supersession |
| ADV | WP-DETF-PUSH-ADV | WT | **DONE** | Nested I1/local I1 covered in NestedPush.t.sol + host durable I1 |

---

## 10. Definition of done (program)

1. All nine family slices **DONE** on `main` (BAL-SE + WP pool of 8).  
2. Grep-proven: no production nested fund path remains on `forceApprove` + `false` for push-flag hosts.  
3. Explicit T-NEST-1…8 + T-LOCAL-PUSH/I1 green per family.  
4. EXPECTED_HOLD_SET documented (W0) and synced in CODE for each family.  
5. Outer exact-out: assert + re-forward caller-paid unused to entry `msg.sender`; then hold-set sync.  
6. All required host upgrades on `main` before dependent call-sites.  
7. Hermetic (or documented fork) acceptance green; linear history.  
8. No port edits in diff.  
9. Docs supersede nested-false; parent plan `detf-push` **DONE**.  
10. Zero nested call skipped; partial maxIn success path shipped where exact-out exists.

---

## 11. First action (start here)

1. Confirm parent Waves 0–2 still green / SE push works for packages DETFs nest.  
2. Create worktree `fix_detf_push/inv` (or run on primary for docs-only W0); run greps; fill Tables A–C in this plan or a linked inventory appendix.  
3. Land WH host upgrades on `main` for any N readiness.  
4. Worktree `fix_detf_push/bal_se`; seed caches; implement BAL-SE; explicit tests; hermetic green; rebase → FF `main`.  
5. Fan out WP pool with **≤3** concurrent worktrees/subagents (suggested first batch: U4-SE, BAL-MV, BAL-MB).  
6. Complete remaining queue → DOCS → ADV.  

**Executor start command:**

> Execute `docs/vaults/DETF_NESTED_SE_PUSH_PRETRANSFER_IMPLEMENTATION_PLAN.md` Wave W0 (INV tables), then WH (HOST blockers), then WR (BAL-SE); seed `cache_forge` + `out`; never kill long forge/solc; max 3 concurrent implementer worktrees/subagents on the WP pool.

---

## 12. Approval

| Role | Expectation |
|------|-------------|
| Product | Law fixed in PRD; plan only sequences CODE/tests/docs |
| Implementer | Follow §2 CODE shape + §1 law; host-ready before call-site; explicit tests; ≤3 parallelism |
| Reviewer | Reject leftover nested forceApprove+false on push-flag hosts; stranded outer refunds; missing LOCAL push; theater tests; port edits; economics rewrites |
| Orchestrator | W0→WH→WR→WP→WT; linear history; progress in §9; never 4th live agent |

---

## 13. Cross-links

| Doc | Relation |
|------|----------|
| [`DETF_NESTED_SE_PUSH_PRETRANSFER_PRD.md`](./DETF_NESTED_SE_PUSH_PRETRANSFER_PRD.md) | Normative product law |
| [`BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md`](./BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md) | Host durable baseline |
| [`BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md`](./BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md) | Waves 0–2 prerequisite; Wave 3 `detf-push` |
| `docs/testing/coverage-audit/CLONE_API_FREEZE.md` | Nested caller push+true when host reserve-delta |
| `docs/agent/INDEXEDEX_AGENT_LAW.md` | Role names, opacity, production-first tests |
