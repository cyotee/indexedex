# Coordinator draft

## Draft identity

- Draft ID: draft-pairtoken-prd-sourcify-accuracy-20261027-r1
- Path: docs/reviews/pairtoken-prd-sourcify-accuracy-20261027/coordinator/draft.md
- Run ID: pairtoken-prd-sourcify-accuracy-20261027
- Status: pending advisory review. This file is not the final.
- Fingerprint: not embedded. A hash written into these bytes cannot authenticate them. The coordinator records the raw-file SHA-256 in RUN.md and in the advisory assignment after shasum. Members verify that assignment against the file bytes.
- Sources: members/astra/response.md, members/grok/response.md, members/minimax/response.md, members/kimi/response.md, the pinned PRD, and the admitted Sourcify decode. Member originals are preserved and are not rewritten by this draft.

## Participation

- Council kind: full
- Requested members: Astra, Grok, MiniMax, Kimi
- Substantive initial responses: all four
- Missing initial responses: none
- Result label: full
- Coordinator mode: invoking-agent
- Coordinator is an independent vote: no

Astra used chatgpt-subscription/gpt-6-astra:high, task st_01a17e7a, and reported session 01a17e7a-70bc-78fc-842a-9d14253e4444. Grok used xai/grok-4.7:xhigh, task st_01a17e7b. MiniMax used minimax/MiniMax-M3, task st_01a17e7c; adaptive-thinking payload was not exposed on the status snapshot, and live models.json has forceAdaptiveThinking true. Kimi used kimi-coding/k3.1-pro:high, task st_01a17e7d. Those routes come from Native task status, not from model self-description. No member was replaced.

## Question

Is docs/research/pairtoken-unified-prd-20261027-01a17e03/handoff/PRD.md, identity pairtoken-unified-prd-r1, an accurate definition of the PairToken-local behavior in the exact-match source at https://sourcify.dev/server/v2/contract/4663/0x56C8c249d4c021e93635b120aC68A9a36eb01753?fields=sources?

## Proposed text

Yes, with only non-material clarifications.

No material defect. All four independent originals used that same verdict line. The coordinator adopts it. Agreement is not runtime proof and is not a fifth vote.

The published PRD accurately defines the reviewed PairToken-local external behavior under the assigned standard: public ABI, constants, events, errors, exact integer results and stated casts, stated check and call order, and the dependency boundaries the source actually has. No member demonstrated a requirement that forces an observable result, failure, event, or order the source does not have, or a PairToken-local source behavior that changes one of those observations and is absent from both the normative text and an explicit dependency or absence.

The live Sourcify response reconfirmed on October 27, 2026 is HTTP 200, 147694 bytes, raw SHA-256 ebbbf460a7873b7a5a1fb2802035778976ac4c5f64f3c6074776fd71aa53cd98, matchId 55980642, chain 4663, address 0x56C8c249d4c021e93635b120aC68A9a36eb01753, creation and runtime exact_match, verifiedAt 2026-10-12T10:33:37Z, 28 files. Astra, Grok, and MiniMax each refetched that URL and reported the same identity. Kimi did not refetch; for Kimi those identity fields are coordinator-supplied through evidence/SOURCE.md. The local decode matches each response content string except one extra trailing newline per file. The pinned PRD raw SHA-256 is 1824df69b7f64cc15252a7ae877d3b3f762773db5bfc4f091591eb1af8a7f6d2. Astra, Grok, MiniMax, and Kimi each computed that hash.

### Findings

Each item below is a PRD wording clarification. None is applied. Fix direction changes the PRD only. Member originals keep their own locators; corrections below are coordinator re-reads, not edits to those originals.

#### L1 - low: state retention-before-liquidity-read in the shared exit paragraph

- Location: PRD line 277, read with PRD line 473. Source: PairToken.sol lines 396-399. Astra cited PRD lines 277-285 and 473, and PairToken.sol lines 391-405. Those ranges were re-read. The operative lines are 277, 473, and 396-399.
- Invariant or requirement: After the caller burn, checked retention arithmetic occurs before the position-liquidity read.
- Impact: Line 277 says to read position liquidity after the burn and does not mention the intervening payout calculation. A reader of that sentence alone could place the external read before retention arithmetic. Line 473 already orders retention arithmetic before the liquidity read, and PT-CONFORM-01 requires the requirements to be read together. The complete PRD does not permit the reordered implementation.
- Fix direction: In PT-EXIT-01, say burn the caller's shares, calculate the checked payout, then read position liquidity. Keep the formulas and PT-ERROR-02.
- Evidence class: static analysis. Adopted from Astra. No other member contradicted it.
- Dissent: none among received responses.

#### L2 - low: amount1 uses an absolute difference, not a sort

