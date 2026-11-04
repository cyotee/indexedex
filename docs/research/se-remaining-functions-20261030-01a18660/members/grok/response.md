# Grok member response

## Identity

- Run ID: se-remaining-functions-20261030-01a18660
- Member label: grok
- Profile: research
- Phase: initial independent response
- Owned path: docs/research/se-remaining-functions-20261030-01a18660/members/grok/response.md
- Requested role: Grok member of the research council
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: not exposed
- Peers read before submission: no

The member label is the caller's assignment. It is not a model identity inferred from this prose. Native did not expose the runtime role, model, reasoning setting, task ID, or session ID on this assignment. This self-description is not proof of the runtime model.

## Question and targets

- Question: For each remaining open full-spread function, should this family keep it, drop it, or map it onto an accepted standard function?
- Required targets:
  - `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`
  - `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md`, owner lock and accepted interfaces only
  - `docs/research/se-paired-money-necessity-20261030-01a18660/REPORT.md`
  - The current declarations of `previewZapCredit`, `previewWithdrawalMode`, `maxZapBps`, and `maxZapTickMove` in the PairToken interface or stage-one PRD
- Optional context: `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`, for what the zap functions do. Not new-family law.
- Admitted read scope: the brief at `docs/research/se-remaining-functions-20261030-01a18660/brief.md`, the required targets above, and the optional stage-one PRD. Peers were not read. The full-spread PRD was not read. Implementation bodies were not read.

The five functions, as the brief names them, are `previewZapCredit`, `previewWithdrawalMode`, `maxZapBps`, `maxZapTickMove`, and `wrappedNative`.

## Evidence

