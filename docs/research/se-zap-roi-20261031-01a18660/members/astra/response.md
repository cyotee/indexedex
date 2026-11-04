# Astra research response

## Identity

- Assigned member: Astra.
- Requested model and route: `chatgpt-subscription/gpt-6-astra:high`.
- Actual Native model, account route, and reasoning setting: not exposed.
- Native task/session identity and ancestry: not exposed.
- Run: `se-zap-roi-20261031-01a18660`.
- Date: 2026-10-31.
- Role: independent initial research contribution, not coordinator synthesis.

## Question and targets

Is the additional utility of `previewZapCredit`, `maxZapBps`, and `maxZapTickMove` worth their incremental implementation cost beyond the entry route and standard preview this family already needs?

The decision concerns each public function separately from internal accounting, configuration, and cap enforcement. The comparison is against `previewExchangeIn` and rejection of an invalid quote or transaction. The locked removal of `previewWithdrawalMode` and the family `wrappedNative()` getter is not reopened.

## Evidence

The following are source observations from admitted local files, not runtime verification. Paths are relative to the repository root.

**E1. Scope and open decisions.** `docs/research/se-zap-roi-20261031-01a18660/brief.md`, "What the recommendation must decide," explicitly distinguishes public exposure from required internal work. `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md:22-29` describes the preview as shares, per-currency credit, and uncredited amounts; both cap getters remain open independently of their caps.

**E2. The standard preview is not a substitute for every returned field.** `docs/research/se-remaining-functions-20261030-01a18660/REPORT.md`, "Answer" and "`previewZapCredit`," states that `previewExchangeIn`'s `amountRefunded` is unkept input in the supplied token, not `credit0`, `credit1`, `uncredited0`, or `uncredited1`. It also records the accounting-policy objection to retaining the richer preview. This is an observation of the admitted prior report; I did not read its member originals or independently inspect the standard-preview implementation.

**E3. The current richer preview is a projection of a plan, not a separate planner.** `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultQuoteTarget.sol`, `previewZapCredit` (tag `previewZapCredit-73cd027d`), guards idle state, calls `_plan(_zapOperation(token_, amount_))`, and returns `plan_.shares`, both `plan_.credit` amounts, and both `plan_.uncredited` amounts. In the same file, `_plan` at lines 17-24 loads a snapshot and calls `Planner.plan`; `_zapOperation` at lines 37-46 creates a `DepositZap` operation with the input currency and amount.

**E4. Execution also uses that planner.** `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultExecution.sol:149-183` constructs a `DepositZap` request for a currency-to-share `exchangeIn` and passes it to `_exchange`. At lines 268-280, `_exchange` prepares that request and uses `run.plan.shares`, `credit`, and `uncredited` for the deposit result/event. At lines 292-309, preparation calls `Planner.plan(run.state, request_.operation)`. This establishes shared-planner structure in the existing PairToken implementation. It does not prove runtime parity or that the new family already has an equivalent implementation.

**E5. Each getter is currently a stored-config read.** `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultQueryTarget.sol:113-129` returns `Repo._layoutStruct().config.maxZapBps` and `.maxZapTickMove`. Neither body computes a limit, simulates a swap, or enforces a cap. `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol:312-324` declares the respective return types as `uint16` and `int24`; its notices describe the baseline compound quarter-cap linkage and an entry-only nonnegative tick bound. Lines 337-351 declare the preview's five named outputs.

**E6. Baseline enforcement illustrates why a configured limit is not a transaction quote.** `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md:533-551`, S1-OP-02, applies the size limit to pre-entry-swap input reserves and tests absolute tick movement around the entry swap. Lines 604-620 describe a separate compound calculation using an active-pool reserve estimate and a quarter-sized cap, with the tick bound applying only to entry. These passages are evidence about the baseline only. Their formulas, snapshots, compound linkage, and residual treatment are not adopted as new-family requirements.

## Assumptions

- The family must already implement a single-token entry route and its accepted standard preview. Work needed to make those correct is common cost, not a charge attributable solely to these three selectors.
- For the preview recommendation, one internal entry calculation can supply the accepted accounting result to execution and both public previews. E3-E4 demonstrate this shape in PairToken, but the new-family implementation was not examined.
- Credit and any uncredited amounts must mean what the new family's own accounting policy actually does. Exposing them does not decide whether a residual is donated, refunded, retained, or absent. A zero result is appropriate only when the adopted accounting genuinely produces zero; it is not an implementation shortcut.
- For the getter recommendations, the corresponding configured caps exist for internal enforcement. No additional cap, setter, governance role, or compound coupling is proposed merely to give a getter something to return.
- Utility and difficulty ratings below are engineering judgments, not measured development time, gas estimates, user-demand measurements, or financial returns.

## Coverage

| Admitted input or target | Coverage |
| --- | --- |
| Current run brief | Read completely. |
| Function-review file | Zap-accounting section only. |
| Prior remaining-functions report | Read completely; treated as prior synthesis, not new independent votes. |
| Quote target | Named preview and the narrow `_plan`/`_zapOperation` dependency trace. |
| Query target | Both cap getters. |
| Interface | The three named declarations and their notices. |
| Optional stage-one PRD | Entry-cap and compound-cap passages only; not new-family law. |
| Optional planner trace | Followed the preview and `exchangeIn` to their shared `Planner.plan` call; did not audit planner mathematics or execution correctness. |
| All three requested public-function decisions | Answered below, independently of internal caps. |

