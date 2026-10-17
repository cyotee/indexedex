# Grok original — APEX remediation application

- **Reviewer:** Grok (`xai/grok-4.7`), independent first pass. Not the coordinator. Not a replacement.
- **Date:** 2026-10-14
- **Target:** current IndexedEx working tree. No source identity hash was recomputed. None is invented here.
- **Question:** Have the named remediations been correctly applied?
- **Forge:** not run. Source presence is not a passing test. A present assertion is not a green run.

Controlling text used: the item PRDs and plans named in the assignment, Stage-2 `FIX_PRD.md`, the 2026-10-11 confirmation PRD as a claim to re-verify, the 2026-10-07 Stage-2 draft as subordinate, and the September council and second-audit-readiness PRDs. Later text wins where it withdraws an earlier draft. Plans are specifications, not evidence of execution. Prior "confirmed executed" lists were not treated as still true.

This pass did not re-read every `.plan.md` in full. The RC-01 plan, the REQ-C04 plan opening, and the REQ-C06 plan through its named branches were re-read. Those plans say the item PRD controls on conflict.

## Findings

### 1. Legacy V4 yield redemption still delegatecalls a different execution delegate

- **Severity:** Low. The 2026-10-11 confirmation rated the self-call Medium. This differs because the identity-forging `exchangeIn` self-call is gone and the burn holder is an argument. What remains is the call shape the later PRD and plan forbid, not a restored self-call.
- **File and line:** `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol:26-35`. Inheritance that already contains the settlement: `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet.sol:13` through `UniswapV4StandardYieldExecutionTarget` and `UniswapV4StandardExchangeInTarget.sol:29` into `UniswapV4StandardExchangeInBase.sol:146-152`.
- **Remediation ID:** RC-01 / REQ-C01. REQ-C02's V3 ordinary path is not this finding.
- **Intended behavior:** The item PRD requires both yield facets to call the inherited exact-input settlement directly and pass the holder. "delegatecall to a different execution-delegate contract is not a call to self. It is also not the required path when the facet already inherits the settlement function." The plan repeats that this form "is not the yield path for these two facets" and says "Do not move the yield path onto a delegate, to get under the limit."
- **Broken requirement or invariant:** Vault-held and ordinary redemption pass the holder, then `delegatecall` `UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE.executeNamedHolderRedemption`. That delegate then calls `_executeZapOutExactIn` with the same holder. The facet already inherits `_executeZapOutExactIn`. V3 FullSpread does the required internal call (`UniswapV3FullSpreadStandardYieldExecutionTarget.sol:26-29`).
- **Impact class:** caller identity / specification conformance. `delegatecall` to a different contract does not make `msg.sender` the vault. It is not the withdrawn self-call. It is still the forbidden reuse shape for this family.
- **Fix direction:** Call the inherited `_executeZapOutExactIn` directly from the yield path, as V3 does, and pass `address(this)` or the original caller. Do not keep the execution-delegate hop to satisfy a size limit. Keep the public four-argument wrapper unchanged.
- **Confidence:** high that the call shape violates the PRD and plan. Medium that runtime settlement still matches an internal call, because the delegate uses the same base and this pass did not compare constructor immutables.
- **Fact:** the yield function delegatecalls a stored delegate address, not `address(this)`. Both burn sites in `_executeZapOutExactIn` use `holder_` (`UniswapV4StandardExchangeInBase.sol:174` and `:197`). `_secureShareDelivery` no longer has `msg.sender == address(this)` (`UniswapV4StandardExchangeCommon.sol:1301-1318`).
- **Inference:** the `noSelfCalls` modifier in `contracts/vaults/standard/sy/Behavior_NativeStandardYieldExecution.sol:23-27` permits delegatecalls to a distinct implementation, so the legacy V4 suite can pass without witnessing the required internal call.
- **Speculation:** none on loss. No unauthorized payout was established from this shape.

### 2. Legacy V4 direct yield path does not keep the disable check

