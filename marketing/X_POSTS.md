# IndexedEx X posts — DETF launch pack (X Premium long-form)

**Status:** Hold full rewrites until **site copy is settled** (landing + research). One aligned pass later — do not ship divergent X wording first.

**Purpose:** Ready-to-post copy for advertising IndexedEx research and the DETF platform.  
**Premier product:** **create your own DETFs** from many package types.  
**Define early:** DETF = **Decentralized ETF** (the D is decentralized — not a registered securities ETF).  
**Protocol DETF:** how you earn a share of protocol fees — same DETF design, not a “separate product.”  
**Narrative SoT:** [`docs/marketing/DETF_NARRATIVE_SPINE.md`](../docs/marketing/DETF_NARRATIVE_SPINE.md) (hierarchy, Policy vs Open, disclaimers).  
**Chain story:** Robinhood Chain first → Base + Ethereum next → other EVM chains later.

**Format:** X Premium long posts. Each piece is **one post**, not a thread.  
**Before posting:** replace `[RESEARCH_URL]`, explorer links. Delete every `---` fold marker.

**@ packs:** baked into each full post (expanded body only). Account rationale: [`X_ACCOUNTS_TO_TAG.md`](./X_ACCOUNTS_TO_TAG.md).  
Tags are **not partnerships** — distribution only. Max ~2–4 handles per post.

---

## How to write for Premium (locked rule)

X shows roughly the **first ~280 characters** in the feed. Everything after is behind **Show more**.

| Layer | Job |
|-------|-----|
| **Hook (chars 1–~280)** | Stop the scroll. One claim, one curiosity gap, or one contrast. **No @s, no links, no disclaimers** in the hook. |
| **Body (after expand)** | Thesis, mechanics, **@ pack**, roadmap, research URL, disclaimers. |

**Hook craft:**
- Front-load the sharpest line; bury logistics after expand.
- Prefer 1–3 short lines that force “I need the rest.”
- End the hook on tension or an unfinished idea.
- Research URL near the **end** of the full post.

Each post below is paste-ready. **`---`** = approximate expand fold (delete before posting).

---

## Comms guardrails (body only)

| Do say | Do not say |
|--------|------------|
| DETF = decentralized ETF **product pattern** onchain | “Registered ETF,” “SEC-approved,” “same as SPY/VOO” |
| Economic exposure via **onchain reserve assets** | “You own the stock / underlying security via DETF” |
| Built by the **original developer of Olympus** | “This is OlympusDAO” / “official OHM” |
| Bond → protocol-owned reserve; mint/burn from **pool-priced rules** | Guaranteed APY, “(3,3)” returns, risk-free |
| **Policy** price-gates mint/burn; **Open** = no price restrictions | Implying Open still checks thresholds; “0 thresholds = Open” |
| Immutable unowned DETF instances after deploy | Admin can mint / pause / rebalance for you |
| Research + roadmap; product going live in phases | “Live trading now” unless addresses are public |
| Tags = “building with / same problem space as” | Tags = “partnered with / endorsed by” (unless true) |

**Two tracks:**

1. **Track A — Venue-forward** (names Robinhood Chain + venue tags).  
2. **Track B — Brand-silent** (no venue brand names / no RH tags).

Use one track per campaign week.

---

## @ pack cheat sheet

| Post | Default tags (in body) | Optional swap-in |
|------|------------------------|------------------|
| A1 pin | `@RobinhoodCrypto` `@Balancer` | + `@arbitrum` (drop one default if crowded) |
| A2 DETF explainer | `@Balancer` `@RobinhoodCrypto` | + `@vimenprotocol` (basket peer frame) |
| A3 why RH | `@RobinhoodCrypto` `@arbitrum` `@Balancer` | + `@vimenprotocol` or `@TheIndexFi` |
| A4 agents | `@virtuals_io` `@RobinhoodCrypto` `@Balancer` | + `@Safe` if smart-wallet angle |
| A5 Olympus | `@OlympusDAO` `@Balancer` `@RobinhoodCrypto` | drop venue if you want quieter |
| A6 roadmap | `@RobinhoodCrypto` `@base` `@ethereum` | + `@Balancer` |
| A7 rate research | `@Balancer` | + `@andrewtalksdefi` if sharing graphs |
| A8 preview research | `@Balancer` | — |
| A9a contrast | `@Balancer` `@RobinhoodCrypto` | — |
| A9b anti-meme | `@RobinhoodCrypto` `@Balancer` | — |
| A9c one-liner | `@RobinhoodCrypto` `@Balancer` | keep minimal |
| B1–B3 | `@Balancer` only (optional `@OlympusDAO` on provenance) | no RH tags |

