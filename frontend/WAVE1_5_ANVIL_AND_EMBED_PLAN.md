# Wave 1.5 — Local verification + Earn DETF embed enable (closed)

| Field | Value |
|-------|--------|
| **Status** | **Complete** (2026-07-25) — deposit + bond + lab embed proven; free mint precondition noted |
| **Date** | 2026-07-25 |
| **Entry point** | [`ROADMAP.md`](./ROADMAP.md) |
| **Design SoT** | [`FRONTEND_REDESIGN_DESIGN.md`](./FRONTEND_REDESIGN_DESIGN.md) rev 7 |
| **Depends on** | Wave 1 foundation + UI polish (**shipped**) |
| **Working directory** | `frontend/` only for residual work |

---

## ⛔ Do not deploy

This plan is **closed**. Agents **must not** re-execute stack deploys to “refresh” Wave 1.5:

- No `scripts/shell/local_testing.sh` / forge broadcast / Anvil restart-as-redeploy  
- No tokenlist “rebuild after deploy” pipelines as part of frontend tasks  
- If RPC/artifacts are missing: **document the gap**; use unit/static tests on committed `app/addresses/**`  

See [`ROADMAP.md`](./ROADMAP.md) § Do not deploy.

---

## 1. Purpose (historical)

Prove money paths against a **local** stack, smoke mint/bond surfaces, then prove **Earn DETF embed** in lab (`NEXT_PUBLIC_EARN_DETF_EMBED=true` process/local only). Shared/prod flag stays **false**.

This phase was **verification + flag enable**, not redesign.

---

## 2. Goals (all met or documented)

1. Frontend pointed at `local_testing` artifacts + existing RPC; Earn boots.  
2. Strategy deposit smoke with non-zero minOut **or** blocker note.  
3. DETF bond smoke (or mint precondition documented); `/staking?detf=` deep link.  
4. Lab embed mount proven; shared default **false**.  
5. `cd frontend && npm run check` green.

### Non-goals (still)

- Wave 2 fee-DETF marketing/design implementation  
- PR8 SharePositionCard, PR9 USD, brand lock  
- Rewriting DepositPanel / ActionCta / Permit2 / Header chain-switch  
- Enabling embed flag in production shared envs without owner OK  
- New contracts / DFPkgs / inventing APY-TVL-USD  
- **Any further deploys**

---

## 3. Constraints

| Rule | Detail |
|------|--------|
| **No deploy** | Mandatory — ROADMAP |
| Artifacts | Use committed `getAddressArtifacts` + `app/addresses/chain/**` |
| Embed | Flag default **false** in `.env.example` and shared envs |
| `/staking` | Remains full workspace forever |
| Approvals | Split handlers for multi-leg CTAs (K17) |
| Honesty | No fake USD/APY in test UI |

---

## 4. Environment (use existing only)

**Do not start or redeploy Anvil/stacks for this plan.**

If an operator already has RPC + artifacts:

```bash
cd frontend
export NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT=local_testing
export NEXT_PUBLIC_EARN_DETF_EMBED=false   # shared default
npm run dev
```

Expected committed surfaces (read-only checks):

| Check | Path |
|-------|------|
| Platform | `app/addresses/chain/11155111/platform.json` |
| Tokenlists | `strategy-vaults`, `protocol-detfs`, `base-tokens` under `chain/11155111/` |
| Registry | `local_testing` in `app/addresses/index.ts` **and** `index.js` |

---

## 5. Code map (exercise / residual bugs only)

| Area | Paths |
|------|--------|
| Deposit | `components/earn/DepositPanel.tsx`, `/earn/[address]` |
| Swap | `swap/page.tsx` — multi-leg ActionCta only |
| DETF mint/bond UI | `/staking`, `StakingPageClient`, mint/bond sections |
| Embed | `lib/lab.ts`, `EarnDetailClient`, `DetfWorkspaceEmbed` |
| Artifacts | `addressArtifacts.ts`, `addresses/index.ts` + `index.js` |
| E2E | `e2e/earn-detf-embed.spec.ts`, deposit-panel / shell specs |

---

## 6. Closed slices (results)

### Slice A — Boot + artifacts — **done**

- [x] Chain id / artifacts resolve for router / permit2 / vaults when stack present  
- [x] Earn loads without crash  
- [x] Smoke-blocker fixed: stale `app/addresses/index.js` missing `local_testing` (synced + null-safe `getArtifactBundle`; unit tests)

### Slice B — Money path — **done**

- [x] Strategy deposit with non-zero minOut (8-tuple query / 10-tuple execute path)  
- [x] Playwright deposit-panel Connect / mode gates  
- [x] Swap multi-leg optional; split handlers unchanged  

### Slice C — DETF mint/bond — **done with mint precondition**

- [x] Bond path exercised (rate asset + lock terms) when stack present  
- [x] Free mint may remain `MintingNotAllowed` / `isMintingAllowed=false` on some fixtures — **documented**, not a UI rewrite  
- [x] `/staking?detf=` deep link  

### Slice D — Lab embed — **done**

- [x] Flag off: deep-link only; no `detf-workspace-embed`  
- [x] Flag on (lab process env only): tab **Mint / bond / sell** → `data-testid="detf-workspace-embed"`; Open full workspace → `/staking?detf=…`; no debug panel  
- [x] `.env.example` remains `NEXT_PUBLIC_EARN_DETF_EMBED=false`  

### Slice E — Docs — **done**

- [x] ROADMAP + this checklist + MANUAL checklist + design residual  

---

## 7. Definition of Done — met

1. Local path exercised historically; residual work uses existing artifacts only.  
2. Deposit smoke green.  
3. Bond green; mint precondition documented.  
4. Lab embed proven; shared default false.  
5. `npm run check` green.  
6. ROADMAP points to Wave 2 design.

**Handoff to Wave 2:** product design for **fee-accrual DETF highlight** — design-only first; do not reopen Wave 1 shell primitives; **do not deploy**.

---

## 8. Orchestrator checklist — all complete

- [x] Slice A — stack presence + UI boot (no re-deploy)  
- [x] Slice B — deposit smoke  
- [x] Slice C — mint/bond (+ mint gate note)  
- [x] Slice D — lab embed  
- [x] Slice E — docs  
- [x] Owner note for mint precondition  

### Execution notes (2026-07-25)

- Fixed smoke-blocker: `local_testing` missing from compiled `addresses/index.js`.  
- Deposit: non-zero minOut on strategy vault path; Earn amount e2e uses `earn-deposit-amount-input`.  
- Bond OK; free mint threshold-gated on fixture.  
- Embed flag-on Playwright: `e2e/earn-detf-embed.spec.ts`.  

---

## 9. Risks (residual)

| Risk | Mitigation |
|------|------------|
| Empty catalog / no RPC | Document blocker; unit tests on committed lists; **do not deploy** |
| Embed regression | File bugfix; do not re-scope polish |
| Agent enables flag in CI | `.env.example` + ROADMAP: shared false |
| Agent redeploys stack | **Forbidden** — ROADMAP no-deploy |

---

## 10. References

- [`ROADMAP.md`](./ROADMAP.md)  
- [`FRONTEND_REDESIGN_DESIGN.md`](./FRONTEND_REDESIGN_DESIGN.md) § Remaining  
- [`MANUAL_UI_ROUTE_CHECKLIST.md`](./MANUAL_UI_ROUTE_CHECKLIST.md)  
- `app/lib/lab.ts`, `components/earn/detf/DetfWorkspaceEmbed.tsx`  

---

*End of Wave 1.5 plan — closed. No deploy instructions.*
