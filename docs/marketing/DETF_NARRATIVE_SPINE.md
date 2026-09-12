# DETF narrative spine

**Canonical public product story** for landing, in-app Research, external research teaser, and social copy.

| Field | Value |
|-------|--------|
| **Status** | Active — use as source of truth for product education |
| **Created** | 2026-07-27 |
| **Owner surfaces** | `/` (compact landing), `/research`, `marketing/research-site/`, `marketing/X_POSTS.md` |
| **Product law** | `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md` D32–D55 / §24: funded staking, linear bonds, mandatory primary gates with swap fallback |
| **Engineering tracker** | `contracts/vaults/detf/DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md` |
| **Frontend roadmap** | `frontend/ROADMAP.md` → landing compact choice page (post-R3) |
| **Research design** | `frontend/RESEARCH_SECTION_DESIGN.md` |

**Rule:** Do not invent a second public story. Adapt tone by surface; keep claims, disclaimers, and route language aligned with this file.

**Refactor scope:** This release implements the approved funded design for Uniswap V4 DETFs. D60 excludes further functional changes to Balancer-hosted DETFs; descriptions of those families below are broader product context, not release-completion claims. D66 defers unfinished Slipstream support; V4 and unrelated SE work continue. Do not claim an existing deployed instance has changed or a Pendle market is live without deployment evidence. D32–D55 supersede the older Policy/Open and LP-claim story; historical changelog entries below describe earlier versions.

---

## 1. One-line positioning

**DETF** (Decentralized ETF product pattern): an onchain share over a real multi-asset reserve, with bonding into protocol-owned depth and mint/burn rules priced from the pool — not a fund administrator and not a black-box rebalancer.

**Category language (use carefully):**

| Say | Do not say |
|-----|------------|
| Decentralized ETF **product pattern** | Registered ETF, SEC-approved fund, “same as SPY/VOO” |
| Economic exposure via **onchain reserve assets** | Legal ownership of offchain stocks / underlyings |
| Built by the **original developer of Olympus** | “This is OlympusDAO” / “official OHM” |
| OHM-class **design family**, productized | Guaranteed rebase, “(3,3)” performance, risk-free |
| Price gates choose primary issuance/redemption or a reserve swap | Open as a deployment option; a failed price gate makes the route unavailable |

---

## 2. Product hierarchy (locked)

| Role | What it is | App home |
|------|------------|----------|
| **Premier product** | **Create your own DETFs** from IndexedEx’s family of DETF types (single SE, multi-vault weighted, mixed-buffer stable, composed, …). Deployable packages → reserve-backed shares with bond / mint / burn rules. | Education: `/research/detf`; discovery often via Earn / future deploy UX — **not** “Protocol DETF = the whole product” |
| **Protocol DETF** | A live DETF path to **earn a share of protocol fees** (amounts not guaranteed). Same DETF design class — not a second product category. | `/staking` (featured fee list; **not** the Earn grid) |
| **Category** | **DETF** = decentralized ETF **product pattern** (any family instance). | — |
| **Earn** | Standard Exchange strategy vaults and composed liquidity (legs / rails under DETFs). | `/earn` |
| **Evidence rails** | DualLiquidity / nested vaults as mark-integrity and composition proof — never as the landing hero name. | — |

**Anti-pattern:** Calling Protocol DETF the “premier product” or “hero product,” or framing it as a **separate product** with different product rules. Protocol DETF is the **protocol fees path**; the platform’s flagship offer is **many DETF types you can stand up yourself**.

---

## 3. Why a DETF is desirable

Use these benefit pillars on landing and long-form. Order is intentional for conversion.

### 3.1 One share over a basket

Users get **ETF-shaped intent** without a discretionary portfolio manager: one ERC-20 surface over configured reserve legs (vault shares and related onchain assets).

### 3.2 Pricing engine = the reserve pool

Mint/burn and synthetic valuation are driven by the **reserve pool** (supported Balancer V3 pools or Uniswap V4 buffer hooks, with their balances, weights, fees and rate providers) — not an off-pool “dashboard ledger” that can disagree with the pool.

### 3.3 Bonding builds protocol-owned depth

Instances deploy **inert**. The first successful bond takes them **live** and deepens **protocol-owned** reserve. Users can participate in bond terms from onchain configuration rather than relying on a human market-maker promise.

### 3.4 One monetary policy with pool trading

