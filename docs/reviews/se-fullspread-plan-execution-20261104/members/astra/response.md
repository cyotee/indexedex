# Identity

- Run ID: se-fullspread-plan-execution-20261104
- Member label: astra
- Profile: review
- Phase: initial independent response
- Requested role: council-member
- Requested model and reasoning: chatgpt-subscription/gpt-6-astra:high
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no
- Owned path: docs/reviews/se-fullspread-plan-execution-20261104/members/astra/response.md
- Specification SHA-256, coordinator-supplied: `02060190a9237e07641a62d388e6204c8fce6d09a91af343cc743ed6985e1e57`
- Independent fingerprint: not computed

# Question and targets

Does the current repository tree execute every requirement in the supplied implementation and test plan completely and accurately?

**No.** This static review identifies 24 plan-conformance findings below. It distinguishes implementation defects, missing assertions, and overbroad evidence claims. An implemented requirement is coverage, not a finding. The plan's permission sentence is not a finding.

The specification is `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md`. It was read completely, including lines 408-480 after the first read reached its output limit, before judging production code. All 48 required targets were opened. Targets 1-42 and 45 were examined completely; targets 43, 44, 46, 47, and 48 were partially examined as described in Coverage. None was substituted or omitted.

In this response, `PLAN:line` means a line in that exact specification path, not a different draft. `PRD:line` means `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`, used only to resolve the FS-A acceptance rows incorporated by PLAN:369-383. Source-file locations in findings are repository-relative.

# Evidence

The evidence is source text read on November 4, 2026, not executed behavior. Each finding's Location identifies the source observation; its Impact separates the resulting inference from that observation. No test, compiler, deployment, wallet, or Git operation was run. No public source service received repository text.

The following matching elements are positive coverage:

- The package ABI has the prescribed field order and six-address array; `bindingHash` hashes the complete initialization struct. Initialization sets the Protocol Aware addresses, WETH, full-range ticks, zero salt, metadata, and domain version. These are source observations, not proof that every invalid configuration is rejected: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol:15-46`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol:69-103,168-189`.
- The explicit selector manifest installs the specified money, quote, out, query, and callback functions, uses the shared out-interface selectors, and obtains the protocol/position getters from their Crane interfaces: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol:264-358`. This is not a runtime proxy-cut test.
- The family slot expression and positional booked/reserved arrays match the stated layout. Reserve queries add position principal and unpaid fees, not local holdings: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultRepo.sol:5-14`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultQueryTarget.sol:14-29`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultProjection.sol:29-47`.
- Live-owner and three-arm maintenance checks use the oracle and OperableRepo rather than a stored ownable owner: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultOwnerModifiers.sol:8-14`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMaintenanceModifiers.sol:9-17`.
- Execution and preview call the same Planner functions. The execution loop has per-action commitment, callback consumption, settlement, and relock checks; the borrowed branch has the required bare entry rejection and explicit guard rejection: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultQuoteTarget.sol:14-56`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultExecution.sol:30-39,63-67,98-101,178-222`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultExecutionPreparation.sol:25-38,70-103`. The findings below identify gaps in the economics and proofs; they do not deny this shared structure.
- Enabled exact-out is a zero preview and a reverting execution; deadline precedes disable: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultOutTarget.sol:15-28`.
- The required fixture uses a production registry/package deployment, sorted hookless backing currencies, a public bundle bootstrap, and two providers for one vault: `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol:65-78,140-180,201-224`. Its prohibited compatibility seams and manager integration are separate findings.
- Weighted N3 and the two Balancer sizes construct runtime-length funding arrays instead of calling the fixed-length behavior seed helpers: `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol:167-175`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:114-126,163-171`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.t.sol:15-18`.

Migration observations:

- `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md:3-7` says **1,626 textual occurrences in 618 files**, explicitly not a decoder census. I did not paste the index or treat its occurrence count as the number of ABI decoders.
- Local, in-memory searches of text opened through the read tool used `ComposedStableCommonDetfCommon`, `previewExchangeIn`, `exchangeIn`, `abi.decode`, return-length comparisons, `outputs`, and `SeMatrixBehavior`. No repository-wide directory search was used. Searching the complete loaded index found one `ComposedStableCommonDetfCommon.sol` path, at index line 127; that path was opened.
- Both specifically required production assignments read the first tuple word: `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol:64-67,119-121,392-418`; `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfCommon.sol:183-184,205-221,233-240,277-284,333-334,621-622,705`.
- The shared interface and helper return/read the two-word ABI: `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:46-49,62-70`; `contracts/utils/ExchangeInAmount.sol:9-29`. The provider distinguishes a 64-byte preview response from its separate 32-byte state-quote response and reads amountOut: `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:101-109,119-127`.
- Two opened frontend ABI bindings use both outputs, and the opened value consumers select the first: `frontend/apps/indexedex/app/insights/lib/insightsAbi.ts:67-91`; `frontend/packages/protocol/src/protocolDetfAbi.ts:16-40`; `frontend/apps/indexedex/app/insights/components/DetfActions.tsx:240-248,275-291,599-606`; `frontend/apps/indexedex/app/insights/components/DetfStaking.tsx:91-96,108-112`.

Those are sampled migration matches, not a repo-wide migration verdict. Nineteen of the 618 index paths were opened, generally at the relevant call sites. The other 599 were not examined. The third ABI binding, every generated ABI, all six length gates, and compilation across all callers were not established.

# Assumptions

