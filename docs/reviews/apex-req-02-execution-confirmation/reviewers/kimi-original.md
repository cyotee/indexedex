# Kimi K3 — original: REQ-02 execution confirmation

- **Label:** Replacement-session original, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. This is an independent first pass on the execution question; no `reviewers/` content for this round and no peer findings were read. The coordinator's `apex-req-02-execution-confirmation/REMEDIATION_PRD.md` was not read.
- **Date:** 2026-10-14.
- **Question:** Was `docs/reviews/apex-req-02-residual-preview-internal/REMEDIATION_PRD.plan.md` executed completely against the current working tree?
- **Documents re-read in full:** the plan (`REMEDIATION_PRD.plan.md`) and the controlling PRD (`REMEDIATION_PRD.md`) in `docs/reviews/apex-req-02-residual-preview-internal/`. The PRD wins on conflict; no conflict between them was material here. No separate audit report was supplied.
- **Execution evidence:** I did not run Forge. An implementation-session report and logs exist and were read; they are claims I verified for internal consistency against current source, not a run I performed.

## Answer

**Yes — executed, with runtime attestation by report only.** Every done-when item is confirmed against current source and tests. No incomplete, incorrect, or regressed item was found. One judgment note on the Case 2 construction is recorded below; it is not a defect.

## Item-by-item verification (done-when list)

1. **`previewResidualBuffer` is internal, no catch, direct body — executed.** `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:384` now reads `function previewResidualBuffer(uint256 amount) internal view returns (uint256 shares)`. Body at `:385-388` is unchanged: storage read plus direct `IStandardExchangeIn(l.standardExchange).previewExchangeIn(IERC20(l.pairToken), amount, IERC20(l.standardExchange))`. No catch, no zero check. Comment at `:382-383` unchanged.
2. **`bufferQuotedResidual` still external — executed.** Same file `:393`.
3. **All four sweeps still call `ClaimLib.previewResidualBuffer` and stop on zero; nothing pasted, nothing deleted — executed.** Repo-wide grep over `contracts/` finds the name in exactly five files: the ClaimLib declaration and the four sweep calls at `DepositCommon.sol:375`, `WithdrawalLib.sol:138`, `Target.sol:396`, `SeTarget.sol:485`. The zero stops remain at `:376`, `:139`, `:397`, `:486` respectively (`if (preview == 0) return;`). The sweep bodies match the full reads I made earlier today at identical line numbers. The report's "byte-for-byte unchanged" claim (`EXECUTION_REPORT.md:8-9`) is consistent with this.
4. **Monolith Target and SeTarget copies not given a new entry; cited as unreached — executed.** The test header cites both explicitly (`UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol:20-21`: "The monolithic Target._refundPairDust is not installed by this TestBase, and the SeTarget._refundPairDust copy has no caller. Both remain unreached; no entry is added."). The report repeats this and notes the monolith was still included as a compilation root and SeTarget compiled through SeFacet (`EXECUTION_REPORT.md:44-47`). No new caller of either copy exists (grep).
5. **DepositCommon and WithdrawalLib each have separate zero and reverting witnesses — executed.** Four tests: `test_residualPreview_deposit_zeroRetainsExcess` (`:47-68`), `test_residualPreview_withdraw_zeroRetainsExcess` (`:71-91`), `test_residualPreview_deposit_quoteRevertRollsBack` (`:94-106`), `test_residualPreview_withdraw_quoteRevertRollsBack` (`:109-122`). Entries: `depositWithSeShares` (reaches `DepositCommon._refundPairDust` via `_depositWithSeShares` at `DepositCommon.sol:582`) and `withdrawSeShares` (reaches `WithdrawalLib.refundPairDust` via `WithdrawTarget.sol:575` → wrapper `:338-340`). The header documents why the pre-call excess is the sweep-time excess for both share-only entries (`:17-19`), which I verified against `WithdrawTarget.sol:561-570` (withdrawSeShares pays raw + SE shares, no pair movement) and the deposit path's pulls (`DepositTarget.sol:128-138` pulls raw and SE shares only).
6. **No new hook selector — executed.** `test_residualPreview_hasNoHookSelector` (`:125-131`) asserts `IDiamondLoupe(hook).facetAddress(keccak256("previewResidualBuffer(uint256)")) == address(0)`. The grep in item 3 confirms no wrapper was added.
7. **Case 2 not manufactured by mock or harness fault — executed correctly.** The full test file contains no `mockCall`, no replaced dependency, and no added throwing token/vault. `_prepareRevertingQuote` (`:156-163`) donates a real minted pair amount (`type(uint256).max / receipt.totalSupply() + 1` plus the dust floor) so the bound receipt's existing checked multiplication in `SimpleYieldERC4626.convertToShares` overflows with `Panic(0x11)`; the direct precondition call proves the bound SE's quote reverts with that panic for exactly the sweep's excess (`:160-162`), and `vm.expectCall` pins the sweep's quote call with exact args at count 1 (`:173-182`), so an earlier unrelated failure cannot satisfy the test. Rollback assertions cover pair, raw, SE shares, LP balance, and LP supply (`:205-213`).
8. **Artifact refresh and a reported Forge run — executed as reported; runtime not re-executed by me.** `EXECUTION_REPORT.md:54-70` lists the artifact build, the focused test command with both test roots, `forge fmt --check`, and `git diff --check`. `evidence/focused-tests.log:37-64` is consistent with the report: the five new tests PASS and the sixteen deploy tests PASS, 21 total, 0 failed. A sandbox crash on the first attempt is disclosed with a rerun outside the sandbox (`:72-77`). I did not re-run any of this; the run is a verified-for-consistency claim, not my execution.

