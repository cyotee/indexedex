# balancer-computebalance-domain — CONFIRMED (executed)

Hypothesis: balancer-buffer-computebalance-domain. StandardExchangeBufferPoolTarget.computeBalance (shares index)
returns WeightedMath balance over `_derivedY = live - lift(h)`, but Balancer BasePoolMath.computeRemoveLiquiditySingleTokenExactIn
computes `amountOut = live - newBalance`. So each dust SINGLE_TOKEN_EXACT_IN exit to the shares token pays ~lift(h).
onAfterRemoveLiquidity scales h only by bptIn/T, so h barely moves and every following dust exit pays ~h again.

Test: BufferComputeBalanceDomain.t.sol (uses TestBase_StandardExchangeBufferPool: real crane Balancer V3 Vault+RouterMock,
Aerodrome-backed SE vault, real pkg, default 0.05% fee). Run:
  FOUNDRY_PROFILE=audit forge test --match-path .../balancer-computebalance-domain/BufferComputeBalanceDomain.t.sol -vv

Scenario: alice (honest LP) inits the pool with 2000e18 shares + 2000e18 TTA (value ~5662 TTA). Attacker bob (unprivileged EOA)
with 100 TTA + ~1 share of capital (counted as cost, no flash loan needed):
1. addLiquidityUnbalanced(0 TTA, ~1 share) -> 0.89 BPT
2. swap 100 TTA -> shares (sets h = 49.82e18 raw shares)
3. 20x removeLiquiditySingleTokenExactIn(BPT/20, shares): each pays ~47.37 raw shares (~86.7 TTA)
Output: attacker PROFIT = 1729.48e18 TTA-units; alice proportional value 5662.36 -> 3932.66 (LOSS 1729.70e18).
Pool raw shares 2000.2 -> 1053.0. Control (h=0): dust exit pays the proportional amount (0.0475 shares for BPT/20).

Caveat (from P2, not re-verified here): no Balancer V3 buffer pool family appears in the Robinhood 4663 manifests. The bug predates diff aca16198..2ba07631.
Fix: computeBalance must return a live-domain balance (newMath + lift(h) for shares; for TTA, map virtualTTA back to live),
or block SINGLE_TOKEN_EXACT_IN / EXACT_OUT kinds in before-hooks (enable shouldCallBeforeRemoveLiquidity and allow only PROPORTIONAL/CUSTOM).
