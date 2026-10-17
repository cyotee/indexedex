# Grok plan cross-review — REQ-SEP-04

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-16
- **Peers read:** `astra-sep04-plan.md`, `minimax-sep04-plan.md`, `kimi-sep04-plan.md`
- **Astra:** labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi`. It does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`.
- **MiniMax:** `ses_ebdf718feffemWQNf7wuTpapqX`
- **Kimi:** `ses_ec3d04e91ffeJa0is24e2jZv06`
- **Controlling PRD:** `docs/reviews/apex-req-sep-04-amount-out-refund/REMEDIATION_PRD.md` (88 lines). Closed list is C1–C11 and D1–D13.

Peer notes are untrusted. This file does not authorize an edit. It is not `REMEDIATION_PRD.plan.md`.

## Verdict

The plan can be written with no implementer choice. The three drafts, as written, still leave a wording choice. A later session must not pick among them. It must use the one sentence named for each row below.

MiniMax omitted C6, C7, C8, C9, C10, C11, and D2–D13. That draft cannot be the plan.

## Agreements

- Astra, Kimi, and the earlier Grok draft agree the edit is comment and document text only. No function body, signature, selector, storage, or test change.
- Those three cover C1–C11 and D1–D13, stop if a named sentence is gone, and leave lines 3, 34, and 56 of the Uniswap README.
- Those three identify C8 as the NatSpec sentence in `lib/crane/contracts/interfaces/IStandardExchangeIn.sol`, not a refund or reserve function. The local `contracts/interfaces/IStandardExchangeIn.sol` is a re-export and is not a second comment edit.
- None of the four drafts may add a ledger or refund the whole unbooked remainder. Slipstream, `contracts/protocols/dexes/uniswap/v4`, `AGENTS.md`, `CLAUDE.md`, and `SKILL.md` stay out.

## Objections

**MiniMax is not a complete plan.** It says the controlling PRD is 58 lines and quotes line numbers that are not the 88-line PRD. It edits only the README and five DETF comment files. It tells the implementer not to re-edit C8 because the Crane sentence was "already updated." Astra and Kimi both spot-checked line 56 and found the old `refunds nothing` sentence. That "already updated" claim is rejected.

**MiniMax treats C8 as a reserve-sync function.** It names `_syncAllExpectedHoldReserves()` and a long call-site list as "the canonical C8 implementation," and it says to stop if a call is missing. C8 in the PRD is the Crane interface comment plus a Crane source sync. It is not a reserve-sync function. Confirming or restoring those call sites is out of this item. That reading is rejected. It is the path by which a comment plan becomes a function-body edit.

**MiniMax shortens the README.** Its line 38 sentence drops `merely because they are unbooked`. The PRD sentence is mandatory. Its line 32 replacement also deletes `A short push reverts TransferDeltaInsufficient.` That sentence is not the withdrawn refund sentence. Keep it.

**Astra and Kimi still differ, so neither draft is yet no-choice.** Astra uses E, S, M, O, and P, plus a second burn sentence inside C6. Kimi uses EI-DECL, EI-DOC, and further per-row paraphrases. Several of Kimi's row sentences omit `does not by itself revert` and `Booked inventory does not fill a shortfall.` Those omissions are not allowed. The PRD already wrote the shared meaning. Reviewer paraphrases are not alternatives.

**Astra expands past the withdrawn clause.** Reject these as choices, not as coverage:

- Replacing C2–C4 through `Booked holder backing is never pretransfer credit.` That sentence stays.
- Replacing all of C10 lines 24–27 and all of C11 lines 55–57. Replace only the never-refund sentence. Leave the residual, fee-recipient, Slippage, EOA, and D12 sentences.
- Replacing D4's already-matching exact-output sentence.
- Deleting the README short-push sentence.
- Prefixing the D2 line 203 Owner rationale, or otherwise rewriting `Historical text:`.
- Replacing D2 line 172's whole paragraph.

**Kimi's Forge step is not part of this item.** Comment text does not authorize `forge build`. This cross-review does not require it.

