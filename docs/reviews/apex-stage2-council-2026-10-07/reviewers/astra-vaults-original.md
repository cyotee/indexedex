# Astra — A-vaults independent original

## Status, identity and boundaries

**PARTIAL_REPORT; inspection only.** Reviewer: Astra, assignment A-vaults, primary coverage C02–C05. This is an independent first pass, not a cross-review or a replacement session. No shell, compilation, tests, forks, RPC, deployment, delegation, or code/test/config changes were performed. Only this report was written. No current-wave peer outputs were read.

Last supplied identity, not recomputed here: IndexedEx `5709cb3507a9df72b11ec476d27b79ef88696c3a`; Crane `b35609951b4951a3c107e267e22844a50c4dc043`; content hash `82e1f83932a7149cacb7269cdcf90001541cc31306f54407e8037a6597eb5c32`; captured 2026-10-07T20:54:31Z. The header of `docs/research/apex-stage2-review/recurrence-20261007/evidence/source-before-build.json:1–5` agrees with the supplied identity. Current reads were not independently hashed against that manifest. ApexRecurrence source drift and the incomplete build log are not successful verification evidence.

All findings below have execution-evidence state **MISSING**, outcome **UNKNOWN**, for this session. Stage-1 named passes remain reported claims with incomplete provenance here, not invented failures or current PASS results. No runtime loss or successful adversarial execution is claimed.

Read authority: `CLAUDE.md`; Stage-2 PRD and plan; readiness `REMEDIATION_PRD.md` and `STAGE1_EVIDENCE.md`; relevant original APEX PRD/plan sections, particularly D9/D12/D15/D16 and R2/R3/R7/R9; Wings PRD including O1–O7/A3 and its acceptance section; agent-law token/route sections; skill catalog and all four assigned canonical testing/adversarial SKILL.md files. Historical `accepted-20261007/REPORT.md` was consulted only as the assignment-supplied claims index after independent source inspection; its linked reviewer artifacts were not opened. No attempted supplied path was missing. Large original APEX documents were read selectively, not certified as fully reconciled.

### Citation roots

Repository-relative aliases below expand as follows. A basename following an alias identifies that exact file, not another product's corresponding implementation.

- **V3** = `contracts/vaults/standard/exchange/protocols/uniswap/v3/`
- **H** = `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/`
- **P** = `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/`
- **W** = `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`
- **TV3** = `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/`
- **TH**, **TP**, **TW** = the matching `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/` product directories for H, P and W.

## Findings

### Astra-AV-01 — Native SY internal redemption loses the initiating-caller bytecode gate

- **Class / severity / confidence:** CODE_DEFECT / Medium / High for control flow; Medium for Wings' precise inherited-policy applicability.
- **File and line:** `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:34–42,59–63,115–118`; V3 `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:907–913`; H `UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol:951–961`; P `UniswapV4FullSpreadPonsFamilyHookCommon.sol:951–961`; W `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:147–157,171`.
- **Intended behavior:** APEX plan D9, line 99, expressly requires the bytecode gate on external SY internal-balance redemption. D12 permits non-atomic resting credit for contract callers, not an EOA exception. Wings inherits applicable shared custody/security rules under its PRD §6 and §9; its distinct O1/O3 residual law does not waive caller authentication.
- **Broken requirement:** Authenticate the external initiating caller before changing call identity to the vault.
- **Observed facts:** The adapter checks token/amount/receiver but not initiating bytecode, records any nonzero initiator, then self-calls the false-pretransfer standard route. V3, H and P accept requested self-held shares on the self-call/nonzero-context predicate, without inspecting initiator bytecode. W inherits the adapter without an override; its false-flag redemption selects `msg.sender`, which is now the vault, and checks/burns that holder's shares. Its pushed-only gate is not reached.
- **Inference / impact class:** Caller-policy bypass on redemption of shares already held by the vault. Applicability is confirmed separately for V3, H and P. The same mechanical bypass exists for W; the shared-policy reading is supported, while W is not literally named in the historical D16 list.
- **Counterevidence:** This does **not** authorize burning an arbitrary third-party wallet's shares. The selected holder is the vault and the amount remains bounded by its share balance; FullSpread's internal holder path is intentionally allowed to use self-held shares. D12 already accepts resting-share exposure to contract callers. These facts refute a universal wallet-theft claim and limit severity, but do not satisfy D9. No ownership-attribution mechanism is recommended.
- **Readiness:** BLOCKS closure of the FullSpread external-SY caller gate; W's shared-gate acceptance remains implicated independently, not inferred from FullSpread accounting.
- **Fix direction:** Authenticate the initiating caller at the external internal-balance boundary before self-call; preserve exact requested burn, context restoration, and valid atomic contract integrations. Add distinct self-held versus third-party-held share assertions for each product.
- **Stage-1 relationship:** Broader original-program/new-product coverage, not the repaired RebasingAware custody REQ-03 path; no Stage-1 regression attribution established.

