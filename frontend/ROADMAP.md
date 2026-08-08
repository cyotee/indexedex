# Frontend roadmap — agent entry point

| Field | Value |
|-------|--------|
| **Status** | Wave 1 + 1.5 + Wave 2 + PR8 + **RiskBadge (partial PR9)** + **Research R1 + R2 note polish + R3 landing** complete (2026-07-27) |
| **Next phase** | **R4** curated plots under `public/research/`; residual PR9 USD / brand / Wave 3; optional R5 e2e/OG |
| **Product / architecture SoT** | [FRONTEND_REDESIGN_DESIGN.md](./FRONTEND_REDESIGN_DESIGN.md) (**rev 9**) |
| **Wave 2 design SoT** | [WAVE2_FEE_DETF_DESIGN.md](./WAVE2_FEE_DETF_DESIGN.md) (**rev 2** — implemented) |
| **Narrative spine** | [`docs/marketing/DETF_NARRATIVE_SPINE.md`](../docs/marketing/DETF_NARRATIVE_SPINE.md) |
| **Working directory** | `frontend/` |
| **Multi-site architecture** | [MULTI_APP_MONOREPO_PRD.md](./MULTI_APP_MONOREPO_PRD.md) — npm workspaces, `apps/indexedex` + `apps/pachira`, shared `@indexedex/protocol` (**implementation PRD; parallel worktree OK**) |

**Cold-start rule:** Open **this file first** for frontend product work. Do **not** treat repo-root `PROGRESS.md` as the frontend redesign status (it is historical Permit2 notes unless updated).

**Multi-app monorepo work:** If the task is splitting sites / shared protocol package / dual Vercel app roots, open **[MULTI_APP_MONOREPO_PRD.md](./MULTI_APP_MONOREPO_PRD.md)** and implement only that PRD (prefer isolated worktree).

---

## ⛔ Do not deploy (mandatory)

**Frontend agents MUST NOT deploy anything** while executing product / redesign / verification work from this ROADMAP:

- No Anvil start/restart for the purpose of a full stack redeploy  
- No `scripts/shell/local_testing.sh` (or any stage/scenario forge deploy script)  
- No `forge script … --broadcast` against local or remote chains  
- No production / testnet / CI package or vault deploys as part of UI work  
- No “rebuild the world so the UI works” — if chain/RPC/artifacts are missing, **document the blocker** and use unit/static/Playwright against **existing** committed artifacts

**Allowed:** run the Next app (`npm run dev` / `check` / vitest / Playwright) against an **already running** RPC the operator provided, or offline against tokenlists under `app/addresses/`. Point env at existing `local_testing` / `supersim_sepolia` / etc. artifacts already on disk.

**Historical note:** Wave 1.5 once exercised a live Anvil stack; that work is **done**. Do **not** re-run deploys to “complete” residual QA.

**Dev tip:** `npm run dev` hardcodes `--kill-port 3000`. Prefer `node scripts/next.mjs dev --port 3001` if another app may own 3000.

---

## Agent resume (30 seconds)

| | |
|--|--|
| **Where we are** | Redesign through **Wave 2 + PR8 + RiskBadge** is **shipped**. **Research R1** + **R2** (`/research/detf` Policy/Open) + **R3** DETF-first landing + research strip **shipped**. Fee-accrual DETF lives on `/staking` (not Earn grid). |
| **Do next** | **R4** charts under `public/research/`; residual PR9 USD / brand / Wave 3. Do not invent risk tags or USD. |
| **Do not re-open** | Wave 1 money path / polish; Wave 1.5 deploys; Wave 2 list/IA; PR8 share; RiskBadge inventing levels; inventing USD/APY; DualLiquidity as hero; re-mingling fee DETFs into Earn grid; R3 landing structure (spine §6) |
| **Never** | Deploy contracts / restart Anvil stacks / run `local_testing.sh` for frontend tasks |

---

## Read order

