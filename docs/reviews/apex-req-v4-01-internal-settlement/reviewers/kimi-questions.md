# Kimi K3 — question pass: REQ-V4-01 readiness

- **Label:** Replacement-session question pass, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No other reviewers' notes were read. No PRD was written; no code edited.
- **Date:** 2026-10-14.
- **Question asked of me:** does REQ-V4-01 still need an owner decision before a PRD, or is the recorded requirement enough to write one with no implementer choice?
- I did not run Forge.

## Answer: ready — no owner decision is needed

The recorded text already selects the repair. REQ-V4-01 (`docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md:68-80`) states the intended behavior and acceptance criteria unambiguously: the yield path calls the inherited `_executeZapOutExactIn` and passes the holder; it does not `delegatecall` or externally call `address(this)`; it does not keep the holder-taking wrapper as the yield path; a size-limit overflow is reported, not silently substituted. That restates the controlling RC-01 law ("the required path is an internal call that passes the holder") and its plan's build gate ("do not move the yield path onto a delegate, to get under the limit"). The mechanism choice an owner might have had to make — accept the delegate hop as a residual versus require the internal call — is already recorded as "require the internal call." Nothing remains that only the owner can decide.

Current source, re-read this turn: `UniswapV4StandardYieldExecutionTarget.sol:26-36` still delegatecalls `executeNamedHolderRedemption` on the IN execution delegate from `_settleNamedHolder`; the inherited declaration is `_executeZapOutExactIn(..., address holder_)` at `UniswapV4StandardExchangeInBase.sol:146-152`; the matching V3 shape is the internal call at `UniswapV3FullSpreadStandardYieldExecutionTarget.sol:26-30`.

## Mechanical closures the PRD must state so the implementer does not choose

None of these is an owner decision; each is implied by recorded text but should be written down explicitly:

1. **The edit's shape.** `_settleNamedHolder` keeps its name and signature; only its body changes — the delegatecall (`UniswapV4StandardYieldExecutionTarget.sol:29-34`) is replaced by `return _executeZapOutExactIn(tokenOut_, shares_, minimum_, receiver_, holder_);`, mirroring the V3 body (`UniswapV3FullSpreadStandardYieldExecutionTarget.sol:29`). The holders stay `address(this)` for vault-held (`:14`) and `msg.sender` for ordinary (`:21`). Stating this forecloses any rewrite of the two call sites.
2. **Fate of the wrapper.** `executeNamedHolderRedemption` (`UniswapV4StandardExchangeInExecutionDelegate.sol:13-18`) is deleted once the hop is gone. Verified this turn: its only references are its own definition and the yield target (grep over `contracts/`). The PRD should instruct a fresh grep at implementation time and deletion if still caller-less; the four-argument `executeZapOutExactIn` wrapper (`:27-34`) stays unchanged. Without this sentence an implementer could choose to keep the holder-taking entrypoint, which the acceptance criteria and the RC-01 non-goal ("it would let a caller name the holder") rule against.
3. **Interaction with REQ-V4-02.** Both items edit the same function. The PRD should state that the replacement body keeps `nonReentrant` and the post-settlement `_pokeBoundPoolTwap()` and adds `_requireNotDisabled()` per REQ-V4-02's acceptance (`REMEDIATION_PRD.md:88-91`) — one edit closing both, or an explicit sequence — so the implementer does not choose whether REQ-V4-02 is in scope of this edit.
4. **Size contingency.** After the change, measure the affected deployed unit(s); if a runtime exceeds 24,576 bytes, stop and report per the recorded rule. The PRD should repeat that no delegate hop, no self-call, and no `via_ir` may be used to get under the limit (RC-01 plan build gate; REQ-V4-01 acceptance `:78`).
5. **Regression gate.** The existing legacy V4 suite (`test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol`) asserts behavior, not the hop, and must pass unchanged; the PRD should name it, plus the artifact-refresh command required before `forge test` because the edit touches production source (`scripts/forge-artifacts.py`, per `docs/testing/ARTIFACT_BUILDS.md`).

## Non-questions (already answered by recorded text, so not asked)

- No function-name, error-name, or layout choice is referred to the owner: the internal call is selected, and the helper name/layout is fixed by closure 1.
- No owner ruling on EIP-170 oversize is needed in advance: the contingency (report, do not substitute) is pre-decided by the recorded acceptance criteria.
- Hookless and Pons delegate shapes are not this item (REQ-V4-01 non-goals, `:80`), and V3 FullSpread is the contrast to match, not to edit (`:79`).

I did not run Forge.
