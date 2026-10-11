# Grok cross-review — APEX Stage 2 remediation confirmation

- **Reviewer:** Grok (`xai/grok-4.7`). This file does not replace `grok-original.md`.
- **Peers read:** Astra, MiniMax M3, and Kimi K3 originals only. No `*-cross.md` file was opened.
- **Recheck:** current source and FIX_PRD / Stage-1 OD-08. No Forge run. Peer text is untrusted evidence, not authority.
- **Consensus:** not claimed. Three reviewers can agree and still be wrong. Runtime remains unverified.

## Corrections to my original

1. **RC-01 ordinary V3 EOA redemption.** My original said ordinary redemption still burns the original caller and cited the V3 test. That test uses `address(this)`, a contract. Recheck shows an ordinary code-less caller is rejected. This is a failed RC-01 execution I missed. Agree with Astra-01. Object to MiniMax and to Kimi's ordinary-caller closure sentence.
2. **RC-03 status.** My original marked the item PARTIALLY_EXECUTED because the README is stale. The deleted package is not restored by that text. Code execution of the deletion and caller retarget is confirmed. The README remains a documentation gap, not a failed deletion.
3. **RC-04 severity.** The settlement guard is present. The missing witness is a test gap, not a missing source check. I lower that finding from Medium to Low. I do not change the status to CONFIRMED_EXECUTED.
4. **RC-06 status.** The helper body matches the zero-preview signal. The callers do not. I withdraw CONFIRMED_EXECUTED for the item. It is PARTIALLY_EXECUTED against OD-08 and the "failed probe must not book" rule.
5. **C-006.** I did not credit `ApexRecurrenceConsumerConservation.t.sol`. Those assertions are real and not tautological. They do not close the cited original line, and they were not run. The item stays unauthorized.

## RC-01 — legacy V4 self-call, and ordinary V3 EOA rejection

**Agree with Astra and Kimi. Object to MiniMax.**

**Fact.** Legacy V4 `_redeemVaultHeld` is not an explicit-holder burn. It is an external call:

```22:24:contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol
amount_ = IStandardExchangeIn(address(this)).exchangeIn(
    IERC20(address(this)), shares_, IERC20(tokenOut_), minimum_, receiver_, false, block.timestamp
);
```

The ordinary override at `:30-34` moves the caller's shares onto the vault and then sets `internal_ = true`, so that same external call is used for ordinary redemption too. Legacy Common still accepts that forged caller at `UniswapV4StandardExchangeCommon.sol:1302-1305` (`msg.sender == address(this) && !pretransferred`).

**Fact.** MiniMax lists this file among overrides that burn `address(this)` and treats absence of the token `address(this).call` as closure (`minimax-original.md` RC-01 row and §3.1). A typed interface call on `address(this)` is still an external call. FIX_PRD `:83-85` and `:93` forbid re-entering `exchangeIn` to change `msg.sender`. The plan names legacy V4. MiniMax's CONFIRMED_EXECUTED is refuted for this family.

**Fact.** The shared entry does reject a code-less internal-balance caller before settlement (`NativeStandardYieldTarget.sol:41-44`). I do not upgrade this family's remaining defect to the old unauthenticated-EOA claim. Severity stays Medium. Impact class: caller-identity conformance on one inheritor. No third-party wallet burn was established. Fix direction: explicit-holder settlement without external `exchangeIn`. Do not delete the V4 package under RC-03.

**New fact, missed in my original.** Ordinary V3 FullSpread redemption is contract-only.

`UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol:45-50` transfers the caller's shares, then `delegatecall`s `exchangeIn` with `pretransferred=true`. `InTarget.sol:58-59` passes that flag to `_secureShareDelivery`. `Common.sol:918-919` forwards it to `_secureTokenTransfer`, which calls `requirePretransferCaller(msg.sender)` at `:866-867` before any burn. `delegatecall` keeps the original caller. A code-less caller therefore hits `EOAPretransferNotAllowed`. The staged transfer rolls back with that revert.

FIX_PRD `:86` and `:97` require ordinary redemption to burn the original caller's shares. D9 at `:79` and `:87` is the internal-balance / pretransfer gate, not a ban on ordinary false-flag redemption. Hookless does not have this conversion: its false-flag share delivery transfers from `msg.sender` without the bytecode check (`UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol:944-947`). One family does not close the other.

- **Severity:** Medium. **Class:** CODE_DEFECT. Failed RC-01 execution. Possible regression; no diff proves when it was introduced.
- **Impact class:** ordinary wallet redemption availability. Not an established unauthorized burn.
- **Fix direction:** settle ordinary redemption against the original holder without marking an adapter-staged transfer as an external pretransfer. Keep the external true-flag gate. The existing ordinary test at `UniswapV3FullSpreadVaultHeldRedeem.t.sol:96-104` uses a contract caller and does not catch this.
- **Confidence:** high on the call path. No run.

