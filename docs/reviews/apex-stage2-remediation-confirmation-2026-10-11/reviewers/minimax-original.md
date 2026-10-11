# APEX Stage 2 Remediation Confirmation — MiniMax M3 Original

- **Date:** 2026-10-11
- **Reviewer:** MiniMax M3 (session `ses_ee9ccf532ffe7kBBq6lhXrOnHr` per APEX_STAGE2_REVIEW_PRD §12.1, continuing)
- **Source:** IndexedEx working tree inspected 2026-10-11. No build, test, simulation, fork, RPC, deployment, or shell execution performed.
- **Scope:** Independent first-pass judgment on whether the remediations associated with the APEX Stage 2 program are correctly specified (FIX_PRD.md) and have been executed correctly in the current IndexedEx working tree.
- **Reference documents consulted (read directly, not through search):**
  - `docs/plans/APEX_STAGE2_REVIEW_PRD.md` and `docs/plans/APEX_STAGE2_REVIEW_PRD.plan.md`
  - `docs/research/apex-stage2-review/accepted-20261007/REPORT.md`, `REVIEW_MANIFEST.md`
  - `docs/research/apex-stage2-review/recurrence-20261007/REVIEW_MANIFEST.md`, `A-vaults-review.md`, `B-credit-lending.md`
  - `docs/reviews/apex-stage2-council-2026-10-07/FIX_PRD.md` and `FIX_PRD.plan.md` (controlling elaboration; corrections override older text)
  - `docs/reviews/apex-stage2-council-2026-10-07/REMEDIATION_PRD.md` (earlier draft context)
  - `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` (Stage-1 REQ-01 / REQ-08 continuity only, per coordinator instruction)
  - `CLAUDE.md` (current repo rules)
- **Documents intentionally NOT read** (per coordinator): any peer reviewer output under `docs/reviews/apex-stage2-remediation-confirmation-2026-10-11/`. This includes other first-pass originals.

---

## 1. Summary judgment

The six elaborated remediations (RC-01 through RC-06) have been executed in the current source tree in a way that satisfies the FIX_PRD text on the inspected surfaces. RC-07 is correctly recorded as ignored per the owner's explicit decision; the script remains unedited. One documentation gap (stale FullSpread README referencing the deleted `contracts/protocols/dexes/uniswap/v3/` path) was located and is recorded but is not itself a failed remediation.

No newly observed production-source defect is introduced by these repairs on the surfaces I read. Several accepted-report items (A-F01–A-F03, B-03–B-05, C-001–C-007, D-F01–D-F04, D-X01) are not elaborated into named remediations in `FIX_PRD.md`. Where Stage-1 RC items overlap with them, the elaboration controls; the rest are recorded as `NOT_A_REMEDIATION` for this round, not as new code defects. I did not execute any tests; runtime verification of the new tests remains outside this scope.

Confidence is high in the source-assertion facts cited below. Where confidence is bounded (e.g. catalog-wide applicability), the bound is stated.

---

## 2. Disposition table for in-scope RC items

Status vocabulary is per coordinator: `CONFIRMED_EXECUTED`, `PARTIALLY_EXECUTED`, `NOT_EXECUTED`, `SPEC_CONFLICT`, `NOT_A_REMEDIATION`, `UNVERIFIED`.

