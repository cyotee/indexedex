# FullSpread SE hook implementation/testing planning record

- intent: clear
- classification: architecture
- review_required: true
- status: completed-plan
- plan_path: .omo/plans/fullspread-se-hooks-implementation-testing-20261106.md
- approval: The user approved proceeding from the readiness assessment and explicitly requested the new implementation and testing plan. No further planning permission is required. Implementation is not authorized.
- authoring: Use apply_patch for all planning artifacts under the session's file-edit rules. Do not run a file-writing scaffold script.
- test_strategy: Preserve and update superseded assertions, add production-first regressions alongside implementation, and require red-before/green-after evidence for newly exposed behavior. No project tests or builds run during planning.
- pending_action: none; completed plan delivered for the user's separate execution decision.
- queue_state: The owner supplied and approved both decisions in the PRD before requesting this completion. Authoring, reconciliation and source-backed self-review are complete; implementation remains unexecuted.

## Authority

`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` is authoritative, including the latest FS-OWN-34/35 own-share clarification and FS-OWN-36/37 fee/bootstrap locks, FS-HOOK-05 through FS-HOOK-10, and FS-A01 through FS-A48. The previous family implementation plan and council diagnosis are historical context where superseded.

The user's latest instruction requires every hook type to handle refunds and disablement and include local booked balances in swap calculations. It does not authorize rate-valued LP ownership or departure from proportional actual-component accounting. The plan must preserve the useful family-specific liquidity-coordinate structure without treating raw SE-share units and pair-token units as directly additive.

No named deprecated vault is a fixture prerequisite. Do not delete that contract in this planning task or include its deletion as an implementation prerequisite. Two real FullSpread instances with disjoint backing pools can supply the cross-vault fixture.

## Affected users and ideal state

| ID | User and desired result |
| --- | --- |
| IS-1 | Hook LPs own proportional actual SE-share and local-token components without rate-driven issuance or loss of retained refunds. |
| IS-2 | Swappers see local inventory included in reserves and consumed before SE redemption, including while an underlying vault is disabled. |
| IS-3 | Exiting LPs receive their component claims without a cleanup deposit vetoing a permitted disabled-vault withdrawal. |
| IS-4 | Integrators bind a valid pairToken through vaultTokens(), with own-share mint/redeem recognized separately and no asset() dependency. |
| IS-5 | Implementers have an exhaustive seven-family route map, file ownership boundaries, dependencies, and executable verification. |
| IS-6 | Reviewers can trace every original failure and each of 48 PRD acceptance rows to concrete evidence rather than skipped or falsely green tests. |

## Gaps

| ID | Current observation | Required closure |
| --- | --- | --- |
| GAP-1 | Shared leg classification still has asset() wrapper recognition. | Membership-only paired-token validation and implicit own-share processing. |
| GAP-2 | Family conversion and cleanup paths can ignore/refeed refunds or mint into a disabled SE. | Per-leg owned local books, tuple-aware settlement, disable-aware buffering. |
| GAP-3 | Existing family liquidity and fee paths use inconsistent raw/virtual/rated coordinates. | Uniform component ownership invariant applied through every family adapter and public route. |
| GAP-4 | Dual and mixed FullSpread fixtures use an out-of-scope sibling identity configuration. | Real FullSpread sibling backing pools, valid paired tokens, real conversion and exit evidence. |
| GAP-5 | Existing tests expect rejected identities and blanket buffered disable reverts. | Requirement-driven replacement positives/negatives, all family/state combinations, full 48-row traceability. |
| GAP-6 | Artifacts are runtime deployment inputs; passing source inspection is not runtime proof. | Solar artifact-first build, deployed-proxy checks, gas and evidence gates in execution plan. |

## Independent read-only tracks

| Task | Track | Status |
| --- | --- | --- |
| st_01a1b1d9 | Architect: single, constant-product single, dual and shared boundaries | completed; principal claims independently checked |
| st_01a1b1da | Explore: orbital, weighted, Curve, Balancer and test map | completed; parent verification complete, including correction of a nonexistent Curve InQuoteBase reference |
| st_01a1b1db | Detail advisory: proportional algorithms, zero components, refunds, fees and verification | completed; substantive fee/bootstrap preservation conflicts identified |

All research tasks are terminal. Monitor mon_MBVW2XB3FK8DQ02H was stopped after the research completed; the earlier mon_ST8YZG68BWGQM7ST timed out. No research task was restarted. No research or terminal monitor remains active; the owner subsequently resolved both decisions.

