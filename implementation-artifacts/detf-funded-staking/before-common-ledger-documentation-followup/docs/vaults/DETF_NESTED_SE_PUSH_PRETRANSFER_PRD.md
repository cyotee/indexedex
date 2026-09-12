# Product Requirements Document (PRD)

## Title

**DETF Nested SE Push Pretransfer** — migrate DETF → Standard Exchange (and equivalent nested money hosts) from `forceApprove` + `pretransferred=false` to **push + `pretransferred=true`**, now that BasicVault-family SE vaults implement reserve-delta (`U = B − R`)

---

## 1. Header

| Field | Value |
|-------|--------|
| **Status** | **READY-FOR-IMPLEMENTATION** (authorizes implementation plan + CODE) |
| **Kind** | Product-law refinement / gas + composition fix PRD |
| **Date** | 2026-08-10 |
| **Last clarified** | 2026-08-10 — owner Q&A #3 + CODE slice review: nine directory-disjoint family slices; MixedBuffer ≠ MultiVault; U4-CP ≠ U4-SE; LOCAL per-family; §6.1 parallel waves (W0→WH→WR BAL-SE→WP pool≤3→WT); outermost-only refund; host-on-main first; ≤3 subagents/worktrees |
| **Program role** | Completes **Wave 3 / WP-RSRV-3-DETF** (+ DualLiquidity/cross-version DETF trees) from [`BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md`](./BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md) |
| **Depends on** | Waves **0–2** of Basic Vault reserve-delta for BasicVault nested SE hosts. Nested hosts that still lack durable push must be upgraded **in IndexedEx production CODE** (not Crane-vendored reference ports) **on `main` before** the DETF call-site migrate for that host |
| **Normative parent** | [`BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md`](./BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md) §4 (SE reserve-delta) + §5.5 (deferred DETF push) |
| **Supersedes (nested pattern)** | Gap-closure “nested SE must stay `forceApprove` + `false`” — Wave 0–2 workaround only |
| **Does not reopen** | Absolute free credit (PAT-I-ABS); SE full-set sync law; DETF economics / fees / bond maturity |
| **Does not modify** | Crane-vendored / `contracts/external` **ported reference** protocol code — for reference and testing of production only. Change **IndexedEx DETF + nested host production** under this repo’s product packages |
| **Shared error** | `ISecurePullErrors.TransferDeltaInsufficient(claimed, observedDelta)` |
| **Primary skills** | `crane-testing`, `indexedex-testing`, `crane-adversarial-testing`, `indexedex-adversarial-testing` |
| **Worktree / branch prefix** | `fix_detf_push_` / `fix_detf_push/<family>` |
| **Merge model** | Worktree implementers → rebase onto `main` → fast-forward `main` (linear history). Prefer parallel family worktrees |
| **Parallelism law** | **Use git worktrees + subagents where possible** to expedite independent slices (inventory fan-out, host upgrades with disjoint touch sets, family migrates). **Hard cap: ≤3 concurrent worktrees and ≤3 concurrent subagents** at any time — do not overload the host (CPU/RAM/`forge`/solc). Queue additional slices; never spawn a fourth live implementer subagent. Same file/family Common must not be dual-owned. |
| **Follow-on plan** | [`DETF_NESTED_SE_PUSH_PRETRANSFER_IMPLEMENTATION_PLAN.md`](./DETF_NESTED_SE_PUSH_PRETRANSFER_IMPLEMENTATION_PLAN.md) — **READY TO EXECUTE** |

### 1.1 Locked product decisions (owner-clarified 2026-08-10; Q&A #3 folded in)

