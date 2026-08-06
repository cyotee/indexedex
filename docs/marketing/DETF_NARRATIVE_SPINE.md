# DETF narrative spine

**Canonical public product story** for landing, in-app Research, external research teaser, and social copy.

| Field | Value |
|-------|--------|
| **Status** | Active — use as source of truth for product education |
| **Created** | 2026-07-27 |
| **Owner surfaces** | `/` (R3 landing), `/research`, `marketing/research-site/`, `marketing/X_POSTS.md` |
| **Product law (modes)** | `contracts/vaults/detf/DETF_Threshold_Modes_PRD.md` (**PRODUCT LAW LOCKED**) |
| **Engineering tracker** | `contracts/vaults/detf/DETF_Threshold_Modes_PROGRESS.md` |
| **Frontend roadmap** | `frontend/ROADMAP.md` → **R3** landing DETF hero + research strip |
| **Research design** | `frontend/RESEARCH_SECTION_DESIGN.md` |

**Rule:** Do not invent a second public story. Adapt tone by surface; keep claims, disclaimers, and mode language aligned with this file.

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
| Deploy-time **Policy** (price-gated) or **Open** (no price restrictions on mint/burn) | Implying Open still price-gates; “0 thresholds = open” |

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

Mint/burn and synthetic valuation are driven by the **Balancer V3 reserve** (balances, weights, fees, rate providers) — not an off-pool “dashboard ledger” that can disagree with the pool.

### 3.3 Bonding builds protocol-owned depth

Instances deploy **inert**. The first successful bond takes them **live** and deepens **protocol-owned** reserve. Users can participate in bond terms from onchain configuration rather than relying on a human market-maker promise.

### 3.4 Explicit monetary policy (or unrestricted Open)

- **Policy (default):** seigniorage expands when the synthetic price is **above** the mint threshold and contracts when **below** the burn threshold (defaults commonly ±5% around an abstract 1e18 peg). Inside the band, primary mint/burn stays quiet; secondary markets / the reserve AMM remain the path.  
- **Open (deploy-time option):** **no price restrictions** on primary mint or burn — users can mint and burn regardless of synthetic price. Fees and seigniorage splits still apply. Do **not** describe Open as “gates always pass” or as still checking thresholds.

### 3.5 Immutable, unowned instances

After deploy, true DETF instances are **immutable and unowned** for normal operation: no instance owner, no discretionary diamondCut, no admin pause surface as the product model. Flawed config → abandon the instance and ship a new package/args.

### 3.6 Closed-form honesty where routes allow

Supported vault-share ↔ DETF routes aim for **preview = execution** (exact where closed-form; document few-wei only if a multi-leg path forces it). That is a trust bar, not a yield claim.

### 3.7 Composable with Standard Exchange vaults

Production DETFs talk to **Standard Exchange** surfaces and Balancer — protocol-opaque legs (Uniswap, Aerodrome, Camelot, Aave Stata, nested DETFs, etc.) without baking venue brands into the DETF product definition.

---

## 4. How a DETF works (user-facing)

### 4.1 Lifecycle

```text
Deploy (inert)  →  First bond (live + protocol reserve)  →  Hold / mint / burn / bond / claim (family-wired)
```

| State | User seigniorage mint/burn |
|-------|----------------------------|
| **Inert** | Blocked (any mode) |
| **Live + Policy** | Allowed only outside the synthetic deadband (strict inequalities) |
| **Live + Open** | Always allowed — **no** synthetic price restrictions |

### 4.2 Core shape (true DETF)

1. **Share token** — the diamond proxy **is** the ERC-20.  
2. **Reserve** — Balancer V3 pool (typically weighted) including the DETF self-leg and external legs.  
3. **Bonding** — first bond establishes liveness and protocol-owned depth; further bonds deepen / lock terms per oracle.  
4. **Primary market** — mint/burn against configured vault shares (exact-in closed form preferred).  
5. **Threshold mode** — deploy-time `Policy` or `Open` (never inferred from zero thresholds).  
6. **Claim path (when wired)** — sell bond NFT → protocol; rebasing claim on protocol-owned reserve BPT; redeem burns claim and unwinds toward configured rate asset(s).

