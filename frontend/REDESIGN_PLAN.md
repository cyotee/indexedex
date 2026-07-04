# IndexedEx / Pachira Frontend Redesign Plan

**Status:** Implemented (core funnel shipped; see goal plan Deviations)  
**Brand in UI today:** Pachira (“Composed Indexed Liquidity”)  
**Stack:** Next.js App Router, Tailwind v4 (`globals.css` `@theme`), wagmi/viem, list-driven menus (`menuConfig.ts` + tokenlists)  
**Goal:** Convert visitors into **token buyers** and **depositors** with a professional vault UX, light internet-culture personality on the edges only.

---

## 1. Product goals

| Priority | Outcome |
|----------|---------|
| P0 | First-time user can connect → pick a strategy → deposit in ≤ 3 primary clicks after connect |
| P0 | Launch path: buy/claim token → soft handoff into a featured vault/DETF deposit |
| P0 | Trust: fees, contracts, chain, and “where is my money” visible without docs spelunking |
| P1 | Portfolio is the post-deposit home (positions, bond NFTs, unlocks, share card) |
| P1 | DETF lifecycle (mint → bond NFT → sell → RICHIR) is understandable in the UI |
| P2 | Power tools (create, batch-swap, admin, mint, token-info) remain available but demoted |

**Non-goals for this redesign**

- Rewriting contract ABIs, deploy scripts, or tokenlist generation pipelines
- New yield math / off-chain indexer (use existing reads + tokenlists; charts can stub then upgrade)
- Full mobile native app
- Replacing wagmi / Permit2 flows (improve presentation only)
- Renaming on-chain artifacts (e.g. JSON keys `protocolNftVault`) — UI labels can say “Bond NFT vault”

---

## 2. Current-state audit (baseline)

### 2.1 Routes in use

| Route | Role today | Redesign fate |
|-------|------------|---------------|
| `/` | Static card grid (“Welcome to Pachira”); some links broken (`/pools`, `/insights/vault`) | **Conversion landing** (disconnected) / redirect to Earn (connected, optional) |
| `/swap` | Core swap via SE router | Keep; secondary nav; launch mode defaults |
| `/batch-swap` | Power multi-step | Demote under **More** |
| `/vaults` | Strategy vault browser (tokenlist `vaults-page`) | Core of **Earn** |
| `/detf`, `/detfs` | DETF UI (thin wrappers) | Merge into Earn + detail; keep redirects |
| `/staking` | Protocol DETF mint/bond/sell sections | **DETF workspace** under Earn detail / Advanced |
| `/portfolio` | Balances + bond NFT positions | Post-deposit home; polish heavily |
| `/insights` | Insights | Educate → convert; trust content |
| `/create`, `/mint`, `/token-info` | Power / debug-adjacent | More menu |
| `/seigniorage` | Present | Fold into Earn type filter |

### 2.2 Shell & design system today

- `app/layout.tsx`: Inter, `bg-gray-900`, Header + main only; no footer, no max-width shell component.
- `app/globals.css`: dual themes `pachira` (lime/green accent, wavy `bg_web.svg`) and `current` (neutral dark). Heavy `!important` overrides on borders/text.
- `app/components/layout/Header.tsx`: flat nav dump — Create, Swap, Batch Swap, Vaults, Portfolio, DETFs, Staking, Insights, Pools, Admin, + More (Mint, Token Info). Chain/env switchers and wallet live here (complex; keep logic, restyle chrome).
- Shared UI is sparse: almost no design-system components under `app/components/` (Approval, Slippage, WalletStatusBanner, DebugPanel, Header only).
- Data model is already good: **list-driven** (`menuConfig.ts` → tokenlists by chain/env). Redesign should **compose** lists into Earn, not invent hard-coded vault tables.

### 2.3 Pain points to fix

1. **Toolbox IA** — equal-weight nav for power and money paths.
2. **No unified Earn** — vaults vs DETFs vs staking feel like separate apps.
3. **Landing is not a funnel** — no live stats, no primary deposit CTA, dead links.
4. **No shared deposit primitive** — each page reinvents amount/approve/tx UX.
5. **Debug surfaces leak into product** — DebugPanel density competes with trust.
6. **Visual system is theme CSS hacks** — need semantic tokens + components instead of more `!important`.

---

## 3. Experience principles

