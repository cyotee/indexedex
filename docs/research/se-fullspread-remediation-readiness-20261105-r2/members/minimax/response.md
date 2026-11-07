# Member response

## Identity

- Run ID: se-fullspread-remediation-readiness-20261105-r2
- Member label: minimax
- Profile: research
- Phase: initial independent response
- Owned path: docs/research/se-fullspread-remediation-readiness-20261105-r2/members/minimax/response.md
- Requested role: council-member
- Requested model and reasoning: minimax/MiniMax-M3, admitted adaptive thinking, not a selectable depth
- Actual role, model, reasoning, task ID, and session ID: role council-member as assigned; actual model not exposed; reasoning not exposed; task ID not exposed; session ID not exposed
- Fresh or continued: fresh for this run; not otherwise exposed
- Peers read before submission: no

The member label is the caller's assignment. No runtime identity was exposed to this member, so none is claimed here.

## Question and targets

- Question: Is docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md, as now written, ready to be the source from which an implementation plan file is written, with no further owner product decision required?
- Required targets: docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md, read in full as the current file, including the owner lock dated 2026-11-05.
- Optional context: contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md (partially examined); contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md (partially examined); docs/research/se-fullspread-remediation-readiness-20261105/REPORT.md (examined).
- Admitted read scope: the required target, the three optional files above, and the run brief. I read the council package's member-response template for the required response structure; it carries no project evidence and was not used as a source for any claim. No peer response or feedback file was read. No code target from the reviewed plan was opened.

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| Owner lock present in the current target | docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:22-58 | source observation | The current file carries an `## Owner lock, 2026-11-05` section at line 22: scope (26), rule (28), domain (30), out-of-range paragraph (32), the two root equations and their prices (34-44), the shared-boundary note (46), the tick cap (48), the Q96 scaling note (50), and five numbered owner answers (54-58). |
| Standalone gas route set is now named | docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:58 | source observation | Line 58 names the standalone routes: `exchangeIn` one-sided share mint, `exchangeIn` one-token exit, `exchangeIn` pass-through, `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, `compound`. It states `setOperator` and `setOperatorFor` are appointment calls and not routes in this set, requires a gas test for every supported route, gives each plan section 12 row its own composed measurement, keeps the ceilings 11,900,000 / 12,000,000 / 5,000,000, and says an oversized route is unresolved, not passed. It withdraws the count of six. |
| The base plan carries the same amendment | contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:374, 389, 496 | source observation | Plan line 374 assigns "standalone gas for the seven economic money and maintenance routes" to `Money.t.sol`; plan line 389 is the amended owner instruction with the same route list; plan line 496 says gas tests cover the seven standalone economic routes named in section 13 plus each section 12 row. |
| The named routes map onto the installed money selectors | contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:94 | source observation | The money facet installs `exchangeIn`, `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, `compound`, `setOperator`, `setOperatorFor`. The seven named routes sit on five of those selectors; the two operator calls are the appointment calls the lock excludes. |
| Out-of-range starting price outcome is now stated | docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:32 | source observation | Line 32: if `s` is not strictly inside the position, including a price exactly at `sL` or `sU`, the quadratic is not used; the position wants only one token; a caller that provided that token adds it with no swap and refunds what the add does not take; a caller that provided the other token is not swapped, and a share mint refunds it while a donate or compound books it; no new error; zero active liquidity is not this case; a collapsed candidate returns the input and does not keep a selected swap. |
| The lock adds no inherited-domain reject | contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md:399-400 | source observation | FS-PKG-02 lists what installation rejects and ends that bullet with "Do not reject \"outside the inherited domain.\"" The lock's "No new error" at REMEDIATION_PRD.md:32 is consistent with it. |
| The family PRD has no call-time domain rule to contradict | contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md:192, 246 | source observation | FS-OWN-22 is an installation check on the pool key and states there is no inherited-domain check. FS-OWN-33 states the one-sided shape and the refund rule without fixing a starting-price domain. |
| The lock does not reach the one-token exit | docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:26; contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:180 | source observation | The lock scope names a one-sided share mint and a one-token donate or compound, and excludes a bundle deposit and a one-token exit. The exit's own mechanic stays in base plan section 9. |
| The three earlier splits are marked superseded | docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:111, 120, 147 | source observation | The F4, F5 and F8 fix directions each say the owner lock dated 2026-11-05 supersedes the requirement reading, closes the split, or withdraws the older prohibition. |
| The recommendations restate the lock without contradicting it | docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:222-229 | source observation | The eight recommendation bullets repeat the lock: exit error, collapsed candidate, six component checks, booked getter, weighted two-leg `setUp`, FS-A01 to FS-A04 and the gas measurements, the section 12 caution, and the one-sided sizing by the lock. None of them adds or withdraws a rule. |
| The unresolved list is stated as not-a-finding | docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:180, 183, 187-190 | source observation | Line 180 states the items were not re-read far enough to adopt or reject and that naming them is not a finding that they are defects. Line 183 leaves the zero-added-liquidity floor check as a caller-path trace. Lines 187-190 mark share-burn allowance and native credit receipt as not findings. |
| F7 assigns the remaining check to the plan author | docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:136-138 | source observation | Line 136 states `limitCapacity()` and `openCapacity()` are not part of the fixture and no sleeve capacity gate is added; line 138 says not to delete them until the parent requirement is checked. The check is written into the remediation text as work for the plan author. |
| The planned-amount rule is determinate on the page | docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:28, 30 | source observation | Line 28: round the gross swap input down, and swap nothing if that rounded input is zero. Line 30: `n` is the fee-excluded amount that enters the curve, the gross input is `n / g` rounded down, the planned `n` must not exceed the amount the pool will apply for that rounded input, and the pool takes its fee from the input and rounds it up. |
| The zero-add outcome is written in the acceptance rows | contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md:558; docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md:83 | source observation | FS-A05 states added liquidity less than or equal to 1_000 is rejected and the floor is `MIN_SHARES` minted to `address(0)`. The current code maps a failed plan to `MinLiquidityNotMet` on the mint path, and F1 changes only the exit shortfall. |
| The prior report named exactly two open choices | docs/research/se-fullspread-remediation-readiness-20261105/REPORT.md:36, 50, 52, 54, 56, 100 | source observation | The prior report's verdict was not ready (line 36) because two product choices remained open (line 50): item 1, that lock item 5 did not name the standalone gas routes or define the shapes of `exchangeIn` (line 52); and item 2, that the lock's domain was a starting price strictly inside the position and it did not state the outcome when the price is not strictly inside (line 54). It recorded F7 as not an owner question (line 56) and recorded that the root-versus-pool-applied-amount choice was already settled by PRD lines 28 and 30 (line 100). |
| The lock agrees with the base plan's own answers | contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:19, 24, 71, 192, 491-496 | source observation | Plan section 16 lists the six owner answers of 2026-11-05 and they match the lock one for one: components (491 vs PRD 54), weighted two-leg `setUp` (492 vs PRD 55), recipient receipt (493 vs PRD 56), no `exchangeRate` test (495 vs PRD 57), gas coverage of the seven routes plus each section 12 row (496 vs PRD 58), and the one-sided sizing rule with no iteration (494 and 19, 192 vs PRD 24-50). |

