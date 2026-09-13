---
name: indexedex-product-voice
description: "Write or edit IndexedEx/DETF customer-facing UI, education and marketing copy using the project voice rules."
---

# IndexedEx product voice

**Read first:** `docs/marketing/DETF_NARRATIVE_SPINE.md` and, if present, `.agents/product-marketing.md`.

This skill **overrides** generic marketing skills on **product hierarchy, names, price routes, funded staking, honesty, and banned jargon**. Use `copywriting` / `copy-editing` for structure and clarity, then run this checklist before shipping copy.

---

## Product hierarchy (mandatory)

| Role | Say | Do not say |
|------|-----|------------|
| **Premier product** | Create / deploy **your own DETFs** from many **DETF types** (package families) | Protocol DETF as the only / premier / hero product |
| **Protocol DETF** | How you **earn a share of protocol fees** (not guaranteed yield); same DETF design | Fee-accrual DETF (as brand); “premier product”; “separate product” |
| **DETF** | Decentralized ETF **product pattern** / any instance | Registered ETF, SEC fund, “like SPY” |
| **Earn** | Strategy vaults / legs under DETFs | Confusing Earn catalog with Protocol DETF |

**Homes:** Explore live DETFs → `/explore` (Protocol DETF opens `/staking?detf=`). Create types → `/create`. Positions → `/you`. Education → `/learn` (chapters stay at `/research/[slug]`). Vault catalog → `/earn` (not a top-level product).

**$RICH (landing fee story):** $RICH is the named token for app fees. Customer copy: **all protocol / app fees go to buying back $RICH**, including the **pons family** launch for $RICH. Point people to **buy $RICH** as the long-term way to take part when the product is used. Do not promise profit, APY, or a higher price from buybacks. Keep create-your-own DETFs as the premier product; $RICH is the fee-buyback path, not a second DETF brand.

**Creator rights:** The creator's role NFT has no redeemable principal. It receives a portion of funded rewards as **sDETF**. Those receipts are freely transferable and can be unstaked for an equal amount of DETF. The standing right can receive more sDETF after earlier receipts have all been redeemed. The fee recipient follows the same pattern. Purchased user bonds instead have funded principal that vests linearly, plus staking rewards claimable during vesting. Do not call the creator's sDETF unredeemable or promise reward amounts.

**Never** put deploy package or family type names in customer UI titles:

- ~~Single Vault DETF~~, ~~SingleStandardExchangeDETF~~, ~~MultiVaultWeightedDetf~~, ~~MixedBuffer…~~
- Package names may appear only in **engineer docs / code / NatSpec**, not landing cards or nav.

---

## Price routes and staking (mandatory)

The owner-approved `DETF_ALIGNMENT_PRD.md` D32–D55 / §24 supersedes the older Policy/Open and LP-backed claim story.

- All new DETFs have mandatory primary price gates. Failed price conditions select the reserve swap on the same supported route; do not call it blocked solely for price. Liquidity and minimum output still apply.
- Do not offer Open mode or infer it from zero thresholds.
- Stake DETF for an equal number of sDETF; unstake sDETF for held DETF one-for-one in token units. Funded rewards may increase sDETF balances; this is not a promise about market value.
- A bond buys discounted DETF, funded and staked at purchase. Principal vests linearly and rewards are claimable while vesting. Both pay sDETF. Remove mature-only NFT-sale and LP-claim instructions.
- Issuance rewards are immediate. Only automatic expansion uses eight-hour periods from the first bond, with completed idle periods settled in one update.
- This is the target design for the refactor. Verify deployed capabilities before presenting them as live, including any Pendle market.

---

## Reading level (mandatory)

Target **grade 8**. Short sentences. One idea each. Everyday words first.

| Hard word | Prefer |
|-----------|--------|
| protocol (as category) | IndexedEx / this product / other apps |
| reserve / managed reserve | the assets behind the token |
| market liquidity | a market people can trade |
| unredeemable | you cannot cash it out |
| claim on a share | you own a piece of |
| seigniorage / synthetic / residual | do not use |
| composition / immutable | shape / stays put |

Keep product names: DETF, bond, mint, burn, stake, unstake, sDETF, vault share, Protocol DETF. Define DETF on first use. Define bond, mint, and burn with a plain verb the first time they appear on a page.

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
| Tokenomics experiment (as hype) | explain the quoted route and funded staking plainly |
| Fee-accrual DETF | **Protocol DETF** |
| Deploy package as display name | Protocol DETF + symbol, or “DETF” + type description in plain words |

Also avoid: Learn More, Get Started, Submit (use **Open {symbol}**, **Bond**, **Read how it works**, **Browse vaults**).

---

## Surface rules

| Surface | Style |
|---------|--------|
| Landing `/` | Define DETF first; CTAs to **Create**, **Explore**, **Learn**; Protocol DETF is one fees card ($RICH not in the first-screen row). Not the full education walk. |
| `/staking` | Title **Protocol DETF**; frame as share of protocol fees; actions named by verb |
| Earn | Catalog for strategies; cross-promo says **Protocol DETF**, not package |
| Research | Mechanics + not-claiming; hierarchy clear; cite spine; no fake performance |
| X / external | Same product law; disclaimers in body not hook |

---

## Workflow with other skills

1. Load spine + this skill.  
2. Optional: `copywriting` for structure (then **strip** banned words).  
3. Optional: `copy-editing` pass.  
4. Final gate: hierarchy (create DETFs > Protocol DETF fee share), product names, primary/swap and staking accuracy, banned list, no invented APY.

---

## Quick self-check

- [ ] DETF expanded early (**Decentralized ETF** / D is decentralized)  
- [ ] Premier story is **create your own DETFs** (many types), not Protocol DETF alone  
- [ ] Protocol DETF is **protocol fees path** — not “separate product”  
- [ ] No deploy-package strings in UI titles  
- [ ] Price gate selects primary issuance/redemption or a pool swap; no Open option
- [ ] sDETF receipts are funded and unstakable; bond principal vests linearly  
- [ ] No hero / workspace / surface marketing chrome  
- [ ] Disclaimers present where claims could be misread  
- [ ] CTAs name the real next action  

---

## Canonical paths

- Spine: `docs/marketing/DETF_NARRATIVE_SPINE.md`  
- Research article: `frontend/apps/indexedex/app/content/research/articles/detf.ts`
- Landing: `frontend/apps/indexedex/app/page.tsx`
- Shared marketing context (if present): `.agents/product-marketing.md`  
