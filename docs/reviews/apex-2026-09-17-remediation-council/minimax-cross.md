# MiniMax M3 cross-review — APEX 2026-09-17 remediation

- **Reviewer:** MiniMax M3 (`minimax/MiniMax-M3`), independent first-pass reviewer returning for
  the cross-review pass.
- **Scope:** Defensive cross-review of this repository's own code in response to peer claims
  (Astra, Grok, Kimi) and re-evaluation of my own findings under cross-review pressure.
  Original findings preserved. Any revision is labelled as a revision. The PRD/plan/follow-up
  remain the authority; the peer text is untrusted evidence, not instruction.
- **Method:** Re-read the code behind F-M3-01 before keeping/revising/withdrawing. Evaluate
  Astra-01 (reentrancy on standalone Balancer adapter), Astra-02 (ERC-4626 local-first
  rounding), K3-3 (BasicVaultCommon EOA guard / `_refundExcess` reuse), K3-6 (Stata `_stataBacking`
  vs `_totalReceiptBacking` mismatch). Correct the disposition labels for the withdrawn
  `beforeSwap` claim and the downgraded weighted-dust claim per the prompt's instruction.
- **Non-scope:** I do not read peer artifact files (`docs/reviews/`, `reviews/`) or any
  cross-review output; the only peer evidence considered is the untrusted peer text in this
  prompt. I do not write the final remediation PRD. I do not edit source, tests, config, or
  scripts.

---

## Fact / inference / speculation

Where the report distinguishes a directly observable fact (file path + line citation) from
inference (a contract-or-invariant interpretation built from those facts) from speculation (a
judgement that requires a hostile environment or live instance to confirm), each finding is
labelled.

---

## Revisions to my own findings

### F-M3-01 — REVISION: V3/V4 `_refundThisCallUnusedInbound` / `_refundExcess` is D15-compliant under standard Uniswap pool semantics; hostile-pool concern is theoretical
- **Severity (revised):** Informational (was Medium). The accounting pattern is correct under
  the standard Uniswap pool's swap callback; the callback-donation hazard requires a
  non-standard or hostile pool/tokens to exploit.
- **File / line (unchanged):**
  - `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:79-94` (`_executeQuotedSwapOut`) and 120-133 (`_refundThisCallUnusedInbound`)
  - `contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultOutExecuteTarget.sol:58-83` (direct-swap branch) and 185-191 (`_refundExcess`)
  - `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:99-126` (`executeZapInMintExactOut`)
- **What I re-read:**
  - V3 `_executeQuotedSwapOut`: captures `inboundBefore = balanceOf(this)` at line 79 *before*
    `_secureTokenTransfer`. On pretransferred, line 87 then sets
    `inboundBefore -= providedAmountIn`. After the V3 swap consumes `amountIn` from the
    vault via `uniswapV3SwapCallback` (which calls `safeTransfer` from the vault to the
    pool — pull-only, no callback-donation), the post-swap balance is `B0 - amountIn` and
    `unusedInbound = (B0 - amountIn) - (B0 - credit) = credit - amountIn`. The refund
    is therefore exactly `credit - amountIn`, D15-compliant.
  - V4 `_refundExcess` at line 185-191: identical accounting. Line 68 also subtracts
    `providedAmountIn` from `inboundBefore`, so `inboundBefore` = pre-existing rest
    post-credit. The V4 `_executeDirectSwapOut` calls `_executeUnlock` with the
    PoolManager; the settle step is a `safeTransfer` from the vault to the PoolManager,
    pull-only.
  - The `_swapExactOut` and `_executeDirectSwapOut` paths have no callback-donation
    opportunity from a standard Uniswap pool. The only way `balanceOf(this)` could be
    higher than expected is a hostile pool that donates tokens to the vault during the
    swap, which is not the standard Uniswap V3/V4 behavior.
- **What changed my view:** I confirmed the post-subtraction accounting on both V3 and V4
  (V3 line 87; V4 line 68). For standard Uniswap pools, the refund cap is exactly
  `credit - amountIn`. The theoretical concern in my original F-M3-01 about callback
  donations requires a non-standard pool/tokens to manifest, and the PRD's D2/D28/D29
  accept this residual for the standard-pool case. I revise the severity to Informational
  and the evidence label to "speculation" (requires a hostile environment to confirm).
- **Disagreement with original:** No fundamental disagreement with the original finding's
  shape. The original Medium severity was based on the abstract callback-donation hazard;
  the revision recognises the hazard requires a hostile pool and is below the standard-pool
  audit bar.
