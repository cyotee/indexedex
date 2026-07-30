# IndexedEx research site

Static public landing for **DETF research** and multi-chain launch narrative.

## Live URL (GitHub Pages)

| Field | Value |
|-------|--------|
| **Site** | https://cyotee.github.io/indexedex/ |
| **Litepaper PDF** | https://cyotee.github.io/indexedex/DETF_LITEPAPAPER.pdf |
| **Source dir** | this folder (`marketing/research-site/`) |
| **Workflow** | `.github/workflows/deploy-research-pages.yml` |

Redeploys on push to `main` when this folder (or the workflow) changes, or via **Actions → Deploy research site to GitHub Pages → Run workflow**.

## Local preview

```bash
cd marketing/research-site
# any static server, e.g.:
python3 -m http.server 4173
# open http://127.0.0.1:4173
```

## Optional: Vercel mirror

The original plan also allowed a **second** Vercel project rooted at `marketing/research-site` (independent of the Next app under `frontend/`). GitHub Pages is the default public research landing; Vercel remains optional.

```bash
cd marketing/research-site
npx vercel          # preview
npx vercel --prod   # production
```

## Litepaper PDF

Served from this folder:

- [`DETF_LITEPAPAPER.pdf`](./DETF_LITEPAPAPER.pdf) — public download (also linked from hero, nav, research, footer)
- Source/build: `research/papers/detf-litepaper/` (`build_pdf.sh`)

When regenerating the PDF, copy it here and to `frontend/public/research/DETF_LITEPAPAPER.pdf` for the Next app.

## Before public ship

1. Confirm GitHub / social links in `index.html` (`#follow` section).
2. Set a real domain (e.g. `research.indexedex.xyz`) in Vercel.
3. Optional: add `og-image.png` and wire `og:image` / `twitter:image` meta tags.
4. Align public venue naming with `docs/ROBINHOOD_LAUNCH_PLAN.md` comms rule — this site is **venue-forward** by default (names Robinhood Chain). Switch copy to brand-silent if that decision stays locked.
5. Point CTAs in `marketing/X_POSTS.md` at the production URL.

## Related

- Narrative spine (SoT): [`../../docs/marketing/DETF_NARRATIVE_SPINE.md`](../../docs/marketing/DETF_NARRATIVE_SPINE.md)
- X copy pack: [`../X_POSTS.md`](../X_POSTS.md)
- Internal product track: [`../../docs/ROBINHOOD_LAUNCH_PLAN.md`](../../docs/ROBINHOOD_LAUNCH_PLAN.md)
- Research findings roll-up: [`../../research/MARKETING_AND_PERFORMANCE_FINDINGS.md`](../../research/MARKETING_AND_PERFORMANCE_FINDINGS.md)
- In-app landing (R3): `frontend/app/page.tsx`
