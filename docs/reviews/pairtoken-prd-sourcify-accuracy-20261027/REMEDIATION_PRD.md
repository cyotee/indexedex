# Pair Token PRD accuracy review

## Question

- Run ID: pairtoken-prd-sourcify-accuracy-20261027
- Question: Is docs/research/pairtoken-unified-prd-20261027-01a17e03/handoff/PRD.md, identity pairtoken-unified-prd-r1, an accurate definition of the PairToken-local behavior in the exact-match source at https://sourcify.dev/server/v2/contract/4663/0x56C8c249d4c021e93635b120aC68A9a36eb01753?fields=sources?
- Profile: review
- Council kind: full
- Result label: full

Yes, with only non-material clarifications.

No material defect was demonstrated. The PRD accurately defines the compared PairToken-local results, failures, events, formulas, stated check and call order, and dependency boundaries. It does not fully specify native-call gas, and it does not state that the consumed balance and single-slot extsload reads are static. Those two omissions are clarifications. No existing PRD sentence was found that already requires them. They are not demonstrated wrong formulas, and the final does not treat them as already cured by other wording.

## Authorization and scope

- Authorization source: explicit council directive. The user asked whether the council considers the named PRD an accurate definition of the named Sourcify source.
- Authorizing task or role: invoking session
- Required targets: the pinned PRD, raw SHA-256 1824df69b7f64cc15252a7ae877d3b3f762773db5bfc4f091591eb1af8a7f6d2; the 28-file exact-match source
- Optional context: earlier requirements, errata, and the prior fidelity report were not supplied to this council and were not read
- Inherited permissions: accepted. They are not extra authority and not a sandbox.
- Implementation authority: none. This report does not authorize edits, reviewed-project tests, installs, deployment, or Git. The PRD was not edited.

## Participation

| Participant | Role | Requested model and reasoning | Actual model and reasoning | Task ID | Fresh or continued | Status | Identity source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Coordinator | invoking session, not a vote | current invoking model; reasoning not separately selected | session prompt label Grok 4.7; reasoning not exposed | not exposed | invoking session | published this final | session prompt, not a child-task snapshot |
| Astra | council-member | chatgpt-subscription/gpt-6-astra:high | same route, high | st_01a17e7a | fresh, then continued for advisory | initial and advisory completed | Native task status; member-reported session 01a17e7a-70bc-78fc-842a-9d14253e4444 |
| Grok | council-member | xai/grok-4.7:xhigh | same route, xhigh | st_01a17e7b | fresh, then continued for advisory | initial and advisory completed | Native task status |
| MiniMax | council-member | minimax/MiniMax-M3, adaptive thinking | minimax/MiniMax-M3; adaptive payload not exposed | st_01a17e7c | fresh, then continued for advisory | initial and advisory completed | Native task status; live models.json has forceAdaptiveThinking true |
| Kimi | council-member | kimi-coding/k3.1-pro:high, global | same route, high | st_01a17e7d | fresh, then continued for advisory | initial and advisory completed | Native task status |

- Coordinator mode: invoking-agent
- Actual mode equals requested mode: yes
- Missing initial responses: none
- Missing feedback: none

The coordinator is not an independent vote. No model was substituted. MiniMax adaptive-thinking was configured in models.json and was not confirmed from a captured request payload.

## Findings

### No material defect

- Location: the pinned PRD compared with PairToken.sol and the helpers named in Coverage
- Invariant or requirement: an implementer who has only the PRD must reproduce PairToken-local public ABI, constants, events, errors, integer results, stated casts, stated check and call order, and the source's dependency boundaries
- Impact: no compared requirement forces a result, failure, event, or order the source lacks, and no compared source behavior that changes those observations was left out of both the normative text and an explicit dependency or absence, except the two call-context clarifications below
- Fix direction: none for formulas, guards, or accounting order
- Evidence class: static analysis
- Dissent on this finding: none among received responses. Advisory reservations qualify L6 and L7; they do not withdraw the no-material-defect conclusion.

### L1 - low: retention before the liquidity read

- Location: PRD line 277, read with line 473. Source: PairToken.sol lines 396-399. Coordinator re-read.
- Invariant or requirement: after the caller burn, checked retention arithmetic occurs before the position-liquidity read
- Impact: line 277 says to read liquidity after the burn and does not mention the intervening payout calculation. Line 473 already orders retention arithmetic before that read. The complete PRD does not permit the reordered implementation.
- Fix direction: in PT-EXIT-01, say burn, calculate the checked payout, then read position liquidity. Not applied.
- Evidence class: static analysis
- Dissent on this finding: none. Kimi and Grok did not independently re-verify it in the advisory pass. That is not dissent.

### L2 - low: amount1 uses an absolute difference