**Nuclear (flagship only, not weekly):** add `@vladtenev` to A1 once — never every post.

---

## Track A — Venue-forward (Robinhood-first)

### A1. Pin / announcement

**@ pack:** `@RobinhoodCrypto` · `@Balancer`  
**Hook (~chars before fold):**
> ETFs put baskets on TradFi rails.  
> We’re putting the basket *and* the monetary policy onchain.  
> DETF — the Decentralized ETF.

**Full post (paste; delete the `---` line):**

```
ETFs put baskets on TradFi rails.
We’re putting the basket *and* the monetary policy onchain.

DETF — the Decentralized ETF.
---
That’s the premier product of IndexedEx: modular DeFi vault infrastructure with one flagship primitive.

A DETF is not a fund admin, a rebalance bot, or a dashboard promising index exposure.

It is:
• a share ERC-20 (the diamond *is* the token)
• a real multi-asset reserve on Balancer V3
• bonding that deepens protocol-owned liquidity
• mint & burn: Policy price-gates by default, or deploy-time Open with no price restrictions

First home: Robinhood Chain (@RobinhoodCrypto).
Reserve engine: weighted multi-asset pools on @Balancer.
Near-term: Base + Ethereum.
Later: the rest of EVM via deterministic deploy.

Built by the original developer of Olympus.
A DETF is how you launch your own OHM-class unit for a chosen reserve — productized seigniorage, not a one-off protocol.

We’re publishing research first. Mechanics before hype.

Research: [RESEARCH_URL]

Not a registered securities ETF. Onchain economic exposure ≠ legal ownership of offchain underlyings. Not investment advice. Tags ≠ partnership claims.
```

---

### A2. What is a DETF? (long explainer)

**@ pack:** `@Balancer` · `@RobinhoodCrypto`  
**Optional 3rd (basket peer):** `@vimenprotocol`  
**Hook:**
> What if an “ETF-shaped” product didn’t live at a fund administrator — but as an immutable onchain share with a real multi-asset reserve?

**Full post:**

```
What if an “ETF-shaped” product didn’t live at a fund administrator —
but as an immutable onchain share with a real multi-asset reserve?
---
That’s the DETF: Decentralized ETF. Premier product of IndexedEx.

“ETF-shaped” intent is simple: one share over a basket of legs.
Onchain mechanics are stricter:

1) The diamond is the share ERC-20 — you don’t get a claim wrapper and a separate fund share story.
2) The reserve lives in a @Balancer V3 weighted pool. Pricing engine = the pool, not an off-pool FX ledger.
3) Instances deploy *inert*. The first successful bond takes them *live* and deepens protocol-owned reserve.
4) Mint/burn modes (deploy-time): **Policy** (default) — mint only when synthetic price is above the mint threshold; burn only below the burn threshold (e.g. ±5% deadband). **Open** — no price restrictions on mint or burn; fees still apply. Zero thresholds never mean Open.
5) After deploy: unowned. No instance owner, no diamondCut, no admin pause surface for normal operation. Flawed config → abandon the instance and ship a new package.

What a DETF is not:
• a registered securities ETF
• legal title to offchain stocks or underlyings
• guaranteed rebase yield or “(3,3)” performance
• a black-box treasury multisig narrative standing in for market structure

Why Robinhood Chain first (@RobinhoodCrypto):
It’s a permissionless EVM L2 where multi-asset and market-linked ERC-20s are first-class citizens. A decentralized ETF pattern that holds multi-leg reserves is a natural product surface — especially before every chain has weighted multi-asset AMM infrastructure as table stakes.

Same problem space as other onchain basket / index builders on the chain (shout to peers like @vimenprotocol) — we’re shipping seigniorage + bond + immutable instance policy as the product, not a spreadsheet index.

Olympus DNA, productized:
IndexedEx is built by the original developer of Olympus. OHM proved a *category* (reserve-backed seigniorage with bonding into protocol-owned depth). DETFs turn that class of design into a deployable package so *many* baskets can each be their own monetary unit — “from one OHM to many.”

We’re not “OlympusDAO.” We’re not the OHM token. We’re shipping the next generation of that design family as infrastructure.

Research (how vaults re-mark, when rate providers matter, preview vs execution):
[RESEARCH_URL]

Follow for roadmap, addresses when public, and measured claims only.
```