- Location: PRD line 138. Source: SqrtPriceMath.sol line 194 sorts inside getAmount0Delta; line 239 uses absDiff for getAmount1Delta. MiniMax cited line 239 and the absDiff definition at line 214. Both were re-read.
- Invariant or requirement: Amount0 sorts its endpoints and rejects a zero lower endpoint. Amount1 uses the absolute endpoint difference and does not apply that zero check.
- Impact: The sentence "Both amount functions sort their two supplied endpoints" is broader than the amount1 helper. The next sentence already states the absolute-difference rule. Absolute difference and sorted subtraction produce the same integer. No observable result changes.
- Fix direction: Say the amount0 function sorts its endpoints and the amount1 function uses the absolute endpoint difference. Do not change the formulas.
- Evidence class: static analysis. Adopted from MiniMax. No other member contradicted it.
- Dissent: none among received responses.

#### L3 - low: name which division failure equal bounds produce

- Location: PRD line 145, not line 142, and PT-AC-55 at PRD line 569, not line 549. Line 549 is PT-AC-35. MiniMax's original cites lines 142 and 549; those locators are not adopted. The equal-bounds sentence and PT-AC-55 were re-read at lines 145 and 569. Source: LiquidityAmounts.sol lines 25 and 34 call FullMath.mulDiv with a zero denominator when bounds are equal; FullMath.sol line 30 is require(denominator > prod1), an unadorned revert. PairToken.sol lines 148-149 call TickMath.minUsableTick and maxUsableTick. Those bodies, TickMath.sol lines 39-49, divide in an unchecked block. Solidity still rejects division by zero inside unchecked; that language rule was not executed in this review.
- Invariant or requirement: Equal liquidity bounds fail through the MD helper's unadorned revert. Zero tick spacing fails through the initialization division. PT-MATH-01 and PT-ERROR-03 already say helper plain reverts and division-by-zero are not normalized into one application error.
- Impact: "Division failure" does not by itself say which revert bytes occur. An implementer who turns both into one panic would change revert data on a rare path. The complete PRD already forbids that normalization when PT-MATH-01 and PT-ERROR-03 are applied. This is not a material missing rule.
- Fix direction: At lines 145 and 569, say equal liquidity bounds fail through the MD unadorned revert, while zero tick spacing fails through the initialization division. Do not add a new guard.
- Evidence class: static analysis, plus an unverified language inference for the unchecked division-by-zero panic. Adopted from MiniMax after locator correction. No other member contradicted the substance.
- Dissent: none among received responses. The original line numbers remain wrong in MiniMax's response and are not silently rewritten there.

#### L4 - low: Add callback says positive while including zero

- Location: PRD line 364. Source: PairToken.sol lines 552-554. Kimi cited line 364 and lines 552-555. Those lines were re-read.
- Invariant or requirement: An Add callback decodes a uint128 and forwards that nonnegative value, including an explicit zero, as a liquidity modification.
- Impact: "Positive liquidity modification ... including zero" is inconsistent wording. The same row expressly includes zero, and the source forwards the decoded value. No required behavior changes.
- Fix direction: Replace "Positive liquidity modification" with "Nonnegative liquidity modification," and keep the express zero permission.
- Evidence class: static analysis. Adopted from Kimi. No other member contradicted it.
- Dissent: none among received responses.

#### L5 - low: say the notify catches are catch-all

- Location: PairToken.sol lines 451-463 use bare catch. PRD lines 319-323 say a caught notification revert reports zero, and the paragraph after the table says factory getter failures, checked arithmetic, malformed approval return data, and local or dependency call-setup failures can abort. Grok also cited PT-AC-38, which is PRD line 552 and restates the caught-notification outcome. Those lines were re-read. Grok's cited range 315-319 starts at the heading; the operative sentences are 319-323 and the following paragraph.
- Invariant or requirement: A failed notify is caught and reports zero. The listed non-notification failures are not caught.
- Impact: A bare catch also catches custom errors, Panic, and empty reverts from notify. The PRD says notification reverts are caught and lists other failures that are not. It does not spell out catch-all versus catch Error(string). A reader who implements only catch Error(string) would let a custom-error fee manager abort. That narrower catch is not what the PRD requires. The word revert, together with the explicit list of uncaught failures, already points at notification-call failure rather than only Error(string).
- Fix direction: In PT-COMP-03, say both notify catches are catch-all external-call failures, including custom errors, Panic, and empty reverts. Do not say fee-manager failure can never block users.
- Evidence class: static analysis. Adopted from Grok. No other member contradicted it.
- Dissent: none among received responses.

#### L6 - low: native calls forward remaining gas

