# Product Requirements Document (PRD)

## Title

**DETF Threshold Modes** — deploy-time **Policy** vs **Open** mint/burn gating for all true DETF families

## Status

**LOCKED — 2026-07-28** (product law locked 2026-07-27; formal **LOCKED** now that F1 + F2 + F3 threshold-mode plans are accepted **and** Wave 2 implement waves P0–P3 are green / oversight-accepted)

| Field | Value |
|-------|--------|
| **Status** | Formal **LOCKED** — 2026-07-28. Product law locked 2026-07-27; Wave 2 (core lib + F1/F2/F3) plans accepted and implementation green |
| **Scope** | Family-agnostic product law for mint/burn **primary-market gates** |
| **Implementation style** | Shared **semantics** + `detf/core` lib helpers; **per-family** wiring plans |
| **Related product narrative** | Decentralized ETF-shaped share + optional OHM-class policy bands; immutable instances; no keeper |
| **Normative shared helpers today** | `contracts/vaults/detf/core/DETFThresholdPolicy.sol` |
| **AGENTS.md** | DETF families — common expectations (mint/burn thresholds, inert→live); update after formal LOCKED (P7) |

**Implementation status:** Product law is normative. Waves 2–4 are **shipped** for in-scope families: core lib + F1–F5 Policy/Open, F6 `IProtocolDETF` NatSpec/`thresholdMode`, F7 Seigniorage formal **Out**. **P7 complete** (AGENTS.md Policy/Open + family PRD conform notes). **Threshold Modes program P0–P7 complete.**

---

## 0. Intent (why this exists)

### 0.1 Product problem

True DETFs mint and burn share supply against a Balancer (or mixed-buffer) **reserve** using **synthetic / fully diluted** pricing. Today, almost all modern families gate that primary market with a **deadband**:

| Condition (Policy default) | Allowed? |
|----------------------------|----------|
| `syntheticPrice > mintThreshold` (default `1.05e18`) | Mint |
| `syntheticPrice < burnThreshold` (default `0.95e18`) | Burn |
| Inside the band (including **equality** at either threshold) | Neither — users use the reserve AMM / other routes |

That deadband is **OHM-class monetary policy**: expand supply when rich, contract when cheap, stay quiet near peg.

**Strict inequalities:** mint requires `synthetic > mintThreshold`; burn requires `synthetic < burnThreshold`. Equality at either threshold is **inside the deadband** (neither mint nor burn via primary gates).

### 0.2 Market problem

A second audience wants a **decentralized ETF-shaped** experience: **create and redeem whenever the product is live**, without waiting for the synthetic to leave a band — still without a fund admin, keeper, or post-deploy governance of the instance.

### 0.3 Decision (locked)

| Decision | Choice |
|----------|--------|
| Remove Policy gating forever? | **No** — keep as **default** |
| Support always-on mint/burn? | **Yes** — as deploy-time **Open** mode |
| Post-deploy mode / threshold changes? | **No** — preserves immutable unowned instances |
| Seigniorage **split** to bonders / fee paths? | **Keep in both modes** when mints occur |
| Usage / protocol **fees** | **Unchanged by mode** — fees apply regardless of Policy vs Open |
| Pure pro-rata BPT vault as “Open”? | **Out of scope** — different product class |
| Encoding | **Explicit** `enum ThresholdMode { Policy, Open }` — never infer Open from threshold sentinels alone |
| Gate price input | **Always synthetic / FD** (migrate any spot-based gates in this program) |
| Asymmetric modes (open burn / gated mint only) | **Do not exist** — out of product space forever for v1+ under this PRD |
| Nested DETF composition | **No cross-instance mode rules** — each diamond’s mode is independent |

### 0.4 Unified narrative (marketing alignment)

```text
Same chassis:  detfToken share + market-composed reserve + bond lifecycle + seigniorage split (as designed)
Deploy dial:   Policy (default deadband)  ←→  Open (always-on primary market when live)
Stories:       OHM-class policy unit           ETF-class create/redeem
Honesty layer: rate re-mark + pool pricing + no keeper / no instance admin (both)
```

**Headline (both modes):**

> A DETF is a decentralized ETF-shaped share over a market-composed reserve. Instances are immutable after deploy. Markets and fixed deploy-time policy run the product — not keepers or an admin. Choose Policy bands (OHM-class) or Open primary market (ETF-class) at deploy.

**Supported product configurations (first-class SKUs):**

| SKU | Mode | Thresholds | Narrative |
|-----|------|------------|-----------|
| **Policy (default)** | `Policy` | Defaults ±5% (`0,0` → `1.05e18` / `0.95e18`) | OHM-class deadband; **peg narrative** (abstract 1e18 synthetic) |
| **Open** | `Open` | Stored for display (defaults); **ignored by gates** | ETF-class create/redeem when live; **do not advertise a peg** |

Protocol still allows non-default Policy numeric thresholds when they pass validation (see §4.2) — used for tests and non-standard deploys. They are **not** a marketed third product flavor. Extreme Policy thresholds (`mint=1`, `burn=type(uint256).max`) remain **legal** and still mean **Policy** (gates happen to always pass); product **Open** requires `thresholdMode = Open`.

### 0.5 What gating is / is not

| Controls | Does not control |
|----------|------------------|
| Whether **seigniorage mint/burn** may expand/contract supply | Secondary-market trading of free DETF |
| When primary market is open | Whether synthetic is computed from the reserve (it always is) |
| Deploy-time product flavor | Offchain underlyings legal ownership |
| Fees | Fee rates / fee paths (mode-independent) |

Open mode does **not** “unbind” share value from the reserve. Synthetic remains reserve-derived. Open only removes the **deadband on primary mint/burn**.

### 0.6 Open-mode primary-market economics (normative honesty)

When **Open + live**, both mint and burn primary routes are allowed even when synthetic would have been inside the Policy deadband. That is intentional ETF-class create/redeem UX.

Implications agents and marketing must respect:

- Users **can** two-way trade against the reserve via primary mint and burn subject to **usage fees, seigniorage split, liquidity, and price impact**.
- This is **not** risk-free NAV arbitrage and **not** a free put/call on a stated peg.
- **Open instances must not advertise a peg price.** Policy instances may continue the abstract **1e18** synthetic peg narrative used for deadband gates.
- Secondary-market DETF trading remains available in both modes; Open only expands **primary** access.

### 0.7 First bond / bootstrap (orthogonal to mode)

First-bond / bootstrap liveness rules are **orthogonal** to threshold mode:

