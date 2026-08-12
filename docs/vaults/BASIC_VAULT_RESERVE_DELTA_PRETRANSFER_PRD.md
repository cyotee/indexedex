# Product Requirements Document (PRD)

## Title

**Basic Vault Reserve-Delta Pretransfer** — restore durable `reserveOfToken` last-accounted snapshot as the secure baseline for `pretransferred=true` push funding, implemented once in `BasicVaultCommon` so Standard Exchange vaults inherit correct behavior

---

## 1. Header

| Field | Value |
|-------|--------|
| **Status** | **READY-FOR-IMPLEMENTATION** (authorizes implementation plan + CODE) |
| **Kind** | Fix / product-law refinement PRD |
| **Date** | 2026-08-10 |
| **Last clarified** | 2026-08-10 — owner decisions §1.1 + OQ-2/OQ-5 closed (full-set sync; no production underflow product error) |
| **Primary CODE home** | `contracts/vaults/basic/BasicVaultCommon.sol` |
| **Primary storage** | `MultiAssetBasicVaultRepo` / `BasicVaultRepo` (`reserveOfToken` / `_reserveOfToken`, same slot) |
| **Shared error** | `contracts/interfaces/ISecurePullErrors.sol` → `TransferDeltaInsufficient(claimed, observedDelta)` |
| **Supersedes (semantics)** | In-call-only `balBefore` pretransfer baseline from `gap_cover(i-common)` **for vaults that book `reserveOfToken`** — see §4.3 |
| **Does not reopen** | Absolute `balanceOf >= claimed` free credit (PAT-I-ABS) |
| **Related law** | L-GAPS-9/10 (credit claimed iff delta-sufficient; shared error); L-CLAIM-3; CLONE_API_FREEZE (to be amended) |
| **Diagnosis context** | Transfer-before-call + `pretransferred=true` fails with `TransferDeltaInsufficient(claimed, 0)` after i-common; `reserveOfToken` was never wired into `_secureTokenTransfer` |
| **Primary skills** | `crane-testing`, `indexedex-testing`, `crane-adversarial-testing`, `indexedex-adversarial-testing` |
| **Worktree / branch prefix** | `fix_reserve_delta_` (e.g. `fix_reserve_delta/common`) |
| **Follow-on plan** | [`BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md`](./BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md) — execute Waves 0–2; this PRD remains product law only |

### 1.1 Locked product decisions (owner-clarified 2026-08-10)

These override any earlier “default if silent” / open-question language in this document.

| ID | Decision | Law |
|----|----------|-----|
| **L-RSRV-CALLER** | **Any caller** may pass `pretransferred=true`. No principal-only / router-only gate in this program. | Expectation (off-chain / integrator discipline): use `true` only inside an **atomic** fund+call (same transaction). The protocol does **not** enforce atomicity on-chain beyond reserve-delta math. |
| **L-RSRV-SYNC-WHEN** | Reserve is synced at the **end of each successful money workflow**, for tokens the vault is **expected to hold**. | A Solidity `modifier` cannot return route outputs, so **do not** rely on a wrapper modifier for post-return sync. Each vault route **must** call sync helpers at the end of its workflow (after refunds). |
| **L-RSRV-SYNC-ROUTES** | **Every route that changes vault reserve balances** must end-sync — not only paths that call `_secureTokenTransfer`. | Includes **deposits**, **withdrawals**, and any other op that mutates booked ERC20 inventory (compound, harvest, rebalance, fee-compound, zap, etc.). View-only / pure quote paths do **not** sync. |
| **L-RSRV-SYNC-WHICH** | Sync **only** tokens the vault is **expected to hold** (see §4.4 hold-set). | Do **not** attempt to book arbitrary unrelated ERC20s. |
| **L-RSRV-HOLD-SET** | Expected-hold = **underlying tokens used as vault reserve**, plus package-known **retained inventory** that must be protected. | **Always:** pair / rate / constituent underlyings registered for the vault. **Also when the package holds them:** liquidity-sleeve assets (e.g. EtherFi-style sleeve), and dust / residual balances **pending compounding or rebalance** (e.g. Aerodrome, Uniswap V3/V4). Those must be **synced end-of-op so they are booked and cannot free-credit** via `pretransferred=true`. **Not in book:** vault share token (`address(this)` / `detfToken`); share burns use existing self-burn / refund paths, not reserve-delta inventory accounting. |
| **L-RSRV-ABSORB** | When `claimed < unbooked` (or push > claimed) and the op succeeds, **unclaimed surplus is absorbed into `R` at end sync** — not refunded. | **Caller fault.** Protocol does **not** refund unclaimed push surplus. Only exact-out style `claimed/max > used` uses `_refundExcess`. |
| **L-RSRV-COMPOUND-DUST** | Dust **retained for later compounding / rebalance** is included in **end-of-op reserve sync**. | Book it into `R` after every successful money op that leaves it on the vault. Protected by I1; not free pretransfer credit. |
| **L-RSRV-DUST** | Leaving some balances **unbooked** (not synced, or not yet synced) intentionally allows a later `pretransferred=true` claim to **use that dust as funding**. | **Desired crude recovery method** for stranded / donated inventory on claimable tokens that are **not** yet part of a completed sync — not a bug to close. Does **not** override L-RSRV-COMPOUND-DUST for package-known retained compound dust. |
| **L-RSRV-BOOTSTRAP** | At init, `reserveOfToken` defaults to **0**. Any live balance is fully unbooked until claimed or absorbed by a later sync. | **Desired.** Seed / deploy inventory may be claimed via first atomic push-style `true` or absorbed when a later op syncs. |
| **L-RSRV-DETF-W0** | **Wave 0 does not** migrate DETF nested SE to push. | Leave DETF as **`forceApprove` + `pretransferred=false`** until Wave 3. **Wave 3 product law:** [`DETF_NESTED_SE_PUSH_PRETRANSFER_PRD.md`](./DETF_NESTED_SE_PUSH_PRETRANSFER_PRD.md) (push + `true` once SE reserve-delta is live). |
| **L-RSRV-UNIT-SUT** | Wave 0 unit law is proven on a **minimal BasicVault-family diamond** (package + deploy path), not a one-off SE-only harness. | Implement reserve-delta **once** in `BasicVaultCommon` (+ helpers); SE/package inheritors reuse it. Unit suite under `test/foundry/spec/vaults/basic/**` is the canonical law surface (WP-RSRV-0 / 0c). |
| **L-RSRV-SYNC-FULL** | At end of **every** successful money route, sync the **full expected-hold set** to `balanceOf` for each booked token. | Not route-touched-only. Minimizes miss-sync bugs and implementer judgment. Accept extra SSTOREs. |
| **L-RSRV-NO-UNDERFLOW-BRANCH** | **No** production-time dedicated `B < R` product path (no `ReserveAccountingUnderflow`, no intentional assert branch). | `B < R` only arises from **incorrect** vault implementation (missed sync, inverted refund/sync, bad outflows, non-conforming token book). Catch via **tests** that enforce INV-R1 after every money route — not a designed runtime recovery/error API. Implementers compute `U = B - R` normally; do **not** add a special underflow error type or silent clamp. |

