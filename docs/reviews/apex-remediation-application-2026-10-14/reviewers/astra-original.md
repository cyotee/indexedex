# Astra original — remediation application review

Date: 2026-10-14. Target: current IndexedEx working tree. Independent first pass; no peer artifacts read. No source identity hash was recomputed or inferred.

## Answer and limits

**No: the remediations are not completely applied.** Hook-zero rollback remains unapplied; legacy V4 uses a settlement-delegate mechanism expressly excluded by the holder specification; matrix acceptance assertions remain incomplete; and an older required README correction is still incomplete. Two additional required-test defects are identified below.

This is a source-inspection review, not an execution attestation or a full re-audit. I did not run Forge, builds, shell commands, scripts, or deployments. `Applied` below means the inspected source and assertions match the stated requirement, not that a test passed. `Unverified` means the complete acceptance set was not established; it does not assert a missing implementation. Some September requirements remain unverified because their full production/test inventories were not body-reviewed.

All ten supplied specification groups and their supplied plans were read successfully, including the earlier draft and confirmation PRD. No supplied document read failed. CLAUDE.md, docs/agent/SKILL_CATALOG.md, and the canonical Crane and IndexedEx testing skills were read directly. No skill was invoked. No external documentation lookup was necessary for these source/specification comparisons. The audit PDF was not re-audited. The current round's REMEDIATION_PRD.md and all reviewers directories were not read.

## Findings

### Astra-01 — Hook-zero rollback repair is still absent, including its contradictory tests

