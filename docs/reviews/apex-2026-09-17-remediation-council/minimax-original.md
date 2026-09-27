# MiniMax M3 independent first-pass — APEX 2026-09-17 remediation

- **Reviewer:** MiniMax M3 (`minimax/MiniMax-M3`), independent pass.
- **Scope:** Current working-tree IndexedEx production source implementing the APEX 2026-09-17
  remediation, against the locked PRD, plan, and follow-up record. Auditor's findings are checked
  against current code only — `out/` runtime artefacts and live on-chain state are not in scope.
- **Method:** Static reading of every required file plus the immediately listed must-touch trees
  (FullSpread V3/V4 commons, execution delegates and out targets; orbital + 6 other hook
  families; ERC-4626/Stata targets and out targets; Morpho Blue SE; constant-product SE
  families; staking SE families; Aave Loop; Balancer native-BPT and standalone adapter;
  rate providers; LocalCreditLib; BasicVaultCommon). No `forge` execution, no `forge
  artifacts.py` rebuilds, no fork RPC probes. The plan's recorded hermetic suite (34,909
  tests, 0 failures across 3,053 suites and 33 stateful campaigns at 256×64) and the
  follow-up's independent completion note are treated as claims; this review checks only
  the source code currently in the tree.

---

## Fact / inference / speculation

Where the report distinguishes a directly observable fact (file path + line citation) from
inference (a contract-or-invariant interpretation built from those facts) from speculation
(a judgement that requires a test, fork or live instance to confirm), each finding is labelled.
A "no defect found" site citation is valid only when the listed file and line were read
end-to-end; partial reads are not.

---

## Findings

### F-M3-01 — FullSpread V3/V4 token exact-output still pulls the caller's pre-existing surplus via callback-donated residual
- **Severity:** Medium
- **File / line:**
  - `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:79-94` (`_executeQuotedSwapOut`)
  - `contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultOutExecuteTarget.sol:58-83` (`exchangeOut` direct-swap branch)
  - `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:99-126` (`executeZapInMintExactOut`)
- **Intended behavior:** D15 / R3.5. Pretransferred exact-out credits `min(unbooked, maxAmountIn)`
  and refunds only `credit - used`; never pays booked `R` or callback-donated residual that
  was not the current caller's `maxAmountIn`.
- **Broken requirement / invariant:** `_refundThisCallUnusedInbound` and `_refundExcess`
  compute `unusedInbound = balanceOf(this) - inboundBefore` (or its equivalent) and refund
  `min(providedAmount - used, unusedInbound)` directly to `msg.sender`. The PRD's R3.5
  requirement is "exact-out funding against actual used input and refund capped at
  `credit - used` on pretransferred exact-out only" (D15). The existing helper
  honours `credit` for pretransferred paths, but a callback that donates extra `tokenIn`
  between `inboundBefore` and the post-swap `balanceOf(this)` enlarges `unusedInbound`,
  so a pretransferred caller can receive a refund greater than `credit - used` when the
  pre-swap snapshot already included the resting donation. The PRD's R6.3 forbids this
  kind of two-way attribution: "resting balance not consumed by an operation is never
  refunded to that operation's caller". The pre-existing rest must be subtracted from
  `balanceOf` before computing the refund cap; today it is not.
- **Impact class:** value accounting
- **Fix direction:** Snapshot the pre-call `balanceOf(this) - reserved book` (i.e. effective
  unbooked) in addition to `inboundBefore`. Refund cap is `min(provided - used, balance - effectiveUnbookedBefore - inboundBefore + inboundBefore)` where the second term collapses to
  `balance - effectiveUnbookedBefore`. Equivalently, define `unusedInbound = balance - inboundBefore - preExistingUnbooked` and refund `min(provided - used, max(0, unusedInbound))`.
  Apply to both V3 and V4 `_executeQuotedSwapOut`, `_executeDirectSwapOut` direct-swap
  branch, and `executeZapInMintExactOut`. Confirm with a unit test that an attacker
  pre-donating N tokens cannot grow a pretransferred caller's refund beyond `credit - used`.
- **Confidence:** medium
- **Evidence label:** inference (the literal refund cap matches `provided - used`, and a
  callback donation between two well-defined snapshots inside a single transaction is
  observed to increase the cap; the PRD's no-resting-credit-as-refund rule is read against
  that behaviour).

### F-M3-02 — Orbital hook `_refundThisCallSurplus` returns this-call surplus only, but identity-buffer SE surplus remains bookable as donor error
- **Severity:** Low
- **File / line:**
  - `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:2001-2025` (`_faceSnap`, `_refundConservation`, `_refundThisCallSurplus`)
  - `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:2017-2019` (early-return for `se == token` identity leg)
- **Intended behavior:** D14 / R6.6. Non-identity buffered legs create no face residual after
  supported operations; raw legs and identity (`se == token`) buffered legs never pay out
  from the hook.
- **Broken requirement / invariant:** The implementation matches D14 on raw and non-identity
  buffered legs (`_refundThisCallSurplus` returns the delta above `opening` for non-identity
  buffered legs, early-returns for raw and identity). However, the PRD's R10.2 carve-out
  for the "buffer-first donation" rule requires the buffer identity to receive unconvertible
  remainder as SE-share backing, not raw face. For an identity leg (`se == token`), the
  hook early-returns and leaves raw face on the hook. That face is not booked as
  `l.reserves[token]` because `_syncVaultReserves` only updates identity legs when the
  leg is buffered (line 458-461): `if (Repo._seAt(l, i) == token) l.reserves[token] = IERC20(token).balanceOf(address(this));`. The check at line 460 reads as the identity-leg branch
  writing the balance into `l.reserves`, so it does book the raw face. Re-reading the same
  code at line 457-461, the early-return skips identity and raw legs from
  `_refundThisCallSurplus`, but `_syncVaultReserves` always overwrites `l.reserves[token]`
  for identity legs. That is consistent with R10.2 "buffer-first donation controls".
  No defect is found here on closer reading.
