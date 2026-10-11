# B-credit-lending — bounded cross-review

Reviewer `/root/credit_lending`; 2026-10-07. This is the single cross-review wave authorized after the global freeze at 20:21:34 UTC. The four frozen originals A-vaults, B-credit-lending, C-hooks-matrix and D-coordinator were supplied together and read; no cross-review file was read and no original was edited. C's repetitive ordinary-row appendix was also read in a compact representation retaining row keys and design dispositions; that is report review, not independent source inspection of those 210 wrappers.

Source remains the manifest-bound dirty IndexedEx `5709cb3507a9df72b11ec476d27b79ef88696c3a`, Crane `b35609951b4951a3c107e267e22844a50c4dc043`, digest `379d2c49ead26ad701503c419ca486ddcd0ae9158e2d879f9f0720129c721439`. Stage 1 is complete and accepted. This cross-review neither revokes acceptance nor requests it again. Only read-only source/document inspection and this report write occurred; no test, build, scanner execution, simulation, RPC or code/test/configuration change occurred.

## Cross-review dispositions

### A-F01: upheld with its diagnostic-only scope

**Disposition: CONFIRM, Low CODE_DEFECT against the specified error contract; no authorization bypass established.** Independently re-read APEX D9 and R13.1–2: the no-bytecode caller is assigned `EOAPretransferNotAllowed()`, and R13.1 requires the guard before credit. The competing interpretation is that a rejected call never actually credits anything, so an earlier shortfall error is harmless to funds. That is valid counterevidence against a principal-safety allegation, but does not establish the named error contract.

Direct source witnesses:

- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:24–43,71–90`: the external route does not first impose the bytecode guard; supported direct exact-output calls quote and compare prepaid credit before `_secureTokenTransfer`.
- Sibling `UniswapV3FullSpreadStandardExchangeVaultOutMultiTarget.sol:22–44`: the supported dual exit similarly rejects insufficient share credit before guarded share delivery. Sibling `Common.sol:897–913` supplies the unguarded budget helper and later delivery dispatch.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:94–106,153–165` and `ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol:94–106,153–165`: both exact-share input and direct exact-output compare usable credit before the token-delivery helper. Each corresponding `Common.sol:901–921` places the caller guard inside that later helper.

This confirms ordering conditional on a supported, otherwise valid quote; no assertion that every invalid EOA call must bypass every route/deadline check is needed. Sufficient-credit EOAs still encounter the guard. Preserve A's historical disclosure and limited readiness effect: it blocks an unqualified exact-error conformance claim, not a finding of successful unauthorized withdrawal. No runtime witness was produced.

### A-F02: upheld, with meaningful controls retained

