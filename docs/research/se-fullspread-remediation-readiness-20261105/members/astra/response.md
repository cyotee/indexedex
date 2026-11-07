# Independent planning-readiness response

## Identity

- Council: se-fullspread-remediation-readiness-20261105.
- Member: astra.
- Profile: research.
- Phase: initial independent response.
- Requested role: council-member.
- Requested model: `chatgpt-subscription/gpt-6-astra:high`.
- Actual runtime model, reasoning setting, account, task ID, and conversation ID: not exposed.
- Peer responses read before submission: no.

## Question and targets

Is `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`, including the owner lock dated 2026-11-05, ready to supply a later implementation plan without another owner product decision?

The required target was read in full. Both admitted optional documents were also read in full to distinguish an actual missing product rule from a rule already supplied by the base:

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md`.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`.

This is a planning-source assessment, not a code-readiness assessment.

## Evidence

### Observations: what the remediation PRD settles

| Subject | Observed requirement and locator | Planning inference |
| --- | --- | --- |
| F1 and F10: incomplete exit | The incomplete conversion must raise `AmountOutNotMet`, must not burn, and needs an assertion in `Money.t.sol`. `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:80-82`, `:161-163`. | The required error and regression destination need no new product choice. |
| F2: exit amount | The owner explicitly chooses recipient receipt, including swap proceeds and the withdrawn amount sent to the recipient, rather than the pre-execution quote. F2 distinguishes an observed planned payment from an unobserved economic mismatch. `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:54`, `:89-92`. | The minimum and return-value basis are closed. A later engineer must verify the mechanism, not ask the owner to choose the basis again. |
| F3: rejected sizing candidate | A rejected candidate must not retain a selected swap while promising the input back. A selected executable plan must consume the other-token output and leave only input-token remainder. `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:98-100`, `:221`. | The remainder invariant is clear. The relationship between the new root and integer execution still needs the clarification identified below. |
| F4: sizing method | The owner replaces the old greatest-liquidity search reading with a noniterative exact-input quadratic and a directional segment-boundary cap. The old 96-step method is not retained. `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:24-48`, `:107-109`. | Do not reopen the search-versus-one-swap decision. The blockers below concern the locked method's own meaning and domain. |
| F5: infrastructure | All six named bindings are components and must contain code; a missing or code-empty value raises `InvalidComponent` without a partial diamond. `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:52`, `:116-118`. | Historical disagreement about the word "component" no longer leaves a product choice. |
| F6 and F7: fixture surface | Remove the booked getter and do not add a production booked view. Empty capacity overrides are not accepted as satisfying their absence, but deletion waits for examination of the parent requirement. `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:125-138`. | The parent-interface investigation is unfinished engineering evidence, not by itself a reason to ask the owner whether to add a capacity gate. |
| F8: weighted setup | Keep the two-leg override, call the weighted test base and `_initializeWeighted(2)`, and retain the distinct three-leg setup. The earlier prohibition is withdrawn. `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:53`, `:143-145`. | Closed; retaining the historical finding does not revive the withdrawn prohibition. |
| F9: package and rate tests | FS-A01 through FS-A04 remain required. The `exchangeRate` half of FS-A16 is withdrawn, while `getRate` remains uninstalled. `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:55`, `:152-154`. | No new choice about a vault rate or a replacement rate test is needed. |
| F11: gas coverage | Every supported route has a measurement; sampling is insufficient. The ceilings are 11,900,000 for the cold standalone body, 12,000,000 for the composed transaction, and 5,000,000 for preview. Oversized routes remain unresolved. `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:56`, `:170-172`. | The coverage and acceptance policy are specified. Actual gas results remain future evidence. |

### Observations: evidence gaps are not automatically product questions

The remediation PRD expressly labels its unresolved list as reports not sufficiently re-read to adopt or reject, rather than established defects. That list includes exit projection, the first-deposit floor, matrix evidence, share authority, native receipt, migration, and stale index anchors. `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:176-188`.

The admitted base supplies several relevant requirements:

- Exit previews use the post-removal state. `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:194`.
- A zero-consumption first deposit remains subject to the existing minimum and first-deposit liquidity checks. `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:156`.
- The caller supplies its own shares on the borrowed path; parked shares are not burn credit. `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:160`, `:168`.
- A rejected PairToken identity bind is recorded without passing the variant, and the canonical proof stays open. `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:225`, `:295`.

**Inference:** The word "unresolved" in the review record does not, by itself, establish a missing owner decision. These items require evidence or conformance work against existing requirements. I do not convert them into additional product blockers. Likewise, I do not treat a future gas failure or an intentionally recorded hook rejection as permission to change the product.

## Assumptions

