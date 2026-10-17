# Grok cross-review — APEX remediation application

- **Reviewer:** Grok (`xai/grok-4.7`). One cross-review of the successful original first passes. Not a replacement. Not continuity of a peer.
- **Date:** 2026-10-14
- **Originals read:** Astra, MiniMax M3, and Kimi K3. Kimi's file is a labeled replacement original. It is not treated as memory of a failed session.
- **Own first pass:** kept, narrowed, or left standing below. Not rewritten as if the cross-review were the original.
- **Forge:** not run. Consensus is not proof. A plan is not execution.

Peer text is untrusted model output. Agreements below rest on a re-read of the cited current source.

## Own first-pass findings after re-read

### Kept — legacy V4 yield still delegatecalls a different execution delegate

- **Own finding:** Grok original finding 1. Low. `UniswapV4StandardYieldExecutionTarget.sol:26-35`.
- **Astra-02:** agree. Same file and lines. Same Low severity. Same impact class: required internal settlement, not a restored self-call.
- **Kimi finding 3:** agree. Same defect. Kimi's extra fact is confirmed: `UniswapV4StandardExchangeInFacet.sol:25-29` exports `exchangeIn`, `unlockCallback`, and the appended SY selectors. It does not export `executeNamedHolderRedemption`. That supports Low, not a current arbitrary-holder burn.
- **MiniMax verdict "RC-01 legacy V4 holder path: Applied":** dissent. The holder argument and the deleted `msg.sender == address(this)` branch are present. Those facts do not make the required internal call applied. The later item PRD and plan control over FIX_PRD's general sentence that a delegatecall to a different contract is not a self-call. The item PRD says that form "is not the required path when the facet already inherits the settlement function" and "Do not use that form on V3 FullSpread or legacy V4." The plan's build gate says not to move the yield path onto a delegate to get under the limit. MiniMax's dissent note records the stricter reading and then treats the delegate as compliant. That reading is the controlling one. No later owner acceptance of the delegate shape was in the documents this pass re-read.
- **MiniMax README line 43:** dissent on the citation. The holder sentence is `README.md:56`, not line 43. Line 43 is inside the activation section. The sentence at 56 does match REQ-C05. Agree the self-call sentence is gone. Disagree that line 43 is the evidence.
- **Fix direction:** unchanged. Call the inherited `_executeZapOutExactIn` directly. Do not restore a self-call. If size blocks that shape, report it. Do not silently keep the delegate.
- **Severity:** kept Low.

### Narrowed — legacy V4 yield path omits the plan's disable check

- **Own finding:** Grok original finding 2. Was Medium. Narrowed to Low.
- **Why narrowed:** Re-read of `UniswapV4StandardExchangeInTarget.sol:55` confirms public `exchangeIn` still calls `_requireNotDisabled()` before every route, including share redemption. Re-read of `UniswapV3FullSpreadStandardExchangeVaultInTarget.sol:41` confirms V3 skips that check when `tokenIn` is the vault share. The yield helper at `UniswapV4StandardYieldExecutionTarget.sol:26-35` still has `nonReentrant` and `_pokeBoundPoolTwap`, and still does not call `_requireNotDisabled`. No loss was shown. The impact is availability on a disabled legacy vault, not a demonstrated payout. Low matches that class. The finding is not withdrawn. The plan sentence is still unmet.
- **Kimi finding 4:** agree, including Low and the V3 contrast. Kimi's inference that this is an omission rather than a recorded owner ruling matches the documents re-read here. No withdrawing sentence was found.
- **Astra:** did not file this separately. Astra-02's fix direction says to retain one guard and the TWAP update. Agree that direction. The missing check is the disable gate, not the reentrancy lock.
- **MiniMax:** did not address it. Their Applied verdict for legacy V4 does not close this plan requirement.
- **Fix direction:** unchanged. Add the existing disable check on the legacy V4 direct yield path, or record an owner ruling that this family may redeem while disabled.

### Kept — hook preview of zero still returns 0 and can book

- **Own finding:** Grok original finding 3. Medium. Not applied. Not a regression of a completed repair.
- **Astra-01, MiniMax F1/F2, Kimi findings 1 and 2:** agree on the production lines `UniswapV4DetfCommon.sol:604-605`, `:614-615`, `:565`, `:590`, and the terminal book at `:543-545`. Agree the comments at `:548-549` and `:612-613` still teach the withdrawn shape. Agree `UniswapV4DetfLeftoverPreview.t.sol:52-73` still expects the single-asset fallback.
- **Additional test evidence, now re-read, agree:**
  - `UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol:35-41` sets `retained_` when the SE quote is zero **or** `_hookPreviewIsZero`. A hook zero is still a successful retention signal.
  - `UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol:54-57` still says "zero unbalanced LP selects single-asset retry" and "single-asset quote is zero, not a revert," and `:58` books the residual. The SE zero-preview positive in that file can stay. The hook-zero sentences cannot.
