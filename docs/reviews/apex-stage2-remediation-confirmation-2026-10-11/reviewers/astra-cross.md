# Astra — bounded cross-review of APEX Stage 2 remediation confirmation

Date: 2026-10-11. Continuing the successful Astra first-pass session. Original findings remain attributed to Astra and **`astra-original.md` is unchanged**.

Read the supplied **Grok, MiniMax M3 and Kimi K3 originals together**, then re-read the disputed current source and controlling documents. No peer cross-review was read. No code, test, configuration, original report or remediation PRD was edited. Only this assigned cross-report was written. No shell, tests, builds, deployments, browsers or delegation occurred.

## Read limitation and attribution correction

All three supplied files were requested in full and returned through their end-of-file markers: Grok 219 lines, MiniMax 286 lines, Kimi 169 lines. The read tool truncated Kimi's unusually long line 132 after 2,000 characters; an exact-file content search omitted that long line rather than exposing its remainder. **That remainder could not be inspected with the permitted tools.** The surrounding complete findings and disposition rows state the material positions; I do not claim to have seen the omitted text. No substitute peer summary or cross-review was used.

The continuation's description says Grok and Kimi also found ordinary V3 EOA redemption rejected. **Their supplied originals do not establish that attribution.** Grok's `grok-original.md:184` says the non-legacy-V4 inheritors match; Kimi's `kimi-original.md:145,151` lists the V3 route/tests as conforming. Neither original has a separately developed ordinary-EOA finding. I retain **Astra-01 as Astra's original finding**, not as a three-reviewer agreement. Grok and Kimi do independently report the legacy V4 external self-call.

Peer opinions are evidence to challenge, not authorization. No consensus or independently executed test result is claimed.

## Cross-review conclusions

| Dispute | Astra response | Final scoped judgment |
|---|---|---|
| RC-01 legacy V4 | Agree with Grok finding 1 and Kimi K3-01 on the call; object to MiniMax's closure. Retain Astra-02 at Low, not their Medium. | **PARTIALLY_EXECUTED**. Typed external call is still a self-call even without literal `.call` syntax. |
| RC-01 ordinary V3 EOA redemption | Retain Astra-01 independently; object to blanket ordinary-redemption closure in peer originals. | **PARTIALLY_EXECUTED**, Medium availability defect. Contract-caller test is insufficient. |
| RC-03 deletion versus README | Agree with MiniMax/Kimi that deletion is implemented; agree with Grok's documentation fact but not with treating it as surviving old V3 code. | Source migration **CONFIRMED_EXECUTED** within original bounded checks; Low documentation gap remains. |
| RC-04 checks versus tests | Agree all inspected checks exist; agree Grok/Kimi on missing settlement witness. Object to an unqualified all-acceptance closure. | Source check **CONFIRMED_EXECUTED**; full specified source-and-test repair **PARTIALLY_EXECUTED**. Low test deficiency. |
| RC-06 helper versus surrounding joins | Agree the helper's predicate/write is repaired; agree Grok on separate hook-zero conflict. Object to MiniMax/Kimi's broad REQ-01 closure. | Helper-source repair matches. Overall assignment item **PARTIALLY_EXECUTED**, including Medium Stage-1 hook-zero conflict and Low branch-specific test gap. |
| RC-06 failed probe | Narrow/correct Astra-04's unconditional classification; distinguish helper-local failed probe from subsequent independent zero preview. | Low **DECISION_NEEDED** on the assignment's broader no-book wording; not proof of booking without a successful SE zero preview. |
| Accepted-report items outside FIX_PRD | Agree no extra production repair was elaborated; object to equating that with no authorized verification or no substantive current tests. | Keep **NOT_A_REMEDIATION** as production-fix classification, while separately assessing actual test source and unverified runtime. |

`CONFIRMED_EXECUTED` here retains the original's narrow inspection meaning. It never means the implementation-session tests were run. FIX_PRD.plan `:156–159` requires tests and run reporting; that runtime portion remains unverified throughout.

## 1. RC-01 — two distinct incomplete paths

