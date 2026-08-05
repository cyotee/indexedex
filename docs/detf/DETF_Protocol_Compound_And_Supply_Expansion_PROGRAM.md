# DETF Protocol Compound + Natural Supply Expansion — Program Index

## Status

| Field | Value |
|-------|--------|
| **Product law** | [`DETF_Protocol_Compound_And_Supply_Expansion_PRD.md`](./DETF_Protocol_Compound_And_Supply_Expansion_PRD.md) — **LOCKED** (2026-07-30) |
| **Plans** | Stages 00–09 under `docs/detf/` (shared at root; family stages under mirrored `docs/detf/balancer/v3/<family-path>/`) |
| **Implementation** | Stages 00–09 green; AGENTS.md updated |

**Do not re-litigate product law in stage plans.** If conflict: PRD wins; open a PRD revision before changing law.

---

## How to run an agent on one stage

1. Give the agent **only one** stage plan path (absolute or repo-relative).
2. Instruct: read the plan fully, then the PRD sections it cites, then implement **that stage only**.
3. Do **not** start a stage whose **Depends on** stages are not green.
4. Stage **Definition of Done** must pass before the next stage.

Example goal prompt:

```text
Execute the implementation plan at:
docs/detf/00_DETF_Protocol_Compound_Shared_IMPLEMENTATION_AND_TEST_PLAN.md

Normative product law:
docs/detf/DETF_Protocol_Compound_And_Supply_Expansion_PRD.md

Implement only this stage. Do not start other stages. Production-first tests; no SUT mocks.
```

---

## Execution order (mandatory DAG)

```text
Stage 00  Shared Phase-1 foundation (core + bond NFT compound plumbing)
    │
    ├─► Stage 01  Single SE          Phase 1 (protocol compound)   [pathfinder]
    ├─► Stage 02  Multi-vault weighted Phase 1
    ├─► Stage 03  Mixed-buffer         Phase 1
    └─► Stage 04  Composed stable      Phase 1
              │
              │  (Stages 02–04 may run in parallel after Stage 00;
              │   prefer Stage 01 green first if shared APIs still settling)
              ▼
Stage 05  Shared Phase-2 foundation (premium-closure expansion lib)
    │
    ├─► Stage 06  Single SE          Phase 2 (natural expansion)   [pathfinder]
    ├─► Stage 07  Multi-vault weighted Phase 2
    ├─► Stage 08  Mixed-buffer         Phase 2
    └─► Stage 09  Composed stable      Phase 2
```

**Hard rules (PRD §7.2):**

- No family Phase 2 before **that family’s** Phase 1 is green.
- No Phase 2 before **Stage 05** is green.
- Stage 00 before any Phase 1 family stage.
- Pathfinder preference: **01 before 02–04**, **06 before 07–09** when shared surface may still change.

---

## Stage catalog