| ID | Spec anchor (controlling) | Source execution evidence | Tests status | Disposition | Independent notes |
|---|---|---|---|---|---|
| RC-01 | `FIX_PRD.md:21-113` (one elaboration) | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:35-85`; per-family overrides at lines 12-20 of ERC4626, MorphoBlue, LidoWstETH, RocketPoolRETH, EtherFiWeETH, AaveV3Stata SYs, BalancerV3PoolStandardExchangeTarget, ConstantProductStandardYieldTarget, UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget (V3 FS), UniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiQueryTarget (hookless), UniswapV4FullSpreadPonsFamilyHookOutMultiQueryTarget (Pons), UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawTarget, UniswapV4DualStandardExchangeBufferConstantProductHookSeTarget, UniswapV4StandardExchangeOrbitalBufferHookSeTarget, UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget, UniswapV4StandardExchangeBalancerQuadStableBufferHookQueryTarget, UniswapV4StandardExchangeCurveQuadStableBufferHookJoinQueryTarget, UniswapV4UpperLowerWingsStandardExchangeVaultSYTarget (Wings), UniswapV4StandardExchangeOutMultiQueryTarget (legacy V4) | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol`, `…/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessVaultHeldRedeem.t.sol`, `…/ponsFamilyV2Hook/UniswapV4FullSpreadPonsVaultHeldRedeem.t.sol`, `…/v4/upperLowerWings/UniswapV4UpperLowerWingsVaultHeldRedeem.t.sol` — all four families assert EOA `EOAPretransferNotAllowed`, contract caller redeems only vault-held shares, ordinary redeem burns caller shares | CONFIRMED_EXECUTED | (See Section 3.1) |
| RC-02 | `FIX_PRD.md:115-147` (one elaboration) | `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol:761-764` — shares-units comparison before `_secureSelfBurn` on both pretransfer flags | `test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2ZapOutMaxAmountIn.t.sol` covers pull/pretransferred rejection and pull/pretransferred success | CONFIRMED_EXECUTED | (See Section 3.2) |
| RC-03 | `FIX_PRD.md:149-196` (one elaboration with corrections) | `contracts/protocols/dexes/uniswap/v3/` does not exist (only `v2/` and `v4/`); scripts updated to `IUniswapV3FullSpreadStandardExchangeVaultDFPkg`; `UniswapV4DetfProductionSeDeployLib.sol:85-356` uses FullSpread package | No test still constructs `deployUniswapV3StandardExchangeDFPkg` in production code (grep returned only docs/implementation-artifacts); FullSpread packages retain `LocalCreditLib.available(balanceOf(this), _reserveOfToken(token))` check | CONFIRMED_EXECUTED (with stale README noted) | (See Section 3.3) |
| RC-04 | `FIX_PRD.md:198-241` (one elaboration) | `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:255-285` (`_quoteSwapOut` checks `fullyFilled && quote.amountOut == amountOut` and reverts with `UniswapV3Exchange_ExactOutputNotFilled`); `:505-537` (`_swapExactOut` checks input ceiling then outputPaid against amountOut) | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/ApexRecurrenceErrorOrder.t.sol:26-37` asserts partial-fill preview reverts with `UniswapV3Exchange_ExactOutputNotFilled`; `test_review_directExactOutSupportedControl` asserts funded control | CONFIRMED_EXECUTED (with a naming caveat) | (See Section 3.4) |
| RC-05 | `FIX_PRD.md:243-281` (corrected elaboration) | `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol:495-510` (`_bestEffortStakeOverageTowardTarget` does single excess decision with sleeve accumulation); `liquidReserveEth` retained; EtherFi unchanged (`contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeCommon.sol` has no `_bestEffortStakeOverageTowardTarget`) | `test/foundry/spec/protocol/staking/rocket-pool/RocketPoolSleeveExcessStake.t.sol` covers below-minimum retention, accumulation then stake of entire excess, capacity-capped accumulation | CONFIRMED_EXECUTED | (See Section 3.5) |
| RC-06 | `FIX_PRD.md:283-311` (one elaboration with `quoteInputForExactShares` prohibition) | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:625-638` (`_retainSubSharePairResidual` uses `previewExchangeIn(pair, amount, se) == 0`, books full local balance, `supportsInterface` catch returns false without booking) | `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/UniswapV4DetfLeftoverPreview.t.sol` — zero-preview retention, nonzero-preview single-asset fallback, reverting-preview propagation | CONFIRMED_EXECUTED | (See Section 3.6) |
| RC-07 | `FIX_PRD.md:18,103` (owner ruling recorded; FIX_PRD.plan.md:7) — script not repaired; EIP-170 still applies | `scripts/r12_selector_size_compare.py:35-62` — `discover_artifacts` still globs `*.sol` only in parent directories of baseline rows | Not authored as a remediation; the owner ruling is the closure | NOT_A_REMEDIATION (per owner ruling) | (See Section 3.7) |

### Accepted-report items not elaborated in FIX_PRD

