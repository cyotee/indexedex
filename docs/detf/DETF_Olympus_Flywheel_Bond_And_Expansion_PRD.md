# Product Requirements Document (PRD)

## Title

**DETF Olympus-Class Flywheel** — free-DETF bonding/staking, expansion eligibility, market vs synthetic premium, and launch runway

## Status

**DRAFT v0.1 — 2026-08-04** — Review and product-law delta only. **No implementation until this PRD is LOCKED** and the locked compound/expansion PRD is formally revised where this document conflicts.

| Field | Value |
|-------|--------|
| **Status** | **DRAFT** |
| **Scope** | Product gaps between shipped true-DETF behavior and the desired OHM-class economic flywheel |
| **Code reviewed** | `contracts/vaults/detf/**` (Balancer true DETF families + shared core/bondNft; UniV4 Single SE as related draft) |
| **Normative peers (LOCKED today)** | [`DETF_Protocol_Compound_And_Supply_Expansion_PRD.md`](./DETF_Protocol_Compound_And_Supply_Expansion_PRD.md), Threshold Modes, AGENTS.md DETF common expectations |
| **Out of this document** | Code changes, stage plans, UI copy polish (see handoff file after lock) |

---

## 0. Intent

### 0.1 Desired product story (operator goal)

Create an **Olympus V1–class economic flywheel**:

1. **List** the DETF against its underlying reserve (or pair token) at a **market price well above** the abstract Policy peg (`1e18` synthetic narrative).
2. Users **buy DETF** on that market (premium to peg / backing).
3. Users **bond (lock) the DETF token** they bought.
4. While locked, bonders receive a **share of natural supply expansion** — the source of high headline APY when bonded float is small and premium is large.
5. Expansion slowly dilutes free float / closes richness so there is a **long runway** before the unit is “at peg” in the product sense — not an instant collapse of premium after bootstrap.

This is the **buy → bond DETF → earn expansion** loop. It is distinct from (and complementary to) **capital bonding** (vault shares / BPT / buffer → reserve depth + seigniorage).

### 0.2 Why this PRD exists

Code and locked product law already implement:

- Capital-backed mint/bond with seigniorage inventory to the bond reward ledger.
- Policy/Open threshold gates on **synthetic** price.
- Natural expansion (premium-closure) to **bond NFT effective shares**.
- Protocol NFT compound of rewards into reserve BPT.

They do **not** implement the flywheel’s critical middle step: **users cannot bond free DETF**, and **expansion does not accrue to free-DETF holders**. Expansion is a reward on **capital principal positions** (BPT / family principal), not on DETF stake.

Without a DETF-principal bond path, “list high → buy DETF → bond DETF → insane APY” cannot work as stated.

### 0.3 Goals

1. Document **as-shipped operation** (truthful baseline).
2. Map **exact gaps** vs the desired flywheel.
3. Lock (when accepted) a **product-law revision** for:
   - Free-DETF bond / stake surface.
   - How expansion is shared between capital bonders and DETF bonders.
   - Relationship between **market listing premium** and **synthetic** (expansion gate + runway).
   - Deploy-time parameters for high-premium launch and expansion intensity.
4. Keep true-DETF chassis (immutable unowned instances, Policy/Open, reserve-backed synthetic, production-first tests).

### 0.4 Non-goals (v1 of this program)

- Olympus V3 RBS / Heart keepers / Kernel.
- Guaranteed APY, guaranteed peg, or “risk-free” yield claims.
- Auto-compound of **user** DETF-bond rewards into the reserve (keep claimable free DETF unless a later PRD revises).
- Replacing capital bonding (vault share / BPT bonds remain first-class).
- DualLiquidity / non–true-DETF packages.
- Post-deploy mutation of expansion rate or threshold mode (still deploy-time only).

---

## 1. As-shipped operation (code truth)

### 1.1 Chassis (true DETF)

```text
detfToken (diamond = ERC-20)
  + reserve pool (Balancer V3: DETF self-leg + external legs — family-specific)
  + bond NFT vault (principal lock + effectiveShares + DETF reward token)
  + optional rebasing claim on protocol-owned principal
  + Policy/Open thresholds + optional natural expansion (Policy only)
```