Public search: not used. No source excerpt was sent to a search service.

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| Five functions still unmarked | `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`, Zap accounting and Pool and position identity | source observation | `previewZapCredit(tokenIn, amountIn)` returns the shares a single-token deposit would mint, how much of each currency funds those shares, and how much is left uncredited. `previewWithdrawalMode(shares, paired, tokenOut)` says whether a withdrawal would fully compound or only collect fees, and why. `maxZapBps()` is the configured cap on how large a single-token deposit or compound swap may be. `maxZapTickMove()` is the configured cap on how far that entry swap may move the pool's tick. `wrappedNative()` is the wrapper used when a standard nonpayable call has to represent ETH, and is marked Open. |
| Already locked, not reopened | Same review file; brief owner question | source observation | No `rateAsset`, no `getRate`, no ERC-5115. `depositPair` and `redeemPair` are not kept; they map to `exchangeBundleInForSingleOut` and `exchangeBundleOut`. `previewDepositPair` and `previewRedeemPair` map to the matching previews. `donate` and `compound` stay. `vaultTokens()` is reused from `MultiAssetBasicVaultFacet` and is not reimplemented. `poolKey` information stays, but not as a full-spread-only query; it belongs to a Uniswap V4 Position Repo, and native ETH stays `address(0)` there. `poolManager` is not a family query. |
| Owner lock on exact-in returns | `se-interface-refund-bundle-20261030-01a18660/REPORT.md`, Owner lock, revision `se-interface-refund-bundle-20261030-01a18660-final` | source observation | The owner put the refund return on the existing `previewExchangeIn` and `exchangeIn`. Parameters and selectors do not change. `previewExchangeIn(address,uint256,address)` remains `0x89d61912`. Both return `(uint256 amountOut, uint256 amountRefunded)`. `WithRefund` names are not accepted. The bundle interfaces in that report are accepted. `exchangeOut` does not gain a refund return. The council text below the lock is preserved and overridden where they conflict. |
| Accepted route identity | Same report, Question and Answer, as constrained by the owner lock | source observation | Swaps, deposits, and withdrawals use one family. Underlying for the share is a deposit. Share for a named set of underlyings is a withdrawal. The share may be `tokenIn` or `tokenOut` even when it is absent from `vaultTokens()`. |
| Refund is not a per-currency split | Same report, Refund rule and `IStandardExchangeIn` notice | source observation | Declared amount equals amount consumed plus amount refunded. There is no third bucket inside the declaration. `amountRefunded` is quoted unkept `tokenIn`. It is not a balance read. Refunded wei are not credited as a deposit. The functions are not payable. The caller passes the wrapped ERC-20 face. They do not accept `address(0)` and do not wrap it. `address(0)` reverts `TokenNotExchangeable`. |
| Bundle previews | Same report, accepted `IStandardExchangeBundleInForSingleOut` and `IStandardExchangeBundleOut` | source observation | `previewExchangeBundleInForSingleOut(uint256[],address)` returns `(uint256 amountOut, uint256[] amountsRefunded)`. `previewExchangeBundleOut(address,uint256,address[])` returns `(uint256[] amountsOut, uint256 amountRefunded)`. Bundle-in amounts use `vaultTokens()` order. `vaultTokens` is unchanged. |
| Paired previews already mapped | `se-paired-money-necessity-20261030-01a18660/REPORT.md`, revision `se-paired-money-necessity-20261030-01a18660-final` | source observation | The owner accepted the recommendation. The standard previews cover the quotes, so the paired preview selectors are not also required. `vaultTokens()` order must stay stable, with the wrapped face at a native leg's index. `address(0)` is not a bundle input. Accepted bundle functions do not take or pay raw ETH. That is not a reason to keep the old selectors, and it is not authority to extend the standard. |
| Current vault-interface declarations | `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol` | source observation | `wrappedNative()` returns `address` (line 267). Notice: package-bound canonical one-to-one native wrapper. `maxZapBps()` returns `uint16` (line 316). Notice: configured zap size limit, also used by the compound quarter-cap. `maxZapTickMove()` returns `int24` (line 323). Notice: nonnegative maximum tick movement around the caller's entry swap only. `previewWithdrawalMode(uint256,bool,address)` returns `(WithdrawalMode, MaintenanceReason)` (line 331). Dev comment: paired requires `tokenOut == address(0)`; otherwise zero means raw ETH output. `previewZapCredit(address,uint256)` returns `(shares, credit0, credit1, uncredited0, uncredited1)` (line 341). Notice: project share credit and residual donations for a supported SY input form. |
| Mode enums | Same interface, lines 16-29 | source observation | `WithdrawalMode` is `FullCompound` or `CollectOnly`. `MaintenanceReason` is `None`, `MaintenanceWorkLimit`, `MaintenancePriceLimit`, `MaintenanceLiquidityLimit`, or `MaintenanceDeltaLimit`. |
| Baseline factory caps | `contracts/pairtoken-baseline/interfaces/IPairTokenDependencies.sol`, `IPairTokenFactory` | source observation | The baseline factory, not the token, declares `maxZapBps() returns (uint16)` and `maxZapTickMove() returns (int24)`. This is baseline placement, not new-family law. |
| Stage-one zap meaning | `PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`, S1-OP-02, S1-ACC-07, S1-API-05. Revision: Owner-approved bounded-execution amendment, 2026-10-29. Optional. Not new-family law. | source observation | A zap swaps `floor(received / 2)`, checks the tick move around that swap only, mints against `G_i`, and books leftover `J_i` with no extra shares. The text calls that the no-refund residual policy and says previews must expose the uncredited remainder. `previewZapCredit` is not an additional deposit route. It accepts SY input forms. |
| Stage-one withdrawal mode | Same PRD, S1-EXIT-01 and S1-API-05. Not new-family law. | source observation | `CollectOnly` is selected only by a view plan before manager mutation, and only for listed maintenance obstacles. There is no user flag to bypass a valid full-compound plan. The paired mode query uses `tokenOut == address(0)` as a sentinel. |
| Stage-one caps and wrapper | Same PRD, S1-ARCH-03, S1-OP-05, S1-NATIVE-01. Not new-family law. | source observation | `maxZapBps` and `maxZapTickMove` are instance arguments. The text says not to invent defaults. `maxZapBps` controls entry size and the compound quarter-cap. `maxZapTickMove` governs only entry swaps. Native currency stays `address(0)` in the pool key. The nonpayable face is `wrappedNative` when that leg is native. Stage one says to expose the wrapper on the family query interface. |
| Brief constraints | `docs/research/se-remaining-functions-20261030-01a18660/brief.md` | coordinator-supplied | Each function is keep, drop, or map. A map must name the accepted function and what it does not return. The refund return must be compared with the credit split. The withdrawal mode must be compared with `previewExchangeBundleOut`. Dropping the cap getters is not dropping the caps. `wrappedNative` must be placed on this family, on the Position Repo, or called unnecessary because `vaultTokens()` exposes the face. This recommendation does not authorize implementation and does not lock the PRD. |
| Unopened search hits | Workspace search for the five names | unverified | The search also named the full-spread PRD, pair-token implementation targets, and stage-one execution evidence. Those files were not opened. Their matching lines are not observations in this response. |

## Assumptions

