# Astra — SEP-04 replacement-session plan draft

Independent plan draft by the labeled replacement, not continuity with `ses_ec412bcc2ffejKLo7nuoEAqbV0`; I do not recall that session. No other reviewers' notes were read for this draft. I read the controlling `docs/reviews/apex-req-sep-04-amount-out-refund/REMEDIATION_PRD.md` in full, including its closed C1–C11 and D1–D13 tables.

This is not `REMEDIATION_PRD.plan.md`. Only this assigned Markdown draft was written. A later, separately authorized session implements the consolidated plan; this draft authorizes no source or documentation changes.

## 1. Preflight and fixed boundaries

**All C and D locations were spot-checked against current text in this pass.** C1–C4 repeated blocks, both C5/C6 sites, C7–C11, both README paragraphs, all seven D2 locations, the seven D3 historical references and every D4–D13 location are present. D3's original heading and front matter were also read to fix the insertion point. No supplied input was missing.

Before the first later edit, validate **all** original locations and quoted anchors below against the unedited files. If a named sentence is absent, changed, or already replaced, **stop and report its C/D ID, path and text discrepancy**. Do not substitute another occurrence, skip it silently, add a new target, or reinterpret the instruction. Validate original line numbers before insertions shift them; subsequently use the validated anchors.

Closed scope: **11 Solidity comment files and 13 Markdown documentation files**. No function-body, declaration, import, signature, selector, storage, test, configuration or executable-script edit. Do not format whole Solidity files. Preserve SPDX, pragmas, NatSpec tags and include markers. No Forge is needed or authorized in this draft session.

Do not edit Slipstream, `contracts/protocols/dexes/uniswap/v4`, any `AGENTS.md`, `CLAUDE.md` or `SKILL.md`, or dated audit/review/research records. Do not rewrite preserved reviewer artifacts. Preserve unrelated working-tree changes. The selected live documents may contain historical passages: the instructions below preserve those passages, except for the explicitly additive current-law annotation.

No attribution ledger, whole-unbooked refund, new exact-input output target or changed economic behavior is introduced. Exact-input uses the declared amount. Exact-output uses bounded credit, not a requirement to deliver the entire maximum when the quoted input needs less.

## 2. Exact replacement text dictionary

The labels below are **exact textual expansions**, not options. Where an edit says to insert E, insert its full literal text, not the letter E. Retain the file's existing comment prefix (`///` or `*`) and indent; wrap only within the replaced comment. Markdown table cells retain their existing delimiters and unaffected columns.

**E — single-input rule**

> A prepaid exact-input operation processes the declared input amount only when present unbooked input covers it. Tokens above that declaration are not refunded. A difference between the declaration and the whole surplus does not by itself revert. Booked inventory never fills an input shortfall.

**S — share-input rule**

> A prepaid exact-input redemption burns the declared share amount only when available unbooked shares cover it. Shares above that declaration are not refunded. A difference between the declaration and the whole share surplus does not by itself revert. Booked holder backing never fills an input shortfall.

**M — multi-input rule**

> For a prepaid exact-input operation, each declared input amount is processed only when that token's present unbooked input covers it. Tokens above each declaration are not refunded. A difference between a declared amount and that token's whole surplus does not by itself revert. Booked inventory never fills an input shortfall.

**O — exact-output rule**

> A prepaid exact-output operation uses only the input needed for the requested output, with credit equal to `min(unbooked, declared maximum)`. Required input above that credit reverts; the unused part of that bounded credit is refunded to the caller. Unbooked tokens above the declaration are not refunded, and booked inventory never fills an input shortfall.

**P — pull distinction**

> False-flag exact-output pulls only the quoted input needed for the requested output; exact-input pulls retain their measured-delivery check. Pull-delta equality is not a requirement that a prepaid declaration equal the whole unbooked surplus.

Do not globally replace “refunds nothing.” Apply only the following locations. In particular, correct exact-output capped-refund comments, qualified unclaimed-surplus booking comments and actual test assertions remain untouched.

## 3. Comment edits in order C1–C11

### C1 — Uniswap V4 DETF interface

File: `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol`.

At both 126 and 137, replace the complete sentence `Exact-input credits the requested amount from unbooked available and refunds nothing.` with **E**. Keep the preceding `@param pretransferred` and caller-bytecode sentence at 125/136. Do not change `bond` or `donate` signatures.