- **Severity:** Medium for a required gate that the public `exchangeIn` path still has and the repaired yield path does not. No loss amount was established. This is not the confirmation's self-call severity.
- **File and line:** `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol:26-35` does not call `_requireNotDisabled`. That check is `UniswapV4StandardExchangeCommon.sol:71-74` and is used by public `exchangeIn` at `UniswapV4StandardExchangeInTarget.sol:55`.
- **Remediation ID:** RC-01 plan step 2. The item PRD acceptance list does not name this check. The plan does, and it is a controlling specification.
- **Intended behavior:** "The direct yield path must keep the protections the external `exchangeIn` used to supply: the reentrancy lock, the disable check, and the post-settlement TWAP update. Do not re-enter `exchangeIn` to obtain them."
- **Broken requirement or invariant:** The yield helper is `nonReentrant` and calls `_pokeBoundPoolTwap` after the delegatecall. It does not call `_requireNotDisabled`. A disabled vault can still enter SY redemption on this path. Public `exchangeIn` cannot.
- **Impact class:** authorization / disable gate.
- **Fix direction:** Call the existing disable check on the direct yield path before burn, without re-entering `exchangeIn`. Do not treat the FullSpread README sentence about allowing SY exits when disabled as this legacy V4 rule; that README is the FullSpread family file.
- **Confidence:** high that the check is absent from the yield helper. Medium that product intent still wants the check, because the plan requires it and this pass did not find a later withdrawal.
- **Fact:** `_requireNotDisabled` reverts `VaultDisabled` when the registry reports the vault disabled. The yield helper does not call it.
- **Inference:** the old self-call into `exchangeIn` would have hit this check. Removing the self-call without copying the check drops the gate.
- **Speculation:** none that a disabled vault was observed redeeming.

### 3. Hook preview of zero still returns success and can book

