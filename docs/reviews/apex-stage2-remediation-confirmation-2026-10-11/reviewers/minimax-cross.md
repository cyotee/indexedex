# MiniMax M3 — APEX Stage 2 remediation confirmation, cross-review

- **Date:** 2026-10-11
- **Reviewer:** MiniMax M3 (continuing session per `APEX_STAGE2_REVIEW_PRD.md` §12.1)
- **Original first pass:** `docs/reviews/apex-stage2-remediation-confirmation-2026-10-11/reviewers/minimax-original.md`
- **Scope of this file:** Bounded cross-review of the three peer originals (Astra, Grok, Kimi). Original is not revised.
- **Method:** Recheck disputed material claims against current source and the controlling FIX_PRD / Stage-1 / family documents. No build/test/forge/execution. No peer-original as authority; each is treated as untrusted evidence.

---

## 1. Recheck summary

Three of my original dispositions are corrected on the basis of re-inspection and peer corroboration. One documentation-gap disposition is upheld. One narrow repair disposition is upheld with an additional unclosed-gap note. One blanket `NOT_A_REMEDIATION` disposition is refined to distinguish "no authorized remediation" from "unauthorized recurrence test work exists but does not close the locked finding."

I read each peer original in full before drafting this file. No `*-cross.md` was read.

---

## 2. Disposition corrections

### 2.1 RC-01 — corrected from `CONFIRMED_EXECUTED` to `PARTIALLY_EXECUTED`

**Agreed with:** Astra (`Astra-02`), Grok (`Grok-1`), Kimi (`K3-01`).

**Where my original erred:** My first-pass inventory of `UniswapV4StandardExchangeOutMultiQueryTarget.sol` (line 16 of my original) said the legacy V4 family "burns `address(this)` through explicit-holder settlement." The file does not burn shares directly. Re-read confirms the override at `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol:17-25`:

```solidity
function _redeemVaultHeld(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_)
    internal override returns (uint256 amount_)
{
    // The existing guarded SE entrypoint explicitly accepts self-calls using vault-held shares.
    // Reuse its execution delegate instead of embedding a second settlement engine in the SY facet.
    amount_ = IStandardExchangeIn(address(this)).exchangeIn(
        IERC20(address(this)), shares_, IERC20(tokenOut_), minimum_, receiver_, false, block.timestamp
    );
}
```

`IStandardExchangeIn(address(this)).exchangeIn(...)` is an external call whose `msg.sender` becomes the vault. The accompanying acceptance branch at `UniswapV4StandardExchangeCommon.sol:1299-1305` (peers cite `:1302-1305`) credits vault-held shares via `msg.sender == address(this) && !pretransferred`. This is the exact call shape FIX_PRD §RC-01 §"Required repair" item 1 and item 3 explicitly withdraw ("Do not keep the external self-call…Burn `address(this)` through a shared internal or library function…Do not re-enter `exchangeIn` to obtain a different `msg.sender`."). `FIX_PRD.plan.md` Step 5 names legacy V4 in scope ("Legacy V4 out-query targets that inherit it. Fix their internal-balance call shape here. Do not turn this step into an accounting repair, and do not delete the old V4 package.").

**Severity / impact class:** Medium / CODE_DEFECT. The base `NativeStandardYieldTarget.redeem` still rejects a code-less caller with `EOAPretransferNotAllowed` before settlement (`NativeStandardYieldTarget.sol:41-44`) and requires vault-held shares (`_requireVaultHeldShares` at `:75-78`); the unguarded-burn exposure that motivated the original specification is closed at the entry. The remaining defect is retention of the forbidden mechanism on one in-scope inheritor and the loss of the "inventory every inheritor" acceptance criterion. No new unauthorized-burn or third-party-wallet-burn path is asserted.

**Fix direction (prose):** Convert the legacy V4 internal-balance path to the same explicit-holder settlement shape used by the other families (burn `address(this)` without re-entering `exchangeIn` through a self-call), and remove or gate the `msg.sender == address(this) && !pretransferred` acceptance branch in the legacy V4 share-delivery helper, without touching its accounting rules and without deleting the package. Add a production-proxy assertion for this family; the V3 / hookless / Pons / Wings tests do not cover it.

