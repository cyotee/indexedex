# MiniMax M3 — Original first pass: APEX remediation-application review

- **Date:** 2026-10-14
- **Reviewer:** MiniMax M3 (independent first pass; no peer originals read)
- **Target:** current IndexedEx working tree, current state 2026-10-14
- **Question:** Have the remediations defined in `docs/reviews` been correctly applied?
- **I did not run Forge.** No `forge build`, `forge test`, or shell command was executed. Source presence is not a passing run.

## Controlling documents

I re-read the following documents this round. Later text withdraws an earlier draft where both exist:

1. `docs/reviews/apex-rc01-explicit-holder/REMEDIATION_PRD.md` and `REMEDIATION_PRD.plan.md` — RC-01
2. `docs/reviews/apex-req-c03-exact-output-settlement-witness/REMEDIATION_PRD.md` and `REMEDIATION_PRD.plan.md` — REQ-C03
3. `docs/reviews/apex-req-c04-hook-zero/REMEDIATION_PRD.md` and `REMEDIATION_PRD.plan.md` — REQ-C04
4. `docs/reviews/apex-req-c05-uniswap-readme/REMEDIATION_PRD.md` and `REMEDIATION_PRD.plan.md` — REQ-C05
5. `docs/reviews/apex-req-c06-pretransfer-caller-first/REMEDIATION_PRD.md` and `REMEDIATION_PRD.plan.md` — REQ-C06
6. `docs/reviews/apex-stage2-council-2026-10-07/FIX_PRD.md` and `FIX_PRD.plan.md` — RC-02, RC-03, RC-04, RC-05, RC-06 elaboration
7. `docs/reviews/apex-stage2-remediation-confirmation-2026-10-11/REMEDIATION_PRD.md` — prior confirmation claims (re-verified only for items cited below; not adopted as proof)
8. `docs/reviews/apex-stage2-council-2026-10-07/REMEDIATION_PRD.md` — earlier draft, subordinate to FIX_PRD
9. `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` and `REMEDIATION_PRD.plan.md` — Stage-1 items REQ-01 / REQ-02 / OD-08 still in force unless withdrawn
10. `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md` — earlier confirmed findings

I did **not** re-read the Stage-1 PRD line by line; only OD-08 and the hook-zero resolution it controls are referenced below. Items I did not re-read are marked `unverified`.

## Verdict table

