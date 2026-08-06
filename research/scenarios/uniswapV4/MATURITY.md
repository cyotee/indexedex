# Uni V4 Hooks + DETF — Research Maturity Matrix

**Updated:** 2026-08-06  
**Rule:** Research scripts only for rows with **Research gate = open**. Blocked rows keep PRD/plan stubs only.

| Product | Code | TestBase | Hermetic specs | Fork specs | Product PRD | Research gate | Notes |
|---------|------|----------|----------------|------------|-------------|---------------|-------|
| Orbital Swap Hook | yes | `contracts/…/orbital/TestBase_*` | ~10 | Base/Eth/Robinhood | v1.15 | **open** | Sphere LP; three pair doors |
| Quad Stable Swap Hook | yes | `contracts/…/stable/quad/TestBase_*` | ~9 | Base/Robinhood | draft v0.6 | **open** | 4-asset stable |
| Weighted Swap Hook | yes | `contracts/…/weighted/TestBase_*` | ~12 | Base/Robinhood | draft v0.2 | **open** | Monomorph CREATE2 factory (not DFPkg diamond yet) |
| SE Buffer CP Single | yes | co-located TestBase | ~7 | Base/Robinhood | draft v1.3 | **open** | ERC-4626 wrapper SE in TestBase |
| SE Orbital Buffer | yes | co-located TestBase | ~14 | Base/Eth/Robinhood | draft v0.5 | **open** | via_ir profile |
| SE Weighted Buffer | yes | TestBase under `test/…/weighted/` | suite present | Base/Robinhood | plan+PRD | **partial** | Prefer promote TestBase to contracts/ before long campaign |
| Uni V4 CP Single DETF | yes | co-located TestBase | ~9 (deploy→claim) | Base fork | draft v0.5 | **open** | First full DETF research target on V4 |
| Uni V4 Orbital DETF | yes | co-located TestBase | ~8 | — | draft v0.6 | **open** | Mature-only sell→claim law first adopter |
| Uni V4 Weighted DETF | **PRD only** | none | none | none | draft v0.4 | **blocked** | Wait for package + TestBase |

## Research priority (Phase 1–2)

1. Orbital AMM hook (simplest multi-asset demand story)  
2. SE CP single + Uni V4 CP DETF (hook + DETF stack, ERC-4626 SE)  
3. SE Orbital + Orbital DETF (sphere host + true DETF)  
4. Quad + Weighted AMM hooks (curve variants)  
5. SE Weighted buffer (partial)  
6. Weighted DETF (blocked)

## Foundry profiles

See [`PROGRAM.md`](./PROGRAM.md) §5. Prefer the product’s dedicated profile for compile isolation.
