# MiniMax M3 — RC-06 first pass (replacement-session original)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49UzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** Owner question — is RC-06 already closed in current source? The September claim was that after `exchangeOut`, `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol` assigned the approval cap to the returned share count and discarded the amount the SE reported.
- **Inputs read:** `REMEDIATION_PRD.md` RC-06 section (lines 146-155); `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol` lines 1-2380 (full source).
- **No code edit. No PRD write. No Forge. No exploit procedures.**

---

## Close RC-06.

The September claim is **refuted** by current source. The function at lines 711-727 (`_unwrapExactTokenOut`) does **not** return a share count. It is a void function. The function at lines 691-697 (`_unwrapSeShares` 2-arg) also does not return a share count. The function at lines 699-708 (`_unwrapSeShares` 3-arg) also does not return a share count. The function at lines 750-765 (`_swapExactOutExecute`) also does not return a share count.

**In plain English, the mis-report is absent from current source.** The function was refactored.

---

## Evidence

### The `exchangeOut` call site at lines 711-727

```solidity
711:     function _unwrapExactTokenOut(address token, uint256 amountOut) internal {
712:         if (amountOut == 0) return;
713:         address se = _seOf(token);
714:         if (se == token) return;
715:         uint256 cap = _spendableSeShares(token);
716:         if (cap == 0) revert InsufficientTokenOut();
717:         uint256 quotedIn = ClaimLib.invertUnwrapExactTokenOut(se, token, amountOut);
718:         if (quotedIn == 0 || quotedIn > cap) revert InsufficientTokenOut();
719:         uint256 maxIn = quotedIn;
720:         IERC20(se).forceApprove(se, maxIn);
721:         uint256 beforeOut = IERC20(token).balanceOf(address(this));
722:         IStandardExchangeOut(se).exchangeOut(
723:             IERC20(se), maxIn, IERC20(token), amountOut, address(this), false, block.timestamp
724:         );
725:         IERC20(se).forceApprove(se, 0);
726:         if (IERC20(token).balanceOf(address(this)) - beforeOut < amountOut) revert InsufficientTokenOut();
727:     }
```

The function at lines 711-727 is a **void function** (no return type after the parameter list). It does not return a share count.

- Line 719: `uint256 maxIn = quotedIn;` — `maxIn` is set from `quotedIn` (the calculated input from `ClaimLib.invertUnwrapExactTokenOut`), not from the SE's reported spend.
- Line 720: `IERC20(se).forceApprove(se, maxIn);` — approve the cap.
- Line 722-724: `IStandardExchangeOut(se).exchangeOut(...)` — call the SE.
- Line 725: `IERC20(se).forceApprove(se, 0);` — approve back to zero (the existing approved sequence remains).
- Line 726: check the underlying was received.

The function does **not** assign `seIn = maxIn` and discard the SE's reported spend. It does not return a share count at all.

### The `_unwrapSeShares` overloads at lines 691-708

```solidity
691:     function _unwrapSeShares(address token, uint256 seIn) internal returns (uint256 pairOut) {
692:         if (seIn == 0) return 0;
693:         address se = _seOf(token);
694:         if (se == token) return seIn;
695:         uint256 m = IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seIn, IERC20(token));
696:         return _unwrapSeShares(token, seIn, m > 0 ? m - 1 : 0);
697:     }
698:
699:     function _unwrapSeShares(address token, uint256 seIn, uint256 minOut) internal returns (uint256 pairOut) {
700:         if (seIn == 0) return 0;
701:         address se = _seOf(token);
702:         if (se == token) return seIn;
703:         IERC20(se).forceApprove(se, seIn);
704:         pairOut = IStandardExchangeIn(se).exchangeIn(
705:             IERC20(se), seIn, IERC20(token), minOut, address(this), false, block.timestamp
706:         );
707:         IERC20(se).forceApprove(se, 0);
708:     }
```

These functions return `pairOut` (the underlying amount received), not a share count. The `seIn` is passed in from the caller; these functions don't discard a return value.

### The `_swapExactOutExecute` at lines 750-765

```solidity
750:     function _swapExactOutExecute(address tokenIn, address tokenOut, uint256 amountOut, uint256 feeWad)
751:         internal
752:         returns (uint256 amountIn)
753:     {
754:         _requireNonZero(amountOut);
755:         amountIn = _previewSwapExactOutWithFee(tokenIn, tokenOut, amountOut, feeWad);
756:         if (_seOf(tokenOut) != address(0)) {
757:             _unwrapExactTokenOut(tokenOut, amountOut);
758:         } else {
759:             ...
760:         }
761:         _requirePostUnderRadius();
762:     }
```

Returns `amountIn` (the SE input consumed), not a share count. The `seIn` comes from the quote at line 755.

---

## What was actually reported (plain English)

The September report said the orbital capped-unwrap function took the SE's reported spend and discarded it in favor of the approval cap. The current source has neither the discarded-spend pattern nor a return value that reports a share count. The function is a void function that just does the SE call, checks the underlying was received, and lets the caller use the call site. The mis-report is absent from current source.

---

## What would change this answer

I would re-open the answer only if:

1. The function at lines 711-727 returned a share count. — Not true. It is a void function.
2. The function assigned `seIn = maxIn` and discarded a value. — Not true. `maxIn = quotedIn` comes from the quote; there is no discarded return.
3. A function in the family returned the approval cap as the share count. — Not true. The `_unwrapSeShares` overloads return `pairOut` (underlying received), not share count. `_swapExactOutExecute` returns `amountIn`, not share count.

None of these is true. The close stands.

---

## Files examined

- `REMEDIATION_PRD.md` (RC-06 section, lines 146-155)
- `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol` lines 680-765 (the unwrap function `_unwrapExactTokenOut` at 711-727, the `_unwrapSeShares` overloads at 691-708, and `_swapExactOutExecute` at 750-765)

No Forge / build / test was executed. No code was edited.

---

**Close RC-06.**

I did not run Forge.