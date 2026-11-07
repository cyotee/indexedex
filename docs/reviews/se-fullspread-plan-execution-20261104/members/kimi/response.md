# Identity

- Run ID: `se-fullspread-plan-execution-20261104`
- Member label: `kimi`
- Profile: `review`
- Phase: `initial independent response`
- Owned path: `docs/reviews/se-fullspread-plan-execution-20261104/members/kimi/response.md`
- Requested role: `council-member`
- Requested model and reasoning: `kimi-coding/k3.1-pro:high`, global route
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no
- Specification SHA-256, coordinator-supplied: `02060190a9237e07641a62d388e6204c8fce6d09a91af343cc743ed6985e1e57`
- Independent fingerprint: not computed

# Question and targets

Question: Does the current repository tree execute every requirement in the supplied implementation and test plan completely and accurately? The review reports requirements that are missing, contradicted, partial, or not acceptable as the plan's stated outcome. A match is coverage, not a defect.

Specification reviewed:

`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md`

The complete brief and all 480 lines of that specification were read before judging code. Sections 2 through 15 were judged. All 48 required targets were opened; the Coverage section records their individual status.

# Evidence

- This was a static source review. No forge command, test, build, install, deployment, or Git operation was run. No test is claimed to pass or fail from this review.
- The complete production family files, the seven vault test files, the fixture and nine matrix rows, the migration index, and the five evidence destinations were opened as listed below.
- Optional context: the PRD's FS-A01 through FS-A39 definitions were read at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md:550-592` because plan section 13 assigns those IDs without restating each assertion. No older PRD sentence was used to displace a plan lock.
- Declared dependency context: `contracts/utils/ExchangeInAmount.sol:6-25` was read because the migrated ComposedStable target calls it. The constant-product behavior was read at `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol:240-267` to determine what the required row leaves inherited.
- Migration dependency reads included the complete relevant decoder regions in `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol` and every `ComposedStableCommonDetfCommon.sol` path named by the index. The index names one such path: `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfCommon.sol`.
- Local-only searches were used for `function test_`, `previewExchangeIn`, `setUp`, `currencyDelta`, `limitCapacity|openCapacity|seBooked`, the V4 `seFamily` entries, `R10.3`, and `2026-11-04`, restricted to admitted files. No source excerpt was sent to a public search or fetch service.
- The index header was re-read: 1,626 textual occurrences in 618 files at `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md:1-7`. It was treated as an occurrence index, not a decoder census.

# Assumptions

- The plan is the requirements authority. A source comment claiming a later owner instruction does not supersede a plan sentence in this review.
- Section 14 supplies names, not additional behavior. Findings rely on behavioral requirements in sections 2 through 13 and migration/evidence requirements in section 12.
- Examined means the file text was opened and the relevant implementation or evidence was assessed; it does not imply runtime validation. Partially examined means only the plan-relevant portions were read, as expressly identified below.
- A missing test assertion is assessed from the declared test bodies. Static presence of production logic is not treated as a substitute for the plan's required test.
- An unopened index path is not examined and is not declared migrated. Repo-wide migration completeness is therefore outside the positive conclusion, not silently inferred from the two required production examples.

# Coverage