## Assumptions

- I read the lock's Scope sentence (REMEDIATION_PRD.md:26) as bounding the Rule, Domain, out-of-range, root and tick-cap sentences (28-48) to the one-sided add flow, because the scope names the two subject operations and then excludes the bundle deposit and the one-token exit. Under that reading the exit keeps base plan section 9 and does not inherit the quadratic.
- I take the plan file to be written as a remediation plan whose scope is the current PRD's Recommendations (222-229) and owner lock (22-58), built on the base implementation plan and family PRD as the base the PRD amends. The brief's question uses that wording.
- I take "Each section 12 row named by the plan" (REMEDIATION_PRD.md:58) to point at the base implementation plan's section 12 row files, observed at plan lines 202 and 374-380.
- I take a rejected sizing candidate to be a sizing-layer result whose input becomes a refund, and the deposit outcome for a zero-liquidity add to be the rejection already written in FS-A05 (family PRD:558). The PRD does not use the word "refund" for the deposit outcome in that case; it uses "returns the input".

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md | required | examined | Read in full as the current file: lines 1-247, including the owner lock, F1 to F11, the unresolved list, coverage, recommendations and publication. |
| contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md | optional | partially examined | Read lines 1-25, 88-100, 170-200, 361, 374, 389, 487-496 and searched for range, gas and sizing rules. Section 12 row bodies, section 13 test bodies and the behaviour rows were not read. |
| contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md | optional | partially examined | Read FS-A01 to FS-A11 at lines 548-566, FS-A31 at 584, FS-OWN-22 at 192, FS-OWN-33 at 246, FS-PKG-02 at 395-400 and the gas ceiling at 427. Other rows were not read. |
| docs/research/se-fullspread-remediation-readiness-20261105/REPORT.md | optional | examined | Read in full to test whether the two product choices it named are still open. |
| docs/research/se-fullspread-remediation-readiness-20261105-r2/brief.md | admitted | examined | Read in full. |
| Peer response and feedback files | not admitted | not examined | Not read, by the scope in the brief. |
| The 48 reviewed code targets | out of scope | not examined | This is not a code-readiness verdict. |