**Confidence:** High.

**Relation to the remediation:** Failed execution of RC-01 for one in-scope inheritor. Not a bad specification.

---

### 2.2 RC-01 (V3 ordinary EOA redemption) — corrected from "no defect" to a Medium regression

**Agreed with:** Astra (`Astra-01`).

**Where my original erred:** I read `UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol:39-54` and described ordinary redemption as "burns the original caller's own shares" in section 3.1. The override does not burn the caller directly. Re-trace:

`NativeStandardYieldTarget.redeem(receiver_, shares_, tokenOut_, minimum_, false)` enters `_standardRoute(IERC20(address(this)), shares_, IERC20(tokenOut_), minimum_, receiver_, false)`.

`UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget._standardRoute` at lines 39-54:
- `in_ == address(this)` and `internal_ == false`, so the `if (address(in_) != address(this) || internal_)` guard is false; it does not return `super._standardRoute`.
- It runs `ERC20Repo._transfer(msg.sender, address(this), amount_)` (line 45) — moves the caller's shares onto the vault.
- Then `address(this).delegatecall(data_)` where `data_` encodes `exchangeIn(IERC20(address(this)), amount_, IERC20(out_), minimum_, receiver_, true, block.timestamp)` (lines 46-49). The delegatecall preserves `msg.sender` as the original caller and routes into the V3 FullSpread `exchangeIn` facet.

The V3 FullSpread `exchangeIn` implementation (`UniswapV3FullSpreadStandardExchangeVaultInTarget.sol:25` / `InMultiTarget.sol:11-28`) eventually calls `_secureTokenTransfer(tokenIn, amountIn, pretransferred=true)` (`Common.sol:863-884`), which runs `LocalCreditLib.requirePretransferCaller(msg.sender)` at `:867`. For an EOA caller, that reverts with `EOAPretransferNotAllowed`.

The result: ordinary share redemption by an EOA on the production V3 FullSpread proxy reverts before any burn. The D9/R13.1-2 caller's bytecode check at the internal-balance entry does not apply here, because `internalBalance_ == false`, but the staged ordinary path's `pretransferred=true` reshape puts the EOA behind the same bytecode check.

The new `UniswapV3FullSpreadVaultHeldRedeem.t.sol:test_RC01_ordinaryRedeem_burnsCallerShares` (lines 96-104) calls as `address(this)` (a contract), which is why the regression is masked in the focused regression.

**Severity / impact class:** Medium / CODE_DEFECT. Availability regression for ordinary wallet users; not an unauthorized-burn path or demonstrated principal loss. The internal-balance path itself is closed.

**Fix direction (prose):** Distinguish the externally staged ordinary redemption from a true external pretransfer. Share-delivery for the ordinary path should burn the original caller explicitly (e.g. via `ERC20Repo._burn(msg.sender, amount_)` and pay the receiver through a non-pretransfer route) rather than misclassify internally staged shares as an external pretransfer that triggers `requirePretransferCaller`. Preserve the external true-flag gate. Add an ordinary funded EOA assertion alongside the contract-caller assertion.

**Confidence:** High in call-path conclusion; no runtime reproduction performed. Whether the change is a regression introduced by the RC-01 repair versus an older shape is not established (no diff was available to me). The peers (Astra-01) reach the same conclusion.

**Relation to the remediation:** Failed execution of RC-01's stated acceptance criterion "An ordinary redemption still burns the original caller's own shares" on the V3 FullSpread family, masked by a contract-only test caller.

---

### 2.3 RC-04 — refined from `CONFIRMED_EXECUTED` to `PARTIALLY_EXECUTED` (source present, post-swap guard untested)

**Agreed with:** Astra (`Astra-05`), Grok (`Grok-3`), Kimi (`K3-04`).

**Recheck:** The two source checks exist at `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:281-284` (`_quoteSwapOut`) and `:505-536` (`_swapExactOut`). The acceptance criterion has two layers: quote rejection and settlement rejection. The focused test at `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadExactOutputFill.t.sol:15-17,48-69` (disclosed by the test itself) supplies an unfillable quote and reverts at preview/quote time before `pool.swap`. The fixture's pool cannot produce a quote-filled-but-settlement-short outcome, and the test does not claim coverage of the post-swap output-delta guard.