---

## 2. Intent & problem statement

### 2.1 Intended product design (owner)

Standard Exchange vaults and routers are designed for a **gas-efficient push model**:

1. At the **end** of a successful money operation, the vault stores a **booked** token balance in `reserveOfToken[token]` (last-accounted snapshot).
2. A caller (user or router) may **push** ERC20 tokens to the vault (`transfer` / Permit2 to vault address).
3. The caller invokes `exchangeIn` / `exchangeOut` with **`pretransferred=true`**.
4. The vault credits **`claimed` only if**  
   `claimed ≤ balanceOf(vault) − reserveOfToken[token]`  
   (unbooked inbound since last snapshot), then consumes tokens and **re-syncs** `reserveOfToken` at end of op.
5. When **`pretransferred=false`**, the vault **pulls** (ERC20 allowance, else Permit2), credits the actual inbound amount (FoT-safe), and still re-syncs reserves for tokens it books.

This avoids an extra hop (caller → router → vault pull) when the funder can push once to the destination vault, while still **not** treating absolute inventory as free credit.

### 2.2 What went wrong

| Layer | Reality |
|-------|---------|
| **Storage** | `BasicVaultRepo` / `MultiAssetBasicVaultRepo` define `reserveOfToken` and `_updateReserve` for this purpose. |
| **Secure pull** | `BasicVaultCommon._secureTokenTransfer` **never** read or wrote `reserveOfToken`. |
| **Pre-i-common** | `pretransferred=true` used **absolute** `balanceOf >= claimed` → push “worked,” but **PAT-I-ABS free inventory credit** was possible. |
| **i-common (`gap_cover`)** | Replaced absolute check with **in-call** `balBefore`/`balAfter` only. That correctly blocks free **booked** inventory when no in-window pull occurs, but also makes **transfer-before-call push always delta 0**. |
| **Overrides** | Aerodrome (and peers) document “same as BasicVaultCommon”; compound dust/`excessToken*` is separate and must **not** free-credit. |
| **Callers** | Balancer V3 SE router still does `_transferTokenIn(vault)` + `exchange*(..., true)` — correct under reserve-delta, broken under in-call-only. |
| **Tests** | Mix of stale absolute happy paths, I1 theater inversions, and valid router e2e that now fail. |

**Root cause (normative):** incomplete wiring of last-accounted snapshot into secure pull, then a security cutover that closed free credit **without** completing the durable-snapshot push path.

This is **not** “the vault failed to notice an in-call transfer.” Classic push lands **before** the vault’s current in-call window. The bug/gap is **missing `reserveOfToken` baseline + mandatory end-of-op sync**.

### 2.3 Goals

1. Implement **reserve-delta pretransfer** once in `BasicVaultCommon` so inheriting SE commons get correct push semantics.
2. Keep **I1** for **booked** inventory: if `balanceOf == reserveOfToken` and no pull, `observedDelta == 0` → `TransferDeltaInsufficient(claimed, 0)`.
3. Keep **no absolute free credit** and **no exact-delta grief** (credit exactly `claimed` when `claimed ≤ delta`).
4. Make **router push + `true`** work without `forceApprove` on the hot path (gas goal).
5. Require **full expected-hold end-sync** on **every money route** (L-RSRV-SYNC-ROUTES / L-RSRV-SYNC-FULL / L-RSRV-HOLD-SET); leave **unrelated** ERC20s unsynced (L-RSRV-DUST).
6. **Absorb** unclaimed push surplus into `R` (L-RSRV-ABSORB); book retained compound/rebalance dust into `R` (L-RSRV-COMPOUND-DUST).
7. **No** production `B < R` product error — catch broken accounting with INV-R1 tests (L-RSRV-NO-UNDERFLOW-BRANCH).
8. Amend clone law / CLONE_API_FREEZE so package clones match reserve-delta (or explicitly document non-BasicVault packages).
9. Green the known failure cluster (Aerodrome / UniV2 / Balancer SE router / refund / Aave SE pretransfer) under the **new** law, without greenwashing **booked** free mint (I1).
10. Keep DETF nested pull workflow in Wave 0; schedule DETF push refactor as a later wave (L-RSRV-DETF-W0).
11. Prove Wave 0 unit law on a **minimal BasicVault-family diamond** reused as the canonical surface (L-RSRV-UNIT-SUT).