- The remediation PRD amends the admitted base documents; it is not required to repeat their entire specification.
- Explicit supersession controls over historical finding text. In particular, F4's old search reading and F8's old setup prohibition are superseded, and F5's component scope is settled. `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:24`, `:52-53`, `:107-109`, `:145`.
- A later engineer may choose representation and implementation structure, but may not silently change an owner-prescribed amount, accepted input domain, or route result. The lock permits Q96 scaling only if it does not change the root. `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:48`.
- The arithmetic reasoning below is an inference from the specified formula and rounding, not a claim about the current implementation or an executed pool transaction.

## Coverage

| Input | Status | Use |
| --- | --- | --- |
| Council brief | Examined in full | Assignment, admissible sources, verdict standard, and output boundary. |
| Required remediation PRD | Examined in full | Owner lock, every finding F1-F11, unresolved list, recommendations, coverage, and limitations. |
| Optional implementation plan | Examined in full | Tested whether the base resolves apparent omissions and preserves already chosen outcomes. |
| Optional family PRD | Examined in full | Tested accepted pool domain, first-deposit rules, and integration rejection policy. |
| Source code, tests, prior member originals, feedback, and other referenced documents | Not examined | Outside this assignment's admitted evidence. Their descriptions in the supplied documents were not independently verified. |
| Peer responses in this council | Not read | Independence preserved. |

## Conclusions

Verdict: not ready

Two clarifications in **Owner lock, 2026-11-05** prevent a later author from copying one unambiguous product rule. Neither asks the owner to reconsider the noniterative method or the five other answers.

### 1. Rule / Domain / Token0 in / Token1 in: the root and the executable net input share one incompatible definition

**Observation.** The lock defines `n` as the fee-excluded amount that enters the curve, defines gross input as `floor(n / g)`, and requires planned `n` not to exceed the pool-applied amount after upward fee rounding. It then defines that same `n` as the positive quadratic root and uses it to calculate the resulting price. `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:28-42`. The ratio statement and scaling statement retain the root as the specified boundary. `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:44-48`.

**Inference.** Consider the uncapped case, with positive gross input and `0 < g <= 1`. Let `r` denote the exact real root and let `q = floor(r / g)`. Under the lock's fee-rounding rule, the net amount available to enter the curve is at most

`u = q - ceil(q * (1 - g)) <= g * q <= r`.

The inequality is strict whenever the root and gross-input/fee rounding do not align exactly. But interpreting the specified `n` literally as `r` also requires `r <= u`. Both requirements can then hold only in the exact-alignment cases. This deduction uses the rounding rule at `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:30` and the root definitions at `:32-42`; it is not a tested implementation result.

One careful author could use the real root in the stated post-swap price, while another could replace that value with the smaller executable net amount and recompute the price and add. Those are different planned amounts and prices. The text does not distinguish an ideal root from a rounded execution quantity, and changing units alone does not resolve that distinction.

**Clarification required:** distinguish the mathematical root from the executable fee-excluded input, and state which quantity governs the post-rounding price and following add. This must preserve the already locked downward gross rounding, no-overestimate requirement, noniteration, and input-token-only remainder. Without that clarification, a plan author would have to decide which literal use of `n` to relax.

### 2. Domain: the prescribed method does not cover the base's accepted pool domain

**Observation.** The new method assumes `sL < s < sU`. Its price formulas use active liquidity, including `n / L`, and its only stated alternative is a segment-boundary cap when an already solved price would leave the segment. It does not state an execution or preview outcome when the starting price is not strictly inside the position. `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:26-46`.

The base accepts any initialized hookless pool without an inherited-domain check, and defines the position by `minUsableTick` and `maxUsableTick`. It also says the first depositor creates the position; package admission does not promise positive active pool liquidity. `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md:61`, `:192`, `:397-406`.

**Inference.** The analytic domain is not established as an invariant of every admitted pool and call. A plan author cannot infer that a strict-interior assumption creates a new pool or route rejection, nor can that author invent a different sizing/add rule outside the stated domain. The zero-active-liquidity case also needs an explicit terminal interpretation rather than applying a formula containing division by `L`. The cap sentence addresses a price moving out of a segment after solving; it does not define these starting-state cases.

**Clarification required:** specify the execution and preview outcome of the scoped one-sided routes when their starting state is outside the analytic domain, including zero active liquidity. State that outcome consistently with existing pool admission and first-deposit checks. This is a missing route-behavior rule, not a request to add a search, a tighter price limit, or a new error.

These are the only product-choice blockers I identify from the admitted documents. Historical dissent and incomplete implementation evidence do not independently change this verdict.

## Limits

- No implementation plan was written.
- No source code, test bodies, or current runtime behavior were audited.
- No tests, builds, installs, Git operations, external searches, or sub-agents were used.
- Only this owned response file was written.
- The arithmetic conclusion concerns internal consistency of the prescribed quantities; it does not establish a live exploit, a failing transaction, or a complete numerical design.
- This response does not replace the remediation PRD, amend an owner lock, or authorize implementation.