1. Sections 2-15 of the supplied plan are the requirements. Optional documents do not overturn an adopted reading. The PRD was consulted only for acceptance rows the plan identifies without fully restating.
2. A later-owner claim inside a source comment is not evidence of an instruction that changes this assignment. The weighted setup discrepancy is identified against the specific weighted sentence, with the plan's more general setup sentence disclosed.
3. An FS-HOOK-04 rejection can satisfy the requirement to record an incompatibility. It cannot close FS-A24, FS-A26, the both-target proof, or a conversion assertion that returned before executing; PLAN:223,287-295 and PRD:577-582 make these distinctions.
4. Loading a file into the read kernel is not the same as examining every line. Coverage reflects the text actually reviewed, including recovery of relevant elided output.
5. No assertion below that a path is missing is a claim that an unlisted directory has been exhaustively searched. Missing-test findings concern the plan-designated files and their examined setup/inherited row bodies.

# Coverage

## Required specification and targets

`examined` means the complete target text was examined. `partially examined` means the file was opened and its relevant sections were examined, with the remaining extent disclosed. These statuses are not pass/fail labels.

| # | Path | Status | Examined extent / result |
| --- | --- | --- | --- |
| Specification | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md` | examined | Lines 1-480; sections 2-15 are the conformance standard. |
| 1 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol` | examined | Lines 1-85; markers, family errors, bundle ABI. |
| 2 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol` | examined | Lines 1-56; initialization order and package surface. |
| 3 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol` | examined | Lines 1-360; bindings, initialization, registry context, cut. Finding 4. |
| 4 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultComponent_FactoryService.sol` | examined | Lines 1-95; artifact-backed deployments and binding checks. |
| 5 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultComponentBindings.sol` | examined | Lines 1-28; six-library order. |
| 6 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultTypes.sol` | examined | Lines 1-70; action and plan representation. |
| 7 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultRepo.sol` | examined | Lines 1-41; namespace and accounting fields. |
| 8 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMath.sol` | examined | Lines 1-143; sizing, rounding, shares, claims. Finding 1. |
| 9 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultProjection.sol` | examined | Lines 1-49; position and unpaid-fee read. |
| 10 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol` | examined | Lines 1-248; all routes and sizing. Findings 1-3, 5. |
| 11 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultExecution.sol` | examined | Lines 1-278; funding, action dispatch, mint/burn, bookkeeping, maintenance. Findings 3, 5. |
| 12 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultExecutionPreparation.sol` | examined | Lines 1-105; commitments, manager calls, settlement. Finding 2 comparison. |
| 13 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultSwapProjection.sol` | examined | Lines 1-112; traversal and post-removal adjustment. Finding 2. |
| 14 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultOwnerModifiers.sol` | examined | Lines 1-15; live owner. |
| 15 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMaintenanceModifiers.sol` | examined | Lines 1-18; three-arm authorization. |
| 16 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMoneyFacet.sol` | examined | Lines 1-41; selectors and interface declarations. |
| 17 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMoneyTarget.sol` | examined | Lines 1-165; routes and public checks. |
| 18 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultQuoteFacet.sol` | examined | Lines 1-34; three preview selectors. |
| 19 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultQuoteTarget.sol` | examined | Lines 1-67; shared planner and output ordering. |
| 20 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultOutFacet.sol` | examined | Lines 1-27; selectors derived from interface. |
| 21 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultOutTarget.sol` | examined | Lines 1-30; absent exact-out and check order. |
| 22 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultQueryFacet.sol` | examined | Lines 1-27; two reserve selectors. |
| 23 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultQueryTarget.sol` | examined | Lines 1-40; position-only reserves. |
| 24 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultCallbackFacet.sol` | examined | Lines 1-29; callback selector. |
| 25 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultCallbackTarget.sol` | examined | Lines 1-15; execution delegation. |
| 26 | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Package.t.sol` | examined | Lines 1-68; four tests. Finding 10. |
| 27 | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Money.t.sol` | examined | Lines 1-186; funding/economics/maintenance coverage is incomplete. Findings 9, 11-14. |
| 28 | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/QuotesAndRate.t.sol` | examined | Lines 1-110; bundle parity, unsupported route, one gas probe, exact-out negative. Finding 18. |
| 29 | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Native.t.sol` | examined | Lines 1-79; one value rejection and deposit route. Finding 17. |
| 30 | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Callbacks.t.sol` | examined | Lines 1-23; two rejection tests. Finding 15. |
| 31 | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/AlreadyUnlocked.t.sol` | examined | Lines 1-123; three borrowed-path tests. Finding 16. |
| 32 | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/BufferHookIntegration.t.sol` | examined | Lines 1-108 and inherited CP row; findings 6, 9, 14, 21. |
| 33 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol` | examined | Lines 1-270; findings 6, 22. |
| 34 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | Lines 1-190; findings 6, 19. |
| 35 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | Lines 1-226; findings 6, 19, 21. |
| 36 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | Lines 1-420, including shared helpers; findings 8, 19, 20, 24. |
| 37 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | Lines 1-242; identity rejection and raw-control branches, shared helper limitations. |
| 38 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | Lines 1-252; finding 23 and shared helper limitations. |
| 39 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol` | examined | Lines 1-316; runtime length and named identity record; findings 19, 20, 24. |
| 40 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | Lines 1-285; findings 7, 19, 20, 24. |
| 41 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` | examined | Lines 1-311; findings 7, 19, 20, 24. |
| 42 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.t.sol` | examined | Lines 1-53 and its required parent row; findings 7, 20, 24. |
| 43 | `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md` | partially examined | Header and initial listing, plus local scans of all 629 loaded lines for required assignments, bindings, and behaviors. Not an examination of all listed files. |
| 44 | `docs/audits/apex-2026-09-17-evidence/hook-se-matrix.json` | partially examined | Header, all nine current V4 FullSpread records, V3 locators, FS-HOOK-04 entry. Unrelated historical rows not reviewed. Finding 24. |
| 45 | `docs/audits/apex-2026-09-17-evidence/hook-se-matrix-findings.json` | examined | Lines 1-183, including V4 finding associations and retained V3 associations. |
| 46 | `docs/audits/apex-2026-09-17-evidence/hook-se-matrix-finding-descriptions.json` | partially examined | F6 and FS-HOOK-04 plus surrounding descriptions; long unrelated historical detail lines were not fully examined. Finding 24. |
| 47 | `docs/audits/apex-2026-09-17-evidence.md` | partially examined | Current V4 replacement statement at line 74 and related historical/migration passages. Unrelated audit history not fully reviewed. Finding 24. |
| 48 | `docs/audits/apex-2026-09-17-evidence/acceptance.json` | partially examined | R10.3, lines 1115-1139, and current V4 statement; unrelated acceptance items not fully reviewed. Finding 24. |

## Requirement coverage

This table is a static coverage assessment, not a test-result table. The cited target ranges above and findings below supply the underlying source references.

| Plan requirement | Assessment |
| --- | --- |
| Sections 3-5 production file map, binding order, cut, storage | All required files present and examined; source matches described in Evidence. Missing infrastructure validation: finding 4. Runtime package acceptance coverage: finding 10. |
| Sections 2, 9, 10 one-sided sizing and quote engine | Shared engine exists; greatest-liquidity/output-consumption guarantee and uncapped convergence are not established by its algorithm: finding 1. |
| Sections 6-9 floor and exits | Zero-liquidity genesis bypass, post-removal projection, and wrong incomplete-exit error: findings 2, 3, 5. |
| Sections 6-8 funding, guard, callbacks, settlement | Source structure is substantially present; designated negative and isolation tests remain incomplete: findings 11, 15-17. |
| Sections 9, 11 fee, maintenance, operators, disable | Matching production structure is not the required test matrix: findings 12-14. |
| Section 12 nine topology files and fixture | All opened; positive coverage is recorded above. Findings 6-8 and 19-24 concern substantive proof or explicit construction requirements. |
| Section 12 tuple migration | Named production assignments and opened consumers use amountOut. Repo-wide migration and compilation are not established; 599 index paths remain unexamined. |
| Section 13 FS-A01-A04, A16 | Partial: package bootstrap/domain/two absent selectors only; finding 10. |
| Section 13 FS-A05-A08, A11 | Partial: ordinary funded routes exist; first-deposit boundaries, fee/book claims, pretransfer and maintenance cases are missing; findings 11-13. |
| Section 13 FS-A09 | Enabled negative exists; unchanged-balance assertions incomplete: finding 18. |
| Section 13 FS-A10, A35 | Partial locked deposit only; finding 17. |
| Section 13 FS-A12-A15 | Withdrawn, not reopened as rate tests. |
| Section 13 FS-A17-A18 | Partial entry rejection only; finding 15. |
| Section 13 FS-A19-A23, A33-A34, A36-A37 | Funded non-hook mint, one bundle reject, and pretransfer reject exist; remainder incomplete: finding 16. |
| Section 13 FS-A24 | Identity bind attempted; rejection recording is not a positive identity pass. Finding 24 addresses classification. |
| Section 13 FS-A25-A30 | Partial topology coverage; disjoint-key checks and two providers exist. Shared-manager proof, stable pricing and canonical identity closure remain deficient or open: findings 6-8, 20-21, 24. Same-backing sequential composition is not claimed proved here. |
| Section 13 FS-A31 | Standalone/composed measurements missing; only one preview probe: finding 9. |
| Section 13 FS-A32 | Busy/unlocked views and reserve semantics untested in designated quote file: finding 18. |
| Section 13 FS-A38 | Partial vault disable check, no buffered disable matrix: finding 14. |
| Section 13 FS-A39 | Appointment and operator matrix absent from designated money tests: finding 13. |
| Audit 010, 011, 022, 034, 036, 039 | Vault-level funding/credit and over-mint controls incomplete: findings 11-12, 16. The hook staged-transfer test is positive partial coverage, not the missing vault tests. |
| Audit 013, 029, 032, 042, 052 | Some absent-interface/domain coverage exists; selector exclusions, no-bool approve and actual permit use incomplete: finding 10. |
| Audit 019, 049, 051 | Exact-out negatives and ordinary parity exist, but complete state/economic-view boundary coverage does not: finding 18. |
| Audit 023, 024, 040, 041, 044, 048 | Maintenance access, isolated exit claims, donation/dust liveness, precision and event/remainder cases incomplete: findings 12-13, 16, 18. |
| Audit 028, 045, 054 | Same-token rejection is not the full identity/hook-exit proof; buffered disable and every required successful unwrap are not established: findings 6, 14, 20-21, 24. |
| Audit 014, 015, 030, 043 | Integration-only classifications retained; this review does not claim a vault fix to those hook mechanisms. |
| Audit 012, 016-018, 020-021, 025-027, 031, 033, 035, 037-038, 046-047, 050, 053 | Exclusions, not demands to implement those mechanisms. The production selector manifest gives partial structural absence coverage; the designated Package file lacks the complete manifest/exclusion assertions (finding 10). |
| Sections 14-15 names and traceability | Required names present; names alone do not close the behavioral and assertion gaps above. |

## Optional and dependency context

- PRD: **partially examined**, acceptance rows at lines 550-592 used to resolve PLAN section 13; no independent requirements imported.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`: **not examined**.
- `docs/research/se-fullspread-implementation-plan-20261104/REPORT.md`: **not examined**.
- `docs/research/se-fullspread-implementation-plan-20261104/coordinator/draft.md`: **not examined**.
- Seven optional behavior contracts: **partially examined**, their setup, test declarations, tuple reads, relevant seed helpers, and CP partial-consumption body. Their full paths are the seven `Behavior:` paths in PLAN:254,266,278,299,317,331,343.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol`: **examined**, lines 1-113, as the setup dependency of targets 26-31.
- The two single-hook TestBases and `contracts/test/libs/RateProviderFixtureLib.sol`: **partially examined**, to trace the required rows' manager and provider setup; cited in finding 6 and Evidence.
- `contracts/utils/ExchangeInAmount.sol`: **examined**, lines 1-31, as the helper called by opened migration consumers.
- The 19 opened INDEX paths comprise the two hook quote/leg libraries; Curve ClaimLib; the rate-provider facet; the one indexed ComposedStableCommonDetfCommon; two frontend ABI bindings; IStandardExchangeIn; DetfActions and DetfStaking; seven behavior files; and the two single-hook TestBases. Each was examined at the relevant sites, not certified in full.

Unused optional context and unexamined migration consumers are disclosed gaps, not invented requirements. Peer files were not opened.

# Conclusions

The implementation is not complete against the plan. There is substantial matching structure, but arithmetic/initial-deposit defects and several missing public-path proofs prevent acceptance. The designated test files are much narrower than the specified FS-A and audit matrices. Existing evidence labels also combine successful control tests with identity variants that did not execute.

**Finding count: 24.** Findings 1-5 concern production conformance; 6-8 concern invalid or incomplete integration construction; 9-18 concern required acceptance coverage; 19-24 concern specific row assertions, explicit construction constraints, and evidence accuracy.

No finding authorizes implementation or edits to the plan/PRD. No tests are claimed to have passed in this review. FS-A26 remains open; neither a recorded FS-HOOK-04 rejection nor a face/raw control closes it.

# Review findings

## 1. Sections 2, 9, 10 - One-sided sizing does not enforce the selected swap/add invariant

- **Location:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMath.sol:56-83`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:105-115,175-201`.
- **Invariant or requirement:** PLAN:19,174,190 requires greatest addable liquidity, consumption of the complete swap output by that add, remainder only in original input, and no step cap.
- **Impact:** Observation: Math accepts `needOut <= swapOut`, can reduce liquidity to fit remaining input, and records the smaller consumed output as `sized.swapOut`. Planner never uses that field to resize the swap; it executes `sized.swapIn` and the reduced liquidity. Its search ends after 96 iterations without proving convergence, and a zero-output midpoint discards the larger-input half. Inference: the implementation permits a swap/add pair with opposing-token residue and does not establish the stated greatest-liquidity result. Quote/execution agreement through the same algorithm would not prove this independent requirement.
- **Fix direction:** Make the selected exact-input swap and rounded add satisfy the full-output-consumption invariant, prove the search termination/optimality over its accepted input domain, and test the invariant independently of Planner's own quote.
- **Evidence class:** Direct source observation plus arithmetic/control-flow inference; no runtime counterexample is claimed.

## 2. Sections 9-10 - Exit projection does not fully remove the position from projected pool state

- **Location:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:136-168`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultSwapProjection.sol:28-40,67-71,105-110`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultExecutionPreparation.sol:54-64`.
- **Invariant or requirement:** PLAN:178,192 requires the exit quote to use post-removal state and match actual one-token output.
- **Impact:** Observation: the projection subtracts the removed liquidity from current active pool liquidity unconditionally, but subsequent crossings read unadjusted on-chain tick liquidityNet. The execution instead removes the position through `modifyLiquidity` before swapping. Inference: a quote outside the position's active interval or crossing its boundary does not represent that execution state; it can calculate the wrong output or fail before a valid route executes. The plan expressly leaves swaps unbounded, so boundary state cannot be excluded by an invented zap cap.
- **Fix direction:** Project the position removal consistently in active liquidity and boundary tick changes, and compare boundary-crossing exits against actual settlement.
- **Evidence class:** Direct source observation and state-transition inference; not an executed failure.

