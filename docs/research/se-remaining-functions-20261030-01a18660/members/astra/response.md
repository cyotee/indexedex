# Astra research contribution

## Identity

- Assigned member: Astra.
- Requested model/account route: `chatgpt-subscription/gpt-6-astra:high`.
- Actual Native model/account route: not exposed.
- Actual Native reasoning setting, execution mode, and ancestry: not exposed.
- Run: `se-remaining-functions-20261030-01a18660`.
- Date: 2026-10-31.
- This is an independent initial contribution, not the council's aggregate recommendation. No peer responses were read.

## Question and targets

For each of the five remaining full-spread functions, should the family keep it, drop it, or map its caller need onto an accepted standard function?

The five targets are `previewZapCredit`, `previewWithdrawalMode`, `maxZapBps`, `maxZapTickMove`, and `wrappedNative`. The recommendations below preserve the locked refund ABI, bundle routes, wrapped native faces, and removal of the paired selectors, ERC-5115, `rateAsset`, and `getRate`.

## Evidence

The following are **source observations** from the admitted local documents, not runtime verification:

| ID | Source and locator | Observation |
| --- | --- | --- |
| E1 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`, "Standard Exchange return", "Paired money", "Zap accounting", and "Pool and position identity" | The five targets remain open. The exact-input refund return and bundle mappings are locked. `poolKey` information belongs in a reusable Position Repo; the standard token list uses the wrapped face at a native leg's index. |
| E2 | `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md`, revision `se-interface-refund-bundle-20261030-01a18660-final`, "Owner lock" and "Recommended interfaces" | `previewExchangeIn` returns `(amountOut, amountRefunded)`, where the refund is unkept input in the input token. `previewExchangeBundleOut` returns `(amountsOut, amountRefunded)`. Neither returns credit attribution, maintenance mode, maintenance reason, or configuration caps. The accepted standard routes reject `address(0)`. |
| E3 | `docs/research/se-paired-money-necessity-20261030-01a18660/REPORT.md`, revision `se-paired-money-necessity-20261030-01a18660-final`, "Answer" and "Raw ETH" | Paired redemption maps to `exchangeBundleOut` and its preview, with proportional outputs rather than an implicit sale. Token ordering is stable, native output uses its wrapper, and this mapping does not authorize a raw-ETH extension. |
| E4 | `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`, S1-API-05 | The declarations are `previewZapCredit(address,uint256) -> (shares,credit0,credit1,uncredited0,uncredited1)`, `previewWithdrawalMode(uint256,bool,address) -> (WithdrawalMode,MaintenanceReason)`, `maxZapBps() -> uint16`, and `maxZapTickMove() -> int24`. |
| E5 | Same stage-one PRD, S1-ACC-07 and S1-OP-02 | Baseline zap shares credit removable-principal growth `G_i`; residual caller inventory `J_i` is booked without extra shares. The baseline explicitly retains a no-refund residual policy. Therefore an uncredited residual is not, merely by that name, an amount refunded. |
| E6 | Same stage-one PRD, S1-OP-02 and S1-OP-05 | `maxZapBps` bounds single-token entry against the pre-entry-swap input reserve and also controls the quarter-sized compound-swap cap. `maxZapTickMove` bounds the entry swap's tick movement only, not the compound swap. |
| E7 | Same stage-one PRD, S1-EXIT-01, S1-API-05, and S1-QUOTE-01 | The baseline planner selects full compound or collection-only maintenance before mutation. Its standard previews already incorporate that selection. The dedicated mode query exposes the selected mode and reason but gives the caller no bypass flag. |
| E8 | Same stage-one PRD, S1-NATIVE-01 | The PoolKey retains native currency identity while `vaultTokens()` uses the wrapped ERC-20 face at the corresponding index. The wrapper is an I/O adapter, not another reserve or a valuation asset. |

E4-E8 explain the baseline functions. They are not new-family law and do not reinstate the baseline's superseded SY, raw-ETH, paired-selector, or reserve-query requirements.

## Assumptions

- **Recommendation criterion:** keep a distinct public query when it exposes relevant information that accepted standard queries do not provide; avoid a second query when the accepted interface already supplies the caller's required result.
- **Inference from E2 and E5:** refund accounting and share-credit attribution are separate dimensions. The owner-accepted refund ABI does not itself decide whether a post-swap residual is kept, refunded, or converted. This contribution does not make that economic decision.
- **Inference from E3 and E7:** a withdrawing caller primarily needs the requested assets and enforceable minimum receipts. No admitted evidence identifies an integration that must branch on a maintenance-reason enum.
- **Scope assumption from E1 and E3:** the native leg can be identified from the retained PoolKey information, and the accepted `vaultTokens()` ordering associates that leg with its ERC-20 face. No global wrapper registry or extra public getter is assumed.

## Coverage

| Target/input | Coverage |
| --- | --- |
| Five named functions | All five receive an explicit decision below. |
| Function-review file | Examined in full; not edited. |
| Refund/bundle report | Examined the owner lock and accepted interface declarations only as substantive evidence. Older proposals do not override the lock. |
| Paired-money report | Examined in full, including the owner-accepted mappings and raw-ETH limitation. |
| Current declarations | Examined S1-API-05 of the admitted stage-one PRD. The alternative PairToken interface was not opened. |
| Optional baseline explanation | Examined the relevant credit, operation, cap, maintenance, native-face, and preview sections. This was not a complete audit of that PRD or its implementation. |
| Peers, new-family PRD, implementation, and external sources | Not examined. No external research was needed to compare the admitted declarations and owner locks. |

## Conclusions

These are **recommendations**, not locked decisions.

| Function | Recommendation | Destination or retained purpose |
| --- | --- | --- |
| `previewZapCredit(tokenIn, amountIn)` | **KEEP** | Retain a diagnostic query for shares, per-currency credited principal, and per-currency uncredited residual. |
| `previewWithdrawalMode(shares, paired, tokenOut)` | **MAP** | Use `previewExchangeBundleOut` for paired payout quotes and `previewExchangeIn` for existing scalar share-to-token payout quotes. Drop the dedicated mode selector. |
| `maxZapBps()` | **KEEP** | Expose the configured entry-size and compound-swap-size parameter. |
| `maxZapTickMove()` | **KEEP** | Expose the configured entry-swap tick-movement parameter. |
| `wrappedNative()` | **MAP** | Use `vaultTokens()` for the accepted ERC-20 face, associated with the native leg through the retained PoolKey information. Drop the standalone getter. |

### 1. `previewZapCredit`: keep

The scalar standard preview answers how many shares are quoted and how much of the supplied input token is returned. It does **not** answer how much of each pool currency generated those shares after the entry swap. The refund return therefore does **not** replace the per-currency credit split. Nor does a zero refund prove that every retained unit received share credit. E2 and E5 establish the distinction.

Retain this as a read-only explanation of the same entry plan, not a second money route or an independent quote algorithm. Its quoted shares should agree with `previewExchangeIn(tokenIn, amountIn, share)` at the same state. Keep the standard preview authoritative for the scalar same-input-token refund; do not rename `uncredited0` or `uncredited1` to refunds or infer that those two amounts will be paid.

The reason to retain the query is especially concrete under the baseline: booked residual can contribute value without minting extra shares. Removing the diagnostic would conceal that distinction behind a single share-output number. This recommendation preserves visibility without importing the baseline residual policy into the new family. Restrict supported input forms to the accepted family routes; keeping this query does not restore SY or raw-ETH input. **Basis: E1, E2, E4, E5; recommendation and inference.**

### 2. `previewWithdrawalMode`: map

For a paired withdrawal, use `previewExchangeBundleOut(share, shares, tokensOut)` with both ERC-20 faces. Its `amountsOut` is the relevant quote, and its `amountRefunded` refers to unkept input shares, not an underlying-token credit split. For an existing single-token withdrawal route, use `previewExchangeIn(share, shares, tokenOut)`. Do not assume that the generic bundle interface's possible one-element output list authorizes a new family route.

**Neither mapped function returns `WithdrawalMode` or `MaintenanceReason`.** This mapping intentionally removes pre-execution maintenance diagnostics; it is not a lossless ABI replacement. `previewExchangeBundleOut` is enough for the paired caller's payout question, but not for a caller asking which maintenance branch ran.

The admitted material identifies no caller control over that branch and no consumer requiring the reason enum. Keep the branch inside the shared economic plan and reflect its effects in the payout preview rather than making integrators issue another planning call. Dropping the getter does not drop a retained collection-only fallback, alter its predicates, or remove execution signals. Any existing maintenance-event requirement is outside this selector-removal recommendation. **Basis: E2, E3, E4, E7; recommendation and inference.**

### 3. `maxZapBps`: keep

This is configuration disclosure, not a deposit route. The accepted standard previews quote particular calls; they do not return this parameter. Retain the getter so a caller can inspect the configured size policy without treating one successful or failed quote as discovery of that policy.

Document both uses distinctly: in the admitted baseline, entry is bounded against the input reserve, while compounding uses a different reserve estimate and a quarter-sized cap. The getter alone is not a maximum executable deposit amount; initialization, reserves, rounding, and the rest of the execution plan still matter. Keeping it neither changes the cap nor proves manipulation resistance. Conversely, dropping a getter would not authorize dropping enforcement. **Basis: E4 and E6; recommendation and inference.**

### 4. `maxZapTickMove`: keep

This getter exposes a separate configured bound that neither standard preview returns. Keep it alongside `maxZapBps`, with an explicit entry-swap-only meaning. Do not describe it as a bound on compounding, every price movement in the operation, execution versus an external price, or the caller's final share slippage.

The standard preview remains necessary to know whether a particular complete operation fits all constraints. Removing a public getter and removing the enforced tick cap are different decisions; this recommendation does neither. **Basis: E4 and E6; recommendation and inference.**

### 5. `wrappedNative`: map

For accepted calls, the caller needs the ERC-20 address it may pass, and `vaultTokens()` already supplies it. For a native leg, associate the native currency in the retained PoolKey information with the same index in the stable token list. Use that face in bundle inputs and outputs; continue rejecting `address(0)` on those routes.

**`vaultTokens()` does not return a separately labeled wrapper address, the raw PoolKey, or a boolean identifying a native leg.** The PoolKey association supplies the missing identity distinction. A wrapped-native token that is itself an ordinary ERC-20 pool currency must not be mistaken for a raw-native leg merely because of its address.

Recommend that the standalone getter is unnecessary on this family; do **not** move an otherwise redundant public `wrappedNative()` selector to the Position Repo merely to preserve it. This recommendation removes duplicate public discovery, not the wrapper binding or state needed for correct native settlement. It does not select that internal storage layout. **Basis: E1, E3, E8; recommendation and inference.**

## Limits

This contribution neither locks the PRD nor authorizes implementation. Only the assigned response file is authored. No project code, PRD, function-review file, peer artifact, or configuration is changed; no sub-agents, tests, builds, installs, Git operations, wallets, or deployments are used.

The evidence is local document text read during this run, not an atomic repository snapshot or proof of deployed behavior. Actual Native identity fields remain not exposed. The conclusions deliberately distinguish an interface mapping from preservation of every diagnostic return and distinguish removing a getter from removing its underlying behavior.