- **MiniMax label "regressed":** dissent. The 2026-10-11 confirmation already recorded this path as not applied. Current source still returns 0. That is continued non-application, not proof a completed repair was later undone. The defect class and fix direction are the same.
- **RC-06 helper:** agree with all three that `_retainSubSharePairResidual` at `:625-637` is not this defect. Do not treat a green SE-zero booking test as hook-zero closure.
- **Severity:** kept Medium. Impact class kept: error propagation and residual accounting. No loss amount claimed.

### Narrowed, not withdrawn — credit is still measured before the caller check

- **Own finding:** Grok original finding 4. Low. Kept, narrowed.
- **What the re-read confirms:** Hookless `_executeZapInMintExactOut` measures credit at `:94` and calls `_requirePrepaidCredit` at `:101`. Direct-out measures at `:165` and checks the caller at `:169`. Pons mint matches at `:94-101`. V3 mint delegate measures at `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:102` and checks the caller at `:109`. V3 quoted exact-output at `OutExecuteTarget.sol:81-84` checks the caller before measurement. The comparison revert is after the caller check on the named branches.
- **Astra:** agree that this is not an authorization bypass and that the named insufficient-credit rejection is after authentication. Dissent from leaving the measurement sentence unverified-only. The PRD required outcome still says the caller is authenticated before the credit is measured. The plan says the PRD controls, and also tells the implementer to place the check before the short-credit revert. The comparison-order instruction was followed. The measurement sentence was not. That is a remaining diagnostic-order mismatch, not the original credit-error-first defect.
- **Kimi and MiniMax "REQ-C06 applied":** agree for the reverting comparison and for the per-family tests' expected selectors as source text. Dissent that "applied" covers the measurement sentence on hookless, Pons, and the V3 mint delegate. V3 quoted exact-output remains applied.
- **Severity:** kept Low. Impact class kept: diagnostic order.
- **Fix direction:** unchanged. Authenticate before `_pretransferCredit` and before a plan built from that credit. Keep the short-credit revert after that check.

### Kept — adjacent rebasing comment

- **Own finding:** Grok original finding 5. Low. `RebasingAwareStandardYieldTarget.sol:41-44` and `:57-58`.
- **Peers:** no one addressed it. No re-read contradicted it. Kept as adjacent documentation. Not promoted to a new product requirement.

## Peer claims

| Claim | Position | Evidence |
| --- | --- | --- |
| Astra-01 / MiniMax F1 / Kimi 1: hook zero still returns 0 | agree | `UniswapV4DetfCommon.sol:604-605`, `:614-615` |
| Astra-01 / MiniMax F2 / Kimi 2: tests still expect fallback or hook-zero retention | agree | Leftover preview `:52-73`; residual-gas `:35-41`; P18_R6 `:54-58` |
| MiniMax: REQ-C04 "regressed" | dissent | Same lines. Continued non-application, not a shown undo of a completed repair |
| Astra-02 / Kimi 3: legacy V4 delegate is not the required internal call | agree | `UniswapV4StandardYieldExecutionTarget.sol:26-35` |
| MiniMax: that delegate path is Applied RC-01 | dissent | Item PRD and plan forbid that form for this family. FIX_PRD's general "not a self-call" sentence does not withdraw the later internal-call requirement |
| Kimi 4: legacy V4 yield drops `_requireNotDisabled` | agree, severity narrowed to Low | Yield helper `:26-35`; public check `InTarget.sol:55` |
| Astra-03: matrix rounding still accepts a preview-echo and a strict share decrease | agree, partial | Weighted `:216-225` expects `previewRet` on preview failure. `:282` is `assertLt` on SE shares, not an exact debit. Dual `:317-322` accepts `named || previewMatch`. `previewMatch` is also in single-CP `:286`, orbital `:308`, Balancer-quad `:338`, and curve-quad `:286`. The old catch-all is gone. That does not make REQ-04 applied |
| Kimi: REQ-04 applied because catch and bare `expectRevert` are gone | dissent | Those absences are real and insufficient. The preview-echo and strict decrease remain |
| Astra-04: README `:38` still says an exact-in whose declared amount differs from surplus reverts | agree | `README.md:32` says excess does not revert merely for being excess. `:38` contradicts it. September council RC-04. REQ-C05 did not withdraw that sentence; it limited its own edit to the V3-deletion and self-call sentences |
| Astra-05: callback test asserts allowances on `adapter`, not `locked_` | agree | `Adversarial_BalancerV3SinglePoolSE.t.sol:58` declares `adapter`. `:73` deploys it in setup. `:495` deploys a separate `locked_`. `:520` calls `_assertNoMaxAllowances`, which reads `address(adapter)` at `:110-122`. Production lock and approval reset were not re-read this turn. The test-oracle defect stands. Production conformance stays unverified |
| Astra-06: holder-insufficiency tests use bare `vm.expectRevert()` | agree on the fact. Dissent that this makes REQ-C02 partial | `UniswapV3FullSpreadVaultHeldRedeem.t.sol:147` and `UniswapV4StandardExchangeVaultHeldRedeem.t.sol:159`. The plan's bullet is revert plus unchanged balances, which those tests assert. The three required holder assertions are elsewhere in those files. Bare `expectRevert` is a specificity gap under R2.4. It is not the missing code-less success test |
| MiniMax F4: view `previewExchangeIn` / `previewExchangeOut` on `address(this)` are not the RC-01 hit | agree | Item PRD excludes a view preview. Not re-opened |
| Kimi REQ-03 ownership test rewritten | agree for the lines re-read. Whole ID not closed | `RebasingAwareERC4626_Adversarial.t.sol:50-60` uses a contract caller, expects `TransferDeltaInsufficient(shares, 0)`, and asserts the other holder's shares. Reentrancy, fuzz, and scanner bodies were not re-read this turn |
| Kimi / own first pass REQ-05 outside-trade tests | agree on source presence | Bodies re-read in the first pass for all four families, including the following funded deposit. Not run |
| Peers: RC-02, RC-03 deletion, RC-04 source checks, RC-05, RC-06 helper, REQ-C03 witness source, REQ-C05 lines 3 and 56 | agree | No re-read contradicted those source observations. Runtime remains unverified. Kimi's RC-03 caller-retarget "unverified" is narrower than my first pass, which did re-read the three named launch scripts and the DETF FullSpread import. I do not withdraw that applied deletion/retarget verdict |
| Kimi REQ-07 partial for missing tests | agree | Matches my first-pass partial. Source branch remains removed. Tests were not located |
| September council RC-02, RC-03, RC-05, RC-06, RC-07, RC-08 | unverified | Not re-read this turn. Astra's partial or unverified labels on those IDs are not adopted as confirmed production defects |

