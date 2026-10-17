# Grok original — REQ-02 plan execution

- **Reviewer:** Grok (`xai/grok-4.7`). Independent first pass. Not a cross-review.
- **Date:** 2026-10-14
- **Question:** Was `docs/reviews/apex-req-02-residual-preview-internal/REMEDIATION_PRD.plan.md` executed completely against the current tree?
- **Controlling PRD:** `docs/reviews/apex-req-02-residual-preview-internal/REMEDIATION_PRD.md`. It wins on conflict. No conflict was found in the executed source.
- **Answer:** Yes, for the done-when items re-read here. No incomplete or incorrect execution was found. This reviewer did not run Forge. The green count is the cited log, not a new run.

## Findings

None. The items below match the plan and the PRD. No incomplete or incorrect execution is recorded.

## Verdict table

| Item | Verdict | Evidence |
| --- | --- | --- |
| `previewResidualBuffer` is `internal`, has no `catch`, and still returns `previewExchangeIn` of the excess pair amount | executed | `UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:384-388` |
| `bufferQuotedResidual` is still `external` | executed | Same file `:393-399` |
| All four sweeps still call `ClaimLib.previewResidualBuffer` and still return without depositing on a zero quote. The body was not pasted in and the calls were not deleted | executed | `DepositCommon.sol:375-377`; `WithdrawalLib.sol:138-140`; `Target.sol:396-398`; `SeTarget.sol:485-487` |
| Monolith `Target` and `SeTarget` were not given a new entry, and the test cites them as unreached | executed | Test header `UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol:20-21`. No new public entry was found on those copies |
| DepositCommon and WithdrawalLib each have a separate zero-preview witness and a separate reverting-preview witness | executed | `depositWithSeShares` zero at `:47-67` and revert at `:94-105`. `withdrawSeShares` zero at `:71-90` and revert at `:109-121` |
| The hook did not gain a `previewResidualBuffer` selector | executed | Loupe assertion at `:125-130`. The function is a library `internal`, not a facet function |
| Case 2 was not manufactured by mocking the vault or by faulting a harness `balanceOf` | executed | `_prepareRevertingQuote` at `:156-162` donates the existing pair token so the bound receipt's existing `convertToShares` multiplication overflows (`SimpleYieldERC4626.sol:102-105`). No `mockCall` or `mockCallRevert` in this test file. The expected revert is `Panic(0x11)` (`:215-216`), and `expectCall` requires that quote (`:173-181`) |
| Artifact refresh and a reported Forge run | executed as a reported run, not re-executed here | `docs/reviews/apex-req-02-residual-preview-internal/EXECUTION_REPORT.md:54-66` names `scripts/forge-artifacts.py` then the two test roots. `evidence/focused-tests.log:37-43` and `:64` record 5 residual tests and 16 deploy tests, 21 passed, 0 failed. This reviewer did not run those commands |

## What was re-read

The visibility change is the mechanism the plan required. The four sweep loops still compute `excess = balance - MAX_DUST_WEI`, call `ClaimLib.previewResidualBuffer`, return on zero, and call `bufferQuotedResidual` only after a positive quote. `MAX_DUST_WEI` remains the repo constant used by the tests (`Repo.MAX_DUST_WEI` at test `:142` and `:158`).

Case 1 uses the bound receipt's existing `simulateYield` transition (`:139`), which increases assets without minting receipt shares (`:140-141`). It then donates `MAX_DUST_WEI + 1` and requires the bound vault's `previewExchangeIn` of that excess to return 0 (`:145-149`) before `depositWithSeShares` and `withdrawSeShares`. Assertions keep the pair excess in the hook and separate the parent LP, raw, and SE movements (`:59-67`, `:83-90`, `:198-202`). That matches the plan's allowed yield transition and the "do not count the parent payout as dust" rule.

Case 2 is a state the bound receipt already computes: checked `assets * supply / totalAssets`. It is not a pause or disable path. The plan allows another rejection the production vault already exposes, and it forbids a harness `balanceOf` fault. This construction follows that split. The parent preview is asserted positive before the call (`:97-98`, `:112-114`), so the expected panic is not an earlier parent-quote failure in the test text. Whether that ordering holds at runtime is what the cited log records as passed. This reviewer did not re-run it.

The test inherits `TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook` and calls `super.setUp()` (`:40-42`). It does not deploy the hook with `new`.

## Evidence gap

This reviewer did not run Forge. The pass count is the existing log, not an independent execution in this session. No full hermetic suite is claimed by the report, and none is claimed here.

I did not run Forge.
