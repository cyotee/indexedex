# MiniMax member response — remaining full-spread functions

## Identity

- Run ID: `se-remaining-functions-20261030-01a18660`
- Member label: `minimax`
- Profile: `research`
- Phase: initial independent response
- Owned path: `docs/research/se-remaining-functions-20261030-01a18660/members/minimax/response.md`
- Requested role: council member, research profile, one initial independent response
- Requested model and reasoning: `minimax/MiniMax-M3`, adaptive thinking
- Actual role, model, reasoning, task ID, and session ID: council member; provider `minimax`, model `MiniMax-M3` (runtime-exposed); reasoning level `high` as exposed by the runtime, and the brief's "adaptive thinking" setting is not separately exposed; task ID `st_01a192c0` (the run record and this child session directory agree on it); a per-member session identifier is not exposed
- Fresh or continued: fresh session for this assignment
- Peers read before submission: no

## Question and targets

- Question: For each remaining open full-spread function — `previewZapCredit(tokenIn, amountIn)`, `previewWithdrawalMode(shares, paired, tokenOut)`, `maxZapBps()`, `maxZapTickMove()`, `wrappedNative()` — should this family keep it, drop it, or map it onto an accepted standard function?
- Required targets:
  - `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`
  - `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md` — owner lock and accepted interfaces only
  - `docs/research/se-paired-money-necessity-20261030-01a18660/REPORT.md`
  - The current declarations of `previewZapCredit`, `previewWithdrawalMode`, `maxZapBps`, and `maxZapTickMove` in the PairToken interface or stage-one PRD