### 1A. Legacy V4: agree on mechanism, retain severity dissent

**Astra-02 retained: Low / CODE_DEFECT / failed RC-01 execution.**

**Re-read facts:**

- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol:17–24` implements `_redeemVaultHeld` with a typed external call to `IStandardExchangeIn(address(this)).exchangeIn`.
- Its ordinary override stages caller shares and switches to the internal route at `:27–34`.
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol:1299–1305` explicitly accepts the vault as `msg.sender` on the false-flag branch.
- The common SY entry now checks the original code-less caller on the true flag before settlement: `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:41–44`.

**Controlling requirement:** related `docs/reviews/apex-stage2-council-2026-10-07/FIX_PRD.md:77–88,103` requires no identity-changing external self-call and specifically forbids retaining it behind the new gate. The meaning is semantic, not a restriction only on the spelling `address(this).call`.

**Peer challenge:** MiniMax `minimax-original.md:70–76` infers all inventoried implementations use explicit burn or delegatecall from the absence of raw `.call` matches. The typed call above directly refutes that generalization. Agree with Grok `:74–90` and Kimi `:47–57` on nonconformance.

**Impact class:** caller-context/specification conformance, not established unauthorized payout. The new entry gate and held-balance check are material mitigation. I retain Low rather than Grok/Kimi's Medium: the observed remaining mechanism alone does not establish monetary or availability impact in that family. This severity dissent is unresolved.

**Fix direction:** share legacy V4 settlement with an explicit holder; remove the identity-substituting exchangeIn re-entry. Preserve its ordinary caller behavior and test the family independently. Do not delete or accounting-rewrite V4 under RC-03.

**Confidence:** high in source mechanics; no runtime or deployed-instance claim.

### 1B. V3 FullSpread: retain the ordinary EOA rejection finding

**Astra-01 retained: Medium / CODE_DEFECT / failed RC-01 ordinary-redemption requirement.**

**Re-read facts:**

1. Native SY ordinary redemption selects `_standardRoute` with false at `NativeStandardYieldTarget.sol:45–48`.
2. V3's override moves the original caller's shares locally, then delegatecalls exchangeIn with **true** at `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol:39–50`.
3. `UniswapV3FullSpreadStandardExchangeVaultInTarget.sol:58–61` uses `_secureShareDelivery` for that route.
4. Common `:918–920` forwards the flag to `_secureTokenTransfer`; Common `:866–867` invokes `LocalCreditLib.requirePretransferCaller(msg.sender)`.
5. `contracts/utils/LocalCreditLib.sol:23–27` rejects a caller without bytecode. Delegatecall has preserved the original caller.

**Inference:** an ordinary code-less holder reaches the external-pretransfer gate and is rejected. The staged transfer rolls back. This does not prove permanently stranded assets or failure of all other withdrawal interfaces; it proves failure of this ordinary SY interface.

**Requirement:** FIX_PRD `:86,97` preserves ordinary redemption of the original caller's shares. Preserving identity is necessary but not sufficient if subsequent validation now rejects that ordinary caller.