- Open does **not** skip inert; normal user mint/burn still require live.
- Policy does **not** re-gate first bond with synthetic thresholds.
- First bond remains **synthetically ungated** in **both** modes — required to initialize reserve / go live.

---

## 1. Goals

1. Define **one product law** for threshold modes across all in-scope true DETFs.
2. Keep **Policy ±5%** as the default for new and existing arg conventions (`0` → defaults).
3. Introduce **Open** as an explicit deploy-time mode (not overloaded `0`).
4. Share **semantics** via PRD + `detf/core` helpers; implement gates in **each family’s** exchange/info/pkg path.
5. Provide a **family inventory** and **cross-family checklist** so agents can write implementation/test plans without re-litigating product.
6. Preserve: inert→live, first-bond rules, preview==execution expectations, seigniorage fee/split, production-first testing.
7. Migrate **all** true DETF families to this deploy-time Policy/Open gating option; keep existing Policy/gated tests; **add** Open-configuration tests.
8. Mandate a uniform info surface: `thresholdMode()`, `isMintingAllowed()`, `isBurningAllowed()` — with accuracy tests — on every in-scope family.

---

## 2. Non-goals

- Post-deploy threshold or mode mutation (owner, oracle, or otherwise).
- Fee-oracle (or any oracle) control of mint/burn thresholds or mode — **including** “global default band at deploy.”
- Replacing seigniorage mint with pure pro-rata BPT accounting.
- Removing bond NFT / claim / seigniorage split economics.
- Changing fee schedules based on mode (fees apply in both modes as designed today).
- Unifying all DETF families into one DFPkg or one Exchange facet.
- DualLiquidityLinked (not a true DETF — no synthetic mint/burn gates).
- Research plot packs (tracked separately; Open mode should be included in future DETF research).
- Changing default numeric band (still ±5% for Policy) unless a later PRD revision says so.
- Venue-specific branding in contracts.
- Asymmetric threshold modes (open-only-mint, open-only-burn, etc.).
- Nested mode composition rules between outer/inner DETFs.
- Frontend / UI product copy requirements in this session (separate workstream).
- Claim **redemption** gates (`RedemptionNotAllowed` and peers) — **independent** of Open mode unless a family plan proves literal coupling (default: independent).

---

## 3. Definitions

| Term | Meaning |
|------|---------|
| **True DETF** | Diamond **is** the share ERC-20; seigniorage mint/burn vs a reserve pool that includes a DETF self-leg (or family-equivalent seigniorage design). |
| **Synthetic price** | Family’s fully diluted / reserve-backed unit price used for **all** mint/burn gates (abstract **1e18** reference for Policy peg narrative). |
| **Policy mode** | Mint only if `synthetic > mintThreshold`; burn only if `synthetic < burnThreshold`. Equality is deadband. |
| **Open mode** | When reserve is **live**, mint and burn **threshold** gates always pass (subject to all other preconditions: amounts, liquidity, locks, route validity). No peg advertised. |
| **Primary market** | Seigniorage mint/burn routes that change DETF supply against the reserve. |
| **Deadband** | Synthetic region where Policy forbids both mint and burn (includes equality at thresholds). |
| **Inert / pre-live** | Deployed but not yet live; normal user mint/burn blocked until family liveness rule (usually first bond / bootstrap). |
| **ThresholdMode** | `enum ThresholdMode { Policy, Open }` with `Policy = 0`, `Open = 1`. |

---

## 4. Functional requirements

### 4.1 Modes (normative)

| Mode | Enum | Mint when live | Burn when live | Threshold storage |
|------|------|----------------|----------------|-------------------|
| **Policy** | `ThresholdMode.Policy` (`0`) | `synthetic > mintThreshold` | `synthetic < burnThreshold` | After resolve: defaults or validated custom values; **gates use them** |
| **Open** | `ThresholdMode.Open` (`1`) | Always allowed by threshold policy | Always allowed by threshold policy | Still **resolve and store** defaults (or resolved args) for getters; **gates ignore** them |

**Locked encoding:**

```solidity
enum ThresholdMode {
    Policy, // 0 — default when omitted / zero storage
    Open    // 1
}
```

- Explicit `thresholdMode` field on every in-scope family’s `PkgArgs` and instance storage.
- Omitted / zero mode → **Policy** (backward compatible with existing diamonds and args).
- **Never** infer Open from sentinel threshold pairs alone.
- Extreme Policy thresholds remain **legal** and still mean Policy; product Open requires `thresholdMode = Open`.

### 4.2 Deploy-time configuration and validation

1. Mode and thresholds are fixed in package args / init and written once to instance storage.
2. **No** instance function may change mode or thresholds after init.
3. **`mintThreshold == 0` and `burnThreshold == 0` resolve to Policy defaults** when mode is Policy (or mode omitted → Policy):
   - `0` → `mintThreshold = 1.05e18`
   - `0` → `burnThreshold = 0.95e18`
   - **Critical:** `0` must **not** mean Open.
4. Open mode is selected **only** by `thresholdMode = Open`.
5. **Validation (both modes, after `0` resolution):** if `mintThreshold <= burnThreshold`, **revert at deploy/init**. Invalid `thresholdMode` (`> Open`) also reverts. See §16.
6. **Open:** still resolve and store thresholds for getters; **do not** re-impose deadband on gates. Same numeric validation as Policy.
7. **No fee oracle / manager path** may set, override, or mutate mode or thresholds at deploy or later. PkgArgs are the sole source.
8. Emit **`ThresholdModeSet(mode, mintThreshold, burnThreshold)`** **once at init** with **resolved** thresholds (canonical ABI in §16.4).

### 4.3 Gate evaluation (normative)

**Split of responsibility (locked):**

| Layer | Responsibility |
|-------|----------------|
| **Family** (Common / Exchange) | Check **live** first with family-specific inert/live errors; then call threshold helpers; map Policy failures to `MintingNotAllowed` / `BurningNotAllowed` |
| **Shared lib** (`DETFThresholdPolicy`) | Pure mode + price logic only — **no live flag** |

```text
// Shared lib (pure) — mode + price only
function isMintingAllowed(mode, mintThreshold, synthetic) -> bool:
  if mode == Open: return true
  return synthetic > mintThreshold

function isBurningAllowed(mode, burnThreshold, synthetic) -> bool:
  if mode == Open: return true
  return synthetic < burnThreshold

// Family execution / views
function allowMint(live, mode, synthetic, mintThreshold) -> bool:
  if not live: return false   // family error path for inert
  return DETFThresholdPolicy.isMintingAllowed(mode, mintThreshold, synthetic)

function allowBurn(live, mode, synthetic, burnThreshold) -> bool:
  if not live: return false
  return DETFThresholdPolicy.isBurningAllowed(mode, burnThreshold, synthetic)
```