### 4.3 Typical user routes

| Route | Guidance |
|-------|----------|
| Vault share → DETF | Preferred live mint surface |
| DETF → vault share | Preferred live burn surface |
| Rate asset as direct mint `tokenIn` | Out of scope unless a family zap is documented — usually deposit to SE first |
| vaultShareᵢ ↔ vaultShareⱼ on DETF | Out of scope — use Balancer / Standard Exchange Router on the reserve |
| Non-closed-form exact-out solvers | Should not be marketed as product features |

### 4.4 What users see as “value”

Be honest about **where value can come from** without inventing APY:

- Exposure to the **composition of the reserve** (legs + weights + rates).  
- Participation in **bonding** into protocol-owned liquidity.  
- **Fee / seigniorage** mechanics when the family and fee oracle apply them (amounts are not guarantees).  
- Secondary trading of the DETF share when markets exist.  

**Do not** claim: automatic yield, rebase return, locked APY, or “always above peg.”

---

## 5. Threshold modes (copy law)

Normative product: `DETF_Threshold_Modes_PRD.md` §16. Marketing summary only.

### 5.1 Modes

| Mode | Public name | Meaning |
|------|-------------|---------|
| `Policy` (0) | **Policy** / gated seigniorage | Default. Deadband gates on synthetic price. |
| `Open` (1) | **Open** | No price restrictions on primary mint/burn |

### 5.2 Defaults and validation

- Zero mint/burn args resolve to **`1.05e18` / `0.95e18`** (stored config; Policy uses them as gates).  
- **`0` never means Open.** Open is only `thresholdMode = Open`.  
- After resolve, both modes require **mint threshold > burn threshold** as config validity — **not** an Open price gate.  
- **Policy** gates use synthetic price. **Open** does **not** gate mint/burn on price at all.

### 5.3 Language patterns

**Good:**

- “Default instances use Policy mode: mint only when the synthetic price is rich, burn only when cheap.”  
- “Open mode: no price restrictions — mint and burn freely on the primary market.”  
- “Policy price-gates seigniorage; Open does not.”

**Bad:**

- “Open thresholds” for extreme Policy (`mint=1`, `burn=max`) — that is still **Policy**, dual-path test language only.  
- Implying Open still checks mint/burn thresholds or “gates always pass” (sounds like a check).  
- “Peg maintained by thresholds” as a guarantee.

### 5.4 When to mention Open in public

| Condition | Copy stance |
|-----------|-------------|
| Modes not yet on listed live product | “Deploy-time Policy or Open option in the DETF packages” (forward-looking, not “this instance is Open”) |
| Featured fee DETF is Policy | Lead with Policy; footnote Open as package option |
| Featured fee DETF is Open | Label the instance Open; do not describe it as deadband-gated |

Engineering gate: prefer P1 (Single Standard Exchange DETF) green before asserting Open on in-app featured products.

---

## 6. Landing page outline (R3)

Target route: `frontend/app/page.tsx`. Structure from `frontend/RESEARCH_SECTION_DESIGN.md` §4.

```text
Hero — create DETFs (premier)
  → Benefits (pillars §3)
  → How it works (§4.1–4.2, short)
  → Modes Policy / Open
  → Protocol DETF (protocol fees path → /staking)
  → Research strip (2–3 published notes)
  → Earn (strategy vaults / legs)
  → Disclaimers (§8)
```

### 6.1 Suggested hero copy (editable)

**Eyebrow:** DETF = Decentralized ETF · many types  

**H1:** Build your own onchain DETF.  

**Lede:** **DETF** means **Decentralized ETF** — the D is decentralized. One onchain share over a real multi-asset reserve. Premier product: stand up **your own DETFs** from a wide family of package types — bond, mint, and burn rules priced from the pool. Want a share of protocol fees? Open **Protocol DETF**.

**Primary CTA:** How DETFs work → `/research/detf`  
**Secondary CTA:** Open Protocol DETF → `/staking`  
**Tertiary:** Browse strategy vaults → `/earn`

### 6.2 Benefits block (short labels)