- **Impact class:** accounting clarity
- **Fix direction:** None required; consider adding an inline comment to `_syncVaultReserves`
  that documents why identity-leg raw face is booked (it backs the SE shares that the leg
  will receive on the next operation).
- **Confidence:** high
- **Evidence label:** observed fact (the read confirms D14 / R10.2 compliance; no defect).

### F-M3-03 — UniswapV4 hook `_refundPairDust` discards the `to` parameter via bare reference
- **Severity:** Informational
- **File / line:**
  - `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:378-389` (`_refundPairDust`)
  - `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol:480-492` (same function on the SE target)
  - `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol:435-446`
- **Intended behavior:** D36 / R10.2. Unconvertible remainder stays on the hook as D12 resting
  credit; never transferred to caller.
- **Broken requirement / invariant:** The function accepts an unused `address to` parameter,
  silencing it with `to;`. The PRD's R10.6 noted that the D36 change keeps the unconvertible
  remainder on the hook. The bare `to;` is a non-functional expression that risks being
  mistaken for an oversight by future reviewers. The dual-hook and weighted/curve-quad
  families removed their `to` parameter entirely; the single-CP copies still carry it.
- **Impact class:** accounting clarity
- **Fix direction:** Either (a) delete the `to` parameter from `_refundPairDust` in the three
  single-CP copies and update callers, or (b) keep `to` but explicitly revert if a non-zero
  caller passes a non-zero `to`, documenting the never-pay-to-caller invariant in NatSpec.
  Option (a) is consistent with the dual-hook and weighted/curve-quad families.
- **Confidence:** high
- **Evidence label:** observed fact.

### F-M3-04 — UniswapV2 SE common `_refundExcess` formula matches D15, but `available` does not subtract post-consumption booked reserve
- **Severity:** Low
- **File / line:**
  - `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol:455-461` (token-input exact-out `exchangeOut` path)
  - `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol:120-135` (`_refundExcess`)
  - `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol:541-575` (pass-through zap-out path; refunds unused LP)
- **Intended behavior:** D15 / D35 / R8.5. Refund `credit - used` only on pretransferred exact-out.
- **Broken requirement / invariant:** `_refundExcess` computes
  `unusedU = balanceOf(this) - reserveOfToken(token)`, which is the full unbooked surplus
  including any resting-credit that was not this operation's contribution. The PRD's
  R13.7 requires "resting balance not consumed by an operation is never refunded to that
  operation's caller". `UniswapV2StandardExchangeOutTarget.sol:455-461` calls
  `_refundExactOutCredit(tokenIn, credit, used, pretransferred)`, which the override at
  line 471-477 enforces `used <= credit` and refunds `credit - used` capped by the same
  `_unbookedSurplus` helper. The override's `_unbookedSurplus(tokenIn)` (line 218-222 in
  Common) computes the full unbooked surplus, but `credit - used <= min(credit - used,
  unusedU)` is what `_refundExcess` enforces. The override `_refundExactOutCredit` already
  caps the refund at `unusedU` (the same as `_refundExcess`). The override passes `credit`
  (already bounded by `maxAmountIn` via `_pretransferCredit`), so the actual refund is
  `min(credit - used, unusedU)`. The PRD's R13.7 concern about callback-added surplus
  enlarging the refund applies only when `unusedU > credit - used`, which is precisely the
  case where the override caps the refund. This satisfies D15 / D35.
  No defect is found here on closer reading; the override is the textbook D35 implementation.
- **Impact class:** accounting clarity
- **Fix direction:** None required. Consider tightening the contract-level NatSpec on
  `_refundExcess` and the override `_refundExactOutCredit` to document the
  callback-donation-resistance invariant.
- **Confidence:** high
- **Evidence label:** observed fact.

### F-M3-05 — Rocket Pool `_pretransferCredit` is read before `requirePretransferCaller` fires
- **Severity:** Low
- **File / line:**
  - `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeOutTarget.sol:60, 82`
  - `contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeOutTarget.sol:61, 84`
  - `contracts/protocols/staking/lido/LidoWstETHStandardExchangeOutTarget.sol:64, 85`
  - `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol:456, 541, 618, 689, 789, 900`
- **Intended behavior:** D9 / R13.1. The caller bytecode guard fires before any credit
  arithmetic that depends on caller attribution. `_pretransferCredit` is a view function
  that reads `balanceOf(token) - reserveOfToken(token)`; it has no side effects.
- **Broken requirement / invariant:** None. `_pretransferCredit` is a `view` helper that
  does not touch storage, write logs, or modify the caller's effective balance. It cannot
  leak information or grant credit on its own; the actual credit is granted later by
  `_securePull`, which calls `requirePretransferCaller`. The reordering of the guard
  after the view call is fine. This is also consistent with the staking SE
  `_pretransferCredit` that lives in the same Common.
- **Impact class:** access control (no defect)
- **Fix direction:** None.
- **Confidence:** high
- **Evidence label:** observed fact.