**Price input (locked for all families in this program):** gates MUST use the family’s **synthetic / FD** price.  
**Do not** introduce a second ad-hoc FX ledger.  
**Spot-based gates** (e.g. historical F5 paths): **migrate to synthetic** under this program — no permanent exception.

**Zero supply:** no Open-specific special path. Existing family rules for synthetic when `totalSupply == 0` (typically abstract peg `1e18` for views) remain; gates for normal mint/burn still require **live**.

### 4.4 Preconditions that still apply in Open mode

Open removes **only** the synthetic deadband. Still required as today per family:

- Reserve **live** (inert still blocks normal mint/burn).
- Valid route / token allowlists.
- Reentrancy locks, balances, minOut / deadline.
- Usage fee + seigniorage split on mint where designed (and any burn fees) — **same fee paths as Policy**.
- Bond/bootstrap rules (first bond remains **ungated** by synthetic in both modes).

### 4.5 Info surface (normative — MUST for every in-scope family)

Every in-scope family **MUST** expose:

| View | Behavior |
|------|----------|
| `mintThreshold()` / `burnThreshold()` | Stored resolved values (Policy gates use them; Open stores them for display only) |
| `thresholdMode()` | `ThresholdMode` — new selector on new package cuts |
| `isMintingAllowed()` | Encapsulates **live + mode + synthetic** (Policy compares price; Open short-circuits when live) |
| `isBurningAllowed()` | Same |

**Accuracy contract:**

| State | `thresholdMode()` | `isMintingAllowed` | `isBurningAllowed` |
|-------|-------------------|--------------------|--------------------|
| Inert (any mode) | as deployed | `false` | `false` |
| Live + Policy + in deadband (incl. equality) | Policy | `false` | `false` |
| Live + Policy + `synthetic > mintThreshold` | Policy | `true` | per burn rule |
| Live + Policy + `synthetic < burnThreshold` | Policy | per mint rule | `true` |
| Live + Open | Open | `true` | `true` |

Family plans **MUST** test that these views match execution gates for both modes.

**Existing diamonds:** no upgrade path (immutable). Storage default `0` ⇒ Policy. New packages add selectors; old instances remain Policy-only without `thresholdMode()` unless redeployed under a new package cut.

### 4.6 Preview / execution parity

Preview paths that check thresholds MUST use the **same** allow rules as execution for both modes (AGENTS.md: closed-form preview == execution).

### 4.7 Errors

- Policy mode continues to use family errors such as `MintingNotAllowed(price, mintThreshold)` / `BurningNotAllowed(price, burnThreshold)`.
- Open mode must **not** hit those for deadband reasons.
- Inert/not-live keeps existing live-check errors (not threshold errors).

### 4.8 Shared core library (normative engineering)

Extend `contracts/vaults/detf/core/DETFThresholdPolicy.sol` (or sibling lib) to provide:

- `ThresholdMode` enum / constants (`Policy = 0`, `Open = 1`)
- `resolveThresholds(mintArg, burnArg) → (mint, burn)` with `0 → default` (mode-agnostic numeric resolve)
- `isMintingAllowed(mode, threshold, price)` / `isBurningAllowed(mode, threshold, price)` including Open short-circuit
- Optional: `isOpenMode(mode)`
- Pure unit tests for the lib (no diamond required)

Families call these helpers; they do **not** need a shared facet.

### 4.9 Defaults and immutability (summary)

| Knob | Default | Mutable after deploy? | Source |
|------|---------|------------------------|--------|
| Mode | **Policy** (`0`) | No | PkgArgs only |
| mintThreshold | `1.05e18` (`0` arg → default) | No | PkgArgs only |
| burnThreshold | `0.95e18` (`0` arg → default) | No | PkgArgs only |

### 4.10 API sketch (copy into family plans)

```solidity
// On package interface PkgArgs (names illustrative; match family style):
struct PkgArgs {
    // ... existing fields ...
    ThresholdMode thresholdMode; // 0 = Policy (default), 1 = Open
    uint256 mintThreshold;       // 0 → 1.05e18 when resolved
    uint256 burnThreshold;       // 0 → 0.95e18 when resolved
}

// Info surface (MUST):
function thresholdMode() external view returns (ThresholdMode);
function mintThreshold() external view returns (uint256);
function burnThreshold() external view returns (uint256);
function isMintingAllowed() external view returns (bool);
function isBurningAllowed() external view returns (bool);

// Init event (MUST, once):
event ThresholdModeSet(ThresholdMode mode, uint256 mintThreshold, uint256 burnThreshold);
```

`PkgInit` / `PkgArgs` remain **on the interface**, not the DFPkg contract (Crane rule).

---

## 5. Testing requirements (cross-family checklist)

Every in-scope family implementation plan must cover:

### 5.1 Deploy matrix

| # | Case | Expect |
|---|------|--------|
| T1 | Policy, args `0,0` | Stored thresholds = 1.05e18 / 0.95e18; mode Policy; event emitted |
| T2 | Policy, custom band e.g. 1.10 / 0.90 | Stored as given; gates use them (legal; not a marketed SKU) |
| T3 | Open mode deploy | Mode Open; stored thresholds display-stable; info flags when live |
| T4 | Invalid Policy args after resolve (`mintThreshold <= burnThreshold`) | Revert at deploy/init |
| T4b | Extreme Policy thresholds (`1` / `max`) | Deploy succeeds as **Policy**; gates always pass when live — not a substitute for Open product mode |

### 5.2 Runtime — Policy

| # | Case | Expect |
|---|------|--------|
| T5 | Live, synthetic in deadband (incl. equality) | Mint reverts; burn reverts |
| T6 | Live, synthetic > mintThreshold | Mint succeeds (happy path) |
| T7 | Live, synthetic < burnThreshold | Burn succeeds |
| T8 | Inert | Mint/burn blocked regardless of synthetic / mode |
| T9 | Drive synthetic via **real underlying trades** under default ±5% | Both mint-allowed and burn-allowed regimes (AGENTS.md DETF testing) |
| T9b | Info views | `thresholdMode` / `isMintingAllowed` / `isBurningAllowed` match execution |