- **Severity:** Medium, as specified by REQ-C04 / Stage-1 REQ-01.
- **File and line:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:600-618`; consumers at `:565`, `:590`, and `:524-545`.
- **Remediation ID:** REQ-C04; Stage-1 REQ-01 / OD-08. This is not the RC-06 helper repair.
- **Intended behavior:** REQ-C04 PRD lines 15-17 and 41-46 require either hook preview returning zero to revert the parent, without switching modes or committing a new holder reserve. Only a successful Standard Exchange preview of zero permits book-and-wait.
- **Observed fact:** Both hook-preview branches still `return 0`. Both loops still break on a zero LP result. The caller can then try the other mode and ultimately update the local reserve. The comments at lines 543-549 and 612-613 still teach the withdrawn interpretation.
- **Required-test fact:** `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/UniswapV4DetfLeftoverPreview.t.sol:52-83` explicitly expects single-asset continuation following a zero proportional preview. `.../detf/prod-se/UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol:35-56` treats an SE zero and hook zero as alternative successful retention signals. `.../detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol:16,26,46-57` retains the prohibited explanatory text.
- **Broken invariant / impact class:** Error propagation and residual accounting: a required rollback is translated into successful continuation or booking.
- **Inference:** The current tests reinforce the nonconforming behavior rather than witnessing the repair. No financial-loss claim or runtime demonstration is made.
- **Fix direction:** Revert at both zero hook previews; remove the zero-result loop exits; keep the terminal custody sync for genuinely completed attempts; rewrite the named comments and tests to require rollback, unchanged reserves, and no fallback. Preserve the existing successful SE-zero path.
- **Confidence:** High.

### Astra-02 — Legacy V4 holder repair substitutes a forbidden delegate path for the required internal settlement

- **Severity:** Low. The confirmation PRD uses Medium for the earlier caller-identity nonconformance; current code passes the holder explicitly and preserves caller identity. The remaining demonstrated impact is architectural/specification conformance, not an authorization bypass.
- **File and line:** `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol:26-35`; `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInExecutionDelegate.sol:12-18`.
- **Remediation ID:** RC-01 / REQ-C01.
- **Intended behavior:** Explicit-holder PRD lines 17, 78-80, and 107 require these two families to call inherited settlement internally, not a different execution delegate. Its plan line 140 explicitly says not to move the yield path onto a delegate to meet the runtime limit.
- **Observed fact:** The V4 query target now contains only preview/discovery functionality. The new execution target delegates to `executeNamedHolderRedemption`, an external holder-taking wrapper on the execution delegate. The wrapper then calls the shared settlement. In contrast, V3's new execution target calls `_executeZapOutExactIn` internally at line 29.
- **Broken invariant / impact class:** Required settlement-reuse architecture. Removal of a self-call is necessary but is not the entire specified repair.
- **Inference:** The holder and burn semantics appear improved, but this cannot be marked fully applied against the supplied controlling specification. This is **not** a call to self and is not described as one. No arbitrary-wallet burn is established by this observation.
- **Fix direction:** Use the inherited internal settlement on legacy V4 as specified, retaining one guard and the post-settlement TWAP update. Do not restore a self-call. If runtime size prevents that shape, report the constraint for an explicit specification decision rather than silently accepting the delegate alternative.
- **Confidence:** High.

### Astra-03 — Matrix controls still accept unrelated matching failures and do not prove exact share consumption

- **Severity:** Medium, matching Stage-1 REQ-04.
- **File and line:** `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol:216-225,260-282`; `.../dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol:317-325`.
- **Remediation ID:** Stage-1 REQ-04 / R10.3 / R2.4.
- **Intended behavior:** Second-audit-readiness PRD lines 246-250 require an exact family rounding error or a measured successful zero-output/retained-book result, including the branch precondition, and exact share movement.
- **Observed fact:** Weighted derives its expected revert from whatever the preview returned on failure. Dual accepts any execution error selector matching a failed preview, in addition to two named selectors. The same `previewMatch` escape appears in orbital, single-CP, Balancer-quad, and curve-quad controls. Weighted's exact-output assertion still checks only that SE shares decreased, not their exact consumption. Equivalent strict-decrease assertions remain in those sibling behaviors.
- **Broken invariant / impact class:** Test gap / false-positive coverage. Matching preview and execution failures is not an independent oracle for rounding; a strict decrease does not establish that only the required shares were burned.
- **Inference:** A shared unrelated failure can satisfy the rounding control, and an excessive positive share debit can satisfy the share-decrease check. This is not a claim that current production performs such a debit.
- **Fix direction:** Establish the rounding precondition and pin the permitted family result independently of the observed failed preview. Reconcile the actual SE debit with the precise expected consumption, output, and retained book. Do not replace these with broad revert or range checks.
- **Confidence:** High for the cited bodies and sibling search hits. Full seven-family acceptance remains unverified.

### Astra-04 — README still claims excess exact-input pretransfer must revert

- **Severity:** Low, matching September council RC-04.
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/README.md:38`.
- **Remediation ID:** September council RC-04, not REQ-C05.
- **Intended behavior:** September council PRD lines 124-128 require comments to state sufficiency, not equality of the entire surplus: exact-in credits the declared amount when available credit is sufficient and does not refund the remainder.
- **Observed fact:** Line 32 correctly says excess push does not revert merely for being excess. Line 38 contradicts it: “An exact-in call whose declared amount differs from that surplus reverts.”
- **Broken invariant / impact class:** Documentation consistency with the executable credit rule; security-critical integrator guidance.
- **Inference:** An editor or integrator can still infer the withdrawn whole-surplus equality rule. The later C05 edits correctly repair deleted-V3 and self-call prose, but do not close this independent September requirement.
- **Fix direction:** Replace the equality claim with the insufficient-credit rule, preserving the accepted donor-risk warning and prohibition on spending booked inventory.
- **Confidence:** High.

### Astra-05 — Balancer callback regression checks approval cleanup on the wrong adapter

- **Severity:** Medium, matching the September council RC-01 test requirement; the inspected production lock and approval cleanup are present. This finding is limited to test coverage.
- **File and line:** `test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol:493-520`; helper `:108-122`.
- **Remediation ID:** September council RC-01.
- **Intended behavior:** The September PRD lines 77-82 and test row 230 require the exercised production adapter to leave router and Permit2 allowances at zero after successful callback-capable operation.
- **Observed fact:** The test deploys and operates on `locked_`, then calls `_assertNoMaxAllowances(probe)`. That helper queries allowances owned by the separate fixture `adapter`, not `locked_`. Its three zero checks therefore do not inspect the exercised adapter.
- **Broken invariant / impact class:** Required-test oracle bound to the wrong subject.
- **Inference:** The callback regression can report successful cleanup without establishing cleanup on its SUT instance. The production implementation visibly clears approvals; this finding does not claim a production allowance leak.
- **Fix direction:** Parameterize the helper with the actual adapter under test and assert all three allowances for `locked_`. Complete the specified exchangeIn/exchangeOut and reserve-sync coverage without using a different instance's state as the oracle.
- **Confidence:** High.

