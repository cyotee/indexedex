# Single SE DETF Phase 3 — FINDINGS

**Status:** complete (2026-07-30)  
**Harness:** Uni V2 WETH/USDC Standard Exchange + Single Standard Exchange DETF (hermetic, `FOUNDRY_PROFILE=default`)  
**Reproduce:** `./research/run_detf_single_se.sh` from repo root  

## Headline

A production Single SE DETF against hermetic Uni V2 SE deploys **inert**, goes **live** on first bond, gates mint/burn under **Policy** defaults (1.05 / 0.95), shows **exact** mint preview==execution after real market + inventory paths, keeps **Open** free of natural expansion, accrues **Policy expansion** when mint-rich + time, and **compounds protocol NFT rewards** into higher protocol BPT principal. No mainnet APY, peg guarantee, or claim-APY statements.

## Setup

| Item | Value |
|------|--------|
| DETF family | `contracts/vaults/detf/standardExchange/single/` |
| SE attachment | Uni V2 Standard Exchange (WETH/USDC hermetic) |
| Fixture | `scripts/foundry/research/detf/singleSe/ResearchFixture_DetfSingleSeUniV2.sol` |
| Thresholds | Policy defaults resolve mint=1.05e18, burn=0.95e18 |
| Expansion default | `expansionClosureRatePerSecond = 3170979198` (~10%/year premium closure) |
| Artifacts | `research/out/detf/singleSe/` |

## RQ1–RQ10

| RQ | Result | Evidence |
|----|--------|----------|
| **RQ1** inert until first bond | **PASS** | D0: `isReserveLive=false`; mint reverts `0xbb35752c`; post-warp still inert |
| **RQ2** first bond → live | **PASS** | D1: live after bond; reservePool set; supply ~505.2e18 |
| **RQ3** Policy mint gate | **PASS** | D2: post-bond synth ~0.625 (burn-side, not deadband); mint blocked. D3: mint after synth driven above mintThreshold |
| **RQ4** Policy burn gate | **PASS** | D4: synth ~0.646 < 0.95; burn succeeds; preview/exec within documented bound |
| **RQ5** synthetic via production markets | **PARTIAL** | Empirically **Uni trades alone cannot** clear mintThreshold from post-bond synth ~0.625 (bond free-DETF dilution ~189e18 free DETF). D3 opens mint via **production** free-DETF primary burns + Uni trades (no Open/deal). Supply 505.2e18→321.3e18 during drive; synth→1.068e18. |
| **RQ6** mint preview == exec | **PASS** | D3: preview=exec=`332354104227370659` (diff **0**) |
| **RQ7** Open no synth gates | **PASS** | D5: live Open mint+burn allowed independent of synth; routes execute |
| **RQ8** expansion Policy-only when rich | **PASS** | D0/D2/D5: no expansion when inert/not-rich/Open. D8: Policy supply 323531031889496482499 → 323533269971346029699 after 12h warp+touch |
| **RQ9** bond ledger vs free holders | **PASS** | D7: bob free DETF balance unchanged across warp; alice has bond effective shares + reward path |
| **RQ10** protocol compound BPT ↑ | **PASS** | D9 Open + seigniorage mints: protocolBpt 191.44e18 → 192.30e18 via lazy compound on mint (no deal seed) |

## Per-scenario summary

| ID | Result | One-line |
|----|--------|----------|
| D0 | PASS | Inert Policy; defaults 1.05/0.95; mint blocked; warp inert |
| D1 | PASS | First bond → live; residual free SE on diamond 0 |
| D2 | PASS | Post-bond burn-side (synth~0.625); mint reverts; no expansion on warp |
| D3 | PASS | Prod free-DETF burns + Uni trades → mint-allowed; capital mint preview==exec exact |
| D4 | PASS | Burn when synth < burnTh; free DETF from bond mint-split; burn within dust bound |
| D5 | PASS | Open mint/burn live; supply/pending unchanged over 30d warp |
| D6 | PASS | Serial capital mints increase supply (not expansion) |
| D7 | PASS | Bonder reward path ≠ free-holder expansion airdrop |
| D8 | PASS | Policy expansion on rich+warp; Open twin no expansion |
| D9 | PASS | `compoundProtocolRewards` raises protocol NFT BPT principal |

## Figure index

| Fig | Path |
|-----|------|
| F1 | `research/out/detf/singleSe/figures/F1_lifecycle.png` |
| F2 | `research/out/detf/singleSe/figures/F2_synthetic_thresholds.png` |
| F3 | `research/out/detf/singleSe/figures/F3_demand_to_synthetic.png` |
| F4 | `research/out/detf/singleSe/figures/F4_preview_vs_execution.png` |
| F7 | `research/out/detf/singleSe/figures/F7_bond_vs_mint.png` |
| F8 | `research/out/detf/singleSe/figures/F8_expansion_policy_vs_open.png` |
| F9 | `research/out/detf/singleSe/figures/F9_protocol_compound.png` |

F5–F6 are SE rateProviderCompare figures (cite prior campaign; not re-run here).

## Expansion vs capital seigniorage

| Path | What it is | Where |
|------|------------|--------|
| **Capital seigniorage** | External SE shares → mint DETF (fee + inventory split) | D3, D6 primary mints |
| **Natural expansion** | Free DETF into bond reward ledger when Policy + live + mint-rich + time | D8 (supply +2.24e15 over 12h at default rate) |
| **Open** | Never expands | D5, D8 Open twin |

## Protocol compound

- Metric: `bondNftVault.originalSharesOf(detfNFTId)`  
- D9: Open DETF + 20% seigniorage; protocolBpt rises on each seigniorage mint (lazy compound) from 191.44e18 baseline to 192.30e18  
- Reward source: production seigniorage inventory only (**no deal seed**)  
- Single-sided DETF join skew accepted (product v1)  

## Caveats / non-claims

- Hermetic research only — **not** mainnet APY, TVL, or yield marketing numbers  
- **No peg guarantee** advertised for Open instances  
- **No claim token APY** measured  
- D4 free DETF comes from product bond mint-split (or capital mint after production drive); **no deal seed**  
- Burn preview/exec on large SE-share units: absolute multi-wei dust allowed with relative ≤1e-6 bound (documented)  
- RQ5 PARTIAL: Uni-trades-alone insufficient post-bond; production free-DETF burns are required co-path (see D3 NOTES)
- Synthetic drive never uses Open thresholds or deal-seed DETF

## Reproduce

```bash
# Full campaign (forge D0–D9 + stamp + plots)
./research/run_detf_single_se.sh

# Single scenario
./research/run_detf_single_se.sh --d3
./research/run_detf_single_se.sh --plot-only
```

Git commit at stamp: see each `meta.json` (`gitCommitShort`).
