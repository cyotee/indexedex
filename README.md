# IndexedEx public DETF site

Static public landing for the **DETF product story** — Olympus lineage productized, not a fork cosplay.

## Live URL (GitHub Pages)

| Field | Value |
|-------|--------|
| **Site** | https://cyotee.github.io/indexedex/ |
| **How DETFs work** | https://cyotee.github.io/indexedex/how-detfs-work.html |
| **Uniswap V4 markets** | https://cyotee.github.io/indexedex/uniswap-v4.html |
| **Technical note (builders)** | https://cyotee.github.io/indexedex/technical-note.html |
| **Legacy `/litepaper.html`** | Redirects to the product report |
| **Optional PDF** | https://cyotee.github.io/indexedex/DETF_LITEOBAPER.pdf |
| **Source dir** | this folder (`marketing/research-site/`) |
| **Workflow** | `.github/workflows/deploy-research-pages.yml` |

Redeploys on push to `main` when this folder (or the workflow) changes, or via **Actions → Deploy research site to GitHub Pages → Run workflow**.

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