### C2, C3, C4 — repeated DETF bonding-interface blocks

| ID | File | Original block endings |
|---|---|---|
| C2 | `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfBonding.sol` | 11, 24, 30, 36, 42, 48 |
| C3 | `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFBonding.sol` | 12, 21, 27, 33, 39, 45 |
| C4 | `contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfBonding.sol` | 11, 24, 30, 36, 42, 48 |

In **each of the six blocks in each file**, retain the text through `A caller with no bytecode reverts ...` and replace the two following sentences beginning `Exactly the requested amount is credited` and ending `Booked holder backing is never pretransfer credit.` with **E**. The block describes prepaid operation semantics; it does not assert that an adjacent view function moves funds. Do not relocate comments to new functions or remove the repeated blocks as unrelated cleanup. Exactly 18 block replacements are required across these three files.

### C5 — core DETF interface

File: `contracts/interfaces/detf/IDetf.sol`.

- At 169, replace the final sentence beginning `Exact-input processes exactly` and referring to `rateAssetAmount` with **E**. Preserve the `@param` prefix and all preceding integrating-contract, atomicity, caller-check and backing text.
- At 238, replace the final sentence beginning `Exact-input processes exactly the requested amount` through its repeated `booked holder backing is never pretransfer credit.` ending with **E**. Preserve preceding text. Do not change `mintWithRateAsset` or `donate`.

### C6 — claim-token interface

File: `contracts/interfaces/IRebasingClaimToken.sol`.

At both 177 and 188 replace only `Exact-input burns the requested amount and refunds nothing.` with **S**. Keep preceding `@param pretransferred` qualifications. For the `burnShares` occurrence, use the following exact variant instead of the first sentence of S: **“A prepaid exact-input burn consumes the declared share amount only when available unbooked shares cover it.”** The remaining three sentences of S stay identical. No signature, return parameter or authorization change.

### C7 — multi-input exchange interface

File: `contracts/interfaces/IStandardExchangeInMulti.sol`.

At 27 replace the sentence starting `Exact-input processes each requested amount` with **M**. Preserve the preceding caller/atomicity text and `minAmountOut`'s minimum semantics.

### C8 — canonical Crane input interface and synchronization

File: `lib/crane/contracts/interfaces/IStandardExchangeIn.sol`.

At 56 replace only the sentence beginning `Exact-input processes exactly` and ending `refunds nothing.` with **E**. Keep preceding caller, timing, unrecorded-balance and backing text, as well as the `@return` and selector tag below. No signature change.

**Crane sync note:** this is the canonical Crane Solidity source, not a local duplicate. `remappings.txt:3` maps `@crane/` to `lib/crane/`, and `contracts/interfaces/IStandardExchangeIn.sol:4` merely re-exports that canonical interface. Therefore the working-tree consumer already reads the edited source; do **not** copy its text into that re-export, generated outputs, skill mirrors or another interface file. For repository delivery, carry this source change through the approved Crane dependency synchronization/release process and record the delivered Crane revision alongside the consuming change; this plan itself grants no commit, push, signing or dependency-update authority. If that delivery authorization is unavailable, report C8 synchronization as pending rather than pretending a local mirror edit completes it. Do not run `sync-crane-skills.sh`: it synchronizes skills, not this interface, and would touch excluded skill targets.

### C9 — base vault helper comment

File: `contracts/vaults/basic/BasicVaultCommon.sol`.

Replace the sentence at **76 only**, `Exact-in credits exactly ... and refunds nothing.`, with **E**. Keep the qualified unclaimed-surplus sentences at 17 and 69–70 and the false-flag/exact-output helper documentation unchanged. No helper-body edit.

### C10 — generic ERC4626 common introduction

File: `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol`.

Replace the `@dev` paragraph at 24–27 with this exact paragraph:

> APEX 2026-09-17 (D6/D15/D22/D31/R14), clarified by REQ-SEP-04: a prepaid exact-input operation processes its declared input only when covered by present unbooked input; undeclared surplus is not refunded and surplus inequality alone does not revert. Credited underlying retained because of capacity or pause remains booked backing and is swept into the protocol vault by a later investing operation; it is not a refund of undeclared input and is not paid to the fee recipient. Prepaid exact-output refunds only the unused part of `min(unbooked, declared maximum)` to the caller. Booked inventory never fills an input shortfall. Under-delivery of amountOut is Slippage.