| ID | Target | Status | Scope examined |
| --- | --- | --- | --- |
| Spec | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md` | examined | Complete, lines 1-480 |
| 1 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol` | examined | Complete |
| 2 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol` | examined | Complete |
| 3 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol` | examined | Complete |
| 4 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultComponent_FactoryService.sol` | examined | Complete |
| 5 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultComponentBindings.sol` | examined | Complete |
| 6 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultTypes.sol` | examined | Complete |
| 7 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultRepo.sol` | examined | Complete |
| 8 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMath.sol` | examined | Complete |
| 9 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultProjection.sol` | examined | Complete |
| 10 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol` | examined | Complete |
| 11 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultExecution.sol` | examined | Complete |
| 12 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultExecutionPreparation.sol` | examined | Complete |
| 13 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultSwapProjection.sol` | examined | Complete |
| 14 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultOwnerModifiers.sol` | examined | Complete |
| 15 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMaintenanceModifiers.sol` | examined | Complete |
| 16 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMoneyFacet.sol` | examined | Complete |
| 17 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMoneyTarget.sol` | examined | Complete |
| 18 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultQuoteFacet.sol` | examined | Complete |
| 19 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultQuoteTarget.sol` | examined | Complete |
| 20 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultOutFacet.sol` | examined | Complete |
| 21 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultOutTarget.sol` | examined | Complete |
| 22 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultQueryFacet.sol` | examined | Complete |
| 23 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultQueryTarget.sol` | examined | Complete |
| 24 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultCallbackFacet.sol` | examined | Complete |
| 25 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultCallbackTarget.sol` | examined | Complete |
| 26 | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Package.t.sol` | examined | Complete; four declared tests |
| 27 | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Money.t.sol` | examined | Complete; nine declared tests |
| 28 | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/QuotesAndRate.t.sol` | examined | Complete; four declared tests |
| 29 | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Native.t.sol` | examined | Complete; two declared tests |
| 30 | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Callbacks.t.sol` | examined | Complete; two declared tests |
| 31 | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/AlreadyUnlocked.t.sol` | examined | Complete; three declared tests |
| 32 | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/BufferHookIntegration.t.sol` | examined | Complete; four declared tests |
| 33 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol` | examined | Complete |
| 34 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | Complete |
| 35 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | Complete |
| 36 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | Complete |
| 37 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | Complete |
| 38 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | Complete |
| 39 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol` | examined | Complete |
| 40 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | Complete |
| 41 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | Complete |
| 42 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.t.sol` | examined | Complete |
| 43 | `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md` | examined | Complete, lines 1-629 |
| 44 | `docs/audits/apex-2026-09-17-evidence/hook-se-matrix.json` | partially examined | Header, summary, all nine V4 FullSpread row entries, and the closing row-count/findings structure; unrelated historical rows were not read in full |
| 45 | `docs/audits/apex-2026-09-17-evidence/hook-se-matrix-findings.json` | examined | Complete |
| 46 | `docs/audits/apex-2026-09-17-evidence/hook-se-matrix-finding-descriptions.json` | examined | Complete |
| 47 | `docs/audits/apex-2026-09-17-evidence.md` | examined | Complete, lines 1-300 |
| 48 | `docs/audits/apex-2026-09-17-evidence/acceptance.json` | partially examined | R10.3 and its surrounding record at lines 1116-1134, plus the opening schema; unrelated acceptance items were not read in full |

No required target is absent or wholly unexamined. The optional behavior contracts other than the constant-product dependency noted above were not examined. Unopened paths named by the 618-file index remain unexamined for repo-wide migration purposes.

# Conclusions

No. The current tree does not execute every plan requirement completely and accurately. Fourteen findings are recorded below: production component validation, one-token exit error behavior, greatest-liquidity sizing, fixture and matrix conformance, and substantial missing test-plan coverage.

The two production migration examples required by the brief were opened. The curve-quad claim library decodes the first tuple word at `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol:119,323,333,343,393,414,449,453`. ComposedStable decodes the first word at `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfCommon.sol:333,621,705`, and its helper explicitly reads `amountOut`, not the refund word, at `contracts/utils/ExchangeInAmount.sol:12-14,22-24`. This is coverage of those examples only, not a repo-wide migration conclusion.

The evidence destinations contain replacement V4 entries tied to `forge-test-use-solar-2026-11-04`, and the FS-HOOK-04 description says FS-A26 remains open at `docs/audits/apex-2026-09-17-evidence/hook-se-matrix-finding-descriptions.json:83-89`. R10.3 also records the 2026-11-04 replacement at `docs/audits/apex-2026-09-17-evidence/acceptance.json:1129`. Those recorded outcomes were not rerun.

# Review findings

## Finding 1 — Section 4: code-empty infrastructure components are accepted

**Location.** Plan requirement at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:69`. Implementation at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol:70-90,177-179`.

**Invariant or requirement.** A missing or code-empty component must revert `InvalidComponent` with no partial diamond.

**Impact.** The constructor checks the manager, registry, oracle, factory, WETH, facets, and linked libraries, but it does not check `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, or `universalRouter` before storing them and later initializing Protocol Aware with them. A package can therefore be constructed with missing or code-empty architecture components, contrary to the required rejection boundary.

**Fix direction.** Apply the same component validation policy to every infrastructure binding covered by the plan, and add negative package tests for each missing or code-empty binding.

**Evidence class.** Static source observation. The absence of checks is visible at lines 70-90; the six values are consumed at lines 177-179. No runtime claim is made.

## Finding 2 — Section 9: an incomplete exit swap raises the wrong error

**Location.** Plan requirement at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:178`. Failure production at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:130-170`, especially lines 163-165. Error translation at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultExecution.sol:64-66`.

