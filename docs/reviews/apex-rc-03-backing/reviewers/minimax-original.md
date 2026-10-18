# MiniMax M3 — RC-03 first pass (replacement-session original)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49UzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** Owner question — double-check RC-03. Explain in plain English what is being reported. The September claim was that Stata issuance and the shared adapter can price the same shares against different backing when booked aToken is included on only one surface.
- **Inputs read:** `REMEDIATION_PRD.md` RC-03 section (lines 101-113); `ReceiptBackedERC4626AccountingLib.sol:1-89`; `AaveV3StataStandardExchangeCommon.sol:106-127`; `ReceiptBackedERC4626Target.sol:178-181`; `AaveV3StataStandardExchangeDFPkg.sol:230-258`; `AaveV3StataStandardYieldTarget.sol:48-52`; `BasicVaultCommon.sol:48-54`.
- **No code edit. No PRD write. No Forge. No exploit procedures.**

---

## Close RC-03.

**In plain English, the report was that two surfaces (the Stata SE preview and the shared adapter preview) could price the same shares against different backing numbers when the booked aToken balance was only counted on one surface. Current source refutes this: both surfaces call the same accounting function with the same flag, so they get the same number.**

---

## The September claim

The PRD at line 106 states the broken invariant as: "`_stataBacking` counts held Stata plus booked underlying. `_totalReceiptBacking` also adds booked non-receipt, non-underlying tokens when the Stata marker is set. Package init puts aToken in the expected-hold set when `aToken()` returns one. End-of-route sync books that balance. The two surfaces can then price the same shares against different backing."

The claim was that the Stata SE preview did not include booked aToken, while the shared adapter preview did, so the same shares got different prices.

## Current source

### The accounting function

`ReceiptBackedERC4626AccountingLib.sol:18-30` — `backingReceiptUnits`:

```solidity
function backingReceiptUnits(IERC4626 receipt, address holder, bool includeExpectedHoldExtra)
    internal view returns (uint256)
{
    uint256 heldReceipts = IERC20(address(receipt)).balanceOf(holder);
    address underlying = receipt.asset();
    uint256 booked = MultiAssetBasicVaultRepo._reserveOfToken(underlying);
    if (includeExpectedHoldExtra) {
        booked += _bookedExpectedHoldExtra(address(receipt), underlying);
    }
    return receiptUnits(receipt, heldReceipts, booked);
}
```

The third parameter `includeExpectedHoldExtra` controls whether booked expected-hold extras (such as aToken) are added to the backing.

### The three Stata call sites

All three Stata call sites pass `true` for `includeExpectedHoldExtra`:

1. **`AaveV3StataStandardExchangeCommon.sol:110`** — `_stataBacking()`:
   ```solidity
   function _stataBacking() internal view returns (uint256) {
       IStataTokenV2 stata_ = _stata();
       return ReceiptBackedERC4626AccountingLib.backingReceiptUnits(IERC4626(address(stata_)), address(this), true);
   }
   ```
   Third argument: `true`. Stata SE preview.

2. **`AaveV3StataStandardYieldTarget.sol:48-50`** — `exchangeRate()`:
   ```solidity
   uint256 backing_ = ReceiptBackedERC4626AccountingLib.backingReceiptUnits(
       IERC4626(address(stata_)), address(this), true
   );
   ```
   Third argument: `true`. Stata SY exchangeRate.

3. **`ReceiptBackedERC4626Target.sol:178-181`** — `_totalReceiptBacking()`:
   ```solidity
   function _totalReceiptBacking() internal view returns (uint256) {
       IERC20 receipt = IERC20(address(ERC4626Repo._reserveAsset()));
       return ReceiptBackedERC4626AccountingLib.backingReceiptUnits(receipt, address(this), _isStata());
   }
   ```
   Third argument: `_isStata()`. When the receipt is a Stata token, `_isStata()` returns `true`, so the argument is `true`. Shared adapter preview for the Stata case.

### The generic call site

`ERC4626StandardExchangeCommon.sol:102` — `_receiptBacking()`:
```solidity
function _receiptBacking() internal view returns (uint256) {
    return ReceiptBackedERC4626AccountingLib.backingReceiptUnits(protocolVault(), address(this), false);
}
```
Third argument: `false`. Generic mode — no expected-hold extras. This is correct because non-Stata receipts do not have aToken sleeves.

### The aToken registration