Every new DETF uses price gates. Above the mint threshold, a supported purchase can issue DETF; below the burn threshold, a supported redemption can burn DETF against the protocol's reserve. Otherwise the same route trades through the reserve pool. A price gate alone does not block the user's route. Available liquidity, fees and the user's minimum output still matter.

### 3.4.1 Funded staking and vesting

Stake DETF to receive an equal amount of sDETF. Each sDETF can be unstaked for one DETF held in the staking reserve. Funded rewards can increase the sDETF balance; a change in the pool price cannot reduce those token units. This does not promise a higher market value.

A bond buys discounted DETF that is funded and staked immediately. Purchased principal becomes claimable steadily over the selected period, and staking rewards can be claimed during that period. Both pay sDETF, which the recipient can keep staked or unstake for DETF.

### 3.5 Immutable, unowned instances

After deploy, true DETF instances are **immutable and unowned** for normal operation: no instance owner, no discretionary diamondCut, no admin pause surface as the product model. Flawed config → abandon the instance and ship a new package/args.

### 3.6 Closed-form honesty where routes allow

Supported vault-share ↔ DETF routes aim for **preview = execution** (exact where closed-form; document few-wei only if a multi-leg path forces it). That is a trust bar, not a yield claim.

### 3.7 Composable with Standard Exchange vaults

Production DETFs talk to **Standard Exchange** surfaces and the configured reserve host — protocol-opaque legs (Uniswap, Aerodrome, Camelot, Aave Stata, nested DETFs, etc.) without baking venue brands into the DETF product definition.

---

## 4. How a DETF works (user-facing)

### 4.1 Lifecycle

```text
Deploy (inert)  →  First bond (live + protocol reserve)  →  Hold / mint / burn / bond / claim (family-wired)
```

| State | Supported purchase/redemption routes |
|-------|---------------------------------------|
| **Inert** | Wait for the first bond to establish the reserve |
| **Live, primary price condition met** | Issue or redeem DETF using the existing pool-priced formula |
| **Live, primary price condition not met** | Swap through the reserve pool, subject to liquidity and the user's minimum output |

### 4.2 Core shape (true DETF)

1. **DETF** — the diamond is the nine-decimal ERC-20.
2. **Reserve** — includes DETF and the configured external assets. LP acquired by DETF operations belongs to the DETF as a whole; bond owners do not own a reserved LP slice.
3. **Bond** — actual payment and a separate proportional DETF amount add liquidity. The discounted DETF purchase is additionally minted, staked and vested linearly.
4. **sDETF** — nine-decimal staking receipts backed by held DETF, redeemable one-for-one in token units.
5. **Rewards** — issuance rewards are funded immediately. Only automatic expansion uses fixed eight-hour periods from the first bond; idle periods settle together in one update.
6. **Creator and fee recipients** — standing rights produce new, freely unstakable sDETF when rewards are allocated, even after earlier receipts have all been unstaked. The role NFT itself has no redeemable principal.
7. **SY** — separate static wrappers for raw DETF and staked DETF expose the Pendle interface. Wrapping raw DETF does not stake it. Interface support does not establish a live yield market.

### 4.3 Typical user routes

| Route | Guidance |
|-------|----------|
| Supported payment → DETF | The standard route chooses primary issuance or a pool swap |
| DETF → supported output | The standard route chooses primary redemption or a pool swap |
| Rate asset as direct mint `tokenIn` | Out of scope unless a family zap is documented — usually deposit to SE first |
| vaultShareᵢ ↔ vaultShareⱼ on DETF | Out of scope — use Balancer / Standard Exchange Router on the reserve |
| DETF ↔ sDETF | Stake or unstake one-for-one in token units |
| Bond NFT claims | Claim vested principal and/or staking rewards as sDETF |
| Non-closed-form exact-out solvers | Should not be marketed as product features |

### 4.4 What users see as “value”

Be honest about **where value can come from** without inventing APY:

- Exposure to the **composition of the reserve** (legs + weights + rates).  
- Participation in **bonding** into protocol-owned liquidity.  
- **Fee / seigniorage** mechanics when the family and fee oracle apply them (amounts are not guarantees).  
- Secondary trading of the DETF share when markets exist.  

**Do not** promise automatic profit, a fixed rebase return, locked APY or “always above peg.” Distinguish funded token-unit growth from market-price performance.

---

## 5. Price gates and staking (copy law)

Normative product: `DETF_ALIGNMENT_PRD.md` D32–D55 / §24. This is a marketing summary.

