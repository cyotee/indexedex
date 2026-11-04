# detf-bond-spot-valuation — PoC result

Test: `DetfBondSpot.t.sol` (12 tests, all PASS on run 11)
Run: FOUNDRY_PROFILE=audit forge test --match-path .../test/apex_audit/detf-bond-spot/DetfBondSpot.t.sol -vv`

## Verdict
- **Constant-product reserve hook (`TestBase_UniswapV4Detf`, CP single-SE buffer hook, 0.3% fee): CONFIRMED.**
- **3-token weighted reserve hook (fixture 40/30/30 and live-like 60/20/20): NOT profitable.** Execution refutes the hypothesis for this family, which is what Robinhood 4663 runs.

## Mechanism (confirmed on CP)
`bond()` prices two things from the live pool book, with no TWAP, no cap and no min-out:
- `g`, from `previewExitProportional`
- the principal, from `previewExchangeIn`

It then joins `g` plus the pair with `minLp=0`. The attacker contract does the following in one tx:
1. Dumps DETF into the reserve pool, about 25% of the pool's DETF reserve.
2. Calls `bond(pair, B)`, which mints an inflated `g` and an inflated principal.
3. Binary-searches a pair→DETF buy-back until the hook's spot returns exactly to the pre-attack value.

The attacker gets its DETF inventory back plus extra, and holds an oversized bond NFT.

## Numbers (CP, 1000-pair reserve, B = 50 pair, sell 350 DETF ≈ 25% of pool DETF, 180d lock = live max 50% bonus)
| | honest bond, same B | sandwiched bond |
|---|---|---|
| principal (DETF 1e9) | 67.46 | 104.02 |
| spot-valued PnL (pair) | +17.17 | **+54.65** |
| realized PnL after lock, dumping everything (pair) | -5.88 | **+11.51** |
| victim (1028 DETF holder) realized loss (pair) | 14.73 | **29.60** |
| non-DETF backing per circulating DETF (pair) | 0.9591 | 0.9341 |

- 30d lock (0% bonus): spot PnL is -4.45 honest vs +21.59 sandwich. Realized: -19.1 vs -8.0, so there is excess over honest but no absolute realized profit.
- Smaller case (10% dump, B = 20, 180d): spot +7.7 vs +12.7; realized -1.64 vs +0.66.

## Weighted (refutation evidence)
Restoring all legs (spot PnL, all legs valued at the pre-attack prices):

| weights | honest | sandwich |
|---|---|---|
| 40/30/30 | +11.56 | +8.77 |
| 60/20/20 | +12.20 | +0.73 |

Restoring only the DETF/pair0 leg:

| weights | spot honest | spot sandwich | realized honest | realized sandwich |
|---|---|---|---|---|
| 40/30/30 | +11.56 | +12.63 | -6.7 | -13.6 |
| 60/20/20 | +12.20 | +4.96 | — | — |

In the 3-token weighted pool, the unbalanced 2-of-3 join and the third leg absorb the over-minted `g`. This matches the econ skeptic: the sandwich is roughly an honest bond of more capital, minus fees. In the weighted runs where the attacker restores the pair1 leg, ignore the "REALIZED" lines: they ignore the pair1 the attacker spent. Use the spot PnL instead.

## Preconditions and caveats
- The attacker needs DETF inventory of about 10–25% of the pool's DETF reserve. It is returned (with a surplus) in the same tx. No external flash source for DETF was used.
- The principal is locked for 30–180d (lock and price risk). The PoC realizes it after the lock with `vm.warp`, with no other market activity in between.
- `ownerOnlyLiquidity = true`, so the reserve-LP bond leg (H4) can't be reached and was not tested.
- Live 4663 (weighted 60/20/20) is not affected by this strategy. The affected deployments are V4 DETFs with a CP (single SE buffer) reserve hook (e.g. the `TestBase_UniswapV4Detf_Cp_*` configurations).

## Fix
- Price `g` and the principal from a manipulation-resistant reference: TWAP/oracle, or `previewSynthetic` with a deviation band versus spot.
- Add a `minPrincipal`/`maxPrice` parameter to `bond()` and a non-zero `minLp` on `_joinUnbalanced`.
- Optionally cap the per-tx bond size relative to the reserve.
