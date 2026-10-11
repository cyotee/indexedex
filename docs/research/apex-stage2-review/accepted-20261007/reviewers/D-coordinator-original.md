# D-coordinator independent original

Status: original first pass complete within the inspected scope; partial coverage is explicit below. Author/session: /root. No peer original or cross-review was read before writing this original. Bound source: REVIEW_MANIFEST.md digest 379d2c49ead26ad701503c419ca486ddcd0ae9158e2d879f9f0720129c721439, IndexedEx 5709cb3507a9df72b11ec476d27b79ef88696c3a plus working tree; Crane b35609951b4951a3c107e267e22844a50c4dc043.

## Scope and authority

C01/C12/C13: APEX historical evidence and release provenance, DETF prepaid/refund/residual consumers, production setup and campaign quality. Primary R1/R2/R4/R11/R12/R13 and R14 excluding .2–.4; R14 family implementation cooperation explicitly assigned A–C. Supplements S2-ADD-001/002/008. Stage 1 is complete and accepted; this review does not reopen authorization. Any continuing repair mismatch is STAGE1_OPEN, not a new authorization gate.

Read controlling APEX Stage2 plan/PRD, original audit PDF and 108-criterion plan, Stage1 note/current compare, OD-01–08, INDEXEDEX_AGENT_LAW, IndexedEx testing/adversarial and Crane architecture/deployment/testing rules. Skills used as inspection criteria only. No tests, builds, RPC, simulations, code/test/config changes. Read-only source inspection and content hashing permitted by recorded owner clarification.

## D-F01 — replacement directories fall outside selector/size discovery

- Class/severity/confidence: TEST_DEFICIENCY (verification tooling), Medium, High.
- Origin/requirements: STAGE1_OPEN REQ-08; R12.2/R12.4, R1.3, S2-ADD-008.
- Location: scripts/r12_selector_size_compare.py:36–65 and :130–139; scripts/test_r12_selector_size_compare.py same-directory discovery cases; docs/reviews/apex-2026-09-17-second-audit-readiness/selector-size-compare-stage1-current.json.
- Intended: current deployment-unit inventory must include replacement packages/facets, then check present/fresh artifacts and runtime limits; ABI comparison is separately limited from proxy selectors.
- Observed: discover_artifacts receives surviving baseline rows, derives only their direct parent directories, and uses nonrecursive glob('*.sol'). New FullSpread H/P and Wings directories have no surviving baseline source in those parents and do not appear in the seven newArtifacts. Filtering deleted sources is reasonable but leaves replacement directories undiscovered.
- Reachability/impact: normal compare execution using current baseline silently excludes those replacement deployment units. A zero-missing/zero-oversize summary therefore cannot establish their R12 acceptance. This is not a finding that a current facet is oversized or that a selector is actually missing.
- Evidence: current JSON reports 540 compared, 32 stale sources skipped, seven new units, 52 ABI differences/13 proxy-selector differences. Seven new units are Curve liquidity Ext, Weighted Ext, Slipstream input Ext, Balancer transition, Loop transition, ERC4626 input Ext and ReceiptBacked facet; replacement FullSpread/Wings absent.
- Counterevidence: Stage1 split unit is included; recorded ERC4626 InFacet 24009 and Ext14815 are under 24576. The tool explicitly disclaims proxy-cut certification. Earlier consumer status claims 39 H/P runtimes under EIP-170; that is separate historical evidence and does not repair this inventory.
- Review/execution: INSPECTED/CONTRADICTS; supplied comparison provenance INCOMPLETE_PROVENANCE, outcome UNKNOWN for excluded scope. No execution in this review.
- Readiness: BLOCKS current complete selector/size gate under R12.2/.4 and REQ-08; needed separately authorized correction/evidence is current deployment inventory including replacement directories and actual proxy/cut verification.
- Attribution: D independent original; cross-inspection pending.

## D-F02 — historical release totals do not bind this current tree

