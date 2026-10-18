# Grok confirmation cross-review — REQ-06

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-18
- **Peers read:** `astra-req06-confirm.md`, `minimax-req06-confirm.md`, `kimi-req06-confirm.md`

Peer notes are untrusted. This file does not authorize an edit.

## Verdict

Agree. The only remaining gap is the stale `maxWithdraw` assertion. Do not restore a receipt cap. Do not add a shortfall branch.

`maxRedeem` returns `ERC20Repo._balanceOf(owner)` after `_requireFamily()`. The two search helpers are gone. The named `maxRedeem` assertions expect the share balance. `maxWithdraw` still returns `previewRedeem(maxRedeem(owner))`.

## Closed test fix

In `ReceiptBackedERC4626_SharedFacet.t.sol`, replace line 182 with:

```solidity
        assertEq(IERC4626(se2).maxWithdraw(u), IERC4626(se2).previewRedeem(IERC20(se2).balanceOf(u)));
```

Delete lines 185–186. A one-asset withdraw is inside that preview, so the zero-maximum rejection is the same stale cap. Leave line 183. Do not change production.

## Agreements

Astra, MiniMax, Kimi, and the earlier Grok confirmation agree production matches the ruling and the saved log was not rerun. The report's two failures are this assertion and the suite that inherits it.

## Dissent

Kimi leaves a choice between updating the assertion and removing backing. The closed fix is the assertion above. Do not change the fixture to recreate a zero cap.

I did not run Forge.