### 2.4 Non-goals

- Reintroducing absolute `balanceOf >= claimed` without subtracting booked reserve.
- Redesigning DETF economics, fees, or bond maturity.
- Full rewrite of every package-local `_pullToken` in the first wave (see §6 waves); Wave 0 is BasicVaultCommon + SE inheritors.
- Making `pretransferred=true` the only supported EOA path (pull remains first-class).
- Formal verification / `via_ir`.
- Frontend / Permit2 UX redesign beyond vault/router CODE needed for the law.
- Using Aerodrome `_excessToken*` / compound dust as pretransfer credit (explicitly forbidden).

### 2.5 Success definition

| Criterion | Meaning |
|-----------|---------|
| **Push works** | Transfer (or Permit2) tokens **to vault**, then `exchange*(..., pretransferred=true)` with `claimed ≤ unbooked` succeeds and credits exactly `claimed`. |
| **I1 booked** | After reserves synced, inventory with **no new unbooked inflow** + `true` → `TransferDeltaInsufficient(claimed, 0)`. |
| **I2 short** | `claimed > (balance − reserve)` → shared error with exact args. |
| **I3 residual (synced tokens)** | After a successful op that **syncs** token `T`, leftover unclaimed balance of `T` (including under-claimed push) is **absorbed** into `R` (L-RSRV-ABSORB) → cannot fund a second `true` claim without a **new** unbooked inflow. No refund of `U − claimed`. |
| **Compound / sleeve dust booked** | Retained compound/rebalance residuals and package sleeve inventory are in expected-hold and end-synced → I1 protected (L-RSRV-COMPOUND-DUST / L-RSRV-HOLD-SET). |
| **Dust recovery** | Unsynced / not-yet-synced / non-expected-hold unbooked surplus on claimable tokens **may** fund `true` (L-RSRV-DUST); tests must not treat that as a failure. |
| **Pull intact** | `pretransferred=false` still pulls ERC20 then Permit2; returns observed pull delta (FoT-safe). |
| **All money routes full-set sync** | Every money path end-syncs the **full** expected-hold set (L-RSRV-SYNC-ROUTES / L-RSRV-SYNC-FULL). |
| **Inheritance** | UniV2 / Camelot / Aerodrome / Aave Stata SE commons inherit without reintroducing absolute credit; Aerodrome override does not bypass reserve-delta. |
| **Router** | Balancer V3 SE router push + `true` passes deposit / pass-through / batch tests **without** changing product intent to approve+pull-only. |
| **DETF Wave 0** | Nested DETF → SE remains approve + `false` (L-RSRV-DETF-W0). |
| **Unit SUT** | Minimal BasicVault-family diamond proves law once under `test/.../vaults/basic/**` (L-RSRV-UNIT-SUT). |
| **Docs** | CLONE_API_FREEZE + agent law pointers describe reserve-delta for BasicVault-family pulls. |

---

## 3. Scope

### 3.1 In scope — canonical implementation

| Artifact | Role |
|----------|------|
| `contracts/vaults/basic/BasicVaultCommon.sol` | Canonical `_secureTokenTransfer`, `_refundExcess` interaction, reserve sync helpers |
| `contracts/vaults/basic/MultiAssetBasicVaultRepo.sol` | Primary booked-balance storage API used by SE DFPkgs (`_reserveOfToken`, `_updateReserve`) |
| `contracts/vaults/basic/BasicVaultRepo.sol` | Same storage slot / layout family; keep API consistent; avoid dual semantics |
| `contracts/interfaces/ISecurePullErrors.sol` | Unchanged error type (reuse) |
| SE commons inheriting `BasicVaultCommon` | Uni V2, Camelot V2, Aerodrome V1, Aave V3 Stata (and any other direct inheritor) |
| Aerodrome `_secureTokenTransfer` override | Align with super / delete divergence; excess dust must not free-credit |
| End-of-op reserve sync call sites | **Every** route that changes vault reserve balances (deposits, withdrawals, compound, rebalance, harvest, etc.) under BasicVaultCommon inheritors — L-RSRV-SYNC-ROUTES |
| Minimal BasicVault-family diamond (Wave 0 SUT) | Canonical unit-test deploy path for law proofs; implement once, reuse across packages (L-RSRV-UNIT-SUT) |
| Tests under `test/foundry/spec/vaults/basic/**` | Unit law for reserve-delta, I1–I3, push happy, pull happy, absorb, compound-dust booked |
| Affected SE + router specs | Fix expectations to reserve-delta law; green known failures |

### 3.2 In scope — callers that rely on push

| Artifact | Role |
|----------|------|
| `BalancerV3StandardExchangeRouter*` ExactIn/Out/batch | Keep transfer-to-vault + `pretransferred=true` **if** vault law supports it after this PRD |
| Nested DETF → SE | **Wave 0: leave as-is** (`forceApprove` + `false`). **Later wave:** refactor DETFs to push + `true` (L-RSRV-DETF-W0) |

### 3.3 Related but separate (later waves / clones)

| Area | Note |
|------|------|
| DETF `_pullToken` / package-local secure pull | Wave 0: nested SE stays pull (`false`). **Later dedicated wave:** DETF push workflow + optional DETF-local booked baseline. |
| Uni V4 SE, Slipstream, hooks CP/Dual/buffers | Peer implementations; amend CLONE checklist; do not block Wave 0 SE. |
| ERC4626 `lastTotalAssets` | Different accounting surface; do not conflate without explicit design. |
| Public `reserveOfToken()` views that intentionally return 0 (e.g. some hook packages) | Must not break product views; internal pull may need package-local booked state. |