- Class/severity/confidence: EVIDENCE_GAP, Medium, High.
- Origin/requirements: STAGE1_OPEN REQ-08 for current named-run provenance; original broader R1.3/R2/R11/R12 release requirements.
- Location: STAGE1_EVIDENCE.md; docs/audits/apex-2026-09-17-evidence/followup-review/independent-completion.json, identity-after.json, phase2 release summary/campaign/fuzz selection records and provenance.json.
- Intended: execution claims bind exact dirty source, dependencies, runtime artifacts, fixtures, commands, toolchain and logs.
- Observed: Stage1 evidence records named passing repairs and counts but describes 5709cb35 plus uncommitted edits as not a release identity. September release completion reports 34909 tests, 3053 suites, 33 campaigns, 540672 calls, historical matrix203; identity is IndexedEx2d69dc1e954f51698f7e26699940171dec2d8a3b / Crane dfc93a9bcf7bcb4376333a10c74d924417b2bfbe, not this snapshot.
- Source comparison: UniswapV4DetfCommon.sol and ReceiptBackedERC4626Target.sol differ from historical hashes. LocalCreditLib, StandardExchangeRateProviderFacet and one DETF invariant match historical individual hashes; unchanged files do not bind changed dependencies or artifacts.
- Impact: present release/campaign sufficiency cannot be inferred from historical counts. No allegation that logs are false or that Stage1 did not complete.
- Counterevidence: historical bundle includes commands, exit codes, log/artifact/source hashes, Forge1.5.1/solc0.8.35/prague/optimizer1/viaIRfalse as reported. Named current Stage1 controls and supplied compare are useful documentary evidence.
- Review/execution: INSPECTED/INDETERMINATE; historical runs HISTORICAL_ONLY/PASS as reported; current Stage1 bundle INCOMPLETE_PROVENANCE/PASS as reported; current full release MISSING/UNKNOWN.
- Readiness: BLOCKS R1.3/R11/R12 claims requiring current runs. Need separately authorized evidence assembly/verification, not automatic code repairs.
- Attribution: D independent original; cross-inspection pending.

## D-F03 — inverse-quote residual retention bypasses OD-08's required zero preview

- Class/severity/confidence: CODE_DEFECT against the locked rule, Medium, High for source/authority mismatch; practical monetary effect unproven.
- Origin/requirements: STAGE1_OPEN REQ-01; OD-01/08, S2-ADD-001; R14.9 error/zero distinction.
- Location: contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:574–575, :599–600, :634–653, :659, :693–694.
- Intended: OD-08 and REQ-01 permit book-and-wait only after successful Standard Exchange previewExchangeIn returning zero; reverting previews and operative joins remain hard.
- Observed: _retainSubSharePairResidual is called before _pairQuoteIsZero. With supported exact-output quantity quoting, it calls quoteState/quoteInputForExactShares and can update the holder reserve and return true without ever calling previewExchangeIn. The unsupported-interface branch does require the preview; the supported branch does not.
- Reachability: configured pair SE advertising the exact-quantity interface and inverse indicating a below-one-share input. Normal residual consumers can exit before the mandated direct preview. No claim that the inverse is numerically wrong; missing required preview also leaves its validation/failure semantics unobserved.
- Counterevidence: UNISWAP_V4_FULLSPREAD_CONSUMER_STATUS.md:13–18 explicitly describes supported opaque inverse retention. That is implementation-status evidence, not an owner amendment to OD-08. Actual join catches were removed and _entryJoinResidualAtomic:616–627 hard-reverts zero LP; _pairQuoteIsZero:670–674 is direct. The supportsInterface catch itself is outside OD-01 and is not this finding.
- Tests: prod-se/UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol supplies zero-preview/rollback controls but its V3 route exercises the unsupported inverse branch, not proof of the supported-inverse preview precondition.
- Review/execution: INSPECTED/CONTRADICTS; current runtime INCOMPLETE_PROVENANCE; no runtime outcome inferred.
- Readiness: BLOCKS REQ-01 closure under current text. Resolve with compliant source/tests or an explicit owner rule permitting the inverse as separate retention proof. No automatic policy change or repair.
- Attribution: D independent original; independent A/C source/authority challenge requested only after freeze.

