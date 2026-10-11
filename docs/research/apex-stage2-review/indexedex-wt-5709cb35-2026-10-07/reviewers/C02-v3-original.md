# C02 - V3 FullSpread independent first-pass review

Date: 2026-10-07. Reviewer: C02, Sisyphus-Junior. Model identity supplied by the session: openai/gpt-6-astra. Session/task identifier was not supplied to this reviewer and is not invented.

Report state: **PARTIAL_REPORT**. Assigned rows are dispositioned below, but the exhaustive route/test obligations of R3.4/R3.5/R3.7 are not certified complete. The V3 portion of S2-ADD-005 has a supported assertion-quality limitation, marked `STAGE1_OPEN`; closure of that affected Stage-1 requirement is paused for owner/coordinator disposition. This is not a claim that its supplied run failed.

## Snapshot and boundaries

- Selected identity: IndexedEx HEAD `5709cb3507a9df72b11ec476d27b79ef88696c3a` **plus working-tree edits**, as described in `docs/research/apex-stage2-review/indexedex-wt-5709cb35-2026-10-07/REVIEW_MANIFEST.md:32-44,81,99`. All source observations below come from filesystem reads, not a clean-commit reconstruction.
- Dependency identity, supplied only: Crane `b35609951b4951a3c107e267e22844a50c4dc043` (manifest:42). No Crane contract body was audited. Imported arithmetic, pool, ERC-20 storage and lock primitives remain dependency assumptions.
- The manifest expressly lacks dirty-file hashes and an immutable dirty-tree identity (manifest:34,43-44,169-171). No hashes or source stability guarantees were manufactured. No source drift was established by these reads; that is not proof of immutability.
- Scope: V3 FullSpread only; R3.1-R3.7, V3's R10.5, and V3's S2-ADD-005. Shared IndexedEx helpers were inspected only as V3 consumers. No hookless, Pons-family or wings conclusion follows from this report.
- No shell, builds, tests, simulations, RPC, source/test/config edits, peer-review reads, or cross-review. Only this Markdown original was written.

## Citation key

All abbreviated file citations below expand to repository-relative paths in this table. A suffix such as `Common:394-400` is a file:line citation, not a symbol-only reference.

