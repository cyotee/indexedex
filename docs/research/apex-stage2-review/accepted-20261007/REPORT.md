# APEX Stage 2 source review

Report state: **PARTIAL_REPORT**. Delivered 2026-10-07. **Stage 1 is complete and owner-accepted.** Its acceptance and this review's launch/read authorization are permanently recorded; no reconfirmation is required.

## 1. Result

The authorized parallel review and one bounded cross-review wave produced four preserved independent originals, four cross reports, all 108 original criterion records, ten separate supplements, nine historical audit mappings, and the current finite ordinary matrix inventory.

**Twenty consolidated findings remain: 11 Medium and nine Low** — four source conformance defects, fourteen test/tooling deficiencies and two evidence gaps. No new Critical/High finding or demonstrated principal loss was established. A separate Informational original about four-vault execution provenance is retained as an attributed alias of the broader evidence gap, not discarded.

The clearest current production issue is **B-01**: Camelot's false-pretransfer share-to-token exact-output withdrawal does not enforce the caller's maximum share input. **B-02** identifies Rocket's skipped old-reserve allocation being pooled into the next investment. **D-F03** is a source conflict with OD-08's exclusive zero-preview retention rule, with meaningful implementation-intent counterevidence and no demonstrated loss.

This is **not an audit-submission approval**. The expanded Wings/FullSpread configuration-and-route denominator and several detailed assertion/census requirements remain unresolved. Those are inspection/coverage limits, separately from missing current execution evidence. Consequently the controlling plan requires PARTIAL_REPORT rather than INSPECTION_COMPLETE.

Reviewed identity:
- IndexedEx HEAD `5709cb3507a9df72b11ec476d27b79ef88696c3a` plus the existing Stage1 working tree.
- Crane HEAD `b35609951b4951a3c107e267e22844a50c4dc043`, clean at inspection.
- Working content SHA-256 `379d2c49ead26ad701503c419ca486ddcd0ae9158e2d879f9f0720129c721439`, **15,552 files**. The identical closing calculation returned the same count/digest; no reviewed-source drift detected. Scope/method are in [REVIEW_MANIFEST](REVIEW_MANIFEST.md).

## 2. Execution, authorization and attribution

Native sessions /root/vaults (A), /root/credit_lending (B), /root/hooks_matrix (C) and /root (D) performed genuinely overlapping source work, observed at 20:00:17 UTC with substantive progress updates. Each wrote a separate original. D preserved its own original before reading any peer original. All four originals were frozen at 20:21:34 UTC, hashed, and then supplied together to the same sessions for one cross-review wave. No reviewer read another reviewer's cross file or rewrote an original. All four original hashes matched at closing inspection.

**Stage2 ran no builds, tests, fuzz/invariant campaigns, simulations, forks, scanners, RPC or chain checks.** No production, test or configuration file was changed; no tool was installed and no remediation PRD was generated. Read-only shell/source/identity inspection and Markdown report writes were explicitly authorized by the owner after the earlier launch attempt. The three acceptance/authorization note edits were made before snapshot capture. The earlier blocked-at-launch artifact remains historical, with its acceptance/read-permission blockers resolved.

Canonical IndexedEx/Crane testing, adversarial, architecture and deployment rules were read as inspection criteria. They did not authorize test execution. Product-specific law and owner decisions take precedence over obsolete historical criteria. All execution outcomes below are supplied claims, not independently rerun results.

Artifacts:
- [Manifest](REVIEW_MANIFEST.md), [criteria ledger](CRITERIA_LEDGER.md), [audit-item ledger](AUDIT_ITEM_LEDGER.md), [matrix ledger](MATRIX_LEDGER.md).
- Originals: [A](reviewers/A-vaults-original.md), [B](reviewers/B-credit-lending-original.md), [C](reviewers/C-hooks-matrix-original.md), [D](reviewers/D-coordinator-original.md).
- Cross-reviews: [A](reviewers/A-vaults-cross.md), [B](reviewers/B-credit-lending-cross.md), [C](reviewers/C-hooks-matrix-cross.md), [D](reviewers/D-coordinator-cross.md).

## 3. Coverage and separate vault conclusions

Original denominator: **108 IDs, 108 unique**, counts R1=6/R2=6/R3=7/R4=6/R5=6/R6=10/R7=6/R8=5/R9=7/R10=8/R11=6/R12=6/R13=8/R14=21. All have explicit applicability, owner, inspection, evidence, origin and readiness fields. Original row states: **83 INSPECTED, 25 PARTIAL**; inspection results **49 MATCHES, 41 INDETERMINATE, 18 CONTRADICTS**. These are source/requirement dispositions, not test pass counts. R3.1's obsolete-source reconstruction is SUPERSEDED; scoped supersessions within other rows remain visible. Ten supplemental rows retain a separate denominator.

| Coverage group | Substantive inspection | Remaining boundary |
| --- | --- | --- |
| C01 provenance/authority | D historical PDF, evidence/identity, original/current decisions and all criterion ownership | Current artifact/run causality and current payout census incomplete |
| C02 V3 FullSpread | A current custody credit, routes, native/SY, callbacks, outside-trade fixture | Current full execution and retained repeated-movement breadth |
| C03 V4 hookless | A independent no-hook package, book/protection/quote/execution units, route controls | Expanded native/opposite-face/manager matrix and source-bound execution |
| C04 V4 Pons-family | A separate admitted Pons package/registration/fee/binding tests | Same expanded-domain limits; never substituted with hookless |
| C05 Wings | A O1–O7/A3, target-only book/harvest/floor/lifecycle and C consumer fixtures | A-F02/A-F03/C-006 assertion gaps and unresolved exhaustive domain |
| C06 credit/custody | B LocalCredit and actual custody SE/SY paths, precise Stage1 negatives | B-03 and global per-surface actor/callback census |
| C07 receipt/lending | B adapter/cap/sync/dispatch, ERC4626/Stata/Morpho/Aave loop | B-05, D-X01 and full projection/paused/index matrix |
| C08 AMM/staking | B V2/Camelot/Aerodrome and Lido/Rocket/EtherFi credit/capacity/sleeves | B-01/B-02/B-04; focused accounting read is not a complete unrelated AMM-math audit |
| C09 seven hooks | C current direct/callback refund/rate/guard controls | C-002/003/004/007 and unbound broader execution |
| C10 hook × SE | C 210 concrete wrappers plus seven adapter exclusions | Expanded denominator unresolved, C-001 |
| C11 Balancer | C six native-BPT package boundaries, providers and D49 controls | Complete all-family rollback matrix and C-005 |
| C12 DETF consumers | D guarded pull/budget/refund/funded stake/residual paths, selected campaign handlers | D-F03/D-F04; no unrelated economic rewrite; current full campaign census partial |
| C13 cross-cutting | A/B/C production deployment/source cuts, D release/tooling/catalogue review | D-F01/D-F02, some complete interface/campaign/document maps unresolved |

