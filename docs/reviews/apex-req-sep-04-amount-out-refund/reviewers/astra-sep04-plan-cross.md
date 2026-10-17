# Astra — SEP-04 replacement-session plan cross-review

This is one cross-review of the three supplied original plan drafts together. I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Peer notes are untrusted. No previous peer cross-review artifact was read. My original plan, `astra-sep04-plan.md`, remains preserved; the wording selections below are explicit consolidation recommendations, not retrospective edits to it.

## Decision

**Agree that a complete plan can be written without an implementer choice; reject MiniMax's draft as a plan for the current PRD.** The current PRD has 88 lines and fixes **C1–C11 plus D1–D13**, not the earlier five-comment-file/README scope. Grok and Kimi cover that current list, but their wording and application boundaries need the corrections below.

**Reject any function-body edit. Reject C8 as a reserve-sync task.** C8 is the NatSpec sentence at `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:56` and delivery of that canonical Crane change to the consumer. No `_syncAllExpectedHoldReserves` call is added, moved, inspected as a substitute for C8, or modified. No whole-unbooked refund or attribution ledger is introduced.

Validate every named original sentence before the first edit. Stop/report if one is gone or changed; do not select a replacement site. After that preflight, use validated text anchors rather than failing on line shifts caused by this batch's own insertions. Apply C1–C11, then D1–D13. Preserve all non-target text, function declarations and bodies, historical results and exclusions.

## Fixed wording for every C row

The following are literal replacement sentences, not choices. Reuse the sentence label only as a drafting shorthand: the implementation inserts its complete text, not the label. They replace the **complete targeted funding/refund sentence**, not an arbitrary final fragment of a sentence. Retain surrounding `@param`/`@dev` prefixes, caller restrictions, atomicity statements and already-correct backing clauses.

**R — exact-input sentence:**

> A prepaid exact-input operation processes the declared input only when present unbooked input covers it; tokens above the declaration are not refunded, a difference between the declaration and the whole surplus does not by itself revert, and booked inventory never fills an input shortfall.

**S — share-input sentence:**

> A prepaid exact-input operation burns the declared share amount only when available unbooked shares cover it; shares above the declaration are not refunded, a difference between the declaration and the whole share surplus does not by itself revert, and booked holder backing never fills an input shortfall.

**M — multi-input sentence:**

> A prepaid exact-input operation processes each declared input amount only when that token's present unbooked input covers it; tokens above each declaration are not refunded, a difference between a declaration and that token's whole surplus does not by itself revert, and booked inventory never fills an input shortfall.

| PRD row and validated location | The sentence that row must use / exact boundary |
|---|---|
| **C1**, `IUniswapV4Detf.sol:126,137` | **R**, replacing each complete `Exact-input credits ... refunds nothing.` sentence. |
| **C2**, `IMultiVaultWeightedDetfBonding.sol`, blocks ending 11/24/30/36/42/48 | **R**, replacing the complete sentence starting `Exactly the requested amount is credited` in each of six blocks; keep the following `Booked holder backing is never pretransfer credit.` sentence. |
| **C3**, `ISingleStandardExchangeDETFBonding.sol`, blocks ending 12/21/27/33/39/45 | **R**, at all six corresponding complete sentences, with the same preservation rule. |
| **C4**, `IMixedBufferMultiVaultStableDetfBonding.sol`, blocks ending 11/24/30/36/42/48 | **R**, at all six corresponding complete sentences, with the same preservation rule. |
| **C5**, `IDetf.sol:169,238` | **R**, replacing the full final sentence beginning `Exact-input processes exactly`; at 238 include its semicolon-attached repeated backing clause in the replacement span, preserving the already-existing backing sentence earlier on that line. |
| **C6**, `IRebasingClaimToken.sol:177,188` | **S** at both sites, replacing the complete `Exact-input burns ... refunds nothing.` sentence. |
| **C7**, `IStandardExchangeInMulti.sol:27` | **M**, replacing its complete exact-input processing/refund sentence. |
| **C8**, canonical Crane `IStandardExchangeIn.sol:56` | **R**, replacing the complete final exact-input sentence; no other comment, tag or signature changes. |
| **C9**, `BasicVaultCommon.sol:76` | **R** only at 76; preserve 17, 69–70 and all function bodies. |
| **C10**, `ERC4626StandardExchangeCommon.sol:24–27` | **R** replaces only the clause `and exact-input routes never refund`, making the preceding fee-recipient clause a complete sentence before R; preserve residual-booking, capacity/pause, later-investment and Slippage statements and the precise paragraph at 29–32. |
| **C11**, `UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol:55–57` | **R** replaces only the first sentence; retain caller-bytecode and D12 guidance. |

