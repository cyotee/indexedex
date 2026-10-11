# Astra — APEX Stage 2 remediation confirmation, independent original

Date: 2026-10-11. Review state: **PARTIAL_REPORT**. Attribution: **Astra**.

## Executive judgment

**The current tree does not support unconditional confirmation of RC-01 through RC-06.** There are substantive repairs, but RC-01 still contains a prohibited external self-call in legacy V4 and rejects ordinary V3 FullSpread EOA redemption. RC-06's particular retention helper now uses the required preview, but its surrounding hook-zero/fallback behavior contradicts the controlling Stage-1 rule. RC-04's two source checks are present; its focused regression explicitly does not cover the post-swap rejection.

Camelot's share maximum and Rocket's corrected accumulator policy are implemented in the inspected source and have meaningful focused assertions. Legacy V3 source is absent, and the named launch/DETF constructors now select FullSpread. The family README has not caught up.

The earlier Rocket objective is **not** a valid requirement to enforce: FIX_PRD explicitly withdraws the instruction to keep skipped credits permanently separate. Similarly, preserving the native SY self-call and patching legacy V3 in place are superseded proposals, not alternative closure criteria.

No shell, tests, builds, deployment, browser, delegation, or external source transmission occurred. Only this assigned report was written. No other output from this review round was read or searched. Historical reports supplied by the assignment were treated as evidence, not conclusions or permission grants. No cross-review or consensus claim is made.

## Evidence and authority

### Inputs read

Human-supplied:

- `CLAUDE.md`.
- `docs/plans/APEX_STAGE2_REVIEW_PRD.md` and `.plan.md`.
- `docs/research/apex-stage2-review/accepted-20261007/REPORT.md` and `REVIEW_MANIFEST.md`.
- `docs/research/apex-stage2-review/recurrence-20261007/REVIEW_MANIFEST.md`, `A-vaults-review.md`, and `B-credit-lending.md`.
- Relevant sections of canonical IndexedEx testing/adversarial skills, Crane testing/adversarial/architecture/deployment skills, and `docs/agent/SKILL_CATALOG.md`; skills were read directly.

**Related documents**, distinguished from human-named primary inputs:

- `docs/reviews/apex-stage2-council-2026-10-07/REMEDIATION_PRD.md`.
- Same directory's `FIX_PRD.md` and `FIX_PRD.plan.md`.
- `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md`, particularly OD-08 and REQ-01/REQ-08 continuity.
- `contracts/protocols/staking/rocket-pool/ROCKET_POOL_RETH_STANDARD_EXCHANGE_VAULT_PRD.md:203–217`.
- Relevant router/product-law sections of `docs/agent/INDEXEDEX_AGENT_LAW.md`, and the current Uniswap README and Wings consumer status.

All supplied document paths above were available. The source directory `contracts/protocols/dexes/uniswap/v3` was not found; that is consistent with RC-03, not a missing-authority blocker. One accidental navigation read of `contracts/agent/INDEXEDEX_AGENT_LAW.md` failed; the correct supplied/router path `docs/agent/INDEXEDEX_AGENT_LAW.md` was read instead.

### Authorization is separate from specification

The Stage-2 PRD describes a review, not production repair. The accepted report expressly withholds implementation authorization (`REPORT.md:406–419`). The recurrence manifest authorizes verification work, but excludes production fixes (`REVIEW_MANIFEST.md:5–9`). Related FIX_PRD specifies repairs while withholding implementation authorization (`:3–6`); its plan requires a separately authorized session (`:3–7`). **No supplied record establishes the separate production-implementation authorization.** This is not an allegation that the owner never gave one; it is a provenance limit of this packet.

I nevertheless assess the current implementation against the stipulated later FIX_PRD corrections, as requested. For items outside FIX_PRD, the accepted report supplies corrective objectives, and the recurrence authorization supports test investigation; neither becomes permission for an invented production repair.

### Status meaning

`CONFIRMED_EXECUTED` below means the specified source change and relevant inspected test assertions are present, **not that tests were run or passed**. Runtime execution is **UNVERIFIED for every row**. `PARTIALLY_EXECUTED` identifies a concrete remaining implementation/assertion gap, rather than using missing runtime alone to downgrade everything. Specification entries marked `NOT_A_REMEDIATION` mean no separately elaborated/authorized production repair in the supplied packet; their current test work is assessed separately.

No immutable current snapshot, dirty-tree digest, change-attribution diff, or current source/artifact/run chain was supplied for this session. October 7 hashes are historical, not the identity of the October 11 reads. Accordingly, statements such as “EtherFi was not edited,” “the quoter was unchanged,” or “the script was not edited” cannot be proved from this single tree. I distinguish current shape from historical edit attribution throughout.

## Disposition table — every in-scope ID

