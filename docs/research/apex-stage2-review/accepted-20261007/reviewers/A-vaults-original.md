# A-vaults — independent original

Reviewer: native collaboration assignment `/root/vaults` (A-vaults), 2026-10-07. First pass; no peer originals, cross-reviews, or previous Stage-2 review outputs were read. No builds, tests, simulations, RPC, deployment, test authoring, or production/configuration edits occurred. Read-only shell inspection and this assigned report write used the owner's explicit authorization. Stage 1 is accepted and Stage 2 is authorized; neither is pending.

Snapshot: IndexedEx `5709cb3507a9df72b11ec476d27b79ef88696c3a` plus manifest dirty tree; Crane `b35609951b4951a3c107e267e22844a50c4dc043`; supplied working-tree SHA-256 `379d2c49ead26ad701503c419ca486ddcd0ae9158e2d879f9f0720129c721439`. No source changes were observed during inspection. The coordinator owns the closing identity check. Conclusions are source inspection, not runtime certification.

## Scope and result

C02–C05 were separately inspected: V3 FullSpread; V4 hookless FullSpread; V4 Pons-family FullSpread; and upper/lower wings. Primary rows are R3.1–R3.7 and S2-ADD-005/009/010. R13/R14 seams were inspected where used by these vaults. Current owner decisions OD-04/05/08 supersede the obsolete demand to reconstruct stored-total-minus-deployed witnesses on replacements. The wings O1–O7/A3 rules govern wings, including first-depositor residual benefit, target-only routes, oracle sleeve, one-unit floor and terminal release.

The inspected input-credit code uses local custody and does not authorize input by subtracting live deployed assets from historical total backing. Exact-output refunds are bounded by credited input on the inspected supported routes. The four required outside-trade tests exist on distinct production fixtures. These are positive findings about source consistency, not a current-source passing run.

Supported findings: one Low error-contract inconsistency, one Low negative-test weakness, one Medium invariant-test weakness, and one Informational evidence gap. No principal-loss defect was established in this inspection. No issue is claimed to overturn Stage-1 owner acceptance. The error-ordering issue predates Stage 1 and is documented in historical evidence; the test weaknesses concern the wider wings acceptance surface reopened by Stage 2.

## Citation aliases

All paths are repository-relative. An alias followed by a filename and line identifies that exact file, not every file in its directory.