## 3. Sections 7, 9 - Zero added liquidity bypasses the first-deposit floor rejection

- **Location:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:37-47,204-214`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultExecution.sol:98-109,224-229`.
- **Invariant or requirement:** PLAN:154,174,176 and incorporated FS-A05 require a first deposit adding no more than 1,000 liquidity to revert `MinLiquidityNotMet()`.
- **Impact:** Observation: `_shares` returns immediately when `liquidityAdded == 0`, before the zero-supply floor check. The bundle execution only rejects `plan.failed`, so a zero-liquidity plan with a zero minimum proceeds to refunds and `PairDeposited`. Inference: the zero member of the forbidden genesis range succeeds instead of reverting; testing only a positive bootstrap does not detect it.
- **Fix direction:** Apply the genesis floor check before the zero-liquidity early return, on all mint routes, and assert the zero-liquidity boundary through public calls.
- **Evidence class:** Direct source/control-flow inference.

## 4. Section 4 - Six infrastructure bindings bypass the code-empty component check

- **Location:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol:69-91,177-179`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol:90-100`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol:159-169`.
- **Invariant or requirement:** PLAN:55-69 requires the named infrastructure bindings and rejection of a missing or code-empty component with `InvalidComponent`.
- **Impact:** Observation: constructor checks cover manager, registry, oracle, factory, WETH, facets and libraries, but not positionDescriptor, positionManager, quoter, stateView, reservesLens or universalRouter. Both fixture paths supply small bare addresses for those six fields. Inference: a package can advertise initialized infrastructure getters while retaining code-empty bindings, contrary to the component-rejection requirement.
- **Fix direction:** Validate all required infrastructure components and use legitimate deployed bindings in the production-first fixtures.
- **Evidence class:** Direct source omission; runtime deployment not attempted.

## 5. Sections 6, 9 - An incomplete one-token exit reports the mint-floor error

- **Location:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:154-165`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultExecution.sol:63-66`.
- **Invariant or requirement:** PLAN:178 requires an exit unable to convert all unwanted claim to revert `AmountOutNotMet` without burning.
- **Impact:** Observation: incomplete exit conversion sets the generic `plan.failed`; execution maps every such failure to `MinLiquidityNotMet`. Inference: rollback may occur, but the public failure contract is the wrong one and consumers cannot distinguish the required exit failure from a genesis mint condition.
- **Fix direction:** Distinguish exit-conversion failure from mint-floor failure and assert the named exit error with unchanged shares and balances.
- **Evidence class:** Direct source/control-flow inference.

## 6. Sections 12-13 - Single and constant-product rows do not prove borrowed execution

- **Location:** `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol:54,65-68,133-137,159`; `contracts/hooks/uniswap/v4/standardExchange/single/TestBase_UniswapV4SingleStandardExchangeBufferHook.sol:94-100,152-161`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol:101-120`; `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol:91-96`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol:85-102,118-129`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultExecution.sol:178-189,199-204`.
- **Invariant or requirement:** PLAN:262,291,378 and FS-A25 require mint/burn while the vault's bound manager is unlocked, not merely while some other manager is unlocked.
- **Impact:** Observation: the inherited hook setups create managers with their own salts; the fixture creates another manager with `SeMatrix_FullSpreadV4_PoolManager`. Neither single row rebinds the inherited manager to the fixture manager. Execution tests unlock state on the vault's own manager. Inference: their hook swaps can take the vault's locked path and therefore do not establish the requested borrowed-unlock integration. `BufferHookIntegration.t.sol:21-28` inherits the same CP setup.
- **Fix direction:** Bind hook and vault to the same manager while retaining disjoint PoolKeys and the required setup constraints; prove zero nested unlocks and this vault's zero closing deltas on that manager.
- **Evidence class:** Direct setup observation plus execution-path inference.

