# C06 — Local credit and RebasingAware custody: independent first pass

## Identity, scope and conclusion

- Reviewer: C06; session `ses_ee93de787ffeHFuOsRl7gOjvFi` as recorded in `REVIEW_MANIFEST.md:152`. Independent original; no peer report read and no cross-review performed.
- Snapshot: IndexedEx HEAD `5709cb3507a9df72b11ec476d27b79ef88696c3a` plus working-tree edits, per `REVIEW_MANIFEST.md:32–44,74–75`. Identity is supplied by the manifest, not independently recomputed. Dirty-file content hashes are unavailable. Conclusions describe the files read during this pass, not immutable deployed instances.
- Permissions observed: source/document inspection only; no shell, build, test, simulation, RPC, source modification or Crane-body audit. This Markdown is the only repository write.
- Result: **bounded first-pass inspection delivered; PARTIAL for aggregate R5/R9/R13 closure**. The helper arithmetic and inspected custody execution paths match the principal credit/burn/refund rules. No production code defect is established in those paths. Two confirmed low-severity test/documentation deficiencies and one unresolved evidence qualification are below. Broader consumers and complete custody campaign coverage are not closed by this report.
- Execution: the Stage-1 note reports all three assigned custody tests passed. This review did not rerun them. Do not convert this report into audit-submission approval.

## Citation key and authority

All paths are repository-relative. The following abbreviations apply to every `file:line` citation below:

| Key | File |
| --- | --- |
| PLAN | `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md` |
| S2 | `docs/plans/APEX_STAGE2_REVIEW_PRD.md` |
| READY | `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` |
| EVID | `docs/reviews/apex-2026-09-17-second-audit-readiness/STAGE1_EVIDENCE.md` |
| LAW | `contracts/protocols/staking/rebasingVault/REBASING_AWARE_ERC4626_SY_SE_PRD.md` |
| LC | `contracts/utils/LocalCreditLib.sol` |
| LCT | `test/foundry/spec/utils/LocalCreditLib.t.sol` |
| SE | `contracts/protocols/staking/rebasingVault/RebasingAwareStandardExchangeTarget.sol` |
| SY | `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol` |
| COMMON | `contracts/protocols/staking/rebasingVault/RebasingAwareERC4626Common.sol` |
| ERC | `contracts/protocols/staking/rebasingVault/RebasingAwareERC4626Target.sol` |
| META | `contracts/protocols/staking/rebasingVault/RebasingAwareVaultMetadataTarget.sol` |
| PKG | `contracts/protocols/staking/rebasingVault/RebasingAwareERC4626DFPkg.sol` |
| BASE | `contracts/protocols/staking/rebasingVault/TestBase_RebasingAwareERC4626.sol` |
| ADV | `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol` |
| FUZZ | `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol` |
| SET | `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_StandardExchange.t.sol` |
| SYT | `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_StandardYield.t.sol` |
| INV | `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Invariant.t.sol` (only lines 166–212 opened) |
| TOKEN | `contracts/test/stubs/ReentrantERC20Harness.sol` |

Controlling rules: PLAN:102 (D12 accepted non-atomic contract-caller residual), :507–512 (R5), :542–548 (R9), :577–583 (R13.1–R13.7); READY:166–177 (OD-07), :223–235 (REQ-03); S2:198–228 (Stage-1 continuity and production-route assertions). The custody product is expressly an exception permitting rebasing direct backing, LAW:73,79–104. Applying the generic raw-rebasing-underlying prohibition here would contradict that scoped owner ruling. OD-03's receipt-backed redemption-cap change is not silently transplanted to this direct-custody wrapper.

Read the IndexedEx-local testing and adversarial skills directly: `.claude/skills/indexedex-testing/SKILL.md:25–35,144–188` and `.claude/skills/indexedex-adversarial-testing/SKILL.md:146–180`. Their commands were not executed. Agent-law token/trust-flag entries were located at `docs/agent/INDEXEDEX_AGENT_LAW.md:96,422`; the scoped product exception above controls this package.

