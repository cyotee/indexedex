# Member response

## Identity

- Run ID: se-zap-roi-20261031-01a18660
- Member label: grok
- Profile: research
- Phase: initial independent response
- Owned path: docs/research/se-zap-roi-20261031-01a18660/members/grok/response.md
- Requested role: Grok member of the research council
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh, from the assignment envelope stating this is the first request of the session. Native session identity was not exposed.
- Peers read before submission: no

The member label is the caller's assignment. This self-description is not proof of the runtime model.

## Question and targets

- Question: For `previewZapCredit`, `maxZapBps`, and `maxZapTickMove`, is the utilitarian value of the public function worth the incremental implementation cost?
- Required targets: the zap section of `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`; `docs/research/se-remaining-functions-20261030-01a18660/REPORT.md`; `previewZapCredit` in `UniswapV4PairTokenStandardExchangeVaultQuoteTarget.sol`; the two cap getters in `UniswapV4PairTokenStandardExchangeVaultQueryTarget.sol`; the three declarations in `IUniswapV4PairTokenStandardExchangeVault.sol`.
- Optional context: zap-cap paragraphs in `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`; the current PairToken planner that `previewZapCredit` calls, only far enough to say whether that planner is also required by `exchangeIn`.
- Admitted read scope: those paths only. No peer originals. No full-spread PRD. No execution facet. No tests, installs, deploys, wallets, or Git.

The verdicts below are for the three public functions. Each is separated from any internal cap. This response does not authorize implementation and does not lock the PRD. `previewWithdrawalMode` and `wrappedNative()` stay locked drops and are not reopened.

## Evidence

