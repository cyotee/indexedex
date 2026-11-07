# F1 - PRD and failure-ledger audit

Date: 2026-11-07. Disposition: complete for the requested scope.

The final default receipt, `54-final-default.log`, has 2,660 suites and
28,411 passing counted cases, zero failures or skips, exit 0. All 36
original failure identities match exact passing contract/method pairs.
All 48 acceptance IDs remain present and unique: 42 active rows expand
to 103 named controls, all matched to PASS; A12-A16 remain withdrawn and
A30 remains a reporting boundary. Selected controls are not inflated into
claims about unconstructed state combinations.

Nine standalone FullSpread configurations contribute 179 passing cases;
nine inherited configurations contribute 194. Their 373 cases are a
subset of the default total. All seven topologies execute real registered
proxies; H1 is conversion-only, not an invented LP product.

The user's clarification controls funding: every required genesis leg
accepts pair tokens or SE shares, while ongoing caller-funded single-leg
preparation remains supported. Actual acquired/preowned shares fund the
five-percent redemption. Native component acceptance follows paid trades;
backed gross LP splits into net and protocol LP, with the locked floor
excluded from fee issuance. No earlier rejection-only interpretation is
retained as authority.

Capability limits remain explicit in `17-capabilities.md`: unsupported
inverse operations, unprojected sequential views and unavailable share-only
payout conversions reject rather than inventing state or mixed output.
Disjoint backing is not same-backing-pool sequential proof. The recorded
own-credit rejection is not relabelled an unexecuted own-negative-debt
construction.

Publication validation parsed all four audit JSON documents and the new
source manifest. All 196 non-V4 matrix rows, including seven V3 rows, all
107 non-R10.3 acceptance items, historical finding descriptions and the
historical independentReview object are unchanged. Matrix states reconcile
to 197 COMPATIBLE, seven DEPRECATED, one INCOMPATIBLE and zero BLOCKED.

Current evidence: `01-acceptance-ledger.md`, `56-final-summary.md`,
`57-source-identity.json`. Historical exact control/alias tables remain
in `20-matrix-publication-handoff.md`; their identities were rechecked
in the final receipt, not counted as fresh tests by reference alone.