## What the inspected implementation does

### Helper

`available` is saturating subtraction, so the subtraction branch cannot underflow; `budget` is a minimum without addition or multiplication (LC:13–21). Neither primitive authenticates ownership or validates token-unit identity. The bytecode test is a call to `BetterAddress.isContract` followed by the exact IndexedEx error (LC:23–27); the imported Crane body was not inspected. Its stated limitation is explicit at LC:7–9.

LCT:69–114 covers zero, deficit, equality, excess and maximum arithmetic, plus fuzzed formulas and refund bounds. LCT:116–177 contains exact EOA and constructor rejection, deployed-caller acceptance, and actual delegation via `vm.signAndAttachDelegation`, not `vm.etch`. The harness's consume methods deliberately record declared input without implementing a production reserve book (LCT:28–49). Their success is therefore **not** a family-credit regression. LCT:179–205 checks a pull fixture and failed-consume rollback, not a custody SE recipient implementation.

### Custody accounting inventory

| Surface | Units/book and synchronization | Payer, credit, payout and remainder |
| --- | --- | --- |
| Asset→share SE exact-in, SY deposit, ERC4626 deposit | Configured raw asset units; live pre-pull balance and common supply/virtual offset (COMMON:67–74,341–367) | Pull precisely assets from `msg.sender`; require unchanged asset supply and exact payer debit/vault credit (COMMON:274–287). Mint calculated shares to receiver. No anonymous asset balance is deposit payment. SE asset pretransfer is rejected (SE:77–81). |
| Asset→share SE exact-out / ERC4626 mint | Same live book; ceil assets-for-mint (COMMON:149–151,370–397) | Check calculated assets against max before pull; pull calculated amount only; mint requested shares; no max-minus-used refund. SE:111–115 rejects asset pretransfer. |
| Share→asset SE exact-in, prepaid | Raw static wrapper shares; self-held shares have no separate booked-self-share deduction under this package's public custody rule | Guard caller (SE:83–89), burn exactly requested shares from vault self-balance or exact shortfall (COMMON:321–325), transfer calculated assets to recipient. No share refund. Remainder stays public self-shares. |
| Share→asset SE exact-out, prepaid | Snapshot raw self-held shares before payout, book argument zero (SE:117–126) | Credit = min(self shares, max); required shares must fit credit. Burn required shares once; pay exact assets; return credit-minus-burned shares to `msg.sender`, not payout recipient (SE:127–138). Outside-budget self shares and callback-added shares are not included in the snapshotted refund. |
| Holder-funded exits | Same shared supply and live asset backing | SE/SY choose caller as owner when false; ERC4626 allows approved owner. COMMON:309–319 checks balance/allowance and burns once. Exits do not pull a declared maximum. |
| SY internal-balance redeem | Same static self-held-share balance, not asset reserves | External caller must pass bytecode gate; self-call exempt only from that gate (SY:57–65). Exact requested burn, no refund (COMMON:321–325,399–426). Self-call does not mean burn the entire balance. |

Rebases/donations update share value through `liveBook`, not delivery authentication (COMMON:67–74,145–159). Outbound transfers check both reserve debit and receiver credit and unchanged asset supply (COMMON:290–306). Zero-output and backing constraints precede burn (COMMON:411–421). `reserveOfToken` is itself live balance, not an independent stored-book update (META:34–44); tests saying “books nothing” in this package are testing live custody consistency, not stale-book isolation.

Production-route inspection: BASE:50–64 uses facet FactoryServices, manager package deployment and package `deployVault`; PKG:81–105 forwards instance deployment through the registry. PKG:184–193 installs SE/SY cuts. `RebasingAwareStandardExchangeFacet.sol:22–27` names the four SE selectors. `RebasingAwareStandardYieldFacet.sol:21–23` delegates selector construction to `NativeStandardYieldSelectors`; that helper was not opened, so complete SY selector-set equivalence is not independently closed. SYT:100–120 calls the advertised SY surface on the proxy in source; no run is claimed. PKG:214–254 validates/configures offset bounds and metadata. The deployment FactoryService implementation, registry implementation and artifact bytecode were not audited here.

