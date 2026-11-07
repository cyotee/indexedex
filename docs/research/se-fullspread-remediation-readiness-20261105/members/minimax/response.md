# Member response

## Identity

- Run ID: se-fullspread-remediation-readiness-20261105
- Member label: minimax
- Profile: research
- Phase: initial independent response
- Owned path: `docs/research/se-fullspread-remediation-readiness-20261105/members/minimax/response.md`
- Requested role: council-member
- Requested model and reasoning: `minimax/MiniMax-M3`, admitted adaptive thinking, not a selectable depth
- Actual role, model, reasoning, task ID, and session ID: role `council-member` as assigned; runtime model identity, reasoning depth, task ID, and session ID not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

- Question: Is `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`, including the owner lock dated 2026-11-05, ready to be the source from which an implementation plan is written, with no further owner product decision required?
- Required targets: `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md` (245 lines, read in full)
- Optional context: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md` (496 lines, read in full) and `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` (688 lines, read in full). Both were read only to test whether the remediation PRD still needs an owner choice.
- Admitted read scope: the required target, the two optional files above, and the brief. No source file, member file, coordinator draft, resolution, or run record was read. Public query: not used.

Source labels used below: `PRD` = the required target, `PLAN` = the implementation plan, `FAMILY` = the family PRD.

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| The lock is dated and scoped | PRD L22-L24 | source observation | The owner lock is dated 2026-11-05, states that it supersedes F4's requirement reading, states that the 96-step search is not the method, and states that it does not authorize implementation. |
| Lock scope | PRD L26 | source observation | Applies to a one-sided share mint and a one-token `donate` or `compound`; explicitly not a bundle deposit and not a one-token exit. The base agrees: the bundle deposit does not run the one-sided swap (PLAN L178) and the exit swaps the unwanted claim (PLAN L180). |
| Lock rule | PRD L28 | source observation | Do not iterate. Size one exact-input swap so the following add consumes the other token at the price that swap produces. A refund is in the provided token. Round the gross swap input down. If that rounded input is zero, swap nothing. Do not size the swap as an exact output. |
| Lock domain and fee rounding | PRD L30 | source observation | Defines `s` strictly inside the position, `sL < s < sU`, constant `L` on the current initialized-tick segment, `A` as the processed amount of the provided token, `g = (1_000_000 - feePips) / 1_000_000`, `n` as the fee-excluded amount. The gross input is `n / g` rounded down. The planned `n` must not exceed the amount the pool will apply for that rounded input. The pool takes its fee from the input and rounds that fee up. |
| Token0 root | PRD L32-L36 | source observation | `n` is the positive root of the stated quadratic; the resulting price is `s' = L · s / (L + n · s)`. |
| Token1 root | PRD L38-L42 | source observation | `n` is the positive root of the stated quadratic; the resulting price is `s' = s + n / L`; the other-token output is `n / (s · s')`. |
| Shared boundary | PRD L44 | source observation | Both roots are the same boundary: after the swap the remaining provided token and the received other token are in the position's per-liquidity ratio at `s'`. The deep-pool "about half" limit is explicitly not a separate rule and not permission to swap half. |
| Segment cap | PRD L46 | source observation | If the solved `s'` would leave the current constant-liquidity segment, do not use the root and do not walk ticks; cap `n` at the fee-excluded input to the segment boundary (`n = L · (s − sBound) / (sBound · s)` for token0, `n = L · (sBound − s)` for token1). One calculation, and not the greatest liquidity past that boundary. |
| Scaling | PRD L48 | source observation | The prices are real prices; a Q96 scaling is permitted but must not change the root. |
| The five companion answers | PRD L52-L56 | source observation | (1) The six infrastructure bindings are components and each must have code, else `InvalidComponent` with no partial diamond. (2) The weighted two-leg row overrides `setUp` and keeps that override. (3) The one-token exit minimum and the returned `amountOut` are the recipient receipt, the swap proceeds plus the withdrawn amount, not the swap proceeds alone and not the pre-execution quote. (4) No `exchangeRate` test; FS-A01 to FS-A04 remain required. (5) Every supported route has a gas test, with ceilings 11,900,000 cold standalone, 12,000,000 composed, 5,000,000 preview, and an oversized route is unresolved, not passed. |
| Every finding carries an invariant, an impact and a fix direction | PRD L77-L174 | source observation | F1 L80/L82; F2 L89/L91; F3 L98/L100; F4 L107/L109; F5 L116/L118; F6 L125/L127; F7 L134/L136; F8 L143/L145; F9 L152/L154; F10 L161/L163; F11 L170/L172. |
| The recommendations cover the findings and the lock | PRD L218-L227 | source observation | L220 exit error, L221 collapsed candidate, L222 the six addresses, L223 the booked getter and the capacity overrides, L224 the weighted override, L225 FS-A01 to FS-A04 and the gas measurements, L226 the migration and section 12, L227 the sizing method. |
| The unresolved list is labelled as coverage | PRD L176-L188 | source observation | The section states that the items were "not re-read far enough to adopt or reject" and that naming them is not a finding that they are defects. |
| The base plan already carries the same six answers | PLAN L19, L71, L123, L180, L192, L323, L387, L389, L493-L496 | source observation | The 2026-11-05 instructions appear in plan sections 2, 4, 6, 9, 10, 12 and 13 and in the section 16 answer list, so the PRD lock and the base state the same owner decisions. |
| The base settles the exit basis and the preview equality | PLAN L123, L180, L194; FAMILY L228, L467 | source observation | The exit minimum is enforced on the recipient receipt, the swap proceeds plus the withdrawn amount. The exit preview uses the same swap, so the quoted `amountOut` matches execution. |
| The base settles the refund rule and the first-deposit floor | FAMILY L33, L328, L418, L422; PLAN L156, L176 | source observation | Unused declared input is refunded to the payer, is not booked and is not minted. The first deposit must add more than `1_000` liquidity or revert `MinLiquidityNotMet`. A later deposit's `grossShares` is `added liquidity * supplyBefore / liquidityBefore`. |
| The base settles the fixture, the hook rows and the migration | PLAN L217, L225, L361, L363 | source observation | `limitCapacity()` and `openCapacity()` are not part of this fixture and no booked getter is added; a rejected identity bind is recorded under FS-HOOK-04 and is not passed; every one-word reader listed in the index migrates to the tuple and the migration must compile repo-wide. |
| PRD L89 is not the wording of the section it cites | PRD L89 against PLAN L180 | source observation | PRD L89 states "A one-token exit uses the actual token output. The caller minimum is enforced on that output" and attributes it to plan section 9. Plan section 9 (PLAN L180) states the recipient receipt and contains no such sentence. |
| No pass-through payment finding exists | PRD L88 | source observation | The re-read states that lines 68-73 are the mint and pass-through branches and that the F2 claim is confined to the exit branches; the pass-through's minimum basis is not a finding. |
| The six standalone gas routes | PLAN L374, L389; PRD L56 | inference | The only set of six that contains both shapes of `exchangeIn` is the `exchangeIn` mint, the `exchangeIn` exit, `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate` and `compound`. The operator appointment calls are appointment, not money or maintenance, routes. |
| Review coverage is partial and disclosed | PRD L190-L199, L229-L235 | source observation | Targets 1-42, target 43 and targets 44-48 are recorded as partially examined; the coordinator re-read only the lines it cites; the review was static reading only. |

