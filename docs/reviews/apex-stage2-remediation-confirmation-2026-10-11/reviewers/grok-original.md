# Grok original — APEX Stage 2 remediation confirmation

- **Reviewer:** Grok (`xai/grok-4.7`), independent first pass. Not the coordinator. No peer original from this round was opened.
- **Date:** 2026-10-11
- **Question:** Are the APEX Stage 2 remediations correctly specified, and does the current tree execute them?
- **Method:** Source and test inspection only. No Forge, shell, build, or deployment. Historical reports are claims, not proof. Passing-test claims were not rerun.
- **Controlling repair spec:** `docs/reviews/apex-stage2-council-2026-10-07/FIX_PRD.md`, as elaborated by `FIX_PRD.plan.md`. Where that file withdraws an earlier draft, the withdrawal controls. The Stage 2 review PRD and the accepted inspection report do not authorize production fixes. FIX_PRD itself says writing it does not authorize editing. This review judges the tree against that later specification; it does not treat the specification as a new implementation grant.

## Session limitations

- Crane testing skill body under `lib/crane/.claude/skills/crane-testing/` was not re-read in full. IndexedEx testing and adversarial skills, and `docs/agent/SKILL_CATALOG.md`, were read and used as the production-path / exact-assertion bar.
- A repository search listing included the path of another reviewer's file under this round's output directory. That file was not opened. Its name is not a finding.
- No git diff was available. "Not edited" claims are inferences from current text, not a diff against the pre-repair tree.
- Runtime execution of the new tests is **UNVERIFIED**.

## Authority used

| Document | Role in this review |
| --- | --- |
| `docs/plans/APEX_STAGE2_REVIEW_PRD.md` and `.plan.md` | Review program. Not a fix authorization. |
| `docs/research/apex-stage2-review/accepted-20261007/REPORT.md` and `REVIEW_MANIFEST.md` | Historical findings and corrective objectives. Report says implementation is not authorized. |
| `docs/research/apex-stage2-review/recurrence-20261007/REVIEW_MANIFEST.md`, `A-vaults-review.md`, `B-credit-lending.md` | Historical claim that production was not repaired and new tests were not run by those reviewers. Re-checked against the current tree; not treated as proof of the current tree. |
| `docs/reviews/apex-stage2-council-2026-10-07/REMEDIATION_PRD.md` | Earlier draft. Superseded where FIX_PRD records a correction. |
| `docs/reviews/apex-stage2-council-2026-10-07/FIX_PRD.md` and `.plan.md` | Later repair specification to test against. |
| `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` | REQ-01 / OD-08 and REQ-08 continuity only. |

Recorded spec corrections, not silently preferred:

- **RC-01:** Earlier draft kept the external self-call and added a caller check in front of it. FIX_PRD withdraws that repair. The self-call is the design error. The EOA check remains, but it is not a reason to keep the call.
- **RC-03:** Earlier draft left an owner choice to patch or stop constructing the old V3 package. FIX_PRD withdraws the patch. Delete `contracts/protocols/dexes/uniswap/v3` and retarget named callers to V3 FullSpread. Do not delete `contracts/protocols/dexes/uniswap/v4`.
- **RC-05:** Earlier draft said a skipped book must never be combined with a later credit. FIX_PRD withdraws that. Small credits accumulate in the liquid sleeve. Deposit only excess over the configured sleeve when that excess meets the Rocket minimum. This matches the family rule at `ROCKET_POOL_RETH_STANDARD_EXCHANGE_VAULT_PRD.md:203-214`.
- **RC-07:** Earlier draft required a selector-script repair or an evidence narrowing. FIX_PRD ignores the script. Ignoring it is not closure of REQ-08.

## Disposition table