### 5.3 Runtime — Open

| # | Case | Expect |
|---|------|--------|
| T10 | Live, synthetic **inside** former deadband | Mint succeeds; burn succeeds (subject to liquidity / fees / impact) |
| T11 | Inert + Open | Still blocked pre-live |
| T12 | Preview == execution on closed-form mint/burn when allowed |
| T13 | Seigniorage/fee split still applied on Open mints (same as Policy fee paths) |
| T13b | Info views | Live Open ⇒ both `is*Allowed` true; mode Open |

### 5.4 Adversarial / abuse

| # | Case | Expect |
|---|------|--------|
| T14 | No post-deploy setter for mode/thresholds | No selector / revert |
| T15 | Alternate route cannot bypass Policy deadband | Same gates |
| T16 | Reentrancy still hits `IsLocked` where family already tests it |
| T17 | Open + live mint → immediate burn (round-trip) | Fees/split/residual inventory behave as designed; no deadband errors |
| T18 | Policy extreme thresholds (`1` / `max`) | Still reports `thresholdMode() == Policy`; not Open |
| T19 | Open deploy with non-default stored threshold numbers | Never reverts with deadband `MintingNotAllowed` / `BurningNotAllowed` when live |

### 5.5 Production-first and dual-path fixtures

- No mocks of SUT DETF, DFPkg, manager, registry, fee oracle, attached SE vaults.
- Prefer gold `TestBase_*` production deploy path.
- **Keep** existing Policy/gated suites as the gated configuration baseline.
- **Add** explicit Open-configuration suites.
- Dual-path allowed during migration: extreme Policy thresholds may remain in older tests until named Open helpers exist; new work should use `_deployOpenThresholds()` / `thresholdMode: Open`.
- Named Open fixtures once helpers land: e.g. `_deployOpenThresholds()`, not only anonymous `mintTh=1, burnTh=max` without documenting product mode.

---

## 6. Implementation strategy for agents

```text
1) This PRD is formally LOCKED (2026-07-28) — product law + Wave 2 implement (P0–P3) complete
2) Core lib DETFThresholdPolicy extended (+ pure unit tests) — shipped (P0)
3) Gold path: SingleStandardExchangeDETF plan + implement + green tests — shipped (P1)
4) F2 + F3 plans specified and implemented — shipped (P2/P3); formal LOCKED gate met
5) Port remaining families (F4–F7 as inventory priority) via dedicated plans
6) Update AGENTS.md one-liner; family PRDs “conforms to DETF_Threshold_Modes_PRD” (P7)
7) Marketing: Open never claims a peg; gold family Open is available when product chooses
```

**Rollout waves:**

| Wave | Scope | Gate |
|------|-------|------|
| **MVP** | Core lib + F1 (P0) green (Policy + Open) | **Shipped** (P0–P1) |
| **Wave 2** | F2, F3 (P1) plans **specified**, then implemented | **Shipped** (P2–P3) — formal PRD **LOCKED** gate met 2026-07-28 |
| **Wave 3** | F4, F5 (+ F6 interface NatSpec) | Later — synthetic migration for any remaining spot gates |
| **Wave 4** | F7 audit → parity wiring or formal **Out** | Later — explicit decision in family plan |

**Per-family plan template (suggested filename):**  
`{Family}_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md` next to the family package  
**or** a new section in the existing `*_IMPLEMENTATION_AND_TEST_PLAN.md`.

Each plan should include: touch list, PkgArgs diff, gate call sites, synthetic function confirmation (no spot), TestBase changes, `ThresholdModeSet` event, checklist from §5 mapped to concrete tests.

---

## 7. Inventory — target families and locations

### 7.1 Legend

| Priority | Meaning |
|----------|---------|
| **P0** | Gold path — implement first; defines reference behavior (**shipped** Wave 2) |
| **P1** | Modern true DETF, full threshold stack; plans + Wave 2 implement gated formal LOCKED (**met**) |
| **P2** | In scope; ship after Wave 2; same product law (Wave 3) |
| **P3** | Legacy / alternate surface — audit for parity under same law or explicit Out (Wave 4) |
| **Out** | Not a true DETF gate product; do not force this PRD |

| Gate status (today) | Meaning |
|---------------------|---------|
| **Synthetic + DETFThresholdPolicy** | Peer gold pattern |
| **Spot-based gates** | Must migrate to synthetic in this program |
| **Peg narrative only** | Above/below peg in comments/routes — migrate to Policy/Open + synthetic |
| **N/A** | No mint/burn threshold product |

---

### 7.2 Shared infrastructure (not a DETF instance)

| Component | Path | Role for this PRD |
|-----------|------|-------------------|
| Threshold pure lib | `contracts/vaults/detf/core/DETFThresholdPolicy.sol` | **Extend** for mode-aware allow + resolve |
| Other core libs | `contracts/vaults/detf/core/*` | Unchanged unless preview helpers need mode |
| DETF common / bridge | `contracts/vaults/detf/DETFCommon.sol`, `DetfSuperchainBridgeRepo.sol` | Out of scope unless they gate mint |
| Reusable factories | `contracts/vaults/detf/reusable/*` | Only if PkgArgs plumbing is shared |
| Inventory policies | `contracts/vaults/detf/inventory/*` | Out of scope |
| Dual / embedded stubs | `contracts/vaults/detf/dual/*` | Inventory only; confirm no independent gate surface |
| Bond NFT / claim packages | `contracts/vaults/protocol/DETFNFTVault*`, `RebasingClaimToken*` | Out of scope for gates (bond may stay synthetically ungated on first bond) |
| Vault Fee Oracle | `contracts/oracles/fee/**` | **No** threshold/mode control (bond terms remain oracle-driven) |
| AGENTS expectations | `Agents.md` / `AGENTS.md` DETF section | Update after formal LOCKED: Policy default; Open optional; gates always synthetic |

---

### 7.3 In-scope true DETF families

#### F1 — Single Standard Exchange DETF (**P0 gold** — **shipped**)