## D-F04 — manager mocking weakens the missing-registry-query regression

- Class/severity/confidence: TEST_DEFICIENCY, Low, High.
- Origin/requirements: original R2.6; IndexedEx testing skill production-first ladder item7.
- Location: test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/adversarial/Adversarial_TrustFlags.t.sol:55–65.
- Intended: actual package/registry/manager behavior; skill expressly forbids manager/registry vm.mockCall as SUT.
- Observed: test_APEX005_D37_registryWithoutIsDisabled_revertsDonate uses vm.mockCallRevert on indexedexManager isDisabled. The exact revert check proves reaction to an injected response, not the stated registry integration through genuine production deployment.
- Impact/counterevidence: narrow setup-quality defect, not proven production failure. The suite otherwise uses a production TestBase and exact revert bytes; external non-SUT dependency fault injection elsewhere remains permitted.
- Review/execution: INSPECTED/CONTRADICTS; historical execution cannot waive setup rule.
- Readiness: BLOCKS treating this one test as R2.6-compliant integration evidence. Need an authorized production-valid setup or explicit applicability exception, not a new mock SUT.
- Attribution: D independent original; cross-inspection pending.

## Positive source conclusions and bounded limits

DETF intake: UniswapV4DetfCommon._pullToken:390–415 uses actual received delta for false, guarded available balance minus book capped to exact requested for true. Target:198–230 validates routes; mint:259–305, stake:343–376 and bond seat:602–623 consume bounded/produced amounts and synchronize. Funded StakedDETF leaf intentionally rejects prepaid input; parent acquires then approves a false-path transfer. Do not restore the legacy unpaid staking path from old R13 wording. Legacy RebasingDETFTokenTarget exact-out/burn paths retain their scoped authorization, bounded budget and held-share distinction.

Balancer Single/Multi/Mixed/Composed common pull functions use guarded bounded credit; MultiVaultWeightedDetfExchangeQueryTarget refunds credited-used, ComposedStableCommonDetfExchangeOutQueryFacet uses bounded prepaid and recombines/refunds only unused received staking input. No new booked-inventory payout defect established in these inspected paths. contracts/test/bases/DetfExactOutCreditAssertions.sol independently seeds book/excess and asserts legitimate refunds and shortage errors.

Constant-product ClaimLib.previewResidualBuffer:246–251 directly returns the SE preview; bufferQuotedResidual:255–262 uses the returned minimum with hard exchangeIn. All four callers were read: DepositCommon:370–383, SeTarget:474–488, Target:388–400, WithdrawTarget:375–387 return locally on zero; none catch preview reverts or update a DETF holder book. Positive direct-call result for S2-ADD-002 is distinct from D-F03.

Campaigns: current DetfStatefulActions rotates eight actions with attempted/succeeded/expected/unexpected counters and real funded operations. UniswapV4Detf_Invariant uses production registry setup, explicit acceptable failures and snapshots, lifecycle assertions and 256×64 configuration. Other four DETF stateful definitions and selected handlers have corresponding counters. The older Handler_MultiVaultWeightedDetf.sol is not the active handler of the current invariant; its catches were not attributed as current campaign vacuity. Full per-family campaign enumeration and execution remain limited. Historical 33 entries include an obsolete V4 fullspread path.

LocalCreditLib.t.sol uses independent expected-budget calculations and real signAndAttachDelegation for EIP-7702. AtomicPretransferCaller is a shared production-path integrator fixture, not ownership authentication. D12 accepts only non-atomic unbooked-credit provenance risk, not refund of booked inventory or EOA access.

Historical fork inventory: APEX20260917_HistoricalInventory.t.sol separately handles the seven instances/custody, full registry, primary historical behavior, selector derivation and current inspection. The supplied September24 summary reports six passes; no fresh chain state is asserted. Availability failures do not prove safety; current source cannot change immutable deployed code.

Audit PDF was read locally with already-installed pypdf after pdftotext was unavailable; nothing installed. Seven entries: 001-M Critical, 001-M2 scope extension, 003/008/009/004B High and 005 structural High. beforeSwap was withdrawn; weighted dust downgraded Informational. Claims require separate evidence-qualified current mappings.

