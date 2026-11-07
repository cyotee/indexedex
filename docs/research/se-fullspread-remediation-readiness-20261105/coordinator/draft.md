# Coordinator draft

## Draft identity

- Draft ID: draft-se-fullspread-remediation-readiness-20261105-r1
- Path: docs/research/se-fullspread-remediation-readiness-20261105/coordinator/draft.md
- Run ID: se-fullspread-remediation-readiness-20261105
- Status: pending advisory review. This file is not the final.
- Fingerprint: not computed
- Sources: the four settled initial responses, the remediation PRD, and the locators re-read below

## Participation

- Council kind: full
- Requested members: astra, grok, minimax, kimi
- Substantive initial responses: astra not ready; grok not ready; minimax ready; kimi not ready
- Missing initial responses: none
- Result label: full
- Coordinator mode: invoking-agent
- Coordinator is an independent vote: no

## Question

Is `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`, including the owner lock dated 2026-11-05, ready to be the source from which an implementation plan is written, with no further owner product decision required?

## Proposed text

Proposed verdict: not ready.

This is not a code-readiness verdict. It does not authorize implementation. It does not write the plan. Three members reached not ready. MiniMax reached ready. That disagreement is preserved below. Silence from a member on an item is not agreement that the item is closed.

The lock does close these product splits. All four responses observed them, and the coordinator re-read the cited lines:

- The incomplete one-token exit raises `AmountOutNotMet` and does not burn. Remediation PRD lines 80-82 and lock item 3 at line 54, which says it does not change F1's error.
- The exit minimum and returned `amountOut` are the recipient receipt: swap proceeds plus the withdrawn amount sent to the recipient. Line 54.
- The six named infrastructure bindings are components. A missing or code-empty value reverts `InvalidComponent` with no partial diamond. Line 52.
- The weighted two-leg row keeps its `setUp` override. Line 53.
- `exchangeRate` tests are dropped. FS-A01 through FS-A04 remain. Line 55.
- The one-sided method is the locked quadratic or the segment-boundary cap, not the 96-step search. Lines 24-48 and F4 at lines 107-109.

Those closed sentences are not the whole source. A later author still cannot copy one plan from this PRD without making a product choice the owner has not made. The choices are these three.

1. Owner lock, Domain through Token1 in, lines 30-42. The same symbol `n` is the fee-excluded amount that enters the curve, the positive quadratic root, and a quantity that must not exceed the amount the pool applies after the fee is rounded up. The gross input is `n / g`, rounded down. The resulting price is computed from that same `n`. Astra inferred that, after downward gross rounding and upward fee rounding, the executable net input is strictly smaller than the exact root except in exact-alignment cases, so one author can price the swap from the root and another from the smaller executable net. The coordinator re-read lines 30-42 and confirms the one-symbol text. The incompatibility is Astra's inference, not a traced execution. Grok, MiniMax, and Kimi did not raise it. MiniMax quoted those lines as a complete rule. Their silence is not a vote that the two uses of `n` are the same quantity.

2. Owner lock item 5, line 56, repeated at F11 line 172 and recommendations line 225. The standalone routes are "the six money and maintenance routes, including both shapes of `exchangeIn`." The six routes are not named. The two shapes are not named. The implementation plan line 374 assigns "standalone gas for the six money and maintenance routes" to `Money.t.sol` and does not list them. Plan line 389 repeats the unnamed phrase. Plan line 94 installs seven money-facet selectors, including `setOperator` and `setOperatorFor`. The family PRD money facet, read at the selector table, lists five money selectors and does not include those two appointment selectors. MiniMax inferred one set of six: `exchangeIn` mint, `exchangeIn` exit, `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound`. That set is not written in the lock. Astra treated the coverage policy as specified and did not treat the unnamed six as an open choice. Grok and Kimi did. A later author cannot copy one standalone gas list from the text that was re-read.

