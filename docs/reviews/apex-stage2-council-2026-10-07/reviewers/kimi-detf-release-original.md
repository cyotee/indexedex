# Kimi K3 — Independent first-pass review (ORIGINAL)

- **Reviewer:** Kimi K3 (kimi-code-plan-global/k3, variant high), assignment **D-detf-release**
- **Date:** 2026-10-07
- **Mode:** Inspection only. No builds, tests, shell execution, forks, RPC, code/test/config edits, or delegation were performed by this reviewer.
- **Snapshot (supplied, not recomputed):** IndexedEx `5709cb3507a9df72b11ec476d27b79ef88696c3a`, Crane `b35609951b4951a3c107e267e22844a50c4dc043`, content hash `82e1f83932a7149cacb7269cdcf90001541cc31306f54407e8037a6597eb5c32`, captured 2026-10-07T20:54:31Z (`docs/research/apex-stage2-review/recurrence-20261007/evidence/source-before-build.json`). `evidence/full-build.log` is not a completed build; `evidence/forge-version.txt` is a reported toolchain string only. No run is claimed by this review.
- **Controlling documents read:** `CLAUDE.md`; `docs/plans/APEX_STAGE2_REVIEW_PRD.md`; `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` (OD-01–OD-08, REQ-01–REQ-08); `STAGE1_EVIDENCE.md`; `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md` (D11–D69, R14.6/R14.7/R14.12, D15/D16/D22/D29/D30/D37/D43/D45 rows); `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md` (funded-staking/SY; residual references there concern the D15 claim-redeem reserve curve, a different concept from SE residual retention).
- **Audit PDF:** `docs/audits/APEX-IndexedEx-Audit-2026-09-17.pdf` **could not be read** (tooling cannot ingest PDF). All historical auditor allegations below are therefore **CLAIM_UNVERIFIED**; nothing about them is invented.

Applicability, inspection result, and execution-evidence state are kept independent throughout.

---

## 1. Findings

### K3-D-01 — REQ-01 continuity: supported-inverse branch books a holder reserve without a successful `previewExchangeIn` of zero (possible STAGE1_OPEN; owner decision required)

