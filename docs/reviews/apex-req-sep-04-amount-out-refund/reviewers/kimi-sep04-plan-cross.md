# Kimi K3 — cross-review: REQ-SEP-04 plan drafts

- **Label:** Replacement-session cross-review, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. Astra is the labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi`; MiniMax is `ses_ebdf718feffemWQNf7wuTpapqX`. My draft is `kimi-sep04-plan.md`. The three peer drafts were read in full as untrusted output. Controlling PRD: `docs/reviews/apex-req-sep-04-amount-out-refund/REMEDIATION_PRD.md` (current version: 88 lines, closed list C1–C11 / D1–D13 at `:28-70`, re-read this round). Nothing was edited.
- **Date:** 2026-10-16. I did not run Forge.

## Verdict on the assigned question

**Agree: the plan can be written with no implementer choice** — Astra's draft and Grok's draft each prove it (fixed sites, verbatim replacement text, fixed order, stop rule). **MiniMax's draft must be rejected** (below). No draft edits a function body; none must.

## Rejection: MiniMax's draft (`minimax-sep04-plan.md`)

Rejected in full, on four independent grounds:

1. **It planned against the superseded PRD.** Its header (`:4`) describes the controlling PRD as "58 lines, read in full this round" and its §0 spot-check cites `:30/:32/:34/:36/:38/:40` as the Documentation section and `:42-46` as "What is already known" — those are the old 58-line draft's line numbers. The current PRD is 88 lines with the closed list at `:28-70`. Every downstream omission follows from this staleness.
2. **It omits most of the closed list.** Its edit scope (`:6`) is "0 code edits; 2 README documentation edits; 5 DETF interface comment files. No other site is in scope." That drops C6 (`IRebasingClaimToken.sol:177,188`), C7 (`IStandardExchangeInMulti.sol:27`), C9 (`BasicVaultCommon.sol:76`), C10 (`ERC4626StandardExchangeCommon.sol:24-27`), C11 (orbital hook `:55-57`), and **all of D2–D13** — all present in the current PRD's closed list.
3. **It treats C8 as a reserve-sync function.** Its §1.6 (`:105-135`) declares "The C8 requirement … is implemented in production by `_syncAllExpectedHoldReserves()`" and substitutes a 25-row inventory of sync call sites. C8 in the PRD (`:45`) is the `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:56` comment edit plus the Crane sync note. This is exactly the misreading the assignment says to reject.
4. **It asserts a false fact about C8's file.** `:92` claims `lib/crane/.../IStandardExchangeIn.sol:56` is "already updated to the new wording by a prior change." I read that line this session: it still reads "Exact-input processes exactly `amountIn` when unbooked available is at least that amount, leaves excess uncredited to this operation, and refunds nothing." The claim is wrong, and its "confirm and do not re-edit" instruction would silently drop a closed-list row.

MiniMax's README `:38` replacement text is also the old PRD's version (missing "merely because they are unbooked"), and its README `:32` operation deletes the "A short push reverts `TransferDeltaInsufficient`" sentence (see the D1 ruling below). Nothing in this draft is salvageable as written; the plan must be rewritten from the current PRD.

## Agreements (Astra, Grok, my draft)

- No code, signature, selector, or test-expectation edits; comment/documentation text only.
- Stop-and-report if a named sentence is gone; no substitution, no search.
- README replacements use the PRD's verbatim text; lines 3, 34, 56 unchanged.
- C8 = Crane source comment edit plus sync through the Crane dependency process; the IndexedEx-side `contracts/interfaces/IStandardExchangeIn.sol` is a re-export with no NatSpec and is not edited (Astra `:88`, Grok `:85`; consistent with the remapping).
- All 18 repeated blocks in C2–C4 are replaced identically, including blocks preceding view functions; no relocation.

## Rulings where the drafts differ — the one sentence each row must use

The governing principle: use the PRD's own `:32` meaning verbatim rather than any reviewer's paraphrase. That fixes the two canonical sentences:

- **EI (default exact-input replacement; PRD `:32` text):** "The declared input is processed only when present unbooked input covers it. Tokens above the declaration are not refunded. A difference between the declaration and the whole surplus does not by itself revert. Booked inventory does not fill a shortfall." — Grok's "shared exact-input sentence" is exactly this; adopt it over my EI-DECL, Astra's E, and MiniMax's variant (all semantically equal, but the PRD's words are the controlling text).
- **EI-SHARE (share-burn surfaces):** "The declared share amount is burned only when present unbooked shares cover it. Shares above the declaration are not refunded. A difference between the declaration and the whole share surplus does not by itself revert. Booked holder backing does not fill a shortfall." — Astra's S, aligned to PRD wording; adopt over Grok's generic EI sentence for burn surfaces ("processed" is weaker than "burned" on a redeem/burn path).

Per row:

| Row | Ruling |
|---|---|
| C1 (`:126,137`), C5 (`:169,238`), C7 (`:27`), C9 (`:76`), C11 (`:55-57`) | Replace the cited exact-input sentence with **EI**, preserving the EOA/atomicity/backing clauses on the same lines. |
| C2/C3/C4 (18 blocks) | Replace "Exactly the requested amount is credited when at least that much unbooked input exists; excess is left uncredited and nothing is refunded." with **EI** in every block, keeping the trailing "Booked holder backing is never pretransfer credit." |
| C6 (`:177,188`) | Replace "Exact-input burns the requested amount and refunds nothing." with **EI-SHARE** at both sites (one wording for both; Astra's extra `burnShares` first-sentence variant is an unneeded distinction — one sentence, no choice). |
| C8 (`:56`) | Replace the final clause ("Exact-input processes exactly `amountIn` … refunds nothing.") with **EI** in the Crane source repo; sync via the approved Crane dependency process and record the delivered revision (Astra's formulation of the mechanics; Grok's `scripts/submodule-commit.sh` pointer step is the same mechanics and acceptable). Do not edit the re-export, mirrors, or skills. |
| C10 (`:24-27`) | Surgical clause swap (Grok's approach), not Astra's whole-paragraph rewrite: replace "and exact-input routes never refund" with "; exact-input routes process the declared input only when present unbooked input covers it and do not refund tokens above the declaration". Keeps the residual/capacity/fee sentences and `:29-32` byte-identical — less collateral, same meaning. |
| D1 README `:32` | **Grok's construction is correct; Astra and MiniMax over-delete.** Keep the measurement sentence **and** "A short push reverts `TransferDeltaInsufficient`." (that sentence is neither the refund nor the equality sentence the PRD withdraws); replace only "Exact-in credits exactly `amountIn` when unbooked availability is sufficient. An exact-in excess push does not revert merely for being excess, and exact-in never refunds." with the PRD `:52` paragraph verbatim. Astra's "replace the remainder of that paragraph" (`:126`) and MiniMax's "sentences 2-4" both drop the short-push sentence, which states still-true behavior. `:38` = PRD `:54` verbatim (with "merely because they are unbooked"); MiniMax's older text is rejected. |
| D2 | Adopt Astra's per-line operations at `:14`, `:63`, `:172`, `:202`, `:203` verbatim (they preserve the historical segments). At `:113` and `:146`, two clause swaps each (Grok caught what Astra's `:113` instruction missed): (a) the equality clause `` `exchangeIn` requires `actualIn == amountIn` `` → "prepaid `exchangeIn` requires unbooked availability to cover the declared `amountIn`; a difference between the declaration and the whole surplus does not by itself revert"; (b) "refunds this-call surplus to `msg.sender`" → "refunds only the unused part of `min(unbooked, declared maximum)` credit to `msg.sender`" — the old phrase overpromises relative to the capped rule. |
| D3 | Note text: Grok's `:140` paragraph (equivalent to Astra's `:158`; either wording is acceptable, pick Grok's shorter one). **Placement ruling: after the execution-complete paragraph ending at line 10, before `## Objective`** (Grok) — not between the H1 and the front matter (Astra) and not after line 8 (my own draft); the front-matter block stays intact. The historical lines 65, 88, 117, 229, 251, 261, 333 are not touched. |
| D4, D5, D6, D7, D9, D10, D13 | Replace the cited withdrawn sentence with **EI**, preserving the surrounding exact-output, false-flag, and label text as Grok's rows specify. |
| D8 (`:7,152`) | Replace the cited sentence with **EI-SHARE** at both lines. |
| D11 | Grok's construction: keep "Exact-in retains sleeve/residual assets" and replace "and refunds nothing." with ". The declared input is processed only when present unbooked input covers it. Tokens above the declaration are not refunded. A difference between the declaration and the whole surplus does not by itself revert. Booked inventory does not fill a shortfall." |
| D12 | Grok's text: replace "EI refunds nothing" with "EI processes the declared input only when present unbooked input covers it and does not refund tokens above that declaration. A difference between the declaration and the whole surplus does not by itself revert. Booked inventory does not fill a shortfall." |

## Other dispositions

- **Verification gate:** keep my draft's `forge build` compile check in the later implementation session. Astra (`:179`) says do not compile to verify prose; the repo rule runs `forge build` after production contract edits, and NatSpec edits are the cheapest place to break a comment terminator — the gate is a build, not a test claim, and no pass claims a test run.
- **Grok's C8 caveat** (`:80`: its direct read of `lib/crane` was denied and it relied on a prior record) is handled correctly by its own stop rule; I confirm from my unimpeded read this session that the old sentence is present at `:56` today.
- Astra's D2 `:203` "Historical rationale, superseded…" prefix on the note cell is adopted; it is the only history-related addition permitted anywhere.

## Unresolved dissent

One: MiniMax's draft stands rejected (stale PRD, omitted rows, C8 misread, false C8 fact); Astra, Grok, and I converge on the full closed list with the per-row wordings above. The remaining differences were editorial and are ruled on above. Consensus is not proof; no pass ran Forge, and no draft authorizes an edit.

I did not run Forge.