1. **Proof-first** — APY, TVL, fees, contracts, chain before brand jokes.
2. **One primary action per view** — Deposit / Swap / Buy Token.
3. **Progressive disclosure** — card → detail tabs → advanced.
4. **80/20 tone** — institutional tables; culture only on landing, empty states, success, share cards.
5. **List-driven truth** — UI never invents products not present in tokenlists for the active chain/env.
6. **Production hides lab** — supersim/anvil controls only when env ≠ public production build flag.

---

## 4. Information architecture

### 4.1 Primary nav (always visible)

```
[Logo]  Earn  ·  Swap  ·  Portfolio  ·  Token     [Chain] [Connect]
                                              More ▾
```

| Item | Target | Notes |
|------|--------|-------|
| Logo | `/` | Landing |
| **Earn** | `/earn` | Unified vault + DETF browser (**new** default product surface) |
| **Swap** | `/swap` | Existing |
| **Portfolio** | `/portfolio` | Existing, upgraded |
| **Token** | `/token` | **New** launch / utility page (or redirect to swap with defaults until TGE content ready) |
| More | dropdown | Batch Swap, Create, Insights, Mint, Token Info, Staking (legacy URL), Admin (gated), Theme |

### 4.2 Route map (implement)

| Path | Purpose |
|------|---------|
| `/` | Marketing landing |
| `/earn` | Unified catalog (filters, sort, featured) |
| `/earn/[address]` | Product detail + deposit/withdraw + tabs |
| `/swap` | Swap (optional `?launch=1` defaults) |
| `/portfolio` | Positions + bond NFTs + share |
| `/token` | Token story, buy CTA, utility |
| `/staking` | **Redirect** → `/earn?type=detf` or last protocol DETF detail (preserve deep links during migration) |
| `/vaults` | **Redirect** → `/earn?type=strategy` |
| `/detfs`, `/detf` | **Redirect** → `/earn?type=detf` |
| Existing power routes | Unchanged paths; linked only from More |

### 4.3 Menu / list wiring

Extend `app/lib/menuConfig.ts` (do not break existing menus):

```ts
// New catalog menus for Earn
'earn-strategy-vaults': { fromLists: [{ listId: 'strategy-vaults', type: 'vault' }] },
'earn-protocol-detfs':  { fromLists: [{ listId: 'protocol-detfs', type: 'vault' }] },
'earn-seigniorage-detfs': { fromLists: [{ listId: 'seigniorage-detfs', type: 'vault' }] },
// Keep vaults-page / seigniorage-detfs-page as aliases or migrate callers
```

Earn page merges these into one row model with `productType: 'strategy' | 'protocol-detf' | 'seigniorage-detf'`.

---

## 5. Design system

### 5.1 Tokens (extend `globals.css`, reduce `!important`)

Introduce semantic CSS variables used by components (map into both themes):

| Token | Role | Pachira suggestion |
|-------|------|--------------------|
| `--surface-0` | Page bg | `#0a0a0a` |
| `--surface-1` | Card | `#14171f` / current gray-800 |
| `--surface-2` | Elevated / input | `#1c2030` |
| `--border-subtle` | Default border | `rgba(255,255,255,0.08)` |
| `--border-accent` | Focus / featured | lime `rgba(79,212,75,0.45)` |
| `--text-primary` | Headings/body | `#EDEDED` (not full lime body text) |
| `--text-muted` | Secondary | `#9aa3b2` |
| `--accent` | Primary CTA / links | `#4FD44B` or teal `#05A0B6` — **pick one accent family** |
| `--accent-muted` | Selected row bg | `#1A3721` |
| `--danger` | Errors | existing error |
| `--warning` | Risk experimental | orange |
| `--font-mono` | Amounts, APY, addresses | JetBrains Mono or IBM Plex Mono via `next/font` |

**Theme policy**

- Default theme remains `pachira`.
- **Stop forcing all `.text-white` to lime** for body copy; reserve lime for accents, positive PnL, focus rings.
- Wavy `body::after` background: keep at ≤0.35 opacity; disable on dense tables if contrast suffers.
- `tailwind.config.js`: extend `fontFamily.mono`, `boxShadow.card`, `borderRadius.xl` — avoid one-off magic classes.

### 5.2 Typography scale

| Use | Class guidance |
|-----|----------------|
| Page title | `text-2xl md:text-3xl font-semibold tracking-tight` |
| Section | `text-lg font-medium` |
| Metric (APY/TVL) | `font-mono text-xl tabular-nums` |
| Address | `font-mono text-xs text-muted truncate` |
| Helper / joke | `text-sm text-muted` only |