| ID | Specification correctness / authority | Current execution disposition | Evidence and judgment |
|---|---|---|---|
| RC-01 | Later FIX_PRD is consistent: explicit vault holder, pre-burn D9 gate, ordinary caller retained. Earlier self-call-preserving proposal withdrawn. Separate implementation authorization unverified. | **PARTIALLY_EXECUTED** | Base gate and family overrides exist. Legacy V4 still externally re-enters exchangeIn; V3 ordinary EOA redemption reaches the pretransfer EOA rejection. Astra-01/02; inventory below. |
| RC-02 / B-01 | Correct share-unit maximum; no later conflicting correction found. | **CONFIRMED_EXECUTED** | Camelot OutTarget `:751–769` compares before burn, independent of flag. `CamelotV2ZapOutMaxAmountIn.t.sol:33–83` covers both flags, rejection rollback and exact successful payout. No defect found in this repair. |
| RC-03 | Later delete-and-retarget instruction controls over earlier patch-or-decide proposal. V4 expressly excluded. | **CONFIRMED_EXECUTED** (source/test migration); documentation incomplete | Legacy V3 directory absent; no old constructor occurrence in bounded contracts/scripts/test searches. Named callers use FullSpread. Full local book and actual pulls checked in source/tests. README contradicts this, Astra-07. No remaining old-V3 code defect found. |
| RC-04 | Correct two-boundary fill check; Crane partial quote is not the defect. Existing input error rename expressly excluded. | **PARTIALLY_EXECUTED** | Common `:281–284,527–536` checks quote and paid output; caller consumes it. Focused test `:15–17,48–69` only reaches quote rejection, not settlement rejection. Astra-05. Input error still misleading, Astra-08, but preserving it is not RC-04 noncompliance. |
| RC-05 / B-02 | **SPEC_CONFLICT resolved in favor of FIX_PRD**: old never-combine objective is withdrawn. New aggregate-sleeve rule matches family PRD `:203–217`. | **CONFIRMED_EXECUTED** against corrected specification | Rocket Common `:445–459,495–509`, InTarget `:71–81`, OutTarget `:60–74`; accumulator/cap tests and corrected exact-in/out recurrence cases present. No defect found in the corrected repair. EtherFi remains a different split helper. |
| RC-06 / D-F03 | Correct actual-leftover zero preview and full local balance; no new catch; Stage-1 OD-08 still controls hook zero semantics. | **PARTIALLY_EXECUTED** | Retain helper `:625–637` matches narrowly. Surrounding joins accept hook-zero fallback and eventually book; failed probe can be bypassed by adjacent zero helper. Supported-interface regression not supplied by focused fixture. Astra-03/04/06. |
| RC-07 | **NOT_A_REMEDIATION**: explicitly IGNORED by owner in FIX_PRD `:18` and plan `:7`. | **NOT_A_REMEDIATION**; historical non-edit **UNVERIFIED** | Script still has nonrecursive discovery `:43–47`. Ignoring is recorded, not closure of REQ-08 or EIP-170 evidence. No request to repair this script is made. |
| A-F01 | **NOT_A_REMEDIATION** under FIX_PRD; accepted report specifies an error-order objective but no production-fix authorization. | **NOT_EXECUTED** in inspected V3 route | OutExecuteTarget `:81–86` checks shortage before D9. Current recurrence test `:56–70` expects shortage, not conformance. Astra-09. H/P-wide closure not inferred from V3. |
| A-F02 | **NOT_A_REMEDIATION** under FIX_PRD; exact-error test objective and later verification authorization exist. | **PARTIALLY_EXECUTED** test work | Wings `ApexRecurrenceExactErrors.t.sol:27–84,105–121` adds exact token, callback and rollback assertions. It is not accurate to say no new tests exist. Full original-negative replacement and runtime closure unverified; no new production defect inferred. |
| A-F03 | **NOT_A_REMEDIATION** under FIX_PRD; campaign-vacuity corrective objective, verification authorized. | **PARTIALLY_EXECUTED** test work | New witness `:19–53` requires funded setup, actual trade/rebalance/exit; `:76–83` adds deterministic coverage. Original invariant still catches every action and never requires successes. Historical promise of afterInvariant progress counters is absent in current witness. Astra-11. |
| C-006 | **NOT_A_REMEDIATION** under FIX_PRD; conservation assertion objective, verification authorized. | **CONFIRMED_EXECUTED** for replacement assertion source | `ApexRecurrenceConsumerConservation.t.sol:57–68` measures before balances and exact share conservation across five callers. Original tautology remains at FamilyConsumers `:59`; do not cite it as proof. No defect found in the replacement conservation assertions; runs unverified. |
| B-03 | **NOT_A_REMEDIATION** under FIX_PRD; custody test/evidence objective, verification authorized. | **CONFIRMED_EXECUTED** for inspected missing test cases | `RebasingAwareERC4626_APEX_Recurrence.t.sol:28–90` uses custody proxy, payout callback-added shares, exact-in/out/SY retention and consumed-credit retry. Historical acceptance mapping correction not verified. No defect found in these assertions. |
| B-04 | **NOT_A_REMEDIATION** under FIX_PRD; EtherFi-specific test objective, not a Rocket production fix. | **CONFIRMED_EXECUTED** for inspected boundary tests | EtherFi recurrence `:19–68` asserts its own exact sleeve arithmetic and zero/full targets in both modes. No defect found in these assertions. Historical evidence mapping and runs unverified. |
| B-05 | **NOT_A_REMEDIATION** under FIX_PRD; receipt operation/dispatch tests requested as verification. | **CONFIRMED_EXECUTED** for inspected missing assertions | Shared behavior `:261–334` covers all four operations with local backing and subsequent SE credit; generic-over-real-Stata recurrence `:12–35` checks dispatch/books/isolation. Transitive host setup/run closure not certified. No defect found in these new assertions. |
| C-001 | **NOT_A_REMEDIATION** under FIX_PRD; inventory/evidence objective, not a code repair. | **NOT_EXECUTED** for disclosed exhaustive closure | Wings `CONSUMER_RESULTS.md:5–15` still says not every legal mask and lists pending domains. No exhaustive denominator derived in this review. No new code vulnerability inferred. |
| C-002 | **NOT_A_REMEDIATION** under FIX_PRD; historical-cap reconciliation requires an applicability decision, not restoring an obsolete branch. | **PARTIALLY_EXECUTED** test work | Orbital Apex008 `:236–274` now checks exact burn/allowance and exact earlier wrapped rejection with zero SE execution calls. This is useful current-route evidence, not proof of an operative cap-call failure. Requirement reconciliation remains unverified. |
| C-003 | **NOT_A_REMEDIATION** under FIX_PRD; family projection test objective, verification authorized. | **PARTIALLY_EXECUTED** | All three D41 files now exercise selected quoteRate failures and count selected calls. Successful projection uses equal live/projected rates, leaving the stated discriminating numerical result incomplete. Astra-12. |
| C-004 | **NOT_A_REMEDIATION** under FIX_PRD; D48 test objective, verification authorized. | **UNVERIFIED** against current controlling rate design | Current Morpho/wrapped suites now assert whole-supply/one-call behavior and more payload failures (`RateProvider.t.sol:67–120`, wrapped `:152–189`). This is not simply the historical missing bounded-search test. No supplied FIX ruling authorizes replacing that requirement; later rate-design authority was not fully traced. Do not restore old search or declare closure by assumption. |
| C-005 | **NOT_A_REMEDIATION** under FIX_PRD; real dependency/authorization witnesses requested as verification. | **PARTIALLY_EXECUTED** | All six D49 suites contain new real-underlying-pause tests (bounded search). Representative constProd `:37–69` proves actual dependency rollback/reopening. Its handoff failure tests still mock router responses `:179–198`. Full six-family auth-boundary closure not established. |
| C-007 | **NOT_A_REMEDIATION** under FIX_PRD; missing unlock-context test objective, verification authorized. | **CONFIRMED_EXECUTED** for missing assertion source | Balancer quad `_Recurrence.t.sol:19–50` enters real manager unlock, records exact NotPoolManager, checks reserves/supply and funded authorized swap. No new guard was needed. No defect found in that test. |
| D-F01 | **NOT_A_REMEDIATION** as script repair after RC-07 owner correction; broader REQ-08 evidence obligation survives. | **NOT_A_REMEDIATION** for script; evidence closure **UNVERIFIED** | Current script `:35–62` still scans baseline parents, not all replacement directories. No claim this subset establishes current release size/selector closure. |
| D-F02 | **NOT_A_REMEDIATION** under FIX_PRD; source/artifact/run evidence objective, verification authorized. | **UNVERIFIED** | No current causal run chain assessed here. Historical accepted/recurrence identities and pending statements cannot attest to today's changed source. Preserve REQ-08 origin; owner acceptance is not contradicted by this evidence limitation. |
| D-F04 | **NOT_A_REMEDIATION** under FIX_PRD; manager-fixture correction objective, no production repair specified. | **NOT_EXECUTED** in named regression | `Adversarial_TrustFlags.t.sol:55–65` still mocks manager isDisabled. Astra-10. No new manager code defect inferred. |
| D-X01 | **NOT_A_REMEDIATION** under FIX_PRD; Aave matrix verification authorized, not a production redesign. | **CONFIRMED_EXECUTED** for inspected missing assertion source | Aave recurrence `:26–47,56–178` adds equal-unit setup, initial/later/zero caps, both debt legs, real frozen-reserve rollback, reopening, and elapsed-interest capacity boundary. No defect found in these assertions; complete market setup/math and execution remain unverified. |

