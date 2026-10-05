# Clarifying questions on the APEX second-audit remediation PRD

- **Date:** 2026-10-03
- **Status:** targeted follow-up, not a new review round and not consensus
- **PRD:** `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md`
- **This file records the coordinator's question list.** It does not authorize code changes and does not amend the remediation PRD.

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

Astra, MiniMax, and Kimi say the PRD allows either outcome, so an implementer cannot choose. Grok does not treat this as open: no owner amendment was found, so the implementer should restore hard propagation.

If an exception is wanted, name the function, the permitted error, and the exact retained or rolled-back result. The sites are not the same:

- Operative residual joins in `UniswapV4DetfCommon.sol` around lines 572, 604, 628, and 642.
- Interface probes and sub-share qualification around lines 664–685.
- Residual parking around lines 699–721.
- `previewResidualBuffer` at `UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:246-257`.

The product choice is whether a residual that cannot be joined should revert the operation, or stay locally owned without being credited or paid out.

### 2. REQ-07: what happens to the gas-gated `quoteState` probe?

All four ask this. The PRD says remove it or amend it, and then says a failed call follows "the locked hard or exact-length rule." Those are different fixes.

- Delete the snapshot call. Empty-state rates use the live probe only.
- Keep the snapshot call and revert if it fails, returns short data, or cannot be paid for.
- Keep a non-reverting exact-length fall-through, and say which rate that path must return.
- Keep the current gas-gated fall-through only if an amendment names the gas bound and the required rate match.

Kimi also asks whether open-item 10 already authorized this probe, and whether any production SE needs it for a correct rate. That was not established in the review.

### 3. REQ-06: which rounding direction closes the double floor?

Only MiniMax treats this as open. Astra, Grok, and Kimi say the acceptance text is already enough: return the full owner balance when that balance's rounded receipt payout is within held receipts, and otherwise use one consistent cap that still rejects a redeem above receipt inventory.

If a specific direction is wanted, say floor, ceiling, or parity with `previewRedeem`. Otherwise an implementer can follow the acceptance text as written.

### 4. REQ-05: what must the replacement FullSpread prove?

Only Kimi treats this as open. The others say the cited supplement must stop being labeled as the stale-total boundary, and a real stale-book control must be cited.

Kimi asks whether the equality and greater-than cases exist only on the preserved implementation, with the replacement checked after an external pool trade that does not sync the vault, or whether the replacement needs its own named boundary set.

### 5. REQ-08: was the current FullSpread V4 split authorized?

Only Kimi asks this. If the hookless and Pons-family split is ratified, REQ-08 is an evidence map and a fresh source-bound run. If it was not authorized, the later task may have to restructure or revert that package shape before regenerating evidence.

### 6. How wide is the later implementation task?

Only Astra asks this. The PRD can be read as eight repairs, with the other criteria left unverified, or as a renewed certification of all 108 criteria plus the full hermetic, release-count, and fork gates.

### 7. May implementing tests still contain defensive red/green regressions?

Only Astra asks this. The PRD forbids exploit procedures, proof-of-concept code, payloads, and attack parameters in implementing tests. It does not say whether a hermetic production-route test may still show the old assertion failing on preserved source and passing on the replacement, as long as the report does not describe how to attack a live system.

## Already specific enough for the reviewers who did not ask

REQ-03 and REQ-04 were not questioned. The required tests are exact errors, unchanged state on rejection, and measured consumption rather than a catch of every revert.

## Next step

Work through each question above. The remediation PRD is unchanged until those answers are recorded.
