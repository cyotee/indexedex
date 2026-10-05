# Independent first pass — Astra

## Scope and assumptions

- Reviewer: **Astra**, independent first pass. Review date: 2026-10-03. This report preserves this session's original findings; no peer reports were read. The coordinator's continuation requested that exploration stop and that unverified items be identified explicitly.
- Read-only inspection only. No shell, tests, build, git, deployment, chain access, or delegated review was performed. Only this assigned report was written. Consequently, execution results, artifact freshness, current hashes, code sizes, and historical replay results are not independently verified here.
- Read `CLAUDE.md`, the four assigned canonical testing/adversarial skills, `docs/agent/SKILL_CATALOG.md`, relevant product-law sections, the seven-page audit PDF, the follow-up record, the open-items ledger, and all five supplied open-item PRDs. Read substantial portions of the main PRD and locked plan, including D1–D69 and acceptance requirements through R12's opening; some long tool-returned lines were truncated. Read the evidence narrative's header/integration sections and the beginning of `acceptance.json`, including the individual R1–R5 claims. This was **not a complete verification of all 108 criteria**.
- All user-supplied document paths opened successfully. Two discovery paths did not exist: the presumed `remediation/UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile.t.sol` was instead found under `release/v3/`; the presumed `SeMatrix_UniswapV2Fixture.sol` is named `SeMatrix_UniV2Fixture.sol` (located, not read). More importantly, the plan's former V4 production Common path is absent; current replacement code has moved into named FullSpread variants, discussed below.
- Intended behavior comes from the supplied requirements, including later owner decisions and the follow-up record. D12 resting contract credit is an accepted integrator risk, not a finding. D57 Slipstream deprecation is not a missing rewrite. Live immutable instances are outside source remediation; replacement verification does not establish deployment remediation.
- This is a bounded source/test-quality review, not a claim of total security. Severity below distinguishes production correctness from assurance/coverage defects. No finding contains an exploitation procedure or attack parameters.

## Completion verdict

**The claim that the current working tree is fully verified against all 108 criteria is not substantiated by this pass, and several inspected closure assertions are weaker than their requirements.**

There is substantial, observable implementation progress. `LocalCreditLib` implements the specified saturating availability, bounded budget, and bytecode guard. The inspected custody SE/SY paths burn the requested self-shares and bound exact-output refunds. Generic ERC-4626 and Morpho no longer contain the inspected whole-self-balance refund pattern. The generic wrapper books residuals and has explicit capacity/sweep logic. The shared receipt adapter synchronizes the registered reserve set after each of its four money paths. The inspected Balancer target retains its hard public-pretransfer rejection and authenticated settlement callback. These are source observations, not executed closure evidence.

However:

1. R2.4 is not satisfied across inspected in-scope tests: unqualified negative expectations remain, including one whose named ownership property is intercepted by the EOA guard.
2. Matrix rounding controls accept arbitrary production reverts, and some accounting assertions prove bounds rather than the specified exact consumption/backing relationship.
3. The cited V3 R3.3 reconciliation supplement does not exercise the independently moved, stale-book state its acceptance evidence purports to close.
4. Current V4 source identities and rate-provider behavior differ materially from the snapshot's named scope. September completion results cannot simply be carried forward to those files.

The historical sections of the evidence file were treated as historical, not current failures. The final header was treated as a claim requiring verification, not proof. This report does not infer that the September runs never happened or that all remediation has regressed.

## Test-quality verdict

**Mixed; not sufficient to certify the claimed completion.**

Good evidence in the source includes the corrected custody insufficient-pretransfer test using a contract caller and a complete `TransferDeltaInsufficient` expectation; real package-oriented matrix fixtures; weighted matrix assertions on exact output delivery and bounded refund; and the strengthened shared hook handler. In the handler's inspected section, every `cycle` performs a real join and partial exit, checks actual token/share deltas, and executes an additional action. It does not seed success counters in its constructor, and unexpected low-level trade failures are rethrown. The weighted campaign targets `cycle` and declares fail-on-revert. This is materially stronger than a setup-only or swallowed-failure invariant.

