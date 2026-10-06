# Decision register — owner rulings applied 2026-10-05

The user's six implementation rulings are controlling, recorded in PRD v0.4 O1–O7. They supersede this register's former proposals; do not ask the owner to ratify those proposals again.

| Topic | Controlling instruction | Remaining engineering work |
| --- | --- | --- |
| Unsellable inventory | Exclude from V; no separately owned recovery claim; zero-supply residuals incentivize future interaction | Actual custody remains tracked; count proceeds if inventory later becomes sellable; test manipulation and terminal supply |
| S>0,V=0 | Owner expects this cannot occur given target-only deposits | Test the invariant against real pool conversion and external liquidity changes; no unapproved recapitalization/freeze policy |
| Bootstrap residuals | Give to the first depositor | Implement residual benefit without sink shares; preserve zero-supply lifecycle; establish native-unit scaling using existing conventions |
| Costs | Vault pays from reserves | Exact accounting once; no placement surcharge; prove redemption funding and bound repeated maintenance losses |
| Sleeve | Call liquidReservePercentageOfVault on the Vault Fee Oracle | Use its effective defaults and runtime changes; no hardcoded Wings percentage |
| Native ETH | Routers handle wrapping/unwrapping | Vault remains ERC20-facing and rejects native routes |
| Token routes | Configured PoolKey and target only | Implement PRD/shared target deposit/redemption routes and consumer-required quantity semantics; reject opposing routes |
| Work/gas limits | Engineering obligations | Measure useful domain and total nested cost, report actual constraint conflicts rather than asking the owner for arbitrary constants |

Prior proposed sink allocations, separate depositor placement charges, fixed sleeve defaults, and blanket zero-V route rejection are not approved. Ownership, cost payer, sleeve source and native/token surfaces are no longer open preference questions.

## Concrete engineering finding

The real-pool counterexample in ZERO_VALUE_WITNESS.md demonstrates zero realizable value after target-only funding when the effective sleeve is zero. Following the proposed one-native-unit floor and the owner's instruction to continue implementation, enforce at least one native target unit locally while shares remain (O7), after costs and partial withdrawals. The final redemption releases it. The oracle percentage still controls the sleeve above this minimum. Lifecycle tests must establish the invariant; the reference witness alone does not prove enforcement.

## Engineering limits under validation

Rebalance search evaluates at most 12 candidates with a shared 512-step traversal budget.
The money/maintenance context permits at most 16 pool mutations. A rebalance must increase
core liquidity and retain the target reserve floor. Its implemented maximum value loss is
floor(V_before * (L_after-L_before) / L_after) / 100: a 1% ceiling scaled by actual core
progress, rather than granting the whole ceiling for repeated negligible progress.
This is an engineering choice being tested, not an additional owner ruling or a claim
of sandwich resistance. Full manipulation, repeated-call and outer gas validation remain
required. Caller min-value bounds can only tighten the protocol limit. No caller reward.

Harvest planning/observation functions are now linked library calls, shared across money
and maintenance facets, to keep deployed runtimes within EIP-170 without via-IR. Runtime
artifacts are linked through the existing CREATE3 ArtifactCreationCode workflow.

Sleeve-policy restoration is also progress: increasing the oracle percentage can require
reducing the core to replenish local target reserves. Rebalance therefore measures both
normalized core growth and reduction of the pre-existing target-sleeve deficit. Its loss
allowance is 1% of their combined target-value measure, capped at 1% of V. Closing core
liquidity for this purpose is allowed only when current local target is below the oracle
sleeve requirement. This remains subject to lifecycle/manipulation tests.
