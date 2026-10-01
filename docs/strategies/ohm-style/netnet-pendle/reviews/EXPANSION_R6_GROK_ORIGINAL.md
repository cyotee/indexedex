# EXPANSION_R6 Grok original — Universal V4 expansion vs NetNet family

| Field | Value |
| --- | --- |
| Researcher | Grok |
| Routing | `xai/grok-4.6` — not provider attestation |
| Read | `DETFEpochNaturalExpansionLib.sol`; `UniswapV4DetfCommon.sol:175–380`; `UniswapV4DetfTarget.sol:275,545–595`; `UniswapV4DetfMaintenanceTarget.sol:16–28`; `UniswapV4DetfRepo.sol:98–181`; `UniswapV4DetfDFPkg.sol:246–265`; `DETFThresholdPolicy.sol:16–30`; `IDetfReserveQuote.sol`; Weighted `previewSynthetic` `:89–139`; `StakedDETFTarget.sol:170–183`; `DETF_ALIGNMENT_PRD.md` D31/D50/D52 §24.3.2; lib test (unread-run) `DETFEpochNaturalExpansionLib.t.sol`; PRD v0.15 `:26` |
| Peers | unread |
| Status | Research. Unauthorized. No live pins. |

**Selected now (do not fight):** opening **1000 NET/DETF**; expansion **eligible iff strictly > 1 NET/DETF** on **every processed NET epoch**. Prior **0.5%/epoch is not amount mechanics**. Discuss reuse vs modify. R43 staking custody stays.

## Universal V4 actual behavior

**Formula** (`DETFEpochNaturalExpansionLib.sol:33–46`, OZ `Math.mulDiv` **floor**):

```
if !live || now <= last → 0
if supply==0 || P <= 1e18 || P <= mintThreshold → 0   // equality ineligible
epochs = floor((now-last) / 8 hours); if 0 → 0
c = mulDiv(rateYearWad, 8 hours, 365 days)
per = mulDiv(supply, P-1e18, P)
per = mulDiv(per, c, 1e18)
mint = per * epochs; if mint <= 1 → 0
```

**Defaults:** `rateYearWad=0` → **0.10e18** (10%/year) (`:12,26–27`; DFPkg `:248`). `mintThreshold` 0 → **1.05e18** (`DETFThresholdPolicy:16,29`). DETF supply is **native 9-decimal** (`Common:315`).

**Gate:** must be **strictly above peg (1e18) and** mint threshold (`:35–37`; test `:74–82`). Open-mode mint gates do **not** skip this lib check.

**Price:** `_highestSyntheticPrice` (`Common:322–341`) = **max** `previewSynthetic` over **every non-DETF hook pair**, each with **its own `creationOfPair`**, same `ownedLp` and **current** supply (`pendingExpansion` field **0**). **Not NET-only.** Alignment `:991`.

**Synthetic mark** (Weighted `:134–139`):  
`pairWad = marked * ownedLp / lpSupply`; `mid = pairWad * 1e18 / (supplyWAD+pending)`; `P = mid * 1e18 / creationPairPerDetfWad`.  
**View inventory mark, not an executable swap.** `_quoteCtx` can inflate supply for **mint gates** (`:183`) while expansion itself uses uninflated supply (`:330`).

**Creation vs opening:** expansion uses **`creationOfPair`**, not `openingOfPair`. First-bond **opening** prices the initial G (`Target:588–595`). If opening=1000 NET/DETF and that value is **also stored as creation**, launch mark ≈ **1.0 WAD** → **no** expansion premium. A high opening **does not** invent a 1000× synthetic premium.

**Clock:** `EPOCH=8 hours`; `YEAR=365 days`. Anchor = **first successful bond** (`Repo._setReserveLive:174–180`; `Target:593–595` overwrites to `block.timestamp`). Inert: no mint (`Lib:34`; `_hasCompletedExpansionEpoch` needs live + ≥1 epoch `:367–369`). **Zero mint still advances** completed boundaries (`Lib:48–57`; test `:53–62`). **No historical compounding** (`mint = perEpoch * N` at **current** P/supply). **No catch-up caps** (D52; test 21× one-epoch `:44–50`). Remainder `<8h` kept.

**Triggers:** mint/bond/burn/redeem paths call `_realizeExpansionIfNeeded` **first** (D31; `Target:275,545`); `synchronizeRewards` (`Maintenance:16–28`) for staking/NFT children (locked callback no-ops). Donate does **not** realize (D31).

**Destination:** mint DETF to DETF, `fundRewards` → sDETF index + fee/creator receipts (`Common:372–379`; `StakedDETFTarget:170–183`). **No** extra `p * expansion` (alignment `:987`).

**Example** (test `_input`): supply `1000e9`, P=`2e18`, threshold `1.05e18`, rate `0.10e18`, 1 epoch:  
`c = floor(1e17 * 28800 / 31536000) = 91324200913242`  
`per = floor(floor(1000e9 * 1e18 / 2e18) * c / 1e18) = 45662100` (~0.0457 DETF). 25h → **3×** that, clock +24h.

## Reuse vs modify (NetNet)

| Piece | Reuse? |
| --- | --- |
| Floor premium-closure, dust, consume-zero-epochs, no compound, no D52 caps, fund sDETF | **Yes** (structure) |
| 8h first-bond clock | **No** — family is **processed NET epoch** (R08) |
| Gate `>1` **and** `>1.05` mintThreshold; **highest-of-legs** | **No** — owner: **strictly >1 NET/DETF only** |
| 10%/year default | **No** — 0.5%/epoch **not** selected as replacement |
| View synthetic / creation denominator | Reuse **idea**; numeraire = **NET**; set **creation=1000 NET/DETF** so open ≈ peg-in-creation-units, **not** vs R25’s 1 NET target |

**Do not** treat 1000 opening as expansion eligibility. **Do not** copy 8h catch-up onto NET epochs without mapping “processed epoch” ≠ elapsed time.

**Uncertainties:** custom Weighted `previewSynthetic` mapping for Pendle/YT/`C`/SE; NET 9 vs 18 decimals in `creationPairPerDetfWad`; live oracle rate vs PkgArgs 0→10%.