## RC-01 production inventory and settlement evidence

Search was bounded to current `contracts/**/*.sol` for `NativeStandardYieldTarget`, `_redeemVaultHeld`, `_standardRoute`, the removed context name, and explicit self-call spellings. It found **20 direct production inheritors**, including additional hook families and Aave cross-version beyond the question's starting list. Every direct inheritor found has an override; no current direct inheritor was found relying solely on the base's reverting fallback. `NativeStandardYieldContextRepo` was not found in that search. This is a source inventory, not an installed-instance census.

The base `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:35–51` checks D9 at `:42` before balance validation and settlement. `LocalCreditLib.sol:23–27` implements the exact error. Base ordinary routing uses delegatecall with false flag (`:65–71`), preserving the external caller. Invalid receiver/zero amount/invalid token may fail earlier; the pre-burn D9 acceptance does not require those unrelated validation errors to be suppressed.

| Production inheritor (full path) | Current internal-balance shape | Inspection result / boundary |
|---|---|---|
| `contracts/vaults/standard/erc4626/ERC4626StandardYieldTarget.sol:17–35` | `_burnSeShares(address(this),...,false)`, local-first/receipt payout and sync | Explicit holder confirmed; Common `:282–291` burns supplied owner. No defect found in inspected settlement. |
| `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardYieldTarget.sol:12–16` | `_execUnwrapExactIn(address(this),...)` | Explicit owner forwarding; Common search identifies owner burn `:206–215,320–334`. Complete payout body/test closure not established here. |
| `contracts/protocols/staking/lido/LidoWstETHStandardYieldTarget.sol:12–22` | Direct vault burn, family payout and sync | No self-call; no defect found in inspected override. |
| `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardYieldTarget.sol:12–20` | Direct vault burn, family payout and sync | No self-call; no defect found in inspected override. |
| `contracts/protocols/staking/etherfi/EtherFiWeETHStandardYieldTarget.sol:12–22` | Direct vault burn, family payout and sync | No self-call; no defect found in inspected override. This RC-01 change is not an RC-05 sleeve change. |
| `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardYieldTarget.sol:20–30` | Direct vault burn, Stata delivery, rewards and sync | No self-call; no defect found in inspected override. |
| `contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeOutTarget.sol:24–34` | Direct vault burn, withdrawal/payout helper | Additional inheritor; no self-call in inspected override. |
| `contracts/protocols/dexes/balancer/v3/pools/BalancerV3PoolStandardExchangeTarget.sol:46–53` | Explicit holder into `_executePoolLiquidityFrom` | `:138–172` separates self-held from pulled funding; `:214–218` uses `from: address(this)` for BPT burn. Authenticated Vault callback is not the prohibited exchangeIn self-call. No defect found in inspected path. |
| `contracts/vaults/standard/sy/ConstantProductStandardYieldTarget.sol:15–22` | Explicit holder into family `_redeemConstantProduct` | UniV2 OutFacet `:24–28`, Camelot InFacet `:23–27`, Aerodrome OutQueryFacet `:19–28` forward holder to settlement (Aerodrome uses delegatecall). Common searches locate `_burn(holder_, shares_)`. Full per-route payout tests not inspected. |
| `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol:24–54` | Internal-balance delegates directly to installed execution implementation; ordinary route stages caller shares then sends true flag | Internal burn confirmed in InBase `:204,224`. Ordinary EOA failure: Astra-01. |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiQueryTarget.sol:23–35` | Locked/scoped delegatecall to existing execution delegate | Own InBase `:133–207` burns vault at `:155,204`, pays receiver, syncs. Own Common `:944–949` ordinary route moves original caller shares without allowance. No defect found in this inspected path. |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutMultiQueryTarget.sol:23–35` | Separate locked/scoped delegatecall | Independently read Pons InBase `:133–207` and Common `:944–949`; same holder property confirmed independently. No defect found in inspected path. |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultSYTarget.sol:12–18` | Money begin/redeem/end; true selects vault holder | Money `:147–171` checks gate, selects holder, burns exactly shares; false retains caller. No defect found in inspected holder selection. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol:17–35` | **Typed external exchangeIn self-call**, including staged ordinary route | Fails RC-01 mechanism requirement, Astra-02. V4 remains present; not deleted as RC-03. |
| `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawTarget.sol:57–61` | Explicit vault holder, liquidity-removal authorization and lock | `_withdrawSingleFrom:673–718` validates holder, burns holder at `:690`, settles/syncs. Other payout/dust policy not audited. |
| `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookSeTarget.sol:51–56` | Explicit vault holder into exit helper under lock | No self-call in inspected override; full helper economics/test coverage unverified. |
| `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget.sol:17–25` | Explicit vault holder; liquidity-removal authorization and lock | No self-call in inspected override; full helper economics/test coverage unverified. |
| `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol:53–64` | Authorized/locked delegatecall to withdrawal facet | WithdrawFacet `:26–31` names vault holder. New implementation-only method rejects direct calls and is absent from listed proxy selectors `:43–55`; no direct public burn bypass established. |
| `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinQueryTarget.sol:20–31` | Authorized/locked delegatecall to exit facet | ExitFacet `:24–31` names vault holder and rejects direct calls. Full installed-selector/runtime proof not established here. |
| `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookQueryTarget.sol:14–25` | Locked delegatecall to exit facet | ExitFacet `:12–16` names vault holder and rejects direct calls; proxy selector list `:21–34` excludes helper. No public burn bypass established. |