- Location: Currency.sol line 48 is call(gas(), to, amount, 0, 0, 0, 0). Line 47 is a comment; Grok cited line 47, and that locator is corrected to the call on line 48. PairToken.sol line 674 is msg.sender.call{value: refund}(""). PRD lines 410 and 416 say empty-calldata value calls with the stated distinct failure modes. Those lines were re-read.
- Invariant or requirement: Native payout and paired refund are empty-calldata value calls, with WrappedError and TransferFailed respectively.
- Impact: Both source calls forward remaining gas. The PRD's "value call" already excludes a 2300-gas transfer or send, because those are different calls and the stated failure modes differ. It does not spell out remaining-gas forwarding. A stipend would change success for some recipients. A Solidity 0.8.26 value call does not impose that stipend. This was not confirmed by compilation.
- Fix direction: State that both native payout and paired refund use CALL with remaining gas, not a fixed 2300-gas stipend.
- Evidence class: static analysis, plus an inference about Solidity call gas. Adopted from Grok after the line-47 correction. No other member contradicted it.
- Dissent: none among received responses.

#### L7 - low: mark consumed balance and extsload reads as view

- Location: IExtsload.sol line 9 declares extsload(bytes32) external view. IERC20Minimal.sol line 10 declares balanceOf external view. PRD line 608 names extsload(bytes32)->bytes32 without repeating view. PT-BAL-01 at PRD line 398 says ERC-20 idle is the token's reported balanceOf(instance) and does not say staticcall. Factory reads are already marked view at PT-DEPENDS-01. Those lines were re-read.
- Invariant or requirement: Position, price, active-liquidity, and ERC-20 idle reads use the consumed external ABI. A view implementation returns the same value to a static call.
- Impact: The source calls those view functions, so the compiler emits static calls. The PRD names the signatures and the reported balance without repeating view for extsload or balanceOf. A read that writes, or reverts only under staticcall, would fail in the source and could differ under a non-static call. That behavior is outside the declared view ABI. The PRD does not require the implementer to drop view.
- Fix direction: Mark the consumed single-slot extsload and token balanceOf reads as view static calls.
- Evidence class: static analysis. Adopted from Grok. No other member contradicted it.
- Dissent: none among received responses.

No material finding was received. The coordinator does not add one.

## Preserved disagreements

| Topic | Positions | Not resolved in this draft |
| --- | --- | --- |
| Verdict | All four received responses say yes, with only non-material clarifications, and no material defect. | none. This is not called unanimity-as-proof. |
| Which low wording items to mention | Each member reported different low items. No received response rejected another member's item, because peers were not read. | Absence of an item from one original is not dissent. All seven low items are carried. |

## Evidence gaps

- Kimi did not refetch Sourcify. Identity fields in Kimi's response are coordinator-supplied, then used by Kimi as admitted evidence. Astra, Grok, and MiniMax refetched.
- No member ran the contract, a project test, a build, or a chain call. Grok's sqrt and tick checks are transcribed integer comparisons, not on-chain results. MiniMax's PriceMath.sqrt sampling is likewise member-reported static sampling, not coordinator-executed.
- Unused bundle files that PairToken does not call were not treated as obligations. Grok marked BitMath, LiquidityMath, BeforeSwapDelta, IHooks, IProtocolFees, IERC6909Claims, and IExttload as not examined for that reason. Astra reported reading the full 28-file bundle but not treating unused functions as executed. That difference is coverage labeling, not a conflicting behavior claim.
- Concrete manager, factory, fee-manager, hook, token, and deployed-state internals were not supplied. The yes does not claim whole-system equivalence, bytecode identity, legal clearance, or source nonexposure.
- MiniMax adaptive-thinking request payload was not inspected in this run.

## Coverage adopted from responses

| Target | Status | Adopted from | Conflict or gap |
| --- | --- | --- | --- |
| Pinned PRD, pairtoken-unified-prd-r1 | examined | all four; each computed the pinned hash | none |
| Sourcify exact-match identity | examined | coordinator refetch; Astra, Grok, and MiniMax refetches | Kimi did not refetch |
| PairToken.sol | examined | all four | none on compared behavior |
| Math helpers used by PairToken | examined | all four, with Grok additionally sampling transcribed sqrt and tick functions | sampling is not execution |
| Currency, position, state-read, and callback helpers used by the claims | examined | all four | Grok left unused library files not examined; Astra read them without treating unused functions as executed |
| Earlier requirements, errata, and the prior fidelity report | not examined | excluded by the brief | absence is intentional |

## Limits

- Static, extracted, supplied-runtime, and unverified claims stay distinguished. This draft is static analysis. It is not runtime proof.
- This draft does not claim permission confinement.
- Original response files were read and are preserved.
- No project code, configuration, or Git action is authorized by this draft.
- Coordinator locator corrections do not rewrite member originals.
- This draft does not authorize implementation or an edit to the PRD.
