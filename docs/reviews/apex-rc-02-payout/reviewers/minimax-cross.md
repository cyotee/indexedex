# MiniMax M3 — RC-02 cross-review (replacement session)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49UzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** One defensive cross-review of the RC-02 originals. The coordinator notes: a normal ERC-4626 withdraw transfers the requested assets and burns the rounded share amount from the owner. Confirm or withdraw the claim against the interface.
- **Method:** Read the three peer originals. Re-examine the OZ ERC-4626 `withdraw` semantics against the helper. Re-confirm against my own original.
- **Untrusted:** the three peer originals, treated as model content. The PRD is the controlling text.
- **Forge:** Not run. No code edit. No PRD/plan write.

---

## Close RC-02.

I withdraw my original claim that "withdraw pays more than the asset amount." A normal ERC-4626 `withdraw(assets, ...)` transfers exactly `assets` of the underlying to the receiver; the rounding is applied to the share count burned from the owner, not to the assets delivered. The helper at `ERC4626StandardExchangeCommon.sol:116-127` calls `vault.withdraw(shortfall, recipient, address(this))`, which transfers exactly `shortfall` to the recipient. The recipient receives exactly the accounted due amount (`fromLocal + shortfall = due`).

All three peer originals and I now agree: **Close RC-02.**

---

## The one resolution

The route uses an **exact-asset withdrawal** whose share charge matches the preview. This is one of the two allowed resolutions in the PRD acceptance criteria at line 94: "the route uses an exact-asset withdrawal whose share charge matches the preview."

The helper at `ERC4626StandardExchangeCommon.sol:116-127`:

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

- `fromLocal = min(due, local)` — the local cash portion. Direct transfer of exactly that amount.
- `vault.withdraw(shortfall, recipient, address(this))` — the protocol vault's normal ERC-4626 `withdraw`. It transfers exactly `shortfall` underlying to the recipient; rounding applies to the share count, not the asset amount.
- The post-check (`< shortfall → Slippage`) guards under-delivery. There is no branch for over-delivery because normal ERC-4626 does not over-deliver.

On successful supported execution, the recipient receives exactly `fromLocal + shortfall = due`. No remainder is created. Nothing is sent to `feeTo`. The `redeem`-then-return-more pattern from the September claim is absent.

---

## Per-reviewer synthesis

### Astra (`astra-original.md`, 94 lines)

- **Headline:** "Close RC-02. No implementation gap was established in the current local-first payout path."
- **Critical correction:** "The September description is not true of the current helper: it no longer redeems a rounded-up receipt-share amount. It calls the protocol vault's exact-asset `withdraw(shortfall, recipient, address(this))`, then transfers the local portion. For a normal ERC-4626 vault and supported standard underlying transfers, the recipient receives exactly the accounted due amount. Rounding affects the receipt shares charged for the withdrawal, not the requested underlying assets sent."
- **Three callers read:** InTarget, OutTarget, StandardYieldTarget. Each passes the accounted amount and does not add a second payout.
- **ERC-4626 semantic confirmation:** Used Context7 for OpenZeppelin to confirm `withdraw` sends the specified assets and rounds on shares. The repository's test stubs (`SimpleYieldERC4626`, `CappedPausableERC4626`) exhibit that distinction.
- **Tests substantiate:** APEX_R14 `test_RC02_exactOut_localFirst_nonUnitRate_paysExactDue` (`:163-180`), `test_RC02_exactIn_localFirst_nonUnitRate_returnMatchesRecipient` (`:184-195`), and `Apex008` `test_R6_cappedUnwrap_fundedSuccess` (`:224-234`).
- **Verdict:** Close RC-02.

### Grok (`grok-original.md`, 21 lines)

- **Headline:** "Close RC-02. The September claim is refuted."
- **Core:** "`ERC4626StandardExchangeCommon.sol:116-127` pays booked local cash first. The shortfall is `vault.withdraw(shortfall, recipient, address(this))`. A normal ERC-4626 `withdraw` sends that asset amount. Local cash is then transferred in the same amount already subtracted from the due. The recipient receives exactly the accounted due. Nothing is sent to `feeTo`."
- **Verdict:** Close RC-02.