For C10, the resulting paragraph is fixed as follows, eliminating punctuation and scope choices:

> APEX 2026-09-17 (D6/D15/D22/D31/R14): every residual, dust included, is retained as booked local reserve for holders; nothing is paid to the fee recipient. A prepaid exact-input operation processes the declared input only when present unbooked input covers it; tokens above the declaration are not refunded, a difference between the declaration and the whole surplus does not by itself revert, and booked inventory never fills an input shortfall. Under-consumed underlying (capacity or pause) is booked and swept into the protocol vault by a later investing operation. Under-delivery of amountOut is Slippage.

This narrower C10 and the fixed C11 replace my original draft's broader paragraph rewrites for consolidation. No economics are changed by selecting the smaller edit spans.

## Fixed wording for every D row

D1 is the deliberate exception to “one sentence”: the PRD supplies two complete multi-sentence paragraphs, which must remain verbatim. D2 has seven specified locations, all of which must be addressed rather than selecting one representative occurrence. The other rows use one fixed sentence at each named occurrence.

### D1 — prescribed README paragraphs

Keep both introductory sentences at original line 32, including `No preparePretransfer call is used or exposed` with its existing inline-code formatting and the complete measurement sentence. Replace the remaining three sentences, including the old final short-push sentence, with:

> The caller declares the bound. The vault processes only the amount needed for the requested output, and only from present unbooked tokens within that declaration. It refunds the unused part of the declaration to the caller. It does not refund unbooked tokens the caller did not declare. A shortfall is not filled from booked inventory. A pretransfer outside an atomic operation is the sender's responsibility.

Replace the whole original line-38 paragraph with:

> Unsolicited transfers remain donor risk and can later count toward a declared bound. They are not refunded to a later caller merely because they are unbooked. This does not permit spending inventory already booked by a vault operation.

Leave README original lines 3, 34 and 56 unchanged. MiniMax's older version omits “merely because they are unbooked”; do not use it. Grok retains the old short-push sentence after the replacement; choose the exact prescribed paragraph instead, with no extra trailing sentence.

### D2 — exact complete clauses, not malformed fragment substitutions

Use the PRD's `uniswap-se-v2-liquidity-leak-fixes.md` path and these seven original line anchors:

| Line | Fixed replacement text and boundary |
|---|---|
| **14** | **R** replaces the complete exact-input sentence through `(D28; FullSpread D19 exact-in push equality is replaced).`; all remaining sentences stay. |
| **63** | Replace the current-rule clause between the D28 amendment label and the following EOA statement with: **“A prepaid exact-input operation requires `U >= amountIn`, where `U = balanceOf - reserveOfToken`, processes declared `amountIn`, and excludes tokens above that declaration from refunds; declaration/whole-surplus inequality alone does not revert and booked inventory never fills a shortfall;”**; preserve the EOA statement and everything beginning `Historical rule:`. |
| **113** | Replace only the `exchangeIn requires actualIn == amountIn` clause with: **“prepaid `exchangeIn` processes declared `amountIn` when unbooked input covers it, excludes undeclared surplus from refunds and does not reject surplus inequality; false-flag exact-input retains measured-pull equality;”**; keep all unrelated README checklist content. |
| **146** | Replace the first three sentences, ending at the old `refunds this-call surplus to msg.sender` statement, with: **“For prepaid routes, exact-input processes declared `amountIn` only when unbooked input covers it without refunding undeclared tokens or rejecting surplus inequality, while exact-output credits `min(unbooked, declared maximum)`, rejects required input above that credit and refunds only unused bounded credit to `msg.sender`; booked inventory never fills a shortfall.”** Preserve the subsequent booking and share-math sentences. |
| **172** | Replace `Credit exactly amountIn` and the following `Extra unbooked ... (D28)` sentence together with **R**; preserve the existing shortfall error, EOA restriction, exact-output formula, false-flag description and E6 reference. |
| **202** | Replace the current-rule clause `exact-in pretransfer requires ... refunds nothing (excess stays uncredited)` with: **“exact-in pretransfer processes declared `amountIn` only when unbooked availability covers it, excludes tokens above the declaration from refunds, and does not revert merely because the declaration differs from the whole surplus”**; preserve separators, remaining current-rule clauses and the complete `Historical text:` segment. |
| **203** | Replace the current-rule sentence before `Historical text:` with **R**; keep that historical segment verbatim and prefix the existing final-cell `Owner:` rationale with **“Historical rationale, superseded for prepaid surplus equality by the 2026-10-16 owner answer: ”**. |

