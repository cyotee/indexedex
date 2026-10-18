# Kimi K3 — RC-02 local-first payout: close or keep? (replacement-session original)

- **Label:** Replacement-session original, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read. The controlling text (`docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md` RC-02 at `:86-99` and its resolution row at `:231`) was read fresh this round — no guard denial. Nothing was edited. I did not run Forge.
- **Date:** 2026-10-18.

## Verdict: Close RC-02.

The September claim — helper redeems `previewWithdraw(shortfall)` and accepts any payout at least the shortfall — is **refuted by current source**. The helper now performs an ERC-4626 exact-asset `withdraw`, and the recipient receives exactly the accounted due amount on every production route. Every acceptance criterion has a current test asserting it.

## The helper (current source)

`contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:116-127` (read this round):

```solidity
    function _payUnderlyingLocalFirst(IERC4626 vault, uint256 due, address recipient) internal {
        IERC20 underlying = IERC20(_underlying());
        uint256 local = _localUnderlying();
        uint256 fromLocal = due < local ? due : local;
        uint256 shortfall = due - fromLocal;
        if (shortfall > 0) {
            uint256 before_ = underlying.balanceOf(recipient);
            vault.withdraw(shortfall, recipient, address(this));
            if (underlying.balanceOf(recipient) - before_ < shortfall) revert Slippage();
        }
        if (fromLocal > 0) underlying.safeTransfer(recipient, fromLocal);
    }
```

`withdraw(shortfall, …)` is the exact-asset ERC-4626 path: the protocol vault sends exactly `shortfall` underlying and charges `previewWithdraw(shortfall)` shares (rounded up) to the SE itself — the rounding cost lands on the SE's own share balance, never as extra assets to the recipient. The delivery check (`< shortfall → Slippage`) guards the exact-amount invariant. This is precisely one of the PRD's two allowed resolutions: "the route uses an exact-asset withdrawal whose share charge matches the preview." No remainder is created, so nothing is sent to `feeTo` or paid out as excess.

## Callers (all production, read this round)

- `ERC4626StandardExchangeOutTarget.sol:112` — unwrap exact-out: `_payUnderlyingLocalFirst(vault, amountOut, recipient)` after burning only the quoted `amountIn`; returns `amountIn`.
- `ERC4626StandardExchangeInTarget.sol:100` — unwrap exact-in: pays the previewed `amountOut` and returns that same value, so the exact-in return equals what the recipient received.
- `ERC4626StandardYieldTarget.sol:26` — SY vault-held redemption: same helper with the same previewed amount; the returned `amount_` is the preview paid exactly.

(The September file-and-line, `:80-92`, moved to `:116-127` — consistent with the helper having been rewritten in the interim.)

## Acceptance criteria, each with a current test

1. **Recipient receives exactly the accounted due, non-unit rate, mixed local cash + shortfall:** `test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_APEX_R14.t.sol:163-181` — `_seedNonUnitMixed` (1 ether local + 2-wei shortfall), and the test first proves the old bug shape exists in principle (`:168`: redeeming the rounded shares would overpay), then asserts `spent == need` (`:177`), `recipient delta == due` (`:178`), the SE's share charge equals `previewWithdraw` (`:179`), and the ending book is zero with no over-withdrawal into the book (`:180`).
2. **Exact-input return equals the recipient delta:** `…APEX_R14.t.sol:184-196` — `got == preview` (`:194`) and `recipient delta == got` (`:195`).
3. **Orbital capped-unwrap on this SE leaves no operation-created face:** `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_Apex008.t.sol:224-234` (`test_R6_cappedUnwrap_fundedSuccess`) — exact user delta (`:231`), SE burns only used shares (`:232`), `token0.balanceOf(hook) == 0` — no leftover buffered face (`:233`). The test's base inherits `TestBase_ERC4626StandardExchange` (`:64` of the TestBase), so leg 0 is the RC-02 SE. Bounded-burn recurrence (`:236-252`) and the resting-face preservation assertions in `…OrbitalBufferHook_SeMatrixBehavior.sol:465-466` cover the D12-resting-face non-goal separately.

The production rule is therefore proven, not merely present: no test is missing against these acceptance criteria.

## Non-goals check

No residual is sent to `feeTo` (the ending book assertion is zero and the shortfall is not over-withdrawn); no exact-input refund was reintroduced (the helper has no refund branch); D12 resting face is accounted separately (the SeMatrixBehavior resting-face assertions, not this item); no unbounded-loss claim is made — the rounding cost is a bounded share-side charge to the SE.

## On the alert's history

The September PRD's "broken requirement" paragraph accurately describes the then-current code (`redeem` + `>= shortfall` acceptance). That shape is gone today; the exact-asset withdrawal plus the delivery check and the three test suites close it. The alert was real at filing; it is resolved now.

Close RC-02

I did not run Forge.