The four vault conclusions are independent:

| Vault identity | Source/test conclusion | Evidence limit |
| --- | --- | --- |
| V3 FullSpread | Local custody, not historical total less live deployed balance, controls input credit. Outside-trade test and additional zero-input/funded/callback controls inspected. | A-F01 diagnostic ordering; no present complete source-bound R3 campaign |
| V4 hookless FullSpread | Distinct zero-hook admission, local book and current funded/quote/native/import controls inspected. | A-F01, incomplete expanded configuration/route and run binding |
| V4 Pons-family FullSpread | Distinct production Pons registration/fee/identity checks and own outside-trade fixture inspected. Not merged with hookless. | Same scoped limits; no substitution by hookless results |
| Wings | Target-only routes and hookless underlying binding; O1/O3 residual ownership, oracle sleeve/floor, A3 inbound-before-harvest and locked-manager behavior inspected. | Deterministic/campaign assertion gaps; full numerical/consumer domain remains incomplete. FullSpread law was not imported into Wings |

The finite ordinary matrix is **217 records**: **202 COMPATIBLE within stated route domains (including 21 control-role rows), eight INCOMPATIBLE and seven DEPRECATED**. This comprises 210 current wrappers plus seven external-BPT adapter exclusions. It does not count incompatible/deprecated controls as passing integrations.

Wings' eleven formal pre-route domains sum to 489,664 ordered assignments, but legality, route/state and mixed-family expansion remain unresolved. This is not a complete admitted denominator and not an execution count. H/P native/opposite-face/manager alternatives also remain explicit. **Zero current matrix rows were established as SUPPLIED_SOURCE_BOUND by this review**; this says nothing about whether unbound tests ran.