| Stage | Phase | Scope | Plan file |
|-------|-------|--------|-----------|
| **00** | Shared P1 | Core + bond NFT compound foundation | [`00_DETF_Protocol_Compound_Shared_IMPLEMENTATION_AND_TEST_PLAN.md`](./00_DETF_Protocol_Compound_Shared_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **01** | P1 | Single Standard Exchange | [`01_…`](./balancer/v3/standardExchange/single/01_SingleStandardExchangeDETF_Protocol_Compound_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **02** | P1 | Multi-vault weighted | [`02_…`](./balancer/v3/multi-vault-weighted/02_MultiVaultWeightedDetf_Protocol_Compound_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **03** | P1 | Mixed-buffer multi-vault stable | [`03_…`](./balancer/v3/mixedBuffer/03_MixedBufferMultiVaultStableDetf_Protocol_Compound_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **04** | P1 | Composed stable common | [`04_…`](./balancer/v3/stable/common/04_ComposedStableCommonDetf_Protocol_Compound_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **05** | Shared P2 | Expansion math + mint-on-update helpers | [`05_DETF_Natural_Expansion_Shared_IMPLEMENTATION_AND_TEST_PLAN.md`](./05_DETF_Natural_Expansion_Shared_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **06** | P2 | Single Standard Exchange | [`06_…`](./balancer/v3/standardExchange/single/06_SingleStandardExchangeDETF_Natural_Expansion_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **07** | P2 | Multi-vault weighted | [`07_…`](./balancer/v3/multi-vault-weighted/07_MultiVaultWeightedDetf_Natural_Expansion_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **08** | P2 | Mixed-buffer multi-vault stable | [`08_…`](./balancer/v3/mixedBuffer/08_MixedBufferMultiVaultStableDetf_Natural_Expansion_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **09** | P2 | Composed stable common | [`09_…`](./balancer/v3/stable/common/09_ComposedStableCommonDetf_Natural_Expansion_IMPLEMENTATION_AND_TEST_PLAN.md) |

---

## Out of scope (never assign as stages)

| Package | Reason |
|---------|--------|
| `composed/single` | Removal in progress |
| `contracts/vaults/seigniorage/` | PRD Out |
| `detf/dual/**` | PRD Out unless re-supported |

---

## Progress checklist

| Stage | Status | Notes |
|-------|--------|-------|
| 00 Shared P1 | green | `DETFProtocolCompoundLib` + pure tests; DETF-orchestrated compound law documented |
| 01 Single SE P1 | green | pathfinder — compound + C1–C8 tests; `_addToPosition` reward-debt fix |
| 02 Multi-vault P1 | green | compound + C1–C8 tests; `_joinReserveDetfOnly` DETF self-leg only |
| 03 Mixed-buffer P1 | green | compound + C1–C8 tests; reuse `_joinReserveDetfOnly`; lazy mint/bond/bootstrap/sell + public surface |
| 04 Composed stable P1 | green | `_tryCompoundProtocolRewards` / public compound; C1–C8 + non-waivable C5 |
| 05 Shared P2 | green | `DETFNaturalExpansionLib` + pure T5.1–T5.10; premium-closure + resolve defaults; no family wiring |
| 06 Single SE P2 | green | pathfinder — expansion mint-on-update + E1–E8; Phase 1 compound suite still green |
| 07 Multi-vault P2 | green | expansion mint-on-update + E1–E8; Phase 1 compound suite still green |
| 08 Mixed-buffer P2 | green | expansion mint-on-update + E1–E8; Phase 1 compound suite still green |
| 09 Composed stable P2 | green | expansion mint-on-update into bond-reward DETF + E1–E8; Phase 1 compound suite still green; claim-coupling E6 |
| AGENTS.md update | green | 2026-07-30 — common DETF expectations include protocol compound + Policy expansion |

---

## Product locks agents must not reopen

See PRD §0.4 / §12.1–12.2. Summary:

1. Protocol detf-owned NFT only auto-compounds (single-sided DETF join).
2. User + fee-recipient rewards stay claimable free DETF while locked.
3. Lazy hooks **+ required** `compoundProtocolRewards()` (or family-equivalent).
4. Join failure = **best-effort** (leave pending; do not fail whole user touch).
5. Expansion = **Policy only**, premium-closure, **mint-on-update into `rewardPerShares`**.
6. Deploy-time params only; no keeper; immutable instances.

---

## Testing law (all stages)

- Production-first: CREATE3 + FactoryService + manager vault registry for vault/DETF DFPkgs.
- **No mocks of SUT** (DETF, facets, DFPkg, manager, registry, fee oracle, attached SE under test).
- Gold TestBases: `CraneTest` → `IndexedexTest` → family `TestBase_*`.
- Preview == claim/execution where closed-form (document ≤ few-wei only if forced).

---

## Family note — Uni V4 Single SE CP buffer (epoch expansion first adopter)

| Field | Value |
|-------|--------|
| Package | `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/` |
| Epoch form | Shipped for this family via `DETFEpochNaturalExpansionLib` (whole-epoch catch-up, debt-inclusive synthetic, realize only on bond / claimRewards / compound). Shared PRD still describes continuous `dt` as default for Balancer families until a formal shared amendment. |
| Hermetic | `FOUNDRY_PROFILE=uv4_single_se_cp_detf` — Phases 0–6 product path green |
| Fork (Phase 6.1) | `FOUNDRY_PROFILE=uv4_single_se_cp_detf_fork` — Base lifecycle smoke green (`inert → first bond → mint`) |
| Product law | Co-located `UniswapV4SingleStandardExchangeDETF_PRD.md` (not LOCK-stamped by implementor) |
| Do not | Migrate all Balancer families to epoch form without shared PRD amendment; treat product LOCK as human product role |

---

## Document control

| Item | Value |
|------|--------|
| Created | 2026-07-29 |
| Related | Threshold Modes program (orthogonal; already shipped) |
| Next after all stages green | Mark PRD LOCKED if not already; update AGENTS.md common DETF expectations |
| 2026-08-05 | Uni V4 Single SE CP family pointer: epoch expansion + Base fork smoke (see section above) |
