# Kimi K3 — REQ-SEP-04 plan draft (replacement session)

- **Label:** Replacement-session plan draft, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read for this pass. Controlling PRD: `docs/reviews/apex-req-sep-04-amount-out-refund/REMEDIATION_PRD.md` (read in full this round, 88 lines, closed edit list at `:28-70`). Nothing was edited. This draft does not authorize edits; it is not `REMEDIATION_PRD.plan.md`.
- **Scope discipline:** comment and documentation text only. No function-body, signature, selector, or test-expectation change. No ledger. No whole-remainder refund. Slipstream, `contracts/protocols/dexes/uniswap/v4`, `AGENTS.md`, `CLAUDE.md`, `SKILL.md`, and dated review/audit/research records are not touched.

## 1. Spot-check results — every C and D row against current source

All rows verified this round by direct read; the cited sentence is present at the cited line in every case:

| Row | Verified current text (abbreviated) | Present? |
|---|---|---|
| C1 `IUniswapV4Detf.sol:125-126,136-137` | "Exact-input credits the requested amount from unbooked available and refunds nothing." | yes (both) |
| C2 `IMultiVaultWeightedDetfBonding.sol` blocks ending 11/24/30/36/42/48 | "…excess is left uncredited and nothing is refunded." | yes (6 blocks) |
| C3 `ISingleStandardExchangeDETFBonding.sol` blocks ending 12/21/27/33/39/45 | same sentence | yes (6 blocks) |
| C4 `IMixedBufferMultiVaultStableDetfBonding.sol` blocks ending 11/24/30/36/42/48 | same sentence (first block read verbatim; layout identical) | yes (6 blocks) |
| C5 `IDetf.sol:169,238` | "…leaves excess uncredited, and refunds nothing." | yes (both) |
| C6 `IRebasingClaimToken.sol:177,188` | "Exact-input burns the requested amount and refunds nothing." | yes (both) |
| C7 `IStandardExchangeInMulti.sol:27` | "…leaves excess uncredited, and refunds nothing." | yes |
| C8 `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:56` | "Exact-input processes exactly `amountIn` when unbooked available is at least that amount, leaves excess uncredited to this operation, and refunds nothing." | yes |
| C9 `BasicVaultCommon.sol:76` | "Exact-in credits exactly `amountTokenToDeposit` and refunds nothing." (`:17`, `:69-70`, `:113` qualified — preserved) | yes |
| C10 `ERC4626StandardExchangeCommon.sol:24-27` | "…exact-input routes never refund." (`:29-32` precise — preserved) | yes |
| C11 `…OrbitalBufferHookSeTarget.sol:55-57` | "Exact-in credits the requested amount and refunds nothing." | yes |
| D1 README `:32,:38` | withdrawn exact-in and equality sentences present; measurement sentence at `:32` present | yes |
| D2 `uniswap-se-v2-liquidity-leak-fixes.md:14,63,113,146,172,202-203` | `:113` and `:146` teach `exchangeIn` requires `actualIn == amountIn`; `:14,:63,:172,:202-203` carry the terse never-refund phrasing | yes (all read) |
| D3 `uniswap-se-v2-liquidity-leak-fixes.plan.md` | header `:1-10` confirms it is the completed 2026-09-16 execution artifact; historical lines 65/88/117/229/251/261/333 exist per PRD | yes |
| D4 `BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md:21` | "Exact-in pretransfer credits exactly `amountIn` and refunds nothing." | yes |
| D5 `…_IMPLEMENTATION_PLAN.md:45` | "Exact-in pretransfer never refunds." | yes |
| D6 `INDEXEDEX_AGENT_LAW.md:422` | "Exact-in never refunds." | yes |
| D7 `AAVE_V3_STATA_STANDARD_EXCHANGE_VAULT_PLAN.md:376` | "…refunds nothing and leaves the excess uncredited." | yes |
| D8 `REBASING_AWARE_ERC4626_SY_SE_PRD.md:7,152` | "…burns the requested amount and refunds nothing." / "…burns exactly `amountIn` and refunds nothing." | yes (both) |
| D9 `UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md:159` | "Exact-input push processes exactly the declared amount and refunds nothing." | yes |
| D10 `UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md:419` | "- Exact-in refunds nothing." | yes |
| D11 `UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md:214` | "Exact-in retains sleeve/residual assets and refunds nothing." | yes |
| D12 `UNISWAP_V4_FULLSPREAD_ACCEPTANCE_MAP.md:48` | "EI refunds nothing;" | yes |
| D13 `UNISWAP_V4_CLOSED_FORM_CANDIDATE_VALIDATION_AGENT_PROMPT.md:278` | "- exact-in refunds nothing" | yes |

**Stop condition (from PRD `:30`, restated as an order):** if any named line no longer contains the cited sentence, the implementer stops and reports; no substitute line is chosen.

## 2. Canonical replacement texts (the only two phrasings used below)

