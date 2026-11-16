# T5-EGRESS integer evidence

Date: 2026-11-10. Interpreter: resident Bun 1.4.4 JavaScript kernel.

Executed `runVectors()` from `vectors.mjs`, using the local `model.mjs` integer ledger, by dynamic import. The final invocation completed normally with all assertions passing. No shell process was started; there is no shell exit status to report. Standalone reproduction, not a command executed in this lane:

```sh
bun docs/incidents/2026-09-16-dtf-recovery/migration/package/evidence/egress/vectors.mjs
```

All amounts below are integer native units or gons, not human whole tokens. The readable vectors use initial `k = 1000`. The exhaustive cases also execute with the production `k = 10^36`. Both use the actual allocation precision `10^54`, integer reward-per-share floors, ceiling rebase division, native allocation/staking dust, and top-up-only standing weights.

## Final observed output

This is a compact transcription of the final returned object, omitting only zero-valued account entries. `vectors.mjs` prints the complete object, including those entries.

```json
{
  "bondAndPostClaimGrowth": {
    "funding": [
      {"old":"1000","k":"500","staking":"10","fee":"0","creator":"0","ad":"0","sd":"0"},
      {"old":"500","k":"400","staking":"5","fee":"0","creator":"0","ad":"0","sd":"0"},
      {"old":"400","k":"200","staking":"15","fee":"0","creator":"0","ad":"0","sd":"0"}
    ],
    "afterPrincipal": {
      "k":"400","totalGons":"6000","backing":"15",
      "gons":{"bond":"5000","escrow":"1000"},
      "rewards":{"wallet:alice":"1000"},"paid":"10"
    },
    "release":"5","repeat":"0",
    "final":{"k":"200","totalGons":"0","backing":"0","paid":"40"}
  },
  "sySplitInternalAndDust": {
    "funding": [
      {"old":"1000","k":"875","staking":"1","fee":"0","creator":"0","ad":"1","sd":"0"},
      {"old":"875","k":"637","staking":"3","fee":"0","creator":"0","ad":"1","sd":"1"},
      {"old":"637","k":"423","staking":"1","fee":"0","creator":"0","ad":"1","sd":"1"}
    ],
    "internalCredit":"2",
    "afterSyExit": {
      "k":"637","totalGons":"2541","backing":"5","allocationDust":"1","stakingDust":"1",
      "gons":{"escrow":"2541"},
      "rewards":{"sy:bob":"726","sy:alice":"1815"},
      "paid":"7"
    },
    "firstReward":"2","finalReward":"2",
    "final": {
      "k":"423","totalGons":"421","backing":"2","allocationDust":"1","stakingDust":"1",
      "gons":{"escrow":"421"},"rewards":{"sy:alice":"421"},"paid":"11"
    }
  },
  "mixedHolderRouter": {
    "k":"770","totalGons":"6900","backing":"10","allocationDust":"1","stakingDust":"1",
    "gons":{"escrow":"6900"},
    "rewards":{"wallet:alice":"4600","wallet:bob":"2300","wallet:router":"0"},
    "paid":"30"
  },
  "roleChange": {
    "funding": [
      {"old":"1000","k":"527","staking":"9","fee":"2","creator":"1","ad":"2","sd":"1"},
      {"old":"527","k":"374","staking":"9","fee":"2","creator":"1","ad":"1","sd":"1"}
    ],
    "oldGons":"1054","oldPaid":"2",
    "final": {
      "k":"374","totalGons":"12703","backing":"35","allocationDust":"1","stakingDust":"1",
      "gons":{"alice":"10000","escrow":"1955","fee-old":"748"},
      "principal":{"alice":"10","fee-old":"2"},
      "rewards":{"role:fee-old":"306","role:creator":"901","role:fee-new":"748"},
      "paid":"0"
    }
  },
  "exhaustiveSplitMerge": {
    "scales":["1000","1000000000000000000000000000000000000"],
    "principalRange":"1..24",
    "everySplitIncludingZeroAndFull":true,
    "cases":648,
    "allInvariantsPassed":true
  },
  "equalRoleBeneficiaries": {
    "allocation":{"old":"1000","k":"527","staking":"9","fee":"2","creator":"1","ad":"2","sd":"1"},
    "pendingGons":"1581"
  },
  "boundaryPredicates": {
    "cliffPrincipalAtUnlockMinusOneUnlockPlusOne":["0","10","10"],
    "stageOneRewardClaimAndReleaseRejectedBeforeMutation":true,
    "internalAttackerCredit":"0",
    "internalAttackerOneShareAdmissible":false,
    "mixedAliceRewardOnlyOneUnitWithdrawableBeforeActivation":false
  },
  "bondFractionRetained": {
    "paidToRecipient":"8","retainedOwner":"alice","retiredToOwner":"776","later":"2",
    "final":{"k":"388","totalGons":"0","backing":"1","allocationDust":"1","stakingDust":"0","paid":"10"}
  },
  "activeFullWithdrawalFraction": {
    "physicalFraction":"776",
    "afterCheckpoint": {
      "k":"778","totalGons":"776","backing":"2","allocationDust":"1","stakingDust":"1",
      "gons":{"escrow":"776"},"rewards":{"wallet:alice":"776"},"paid":"8"
    }
  },
  "fixedGonPartitionCounterexample": {
    "principal":"10","fixedGonSliceCapacities":["1","8"],"selectedPrincipalSliceCapacities":["1","9"]
  },
  "mixedInternalOwners": {
    "afterRouterExit": {
      "k":"500","totalGons":"5000","backing":"10","allocationDust":"0","stakingDust":"0",
      "gons":{"escrow":"5000"},"rewards":{"sy:alice":"2000","sy:bob":"3000"},"paid":"10"
    },
    "aliceReward":"4","bobReward":"6",
    "final":{"k":"500","totalGons":"0","backing":"0","allocationDust":"0","stakingDust":"0","paid":"20"}
  }
}
```