### Astra-AV-02 — V3 direct exact-output accepts a partial-fill quote and never checks delivered output

- **Class / severity / confidence:** CODE_DEFECT / Medium / High for omission and quote semantics; execution reachability not run.
- **File and line:** V3 `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:253–279,500–525`; V3 `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:68–95`; Crane `lib/crane/contracts/utils/math/UniswapV3Quoter.sol:141–158`.
- **Intended behavior:** Supported exact-output operations deliver the requested output or revert, with actual-used input bounded by the caller maximum (APEX R3/D15 and the standard exchange route contract).
- **Broken invariant:** A successful exact-output result must establish output fulfillment, not merely sufficient input payment.
- **Observed facts:** Crane's quote may stop at its price limit with remaining requested output; it returns `fullyFilled=false` and the actual partial `amountOut`. V3 `_quoteSwapOut` returns only `quote.amountIn`. `_swapExactOut` reads the positive input delta and checks the maximum, but never verifies the output delta against `amountOut`. Its caller checks input delivery, refunds where applicable, and synchronizes; it adds no output check.
- **Inference / impact class:** A pool-limit partial fill can be priced and treated as a successful exact-output operation, leaving a recipient or consumer underfunded relative to its requested output. No particular transaction, loss size or downstream extraction is demonstrated. A later rebalance can revert some states; that is not a fulfillment invariant.
- **Counterevidence / sibling search:** H `UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService.sol:113–140` rejects a nonmatching exact-output quote; H Common `:1101–1117` checks actual output equality. P independently has equivalent exact-fill checks in its own QuoteService `:115–145` and Common `:1101–1117`, including its separate fee computation. W exposes no direct token-pair swap route; W Money `:161–173,190–208` funds its target obligation and checks recipient receipt. This finding is **V3-only**, not all FullSpread or Wings.
- **Readiness:** BLOCKS V3 direct exact-output acceptance.
- **Fix direction:** Reject incomplete exact-output quotes and verify the executed output amount independently at settlement; retain exact used-input/max and refund rules. Cover limited-fill rejection and an adjacent funded successful route through the production proxy.
- **Stage-1 relationship:** Broader C02 quote/execution review, not an established regression of a Stage-1 repair.

### Astra-AV-03 — V3 wallet-funded Native SY redemption is incorrectly routed through the contract-only push gate