1. **This file** (`ROADMAP.md`) — status + next + **no-deploy**  
2. [RESEARCH_SECTION_DESIGN.md](./RESEARCH_SECTION_DESIGN.md) — research IA + R1–R5 (when working research/landing narrative)  
3. [FRONTEND_REDESIGN_DESIGN.md](./FRONTEND_REDESIGN_DESIGN.md) — **rev 9** header + § Implemented vs remaining  
4. [WAVE2_FEE_DETF_DESIGN.md](./WAVE2_FEE_DETF_DESIGN.md) — Wave 2 **implemented** (do not re-build)  
5. [WAVE1_IMPLEMENTATION_PLAN.md](./WAVE1_IMPLEMENTATION_PLAN.md) / [WAVE1_UI_POLISH_IMPLEMENTATION_PLAN.md](./WAVE1_UI_POLISH_IMPLEMENTATION_PLAN.md) / [WAVE1_5_ANVIL_AND_EMBED_PLAN.md](./WAVE1_5_ANVIL_AND_EMBED_PLAN.md) — historical DoD only  
6. QA aids: [MANUAL_UI_ROUTE_CHECKLIST.md](./MANUAL_UI_ROUTE_CHECKLIST.md) (§ Wave 2), [UI_FULL_FUNCTIONALITY_TEST_PLAN.md](./UI_FULL_FUNCTIONALITY_TEST_PLAN.md)

Skills while coding: `ethskills-frontend-ux`, `indexedex-ui-refactor` (do not reintroduce live env toggle).

---

## Ordered roadmap

```text
[x] Wave 1 foundation     money path + DETF embed scaffold (flag off)
[x] Wave 1 UI polish      Portfolio + DETF chrome + Swap density
[x] Wave 1.5              local verify + deposit/bond smoke + lab embed enable
[x] Wave 2 design rev 2   WAVE2_FEE_DETF_DESIGN.md (owner Q&A locked)
[x] Wave 2 build          W2-PR1–PR4 fee-detf list, staking narrative, marketing CTAs, Earn banner/redirect
[x] Wave 2 smoke          vitest fee-list exclude + Playwright e2e/wave2-fee-detf.spec.ts (green 2026-07-26)
[x] PR8 SharePositionCard sanitized share + Portfolio wire + Token/LaunchBanner polish
[x] PR9 RiskBadge         tags-only RiskBadge + Earn wire; hide when untagged
[x] Research R1           /research registry + 3 notes + nav/footer (RESEARCH_SECTION_DESIGN.md)
[x] Research R2           detf.ts Policy/Open polish (narrative spine)
[x] Research R3           landing DETF hero + research strip (app/page.tsx, 2026-07-27)
[ ] Research R4           curated plots under public/research/
[ ] PR9 USD (optional)    only when NEXT_PUBLIC_USD_PRICE_SOURCE ≠ none + real adapter
[ ] Brand lock / P2-7     production metadata (OG absolute, favicon) when owner locks brand
[ ] Wave 3                Aave / lending IA only after Earn vs Lend nav decision
```

---

## Do not re-implement (shipped)

| Area | Evidence |
|------|----------|
| Deposit multi-leg + query 8-tuple minOut + wrong-network | `DepositPanel.tsx`, WAVE1 foundation |
| Swap multi-leg ActionCta + split approval handlers | `swap/page.tsx`, `swapActionCta.wiring.test.ts` |
| Shared primitives | `ActionCta`, `resolveWalletGate`, `AmountField`, `parseContractError`, … |
| DETF Earn embed **scaffold** + **lab enable proven** (flag default **false** shared) | `DetfWorkspaceEmbed.tsx`, `isEarnDetfEmbedEnabled()`, WAVE1_5 |
| `local_testing` address registry (TS + JS) | `app/addresses/index.ts` / `index.js`, `addressArtifacts.local_testing.test.ts` |
| Portfolio design system + `BondNftCard` + human decimals | polish plan |
| DETF workspace chrome + symbol/role titles | staking sections |
| Swap density (preview → ActionCta; Advanced collapsed) | polish plan |
| Wave 2 fee-accrual DETF IA + narrative | `featured-fee-detfs.tokenlist.json`, Earn exclude, `/staking` home, landing/Token/Portfolio CTAs, Earn banner + `/earn/0xFee` redirect |
| Wave 2 regression e2e | `e2e/wave2-fee-detf.spec.ts` (landing → staking, Earn exclude, redirect, staking chrome, Token handoff) |
| **PR8 SharePositionCard** | `components/earn/SharePositionCard.tsx`, `lib/portfolio/sanitizeShareFields.ts` (+ tests), Portfolio Share actions, Token “no invent claim”, `LaunchBanner` env wiring |
| **RiskBadge (partial PR9)** | `components/earn/RiskBadge.tsx`, `lib/earn/riskFromTags.ts` (+ tests); tags preserved on `TokenListEntry`; Earn table/detail; hide if no `risk-*` / `extensions.risk` |
| **Research R1–R3** | `/research` registry; `articles/detf.ts` Policy/Open; landing DETF-first hero + benefits + how-it-works + fee DETF + research strip + Earn secondary + disclaimers (`app/page.tsx`); spine `docs/marketing/DETF_NARRATIVE_SPINE.md` |
| **Landing lab visual** | Lab/experimental tone on `/` only: atmosphere, reserve core, Policy/Open band experiment, terminal fee DETF card, lab notes (`app/landing.css` + `app/page.tsx`) — no heavy Olympus lean |