| Item | Stage-1/Stage-2 source | Disposition | Note |
|---|---|---|---|
| A-F01 (FullSpread exact-output error precedence) | `accepted-20261007/REPORT.md:206-216` | NOT_A_REMEDIATION | RC-04 explicitly forbade renaming the existing input-ceiling revert error. The short-output case is now distinguished by `UniswapV3Exchange_ExactOutputNotFilled(uint256 requested, uint256 delivered)`. The historical `UniswapV3Exchange_InsufficientOutput` remains the input-ceiling revert and is intentionally misnamed per FIX_PRD §Non-goals. No new defect beyond the named-input mislabel; not a Stage-2 elaboration. |
| A-F02 / A-F03 / C-006 (Wings assertion gaps) | `accepted-20261007/REPORT.md:230-247, 278-288` | NOT_A_REMEDIATION | Wings supplementation falls outside RC-01–RC-06. RC-01 added per-family vault-held redeem tests (see disposition above). The campaign-vacuity (A-F03) and tautology (C-006) gaps are not elaborated in `FIX_PRD.md`. |
| B-03 / B-04 / B-05 (custody, EtherFi, receipt gaps) | `accepted-20261007/REPORT.md:110-132, 242-252` | NOT_A_REMEDIATION | Not elaborated in `FIX_PRD.md` for Stage 2. RC-05 explicitly excludes EtherFi; receipt adapter coverage is not addressed. |
| C-001 through C-007 | `accepted-20261007/REPORT.md:184-300` | NOT_A_REMEDIATION | Out of scope for Stage 2 elaboration. |
| D-F01 / D-F02 / D-F04 | `accepted-20261007/REPORT.md:158-169, 194-204, 302-312` | NOT_A_REMEDIATION | Test/evidence gaps; Stage-1 REQ-08 continuity only. RC-07 closure is by owner ruling. |
| D-X01 | `accepted-20261007/REPORT.md:170-180` | NOT_A_REMEDIATION | Aave R14.7 test gap; not elaborated in `FIX_PRD.md`. |

---

## 3. Findings

Findings are labeled MiniMax M3. Each finding has title, severity, file:line, intended behavior, broken requirement or invariant, impact class, fix direction, confidence, and whether it is a failed execution of a named remediation, a bad specification, or a new defect.

### 3.1 RC-01 — Native SY internal-balance redemption self-call removed (CONFIRMED_EXECUTED)

- **Severity:** Informational (closure evidence only).
- **Files and lines:**
  - `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:35-85`
  - Per-family overrides (line numbers above): ERC4626StandardYieldTarget.sol:17-35, RocketPoolRETHStandardYieldTarget.sol:12-20, LidoWstETHStandardYieldTarget.sol:12, EtherFiWeETHStandardYieldTarget.sol:12, AaveV3StataStandardYieldTarget.sol:20, MorphoBlueStandardYieldTarget.sol:12, BalancerV3PoolStandardExchangeTarget.sol:46, ConstantProductStandardYieldTarget.sol:15, UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol:24-35, UniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiQueryTarget.sol:23-35, UniswapV4FullSpreadPonsFamilyHookOutMultiQueryTarget.sol:23-35, UniswapV4UpperLowerWingsStandardExchangeVaultSYTarget.sol:12-18, UniswapV4StandardExchangeOutMultiQueryTarget.sol:17-25, plus the single-CP / weighted / balancer-quad / curve-quad / dual / orbital HookExitQuery/SeTarget overrides.
  - `contracts/utils/LocalCreditLib.sol:24-28` (the gate).
  - `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:282-293` (the shared `_burnSeShares` with explicit holder).
- **Intended behavior (per FIX_PRD §RC-01):** Internal-balance redemption burns the vault's own shares; no `address(this).call` is used; the holder is `address(this)` passed explicitly; `LocalCreditLib.requirePretransferCaller` rejects a code-less caller with `EOAPretransferNotAllowed` before any burn; ordinary redemption still burns the original caller's shares.
- **Observed behavior:**
  - `NativeStandardYieldTarget.redeem` at lines 35-52: when `internalBalance_` is true, it calls `LocalCreditLib.requirePretransferCaller(msg.sender)` (line 42) and `_requireVaultHeldShares(shares_)` (line 43) before `_redeemVaultHeld(...)` (line 44). No `address(this).call`.
  - `_standardRoute` (lines 56-73): internal=true branch goes to `_redeemVaultHeld` directly; internal=false (ordinary) uses `address(this).delegatecall(...)` to preserve the original payer.
  - The base `_redeemVaultHeld` reverts with `InvalidSYToken` (line 81-85); the SY adapter pattern requires each inheritor to override it. All named inheritors in the FIX_PRD list (and the inspected additional overrides) burn `address(this)` via `_burnSeShares(address(this), shares_, false)` or use a guarded internal delegatecall. None of the production source files contains `address(this).call` (grep returned only test bases in `contracts/test/bases/` and `contracts/vaults/detf/.../TestBase_*.sol`, plus a `LocalCreditLib.requirePretransferCaller`-shaped fixture; no `NativeStandardYieldContextRepo` source file exists).
  - `_burnSeShares(address owner, uint256 burnAmount, bool pretransferred)` (ERC4626StandardExchangeCommon.sol:282-293) honors `pretransferred=false` by burning exactly `burnAmount` from `owner` and `pretransferred=true` by requiring `requirePretransferCaller(msg.sender)` then burning exactly `burnAmount` from `address(this)`. `LocalCreditLib.requirePretransferCaller` (LocalCreditLib.sol:24-28) reverts with `EOAPretransferNotAllowed` when the caller has no bytecode.