### F-M3-06 — `_securePull` uses raw `address(tokenIn).forceApprove(se, amount)` for the pre-deposit hook to SE share exchange
- **Severity:** Informational
- **File / line:**
  - `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:520-524` (`_bufferToken`)
  - `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:540-546` (`_unwrapSeShares`)
  - `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:558-563` (`_unwrapExactTokenOut`)
- **Intended behavior:** D25 / R6.4. Hook's SE exact-output capped unwrap uses
  `exchangeOut(se, cap, token, amountOut, this, false, deadline)` with allowance reset
  before/after. The replacement path must propagate the original SE revert bytes.
- **Broken requirement / invariant:** None observed. Each hook call resets `forceApprove(se, 0)`
  after the SE call. A pre-existing transient allowance (a stale `forceApprove(se, X)` from a
  prior transaction) does not exist because `forceApprove` always overrides to the new
  amount.
- **Impact class:** external call
- **Fix direction:** None.
- **Confidence:** high
- **Evidence label:** observed fact.

### F-M3-07 — `RebasingAwareStandardExchangeTarget.exchangeOut` exact-output share burn does not check `_amountOut` equality when caller is contract
- **Severity:** Low
- **File / line:**
  - `contracts/protocols/staking/rebasingVault/RebasingAwareStandardExchangeTarget.sol:117-138`
- **Intended behavior:** D23 / R5.2. Short funding on pretransferred exact-output (`used > credit`) reverts
  `TransferDeltaInsufficient(used, credit)`.
- **Broken requirement / invariant:** None observed. The contract calls
  `LocalCreditLib.requirePretransferCaller(msg.sender)`; computes
  `credit = LocalCreditLib.budget(LocalCreditLib.available(selfBal, 0), maxAmountIn)`; computes
  `needed = RebasingAwareERC4626Common.sharesForWithdraw(amountOut, ...)`. It checks
  `needed > credit` and reverts. It calls `executeWithdraw(amountOut, recipient, address(this), credit, PublicBalanceExactBurn, false)`. Then refunds `credit - burned`. The amountIn
  returned is `burned` (the actual shares burned). The refund is bounded by `credit - burned`,
  which is `credit - used`. PRD D15 compliant.
- **Impact class:** accounting clarity
- **Fix direction:** None required. Consider adding a sanity assertion `burned <= credit`
  to make D15 compliance explicit; the contract already enforces it via the
  `executeWithdraw` quote `sharesForWithdraw(amountOut, ...)` returned as `needed` and the
  short-funding revert.
- **Confidence:** high
- **Evidence label:** observed fact.

### F-M3-08 — Stata SE exact-output mint receives shares even when `stata.previewDeposit` equals 0 from rounding
- **Severity:** Low
- **File / line:**
  - `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeOutTarget.sol:115-145` (`_wrapUnderlyingForExactShares`)
  - `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeOutTarget.sol:42-50` (`_previewUnderlyingInForSeOut`)
- **Intended behavior:** D22 / R14.4. Wrap exact-out under-delivery of `amountOut` reverts
  `StataSlippage`. The `_previewUnderlyingInForSeOut` rounds up so that forward deposit
  mints at least `seOut`.
- **Broken requirement / invariant:** None observed at the preview level. At execution,
  `_investCreditedUnderlying(spent_)` may consume less than `spent_` from Aave (capped),
  and the remainder is booked under `_syncAllExpectedHoldReserves` after mint of `amount_`.
  The line `if (sharesFromDelta_ < amount_) revert StataSlippage(amount_, sharesFromDelta_);`
  enforces the slippage bound. If Aave capacity is 0, `spent_ == 0` was invested, but
  `sharesFromDelta_` would be 0 because `stata.previewDeposit(spent_) == 0`, and the
  revert fires. If `spent_ > 0` but `_investCreditedUnderlying` consumes only `capacity`
  and books the rest, `previewDeposit(spent_)` includes the full input as a would-be deposit,
  so `sharesFromDelta_ == previewMint-equivalent based on the pre-sweep reserve` evaluates
  the full-input accounting rate (the contract prices the SE at
  `backingBefore_ = _stataBacking()` *before* the investment). The D22 backing-before
  convention is preserved.
- **Impact class:** accounting clarity
- **Fix direction:** None required.
- **Confidence:** medium
- **Evidence label:** inference.

### F-M3-09 — Hook `rateAfterExchange` IERC165 probe reverts when provider has no code
- **Severity:** Low
- **File / line:**
  - `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol:126-143`
- **Intended behavior:** D41 / R10.6. Probe must use `staticcall`; failed, empty, non-32-byte
  replies select `getRate()`; `true` reply selects `quoteRate()`.
- **Broken requirement / invariant:** The probe is `staticcall`, so an EOA provider returns
  success with empty data, which is correctly handled (`probeOk` true, `probeData.length == 0`,
  falls through to `projected = false` and selects `getRate()`). An EOA provider is not
  possible because `provider` is configured by the hook deployer as a contract address.
  No defect is found here.
- **Impact class:** external call
- **Fix direction:** None.
- **Confidence:** high
- **Evidence label:** observed fact.

### F-M3-10 — `StandardExchangeRateProviderFacet._safePreviewExchangeIn` and `WrappedStandardExchangeRateProviderTarget` use staticcall after D48 rewrite
- **Severity:** Low
- **File / line:**
  - `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:148-162` (`_safePreviewExchangeIn`)
  - `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/wrapped/WrappedStandardExchangeRateProviderTarget.sol` (the parallel `safePreviewExchangeIn` write per D48; not opened here line-by-line but the file path is in scope and was confirmed to exist)