- All new DETFs use price gating. There is no Open deployment choice.
- Default zero threshold arguments resolve to 1.05 and 0.95 in the contract's normalized price unit. The mint threshold must exceed the burn threshold.
- Primary mint uses a strict above-threshold condition and primary burn a strict below-threshold condition. Equality and the middle band use reserve swaps.
- Say “This purchase uses the pool” when the route selects a swap; do not label it blocked solely for price.
- Explain staking as “Deposit DETF, receive sDETF, unstake for an equal number of DETF.” Do not describe it as a claim on LP or a guarantee of dollar value.
- Explain bonding as “Buy discounted DETF that is staked while it vests. Claim vested principal and staking rewards as sDETF.” Do not instruct users to sell a mature NFT for a new claim token.
- Creator and fee rights have no redeemable principal, but the sDETF they receive can be unstaked. Never describe these receipts as permanently locked.
- Do not advertise a Pendle market or newly upgraded live instance based on an implementation plan alone.

---

## 6. Landing page outline

Target route: `frontend/apps/dtf/app/page.tsx`.

`/` is a **choice page**, not the full education walk. Price-route and staking details, creator rights, vault legs, and research summaries live on `/create`, `/learn`, and `/research/[slug]`.

```text
First screen — define DETF + one outcome + diagram
  CTAs: Create → /create, Use a live DETF → /explore, How DETFs work → /learn
  → Three steps (Create → Bond → Use)
  → Protocol DETF (one $RICH / fees card → /staking)
  → Learn (one line + Full walk → /learn)
  → Disclaimers (§8, folded)
```

Do **not** restore on `/`: Why DETFs card grid, Policy/Open band, Earn vaults banner, three-note research strip, closing recap strip, or **Buy $RICH** in the first-screen button row.

### 6.1 First-screen copy

**Eyebrow:** DETF means Decentralized ETF  

**H1:** Hold a strategy as one token.  

**Lede:** A DETF is one token for a basket you pick. The basket works in other apps. Create your own, or open one that is already live.

**Primary CTA:** Create DETF → `/create`  
**Secondary CTA:** Use a live DETF → `/explore`  
**Tertiary:** How DETFs work → `/learn`

**Buy $RICH** sits on the Protocol DETF card below, not next to Create.

### 6.2 How it works (three steps)

1. **Create** — Make a DETF. You pick the rules. It stays off until the first bond.  
2. **Bond** — Buy DETF that is staked while it vests. The first bond turns the DETF on.  
3. **Use** — Hold the token. Mint more, burn to exit, or trade it.

Price gates and staking are Create + Learn lessons, not a landing widget. One line (“You pick the rules”) is enough on `/`.

### 6.3 Protocol DETF (fees path)

One heading **Protocol DETF** and one `/staking?detf=` link (Wave 2 e2e). $RICH copy: app fees buy back $RICH, including the pons family launch. No second grid of Protocol DETF cards (Explore lists live DETFs). Do not add legal hedges or “not a promised return” lines in landing body copy.

### 6.4 Learn strip

One line: five short chapters. Link **Full walk →** `/learn`. Do not stack published-note summaries on `/`.

### 6.5 What to demote on landing

- Generic “Composed indexed liquidity / deposit once” as the **only** first-screen claim (keep as sub-brand if needed, not above DETF).  
- DualLiquidity as the first-screen product.  
- Invented TVL / APY / USD when price source is off.  
- Fee DETFs listed inside the Earn grid (Wave 2 rule stays).  
- Policy/Open experiment, Why DETFs five-card grid, Earn banner, research catalog, $RICH in the first paragraph.

---

## 7. Research section outline

### 7.1 Flagship note: `/research/detf`

Source module: `frontend/apps/dtf/app/content/research/articles/detf.ts`.

**Required claim set (target):**

1. The DETF diamond is the share ERC-20.  
2. Reserve pricing lives in the configured Balancer pool or Uniswap V4 buffer hook.  
3. Instances deploy inert; first successful bond takes them live.  
4. Mandatory price gates choose primary issuance/redemption or a reserve swap. Staking pays held DETF one-for-one; funded bond principal vests linearly.  
5. After deploy, instances are immutable and unowned for normal operation.

**Required not-claiming set:**

- Not a registered securities ETF.  
- Not legal ownership of offchain underlyings.  
- Thresholds do not guarantee a peg or returns.  
- No promised APY, rebase return, or “(3,3)” performance.  
- A rising sDETF token balance does not guarantee rising market value.