## Judgment note (not a defect)

The plan's Case 2 step 2 admits "a pause, a disabled vault, or another rejection the production vault already exposes," and step 5 forbids mocking the vault, faulting a harness `balanceOf`, or adding a throwing-only dependency. The implementer used none of those; the witness relies on the bound receipt's own checked arithmetic at an extreme-but-admitted balance. In my earlier plan cross-review I argued the default for a hard-to-reach Case 2 is stop-and-report; that default applied to constructions the plan forbids. This construction is a faithful witness of the property Case 2 exists to prove — the sweep's actual quote reverting rolls the parent back — using no forbidden mechanism. Whether an overflow-magnitude donation is "a state the vault already supports" in the plan's intended sense is a coordinator/owner reading; I record the question and do not score it as incorrect execution. Confidence: high on the code facts; the interpretive note is flagged, not resolved.

## Findings

None. No incomplete or incorrect execution was found against the plan's done-when list.

## Verdict table

| Done-when item | Verdict | Evidence (lines read this round) |
| --- | --- | --- |
| `previewResidualBuffer` internal, no catch, direct body | executed | `...HookClaimLib.sol:384-389` |
| `bufferQuotedResidual` still external | executed | `...HookClaimLib.sol:393-400` |
| Four sweeps still call the library and stop on zero; no paste, no deletion | executed | calls `DepositCommon:375`, `WithdrawalLib:138`, `Target:396`, `SeTarget:485`; stops `:376`, `:139`, `:397`, `:486` |
| Monolith Target / SeTarget copies: no new entry; cited as unreached | executed | test header `:20-21`; `EXECUTION_REPORT.md:44-47`; grep (no new callers) |
| Separate zero and reverting witnesses for DepositCommon and WithdrawalLib | executed | test file `:47-68`, `:71-91`, `:94-106`, `:109-122` |
| No `previewResidualBuffer` selector on the hook | executed | test `:125-131`; grep (no wrapper/interface) |
| Case 2 not built from a vault mock or harness `balanceOf` fault | executed | test file full read `:134-182`; no `mockCall` present |
| Artifact refresh + reported Forge run | executed as reported; runtime unverified by me | `EXECUTION_REPORT.md:54-80`; `evidence/focused-tests.log:37-64` |

## Files examined with no defect found

- `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:378-407`
- The four sweep call/stop sites (grep-verified this round; bodies full-read earlier today at identical line numbers): `...HookDepositCommon.sol`, `...HookWithdrawalLib.sol`, `...HookTarget.sol`, `...HookSeTarget.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol` (full read)
- `docs/reviews/apex-req-02-residual-preview-internal/EXECUTION_REPORT.md` and `evidence/focused-tests.log` (claims, consistency-checked)
- Repo-wide `previewResidualBuffer` grep over `contracts/` (five files, listed above)

## Evidence gaps

- I did not run Forge; the 21/21 result is the implementation session's log, not my execution. A present log is not a pass I can attest.
- Whether `vm.expectCall` counts a call that reverts (load-bearing for the Case 2 reachability argument) was not executed by me; the reported green run is consistent with it counting, but I did not verify Foundry's semantics by running.
- The first-attempt sandbox crash (`evidence/focused-tests-sandbox-crash.log`) was not body-read; the report's disclosure of it was noted.
- Full hermetic and fork suites were not run by the implementation session and are outside this item's scope (`EXECUTION_REPORT.md:51-52`).

I did not run Forge.
