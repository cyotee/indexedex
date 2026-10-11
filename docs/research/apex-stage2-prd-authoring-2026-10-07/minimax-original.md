# MiniMax M3 — Stage 2 PRD authoring, original recommendations

**Sources:** `REMEDIATION_PRD.md` (R), `REMEDIATION_PRD.plan.md` (P), `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md` (A), `CLAUDE.md`. No peer artifacts read. Self-contained original.

## 1. PRD structure (proposed)

The Stage-2 review/report PRD at `docs/plans/APEX_STAGE2_REVIEW_PRD.md` should follow the Stage-1 artifact layout with these sections: Required outcome, Inputs, Inspection authority and threat-model bar, Coverage lanes, Evidence and disposition schemas, Acceptance gates, Non-goals, Pitfalls, Owner sign-off format. The PRD's purpose is review-only orchestration, not implementation; remediation is a separately requested downstream PRD.

## 2. Coverage lanes (proposed partitioning)

Lanes partition the post-Stage-1 source snapshot into independently reviewable surfaces. Real concurrency is a future requirement; lanes are defined now so a future capable coordinator can fan them out in parallel without changing lane boundaries.

| Lane | Surface | Source anchors | Catalog scope |
|---|---|---|---|
| **L1 Vault — V3 FullSpread** | `contracts/vaults/standard/exchange/protocols/uniswap/release/v3/` | R:139-141, A:D20 | E6, CROPS, I1-I3, J1-J3, K1 |
| **L2 Vault — V4 FullSpread hookless** | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/` | R:139, A:D3 | same |
| **L3 Vault — V4 FullSpread Pons-family** | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamily/` | R:139, A:D3 | same |
| **L4 Vault — Wings** | `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/` | R:140, OD-04, A:D16 | same + D15 refund rule |
| **L5 Hooks (7 D16 families)** | `contracts/hooks/uniswap/v4/standardExchange/{orbital,weighted,stable/quad/curve,stable/quad/balancer,single,dual}/` | A:D16, D20, D26 | D25, R10, R14 |
| **L6 Matrix — hook × SE × V3/V4** | full hook × SE Cartesian per A:D20 | A:D26 | D25, R10, R14 |
| **L7 SE families (non-Uniswap)** | D16 SE list excluding FullSpread (ERC-4626, Morpho, RebasingAware custody SY/SE, V2, Camelot, Aerodrome, Slipstream, Lido, Rocket, EtherFi, Aave Stata, Aave Cross-Version Loop, Balancer V3) | A:D16, D34 | I/J/K, A0, L1/L3 |
| **L8 DETFs** | Uniswap V4 DETF, Single SE DETF, MultiVaultWeighted, MixedBuffer, Composed/Rebasing, `IDetf.mintWithRateAsset`, `bond(..., prepaid)`, `RebasingDETFTokenTarget.redeem`, `StakedDETFTarget.exchangeIn/Out`, D34/D37 catch sites | A:D16, D27, D37 | A0/E6, FH1-4, K1, L/M/N/O as surface applies |
| **L9 Rate providers** | `StandardExchangeRateProviderDFPkg` / `Facet` and `WrappedStandardExchangeRateProviderDFPkg` / `Facet` (D48 staticcall rewrite only) | A:D16, D41/D48 | — |
| **L10 Custody + pretransfer guards** | `RebasingAwareStandardYieldTarget` EOA guard, `LocalCreditLib` consumers, D16 pretransfer entries | R:226, A:D9/D11/D15/D28 | I1-I3 |
| **L11 Adapter / receipt ERC-4626** | `ReceiptBackedERC4626Target`, `ReceiptBackedERC4626AccountingLib`, the shared adapter facet (D13 is one shared IndexedEx adapter per A:thirteenth review) | R:280, A:D16 | D45 dispatch |
| **L12 Audit-item ledger** | APEX-2026-001-M, -001-M2, -003, -008, -009, -004B, -005, `beforeSwap` retraction, weighted dust retraction, plus R-IDs R3–R14 | R:348-360, A:69-79 | — |

Twelve lanes. Each lane reports a **per-lane ledger** (item ID, file:line, severity, disposition) and an **inspection note** (file hashes inspected, dirty-file identity recorded per P:96).