### Kimi (`kimi-original.md`, 57 lines)

- **Headline:** "Close RC-02. The September claim is refuted by current source."
- **Core:** "The helper now performs an ERC-4626 exact-asset `withdraw`, and the recipient receives exactly the accounted due amount on every production route. Every acceptance criterion has a current test asserting it."
- **Test mapping:** `…APEX_R14.t.sol:163-181` (non-unit rate, mixed local/protocol), `:184-196` (return equals recipient delta), `Apex008.t.sol:224-234` (orbital capped unwrap, no leftover face).
- **Non-goals check:** "No residual is sent to `feeTo` ... no exact-input refund was reintroduced ... D12 resting face is accounted separately ... no unbounded-loss claim is made."
- **History:** "The September PRD's 'broken requirement' paragraph accurately describes the then-current code (`redeem` + `>= shortfall` acceptance). That shape is gone today; the exact-asset withdrawal plus the delivery check and the three test suites close it. The alert was real at filing; it is resolved now."
- **Verdict:** Close RC-02.

### Mine (this session's `minimax-original.md`)

- **Retracted.** My original claimed the helper "redeems previewWithdraw(shortfall) and accepts any payout at least shortfall" with overpayment. That was wrong. A normal ERC-4626 `withdraw(assets, ...)` transfers exactly `assets` to the receiver. Rounding applies to the share count burned, not the assets delivered. The helper's behavior is correct: the recipient receives exactly the accounted due amount.

---

## Where I agree

All four reviewers (Astra, Grok, Kimi, my retracted original) converge: **Close RC-02.** The one resolution is that the route uses an exact-asset withdrawal whose share charge matches the preview. This is the second of the two allowed resolutions in the PRD acceptance criteria.

---

## What would change this answer

I would re-open the answer only if:

1. A normal ERC-4626 `withdraw(assets, ...)` transferred more than `assets` to the receiver. — Not true. OpenZeppelin ERC-4626 v5.x and the repository's stubs confirm: `withdraw(assets, ...)` transfers exactly `assets` of the underlying.
2. The helper called a `redeem(previewWithdraw(shortfall), ...)` pattern. — Not true. The helper calls `vault.withdraw(shortfall, ...)`, which is the exact-asset path.
3. The acceptance tests do not exist. — Not true. APEX_R14 `test_RC02_exactOut_localFirst_nonUnitRate_paysExactDue` (`:163-180`) and `test_RC02_exactIn_localFirst_nonUnitRate_returnMatchesRecipient` (`:184-196`) directly assert the recipient's balance equals the accounted due amount.
4. A non-unit receipt rate creates a remainder. — Not true. A non-unit rate means `previewWithdraw(shortfall)` returns a rounded-up share count; the SE burns that many shares and the vault sends exactly `shortfall` underlying. The rounding cost lands on the SE's share balance, not the recipient's underlying.

None of these is true. The close stands.

---

## Dissent or unresolved items

**Dissent from none of the peers.** All four converge: Close RC-02.

**Unresolved item:** None. The item is closed. The September alert was real at filing; the current source is correct. The one resolution is the exact-asset withdrawal path.

---

## Files examined (this cross-review)

- `docs/reviews/apex-rc-02-payout/reviewers/astra-original.md` — read in full (94 lines).
- `docs/reviews/apex-rc-02-payout/reviewers/grok-original.md` — read in full (21 lines).
- `docs/reviews/apex-rc-02-payout/reviewers/kimi-original.md` — read in full (57 lines).
- `docs/reviews/apex-rc-02-payout/reviewers/minimax-original.md` — re-read for self-consistency. Not treated as a peer.

No Forge / build / test was executed. No code was edited.

---

**Close RC-02. The one resolution:** the route uses an exact-asset withdrawal whose share charge matches the preview. Nothing is sent to `feeTo`. The alert was real at filing; it is resolved now.

I did not run Forge.