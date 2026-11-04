# chain-reentrancy-router — RESULT: REFUTED_BY_EXECUTION (primitives do not compose; composite < best single primitive)

Goal: a composite "chain-reentrancy-router" whose executed profit exceeds the best single primitive it
uses, combining hook-midstate-reentrancy + balancer-buffer-computebalance-domain +
balancer-router-permit-overpull + prepaid-credit-refund-sweep.

Test: `test/apex_audit/chain-reentrancy-router/ChainReentrancyRouter.t.sol`
Fixture: `TestBase_StandardExchangeBufferPool` (real crane BV3 Vault + RouterMock, Aerodrome-backed SE vault,
real pkg), identical to the two confirmed buffer-pool PoCs. Attacker = unprivileged EOA `bob`, capital =
100 TTA + ~1 share, counted as cost; all value deltas measured at the PRE-attack share rate (`rate0`).
Run: FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/chain-reentrancy-router/ChainReentrancyRouter.t.sol -vv`

## What composes and what doesn't

Only two of the four primitives live in the same custody/unlock frame (the BV3 StandardExchangeBufferPool):
hook-midstate-reentrancy and balancer-buffer-computebalance-domain. Both extract from the SAME single LP
(alice) and both move the SAME two hook state variables — `virtualTTA` (x) and `hookSharesDelta` (h). The
other two primitives are on different contracts (SE router diamond; RebasingAware ERC4626 vault) with no
shared `vault.unlock` frame, so "a reentrant buffer-pool frame sweeps router residue" is not reachable — the
residue sits on the SE router's own balance, the reentrancy is inside the BV3 Vault unlock; different
contract, different custody. See "Router/refund legs" below.

### Best single primitive (baseline, same fresh state)
`test_grid` — single computeBalance dust-drain, measured at rate0:
- n=20 exits: attacker +1725.32e18 TTA, alice −1734.09e18
- n=40 exits: attacker +3458.10e18 TTA, alice −3466.87e18
- n=80 exits: attacker **+3653.73e18 TTA**, alice −3662.50e18  (exits self-cap at #57: h is exhausted)
- n=160: +3653.90e18 (no further gain — the drain is saturated)

**Best single primitive = computeBalance ≈ 3653.73e18 TTA.** (hook-midstate alone ≈ +391.6e18, confirmed below.)

### Composition A — computeBalance FIRST, then midstate sell (interleaved or sequential)
After the n=80 drain the pool shares side is near-empty and h is exhausted. Every stage-2 shares→TTA sell
reverts, at every size tried (multBps 3000/6000/10000/16000, nested and sequential):
- `panic 0x11` (arithmetic over/underflow) in the pre-seat path — `_derivedY`/`virtualTTA` have been driven
  to an extreme where `_preSeatShares` / WeightedMath underflow.
- Shallower drain (n=20) + stage-2 sell DOES execute (chain SEQ n=20): attacker **+2007.84e18**, alice −1946.09e18.
  Still **below** the 3653 single primitive. The nested variant at n=20 reverts with `MaxInRatio() 0x340a4533`
  (0x340a4533) — the drained derivedY is so small that even one nested sell exceeds Balancer's MAX_IN_RATIO.

### Composition B — midstate FIRST (zero-capital, buyback), then computeBalance
`test_sequence_midstateThenCompute`:
- midstate nested (4-level, buyback, zero capital) nets **+391.61e18 TTA** — reproduces the standalone PoC.
- It leaves `hookSharesDelta = −203.6e18` (negative) and pool live shares 2000→1796.4.
- The following computeBalance drain then drains **0**: the first dust exit reverts immediately
  ("exit reverted at 0"). The computeBalance primitive needs h>0 and a healthy resting BPT/dust path; the
  midstate leg left h negative and the shares side reduced, so its precondition is gone.
- COMPOSITE total = **+397.06e18 TTA** (essentially just the midstate leg), alice −385.59e18.
  Far **below** the 3653 single primitive.

## Why they do not compose (the blocking guard)
The two in-frame primitives are not additive because they are two different ways of draining the SAME LP via
the SAME (x = virtualTTA, h = hookSharesDelta) pair, and each one drives that pair into a regime where the
other's precondition fails:
- computeBalance saturates the shares side / exhausts h → the midstate pre-seat path underflows (`panic 0x11`)
  or trips `MaxInRatio` because derivedY is now tiny.
- midstate drives h negative and shrinks the shares balance → the computeBalance dust exit reverts at the
  first chunk.
There is no state in which both preconditions (large positive h AND a healthy derivedY for nested pre-seat)
hold at once after the other has run. The maximal extraction is bounded by the single stronger primitive
(computeBalance, 3653e18 ≈ the whole of alice's value edge), not by their sum.

## Router/refund legs (balancer-router-permit-overpull, prepaid-credit-refund-sweep) — not chainable here
- balancer-router-permit-overpull theft lives on the `BalancerV3StandardExchangeRouter` diamond and spends
  THAT contract's own residual balance; it is not inside the BV3 buffer-pool `vault.unlock` frame and shares
  no token custody with it. A reentrant buffer-pool callback cannot reach or sweep it.
- prepaid-credit-refund-sweep is on the RebasingAware ERC4626 custody vault and needs a victim's non-atomic
  pretransfer; again a separate contract/custody, no shared unlock.
- Per P2 reach votes, neither the SE router nor the BV3 buffer-pool family appears in the Robinhood-4663
  deployment manifests, so the whole buffer-pool composition is latent (live only where that family is
  deployed, e.g. base_main scripts).

## Validity
Attacker is an unprivileged EOA; no privileged prank / vm.store / etch / mockCall / deal on protocol state
during the attack. The midstate leg's mid-unlock DAI borrow (`vault.sendTo`) is repaid in-tx before the
unlock closes (asserted share/TTA deltas == 0). Victim (alice) set up honestly before the attack; profit and
loss asserted at the restored pre-attack rate. No hidden side assets (attacker USDC == 0 asserted, no
residual BPT asserted).

## Bottom line
CONFIRMED that each in-frame primitive executes (computeBalance 3653e18; midstate 391e18). REFUTED that they
compose: the deepest working composite (shallow-drain + sequential sell) is 2007e18 and every richer
ordering either reverts or collapses to one leg — none exceeds the 3653e18 single-primitive maximum. The
router/refund primitives are on separate contracts and cannot be reentrantly chained into the buffer-pool
frame.
