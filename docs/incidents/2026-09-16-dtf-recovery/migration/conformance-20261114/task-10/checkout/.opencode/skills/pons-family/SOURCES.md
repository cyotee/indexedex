# pons skill family — sources

Root: https://docs.ponsfamily.com/  
Inventory date: 2026-07-29  
Product name: **pons** (lowercase)

## Full inventory

| id | url | title | section | status | skill targets |
|----|-----|-------|---------|--------|---------------|
| 1 | https://docs.ponsfamily.com/ | pons docs (v1 user + integration) | / | done | pons-architecture; pons-operations; pons-integration |
| 2 | https://docs.ponsfamily.com/v2 | pons v2 docs (user + integration) | /v2 | done | pons-architecture; pons-operations; pons-integration |
| 3 | https://docs.ponsfamily.com/llms.txt | llms.txt agent summary | /llms.txt | done | pons-architecture; pons-integration |
| 4 | https://docs.ponsfamily.com/sitemap.xml | sitemap | discovery | done | (discovery only) |

## Discovery notes

- Sitemap lists only `/` and `/v2` (plus root).
- `llms.txt` adds public HTTP surfaces under ponsfamily.com API (optional UX; not trust root).
- No separate multi-page sidebar beyond the single-page v1 and v2 documents.

## Content → skill mapping

| Doc region | Primary skill | References |
|------------|---------------|------------|
| v1 overview, how launches work, trading vocab, graduation, fees, protocol revenue | pons-architecture, pons-operations | architecture/v1-contracts, risk-and-governance; operations/* |
| v1 CTO, risk disclosures | pons-architecture, pons-operations | risk-and-governance; creator-and-fees |
| v1 Integration (network, contracts, events, reads, pricing, reference token) | pons-integration | v1-indexing-and-reads |
| v2 overview, lifecycle, curve, graduation, custom pairs, fees, payouts, buyback, creator controls, CTO, safety | pons-architecture, pons-operations | v2-contracts; operations/* |
| v2 Integration (launch, trade, state, events, V4, errors, audits) | pons-integration | v2-onchain-api |
| llms.txt builder addresses + API URLs | pons-integration, pons-architecture | v1-contracts |

## External links retained (not scraped as doc pages)

- https://forms.gle/JjrWvybFeNfE5v8F6 — CTO form
- https://ponsfamily.com/launchpad — app
- https://ponsfamily.com/api/pons-launches|pons-token|pons-market — optional APIs
- mailto:contact@ponsfamily.com — support