- Location: PRD line 138. Source: SqrtPriceMath.sol line 194 sorts in getAmount0Delta; line 239 uses absDiff for amount1. Coordinator re-read.
- Invariant or requirement: amount0 sorts and rejects a zero lower endpoint. Amount1 uses the absolute difference and does not apply that zero check.
- Impact: "Both amount functions sort" is broader than amount1. The next sentence already states the absolute-difference rule. The integers match.
- Fix direction: say amount0 sorts and amount1 uses the absolute difference. Not applied.
- Evidence class: static analysis
- Dissent on this finding: none

### L3 - low: name the equal-bounds failure

- Location: PRD line 145 and PT-AC-55 at line 569. Do not cite lines 142 or 549 as the corrected locations. Line 549 is PT-AC-35. MiniMax's original still cites 142 and 549; that file was not rewritten. Source re-read: LiquidityAmounts.sol lines 25 and 34 are the coordinator's re-read of the mulDiv expressions. MiniMax's citation remains lines 22 and 32. FullMath.sol line 30 is an unadorned require. PairToken.sol lines 148-149 call TickMath.minUsableTick and maxUsableTick, whose bodies at lines 39-49 divide in an unchecked block.
- Invariant or requirement: equal liquidity bounds fail through the MD helper's unadorned revert. Zero tick spacing fails through the initialization division. PT-MATH-01 and PT-ERROR-03 already say those failure classes are not normalized into one application error.
- Impact: "division failure" does not name the revert bytes. An implementer who collapses both into one panic would change rare-path revert data. The complete PRD already forbids that normalization when those two requirements are applied.
- Fix direction: at lines 145 and 569, distinguish the MD unadorned revert from the initialization division. Not applied.
- Evidence class: static analysis. The statement that unchecked Solidity division by zero still panics was not executed. Grok did not adopt that sentence as an observation. It remains an unverified language inference.
- Dissent on this finding: none on the substance. MiniMax asked that the corrected locators be used downstream. That request is adopted here.

### L4 - low: Add says positive while including zero

- Location: PRD line 364. Source: PairToken.sol lines 552-554. Coordinator re-read.
- Invariant or requirement: Add decodes a uint128 and forwards that nonnegative value, including explicit zero
- Impact: "Positive liquidity modification ... including zero" is inconsistent wording. The same row includes zero. No required behavior changes.
- Fix direction: say nonnegative, and keep the express zero permission. Not applied.
- Evidence class: static analysis
- Dissent on this finding: none

### L5 - low: notify catches are catch-all

- Location: PairToken.sol lines 451-463 use bare catch. PRD lines 319-323 and the following paragraph. PT-AC-38 is line 552. Coordinator re-read.
- Invariant or requirement: a failed notify is caught and reports zero. Factory getter failures, checked arithmetic, malformed approval data, and call-setup failures are not caught.
- Impact: a bare catch also catches custom errors, Panic, and empty reverts from notify. The PRD says notification reverts are caught and lists other failures that are not. It does not spell out catch-all versus catch Error(string). The narrower catch is not what the PRD requires.
- Fix direction: say both notify catches are catch-all external-call failures. Do not say fee-manager failure can never block users. Not applied.
- Evidence class: static analysis
- Dissent on this finding: none

### L6 - low, classification qualified: native call gas is unspecified

- Location: Currency.sol line 48 is call(gas(), to, amount, 0, 0, 0, 0). Line 47 is a comment; Grok's original cited line 47, and the call is line 48. PairToken.sol line 674 is a Solidity value call. PRD lines 410 and 416 say empty-calldata value call and name the failure modes. Coordinator re-read. A later PRD search found no gas, stipend, or remaining-gas sentence.
- Invariant or requirement: native payout and paired refund are empty-calldata value calls, with WrappedError and TransferFailed respectively. The source forwards the CALL gas argument. The PRD does not state that gas policy.
- Impact: a fixed stipend can change success for some recipients. The words "value call" do not exclude an explicit gas limit. No existing PRD sentence was found that already requires remaining-gas forwarding. The draft's stronger justification is not adopted.
- Fix direction: state that the source payout uses CALL with gas() and the source refund uses a value call that forwards remaining gas, not a 2300-gas stipend. Describe that as source behavior subject to the CALL gas argument. Do not claim the current PRD already requires it. Not applied.
- Evidence class: static analysis of the source calls. The Solidity default for `.call` gas was not confirmed by compilation.
- Dissent on this finding: Astra reserved the draft's justification and asked for this qualification. The reservation is adopted. Grok's original classified the item as low and later supported the draft; that support is not approval of this revised wording.

### L7 - low, classification qualified: static read context is unspecified