- **Class / severity / confidence:** CODE_DEFECT / Medium / High.
- **File and line:** V3 `UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol:18–29`; V3 `UniswapV3FullSpreadStandardExchangeVaultInTarget.sol:58–61`; V3 Common `:852–862,907–913`.
- **Intended behavior:** External wallet-funded SY redemption consumes the initiating holder's own requested shares. APEX's bytecode restriction applies to public pretransfer/internal-balance credit, not every ordinary holder withdrawal. The FullSpread native-SY route description preserves caller-funded redemption without share allowance.
- **Broken invariant:** An ordinary false-internal-balance owner redemption must not become unsupported solely because an internal implementation transfer is presented as public push credit.
- **Observed facts:** The V3 override transfers shares from `msg.sender` to the vault, builds a standard route with pretransfer enabled, and delegatecalls it. The original EOA remains `msg.sender`; the share-delivery helper reaches `requirePretransferCaller` and rejects it. The transfer rolls back.
- **Inference / impact class:** Loss of direct Native SY exit availability for code-less holders, despite ownership and otherwise sufficient funding. This is not fund theft or permanent loss: alternative standard exchange exits may remain available.
- **Counterevidence:** `release/sy/UniswapV3FullSpreadStandardExchangeVault_NativeSY.t.sol:85–94` tests caller redemption from the test contract, so it exercises the allowed contract case and does not refute the EOA failure. H and P do not retain this override: their ordinary false-flag share helper transfers the original caller's shares. W directly burns the false-flag caller's balance. No equivalent defect was established for those products.
- **Readiness:** BLOCKS the V3 native-SY external-holder route claim.
- **Fix direction:** Preserve authenticated owner-funded share delivery without reclassifying it as public pretransfer. Do not weaken the public push gate. Require separate EOA and contract owner-redemption controls and separate internal-balance negatives.
- **Stage-1 relationship:** Broader native-SY coverage; not REQ-03 custody remediation.

### Astra-AV-04 — FullSpread exact-output funding diagnostics can precede the required EOA rejection

- **Class / severity / confidence:** CODE_DEFECT / Low / High.
- **File and line:** V3 `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:77–86`, Common `:897–904,855–856`; H `UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:159–165`, Common `:941–948`; P `UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol:159–165`, Common `:941–948`.
- **Intended behavior:** D9/R13 identify `EOAPretransferNotAllowed()` as the rejection for code-less public pretransfer callers.
- **Broken requirement:** The specified caller diagnostic must not be replaced by a funding diagnostic on an otherwise supported quote path.
- **Observed facts:** Each listed direct exact-output implementation calculates available credit and may reject short funding before `_secureTokenTransfer` performs the bytecode check. Their `_pretransferCredit` helpers contain arithmetic only.
- **Impact class / inference:** Error-contract nonconformance and weaker exact-error testability, **not** an authorization bypass: the underfunded path still reverts. This is distinct from AV-01's missing gate on a successful route.
- **Counterevidence:** Sufficient-credit EOAs reach the bytecode guard. W's `pretransferBudget` checks caller bytecode before credit; the same shortage-before-gate claim is not established there. Other unrelated route/quote errors are not asserted to require this precedence.
- **Readiness:** BLOCKS the exact diagnostic criterion, not evidence of principal loss.
- **Fix direction:** Place caller validation before funding-credit evaluation on these supported public push branches, or obtain an explicit scoped diagnostic-policy amendment; retain all funding checks.
- **Stage-1 / history:** Original-program coverage. Historical A-F01 is supported for the specifically re-read direct exact-output sites. The historical multi-output sites were not re-inspected and remain unverified here.

### Astra-AV-05 — Wings security negatives permit unrelated reverts

