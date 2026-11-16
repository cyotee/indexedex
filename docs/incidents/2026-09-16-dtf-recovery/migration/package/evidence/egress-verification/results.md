# Independent egress arithmetic execution

Date: 2026-11-10.

Final standalone run: **exit 0**, Bun **1.4.2**, no dependencies installed. Executed under a finite completion monitor:

```sh
cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03
/opt/homebrew/bin/bun --version
/opt/homebrew/bin/bun docs/incidents/2026-09-16-dtf-recovery/migration/package/evidence/egress-verification/run.mjs
```

The actual monitored shell chained the version and script commands with `&&`. Final monitor `mon_3VS17GJ5CKKKQ1DZ`, terminal handle `bash_3`, completed with exit 0. No standing watcher or process is required afterward.

The preceding resident Bun 1.4.4 evaluation also passed the sequence and compatibility functions before the additional standing-weight-only vector was added. An intermediate standalone run (`mon_22N4R9AV22H8QWRP`, `bash_2`) also exited 0. Coverage inspection then added distinct rewards-only/combined rejection, repeat activation, and active full-withdrawal fraction witnesses, and made the abstract output example strictly positive for all positive inputs. The final run above includes these changes and fresh module loads.

One launcher attempt did **not** execute arithmetic: the resident runtime's `process.execPath` was `/Users/cyotee/.omo/binary-runtime/5.1.58/omo`, not a standalone Bun interpreter. Launching it with the evidence filename printed `senpi rpc host: internal_key_unavailable: no key within 2000ms` and exited 137 (`bash_1`, `mon_J380Z43HB1KKPDNW`). It was replaced with the separately located standalone Bun executable. That failed launcher is not a passing check or a production failure; it is recorded so the successful evidence is not confused with it. All three finite monitor sessions terminated.

## Complete final stdout after the version line

```json
{
  "sequences": {
    "principalThenRebase": {
      "principalPaid": "10",
      "originalResidual": "5000000000000000000000000000000000000",
      "walletResidual": "1000000000000000000000000000000000000",
      "postClaimReward": "5",
      "originalReward": "25",
      "finalBacking": "0"
    },
    "boundedWrapperSequences": {
      "cases": 4320,
      "rollbackCases": 4320,
      "principalUnits": "47904",
      "scales": [
        "1000",
        "1000000000000000000000000000000000000"
      ],
      "principals": "1..12",
      "splits": "every 0..n",
      "outputs": [
        "raw",
        "receipt",
        "abstract configured budget"
      ],
      "bothBurnModes": true
    },
    "allowanceAndMixedReceipts": {
      "paid": "30",
      "allowance": "115792089237316195423570985008687907853269984665640564039457584007913129639928",
      "alice": "4600",
      "bob": "2300"
    },
    "roles": {
      "captured": "1581",
      "rolePaid": "4",
      "protectedGift": "530",
      "activePaid": "4"
    },
    "standingWeightOnly": {
      "feeWeight": "10000",
      "totalGons": "0",
      "finalBacking": "0",
      "totalPaid": "20"
    },
    "fraction": {
      "dust": "776",
      "laterPaid": "2",
      "finalBacking": "1",
      "allocationDust": "1"
    },
    "activeFullWithdrawal": {
      "paid": "8",
      "retainedGons": "776"
    },
    "multipleInternalOwners": {
      "closedPrincipalPaid": "10",
      "aliceRewardGons": "2000",
      "bobRewardGons": "3000",
      "voluntarilyMergedPayment": "10",
      "finalBacking": "0"
    },
    "donationsAndSaturation": {
      "unsolicited": "999",
      "canonicalDust": "50",
      "finalBacking": "50",
      "rejectedUnrepresentableGons": true
    },
    "rawWrapperBudgetCases": 72
  },
  "compatibility": {
    "indexCounterexample": {
      "principalShares": "10",
      "k": "500000000000000000000000000000000000",
      "syIndex": "500000000000000000000000000000000000",
      "consumerOwed": "4999999999999999999",
      "actualPaid": "10"
    },
    "ownershipCounterexample": {
      "recordedForOldYTUser": "10",
      "leftForOldYTUser": "0",
      "paidToNewSYHolder": "10"
    },
    "routerCounterexample": {
      "directTicket": "5",
      "directAdapted": "5",
      "oldSelectorRejected": true,
      "upstreamTicket": "5",
      "routerTicketForUpstream": "0",
      "newSelectorAloneAlsoRejected": true,
      "depositToSelfByRouterSucceeded": true
    },
    "conditionalGuardChecks": {
      "busyActivationRejects": 16,
      "parentLockChecks": 5,
      "nestedFundingRestoredPhase": true,
      "staleIndexRejected": true,
      "postEffectsCustodyCovered": true,
      "nftCallbackOwner": "alice"
    }
  }
}
```

## Interpretation and limitations

- `reference.mjs` stores total gon entitlement by slot and derives its reward excess from current principal coverage. It does not import the producer's `Ledger` or use its lazy slot representation. The split checks compare the latter's equations to this independent entitlement representation.
- The funding calculation was derived from the read production `DETFFundedStakingMath` and standing-weight code. It uses `10^54` allocation precision, allocation floors, funded ceiling division and both native dust classes. Initial divisors are 1000 and the actual `10^36`.
- All 4,320 sequences succeed at real model principal departure and later activated reward release. They vary each split from zero to the whole holding, mix another depositor, fund twice, transfer back, exit partially then fully, select external/internal slots, choose same/different receivers, and exercise raw/receipt/configured-output budget branches. They are bounded sequences, not a proof over every uint256 or arbitrary action ordering.
- The 4,320 rejected-minimum checks restore a full transaction snapshot, including simulated initial funding, share changes, reward detachment and principal payment. This deliberately **assumes** EVM transaction rollback. It cannot prove that a production adapter propagates every failure or has installed the correct guards.
- The configured-output arithmetic uses `floor(n*997/100)` solely as a deterministic consumed-budget example, with a strictly positive output for every executed positive input, including partial exits. That is **not** an IndexedEx fee quote, reserve formula, actual `getTokensOut` member, or E3/runtime test result. The report separately traces each production output branch and labels actual route execution unproved.
- The raw-SY cases are simple native-unit budget cases. They do not pretend a raw wrapper has gon-backed yield, a configured receipt route when none was installed, or executed market liquidity.
- Custody queries, busy phases, stale-index rejection, NFT callback ordering and activation exclusion are symbolic checks of the proposed call protocol against read source order. They are not tests of actual proxies. The native parent ERC20 funding calls remain separately authorized.
- F1 executes the actual consumer's WAD `mulDown` expression, including its initial sentinel. F2 deliberately grants a correct native consumer accrual to isolate lost reward ownership from F1's unit mismatch. F3 follows actual `msg.sender` identities for user-pull and YT-push graphs, rather than accepting a caller-supplied beneficiary.
- Ordinary cryptographic permit validation, production signatures, complete overflow limits, gas, initializer/delegatecall closure, selector installation and callback resistance were not executed. No Solidity, Forge, chain, RPC, deploy, production/test/config edit or Git operation ran.
- Automatic JavaScript diagnostics requests timed out for `reference.mjs` and `sequences.mjs`; the Solidity LSP reference request also timed out. These are tooling limitations, not a clean type-check claim. The final standalone runner successfully parsed and executed every authored arithmetic module.
- No task-owned temporary directory, dependency, listener or persistent runtime remains. Only the intended report and evidence files are retained.
