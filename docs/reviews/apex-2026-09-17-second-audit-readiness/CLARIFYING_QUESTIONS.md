# Clarifying questions on the APEX second-audit remediation PRD

- **Date:** 2026-10-03
- **Status:** targeted follow-up, not a new review round and not consensus
- **PRD:** `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md`
- **This file records the coordinator's question list.** Owner answers are recorded in the remediation PRD. This file does not authorize code changes.

All four existing sessions answered. Astra was not censored. Session IDs are unchanged:

| Reviewer | Session |
| --- | --- |
| Astra | `ses_efedbea33ffeiXIiaYN3lpvkJ4` |
| Grok | `ses_efedba981ffe2HHDI7axlM96f6` |
| MiniMax M3 | `ses_efedb685dffeFUZVpB5GMex0Mw` |
| Kimi K3 | `ses_efedb20a4ffe9dgQoPxdM9jLgi` |

They do have clarifying questions. Grok has one. Astra, MiniMax, and Kimi have four each. The questions overlap, but the reviewers do not agree on which ones are blocking.

Source question files:

- `docs/reviews/apex-2026-09-17-second-audit-readiness/astra-questions.md`
- `docs/reviews/apex-2026-09-17-second-audit-readiness/grok-questions.md`
- `docs/reviews/apex-2026-09-17-second-audit-readiness/minimax-questions.md`
- `docs/reviews/apex-2026-09-17-second-audit-readiness/kimi-questions.md`

## Questions that change the fix

### 1. REQ-01 and REQ-02: remove the residual catches, or keep some under a written exception?

**Decided 2026-10-06 as OD-01.** A preview result of `0` is the only signal that a residual deposit cannot be processed. The leftover stays booked and the parent operation continues. Any revert rolls the transaction back. No new catch exception is required. The `supportsInterface` probe is not decided by OD-01.

The wings vault PRD was included as related design context only. It does not authorize a DETF catch.

### 2. REQ-07: what happens to the gas-gated `quoteState` probe?

**Decided 2026-10-06 as OD-02.** A plain rate call uses the live preview. It does not call `quoteState` and does not check remaining gas. A hook that already holds a snapshot may still pass that snapshot into the rate quote. A failed snapshot is not silently replaced with the live rate. Vault snapshot functions stay. The Full Spread gas workaround is not a reason to keep the self-snapshot.

### 3. REQ-06: which rounding direction closes the double floor?

**Decided 2026-10-06 as OD-03.** The current formula is not correct. `maxRedeem` becomes the share cap, in the OpenZeppelin ERC-4626 v5.7.0 direction, and `maxWithdraw` becomes `previewRedeem` of that cap. The uncapped OpenZeppelin `balanceOf` return applies only when `previewRedeem` of the full balance is payable from held receipts and is not zero. This is not a port of OpenZeppelin virtual shares.

### 4. REQ-05: what must the replacement FullSpread prove?

**Decided 2026-10-06 as OD-04.** The old incorrect vault is not kept merely to prove the new vaults. FullSpread and the wings vault each get their own outside-trade credit test. The old equality and greater-than cases are not reconstructed. The current supplement is not the stale-reserve proof. This review does not write the tests.

### 5. REQ-08: was the current FullSpread V4 split authorized?

**Decided 2026-10-06 as OD-05.** The owner specifically requested the split. Distinct packages stay for specific Uniswap V4 hooks. Do not merge them back. Evidence names the current files. Whether a later package may reuse the wings vault on a Pons-configured pool is a separate open question, not decided by OD-05.

### 6. How wide is the later implementation task?

**Decided 2026-10-06 as OD-06.** Do both, in stages. Stage 1 is the repairs in this PRD and their tests, used as a fast-fail check. Stage 2 reopens the full APEX program, including the broader changes and new vaults, before audit submission. Stage 1 passing is not submission.

### 7. May implementing tests still contain defensive regressions?

**Decided 2026-10-06 as OD-07.** Option 1 is the project rule. Tests must exercise the real production path and assert the exact corrected security result, including that the forbidden credit or payout does not occur. Reports and test names must not describe how to attack a live system. A red run on preserved old source is not required.

## Already specific enough for the reviewers who did not ask

REQ-03 and REQ-04 were not questioned. The required tests are exact errors, unchanged state on rejection, and measured consumption rather than a catch of every revert.

## Next step

Questions 1 through 7 are decided in the remediation PRD. No clarifying question from this list remains open.
