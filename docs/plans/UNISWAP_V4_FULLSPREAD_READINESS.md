# FullSpread audit-submission readiness — draft

**2026-09-30 — DRAFT, final QA and owner retirement gate pending.** G1–G6 implementations and their scoped closure tests have passing evidence. This is a readiness checklist for the completed work and final validation, not audit completion, a security guarantee, or source-removal authorization.

Normative references: [PRD §3.1 / §13](UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md), [implementation/test plan](UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md), [finite removal manifest](UNISWAP_V4_FULLSPREAD_REMOVAL_MANIFEST.md), and the reconciled [assertion acceptance map](UNISWAP_V4_FULLSPREAD_ACCEPTANCE_MAP.md).

## 1. Source identity

| Field | Current record |
|---|---|
| Observed repository HEAD / tracked baseline | `b019f232a1a109868da81be2d81f94d00a8a0be7` |
| Replacement implementation identity | **Dirty/untracked working tree** over that baseline; HEAD is not its immutable identity. |
| Final source manifest / archival revision | Pending collection and durable preservation by parent. Include H/P, shared pure helpers, consumers, tests, scripts and relevant Crane dependency state. |
| Final source-to-artifact/runtime manifest | Pending final qualification after native DFPkg and F6 changes. |
| Post-removal revision | Not created; retirement has not been authorized by this record. |

The two new implementations remain separately compiled under
`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/{hookless,ponsFamilyV2Hook}/`.
H/P economic quote, execution, callback and maintenance orchestration stay separate;
the plan's approved pure/generic reuse remains the boundary. No runtime-bytecode
equivalence prerequisite is added for Pons: the owner's accepted documentation and
graduated-pool evidence remain sufficient integration evidence under D29.

## 2. Completed scoped closure

| Work | Source/assertion closure | Executed evidence qualification |
|---|---|---|
| G1 contextual EO | All six AMMs: Single-CP, Dual-CP, Weighted, Orbital, CurveQuad, BalancerQuad. Idle PM preview projects the upcoming same-manager blocked state; exact router input/output, nonunit rates, actual shares, no nested unlock/stranded deltas, appropriate two-leg rejection and foreign context. Natural-linear output tests separately prove independent share burn/cover/budget boundaries. | Parent reports **78 same-manager + 14 linear** green. Acceptance map names actual tests and contexts. |
| G2 independent terminal maintenance | Independent base-2^32 rational/price metric, executed restored-core placement baseline and separately labelled predictive registry-proxy baseline. Actual terminal costs/fees/removal/placement, useful partial progress/repeats, stop bands, no reward/issuance, complete book. | **16 core + 7 registry** green, retained focused logs below. Old production-comparator optimization test is not counted as independent proof. |
| G3 route/funding | Eight definitions /16 H/P instances: actual blocked EI negative, first blocked activation, F1 restored pull/push, F3 and natural-linear full budget matrices, each local leg shortage, malformed/missing vector credit and both-face SY aliases. | Included in **436-family/128** checkpoint. Old6-pass/10-fail allowance record is superseded. |
| G4 import/deploy/native/TWAP |14 definitions per family: actual NFT trust/funding/fees/minimum/approvals/core checkpoints/SY lifecycle, exact package/registry/salts, native order/discovery, actual launch replay, oracle observation and fault/mutable-advertisement rollback. | Latest **28/28 green**, including final native DFPkg correction and all enhancements. |
| G5 guard/history |14 definitions per family, real FoT/callbacks/permit/guards/disable/retry/self-share isolation;48-step3-actor credit fuzz plus persistent mixed money/reentry histories. All24 old handler **predicates** explicitly mapped with independent economics retained in C32/G3/G6. | Enhanced **28 G5 instances green** in66 selection, but actual fuzz lines are **16**. Final128 rerun pending; old128 run predates enhancements. |
| G6 transition/lifecycle/F6 partial | Both terminal-partial faces with independently exact residual cash, full fields/claims, late minimum rollback, already-at-limit full retention, full-range lifecycle, strict direct-EI control and nonterminal64-step rejection. Family-local production correction completed. | **16 lifecycle + 2 work-limit** green; lifecycle log directly checked, work-limit result parent-reported. Parent reports bounded independent security PASS. |

### Authorized corrections preserved in the handoff

- **Native contents identity:** both DFPkgs hash a freshly allocated sorted token
  copy for registry contentsId, while original PoolKey face order remains in
  storage/config/names/approvals. Both token permutations discover the actual vault.
  PoolKey, arguments, component/package salts and instance salt derivation are
  unchanged. This affects new deployments, not existing package/proxy upgrades.
- **F6 partial conversion:** only redemption's forward quote accepts actual terminal
  price-limit partial fill or already-at-limit no-conversion. It retains/bookkeeps
  unspent opposing entitlement and verifies actual consumed input/net output/core
  terminal state. Ordinary/direct forward calls remain strict; no work-cap reduction,
  two-leg EO inverse, relaxed protection or cross-family dispatcher was introduced.
- **TWAP:** F is the selected baseline. Its propagating update failure is preserved
  and now validated with actual rollback after genuine oracle update. O's conflicting
  fail-open success is specifically superseded, not a new owner-policy question.
- **Own-share authorization:** owner-confirmed current holder exit debits caller's
  own shares without a vault allowance. Third-party ERC20 pulls still require
  approval; booked self-shares and SY context remain isolated and tested.