### Astra-06 — Holder-balance negatives still accept any revert

- **Severity:** Low; narrower than the original Medium caller-identity defect because this is a required-test specificity gap, not evidence that the current holder burn is wrong.
- **File and line:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol:142-151`; `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol:154-163`.
- **Remediation ID:** RC-01 explicit-holder plan, step 6; R2.4 precise-negative-test rule.
- **Intended behavior:** The holder plan lines 124-127 requires insufficient holder balance rejection and unchanged balances; the production-first testing rule requires the negative to reach and identify the named condition.
- **Observed fact:** Both insufficient-holder tests use bare `vm.expectRevert()`. They do not pin the share-balance failure. The V3 file also falls within the scanner's unconditional Uniswap suite root (`scripts/apex_bare_expectrevert_scan.sh:14-29`).
- **Broken invariant / impact class:** Test gap; unrelated quote, pool, or rounding failures can satisfy a test named for holder insufficiency.
- **Inference:** Balance rollback assertions alone cannot distinguish those failure causes. No test execution or scanner result is claimed.
- **Fix direction:** Prepare a payable nonzero-output route, pin the actual holder-balance error and quantities, and retain unchanged holder/vault/recipient assertions in both families.
- **Confidence:** High.

## Verdict table

IDs are namespaced to avoid conflating the September RC numbers with October's unrelated RC numbers. Evidence paths below are repository-relative; shortened basenames refer to the full paths in the findings or examined-files section. `Unverified` rows explicitly identify the unclosed evidence boundary.

| ID | Verdict | Evidence file:line |
|---|---|---|
| October RC-01, REQ-C01 | partial | `UniswapV4StandardYieldExecutionTarget.sol:26-35`; explicit holder and caller check exist, but Astra-02 and Astra-06 remain |
| REQ-C02, V3 ordinary holder | partial | `UniswapV3FullSpreadStandardYieldExecutionTarget.sol:18-29`; `UniswapV3FullSpreadVaultHeldRedeem.t.sol:105-121,142-151`; intended caller burn restored, required negative remains weak |
| October RC-02 | applied | `CamelotV2StandardExchangeOutTarget.sol:761-768`; `CamelotV2ZapOutMaxAmountIn.t.sol:33-83` covers both flags and exact funded payout |
| October RC-03 | unverified | `contracts/protocols/dexes/uniswap/` lists only v2/v4; V3 Common `:909-916` uses local book. No old package construction found in contracts/scripts/tests searches; not every migration caller/test body was reviewed |
| October RC-04 / REQ-C03 | applied | V3 Common `:282-283,520-536`; `UniswapV3FullSpreadExactOutputFill.t.sol:79-139,219-248`: distinct accepted-quote settlement witness, unchanged caller input, quiet-token success control; execution unverified |
| October RC-05 | applied | `RocketPoolRETHStandardExchangeCommon.sol:455-467,511-518`; `RocketPoolSleeveExcessStake.t.sol:17-69` |
| October RC-06 | applied | `UniswapV4DetfCommon.sol:625-645`; `UniswapV4DetfLeftoverPreview.t.sol:39-49,87-116`; actual SE preview and full-local-book rule, not hook-zero closure |
| REQ-C04 / Stage-1 REQ-01 / OD-08 hook-zero | not applied | `UniswapV4DetfCommon.sol:605,615,565,590`; Astra-01 |
| REQ-C05 | applied | Uniswap `README.md:3,13,56`; old V3 absent and legacy V4 retained; separate September prose defect remains |
| REQ-C06 | unverified | Named source branches conform: V3 OutExecute `:81-87`, OutExecutionDelegate `:108-113`; hookless/Pons OutExecute `:100-104,139-141,169-171`. Three `ApexRecurrenceErrorOrder.t.sol` suites contain caller/credit/funded/false-flag controls. Exhaustive additional-active-path search and all route variants not closed |
| October RC-07 script repair | not a current requirement | FIX_PRD `:18`: “Do not repair it. EIP-170 still applies at deploy.” |
| Earlier preserve-self-call repair | not a current requirement | FIX_PRD `:24`: “That repair is withdrawn. The self-call is the design error.” |
| Earlier preserve old V3 / patch its subtraction | not a current requirement | FIX_PRD `:174`: “Delete the old Uniswap V3 Standard Exchange … Do not rewrite it in place and do not keep a copy.” |
| Earlier never-combine Rocket credits | not a current requirement | FIX_PRD `:246`: small amounts sit together in the sleeve; no per-deposit ledger |
| Stage-1 REQ-02 | unverified | `UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:384-388` remains a direct preview; full caller zero/revert regression inventory not reviewed |
| Stage-1 REQ-03 | unverified | `RebasingAwareERC4626_Adversarial.t.sol:50-60,128-146`, `_Fuzz.t.sol:57-100`, scanner `:18-26` show targeted edits; nested-error oracle and complete D16 scanner inventory not established |
| Stage-1 REQ-04 | partial | weighted matrix `:216-225,282`, dual matrix `:317-325`; Astra-03 |
| Stage-1 REQ-05 | unverified | hookless `AttributionAndBooking.t.sol:34-42`, Pons counterpart `:37-45` found; all four complete outside-trade/following-credit witnesses were not body-reviewed |
| Stage-1 REQ-06 / OD-03 | unverified | `ReceiptBackedERC4626Target.sol:67-80,153-195` follows share-cap direction; shared behavior `:172-234` includes non-unit, receipt-limited and zero-preview cases. Both dispatched-family bindings and every maximality/rejection assertion not verified |
| Stage-1 REQ-07 / OD-02 | unverified | `StandardExchangeRateProviderFacet.sol:61-82,112-125` removes gas-gated self-snapshot; complete required test witnesses not reviewed |
| Stage-1 REQ-08 | unverified | Controlling PRD `:316-320` requires current-source map and regenerated execution evidence; neither current identity nor builds/selectors/sizes/regressions verified this round |
| September council RC-01 | partial | `BalancerV3SinglePoolStandardExchange.sol:86,147,269-282` has lock/finite approval/reset; callback regression `:520` checks wrong instance (Astra-05) |
| September council RC-02 | unverified | `ERC4626StandardExchangeCommon.sol:117-127` uses exact-asset withdrawal; `ERC4626StandardExchange_APEX_R14.t.sol:163-195` checks payout. Required composing orbital witness not fully verified |
| September council RC-03 | unverified | Stata Common `:108-110` uses shared backing; accounting lib `:23-38` includes booked extras; Stata R14 test `:124-148` compares preview. Full transition/issuance/redemption witness set not verified |
| September council RC-04 | partial | Uniswap `README.md:38` still contradicts declared-credit sufficiency (Astra-04) |
| September council RC-05 | unverified | Search of `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol` found no second public `exchangeOut`; installed-selector preservation and surface regression not fully reviewed |
| September council RC-06 | unverified | orbital Common `:711-726` removes unused share return and retains capped approval/reset/short-delivery check; complete updated-caller/test inventory not verified |
| September council RC-07 | unverified | BasicVaultCommon `:33-38` preserves historical base semantics; Uni V2/Camelot/Aerodrome Common overrides use LocalCreditLib. All D16 consumers and required route coverage not verified |
| September council RC-08 | unverified | Uni V2 OutTarget `:585,991-996` has named backing check; security test `:359-381` claims authorized focused fallback. Full reachability justification and production-helper equivalence not closed |

## Examined files with no defect identified in the inspected requirement-specific portions

These are limited positive observations, not whole-file approvals. Long files were read at the relevant functions, sometimes supplemented by scoped searches.

- `contracts/utils/LocalCreditLib.sol:7-28` — saturated availability, capped credit, bytecode gate.
- `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:29-71` — internal-balance starter gate before held-share check; no exchange self-call in the inspected shared route.
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol:1-57` and `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol:1-61` — now preview/discovery targets, not the current redemption implementation.
- Legacy V4 `UniswapV4StandardExchangeCommon.sol:1301-1318` — forbidden self-recognition branch removed; real share pretransfer retains caller/credit checks.
- Legacy V4 `UniswapV4StandardExchangeInBase.sol:146-200` and V3 `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:212-259` — both burn paths use the supplied holder.
- V3 `UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate.sol:19-25`, `UniswapV3FullSpreadStandardYieldExecutionTarget.sol:12-29`, Common `:506-537,909-920`, OutExecuteTarget `:68-95`, and OutExecutionDelegate `:14-69,93-126` — holder wrapper, fill check, local credit, and named caller-before-credit comparisons observed.
- Hookless and Pons `*OutExecuteTarget.sol:86-186` and `*StandardYieldExecutionTarget.sol:6-15` — named short-credit checks authenticate first; no direct self-call in the inspected yield overrides.
- `CamelotV2StandardExchangeOutTarget.sol:751-768`, `CamelotV2ZapOutMaxAmountIn.t.sol:11-84`, `RocketPoolRETHStandardExchangeCommon.sol:455-518`, and `RocketPoolSleeveExcessStake.t.sol:8-70` — the scoped repairs and focused assertions match.
- `UniswapV3FullSpreadExactOutputFill.t.sol:15-17,79-139,219-248` — unlike the prior confirmation claim, a separate settlement witness is now present. It is not relabeled quote-only coverage.
- `ReceiptBackedERC4626Target.sol:67-80,153-195`, `ReceiptBackedERC4626AccountingLib.sol:18-69`, `ERC4626StandardExchangeCommon.sol:117-127,237-280`, `StandardExchangeRateProviderFacet.sol:61-125`, and single-CP ClaimLib `:384-388` — inspected source changes align; full test closure remains as tabled.
- The three `ApexRecurrenceErrorOrder.t.sol` suites at V3 release, hookless, and Pons paths — inspected positive and negative assertions distinguish code-less and contract callers.

