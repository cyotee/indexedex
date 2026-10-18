# Kimi K3 — RC-06 orbital capped unwrap: close or keep? (replacement-session original)

- **Label:** Replacement-session original, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read. The controlling text (`docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md` RC-06 at `:146-157`) was read fresh this round — no guard denial. Nothing was edited. I did not run Forge.
- **Date:** 2026-10-18.

## Verdict: Close RC-06. The function no longer returns a share count.

## The September claim and the current source

The claim: after `exchangeOut`, the orbital capped unwrap assigned `seIn = maxIn` — the approval cap — to the returned share count and discarded the Standard Exchange's reported spend (September site `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:550-565`).

Current `_unwrapExactTokenOut` (`UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:711-727`, read in full this round):

```solidity
    function _unwrapExactTokenOut(address token, uint256 amountOut) internal {
        if (amountOut == 0) return;
        address se = _seOf(token);
        if (se == token) return;
        uint256 cap = _spendableSeShares(token);
        if (cap == 0) revert InsufficientTokenOut();
        uint256 quotedIn = ClaimLib.invertUnwrapExactTokenOut(se, token, amountOut);
        if (quotedIn == 0 || quotedIn > cap) revert InsufficientTokenOut();
        uint256 maxIn = quotedIn;
        IERC20(se).forceApprove(se, maxIn);
        uint256 beforeOut = IERC20(token).balanceOf(address(this));
        IStandardExchangeOut(se).exchangeOut(
            IERC20(se), maxIn, IERC20(token), amountOut, address(this), false, block.timestamp
        );
        IERC20(se).forceApprove(se, 0);
        if (IERC20(token).balanceOf(address(this)) - beforeOut < amountOut) revert InsufficientTokenOut();
    }
```

- **No `returns` clause.** The function returns nothing, so there is no share count that could misreport. This is the PRD's second permitted resolution verbatim: "or the unused return is removed and every caller is updated."
- **Every caller is updated:** the family's grep shows exactly three call sites — `Common.sol:758`, `SeTarget.sol:144`, `SeTarget.sol:213` — all statement-form calls with no assignment. None consumes a return.
- **No cap-to-return pattern survives:** a family-wide search for `= maxIn` / `return maxIn` / cap-assignment forms finds none outside this function's local `maxIn = quotedIn` (a tight cap equal to the computed quote, not a fat maximum).
- **The approval sequence is preserved** (`:720` approve the cap, `:725` back to zero) — acceptance criterion 2.
- **A short SE delivery still reverts** (`:726`, exact-delta check) — acceptance criterion 3; and since `maxIn == quotedIn`, the unwrap cannot create a surplus (non-goal honored).

The September line range now holds unrelated code — the function moved and lost its return in the interim. The defect's mechanism is absent, not merely unused.

## On the September dissent

MiniMax's recorded dissent (the assignment was unused, so not a functional defect) is moot: the PRD's requirement was a truthful return or its removal, and the tree carries the removal. No choice between the two resolutions remains open — the source already contains one; I do not choose.

## Boundaries

Source-presence verdict on the current tree; no Forge run and no runtime claim by me; nothing here speaks to deployed bytecode. The alert was accurate at filing; it is resolved now.

Close RC-06

I did not run Forge.