- **Broken requirement or invariant:** None observed on the inspected source. The corrections in FIX_PRD §RC-01 (especially the second draft that withdrew the "check then self-call" repair) are implemented: the external self-call is removed, the holder is `address(this)`, and the gate runs before burn.
- **Impact class:** Closure of the original Stage-1 RC-01 and A-R01 vulnerability surface (code-less caller consuming self-held shares). Counterevidence remains D12 (accepted `UNSUPPORTED_USE` for non-atomic contract pretransfer).
- **Fix direction:** No further code or test fix observed as required by this item. The four per-family tests assert the production-proxy invariant; passing them once in an authorized verification session would close the spec for those four families.
- **Confidence:** High in source-level conformance. Medium in full inheritance inventory (some inheritors not re-read line-by-line; named set from FIX_PRD was checked by symbol, broader set by grep `_redeemVaultHeld`).
- **Class:** Successful execution of an elaborated remediation.

### 3.2 RC-02 — Camelot zap-out share maximum enforced before burn (CONFIRMED_EXECUTED)

- **Severity:** Informational (closure evidence only).
- **File and line:** `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol:761-764` (zap-out share comparison), working precedent at `:654-661` (share-to-pool exact-out comparison).
- **Intended behavior (per FIX_PRD §RC-02):** When `amountIn` (the share burn amount) exceeds `maxAmountIn`, revert `MaxAmountExceeded(maxAmountIn, amountIn)` before any `_secureSelfBurn` on both pretransfer flags; LP amount and token output are not the comparison.
- **Observed behavior:** Lines 761-764:
  ```solidity
  // Share maximum, same units as the share-to-pool branch. LP and output are not this check.
  if (amountIn > maxAmountIn) {
      revert MaxAmountExceeded(maxAmountIn, amountIn);
  }
  ```
  This sits after `amountIn` is computed at line 751 (`BetterMath._convertToSharesUp(lpToBurn, …)`) and before `_secureSelfBurn(msg.sender, amountIn, pretransferred)` at line 768. The unit comparison is shares against shares, matching the share-to-pool branch's pattern (`:654-661`). The `MaxAmountExceeded` selector is the same on both branches. The fee-share mint occurs before this comparison, which is permitted per FIX_PRD §Non-goals (a revert rolls the mint back).
- **Broken requirement or invariant:** None observed.
- **Impact class:** Closure of B-01 source defect (caller could be charged more shares than authorized on a zap-out exact-output). The earlier accepted report's severity was Medium and dissent over High is preserved but moot since this is now implemented.
- **Fix direction:** No further source fix observed as required by this item. Test at `CamelotV2ZapOutMaxAmountIn.t.sol` exercises both pretransfer flags and the success boundary.
- **Confidence:** High.
- **Class:** Successful execution of an elaborated remediation.

### 3.3 RC-03 — Legacy Uniswap V3 Standard Exchange deleted (CONFIRMED_EXECUTED with documentation gap)

- **Severity:** Informational for source execution; Low for the documentation gap.
- **Files and lines:**
  - `contracts/protocols/dexes/uniswap/v3/` directory: **does not exist** (only `v2/` and `v4/`).
  - `contracts/protocols/dexes/uniswap/v4/`: still present (FIX_PRD explicitly excluded this from deletion).
  - Scripts updated to FullSpread: `scripts/foundry/anvil_robinhood_testnet/Phase_05_Stage_04_UniswapV3StandardExchangePkg.sol:14-17`; `…/anvil_robinhood_main/Phase_05_Stage_04_UniswapV3StandardExchangePkg.sol` (mirrors); `scripts/foundry/anvil_robinhood_fee_detf/Script_05_DeployUniV3SeOnRichPool.s.sol:15-18,98-129`.
  - `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol:85-91, 244-356, 441` — uses `IUniswapV3FullSpreadStandardExchangeVaultDFPkg`.