**Test counterevidence resolved:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol:96–104` tests ordinary redemption from the **test contract**. Its success assertions do not falsify the EOA failure. The EOA test at `:68–77` uses the true flag and is correctly expected to fail; it is a different requirement.

**Peer challenge:** MiniMax's general closure and Kimi/Grok's non-legacy conformance descriptions overlook this composition of the ordinary adapter with the guarded share-delivery helper. No peer original supplies a source exception or ordinary EOA positive to refute it.

**Impact class:** ordinary-wallet redemption availability.

**Fix direction:** retain the original owner as explicit settlement holder without turning an adapter-internal share movement into an externally asserted pretransfer. Preserve D9 for real true-flag entries. Add a funded ordinary EOA assertion alongside the contract-caller test.

**Confidence:** high in control-flow conclusion. Introduction date remains unverified; no baseline diff was supplied.

## 2. RC-03 — documentation residue does not resurrect deleted code

**Astra-07 retained: Low / DOCUMENTATION_GAP. No change to original source-migration disposition.**

**Fresh evidence:** directory read of `contracts/protocols/dexes/uniswap/` returns only `v2/` and `v4/`. Family README still states preserved V3/V4 at `contracts/vaults/standard/exchange/protocols/uniswap/README.md:3` and the old native SY self-call/context at `:56`.

**Authority:** FIX_PRD `:174–187` orders V3 deletion, caller/test retargeting and the local book. It does not authorize keeping the package because a README says it is preserved. The named FullSpread constructors and local-book checks were inspected and cited in Astra's original; no contrary surviving constructor evidence was offered by a peer.

**Agreement/objection:**

- Agree with MiniMax `:99–119` and Kimi `:59–79`: source closure and documentation residue are distinct.
- Agree with Grok `:92–106` that current-facing prose is wrong. Object only if his `PARTIALLY_EXECUTED` label is used to suggest the legacy V3 code or old constructor remains. It can describe incomplete documentation work, not failed deletion.
- I retain Low rather than Grok's Medium: operator/auditor mapping confusion is supported; restoration of obsolete vulnerable code is a hypothetical downstream consequence, not an observed execution path.

**Impact class:** documentation and source-map integrity. **Fix direction:** describe supported FullSpread V3, retained legacy V4 and immutable historical instances separately, and distinguish old validation artifacts from current implementation. Do not destroy historical evidence or reopen the deleted package. **Confidence:** high for README mismatch. Kimi's additional document citations were not independently re-read in this bounded cross-pass and are not adopted as new Astra findings.

## 3. RC-04 — present source checks, incomplete required regression

**Astra-05 retained: Low / TEST_DEFICIENCY. Source check matches; source-and-test acceptance remains partial.**

**Fresh facts:**

- V3 FullSpread Common `:281–284` rejects incomplete/unequal quoted output.
- Same file `:527–536` retains input ceiling and independently checks opposite pool output delta.
- OutExecuteTarget `:77–89` calls the quote check before pulling and before settlement.
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadExactOutputFill.t.sol:15–17` expressly disclaims post-swap short-fill coverage. Its negative `:48–69` expects an incomplete **quote** error; the positive `:73–99` checks a filled execution.

**Authority:** FIX_PRD `:215–217,231–233` requires both rejection points. Plan `:156` requires a production-path test for each acceptance list. Thus the missing second-boundary witness is part of acceptance, not merely optional extra coverage.

**Agreement/objection:** Agree with Grok's finding 3 and Kimi K3-04 on the concrete gap. Kimi's `CONFIRMED_EXECUTED` is defensible **only as source-check status**, not the whole source/test item; his own finding calls test acceptance incomplete. Object to MiniMax's `:153,157–159` unqualified closure based on quote rejection and positive settlement alone.

**Impact class:** settlement-regression evidence. No current short payout or defect in the new guard has been established. I retain Low, rather than Grok's Medium, because code checks are present and the established problem is the absent focused witness.

**Fix direction:** obtain a production-path witness distinguishing settlement output mismatch from quote rejection, or document a rigorously supported route impossibility and obtain acceptance of the alternative coverage. Do not change the quoter or unrelated families to force a case. Runtime remains unverified even for existing tests.

### Correction to Astra-08 — diagnostic observation, not an active repair defect

My original classified the retained input-ceiling misnomer as **Low / CODE_DEFECT**. I now reclassify it as **Informational / DOCUMENTATION_GAP (diagnostic naming observation)**, agreeing with Grok finding 4 and Kimi K3-05. The source fact remains: Common `:528–529` names an input-ceiling failure `UniswapV3Exchange_InsufficientOutput`. But FIX_PRD `:239` expressly preserves that existing error under RC-04, and no separately locked requirement for its rename was supplied. It should not count as a failed repair or new security defect.

Impact is diagnostic confusion only; any rename requires separate scope. The original record remains untouched and attributed.

**Important peer correction:** MiniMax `:47,154,223` conflates A-F01 with the input-ceiling misnomer or short-output fulfillment. A-F01 is **EOA versus credit-shortage error ordering**, a separate issue. RC-04's error-name non-goal neither fixes nor waives A-F01.

