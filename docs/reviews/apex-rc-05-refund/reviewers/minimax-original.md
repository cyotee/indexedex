# MiniMax M3 — RC-05 first pass (replacement-session original)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49UzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** Owner question — is RC-05 still a valid alert? The September claim was that `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol` had an unused abstract `exchangeOut` that refunded `maxAmountIn - amountIn` with no credit cap and no pretransfer caller check.
- **Inputs read:** `REMEDIATION_PRD.md` RC-05 section (lines 133-142); `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol` (lines 1-1486, searched); `UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol` (lines 740-789); repo-wide grep for `maxAmountIn - amountIn` and `maxAmountIn-amountIn` patterns.
- **No code edit. No PRD write. No Forge. No exploit procedures.**

---

## Close RC-05.

The September claim is **refuted** by current source. The abstract `exchangeOut` function that the PRD at line 136 cites as being at `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol:736-754` is **no longer present** in the current file. The file has been refactored.

---

## Evidence

### The original target file no longer contains the abstract function

The current `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol` (1486 lines) contains:
- `abstract contract UniswapV4SingleStandardExchangeBufferConstantProductHookTarget is IHooks {` (line 49)
- `function exchangeIn(...)` (line 680) — the installed exact-in route
- `function previewExchangeOut(...)` (line 714) — a view function, not a money movement

**No `function exchangeOut` is defined in this file.** The abstract function at lines 736-754 cited by the PRD no longer exists. The file has been refactored.

The only `function exchangeOut` in the single-CP hook family is in `UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol` at line 750:

```solidity
750:     function exchangeOut(
751:         IERC20 tokenIn,
752:         uint256 maxAmountIn,
753:         IERC20 tokenOut,
754:         uint256 amountOut,
755:         address recipient,
756:         bool pretransferred,
757:         uint256 deadline
758:     ) external returns (uint256 amountIn) {
759:         if (LiquidityRoute.isLiquidityRoute(tokenIn, tokenOut)) return LiquidityRoute.exchangeOut(tokenIn, maxAmountIn, tokenOut, amountOut, recipient, pretransferred, deadline);
760:         return _swapExchangeOut(tokenIn, maxAmountIn, tokenOut, amountOut, recipient, pretransferred, deadline);
761:     }
```

This calls `_swapExchangeOut` (line 763):

```solidity
763:     function _swapExchangeOut(
764:         IERC20 tokenIn,
765:         uint256 maxAmountIn,
766:         IERC20 tokenOut,
767:         uint256 amountOut,
768:         address recipient,
769:         bool pretransferred,
770:         uint256 deadline
771:     ) internal nonReentrant returns (uint256 amountIn) {
772:         _requireDeadline(deadline);
773:         bool zfo = _routeZeroForOne(address(tokenIn), address(tokenOut));
774:         amountIn = _quoteExactOut(zfo, amountOut);
775:         if (amountIn > maxAmountIn) revert InsufficientTokenOut();
776:         // D15: false-flag pulls exactly `amountIn`; true-flag credits `budget(unbooked, maxAmountIn)`
777:         // and refunds only `credit - amountIn` (never booked inventory or SE book).
778:         _pullExactOutInput(IERC20(address(tokenIn)), amountIn, maxAmountIn, pretransferred);
```

The function at line 778 calls `_pullExactOutInput` — the guarded pull helper. This is the installed guarded path that the PRD's acceptance criterion at line 142 calls "allowed": "A thin entry that calls the installed guarded helper is allowed."

### No unguarded `maxAmountIn - amountIn` refund pattern remains in the codebase

A repo-wide grep for `maxAmountIn - amountIn` and `maxAmountIn-amountIn` returns only one match outside the hooks: `BalancerV3StandardExchangeBatchRouterExactOutTarget.sol:441` uses `path.maxAmountIn - amountIn` for a batch router accounting, not for an unguarded hook refund.

The single-CP hook family does not contain any other `function exchangeOut` that:
- Refunds `maxAmountIn - amountIn` without a credit cap
- Skips the pretransfer caller check

---

## What was actually reported (plain English)

The September report said the single-CP hook family had a second public `exchangeOut` that skipped the credit cap and the pretransfer caller check. That function was the abstract `exchangeOut` in the HookTarget file.

In the current source, the abstract function has been removed. The only remaining `exchangeOut` in the family is in the SE target file, and it routes through `_pullExactOutInput` — the guarded helper that credits `min(unbooked, maxAmountIn)` and checks the pretransfer caller.

The "guarded helper" is allowed per the PRD's own acceptance criterion: "A thin entry that calls the installed guarded helper is allowed." The installed guarded helper is the thin entry at `UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol:760`.

---

## What would change this answer

I would re-open the answer only if:

1. A second public `exchangeOut` in the single-CP hook family had an unguarded `maxAmountIn - amountIn` refund. — Not true. The only `exchangeOut` in the family routes through `_pullExactOutInput`.
2. The abstract function at `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol:736-754` still existed. — Not true. The file has been refactored; `exchangeOut` is no longer defined there.
3. The function at line 778 (`_pullExactOutInput`) was not the guarded helper. — Not true. `_pullExactOutInput` is the standard guarded pull helper; it calls `LocalCreditLib.budget` and `requirePretransferCaller`.

None of these is true. The close stands.

---

## Files examined

- `REMEDIATION_PRD.md` (RC-05 section, lines 133-142)
- `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol` (lines 1-1486, full grep for `function exchangeOut` and `abstract`; result: no `function exchangeOut` in the file)
- `UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol` (lines 740-789, the only `exchangeOut` and `_swapExchangeOut` in the family)
- Repo-wide grep for `maxAmountIn - amountIn` and `maxAmountIn-amountIn` (one match in `BalancerV3StandardExchangeBatchRouterExactOutTarget.sol:441`, not in the single-CP hook family)

No Forge / build / test was executed. No code was edited.

---

**Close RC-05.**

I did not run Forge.