**Sections to keep / add:**

| Section | Purpose |
|---------|---------|
| ETF-shaped intent, onchain mechanics | Accessibility |
| Core shape | Share, reserve, bond, gates, immutability |
| Price routes and staking | Primary/swap selection, funded sDETF and linear bonds (§5) |
| How users interact | Routes honesty |
| Olympus-class design, productized | Provenance without affiliation |
| Why research matters | Links to companion notes |

### 7.2 Follow-on education

Explain pool trading, direct staking and a bond's linear principal/reward claims with concrete token amounts. Link to actual supported routes. Keep pending implementation details separate from claims about listed live products.

### 7.3 Evidence honesty

`research/MARKETING_AND_PERFORMANCE_FINDINGS.md` still lists full synthetic DETF mint/burn/bond/claim research as **not started**. Until that campaign ships:

- Research notes may teach **mechanics and design**.  
- Do **not** claim measured DETF seigniorage performance or live mainnet APY.  
- Supporting plots may come from SE / rate-provider / DualLiquidity research as **infrastructure honesty**, clearly labeled.

---

## 8. Disclaimers (paste block)

Use near CTAs, research footers, and social body (not in X hooks).

```text
A DETF is a decentralized ETF product pattern onchain — not a registered securities ETF or fund share.
Holding DETF or reserve assets is not legal ownership of offchain stocks or other underlyings.
Mint/burn thresholds do not guarantee peg stability, liquidity, or returns.
There is no promised APY, rebase yield, or “(3,3)” performance.
Smart-contract and market risk apply. Read docs and research; this is not financial advice.
```

---

## 9. Surface adaptation guide

| Surface | Tone | Lead with | Mechanics |
|---------|------|-----------|--------|
| Landing `/` | Conversion + clarity | One outcome + Create / Explore / Learn; $RICH on fees card | Price gates and staking on Create + Learn |
| `/research/detf` | Educational | How it works + not-claiming | Primary/swap routes and funded staking |
| `/staking` | Product UI | Actions (bond, mint, burn, claim) | Show the actual quoted route and claim amounts |
| `marketing/research-site/` | Public teaser | Premier product + roadmap | Sync to §5 |
| `marketing/X_POSTS.md` | Premium long-form | Hook without legal; mechanics in body | One clear bullet in explainer posts |
| Earn `/earn` | Catalog | Strategy vaults; DETF banner out to staking | Do not re-teach full DETF |

### 9.1 Provenance line (approved)

> Built by the original developer of Olympus. The DETF productizes a familiar design class — reserve-backed seigniorage, bonding into protocol-owned depth, pool-priced mint/burn rules — so many baskets can each be their own monetary unit. A DETF is not OlympusDAO, not the OHM token, and not a claim on any DAO treasury.

**Public site campaign tone (static teaser / social, when approved):** lean **new product, not a fork** — “Olympus made the meme; DETFs make the product.” Keep the not-OHM / not-DAO disclaimers in body or footer. Prefer pithy, slightly meme energy on `marketing/research-site/`; keep in-app Research more lab-neutral unless product asks otherwise.

**Launch map (customer pages, 2026 ship):** only Uniswap V4 **pair** (ConstProd buffer), **triangle** (orbital), and **weighted** market rails + matching DETFs. Do not list dual-vault pairs, four-asset stable books, or Balancer-family DETFs as this launch set on public marketing pages.

### 9.2 Chain / venue language

Comms may be **venue-forward** (e.g. Robinhood Chain first → Base + Ethereum) or **brand-silent**. See `marketing/README.md` and `docs/ROBINHOOD_LAUNCH_PLAN.md`. Pick one track per campaign week; do not mix venue tags into brand-silent posts.

---

## 10. Copy bank (short)

### 10.1 Elevator (≈25 words)

A DETF is one onchain share over a multi-asset reserve: bond to go live, mint and burn against pool-priced rules, immutable after deploy.

### 10.2 Elevator with staking (≈40 words)

Hold DETF for reserve exposure, stake it for funded sDETF, or buy a discounted bond that stays staked while it vests. Price gates choose primary issuance/redemption or a pool swap.

### 10.3 Contrast lines

- Spreadsheet index vs **onchain reserve + share**.  
- Discretionary rebalancer vs **pool-priced policy**.  
- Single-pair farm vs **basket reserve infrastructure**.  
- Admin mint vs **unowned instance after deploy**.

### 10.4 FAQ seeds

