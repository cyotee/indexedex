# Product Requirements Document (PRD)

## Title

**DETF Protocol Seigniorage Compound + Natural Supply Expansion** — family-agnostic product law for (1) compounding protocol-owned bond NFT seigniorage into the reserve, and (2) classic Olympus-style natural supply expansion to bond holders, keeper-free

## Status

**LOCKED — product law accepted 2026-07-30** (requirements clarification 2026-07-29; Stages 00–09 implemented and green; AGENTS.md common expectations updated)

| Field | Value |
|-------|--------|
| **Status** | **LOCKED** — 2026-07-30. Do not re-litigate without an explicit PRD revision |
| **Scope** | Family-agnostic product law for **protocol NFT reward compound** and **Policy-mode natural supply expansion** |
| **Implementation style** | Shared semantics (`detf/core` helpers); **stage plans** 00–09 under `contracts/vaults/detf/` |
| **Related product narrative** | OHM-class policy unit: passive synthetic gates + protocol-owned depth + optional natural expansion to bonders; immutable instances; **no keeper** |
| **Companion program** | Threshold Modes (Policy vs Open gates — **LOCKED**, orthogonal but coupled for expansion eligibility) |
| **AGENTS.md** | Common DETF expectations include protocol compound + Policy expansion (updated with this lock) |

**Implementation status:** Stages **00–09 green** (see program index). This PRD remains the normative product law for further changes.

---

## 0. Intent (why this exists)

### 0.1 Product problems

#### P1 — Protocol seigniorage does not deepen reserve

True DETFs split capital-backed mint/bond seigniorage so an **inventory** slice accrues to bond NFT **reward** accounting (DETF as reward token). **User** bond holders correctly **preview and claim** free DETF via `claimRewards` / pending rewards **while the bond is still locked**.

The **DETF-owned (protocol) bond NFT** was intended to turn its seigniorage share into **more protocol-owned reserve BPT** (compound into the reserve), so:

- Protocol-owned depth grows with seigniorage.
- **Rebasing claim** holders (claim on protocol NFT BPT) see **redemption-rate** improvement when protocol principal grows.

**Shipped behavior:** protocol inventory DETF is (or can sit as) **claimable free DETF** on the same reward ledger; there is **no** normative auto-compound of protocol rewards into the reserve. That is a **requirements/implementation gap** relative to product intent.

#### P2 — No classic natural supply expansion

Under **Policy** mode, primary mint is open only when synthetic is **above** the mint threshold, and only when a user supplies vault-share (or family-equivalent) capital. There is **no** continuous, keeper-free expansion of DETF supply awarded to bond holders while the unit is rich — the classic Olympus **stake/rebase-style** expansion of free float toward peg.

Capital-backed seigniorage already rewards bonders when others mint; it does **not** replace time/premium expansion when the market is rich but primary volume is quiet.

### 0.2 Goals

1. Define **one product law** for protocol-owned bond NFT **compound-to-reserve** across all in-scope true DETFs.
2. Define **one product law** for **natural supply expansion** to bond holders (same distribution shape as seigniorage reward share), **Policy-only**, **keeper-free**, with **preview then finalize on claim/withdraw**.
3. Keep **user** bond rewards **claimable free DETF** while locked (do not force user auto-compound).
4. Make protocol compound a **normative success criterion** for claim-backed families: protocol BPT ↑ → claim redemption rate **can** rise.
5. Execute in **two phases per family** (compound green, then expansion green) to limit behavioral drift.
6. Preserve: immutable unowned instances, synthetic pricing as gate input, inert→live, production-first tests, no off-chain bot requirement.

### 0.3 Non-goals

- Olympus V3 **RBS walls/cushions** / Heart keepers / Kernel modules.
- Post-deploy mutation of expansion rate, compound rules, or threshold mode.
- Auto-compound of **user** (or fee-recipient) bond NFT rewards into the reserve (v1).
- Requiring a new “stake DETF” surface for Phase 2 (optional follow-on; not required).
- Changing primary mint/burn **route set**, fee schedules, or Threshold Modes Policy/Open encoding.
- `contracts/vaults/detf/composed/single` (**out of scope** — package removal in progress).
- DualLiquidity pure pro-rata vaults that are **not** true DETFs.
- Legacy `contracts/vaults/seigniorage/` package (**out of scope** for this program).
- Dual / embedded DETFs under `detf/dual/**` (**out of scope** unless product re-supports later).
- Marketing claims of guaranteed peg, APY, or risk-free expansion yield.