- Optional context: `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md` for what the zap functions do
- Admitted read scope: the brief and the files above, plus the current production declarations and implementation needed to establish each fact (the PairToken Standard Exchange family interface, quote target, execution target, and the full-spread PRD that this review feeds). No peer response of this run was read.

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| The zap deposit is the `exchangeIn` route | `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultExecution.sol:149-181`, `:174` | source observation | `exchangeIn` sets `OperationKind.DepositZap` when `tokenOut == address(this)`. `previewZapCredit` quotes that same route; it is not a second money route. |
| The standard preview already returns the zap's share count | `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultQuoteTarget.sol:48-56` (`:56`), `:84-86` | source observation | For `out == address(this)`, `_previewRoute` returns `_plan(_zapOperation(in_, amount_)).shares`. That is the identical value `previewZapCredit` returns as its first word. |
| `previewZapCredit` adds only the split | `...QuoteTarget.sol:143-152` | source observation | It returns `plan_.shares, plan_.credit.amount0, plan_.credit.amount1, plan_.uncredited.amount0, plan_.uncredited.amount1`. The credit pair and the uncredited pair have no other public surface. |
| The zap refunds nothing | `...Execution.sol:331-357` (`:335`), `:413-452`, `:463-497` (`:493`) | source observation | The refund bucket is set only on the `DepositPair` native path. On the zap path the declared amount is pulled whole, the leftover is `inventory.callerInput` after the addition, and `_mintCredit` books it (`booked.amount0 += residual.amount0`) instead of refunding it. `amountRefunded` for a zap route is therefore zero by construction. |
| The refund return is one token, not a split | `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md`, "Refund rule" and `IStandardExchangeIn` | source observation | `previewExchangeIn` returns `(amountOut, amountRefunded)`; `amountRefunded` is the unkept `tokenIn`. There is no per-currency word in the accepted exact-in return. |
| The zap residual is required to be previewed | stage-one PRD S1-ACC-07 ("previews and events must expose the uncredited remainder"); full-spread PRD FS-X04 ("previews disclose it") | source observation | An inherited requirement names a preview disclosure of the uncredited remainder, separate from the event. |
| The mode is a planner classification of the same plan | `...QuoteTarget.sol:123-133`; stage-one PRD S1-EXIT-01 | source observation | `previewWithdrawalMode` returns `plan_.mode, plan_.reason` from the plan that also produces the payouts. It is not caller-selectable: "There is no user flag to bypass a valid full-compound plan." |
| The accepted previews must project the selected candidate | stage-one PRD S1-EXIT-01 ("Standard and SY previews use that identical choice"), S1-QUOTE-01 | source observation | The accepted previews already carry the economics of whichever candidate the planner selected, so the amounts reflect the mode without exposing the mode. |
| The mode and reason stay observable after execution | `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol:186` | source observation | `WithdrawalMaintenanceSelected(WithdrawalMode mode, MaintenanceReason reason)` is emitted on every successful withdrawal. |
| Two inherited rows bind a mode query | stage-one PRD S1-A61, S1-A63 | source observation | S1-A61: "mode/reason in preview, event, and execution agree". S1-A63: "Paired mode and single-token ETH mode are unambiguous in the mode-query ABI". Both name a preview or mode-query ABI. |
| The caps are configuration, not routes | stage-one PRD S1-OP-02 step 3, S1-OP-05; full-spread PRD FS-PKG-01 (`uint16 maxZapBps`, `int24 maxZapTickMove` in `PkgArgs`), FS-PKG-02 (`InvalidZapLimits`) | source observation | The caps are deployment arguments, validated at initialization and enforced in the plan. They are not routes and are not quotes. |
| No inherited acceptance row calls the cap getters | stage-one PRD S1-A14, S1-A23 | source observation | S1-A14 covers "size cap boundary, and tick-movement boundary"; S1-A23 covers the compound quarter-cap. Neither calls a getter, and no inherited row calls `maxZapBps()` or `maxZapTickMove()` as an interface. |
| The cap denominators are not publicly readable | stage-one PRD S1-OP-02 step 3, S1-OP-05 | source observation | The zap cap is tested against the pre-entry-swap input-side basket reserve; the compound cap is tested against the active pool reserve. Neither is a public getter, so the bps value alone cannot be turned into a reliable maximum deposit. |
| The wrapper face is in `vaultTokens()` | stage-one PRD S1-NATIVE-01; full-spread PRD FS-OWN-07; `docs/research/se-paired-money-necessity-20261030-01a18660/REPORT.md` ("`vaultTokens()` order must stay stable, with the wrapped face at a native leg's index") | source observation | `vaultTokens()` is `[C0, C1]`, with `C0` the wrapped face when `currency0` is native. The face a caller must pass is already on the accepted Basic Vault getter. |
| The native leg is identifiable | full-spread PRD FS-OWN-02, FS-FACET-01 `queryFacet` row | source observation | `poolKey()` stays callable through the Position Repo pair; `currency0 == address(0)` marks the native leg whose `vaultTokens()` index carries the face. The Position Repo pair is not created by this PRD revision, so this is a construction-order dependency. |
| The wrapper survives as a binding | full-spread PRD FS-PKG-01 (`wrappedNative` in `PkgInit`), FS-PKG-02 (`InvalidWrappedNative`) | source observation | The wrapper is a package binding with an initialization check. A dropped getter does not remove the binding or its validation. |
| The accepted routes need the wrapped face and reject `address(0)` | `se-interface-refund-bundle` REPORT ("They do not accept `address(0)` and do not wrap it"); `se-paired-money-necessity` REPORT | source observation | The bundle routes take the ERC-20 face, and `vaultTokens()` order is the conformance rule for that. |
| No production consumer reads these four | repository-wide identifier search over `contracts/hooks/` for `previewZapCredit\|previewWithdrawalMode\|maxZapBps\|maxZapTickMove\|wrappedNative` returned no match | static analysis | No hook, router, or other production contract reads them. Only the family interface, its own facets, and tests name them. |
| The stage-one PRD ties `previewZapCredit` to SY input forms | stage-one PRD S1-API-05 | source observation | "accepts SY input forms and uses the same planner. It exposes final share credit and uncredited residual, not an additional deposit route." FS-OWN-05 drops SY from this family, so that property is not inherited here; the credit and residual disclosure is. |
| The query facet is still open and already trimmed | full-spread PRD FS-FACET-01 `queryFacet` row | source observation | `poolManager()`, family-only `poolKey()`, `rateAsset()`, and `getRate()` are excluded; the row is marked "Still under function review". |

## Assumptions