| Concept | Meaning in code |
|---------|-----------------|
| **Synthetic price** | Fully diluted reserve-backed unit price: rate-scaled claim of owned BPT on pool balances ÷ `totalSupply`. Abstract peg **1e18**. |
| **Market price** | External listing (reserve pool spot / Uni V4 TWAP / secondary). **Not** used by Balancer-family expansion gates today. |
| **Bond principal** | Family principal units on the bond NFT (typically **BPT amount**, or UniV4 listing LP accounting). **Not** free DETF. |
| **Effective shares** | `principal * lockBonusMultiplier` — weight for `rewardPerShares`. |
| **Rewards** | Free DETF: capital seigniorage inventory + natural expansion mint-on-update. |

### 1.2 Capital bond (what `bond` does today)

Users bond **reserve capital**, not free DETF.

| Family | `acceptedBondTokens` (conceptually) | Free DETF as `tokenIn`? |
|--------|--------------------------------------|-------------------------|
| Single SE | SE vault share + allowlisted SE vault tokens | **No** — `_isAllowlistedTokenIn` returns `false` for `address(this)` |
| Multi-vault weighted | Reserve BPT + vault shares | **No** |
| Mixed-buffer multi-vault stable | Buffer + vault shares + reserve BPT | **No** |
| Composed stable common | Family accepted / routed tokens | **No** (not free DETF stake) |
| UniV4 Single SE (draft PRD) | `pairToken` for bond-open | **No** free-DETF stake surface in draft |

**Single SE live bond path (representative):**

1. Pull vault shares (or zap allowlisted rate asset into the SE vault).
2. Quote DETF self-leg for weight-matched reserve join.
3. Mint DETF: pool leg + usage fee + seigniorage split (`userDetf` free, `inventoryDetf` → bond vault reward token, `feeToDetf`).
4. Join reserve (DETF + vault shares) → **BPT**.
5. Create bond NFT with **BPT as principal shares**; lock clamped by fee-oracle bond terms.
6. First successful bond sets **live**.
7. Lazy `_tryCompoundProtocolRewards` (expansion mint-on-update + protocol compound).

**Multi-vault weighted live path:** bond **reserve BPT** (first bond can go live) or post-live **vault-share** join that mints DETF pairing + inventory split.

**Outcome of a capital bond for the user:**

- Locked claim on **BPT principal** (subject to lock / sell-to-protocol / claim paths).
- Optional **free DETF seigniorage** at bond time (`userDetf`).
- Ongoing **reward accrual** proportional to **effectiveShares** (BPT principal × lock bonus).

### 1.3 Primary mint (capital → free DETF, no lock required)

When live + mint-allowed under Policy (or Open):

- User supplies vault share / family mint input.
- Receives **free DETF** after fee/split; inventory slice goes to bond reward vault.
- Free DETF is **liquid** — **does not** by itself earn expansion.

### 1.4 Natural supply expansion (Policy)

**Gates (all required):**

1. Instance **live**
2. `thresholdMode == Policy` (**Open never expands**)
3. `synthetic > mintThreshold` (default mint threshold **1.05e18** after resolve)

**Formula** (`DETFNaturalExpansionLib` — premium-closure):

```text
peg = 1e18
premium = synthetic > peg ? synthetic - peg : 0
dt = min(now - lastExpansionTimestamp, catchUpMaxSeconds)   // default max 1 day
mint = totalSupply * premium * closureRatePerSecond * dt / (1e18 * synthetic)
mint = min(mint, totalSupply * catchUpCapBps / 10_000)      // default 50 bps = 0.50%
if mint <= dust: mint = 0
```

**Defaults:** close **~10% of synthetic premium per year**; catch-up window **1 day**; **0.50% of supply** max per update.

**Distribution:**

- Mint free DETF **into the bond NFT vault** (same sink as seigniorage inventory).
- Existing `rewardPerShares` / **effectiveShares** ledger distributes to bond positions.
- Protocol NFT’s share compounds to **more protocol BPT** (Phase 1).
- Fee-recipient NFT: claimable free DETF (v1).
- **Unlocked free DETF holders: zero expansion** (explicit locked law).

**Trigger:** lazy on DETF touch points that already update rewards / compound, plus public `compoundProtocolRewards()`. No keeper.

### 1.5 Synthetic vs market (critical economics)

| Price | Definition | Drives expansion? | Drives primary mint/burn gates? |
|-------|------------|-------------------|----------------------------------|
| **Synthetic** | Owned reserve backing ÷ total DETF supply | **Yes** | **Yes** (Policy) |
| **Market / listing** | Spot or TWAP on listing pool | **No** (Balancer families) | **No** (Balancer families) |

