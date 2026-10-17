 # Implementation plan — declared-bound refund wording

- **Date:** 2026-10-16
- **Status:** DRAFT. This plan does not authorize comment, documentation, code, test, or config edits. A later session must be explicitly asked to implement it.
- **Controlling PRD:** [REMEDIATION_PRD.md](./REMEDIATION_PRD.md). Where this plan conflicts with that PRD, the PRD controls.
- **ID:** REQ-SEP-04. No function body, signature, selector, or test expectation changes.
- **Council:** Astra replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi` does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Grok `ses_ec4128917ffeeVds3Y2p7xrVjp`. MiniMax replacement `ses_ebdf718feffemWQNf7wuTpapqX` does not recall `ses_ec41255ceffeVhrySLQe8hwwMC`. Kimi replacement `ses_ec3d04e91ffeJa0is24e2jZv06` does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No Forge run. Consensus is not proof.
- **Drafts:** `reviewers/astra-sep04-plan.md`, `reviewers/grok-sep04-plan.md`, `reviewers/minimax-sep04-plan.md`, `reviewers/kimi-sep04-plan.md`, and the four `*-sep04-plan-cross.md` files. MiniMax's draft is rejected. It omitted C6–C11 and D2–D13 and treated C8 as a reserve-sync function.

## Sentences

Use these sentences. Do not paraphrase them.

**EI:** The declared input is processed only when present unbooked input covers it. Tokens above the declaration are not refunded. A difference between the declaration and the whole surplus does not by itself revert. Booked inventory does not fill a shortfall.

**EI-SHARE:** The declared share amount is burned only when present unbooked shares cover it. Shares above the declaration are not refunded. A difference between the declaration and the whole share surplus does not by itself revert. Booked holder backing does not fill a shortfall.

## What not to do

- Do not edit a function body, a signature, a selector, or a test.
- Do not refund the whole unbooked remainder. Do not add a ledger.
- Do not edit Slipstream, `contracts/protocols/dexes/uniswap/v4`, `AGENTS.md`, `CLAUDE.md`, `SKILL.md`, or a file under `docs/reviews/`, `docs/research/`, or a dated audit record.
- Do not treat C8 as `_syncAllExpectedHoldReserves`.
- If a named sentence is absent, stop and report that file and line. Do not choose another line.

## Step 1 — README

In `contracts/vaults/standard/exchange/protocols/uniswap/README.md`:

- Keep the measurement sentence in line 32 and keep "A short push reverts `TransferDeltaInsufficient`."
- Replace only "Exact-in credits exactly `amountIn` when unbooked availability is sufficient. An exact-in excess push does not revert merely for being excess, and exact-in never refunds." with: "The caller declares the bound. The vault processes only the amount needed for the requested output, and only from present unbooked tokens within that declaration. It refunds the unused part of the declaration to the caller. It does not refund unbooked tokens the caller did not declare. A shortfall is not filled from booked inventory. A pretransfer outside an atomic operation is the sender's responsibility."
- Replace line 38 with: "Unsolicited transfers remain donor risk and can later count toward a declared bound. They are not refunded to a later caller merely because they are unbooked. This does not permit spending inventory already booked by a vault operation."
- Leave lines 3, 34, and 56 unchanged.

## Step 2 — comments

Replace only the cited withdrawn sentence. Keep the EOA, atomicity, and booked-backing clauses on the same line.

| Row | Replacement |
| --- | --- |
| C1, both sites | EI |
| C2, C3, and C4, all 18 blocks | Replace "Exactly the requested amount is credited when at least that much unbooked input exists; excess is left uncredited and nothing is refunded." with EI. Keep "Booked holder backing is never pretransfer credit." |
| C5, both sites | EI |
| C6, both sites | EI-SHARE |
| C7 | EI |
| C8 | Replace the final exact-input clause at `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:56` with EI. Edit that Crane source file. Do not edit the IndexedEx re-export. If `lib/crane` is a submodule, update the IndexedEx pointer with the repository's existing submodule process. Do not run `sync-crane-skills.sh`. |
| C9 | Replace only line 76 with EI. Leave lines 17, 69–70, and 113. |
| C10 | Replace "and exact-input routes never refund" with "; exact-input routes process the declared input only when present unbooked input covers it and do not refund tokens above the declaration". Leave lines 29–32. |
| C11 | Replace "Exact-in credits the requested amount and refunds nothing." with EI. Keep the EOA and D12 sentences. |

## Step 3 — other documents

| Row | Replacement |
| --- | --- |
| D2 lines 113 and 146 | Replace `` `exchangeIn` requires `actualIn == amountIn` `` with "prepaid `exchangeIn` requires unbooked availability to cover the declared `amountIn`; a difference between the declaration and the whole surplus does not by itself revert". Replace "refunds this-call surplus to `msg.sender`" with "refunds only the unused part of `min(unbooked, declared maximum)` credit to `msg.sender`". |
| D2 lines 14, 63, 172, and 202–203 | Replace the terse never-refund clause with EI. Keep any "Historical text" label. |
| D3 | After the execution-complete paragraph and before `## Objective`, add: "Current-law note (2026-10-16, REQ-SEP-04): the prepaid rule is declared-bound. Exact-input processes the declared amount and does not refund undeclared tokens. Exact-output refunds only the unused part of `min(unbooked, declared maximum)` credit. A declaration differing from the whole surplus does not revert. The checked items at lines 65, 88, 117, 229, 251, 261, and 333 are historical records and are not current requirements." Do not edit those lines. |
| D4, D5, D6, D7, D9, D10, and D13 | Replace the cited never-refund sentence with EI. Keep surrounding exact-output and false-flag text. |
| D8, both lines | EI-SHARE |
| D11 | Keep "Exact-in retains sleeve/residual assets" and replace "and refunds nothing." with ". " followed by EI. |
| D12 | Replace "EI refunds nothing" with "EI processes the declared input only when present unbooked input covers it and does not refund tokens above that declaration. A difference between the declaration and the whole surplus does not by itself revert. Booked inventory does not fill a shortfall." |

## Step 4 — check

Record `git status` and preserve unrelated changes. After the Solidity comment edits, run `forge build` from the repository root. Do not enable `via_ir`. Do not delete `out/` or `cache_forge/`. Do not run a behavioral test suite for this wording item. A comment-only diff must not change a function body. If the build fails, stop and report it.

Report the files changed and the build result in `EXECUTION_REPORT.md` in this directory. A present sentence is not a completed edit until that report exists.

## Done when

- Every C and D row uses the sentence named above.
- No function body, signature, test, Slipstream file, or deleted legacy V4 file changed.
- The Crane comment is the EI sentence, and the IndexedEx re-export was not given a copied NatSpec block.
- `forge build` is recorded.

## Dissent

MiniMax's plan draft is not this plan. Grok and Kimi agree the short-push revert sentence in the README stays. Astra's draft would have deleted it. This plan keeps it.
