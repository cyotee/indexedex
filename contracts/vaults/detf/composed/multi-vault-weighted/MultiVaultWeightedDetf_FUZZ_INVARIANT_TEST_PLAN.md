# MultiVaultWeightedDetf — fuzz & invariant test plan

**Status:** IMPLEMENTED (L1 + L3 P0)  
**Date:** 2026-07-16  
**Parent:** `docs/testing/FUZZ_INVARIANT_COVERAGE_IMPLEMENTATION_PLAN.md` Wave 1A

## Scope

| Level | Path | Status |
|-------|------|--------|
| L1 | `test/.../multi-vault-weighted/fuzz/` | P0 |
| L3 | `test/.../multi-vault-weighted/invariant/` | P0 |

## P0 properties

| ID | Where |
|----|--------|
| P-CONS | L1 mint/partial burn |
| P-NODILUTE | L1 holder balance |
| P-BOUND | L1 zero/extreme |
| P-PRORATA | L3 aggregate claims |
| P-RESID | L3 residual inventory |
| P-GHOST | L3 ghost counters monotonic |
| P-NOFREE | L3 fee-aware soft (ghost assets) |

## Deferred

| Item | Reason |
|------|--------|
| Bond/claim random selectors | High revert rate under open thresholds; adversarial covers D-class |
| Nightly high runs/depth | Wave 4 |
| Multi-leg N>1 Handler | Start N=1 hermetic; N>1 later |

## Config

```text
invariant.runs = 24
invariant.depth = 10
fuzz.runs = 64 (default project)
```