| ID | Decision | Law |
|----|----------|-----|
| **L-DETF-DOD-ALL** | **Definition of done = every production DETF family migrated** (including DualLiquidity / cross-version trees in `contracts/vaults/detf/**`). | No “MVP one family only” ship gate. Parallel worktrees + subagents allowed under **L-DETF-PARALLEL**; orchestrator rebases each onto `main` and FF-merges for linear history. |
| **L-DETF-PARALLEL** | Expedite with **worktrees and subagents** on independent slices. | **≤3 concurrent worktrees** and **≤3 concurrent live subagents** (project load law). Prefer subagents for disjoint family/host WPs after inventory and host readiness. Never two agents on the same family Common / shared file. Queue overflow; do not raise the cap. |
| **L-DETF-PUSH-NESTED** | Every production DETF path that funds a nested money host via **`exchangeIn` / `exchangeOut` (or family equivalent with a `pretransferred` flag)** **must** use **push then `pretransferred=true`** when the target supports push funding. | Hosts include **SE vaults, hooks, exit pricers, buffers, leg underlying vaults** — anything DETF calls that accepts token push + pretransfer. Canonical: `token.safeTransfer(host, amount)` → `host.exchange*(..., true)`. **Forbidden:** `forceApprove(host)` + `false` solely to create an in-call pull window. |
| **L-DETF-PUSH-C2C** | **Push is the standard contract-to-contract integration** whenever the target supports pretransfer/push. | Applies to **all** nested `exchange*` from DETF production CODE, not only “SE-shaped” diamonds. |
| **L-DETF-PUSH-ATOMIC** | Nested push + `true` only inside the same DETF money-route transaction that holds the tokens. | Protocol enforces host reserve-delta math; not extra cross-contract atomicity API. |
| **L-DETF-PUSH-CLAIMED** | Nested claimed amount must satisfy host law (`claimed ≤ U_host`). Prefer exact push of the amount claimed. | Unclaimed push surplus on a BasicVault host is **absorbed** by host end-sync (parent L-RSRV-ABSORB) — do not rely on host refund of `U − claimed`. |
| **L-DETF-NESTED-REFUND** | Nested host exact-out: host refunds unused credit to **`msg.sender` (= DETF)**. | Host must **not** refund the end user directly. Intermediate multi-hop nested exact-outs may leave unused input on DETF until the **outermost** DETF money-route path re-forwards (L-DETF-REFUND-OUTER). |
| **L-DETF-REFUND-OUTER** | **Only the outermost DETF exact-out / burn path** re-forwards unused **caller-paid** input to outer `msg.sender`. | Intermediate nested hops do **not** re-forward outward. **Outer path measure (normative):** `refund = maxIn − amountInUsed` from the nested (or final hop) return; **assert** `refund` equals the increase in `tokenIn.balanceOf(DETF)` over the isolated measure window; **mismatch → revert**. Then `tokenIn.safeTransfer(outerMsgSender, refund)` when `refund > 0`. |
| **L-DETF-REFUND-SCOPE** | Refund re-forward applies to **tokens the caller pays in** on that outer exact-out path. | Product does **not** require sweeping or booking dust of arbitrary unrelated tokens that may have been transferred to the vault. |
| **L-DETF-EXACT-OUT-PARTIAL** | Partial use of `maxIn` on exact-out is a **success** path. | Replace residual-after-exact-out reverts (e.g. “balance must be zero”) with refund assert + outer re-forward. Leftover **after** re-forward of the caller-paid refund still hard-fails. |
| **L-DETF-END-ORDER** | End of successful **outer** money route order is fixed. | (1) nested host call(s) (push+true; host may refund intermediate unused to DETF); (2) **outermost** refund re-forward of caller-paid unused input to outer `msg.sender` if any; (3) **full expected-hold reserve sync** (`R[T] = balanceOf(T)` for every booked hold-set token). Sync must observe **post-re-forward** balances. |
| **L-DETF-HOLD-SET** | Tokens booked in `R` come from **implemented residual inventory**, not implementer taste and not “all processable tokens.” | **`vaultTokens` / processable set** = tokens the vault **may process** on routes. **Expected-hold / booked set** = tokens the vault **actually retains as inventory** under implemented behavior. Hold-set **may be a subset** of processable vault tokens. There is **no** pre-existing canonical held-token registry — **this program must inventory** DETFs, nested vaults, hooks, exit pricers, buffers, and other money hosts and document what each **actually holds** (including hosts that hold **nothing** because the integrated protocol never leaves deposit tokens on the diamond). A held-token set/API may be added to ease implementation; membership still comes from CODE analysis. Register hold-set tokens into MultiAsset (or equivalent) so end-sync updates `R`. |
| **L-DETF-PUSH-GAS** | Nested hot path **must not** require ERC20 allowance from DETF → host for the pushed asset. | Eliminate nested `forceApprove`/`approve` to that host for the fund path. Approvals to **non-push hosts** (no pretransfer API: bond NFT, claim token, etc.) stay if product still needs them. |
| **L-DETF-PUSH-OPACITY** | DETF production talks only to **`IStandardExchange*` / share ERC-20 / documented reserve-host ABI**. | No concrete Uni/Aero/Camelot/Aave **vault implementation** imports into DETF. |
| **L-DETF-LOCAL-PUSH** | **DETF diamonds must support tokens pushed to them** (caller/router → DETF + `pretransferred=true`). | DETF-local `_pullToken` / `_secureTokenTransfer` **must** use **`U = B − R`** for **expected-hold** tokens (L-DETF-HOLD-SET). Book storage: **`MultiAssetBasicVaultRepo`** on DETF diamonds that already use that slot; do not invent a second reserve map. End every successful money route with full **expected-hold** sync **after** outer refund re-forward (L-DETF-END-ORDER). |
| **L-DETF-LOCAL-I1** | Booked DETF inventory (`R == B`) + `pretransferred=true` without new unbooked inflow → `TransferDeltaInsufficient(claimed, 0)`. | Shared error. No absolute free mint/extract. |
| **L-DETF-LOCAL-PULL** | `pretransferred=false` into DETF remains first-class (ERC20 pull / Permit2 as package already does). | Credit **pull delta only**; do not add prior unbooked `U` to pull credit. |
| **L-DETF-SHARE** | `detfToken` / `address(this)` share burns stay on existing self-burn / pretransfer-share paths — **not** nested-host reserve inventory accounting. | `detfToken` is **not** in expected-hold for ERC20 reserve-delta unless a family’s **implemented behavior** explicitly retains `detfToken` as inventory subject to I1 (document in that family’s hold-set table). Default: share burn paths stay self-burn; do not book `address(this)` as a free-credit inventory token. |
| **L-DETF-HOST-UPGRADE** | Nested host still in-call-only / missing durable push | **Mandatory:** upgrade IndexedEx production host to durable push **and land on `main` first**, then migrate DETF call site. Family call-site not DONE while its push-flag nested hosts still require `false`. **No** permanent `false` exceptions. **No** Crane port edits. |
| **L-DETF-ZERO-NESTED** | When nested `amountIn == 0` | **Skip the entire nested host call** (not only the transfer). Treat as no-op for that hop. |
| **L-DETF-REFUND-RECIPIENT** | Outer refund recipient | Always **DETF-entry `msg.sender`** for every money route (user `exchangeOut` / burn, compound, expansion, operator, protocol router). |
| **L-DETF-TEST-EXPLICIT** | Acceptance is not “suite still green by accident.” | **Explicit** T-NEST-1…8 and T-LOCAL-PUSH / T-LOCAL-I1 coverage **per family**. |
| **L-DETF-ROLE-NAMES** | DETF role names only. | `rateAsset`, `pairToken`, `underlyingVault` / `standardExchangeVault`, `vaultShare`, `detfToken`, `reservePool` / `reserveBpt`, `rebasingClaimToken`. |
| **L-DETF-NO-MOCK-SUT** | Production-first tests; no mocks of DETF SUT, nested SE SUT, manager, registry. | Crane/IndexedEx TestBases. |
| **L-DETF-NO-VIA-IR** | `via_ir` forbidden. | Default / fork profiles only. |
| **L-DETF-NO-PORT-EDITS** | **Do not change** Crane-vendored / external **ported reference** protocol code. | Only IndexedEx production DETF + IndexedEx nested host packages. Ports remain reference/testing aids. |
| **L-DETF-SCOPE-DUAL** | **DualLiquidity and cross-version DETF trees are in mandatory DoD.** | Same nested push + DETF-local push law. |
| **L-DETF-SCOPE-STANDALONE-CLONES** | Standalone Uni V3/V4 SE / Slipstream / EtherFi–Rocket packages **not consumed as DETF nested hosts** remain companion `clone-u4` / `clone-other`. | If DETF nests a host that lacks push support, **L-DETF-HOST-UPGRADE** applies (IndexedEx host only). |

---

## 2. Intent & problem statement

### 2.1 Intended product design

DETF money routes often:

1. Pull or mint inventory on the **DETF diamond** (`pairToken`, allowlisted underlyings, SE `vaultShare`, etc.).
2. Immediately **fund a nested SE** to mint/burn vault shares or swap legs.
3. Continue DETF accounting (mint `detfToken`, bond, claim routes, compound).

The intended nested pattern — matching SE routers and BasicVault reserve-delta — is:

```text
// tokens already on DETF (this)
token.safeTransfer(address(standardExchangeVault), amount);
standardExchangeVault.exchangeIn(token, amount, outToken, minOut, recipient, true, deadline);
//                                                     ^^^^ pretransferred
```

SE credits `amount` iff `amount ≤ U_se` after the transfer lands, then full-set syncs booked reserves. No DETF→SE allowance hop.

### 2.2 What went wrong / why `false` still exists

| Layer | Reality |
|-------|---------|
| **i-common / gap_cover** | SE pretransfer became **in-call-only** delta → outer transfer then nested `true` always saw `U = 0`. |
| **DETF fix (Wave 0–2 era)** | Nested paths switched to **`forceApprove` + `pretransferred=false`** so SE measured an in-window pull. Correct under broken SE law; **wrong long-term product**. |
| **Parent program Waves 0–2** | SE BasicVault family now implements durable **`U = B − R`** + full-set end-sync. Nested push + `true` is **correct and green** for routers. |
| **DETF still on workaround** | Production DETF CODE and comments still mandate nested `false` (e.g. Uni V4 single SE DETF, ComposedStable nested vault, weighted/orbital SE helpers). Extra SSTORE/approve gas; dual mental models. |

**Root cause (normative):** nested DETF→SE was frozen to pull-mode as a **temporary compatibility** fix. With SE reserve-delta shipped, that freeze must be lifted and CODE migrated.

### 2.3 Goals

1. Migrate **all production DETF families** (including DualLiquidity / cross-version) nested `exchange*` fund paths to **push + `pretransferred=true`** against every push-capable host (SE, hook, buffer, exit pricer, leg vault).
2. Remove nested **`forceApprove` / `approve` to those hosts** used only for the pull workaround.
3. Make **DETF diamonds accept push** (durable `U = B − R` + full expected-hold end-sync) so callers/routers can fund DETF with transfer + `true`.
4. On **outermost** DETF exact-out: **re-forward caller-paid unused input** from DETF to entry `msg.sender` (assert return-value refund == balance delta). Intermediate nested hops do not re-forward outward.
5. Keep **I1-safe** booked inventory on DETF and nested hosts for **documented hold-set** tokens; no absolute free credit.
6. Keep DETF **opacity** and **role names**; do not edit Crane-vendored port reference CODE.
7. **Explicit** T-NEST / T-LOCAL acceptance per family + green hermetic suites; linear git history via worktree rebase + FF `main`.
8. Document supersession of gap-closure nested-false mandate.
9. Inventory actual held inventory across DETFs / nested vaults / hooks / related money hosts (including “holds nothing”).

### 2.4 Non-goals

- Redesigning DETF fees, thresholds, bond maturity, seigniorage, or listing oracles.
- Editing **ported reference** code under Crane / `contracts/external` (use only as reference/tests of production).
- Reopening SE reserve-delta law or reintroducing absolute free credit.
- Frontend / Permit2 UX redesign beyond CODE required for push.
- Standalone clone packages never nested by DETF (`clone-u4` / `clone-other` companion) except when a DETF host upgrade is required.
- Formal verification / `via_ir`.

### 2.5 Success definition

| Criterion | Meaning |
|-----------|---------|
| **All DETFs** | Every production DETF family in inventory (incl. DualLiquidity/cross-version) migrated |
| **Nested push** | All nested `exchange*` fund paths use transfer-to-host + `true` on push-capable hosts |
| **No nested approve hop** | Production nested fund paths do not `forceApprove` the host for the pushed asset |
| **DETF-local push** | Transfer-to-DETF + `pretransferred=true` succeeds when `claimed ≤ U_detf`; booked I1 still holds |
| **Outer refund re-forward** | Outermost exact-out: host refunds DETF; DETF re-forwards **caller-paid** unused input to entry `msg.sender` (assert + transfer) |
| **I1 nested host** | Booked host inventory cannot free-credit via nested `true` without new push |
| **Pull intact** | Outer `pretransferred=false` into DETF still works (pull delta only) |
| **Hold-set documented** | Per-host / per-family EXPECTED_HOLD_SET from CODE inventory (may be subset of processable; may be empty) |
| **Family green** | Per-family hermetic acceptance **and** explicit T-NEST-1…8 + T-LOCAL-* green |
| **Host-before-call-site** | Push-host upgrades on `main` before family call-site migrate for that host |
| **Linear history** | Worktree → rebase `main` → FF `main` |
| **No port edits** | Diff excludes vendored reference protocol rewrites |
| **No accidental economics change** | Same fees/thresholds; funding pattern + outer refund re-forward only |

---

## 3. Scope

### 3.1 In scope — nested fund pattern (mandatory)

| Surface | Role |
|---------|------|
| DETF → any nested **vault / SE / hook / buffer / exit pricer** called via `exchangeIn` / `exchangeOut` (or equivalent with `pretransferred`) | Push + `true` when host has pretransfer/push support (upgrade host first if missing) |
| DETF-local `_pullToken` / `_secureTokenTransfer` + money-route end-sync | Durable `U = B − R` + full expected-hold sync (push-to-DETF) |
| Outermost exact-out refund re-forward | Host → DETF → entry `msg.sender` (caller-paid input only; intermediate hops do not re-forward outward) |
| Hold-set inventory | CODE review of DETFs, vaults, hooks, exit pricers, buffers, other money hosts — document actual held inventory (incl. empty) |
| IndexedEx production nested hosts that lack push support but are DETF-called | Upgrade host on `main` first (IndexedEx CODE only), then DETF call-site |
| Zero-amount nested hop | Skip entire nested call when `amountIn == 0` |
| Comments / NatSpec / gap-closure nested-false mandates | Rewrite to push standard |
| Family tests / TestBases | Explicit T-NEST-1…8 + T-LOCAL-*; transfer+true; outer refund; I1 booked |

### 3.2 In scope — DETF families (CODE-confirmed production trees)

**Nine directory-disjoint production packages** under `contracts/vaults/detf/protocols/dexes/**` (re-grep at execute; paths locked by CODE review 2026-08-10):

