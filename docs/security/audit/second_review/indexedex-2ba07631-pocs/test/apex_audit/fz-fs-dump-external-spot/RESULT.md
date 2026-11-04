# fz-fs-dump-external-spot: DUMP-AT-EXTERNAL-SPOT (p4-fs candidate)

**Verdict: refuted_by_execution (no attacker-profitable variant). Severity: info.**
- The redeem-sandwich part has the same root cause as `fs-user-slippage` (p2, refuted/info). The idle redemption swap has no internal price limit, and only the user's `minAmountOut` bounds it.
- The `rebalanceLiquidReserve` sub-variant (p4 `test_variant_forcedDump`, op 5) is `fs-maintenance-at-spot-jit` (p3, confirmed).

## Root-cause triage
- p4 `test_repro_ponsMovedRedeemNavDrop`: here the ATTACKER is the redeemer (a_movedIdleOp op 2). The attacker loses -32.15e18 and LP0 loses -1.32e18. That is self-funded griefing, not a sandwich.
- p4 `test_variant_forcedDump`: the positive attacker deltas (+0.17 / +0.35 / +3.7e18) come from op 5, the permissionless `rebalanceLiquidReserve` at a displaced spot. That is the confirmed `fs-maintenance-at-spot-jit` class (the impact bound is measured against the manipulated entry spot).
- What was left to test: sandwiching an HONEST single-sided idle redeem (`_executeFreeZapOutExactIn` -> `_swapRedemptionExactIn`, full-range price limit). This PoC does that.

## PoC
- Files: `FSDumpSandwich.t.sol` (hookless, 0.30% and 0.05% tiers) and `FSDumpSandwichPons.t.sol` (Pons V2 hook: 1% hook fee + 1% creator tax).
- Setup: external full-range LP of 1000e18 L; bootstrap LP0 = 1000/1000 (1000 shares); a second LP of 1000e18; an honest victim with 500e18 (250 of 1750 shares).
- Sequence, one tx each:
  1. Attacker front-runs by pushing sqrtP to P0*m/1000 in its own closed unlock.
  2. The victim calls `exchangeIn(vault, allShares, token0, minOut = preview*(1-slip))`.
  3. The attacker back-runs to P0.
- Measurement:
  - Sweep: m in {800..1200} and slip in {50, 100, 300 bps, none}.
  - Attacker PnL is taken at P0, net of the plain back-run arb it would earn anyway (baseline: same redeem with no front-run).
  - Victim loss is measured against the baseline output.
  - Remaining holders are measured by NAV/share at P0, against both the baseline and the pre-op level.
- Assertions (all PASS): whenever the attacker profits, (a) the victim loss is <= the victim's own minOut slack, and (b) the remaining holders' NAV/share is >= its pre-op level.

## Numbers (the audit runner, Suite result: ok, all 3 suites)
Baseline (no attack): the victim gets 474.39e18 (0.30% tier) for a fair 500e18. This is ordinary single-sided price impact on a shallow pool, borne by the redeemer. LP0 gains +1.04e18 against pre-op.

| tier | m | slip | sandwich PnL | victim extra loss | LP0 vs baseline | LP0 vs pre-op |
|---|---|---|---|---|---|---|
| 0.30% | 1002 | 50bps | +1.078 | 0.930 | -0.107 | +0.932 |
| 0.30% | 1010 | 50bps | REVERT (victim protected), attacker -0.15 | 0 | - | - |
| 0.30% | 1030 | 300bps | +13.17 | 13.54 | +0.13 | +1.17 |
| 0.30% | 1200 | none | +69.55 | 76.74 | +4.06 | +5.10 |
| 0.05% | 1200 | none | +75.65 | 76.89 | +0.71 | +1.32 |
| Pons | 1200 | none | +58.04 | 76.08 | +0.55 | +1.03 |
| 0.30% | 900 (anti) | any | -51.56 | -52.30 (victim gains) | -0.50 | +0.54 |
| Pons | 900 (anti) | any | -51.62 | -51.72 | -0.485 | -0.0015 |

(Values are e18; LP0 holds 1000 shares, about 2000e18 NAV.)

## Conclusion
- Profit comes only from the victim's own signed slippage. It is ordinary AMM sandwich MEV, capped by `minAmountOut`, and with a 50 bps minOut any front-run with m >= 1.01 makes the victim's tx revert.
- In the profitable direction, remaining holders never lose NAV/share against the pre-op level. The worst case is a 0.107e18 smaller gain than baseline (about 0.5 bp of LP0).
- The anti-direction "dump" that the p4 classifier flags is pure griefing. It costs the attacker about 100x the remaining-holder impact (51.6e18 spent, mostly transferred to the victim, for at most 0.5e18 less gain than baseline). The only absolute NAV/share loss was -0.0015e18 (Pons).
- Not a new finding.