| ID | Specification | Execution status | Judgment |
| --- | --- | --- | --- |
| RC-01 | Later spec is the correct one: remove the self-call; burn `address(this)`; reject a code-less caller with `EOAPretransferNotAllowed` before burn; ordinary redemption still burns the original caller. One family does not close another. | **PARTIALLY_EXECUTED** | Shared adapter and the inventoried inheritors other than legacy V4 match. Legacy V4 out-query still re-enters `exchangeIn` by an external call. |
| RC-02 | Matches the caller-maximum rule and the later spec. Both flags. Compare share units, not LP or output. | **CONFIRMED_EXECUTED** | Comparison is before burn on both flags. Production-path tests assert the exact error and unchanged share balances. Not executed here. |
| RC-03 | Later delete-and-retarget spec matches the local-book rule for the supported V3 vault. Keeping legacy V4 is an explicit non-goal, not a silent preference for the old formula. | **PARTIALLY_EXECUTED** | Old V3 source is absent. Named launch and DETF callers construct FullSpread. Family README still describes the deleted tree and the withdrawn self-call. |
| RC-04 | Later spec is correct. Quoter partial-fill return is not the defect. Do not rename the existing input-ceiling error. Do not edit hookless, Pons, or Wings for this item. | **PARTIALLY_EXECUTED** | Quote and settlement checks are in source. The short-output settlement guard has no test. The input-ceiling revert is still named as an output shortage; the spec forbids renaming it here. |
| RC-05 | Later sleeve-excess spec is correct and matches the family PRD. It conflicts with the earlier "never combine" draft. That earlier draft is not the spec. | **CONFIRMED_EXECUTED** | One excess decision. EtherFi was not given this helper. Tests cover accumulation, minimum, and capacity cap. Not executed here. |
| RC-06 | Later spec matches OD-08's exclusive SE zero-preview signal for this helper. It correctly rejects the one-share quote. | **CONFIRMED_EXECUTED** for the named helper | Helper uses `previewExchangeIn == 0`, books the full local balance, and does not catch the preview. A separate hook-preview-of-zero path still contradicts OD-08. That path was not the RC-06 repair. |
| RC-07 | Owner ignore is a decision, not a repair. It must not be treated as REQ-08 closure. | **NOT_A_REMEDIATION** | Script still discovers only direct parents of baseline rows. FIX_PRD records the ignore. Stage-1 evidence still presents that scan as the replacement-package citation. |
| A-F01 | No FIX_PRD repair. Not authorized. | **NOT_A_REMEDIATION** | Current V3 and hookless exact-output paths still compare credit before `requirePretransferCaller`. Locked exact-error order remains contradicted. Not a new loss claim. |
| A-F02 | No FIX_PRD repair. | **NOT_A_REMEDIATION** | Cited Wings security test still uses a bare `vm.expectRevert()`. |
| A-F03 | No FIX_PRD repair. | **NOT_A_REMEDIATION** | Wings invariant handlers still swallow failures. The invariant does not require a successful deposit or withdrawal. |
| A-F04 / D-F02 | No FIX_PRD repair. Evidence gap, not a code repair. | **NOT_A_REMEDIATION** | This review did not bind a current run to artifacts. Historical Stage-1 evidence remains historical. |
| B-01 | Elaborated as RC-02. | See RC-02 | Closed in source and tests against the later spec, subject to the no-run limit. |
| B-02 | Elaborated as RC-05, then corrected. | See RC-05 | Executed against the later correction, not the earlier "never combine" objective. |
| B-03 | No FIX_PRD repair. | **NOT_A_REMEDIATION** | Not re-proved in this pass beyond the historical citation. No authorized custody-test repair was found. |
| B-04 | No FIX_PRD repair. FIX_PRD says do not change EtherFi in RC-05. | **NOT_A_REMEDIATION** | EtherFi was not edited to imitate the Rocket helper. Its own boundary-test gap was not given a repair. Current EtherFi tests were not re-audited line by line. |
| B-05 | No FIX_PRD repair. | **NOT_A_REMEDIATION** | No authorized shared-adapter matrix repair was specified. Current closure was not re-established. |
| C-001 | No FIX_PRD repair. Evidence/inventory gap. | **NOT_A_REMEDIATION** | No admitted expanded denominator was specified or produced by this review. |
| C-002 | No FIX_PRD repair. | **NOT_A_REMEDIATION** | Not re-read in this pass. No authorized Orbital cap-call reconciliation was found. |
| C-003 | No FIX_PRD repair. | **NOT_A_REMEDIATION** | Not re-read. No authorized family projection-test repair. |
| C-004 | No FIX_PRD repair. | **NOT_A_REMEDIATION** | Not re-read. No authorized D48 search-boundary repair. |
| C-005 | No FIX_PRD repair. | **NOT_A_REMEDIATION** | Not re-read. No authorized production-dependency witness repair. |
| C-006 | No FIX_PRD repair. | **NOT_A_REMEDIATION** | The cited consumer assertion is still a comparison of a balance to itself. |
| C-007 | No FIX_PRD repair. | **NOT_A_REMEDIATION** | Not re-read. No authorized unlock-context negative was specified. |
| D-F01 | Same subject as RC-07. Script repair ignored. | **NOT_A_REMEDIATION** | The parent-only discovery gap remains. Ignoring the script does not close REQ-08. |
| D-F03 | Elaborated as RC-06. | See RC-06 | Named helper matches the later zero-preview spec. Hook-preview-of-zero rollback remains a separate REQ-01 gap. |
| D-F04 | No FIX_PRD repair. | **NOT_A_REMEDIATION** | The cited test still replaces `indexedexManager.isDisabled` with `vm.mockCallRevert`. |
| D-X01 | No FIX_PRD repair. | **NOT_A_REMEDIATION** | No authorized Aave matrix repair. Recurrence tests, if present, were not run and are not a specified remediation. |