### 5.3 Component library (new folder)

Create `frontend/app/components/ui/` and `frontend/app/components/earn/`:

| Component | File | Responsibility |
|-----------|------|----------------|
| `AppShell` | `ui/AppShell.tsx` | max-width container, page padding, optional launch bar slot |
| `Button` | `ui/Button.tsx` | variants: primary, secondary, ghost, danger; loading |
| `Card` | `ui/Card.tsx` | surface-1, border-subtle, optional accent |
| `Badge` | `ui/Badge.tsx` | chain, risk, product type |
| `Stat` | `ui/Stat.tsx` | label + mono value + tooltip |
| `Tabs` | `ui/Tabs.tsx` | detail page tabs |
| `Modal` / `Drawer` | `ui/Modal.tsx` | deposit / withdraw |
| `DataTable` | `ui/DataTable.tsx` | Earn list desktop |
| `EmptyState` | `ui/EmptyState.tsx` | copy + CTA (culture allowed) |
| `TxSteps` | `ui/TxSteps.tsx` | Approve → Sign → Confirm |
| `AddressLink` | `ui/AddressLink.tsx` | explorer link via existing `lib/explorer.ts` |
| `RiskBadge` | `earn/RiskBadge.tsx` | Conservative / Balanced / Experimental |
| `ProductTypeBadge` | `earn/ProductTypeBadge.tsx` | Strategy / DETF / Seigniorage |
| `EarnFilters` | `earn/EarnFilters.tsx` | type, asset, chain context, search |
| `EarnProductRow` | `earn/EarnProductRow.tsx` | table row / mobile card |
| `FeaturedProductCard` | `earn/FeaturedProductCard.tsx` | launch highlight |
| `DepositPanel` | `earn/DepositPanel.tsx` | amount, preview, fees, CTA |
| `WithdrawPanel` | `earn/WithdrawPanel.tsx` | symmetric |
| `AllocationList` | `earn/AllocationList.tsx` | “where is my money” |
| `DetfLifecycleStepper` | `earn/DetfLifecycleStepper.tsx` | mint → bond → sell → RICHIR |
| `BondNftCard` | `earn/BondNftCard.tsx` | portfolio NFT presentation |
| `SharePositionCard` | `earn/SharePositionCard.tsx` | canvas/DOM share image |
| `TrustFooter` | `ui/TrustFooter.tsx` | docs, audits, contracts, social |
| `LaunchBanner` | `ui/LaunchBanner.tsx` | sticky TGE strip |
| `PageHeader` | `ui/PageHeader.tsx` | title, subtitle, actions |

**Debug**

- Wrap `DebugPanel` in `process.env.NEXT_PUBLIC_SHOW_DEBUG === 'true'` or a header “Lab” toggle default off in production builds.

### 5.4 Layout chrome changes

**Header** (`components/layout/Header.tsx`)

- Collapse primary links to Earn / Swap / Portfolio / Token.
- Move remaining links into `MoreDropdown`.
- Keep chain switch + connect; restyle to `Button` / compact selects.
- Optional: show small “Earn” badge when on `/earn/*`.
- Logo alt/title: keep Pachira until brand rename decision; metadata in `layout.tsx` stays consistent.

**Footer** (new `components/layout/Footer.tsx`)

- Docs · Audits · GitHub · Explorer hub · Discord/X  
- One-line culture: e.g. “Indexed liquidity. Employed bags.”  
- Env name only if non-production.

**App shell**

```tsx
// layout.tsx sketch
<Providers>
  <div className="min-h-screen bg-[var(--surface-0)] flex flex-col">
    <LaunchBanner /> {/* feature-flagged */}
    <Header />
    <main className="flex-1 py-6 md:py-8">
      <AppShell>{children}</AppShell>
    </main>
    <Footer />
  </div>
</Providers>
```

---

## 6. Page specifications

### 6.1 Landing — `/` (`app/page.tsx`)

**Audience:** disconnected or first visit.

**Sections (top → bottom)**

1. **Hero**
   - H1: value prop (not only “Welcome to Pachira”)
   - Sub: one sentence on composed indexed liquidity / DETFs
   - CTA primary: `Connect & Earn` → wallet connect then `/earn`
   - CTA secondary: `Get $TOKEN` → `/token` or `/swap?launch=1`