- **Class / severity / confidence:** TEST_DEFICIENCY / Low / High.
- **File and line:** TW `UniswapV4UpperLowerWingsStandardExchangeVaultSecurity.t.sol:29–42`; TW `UniswapV4UpperLowerWingsStandardExchangeVaultTokens.t.sol:26–31,53–91`.
- **Intended behavior:** APEX R2.4 and Stage-2 S2-REQ-08 require precise intended errors, reachable branch preconditions, and unchanged affected state. Wings retains these security requirements.
- **Broken requirement:** A test of a named ownership, delivery, token-policy or reentrancy guard must distinguish that guard from an unrelated failure.
- **Observed facts:** Six negative expectations are bare `expectRevert`: one ownership negative and five token negatives. The hostile token stores only callback attempted/succeeded, discarding revert data. The reentrancy/economic-read test asserts only attempted and unsuccessful. Consequently wrong-route, unrelated valuation or other failures can satisfy those rejection assertions.
- **Impact class / inference:** False-positive security coverage. This does not establish a production guard defect. The present assertions are deficient independently of whether tests have been executed.
- **Counterevidence:** These are real configured hostile underlyings and real vault packages, not mocked vaults. Several checks assert balance/supply rollback; other Wings tests pin deadline, minimum and caller errors. Those useful controls should remain.
- **Readiness:** BLOCKS closure of the affected exact-error properties, not all Wings testing.
- **Fix direction:** Assert the intended typed error and relevant data after establishing its preconditions; preserve callback failure data and assert the actual guard, along with balance/share/book/position rollback and a funded positive control.
- **Stage-1 / history:** Historical A-F02 is supported against current test source. This is Wings coverage, not a recurrence of the separately repaired custody REQ-03 tests.

### Astra-AV-06 — Wings stateful campaign does not require successful operations

- **Class / severity / confidence:** TEST_DEFICIENCY / Medium / High.
- **File and line:** TW `UniswapV4UpperLowerWingsStandardExchangeVaultInvariant.t.sol:33–50,57–89`.
- **Intended behavior:** APEX D4/R11 success-counter requirements, Wings O2/O7 and §14 stateful verification, and S2-REQ-08 non-vacuity.
- **Broken invariant of the test:** A campaign claimed to exercise custody and positive value through trading, deposits, withdrawals and maintenance must demonstrate meaningful successful transitions.
- **Observed facts:** Every handler action catches and suppresses all failures. Setup calls the same catching deposit without checking success. Deposit/withdrawal counters exist but are never asserted; market/maintenance success counters are absent. The positive-value condition is conditional on nonzero supply.
- **Inference / impact class:** A zero-success campaign can satisfy initial custody, zero-supply and cash-accounting assertions while never testing positive-value preservation. Even a successful initial deposit does not prove later action coverage. This is vacuous campaign acceptance, not proof that an actual supplied campaign was vacuous.
- **Counterevidence:** The fixture deploys real products and external liquidity. Deterministic Money/Rebalance tests contain funded successful operations and substantive assertions. The invariant is useful when the actions succeed; those facts do not enforce campaign success coverage.
- **Readiness:** BLOCKS Wings stateful acceptance.
- **Fix direction:** Require successful initialization and campaign-end success coverage for applicable money, market and maintenance actions. Classify permitted rejections rather than silently accepting all failures. Keep safety assertions active through zero-supply and reactivation lifecycle states.
- **Stage-1 / history:** Current Wings supplement; historical A-F03 is supported. Not an established Stage-1 production regression.

### Astra-AV-07 — Four-vault execution closure lacks a current source-bound result in the supplied evidence

- **Class / severity / confidence:** EVIDENCE_GAP / Informational / High for this review's evidence boundary.
- **File and line:** `docs/reviews/apex-2026-09-17-second-audit-readiness/STAGE1_EVIDENCE.md:7–9,30–43`; recurrence `source-before-build.json:1–5`; user-supplied incomplete `full-build.log` description.
- **Intended behavior:** S2-REQ-09 and APEX R1/R11/R12 require identity, executed artifact/test selection and completed outcome for claimed verification.
- **Missing requirement / observed facts:** The note expressly is not a release identity, reports named passes, and does not establish their full artifact/source causality. The recurrence identity predates known test drift. A line saying compilation started is not a completed build or test result. No source-bound completed result was established for this assignment.
- **Impact class:** Provenance/readiness uncertainty, not a code defect or an allegation that Stage 1 did not run.
- **Counterevidence:** Stage-1 owner acceptance is established and is not being reopened. Named tests and meaningful source assertions exist. The supplied identity is useful but cannot alone prove execution.
- **Readiness:** BLOCKS a current regression-verified closure claim for C02, C03, C04 and C05 independently; it does not prohibit delivery of this inspection report.
- **Fix direction:** Have the evidence lane bind existing completed records to source, dependencies and deployed artifacts, or commission separate authorized verification. Do not turn missing evidence into invented PASS or automatic production remediation.
- **Stage-1 relationship:** REQ-05/REQ-08 evidence continuity only; no determination here that a production repair regressed.

