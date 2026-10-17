# Astra plan draft — REQ-02 internal residual preview

- **Date:** 2026-10-14
- **Status:** Draft implementation plan; does not authorize code edits. Implementation and execution require a separate request.
- **Controlling PRD:** `docs/reviews/apex-req-02-residual-preview-internal/REMEDIATION_PRD.md`, read in full. It controls over this draft.
- **Scope:** Visibility of the single-CP residual preview and the two required production-path regression cases. This is not a new defect review and does not reopen REQ-C04.

## Objective

Make `previewResidualBuffer` internal while preserving its direct Standard Exchange quote. Preserve every existing sweep's successful-zero stop and positive-preview deposit. Prove, through the existing production TestBase, that an SE zero leaves excess in hook custody and that an SE preview revert rolls back the parent operation.

No reviewer artifacts or the coordinator's `REMEDIATION_PRD.plan.md` were read. No source, tests, configuration, or scripts were edited. The PRD and all named source/TestBase reads succeeded.

## Current source and route map

For the table below, `C/` means:

`contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/`

Every abbreviated source filename below has the prefix `UniswapV4SingleStandardExchangeBufferConstantProductHook`, unless it is the explicitly named TestBase.

| Function / file | Current lines read | Entry and reachability |
|---|---|---|
| `C/...ClaimLib.sol`, `previewResidualBuffer` | 382-389 | Currently external; reads the configured pair/SE and directly returns `previewExchangeIn`. No catch or zero rejection. |
| `C/...ClaimLib.sol`, `bufferQuotedResidual` | 391-399 | External; approves, deposits with the quoted minimum, then clears approval. Leave unchanged. |
| `C/...DepositCommon.sol`, `_refundPairDust` | 367-378 | `_deposit` reaches it after sync at 489-491; `_depositWithSeShares` reaches it at 580-582; `_depositSingle` reaches it at 710-712. |
| `C/...WithdrawalLib.sol`, `refundPairDust` | 131-141 | `withdrawFrom` calls it after sync at 64-66. `WithdrawTarget._refundPairDust` also delegates here at 338-340. |
| `C/...Target.sol`, `_refundPairDust` | 388-399 | Source-level callers exist in `_deposit` (844-846), `_depositSingle` (971, search), `_withdraw` (1137-1139), and `_withdrawSingle` (1213-1215). This is an abstract aggregate; installed-proxy reachability is not established below. |
| `C/...SeTarget.sol`, `_refundPairDust` | 477-488 | Scoped search found its definition but no invocation of this copy. Do not add an entry to expose it. |

All four sweeps use the actual local pair balance, return at or below `Repo.MAX_DUST_WEI`, quote exactly the balance minus that floor, stop on zero, and otherwise call `bufferQuotedResidual`. `C/...Repo.sol:19` defines the floor. Tests must use that source constant rather than independently assuming a value.

### Production entries to exercise

- **DepositCommon sweep:** `C/...DepositTarget.sol:65-73` exposes `deposit`; lines 77-110 expose its Permit2 variants. `joinProportional` and `joinUnbalanced` reach the same common deposit routines at 21-61. `depositWithSeShares` at 128-138 reaches `_depositWithSeShares`. `C/...DepositSingleTarget.sol:64-97` exposes single-asset deposit and its Permit2 variants, reaching `_depositSingle`.
- **WithdrawalLib sweep:** `C/...WithdrawTarget.sol:477-483` exposes `withdraw`, whose implementation calls its sweep adapter at 534-536. `withdrawSeShares` at 497-504 reaches the same adapter at 573-575. `withdrawSingle` at 486-493 reaches `_withdrawSingleFrom` at 603-606 and then `Withdrawal.withdrawFrom`, whose sweep is at 66. The vault-held SY override in `C/...DepositSingleTarget.sol:42-45` also uses `Withdrawal.withdrawFrom`.
- **Aggregate Target copy:** Its public `withdraw`/`withdrawSingle` at 798-813 reach its own internal implementations and sweep; its deposit implementation also contains a sweep. However, an exact-name search over `contracts/**/*.sol` found only the aggregate's own title and abstract declaration, not an importing/inheriting production implementation. The named TestBase deploys split facets instead (115-132). Do not claim that a call through the split proxy covers this aggregate copy. Recheck the package/cut/inheritance mapping during implementation; if no production route exists, report that evidence and the resulting coverage limitation. Do not manufacture a wrapper or new facet to make it reachable.
- **SeTarget copy:** Preserve and compile it, cite the absence of a located caller, and do not add a public test door. Recheck the search after the visibility edit.

The minimum behavioral matrix is therefore two distinct cases, each exercised separately for every actually reachable sweep implementation. DepositCommon and WithdrawalLib must not be represented by one another. The same two case definitions can be reused across route-specific tests; this does not merge the zero and revert cases.