2. **Live strip** (`Stat` row): TVL · products listed · chains — from tokenlist counts + optional on-chain sums (phase 1: product count + chain; phase 2: TVL)
3. **Featured strategies** — 3× `FeaturedProductCard` (config via env or `lib/featuredProducts.ts`)
4. **How it works** — 3 steps: Deposit into vault/DETF → protocol routes liquidity → earn / bond / redeem
5. **Trust row** — audits/docs placeholders with real links when available
6. **Weird closer** (optional, below fold) — short terminal/chat manifesto; no money CTAs that look like jokes

**Remove/fix:** dead `/pools`, `/insights/vault` cards or point to live routes.

### 6.2 Earn catalog — `/earn` (new)

**File:** `app/earn/page.tsx` + `app/earn/EarnPageClient.tsx`

**Layout**

```
[PageHeader: Earn]
[Featured banner — launch week]
[EarnFilters]
[DataTable | mobile cards]
```

**Filters**

- Type: All | Strategy | Protocol DETF | Seigniorage  
- Search by name/symbol/address  
- Sort: APY (when available) · TVL · Name · Your balance  

**Row fields**

| Field | Source |
|-------|--------|
| Name / symbol | tokenlist `display` / `symbol` |
| Type badge | productType |
| Asset | underlying from list metadata or `asset()` read if present |
| APY | phase 1: “—” or oracle if exists; phase 2: share-price series |
| TVL / liquidity | `totalAssets` / reserves reads where cheap |
| Your balance | ERC20 balance of vault/share token |
| CTA | “View” → `/earn/[address]` |

**Empty states**

- No products on chain: *“No strategies on this network yet. Switch chain or check env.”*
- No wallet: still show catalog (browse without connect); deposit requires connect on detail.

### 6.3 Product detail — `/earn/[address]`

**File:** `app/earn/[address]/page.tsx` + `EarnDetailClient.tsx`

**Above the fold**

- Back to Earn  
- Title, type badge, chain badge, risk badge  
- Stats: APY · TVL · Your position  
- Primary actions: **Deposit** | **Withdraw** (open modal or split panel on desktop)  
- Contract `AddressLink`

**Tabs**

| Tab | Content | Data notes |
|-----|---------|------------|
| Overview | Plain-language strategy; for DETF show `DetfLifecycleStepper` | Static copy map by productType + tokenlist tags |
| Performance | Chart placeholder → share price | Phase 2 |
| Composition | `AllocationList` (tokens/reserves/yield token) | Reuse vaults page reads (`reserves`, `tokens`, etc.) |
| Risks | Lock, IL, oracle, experimental flags | Copy config |
| Activity | Optional later | — |

**DETF-specific panel** (if protocol/seigniorage DETF)

- Embed slim actions from staking sections: Mint / Bond / Sell NFT as secondary cards or deep-link anchors  
- Prefer extracting shared hooks from `staking/sections/*` into `lib/hooks/` or `components/earn/detf/` rather than iframe-ing the whole staking page

**Deposit panel requirements**

1. Balance + Max  
2. Amount input (`tabular-nums`)  
3. Preview: shares out / min received if applicable  
4. Fee line (protocol fee if readable; else “see docs”)  
5. `TxSteps` for approve → deposit  
6. Use existing `useApprovalFlow` / Permit2 helpers where swap already does  
7. Success → toast + link Portfolio + optional Share  

### 6.4 Portfolio — `/portfolio`

**Keep data logic** in `portfolio/page.tsx`; restyle and structure:

1. **Summary bar** — wallet value proxy (sum known balances), # positions, # bond NFTs  
2. **Positions** — strategy vault + DETF share balances as cards/table with “Manage” → `/earn/[address]`  
3. **Bond NFTs** — `BondNftCard` grid (image from metadata, unlock countdown, pending rewards, claim CTA)  
4. **Empty** — CTA to Earn with light culture copy  
5. **Share** — generate share card for largest position or selected NFT  

Hide or collapse DebugPanel behind lab flag.

### 6.5 Token — `/token` (new)

**Launch conversion page**

- Token summary (name, chain, contract when live)  
- Primary: **Buy** → `/swap` with query defaults (`tokenOut`, slippage)  
- Utility bullets (fee share / bonding boost / governance — only real utilities)  
- “Then put it to work” → featured Earn product  
- LaunchBanner can deep-link here  