**Implication:** Listing DETF “much higher than peg” on a market **does not** by itself create expansion or a long expansion runway. Expansion runs only while **synthetic** is above the mint threshold. Market premium can exist while synthetic is deadband or below peg (or the reverse).

To keep synthetic rich for a long time you need **backing / free-float structure**, not only a high secondary price:

- Capital joins that deepen reserve relative to free float.
- Controlled free-float mint (Policy gates + expansion dilution).
- Avoid flooding free DETF without reserve (seigniorage + expansion are the intentional free-float sources).

### 1.6 Protocol compound

- Protocol-owned bond NFT pending DETF → **single-sided DETF join** → BPT credited to protocol NFT principal.
- Best-effort on join failure; public `compoundProtocolRewards()` required.
- Improves claim redemption path when rebasing claim is wired.

### 1.7 What is already “Olympus-like”

| Olympus V1 idea | DETF today |
|-----------------|------------|
| Policy unit with RFV-like backing | Synthetic from reserve BPT claim |
| Bond **reserve assets** for discounted/paired OHM | Capital bond vault shares / BPT → free DETF + BPT principal |
| Stake OHM → rebase | **Missing** as DETF-principal stake; expansion instead pays **capital bonders** |
| Premium → expansion / dilution toward policy | Premium-closure on **synthetic**, not market mark |
| Protocol-owned liquidity | Protocol NFT compound to BPT |

Locked expansion PRD even listed: *“Requiring a new stake DETF surface for Phase 2 (optional follow-on; not required).”* That optional follow-on is **this** program’s main product delta.

---

## 2. Gap analysis vs desired flywheel

### G1 — Cannot bond free DETF (blocker)

**User story fails:** buy DETF → bond DETF → earn expansion.

**Code:** Single SE explicitly excludes `address(this)` from bond allowlist; other families’ `acceptedBondTokens` are capital assets only.

**Severity:** **P0 product gap** for the stated flywheel.

### G2 — Expansion weight is capital principal, not DETF holdings

Even if a user holds free DETF (from market buy or mint seigniorage), they earn **zero** expansion until they open a **capital** bond with BPT/share principal.

**Severity:** **P0** for “DETF holders get expansion APY.”

### G3 — Market listing premium ≠ synthetic runway

Operator wants: list high above peg so expansion has a long time before “reaching peg.”

**Today:** expansion closes **synthetic** premium toward `1e18`. Market premium is external and uncoupled (Balancer families).

**Severity:** **P0** for launch design / runway narrative; may need product choices on whether expansion (or a second lever) tracks market TWAP.

### G4 — Default expansion intensity is modest

At synthetic \(S = 2\times\) peg, default ~10%/yr premium-closure implies order-of-magnitude **~5% of total supply/year** expansion before share dilution among bonders. Catch-up caps further brake idle spikes.

This is **not** automatically “insanely high APY.” High bonder APY historically also needed **small bonded float vs expansion mint** (early OHM). Today all expansion is shared only among capital bond effective shares — if bonded float is large, APY compresses; if tiny, APY can spike but few can participate without capital bonds.

**Severity:** **P1** parameter / product design (deploy-time rates + who is in the share set).

### G5 — Two distinct Olympus actions are collapsed wrong-way

| Desired | Capital bond today | Needed |
|---------|-------------------|--------|
| Provide reserve → get DETF / depth | ✅ | Keep |
| Lock DETF → get expansion | ❌ | Add DETF-principal bond/stake |

### G6 — Free DETF from capital bond is not “staked”

Capital bond mints `userDetf` free to the user. That free DETF leaves the locked position; only **BPT principal** stays locked for rewards. Users who sell free DETF still earn expansion on BPT — correct for capital bonders, confusing for “bond DETF” narrative.

### G7 — Locked law conflicts with flywheel

Compound/expansion PRD **LOCKED** statements that this DRAFT must revise if accepted:

- Free DETF holders get no expansion unless they hold a bond (**capital** bond today).
- Stake DETF surface was optional non-goal for Phase 2.
- Expansion distribution = seigniorage effective-share scheme only (capital principal).

---

## 3. Product decisions (proposed — resolve before LOCK)

### 3.1 DETF-principal bond (required for flywheel)

**Proposal: add a first-class `bond` route for free DETF.**