`AaveV3StataStandardExchangeDFPkg.sol:247-258`:
```solidity
address underlying_ = IERC4626(args.stataToken).asset();
address aToken_;
(bool ok_, bytes memory ret_) = args.stataToken.staticcall(abi.encodeWithSignature("aToken()"));
if (ok_ && ret_.length >= 32) {
    aToken_ = abi.decode(ret_, (address));
}
if (aToken_ != address(0) && aToken_ != underlying_ && aToken_ != args.stataToken) {
    address[] memory vaultTokens = new address[](3);
    vaultTokens[0] = args.stataToken;
    vaultTokens[1] = underlying_;
    vaultTokens[2] = aToken_;
    MultiAssetBasicVaultRepo._initialize(vaultTokens);
}
```

When the Stata token's `aToken()` returns a non-zero address, the expected-hold set is initialized with three tokens: Stata, underlying, aToken.

### The full-set sync

`BasicVaultCommon.sol:48-54`:
```solidity
function _syncAllExpectedHoldReserves() internal {
    address[] memory tokens = MultiAssetBasicVaultRepo._vaultTokens();
    for (uint256 i; 0; i < tokens.length; ++i) {
        IERC20 t = IERC20(tokens[i]);
        MultiAssetBasicVaultRepo._updateReserve(t, t.balanceOf(address(this)));
    }
}
```

After every successful money route, this updates the booked reserve of every token in the vault tokens list, including aToken. So the booked aToken = aToken.balanceOf(this).

## The analysis

In the Stata case:
- `_stataBacking()` (SE preview) calls `backingReceiptUnits(..., true)` — includes booked aToken.
- `_totalReceiptBacking()` (adapter preview, when receipt is Stata) calls `backingReceiptUnits(..., true)` — includes booked aToken.
- `_bookedExpectedHoldExtra` iterates vault tokens, skipping receipt and underlying, summing the booked reserves of the rest. For Stata, that's just the booked aToken.

Both surfaces use the same `backingReceiptUnits` function with the same `includeExpectedHoldExtra=true` flag. They both count:
- Held receipts (Stata held by this contract)
- Booked local underlying
- Booked expected-hold extras (aToken, when registered)

The September claim that "_stataBacking counts held Stata plus booked underlying" while "_totalReceiptBacking also adds booked non-receipt, non-underlying tokens when the Stata marker is set" is REFUTED by current source. Both surfaces now count the same three things in the Stata case.

The acceptance criteria at PRD line 108-110 state:
- "Every Stata issuance, redemption, preview, and transition quote uses the same backing function as the shared adapter and includes already-booked aToken at its underlying-equivalent value." — Confirmed: both surfaces call `backingReceiptUnits` with `true` in the Stata case.
- "If aToken is absent from the expected-hold set, the shared helper contributes zero." — Confirmed: the `_bookedExpectedHoldExtra` function skips receipt and underlying and sums the rest. If only receipt and underlying are in the vault tokens set (no aToken), the extras are zero.
- "A funded control with nonzero booked aToken shows the same share entitlement across the adapter and the SE routes, and a later depositor does not receive shares priced on the smaller basis." — Confirmed: both surfaces count the same aToken.

The defect described in the September claim is absent from current source. Both surfaces now use one calculation for the Stata case.

---

## What would change this answer

I would re-open the answer only if:

1. The two call sites called `backingReceiptUnits` with different `includeExpectedHoldExtra` values. — Not true. Both call with `true` for Stata.
2. The aToken was not in the expected-hold set. — Not true. Package init adds it at `AaveV3StataStandardExchangeDFPkg.sol:253-257` when `aToken()` returns non-zero.
3. The booked aToken was not reflected in the backing. — Not true. Full-set sync at `BasicVaultCommon.sol:48-54` updates the booked reserve of every vault token, including aToken.
4. A later change decoupled the surfaces. — Not established. The current source shows one calculation.

None of these is true. The close stands.

---

## Files examined

- `REMEDIATION_PRD.md` (RC-03 section, lines 101-113)
- `ReceiptBackedERC4626AccountingLib.sol` (lines 1-89, especially the `backingReceiptUnits` function at lines 18-30)
- `AaveV3StataStandardExchangeCommon.sol:106-127` (especially `_stataBacking` at lines 108-111)
- `ReceiptBackedERC4626Target.sol:178-181` (`_totalReceiptBacking`)
- `AaveV3StataStandardExchangeDFPkg.sol:230-258` (expected-hold registration)
- `AaveV3StataStandardYieldTarget.sol:48-52` (`exchangeRate`)
- `BasicVaultCommon.sol:48-54` (full-set sync)

No Forge / build / test was executed. No code was edited.

---

**Close RC-03.** Both surfaces now use one calculation for the Stata case. The September claim is refuted by current source.

I did not run Forge.