The language-server definition lookup timed out. Narrow text locators and file reads supplied the call-chain evidence instead. No peer responses were read.

## Conclusions

**Recommendation: implement all three public functions.** The two getters have the clearest cost-benefit case. The richer preview also earns its place as an explanation of the existing entry calculation, not as justification for a second calculation or a particular residual policy.

| Public function | Decision | Additional utility beyond standard preview/revert | Incremental difficulty |
| --- | --- | --- | --- |
| `previewZapCredit(tokenIn, amountIn)` | **Implement** | Shows the per-currency amounts credited to the depositor and any amounts not credited, enabling an integrator to explain or reject an otherwise successful entry on that basis. | Low to moderate when projecting the shared entry result; more work than either getter. |
| `maxZapBps()` | **Implement** | Exposes the configured size policy for discovery, display, and policy-based filtering without trying an invalid amount first. | Very low if that configuration already exists. |
| `maxZapTickMove()` | **Implement** | Exposes the configured entry tick-movement bound for discovery, display, and comparison without first provoking a failed preview. | Very low if that configuration already exists. |

### `previewZapCredit`: useful detail at a bounded additional cost

**Inference from E1-E4:** Its strongest use is explaining a successful quote, not making a rejected quote succeed. A caller can see satisfactory share output yet still want to know whether part of the resulting currency inventory receives no share credit. An integrator can present that decomposition or apply its own rule to the uncredited amounts. `amountRefunded` cannot express a two-currency credit split, and a revert supplies no explanation for an entry that succeeds.

The weaker case is a caller interested only in shares received. That caller already has `previewExchangeIn` and gains little. There is no evidence here that every UI or router needs the richer result. Its value is targeted accounting transparency, not a prerequisite for using the vault.

The incremental implementation is a public projection, ABI/selector integration, documentation of the five outputs, and consistency coverage. The important coverage would establish that the preview and standard preview agree on shares for the same relevant state and that the reported decomposition agrees with execution under controlled unchanged state. Routing, supported-input behavior, and rounding semantics also need to agree. This is not literally free because the visible outputs become a supported contract with callers.

E3-E4 argue against charging this function for building an entire second planner: the reference already computes the data for execution. Reuse that calculation. A separate simulator, separate accounting formulas, or a planner fork would materially worsen ROI and is not part of this recommendation.

**Separate internal decision:** Implementing this preview does not adopt stage-one no-share residual donations, its formulas, or its compound policy. It exposes the accounting chosen for the entry route. The low-to-moderate estimate depends on reusing that route's calculation, not copying stage-one economics. If the eventual entry design lacks a meaningful credit decomposition, the premise of this recommendation has changed; do not manufacture a residual policy to preserve this API.

### `maxZapBps`: modest utility, very small additional cost

**Inference from E5-E6:** An integrator can discover and display the vault's configured size setting or exclude vault configurations that do not meet its own policy. Where the applicable reserve basis is also available, the setting can assist preliminary input sizing. The getter alone is not a maximum input amount: the reserve basis, checkpoint timing, rounding, and other route checks still matter. `previewExchangeIn` remains necessary to quote a candidate transaction.

A revert tests one candidate against current conditions. Even a richly encoded error is not as convenient as directly reading the configured policy without needing a failing candidate. The benefit is modest, but a stored-field read makes the threshold for sufficient ROI correspondingly low.

Incremental work consists of the getter, its selector/interface integration, precise units and scope documentation, and a configured-value assertion through the installed public surface. It does not require a new swap algorithm or planner. Those small integration costs should be counted, rather than calling the whole feature one line, but they do not overturn the recommendation.

**Separate internal cap:** Store and enforce whatever size cap the family's entry design requires regardless of whether this getter is installed. Any compound cap remains an independent internal policy. This recommendation does not copy the baseline reserve formula, quarter-cap, or shared entry/compound parameter. If compound uses a distinct limit, the getter's documentation must not imply it exposes that limit.

### `maxZapTickMove`: similarly cheap policy visibility

**Inference from E5-E6:** The getter lets an operator or integrator read the configured entry-swap tick bound and distinguish vault configurations without constructing a transaction that crosses that bound. It supports policy display and comparison. It does not predict actual tick movement, quote execution price, or provide a caller-selected slippage limit.

The implementation cost is again the stored-field read plus public-surface wiring, documentation, and configured-value coverage. A scalar getter does not need a second swap simulation. Its practical audience may be smaller than that of the main quote, but the incremental cost is small enough to justify it.

**Separate internal cap:** Enforce the adopted entry-swap tick constraint internally whether or not the public getter exists. The getter neither enforces that constraint nor extends it to maintenance, compound, or every price change. Its existence alone is not proof that execution enforces the value.

### Relative priority

The getters are the easiest positive decisions: small additional utility is enough to justify their very small incremental cost. `previewZapCredit` is the more substantial commitment because it publishes accounting semantics and requires parity coverage. I still recommend implementing it, using the existing entry calculation rather than a parallel one. None of these decisions requires copying the baseline compound quarter-cap or resolving the family's residual policy by inheritance.

## Limits

This is a static, scoped ROI assessment. I did not inspect the new-family PRD, audit the full planner, measure gas or developer effort, run tests or builds, perform public web research, or verify deployed behavior. The admitted report is the basis for the standard-preview refund distinction. Current files were read individually, not as an atomic repository snapshot.

Only this assigned response artifact was written. The PRD, function-review file, project code, and peer artifacts were not edited. No implementation or sub-agent work was performed. These recommendations neither lock the PRD nor authorize implementation.
