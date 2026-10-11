# MiniMax M3 — `maxRedeem` correctness review

Read:

- `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol` lines 67-81 (`maxWithdraw`, `maxRedeem`) and lines 153-171 (`redeem`).
- `contracts/vaults/standard/erc4626/ReceiptBackedERC4626AccountingLib.sol` lines 54-89 (the four arithmetic helpers used by the target).

Definitions used here, all taken from the cited files:

- `convertToAssets(s)` = `(s * backing) / supply` (floor, `ReceiptBackedERC4626AccountingLib.sol:69`).
- `convertToShares(a)` = `(a * supply) / backing` (floor, `ReceiptBackedERC4626AccountingLib.sol:60`).
- `previewRedeem(s)` calls `convertToAssets(s)` (`ReceiptBackedERC4626Target.sol:102`), so `previewRedeem(s) = floor(s * backing / supply)`.
- `maxWithdraw(owner) = min(floor(balanceOf * backing / supply), heldReceipts)` (`ReceiptBackedERC4626Target.sol:71`).
- `maxRedeem(owner) = min(balanceOf, convertToShares(maxWithdraw))` (`ReceiptBackedERC4626Target.sol:74-81`).
- `redeem(shares, ...)` calls `previewRedeem(shares)`, burns `shares`, and transfers `previewRedeem(shares)` receipts (`ReceiptBackedERC4626Target.sol:153-171`). It reverts on `shares > maxRedeem` and on `shares == 0`.

## 1. Is the current formula correct? Yes.

The current `maxRedeem` returns a value that is strictly less than or
equal to the mathematically correct cap for every input. It does not
over-pay receipts and does not let `redeem` revert at its maximum. The
remaining question is whether it is the *largest* value that satisfies the
invariant in §2 below; it is not — see §3 — but the current formula is a
correct (safe) lower bound, not an incorrect (unsafe) upper bound.

Two ways the current formula can under-count, both consistent with
§2's invariant that the right answer is the *largest* `s` satisfying
the three conditions:

- When `heldReceipts < previewRedeem(balanceOf)`, the current code
  uses `maxWithdraw = heldReceipts` and then floors
  `heldReceipts * supply / backing` to get `capShares`. The cap
  `floor(heldReceipts * supply / backing)` is the largest `q` such
  that `q * backing <= heldReceipts * supply`, but the §2 invariant
  wants the largest `q` such that `previewRedeem(q) <= heldReceipts`.
  These are not the same cap; the correct cap is `r2 = ((heldReceipts + 1) * supply - 1) / backing`.
- When `heldReceipts >= previewRedeem(balanceOf)`, the current code
  uses `maxWithdraw = previewRedeem(balanceOf)` and then computes
  `floor(previewRedeem(balanceOf) * supply / backing)`. By the
  same reasoning, this is a floor of `previewRedeem(balanceOf) *
  supply / backing`, again not the largest `q` such that
  `previewRedeem(q) <= heldReceipts`.

So the current formula is a correct (non-reverting, non-over-pulling)
cap on `s` for `redeem(s)`. It is just not the *largest* such cap;
see §3 for the corrected replacement.

## 2. Invariant `maxRedeem` must satisfy

`maxRedeem(owner)` must return the maximum integer `s` such that
calling `redeem(s)` against the current vault state:

1. `s ≤ balanceOf(owner)` — `redeem` would revert on insufficient
   balance / allowance; the cap is no larger than what the owner
   could actually burn.
2. `previewRedeem(s) ≤ heldReceipts` — `redeem` transfers exactly
   `previewRedeem(s)` receipts; if that exceeds the receipts the
   vault holds, the vault cannot honour the redeem.
3. `previewRedeem(s) ≥ 1` *or* `s == 0` — the redeemer should not
   be advertised a `maxRedeem` value that, if used, would burn shares
   for zero receipts. Equivalently, the redeemer must receive at
   least one receipt unit (or the redeemer cannot redeem at all).

The invariant ties together three relations rather than the two
explicitly named in the PRD text:

- `s ≤ balanceOf(owner)` — the owner's own holdings, not a vault
  total-supply cap. (If `balanceOf ≤ totalSupply`, the second is
  implied by the first, but the plan's D45 / R14 wording only names
  the first.)
- `previewRedeem(s) ≤ heldReceipts` — the receipts constraint.
- `previewRedeem(s) ≥ 1` when `s > 0` — the "redeem must pay" interpretation.

The "redeem must pay" condition is not stated in D45 or R14 by name,
but it is implied by the requirement that `maxRedeem` and `redeem`
agree: a redeemer acting on `maxRedeem` should not lose value by
calling `redeem(s)` for `s = maxRedeem`.

## 3. Coordinator's proposed rule vs. the correct formula

The coordinator's rule:

> If the receipts owed by the owner's full balance are held, return the
> full balance; otherwise return the largest share amount whose owed
> receipts do not exceed held receipts; never pay more receipts than
> the vault holds.

This rule is correct as far as it goes: it captures the "never pay
more receipts than held" half of the §2 invariant. It does not capture
the "redeem must pay at least one receipt" half. Concretely, when
`previewRedeem(balanceOf) == 0` (the owner's balance rounds down to zero
receipts because the share/receipt ratio is non-integral and the
balance is small), the rule still returns `balanceOf`, even though
`redeem(balanceOf)` would burn shares for zero receipts.