| Key | Path |
| --- | --- |
| APEX plan | `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md` |
| Stage2 | `docs/plans/APEX_STAGE2_REVIEW_PRD.md` |
| Readiness | `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` |
| Stage1 plan | `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.plan.md` |
| Stage1 evidence | `docs/reviews/apex-2026-09-17-second-audit-readiness/STAGE1_EVIDENCE.md` |
| Manifest | `docs/research/apex-stage2-review/indexedex-wt-5709cb35-2026-10-07/REVIEW_MANIFEST.md` |
| Family PRD | `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.md` |
| Family README | `contracts/vaults/standard/exchange/protocols/uniswap/README.md` |
| V3/ | `contracts/vaults/standard/exchange/protocols/uniswap/v3/` |
| Common | `V3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol` |
| InTarget / InBase / InDelegate | `V3/UniswapV3FullSpreadStandardExchangeVaultInTarget.sol`, `V3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol`, `V3/UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate.sol` |
| OutExecute / OutBase / OutDelegate | `V3/UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol`, `V3/UniswapV3FullSpreadStandardExchangeVaultOutBase.sol`, `V3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol` |
| InMulti / OutMulti | `V3/UniswapV3FullSpreadStandardExchangeVaultInMultiTarget.sol`, `V3/UniswapV3FullSpreadStandardExchangeVaultOutMultiTarget.sol` |
| InMultiQuery | `V3/UniswapV3FullSpreadStandardExchangeVaultInMultiQueryTarget.sol` |
| Liquid / Import / Package / Factory | `V3/UniswapV3FullSpreadStandardExchangeVaultLiquidReserveTarget.sol`, `V3/UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol`, `V3/UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol`, `V3/UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.sol` |
| TestBase | `V3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol` |
| CP | `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol` |
| Credit | `contracts/utils/LocalCreditLib.sol` |
| ReserveRepo | `contracts/vaults/basic/MultiAssetBasicVaultRepo.sol` |
| AtomicCaller | `contracts/test/stubs/AtomicPretransferCaller.sol` |
| Tests/ | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/` |
| FeeCompound / Reconcile / Parity / Multi / ImportTest | `Tests/release/v3/UniswapV3FullSpreadStandardExchangeVault_FeeCompound.t.sol`, `Tests/release/v3/UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile.t.sol`, `Tests/release/v3/UniswapV3FullSpreadStandardExchangeVault_PretransferParity.t.sol`, `Tests/release/v3/UniswapV3FullSpreadStandardExchangeVault_MultiJoinExit.t.sol`, `Tests/release/v3/UniswapV3FullSpreadStandardExchangeVault_Import.t.sol` |
| V3AdversarialBase | `Tests/adversarial/TestBase_UniswapV3FullSpreadStandardExchangeVault_Adversarial.sol` |
| AdversarialBehavior | `Tests/adversarial/StandardExchangeFullSpreadAdversarialBehavior.sol` |
| DeliveryBehavior / ReleaseBehavior | `Tests/remediation/StandardExchangeDeliveryBehavior.sol`, `Tests/remediation/StandardExchangeReleaseBehavior.sol` |
| DeliveryToken / MarketTrader / LockedCaller | `Tests/remediation/DeliveryTestToken.sol`, `Tests/remediation/StandardExchangeMarketTrader.sol`, `Tests/remediation/StandardExchangeLockedCaller.sol` |
| SwapLockCaller | `Tests/release/v3/harness/UniswapV3FullSpreadStandardExchangeVaultBoundPoolLockSeCaller.sol` |

## Authority disposition

1. APEX plan:477-483 supplies the seven original R3 IDs; :555 supplies R10.5. The checkbox marks are historical assertions, not this review's results.
2. Readiness:130-141,166-186 and Stage1 plan:29-40,85-95 supersede the old-source red-run requirement and prohibit reconstructing stored-total equality/greater-than scenarios. R3.1 remains in the denominator as `SUPERSEDED`. R3.3 is assessed only for its surviving current-accounting controls; its old stored-total subcases are superseded, not missing tests.
3. **D28 was read at APEX plan:118 before disposing R3.5.** Exact-in push requires sufficiency, credits the requested amount, accepts excess, and refunds nothing. Pull-delta equality remains required. D15/D17 at :105,107 control quote-used pulls and exact-out refunds. No finding here asks for excess-push rejection or sender attribution.
4. D12 at APEX plan:102 is an accepted integrator-risk residual. Unbooked resting credit is not protected by sender attribution. Booked inventory remains protected. No ownership mechanism is proposed.
5. Current family precedence is explicit in Family PRD:14-20. Older contradictory prose is documented below rather than used to override D28.

## Criterion ledger

Owner for every row: C02. Product for every row: **V3 FullSpread replacement**, except R3.1's historical reproduction obligation. `MATCHES` means source consistency within the stated inspected boundary, never an executed pass. Outcome records describe supplied execution evidence, not the inspection verdict.

| Criterion and requirement reference | Controlling authority / applicability | Review / inspection | Source and test evidence; confidence and limits | Execution / supplied outcome | Origin, findings, readiness |
| --- | --- | --- | --- | --- | --- |
| **R3.1**, APEX plan:477: preserved-family reproduction | Readiness OD-04/OD-07 :138-141,174-177; `SUPERSEDED`: no preserved-source red run required; replacement is S2-ADD-005 | `INSPECTED` / `NOT_ASSESSED` | Authority disposition only, high confidence. Preserved implementation and historical reproduction not audited. No claim that immutable deployments were repaired. | `NOT_REQUIRED` / `UNKNOWN` for the superseded rerun obligation | Original program; no finding; `DOES_NOT_BLOCK` current V3 closure by itself |
| **R3.2**, APEX plan:478: post-movement no-delivery EOA/contract rejection; unchanged books/entitlements | D9/D15 and OD-04; `APPLICABLE` | `PARTIAL` / `INDETERMINATE` | Delivery separation matches Common:851-873 and Credit:13-27. DeliveryBehavior:123-140 establishes deployed movement and precise EOA/contract errors in both directions; :95-115 checks books/custody/supply for `_reject`. The contract branch :135-140 does not repeat that complete snapshot. FeeCompound:61-67 asserts unchanged books across the outside trade. These controls are complementary, not one fully reconciled post-movement proof. Medium confidence; no code defect inferred. | `MISSING` / `UNKNOWN` for the complete row; Stage1's narrower outside-trade claim is separately `INCOMPLETE_PROVENANCE` / `PASS` | Original program; C02-E01; `BLOCKS` runtime closure and complete assertion reconciliation |
| **R3.3**, APEX plan:479: token/direction and rebalance-then-outside-trade coverage | OD-04 :139-141 and Stage1 plan:39; `APPLICABLE` to surviving controls; old stored-total subcases `SUPERSEDED` | `PARTIAL` / `INDETERMINATE` | DeliveryBehavior:117-140 covers two directions/token sides; ImportTest:84-122 covers imported-state directions. Reconcile:109-152 trades through the vault, not externally. DeliveryBehavior:208-214 trades then rebalances, not rebalance then another outside trade. That surviving sequence was not established within inspected tests; no repository-wide absence claim. | `MISSING` / `UNKNOWN` | Original program as amended; C02-E01; `BLOCKS` full row closure pending remaining sequence coverage/evidence, not reconstruction of obsolete cases |
| **R3.4**, APEX plan:480: all route and state controls | Family PRD:39-61 and D15/D28; `APPLICABLE`; V4 native wrapping is `NOT_APPLICABLE` to this product | `PARTIAL` / `INDETERMINATE` | Read single input/direct swap/share exit, multi join/exit, import, fees, no-position refund fixture and locked paths. InTarget:40-63; InMulti:26-30; OutExecute:39-63; OutDelegate:24-69,100-125; Import:81-175; AdversarialBehavior:340-425; Multi:275-340. Native SY implementation/context restoration and complete release/invariant coverage not inspected. | `MISSING` / `UNKNOWN` | Original program; C02-E01; `BLOCKS` exhaustive route/test closure; no unsupported variant inheritance |
| **R3.5**, APEX plan:481: measured pull, sufficient push, used-only pull, bounded refunds, internal SY and reuse | D15/D17/D28, APEX plan:105,107,118; `APPLICABLE` | `PARTIAL` / `CONTRADICTS` | Core credit rules match Common:851-919. OutExecute:76-94 removes the pull buffer; OutMulti:36-51 pulls quoted shares. Parity:18-49 checks mint exact-out pull/push and refund parity. AdversarialBehavior:348-425 checks bounded refunds/book retention/reuse. Exact-in excess tests do not bound shares to the request (C02-T02). Conditional underquote rejection has the wrong specified error (C02-C01). Common:907-913 narrows self-share credit, but full SY caller/context lifecycle is uninspected. High confidence in cited local comparisons; no quoter mismatch reachability demonstration. | `MISSING` / `UNKNOWN` | Original program; C02-C01/T02/D01/E01; `BLOCKS` exact error/test/evidence closure |
| **R3.6**, APEX plan:482: persisted local custody, not stored total minus deployed | Family PRD:16,40-47; `APPLICABLE` | `INSPECTED` / `MATCHES` | Common:394-400 writes all three balances, ReserveRepo:82-95 persists them; Common:851-872 uses only local balance minus booked balance for delivery. Common:313-359 reads deployed assets/fees for valuation separately. Operation syncs inspected in InBase:23-32,77-84,131-139,194-226; OutExecute:94 and :44; OutDelegate:50-51,68-69,123-125; OutMulti:94-120; Import:124-126; rebalance Common:661-715. Reconcile:140-171 supplies custody positives/negatives, not outside-trade proof. High confidence within V3 entries read. | `MISSING` / `UNKNOWN` for source-bound execution of the full row | Original program; C02-E01; `BLOCKS` runtime acceptance despite `INSPECTED` + `MATCHES`; not a code defect |
| **R3.7**, APEX plan:483: callback/lock and duplicate-credit protection | Family PRD:87-88; `APPLICABLE` | `PARTIAL` / `INDETERMINATE` | Public mutation entrypoints use `nonReentrant`; callbacks require bound pool (Common:133-160). AdversarialBehavior:304-319 records exact `IsLocked` and tests propagated rollback; DeliveryToken:29-39 actually calls back during transferFrom; `_reject` has state assertions. Multi:95-110,204-235 plus SwapLockCaller:234-305 cover real pool-locked call paths. LockedCaller:15-25,32-41 supplies the V3 flash route for shared cases. No Crane lock-body audit, and full refund-callback/SY composition not certified. | `MISSING` / `UNKNOWN` | Original program; C02-E01; `BLOCKS` full callback/runtime closure, not evidence of bypass |
| **R10.5**, APEX plan:555: retain protocol residual/dust; fee recipient only explicit fees | D6 at APEX plan:96 and D15/D17/D28; `APPLICABLE` for V3 | `INSPECTED` / `MATCHES` | OutDelegate:65-69 pays requested output and books surplus; :89-125 books exact-mint rounding remainder; OutExecute:91-94,120-132 restricts refunds to pushed unused input. Common:718-739 retains non-mintable excess, :661-715 syncs custody after rebalance; no caller payout in Liquid:75-79. AdversarialBehavior:340-389 checks book-preserving refunds; Parity:36 checks unused bounded credit. No fee-recipient residual diversion found in inspected V3 paths. Medium confidence; this is not a proof of every dust boundary or fee calculation. | `MISSING` / `UNKNOWN` | Original program; C02-E01; `BLOCKS` runtime acceptance, not a demonstrated residual loss |
| **S2-ADD-005 (V3 only)**: outside-trade test, Readiness REQ-05 :255-268; Stage2:206 | OD-04/OD-08, Readiness:140,185-186; `APPLICABLE` | `BLOCKED` / `CONTRADICTS` for full asserted-credit proof, while external-call/book-invariance subclaims match | FeeCompound:28-75 and TestBase:63-175 inspected through caller, deployment, pool trade, preview and execution. Post-deposit result only checks same-implementation preview parity and recipient shares; no independent credited-input/entitlement reconciliation. C02-T01. High confidence in missing assertions within this named function. | `INCOMPLETE_PROVENANCE` / `PASS` (supplied Stage1 narrative, not a rerun) | Supplemental, `STAGE1_OPEN`; C02-T01/E01; `BLOCKS` closure; pause affected conclusion for owner disposition under Stage2:211,301-308 |

## Outside-trade test: setup, route, preconditions and assertions

### What the test genuinely establishes on inspection

`FeeCompound:28-36` creates mintable external tokens, a real pool and external liquidity, then deploys the vault using its TestBase. `TestBase:70-109` calls component FactoryServices and the manager's package deployment; `Factory:23-43,113-132,171-193` loads named artifacts and routes the package through the registry; `Package:306-310` routes the instance through the registry. This is not a mocked vault or direct arithmetic harness. Runtime artifact freshness is a separate, unproven execution dependency.

The incumbent joins through `exchangeInManyToOne` (`FeeCompound:38-47,56-60`, `InMulti:19-30`). It reaches `_executeZapInDualDeposit`, share minting, and ordinary rebalance (`InBase:100-139`). The intended fixture thus has a sleeve and deployed liquidity, but the named test does not assert either positive precondition.

After saving both custody books and supply (`FeeCompound:61-63`), `_externalSwapExactIn` invokes **pool.swap**, not the vault (`TestBase:161-174`). The test contract funds/pays this swap through `TestBase:153-158`; it is distinct from the incumbent and later depositor. No vault sync is called in this helper. The test asserts both stored books and supply are unchanged (`FeeCompound:65-67`). This is meaningful outside-trade book-invariance coverage and must not be confused with the Reconcile supplement.

The later depositor is funded and uses a **false-flag pull** (`FeeCompound:53-55,68-72`). InTarget:51-54 measures delivery before entering the delegate. InDelegate:9-14 forwards to InBase:45-84; idle fee collection happens after input capture, pre-deposit reserves subtract the credited amount, and shares are minted before final rebalance. Preview goes through InMultiQuery:29-30 to InBase:34-42. The standard preview selector is explicitly declared in `V3/UniswapV3FullSpreadStandardExchangeVaultInMultiQueryFacet.sol:23-27`; exchangeIn/callbacks are declared in `V3/UniswapV3FullSpreadStandardExchangeVaultInFacet.sol:34-38`; Package:174-183,204-213 installs those facet declarations.

### What the named test does not establish

At FeeCompound:73-74, `minted == preview` and `recipient.balance == minted` do not independently show that the amount minted is the correct entitlement for the measured input. Both paths call Common:612-624 and CP:37-64. A shared pricing/book error can agree in preview and execution. The test does not assert input-token expenditure, post-deposit total-supply delta, incumbent entitlement conservation, positive deployed/free inventory, or actual pool-price/deployed-inventory movement. The direct real-pool call is strong setup evidence, but the missing precondition assertion leaves that aspect less regression-resistant.

The broader existing suite has stronger no-delivery controls: DeliveryBehavior:123-140 verifies deployed movement and EOA/contract errors; ImportTest:84-122 does so after import; Reconcile:155-187 checks a custody-state digest and funded success. Those are counterevidence to any claim that V3 has no protective tests. They do not change the assertions of this Stage-1 named function or turn the through-vault Reconcile trade into the required outside trade.

## Findings

All findings refer to the snapshot above, V3 only. Attribution: C02 independent original. Cross-review response: not performed. Coordinator disposition: pending. No financial exploit or fund-loss result was demonstrated.

### C02-T01 - Outside-trade credit assertion is correlated with the implementation

- **Class / severity / confidence:** `TEST_DEFICIENCY` / Medium / High.
- **Origin:** `STAGE1_OPEN`, Readiness REQ-05; linked S2-ADD-005 (V3), R3.2/R3.3/R3.4; audit context APEX-2026-001-M replacement proof.
- **Intended:** Readiness:260-266 and Stage2:217-228 require the outside trade and subsequent actual-funded credit to be substantively asserted, not inferred from a name or successful return.
- **Observed:** FeeCompound:50-75 pins book invariance, then uses the vault's own preview as the sole quantitative share oracle. InBase:34-42,59-63 and Common:612-624 show the shared pricing path. No independent funding-to-entitlement assertion is present in this function.
- **Impact:** False-positive security acceptance is possible for a shared preview/execution error. The test can verify parity without verifying its claim of no unearned credit. This is an assertion-quality defect, not a demonstrated V3 accounting defect.
- **Counterevidence:** Correctly separate pool call, unchanged-book assertions, genuinely funded pull, and existing EOA/contract negatives elsewhere. Those support parts of the obligation and prevent characterizing the whole suite as vacuous.
- **Readiness:** `BLOCKS` the complete V3 S2-ADD-005 assertion-proof claim. The Stage1 pass claim remains recorded as supplied `PASS`; no failing run is alleged. Per Stage2:211, affected closure is paused for owner/coordinator disposition, not silently repaired or renamed as a new unrelated discovery.
- **Corrective objective:** Independently reconcile the funded input, issued shares and pre-existing holder entitlement after the outside movement, and assert the position/movement preconditions. Then obtain separately authorized source-bound execution evidence. Do not add obsolete stored-total cases.

### C02-T02 - Excess-input tests do not assert the amount of credit granted

- **Class / severity / confidence:** `TEST_DEFICIENCY` / Low / High.
- **Origin:** Original-program assertion review; R3.5/D28 (not claimed to be a Stage1 regression).
- **Evidence:** AdversarialBehavior:228-244 and DeliveryBehavior:160-167 assert only positive minted shares and no remaining payer tokens after an excess push. The actual share quantity is not checked against requested-only credit, and the excess leg test similarly accepts any positive mint.
- **Intended:** APEX plan:118 requires exactly requested credit, not merely success/no refund. The current implementation at Common:855-862 and InMulti:26-30 appears to implement that rule correctly.
- **Impact:** These specifically named requested-only tests would not distinguish granting shares for all delivered input from granting shares only for requested input. No over-credit in current production is demonstrated.
- **Counterevidence:** D28 sufficiency and exact requested return are explicit in production; broader no-delivery/reuse tests exist. This finding is bounded to the listed excess-input assertions, not a claim that no stronger test exists anywhere.
- **Readiness:** `BLOCKS` credit-amount proof from these controls under R3.5. Severity is Low because the observed defect is in regression strength, not a proven transfer of booked assets.
- **Corrective objective:** Assert the correct requested-only share increment and final retained-book state using an independent expected result or controlled comparison, without restoring equality rejection.

### C02-C01 - Conditional quote-underestimation rejection differs from R3.5's specified family error

- **Class / severity / confidence:** `CODE_DEFECT` / Low / High for the static error mismatch; reachability on a supported unchanged-state real-pool quote is unestablished.
- **Origin:** Original-program conformity; R3.5, APEX plan:481.
- **Intended:** The criterion expressly requires `UniswapV3ExchangeOut_InsufficientInput()` if the swap needs more than quoted used input. There must be no quote buffer or extra caller pull.
- **Observed:** OutExecute:77-90 pulls `quotedIn`, then invokes `_swapExactOut` with `maxAmountIn`. If actual used exceeds provided input while remaining within max, `_requireDelivered` at Common:893-895 emits `TransferDeltaInsufficient`, not the specified family error. If actual used exceeds max, Common:522-525 emits `UniswapV3Exchange_InsufficientOutput`. The specified input error exists in OutBase:31 and is used for the initial quote/max check at OutExecute:78, not these post-swap conditions.
- **Impact:** Conditional error-contract mismatch, not a demonstrated underfunded success: either inspected branch reverts atomically. No theft, partial commitment, or reachable quoter discrepancy is claimed. Crane quoter/pool bodies were deliberately not audited.
- **Counterevidence:** Exact quotes can make this defensive branch unreachable in ordinary supported execution. Delivery safety is maintained by the revert; measured pull and max limits are present. That limits severity but does not erase the explicit local mismatch with R3.5.
- **Readiness:** `BLOCKS` literal R3.5 conformity closure unless the required error is aligned or the owner explicitly resolves that conditional requirement. Does not by itself establish a runtime security failure.
- **Corrective objective:** Resolve the specified conditional rejection behavior and provide a source-bound control if reachable. Do not add a pull buffer or weaken delivery sufficiency.

### C02-D01 - Current family guidance still contains superseded exact-in equality language

- **Class / severity / confidence:** `DOCUMENTATION_GAP` / Low / High.
- **Origin:** Original-program D28 continuity; linked R3.5 (documentation dependency, not a new R13 audit).
- **Evidence:** Family README:32 correctly accepts excess, but :38 says differing declared amount reverts. Family PRD:14,47,63 correctly applies D28, while :58 still requests excess rejection and :113,146 still state equality.
- **Intended:** APEX plan:118 and Family PRD:14 govern; sufficiency replaces exact-in push equality, not pull-delta equality.
- **Impact:** Contradictory integration/test instructions can recreate obsolete assertions. Production Common:855-872 follows D28. This is not an unresolved owner-policy conflict and is not reported as `DECISION_NEEDED`.
- **Counterevidence:** Prominent amendment and several correct paragraphs already establish precedence.
- **Readiness:** `DOES_NOT_BLOCK` the narrow source-accounting conclusion once precedence is applied; unresolved documentation consistency should be carried to the coordinator's documentation lane. It does not justify closing execution evidence.
- **Corrective objective:** Reconcile the remaining active equality sentences with D28 while retaining historical policy only when explicitly labeled historical.

### C02-E01 - Supplied V3 execution narrative cannot be bound to the dirty review snapshot

- **Class / severity / confidence:** `EVIDENCE_GAP` / Medium / High.
- **Origin:** Stage2 evidence assessment, not a claim of reopened/failed Stage1 execution; linked all applicable runtime rows, especially S2-ADD-005.
- **Evidence:** Stage1 evidence:4 explicitly says the note is not a release identity; :28 describes only a command pattern; :34 reports the outside-trade tests passed. Manifest:34,43-44 acknowledges no dirty-file hashes/immutability. The dirty V3 test is specifically listed at Manifest:81.
- **Missing binding:** Full selected invocation, dependency/toolchain identity for that run, immutable source/test/artifact association, and inspectable per-test result details tied to that association. Factory:28,40,129,178 loads artifact bytecode, so source reading alone does not establish which implementation bytecode the supplied run deployed.
- **Impact:** Cannot promote the narrative to `SUPPLIED_SOURCE_BOUND`, or inherit historical aggregate counts as current acceptance. No build/test failure is inferred.
- **Counterevidence:** Owner accepted Stage1 (Manifest:9-24); the note names the correct V3 test/root and claims success. Therefore classify that claim `INCOMPLETE_PROVENANCE` / `PASS`, **not** `MISSING`, `FAIL`, or a fresh run. Broader row-specific current runtime artifacts were not supplied/established in this lane and remain `MISSING` / `UNKNOWN`.
- **Readiness:** `BLOCKS` current runtime closure, including rows with source `MATCHES`. This blocker needs evidence, not automatically code changes; the owner-accepted launch gate is not rescinded by this reviewer.
- **Verification need:** Supply a matching immutable dirty-source/test/dependency/artifact record and complete selected execution result, or commission separate verification. No such execution is authorized here.

## Catalog and dependency limits

- Relevant inspected categories: I1-I3 (delivery/short/reuse), E6 (refund ownership), L1/L3 (outside pool movement), C1 and H (reentrancy/locked payout), F5 (permissionless rebalance), A0 (first-mint residual handling as a supporting read), and J (outside-test route declaration/package linkage).
- M1/M2 arbitrary user target/calldata and O1/O2 Permit2 deposit paths are not introduced by the V3 entries read; the V3 adversarial suite explicitly defers these and distinguishes share permit at `Tests/adversarial/UniswapV3FullSpreadStandardExchangeVault_Adversarial.t.sol:4-5`. This report does not close the uninspected share-permit suite. NFT-import ownership/all approval controls were not exhaustively reviewed.
- D12 resting unbooked input remains accepted integrator risk. Neither catalog K wording nor old FullSpread prose overrides it. FoT/rebasing underlyings remain forbidden under `docs/agent/INDEXEDEX_AGENT_LAW.md:89-101`.
- Arithmetic-library correctness, pool lock behavior and callback payment semantics are assessed only at IndexedEx call sites. No imported Crane implementation was opened. No assertion of runtime selector installation, artifact freshness, campaign adequacy or exhaustive cross-interface coverage is made.

## Read inventory and explicit omissions

### Actually read in full

- `CLAUDE.md`; Stage2; Manifest; Stage1 plan; Stage1 evidence; Family README.
- Common; InTarget; InBase; InDelegate; OutExecute; OutBase; OutDelegate; InMulti; OutMulti; InMultiQuery; Liquid; Import; Package; Factory; TestBase; CP; Credit; ReserveRepo; AtomicCaller.
- `V3/UniswapV3FullSpreadStandardExchangeVaultInQueryTarget.sol` (read, but transition-math audit not completed); `V3/UniswapV3FullSpreadStandardExchangeVaultInFacet.sol`; `V3/UniswapV3FullSpreadStandardExchangeVaultInMultiQueryFacet.sol`.
- FeeCompound; Reconcile; Parity; SwapLockCaller; V3AdversarialBase; `Tests/adversarial/UniswapV3FullSpreadStandardExchangeVault_Adversarial.t.sol`; DeliveryToken; LockedCaller; MarketTrader (V3 portion assessed only).

### Actually read as bounded excerpts / search results

- APEX plan:90-123,471-486 and targeted R3/R10.5/D28 search hits (including :555).
- Readiness:125-319; Family PRD:1-155.
- `docs/agent/INDEXEDEX_AGENT_LAW.md:89-115` plus targeted token/pretransfer search hits.
- `.claude/skills/indexedex-testing/SKILL.md:1-100`; `.claude/skills/indexedex-adversarial-testing/SKILL.md:1-190` (guidance only, no workflow execution).
- Multi:1-350; ImportTest:1-205; AdversarialBehavior:85-428 plus function-index search; DeliveryBehavior:1-245; ReleaseBehavior:1-32 (inheritance and fixture context only).
- File/function discovery only for other `Tests/release/v3/*.sol` and V3 source files; those hits are not body inspection. A targeted inherited-helper search also returned function declarations in `Tests/remediation/StandardExchangePreservedBehavior.sol`; its body was not opened or used to substantiate replacement correctness.

### Not inspected / not certified

- Remaining portions of the excerpted files above, especially full Native SY/release behavior and remaining adversarial pull/surface cases.
- `V3/UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol`, `V3/UniswapV3FullSpreadStandardExchangeVaultOutMultiQueryTarget.sol`, `V3/UniswapV3FullSpreadStandardExchangeVaultRepo.sol`, `V3/UniswapV3FullSpreadStandardExchangeVaultPoolAwareRepo.sol`, `V3/UniswapV3FullSpreadStandardExchangeVaultFactoryAwareRepo.sol`, `V3/IUniswapV3FullSpreadStandardExchangeVaultDFPkg.sol`, remaining facet wrappers/selector declarations, and the complete inherited manager/registry/shared-vault infrastructure. The Package and outside-test selector path reads do not imply an audit of all these dependencies.
- `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol` and `Tests/release/sy/UniswapV3FullSpreadStandardExchangeVault_NativeSY.t.sol`; full context restoration and external-SY dispatch remain a seam for additional inspection.
- V3 Routes, Previews, FullRangeBook, Decimals, deployment/IFacet test bodies; V3 invariant handler/campaign and F6 diagnostic bodies; remaining delivery/release behavior bodies and other remediation suites. Discovery is not proof of absence or completeness.
- Historical audit PDF, original APEX PRD body, historical execution logs/acceptance JSON, current selector-size JSON, artifact JSON/bytecode, full source-map/hash manifests, historical preserved V3 implementation. No historical aggregate result is adopted.
- All Crane bodies, other V3 consumers outside this assignment, V4 products, wings, all peer originals, all cross-review artifacts.

## Handoff

The inspected V3 implementation separates local delivery credit from live deployed/fee valuation, and the named outside-trade test genuinely avoids a vault trade. Readiness nevertheless remains blocked by C02-T01/C02-T02/C02-C01 and evidence/coverage limits. Preserve this original, request owner/coordinator disposition of the `STAGE1_OPEN` assertion limitation, and keep subsequent verification or remediation separately authorized. This report authorizes neither and does not start cross-review.