- **Severity:** Medium. Same as REQ-C04 / Stage-1 REQ-01. Current code does not reduce that impact class.
- **File and line:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:604-605`, `:614-615`, loop stops `:565` and `:590`, terminal book `:543-545`. Comments that still teach the old shape: `:548-549` and `:612-613`.
- **Remediation ID:** REQ-C04, which is Stage-1 REQ-01 / OD-08. Not RC-06. The helper repair is a different function.
- **Intended behavior:** "A hook preview of `0`, or a hook join revert, rolls the parent transaction back. It does not book a new holder reserve. It does not continue into another join mode." Book-and-wait remains only a successful Standard Exchange `previewExchangeIn` of `0`.
- **Broken requirement or invariant:** Both hook-preview branches still `return 0` when the quote is `0`. The join loops still treat `lpOut_ == 0` as an ordinary stop. `_tryJoinResidual` then writes the full local balance at `:543-545`. A proportional hook preview of `0` can fall through to the single-asset mode. The comments still say a zero complete-route quote retains the booked remainder and that a one-sided proportional join can be unsupported and continue.
- **Impact class:** value accounting / residual retention. A soft zero is still translated into a book or the other join mode. Financial loss was not demonstrated.
- **Fix direction:** Revert at both hook-preview checks. Do not return `0`. Do not catch that revert. Remove the loop stops that exist only to consume that zero. Keep the terminal reserve update for joins that did not see a hook preview of zero, and rewrite the comments and tests that expect the fallback.
- **Confidence:** high.
- **Fact:** `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/UniswapV4DetfLeftoverPreview.t.sol:52-73` is still named `test_RC06_nonzeroPreview_usesSingleAssetFallback` and expects `previewJoinUnbalanced` of `0` to continue into `joinSingleAssetExactIn`. That is the continuation OD-08 forbids. `_retainSubSharePairResidual` at `:625-637` is the separate RC-06 helper and was not the missing change.
- **Inference:** a green run of that fallback test would confirm the defect remains, not close REQ-C04.
- **Speculation:** none that a holder was underpaid.

### 4. Hookless and Pons still measure pretransfer credit before the caller check

- **Severity:** Low. Same as REQ-C06. The reverting credit comparison was moved behind the caller check, so the impact is narrower than the original credit-error-first defect. It is not closed.
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:94-101` and `:165-169`. Same mint order at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol:94-101`. V3 mint delegate has the same measurement-before-check shape at `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:102-110`.
- **Remediation ID:** REQ-C06. Owner decision 2026-10-11.
- **Intended behavior:** "On a pretransfer, the caller is authenticated before the credit is measured. A code-less caller is rejected with `EOAPretransferNotAllowed` even when the pushed credit is also short." The plan says the PRD controls, and also tells the implementer to place the caller check before the short-credit revert.
- **Broken requirement or invariant:** `_pretransferCredit` runs, and on the direct-out path the plan is built from that credit, before `requirePretransferCaller`. The later `_requirePrepaidCredit` does check the caller before `TransferDeltaInsufficient`. That fixes the named comparison order. It does not authenticate before measurement. V3's quoted exact-output branch does the required order (`UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:81-84`).
- **Impact class:** diagnostic order. Not an authorization bypass. Not REQ-C02.
- **Fix direction:** On each prepaid branch, call `requirePretransferCaller` before `_pretransferCredit` and before any quote or plan that consumes that credit. Keep the short-credit revert after that check. Do not add the check to a false-flag path.
- **Confidence:** high that measurement precedes the caller check. Medium that a code-less short-credit caller can still see `UniswapV4ExchangeOut_InsufficientInput` before `EOAPretransferNotAllowed` when the zero-credit plan's input exceeds the maximum. That second sentence is inference from the source order. Forge was not run.
- **Fact:** `_pretransferCredit` itself does not revert (`UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol:945-952`). The comparison revert is after the caller check. Tests in `ApexRecurrenceErrorOrder.t.sol` for hookless and Pons expect `EOAPretransferNotAllowed` for a code-less exact-output caller with no credit. Those tests were not run.
- **Inference:** the plan's "before the comparison" instruction was followed; the PRD's "before the credit is measured" sentence was not.
- **Speculation:** none that tokens move. The call still reverts.

### 5. Adjacent — rebasing SY comment still describes a vault self-call path

- **Severity:** Low. Adjacent to RC-01 comment cleanup. Not a new product requirement.
- **File and line:** `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol:41-44` and the exemption at `:57-58`.
- **Remediation ID:** RC-01 comment rule. The item PRD includes NatSpec that tells a later agent to call self.
- **Intended behavior:** Comments must not describe internal-balance redemption as a proxy self-call or tell a later agent to call self.
- **Broken requirement or invariant:** The NatSpec says "The vault's own self-call path is unaffected" and the code skips `requirePretransferCaller` when `msg.sender == address(this)`. This function does not itself call `address(this)`.
- **Impact class:** documentation. It can recreate the recurrence the item PRD describes.
- **Fix direction:** Delete the self-call sentence. If no production caller still enters this function as the vault, delete the `msg.sender == address(this)` exemption. Do not add a self-call to preserve the comment.
- **Confidence:** high that the comment teaches a self-call. Medium that no remaining caller uses that exemption. This pass did not find a production `address(this)` call into this redeem.
- **Fact:** the comment and the exemption are present. `NativeStandardYieldContextRepo` was not found under `contracts/`.
- **Inference:** the exemption is leftover from the withdrawn self-call design.
- **Speculation:** none that this function is currently reached by a self-call.

## Verdict table

"Applied" means the acceptance criteria re-read in this pass match current source. It does not mean Forge passed. "Partial" includes a required test that was not found, or a repair whose outcome is only partly present.

| ID | Verdict | Evidence file:line |
| --- | --- | --- |
| RC-01 / REQ-C01 legacy V4 yield shape | partial | `UniswapV4StandardYieldExecutionTarget.sol:26-35` delegatecalls a different delegate. Holder is passed. Self-call into `exchangeIn` is gone. |
| RC-01 / REQ-C02 V3 FullSpread yield | applied | `UniswapV3FullSpreadStandardYieldExecutionTarget.sol:12-29` calls inherited `_executeZapOutExactIn` with `address(this)` or `msg.sender`. Burns at `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:236` and `:257`. Tests in `UniswapV3FullSpreadVaultHeldRedeem.t.sol:77-121` use a code-less holder. Not run. |
| RC-01 shared adapter self-call | applied | `NativeStandardYieldTarget.sol:35-40` checks the caller, then `_redeemVaultHeld`. No `address(this).call`. |
| RC-01 legacy V4 disable check (plan) | not applied | Yield helper does not call `_requireNotDisabled` (`UniswapV4StandardExchangeCommon.sol:71-74`). Public `exchangeIn` does (`InTarget.sol:55`). |
| RC-01 self-call-plus-caller-check draft | not a current requirement | FIX_PRD: "That repair is withdrawn. The self-call is the design error." Item PRD: "A caller check in front of a self-call is not the repair." |
| RC-02 Camelot zap-out maximum | applied | Comparison before burn at `CamelotV2StandardExchangeOutTarget.sol:761-768`, both flags. Tests in `CamelotV2ZapOutMaxAmountIn.t.sol:33-48`. Not run. |
| RC-03 delete old V3 package | applied | `contracts/protocols/dexes/uniswap/` contains `v2/` and `v4/` only. No `deployUniswapV3StandardExchangeDFPkg` under `contracts/**/*.sol` or `scripts/`. Named stages call `deployUniswapV3FullSpreadStandardExchangeVaultDFPkg` (`Phase_05_Stage_04_UniswapV3StandardExchangePkg.sol:56` testnet and main; fee-DETF script `:129`). DETF deploy lib imports FullSpread (`UniswapV4DetfProductionSeDeployLib.sol:85-88`). |
| RC-03 legacy V4 stored-total credit | not a current requirement | FIX_PRD kept `contracts/protocols/dexes/uniswap/v4` and did not authorize that accounting repair. The subtraction remains at `UniswapV4StandardExchangeCommon.sol:1269-1272`. |
| RC-04 quote and settlement checks | applied | Incomplete quote reverts at `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:282-284`. Post-swap output check at `:534-536`. Input-ceiling name `UniswapV3Exchange_InsufficientOutput` at `:528-529` is a recorded non-goal. |
| REQ-C03 settlement witness | applied | `UniswapV3FullSpreadExactOutputFill.t.sol:15-17` says quote-stage tests do not cover the post-swap guard. `:110-138` expects `ExactOutputNotFilled` with paid `0` after an accepted quote, and asserts the caller input is unchanged. Fillable case remains at `:79-105`. Hookless, Pons, and Wings are not this witness. Not run. Reachability of `:534-535` if the pool reverts inside `swap` is an evidence gap, not a confirmed miss. |
| RC-05 Rocket sleeve accumulation | applied | `_bestEffortStakeOverageTowardTarget` is one excess decision (`RocketPoolRETHStandardExchangeCommon.sol:511-518`). No booked-first split. `liquidReserveEth` remains. Tests in `RocketPoolSleeveExcessStake.t.sol:17-37`. Not run. |
| RC-05 never-combine draft | not a current requirement | FIX_PRD: small credits accumulate in the sleeve. Confirmation: the earlier "never combine" objective is not a valid remaining requirement. |
| RC-06 helper | applied | `_retainSubSharePairResidual` books only after `previewExchangeIn` of that amount returns zero (`UniswapV4DetfCommon.sol:625-637`). No one-share quote. The `supportsInterface` catch returns false and does not book. |
| REQ-C04 / REQ-01 / OD-08 hook zero | not applied | See finding 3. `UniswapV4DetfCommon.sol:604-605` and `:614-615` still return `0`. |
| REQ-C05 README | applied | `contracts/vaults/standard/exchange/protocols/uniswap/README.md:3` names FullSpread, says the old V3 tree was removed, and limits the stored-reserve warning to retained legacy V4. `:13` says the maps are historical and the old V3 tree is absent. `:56` says the holder is an argument and redemption does not call `address(this)`. |
| REQ-C06 V3 quoted exact-output | applied | Caller check, then credit measurement, then comparison at `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:81-84`. |
| REQ-C06 hookless / Pons / V3 mint measurement order | partial | See finding 4. Comparison revert is after the caller check. Measurement is not. |
| RC-07 selector-script repair | not a current requirement | FIX_PRD: "RC-07 is ignored. Owner 2026-10-07: `r12_selector_size_compare.py` is a prior audit tool. Do not repair it." |
| Stage-1 REQ-02 zero residual preview | partial | `previewResidualBuffer` is a direct `previewExchangeIn` with no catch (`UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:384-388`). No test under `test/` names `previewResidualBuffer`. The required regressions were not found. |
| Stage-1 REQ-03 custody negatives | unverified | Cited tests were not re-read. |
| Stage-1 REQ-04 matrix catch-all | unverified | Cited matrix behaviors were not re-read. |
| Stage-1 REQ-05 outside-trade credit | applied | Separate tests for V3 (`UniswapV3FullSpreadStandardExchangeVault_FeeCompound.t.sol:50-74`), hookless (`AttributionAndBooking.t.sol:34-48`), Pons (`AttributionAndBooking.t.sol:37-51`), and wings (`UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol:26-39`). Each follows an outside trade with a deposit credited only from the funded input. Not run. |
| Stage-1 REQ-06 maxRedeem direction | partial | `maxWithdraw` is `previewRedeem(maxRedeem(owner))` and `maxRedeem` does not call `maxWithdraw` (`ReceiptBackedERC4626Target.sol:67-80`). Shared behavior tests exist at `Behavior_ReceiptBackedERC4626_CrossInterface.sol:172-216`. Both dispatched families executing those tests was not re-read. |
| Stage-1 REQ-07 plain rate, no gas snapshot | partial | `_getRate` does not call `quoteState` or `gasleft` (`StandardExchangeRateProviderFacet.sol:61-82`). No `gasleft` match in that file. The required empty-state and failed-snapshot tests were not found under `*RateProvider*`. |
| Stage-1 REQ-08 current-tree evidence | unverified | This pass did not re-read a regenerated build, selector, size, or regression artifact bound to this tree. Ignoring the selector script is not closure of REQ-08. |
| September council RC-01 Balancer reentrancy | unverified | Cited adapter was not re-read. Later documents do not withdraw this repair. |
| September council RC-02 local-first payout | unverified | Cited payout was not re-read. Not withdrawn. |
| September council RC-03 Stata backing | unverified | Cited backing functions were not re-read. Not withdrawn. |
| September council RC-04 stale comments | unverified | README delivery sentences were not re-checked against this ID except the REQ-C05 lines. Other cited comments were not re-read. |
| September council RC-05 unused single-CP `exchangeOut` | unverified | Cited function was not re-read. Not withdrawn. |
| September council RC-06 orbital share return | unverified | Cited assignment was not re-read. Not withdrawn. |
| September council RC-07 base availability panic | unverified | `BasicVaultCommon` was not re-read. Not withdrawn. |
| September council RC-08 Uni V2 named backing error | unverified | Cited revert was not re-read. Not withdrawn. |
| September council "preserve V3 and V4 trees" | not a current requirement for V3 | FIX_PRD RC-03 deletes `contracts/protocols/dexes/uniswap/v3`. V4 retention remains current. The V4 tree is present. |
| Confirmation "confirmed executed" list | not proof | Re-read above. Several of those claims still match source. REQ-C04 does not. RC-01's required internal call does not, for legacy V4. |

## Files re-read with no additional defect for the named requirement

- `contracts/utils/LocalCreditLib.sol:23-28` — caller check is the bytecode check. Not weakened on the sites re-read.
- `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:29-72` — no self-call. Internal-balance rejects a code-less caller before `_redeemVaultHeld`.
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate.sol:19-25` — public wrapper still has four arguments and passes `address(this)` after a pull. Yield does not call it.
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:29-34` — withdrawal delegate still checks the caller before the credit comparison. This item was not supposed to edit that function. Whether the file is byte-for-byte unchanged was not proven; the signature has no holder argument.
- `contracts/vaults/standard/erc4626/ERC4626StandardYieldTarget.sol:18-32` — burns `address(this)` without calling `address(this)`.
- `contracts/vaults/standard/sy/ConstantProductStandardYieldTarget.sol:55-58` — passes `address(this)` into `_redeemConstantProduct`.
- `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardYieldTarget.sol:13-18` — burns `address(this)` directly.
- Hookless and Pons `_redeemVaultHeld` delegatecall a different contract's `executeZapOutExactIn` and do not call `address(this)`. The item PRD says to leave that shape alone.
- Wings `_redeemVaultHeld` calls `Money.redeem` with the vault-held flag and does not call `exchangeIn`.
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutExecutionDelegate.sol` view `previewExchangeIn` on `address(this)` was not treated as a yield redemption. The item PRD says not to invent a hit from a view preview.