## Evidence already checked

- Repository router and assistant coding/deployment/testing rules.
- IndexedEx and Crane testing/deployment/architecture skills; hook-package skill. Router overrides stale package-specific profile and compiler examples.
- Current foundry.toml: default hermetic and fork profiles only; out/ and cache_forge/; via_ir false.
- docs/testing/ARTIFACT_BUILDS.md: explicit runtime artifact refresh before tests, no concurrent writers to shared artifacts.
- FullSpread TestBase and SeMatrix_FullSpreadV4Fixture.sol: registry-backed package construction, sibling fixture currently needs replacement.
- Eight FullSpread spec files and their literal test names. Native LSP document-symbol requests failed with changed-input errors and one timeout; direct file reading and bounded literal search were used instead. No language-server configuration changed.
- Shared leg library and IVaultRegistryDisableQuery: identify membership/own-share separation and effective address-or-package disable lookup.
- FullSpread Planner currently uses the locked 49% one-sided input rule. Older quadratic helper tests exist; they must not be mistaken for the current product sizing requirement.

## Review ledger

No formal plan review launched. A plan-consultant request was refused by Native: the user did not explicitly request the ulw-plan workflow, so plan-gated reviewers are unavailable. Do not retry or attempt to unlock that gate. Continue with source-backed self-review and the already authorized read-only design advisories; do not claim independent plan-reviewer approval. No implementation, tests, builds, installs, deployment, Git, or contract deletion performed.

The same implementation plan file at plan_path is complete. It contains twenty implementation/testing tasks, four future final-verification tasks, seven-family source/route coverage, 48 unique acceptance dispositions matching the PRD, and the complete 36-instance failure migration ledger. Explicit task dependencies, single-writer ownership, all nine concrete FullSpread matrix rows, planned new test filenames and exact fee/genesis regressions are included. Source references were checked and the nonexistent Curve InQuoteBase locator replaced by the actual JoinCore/HooksTarget quote paths. No independent plan-reviewer approval is claimed.

## Resolved owner decisions

- FS-OWN-36 / FS-HOOK-09 / FS-A47: charge a configured percentage of new fully backed gross Hook LP, split it into protocol fee LP and depositor net LP, and retire growth-based protocol issuance. Previews/minima are net; exact-net requests gross up. Exclude the locked genesis floor once. Preserve normal pool trading fees and existing configuration sources without importing the FullSpread vault fee cap.
- FS-OWN-37 / FS-HOOK-10 / FS-A48: at LP supply zero, funded SE-backed legs accept SE shares and redeem floor(actualReceivedShares*5/100) to seed local paired-token inventory. Use normalized retained shares and raw quantities in existing family seed functions, verify actual share consumption and positive local receipt, and revert atomically on failures. Later joins follow the actual basket, not a permanent 5% ratio. H1 has no LP genesis.
- These supersede the earlier unselected swap-fee-token/basket proposals and the share-or-local fallback seed proposal. No question or economic default remains pending.

## Completed authoring checks

- 48 PRD acceptance IDs exactly match 48 unique plan ledger rows, including withdrawn A12-A16 dispositions and added A47/A48.
- All 20 tasks retain references, work, acceptance criteria, happy/failure QA, executor category and no-commit boundaries; four final verification tasks remain unexecuted.
- All 36 original instances remain represented (24 + 8 + 2 + 1 + 1), including the twelve dual names and positive disabled withdrawal.
- Explicit family production filenames and all nine existing FullSpread matrix filenames were checked. The two differently prefixed Balancer LiquidityUnits files exist. Proposed new test files are labelled new rather than claimed to exist.
- The minimal gross-up identity was sanity-checked for 10,000 integer percentage/net-amount cases; this was document arithmetic validation, not a project test or runtime integration result.
- Source-backed self-review reconciled fees, bootstrap, independent component books, fixture funding, facade aliases, dependencies, output bounds, disabled redemption and the non-LP single exception.
- Only the plan and this planning record were edited for this completion. No implementation, project tests/builds, installs, deployments, Git changes or contract deletion occurred. The PRD remains the requirements authority.

## Verified corrections to research claims