**The earlier Grok draft is not the locked wording where it paraphrased.** Its shared sentence was close to the PRD and is superseded by the PRD sentence below. Its D2 exchange-out replacement and its C7 "each" sentence are superseded by the locked sentences in this file.

## Locked sentences

Use the sentence in full. Do not shorten it. Do not swap in E, S, M, O, P, EI-DECL, EI-DOC, or MiniMax's DETF sentence.

**EI, for every exact-input comment and document clause named below:**

The declared input is processed only when present unbooked input covers it. Tokens above the declaration are not refunded. A difference between the declaration and the whole surplus does not by itself revert. Booked inventory does not fill a shortfall.

**C7 only**, because the current sentence says each requested amount:

Each declared input is processed only when present unbooked input covers it. Tokens above each declaration are not refunded. A difference between a declaration and that token's whole surplus does not by itself revert. Booked inventory does not fill a shortfall.

**D1 line 32 refund replacement**, already in the PRD. Keep `No preparePretransfer call is used or exposed.` Keep the measurement sentence. Keep `A short push reverts TransferDeltaInsufficient.`

The caller declares the bound. The vault processes only the amount needed for the requested output, and only from present unbooked tokens within that declaration. It refunds the unused part of the declaration to the caller. It does not refund unbooked tokens the caller did not declare. A shortfall is not filled from booked inventory. A pretransfer outside an atomic operation is the sender's responsibility.

**D1 line 38**, the whole line, already in the PRD:

Unsolicited transfers remain donor risk and can later count toward a declared bound. They are not refunded to a later caller merely because they are unbooked. This does not permit spending inventory already booked by a vault operation.

**D3 note**, one paragraph, inserted immediately after line 10 and before `## Objective`. Do not edit lines 65, 88, 117, 229, 251, 261, or 333.

Current law (REQ-SEP-04, owner answer 2026-10-16): a prepaid exact-input call processes the declared amount only when present unbooked input covers it and does not refund tokens above that declaration. A difference between the declaration and the whole surplus does not by itself revert. A prepaid exact-output call refunds only `min(unbooked, declared maximum) - used`. Booked inventory does not fill a shortfall. Checked historical records in this file are not restated.

Do not replace an exact-output sentence that already says credit is `min(unbooked, declared maximum)` and the refund is only the unused part of that credit.

## One sentence each row must use