## Dissent this pass cannot resolve

- REQ-C06 measurement versus comparison. The PRD says authenticate before the credit is measured. The plan says place the caller check before the short-credit revert and says the PRD controls. The comparison order matches the plan. The measurement order does not match the PRD. This pass does not treat the plan as a withdrawal.
- Legacy V4 disable check versus exit-when-disabled. The RC-01 plan requires the yield path to keep `exchangeIn`'s disable check. The FullSpread README at line 58 says disabling allows SY redemptions. That README is not the legacy V4 package. No later sentence withdrawing the plan's disable-check sentence was re-read.
- REQ-C03. The witness source matches the acceptance text. Whether `pool.swap` returns a short delta or reverts before `:534-535` after the fixture changes the pool was not executed. That is an evidence gap, not a finding that the witness is absent.
- September council IDs above were not re-read. Absence of a finding is not a pass.

## Evidence gaps

- Forge, build, and tests were not run. No command is reported as green.
- No source identity hash was computed.
- C03, C04, C05, and C06 plans were not re-read in full. RC-01 plan was.
- A full search of every production pretransfer branch beyond the named V3, hookless, and Pons sites was not completed. Slipstream was not re-read. The REQ-C06 instruction is to record a Slipstream early credit revert and not rewrite it. That search is unverified.
- September council RC-01 through RC-08 production sites were not re-read.
- Stage-1 REQ-03, REQ-04, and REQ-08 artifacts were not re-read.
- Whether both receipt-backed families execute the REQ-06 behavior tests was not re-read.
- Constructor immutables of the legacy V4 execution delegate were not compared with the facet.
- This pass did not use other reviewers' files as evidence.

Forge was not run.