- The owner locks in the two reports, and the locked rows in the review file, govern this family. The stage-one PRD explains the old functions. It is not new-family law, and its "must expose" sentences are not adopted here.
- A single-token deposit quote is `previewExchangeIn` with `tokenOut` equal to the share. That is inferred from the accepted route-by-identity rule. No owner sentence names `previewZapCredit` in that lock.
- Map means do not keep the old selector. The named accepted function is the caller-facing replacement. Drop means do not keep the selector and do not pretend an accepted function returns the same result.
- Accepted functions used below are the owner-locked `previewExchangeIn` and `previewExchangeBundleOut`, plus the locked reuse of `vaultTokens()`. Stage-one-only selectors are not accepted replacements.
- No independent pricing source is assumed. The tick cap is not treated as proof against manipulation.
- Live files were read in this run. No content hash was taken. A later edit would not be detected here.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md` | required | examined | Read the whole file. The five functions are unmarked. Locked rows were not reopened. |
| `se-interface-refund-bundle-20261030-01a18660/REPORT.md` | required | examined | Read the whole report. Conclusions use the owner lock and the accepted interfaces. The council answer under the lock is overridden where it conflicts, including its "do not edit `exchangeIn`" sentence. |
| `se-paired-money-necessity-20261030-01a18660/REPORT.md` | required | examined | Read the whole report, including the owner lock. |
| Current declarations of the four zap functions | required | examined | Read in `IUniswapV4PairTokenStandardExchangeVault.sol` and in stage-one S1-API-05. `wrappedNative` is declared beside them in both places. |
| `PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md` | optional | partially examined | Read S1-ARCH-03, the zap credit and residual text, S1-OP-02, S1-OP-05's cap use, S1-EXIT-01, S1-NATIVE-01, and S1-API-05. Did not read the rest of the 1272-line file. Not used as new-family law. |
| `IPairTokenDependencies.sol` factory getters | not required | examined | Opened while locating cap declarations. Used only as baseline placement. |
| Full-spread PRD, implementation bodies, peers | not admitted | not examined | Not opened. Implementation behavior of the old targets is unverified. |
| Public web | not required | not examined | Not used. |

## Conclusions

Agreement is not available. Peers were not read. These are recommendations. They do not lock the PRD and do not authorize implementation.

The refund return does not replace the per-currency credit split. A caller does not need the compound-or-collect choice. Dropping the two cap getters does not drop the caps. `wrappedNative()` does not stay on this family and does not move to the Position Repo.

### `previewZapCredit` — map

Recommendation: map. Do not keep the selector. Map it onto `previewExchangeIn(tokenIn, amountIn, share)`.

`amountOut` is the quoted shares only when the caller passes the share as `tokenOut`. `amountRefunded` is unkept input of that same `tokenIn`. That is the caller-facing quote of a single-token deposit under the locked route rule: underlying for the share is a deposit, and declared input is consumed plus refunded.

`previewExchangeIn` does not return `credit0`, `credit1`, `uncredited0`, or `uncredited1`. It does not say how much of each currency funds the minted shares. It does not say how much of each currency was left uncredited.

That missing split is not a silent substitution. The refund word does not replace it. The split is a different result: post-swap attribution across both currencies, including value the stage-one zap books and does not give back. The locked refund rule has no third bucket. Unkept input is `amountRefunded` of the token the user provided. Booked uncredited residual in both currencies is that third bucket, and it is the stage-one no-refund residual policy. This family has not locked that policy. ERC-5115 is locked out, and the current notice on `previewZapCredit` is an SY input projection. Keeping the selector would keep a second deposit quote that can disagree with `previewExchangeIn`, which is the reason the paired previews were not kept.

What would reverse this recommendation: an owner decision to retain booked uncredited residual as economics. That decision is not in the admitted locks. This response does not make it. Until it exists, the split is not a return this family should publish.

### `previewWithdrawalMode` — drop

Recommendation: drop. Do not map it.

A caller does not need the compound-or-collect choice. It is not a caller input. The stage-one text, which is not new-family law, says there is no user flag to bypass a valid full-compound plan. The choice is an internal planner branch with a reason enum.

`previewExchangeBundleOut` is enough for the withdrawal quote. For a paired exit, `tokenIn` is the share and `tokensOut` are the two ERC-20 faces, which is the already locked map of `previewRedeemPair`. It returns `amountsOut` and `amountRefunded`. It does not return `WithdrawalMode` or `MaintenanceReason`. That gap is acceptable because the caller needs the amounts, not the branch name. Slippage binds to `minAmountsOut`. The amount quote already has to use whichever internal branch the implementation selected. Naming the branch would publish a fallback policy this family has not locked. Sleeve use while the PoolManager is locked is explicitly unspecified in the review file.

This is not a map onto `previewExchangeBundleOut`, because that function does not answer the question this selector asks. `compound()` stays. Dropping this query does not drop `compound()`, and it does not specify an internal fallback.

The current declaration also does not fit the locked surface. Its dev comment requires `tokenOut == address(0)` for the paired query, and otherwise treats zero as raw ETH output. Accepted routes reject `address(0)`. Raw ETH is not decided, and the paired-money lock says that absence is not a reason to keep an old selector.

### `maxZapBps` — drop

Recommendation: drop the getter. Do not map it. No accepted function returns this cap.

Dropping the getter is not dropping the cap. The cap is configuration, not a route. Recommend that a size bound on a single-token entry swap remain internal enforcement. This response does not adopt the stage-one formula, and it does not adopt the compound quarter-cap, as new-family law. `compound()` stays as its own function. Whether that function uses this cap is a separate enforcement choice. Removing the bound would also be a separate decision. It does not follow from dropping the getter.

The caller does not need the raw `uint16` to use the route. `previewExchangeIn` returns the quoted shares and the unkept `tokenIn` for a stated `amountIn`. The cost of the drop is that an integrator cannot read the policy number except through that quote, or through a revert. That cost does not justify a family getter whose notice also freezes the unadopted quarter-cap meaning.

### `maxZapTickMove` — drop

Recommendation: drop the getter. Do not map it. No accepted function returns this cap.

Dropping the getter is not dropping the cap. Recommend that a bound on how far the entry swap may move the pool tick remain internal enforcement. The current notice limits that bound to the caller's entry swap. This response does not adopt the stage-one predicate as new-family law, and it does not claim the bound is manipulation protection. There is no independent pricing source in the admitted locks.

A caller cannot apply the raw `int24` without simulating the swap. The entry quote is the surface that shows whether the stated input can be consumed. Publishing the configured distance would not tell the caller the outcome, and it would look like a guarantee the stage-one text itself refuses. The cap can remain without the getter.

### `wrappedNative` — drop

Recommendation: drop. It does not stay on this family. It does not move to the Position Repo. It is unnecessary because `vaultTokens()` already exposes the face the accepted routes require.

This is not a map onto `vaultTokens()`. `vaultTokens()` does not return one identified wrapper address. It does not say which index is the native stand-in. What it does return, under the paired-money lock, is the stable token list with the wrapped face at a native leg's index. Accepted routes are nonpayable, reject `address(0)`, and require that face. A caller passes `vaultTokens()` entries. They do not pass `wrappedNative()`.

The Position Repo is the wrong home. The locked repo holds position-in-pool state: the pool key, where native ETH stays `address(0)`, the ticks, and position liquidity. The wrapper is not position state. It is the translation from that `address(0)` leg to the ERC-20 face. That translation is already the locked `vaultTokens()` index rule. Putting the wrapper on the repo would duplicate the face and couple position storage to a chain wrapper. Protocol Aware was locked for protocol components such as the PoolManager. The wrapper is not one of those. This response does not invent a fourth home.

A second getter can disagree with `vaultTokens()`. That is the same reason a second paired entry was not kept. The getter's extra fact, the canonical wrapper even when it is not a vault face, is unused by the accepted routes. Raw ETH is not decided. Naming the wrapper does not move raw ETH, and the paired-money lock says the missing raw-ETH path is not a reason to keep a selector.

## Limits

- Runtime or extraction proof: none. No tests, builds, installs, wallets, deployment, or Git operations were run. Static reads are not execution proof. No content hash was taken. Live files can change. This is not an atomic snapshot.
- Public search: not used.
- Not examined: the full-spread PRD, pair-token implementation bodies, stage-one sections outside the list in Coverage, peer responses, and whether package init stores the wrapper without a getter. Old-target runtime behavior is unverified.
- Native identity: not exposed. The brief's shared-workspace, `isolated: false` statement is coordinator-supplied. This file does not prove confinement.
- The stage-one PRD was used only to see what the old functions do. Its exposure requirements, formulas, and SY input forms are not adopted.
- The map for `previewZapCredit` holds only while booked uncredited residual is not an owner-locked economic output. This response does not create that lock.
- Dropping `maxZapBps` and `maxZapTickMove` does not drop, adopt, or resize those caps. Cap formulas remain undecided.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path. It does not lock the PRD or the function-review file.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