| ID | Verdict | Evidence file:line |
|----|---------|---------------------|
| RC-01 (V3 FullSpread holder path) | Applied | `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol:212-261`; `UniswapV3FullSpreadStandardYieldExecutionTarget.sol:12-30`; `UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate.sol:19-26` |
| RC-01 (legacy V4 holder path) | Applied | `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInBase.sol:146-201`; `UniswapV4StandardYieldExecutionTarget.sol:11-36`; `UniswapV4StandardExchangeInExecutionDelegate.sol:13-34` |
| RC-01 (V4 `_secureShareDelivery` self-call branch removed) | Applied | `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol:1301-1319` |
| RC-01 (Native SY shared adapter no `address(this).call`) | Applied | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:29-44, 59-66`; no `NativeStandardYieldContextRepo` source remains in `contracts/` |
| RC-01 (README `:56` self-call sentence removed) | Applied | `contracts/vaults/standard/exchange/protocols/uniswap/README.md:43` |
| RC-01 (`executeZapOutWithdrawal` unchanged) | Applied | `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:14-70` |
| RC-02 (Camelot zap-out `MaxAmountExceeded` before burn) | Applied | `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol:761-768` |
| RC-03 (V3 package deleted) | Applied | `contracts/protocols/dexes/uniswap/` contains only `v2/`, `v4/` |
| RC-04 (V3 quote rejects incomplete) | Applied | `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:282-284` |
| RC-04 (V3 settlement checks output delta) | Applied | `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:533-537` |
| RC-05 (Rocket Pool one sleeve-excess decision) | Applied | `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol:511-519` |
| RC-06 (DETF helper uses zero preview signal) | Applied | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:621-638` |
| REQ-C01 (legacy V4 internal-balance redemption does not re-enter `exchangeIn`) | Applied | `UniswapV4StandardYieldExecutionTarget.sol:11-36`; `_secureShareDelivery` no longer recognises `msg.sender == address(this)` |
| REQ-C02 (V3 ordinary redemption allows code-less holder) | Applied | `UniswapV3FullSpreadStandardYieldExecutionTarget.sol:18-24`; `UniswapV3FullSpreadVaultHeldRedeem.t.sol:105-122` |
| REQ-C03 (settlement witness on production proxy) | Applied | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadExactOutputFill.t.sol:108-139` (`test_RC04_acceptedQuote_shortPayment_revertsSettlementAndRestoresCaller`) |
| **REQ-C04 (hook preview of zero rolls back)** | **Not applied (regressed: hook-zero path still returns 0 and the join loops still treat it as ordinary no-progress)** | `UniswapV4DetfCommon.sol:604-605`, `:614-615`, `:565`, `:590`; `UniswapV4DetfLeftoverPreview.t.sol:53-84`; `UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol:46-58` |
| REQ-C05 (README updated; no self-call; V3 path absent) | Applied | `contracts/vaults/standard/exchange/protocols/uniswap/README.md:3, 43` |
| REQ-C06 (V3 caller-before-credit on pretransfer) | Applied | `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:81-86`; `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:30-36, 102-112` |
| REQ-C06 (hookless caller-before-credit on pretransfer) | Applied | `UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:138-142`; called from `_executeZapInMintExactOut` line 100-103 and `_executeDirectOut` line 169 |
| REQ-C06 (Pons caller-before-credit on pretransfer) | Applied | `UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol:138-142`; called from `_executeZapInMintExactOut` line 100-103 and `_executeDirectOut` line 169 |
| OD-08 / Stage-1 hook-zero rule | Not applied (same defect as REQ-C04 above) | `UniswapV4DetfCommon.sol:600-619, 543-545` |

### Stage-1 September IDs not re-read this round

These IDs appear in `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` and `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`. I did not re-read the controlling lines for them this round, so each is **unverified** for application state. Marking unverified per coordinator instruction.

| ID | Disposition in this pass |
|----|--------------------------|
| REQ-01 (DETF residual helper reverts not caught) | unverified |
| REQ-02 (previewResidualBuffer stays direct) | unverified |
| REQ-03 (custody negatives pinned) | unverified |
| REQ-04 (matrix rounding controls) | unverified |
| REQ-05 (outside-trade credit on new vaults) | unverified |
| REQ-06 (OpenZeppelin direction for `maxRedeem`/`maxWithdraw`) | unverified |
| REQ-07 (plain rate path, no empty-state `quoteState` gas branch) | unverified |
| REQ-08 (current-source map, hookless / Pons-family split) | unverified |
| RC-01 … RC-08 (September council) | unverified for each line not separately re-read above |
| A-F02, A-F03, B-03, B-04, B-05, C-001 … C-007, D-F01, D-F02, D-F04, D-X01 | unverified |
| `beforeSwap` retraction; weighted-dust High retraction | unverified |
| RC-07 (`scripts/r12_selector_size_compare.py`) | **withdrawn by FIX_PRD — owner 2026-10-07 ignore.** Not a current requirement; script not edited is the correct disposition. No inspection required. |

## Findings

### F1 — REQ-C04 / OD-08: hook preview of zero still books instead of rolling back

- **Severity:** Medium (PRD REQ-C04 severity; OD-08 inherits the rule from Stage-1 REQ-01)
- **File and line:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:604-605`, `:614-615`, `:565`, `:590`, `:543-545`
- **Remediation ID:** REQ-C04 (and OD-08 / Stage-1 REQ-01)
- **Intended behavior (from REQ-C04 PRD, paraphrased):** A hook preview of `0` in `_entryJoinResidualAtomic` reverts (it does not return `0`). The join loops do not treat that zero as ordinary no-progress and do not switch modes. The terminal `_updateReserve` at `:543-545` is still present and runs only after a successful join that did not encounter a hook preview of zero.
- **Broken requirement / invariant:** Both hook-preview checks still return `0` instead of reverting (`UniswapV4DetfCommon.sol:604-605` and `:614-615`). The join loops still break on `lpOut_ == 0` at `:565` and `:590`. The terminal `_updateReserve` at `:543-545` therefore runs after a hook-zero return and books the local balance. The PRD forbids this; OD-08 narrows book-and-wait to a successful Standard Exchange `previewExchangeIn` of `0` only.
- **Impact class:** Error propagation and residual accounting. A returned hook zero currently books the local balance; the parent does not roll back.
- **Fix direction:** Make the two hook-preview checks in `_entryJoinResidualAtomic` revert with `ResidualJoinUnavailable` (the error already used at `:618`) instead of returning `0`. Remove the `lpOut_ == 0` break branches at `:565` and `:590` once the producer can no longer return a zero. Do not add a `catch`. Rewrite the comments at `:543-544`, `:548-549`, and `:612-613` so they no longer describe retention or mode-switching after a hook zero.
- **Confidence:** High (source reads)
- **Observed fact vs inference:** Observed: the source still returns `0` and breaks on zero. Inference: the parent therefore does not roll back on a hook-zero path; the terminal reserve update at `:543-545` runs.