## The three assigned Stage-1 tests

| Test | Static reachability and assertions | Inspection disposition |
| --- | --- | --- |
| `test_ADV_cannotBurnOtherHolderViaInternalSy` | ADV:50–60 first deposits for Alice, uses an actual deployed caller contract address, then requests internal redemption while vault self-shares are zero. SY:57–65 passes the caller gate; COMMON:411–421 reaches `takeShares`; COMMON:321–325 supplies `TransferDeltaInsufficient(shares,0)`. Test pins both arguments and checks Alice's shares and live reserve unchanged. | **MATCHES** the named ownership correction, not a broad `expectRevert`. No assertion of generic caller ownership over resting public shares is implied. |
| `test_ADV03_reentrancyDuringDepositReverts` | ADV:128–146 configures token callback before deposit, expects `TransferFromFailed`, and checks supply, Alice shares, vault assets and reserve unchanged. Callback ADV:28–32 low-level-calls nested deposit, checks `!ok` and exact `IsLocked` bytes, then deliberately reverts `IsLocked`. TOKEN:58–75 moves tokens, invokes callback and bubbles its failure. ERC:74–75 applies the lock on deposit. | Exact inner assertion **is present**, and intended nested call is wired; not merely bare `expectRevert`. Outer assertion alone proves only a failed transfer and rollback. Strict proof that a wrong nested reason cannot still leave this test green depends on assertion-failure propagation through the reverted callback/transfer wrapper; **INDETERMINATE** within the dependency/no-execution boundary. See C06-E01. |
| `testFuzz_FUZZ02_exactOutMinimals` | FUZZ:57–100 uses an empty real wrapper, offset 10, approved funded Alice (BASE:41,62–74), bounds requested shares, rejects `need <= 1`, pins `MaxAmountExceeded(need-1,need)`, asserts unchanged shares/supply/assets/reserve, restores snapshot and succeeds at `need`, asserting exact returned payment, shares and asset/reserve deltas. COMMON:385–391 places the max check before pull. | **MATCHES** the short-funding/exact-success correction for this asset→share empty-state route. Not a proof of share→asset minimality or nonempty/rebased-state coverage. No broad `expectRevert`. |

Stage-1 evidence is **reported PASS**, EVID:26–30. Provenance for independent acceptance is **INCOMPLETE_PROVENANCE**: EVID:4 identifies HEAD plus unspecified dirty edits rather than content hashes; :28 describes the command family and flags but does not give the complete individual invocations, toolchain versions or per-run raw transcripts. This is a limitation of the supplied note, not a claim that those tests failed or that the owner's Stage-1 acceptance is invalid. Manifest:15 explicitly accepts the note and its scanner limitation.

## Findings and qualifications

### C06-E01 — Nested-guard proof depends on failure propagation outside the inspected boundary