### 3.4 Storage layout note (implementers)

`BasicVaultRepo` and `MultiAssetBasicVaultRepo` both use:

```text
STORAGE_SLOT = keccak256(abi.encode("indexedex.vaults.basic"))
struct { AddressSet tokens; mapping(address => uint256) reserveOfToken; }
```

Field naming differs (`reserveOfToken` vs `_reserveOfToken`); **slot layout is aligned**. Wave 0 must use **one** library for BasicVaultCommon (recommend **`MultiAssetBasicVaultRepo`**, matching SE DFPkg init). Do not invent a third mapping for the same purpose.

---

## 4. Product law (normative)

### 4.1 Definitions

| Term | Definition |
|------|------------|
| **Booked reserve** | `R = MultiAssetBasicVaultRepo._reserveOfToken(token)` |
| **Live balance** | `B = token.balanceOf(address(this))` |
| **Unbooked surplus** | `U = B − R` (Solidity 0.8 checked arithmetic). On a **correct** vault after successful money ops, `B ≥ R` always holds for expected-hold tokens (INV-R1). No dedicated product error for `B < R` (L-RSRV-NO-UNDERFLOW-BRANCH). |
| **Claimed** | Caller-provided `amountIn` / computed exact-out `amountIn` passed into secure pull |
| **Credit** | Amount returned from `_secureTokenTransfer` and used by the route |

### 4.2 Secure pull algorithm (BasicVaultCommon)

```text
// _secureTokenTransfer(token, claimed, pretransferred)

R = _reserveOfToken(token)
B0 = token.balanceOf(this)
// No dedicated B < R product branch (L-RSRV-NO-UNDERFLOW-BRANCH).
// Correct vaults maintain B >= R via end-of-op full-set sync (tests enforce INV-R1).

if !pretransferred:
    // Pull: ERC20 allowance first, else Permit2 (existing order)
    pull claimed from msg.sender
    B1 = token.balanceOf(this)
    pullDelta = B1 - B0
    // FoT-safe credit for pull path:
    credit = pullDelta
    // Do NOT free-credit prior unbooked U into credit; only what this pull delivered.
    // Unbooked U remains for a later pretransfer or absorb (§4.4).
    return credit

// pretransferred == true
// Durable snapshot baseline (NOT in-call balBefore alone):
U = B0 - R
if claimed > U:
    revert TransferDeltaInsufficient(claimed, U)
credit = claimed
// Do not credit surplus (U - claimed); leave it unbooked until end sync / later claim
return credit
```

**Notes:**

1. **Push before call works** because push increases `B0` without increasing `R`, so `U` includes the push.
2. **Booked inventory does not free-credit** because when fully synced `B0 == R` and no push, `U == 0`.
3. **In-call-only `balBefore` is insufficient** for the product push model; it remains useful only as a **component** of the pull branch (`B1 − B0`).

### 4.3 Credit and short rules (unchanged spirit of L-GAPS-9/10)

| Rule | Requirement |
|------|-------------|
| Short delivery | `claimed > U` → `TransferDeltaInsufficient(claimed, U)` (pretransfer) |
| Credit amount | Exactly `claimed` when pretransfer succeeds |
| No exact-delta grief | `U > claimed` does **not** revert; surplus stays unbooked until sync/absorb |
| Pull path | Return actual pull delta; may be `< claimed` (FoT) |
| Absolute `B >= claimed` without `U` | **FORBIDDEN** |
| Unclaimed push surplus (`claimed < U`) | **Absorb** into `R` at end sync (L-RSRV-ABSORB). **Do not** refund `U − claimed`. Caller error. |
| Retained compound / rebalance dust | **Book into `R`** at end-of-op sync (L-RSRV-COMPOUND-DUST). Not free pretransfer credit after sync. |
| Package-known sleeve / residual inventory | Part of expected-hold; synced and protected (L-RSRV-HOLD-SET). |

### 4.4 End-of-op reserve sync (mandatory) — L-RSRV-SYNC-WHEN / L-RSRV-SYNC-ROUTES / L-RSRV-SYNC-WHICH / L-RSRV-HOLD-SET

**When:** At the **end of each successful money workflow** (after DEX/mint/burn and after `_refundExcess`), not mid-pull and not via a return-value `modifier` (modifiers cannot surface route return values; L-RSRV-SYNC-WHEN).

**Which routes (L-RSRV-SYNC-ROUTES):** **Every route that results in a change to vault reserve balances** — deposits, withdrawals, and any other balance-mutating money path (compound, harvest, rebalance, fee-compound, zap, settle, etc.). Not limited to routes that call `_secureTokenTransfer`. View-only / pure quote paths do not sync.

**Which tokens (L-RSRV-SYNC-WHICH / L-RSRV-HOLD-SET):** Tokens the vault is **expected to hold**:

| Include in sync (expected-hold) | Exclude from sync |
|---------------------------------|-------------------|
| **Underlying reserve tokens** — pair / rate / constituent underlyings registered for the vault (`vaultTokens` / MultiAsset init list) | Arbitrary airdropped / unrelated ERC20s the vault does not book |
| **Liquidity-sleeve assets** when the package holds them as inventory (e.g. EtherFi-style sleeve tokens) | Tokens only ever in flight if the package explicitly does not book them |
| **Dust / residuals pending compounding or rebalance** (e.g. Aerodrome, Uniswap V3/V4) — **must be synced** so they are protected (L-RSRV-COMPOUND-DUST) | **Vault share token** (`address(this)` / product share) — not reserve inventory; use self-burn / refund paths |
| Any other package-known retained ERC20 inventory that must not free-credit | |