- **EI-DECL (exact-input comment canonical):** "Exact-input processes exactly the declared amount when present unbooked input covers it; tokens above the declaration are not refunded, and a difference between the declaration and the whole surplus is not an error."
- **EI-DOC (document shorthand):** "Exact-input processes the declared amount when present unbooked input covers it; tokens above the declaration are not refunded; a difference between the declaration and the whole surplus does not by itself revert."

Exact-output sentences already state `min(unbooked, declared maximum)` and are preserved everywhere. Booked-inventory and EOA-guard clauses are preserved everywhere.

## 3. Ordered plan

**Step 0 — Setup.** Work on a `fix_req-sep-04-docs` branch/worktree. Read the PRD in full. Confirm the stop condition. No code, test, or config file other than the rows below is opened for edit.

**Step 1 — D1 (README), the canonical text every other row restates.**
`contracts/vaults/standard/exchange/protocols/uniswap/README.md`:
- `:32` — keep the measurement sentence ("No `preparePretransfer` call is used or exposed. … captured before settlement changes balances."). Replace "Exact-in credits exactly `amountIn` when unbooked availability is sufficient. An exact-in excess push does not revert merely for being excess, and exact-in never refunds. A short push reverts `TransferDeltaInsufficient`." with the PRD `:52` sentence verbatim: "The caller declares the bound. The vault processes only the amount needed for the requested output, and only from present unbooked tokens within that declaration. It refunds the unused part of the declaration to the caller. It does not refund unbooked tokens the caller did not declare. A shortfall is not filled from booked inventory. A pretransfer outside an atomic operation is the sender's responsibility."
- `:38` — replace with the PRD `:54` sentence verbatim: "Unsolicited transfers remain donor risk and can later count toward a declared bound. They are not refunded to a later caller merely because they are unbooked. This does not permit spending inventory already booked by a vault operation."
- Lines 3, 34, 56: untouched.

**Step 2 — C8 (canonical Crane interface) and sync.**
In the **Crane source repository** (not only the submodule working tree), edit `contracts/interfaces/IStandardExchangeIn.sol:56`: replace the final clause "Exact-input processes exactly `amountIn` when unbooked available is at least that amount, leaves excess uncredited to this operation, and refunds nothing." with EI-DECL, keeping the EOA-guard and booked-backing clauses and the `@custom:selector` block unchanged. Land the change in Crane, then update the `lib/crane` submodule pin in IndexedEx so the synced file carries the identical sentence. Do not change the signature.

**Step 3 — Comment rows C1–C7, C9–C11 (IndexedEx tree).** Each is a sentence-level swap; surrounding clauses (atomicity, `EOAPretransferNotAllowed()`, "Booked holder backing is never pretransfer credit", D12 notes) stay byte-identical:
1. C1 `IUniswapV4Detf.sol:125-126` and `:136-137`: replace "Exact-input credits the requested amount from unbooked available and refunds nothing." with EI-DECL (both sites).
2. C2/C3/C4 (three bonding interfaces, six blocks each): replace "Exactly the requested amount is credited when at least that much unbooked input exists; excess is left uncredited and nothing is refunded." with "Exactly the declared amount is processed when at least that much unbooked input exists; excess above the declaration is left uncredited and is not refunded, and inequality with the whole surplus is not an error." Apply identically in all six blocks per file, including blocks preceding view functions — the sentence states the family prepaid rule, not the view's behavior.
3. C5 `IDetf.sol:169` and `:238`: replace "leaves excess uncredited, and refunds nothing" (and the `:238` variant "leaves excess uncredited to this operation and refunds nothing") with "processes exactly the declared amount when present unbooked input covers it; tokens above the declaration are left uncredited and are not refunded, and a difference between the declaration and the whole surplus is not an error".
4. C6 `IRebasingClaimToken.sol:177` and `:188`: replace "Exact-input burns the requested amount and refunds nothing." with "Exact-input burns exactly the declared share amount; shares above the declaration are not this operation's input and are not refunded."
5. C7 `IStandardExchangeInMulti.sol:27`: replace "Exact-input processes each requested amount when unbooked available covers it, leaves excess uncredited, and refunds nothing." with "Exact-input processes each declared amount when present unbooked input covers it; tokens above each declaration are not refunded, and a difference between a declaration and the whole surplus is not an error."
6. C9 `BasicVaultCommon.sol:76` only: replace "Exact-in credits exactly `amountTokenToDeposit` and refunds nothing." with EI-DECL (with `amountTokenToDeposit` as the declared amount). Lines 17, 69–70, 113 untouched.
7. C10 `ERC4626StandardExchangeCommon.sol:24-27`: replace "and exact-input routes never refund." with "; exact-input routes process the declared amount and do not refund tokens above the declaration." Leave the residual-retention and under-consumed-underlying sentences and `:29-32` unchanged.
8. C11 `UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol:55-57`: replace "Exact-in credits the requested amount and refunds nothing." with EI-DECL; keep the `EOAPretransferNotAllowed` and D12 sentences.