*If you skip the peer tag, delete the `@vimenprotocol` sentence and keep only `@Balancer` + `@RobinhoodCrypto`.*

---

### A3. Why Robinhood Chain first

**@ pack:** `@RobinhoodCrypto` · `@arbitrum` · `@Balancer`  
**Optional peer:** `@vimenprotocol` *or* `@TheIndexFi`  
**Hook:**
> The interesting DeFi question on Robinhood Chain isn’t “can we swap pairs?”  
> It’s “can a basket be first-class money?”

**Full post:**

```
The interesting DeFi question on Robinhood Chain isn’t “can we swap pairs?”
It’s “can a basket be first-class money?”
---
Spot AMMs are table stakes on any serious EVM. Pair swaps will exist.

What multi-asset markets actually need is infrastructure for *reserves that are baskets* — weighted multi-leg liquidity, vault-native composition, and a share that can mint/burn against that reserve with transparent policy.

That’s the DETF (Decentralized ETF) on IndexedEx:

• multi-leg (or single-leg) onchain reserves
• bond → protocol-owned depth
• mint/burn: Policy price-gates, or Open with no price restrictions
• immutable instances after deploy

Building toward @RobinhoodCrypto’s chain as product home — Orbit-class L2 stack with @arbitrum tech under the hood — because market-linked ERC-20s and crypto rails coexist there. Sector baskets, market×ETH units, and simple single-leg demos all map cleanly onto one pattern: reserve-backed seigniorage shares priced from @Balancer multi-asset reserves.

Onchain baskets are a live narrative on this L2 (index / stock-token builders like @vimenprotocol and @TheIndexFi are in the same neighborhood). Our cut: DETF = basket *currency* with bond + seigniorage policy, not just fee routing on tokenized legs.

Honest constraints (important):
Holding onchain reserve assets is *economic exposure* onchain. It is not legal ownership of offchain securities. Issuer/venue eligibility rules still apply. We do not rewrite jurisdiction with a smart contract.

Roadmap:
1. Robinhood Chain — product + research demos
2. Base + Ethereum — capital markets + deep liquidity rails
3. Later — additional EVMs via deterministic CREATE3-style deploy

Same DETF pattern. Different liquidity neighborhoods.

Research hub: [RESEARCH_URL]
```

*To stay at 3 tags: drop one of `@vimenprotocol` / `@TheIndexFi` (or both) and keep the venue + stack trio.*

---

### A4. Agents (long)

**@ pack:** `@virtuals_io` · `@RobinhoodCrypto` · `@Balancer`  
**Hook:**
> Agents shouldn’t babysit twelve LP positions forever.  
> They should deploy one DETF and hold a single reserve-backed share.

**Full post:**