Detailed incomplete criterion slices and exact evidence are preserved in [CRITERIA_LEDGER](CRITERIA_LEDGER.md#accounting-and-unresolved-boundaries); no omitted slice is silently considered passed.

## 4. Findings and final dispositions

Every record below inherits the reviewed snapshot in §1. Confidence is high in the stated source/assertion fact unless bounded absence is explicitly qualified. Severity describes the actual identified impact; readiness is a separate field. **BLOCKS means the named acceptance claim cannot be closed**, not that every Low issue proves a release-wide monetary threat.

Full original evidence fields, exact path expansion, setup/assertion details and bounded searches are incorporated through the linked original. Cross references supply challenges and corrections. No exploit procedure, payload or live-system action is proposed.

### B-01 — Camelot exact-output share withdrawal omits the pull-path maximum

**Medium · CODE_DEFECT · original-program/current-product coverage**. Confidence: high in cited control flow/assertions; execution unverified.

- Source: contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol:339–353,709–805; Common.sol:214–219; BasicVaultCommon.sol:151–156.
- Intended requirement: R7.5/.6, R8.5; D15 exact-output authorization.
- Observation and impact: The share-to-pool-token branch computes and burns the required shares without comparing them to maxAmountIn when pretransferred=false. The refund helper immediately returns in that mode. The installed facet/package exposes this route. A successful own-position withdrawal can therefore charge more shares than the caller authorized.
- Counterevidence and limits: True-flag bounded credit and adjacent routes' max checks work independently. Some downstream states may revert; that does not supply a maximum check on successful execution. No third-party theft or runtime loss was demonstrated.
- Readiness: **BLOCKS** complete closure of the requirement above, limited to this recorded property/evidence gap.
- Corrective objective or verification need: Enforce the declared share-input maximum and establish a funded production-proxy negative and valid boundary control. No implementation is authorized by this report.
- Attribution and coordinator disposition: **retain**, with the qualifications above. B original; A and D source reinspection; B cross retained. [Full original](reviewers/B-credit-lending-original.md); [cross](reviewers/B-credit-lending-cross.md).

### D-F03 — Supported inverse retention bypasses the required successful zero preview

**Medium · CODE_DEFECT · STAGE1_OPEN REQ-01**. Confidence: high in cited control flow/assertions; execution unverified.

- Source: contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:574–575,599–600,634–674,693–694.
- Intended requirement: Readiness REQ-01, OD-01/08; S2-ADD-001; R14.9.
- Observation and impact: The supported exact-quantity branch can book residual and return before previewExchangeIn is called. OD-08 permits this retention only after a successful Standard Exchange preview returning zero. This is a literal source/locked-rule conflict; financial harm is not established.
- Counterevidence and limits: Consumer status explicitly describes inverse-based retention, so it is intentional behavior with plausible sub-share justification. Hard joins and direct preview helper are repaired. No explicit owner amendment authorizing the alternative predicate was located. The supportsInterface catch is outside this ruling.
- Readiness: **BLOCKS** complete closure of the requirement above, limited to this recorded property/evidence gap.
- Corrective objective or verification need: Resolve the requirement conflict through compliant source/property evidence or an explicit scoped owner exception for inverse-based proof; do not restore operative catches. No implementation is authorized by this report.
- Attribution and coordinator disposition: **retain**, with the qualifications above. D original; A and C independently re-read both source and competing authority. [Full original](reviewers/D-coordinator-original.md); [cross](reviewers/D-coordinator-cross.md).

### A-F03 — Wings campaign does not require successful state transitions

**Medium · TEST_DEFICIENCY · current Wings supplement**. Confidence: high in cited control flow/assertions; execution unverified.

- Source: test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultInvariant.t.sol:32–96.
- Intended requirement: S2-ADD-009; R11.2–.4; Wings O2/O7 and stateful verification.
- Observation and impact: All four handler actions swallow failures, setup uses the same catching deposit, and success counters are not asserted. A zero-supply run can bypass the positive-value condition while satisfying custody/cash assertions.
- Counterevidence and limits: Deterministic money/rebalance/transition tests perform real funded operations; the invariant is meaningful when transitions occur. No claim the supplied run actually had zero successes.
- Readiness: **BLOCKS** complete closure of the requirement above, limited to this recorded property/evidence gap.
- Corrective objective or verification need: Require successful setup and meaningful money/market/maintenance action coverage with classified failures, alongside safety invariants. No implementation is authorized by this report.
- Attribution and coordinator disposition: **retain**, with the qualifications above. A original; B/C/D source corroboration. [Full original](reviewers/A-vaults-original.md); [cross](reviewers/A-vaults-cross.md).

### B-03 — Custody acceptance cites tests of another product

**Medium · TEST_DEFICIENCY · original-program/current-product coverage**. Confidence: high in cited control flow/assertions; execution unverified.

- Source: docs/audits/apex-2026-09-17-evidence/acceptance.json R5.3; test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_RestingCredit.t.sol:53–168.
- Intended requirement: R5.3; APEX-003 callback and consumed-credit reuse controls.
- Observation and impact: The cited closure suite deploys a generic receipt wrapper and tests different donation/redemption properties. It does not establish the required custody SE self-share callback and reuse controls.
- Counterevidence and limits: Current custody guards, bounded refunds, rebase assertions and Stage1 exact-error repairs are substantive. The absence search is bounded; the cited mapping is demonstrably wrong even if another differently named test exists.
- Readiness: **BLOCKS** complete closure of the requirement above, limited to this recorded property/evidence gap.
- Corrective objective or verification need: Identify or supply the actual custody-route controls and correct criterion-to-test evidence attribution. No implementation is authorized by this report.
- Attribution and coordinator disposition: **retain**, with the qualifications above. B original; D re-read mapping/setup/test bodies. [Full original](reviewers/B-credit-lending-original.md); [cross](reviewers/B-credit-lending-cross.md).

### B-05 — Shared receipt-adapter proof omits required operations and dispatch configuration

**Medium · TEST_DEFICIENCY · original-program/current-product coverage**. Confidence: high in cited control flow/assertions; execution unverified.

- Source: test/foundry/spec/vaults/standard/erc4626/behaviors/Behavior_ReceiptBackedERC4626_CrossInterface.sol:68–138; ReceiptBackedERC4626_SharedFacet.t.sol:92–165.
- Intended requirement: R14.17/.18; related R9.1 and adapter isolation.
- Observation and impact: Shared tests omit the mint-to-unfunded-SE negative and specified post-withdraw/redeem atomic-SE positives; the generic wrapper is over SimpleYield, not a Stata receipt. A smaller adapter deposit is not a test of SE pretransfer credit.
- Counterevidence and limits: All-four-operation implementation sync, generic D45 tests, real shared-facet wiring, marker unit tests and proxy-isolation checks exist. Hook generic/Stata fixtures do not create generic-over-Stata dispatch either. No adapter production defect established.
- Readiness: **BLOCKS** complete closure of the requirement above, limited to this recorded property/evidence gap.
- Corrective objective or verification need: Close the specified two-host operation/configuration gaps with nonzero local backing and correct the historical coverage claim. No implementation is authorized by this report.
- Attribution and coordinator disposition: **retain**, with the qualifications above. B original; C and D source/fixture corroboration. [Full original](reviewers/B-credit-lending-original.md); [cross](reviewers/B-credit-lending-cross.md).

### C-003 — D41 family tests do not distinguish projected-rate selection

**Medium · TEST_DEFICIENCY · original-program/current-product coverage**. Confidence: high in cited control flow/assertions; execution unverified.

- Source: test/foundry/spec/hooks/uniswap/v4/standardExchange/{orbital,weighted,stable/quad/curve}/*APEX_D41.t.sol; contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol:127–151.
- Intended requirement: R10.6 / D41.
- Observation and impact: Family controls assert a positive effective reserve or rated balance. They do not prove the production projection path selected the differing quoteRate, nor the required family invalid/failing selected-response cases.
- Counterevidence and limits: The direct library suite covers the listed selection/failure branches and source retains hard selected-rate behavior. No present production pricing defect established.
- Readiness: **BLOCKS** complete closure of the requirement above, limited to this recorded property/evidence gap.
- Corrective objective or verification need: Demonstrate discriminating projected results and specified failures through each required production family. No implementation is authorized by this report.
- Attribution and coordinator disposition: **retain**, with the qualifications above. C original; D re-read family assertions and library boundary. [Full original](reviewers/C-hooks-matrix-original.md); [cross](reviewers/C-hooks-matrix-cross.md).

### C-004 — D48 tests leave bounded-search and failure distinctions unproved

**Medium · TEST_DEFICIENCY · original-program/current-product coverage**. Confidence: high in cited control flow/assertions; execution unverified.

- Source: test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchange_RateProvider.t.sol:76–178; test/foundry/spec/protocol/dexes/balancer/v3/WrappedStandardExchangeRateProvider.t.sol:68–178; contracts/test/stubs/ApexD48QuoteReplyFixture.sol.
- Intended requirement: R10.7/.8 / D48, with OD-02 live path preserved.
- Observation and impact: The current tests do not establish all provider-specific attempted amounts, recovery/exhaustion boundaries and payload/direct-failure distinctions. Constant-zero/revert fixtures cannot demonstrate a scale-up recovery boundary.
- Counterevidence and limits: Both providers have bounded loops and exact successful reply-length checks; funded rate and supplied-snapshot parity controls are meaningful. OD-02 repair separately matches source.
- Readiness: **BLOCKS** complete closure of the requirement above, limited to this recorded property/evidence gap.
- Corrective objective or verification need: Complete the specified provider-specific search/reply/dependency controls and bind their execution to source. No implementation is authorized by this report.
- Attribution and coordinator disposition: **retain**, with the qualifications above. C original; D source/fixture reinspection. [Full original](reviewers/C-hooks-matrix-original.md); [cross](reviewers/C-hooks-matrix-cross.md).

### D-F01 — Selector/size discovery omits replacement deployment directories

**Medium · TEST_DEFICIENCY · STAGE1_OPEN REQ-08**. Confidence: high in cited control flow/assertions; execution unverified.

- Source: scripts/r12_selector_size_compare.py:36–65,125–139; scripts/test_r12_selector_size_compare.py; selector-size-compare-stage1-current.json.
- Intended requirement: R12.2/.4; S2-ADD-008; readiness REQ-08.
- Observation and impact: The checker searches only direct parents of surviving baseline files. Current Hookless, Pons-family and Wings replacement roots are outside that universe and absent from the seven new units. Zero missing/oversized results apply only to the scanned subset.
- Counterevidence and limits: The ERC4626 split is included and reported under EIP-170. The helper accurately describes same-directory discovery and the JSON disclaims proxy-cut certification. No actual oversized facet or missing installed selector was established.
- Readiness: **BLOCKS** complete closure of the requirement above, limited to this recorded property/evidence gap.
- Corrective objective or verification need: Use a complete present deployment inventory, establish artifact freshness and separately verify real installed proxy selectors. No implementation is authorized by this report.
- Attribution and coordinator disposition: **retain**, with the qualifications above. D original; A/C independent baseline/source/JSON checks. [Full original](reviewers/D-coordinator-original.md); [cross](reviewers/D-coordinator-cross.md).

### D-X01 — Aave partial-position regression matrix remains incomplete

**Medium · TEST_DEFICIENCY · original-program/current-product coverage**. Confidence: high in cited control flow/assertions; execution unverified.

- Source: test/foundry/spec/protocol/lending/aave/cross-version/AaveCrossVersionLoop_APEX_D43.t.sol:38–139; contracts/test/bases/TestBase_AaveCrossVersionLoop.sol:36–42.
- Intended requirement: R14.7 / D43.
- Observation and impact: Two substantive tests establish aggregate tokenA supply/debt, no idle A and local-first capacity/reopening behavior. They do not establish the full specified layer/B-debt/collateral, initial-equal-cap, nonunit-index and post-progress-failure rollback matrix; the fixture's token decimals differ from the specified numeric case.
- Counterevidence and limits: Real registry-deployed V3/V4 pools and useful aggregate/local assertions are present. This is not evidence that the executor is wrong. Search was bounded to the current cross-version spec tree and named acceptance mapping.
- Readiness: **BLOCKS** complete closure of the requirement above, limited to this recorded property/evidence gap.
- Corrective objective or verification need: Identify or supply each missing detailed production-control witness and correct the R14.7 mapping; preserve existing useful tests. No implementation is authorized by this report.
- Attribution and coordinator disposition: **retain**, with the qualifications above. B cross corrected its own mistaken R14.7 mapping; D independently read the same test bodies and recorded the gap in D cross. New stable consolidated ID, not a new review wave. [B corrected record](reviewers/B-credit-lending-cross.md#required-correction-to-bs-r147-record), [D cross](reviewers/D-coordinator-cross.md).

### C-001 — Expanded matrix denominator and coverage remain unresolved

**Medium · EVIDENCE_GAP · original-program/current-product coverage**. Confidence: high in cited control flow/assertions; execution unverified.

- Source: reviewers/C-hooks-matrix-original.md Appendix A/B; docs/plans/records/uniswap-v4-upper-lower-wings/CONSUMER_MATRIX.json and CONSUMER_RESULTS.md; current H/P SeMatrix fixtures.
- Intended requirement: R10.3; S2-AC-09; Wings consumer requirements.
- Observation and impact: The finite ordinary inventory is 217 configuration/control/exclusion records. Wings formal assignments and current native/opposite-face/manager alternatives are not reconciled into a complete admitted route/state denominator. The Wings manifest expressly declares incomplete coverage.
- Counterevidence and limits: Substantial real integration samples and explicit honest disclosure exist. Formal assignments are not tested combinations; no unsupported Cartesian product or symmetry reduction is invented.
- Readiness: **BLOCKS** complete closure of the requirement above, limited to this recorded property/evidence gap.
- Corrective objective or verification need: Resolve legal configuration/route domains and remaining explicit inventory questions, then separately obtain source-bound evidence for applicable controls. No implementation is authorized by this report.
- Attribution and coordinator disposition: **retain**, with the qualifications above. C original/cross census; A and D independently read Wings authority/manifest/results. Ordinary file census is C's attributed work. [Full original](reviewers/C-hooks-matrix-original.md); [cross](reviewers/C-hooks-matrix-cross.md).

### D-F02 — Present release claims lack complete source/artifact/run binding

**Medium · EVIDENCE_GAP · STAGE1_OPEN REQ-08 evidence subset plus original broader release gate**. Confidence: high in cited control flow/assertions; execution unverified.

- Source: docs/reviews/apex-2026-09-17-second-audit-readiness/STAGE1_EVIDENCE.md; docs/audits/apex-2026-09-17-evidence/followup-review/{independent-completion.json,phase2-release-001-identity-after.json}.
- Intended requirement: R1.3, R11, R12; readiness REQ-08; S2-REQ-09.
- Observation and impact: Named current Stage1 passes are not bound to exact executed artifacts/source/logs; September release totals concern an earlier tree. The historical manifest itself disclaims that post-log hashes prove which source/artifacts produced those logs.
- Counterevidence and limits: Owner acceptance is established; logs and named passes remain useful reported evidence. Matching individual file hashes do not bind changed dependencies. No fabricated-run or failed-Stage1 allegation.
- Readiness: **BLOCKS** complete closure of the requirement above, limited to this recorded property/evidence gap.
- Corrective objective or verification need: Assemble an existing causal evidence chain where available; use a separately authorized verification session for unresolved current artifact/run requirements. No implementation is authorized by this report.
- Attribution and coordinator disposition: **retain**, with the qualifications above. D original; B independently re-read metadata; A-F04 merged here with its original Informational severity and four-vault limits preserved. [Full original](reviewers/D-coordinator-original.md); [cross](reviewers/D-coordinator-cross.md).

### A-F01 — FullSpread exact-output shortage can precede the specified EOA error

**Low · CODE_DEFECT · original-program/current-product coverage**. Confidence: high in cited control flow/assertions; execution unverified.

- Source: V3 UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:82–90 and OutMultiTarget.sol:36–44; H/P OutExecuteTarget.sol:94–106,153–165; full paths in A original.
- Intended requirement: R13.1/.2 / D9 named caller error.
- Observation and impact: Supported exact-output routes evaluate available-credit shortfall before the helper's bytecode guard. This changes the required error contract.
- Counterevidence and limits: Underfunded calls still revert atomically, sufficient-credit EOAs reach the guard, and historical evidence already discloses the order. This is not authorization bypass or principal loss. Wings differs.
- Readiness: **BLOCKS** complete closure of the requirement above, limited to this recorded property/evidence gap.
- Corrective objective or verification need: Align exact-error behavior or obtain a scoped acceptance of the diagnostic difference; preserve funding checks. No implementation is authorized by this report.
- Attribution and coordinator disposition: **retain**, with the qualifications above. A original; B and D corroboration; A cross retained narrowly. [Full original](reviewers/A-vaults-original.md); [cross](reviewers/A-vaults-cross.md).

### B-02 — Rocket can pool a skipped old-reserve allocation into the caller stake

**Low · CODE_DEFECT · original-program/current-product coverage**. Confidence: high in cited control flow/assertions; execution unverified.

- Source: contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol:446–459,500–515; InTarget.sol:71–80; OutTarget.sol:60–73.
- Intended requirement: D39/D42; R14.3/.19/.20 separate source budgets.
- Observation and impact: When the first booked allocation is below minimum it stays liquid; the second attempt recomputes aggregate excess without subtracting that skipped budget or bounding the attempt to caller credit.
- Counterevidence and limits: Normal sleeve/cap cases work and no extra caller shares or insolvency is established. It changes holder investment timing and can apply existing fees earlier, rather than demonstrating extraction.
- Readiness: **BLOCKS** complete closure of the requirement above, limited to this recorded property/evidence gap.
- Corrective objective or verification need: Preserve separate source allocations across a skipped first stake and substantiate each minimum/cap boundary on both public routes. No implementation is authorized by this report.
- Attribution and coordinator disposition: **retain**, with the qualifications above. B original; A/D source confirmation; B cross retained. [Full original](reviewers/B-credit-lending-original.md); [cross](reviewers/B-credit-lending-cross.md).

### A-F02 — Some Wings negatives accept an unrelated revert

**Low · TEST_DEFICIENCY · current Wings supplement**. Confidence: high in cited control flow/assertions; execution unverified.

- Source: Wings Security.t.sol:29–42 and Tokens.t.sol:53–91 under test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/.
- Intended requirement: R2.4; S2-ADD-009; precise security-property assertions.
- Observation and impact: Six bare expected reverts and callback success-only recording do not establish the named rejection cause.
- Counterevidence and limits: Real deployment, funded setup, rollback assertions and several other exact-error tests are useful. This is not absence of Wings security tests or a regression of custody REQ-03.
- Readiness: **BLOCKS** complete closure of the requirement above, limited to this recorded property/evidence gap.
- Corrective objective or verification need: Pin reachable intended failure data while retaining funded and rollback controls. No implementation is authorized by this report.
- Attribution and coordinator disposition: **retain**, with the qualifications above. A original; B/D reinspection. [Full original](reviewers/A-vaults-original.md); [cross](reviewers/A-vaults-cross.md).

### B-04 — EtherFi sleeve boundaries cannot be closed by Rocket-only evidence

**Low · TEST_DEFICIENCY · original-program/current-product coverage**. Confidence: high in cited mapping, moderate in bounded absence.

- Source: acceptance.json R14.4; RocketPoolRETHStandardExchange_APEX_R14.t.sol:159–244; EtherFi Core.t.sol:52–116 and adversarial tests:680–780.
- Intended requirement: R14.4 / D42 consumer-specific allocation boundaries.
- Observation and impact: The cited closure uses Rocket scenarios; the bounded EtherFi search did not locate equivalent required exact allocation/target-extreme controls.
- Counterevidence and limits: EtherFi default sleeve/pause/blacklist/reopening controls are real. Its capacity is binary; no artificial finite cap is required. Global absence confidence is bounded.
- Readiness: **BLOCKS** complete closure of the requirement above, limited to this recorded property/evidence gap.
- Corrective objective or verification need: Establish missing EtherFi-specific boundary evidence and correct attribution. No implementation is authorized by this report.
- Attribution and coordinator disposition: **retain**, with the qualifications above. B original; D bounded search and family distinction check. [Full original](reviewers/B-credit-lending-original.md); [cross](reviewers/B-credit-lending-cross.md).

### C-002 — Orbital historical cap-call requirement needs reconciliation

**Low · TEST_DEFICIENCY · original-program/current-product coverage**. Confidence: high in cited control flow/assertions; execution unverified.

- Source: Orbital Common.sol:749–757,852–870,963–977; ClaimLib.sol:450–459; Apex008.t.sol:223–272, full roots in C original.
- Intended requirement: R6.4 historical cap/error witness.
- Observation and impact: Earlier preview rejects an over-cap request before the operative unwrap under stable state. The named tests therefore do not establish the historic cap-call behavior or exact nested operative failure.
- Counterevidence and limits: Current source rejection is protective and no reachable missing-cap vulnerability was established. Ordinary successful exact-output and preview-Drain/outer-wrapper checks are valid within their scope.
- Readiness: **BLOCKS** complete closure of the requirement above, limited to this recorded property/evidence gap.
- Corrective objective or verification need: Reconcile the old acceptance with current reachable behavior; identify a relevant downstream-failure control rather than reintroducing an obsolete branch. No implementation is authorized by this report.
- Attribution and coordinator disposition: **retain**, with the qualifications above. C original narrowed by C cross from Medium to Low; D re-read the earlier guard trace. [Full original](reviewers/C-hooks-matrix-original.md); [cross](reviewers/C-hooks-matrix-cross.md).

### C-005 — D49 failure fixtures replace production router/SE responses

**Low · TEST_DEFICIENCY · original-program/current-product coverage**. Confidence: high in cited control flow/assertions; execution unverified.

- Source: Six *D49.t.sol suites; constProd StandardExchangeBufferPool_D49.t.sol:144–211; controlling open-item-5 PRD P3/§4.
- Intended requirement: D49 P3/§4; R2.6, R14.9/.20.
- Observation and impact: Tests mock real router handoff and SE preview/operative selectors where the accepted fixture rule requires real authorization state and SE dependency-side failures.
- Counterevidence and limits: Injected-error propagation, rollback and funded positive controls remain useful. This does not challenge allowed staticcall probes or establish swallowed production errors.
- Readiness: **BLOCKS** complete closure of the requirement above, limited to this recorded property/evidence gap.
- Corrective objective or verification need: Supply production-state/dependency witnesses for the required end-to-end boundary while preserving useful unit-boundary evidence. No implementation is authorized by this report.
- Attribution and coordinator disposition: **retain**, with the qualifications above. C original; B all-six pattern confirmation and D representative bodies/rule check. [Full original](reviewers/C-hooks-matrix-original.md); [cross](reviewers/C-hooks-matrix-cross.md).

### C-006 — Wings consumer conservation assertion compares a value to itself

**Low · TEST_DEFICIENCY · current Wings supplement**. Confidence: high in cited control flow/assertions; execution unverified.

- Source: test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultFamilyConsumers.t.sol:38–59.
- Intended requirement: S2-ADD-009; Wings consumer conservation / R10.3.
- Observation and impact: The opposing-token balance equality is tautological and cannot catch incorrect movement.
- Counterevidence and limits: Real funded joins/exits and other share-movement inequalities are useful. No wrong movement is established; fixing this one assertion does not close the matrix.
- Readiness: **BLOCKS** complete closure of the requirement above, limited to this recorded property/evidence gap.
- Corrective objective or verification need: Compare independently captured or derived expected balances and exact share settlement. No implementation is authorized by this report.
- Attribution and coordinator disposition: **retain**, with the qualifications above. C original; A/D reinspection; C cross retains distinct from A-F03. [Full original](reviewers/C-hooks-matrix-original.md); [cross](reviewers/C-hooks-matrix-cross.md).

### C-007 — Balancer-quad guard suite lacks a required unlock-context negative

**Low · TEST_DEFICIENCY · original-program/current-product coverage**. Confidence: high in cited mapping, moderate in bounded absence.

- Source: Balancer quad Adversarial.t.sol:60–67 and HooksTarget.sol:112–119; BeforeInitializeLib.sol:25–28; bounded search described in C original.
- Intended requirement: R10.1.
- Observation and impact: Direct unauthorized beforeSwap and valid swap controls exist; the required attacker-opened-unlock negative was not located.
- Counterevidence and limits: Source msg.sender comparison excludes that unauthorized caller as well. The original missing-guard allegation stays refuted. Absence claim is bounded, not repository-wide proof.
- Readiness: **BLOCKS** complete closure of the requirement above, limited to this recorded property/evidence gap.
- Corrective objective or verification need: Identify or separately verify the missing production-proxy context; no redundant production guard is indicated. No implementation is authorized by this report.
- Attribution and coordinator disposition: **retain**, with the qualifications above. C original; D bounded source/test check. [Full original](reviewers/C-hooks-matrix-original.md); [cross](reviewers/C-hooks-matrix-cross.md).

### D-F04 — Missing-registry-query regression mocks the manager

**Low · TEST_DEFICIENCY · original-program/current-product coverage**. Confidence: high in cited control flow/assertions; execution unverified.

- Source: test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/adversarial/Adversarial_TrustFlags.t.sol:55–65.
- Intended requirement: R2.6 and explicit IndexedEx production-first manager/registry rule.
- Observation and impact: vm.mockCallRevert replaces indexedexManager.isDisabled, so the test proves injected-boundary response rather than the stated genuine registry integration condition.
- Counterevidence and limits: The TestBase and exact injected error assertion are useful. Non-SUT failure injection is allowed elsewhere, but manager/registry mocking is explicitly barred for this required setup.
- Readiness: **BLOCKS** complete closure of the requirement above, limited to this recorded property/evidence gap.
- Corrective objective or verification need: Provide a production-valid integration witness or explicitly reconcile applicability; retain useful bounded fault-response evidence. No implementation is authorized by this report.
- Attribution and coordinator disposition: **retain**, with the qualifications above. D original; B independently confirms explicit skill rule and source. [Full original](reviewers/D-coordinator-original.md); [cross](reviewers/D-coordinator-cross.md).

### Informational original retained through consolidation

**A-F04**, Informational EVIDENCE_GAP, is merged into **D-F02** because both concern missing current source/artifact/run binding. A's four separate vault limitations and original severity remain preserved in [A original](reviewers/A-vaults-original.md#a-f04--named-stage-1-passes-do-not-bind-the-broader-vault-acceptance-to-this-snapshot) and [A cross](reviewers/A-vaults-cross.md). The merge is not a dismissal of an Informational finding or a new source vulnerability.

The twenty independent-original records plus D-X01's corrected cross-review finding, minus that one duplicate cause, yield **twenty consolidated causes**. C-002 is Low after source-based narrowing; no original was edited to hide the change.

## 5. Stage1 continuity

Accepted completion remains recorded. The review pauses **affected closure claims**, preserves their original REQ IDs and continues independent inspection; it neither repairs them nor requests launch approval again.

| Stage1 requirement | Current source inspection | Limitation / origin |
| --- | --- | --- |
| REQ-01 residual zero/hard joins | Hard joins and direct zero helper present | **STAGE1_OPEN D-F03**: supported inverse branch bypasses exclusive successful-preview predicate |
| REQ-02 CP preview/callers | Direct preview; four callers retain local zero residual, hard failures; no invented DETF book update | Source matches; current full caller-run binding incomplete |
| REQ-03 custody negatives/scanner | Intended ownership/reentry/minimality controls inspected; scanner includes both custody files | Named repairs present; wider scanner still nonclean by supplied note, not a new custody regression |
| REQ-04 seven behavior families | Repaired named/preview-matched rejection and meaningful debit/share/partial-book checks inspected | Broader matrix coverage distinct; C-001, no arbitrary full-matrix pass inferred |
| REQ-05 four outside trades | Four separate current production fixtures and funded controls inspected | Narrow property source matches; cannot substitute one variant or broad economic proof |
| REQ-06 receipt cap | Share-first payable cap; maxWithdraw derives from previewRedeem of that cap | Both-host named controls inspected; broader B-05 is not a cap regression |
| REQ-07 plain rate | Empty state uses live preview; no self quoteState/gas gate; supplied projected state remains distinct | Source matches; C-003/C-004 concern broader preserved obligations |
| REQ-08 source/evidence/size | Current source map and ERC4626 split source present | **STAGE1_OPEN D-F01/D-F02**: replacement inventory and execution binding incomplete |

No STAGE1_REGRESSION is asserted without historical source-bound evidence establishing a new break. Existing acceptance remains a decision, while this report records current requirement/evidence limitations.

## 6. Evidence sufficiency

| Supplied evidence | Reported outcome | Classification and precise limit |
| --- | --- | --- |
| Stage1 evidence note, named custody/cap/rate/residual/outside-trade/matrix controls | PASS as recorded by owner/session | INCOMPLETE_PROVENANCE for this exact content digest; useful named source/test mapping, not rejected acceptance |
| Current selector-size compare | 540 compared, zero missing, zero oversize; 52 ABI / 13 proxy-selector differences; 32 obsolete paths skipped; seven new units | INCOMPLETE_PROVENANCE; subset only and ABI-only limitation; D-F01 excludes replacements |
| ERC4626 split sizes | InFacet 24,009, Ext 14,815 versus 24,576 limit as reported | Useful supplied size values, not independently rebuilt runtimes or installed proxy-cut proof |
| September25 release | 34,909 tests, 3,053 suites, 33 campaigns, 540,672 calls, 571 artifacts, 16 recorded source fuzz properties | HISTORICAL_ONLY/PASS as reported; relevant source differs. Original broad narrative fuzz totals are not adopted |
| September25 matrix | 203 historical rows: 195 compatible/one incompatible/seven deprecated | HISTORICAL_ONLY/PASS as reported; seven later Pons wrappers and current broader domains require own reconciliation |
| Historical source/runtime manifest | Full hashes and metadata bundled after logs | Its own identityScope disclaims causal build/run freshness; hashes alone cannot retroactively establish executed bytes |
| Historical fork summaries | Earlier inventory and later six-test summary retained | HISTORICAL_ONLY; no new live state, RPC or immutable-instance repair |
| Wings consumer results | Selected real money paths reported passing, exhaustive domains explicitly pending | INCOMPLETE_PROVENANCE/PARTIAL for current broad closure; domain enumeration is not execution |
| Current whole release/campaign/configuration closure | No complete matching chain established | MISSING/UNKNOWN for unresolved obligations; Stage2 did not create execution evidence |

Historical metadata reports Forge 1.5.1, solc 0.8.35, Prague, optimizer 1, viaIR false. These are reported evidence settings, not a claim about a toolchain executed in this review.

Source MATCHES may coexist with missing runtime. CONTRADICTS may be a precise test assertion or document/source rule conflict rather than a production-money defect. The ledgers preserve these dimensions independently.

## 7. Historical audit, accepted residuals and policy questions

[AUDIT_ITEM_LEDGER](AUDIT_ITEM_LEDGER.md) contains exactly seven reported entries (001-M,001-M2,003,008,009,004B,005) and both retractions. Reported historical severities remain separate from current findings. Supplied historical reproductions support their scoped allegations; Morpho's separate old-source reproduction remains unverified where only the ERC4626 red case/analogous Morpho green was supplied. 001-M2 is instance scope, not an invented independent arithmetic defect. 005 governs concrete behaviors, not an artificial standalone exploit.

The withdrawn beforeSwap guard allegation stays refuted; C-007 is missing negative-context proof, not a revived guard vulnerability. Weighted dust was downgraded to Informational, not a universal certificate about every current residual state.

Accepted boundaries:
- D7/R4: immutable historical deployments are not changed by source fixes or replacement tests.
- D12: non-atomic **unbooked** contract-wallet/EIP-7702 credit provenance is the accepted UNSUPPORTED_USE residual. It does not authorize booked-inventory consumption, excess refund, EOA pretransfer or ignored maximums.
- D57: Slipstream Standard Exchange is DEPRECATED; compile-only preservation is not a missed functional rewrite.
- DETF_ALIGNMENT D60 removes further Balancer-hosted DETF functionality from this release. This is distinct from APEX D60 hook valuation.
- Wings O1/O3 intentionally govern unsold custody and first-depositor residual benefit; its O6 target-only/hookless-underlying rules stand.

Open policy/authority questions remain explicit: whether supported inverse proof is intended as an exception to OD-08; whether disclosed FullSpread diagnostic ordering is acceptable under the exact-error rule; how R6.4's historical cap-call requirement maps to current earlier rejection; and the admitted expanded configuration/route denominator. None is automatically waived or treated as harmless.

## 8. Cross-review reconciliation

All material proposed findings received a second source inspection or a bounded absence recheck. Corroboration remains limited to cited properties; reviewer agreement is not execution evidence or complete transitive audit.

- A/B/D corroborated Camelot/Rocket and diagnostic ordering with source/helper/caller checks.
- A/C independently corroborated D's replacement-directory omission and literal residual-rule conflict, preserving consumer-status counterevidence.
- B/C/D corroborated Wings assertion/campaign and adapter configuration issues. A/C retained deterministic tautology separately from campaign vacuity.
- B/D corroborated explicit production-fixture restrictions; injected-boundary tests retain their limited evidentiary value.
- C traced an earlier Orbital Drain guard; D re-read that trace. **C-002 narrowed Medium→Low and R6.4 becomes INDETERMINATE**, rather than a claim of a reachable missing-cap production defect.
- B's cooperative R14.7 staking mapping and C's AMM R14.7 label were wrong. Their underlying observations map elsewhere; corrected R14.7 is Aave PARTIAL/INDETERMINATE and D-X01 records the actual test gap.
- A-F04 merges into D-F02 with original Informational severity and scope retained.
- Ordinary CONTROL design labels are normalized to COMPATIBLE with CONTROL role; unresolved expanded domains use UNDETERMINED.

Unresolved interpretation is retained for D-F03, A-F01 and C-002. No vote, policy invention, repeated review wave or replacement reviewer was used to force agreement.

## 9. Acceptance assessment and separate next work

| Acceptance condition | Assessment | Evidence / unmet portion |
| --- | --- | --- |
| S2-AC-01 | SATISFIED | Recorded owner acceptance/launch in plan/PRD/Stage1 note; manifest required inputs. No reconfirmation. |
| S2-AC-02 | SATISFIED | Manifest observed concurrent substantive work, real session attribution, four originals. |
| S2-AC-03 | SATISFIED within recorded scope | 15,552-file starting/closing digest identical, IndexedEx/Crane identities; historical execution identity kept separate. |
| S2-AC-04 | SATISFIED | Criteria ledger 108 unique original IDs and exact group counts, retained scoped supersessions. |
| S2-AC-05 | PARTIAL | Ten separate supplements assessed; complete Wings proof/domain remains unresolved, not merely missing runtime. |
| S2-AC-06 | SATISFIED as separate conclusions | §3 and A records provide four independent source/test/evidence conclusions with limitations. |
| S2-AC-07 | PARTIAL | All 13 groups received substantive review; detailed payout/campaign/actor/route and capacity/projection breadth in ledger remains partial. |
| S2-AC-08 | SATISFIED | Audit-item ledger seven entries plus two retractions with historical/current distinction and claim limits. |
| S2-AC-09 | PARTIAL | 217 finite ordinary rows reconciled; expanded Wings/H/P domain unresolved. No source count promoted to executed pass. |
| S2-AC-10 | PARTIAL | Catalogue/setup/assertions and supplied release evidence reviewed; exhaustive per-family/action/configuration map remains incomplete. |
| S2-AC-11 | SATISFIED for reported findings | §4 full evidence fields by incorporation, all supported severities and counterevidence, narrow confidence/absence limits, exact next dependencies. |
| S2-AC-12 | SATISFIED | Frozen originals, one same-session combined-original cross wave, final reconciliation and unchanged original hashes. |
| S2-AC-13 | SATISFIED | §§5–7 and ledgers separate defects, test/evidence gaps, D12/deprecations and undecided authority. |
| S2-AC-14 | SATISFIED for disclosed partial package | Counts/identity/status align across manifest/report/ledgers; inherited original mistakes corrected without editing originals. |
| S2-AC-15 | SATISFIED under explicit owner amendment | No production/test/config edits or runtime execution. Read-only shell and three acceptance-note edits were explicitly authorized before snapshot; the earlier absolute shell prohibition is superseded for this run. |
| S2-AC-16 | SATISFIED | §10 owner checkpoint; no remediation PRD, verification or fixes automatically follow. |

Separately scoped next work, if selected by the owner:
- **Additional inspection:** finish the current payout/actor/campaign/document census, detailed family test maps and admitted expanded matrix denominator. Policy/routing applicability must be resolved before calling a Cartesian count exhaustive.
- **Verification:** assemble causal artifact/source/run evidence and perform only separately authorized build/test/fuzz/invariant/selector/size/fork work for concrete missing obligations. Historical immutable instances remain separate from replacements.
- **Corrective objectives:** consider all retained findings, including Low errors/assertions/fixture issues, in a later approved remediation PRD. This report supplies objectives, not an automatic implementation plan.
- **Owner rulings:** inverse retention, exact-error precedence, current Orbital cap requirement, and expanded domain scope as listed in §7. No new OD number or governance format is imposed.

## 10. Owner checkpoint and stop

1. Is the disclosed coverage sufficient for this review handoff, or which additional inspection should complete the partial slices?
2. Which evidence gaps should enter a separately authorized verification session?
3. Which supported source, test, tooling or documentation/evidence corrections should enter a remediation PRD?
4. Which unresolved policy questions above need an explicit ruling?

**Stop here.** This report does not authorize fixes, a new test run, another review wave, a remediation PRD, deployment or audit submission. Stage1 acceptance remains recorded and is not a pending question.
