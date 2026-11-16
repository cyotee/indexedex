# Independent r2 verification execution receipt

Date: 2026-11-10. Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03`.

**Both finite evaluations completed normally with all assertions passing in
resident Bun 1.4.4. The construction verdict is nevertheless needs-fix.**
Passing assertions include reproduction of the specified failures; they are
not assertions that the construction satisfies every requirement.

## Provenance and execution

At session start, `ledger.mjs`, `consumers.mjs`, `callers.mjs`, and `run.mjs`
already existed in this verifier-owned directory. They were read completely,
audited against the concrete source and r2, and left unchanged. This session
does not claim authorship of those files or adopt a previous execution result.
Its execution of them is new evidence. None imports a producer model.

This session authored `audit-session.mjs` with apply_patch. It imports only the
inspected independent ledger and consumer modules above. It adds actual
first-index native payout, early reward-token delivery/assignment, a funded
self-deposit with nonzero transit rewards, multiple operators/owners, full
input and native-output rollback, and the source-derived fresh-factory gauge
admission counterexample with an explicitly counterfactual positive control.

Actually evaluated, in order, in the resident JavaScript kernel:

```javascript
const first = await import(
  "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03/docs/incidents/2026-09-16-dtf-recovery/migration/package/evidence/egress-correction-verification/run.mjs"
);
const independentResult = first.run();
const second = await import(
  "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03/docs/incidents/2026-09-16-dtf-recovery/migration/package/evidence/egress-correction-verification/audit-session.mjs"
);
const auditResult = second.auditSession();
```

Each result was printed with BigInts converted to decimal strings. The two
complete returned objects follow. No shell command was needed, so there is
**no shell exit code** to report.

Standalone reproduction commands, **not executed in this session**:

```sh
cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03
bun docs/incidents/2026-09-16-dtf-recovery/migration/package/evidence/egress-correction-verification/run.mjs
bun docs/incidents/2026-09-16-dtf-recovery/migration/package/evidence/egress-correction-verification/audit-session.mjs
```

## Complete first result

```json
{
  "consumers": {
    "originalF1": {
      "r1Native": "4999999999999999999",
      "actualNativeBacking": "10"
    },
    "originalF2": {
      "hypotheticalR1OldClaim": "10",
      "r1OldBackingAfterFullTransfer": "0",
      "r1NewHolderBacking": "10"
    },
    "corrected": {
      "index": "500000000000000000000000000000000000000000000000000001",
      "gonLiability": "5000000000000000000000000000000000000",
      "stockWidthRejects": true,
      "principalPaid": "10",
      "nativeRewardPaid": "20",
      "totalPaid": "30",
      "backing": "0"
    },
    "stageOne": {
      "active": false,
      "rgDelivered": "5000000000000000000000000000000000000",
      "liquidRewards": "0",
      "pendingYT": "0"
    },
    "cohorts": {
      "first": "1555555555555555555555555555555555554",
      "alice": {
        "gross": "2699346405228758169934640522875816989",
        "fee": "269934640522875816993464052287581698",
        "net": "2429411764705882352941176470588235291"
      },
      "bob": {
        "gross": "1143790849673202614379084967320261435",
        "fee": "114379084967320261437908496732026143",
        "net": "1029411764705882352941176470588235292"
      },
      "nativePayments": {"alice": "4", "bob": "1", "treasury": "0"}
    },
    "expiry": {
      "reserved": "5000000000000000000000000000000000000",
      "laterTreasury": "1666666666666666666666666666666666660",
      "nativePayments": {"old": "14", "treasury": "4"}
    }
  },
  "market": {
    "index": "4000000000000000000",
    "inventory": "12",
    "distributed": "10",
    "remainder": ["999999999999999999", "999999999999999998"],
    "fractionWhole": "1",
    "unassignedPlusFractionBacking": "1",
    "exactWideClaims": [
      "2800000000000000000000000000000000000",
      "4200000000000000000000000000000000000"
    ],
    "twoSameBlockDeltas": {"proposed": "10", "cached": "4"}
  },
  "callers": {
    "direct": {
      "principal": "5",
      "entitledRG": "5000000000000000000000000000000000000",
      "rewardPaid": "10",
      "surplusAdapterShares": "2",
      "trace": ["adapter.transferFrom(alice,SY): (adapter,alice)"],
      "fullMinimumRollback": true,
      "wrongCallerAndOwnerRejected": true,
      "marketAdmissionConditional": false
    },
    "yt": {
      "principal": "5",
      "entitledRG": "5000000000000000000000000000000000000",
      "rewardPaid": "10",
      "surplusAdapterShares": "2",
      "trace": ["YT.redeemPYMulti([adapter],[n]); YT.transfer(adapter)"],
      "fullMinimumRollback": true,
      "wrongCallerAndOwnerRejected": true,
      "marketAdmissionConditional": false
    },
    "market": {
      "principal": "5000",
      "entitledRG": "4500000000000000000000000000000000000000",
      "rewardPaid": "9000",
      "surplusAdapterShares": "2",
      "trace": ["market.burn(adapter,receiver,n); market.transfer(adapter)"],
      "fullMinimumRollback": true,
      "wrongCallerAndOwnerRejected": true,
      "marketAdmissionConditional": true
    },
    "self": {
      "principal": "5",
      "entitledRG": "0",
      "rewardPaid": "0",
      "surplusAdapterShares": "2",
      "trace": ["adapter funds SY.deposit(SY): (adapter,adapter)"],
      "fullMinimumRollback": true,
      "wrongCallerAndOwnerRejected": true,
      "marketAdmissionConditional": false
    },
    "originalF3": {
      "directOldRejects": true,
      "directTypedPaid": "5",
      "push": {
        "YT": {"sourceTicket": "5", "routerTicket": "0"},
        "market": {"sourceTicket": "5", "routerTicket": "0"}
      }
    },
    "freshGaugeFailure": {
      "localFactoryRegistered": true,
      "cached": false,
      "configuredFactoryMatches": 0,
      "error": "GCNotPendleMarket(market)",
      "firstMintBlocked": true,
      "syHarvestRolledBack": true,
      "pendingPendle": "0"
    }
  },
  "bounded": {
    "cases": 608,
    "nativePrincipal": "8352",
    "nativeRewards": "4912",
    "residualOwners": 1134,
    "wholeTransactionRollbackCases": 608,
    "fractionalTransfer": {"retained": "776", "later": "2"},
    "roles": {"captured": "1581", "paid": "4", "residual": "85"},
    "saturation": {"total": "0", "backing": "50", "dust": "50"},
    "preservedBond": {
      "principal": "10",
      "originalBondReward": "25",
      "postClaimReward": "5"
    }
  },
  "transit": {
    "inputOwnerRight": "384615384615384615384615384615384615",
    "oldAdapterRight": "153846153846153846153846153846153846",
    "nativePaid": "0"
  },
  "verdict": "needs-fix",
  "nature": "Source-derived arithmetic and caller proofs, not runtime acceptance"
}
```

## Complete supplementary result

```json
{
  "firstPayout": {
    "principal": "10",
    "stageOneNewUserRG": "4500000000000000000000000000000000000",
    "stageOneNewTreasuryRG": "500000000000000000000000000000000000",
    "stageOneNativeReward": "0",
    "activatedAssigneeNative": "9",
    "activatedTreasuryNative": "1",
    "totalNativePaid": "20",
    "finalBacking": "0"
  },
  "selfDeposit": {
    "principal": "5",
    "transit": "2500000000000000000000000000000000000",
    "nativeReward": "5",
    "finalBacking": "0",
    "fullInputAndOutputRollback": true
  },
  "tickets": {
    "principal": "10",
    "aliceReward": "4",
    "bobReward": "6",
    "wrongTicketRejected": true,
    "finalBacking": "0"
  },
  "gauge": {
    "failingLocalRegistration": true,
    "failingPendleDue": "0",
    "firstMintRejected": "GCNotPendleMarket(market)",
    "conditionalAdmittedPrincipal": "5000",
    "conditionalAdmittedReward": "9000",
    "lockedReserveRG": "500000000000000000000000000000000000000",
    "counterfactualAdmissionOnly": true
  }
}
```

## Evidence interpretation and limitations

- Canonical funding uses the read `DETFFundedStakingMath` allocation precision
  `10^54`, floor allocation and ceiling divisor. The verifier stores total
  physical gons by slot, rather than using r2's lazy `shares*lastK` state.
  Escrow and RG liability are separate; RG is not counted as additional gons.
- The 608 cases are `Q in {1000,10^36}`, `n=1..16`, every split `0..n`, and two
  funding amounts. They use mixed deposits, transfers back, repeated funding,
  approvals, internal tickets, principal exits, materialization, activation,
  native reward withdrawal, retained modulus and duplicate rejection.
  They do not repeat the old 4,320 attached-reward cases as proof of r2.
- YT liabilities are computed separately from the source's reward shares,
  sentinel and WAD multiplication. Native fee/user payments sum to funded
  custody. The supplementary 9+1 payout occurs at the first funded index;
  the 20 payout occurs after additional funding and complete principal exit.
- A zero native payout is not substituted for a success witness. The original
  transit example is honestly zero at its current divisor. The supplementary
  self-deposit pays both 5 principal and 5 funded native rewards. For cohorts,
  nonpayable fee fractions remain RG; the separate 9+1 witness proves an actual
  positive treasury payout.
- Market tests use active balances, not raw LP balances. The LP witness
  includes the source's minimum 1,000 LP held at address(1). With no ve boost,
  active weights are 400 reserve and 3,600 user. The 9,000 user reward excludes
  the reserved LP's 1,000-unit equivalent; it does not award locked LP rewards
  to the withdrawing user.
- The gauge counterexample evaluates the actual four-registry/cached-market
  predicate, not a fake payment failure. Adding recognition in the positive
  control is explicitly a hypothetical prerequisite, not an implemented or
  authorized registration method. Current source exposes no generic setter
  that makes a newly chosen factory recognized by an existing controller.
- The producer's 10-LP market example evaluates a ratio but is not a reachable
  fresh market with source minimum liquidity 1,000. This verifier uses a
  10,000-LP conditional witness. Admission still prevents claiming a complete
  supported deployment graph.
- PT-swap sender/budget edges and the actual trade formulas were read, but no
  logarithmic swap computation or successful market lifecycle was executed.
  The report does not call the LP ratio a PT-swap proof.
- Snapshot restoration deliberately models EVM atomicity. The rollback
  checks include modeled funding, inputs, allowances, consumer fields,
  reserve amounts, tickets, gons, RG and output effects where those fields
  exist. They do not execute EVM revert propagation, actual contracts,
  cryptographic approvals, pool output transfers, callbacks or factory calls.
  Canonical SY allowances decrement max; Pendle PT/YT/LP source preserves max.
  The symbolic finite input-allowance examples do not establish that distinction
  at runtime.
- Domain-1 old/new role allocations remain unchanged by r2. Their 1,581-gon
  captured right pays 4, retains 85 and repeats zero. The original principal
  ledger's evidence stands for unchanged equations. The new `preservedBond`
  row is algebra only, not a newly executed bond lifecycle.
- No all-uint256 proof, gas bound, deployment, actual market/treasury
  configuration, installed phase guard, selector cut or E4/E5 result is claimed.

## Diagnostics and resource completion

`lsp_diagnostics` on the newly authored `audit-session.mjs`, severity `all`,
returned `No diagnostics found`, zero diagnostics, not truncated. Both finite
resident evaluations parsed and executed their complete module dependencies.
No Solidity diagnostics, compiler or runtime result is inferred.

One initial helper-cell definition was rejected by the eval parser with
`Unexpected identifier 'await'. Expected a ';' following a return statement.`
It preceded evidence execution, changed no files and was replaced with an
async function expression. Neither arithmetic run failed.

No child process, monitor, node, listener, RPC connection, temporary directory,
worktree, dependency or cache was created by this verifier. There is no pending
runtime to clean up. Tool-managed resident/LSP infrastructure was not treated
as an owned service. No Forge, install, Git, commit, broadcast, external
message or delegation ran. Producer files and all historical evidence remain
unmodified. Only the report, this receipt and `audit-session.mjs` were authored
in this session.
