# Research section + DETF-first landing — design note

| Field | Value |
|-------|--------|
| **Status** | **R1 + R2 + R3 shipped** (2026-07-27) — research routes, DETF note Policy/Open, landing DETF hero + research strip |
| **Date** | 2026-07-27 |
| **Frontend root** | `frontend/` |
| **Agent entry** | [`ROADMAP.md`](./ROADMAP.md) (no-deploy still applies) |
| **Narrative spine** | [`docs/marketing/DETF_NARRATIVE_SPINE.md`](../docs/marketing/DETF_NARRATIVE_SPINE.md) |
| **Related** | `research/MARKETING_AND_PERFORMANCE_FINDINGS.md` (canonical science), `marketing/X_POSTS.md` (comms) |

---

## 0. Goals

1. Make **research a first-class product surface** inside the existing Next app (not only a separate Vercel teaser).
2. Educate on **creating DETFs** as the premier product (many package types; decentralized ETF *pattern* — not a registered securities ETF). Protocol DETF = fee-share / staking path.
3. Publish **claim-safe** notes backed by monorepo research, without dumping engineer FINDINGS files into the UI.
4. Leave a clean path for **R2** (`/research/detf` polish if needed), **R3** (landing rewrite), **R4** (charts).

---

## 1. Information architecture

```text
/                         Landing (R3: DETF hero — not in R1)
/research                 Index of publishable notes
/research/[slug]          Individual note
/staking                  Live fee-accrual DETF (unchanged)
/earn                     Vault catalog (unchanged)
/insights                 Lab pool diagnostics — NOT research (unchanged)
```

| Route | Role |
|-------|------|
| `/research` | Catalog: title, summary, date, tags; link to live DETF |
| `/research/[slug]` | Long-form note: claim → body → not-claiming → product CTA |
| `/insights` | Power tool under More; do not conflate with Research |

### Navigation (R1)

| Location | Change |
|----------|--------|
| Primary nav | Add **Research** → `/research` (after Portfolio or before Token) |
| Footer | Add **Research** |
| More menu | Keep Insights as-is; optional “Research” not required if primary |

---

## 2. Content model

### 2.1 Layers

| Layer | Location | Rule |
|-------|----------|------|
| Canonical science | Repo `research/` | Full scenarios, jsonl, agent reports — source of truth |
| Publishable spine | `frontend/app/content/research/` | Curated articles only |
| Figures (R4) | `frontend/public/research/<slug>/` | Hand-picked PNGs only |

**Do not** import all of `research/out/` into the Next bundle.

### 2.2 Registry

```text
frontend/app/content/research/
  types.ts
  index.ts                 # RESEARCH_ARTICLES + helpers
  articles/
    detf.ts
    detf-types.ts
    bond-vs-mint.ts
    rate-providers.ts
```

Each article module exports a `ResearchArticle`:

| Field | Purpose |
|-------|---------|
| `slug` | URL segment |
| `title` / `summary` | Index + OG |
| `date` | ISO date, sort desc |
| `tags` | e.g. `detf`, `rates`, `se`, `trust` |
| `status` | `published` \| `draft` (draft hidden unless lab) |
| `sections` | Ordered body blocks (heading + paragraphs + optional bullets) |
| `claims` | Short “what we show” list |
| `notClaiming` | Mandatory honesty list |
| `relatedProductHref` / `Label` | Optional CTA (`/staking`, `/earn`) |
| `sourceNote` | Pointer to monorepo paths for transparency |

### 2.3 Published research articles

| Slug | Title | Source spine |
|------|-------|----------------|
| `detf` | What is a DETF? | Product PRDs / AGENTS DETF rules / marketing spine |
| `detf-types` | DETF types: which design for which basket | AGENTS DETF families; family PRDs |
| `bond-vs-mint` | Bond vs mint: liquid share or seigniorage path | Spine lifecycle; bond/claim AGENTS rules |
| `rate-providers` | Rate providers: mark accuracy or market reprice | `MARKETING_AND_PERFORMANCE_FINDINGS` §3.3; rates on (accuracy) vs off (reprice volume) |