### PR8 acceptance (done 2026-07-26)

- [x] Share fields sanitized (symbol / amount / address only; culture off by default)  
- [x] Never raw tokenURI HTML/SVG in share canvas/DOM  
- [x] Portfolio: Share on vault shares, DETF balances, bond NFTs  
- [x] Fee DETF **Manage** → `/staking?detf=` when address is on featured-fee list  
- [x] Token page does not invent claim contract  
- [x] Launch banner env-gated (`NEXT_PUBLIC_SHOW_LAUNCH_BANNER`); real routes only  
- [x] Vitest: `app/lib/portfolio/sanitizeShareFields.test.ts`

### RiskBadge acceptance (done 2026-07-26)

- [x] `resolveRiskLevel` / `parseRiskToken` only from explicit risk tags (`risk-conservative` \| `risk-balanced` \| `risk-experimental`) or `extensions.risk`  
- [x] Product tags alone (`strat`, `vault`, `detf`) do **not** invent a risk level  
- [x] `RiskBadge` renders nothing when untagged  
- [x] Earn catalog Risk column + mobile cards; detail header + Risks tab note when tagged  
- [x] No mass-tagging of production tokenlists (badges stay hidden until lists add real tags)  
- [x] Vitest: `app/lib/earn/riskFromTags.test.ts` + assemble/registry coverage  

---

## Constraints (always)

1. **No deploy** — see § Do not deploy above.  
2. **List-driven** — tokenlists + `getAddressArtifacts` + deployment env; no hard-coded vault tables.  
3. **Honesty** — no fabricated APY / TVL / USD (`NEXT_PUBLIC_USD_PRICE_SOURCE=none` → hide `$`).  
4. **Dual brand** — Pachira + IndexedEx; no single-brand lock unless owner decides.  
5. **Approvals** — sequential multi-leg UI uses **split** handlers only (`handleIssuePermit2Approval` / `handleIssueRouterApproval`), never one-shot `handleApproval` for separate CTAs.  
6. **Query vs execute** — vault deposit query **8-tuple** via `simulateContract`; execute **10-tuple**; never spread execute args into query.  
7. **DETF naming** — symbol primary, role helper secondary; no RICH/RICHIR on Earn/user chrome (Wave 2 marketing may use list symbols / RICH when list uses them).  
8. **Embed safety** — `NEXT_PUBLIC_EARN_DETF_EMBED=false` in shared/prod; lab-only true is operator-opt-in; keep `/staking` full page.  
9. **Fee DETF IA** — product home is `/staking`; Earn grid **must not** list `featured-fee-detfs` addresses.

---

## Code map

| Journey | Entry | Notes |
|---------|--------|------|
| Strategy deposit | `app/components/earn/DepositPanel.tsx` | Multi-leg + minOut **done** |
| Swap | `app/swap/page.tsx` | ActionCta multi-leg **done** |
| DETF full workspace | `app/staking/StakingPageClient.tsx` | fee-accrual DETF home (mint/bond/sell) |
| Featured fee DETFs | `addresses/chain/*/featured-fee-detfs.tokenlist.json`, `getFeaturedFeeDetfsForChain` | list-driven; excluded from Earn |
| DETF Earn embed | `app/components/earn/detf/DetfWorkspaceEmbed.tsx` | flag-gated (shared/prod false) |
| Earn detail | `app/earn/[address]/EarnDetailClient.tsx` | fee addresses → redirect `/staking?detf=` |
| Portfolio | `app/portfolio/page.tsx`, `BondNftCard.tsx`, **`SharePositionCard.tsx`** | polish + PR8 share **done** |
| Share sanitizers | `app/lib/portfolio/sanitizeShareFields.ts` | unit-tested |
| Token / launch | `app/token/page.tsx`, `components/ui/LaunchBanner.tsx` | PR8 polish **done** |
| Env / artifacts | `deploymentEnvironment.tsx`, `addressArtifacts.ts`, `addresses/` | existing lists only |
| Wave 2 e2e | `e2e/wave2-fee-detf.spec.ts` | regression when touching routes |