- Class: **EVIDENCE_GAP**; severity **Informational**; confidence high in the source structure, limited in runtime consequences. Origin: Stage-1 REQ-03 continuity question; **not a confirmed STAGE1_OPEN or STAGE1_REGRESSION**.
- Affected snapshot/package: this manifest's dirty ADV test and TOKEN fixture, RebasingAware custody; S2-ADD-003 / READY:230–233.
- Evidence: ADV:26–32,128–146; TOKEN:68–77. The callback intentionally fails even after correct assertions; the outer expected error is a transfer-wrapper error. An ordinary callback failure and the intended nested rejection both reach a failed outer transfer. State rollback assertions cannot discriminate those causes on their own.
- Counterevidence: the callback does compare exact `IsLocked` bytes, and Foundry assertions may have failure signaling beyond an ordinary reverted frame. That implementation/behavior was not inspected or run. Consequently this review does **not** assert that wrong nested errors actually pass.
- Additional, distinct counterevidence: INV:172–200 uses a callback that returns after exact nested-error assertions, and the outer path requires successful deposit/redeem plus a two-callback counter delta. Only that excerpt was inspected, not the whole invariant campaign; no supplied current execution result for it was evaluated.
- Impact: uncertainty about the discriminating power of one named security regression, not demonstrated fund loss or missing production reentrancy protection.
- Readiness effect: **UNDETERMINED** for the strict REQ-03 nested-error closure claim. Coordinator should retain this qualification rather than report the three tests as independently verified. If later inspection establishes masking, classify the existing REQ-03 issue as STAGE1_OPEN and apply S2:211's pause/owner-decision rule; do not rename it a new production defect.
- Verification objective: separately establish that a wrong nested error necessarily fails the named test, or rely on a source-bound non-masking observation of the exact nested error. No verification was executed or authorized by this report.
- Attribution: C06 original; cross-review not performed; coordinator disposition pending.

### C06-T01 — SY invalid-token negatives still accept any revert

- Class: **TEST_DEFICIENCY**; severity **Low**; confidence high. Origin: broader original-program assertion quality, not a regression in the three repaired tests.
- Evidence: SYT:123–128 uses bare `vm.expectRevert()` for both positive invalid-token deposit and preview. Production errors are explicit `InvalidRoute` at SY:33–35 and :112–115.
- Requirement: production-route exact assertions, S2:215–228; READY:227's R2.4 standard. Relevant to R5.4 and R13 consumer test confidence, but does not contradict their inspected burn semantics.
- Impact: those two tests cannot distinguish intended route rejection from an unrelated revert and omit affected-state assertions. No production route-validation defect is established.
- Counterevidence: route validation exists in source; these are not the three Stage-1 named tests. EVID:60 already discloses a non-clean wider bare-revert inventory, so this is **not** a newly alleged breach of the accepted Stage-1 scanner baseline.
- Readiness effect: **BLOCKS** treating these tests as exact route-rejection evidence; does not invalidate helper arithmetic or prove custody loss.
- Corrective objective: pin the intended route error and relevant unchanged state in a separately authorized test-remediation task.
- Attribution: C06 original; cross-review not performed; coordinator disposition pending.

### C06-D01 — SY internal-balance NatSpec omits the explicit remaining-credit warning

- Class: **DOCUMENTATION_GAP**; severity **Low**; confidence high. Origin: original-program R13.3.
- Evidence: SY:41–44 documents contract-only use, atomic transfer-and-consume, staged integrator risk, exact requested burn and no refund. It does not expressly say remaining unrecorded vault-held balance can be consumed by the next contract caller, or that booked holder backing is not pretransfer credit, as required for this target by PLAN:579.
- Counterevidence: LAW:152–156 explains the public, nonexclusive custody semantics; LC:7–9 warns its math does not attribute ownership. The omission is narrower than an entirely missing risk disclosure.
- Impact: caller-facing function documentation incompletely states an accepted exposure; **D12 remains an accepted residual, not a new code defect**.
- Readiness effect: **BLOCKS** full textual R13.3 compliance for the IndexedEx SY target, not economic source closure. Crane interface NatSpec remains outside this lane and was not read.
- Corrective objective: carry the explicit resting-credit and backing distinction into this function's NatSpec without changing API-12 or adding ownership/atomicity mechanisms.
- Attribution: C06 original; cross-review not performed; coordinator disposition pending.

## Criterion dispositions for this lane

Every row below belongs to C06 and the stated snapshot. `MATCHES` means static consistency, never runtime PASS. `PARTIAL` identifies remaining inspection coverage. All rows are APPLICABLE within custody/helper scope unless qualified; none closes other D16 families. Runtime evidence is MISSING/UNKNOWN in this pass except the three named tests' INCOMPLETE_PROVENANCE/reported PASS above. Documentary-only subclaims are NOT_REQUIRED/UNKNOWN for execution. Absence of a run is not itself a code defect.

