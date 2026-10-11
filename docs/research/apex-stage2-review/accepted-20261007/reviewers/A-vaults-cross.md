# A-vaults bounded cross-review

Status: **CROSS_REVIEW_COMPLETE; source conclusions only; no release approval**. Reviewer `/root/vaults`, 2026-10-07. This wave began after the coordinator's global freeze at 20:21:34 UTC. The four frozen originals (`A-vaults-original.md`, `B-credit-lending-original.md`, `C-hooks-matrix-original.md`, `D-coordinator-original.md`) were considered together; the findings below received the assigned source reinspection. No peer cross-review was read and no original was modified. Other peer findings are not independently endorsed by this packet.

The original snapshot remains IndexedEx `5709cb3507a9df72b11ec476d27b79ef88696c3a` plus authorized dirty tree, manifest content digest `379d2c49ead26ad701503c419ca486ddcd0ae9158e2d879f9f0720129c721439`, Crane `b35609951b4951a3c107e267e22844a50c4dc043`. **Stage 1 is owner-accepted and complete.** Recording a remaining requirement conflict does not rescind that acceptance. No build, test, script execution, RPC, simulation, deployment, production edit or repair occurred. Runtime claims in supplied records remain supplied historical evidence.

## Dispositions

| Original finding | Cross-review disposition | Severity retained | Bound conclusion |
| --- | --- | --- | --- |
| B-01 | CONFIRM | Medium | Camelot false-flag share-to-constituent exact output lacks the caller's maximum check. |
| B-02 | CONFIRM | Low | Rocket's second allocation can include the first allocation that the minimum precheck skipped. |
| D-F03 | CONFIRM WITH AUTHORITY CAVEAT | Medium | Supported inverse retention conflicts with literal OD-08; consumer status documents the implementation but is not an identified owner amendment. No inverse-math error or monetary loss established. |
| D-F01 | CONFIRM | Medium | Same-directory discovery excludes replacement deployment roots; zero reported missing/oversized artifacts cannot certify those roots. |
| A-F01 | RETAIN, NARROW | Low | Exact-error ordering conflict only; all inspected EOA cases reject, and historical disclosure is preserved as counterevidence. |
| C-006 | CONFIRM | Low | One Wings consumer assertion is tautological; other actual join/exit assertions remain useful. |
| C-001, Wings component | CONFIRM LIMIT | Medium | Required assignments and route/state domains remain unresolved; documented domain counts are not executions or a complete overall denominator. |
| A-F04 / D-F02 | MERGE RECOMMENDATION | Informational for A-F04 | Consolidate A's source/runtime provenance limitation into D's evidence finding, retaining family-specific missing bindings. |

## B-01: maximum must survive the false-pretransfer path

Inspected `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol:339–353,443,709–805`, `CamelotV2StandardExchangeCommon.sol:195–225`, and `contracts/vaults/basic/BasicVaultCommon.sol:140–157`.

The public route validates deadline but supplies no universal maximum guard. In the share-to-contained-pool-token branch, the computed share debit is assigned to `amountIn` and passed to `_secureSelfBurn` without comparison to `maxAmountIn`. The common refund helper immediately returns when `pretransferred` is false, so its credit-bound check cannot repair this route. The false-flag burn is bounded by the holder's available shares, not the holder's declared maximum. The enclosing path does populate `indexSource.pool`; an uninitialized-pool objection does not make the branch unreachable.

The true-pretransfer path's credit cap and nearby branches' explicit maximum checks are counterevidence against an all-route defect, not a check on this branch. Preserve B's narrow own-position slippage/budget violation; do not describe arbitrary-holder theft or claim runtime reproduction. This is a source-established exact-output contract violation, independent of Stage 1 acceptance.

## B-02: rereading eligible excess does not preserve source allocation

Inspected `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol:446–459,500–515`, WETH investing callers in `RocketPoolRETHStandardExchangeInTarget.sol:71–80` and `RocketPoolRETHStandardExchangeOutTarget.sol:60–73`, and `test/foundry/spec/protocol/staking/rocket-pool/RocketPoolRETHStandardExchange_APEX_R14.t.sol:48–63`.

The first attempt is bounded by booked reserves. `_stakeWethToRethSoft` returns without investment when its stakeable amount is below the minimum. The second attempt recomputes `liquid-target` and sends that full eligible excess to the same helper; it does not subtract the skipped old allocation or bound the attempt to this caller's allocation. Thus the second stake can consume old eligible reserve that the separate first minimum check retained.

The controlling original plan (`docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md:129,132,592,627–628`, D39/D42, R14.3/19/20) expressly requires separate deposits, source bounds, and retention of the below-minimum sweep. The named regression keeps the aggregate below the minimum in its skip phase, then reduces the minimum; it does not discriminate separate retained budgets from pooled eligibility. Existing sleeve protection and the absence of new caller shares for old backing limit the impact. Retain Low conformance/economic-policy severity; no loss or profitable extraction is established.

## D-F03: preserve the precise owner-rule conflict

Inspected `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:566–710`, `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md:85–99,179–206`, and `docs/plans/UNISWAP_V4_FULLSPREAD_CONSUMER_STATUS.md:13–18`.

Both residual-join paths call `_retainSubSharePairResidual` before `_pairQuoteIsZero`; parking/wrapping paths also reach the helper first. For a supported exact-quantity quote interface, the helper can book and return on an inverse quote for one share without calling `previewExchangeIn`. The explicitly unsupported-interface branch does require a successful zero preview. That difference is real and is narrower than a claim that all residual errors are swallowed.

