# Marketing — IndexedEx / DETF

Public go-to-market materials for **DETFs** (Decentralized ETF product pattern).

| Path | Purpose |
|------|---------|
| [`../docs/marketing/DETF_NARRATIVE_SPINE.md`](../docs/marketing/DETF_NARRATIVE_SPINE.md) | Canonical product claims (modes, disclaimers) |
| [`X_POSTS.md`](./X_POSTS.md) | X Premium long-form posts |
| [`X_ACCOUNTS_TO_TAG.md`](./X_ACCOUNTS_TO_TAG.md) | Who to @, tiers, anti-patterns |
| [`research-site/`](./research-site/) | Static public teaser (not deployed via GitHub Pages) |
| In-app Research + landing | `frontend/app/content/research/`, `frontend/app/page.tsx` |

## Public story (static teaser / social)

**Tone:** simple, pithy, a bit meme — DETFs are a **real product**, the evolution of Olympus-class design from the **original developer of Olympus**. Not a fork. Not OHM cosplay.

**Core line:** Olympus made the meme. DETFs make the product.

**Launch set only (customer pages):**

| Markets (Uniswap V4 hooks) | DETFs |
|----------------------------|--------|
| Pair · constant-product buffer | Pair DETF |
| Triangle · orbital book | Triangle DETF |
| Weighted multi-asset book | Weighted basket DETF |

## Narrative spine (claims law)

Full text: [`docs/marketing/DETF_NARRATIVE_SPINE.md`](../docs/marketing/DETF_NARRATIVE_SPINE.md). Summary:

1. **Premier product:** create your own DETFs (many units, clear bond / mint / burn).
2. **Protocol DETF:** share of protocol fees — same design class, amounts not guaranteed.
3. **Modes:** **Policy** (price-gated) or **Open** (no price restrictions on mint/burn).
4. **Provenance:** original developer of Olympus; not OlympusDAO / not OHM.
5. **Honesty:** not a registered ETF; no legal ownership of offchain underlyings; no fake APY.

## Comms decision

`docs/ROBINHOOD_LAUNCH_PLAN.md` may recommend brand-silent venue naming. Materials here default to **venue-forward** (Robinhood Chain first) unless you switch Track B in `X_POSTS.md`.

## Suggested first week

1. Host or link `research-site/` where you actually publish (not GitHub Pages).
2. Pin post: Olympus lineage → DETF product; link how-detfs-work.
3. Markets post: three Uniswap V4 rails only.
4. Roadmap post (RH → Base/ETH → later).
