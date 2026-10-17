# Astra original — REQ-02 execution confirmation

**Date:** 2026-10-14 review round. **Scope:** Current working-tree execution of `docs/reviews/apex-req-02-residual-preview-internal/REMEDIATION_PRD.plan.md`, subordinate to its sibling `REMEDIATION_PRD.md`. Both were re-read in full. No separate audit report was supplied.

## Conclusion

**The scoped implementation appears complete in current source and test assertions, with a documented artifact refresh and focused passing run. No incomplete or incorrect execution finding was established.** Independent runtime verification remains unperformed: I inspected the execution report and saved logs, not a run I executed or a freshly identity-bound artifact set.

The previously planned stop/report alternative for Case 2 was not needed in the submitted implementation: the tests use an existing checked-arithmetic rejection in the unchanged bound receipt fixture. They do not mock the vault, fault `balanceOf`, or replace a dependency with a throwing implementation. This is materially different from the prohibited fault-injection proposal.

## Verdict table

`Executed` below means the current source/assertions satisfy the scoped item, or the requested execution evidence is present as explicitly noted. It does not mean I independently ran the test. Permitted verdicts are executed, partial, not executed, incorrect, and unverified.

For compact source citations, `C/` means `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/`; abbreviated filenames have the prefix `UniswapV4SingleStandardExchangeBufferConstantProductHook`. `T` means `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol`. `R/` means `docs/reviews/apex-req-02-residual-preview-internal/`.

| Item | Verdict | Current evidence |
|---|---|---|
| Preview internal/view, direct, no catch | executed | `C/...ClaimLib.sol:384-389` declares internal/view and directly returns the configured pair-to-SE preview. |
| Buffer operation remains external | executed | `C/...ClaimLib.sol:393-399`; approval, quoted-minimum deposit, and approval clearing remain. |
| DepositCommon retains helper call and zero stop | executed | `C/...DepositCommon.sol:367-378`; helper at 375, zero return at 376, buffering only afterward. |
| WithdrawalLib retains helper call and zero stop | executed | `C/...WithdrawalLib.sol:131-141`; helper at 138, zero return at 139. |
| Aggregate Target retains helper call and zero stop | executed | `C/...Target.sol:388-399`; helper at 396, zero return at 397. |
| SeTarget retains helper call and zero stop | executed | `C/...SeTarget.sol:477-488`; helper at 485, zero return at 486. |
| Quote body not pasted into sweeps; calls not deleted | executed | All four bodies above retain `ClaimLib.previewResidualBuffer(excess)`. Search across production Solidity found precisely the declaration and these four calls. |
| No new entry for aggregate Target / uncalled SeTarget; unreached status cited | executed | `T:20-21`; `R/EXECUTION_REPORT.md:44-47`; TestBase `:115-138` installs split facets. Production exact-name search finds aggregate Target only in its own title/declaration; SeTarget sweep search finds only its definition. |
| DepositCommon zero-preview witness | executed | `T:46-68,133-150,172-202`: actual excess quoted as hook; parent deposit succeeds; exact parent transfers separated from retained excess. |
| WithdrawalLib zero-preview witness | executed | `T:70-91,133-150,172-202`: corresponding withdrawal witness, with exact parent payout and no residual payout. |
| DepositCommon reverting-preview witness | executed | `T:93-106,153-182,205-216`: specific quote error, exact quote/conversion call expectations, whole-call balance rollback assertions. |
| WithdrawalLib reverting-preview witness | executed | `T:108-122` plus the same setup, call, and rollback helpers. Separate test and production entry. |
| Case 2 not created by forbidden mocking/fault injection | executed | Full `T:1-219` read: uses existing fixture state and actual token transfers; no mock or harness-read override. Receipt behavior is visible at `contracts/test/stubs/SimpleYieldERC4626.sol:102-105`. |
| Hook has no preview selector | executed | Production search finds no wrapper/interface declaration; `T:124-130` asserts no loupe binding; recorded pass at `R/evidence/focused-tests.log:40`. Runtime assertion not independently rerun. |
| Artifact refresh and reported Forge run | executed — documentary evidence | `R/EXECUTION_REPORT.md:54-80`; `R/evidence/artifact-build.log:1-5`; `R/evidence/focused-tests.log:1-4,35-64`. |
| Independent replay and exact current-tree/artifact identity verification | unverified | No Forge/build was run by this reviewer and no source identity hash was recomputed. This is a review limitation, not an additional unmet plan requirement. |

## Source and test assessment

### 1. Visibility and caller behavior

The helper's current body matches PRD lines 50 and 57-58. Each sweep still computes excess from its actual pair balance and the repo dust floor, preserves the identity-leg early return and bounded loop, and stops before buffering a zero quote. There is no catch in the inspected preview/sweep bodies.

The selected production entries reach the intended two implementations:

- `depositWithSeShares` uses `DepositCommon._depositWithSeShares`; current `C/...DepositCommon.sol:579-582` checks the parent minimum, syncs reserves, updates its accounting, and then calls its sweep.
- `withdrawSeShares` uses `C/...WithdrawTarget.sol:544-576`; it transfers raw tokens and SE shares, checks the parent minimum, syncs, and invokes `_refundPairDust`. The adapter at `:338-340` calls `Withdrawal.refundPairDust`.

Neither selected operation's primary settlement transfers pair tokens or changes the receipt supply. This supports the test's use of the pre-call pair excess as the sweep-time excess, rather than assuming a changed balance still represents the same quote.

The new test inherits and calls the named TestBase (`T:8-9,24,40-43`). Current TestBase lines 78-89 obtain the real SE around its existing receipt fixture; lines 111-138 deploy the split hook through the existing manager/package path. There is no replacement SUT in the new test.

### 2. Zero-preview evidence

`T:133-150` uses the receipt's existing yield transition and verifies the actual excess preview from the hook context. `SimpleYieldERC4626.sol:186-190` implements that transition without issuing receipt shares.

The two tests do not mistake legitimate parent SE-share movement for dust conversion. Deposit assertions at `T:59-67` account for exact intake and LP issuance; withdrawal assertions at `:83-90` account for exact payout and LP burning. Shared assertions at `:198-202` preserve the pair balance/excess and rule out dust paid to the caller or actual fee recipient.

### 3. Reverting-preview evidence

The existing bound receipt's conversion uses checked arithmetic (`SimpleYieldERC4626.sol:102-105`). The SE's actual pair-to-share preview calls that conversion (`contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:47-54`). The test exercises a rejection already present in that fixture, not a mocked response or a newly introduced throwing dependency. No procedure or numerical construction is reproduced in this report.

The direct quote precondition is tested separately from the parent transaction (`T:153-163`). Both parent tests establish a successful ordinary parent preview before invoking the money entry (`:97-103,112-119`). Exact call expectations identify the residual SE quote and receipt conversion (`:172-181`), while the explicit error expectation and rollback assertions (`:205-216`) prevent an arbitrary early revert or successful catch-and-retain result from being counted as this witness.

**Inference:** These assertions are appropriately aimed at the specified sweep behavior. That inference is supported by the saved passing results, but I did not independently reproduce their execution. A fixture arithmetic-boundary witness does not establish every real-world pause/disable behavior; the plan does not require that broader claim.

## Reported execution evidence

An implementation report exists; runtime is therefore not merely an unsupported “tests present” claim.

- `R/evidence/artifact-build.log:3-5` records compilation with Solc 0.8.35 and a successful compiler result with warnings.
- `R/EXECUTION_REPORT.md:61-66` records the focused artifact-helper command with the edited library, aggregate Target compilation root, new regression test, and existing deploy test.
- `R/evidence/focused-tests.log:37-43` records all five new tests passing. Lines 45-64 record sixteen deployment tests passing and the combined result of **21 passed, 0 failed, 0 skipped**.
- `R/EXECUTION_REPORT.md:72-80` distinguishes an initial environmental crash from the later successful focused invocation. I did not treat the initial crash as a passing run or infer that it persists.

These are **recorded results**, not results generated by this review. The report's claim that the four sweeps are byte-for-byte unchanged from HEAD was not independently verified with a diff. Their current required behavior was directly re-read. Long generated command lines in the logs were truncated by the reader; the shorter explicit commands in the report were readable.

## Findings and examined files

**No confirmed incomplete or incorrect execution finding.** No remediation recommendation is added merely because independent runtime replay was prohibited. The uninvoked-copy citation is present in both the test header and execution report, so no documentation gap is opened for it.

No scoped defect was identified in the inspected portions of:

- ClaimLib and all four sweep definitions cited in the table;
- DepositCommon's share-deposit settlement and WithdrawTarget's share-withdrawal/adapter path;
- the named production TestBase deployment section;
- the full new `..._ResidualPreview.t.sol` test file;
- the bound SE preview branch and existing `SimpleYieldERC4626` conversion/yield functions;
- the implementation report and the two evidence logs, subject to the provenance/replay limits stated above.

All requested PRD/plan/source/test reads succeeded. No separate audit was supplied or inferred. This is a new independent pass: no peer artifact contents were read and no earlier findings were adopted as proof. A file-discovery glob scoped to the implementation-document folder unexpectedly returned descendant reviewer filenames as well as `EXECUTION_REPORT.md`; those reviewer files were not opened or used. No further reviewer-directory discovery was performed. The prohibited execution-confirmation REMEDIATION_PRD.md was not read.

There is no unresolved specification dissent in this pass. The remaining evidence limitation is independent replay and current artifact identity, not a demonstrated failure to execute the scoped plan.

I did not run Forge.