| Slice ID | Family tree | Production root (own Common / targets) | Nested fund pattern (today) |
|----------|-------------|----------------------------------------|-----------------------------|
| **BAL-SE** | Balancer V3 Single SE DETF | `.../balancer/v3/standardExchange/single/` | `standardExchangeVault.exchangeIn` after pull; nested false/approve sites in In/Bond/Out targets |
| **BAL-MV** | Balancer V3 MultiVault Weighted | `.../balancer/v3/multi-vault-weighted/` | Leg `underlyingVaults[i].exchangeIn`; own `_pullToken` |
| **BAL-MB** | Balancer V3 MixedBuffer MultiVault Stable | `.../balancer/v3/mixedBuffer/` | Leg buffer `underlyingVaults[i].exchangeIn` + nested-false comments; **separate tree from BAL-MV** |
| **BAL-CS** | Balancer V3 Composed Stable | `.../balancer/v3/stable/common/` | Underlying vault + pool router + exit pricer + reserve entry router; heavy `forceApprove` + `false` |
| **DUAL** | DualLiquidity cross-version Uni vault | `.../balancer/v3/uniswap/v4/crossVersion/v2/` | Nested `vault_.exchangeIn/Out(..., false)` + dual-local receive |
| **U4-SE** | Uni V4 Single SE DETF (**REMOVED**) | former `.../uniswap/v4/standardExchange/single/` | Listing-family draft deleted (no liquidity-holding reserve); do not reintroduce |
| **U4-CP** | Uni V4 CP Single SE DETF | `.../uniswap/v4/standardExchange/constantProduct/single/` | Nested SE + reserveHook paths; **separate Common from U4-SE** (files differ) |
| **U4-W** | Uni V4 Weighted SE DETF | `.../uniswap/v4/standardExchange/weighted/` | Nested SE legs + `reserveHook` / hook `exchangeIn` |
| **U4-O** | Uni V4 Orbital SE DETF | `.../uniswap/v4/standardExchange/orbital/` | Dual SE legs + `reserveHook` / hook paths |

**Not a separate monorepo LOCAL package:** each family owns `_pullToken` / `_secureTokenTransfer` on its Common (or stable `ComposedStableCommonDetfCommon`). DETF-local durable push is done **inside each family slice**, not a shared serial CODE WP.

**Shared CODE caution (serialize if edited):**

| Path | Notes |
|------|--------|
| `contracts/vaults/detf/common/core/**` | Shared libs (e.g. `DETFBondLifecycleLib` has reserve-pool `forceApprove` — not nested SE fund pattern by default). **Do not dual-edit** in parallel family slices. |
| `contracts/vaults/detf/common/claimToken/**`, `.../bondNft/**` | Component packages; only touch if nested-push law requires; serial if shared |
| `contracts/vaults/basic/**` / SE host packages | WP-HOST only; families consume via `IStandardExchange*` |

**Grep at plan start (normative for execute):**

```bash
rg -n 'forceApprove|pretransferred=false|Nested SE' contracts/vaults/detf --glob '*.sol'
rg -n '\.exchangeIn\(|\.exchangeOut\(' contracts/vaults/detf --glob '*.sol'
```

### 3.3 Out of scope (this PRD)

| Area | Note |
|------|------|
| Standalone Uni V3/V4 SE / Slipstream / EtherFi–Rocket **never nested by DETF** | Parent `clone-u4` / `clone-other` |
| Crane-vendored / `contracts/external` ported **reference** protocol CODE | Do not edit; reference/testing only |
| DETF fee / bond maturity / threshold economics redesign | Non-goal |
| Manager / registry architecture redesign | Prefer pattern-only; registry remains DFPkg deploy path |

### 3.4 Preconditions (hard)

1. Nested host supports **push pretransfer** (durable unbooked surplus or equivalent product law). If not, **upgrade IndexedEx production host and land on `main`** before migrating the DETF call site to `true`.
2. Nested host expected-hold / book includes tokens DETF pushes **when that host actually holds inventory** (empty hold-set hosts documented in WP-0).
3. DETF DFPkg registers **documented** expected-hold tokens for DETF-local `R` (hold-set from CODE inventory; may be subset of processable tokens).
4. Production-first TestBase can deploy DETF + nested hosts via manager registry.
5. Explicit T-NEST / T-LOCAL tests exist or are added with the family migrate (L-DETF-TEST-EXPLICIT).

---

## 4. Product law (normative)

### 4.1 Definitions

| Term | Definition |
|------|------------|
| **Nested SE** | Contract DETF calls via `IStandardExchangeIn` / `IStandardExchangeOut` (or family alias) to move inventory into/out of an SE vault diamond |
| **Push** | ERC20 balance increase on nested SE **before** the nested `exchange*` call returns into secure pull — typically `safeTransfer` from DETF to SE in the same DETF function |
| **Nested claim** | Amount argument DETF passes as SE `amountIn` / computed exact-out input |
| **DETF-local pull** | Secure credit of tokens into the DETF diamond from `msg.sender` (or Permit2), independent of nested SE |

### 4.2 Nested SE algorithm (canonical)

```text
// Inside DETF money route, after DETF holds `amount` of token T:

// 1) Optional: DETF-local pull already completed for this route
// 2) Push to nested SE
T.safeTransfer(address(se), amount);

// 3) Nested call — pretransferred=true
out = se.exchangeIn(
  T, amount, tokenOut, minOut, recipientOrThis, true, deadline
);
// or exchangeOut(..., true) with max/used per SE exact-out law

// 4) Do NOT forceApprove(se, amount) for T on this path
// 5) Do NOT pass false solely to create a pull window
```

**Nested exact-out (all hops) + outermost re-forward (L-DETF-NESTED-REFUND + L-DETF-REFUND-OUTER + L-DETF-END-ORDER):**

```text
// Every nested hop (incl. intermediate multi-hop):
if amountIn == 0:
  // L-DETF-ZERO-NESTED — skip entire nested call
  continue
T.safeTransfer(host, maxIn)   // when maxIn > 0
// Host refunds unused credit to msg.sender (= DETF), NOT end user
amountInUsed = host.exchangeOut(T, maxIn, tokenOut, amountOut, recipient, true, deadline)
// Intermediate hops: leave any unused T on DETF; do NOT re-forward to outer caller here

// Outermost DETF exact-out / burn path only (caller-paid tokenIn):
// outerCaller = msg.sender at DETF entry (user, operator, compound, router — always entry msg.sender)
balBefore = T.balanceOf(this)   // isolate window carefully around the outer measure
// ... final nested hop(s) that consume caller-paid T ...
refundFromReturn = maxIn - amountInUsed   // or equivalent unused caller-paid input
balAfter = T.balanceOf(this)
refundFromBal = balAfter - balBefore
require refundFromReturn == refundFromBal  // mismatch → revert (no silent choice)
if refundFromReturn > 0:
  T.safeTransfer(outerCaller, refundFromReturn)
// then full expected-hold sync (post-re-forward balances)
```