## Individual primary criterion records

All below are APPLICABLE except scoped amendments noted; execution is HISTORICAL_ONLY or INCOMPLETE_PROVENANCE, never a Stage2 run. MATCHES means inspected source/document behavior only. Partial entries deliberately prevent a blanket complete claim.

- **R1.1**: INSPECTED / INDETERMINATE — historical finding-matrix and evidence markdown contain seven findings and two retractions; current replacement mappings need A–C input. D-F02 limits current verification.
- **R1.2**: INSPECTED / MATCHES — historical state vocabulary and D12 restriction are explicit; current review keeps historical claims separate.
- **R1.3**: INSPECTED / INDETERMINATE — historical provenance has versions, commands and hashes; current named Stage-1 runs lack complete source/artifact/run binding (D-F02).
- **R1.4**: PARTIAL / INDETERMINATE — historical credit-refund inventory read, current DETF pull/refund sites traced; replacement-wide payout census remains reconciliation work. Historical 125/20 counts are not current coverage.
- **R1.5**: INSPECTED / MATCHES — existing working-tree edits preserved; reviewed existing regressions without duplication.
- **R1.6**: INSPECTED / MATCHES — PDF and finding matrix connect 005 structural failure to concrete findings; 001-M2 remains instance scope of 001-M.
- **R2.1**: INSPECTED / INDETERMINATE — historical red/green records exist; OD-04/07 supersede old-source red requirement for new vaults. No source-bound current run claim.
- **R2.2**: INSPECTED / MATCHES — historical fork source distinguishes open/closed/unavailable and current fork inventory; baseline characterization not current security proof.
- **R2.3**: PARTIAL / INDETERMINATE — inspected atomic caller, actual EIP-7702 delegation and DETF actor selection; exhaustive per-surface actor coverage needs A–C reconciliation.
- **R2.4**: INSPECTED / CONTRADICTS — precise error/state assertions inspected in credit and DETF suites; supplied wider bare-revert scan still fails. D-F02 and B custody review control remaining scope.
- **R2.5**: PARTIAL / INDETERMINATE — same-route funded controls inspected in LocalCreditLib, DETF exact-out and stateful actions; one-per-every-negative inventory not established.
- **R2.6**: INSPECTED / CONTRADICTS — production package/registry setup verified in DETF TestBases, but manager mock in trust-flag test violates explicit setup rule (D-F04).
- **R4.1**: INSPECTED / INDETERMINATE — historical fork source inventories seven vaults plus custody; current replacement map/provenance separate, no fresh chain reads.
- **R4.2**: INSPECTED / INDETERMINATE — pinned historical full-registry enumerate/classify test exists; supplied September six-pass summary is historical.
- **R4.3**: INSPECTED / INDETERMINATE — primary positive historical probe and per-instance gate classifications in fork source; no Stage-2 fork run.
- **R4.4**: INSPECTED / MATCHES — fork test derives selector from signature, checks 0x46f910ac and typed book/token interpretation; execution historical.
- **R4.5**: INSPECTED / INDETERMINATE — historical/current inventory tests distinct and archive availability explicit; cannot infer current chain state.
- **R4.6**: INSPECTED / MATCHES — integration notes explicitly distinguish immutable deployments and replacements. No live remediation claimed.
- **R11.1**: PARTIAL / INDETERMINATE — independent LocalCredit oracle and 16-property historical inventory inspected; full current mixed-decimal property denominator requires family reconciliation.
- **R11.2**: PARTIAL / INDETERMINATE — five production DETF campaign definitions and current handlers inspected; historical 33-campaign list contains superseded V4 path, new vault denominator unproven.
- **R11.3**: INSPECTED / INDETERMINATE — current DETF definitions pin 256×64, hard action counters and lifecycle checks; historical execution does not prove current campaign success.
- **R11.4**: PARTIAL / INDETERMINATE — credit budgets, booked residuals and funded staking liability checks inspected; family-wide assertion completeness not inferred from shared helper.
- **R11.5**: PARTIAL / INDETERMINATE — deterministic failure snapshots and earlier-transfer boundary inspected in DETF/credit suites; exhaustive callbacks/allowances coverage awaits family mapping.
- **R11.6**: INSPECTED / INDETERMINATE — historical selections/seeds and completion preserved; no present counterexample search, old audit math/vacuous campaign not adopted.
- **R12.1**: INSPECTED / INDETERMINATE — Stage-1 note says build passed; FactoryService artifact indirection makes exact runtime provenance material (D-F02).
- **R12.2**: INSPECTED / CONTRADICTS — declaration/cut source present, but compare discovery misses replacement directories and cannot certify proxy cuts (D-F01).
- **R12.3**: INSPECTED / INDETERMINATE — historical full release logs retained, current full hermetic release evidence absent (D-F02).
- **R12.4**: INSPECTED / INDETERMINATE — current compare zero oversize only for its scanned subset; current replacements excluded (D-F01). No oversized current runtime established.
- **R12.5**: INSPECTED / INDETERMINATE — all historical claims mapped; current critical/high closure cannot inherit historical release counts.
- **R12.6**: INSPECTED / MATCHES — integration notes cover credit/refund, D12 and immutable replacement distinction; current family mapping must accompany submission.
- **R13.1**: PARTIAL / INDETERMINATE — DETF common and Balancer family guarded bounded intake inspected; current funded staking supersedes legacy prepaid acceptance on its own leaf. Other families assigned A–C.
- **R13.2**: PARTIAL / INDETERMINATE — LocalCredit tests use real signAndAttachDelegation, constructor negative and atomic caller; no vm.etch substitution there. Per-proxy coverage not inferred.
- **R13.3**: INSPECTED / MATCHES — Crane SE in/out and multi-vault interface NatSpec state bytecode/atomicity/credit contract. D12 is integrator residual only.
- **R13.4**: PARTIAL / INDETERMINATE — DETF exact-in actual delta/exact requested and exact-out bounded credit/refund inspected; global per-leg inventory requires A–C.
- **R13.5**: PARTIAL / INDETERMINATE — shared exact-out tests seed booked and excess balances, independent budgets; every exact-in token/share/leg negative not independently enumerated.
- **R13.6**: INSPECTED / MATCHES — current DETF _stakeHeld consumes acquired operation amount with funded staking false path; legacy burn authorization explicit. FullSpread native SY exception belongs to A.
- **R13.7**: PARTIAL / INDETERMINATE — full-set reserve sync and bounded refunds traced in DETF families; lower-level no-book consumers and current replacements assigned A–C.
- **R13.8**: PARTIAL / INDETERMINATE — current agent law funded staking and historical integration amendment table read; every D16 family PRD contrary sentence not exhaustively searched.