```
Agents shouldn’t babysit twelve LP positions forever.
They should deploy one DETF and hold a single reserve-backed share.
---
That’s the product thesis for DETFs on IndexedEx.

Rebalancing bots are a tax on attention and gas. Continuous multi-venue inventory management is a full-time job for humans and a failure mode for agents.

A DETF packages the opposite workflow:

• choose reserve legs (via Standard Exchange vaults — protocol-opaque composition)
• bond to establish protocol-owned reserve and go live
• hold the DETF share as the monetary unit of that reserve
• mint/burn under deploy-time Policy (price-gated) or Open (no price restrictions) — no discretionary “manager rebalance”

Agents (and agent wallets) get a clean surface: deploy, bond, hold, exit closed-form routes. Humans get the same surface without becoming a professional LP.

Why this belongs on Robinhood Chain: @RobinhoodCrypto is pushing an AI-native / agent-ready finance surface, and agent ecosystems like @virtuals_io already treat the chain as a live playground. A DETF is something an agent can *hold* — one reserve-backed share over @Balancer multi-asset depth — instead of babysitting twelve LPs.

We’re building modular vault infrastructure so that story is real infrastructure — not a slideshow.

First home: Robinhood Chain. Then Base + Ethereum.

Research: [RESEARCH_URL]
```

---

### A5. Olympus provenance (long, careful)

**@ pack:** `@OlympusDAO` · `@Balancer` · `@RobinhoodCrypto`  
**Hook:**
> OHM proved a category.  
> We’re productizing it so anyone can launch their own.

**Full post:**

```
OHM proved a category.
We’re productizing it so anyone can launch their own.
---
IndexedEx is built by the original developer of Olympus.

What that does *not* mean (read this twice, @OlympusDAO community):
• this is not OlympusDAO
• this is not the OHM token
• this is not a claim on Olympus governance or treasury

What it *does* mean:
The design family that made OHM a category — reserve-backed seigniorage, bonding into protocol-owned depth, policy around mint/burn — is generalized as the DETF: a deployable product over chosen reserves.

Conceptual map (marketing, not 1:1 code cosplay):

• Protocol token as money → DETF share *is* the currency of that reserve  
• Treasury / reserves → @Balancer V3 weighted reserve (transparent pool)  
• Bonding → POL → bond NFT + first bond → live  
• Seigniorage policy → Policy thresholds on synthetic price, or Open with no price gates  
• One global unit → many DETFs — one monetary unit per basket  

Tagline we stand behind: **Launch your own OHM.**

Premier product: DETF (Decentralized ETF pattern onchain).
First product home: Robinhood Chain (@RobinhoodCrypto). Near-term: Base + Ethereum.

Research before markets:
[RESEARCH_URL]

No guaranteed rebase yield. No “(3,3)” performance claims. Open mechanics. Not affiliated with OlympusDAO.
```

---

### A6. Roadmap (long)

**@ pack:** `@RobinhoodCrypto` · `@base` · `@ethereum`  
**Optional 4th:** `@Balancer`  
**Hook:**
> Three horizons. One product.  
> DETF — then the liquidity graph expands.

**Full post:**

```
Three horizons. One product.
DETF — then the liquidity graph expands.
---
IndexedEx ships modular DeFi vault infrastructure. Premier product is the DETF: decentralized ETF pattern — reserve-backed share, bond, mint/burn rules with Policy or Open modes (reserves on @Balancer-class multi-asset pools).

Horizon 1 — Now: Robinhood Chain (@RobinhoodCrypto)
Product home for flagship DETF research demos and first public infrastructure. Multi-asset reserve narrative leads.

Horizon 2 — Immediate: @base + @ethereum
Capital formation, deep liquidity rails, Superchain-adjacent distribution. Same DETF pattern; richer markets.

Horizon 3 — Later: additional EVM chains
Deterministic deploy (Crane / CREATE3-class) so packages and addresses stay coherent as the graph grows.

We are not competing as “another meme ticker.”
We are shipping the stack that lets builders and agents stand up reserve-backed basket currencies with immutable instances and pool-priced policy.

Research hub (findings, not fantasy APYs):
[RESEARCH_URL]
```

---

### A7. Research drop — rate providers

**@ pack:** `@Balancer`  
**Optional:** `@andrewtalksdefi` (if attaching charts / seeking DeFi-research eyes)  
**Hook:**
> Rate providers don’t print yield.  
> They keep nested markets honest.

