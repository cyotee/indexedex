# Agent research report — Single SE DETF Phase 3

**Audience:** agents and humans reusing results without re-running the full harness  
**Status:** **LOCKED** 2026-07-30  
**Do not re-run casually** — full D0–D9 takes significant forge time; plots are offline from JSONL  

## Pointers

| Need | Path |
|------|------|
| Findings (RQ1–RQ10) | [`FINDINGS.md`](./FINDINGS.md) |
| Campaign law | [`DETF_Research_PRD.md`](./DETF_Research_PRD.md) |
| Phase 3 PRD | [`DETF_Research_Phase3_PRD.md`](./DETF_Research_Phase3_PRD.md) |
| Implementation plan | [`DETF_Research_Phase3_IMPLEMENTATION_AND_TEST_PLAN.md`](./DETF_Research_Phase3_IMPLEMENTATION_AND_TEST_PLAN.md) |
| Artifacts | `research/out/detf/singleSe/D{0..9}_*/` + `figures/` |
| Runner | `./research/run_detf_single_se.sh` |
| Fixture | `scripts/foundry/research/detf/singleSe/ResearchFixture_DetfSingleSeUniV2.sol` |

## One-liners for agents

1. **Inert → live:** Policy DETF starts inert; first bond of Uni V2 SE shares sets live + reserve pool.  
2. **Policy gates:** defaults 1.05 / 0.95; post-bond hermetic synth often ~0.625 (burn-allowed); mint needs real Uni trades + inventory burn path under production rules.  
3. **Preview honesty:** closed-form mint preview == execution exact (D3).  
4. **Open:** mint/burn when live without synth gates; **never** natural expansion.  
5. **Expansion:** Policy + live + mint-rich + warp + touch → supply/reward ledger ↑; free unlocked DETF holders get no airdrop.  
6. **Compound:** `compoundProtocolRewards` increases protocol NFT BPT principal (`originalSharesOf(detfNFTId)`).  

## Non-claims (enforce in copy)

- No mainnet APY / peg / Olympus analogies  
- No claim-token yield marketing  
- Hermetic only  

## When to re-run

- Product PRD change to thresholds, expansion, or compound  
- Fixture SE attachment change  
- Otherwise: **read FINDINGS + series.jsonl**, do not re-execute matrices
