# Identity

- Run ID: apex-012-design-recommendation-20261024
- Member label: astra
- Profile: research
- Phase: advisory feedback
- Fresh or continued: continued
- Owned path: docs/reviews/apex-012-design-recommendation-20261024/members/astra/feedback.md

## Draft reviewed

- Draft ID: draft-apex-012-design-recommendation-20261024-r1
- Path: docs/reviews/apex-012-design-recommendation-20261024/coordinator/draft.md

## Disposition

Requested changes. The draft correctly preserves full conversion before my design deals, rejects immediate dealing against mixed inventory, and distinguishes the proposed entry conversion from today's deposit. However, its shared Family A description misstates my rate and drops the condition under which I said the design meets the brief. This feedback does not choose a family for the owner.

## Concerns

1. **My rate does not fall when target is allocated to the LP.** The Family A cost paragraph says, "The published rate is payable target" and "It falls when target is spent to seek fees." Neither describes my proposal. During investment, my rate remains the last completed cash-settlement price; it is not presently payable target and is not recomputed from remaining idle target. Investment gains, losses, and costs enter the next completed settlement. Please separate this historical-rate contract from any idle-target-counter design.

2. **Satisfaction of the one-rule constraint is conditional, not unqualified.** My deposit and redemption requests execute at the next realized settlement ratio, not necessarily the rate displayed when requested. At a dealing event, deposit, redemption, and publication use that one ratio. Between events, the published number is historical and dealing is closed. My response explicitly refuses a continuously executable current target price during investment. The draft's "Both meet the constraint" needs this qualification, including the requirement that downstream rate consumers accept stale settlement prices and obtain settlement status separately.

3. **The trading position still belongs economically to shareholders.** "The trading position is not what a share is priced or paid in" is acceptable only as a statement about settlement denomination. It must not suggest an excluded reserve or forfeited inventory claim: the old cohort receives all net portfolio realization, including other-token principal and fees, and bears its losses. Pending deposits stay segregated until that cohort is fully valued in actual target. Redemption shares remain in its supply until settlement.

4. **The other-token exclusion needs historical-rate wording.** The sentence saying other token is absent from the published rate until conversion can imply that allocation immediately writes off its value. My design instead omits any new target valuation of the invested inventory until realization. The previous settlement observation remains unchanged; it is neither a current valuation of the other token nor a zero mark for it.

5. **Keep the execution safeguard and its limit together.** My proposal requires inventory in custody before auction bidding closes and actual target receipt before later price publication; merely publishing a live same-pool sale result one transaction later is not the complete proposed mechanism. Time separation prevents transient pool state from directly setting dealing inputs. It is not a proof against multi-block manipulation, collusion, or bad execution.

6. **The stated closure distinction is internally unclear.** The draft describes both Astra and Grok as requiring closed inventory before dealing, then says they differ in whether the position must be fully closed. Please identify the actual distinction or remove that claim. I cannot resolve Grok's intended design from this draft alone.

## Limits

Reviewed only the named coordinator draft against my own submitted design and constraints. No peer files, tests, Forge, external research, or sub-agents. I make no determination about another member's intended design beyond the coordinator's descriptions. No family selection, implementation authorization, or approval of a revised draft is implied.
