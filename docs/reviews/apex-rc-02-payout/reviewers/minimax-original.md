# MiniMax M3 — RC-02 first pass (replacement-session original)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49UzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** Owner question — how should RC-02 be resolved? Is the production defect still present?
- **Inputs read:** `REMEDIATION_PRD.md` RC-02 section (lines 86-99), `ERC4626StandardExchangeCommon.sol` (lines 80-127), `ERC4626StandardExchangeOutTarget.sol` (lines 107-115), `ERC4626StandardExchangeInTarget.sol` (lines 90-103), `ERC4626StandardYieldTarget.sol` (lines 18-36).
- **No code edit. No PRD write. No Forge. No exploit procedures.**

---

## Do not close RC-02.

The September claim is **confirmed** against current source. `_payUnderlyingLocalFirst` at `ERC4626StandardExchangeCommon.sol:116-127` does call `vault.withdraw(shortfall, recipient, address(this))`, which internally uses `previewWithdraw(shortfall)`, and accepts any redemption at least `shortfall`. It does not cap the redemption, retain the difference, or report the larger amount.

The acceptance criterion **"The recipient of a local-first underlying payout receives exactly the accounted due amount"** is **not satisfied** by current source.

---

## Defect

- **Defect class:** Production defect — recipient receives more than the accounted due amount on rounding remainder.
- **File and line:** `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:116-127` (`_payUnderlyingLocalFirst`). The vault.withdraw at line 123 sends whatever the protocol vault computes for `shortfall` shares, which can be more than `shortfall` due to rounding. The post-check at line 124 (`if (underlying.balanceOf(recipient) - before_ < shortfall) revert Slippage()`) only reverts when the recipient received **less** than shortfall, not when the recipient received **more**. The excess stays with the recipient, not in the SE.
- **Broken requirement:** PRD acceptance criterion line 93: "The recipient of a local-first underlying payout receives exactly the accounted due amount."
- **Impact class:** Recipient overpayment on a non-unit receipt rate. The excess is operation-created surplus that was not booked; it is not sent to feeTo (which is what the PRD non-goal at line 98 requires) but it is also not returned to the SE.
- **Fix direction (closed):** Cap the redemption. Compute the actual vault output by either reading `underlying.balanceOf(recipient) - before_` after the withdraw, or by precomputing via `previewWithdraw` and rejecting mismatches. Any excess over `shortfall` must be returned to the SE (either by transferring back to the vault via `deposit` or by crediting the vault directly). The fix is the single change to `_payUnderlyingLocalFirst` at `ERC4626StandardExchangeCommon.sol:116-127`; no other file needs to change.

---

## Evidence

### The helper at `ERC4626StandardExchangeCommon.sol:114-127`

```solidity
114:     /// @dev R14.15: pay `due` underlying from booked local cash first and withdraw only the
115:     ///      shortfall from the protocol vault. The vault's own exceeded-max error propagates.
116:     function _payUnderlyingLocalFirst(IERC4626 vault, uint256 due, address recipient) internal {
117:         IERC20 underlying = IERC20(_underlying());
118:         uint256 local = _localUnderlying();
119:         uint256 fromLocal = due < local ? due : local;
120:         uint256 shortfall = due - fromLocal;
121:         if (shortfall > 0) {
122:             uint256 before_ = underlying.balanceOf(recipient);
123:             vault.withdraw(shortfall, recipient, address(this));
124:             if (underlying.balanceOf(recipient) - before_ < shortfall) revert Slippage();
125:         }
126:         if (fromLocal > 0) underlying.safeTransfer(recipient, fromLocal);
127:     }
```

The function:
- Line 119: `fromLocal = min(due, local)` — capped at the smaller of the due amount and the local booked/unbooked balance.
- Line 123: `vault.withdraw(shortfall, recipient, address(this))` — calls the protocol vault's `withdraw` (ERC-4626 semantics) which burns `shortfall` shares from `address(this)` and transfers the resulting underlying to `recipient`. The actual underlying transferred is whatever `previewWithdraw(shortfall)` computes — this can be more than `shortfall` due to rounding.
- Line 124: `if (underlying.balanceOf(recipient) - before_ < shortfall) revert Slippage();` — the post-check only reverts when the recipient received **less** than `shortfall`. If the recipient received **more** (due to rounding), the function continues and the recipient keeps the excess.
- Line 126: `if (fromLocal > 0) underlying.safeTransfer(recipient, fromLocal);` — direct transfer of the local cash portion to the recipient.

The function does NOT:
- Pre-compute `previewWithdraw(shortfall)` and pass that amount to a `redeem(shortfall, recipient, address(this))` call.
- Cap the redemption at `shortfall` and return the excess.
- Send the excess to `feeTo`.
- Record the difference in any state variable.

The function's behavior is exactly what the PRD at line 91 describes: "redeems previewWithdraw(shortfall) directly to the recipient and accepts any redemption at least shortfall. It does not cap the redemption, retain the difference, or report the larger amount."