Kimi's `K3-04` reads `_executeQuotedSwapOut` (`OutExecuteTarget.sol:68-95`): it calls `_quoteSwapOut` first (line 77) and then `_swapExactOut` only when the quote is acceptable. A short settlement is unreachable through this caller as long as the quote stage rejects every short outcome. My original conflated the two layers.

**Severity / impact class:** Low / TEST_DEFICIENCY. The source repair is present in both required locations. The second-layer acceptance bullet ("settlement verifies delivered output against the requested amount") is unwitnessed by the inspected regression; this is a coverage gap, not a demonstrated shortfall.

**Fix direction (prose):** Add a production-first witness in which quote and settlement can diverge (or document why such divergence is impossible on this route and obtain acceptance of quote-stage-only coverage). Do not weaken the existing checks. Do not change the Crane quoter.

**Confidence:** High that the test does not cover the guard. Medium that a hermetic pool can reach a short execution independently of the quote check; that reachability was not demonstrated.

**Relation to the remediation:** Incomplete execution of RC-04's test acceptance. The source repair is present. Not a bad specification.

The naming caveat (`UniswapV3Exchange_InsufficientOutput` at `_swapExactOut:529` is the input-ceiling revert name and is preserved per FIX_PRD §Non-goals) remains as recorded in my original; this is a separately-documented constraint, not part of the partial-execution finding.

---

### 2.4 RC-06 — narrow repair disposition upheld; Stage-1 hook-zero gap noted as unclosed

**Where I agree with peers:** Astra (`Astra-03`, `Astra-04`), Grok (`Grok-5`), Kimi (`K3-06`).

**Recheck of RC-06 narrow helper:** `_retainSubSharePairResidual` (`UniswapV4DetfCommon.sol:625-638`) uses `previewExchangeIn(pair, amount, se) == 0` and does not call `quoteInputForExactShares`. The `supportsInterface` probe catch returns false. The reserve write is the full local balance. The narrow RC-06 repair is in place.

**Recheck of hook-zero callers (separately flagged by all three peers):** `_entryJoinResidualAtomic` returns `0` when `_hook().previewJoinUnbalanced(...) == 0` (`:615`); the caller loop in `_joinResidualCapped` / `_joinResidualUnbalanced` at `:550-597` then breaks on `lpOut_ == 0` and continues to fall through to `_tryJoinResidual`'s unconditional full-balance booking at `:543-545`. This contradicts Stage-1 OD-08 / REQ-01's explicit hook-zero-rollback rule. FIX_PRD §RC-06 did not authorize this hook-zero repair; no owner exception is recorded.

**Disposition:** Keep RC-06 itself as `CONFIRMED_EXECUTED` against the narrow FIX_PRD §RC-06 text (the helper is closed against that elaboration). Add an explicit Stage-1 REQ-01 hook-zero continuity note: the surrounding residual joins still do not roll the parent back on a hook preview of zero. This was `D-F03` in the accepted report and remains `STAGE1_OPEN` for the hook-zero leg. RC-06 did not authorize or attempt a fix; the gap is not closed by RC-06.

**Severity / impact class:** Medium / CODE_DEFECT (hook-zero continuity, not RC-06 itself). Parent-operation atomicity / residual policy. No monetary loss is established. The `supportsInterface` catch at `:630-633` returns false, does not itself book; `Astra-04`'s observation that `_pairQuoteIsZero` at `:641-646` could still book through a separate path on a failed-probe-with-preview-zero dependency is conditionally correct but bounded by whether any production family exhibits that dependency behavior. Not asserted here.

**Fix direction (prose):** Restore hook-preview-of-zero and hook-join-failure rollback through the parent operation, or obtain a scoped owner amendment. Do not add a new catch around the SE preview. Do not change bond / threshold / vesting economics.

**Confidence:** High on cited control flow. Medium on universal reachability (the function is the production sweep path; not every family was re-traced).

**Relation to the remediation:** Not a failed execution of RC-06. RC-06 is the narrow helper. The hook-zero rollback is a separate unclosed locked Stage-1 requirement that was not elaborated in `FIX_PRD.md` for this round.

---