**Disposition: CONFIRM, Low TEST_DEFICIENCY.** Independently read the complete Wings `Security.t.sol` and `Tokens.t.sol` under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`, with full prefix `UniswapV4UpperLowerWingsStandardExchangeVault`.

Security :29–42 uses a bare expected revert for the outsider redemption. Tokens :53–91 has five further bare expected reverts for fee-on-transfer, pause, blacklist and balance-deficit cases. Its hostile underlying :30 only saves the callback success flag, discarding returned failure data; :79–84 cannot distinguish the intended nested guard from an unrelated nested failure.

The strongest challenge is that these cases retain supply/balance assertions, successful setup and, for pause/blacklist, a successful reopened operation. Those assertions establish useful atomicity and reachability and should remain in the evidence table. They do not identify the named rejection cause. Other Security tests pin specific permit/deadline/slippage errors and do not share this particular defect. Restrict the blocker to precise negative-cause coverage, as A does. This is not a newly discovered Wings production failure.

### A-F03: upheld, without asserting an observed empty campaign

**Disposition: CONFIRM, Medium TEST_DEFICIENCY.** The entire Wings `Invariant.t.sol` was re-read. Handler :32–51 catches all four operation failures. Only deposit/withdrawal success counts exist. Setup :58–76 calls the same catching deposit method; invariant :78–96 never asserts those counts and conditions the positive-value check on nonzero supply. Trade and rebalance do not count successful executions.

The competing explanation—deterministic suites already show successful money operations—does not repair the invariant campaign's own unenforced workload. Current runtime behavior may produce many successes; no claim of actual zero successes is made. The source nevertheless permits a campaign that does not establish its intended lifecycle coverage. Preserve A's useful custody, issued-supply and pool-position invariants; the deficiency is successful-operation coverage, not that every assertion is vacuous in every run.

### D-F04 and C-005: upheld under explicit production-fixture rules

**D-F04 disposition: CONFIRM, Low TEST_DEFICIENCY.** `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/adversarial/Adversarial_TrustFlags.t.sol:55–65` directly replaces `indexedexManager.isDisabled` with `vm.mockCallRevert`. `.claude/skills/indexedex-testing/SKILL.md:29–35,132–133,154` expressly bars a mocked manager/registry under test and requires non-SUT failure fixtures for isolation. The test checks exact injected bytes, so it remains evidence of the caller's behavior under that injected boundary condition. It does not establish the required production registry condition. No broader dismissal of the production TestBase follows.

**C-005 disposition: CONFIRM, Low TEST_DEFICIENCY across all six D49 suites.** The rule is more specific than a general preference against mocks: `docs/audits/apex-2026-09-17-open-item-5-buffer-hook-staticcall-exception-PRD.md` P3 expressly requires the real IndexedEx router, no production SUT mocks, and SE-side dependency failure fixtures. Section 4 describes actual router authorization/session failures and failure on the SE's dependency. Treating SE/router as arbitrary non-SUT dependencies of a narrowly defined pool is therefore not sufficient under this task's cross-product rule.

Re-read actual test bodies in `.../pools/constProd/standardExchange/StandardExchangeBufferPool_D49.t.sol:130–215` and `.../pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePool_D49.t.sol:152–234`. They directly mock router pass/restore and SE preview/exchange selectors, while retaining useful exact-error, rollback and funded-success assertions. A bounded search of every `*_D49.t.sol` under `test/foundry/spec/protocols/dexes/balancer/v3/pools/` confirms equivalent direct replacement sites in:

- stable mixed: `MixedBufferMultiVaultStablePool_D49.t.sol:166,180,199,213,227,242–243,263,277`;
- weighted common: `CommonBufferMultiVaultWeightedPool_D49.t.sol` at those same line numbers;
- weighted mixed-leg: `MixedLegWeightedBufferPool_D49.t.sol:150,164,184,198,212,225`;
- weighted multi-pair: `MultiPairStandardExchangeBufferPool_D49.t.sol` at those same line numbers.

The four latter suites' complete deployment/rollback bodies were not re-audited in this cross-pass; the listed call sites corroborate C's bounded same-pattern claim. The finding concerns fixture conformance, not the authorized D49 staticcall exceptions or proof that operative errors are swallowed. Preserve production funded controls and injected-boundary evidence rather than deleting their evidentiary value.

### D-F02: upheld; historical provenance is itself explicitly qualified

**Disposition: CONFIRM, EVIDENCE_GAP; retain separation from source defects and Stage-1 acceptance.** `STAGE1_EVIDENCE.md` was read in full. It names passing controls, says dirty `5709cb35` is not a release identity, and does not contain a command/log/artifact/content linkage for the present manifest digest. It remains owner-supplied PASS evidence with incomplete provenance, not evidence of failed runs.

The correct full locator for D's abbreviated identity citation is `docs/audits/apex-2026-09-17-evidence/followup-review/phase2-release-001-identity-after.json`. Reading its scalar metadata establishes IndexedEx `2d69dc1e954f51698f7e26699940171dec2d8a3b`, Crane `dfc93a9bcf7bcb4376333a10c74d924417b2bfbe`, and a capture time after the supplied logs. Its `identityScope` expressly states that bundling log/source/artifact hashes does not establish that the captured sources/artifacts produced an earlier log or that artifacts are fresh. This is stronger than merely different HEAD strings: even the historical manifest disclaims a causal execution link. Its large hash maps were not independently authenticated or exhaustively compared here.

`followup-review/independent-completion.json` separately reports PASS, 34,909 tests, 3,053 suites, 33 campaigns and 540,672 calls and points to that identity file. Those are historical reported results; they are not current-source results. A's A-F04 and C's changed-matrix evidence support the same limitation but should not be counted as multiple independent production defects. D's severity expresses release-evidence significance; it does not upgrade this to a monetary vulnerability. Current full release remains MISSING/UNKNOWN under this read-only scope.

## Required correction to B's R14.7 record

**The B original's cooperative R14.7 entry is mapped to the wrong requirement and must not be carried into the consolidated ledger.** It describes Lido/Rocket/EtherFi prechecks; original APEX R14.7 at `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md:614` instead requires Aave partial-position numeric/index/failure controls. Those staking observations remain valid contributions to R14.2/R14.19/R14.20, with B-02's allocation exception. C's cooperative row labelled “R14.7 D33 AMM caller-fund separation” also does not establish R14.7; that AMM condition is expressed in R14.20. These are report mapping corrections, not source defects.

Replacement criterion record:

- **Criterion/reference/applicability:** R14.7, APEX :614, D43; APPLICABLE to Aave Cross-Version Loop, original-program.
- **Owner/review/result:** coordinator primary, B lending contribution; PARTIAL / INDETERMINATE for the full criterion. The two inspected test bodies are meaningful but insufficient to label the entire required matrix MATCHES.
- **Production/setup evidence:** `test/foundry/spec/protocol/lending/aave/cross-version/AaveCrossVersionLoop_APEX_D43.t.sol:38–80` deploys the loop through the manager with production V3/V4 pools. V3 market TestBase :42–67 and V4 market TestBase :60–88 corroborate actual market orchestration/artifact use. `contracts/test/bases/TestBase_AaveCrossVersionLoop.sol:36–42` selects tokenA at 18 decimals and tokenB at 6 decimals; this is not the criterion's specified all-18-decimal numeric fixture.
- **Actually supported assertions:** D43 :97–109 asserts aggregate tokenA supply approximately at the cap, recursive tokenA debt approximately equal to the retained leverage, no idle tokenA, positive tokenB collateral and healthy V3 position. D43 :114–139 checks zero capacity after an existing position, full local principal, preview/execution agreement, local-first withdrawal, cap-zero reopening and later sweep. Cap zero as unbounded therefore has a concrete source witness.
- **Unestablished details:** the named suite has only those two tests. It does not independently assert each specified recursive layer, exact tokenB collateral and debt, no further iteration, exact no-extra-share attribution in the partial-position case, initial capacity exactly equal to initial supply, a non-unit liquidity-index cap boundary, or a same-state unrelated failure after some progress with original bytes and full position/debt/share/transfer rollback. Its zero-capacity test starts from an existing loop, so it is not the fresh zero-initial-position witness requested by the criterion. Reopening to unbounded capacity does not by itself prove ordering when a reserve sweep consumes a finite amount of headroom before a new caller.
- **Search boundary:** a scoped search of `test/foundry/spec/protocol/lending/aave/cross-version/` for D43, liquidity-index/cap boundary, `setSupplyCap` and rollback terms located the named cap controls in this suite; this is not proof that every possible differently named external fixture is absent.
- **Execution/readiness:** MISSING / UNKNOWN for the bound source; BLOCKS an unqualified complete R14.7 test claim. The gap is test/evidence coverage, not a newly established executor error. If the coordinator needs a finding link, associate this qualified record with the broader test/evidence ledger; do not manufacture a code defect from missing tests.

B's original R14.6 source observations remain useful for executor capacity handling. They do not substitute for R14.7's detailed test assertions. Likewise, the R14.5 MATCHES entry should be read as the specifically cited Stata source paths and tests, not proof of every independently required paused/frozen/inactive branch without a reconciled test map.

## Challenges to B's own findings

- **B-01 retained.** Re-read Camelot `OutTarget.sol:748–764` and `Common.sol:214–219`: the exact-output SE-share zap-out calculates and burns required shares without a false-flag max check; the refund helper returns immediately for false. The strongest competing explanation is downstream execution reverts for some states. That limits practical reachability certainty but supplies no missing max authorization check on a successful route. Keep Medium, caller slippage authorization scope, no third-party theft or runtime reproduction claim.
- **B-02 retained at Low.** Re-read Rocket `Common.sol:446–459,500–515`: a sub-minimum booked allocation returns without investment, and the second attempt consumes aggregate remaining excess without a separate caller bound. D39/R14.3/R14.19 expressly require separate minimum-qualified allocations. Accepted protocol fee socialization and correct ordinary sleeve examples do not waive the minimum-isolation rule. Preserve the original narrow policy impact and absence of demonstrated loss.
- **B-03/B-04/B-05 remain bounded test-to-criterion mismatches.** None of the peer originals supplies a missing custody callback/reuse witness, EtherFi target-boundary matrix, or generic-over-Stata shared-adapter configuration. Their source correctness observations do not establish those missing assertions. The original absence searches remain bounded; these are not claims of repository-wide absence or new runtime failures. No broad repeat audit was performed in this wave.

## Limits and handoff

The six challenged peer findings are supported within the qualifications above. Independent source reinspection was concentrated on the specified seams: exact-output guard placement, Wings assertions/campaign liveness, manager and D49 mocking rules, historical identity metadata, Aave R14.7 and the two B source defects. Other findings were read for conflicts but are not newly certified by this cross-review. No peer cross-review was consumed, no extra wave was started, and no frozen original was changed. Coordinator disposition and final source-stability check remain with the coordinator.