**Step 4 — Documentation rows D2–D13.**
- D2 `uniswap-se-v2-liquidity-leak-fixes.md`:
  - `:113` and `:146` — replace "`exchangeIn` requires `actualIn == amountIn`" with "`exchangeIn` requires unbooked availability to cover the declared `amountIn`; a difference between the declaration and the whole surplus does not revert".
  - `:14` — replace "credits exactly the requested `amountIn` when unbooked available covers it, leaves excess uncredited, and refunds nothing (D28; FullSpread D19 exact-in push equality is replaced)" with "processes exactly the declared `amountIn` when unbooked available covers it; tokens above the declaration are left uncredited and are not refunded (D28; FullSpread D19 exact-in push equality is replaced)".
  - `:63` — replace "credits exactly `amountIn`, and leaves the rest uncredited (never refunded, never a revert)" with "processes exactly the declared `amountIn`; the rest is left uncredited, is not refunded, and never reverts for differing from the whole surplus".
  - `:172` — replace "Credit exactly `amountIn`. Extra unbooked above `amountIn` is not refunded and does not revert (D28)." with "Credit exactly the declared `amountIn`. Unbooked input above the declaration is not this operation's input, is not refunded, and does not revert (D28)."
  - `:202-203` (D15/D16 rows) — keep the "Historical text" labels; in the current-rule sentences replace "credits exactly `amountIn` and refunds nothing (excess stays uncredited)" with "processes exactly the declared `amountIn`; excess above the declaration stays uncredited and is not refunded", and mark D16's note-column "extra push reverts rather than refunds" rationale as superseded by the 2026-10-16 answer.
- D3 `uniswap-se-v2-liquidity-leak-fixes.plan.md` — add exactly one note after the status block (after line 8): "Current-law note (2026-10-16, REQ-SEP-04): the prepaid rule is declared-bound — exact-input processes the declared amount and does not refund undeclared tokens; exact-output refunds only the unused part of `min(unbooked, declared maximum)` credit; a declaration differing from the whole surplus does not revert. The checked acceptance items at lines 65, 88, 117, 229, 251, 261, and 333 are preserved as records of the completed 2026-09-16 execution and are not current requirements." No other line in this file is edited.
- D4 `BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md:21` — replace "Exact-in pretransfer credits exactly `amountIn` and refunds nothing." with EI-DOC.
- D5 `…_IMPLEMENTATION_PLAN.md:45` — replace "Exact-in pretransfer never refunds." with EI-DOC.
- D6 `INDEXEDEX_AGENT_LAW.md:422` — replace "Exact-in never refunds." with "Exact-in processes the declared amount; tokens above the declaration are not refunded."
- D7 `AAVE_V3_STATA_STANDARD_EXCHANGE_VAULT_PLAN.md:376` — replace "credits exactly the requested amount when at least that much unbooked input exists, refunds nothing and leaves the excess uncredited" with "processes exactly the declared amount when at least that much unbooked input exists; tokens above the declaration are left uncredited and are not refunded".
- D8 `REBASING_AWARE_ERC4626_SY_SE_PRD.md:7` and `:152` — replace "burns the requested amount and refunds nothing" / "burns exactly `amountIn` and refunds nothing" with "burns exactly the declared share amount; shares above the declaration are not refunded".
- D9 Wings PRD `:159` — replace "Exact-input push processes exactly the declared amount and refunds nothing." with "Exact-input push processes exactly the declared amount; tokens above the declaration are not refunded."
- D10 Zap-in PRD `:419` — replace "- Exact-in refunds nothing." with "- Exact-in processes the declared amount; tokens above the declaration are not refunded."
- D11 FullSpread impl plan `:214` — replace "Exact-in retains sleeve/residual assets and refunds nothing." with "Exact-in processes the declared amount and retains undeclared sleeve/residual assets; tokens above the declaration are not refunded."
- D12 Acceptance map `:48` — replace "EI refunds nothing;" with "EI processes the declared amount and does not refund undeclared tokens;".
- D13 Closed-form prompt `:278` — replace "- exact-in refunds nothing" with "- exact-in processes the declared amount and does not refund tokens above the declaration".

**Step 5 — Verification.** Comment/NatSpec and Markdown edits only; no bytecode changes are expected. Per repo rule, run `forge build` after the Solidity comment edits (comments must not break compilation), then a diff review confirming: no `.sol` diff line touches anything outside a comment; no signature, selector, or test file changed; the D3 note is the only addition to that file; the `lib/crane` diff is exactly the C8 sentence plus the submodule pin. Report the build result and the diff summary. If any named sentence was absent at any row, the run stops at that row and reports instead of substituting.

## 4. Explicit no-choice statement

Every row has a verbatim replacement above or in the PRD (D1). The implementer chooses nothing: not the sites (C1–C11, D1–D13, fixed), not the wording (EI-DECL/EI-DOC or the quoted sentences), not the order (Steps 1–5), not the Crane mechanics (source-repo edit, then pin sync), and not the stop behavior (PRD `:30`).

I did not run Forge.