Until mainnet token exists: page states **Testnet / Coming soon** with Sepolia buy path if applicable — never fake mainnet liquidity.

### 6.6 Swap — `/swap`

- Visual restyle to `Card` + `Button` only in phase 1  
- Support `?launch=1&tokenOut=0x…` for TGE  
- Keep routing logic / `SwapForm` intact  
- WalletStatusBanner stays; match new banner styles  

### 6.7 Staking / DETF legacy

- Implement redirects in `app/staking/page.tsx`, `app/vaults/page.tsx`, `app/detfs/page.tsx`  
- Preserve query params where possible  
- Long-term: move section components under `components/earn/detf/` and delete duplicate page chrome  

---

## 7. Copy & culture guidelines

| Surface | Tone |
|---------|------|
| Buttons / fees / risks / errors | Neutral professional |
| Empty states / success toasts | One short line of personality max |
| Share cards | Optional “gmi” subtitle; default off if user prefers clean |
| Never | Joke copy on confirm transaction or lock disclaimer |

**Microcopy bank**

- Empty portfolio: “No positions yet. The index is empty — you can fix that.”  
- Deposit success: “Position live.”  
- Experimental badge tooltip: “Higher smart-contract and strategy risk. Read Risks.”  

---

## 8. Feature flags & config

```bash
# .env.example (document these)
NEXT_PUBLIC_SHOW_DEBUG=false
NEXT_PUBLIC_SHOW_LAUNCH_BANNER=false
NEXT_PUBLIC_LAUNCH_TOKEN_ADDRESS=
NEXT_PUBLIC_FEATURED_EARN_ADDRESSES=0x...,0x...   # chain-specific later
NEXT_PUBLIC_DOCS_URL=
NEXT_PUBLIC_AUDIT_URL=
```

`lib/featuredProducts.ts` — resolve featured addresses against current chain tokenlists (skip if not listed).

---

## 9. Implementation phases (PR-sized)

### PR1 — Design system + shell (no behavior change)

- Semantic tokens in `globals.css`; dial back body lime overrides  
- `AppShell`, `Button`, `Card`, `Badge`, `PageHeader`, `Footer`  
- Header primary nav collapse + More menu  
- Wire Footer in `layout.tsx`  
- Lab flag for DebugPanel on 1–2 pages as pattern  

**Done when:** visual chrome consistent on `/` and `/swap` without breaking connect/chain.

### PR2 — Landing conversion

- Rewrite `app/page.tsx` per §6.1  
- Featured products helper  
- Fix dead links  
- Optional LaunchBanner component (off by default)  

**Done when:** disconnected user sees clear path to Earn and Token/Swap.

### PR3 — Earn catalog

- `app/earn/page.tsx` + client  
- menuConfig earn menus  
- Filters, table, mobile cards  
- Redirects from `/vaults`  

**Done when:** all strategy vaults from tokenlist visible; click-through to detail scaffold.

### PR4 — Earn detail + deposit panel

- `app/earn/[address]/page.tsx`  
- Composition tab from existing vault reads  
- Deposit/withdraw panel (strategy vaults first: ERC4626-style or vault-specific entry already used in app)  
- Redirects from `/detf(s)`  

**Done when:** user can deposit into at least one strategy vault on testnet env via new UI.

### PR5 — DETF integration

- Protocol + seigniorage types on Earn  
- Lifecycle stepper  
- Port mint/bond/sell flows from `staking/sections` into detail or linked subpanels  
- `/staking` redirect  

**Done when:** mint → bond path works from Earn detail on configured test env.

### PR6 — Portfolio polish + share

- Restyle portfolio; BondNftCard; summary stats  
- SharePositionCard  
- Empty → Earn CTA  

**Done when:** bond NFTs and vault balances readable; share image generates in-browser.

### PR7 — Token page + launch mode

- `/token`  
- Swap launch query defaults  
- LaunchBanner env wiring  
- Trust links real  

**Done when:** end-to-end story Connect → Buy → Earn deposit documented in MANUAL checklist.

### PR8 — Performance & trust depth (iterative)

- APY/TVL aggregation where data allows  
- Simple performance chart  
- Risk copy matrix  
- Accessibility pass (focus rings, contrast, `prefers-reduced-motion` already partial)  

---

## 10. File / folder target structure

