# Astra independent response

## Identity

- Run ID: se-fullspread-remediation-readiness-20261105-r2
- Member: astra
- Profile: research
- Phase: initial independent response
- Requested role: council-member
- Requested model and reasoning: `chatgpt-subscription/gpt-6-astra:high`
- Actual runtime role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued runtime identity: not exposed
- Owned path: `docs/research/se-fullspread-remediation-readiness-20261105-r2/members/astra/response.md`
- Peer responses read: no

## Question and targets

Is the current remediation PRD ready to serve as the source for one implementation plan file without another owner product decision?

The required target is `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`. I read the whole current file, including its owner lock. I used the admitted existing implementation plan, selected family-PRD sections, and prior report only to test whether a product choice remains. The prior report is not the verdict of this response.

## Evidence

| Item | Source | Class | Observation |
| --- | --- | --- | --- |
| One-sided sizing authority | `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:24-50`, `:109-111` | source observation | The owner lock replaces the old search reading. It specifies the affected routes, exact-input sizing, downward gross-input rounding, pool-applied-input constraint, two quadratic equations, and one segment-boundary cap. It prohibits iterative split search. |
| Starting price outside the position | `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:30-32` | source observation | The new paragraph includes both exact boundaries. It forbids the quadratic there. For the wanted token it directs an add without a swap and a refund of what the add does not take. For the other token it forbids a swap, refunds a share mint, and books a donate or compound. It adds no new error, distinguishes zero active liquidity, and says a collapsed candidate returns the input without retaining a selected swap. |
| Gas-route membership | `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:58` | source observation | Seven standalone routes are named: the three economic `exchangeIn` cases, bundle entry, bundle exit, donate, and compound. Appointment calls are excluded. Each section 12 row has its own composed measurement. Cold standalone, composed, and preview ceilings are respectively 11,900,000, 12,000,000, and 5,000,000. An oversized route is unresolved rather than passed. |
| Other owner choices | `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:54-57`, `:82-84` | source observation | The six infrastructure bindings require code; the weighted two-leg override stays; exit minimum and returned output use recipient receipt; the obsolete exchange-rate test is excluded; FS-A01 through FS-A04 remain; an incomplete one-token exit raises `AmountOutNotMet` without a burn. |
| Fixture and test work | `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:127-140`, `:156`, `:165`, `:172-174` | source observation | The booked getter is removed. Capacity overrides require checking the parent before deletion, without introducing a sleeve gate. Missing package assertions, the exit-error regression, and route gas measurements are identified. |
| Unresolved evidence is not an owner ballot | `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:178-189`, `:228` | source observation | The document explicitly does not adopt the unresolved reports as defects and does not certify the migration or section 12 complete. |
| Prior blockers | `docs/research/se-fullspread-remediation-readiness-20261105/REPORT.md:50-56` | source observation | The prior report named the unnamed gas set and absent out-of-range outcome as its two remaining product choices. It classified the capacity-parent check as engineering work. |

Public query: not used. No repository text was sent to a public search or fetch service.

## Assumptions

The current remediation owner lock amends older base wording wherever they differ; the older sentence is not a second live product choice. This reading follows the assignment's amendment model and the explicit supersession language in `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:24`, `:55`, and `:109-111`.

The verdict concerns authoring a plan, not proving that every prescribed calculation and integration already works.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md` | required | examined | Read all 248 lines, including owner lock, F1-F11, unresolved reports, recommendations, and limitations. |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md` | optional | examined | Read all 497 lines to check route enumeration, composed rows, retained execution checks, preview behavior, and the capacity procedure against the amendments. |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` | optional | partially examined | Read lines 1-310, including precedence and FS-OWN-01 through FS-OWN-33, to check whether base remainder rules introduced a further owner choice. The remainder was not examined. |
| `docs/research/se-fullspread-remediation-readiness-20261105/REPORT.md` | optional | examined | Read the report to test its two stated blockers against the current owner text, not to inherit its verdict. |

## Conclusions

Verdict: ready

**Observation:** The previously unnamed gas set is now enumerated, and the previously unspecified out-of-range starting-price branch now states its operations and remainder outcomes. These are current owner sentences, not inferred replacements for the missing choices. Sources: `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:32`, `:58`.

**Inference:** Neither prior blocker remains an owner product question. A plan author can copy the seven standalone routes and the named composed-row requirement, and can carry the explicit outside-position branch into the shared planning engine. The existing plan already requires previews and execution to use that same engine; a separate owner-selected preview policy is unnecessary. Sources: `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:32`, `:58`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:192-194`.

**Inference:** The new outside-position sentence must be copied as the amendment it is, rather than silently restored to older wording. In particular, its wanted-token branch expressly says to refund what the add does not take; its other-token branch expressly distinguishes mint refunds from maintenance booking. The older plan's general maintenance-booking sentence does not justify asking the owner to choose again or silently rewriting that new branch. Sources: `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:26-32`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:186`.

**Inference:** Checking the capacity parent, constructing arithmetic that respects the locked rounding constraints, measuring gas, and verifying unresolved integration evidence remain engineering work. They do not require choosing a new product outcome merely to write the plan. The current document preserves those evidence limits rather than declaring them passed. Sources: `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:28-50`, `:58`, `:136-140`, `:178-189`, `:228`.

I found no remaining owner product choice that prevents writing that one plan file under this amendment reading. This conclusion is an independent assessment, not council consensus. It does not replace the remediation PRD or authorize implementation.

## Limits

- Static document assessment only. No implementation source, fixture parent, test execution, build, gas measurement, installation, deployment, or Git operation was examined or performed.
- The algebra and integer implementation have not been proved or executed here. Readiness to author a plan is not numerical or code-readiness certification.
- Historical code observations inside the remediation PRD were read as that document's evidence record, not independently reproduced.
- Family-PRD lines after 310 were not examined. No current peer response or feedback file was read.
- The sources are live files, not an independently fingerprinted snapshot.
- Only the assigned response file was written. Inherited permissions do not prove filesystem confinement.