- The full-spread family inherits stage-one economics by ID, with the named FS deltas and owner locks overriding. I treated S1-ACC-07, S1-OP-02, S1-EXIT-01, S1-NATIVE-01, and S1-QUOTE-01 as in force except where FS-X04 and FS-OWN-01 through FS-OWN-09 say otherwise.
- I treated the two accepted reports as final: the refund-and-bundle interface set with its owner lock, and the bundle mapping of the paired routes.
- I assumed the Position Repo pair and the Protocol Aware pair will expose `poolKey()` and the protocol components on the diamond as FS-OWN-01 and FS-OWN-02 describe. Neither pair exists yet, so I did not verify runtime availability of `poolKey()`.
- I assumed `vaultTokens()` for this family is `[C0, C1]` in PoolKey order with the wrapped face at a native leg's index, per S1-NATIVE-01 and the paired-money report.
- No implementation of the accepted bundle interfaces exists in the tree, so every statement about `previewExchangeBundleInForSingleOut` and `previewExchangeBundleOut` is a statement about the accepted specification, not about running code.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md` | required | examined | All five open functions and every locked decision were read; the zap section and the `wrappedNative` line were the deciding text. |
| `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md` (owner lock and accepted interfaces only) | required | examined | Owner lock, refund rule, and the three accepted interfaces were read. The non-accepted proposals in that report's "Dissent not adopted" section were not used as requirements. |
| `docs/research/se-paired-money-necessity-20261030-01a18660/REPORT.md` | required | examined | The accepted mapping table and the `vaultTokens()` wrapper-face rule were read. |
| Current declarations of `previewZapCredit`, `previewWithdrawalMode`, `maxZapBps`, `maxZapTickMove` in the PairToken interface or stage-one PRD | required | examined | Read in both places: `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol:312-351` and stage-one PRD S1-API-05. |
| `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md` | optional | examined | S1-ACC-07, S1-OP-02, S1-OP-05, S1-EXIT-01, S1-NATIVE-01, S1-API-05, S1-QUOTE-01, and rows S1-A14, S1-A23, S1-A27, S1-A61, S1-A63, S1-A64 were read. Treated as inherited context, not as new-family law. |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` | optional context | examined | Read for the currently installed facet contents, FS-OWN-02 and FS-OWN-07, and FS-PKG-01/FS-PKG-02. Not edited. |
| Current PairToken family implementation (interface, quote target, execution target) | optional context | examined | Read to establish the route identity, the shared planner, and the refund-versus-booked behaviour of the zap. Not edited. |

## Conclusions

These are recommendations for the coordinator to carry into the draft. They are not agreed decisions, and this response does not lock the PRD.

**Standard I applied.** A family-specific view survives only when it carries economic information that no accepted surface returns and that a caller can act on. Where an accepted surface already returns the same economic value, the family view must either add something the accepted surface cannot express, or be dropped with the loss named.

| Function | Recommendation | Target if mapped |
| --- | --- | --- |
| `previewZapCredit(tokenIn, amountIn)` | **Keep**, as a family-specific preview of the `exchangeIn` zap route | none — not mappable |
| `previewWithdrawalMode(shares, paired, tokenOut)` | **Drop** the selector; map the two exits it quoted | `previewExchangeBundleOut` (paired exit) and `previewExchangeIn` (single-token exit) |
| `maxZapBps()` | **Drop** the getter; **keep** the cap | none — no accepted configuration read exists |
| `maxZapTickMove()` | **Drop** the getter; **keep** the cap | none — no accepted configuration read exists |
| `wrappedNative()` | **Drop** the family getter | none — the face is already on `vaultTokens()` |

### 1. `previewZapCredit(tokenIn, amountIn)` — keep

Do not map it onto `previewExchangeIn`, and do not treat the refund return as a replacement for the split.

- The refund return does **not** replace the per-currency split, for two independent reasons. First, it is a single-token quantity in the input token, while the split is a two-currency decomposition of how the vault funded the minted shares. Second, and decisively, on the zap route `amountRefunded` is zero by construction: the declared input is pulled whole, half is swapped, the rest is added to liquidity, and the rounding remainder is booked into the vault's own inventory rather than returned. The current implementation sets the refund bucket only on the native paired path, and `_mintCredit` books the zap residual. A caller reading `amountRefunded` on a zap quote learns nothing about the residual.
- What the mapped function does not return, stated plainly: `previewExchangeIn` returns `(amountOut, amountRefunded)` where `amountOut` is the same share count `previewZapCredit` already returns. It does **not** return `credit0`/`credit1`, the per-currency funding of those shares; it does **not** return `uncredited0`/`uncredited1`, the per-currency residual; and it does not return the input-side reserve against which the size cap was tested.
- Why keeping it is right rather than merely tolerated: the residual is economic. It is the part of the caller's input that ends up backing shares the caller does not own, and it is the difference between the input quoted and the value actually credited. The inherited text requires a preview to expose it (S1-ACC-07: "previews and events must expose the uncredited remainder"; FS-X04: "previews disclose it"). The `ZapCredit` event covers only the post-execution half of that requirement.
- Keeping it does not create a second money route and does not add drift risk that is not already controlled: `previewZapCredit` quotes the `exchangeIn` zap route, the current implementation derives both quotes from the same `_plan(_zapOperation(...))`, and inherited row S1-A27 requires every SE preview to match execution exactly.
- The one condition that flips this to drop: if the owner rules that a booked no-share residual is "idle unconsumed input" under the accepted refund rule and therefore must be refunded instead of booked, then `amountRefunded` becomes the residual disclosure and the selector becomes redundant. In that case the `credit0`/`credit1` words still have no home on any accepted surface and would have to be dropped too, and FS-X04's booking rule would change. That is an owner decision about the residual's economics, not a preview-surface decision, and it must be taken before the preview is closed.

