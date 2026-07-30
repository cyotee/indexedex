# IndexedEx research site (Vercel)

Static public landing for **DETF research** and multi-chain launch narrative.

## Local preview

```bash
cd marketing/research-site
# any static server, e.g.:
python3 -m http.server 4173
# open http://127.0.0.1:4173
```

Or with Vercel CLI:

```bash
cd marketing/research-site
npx vercel dev
```

## Deploy to Vercel

### Option A — CLI (from this folder)

```bash
cd marketing/research-site
npx vercel          # preview
npx vercel --prod   # production
```

### Option B — Vercel dashboard

1. Import the repo (or this subdirectory as a monorepo root).
2. Set **Root Directory** to `marketing/research-site`.
3. Framework Preset: **Other**.
4. Build Command: leave empty (static).
5. Output Directory: `.` (or leave default for static).
6. Deploy.

### Option C — monorepo with existing project

If the main app already uses Vercel from `frontend/`, create a **second** Vercel project pointed at `marketing/research-site` so product UI and research marketing stay independent.

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