**Full post:**

```
Rate providers don’t print yield.
They keep nested markets honest.
---
Research note from IndexedEx vault / nested-liquidity work:

When Standard Exchange vault shares sit in nested @Balancer legs, Rate Providers keep mids fair as the underlying market moves.

Rates on  → residual mid lag ≈ 0 under the tested demand paths  
Rates off → residual lag grows with volume  

That’s *mark integrity*, not free money. Residual is not a free arb until edge clears pool fees and path costs. Fee is an arb presentation threshold — below the stack, residuals can exist with zero fills; above, closers can fill.

Why this matters for DETFs:
A decentralized ETF that prices from a multi-asset reserve is only as honest as how nested legs re-mark. We’re publishing that research spine *before* asking anyone to trust a marketing number.

More: [RESEARCH_URL]
```

---

### A8. Research drop — preview = execution

**@ pack:** `@Balancer`  
**Hook:**
> If preview ≠ execution, the UI is lying.  
> Closed-form routes should be boring.

**Full post:**

```
If preview ≠ execution, the UI is lying.
Closed-form routes should be boring.
---
IndexedEx research / product bar for supported closed-form vault and DETF routes (including paths that settle against @Balancer-class reserves):

preview amount == execution amount

Exact where math allows. Documented few-wei only when multi-leg proportional paths force it — never “approximately good enough for marketing.”

That’s the opposite of yield theater. Before live DETF markets, we’re publishing the standard we hold ourselves to: numbers the chain can prove.

Research: [RESEARCH_URL]
```

---

### A9. Short premium posts (still long-form, denser)

**A9a — contrast** · **@ pack:** `@Balancer` · `@RobinhoodCrypto`

```
TradFi: ETF = basket + fund complex + prospectus.
Onchain: DETF = basket + reserve pool + mint/burn rules (Policy or Open).
---
Same *shape* of user intent. Completely different trust model.

DETF (IndexedEx): diamond share, @Balancer V3 reserve, bond → live, Policy/Open modes, immutable after deploy.
First home: Robinhood Chain (@RobinhoodCrypto) → then Base + Ethereum.

[RESEARCH_URL]

Not a registered ETF. Not legal ownership of offchain underlyings.
```

**A9b — anti-meme** · **@ pack:** `@RobinhoodCrypto` · `@Balancer`

```
We’re not shipping another meme ticker.
We’re shipping monetary infrastructure.
---
DETF = Decentralized ETF product pattern: reserve-backed seigniorage as a package.

Bond the reserve. Mint against the pool (@Balancer). No instance owner after deploy.

IndexedEx · @RobinhoodCrypto first → Base → Ethereum
[RESEARCH_URL]
```

**A9c — one sentence thesis** · **@ pack:** `@RobinhoodCrypto` · `@Balancer`

```
A DETF is an onchain share whose treasury is a market — not a spreadsheet.
---
Premier product of IndexedEx.
Robinhood Chain (@RobinhoodCrypto) · reserves on @Balancer · research: [RESEARCH_URL]
```

---

### A10. Launch-week cadence (Premium)

| Day | Post | Tags live in body |
|-----|------|-------------------|
| Mon | **A1** pin | RH + Balancer |
| Tue | **A2** DETF explainer | Balancer + RH (+ optional Vimen) |
| Wed | **A4** agents *or* **A9a** | Virtuals + RH + Balancer / RH + Balancer |
| Thu | **A7** or **A8** research | Balancer only |
| Fri | **A6** roadmap | RH + Base + Ethereum |
| Weekend | **A5** Olympus provenance | OlympusDAO + Balancer + RH |

Optional mid-week: **A3** (RH + Arbitrum + Balancer).

---

## Track B — Brand-silent

No `@RobinhoodCrypto` / `@RobinhoodApp` / `@vladtenev`. Tech + provenance only.

### B1. Pin

**@ pack:** `@Balancer`  
**Optional provenance soft-tag:** none in pin (save `@OlympusDAO` for B2)

