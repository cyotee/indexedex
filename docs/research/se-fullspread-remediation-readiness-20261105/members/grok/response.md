# Member response

## Identity

- Run ID: se-fullspread-remediation-readiness-20261105
- Member label: grok
- Profile: research
- Phase: initial independent response
- Owned path: `docs/research/se-fullspread-remediation-readiness-20261105/members/grok/response.md`
- Requested role: council-member
- Requested model and reasoning: `xai/grok-4.7:xhigh`
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh. The assignment named this phase as the initial independent response and did not give a prior task ID.
- Peers read before submission: no

## Question and targets

- Question: Is `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`, including the owner lock dated 2026-11-05, ready to be the source from which an implementation plan is written, with no further owner product decision required?
- Required targets: `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`, read whole
- Optional context: the implementation plan and the family PRD named in the brief, read only to test whether an owner choice remains
- Admitted read scope: the brief, the required remediation PRD, and those two optional files. No other file was read.
- Public query: not used

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| Lock exists and does not authorize implementation | Remediation PRD lines 16-18 and 50; line 218 | source observation | The owner lock is dated 2026-11-05. Line 18 says the one-sided lock does not authorize implementation. Line 50 says none of the six locks authorizes implementation. Line 218 says the lock does not edit the implementation plan or the family PRD and does not authorize implementation. |
| One-sided method stated in this PRD | Remediation PRD lines 18-22, 24-38, and 46-49; F4 lines 108-111; recommendations line 227 | source observation | The lock supersedes F4's requirement reading. The 96-step search is not the method. Scope is a one-sided share mint and a one-token `donate` or `compound`, not a bundle deposit and not a one-token exit. The rule is one exact-input swap, no iteration, gross input rounded down, swap nothing if that input is zero, not an exact output. The text gives a token0 quadratic, a token1 quadratic, a segment-boundary cap, and permission to scale with `SwapMath` Q96 units without changing the root. F4 says the required method is that quadratic or the segment-boundary cap. Line 227 says size by this lock and do not replace it with the 96-step search. |
| Same-date plan sentence does not contain those equations | Implementation plan lines 19, 192, and 494 | source observation | Those lines record a 2026-11-05 owner instruction to adapt `WeirVaults.sol` `_balance`, not to iterate, and to size one swap so the following add consumes the other token and any needed refund stays in the provided token. A search of that plan found no `feePips` and no quadratic. Line 494 is the plan's section 16 sizing answer and names the Weir swap, not the equations. |
| Equations amend the base rather than reopen the method | Remediation PRD lines 18 and 108-111, against the plan lines above | inference | The remediation PRD is the amending source. It names the quadratic or the segment cap as the required method and says that lock supersedes F4's reading. A later author copies that method in place of the plan's Weir pointer. That cross-document difference does not by itself require another owner choice. `WeirVaults.sol` was not read, so this row does not say the equations match or contradict `_balance`. |
| Segment cap against the family price-limit sentence | Family PRD line 246 and line 417; remediation PRD lines 46-47 | source observation, then inference | The family PRD says the FS-OWN-33 price limit is `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`, that this is not `maxZapTickMove`, and that no tighter cap is added. Line 417 says there is no new price check, tick bound, or fee cap. The remediation lock says not to walk ticks and to cap `n` at the current segment boundary. Inference: that cap is the amending sizing rule. It does not, in this PRD, retarget the swap's price-limit parameter. It is not recorded here as a further owner choice. |
| Exit error and receipt basis | Remediation PRD lines 54, 78-84, 86-94, and 220 | source observation | Lock item 3 says the minimum and the returned `amountOut` are the recipient receipt, swap proceeds plus the withdrawn amount sent to the recipient, not the swap proceeds alone and not the pre-execution quote. It closes the F2 basis split and does not change F1's error. F1's fix direction is `AmountOutNotMet` and no burn. Line 220 repeats that error change and says not to describe a quote-versus-pool shortfall as already observed. |
| Infrastructure, weighted setup, and rate test | Remediation PRD lines 51-53; plan lines 71 and 323; family PRD lines 554-557 and 569 | source observation | Lock items 1, 2, and 4 name the six component addresses, the code-empty `InvalidComponent` reject with no partial diamond, the weighted two-leg `setUp` override and `_initializeWeighted(2)`, and the withdrawal of the older prohibition. Item 4 drops FS-A16's `exchangeRate` half, keeps `getRate` uninstalled, and keeps FS-A01 through FS-A04. Plan line 71 states the same six-address code check. Plan line 323 states the same two-leg override. Family PRD lines 554-557 state the FS-A01 through FS-A04 rows. Line 569 states both halves of FS-A16; the lock drops only the `exchangeRate` half. |
| Standalone gas set is not named | Remediation PRD line 55; F11 lines 172-179; recommendations line 225; plan lines 94, 106, 374, and 389; family PRD search | source observation | Lock item 5 says every supported route has a gas test, a sampled route is not coverage, and the standalone routes are "the six money and maintenance routes, including both shapes of `exchangeIn`." It also points at each section 12 row named by the plan for a composed measurement, and it states the three ceilings. F11 and line 225 repeat "every supported route named" in that lock. The plan's line 389 uses the same unnamed phrase and says those six are "in the table above." The table cell at plan line 374 names assertion IDs and `Money.t.sol`, not six routes. Plan line 94 installs seven money-facet selectors. Plan line 106 separates appointment from money and maintenance. A search of the family PRD found no "both shapes", no "six money", and no "maintenance route". |
| Why that phrase does not identify one set | Plan lines 94, 112-123, and 170-186, against remediation PRD line 55 | inference | Counting money and maintenance selectors, then replacing one `exchangeIn` with two shapes, can produce the number six only after the two shapes are known. The plan describes more than one economic use of `exchangeIn`, including share mint, one-token exit, and pass-through. The lock says "both" and does not say which two. Two careful authors would not copy the same standalone list. This response does not pick a list. |
| Capacity overrides | Remediation PRD lines 140-149 and 223; plan line 217 | source observation | F7 says `limitCapacity()` and `openCapacity()` are present as empty overrides, the plan says they are not part of this fixture, and the parent constraint was not re-read. The fix direction says not to treat the empty bodies as satisfying that sentence, not to delete them until the parent requirement is checked, and the finding does not order deletion. Line 223 says not to treat the empty overrides as if the plan omitted them. The owner lock does not mention these functions. Plan line 217 still says they are not part of this fixture and not to add a sleeve capacity gate. |
| Items not treated as new owner choices | Remediation PRD lines 183-201 and 226; plan line 160; family PRD lines 417-418 | source observation | The unresolved list says naming those items is not a finding that they are defects. Line 226 says not to certify section 12 complete. Plan line 160 says share burns use the caller's own balance or allowance and parked shares are not that credit. Family PRD lines 417-418 state the first-deposit floor: added liquidity less than or equal to `1_000` is rejected with `MinLiquidityNotMet()`. |