Kimi's inventory of the other explicit-holder families is consistent with my original and with the re-read. I do not reopen those families. Unresolved: Kimi did not record the ordinary V3 EOA rejection. That dissent is now corrected on my side; Kimi's original still omits it.

## RC-03 — stale README does not reopen the deleted package

**Agree with Astra, MiniMax, and Kimi on the code. Correct my own PARTIALLY_EXECUTED.**

**Fact.** `contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeCommon.sol` is absent. Named launch and DETF callers construct FullSpread, as recorded in my original. Legacy V4 remains, which FIX_PRD required.

**Fact.** `contracts/vaults/standard/exchange/protocols/uniswap/README.md:3` and `:56` still say the V3 tree remains and that internal-balance redemption uses the proxy self-call. That text is false for the current tree. It does not recreate the deleted sources or the old constructor.

- **Corrected status:** CONFIRMED_EXECUTED for the deletion and retarget. Documentation gap remains.
- **Severity of the README:** Low, not a failed deletion. I withdraw the Medium "failed documentation completeness of the execution" framing. The self-call sentence can still mislead a later editor; that is guidance risk, not restoration of the package.
- **Impact class:** documentation. **Fix direction:** state that legacy V3 source was removed, V3 FullSpread is the supported V3 vault, and the self-call is not current FullSpread behavior. Keep the legacy V4 warning labeled as the retained package.
- **Unresolved:** Kimi also cites other current-facing documents. I did not re-read those citations in this pass, so I neither confirm nor dismiss K3-03.

## RC-04 — source checks present; acceptance is still partial

**Agree with Astra and Kimi that the source checks exist. Object to MiniMax's CONFIRMED_EXECUTED. Correct my severity, not my status.**

**Fact.** `_quoteSwapOut` rejects an incomplete quote (`UniswapV3FullSpreadStandardExchangeVaultCommon.sol:281-283`). `_swapExactOut` requires the paid output delta to equal `amountOut` (`:531-535`) and still uses `UniswapV3Exchange_InsufficientOutput` for the input ceiling (`:528-529`). FIX_PRD `:239` forbids renaming that ceiling error in this item. The misname is not a failed RC-04 execution. Agree with all three peers on that point.

**Fact.** `UniswapV3FullSpreadExactOutputFill.t.sol:16-17` says the fixture does not cover the post-swap output-delta guard. The unfilled execution test reverts at quote time. MiniMax cites `ApexRecurrenceErrorOrder.t.sol` for a partial-fill preview revert. That is the quote boundary, not the settlement boundary.

- **Status I keep:** PARTIALLY_EXECUTED. The acceptance bullet that an execution whose output delta is short reverts is not witnessed.
- **Severity correction:** Low TEST_DEFICIENCY, not Medium. The source repair is present. Impact class is regression detection, not a demonstrated short payout.
- **Fix direction:** a production-path witness that reaches settlement, or an explicit owner acceptance of quote-only coverage. Do not change the quoter or the other families for this item.
- **Unresolved label:** Kimi uses CONFIRMED_EXECUTED plus a Low gap. I object to that label because the controlling acceptance list includes the unwitnessed bullet. The underlying facts are the same.

## RC-06 — helper closed; callers are not

**Agree with Astra. Object to MiniMax and Kimi treating the item as closed. Correct my own CONFIRMED_EXECUTED.**

**Fact, helper.** `_retainSubSharePairResidual` (`UniswapV4DetfCommon.sol:625-637`) books only after `previewExchangeIn` of that amount returns zero, writes the full local balance, and does not catch the preview. The one-share quote is not called there. That narrow repair matches FIX_PRD RC-06. MiniMax and Kimi are right about the helper body. They are wrong to stop there.

**Fact, hook zero.** `_entryJoinResidualAtomic:604-605` and `:614-615` return `0` when the hook preview is `0`. They do not revert. The join loops break on `lpOut_ == 0` (`:565`, `:590`). `_tryJoinResidual:543-545` then books the full local balance. OD-08 / REQ-01 (`docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md:184` and `:200`) says a hook preview of `0` rolls the parent back and does not add a holder-reserve update. FIX_PRD RC-06 did not withdraw that rule.

The focused test at `UniswapV4DetfLeftoverPreview.t.sol:52-77` expects a zero proportional hook preview to fall through to a single-asset join. That test conflicts with OD-08 if that zero hook preview is the case OD-08 names. I agree with Astra-03. Severity Medium. Impact class: parent atomicity / residual policy. No loss established. Fix direction: hard-fail a hook preview of zero, or record a scoped owner exception. Do not add a catch around the SE preview.