| Label | One line |
|-------|----------|
| Basket share | One ERC-20 surface over configured reserve legs |
| Pool-priced | Synthetic valuation from the reserve AMM, not a private ledger |
| Bond to live | First bond deepens protocol-owned reserve and opens the product |
| Policy or Open | Default price-gated seigniorage — or Open with no price restrictions |
| Immutable | No instance owner or admin rebalance after deploy |

### 6.3 How it works (three steps)

1. **Bond** — take the instance live; protocol-owned depth.  
2. **Mint / burn** — vault shares ↔ DETF when mode and liveness allow; fees may apply.  
3. **Hold or claim** — secondary markets; bond/claim paths where the package wires them.

### 6.4 Research strip

Pull from published `frontend/app/content/research` articles (title + summary + link). Prefer:

1. DETFs: one share over a real onchain reserve (`/research/detf`)  
2. DETF types (`/research/detf-types`)  
3. Bond vs mint (`/research/bond-vs-mint`)  
4. Rate providers / mark integrity (`/research/rate-providers`)  

Do **not** feature preview-equals-execution as a landing research panel (engineering bar, not a customer value prop).

### 6.5 What to demote on landing

- Generic “Composed indexed liquidity / deposit once” as the **only** hero (keep as sub-brand if needed, not above DETF).  
- DualLiquidity as hero.  
- Invented TVL / APY / USD when price source is off.  
- Fee DETFs listed inside the Earn grid (Wave 2 rule stays).

---

## 7. Research section outline

### 7.1 Flagship note: `/research/detf`

Source module: `frontend/app/content/research/articles/detf.ts`.

**Required claim set (target):**

1. The DETF diamond is the share ERC-20.  
2. Reserve pricing lives in a Balancer V3 pool, not an off-pool ledger.  
3. Instances deploy inert; first successful bond takes them live.  
4. **Default Policy** gates mint/burn on synthetic thresholds; **Open** has **no price restrictions** on mint/burn.  
5. After deploy, instances are immutable and unowned for normal operation.

**Required not-claiming set:**

- Not a registered securities ETF.  
- Not legal ownership of offchain underlyings.  
- Thresholds / modes are not a guarantee of peg or yield.  
- No promised APY, rebase return, or “(3,3)” performance.  
- Open removes price gates only; fees still apply.

**Sections to keep / add:**

| Section | Purpose |
|---------|---------|
| ETF-shaped intent, onchain mechanics | Accessibility |
| Core shape | Share, reserve, bond, gates, immutability |
| Policy vs Open | Deploy-time modes (§5) |
| How users interact | Routes honesty |
| Olympus-class design, productized | Provenance without affiliation |
| Why research matters | Links to companion notes |

### 7.2 Optional follow-on note