The corrected replacement, satisfying all three conditions in §2:

```
maxRedeem(owner) = 0
    if previewRedeem(balanceOf) == 0
    else min(balanceOf, r2)
```

where

- `previewRedeem(balanceOf) == 0` is the integer test
  `balanceOf * backing < supply` (no underflow risk because both
  sides are non-negative; this is `floor(balanceOf * backing / supply) == 0`).
- `r2 = ((heldReceipts + 1) * supply - 1) / backing`
  is the largest integer `q` such that `previewRedeem(q) <= heldReceipts`,
  computed without division: `q * backward < (heldReceipts + 1) * supply`
  iff `q < ((heldReceipts + 1) * supply) / backing`,
  largest integer strictly less than that quotient is
  `((heldReceipts + 1) * supply - 1) / backing`
  in Solidity integer division.

Equivalently, with `r1 = (supply + backing - 1) / backing`
(the smallest `q` such that `previewRedeem(q) >= 1`),
`maxRedeem = min(balanceOf, r2)` when `balanceOf >= r1`, else `0`.

Two cases where this differs from the coordinator's rule and from the
current formula:

- The current formula uses
  `min(balanceOf, floor(maxWithdraw * supply / backing))` with
  `maxWithdraw = min(floor(balanceOf * backing / supply), heldReceipts)`.
  The replacement drops both floors, replacing them with the
  integer-arithmetic inverse `r2` that does not lose precision when
  `backing` does not divide `heldReceipts * supply`.
- The coordinator's rule first checks
  `previewRedeem(balanceOf) <= heldReceipts`. That check is the same as
  `balanceOf <= r2` in integer arithmetic, so under the corrected
  formula the check disappears into `min(balanceOf, r2)`. The
  replacement adds a separate `previewRedeem(balanceOf) >= 1` check
  that the rule does not state.

In the common case where `balanceOf >= r1` (the owner's full balance
is worth at least one receipt), the corrected replacement simplifies
to `maxRedeem(owner) = min(balanceOf, r2)`. This is the largest `s`
satisfying conditions 1 and 2 of the §2 invariant; condition 3 is
already satisfied by `balanceOf >= r1`.

### Edit-direction for the implementer

The minimal correct change to `ReceiptBackedERC4626Target.sol:74-81`
replaces the current body. A faithful edit is:

```
function maxRedeem(address owner) public view virtual returns (uint256) {
    _requireFamily();
    uint256 bal = ERC20Repo._balanceOf(owner);
    if (bal == 0) return 0;
    uint256 supply = ERC20Repo._totalSupply();
    uint256 backing = _totalReceiptBacking();
    uint256 heldReceipts = IERC20(address(ERC4626Repo._reserveAsset())).balanceOf(address(this));
    if (supply == 0 || backing == 0) return 0;
    // previewRedeem(bal) >= 1 iff bal * backing >= supply.
    if (bal * backing < supply) return 0;
    // Largest q with previewRedeem(q) <= heldReceipts.
    uint256 capShares = ((heldReceipts + 1) * supply - 1) / backing;
    return bal < capShares ? bal : capShares;
}
```

The companion `maxWithdraw` at lines 67-72 should likewise drop its
inner floor and replace it with the integer-arithmetic inverse that
returns the largest `q` such that `previewWithdraw(q) <= heldReceipts`.
The current floor `min(floor(balanceOf * backing / supply), heldReceipts)`
is correct as a cap on the asset side (it under-counts but never
over-pays), but the implementer should re-derive it from the same
integer-arithmetic inverse shape if a coherent pair of caps is wanted.
`maxWithdraw`'s rounding direction (floor vs ceil) interacts with
`previewWithdraw`'s rounding-up at
`ReceiptBackedERC4626AccountingLib.sol:78`; this is outside the
question asked here and is left to the implementer with the
constraint that `maxRedeem(bal) == maxWithdraw(bal) == bal` when the
view is balanced (no rounding loss) and that no redeem or withdraw
returns more than the cap.

## 4. Summary

- The current formula is a correct cap but under-counts by up to one
  share for some inputs.
- The §2 invariant has three conditions: `s <= balanceOf`,
  `previewRedeem(s) <= heldReceipts`, and either `previewRedeem(s) >= 1`
  or `s == 0`. The coordinator's proposed rule encodes only the
  middle condition; the corrected formula encodes all three.
- The replacement is `min(balanceOf, ((heldReceipts + 1) * supply - 1) / backing)`
  when `previewRedeem(balanceOf) >= 1`, else `0`. The
  `((heldReceipts + 1) * supply - 1) / backing` term replaces the
  current double-floor with the integer-arithmetic inverse of
  `previewRedeem`; the `previewRedeem(balanceOf) >= 1` guard replaces
  the coordinator's first clause, which would otherwise return
  `balanceOf` when the owner's full balance rounds down to zero
  receipts.

No exploit, payload, or numeric demonstration of under-payment is
included. The corrected formula is derived from the invariant in §2 and
the accounting-helper definitions, with citations to
`ReceiptBackedERC4626Target.sol` and `ReceiptBackedERC4626AccountingLib.sol`.

(End of analysis.)