## 3. Evidence schema (per finding)

```text
{
  "lane": "L<N>",
  "criterion_id": "D<n>|<R<n.n>|<finding-ID>|catalog-<A0-L>/<L/M/N/O>",
  "file_path": "contracts/.../Foo.sol",
  "line_range": "<start-end>",
  "broken_invariant": "<cite locked D/R>",
  "intended_behavior": "<one sentence from PRD or skill>",
  "observed_in_source": "<what the inspector found>",
  "disposition": "confirmed|refuted|unverified|residual|accepted",
  "severity": "Critical|High|Medium|Low|Informational",
  "confidence": "high|medium|low",
  "evidence_paths": ["test/...", "docs/audits/..."],
  "fix_direction": "<prose only; no executable code>",
  "needs_runtime_evidence": false,
  "blocked_by_runtime_evidence_only": false
```

Output drafts **less than full schemas**. JSON or YAML allowed; per-lane MD files acceptable. No PoC, payloads, or attack parameters (OD-07:2, A:D1).

## 4. Consolidated disposition schema

Each finding rolls up to one of: **confirmed defect** (Medium+ with verified cite → remediation PRD candidate), **refuted** (source matches locked property; cite proves it), **unverified** (execution claim not reproducible from source alone → readiness blocker, not defect), **accepted residual** (D12 / D57 / immutable 4663 instances — cite OD/PRD line), **out of Stage-2 scope** (Crane NatSpec dirty edit, `supportsInterface`, wings↔Pons binding, hookless+Pons merge; cite P:118-123).

## 5. Acceptance gates

A Stage-2 review closes (not "approves audit") when:
1. **All 12 lanes reported.** Missing lane = readiness blocker, not defect.
2. **All R-IDs R3–R14 dispositioned.** Undispositioned = readiness blocker.
3. **All 108 criteria mapped** to a current R-group or catalog class; missing mapping = readiness blocker.
4. **Per-finding evidence schema complete** for confirmed defects and refutations.
5. **Dirty-file identity recorded** for the inspected snapshot (P:96).
6. **No fix, no test, no deploy** authored. Confirmed defects trigger a separate, owner-requested remediation PRD.
7. **Unverified items enumerated** with the specific execution claim (matrix recount, 34,909/33/37 follow-up, fork inventory, EtherFi/Lido/Rocket prechecks, D16 pretransfer inventory, Balancer D68/D69 transition quotes — R:336-346). These block readiness without being defects.
8. **All severities reported** including Informational/Low; no filtering.

## 6. Pitfalls

- **Silent concurrency fallback.** Today's synchronous council must not become the default future coordinator. The PRD must name real concurrency as a future requirement (P:6, R:160).
- **Silent evidence carryover.** Stage-1 evidence used only where provenance and coverage match the current snapshot (P:96). Changed file = impact review, not reuse.
- **Confusion of evidence gap with defect.** Per R:22 ("claims, not proof") and R:336-346, missing execution = unverified, not a code defect. Readiness blocker ≠ remediation trigger.
- **Catalog scope drift.** Catalog A–K + A0/L/M/N/O is the ceiling, not the floor (`indexedex-adversarial-testing/SKILL.md:146-174`).
- **Open follow-on rulings.** `supportsInterface` probe (R:194), wings↔Pons binding (R:153), TokenStakingTarget:452 silent try (R:333) — each stays an open item, not a Stage-2 conclusion.
- **Severity filtering.** All severities reported; Informational findings are not dropped.
- **Owner sign-off format.** The PRD must define one (e.g., a new OD-09 entry recording review completion, blockers, and remediation-PRD request).
- **Doc roots.** Future review writes to `docs/reviews/`; this drafting session writes to `docs/plans/` per owner path. PRD must distinguish them.

## 7. Non-goals (carried from Stage 1)

Deployment, migration, registry disablement, broadcasts; merging hookless+Pons; wings↔Pons binding; `supportsInterface` ruling; old stored-total reconstruction; live chain-4663 remediation; D12 removal; Slipstream rewrite; test execution, test authoring, code edits in Stage 2 (R:362-369, P:29-44, this PRD).

## Confidence

High on lanes 1–6; medium on lanes 7–12 (depend on owner scope confirmation); high on schema/gates/non-goals.