Public web search: not used.

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| Open proposal | `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md` lines 22-29 | source observation | `previewZapCredit(tokenIn, amountIn)` would return shares, how much of each currency funds those shares, and how much is left uncredited. Open. `maxZapBps()` is described as the configured cap on how large a single-token deposit or compound swap may be. Open. The public getter is what is under discussion. Dropping the getter would not, by itself, drop a cap. `maxZapTickMove()` is described as the configured cap on how far that entry swap may move the pool's tick. Open, on the same terms. |
| Locked neighbor returns | same file, line 9 and line 18 | source observation | `previewExchangeIn` and `exchangeIn` keep `(amountOut, amountRefunded)`. `compound()` stays: it collects fees and puts them back into the position, and it does not change the share supply. Those lines do not name a bps cap, a tick cap, or a residual donation. |
| Prior split, not a vote on this question | `docs/research/se-remaining-functions-20261030-01a18660/REPORT.md` lines 26-28 and 48-62 | source observation | The three public functions were not settled. Three originals would keep `previewZapCredit`; one would map it onto `previewExchangeIn` and drop the selector. Getter split was two and two. No original removed the caps themselves. The report says `amountRefunded` is unkept input of the token the caller provided, not `credit0`, `credit1`, `uncredited0`, or `uncredited1`. It says the missing split is stage-one residual accounting this family has not locked. |
| Same planner call | `UniswapV4PairTokenStandardExchangeVaultQuoteTarget.sol` lines 17-23, 37-45, 56-57, and 139-153 | source observation | `previewZapCredit` calls `_plan(_zapOperation(...))` and returns `plan_.shares`, `plan_.credit.amount0`, `plan_.credit.amount1`, `plan_.uncredited.amount0`, and `plan_.uncredited.amount1`. `_plan` calls `Planner.plan`. `_zapOperation` builds `OperationKind.DepositZap`. The share-out branch of `_previewRoute` returns `_plan(_zapOperation(in_, amount_)).shares`. `previewExchangeIn` delegates to `_previewRoute`. In this body the zap planner call is not unique to `previewZapCredit`. |
| Current quote signature | same QuoteTarget, `previewExchangeIn` | source observation | The current PairToken `previewExchangeIn` returns one `uint256`, not the locked full-spread pair `(amountOut, amountRefunded)`. The current body is shape, not the accepted full-spread signature. |
| Getter shape | `UniswapV4PairTokenStandardExchangeVaultQueryTarget.sol` lines 113-129 | source observation | `maxZapBps()` returns `config.maxZapBps` as `uint16`. `maxZapTickMove()` returns `config.maxZapTickMove` as `int24`. Each is a storage read. Comments say the first is zap size and compound-cap configuration, and the second is a tick bound around the caller entry swap only. |
| Interface comments | `IUniswapV4PairTokenStandardExchangeVault.sol` lines 312-324 and 337-351 | source observation | `maxZapBps` notice: configured zap size limit, also used by the compound quarter-cap. `maxZapTickMove` notice: nonnegative maximum tick movement around the caller's entry swap only. `previewZapCredit` notice: project share credit and residual donations for a supported SY input form. Returns are named `shares`, `credit0`, `credit1`, `uncredited0`, `uncredited1`. |
| Entry-route enforcement in the current planner | `UniswapV4PairTokenStandardExchangeVaultPlanner.sol` lines 152-153, 188-189, 204-208, 251-254, and 256-264 | source observation | `plan` routes `DepositZap` to `_zapEntry`. Empty supply on that kind reverts `ExchangeInNotAvailable`. `_zapEntry` rejects `amount > FullMath.mulDiv(inputReserve, maxZapBps, 10000)` with `ZapSizeExceeded(amount, maximum)`, then swaps `amount / 2` and rejects an absolute tick delta above `maxZapTickMove` with `ZapTickMoveExceeded`. Maintenance, which runs before that entry, passes `config.maxZapBps` into `Math.tryCompoundSwap`. This excerpt does not show `maxZapTickMove` on the maintenance path. |
| What the zap plan stores | same planner, lines 303-322 | source observation | For a zap, `credit` is post-add principal growth, `uncredited` is remaining caller input, and `shares` come from `Math.zapCredit` on growth, not on that residual. The residual is then added to booked inventory. The non-zap branch folds residual into `credit` instead. `Math.zapCredit` and `Math.tryCompoundSwap` were not opened. |
| Optional stage-one cap text | `PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md` lines 181-185, 541-547, 610-624, and 859-875 | source observation | Stage one requires stored `maxZapBps` and `maxZapTickMove`, with no silent defaults. Single-token deposit size is `0 < amountIn <= floor(inputReserve * maxZapBps / 10000)`. Tick movement is enforced around that entry swap only. Compound swap size uses `maxZapBps / 10000 / 4`. The same PRD says `maxZapTickMove` governs only entry swaps and is not automatically a compounding guard. `previewZapCredit` is specified as the same planner, exposing share credit and uncredited residual, not an additional deposit route. |
| Assignment boundary on copying | brief, "What the recommendation must decide" | coordinator-supplied | Current PairToken bodies are evidence of shape. They are not a requirement to copy the stage-one residual policy, the stage-one formulas, or the compound quarter-cap. A cap stored and enforced for `exchangeIn` or `compound` is not the same work as exposing it. Value is what a caller, integrator, or operator can do with the result that `previewExchangeIn` and a revert do not already give them. |

No supplied runtime. No test run. No atomic snapshot. The files above were read during this pass and can change.

## Assumptions

- The function-review statement that `previewExchangeIn` and `exchangeIn` return `(amountOut, amountRefunded)`, and the remaining-functions report's statement that `amountRefunded` is unkept input of the caller's token, are the accepted surface for this judgment. The refund-bundle report named from the function-review file was not re-read.
- "The entry route this family already has to build" means the locked `exchangeIn` / `previewExchangeIn` route, not a requirement that the full-spread route call this PairToken `Planner` contract. Only the current quote path was observed to call it.
- A bare `uint16` or `int24` does not tell a caller the maximum input unless the enforcement formula is also public law. That formula is not treated as locked.