## Assumptions

- The later plan author may read the two base files named in the brief, and the PRD's section and row references into them are reliable locators. I checked every section and row this response relies on.
- The 2026-11-05 lock is owner text and outranks the earlier "greatest liquidity" wording at FAMILY L246 and the older plan sentence at PLAN L19, which the plan already restates under the same date.
- The remediation plan's scope is what the PRD adopts: F1 to F11, the 2026-11-05 lock, and the return migration. The eight items at PRD L180-L188 are carried as re-verification items, not as new requirements.
- The runtime model, reasoning depth, task ID, and session ID are reported as not exposed because the assignment did not give them; nothing in this file is a self-description of the runtime model.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md` | required | examined | Read in full (245 lines) with line numbers: owner lock L22-L56, findings F1 to F11 L77-L174, unresolved list L176-L188, coverage L190-L199, recommendations L218-L227, limitations L229-L235. |
| `.../UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md` | optional | examined | Read in full (496 lines) to test whether the PRD still needs an owner choice: sections 1 to 16, including the owner instructions at L19, L71, L123, L180, L192, L323, L387, L389 and L493-L496, the fixture rules at L217, the identity bind at L225, the migration at L361-L363 and the test plan table at L374-L389. |
| `.../UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` | optional | examined | Read in full (688 lines) for the base requirements: FS-X04 L33, FS-OWN-11 to FS-OWN-33 L160-L246, FS-FACET-01 L291-L334, FS-PKG-02 L395-L407, FS-MONEY-01 L410-L428, the section 6 quote table L461-L473, FS-TEST-03 L550-L595, FS-TEST-04 L596-L665 and the audit inventory L616-L665. |
| `docs/research/se-fullspread-remediation-readiness-20261105/brief.md` | required | examined | Read in full; it fixes the question, the verdict rule, the admitted read scope and the owned path. |

## Conclusions

Verdict: ready

Observation: the owner lock dated 2026-11-05 is a complete rule, not a direction to search. It fixes the scope (PRD L26), the rule (PRD L28), the domain and the fee rounding (PRD L30), both roots with their resulting prices (PRD L32-L42), the shared boundary condition (PRD L44), the segment cap (PRD L46) and the scaling rule (PRD L48). The five companion answers (PRD L52-L56) settle the splits the findings had left open: the six infrastructure bindings for F5, the weighted two-leg override for F8, the exit receipt basis for F2, the `exchangeRate` half of FS-A16 for F9, and the gas coverage rule for F11. PLAN L19, L71, L123, L180, L192, L323, L387, L389 and L493-L496 show that the base plan already carries the same six answers, so the PRD and the base agree instead of competing.

Inference: for each of F1 to F11 the required behavior is stated somewhere the plan author can copy, so no finding needs an owner answer. F1's error is named at PRD L80 and L220 and already exists in the base (FAMILY L561, PLAN L180). F2's basis is named at PRD L54 and L91 and is settled by PLAN L123 and L180 together with the preview equality at PLAN L194 and FAMILY L228 and L467. F3's outcome is the refund path already in the base (FAMILY L33, PLAN L176) and the first-deposit floor (FAMILY L418, PLAN L156). F4, F5 and F8 are closed by the lock itself (PRD L52-L53, L109, L118, L145). F6 and F7 name the fixture rule at PRD L125-L136 with the base rule at PLAN L217 and the treatment at PRD L223. F9, F10 and F11 name their files and rows at PRD L154, L163, L172 and L225.

Inference: the eight items at PRD L180-L188 are not open product choices. Each resolves to a base rule or to a code check the plan must perform: the exit projection (PLAN L180, L194, FAMILY L422), the first-deposit floor (FAMILY L418), the identity-bind and partial-consumption rows (PLAN L225), the recorded-rejection classification (PLAN L225), the share-burn allowance (PLAN L140, L160), the native credit receipt (a code check on the diamond `receive` path), the repo-wide migration (PLAN L361-L363) and the index anchors (PRD L188 states the plan does not require regenerating the index). None asks the owner to choose between two product behaviors.

Inference: the one sentence that could mislead a later author is PRD L89, "A one-token exit uses the actual token output", attributed to plan section 9. That sentence is not in plan section 9 (PLAN L180), and the family requires the exit preview's quoted `amountOut` to match execution (FAMILY L228, L467). Read as a post-swap measurement it would contradict the base plan and the PRD's own fix direction at PRD L91 and L220, and it would be the one place that would need an owner answer. Read the way the base settles it, which is the only reading consistent with L91, L220, PLAN L194, FAMILY L228 and the absence of any pass-through payment finding at PRD L88, it changes nothing and needs no owner answer. I record it as wording that the plan author must not misread, not as an open product choice, because the base files settle the behavior.

Inference: the scope is one plan. The remediation touches the sizing math and the planner (PRD L109, L227), the exit error mapping (PRD L82, L220), the package constructor (PRD L118, L222), the matrix fixture and the weighted row (PRD L127, L136, L145, L223, L224), four test files (PRD L154, L163, L172, L225) and the return migration (PRD L187, L226). Every item is a code or test change with a named file and a named requirement, and none needs a new product choice.

This verdict is not a code-readiness verdict, it does not authorize implementation, and it does not certify that the remediation PRD's own review coverage was complete (PRD L190-L199).

## Limits

- Runtime or extraction proof: none. No forge test, compile, gas measurement, install, or deployment was run, and no mutating Git action was taken; one read-only `git status` was run to confirm the only path I changed is my owned response file. Every statement here is a reading of three documents.
- Not examined: no source file of the vault, the PoolManager, the fixtures, or the test files; no member response, feedback file, coordinator draft, resolution, or run record; no `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md`; no blockers file, research report, or behavior contract. The coverage percentages and the "618-file" figure at PRD L187-L188 and L196 are the PRD's statements, not my measurement.
- Scope of the verdict: this answers whether the PRD can source an implementation plan without another owner product decision. It does not answer whether the code is ready to implement, whether the 2026-11-01 readiness report's cells are met, or whether the unresolved items at PRD L180-L188 will turn out to be defects.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path. No plan was written here, and no menu of product choices is offered.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