**What to sync (L-RSRV-SYNC-FULL — locked):** at end of **every** successful money route, sync the **full expected-hold set** (`_updateReserve(T, T.balanceOf(this))` for each expected-hold token). Do **not** implement route-touched-only sync. Missing any expected-hold token is a ship blocker.

After a successful route for booked token `T`:

```text
// Preferred simple sync (hot path):
_updateReserve(T, T.balanceOf(this))
```

**Semantics of simple sync:**  
Post-op live balance becomes the next op’s booked baseline. Any **uncredited** unbooked surplus remaining on a **synced** token is **absorbed into the book without minting** (L-RSRV-ABSORB). That is the primary **I3 / residual** control for synced tokens:

- Caller pushes 100, claims 60, op completes with 40 still on vault → sync sets `R = B = 40` → second `true` claim of 40 **without a new push** → `U == 0`. Residual cannot free-credit after sync. **Do not refund** the unclaimed 40; caller under-claimed (L-RSRV-ABSORB).
- If op spends claimed amount and unused was refunded via `_refundExcess` (exact-out: `max/claimed > used` only), sync at final balance.
- Retained compound dust left on vault after the op is included in that final `balanceOf` → booked into `R` (L-RSRV-COMPOUND-DUST).

**Unrelated / not-yet-synced balances (L-RSRV-DUST — desired, not a bug):**

- Tokens **outside** the expected-hold set, or balances **not yet synced** after an inflow (e.g. bootstrap, mid-tx before end sync), keep `U = B − R` available to fund a later `pretransferred=true` claim on a route that accepts that token.
- That is an intentional **crude recovery** path for stranded donations on claimable tokens. Do **not** “fix” it by forcing sync of every ERC20 that ever appears on the vault.
- It does **not** license leaving package-known compound/sleeve dust unbooked after a successful money op (L-RSRV-COMPOUND-DUST / L-RSRV-HOLD-SET win).
- I1 tests must use **booked** inventory (`R` synced to `B`), not “deal tokens and never sync.”

**Refund interaction (`pretransferred=true`):**

| Case | Behavior |
|------|----------|
| Exact-out: `maxAmount/claimed > used` | `_refundExcess` returns unused **credited** amount to recipient, **then** sync |
| Push surplus: `U > claimed`, op uses ≤ claimed | **No** refund of `U − claimed`; absorb into `R` at sync (L-RSRV-ABSORB) |
| Order | Refund (if any) **before** final sync |

**When not to sync to full `balanceOf`:**  
Packages whose public `reserveOfToken` is an **economic** reserve (e.g. effective liquidity) distinct from ERC20 `balanceOf` must **not** blindly overwrite that meaning. For BasicVault-family SE that treat `reserveOfToken` as ERC20 book, full balance sync is correct. Document exceptions per package in the plan; default for this PRD is **ERC20 book = `balanceOf` after op**.

### 4.5 Invariants

| ID | Invariant |
|----|-----------|
| **INV-R1** | After **every** successful money op, for **every** expected-hold token `T`: `R(T) == balanceOf(T)` (full-set sync, L-RSRV-SYNC-FULL). |
| **INV-R2** | Never credit `claimed` when `claimed > max(0, B − R)`. |
| **INV-R3** | `B < R` must **not** occur on a correctly implemented vault. Enforced by INV-R1 tests after every money route — **not** by a dedicated production underflow error API (L-RSRV-NO-UNDERFLOW-BRANCH). Never silent-clamp. |
| **INV-R4** | Package-known retained inventory (compound dust, rebalance residuals, liquidity sleeves) that remains on the vault after a successful money op **must** be included in `R` for those tokens (L-RSRV-COMPOUND-DUST / L-RSRV-HOLD-SET). |
| **INV-R5** | Vault share token is **not** required to satisfy INV-R1 under this program; share lifecycle uses burn/refund paths. |

### 4.6 Callers, atomicity, donation / dust / absorb (locked)

| Policy | Locked choice |
|--------|----------------|
| **Who may pass `pretransferred=true`?** | **Any caller** (L-RSRV-CALLER). No on-chain principal-only / router-only restriction in this program. |
| **Atomicity** | **Integrator expectation:** fund (push) and `exchange*` with `true` in the **same transaction**. The vault enforces only reserve-delta math, not “same-tx as push” beyond that. |
| **Can unbooked surplus `U` fund `true`?** | **Yes** — same mechanism as intentional push (required for transfer-before-call). Also crude recovery for **not-yet-synced** / **non-expected-hold** inventory (L-RSRV-DUST). |
| **After an op syncs token `T`** | Leftover unclaimed `T` (including under-claimed push) is **absorbed** into `R` (no mint, no refund of unclaimed surplus — L-RSRV-ABSORB). Further `true` on `T` needs new unbooked inflow. |
| **Retained compound / sleeve dust** | Synced into `R` end-of-op → **I1 protected** (L-RSRV-COMPOUND-DUST). |
| **I1 still means** | **Booked** inventory (`U == 0` after sync) cannot free-credit. Tests that only `deal`/transfer without booking are testing unbooked funding / recovery, **not** I1. |

**Anti-theater:** I1 tests must set `R` to match inventory (via sync after setup or direct storage) so inventory is **booked**, then call `true` with no new push.

### 4.7 Pull path vs unbooked surplus

If `U > 0` and caller uses `pretransferred=false`:

- Pull still measures **only** `B1 − B0` from the pull.
- Prior `U` is **not** added to pull credit (prevents double-counting donation as “pulled”).
- End-of-op sync books remaining live balance (absorbing unused `U` without minting).

### 4.8 Relationship to i-common / L-GAPS-9

