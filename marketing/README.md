# Marketing — IndexedEx / DETF

Public go-to-market materials for the **DETF** (decentralized ETF product pattern) and research launch.

| Path | Purpose |
|------|---------|
| [`../docs/marketing/DETF_NARRATIVE_SPINE.md`](../docs/marketing/DETF_NARRATIVE_SPINE.md) | **Canonical product story** (Policy/Open, landing outline, disclaimers) |
| [`X_POSTS.md`](./X_POSTS.md) | X Premium long-form posts (hook ≤~280 chars; @ packs in expanded body) |
| [`X_ACCOUNTS_TO_TAG.md`](./X_ACCOUNTS_TO_TAG.md) | Who to @, tiers, anti-patterns |
| [`research-site/`](./research-site/) | Static GitHub Pages landing for DETF education + Uniswap V4 market rails |
| In-app Research + landing | `frontend/app/content/research/`, `frontend/app/page.tsx` (R1–R3 shipped) |

## Narrative spine (public)

**Full text:** [`docs/marketing/DETF_NARRATIVE_SPINE.md`](../docs/marketing/DETF_NARRATIVE_SPINE.md). Summary:

1. **Premier product:** create your own DETFs from many package types (reserve-backed shares, bond / mint / burn).  
2. **Protocol DETF:** how you earn a share of protocol fees — same DETF design, not premier and not a “separate product.”  
3. **Modes:** **Policy** (price-gated mint/burn) or **Open** (no price restrictions on mint/burn). Never infer Open from zero thresholds.  
4. **Category:** “Decentralized ETF” for accessibility + Olympus-class design depth when asked.  
5. **Chains:** Robinhood Chain first → Base + Ethereum next → other EVMs later.  
6. **Provenance:** built by the original developer of Olympus; not OlympusDAO / not OHM.  
7. **Honesty:** not a registered ETF; not legal ownership of offchain underlyings; no fake APY.

## Comms decision

`docs/ROBINHOOD_LAUNCH_PLAN.md` currently recommends **avoiding venue brand names** in public copy unless an exception is logged. Materials here default to **venue-forward** because that matches the explicit launch ask. Use Track B in `X_POSTS.md` (and strip venue names from the research site) if you keep the brand-silent rule.

## Suggested first week

1. Deploy `research-site/` to Vercel; pin the URL.  
2. Post Track A pin + long DETF explainer (or Track B if brand-silent) — Premium long posts, sharp hooks.  
3. One research drop mid-week from `research/MARKETING_AND_PERFORMANCE_FINDINGS.md`.  
4. Roadmap post (RH → Base/ETH → later).