Those improvements do not cure unrelated weak tests. Test counts and a scanner that selects only some filenames/content do not establish exact-error coverage throughout D16. Matrix test-name completeness is not assertion completeness. No SUT mock was confirmed in the portions inspected; that is not a repository-wide certification that none exists.

## Second-audit readiness

**Verdict: NOT READY to submit the current tree as a completed, regression-verified implementation of this locked plan.**

The source can of course be sent to an auditor with explicit open issues; that is different from representing remediation and regression acceptance as complete. Before making the latter representation, close or explicitly disposition the findings below, map the current V4 variants and changed rate-provider behavior to approved requirements, and regenerate source-bound build/test/selector evidence for the actual submission tree. The reviewer did not run those gates and cannot attest that they pass today.

D12, Slipstream retirement, immutable deployment exposure, and documented unsupported compositions should remain explicit residuals. They are not reasons by themselves to block a source re-audit. The blockers here are test/closure defects and unresolved current-source verification, not those accepted residuals.

## Findings

### Astra-01 — Strict-negative closure excludes in-scope tests, and a named ownership test stops at the EOA guard

- **Severity:** Medium — assurance/coverage defect.
- **File and line:** `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol:38–44,112–124`; `RebasingAwareERC4626_Fuzz.t.sol:55–85`; `scripts/apex_bare_expectrevert_scan.sh:14–24`.
- **Intended behavior:** R2.4 requires the precise intended error and unchanged affected state, rejects bare `expectRevert()`, and rejects success inferred only from a return value. R5/R7 require the relevant share-burn checks, not only the contract-caller gate.
- **Broken requirement/invariant:** A passing negative must identify the intended control. The scanner's selected roots plus an `APEX` text filter do not cover every D16 test reused as remediation evidence.
- **Observed:** `test_ADV_cannotBurnOtherHolderViaInternalSy` invokes internal-balance SY redemption as `bob` with a bare expectation. The current SY implementation checks `requirePretransferCaller` at `RebasingAwareStandardYieldTarget.sol:57–59` before the burn logic. The named ownership condition therefore is not established by that test. The reentrancy test at line 122 also accepts any revert and does not record/assert the nested guard. The exact-output minimality fuzz test uses a bare expectation and checks only the successful return value. The scanner can pass without scanning these files when they lack its APEX marker.
- **Inference/impact class:** False-positive security coverage for authorization, reentrancy, and exact-output funding; unrelated failures can preserve a green result. This does not establish that the production guards are broken.
- **Fix direction:** Pin the intended error, prepare an allowed contract caller for the internal-share check, record the nested reentrancy result, assert full relevant state/deltas, and select the complete D16 regression inventory rather than relying on an APEX text marker. Keep separate EOA-gate controls.
- **Confidence:** High.
- **Evidence class:** Observed source/test behavior, with the coverage impact inferred.

### Astra-02 — Matrix rounding controls swallow arbitrary failures; accounting bounds are weaker than the required property

- **Severity:** Medium — test-quality and completion defect.
- **File and line:** `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol:177–216,236–258,369–383`. Same catch pattern located in dual `:299–305`, orbital `:290–296`, single non-CP `:270–281`, single-CP `:268–274`, Balancer quad `:320–326`, curve quad `:268–274` matrix behaviors.
- **Intended behavior:** R10.3 and open-item-1 §6 require reachable rounding/partial-consumption controls, actual consumed amount, backing/refund reconciliation, and no weaker stand-in. R2.4 requires exact errors; M7 substitutes a rounding-to-zero control only for families with no leftover case.
- **Broken requirement/invariant:** A rounding test must distinguish the specified rounding outcome from an unexpected dependency, wiring, or accounting failure. A named accounting property must be supported by its assertions.
- **Observed:** Weighted `_roundingToZeroControl` catches every revert and passes if two balances are unchanged. Transaction rollback makes those checks compatible with any revert reason; there is no assertion that the intended zero-output branch was reached. The partial-consumption branch checks a range for the booked increase rather than measuring the underlying's actual consumption and reconciling the exact remainder. The exact-output test's comment says the SE burned only what it used, but its SE-share assertion is merely a strict decrease. The AMM separation test does not assert a nonzero prepared unpaired book before comparing its ending lower bound.
- **Inference/impact class:** Overstated matrix coverage. A row can pass its rounding control without testing rounding at all; accounting regressions within the asserted ranges can remain undetected. Other controls in that row may still be meaningful, so the entire matrix is not declared vacuous.
- **Fix direction:** Pin family-specific expected rounding errors or assert a successful measured zero-output/retention outcome; assert the branch preconditions. Reconcile actual dependency consumption, credited amount, book change, and exact SE-share movement. For D33, explicitly establish the required nonzero unpaired inventory and isolate caller input.
- **Confidence:** High for catch-all weakness; medium-high for the accounting coverage gap.
- **Evidence class:** Observed. No production loss is claimed from these tests alone.