## Facts, inference, speculation

**Facts** are cited file:line observations. **Inference** is what those observations imply for the named repair. **Speculation** is reachability or loss that this pass did not establish. No fund-loss magnitude is claimed.

---

## Findings

### 1. Legacy V4 internal-balance redemption still re-enters exchangeIn

- **Severity:** Medium
- **Defect class:** CODE_DEFECT
- **File and line:** `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol:17-34`
- **Intended behavior:** FIX_PRD RC-01. Internal-balance redemption burns `address(this)` through a shared function. It does not re-enter `exchangeIn` to change `msg.sender`. Ordinary redemption burns the original caller and does not become that internal-balance call. Legacy V4 is in the inventory. Deleting it is not this item.
- **Broken requirement or invariant:** The later repair forbids preserving the self-call and adding a caller check in front of it. This override still performs an external `exchangeIn` on `address(this)` with `pretransferred=false`. The ordinary override moves the caller's shares onto the vault and then sets the internal flag, so that same external call is used for ordinary redemption too.
- **Impact class:** Caller-identity and call-shape invariant on one inheritor. The shared adapter now rejects a code-less caller before `_redeemVaultHeld` (`NativeStandardYieldTarget.sol:41-44`), so this pass does not restate the earlier unguarded-EOA claim for this entry. No extra burn or third-party wallet burn was established.
- **Fix direction:** Give this inheritor the same explicit-holder settlement the other families use. Do not keep the external `exchangeIn`. Do not delete or rewrite the legacy V4 accounting package as part of that call-shape repair. Add a production-proxy assertion for this family; the V3, hookless, Pons, and Wings tests do not cover it.
- **Confidence:** High on the call shape. Medium on residual economic difference versus an explicit burn, because the downstream false-flag burn was not fully traced.
- **Relation to the remediation:** Failed execution of RC-01 for this family only. Not a bad specification. The later spec named this inheritor and said not to leave the self-call.

**Fact:** `IStandardExchangeIn(address(this)).exchangeIn(...)` at lines 22-24 is the only production `exchangeIn` self-call found under `contracts/`. `address(this).call` remains only in test helpers, not on an internal-balance redemption.

**Fact:** Other inventoried inheritors pass `address(this)` into a burn or settlement helper, or delegatecall a zap-out that burns `address(this)`. Examples: `ERC4626StandardYieldTarget.sol:24` and `:31`; `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:204` and `:224`; Wings `Money.sol:154-171` with `pushed_=true` from `UniswapV4UpperLowerWingsStandardExchangeVaultSYTarget.sol:16`. Base `_redeemVaultHeld` reverts (`NativeStandardYieldTarget.sol:81-84`). `NativeStandardYieldContextRepo` is absent.

**Inference:** RC-01 is executed for the shared adapter and for the families whose tests call `expectCall` on `exchangeIn` with a count of zero. It is not executed for legacy V4.

