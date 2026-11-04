# staking-requeue (staking-rebalance-requeue-pending): CONFIRMED as griefing/DoS, no profit

The test (`StakingRequeue.t.sol`) uses the project's TestBase_LidoWstETHStandardExchange, which has the production DFPkg plus hermetic Lido ports (1:1 rate). The liquid target is the default 5%.

Setup: honest LPs deposit 200 WETH. One rebalance runs, leaving 10 WETH liquid and 190 wstETH. A small LP then exits 3 WETH, so liquid is 7 and the deficit is 2.85 ETH (above the 10% band).

Results:
- Control: one rebalance queues 2.85 ETH. A 50 wstETH locked-side exit then succeeds.
- Attack: an unprivileged contract loops `rebalance()` in one tx. It took 67 calls, used about 20.0M gas and created 67 withdrawal requests. The whole 190 wstETH went into the Lido queue (about 67x the real deficit). Liquid WETH stayed at 7 and NAV stayed at 197.
- Afterwards, any locked-side exit (50 or 1 wstETH) reverts with `InsufficientLockedReserve`.
- `totalReserveEth()` costs about 486k gas with 67 pending requests. That is bounded, not an out-of-gas DoS.

Root cause: `_queueDeficit(target - liquid)` does not subtract pending face. Pending face is counted in the total but does not raise liquid until claimed, so the deficit stays and gets re-queued on every call.

Impact:
- The whole LST inventory can be forced into the withdrawal queue. On real Lido, queued stETH earns no rewards, so the vault loses yield for the length of the queue.
- After finalization there is a forced unstake/restake round trip.
- In-kind wstETH/stETH exits are DoS'd until finalization.
- The attacker gains nothing; the cost is gas only.
- Not profitable: NAV is unchanged, and pending face equals the payout absent slashing.
- Not deployed on chain 4663.

Severity: low/medium griefing. EtherFi weETH has the same code shape (not separately executed).

Fix: queue `max(0, target - liquid - pendingFace)`, or skip queueing while any request is pending.