## Conclusions

Verdict: ready.

This is a verdict about the current remediation PRD as the source for one plan file. It is not a verdict that the code is ready to implement, it does not write the plan, and it does not authorize implementation.

Observation: the current target carries the owner lock dated 2026-11-05 (REMEDIATION_PRD.md:22-58), and both product choices the prior report named as open are now stated in the target text.

- The standalone gas route set is closed. Line 58 names seven routes across the installed money selectors, excludes the two operator appointment calls, keeps the three ceilings, and gives each plan section 12 row its own composed measurement. The base plan carries the same amendment at lines 374, 389 and 496, so the target and its base agree. The prior report's first open choice (REPORT.md:52) no longer exists in the text.
- The out-of-range starting price is closed. Line 32 states the route outcome for a price that is not strictly inside the position, including a price exactly at `sL` or `sU`: no quadratic, one token only, no swap, the other token refunded by a share mint or booked by donate or compound, no new error, and a collapsed candidate that returns the input and keeps no selected swap. It agrees with the family PRD, which refuses an inherited-domain reject at installation (family PRD:399-400) and states no call-time domain rule (family PRD:192, 246). The prior report's second open choice (REPORT.md:54) no longer exists in the text.

Observation: I found no pair of contradictory sentences in the current target. The three earlier splits are each marked superseded by the lock in their own fix directions (111, 120, 147). The eight recommendation bullets (222-229) restate the lock and the findings without adding, withdrawing, or narrowing a rule. The lock and the base plan's own owner answers match one for one (plan:491-496 against PRD:54-58 and PRD:24-50).

Observation: the items the target leaves unresolved are not owner product choices. Line 180 says so in terms, and each item either names an existing requirement the implementation may not yet meet (line 183 against family PRD:558), is marked not a finding (187-190), or is an evidence-completeness concern. F7 is explicitly assigned to the plan author, who checks the parent interface and then either keeps empty overrides that add no gate or omits them (136-138).

Inference, and I mark it as inference: a later plan author can copy the sizing rule, the out-of-range rule, the exit basis, the component rule, the rate rule and the gas rule from the current text without choosing between competing sentences, and can resolve the remaining items as engineering work against sentences that are already written. The one place where the target and a family acceptance row touch, a zero-liquidity add, is resolved by FS-A05's written rejection rather than by a new owner answer, and I read the phrase "returns the input" at line 32 as the sizing-layer refund the F3 fix direction describes (102).

Inference: the two decisions the prior report recommended against asking the owner about are also settled on the page. Lines 28 and 30 fix the rounding direction and the inequality between the planned amount and the pool-applied amount, so the root is the solver input and the conservative applied amount is the commitment. That is what REPORT.md:100 already recorded.

I did not find an open, contradictory, or too-unclear product choice in the current target. If a plan author later finds one, it will be in the base plan or family PRD rows I did not read, or in the code, and not in the product sentences of the remediation PRD.

## Limits

- Runtime or extraction proof: none. This is a static reading. No forge test, compile, gas measurement, install, deployment, or Git action was run. No fingerprint was computed.
- Not examined: the 48 code targets of the underlying review; the base plan's section 12 row bodies and section 13 test bodies; most family PRD rows; the blockers file, the underlying review's research report and draft, and the seven behaviour contracts; the four peer response and feedback files.
- The base plan and family PRD were read in part only. A sentence in the unread parts could conflict with the lock, so the residual risk of a base-versus-lock conflict is low but not zero. The prior report's own two open choices were both about the lock and are both closed; the base-versus-lock check I performed covers the sections the lock names.
- The current target's own coverage table (192-201) records that the underlying review's coverage of its targets was partial, and the target instructs that section 12 must not be certified complete (228). That caution travels into the plan file; it is not an owner product question.
- The verdict rests on the disclosed assumption that the lock's scope sentence bounds the sizing paragraphs to the one-sided add flow. If the owner intends the out-of-range paragraph to reach the one-token exit as well, the exit would need a sizing rule of its own, and the base plan's section 9 would need amending. The scope sentence as written excludes the exit, so a plan author is not left to choose.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path. It does not write the plan and it does not offer the owner a menu of choices.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