- The multi-leg explorer's claim that all existing LP paths are rated/NAV-based is too broad. Parent reads of Weighted LiquidityTarget._fullPropJoin and Curve JoinCore._fullPropJoin show inventory-domain proportional algebra; Balancer StableLiquidityUnitsCore proportional joins use _nativeAll. Its unbalanced branch does use _ratedWadAll. Preserve and extend inventory-coordinate patterns, rather than rewriting all math as though no quantity-based path exists.
- FullSpread's prohibition on SY selectors applies to that vault, not automatically to hooks. Existing hook Native SY and flexible-liquidity facades remain route surfaces to adapt and test, not remove.
- DFPkg validators are in scope even if no facet is added: orbital, weighted, Curve, and Balancer packages call the wrapper-recognition helper directly as well as paired-token membership.
- Explorer line ranges for the PRD do not match the current document. Use requirement IDs and independently checked source locators in the final.
- Single's product interface explicitly declares it a wrap/unwrap hop, not an LP product. Cover custody, refunds, disablement and settlement there; LP ownership cases apply to the six LP-bearing families. Do not invent LP issuance for single merely to fill the matrix.
- CP-single DepositCommon._mintProtocolFeeIfNeeded and dual Common._mintProtocolFeeIfNeeded use rated reserve products; their preview supply paths do too. Rate-independent final mint arithmetic alone does not remove that supply-denominator dependency. Fee and bootstrap treatment must be explicit in the plan.
- CP-single WithdrawalLib.proRata and the multi-leg inventory-domain proportional paths are reuse anchors, not evidence that the local-pair extension already exists.
- Balancer StableLiquidityUnitsCore exposes pair-or-share flags and unbalanced routes. Preserve existing hook facade/selector contracts; the final plan must address how caller-allocated local tokens are converted for share-requested exits and what happens when that requested conversion is disabled.
- Existing single's fee-oracle binding is zero. Any internal effective-disable lookup must use an actual bound registry, not assume every hook's feeOracle is a usable registry.
- Recommended decomposition: family-owned component books and adapters, small common arithmetic/result handling; do not replace all family execution with a universal engine.

## Acceptance inventory

The completed plan's Full PRD acceptance ledger is the execution mapping for all 48 rows. The PRD remains authoritative; this planning record does not maintain a competing requirements table.

## Original failure migration ledger

The user supplied 36 failing contract/test instances. These were not rerun during planning. The updated PRD supersedes the earlier council's instruction to keep the invalid sibling-identity fixtures deliberately red. Preserve the tested behavior, rebuild valid fixtures, and replace obsolete expectations explicitly rather than deleting coverage.

| Original instances | Count | Required plan action |
| --- | ---: | --- |
| Twelve identity-gated dual tests, each in the standalone dual matrix and inherited DualUnwrap suite | 24 | Replace the sibling with a real second FullSpread vault and its valid paired face; run each test body past the old identity guard. Keep both directions, both product-index cases, both provider targets, previews, swaps, refund ownership, and measured gas. |
| test_row_identity_pairToken in orbital, weighted N3, Curve, Balancer five-leg and their four inherited unwrap suites | 8 | Replace the deprecated sibling fixture and misleading identity expectation with valid paired-token membership plus positive own-share mint/redeem. Keep raw-leg controls and separate nonmember rejection tests. |
| test_row_identity_thisVault in dual and DualUnwrap | 2 | Rewrite as FS-A24 positive own-share processing with the vault address absent from its underlying list and a separate valid paired-token binding. Do not require self-membership. |
| test_dualUnwrapApprovesAndCompletesExit | 1 | Execute approval, burn, local entitlement and SE redemption on the rebuilt valid dual fixture. A prerequisite assertion alone is not exit coverage. |
| test_disabledBufferedWithdrawalApprovesAndCompletesExit | 1 | Preserve the positive exit obligation; separately assert retained local ownership and the absence of prohibited cleanup deposits. Extend the case to every hook family and both disable axes. |

The twelve dual test names are:

- test_composedRouteGasFitsCeiling
- test_row_bind_deploysThroughPackage
- test_row_bufferFirst_restingFace_notPaidToJoiner
- test_row_hookSwap_exactIn_eoaPretransferRejected
- test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly
- test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed
- test_row_index0
- test_row_index1
- test_row_partialConsumption_bookedNotRefunded
- test_row_poolManagerSwap_bothDirections_noFaceResidual
- test_row_previewMatchesExecution
- test_row_rateTarget_currency1

The existing test_disabledBufferedMintRevertsWhileUnlockedAndRollsBack is not one of the supplied failures but becomes stale under the new requirements: replace the blanket hook-level revert assertion with positive local booking plus a distinct direct-disabled-SE rejection/rollback test. Tests must continue distinguishing a hook-local exact-output settlement from a path that actually calls the FullSpread vault's unavailable exchangeOut.