| Field | Proposed law |
|-------|----------------|
| **Token in** | `detfToken` (`address(this)`) |
| **Principal accounting** | Lock **DETF amount** as bond principal units (family may use a dedicated share unit type or a tagged principal kind on the bond NFT) |
| **Lock terms** | Same fee-oracle bond terms (min lock revert; max clamp + bonus) **or** deploy-time separate DETF-stake terms — **decision D1** |
| **Rewards** | Eligible for **natural expansion** and optionally capital seigniorage inventory — **decision D2** |
| **Unlock** | After maturity: return locked DETF principal (+ claim pending rewards). No automatic reserve join of principal in v1 |
| **Sell-to-protocol** | **Decision D3:** (a) not allowed for DETF-principal bonds; (b) allowed with claim mint against protocol inventory rules; (c) convert principal to capital bond via join path |

**Anti-patterns:**

- Do not treat free DETF pull as vault-share mint without lock (that is primary mint / market buy).
- Do not double-count the same DETF as both free float earning expansion and unlocked liquid (locked DETF must be removed from “liquid free float” narrative; supply still counts in `totalSupply` for synthetic).

**Synthetic note:** Locked DETF still exists in `totalSupply`. Synthetic is unchanged by merely locking vs holding free DETF (same supply, same reserve). Expansion still dilutes all holders via supply growth; **distribution** of new mint is what changes.

### 3.2 Expansion distribution (who gets the mint)

**Decision D2 options:**

| Option | Description | Flywheel fit | Capital-bonder impact |
|--------|-------------|--------------|----------------------|
| **A — DETF-stake only for expansion** | Natural expansion only to DETF-principal bonds; capital bonds keep seigniorage inventory only | Strongest “buy DETF bond DETF” APY | Capital bonders lose expansion; may under-bond capital |
| **B — Shared ledger, dual principal** | One `rewardPerShares`; capital BPT and DETF-principal both contribute effective shares (possibly with deploy-time weight) | Balanced | Dilutes expansion across both cohorts |
| **C — Dual ledgers** | Separate expansion index for DETF stakes vs seigniorage for capital | Clean UX | More complexity; two claim surfaces |

**Recommendation for draft LOCK target: Option B with deploy-time `detfStakeShareWeight` (default 1e18 = 1:1 vs capital effective share units after a documented conversion).** Conversion rule must be explicit (e.g. 1 DETF locked = 1 effective share unit, while BPT shares remain BPT wei — **dangerous unit mix**). Prefer:

- **Normalize both principals to a common “reward weight” unit** at position creation (e.g. both denominated in DETF-notional or both in rateAsset-notional via synthetic), stored as `effectiveShares`.

**Must not:** invent silent unit confusion (BPT wei vs DETF wei on one ledger).

### 3.3 Market premium vs synthetic (runway)

**Decision D4 — expansion gate input:**

| Option | Gate / formula uses | Launch “list high” story |
|--------|---------------------|---------------------------|
| **S0 — Synthetic only (status quo)** | Synthetic vs mintThreshold; premium-closure on synthetic | Listing high does **not** extend expansion; operator must structure **backing** for synthetic richness |
| **S1 — Market TWAP for expansion only** | Expansion accrues when **market mark** > threshold; primary mint still synthetic | Matches “list high → long expansion runway” if mark stays high; can expand while synthetic is not rich (extra dilution risk) |
| **S2 — Dual condition** | Expansion only if **both** synthetic and market > thresholds | Safer; harder to sustain; needs listing oracle on all families |
| **S3 — Synthetic expansion + market-informed mint quote** | Expansion stays synthetic; listing price only affects UniV4-style mint sizing / UX | Partial: runway still synthetic-backed |

**Recommendation:** Start with **S0 + operational launch guide** (how to seed synthetic premium), and only adopt **S1/S2** if Balancer families gain a mandatory listing oracle. UniV4 Single SE already drafts TWAP synthetic for gates — align vocabulary carefully (do not rename market mark to synthetic without formula change).

**Launch runway under S0 (normative ops):**

1. Bootstrap reserve with high owned backing vs free float (first bond / initializeReserve).
2. Keep primary mint Policy-gated so free float cannot unlimited-mint at low synthetic.
3. Optionally set higher deploy-time `mintThreshold` only if product wants a higher “rich” bar (defaults 1.05 / 0.95).
4. Set `expansionClosureRatePerSecond` for desired closure speed (lower rate → longer synthetic runway; higher rate → faster dilution / higher short-term expansion).
5. Understand market premium is a **secondary** narrative unless S1/S2 is locked.

