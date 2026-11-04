# fz-balancer-sharesonly-join: CONFIRMED (distinct root cause)

Run: FOUNDRY_PROFILE=audit forge test --match-path .../fz-balancer-sharesonly-join/BufferSharesOnlyJoin.t.sol -vv -> 4 passed, 0 failed (3 suites).

## Root cause
`StandardExchangeBufferHookTarget.onBeforeInitialize` seeds `virtualTTA = exactAmountsInScaled18[sharesIdx]`
(the shares' rated value) and ignores the TTA actually deposited. `computeInvariant`/`onSwap` read the TTA
side only from `virtualTTA`, never the live TTA balance. If the initializer deposits less TTA than
shares*rate, the BPT book (invariant) shows about twice the real backing. Unbalanced and native shares-only joins
(`exchangeIn(shares -> BPT)`, `router.addLiquidityUnbalanced`) are priced on that virtual book. Proportional
exits pay from live balances. The joiner overpays, and the difference goes to the incumbent LP(s).
Proportional joins are fair (control round trip loses 3 wei).

This is not a duplicate of balancer-buffer-computebalance-domain. That finding needs h != 0 and comes from computeBalance
returning a math-domain balance on single-token exits. Here h == 0 throughout, and computeBalance is not involved.
P4 noted it as the harness root "B1/B2 (virtualTTA vs live TTA)", but no p3/p3b/p3c/p5a result confirmed it.

## Results (shares valued at fixed fair LP value fsv=2.0 DAI; slippage bound = previewExchangeIn, preview == exec)
- Variant A (the project's own fixture init: alice seeds 2000 shares + 2000 TTA; virtualTTA 3662.5):
  carol joins 100 shares (200 DAI) natively, gets 88.01 BPT, exits for 145.49 DAI. Loss 27.25%. Alice gains 54.5 DAI.
- Variant B (unprivileged attacker inits the pool with 1000 shares + 1 TTA, cost 2001 DAI; virtualTTA 1782.5):
  3 honest victims join natively with 500/250/1000 DAI-worth of shares (3500 DAI). Attacker exits first, proportionally.
  Attacker profit +1354.76 DAI (fsv) / +1207.4 (rate). Victim loss 1354.76 DAI (38.7%; per victim 26.5/36.1/45.5%).
- Control for B (same flow, value-balanced init, live TTA == virtualTTA; same BPT minted): victim loss 18.85%
  (ordinary single-sided impact plus the rate<fsv discount; first victim only 2.65%). The excess due to the bug is
  about 695 DAI (19.9% of victim deposits); first victim 26.5% vs 2.65%.

## Fix
In onBeforeInitialize, set virtualTTA from the TTA actually deposited (exactAmountsIn[ttaIdx]), or require
exactAmountsIn[ttaIdx] == exactAmountsIn[sharesIdx] (value-balanced). More generally, reconcile the invariant with
live TTA (plus hook-held excess shares), or gate non-proportional joins.