No required target is missing. The execution facet is not examined, and that gap is not converted into an assumption that execution matches the quote.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| Zap section of `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md` | required | examined | Lines 22-29 read. Lines 1-21 were also read and used only for the locked return and `compound()` statement. Later sections were not used. |
| `docs/research/se-remaining-functions-20261030-01a18660/REPORT.md` | required | examined | Full 67-line report read. |
| `previewZapCredit` in QuoteTarget | required | examined | Lines 139-153 read. The same file's `_plan`, `_zapOperation`, and `_previewRoute` were read because the admitted planner question cannot be answered from the wrapper alone. `previewDepositPair`, `previewRedeemPair`, and `previewWithdrawalMode` were visible and are not requirements. |
| Two cap getters in QueryTarget | required | examined | Lines 113-129 read. The tail of `basket()` and `_positionLiquidity` were visible and are not requirements. |
| Three interface declarations | required | examined | Lines 312-351 read, including the nearby `previewWithdrawalMode` declaration, which stays a locked drop. |
| Stage-one zap-cap paragraphs | optional | examined | Lines 181-185, 535-547, 600-627, and 849-875 read. The rest of that PRD was not examined. |
| Planner, only far enough for the `exchangeIn` question | optional | partially examined | `plan`'s `DepositZap` dispatch, the empty-supply revert, `_maintenance`'s `maxZapBps` pass, `_zapEntry`, and `_entryCredit` were read. Exit planning after line 329 was not read, except the `_withdrawal` helper at line 479. |
| Execution `exchangeIn` body | not a named target | not examined | Not admitted. The quote path is the evidence that this planner is shared with `previewExchangeIn` in the current body. |
| `Math.tryCompoundSwap` and `Math.zapCredit` | not named | not examined | Call sites only. The quarter division is not claimed from code. |
| Full-spread PRD and refund-bundle report | not admitted | not examined | Optional absence is not used to invent requirements. |
| Peer originals | forbidden | not examined | Independent pass. |

## Conclusions

Verdicts, public functions only:

- `previewZapCredit`: do not implement.
- `maxZapBps`: do not implement.
- `maxZapTickMove`: do not implement.

These are ROI judgments for this pass. They are not council consensus. Peers were not read. The prior remaining-functions split is a source fact about a different question, not a vote on these three verdicts.

### `previewZapCredit`: do not implement

Separate the public function from the internal plan.

The public function would be a new family selector beside the locked `previewExchangeIn`. In the current PairToken body it is a view wrapper: it calls the same `_plan(_zapOperation(...))` that the share-out branch of `_previewRoute` already calls, then returns five fields instead of `shares`. That wrapper is small. Its low cost is a fact about this body. It is not a reason to copy stage-one residual booking, `Math.zapCredit`, or the half-swap. If the full-spread entry plan does not already compute `credit0`, `credit1`, `uncredited0`, and `uncredited1`, this selector is a second planner, not a one-line read. This recommendation does not depend on that copy. The value test fails even if the wrapper is free.

What `previewExchangeIn` and a revert already give a caller: shares out, unkept input of the token the caller provided, and rejection of an amount the route will not accept. The prior report's observation, accepted here as that report's text, is that `amountRefunded` is not the four-way split.

What the extra fields would add, if given the current body's meaning: `credit0` and `credit1` are post-swap principal growth attributed to the new shares; `uncredited0` and `uncredited1` are caller inventory booked without minting shares. The interface calls that a residual donation. The function-review proposal says "left uncredited" and does not lock a donation. The remaining-functions report says that residual accounting is not locked for this family. A caller cannot safely act on fields whose meaning is the unlocked policy. Displaying them, or refusing a deposit because of them, is only a real choice after that policy exists.

The shares field is redundant with `previewExchangeIn`. The two uncredited fields collide with the locked refund of unkept input if that refund is the family's rule, and they publish a donation if it is not. Either reading is a product decision this selector would freeze. `credit0` and `credit1` have no other home on the accepted surface. No other home is not a caller action. An integrator still chooses `exchangeIn` or a paired route from shares and refund. The split does not size the deposit, avoid a cap, or replace the revert.

Difficulty beyond the entry route is therefore not the Solidity wrapper. It is a second public quote that must agree with `previewExchangeIn` on shares, plus a defined meaning for four fields the locked return does not contain. Shipping the current body's meaning would copy residual policy the brief says is not required. Shipping the selector without that meaning gives callers numbers they cannot use. Neither is sufficient ROI.

Internal plan fields are not this selector. If `exchangeIn` must know how many shares to mint, that computation belongs to the entry route. It does not require a public five-value preview. This verdict does not remove internal share accounting and does not require the current `uncredited` booking.