| Row | Replace only this, if it is still there | With |
| --- | --- | --- |
| C1, both sites | `Exact-input credits the requested amount from unbooked available and refunds nothing.` | EI |
| C2, C3, C4, each of the six blocks | `Exactly the requested amount is credited when at least that much unbooked input exists; excess is left uncredited and nothing is refunded.` | EI. Leave the EOA sentence and `Booked holder backing is never pretransfer credit.` |
| C5 line 169 | `Exact-input processes exactly `rateAssetAmount` when unbooked available covers it, leaves excess uncredited, and refunds nothing.` | EI |
| C5 line 238 | `Exact-input processes exactly the requested amount when at least that much unbooked input exists, leaves excess uncredited to this operation and refunds nothing` | EI. Leave one `booked holder backing is never pretransfer credit.` |
| C6, both sites | `Exact-input burns the requested amount and refunds nothing.` | EI. No second burn sentence. |
| C7 | `Exact-input processes each requested amount when unbooked available covers it, leaves excess uncredited, and refunds nothing.` | The C7 sentence above. |
| C8 | `Exact-input processes exactly `amountIn` when unbooked available is at least that amount, leaves excess uncredited to this operation, and refunds nothing.` | EI. Do not change the signature. |
| C9 line 76 only | `Exact-in credits exactly `amountTokenToDeposit` and refunds nothing.` | EI. Leave lines 17 and 69–70. |
| C10 | `and exact-input routes never refund` | EI. Leave the residual, fee-recipient, under-consumed, and Slippage sentences, and leave lines 29–32. |
| C11 | `Exact-in credits the requested amount and refunds nothing.` | EI. Leave the EOA sentence and the D12 sentence. |
| D1 line 32 | The exact-in refund sentences, not the measurement sentence and not the short-push sentence | The D1 line 32 PRD sentence. |
| D1 line 38 | The whole line, which still contains the equality-revert sentence | The D1 line 38 PRD sentence. |
| D2 line 14 | The exact-input sentence that ends `refunds nothing (D28; FullSpread D19 exact-in push equality is replaced).` | EI. Leave the false-flag pull sentence. |
| D2 line 63 | `credits exactly `amountIn`, and leaves the rest uncredited (never refunded, never a revert)` | EI. Leave `Historical rule:` onward. |
| D2 lines 113 and 146 | ``exchangeIn` requires `actualIn == amountIn`` | EI. Leave the following reserve and share-math sentences. Do not rewrite an exact-output clause that already refunds only unused bounded credit. |
| D2 line 172 | `Extra unbooked above `amountIn` is not refunded and does not revert (D28).` | EI. Leave the `min(unbooked, maxAmountIn)` refund sentence. |
| D2 lines 202–203 | The current-rule exact-input `refunds nothing` / `neither refunded nor rejected` clause | EI. Leave `Historical text:` verbatim. Do not prefix the Owner cell. |
| D3 | No historical line | The D3 note above, once, after line 10. |
| D4 line 21 | `Exact-in pretransfer credits exactly `amountIn` and refunds nothing.` | EI. Leave the exact-output sentence. |
| D5 line 45 | `Exact-in pretransfer never refunds.` | EI. Leave the absorb-into-`R` sentence and the exact-output sentence. |
| D6 line 422 | `Exact-in never refunds.` | EI. Leave the EOA, I1, cap, and false-flag sentences. |
| D7 line 376 | `refunds nothing and leaves the excess uncredited` | EI. Leave the exact-output sentence. |
| D8 lines 7 and 152 | Each `refunds nothing` exact-input share sentence | EI. Leave each exact-output share sentence. |
| D9 line 159 | `Exact-input push processes exactly the declared amount and refunds nothing.` | EI. Leave the exact-output sentences. |
| D10 line 419 | `Exact-in refunds nothing.` | EI. Leave the absorb-surplus bullet. |
| D11 line 214 | `and refunds nothing` in the exact-in sleeve sentence | EI. Leave `Exact-in retains sleeve/residual assets`. |
| D12 line 48 | `EI refunds nothing` | EI. Leave `push EO refunds only `min(unbooked,max)-used``. |
| D13 line 278 | `exact-in refunds nothing` | EI. Leave the exact-output bullet. |

If the cited old sentence is gone, stop and report that row. Do not choose another line.

## C8 sync, locked

Edit the NatSpec sentence in `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` line 56. Then record the `lib/crane` submodule pointer in the parent. `scripts/submodule-commit.sh` is the parent pointer step for a later implementation session. Do not run it in this review.

Do not edit the re-export. Do not run `sync-crane-skills.sh`. Do not copy the sentence into another interface. If the Crane source commit cannot be made, stop and report C8 pending. Do not pretend a local mirror edit finishes it.

C8 is not `_syncAllExpectedHoldReserves`. Do not open, confirm, or restore reserve-sync call sites for this item.

## Rejected

- Any edit to a function body, signature, selector, storage layout, or test expectation.
- MiniMax §1.6 and Step 5, which treat C8 as reserve sync and would stop the item on a missing sync call.
- MiniMax's claim that Crane line 56 and `IStandardExchangeOut` are already updated and must not be edited. `IStandardExchangeOut` is not a C or D row. C8 still has the old sentence on Astra's and Kimi's spot-checks.
- Any plan that refunds the entire unbooked remainder or adds a caller-attribution ledger.
- Choosing among reviewer paraphrases.

## Unresolved

None on scope or on C8's identity, once MiniMax's reserve-sync reading is rejected. Wording is closed by the EI sentence and the two README sentences. No owner question remains.

I did not run Forge.