Retain the separate detailed credit paragraph at 29–32 and all functions below it. This does not alter the sleeve, capacity, fee or investment policy.

### C11 — orbital exchange entry comment

File: `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol`.

Replace the full `@dev` paragraph at 55–57 with:

> A prepaid exact-input operation processes the declared input only when present unbooked input covers it; tokens above that declaration are not refunded, surplus inequality alone does not revert, and booked inventory never fills a shortfall. `pretransferred=true` is for integrating contracts only and reverts `EOAPretransferNotAllowed` for a caller with no bytecode. Resting unbooked face may count toward a declaration without attribution; it is not refundable merely because it is unbooked.

Do not change `_entryExchangeIn` or any caller.

## 4. Documentation edits in order D1–D13

### D1 — README: use the PRD's exact paragraphs

File: `contracts/vaults/standard/exchange/protocols/uniswap/README.md`.

At 32 preserve these two sentences exactly:

> No `preparePretransfer` call is used or exposed. The measured pushed input is `balanceOf(vault) - reserveOfToken(token)` captured before settlement changes balances.

Replace the remainder of that paragraph with the PRD's literal text:

> The caller declares the bound. The vault processes only the amount needed for the requested output, and only from present unbooked tokens within that declaration. It refunds the unused part of the declaration to the caller. It does not refund unbooked tokens the caller did not declare. A shortfall is not filled from booked inventory. A pretransfer outside an atomic operation is the sender's responsibility.

Replace the entire paragraph at 38 with the PRD's literal text:

> Unsolicited transfers remain donor risk and can later count toward a declared bound. They are not refunded to a later caller merely because they are unbooked. This does not permit spending inventory already booked by a vault operation.

Leave original lines **3, 34 and 56** byte-for-byte unchanged. Do not use this item to fix other README history.

### D2 — live liquidity-leak PRD: seven exact locations

File: `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.md`.

Do not replace entire long rows or paragraphs when the instruction below specifies a substring. Preserve all other current and historical text, Markdown columns and checkboxes.

| Original line | Exact replacement operation |
|---|---|
| 14 | Replace the complete sentence beginning `Exact-input pretransfer credits exactly the requested` and ending `(D28; FullSpread D19 exact-in push equality is replaced).` with **E**. Preserve the dated amendment heading, caller check, pull rules and other sentences. |
| 63 | Replace from `unbooked surplus` immediately after the D28 amendment label through `never a revert);` with: **“unbooked surplus `U = balanceOf - reserveOfToken` is available credit; a prepaid exact-input operation processes its declared `amountIn` only if `U >= amountIn`, leaves tokens above that declaration outside the operation without refund, and does not revert merely because `U != amountIn`;”**. Preserve the following EOA sentence and every word beginning `Historical rule:` onward. |
| 113 | Replace only the clause `` `exchangeIn` requires `actualIn == amountIn`; `` with: **“prepaid `exchangeIn` requires unbooked availability to cover declared `amountIn`, processes that declaration, and does not refund undeclared surplus or reject surplus inequality; false-flag exact-input retains measured-pull equality;”**. The rest of this checklist line remains unchanged. |
| 146 | Replace the first three sentences, from `Delivery for` through `refunds this-call surplus to ...`, with: **“For `pretransferred=true`, available credit is the unbooked balance above `reserveOfToken`. Exact-input processes the declared `amountIn` only when that credit covers it; undeclared surplus is not refunded and inequality with the whole surplus does not by itself revert. Exact-output credits `min(unbooked, declared maximum)`, rejects required input above that credit, and refunds only unused bounded credit to `msg.sender`; booked inventory never fills an input shortfall.”** Keep all following reserve-booking and share-math sentences unchanged. |
| 172 | Replace the entire paragraph with the literal concatenation **E + O + P**, in that order, followed by: **“Public `pretransferred=true` is contract-only; a caller with no bytecode reverts `EOAPretransferNotAllowed()`. Catalog E6 protects booked reserves.”** |
| 202 | Inside the `Current rule:` segment, replace only the clause `exact-in pretransfer requires unbooked ... (excess stays uncredited);` with: **“exact-in pretransfer processes declared `amountIn` only when unbooked availability covers it; undeclared surplus is not refunded and surplus inequality alone does not revert;”**. Preserve the pull-equality clause, other exact-output clauses and everything starting `Historical text:`. |
| 203 | Replace the current-rule text between the D15/D28 amendment label and `Historical text:` with: **“a prepaid exact-input operation processes declared `amountIn` when unbooked input covers it; surplus above that declaration is undeclared and not refunded, and inequality between the declaration and the whole surplus does not by itself revert. ”** Keep the `Historical text:` segment intact. In the last table cell, prefix the existing `Owner:` sentence with **“Historical rationale, superseded for prepaid surplus equality: ”** so the retained extra-push-revert statement cannot be read as current instruction. |

