# SeigniorageDETF — Threshold Modes **Out** (Wave 4 / F7)

**Date:** 2026-07-28  
**Decision:** **Formal Out** of `DETF_Threshold_Modes` implement scope  
**Tracker:** `contracts/vaults/detf/DETF_Threshold_Modes_PROGRESS.md` (P6 F7)  
**PRD:** `contracts/vaults/detf/DETF_Threshold_Modes_PRD.md` §7 F7

## Decision

Do **not** wire `ThresholdMode { Policy, Open }`, `mintThreshold` / `burnThreshold`, or `DETFThresholdPolicy` gates into `contracts/vaults/seigniorage/`. Leave peg-regime code as-is. No half-migration.

This is **not** a delete/abandon of the package tree. Historical deploy scripts, tests, and demo tokenlists may remain. The package is **out of product-law Policy/Open shipping** under the threshold-modes PRD.

## Audit evidence (2026-07-28)

| Question | Finding | Paths / notes |
|----------|---------|----------------|
| **True DETF?** | **Yes (distinct chassis)** — diamond is ERC-20 share; mint/burn vs Balancer V3 80/20 reserve with self-leg; diluted price + sRBT underwriting | `SeigniorageDETFDFPkg.sol`, `SeigniorageDETFCommon.sol`, `SeigniorageDETFExchangeInTarget.sol` / `Out` |
| **Gate price today** | **Diluted / peg-regime**, not Policy deadband. Mint when `_isAbovePeg` (`dilutedPrice > 1e18`); burn when `_isBelowPeg` (`<= 1e18`). Errors `PriceBelowPeg` / `PriceAbovePeg` | Common `_calcDilutedPrice`, ExchangeIn/Out gate branches |
| **Thresholds / mode storage** | **None** — no `mintThreshold`, `burnThreshold`, or `thresholdMode` in Repo or `PkgArgs` | `SeigniorageDETFRepo.Storage`; `ISeigniorageDETFDFPkg.PkgArgs` (name/symbol/reserveVault/rateTarget only) |
| **Deploy / tests** | Scripts + hermetic/fork/adversarial tests exist; Sepolia artifacts present | `scripts/foundry/anvil_*/Script_15_DeploySeigniorageDETFS.s.sol`; `test/foundry/spec/protocol/vaults/seigniorage/**`; `test/foundry/fork/base_main/seigniorage/**`; `deployments/public_sepolia/**/15_seigniorage_detfs.json` |
| **Modern launch path** | **Not** on `anvil_single` local product path (fragments: `protocolDetf`, strategy only) | `deployments/local_testing/anvil_single/fragments/vaults/` |
| **Frontend** | Earn filter + tokenlist artifacts; comment marks seigniorage list as **legacy artifact** path | `frontend/app/lib/tokenlists.ts` (“not yet migrated… legacy artifact”); `frontend/app/seigniorage/page.tsx` → `/earn?type=seigniorage-detf` |
| **Migration program stance** | Explicit **out of scope / reference only** for DETF family consolidation | `docs/DETF_CONSOLIDATION_IMPLEMENTATION_PLAN.md` (Seigniorage reference only; do not pull into migration) |
| **Interface lineage** | `ISeigniorageDETF` — **not** `IProtocolDETF` | Separate surface from F5/F6 Protocol DETF |

## Why Out (not Parity)

1. **Different gate product:** peg always-one-side-open (mint above / burn at-or-below 1e18) is not the Policy ±5% deadband + Open short-circuit product law. “Parity” would be an economic redesign, not a trailing `PkgArgs.thresholdMode` wire-up.
2. **No threshold storage to extend** — full mode stack (resolve/validate, event, info, Open suites) would be greenfield on this chassis.
3. **Program already parked migration:** consolidation marks Seigniorage **reference only / out of active migration**.
4. **Modern DETF shipping** is F1–F5 under `contracts/vaults/detf/**` + Protocol DETF surface (F6). Seigniorage is parallel legacy demo chassis.
5. Half-wiring mode storage without full Open/Policy tests is **forbidden** by the threshold-modes program.

## What remains in force for this package

- Existing peg gates (`PriceAbovePeg` / `PriceBelowPeg`) and diluted-price math.
- Underwrite / sRBT / NFT vault lifecycle as currently implemented.
- Spec + fork + adversarial suites as currently owned (no P6 requirement to re-run for Out DoD).

## If product later wants Policy/Open on Seigniorage

Treat as a **new PRD revision** (or dedicated family plan): define how peg-regime routes interact with deadband/Open, then full Parity + production-first tests. Do not silent-migrate under this Wave 4 Out.