No literal `address(this).call(...)` was located on the inspected native internal-balance routes. **That lexical result does not close RC-01**: legacy V4's typed interface call has the same external-call semantics. No family is closed solely because a sibling was inspected.

Separate focused held-share suites were read for V3, hookless, Pons and Wings. Each asserts exact EOA error, requested vault debit, no other-share refund, receiver payout and contract-caller ordinary debit. V3's ordinary test uses the test contract, so it misses the EOA regression. Recurrence V3/Wings files also now contain funded EOA rejection checks, refuting the historical claim that their current bodies still expect successful EOA internal redemption. Runtime outcomes were not inferred from the updated assertions.

The base reverting fallback is not by itself a demonstrated live-family defect after the inventory above. It would be a future inheritance hazard, not proof that the listed overrides fail closed instead of implementing settlement.

## Findings

### Astra-01 — Ordinary V3 FullSpread SY redemption is accidentally contract-only

- **Severity / class:** Medium / CODE_DEFECT.
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol:39–50`; Common `:866–868,918–920`; InTarget `:58–61`.
- **Intended behavior:** FIX_PRD RC-01 `:84–87,97` retains ordinary redemption of the original caller's own shares; D9 applies to externally requested internal-balance/pretransfer, not an ordinary false-flag redemption.
- **Observed fact:** Ordinary redemption transfers the original caller's shares to the vault, then delegatecalls exchangeIn with `pretransferred=true`. Share delivery invokes the bytecode check on the unchanged original caller. There is no exemption for an adapter-internal transfer.
- **Inference / broken invariant:** A code-less holder cannot complete ordinary redemption: its false SY flag is internally converted into the contract-only push path. The staged transfer rolls back, so this is availability loss, not an established unauthorized burn or theft.
- **Impact class:** Ordinary wallet redemption availability / interface regression.
- **Fix direction:** Share ordinary settlement using an explicit original holder without misclassifying internally staged shares as an external pretransfer. Preserve the external true-flag gate. Add an ordinary funded EOA assertion alongside the contract-caller assertion.
- **Confidence:** High in call-path conclusion; no runtime reproduction performed.
- **Relationship:** Failed RC-01 execution. Likely a call-shape regression, but introduction date/commit cannot be proved without a baseline diff. Test gap at `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol:96–104` masks it by using `address(this)` as caller.

### Astra-02 — Legacy V4 retains the explicitly forbidden exchangeIn self-call

- **Severity / class:** Low / CODE_DEFECT.
- **File and line:** `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol:17–24,27–35`; `UniswapV4StandardExchangeCommon.sol:1299–1305`.
- **Intended behavior:** FIX_PRD RC-01 `:77–88,93` removes identity-changing external self-calls from every inventoried family; plan `:93` explicitly includes retained legacy V4.
- **Observed fact:** The override calls `IStandardExchangeIn(address(this)).exchangeIn(...)` externally. Common accepts vault-held shares through `msg.sender == address(this) && !pretransferred`. Ordinary routing also stages shares and redirects to this override.
- **Inference / broken invariant:** The identity-substitution design survives under typed-call syntax. A grep for raw `.call` alone misses it.
- **Impact class:** Specification/authorization-context conformance; caller identity changes across settlement. The new base gate does reject code-less true-flag callers; no current EOA internal-burn bypass is asserted here.
- **Fix direction:** Use explicit-holder shared settlement without external exchangeIn re-entry, and test legacy V4 independently. Do not delete or accounting-rewrite V4 under RC-03.
- **Confidence:** High.
- **Relationship:** Failed RC-01 execution, not a reason to widen RC-03.

### Astra-03 — DETF hook zero quotes are accepted as fallback/retention instead of rolling back

- **Severity / class:** Medium / CODE_DEFECT.
- **File and line:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:600–618`, callers `:524–545,550–597`; test `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/UniswapV4DetfLeftoverPreview.t.sol:52–77`.
- **Intended behavior:** Related Stage-1 OD-08/REQ-01 `:184,195–202`: only successful **SE** zero preview authorizes book-and-wait. A **hook** zero preview rolls the parent back. FIX_PRD RC-06 changes the retention signal, not that rule.
- **Observed fact:** Both hook preview branches return zero at Common `:605,615`. Outer loops break, may try another mode, and can reach unconditional full-balance booking at `:545`. The named RC-06 positive test deliberately establishes nonzero SE preview plus zero proportional hook preview, then expects successful single-asset fallback.
- **Inference / broken invariant:** This is a current source-and-test conflict with the explicit hook-zero rollback requirement, not an ambiguous inverse rounding equivalence. A successful fallback is still contrary to the supplied controlling rule.
- **Impact class:** Parent-operation atomicity / residual policy conformance. No monetary loss is established.
- **Fix direction:** Restore the stipulated hook-zero rollback behavior and assert it through the parent operation, or obtain an explicit scoped owner amendment before treating this fallback as compliant. Do not silently broaden the SE-zero exception.
- **Confidence:** High.
- **Relationship:** RC-06 fails to preserve Stage-1 REQ-01. Historical report said hard joins matched; without a source diff I do not certify when this contradictory fallback was introduced.