## 7. Section 12 - Stable raw-control fallbacks discard the PairToken pricing provider

- **Location:** `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:94-110,127-134`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:128-145,163-171`; `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol:116-121`.
- **Invariant or requirement:** PLAN:221 requires a stable share leg to be priced through its configured provider, not treated as a face-unit peg; the raw controls must remain distinct from FS-A26.
- **Impact:** Observation: after rejecting the identity binding, both stable rows retain the PairToken share as a pool token but clear its provider as well as its SE binding. Curve's corresponding valuation path uses pairAmount directly when that provider is zero. Inference: even the continuing face/raw control runs in a stable pool whose retained share leg no longer has the required pricing record. Calling it a raw control does not satisfy the explicit share-pricing rule.
- **Fix direction:** Preserve correct provider-based pricing in any permitted non-converting control; otherwise record that control as unresolved rather than seeding a unit-valued share substitute.
- **Evidence class:** Direct source observation and valuation inference.

## 8. Section 12 - Dual/orbital address-side selection leaves the provider bound to an older vault

- **Location:** `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:46-68,123-148,263-275`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:56-78`.
- **Invariant or requirement:** PLAN:221 requires one PairToken identity record whose share, SE, reserveVault and rateSubject are the same vault; both product-index cases must use that correct record.
- **Impact:** Observation: `initialize` deploys the provider for the initial share. `deployNamed` changes `vault` and `share` and bootstraps the new vault but never replaces `provider`. `pair` can call this repeatedly without reverting rejected candidates, despite the comment saying candidates do not coexist. Inference: when address-side selection needs a later candidate, the eventual leg token/SE and provider subject disagree. Rejected binds cannot establish which identity configuration was actually tested.
- **Fix direction:** Construct the provider after selecting the sole retained vault, or otherwise keep the complete identity record synchronized and isolate discarded candidates.
- **Evidence class:** Direct source/control-flow inference; conditional on the candidate-selection branch.

