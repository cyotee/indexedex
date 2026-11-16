# DETF X content ideas

Working folder for educational X posts: what a DETF is, how it works, and how to create one.

```text
marketing/content/
  IDEAS.md
  infographics/            HTML boards + export.mjs + out/*.png   ← posting set
  track-b/<piece>/board.png
  references/              unused cinematic lock (not for X)
```

**Posting assets are the labeled boards**, not the cinematic stills. Rebuild with `node marketing/content/infographics/export.mjs`.


**Audience in production:** Track B (broader crypto / Robinhood Chain).  
**Recorded for later:** Track A (crypto-native DeFi) and Track C (people who might deploy).  
**Claims:** [`docs/marketing/DETF_NARRATIVE_SPINE.md`](../../docs/marketing/DETF_NARRATIVE_SPINE.md).  
**Voice:** `.grok/skills/indexedex-product-voice`. Long-form copy templates: [`../X_POSTS.md`](../X_POSTS.md).

X shows about the first 280 characters. Each piece is one hook, one visual, one mechanic. Disclaimers go in the body, not the hook. Do not name deploy packages. Do not call Protocol DETF the whole product. Do not promise APY, a peg, or legal ownership of offchain underlyings.

---

## Production split

| Stage | Tool | Job |
|-------|------|-----|
| **X stills (use these)** | HTML + CSS in `infographics/` | Labeled boards. Exact product copy. |
| Older lab boards | `docs/marketing/x-diagrams/` | Some still teach Policy/Open. Do not post those. |
| Cinematic stills / 6s loops | `references/` and early `track-b` jpgs/mp4 | Unused for this campaign. Keep as scrap. |
| Motion later | Higgsfield, from a board if needed | Slow camera on a still board, or cut to the PNG. Do not redraw labels in a video model. |

Visual lock for boards: dark ground `#07080c`, accent `#4fd44b`, IndexedEx wordmark, grade-8 labels. See [`infographics/README.md`](infographics/README.md).

---

## Track B (in production)

Broader crypto, including Robinhood Chain. More metaphor, less Olympus. Venue lives in post copy, not as fake logos on the image.

Launch types you may show: pair, triangle, weighted basket. Do not list Balancer-hosted families or unfinished Slipstream as this launch set.

| # | Piece | Board | Status |
|---|-------|-------|--------|
| 01 | What a DETF is | `infographics/out/01-what-is-detf.png` | Ready to review |
| 02 | Spreadsheet vs reserve | `infographics/out/02-spreadsheet-vs-reserve.png` | Ready to review |
| 03 | Create your own is the product | `infographics/out/03-create-your-own.png` | Ready to review |
| 04 | Inert until the first bond | `infographics/out/04-inert-until-first-bond.png` | Ready to review |
| 05 | Two doors, one route | `infographics/out/05-two-doors-one-route.png` | Ready to review |
| 06 | Buy, bond, or stake | `infographics/out/06-bond-vs-buy.png` | Ready to review |
| 07 | Create, bond, use | `infographics/out/07-three-steps.png` | Ready to review |
| 08 | What you pick | `infographics/out/08-what-you-pick.png` | Ready to review |

Each PNG is also copied to `track-b/<piece>/board.png`.

### 01 Definition (drafting)

**Hook seed:** ETFs put baskets on TradFi rails. This puts the basket and the mint/burn rules onchain. DETF means Decentralized ETF.

**On-screen:** nothing, or the letters DETF only if a later labeled still is built in code. The generated stills have no type.

**Body must say:** not a registered securities ETF. Onchain reserve exposure is not legal ownership of offchain stocks.

**Assets:** `track-b/01-definition/`

### 02 Spreadsheet vs reserve

**Hook seed:** A list in a spreadsheet is not a market. A DETF prices mint and burn from the reserve pool.

**Do not say:** like SPY, same as VOO, tracked index.

### 03 Create your own is the product

**Hook seed:** The product is that you can stand up your own DETF. Protocol DETF is how you take a share of app fees, same design, amounts not guaranteed.

**Visual:** several finished coins, same family, different baskets. Not one "protocol coin" in the center.

### 04 Inert until the first bond (drafting)

**Hook seed:** A new DETF starts off. The first successful bond turns it on and puts depth in the reserve.

**Body:** first bond takes the instance live. Later bonds still buy discounted DETF that is staked while it vests.

**Assets:** `track-b/04-inert-until-first-bond/`

### 05 Two doors, one route

**Hook seed:** Above the mint line, the purchase can issue DETF. Below the burn line, a redemption can burn DETF. In the middle, the same route swaps through the pool.

**Do not say:** Open mode. Do not say a failed price gate blocks the route. Liquidity and the user's minimum output still apply.

### 06 Bond vs buy

**Hook seed:** Buy liquid DETF when you want tokens you can move now. Bond to buy discounted DETF that stays staked while it vests.

**Body:** claims pay sDETF. Unstake sDETF one-for-one for held DETF. Funded token units are not a promise about market value.

### 07 Create, bond, use (drafting)

1. Create: you pick the rules. It stays off.
2. Bond: buy DETF that is staked while it vests. The first bond turns it on.
3. Use: hold, mint, burn, or trade.

**CTA in the body:** Create a DETF, or open one that is already live.

**Assets:** `track-b/07-three-steps/`

### 08 What you pick

