# Agent handoff — Uni V4 Hooks + DETF research portfolio

| Field | Value |
|-------|--------|
| **Written** | 2026-08-06 |
| **Repo** | IndexedEx monorepo |
| **Audience** | Implementation agents continuing Phase 1–2 |

## Read first

1. [`PROGRAM.md`](./PROGRAM.md) — ladder, layout, work order  
2. [`MATURITY.md`](./MATURITY.md) — research gates  
3. Existing playbook: [`research/RESEARCH_PLAYBOOK.md`](../../RESEARCH_PLAYBOOK.md)  
4. Peer DETF gold (do **not** re-run): [`../detf/singleSe/`](../detf/singleSe/)

## Locked decisions

| Topic | Decision |
|-------|----------|
| Production-first | CREATE3 + hook factory / registry; no mock SUT |
| Artifacts | `research/out/uniswapV4/...` only |
| Profiles | Product narrow profiles + **`--via-ir`** for research fixtures (stack-too-deep without IR) |
| Unicode in Solidity strings | **ASCII only** in `console2.log` / NOTES string.concat (Solidity rejects `→` etc.) |
| Weighted DETF | **Blocked** until package code |
| Numeraire | Hermetic 1:1 token units unless scenario pins spot |

## Done this session

| Item | Status |
|------|--------|
| Portfolio PROGRAM + MATURITY | done |
| Campaign PRDs (all scoped products) | done (Weighted DETF blocked stub) |
| Orbital fixture + H0/H1/H2 scripts | **PASS** |
| Orbital plots + FINDINGS | done |
| Uni V4 CP DETF fixture + D0 | **PASS** |
| Uni V4 CP DETF D1 | **PASS** (tokenId=2, LP principal ~99.95e18) |
| Runners | `run_uniswap_v4_orbital_hook.sh`, `run_uniswap_v4_cp_detf.sh` |

## Next agent work order

1. Confirm **D1 firstBond** green; update FINDINGS.  
2. Implement **D2–D9** for CP DETF (mirror Single SE Phase 3, host-specific synthetic drive via hook swaps).  
3. Scaffold **SE CP single hook** H0/S0/H1 (feeds DETF narrative).  
4. **SE Orbital** hook + **Orbital DETF** D0–D1 after CP path stable.  
5. Quad / Weighted AMM Mode H (copy Orbital fixture pattern).  
6. Do **not** start Weighted DETF research until package lands.

## Commands that work

```bash
# Orbital hook full H0-H2
./research/run_uniswap_v4_orbital_hook.sh

# Uni V4 CP DETF
./research/run_uniswap_v4_cp_detf.sh --d0
FOUNDRY_PROFILE=uv4_single_se_cp_detf forge script \
  scripts/foundry/research/uniswapV4/detf/standardExchangeCpSingle/Script_D1_FirstBond.s.sol:Script_D1_FirstBond \
  -vv --via-ir
```

## Compile notes

- `FOUNDRY_PROFILE=default` may fail on unrelated monorepo abstract contracts — use product profiles.  
- Research fixture inheritance needs **via-ir**.  
- First via-ir compile is slow (~10–25 min); subsequent script edits recompile 1 file much faster.
