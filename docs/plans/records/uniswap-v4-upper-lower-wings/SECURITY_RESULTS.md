# Security checkpoint

The pure geometry/inventory/reference tests cover part of G1/G3/C5/C7/SEC-06/SEC-07 only. They do not satisfy the full product security requirements. All live-custody, callback, donation, pretransfer, permit, same-state redemption, rebalance manipulation and invariant acceptance gates remain pending.

The executable accounting witnesses deliberately demonstrate the candidate's limitations: positive-V recovery participation transfers, undefined S>0,V=0 division, and non-equivalence of credited input and value growth. A passing witness confirms the arithmetic problem; it does not turn that behavior into an approved policy or certify manipulation resistance. See ACCOUNTING_AND_RECOVERY.md.

No externally deployed code was changed. No known finding is relabeled a passing product security gate.

Validation: artifact build followed by focused tests exited 0 on the approved outside-sandbox retry. Four suites: geometry 8/8, inventory 8/8, full-width vectors 1/1, accounting references 6/6; total 23/23, no skipped tests. Six fuzz properties each ran 256 cases. Full logs and exit records are retained.

## Owner-ruling continuation

PRD v0.4 resolves the old ownership/cost/sleeve/native policy questions. The updated first-depositor witness and two real PoolManager references passed: 25 tests across five suites, zero failures/skips, artifact-first exit 0 (`owner-rulings-tests.log`). The real-pool tests demonstrate zero current realizable target after positive target-only initial funding with zero local sleeve; this is an O2 invariant counterexample, not a passed invariant. See ZERO_VALUE_WITNESS.md for exact state and boundaries.

Latest combined run: 30 passed, zero failed/skipped across six suites, seven fuzz properties at 256 cases each. All five real-oracle sleeve tests passed. The O2 portfolio counterexample remains a design issue pending an invariant-enforcement decision; it is not an accepted money-path failure.

## SEC-08 correction — 2026-10-05

`consumer-manipulation-tests.log` failed `test_externalDepthRemovalDepositRestorationCannotExtractIncumbentTarget` because the attacker redeemed 1293002495260 after depositing 1000000000000. Incumbent V fell from 997272164917 to 544677734372 when external depth was removed, then the attacker's payout plus remaining V conserved the restored book within 5 units. O1 assigns that recovery to outstanding shares. The zero-profit assertion contradicted O1 and was not a production defect.

Replacement witnesses in `UniswapV4UpperLowerWingsStandardExchangeVaultManipulation.t.sol` passed in `family-suite-after-sec08.log`: no overmint at depressed or manipulated V, redemption at or below the pre-exit share, no profit while depth stays removed, JIT rebalance with zero keeper reward, and blocked entry priced at actual V. This is not a completed JIT/keeper/DETF manipulation matrix and not a security certification.