### 0.4 Locked decisions (summary)

| Decision | Choice |
|----------|--------|
| Who auto-compounds into reserve? | **Protocol-owned bond NFT only** |
| User bond seigniorage / expansion rewards? | **Claimable free DETF**; harvestable **while lock matures** (`claimRewards` / family equivalent) |
| Fee-recipient NFT? | **Claimable** (same as users for v1); does **not** auto-compound |
| Compound method | **Single-sided DETF join** into the reserve (self-leg join) |
| Compound trigger | **Lazy** on existing vault/DETF touch points that already update global rewards (no bot) |
| Public compound surface | **`compoundProtocolRewards()` (or family-equivalent name) required** on all in-scope families — in addition to lazy hooks; not a keeper substitute |
| Compound join failure | **Best-effort:** reward update proceeds; if single-sided join fails, leave protocol pending for next touch / public compound; no whole-tx fail-closed on join failure |
| Claim coupling | Compound **must** increase protocol-owned BPT so claim **redemption rate can rise** when claim package is wired |
| Expansion distribution | **Same shape as seigniorage share** — bond effective-share reward ledger |
| Expansion index / mint | **Fold into `rewardPerShares` + mint-on-update** (free DETF minted into reward vault on lazy update; same ledger as seigniorage) |
| Expansion formula shape | **Premium-closure rate** (close a fixed % of synthetic premium toward peg per unit time while mint-allowed); exact rate/cap numbers in family/core plans |
| Expansion mode | **Policy only**; accrue only while synthetic is on the **mint-allowed** side of Policy; **Open = no expansion** |
| Expansion settlement UX | Staking-style: **preview pending**, finalize on **claim / unlock paths** (no keeper) |
| Program structure | One overall PRD (this file); **per-family** implementation plans; **Phase 1 compound → tests green → Phase 2 expansion → tests green** |
| Family scope | Single SE, multi-vault weighted, mixed-buffer, composed stable common. **Out:** composed/single, seigniorage/, detf/dual/** |

### 0.5 Unified narrative

```text
Chassis:     detfToken + reserve + bond NFT + optional rebasing claim
Phase 1:     Protocol NFT seigniorage → single-sided DETF join → more protocol BPT
             (lazy hooks + required public compoundProtocolRewards; best-effort on join fail)
Phase 2:     Policy + rich synthetic → premium-closure expansion mint → rewardPerShares ledger
Users:       preview + claim free DETF rewards while bond matures
Protocol:    compounds its reward share into reserve (claim holders share via BPT backing)
Keeper:      none — lazy update on existing touch points (+ public compound for catch-up)
```

**Headline:**

> Policy DETFs deepen protocol-owned reserve by compounding the protocol bond NFT’s seigniorage into the pool, and may mint natural supply expansion to bond holders while synthetic is rich — without keepers. Users still harvest free DETF rewards on their bonds while locked. Claim tokens track protocol BPT, so protocol compound improves claim backing.

---

## 1. Definitions

| Term | Meaning |
|------|---------|
| **True DETF** | Diamond **is** the share ERC-20; seigniorage mint/burn vs a reserve that includes a DETF self-leg (or family-equivalent seigniorage design). |
| **Synthetic price** | Fully diluted / reserve-backed unit price used for Policy gates (abstract **1e18** peg narrative under Policy). |
| **Bond NFT vault** | Lock vault: BPT (or family principal) positions with **effective shares**, lock boost, DETF (or family) **reward token**. |
| **Protocol-owned bond NFT** | DETF-owned NFT position (protocol principal + reward accrual). |
| **Fee-recipient NFT** | Fee-to / fee-recipient position on the same vault (v1: claimable rewards, no auto-compound). |
| **Seigniorage inventory / reward share** | Mint-split (and related) DETF allocated to the bond reward ledger for bonder / inventory accrual. |
| **Protocol compound** | Realization of **protocol NFT pending reward DETF** into **additional protocol-owned reserve BPT** via **single-sided DETF join**. |
| **Natural supply expansion** | Minting free DETF **without** new external capital, while Policy mint-side synthetic condition holds, credited through the **same reward ledger** as seigniorage. |
| **Premium-closure rate** | Expansion formula shape: while mint-allowed, advance free-float expansion that closes a deploy-time **fixed fraction of (synthetic − peg)** per unit time (exact constants in family/core plans), subject to catch-up caps. |
| **Mint-on-update** | On lazy reward update (when expansion is accruing), mint free DETF into the bond reward vault and fold into **`rewardPerShares`** — not a separate expansion airdrop ledger. |
| **Lazy update** | Accrual and/or compound executed on user/protocol touch points that already update global rewards; no off-chain bot. |
| **`compoundProtocolRewards`** | Required public entrypoint that updates global rewards and attempts protocol NFT compound (best-effort join); family-equivalent name allowed with NatSpec. |
| **Phase 1 / Phase 2** | Program stages: compound first (green), then expansion (green), per family (see §7). |

Role naming remains as in AGENTS.md (`rateAsset`, `pairToken`, `underlyingVault`, `vaultShare`, `detfToken`, `reservePool` / `reserveBpt`, `rebasingClaimToken`, etc.). No brand tokens in production surfaces.

---

## 2. Current baseline (normative “as shipped” before this program)

Documented so implementers know what changes:

1. **Capital-backed mint/bond** may mint DETF; usage fee + seigniorage incentive split produces **user / fee / inventory** DETF legs (family-specific field names).
2. **Inventory DETF** is typically minted to the **bond NFT vault** as **reward token** and accrues via `rewardPerShares` / effective shares.
3. **User** holders: `pendingRewards` + `claimRewards` **without** requiring unlock; principal unlock separate.
4. **Protocol NFT** participates in the same reward index but **does not** normatively **single-sided join** pending DETF into the reserve.
5. **Rebasing claim** redemption rate is driven by **protocol NFT BPT value**, not free DETF reward balances.
6. **Threshold modes:** Policy deadband vs Open primary market ([`DETF_Threshold_Modes_PRD.md`](./DETF_Threshold_Modes_PRD.md)).
7. **No** natural supply expansion mint path.

---

## 3. Phase 1 — Protocol seigniorage compound (normative)

### 3.1 Who compounds

| Position | Reward handling (v1) |
|----------|----------------------|
| **User bond NFT** | **Claimable free DETF** (unchanged intent) |
| **Fee-recipient NFT** | **Claimable free DETF** (v1) |
| **Protocol-owned bond NFT** | **Auto-compound** pending reward DETF into reserve via **single-sided DETF join**; increases **protocol-owned BPT** |

Do **not** auto-compound user or fee-recipient rewards in v1.

### 3.2 Compound method (locked)

**Single-sided DETF join** into the family’s reserve pool:

- Input: free DETF amount attributed as **protocol NFT rewards** (after global reward update).
- Action: join **DETF self-leg only** into `reservePool` (family join primitive: prepay unbalanced / equivalent).
- Output: **BPT** credited to **protocol-owned** inventory (protocol NFT principal / DETF-held BPT accounting as the family already models protocol ownership).
- **No** requirement to sell DETF for vault shares or balanced two-leg join in v1 (explicit product choice; weight skew accepted for protocol compound size).

### 3.3 When compound runs (locked)

**Lazy** on existing touch points that **already update global bond rewards**, including at least:

- Bond create / add-to-position paths that update rewards  
- `claimRewards` / harvest paths  
- Redeem / unlock / sell-to-protocol-NFT paths  
- Capital-backed mint paths that deposit inventory DETF into the reward vault  
- Family-equivalent entrypoints that call `_updateGlobalRewards` (or successor)

**Plus required public surface:**

- Every in-scope family **must** expose **`compoundProtocolRewards()`** (or family-equivalent name with NatSpec) that updates global rewards and attempts protocol compound. This is **not** a keeper substitute and **does not** replace lazy hooks; it is a required catch-up / test / ops surface.

**Rules:**

1. Before compound: **update global rewards** so protocol pending is current.  
2. If protocol pending reward DETF **> 0** (and any dust threshold family defines): attempt **single-sided join**, credit protocol BPT, zero protocol’s claimable free DETF debt for the compounded amount.  
3. **No keeper.** Lazy hooks remain normative for automatic compound; the public entrypoint is **required** in addition.  
4. **Join failure = best-effort (locked):** if the single-sided DETF join cannot complete (Balancer/router revert, zero joinable amount beyond dust, etc.):
   - Global reward update **must still succeed** (do not fail-closed the whole user touch for join failure alone).
   - Protocol pending reward DETF **remains** for the next lazy touch and/or `compoundProtocolRewards()`.
   - Reward debt / accounting must stay **consistent** (no double-claim, no invented debt wipe without join).
   - Documented **dust** residuals (≤ few-wei style join math) may be skipped per family plan.
   - **Silent long-term strand** of large free DETF on the protocol NFT as steady state is **not** acceptable when lazy touches and/or the public compound path are used — tests must exercise successful compound and retry-after-failure.

### 3.4 Claim token coupling (locked)

When a family wires **rebasing claim**:

- Protocol compound **must** increase the **protocol-owned BPT** that claim valuation uses.
- Tests **must** show that after protocol compound, **claim redemption rate** (or equivalent preview) **can rise** vs pre-compound baseline when other factors are held equal (or document strict inequality / tolerance only if math forces it).
- Families **without** claim package still **must** compound protocol rewards to protocol BPT; claim-rate tests apply only where claim is deployed.

### 3.5 What Phase 1 does **not** change

- User `claimRewards` UX and lock rules.  
- Primary mint/burn gates (Threshold Modes).  
- Capital-backed seigniorage **existence** (only the **protocol sink**: free DETF → compound rather than long-lived claimable protocol free DETF).  
- Natural expansion (Phase 2).

### 3.6 Phase 1 acceptance (cross-family)

| # | Criterion |
|---|-----------|
| C1 | Protocol NFT pending seigniorage DETF is compounded via single-sided DETF join on lazy touch points |
| C2 | Protocol-owned BPT (or family protocol principal) increases by join output (exact or documented ≤ few-wei) |
| C3 | User positions still claim free DETF rewards while locked |
| C4 | Fee-recipient remains claimable (v1) |
| C5 | Claim-wired families: redemption rate / BPT backing path reflects protocol compound |
| C6 | No keeper; no post-deploy compound config; **`compoundProtocolRewards()` (or equivalent) is exposed and works** |
| C7 | Production-first tests; no SUT mocks |
| C8 | Join failure is best-effort: touch/public path leaves protocol pending intact and consistent; retry succeeds when join is possible |

---

## 4. Phase 2 — Natural supply expansion (normative)

### 4.1 What expands

While the instance is **live**, **`thresholdMode == Policy`**, and **synthetic is mint-allowed** under Policy (same strict inequality as primary mint: `synthetic > mintThreshold` after resolve):

- The system may **mint free DETF** (no external vault-share deposit required for this mint).
- Minted DETF is credited through the **same bond reward distribution** as seigniorage inventory (effective shares / reward-per-share accounting).

**Open mode:** natural expansion is **off** (no accrual). Open primary mint/burn rules unchanged.

### 4.2 Who receives expansion

| Recipient | Treatment |
|-----------|-----------|
| Bond holders (effective shares) | Expansion DETF as **rewards** — same as seigniorage share |
| Protocol-owned NFT | Receives its weight of expansion as rewards, then **Phase 1 compound** turns that into protocol BPT on lazy update |
| Fee-recipient NFT | Receives its weight as **claimable** free DETF (v1) |
| Free DETF holders (unlocked) | **No** expansion unless they hold a bond position (v1) |
| Rebasing claim holders | **Indirect** via protocol compound increasing protocol BPT (not a separate free DETF airdrop) |

**Distribution law (locked):** expansion is distributed **the same way as the seigniorage share** to bond holders as rewards. Do not invent a second weight scheme for v1.

### 4.3 Keeper-free accrual + preview / finalize (locked)

Classic staking-style settlement:

1. **Accounting model (locked):** fold expansion into the existing **`rewardPerShares`** ledger via **mint-on-update** — on lazy reward update while expansion is accruing, **mint free DETF** into the bond reward vault and advance reward-per-share the same way seigniorage inventory does. Do **not** invent a second end-user weight scheme or a separate claimable expansion token. Optional debug getters (e.g. last expansion timestamp / last expansion mint amount) are fine; the user path remains `pendingRewards` / `claimRewards`.  
2. Accrual amount is a pure function of **time**, **synthetic condition**, **total effective shares**, and **deploy-time premium-closure rate/cap parameters** (see §4.4).  
3. **Lazy realization** on the same class of touch points as Phase 1 reward updates (and any path that updates global rewards before compound).  
4. **Preview:** `pendingRewards` (or family preview) includes expansion that would be realized if updated now (**view-consistent** with claim).  
5. **Finalize:** user **`claimRewards`** / unlock harvest / sell-to-protocol harvest — same as seigniorage rewards.  
6. **No off-chain bot.** Idle periods: virtual accrual in views; first touch may catch up subject to **deploy-time caps** (family/core plan must define anti-jump caps).

### 4.4 Expansion parameters (deploy-time only)

| Param | Rule |
|-------|------|
| Expansion on/off | Implicit: **Policy + live + formula**; Open never expands |
| Formula shape | **Premium-closure rate (locked cross-family default):** while mint-allowed, expand free float to close a deploy-time **fixed fraction of (synthetic − peg)** per unit time (OHM-style pull toward peg). Not fixed-APY-by-default; not hybrid-by-default. |
| Rate / gap-closure / caps | **PkgArgs → resolve → instance storage** only; **not** fee oracle; **no** post-deploy setter |
| Threshold for accrual | **Mint-side Policy gate** on synthetic (reuse resolved `mintThreshold` / mode) unless a family plan documents a dedicated expansion threshold **still deploy-time and still Policy-only** |
| Defaults | Family/core plans propose **numeric** defaults (closure fraction, catch-up cap, dust); PRD requires **documented defaults** and validation (rate ≥ 0, caps sane, Open ignores expansion fields) |

Exact **numbers** (closure fraction, max catch-up mint, dust) are **implementation-plan-level**. The formula shape is **not** open: premium-closure. Implementation must:

- Be deterministic and previewable.  
- Pull synthetic toward peg when expansion mints free supply (dilution).  
- Cap catch-up after long idle.  
- Not require keepers.

### 4.5 Interaction with capital-backed mint

| Path | Capital | When | Reward ledger |
|------|---------|------|---------------|
| Primary mint / bond seigniorage | External vault share (etc.) | Policy mint allowed (or bond bootstrap rules) | Existing inventory split |
| Natural expansion | None | Policy + mint-allowed synthetic + live | Same ledger as seigniorage share |

Both may mint DETF; both feed rewards. Accounting must not double-count or strand inventory. Phase 1 compound applies to **protocol** reward credits from **either** source.

### 4.6 Phase 2 acceptance (cross-family)

| # | Criterion |
|---|-----------|
| E1 | Expansion accrues only when live + Policy + synthetic mint-allowed (premium-closure rate; mint-on-update into rewardPerShares) |
| E2 | Open instances never accrue expansion |
| E3 | Distribution matches seigniorage reward weights (effective shares) |
| E4 | Preview pending == claim amount (exact or documented dust) after update |
| E5 | Users claim expansion while bond locked |
| E6 | Protocol’s expansion share compounds per Phase 1 (BPT ↑; claim rate path when wired) |
| E7 | No keeper; deploy-time params only |
| E8 | Idle catch-up respects caps; adversarial synthetic manipulation covered in family adversarial plans as needed |
| E9 | Phase 1 suite remains green |

---

## 5. Family inventory (in scope / out of scope)

### 5.1 In scope (true DETFs)

| Family | Path | Notes |
|--------|------|-------|
| Single Standard Exchange | `standardExchange/single/` | Gold pathfinder recommended for shared patterns |
| Multi-vault weighted | `composed/multi-vault-weighted/` | Weighted multi-leg reserve |
| Mixed-buffer multi-vault stable | `composed/stable/mixedBuffer/` | Buffer burn rules unchanged by this PRD |
| Composed stable common | `composed/stable/common/` | Claim / rebasing surfaces often wired — Phase 1 claim coupling critical |

Shared: `detf/core/*`, `detf/bondNft/*`, `detf/claimToken/*`, `detf/reusable/*` as needed.

### 5.2 Explicitly out of scope

| Item | Reason |
|------|--------|
| `contracts/vaults/detf/composed/single` | **Removal in progress** — do not extend |
| `contracts/vaults/seigniorage/` | **Out of scope** for this program (legacy package; do not port compound/expansion here) |
| `detf/dual/**` | **Out of scope** unless product explicitly re-supports dual as a live family later |
| DualLiquidity / pure SE vaults without true DETF seigniorage | Not true DETFs |
| Threshold Modes redesign | Already LOCKED; this PRD consumes Policy/Open |
| RBS Operator/Heart | Different product |

### 5.3 Pathfinder recommendation (non-normative process)

1. Shared helpers + **Single Standard Exchange** Phase 1 → green.  
2. Single SE Phase 2 → green.  
3. Roll Phase 1 then Phase 2 to remaining families using the same PRD law (per-family plans only specialize wiring).

Families may proceed in parallel **only** after shared semantics are stable enough to avoid forked product law.

---

## 6. Governance, immutability, and ops

| Topic | Law |
|-------|-----|
| Instance ownership | Remains **immutable, unowned** after deploy |
| Compound / expansion params | **Deploy-time only** via PkgArgs → storage |
| Fee oracle | Fees and bond **lock terms** only — **not** expansion rate, not compound toggle, not thresholds/mode |
| Disable | Existing vault registry disable remains the kill-switch surface |
| Keepers | **Forbidden** as a requirement for correct accrual or compound |

---

## 7. Program execution model (planning law)

### 7.1 Artifacts

| Artifact | Owner |
|----------|--------|
| **This PRD** | Cross-family product law |
| **Program index (stage DAG + agent routing)** | [`DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md`](./DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md) |
| **Stage plans (one stage per file)** | See program index catalog (Stages 00–09): shared P1, four family P1, shared P2, four family P2 |

**Stage plan paths (normative for agents):**

| Stage | Plan |
|-------|------|
| 00 Shared P1 | [`00_DETF_Protocol_Compound_Shared_IMPLEMENTATION_AND_TEST_PLAN.md`](./00_DETF_Protocol_Compound_Shared_IMPLEMENTATION_AND_TEST_PLAN.md) |
| 01 Single SE P1 | [`01_SingleStandardExchangeDETF_Protocol_Compound_IMPLEMENTATION_AND_TEST_PLAN.md`](./01_SingleStandardExchangeDETF_Protocol_Compound_IMPLEMENTATION_AND_TEST_PLAN.md) |
| 02 Multi-vault P1 | [`02_MultiVaultWeightedDetf_Protocol_Compound_IMPLEMENTATION_AND_TEST_PLAN.md`](./02_MultiVaultWeightedDetf_Protocol_Compound_IMPLEMENTATION_AND_TEST_PLAN.md) |
| 03 Mixed-buffer P1 | [`03_MixedBufferMultiVaultStableDetf_Protocol_Compound_IMPLEMENTATION_AND_TEST_PLAN.md`](./03_MixedBufferMultiVaultStableDetf_Protocol_Compound_IMPLEMENTATION_AND_TEST_PLAN.md) |
| 04 Composed stable P1 | [`04_ComposedStableCommonDetf_Protocol_Compound_IMPLEMENTATION_AND_TEST_PLAN.md`](./04_ComposedStableCommonDetf_Protocol_Compound_IMPLEMENTATION_AND_TEST_PLAN.md) |
| 05 Shared P2 | [`05_DETF_Natural_Expansion_Shared_IMPLEMENTATION_AND_TEST_PLAN.md`](./05_DETF_Natural_Expansion_Shared_IMPLEMENTATION_AND_TEST_PLAN.md) |
| 06 Single SE P2 | [`06_SingleStandardExchangeDETF_Natural_Expansion_IMPLEMENTATION_AND_TEST_PLAN.md`](./06_SingleStandardExchangeDETF_Natural_Expansion_IMPLEMENTATION_AND_TEST_PLAN.md) |
| 07 Multi-vault P2 | [`07_MultiVaultWeightedDetf_Natural_Expansion_IMPLEMENTATION_AND_TEST_PLAN.md`](./07_MultiVaultWeightedDetf_Natural_Expansion_IMPLEMENTATION_AND_TEST_PLAN.md) |
| 08 Mixed-buffer P2 | [`08_MixedBufferMultiVaultStableDetf_Natural_Expansion_IMPLEMENTATION_AND_TEST_PLAN.md`](./08_MixedBufferMultiVaultStableDetf_Natural_Expansion_IMPLEMENTATION_AND_TEST_PLAN.md) |
| 09 Composed stable P2 | [`09_ComposedStableCommonDetf_Natural_Expansion_IMPLEMENTATION_AND_TEST_PLAN.md`](./09_ComposedStableCommonDetf_Natural_Expansion_IMPLEMENTATION_AND_TEST_PLAN.md) |

### 7.2 Two-phase rule (mandatory)

For **each** in-scope family:

```text
Phase 1: Protocol compound implementation + tests
         → all Phase 1 acceptance criteria green
Phase 2: Natural supply expansion + tests
         → all Phase 2 acceptance criteria green
         → Phase 1 suite still green
```

**Do not** ship expansion for a family before that family’s Phase 1 is green.  
**Do not** mix both behaviors in a single unscoped change set without a green bar between them.

### 7.3 Testing expectations (both phases)

Align with AGENTS.md + `indexedex-testing` + `indexedex-adversarial-testing`:

1. Production-first; **no mocks of SUT** (DETF, facets, DFPkg, manager, registry, fee oracle, attached SE vaults under test).  
2. Gold TestBases / family `TestBase_*`.  
3. Preview == execution (or documented dust) for claim/compound amounts where closed-form.  
4. Phase 1: locked user still claims rewards; protocol BPT grows on compound; claim rate path when wired; public `compoundProtocolRewards` works; join-failure best-effort + retry.  
5. Phase 2: Policy expands when rich via premium-closure; Open does not; mint-on-update into `rewardPerShares`; pending preview; claim while locked; protocol compound of expansion share.  
6. Reentrancy / reward-debt transfer footguns covered when positions are transferable.

---

## 8. Interfaces and observability (minimum)

Families must expose enough surface for UX and tests (names may match existing bond vault APIs):

| Surface | Purpose |
|---------|---------|
| `pendingRewards(tokenId)` (or equivalent) | Preview seigniorage + expansion after virtual update |
| `claimRewards(tokenId, recipient)` | Finalize free DETF for user/fee positions |
| **`compoundProtocolRewards()`** (or family-equivalent name) | **Required:** update global rewards + attempt protocol NFT single-sided compound (best-effort on join failure) |
| Protocol BPT / protocol NFT principal getters (existing or documented) | Prove compound |
| `syntheticPrice`, `thresholdMode`, `mintThreshold`, `isMintingAllowed` | Expansion gate observability |
| Optional: last expansion mint / last accrual timestamp | Debugging and tests (expansion itself is folded into `rewardPerShares`) |

New public functions require NatSpec; role names only.

---

## 9. Risks and accepted tradeoffs

| Risk / tradeoff | Handling |
|-----------------|----------|
| Single-sided DETF join **skews** reserve toward self-leg | **Accepted** in v1; size limited by reward magnitude; revisit balanced compound only via PRD revision |
| Expansion dilutes free float / synthetic | **Intended** under Policy when rich (premium-closure) |
| Long idle catch-up mint spike | Deploy-time **caps**; tests |
| Protocol free DETF briefly exists between accrual and compound | Allowed; best-effort join leaves pending for next lazy touch / `compoundProtocolRewards()`; not steady-state abandonment when those paths are used |
| Join failure on a user touch | **Best-effort** — do not fail the whole user action solely because compound join reverts |
| Open mode users expect expansion | Product law: **no**; document in UI/copy later |
| `composed/single` / `seigniorage/` / `detf/dual/**` | Out of scope (see §5.2) |

---

## 10. Open parameters (fill in family/core plans; not re-litigate product law)

These are **not** open product *direction*; they need numeric/API choices only:

1. **Numeric** premium-closure defaults (closure fraction per unit time) and catch-up cap.  
2. Dust thresholds for compound and reward harvest.  
3. Exact list of lazy touch points per family (must include reward-update paths listed in §3.3 at minimum).  
4. Exact ABI name/signature of the required public compound entrypoint if not literally `compoundProtocolRewards()`.  
5. Optional debug observability for expansion mint amounts/timestamps (not a second reward ledger).

**Already locked (do not re-open in family plans):**

- Expansion formula **shape** = premium-closure (not fixed APY default).  
- Expansion accounting = fold into `rewardPerShares` + mint-on-update.  
- Public compound entrypoint = **required**.  
- Join failure = **best-effort**, leave pending.  
- Scope Out: `composed/single`, `contracts/vaults/seigniorage/`, `detf/dual/**`.

---

## 11. Success criteria (program)

| # | Criterion |
|---|-----------|
| S1 | This PRD formal **LOCKED** after review — **done 2026-07-30** |
| S2 | Shared semantics documented; stage plans 00–09 for each in-scope family — **done** |
| S3 | Every in-scope family Phase 1 green (C1–C8) — **done** |
| S4 | Every in-scope family Phase 2 green (E1–E9) — **done** |
| S5 | AGENTS.md common expectations updated for protocol compound + Policy expansion — **done 2026-07-30** |
| S6 | Out-of-scope packages never extended by this program (`composed/single`, `seigniorage/`, `detf/dual/**`) |

---

## 12. Document control

| Item | Value |
|------|--------|
| **Created** | 2026-07-29 |
| **Status** | **LOCKED** (2026-07-30) |
| **Supersedes** | Implicit incorrect assumption that protocol seigniorage already compounds into reserve |
| **Related** | Threshold Modes PRD; family DETF PRDs; bond NFT + claim packages; AGENTS.md common expectations |
| **Shipped** | Stages 00–09 per program index; shared libs + per-family compound/expansion + tests |

### 12.1 Clarification log (requirements)

| Topic | Locked choice |
|-------|----------------|
| Compound target | Protocol-owned bond NFT only |
| Compound method | Single-sided DETF join |
| Compound trigger | Lazy on existing reward-update touch points |
| Public compound surface | **`compoundProtocolRewards()` required** on all in-scope families (plus lazy hooks) |
| Compound join failure | **Best-effort:** leave protocol pending for next touch / public compound; do not fail-closed the whole user touch for join failure alone |
| User / fee rewards | Claimable free DETF while locked |
| Expansion distribution | Same as seigniorage share to bond rewards |
| Expansion accounting | **Fold into `rewardPerShares` + mint-on-update** |
| Expansion formula shape | **Premium-closure rate** (numeric rate/cap in family/core plans) |
| Expansion mode | Policy only; Open off |
| Claim | Protocol compound must raise protocol BPT so redemption rate can rise |
| Scope In | Single SE; multi-vault weighted; mixed-buffer; composed stable common |
| Scope Out | `composed/single`; `contracts/vaults/seigniorage/`; `detf/dual/**` (unless re-supported later) |
| Staging | Phase 1 compound green → Phase 2 expansion green per family |

### 12.2 Review Q&A lock (2026-07-29)

| Question | Answer |
|----------|--------|
| Default Phase 2 formula shape? | Premium-closure rate |
| Legacy `contracts/vaults/seigniorage/`? | Out of scope |
| `detf/dual/**`? | Out unless explicitly re-supported later |
| Join failure on lazy touch? | Best-effort; leave pending for next touch |
| Public `compoundProtocolRewards()`? | **Required** on all families |
| Expansion index design? | Fold into `rewardPerShares` + mint-on-update |

---

## 13. One-page law (agents)

```text
1. Protocol NFT seigniorage rewards → single-sided DETF join → more protocol BPT
   (lazy hooks + required compoundProtocolRewards; no bot).
2. Join failure is best-effort: leave protocol pending; reward debt stays consistent.
3. User (+ fee) bond rewards stay claimable free DETF while locked.
4. Claim packages: compound increases protocol BPT backing / redemption rate path.
5. Natural expansion (Phase 2): Policy + live + synthetic mint-allowed;
   premium-closure formula; mint free DETF into rewardPerShares on update;
   Open never expands.
6. Preview pending; finalize on claim/withdraw; no keeper.
7. Deploy-time params only; immutable instances.
8. Per family: implement compound + tests green, then expansion + tests green.
9. Do not touch composed/single, seigniorage/, or detf/dual/** (out of scope).
```