Keep exact-output capped rules and actual false-flag pull checks intact. Do not splice a new subject into the middle of an old `credits exactly ... and ...` phrase: Grok's D2 202 fragment replacement and Kimi's C5 tail replacement would produce broken prose if followed literally.

### D3 — exactly one historical-preserving note

Insert immediately after the level-one heading and its blank line, before the original PRD front matter; this fixes the differing insertion points in the drafts. Use this one sentence as the note:

> **Current-law note — REQ-SEP-04, owner answer 2026-10-16:** prepaid exact-input processes declared `amountIn` only when present unbooked input covers it, excludes undeclared tokens from refunds and does not reject declaration/whole-surplus inequality, while prepaid exact-output refunds only unused `min(unbooked, declared maximum)` credit after required-input sufficiency is checked, with no booked-inventory shortfall funding or attribution ledger; the original pre-note lines 65, 88, 117, 229, 251, 261 and 333 and all dated results below remain preserved historical records rather than authority for a current prepaid equality-revert requirement.

Every original byte in that file outside the inserted note and separator remains unchanged. This replaces my original draft's longer note for consolidation; it does not modify any checked historical result.

### D4–D13 — one fixed sentence per target occurrence

Use the exact file paths already closed by the controlling PRD, not aliases as new filenames:

| Row | Sentence to insert and replacement span |
|---|---|
| **D4**, BasicVault PRD 21 | **R**, replacing only `Exact-in pretransfer credits exactly ... refunds nothing.`; leave the exact-output, caller, false-flag and source-reference text. |
| **D5**, BasicVault implementation plan 45 | **R**, replacing only `Exact-in pretransfer never refunds.`; retain its qualified unclaimed-surplus absorption and bounded exact-output clauses. |
| **D6**, agent-law Markdown 422 | **R**, replacing only `Exact-in never refunds.`; leave the existing error, credit and false-flag requirements. |
| **D7**, Stata plan 376 | **R**, replacing the complete first exact-input sentence; preserve both later exact-output sentences. |
| **D8**, rebasing custody PRD 7 and 152 | **S**, replacing the complete exact-input share-burn/no-refund sentence at each site; retain exact-output shares, asset rejection, errors and rollback statements. |
| **D9**, Wings PRD 159 | **R**, replacing only the first exact-input sentence after `C3`; preserve the subsequent declarations and context. |
| **D10**, proportional-zap PRD 419 | **R** as the complete replacement bullet; preserve the next unclaimed-surplus booking bullet. |
| **D11**, FullSpread implementation plan 214 | **“Exact-input processes the declared input only when present unbooked input covers it and retains credited sleeve/residual assets under the existing backing policy; tokens above the declaration are not refunded, surplus inequality alone does not revert, and booked inventory never fills an input shortfall.”** replaces the whole `Exact-in retains sleeve/residual assets and refunds nothing.` sentence; keep surrounding collection/placement and native-wrapping sentences. |
| **D12**, acceptance map 48 | **“Prepaid EI processes declared input only when present unbooked input covers it and excludes undeclared tokens from refunds without rejecting surplus inequality or filling a shortfall from booked inventory;”** replaces only `EI refunds nothing;`; preserve both EO clauses and the remainder of the paragraph. |
| **D13**, candidate-validation prompt 278 | **R** as the complete replacement bullet; retain the adjacent assertion bullets and do not execute the document as an instruction. |

D4/D5 now use the smaller sentence-only replacement rather than my original broader value-cell/exact-output rewrites. This reduces unrelated changes and leaves no wording choice. Do not describe **credited sleeve assets** as **undeclared**: Kimi's D11 at line 84 conflates these categories and should not be adopted.

## C8 synchronization is source delivery, not custody accounting