## 9. Sections 2, 13 - Required standalone and composed gas gates are absent

- **Location:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Money.t.sol:61-186`; `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/BufferHookIntegration.t.sol:28-108`; `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/QuotesAndRate.t.sol:92-95`.
- **Invariant or requirement:** PLAN:24,372,378-381 requires six cold standalone money/maintenance bodies at most 11,900,000 gas, complete composed transactions at most 12,000,000, and previews within 5,000,000.
- **Impact:** Observation: Money and BufferHookIntegration have no such measurements; the examined inherited CP tests also have no gas gate. QuotesAndRate measures only one one-sided mint preview. Inference: none of the six required standalone routes or whole composed transactions has the specified acceptance gate, and one preview probe cannot establish all claimed preview routes.
- **Fix direction:** Add the required isolated cold-body and whole-transaction measurements, without prewarming through preview, and preserve unresolved status for oversized routes.
- **Evidence class:** Missing assertions in fully examined designated files; no gas result inferred.

## 10. Sections 5, 13 - Package acceptance is reduced to four smoke tests

- **Location:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Package.t.sol:24-68`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol:36-113`.
- **Invariant or requirement:** PLAN:371 and inventory 013, 029, 032, 042, 052 require FS-A01-A04/A16, proxy selector coverage, invalid contexts/bindings, slot separation, callable shared getters, no retained temporary hook, usable no-bool-approve tokens, and actual permit operation.
- **Impact:** Observation: the file tests bootstrap, two domain strings, absence of getRate/asset, and that a direct transfer does not instantly mint. It does not test bindingHash changes, invalid components/keys/contexts, repeated initialization, slot separation, the full installed/absent selector manifest, temporary-hook removal, a no-bool approve route, or signing and using permit. Inference: domain inspection and source manifests do not execute those package acceptance requirements.
- **Fix direction:** Add the prescribed proxy-level positive/negative package assertions and permit/token integration cases. Keep excluded audit mechanisms as absence checks, not invented implementations.
- **Evidence class:** Missing/partial tests, not an assertion that the matching production selectors are wrong.

## 11. Sections 7, 13 - Vault funding and pretransfer acceptance cases are missing

- **Location:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Money.t.sol:64-121,143-184`; `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Package.t.sol:60-66`; `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/BufferHookIntegration.t.sol:37-63`.
- **Invariant or requirement:** PLAN:152-158,389-390,413-418 requires full pull funding, caller-bound burns, maximum-bounded refunds, the one-token shortfall behavior, bundle over-max rollback, direct-transfer/first-deposit controls, and staged-credit separation.
- **Impact:** Observation: Money's successful routes use pull funding; it contains no true-pretransfer success/shortfall/excess case or bundle over-max test, no parked-share burn rejection, and no separate payer/refund-recipient test. Package only checks supply immediately after a transfer; the staged transfer test exercises a hook, not the missing vault-level cases. Inference: required funding branches can regress while all these tests remain unchanged.
- **Fix direction:** Exercise the specified cases through real public routes with separate caller/recipient roles and exact balance, refund, supply, and rollback assertions.
- **Evidence class:** Missing assertions in designated files.

