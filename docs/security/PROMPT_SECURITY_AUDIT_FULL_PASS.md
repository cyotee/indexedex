# Agent prompt — Complete Stage 1 MODE=full security audit

> **How to use:** Paste the boxed `/goal` text below into a **new** goal (do not `/goal resume` the pilot).  
> Or open this file as the sole task prompt for any orchestrator agent.  
> **Repo root:** IndexedEx (`lib/indexedex`).  
> **Kind:** Stage 1 review only. Reports under `docs/security/audit/**`. No remediations.

---

## Launch (paste into `/goal`)

```text
/goal Complete Stage 1 MODE=full of the IndexedEx security audit. Produce a comprehensive AUDIT-REPORT for every in-scope money product under contracts/. No half measures.

LAW (read fully before spawning):
- docs/security/SECURITY_AUDIT_PRD.md (especially §§2–8, §12 DoD, §15.3, §19 L-SEC-1…14)
- docs/security/SECURITY_AUDIT_EXECUTE_PLAN.md Tasks O5–O7 and §4 prompts
- docs/security/PROMPT_SECURITY_AUDIT_FULL_PASS.md (this file)
- Claude.md + docs/agent/INDEXEDEX_AGENT_LAW.md (DETF/deploy)

YOU ARE the Stage 1 orchestrator. Spawn parallel product-area and specialist subagents. You do not implement CODE. You do not write docs/security/SECURITY_AUDIT_REMEDIATION_PRD.md. You do not open sec_fix_* or gap_cover_* worktrees. Writes only under docs/security/audit/**. Never via_ir. Never kill long forge/solc. Never treat mock SUT as proof a vuln is absent. DETF role names only.

PILOT IS DONE — REUSE, DO NOT REDO:
- docs/security/audit/00_SCOPE_PARTITION.md
- docs/security/audit/areas/A-commons-pull.md
- docs/security/audit/areas/A-detf-multi-vault.md
- docs/security/audit/areas/A-se-amm-v2.md
- docs/security/audit/specialists/S-sharp-edges.md
- docs/security/audit/specialists/S-crops-trust.md
- docs/security/audit/repro/SEC-COMMON-001/ (I1 9/9 PASS at 1e0d7c48 — re-check SHA if HEAD moved)
- Thin pilot AGGREGATE.md + WORK_PACKAGE_BACKLOG.md + PILOT_EXIT.md

Before overwriting the thin pilot aggregate/backlog, copy them to docs/security/audit/archive/{RUN_DATE}/ (keep pilot evidence). Then rewrite AGGREGATE.md and WORK_PACKAGE_BACKLOG.md as the FULL reports (PRD §7.5 and §8). Update 00_SCOPE_PARTITION.md with the full partition. Re-open a pilot area only if inventory finds a missing in-scope product that the pilot report never named.

FULL PASS IS MANDATORY. Do not stop at PARTIAL because the monorepo is large. Split oversized areas into non-overlapping child areas rather than skipping products. Every ship-blocking money product under contracts/ must appear in some area inventory (L-SEC-2).

REQUIRED AREA AGENTS (spawn in parallel waves of 4–8; use execute-plan §4.1 prompts):
F1:
- A-detf-single-se — Balancer V3 Single SE DETF + Uni V4 Single SE CP DETF (and any other single-SE DETF packages)
- A-detf-composed-stable — Composed stable + mixed buffer
- A-detf-dual-liquidity — DualLiquidity cross-version (fork-first; L-SEC-5)
F2 (SPLIT if one agent cannot finish — do not omit):
- A-se-univ3 — contracts/protocols/dexes/uniswap/v3/** (pilot already flagged live PAT-I-ABS clones)
- A-se-univ4 — contracts/protocols/dexes/uniswap/v4/** SE
- A-se-lending-lst — Aave Stata/loop, Morpho SE, Lido/EtherFi/Rocket LST SE
- A-hooks-v4 — contracts/hooks/** (every hook DFPkg, not a sample)
- A-manager-fee-registry — manager, fee collector, fee oracle, vault registry
- A-routers-permit2 — contracts/routers/** + Permit2 witness paths
F2b if present and product-like:
- A-slipstream-buffer — Slipstream SE / buffer
- A-research-contracts — only deployable product-like contracts still under research/** with tests
- Any other contracts/** money DFPkg/facet/router found in inventory that no area owns

Inventory first: walk docs/agent/INDEXEDEX_CONTENT_INVENTORY.md + contracts/ tree. Every vault, DETF family, SE adapter, hook package, router, manager/fee/registry package must be assigned. If you find an orphan, create an area rather than DEFER as “not launch.”

REQUIRED SPECIALISTS after area inventories exist (execute-plan §4.3; do not skip):
- S-spec-detf — spec-to-code vs family PRDs + docs/detf/* + INDEXEDEX_AGENT_LAW DETF sections
- S-token-weird — FoT, rebase, 6/8 decimals, missing return, blacklist/pause
- S-amm-oracle-flash — defi-amm / oracles / flashloans / B / L / N
- S-diamond-proxy — catalog J, storage slots, initializer, leftover diamondCut
- S-signatures — Permit2 / EIP-712 / O / I5
- S-incidents — defi-incident-patterns map (reference only; no HackLabs remappings)
- S-evm-general — general + precision-math + dos
Reuse S-sharp-edges and S-crops-trust; extend them with a short addendum if full-pass areas add material Highs, or fold those Highs into the new specialist/area reports.

F4 — ADVERSARIAL MODELER:
For EVERY remaining Critical or High CODE finding that is NOT OWNED_ELSEWHERE, spawn differential-review:adversarial-modeler (or equivalent) with execute-plan §4.4. Append concrete attack steps + blast radius. No mainnet exploit scripts.

HARD RULES:
1. Writes only docs/security/audit/**.
2. Catalog SoT: Crane A–K + A0/L/M/N/O + E6/F5. EVM-audit domains are hunt lists.
3. Pattern hunt mandatory (PRD §2.4) on every area.
4. Finding class: CODE | TEST | THEATER | DEFER | NEEDS_OWNER | ACCEPTED_RISK | OWNED_ELSEWHERE.
5. Severity: Critical|High|Medium|Low|Info. No “Blocker.”
6. Same production touch-set as TCA-* / WP-I-* → OWNED_ELSEWHERE; link IDs; no competing sec_fix_*.
7. Critical CODE requires runtime proof (L-SEC-3). If forge is slow, wait. If BUILD_BLOCKED, max High + RUNTIME_UNPROVEN.
8. Fork: foundry.toml *_alchemy + ALCHEMY_KEY; FOUNDRY_PROFILE=fork. DualLiquidity missing fork P0 = High/Critical, not Medium.
9. J bar = Target ⊆ facetFuncs ⊆ cuts ⊆ loupe ⊆ PROXY call.
10. Pass = exploit blocked (or ACCEPTED_RISK with invariants).

DONE only when PRD §12 is checked AND all of the following exist and are non-empty:
- Updated 00_SCOPE_PARTITION.md covering every in-scope product
- Area report for every required F1/F2 (and F2b if applicable) with §7.2 headings 1–11 and Status COMPLETE or PARTIAL with a remaining-inventory list that is empty of unnamed money products
- Specialist reports for every F3 ID with §7.4 headings 1–6
- Adversarial-modeler notes for every remaining Critical/High CODE
- FULL AGGREGATE.md with all 12 items in PRD §7.5 (not the thin pilot)
- WORK_PACKAGE_BACKLOG.md with full §8 fields for every Critical/High this program owns, finding→WP index, OWNED_ELSEWHERE table, parallelism graph
- Runtime evidence under repro/ for any new Critical, plus SHA check of SEC-COMMON-001 if HEAD ≠ the SHA in that folder

Then STOP. Point at docs/security/PROMPT_SECURITY_AUDIT_REMEDIATION_PRD.md for Stage 2. Do not write the remediation PRD. Do not start remediations.
```