### Astra-03 — The R3.3 reconciliation supplement substitutes current totals and vault-mediated trades for the stale-reserve boundary

- **Severity:** Medium — acceptance-evidence defect.
- **File and line:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile.t.sol:58–105,109–152`; `docs/audits/apex-2026-09-17-evidence/acceptance.json:249–257`.
- **Intended behavior:** R3.3 requires partial mismatch, equality and greater-than cases relative to the old stored-total baseline, and a rebalance followed by an independently funded external pool trade before the delivery test. The historical mechanism depends on pool state moving without a vault reserve synchronization.
- **Broken requirement/invariant:** Evidence cited for a stale-book condition must actually create that condition, not a fresh derived total or a vault operation that resynchronizes the book.
- **Observed:** The first test constructs `total = local + deployed` from current reads. The equality-named test checks that local balances are below a dust bound and deployed balances are positive; it does not establish equality with a historical stored total. The rebalance test performs a vault deposit, then `_assertCreditAfterFundedPoolTrade` trades through `vault.exchangeIn`; it immediately asserts synchronized custody before checking credit. This is not the independently moved pool state described by R3.3. The acceptance entry cites this supplement as closing the missing boundary controls.
- **Inference/impact class:** A specific completion claim is not proved by its cited test. FullSpread's inspected delivery helper uses local books correctly; this finding does not assert a reintroduction of 001-M. Other external-trade tests may cover portions of R3.3, but a complete cross-reference was not verified.
- **Fix direction:** Preserve meaningful historical-boundary controls on the appropriate preserved implementation, and verify replacement credit after an external pool action that does not run the vault's synchronization. Link those exact assertions to R3.3; do not label current `local + deployed` arithmetic as the old stale-total boundary.
- **Confidence:** High about this cited test; overall R3.3 coverage remains unverified rather than declared globally absent.
- **Evidence class:** Observed test structure and documentary claim; coverage conclusion is inference.

### Astra-04 — Receipt adapter's double-rounded redemption cap rejects otherwise deliverable full balances

- **Severity:** Low — production correctness/liveness defect.
- **File and line:** `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol:67–80,162–166`; `ReceiptBackedERC4626AccountingLib.sol:54–70`.
- **Intended behavior:** D45 and R14 require preserved receipt payout limits and coherent receipt/local accounting across interfaces. A receipt-liquidity cap should constrain receipt delivery, not reject an owner's share balance when that balance's rounded payout is deliverable.
- **Broken requirement/invariant:** When all of an owner's shares have a payable receipt entitlement, the adapter should not reduce the executable redemption solely by converting that rounded entitlement back to shares with another floor.
- **Observed:** `maxWithdraw` floors the owner's share entitlement to receipt units. `maxRedeem` then converts that amount back with floor division. With a non-integral share/receipt ratio, the result can be below the owner's balance even when held receipts cover that owner's full `previewRedeem`. `redeem` enforces this smaller result. The inspected accounting functions make both floor operations explicit.
- **Inference/impact class:** Unnecessary redemption rejection and stranded share dust; no theft or material loss magnitude is established. Search results in `ReceiptBackedERC4626_RestingCredit.t.sol:129–139` explicitly describe redeeming via `maxRedeem` to accommodate this cap, but that test file was not fully read and is not treated as proof of an approved product exception.
- **Fix direction:** Return the full owner balance when its rounded receipt payout is within actual receipt inventory; otherwise compute a share cap from the actual receipt-liquidity inequality with correct rounding and an owner-balance bound. Add non-integral-rate full-balance and receipt-limited redemption controls for both dispatched families.
- **Confidence:** High on the arithmetic; medium on practical severity.
- **Evidence class:** Observed arithmetic with inferred liveness effect. No runtime reproduction was executed.

### Astra-05 — Current rate provider adds a gas-dependent soft snapshot fallback outside the specified exception

- **Severity:** Medium — requirement deviation and valuation-assurance gap; financial exploitability unverified.
- **File and line:** `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:69–88`.
- **Intended behavior:** D48 and R10.7–R10.8 confine failed-quote fallback to `_safePreviewExchangeIn`, preserve the specified search behavior, and keep other dependency failures hard. D60 changes valuation/provider requirements but does not, in the supplied decisions, authorize gas-dependent best-effort snapshot acquisition.
- **Broken requirement/invariant:** The supplied locked exception is not blanket permission to suppress additional dependency failures or select a different valuation path based on remaining gas.
- **Observed:** For unlock-context-capable subjects, `_getRate` conditionally attempts `quoteState` according to remaining gas, forwards a bounded stipend, and falls through to a live-supply probe on failure. This differs from the inspected `_safePreviewExchangeIn` exact-length fallback, which does match D48. The adjacent comment expressly describes the new soft behavior. New `_hasContextQuote` capability probing is also present in the shared hook leg library; its broader authorization was not traced.
- **Inference/impact class:** Source behavior is no longer the narrowly described D48 rewrite. Depending on the SE, callers may observe a different quote path or failure behavior; price equality between paths was not established. This is not a proven price manipulation or fund-loss finding.
- **Fix direction:** Identify and attach any separately approved later requirement, then verify same-state rate equivalence and failure semantics across the selected paths and realistic call budgets. Otherwise restore the locked hard-call boundary. Refresh D48 evidence against the current implementation instead of inheriting the prior result.
- **Confidence:** High on deviation from supplied requirements; medium on security consequence.
- **Evidence class:** Observed branch and suppression; valuation consequences are inference.

### Astra-06 — The completion handoff does not identify the current FullSpread V4 implementation set

- **Severity:** Medium — provenance/re-audit readiness defect.
- **File and line:** `docs/audits/apex-2026-09-17-evidence.md:3,67–76`; `docs/audits/apex-2026-09-17-followup-fixes.md:104–110`; current `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol:51–83`.
- **Intended behavior:** R1.3/R12 require source and runtime identities for the actual corrected version. D3 requires old/new code to be independently identified. The user expressly requires checking the current tree rather than adopting September's snapshot.
- **Broken requirement/invariant:** A historical release attestation cannot establish verification of renamed/restructured current implementation artifacts without a current mapping and refreshed evidence.
- **Observed:** The plan's `v4/UniswapV4FullSpreadStandardExchangeVaultCommon.sol` does not exist at that path. Discovery found current hookless and Pons-family V4 Common implementations under `fullSpread/`. The hookless implementation now imports separate inventory/protection/transition-planner/quote/execution-context components and has an `operationScope` modifier. The snapshot handoff names the former package and says the plan is independently reverified; its inspected replacement section does not map these current variants.
- **Inference/impact class:** Submission identity and coverage can be mistaken. A prior green suite cannot be assumed to validate these current components. This does not prove that the refactor is unauthorized or incorrect, nor that no newer evidence exists elsewhere; no such evidence was independently examined in this pass.
- **Fix direction:** Supply an explicit snapshot-to-current package/source/selector mapping, declare the audit submission boundary, identify tests covering each current variant, and rerun source-bound build/size/regression gates under separate authorization. Preserve historical evidence rather than overwriting it.
- **Confidence:** High on path/source divergence; medium-high on the incomplete inspected handoff.
- **Evidence class:** Observed divergence; readiness consequence is inference.

## Criteria checked and unverified

The following are **inspection dispositions**, not execution attestations. No statement below certifies all nested requirements in an R-group.

| Decision / criterion | Disposition from this pass |
|---|---|
| D2/D9–D12/D15/D28, R9.2/R9.4 | `LocalCreditLib` source matches the three specified primitives. Pure arithmetic has no observed defect. Every consumer and fuzz boundary is not verified. D12 remains accepted, not a security defect. |
| R1.3/R12 current identities | Unverified; current V4 identity drift is observed (Astra-06). No hash/build comparison executed. |
| R2.1/R2.2 red/green history | Unverified. Follow-up narratives/log references are claims, not independent reproduction. |
| R2.4 precise errors/deltas | Refuted as a universal completion claim by Astra-01 and Astra-02. Corrected custody `test_ADV02` is a positive spot-check. |
| R2.5/R2.6 production fixtures | Positive partial evidence: inspected matrix behavior uses deployed hook/SE fixtures; shared atomic caller is used. Complete per-rejection funded-control mapping not verified. |
| R3.2/R3.5/R3.6 FullSpread | V3 local-credit helper and Native SY self-call restriction inspected; no observed defect there. End-to-end route closure unverified. R3.3 cited supplement is mis-aimed (Astra-03). |
| R4.1–R4.6 historical inventory | Documentary entries read, historical fork source/runtime not reviewed. Latest follow-up claim of corrected positive-credit historical replay is neither confirmed nor refuted. No inference from the obsolete zero-input narrative. Immutable/live distinction is correctly stated. |
| R5.2/R5.4/R5.5 custody | Source supports exact requested burns, bounded exact-output refund, EOA guard, and retained asset-pretransfer rejection. Common `takeShares` inspected. Full rebasing/callback/decimal execution coverage unverified. |
| R7/R8 ERC-4626 and Morpho | Inspected core source removes old whole-share and exact-in surplus refunds; ERC-4626 capacity/sweep and local-first payout are present. Morpho wrap pricing excludes credited pretransfer and exact-out refunds its bounded credit. Complete route tests and historical failing assertions unverified. |
| D22/D31/D45, R14 receipt accounting | Shared dispatch and reserve synchronization present. Generic underlying capacity path and Stata common investment/reward/pull paths inspected. Full backing, cross-interface, fee, and capacity matrix unverified; redemption-cap defect in Astra-04. |
| D32/D38 Balancer/Aave | Inspected Balancer target rejects public pretransfer and authenticates its callback; Aave exact-out mint rejects pretransfer, measures exact pull, and uses reserve-first looping. Loop executor/cap/deleverage correctness not reviewed. |
| D34/D37 dependency propagation | Direct Stata reward calls and Morpho supply observed. Exhaustive removed-catch inventory not verified. D48 current deviation in Astra-05. |
| D41/D48 rate providers | Selected-rate exact-length/nonzero validation present in `rateAfterExchange`; standard and wrapped `_safePreviewExchangeIn` match specified exact-length behavior. Full malformed-data matrix and wrapped-search parity unverified. |
| R6 orbital | Current operation-opening snapshots restrict inspected direct refunds; current local-credit logic distinguishes raw/identity custody from non-identity buffered face. All five direct callers, capped unwrap and callback paths not fully reviewed. |
| D20/D26/D69, R10.3 | Current weighted matrix has meaningful funded controls, but Astra-02 prevents treating named-control completion as full assertion coverage. Entire Cartesian/decimal matrix not verified. No claim that old placeholder counts remain current. |
| R10.1 guard retraction / R10.2 weighted retraction | PDF and requirements read. Weighted buffer-first test partially inspected; Balancer-quad guard execution not independently checked. No invented missing-guard finding. |
| R11.2/R11.3 campaigns | Shared hook handler's first 350 lines and weighted campaign inspected: real nonzero joins/exits, no setup counter seed, explicit trade error propagation. `assertCampaign` body and all other campaign handlers were not read; all 33 campaigns remain unverified as a complete release claim. |
| R11.1/R11.6 counts/seeds | Unverified. The custody minimality fuzz test has a weak negative/positive oracle (Astra-01). No current 10,000-case or 256×64 run attested. |
| R12 selectors/sizes/build | Unverified. No test/build execution or artifact size calculation permitted/performed. |
| D57 Slipstream | Accepted retirement; no missing functional rewrite asserted. Launch/registry exclusion not independently scanned. |
| D58 / legacy facet deletion / D59–D69 follow-on features | Supplied decisions read; comprehensive implementation or build closure unverified. |
| EtherFi open-item-3 research and R14.20 | Research PRD/ledger read. Current implementation identity, source verification, selector history, and fork-pin closure unverified. Older pinned-fork failures are not asserted as new current source defects. |

**All remaining nested criteria, and all uninspected portions of partially checked rows, are unverified in this report.** This explicitly includes a complete all-family EOA/constructor/delegation/wallet matrix, seven-hook source review, DETF prepaid/exchange source review, all Balancer buffer package operative-call boundaries, and full Aave supply-cap/unwind behavior. The coordinator's stop request prevents completing those scopes here.

### Files examined where no defect was found in the inspected portions

This is a positive-observation list, not a clean bill of health for entire families:

- `contracts/utils/LocalCreditLib.sol` — entire file.
- `contracts/protocols/staking/rebasingVault/RebasingAwareStandardExchangeTarget.sol` — entire file.
- `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol` — money entries and preview surface through line 130.
- `contracts/protocols/staking/rebasingVault/RebasingAwareERC4626Common.sol` — payout movement checks, `takeShares`, deposit/mint, beginning of redeem, lines 290–419.
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol`, `ERC4626StandardExchangeInTarget.sol`, `ERC4626StandardExchangeOutTarget.sol` — inspected entire files; no additional confirmed defect beyond the separately reviewed shared adapter.
- `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeCommon.sol` — lines 90–375.
- `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeCommon.sol` — lines 75–248.
- `contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeOutTarget.sol` — lines 1–115; dependencies not fully traced.
- `contracts/protocols/dexes/balancer/v3/pools/BalancerV3PoolStandardExchangeTarget.sol` — lines 100–227.
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol` — lines 835–921.
- `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol` — inspected snapshot/refund/local-credit section, lines 2020–2174; not a full orbital audit.
- `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/wrapped/WrappedStandardExchangeRateProviderTarget.sol` — entire file, no confirmed defect in the specified rewrite.
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/HookLiquidityInvariantHandler.sol` — first 350 lines; `weighted/invariant/UniswapV4StandardExchangeWeightedBufferHook_Invariant.t.sol` — entire campaign host. Positive counter/money-path observations described above; complete conservation proof not established.
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol` and weighted Morpho concrete matrix file — inspected fixture interface/glue, no independently confirmed defect.

## Vacuous or weak tests

1. **Catch-all rounding fallback:** Matrix tests can pass this control on any production revert (Astra-02). This is conditional vacuity in one control, not proof that all matrix money paths are unexecuted.
2. **Wrong boundary reached:** Custody internal-SY ownership test is intercepted by the plain-EOA pretransfer guard (Astra-01).
3. **Unqualified reentrancy/minimality negatives:** Custody tests leave failure reason unbound; the fuzz minimality positive checks only the return (Astra-01).
4. **Weaker accounting substitutes:** Bounded booked increase is not exact consumed-versus-retained reconciliation; a decrease in SE shares is not exact burn accounting; AMM separation needs a proven nonzero prepared leftover (Astra-02).
5. **Stale-book property replaced by refreshed-book consistency:** V3 reconciliation supplement is meaningful for custody synchronization but not sufficient for its cited R3.3 boundary claim (Astra-03).
6. **Additional weak assertion observed, not promoted to a separate finding:** `RebasingAwareERC4626_Adversarial.t.sol:23–35` names first-depositor donation-inflation protection but asserts only positive minted shares and an aggregate redemption upper bound that includes donated value. It does not independently bound each depositor's loss or prove preservation of the second depositor's entitlement. Other tests may supply that property; not checked here.

The inspected shared hook campaign is **not** classified as setup-only/vacuous. Its actual join/exit actions and delta checks deserve to be retained. No claim is made that green campaigns prove all economic invariants.

## Threat-model coverage gaps

### Audit findings and retractions

| Audit item | Inspected evidence / remaining gap |
|---|---|
| 001-M | Local-book V3 helper is corrected in the inspected source. Full stale-reserve boundary evidence remains incomplete; current V4 variants need scope remapping. |
| 001-M2 | Historical inventory and live implementation mapping not independently verified; no deployment remediation claimed. |
| 003 | Custody SE/SY source correction visible. Weak internal-SY and reentrancy tests remain; complete callback/rebase regression coverage unverified. |
| 008 | Orbital opening-balance refund and custody-kind credit correction visible. Five-site and callback execution coverage not fully checked. |
| 009 | Generic ERC-4626 and Morpho inspected burns no longer refund whole self balances. All routes and cross-interface attack controls unverified. |
| 004B | Generic ERC-4626 exact-in source no longer sweeps prior underlying to the caller. Exact consumed/booked matrix assertions remain weaker than specified in the inspected hook behavior. |
| 005 | Canonical helper exists and matches arithmetic requirement. Complete D16 call-site integration remains unverified. |
| Withdrawn beforeSwap claim | No new vulnerability inferred. Required Balancer-quad attacker-context/valid-caller controls not reviewed. |
| Informational weighted dust | Buffer-first funded tests exist; catch-all rounding controls cannot establish the speculative branch boundary. No restored High vulnerability claimed. |

### Catalog coverage relative to D16

- **A/A0/K:** Donation and sync controls exist, but the inspected first-depositor test has a weaker oracle, and full empty-supply/residual and cross-interface sync coverage is unverified. Do not turn D12-authorized unbooked consumption into a false donation finding.
- **B/L3:** Required independent pool movement and stale-book boundary controls are not established by the cited reconciliation supplement. Complete price/rate-manipulation bounds were not reviewed.
- **C/N1:** Custody's bare reentrancy negative does not prove the intended nested guard. Shared handler NatSpec defers callback reentrancy to dedicated suites; those suites were not comprehensively checked. Mid-valuation/settlement unit consistency, including new context-dependent rates, remains unverified.
- **D/F/J:** Actual caller authorization is not established by the mis-aimed internal-SY test. Comprehensive access/admin/upgrade, target-to-facet-to-package-to-proxy selector coverage was not examined. No claim that proxy declarations alone prove reachability.
- **E/E6/I1–I3:** Meaningful bounded-refund and no-delivery controls were observed. Exact underlying-consumption and share-burn reconciliation are incomplete in the sampled matrix, and full short/reuse/constructor/contract coverage per D16 entry remains unverified.
- **G/H:** Real compositions and rollback assertions appear in the weighted matrix, but catch-all rounding failure acceptance hides unintended liveness failures in that control. All seven-hook compositions and native-BPT failure paths were not independently verified.
- **L1/L2:** The sampled AMM fund-separation control needs a proven nonzero unpaired starting book. Full AMM desynchronization and configured fee-on-transfer rejection coverage not checked; prohibited token classes are not assumed supported.
- **M/O:** Complete allowance/middleware authority and permit/signature invalidity/replay coverage was not examined. Orbital's inspected funding section includes Permit2-related paths; applicability cannot be dismissed as “no signature surface.”
- **N2:** Some weighted join/withdraw/swap preview equality assertions are real. Whole-repository parity, mixed native units, and current V4 context-dependent quote behavior remain unverified.

These are **observed weak controls plus explicitly unverified classes**, not an assertion that every unreviewed category lacks tests. No “all possible attacks” claim is made.

## Notes reserved for cross-review

- No peer conclusions were read or adopted. No cross-review has occurred.
- Preserve Astra-01 through Astra-06 as the original positions. A later cross-review should distinguish new evidence from corrections rather than rewriting these originals.
- High-value questions for authorized continuation: whether later approved specifications authorize the current rate snapshot fallback and V4 variants; exact source-to-artifact identities for the submission; a complete R3.3 assertion map; full receipt-redemption boundary tests; all-family scanner selection; and semantic, rather than test-name-only, matrix acceptance.
- A Context7 library-resolution call was made for ERC-4626 reference research before the stop request; no documentation query was completed. Findings here rely on inspected repository requirements and arithmetic, not an external library conformance claim. No proprietary source or secrets were sent externally.
- No implementation is authorized by this report. Await the coordinator/human's next instruction.