### 2.5 RC-03 — stale README disposition upheld as DOCUMENTATION_GAP

**Agreed with:** Grok (`Grok-2`), Kimi (`K3-02`, `K3-03`), and partly Astra (`Astra-07`).

**Recheck:** The legacy `contracts/protocols/dexes/uniswap/v3/` directory was confirmed absent (read returned "File not found"). All four named scripts (`scripts/foundry/anvil_robinhood_testnet/Phase_05_Stage_04_UniswapV3StandardExchangePkg.sol:56`, the `main` mirror at the same line, `scripts/foundry/anvil_robinhood_fee_detf/Script_05_DeployUniV3SeOnRichPool.s.sol:129`, and `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol:85-91,311-356`) now deploy the FullSpread package. FullSpread credit is `balanceOf(this) - _reserveOfToken(token)` (Common `:863-873`).

The README at `contracts/vaults/standard/exchange/protocols/uniswap/README.md:3` and `:56` continues to describe a pre-RC-03 state and the withdrawn self-call mechanism. Kimi (`K3-03`) extends the documentation gap to `contracts/vaults/detf/UNIFIED_DETF_PRODUCTION_SE_HOOK_MATRIX_TEST_PRD.md:131,186,320,526` (which still cites `TestBase_UniswapV3StandardExchange` and `UniswapV3StandardExchangeDFPkg.deployVault`), `docs/security/audit/areas/A-se-univ3.md:55`, and the retained launch-stage script filename `Phase_05_Stage_04_UniswapV3StandardExchangePkg.sol`. I agree with the extension; I had scoped it only to the README.

**Disposition stays.** A stale README (and a few stale PRD/audit-area citations) is a documentation gap, not a failed execution of the deletion. RC-03 source execution is `CONFIRMED_EXECUTED`. The documentation residue is recorded as Low `DOCUMENTATION_GAP`.

**Severity / impact class:** Low / DOCUMENTATION_GAP. Reader can treat a deleted package as current, or restore the withdrawn call shape from the README prose.

**Fix direction (prose):** Update the family README to state that the legacy V3 package was removed under RC-03 and that V3 FullSpread is the supported V3 vault; describe current explicit-holder SY settlement; label preserved-hash JSONs explicitly as historical baseline. Apply the same correction to the cited PRD/audit-area files. The retained launch-stage script filename is cosmetic but worth annotating with the substitution.

**Confidence:** High.

**Relation to the remediation:** Documentation residue of an otherwise-executed deletion; not a new vulnerability and not a failed RC-03 specification.

---

## 3. Refinement on `NOT_A_REMEDIATION` blanket (A-F01, A-F02, A-F03, B-03, B-04, B-05, C-006, D-F01, D-F02, D-F04, D-X01)

**Agreed with the peers' split:** My original blanket may have hidden unauthorized recurrence test work that exists but does not close the locked requirement.

**Refined disposition:** Same `NOT_A_REMEDIATION` for each item (no FIX_PRD-authorized production repair exists), but the recurrence handoff adds specific test work that I now cite alongside the row. None of the recurrence tests closes the original finding.