**Invariant or requirement.** A one-token exit must swap all unwanted withdrawn principal plus opposing claims, or revert `AmountOutNotMet` without burning shares.

**Impact.** When the post-removal projection does not spend the entire unwanted amount, Planner marks the plan failed. Execution maps every failed plan to `MinLiquidityNotMet`, so this exit branch does not produce the plan-required `AmountOutNotMet`. Revert rollback prevents the burn, but the specified failure contract is still contradicted.

**Fix direction.** Distinguish first-deposit liquidity failure from an exit conversion shortfall and map the latter to the required `AmountOutNotMet`; add a regression that asserts the exact error and unchanged shares and balances.

**Evidence class.** Static source observation plus direct control-flow inference. No exploit procedure or runtime result is asserted.

## Finding 3 — Sections 2, 9, and 10: the 96-step sizing loop does not establish greatest liquidity

**Location.** Greatest-liquidity requirement at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:19`. Planner at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:175-202`, particularly the fixed loop at line 185.

**Invariant or requirement.** FS-OWN-33 sizing must return the greatest liquidity the following add can take, with execution and preview using the same Planner result.

**Impact.** `_size` accepts a `uint256 amount_` but stops after at most 96 bisections and returns the best candidate seen. For accepted input ranges whose optimizing interval still requires refinement after those iterations, the code does not establish that no greater feasible liquidity remains. The result can therefore be a feasible approximation rather than the plan's stated greatest result.

**Fix direction.** Use a termination proof based on convergence to an indivisible feasible optimum, or otherwise prove and test optimality across the full accepted amount domain, including values beyond the current 96-step search horizon.

**Evidence class.** Static algorithm-bound observation and inference. This finding does not assert a particular runtime input or output.

## Finding 4 — Section 12: the fixture contains expressly forbidden capacity and booked APIs

**Location.** Plan prohibition at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:215`. Fixture at `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol:105-110`.

**Invariant or requirement.** `limitCapacity()` and `openCapacity()` are not part of this fixture; no sleeve capacity gate or booked getter is to be added.

**Impact.** The fixture declares both capacity functions and a `seBooked()` getter. The inherited constant-product behavior also calls these APIs at `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol:240-267`, preserving the sleeve-oriented shape the plan told the V4 row to replace rather than accommodate.

**Fix direction.** Remove the forbidden fixture surface after replacing all inherited consumers with the required V4 refund assertions; do not emulate capacity or booked-sleeve behavior.

**Evidence class.** Static source observation.

## Finding 5 — Section 12: required refund controls are absent or left inherited

**Location.** Plan requirement at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:240`. Single row at `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:76-86`. Constant-product row inventory at `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:48-195` and inherited behavior at `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol:240-267`.

**Invariant or requirement.** Every row overrides `test_row_partialConsumption_bookedNotRefunded`; the inherited body must not run. The override needs both a fully consumed `amountRefunded == 0` control and a partially consumed refund-to-hook assertion.

**Impact.** The single row checks only the one-sided remainder case and has no fully consumed zero-refund control. The constant-product row declares no override at all, so the inherited body runs and takes its `hasPartialCase()` branch instead of executing the required two V4 assertions. The central refund behavior is therefore not tested as specified on either row.

**Fix direction.** Implement the same explicit two-control V4 override on both rows, with exact tuple decoding and hook-balance deltas, and ensure the inherited sleeve body cannot run.

**Evidence class.** Static test-text observation.

## Finding 6 — Section 12: the dual row omits per-address delta assertions

**Location.** Plan requirement at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:291`. Dual proof at `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:311-333`.

**Invariant or requirement.** Both exact-input directions must assert balances, position owner, ticks, salt, and per-address deltas, while PairToken supply remains unchanged.

**Impact.** `_crossVaultDirections` checks output balances, PairToken supply, and position liquidity at full-range ticks and zero salt, but contains no per-address currency-delta assertion. If the identity record is accepted, the canonical cross-vault proof still lacks the required settlement evidence.

**Fix direction.** Add the relevant vault, hook, and outer-caller delta assertions around both directions without converting an FS-HOOK-04 rejection into a passing FS-A26 proof.

**Evidence class.** Static test-text observation.

## Finding 7 — Section 12: the two-leg weighted row contradicts the setup requirement

**Location.** Plan requirement at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:321`. Row at `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:21-49`.