### 2. `previewWithdrawalMode(shares, paired, tokenOut)` — drop, map to the accepted previews

Drop the selector. The paired exit it quoted maps to `previewExchangeBundleOut(tokenIn = share, amountIn = shares, tokensOut = [C0, C1])`; the single-token exit maps to `previewExchangeIn(tokenIn = share, amountIn = shares, tokenOut)`.

- A caller does not need the choice. The mode is not caller-selectable — S1-EXIT-01 says there is no user flag to bypass a valid full-compound plan — so a caller can only observe it. It is also not an input to any accepted route.
- `previewExchangeBundleOut` is enough for the economics. The accepted previews must project the same operation from the same state and must use the planner's identical maintenance choice, so the returned amounts already reflect whichever candidate the planner selected. The mode label adds nothing to a payout figure.
- What the mapped functions do not return: `previewExchangeBundleOut` returns `(amountsOut[], amountRefunded)` and `previewExchangeIn` returns `(amountOut, amountRefunded)`. Neither returns the `WithdrawalMode` label (`FullCompound` or `CollectOnly`) and neither returns the `MaintenanceReason` classification (`None`, `MaintenanceWorkLimit`, `MaintenancePriceLimit`, `MaintenanceLiquidityLimit`, `MaintenanceDeltaLimit`). A caller loses the ability to ask, before the call, which internal obstacle forced the fallback.
- That loss is acceptable because the reason is a vault-operator diagnostic that the caller cannot act on, and because the classification stays observable after execution through `WithdrawalMaintenanceSelected(mode, reason)`. If a degraded-vault signal is wanted, it should be named as a health or status read by a consumer, not smuggled back in as a withdrawal preview.
- Two inherited items need a re-point, and I am flagging them rather than treating them as resolved: S1-EXIT-01's sentence "Expose the selected mode and reason in `previewWithdrawalMode`", and inherited rows S1-A61 ("mode/reason in preview, event, and execution agree") and S1-A63 ("Paired mode and single-token ETH mode are unambiguous in the mode-query ABI"). Those sentences must be re-worded against the event and the execution plan, and S1-A63's mode-query ABI clause has no remaining home once the `paired` boolean and the `address(0)` sentinel convention disappear. This recommendation does not make that edit.
- The accepted routes also remove the sentinel convention this function carried: `tokenOut == address(0)` as the paired marker, and `address(0)` as the raw-ETH output, both disappear with the mapped routes that reject `address(0)`.

### 3. `maxZapBps()` — drop the getter, keep the cap

Drop the getter. Keep the cap, unchanged, as configuration and enforcement.

- The cap stays in `PkgArgs` (FS-PKG-01), is validated at initialization (`InvalidZapLimits`, FS-PKG-02), and is enforced in the plan (`ZapTooLarge` for the size bound, `ZapMovesPrice` for the tick bound). Dropping the getter removes no protection and no rule. The brief's distinction holds: the getters are not the caps.
- The getter is not a route and not a quote, and there is no accepted function it could map onto — the accepted Standard Exchange surface has no configuration read.
- The getter is also not independently actionable. `maxZapBps` is a ratio whose denominator for the zap is the pre-entry-swap input-side basket reserve, and whose other use is the compound quarter-cap against the active pool reserve. Neither denominator is a public getter, so the bps value on its own cannot be turned into a correct maximum deposit figure. A UI that wants the cap must simulate the quote anyway.
- What is lost: a runtime read of the cap from the vault. The cap remains visible as a deployment argument of the registered vault, and its effect remains observable through the enforcement errors. If a runtime configuration read is later required, name the consumer and put it with the vault's configuration rather than restoring a family query.

### 4. `maxZapTickMove()` — drop the getter, keep the cap

Drop the getter. Keep the cap, unchanged, as configuration and enforcement, with the same reasoning as above.