- **Intended behavior (per FIX_PRD §RC-03):** Delete the legacy `UniswapV3StandardExchangeCommon.sol` source; have launch/DETF callers use the FullSpread package; FullSpread credits `balanceOf(this) - _reserveOfToken(token)` (no deployed subtraction).
- **Observed behavior:**
  - Directory deletion verified.
  - All four named scripts/DETF caller paths were checked: each now constructs `deployUniswapV3FullSpreadStandardExchangeVaultDFPkg` and references the FullSpread facets/FactoryService.
  - FullSpread pretransfer check is intact: `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:862-884` (`_secureTokenTransfer`) and `:908-916` (`_pretransferCredit`) use `LocalCreditLib.available(token.balanceOf(address(this)), MultiAssetBasicVaultRepo._reserveOfToken(...))` — local-only book, no deployed subtraction.
- **Broken requirement or invariant:** None in source. One stale plan/README.
- **Impact class:** Source closure of the original APEX-2026-001-M-style pretransfer-credit vulnerability for the canonical V3 vault.
- **Documentation gap (Low; DOCUMENTATION_GAP):**
  - `contracts/vaults/standard/exchange/protocols/uniswap/README.md:3` says "The preserved implementations under `contracts/protocols/dexes/uniswap/v3` and `v4` remain unchanged. They are not deprecated by this work and remain vulnerable to delivery accounting…"
  - After RC-03 deletion, only `v4` remains under that path. The "preserved implementations" sentence is half-true. The deployment links at `:7-8` correctly point to the new FullSpread packages under `contracts/vaults/standard/exchange/protocols/uniswap/v3/` and `v4/`, but the prose description now reads as if the legacy tree still exists. This is a stale planning document, not a production defect. Recommended fix direction: tighten the README prose to reflect that only `contracts/protocols/dexes/uniswap/v4/` is preserved, and that the V3 FullSpread package is the supported V3 vault.
- **Fix direction:** Update the README prose to remove the stale "v3 preserved" assertion. Do not rename the README under this item (the FIX_PRD §RC-03 plan did not require it).
- **Confidence:** High in deletion and caller rewrites; medium that no caller was missed (grep returned only docs/implementation-artifacts; production contracts and scripts were checked by hand for `deployUniswapV3StandardExchangeDFPkg` which now returns no matches outside `Scripts_05_DeployUniV3SeOnRichPool.s.sol`, where the symbol is referenced only in a comment).
- **Class:** Successful execution of an elaborated remediation; the documentation gap is a side-effect, not a failed remediation.

### 3.4 RC-04 — V3 FullSpread exact-output fills (CONFIRMED_EXECUTED, with naming caveat)

- **Severity:** Informational for execution; Low for the input-ceiling error-name caveat.
- **File and line:**
  - Quote path: `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:255-285` (`_quoteSwapOut`).
  - Settlement: same file, `:505-537` (`_swapExactOut`).
  - Caller: `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:68-95` (`_executeQuotedSwapOut`) — checks the input ceiling at line 78 with `UniswapV3ExchangeOut_InsufficientInput()`, calls `_swapExactOut(...)` at line 89.
- **Intended behavior (per FIX_PRD §RC-04):** In `_quoteSwapOut`, return `quote.amountIn` only when `quote.fullyFilled` and `quote.amountOut == amountOut`; otherwise revert. In `_swapExactOut`, after `pool.swap`, read the output delta and require it to equal `amountOut`. Leave `_executeQuotedSwapOut` input pull/refund alone. Do not edit hookless, Pons, or Wings. Do not rename the existing input-ceiling error.
- **Observed behavior:**
  - `_quoteSwapOut` at lines 281-283:
    ```solidity
    if (!quote.fullyFilled || quote.amountOut != amountOut) {
        revert UniswapV3Exchange_ExactOutputNotFilled(amountOut, quote.amountOut);
    }
    ```
    Implemented as specified; preview reverts with the distinct short-output error.
  - `_swapExactOut` at lines 528-536:
    ```solidity
    amountIn = zeroForOne ? uint256(amount0Delta) : uint256(amount1Delta);
    if (amountIn > maxAmountIn) {
        revert UniswapV3Exchange_InsufficientOutput();
    }
    // Pool delta is negative when the pool paid the recipient. Do not cast this into amountIn.
    int256 outputDelta = zeroForOne ? amount1Delta : amount0Delta;
    uint256 outputPaid = outputDelta < 0 ? uint256(-outputDelta) : 0;
    if (outputPaid != amountOut) {
        revert UniswapV3Exchange_ExactOutputNotFilled(amountOut, outputPaid);
    }
    ```
    Implemented as specified. Two distinct errors: input-ceiling uses `UniswapV3Exchange_InsufficientOutput`; output-short uses `UniswapV3Exchange_ExactOutputNotFilled(uint256 requested, uint256 delivered)`.
  - Hookless (`UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService.sol:113-141`) implements `_exactOutput` with `SwapMath.computeSwapStep` and checks `result_.amountOut != params_.amount || result_.sqrtPriceAfterX96 == target`, reverting `InvalidRoute` on mismatch. This is the distinct hookless/Pons enforcement that FIX_PRD §C-4 preserved; no edit was made for this item.
  - Wings has no direct pair-swap route (per FIX_PRD §RC-04 Plain-language); not modified.