| Field | Value |
|-------|--------|
| **Product** | `SingleStandardExchangeDETF` |
| **Path** | `contracts/vaults/detf/standardExchange/single/` |
| **DFPkg** | `SingleStandardExchangeDETDFPkg.sol` (note filename spelling `DETDFPkg`) |
| **PRD** | `SingleStandardExchangeDETF_PRD.md` |
| **Plans** | `SingleStandardExchangeDETF_IMPLEMENTATION_AND_TEST_PLAN.md`, adversarial + fuzz plans; threshold-modes plan **accepted + shipped** |
| **TestBase** | `TestBase_SingleStandardExchangeDETF.sol` |
| **Gate wiring** | `SingleStandardExchangeDETFCommon` / ExchangeIn / ExchangeOut / Info / Repo |
| **Gate price** | `_syntheticPrice()` (FD synthetic) + mode-aware `DETFThresholdPolicy` |
| **PkgArgs** | Trailing `thresholdMode`; keep `mintThreshold`, `burnThreshold` (`0` → defaults) |
| **Test open pattern** | Extreme Policy dual-path + product Open fixtures (`_deployOpenMode*`) |
| **Factory services** | `*_Component_FactoryService`, `*_Facet_FactoryService`, `*_Pkg_FactoryService` |
| **Notes** | Primary reference implementation for this PRD. Open formalized: **Yes / shipped** (P1). |

#### F2 — Multi-Vault Weighted DETF (**P1** — **shipped**; plan + implement gated formal LOCKED)

| Field | Value |
|-------|--------|
| **Product** | `MultiVaultWeightedDetf` |
| **Path** | `contracts/vaults/detf/composed/multi-vault-weighted/` |
| **DFPkg** | `MultiVaultWeightedDetfDFPkg.sol` |
| **PRD** | `MultiVaultWeightedDetf_PRD.md` (strike any “fee oracle overrides thresholds later” language when conforming) |
| **Plans** | Implementation, adversarial, fuzz/invariant plans; threshold-modes plan **accepted + shipped** |
| **TestBase** | `TestBase_MultiVaultWeightedDetf.sol` |
| **Gate wiring** | `MultiVaultWeightedDetfCommon`, ExchangeIn/Out, Info, Repo |
| **Gate price** | `_syntheticPrice()` + mode-aware policy |
| **PkgArgs** | Trailing `thresholdMode`; same `0` → default pattern |
| **Notes** | Multi-leg weighted basket; same gate law as F1. Nested DETF legs: **no** composition mode rules. Open formalized: **Yes / shipped** (P2). |

#### F3 — MixedBuffer Multi-Vault Stable DETF (**P1** — **shipped**; plan + implement gated formal LOCKED)

| Field | Value |
|-------|--------|
| **Product** | `MixedBufferMultiVaultStableDetf` |
| **Path** | `contracts/vaults/detf/composed/stable/mixedBuffer/` |
| **DFPkg** | `MixedBufferMultiVaultStableDetfDFPkg.sol` |
| **PRD** | `MixedBufferMultiVaultStableDetf_PRD.md` (D1–D30 locked; thresholds ±5% D7 — extend with mode) |
| **Plan** | Threshold-modes plan **accepted + shipped** (alongside family implementation plan) |
| **TestBase** | `TestBase_MixedBufferMultiVaultStableDetf.sol` |
| **Gate wiring** | Common / ExchangeIn / ExchangeOut / Info / Repo |
| **Gate price** | `_syntheticPrice()` + mode-aware policy |
| **Reserve dependency** | `contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/` |
| **Notes** | Burn route is **buffer-only** post-live; Open means threshold-open, not new burn assets. First bond remains synthetically ungated. Open formalized: **Yes / shipped** (P3). |

#### F4 — Composed Stable Common DETF (**P2**)

| Field | Value |
|-------|--------|
| **Product** | `ComposedStableCommonDetf` (+ rebasing claim token packages in-tree) |
| **Path** | `contracts/vaults/detf/composed/stable/common/` |
| **DFPkg** | `ComposedStableCommonDetfDFPkg.sol` |
| **Related pkgs** | `ComposedStableCommonDetfBondNFTVaultDFPkg.sol`, `RebasingDETFTokenDFPkg.sol`, … |
| **PRD** | `ComposedStableCommonDetf_PRD.md` |
| **TestBase** | `TestBase_ComposedStableCommonDetf.sol`, `TestBase_ComposedStableCommonDetf_Components.sol` |
| **Gate wiring** | `ComposedStableCommonDetfCommon`, `ComposedStableCommonDetfExchangeIn`, ExchangeOut query facets, Repo |
| **Gate price** | Synthetic (`_syntheticDetfEthPrice()` / peers) + mode-aware policy |
| **Notes** | Same product law as F1–F3. Wave 3 after P1. Confirm all mint/burn entrypoints (including query facets that enforce gates) get mode awareness. Used as nested attachment in some F1 matrix rows — outer/inner modes stay independent. |

#### F5 — Single Vault DETF / composed single (**P2**)

| Field | Value |
|-------|--------|
| **Product** | `SingleVaultDetf` |
| **Path** | `contracts/vaults/detf/composed/single/` |
| **DFPkg** | `SingleVaultDetfDFPkg.sol` |
| **Plans** | `UNISWAP_V4_SINGLE_DETF_IMPLEMENTATION_PLAN.md`, adversarial plan; add threshold-modes plan |
| **Interfaces** | `contracts/interfaces/ISingleVaultDetf.sol`, related `IProtocolDETF` surface |
| **Gate wiring** | `SingleVaultDetfCommon`, ExchangeIn/Out/Query, Info, Repo |
| **Gate price today** | Some paths use **`_calcReserveSpotPrice()` / reserve spot** |
| **Gate price target** | **Migrate all mint/burn gates to synthetic** in this program (locked) |
| **Notes** | Same Policy/Open deploy option as peers. Brand-era names must not re-enter code. Keep gated Policy tests; add Open tests. |

#### F6 — Protocol DETF interface / legacy surface (**Wave 4 — shipped**)

| Field | Value |
|-------|--------|
| **Product surface** | `IProtocolDETF` |
| **Path** | `contracts/interfaces/IProtocolDETF.sol`, `IProtocolDETFErrors.sol`, `proxies/IProtocolDETFProxy.sol` |
| **Impl note** | **No** standalone `ProtocolDETF*.sol` package under `contracts/` (verified 2026-07-27). Concrete mint/burn lives in families that expose this interface (notably **F5**). |
| **Gate API** | **Shipped 2026-07-28:** NatSpec Policy vs Open + synthetic gate input; `thresholdMode()` returns `ThresholdMode`; live-coupled `isMintingAllowed` / `isBurningAllowed` NatSpec; stored thresholds under Open for display |
| **Errors** | `MintingNotAllowed`, `BurningNotAllowed` (primary gates); `RedemptionNotAllowed` (claim path — **independent** of Open) — NatSpec aligned |
| **Notes** | F5 `SingleVaultDetfInfoFacet` registers `IProtocolDETF.thresholdMode` selector. Claim redemption stays out of threshold-mode scope. |