## 4. RC-06 — helper closure is not parent-path closure

### 4A. Narrow helper: agreement

I agree with all three originals on these facts at `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:625–637`:

- Successful actual-amount SE preview of zero is required for this helper's write.
- The write records full local balance.
- The one-share inverse quote is absent.
- Preview failure is not caught here.
- The probe catch returns false without a write **inside this helper**.

These match FIX_PRD `:294–305`. My original already stated this narrow no-defect conclusion. No reason was found to undo that source repair.

### 4B. Hook-zero semantics: retain Astra-03, sharpen origin labeling

**Astra-03 retained: Medium / CODE_DEFECT / Stage-1 REQ-01 integration nonconformance.**

**Fresh source facts:**

- `_entryJoinResidualAtomic` returns zero on hook preview zero at `Common:605,615`.
- Outer loops break on returned zero at `:565,590`, rather than rolling back.
- `_tryJoinResidual` can try another join mode at `:535–539`, or reach full-local-balance booking at `:543–545`.
- Focused RC-06 test `UniswapV4DetfLeftoverPreview.t.sol:53–77` asserts **nonzero SE preview**, **zero proportional hook preview**, then successful single-asset fallback. This is not the authorized SE-zero case.

**Requirement re-read:** related Stage-1 remediation PRD OD-08 `:184` and REQ-01 `:195,200` unambiguously require a hook preview of zero to roll back the parent without holder-reserve update. FIX_PRD does not withdraw that distinction.

**Agreement/objection:** Agree with Grok finding 5. Object to treating MiniMax `:197–201` or Kimi `:25,137` as closure of the **whole REQ-01/parent path**. They establish the helper's repaired predicate, not hook-zero rollback. MiniMax's reliance on the fallback-positive test actually highlights the conflicting behavior rather than resolving it.

**Clarification of my original relationship label:** Grok is right that the hook-zero site is not the specific inverse-quote expression targeted by RC-06. Call this **a separately locked Stage-1 obligation still contradicted in the repaired helper's callers**, not proof that the new helper predicate is wrong or that the RC-06 edit introduced the fallback. The assignment explicitly included callers and preservation of other invariants, so **overall RC-06 remains PARTIALLY_EXECUTED** even while its narrow predicate edit is confirmed.

**Impact class:** parent-operation atomicity / residual accounting policy, not demonstrated principal loss. **Fix direction:** make hook-zero behavior match the controlling rollback rule, or obtain a scoped owner amendment before treating fallback as accepted. Do not add catches or redesign unrelated DETF economics. **Confidence:** high in conflict; runtime and historical introduction unverified.

### 4C. Correction/narrowing to Astra-04 — failed probe versus independent zero evidence

The call-flow observation remains correct: after probe failure returns false from `:630–634`, `_pairQuoteIsZero` at `:559` or `:584` can independently obtain SE zero and cause its caller to book at `:532` or `:538`.

However, re-reading FIX_PRD `:296` alongside Stage-1 `:203` warrants a narrower classification than my original unconditional **Low / CODE_DEFECT**:

- The catch itself does not book.
- Subsequent booking in the observed alternate path still requires a **successful SE zero preview**; it is not booking solely because a probe failed.
- Stage-1 expressly excluded deciding the supportsInterface probe policy. FIX_PRD's wording names the existing catch locally, while the assignment's “supportsInterface failure must not book” can be read as a stronger caller-wide requirement.

I therefore retain the observation as **Low / DECISION_NEEDED on the breadth of that no-book requirement**, not as a proven violation of Stage-1's zero-preview invariant. If the assignment intends a failed probe to block every later retention path, the current callers do not enforce that stronger property. If only booking on the failed probe itself is forbidden, the helper conforms and a later genuine zero preview is independent evidence.

**Impact class:** requirement/negative-path interpretation. **Fix direction:** resolve the scope explicitly and test the accepted behavior, without inventing a new exception or catch. This correction does not weaken Astra-03: the hook-zero rule is explicit and independently broken. Confidence is high in control flow, bounded in the requirement interpretation and concrete-family reachability.

