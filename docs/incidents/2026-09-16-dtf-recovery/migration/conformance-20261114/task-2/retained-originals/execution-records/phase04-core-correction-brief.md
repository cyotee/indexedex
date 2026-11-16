# Phase04 core correction: F1 and V1

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-04`.
Continue the same core DAG and existing source state. Do not replay completed
component implementation or discard any evidence.

Read the complete `migration/core/verification/report.md`, its source-backed
F1 witness and V1 coverage limit, and the original phase04 brief and accepted
r3 requirements. Paths below beginning `migration/` are under the worktree's
`docs/incidents/2026-09-16-dtf-recovery/`.

## F1: required other-leg capital

Fix `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol`,
especially the bootstrap body around lines 168-181 and conversion path.
Every non-anchor leg must supply at least the canonical opening-price
pair-equivalent capital required by the actual generated self amount.
Reuse the actual `_firstBondOtherPayment(G,pair)` semantics and rounding from
the ordinary target; do not invent a new price, cap, haircut or exact-balance
restriction. Adequate excess capital remains valid.

The independently executed 100-token anchor / 1-token other leg at a 100-token
required minimum must now reject atomically. Preserve that historical witness
unchanged. Add a real regression alongside existing core tests that fails on
the current defective source and passes after the fix. Cover the one-unit
boundary, equality, excess, alternate anchor, relevant decimal scaling and
actual consumed-capital/preview consistency where not already covered.
Assert failed genesis leaves supply, live state, budgets, balances, allowances
and external reserve/SE state unchanged.

## V1: execute both installed Permit2 donation paths

Do not treat `Permit2ContractNotDeployed()` as positive route coverage.
Exercise real proxy
`donateWithPermit2Allowance(address,uint256,uint256,uint256)` and
`donateWithPermit2Signature(address,uint256,uint256,uint256,bytes)`
against a genuine Permit2 implementation at the canonical address used by
the unchanged production code. Inspect and use the repository's legitimate
counterparty deployment/fixture patterns.

Prove positive allowance and signature donations, correct principal/LP
destination, actual token deltas, allowance/nonce changes, and complete
rollback for the relevant deadline, nonce, caller, signature and downstream
minimum/callback failures. Use valid surrounding inputs when isolating each
negative, so an earlier unrelated rejection does not masquerade as coverage.
Record the actual chain ID/domain/verifying-contract binding and counterparty
runtime identity; copied runtime with another deployment's cached EIP-712
domain is not an honest canonical fixture.

No mocked successful Permit2, signature verifier, SUT parent impersonation,
SUT etch/storage injection, broad fake-call recording or skipped test.
Do not change the production Permit2 address or add a new dependency setter
to make a fixture pass. If genuine canonical setup needs an action beyond the
existing fixture rules, identify the exact need to root while finishing F1;
do not silently bypass the rule.

## Exact permitted edits

- The Migration allocation target above.
- Its existing new Migration interface only for a genuinely necessary custom
  error declaration; no new policy or external configuration surface.
- Relevant existing/new core regression tests under the TM migration tree and
  `M/TestBase_UniswapV4DetfMigration.sol` only for legitimate reusable setup.
- If the new genuine Permit2 execution exposes an actual guard/routing defect,
  the existing new Migration parent/bond policy targets may receive a narrow
  fixed-caller correction after documenting the failing execution. Do not
  broaden phase admission or alter ordinary behavior.
- New evidence only under `migration/core/correction/`.

No other production, shared Crane, configuration, dependency, old verification
report or historical witness may be edited. No commits by correction nodes.
Ask root for a concrete additional path only if indispensable.

## Verification and reporting

One producer performs the fix/proofs and the necessary changed-input checks;
one independent verifier follows. Use the same warm worktree, explicit owned
runtime/cache paths and artifact-first Solar workflow. No concurrent compiler.

First capture the new failing regression against the defective source, then
fix the minimum-capital condition. Retain the failure and all setup/compile
attempts. Run the complete focused TM scope and the established combined
ordinary/common/pricing scope on the corrected code once; repeat only after
a new change or failure. Actual executed counts and exit 0 are mandatory.

Because production genesis changes, repeat the brief's exact two-stage owned
18548 local QA on corrected artifacts. Preserve all previous runs in their
original directories; capture new command/receipt/node/source identities.
Keep current-owner genesis, actual on-chain configuration-ID lookup, no
configured supply, mature closed-stage principal, role-beneficiary rewards,
RT/remainders, irreversible selector removal, EIP-170 and cleanup intact.
No new operator/resume or historical-recovery acceptance is claimed.

Producer output: `migration/core/correction/report.md`.
Independent output: `migration/core/correction-verification/report.md`,
with other independent evidence only in that directory.
The verifier must independently execute the former underfunding case against
the fix and check the genuine positive/negative Permit2 evidence and current
source/artifact bindings. It should not repeat a large passing suite without
a changed input, failure or specific unresolved concern.

No terminal DoneClaim while a required run, report or cleanup is pending.
Use a durable child objective/native continuation where supported. Final
verdict must explicitly dispose of F1 and V1 and retain the untouched legacy,
surrender, recovery, operator and release gates. Owner/source policy is not
changed by this correction.