## 12. Sections 9-10, 13 - Fee, floor, and exiting-claim economics lack independent assertions

- **Location:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Money.t.sol:75-121,173-184`; `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Package.t.sol:25-43`; `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/QuotesAndRate.t.sol:61-85`.
- **Invariant or requirement:** PLAN:170-180,390,401-403,413,423,430 requires exact floor/gross/net issuance, bounded live usage fees, feeTo-zero behavior, 1e13 precision, no over-mint loop, pre-burn unpaid/booked claims, and preservation of other holders' inventory.
- **Impact:** Observation: the tests compare one planner quote with execution and check positive outputs; the genesis assertion only says totalSupply exceeds depositor shares. There is no independent exact 1,000 zero-address floor check, fee clamp/precision/zero-recipient matrix, two-holder booked-plus-unpaid exit apportionment, or round-trip/over-mint accounting oracle. Inference: a shared planner/execution arithmetic defect can satisfy the existing parity tests, including the defects in findings 1-3.
- **Fix direction:** Add independent supply/liquidity and per-holder claim expectations, on both exit shapes and both unlock paths, with the specified fee cases and inventory isolation.
- **Evidence class:** Partial economic proof; no failed runtime result claimed.

## 13. Sections 9, 11-13 - Maintenance, remainder, event, and operator matrices are incomplete

- **Location:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Money.t.sol:123-141`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultExecution.sol:137-175`.
- **Invariant or requirement:** PLAN:184-186,196,242,372,402,419-427 and FS-A39 require fee collection ordering, one-/two-token maintenance, share donation, booked remainders, precise marker conditions, later liveness, and live-owner/global/function-operator authorization.
- **Impact:** Observation: the designated test does two owner compounds, checks only that the second has no Compounded topic, and expects Donation for one fresh token donation. It never appoints operators, changes feeTo, tests a stranger or function-scoped denial, measures collect/swap/add ordering, distinguishes fresh-only from booked/fee-funded Compounded events, proves a retained remainder or its later use, tests share donation, or follows a pool donation with compounding and a non-dust later deposit. Inference: most required maintenance and authorization outcomes are untested.
- **Fix direction:** Complete those public-path cases, including empty/no-event and failed/no-event assertions, booked inventory conservation, and live ownership rather than stored-owner assumptions.
- **Evidence class:** Missing/partial assertions; matching modifier source is not runtime proof.

## 14. Sections 6, 11, 13 - Disable coverage omits most routes and all buffered cases

- **Location:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Money.t.sol:147-163`; `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/BufferHookIntegration.t.sol:28-108`; `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/AlreadyUnlocked.t.sol:73-122`.
- **Invariant or requirement:** PLAN:110,198,383,424 requires the complete disabled predicate, deadline priority, allowed maintenance/withdrawals/views, and buffered withdrawal/non-withdrawal outcomes while unlocked.
- **Impact:** Observation: Money checks deadline on one mint call and blocks one mint while allowing one one-token exit. The designated integration and borrowed files do not disable a vault. Inference: pass-through, bundle-in/out, disabled exact-out error selection, maintenance/views, and borrowed/buffered disable behavior are not covered.
- **Fix direction:** Add the route matrix, using the actual buffered manager context and checking enabled exact-out separately.
- **Evidence class:** Missing acceptance coverage.

## 15. Sections 8, 13 - Callback tests do not reach the committed-payload lifecycle