#### F7 — Seigniorage DETF (legacy package tree) (**Wave 4 — formal Out**)

| Field | Value |
|-------|--------|
| **Product** | `SeigniorageDETF` |
| **Path** | `contracts/vaults/seigniorage/` |
| **DFPkg** | `SeigniorageDETFDFPkg.sol` |
| **Related** | `SeigniorageNFTVault*`, `nft/SeigniorageBondNFT*`, factory service |
| **Interfaces** | `contracts/interfaces/ISeigniorageDETF.sol`, errors |
| **Gate pattern today** | Diluted peg-regime: mint when **above peg**, burn when **at-or-below peg** (`PriceAbovePeg` / `PriceBelowPeg`); **no** mint/burn threshold storage |
| **Open formalized** | **Out / not shipping** (2026-07-28 audit) |
| **Adversarial plan** | `SeigniorageDETF_ADVERSARIAL_TEST_PLAN.md` |
| **Out note** | `contracts/vaults/seigniorage/THRESHOLD_MODES_OUT.md` |
| **Notes** | Formal Out of threshold-mode implement scope: peg chassis ≠ Policy deadband; consolidation reference-only; not on modern `anvil_single` path. Package code left as-is (no half-migration). |

---

### 7.4 Explicitly out of scope (do not apply this PRD as mint/burn modes)

| Product | Path | Why out |
|---------|------|---------|
| **DualLiquidity Linked Cross-Version Uniswap Vault** | `contracts/vaults/protocol/uniswap/crossVersion/` | Share-vs-BPT model; PRD states **no** synthetic mint/burn thresholds |
| **Standard Exchange vaults** (Uni/Aero/Camelot/Aave Stata/…) | `contracts/protocols/**`, strategy vault packages | Not DETF seigniorage |
| **Buffer pool implementation** | `contracts/protocols/dexes/balancer/v3/pools/**` | Reserve infra; not DETF gate mode |
| **IndexedexManager / Fee oracle** | `contracts/manager`, `contracts/oracles/fee` | Fees and bond terms only; **never** threshold mode control |
| **Rebasing claim token** | `contracts/vaults/protocol/RebasingClaimToken*` | Claim accounting; redemption rules separate |

---

### 7.5 Quick matrix (agents: start here)

| ID | Family | Dir | Priority | Gate price | Shared lib? | Open formalized? |
|----|--------|-----|----------|------------|-------------|------------------|
| F1 | SingleStandardExchangeDETF | `detf/standardExchange/single/` | **P0** | Synthetic | Extend | **Yes / shipped** |
| F2 | MultiVaultWeightedDetf | `detf/composed/multi-vault-weighted/` | **P1** | Synthetic | Extend | **Yes / shipped** |
| F3 | MixedBufferMultiVaultStableDetf | `detf/composed/stable/mixedBuffer/` | **P1** | Synthetic | Extend | **Yes / shipped** |
| F4 | ComposedStableCommonDetf | `detf/composed/stable/common/` | **P2** | Synthetic | Extend | **Yes / shipped** |
| F5 | SingleVaultDetf | `detf/composed/single/` | **P2** | Synthetic (migrated) | Extend | **Yes / shipped** |
| F6 | IProtocolDETF surface | `interfaces/` + tests | **P3** | Per impl | N/A | **NatSpec + thresholdMode shipped** |
| F7 | SeigniorageDETF | `vaults/seigniorage/` | **P3** | Peg (unchanged) | N/A | **Out / not shipping** |
| — | DualLiquidity | `vaults/protocol/uniswap/crossVersion/` | **Out** | N/A | N/A | N/A |

---

## 8. Suggested touch points (per modern family pattern)

When writing a family plan, search and list concrete files for:

| Concern | Typical locations |
|---------|-------------------|
| Storage | `*Repo.sol` (`mintThreshold`, `burnThreshold`, add `thresholdMode`) |
| Init | `*DFPkg.sol` / `PkgArgs` / `PkgInit` **on interface** (Crane rule); emit `ThresholdModeSet` |
| Allow helpers | `*Common.sol` wrapping mode-aware `DETFThresholdPolicy` |
| Mint gate | `*ExchangeInTarget.sol` (and facets) — live check then policy |
| Burn gate | `*ExchangeOutTarget.sol` / dual-path ExchangeIn burn branches |
| Query parity | `*Exchange*Query*.sol` if they enforce gates |
| Info | `*InfoTarget.sol` / facets — `thresholdMode` + `isMintingAllowed` + `isBurningAllowed` |
| Errors | Repo or errors interface |
| Tests | `TestBase_*`, `test/foundry/spec/vaults/detf/**` — Policy retained + Open added |
| Factories | `*_Facet_FactoryService`, `*_Pkg_FactoryService` when selectors/args change |

---

## 9. Documentation & marketing follow-through

| Doc / surface | Action after implementation |
|---------------|-----------------------------|
| This PRD | Formal **LOCKED** 2026-07-28 (plans + P0–P3 implement waves); changelog |
| Family PRDs | “Conforms to `DETF_Threshold_Modes_PRD`”; mode in PkgArgs table; remove fee-oracle threshold override language |
| `AGENTS.md` DETF section | Defaults Policy; Open optional at deploy; gates always synthetic; Open does not advertise peg |
| `frontend` research note `/research/detf` | Mention both modes only when live (UI copy deferred to separate session) |
| `research/MARKETING_AND_PERFORMANCE_FINDINGS.md` | DETF lifecycle research should cover Policy **and** Open; Open honesty: fees + impact, no peg claim |
| Launch plans | Default instances Policy (±5%) unless product explicitly chooses Open |

---

## 10. Risks

| Risk | Mitigation |
|------|------------|
| `0` arg misread as Open | Explicit `thresholdMode`; tests; NatSpec |
| Extreme Policy confused with Open | T18; product Open requires mode=Open; getters return Policy |
| Divergent Open definitions per family | Shared core lib + this PRD checklist |
| Open + stale rates → bad primary mint | Rate providers + research; do not market Open as risk-free or pegged ETF |
| Spot vs synthetic (F5 legacy) | **Mandatory** synthetic migration in this program |
| Scope explosion into claim redeem | Claim gates independent of Open |
| Legacy SeigniorageDETF half-migrated | Wave 4 audit with explicit parity or Out |
| Family PRDs still imply fee-oracle threshold overrides | Conform family PRDs when porting |