## 3. Evidence ledger and ordering

Tool-output root: `/Users/cyotee/.local/share/opencode/tool-output/`.
Temporary root: `/var/folders/28/y_7zd8pd2sl_jtwdj8y7hbb00000gn/T/opencode/`.

| Evidence | Result | What it cannot certify |
|---|---|---|
| `tool_0f28e99a80017hutLncSKOzlpl` |436 passed,0 failed/skipped,89 suites; fuzz128 | Final native DFPkg fix and subsequent test enhancements. |
| `tool_0f2ac962b001saQBFZEqpb2RyO` |66 passed: G5(14×2), G6 lifecycle(8×2), then-current G4(11×2); G5 fuzz16 | Latest G4 extra6 cases or refreshed128 G5 histories. |
| `tool_0f2c329e50011839URdKreiEXa` |28 passed,0 failed/skipped; latest G4 | Whole final family/consumer gate. |
| `tool_0f21c621b001ItRzzIYg3Q1Fl3` |12,050 passed,0 failed/skipped,482 prod-SE suites | Post-F6 consumer behavior. Parent's fresh broad run is pending at this handoff. |
| `fullspread-maintenance-observed-final.log` |16 independent core controls passed | Universal liveness or every fixture dimension. |
| `fullspread-registry-maintenance-observed.log` |7 independent public-proxy controls passed | Final current-source artifact/consumer certification. |
| Parent G1/work-limit/security results |78+14 contextual EO,2 work-limit, bounded F6 security PASS | A fabricated log ID/source manifest or whole-protocol audit approval. Attach their durable evidence to final bundle. |

**Expected final family count:450.** This is a pending selection expectation,
not450 executed passes. Focused selections overlap; their totals must not be added
to436 as if they were disjoint. The older315 and12,044/5 checkpoints remain historical
and do not override the later results or certify the final changed source.

## 4. Exact remaining pre-retirement requirements

### A. Final validation already owned by parent

- [ ] Collect the refreshed final family result with **128 fuzz runs**, expected450
  before any additional predicate test, including the latest G4/G5/G6 additions.
  If the selection count differs, reconcile actual discovered tests rather than
  forcing the expected number. Retain compiler/test exit codes and exact commands.
- [ ] Collect the fresh **post-F6 broad prod-SE** result. The12,050 checkpoint is
  green for its prior source; do not mark the ongoing run passed or failed early.
- [ ] Qualify H/P and affected consumer runtimes/source identities against final
  artifacts, including the tight OutFacet and consumer margins, linked libraries,
  package metadata and changed loader/script dependencies. Preserve existing gas
  and work bounds. Collect final combined QA/review disposition for that source.

These are final evidence collection gates, not requests to reopen completed G1–G6
engineering or start concurrent builds. This docs task invokes no compilation.

### B. Two retained exact legacy predicates to finish mapping

The acceptance map narrows the original large unresolved list to:

- [ ] **L1, intentional unbalanced Multi:** positive live dual join, both declared
  payments/no refund, proportional issuance and retained excess booked; includes
  the shared one-excess-pushed-leg predicate. Balanced funding, scalar surplus and
  malformed-vector negatives do not by themselves demonstrate that actual case.
- [ ] **L2, exact SY return values:** old FullRangeBook metadata/rate assertion
  (`yieldToken`, liquidity assetInfo manager/decimals, observed whole-book geometric
  exchangeRate). Current Admission calls these getters but does not compare the
  returned values; provider-rate tests concern a different API.

First locate a current exact assertion or record an explicit valid supersession;
only add the narrowly missing predicate if needed. These are preservation gaps,
not demonstrated contract defects. No new all-decimal/native Cartesian product,
literal24-action handler, or exact64th-step terminal-success fixture is required.

### C. Preservation, dependency closure and owner checkpoint

- [ ] Preserve final dirty/untracked implementation/tests and historical candidate
  evidence in a durable revision/manifest bundle; baseline HEAD alone is insufficient.
- [ ] Re-enumerate the finite manifest and final active source/test/script/artifact
  dependencies. Maintained consumers stay on explicit H/P; legacy release/adversarial/
  invariant adapters and old aggregate imports receive their documented disposition.
  Preserve shared V3 behaviors/providers and maintained Pons/DETF imports.
- [ ] Record the **owner's determination of readiness for security-audit submission
  and permission to proceed with the gated retirement**, referencing the final
  evidence. Audit completion is not required, and readiness is not a security guarantee.

## 5. After the owner gate — not performed

1. Apply only the manifest's **80 Solidity +6 historical-document** retirement set
   and explicitly disposition obsolete compilation roots/references. Both complete
   new-family subtrees are unconditional exclusions. Preserve parent shared math,
   V3, Crane V4/Pons/network sources, unrelated metadata and all live deployments.
2. Verify no maintained import, artifact lookup or aggregate build path depends on
   removed types. Shared adversarial/invariant files with V3 users stay maintained.
3. Refresh final post-removal artifacts and run required replacement/consumer
   regressions on that final revision. Record runtime identities/results and use
   **that revision**, not only a pre-removal green tree, in the audit handoff.

**Current decision: keep retirement blocked pending §4.** No source deletion,
deployment, live registry action or migration is authorized by this draft.