| Alias | Exact root/prefix |
| --- | --- |
| V3 | `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVault` |
| H | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVault` |
| P | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHook` |
| W | `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVault` |
| TV3 | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVault` |
| TH | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/` |
| TP | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/` |
| TW | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVault` |
| TB | `contracts/test/bases/` |
| RB | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/remediation/` |
| AP | `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md` |
| RP | `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` |
| WP | `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md` |
| FP | `docs/plans/UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md` |

## Findings

### A-F01 — Underfunded EOA exact-output calls can fail before the specified caller guard

- Class/origin: `CODE_DEFECT`; original-program error-contract discrepancy, already described in `docs/audits/apex-2026-09-17-evidence.md:159`. Not a newly introduced `STAGE1_REGRESSION` and not D12 `UNSUPPORTED_USE`.
- Severity/confidence: **Low**, high confidence in control-flow discrepancy; no runtime execution in this review.
- Affected snapshot/consumers: snapshot above; V3, H and P public exact-output consumers. V3 direct token swap and dual exit are explicit witnesses; H/P direct token swap and exact-share mint carry the same ordering.
- Intended behavior: AP D9 at :99, R13.1 :577 and R13.2 :578 require a caller without bytecode to receive `EOAPretransferNotAllowed()` on supported public pretransfer entries. Funding shortfall for integrating contracts remains `TransferDeltaInsufficient`.
- Observed behavior: V3 `OutExecuteTarget.sol:82–90` computes capped pretransfer credit and rejects `quotedIn > credit` before `_secureTokenTransfer`; V3 `OutMultiTarget.sol:36–44` does likewise for shares. V3 `Common.sol:897–913` confirms the budget helper has no guard and the later secure-delivery helper does. H/P `OutExecuteTarget.sol:94–106` and H `OutExecuteTarget.sol:158–165` likewise reject credit shortfall before the guarded helper. Both V4 `Common.sol:901–921,941–949` use the same separation.
- Impact: externally observable error-contract inconsistency and misleading guard-coverage inference, not authorization bypass. No accepted underfunded call or lost funds is asserted.
- Supporting tests: `RB/StandardExchangeDeliveryBehavior.sol:125–141` checks the exact EOA error on exact-input deposits, while :232–252 checks direct exact-output as the test contract. TH `Adversarial.t.sol:22–26` and `PretransferCallerLifecycle.t.sol:13–60` likewise focus on exact-input. They do not establish the same error on underfunded exact-output EOAs.
- Counterevidence/competing interpretation: sufficient-credit EOAs still reach the bytecode guard; underfunded EOAs revert atomically earlier. Historical evidence explicitly disclosed this ordering. That disclosure is not an identified owner amendment waiving D9/R13's exact error, but the coordinator should retain it when assessing whether this is an accepted diagnostic difference rather than a repair requirement. Wings `Money.sol:245–249` guards inside `pretransferBudget` and does not share this specific ordering.
- Links: R13.1/R13.2, supporting R3.2/R3.4/R3.5, APEX-2026-005. No new allegation of APEX-2026-001-M principal leakage.
- Readiness: `BLOCKS` only an unqualified exact-error conformance claim; does not establish a principal-safety blocker.
- Corrective objective: align the guard/error contract or record an explicit scoped acceptance, and cover the affected exact-output routes with exact errors. Do not weaken delivery checks.
- Attribution/cross/coordinator: A-vaults original; cross-review pending global freeze; coordinator disposition pending.

### A-F02 — Wings negative tests accept unrelated failures

- Class/origin: `TEST_DEFICIENCY`; supplemental wings standard under S2-ADD-009, not the Stage-1 four outside-trade test implementation.
- Severity/confidence: **Low**, high source confidence.
- Snapshot/scope: snapshot above; `TW Security.t.sol:29–42` and `TW Tokens.t.sol:53–91`.
- Intended behavior: Stage-2 PRD §5 requires inspection of setup, call paths and assertions; current RP OD-07 requires production-route security assertions, not names or broad reverts. WP C2/C5/C6 and security/verification sections require precise delivery, rollback and reentrancy proofs. AP R2.4 is the original exact-error test standard relevant to the coordinator's lane.
- Observed: six bare `vm.expectRevert()` sites exist in the bounded `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/` search: Security :39; Tokens :55,63,70,73,89. They cover ownership, inbound/outbound FoT rejection, paused/blacklisted delivery and negative-balance behavior. Tokens :79–84 records callback attempted/succeeded booleans but discards nested revert data, allowing an unrelated callback error to satisfy the negative. For example, the funded supply/custody rollback assertions prove atomicity but do not prove the named delivery or backing guard was reached.
- Impact: false-positive regression protection if a route becomes unavailable or a preceding guard regresses; no production failure or successful attack is established.
- Counterevidence: the fixtures deploy real vault/registry/manager code and a non-SUT hostile token; several balance and supply assertions are meaningful. `TW Money.t.sol:88–95,157–160` pins pretransfer errors; `TW Security.t.sol:45–66` pins slippage/deadline errors. Therefore this is a bounded deficiency, not absence of wings security testing.
- Links: S2-ADD-009, R3.7 extension to wings, R2.4 seam, catalogs C/E/H/I/K/L. Stage-1 origin: broader new-vault review, no claimed regression of RP REQ-03's separate custody fixes.
- Readiness: `BLOCKS` claiming these negatives establish their named failure causes; does not itself block all source consistency conclusions.
- Corrective objective: establish reachable named preconditions, retain and assert exact failure data, and keep rollback assertions. No tests were authored here.
- Attribution/cross/coordinator: A-vaults original; cross-review pending global freeze; coordinator disposition pending.

### A-F03 — Wings invariant campaign can pass without successful money or market operations

- Class/origin: `TEST_DEFICIENCY`; supplemental wings stateful acceptance.
- Severity/confidence: **Medium**, high source confidence; not a claim that the supplied campaign actually had zero successes.
- Snapshot/scope: snapshot above; `TW Invariant.t.sol:32–51,58–96`.
- Intended behavior: AP D4 :95 requires stateful campaigns with success counters. WP O2/O7 :16,22 and §14 :389 require positive-value/lifecycle proof across trading and sleeve depletion; blanket rejection is not sufficient coverage.
- Observed: `trade`, `deposit`, `redeem`, and `rebalance` catch every failure and discard it. Only deposit/withdrawal success counters exist and neither is asserted. The setup's initial `handler.deposit(1e9)` also calls the catch-all handler. If initial and later deposits reject, supply remains zero and the conditional positive-value assertion is bypassed; zero local balances and unchanged funded/paid balances satisfy the remaining invariant. There are no successful trade or rebalance counters. This follows directly from handler/test control flow, without hypothesizing a production defect.
- Impact: the invariant suite cannot by itself establish exercised lifecycle coverage or distinguish universal reversion from a healthy positive-value campaign.
- Counterevidence: deterministic `TW Money.t.sol`, `TW Rebalance.t.sol:34–96`, and transition tests execute funded operations and are useful separate evidence. The invariant asserts real pool positions and holder cash conservation when state transitions occur. These controls do not impose per-campaign liveness or prove the required success distribution.
- Links: S2-ADD-009, supporting R3.7 and coordinator R11 campaign claims, catalogs A/C/E/H/K/N. No Stage-1 source regression is asserted.
- Readiness: `BLOCKS` treating this campaign as completion of the required successful stateful coverage; runtime logs alone cannot repair a test that does not enforce its claimed coverage across future runs.
- Corrective objective: require successful setup, record/classify rejected operations and successful market/maintenance calls, and assert meaningful coverage of the intended funded transitions alongside safety invariants.
- Attribution/cross/coordinator: A-vaults original; cross-review pending global freeze; coordinator disposition pending.

### A-F04 — Named Stage-1 passes do not bind the broader vault acceptance to this snapshot

- Class/origin: `EVIDENCE_GAP`; current completion evidence, with historical records retained. Owner acceptance is established.
- Severity/confidence: **Informational**, high confidence in the scoped evidence limitation.
- Snapshot/scope: all four vault variants above. `docs/reviews/apex-2026-09-17-second-audit-readiness/STAGE1_EVIDENCE.md` explicitly calls its dirty `5709cb35` tree “not a release identity,” lists named passes and gives source roots; it does not bind each executed artifact to this content digest. `selector-size-compare-stage1-current.json:1–16` contains aggregate comparison fields and artifact paths, not fresh execution of the current review snapshot.
- Requirement: S2-REQ-09 and RP REQ-08 distinguish a current-source claim from historical/insufficient-provenance evidence. A new review digest cannot retroactively identify bytes executed by an earlier run.
- Observed/missing: no source-bound runtime result for the full R3 acceptance/variant matrix was established from the supplied Stage-1 note. It is stronger than no evidence: four specific outside-trade passes are claimed and the current split is named. Nevertheless, the historical 34,909/0 count and removed unsegmented V4 paths are not tests of both present packages or wings.
- Impact: closure/provenance limitation, not a source defect, no inference that the named runs failed or were fabricated.
- Counterevidence: present test bodies and real deployment fixtures support source-level relevance; the source map and non-oversize compare are useful supplied evidence. They do not substitute for build/artifact/source/command/run linkage.
- Links: S2-ADD-005, S2-ADD-010, R3.2–R3.7, coordinator S2-ADD-008 and R12. Stage-1 relationship: acceptance retained; evidence sufficiency assessed independently, not a request to re-approve Stage 1.
- Readiness: `BLOCKS` current-snapshot runtime closure of the affected criteria. Inspection may complete with this evidence gap.
- Verification need: separately authorized source-bound validation or a complete existing evidence chain; no new run is requested or performed by this inspection.
- Attribution/cross/coordinator: A-vaults original; cross-review pending global freeze; coordinator disposition pending.

## Criterion records

Common record fields below apply separately to every row: owner = A-vaults `/root/vaults`; snapshot = identity above; confidence = high for cited control flow and test assertions, moderate for breadth of composed economic behavior; no new runtime execution. `INSPECTED` describes requirement assessment, not every line of every transitive library being audited. Tests are assessed as written, not passed. No row inherits another variant's runtime result.

### R3.1

- Requirement: AP :477, historical preserved-family stale reserve reproduction.
- Authority/applicability: `SUPERSEDED` for retaining/reconstructing obsolete source, RP OD-04 :130–140 and OD-08 :185; replacement is S2-ADD-005. Historical audit-claim proof is the coordinator's audit ledger, not a new green criterion.
- Product/surface: current V3/H/P local books and wings independent book; old stored-total model is not their delivery denominator.
- Review/inspection: `INSPECTED` / `MATCHES` current disposition. Evidence: V3 `Common.sol:852–863`; H/P `Common.sol:901–912`; W `Money.sol:80–90`; RP :258–265.
- Execution: `NOT_REQUIRED` / `UNKNOWN` for the superseded new red-run demand; historical supplied demonstrations are `HISTORICAL_ONLY` and not independently reopened here.
- Origin/residual: original-program, superseded by owner; immutable historical exposure remains outside source remediation, D12 staged-credit residual unaffected.
- Findings/readiness: A-F04 relates to replacement evidence; `DOES_NOT_BLOCK` on obsolete-source reconstruction. No reinstatement of the removed old-source gate.

### R3.2

- Requirement: AP :478 zero-funded contract and EOA controls after price movement, no claims/refunds/reusable credit, unchanged local baseline.
- Authority/applicability: `APPLICABLE`, D9/D12/D15/D28 plus RP OD-04/08; separately assess V3/H/P. Wings follows its supplement.
- Product/surface: secure delivery and reserve synchronization.
- Review/inspection: `INSPECTED` / `MATCHES` for local-custody and zero-funded exact-input rejection. Evidence: V3 `Common.sol:852–873,394–400`; RB `StandardExchangeDeliveryBehavior.sol:95–141` captures supply, balances, self shares and books and checks both EOA/contract failures after an asserted deployed-inventory move. H/P `AttributionAndBooking.t.sol` separately assert no pretransfer credit after external swaps and no reuse; H/P `Common.sol:901–921,514–524` exclude deployed inventory and synchronize only local faces. Exact-output guard ordering is the separately bounded A-F01/R13 seam, not a finding that exact-input EOA guard is absent.
- Execution: `INCOMPLETE_PROVENANCE` / `PARTIAL` from named Stage-1 outside-trade passes; older V3/V4 full counts are `HISTORICAL_ONLY`.
- Origin/residual: original-program; source-agnostic unbooked transfers remain D12 accepted risk, not booked backing.
- Findings/readiness: A-F04; A-F01 for broader exact-output guard claims. `BLOCKS` runtime closure pending source-bound results.

### R3.3

- Requirement: AP :479 both sides/directions, old clamp/equality/excess conditions, repeat movement after rebalance.
- Authority/applicability: `APPLICABLE` for directions and custody behavior; old `deployed == storedTotal`/`>` and clamp clauses are explicitly `SUPERSEDED` by RP OD-04 :139 and REQ-05 :261. Do not recreate artificial stored-total states.
- Product/surface: V3/H/P current local books; external movement and maintenance.
- Review/inspection: `INSPECTED` / `INDETERMINATE` for the full retained test denominator. RB `StandardExchangeDeliveryBehavior.sol:125–141,208–214,288–292` covers both directions/fuzz and a trade then rebalance, but the :208 test itself does not trade again after rebalance. TH/TP `GuardClosure.t.sol:28–33` assert real before/after pool price movement; shared G5 histories and separate attribution tests broaden support. No exact current-source test-to-control reconciliation for every repeat-trade sequence was established here. This is a bounded coverage uncertainty, not an invented code failure or obsolete equality requirement.
- Execution: `INCOMPLETE_PROVENANCE` / `PARTIAL` for Stage-1; broader campaigns not current-source-bound.
- Origin/residual: original-program under current accounting; no accepted residual waives repeat-movement assurance.
- Findings/readiness: A-F04; `BLOCKS` unqualified full runtime closure; direction coverage exists as source.

### R3.4

- Requirement: AP :480 routes/refunds, empty controls, fees, liquidity/import and native wrapping.
- Authority/applicability: `APPLICABLE` within each current family's supported routes; FP §2 F0–F5 and current V4 PRD D18/D19 preserve scoped `InvalidRoute` for unsupported inverses. WP O6 forbids importing FullSpread direct/multi/native routes into wings.
- Product/surface: V3 in/multi/out, H/P in/multi/out/import/native; wings assessed separately below.
- Review/inspection: `INSPECTED` / `MATCHES` on inspected supported-route safeguards. RB `StandardExchangeDeliveryBehavior.sol:216–279,302–430` covers missing second leg, direct swap, exact-output refund, share reuse/booked shares, blocked contexts and no-position control. TH/TP `NativePositionImportFunding.t.sol` bind each family to real import fixtures; `TB TestBase_UniswapV4FullSpreadNativeImport.sol:50–73,135–153` compares donated/no-donation credit, checks rollback/NFT ownership, booked WETH and zero raw ETH. `TB TestBase_UniswapV4FullSpreadG3RouteFunding.sol:188–238,511–569` exercises exact/fat/short funding and both local-leg shortages. H/P fixture distinction is retained.
- Execution: `INCOMPLETE_PROVENANCE` / `PARTIAL`; no current full route/import/native run established.
- Origin/residual: original-program with current route-law supersession; D12 excess remains outside per-call refund.
- Findings/readiness: A-F01/A-F04; `BLOCKS` full closure only to extent error-contract and runtime requirements remain.

### R3.5

- Requirement: AP :481 funded pull/push, used-only exact-output pull, capped push refund, internal SY amount-only single burn, repeat protection.
- Authority/applicability: `APPLICABLE`, D15/D17/D24/D28 and current FP route domains.
- Product/surface: V3 `OutExecuteTarget.sol:71–101`, `OutMultiTarget.sol:36–56,85–100`, `Common.sol:907–920`; H/P `OutExecuteTarget.sol:94–116,153–180`, `Common.sol:951–968`; common native SY.
- Review/inspection: `INSPECTED` / `MATCHES` principal/refund control in these paths. Quoted used is pulled in false mode; push budget limits refund; V3/H/P self-redemption checks requested shares, not the whole self balance. `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:34–65` preserves payer for normal calls and opens/closes internal context for self-call. G3 budget matrix :188–238 explicitly checks exact supply burn, recipient payout, retained over-cap shares and allowances; no refund of booked self-share seed at :511–527. V3 route tests :143–157,242–277,329–357 give funded/replay/refund controls.
- Execution: `INCOMPLETE_PROVENANCE` / `PARTIAL`; no current broad source-bound pass. Quote/execution equality across all numeric domains is not proved by reading the delivery helper.
- Origin/residual: original-program; accepted D12 staged-credit and explicitly permitted native SY holder path retained.
- Findings/readiness: A-F01 diagnostic seam and A-F04; `BLOCKS` full runtime closure. No principal-refund leak established.

### R3.6

- Requirement: AP :482 local reserve semantics, never stored total minus live deployed for authorization, funded controls.
- Authority/applicability: `APPLICABLE`, unchanged central invariant under OD-04/08 and FP local `R` versus whole-book `B` distinction.
- Product/surface: all three FullSpread variants; separate wings C1.
- Review/inspection: `INSPECTED` / `MATCHES`. V3 `Common.sol:394–400,852–873`; H/P `Common.sol:514–524,901–921` record ERC20 custody, separately derive pricing backing, and never subtract deployed units in delivery. TH/TP `_assertBooked` checks both underlying faces and self shares; `AttributionAndBooking.t.sol` funded pull/push comparisons and no-credit reuse checks provide positive controls. The Stage-1 named external-trade bodies are traced below.
- Execution: `INCOMPLETE_PROVENANCE` / `PARTIAL` for four named Stage-1 claims; source consistency is distinct.
- Origin/residual: original-program, D12 unbooked anonymous transfers; FullSpread end-operation excess becomes backing.
- Findings/readiness: A-F04; `BLOCKS` current runtime completion, no inspected accounting contradiction.

### R3.7

- Requirement: AP :483 supported callback/lock contexts; no repeated credit/spend through reentry.
- Authority/applicability: `APPLICABLE`, family-specific manager/pool contexts and catalogue C/H/I.
- Product/surface: V3 pool callbacks; H/P operation scope and manager callback; wings own busy/hash protocol.
- Review/inspection: `INSPECTED` / `MATCHES` inspected guards, with broader test limitations separately recorded. V3 `Common.sol:133–161` checks bound pool; public routes are nonReentrant; RB :382–395 asserts nested `IsLocked` and no recipient shares. H/P `Common.sol:79–84,683–700` use scoped operation/context consumption; TH/TP `GuardClosure.t.sol` instantiate the shared G5 fixture separately. `TB TestBase_FullSpreadG5GuardClosure.sol:254–273` proves callback attempt, exact `IsLocked`, held token/SY shares and rollback in both nested shapes. Older `AdversarialReentrancy.t.sol:19–28` only expects `reenter-failed`; the stronger G5 coverage is relevant counterevidence, not ignored. Wings `Common.sol:43–56`, `ExecutionDelegate.sol:23–30`, `Money.sol:41–53` authenticate busy/callback state and clear it; A-F02/A-F03 bound wings test confidence.
- Execution: `MISSING` / `UNKNOWN` for full current callback campaigns; supplied isolated claims are not that campaign.
- Origin/residual: original-program plus wings extension; external hostile underlying fixtures are allowed, no mocked SUT inspected.
- Findings/readiness: A-F02/A-F03 for wings; A-F04 for release provenance. `BLOCKS` full campaign closure; no demonstrated duplicate-credit code path.

### S2-ADD-005 — Four current outside-trade tests

- Requirement/authority/applicability: RP OD-04 :130–143, OD-08 :179–186, REQ-05 :255–265; `APPLICABLE` to each of V3/H/P/wings separately.
- Review/inspection: `INSPECTED` / `MATCHES` source structure. V3 `TV3 _FeeCompound.t.sol:50–74` seeds an incumbent, records both books/supply, calls `_externalSwapExactIn` and then a separately funded deposit with preview/share assertions. H `TH AttributionAndBooking.t.sol:34–48` and P `TP AttributionAndBooking.t.sol:37–51` separately bootstrap, record books/supply, trade through their fixture's manager callback and perform funded deposit. H/P acceptance bases :96–137 and :102–149 respectively call actual `poolManager.swap` and settle actor deltas, not a vault trade; P registers the real Pons fixture at :54–62. Wings `TW Money.t.sol:26–39` trades through a funded `PoolActor`, retains book/supply assertions and performs a target deposit; actor `swapTo/_swap` opens its own manager session.
- Limits/counterevidence: these named tests mostly compare execution with the production preview, not an independent economic reference. They are narrow OD-04 regression controls, not proof of every fee/quote domain. V3 delivery behavior adds explicit deployed-inventory movement and zero-input negatives; separate H/P attribution negatives check forged credit. Wings's `IBasicVault` tracks only the target; authoritative opposing custody is `localReserves`, so its second BasicVault book assertion is not an independent opposing-book proof.
- Execution: `INCOMPLETE_PROVENANCE` / `PASS` **as claimed for these four names** in Stage-1 note; not `SUPPLIED_SOURCE_BOUND` to the review digest. No new run.
- Origin/residual/findings/readiness: supplemental Stage-1 continuity, owner acceptance retained; A-F04; `BLOCKS` source-bound runtime closure only. No source contradiction to the four-test requirement found.

### S2-ADD-009 — Wings O1–O7 and A3

- Requirement/authority/applicability: WP :11–36 and surviving C/V/S requirements; `APPLICABLE`; later O rules supersede earlier sink/zero-value-policy suggestions. No Pons binding authorized.
- Product/review: wings own target-only book, `INSPECTED`; overall `INDETERMINATE` for the complete proof obligation because named-test/campaign limitations remain, while inspected O1/O3/O5/O6/O7/A3 control flow matches the ruling.
- O1/O3: `W LiquidationQuote.sol:113–139` values target plus realizable proceeds, retains unsold inventory; `W Money.sol:106–139` books pre-existing residual on zero-supply bootstrap and excludes pending credit/refund. `TW Money.t.sol:60–70,144–155` asserts first-depositor benefit, zero supply, closed positions and surviving unsold incentive. This owner-selected allocation is not an A0 vulnerability by itself.
- O2/O7: `W Money.sol:139,169–187` preserves one target unit for remaining supply and releases it on final redemption; `W Accounting.sol:54–60` and `W Harvest.sol:161–174` apply the floor alongside oracle sleeve. `TW Money.t.sol:97–102,144–155` exercises native-unit/terminal floor; invariant limitations are A-F03. These are concrete enforcement paths, not a reopened request for the owner to prove positive value.
- O4: `W ExecutionDelegate.sol:31–78` settles actual pool caller deltas once; `W Money.sol:168–186,224–243` pays from reserves, computes cost bound and checks remaining-holder value. `TW ExecutionCost.t.sol:14–28` uses an independent one-step fee/rounding formula and empty-traversal zero-cost checks; `TW Rebalance.t.sol:54–73` links permitted loss to actual core progress. No blanket proof of all price-domain entitlement funding is claimed.
- O5: `W Accounting.sol:45–59`, `W Harvest.sol:47–49,161–174` use the configured oracle and local/deployed-target denominator; no wings hardcoded 20% default. The test fixture's explicit oracle setting is configuration, not production default. `TW Rebalance.t.sol:90–98` tests changed oracle sleeve.
- O6: `W DFPkg.sol:127–136` validates ordered nonnative currencies, zero hook and target membership; `W InTarget.sol:19–24`/`OutTarget.sol:27–32` expose only target/share routes. `TW Money.t.sol:175–179` and `TW Surfaces.t.sol:82–89` reject opposing/native inputs. Do not port FullSpread multi-input/import/native routes here.
- A3: `W Money.sol:128–139` authenticates inbound before idle harvest; :94–104 skips mutation for an already-unlocked manager. Preview :258–301 uses projected harvest; `W Projection.sol:85–105` prepares projected state likewise. `TW Money.t.sol:104–142` checks pending-credit isolation, deferred converted-wing harvest and sleeve-only exit/rollback. `TW Transition.t.sol:22–52,54–111` compares projected post-exit local balances, positions, assets/supply to real operations, including both target orientations.
- Execution: `INCOMPLETE_PROVENANCE` / `PARTIAL`; source contains broader tests, no whole wings source-bound acceptance run established in this assignment.
- Origin/residual: supplemental new family; O1/O3 intentional residual lifecycle, no permanent sink; D12 unbooked transfer caveat retained.
- Findings/readiness: A-F02/A-F03/A-F04; `BLOCKS` unqualified security/campaign closure. Confidence high on policy/code mapping, bounded on numerical-domain proof and full consumer coverage (lane C owns matrix).

### S2-ADD-010 — V4 split package binding and current evidence identity

- Requirement/authority/applicability: RP OD-05 :145–153, REQ-08 :308–321; current V4 PRD D22/D23/D26/D28/D29; `APPLICABLE` separately to H and P.
- Review/inspection: `INSPECTED` / `MATCHES` inspected source identity/admission; evidence completeness is separate. H `DFPkg.sol:394–420` rejects nonzero hooks and checks family component names/code. P `DFPkg.sol:108–119,403–432` pins production expected hook, validates manager, registered launch, zero LP fee and separate family components. `P FeeService.sol:35–60` reads registered launch terms and preserves separate fee floors. P does not inherit H economic dispatch in the inspected OutExecute/Common units; pure shared types are explicit imports, allowed by FP.
- Tests: TH/TP `AdmissionAndIdentity.t.sol` separately checks invalid hook/key, separate pool instances, fixture binding and Target/Facet/proxy declarations; TP :64–84 loops component controls and loupe; TP `PonsFeeSemantics.t.sol:22–56` checks both exactness modes/directions against real core hook charges and independence from changed global defaults. H/P acceptance fixtures bind zero hook versus registered real Pons hook.
- Execution: `INCOMPLETE_PROVENANCE` / `PARTIAL`; Stage-1 note maps roots, four test names and aggregate selector compare, but no reviewed-source full replacement run/artifact linkage was established. Pons accepted documentation evidence is not reopened for runtime-codehash equivalence or RPC.
- Origin/residual/findings/readiness: supplemental split binding, not permission to merge or bind wings to Pons; A-F04; `BLOCKS` unqualified source-bound completion claim, not a discovered admission-code contradiction.

## Shared-seam and catalogue dispositions

These are lane-local contributions, not duplicate ownership of the coordinator's full R13/R14 or C's matrix rows.

| Seam/catalog | Applicability and inspected support | Limitation |
| --- | --- | --- |
| R13.1–2 / I1–I3 | All supported public push routes require actual local credit; exact-input guard and replay tests traced. A-F01 identifies exact-output error ordering. H pretransfer lifecycle uses actual delegation attachment, not `vm.etch`. | No all-family delegated-wallet campaign verified here. |
| R13.4–7 / E6 | Amount-only exact-in, capped exact-out refunds, used-only pulls; G3 budget matrices seed booked self shares and check retained excess. Wings surplus policy differs from FullSpread and is not silently rewritten to sync all anonymous transfers. | No D12 sender-attribution promise; runtime source binding missing. |
| R14 local reserves | FullSpread `_syncVaultReserves` books local residuals and native WETH face; wings owned local0/local1 is separate from deposited caller credit, floor and unsold inventory. | Lending capacity/receipt adapter and other SE books belong to B; no conclusion here about them. |
| A0/A donation/bootstrap | FullSpread minimum/sink formula in current FP and G5; wings first-depositor donation benefit/zero-supply lifecycle is owner-authorized O1/O3. | No cross-family universal bootstrap formula is assumed. |
| B/L3 manipulation | Real external pool movement and quote/position changes present in R3 controls; wings value includes realizable liquidation rather than spot-only NAV. | Exhaustive economic/manipulation proof and complete analytic math audit not performed. |
| C reentrancy; H rollback | V3 exact nested error; H/P G5 exact callback error, attempt and rollback; wings busy/hash and no nested unlock, with A-F02 test qualification. | No current campaign run; hostile tests are not exhaustive token behavior. |
| D/F authority | Share redemption burns requested holder/self input; registry disable and authenticated manager callbacks inspected at entry seams. | Bond/NFT principal, role-governance and unrelated owner paths are outside this lane. |
| E conservation | Refund/used/supply/custody assertions read, wings terminal release/remaining-holder checks mapped. | Financial soundness over all supported integer domains requires evidence; no claimed theorem. |
| G composition | Native SY forwarding and blocked manager behavior traced; H/P separate fixtures and shared G3 route tests. | Full seven-hook Cartesian matrix owned by C. |
| I trust flags | Actual local balance minus book; excess-input/request-only handling; zero/short/replay controls. | D12 resting credit intentionally consumable by next eligible contract; not a defect. |
| J proxy surface | Registry fixture paths and H/P declaration/loupe controls inspected; wings package installs its provided facets, target-only dispatch and native SY test calls read. | Exhaustive selector-set/artifact verification belongs to D and was not executed. |
| K sync | FullSpread local book and current outside-trade tests; wings independent local book/settlement. | Wings second BasicVault token check does not replace localReserves assertion. |
| L1/L2 weird-token/surplus | FoT rejection and balance-deficit code mapped; wings tax/paused/rebase fixture is hostile non-SUT, subject to A-F02. | FoT/rebasing underlyings remain forbidden; these tests do not declare support. |
| M forwarding/approvals | Native SY fixed-selector delegate/self-call and G3 allowance assertions inspected. | General user routers/arbitrary calldata not reviewed in this lane. |
| N transitions | Wings quote prepared state, external-share attribution and projection-versus-execution assertions read; H/P quote funding plans examined at dispatch seams. | Work/gas limits and all deep analytic branches not independently proved. |
| O signatures | Wings nonce replay/domain checks in Security; G5 permit surface visible. | No independent EIP-712 implementation audit or runtime replay suite. |

## Read inventory and limits

The following is the actual content inspection inventory. “Scoped” means relevant ranges/search hits, not a claim to have read every line. Directory listings and filename-only search hits are discovery, not inspection credit.

Authority/rules, scoped where long:

- `CLAUDE.md`; `docs/agent/INDEXEDEX_AGENT_LAW.md`; controlling `docs/plans/APEX_STAGE2_REVIEW_PRD.md` and `.plan.md`; accepted run `REVIEW_MANIFEST.md`.
- AP; RP; `docs/reviews/apex-2026-09-17-second-audit-readiness/STAGE1_EVIDENCE.md`; initial entries of its `selector-size-compare-stage1-current.json`; historical `docs/audits/apex-2026-09-17-evidence.md` (explicitly historical).
- WP and companion `.plan.md`; `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md`; FP; `docs/plans/UNISWAP_V4_FULLSPREAD_CONTEXT_QUOTE_ADDENDUM.md`.
- `.claude/skills/indexedex-testing/SKILL.md`, `.claude/skills/indexedex-adversarial-testing/SKILL.md`; canonical `lib/crane/.claude/skills/{crane-testing,crane-adversarial-testing,crane-deployment,crane-architecture}/SKILL.md`. Read as source rules, no workflow execution.

Production content:

- `contracts/utils/LocalCreditLib.sol`; `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol`.
- V3 `Common.sol`, `InBase.sol`, `OutBase.sol`, `InTarget.sol`, `InMultiTarget.sol`, `OutTarget.sol`, `OutExecuteTarget.sol`, `OutExecutionDelegate.sol`, `OutMultiTarget.sol` (full delivery/refund branches, other portions scoped).
- H `Common.sol`, `OutExecuteTarget.sol`, `DFPkg.sol`; P `Common.sol`, `OutExecuteTarget.sol`, `InMultiTarget.sol`, `DFPkg.sol`, `FeeService.sol` (economic dispatch/delivery/binding ranges and search hits). Underlying H/P analytic/planner libraries were not fully audited; their interfaces/calls were read through these sources.
- W `Common.sol`, `Money.sol`, `Accounting.sol`, `InTarget.sol`, `OutTarget.sol`, `SYTarget.sol`, `ExecutionDelegate.sol`, `DFPkg.sol`, `EconomicTarget.sol`, `TransitionTarget.sol`, `Projection.sol` (first 105 lines), `Harvest.sol` (first 220 lines), `LiquidationQuote.sol` (first 230 lines; further fee/settlement search hits). Not a complete proof of the quote traversal library.

Tests/fixtures content:

- TV3 `_FeeCompound.t.sol` (including entire outside-trade test); RB `UniswapV3FullSpreadStandardExchangeVault_Delivery.t.sol`, `StandardExchangeDeliveryBehavior.sol` (negative/funded/refund/lock/fee controls), `StandardExchangeReleaseBehavior.sol` (scoped search hits).
- H and P `test/bases/TestBase_*_Acceptance.sol` (full names as imported by TH/TP AttributionAndBooking); wings `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/test/bases/TestBase_UniswapV4UpperLowerWingsStandardExchangeVault.sol`.
- Deployment/helper ranges in `contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol` (:63–124,161–175); H `test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault.sol` and P `test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook.sol` (factory/registry setup search ranges). V3 calls the real pool directly for its outside swap; current H/P packages are constructed through the manager deployment methods.
- TH/TP `AttributionAndBooking.t.sol`, `AdversarialReentrancy.t.sol`, `GuardClosure.t.sol`, `NativePositionImportFunding.t.sol`, `AdmissionAndIdentity.t.sol`; TH `PretransferCallerLifecycle.t.sol`, `RouteFundingClosure.t.sol`, `Adversarial.t.sol` (scoped); TP `PonsFeeSemantics.t.sol`.
- TB `TestBase_UniswapV4FullSpreadG3RouteFunding.sol` (ledger, rollback, allowance, eight-mode budget and F3 controls; remaining test declarations searched), `TestBase_FullSpreadG5GuardClosure.sol` (nested callbacks/history wiring and declarations), `TestBase_UniswapV4FullSpreadNativeImport.sol` (funding and rollback assertions/search hits).
- TW `Money.t.sol`, `Surfaces.t.sol`, `Security.t.sol`, `Tokens.t.sol`, `Invariant.t.sol`, `ExecutionCost.t.sol`, `Transition.t.sol` (first 145 lines), `Rebalance.t.sol` (first 100 lines); `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/reference/UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor.sol` (first 90 lines).

Not inspected as primary contents: historical PDF itself, complete release logs/artifact bytecode, all deep V4 analytic and wings liquidation/projection arithmetic, all test files in each family, deployed instances, chain state, full hook matrix, or unrelated family implementations. These remain explicit limits; assignment conclusions do not claim those things. The coordinator owns historical audit mapping, release provenance and total R1–R14 reconciliation. Each assigned criterion and supplement has a substantive disposition above; retained R3.3 breadth and wings full-proof claims remain indeterminate rather than being marked passed by filenames.

First-pass original ends here. No cross-review conclusions have been incorporated.
