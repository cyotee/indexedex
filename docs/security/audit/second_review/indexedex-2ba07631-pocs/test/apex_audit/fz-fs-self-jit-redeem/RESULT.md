# fz-fs-self-jit-redeem: DUPLICATE of fs-maintenance-at-spot-jit (the claim "no blocked mode needed" is refuted by execution)

Files:
- `SelfJitRedeem.t.sol`
- `SJHandler.sol` / `SJBase.sol`: copies of the p4-fs harness, renamed to avoid name collisions. The acting actor restores the pool to P0 at its own cost after every action, and all values are taken at P0 = 1.

Runner: `forge test .../fz-fs-self-jit-redeem/SelfJitRedeem.t.sol -vv --match-test test_sj_`. 5 invocations, all suites PASS.

## Fixture
- Hookless V4 FullSpread, 20% sleeve.
- Bootstrap LP holds 1000/1000. Three honest holders and the attacker (actor 3) each hold 400e18 shares from fair dual deposits made before the attack.
- A keeper rebalance leaves the vault in its normal state: 300/300 free, 1500/1500 deployed.
- Variants:
  - 0.30% tier, external L = 1000e18
  - 0.05% tier, external L = 1000e18
  - 0.05% tier, external L = 10000e18 ("Deep")

## Results
### A. Clean state, no blocked-mode op (the claimed trigger)
Test `test_sj_grid_clean`: the attacker optionally makes an extra fair deposit (0 / 400 / 1000 / 2000e18), redeems ALL its shares single-sided (to t0 or t1), then restores P0.

The vault's own redemption swap does move the spot a lot, and the best-effort rebalance runs right after it. Even so, in **every one of the 24 single-sided configs the attacker loses** (−0.35e18 to −8.5e18) **and LP0 and the honest holders gain**. NAV/share rises, e.g. 2.0000 to 2.0043. The dual-exit control gives −1 wei.

`test_sj_grid_afterBlockedDual` makes an honest actor 0 do the blocked dual deposit instead. There the attacker also loses in every config on the 0.30% and Deep fixtures (0.05% rows were truncated in the log).

### B. Profit appears only with blocked-mode two-sided idle excess (`test_sj_attackerBlockedPrefix`, `test_sj_assert_needsBlockedExcess`)
Steps: the attacker makes a blocked (in-session, at P0) dual deposit of about nav/5. That path skips `_rebalanceLiquidReserveBestEffort` and emits `LocalDepositWhileBlocked`. The attacker then makes an idle single-sided redeem of all its shares and restores. Values are attacker net / LP0 / honest:

| tier | with blocked prefix | without prefix |
|---|---|---|
| 0.05%, ext L 1000 | +5.91e18 / −3.85e18 / −2.31e18 | −0.67e18 / +0.37e18 |
| 0.30%, ext L 1000 | +3.34e18 / −2.98e18 / −1.79e18 | −1.71e18 / +0.76e18 |
| 0.05%, ext L 10000 (vault about 15% of L) | −1.89e18 (unprofitable) | −0.35e18 |

- With a 300e18 blocked prefix the result is marginal: +0.07 to +0.19e18 on 0.05%, negative on 0.30%.
- The profit falls as the blocked prefix shrinks, and is zero without it.
- The p4 counterexamples also contain blocked ops:
  - B is `b_depositDual(1003, …)`, a blocked dual deposit by actor 3, then `h_syRedeem`. Reproduced here at +4.35e18 / −2.84e18.
  - A is preceded by `b_exitDual` / `b_redeem` / `b_mint` and a full undeploy.

## Why this is a duplicate
`fs-maintenance-at-spot-jit` (p2 title: "...place liquidity at a manipulated price (JIT-IL), **including right after the caller's own unbounded direct swap**"). The p3 confirmed form (probe-maintenance-jit B) is: a blocked-mode two-sided deposit leaves idle excess; the next maintenance mints that excess at the current displaced spot; a swap back to P0 captures the IL.

Self-JIT is the same root cause, with the same location and the same fix:
- Root cause: maintenance places liquidity at an unvalidated spot after blocked-mode excess.
- Location: `_rebalanceLiquidReserveInternal` / `_executePlacement`, called from `_executeFreeZapOutExactIn` → `_rebalanceLiquidReserveBestEffort`.
- Fix: a TWAP/deviation guard on placement, or gate deployment of blocked-mode excess.

The only difference is the displacement leg: the vault's own unbounded redemption swap instead of an external flash push. The p2 title already anticipates that ("caller's own unbounded swap").

Without blocked-mode excess the vault's own displacement is unprofitable and benefits the LPs, so this is not an independent root cause. The "no effective impact cap" on the redemption swap is the already-reviewed fs-user-slippage behaviour (the user is bounded by minAmountOut). It is not by itself a source of LP loss: the A-grid shows LPs gain.

The new information worth adding to fs-maintenance-at-spot-jit:
- It is executed on V4 hookless, which p3 had listed as not executed.
- No external flash capital is needed: the attacker's own single-sided redeem supplies the displacement.
- Magnitude: about 0.1-0.16% of NAV per round on shallow pools; unprofitable once the vault is about 15% or less of in-range L.
