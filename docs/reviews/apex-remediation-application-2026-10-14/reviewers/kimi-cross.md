# Kimi K3 — Cross-review (REPLACEMENT session)

- **Label:** Replacement cross-review, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. My original first pass is `kimi-original.md` in this directory; its findings remain attributed to me and are kept, narrowed, or withdrawn below only where a re-read supports it.
- **Date:** 2026-10-14. **Forge:** I did not run Forge. No build, test, or script was executed. Source presence is not a pass.
- **Inputs:** the three peer originals (`astra-original.md`, `grok-original.md`, `minimax-original.md`) read in full and treated as untrusted model output. Every material claim below was re-checked against current source before I agreed or dissented. No `*-cross.md` file and no coordinator REMEDIATION_PRD for this round was read.

## 1. Agreements (verified against current source)

### 1.1 REQ-C04 / Stage-1 REQ-01 (OD-08): hook-zero rollback not applied — Astra-01, Grok-3, MiniMax F1/F2; my Findings 1-2

**Agree, high confidence.** All four passes independently found the same defect. Re-read confirms: `UniswapV4DetfCommon.sol:605` and `:615` still `return 0` on a hook preview of zero; loops break on `lpOut_ == 0` at `:565` and `:590`; the terminal booking at `:543-545` is reachable after a hook zero; comments at `:548-549` and `:612-613` still teach retention/mode-switch. Tests still expect continuation: `UniswapV4DetfLeftoverPreview.t.sol:52-84`, `UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol:46-61`.