- The cap stays in `PkgArgs`, stays validated by `InvalidZapLimits`, stays enforced by `ZapMovesPrice`, and stays inherited in S1-OP-02 step 6 ("Enforce `abs(tickAfter - tickBefore) <= maxZapTickMove` around that swap only") and S1-OP-05 ("`maxZapTickMove` governs only entry swaps").
- The numeric value is not quotable for a caller. It bounds the vault's own entry swap, and the price impact of a caller's own trade depends on the pool's liquidity and the trade size, not on this bound. A caller reading the bound learns whether the vault is configured tightly or loosely, which is a configuration fact, not a quote input.
- No inherited acceptance row calls the getter. S1-A14 tests the tick-movement boundary's behaviour; S1-A23 tests the compound quarter-cap. Both survive the getter's removal.
- Same loss and same mitigation as `maxZapBps`.

### 5. `wrappedNative()` — drop the family getter

Drop it from this family. It is unnecessary because `vaultTokens()` already exposes the face, and the Position Repo is the wrong home for it.

- The face is already on an accepted getter. S1-NATIVE-01 defines the currency faces as `C0 = wrappedNative` when `currency0` is native, `C1 = currency1`, and states that `vaultTokens()` uses `[C0, C1]`. The paired-money report repeats it as a conformance rule: the wrapped face sits at a native leg's index. FS-OWN-07 locks `vaultTokens()` to `MultiAssetBasicVaultFacet`, so no new getter is needed to reach it.
- The native leg's index is identifiable from `poolKey()`, which FS-OWN-02 keeps as information through the Position Repo pair: `currency0 == address(0)` marks the native leg, and `vaultTokens()` at that index is the wrapper. Dependency to name: the Position Repo pair is not created by this PRD revision, so until it exists, the native leg's index is known from the pool key recorded at deployment rather than from a live read. That is a construction-order dependency, not a reason to keep a family-only getter.
- It should not move to the Position Repo. The Position Repo holds the state of one position in one pool: the pool key and the ticks. A wrapper address is neither position state nor pool state. If a runtime protocol-component read is ever wanted, the Protocol Aware pair is its home, alongside the PoolManager and the Universal Router under FS-OWN-01 — but for this family the actionable information is the face in `vaultTokens()`, and a wrapper for a pool with no native leg has no use, because this family has no raw-ETH surface and the accepted routes reject `address(0)`.
- What is lost: a single-call read of the package-bound wrapper when the pool has no native leg. The wrapper itself does not go away: it stays a `PkgInit` binding with the `InvalidWrappedNative` initialization check.

### Cross-cutting item to carry into the draft

The zap residual is the one place where the accepted refund rule and the inherited zap accounting touch. The refund rule says a declared input has exactly two buckets — consumed and refunded — and that "idle unconsumed input is not consumption". The inherited zap accounting books the rounding residual into the vault's book with no extra shares for the entrant, which is what makes `amountRefunded` zero on the zap route. Those two statements can be read as consistent (the residual is consumed, because the vault keeps it and it accrues to the basket) or as conflicting (the entrant is charged for input that earns the entrant nothing, which is the outcome the refund rule exists to prevent). The reading decides whether the residual is booked or refunded, and it decides item 1 above. I am not resolving it here: it is an owner decision on the residual's economics, and it should be named as such in the draft rather than settled as a side effect of a preview-surface choice.

### Resulting family surface, for the coordinator's manifest

After these five decisions, the family has no bespoke query selectors left among the five under review: `maxZapBps`, `maxZapTickMove`, and `wrappedNative` are dropped; `poolManager()`, family-only `poolKey()`, `rateAsset()`, and `getRate()` are already excluded by FS-OWN-01 through FS-OWN-03; `basket()` is dropped by FS-OWN-07. What remains of the family's own read surface is `localReserves()` and `positionLiquidity()`, with `poolKey()`, `tickLower()`, and `tickUpper()` arriving through the Position Repo pair. The remaining family-specific preview is `previewZapCredit`. I did not re-derive the selector manifest or interface ids; that is implementation work for whoever implements the family.

## Limits

- Runtime or extraction proof: none. No test, build, simulation, or deployment was run. Every statement about the current family comes from reading production Solidity and PRD text in this repository. The accepted bundle interfaces have no implementation in the tree, so statements about them are statements about the accepted specification.
- Not examined: the Uniswap V4 Position Repo pair and the Protocol Aware pair, which do not exist yet, so I could not verify that `poolKey()` remains callable on the diamond at runtime; the registry's storage of the vault's deployment arguments, which I assumed to be recoverable from the deployment transaction rather than verified in the registry code; the earlier, already-completed council runs' member responses, apart from incidental identifier lines surfaced by a repository-wide name search; the frontend, which has no reader of these five functions in the code I searched.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path. It does not lock the PRD or the function-review file, and it does not amend any accepted report.
- Peer independence: no peer response of this run was read, and no council consensus is claimed. The recommendations above are mine alone.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
