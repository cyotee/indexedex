# Member response

## Identity

- Run ID: se-zap-roi-20261031-01a18660
- Member label: minimax
- Profile: research
- Phase: initial independent response
- Owned path: docs/research/se-zap-roi-20261031-01a18660/members/minimax/response.md
- Requested role: MiniMax member of a four-member research council, research profile only. No review phase on this pass.
- Requested model and reasoning: `minimax/MiniMax-M3`, adaptive thinking
- Actual role, model, reasoning, task ID, and session ID: role as assigned by the brief roster; task ID `st_01a192d5` from the run record; actual runtime model, account or route identity, reasoning setting, and session ID were not exposed to me (`not exposed`). I do not assert a runtime model from prose.
- Fresh or continued: fresh. No artifact of my own was carried in. No peer response file from this run was read. The prior run's `REPORT.md` was read because the brief lists it as a required target, and I used it only as the recorded state of the earlier question.
- Peers read before submission: no

## Question and targets

- Question: For `previewZapCredit`, `maxZapBps()`, and `maxZapTickMove()`, is the utilitarian value of the public function worth the incremental implementation cost? For each of the three, recommend implement or do not implement, and separate each public function from any internal cap that must be stored and enforced for `exchangeIn` or `compound`. This recommendation does not authorize implementation and does not lock the PRD.
- Required targets:
  1. `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`, "Zap accounting" section only
  2. `docs/research/se-remaining-functions-20261030-01a18660/REPORT.md`
  3. `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultQuoteTarget.sol`, `previewZapCredit` only
  4. `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultQueryTarget.sol`, the two cap getters only
  5. `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol`, the three declarations only
- Optional context:
  1. `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`, the zap-cap paragraphs only: config items 4 and 5 (lines 181-185), the zap entry sequence (lines 535-556), the compound cap (lines 605-624), the query list and the `previewZapCredit` paragraph (lines 855-877), and the preview-equivalence list (lines 885-897)
  2. The current PairToken planner that `previewZapCredit` calls, read far enough to say whether that planner is also required by `exchangeIn`