### 2. Uniswap family README still describes the deleted V3 tree and the withdrawn self-call

- **Severity:** Medium
- **Defect class:** DOCUMENTATION_GAP
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/README.md:3` and `:56`
- **Intended behavior:** FIX_PRD RC-03 deletes `contracts/protocols/dexes/uniswap/v3` and points callers at V3 FullSpread. FIX_PRD RC-01 removes the proxy self-call. The README is the family description next to the FullSpread packages.
- **Broken requirement or invariant:** The README says the preserved implementations under `contracts/protocols/dexes/uniswap/v3` and `v4` remain unchanged, are not deprecated, and remain vulnerable to stored-total-minus-deployed accounting. It also says internal-balance redemption uses the fixed proxy self-call with `pretransferred=false`. The V3 file `UniswapV3StandardExchangeCommon.sol` is not present. FullSpread internal-balance redemption does not use that self-call.
- **Impact class:** Operators and later agents can treat a deleted package as current, or restore the withdrawn call shape because the family text still requires it. This is not a live-instance migration claim.
- **Fix direction:** Rewrite the family README so it matches the deletion, the FullSpread local book, and the explicit-holder SY settlement. State separately that legacy V4 source was intentionally kept and still uses the old formula. Do not describe the self-call as current FullSpread behavior.
- **Confidence:** High.
- **Relation to the remediation:** Failed documentation completeness of RC-01 and RC-03. The code deletion itself is present. Not a bad delete specification.

**Fact:** Named callers now construct FullSpread, not `deployUniswapV3StandardExchangeDFPkg`: `scripts/foundry/anvil_robinhood_testnet/Phase_05_Stage_04_UniswapV3StandardExchangePkg.sol:56`, the main-stage counterpart at the same line, `scripts/foundry/anvil_robinhood_fee_detf/Script_05_DeployUniV3SeOnRichPool.s.sol:129`, and `UniswapV4DetfProductionSeDeployLib.sol:356`. FullSpread pretransfer credit is `balanceOf(this)` minus `_reserveOfToken` (`UniswapV3FullSpreadStandardExchangeVaultCommon.sol:866-872`). A pull measures the transfer delta (`:875-883`).

**Fact:** Legacy V4 was not deleted. Its pretransfer helper still computes `faceBooked = R - deployed` (`UniswapV4StandardExchangeCommon.sol:1248-1274`) and does not call `requirePretransferCaller` in that function. FIX_PRD RC-03 explicitly says not to delete that package. That residual is not a failed RC-03 execution. It remains a locked local-credit contradiction on a package the later spec kept. No current launch script in the named RC-03 caller list constructs it. Its factory service and test base still can.

### 3. V3 exact-output settlement guard is untested

- **Severity:** Medium
- **Defect class:** TEST_DEFICIENCY
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:505-536`; test disclaimer at `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadExactOutputFill.t.sol:16-17`
- **Intended behavior:** FIX_PRD RC-04. A direct exact-output execution whose output delta is not the requested amount reverts, and the caller's input is unchanged. Quote rejection and a fillable success are also required.
- **Broken requirement or invariant:** Source checks `fullyFilled` and `quote.amountOut` (`:281-283`) and, after `pool.swap`, requires the paid output delta to equal `amountOut` (`:531-535`). The production test file states that the fixture has no execution-only short fill and that quote-stage rollback does not cover the post-swap output-delta guard. The unfilled execution test reverts at preview/quote time.
- **Impact class:** The settlement acceptance criterion is not evidenced. This pass did not establish that the source check is unreachable or wrong. No shortfall amount was measured.
- **Fix direction:** Add a production-proxy case that reaches `_swapExactOut` and rejects a short output delta, with the caller's input unchanged. Do not change the Crane quoter. Do not edit hookless, Pons, or Wings to manufacture that case.
- **Confidence:** High that the test does not cover the guard. Medium that a hermetic pool can reach a short execution independently of the quote check; that reachability was not demonstrated.
- **Relation to the remediation:** Incomplete execution of RC-04's test acceptance. The source repair is present. Not a bad specification.