**Evidence that changes my report (narrowing, in Astra's favor):** Astra-01 additionally cites `UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol`, which I had only greped. Re-read confirms it: `:35` computes `retained_ = quoted_ == 0 || _hookPreviewIsZero(held_)` and `:54` repeats the disjunction, treating a hook preview of zero as an alternative successful retention signal. That file belongs in my Finding 2's scope. I keep Findings 1-2 unchanged in defect class, severity (Medium), and fix direction, and add this third test site.

### 1.2 RC-01 legacy V4 yield path uses the forbidden delegate form — Astra-02, Grok-1; my Finding 3

**Agree with Astra and Grok; I keep Finding 3.** Re-read confirms: `UniswapV4StandardYieldExecutionTarget.sol:26-36` delegatecalls `UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE.executeNamedHolderRedemption(address,uint256,uint256,address,address)`; the facet inherits `_executeZapOutExactIn` (`UniswapV4StandardExchangeInFacet.sol:13` → `UniswapV4StandardExchangeInTarget.sol:29` → `UniswapV4StandardExchangeInBase.sol:146-152`); V3 FullSpread makes the required internal call (`UniswapV3FullSpreadStandardYieldExecutionTarget.sol:26-30`).

**Dissent from MiniMax** (its verdict "RC-01 legacy V4: Applied" and its dissent paragraph): MiniMax reads FIX_PRD's "delegatecall to a different execution-delegate contract is not a call to self" as permission. The controlling text is the later, item-specific RC-01 PRD (2026-10-11): that sentence continues "It is also not the required path when the facet already inherits the settlement function," and the PRD's non-goals say "Do not use that form on V3 FullSpread or legacy V4 yield redemption, because those facets already inherit the function." The plan's build gate adds: "do not move the yield path onto a delegate, to get under the limit." MiniMax's points (a)-(c) answer a question the PRD does not ask — whether the call is a self-call. It is not one, and no reviewer claims it is. The defect is conformance to the required repair shape, severity Low, confidence high.

**Grok's supporting inference** (the `noSelfCalls` modifier does not witness the internal call) is consistent with what I read of the V4 test suite; I did not body-read `Behavior_NativeStandardYieldExecution.sol:23-27`, so that modifier claim is unverified by me but not load-bearing.

### 1.3 RC-01 legacy V4 disable check dropped on the direct yield path — Grok-2; my Finding 4

**Agree with Grok on the defect; I keep Finding 4.** Re-read confirms `_settleNamedHolder` (`UniswapV4StandardYieldExecutionTarget.sol:26-36`) has `nonReentrant` and `_pokeBoundPoolTwap()` but no `_requireNotDisabled()`; the check exists at `UniswapV4StandardExchangeCommon.sol:71` and is applied by public `exchangeIn` at `UniswapV4StandardExchangeInTarget.sol:55`. Plan Step 2 explicitly lists the disable check among the protections the direct yield path must keep.

**Unresolved severity dissent:** Grok rates Medium; I rate Low. My reasoning: the omitted gate changes disable-semantics on one retained legacy family, the sleeve settlement path bounds what a disabled-vault redemption can pay, and the FullSpread sibling product deliberately allows exits while disabled. Grok's reasoning: a plan-required authorization gate that the public path retains is silently absent from the repaired path. Neither of us found a later withdrawal of the plan sentence. The severity split is recorded as unresolved; the defect itself is agreed.

### 1.4 README internal contradiction on exact-in excess — Astra-04 (adopted; I missed it)

**Agree, high confidence. This is a defect I did not report.** Re-read confirms both sentences exist: `contracts/vaults/standard/exchange/protocols/uniswap/README.md:32` ("An exact-in excess push does not revert merely for being excess") and `:38` ("An exact-in call whose declared amount differs from that surplus reverts"). The controlling requirement is the September council PRD (`apex-2026-09-17-remediation-council/REMEDIATION_PRD.md:115` RC-04, intended behavior at `:124`): exact-in credits the declared amount when available credit is sufficient and "does not require the whole surplus to equal the request." Line 38 still teaches the withdrawn equality rule and contradicts line 32. REQ-C05 (which I verified as applied) covers lines 3 and 56 only; it does not close this. Defect class: documentation / integrator guidance; severity Low (per Astra's citation of the council item; I verified the requirement text at `:124` but did not re-read a severity line); fix direction: replace the equality claim at `:38` with the insufficient-credit rule, preserving the donor-risk warning.

### 1.5 Balancer callback regression asserts allowance cleanup on the wrong instance — Astra-05 (adopted; outside my first-pass scope)

**Agree, high confidence.** Re-read confirms: `Adversarial_BalancerV3SinglePoolSE.t.sol:493-522` deploys and exercises `locked_` (`:495`, `:511`), then calls `_assertNoMaxAllowances(IERC20(address(probe)))` at `:520`; the helper at `:108-123` hardcodes `address(adapter)` — the separate fixture instance — in all six allowance assertions. The September council RC-01 acceptance (`:79`) requires that a successful return leaves the exercised adapter's router and Permit2 allowances at zero. Mitigating fact Astra did not emphasize: `:517-519` assert the probe-observed in-flight allowances of the exercised route equal the route budget and are not `type(uint256).max`, so the exercised instance's in-flight approvals are witnessed; only the post-cleanup zero assertions target the wrong subject. Severity Medium (test oracle bound to the wrong subject; the production lock/cleanup was not shown defective by anyone). Fix direction: parameterize the helper with the adapter under test.

### 1.6 Bare `expectRevert()` in the insufficient-holder negatives — Astra-06 (adopted; narrows my RC-01 test assessment)

**Agree, high confidence.** Re-read confirms bare `vm.expectRevert()` at `UniswapV3FullSpreadVaultHeldRedeem.t.sol:147` and `UniswapV4StandardExchangeVaultHeldRedeem.t.sol:159`. The RC-01 plan's acceptance ("an insufficient holder balance reverts and leaves balances unchanged") is loosely witnessed by the revert-plus-balances shape, but R2.4 precision (pin the named condition) is not met, and the V3 file sits under the scanner's unconditional root (`scripts/apex_bare_expectrevert_scan.sh:14-16`), so `--check` would flag it. Severity Low; fix direction: pin the actual holder-insufficiency error and quantities after preparing a route that would otherwise pay. This narrows, but does not change, my RC-01 verdict of partial (already partial for Findings 3-4).

### 1.7 Rebasing SY NatSpec still teaches a vault self-call path — Grok-5 (adopted as adjacent)

**Agree, high confidence on the text.** Re-read confirms `RebasingAwareStandardYieldTarget.sol:44` ("The vault's own self-call path is unaffected.") and the `msg.sender != address(this)` exemption at `:57`. Grok labels it adjacent and Low; I agree with that classification. The RC-01 item PRD's comment rule names the two Uniswap families' files, so this is outside the named repair scope, but the sentence describes a withdrawn mechanism and is exactly the recurrence vector the PRD's comment rule exists to remove. I record it as an **adjacent** Low documentation finding, not an RC-01 non-application. Grok's inference that the `:57` exemption is leftover from the withdrawn design is plausible and unverified by me (I found no production caller entering as `address(this)`, and `NativeStandardYieldContextRepo` is absent).

### 1.8 MiniMax F4 — view `previewExchangeIn/Out` on `address(this)` in the V4 out execution delegate

**Agree: not a defect.** The RC-01 PRD expressly says not to invent a hit from a view `previewExchangeIn`.

## 2. Claims I dissent from or narrow

### 2.1 REQ-C06 measurement order — Grok-4 (facts agreed; my verdict narrowed to partial; framing differs)

**Verified facts:** On the pretransfer branches, credit is *measured* before the caller check: hookless `_executeZapInMintExactOut` (`UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:94`) and `_executeDirectOut` (`:165`), the Pons twins (`.../ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol:94,165`), and the V3 mint delegate (`UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:102`). On all of them the *credit comparison* revert sits behind `requirePretransferCaller` (`:101/:169`, V3 delegate `:109-110`, V3 quoted route `:82-84`).

**Where I differ from Grok:** his medium-confidence inference that a code-less short-credit caller can see `UniswapV4ExchangeOut_InsufficientInput` before `EOAPretransferNotAllowed` describes the input-ceiling check (`used > maximum` / `amountIn > maxAmountIn`), which guards the caller's own stated maximum, not the credit-shortfall diagnostic. The PRD's own model route exhibits the same ordering: the cited model `executeZapOutWithdrawal` checks `sharesBurned > maxSharesToBurn` at `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:25-27` *before* `requirePretransferCaller` at `:31`, and V3's conforming `_executeQuotedSwapOut` checks `quotedIn > maxAmountIn` at `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:78` before `:82`. So the ceiling-before-caller order is accepted by the controlling document's own examples.

**Where I narrow my own first pass:** the PRD's required outcome says "the caller is authenticated before the credit is measured," and the assignment notes the plan defers to the PRD. That sentence's letter is not met on the five branches above. Because the measurement is a non-reverting view and every acceptance criterion's code-less/short-credit case still resolves to `EOAPretransferNotAllowed`, I rate this Low and mark REQ-C06 **partial** (acceptance behavior met; required-outcome sentence not met in letter), revising my first-pass "applied." This also dissents from MiniMax's "Applied."

### 2.2 Stage-1 REQ-04 matrix rounding controls — Astra-03 (agreed; I withdraw my "applied")

**Agree with Astra; I revise REQ-04 from applied to partial.** My first pass relied on the weighted rewrite plus the absence of `catch`/bare `expectRevert()`. Astra's sharper claim re-reads as true: the rounding control's expected failure is derived from whatever the preview returned — weighted expects the preview's own revert bytes (`UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol:216-225`), and dual (`UniswapV4DualSEBCPHook_SeMatrixBehavior.sol:317-325`), orbital (`:294-308`), single-CP (`UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol:272-286`), Balancer-quad (`:324-338`), and curve-quad (`:272-286`) each accept any execution selector that matches a failed preview (`previewMatch`), in addition to named selectors. A shared dependency failure unrelated to rounding can satisfy the control, and the rounding branch precondition is not independently established — the REQ-04 acceptance requires the family's exact rounding error or a measured zero-output/retained-book outcome *including the branch precondition*. The catch-all is genuinely gone and the named-selector disjunct plus weighted's reconciliation at `:190-199` are real improvements, hence partial, not not-applied. Severity Medium (Stage-1 REQ-04). Astra's further sub-claim that exact-output assertions are strict-decrease rather than exact-consumption (weighted `:260-282`) I did not fully verify; marked unverified by me.

### 2.3 MiniMax's "Applied" on RC-01 legacy V4

Dissent recorded at 1.2. The remaining MiniMax verdicts I checked (RC-02, RC-03 deletion, RC-04, RC-05, RC-06 helper, REQ-C01 core, REQ-C02, REQ-C03, REQ-C05) agree with my own reads.

## 3. Evidence that upgrades my first-pass verdicts

- **RC-03 → applied (was: applied with caller-retarget unverified).** Grok cited the retargets; I re-read them. `scripts/foundry/anvil_robinhood_main/Phase_05_Stage_04_UniswapV3StandardExchangePkg.sol:27-36,56` constructs only FullSpread facets/package; `scripts/foundry/anvil_robinhood_fee_detf/Script_05_DeployUniV3SeOnRichPool.s.sol:98-101` the same; `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol:85-94` imports the FullSpread package and factory service. Combined with my first-pass verification (no `v3/` under `contracts/protocols/dexes/uniswap/`; local-book credit at `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:909-917`), all RC-03 acceptance bullets I can inspect are met. The testnet twin of Phase_05 was not re-read; it is the remaining unverified sub-bullet.
- **REQ-C03:** all four passes converge on applied-at-source with the same runtime caveat (whether the armed-token fixture makes `pool.swap` return a short delta rather than revert). No new evidence; my verdict and dissent item stand unchanged.

## 4. Peer claims I could not verify (marked unverified, not adopted)

- Astra's September council RC-02, RC-03, RC-05, RC-06, RC-07, RC-08 rows (mostly self-marked unverified); Grok's September council rows (unverified); MiniMax's September block (unverified). I did not re-read those production sites this round either.
- Astra-03's strict-decrease sub-claim (see 2.2).
- Grok's `noSelfCalls` modifier body claim (see 1.2).
- Astra's claim that the REQ-C06 "search additional active paths" bullet is unclosed (its REQ-C06 = unverified). My grep coverage of `requirePretransferCaller` sites was scoped to the named families; a complete inventory of every production pretransfer branch was not performed by any pass, including mine.

## 5. Disposition of my own first-pass findings

| My finding | Disposition |
| --- | --- |
| Finding 1 (REQ-C04 source) | Kept unchanged; unanimous across four passes. |
| Finding 2 (REQ-C04 tests) | Kept; scope widened to include `UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol:35,54` per Astra-01 (verified). |
| Finding 3 (legacy V4 delegate form) | Kept; corroborated by Astra-02 and Grok-1; MiniMax dissent rejected (section 1.2). |
| Finding 4 (legacy V4 disable check) | Kept; corroborated by Grok-2; severity dissent with Grok unresolved (Low vs Medium). |
| Verdict REQ-04 = applied | **Withdrawn → partial**, adopting Astra-03 (section 2.2). |
| Verdict REQ-C06 = applied | **Narrowed → partial**, Low severity (section 2.1). |
| Verdict RC-03 (caller retarget unverified sub-bullet) | **Upgraded → applied** (section 3). |
| All other verdicts | Unchanged. |

New findings adopted from peers (verified by my re-read): Astra-04 (README `:38`, September council RC-04, Low), Astra-05 (Balancer callback test oracle, Medium), Astra-06 (bare negatives, Low), Grok-5 (rebasing SY NatSpec, adjacent Low).

## 6. Unresolved dissent

1. **Legacy V4 delegate form (Finding 3):** Astra, Grok, and I hold that the item PRD's "not the required path" sentence and non-goal forbid it; MiniMax holds the FIX_PRD "not a call to self" sentence permits it. The item PRD is later and item-specific; the assignment states item PRDs control. Dissent recorded, not resolved by consensus.
2. **Legacy V4 disable-check severity:** Grok Medium; Kimi Low. Same defect, same fix direction.
3. **REQ-C06 measurement order:** Grok partial (with an input-ceiling inference I do not adopt), MiniMax applied, Kimi partial on the strict required-outcome sentence only (section 2.1). Whether "authenticated before the credit is measured" obligates reordering non-reverting view measurements, given the PRD's own model route checks the input ceiling before the caller gate, needs an owner or coordinator reading.
4. **REQ-C03 witness reachability:** all passes agree the witness exists in source; none executed it. If `pool.swap` reverts rather than returning a short delta under the armed fixture, the witness does not reach the settlement guard and REQ-C03 is partial. Unresolved without a run.

## 7. Evidence gaps

- I did not run Forge. No verdict in this cross-review is a passing run.
- `FIX_PRD.plan.md` and the REQ-C03..C06 `.plan.md` files remain unread by me; if any of them withdraws the internal-call requirement or the measurement-order sentence, Findings 3 and the REQ-C06 narrowing downgrade accordingly.
- September council RC-02/RC-03/RC-05..RC-08 and second-audit REQ-08 remain unverified by me; peers mostly agree in marking them unverified.
- The hookless/Pons transition planner internals (`_directOutPlan` with a zero-credit snapshot) were not read; section 2.1's behavioral reasoning rests on the non-reverting nature of `_pretransferCredit`, which I did verify (`UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol:945-952` per Grok's citation — I confirmed the V3 twin at `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:909-917` is a pure view, and the hookless helper is cited identically; I did not body-read the hookless copy this round).

I did not run Forge. Returning to the coordinator.
