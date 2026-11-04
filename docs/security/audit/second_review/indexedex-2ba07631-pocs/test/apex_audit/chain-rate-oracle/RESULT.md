# chain-rate-oracle: composite CONFIRMED by execution (latent; not live on 4663)

Composite of five hypotheses, chained through ONE manipulation per pool inside one tx:
se-rate-provider-full-book-manipulable, rawleg-rp-swap, rawleg-rp-lp-and-fee,
balancer-buffer-computebalance-domain, hunt-twap-retroactive-current-tick.

## Fixture (project's own matrix row, no pranks/mocks on protocol state)
`UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_StandardExchangeBufferPool`:
a Curve-quad stable buffer hook over 4 buffered legs. Each leg's SE is a real Balancer V3
`StandardExchangeBufferPool` (its BPT is the SE share, "BPT-as-SE"), valued by the production
`StandardExchangeRateProvider` (RP = pool raw shares / BPT supply, i.e. full-book single-token).
Real V4 PoolManager, real Balancer VaultMock + RouterMock per leg, real packages/registry/hook
factory. Honest quad LP (`user`) joins 200 face per leg; honest pool LP (`alice`) seeds each
Balancer pool. Attacker = the harness `bob` (unprivileged EOA, same address on all 4 legs).

Test: `ChainRateOracle.t.sol`. Run (box compiles all of test/foundry/spec; see Infra note):
  FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/chain-rate-oracle/ChainRateOracle.t.sol -vv --match-test composite_allLegs

## The chain (one push feeds two consumers, inside one quad call, x4 legs, one tx)
Per leg i (unprivileged, flash-funded TTA_i push + face_j route capital):
1. MANIPULATION: swap ~300 TTA_i -> shares in leg i's Balancer pool. This single swap does two things:
   - sets the pool's `hookSharesDelta` h (the StandardExchangeBufferPool computeBalance-domain primitive),
   - moves RP_i seen by the quad (the se-rate-provider full-book primitive): RP_i 0.581 -> 0.547.
2. CONSUMER A+B together, via `quad.exchangeIn(face_j -> face_i)` x10: the quad values leg i at the
   shifted RP_i AND, to pay out face_i, has the hook redeem BPT_i single-token from the Balancer pool,
   which overpays by ~lift(h) (BasePoolMath subtracts the math-domain computeBalance from the LIVE
   balance). Output is wildly inflated: 50 face_j in -> 138-216 face_i out (the overpay compounds the
   rate mispricing). This drains the Balancer pool's reserves, i.e. the outside pool LP `alice`.