### Astra-04 — Failed supportsInterface probe can still lead to booking through the caller

- **Severity / class:** Low / CODE_DEFECT.
- **File and line:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:630–645`, `:558–559,583–584,531–539`.
- **Intended behavior:** FIX_PRD RC-06 `:296` and the assignment require the failed supportsInterface probe not to book; its failure remains distinct from accepted retention.
- **Observed fact:** `_retainSubSharePairResidual` catches the probe failure and returns false. Both joining loops immediately call `_pairQuoteIsZero`, which re-resolves the same SE and calls preview without the probe. A zero result returns true to an outer caller that books the full balance.
- **Inference / broken invariant:** Helper-local “return false” does not enforce the no-book property across callers. This conclusion is conditional on a dependency whose probe fails while preview returns zero; no claim that a particular deployed family exhibits that dependency behavior is made.
- **Impact class:** Failed-probe policy propagation / incorrect closure of negative-path acceptance.
- **Fix direction:** Preserve the failed-probe outcome across the caller chain rather than retrying retention through an indistinguishable boolean fallback. Add a production-path dependency-failure regression without mocking the SUT.
- **Confidence:** High on control flow; medium on practical family reachability.
- **Relationship:** Incomplete RC-06 execution, not a request for a new catch.

### Astra-05 — RC-04 tests never establish post-swap short-output rejection

- **Severity / class:** Low / TEST_DEFICIENCY.
- **File and line:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadExactOutputFill.t.sol:15–17,48–69`; source guard at Common `:531–536`.
- **Intended behavior:** FIX_PRD RC-04 `:229–233` and plan `:54` require execution-output mismatch rollback, independently of quote rejection.
- **Observed fact:** The test explicitly disclaims this boundary. The execution negative supplies an incomplete quote, which `_quoteSwapOut` rejects before token pull or pool.swap. The positive case checks a complete swap.
- **Inference / broken invariant:** Removing only the settlement guard would leave these focused tests' asserted outcomes unchanged. The source repair is present, but its second acceptance boundary is not protected by the inspected regression.
- **Impact class:** Regression-detection gap, not demonstrated short payout in current production.
- **Fix direction:** Obtain a production-path witness that reaches settlement and distinguishes paid-output mismatch from quote failure, with precise rollback assertions; if unavailable, keep this acceptance explicitly open rather than relabel the existing test.
- **Confidence:** High. No code defect found in the inspected new fill checks.
- **Relationship:** Partial RC-04 execution/test closure.