### 3.4 “Insanely high APY” parameters

APY for a DETF-principal bonder is approximately:

```text
APY ≈ (expansionMintRate * fractionOfMintToThisCohort * userWeight / cohortWeight)
      / userPrincipal
```

Levers (deploy-time only):

| Lever | Effect |
|-------|--------|
| Higher synthetic premium | More mint under premium-closure |
| Higher `expansionClosureRatePerSecond` | Faster premium closure / more mint per time |
| Smaller total effective shares of expansion cohort | Higher APY per bonder |
| Catch-up caps | Cap idle jump; dampen “insane” catch-up |

**Proposal:** document **profile presets** (not post-deploy knobs):

| Profile | Closure rate spirit | Catch-up | Intent |
|---------|---------------------|----------|--------|
| **Conservative** | ~10%/yr of premium (current default) | 1d / 50 bps | Slow dilution |
| **Growth** | Higher (e.g. 50–100%/yr of premium) | tighter catch-up | Early flywheel APY |
| **Hyper** | Very high rate + low early bonded float | strict catch-up | Marketing peak APY; short runway |

Product law should **not** claim a target APY; it should claim **mechanics + deploy profiles**.

### 3.5 Capital bond remains first-class

Capital bonding stays the path that:

- Deepens reserve.
- Goes live (family first-bond rules).
- Produces seigniorage inventory.
- Optionally still shares expansion (D2).

DETF-principal bond **must not** replace first-bond bootstrap (cannot go live by locking DETF alone without reserve).

### 3.6 Open mode

Unchanged: **Open never expands.** DETF-principal bonds under Open earn **no** natural expansion (only any capital seigniorage if they somehow share a ledger — prefer no expansion rewards under Open).

---

## 4. Proposed user journeys (after lock)

### 4.1 Flywheel user (target)

```text
1. Market: buy DETF (premium listing vs reserve / pair)
2. Approve DETF → bond(DETF, amount, lockDuration)
3. Hold bond NFT; pending rewards increase while Policy + rich (per D4)
4. claimRewards while locked → free DETF (may re-bond)
5. At maturity: unlock principal DETF + remaining rewards
```

### 4.2 Capital bonder (keep)

```text
1. Acquire vault shares / BPT / buffer (family)
2. bond(capitalToken, amount, lockDuration)
3. Receive optional free DETF seigniorage + BPT principal lock
4. Earn seigniorage inventory rewards (+ expansion if D2 includes capital)
5. Unlock / sell-to-protocol / claim redeem per family
```

### 4.3 Protocol / claim

Unchanged intent: protocol share of rewards compounds to protocol BPT; claim holders benefit via redemption rate when claim is wired.

---

## 5. Interface sketch (non-normative until stage plan)

Minimum surfaces (names illustrative):

| Surface | Purpose |
|---------|---------|
| `bond(DETF, amount, lock, …)` | DETF-principal open |
| `acceptedBondTokens()` | Include `address(this)` when DETF bond enabled |
| `pendingRewards` / `claimRewards` | Unchanged UX; include expansion share |
| `principalKind(tokenId)` or position info | Distinguish capital vs DETF principal for UX |
| Existing expansion getters | Observability |
| `compoundProtocolRewards()` | Unchanged |

Deploy-time `PkgArgs` additions (illustrative):

- `detfBondEnabled` (or always-on for Policy families)
- Expansion share weights / conversion (if D2-B)
- Optional separate lock terms for DETF bonds (D1)
- Expansion profile fields already exist; document presets

---

## 6. Risks and tradeoffs

| Risk | Handling |
|------|----------|
| Expansion pays DETF stakers without new backing → pure dilution | **Intended** when rich; Policy gates; Open off |
| Unit mix BPT wei vs DETF wei on one ledger | **Mandatory** normalization at position creation (D2) |
| Market-gated expansion (S1) while synthetic low | Extra free float without backing; claim rate / synthetic can crash — prefer S0 or S2 |
| Capital bonders exit if expansion moves to DETF-only (A) | Prefer B or clear incentive (seigniorage-only capital path may still be rational) |
| Reentrancy / reward debt on DETF transfer into bond vault | Same production-first + adversarial suites as capital bonds |
| Locked DETF still in totalSupply | Document clearly; synthetic unchanged by lock |
| “Insane APY” marketing | Product-voice ban; show mechanics + risk of dilution |
| Revising LOCKED expansion PRD | Requires explicit lock revision section in that file when this DRAFT locks |