| i-common rule | This PRD |
|---------------|----------|
| No absolute free credit | **Kept** (must use `U = B − R`, not `B >= claimed` alone) |
| Credit exactly claimed when sufficient | **Kept** |
| Shared `TransferDeltaInsufficient` | **Kept** |
| `observedDelta` definition | **Refined:** for `pretransferred=true`, `observedDelta := U = B − R` (last-accounted), not in-call `balAfter − balBefore` alone |
| Nested forceApprove + false | **Still valid**; not mandatory for SE entry if push + true works |
| Theater transfer+true without booked baseline | **Becomes valid happy path** when push creates `U` |

**CLONE_API_FREEZE** must be amended in the same program so clones do not re-implement pure in-call-only pretransfer for BasicVault-family packages.

### 4.9 Init / first deposit (L-RSRV-BOOTSTRAP)

On vault deploy / package init:

- Tokens registered via `_initialize(vaultTokens)` (expected-hold set).
- `reserveOfToken[token]` defaults to **0**.
- Any live balance is fully unbooked: `U = B − 0 = B`.
- First `pretransferred=true` may claim up to full live balance of a claimable token — **desired** (bootstrap / seed recovery), not a defect.
- After first successful op that **syncs** that token, INV-R1 holds for that token.
- Tests that need I1 immediately after setup must **sync** (or set `R = B`) before the free-credit attempt.

---

## 5. API & CODE shape (implementation guidance)

### 5.1 BasicVaultCommon (canonical)

Add internal helpers (names illustrative):

```solidity
function _bookedReserve(IERC20 token) internal view returns (uint256);
function _unbookedSurplus(IERC20 token) internal view returns (uint256); // B - R (no special underflow product error)
function _syncReserveToBalance(IERC20 token) internal; // _updateReserve(token, balanceOf)
function _syncAllExpectedHoldReserves() internal; // full expected-hold set (L-RSRV-SYNC-FULL)
function _secureTokenTransfer(...) internal virtual returns (uint256); // law §4.2
```

Use `MultiAssetBasicVaultRepo` for storage access. Do **not** add `ReserveAccountingUnderflow` (L-RSRV-NO-UNDERFLOW-BRANCH).

### 5.2 Route authors (all BasicVaultCommon inheritors)

**Every route that changes vault reserve balances** (L-RSRV-SYNC-ROUTES) — deposits, withdrawals, compound, rebalance, harvest, fee-compound, zap, etc. — must:

1. Compute amounts / execute DEX / mint-burn / compound as today.
2. Apply `_refundExcess` when applicable (**exact-out unused credit only**) **before** final sync.
3. At **end of the workflow**, call **`_syncAllExpectedHoldReserves()`** (or equivalent) — **full expected-hold set**, every money route (L-RSRV-SYNC-FULL / L-RSRV-HOLD-SET). Do **not** depend on a function modifier to sync after return. Do **not** implement route-touched-only sync.
4. **Do not** refund unclaimed push surplus (`U − claimed`); absorb via sync (L-RSRV-ABSORB).

Failure to full-set sync after a money route is a **functional bug** (INV-R1 break; next push mis-credits; retained dust free-credits). Deliberately **not** syncing unrelated ERC20s is correct (L-RSRV-DUST).

### 5.3 Aerodrome override / compound dust (L-RSRV-COMPOUND-DUST)

Current override that only documents in-call delta and calls `super` must remain compatible:

- Prefer **delete override** if super fully implements law.
- If kept, must **not** compute credit as `balance − excessToken` free inventory.
- **Locked:** dust retained for later compounding / rebalance is **included in end-of-op `R`** via normal balance sync. After a successful money op, compound residuals are **booked and I1-protected**, not left unbooked for free claim.

### 5.4 Router (Balancer SE)

No mandatory redesign for Wave 0 if vault law lands:

- Keep: transfer/Permit2 **to vault**, then `exchange*(..., true)`.
- Ensure estimated/exact amounts match claimed ≤ unbooked after push.
- Exact-out: push `max` or estimated; vault credits used amount; refund excess; sync.

Optional later gas: Permit2 **user → vault** direct without router custody on pure deposit routes.

### 5.5 DETF nested SE (L-RSRV-DETF-W0)

**Wave 0 (this program’s SE/commons waves):** leave DETF nested calls as **`forceApprove` + `pretransferred=false`**. Do not migrate DETFs to push in Wave 0.

**Later wave (explicit follow-on):** refactor DETFs to the correct **push + `pretransferred=true`** workflow against SE vaults that book reserves — full product law in [`DETF_NESTED_SE_PUSH_PRETRANSFER_PRD.md`](./DETF_NESTED_SE_PUSH_PRETRANSFER_PRD.md).

Until SE Wave 0–2 land, nested `transfer` + `true` against a not-yet-fixed vault remains broken; DETF `false` path stays the supported nested pattern for Wave 0. After SE reserve-delta is live, the DETF push PRD **supersedes** nested-false as permanent design.

---

## 6. Work packages

### Wave 0 — Commons (serial, ship-blocking)

| ID | Work | DoD |
|----|------|-----|
| **WP-RSRV-0** | Implement §4.2–4.4 in `BasicVaultCommon` + repo helpers (once; all inheritors reuse) | Unit tests in `test/foundry/spec/vaults/basic/**` green |
| **WP-RSRV-0b** | Amend `docs/testing/coverage-audit/CLONE_API_FREEZE.md` + short note in gap-closure law pointers | Docs match reserve-delta for BasicVault family |
| **WP-RSRV-0c** | **Minimal BasicVault-family diamond** (L-RSRV-UNIT-SUT) + TrustFlags / TokenTransfer tests: push happy; I1 booked; I2 short; I3 absorb after sync; pull FoT; compound-dust booked if surface exposes it | No theater free credit; canonical law surface for reuse |