- **Broken requirement or invariant:** None on the V3 fix.
- **Impact class:** Closure of A-F01 short-output as success. A-F01 historical disclosure becomes a properly named distinguish (input ceiling vs short output).
- **Naming caveat (Low; SPEC_CONFLICT or SPEC_CONFLICT-adjacent, debatable):**
  - The error name `UniswapV3Exchange_InsufficientOutput` at `_swapExactOut` line 529 is used for the input-ceiling revert (when `amountIn > maxAmountIn`). FIX_PRD §Non-goals explicitly says: "Do not rename the existing input-ceiling error in this item." The mismatch between the error name and what it represents is intentional per the elaboration. This is not a failed execution; it is the documented preservation of an old name. Recording as a documented constraint, not a defect.
- **Fix direction:** No further code fix required by this item. Optional future cleanup (separate scope) could rename the input-ceiling error for clarity, but the FIX_PRD forbids it under this item.
- **Confidence:** High.
- **Class:** Successful execution of an elaborated remediation.

### 3.5 RC-05 — Rocket Pool sleeve accumulation (CONFIRMED_EXECUTED, EtherFi untouched)

- **Severity:** Informational.
- **File and line:** `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol:495-510` (`_bestEffortStakeOverageTowardTarget`); callers at `RocketPoolRETHStandardExchangeInTarget.sol:79` and `RocketPoolRETHStandardExchangeOutTarget.sol:72`.
- **Intended behavior (per FIX_PRD §RC-05, corrected elaboration):** Single stake decision: small credits accumulate in the existing liquid sleeve (WETH balance); only when `liquidReserveEth() - targetLiquid` meets `getMinimumDeposit()` and `getMaximumDepositAmount()` is honored, deposit `min(excess, getMaximumDepositAmount())`; nothing is deposited below the minimum; `liquidReserveEth()` stays; the booked-first pass is removed.
- **Observed behavior:**
  - `_bestEffortStakeOverageTowardTarget` (lines 502-510):
    ```solidity
    function _bestEffortStakeOverageTowardTarget() internal {
        uint256 liquid = liquidReserveEth();
        if (liquid == 0) return;
        uint256 target = (totalReserveEth() * targetLiquidReservePercentage()) / ONE_WAD;
        if (liquid <= target) return;
        uint256 excess = liquid - target;
        if (excess < _minimumDeposit()) return;
        _stakeWethToRethSoft(excess);
    }
    ```
    One stake decision. `liquidReserveEth()` (line 56-58) is retained as `IERC20(weth()).balanceOf(address(this))` — the WETH balance, which is the accumulator. `_stakeWethToRethSoft` (lines 446-459) honors capacity (`maxDep`/`minDep`) without per-deposit bookkeeping. The booked-first pass the earlier draft objected to is absent; `liquid` already includes any sub-minimum amounts from prior credits.
- **EtherFi independence:** Grep for `_bestEffortStakeOverageTowardTarget` returns only the RocketPool files. `EtherFiWeETHStandardExchangeCommon.sol` does not contain the helper; `_bestEffortStakeOverageTowardTarget` was not propagated to EtherFi.
- **Broken requirement or invariant:** None observed.
- **Impact class:** Closure of B-02 timing defect (skipped sub-minimum credits could be pooled into a later excess). No demonstrated extraction; sleeve accumulation is the corrected shape.
- **Fix direction:** No further source fix required by this item. The companion test `RocketPoolSleeveExcessStake.t.sol` covers three cases (single below-minimum credit, two-accumulated-credit then stake, capacity-capped accumulation).
- **Confidence:** High.
- **Class:** Successful execution of an elaborated remediation.

### 3.6 RC-06 — DETF leftover preview signal (CONFIRMED_EXECUTED)

