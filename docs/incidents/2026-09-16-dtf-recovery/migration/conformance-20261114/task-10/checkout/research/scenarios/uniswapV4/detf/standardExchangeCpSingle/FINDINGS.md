# Uni V4 Single SE CP DETF Research — Findings (partial)

**Campaign:** `uniswapV4/detf/standardExchangeCpSingle`  
**Date:** 2026-08-06  
**Profile:** `FOUNDRY_PROFILE=uv4_single_se_cp_detf` + `--via-ir`  
**Artifacts:** `research/out/uniswapV4/detf/standardExchangeCpSingle/`

## Headline (so far)

Hermetic **Uni V4 Single SE CP Buffer DETF** deploys **inert** under Policy with default mint/burn thresholds **1.05e18 / 0.95e18**; primary mint reverts while not live; **first bond with pairToken** takes the instance live and credits hook LP principal on the bond NFT.

## Results

| ID | Status | Finding |
|----|--------|---------|
| **D0_inert** | **PASS** | `isReserveLive=false`; `isMintingAllowed=false`; mintThreshold=1.05e18; burnThreshold=0.95e18; exchangeIn reverts (selector logged) |
| **D1_firstBond** | **PASS** | Bond 100e18 pair → live; tokenId=2; lp principal ≈ 99.95e18 |

## vs Balancer Single SE DETF

| Topic | Balancer Single SE (done) | Uni V4 CP DETF |
|-------|---------------------------|----------------|
| Reserve host | Weighted pool + BPT | SE Buffer CP Hook LP |
| SE attachment (research) | Uni V2 SE | ERC-4626 wrapper SE |
| Inert + defaults | PASS D0 | **PASS D0** (this host) |
| First bond → live | PASS D1 | **PASS D1** (hook LP principal) |
| Full D2–D9 | complete | **todo** |

## Reproduce

```bash
./research/run_uniswap_v4_cp_detf.sh --d0
FOUNDRY_PROFILE=uv4_single_se_cp_detf forge script \
  scripts/foundry/research/uniswapV4/detf/standardExchangeCpSingle/Script_D0_Inert.s.sol:Script_D0_Inert \
  -vv --via-ir
```

## Next

- Lock D1 first bond  
- D2–D9 gates / expansion / compound (mirror Single SE Phase 3)  
- Plots F1 lifecycle  