- **Location:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Callbacks.t.sol:11-22`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultExecution.sol:30-38,199-216`.
- **Invariant or requirement:** PLAN:162,375 and FS-A17-A18 require one consumed callback per action, replay rejection after each callback, guard continuity, zero borrowed unlocks, and no token movement on unauthorized callbacks.
- **Impact:** Observation: both tests call the callback outside a live guarded operation. Even the manager-pranked test reaches the idle guard rejection before payload consumption. Neither test performs a multi-action deposit/exit, checks action counts/relock, attempts replay during the relevant lifecycle, or snapshots token movement. Inference: the commitment and guard-between-actions contract has no designated test.
- **Fix direction:** Observe real manager/action events and calls around production multi-action routes and assert the lifecycle without replacing or injecting the system under test.
- **Evidence class:** Direct test-body observation and branch-coverage inference.

## 16. Sections 8, 13 - Borrowed-path tests omit isolation, rollback, and exit parity

- **Location:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/AlreadyUnlocked.t.sol:35-49,73-122`.
- **Invariant or requirement:** PLAN:166,376,390,401,403 and FS-A19-A23/A33-A34/A36-A37 require self-funding, no nested unlock, stable position identity, forbidden-route checks, own-delta isolation, both forms of rollback, and the same economics as locked execution.
- **Impact:** Observation: three tests cover a funded mint with closing vault deltas, bundle-in rejection, and pretransfer rejection. The caller always propagates failure. There is no share exit/pass-through parity, own-delta-at-entry negative, unrelated outer debt preservation, caught failure, propagated outer failure after success, unowned input/share test, bundle-out/donate/compound rejection, zero-unlock count, or position identity comparison. Inference: the hard borrowed-path acceptance requirements remain substantially unexecuted.
- **Fix direction:** Complete the public borrowed-context cases with the real manager, independent economic comparisons, exact entry/close behavior, and before/after state assertions.
- **Evidence class:** Missing test branches and assertions; the funded non-hook success is retained as coverage.

## 17. Sections 5, 8, 13 - Native tests stop before withdrawal and borrowed settlement

- **Location:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Native.t.sol:33-78`.
- **Invariant or requirement:** PLAN:104,164,374 and FS-A10/A35 require WETH-only caller-facing inputs/outputs and native borrowed settlement that cannot reuse another actor's sync credit or count backing twice.
- **Impact:** Observation: the file has one value-bearing exchangeIn rejection and locked bundle/one-sided deposits. It has no WETH payout test, native borrowed route, sync-credit interference case, native/wrapped conservation assertion, or value rejection across the other named public boundaries. Inference: the native settlement and output obligations are not proven by these deposit tests.
- **Fix direction:** Add real-manager native exits and borrowed-context settlement assertions, including relevant public nonpayable boundaries and exact WETH/native conservation.
- **Evidence class:** Missing acceptance coverage.

## 18. Sections 10, 13 - Quote tests omit busy-state reserves and dust/fee boundaries

- **Location:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/QuotesAndRate.t.sol:61-109`; `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Money.t.sol:88-103`.
- **Invariant or requirement:** PLAN:190-192,373,398,420,423,428,430 and FS-A32 require live position-plus-fee reserve views, busy/unlocked non-reverting economic views, dust-tick liveness, net-fee/minimum precision, and same-state exit parity.
- **Impact:** Observation: quote tests cover a normal bundle round trip, one unsupported address, one mint preview gas probe, and the exact-out negative. No test queries reserves or economic views during a busy/unlocked operation, separates local balances from position-plus-fees, creates dust ticks, or checks fee precision. Exact-out tests do not snapshot balances around the rejected/zero operations. Inference: ordinary parity and selector absence leave the specified quote boundary requirements unexecuted.
- **Fix direction:** Add those state and arithmetic boundary cases while keeping FS-A12-A15 withdrawn, and assert output equality independently of refund-word equality.
- **Evidence class:** Missing/partial acceptance assertions.

## 19. Section 12 - Required refund controls are skipped, weakened, or tested without a hook call

- **Location:** `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:76-89`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:37-220`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol:240-294`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:177-205,378-380`.
- **Invariant or requirement:** PLAN:240 requires an override in every topology, a fully consumed zero-refund control, and an under-consumed call whose refund reaches the actual calling hook.
- **Impact:** Observation: CP has no override and inherits the `hasPartialCase == false` dust fallback. Single replaces a zero-refund assertion with a less-than-one-percent bound and does not require a positive refund in its other case. The shared helper used by the remaining rows makes direct vault calls under `vm.startPrank(hook_)`; it does not drive the hook's money path. Inference: the first two rows lack the specified controls, and the shared helper proves only vault behavior for an impersonated sender, not that the composed hook path retains the refund as required.
- **Fix direction:** Implement both controls per actual topology, exercise the public hook route, and reconcile the hook's input balance with the returned refund rather than a tolerance or a booked getter.
- **Evidence class:** Direct test-body observation; integration coverage gap, not a claimed runtime refund theft.

## 20. Section 12 - Cross-vault assertions miss deltas and monitor the wrong bundle-out signature

- **Location:** `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:311-333,392-403`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol:183-203`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:142-162`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:179-201`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.t.sol:33-40`.
- **Invariant or requirement:** PLAN:221,291-293 requires no PairToken money calls, both directions, and per-address delta assertions in the canonical proof; PLAN:235 distinguishes the two named exact-out controls.
- **Impact:** Observation: the canonical dual direction helper checks outputs, supply and a position lookup but never asserts per-address deltas. The zero-call guards for `exchangeBundleOut` encode a signature without the output-address array and full minimum-array argument list. The dual true/false exact-out tests both call the same router helper without distinguishing the flag. Inference: even if identity binding becomes accepted, the proof still lacks a required invariant, does not monitor the intended bundle-out selector, and does not independently establish both named trust-flag cases.
- **Fix direction:** Derive the no-call selector from the correct interface, assert the canonical vault/outer delta obligations, and make each trust-flag control exercise its intended route.
- **Evidence class:** Direct assertion/signature observation and coverage inference; no PairToken money call is alleged to have occurred.