- **Severity:** Informational.
- **File and line:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:625-638` (`_retainSubSharePairResidual`), zero-preview helper at `:641-646` (`_pairQuoteIsZero`), call sites at `:528, :558-559, :583-584`.
- **Intended behavior (per FIX_PRD §RC-06):** Use `previewExchangeIn(pair, amount, se) == 0` on both branches as the only signal; do not call `quoteInputForExactShares(state, 1)`; do not add a new catch; the `supportsInterface` catch stays a failed probe; the local reserve is the full locally held balance of that token.
- **Observed behavior:**
  - `_retainSubSharePairResidual` (lines 625-638) now has a single body: probe interface (return false on catch); check `previewExchangeIn(pair, amount, se) != 0` (return false if not zero); if zero, `MultiAssetBasicVaultRepo._updateReserve(IERC20(pair_), IERC20(pair_).balanceOf(address(this)))` and return true.
  - There is no `quoteInputForExactShares` call in this function. There is no `_invariant(params_, row)`/no new catch around the preview.
  - The earlier two-branch shape (supported-quote vs unsupported-quote) was collapsed into a single check; the `supportsInterface` probe remains as a gate that does not book.
  - The companion `_pairQuoteIsZero` (lines 641-646) is a direct zero-quote read used in the residual join ladder; it is consistent with the same rule.
- **Broken requirement or invariant:** None observed. The exclusive OD-08 zero-preview signal (REQ-01) is preserved on the supported-quote branch because the function only books when `previewExchangeIn == 0`. The earlier-stage `supportsInterface` translation catch is preserved as a non-booking probe (D41 exception) and is not the book-and-wait signal.
- **Impact class:** Closure of D-F03 STAGE1_OPEN. DETF residual accounting no longer uses an inverse quote to decide non-depositable.
- **Fix direction:** No further source fix required by this item. Test `UniswapV4DetfLeftoverPreview.t.sol` exercises the three relevant paths (zero-preview, nonzero-preview falling back to single-asset, reverting-preview propagating).
- **Confidence:** High.
- **Class:** Successful execution of an elaborated remediation.

### 3.7 RC-07 — Selector/size script not repaired, per owner ruling (NOT_A_REMEDIATION)

- **Severity:** Informational.
- **File and line:** `scripts/r12_selector_size_compare.py:35-62` (`discover_artifacts`).
- **Intended behavior (per FIX_PRD.md:18 and FIX_PRD.plan.md:7):** Owner 2026-10-07: "`r12_selector_size_compare.py` is a prior audit tool. Do not repair it. EIP-170 still applies at deploy." The script was not edited as a fake fix.
- **Observed behavior:** The script's `discover_artifacts` still globs `*.sol` only in the parent directory of each live baseline row (lines 43-62). Replacement packages under nested directories (hookless, Pons-family, wings) are still not discovered. EIP-170 (`EIP170 = 24576`) still applies.
- **Broken requirement or invariant:** None observed. The closure is by owner ruling, recorded in both `FIX_PRD.md:18` and `FIX_PRD.plan.md:7`. The Stage-1 REQ-08 evidence gap (D-F01/D-F02) is preserved as a separate, not-elaborated continuity item.
- **Impact class:** Documentary closure per owner decision; no production defect.
- **Fix direction:** None required by this round. Future closure of REQ-08 evidence will require a separately authorized verification session or an owner ruling expanding the script's discovery.
- **Confidence:** High.
- **Class:** Not a remediation; explicit owner-recorded skip.

---

## 4. Cross-cutting observations

- **Owner corrections override older draft text.** Where `FIX_PRD.md` and `REMEDIATION_PRD.md` disagree (RC-02 severity, RC-04 caller-confirmation dissent, RC-05 sleeve accumulation rule, RC-06 inverse-vs-zero-preview), the FIX_PRD corrections control. I applied the corrections as the authoritative specification per the PRD/plan precedence rule.
- **No new code defect introduced by the remediations was located on the inspected surfaces.** The repairs target previously documented vulnerabilities or owner-corrections; the implementations match the corrected text.
- **Production-source `address(this).call` for internal-balance redemption is absent.** All 17 grep hits under `contracts/` are in test bases (`contracts/test/bases/TestBase_UniswapV4FullSpreadBlockedYield.sol:131`) and DETF TestBase production-fixture files used to launch Pons via `tryLaunchPonsV1` self-calls. None of these are the SY adapter internal-balance redemption path.
- **`NativeStandardYieldContextRepo` is not a live production source file.** Only planning documents reference it (`uniswap-se-v2-liquidity-leak-fixes.md` / `.plan.md`). The FIX_PRD §RC-01 said the context goes away with the self-call unless a cited family still uses it; the grep found no production source file under that name. The MD files are planning/notes and do not bind behavior.
- **A-F01 naming caveat (Low):** `UniswapV3Exchange_InsufficientOutput` is the input-ceiling revert name and is preserved per FIX_PRD §Non-goals. This is not a failed execution; it is the documented preservation of an old name. The short-output case is now distinctly named. Optional future cleanup is out of scope for this round.
- **Stale README (Low):** `contracts/vaults/standard/exchange/protocols/uniswap/README.md:3` describes a pre-RC-03 state. This is a planning/README staleness, not a code defect. Recording here so the owner can decide whether to amend the prose.
- **All other accepted-report items** (A-F02, A-F03, B-03, B-04, B-05, C-001–C-007, D-F01, D-F02, D-F04, D-X01) were not elaborated into named remediations in `FIX_PRD.md`. They remain as Stage-1 / first-wave notes and are not auto-promoted to defects by this round. None of those inspected today showed a contradiction with a locked current requirement that this round was authorized to fix.

---

## 5. Files examined (no defect found in these files relative to the in-scope items)

- `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol`
- `contracts/vaults/standard/erc4626/ERC4626StandardYieldTarget.sol`
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol` (excerpt)
- `contracts/utils/LocalCreditLib.sol`
- `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardYieldTarget.sol`
- `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol`
- `contracts/protocols/staking/rocket-pool/README.md`
- `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol` (excerpt)
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiQueryTarget.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService.sol` (excerpt)
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutMultiQueryTarget.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookCommon.sol` (line range)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultSYTarget.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol` (full)
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol` (filtered)
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessVaultHeldRedeem.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsVaultHeldRedeem.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/ApexRecurrenceErrorOrder.t.sol`
- `test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2ZapOutMaxAmountIn.t.sol`
- `test/foundry/spec/protocol/staking/rocket-pool/RocketPoolSleeveExcessStake.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/UniswapV4DetfLeftoverPreview.t.sol`
- `scripts/r12_selector_size_compare.py`
- `contracts/vaults/standard/exchange/protocols/uniswap/README.md` (stale prose noted; no source defect)
- `scripts/foundry/anvil_robinhood_testnet/Phase_05_Stage_04_UniswapV3StandardExchangePkg.sol`
- `scripts/foundry/anvil_robinhood_fee_detf/Script_05_DeployUniV3SeOnRichPool.s.sol`

(Empty `contracts/protocols/dexes/uniswap/v3/` confirmed via directory read returning "File not found".)

---

## 6. Session limitations

- No build, test, simulation, fork, RPC, deployment, shell execution, source/config edit, or test authoring was performed. All judgments are source-bound.
- This is an independent first pass. The cross-review wave is a later coordinator step and is not started here.
- No peer reviewer output under `docs/reviews/apex-stage2-remediation-confirmation-2026-10-11/` was read, searched for, or otherwise consulted, per coordinator instruction.
- The `_bridgeInCompactRate` `supportsInterface` translation catch at `_retainSubSharePairResidual` lines 630-634 is described by the FIX_PRD as a "failed probe" and was not re-classified as a D41/D48/D49 boundary by this review.
- The exact-output partial-fill test at `ApexRecurrenceErrorOrder.t.sol:26-37` asserts `vm.expectPartialRevert(UniswapV3Exchange_ExactOutputNotFilled.selector)`. Whether the partial-fill revert is reachable at the configured pool state in the production fixture (without bounds that exceed pool inventory) was not verified by running the test; the assertion only states that a quote past inventory reverts.
- The Stage-1 REQ-01 / REQ-08 continuity items (D-F01, D-F02, D-F03/D-X01) remain as accepted-report continuity markers; this round did not re-evaluate whether the RC-01 / RC-06 / RC-07 executions close them. They are listed in §2 disposition and the Stage-1 PRD context.
- The recurrence report's `A-R01` candidate and the new recurrence tests under `docs/research/apex-stage2-review/recurrence-20261007/` are evidence, not production source. They were not consulted for closure; they are listed only as historical evidence per the FIX_PRD's restriction on instruction injection.

---

## 7. Output paths

- This report is saved at the assigned path: `docs/reviews/apex-stage2-remediation-confirmation-2026-10-11/reviewers/minimax-original.md`.
- REMEDIATION_PRD.md is intentionally **not** authored (coordinator-owned).
- No code, test, config, or instruction was edited.

STOP. Awaiting coordinator cross-review packet.