| Question | Answer seed |
|----------|-------------|
| Is this an ETF? | Product pattern: onchain reserve-backed share with bond/mint/burn rules. Not a registered securities ETF. |
| Where does the price come from? | The reserve pool (and rate providers on legs), expressed as a synthetic / fully diluted backing metric for gates. |
| Why can’t I mint right after deploy? | Instances start inert until the first successful bond. |
| What happens inside the price band? | The supported purchase/redemption route swaps through the reserve pool. |
| Can I unstake bond rewards before maturity? | Yes. Claimable rewards pay sDETF, which can be unstaked for DETF; unvested purchased principal remains in the bond. |
| Who can change thresholds later? | Normal product model: no post-deploy threshold setter; flawed config → new instance. |

---

## 11. Implementation checklist (content + UI)

Use when preparing landing + research for ship.

### Content

- [x] Reconcile this spine with the approved funded staking design.
- [ ] Reconcile active research, external teaser and social copy with §5.
- [ ] Point CTAs at verified deployed products; distinguish older instances from the new design.

### UI (R3 shipped; compact `/` 2026-08-21)

- [x] Landing first screen DETF-first per §6 (Create / Explore / Learn)  
- [x] Three steps only (no Why DETFs grid, no Policy/Open band)  
- [x] Keep Protocol DETF featured → `/staking` (one card; $RICH not in first-screen CTAs)  
- [x] Learn strip → `/learn` (no three-note research catalog on `/`)  
- [x] Disclaimers §8 (folded; no closing recap strip)  
- [x] Public product name is **Protocol DETF** (not deploy package names); e2e matches `Protocol DETF` + staking links  
- [x] No invented APY/USD; no DualLiquidity first-screen product  

### Product chrome (funded refactor)

- [ ] Confirm threshold displays and the actual quoted primary/swap route.
- [ ] Confirm direct stake/unstake and principal/reward claim amounts against deployed contracts.
- [ ] Confirm first-bond liveness and nine-decimal token displays.

### Evidence (later)

- [ ] DETF synthetic mint/burn/bond research campaign when prioritized  
- [ ] R4 curated plots under `frontend/public/research/` only from claim-safe figures  

---

## 12. Related paths

| Path | Role |
|------|------|
| `docs/marketing/DETF_NARRATIVE_SPINE.md` | **This file** |
| `marketing/README.md` | Marketing folder index + weekly cadence |
| `marketing/X_POSTS.md` | Social long-form |
| `marketing/research-site/` | Static public teaser |
| `frontend/RESEARCH_SECTION_DESIGN.md` | R1–R5 research + landing IA |
| `frontend/ROADMAP.md` | Next UI phase (R3) |
| `frontend/apps/dtf/app/content/research/articles/detf.ts` | In-app DETF note |
| `research/MARKETING_AND_PERFORMANCE_FINDINGS.md` | Measured claims roll-up |
| `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md` | Normative funded staking law (D32–D55 / §24) |
| monorepo `AGENTS.md` | DETF role names + family expectations |

---

## 13. Changelog

| Date | Note |
|------|------|
| 2026-09-07 | Reconciled target product story with funded sDETF, linear bonds, immediate rewards, fixed epochs and mandatory gate-to-swap routes. Historical entries below describe superseded versions. |
| 2026-08-21 | Landing `/` compact choice page: drop Why grid, Policy/Open band, Earn banner, research catalog, closing strip; $RICH off first-screen CTAs. Spine §6 rewritten. |
| 2026-08-06 | Public GitHub Pages rewrite: Olympus→DETF product tone; launch map locked to Uni V4 pair / triangle / weighted only. |
| 2026-07-27 | Initial spine: positioning, desirability, lifecycle, Policy/Open copy law, R3 landing outline, research update targets, disclaimers, copy bank. |
| 2026-07-27 | Shipped in-app: `frontend/apps/dtf/app/content/research/articles/detf.ts` Policy/Open update; R3 landing rewrite on `frontend/app/page.tsx`. |
| 2026-07-27 | Marked R2/R3 shipped in `frontend/ROADMAP.md` + `RESEARCH_SECTION_DESIGN.md`. Synced `marketing/research-site/`, `marketing/X_POSTS.md`, `marketing/README.md` to Policy/Open. |
| 2026-07-27 | Clarified **Open = no price restrictions** on mint/burn (not “gates always pass”). Updated landing experiment, `detf.ts`, spine §3.4 / §5. |