3. CONSUMER C (attacker's own dust BPT single-token exits) draws from the SAME h and therefore REVERTS
   after step 2 has consumed it (ZeroTransfer) — see "composition limit" below.
Legs 1..3 repeat. Cross-leg face debts net (each leg borrows face_{i+1}, receives face_i); each TTA_i
flash is repaid by selling the abundant face_i back to TTA_i; a 9 bps flash fee is charged on all
principal and asserted covered in-kind before it is handed back. No residual BPT (asserted).

## Executed result — test_composite_allLegs (PASS)
- attacker net profit, at fair pre-attack prices, after the 9 bps flash fee, over the 4 pools in one tx:
  **+4,981.6e18 TTA-units** (`4981604798296144097053`).
- quad LP book: +349.7e18 (the quad hook itself slightly GAINS; it is not the victim here).
- outside Balancer pool LPs (`alice`): **-5,929.8e18** TTA-units (`5929777341382913550586`) — the loss
  source is the single-token BPT redemptions draining the pools' reserves.
- The composite hits **4 consumers (one per leg pool) in one flash-loaned tx**; within each leg the single
  push feeds 2 quad-internal consumers (rate valuation + computeBalance redemption overpay).

## Does it exceed the best single primitive?
Yes in aggregate: 4x the per-pool extraction by hitting all 4 legs in one unlock/tx (~1,245e18/leg of
attacker profit vs the standalone computeBalance PoC's ~1,729e18 TTA-units and the standalone se-rate
PoC's ~+17 face). Note the per-leg figures are not unit-identical across fixtures, so the honest headline
is "one tx, 4 pools, ~4,981e18 net, flash repaid", not a strict 2x-over-one-primitive on a single pool.

## Composition limit found (reported honestly)
Consumers A (quad rate valuation) and B (quad's single-token BPT redemption overpay) genuinely COMPOSE:
both are driven by the one push and both execute inside the same `exchangeIn`, amplifying each other.
Consumer C (the attacker's own direct dust single-token exit, the standalone computeBalance primitive)
does NOT stack on top of B: they share the same `hookSharesDelta` h pot, and the quad's redemptions in
step 2 drain h first, so the direct dust exits then revert (ZeroTransfer). The TWAP primitive
(hunt-twap-retroactive) does not compose at all here: no contract in this family reads the V4 TWAP, so
there is no on-chain consumer to feed (it needs an external lender, as its own PoC showed).

## Validity (anti-cheat)
- Attacker is the unprivileged harness `bob`; no prank/store/etch/mockCall on protocol state during the attack.
- Only setup-time config is the quad dex fee (0.1%, within package bounds); victims (`user`, `alice`) set up honestly first.
- Flash capital (TTA_i push + face_j route) is a simulated loan: principal + 9 bps fee asserted held in-kind
  at the end and handed to the lender; own capital (1 face/leg for the dust BPT mint) counted as cost.
- Profit asserted > 0 and valued at fair pre-attack prices; no residual BPT held.

## Live impact
Nil today. Per census.md, no Curve/Balancer quad hook and no StandardExchangeBufferPool (BPT-as-SE) family
is deployed on Robinhood 4663. Forward-looking: HIGH if a quad/orbital consumer over a BPT-as-SE leg ships.

## Fix
Value a BPT-as-SE leg by its proportional/invariant value (invariant * rate / supply) or a marginal-unit
exit, not a full-book single-token liquidation; and make `StandardExchangeBufferPool.computeBalance`
return a LIVE-domain balance (or block SINGLE_TOKEN_EXACT_IN/EXACT_OUT in the before-hook). Fixing either
bug alone cuts the chain; both are needed to remove the amplification.

## Infra note
The t4 box compiles the whole `test/foundry/spec` tree. On a cold full recompile, several unrelated
project test files (e.g. .../fullSpread/.../NestedAndConsumer.t.sol, SeMatrix exact-out swap helpers)
intermittently hit a non-via-ir "Stack too deep", which fails the whole `forge test` before any test runs.
The passing result above was produced on a successful cold full compile / warm slot; retries land on cold
slots and fail to compile. This is a pre-existing suite/infra flakiness, independent of this PoC.

## Adversarial review (2026-10-21) — VALID after fix
- Defect found: harness `bob` is pre-funded ~1e27 TTA per leg, so `_repay`'s "sell face_i -> TTA_i" path never ran;
  the TTA flash was repaid from bob's pre-existing balance (profit was still Delta-based, so not inflated, but the
  repay-from-proceeds claim was not exercised). Fix: bob's pre-existing TTA/face are parked at 0xBEEF before v0.
- Repay sells then hit Balancer MaxInRatio; sells now chunked to <=25% of pool shares raw.
- Baseline `test_baseline_oneLeg` reverted ZeroTransfer (transfer(0) on unattacked legs); guarded.
- Added re-valuation of residual face at min(pre, post) seRateProvider rate + assert > 0.
- Re-run (all 13 PASS): attacker net +6,072.41e18 TTA-units at min(pre,post) face price (+6,072.84e18 at pre),
  flash principal + 9 bps repaid purely from proceeds; alice loss 6,075.30e18; quad book +352.1e18.
  Residual holdings: ~716 TTA + ~5,313 face (aero SE share, rate ~1.0089 pre/post).