## What the numbers establish

- Bond vector: deposit 10; actual funding 10, 5, 15. Claim 10 principal at `k=500`; later growth at `k=400` leaves 1,000 wallet reward gons after a successful 10-unit principal exit. Original bond retains a different 5,000 gons. At `k=200`, those rights pay 5 and 25 respectively, once. Total DETF paid is `10 + 5 + 25 = 40`, matching all measured input. No double count between bond rewards and growth on claimed principal.
- SY vector: wrap 7; fund 2; transfer 2 shares to Bob; fund 3; the router transfers Bob's complete 2-share holding to Bob's wrapper-internal beneficial-owner slot, creating a `(router,bob)` principal-spend ticket. Internal redemption pays 2 principal receipts to Bob, which Bob unstakes; Alice independently redeems 5 principal. Seven principal units exit successfully, no shares remain, and Alice/Bob retain 1,815/726 reward gons. Bob later voluntarily assigns his detached rights to Alice. The router owns neither user's reward. Two activated releases pay 2 and 2; the immediate repeats pay zero. A final 421-gon right remains Alice's, not abandoned wrapper inventory. The remaining two native backing units are exactly allocation dust 1 plus staking dust 1: `floor(421/423) + 1 + 1 = 2`.
- Mixed vector: Alice's 20 and Bob's 10 principal receive funded growth, then 7 principal goes Alice -> router -> Bob. Bob withdraws 17 and Alice withdraws 13. The router cannot launder their 4,600/2,300 reward gons into principal.
- Role vector: changing the reserved fee beneficiary affects the second allocation only. The old 1,054 gons do not change; their current value is `floor(1054/374)=2`, with 306 gons retained after release. Receipt transfer changes neither aggregate gons nor backing. Equal fee/creator beneficiaries receive one summed 1,581-gon right.
- Each exhaustive case deposits `n`, wraps, funds 3, transfers every `x in [0,n]`, funds 2, transfers the complete second holding back, exits all `n` principal, activates, releases the whole payable reward, and attempts a duplicate release. It checks conservation and per-account nonnegative principal backing after transitions. It covers 324 split choices at each of two scales.
- Mixed internal owners: one router controls distinct Alice/Bob tickets of 2/3 shares. Its attempted 3-share spend against Alice's 2-share ticket rejects before mutation despite five aggregate internal shares. Further actual funding occurs while these shares are in internal custody. All 10 principal units subsequently exit; 2,000/3,000 reward gons stay Alice's/Bob's, not the router's. Activation releases 4/6 respectively and leaves zero backing/gons.
- Bond fraction: after principal and a payable reward go to Bob, the final 776-gon position fraction belongs to NFT owner Alice. It pays zero at `k=778`, survives retirement as a retained right, and pays two after actual funding changes `k` to 388; the repeat is zero.
- Active full withdrawal: paying all eight displayed units leaves 776 physical gons. The explicit wallet checkpoint moves exactly those gons into Alice's retained reward account. Neither the full withdrawal nor checkpoint retires them.

## Limits and execution history

This is an arithmetic model of the proposed transitions, not production/test code or executable SUT acceptance. It does not execute registry proxies, token callbacks, allowance/permit code, actual `msg.sender` authority, route conversions, selector cuts, revert rollback after arbitrary external calls, Solidity overflow limits, or gas. Explicit rejection checks happen before model mutation; the other reported negative cases are admissibility predicates, not EVM revert tests. Internal slots are keyed by beneficial owner; a separate `(operator,owner)` ticket is checked arithmetically. Production must authenticate those addresses from actual calls. Active immediate role delivery and the integrated SY `claimRewards` entrypoint are not SUT-tested here.

Early hand-calculated fixture expectations omitted the canonical reward-per-share floor and therefore failed. The final fixtures use the actual two-stage floor/ceiling machinery, preserve the resulting allocation/staking dust, and assert the corrected exact values. No repository test was changed. The SY model was then completed so attached rewards travel proportionally with transferred shares and detach to the source owner on principal redemption. Verification separated a router's principal-spend ticket from the original owner's reward slot; the final design never relies on a generic router forwarding a reward that was incorrectly credited to it. The ledger and vectors are separate bounded files.

The edit tool reported timeouts waiting for fresh JavaScript LSP diagnostics, not compiler diagnostics. No clean LSP/type-check claim is made. The final interpreter run is the executable evidence recorded here.

No dependencies, processes, listeners, temporary directories, caches, Forge artifacts, or worktrees were created or modified by these checks. The two arithmetic scripts and this evidence file are the intended retained artifacts, not cleanup targets.