| ID | Disposition | Refinement (test work exists at site, unauthorized, does not close) |
|---|---|---|
| A-F01 | NOT_A_REMEDIATION | Accepted report's finding persists. Shortfall-before-guard order at `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:81-88` (Common `:866-867`) and hookless mirror at `:94-104,159-165`; Pons mirrored (bounded by accepted report). New `ApexRecurrenceErrorOrder.t.sol` (V3 release, hookless, Pons) documents the current order (`TransferDeltaInsufficient` for underfunded EOA; `EOAPretransferNotAllowed` only once funded) rather than asserting D9/R13 exact-error conformance. (See `Grok-7`, `K3-06`.) |
| A-F02 | NOT_A_REMEDIATION | `UniswapV4UpperLowerWingsStandardExchangeVaultSecurity.t.sol:39` still uses bare `vm.expectRevert()` (bounded spot check). New `test/.../upperLowerWings/ApexRecurrenceExactErrors.t.sol` adds exact-error probes (Astra-02, Kimi-07); unrun per recurrence handoff; not FIX_PRD-authorized; does not replace the cited file. |
| A-F03 | NOT_A_REMEDIATION | `UniswapV4UpperLowerWingsStandardExchangeVaultInvariant.t.sol:33-51` handlers still swallow failures (`catch {}`); success counters unasserted at `:75-89`. New `ApexRecurrenceInvariantWitness.t.sol` adds a deterministic funded-control witness but the campaign invariant still does not require randomized successful actions in-flight. (Astra-11, Kimi-07.) |
| B-03 | NOT_A_REMEDIATION | New `RebasingAwareERC4626_APEX_Recurrence.t.sol` adds custody callback-added-share retention and consumed-credit retry (recurrence handoff); unrun; not FIX_PRD-authorized; historical `acceptance.json:498-507` mapping not corrected. |
| B-04 | NOT_A_REMEDIATION | New `EtherFiWeETHStandardExchange_APEX_Recurrence.t.sol` adds EtherFi sleeve arithmetic and zero/full target tests (recurrence handoff); unrun; not FIX_PRD-authorized; EtherFi code was not given RC-05 and remains a different split helper. |
| B-05 | NOT_A_REMEDIATION | `Behavior_ReceiptBackedERC4626_CrossInterface.sol` adds `test_RECURRENCE_B05_*` and a native-SY EOA case (Astra-05, Kimi row). Generic-over-real-Stata dispatch is exercised; both-host setup added (Astra-05); execution unverified; not FIX_PRD-authorized. |
| C-001 | NOT_A_REMEDIATION | Inventory/evidence item. Wings `CONSUMER_RESULTS.md:5-15` still declares not every legal mask and lists pending domains; no exhaustive denominator derived. |
| C-002 | NOT_A_REMEDIATION | Orbital Apex008 new exact-burn / earlier-rejection assertions are useful bounded evidence (`Apex008.t.sol:236-274`) but are not proof of the historical cap-call failure. |
| C-003 | NOT_A_REMEDIATION | D41 family tests now exercise selected quoteRate failures and exact call count, but live and projected rates are equal — discriminating numerical result remains unproven (Astra-12). |
| C-004 | NOT_A_REMEDIATION | Morpho / wrapped rate suites now assert whole-supply / one-call behavior (`Morpho RateProvider.t.sol:67-120`, wrapped `:152-189`); bounded search is not restored; current controlling rate-design authority not fully traced (Astra row). |
| C-005 | NOT_A_REMEDIATION | All six D49 suites contain new real-underlying-pause tests (`constProd D49.t.sol:37–69` proves rollback / reopening); handoff failure tests still mock router responses at `:179-198`. |
| C-006 | NOT_A_REMEDIATION | New `ApexRecurrenceConsumerConservation.t.sol:57-68` measures before balances and exact share conservation across five callers; original tautology remains at `FamilyConsumers.t.sol:59`. The replacement assertions do not close the locked requirement because the original file is unchanged and the recurrence file is not FIX_PRD-authorized. |
| C-007 | NOT_A_REMEDIATION | New `Balancer quad _Recurrence.t.sol:19-50` enters real manager unlock, records exact `NotPoolManager`, checks reserves / supply and funded authorized swap; no new production guard was needed; the file is unrun. |
| D-F01 | NOT_A_REMEDIATION | Script discovery still parent-only. RC-07 owner ignore recorded. REQ-08 evidence obligation is preserved as a separate open item. |
| D-F02 | NOT_A_REMEDIATION | No current causal run chain. Historical accepted/recurrence identities preserved; not in scope for this round. |
| D-F04 | NOT_A_REMEDIATION | `Adversarial_TrustFlags.t.sol:55-64` still `vm.mockCallRevert`s `indexedexManager.isDisabled` for a property the production-first rule reserves for real integration (Grok-7, Kimi-07). No manager production fault is established. |
| D-X01 | NOT_A_REMEDIATION | Aave `APEX_D43.t.sol:97,114` still the same two. New `AaveCrossVersionLoop_APEX_Recurrence.t.sol:26-178` adds equal-unit setup, initial/later/zero caps, both debt legs, real frozen-reserve rollback, reopening, and elapsed-interest capacity boundary; unrun; not FIX_PRD-authorized. |