---

## What “full” means (do not weaken)

| In scope | Out of scope |
|----------|----------------|
| Every money-moving vault, DETF family, SE package, hook DFPkg, production router, manager, fee oracle, fee collector, vault registry under `contracts/` | `frontend/**` except CROPS Info if it does not gate onchain exit |
| Shared pull/credit/commons that those products inherit | Pure vendored `lib/**` except Crane patterns and IndexedEx call sites |
| Family PRD / `docs/detf/*` vs code (`S-spec-detf`) | Implementing fixes, `sec_fix_*` worktrees, Stage 2 PRD |
| Optional: Slipstream / leftover `research/**` product-like contracts | Compiling `lib/DeFiHackLabs`; `via_ir`; killing forge |

Pilot already covered commons pull, MultiVault, Aero/Camelot/Uni V2 SE, sharp-edges, CROPS. **Include those products in the full matrices.** Do not re-hunt them unless inventory finds a hole.

## Suggested spawn order

1. Update `00_SCOPE_PARTITION.md` (full tables + orphan scan).
2. Archive thin `AGGREGATE.md` / `WORK_PACKAGE_BACKLOG.md` under `archive/{RUN_DATE}/`.
3. Wave F1 (3 DETF areas) in parallel.
4. Wave F2 (split SE/hooks/manager/routers) in parallel.
5. Wave F3 specialists in parallel (they read area reports).
6. Wave F4 adversarial-modeler per leftover Critical/High CODE.
7. Merge, dedupe, write **full** aggregate + backlog.
8. Stop.

## QA the agent must apply

Area reports: execute-plan §5.1. Specialist reports: §5.2. Aggregate: §7.1 / PRD §7.5. Backlog: every Critical/High §8 fields + `sec_fix_` worktree + coverage-audit collision column.