## 21. Sections 12-13 - Constant-product currency1 and rollback tests stop short of their claimed outcomes

- **Location:** `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:56-66,170-179`; `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/BufferHookIntegration.t.sol:87-106`.
- **Invariant or requirement:** PLAN:219,244,270-274,378 requires the second rate-target pool's integration proof, both exact-input directions, and rollback assertions for shares, caller face, and vault face. Inventory 028/054 does not reduce to a same-token route rejection.
- **Impact:** Observation: the currency1 test deploys and checks bindings but never seeds, reads the selected provider rate, or swaps that pool. The CP rollback override checks total supply and vault face but not caller face. The integration file's identity test calls share-to-same-share directly on the vault, not a hook identity bind. Inference: construction is partial coverage, not the complete second-target execution or identity/hook-exit proof.
- **Fix direction:** Execute both directions on the second target pool, complete the rollback balance assertions, and keep direct invalid-route coverage distinct from the plan's identity-bind and successful unwrap requirements.
- **Evidence class:** Partial test coverage. Existing direct invalid-route and binding assertions remain valid coverage.

## 22. Section 12 - Fixture retains prohibited capacity/booked compatibility seams

- **Location:** `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol:101-111`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol:269-293`.
- **Invariant or requirement:** PLAN:215 says limitCapacity/openCapacity are not part of this fixture and forbids adding a booked getter.
- **Impact:** Observation: the fixture implements both capacity functions as no-ops and exposes `seBooked()` as the vault's raw token balance. The inherited CP fallback uses that value as a book assertion. Inference: the fixture preserves the explicitly excluded sleeve vocabulary and conflates raw holdings with the private booked ledger; a test using it cannot establish booked-inventory behavior.
- **Fix direction:** Remove reliance on those compatibility seams in this family and express its tests through public outcomes, without adding a production booked getter.
- **Evidence class:** Direct textual mismatch and test-semantic inference.

## 23. Section 12 - Weighted two-leg setup contradicts its specific plan sentence

- **Location:** `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:21-24,44-47`.
- **Invariant or requirement:** PLAN:321 specifically says the weighted two-leg file does not override setUp. PLAN:227 is the more general setup instruction.
- **Impact:** Observation: the two-leg row does override setUp and its comment claims an owner instruction supersedes the plan. No such instruction is part of this assignment's requirements. Inference: the current text cannot be accepted as execution of the specific supplied weighted sentence merely on that comment. This is a conformance discrepancy, not evidence that overriding setup is inherently unsafe.
- **Fix direction:** Reconcile the row with the specific supplied requirement or obtain an explicitly admitted plan amendment; do not use a source comment as the amendment.
- **Evidence class:** Direct text mismatch, with the general/specific plan tension disclosed.

## 24. Sections 12-13 - Evidence labels rejected identity variants as compatible passing rows

- **Location:** `docs/audits/apex-2026-09-17-evidence/hook-se-matrix.json:2660-2702,1685-1727,3785-3829,6446-6499`; `docs/audits/apex-2026-09-17-evidence/hook-se-matrix-finding-descriptions.json:83-90`; `docs/audits/apex-2026-09-17-evidence.md:74`; `docs/audits/apex-2026-09-17-evidence/acceptance.json:1116-1129`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:277-284,303-312,349-360`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol:206-240`.
- **Invariant or requirement:** PLAN:223,293,295,363 requires that rejection records not pass the identity variant and that stale evidence be replaced by actual results of the named rows; FS-A26 remains open until the canonical identity proof executes.
- **Impact:** Observation: the new records use current filenames and disclose FS-HOOK-04, which is an improvement over stale F6 attribution. However, the dual and mixed identity rows are still `COMPATIBLE` with passed counts and empty failures, while their tests return after a rejection; some index cases also return after an unmatched candidate search. The prose says all suites passed and R10.3 remains EVIDENCED while simultaneously saying FS-A26 is open. Inference: successful negative/control tests and unexecuted positive variants are not separated in the machine-readable outcome. A reader cannot use the compatibility label/count as proof of the plan's topology and index outcomes.
- **Fix direction:** Preserve the useful rejection records and successful control results, but separately classify each unexecuted identity/index/rate-target requirement as open or incompatible. Tie replacement evidence to identifiable new-row execution output and do not use a suite's green return as a positive conversion result.
- **Evidence class:** Direct contradiction between source branches and evidence classification. Historical run claims were read, not independently verified; this review does not assert they were fabricated.

# Limits

- Required targets wholly unexamined: **none**.
- Required targets partially examined: **43, 44, 46, 47, 48**, with exact scope recorded above. All production components, all seven designated vault test files, the fixture, all nine topology row files, and the finding-association JSON were examined completely.
- Migration is not certified repo-wide: **19 index paths opened; 599 not examined**. The two named production assignment families were opened; the complete index contained one ComposedStableCommonDetfCommon path. Generated artifacts, all length gates, all ABI bindings, and compilation remain unverified.
- The seven behavior files and additional declared dependencies were consulted only for the specific inherited/setup/migration questions listed. Full preservation of every V3 row or every other-family expectation was not established; no Git history was used.
- Builds, tests, gas measurements, native execution, deployed bytecode, and historical run logs were not independently executed or verified. The code-level inferences are not proof of a runtime exploit or a passing test.
- No peer files, credentials, public search services, plan alternatives, or unadmitted requirements sources were used. Only this owned response file was written. This advisory neither changes the plan nor authorizes implementation.