### Wave 1 — SE inheritors + sync call sites

| ID | Work | DoD |
|----|------|-----|
| **WP-RSRV-1-U2** | Uni V2 SE: every money branch ends with **full expected-hold** sync | Spec suite green for pretransfer + refund; INV-R1 |
| **WP-RSRV-1-AERO** | Aerodrome SE: delete/align override; full-set sync books **compound residual dust** | Swap/zap/out/compound green; booked dust not free |
| **WP-RSRV-1-CAM** | Camelot V2 SE: full-set end sync on every money route | Pretransfer + deposit paths green |
| **WP-RSRV-1-AAVE** | Aave Stata SE: full-set sync (sleeve/underlying in hold-set) | Pretransfer fuzz/routes green |
| **WP-RSRV-1-OTHER** | Any other `is BasicVaultCommon` package; full-set sync on all money routes | Grep-proven coverage |

### Wave 2 — Routers & integration

| ID | Work | DoD |
|----|------|-----|
| **WP-RSRV-2-BAL** | Balancer V3 SE router suites (deposit, pass-through, batch, permit2, transient) | Known ~23 failures closed without approve+pull rewrite |
| **WP-RSRV-2-REFUND** | `StandardExchangeOut_Refund` + UniV2 router refund | Pretransfer refund + sync order proven |

### Wave 3 — Clones (non-BasicVaultCommon)

| ID | Work | DoD |
|----|------|-----|
| **WP-RSRV-3-DETF** | **Later wave:** refactor DETF nested SE to push + `true` — see [`DETF_NESTED_SE_PUSH_PRETRANSFER_PRD.md`](./DETF_NESTED_SE_PUSH_PRETRANSFER_PRD.md) | DETF push workflow green; nested I1; no absolute credit; no nested SE approve hop |
| **WP-RSRV-3-U4-HOOK** | Uni V4 SE / hooks peers per CLONE checklist | Checklist complete; no free extract regression |

---

## 7. Testing requirements

### 7.1 Unit (BasicVaultCommon / basic vault)

| Test | Expect |
|------|--------|
| Pull `false` with approve | Success; credit = received; reserve synced |
| Pull via Permit2 when allowance low | Success |
| Push then `true` with `claimed = push` | Success; credit = claimed |
| Push then `true` with `claimed < push` | Success; unclaimed surplus **absorbed** on sync (I3 / L-RSRV-ABSORB) — **no** refund of `U − claimed` |
| Push then `true` with `claimed > push` and `R` synced | `TransferDeltaInsufficient` |
| Booked inventory only (`R == B`), `true`, no push | I1: `TransferDeltaInsufficient(claimed, 0)` |
| Booked retained compound/sleeve dust, `true`, no push | I1: same (L-RSRV-COMPOUND-DUST) |
| Exact-out max push, partial use, refund, sync | Caller gets refund of unused **credit** only; then `R == B` |
| FoT token pull | Credit actual delta |
| Deposit/withdraw (or other money path) mutates balance | End-of-op **full expected-hold** sync; INV-R1 for **every** expected-hold token |
| Post-op invariant (tests, not production error API) | After every money route: `R(T) == balanceOf(T)` for all expected-hold `T` (L-RSRV-NO-UNDERFLOW-BRANCH) |

### 7.2 Integration

| Suite cluster | Expect after Wave 1–2 |
|---------------|------------------------|
| Aerodrome pretransfer happies | Pass under reserve-delta |
| Aerodrome reserved / compound dust | Expect `TransferDeltaInsufficient` / dust **booked** end-of-op not free (L-RSRV-COMPOUND-DUST) |
| Balancer SE router vault deposit/pass-through | Pass with push + `true` |
| UniV2 / StandardExchangeOut refund | Pass |
| Aave Stata pretransfer | Fund correctly or expect I1 if unfunded |

### 7.3 Production-first rules

- No mocks of SUT vaults/routers/manager.
- Deploy via IndexedEx manager / package paths per `indexedex-testing`.
- Prefer hermetic default profile; fork only where already required.

### 7.4 Acceptance commands (minimum)

```bash
forge test --match-path 'test/foundry/spec/vaults/basic/**' -vv
forge test --match-path 'test/foundry/spec/protocol/dexes/uniswap/v2/**' --match-test 'pretransfer|Refund|refund' -vv
forge test --match-path 'test/foundry/spec/protocol/dexes/aerodrome/v1/**' --match-test 'pretransfer|Pretransfer' -vv
forge test --match-path 'test/foundry/spec/protocol/dexes/balancer/v3/routers/**' -vv
```

Full SE filters as needed before merge.

---

## 8. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Missing full-set sync on a money branch | Checklist **all** money routes call `_syncAllExpectedHoldReserves` (L-RSRV-SYNC-ROUTES / L-RSRV-SYNC-FULL); post-op INV-R1 tests |
| `B < R` from incorrect implementation | **Tests** catch broken routes (INV-R1). No production `ReserveAccountingUnderflow` API (L-RSRV-NO-UNDERFLOW-BRANCH). Never silent clamp. |
| Unbooked donation funds next `true` claim | **By design** for not-yet-synced / non-expected-hold (L-RSRV-DUST / L-RSRV-CALLER); integrators use atomic fund+call; expected-hold leftovers **absorbed** (L-RSRV-ABSORB) |
| Caller under-claims after large push | Absorb remainder (L-RSRV-ABSORB); not protocol refund duty |
| Double meaning of public `reserveOfToken` on non-ERC20-book packages | Exclude from blind Wave 0; package-local law |
| Gas: SSTORE on every sync | Accept as cost of durable push; still cheaper than approve+second hop in many paths; optional later transient window for same-tx-only funders |
| Conflict with i-common adversarial tests that expect pure in-call delta 0 after external push | Update tests to **booked** I1 vs **unbooked push** happy path |
| Aerodrome compound dust free-credit regression | **Must** book residual dust end-of-op (L-RSRV-COMPOUND-DUST) in WP-RSRV-1-AERO |