### F2 — REQ-C04: tests still expect the hook-zero single-asset fallback and retention

- **Severity:** Medium
- **File and line:**
  - `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/UniswapV4DetfLeftoverPreview.t.sol:52-84`
  - `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol:46-58`
- **Remediation ID:** REQ-C04 (test mirror of F1)
- **Intended behavior (from REQ-C04 plan, paraphrased):** Replace `test_RC06_nonzeroPreview_usesSingleAssetFallback` so it expects the parent to revert `ResidualJoinUnavailable`, the single-asset join not to be called, and the prior reserve to be unchanged. Rename it so the name no longer advertises the fallback as the expected path. Split the residual-gas file's retention check so a hook-zero preview is not treated the same as a Standard Exchange zero. Rewrite the assertion messages in `UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol` that still say "zero unbalanced LP selects single-asset retry".
- **Broken requirement / invariant:** `test_RC06_nonzeroPreview_usesSingleAssetFallback` (line 53-84) still expects the hook `previewJoinUnbalanced` returning `0` to fall through to `previewJoinSingleAssetExactIn` and to a successful `joinSingleAssetExactIn`, then asserts that `pairToken.balanceOf(detf)` drops below the held amount ("mintable residual deployed"). The product-law file at lines 46-58 still asserts `"zero unbalanced LP selects single-asset retry"` and `"single-asset quote is zero, not a revert"`. These are precisely the assertions the PRD requires to be replaced.
- **Impact class:** Test gap. A green run on this file today would prove the old behaviour, not the locked one. Combined with F1, the requirement is regressed in both source and test.
- **Fix direction:** Apply the rewrites named in REQ-C04 plan Step 4: change the leftover-preview test to assert revert and no book; split the residual-gas retention check; rename the test; rewrite the product-law file's assertion messages.
- **Confidence:** High
- **Observed fact vs inference:** Observed: the test bodies and messages still match the withdrawn hook-zero behaviour. Inference: running the suite today green-greens the old path, not the locked path.

### F3 — Adjacent: V3 `_secureTokenTransfer` does the caller-before-credit order; this is a positive observation, not a defect

