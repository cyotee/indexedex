---
name: indexedex-product-voice
description: >
  Project voice law for IndexedEx / DETF customer-facing copy (UI, research notes,
  marketing site, X posts). Use when writing or editing landing pages, product UI
  strings, Protocol DETF copy, research education, disclaimers, CTAs, or when
  copywriting/copy-editing skills would otherwise inject marketing jargon.
  Triggers: product voice, UI copy, landing copy, Protocol DETF wording, ban jargon,
  plain language DeFi, customer-facing text, rewrite marketing speak, DETF narrative.
---

# IndexedEx product voice

**Read first:** `docs/marketing/DETF_NARRATIVE_SPINE.md` and, if present, `.agents/product-marketing.md`.

This skill **overrides** generic marketing skills on **product hierarchy, names, threshold modes, honesty, and banned jargon**. Use `copywriting` / `copy-editing` for structure and clarity, then run this checklist before shipping copy.

---

## Product hierarchy (mandatory)

| Role | Say | Do not say |
|------|-----|------------|
| **Premier product** | Create / deploy **your own DETFs** from many **DETF types** (package families) | Protocol DETF as the only / premier / hero product |
| **Protocol DETF** | How you **earn a share of protocol fees** (not guaranteed yield); same DETF design | Fee-accrual DETF (as brand); “premier product”; “separate product” |
| **DETF** | Decentralized ETF **product pattern** / any instance | Registered ETF, SEC fund, “like SPY” |
| **Earn** | Strategy vaults / legs under DETFs | Confusing Earn catalog with Protocol DETF |

**Homes:** Protocol DETF → `/staking` (not Earn grid). Education → `/research/detf`. Strategy legs → `/earn`.

**Never** put deploy package or family type names in customer UI titles:

- ~~Single Vault DETF~~, ~~SingleStandardExchangeDETF~~, ~~MultiVaultWeightedDetf~~, ~~MixedBuffer…~~
- Package names may appear only in **engineer docs / code / NatSpec**, not landing cards or nav.

---

## Threshold modes (mandatory)

| Mode | Customer meaning |
|------|------------------|
| **Policy** (default) | Primary mint/burn **restricted by synthetic price** (deadband; defaults often ±5%). |
| **Open** | **No price restrictions** on primary mint/burn — users can mint and burn regardless of synthetic price. |

**Do not write:**

- “Open gates always pass” / “Open collapses the deadband after live” (sounds like price still decides)
- “0 thresholds = Open”
- Extreme Policy (`mint=1`) as “open thresholds”

**May still say:** fees can apply; modes do not guarantee peg or returns.

---

## Voice

1. **Expand DETF first:** before (or with) “create DETFs,” say **DETF = Decentralized ETF** and that the **D is decentralized** (not a registered securities ETF). Eyebrow or first lede sentence is ideal.
2. **Plain verbs:** bond, mint, burn, hold, redeem, deposit, open, deploy, create.
3. **Specific over vague:** name the action and the asset (Open CHIR, Bond to go live, create a DETF).
4. **Honest:** no APY, no “(3,3)” returns, no peg guarantees, no legal ownership of offchain underlyings.
5. **Technical when needed:** synthetic price, reserve pool, inert → live — define once in plain words.
6. **Tone:** serious lab / product, not agency hype. Olympus lineage only if the user asks — never as hero claim.
7. **Protocol DETF framing:** “earn a share of protocol fees” / “protocol fees path” — same DETF design. **Not** “separate product,” “staking-style path,” “staking analogue,” or other internal taxonomy.

---

## Banned jargon (customer-facing)

Do **not** use these as labels users see (internal CSS class names are fine):

| Ban | Prefer |
|-----|--------|
| Hero / hero product / premier product (for Protocol DETF) | Protocol DETF = fee share / staking; premier = create your own DETFs |
| Workspace (as product name) | Protocol DETF, product page, `/staking` |
| Seigniorage surface | mint and burn against the reserve |
| Lab log / experiment · ready | omit, or “how mint and burn work” |
| Unlock / seamless / supercharge / empower | concrete outcome |
| Streamline / optimize / innovative / cutting-edge | delete or be specific |
| Tokenomics experiment (as hype) | explain Policy vs Open plainly |
| Fee-accrual DETF | **Protocol DETF** |
| Deploy package as display name | Protocol DETF + symbol, or “DETF” + type description in plain words |

Also avoid: Learn More, Get Started, Submit (use **Open {symbol}**, **Bond**, **Read how it works**, **Browse vaults**).

---

## Surface rules

| Surface | Style |
|---------|--------|
| Landing `/` | Define DETF (Decentralized ETF / D) first; then **create-your-own** / many types; Protocol DETF as fees path; CTAs to research + `/staking` + Earn; no package names on cards |
| `/staking` | Title **Protocol DETF**; frame as share of protocol fees; actions named by verb |
| Earn | Catalog for strategies; cross-promo says **Protocol DETF**, not package |
| Research | Mechanics + not-claiming; hierarchy clear; cite spine; no fake performance |
| X / external | Same product law; disclaimers in body not hook |

---

## Workflow with other skills

1. Load spine + this skill.  
2. Optional: `copywriting` for structure (then **strip** banned words).  
3. Optional: `copy-editing` pass.  
4. Final gate: hierarchy (create DETFs > Protocol DETF fee share), product names, Open/Policy truth, banned list, no invented APY.

---

## Quick self-check

- [ ] DETF expanded early (**Decentralized ETF** / D is decentralized)  
- [ ] Premier story is **create your own DETFs** (many types), not Protocol DETF alone  
- [ ] Protocol DETF is **protocol fees path** — not “separate product”  
- [ ] No deploy-package strings in UI titles  
- [ ] Open = no price restrictions (not “soft gate”)  
- [ ] No hero / workspace / surface marketing chrome  
- [ ] Disclaimers present where claims could be misread  
- [ ] CTAs name the real next action  

---

## Canonical paths

- Spine: `docs/marketing/DETF_NARRATIVE_SPINE.md`  
- Research article: `frontend/apps/dtf/app/content/research/articles/detf.ts`  
- Landing: `frontend/apps/dtf/app/page.tsx`  
- Shared marketing context (if present): `.agents/product-marketing.md`  