```
Launch your own OHM.
That’s a DETF — reserve-backed seigniorage as a deployable product.
---
IndexedEx ships modular vault infrastructure. Premier product: the DETF.

• diamond share ERC-20
• @Balancer V3 multi-asset reserves
• first bond → live
• mint/burn: Policy price-gates by default; Open has no price restrictions
• immutable, unowned instances after deploy

Built by the original developer of Olympus.
Category language, not affiliation: not OlympusDAO, not the OHM token.

Multi-chain by design: major EVMs near-term; expansion L2s where multi-asset reserves are the point.

Research first: [RESEARCH_URL]

No guaranteed rebase. No fake APY. Open mechanics.
```

---

### B2. What is a DETF? (long)

**@ pack:** `@Balancer` · `@OlympusDAO` (disclaimer adjacent)

```
OHM was one seigniorage currency.
DETFs make that design class available to every basket.
---
A DETF (IndexedEx) is:

• a share ERC-20 (the diamond is the token)
• a @Balancer V3 weighted reserve as the pricing engine
• bonding into protocol-owned depth; first bond takes the instance live
• Policy (default): mint when synthetic > mint threshold; burn when synthetic < burn threshold — or Open: no price restrictions on mint/burn
• no instance owner after deploy

A DETF is not:

• guaranteed rebase yield or “(3,3)” performance
• a black-box treasury promise
• legal ownership of offchain underlyings via the token
• admin monetary policy after launch
• “OlympusDAO” or the OHM token (@OlympusDAO — category language only; we are not affiliated)

From one OHM to many: every chosen reserve can be its own monetary unit.

Research: [RESEARCH_URL]
```

---

### B3. Dense premium shorts

**@ pack:** `@Balancer`

```
Bond. Mint. Reserve.
DETF — seigniorage as infrastructure.
---
IndexedEx. Built by Olympus’s original developer. Reserves on @Balancer. Research: [RESEARCH_URL]
```

```
From one OHM to many.
Every basket can be its own monetary unit.
---
That’s the DETF — @Balancer-backed reserve, immutable after deploy. [RESEARCH_URL]
```

---

## Reply bank (keep short — usually no @ spam)

| Someone says… | Reply |
|---------------|--------|
| “Is this an ETF?” | “Product pattern: onchain reserve-backed share with mint/burn rules. Not a registered securities ETF.” |
| “Do I own the stock?” | “You hold onchain assets in a transparent reserve. That is not legal title to offchain securities.” |
| “Is this Olympus?” | “Built by Olympus’s original developer. Not OlympusDAO / not the OHM token. DETF generalizes the *class* of design.” |
| “APY?” | “No invented APY. Live fee-make and depth get measured when routes are public — not promised in ads.” |
| “What’s Open mode?” | “Deploy-time choice: primary mint and burn have no price restrictions. Policy is the mode that gates on synthetic price. Fees still apply.” |
| “When Base/ETH?” | “Immediate multi-chain path after first product home: Base + Ethereum. Other EVMs later via deterministic deploy.” |
| Peer replies from `@vimenprotocol` / index builders | Thank + one-line shared frame: “baskets as first-class onchain objects — we add bond + seigniorage policy.” |

---

## Hook checklist (before you hit Post)

- [ ] First ~280 characters work as a standalone cliffhanger  
- [ ] **No @ handles in the hook**  
- [ ] No URL in the hook  
- [ ] No legal wall of text before expand  
- [ ] 2–4 tags max in body; sentence next to each handle makes sense  
- [ ] Delete any `---` fold markers before posting  
- [ ] Disclaimers + “tags ≠ partners” live in the body when tagging big brands  
- [ ] Verify handles still correct (see `X_ACCOUNTS_TO_TAG.md`)  

---

## Hashtags (optional, light)

0–2 max; often zero is better when you’re already @-tagging.

```
#DeFi #DETF
```

Venue week only (Track A): `#RobinhoodChain`  
Avoid equity ticker laundry lists as the hero story.