Slug candidate: `threshold-modes` — “Policy vs Open mint/burn.”  
Publish after (or when) family wiring is ready to demo; link from landing and staking chrome.

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
Mint/burn thresholds and Policy/Open modes do not guarantee peg stability, liquidity, or returns.
There is no promised APY, rebase yield, or “(3,3)” performance.
Smart-contract and market risk apply. Read docs and research; this is not financial advice.
```

---

## 9. Surface adaptation guide

| Surface | Tone | Lead with | Modes |
|---------|------|-----------|--------|
| Landing `/` | Conversion + clarity | Why desirable + CTA to `/staking` | Policy default; Open as option |
| `/research/detf` | Educational | How it works + not-claiming | Full Policy/Open section |
| `/staking` | Product UI | Actions (bond, mint, burn, claim) | Show instance mode when available |
| `marketing/research-site/` | Public teaser | Premier product + roadmap | Sync to §5 |
| `marketing/X_POSTS.md` | Premium long-form | Hook without legal; modes in body | One clear bullet in explainer posts |
| Earn `/earn` | Catalog | Strategy vaults; DETF banner out to staking | Do not re-teach full DETF |

### 9.1 Provenance line (approved)

> Built by the original developer of Olympus. The DETF productizes a familiar design class — reserve-backed seigniorage, bonding into protocol-owned depth, optional mint/burn policy — so many baskets can each be their own monetary unit. A DETF is not OlympusDAO, not the OHM token, and not a claim on any DAO treasury.

**Public site campaign tone (GitHub Pages / social, when approved):** lean **new product, not a fork** — “Olympus made the meme; DETFs make the product.” Keep the not-OHM / not-DAO disclaimers in body or footer. Prefer pithy, slightly meme energy on `marketing/research-site/`; keep in-app Research more lab-neutral unless product asks otherwise.

**Launch map (customer pages, 2026 ship):** only Uniswap V4 **pair** (ConstProd buffer), **triangle** (orbital), and **weighted** market rails + matching DETFs. Do not list dual-vault pairs, four-asset stable books, or Balancer-family DETFs as this launch set on public marketing pages.

### 9.2 Chain / venue language

Comms may be **venue-forward** (e.g. Robinhood Chain first → Base + Ethereum) or **brand-silent**. See `marketing/README.md` and `docs/ROBINHOOD_LAUNCH_PLAN.md`. Pick one track per campaign week; do not mix venue tags into brand-silent posts.

---

## 10. Copy bank (short)

### 10.1 Elevator (≈25 words)

A DETF is one onchain share over a multi-asset reserve: bond to go live, mint and burn against pool-priced rules, immutable after deploy.

### 10.2 Elevator with modes (≈40 words)

A DETF is a reserve-backed share over a real reserve. Default Policy mode price-gates mint and burn; Open mode never does. Not a registered ETF.

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
| What is Open mode? | Deploy-time choice: primary mint and burn have **no price restrictions**. Policy is the mode that gates on synthetic price. |
| Is Open riskier? | Different policy. No deadband dampening of primary seigniorage; still fees and market risk. Not “safer” or “risk-free.” |
| Who can change thresholds later? | Normal product model: no post-deploy threshold/mode setter; flawed config → new instance. |

---

## 11. Implementation checklist (content + UI)

Use when preparing landing + research for ship.

### Content

- [x] This spine accepted as SoT  
- [x] Update `frontend/app/content/research/articles/detf.ts` claims/sections for Policy vs Open  
- [ ] Optional `threshold-modes` research article  
- [x] Sync `marketing/research-site/index.html` mint/burn language to §5  
- [x] Sync `marketing/X_POSTS.md` explainer bullets to §5  
- [ ] Point CTAs at real URLs (app + research-site when deployed)

### UI (R3)

- [x] Landing hero DETF-first per §6  
- [x] Benefits + how-it-works blocks  
- [x] Keep Protocol DETF featured → `/staking`  
- [x] Research strip from published registry  
- [x] Disclaimers §8  
- [x] Public product name is **Protocol DETF** (not deploy package names); e2e matches `Protocol DETF` + staking links  
- [x] No invented APY/USD; no DualLiquidity hero  

### Product chrome (post Threshold Modes)

- [ ] Display `thresholdMode` + resolved thresholds on DETF info surfaces  
- [ ] Open instances not described as deadband-gated in UI strings  
- [ ] Inert copy remains true for both modes  

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
| `frontend/app/content/research/articles/detf.ts` | In-app DETF note |
| `research/MARKETING_AND_PERFORMANCE_FINDINGS.md` | Measured claims roll-up |
| `contracts/vaults/detf/DETF_Threshold_Modes_PRD.md` | Normative mode law |
| monorepo `AGENTS.md` | DETF role names + family expectations |

---

## 13. Changelog

| Date | Note |
|------|------|
| 2026-08-06 | Public GitHub Pages rewrite: Olympus→DETF product tone; launch map locked to Uni V4 pair / triangle / weighted only. |
| 2026-07-27 | Initial spine: positioning, desirability, lifecycle, Policy/Open copy law, R3 landing outline, research update targets, disclaimers, copy bank. |
| 2026-07-27 | Shipped in-app: `frontend/app/content/research/articles/detf.ts` Policy/Open update; R3 landing rewrite on `frontend/app/page.tsx`. |
| 2026-07-27 | Marked R2/R3 shipped in `frontend/ROADMAP.md` + `RESEARCH_SECTION_DESIGN.md`. Synced `marketing/research-site/`, `marketing/X_POSTS.md`, `marketing/README.md` to Policy/Open. |
| 2026-07-27 | Clarified **Open = no price restrictions** on mint/burn (not “gates always pass”). Updated landing experiment, `detf.ts`, spine §3.4 / §5. |