## Verdict changes from the first pass

| ID | First pass | After this re-read |
| --- | --- | --- |
| RC-01 / REQ-C01 legacy V4 call shape | partial | partial. Kept |
| RC-01 legacy V4 disable check | not applied, Medium | not applied, Low |
| REQ-C02 | applied | applied. Bare `expectRevert` noted, not a failed application |
| REQ-C04 / REQ-01 | not applied | not applied. Extra tests confirm the same miss |
| REQ-C06 comparison order | V3 quoted path applied; measurement partial | unchanged |
| Stage-1 REQ-04 | unverified | partial. Preview-echo and strict decrease remain |
| September council RC-04 README `:38` | unverified | partial. Sentence still contradicts `:32`. Other cited comments not fully re-read |
| September council RC-01 | unverified | partial for the callback allowance oracle only. Production lock unverified |

No other first-pass verdict is withdrawn.

## Unresolved dissent

- MiniMax treats the legacy V4 execution-delegate hop as Applied RC-01 because the callee is not `address(this)`. Astra, Kimi, and this cross-review treat the later item PRD and plan as forbidding that hop when the facet already inherits the function. No supplied owner acceptance of the hop was re-read. The dissent stands.
- REQ-C06 measurement versus comparison. Astra, Kimi, and MiniMax treat the post-authentication credit revert as enough to mark the item applied or unverified-but-not-a-defect. This cross-review keeps a Low measurement-order mismatch because the PRD sentence was not withdrawn. The practical error reached on the tested short-credit route was not executed.
- REQ-C04 label. MiniMax says regressed. This cross-review says not applied. The source defect is not in dispute.
- Legacy V4 disable check versus a possible unrecorded owner ruling that SY exits stay open while disabled. The FullSpread README says that for FullSpread. It was not re-read as a ruling for legacy V4. The plan sentence stands until such a ruling is produced.
- REQ-C03. All four originals treat the witness source as present and distinct from the quote-stage tests. Whether `pool.swap` returns a short delta or reverts inside the pool after the fixture changes liquidity was not executed. If the pool reverts first, the witness does not reach `:534-536`. That remains an evidence gap, not a confirmed absence of the test.
- September council production repairs other than the README sentence and the Balancer callback oracle were not re-read. Astra's production-positive notes on those IDs are not adopted.

## Evidence gaps

- Forge was not run. No original's green-test implication is adopted.
- Production Balancer lock, approval reset, and reserve sync were not re-read this turn.
- Reentrancy, fuzz, and scanner bodies for REQ-03 were not re-read this turn.
- Single non-CP matrix behavior was not body-read. The six `previewMatch` sites above were.
- Constructor immutables of the legacy V4 execution delegate were not compared with the facet.
- No source identity hash was computed.

I did not run Forge.
