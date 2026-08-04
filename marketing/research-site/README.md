# IndexedEx public DETF site

Static public landing for the **DETF product story** (customer-facing) with an optional technical note for builders.

## Live URL (GitHub Pages)

| Field | Value |
|-------|--------|
| **Site** | https://cyotee.github.io/indexedex/ |
| **How DETFs work** | https://cyotee.github.io/indexedex/how-detfs-work.html |
| **Uniswap V4 markets** | https://cyotee.github.io/indexedex/uniswap-v4.html |
| **Technical note (builders)** | https://cyotee.github.io/indexedex/technical-note.html |
| **Legacy `/litepaper.html`** | Redirects to the product report |
| **Optional PDF** | https://cyotee.github.io/indexedex/DETF_LITEPAPAPER.pdf |
| **Source dir** | this folder (`marketing/research-site/`) |
| **Workflow** | `.github/workflows/deploy-research-pages.yml` |

Redeploys on push to `main` when this folder (or the workflow) changes, or via **Actions → Deploy research site to GitHub Pages → Run workflow**.

## Audience split

| Page | Audience | Content |
|------|----------|---------|
| `index.html` | Prospective customers | Product home: what a DETF is, Uniswap V4 rails strip, roadmap, plain-language proof |
| `how-detfs-work.html` | Prospective customers | Full DETF product report (primary long-form) |
| `uniswap-v4.html` | Prospective customers | Uniswap V4 market rails pitch (vault bridges + multi-asset books) |
| `technical-note.html` | Builders / researchers | DETF mechanism detail, measured tables, methodology (+ pointer to V4 product page) |
| `litepaper.html` | Bookmarks / old links | Soft redirect to the product report |

Do **not** put package names, forge scenarios, or deploy scripts on customer pages.

## Local preview

```bash
cd marketing/research-site
# any static server, e.g.:
python3 -m http.server 4173
# open http://127.0.0.1:4173
```

## Optional: Vercel mirror

The original plan also allowed a **second** Vercel project rooted at `marketing/research-site` (independent of the Next app under `frontend/`). GitHub Pages is the default public landing; Vercel remains optional.

```bash
cd marketing/research-site
npx vercel          # preview
npx vercel --prod   # production
```

## Litepaper / PDF

- Preferred public read: [`how-detfs-work.html`](./how-detfs-work.html)
- Uniswap V4 rails: [`uniswap-v4.html`](./uniswap-v4.html)
- Builders: [`technical-note.html`](./technical-note.html)
- Optional offline PDF: [`DETF_LITEPAPAPER.pdf`](./DETF_LITEPAPAPER.pdf) (technical snapshot; may lag the product report)
- Source/build for the PDF: `research/papers/detf-litepaper/` (`build_pdf.sh`)

When regenerating the PDF, copy it here and to `frontend/public/research/DETF_LITEPAPAPER.pdf` for the Next app. Prefer regenerating from customer-facing prose when the PDF is meant for the same audience as the product report.

## Before public ship

1. Confirm GitHub / social links in `index.html` (`#follow` section).
2. Set a real domain (e.g. `research.indexedex.xyz`) in Vercel if used.
3. Optional: add `og-image.png` and wire `og:image` / `twitter:image` meta tags.
4. Align public venue naming with `docs/ROBINHOOD_LAUNCH_PLAN.md` comms rule — this site is **venue-forward** by default (names Robinhood Chain). Switch copy to brand-silent if that decision stays locked.
5. Point CTAs in `marketing/X_POSTS.md` at the production URL and **How DETFs work**.

## Related

- Narrative spine (SoT): [`../../docs/marketing/DETF_NARRATIVE_SPINE.md`](../../docs/marketing/DETF_NARRATIVE_SPINE.md)
- Product voice skill: `.grok/skills/indexedex-product-voice/` (or synced copies under `.claude/skills/`)
- X copy pack: [`../X_POSTS.md`](../X_POSTS.md)
- Internal product track: [`../../docs/ROBINHOOD_LAUNCH_PLAN.md`](../../docs/ROBINHOOD_LAUNCH_PLAN.md)
- Research findings roll-up: [`../../research/MARKETING_AND_PERFORMANCE_FINDINGS.md`](../../research/MARKETING_AND_PERFORMANCE_FINDINGS.md)
- In-app landing (R3): `frontend/app/page.tsx`