| Criterion / original reference | Current authority and inspected evidence | Review state / result; limits and readiness |
| --- | --- | --- |
| R5.1 / PLAN:507 | OD-07 removes old-source-red-run obligation. SET:269–285 demonstrates a separate public share transfer and requested burn, but chooses a fraction, not a preview-derived smallest nonzero burn. | PARTIAL / INDETERMINATE for the full criterion. Minimal-burn custody evidence not established; no repository-wide absence claim. Blocks lane closure of this row. |
| R5.2 / PLAN:508 | D23/D28; SE:83–92,117–138; COMMON:321–325; SET:113–132,218–254,289–304. | INSPECTED / MATCHES source: exact-in burns requested/no refund; exact-out caps budget, exact shortfall, refund to caller. Runtime closure not asserted. |
| R5.3 / PLAN:509 | SET:27–110,113–132,218–304; ADV:113–126,162–202; FUZZ:153–172. Distinct recipient, insufficient/excess shares and atomic outbound failure covered in opened tests. | PARTIAL / INDETERMINATE for complete zero/short/exact/excess × callback-added/rebase/second-redemption matrix. No completed campaign inferred from names/search hits. Blocks aggregate row closure. |
| R5.4 / PLAN:510 | API-12; SY:45–66; COMMON:309–325; SYT:59–76; ADV:50–60. | INSPECTED / MATCHES burn/guard source; self-call exemption remains bounded to requested shares. C06-T01 qualifies unrelated invalid-route test quality. |
| R5.5 / PLAN:511 | LAW:73,79–104,148; SE:77–81,111–115; COMMON:67–83,145–159,349–362,411–421; PKG:214–254. | INSPECTED / MATCHES source; asset pretransfer rejection and live backing retained, bounded immutable offset and zero-output checks. General rebase/decimal campaigns not closed. |
| R5.6 / PLAN:512 | LAW:7,139–156 contains amended API-07; SET:113–132 reflects no exact-in refund. | PARTIAL / MATCHES document amendment; current immutable-instance and frontend inventory not inspected. No live-instance remediation inferred. C01/provenance seam remains. |
| R9.1 / PLAN:542 | Custody inventory above; native share units separate from rebasing reserve units. | INSPECTED / MATCHES for opened custody routes; PARTIAL globally. Consumer list below prevents false generalization. |
| R9.2 / PLAN:543 | LC:13–27, LCT:69–102. | INSPECTED / MATCHES arithmetic and caller-error call site. Crane bytecode-helper body not audited; runtime and identical-unit inputs at other consumers unclosed. |
| R9.3 / PLAN:544 | SE:83–92,117–143; COMMON:274–287,321–325,385–392. | INSPECTED / MATCHES for custody. Asset pull measures exact debit/credit; prepaid shares use exact request or capped actual-used refund. |
| R9.4 / PLAN:545 | LC:14–20; LCT:69–114. Custody has book=0 for static self shares, not a fictitious asset reserve deficit. | INSPECTED / MATCHES helper boundary assertions; full consumer numeric behavior remains separate. |
| R9.5 / PLAN:546 | SE:119–136 proves max is a cap, not additional credit. LCT:104–114 asserts the bound arithmetically; SET:218–254 tests max equal to public balance. | PARTIAL / MATCHES source; opened family test does not independently cover every max below/equal/above public credit arrangement. No universal executed conservation claim. |
| R9.6 / PLAN:547 | Two custody direct helper consumers opened. SE exact-in delegates balance/burn to COMMON:321–325 rather than calling arithmetic helpers there; behavior is the specified zero-book exact burn. | PARTIAL / MATCHES custody call-site intent; all-consumer library routing remains INDETERMINATE. D32 rejection exceptions not inspected here. |
| R9.7 / PLAN:548 | LCT tests exist; production custody BASE and tests inspected. | PARTIAL / INDETERMINATE regarding historical validation order and all production-route regressions. Helper correctness does not close 003/008/009/004B. |
| R13.1 / PLAN:577 | SE:83–89,117–125; SY:57–63. Asset pretransfer rejects categorically. | INSPECTED / MATCHES custody caller-gate placement. All other public flags unclosed by C06. |
| R13.2 / PLAN:578 | LCT:116–177 exact EOA/constructor and deployed/delegated controls; SET:120–131,229–254 and SYT:67–75 family EOA/contract cases. | INSPECTED / MATCHES presence of helper controls; PARTIAL for family-level comprehensive state assertions and runtime/toolchain identity. Combined sign-and-attach is a real delegation operation in test source, not an etch fixture. |
| R13.3 / PLAN:579 | SY:41–44 versus required warning; LAW:152–156. | INSPECTED / CONTRADICTS full target NatSpec obligation, C06-D01. Broader/Crane interfaces not assessed. |
| R13.4 / PLAN:580 | SE:117–143; COMMON:274–287,309–325,385–392. | INSPECTED / MATCHES custody source; burned/credited quantities remain in share units, exact-out pull spends only used. |
| R13.5 / PLAN:581 | SET:269–304; FUZZ:153–171; SYT:59–76. | PARTIAL / INDETERMINATE for the full requested per-surface boundary and resting-plus-atomic control set. Located tests do not by themselves close every specified case. |
| R13.6 / PLAN:582 | SY:57–65 and COMMON:321–325 use explicit requested shares even for self-call. | INSPECTED / MATCHES bounded single-burn behavior. Custody does not have FullSpread's internal LP-production path; that specialized branch is NOT_APPLICABLE here, not closed for FullSpread. |
| R13.7 / PLAN:583 | SE:119–136 snapshots refund credit; exact-in and SY do not refund excess. LAW:154 makes remaining self shares public prepaid custody. | INSPECTED / MATCHES as amended by custody R5.2/API-07/D12. Uncredited self shares remain public credit; underlying donations remain live backing. Do not apply another family's end-of-operation stored-book rule here. |
| S2-ADD-003 / S2:204; READY:223–235 | Three-test analysis above; EVID:30,60. | PARTIAL / MATCHES ownership and minimality source; reentrancy strict proof INDETERMINATE, C06-E01. Scanner implementation not opened; note explicitly discloses wider failure. No confirmed Stage-1 regression alleged. |