## Four independent vault conclusions and outside-trade tests

For every row: applicability **APPLICABLE**; review state **PARTIAL**; execution **MISSING / UNKNOWN**. Findings identify contradictions; other observations are inspection-only and do not close the entire product.

| Product | Inspected source and test result | Limit |
|---|---|---|
| C02 V3 FullSpread | AV-01/02/03/04. TV3 `UniswapV3FullSpreadStandardExchangeVault_FeeCompound.t.sol:50–75` seeds incumbent shares, trades directly through the real pool helper, checks both books and supply unchanged, then checks funded-deposit preview/return and recipient shares. Its TestBase `:105–124,161–174` uses manager/package deployment and a pool call rather than a vault swap. | The named test does not independently assert payer asset debit, changed market/deployed state or unfunded post-trade rejection. Preview parity alone is not independent proof of economically correct credit. Broader R3 closure is not inferred. |
| C03 V4 hookless FullSpread | AV-01/04; V3 AV-02 is not present in the inspected direct exact-output checks. TH `AttributionAndBooking.t.sol:34–49` checks unchanged books/supply then funded share delta and final custody; `:51–56` separately pins no-credit-after-repricing. Acceptance TestBase `:95–125` executes a direct PoolManager swap. | The named positive uses the vault's own preview as expected shares and does not assert payer debit or a market-state delta. The companion negative is useful counterevidence against declaring the entire file vacuous. Full deployment/consumer matrix not closed. |
| C04 V4 Pons-family FullSpread | Independently re-read P helpers, direct executor, quote/planner and tests: AV-01/04; no AV-02 omission at the inspected exact-output site. TP `AttributionAndBooking.t.sol:37–59` has its own unchanged-book/funded-share and no-credit controls. Its Acceptance TestBase `:56–65,101–138` binds a registered Pons hook and executes a direct PoolManager swap. | No inference of hookless closure. Pons fee/protection/registration implementation is not comprehensively reviewed merely because the fixture calls registration. Same independent-credit/market-delta limitation as H. |
| C05 Wings | AV-01's mechanical path, AV-05/06. TW Money test `:26–40` uses a separately funded actor's PoolManager swap, unchanged basic-vault books/supply and funded-deposit preview parity. W Money authenticates target input before harvest, skips manager mutation when already unlocked, reserves one local target unit while supply remains, and releases it for final redemption. | The named outside-trade test asserts the returned mint, not the actual post-deposit recipient share delta or payer debit. It checks `IBasicVault` books rather than also the product's complete local-reserve tuple; Money `end` only mirrors the target there. Full liquidation/harvest/placement math and consumer domain are not closed. O1/O3 residual and first-depositor benefits are approved, not FullSpread donation defects. |

The four named outside-trade tests are present and their helper call paths are genuine external pool operations, not reserve-reconcile substitutions. Their narrower assertions should not be represented as full R3/SEC-01 coverage. I do not infer that all complementary tests are absent: this pass did not perform a complete negative-test census. Thus these limitations are recorded as **partial acceptance inspection**, not a claim that Stage-1 code regressed.

## Historical claim disposition

- Missing initiating-bytecode check: **supported** mechanically for all four products, with the policy/applicability qualification and self-held-share limit in AV-01. A universal third-party-wallet theft characterization is **refuted** by the inspected holder selection.
- V3 partial exact-output success: **supported** as a missing fulfillment invariant, not a runtime demonstration. Generalization to H/P is **refuted** at the re-read exact-fill checks; Wings direct pair-swap applicability is absent.
- Historical A-F01: **supported** for inspected direct exact-output paths, other cited multi-output paths **unverified**.
- Historical A-F02: **supported** by the six bare expectations and discarded callback errors.
- Historical A-F03: **supported** by catching setup/actions and unused counters; an assertion that an actual run had zero successes remains **unverified**.
- Four outside-trade tests: presence/call paths confirmed on inspection; full security closure and execution remain **unverified**.

