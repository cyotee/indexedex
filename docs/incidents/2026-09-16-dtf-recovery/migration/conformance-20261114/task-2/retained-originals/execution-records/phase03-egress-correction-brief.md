# T5-EGRESS correction contract

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03`.
Current committed preparation: `6d82859ee0b20804a4ced6e7a5ae395a49f5cdfd`.
This is a construction correction, not production implementation.

Read completely:

- `migration/package/egress-contract.md`, final 701-line r1, SHA-256
  `5104e78908e38274c987b7e8dfcd2e291373d984c78d919908a5f11f4bcb0506`.
- `migration/package/egress-verification.md` and its actual counterexample
  sources/results.
- The phase03 implementation brief, complete implementation handoff, applicable
  Migration plan and repository rules.

All `migration/` paths above are relative to
`docs/incidents/2026-09-16-dtf-recovery/` in this worktree.

## Required corrections

F1: `Q-k` gon indexes are consumed as WAD-scaled native reward-token accrual.
At production Q, ten funded native rewards become a downstream liability of
4,999,999,999,999,999,999. Fix the complete standard reward boundary: unit,
initial sentinel, native payouts, retained fractions and rebasing treatment.
Relabeling or dividing the first example by a constant is insufficient.

F2: the actual YT consumer retains its users' accrued reward claims when it
returns SY. The r1 SY packet sends the same old reward gons away with those
shares, leaving that retained claim unbacked. Define one ownership settlement
boundary; no right may simultaneously support a retained consumer claim and a
new share holder's claim. Locked economic rights must remain correctly owned;
do not classify their transfer as forbidden payout merely to avoid accounting.

F3: direct pull produces `(router,user)` tickets, but actual YT/market pushes
produce `(YT,YT)` or market tickets while a router redeems onward. Merely
replacing the final call with `redeemInternal(owner,...)` cannot authenticate
that router. Complete the actual typed sender/operator/beneficiary handoff or
correct the wrapper boundary so the required existing call graph works. Do not
restore arbitrary spending of aggregate self inventory as a hidden fix.

Use the concrete vendored consumer anchors in the independent report. The
interface alone does not specify reward-index units; actual RewardManager
does. Constant principal `exchangeRate=1e18` was not independently rejected.

## Scope and invariants

Preserve the verified exact native-principal packets, real funded gon/backing
conservation, mature-principal exits during Stage 1, retained reward ownership
after principal departure, role allocation identity, fractional rights and
exact-once activation release. Preserve ordinary products.

Return one complete corrected construction, not a menu, blanket pause,
unfunded conversion, scalar-only index patch, silent compatibility exclusion,
or invented owner-policy question. Prefer a wrapper-local solution. If typed
adapters are genuinely necessary, name exact local adapter boundaries and the
entire production call graph, including what authenticates each handoff.
Shared Crane/vendored consumer edits are not authorized. Do not expand the
task into unrelated Pendle protocol modifications or claim generic external
router acceptance without evidence.

The original r1 and verification report/evidence are immutable historical
inputs for this correction. Author:

- `migration/package/egress-contract-r2.md`
- Optional bounded arithmetic model/results only under
  `migration/package/evidence/egress-correction/`

Independent reviewer:

- `migration/package/egress-correction-verification.md`
- Arithmetic evidence only under
  `migration/package/evidence/egress-correction-verification/`

No production/test/config edits, Forge runs, installs, Git operations,
commits, broadcasts, delegation or changes to another lane's files.
Use apply_patch for authored files. Retain original evidence and explain
which equations/ABI/storage/ownership rules changed.

## Evidence required

Model the actual source-derived standard consumer expressions and caller
identities, independently from the wrapper's own equations. Include:

1. Exact native reward accrual and payout at production Q, initial sentinel,
   repeated funding, multiple cohorts, transfers and payout rounding.
2. YT user retains accrued reward after principal SY leaves to a different
   receiver; both principal exit and original reward payout succeed without
   double attribution or missing backing.
3. Direct router pull, YT upstream push, market upstream push and router-funded
   self-deposit all have explicit positive authorized paths and negative wrong
   caller/owner paths. Min-output failure restores the entire operation.
4. Original mature-principal/rebase/exit/activation conservation, residual and
   duplicate-release cases still hold under changed SY semantics.

These are source-backed arithmetic/caller proofs, not runtime SUT tests.
Each result must distinguish implemented source behavior, proposed behavior
and unproved production integration. The independent reviewer actively seeks
counterexamples rather than only rerunning the author's model.

Stop at a complete corrected contract with precise implementation boundaries,
actual deterministic results, limitations and cleanup, then independent
ready-for-implementation or needs-fix. E1/E2, actual recovery E3,
Runtime E4/E5 remain open. BOOTSTRAP-AUTH was subsequently resolved by the
current user: current-owner-only pooled genesis, with permissionless
contributions and subsequent ordinary donations. The source/attribution
questions remain unanswered.

## R2 review focus

The delivered r2 proposes an actual transferable reward-rights ERC20, permits
its materialization through SY claimRewards before activation, and introduces
local wide-integer YT/reward-manager/gauge/market variants with fresh factory
configuration. These are material integration and scope changes, not merely
an index-unit fix.

Independently check two boundaries before accepting the construction:

- Does preactivation claimRewards returning a newly transferable reward token
  satisfy the plan's activation-gated reward-payout requirement, including its
  explicit prohibition on early fee/creator receipt delivery? Identify the
  admitted requirement that distinguishes permitted transfer of an existing
  locked right from a newly issued reward payout; do not settle this by naming
  the new token a right.
- Are the local consumer variants genuinely the minimal required Migration
  integration, with exact preserved behavior and required callers, or do they
  introduce an unrequested protocol/deployment scope? Shared-source immutability
  alone does not establish that any local fork is in scope. Do not claim
  unmodified standard consumers compatible when only new variants work.

This is a verification requirement, not authorization to implement those new
components, a predetermined rejection, or a new owner-policy decision.
