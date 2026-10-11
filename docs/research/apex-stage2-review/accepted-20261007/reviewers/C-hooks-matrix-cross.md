# C-hooks-matrix bounded cross-review

Status: **CROSS_REVIEW_COMPLETE; PARTIAL_REPORT readiness remains**. Reviewer `/root/hooks_matrix`, 2026-10-07. This is the one authorized cross-review wave after the global original freeze at 2026-10-07 20:21:34 UTC. The four frozen originals A-vaults, B-credit-lending, C-hooks-matrix and D-coordinator were available together and read for this challenge. No peer cross-review was read and no original was changed.

Bound source remains IndexedEx `5709cb3507a9df72b11ec476d27b79ef88696c3a` plus the accepted working tree, SHA256 `379d2c49ead26ad701503c419ca486ddcd0ae9158e2d879f9f0720129c721439`, Crane `b35609951b4951a3c107e267e22844a50c4dc043`. Stage 1 is complete and accepted. The findings below do not reopen that decision. This wave performed source/document inspection only: no tests, builds, RPC, deployments or source/test/configuration edits.

## Dispositions

| Original finding | Cross-review recommendation | Readiness consequence |
| --- | --- | --- |
| D-F01 | SUPPORT, Medium verification-tool deficiency. Independently confirmed direct-parent-only discovery omits replacement directories. | Current complete R12 selector/size closure remains unsupported; no oversized runtime established. |
| D-F03 | SUPPORT source/OD-08 mismatch, with economic and authority qualifications. | REQ-01/R14.9 conformance remains unresolved under the recorded exclusive zero-preview rule. |
| B-05 | SUPPORT. Hook matrix fixtures do not repair missing adapter-operation/receipt-dispatch configurations. | R14.17–18 full coverage remains incomplete. |
| A-F03 | SUPPORT. Campaign control flow allows a vacuous all-revert campaign. | Stateful coverage cannot be closed by this campaign alone. |
| C-002 | NARROW; recommend Low TEST_DEFICIENCY/authority reconciliation. An earlier preview guard rejects an over-cap request under stable state. | R6.4's historical cap-call acceptance needs explicit reconciliation; do not report a demonstrated reachable missing-cap-call vulnerability. |
| C-001 | SUPPORT, with normalized dispositions and strict domain limits below. | Ordinary documentary inventory is finite; expanded Wings/configuration/route denominator remains unresolved. |
| C-006 | SUPPORT, distinct from A-F03. | Tautological consumer assertion supplies no conservation evidence. |

## D-F03: inverse residual retention versus OD-08

Independently inspected `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:574–575,599–627,634–674,693–694` and OD-08/REQ-01 in `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md:179–210`.

The supported-inverse branch of `_retainSubSharePairResidual` calls `quoteState` and `quoteInputForExactShares(state, 1)`. When the returned minimum is positive and the residual is smaller, it updates the holder reserve and returns before `_pairQuoteIsZero` is called. It therefore does not obtain the successful zero `previewExchangeIn` required by the recorded OD-08 rule. `_joinResidualCapped`, `_joinResidualUnbalanced`, `_parkUnmintablePairDust` and `_wrapAndParkPair` use that helper before their direct-preview check. This is a reachable configured-interface branch, not merely a dead helper.

Counterevidence matters: the unsupported-interface branch does require a successful zero preview; `_entryJoinResidualAtomic` now hard-calls the join and rejects zero LP; `_pairQuoteIsZero` itself is direct. The `supportsInterface` catch is outside the operative-join rule and is not this finding. `docs/plans/UNISWAP_V4_FULLSPREAD_CONSUMER_STATUS.md:13–18` explicitly documents inverse-based retention as supported behavior. That is credible evidence of implementation intent, but I found no explicit owner amendment making the inverse an alternative OD-08 retention signal.

Recommendation: retain D-F03 as a source/locked-rule inconsistency (Medium, high source confidence), pending coordinator authority reconciliation. Do not infer that the inverse arithmetic is wrong or that retained assets can be stolen. An inverse could establish a sound sub-share boundary while still bypassing a required direct preview and its validations. The review does not choose a new policy or prescribe restoring obsolete catches. Execution remains INCOMPLETE_PROVENANCE / UNKNOWN for this specific supported-inverse acceptance; nothing was run.

