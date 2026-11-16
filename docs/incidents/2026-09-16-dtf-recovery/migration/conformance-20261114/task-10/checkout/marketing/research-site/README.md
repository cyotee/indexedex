# IndexedEx public DETF site

Static public landing for the **DETF product story** — Olympus lineage productized, not a fork cosplay.

## Hosting

**GitHub Pages is dropped** for this repo (no deploy workflow). This folder is a static site you can host elsewhere or open locally.

| Field | Value |
|-------|--------|
| **Source dir** | this folder (`marketing/research-site/`) |
| **Entry** | `index.html` |
| **Other pages** | `how-detfs-work.html`, `uniswap-v4.html`, `technical-note.html`, optional PDF |

Local preview: open `index.html` in a browser, or serve the directory with any static file server.

## Voice

- **Simple, pithy, a bit meme** — DETFs are a real product; not technical cosplay.
- **Olympus lineage:** built by the original developer of Olympus; the upgrade, not a fork.
- **Still honest:** not OlympusDAO, not OHM, not a registered ETF, no invented APY.
- Product voice law: `.grok/skills/indexedex-product-voice/` + `docs/marketing/DETF_NARRATIVE_SPINE.md`.

## Launch map (only these)

| Product language | Role |
|------------------|------|
| **Pair** (constant-product buffer) | Market rail + matching DETF |
| **Triangle** (orbital) | Market rail + matching DETF |
| **Weighted basket** | Market rail + matching DETF |

Do **not** advertise dual-vault pairs, four-asset stable books, or Balancer family DETFs as this launch set on customer pages.

## Audience split

| Page | Audience | Content |
|------|----------|---------|
| `index.html` | Prospective customers | Home: story, product, launch lineup |
| `how-detfs-work.html` | Prospective customers | Short product report |
| `uniswap-v4.html` | Prospective customers | Three Uniswap V4 launch markets + Mermaid structure diagrams |
| `technical-note.html` | Builders / researchers | Optional mechanism depth (archive) |
| `litepaper.html` | Bookmarks / old links | Soft redirect to product report |

Do **not** put package names, forge scenarios, or deploy scripts on customer pages.

## Local preview

```bash
cd marketing/research-site
python3 -m http.server 4173
# open http://127.0.0.1:4173
```

## Optional: Vercel mirror

```bash
cd marketing/research-site
npx vercel          # preview
npx vercel --prod   # production
```

## Related

- Narrative spine: [`../../docs/marketing/DETF_NARRATIVE_SPINE.md`](../../docs/marketing/DETF_NARRATIVE_SPINE.md)
- Product voice skill: `.grok/skills/indexedex-product-voice/`
- X copy pack: [`../X_POSTS.md`](../X_POSTS.md)