---

## 9. Documentation deliverables

| Doc | Change |
|-----|--------|
| This PRD | Source of product law |
| `docs/testing/coverage-audit/CLONE_API_FREEZE.md` | Reserve-delta algorithm for BasicVault family |
| `docs/testing/TEST_COVERAGE_GAP_CLOSURE_PRD.md` / impl plan | Cross-link “refined L-GAPS-9 baseline = booked reserve for pretransfer” |
| `docs/agent/INDEXEDEX_AGENT_LAW.md` (if pull semantics section exists) | Pointer only; no paste of full PRD |
| Component docs for SE In/Out (optional) | One-line pretransfer = unbooked surplus vs reserve |

---

## 10. Open questions vs locked decisions

### 10.1 Locked (do not re-litigate)

| ID | Decision | See |
|----|----------|-----|
| **OQ-1** | **Any caller** may use `pretransferred=true`; atomic fund+call is integrator expectation only | L-RSRV-CALLER, §1.1, §4.6 |
| **OQ-3** | **No** DETF push migration in Wave 0; later wave | L-RSRV-DETF-W0, §5.5 |
| **OQ-2** | **No** dedicated production `B < R` error/assert branch; correctness via INV-R1 tests | L-RSRV-NO-UNDERFLOW-BRANCH, §4.2 / §4.5 |
| **OQ-4** | Sync **expected-hold** tokens at end of workflow; not arbitrary ERC20s | L-RSRV-SYNC-*, §4.4 |
| **OQ-5** | **Full expected-hold set** synced on **every** successful money op (not route-touched-only) | L-RSRV-SYNC-FULL, §4.4 / §5.2 |
| **OQ-6** | **All** routes that change vault reserve balances must end-sync (deposits, withdrawals, compound, rebalance, …) | L-RSRV-SYNC-ROUTES, §4.4 |
| **OQ-7** | Hold-set = underlying reserve tokens + package-known sleeve / compound-pending / rebalance residuals; **not** vault share token; sync sleeves/dust to protect | L-RSRV-HOLD-SET, §4.4 |
| **OQ-8** | **Absorb** unclaimed push surplus; caller fault; no refund of `U − claimed` | L-RSRV-ABSORB, §4.4 / §4.6 |
| **OQ-9** | Retained compound dust **included** in end-of-op `R` | L-RSRV-COMPOUND-DUST, §5.3 |
| **OQ-10** | Wave 0 unit SUT = **minimal BasicVault-family diamond**; implement once in commons, reuse | L-RSRV-UNIT-SUT, WP-RSRV-0c |
| **Bootstrap** | `R = 0` unbooked seed is **desired** | L-RSRV-BOOTSTRAP, §4.9 |
| **Dust recovery** | Unbooked surplus on **not-yet-synced / non-expected-hold** tokens funding `true` is **desired recovery** | L-RSRV-DUST, §4.6 |

### 10.2 Open questions

**None.** All product choices that previously left implementer judgment are locked in §1.1 / §10.1.

---

## 11. Summary for implementers

1. **`reserveOfToken` is the durable snapshot** after each successful money op (for expected-hold tokens).  
2. **`pretransferred=true` credits `claimed` only against unbooked surplus `balance − reserve`.** Any caller may use it; prefer atomic fund+call.  
3. **`pretransferred=false` pulls** (ERC20 then Permit2) and credits pull delta.  
4. **Every money route** end-syncs the **full expected-hold set** after refunds (L-RSRV-SYNC-FULL). No sync modifier; no route-touched-only.  
5. **Expected-hold** = underlying reserve tokens + sleeve inventory + dust pending compound/rebalance; **not** vault share.  
6. **Absorb** unclaimed push surplus into `R` (caller fault). Refund only exact-out unused credit.  
7. **Retained compound dust is booked** end-of-op (not free credit after sync).  
8. **Crude recovery** only for not-yet-synced / non-expected-hold inventory.  
9. **No production `B < R` error API** — INV-R1 tests after every money route catch incorrect implementations.  
10. **Bootstrap `R = 0`:** full live balance unbooked until claim/sync (desired).  
11. **Implement once in `BasicVaultCommon`** (+ minimal BasicVault diamond unit surface); SE vaults inherit; fix Aerodrome override; green router push tests.  
12. **Wave 0 DETF:** leave nested approve + `false`; push DETF refactor is a later wave.  
13. **Do not** restore absolute inventory credit.  
14. **I1** = **booked** inventory free-credit blocked; unbooked push / not-yet-synced dust is the happy / recovery path.

---

## 12. Approval

| Role | Decision |
|------|----------|
| Product / owner | Confirmed intent: durable reserve snapshot + secure push (this document); §1.1 clarifications 2026-08-10 |
| Implementer | Must follow §4 law; **no open product OQs** — do not reintroduce implementer choice on sync breadth or underflow errors |
| Reviewer | Reject PRs that credit without `U`, use route-touched-only sync instead of full expected-hold set, skip end-sync on any money route, leave package-known compound/sleeve dust unbooked after success, refund unclaimed push surplus, add a production `ReserveAccountingUnderflow` product API, reintroduce absolute `balanceOf` free credit, or migrate DETF push in Wave 0 without a dedicated wave |