## D-F01: deployment-unit discovery

Independently inspected `scripts/r12_selector_size_compare.py:36–65,125–139`, its baseline/current JSON inputs, and the replacement source directories. `discover_artifacts` derives the direct parent of each surviving baseline source, then uses `parent.glob('*.sol')`. Deleted baseline sources are removed before discovery. The source-parent set does not include, or descend into, any of:

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings`

The supplied current result reports 540 compared rows, 32 stale sources and seven new units. Those seven new units do not include these replacements. A read-only parse of the baseline source paths confirmed the parent-set omission; the comparison/build script itself was not executed. This supports D-F01 independently of trusting its original narrative.

Qualification: the discovery docstring accurately describes same-directory discovery. The defect is its insufficiency for the broader present-product gate, not deception by that helper. Historical H/P runtime-size records remain useful separately. The omission proves neither an oversized current facet nor a missing deployed selector. A complete inventory and source/artifact binding are still needed for R12.2/R12.4 and S2-ADD-008; ABI discovery is not proxy-cut verification.

## B-05: shared receipt adapter and hook matrix evidence

Reinspected `test/foundry/spec/vaults/standard/erc4626/behaviors/Behavior_ReceiptBackedERC4626_CrossInterface.sol:68–138` and `ReceiptBackedERC4626_SharedFacet.t.sol:92–165`. The shared behavior supplies adapter deposit then unfunded SE receipt-push rejection, and a funded receipt-push positive, but not the matching mint negative. Its withdrawal sequence performs another adapter deposit, not the required post-withdrawal atomic SE receipt-pretransfer; the corresponding redeem sequence is also not established there. SharedFacet deploys the generic wrapper over SimpleYield and separately deploys a Stata package; it does not make the generic wrapper's receipt itself Stata.

The hook configurations do not close this gap. `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_ERC4626Fixture.sol:25–29,96–100` uses the generic capped/pausable ERC4626 or SimpleYield host. `SeMatrix_StataFixture.sol:97,227` deploys a Stata package through the manager and binds its Stata receipt. The latter establishes a Stata-family proxy, not the potentially confusing generic-family proxy over a Stata receipt. The ordinary inherited hook controls exercise SE money routes, not the complete four-operation ERC4626-adapter-to-SE transition matrix.

Support B-05, Medium TEST_DEFICIENCY, R14.17/R14.18. Retain its positive counterevidence: all sixteen shared selectors, proxy isolation, all-four-operation implementation sync, and the generic D45 controls are substantive. Do not infer an adapter code defect or erase those positives. Hook COMPATIBLE design rows cannot be used to certify this different dispatch/setup dimension. Current execution for the missing configuration is MISSING / UNKNOWN.

## A-F03 and C-006: Wings campaign and consumer assertions

Reinspected the complete `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultInvariant.t.sol`, especially handler actions at :32–51, setup at :61–65 and invariants at :76–96. Trade, deposit, redeem and rebalance catch all errors. Deposit/withdrawal success counters are not asserted; trade/rebalance lack success requirements. The initial deposit also uses the catch-all handler. An all-reverting deposit sequence leaves zero supply, bypasses the conditional positive-value assertion and satisfies the zero-custody/cash-conservation state. Thus the campaign can pass vacuously. This is a source property, not a claim that the supplied execution actually did so.

Support A-F03, Medium TEST_DEFICIENCY. Real deterministic money, rebalance and transition tests provide counterevidence against treating all Wings integration as untested; they do not enforce successful action coverage in this campaign. Safety invariants and successful state exploration are separate evidence requirements under the Wings supplement and R11.

Also reconfirmed `UniswapV4UpperLowerWingsStandardExchangeVaultFamilyConsumers.t.sol:38–59`: the token1-balance assertion compares the expression to itself. Real funded joins, minted LP, share movement and exit inequalities are useful, but this assertion cannot prove opposing-token preservation. Retain C-006 separately as Low TEST_DEFICIENCY, because a tautological deterministic assertion and a vacuous campaign have different causes and corrective objectives. Neither issue is a demonstrated production loss or a regression of the accepted Stage-1 outside-trade repair.

## C-002: earlier guard narrows the capped callback concern

Additional source tracing changes the strength of the original finding. In `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol`, `_swapExactOutExecute:749–757` runs `_previewSwapExactOutWithFee` before `_unwrapExactTokenOut`. The preview at :852–870 calls `_faceOutToEffectiveNative:963–977`; that helper obtains the unwrap share quote and reverts `Math.Drain` if the shares exceed `_spendableSeShares`. `UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol:450–459` obtains that value by directly calling SE `previewExchangeOut`, rather than an older approximate inversion. `_unwrapExactTokenOut:710–727` checks the same quote against the cap, approves the quoted amount, performs exact-output execution and resets allowance.

Consequently, under stable state and deterministic view results, the callback over-cap request is rejected before the alleged legacy capped-SE-call branch could be reached. The existing `Apex008.t.sol:235–272` preview-Drain/outer-WrappedError negative is consistent with that earlier boundary. It does not establish propagation of an underlying SE execution failure. The named funded capped-success test at :223–233 is an ordinary successful exact-output case and does not witness a distinct cap branch.

The direct SE route also performs preview checks before settlement (`UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol:150–175`). This review has not established a state-changing dependency sequence that bypasses the earlier guard and reaches an over-cap operative call. Do not promote such a hypothetical into a reachable code defect. Conversely, no explicit current amendment was identified that rewrites R6.4's historical requested cap-call/error witness.

Recommendation: narrow C-002 to **Low TEST_DEFICIENCY with authority/requirement reconciliation**, high confidence in the named-test mismatch and earlier guard, no demonstrated principal-safety defect. Amend consolidated R6.4 inspection from an unqualified production CONTRADICTS implication to **INDETERMINATE for the historical cap-call acceptance**, with current over-cap rejection source-supported. R6.4 cannot be marked complete merely because the tests contain “cappedUnwrap” in their names, but do not prescribe reintroducing a path made obsolete by valid current quoting. Any needed downstream execution-error witness must concern a reachable supported path and assert its actual nested error. C-002's original counterevidence already anticipated this issue; this cross-review supplies the missing trace.

## Matrix reconciliation and normalized states

The ordinary inventory was re-counted from actual `*_SeMatrix_*.t.sol` wrappers and checked against the original appendix. It has seven families, each with 22 base configurations and eight decimal configurations: **210 concrete wrappers**. The seven explicit external-BPT adapter exclusions under R10.3 add seven documentary rows and intentionally have no wrapper file. The resulting **217 ordinary documentary configuration cells** are finite and reproducible; they are not 217 executed passes or the total expanded consumer domain.

| Ordinary design disposition | Product/exclusion role | Control role | Total |
| --- | ---: | ---: | ---: |
| COMPATIBLE within the stated supported route domain | 181 | 21 | 202 |
| INCOMPATIBLE | 8 | 0 | 8 |
| DEPRECATED | 7 | 0 | 7 |
| Total | 196 | 21 | 217 |

Normalize the original appendix's `CONTROL` cells to `design_disposition=COMPATIBLE`, `row_role=CONTROL`. Controls are the three SimpleYield host configurations per hook (base and the two decimal configurations), not additional D16 products. Preserve the original row keys and locators when transcribing. The one concrete INCOMPATIBLE row is non-CP single × Camelot's exact-output mint route; its supported-route controls do not make that unavailable route compatible. The seven other INCOMPATIBLE cells are hook × standalone Balancer adapter: shares are external `bptToken()`, while the hook expects `IERC20(se)`, as R10.3 explicitly records. The seven Slipstream cells remain DEPRECATED under D57; rejection controls are not passing integrations. No ordinary DEFERRED designation is retained from stale historical comments.

The fourteen hookless/Pons FullSpread configuration rows belong inside the 202 COMPATIBLE configuration count **only for their admitted route domain**. Their exact-input controls and exact-output rejection overrides must remain visible; they do not certify successful all-route exact-output support. In particular the quad proportional-inverse rejection is a route restriction. Preserve separately the unsupported-route designation and its negative-control execution status. Do not count a designed rejection as a passing economic integration.

Execution remains independent: current wrappers/common behavior were inspected; current source-bound all-matrix execution is INCOMPLETE_PROVENANCE / UNKNOWN. The supplied 203-row historical artifact is HISTORICAL_ONLY / PASS as supplied; its 195 compatible, one incompatible and seven deprecated classifications do not include the seven newer Pons rows. Different older plan prose records different historical totals and cannot replace the current census. Exclusions have no positive integration execution requirement; their supplied deprecation/exclusion witness has its own provenance and outcome.

### Expanded domain is still unresolved

`docs/plans/records/uniswap-v4-upper-lower-wings/CONSUMER_MATRIX.json` explicitly has `IN_PROGRESS` and `completion_claim=false`. Its eleven ordered assignment domains sum to 489,664 assignments before route/state expansion: weighted arities 2–8 use `5^n - 1`; orbital arity 3, the two quad arity-4 families and dual arity 2 provide the other four domains. This arithmetic is not a complete present-product denominator. Single-CP choices, non-CP single applicability, mixed-existing-SE configurations, funded DETF consumers, shared-pool/opposite-target constraints and route/economic-state expansions require explicit reconciliation. The accepted subset in the current consumer tests is much narrower, as the original appendix details.

Normalize the original pending-domain documentary `PENDING` design labels to **UNDETERMINED**, retaining the reason, applicability question and missing evidence separately. Do not turn them into INCOMPATIBLE without authority or into DEFERRED green rows. The full Wings upper-bound assignment count must not be added to 217 and presented as a resolved exhaustive total.

H/P ordinary fixtures also explicitly choose ERC20 currency0 and exclude native ETH from that fixture. Pons production package native-to-WETH handling exists (`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookDFPkg.sol:380–390`), so those wrappers alone do not settle native/opposite-token/manager combinations. Wings native-router applicability and its admitted nonnative underlying configuration are distinct. This review neither admits a Pons underlying Wings pool nor invents a product exclusion. Expanded current configuration scope remains **UNDETERMINED**, with execution MISSING / UNKNOWN for unenumerated required combinations; S2-AC-09 remains a material PARTIAL_REPORT limit.

## R14 seam corrections and additional native-BPT inspection

The frozen C original's shared-seam label **“R14.7 D33 AMM caller-fund separation” is wrong**. R14.7 in the controlling APEX plan at :614 is Aave partial-position control. Consolidation must map that row to R10.3/D33 and the actual applicable R14 capacity/refund criteria, rather than use it to claim R14.7 inspection or closure. Similarly R14.5 concerns Stata's input-specific capacity; R14.6 the loop cap; R14.8 native-BPT failure behavior. A grouped cross-family source note is not an individual criterion witness.

For R14.8, additionally inspected `test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol:212–227,265–317`. It uses real pause authorization and exact PoolPaused controls, unpause/funded success, real invariant-ratio failure and no-unbalanced-pool failure. These are stronger than a mocked paused response. Their cited blocks do not contain the complete all-family rollback/allowance snapshot matrix. The six pool-package route source remains a hard operative boundary (`contracts/protocols/dexes/balancer/v3/pools/BalancerV3PoolStandardExchangeTarget.sol:120–185`): public prepaid is rejected, only quoted used input is pulled, callback state is committed under the lock, Vault calls remain hard and actual output is checked. The internal self-holder exception is distinct from public credit acceptance.

This adds positive R14.8 source/test support without closing the full native-BPT family denominator. Keep R14.8 PARTIAL / INDETERMINATE where those complete controls remain unestablished. C-005's D49 mock-fixture gap is a narrower, separate issue; it should not erase these genuine protocol-state controls or be used to claim their completeness. R14.9's allowed D41/D48/D49 reads must remain distinct from prohibited operative failure softening.

## Evidence and limits

This cross-review relied on the frozen originals, the specifically cited controlling rules and the source/test/configuration portions identified above. It did not execute the suites, authenticate historical binaries or certify installed proxy selectors. Findings are recommendations for coordinator consolidation, not automatic fixes or new policy. Catalog implications remain I/K/N2 for receipt-credit dispatch; A/C/E/H/K/N for Wings stateful/assertion quality; L/J/F for rate, callback and package discovery seams, with per-surface applicability retained from the original. No hypothetical exploit procedure is supplied.

Ready for consolidation with the C-002 narrowing, matrix state normalization and R14 numbering corrections. Original files remain frozen. The report may be complete as a bounded inspection deliverable while overall expanded matrix and release readiness remain explicitly partial.