### Next work (not started)

| Item | Gate | Notes |
|------|------|--------|
| **USD on AmountField** | `NEXT_PUBLIC_USD_PRICE_SOURCE` ≠ `none` + real adapter | Do **not** invent prices |
| **Risk tags on lists** | Owner product matrix | Optional: add `risk-*` tags to tokenlists when honest labels exist |
| Brand lock | Owner | `NEXT_PUBLIC_BRAND_LOCKED=true` |
| P2-7 metadata | Owner production | Absolute OG URL, title, favicon |
| Wave 3 lending | Owner Earn vs Lend | Do not invent Lend nav |

---

## Env flags (frontend)

See `.env.example`. Critical defaults:

```bash
NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT=local_testing   # or supersim_sepolia / sepolia as appropriate
NEXT_PUBLIC_EARN_DETF_EMBED=false                          # shared/prod always false; lab true only if operator opts in
NEXT_PUBLIC_SHOW_DEBUG=false
NEXT_PUBLIC_USD_PRICE_SOURCE=none
NEXT_PUBLIC_SHOW_LAUNCH_BANNER=false
NEXT_PUBLIC_LAUNCH_TOKEN_ADDRESS=                          # optional; Token + LaunchBanner buy path
```

Do **not** create shared env that enables embed or triggers contract deploys.

---

## Resume prompt (paste for next agent)

```text
Open frontend/ROADMAP.md first (no-deploy policy). Wave 1 + 1.5 + Wave 2 + PR8 + RiskBadge are DONE.

CONTEXT
- Wave 2 fee-accrual DETF shipped: featured-fee-detfs list, Earn exclude, /staking home.
- PR8 SharePositionCard shipped. RiskBadge: risk-* tags only; hide if untagged.
- Product home for fee DETF = /staking. Do not mingle fee DETFs into Earn grid.
- No deploys. No fabricated APY / TVL / USD / fee bps / invent risk levels.
- NEXT_PUBLIC_EARN_DETF_EMBED stays false in shared/prod.
- Wave 2 regression: e2e/wave2-fee-detf.spec.ts (keep green when touching routes).

DO NEXT (implement — do not re-smoke Wave 2 as primary task)
1. Prefer owner-chosen residual: PR9 USD only if real price source; OR brand lock / P2
   metadata; OR Wave 3 design after Earn vs Lend; OR optional honest risk-* list tags.
2. If no owner pick: STOP and ask — do not invent DualLiquidity hero or re-open Wave 1–2.

Skills: ethskills-frontend-ux, indexedex-ui-refactor (no live env toggle).
Working directory: frontend/
```

---

## Session notes (2026-07-26)

- Wave 2 vitest (featured fee exclude) + Playwright `wave2-fee-detf.spec.ts` re-run **green**.  
- Port 3000 may be non-IndexedEx apps; use **:3001** for Next when needed.  
- RPC optional for Wave 2 IA e2e (list/route only).  
- PR8 implemented and documented; design SoT bumped to **rev 9** in `FRONTEND_REDESIGN_DESIGN.md`.  
- **RiskBadge (partial PR9):** `riskFromTags` + Earn wire; no production list tags yet (chips hidden until owner adds `risk-*`).

---

## References

- Architecture (rev 9): [FRONTEND_REDESIGN_DESIGN.md](./FRONTEND_REDESIGN_DESIGN.md)  
- Wave 2 design (implemented): [WAVE2_FEE_DETF_DESIGN.md](./WAVE2_FEE_DETF_DESIGN.md)  
- Wave 1 foundation: [WAVE1_IMPLEMENTATION_PLAN.md](./WAVE1_IMPLEMENTATION_PLAN.md)  
- Wave 1 polish: [WAVE1_UI_POLISH_IMPLEMENTATION_PLAN.md](./WAVE1_UI_POLISH_IMPLEMENTATION_PLAN.md)  
- Wave 1.5 closed: [WAVE1_5_ANVIL_AND_EMBED_PLAN.md](./WAVE1_5_ANVIL_AND_EMBED_PLAN.md)  
- Funnel baseline (historical): [REDESIGN_PLAN.md](./REDESIGN_PLAN.md)  
- Repo: `Agents.md` — **frontend work still must not deploy**