**Severity / impact class:** Low aggregate / TEST_DEFICIENCY or EVIDENCE_GAP. No new production defect introduced. No FIX_PRD item elaborated any of these; the recurrence tests do not close the original findings.

**Fix direction (prose):** If the owner wants any of these closed, specify and authorize each repair explicitly (and run the tests), or record an acceptance of the gap. Do not read unrun recurrence probes as closure. Do not invent a repair in this round.

**Confidence:** High on cited lines. Bounded: other files may contain better witnesses that this pass did not find.

---

## 4. Items where my original disposition stands

- **RC-02** stays `CONFIRMED_EXECUTED`. Source comparison is in place at `CamelotV2StandardExchangeOutTarget.sol:761-764` and the focused test covers both flags and the exact error. No peer disputes the source execution; no peer disputes the test.
- **RC-05** stays `CONFIRMED_EXECUTED`. The Rocket helper is the single excess decision; EtherFi has no `_bestEffortStakeOverageTowardTarget`. Peers agree on execution. The dispute would only be about RC-05's *specification*, but FIX_PRD's correction controls over the earlier "never combine" draft.
- **RC-07** stays `NOT_A_REMEDIATION` per owner ruling. Script is unedited; ignore is recorded. Peers agree.
- **A-F01** stays `NOT_A_REMEDIATION` (no FIX_PRD elaboration). My §3 row above preserves the persistence note.
- **D-F03 (Stage-1 REQ-01) hook-zero continuity** is recorded separately in §2.4 as not closed by RC-06.

---

## 5. New findings raised by peers that I adopt

I do not "adopt" peer findings as my own; I record here that I agree with the underlying control-flow observation and that I had not surfaced it. None of these are new discoveries by me on this pass; they are corroborations of what the peers already wrote.

- **Grok-1 / Astra-02 / K3-01:** Legacy V4 self-call retained. See §2.1.
- **Astra-01:** V3 ordinary EOA redemption reverts behind `requirePretransferCaller` because the staged ordinary path misclassifies internally staged shares as an external pretransfer. See §2.2.
- **Astra-05 / Grok-3 / K3-04:** RC-04 settlement guard has no direct test witness. See §2.3.
- **Astra-03 / Grok-5 / K3-06:** DETF hook preview of zero still does not roll the parent back; RC-06 helper is narrow. See §2.4.
- **Grok-2 / K3-02 / K3-03 / Astra-07:** Stale README / PRD / audit-area citations of the deleted legacy V3 package. See §2.5.

I do not adopt:
- **Astra-04** ("failed probe can still lead to booking through `_pairQuoteIsZero`"). The observation is plausible at the helper level but its reachability across production families is bounded and not asserted. I record it as a separate conditional observation rather than as a closure-blocking finding, and I keep RC-06 narrow disposition.
- **Astra-12** ("successful live and projected rates are equal; discriminating numeric result unproven") — accurate for the inspected D41 suites. I keep C-003 `NOT_A_REMEDIATION`.

---

## 6. Unresolved dissent

- **Astra vs. my original on the V3 ordinary redemption.** I now agree with Astra-01 that ordinary V3 FullSpread share redemption by an EOA is reverted before any burn because the staged ordinary path is reshaped to look like an external pretransfer. My original missed this by reading only the test caller (`address(this)`), not the delegatecall-to-`exchangeIn`-with-`pretransferred=true` chain.
- **Grok vs. my original on RC-04.** I agree with Grok-3 that the post-swap guard is untested by the inspected fixture and that this is `PARTIALLY_EXECUTED`, not `CONFIRMED_EXECUTED` with a caveat. The caveat ("naming only") is preserved separately.
- **Kimi vs. my original on the documentation gap.** I agree with K3-03 that the gap is broader than just the README; the same legacy V3 citation appears in the unified DETF PRD, the security audit area file, and the launch-stage script filename. None of these reopens RC-03 execution; all are documentation residue.
- **All peers agree that RC-01 is at most PARTIALLY_EXECUTED.** My original labeled RC-01 `CONFIRMED_EXECUTED`; I now agree this is wrong because the legacy V4 inventory entry is wrong.
- **All peers agree RC-06 is partial because of the hook-zero path, not the helper.** I agree with this split: the narrow helper is closed; the surrounding callers fall through to a hook-zero-acceptance path that contradicts Stage-1 OD-08. My original recorded the helper closure but did not flag the surrounding hook-zero continuity.
- **No peer asserts four-member consensus.** I do not claim consensus either.