Production searches located 24 `_redeemVaultHeld`/`_standardRoute` definitions in 21 files. The V3/V4 moved targets and hookless/Pons targets were followed; search evidence also showed direct vault burns in ERC-4626, Stata, Lido, Rocket and EtherFi. This is not claimed as a complete body-level certification of all 21 files. Searches for old V3 package construction across contracts, scripts, and tests found no `deployUniswapV3StandardExchangeDFPkg` construction; Crane's V3 protocol imports are not the deleted IndexedEx package.

## Unresolved dissent and evidence gaps

- No peer conclusions were consulted, so no cross-review agreement or dissent is asserted.
- The explicit-holder specification unambiguously excludes the current legacy V4 delegate alternative. A later owner authorization accepting that alternative was not supplied. I cannot infer one from refactoring or possible size pressure. Current explicit-holder behavior is not equated with the old identity-changing self-call.
- REQ-C06's prose says caller authentication precedes measuring credit, whereas its plan places the check before the short-credit comparison. Some named paths still compute credit for quote construction before authentication, but authenticate before the named insufficient-credit rejection. I do not report that ordering nuance as an authorization defect; exhaustive diagnostic behavior remains unverified.
- The source changes needed for many September items are visible, but the complete required test sets, all family dispatch bindings, all additional active pretransfer branches, and every production override were not fully read. Those IDs remain unverified rather than guessed complete or falsely declared missing.
- The settlement witness is structurally distinct from quote rejection; whether it executes successfully on the current artifacts was not tested. The same execution limitation applies to every positive observation.
- No current-source map, artifact provenance, runtime-size result, selector inventory, or passing regression count is certified. Ignoring RC-07 does not waive Stage-1 REQ-08 or EIP-170.
- No live-instance remediation, permanent loss, or exploitability claim is made. No exploit procedures or payloads are included.

**I did not run Forge.** Only this assigned Markdown report was written. The remaining evidence gaps prevent a claim of complete remediation application or audit readiness.