OD-01/OD-08 and REQ-01 use an exclusive successful-zero-preview condition. Consumer status explicitly describes supported opaque inverse retention, supplying strong evidence that this behavior is deliberate. It does not identify an owner amendment authorizing a second retention predicate. Under the current document hierarchy, keep D-F03 as **STAGE1_OPEN / INSPECTED / CONTRADICTS** against the locked text, with uncertainty about whether a later owner ruling intended that exception. Do not silently promote the status note into that ruling.

Counterevidence is material: inverse quantities may reasonably identify sub-share dust; this review does not prove them wrong. Operative joins propagate failure and reject zero LP (`:616–627`); `_pairQuoteIsZero` performs the direct preview (`:670–674`). The interface-detection catch is explicitly outside OD-01 and is not an additional defect. This is a REQ-01 closure conflict, not a proved custody loss, and does not subject Wings to the FullSpread ruling or reopen Pons-family policy.

## D-F01: new-directory omissions survive stale-row filtering

Inspected `scripts/r12_selector_size_compare.py:1–150`, especially `:36–63,126–131`; searched the baseline/current inventories for current Hookless, Pons-family and Wings roots; inspected `docs/reviews/apex-2026-09-17-second-audit-readiness/selector-size-compare-stage1-current.json:870–930` and its source entries.

Discovery obtains parent directories solely from surviving baseline rows and uses nonrecursive `parent.glob('*.sol')`. Removing nonexistent old source rows is reasonable, but does not discover their replacement directories. The split Hookless/Pons-family and separate Wings roots are absent from this candidate universe and the compared inventory. New facets beside retained roots are detected; that does not establish current-product completeness.

The comparison itself says it is not audit submission and does not certify installed proxy cuts (`:875–876`). Historical FullSpread consumer-status size assertions are counterevidence against claiming an actual oversized facet; they do not fill the current source/artifact binding. Retain the tooling/inventory deficiency and R12.2/R12.4/S2-ADD-008 closure limitation. Do not report that a facet exceeds EIP-170, that a selector is certainly uninstalled, or that every artifact is stale: none follows from the omission.

## A-F01: exact error is the authority, not rejection safety

Rechecked the controlling original plan D9/R13.1/R13.2 (`:99,577–578`), the V3 exact-output ordering and common guard sites identified in A's original, and `docs/audits/apex-2026-09-17-evidence.md:159`. V3 `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:82–90` and `OutMultiTarget.sol:36–44`, and Hookless/Pons-family `UniswapV4FullSpreadStandardExchangeVaultOutExecuteTarget.sol:94–106` evaluate shortfall before the helper's no-bytecode check. Full paths and the family-specific helper references are retained in the frozen original inventory.

D9's requirement is the named caller error on supported public pretransfer entries, reinforced by R13's exact-error requirements. Historical evidence already says these underfunded calls fail earlier and that both errors reject without state change. That disclosure must accompany the finding; it is not an identified explicit waiver. Retain Low only as diagnostic/interface conformance. It does not establish authorization bypass, principal loss, missing exact-input protection, or a general release safety blocker. Coordinator may resolve the rule interpretation explicitly, but should not erase the counterevidence or ask for Stage 1 acceptance again.

## C-006 and C-001: assertion defect versus stronger Wings domain

Inspected `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultFamilyConsumers.t.sol:27–59`. Five real hook-family round trips call the shared helper. It deposits into the Wings vault, rebalances, deploys and funds a real consumer, verifies positive LP and share movement, then exits part of the position. Those are substantive controls. However, `:59` compares `token1.balanceOf(f.hook)` to the identical expression, so it provides no independent opposing-token or conservation condition. Confirm C-006 without dismissing all five tests.

Separately inspected Wings PRD `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md:348–369`, `docs/plans/records/uniswap-v4-upper-lower-wings/CONSUMER_MATRIX.json:1–260`, and `CONSUMER_RESULTS.md` in full. These documentary records are evidence inspected during cross-review, not a newly bound runtime execution.

The PRD's unit includes family, eligible assignment, mask, route, manager relationship and economic state. Weighted standalone arity eight with eight Wings legs is required; a mandatory raw DETF leg limits buffered Wings to seven. Orbital and quad homogeneous/mixed cases, both constant-product directions, target0/target1, shared underlying PoolKey effects, rejected duplicate bindings and advertised DETF money paths remain separate dimensions. Existing FullSpread/Pons consumer coexistence does not authorize a hooked underlying pool for Wings, and deprecated Slipstream remains excluded. Symmetry reduction needs a proof and explicit acceptance; representative or pairwise tests do not satisfy this language by themselves.

The inspected matrix declares `IN_PROGRESS`, `completion_claim=false` and default PENDING, with eleven assignment-domain counts totaling 489,664 before route/state expansion. Its additional-required section still leaves mixed existing SE families and other domains pending (`:184–204`). The results document expressly reports passed money paths rather than every legal mask and lists remaining coverage. Therefore confirm C-001's Wings limitation and preserve A's own R3.3/supplement INDETERMINATE breadth. The number is a documentary ordered-assignment subtotal, not the overall required denominator or a pass count. This cross-review did not independently repeat C's ordinary 210-file inventory and does not turn historical 203-row evidence into current closure.

## Reconciliation and remaining limits

A-F04's missing current-source execution binding overlaps D-F02; merge the general finding while retaining A's concrete V3/Hookless/Pons/Wings evidence limits. A-F02 and C-006 concern different test assertions and should remain separately attributable; A-F03's all-reverting invariant concern is also distinct from the consumer matrix denominator. No original finding was withdrawn through peer assertion alone.

This wave adds source-based challenges and bounded confirmations. It does not authorize or supply repairs, build freshness, exact deployed cuts, runtime outcomes, exhaustive matrix execution, or an overall release verdict. The coordinator owns final deduplication and closure status with these counterarguments preserved.