## Catalog applicability (bounded to this helper/custody assignment)

- A/A0, E/E6, I1–I3, K: applicable donation, credit, exact burn and refund ownership properties. ADV:35–60,63–89 and SET:218–304 were opened. D12 public static self-shares are distinct from booked asset backing; do not turn permitted staged self-share consumption into an I1 theft finding.
- C, H, N1/N2: callback/reentrancy, atomic rejection and preview/settlement sequencing apply; ADV:128–146,162–202, FUZZ:57–100 and COMMON:274–306 inspected with C06-E01 qualification.
- F/J: instance surface/deployment/auth controls are relevant; BASE/PKG/facets were inspected only to the boundary described above. ADV:205–214's failed low-level diamond-cut call alone is not proof of correct authorization: it does not pin an error or demonstrate a well-formed authorized control. No upgradeability finding inferred.
- L2 applies: FoT forbidden; ADV:162–202 checks exact supply-change error and rollback across five exit routes. L1/L3/B pool-price classes do not apply directly to a custody wrapper with no pool position; downstream integration remains another coverage group.
- D/G downstream claim/composition campaigns not closed here; the direct wrapper itself has no bond vesting engine. M user-calldata router forwarding and O Permit2/signature-spend paths are absent from the inspected SE/SY targets. Inherited ERC20/permit surfaces were not audited and are not declared globally inapplicable. No fee-beneficiary payout exists in this fee-free common settlement core.

## Consumers opened, consumers not opened

