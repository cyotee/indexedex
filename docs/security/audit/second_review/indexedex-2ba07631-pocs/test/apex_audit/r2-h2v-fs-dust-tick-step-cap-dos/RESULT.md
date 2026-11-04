# r2 h2v-fs-dust-tick-step-cap-dos: CONFIRMED as a griefing DoS (hookless FullSpread). Pons variant not executed.

File: `R2FsDustTickStepCapDos.t.sol`. Contracts: `R2FsDustTickStepCapDosTest` (tickSpacing 1, fee 100) and `R2FsDustTickStepCapDosSp10Test` (tickSpacing 10, fee 500).
Run: `forge test <file> -vv --skip "'*/p4-*/*'"`. All 6 tests PASS.

## Setup (all honest)
- Hookless pool, honest external full-range LP of 2000e18 liquidity.
- Alice is the vault LP. She bootstraps with a proportional 10k/10k deposit. Bob is a zapper/swapper.
- The attacker is the unprivileged `R2DustSeeder` contract. It calls `PM.unlock` -> `modifyLiquidity(L=1)` for one-spacing positions on each side of spot.
- No pranks of privileged roles, no vm.store, etch or mockCall. All honest ops run from a snapshot and are rolled back.
- Each ceiling is the largest amount that still succeeds, found by bisection over the real vault entrypoints (`exchangeIn`). Quote ceilings come from the same `QuoteService` library, fed live pool state.

## Results: ceiling before dust -> after 150 positions/side

| op | spacing 1 | spacing 10 | revert after dust |
|---|---|---|---|
| zap deposit token0->share | 51.4e18 -> **0.636e18** (81x) | 49.2e18 -> 8.96e18 (5.5x) | AlignmentNotAchievable 0x4735ea42 |
| zap redeem share->token0 (bps of Alice) | >=5000 -> **32 bps** | >=5000 -> 331 bps | QuoteWorkLimit 0xd3352809 |
| exact-in swap token0->token1 | >=900e18 -> **32.6e18** | >=900e18 -> 295e18 | QuoteWorkLimit 0xd3352809 |
| `Quotes._exactOutput` (single-step inverse) | 53.5e18 -> **0.319e18** | 639e18 -> 0.0249e18 | InvalidRoute 0x229fee83 |
| proportional dual deposit | works | works | n/a |

- Before the attack, the zap-deposit limit is PriceImpactExceeded (0x497aa808).
- After the attacker withdraws, every ceiling returns exactly to baseline. This proves the dust causes the change.

Attack cost:
- 150 wei of each token. The same 150 wei are still net spent after withdrawal, because of rounding.
- About 24.8M gas to seed 300 positions in 6 txs.

Seed-count sweep (`test_r2_seedCountSweep`):
- **n=1 per side** (2 positions, about 2 wei) already gives these ceilings:
  - exact-out quote: 0.319e18 at spacing 1, 0.025e18 at spacing 10.
  - zap deposit: 1.27e18 at spacing 1, 8.96e18 at spacing 10.
  - The zap planner is also limited by the adjacent initialized tick, not only by the step count.
- Exact-in swap ceilings collapse at n>=64. This matches MAX_CORE_STEPS=64.

Persistence:
- A third party cannot remove the dust ticks. Burning from another owner reverts, and `liquidityGross` of the dust tick stays 1 (asserted).
- The DoS lasts until the attacker withdraws. The attacker can re-seed at will.

## Caveats
- **End-to-end `exchangeOut` token->token reverts InvalidRoute already at baseline**, even for 1e15. The `_closedPlacement` / equality certification fails first. This is the separately reported fs-quote-model-exact-equality-dos.
  - So the dust impact on exact-out is shown at the quote level (`QuoteService._exactOutput`), not end to end.
  - Once the separate exact-out issue is fixed, the dust would cap exact-out at the distance to the nearest initialized tick.
- No funds are lost or frozen. Proportional deposits work, and per the earlier P3 PoCs so do exits. The impact is size-limited unavailability of single-sided zaps, zap redemptions and router swaps.
  - Small ops still pass, for example zap deposit <0.636e18 and redeem <0.32% at spacing 1.
- Census: no FullSpread package is deployed on Robinhood mainnet, so live impact is nil and the finding is forward-looking.
- The PonsV2 hook variant (beforeAddLiquidity=false) is not executed here. The code is the same quoter with MAX_CORE_STEPS (PonsFamilyHookQuoteService:25), so it is very likely to behave the same.

Severity: low to medium griefing DoS. It is cheap (wei plus about 25M gas), persistent, and only the attacker can clear it. There is no profit and no loss of principal.