```
frontend/app/
  components/
    layout/
      Header.tsx          # nav collapse
      Footer.tsx          # new
    ui/                   # new design system
    earn/                 # new product components
  earn/
    page.tsx              # catalog
    EarnPageClient.tsx
    [address]/
      page.tsx
      EarnDetailClient.tsx
  token/
    page.tsx              # new
  page.tsx                # landing rewrite
  layout.tsx              # shell
  globals.css             # tokens
  lib/
    featuredProducts.ts   # new
    menuConfig.ts         # earn menus
    earn/
      types.ts            # EarnProduct row type
      loadEarnProducts.ts # merge tokenlists + optional reads
  vaults/page.tsx         # redirect
  detfs/page.tsx          # redirect
  detf/page.tsx           # redirect
  staking/page.tsx        # redirect (keep sections imported by earn)
```

---

## 11. Testing & QA

### Automated

- Keep/extend `vitest` for pure helpers (`loadEarnProducts`, route matchers, featured filter).  
- No need for full e2e in PR1; add Playwright later if desired.

### Manual (extend `MANUAL_UI_ROUTE_CHECKLIST.md`)

| # | Path | Check |
|---|------|--------|
| 1 | `/` disconnected | CTAs work; no 404 cards |
| 2 | Connect on Sepolia/Base Sepolia | Header chain switch; Earn lists non-empty when lists exist |
| 3 | `/earn` | Filter type; open detail |
| 4 | Deposit strategy vault | Approve + deposit; balance updates on Portfolio |
| 5 | DETF path | Selector + mint/bond smoke on env with protocol DETF |
| 6 | `/swap?launch=1` | Defaults apply |
| 7 | More menu | Power routes still reachable |
| 8 | Debug | Hidden when flag false |
| 9 | Mobile 375px | Earn filters + deposit usable |
| 10 | `prefers-reduced-motion` | No wave animation jank |

### Environments

- Verify `public_sepolia` and `supersim_sepolia` via existing deployment environment toggle.  
- Production build: lab/env switcher policy documented (hide or warn).

---

## 12. Success metrics (post-launch)

| Metric | How |
|--------|-----|
| Connect rate from landing | analytics later; for now manual funnel test |
| Deposit completion | txs to vault/DETF from new panel |
| Time-to-first-deposit | usability session target &lt; 3 minutes for crypto-native user |
| Support burden | fewer “where do I stake” / “what is DETF” questions |

---

## 13. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Deposit methods differ per vault type | Start with strategy vaults known to work in UI; gate DETF deposit behind productType-specific panel |
| APY unavailable | Show “—” honesty; don’t invent numbers |
| Redirect breaks bookmarks | Keep old routes as redirects ≥ 1 release |
| Header complexity regressions | Snapshot chain-switch tests manually; avoid rewriting switch logic in PR1—only restructure JSX |
| Theme `!important` fights components | Prefer semantic classes on new components; peel overrides gradually |

---

## 14. Suggested first ticket (smallest valuable slice)

**Title:** `ui: design system shell + Earn nav IA`  
**Scope:** PR1 only  
**Acceptance:**

- [ ] `Button` / `Card` / `AppShell` / `Footer` exist and are used on layout + landing skeleton  
- [ ] Header shows Earn · Swap · Portfolio · Token · More  
- [ ] `/earn` placeholder page lists strategy vaults from `selectFromMenu` / new menu id (names + addresses only)  
- [ ] `/vaults` redirects to `/earn`  
- [ ] No wagmi connect regressions on Sepolia  

---

## 15. Open decisions (resolve before PR3–4)

1. **Canonical product name in UI:** Pachira vs IndexedEx vs both (logo vs wordmark).  
2. **Accent color:** lime (current Pachira) vs teal infrastructure — stick to **one**.  
3. **Default post-connect route:** stay on page vs soft-nav to `/earn`.  
4. **TGE mechanics:** swap-only vs claim contract vs external launchpad (affects `/token`).  
5. **Risk model:** manual tags in `featuredProducts` / tokenlist tags vs on-chain.

---

## 16. Reference summary

- **Catalog UX:** Morpho Earn–style browse/filter/deposit.  
- **Trust UX:** fintech proof-first fees + progressive disclosure.  
- **Personality:** landing, empty, share only — money paths stay serious.  
- **Engineering:** list-driven tokenlists + shared deposit chrome; no parallel hard-coded product registries.

This plan is the implementation source of truth for frontend redesign work. Update the phase checklist in this file as PRs land.