**Fact:** `_executeQuotedSwapOut` still pulls input and then calls `_swapExactOut` (`UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:77-90`). It does not add a second output check that can be skipped. That matches the spec.

**Fact:** `UniswapV3Exchange_ExactOutputNotFilled` appears only in the V3 FullSpread common among the Uniswap vault sources searched. Hookless and Pons still have their own `fullyFilled` references in their quote services. Wings has no direct pair-swap settlement in the files read for this item. No diff was available, so "those trees were not edited" is an inference from the absence of the V3 error, not a history proof.

### 4. Input-ceiling failure is still named as an output shortage

- **Severity:** Informational
- **Defect class:** DOCUMENTATION_GAP
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:528-529`
- **Intended behavior:** FIX_PRD RC-04 non-goal: do not rename the existing input-ceiling error in this item. The short-output revert must mean the output was short.
- **Broken requirement or invariant:** None relative to the later spec. The ceiling check reverts `UniswapV3Exchange_InsufficientOutput` when spent input exceeds `maxAmountIn`. The short-output path uses `UniswapV3Exchange_ExactOutputNotFilled` (`:534-535`). The name of the ceiling error does not describe an input ceiling.
- **Impact class:** Diagnostic confusion only. Not an authorization or payout defect established here.
- **Fix direction:** Leave it unless a later owner item explicitly renames the ceiling error. Do not treat a rename as part of RC-04.
- **Confidence:** High.
- **Relation to the remediation:** Not a failed RC-04 execution. The spec ordered this name left unchanged. Recorded so the misname is not mistaken for the short-output check.

### 5. Hook preview of zero still does not roll the DETF parent back

- **Severity:** Medium
- **Defect class:** CODE_DEFECT
- **File and line:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:524-545` and `:600-618`
- **Intended behavior:** Stage-1 REQ-01 as narrowed by OD-08. A hook preview of `0`, or a hook join revert, rolls the parent back and does not add a holder-reserve update. FIX_PRD RC-06 does not authorize a new catch and does not redesign bond, threshold, or vesting economics. It also does not withdraw OD-08.
- **Broken requirement or invariant:** `_entryJoinResidualAtomic` returns `0` when the hook preview is `0`. It does not revert. The caller loop breaks on `lpOut_ == 0`. `_joinResidualCapped` / `_joinResidualUnbalanced` then fall through with the default false result. `_tryJoinResidual` books the full local balance at `:543-545`.
- **Impact class:** Residual accounting and error propagation. A zero hook preview can continue as a booked holder reserve instead of rolling back. Financial loss was not established. The `supportsInterface` catch at `:630-633` returns false and does not itself book. The preview call is not caught.
- **Fix direction:** Make the hook-preview-of-zero and hook-join-failure paths hard failures that do not update the holder reserve. Do not add a catch around the SE preview. Do not change bond, threshold, or vesting economics. This is not closed by the RC-06 helper.
- **Confidence:** High on the cited control flow. Medium that every hook family reaches this residual join; the function is the production sweep path that was read.
- **Relation to the remediation:** Not a failed execution of the RC-06 helper. It is an unclosed locked REQ-01 obligation. No FIX_PRD item authorized this hook-zero repair, and none recorded an owner exception.

**Fact:** `_retainSubSharePairResidual` (`:625-637`) books only after `previewExchangeIn` of that amount returns zero, writes `balanceOf(address(this))`, and does not call `quoteInputForExactShares`. `UniswapV4DetfLeftoverPreview.t.sol` asserts that public sweep outcome, a nonzero preview that is not treated as undepositable, a reverting preview that does not book, and no one-share quote on the first zero-preview sweep. Those tests were not run here.

### 6. Selector-script ignore is recorded, but Stage-1 evidence still treats the scan as replacement coverage