- **Severity:** n/a (informational)
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:864-885`
- **Remediation ID:** REQ-C06 (cross-reference, not a finding)
- **Intended behavior (from RC-01 + REQ-C06 PRD):** On a real external pretransfer, the caller must be checked before the available-balance comparison.
- **Broken requirement / invariant:** None observed. `_secureTokenTransfer` calls `LocalCreditLib.requirePretransferCaller(msg.sender)` (line 868) and only then computes the available credit. This matches the order the REQ-C06 PRD asks the named pretransfer branches to match.
- **Impact class:** Authorization order; positive.
- **Fix direction:** None required.
- **Confidence:** High
- **Observed fact vs inference:** Observed.

### F4 — Adjacent: V4 `UniswapV4StandardExchangeOutExecutionDelegate` still calls `IStandardExchangeIn(address(this)).previewExchangeIn(...)` and `IStandardExchangeOut(address(this)).previewExchangeOut(...)`

- **Severity:** Low (boundary observation)
- **File and line:** `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutExecutionDelegate.sol:88-90, 93-97`
- **Remediation ID:** RC-01 (boundary check)
- **Intended behavior (RC-01 PRD):** "No production yield redemption reaches `exchangeIn` through a call to self." Previews are excluded from this rule by virtue of being view functions, and the PRD explicitly says a view `previewExchangeIn` is not the hit.
- **Broken requirement / invariant:** None observed. Both `address(this)` calls are typed `IStandardExchangeIn/Out(address(this)).preview{ExchangeIn,ExchangeOut}(...)`. `previewExchangeIn` and `previewExchangeOut` are declared `view` in `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:45` and `IStandardExchangeOut.sol:51`. They are not money paths and the PRD does not treat them as the defect.
- **Impact class:** Documentation / reader clarity only.
- **Fix direction:** None required. If a future rule were ever to extend to view calls, a comment explaining why these `address(this)` calls are exempted would help future readers.
- **Confidence:** Medium (relies on Crane interface being view-only and not being overridden to a non-view implementation)
- **Observed fact vs inference:** Observed: the interface declarations are `view`. Inference: nothing currently overrides them to non-view in this tree.

## Adjacent / scope notes (not findings)

- **`scripts/r12_selector_size_compare.py`** — FIX_PRD records RC-07 as ignored by owner decision 2026-10-07. Not editing that script is the correct disposition. Not in scope.
- **`NativeStandardYieldContextRepo`** — removed from `contracts/`. Matches RC-01 plan Step 5.5 ("Delete `NativeStandardYieldContextRepo` unless a cited family uses it for something other than remembering the caller across the self-call."). Two markdown files in `contracts/vaults/standard/exchange/protocols/uniswap/` still mention the name in prose; those are historical plan files and not production source. Not in scope.
- **V4 `_secureShareDelivery`** — the comment at `:1304` mentions "self-call" in the historical tense ("The old ERC-20 self-call spent the vault's allowance..."). The PRD acceptance criterion was about removing the `msg.sender == address(this)` branch, not the historical comment. The branch is gone; the prose remains descriptive. Partial on the comment if a stricter reading were intended, but not a defect on the RC-01 line.
- **Stage-1 September PRD items REQ-01 through REQ-08 and September RC-01 through RC-08** — not re-read this round beyond OD-08; marked unverified in the table. The hook-zero regression (F1, F2) is the only Stage-1 item I confirm regressed.
- **Fork tests, follow-up claim of 34,909 tests, hook × SE matrix recount, DETF prepaid entries outside residual helpers** — not re-read; unverified. No green-test claim is adopted as proof.

## Evidence gaps

- I did not re-read the September REQ-01 / REQ-02 helper bodies beyond the citations needed for OD-08. The hook-zero regression is the only Stage-1 item I can confirm or refute from this round.
- I did not run the Suite that would execute the new settlement witness or the new vault-held redeem tests. Source presence is not a passing run.
- I did not re-read the script `scripts/r12_selector_size_compare.py`. It is withdrawn by owner ruling, so I did not need to.
- I did not re-read the fix-PLD § RC-01 acceptance lists item by item. I sampled `_redeemVaultHeld` and `_standardRoute` on the V3 YieldExecutionTarget and the V4 YieldExecutionTarget, and the comments around them, and I confirmed the shared `NativeStandardYieldMoneyTarget` entry points. I did not exhaustively audit every inheritor named in the FIX_PRD inventory (`ERC4626StandardYieldTarget`, `MorphoBlueStandardYieldTarget`, `LidoWstETHStandardYieldTarget`, `EtherFiWeETHStandardYieldTarget`, `AaveV3StataStandardYieldTarget`, `BalancerV3PoolStandardExchangeTarget`, `ConstantProductStandardYieldTarget`, `UniswapV4UpperLowerWingsStandardExchangeVaultSYTarget`, `UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawTarget`). Each of those is a non-required-call-to-self risk if the search was incomplete. The PRC-01 plan explicitly says to cite-and-leave-alone a family that already passes an explicit holder; I did not enumerate every family to confirm that. Marked partial / unverified for the global RC-01 inventory.
- The V4 `_secureShareDelivery` prose comment at `:1304` still references the historical "self-call". The PRD's "delete the comment that says to reuse exchangeIn for vault-held shares" (RC-01 plan Step 5) targets the V4 `_redeemVaultHeld` comment at `:20-24`. That comment no longer exists at the originally-cited line because the V4 yield facet no longer overrides `_redeemVaultHeld` at that exact location — the override moved to `UniswapV4StandardYieldExecutionTarget.sol`. I read the new override and confirmed there is no "reuse exchangeIn for vault-held shares" comment in it. The `:1304` comment is a separate sentence about the false-flag self-call allowance; it is descriptive of history. Treating as partial / adjacent, not a defect.

## Dissent I cannot resolve from the documents

- The PRD for RC-01 (apex-rc01-explicit-holder) and FIX_PRD RC-01 disagree on whether the new V4 yield override is acceptable as a `delegatecall` to `executeNamedHolderRedemption` on a different execution-delegate contract. FIX_PRD says: "`delegatecall` to a different execution-delegate contract is not a call to self." The RC-01 plan Step 2 says: "Do not copy that base `delegatecall` of `exchangeIn` on `address(this)` into the share-redemption branch." The current V4 yield facet does `delegatecall` to `UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE` (a different contract) using the function `executeNamedHolderRedemption` (5-arg). I read this as compliant because (a) the callee is not `address(this)`, (b) the function exists for exactly this purpose (line 12 comment: "Not installed on the diamond. The SY entrypoint validates and names its holder before delegation."), and (c) the wrapper is `delegatecall`, not `call`. FIX_PRD authority is acknowledged. No action recommended. Recording only because a stricter reading of the RC-01 plan could object.
- REQ-C04 (hook preview of zero rolls back) is a Stage-1 requirement controlled by OD-08. OD-08 wording: "A hook preview of `0`, or a hook join revert, rolls the parent transaction back. That path does not add a holder-reserve update and does not pay the amount out." Source and tests contradict this rule today. Whether a separate owner amendment has been recorded between 2026-10-07 (FIX_PRD) and 2026-10-14 (today) is not visible in the documents I re-read. If an amendment was issued, it is not in any document I read. Reporting as a current defect.

## Files examined where I found no defect

These source files were re-read this round; no defect observed relative to the controlling PRDs for items listed in the verdict table:

- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol`
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutBase.sol`
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInBase.sol`
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol`
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInExecutionDelegate.sol`
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutExecutionDelegate.sol`
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutExecuteTarget.sol`
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutBase.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardYieldExecutionTarget.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/README.md`
- `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol`
- `contracts/utils/LocalCreditLib.sol`
- `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol` (zap-out branch only)
- `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol` (sleeve-excess decision only)
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol` (lines 543-656 only)
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadExactOutputFill.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/UniswapV4DetfLeftoverPreview.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol` (lines 10-60 only)
- `contracts/protocols/dexes/uniswap/` directory listing (V3 absent, V2 + V4 present)

## Final note

**I did not run Forge.** No `forge build`, `forge test`, or shell command was executed. Source presence is not a passing run.