**Invariant or requirement.** The two-leg weighted row does not override `setUp`; it uses the inherited behavior setup.

**Impact.** The row explicitly overrides `setUp` and calls the weighted TestBase directly. Its comment says an owner instruction supersedes the plan, but that comment is not a plan requirement and does not remove the contradiction.

**Fix direction.** Restore the inherited behavior setup for the two-leg row, keeping custom runtime-length setup only where the plan requires it for the three-leg row.

**Evidence class.** Static source observation.

## Finding 8 — Section 13: Package tests cover only a small part of the required package matrix

**Location.** Plan assignment at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:371` and audit item 052 at line 431. Complete test inventory at `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Package.t.sol:25-66`.

**Invariant or requirement.** Package tests must cover FS-A01 through FS-A04, FS-A16, the package cut, permit domain and operation, and the assigned presence/absence audit rows.

**Impact.** The four tests cover bootstrap, domain metadata, absent `getRate`/`asset`, and direct-transfer non-minting. They do not exercise the selector manifest and forbidden cuts, binding-hash sensitivity, invalid component/pool/initialization contexts, storage-slot separation, post-deploy removal, token approval without a Boolean return, or an actual `permit`. FS-A01 through FS-A04 and the package-cut requirement are therefore largely unexecuted, and audit item 052 is only partially present.

**Fix direction.** Add the named package surface, negative initialization, selector, storage, approval, and permit assertions at the proxy boundary, including unchanged-state checks where required.

**Evidence class.** Static test-inventory observation; no test was run.

## Finding 9 — Section 13: Money tests omit required economics, operators, and standalone gas

**Location.** Plan assignments at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:372,379` and the audit inventory at lines 384-433. Test inventory at `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Money.t.sol:75-183`.

**Invariant or requirement.** Money must execute FS-A05 through FS-A08, FS-A11, FS-A39, the assigned audit rows, and cold standalone gas bodies for all six money and maintenance routes.

**Impact.** Existing tests provide happy-path smoke coverage and partial disable/event checks, but do not assert the genesis floor and full first-deposit issuance, fee collection and booked-remainder accounting, unwanted-exit residual rules and no-burn failure, no implicit compounding, or operator appointment and selector scoping. Required pretransfer, inflation, dust, fee-clamp, precision, and remainder cases are absent. No standalone gas measurement exists in the file. FS-A05 through FS-A08, FS-A11, FS-A39, FS-A31 standalone, and multiple assigned audit rows are consequently absent or partial.

**Fix direction.** Implement the assigned route-level accounting and negative assertions, the complete disable and maintenance matrix, and cold per-route gas measurements with fixture setup and preview warm-up outside the measured body.

**Evidence class.** Static test-inventory observation; no test or gas measurement was run.

## Finding 10 — Section 13: quote and view requirements are only partially tested

**Location.** Plan assignments at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:373,380` and audit items 019, 041, 044, 049, and 051 at lines 393-430. Test inventory at `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/QuotesAndRate.t.sol:61-108`.

**Invariant or requirement.** QuotesAndRate must cover FS-A09, withdrawn FS-A12 through FS-A15, FS-A32, all required preview ceilings, and its assigned economic-view and precision rows.

**Impact.** The four tests cover bundle preview parity, one unsupported preview, one preview gas measurement, and absent exact-out/rate behavior. They do not exercise economic views while the manager is busy or unlocked, reserve composition in that state, the full withdrawn-surface set, unchanged balances around exact-out rejection, dust-tick liveness, fee/precision behavior, or preview-versus-execution acceptance across the required routes. Measuring only `previewExchangeIn` does not establish the ceiling for every required preview.

**Fix direction.** Add the assigned busy/unlocked view assertions and route matrix, withdrawn-surface checks, unchanged-balance negatives, precision/liveness cases, and cold gas checks for every required preview.

**Evidence class.** Static test-inventory observation; no test or gas measurement was run.

## Finding 11 — Section 13: native borrowed settlement is untested

**Location.** Plan assignment at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:374`. Test inventory at `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Native.t.sol:45-79`.

**Invariant or requirement.** Native tests must cover FS-A10 and FS-A35, including native borrowed settlement ordering, no double counting, no use of another actor's sync credit, and WETH-only caller-facing amounts.