### Astra-06 — RC-06 focused fixture does not exercise the originally defective supported-interface branch

- **Severity / class:** Low / TEST_DEFICIENCY.
- **File and line:** `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/UniswapV4DetfLeftoverPreview.t.sol:13–15,29–35,102–112`.
- **Intended behavior:** FIX_PRD RC-06 `:286–305` specifically eliminates supported inverse-quote retention and requires zero/nonzero/reverting actual preview behavior.
- **Observed fact:** Setup asserts the optional exact-output interface is **false**. The comments correctly disclaim isolated helper-write coverage. The zero-call expectation for one-share inverse quoting is therefore tested in a fixture where the old supported branch would not have been selected either.
- **Inference / broken invariant:** Useful unsupported-path coverage does not distinguish the original supported-branch defect; the failed-probe outcome is also not tested here. This is a bounded finding about the focused suite, not proof that no differently named test exists anywhere.
- **Impact class:** Branch-specific regression coverage.
- **Fix direction:** Add supported-interface zero/nonzero/reverting-preview and failed-probe controls using real family implementations/dependency fixtures, while retaining the existing useful public-sweep assertions.
- **Confidence:** High in fixture limitation.
- **Relationship:** Partial RC-06 test execution; no requirement to mock the vault.

### Astra-07 — Current family README describes deleted V3 and withdrawn native-SY mechanics

- **Severity / class:** Low / DOCUMENTATION_GAP.
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/README.md:3,56,66–68`.
- **Intended behavior:** Current family guidance must match RC-03's supported replacement and RC-01's no-self-call architecture; historical validation must not silently certify changed code.
- **Observed fact:** README says both legacy V3/V4 are preserved unchanged and describes active Native SY context plus proxy self-call. V3 directory is absent; base no longer uses that context. Unqualified validation totals immediately follow the obsolete description.
- **Inference / broken invariant:** Readers cannot reliably distinguish supported source and current mechanics from historical release evidence. The retained-V4 warning and immutable-instance limitation remain relevant and should not be deleted indiscriminately.
- **Impact class:** Integration guidance / review provenance.
- **Fix direction:** Document V3 replacement, distinguish retained V4 and immutable deployments, describe current explicit-holder settlement including any still-open exception, and label the old validation identity/scope.
- **Confidence:** High.
- **Relationship:** Documentation left incomplete alongside RC-01/RC-03; not evidence that deleting source migrated instances.

### Astra-08 — V3 settlement input-ceiling failure still uses an output-shortage error

- **Severity / class:** Low / CODE_DEFECT.
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:527–530`.
- **Intended behavior:** An input maximum and an output fill are different failure conditions. FIX_PRD RC-04 `:239` expressly says **not** to rename the existing input-ceiling error in this item.
- **Observed fact:** `amountIn > maxAmountIn` reverts `UniswapV3Exchange_InsufficientOutput`; the new short-fill condition uses `UniswapV3Exchange_ExactOutputNotFilled` separately.
- **Inference / broken invariant:** The existing diagnostic misnames the failed bound. No input-cap bypass follows; the transaction still reverts. The prequote caller also has a correctly separate input error (`OutExecuteTarget:78`).
- **Impact class:** Error-contract quality / integration diagnosis.
- **Fix direction:** Preserve RC-04's scope; track a separately authorized diagnostic cleanup if desired, with compatibility assessment. Do not call this a reason the mandated fill repair failed.
- **Confidence:** High.
- **Relationship:** Existing out-of-repair diagnostic defect explicitly excluded by specification, not a newly introduced RC-04 defect or bad repair specification.

### Astra-09 — FullSpread shortage still precedes the required code-less-caller error