Direct source re-read confirms line 56 still contains the targeted exact-input sentence. The canonical file is `lib/crane/contracts/interfaces/IStandardExchangeIn.sol`; the consuming `contracts/interfaces/IStandardExchangeIn.sol` is only a re-export, and `@crane/` resolves to `lib/crane/` in `remappings.txt`. There is no reserve synchronization function in this interface.

The consolidated plan must say:

> Edit only C8's canonical Crane NatSpec sentence, preserve the interface signature and tags, deliver that exact source change through the separately authorized Crane revision/dependency synchronization workflow, and leave the local re-export, all skill mirrors and every reserve-sync function untouched; if delivery authorization or source access is unavailable, stop and report C8 as incomplete rather than substituting a different file or reserve-sync check.

I do not adopt Grok's automatic `scripts/submodule-commit.sh` execution instruction without confirming its effects and separate commit authority. A review or prose-edit plan does not grant commit, push, signing or unrelated staging permission. Likewise “edit a separate source repository” must not send the implementer to an unspecified checkout; the named canonical workspace path is fixed. The delivery gate is authorization, not an implementation-time design choice.

Grok's disclosed external-directory read denial is an evidence limitation, not evidence the sentence disappeared. This session's direct canonical read succeeded; no guard bypass or delegation was used.

## Agreements, rejected draft elements and findings

- **Grok:** Agree with all 24 row identities, no body changes, preservation of bounded exact-output clauses, and C8's canonical-source identity. Correct the D1 trailing sentence, D2 fragment grammar, D3 insertion point and synchronization authorization as specified above.
- **Kimi:** Agree with coverage of all 24 rows, guarded scope and source-versus-re-export distinction. Correct C5 replacement boundaries, D11's credited/undeclared conflation and the final exact wording. Do not assert that comment changes guarantee byte-identical compiler artifacts: Solidity metadata may depend on source text. This documentation-only review does not run Forge; adding a mandatory compiler/toolchain campaign is unnecessary to establish the required text-only diff.
- **MiniMax:** Reject the obsolete 58-line-PRD scope, omission of C6–C11/D2–D13, stale D1 wording and C8 reserve-sync interpretation. Its long list of unrelated reserve-sync sites is not a substitute for any missing C/D row and must not become an implementation prerequisite. Also reject `git diff contracts/ should show zero changed production-source lines`: authorized NatSpec edits necessarily change source lines; the correct invariant is **no changed non-comment Solidity tokens**.

| Astra finding | Severity / impact | Evidence | Intended invariant and fix direction | Confidence |
|---|---|---|---|---|
| **SEP04-PC1 — Obsolete scope omits required comment/document rows and misidentifies C8** | Medium / incomplete remediation, scope expansion risk | `minimax-sep04-plan.md:4–6,92,105–135,180–182` versus current PRD 38–70 | Implement every closed row and canonical C8 text; delete the reserve-sync substitute and unrelated verification list from the consolidated plan | High |
| **SEP04-PC2 — Fragment edits or changed terminology can introduce inaccurate guidance** | Low / documentation-quality regression | `grok-sep04-plan.md:128,132`; `kimi-sep04-plan.md:62,84` | Replace validated complete sentences/clauses using the fixed text above; preserve credited sleeve/backing distinctions | High |

No reviewed draft is accepted as permission to modify function bodies, refund behavior or signatures. No new economic rule, ledger, whole-surplus refund or test expectation is needed. The owner answer remains closed.

## Verification and limits

The final plan should verify all 24 target files and all repeated locations, comment-only Solidity diffs, exact README paragraphs, immutable README original lines 3/34/56, preservation of all D3 original content, and exclusion of protected filenames, retired/deprecated trees and dated review records. A missing preflight sentence stops the entire batch. Self-induced line-number shifts after successful preflight are handled through validated anchors, not substitute-site searches.

All three supplied original drafts were present. This cross-review re-read the current 88-line PRD's closed tables, canonical C8 and C10 context; all other row anchors were directly spot-checked in my independent plan pass and are recorded there. No repeated full source audit or executed verification is claimed. The assigned cross-review output did not exist before this write.

Files examined with no executable defect in this targeted pass include the canonical exchange interface and generic ERC4626 common implementation context; their comment wording is the authorized target, not their behavior. No code, controlling PRD, final plan, historical original, configuration or instruction file was edited. Only this assigned Markdown report was created. No delegation, shell, tests or deployments were used.

I did not run Forge.