---

## 11. Success criteria (program-level)

1. **Core lib** encodes mode semantics once with pure unit tests. **Met (P0).**  
2. **P0 (F1)** supports Policy (default) and Open at deploy; tests T1–T19 green (as applicable); existing gated suites remain green. **Met (P1).**  
3. **F2 and F3** threshold-mode plans specified **and** implemented with same external behavior. **Met (P2–P3)** — formal LOCKED gate.  
4. Remaining true DETFs (F4–F5 mandatory; F6 NatSpec; F7 parity or Out) migrate to the same deploy-time gating option. *(Wave 3–4)*  
5. Every in-scope family exposes and tests `thresholdMode()`, `isMintingAllowed()`, `isBurningAllowed()`. *(F1–F5 met; F6 interface surface; F7 Out)*  
6. Inventory rows updated with “Open formalized = Yes” where shipped. **Met for F1–F5; F6 NatSpec shipped; F7 Out.**  
7. No post-deploy mutators; no fee-oracle threshold path. **Met on shipped surface.**  
8. Marketing can truthfully offer two deploy flavors (Policy ±5% vs Open create/redeem) without peg claims on Open and without keeper/admin claims.

---

## 12. Locked decisions (formerly open questions)

| # | Topic | Decision |
|---|--------|----------|
| 1 | Encoding | Explicit `enum ThresholdMode { Policy, Open }` in shared lib + each family’s `PkgArgs` / storage |
| 2 | Storage | Store mode **explicitly**; do **not** infer Open from threshold sentinels |
| 3 | Validation | After `0` resolution, Policy reverts if `mintThreshold <= burnThreshold`. Open stores resolved thresholds for display; gates ignore them |
| 4 | Extreme Policy thresholds | **Legal** (esp. tests); still Policy. Product Open requires `mode = Open` |
| 5 | Product SKUs | First-class: **Policy ±5% defaults** and **Open**. Custom Policy bands allowed by protocol/tests, not marketed as a third flavor |
| 6 | F5 / gate price | **Always synthetic** for all families; migrate spot gates in this program |
| 7 | F7 SeigniorageDETF | In-scope intent: migrate if active true DETF; Wave 4 audit may formalize **Out** if frozen legacy |
| 8 | Claim redeem | **Independent** of Open mode |
| 9 | Asymmetric modes | **Do not exist** under this PRD |
| 10 | Fee oracle | **No** path mutates or supplies mint/burn thresholds or mode; no global default band from oracle |
| 11 | Interface stability | New selectors on new package cuts; old diamonds stay Policy via storage default `0` |
| 12 | Names | **Policy** / **Open** only |
| 13 | Info surface | **MUST** expose `thresholdMode`, `isMintingAllowed`, `isBurningAllowed` + accuracy tests |
| 14 | Events | Emit `ThresholdModeSet` (or equivalent) once at init |
| 15 | Fees | Unchanged by mode |
| 16 | Open peg narrative | Open **must not** advertise a peg |
| 17 | Open two-way primary | Intentional; subject to fees and price impact |
| 18 | Nested DETFs | No composition mode rules |
| 19 | First bond | Synthetically ungated in both modes (required to initialize) |
| 20 | Zero-supply Open | No special path |
| 21 | Equality at threshold | Deadband (strict `>` / `<`) |
| 22 | Formal LOCKED | **Met 2026-07-28:** F1 + F2 + F3 plans specified **and** P0–P3 implement waves green / oversight-accepted |
| 23 | Test migration | Keep Policy/gated tests; add Open tests; dual-path extremes OK until Open helpers exist |
| 24 | UI | No frontend requirements in this PRD session |

### 12.1 Prior clarification notes (resolved ambiguity)

**What “F5 design fork” meant (resolved):** whether this program only adds mode plumbing while leaving F5 on spot-price gates, or **forces synthetic** for all gates. **Decision:** force synthetic for all families, including F5.

**What “F7 in-scope vs Out” meant (resolved intent):** whether the legacy `contracts/vaults/seigniorage/` package must receive Policy/Open parity or can be abandoned. **Decision:** program intent is migrate all true DETFs; Wave 4 audit chooses parity wiring vs formal Out if the package is frozen unused.

**What “F4 priority” meant (resolved):** F4 remains **P2** under the same product law; formal LOCKED was gated on F2/F3 plans **and** Wave 2 implement (not F4 completion). F4 ships in Wave 3.

---

## 13. Agent handoff — how to use this document

### Status of this PRD

- Product law in §§0–5, §12 is **normative**.
- Formal status **LOCKED** (2026-07-28): product law + accepted threshold-mode plans for **F1, F2, and F3** + Wave 2 implement (core lib + F1–F3) green / oversight-accepted.
- Formal LOCKED does **not** mean F4–F7 are shipped — Wave 3+ remains later work.
- Update inventory if new DETF families appear under `contracts/vaults/detf/`.

### Writing a family implementation plan

1. Copy family row from §7; obey **§16** encoding locks.  
2. Grep gate call sites in that directory; list spot vs synthetic (spot → migrate).  
3. Map §5 checklist → named tests (Policy retained + Open added).  
4. Specify PkgArgs trailing `thresholdMode`, storage layout, `ThresholdModeSet`, info selectors.  
5. Implement against shared core helpers, not a one-off Open definition.  
6. Run production-first TestBase suite.  
7. Update `DETF_Threshold_Modes_PROGRESS.md` when executing.

### Writing shared core work

- Extend `DETFThresholdPolicy` with pure mode logic + Foundry unit tests (no diamond required). **Shipped (P0).**  
- Do not deploy via `new` in production paths; pure library is fine.

### Wave 2 plan artifacts (formal LOCKED gate — met)

```text
contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETF_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md
contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md
contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md
```

---

## 14. Changelog