---

## 7. Updated disposition table

Status vocabulary is unchanged.

| ID | Original disposition | Cross-review disposition | Net change |
|---|---|---|---|
| RC-01 | CONFIRMED_EXECUTED | **PARTIALLY_EXECUTED** (legacy V4 retains forbidden self-call; V3 ordinary EOA redemption is reverted behind `requirePretransferCaller`) | Corrected |
| RC-02 | CONFIRMED_EXECUTED | CONFIRMED_EXECUTED | Same |
| RC-03 | CONFIRMED_EXECUTED with documentation gap | **CONFIRMED_EXECUTED** with documentation gap extended to additional files | Same, scope extended |
| RC-04 | CONFIRMED_EXECUTED with naming caveat | **PARTIALLY_EXECUTED** (source present, settlement guard untested); naming caveat retained as informational | Corrected |
| RC-05 | CONFIRMED_EXECUTED | CONFIRMED_EXECUTED | Same |
| RC-06 | CONFIRMED_EXECUTED | **CONFIRMED_EXECUTED** (narrow helper) + Stage-1 REQ-01 hook-zero continuity gap is **unclosed** | Narrow repair unchanged; surrounding gap recorded |
| RC-07 | NOT_A_REMEDIATION | NOT_A_REMEDIATION | Same |
| A-F01 | NOT_A_REMEDIATION | NOT_A_REMEDIATION (refined: recurrence probe documents order rather than asserting D9/R13 conformance) | Refined |
| A-F02 / A-F03 / B-03 / B-04 / B-05 / C-001 / C-002 / C-003 / C-004 / C-005 / C-006 / C-007 / D-F01 / D-F02 / D-F04 / D-X01 | NOT_A_REMEDIATION (blanket) | NOT_A_REMEDIATION (each), with explicit "unauthorized recurrence test work exists but does not close" notes where applicable | Refined |

---

## 8. Files re-examined in this cross pass

- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol` — full read.
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol` — full read.
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol` (excerpts `:863-884`, `:918-920`) — to trace `requirePretransferCaller` and the `_secureShareDelivery` chain.
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol` (excerpts `:183-228`) — to confirm `_executeZapOutExactIn` and the `_burn(address(this), …)` calls.
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInTarget.sol` (excerpts) — to trace `exchangeIn` → `_secureTokenTransfer`.
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol` (excerpts) — to confirm second `requirePretransferCaller` site.
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol` (excerpts `:490-656`) — to trace hook-preview-of-zero callers of `_retainSubSharePairResidual`.
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol` — `test_RC01_ordinaryRedeem_burnsCallerShares` caller confirmed as `address(this)` (a contract), which is why the EOA regression is masked.

No peer `*-cross.md` was read. No new test execution.

---

## 9. Session limitations

- No build, test, simulation, fork, RPC, deployment, shell, or git diff was performed.
- The recurrence tests cited in §3 are present in the tree but were not executed; their authored content was not inspected line-for-line beyond the citations already in my original and the cross-review additions above.
- The hook-zero rollback path's universal reachability is not asserted; only the cited control flow is.
- The legacy V4 ordinary redemption path's interaction with the new shared `requirePretransferCaller` was not re-traced to its downstream false-flag burn; Kimi (`K3-01`) flagged this as a medium-confidence residual. I record Kimi's residual as well-bounded but not refuted by this pass.
- No four-member consensus is claimed. The cross-review dispositions are my agreement with peer observations and my own re-derivation, not a vote.

---

## 10. Output paths

- This cross-review file: `docs/reviews/apex-stage2-remediation-confirmation-2026-10-11/reviewers/minimax-cross.md`.
- Original file is preserved at `docs/reviews/apex-stage2-remediation-confirmation-2026-10-11/reviewers/minimax-original.md` and was not edited.
- `REMEDIATION_PRD.md` is intentionally not authored.
- No code, test, config, or instruction was edited.

STOP. Awaiting coordinator consolidation.