**Impact.** The two tests check nonpayable rejection and WETH-facing deposits against native currency. Neither enters the borrowed unlock path nor asserts native sync/settle ordering, per-address deltas, backing separation, or another actor's sync credit. FS-A35 is absent and FS-A10 is only partially exercised.

**Fix direction.** Add native borrowed-route assertions around the real PoolManager callback, covering the specified sync/settle order, caller WETH amounts, own-delta closure, and isolation from unrelated outer settlement state.

**Evidence class.** Static test-inventory observation.

## Finding 12 — Section 13: multi-action callback discipline is not tested

**Location.** Plan assignment at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:375`. Test inventory at `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Callbacks.t.sol:12-21`.

**Invariant or requirement.** Callbacks must cover FS-A17 and FS-A18: one unlock and one consumed callback per action, replay rejection, guard continuity, zero unlocks on the borrowed equivalent, and no token movement on a stranger callback.

**Impact.** The two tests check a stranger callback and an uncommitted payload. They do not execute a multi-action deposit or withdrawal, replay after each callback, inspect guard continuity between actions, compare borrowed unlock counts, or assert unchanged token balances for the stranger call. FS-A17 is absent and FS-A18 is partial.

**Fix direction.** Add instrumented multi-action locked and borrowed routes with per-action callback counts, replay negatives, guard-state assertions, and unchanged-balance checks.

**Evidence class.** Static test-inventory observation.

## Finding 13 — Section 13: the borrowed-unlock acceptance matrix is largely missing

**Location.** Plan assignment at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:376`. Test inventory at `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/AlreadyUnlocked.t.sol:73-121`.

**Invariant or requirement.** AlreadyUnlocked must cover FS-A19 through FS-A23, FS-A33, FS-A34, FS-A36, and FS-A37, plus the assigned borrowed-path audit rows.

**Impact.** The three tests cover one successful borrowed mint, bundle-in rejection, and pretransfer rejection. They do not cover missing input or shares, bundle-out/donate/compound rejection, rollback of shares/liquidity/balances after a borrowed failure, locked-versus-borrowed economic equivalence, nonzero own-delta entry rejection, outer-debt preservation, caught-inner-failure rollback, or propagated outer failure. Position identity, unrelated global deltas, and nonpayment of value are also not asserted. Most of the assigned matrix is therefore absent.

**Fix direction.** Add the complete borrowed-route positive and negative matrix, including all rejected methods, own and outer deltas, exact rollback state, and both propagated and caught failure behavior.

**Evidence class.** Static test-inventory observation.

## Finding 14 — Section 13: composed gas, buffered disable, and required integration controls are missing

**Location.** Plan assignments at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md:378,381`, audit items 014, 015, 030, 036, 043, 045, and 054 at lines 388-433. Test inventory at `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/BufferHookIntegration.t.sol:30-108`.

**Invariant or requirement.** BufferHookIntegration and the rows must cover their composed transaction gas ceiling, the buffered disable matrix, assigned integration-only controls, staged-credit behavior, and required unwrap approval plus completed exit.

**Impact.** The four local tests address the external provider tuple, staged pretransfer, exact-out rejection, and an identity attempt. No composed gas measurement exists. There is no disabled buffered withdrawal/non-withdrawal test, no deadline-before-disable composed case, and no explicit required-unwrap approval/exit control. The assigned Curve, Orbital, and Balancer integration-only controls are also absent from this file. Matrix rows supply other coverage but do not satisfy these file-specific assignments.

**Fix direction.** Add whole-transaction composed gas assertions without a `getRate` warm-up, the complete buffered disable/deadline matrix, and the named integration and unwrap-approval controls with exact balance and settlement assertions.

**Evidence class.** Static test-inventory observation; no composed transaction or gas measurement was run.

# Limits

- Static reading is not runtime proof. No statement here says a test passed, a build succeeded, or a route executed.
- Targets 44 and 48 were partially examined as identified in Coverage. All nine V4 matrix rows and R10.3 were read; unrelated historical evidence was not exhaustively reviewed.
- The migration index contains 618 files. Only the index, required targets, the two specifically required production assignments, and the declared `ExchangeInAmount` dependency were examined for migration. All other index paths are unexamined, so repo-wide migration completeness is not established either way.
- The seven behavior contracts were optional context. Only the constant-product behavior region needed to identify the inherited refund body was read; the other behavior contracts were not examined.
- No peer response or peer directory was read. No project source, plan, PRD, blocker, evidence, or other member file was modified.