- **Severity / class:** Low / CODE_DEFECT.
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:81–86`, Common `:866–872`.
- **Intended behavior:** A-F01's D9/R13 exact-error obligation, also stated in `.claude/skills/indexedex-adversarial-testing/SKILL.md:155`, requires EOA rejection before credit evaluation. No supplied later amendment waives it.
- **Observed fact:** The route computes bounded credit and throws shortage before reaching `_secureTokenTransfer`'s caller gate. The current V3 recurrence test `ApexRecurrenceErrorOrder.t.sol:56–70` still expects the shortage diagnostic in its tested exact-output route.
- **Inference / broken invariant:** Historical diagnostic observation is not a conformance test. Rejection remains atomic; this is not a successful unauthorized credit or monetary loss finding.
- **Impact class:** Error-order contract / acceptance conformance.
- **Fix direction:** Separately authorize alignment or record a scoped owner exception; preserve funding checks. Do not conflate this with RC-01's newly added SY-entry gate.
- **Confidence:** High for inspected V3 route; no broad H/P closure claim.
- **Relationship:** Existing A-F01 remains open; no production repair was elaborated/authorized for it in FIX_PRD.

### Astra-10 — Named missing-registry regression still replaces the manager response

- **Severity / class:** Low / TEST_DEFICIENCY.
- **File and line:** `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/adversarial/Adversarial_TrustFlags.t.sol:55–65`.
- **Intended behavior:** D-F04 / R2.6 and IndexedEx testing skill `:29–35` require the production manager/registry path rather than mocking those SUT components.
- **Observed fact:** The regression uses `vm.mockCallRevert` on `indexedexManager.isDisabled`, then expects the injected bytes.
- **Inference / broken invariant:** It checks boundary propagation, not a genuine registry-without-query integration condition. It cannot alone close the named acceptance; no manager production fault is established.
- **Impact class:** False-positive integration evidence.
- **Fix direction:** Supply a production-valid configuration witness or explicitly reconcile applicability; retain the injection test only with its bounded meaning.
- **Confidence:** High.
- **Relationship:** Unexecuted accepted-report test corrective objective, not failure of an authorized FIX_PRD production repair.

### Astra-11 — Wings campaign still does not require randomized transition progress

- **Severity / class:** Low / TEST_DEFICIENCY.
- **File and line:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultInvariant.t.sol:33–50,62,75–88`; `ApexRecurrenceInvariantWitness.t.sol:56–83`.
- **Intended behavior:** A-F03 asks for non-vacuous campaign transitions and classified failures; recurrence A report `:25` specifically describes post-campaign additional-success checks (a historical plan/claim, not proof they exist).
- **Observed fact:** Original handler still catches all four failures. The new witness materially improves setup by requiring actual deposit/trade/rebalance/exit. During the randomized campaign its counters need only remain at least setup values. Additional successful actions are required in a separate deterministic test, not by campaign completion.
- **Inference / broken invariant:** Zero-initialization vacuity is addressed by the new witness, but a campaign in which every later money action fails can still pass. That is a narrower remaining issue than the original Medium finding.
- **Impact class:** Stateful regression-detection coverage.
- **Fix direction:** Define and verify non-vacuous successful campaign coverage without treating legitimate shrunk failure-only sequences as economic failures; report accepted action coverage separately if deterministic witnesses are the intended amended bar.
- **Confidence:** High in assertions; no claim an actual run had no successes.
- **Relationship:** Partial A-F03 test objective, not a newly established Wings production defect.

### Astra-12 — D41 family tests select quoteRate but still do not discriminate its successful numeric value

- **Severity / class:** Low / TEST_DEFICIENCY.
- **File and line:** `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_APEX_D41.t.sol:88–112`; weighted counterpart `:72–95`; curve-quad counterpart `:68–91`.
- **Intended behavior:** Accepted C-003 calls for family-level discriminating projected results, not merely positive output or selection/failure witnesses.
- **Observed fact:** New cases check selected dependency failure and exact call count, a real improvement. Successful live and projected rate values are equal, and success only requires positive quote. Older differing-rate cases still only require positive effective/rated balances.
- **Inference / broken invariant:** These assertions can establish dependency selection and fail-closed behavior without proving that a differing successful projected value affects the family calculation correctly.
- **Impact class:** Numeric projection regression coverage.
- **Fix direction:** Add independent expected-result or controlled-difference assertions for successful projected pricing in each family; do not replace the useful failure controls or change production on this evidence alone.
- **Confidence:** High for the three inspected suites; bounded, not a global absence claim.
- **Relationship:** Partial C-003 test objective, outside the six elaborated production remediations.

## Additional source checks and no-defect conclusions

### RC-02

Compared both branches directly: share-to-pool `CamelotV2StandardExchangeOutTarget.sol:657–672` retains its original check; zap-out now checks the computed **shares**, not LP units, at `:761–768`. Fee-share mint precedes the comparison but rolls back on rejection, as FIX_PRD permits. Tests separately exercise both flags and compare caller/vault balances, supply and payout. **No defect found in this repair's inspected source/assertions.** TestBase's complete transitive runtime deployment was not executed here.

### RC-03

Current named scripts select `deployUniswapV3FullSpreadStandardExchangeVaultDFPkg` at testnet/main Phase_05_Stage_04 `:56` and fee-DETF Script_05 `:129`. Current `UniswapV4DetfProductionSeDeployLib.sol:311–356` constructs FullSpread components/package. Bounded source searches found no old `deployUniswapV3StandardExchangeDFPkg` in contracts/scripts/test; Crane V3 protocol imports are not old IndexedEx package construction and were not misclassified.

FullSpread Common `:399–404` books full local balances; `:863–883` computes push availability without deployed inventory and measures actual pull delta. `UniswapV3FullSpreadLocalBook.t.sol:49–136` asserts non-dust books, actual outside-pool movement without book refresh, exact credit limits and pull behavior. Legacy V4 is present, with its old deployed-subtraction credit logic still at Common `:1267–1274`; RC-03 does **not** repair that family. **No defect found in the inspected V3 replacement credit repair.** Total file deletion history, all transitive test migrations and current builds were not certified.

### RC-04

Quote rejects either incomplete fill or unequal output. Settlement derives paid output from the opposite negative pool delta and compares to requested output, retaining the input maximum. `OutQueryTarget:79–86` and `OutExecuteTarget:76–94` actually consume those checks. Zero output still returns zero at Common `:261–263`. **No defect found in the new fill-check source itself.** The quoter was not blamed or proposed for modification. No baseline diff was available to prove that Hookless/Pons/Wings/Crane were never edited under this item; their RC-01 changes must not be automatically attributed to RC-04.