### R14 coordination records

- **R14.1**: PARTIAL / INDETERMINATE — current capacity-family matrix and policy read; family implementation inspection delegated B/C.
- **R14.5**: PARTIAL / INDETERMINATE — criterion read in full; lending/staking/receipt/AMM implementation and tests assigned B, with native-BPT/hooks C and vault-specific policy A. Final synthesis must cite their original and cross evidence individually.
- **R14.6**: PARTIAL / INDETERMINATE — criterion read in full; lending/staking/receipt/AMM implementation and tests assigned B, with native-BPT/hooks C and vault-specific policy A. Final synthesis must cite their original and cross evidence individually.
- **R14.7**: PARTIAL / INDETERMINATE — criterion read in full; lending/staking/receipt/AMM implementation and tests assigned B, with native-BPT/hooks C and vault-specific policy A. Final synthesis must cite their original and cross evidence individually.
- **R14.8**: PARTIAL / INDETERMINATE — Balancer native-BPT controls assigned C; no inference from callback declaration alone.
- **R14.9**: INSPECTED / CONTRADICTS — hard-call residual repair present but D-F03 bypasses required zero-preview proof. D41/D48 are separate authorized staticcall rules.
- **R14.10**: PARTIAL / INDETERMINATE — criterion read in full; lending/staking/receipt/AMM implementation and tests assigned B, with native-BPT/hooks C and vault-specific policy A. Final synthesis must cite their original and cross evidence individually.
- **R14.11**: PARTIAL / INDETERMINATE — criterion read in full; lending/staking/receipt/AMM implementation and tests assigned B, with native-BPT/hooks C and vault-specific policy A. Final synthesis must cite their original and cross evidence individually.
- **R14.12**: PARTIAL / INDETERMINATE — criterion read in full; lending/staking/receipt/AMM implementation and tests assigned B, with native-BPT/hooks C and vault-specific policy A. Final synthesis must cite their original and cross evidence individually.
- **R14.13**: PARTIAL / INDETERMINATE — criterion read in full; lending/staking/receipt/AMM implementation and tests assigned B, with native-BPT/hooks C and vault-specific policy A. Final synthesis must cite their original and cross evidence individually.
- **R14.14**: PARTIAL / INDETERMINATE — criterion read in full; lending/staking/receipt/AMM implementation and tests assigned B, with native-BPT/hooks C and vault-specific policy A. Final synthesis must cite their original and cross evidence individually.
- **R14.15**: PARTIAL / INDETERMINATE — criterion read in full; lending/staking/receipt/AMM implementation and tests assigned B, with native-BPT/hooks C and vault-specific policy A. Final synthesis must cite their original and cross evidence individually.
- **R14.16**: PARTIAL / INDETERMINATE — criterion read in full; lending/staking/receipt/AMM implementation and tests assigned B, with native-BPT/hooks C and vault-specific policy A. Final synthesis must cite their original and cross evidence individually.
- **R14.17**: PARTIAL / INDETERMINATE — criterion read in full; lending/staking/receipt/AMM implementation and tests assigned B, with native-BPT/hooks C and vault-specific policy A. Final synthesis must cite their original and cross evidence individually.
- **R14.18**: PARTIAL / INDETERMINATE — criterion read in full; lending/staking/receipt/AMM implementation and tests assigned B, with native-BPT/hooks C and vault-specific policy A. Final synthesis must cite their original and cross evidence individually.
- **R14.19**: PARTIAL / INDETERMINATE — criterion read in full; lending/staking/receipt/AMM implementation and tests assigned B, with native-BPT/hooks C and vault-specific policy A. Final synthesis must cite their original and cross evidence individually.
- **R14.20**: PARTIAL / INDETERMINATE — criterion read in full; lending/staking/receipt/AMM implementation and tests assigned B, with native-BPT/hooks C and vault-specific policy A. Final synthesis must cite their original and cross evidence individually.
- **R14.21**: PARTIAL / INDETERMINATE — criterion read in full; lending/staking/receipt/AMM implementation and tests assigned B, with native-BPT/hooks C and vault-specific policy A. Final synthesis must cite their original and cross evidence individually.