Pair (constant-product buffer), triangle (orbital book), weighted basket. Same DETF coin on each rail. No package names.

---

## Track A (recorded)

Crypto-native DeFi. Sharper mechanics. Provenance line allowed in the **body**: built by the original developer of Olympus; a DETF is not OlympusDAO, not OHM, and not a claim on any DAO treasury. Do not lead the hook with Olympus.

Use after Track B has taught "one token over a basket" and "inert until the first bond."

| Idea | Hook seed | Visual | Why later |
|------|-----------|--------|-----------|
| A1 The diamond is the share | You do not get a wrapper plus a separate fund share. The DETF contract is the ERC-20. | Cutaway of the coin: the metal *is* the share, not a paper claim laid on top | Needs people to already know DETF |
| A2 Pricing engine = the pool | Mint and burn are not a dashboard FX rate. They are priced from the reserve pool. | Pool surface with weights, fees, rate providers as physical objects | Pair with an updated HTML board |
| A3 Immutable after deploy | After deploy, nobody owns the instance. Bad config means a new one. | Finished coin welded shut, no keyhole | Trust post, not intro |
| A4 Price gates | Primary issuance above the mint line, primary redemption below the burn line, swap in the band. | Two thresholds on a price rail, traffic still moving in the middle | Same mechanic as B05, more numbers in the body |
| A5 Funded staking | Stake DETF, receive sDETF, unstake one-for-one in token units. | Coin in a locked well, receipt tag you can hand back | After B06 |
| A6 Linear bond | Purchased principal becomes claimable steadily. Rewards can be claimed while it vests. Both pay sDETF. | Envelope thinning on a clock, not a cliff | After B06; one example amount in the body is enough |
| A7 Preview = execution | Supported vault-share routes aim for the quote you saw. That is a trust bar, not a yield claim. | Two meters matching, labeled in a code-built still | Needs a code diagram, not an image model |
| A8 Not a rebalancer | No discretionary manager. The pool and the gates are the policy. | Empty manager chair next to the pool | Contrast post |
| A9 Protocol-owned depth | Bond payment and a proportional DETF amount add liquidity. LP belongs to the DETF, not to a reserved bond slice. | Pour into a shared basin, no private tap | Easy to get wrong; keep until copy is signed |
| A10 Expansion later | Issuance rewards are immediate. Only automatic expansion uses eight-hour periods from the first bond. | Eight-hour ticks on a single rail | Follow-on. Do not lead with this. |
| A11 Provenance | Olympus made the meme. DETFs make the product. | Same object language as Track B, no OHM imagery | Body disclaimers required. Optional `@OlympusDAO` as distribution, not endorsement. |

Suggested A order once B 01, 04, and 07 have shipped: A1, A2, A4, A5, A6, A3.

---

## Track C (recorded)

People who might deploy a DETF. Create-your-own is post 1, not post 7. Still define DETF in the first line. Still no package names.

| Idea | Hook seed | Visual | Note |
|------|-----------|--------|------|
| C1 You pick the basket | A DETF is one token for a basket you pick. Create one. | Hands setting tokens into a coin die (no recognizable person) | Lead. B01 definition can sit in the body. |
| C2 It stays off | Deploy does not turn it on. The first successful bond does. | Mold on the bench, lights dark | Repeat of B04, told from the creator's chair |
| C3 Three types this launch | Pair, triangle, or weighted basket. | Three rails, one coin | Same as B08, earlier in the sequence |
| C4 Rules stay put | You do not get a pause button or a later threshold setter. | Coin with no keyhole | Honest cost of immutability |
| C5 What you configure | Legs, weights, mint and burn lines, bond terms. | Open tray of parts, then the sealed coin | Keep grade 8. Link `/create` in the body. |
| C6 Creator right | The creator role NFT has no redeemable principal. It can receive sDETF, which can be unstaked. | Named plate on the desk, separate from the coin well | Easy to overclaim. No promised amounts. |
| C7 First bond is public | Anyone can post the first bond. The creator does not have to. | Open vault door, first pour from an unmarked vessel | Matters for inert instances |
| C8 Flawed config | Wrong args: abandon the instance and deploy again. | Two coins, one dark and unused, one live | Do not imply an admin patch |
| C9 After it is live | Holders mint, burn, bond, stake. You do not rebalance for them. | Crowd of coins around the pool, empty manager chair | Close the "then what" loop |
| C10 Walkthrough carousel | Create → Bond → Use as a how-to, not a brand film. | Same three-station desk as B07 | Reuse B07 assets; rewrite the hook |

Suggested C order: C1, C2, C3, C5, C4, C7, C6.

---

## Higgsfield handoff (not started)

After a Track B still is approved:

1. Use that file as the image reference. Do not re-prompt the scene from text only.
2. Keep the same object (coin, vault basin, desk). Change camera and duration, not the metaphor.
3. Prefer 15–30s, 3–5 shots, over a single 60s explainer.
4. Burned-in labels still belong in HTML/CSS, not in the video model.
5. Venue names stay in the X caption. Do not ask Higgsfield to paint Robinhood or Balancer marks.

---

## Do not ship yet

- Policy/Open as a deployment choice (superseded).
- Pendle market or SY as live.
- Measured APY, TVL, or seigniorage performance.
- Balancer-hosted DETF families or Slipstream as this launch set.
- Fake partner logos, fake UI screenshots, fake dollar amounts on screen.