- Admitted read scope: the five required targets, the two optional contexts, the run brief, and the run record. To answer the optional planner question and to see what the two caps actually enforce, I also opened two current production files that the brief's list does not name: `.../UniswapV4PairTokenStandardExchangeVaultExecution.sol` and `.../UniswapV4PairTokenStandardExchangeVaultMath.sol`. I used them for exactly the two purposes the brief allows (planner sharing with `exchangeIn`, and what the caps enforce). No PRD, no function-review file, no peer response, and no project code was edited. Files 3, 4 and 5 above were read in full; only the parts named above are relied on.

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| `exchangeIn` already requires the planner and the zap branch | `...VaultExecution.sol:149`, `:174`, `:309` | source observation | `exchangeIn` sets `request.operation.kind = Types.OperationKind.DepositZap` for a token-to-share entry, and the execution path calls `Planner.plan(run.state, request_.operation)`. The planner, the zap branch, the size check and the tick check are therefore required by the money route regardless of any preview. |
| `previewZapCredit` is a thin read of that same plan | `...VaultQuoteTarget.sol:143-151` | source observation | The body is `Repo._requireIdle()`, `_plan(_zapOperation(token_, amount_))`, then five plan fields. There is no second planner, no new math and no storage in it. |
| The `shares` value is already on an accepted surface | `...VaultQuoteTarget.sol:48-57` (`:56` returns `_plan(_zapOperation(in_, amount_)).shares`), `:84-86` (`previewExchangeIn` calls that same `_previewRoute`) | source observation | `previewExchangeIn(token, amount, share)` returns the identical expression's result. The first return value of `previewZapCredit` duplicates `previewExchangeIn` exactly. |
| The per-currency credit and the residual are computed by the planner | `...VaultPlanner.sol:293-321` (`:303` sets `credit` from the caller's attributable growth, `:305` sets `uncredited` from the leftover caller inventory, `:320` books that leftover into `inventory.booked`) | source observation | For a zap, `credit0/credit1` is how much removable principal the caller's addition produced in each currency, and `uncredited0/uncredited1` is the leftover of the caller's own inventory, booked as idle and given no shares. |
| The same two numbers are already published, but only after the money moved | `...VaultExecution.sol:274-279` | source observation | Execution emits `ZapCredit(caller, recipient, tokenIn, amountIn, credit0, credit1, uncredited0, uncredited1, shares)`. The split is observable post-execution and silent pre-trade. |
| The size cap's revert carries the operative maximum | `...VaultPlanner.sol:28`, `:251-254` | source observation | `ZapSizeExceeded(uint256 amount, uint256 maximum)` is raised with `maximum = mulDiv(inputReserve, config.maxZapBps, 10000)`. The exact limit that applies is already delivered in revert data. |
| The operative size cap is reserve-relative, so the bps is not the limit | `...VaultPlanner.sol:246-255` with `_reserves` at `:459-462` | source observation | The maximum is a fraction of the input-side reserves (position principal plus booked), which move with the position. `maxZapBps()` returns only the fraction. |
| The tick cap's revert carries the same number the getter would return | `...VaultPlanner.sol:33`, `:259-264` | source observation | `ZapTickMoveExceeded(uint256 movement, uint256 maximum)` is raised with `maximumMove = config.maxZapTickMove`, the identical stored value. |
| The tick bound is scoped to the vault's own entry swap | stage-one PRD lines 546-547 | source observation | "Enforce `abs(tickAfter - tickBefore) <= maxZapTickMove` around that swap only. This is not a bound on every square-root-price change." Stage-one wording is evidence of shape only. |
| `maxZapBps` has a second, differently scaled use | `...VaultMath.sol:289`, `:262-292` | source observation | The compound swap is capped at `mulDiv(reserve, maxZapBps, 10000) / 4`, so one number governs an entry share and a quarter-sized compound swap. |
| Both caps are treated as immutable instance parameters | stage-one PRD lines 181-185, 112 | source observation | `maxZapBps` positive and at most 10,000, `maxZapTickMove` nonnegative, no silent defaults; the values govern zap sizing and the compounding cap. Stage-one policy, evidence of shape only. |
| Per-function publication cost in the current shape | interface `:316`, `:323`, `:341`; `...VaultQueryFacet.sol:45-46`; `...VaultDFPkg.sol:437-438`; `...VaultQueryTarget.sol:117`, `:126` | source observation | A getter costs an interface declaration, a facet function-array entry, a package selector entry and one storage read in the body. A preview additionally costs one external view function and its test row. |
| The two getters have no standard surface to map onto | prior `REPORT.md`, "maxZapBps and maxZapTickMove" section | coordinator-supplied | "There is no accepted standard getter to map them onto." Keep or drop are the only options. |
| The earlier pass did not settle these three | prior `REPORT.md`, answer table | coordinator-supplied | `previewZapCredit` was not settled (three would keep it, one would map it away); the getters split two keep / two drop; no original removed the caps themselves. |
| The review file treats the getter and the cap as separate questions | `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`, "Zap accounting" | source observation | "The public getter is what is under discussion. Dropping the getter would not, by itself, drop a cap." |

Public web query: not used.

## Assumptions

1. The full-spread family keeps a single-token entry route that the vault balances with a swap. The review file's "Zap accounting" section describes exactly that route, and my difficulty estimate for `previewZapCredit` is stated on that basis. If the family has no zap entry, `previewZapCredit` has no subject and the question dissolves.
2. The family reuses one planner for `exchangeIn` and for the quote surface, as the current PairToken body does: the quote target calls `Planner.plan` through `_plan`, and the execution target calls the same `Planner.plan`. My cost estimate for `previewZapCredit` depends on this. If the family instead built a separate zap planner for the preview, the cost would be a second planner and my recommendation would flip to do not implement.
3. The plan the family executes must already carry the caller's credited amounts and the leftover, because execution has to decide what happens to the leftover whatever policy is chosen. Whether those fields are named `credit` and `uncredited` is cosmetic. If the family locks a refund-of-residual policy, `uncredited` is always zero; see the flip condition in Conclusions.
4. "Incremental work" is measured against the entry route this family already has to build, as the brief directs, not against the whole vault.
5. The stage-one PRD and the current PairToken bodies are evidence of shape. Where this response cites them, it does not adopt stage-one residual policy, stage-one issuance formulas, or the compound quarter-cap. No difficulty estimate in this response depends on copying them.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`, "Zap accounting" | required | examined | Read; used for the three open questions, the separation of getter from cap, and the definition of the function's returns. |
| prior `REPORT.md` | required | examined | Read; used for the recorded state of the earlier question and for the absence of a standard getter to map the caps onto. |
| `...VaultQuoteTarget.sol`, `previewZapCredit` | required | examined | Read with its helpers `_zapOperation` and `_previewRoute`, which is the minimum needed to see what the function costs and what it duplicates. |
| `...VaultQueryTarget.sol`, the two cap getters | required | examined | Both are one-line reads of `Repo._layoutStruct().config`. |
| `IUniswapV4PairTokenStandardExchangeVault.sol`, the three declarations | required | examined | Read for the three declarations, their documented meaning and their selector tags. |
| stage-one PRD, zap-cap paragraphs | optional | examined | Read the config, entry-sequence, compound-cap, query-list and preview-equivalence paragraphs for what the caps enforce. |
| The current planner `previewZapCredit` calls | optional | examined | Read far enough to establish the zap branch, both cap checks, the credit and residual accounting, and the error shapes. |
| The full-spread vault PRD | not in the admitted list | not examined | Out of admitted scope. I therefore do not know whether the full-spread PRD already locks a zap size cap, a tick cap, or a residual policy. Every conclusion below is conditional on that and is stated as such. |
| Behavior, facade, and deployment configuration of the full-spread family | not in the admitted list | not examined | Out of admitted scope. Impact on difficulty is small and is stated in Assumptions 2 and 3. |

## Conclusions

Summary. The three public functions have very different cost-to-value profiles. The preview is nearly free because the money route already builds the machinery it reports; the two getters are also nearly free, and that is precisely why they are not worth a permanent public surface, because the numbers they would publish are already delivered by the family's own revert data.

| Public function | Recommendation | Public surface | Separate internal cap |
| --- | --- | --- | --- |
| `previewZapCredit` | implement | keep | not applicable, no cap is exposed by it |
| `maxZapBps()` | do not implement | drop | keep the cap as internal configuration and enforcement, if the family locks one |
| `maxZapTickMove()` | do not implement | drop | keep the cap as internal configuration and enforcement, if the family locks one |

### `previewZapCredit`: implement

Value. Two of its five return values are redundant and three are not, and the three are the reason to keep it.

- `shares` is exactly what `previewExchangeIn(token, amount, share)` already returns: both call `_plan(_zapOperation(...))` and read `.shares` (`...VaultQuoteTarget.sol:56` and `:143-151`). Redundant, but harmless.
- `credit0` and `credit1` answer a question no accepted preview answers: how the caller's single-token deposit was funded across both currencies of the pool. A caller depositing one side of a two-sided position learns how much of each side of the pool their money actually bought. The accepted previews return a share count and, on exit, an `amountRefunded` of unkept input; the earlier report records that all four originals agreed the refund return is not a per-currency credit split. This is the only surface that carries the split.
- `uncredited0` and `uncredited1` disclose the part of the caller's own input that bought no shares and is booked as idle, that is, the part donated to incumbents by the vault's internal swap. `previewExchangeIn` gives a share count with no indication that a slice of the input was given away. The `ZapCredit` event carries the same numbers, but only after the transfer; a pre-trade quote is the difference between a caller who can see the effective entry price and one who cannot.

That is the utilitarian test the brief sets: what can a caller, integrator, or operator do with these numbers that `previewExchangeIn` and a revert cannot already give them. Here the answer is concrete. An integrator can show the depositor the effective composition of a one-sided entry instead of a headline share count, and can compare a zap against a paired entry when the uncredited residual is large. Neither is possible with the accepted preview and a revert.

Difficulty, and why it is low. The current body is a thin read of a plan the money route already produces. `exchangeIn` for a token-to-share entry already sets the `DepositZap` operation kind and already calls the same planner (`...VaultExecution.sol:174` and `:309`), so the planner, the zap branch, both cap checks and the credit and residual accounting exist because of the entry route, not because of the preview. The marginal work of the preview is one external view function, one interface declaration, one facet entry, one package selector entry, and one test row. That is the low end of this family's surface, against a disclosure that no other accepted function provides.

I do not claim a second planner is needed, and the current body does not have one. I do not claim the preview creates a new policy dependency: whatever the family decides about the leftover, execution must already decide it, and the preview reports the decision rather than making it. My estimate does not depend on copying stage-one residual policy, stage-one issuance formulas, or the compound quarter-cap.

Flip conditions, stated so the coordinator can carry them:

- If the family locks a refund-of-residual policy, `uncredited0` and `uncredited1` are always zero and one of the two non-redundant values disappears. The function would then report shares (redundant) and the credit split (still informative). My recommendation stays implement on the strength of the credit split alone, but the case for it becomes thinner, and if the family also decides the credit split needs no public home, the correct answer becomes do not implement.
- If the family builds a separate planner for the preview instead of sharing the one `exchangeIn` uses, the marginal cost stops being a thin read and becomes a second planner, and my recommendation flips to do not implement.
- If the family has no one-sided entry route, there is nothing to preview.

### `maxZapBps()`: do not implement as a public function

The cap and the getter are different work and I separate them.

The internal cap: I recommend the family keep an internal bound on the size of one zap, as configuration that the planner enforces. This is a risk control on how much of the input-side reserves a single entry may consume, and its cost is a config field, its validation at package construction, and one check in the planner. That cost is incurred whether or not the getter is public, and dropping the getter does not drop the cap.

The public getter: do not implement.

- It publishes a fraction, not the limit that applies. The operative cap is `floor(inputReserve * maxZapBps / 10000)` against live reserves (`...VaultPlanner.sol:251-254`), and the reserves the planner uses are position principal plus booked (`...VaultPlanner.sol:459-462`). A caller holding only `maxZapBps()` cannot compute the amount it may actually deposit. It can approximate from `IBasicVault.reserves()`, which the review file defines as local plus deployed, where deployed includes unpaid fees, so the approximation is not the planner's definition and has to be kept in sync by the integrator.
- The exact limit is already delivered by the family's own revert, `ZapSizeExceeded(amount, maximum)`, which carries the attempted amount and the operative maximum. A simulated call already answers "how much may I zap" precisely, with the number that actually applies at that moment. The getter's only addition is a fraction the caller did not need.
- Publishing it also advertises the coupling to a second, differently scaled cap. The same number bounds a quarter-sized compound swap (`...VaultMath.sol:289`). A public `maxZapBps()` either has to promise that second relationship, which would lock a compound policy the brief says is not a requirement, or deny it, which would misdescribe the field.
- The cost of the getter is trivial, one storage read plus wiring. So this is a value judgment, not a cost judgment, and the brief's warning about the cost of a second planner does not apply here. The right question is only whether the number earns a permanent public slot, and the family's own revert data says it does not.

The one narrow advantage of the getter over a simulated revert is that it answers during a busy operation, since the static configuration getters are available while economic queries are rejected. I do not think that is worth a permanent ABI surface.

If the family wants a client-side pre-check, the surface that would earn its place is a getter for the effective maximum for a given input currency, not the raw fraction. No such surface is needed today, because the revert already carries it, and I am not recommending one.

### `maxZapTickMove()`: do not implement as a public function

The internal cap: I recommend the family keep an internal bound on how far the vault's own entry swap may move the pool tick, as configuration the planner enforces. That is a real risk control against the vault's internal swap pushing the pool price, and its cost is a config field, its validation, and one check in the planner. It is independent of the getter.

The public getter: do not implement.

- The number it would return is the number the family's own revert already carries. `ZapTickMoveExceeded(movement, maximum)` is raised with `maximumMove = config.maxZapTickMove` (`...VaultPlanner.sol:259-264`), so the configured bound is exactly the `maximum` field of the revert. The getter adds a second way to read one stored constant and no information beyond it.
- Publishing it invites a reading it does not support. The bound is on the tick movement caused by the vault's internal entry swap, and the stage-one wording is explicit that it is not a bound on every square-root-price change (stage-one PRD lines 546-547). A public number of this shape will be taken by integrators as a depositor-facing price-impact or slippage guarantee, which it is not, and the vault cannot stand behind that reading.
- As with `maxZapBps()`, the cost of exposing it is trivial, so this is again a value judgment. The value is a convenience read of a value the family already publishes in its own error data, on a number whose meaning is easy to misread in public.

### What this means for the family as a whole

Two of the three public functions are not worth a permanent public surface, and the reason is uniform: the family already publishes the operative numbers in the revert data of the very routes these caps bound, and the raw configuration fractions or bounds add either no information (`maxZapTickMove`) or a quantity that is not the operative limit (`maxZapBps`). The third, `previewZapCredit`, is worth keeping precisely because it publishes something no revert and no accepted preview publishes: the per-currency composition of a one-sided entry and the slice of the caller's input that was not credited.

The internal caps should be decided on their own merits as configuration, and dropping the two getters does not drop them.

## Limits

- Runtime or extraction proof: none. No contract was compiled, deployed, called, or tested. Every statement about the current bodies is a static reading of source at the cited lines; the evidence class for each row says so.
- The full-spread vault PRD was outside the admitted list and was not examined. I therefore do not know what that PRD already locks about a zap size cap, a tick cap, or a residual policy. Each conclusion above states its dependency on those choices rather than assuming them.
- The current PairToken bodies are evidence of shape, not a requirement to copy. My difficulty estimates do not depend on copying the stage-one residual policy, the stage-one issuance formulas, or the compound quarter-cap, and I have not adopted them as requirements for this family.
- The `exchangeIn` and cap-enforcement facts were read from two current production files that the brief's admitted list does not name by path, for the two purposes the brief allows. A coordinator may prefer to re-verify those two facts from the admitted planner and the brief's own wording.
- I did not read any peer response, so I do not claim agreement, consensus, or council support for any position here. The prior report's recorded split is reported as history, not as authority.
- No implementation, test, install, deployment, wallet use, Git action, or council launch was performed, and none is authorized by this file.