- Location: IExtsload.sol line 9 and IERC20Minimal.sol line 10 declare view. PRD line 608 names extsload(bytes32)->bytes32 without view. PT-BAL-01 at line 398 does not say the balance read is static. Coordinator re-read. A later PRD search found view on PairToken getters and the factory interface, not on these consumed reads, and found no staticcall sentence.
- Invariant or requirement: the source calls view extsload and view balanceOf, so those reads are static. The PRD names the signatures and the reported balance without requiring that static context.
- Impact: a non-static call can differ if the dependency writes or reverts only under staticcall. That difference is caller behavior, not excused by the dependency being outside a view ABI. No existing PRD sentence was found that already requires the static context. No view-compliant dependency was shown to return a different value.
- Fix direction: mark the consumed single-slot extsload and token balanceOf reads as view static calls. Do not claim the current PRD already requires that. Not applied.
- Evidence class: static analysis
- Dissent on this finding: Astra reserved the draft's justification and asked for this qualification. The reservation is adopted. It is not a withdrawal of the no-material-defect conclusion.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| Pinned PRD | required | examined | All four members read it and computed the pinned hash. The coordinator re-read the cited lines and searched for gas, stipend, staticcall, and view. |
| Sourcify exact-match identity | required | examined | Coordinator refetch matched the earlier response hash. Astra, Grok, and MiniMax refetched. Kimi used the coordinator-supplied identity record. |
| PairToken.sol | required | examined | All four compared the public surface and money paths. |
| Math, currency, position, state-read, and callback helpers used by the claims | required | examined | Compared by all four. Grok left unused bundle files not examined. Astra read the bundle without treating unused functions as executed. |
| Earlier requirements and the prior fidelity report | optional, excluded | not examined | Excluded so this council would not adopt the earlier verdict as evidence. |
| Runtime equivalence | not required for the assigned yes | not examined | No build, test, deploy, or chain call. |

## Disagreement and missing responses

- Disagreement: none on the verdict line. All four originals said yes, with only non-material clarifications, and no material defect. Advisory reservations concern the justification for L6 and L7, not a contrary verdict.
- Dissent carried into this report: Astra's two reservations are adopted as qualifications. Grok did not independently verify L1-L4 in the advisory pass and did not adopt the unchecked-division inference. MiniMax did not verify the other members' items in the advisory pass. Those limits stay visible. They are not votes to remove the items.
- Missing responses treated as approval: no
- Feedback used as a missing initial response: no

## Advisory review

- Draft ID: draft-pairtoken-prd-sourcify-accuracy-20261027-r1
- Draft path: docs/reviews/pairtoken-prd-sourcify-accuracy-20261027/coordinator/draft.md
- Resolution path: coordinator/resolution.md
- Feedback dispositions: Astra support-with-reservations; Grok support; MiniMax support-with-reservations; Kimi support
- Concern outcomes: A1 and A2 adopted as qualifications. M1 and M2 adopted as citation rules. M3 required no change. Grok and Kimi requested none.
- Post-review wording changes: the final qualifies L6 and L7 and corrects the citation rules. The pinned draft bytes were not changed.
- Those changes are member-approved: no

## Recommendations

- Use the PRD as the behavioral definition for the compared PairToken-local results. Do not treat this report as implementation authority.
- If a later document revision is separately authorized, apply L1 through L7 as wording clarifications only. For L6 and L7, add the missing call-gas and static-call sentences. Do not claim they were already required.
- Do not cite MiniMax's original lines 142 and 549 as the corrected L3 locations. Use lines 145 and 569.
- Do not add a fee clamp, a gas stipend, a new staticcall guard beyond what the source does, or any accounting change under this review.

## Limitations

- This is static analysis. It is not runtime proof, bytecode identity, legal clearance, or source-nonexposure certification.
- Whole-system equivalence still depends on a compatible manager, factory, fee manager, hook, and currency set. Those implementations were not supplied.
- Kimi did not refetch Sourcify. Three other members and the coordinator did.
- Grok's sqrt and tick sampling, and MiniMax's sqrt sampling, are member-reported static checks, not coordinator-executed tests.
- The unchecked division-by-zero panic was not executed.
- Solidity `.call` gas forwarding was not confirmed by compilation.
- MiniMax adaptive-thinking payload was not captured.
- Advisory reviewers did not reopen the source. Their support is support of the draft, not a second source comparison.
- The pinned draft was not rewritten after review. This final is the coordinator revision.

## Publication

- Publication state: published
- Final path or chat-only statement: docs/reviews/pairtoken-prd-sourcify-accuracy-20261027/REMEDIATION_PRD.md
- Cooperative update: none. The PRD was not edited.
- Unrelated edits preserved: not applicable
- Model work repeated for publication: no
- Git actions: none
- Artifacts retained until explicit deletion: yes