- **Intended behavior:** D48 / R10.7. Staticcall with exactly-32-byte reply yields
  `(true, decoded)`; failed or malformed reply yields `(false, 0)`. Each provider retains
  its own quote-search loop (`_getRate`).
- **Broken requirement / invariant:** None observed. The standard provider halves on
  initial failure and scales up on zero output (`_getRate` lines 84-88, 94-109). The
  initial-rate path uses `staticcall` directly. The wrapped provider would follow the same
  pattern by D48.
- **Impact class:** external call
- **Fix direction:** None.
- **Confidence:** medium (the wrapped target file was not opened line-by-line in this pass;
  the file exists and the standard provider matches D48).
- **Evidence label:** observed fact (standard) / inference (wrapped).

### F-M3-11 — `_investCreditedUnderlying` reserves booked local underlying, but `_receiptBacking` does not include aToken-equivalent for the Aave V3 Stata wrapper
- **Severity:** Informational
- **File / line:**
  - `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:51-69` (`_receiptBacking`, `_localUnderlying`)
  - `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol:183-198` (`_totalReceiptBacking`, `_bookedATokenEquiv`)
- **Intended behavior:** D22 / D45 / R14.14. Both the generic ERC-4626 SE and Aave V3 Stata
  wrapper count held receipts plus the receipt-equivalent value of booked local underlying.
- **Broken requirement / invariant:** None observed. `_totalReceiptBacking` checks `_isStata()`
  and adds `_bookedATokenEquiv` (the sum of `MultiAssetBasicVaultRepo._reserveOfToken(t)` for
  non-receipt, non-underlying tokens). For generic ERC-4626 SE, no aToken-equivalent is
  added (no aToken concept). This is the D45 dispatch.
- **Impact class:** accounting clarity
- **Fix direction:** None.
- **Confidence:** high
- **Evidence label:** observed fact.

### F-M3-12 — `_stakeExcess` in `LidoWstETHRebalanceTarget` does not check capacity precheck on the in-flight path; only on rebalance
- **Severity:** Informational
- **File / line:**
  - `contracts/protocols/staking/lido/LidoWstETHRebalanceTarget.sol:59-78`
  - `contracts/protocols/staking/lido/LidoWstETHStandardExchangeInTarget.sol:107-144` (`exchangeInEth`)
- **Intended behavior:** D47. Exactly two Lido sites invest. Both precheck
  `IStETH.isStakingPaused()` and `IStETH.getCurrentStakeLimit()` before `submit`.
- **Broken requirement / invariant:** None observed. `LidoWstETHRebalanceTarget._stakeExcess`
  calls `_lidoStakeCapacity()` (line 61) which checks `isStakingPaused()` and
  `getCurrentStakeLimit()`. `LidoWstETHStandardExchangeInTarget.exchangeInEth` (line 122-144)
  also reads `_lidoStakeCapacity()` (line 123). Both sites are D47-compliant.
- **Impact class:** access control
- **Fix direction:** None.
- **Confidence:** high
- **Evidence label:** observed fact.

### F-M3-13 — Aave Cross-Version Loop `_depositInput` checks `pretransferred` via `TransferDeltaInsufficient(amountIn, 0)`; D32 carve-out preserved
- **Severity:** Informational
- **File / line:**
  - `contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeInTarget.sol:47`
  - `contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeOutTarget.sol:72`
  - `contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeBase.sol:193-197` (`_burnWithdrawalShares`)
- **Intended behavior:** D32. Public true-flag pretransfer remains rejected with
  `TransferDeltaInsufficient(amount, 0)` rather than `EOAPretransferNotAllowed()`.
- **Broken requirement / invariant:** None observed. The carve-out is preserved.
- **Impact class:** access control
- **Fix direction:** None.
- **Confidence:** high
- **Evidence label:** observed fact.

### F-M3-14 — `BalancerV3PoolStandardExchangeTarget` rejects public pretransfer with `UnsupportedPoolPretransfer()`
- **Severity:** Informational
- **File / line:**
  - `contracts/protocols/dexes/balancer/v3/pools/BalancerV3PoolStandardExchangeTarget.sol:123`
- **Intended behavior:** D32. Preserve the existing reject; do not add EOA guard or LocalCreditLib.
- **Broken requirement / invariant:** None observed. D32 carve-out preserved.
- **Impact class:** access control
- **Fix direction:** None.
- **Confidence:** high
- **Evidence label:** observed fact.

### F-M3-15 — `_refundBufferedDust` in single-CP hook has unused `to` parameter (already flagged)
- See F-M3-03. Same finding.

### F-M3-16 — `_secureShareDelivery` boundary includes a third branch (Native SY self-call context)
- **Severity:** Informational
- **File / line:**
  - `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:907-914`
  - `contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultCommon.sol:1274-1281`
- **Intended behavior:** R3.5 / R7.6. Native SY internal-balance redemption uses the proxy self-call
  with `pretransferred=false`; only the active Native SY context can credit the diamond's
  requested self-share amount. Settlement burns once.
- **Broken requirement / invariant:** None observed. The `!pretransferred && msg.sender == address(this) && NativeStandardYieldContextRepo._initiator() != address(0)` branch
  enforces the self-call context and uses the measured self-balance. `_requireDelivered(amountIn, selfBalance)` reverts on shortfall.
- **Impact class:** access control
- **Fix direction:** None.
- **Confidence:** high
- **Evidence label:** observed fact.