3. F7, lines 131-138, and recommendations line 223. `limitCapacity()` and `openCapacity()` are present as empty overrides. The finding says those empty bodies do not satisfy "not part of this fixture," says not to delete them until a parent requirement that was not re-read is checked, and does not order deletion. The recommendation says not to treat the empty overrides as if the plan omitted them. It does not say keep them, delete them, or accept them when a parent forces the override. The owner lock does not mention these functions. The implementation plan line 217 still says they are not part of this fixture and not to add a sleeve capacity gate. Grok and Kimi treat the missing end state as an open choice. Astra treats the parent check as unfinished engineering evidence, not an owner question. MiniMax treats plan line 217 as the end state. The coordinator re-read does not find a sentence in the remediation PRD that picks one end state.

Astra also reported a fourth gap: the lock's domain is `sL < s < sU` with nonzero active liquidity, and it does not state the execution or preview outcome when the starting state is outside that domain, including zero active liquidity. The coordinator re-read family PRD FS-OWN-22: any initialized hookless pool is accepted, and there is no inherited-domain check. FS-PKG-02 says the first depositor creates the position and says not to reject a pool outside an inherited domain. The lock does not say what the scoped one-sided routes do in that starting state. Grok, MiniMax, and Kimi did not adopt this as a blocker. It is recorded as Astra's position, not as a fourth adopted choice, because the other three examined the base and did not treat it as a product question. It remains a disagreement, not a closed rule.

Kimi also reported that the unresolved list at lines 176-188 leaves the later plan's scope open. The list says naming those items is not a finding that they are defects. Astra, Grok, and MiniMax did not treat that list as an owner choice. The coordinator does not adopt it as a fourth required owner answer. A plan author can copy "not a finding" without choosing a new product behavior. Whether the later plan must investigate those items is Kimi's inference, preserved below, not a proposed owner question.

## Preserved disagreements

| Topic | Positions | Not resolved in this draft |
| --- | --- | --- |
| Overall verdict | Astra, Grok, and Kimi: not ready. MiniMax: ready. | The proposed verdict follows the not-ready readings that survived a re-read. MiniMax's ready verdict is not withdrawn. |
| Symbol `n` | Astra: the root and the executable net input are incompatible under the stated rounding. MiniMax: lines 30-42 are a complete rule. Grok and Kimi: not raised. | Not closed. Silence is not agreement. |
| Unnamed six gas routes | Grok and Kimi: too unclear to copy. MiniMax: one inferred set of six. Astra: coverage policy is specified. | Not closed. The inferred set is not in the lock. |
| Capacity overrides | Grok and Kimi: no end state. Astra: parent check is engineering, not an owner question. MiniMax: plan line 217 is the end state. | Not closed. The remediation PRD does not pick one. |
| Starting state outside the formula domain | Astra: missing route outcome, including zero active liquidity. The other three: not adopted. | Not adopted as a required owner question. Not closed as a stated outcome. |
| Unresolved list as plan scope | Kimi: the later plan's scope is not disposed. Astra, Grok, and MiniMax: those items are not owner choices. | Not adopted as an owner question. |

## Evidence gaps

- No member ran a test, compile, or gas measurement. This draft does not add one.
- Grok and Kimi partially examined the optional plan and family PRD. Astra and MiniMax reported reading both in full. The coordinator re-read only the locators named in this draft.
- Peer responses were not available to members on the initial pass. This draft is the first comparison.
- `WeirVaults.sol` and the fixture parent interface were not admitted as required targets. No requirement is taken from either unread file.

## Coverage adopted from responses

| Target | Status | Adopted from | Conflict or gap |
| --- | --- | --- | --- |
| Remediation PRD | examined | all four, coordinator re-read of the lock, F7, F11, the unresolved list, and the recommendations | Member line numbers for the lock items differ by about one line from the re-read. This draft uses the re-read lines. |
| Implementation plan | partially examined by the coordinator | Grok, Kimi, MiniMax, Astra | Coordinator re-read lines 94, 217, 374, and 389 only. |
| Family PRD | partially examined by the coordinator | Astra's FS-OWN-22 and FS-PKG-02 locators were re-read. The money-facet selector table was re-read. | Not a full re-read. |

## Limits

- Static reading only. No runtime proof.
- This draft does not claim permission confinement.
- Original response files were read and are preserved.
- No project code, configuration, or Git action is authorized by this draft.
- A member locator that this draft corrects is the lock-item line number. The member originals are not rewritten.