### D3 — one additive current-law note; historical body untouched

File: `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.plan.md`.

Insert the following single paragraph immediately after the existing level-one heading and its following blank line, before the original `- **PRD:**` front matter:

> **Current-law note — REQ-SEP-04, owner answer 2026-10-16:** The dated implementation and checked acceptance records below are preserved historical evidence, not authority to require a prepaid declaration to equal the whole unbooked surplus. Prepaid exact-input processes declared `amountIn` only when present unbooked input covers it, does not refund tokens above that declaration, and does not revert merely because the declaration differs from the whole surplus. Prepaid exact-output credit is `min(unbooked, declared maximum)`; required input above credit reverts and only unused bounded credit is refunded to the caller. Booked inventory never fills an input shortfall. No attribution ledger or whole-unbooked-remainder refund is introduced. This clarification supersedes prepaid surplus-equality directions recorded at the pre-note lines 65, 88, 117, 229, 251, 261 and 333; it does not alter false-flag measured-pull checks or rewrite any historical result. Controlling text: `docs/reviews/apex-req-sep-04-amount-out-refund/REMEDIATION_PRD.md`.

Do not alter the original heading, front matter, status, historical body, checked records or reported test results. The original entire file must remain intact after removing the one inserted paragraph and its separating blank line.

### D4–D13 — fixed replacements

| ID / exact file / original line | Replacement text and scope |
|---|---|
| **D4** `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md:21` | Replace only `Exact-in pretransfer credits exactly ... and refunds nothing.` with **E**, and `Exact-out pretransfer refunds only ...` with **O**. Keep the table label, caller restriction, false-flag sentence and source reference. No other row changes. |
| **D5** `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md:45` | Keep the `L-RSRV-ABSORB` label and replace its value cell with: **“Prepaid exact-input processes the declared amount only when unbooked input covers it; tokens above that declaration are not refunded and remain subject to the existing end-of-operation booking rule. Declaration/whole-surplus inequality alone does not revert. Prepaid exact-output refunds only `min(unbooked, declared maximum) - used` to the caller after required-input sufficiency is checked. False-flag exact-output pulls only quoted used input. Booked inventory never fills an input shortfall.”** |
| **D6** `docs/agent/INDEXEDEX_AGENT_LAW.md:422` | Replace only `Exact-in never refunds.` with **E**. Keep the failure-class cell, EOA and I1 errors, credit statement, false-flag statement and references. No edit to any excluded instruction filename. |
| **D7** `contracts/protocols/lending/aave/v3.6/AAVE_V3_STATA_STANDARD_EXCHANGE_VAULT_PLAN.md:376` | Replace the first exact-input sentence with **E**. Keep the exact-output formula, exact credit error and false-flag quoted-share burn sentences unchanged. |
| **D8** `contracts/protocols/staking/rebasingVault/REBASING_AWARE_ERC4626_SY_SE_PRD.md:7,152` | In each paragraph replace only the sentence starting `Exact-input share pretransfer burns` and ending `refunds nothing.` with **S**. Keep exact-output share-credit/refund formulas, asset/pretransfer restrictions, error names, failure rollback statements and historical labels. |
| **D9** `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md:159` | After `**C3.**`, replace only `Exact-input push processes exactly the declared amount and refunds nothing.` with **E**. Keep the remaining excess, exact-output, pull and SY-context sentences unchanged. |
| **D10** `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md:419` | Replace that bullet with: **“- Prepaid exact-input processes its declared input only when present unbooked input covers it; tokens above the declaration are not refunded, surplus inequality alone does not revert, and booked inventory never fills a shortfall.”** Keep adjacent source-agnostic and booking bullets. |
| **D11** `docs/plans/UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md:214` | Replace only `Exact-in retains sleeve/residual assets and refunds nothing.` with: **“Prepaid exact-input processes the declared input only when present unbooked input covers it; undeclared surplus is not refunded and surplus inequality alone does not revert. Credited sleeve/residual assets retain their existing backing treatment, and booked inventory never fills an input shortfall.”** Keep collection/placement and native wrapping sentences unchanged, and do not modify the separate SY paragraph at 216. |
| **D12** `docs/plans/UNISWAP_V4_FULLSPREAD_ACCEPTANCE_MAP.md:48` | Replace only `EI refunds nothing;` with: **“Prepaid EI processes the declared input only when present unbooked input covers it, does not refund tokens above the declaration, and does not reject surplus inequality; booked inventory never fills an input shortfall;”**. Keep proxy identity, pull/push definitions, both EO clauses, rollback and SY statements unchanged. |
| **D13** `docs/plans/UNISWAP_V4_CLOSED_FORM_CANDIDATE_VALIDATION_AGENT_PROMPT.md:278` | Replace that bullet with: **“- prepaid exact-in processes the declared input only when present unbooked input covers it, does not refund tokens above the declaration, and does not revert merely because the declaration differs from the whole surplus”**. Keep adjacent assertion bullets; do not execute the retrieved prompt or change any tests. |