- **Class:** DECISION_NEEDED (with CODE/DOCUMENTATION mismatch characteristics)
- **Severity:** Medium · **Confidence:** Medium (code path certain; requirement interpretation contested)
- **File and line:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:649-653` (supported branch of `_retainSubSharePairResidual`, function at `:634-654`); booking callers at `:574` (`_joinResidualCapped`), `:599` (`_joinResidualUnbalanced`), `:661` (`_parkUnmintablePairDust`), `:693` (`_wrapAndParkPair`).
- **Intended behavior:** OD-01 item 1 as narrowed by OD-08 item 1: a successful Standard Exchange `previewExchangeIn` of `0` is the **only** book-and-wait signal; the leftover is booked to holders, the parent operation continues, nothing is paid to caller or fee recipient, and the SE deposit is not called after that zero. A hook preview of `0` or a hook join revert rolls the parent back. No new catch is authorized.
- **Broken requirement or invariant:** When the bound SE *does* support `IStandardExchangeExactOutputQuantityQuote`, `_retainSubSharePairResidual` retains (books the full pair balance to holders via `MultiAssetBasicVaultRepo._updateReserve` and defers the join) whenever `amount_ < quoteInputForExactShares(state, 1)` — i.e., on a successful **exact-output quote**, without any successful `previewExchangeIn` returning `0` on that path. Only the *unsupported*-inverse branch (`:641-645`) uses the sanctioned zero-preview signal. A supported inverse branch can therefore book a holder reserve without a successful Standard Exchange preview of zero — the precise question the assignment posed, answered **yes** on inspection.
- **Observed behavior:** As above. The `supportsInterface` `try/catch` at `:639-648` is the separate, expressly undecided site (REQ-01 non-goal; the withdrawn `beforeSwap` claim is not treated here as requiring a guard). Hook residual joins are now hard calls: `_joinResidualCapped:577` and `_joinResidualUnbalanced:602` invoke `joinResidualAtomic` via self-call with no `try/catch`, and `_entryJoinResidualAtomic:627` reverts `ResidualJoinUnavailable()` on `lpOut_ == 0`, so a hook zero/join failure rolls the parent back — that part of OD-08 **matches** on inspection. `_pairQuoteIsZero:670-675` is a direct view preview with no catch; a reverting preview reverts the caller (REQ-02 caller-side contract matches).
- **Impact class:** Residual accounting / requirement-conformance. No fund loss demonstrated. In any consistent SE, `amount < quoteInputForExactShares(state,1)` implies a zero-share `previewExchangeIn`, so the branch is functionally near-equivalent to the sanctioned signal; the deviation is that the prescribed check is never executed on this branch and a divergent SE implementation (exact-output quote disagreeing with preview) would be booked on the quote's word alone. Reverts of `quoteState`/`quoteInputForExactShares` propagate (hard calls), which is D37-strict, not a catch.
- **Counterevidence:** The NatSpec at `:630-633` describes this retention as intentional ("Retain only a proven sub-share input under the SE's current actual context… An explicitly unsupported inverse may use a successful zero-share deposit preview instead"). No owner amendment (OD-01–OD-08, or any D-series ruling I read) authorizes the exact-output-quote signal as a book-and-wait trigger, and DETF_ALIGNMENT_PRD.md's "residual" text concerns the D15 claim-redeem reserve curve, not SE residual retention. Whether this branch predates Stage 1 or was added during it cannot be determined by inspection alone (no history access authorized) — that sub-question is **unverified**. The stage-1 residual regression (`UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol:57-66`) asserts that any remaining booked amount must have a successful SE preview of zero, which is consistent with the sanctioned invariant but does not exercise a divergent-quote SE.
- **Readiness effect:** UNDETERMINED — requires an owner ruling: either ratify the exact-output-quote minimum as an equivalent book-and-wait signal for supported inverses, or require the supported branch to also/instead confirm a successful zero `previewExchangeIn`. This is recorded as a **REQ-01 continuity** matter (possible STAGE1_OPEN), not a new ID erasing REQ-01.
- **Fix direction (prose):** Obtain an owner decision. If the current signal is ratified, record it as an explicit amendment attached to REQ-01/OD-01 and document it at the function. If not, align the supported branch so that retention occurs only after a successful Standard Exchange `previewExchangeIn` of zero for the same amount, keeping all dependency calls hard (no new catch), and extend the residual regression with a supported-inverse case.
- **Stage-1 relationship:** REQ-01 (OD-01/OD-08) continuity; possible STAGE1_OPEN.

### K3-D-02 — REQ-08 continuity: stage-1 selector/size compare universe excludes the replacement Hookless, Pons-family, and Wings packages

- **Class:** EVIDENCE_GAP
- **Severity:** Medium · **Confidence:** High
- **File and line:** `scripts/r12_selector_size_compare.py:44-63` (`discover_artifacts` scans only parent directories of **live** baseline rows, non-recursively via `parent.glob('*.sol')`); supplied artifact `docs/reviews/apex-2026-09-17-second-audit-readiness/selector-size-compare-stage1-current.json` (`skippedStaleCount: 32`, `newArtifactCount: 7`).
- **Intended behavior:** REQ-08 (R1.3/R12, OD-05, OD-08 item 3): selector/size evidence regenerated against the current tree must cover the current FullSpread V4 packages — the hookless and Pons-family split — and, per the stage-1 scope, the wings vault; the stage-1 note itself says "The hookless and Pons-family packages above replace that citation."
- **Broken requirement or invariant:** All 32 stale baseline rows are the pre-split `contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVault*` sources (verified in the artifact's `skippedStale` list and the baseline `initial-artifact-selectors-sizes.json`). Because no **live** baseline row has that directory as parent, `discover_artifacts` never scans it; and because discovery is non-recursive, it could never descend into `fullSpread/hookless/`, `fullSpread/ponsFamilyV2Hook/`, or `upperLowerWings/` in any case. The compare's `newArtifacts` contain 7 units (curve-quad `LiquidityFacetExt`, weighted `LiquidityFacetExt`, Slipstream `InFacetExt`, Balancer transition-quote facet, Aave cross-version transition-quote facet, `ERC4626StandardExchangeInFacetExt`, `ReceiptBackedERC4626Facet`) — **none** from the three replacement package directories, each of which contains concrete deployable units (`UniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.sol`, `UniswapV4FullSpreadPonsFamilyHookDFPkg.sol`, `UniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol`, plus their facets/delegates).
- **Observed behavior:** The stage-1 run exited 0 with `oversizeCount: 0`, but that result cannot say anything about the runtime sizes or selector sets of the replacement hookless, Pons-family, or wings packages. The assignment's question — are the replacement directories inside the scanned universe — is answered **no**.
- **Impact class:** Provenance / release-evidence sufficiency. No code defect implied in the packages themselves; the EIP-170 and selector status of the replacement packages is simply unattested by this artifact.
- **Counterevidence:** None found. The note in the artifact ("Not audit submission… Labels do not certify installed proxy cuts") is candid but does not disclose the universe exclusion; STAGE1_EVIDENCE.md's "replace that citation" sentence overstates the artifact's coverage.
- **Readiness effect:** BLOCKS the specific closure claim that stage-1 selector/size evidence covers the current FullSpread V4 replacement packages and wings. Stage-1 owner acceptance (2026-10-07) is recorded; this is a factual gap the owner should see, not a reopening of that acceptance by this reviewer. REQ-08 continuity; possible STAGE1_OPEN.
- **Fix direction (prose):** Extend the comparison's discovery universe so new package directories introduced after the baseline (the `uniswap/v4` subtree including `fullSpread/hookless`, `fullSpread/ponsFamilyV2Hook`, `upperLowerWings`) are scanned — e.g., recursive discovery or explicit supplemental roots — and regenerate a source-bound compare that names every current replacement unit; correct the STAGE1_EVIDENCE wording so it does not imply the current artifact covered those packages.
- **Stage-1 relationship:** REQ-08 continuity.

### K3-D-03 — Stage-1 named-pass evidence is narrative without source-bound provenance

- **Class:** EVIDENCE_GAP
- **Severity:** Low · **Confidence:** High
- **File and line:** `docs/reviews/apex-2026-09-17-second-audit-readiness/STAGE1_EVIDENCE.md:30-43` ("Runs that passed"), `:8` ("Tree: `5709cb35` plus uncommitted stage-1 edits. This note is not a release identity.").
- **Intended behavior:** S2-REQ-09 / REQ-08: relied-upon execution artifacts record path, origin, source identity, command as reported, toolchain, test selection, outcome, and limitations. A narrative pass without command log, toolchain, and source identity is not SUPPLIED_SOURCE_BOUND.
- **Observed behavior:** The named passes (custody, receipt cap, rate provider, residual sweep, outside-trade credit, matrix rounding controls) are listed as test names with a general command shape but no per-run logs, no toolchain version, and a tree description that explicitly includes unspecified uncommitted edits and disclaims release identity. No `--manifest` output exists beside the stage-1 compare in this directory. The named test functions do exist in the current tree (verified for the residual sweep, custody adversarial, rate-provider, maxRedeem behavior, and the four outside-trade tests), so this is a provenance gap, not a missing-test claim.
- **Impact class:** Evidence sufficiency. Supplied outcome: UNKNOWN (not rerun; no log to inspect).
- **Counterevidence:** The note is self-limiting ("Stage 1 passing is not audit submission"; "No matrix row count is recorded").
- **Readiness effect:** DOES_NOT_BLOCK inspection conclusions; BLOCKS any representation of these runs as SUPPLIED_SOURCE_BOUND. Classification: **INCOMPLETE_PROVENANCE**.
- **Fix direction (prose):** In a separately authorized verification session, rerun the named tests against an identified tree and bind logs, toolchain, and content identity (the existing script's `--manifest`/`--test-log` mechanism is designed for this).
- **Stage-1 relationship:** REQ-08 / OD-08 item 3 evidence quality.

### K3-D-04 — R14.7 residual: no withdrawal/preview-consistency assertion from the leveraged partial position (minor)

- **Class:** TEST_DEFICIENCY
- **Severity:** Low · **Confidence:** Low–Medium
- **File and line:** `test/foundry/spec/protocol/lending/aave/cross-version/AaveCrossVersionLoop_APEX_D43.t.sol:97-110`; `test/foundry/spec/protocol/lending/aave/cross-version/AaveCrossVersionLoop_APEX_Recurrence.t.sol:78-92`.
- **Intended behavior:** R14.7 (original plan line 614) includes "Assert current share previews, local/position NAV and supported withdrawals remain consistent for the retained partial position."
- **Observed behavior:** The R14.7 matrix is otherwise substantially present on inspection: zero initial capacity (fresh vault and booked-principal NAV/local-first-exit/sweep, `AaveCrossVersionLoop_APEX_D43.t.sol:114-139`, `AaveCrossVersionLoop_APEX_Recurrence.t.sol:65-75`); capacity exactly equal to initial supply (`:55-62`); the locked 100/150 later-iteration case with exact leg numerics, both collateral/debt legs, no idle borrowed tokenA, principal-only share issuance (`:78-92`); non-unit liquidity index cap boundary (`:136-160`); reserve sweep consuming reopened finite capacity before the new caller (`:121-133`); and a pinned `ISpoke.ReserveFrozen` dependency failure after V3 progress asserting complete rollback of transfers, allowances, positions, debt, and shares (`:95-118`). The one element I did not find is a withdrawal or preview-consistency check exercised **from the leveraged partial position** itself (cap reached in a later iteration); the NAV/local-first exit assertions are made in the zero-capacity (unleveraged retained principal) scenario instead. Per the assignment, this is raised strictly as a test-coverage question; nothing here suggests the executor is wrong.
- **Impact class:** Coverage completeness for one R14.7 sub-assertion.
- **Counterevidence:** The leveraged-partial-position tests do assert supplied/debt/no-idle invariants and health factor; a withdrawal path from that state may be covered in suites I did not read (see coverage-not-inspected).
- **Readiness effect:** DOES_NOT_BLOCK by itself; the larger R14.7 execution-evidence state is **MISSING** (these tests are not in the supplied stage-1 named-pass set; historical follow-up claims are HISTORICAL_ONLY).
- **Fix direction (prose):** Add (or cite, if it exists elsewhere) a control that redeems/withdraws and previews from the cap-truncated leveraged position and reconciles local plus position NAV.
- **Stage-1 relationship:** None (original-program R14.7 continuity).

---

## 2. Claim dispositions (assignment items 1–6)

| # | Claim | Disposition |
|---|-------|-------------|
| 1 | REQ-01/OD-08 residual retention | **Confirmed in part, one open conflict.** Hard-call joins and zero-preview-only `_pairQuoteIsZero` match OD-08. The supported-inverse branch in `_retainSubSharePairResidual` (`:649-653`) **can** book a holder reserve without a successful `previewExchangeIn` of zero — recorded as K3-D-01 (possible STAGE1_OPEN under REQ-01, not a new ID). Comments describe the retention as intentional; no owner amendment authorizes the alternate signal. The `supportsInterface` catch (`:639-648`) is the separate undecided site; no new guard is inferred from the withdrawn `beforeSwap` claim. |
| 2 | REQ-02 direct residual preview | **Confirmed compliant on inspection.** `previewResidualBuffer` (`UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:246-251`) is a direct `previewExchangeIn` return, no catch. Callers (`_pairQuoteIsZero`, DETF sweep paths) treat a returned zero as local retention and do not translate reverts into zero. No holder-reserve sweep was invented or found. Regression tests exist (`UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol`) asserting hook-zero rollback books nothing and pays neither caller nor fee recipient. |
| 3 | REQ-08 selector-size universe | **Refuted.** Replacement Hookless, Pons-family, and Wings directories are **not** inside the scanned universe (K3-D-02). Script not rerun; conclusion from script source plus the supplied artifact's own `skippedStale`/`newArtifacts` contents. |
| 4 | Evidence provenance | Named passes in STAGE1_EVIDENCE.md: **INCOMPLETE_PROVENANCE**, supplied outcome UNKNOWN (K3-D-03). `selector-size-compare-stage1-current.json`: **INCOMPLETE_PROVENANCE** (no bound manifest; universe gap per K3-D-02). Earlier `selector-size-compare-stage1*.json` in that directory: **HISTORICAL_ONLY** (self-declared stale). `evidence/full-build.log`: **INCOMPLETE_PROVENANCE** (not a completed build). `evidence/forge-version.txt`: toolchain string, not a result. Historical 34,909/33-campaign/37-fuzz and 195/1/7 vs 165/3/7 counts: **HISTORICAL_ONLY**, not inherited. `source-before-build.json`: source identity only, not execution evidence. |
| 5 | Aave cross-version partial-position coverage vs R14.7/D43 | Coverage **substantially present** on inspection (zero-capacity, exact-capacity, later-iteration 100/150 exact numerics with both legs, non-unit index, sweep-before-caller, pinned `ReserveFrozen` rollback after progress). One minor residual as K3-D-04. The executor's correctness is **not** adjudicated here. Execution evidence for these suites: **MISSING** in the supplied stage-1 set. |
| 6 | Audit-item mapping | The audit PDF could not be read; every historical allegation below is **CLAIM_UNVERIFIED** (current-source mappings noted separately, kept distinct from historical status). |

### Audit-item table (historical status vs current mapping)

| Audit item | Historical claim | Current-source mapping (inspection, not execution) |
|---|---|---|
| APEX-2026-001-M | CLAIM_UNVERIFIED | Old stored-total vault source removed per OD-04; four outside-trade credit tests exist by name (V3, V4 hookless, V4 Pons-family, wings). Bodies not fully inspected by this lane; execution evidence INCOMPLETE_PROVENANCE. |
| APEX-2026-001-M2 | CLAIM_UNVERIFIED | Documentary inventory matter; no fresh chain inventory performed or authorized. |
| APEX-2026-003 | CLAIM_UNVERIFIED | Current custody guard present; REQ-03's mis-aimed ownership test is repaired on inspection (contract caller, exact `TransferDeltaInsufficient(shares, 0)`, unchanged-shares/reserve assertions — `RebasingAwareERC4626_Adversarial.t.sol:50-61`). |
| APEX-2026-008 | CLAIM_UNVERIFIED | Orbital operation-scoped refund sites not inspected by this lane (seam: shared-credit/hooks lane). |
| APEX-2026-009 | CLAIM_UNVERIFIED | Morpho/ERC-4626 burn-refund routes not re-read by this lane. |
| APEX-2026-004B | CLAIM_UNVERIFIED | Replacement residual booking inspected in `UniswapV4DetfCommon.sol` (book-and-wait present; see K3-D-01 for the signal conflict). |
| APEX-2026-005 | CLAIM_UNVERIFIED | `LocalCreditLib` consumers spot-checked: prepaid/exact-output paths in `MixedBufferMultiVaultStableDetfExchangeQueryTarget.sol:63-76` (budget, `TransferDeltaInsufficient`, msg.sender refund of `credit_ - amount_`, post-operation reserve sync), `StakedDETFTarget.sol:201-204` (EOA gate then hard true-flag reject), `DETFFundedBondTarget.sol:399-405` (donate prepaid guard), `MultiVaultWeightedDetfCommon.sol:241-258` (`_pullToken`/`_requirePrepaidCaller` guards). Consistent with D11/D15 on the paths read; full consumer inventory not re-derived. |
| `beforeSwap` retraction | CLAIM_UNVERIFIED | No missing-guard finding invented; the DETF `supportsInterface` catch is treated strictly as the previously flagged undecided site. |
| Weighted dust retraction | CLAIM_UNVERIFIED | Matrix rounding-control repair asserted in STAGE1_EVIDENCE.md; behavior files not re-inspected by this lane (seam: matrix lane). |

---

## 3. Stage-1 REQ continuity summary (inspection only)

| REQ | Inspection result | Basis |
|---|---|---|
| REQ-01 | **CONTRADICTS (narrow)** — K3-D-01 | Supported-inverse retention signal not the sanctioned zero preview. Other OD-08 elements match. |
| REQ-02 | MATCHES | Direct preview at ClaimLib `:246-251`; caller zero/revert split in `UniswapV4DetfCommon.sol`. |
| REQ-03 | MATCHES (paths read) | `RebasingAwareERC4626_Adversarial.t.sol:50-61` now reaches the share-accounting condition with exact error and state assertions. Scanner scope not re-inspected. |
| REQ-04 | NOT_ASSESSED | Matrix behavior files not re-read this lane. |
| REQ-05 | MATCHES (existence) | Four `test_outsidePoolTradeDoesNotRefreshVaultBook` tests exist (V3 `_FeeCompound.t.sol:50`; hookless `AttributionAndBooking.t.sol:34`; ponsFamilyV2Hook `AttributionAndBooking.t.sol:37`; wings `...VaultMoney.t.sol:26`). Bodies not fully inspected. |
| REQ-06 | MATCHES | `ReceiptBackedERC4626Target.sol:67-81`: `maxWithdraw = previewRedeem(maxRedeem(owner))`; `maxRedeem` is a share cap with `_largestRedeemableShares` fallback; tests exist in `Behavior_ReceiptBackedERC4626_CrossInterface.sol:172-216`. |
| REQ-07 | MATCHES | `StandardExchangeRateProviderFacet.sol:61-92`: empty-state path uses live `totalSupply()` + `_safePreviewExchangeIn`; no `quoteState` call, no `gasleft()` branch; caller-supplied state retained via `quoteRate:49-59`. `test_emptyGetRate_ignoresQuoteStateFailure` exists. |
| REQ-08 | **CONTRADICTS (evidence)** — K3-D-02, K3-D-03 | Replacement packages outside compare universe; named passes lack bound provenance. |

---

## 4. Coverage inspected

- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol` (`_tryJoinResidual`, `_joinResidualCapped`, `_joinResidualUnbalanced`, `_entryJoinResidualAtomic`, `_retainSubSharePairResidual`, `_parkUnmintablePairDust`, `_pairQuoteIsZero`, `_parkResidualOnHook`, `_wrapAndParkPair`, `_entrySweepPairToShare`, `_sweepDustBody`).
- `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:220-279`.
- `scripts/r12_selector_size_compare.py` (full); baseline `initial-artifact-selectors-sizes.json` (Uniswap rows); supplied `selector-size-compare-stage1-current.json` (full).
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol` (full).
- `test/foundry/spec/protocol/lending/aave/cross-version/AaveCrossVersionLoop_APEX_D43.t.sol`, `AaveCrossVersionLoop_APEX_Recurrence.t.sol` (full).
- `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol:38-127`.
- `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol:50-169`; `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:40-119`.
- DETF consumer spot checks: `MixedBufferMultiVaultStableDetfExchangeQueryTarget.sol:40-79`, `StakedDETFTarget.sol:160-229`, `DETFFundedBondTarget.sol:370-419`, `MultiVaultWeightedDetfCommon.sol:241-258`, `IMultiVaultWeightedDetfBonding.sol` NatSpec.
- Production `try`/`catch` sweep across `contracts/vaults/detf/**`: only remaining production site is the `supportsInterface` probe in `UniswapV4DetfCommon.sol:639-648`; other matches are TestBase/fixture scaffolding.
- Controlling documents listed in the header.

**No defect found in the following inspected areas:** REQ-02 preview path; REQ-03 custody test repair (paths read); REQ-06 share-cap direction; REQ-07 empty-state rate path; hard-call residual joins and zero-preview-only `_pairQuoteIsZero` (the OD-08-conformant portion of REQ-01); D15/D32 guards on the DETF prepaid/donate/stake paths read; R14.7 Aave test matrix except the K3-D-04 residual.

## 5. Coverage not inspected (this lane)

- REQ-04 matrix behavior files (seven families) and the wider bare-`expectRevert` scanner inventory (STAGE1_EVIDENCE itself records the scanner still exits 1 on the wider inventory — pre-existing open item, not a new finding).
- Bodies of the four outside-trade tests (existence only).
- Single/multi-vault/composed/rebasing DETF family exchange internals beyond the spot checks above; `RebasingDETFTokenTarget.redeem`/`burnShares` bodies; bond vesting/economics (expressly out of scope).
- Orbital refund sites (APEX-2026-008), Morpho burn sites (APEX-2026-009), Stata routes, Lido/Rocket/EtherFi prechecks, Balancer D68/D69 quotes, hook × SE matrix rows, deployment/registry surfaces beyond the compare artifact.
- Slipstream (deprecated inventory only, per ruling).
- Historical prior-wave claims under `docs/research/apex-stage2-review/` were not relied upon.

## 6. Seams needing another lane

- `_wrapAndParkPair` / `_parkResidualOnHook` move balances (wrap pair→SE shares; transfer SE shares to the hook) without a local `_updateReserve`; direction appears conservative (book stays high while custody falls), but reconciliation of book-vs-custody on these last-resort paths belongs to the shared-credit/custody lane.
- Whether the `_retainSubSharePairResidual` supported-inverse branch predates or postdates Stage 1 (requires history access not authorized here).
- Orbital five-site execution coverage; full LocalCreditLib consumer inventory; wings and FullSpread package internals (assigned to other lanes).

## 7. Limitations

- No execution: nothing was built, tested, or rerun; all "matches" are source-inspection results, not runtime passes.
- The audit PDF was unreadable with available tooling; all historical auditor allegations are CLAIM_UNVERIFIED and no allegation text was reconstructed from secondary summaries.
- Snapshot identity was supplied, not recomputed; tree drift after 2026-10-07T20:54:31Z would stale these conclusions.
- Stage-1 owner acceptance (2026-10-07) is recorded in STAGE1_EVIDENCE.md; findings K3-D-01 and K3-D-02 are factual continuity items for the owner, not a unilateral reopening of that acceptance.