**Direct LocalCreditLib consumers actually opened:** `contracts/protocols/staking/rebasingVault/RebasingAwareStandardExchangeTarget.sol` and `RebasingAwareStandardYieldTarget.sol`. Their common settlement implementation was read in full. LC and LCT were read in full. Other fully opened IndexedEx supporting files are BASE, PKG, ERC, META, SE/SY facets, ADV, FUZZ, SET, SYT and TOKEN. INV was excerpt-only as specified above. Product law and original criteria were read in targeted sections/search results, not claimed exhaustively reviewed.

**Discovery method:** a `LocalCreditLib` filename-result content search restricted to `contracts/` returned 51 files: the helper, one custody PRD, and 49 Solidity consumer candidates. This is an import/reference inventory, not a complete D16 surface audit: it cannot discover nonusers, preserved rejections or indirect inherited entrypoints. Of those 49 candidates, the following 47 were **not opened**; braces below enumerate filenames, not an assertion that their bodies are identical:

- `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol`
- `contracts/protocols/staking/lido/LidoWstETHStandardExchangeCommon.sol`
- `contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeCommon.sol`
- `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeCommon.sol`
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol`
- `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchange{Common,OutTarget,InTarget}.sol`
- `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol`
- `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchange{OutTarget,Common}.sol` — deprecated, not reopened.
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchange{OutExecuteTarget,Common}.sol`
- `contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol`
- `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol`
- `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol`
- `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol`
- `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol`
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol`
- `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeCommon.sol`
- `contracts/vaults/basic/BasicVaultCommon.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVault{OutMultiTarget,Common,OutExecuteTarget,OutExecutionDelegate}.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHook{OutExecuteTarget,OutMultiTarget,Common,OutExecutionDelegate}.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVault{OutExecuteTarget,Common,OutMultiTarget,OutExecutionDelegate}.sol`
- `contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol`
- `contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetf{Common,ExchangeQueryTarget}.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFCommon.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenTarget.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfCommon.sol`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetf{ExchangeQueryTarget,Common}.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf{Target,Common}.sol`

Remaining custody test files found by Glob, including packaging, release, accounting, full invariants and buffer/DETF integrations, were not fully opened. Search hits in them are navigation evidence only. No whole-suite absence or all-tests-correct conclusion is made.

## Audit mapping, accepted residual and handoff

- **APEX-2026-003:** historical allegation remains CLAIM_UNVERIFIED by C06 (original PDF/live source not inspected). Current custody exact-in/SY no-refund and exact-out bounded-refund paths match R5.2/R5.4 on inspection; R5.1/R5.3/R5.6 coverage limitations remain. C06-T01/D01 and E01 are not claims that historical fund loss was reproduced.
- **APEX-2026-005:** current LC arithmetic matches R9.2/R9.4; current family closure is not inherited. Other consumers above require their own book/unit/synchronization and call-route inspection. Historical claim remains CLAIM_UNVERIFIED by this lane.
- **001-M / 008 / 009 / 004B:** this helper pass supplies no family closure. Custody live assets are not pretransfer deposit credit, and asset pretransfer is explicitly rejected; do not assign stale stored-total allegations merely because static-share pretransfer exists (PLAN:511).
- **D12 accepted residual:** separately resting unassigned static self-shares may be consumed by an allowed subsequent contract caller, bounded by the declared request/budget. ADV:76–88 deliberately tests that public custody behavior. This is UNSUPPORTED_USE in the plan's accepted-risk sense, not a new defect. No code exceeding that ruling was identified in the opened custody routes. Bytecode admission is not proof of atomicity or exclusive ownership, including contract wallets and delegated EOAs.
- The coordinator should preserve this original, reconcile remaining matrix/campaign and provenance obligations with the assigned lanes, and retain C06-E01 as uncertain unless further evidence resolves it. No cross-review, remediation PRD, test execution or implementation is initiated by this report.

Report validation was limited to checking the source citations and consistency of this authored content before writing. No command-based validation or reviewer-directory reread was performed, per assignment.
