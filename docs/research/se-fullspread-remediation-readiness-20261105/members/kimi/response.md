# Member response

## Identity

- Run ID: se-fullspread-remediation-readiness-20261105
- Member label: kimi
- Profile: research
- Phase: initial independent response
- Owned path: `docs/research/se-fullspread-remediation-readiness-20261105/members/kimi/response.md`
- Requested role: council-member
- Requested model and reasoning: `kimi-coding/k3.1-pro:high`, global route
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: not exposed
- Peers read before submission: no

## Question and targets

- Question: Is `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`, including the owner lock dated 2026-11-05, ready to be the source from which an implementation plan is written, with no further owner product decision required?
- Required target: `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`
- Optional context: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md` and `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`
- Admitted read scope: the run brief, the required remediation PRD, and the two optional base documents. No public query was used.

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| Owner lock | `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:22-56` | source observation | The lock specifies the one-sided swap calculation and answers the infrastructure-component, weighted-setup, exit-receipt, rate-test, and gas-coverage questions. |
| Capacity functions | `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:131-138`; `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:223` | source observation | F7 says the empty bodies do not satisfy the fixture exclusion, the parent constraint is unverified, deletion waits on a parent check, and the recommendation does not settle the parent-forced case. |
| Base fixture rule | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:217` | source observation | The base plan says `limitCapacity()` and `openCapacity()` are not part of this fixture and forbids a sleeve capacity gate. |
| Gas route count | `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:56`; `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:167-172`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:374`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:389` | source observation | The lock requires six standalone money and maintenance measurements, including “both shapes” of `exchangeIn`, but neither the remediation PRD nor the cited base table enumerates those six measurements. |
| Route definitions | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md:311`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md:433-440`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:176-186` | source observation | The family lists five money selectors; `exchangeIn` has locked and unlocked dispatch paths, while the money section separately describes one-sided deposit, one-token exit, and pass-through behavior. |
| Unresolved remediation scope | `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:176-188`; `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:218-227` | source observation | The PRD expressly leaves reported items neither adopted nor rejected, and its recommendations do not say whether a subsequent plan must dispose of those items. This is not proof that the reported code behaviors are defects. |

## Assumptions

- none

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| `docs/research/se-fullspread-remediation-readiness-20261105/brief.md` | required assignment | examined | Read for the question, verdict rule, admitted scope, and owned path. |
| `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md` | required | examined | Read in full, lines 1-246, including the 2026-11-05 owner lock, F1-F11, unresolved items, recommendations, and limitations. |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md` | optional | partially examined | Sections 2, 6-13, and 16 were examined where needed to test whether the remediation PRD leaves an owner choice. |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` | optional | partially examined | Owner rules, facet routes, money and unlock rules, and acceptance rows were examined where needed to test the same question. |

## Conclusions

- Verdict: not ready
- The owner lock closes the one-sided sizing choice and the F5, F8, F2, and rate-test splits; those closed choices are not reasons for this verdict (`docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:24-55`). This is a source observation.
- **F7 leaves a required fixture disposition open.** The base plan excludes `limitCapacity()` and `openCapacity()` from the fixture (`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:217`), but the remediation PRD says empty overrides do not satisfy that exclusion, the parent constraint is unverified, and the functions must not be deleted before a parent check (`docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:131-138`). The recommendation repeats the objection without deciding the parent-forced case (`docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:223`). Inference: if the parent requires the overrides, a plan author still lacks the required product disposition; that case must be resolved before one implementation plan can be written.
- **The standalone gas-test matrix is not uniquely specified.** The lock requires “six” routes and “both shapes” of `exchangeIn` (`docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:56`), while the base family lists five money selectors (`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md:311`), the base money section describes three economic `exchangeIn` behaviors (`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:176-186`), and `exchangeIn` also has locked and unlocked dispatch (`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md:433-440`). The base plan repeats, rather than enumerates, the same six-route phrase (`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:374,389`). Inference: two authors can produce different standalone coverage matrices from this text, so the exact required measurements remain too unclear to copy into one plan.
- **The remediation scope is not fully disposed.** The PRD labels multiple reported items “not adopted and not rejected,” including entire groups identified only by member finding numbers (`docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:176-188`), while the recommendations neither include them nor expressly exclude them from the later plan (`docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:218-227`). Inference: a plan author cannot determine whether the assignment is limited to F1-F11 or must also resolve those reported items. This is an open remediation-scope choice, not a claim that any unexamined report is a code defect.

## Limits

- Runtime or extraction proof: static document review only. No implementation, tests, installs, deployment, wallets, or Git actions were run.
- Not examined: peer responses, project source code, and sections of the optional base documents unrelated to the readiness question. Whether the parent interface forces the capacity overrides was not independently checked.
- The unresolved reports are treated as unresolved document scope, not as established defects or as proof of code unreadiness.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