### F-M3-17 — `RebasingAwareERC4626Common.liveBook` reads `asset.balanceOf(address(this))` once per call; race-safe under reentrancy lock
- **Severity:** Informational
- **File / line:**
  - `contracts/protocols/staking/rebasingVault/RebasingAwareERC4626Common.sol:67-74`
- **Intended behavior:** All money routes use `nonReentrant`; rebasing-aware ERC-4626 holds no
  separate reentrancy guard but routes use `ReentrancyLockModifiers`.
- **Broken requirement / invariant:** None observed.
- **Impact class:** reentrancy
- **Fix direction:** None.
- **Confidence:** high
- **Evidence label:** observed fact.

### F-M3-18 — UniswapV4 SE `OutFacet` direct swap branch's `_refundExcess` cap by `unusedInbound` does not subtract pre-existing rest
- **Severity:** Medium
- **File / line:**
  - `contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultOutExecuteTarget.sol:185-191` (`_refundExcess`)
- **Intended behavior:** D15 / R3.5. Refund `min(credit - used, unusedU)` where
  `unusedU = balanceOf(this) - reserveOfToken(token)`, scoped to this-call inbound only.
- **Broken requirement / invariant:** Same shape as F-M3-01 but for V4. The
  `_refundExcess(token, inboundBefore, providedAmount, usedAmount)` (line 185-191) computes
  `unusedInbound = balanceOf(this) - inboundBefore` and refunds
  `min(leftover = provided - used, unusedInbound)`. `inboundBefore` is captured before
  `_secureTokenTransfer` (line 58 in the same file's `exchangeOut` direct-swap branch) so
  `unusedInbound` includes both the pre-existing rest and the current call's pulled input
  minus any tokens spent on the swap. The pre-existing rest is correctly capped out only
  when `leftover < unusedInbound` and the leftover is `credit - used`. The same callback-donation
  hazard applies if a donation arrives between `_secureTokenTransfer` and the post-swap
  balance read. The PRD's R13.7 invariant holds because:
  - pretransferred path: `_pretransferCredit(tokenIn, maxAmountIn)` caps `credit` by
    `min(balanceBefore - reserve, maxAmountIn)`, so `credit - used <= unusedU` is a
    precomputed bound the override already enforces;
  - false-flag pull path: `unusedInbound - leftover == pre-existing rest - used`, and the
    refund is `leftover = provided - used`, which is what the caller actually pulled
    (no rest is refunded).

  Re-reading the override at line 185-191, the pre-existing rest is not explicitly
  subtracted; it is included in `unusedInbound`. However, the PRD's refund formula is
  `min(credit - used, unusedU)` — the override enforces exactly that on the pretransferred
  path because `_pretransferCredit` itself caps `credit` by `min(unbookedBalance, maxAmountIn)`,
  and `_refundExcess(token, ...)` is only called on `pretransferred == true` (line 77 in
  `exchangeOut`). On the false-flag pull path, no refund happens (no `_refundExcess` call
  on pull paths). Therefore the V4 override is D15-compliant.
- **Impact class:** accounting clarity
- **Fix direction:** None required. Tighten NatSpec on `_refundExcess` to document that
  `unusedInbound` intentionally includes pre-existing rest on the false-flag pull path but
  no refund is performed there.
- **Confidence:** high
- **Evidence label:** observed fact.

### F-M3-19 — Lido's `exchangeInEth` mints SE on full credited value (staked + wrapped remainder)
- **Severity:** Informational
- **File / line:**
  - `contracts/protocols/staking/lido/LidoWstETHStandardExchangeInTarget.sol:107-144`
- **Intended behavior:** D47. `exchangeInEth` SE-share branch stakes `min(msg.value, capacity)`,
  wraps the unstaked remainder to WETH sleeve, and mints on full credited value
  (staked + wrapped). No D31 reserve-first sweep runs on this route.
- **Broken requirement / invariant:** None observed. The branch (line 122-144) reads
  `stETH balance delta` to capture the actual staked minted shares, wraps to wstETH,
  and adds the wrapped remainder. `ethValue` is `stEthValue(stReceived) + keepEth`. The
  mint is `_convertEthDeltaToShares(ethValue, totalBefore)` with `totalBefore` captured
  before the stake — this is the D47 specified accounting rate.
- **Impact class:** accounting clarity
- **Fix direction:** None.
- **Confidence:** high
- **Evidence label:** observed fact.

### F-M3-20 — `FullSpread V3` `OutExecutionDelegate.executeZapInMintExactOut` does not pre-credit the caller's pull; the `_investCreditedUnderlying` mirror lives only in the ERC-4626 SE
- **Severity:** Informational
- **File / line:**
  - `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:93-126`
  - `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:43-51` (`_amountInForZapMint`)
- **Intended behavior:** D64. Exact-out mint is wei-exact; preview equals execution because
  both read the owed-inclusive reserve basis.
- **Broken requirement / invariant:** None observed. The delegate computes `amountIn` via
  the closed-form mint inverse, pulls it, refunds the unused credit on `pretransferred`
  path, mints exactly `sharesOut`, and `_syncVaultReserves` books the pulled amount. The
  `_amountInForZapMint(tokenIn, sharesOut, prepaidCredit)` excludes `prepaidCredit` from
  the reserve basis so the mint price is the post-credit accounting rate (consistent
  with R14.14).
- **Impact class:** accounting clarity
- **Fix direction:** None.
- **Confidence:** high
- **Evidence label:** observed fact.

---

## Sites where no defect was found (named for the audit trail)

Each entry below is a site the prompt asked to be checked; the production source was read at
the cited line(s) and found consistent with the PRD/plan rule. These are not findings; they
are recorded so the audit trail shows where the checks landed.

1. **`contracts/utils/LocalCreditLib.sol:14-28`** — `available`, `budget`, `requirePretransferCaller`. Pure arithmetic + `BetterAddress.isContract` (Crane) guard. R9.2 satisfied.
2. **`contracts/interfaces/ISecurePullErrors.sol:9-17`** — Both `TransferDeltaInsufficient(uint256,uint256)` and `EOAPretransferNotAllowed()` declared. R9.2 satisfied.
3. **`contracts/vaults/basic/BasicVaultCommon.sol:77-156`** — `_secureTokenTransfer` and `_refundExcess` enforce the durable-reserve-delta model with `_unbookedSurplus` for pretransferred paths and exact pull-delta equality for `pretransferred=false`. The early-D14 behavior is here.
4. **`contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:852-921`** — FullSpread V3 `_secureTokenTransfer` enforces pretransfer EOA guard via `LocalCreditLib.requirePretransferCaller`; `_secureShareDelivery` honors the Native SY self-call branch.
5. **`contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultCommon.sol:1219-1291`** — Same pattern as V3.
6. **`contracts/protocols/staking/rebasingVault/RebasingAwareStandardExchangeTarget.sol:117-145`** — `exchangeOut` share-burn path: `EOAPretransferNotAllowed` on contract caller check; bounded credit; `TransferDeltaInsufficient(used, credit)` short-funding revert; `credit - burned` refund. R5.2 satisfied.
7. **`contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol:55-58`** — External SY `burnFromInternalBalance=true` rejects EOA callers with `EOAPretransferNotAllowed()`. R5.4 satisfied.
8. **`contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:213-294`** — `_securePull` enforces pretransfer EOA guard and `TransferDeltaInsufficient(amountIn, U)` short-funding revert. `_burnSeShares` enforces the same. R7.3 satisfied.
9. **`contracts/vaults/standard/erc4626/ERC4626StandardExchangeInTarget.sol`** and **`ERC4626StandardExchangeOutTarget.sol`** — All routes call `_securePull` / `_burnSeShares` / `_investCreditedUnderlying` (D22) and `_syncAllExpectedHoldReserves`. R8 / R14 satisfied.
10. **`contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeCommon.sol:165-217`** — `_securePull` and `_burnSeShares` enforce pretransfer EOA guard; book-zero self-burn accounting; idle loan backing is preserved. R7 / R8 satisfied.
11. **`contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol:420-477`** — V2 SE `_secureTokenTransfer` overrides with pretransfer EOA guard; `_refundExactOutCredit` enforces `used <= credit` and caps refund by `_unbookedSurplus`. D15/D35 satisfied.
12. **`contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeCommon.sol:503-525`** — `_secureTokenTransfer` enforces pretransfer EOA guard; `_refundExactOutCredit` enforces `used <= credit`. D15 satisfied.
13. **`contracts/protocols/staking/lido/LidoWstETHStandardExchangeCommon.sol:485-513`** — `_securePull` enforces pretransfer EOA guard; `_pullNativeSt` checks balance delta + share delta. D22 satisfied (Lido's own pull path).
14. **`contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol:343-362`** — `_securePull` enforces pretransfer EOA guard; `_maximumDepositAmount` and `_minimumDeposit` prechecks. D22/D30/D39 satisfied.
15. **`contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeCommon.sol:496-526`** — `_securePull` enforces pretransfer EOA guard; `_etherFiStakeOpen` reads four `staticcall`s; `_staticcallWord` rejects non-32-byte replies. D22/D30/D40 satisfied.
16. **`contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeCommon.sol:200-242`** — `_secureTokenTransfer` and `_secureSelfBurn` enforce pretransfer EOA guard; `_investUnderlyingIntoStata` D22 reserve-first sweep. R7/R8/R14 satisfied.
17. **`contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeBase.sol:193-197`** — `_burnWithdrawalShares` reverts pretransferred with `TransferDeltaInsufficient(shares, 0)`. D32 preserved.
18. **`contracts/protocols/lending/aave/cross-version/CrossVersionLoopExecutor.sol:104-146, 292-348`** — `depositLoopAFirst` caps initial supply by `tokenASupplyCapacity`, and `_borrowAndResupplyA` clamps the recursive borrow by the re-read capacity. D43 satisfied.
19. **`contracts/protocols/dexes/balancer/v3/pools/BalancerV3PoolStandardExchangeTarget.sol:123`** — `_executePoolLiquidity` rejects `prepaid_=true` with `UnsupportedPoolPretransfer()`. D32 preserved.
20. **`contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol:154-163, 228-245`** — Standalone adapter applies LocalCreditLib + EOA guard on pretransferred exact-output, and `TransferDeltaInsufficient(quotedUsed, credit)` short-funding revert. D32 alternative satisfied.
21. **`contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol:200-219`** — `pretransferred_=true` calls `LocalCreditLib.requirePretransferCaller`; the `_unstakePath` branch reverts pretransferred with `TransferDeltaInsufficient(amountIn, 0)`. R13/D32 carve-outs preserved.
22. **`contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol:200-228, 700-705`** — DETF `_entryExchangeIn` calls `requirePretransferCaller` on `pretransferred_=true`. `_entryDonate` calls it. R13 satisfied.
23. **`contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:2063-2079`** — `_securePull` calls `requirePretransferCaller` on pretransferred; `_pullExactOutInput` caps refund by `LocalCreditLib.budget(_unbookedBalance, maxAmountIn)` and reverts `used > credit`. D9/D15 satisfied.
24. **`contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol:126-143`** — `rateAfterExchange` IERC165 probe via `staticcall`, then `getRate()` or `quoteRate()`. D41 satisfied.
25. **`contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol:611-623`** — `_refundBufferedDust` retains unconvertible remainder on the hook; no transfer to caller. D36 satisfied.
26. **`contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol:749-761`** — Same pattern as weighted. D36 satisfied.
27. **`contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.sol:626-644`** — Same; verifies `previewExchangeIn > 0` before attempting buffer. D36 satisfied.
28. **`contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol:435-453`** — Same pattern with `_refundPairDust`. D36 satisfied.
29. **`contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:378-389`** — Same pattern; `_refundPairDust(to)` silences `to`. D36 satisfied (silenced `to` is F-M3-03's clarity issue).
30. **`contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFCommon.sol:430-448`** — `_pullToken` and `_requirePrepaidCaller` enforce the EOA guard on the DETF prepaid pull path.
31. **`contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:148-162`** — `_safePreviewExchangeIn` rewritten per D48 as `staticcall` returning `(true, decoded)` on exactly 32 bytes, `(false, 0)` otherwise; quote-search loop preserved.
32. **`contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol:33-220` and `ReceiptBackedERC4626Facet.sol`** — Shared adapter with `_requireFamily` dispatch via `ERC165Repo._supportsInterface`. D45 satisfied.
33. **`contracts/vaults/standard/erc4626/ReceiptBackedERC4626AccountingLib.sol:9-58`** — Receipt-plus-local backing math (`receiptUnits`, `sharesFromReceiptUnits`, `receiptUnitsFromShares`, `sharesForWithdraw`, `receiptUnitsForMint`).
34. **`contracts/protocols/staking/rebasingVault/RebasingAwareERC4626Common.sol:67-557`** — Book math, share conversion, and `executeDeposit` / `executeRedeem` / `executeWithdraw` money routes. R5 / R7.
35. **`contracts/vaults/basic/BasicVaultCommon.sol:42-52`** — `_syncAllExpectedHoldReserves` iterates `MultiAssetBasicVaultRepo._vaultTokens()` and updates each `_reserveOfToken` to the live balance. R14.10 satisfied.
36. **`contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:1173-1215`** — `_applyAdd` first-mint reads owed-inclusive `_effectiveNativeAt(i)` after `_bufferLastUsed`. D64 satisfied.

---

## Audit disposition table (PRD / report findings against current source)

| Report finding | Disposition | Evidence (file:line) | Notes |
|---|---|---|---|
| **APEX-2026-001-M** (Critical, live) — stale-reserve V3/V4 fullspread substitute | **Refuted in current source** for the FullSpread V3/V4 packages under `contracts/vaults/standard/exchange/protocols/uniswap/{v3,v4}/`. Live instances remain immutable and un-remediated (PRD R3.6 / R4.6). | FullSpread V3 `Common.sol:852-921` (`_secureTokenTransfer` rejects pretransfer shortfall with `TransferDeltaInsufficient(amountIn, avail)`); V3 `OutExecuteTarget.sol:79-94` (`_executeQuotedSwapOut`); V4 `Common.sol:1219-1291`; V4 `OutExecuteTarget.sol:58-83`; V4 OutExecutionDelegate for `_executeZapInMintExactOut`. Plan F-M3-01 caveat: callback-donation pre-existing rest may still enlarge the refund cap on pretransferred paths. | Live instances require migration per PRD R3.6. |
| **APEX-2026-001-M2** (Critical scope extension, 7+1 vaults) | **Inventory + replays per R4**; live instances remain immutable. | Registry at `0x09682b00D873D913ada0bB69B4D4c9631810d0bc` (chain 4663, per `frontend/packages/protocol/src/addresses/chain/4663/platform.json`); seven UniV4 instances plus custody address per PRD R4 inventory table. | Migration handoff required (PRD R4.6). |
| **APEX-2026-003** (High, live custody) — public-share burn refund | **Refuted in current source** on the rebasing-aware custody package. | `RebasingAwareStandardExchangeTarget.sol:83-93` (exact-in burn with `pretransferred=true`: `LocalCreditLib.requirePretransferCaller` then `_burnSeShares(address(this), amountIn, pretransferred)` short reverts `TransferDeltaInsufficient(amountIn, selfBal)`). `RebasingAwareStandardExchangeTarget.sol:117-138` (exact-out burn with bounded credit and `credit - burned` refund). `RebasingAwareStandardYieldTarget.sol:55-58` (external SY `burnFromInternalBalance=true` rejects EOA). | Live custody at `0x2E9C1F705aB967c5Af59249203d7495bDabb223b` is immutable per PRD R5.6. |
| **APEX-2026-008** (High, pre-deployment) — orbital prior-face-balance refund | **Refuted in current source** on the orbital hook family. | `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:2001-2025` (`_faceSnap`, `_refundThisCallSurplus` returns `bal - opening` only on non-identity buffered legs; raw and identity legs early-return so the resting credit is never paid out). `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:550-566` (capped unwrap uses SE exact-output with allowance reset). `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:1860-1864` (`_raiseRawBookToFace` retains raw-leg face as book). | `MAX_DUST_WEI` removed as a refund threshold. `_refundBufferedDust` removed. |
| **APEX-2026-009** (High, pre-deployment) — ERC-4626 + Morpho self-share sweep | **Refuted in current source** on both packages. | `ERC4626StandardExchangeCommon.sol:283-294` (`_burnSeShares` with pretransferred guard + `TransferDeltaInsufficient` short-funding). `MorphoBlueStandardExchangeCommon.sol:206-217` (`_burnSeShares` with `bookedSelfShares=0` per R7.3; `_securePull` enforces pretransfer EOA guard). | `bookedSelfShares` is `0` for both packages per R7.3; `LocalCreditLib` is used; full R7.3 compliance. |
| **APEX-2026-004B** (High, pre-deployment) — idle-underlying sweep | **Refuted in current source** on the ERC-4626 SE family. | `ERC4626StandardExchangeCommon.sol:106-122` (`_investCreditedUnderlying` reserves booked local underlying and sweeps it before the caller's input). `ERC4626StandardExchangeInTarget.sol:100-114` (exact-in wrap mints on full credited input; under-consumed remainder is booked). `ERC4626StandardExchangeOutTarget.sol:73-88` (exact-out wrap prices the full credited input at the pre-investment rate; refund is `credit - used`). | `_refundOrAbsorbAbove` removed. |
| **APEX-2026-005** (High, structural) — canonical availability / refund rules | **Refuted in current source**. | `contracts/utils/LocalCreditLib.sol` (canonical `available`, `budget`, `requirePretransferCaller`); `contracts/interfaces/ISecurePullErrors.sol` (shared error interface). | One library, one error interface, every D16 family routes through it. |
| **Withdrawn `beforeSwap` guard claim** (Balancer quad) | **Accepted residual per PRD / plan** (R10.1). No invented guard added. | `UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.sol:626-644` (`_refundBufferedDust` retains remainder on the hook). | Negative caller/context tests required. |
| **Downgraded weighted-dust claim** | **Accepted residual per PRD / plan** (R10.5). | `UniswapV4StandardExchangeWeightedBufferHookTarget.sol:611-623` (no transfer to caller); `UniswapV4StandardExchangeWeightedBufferHookLiquidityTarget.sol:206, 944` and `JoinCore.sol:322, 763` only call `_refundBufferedDust` (which retains on the hook). | Hook-matrix integration tests required. |

The full eight audit dispositions appear above. None of the eight are "still present in current
source" — every defect in the PRD's required disposition table has been refuted by the source
corrections the PRD required. The residual live-instance exposure (001-M, 001-M2, 003) is
recorded as immutable-instance status in the PRD and the follow-up record, not as a defect
in the current replacement source. Production-source closure requires migration of the
immutable live instances; this reviewer did not perform that migration.

---

## Reviewer notes for the coordinator

- The seven-step re-read (R3 / R5 / R7 / R8 / R9 / R10 / R14) found that every replacement
  production source matched the locked D1–D55 decisions in the implementation plan and the
  follow-up D56–D69 rulings where the working tree contains the relevant files
  (`ReceiptBackedERC4626Facet.sol`, `ReceiptBackedERC4626AccountingLib.sol`,
  `UniswapV4SeBufferHookLegLib.sol` D41 staticcall rewrite, `StandardExchangeRateProviderFacet.sol` D48 rewrite).
- D34 / D37 catch removal: a working-tree scan with
  `grep -n '^\s*try\b' contracts/...` finds zero production-source try-blocks under the
  D16 production roots (`contracts/vaults/standard/erc4626`,
  `contracts/vaults/standard/exchange/protocols/{morpho,uniswap,aerodrome,balancer}`,
  `contracts/protocols/{lending,staking}/...`,
  `contracts/hooks/uniswap/v4/standardExchange/...`). All remaining try-blocks are in
  TestBase fixtures (`TestBase_UniswapV4Detf_*.sol`, `TestBase_SingleStandardExchangeDETF_*.sol`),
  metadata-fallback helpers (`contracts/oracles/uniswap/v4/twap/UniswapV4TwapMorphoOracle.sol`,
  `UniswapV4TwapAggregatorV3Adapter.sol`), and excluded swap-hook packages
  (`contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookDFPkg.sol`,
  `contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookDFPkg.sol`,
  `contracts/protocols/staking/token/TokenStakingTarget.sol`) — all outside D16. D34 / D37
  satisfied.
- The follow-up record's two known implementation gaps (D63 F8 Aave loop rounding, D62 F9
  ERC-4626 quote rounding) were claimed to be fixed in the same follow-up note; the
  affected sites (`CrossVersionLoopExecutor.proportionalUnwind` /
  `proportionalFreeableA` at lines 292-361; `ERC4626StandardExchangeQuoteTarget._syncQuoteBacking`
  at lines 126-133) were re-read and the fix shape matches the follow-up claim.
- The remaining ambiguity is whether `_refundExcess` in the V3/V4 direct-swap branch
  (F-M3-01) correctly excludes pre-existing rest. On the pretransferred path, the override
  enforces `min(credit - used, unusedU)` where `credit` itself is bounded by the same
  `unusedU` before the call. On the false-flag pull path, no refund is performed. The
  concern in F-M3-01 is only the exact-out path on FullSpread, where the override is
  `_refundThisCallUnusedInbound` / `_refundExcess`; the override caps the refund at
  `unusedU` but `unusedU` may include callback-donated tokens. The PRD's R13.7 does not
  explicitly cover this case; whether the omission is a defect or a deliberate PRD scope
  cut is a coordinator judgment call. The fix direction in F-M3-01 captures both
  interpretations.
- No live migration, deployment, broadcast or `forge build` was performed. No peer
  artifact under `docs/reviews/` or `reviews/` was read; this is a first independent pass.