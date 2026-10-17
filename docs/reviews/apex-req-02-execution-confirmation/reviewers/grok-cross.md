# Grok cross-review — REQ-02 execution

- **Date:** 2026-10-14
- **Originals read:** Astra, MiniMax M3, Kimi K3. Untrusted. The plan and PRD control.
- **Not read:** `apex-req-02-execution-confirmation/REMEDIATION_PRD.md`.

## Plan execution

**Agree with Astra, MiniMax, and Kimi: the plan was executed completely against the tree that was re-read.**

`previewResidualBuffer` is `internal` and still returns `previewExchangeIn` (`ClaimLib.sol:384-388`). `bufferQuotedResidual` stays `external` (`:393`). All four sweeps still call `ClaimLib.previewResidualBuffer` and still return on zero. The test header cites the monolith and `SeTarget` as unreached (`ResidualPreview.t.sol:20-21`). DepositCommon and WithdrawalLib each have a separate zero witness and a separate revert witness. The loupe test asserts no preview selector (`:125-130`). The cited log records those tests passed. This reviewer did not re-run them.

MiniMax F1, that `apex-req-02-execution-confirmation/` was absent, is not an incomplete execution of the residual-preview plan. That plan does not require a second directory. The source and the report live under `apex-req-02-residual-preview-internal/`.

## Case 2 donation

**Agree: the checked-arithmetic donation is not incorrect execution.**

The plan allows another rejection the bound vault already exposes, and it forbids mocking the vault and faulting a harness `balanceOf`. `_prepareRevertingQuote` (`ResidualPreview.t.sol:156-162`) donates the existing pair token. The bound receipt's own `convertToShares` then does checked `assets * supply / totalAssets` (`SimpleYieldERC4626.sol:102-105`). The test expects that `Panic(0x11)` from the production quote and from the parent entry. There is no `mockCall` and no `balanceOf` fault in the file.

Kimi's open reading question is the same construction. It is not a defect. An overflow-sized donation is a state the existing receipt arithmetic already rejects. It is not the prohibited fault injection. MiniMax F2's note that a later unchecked rewrite would make this witness stale is a maintenance observation, not incorrect execution of this plan.

## Unresolved

None on completeness or on Case 2. Independent replay of the cited log was not done here.

I did not run Forge.