## Assumptions

none

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| `docs/research/se-fullspread-remediation-readiness-20261105/brief.md` | required by the assignment | examined | Read whole. It sets the question, the verdict words, and the read scope. |
| `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md` | required | examined | Read whole, including the 2026-11-05 owner lock, F1 through F11, the unresolved list, the recommendations, and the publication note. |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md` | optional | partially examined | Read to test owner choices: sections 1-2, 4-11, the section 12 capacity sentence, the weighted `setUp` paragraph, section 13 through the gas instruction, section 14's component names, and section 16. Not every section 12 row body was read. |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` | optional | partially examined | Read to test owner choices: FS-OWN-33, the FS-MONEY-01 price-limit and first-deposit sentences, and FS-A01 through FS-A16. Searched for the gas-route phrase. Not read whole. |
| Peer responses | not admitted on this pass | not examined | The assignment forbids reading them before this file. |
| `WeirVaults.sol` and the fixture parent interface | not admitted | not examined | Not required. No requirement was taken from either file. |

## Conclusions

Verdict: not ready

Observation. The remediation PRD does close several product splits by name. The one-token exit shortfall stays `AmountOutNotMet` and does not burn, at lines 54 and 83. The minimum and returned `amountOut` are the recipient receipt, at line 54. The six named infrastructure addresses are components and a missing or code-empty value reverts `InvalidComponent` with no partial diamond, at line 51. The weighted two-leg `setUp` override stays, at line 52. FS-A16's `exchangeRate` half is not a remediation requirement, and FS-A01 through FS-A04 remain, at line 53. The one-sided amount in this PRD is the locked quadratic or the segment-boundary cap, not the 96-step search, at lines 18-22, 46-47, and 108-111. The unresolved list, at lines 183-184, says those named items are not findings. Line 226 says not to certify section 12 complete. None of those sentences asks the owner for another choice.

Inference. Those closed sentences are not the whole source. Two choices a later author would have to make are still open in this PRD. This is not a code-readiness verdict. It does not authorize implementation. Peers were not read, so this is not council consensus.

1. Owner lock item 5, at line 55, repeated by F11 at line 179 and by the recommendations at line 225. The standalone gas set is too unclear to copy. The text requires a gas test for every supported route, then says the standalone routes are the six money and maintenance routes, including both shapes of `exchangeIn`, and does not name the six or the two shapes. The plan's line 389 uses that same phrase and points at a table that does not list the routes. The family PRD does not define the phrase. A later author cannot write one standalone gas list from these files without choosing the set. The composed-row sentence points at rows the plan names; that pointer is not this choice. This response does not name a set.

2. F7, at lines 140-149, and the recommendations at line 223. The owner lock does not mention `limitCapacity()` or `openCapacity()`. The finding says the empty bodies do not satisfy "not part of this fixture," says not to delete them until a parent requirement that this PRD did not re-read is checked, and does not order deletion. The recommendations do not state an end state. A later author cannot copy one required end state for those two functions from this PRD. The plan's product sentence at line 217 is not withdrawn here, and it also does not state that end state.

The plan's Weir sentence, at lines 19, 192, and 494, is a different sizing sentence from the equations. Inference, not a third open choice: F4 says the required method is the locked quadratic or the segment cap, so the amending source replaces that Weir pointer. That inference is not a claim that the equations are `_balance`. The family price-limit sentence, at lines 246 and 417, is likewise not recorded as a further owner choice: the lock amends the sizing amount and does not retarget the price-limit parameter.

## Limits

- Runtime or extraction proof: none. No test, compile, gas measurement, or execution was run. Public query: not used.
- Not examined: peer responses, `WeirVaults.sol`, the fixture parent interface, the unread remainder of the implementation plan, and the unread remainder of the family PRD. The lock's "positive root" is singular at lines 26 and 32. The gross-input rounding constraint is at line 24. Neither gap is recorded here as an additional owner choice.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path. It does not replace the remediation PRD. It does not write an implementation plan.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