Do **not** change host refund recipient (always `msg.sender` of the host call = DETF). Do **not** skip the balance-delta assert on the **outer** re-forward path. Do **not** re-forward on intermediate hops only.

**Partial maxIn (L-DETF-EXACT-OUT-PARTIAL):** residual-after-exact-out reverts that forbid leftover input on DETF are **replaced** by assert + outer re-forward. Leftover after re-forward still hard-fails.

### 4.3 Forbidden nested patterns (post-migrate)

| Pattern | Why |
|---------|-----|
| `forceApprove(host)` + `exchange*(..., false)` for pull-window only | Gas waste; obsolete workaround |
| `transfer(host)` + `exchange*(..., false)` | Double-funds / wrong credit |
| Nested `true` without new unbooked push when host `R == B` | Correct I1; do not “fix” with absolute credit |
| Relying on host to refund unclaimed **push surplus** (`U − claimed`) | Host absorbs (parent L-RSRV-ABSORB) |
| Leaving **outermost** caller-paid exact-out unused input stranded on DETF | Must re-forward to entry `msg.sender` (intermediate hop residual until outer path is OK) |
| Re-forwarding intermediate hop refunds to the end user | Only outermost path re-forwards (L-DETF-REFUND-OUTER) |
| Residual-after-exact-out hard-revert instead of refund assert + re-forward | L-DETF-EXACT-OUT-PARTIAL |
| Calling nested host when `amountIn == 0` | L-DETF-ZERO-NESTED — skip entire call |
| Importing concrete SE vault types into DETF | Opacity break |
| Editing Crane-vendored port reference CODE | L-DETF-NO-PORT-EDITS |
| Equating hold-set with full processable `vaultTokens` without CODE inventory | L-DETF-HOLD-SET |

### 4.4 DETF-local pull / push (mandatory — L-DETF-LOCAL-PUSH + L-DETF-HOLD-SET)

```text
// _pullToken / _secureTokenTransfer on DETF diamond (caller → DETF)
// R book lives in MultiAssetBasicVaultRepo (or equivalent) for hold-set tokens only
R = bookedReserve(token)
B0 = token.balanceOf(this)

if !pretransferred:
  pull from msg.sender
  credit = balanceAfter - B0   // pull delta only
else:
  U = B0 - R
  if claimed > U: revert TransferDeltaInsufficient(claimed, U)
  credit = claimed

// End of every successful DETF money route (L-DETF-END-ORDER):
// 1) nested calls  2) outermost refund re-forward (caller-paid)  3) sync hold-set only:
for each token T in EXPECTED_HOLD_SET(family):   // implemented inventory — may be subset of processable vaultTokens
  R[T] = balanceOf(T)
```

**Hold-set vs processable set (normative):**

| Set | Meaning | Source of truth |
|-----|---------|-----------------|
| **Processable (`vaultTokens`)** | Tokens the vault **may process** on routes | DFPkg / package routing config |
| **Expected-hold (booked `R`)** | Tokens the vault **actually retains as inventory** and must protect with I1 | **Implemented behavior** of that contract’s money routes — **not** a pre-existing canonical registry |