### `maxZapBps`: do not implement

This verdict is the public getter only.

The current getter is a one-line read of `config.maxZapBps`. That cost is real and is not being inflated into a second planner. It is still not sufficient ROI. A caller who needs to know whether a deposit will be accepted already has `previewExchangeIn` and a revert. In the current body the revert can be `ZapSizeExceeded(amount, maximum)`, which returns the effective token maximum for that call. The configured `uint16` does not give that maximum unless the formula is also law. The stage-one formula, `floor(inputReserve * maxZapBps / 10000)`, is optional context, not a requirement to copy. Without it, the getter is a number with no caller action that the quote and the revert do not already provide. An operator who set the value already knows it. Publishing the getter would put an undefined cap unit on the family surface.

Internal size enforcement is separate work. Dropping this getter does not drop a cap. Admitted full-spread locks do not say a stored bps must exist. `exchangeIn` is locked as the exact-input route with a refund return. `compound()` is locked as fee collection and reinvestment that does not change supply. Neither lock names `maxZapBps`.

The current planner does enforce `maxZapBps` on `DepositZap` and passes the same field into `Math.tryCompoundSwap` before entry. Stage one also uses it as a compound quarter-cap. Those are shape and optional PRD text. This difficulty judgment does not depend on copying either formula, and this verdict does not adopt them. If a later entry route stores and checks a size limit, that check stands without this selector. This response does not decide that `compound()` uses the same number, and it does not install the quarter-cap.

### `maxZapTickMove`: do not implement

This verdict is the public getter only.

The current getter is a one-line read of `config.maxZapTickMove`. Same cost finding as `maxZapBps`: cheap, and still not enough. `previewExchangeIn` and a revert already answer whether this amount's entry swap is accepted. In the current body, `ZapTickMoveExceeded(absolute, maximumMove)` returns the tick delta and the configured bound for that failed call. The getter adds the configured `int24` before a failing quote. That number is not the maximum input. It also does not say which swap it bounds unless the formula is public law. Stage one bounds only the caller entry swap, and the planner excerpt matches that shape: the comparison is in `_zapEntry` after `amount / 2`, not in the maintenance path that was read. That formula is not a requirement to copy. A caller cannot act on the bare tick distance beyond what a successful or reverting preview already says.

Internal tick enforcement is separate. Dropping this getter does not drop a cap. No admitted full-spread lock requires this stored `int24`. The current body and the stage-one paragraph show an entry-swap-only bound. This verdict does not adopt that comparison, and it does not extend the cap to `compound()`. The stage-one text says the entry tick guard is not automatically a compounding guard. The planner excerpt does not show `maxZapTickMove` on the maintenance path. If the entry route later stores a tick bound and enforces it around its own swap, that is entry-route work, not this getter.

### What would change the ROI

These are limits on the verdicts, not recommendations to implement now.

- If caller-visible residual accounting is later locked, and `previewExchangeIn` still cannot return the four-way split, `previewZapCredit` becomes a thin disclosure wrapper over a plan the entry route already computes. That is a different value test. It is not met today.
- If a stored cap and its formula are later locked, each getter becomes a one-line read with a real integrator use: compute or display the limit without a rejecting quote. Until the formula is law, the getter does not clear the value test in the brief.

## Limits

- Runtime or extraction proof: none. No tests, forge, scripts, or execution traces. All code claims are static reads.
- Not examined: the execution `exchangeIn` body, so this response does not claim that execution calls `Planner.plan`. `Math.tryCompoundSwap` and `Math.zapCredit` were not read, so the quarter-cap is not claimed from code. The full-spread PRD, the refund-bundle report, deployment records, and peer originals were not read. Public search was not used.
- Quote and interface bodies are current PairToken shape. They are not full-spread requirements. Difficulty of a free wrapper was considered and is not the basis of the three "do not implement" verdicts.
- Live files can change. This is not an atomic repository snapshot.
- Agreement is not available on this pass. The prior report's 3-1 and 2-2 splits are not adopted as consensus and are not re-argued as votes.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
