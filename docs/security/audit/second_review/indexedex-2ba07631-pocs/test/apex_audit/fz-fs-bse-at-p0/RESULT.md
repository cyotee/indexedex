# fz-fs-bse-at-p0: CONFIRMED, DISTINCT trigger (hookless V4 FullSpread). No price move, no pool swap, works at any pool depth.

Run: FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/fz-fs-bse-at-p0/FSBseAtP0.t.sol -vv`. 12/12 pass (6 shallow-pool tests, 6 deep-pool tests).

## Root cause
Blocked mode (the caller holds its own `PoolManager.unlock`) uses two different price models:
- **Blocked single-sided deposit**: `_executeZapInDeposit` else-branch (HooklessInBase ~l.305), then `StandardExchangeConstantProduct._sharesForDeposit`. This mints `S*(sqrt((B0+a)*B1)/sqrt(B0*B1) - 1)` over the total book `B = free + deployed (+fees)`. The implied price is the book composition `B1/B0`, not the market price. Nothing is swapped or rebalanced. The tokens stay as free sleeve, so the composition skew persists.
- **Blocked single-sided zap-out**: `_executeZapOutExactIn` blocked branch. This pays `_quoteZapOutAmount`, the pool-spot quote, which is about fair at P0. It pays only from the free sleeve, so `B0` drops while `B1` is unchanged.

So the first blocked op leaves an **unrebalanced, skewed free sleeve**. The book composition then implies a token0 price above fair (`B1/B0 > P`), and the next blocked single-sided deposit of the scarce token gets too many shares. Measured: after an honest blocked deposit of nav/10 token1, `B1/B0 = 1.2` while spot is still 1.0.

The loop below brings the book back to exactly the same free and deployed balances every round. Only `totalSupply` grows. Each round is pure dilution of the honest LPs.

## Distinct from fs-blocked-entry-spot-mint
- Same sink function, different trigger. spot-mint skews the book by moving slot0, which shifts the deployed composition. Here the skew comes from the vault's own blocked-op accounting. slot0 is never touched, and the test asserts `sqrtP` is unchanged inside the unlock.
- A spot-vs-TWAP deviation gate or an impact gate (spot-mint fix option 2) does not catch it: spot equals TWAP equals P0 throughout.
- Different preconditions. spot-mint needs the vault to hold at least 3-4% of pool liquidity and loses 21,700 bps at the default fixture depth. This variant pays no pool swap fees. It is **more** profitable in a deep pool (the exit quote has less impact).
- Only spot-mint fix option 1 ("refuse single-sided/exact-out entries in blocked mode") also closes this. A complete fix must also cover the blocked single-sided zap-out, or price both legs with the same fair price: value = a*P_ref / NAV(P_ref).

## PoC (unprivileged `BseActor` contracts; no cheatcodes on protocol state; vm.roll/warp only between txs)
Setup: honest LP bootstraps 1000/1000 via the idle path; pool fee 0.3%; default 20% sleeve.

### A) Single-entity self-attack
1. The attacker buys about 16.7% of the shares fairly with an idle dual deposit (20% of backing). Cost is counted.
2. In a later block, the attacker opens one `PM.unlock` and makes no swaps. It loops N times: blocked `exchangeIn(vault -> token0)` sized to 80% of the free token0, then blocked `exchangeIn(token0 -> vault)` with the token0 it just received.
3. In a later block, it exits all shares with an idle pro-rata dual exit.

Realized net profit is valued at P0 = 1. Pre-attack NAV is 2400.

| rounds | shallow pool (vault ~45% of L) profit / honest LP delta | deep pool (vault ~0.1% of L) profit / honest LP delta |
|---|---|---|
| 0 (control) | -2 wei / 0 | -2 wei / 0 |
| 1 | +1.85 / -1.85 | +4.87 / -4.87 |
| 3 | +5.55 / -5.55 | +14.58 / -14.58 |
| 10 | +18.43 / -18.43 | +48.19 / -48.19 |
| 30 | +54.77 / -54.77 | +141.12 / -141.12 |
| 100 | +176.80 (736 bps of NAV) / -176.80 | **+432.89 (1803 bps of NAV) / -432.89** |

- Profit grows linearly with the number of rounds. There is no per-round decay, because the book returns to the same state each round.
- Gas is about 0.38M per round. 100 rounds take about 38M gas, so they would be split over several unlock txs.
- The attacker's capital is fully returned and counted.

### B) Back-run of an honest blocked single-sided deposit (attacker holds no shares)
- An honest integrator, inside its own unlock, deposits nav/10 token1 single-sided. Its mark-to-market loss is -8.32.
- The attacker then makes a blocked deposit of nav/10 token0 and exits idle in the next block: **+9.03 realized**.
- The honest LP is about flat (+0.07 net). The attacker captures the honest depositor's loss.
- Control without the honest prefix: the attacker loses 8.32.

## Not re-tested here
- The Pons variant. The p4-fs strict campaign already showed +13.20 on Pons for the 2-deposit form, and the code path is the same.

## Fix
- In blocked mode, refuse single-sided entries and exits, as well as exact-out mints.
- Alternatively, price both blocked legs against one fair reference price. A deviation gate alone is insufficient.