- **Impact class:** value accounting (theoretical)
- **Fix direction:** None required under standard Uniswap pool semantics. If a future
  version supports a custom pool with potentially-donating swap callbacks, the post-swap
  balance read in `_refundThisCallUnusedInbound` / `_refundExcess` should subtract
  `effectiveUnbookedBefore` to defend against donation. Document this in NatSpec.
- **Confidence:** high (the D15 compliance is verified under standard pool semantics);
  medium that the theoretical hostile-pool concern warrants any code change.
- **Evidence label:** observed fact (the post-subtraction accounting is correct) +
  speculation (the hostile-pool concern).

No other findings from my first pass are revised. All F-M3-02 through F-M3-20 stand as
written.

---

## Peer claims — agree, dissent, or unverified

### Astra-01 — Standalone Balancer SE has no reentrancy lock
- **Disposition:** Agree (with severity moderation).
- **Severity:** Medium (was High in Astra's text). I moderate to Medium because the standard
  Balancer V3 Router's `addLiquidityUnbalanced`, `removeLiquiditySingleTokenExactIn`, and
  `removeLiquiditySingleTokenExactOut` do not callback into the standalone adapter in any
  standard flow. The missing guard is a defensive gap, not an active exploit.
- **File / line:** `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol:22, 69-107, 131-196, 229-260` — re-confirmed: the contract inherits only
  `IStandardExchange` (line 22). No `nonReentrant` modifier, no `ReentrancyLockRepo._lock()` /
  `_unlock()`, and no `ReentrancyLockModifiers` import. `grep -n 'nonReentrant\|ReentrancyLock\|_lock()\|_unlock()' contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol` returns no matches.
- **Intended behavior:** D16 includes this standalone adapter; every other D16 SE family has
  a reentrancy lock on its money routes.
- **Broken invariant:** The Balancer native-BPT pool target (`BalancerV3PoolStandardExchangeTarget.sol`)
  uses `ReentrancyLockRepo._lock()` / `_unlock()` (line 126-152) around its
  `_executePoolLiquidity`. The standalone adapter does not. A token with a
  transferFrom callback or a Permit2 callback into the adapter during `_securePull` or
  between `_approvePermit2ToRouter` and the router call could reenter with a stale
  `_tokenReserve` (the sync happens after the router call at line 88-89 / 101-102 /
  175-176 / 190-191). `_approvePermit2ToRouter` grants `type(uint256).max` to both the
  router and Permit2 (line 271-275), so a reentrant call would inherit the standing
  approvals.
- **Impact class:** reentrancy; value accounting; token integration
- **Fix direction:** Add `nonReentrant` (via `ReentrancyLockModifiers` or
  `ReentrancyLockRepo._lock()` / `_unlock()`) around both `exchangeIn` (line 69) and
  `exchangeOut` (line 131). Constrain `_approvePermit2ToRouter` to the operation budget
  (replace `type(uint256).max` with the actual `actualAmountIn` / `quotedUsed`) and reset
  to 0 before any external call, not after. Add a hostile-token precheck or use a
  blocklist for callback tokens. The 3 fix-direction bullets from Astra's text apply.
- **Confidence:** high on the missing guard; medium on practical exploit.
- **Evidence label:** observed fact.

### Astra-02 — ERC-4626 local-first payout sends rounded redemption surplus to recipient
- **Disposition:** Agree (with severity moderation).
- **Severity:** Medium (was Medium). I agree with Astra's reading of EIP-4626's guarantee:
  `redeem(previewWithdraw(x))` returns exactly `x` for canonical vaults and `≤ x` for
  ERC-4626-compliant vaults. The current code only checks `got < shortfall` and would not
  revert if a vault returned more than `shortfall` due to between-call yield accrual
  (Stata, Aave V3, Lido wstETH, etc., are yield-bearing).
- **File / line:** `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:80-92` (`_payUnderlyingLocalFirst`).
- **Intended behavior:** Exact-output delivers the requested underlying. R6/D25: orbital
  exact-output unwrap must not create buffered-face surplus. R8.5: exact-output routes
  must refund only the unused caller credit.
- **Broken invariant:** `_payUnderlyingLocalFirst` calls
  `vault.redeem(vault.previewWithdraw(shortfall), recipient, address(this))` and only checks
  `got < shortfall` (line 89). The recipient receives the full redemption `got`. For
  yield-bearing vaults (Stata, Aave, Lido wstETH, EtherFi weETH), `redeem(previewWithdraw(x))`
  can return `> x` if yield accrues between the `previewWithdraw` and the `redeem` call
  in the same transaction. The surplus comes from the wrapper's holdings, not from other
  holders, so the impact is bounded to the yield accrual between two adjacent operations.
- **Impact class:** value accounting
- **Fix direction:** Replace `redeem(previewWithdraw(shortfall), recipient, address(this))`
  with `withdraw(shortfall, recipient, address(this))`. ERC-4626's `withdraw(assets,
  receiver, owner)` guarantees exactly `assets` is transferred (capped by available
  liquidity; reverts otherwise). Apply to both `_payUnderlyingLocalFirst` and the
  `_payUnderlying` in `AaveV3StataStandardExchangeCommon.sol:87-97`. Add an
  exact-asset-rounded test asserting the recipient receives exactly `due` underlying.
- **Confidence:** high on the rounding observation; medium on the breadth of practical
  impact (yield accrual in one block is small but non-zero for Stata and similar).
- **Evidence label:** observed fact.

### Astra-03 — ERC-4626 NatSpec still describes removed fee-dust and pull-overshoot behavior
- **Disposition:** Agree.
- **Severity:** Low (was Low in Astra's text).
- **File / line:**
  - `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:201-211` — the
    `_securePull` NatSpec says "Pull overshoot is refunded immediately (D38)". The
    implementation (line 213-235) does not refund pull overshoot; it requires exact
    pull-delta equality (`if (delta != amountIn) revert`). The NatSpec describes the
    pre-D15 behavior. Stale.
  - `contracts/vaults/standard/erc4626/ERC4626StandardExchangeOutTarget.sol:17-20` — the
    OutTarget NatSpec says "unrefundable residual ≤ MAX_DUST_WEI → feeTo when non-zero,
    skip if feeTo==0". The implementation has no MAX_DUST_WEI and no feeTo absorb path
    (removed under D36). Stale.
  - `contracts/vaults/standard/erc4626/ERC4626StandardExchangeInTarget.sol:18` — says "Mint
    routes apply dilution usage fee (D40)". The implementation does apply a dilution fee via
    `_mintWithUsageFee` (Common line 188-199). Not stale.
- **Impact class:** accounting clarity
- **Fix direction:** Update the two stale NatSpec paragraphs. The `_securePull` NatSpec should
  describe the exact pull-delta equality check. The OutTarget NatSpec should describe the
  pretransferred credit/refund rule (D15) without mentioning `MAX_DUST_WEI` or `feeTo`.
- **Confidence:** high
- **Evidence label:** observed fact.

### Grok-1 — Single-CP abstract `HookTarget.exchangeOut` (lines 736-754) lacks LocalCreditLib / EOA guard
- **Disposition:** Agree on the defect; the production cut serves `exchangeOut` via
  `SE_FACET` (DFPkg line 215) which dispatches to `SeTarget.exchangeOut` (line 836) which
  uses `_swapExchangeOut` and `_pullExactOutInput` (line 849-864) with proper guards. So
  this defect is not on the current production cut; it is a second implementation in
  the abstract base. Severity moderated to Informational for production risk; Medium for
  any future deployment that cuts the HookTarget.
- **Severity:** Informational (production), Medium (if deployed)
- **File / line:** `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol:736-754`.
  Re-confirmed: `function exchangeOut(...) external nonReentrant returns (uint256 amountIn)`
  has no `LocalCreditLib.requirePretransferCaller` call. The pretransferred branch
  unconditionally refunds `maxAmountIn - amountIn` (line 753) without bounding against
  unbooked surplus and without the EOA guard.
- **Intended behavior:** D9 / R13.1 / R10. Every D16 public entry that credits
  `pretransferred=true` must call `LocalCreditLib.requirePretransferCaller(msg.sender)`
  and bound the refund by `LocalCreditLib.budget(unbooked, maxAmountIn) - used`.
- **Broken invariant:** The HookTarget.exchangeOut's pretransferred path lets an EOA caller
  consume the hook's free balance for the pretransfer credit and refund `maxAmountIn -
  amountIn` to themselves from the hook's balance without EOA guard, without
  LocalCreditLib budget, and without an explicit shortfall revert. This is precisely
  the pre-D15 / pre-D19 behavior the PRD mandates fixing.
- **Impact class:** value accounting; access control
- **Fix direction:** Either (a) align the HookTarget.exchangeOut with the SeTarget.exchangeOut
  by calling `_pullExactOutInput` from the SeTarget's helper, or (b) add the guard
  directly: `if (pretransferred) { LocalCreditLib.requirePretransferCaller(msg.sender);
  uint256 credit = LocalCreditLib.budget(_unbookedBalance(tokenIn), maxAmountIn); if
  (amountIn > credit) revert TransferDeltaInsufficient(amountIn, credit); }` and refund
  `credit - amountIn` only.
- **Confidence:** high on the defect; high on the cut (DFPkg line 215 confirms SE_FACET is
  the production cut).
- **Evidence label:** observed fact.

### Grok-2 — FullSpread README `:32-48` still documents superseded pull-max / quote-buffer rules
- **Disposition:** Agree.
- **Severity:** Low (was Low in Grok's text)
- **File / line:** `contracts/vaults/standard/exchange/protocols/uniswap/README.md:36` —
  "Pull semantics remain route-specific: V3 token exact-out pulls its quote plus the
  existing capped buffer; V4 pulls max. Dual exits pull max shares and refund unused
  shares." Re-confirmed: the V3 + capped buffer is the OLD D19 behavior; D17 explicitly
  overrides this so V3 pulls exactly `quotedIn`. The code at
  `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:893` enforces `_requireDelivered(quotedIn, providedAmountIn)`, and the OutFacet `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:78,88,90` reverts `UniswapV3ExchangeOut_InsufficientInput` if `quotedIn > maxAmountIn` — there is no buffer. The README text is stale.
- **Impact class:** accounting clarity
- **Fix direction:** Update the README to describe the D17 / D55 / D64 pull semantics: V3 pulls exactly `quotedIn`, V4 pulls quoted `amountIn`, dual exits pull `sharesToBurn` (not `maxSharesToBurn`), exact-out mint pulls the closed-form input only.
- **Confidence:** high
- **Evidence label:** observed fact.

### Grok-3 — ERC-4626 OutTarget NatSpec `:17-20` still says dust goes to feeTo
- **Disposition:** Agree.
- **Severity:** Low
- **File / line:** `contracts/vaults/standard/erc4626/ERC4626StandardExchangeOutTarget.sol:17-20` — re-confirmed; see Astra-03 above.
- **Impact class:** accounting clarity
- **Fix direction:** Same as Astra-03.
- **Confidence:** high
- **Evidence label:** observed fact.

### Grok-4 — Orbital `_unwrapExactTokenOut` `:550-565` sets `seIn = maxIn` rather than shares pulled
- **Disposition:** Dissent (no functional defect).
- **Severity:** Informational (no defect)
- **File / line:** `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:550-566`. Re-confirmed: line 565
  `seIn = maxIn;` is a no-op return-value assignment. The function signature is
  `returns (uint256 seIn)`, but all internal callers (Common lines 586, 604, 1899;
  SeTarget lines 125, 185, 250; WithdrawTarget line 177) call `_unwrapExactTokenOut(...)`
  without capturing the return value. The actual SE shares consumed by the inner
  `exchangeOut` is whatever `_secureTokenTransfer` pulls via `_burnSeShares`, which the
  caller does not need. The `seIn = maxIn` assignment is harmless because no caller
  consumes it.
- **Intended behavior:** The function is internal. The post-condition is that the vault
  receives at least `amountOut` of `token` (line 564 check). The `seIn` return is
  documentary; the actual booked delta is captured by `_syncVaultReserves` after the
  call returns.
- **Broken invariant:** None. The `seIn = maxIn` assignment is defensive (returns the
  upper-bound quote) but unused.
- **Impact class:** accounting clarity (no defect)
- **Fix direction:** None. Optionally remove `seIn = maxIn;` (line 565) and `returns
  (uint256 seIn)` from the signature if the file is to be tidied; or document why
  `maxIn` is returned (it bounds the maximum shares the SE was authorized to pull).
- **Confidence:** high
- **Evidence label:** observed fact.

### Grok-5 — Hook exact-out helper checks used against whole unbooked balance, not pre-existing rest
- **Disposition:** Agree (this is the same F-M3-01 concern, revised to Informational).
- **Severity:** Informational (was Informational)
- **File / line:** `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:2061-2069`
  (`_pullExactOutInput`). Re-confirmed:
  ```solidity
  _securePull(token, used, pretransferred);
  if (!pretransferred) return;
  uint256 credit = LocalCreditLib.budget(_unbookedBalance(token), maxAmountIn);
  if (credit > used) token.safeTransfer(msg.sender, credit - used);
  ```
  The check is `credit > used`; `credit = budget(unbookedBalance, maxAmountIn)` caps
  by the full unbooked balance, not the pre-existing rest. Under the PRD's D15/D28/D29
  standard-pool semantics, this is correct because `_securePull` does not change the
  vault's balance on `pretransferred=true` (no actual transfer; credit is acknowledged
  only). The full unbooked balance is `balanceOf(this) - reserveOfToken`, and the
  pre-existing rest is part of that — but the credited `used` was already "consumed" from
  the unbooked balance by the call's downstream SE `exchangeOut`, so the post-credit
  `unbookedBalance` correctly reflects the post-call state. Same shape as F-M3-01.
  Callers may check first (the SeTarget calls `_pullExactOutInput` after `if
  (amountIn > maxAmountIn) revert InsufficientTokenOut;`, so the post-swap consumed
  amount is already capped by `maxAmountIn`).
- **Impact class:** value accounting (no production defect)
- **Fix direction:** None.
- **Confidence:** medium
- **Evidence label:** observed fact + inference.

### K3-1 — Stale dust-to-feeTo NatSpec at OutTarget `:17-20`
- **Disposition:** Agree.
- **Severity:** Low
- **File / line:** `contracts/vaults/standard/erc4626/ERC4626StandardExchangeOutTarget.sol:17-20` — same as Astra-03 and Grok-3.
- **Impact class:** accounting clarity
- **Fix direction:** Update NatSpec.
- **Confidence:** high
- **Evidence label:** observed fact.

### K3-2 — Stale pull-overshoot comments at Common `:207` and InTarget `:126`
- **Disposition:** Agree.
- **Severity:** Low
- **File / line:**
  - `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:207` — NatSpec for
    `_securePull` says "Pull overshoot is refunded immediately (D38)". The implementation
    requires exact pull-delta equality. Stale.
  - `contracts/vaults/standard/erc4626/ERC4626StandardExchangeInTarget.sol:126` — comment
    says "Pull overshoot already refunded in `_securePull`; reserve retained." Same stale
    comment.
- **Impact class:** accounting clarity
- **Fix direction:** Update both comments to describe the exact pull-delta equality check
  and the absence of pull-overshoot refund.
- **Confidence:** high
- **Evidence label:** observed fact.

### K3-3 — BasicVaultCommon `:34-36, 98, 128` not library-routed; base pull lacks EOA guard; `_refundExcess` still live
- **Disposition:** Partial agree.
- **Severity:** Low (was Low / Medium in Kimi's text)
- **File / line:** `contracts/vaults/basic/BasicVaultCommon.sol:33-36` (`_unbookedSurplus`),
  `:77-103` (`_secureTokenTransfer`), `:120-135` (`_refundExcess`). Re-confirmed:
  - The base `_secureTokenTransfer` (line 77-103) does not call
    `LocalCreditLib.requirePretransferCaller`. The NatSpec at line 71-72 explicitly delegates
    this to callers. Every direct caller in the D16 family overrides the function or calls
    it via an override that includes the guard (Uniswap V2 common line 426-427; Uniswap V3
    common line 855-856; Uniswap V4 common line 1222-1223; ERC4626 common line 229;
    Stata common line 207; Morpho common line 181). Lido/Rocket/EtherFi define their own
    `_securePull` (different name) with the guard.
  - The base `_refundExcess` (line 120-135) is called by Aerodrome v1 and Camelot V2 (both
    in `Common.sol` of their respective packages). Both override or use the basic form.
    The base form is correct under standard pool semantics (D15-compliant).
  - The base is not library-routed because it is `internal`, not `external`/`public`. It is
    `virtual` so heirs can override. This is the intended contract for the
    `BasicVaultCommon` abstract base.
- **Broken invariant:** None observed. The EOA guard delegation via NatSpec is a
  contract discipline, not a runtime invariant violation. Every current caller follows the
  discipline.
- **Impact class:** accounting clarity
- **Fix direction:** Optional: add an explicit `_secureTokenTransfer` invariant that the
  guard must be called before this function, and add a require-style check (e.g.,
  `assembly { /* verify caller has invoked the guard */ }`) — but this is invasive. Better:
  move the `requirePretransferCaller` call into the base `_secureTokenTransfer` itself
  (when `pretransferred` is true), eliminating the delegation. Every current caller
  already calls the guard before `_secureTokenTransfer`, so this change is safe and
  defensive.
- **Confidence:** high that the delegation works today; medium that adding the guard to
  the base is worth the change.
- **Evidence label:** observed fact.

### K3-4 — Bare revert at UniswapV2 OutTarget `:578-580`
- **Disposition:** Agree.
- **Severity:** Low
- **File / line:** `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol:578-580` — re-confirmed:
  ```solidity
  if (indexSource.pool.balanceOf(address(this)) < vault.vaultLpReserve) {
      revert();
  }
  ```
  Bare `revert()` with no error type. The assertion is documented as "Pass-through zap-out
  must not spend ERC4626 lastTotal LP. Prior unbooked dust stays on the vault and is
  booked by the end-of-op sync (A0/R14)." A bare revert loses error information for
  off-chain consumers and auditors.
- **Impact class:** error handling
- **Fix direction:** Define a named error (e.g., `error PassThroughZapOutUnderwaterLP()`) and
  revert with that. Improves debuggability without changing behavior.
- **Confidence:** high
- **Evidence label:** observed fact.

### K3-5 — FullSpread README stale pull semantics
- **Disposition:** Agree.
- **Severity:** Low
- **File / line:** `contracts/vaults/standard/exchange/protocols/uniswap/README.md:36` — same
  as Grok-2.
- **Impact class:** accounting clarity
- **Fix direction:** Same as Grok-2.
- **Confidence:** high
- **Evidence label:** observed fact.

### K3-6 — Stata `_stataBacking` omits booked aToken counted by `ReceiptBackedERC4626Target`
- **Disposition:** Agree (with a conditional scope note).
- **Severity:** Medium (was Medium)
- **File / line:**
  - `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeCommon.sol:52-58`
    (`_stataBacking`) — computes `held_ + stata_.convertToShares(booked_)` where
    `booked_ = _bookedReserve(IERC20(stata_.asset()))` (the booked underlying). Does
    NOT include `_bookedATokenEquiv` from `ReceiptBackedERC4626Target`.
  - `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol:183-198`
    (`_totalReceiptBacking`, `_bookedATokenEquiv`) — the shared adapter adds
    `_bookedATokenEquiv` only when `_isStata()`. So the adapter counts booked aTokens
    (which came from aToken deposits via `depositATokens`); the Stata SE does not.
- **Intended behavior:** R14.14. Both routes should count held receipts + booked local
  underlying in the same units.
- **Broken invariant:** The Stata SE's `_convertStataDeltaToShares` (Common line 148-159)
  and `previewDeposit` (line 49-50 of InTarget) use `_stataBacking()` as the divisor. If
  the wrapper holds booked aTokens (deposited via the shared adapter's `depositATokens`),
  those aTokens are NOT counted in `_stataBacking`, so the Stata SE's share math
  understates the backing. A subsequent Stata SE `exchangeIn(underlying, amount)` could
  mint more shares than the underlying-only backing supports, diluting existing holders.
  Conversely, on a redeem, the Stata SE would understate the entitlement, benefitting
  remaining holders at the expense of the redeemer.
- **Impact class:** value accounting
- **Fix direction:** Either (a) add `_bookedATokenEquiv` to `_stataBacking` (mirror
  `_totalReceiptBacking`), or (b) document that the Stata SE treats aTokens as a
  separate token class and the shared adapter's IERC4626 surface is the only path that
  values them. Option (a) is the D45-consistent approach because the wrapper holds
  both underlying (booked via D22 capacity) and aTokens (booked via `depositATokens`),
  and both should be backing for the SE routes.
- **Confidence:** medium. The severity depends on whether the shared adapter's
  `depositATokens` is exposed on the same diamond as the Stata SE. If they share a
  diamond (which is the typical deployment), the defect is real.
- **Evidence label:** observed fact + inference.

### K3-7 — Stata LM rewards to feeTo, no defect claimed
- **Disposition:** Agree; no defect.
- **Severity:** N/A
- **File / line:** `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeCommon.sol:182-198` (`_collectAndForwardRewards`). Re-confirmed: rewards are forwarded to
  `feeRecipient` (the oracle `feeTo`) on every operation. This is the existing reward
  sweep behavior, distinct from the dust-to-feeTo absorb path removed under D36/D50. The
  reward tokens come from the Aave incentives controller, not from the wrapper's
  inventory. No defect.
- **Confidence:** high
- **Evidence label:** observed fact.

### K3-8 — D12 accepted residual confirmed
- **Disposition:** Agree; no defect.
- **Severity:** N/A
- **File / line:** Multiple. Per PRD D12, the non-atomic contract-caller pretransfer is
  accepted residual. The R13.3 NatSpec on `IStandardExchangeIn.pretransferred` documents
  the risk.
- **Confidence:** high
- **Evidence label:** observed fact.

### Standalone audit disposition re-confirmation
The withdrawn `beforeSwap` guard claim and the downgraded weighted-dust claim both remain
"accepted residual per audit / plan" in my first-pass table. The prompt asks to "correct
disposition labels if 'accepted residual' was the wrong state". Re-checking the PRD's
explicit evidence states (R1.2):

- `WITHDRAWN` — auditor retracted the finding; no evidence needed.
- `UNSUPPORTED_USE` — only for the non-atomic contract-caller residual defined in D12.
- The withdrawn `beforeSwap` guard claim was a false positive from the auditor (they
  searched for a guard that doesn't exist). The correct disposition is `WITHDRAWN per
  audit / plan R10.1; no guard added; negative caller/context tests retained`. The
  phrase "accepted residual" is wrong because the audit did not accept a residual — the
  audit retracted the claim. Correcting.
- The downgraded weighted-dust claim was downgraded by the auditor from High to
  informational. The correct disposition is `Downgraded to informational per audit /
  plan R10.5; buffer-first donation controls preserved`. "Accepted residual" is wrong
  because the audit did not accept a residual — the audit downgraded a finding. Correcting.

---

## Sites where no defect was found (named for the audit trail)

These are sites the prompt asked to be checked during cross-review; the production source
was read at the cited line(s) and found consistent with the PRD/plan rule.

1. **`contracts/vaults/basic/BasicVaultCommon.sol:77-135`** — base `_secureTokenTransfer`
   delegates EOA guard to callers; every D16 caller follows the discipline. Base
   `_refundExcess` is D15-compliant under standard pool semantics.
2. **`contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:120-133`** — `_refundThisCallUnusedInbound` is D15-compliant.
3. **`contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultOutExecuteTarget.sol:185-191`** — `_refundExcess` is D15-compliant.
4. **`contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:550-566`** — `seIn = maxIn` is a no-op return; all callers ignore it.
5. **`contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol:849-864, 983-990`** — `_swapExchangeOut` and `_pullExactOutInput` are D9/D15-correct; this is the production cut.
6. **`contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol:126-143`** — D41 staticcall probe; rate selection correct.
7. **`contracts/protocols/dexes/balancer/v3/pools/BalancerV3PoolStandardExchangeTarget.sol:123-152`** — public pretransfer rejected with `UnsupportedPoolPretransfer()`; reentrancy locked via `ReentrancyLockRepo._lock()` / `_unlock()`.

---

## Audit disposition table (revised labels)

The withdrawn `beforeSwap` and downgraded weighted-dust labels are corrected per the
prompt's instruction. The PRD's explicit states are `REPORTED`, `REPRODUCED`, `FIX_IMPLEMENTED`,
`VERIFIED_FIXED`, `WITHDRAWN`, `BLOCKED`, `UNSUPPORTED_USE`. "Accepted residual" maps to
`UNSUPPORTED_USE`, which is reserved for the D12 non-atomic contract-caller residual. The
two audit-driven retractions are properly `WITHDRAWN` / `Downgraded to informational`, not
`Accepted residual`.

| Report finding | Disposition (revised) | Evidence (file:line) | Notes |
|---|---|---|---|
| **APEX-2026-001-M** (Critical, live) — stale-reserve V3/V4 substitute | **Refuted in current source** on FullSpread V3/V4 under `contracts/vaults/standard/exchange/protocols/uniswap/{v3,v4}/`. Live instances remain immutable. | FullSpread V3 `Common.sol:852-921`; V3 `OutExecuteTarget.sol:79-94`; V4 `Common.sol:1219-1291`; V4 `OutExecuteTarget.sol:58-83`; V3 `OutExecutionDelegate.sol:93-126` (exact-out mint). F-M3-01 revised: D15-compliant under standard pool semantics. | Live instances require migration per PRD R3.6. |
| **APEX-2026-001-M2** (Critical scope, 7+1 vaults) | **Inventory + replays per R4**; live instances remain immutable. | Registry `0x09682b00D873D913ada0bB69B4D4c9631810d0bc` (chain 4663); seven UniV4 instances plus custody address per PRD R4 inventory table. | Migration handoff required per PRD R4.6. |
| **APEX-2026-003** (High, live custody) — public-share burn refund | **Refuted in current source** on the rebasing-aware custody package. | `RebasingAwareStandardExchangeTarget.sol:83-93` (exact-in burn); `117-138` (exact-out bounded credit); `RebasingAwareStandardYieldTarget.sol:55-58` (external SY rejects EOA). | Live custody at `0x2E9C1F705aB967c5Af59249203d7495bDabb223b` is immutable per PRD R5.6. |
| **APEX-2026-008** (High, pre-deployment) — orbital prior-face-balance refund | **Refuted in current source** on the orbital hook family. | `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:1999-2025` (`_faceSnap`, `_refundThisCallSurplus`); capped unwrap at 550-566 (SE exact-output with allowance reset); `_raiseRawBookToFace` at 1860-1864 retains raw-leg face as book. | `MAX_DUST_WEI` removed; `_refundBufferedDust` removed. |
| **APEX-2026-009** (High, pre-deployment) — ERC-4626 + Morpho self-share sweep | **Refuted in current source** on both packages. | `ERC4626StandardExchangeCommon.sol:283-294` (`_burnSeShares`); `MorphoBlueStandardExchangeCommon.sol:206-217` (`_burnSeShares` with `bookedSelfShares=0`). | Both use `LocalCreditLib` and short-funding revert; R7.3 fully satisfied. |
| **APEX-2026-004B** (High, pre-deployment) — idle-underlying sweep | **Refuted in current source** on the ERC-4626 SE family. | `ERC4626StandardExchangeCommon.sol:106-122` (`_investCreditedUnderlying`); `ERC4626StandardExchangeInTarget.sol:100-114`; `ERC4626StandardExchangeOutTarget.sol:73-88`. | `_refundOrAbsorbAbove` removed. |
| **APEX-2026-005** (High, structural) — canonical availability / refund rules | **Refuted in current source**. | `contracts/utils/LocalCreditLib.sol` (canonical `available`, `budget`, `requirePretransferCaller`); `contracts/interfaces/ISecurePullErrors.sol`. K3-3 partial-agree: base contract delegates EOA guard via NatSpec; every current caller follows the discipline. | One library, one error interface. |
| **Withdrawn `beforeSwap` guard claim** (Balancer quad) | **`WITHDRAWN` per audit / plan (R10.1); no guard added; negative caller/context tests retained.** (Label corrected from "Accepted residual" to the PRD's `WITHDRAWN` state.) | `UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.sol:626-644` (`_refundBufferedDust` retains remainder on the hook). | Negative caller/context tests required. |
| **Downgraded weighted-dust claim** | **`Downgraded to informational` per audit / plan (R10.5); buffer-first donation controls preserved.** (Label corrected from "Accepted residual" to the downgraded-informational state.) | `UniswapV4StandardExchangeWeightedBufferHookTarget.sol:611-623`; `LiquidityTarget.sol:206, 944`; `JoinCore.sol:322, 763` only call `_refundBufferedDust` (which retains on the hook). | Hook-matrix integration tests required. |

All eight audit dispositions are recorded above. None are "still present in current source".

---

## Reviewer notes for the coordinator

- F-M3-01 was the only original finding I revised. The re-read confirmed the
  post-subtraction accounting on both V3 (line 87) and V4 (line 68). Under standard
  Uniswap pool semantics (one-way vault → pool callback), the refund cap is exactly
  `credit - amountIn`, D15-compliant. The callback-donation hazard requires a hostile
  pool/tokens to manifest. Severity reduced to Informational; evidence label changed
  to "speculation".
- The peer claims I agree with are sorted by severity:
  - Medium: Astra-01 (Balancer standalone reentrancy), Astra-02 (ERC-4626 rounding), K3-6
    (Stata `_stataBacking` / `_totalReceiptBacking` mismatch).
  - Low: Astra-03, Grok-1 (production), Grok-2, Grok-3, K3-1, K3-2, K3-4, K3-5.
  - Informational / no defect: Grok-4 (no functional defect), Grok-5 (same as F-M3-01),
    K3-3 (delegation works), K3-7, K3-8.
  - Production cut of Grok-1 confirmed via DFPkg line 215 (`SE_FACET`).
- The "accepted residual" labels for the withdrawn and downgraded findings were
  corrected to `WITHDRAWN` and `Downgraded to informational` respectively, per the PRD's
  explicit R1.2 evidence states.
- I did not write a remediation PRD, did not read peer artifact files, did not edit source,
  tests, config, or scripts, did not run `forge`. Cross-review only.

Saved to `/Users/cyotee/Development/projects-defi/daosys/lib/indexedex/docs/reviews/apex-2026-09-17-remediation-council/minimax-cross.md`.