| Date | Note |
|------|------|
| 2026-07-27 | **Initial draft.** Intent: Policy default + Open deploy option; inventory F1–F7 + out-of-scope; cross-family checklist; shared lib + per-family plans strategy. |
| 2026-07-27 | **Product law lock.** Explicit `ThresholdMode` enum; extreme Policy legal but Open requires mode; Policy validation after resolve; Open storage display-only; Open economics + no peg; fee oracle excluded; live check outside lib; first bond orthogonal; MUST info surface + `ThresholdModeSet`; synthetic gates for all families; F2/F3 plans gate formal LOCKED; adversarial T17–T19; dual-path tests; fees mode-independent; no asymmetric modes; no nested composition rules. |
| 2026-07-27 | **§16 Pre-plan encoding locks.** PkgArgs trailing `thresholdMode`; core lib owns enum/defaults/helpers; Open uses same resolve + mint>burn validation; invalid mode reverts; canonical `ThresholdModeSet` event; plan agent prompt path. |
| 2026-07-28 | **Formal LOCKED.** Product law locked 2026-07-27; F1+F2+F3 threshold-mode plans accepted; Wave 2 implement complete and green — P0 core lib, P1 F1 Single SE (81/81), P2 F2 MultiVaultWeighted (97/97), P3 F3 MixedBuffer (72/72, oversight re-verify 2026-07-28). Inventory F1–F3 Open formalized = Yes/shipped. F4–F7 remain later waves. |
| 2026-07-28 | **Wave 4 P6:** F6 `IProtocolDETF` + errors/proxy NatSpec and `thresholdMode()` shipped (F5 implementer). F7 Seigniorage formal **Out** of threshold-mode implement scope — audit in `vaults/seigniorage/THRESHOLD_MODES_OUT.md` (peg chassis, no threshold storage, consolidation reference-only). Inventory F6/F7 updated. Next: P7 AGENTS + family PRD conform notes. |

---

## 15. References

| Resource | Path / note |
|----------|-------------|
| Threshold pure lib | `contracts/vaults/detf/core/DETFThresholdPolicy.sol` |
| AGENTS DETF expectations | repo `Agents.md` / `AGENTS.md` |
| Marketing findings (DETF research not started) | `research/MARKETING_AND_PERFORMANCE_FINDINGS.md` §5–§6 |
| Research playbook Tier 5 DETF | `research/RESEARCH_PLAYBOOK.md` |
| Frontend research design | `frontend/RESEARCH_SECTION_DESIGN.md` |
| Gold family PRD | `contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETF_PRD.md` |
| Plan-agent prompt (copy for next agent) | `contracts/vaults/detf/DETF_Threshold_Modes_PLAN_AGENT_PROMPT.md` |
| Execution progress tracker (created by plan agent) | `contracts/vaults/detf/DETF_Threshold_Modes_PROGRESS.md` |

---

## 16. Pre-plan encoding locks (normative for plans and implementers)

These locks prevent F1/F2/F3 plans from inventing incompatible ABIs or helper surfaces. **Do not re-open** without an explicit PRD revision.

### 16.1 `PkgArgs` field placement (ABI)

- Append `ThresholdMode thresholdMode` as a **trailing** field on every in-scope family’s `PkgArgs` (same convention for all families).
- Do **not** insert `thresholdMode` in different positions per family.
- Document the final field order in each family plan’s API diff.
- Scripts / typed factories that ABI-encode `PkgArgs` must be updated when the field is added (breaking encode change for that struct).

### 16.2 Core lib ownership

Live in **`contracts/vaults/detf/core/DETFThresholdPolicy.sol`** (or one sibling core lib only):

| Item | Requirement |
|------|-------------|
| `ThresholdMode` enum | `Policy = 0`, `Open = 1` |
| Defaults | `DEFAULT_MINT_THRESHOLD = 1.05e18`, `DEFAULT_BURN_THRESHOLD = 0.95e18` |
| Resolve | `resolveThresholds(mintArg, burnArg) → (mint, burn)` with `0 → default` |
| Allow helpers | `isMintingAllowed(mode, threshold, price)` / `isBurningAllowed(...)` — **no `live` param** |
| Optional | `isOpenMode(mode)` |

Families **import** these; they must not redefine default constants or invent alternate Open short-circuit logic.

### 16.3 Open mode resolve and validation

| Case | Behavior |
|------|----------|
| Open + `0,0` thresholds | Resolve to defaults and **store** (display only; gates ignore) |
| Open + custom thresholds | Store resolved values for getters; gates ignore |
| Open + `mintThreshold <= burnThreshold` after resolve | **Same reject as Policy** — revert at init |
| Policy + `mintThreshold <= burnThreshold` after resolve | Revert at init |
| `thresholdMode` value `> Open` (invalid enum / raw uint) | **Revert at init** |

Summary: **same numeric resolve + same `mint > burn` validation for both modes**; Open only changes gate short-circuit (and marketing/peg narrative).

### 16.4 Canonical init event

```solidity
event ThresholdModeSet(
    ThresholdMode mode,
    uint256 mintThreshold,
    uint256 burnThreshold
);
```

- Emit **once** from the path that writes storage at init / postDeploy (one place per family).
- Payload uses **resolved** threshold values (post-`0` defaulting).

### 16.5 Work ordering (plans and execution)

| Order | Work | Why |
|-------|------|-----|
| 0 | Core lib plan + implement + pure unit tests | Shared API surface families copy |
| 1 | F1 SingleStandardExchangeDETF plan + implement | Gold patterns |
| 2 | F2 + F3 plans (may draft in parallel after lib API fixed) then implement | Formal PRD **LOCKED** gate — **met 2026-07-28** |
| 3 | F4 / F5 / F6 / F7 | Later waves per inventory |

### 16.6 Plan deliverable checklist (every family plan)

Each family threshold-mode plan **must** include:

1. Concrete file touch list (Repo / DFPkg / Common / ExchangeIn–Out / Info / Facet selectors / FactoryService if args change / TestBase / specs)
2. `PkgArgs` diff (trailing `thresholdMode` + full field order)
3. Storage layout note (new `thresholdMode` field)
4. Gate call-site table (function → live check → policy check)
5. Synthetic function name used for gates (prove no spot)
6. §5 test IDs T1–T19 → concrete test names (N/A only with reason)
7. Explicit out-of-plan list (claim redeem, UI, fee oracle, asymmetric modes)

### 16.7 Agent prompt and progress tracker

| Artifact | Path |
|----------|------|
| Plan-agent prompt (paste into next agent) | `contracts/vaults/detf/DETF_Threshold_Modes_PLAN_AGENT_PROMPT.md` |
| Execution progress tracker (created/updated by agents) | `contracts/vaults/detf/DETF_Threshold_Modes_PROGRESS.md` |

Execution agents implement by phase, update the progress tracker only (single source of execution status).

---

*Formally LOCKED 2026-07-28. Product law + §16 encoding locks + Wave 2–4 shipped (core + F1–F5 + F6 NatSpec; F7 formal Out). Next: AGENTS conform notes (P7).*