### The three production callers

**`ERC4626StandardExchangeOutTarget.sol:107-115`:**
```solidity
107:         // Unwrap exact-out: SE → underlying — burn only amountIn; local cash pays first (R14.15).
108:         if (address(tokenIn) == address(this) && address(tokenOut) == underlying) {
109:             amountIn = _previewSeInForUnderlyingOut(amountOut);
110:             if (amountIn > maxAmountIn) revert Slippage();
111:             _burnExactOutShares(amountIn, maxAmountIn, pretransferred);
112:             _payUnderlyingLocalFirst(vault, amountOut, recipient);
113:             _syncAllExpectedHoldReserves();
114:             return amountIn;
115:         }
```

The caller passes `amountOut` (the exact-out amount) to `_payUnderlyingLocalFirst` as the `due` parameter. The recipient is the `recipient` argument from the caller.

**`ERC4626StandardExchangeInTarget.sol:90-103`:**
```solidity
90:         }
91:
92:         // Unwrap exact-in: SE → underlying (no exit fee) — burn SE shares (self-burn path).
93:         // Nested DETF push+true leaves shares on this diamond; burn from address(this).
94:         // !pretransferred burns from msg.sender (standard ERC20 burn-from-holder).
95:         if (address(tokenIn) == address(this) && address(tokenOut) == underlying) {
96:             // Entitlement in receipt units of the full backing; local cash pays first (R14.15).
97:             amountOut = _previewUnderlyingOutForSeIn(amountIn);
98:             if (amountOut < minAmountOut) revert Slippage();
99:             _burnSeShares(msg.sender, amountIn, pretransferred);
100:             _payUnderlyingLocalFirst(vault, amountOut, recipient);
101:             _syncAllExpectedHoldReserves();
102:             return amountOut;
103:         }
```

The caller passes `amountOut` (the previewed output) to `_payUnderlyingLocalFirst`. The `amountOut` is the entitlement in receipt units; it is what the SE computed the caller is owed. The recipient is the `recipient` argument.

**`ERC4626StandardYieldTarget.sol:18-36` (`_redeemVaultHeld`):**
```solidity
18:     function _redeemVaultHeld(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_)
19:         internal override nonReentrant returns (uint256 amount_)
20:     {
21:         IERC4626 vault_ = protocolVault();
22:         if (tokenOut_ == vault_.asset()) {
23:             amount_ = _previewUnderlyingOutForSeIn(shares_);
24:             if (amount_ < minimum_) revert Slippage();
25:             _burnSeShares(address(this), shares_, false);
26:             _payUnderlyingLocalFirst(vault_, amount_, receiver_);
27:         } else {
```

The caller passes `amount_` (the previewed output) to `_payUnderlyingLocalFirst` as the `due` parameter. The recipient is `receiver_`.

In all three callers, the recipient is whoever the caller specifies — the user (exact-out unwrap) or the user (exact-in unwrap) or the redeem receiver (SY redeem). The helper sends the payment to that recipient.

### The composing check at `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:559-564`

The PRD at line 89 cites this as a composing check:

```solidity
559:     function _totalSupply() internal view returns (uint256) {
560:         return ERC20Repo._totalSupply();
561:     }
562:
563:
564:     function _balanceOf(address account) internal view returns (uint256) {
```

This is the base ERC-4626 totalSupply/balanceOf view; it is not the composing check. The actual composing check that REQ-02 cites is at a different location. The line range in the PRD (`:559-564`) is the view layer, not the composition site. The RC-02 defect is in `_payUnderlyingLocalFirst` itself, not in the orbital hook's composing check.

---

## Test coverage

A repo-wide grep for `_payUnderlyingLocalFirst` in `test/` returns **no matches**. There is no test that directly verifies the recipient's underlying balance after `_payUnderlyingLocalFirst` returns the accounted `due` amount. The acceptance criterion "A non-unit receipt rate and a mixed local-cash plus protocol-vault shortfall are both asserted, including recipient balance delta, returned amount, and ending reserve book" is not covered by any existing test.

---

## What would change this answer

I would re-open to Close if:
1. The helper were changed to cap the redemption and return the excess.
2. The acceptance test were added to verify the recipient's balance equals the accounted amount.

Neither is true. The defect remains.

---

## Files examined

- `REMEDIATION_PRD.md` (RC-02 section, lines 86-99)
- `ERC4626StandardExchangeCommon.sol:80-127` (the helper)
- `ERC4626StandardExchangeOutTarget.sol:107-115` (caller 1)
- `ERC4626StandardExchangeInTarget.sol:90-103` (caller 2)
- `ERC4626StandardYieldTarget.sol:18-36` (caller 3)
- `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:550-569` (composing area)

No Forge / build / test was executed. No code was edited.

---

Do not close RC-02

I did not run Forge.