### 4D. Supported-interface test coverage remains incomplete

**Astra-06 retained: Low / TEST_DEFICIENCY.** The focused fixture asserts optional-interface support is false at `UniswapV4DetfLeftoverPreview.t.sol:35`; comments at `:13–15` accurately limit its proof. Its no-inverse-call assertion at `:109–112` cannot by itself distinguish the former supported-interface branch. Agree existing zero/nonzero/reverting-preview tests are useful; object to treating them as complete original-branch regression coverage.

Impact is branch-specific test adequacy, not a new production-money defect. Fix direction is supported-interface and accepted failed-probe production-path witnesses. Confidence high within this focused suite; repository-wide absence is not claimed.

## 5. A-F01 through D-X01 — authorization, source coverage and run evidence are three different questions

### Authority correction to peer interpretations

The current historical recurrence manifest was re-read: `docs/research/apex-stage2-review/recurrence-20261007/REVIEW_MANIFEST.md:5` expressly authorizes **tests, necessary verification harnesses and evidence generation** for that continuation, while excluding production fixes. This does not authorize any execution in this review session, but it is counterevidence to calling all recurrence additions “unauthorized” merely because FIX_PRD does not list them.

Accordingly:

1. **Agree** with all peers that no extra production remediation is authorized by absence from FIX_PRD.
2. **Object** to an inference that missing production-fix authorization prevents a verification test from addressing a historical assertion gap. Test-only deficiencies do not inherently require production edits.
3. **Object** to claiming the current gap persists unchanged solely because the old deficient file remains. A separate, valid production-path test can supply the missing assertion; the old tautology is still not evidence.
4. **Agree** that test text is not runtime closure or corrected acceptance mapping. “Not run by the October 7 author” is historical, not proof that no later run ever happened. With no causal current run chain assessed, the current runtime status is **UNVERIFIED**, not an asserted present-day “unrun.”

This corrects Kimi `:30–43,123–127` where “not FIX_PRD-authorized” becomes “unauthorized,” and Grok `:177` if read to dismiss current test evidence rather than distinguish it from a named production repair. MiniMax's blanket `:225` does not assess the substantive new tests. None of those limitations is evidence that their actual assertions are absent or wrong.

### Source disposition retained, with narrower closure language

The table below preserves the original Astra per-item conclusions. The cited sources were inspected during the independent pass; the main disputed conservation/campaign/Aave and error-order paths were additionally re-read in this cross-pass. **None is a claim of executed passing tests.** Paths are repository-relative; abbreviated filenames retain the exact family root stated in the row.