- **Severity:** Low
- **Defect class:** EVIDENCE_GAP
- **File and line:** `scripts/r12_selector_size_compare.py:42-47`; `docs/reviews/apex-2026-09-17-second-audit-readiness/STAGE1_EVIDENCE.md:47-49`
- **Intended behavior:** FIX_PRD RC-07 ignores the script. EIP-170 still applies at deploy. Ignoring the script is not closure of REQ-08. The earlier REQ-08 acceptance required the current hookless, Pons-family, and wings units to be in the evidence, or the claim to be narrowed.
- **Broken requirement or invariant:** Discovery still takes `Path(r['source']).parent` and globs `*.sol` only in that parent. It does not recurse. STAGE1_EVIDENCE still says the hookless and Pons-family packages replace the pre-split citation after a zero-oversize run of that script.
- **Impact class:** Provenance. A zero-oversize result on the scanned parent set can be read as certification of nested replacement packages. No oversized facet was established.
- **Fix direction:** Do not edit the script as a fake closure. Narrow or replace the Stage-1 evidence sentence so it does not say the replacement packages are covered unless a later authorized inventory includes them. Keep EIP-170 as a deploy constraint, not as a claim this script already proved it for those directories.
- **Confidence:** High on the current script shape and the evidence sentence. No diff was taken, so a comment-only edit cannot be excluded. The non-recursive discovery is still the behavior D-F01 described.
- **Relation to the remediation:** The ignore itself matches the later owner decision. Treating that ignore as REQ-08 closure does not. Not a fake script fix on the evidence read.

### 7. Accepted exact-error and assertion gaps were not given a repair, and the cited sites remain

- **Severity:** Low
- **Defect class:** TEST_DEFICIENCY
- **File and line:**
  - A-F01: `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:81-86` checks credit before `_secureTokenTransfer`, which is where `requirePretransferCaller` runs (`UniswapV3FullSpreadStandardExchangeVaultCommon.sol:866-867`). Hookless mint exact-out has the same order at `UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:94-104`.
  - A-F02: `UniswapV4UpperLowerWingsStandardExchangeVaultSecurity.t.sol:39-40`
  - A-F03: `UniswapV4UpperLowerWingsStandardExchangeVaultInvariant.t.sol:33-50` and `:75-81`
  - C-006: `UniswapV4UpperLowerWingsStandardExchangeVaultFamilyConsumers.t.sol:59`
  - D-F04: `Adversarial_TrustFlags.t.sol:58-65`
- **Intended behavior:** Unspecified as a repair. FIX_PRD does not elaborate these IDs. The locked exact-error and production-first rules they cite were not amended in FIX_PRD.
- **Broken requirement or invariant:** Current source or tests still match the historical gap: credit shortfall can precede `EOAPretransferNotAllowed`; a bare revert does not pin the named cause; swallowed handler failures are not required to succeed; a balance is compared to itself; the manager disable query is mocked.
- **Impact class:** Diagnostic and coverage quality. No new principal-loss path was established. These are not failed executions of RC-01 through RC-06.
- **Fix direction:** Do not invent a repair in this review. If the owner wants them closed, specify each one. Until then, do not cite the current tests as closure of R13 exact-error order, Wings campaign success, consumer conservation, or the production-manager disable witness.
- **Confidence:** High on the cited lines. Bounded: other files may contain a better witness that this pass did not find.
- **Relation to the remediation:** Not a failed named remediation. Open items that still contradict a locked requirement. Recurrence test files named in the historical handoff are not a specified or executed repair; this pass did not run them and does not treat them as closure.

## Items with no defect found in the named repair