### RC-05

Rocket Common `:502–509` makes one excess decision. The soft helper caps by maximum and skips capped offers below minimum (`:448–451`), so a capacity below minimum does not force an illegal protocol deposit. Both exactness-mode callers stake after mint and, for exact-output, after refund. `RocketPoolSleeveExcessStake.t.sol:17–69` checks accumulation and capacity; corrected `RocketPoolRETHStandardExchange_APEX_Recurrence.t.sol:9–37` tests combined credits in both modes. **No defect found in corrected sleeve policy.** The stale recurrence NatSpec at `:7` still describes separate allocations, but its assertions now correctly expect combined excess. This is documentary residue, not evidence to restore the withdrawn objective.

EtherFi Common `:704–720` still has a booked-first split plus remaining excess, unlike Rocket. This refutes an assumption that today's Rocket helper was simply copied into EtherFi. It does not establish an untouched history, and the independently read EtherFi SY override belongs to RC-01 rather than RC-05.

### RC-06

Within `_retainSubSharePairResidual` alone, a successful preview of the actual amount is now the signal; full `balanceOf(this)` is booked, one-share inverse quoting is gone, and preview is not caught. **No defect found in those narrow statements.** They do not close surrounding caller behavior or the supported-interface and failed-probe tests, as detailed above.

### RC-07 / REQ-08

Owner ignore is explicitly recorded in the related FIX_PRD and plan. The current script still limits discovery to baseline parents, consistent with the historical limitation. That is not a fake fix visible in current code. Proving historical non-edit requires a diff/source identity not available here. The unresolved source/build/runtime-size/selector evidence obligation remains separate; no actual oversize facet is alleged.

## Files examined without a newly established defect

“Without defect” is limited to the portions and properties inspected, not a whole-contract audit. In addition to the positive RC-02/03/04/05/06 source conclusions above and the per-inheritor entries, these current files/assertions were examined without finding a new defect:

- `contracts/utils/LocalCreditLib.sol` — local availability/cap and bytecode rejection.
- `contracts/vaults/standard/erc4626/ERC4626StandardYieldTarget.sol` and Common `:276–293` — explicit holder burn.
- `contracts/protocols/staking/{lido/LidoWstETH,rocket-pool/RocketPoolRETH,etherfi/EtherFiWeETH}StandardYieldTarget.sol` — each actual file read separately; locked vault-held burn/payout/sync.
- `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardYieldTarget.sol` and `aave/cross-version/AaveCrossVersionLoopExchangeOutTarget.sol:24–34` — explicit vault-held settlement entries.
- `contracts/protocols/dexes/balancer/v3/pools/BalancerV3PoolStandardExchangeTarget.sol:46–53,132–224` — explicit holder and authenticated native Vault settlement.
- Hookless and Pons OutMultiQueryTarget, Common share-delivery and InBase exact-input redemption portions listed in the inventory — separately inspected, not inferred from a shared name.
- Wings SYTarget and Money `:141–181` — amount-only holder selection/burn and receiver path.
- `CamelotV2ZapOutMaxAmountIn.t.sol`, `RocketPoolSleeveExcessStake.t.sol`, `UniswapV3FullSpreadLocalBook.t.sol` at their full paths identified above — meaningful narrow repair assertions.
- The hookless, Pons and Wings `*VaultHeldRedeem.t.sol` suites at the paths listed in the inventory's corresponding test families — separate balances/receiver/no-exchangeIn assertions; full runtime closure not claimed.
- `RebasingAwareERC4626_APEX_Recurrence.t.sol`, `EtherFiWeETHStandardExchange_APEX_Recurrence.t.sol`, `ReceiptBackedERC4626_APEX_Recurrence.t.sol`, shared cross-interface behavior `:261–334`, `AaveCrossVersionLoop_APEX_Recurrence.t.sol`, Wings recurrence conservation/exact-error tests, Balancer-quad recurrence test — substantive additions, not historical-test absence.
- Orbital Apex008 new exact-burn/earlier-rejection assertions and representative D49 real-dependency pause assertions — useful bounded evidence, without claiming they resolve all original acceptance wording.

## Remaining limitations / handoff

1. Current source identity/change attribution and separate production-implementation authorization remain unverified. The report evaluates observed working-tree text, not a certified immutable snapshot or deployed bytecode.
2. No build/test/log authenticity claim is made. In particular, production-first FactoryService tests can depend on artifact freshness; source assertions do not establish which artifacts were executed elsewhere.
3. RC-01 inventory is complete for the bounded direct-inheritance search, but not every transitive settlement helper, facet cut, family test base or deployed instance was fully audited. Additional hook families are explicitly listed rather than assumed closed.
4. Current C-004 whole-supply rate design requires its own later-authority reconciliation. Full matrix denominator, all six D49 auth/dependency paths and REQ-08 release evidence were not exhaustively verified. These limitations prevent `INSPECTION_COMPLETE` for the whole assignment.
5. No external library documentation claim was needed: this was repository business-logic/source review, so no external tool received repository code. No supplied path was bypassed through secret-file searches.
6. Historical claims that production had not been repaired and recurrence tests were not run describe those reviewers' sessions. The present tree visibly contains production repairs and changed tests; I neither inherit historical “not repaired” status nor infer fresh green runs.

**Return to coordinator/human and stop. No implementation, remediation PRD, cross-review, or additional review wave is authorized by this report.**