---

## 7. Acceptance criteria (when implemented later)

| # | Criterion |
|---|-----------|
| F1 | User can bond free DETF on Policy true DETFs in scope; `acceptedBondTokens` includes DETF |
| F2 | DETF-principal bond earns natural expansion under live + Policy + rich gate (per D4) while locked |
| F3 | Preview pending == claim after update (exact or documented dust) |
| F4 | Capital bond path still works; first-bond / live rules unchanged in spirit |
| F5 | Open: no expansion to DETF bonds |
| F6 | Unlock returns DETF principal (plus rewards path) without unauthorized reserve theft |
| F7 | Reward weight units are consistent (no BPT/DETF wei mix bug); tests for dual principal if D2-B |
| F8 | Protocol compound still consumes protocol share of expansion |
| F9 | Production-first tests; no SUT mocks; adversarial reentrancy on bond DETF |
| F10 | Docs/UI: free DETF holders must **bond DETF** to earn expansion; market premium ≠ synthetic unless S1/S2 |

---

## 8. Program relationship

| Artifact | Role |
|----------|------|
| This PRD | Flywheel product delta (DRAFT) |
| Compound + expansion PRD | Must be **revised** on LOCK of this PRD for free-DETF bond + distribution + optional market gate |
| Threshold Modes | Unchanged unless D4 requires market oracle in gates |
| Family stage plans | New stages after LOCK (shared lib + per-family DETF-bond wiring) |
| UniV4 Single SE PRD | Align bond-open vocabulary; may be first host for market-mark expansion if S1/S2 |

**Suggested execution after LOCK:**

1. Revise compound/expansion PRD §4 (recipients + optional stake surface).
2. Shared bond principal typing + reward weight normalization.
3. Pathfinder family (recommend Single SE Balancer **or** UniV4 if market gate).
4. Roll to multi-vault / mixed-buffer / composed stable.
5. Deploy profile docs + TestBase coverage.

---

## 9. Open decisions checklist (must resolve before LOCK)

| ID | Decision | Options | Draft lean |
|----|----------|---------|------------|
| **D1** | DETF-bond lock terms | Same oracle terms vs separate deploy-time | Same oracle terms |
| **D2** | Expansion recipients | A DETF-only / B shared normalized / C dual ledger | **B shared normalized** |
| **D3** | DETF-bond sell-to-protocol | Disallow / allow / convert | Disallow in v1 |
| **D4** | Expansion richness input | S0 synthetic / S1 market / S2 both / S3 hybrid | **S0 + launch guide**; revisit S2 when listing oracle is universal |
| **D5** | Families in scope | All true DETFs vs Balancer only first | All true DETFs after pathfinder |
| **D6** | Growth/Hyper expansion presets | Numeric rates | Specify in stage plan after product picks target runway |

---

## 10. Review summary (executive)

### Implemented correctly relative to **current** locked law

- Capital bonding, seigniorage inventory, Policy/Open gates, premium-closure expansion to **capital bond** effective shares, protocol compound, keeper-free mint-on-update.
- Stages 00–09 intent is reflected in shared libs and family wiring patterns reviewed.

### Not implemented relative to **Olympus flywheel goal**

1. **Bond with DETF token** — missing (and explicitly excluded on Single SE).
2. **Expansion to DETF buyers/holders** — only via capital bond positions today.
3. **Long runway from high market listing** — expansion tracks **synthetic**, not market premium.
4. **Automatically extreme bonder APY** — defaults are mild; extreme APY needs small expansion cohort + high premium + higher deploy rates.

### Bottom line

The chassis is a strong **policy unit + capital bond + expansion-to-lockers** system. It is **not** yet a complete **buy DETF → stake/bond DETF → earn rebase-like expansion** flywheel. Closing that gap is a **product-law revision**, not a small bugfix.

---

## 11. Status of this document

| State | Meaning |
|-------|---------|
| **DRAFT v0.1** | Operation review + proposed deltas; open decisions D1–D6 unresolved |
| Next | Product owner resolves D1–D6 → revise this to LOCK → patch compound/expansion PRD → stage plans → code |

**No code changes are authorized by this DRAFT alone.**