**Fact, failed probe.** The `supportsInterface` catch returns false and does not itself book (`:630-633`). The join loops then call `_pairQuoteIsZero` (`:559`, `:584`). If that preview returns zero, the loop returns true and `_tryJoinResidual:531-538` books. The assignment's rule was that a `supportsInterface` failure must not book. The catch-local reading is satisfied. The caller-wide reading is not.

- **Corrected status:** PARTIALLY_EXECUTED.
- **Severity of the probe path:** Low. Confidence high on control flow, medium on whether any current SE both fails the probe and returns a zero preview. I do not claim a deployed family does that.
- **Unresolved:** MiniMax and Kimi close RC-06 on the helper. I do not. Whether OD-08's "hook preview of 0" includes the proportional-join zero that the RC-06 test treats as a legal fallback is a reading dispute. The text at REMEDIATION_PRD `:184` does not limit the rollback to one hook function. I read it as applying. An owner amendment would be required to prefer the test.

## A-F01 through D-X01 — recurrence tests do not authorize or close production repairs

**Agree with Kimi's rule. Partially agree with Astra's source observations. Object to treating any of these as CONFIRMED_EXECUTED remediations.**

No FIX_PRD item authorizes a production repair for these IDs. A new test file is not a production remediation. The recurrence handoff said those tests were not run. This pass did not run them either. An unrun assertion does not close the named file it leaves in place.

| ID | Recheck | Disposition I keep |
| --- | --- | --- |
| A-F01 | V3 `OutExecuteTarget.sol:81-86` still compares credit before `_secureTokenTransfer`'s caller gate at `Common.sol:866-867`. Agree with Astra and Kimi. Not closed by a recurrence probe that expects the shortage error. | NOT_A_REMEDIATION. Open Low diagnostic-order defect. Not an RC-01 failure. |
| A-F02 | I did not re-read every Wings negative. Astra cites new exact-error probes. Kimi says the bare `expectRevert` at `Security.t.sol:39` remains. I re-confirmed that line in the first pass. A second file does not erase it. | NOT_A_REMEDIATION. Original gap remains. New probes, if present, are unrun and unauthorized. |
| A-F03 | Rechecked `ApexRecurrenceInvariantWitness.t.sol:37-53` and `:56-60`. Setup now requires one deposit, one trade, one rebalance, and one exit. The invariant only requires later counters to stay at least those setup values. `test_deterministicMoneyPathCoverage` is a separate deterministic test, not the campaign. Original handlers still swallow failures. Agree with Astra's narrowing and with Kimi that the original file is not closed. Object to Astra's CONFIRMED-style reading; Astra's own row is PARTIALLY_EXECUTED test work, which is fair as a description of unrun source, not as closure. | NOT_A_REMEDIATION. Campaign vacuity narrowed, not closed. |
| C-006 | Rechecked `ApexRecurrenceConsumerConservation.t.sol:57-68`. It compares captured before-balances and returned shares. That is not the tautology. `FamilyConsumers.t.sol:59` is still `token1.balanceOf(f.hook)` compared with itself. Object to Astra's CONFIRMED_EXECUTED for the accepted finding. Agree the replacement assertions exist. | NOT_A_REMEDIATION. Cited tautology remains. Separate unrun witness exists. |
| B-03, B-04, B-05, C-007, D-X01 | Astra says new recurrence assertions exist and finds no defect in the ones read. I did not re-read those bodies in this pass. I do not adopt CONFIRMED_EXECUTED. I also do not deny the files exist. Kimi's "unrun and not FIX_PRD-authorized" is the status I can defend. | NOT_A_REMEDIATION. Execution of any new assertion is UNVERIFIED. |
| C-001 through C-005 | No FIX_PRD repair. I did not re-audit Astra's D41/D48/D49 line claims in this pass. | NOT_A_REMEDIATION. Astra's partial-test notes are not adopted as my findings and are not refuted. |
| D-F01 / RC-07 | Script still globs only baseline parents (`r12_selector_size_compare.py:46-47`). Ignore is recorded in FIX_PRD. That is not REQ-08 closure. Agree with all three that the script was not fake-fixed. My original evidence-note objection stands: `STAGE1_EVIDENCE.md:49` still says the replacement packages replace the citation. Peers did not withdraw that sentence. | NOT_A_REMEDIATION. REQ-08 evidence claim remains over-broad. |
| D-F04 | `Adversarial_TrustFlags.t.sol:58-65` still mocks `indexedexManager.isDisabled`. Agree with Astra and Kimi. | NOT_A_REMEDIATION. Open test deficiency. |

## What I do not reopen

RC-02 and RC-05 remain CONFIRMED_EXECUTED on inspection, against the later Rocket correction, not the withdrawn "never combine" draft. EtherFi was not given the Rocket helper. No peer established a defect in those two repairs. I agree.

No four-member consensus is claimed. MiniMax's RC-01 closure, MiniMax's and Kimi's RC-06 closure, and Astra's CONFIRMED rows for unauthorized recurrence tests remain dissent where noted above.