**Hold-set rules (owner Q&A #3):**

1. Hold-set **may be a subset** of processable vault tokens (not every processable token is held).
2. There is **no** canonical held-token set today. Execute plan **must inventory** DETFs, nested vaults, hooks, exit pricers, buffers, and other money hosts and document what each **actually holds**. Some hosts hold **nothing** because the integrated protocol never leaves deposit tokens on the diamond — document that as empty hold-set.
3. A held-token set/API may be added to ease implementation; membership still comes from CODE analysis, not implementer defaults.
4. Register documented hold-set tokens into the reserve book used by end-sync. Expanding processable `vaultTokens` is only required when the package must also **route** that token — not merely because it is held.
5. **Refund scope is separate:** product only requires re-forwarding **caller-paid** unused input on the outer exact-out path (L-DETF-REFUND-SCOPE). Do **not** invent a dust-sweep of every random token that may have been transferred to the vault.

### 4.5 Relationship to parent / host law

| Layer | Baseline for `pretransferred=true` |
|-------|-------------------------------------|
| Nested BasicVault SE / buffer | Durable `U = B − R` + full-set end-sync (parent PRD §4) |
| Nested hook / exit pricer / other host | Host durable push law; upgrade IndexedEx host if missing |
| DETF diamond user/router pretransfer | Durable `U = B − R` on DETF expected-hold (§4.4) |

### 4.6 Testing law (anti-theater)

| ID | Required |
|----|----------|
| **T-NEST-1** | Nested happy: push+true; host INV-R1 after op where host books reserves |
| **T-NEST-2** | Nested short: push &lt; claimed → host `TransferDeltaInsufficient(claimed, U)` |
| **T-NEST-3** | Nested I1: host booked, nested `true` without new push → revert |
| **T-NEST-4** | No nested approve for pushed asset on production fund path (push-flag hosts) |
| **T-NEST-5** | **Outermost** exact-out: unused **caller-paid** input returns to **entry** `msg.sender`; production path asserts return-value refund == balance delta (mismatch reverts). Intermediate hops do not re-forward outward |
| **T-NEST-6** | End order: outer refund re-forward completes before full hold-set sync (post-re-forward `R == B` for hold-set) |
| **T-NEST-7** | Zero `amountIn`: nested host call is **not** invoked |
| **T-NEST-8** | Partial `maxIn` exact-out succeeds via refund assert + re-forward (no residual-hard-revert on unused input) |
| **T-LOCAL-PUSH** | Transfer-to-DETF + `true` when `claimed ≤ U_detf`; after route `R == B` for hold-set |
| **T-LOCAL-I1** | Booked DETF inventory + `true` without new push reverts |
| **T-ECON** | Representative mint/burn/bond within existing family fee/rounding tolerances |

**Anti-theater (L-DETF-TEST-EXPLICIT):** each family WP DoD requires **dedicated** tests for the T-NEST / T-LOCAL IDs above — not merely “hermetic suite still green” after the pattern change.

---

## 5. CODE shape (locked design intent)

### 5.1 Before → after (illustrative)

**Before (workaround):**

```solidity
uint256 pulled_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
tokenIn_.forceApprove(address(s.standardExchangeVault), pulled_);
vaultShares_ = s.standardExchangeVault.exchangeIn(
    tokenIn_, pulled_, s.standardExchangeVaultShare, 0, address(this), false, deadline_
);
```

**After (product):**

```solidity
uint256 pulled_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
tokenIn_.safeTransfer(address(s.standardExchangeVault), pulled_);
vaultShares_ = s.standardExchangeVault.exchangeIn(
    tokenIn_, pulled_, s.standardExchangeVaultShare, 0, address(this), true, deadline_
);
```

Same for burn legs that push `vaultShare` into SE for exit routes. On **outermost** exact-out, re-forward caller-paid unused input to entry `msg.sender` (§4.2). When `amountIn == 0`, **skip the entire nested call** (L-DETF-ZERO-NESTED).

### 5.2 Shared helper (recommended, not mandatory monorepo lib)

Families may add small internal helpers to avoid drift:

```solidity
function _nestedExchangeInPush(
    IStandardExchangeIn host_,
    IERC20 tokenIn_,
    uint256 amountIn_,
    IERC20 tokenOut_,
    uint256 minOut_,
    address recipient_,
    uint256 deadline_
) internal returns (uint256 amountOut_) {
    if (amountIn_ == 0) {
        return 0; // L-DETF-ZERO-NESTED — skip entire nested call
    }
    tokenIn_.safeTransfer(address(host_), amountIn_);
    amountOut_ = host_.exchangeIn(
        tokenIn_, amountIn_, tokenOut_, minOut_, recipient_, true, deadline_
    );
}

// Nested exact-out hop: push + true; host refunds unused to DETF.
// Intermediate hops: do NOT re-forward to outer caller.
// Outermost path only: refund = maxIn - amountInUsed;
// require(refund == balAfter - balBefore); if (refund > 0) transfer entry msg.sender;
// then full expected-hold sync.
```

**Do not** extract a monorepo SecurePullLib. Nested helper is pattern-only.

### 5.3 Allowance cleanup

After migration, remove dead `forceApprove` to SE on that path. If a subsequent non-SE call still needs approve (router, hook, claim), keep **those** approvals only.

### 5.4 DualLiquidity / buffer legs

Treat each leg vault as nested SE when it is a reserve-delta SE. Push per leg; do not batch-approve all legs “for convenience” if push-per-call is the law.

---

## 6. Work packages (for execute plan)

| ID | Slice | Work | DoD |
|----|-------|------|-----|
| **WP-DETF-PUSH-0** | INV | Grep nested `exchange*` + `forceApprove`; host push-readiness; **EXPECTED_HOLD_SET** for DETFs + nested vaults/hooks/exit pricers/buffers | Inventory + hold-set + slice readiness tables in execute plan |
| **WP-DETF-PUSH-HOST** | HOST | IndexedEx nested hosts still in-call-only / missing durable push that DETFs call | Upgrade landed on **`main` first** (no port edits; no permanent false). Sub-slices only if host touch sets are directory-disjoint |
| **WP-DETF-PUSH-BAL-SE** | BAL-SE | **Reference family:** nested push + DETF-local durable pull/push + outer refund re-forward | Explicit T-NEST-1…8 + T-LOCAL-*; hermetic green |
| **WP-DETF-PUSH-BAL-MV** | BAL-MV | MultiVault Weighted only (`multi-vault-weighted/`) | Per-leg push+true; T-NEST/T-LOCAL; hermetic green |
| **WP-DETF-PUSH-BAL-MB** | BAL-MB | MixedBuffer only (`mixedBuffer/`) — **not** same slice as BAL-MV | Per-leg push+true; T-NEST/T-LOCAL; hermetic green |
| **WP-DETF-PUSH-BAL-CS** | BAL-CS | Composed Stable (`stable/common/`) nested vaults / routers / exit pricers | Nested push; outermost-only re-forward; explicit tests |
| **WP-DETF-PUSH-DUAL** | DUAL | DualLiquidity cross-version (`crossVersion/v2/`) | Nested push + dual-local; T-NEST/T-LOCAL |
| **WP-DETF-PUSH-U4-SE** | U4-SE | Uni V4 Single only (`standardExchange/single/`) | Nested SE push; explicit tests |
| **WP-DETF-PUSH-U4-CP** | U4-CP | Uni V4 CP Single only (`constantProduct/single/`) — **not** same slice as U4-SE | Nested SE + hook paths as applicable; explicit tests |
| **WP-DETF-PUSH-U4-W** | U4-W | Uni V4 Weighted (`weighted/`) | Nested SE/hook; explicit tests |
| **WP-DETF-PUSH-U4-O** | U4-O | Uni V4 Orbital (`orbital/`) | Nested SE/hook; explicit tests |
| **WP-DETF-PUSH-DOCS** | DOCS | Supersede nested-false mandate; parent plan `detf-push` DONE | Docs consistent |
| **WP-DETF-PUSH-ADV** | ADV | Nested + DETF-local I1 + outer refund adversarial (may fan per family after CODE) | Catalog negatives green |

**LOCAL is not a separate parallel WP:** implement DETF-local `U = B − R` + hold-set end-sync **inside each family slice** (each Common already has `_pullToken` / `_secureTokenTransfer`). Reference BAL-SE establishes the pattern; other families copy the law, not a shared monorepo lib.

### 6.1 Parallel slices (CODE-confirmed; normative for orchestrator)

#### Serial vs parallel waves

| Wave | Mode | Slices | Notes |
|------|------|--------|-------|
| **W0** | **Serial** (orchestrator) | INV (WP-0) | Produce inventory, hold-set tables, host-readiness, final touch-set check. Read-only fan-out OK; no CODE race. |
| **WH** | **Serial gate** / optional parallel sub-slices | HOST | Land push-capable hosts on `main` **before** any family that nests them. Parallelize only **directory-disjoint** host packages (≤3). If one host package is shared by many DETFs, one serial HOST owner. |
| **WR** | **Serial** reference | **BAL-SE** | First family migrate: nested push + LOCAL + outer refund + full T-NEST/T-LOCAL suite. Pattern for others. |
| **WP** | **Parallel pool** (≤3 live) | **BAL-MV ∥ BAL-MB ∥ BAL-CS ∥ DUAL ∥ U4-SE ∥ U4-CP ∥ U4-W ∥ U4-O** | Eight family slices; **all production roots are directory-disjoint** (no shared family Common). Queue beyond 3. Start a family only when **its** nested hosts are push-ready on `main`. |
| **WT** | **Serial tail** (or 1 ADV after last family batch) | DOCS → ADV | Docs after all families (or progressive). ADV may run after WR for BAL-SE, then extend per family; do not exceed ≤3 live with WP. |

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

#### Parallel-safe matrix (family slices)

| Slice | Own production root | Parallel with other WP-pool families? | Typical nested hosts (confirm in W0) |
|-------|---------------------|----------------------------------------|--------------------------------------|
| **BAL-SE** | `balancer/v3/standardExchange/single/` | Reference first (WR); not in WP pool until done | `standardExchangeVault` (IStandardExchange); reserve router for BPT paths |
| **BAL-MV** | `balancer/v3/multi-vault-weighted/` | **Yes** vs all other WP-pool slices | Leg `underlyingVaults[i]` |
| **BAL-MB** | `balancer/v3/mixedBuffer/` | **Yes** (disjoint from BAL-MV) | Leg buffer/SE `underlyingVaults[i]` |
| **BAL-CS** | `balancer/v3/stable/common/` | **Yes** | Underlying vault, pool router, exit pricers, reserve entry router |
| **DUAL** | `balancer/v3/uniswap/v4/crossVersion/v2/` | **Yes** | Nested leg vaults via `exchangeIn/Out` |
| **U4-SE** | former `uniswap/v4/standardExchange/single/` | **Removed** | Listing-family draft deleted |
| **U4-CP** | `uniswap/v4/standardExchange/constantProduct/single/` | **Yes** (disjoint from U4-SE) | Nested SE + `reserveHook` paths |
| **U4-W** | `uniswap/v4/standardExchange/weighted/` | **Yes** | Nested SE legs + `reserveHook` / hook |
| **U4-O** | `uniswap/v4/standardExchange/orbital/` | **Yes** | Dual SE + `reserveHook` / hook |

#### Ownership / conflict rules (must hold for parallel)

1. **One owner per family directory** — never two agents on the same `*Common.sol` or family root.  
2. **No parallel edits** to `contracts/vaults/detf/common/core/**` or other shared DETF common packages; if a shared edit is required, serialize under orchestrator (single worktree).  
3. **HOST before call-site** for that family’s nested pretransfer-flag hosts (L-DETF-HOST-UPGRADE).  
4. **≤3 concurrent worktrees and ≤3 concurrent live subagents** (L-DETF-PARALLEL). Prefer worktree-isolated subagents per slice.  
5. **Suggested WP fill order after WR** (priority, not hard): `U4-SE`, `BAL-MV`, `BAL-MB` (high nested-false comment density / simpler SE) → `U4-CP`, `DUAL` → `BAL-CS`, `U4-W`, `U4-O` (hooks / multi-hop). Reorder by W0 host readiness.  
6. **Rebase → FF `main`** per completed worktree before starting the next queued slice if slots full.

#### Example concurrent batches (≤3)

| Batch | Live slices (example) | Queued |
|-------|----------------------|--------|
| After WR | U4-SE, BAL-MV, BAL-MB | BAL-CS, DUAL, U4-CP, U4-W, U4-O |
| Next | BAL-CS, DUAL, U4-CP | U4-W, U4-O |
| Next | U4-W, U4-O, (ADV start if ready) | — |

**Concurrency (L-DETF-PARALLEL — non-negotiable):**

| Rule | Law |
|------|-----|
| **Worktrees** | One worktree per independent family/host slice; rebase → FF `main` |
| **Subagents** | Prefer subagents (or worktree-isolated subagents) for parallel WP-pool slices |
| **Hard cap** | **≤3 concurrent worktrees** and **≤3 concurrent live subagents** — do not overload this system (CPU/RAM/`forge`/solc). Queue the rest |
| **Ownership** | Never two agents on the same family Common file or overlapping touch set |
| **When** | WP-pool family only after W0 inventory **and** after that family’s nested hosts are push-ready on `main` |

**Merge gate (L-DETF-HOST-UPGRADE):** host upgrade FF to `main` **before** family call-site migrate for that host. Family WP not DONE while any of its pretransfer-flag nested hosts still require `forceApprove` + `false`.

---

## 7. Documentation deliverables

| Doc | Change |
|-----|--------|
| This PRD | Product law for DETF nested push |
| Parent [`BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md`](./BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md) | Point Wave 3 `detf-push` at this PRD; status READY when execute plan exists |
| `docs/testing/TEST_COVERAGE_GAP_CLOSURE_IMPLEMENTATION_PLAN.md` / PRD notes | One-line supersession: nested SE push+true is **required** when host is reserve-delta; forceApprove+false was Wave 0–2 workaround only |
| Family PRDs / NatSpec on nested helpers | Describe push+true; remove “must use false for L-GAPS-9” on nested SE |
| Execute plan | [`DETF_NESTED_SE_PUSH_PRETRANSFER_IMPLEMENTATION_PLAN.md`](./DETF_NESTED_SE_PUSH_PRETRANSFER_IMPLEMENTATION_PLAN.md) — touch sets, forge filters, DoD per WP |

---

## 8. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Nested host not reserve-delta yet | WP-0 inventory; **WP-HOST upgrade on `main` first**; family call-site blocked until ready |
| Intermediate multi-hop re-forward confusion | Only outermost path re-forwards (L-DETF-REFUND-OUTER); T-NEST-5 |
| Exact-out refund recipient confusion | Host refunds DETF; outer path re-forwards to **entry** `msg.sender` always; T-NEST-5 |
| Residual-hard-revert fights partial maxIn | L-DETF-EXACT-OUT-PARTIAL + T-NEST-8 |
| Over-push absorb on SE | DETF pushes exact claimed; under-claim surplus absorbed by SE — document; do not expect SE refund of U−claimed |
| Hold-set equated to all vaultTokens | WP-0 CODE inventory of actual holdings; hold-set may be subset or empty |
| Dust-sweep scope creep | L-DETF-REFUND-SCOPE — only caller-paid outer unused input |
| Missed forceApprove site | Grep inventory + T-NEST-4 |
| Theater tests | L-DETF-TEST-EXPLICIT — dedicated T-NEST/T-LOCAL per family |
| DETF-local I1 regression | Explicit T-LOCAL-I1; do not weaken booked inventory |
| Opacity break | Reject PRs importing concrete SE vault contracts into DETF |
| Gas / stack in helpers | Prefer small internal helper; no via_ir |

---

## 9. Closed decisions (no implementer defaults)

| ID | Decision |
|----|----------|
| **OQ-1** | DETF-local durable push: **yes** (`U = B − R`) |
| **OQ-2** | Nested hosts: **every host with a pretransfer flag** (SE/vault/hook/buffer/exit-pricer/`exchange*`); upgrade IndexedEx host if missing durable push; allowance-only hosts without pretransfer stay approve until they gain the flag |
| **OQ-3** | Ship gate: **all** DETF families incl. DualLiquidity/cross-version |
| **OQ-4** | Nested host refund: host → DETF (`msg.sender`). **Outer re-forward:** host → DETF → **entry** `msg.sender` on **outermost** path only |
| **OQ-5** | Outer refund measure: **`maxIn − amountInUsed` with balance-delta assert** (mismatch reverts) |
| **OQ-6** | Hold-set: **implemented residual inventory** from CODE inventory of DETFs/vaults/hooks/etc.; **may be subset** of processable `vaultTokens`; may be empty; optional held-set API for ease — membership not implementer taste |
| **OQ-7** | In-call-only nested host: **upgrade IndexedEx host on `main` first**, then family call-site (no permanent exceptions; no port edits) |
| **OQ-8** | End order: **outer refund re-forward → full hold-set sync** |
| **OQ-9** | Zero-amount nested: **skip entire nested call** when `amountIn == 0` |
| **OQ-10** | Permit2 DETF→host: not required (ERC20 transfer) |
| **OQ-11** | Crane-vendored ports: do not edit |
| **OQ-12** | Multi-hop: **only outermost** DETF exact-out/burn re-forwards; intermediate hops do not re-forward outward |
| **OQ-13** | Partial maxIn: **success** via refund assert + outer re-forward; replace residual-hard-reverts |
| **OQ-14** | Refund scope: **caller-paid** unused input only — not arbitrary vault dust |
| **OQ-15** | Outer refund recipient: **always DETF-entry `msg.sender`** (incl. compound/operator/router) |
| **OQ-16** | Test DoD: **explicit** T-NEST-1…8 + T-LOCAL-PUSH/I1 **per family** (hermetic green alone insufficient) |
| **OQ-17** | Parallelism: use **worktrees + subagents** to expedite; hard cap **≤3 concurrent worktrees and ≤3 concurrent live subagents** (no overload) |

---

## 10. Definition of done (this program)

1. **All** production DETF families (incl. DualLiquidity/cross-version) migrated.  
2. Grep-proven: no production nested fund path remains on `forceApprove` + `false` workaround for push-flag hosts.  
3. Nested fund paths use push + `true`; **explicit** T-NEST-1…8 green on **each** family.  
4. DETF-local push + booked I1 green (**explicit** T-LOCAL-PUSH / T-LOCAL-I1); per-family / per-host EXPECTED_HOLD_SET documented from CODE inventory and synced.  
5. **Outermost** exact-out: return-value refund **equals** balance delta (assert); re-forward **caller-paid** unused input to **entry** `msg.sender`; then hold-set sync. Intermediate hops do not re-forward outward.  
6. Every in-call-only / non-push nested host DETF calls is upgraded on `main` (IndexedEx) **before** that call site is DONE.  
7. Family hermetic acceptance green **and** explicit T-NEST/T-LOCAL suite green; linear history on `main`.  
8. No Crane-vendored port reference rewrites in the diff.  
9. Docs supersede nested-false mandate; parent plan `detf-push` **DONE**.  
10. Zero-amount nested hops skip the entire host call; partial maxIn succeeds via refund assert + re-forward.

---

## 11. First action (executor)

Execute the plan: W0 INV → WH HOST → WR BAL-SE → WP pool (≤3) → WT DOCS/ADV.

**Executor start command:**

> Execute `docs/vaults/DETF_NESTED_SE_PUSH_PRETRANSFER_IMPLEMENTATION_PLAN.md` Wave W0 (INV tables), then WH (HOST blockers), then WR (BAL-SE); seed `cache_forge` + `out`; never kill long forge/solc; max 3 concurrent implementer worktrees/subagents on the WP pool.

---

## 12. Approval

| Role | Expectation |
|------|-------------|
| Product | Nested push+true on all pretransfer-flag hosts; DETF accepts push; **outermost** caller-paid refund re-forward; hold-set from CODE inventory; all DETFs |
| Implementer | Follow §4–5; host-on-main before call-site; worktree + subagent parallelism under **L-DETF-PARALLEL** (≤3 live); rebase + FF main; no port edits; no absolute free credit; no via_ir; no SUT mocks; explicit T-NEST/T-LOCAL |
| Reviewer | Reject leftover nested forceApprove+false on push-flag hosts; reject stranded **outer** caller-paid refunds; reject intermediate-only re-forward as the sole outer path; reject missing DETF-local push; reject theater tests; reject economics rewrites |
| Orchestrator | Follow §6.1 waves; inventory + hold-set first; host upgrades before family slices; **spawn ≤3 concurrent subagents/worktrees** over the WP pool of 8 (queue the rest); never dual-own family directories or `detf/common/core`; rebase → FF linear history |

---

## 13. Cross-links

| Doc | Relation |
|------|----------|
| [`BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md`](./BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md) | SE durable baseline; §5.5 deferred DETF push **superseded for execution by this PRD** |
| [`BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md`](./BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md) | Waves 0–2 DONE prerequisite; Wave 3 `detf-push` points here |
| `docs/testing/coverage-audit/CLONE_API_FREEZE.md` | BasicVault family law; nested callers must match push+true when using pretransfer |
| `docs/agent/INDEXEDEX_AGENT_LAW.md` | DETF role names, opacity, production-first tests |