## Ordered implementation steps

### 1. Confirm the bounded edit and production route inventory

In a separately authorized implementation session:

1. Re-read the controlling PRD and current versions of the files above, plus repository implementation rules.
2. Search all production calls to `ClaimLib.previewResidualBuffer`, and each definition/call of the four sweep functions. Verify the selected entries are installed on the registry-deployed hook proxy.
3. Resolve the aggregate Target's installed reachability explicitly. Distinguish source-local callers from a callable production deployment. Record an unreachable copy; do not silently claim coverage or broaden the product surface.
4. Identify the existing protocol state controls of the bound vault before attempting either test. No success or reachability is assumed from this draft.

### 2. Change only preview visibility

In `C/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:384`, change `external` to `internal`.

Keep its parameters, `view` qualification, return value, storage lookup, and direct `previewExchangeIn` body unchanged. Do not introduce a catch, a wrapper, or a zero check. Leave `bufferQuotedResidual` external.

Keep all four call sites and their `if (preview == 0) return` checks. An internal library call should remain source-callable as `ClaimLib.previewResidualBuffer(excess)`; verify by compiling rather than assuming. If any caller cannot compile against the internal function, stop and report that file/function and compiler error. Do not revert to external visibility to conceal the failure.

### 3. Build the regression fixture on the existing TestBase

Add a focused test file beside:

`test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_Deploy.t.sol`

Suggested new filename: `UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol` in that same directory.

Inherit `TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook` from `C/`. Call its `setUp`; do not reconstruct deployment. Current TestBase evidence:

- Lines 78-89 build on `TestBase_ERC4626StandardExchange`, deploy the fixture tokens/protocol receipt vault, and obtain the real bound SE through `_deployERC4626SE`.
- Lines 111-138 configure the hook factory through the manager, deploy package/facets on the registry path, deploy the hook, and finalize the product.
- Lines 141-149 fund and approve the existing user.
- Lines 152-174 provide share funding and proportional SE-share deposit helpers; lines 279-295 provide ordinary deposit/bootstrap helpers; lines 297-299 resolve the actual fee recipient.
- Existing deploy test lines 17-35 and 47-67 illustrate inheritance, binding, and registry assertions.

Use the same production hook and bound SE for both case definitions, with independent fresh setup or state isolation. Do not replace the hook, SE, package, manager, registry, fee oracle, or receipt dependency merely to force a result. Do not deploy the hook with `new`, write its storage, add a public wrapper for the preview, or introduce a token/vault whose only purpose is to throw.

Prefer `depositWithSeShares` for DepositCommon and `withdrawSeShares` for WithdrawalLib when preparing the cases: their primary operation exchanges raw tokens and SE shares rather than intentionally depositing the residual pair excess. This can simplify separating the sweep's accounting from the parent operation. These are candidate routes, not a claim that either required quote condition is reachable. Other existing production deposit/withdrawal entries may be used if they provide a faithful witness.

### 4. Case 1 — successful zero preview retains excess

For each reachable sweep implementation:

1. Establish valid live liquidity, permissions, funding, deadline, and meaningful parent-operation minimums through the fixture's normal paths.
2. Using only supported existing state transitions, establish pair custody above `Repo.MAX_DUST_WEI` and a zero SE preview for the exact excess the sweep will observe.
3. Record hook pair balance and exact excess, hook SE shares, caller/receiver balances, and actual `feeTo` pair balance. Also record enough LP/supply/book state to separate the parent operation from residual processing.
4. Verify the bound SE's `previewExchangeIn(pair, excess, se)` returns zero from the same caller/view context as the sweep. Establish that the primary operation does not change that excess or quote basis before the sweep; otherwise compute and witness the actual sweep-time amount. A pre-operation quote of a different amount or state is not sufficient.
5. Invoke the chosen installed production entry and require success. Assert retained pair excess, no residual SE deposit/share increment, no dust payment to caller/receiver or `feeTo`, and satisfaction of the parent operation's own minimum.
6. Reconcile exact parent-operation transfers separately. In a share-funded deposit or withdrawal, the hook's SE-share balance can legitimately change; assert its expected change from that operation and zero additional change attributable to residual buffering. Do not incorrectly require whole-call share balance equality.

Use an exact-call observation of the bound SE quote where useful, without replacing behavior. Verify no residual deposit occurs for that excess. The case must fail if zero causes a revert, deposit, or payout.

### 5. Case 2 — the same excess quote reverts and the parent rolls back

For each reachable sweep implementation, use the same kind of production entry selected for Case 1:

1. Establish a state already supported by the same bound SE in which previewing the sweep's actual excess reverts. Investigate real pause/disable or other existing rejection behavior only; do not assume that disabling execution also disables a view preview.
2. Identify the precise quote error and its data. Confirm the chosen parent route reaches that residual quote rather than failing first in a fee/rate read, input pull, ordinary settlement preview, minimum check, or another gate.
3. Record hook pair/SE-share balances and caller balances before the parent call; include receiver/fee recipient, LP supply, and observable reserves to verify rollback of earlier settlement and sync.
4. Expect the exact quote failure from the production parent call. Require unchanged recorded state. A caught quote failure followed by successful return fails the test even if the excess remains in custody.

A matching error from an earlier unrelated call is not proof that the sweep propagated the quote revert. Establish call-path/argument evidence during the authorized run. No bare revert expectation, catch-and-continue, or substitution of Case 1 is allowed.

### 6. Stop/report rules for unreachable cases

- **Case 1 unavailable:** If every reachable excess on this bound vault has a positive preview, stop and report that zero was not reached, including the production states and entry paths examined. Do not substitute a mock vault, weaken the precondition, silently skip the test, or claim closure.
- **Case 2 unavailable:** If no supported state makes that exact residual preview revert, or every candidate fails earlier, stop and report that the residual-preview revert was not reached. Do not add a throwing dependency, mock the vault/token quote, or accept the earlier failure as evidence.
- **Caller compilation failure:** Report the precise caller; do not retain external visibility as a workaround.
- **Unreachable sweep copy:** Cite source-local calls and the missing production binding separately. Do not add an entry to obtain coverage. A test on another copy does not close it.

These are the PRD's evidence boundaries, not permission to redesign production code. A successfully compiled visibility edit or one successful case does not close REQ-02 if the required behavioral evidence remains unavailable.

### 7. Refresh artifacts, then execute and report

The visibility change is a production edit. Follow `docs/testing/ARTIFACT_BUILDS.md:3-24,41-43`: supply the edited ClaimLib source and exact new test root to `scripts/forge-artifacts.py`; inspect the selected build roots, refresh affected deployed artifacts, and only then run the tests. Include the existing deploy test as an additional test root and the relevant deposit/withdrawal regression suites.

Ensure all four source callers compile, including an abstract/uninstalled source if it is not selected by the runtime-dependent build. Verify current library link references and dependent facet artifacts reflect the internal preview; the remaining external ClaimLib operations must still link normally. Missing artifacts, link failures, or deployed-size violations must be reported, not bypassed by restoring external preview visibility.

Keep the hermetic profile, no `via_ir`, unchanged configured source/test paths, and existing `out/`/`cache_forge/`. Do not delete caches, alter configuration, or deploy/upgrade live instances. Report the actual commands, compiler/toolchain, affected artifacts, tests executed, results, and any case not reached. A present assertion is not a passing test.

## What must not change

- The four existing zero-return checks, dust floor, identity-leg early return, and bounded sweep iteration.
- Direct quote arguments and failure propagation; no new catch or extra zero check.
- `bufferQuotedResidual` visibility, minimum, approval/deposit behavior, and cleanup.
- `WithdrawalLib.bufferPair` at 70-79 and its separate zero-preview handling.
- Reserve sync before the sweep, including DepositCommon 489-491 / 580-582 / 710-712 and WithdrawalLib 64-66.
- Caller/permission/reentrancy checks, parent settlement minimums, fee policy, and existing package selectors.
- No dust payout to user or `feeTo`; no REQ-C04 hook-zero rollback rule imported into this SE-zero case.

## Blocking questions

**No blocking product/specification question.** The PRD specifies what to do if either required state or a caller cannot be reached. Actual zero/revert reachability and the aggregate Target's installed production binding are unresolved implementation evidence tasks, not grounds to invent another fixture or product entry. Report them under the stop rules if they remain unresolved.

## Done when

- The preview is internal, view, direct, and catch-free; `bufferQuotedResidual` remains external.
- All four existing sweep zero stops remain unchanged and all their callers compile.
- The route inventory distinguishes callable proxy sweeps from source-only/uninvoked copies.
- Separate zero-success and exact-quote-revert witnesses execute for each production-reachable sweep implementation through the named TestBase/registry path.
- Tests use the actual sweep excess and context, distinguish parent transfers from dust, and assert exact custody/no-dust-payout or rollback outcomes.
- No new public selector, SUT mock, throwing-only dependency, additional zero check, sync movement, or unrelated product change was introduced.
- Affected production artifacts were refreshed before the reported test runs, and deploy/surface/deposit/withdrawal regressions were reported without claiming unexecuted passes.
- Any unreached case, unbound copy, compiler failure, or artifact/size failure is explicitly reported and REQ-02 is not falsely marked closed.

I did not run Forge.
