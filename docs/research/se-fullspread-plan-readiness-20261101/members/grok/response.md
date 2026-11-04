# Member response

## Identity

- Run ID: se-fullspread-plan-readiness-20261101
- Member label: grok
- Profile: research
- Phase: initial independent response
- Owned path: docs/research/se-fullspread-plan-readiness-20261101/members/grok/response.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

- Question: Are the locked full-spread vault requirements complete enough to write an implementation and testing plan now, without leaving a product decision to the plan author or the implementor?
- Required targets: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`; `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md`; `docs/security/audit/second_review/REMEDIATION_TRACKER.md`
- Optional context: `test/foundry/spec/hooks/uniswap/v4/standardExchange/`; `docs/audits/apex-2026-09-17-open-item-1-hook-se-matrix-PRD.md`; `contracts/protocols/strategy/weir/WeirVaults.sol`; matrix evidence those documents cite
- Admitted read scope: the required targets, that optional context, and repository files those documents cite for the integration matrix and for an audit finding's mechanism. Peer responses, the draft, and other member files were not read. Public query: not used.

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| PRD revision and override rule | `UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` lines 1-3 and section 1.4 | source observation | Revision `fullspread-se-prd-weir-align-r1`. FS-OWN-01 through FS-OWN-10 override a conflicting sentence. Section 1.4 says the 2026-11-01 answers override every conflicting sentence in the file, including the raw-ETH sentence in FS-OWN-09 and the phrase "outside the inherited domain." |
| Query facet still open | PRD FS-FACET-01 `queryFacet` row; following paragraph | source observation | "`queryFacet` | Still under function review." The next paragraph says: "The old 61-selector count included `getRate` and is not the manifest. Recount from the current package after the function review closes." |
| Aware package input still open | PRD FS-PKG-01 | source observation | "`PkgInit.poolManager` stays" is later locked by FS-OWN-16, but FS-PKG-01 still says: "FS-OWN-01 does not yet say whether that field stays or the aware facet becomes a package input." |
| Wrapped-native storage undecided | PRD FS-OWN-10 and FS-OWN-17 | source observation | FS-OWN-10: "This lock does not remove a package address binding, does not decide where that binding is stored." FS-OWN-17: "The wrapper is the network `WETH` constant, `WETH9` on Robinhood." `PkgInit` still has a `wrappedNative` field, and FS-PKG-02 still rejects an incompatible wrapper with `InvalidWrappedNative`. |
| Aware directory empty | `lib/crane/contracts/protocols/dexes/uniswap/v4/aware` | source observation | The directory exists and contains no files. No Position Repo directory was present under `lib/crane/contracts/protocols/dexes/uniswap/v4/`. PRD FS-ARCH-01 says neither file set is created by this PRD revision. |
| Compound sentences conflict | PRD FS-OWN-14 | source observation | "compound() deploys booked idle." Later in the same lock: "If there are no fees, return without a state change and without an event. Do not revert." |
| Sleeve move does not name a swap | PRD FS-OWN-12; function-review liquidity-sleeve section | source observation | Adjustment is best-effort, per token, only when local balance differs from target by more than 5% of target, and must not revert if inexact. Neither sentence says whether the move may swap. FS-OWN-25 authorizes an underlying swap only for `exchangeIn`, and forbids it for a bundle deposit. |
| View-revert conflict | PRD FS-A32 and FS-OWN-19 | source observation | FS-A32: "Busy-vault economic views revert. An idle vault answers while the manager is unlocked. Basic reserves return the last committed snapshot." FS-OWN-19: "No view reverts. Sleeve accounting uses the last committed local snapshot. The deployed term uses the live position amount and unpaid fees." "Busy" is not defined in the PRD. |
| Usage-fee base unnamed | PRD FS-OWN-24 | source observation | "When shares are minted, if `feeTo` is not `address(0)`, mint `mulDiv(sharesMinted, usageFeeOfVault(address(this)), 1e18)` additional shares to `feeTo`." `sharesMinted` is not defined against the `MIN_SHARES` floor. |
| Floor holder versus shared ERC-20 | PRD FS-OWN-11 and FS-FACET-01; `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol` lines 190-196 | source observation | FS-OWN-11 mints `MIN_SHARES` (`1_000`) to `address(0)` and counts that balance in `totalSupply()`. FS-FACET-01 keeps the shared `erc20Facet`. `ERC20Repo._increaseBalanceOf` reverts `ERC20InvalidReceiver` when `account == address(0)`. |
| Dilutive fee is the locked mint | Audit APEX-2026-044; PRD FS-OWN-24 | source observation | The finding says an additional `userShares * usageFee` mint to `feeTo` makes existing LPs pay the fee, and `setUsageFeeOfVault` accepts any value up to `1e18` immediately. FS-OWN-24 locks that additional mint. The PRD does not cap or delay `usageFeeOfVault`. |
| Live-spot maintenance is locked and unbounded | Audit APEX-2026-023; PRD FS-OWN-12, FS-OWN-14, FS-OWN-10, FS-MONEY-01 | source observation | 023 is maintenance that mints idle excess at a displaced `slot0` with no TWAP or pre-operation price check. FS-OWN-12 and FS-OWN-14 require a post-operation move of local balances and deployment of booked idle. FS-OWN-10 forbids a replacement tick bound or cap. FS-MONEY-01 sets the entry swap price limit at `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`. |
| Event names left open | `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md` paired-money section; PRD FS-OWN-09 | source observation | Function review: "`PairDeposited` and `PairRedeemed`, or renamed equivalents, are still emitted by the mapped routes." PRD: "Paired events survive the selector drop." No argument list is given. |
| Decimal scaling unnamed | PRD FS-OWN-27 and FS-MONEY-01 | source observation | FS-OWN-27: "Scale and unscale internal amounts to each underlying token's decimals." FS-MONEY-01 issues shares from liquidity: `frame.shares = (uint256(frame.liq) * v.totalShares) / v.liquidity`. It does not say that a decimal scale enters that formula. Section 1.4 says later locks override conflicting sentences. |
| Two libraries have no behavior | PRD FS-PKG-01 and FS-ARCH-01 | source observation | `linkedLibraries` is `address[6]` for Math, Projection, SwapProjection, Planner, Execution, and ExecutionPreparation. The production file list names Math, Projection, Planner, and Execution only. PairToken economics are not inherited. |
| Weir does not close the open money choices | `contracts/protocols/strategy/weir/WeirVaults.sol` `_deposit`, `_withdraw`, `_compound`, `_balance`, `_swap` | source observation | `_balance` swaps half the excess value. `_withdraw` zaps only the withdrawn net, at the same min/max price limit. `_compound` still reinvests idle when fees are zero and emits only if fees are positive. Weir has no sleeve target, no usage-fee mint, and no ERC-20 floor at `address(0)`. |
| Matrix law | `docs/audits/apex-2026-09-17-open-item-1-hook-se-matrix-PRD.md` | source observation | M5: one behavior contract per hook family and one thin file per SE family. M6: one fixture adapter per SE family. Evidence to update includes `hook-se-matrix.json`, `docs/audits/apex-2026-09-17-evidence.md`, and `acceptance.json` R10.3. |
| Live matrix grid | `test/foundry/spec/hooks/uniswap/v4/standardExchange/` | source observation | Seven hook families each have a `*_SeMatrixBehavior.sol` and 20 non-decimal `*_SeMatrix_*.t.sol` rows. The V3 full-spread column exists. No live file name contains `UniswapV4FullSpread`. Decimals rows exist only for AaveCrossVersionLoop, AaveV3Stata, ERC4626, and SimpleYield. |
| Stale V4 matrix evidence | `docs/audits/apex-2026-09-17-evidence/hook-se-matrix.json` | source observation | `seFamily` `UniswapV4FullSpreadStandardExchangeVault` has 7 rows, all `COMPATIBLE`, one per hook. The cited dual file `dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` is absent. No `SeMatrix_FullSpreadV4Fixture.sol` or `SeMatrix_UniswapV4FullSpreadFixture.sol` exists. `hook-se-matrix-findings.json` still has V4 full-spread keys. |
| Second-audit inventory | `IndexedEx_DiffReview_aca16198-2ba07631.md` summary and section 2 | source observation | 45 findings, APEX-2026-010 through APEX-2026-054 with no numeric gap. Section 3 also restates prior IDs 001, 001-M, 001-M2, 003, 004/004B, 005, 006, 007, 008, 009, DEAD-PRETRANSFER, and Balancer router R1/R2. |
| Retirement does not answer the new vault | `REMEDIATION_TRACKER.md` APEX-2026-011 section | source observation | Deletion of the old V4 FullSpread trees is recorded as closing 011, 041, 042, and 051 in that deleted source. The tracker says V3 FullSpread and the Wings findings stay open, and deleting source does not change deployed contracts. The new PRD rebuilds a V4 full-spread vault. |
| R10.3 still partial | `docs/audits/apex-2026-09-17-evidence.md` | source observation | The matrix program is recorded there. It says R10.3 stays PARTIAL on the 42 M13 deferrals. The criterion body inside `acceptance.json` was not extracted. |
| Public query | none | source observation | not used |

## Assumptions

- Later owner locks override earlier conflicting sentences in the PRD and the function-review file. A stale sentence is not a blocking decision when a later lock states the replacement. That rule closes caller-facing ETH, the "outside the inherited domain" pool check, and the earlier "underlying donate stays idle" bullet. It does not close a lock that conflicts with itself, with another lock, or with a required shared facet.
- Cited economics reports named by the PRD are part of the lock where the PRD incorporates them. This pass did not re-read those reports. No blocker below depends on reopening them.
- "Cannot apply" means the finding's affected code and mechanism are not a surface this vault installs, and the locked PRD does not tell an implementor to recreate that surface. Naming an older vault is not, by itself, a reason to omit the ID.
- The plan may read the cited Standard Exchange interface report for parameter lists. That is not treated as an open product choice.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| `UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` | required | examined | Full file, 452 lines. |
| `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md` | required | examined | Full file, 108 lines. |
| `IndexedEx_DiffReview_aca16198-2ba07631.md` | required | examined | Summary, index, section 3, and each of the 45 write-ups. PoC command blocks were not re-executed. |
| `REMEDIATION_TRACKER.md` | required | examined | Full file, 465 lines. |
| Hook × SE matrix tests and `hook-se-matrix.json` | optional, cited for the matrix | examined | Directory inventory, one V3 thin row, V3 fixture header, JSON family counts, and absence of the JSON-cited V4 test file. |
| `docs/audits/apex-2026-09-17-open-item-1-hook-se-matrix-PRD.md` | optional | examined | Headings, locked decisions M1-M11, and the evidence-update sentence. Section 6 row bodies were taken from the live JSON test names, not re-derived from the PRD prose. |
| `WeirVaults.sol` | optional | examined | Deposit, withdraw, compound, balance, and swap functions. Admin surface was not used. |
| `docs/audits/apex-2026-09-17-evidence.md` | cited by the matrix PRD | partially examined | Matrix-program paragraphs and the R10.3 PARTIAL statement. Not a line-by-line read. |
| `acceptance.json` | cited by the matrix PRD | partially examined | File exists. R10.3 criterion body was not extracted. |
| `hook-se-matrix-findings.json` | current matrix evidence | partially examined | Keys include V4 full-spread rows. Values were not read. |
| `hook-se-matrix-finding-descriptions.json` | cited by the matrix evidence note | not examined | Not required to identify the live grid or the stale V4 rows. |
| `FullSpreadSameManagerAmmFixture.sol` | in the hook spec directory | partially examined | Header only. It is not the matrix column. Callers were not traced. |
| Peer responses, draft, other member files | forbidden | not examined | Initial pass. |

## Conclusions

The locked requirements are not complete enough. An author cannot write the implementation and testing plan now without choosing product behavior. The matrix files and the audit-test obligations can be named. Thirteen decisions cannot.

Agreement is not available. Peers were not read. This is not council consensus.

### Blocking decisions

Each question is the one owner answer that would close that decision. No answer is proposed.

1. Query facet and position getters. The PRD says `queryFacet` is "Still under function review" and "Recount from the current package after the function review closes." The function-review file locks behaviors for `localReserves`, `tickLower`, `tickUpper`, `positionLiquidity`, and `poolKey`, but it does not assign those selectors to a facet. FS-OWN-23 says the cut names installed selectors and then names only `vaultTokens`, `reserveOfToken`, and `reserves`. Owner question: Which selectors does `queryFacet` install, and which facet on this diamond exposes `localReserves()`, `tickLower()`, `tickUpper()`, `positionLiquidity()`, and `poolKey()`?

2. Protocol Aware facet, Position Repo, and the six non-PoolManager addresses. FS-PKG-01 says "FS-OWN-01 does not yet say whether that field stays or the aware facet becomes a package input." FS-OWN-16 closes only the `PkgInit.poolManager` field and the write of that one address. FS-OWN-18 says the repo stores PoolManager, Position Descriptor, Position Manager, Quoter, State View, Reserves Lens, and Universal Router, and that on Robinhood those are the constants in `ROBINHOOD_MAIN.sol`. It does not say when or from where the other six are written. FS-ARCH-01 says this PRD revision does not create either file set. The `v4/aware` directory is empty, and no Position Repo directory is present. Owner question: Are the Protocol Aware facet and the Position Repo facet package inputs on this diamond, and what exact value is written at initialization for Position Descriptor, Position Manager, Quoter, State View, Reserves Lens, and Universal Router?

3. Wrapped-native binding. FS-OWN-10 says the lock "does not decide where that binding is stored." FS-OWN-17 says the wrapper is the network `WETH` constant. `PkgInit` still carries `wrappedNative`, and FS-PKG-02 still rejects an incompatible wrapper. Owner question: Must `PkgInit.wrappedNative` equal the network `WETH` constant, and where is that binding stored if this family has no `wrappedNative()` getter?

4. `compound()` with no fees. FS-OWN-14 says both "compound() deploys booked idle" and "If there are no fees, return without a state change and without an event." Weir's `_compound` reinvests idle when fees are zero, but section 1.4 overrides Weir where they conflict, and the two sentences in FS-OWN-14 conflict with each other. Owner question: When `compound()` finds no fees and booked idle differs from the sleeve target, does it return with no state change, or does it still deploy booked idle and run the sleeve adjustment?

5. Sleeve-adjustment swap. FS-OWN-12 requires a per-token move toward the target when the difference exceeds 5% of target, and it must not revert if the move is inexact. It does not say whether that move may swap. FS-OWN-25 authorizes a pool swap for `exchangeIn` only. Owner question: When one token is above the sleeve target and the other is not, may sleeve adjustment swap through the pool, or may it only add or remove liquidity in the current pool ratio?

6. Busy views. FS-A32 says busy-vault economic views revert, while an idle vault answers during an unlock, and basic reserves return the last committed snapshot. FS-OWN-19 says "No view reverts" and that the deployed term is live. Section 1.4 makes the later lock override a conflicting sentence, but it does not say whether "No view reverts" covers every view or only `reserveOfToken` and `reserves`. "Busy" is not defined. Owner question: Does FS-OWN-19 withdraw FS-A32's busy-vault revert for every view, or only for reserve views? If any view still reverts while busy, which views, and what does busy mean?

7. Usage-fee base. FS-OWN-24 mints `mulDiv(sharesMinted, usageFeeOfVault(address(this)), 1e18)` additional shares to `feeTo` when shares are minted and `feeTo` is not zero. It does not say whether `sharesMinted` includes the `MIN_SHARES` floor, only the depositor's credit, or the fee shares themselves. Owner question: Is `sharesMinted` only the shares credited to the depositor, and are the `MIN_SHARES` floor and the fee shares excluded from that base?

8. Floor holder versus the shared ERC-20. FS-OWN-11 requires the 1,000-share floor to be minted to `address(0)` and included in `totalSupply()`. FS-FACET-01 requires the shared `erc20Facet`. `ERC20Repo._increaseBalanceOf` reverts `ERC20InvalidReceiver` for `address(0)`. The PRD does not say which sentence wins. Owner question: Which holder, or which mint path, satisfies both FS-OWN-11 and the shared ERC-20 facet?

9. APEX-2026-044 versus FS-OWN-24. The finding's vault-side mechanism is the additional dilutive mint to `feeTo`. FS-OWN-24 locks that mint. The owner also required the plan to test that second-audit vulnerabilities are not present in this vault. The instant 100% setter is the fee oracle, which this PRD does not install; the open choice is the vault mint. Owner question: Is the FS-OWN-24 additional mint to `feeTo` an accepted exception to APEX-2026-044, or must this vault not mint that dilutive fee?

10. APEX-2026-023 versus live-spot sleeve and compound. The finding is permissionless maintenance that adds liquidity at a displaced spot, with no TWAP or pre-operation price check. FS-OWN-12 and FS-OWN-14 require that maintenance. FS-OWN-10 forbids adding a tick bound or cap. The owner also required a test that this vulnerability is not present. Owner question: Is deploying sleeve and compound liquidity at the live pool price, with no TWAP or tick guard, an accepted exception to APEX-2026-023, or must the plan add a price guard that FS-OWN-10 currently forbids?

11. Paired event ABI. The function review says "`PairDeposited` and `PairRedeemed`, or renamed equivalents, are still emitted." The PRD says only "Paired events survive the selector drop." Owner question: What are the exact event names and argument lists emitted by the mapped bundle deposit and redeem routes?

12. Decimal scaling. FS-OWN-27 says "Scale and unscale internal amounts to each underlying token's decimals." FS-MONEY-01's share formula is in liquidity units. A later lock overrides a conflicting sentence, but FS-OWN-27 does not name the amounts. Owner question: Which amounts are scaled to token decimals, and does any scaled amount enter `frame.shares = liq * totalShares / liquidity`?

13. `SwapProjection` and `ExecutionPreparation`. FS-PKG-01 requires both in `linkedLibraries`. FS-ARCH-01 does not name their files and forbids inheriting PairToken economics. Owner question: What do `SwapProjection` and `ExecutionPreparation` compute for this family, or are those two slots removed from `PkgInit`?

### Closed by a later lock, not a blocking decision

These stale sentences must not be treated as open choices. Section 1.4 and the third-pass function review override them.

- Callers send and receive WETH only. Native ETH is accepted only from the pool, wrapped before it enters the sleeve or is sent to a caller, and unwrapped only to deploy into a native pool. FS-OWN-17 overrides FS-OWN-09's raw-ETH sentence, FS-MONEY-01's "actual ETH payout," and FS-A10's caller-facing ETH payout.
- The pool-key check is only that the pool is initialized on the bound manager and the hook is `address(0)`. FS-OWN-22 deletes "outside the inherited domain."
- An underlying donation is deployed into the pool before `donate` returns. A share donation burns the shares and does not withdraw. The earlier "booked as local idle" bullet is overridden by the third pass and FS-OWN-21.
- `getRate` and `rateAsset` are not installed. A hook package that requires a provider is an FS-HOOK-04 record. The plan must not invent a provider or a rate policy to make a matrix row pass.
- FS-OWN-04's "refill, shortfall, and whether a locked caller may spend the sleeve are not specified" is overridden by FS-OWN-12, FS-OWN-13, FS-OWN-15, FS-OWN-30, and FS-OWN-31, except the swap question in blocking decision 5.
- One-sided entry swaps half the excess value, using Weir's `_balance` formula and the min/max price limit. One-token exit swaps the unwanted token from the caller's withdrawn fraction, not the vault's whole opposing balance. Those readings come from FS-OWN-33, FS-OWN-30, and the cited Weir functions. They are not open choices.

### Matrix files the plan should extend

The current integration matrix is the hook × SE grid under `test/foundry/spec/hooks/uniswap/v4/standardExchange/`, plus its evidence JSON. It is not the historical snapshots under `docs/audits/apex-2026-09-17-evidence/followup-review/`.

The plan extends these live behavior contracts. New thin rows inherit them. It must not edit their gold assertions for other SE families.

- `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol`

The pattern column is the existing V3 full-spread thin file in each of those seven directories, `*_SeMatrix_UniswapV3FullSpreadStandardExchangeVault.t.sol`, and `SeMatrix_FullSpreadV3Fixture.sol`. `SeMatrixFixture.sol` is the adapter base. Those V3 files are not files to retarget.

The evidence file to extend is `docs/audits/apex-2026-09-17-evidence/hook-se-matrix.json`. It already has seven `COMPATIBLE` rows for `UniswapV4FullSpreadStandardExchangeVault`, one per hook: balancer-quad, curve-quad, dual, orbital, single-cp, single-noncp, and weighted. Those cited test files are absent. The dual path was checked and is absent. A search of the live matrix tree found no `UniswapV4FullSpread` file. The JSON is stale and is not current proof. `hook-se-matrix-findings.json` still carries V4 full-spread keys and must be regenerated with the new rows, not kept as the mechanism record. `docs/audits/apex-2026-09-17-evidence.md` and `acceptance.json` R10.3 are the other evidence records the matrix PRD names. R10.3 is recorded as PARTIAL. The plan extends that record. It does not extend the followup-review JSON snapshots.

Do not add M14 decimals rows for this vault as if they were part of the current column. The JSON's V4 full-spread column has seven rows and no F6 or F9 combo. The V3 full-spread column also has no decimals matrix files. Decimals matrix files exist only for AaveCrossVersionLoop, AaveV3Stata, ERC4626, and SimpleYield.

The ten row controls named in the live JSON are the integration tests this column must meet, with two locked divergences the plan must not choose around:

- `test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly` and `test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed` cannot be gold successes. FS-HOOK-03 and FS-A28 say a hook path that calls `exchangeOut` on this vault reverts and pays neither token.
- `test_row_partialConsumption_bookedNotRefunded` is the wrong assertion for this vault. FS-OWN-32 refunds input that does not become liquidity. The shared gold body must not be inherited for that control.

The other named controls are `test_row_ammCallerFundSeparation`, `test_row_bind_deploysThroughPackage`, `test_row_bufferFirst_restingFace_notPaidToJoiner`, `test_row_hookSwap_exactIn_eoaPretransferRejected`, `test_row_poolManagerSwap_bothDirections_noFaceResidual`, `test_row_previewMatchesExecution`, and `test_row_seFailure_rollsBack`. A missing rate provider is an FS-HOOK-04 record, not a reason to invent `getRate`.

`UniswapV4FullSpreadStandardExchangeVaultBufferHookIntegration.t.sol` is a new file already named by FS-TEST-02. It is not a current file to extend. `FullSpreadSameManagerAmmFixture.sol` was not identified as a matrix file from the header that was read.

### Second-audit finding tests

The tracker records 011, 041, 042, and 051 as closed by deletion of the old V4 FullSpread trees. That deletion is not a reason to skip them. This PRD builds a new vault in that family. "Yes" means the plan must encode a test on this vault. "No" means the finding cannot apply, with the reason taken from the finding text and the locked PRD. No ID is omitted because it names an older vault.

Where a test is required but blocking decision 9 or 10 is open, the plan must not pick the expected result.

| ID | Encode a test on this vault? | Why |
| --- | --- | --- |
| APEX-2026-011 | Yes | High. V4 FullSpread blocked mode prices single-sided entry and zap exit differently, so a no-price-move loop over-mints. This plan replaces that family. FS-UNLOCK-01 uses one engine on both unlock paths. FS-MONEY-01 issues from liquidity. FS-OWN-30 and FS-OWN-31 are the payment rules. The test locks that a caller-forced unlock does not over-mint. |
| APEX-2026-012 | Yes | High. Wings prices deposit and redeem from a live liquidation quote that counts JIT liquidity. This vault is not Wings, but it does operate while the manager is unlocked, and an implementor could copy that quote. FS-MONEY-01 and FS-OWN-06 price and report this position's liquidity only. The test locks that another position's temporary liquidity is not this vault's inventory or share denominator. |
| APEX-2026-013 | Yes | High. Staking SEs cut generic `ERC4626Facet`, so `deposit(balance)` mints shares for free. This PRD forbids ERC-4626 and `asset()`. The test locks that those selectors are absent and that a raw token balance does not mint shares. |
| APEX-2026-014 | No | Medium. The defect is a V4 buffer hook paying a raw leg without dividing by that leg's rate. This vault is not that hook and installs no rate. FS-OWN-29 and FS-HOOK-04 forbid inventing a provider so a hook row can pass. |
| APEX-2026-015 | No | Medium. The Curve quad hook prices SE joins and exits on raw share counts and swaps on rated balances. That split is hook code. This vault has no rate to create it. |
| APEX-2026-016 | No | Medium. Weighted-hook `joinProportional` can seed an empty leg with dust. This vault has no hook join and no partial book. PRD section 1.1 is one pool and one position. |
| APEX-2026-017 | No | High. Balancer V3 buffer-hook `_preSeatShares` calls the caller-supplied router before it applies the share delta. This vault does not implement that hook, and FS-HOOK-01 does not include a Balancer pool hook. |
| APEX-2026-018 | No | High. Balancer `computeBalance` returns a math-domain balance and dust exits pay about `h`. This vault has no `computeBalance`. |
| APEX-2026-019 | No | High. The Balancer SE router exact-out permit path pulls `limit` and does not refund it. This vault has no router and no Permit2 pull of `limit`. `exchangeOut` reverts. |
| APEX-2026-020 | No | Medium. V4 DETF mint and bond are priced from the live reserve-hook book. This vault is not a DETF and has no `bond()`. |
| APEX-2026-021 | No | Medium. Balancer V3 DETF bond and mint read live reserve-pool spot and do not check `IVault.isUnlocked()`. This vault is not that DETF. Its own unlock dispatch is FS-UNLOCK-01, which is a different surface. |
| APEX-2026-022 | Yes | Medium. V3 FullSpread enters blocked mode from the pool's own swap callback, and zap-in plus zap-out becomes a fee-free spot swap paid from the sleeve. Do not skip it because it names V3. This vault also has a sleeve and an unlocked path. FS-OWN-30 pays the caller's fractions and says the sleeve is not a top-up. The test locks that a swap callback cannot produce that fee-free payout. |
| APEX-2026-023 | Yes, expected result blocked | Low. FullSpread maintenance mints idle at a displaced spot. FS-OWN-12 and FS-OWN-14 require that maintenance, and FS-OWN-10 forbids a tick guard. Encode the test only after blocking decision 10. |
| APEX-2026-024 | Yes | Low. Wings redeem dumps the vault's entire opposing balance at a min/max price limit. This vault is not Wings, but FS-MONEY-01 uses that same price limit, so the full-balance dump can be copied. Weir's `_withdraw` and FS-OWN-30 swap only the caller's withdrawn unwanted token. The test locks that other holders' inventory is not sold. |
| APEX-2026-025 | No | Medium. Wings `rebalance` measures its loss cap at the manipulated spot. PRD section 1.1 says there is no rebalance facet. |
| APEX-2026-026 | No | Medium. Wings `stepLimit = 512` freezes deposit, redeem, `getRate`, and `liquidationValue`. This vault has no liquidation-quote walk and no `getRate`. The freeze cannot occur unless the plan adds the walker the PRD does not specify. |
| APEX-2026-027 | No | Medium. Lido and EtherFi `rebalance()` re-queues the full LST deficit. This vault has no LST withdrawal queue. |
| APEX-2026-028 | No | Low. The DUAL hook identity exit pays 0 and still burns hook LP. That burn is hook code. The vault-side identity bind is already FS-A24, which records a package reject and does not add `asset()`. That is not a 028 reproduction. |
| APEX-2026-029 | No | Low. `StandardExchangeRateProviderFacet` values a BPT subject from full-book spot, and the Curve quad credits that pumped rate. FS-A29 forbids binding that provider as this family's rate. FS-A13 already requires `getRate` to be absent. Do not encode a BPT rate-pump test. |
| APEX-2026-030 | No | Low. The Balancer quad hook compares a rated invariant with an unrated checkpoint and mints phantom fee LP. That is hook fee code, not this vault's usage fee. |
| APEX-2026-031 | No | High. Balancer buffer joins are priced against virtual TTA. This vault does not implement that pool. |
| APEX-2026-032 | Yes, narrow | Low. `PostDeployAccountHookFacet` delegatecalls any caller during factory deploy. FS-FACET-02 says the factory still installs that temporary facet. The finding's trigger is Balancer `registerPool` calling a caller-chosen hooks contract. This package does not do that. Encode only that this package's `deployVault` and `processArgs` do not call an unprivileged contract while that facet is installed. Do not encode a Balancer pool backdoor. |
| APEX-2026-033 | No | Medium. DETF primary redemption charges for every protocol-LP leg and pays only `tokenOut`. This vault has no DETF burn. FS-OWN-09 requires the mapped redeem to pay both currencies proportionally. FS-A06 already locks that. Do not encode a DETF burn test. |
| APEX-2026-034 | Yes | Medium. A zero-supply 1:1 mint plus a donated receipt lets the attacker take the next deposit. This vault mints shares. FS-OWN-11, FS-OWN-20, and FS-MONEY-01 are the contrasting rules. The test locks that a 1-wei first deposit plus a direct token transfer does not take the next deposit. The floor holder in the assertion waits on blocking decision 8. |
| APEX-2026-035 | No | Medium. The Aave cross-version loop floors tokenB net at 0 and has no tokenA-to-tokenB route. This vault has no Aave debt legs. |
| APEX-2026-036 | No | Info. Deployed CP hooks use the inverted pretransfer credit and have no caller gate. That formula is hook code. This vault's booking rule is FS-OWN-20, tested under 039. Do not encode a hook `_securePull` test, and do not edit the hook. |
| APEX-2026-037 | No | Low. Re-enabling deployed `0x999DaE02` without a rebalance opens a cross-leg drain on a specific weighted hook. This new vault is not that deployed stack, and the PRD does not re-enable it. |
| APEX-2026-038 | No | Low. Same-transaction sDETF stake and unstake ratchets fee-to and creator weights. This vault has no `feeWeight` or `creatorWeight`. |
| APEX-2026-039 | Yes | Low. Pretransfer credit is not tied to the depositor, and exact-out refunds unattributed self-shares to the caller. The exact-out branch cannot apply because `exchangeOut` reverts. The self-share and unbooked-credit branch can. FS-OWN-20, FS-OWN-32, and FS-UNLOCK-02 say book only the requested amount, refund unused input to the payer, and burn only the caller's shares. |
| APEX-2026-040 | Yes | Low. Wings has no dead-share sink, and donated fee growth rounds the next deposit to 1 share. This vault's issuance includes fee growth only as unpaid fees in reserves, not as the share denominator. FS-MONEY-01 uses liquidity. The test locks that `PoolManager.donate` and a direct transfer do not round the next deposit to 1 share or let the donor take it. The dead-share holder waits on blocking decision 8. |
| APEX-2026-041 | Yes | Low. The deleted V4 FullSpread 64-step quote cap and single-step exact-out let dust ticks cap zap, redeem, and swap. FS-OWN-10 adds no replacement cap. The test locks that dust initialized ticks do not revert `QuoteWorkLimit` or `AlignmentNotAchievable` and do not cap those routes. Those errors are not requirements of this family. |
| APEX-2026-042 | Yes | Low. Both deleted FullSpread packages decode a bool from `approve` to Permit2, so a no-return token cannot be deployed. The PRD does not require Permit2. Settlement is sync, transfer, and settle. The test locks that initialization succeeds for a no-return `approve` token and does not abi-decode a bool from `approve`. |
| APEX-2026-043 | No | Low. The orbital hook freezes radius `R` at 10 times the first mint. This vault is not that hook and has no radius. |
| APEX-2026-044 | Yes, expected result blocked | Low. The dilutive usage-fee mint is the finding. FS-OWN-24 locks that mint. Encode the test only after blocking decision 9. |
| APEX-2026-045 | Yes | Low. Staking SEs never check the registry kill switch, so inbound routes stay open. FS-OWN-26 requires `VaultDisabled` on inbound issuance. FS-A38 says a supported exit through a buffered hook still works. The test locks both. |
| APEX-2026-046 | No | Low. Balancer V3 SE router composite routes revert on settle misaccounting. This vault has no Balancer router routes. |
| APEX-2026-047 | No | Low. A 1-wei underlying donation makes Aave Stata `deposit` revert, and booked aToken is counted but never paid. This vault does not call `stata.deposit`. A general donation test belongs to 034, not to this Stata revert. |
| APEX-2026-048 | No | Low. Aerodrome fee compounding swaps dust with `minOut` 0 and freezes LP routes. This vault's compound is FS-OWN-14, not that Aerodrome zap. FS-OWN-12 already says an inexact sleeve move must not revert. That is a vault assertion, not an 048 reproduction. |
| APEX-2026-049 | No | Low. Camelot exact-out LP-to-share deposit reverts on `actualShares != amountOut`. This vault's `exchangeOut` reverts `ExchangeOutNotAvailable` before any share-equality check. FS-A09 covers that. |
| APEX-2026-050 | No | Low. The V4 truncated TWAP credits an idle gap with the poked tick. This vault does not read that oracle. FS-OWN-03 and FS-RATE-01 forbid `getRate` and a rate policy. Do not add a TWAP consumer in order to test 050. |
| APEX-2026-051 | Yes | Info. The deleted analytic planner's 50 bps check compares a snapshot with itself, so preview certifies plans execution rejects. This family has no `AnalyticComposition` and FS-OWN-10 adds no impact gate. The test locks that preview does not return a positive amount that `exchangeIn` then rejects for `PriceImpactExceeded`, and that there is no self-comparing impact gate. |
| APEX-2026-052 | Yes | Info. The Aave loop cuts ERC-2612 and ERC-5267 and never initializes EIP-712, so standard permit signers fail. FS-FACET-01 cuts both facets here, and initialization installs name and symbol. The same omission can recur. The test locks that `DOMAIN_SEPARATOR()` matches the domain advertised by `eip712Domain()` and that a standard signer for that domain succeeds. |
| APEX-2026-053 | No | Info. Crane `MultiStepOwnable.acceptOwnershipTransfer` skips confirm and the buffer. The affected contracts are the manager, fee collector, and token staking. This vault's package does not install that ownership transfer. |
| APEX-2026-054 | Yes, as an integration classification | Low. Deployed CP hooks call `exchangeIn` without approving the SE, so unwrap reverts. That missing approval is hook bytecode. The PRD forbids editing the hook. Encode, in the integration rows, that a hook unwrap either succeeds with the hook's existing approval or is an FS-HOOK-04 record naming the consumer, selector, arguments, and revert. Do not encode a fork test of the deployed RICH hooks, and do not add a vault-side approval to make 054 pass. |
| APEX-2026-010 | Yes, mechanism only | Medium. Retired deployed V4 SE vaults stay enabled and RICH flows feed a free sleeve that credits stale reserves. The live disable of those addresses is not this vault. The mechanism can recur because this vault has a sleeve. FS-OWN-20 says unbooked balances are not reserves, not sleeve, and not redeemable, and a pretransfer books only the requested amount. The test locks that. Do not encode the mainnet disable script. |

Prior IDs in section 3 of the same report, so they are not skipped:

| ID | Encode a test on this vault? | Why |
| --- | --- | --- |
| APEX-2026-001 | Yes, same test as 010 | Section 3 says the stale-reserve credit was removed and replacement families use booked credit. FS-OWN-20 is that rule. One booking test covers 001 and 010. |
| APEX-2026-001-M | No separate V3 test | The report says V3 `_deployedFaceOf` is dead code that could bring the bug back. This plan does not edit that V3 function. The 010 booking test is what stops the same credit from being copied here. |
| APEX-2026-001-M2 | No | Live kill-switch gap on the seven old diamonds. See 010. Not this vault. |
| APEX-2026-003 | Yes, same test as 039 | Section 3 says a contract attacker still takes resting value. That is the 039 test. |
| APEX-2026-004 / 004B | No separate test | Section 3 says 004B no longer works and the exact-out residual is the 039 class. Exact-out is not installed. The resting-share residual is the 039 test. |
| APEX-2026-005 | No | Inverted pretransfer credit. Section 3 points to 036. Hook code. |
| APEX-2026-006 | No | Section 3 says it stays withdrawn and the guard holds. The report does not restate a mechanism in the sections read. There is no vulnerability text to encode. |
| APEX-2026-007 | No separate deployed-hook test | Section 3 says source is fixed and the deployed weighted hook still has the old code. The 036 related line calls 007 and 008 dust-refund code. The vault-side payer refund is FS-OWN-32, already required. Do not fork the deployed weighted hook for this plan. |
| APEX-2026-008 | No separate test | Section 3 says it is fixed and no longer works at HEAD. The only mechanism label found is the 036 related clause grouping it with 007 dust-refund code. No standalone write-up was in section 6. Vault-side dust refund to the payer is FS-OWN-32. |
| APEX-2026-009 | No separate test | Section 3 says the sweep was removed and the contract residual is the 039 class. Do not add a sweep. The 039 test covers the residual. |
| DEAD-PRETRANSFER | No | Section 3 says RebasingDETFToken routes still revert. This vault is not that token. |
| Balancer router R1 | No | Section 3 points to 019. Router code. |
| Balancer router R2 | No | Section 3 names `BatchRouterExactInTarget.sol` permit double pull. This vault has no Balancer batch router. |

## Limits

- Runtime or extraction proof: none. No tests, forge, git, or installs were run. Audit PoCs were not re-executed. File absence was a directory listing and a direct check of the dual V4 matrix path, not a hash of the JSON.
- Not examined: peer responses, the draft, other member files, the criterion body of `acceptance.json` R10.3, the values in `hook-se-matrix-findings.json`, `hook-se-matrix-finding-descriptions.json`, callers of `FullSpreadSameManagerAmmFixture.sol`, and the cited Standard Exchange interface report. Standalone write-ups for prior IDs 006, 007, and 008 were not in section 6.
- Live files can change. This response is not an atomic repository snapshot.
- Blocking decisions 9 and 10 mean the plan cannot honestly encode the expected result of APEX-2026-023 and APEX-2026-044 until the owner answers. The other required tests can be named now. Their existence does not make the requirements ready.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path. It does not write the implementation and testing plan.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