- **RC-02.** `CamelotV2StandardExchangeOutTarget.sol:761-768` compares `amountIn` with `maxAmountIn` before `_secureSelfBurn`, on both flags, in share units. The share-to-pool comparison at `:657-661` is unchanged. `CamelotV2ZapOutMaxAmountIn.t.sol` covers both flags, the exact `MaxAmountExceeded` selector, unchanged caller and vault share balances, and a funded payout of the requested output. Not run.
- **RC-05 helper and callers.** `_bestEffortStakeOverageTowardTarget` (`RocketPoolRETHStandardExchangeCommon.sol:502-509`) makes one excess decision and returns when excess is below `_minimumDeposit`. Callers are the WETH mint paths at `RocketPoolRETHStandardExchangeInTarget.sol:78-79` and `RocketPoolRETHStandardExchangeOutTarget.sol:71-72`. `RocketPoolSleeveExcessStake.t.sol` covers a below-minimum credit, accumulated excess, and a maximum-deposit cap. EtherFi has no `_bestEffortStakeOverageTowardTarget`. The earlier "never combine" objective is the conflict; the later spec and the family PRD agree with the code.
- **RC-06 helper.** See finding 5 for the separate hook-zero gap. The helper itself matches the later spec.
- **RC-01 shared adapter and the inheritors other than legacy V4.** Inventory of `_redeemVaultHeld` overrides: ERC-4626, Morpho, Lido, Rocket, EtherFi, Aave Stata, Balancer V3 pool, constant-product (Uni V2, Camelot, Aerodrome facets supply `_redeemConstantProduct`), Wings, single-CP, dual, orbital, weighted, Balancer-quad, curve-quad, V3 FullSpread, hookless, Pons, Aave cross-version loop, and legacy V4. Holder argument is `address(this)` except legacy V4, which external-calls. Morpho skips allowance when the owner is `address(this)` (`MorphoBlueStandardExchangeCommon.sol:200-203`) and then burns that owner. Custody SY was not changed to add this self-call; it was not an inheritor of this adapter in the search.
- **RC-03 code deletion and caller retarget.** Old V3 common file is absent. Named callers construct FullSpread. Legacy V4 package was not deleted, which matches the non-goal. The README defect is finding 2.
- **RC-04 source checks and non-spread.** Quote and settlement checks exist. Hookless, Pons, and Wings do not contain the V3 short-output error. The untested settlement guard is finding 3.
- **RC-07 script non-edit as a fake fix.** The parent-only discovery remains, so the script was not repaired into a false closure. The evidence-note overclaim is finding 6.

## Files examined with no additional defect beyond the findings above

- `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol`
- `contracts/vaults/standard/sy/ConstantProductStandardYieldTarget.sol`
- `contracts/vaults/standard/erc4626/ERC4626StandardYieldTarget.sol`
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol` (`_burnSeShares`)
- `contracts/utils/LocalCreditLib.sol`
- `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardYieldTarget.sol`
- `contracts/protocols/staking/lido/LidoWstETHStandardYieldTarget.sol`
- `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardYieldTarget.sol`
- `contracts/protocols/staking/etherfi/EtherFiWeETHStandardYieldTarget.sol`
- `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardYieldTarget.sol`
- `contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeOutTarget.sol`
- `contracts/protocols/dexes/balancer/v3/pools/BalancerV3PoolStandardExchangeTarget.sol`
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol` (`_redeemLpSharesFrom`)
- `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol` (zap-out and share-to-pool)
- `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol`
- `contracts/protocols/staking/rocket-pool/ROCKET_POOL_RETH_STANDARD_EXCHANGE_VAULT_PRD.md` sleeve section
- V3, hookless, and Pons `executeZapOutExactIn` delegates and the V3/hookless `_executeZapOutExactIn` burn of `address(this)`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol` redeem holder selection
- Production RC-01 tests: `UniswapV3FullSpreadVaultHeldRedeem.t.sol`, `UniswapV4FullSpreadHooklessVaultHeldRedeem.t.sol`, `UniswapV4FullSpreadPonsVaultHeldRedeem.t.sol`, `UniswapV4UpperLowerWingsVaultHeldRedeem.t.sol`
- `test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2ZapOutMaxAmountIn.t.sol`
- `test/foundry/spec/protocol/staking/rocket-pool/RocketPoolSleeveExcessStake.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/UniswapV4DetfLeftoverPreview.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadExactOutputFill.t.sol` (source of the disclosed test gap, not a hidden one)

Hook `_redeemVaultHeld` bodies were read far enough to see the holder argument or `executeVaultHeldRedemption` delegatecall. Their full exit math was not re-audited. That is not a claim those families are otherwise safe.

## What this pass does not prove

Zero findings on an item is not a security proof. Reviewer agreement is not claimed. No four-member consensus is claimed. No test was run. Historical green counts are not current evidence. Deleting the old V3 source does not change immutable deployed instances. Keeping legacy V4 was specified; it does not make that package's stored-total credit formula conform to the local-book rule.