## Files/portions examined with no defect found in the stated property

This is not a whole-file security certification.

- `contracts/utils/LocalCreditLib.sol:1–29`: local availability, bounded budget and bytecode guard match their stated rules.
- `lib/crane/contracts/utils/math/UniswapV3Quoter.sol:79–159`: partial completion is explicitly represented; AV-02 concerns its V3 consumer ignoring that result, not a defect in this result contract.
- `contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol:8–27` and V3 OutQueryFacet `:24–27`: redemption is included in the declared selector surface. Package cut searches located the relevant query facets in V3, H and P; installed runtime execution was not verified.
- H and P QuoteService exact-output sections and Common `_executePlannedSwap`, separately: explicit output equality, signed-delta and projected-state checks counter the V3 omission.
- H and P OutMultiQueryTarget: each inherits Native SY; neither contains V3's external-redemption override. The shared-adapter finding remains, but no AV-03 equivalent was found there.
- W SYTarget and InTarget route discovery: configured-target-only token lists/routes; no inherited direct pair-swap surface identified.
- W Money `:81–110,120–139,147–208`: selected inbound-before-harvest, no-nested-unlock, payout receipt and positive-floor orchestration match their intended structure. Their dependent mathematical routines were not fully verified.
- W OutTarget `:11–20`: required-input maximum, bounded pretransfer budget and unused-credit refund are present; no V3 direct-swap analog.
- TH/TP AttributionAndBooking and Acceptance TestBase portions cited above: meaningful custody, no-replay and post-repricing negatives; limitations of the named positives are separately recorded.
- TW PoolActor `:56–118`: actual manager swap/settlement with controller and callback checks; not a mocked SUT.
- W TestBase `:29–72`, V3 TestBase `:84–174`, and TW Rebalance fixture `:15–26`: real deployment/external-market construction visible in the inspected setup. Fresh artifact use is not established by source alone.

## Coverage not inspected and handoffs

This pass does **not** certify full C02–C05 coverage or all 108 original criteria. Not comprehensively inspected: V3 import/native/callback/rebalance paths and all multi-output/error branches; H/P complete inventory/protection/composition and unlock execution implementations, native wrapping, fee policy and registration authorization; Wings LiquidationQuote tick traversal, own-liquidity removal, Harvest/placement, fee and maintenance-loss math, complete transition-state composition and integer inversion proofs; all four package/delegate/facet selectors and artifact sizes; complete fuzz/catalog/campaign inventory; consumer/hook matrix, rate-provider nesting and gas limits. No ApexRecurrence test execution or universal absence search is claimed.

Seams needing another lane:

1. Shared custody/SY lane: other NativeStandardYieldTarget consumers, initiating-caller semantics, and independent corroboration of AV-01/03.
2. Quote/consumer lane: V3 partial-output handling at downstream callers; no automatic inference of consumer loss.
3. Wings math/consumer lane: whole-book realizability, A3 preview/execute projection, O4 cost accounting, O7 floor under all transitions, exact-output inversion and expanded consumer configurations.
4. Release/evidence lane: current identity including drift, artifact freshness, all package cuts/runtime sizes, and source-bound named outside-trade/campaign outcomes.

No missing read, guard denial or tool failure occurred. No external library/API documentation claim was needed: conclusions use local source and product law, so no proprietary source was sent externally. The absence of execution, incomplete source hashing and deliberately bounded coverage remain material limitations. Seven findings are preserved above; no remediation PRD or implementation is authorized. Return to coordinator and stop for the human; no cross-review begun.
