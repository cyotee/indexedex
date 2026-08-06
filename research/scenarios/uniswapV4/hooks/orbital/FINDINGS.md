# Orbital Swap Hook Research — Findings

**Campaign:** `uniswapV4/hooks/orbital`  
**Date:** 2026-08-06  
**Profile:** `FOUNDRY_PROFILE=orbital` + `--via-ir`  
**Artifacts:** `research/out/uniswapV4/hooks/orbital/`

## Headline

Hermetic **Uniswap V4 Orbital Swap Hook** (3-asset sphere): production package path deploys with radius 0 until first LP; equal three-leg seed establishes radius; one-way exact-in demand moves door mid indices as expected; **preview == execution exact** on all six pair directions at 0.3% fee.

## Results

| ID | Status | Finding |
|----|--------|---------|
| **H0_smoke** | **PASS** | pre-seed radius=0; post-seed radius=5e21 wei-scale with 500 ether/leg; LP ~1.5e21 shares |
| **H1_demand_01** | **PASS** | Market buys t1 with t0 (1e18 × 24): midIndex01 **1.0 → ~0.909**; r0↑ r1↓; r2 flat; radius constant |
| **H1_demand_10** | **PASS** | Mirror: midIndex01 **1.0 → ~1.100**; opposite inventory path to H1_demand_01 |
| **H2_preview** | **PASS** | Six directions: previewOut == execOut exact (e.g. t0→t1 out ≈ 0.9968e18 on 1e18 in) |

## Mechanism notes

1. **Sphere:** Radius stays at seed level under pure swaps (inventory moves on the sphere surface).  
2. **Mid framing:** Research uses raw `r1/r0` indices (not USD). Opposite demand ⇒ opposite midIndex01.  
3. **Fees:** 0.3% dex fee; preview path is bit-exact with execution in hermetic suite (matches product Swap tests).  
4. **LP book:** Seed LP held passive; fee/inventory P&L panels still **todo** (H3).

## Reproduce

```bash
./research/run_uniswap_v4_orbital_hook.sh
# or:
FOUNDRY_PROFILE=orbital forge script \
  scripts/foundry/research/uniswapV4/hooks/orbital/Script_H0_Smoke.s.sol:Script_H0_Smoke -vv --via-ir
```

## Non-claims

- Not mainnet APY  
- Not DETF synthetic gates (see DETF campaigns)  
- mid ratios are reserve ratios, not dollar prices  

## Next

- H3 LP full-exit attribution  
- Fee vs inventory panel  
- SE Orbital buffer host research (composition layer)
