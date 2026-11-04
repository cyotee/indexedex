# hook-midstate-reentrancy — RESULT: CONFIRMED (Balancer V3 StandardExchangeBufferPool, pre-seat path)

Run: FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/hook-midstate-reentrancy/HookMidstateReentrancy.t.sol -vv` → 3/3 PASS

## Mechanism (as executed)
- `StandardExchangeBufferHookTarget._preSeatShares` (shares→TTA onBeforeSwap) does `sendTo` + CUSTOM `removeLiquidity(drainAmount)`.
  It then calls `_passPrepay(params.router)` → `router.passPrepayAuth()` (lines 486-497). This happens before
  `hookSharesDelta -= hdSub` (line 547). `params.router` is whoever called `Vault.swap`. `_isPrepayRouter` only
  checks that `prepaySessionActive()` returns 32 bytes.
- An attacker contract that calls `Vault.swap` directly gets control at that point. Balancer V3 swap hooks run outside
  `nonReentrant`, so the attacker re-enters `Vault.swap` on the same pool. The nested sell is quoted and executed with
  `derivedY` understated by the outer drain (shares look scarce), so the nested sell is overpaid in TTA. Nesting can recurse.
- Practical wall: the outer `exchangeOut` uses a share preview computed before the nested SE zap moved Aerodrome, so it
  reverts `MaxAmountExceeded`. The attacker gets around this by borrowing DAI via `vault.sendTo` inside the callback,
  pushing the Aerodrome price back with a DAI→USDC swap, and unwinding that swap before the unlock ends.
  The cost of that round trip (~55 DAI) is included in the attacker's net.
- The attacker buys back all sold shares in the same unlock (EXACT_OUT, chunked for MAX_OUT_RATIO). Share delta nets
  to 0. The attacker uses zero capital: it starts with 0 DAI and no shares.

## Numbers (project fixture TestBase_StandardExchangeBufferPool: real BV3 Vault, Aerodrome DAI/USDC SE vault, deployed 5% static fee)
Pool: 2000 shares (rate 1.831) / virtualTTA 3662 DAI, single honest LP (alice). Sells = 25%,20%,15%,10% of derivedY (4-level nest).
- Attacker net: **+391.66 DAI**, ends with 0 shares, started with 0 DAI.
- LP (alice) proportional exit value: 5662.50 → 5262.35 DAI (−400). At the pre-attack share rate: **−372.90 DAI** (shares 2000 → 1796.4).
- Control, the same sells done sequentially with no nesting, then the same buy-back: attacker **−194.44 DAI**, and the LP *gains* (fees).
- 2-level nest: −12.54 DAI. The edge is smaller than the Aerodrome fix cost. Profit needs at least 3-4 nested levels.

## Not proven / caveats
- TTA→shares reconcile callback (`_reconcileTTAToShares`): not built. The econ skeptic argues that the nested approve
  overwrite makes the outer exchangeIn revert.
- DUAL Uniswap V4 hook half: not built (needs a callback token, and the attacker mostly trades against its own pending withdrawal).
- Per the P2 reach/design votes, Balancer V3 buffer pools are not in the chain-4663 deployment manifests (latent defect).
  The callback predates the diff (aca16198 already called `passPrepayAuth` inside try/catch). The diff only removed the try/catch.
- Sibling hook targets (CommonStable/CommonWeighted/MixedLeg/MultiPair/MixedStable) copy the same pattern. They were not executed.

## Fix
Possible fixes:
- Only call `passPrepayAuth`/`restorePrepayAuth` on an allow-listed IndexedEx router.
- Add a transient-storage reentrancy lock that is held across onBeforeSwap→onAfterSwap and rejects nested swaps and liquidity ops on the pool.
- Apply the `hookSharesDelta`/`virtualTTA` updates before any external call.