- **S2-ADD-001**: INSPECTED / CONTRADICTS, D-F03. Actual joins hard-call; only supported-inverse retention remains inconsistent with exclusive preview wording.
- **S2-ADD-002**: INSPECTED / MATCHES for direct CP preview and four local-retention callers; execution INCOMPLETE_PROVENANCE, REQ-02 named-run claim not independently verified.
- **S2-ADD-008**: INSPECTED / INDETERMINATE, D-F01/02. Supplied Stage1 current map/compare read, replacement coverage and current artifact/run binding not closed.

## Catalogue and second-inspection needs

Relevant adversarial categories: A donation/book attribution; E callbacks/guard rollback; I trust flags/forged credit/second consumption; K residual donation/ownership; J multi-leg exactness; L–O as family capability dictates. Existing source asserts selected categories, not universal catalogue completion. D12 and immutable deployments remain explicit accepted residuals. No new accepted residual was invented.

Second reviewers should challenge all four findings, current residual owner-rule precedence, missing-directory discovery and claimed current-run binding. Shared critical seams need source recheck from A–C: SE book vs external market, receipt/ERC4626/SE sync, each hook's credit/refund math and callbacks, native-BPT no-booking policy, current campaign/matrix replacements and production cuts. No exploit instructions or code changes accompany this review.