**Removed from public research:** `preview-execution` (engineering trust bar, not a selling panel). DualLiquidity may appear as **supporting evidence** inside rate-provider notes — **not** as a hero product name.

### 2.4 Editorial bar (every public note)

- One plain-language lead claim  
- 0–2 figures in R1 (text-only OK); charts in R4  
- Explicit **Not claiming** section  
- No invented APY  
- DETF ≠ registered ETF; onchain exposure ≠ legal ownership of offchain underlyings  
- Product CTA only where honest  

---

## 3. UI specs (R1)

### 3.1 `/research` index

- `PageHeader`: title “Research”, subtitle “Measured claims. Product education.”  
- Grid of cards: title, summary, date, tags  
- Top callout: “Premier product: create your own DETFs” → `/research/detf`; secondary “Protocol fee share” → `/staking` 
- Empty draft filter: only `status === 'published'` in production  

### 3.2 `/research/[slug]`

- Back link to `/research`  
- Title, date, tags  
- Optional “Claims” card (bullets)  
- Sections as prose  
- “Not claiming” card (muted)  
- Optional product CTA button  
- Fine print: source note + general risk line  

Use existing primitives: `PageHeader`, `Card`, `Button`, design tokens (`--text-primary`, `--accent`, etc.). No new design system.

### 3.3 Rendering

- Prefer **server components** for research pages (static content, better SEO).  
- No wallet required.  
- No MDX in R1 (TS modules only).  

---

## 4. Landing (R3 — **shipped**)

```text
Hero DETF → Benefits → How it works → Live fee DETF → Research strip → Secondary Earn → Disclaimers
```

Implemented in `app/page.tsx` per `docs/marketing/DETF_NARRATIVE_SPINE.md` §6. Wave 2 fee-accrual DETF → `/staking` preserved.

---

## 5. Phased delivery

| Phase | Scope | Status |
|-------|--------|--------|
| **R1** | Registry, notes, `/research`, `/research/[slug]`, nav + footer | **Shipped 2026-07-27** (catalog evolved: types + bond-vs-mint; dropped preview-execution) |
| **R2** | Polish DETF note (Policy/Open + spine claims) | **Shipped 2026-07-27** (`articles/detf.ts`) |
| **R3** | Landing DETF-first rewrite + research teaser strip | **Shipped 2026-07-27** (`app/page.tsx`) |
| **R4** | Selected plots under `public/research/` | Pending |
| **R5** | e2e smoke + OG metadata per slug | Pending |

---

## 6. Acceptance criteria (R1)

- [x] `/research` lists published articles (`detf`, `detf-types`, `bond-vs-mint`, `rate-providers`)  
- [x] `/research/detf`, `/research/detf-types`, `/research/bond-vs-mint`, `/research/rate-providers` render full body  
- [x] `/research/preview-execution` is not registered (removed)  
- [x] Unknown slug → 404 (`notFound()`)  
- [x] Header primary nav includes Research  
- [x] Footer includes Research  
- [x] No new deploy scripts; no contract work  
- [x] Insights remains a separate lab route  

---

## 7. Non-goals (R1)

- Landing rewrite  
- MDX pipeline  
- Full research plot gallery  
- Replacing external docs URL  
- DualLiquidity as hero  
- Venue brand names required in research copy (product-first; multi-chain neutral unless a note is venue-specific)  

---

## 8. File map (R1)

```text
frontend/RESEARCH_SECTION_DESIGN.md          # this file
frontend/app/content/research/types.ts
frontend/app/content/research/index.ts
frontend/app/content/research/articles/*.ts
frontend/app/research/page.tsx
frontend/app/research/[slug]/page.tsx
frontend/app/research/components/ResearchArticleView.tsx
frontend/app/components/layout/Header.tsx    # nav
frontend/app/components/layout/Footer.tsx    # footer
```