## 5. Verification and stop conditions

This is a comment/document-only plan. Do not run a Solidity formatter, compile, deploy, generate selector values or alter test expectations to verify prose. Preserve all existing selector/interface tags: none changed because no declaration changed.

The later authorized session must inspect its diff against the pre-edit baseline and report:

1. Exactly C1–C11 and D1–D13 content targets were edited; C8 is in canonical Crane, not a re-export or mirror. Any dependency synchronization delivery status is recorded separately and is not permission for unrelated source or configuration changes.
2. Every Solidity change is within an existing comment/NatSpec range. Non-comment Solidity tokens, signatures, imports, error declarations and bodies are unchanged. Any non-comment change fails verification and stops the task; do not justify it as needed to make the prose true.
3. All 18 repeated C2–C4 blocks, both occurrences in C1/C5/C6, and both D8 paragraphs were handled. No partial “representative” update.
4. README paragraphs use the PRD's exact text, measurement text is preserved, and original lines 3, 34 and 56 are unchanged.
5. D2 historical passages remain verbatim; the only history-related addition there is the specified D16 rationale label. D3's original file content is wholly unchanged apart from the one current-law note. Dated review/audit/research records elsewhere are unchanged.
6. No global phrase sweep, new file, ledger, entire-unbooked refund, caller-attribution promise or new API interpretation was added. Already-qualified no-undeclared-refund rules and precise bounded exact-output formulas outside the closed list were not touched.
7. The final result records each C/D ID as completed or stopped, identifies any missing sentence, and records C8's actual synchronization status. Do not claim a test pass: no executable change or test run is part of this review draft.

If any named original sentence is gone at implementation preflight, stop the **whole edit batch** and report it rather than choosing another location. If an edit shifts later line numbers within this batch, use the already-validated anchors; that self-induced shift is not source drift. If C8 cannot be delivered through the approved Crane synchronization process, report that specific pending delivery rather than copying it into another target or claiming complete delivery.

## 6. Evidence and boundaries of this draft

Direct reads/searches in this pass confirmed all listed target text, including the long D2 current/historical segments and all D3 reference anchors. The source re-export and remapping establish the C8 working-tree dependency path. Canonical Crane NatSpec guidance was read directly; no skill tool was used. Root repository rules and local/canonical testing/architecture guidance were read earlier in this replacement session and remain subordinate to the task's no-execution scope.

No other reviewers' notes, previous peer cross-reviews, shell commands, background agents, tests or deployments were used for this independent draft. The assigned output did not exist before this write. No claim is made that the eventual delivery/synchronization has already happened. No findings or product decisions beyond the controlling closed list are introduced.

I did not run Forge.