| Item | Source evidence and cross-review judgment | Severity / impact / fix direction |
|---|---|---|
| A-F01 | V3 `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:81–86` still checks shortage before Common `:867` caller guard. Agree Grok/Kimi; object to MiniMax's RC-04 conflation. **NOT_A_REMEDIATION; current source objective NOT_EXECUTED.** | Retain Astra-09 **Low CODE_DEFECT**, diagnostic ordering. Separately align ordering or record scoped acceptance; no unauthorized-credit loss alleged. |
| A-F02 | Wings `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/ApexRecurrenceExactErrors.t.sol:27–84,105–121` supplies exact callback/token/rollback assertions. Old bare reverts alone do not establish global missing coverage. **PARTIALLY_EXECUTED verification work**, not a new production repair. | Remaining complete mapping **UNVERIFIED**; no new production defect. Reconcile each named negative and source-bound results. |
| A-F03 | Same Wings root, `ApexRecurrenceInvariantWitness.t.sol:37–53` requires real funded lifecycle setup; `:56–60` permits counters to remain at setup values; `:76–83` is deterministic extra coverage. Object to preserving the original zero-setup-vacuity claim unchanged for this new suite. | Retain Astra-11 **Low TEST_DEFICIENCY**, narrower randomized progress/failure-classification gap. Define/report meaningful campaign action coverage; do not mandate every shrunk sequence succeed. |
| B-03 | `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_APEX_Recurrence.t.sol:28–90` contains actual custody callback-added-share and consumed-credit controls. **Missing assertion source addressed**, mapping/runtime not certified. | No defect found in those assertions. Correct acceptance mapping and bind execution; absence of FIX production authorization is not a coverage rebuttal. |
| B-04 | `test/foundry/spec/protocol/staking/etherfi/EtherFiWeETHStandardExchange_APEX_Recurrence.t.sol:19–68` has own-family sleeve/extreme-target controls in both modes. | No defect found in inspected assertions; evidence attribution/runtime remain unverified. Do not substitute Rocket or infer EtherFi edits under RC-05. |
| B-05 | `test/foundry/spec/vaults/standard/erc4626/behaviors/Behavior_ReceiptBackedERC4626_CrossInterface.sol:261–334` plus `ReceiptBackedERC4626_APEX_Recurrence.t.sol:12–35` in the parent test directory provide the missing operations and generic-over-Stata checks. | No defect found in inspected additions; verify actual hosts/artifacts/runs and mapping, not an invented adapter rewrite. |
| C-001 | `docs/plans/records/uniswap-v4-upper-lower-wings/CONSUMER_RESULTS.md:5–15` still discloses pending legal-mask coverage. **Exhaustive closure NOT_EXECUTED on disclosed evidence.** | Evidence/inventory gap, no new code defect. Resolve admitted denominator and source-bound coverage. |
| C-002 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_Apex008.t.sol:236–274` adds exact earlier-rejection and burn/allowance evidence. **PARTIALLY_EXECUTED verification.** | Requirement reconciliation remains; no missing operative cap vulnerability established. Do not reintroduce obsolete branches. |
| C-003 | Orbital D41 suite `:88–112`, weighted D41 `:72–95`, curve-quad D41 `:68–91` under their corresponding `test/foundry/spec/hooks/uniswap/v4/standardExchange/` roots now exercise selected dependency failure. **PARTIALLY_EXECUTED**, not “no change.” | Retain Astra-12 **Low TEST_DEFICIENCY**, differing successful projected-value assertion still absent in these cases. Add independent numerical discrimination per family. |
| C-004 | Morpho rate-provider test `test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchange_RateProvider.t.sol:67–120` and wrapped counterpart `test/foundry/spec/protocol/dexes/balancer/v3/WrappedStandardExchangeRateProvider.t.sol:152–189` now encode whole-supply/one-call semantics. | **UNVERIFIED** against later controlling rate design. Do not claim no additions or restore old bounded search without resolving authority. No new defect promoted here. |
| C-005 | Representative `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPool_D49.t.sol:37–69` adds real paused-dependency rollback/reopening; router handoff failures still injected at `:179–198`. Six additions located in first pass. | **PARTIALLY_EXECUTED** verification. Remaining real-auth/full-family proof unverified; preserve distinction between injected boundary tests and actual integration conditions. |
| C-006 | Wings recurrence conservation `:57–68` now captures independent balances and reconciles exact returned shares. Fresh re-read confirms it. Original FamilyConsumers `:59` remains tautological but is not the only witness. | Narrow missing conservation assertion **CONFIRMED_EXECUTED as source**; runtime/mapping unverified. Do not assert missing conservation globally from the old file alone. |
| C-007 | `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_Recurrence.t.sol:19–50` adds real unlock context, exact rejected caller and authorized positive. | Missing assertion source **CONFIRMED_EXECUTED**; runtime unverified. No new production guard indicated. |
| D-F01 / RC-07 | FIX_PRD `:18` ignores script repair; current `scripts/r12_selector_size_compare.py:43–47` is still bounded parent discovery. | **NOT_A_REMEDIATION** for script; REQ-08 closure unverified. Ignore does not establish size/selector evidence. Cannot certify historical non-edit without diff. |
| D-F02 | No current source/artifact/run chain was established by this session or the peers' cited historical material. | **UNVERIFIED** evidence closure. Preserve historical identity and obtain current causal evidence; no fabricated-run allegation. |
| D-F03 | See RC-06 above: helper predicate repaired, Stage-1 parent invariant not closed. | Astra-03 **Medium CODE_DEFECT** and Astra-06 **Low TEST_DEFICIENCY** retained; Astra-04 narrowed separately. |
| D-F04 | `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/adversarial/Adversarial_TrustFlags.t.sol:55–65` still mocks the manager query. Agree Grok/Kimi on named test. | Retain Astra-10 **Low TEST_DEFICIENCY**, production integration witness missing at cited site. Supply a genuine configuration witness or reconcile applicability. |
| D-X01 | Fresh re-read of `test/foundry/spec/protocol/lending/aave/cross-version/AaveCrossVersionLoop_APEX_Recurrence.t.sol:56–178` confirms initial/later/zero-cap, both debt legs, actual frozen-market rollback and nonunit-index boundary assertions. Old D43 still having two tests does not refute these additions. | Missing assertion source **CONFIRMED_EXECUTED** within inspected scope; full market setup/runtime unverified. Object to Kimi K3-07's persistence conclusion insofar as based only on the old file. |

These source-level acknowledgments do **not** turn the accepted report into a production implementation grant. Conversely, not having a production grant is not itself a defect in a verification-only test. The broad report remains partial because source coverage, applicability, mapping and runtime have different unresolved boundaries.

## 6. Preservation, corrections and unresolved dissent

### Earlier Astra findings

- **Retained:** Astra-01 ordinary V3 EOA rejection; Astra-02 legacy V4 self-call; Astra-03 hook-zero conflict; Astra-05 settlement test gap; Astra-06 supported-interface test gap; Astra-07 README mismatch; Astra-09 error order; Astra-10 manager mock; Astra-11 narrower campaign progress gap; Astra-12 numerical projection test gap.
- **Corrected here, not rewritten:** Astra-08 becomes Informational diagnostic documentation, not an active Low code defect against FIX_PRD.
- **Narrowed here, not rewritten:** Astra-04 becomes Low DECISION_NEEDED on caller-wide failed-probe semantics, while preserving its factual alternate-call-path observation.
- **Clarified origin:** Astra-03 is an unclosed Stage-1 integration requirement; no evidence establishes that the RC-06 predicate edit introduced it. Narrow helper success is acknowledged explicitly.
- **Status language clarified:** source assertion presence for verification additions is distinct from authorization to change production, corrected acceptance mapping, and actual test execution.

### Dissent preserved

1. MiniMax's RC-01 closure is contradicted by the actual typed external call and ordinary V3 composed path. No agreement is manufactured.
2. Grok/Kimi rate legacy V4 Medium; Astra retains Low absent demonstrated effect beyond mechanism nonconformance.
3. Grok rates README and settlement-witness gaps Medium; Astra retains Low for the established impact.
4. RC-04's headline differs among originals. All meaningful closure language must say source checks present, required settlement witness missing; Astra retains overall PARTIALLY_EXECUTED.
5. MiniMax/Kimi's RC-06 broad closure does not address the controlling hook-zero rollback sentence. Grok's helper-only closure is compatible with Astra's explicitly split judgment.
6. Failed-probe caller-wide policy remains an interpretation question, not something reviewer agreement can amend.
7. A claim that recurrence tests are unauthorized or cannot address test deficiencies solely because FIX_PRD omits them is rejected. Their current runtime execution nevertheless remains unverified.

### Limits and stop

No current immutable snapshot, baseline diff, or executed-artifact/run identity was established. Only disputed portions were re-read in this cross-pass; the original's full inventory and bounded inspection limits remain. No new whole-repository audit, deployment review or evidence campaign is implied. Peer source facts not rechecked or supported by the continuing session's original reads were not adopted as new Astra findings.

No defect was found in the re-read RC-04 fill-check expressions themselves, the re-read RC-06 helper's zero-preview/full-balance write, or the re-read replacement conservation assertions. That does not certify their unreviewed dependencies or runtime results.

**Return to coordinator/human and stop. One bounded cross-review completed; no loop, implementation, new remediation PRD or claim of four-member consensus.**
