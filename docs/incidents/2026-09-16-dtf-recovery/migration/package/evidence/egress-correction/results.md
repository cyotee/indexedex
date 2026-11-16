# Egress correction: deterministic execution receipt

Date: 2026-11-10. Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03`.

**Final run passed, exit 0, standalone Bun 1.4.2.** This is bounded arithmetic
and caller evidence for `../../egress-contract-r2.md`, not runtime SUT testing.

## Reproduction and execution history

Executed:

```sh
cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03
/opt/homebrew/bin/bun --version
/opt/homebrew/bin/bun docs/incidents/2026-09-16-dtf-recovery/migration/package/evidence/egress-correction/vectors.mjs
```

The actual finite monitor command chained these commands with `&&`.
Final monitor `mon_BA7JAAY84KFRMHW4`, terminal `bash_4`, completed with exit 0.
It includes explicit wrong-operator and wrong-owner negatives for direct pull,
both upstream pushes and funded self deposit, and the complete vector runner.

Earlier executions, retained here rather than presented as all-green:

| Execution | Observed result and disposition |
| --- | --- |
| Resident import, Bun 1.4.4 | Failed `vectors.mjs`'s assertion that `5*10^36` exceeds uint128. It does not; the index exceeds uint128. Corrected to accept that amount and reject the larger source-derived accrual for 10,000 native shares. |
| `mon_W2X99J8RK4ZHAEXK`, `bash_1`, standalone 1.4.2 | Exit 0 for the first coherent correction vectors. |
| `mon_F6NXAPFPZRNN39JM`, `bash_2` | Exit 1 after adding transit attribution: complete snapshot comparison found a newly created `inputCaller` property survived Object.assign restoration. Fixed the model rollback helper to remove speculative fields before restoring the old state. The comparison was preserved. |
| `mon_NDN467P1YTQ11Y3Z`, `bash_3` | Exit 0 for expanded expiry, consumer fractions, transit, receipt transfer, k=1 and width vectors. Full output captured. |
| Final monitor/terminal above | Exit 0 after adding every push/self-deposit wrong-operator and wrong-owner negative. Numeric transition equations/output are unchanged from bash_3; decisive final lines independently confirm first payout 10, expired principal 10, sequences 360, issued gons 0 and same-block RG accrual 10. |

No repository test was edited, suppressed, skipped or redefined. These
new scripts are explicitly construction evidence, not production tests.

## Files and oracle separation

* `ledger.mjs`: proposed r2 ownership/materialization/native-release transitions.
  It imports the immutable independent `../egress-verification/reference.mjs`
  for canonical funded allocation, rebase, physical ledger and non-SY paths.
  It overrides old SY transfer/redemption/claim semantics explicitly.
* `consumer.mjs`: source-derived YT sentinel, reward-share, native multiplication,
  fee and expiry expressions, plus explicit local width and remainder/cadence
  corrections. It does not infer liability by querying wrapper accrued rewards.
* `callers.mjs`: explicit operator/owner tickets, input ownership/allowances,
  actual upstream sender identities, source LP output ratio, operation budgets
  and whole-model rollback snapshots.
* `vectors.mjs`: positive/negative sequences and invariants. It does not import
  or execute Solidity, an EVM, RPC or the production system.

Every retained source amount is an integer. WAD is `10^18`, production Q is
`10^36`, canonical funding precision is `10^54`. Readable Q=1000 is explicitly
separate. There are no floating-point reward calculations or timing waits.

## Actual results

The values below are compact records of the executed runner output. Gons are
native units of the **proposed actual RG token**, not native sDETF.

### Production native reward boundary and old YT ownership

```json
{
  "initialIndex": "1",
  "index": "500000000000000000000000000000000000000000000000000001",
  "badR1NativeLiability": "4999999999999999999",
  "gonAccrual": "5000000000000000000000000000000000000",
  "nativeRewardAtFirstFunding": "10",
  "actualFirstNativePayout": "10",
  "principalPaidDuringStageOne": "10",
  "rightsTransferredDuringStageOne": "5000000000000000000000000000000000000",
  "laterNativePaid": "20",
  "totalNativePaid": "30",
  "finalBacking": "0",
  "unmodifiedUint128Rejected": true,
  "duplicatePaid": "0"
}
```

**Implemented-source expression:** `floor(rewardShares*(index-prevIndex)/W)`,
with unset prevIndex replaced by 1; at constant principal rate W, initialized
user rewardShares equals its YT balance. The r1 over-accrual is reproduced.

**Proposed behavior actually evaluated:** ten SY principal units, funding 10,
pre-burn YT checkpoint, SY to a different receiver, principal exit 10, old
holder's RG claim, funding 10 after principal departure, activation and native
reward payout 20. Original user's RG balance does not rebase; its native value
does. The new principal receiver receives zero old reward. An independent
first-funding branch actually pays 10 native units without waiting for the
second funding. Duplicate materialization/payout and wrong-owner native
redemption are rejected or zero as specified.

**Not proved:** the local wide Solidity consumer, real token custody calls,
factory deployment, installed guards and native token transfers.

### Cohorts, fees, transfers and expiry

```json
{
  "cohorts": {
    "aliceGross": "2699346405228758169934640522875816989",
    "aliceFee": "269934640522875816993464052287581698",
    "aliceNet": "2429411764705882352941176470588235291",
    "bobGross": "1143790849673202614379084967320261435",
    "bobFee": "114379084967320261437908496732026143",
    "bobNet": "1029411764705882352941176470588235292",
    "firstAccrualRetained": "1555555555555555555555555555555555554",
    "materialized": "3843137254901960784313725490196078424",
    "lateCohortPriorAccrual": "0"
  },
  "expiry": {
    "reservedUserGons": "5000000000000000000000000000000000000",
    "userPaidGons": "5000000000000000000000000000000000000",
    "newTreasuryGons": "1666666666666666666666666666666666660",
    "oldRightsNativeValue": "14",
    "postExpiryPrincipalPaid": "10"
  }
}
```

**Source behavior:** reward checkpoint precedes YT balance mutation; fee is
`floor(gross*feeRate/W)`; first expiry harvest reserves actual token inventory;
post-expiry PY redemption burns PT only and reward indexes freeze.

**Proposed evidence:** old accrued RG remains with Alice after a YT transfer;
Bob's later deposit gets no prior accrual. Exact gross equals materialized
funding, with fees plus user outputs conserving it. During locked-stage expiry,
user RG remains reserved while new RG goes to treasury; old RG appreciation
stays the user's. Ten expired principal units successfully leave while the
expired YT balance remains, following source PT-only redemption. Treasury
repeat is zero. These are integer transitions, not a live expiry transaction.

### Bounded principal and fraction witnesses

```json
{
  "bounded": {
    "sequences": 360,
    "fullRollbackCases": 360,
    "principalPaid": "3992",
    "retainedNativeFractions": 686,
    "scales": ["1000", "1000000000000000000000000000000000000"]
  },
  "preservedPrincipal": {
    "originalBondGons": "5000000000000000000000000000000000000",
    "postClaimWalletGons": "1000000000000000000000000000000000000",
    "principalPaid": "10",
    "laterWalletPaid": "5",
    "laterBondPaid": "25",
    "finalBacking": "0"
  },
  "roles": {"capturedGons": "1581", "paid": "4", "retainedGons": "85"},
  "receiptTransfers": {"principalPaid": "30", "aliceGons": "4600", "bobGons": "2300"},
  "fraction": {"firstPaid": "1", "transferredGons": "776", "laterPaid": "2", "retainedGons": "0", "backing": "1"},
  "boundaries": {
    "saturationIndex": "1",
    "retainedNativeDust": "50",
    "finalIssuedGons": "0",
    "fullPrecisionQuotient": "57896044618658097711785492504343953926634500000000000000000000000000000000000",
    "narrowIntermediateRejected": true,
    "duplicateActivationRejected": true
  }
}
```

Every `n=1..12`, every split `0..n`, two funding magnitudes, and both scales
run. Mixed deposits, repeated funding, transfer back, internal principal
tickets, raw principal exit and receipt principal exit all succeed. The
minimum-failure branch includes funding inside its speculative operation,
then restores all modeled state. This assumes EVM transactional rollback;
it does not test actual exception propagation or output-token callbacks.

Canonical source funding, principal floor/ceiling and role order are reused
from the independent reference. Invariant checks count RG **only as a claim
on existing escrow gons**, never as extra physical gons or backing. No supply
is invented by materialization. Every owner payout retains the exact modulus.
The 776-gon right is transferred while it is sub-native, then actually pays 2
after another real funding in the model. At production k=1, later funding 50
remains canonical dust; principal and reward payouts leave no issued gons.
These checks do not prove unlimited uint256 lifetime accumulation.

### Standard market reward math and local precision delta

```json
{
  "funded": "7000000000000000000000000000000000000",
  "index": "1400000000000000000000000000000000000000000000000000001",
  "claims": [
    "2800000000000000000000000000000000000",
    "4200000000000000000000000000000000000"
  ],
  "retainedMarketNativeGons": "1",
  "carriedRemainders": ["999999999999999999", "999999999999999998"],
  "mergedWholeGon": "1",
  "sameBlockLocalPaid": "10",
  "sameBlockCachedPaid": "4"
}
```

The source expression is native reward balance delta divided by **active
supply**, followed by each active balance's native reward multiplication.
The 7Q vector uses active weights 2/3. A second nondivisible vector uses native
reward amounts 10 and 2 against active weights 1/2. The source whole-unit floors
are executed separately from the proposed retained numerator carry. Merging
the two carried numerators forms one whole gon and leaves one actual gon of
market inventory, backing remaining fractional/undistributed value.

The same-block comparison executes two deltas 4 and 6 against supply 2:
the local RG cadence processes both; the old cached index processes only the
first before the modeled balance change. This is a deterministic comparison
of index expressions/cadence, not an executed block or gauge-controller call.
The production remainder assignment's caller guard and the unrelated PENDLE
path remain runtime obligations; no PENDLE economics change is inferred.

### Caller identities, positive output and negative ownership

| Path | Actually evaluated positive transition | Negatives/retention |
| --- | --- | --- |
| Direct pull | Adapter pulls Alice5 -> ticket(adapter,Alice) ->5 native principal | Mallory input ownership, wrong operator, wrong ticket owner and min6 reject; old Alice reward5Q remains hers. |
| YT upstream push | YT transfers5 SY to external adapter; adapter transfers5 to SY -> ticket(adapter,adapter) ->5 native principal | Wrong input owner, wrong internal caller/owner and min6 reject. Existing adapter2 shares remain. YT retains5Q old reward gons. |
| Market LP upstream push | `floor(5*10/10)=5` from actual MarketMathCore ratio; market transfers5 SY to adapter; same own-ticket onward exit | Same negatives and2-share surplus protection. Market retains5Q old reward gons. Actual LP reserve writes and logs are not executed. |
| Funded self deposit | Actual model funding5 -> internal(adapter)5 and ticket(adapter,adapter)5 ->5 principal | Wrong caller/owner and min6 reject; final backing0. This is not funding from old wrapper inventory. |
| Unmodified upstream-to-SY route | Actual ticket is(YT,YT) | Adapter cannot spend it through old/internal-owner selectors. YT as the actual ticket owner can exit5, proving the guard is not an all-revert construction. |
| Transit funding | Five operation shares and two old adapter shares coexist through real funding5 | Input user's new right is384615384615384615384615384615384615 gons; prior adapter's separate right is153846153846153846153846153846153846. No total-balance-delta shortcut assigns the old shares' growth to the new user. |

The model has real distinct symbolic sender/operator/owner values and checks
the required inequalities. It does not claim to authenticate an Ethereum
caller cryptographically or simulate actual PT/LP/ERC20 allowance code.
Market PT-swap pricing is deliberately not replaced by a constant-price
model; r2 specifies its actual production call and output-delta budget.
Both required upstream sender classes are positively demonstrated here.

## Source fingerprints

SHA-256 of complete inspected `read` text, not deployed bytecode:

| Worktree-relative source | SHA-256 |
| --- | --- |
| `contracts/vaults/detf/common/core/DETFFundedStakingMath.sol` | `3ec13e4bb20549f5e3055e63212d6518cdc011bb616bab2783e22e5c7a20ba06` |
| `lib/crane/contracts/protocols/perps/pendle/core/RewardManager/RewardManagerAbstract.sol` | `f7722ffad4b1093ef8004b27195da428c7c6057d1b72681600bf416cd9268be4` |
| `lib/crane/contracts/protocols/perps/pendle/core/RewardManager/RewardManager.sol` | `1c1015603789d0fd887ac88b5bf545e385171521c10b203be58c29758f550721` |
| `lib/crane/contracts/protocols/perps/pendle/core/YieldContracts/PendleYieldToken.sol` | `279050ffca029e064e3b90b8d7d6fd8b262e504fcddb4a3a1b1bacc9901a27ca` |
| `lib/crane/contracts/protocols/perps/pendle/core/Market/PendleGauge.sol` | `29d175f1ced747c24eb1903bdad14bee60ed28e42cd24ba19a3745754caade14` |
| `lib/crane/contracts/protocols/perps/pendle/core/Market/v3/PendleMarketV3.sol` | `32e72382241dbd030a140b982ebf14b4f89e6607ab8b9af377eabb08b399c32e` |
| `lib/crane/contracts/protocols/perps/pendle/router/base/ActionBase.sol` | `6bd028676be8ae8dee78b503e68947e273b395926ff8027d7f6a3206639dc17b` |

## Limits and cleanup receipt

No production/test/config file was changed. Prior r1 and verifier inputs were
only read/imported. No Forge, install, Git, commit, deploy, broadcast, delegation
or external message ran. All four finite monitor processes terminated:
three exit 0 and the explained model-error run exit 1. No temporary directory,
listener, node, dependency or cache was created; no cleanup deletion was needed.

JavaScript LSP refresh requests timed out. The final standalone interpreter
parsed/executed all four owned scripts and their read-only reference import;
that is not a clean LSP/type-check or Solidity compilation claim. The scripts
have separate responsibilities (ledger, consumer expressions, caller paths,
vectors), each below 200 nonblank/noncomment lines; they consume no external
untyped input, introduce no production seam and install no dependencies.

The construction still requires independent review and later real-proxy
implementation tests. E1/E2, actual recovery E3, BOOTSTRAP-AUTH and runtime E4/E5
remain open. No owner answer or production acceptance is inferred.
