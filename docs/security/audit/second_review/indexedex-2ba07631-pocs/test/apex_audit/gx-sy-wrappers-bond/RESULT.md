# gx-sy-wrappers-bond: adversarial execution (HEAD 2ba07631)

**Status:** refuted_by_execution. No new break was found. 16 tests were written and run through forge test, and every suite result is `ok`.

## Files
- `GxDetfSyBond.t.sol`: hermetic tests on `TestBase_SingleStandardExchangeDETF` (HEAD DETFSY, StakedDETF and DETFFundedBond code).
- `GxTokenStaking.t.sol`: hermetic tests on `TestBase_TokenStaking` (HEAD code), plus a live 4663 fork test on TokenStaking 0xE4c9Ff4C, which is in the Wrapped phase.
- `GxNativeSyCP.t.sol`: native SY on a UniV2 constant-product SE (HEAD code).

## Results
| Test | What it checks | Result |
|---|---|---|
| A stakingSyTracksDirectStakerAcrossRebases | Over 4 funded rebases, the staking-SY growth equals a direct sDETF staker's growth and never exceeds it. SY claims stay ≤ SY's sDETF balance | PASS (SY 1943710550→1944222368, direct 1947531428→1948044252, ratio equal to within 1e-6) |
| B stakingSyMultiUserExitLiveness | 4 users enter between rebases (non-round gonsPerUnit). One partial exit, then full exits in reverse order with an epoch in between. No revert, no over-claim | PASS. All SY retired; the residual is 3 native units (about 3e-9 DETF) of dust |
| C giftsDoNotBreakOrInflateWrappers | Compares a control run with a run where unsolicited sDETF goes to the staking SY and DETF goes to the raw SY | PASS. Rate and every payout are identical to the control |
| D rawSyInternalBalanceStagedSweep | Known class sy-redeem-internalbalance-unattributed: a non-atomic integrator stages SY at the wrapper and an EOA redeems it | Mechanism reproduces (EOA swept 9.91e18 seShare). DETFSY has no `requirePretransferCaller` EOA gate, unlike native SY. The atomic integrator path is safe. This is a duplicate and needs a user-error precondition |
| E bondDonatePretransferredNoCallerValue | `donate(pretransferred)` credits the whole balance with booked=0 (:399-405). Checks over-declaring, the EOA gate, sDETF protection, LP pretransfer, stranded seShare and stranded raw DETF | PASS. The caller gets 0 of every token; the LP stays in bond custody; sDETF and LP pretransfer revert. The bond still claims in full afterwards |
| F jitStakeAroundEpoch | Stake 10 s before an epoch boundary, sync, then unstake | It works as designed: the JIT staker earned 127,950 against 142,762 for the full-epoch staker, about 0.0066% per epoch. This is the known no-vesting property (P2 detf-expansion-spot, bounded) |
| G rewardConservationAdversarialSequence | 40 interleaved stake/withdraw/reassign/getReward/exit/1-wei actions with a notify mid-period | PASS. Paid 734.8 of 800 funded. Residual = funded − paid exactly; it is the standard Synthetix zero-supply leftover, which the owner can rescue |
| H reassignDoesNotCreateRewards | 30 same-block ping-pong reassigns | PASS. The sum of earned is unchanged |
| H2 reassign gates | Zero-balance reassign and self-reassign | PASS (both revert) |
| I live withdrawClaim chunking + dust split | Live 5M holder: one whole withdrawal against 10 chunks. 20 dust pieces reassigned to an EOA and withdrawn | PASS. Chunked total ≤ whole (…420 vs …422); dust pieces get 0 (rounding favours the remaining holders) |
| J roundTripNoProfit (native SY UniV2) | deposit(token) then redeem(same token) | PASS (out < in) |
| K internalBalanceParity | redeem with internalBalance=true via an atomic caller compared with redeem with internalBalance=false | PASS (identical) |
| L internalBalanceGates | An EOA is rejected, over-claiming reverts, and stranded shares can only be swept by a contract (known class) | PASS |
| 00 tokens | SY token wiring (log only) | PASS |

## Notes
- DETFSY `redeem(internalBalance=true)` burns `address(this)` shares with no caller check, while native SY calls `requirePretransferCaller`. This is a variant of the known sy-redeem-internalbalance-unattributed class, and it only matters if an integrator stages SY across transactions. Live exposure is 0 because the SY self-balance is 0.
- Every payout is caller-neutral on the bond NFT pretransfer credit path. The only effect is forced reserve conversion at spot (known detf-bond-spot-valuation / H3SP-2).
