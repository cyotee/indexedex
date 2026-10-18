# Kimi K3 — REQ-06 requirements check: is an owner question left? (replacement-session original)

- **Label:** Replacement-session original, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read (a grep for the helper names incidentally listed peer files in this directory; none were opened or used). Nothing was edited. I did not run Forge.
- **Controlling text:** `docs/reviews/apex-req-06-max-redeem/REMEDIATION_PRD.md` (55 lines, read in full). Owner ruling 2026-10-17 (`:17-19`): `maxRedeem` is the account's share balance; no smaller-share search, no shortfall case; the claimable value follows the deployed reserve; no receipt cap is reintroduced.
- **Date:** 2026-10-17.

## Answer: No blocking question. Ready.

The draft is closed against current source:

**REQ-06-1 (production).** The current body at `ReceiptBackedERC4626Target.sol:74-81` still contains the withdrawn search — `_redeemFitsReceipts` at `:79`, `_largestRedeemableShares` at `:80` — matching the PRD's premise. The two helpers exist at `:173` and `:179` and, by repo-wide grep this round, have **no caller anywhere except `maxRedeem`** (the only other hits are documents). So "delete the helpers" is compile-safe and choice-free, the replacement body is a single pinned statement (`return ERC20Repo._balanceOf(owner);` after `_requireFamily()`), and the frozen neighbors (`previewRedeem`, `maxWithdraw`, `redeem`, `withdraw`; no new selector) are named. Nothing remains to decide.

**REQ-06-2 (tests).** Both files are named with exact lines (`Behavior_ReceiptBackedERC4626_CrossInterface.sol:202-211,:233`; `ReceiptBackedERC4626_SharedFacet.t.sol:183,:187-188`), the instruction is fixed (assert balance equality; delete the reduced-cap/zero-cap assertions and the `ERC4626ExceededMaxRedeem`-with-0 expectation), and the two exclusions are named (`test_maxRedeem_fullBalancePayableAtNonIntegralRate` stays; `APEX_D46_CapacityFixtures.t.sol:83` is a different contract). Closed.

**Ruling conformity.** Nothing in the draft searches smaller shares, branches on a shortfall, or reintroduces a receipt cap; the dissent note (`:49-51`) records the withdrawn reading honestly. The ruling's "claimable value follows the deployed reserve" needs no test or code consequence in this item because `maxWithdraw`/`previewRedeem` are frozen — the PRD says so.

**Non-question, recorded per the assignment's rule:** after the body collapses, the receipts read at `:78` disappears with it; whether the `IERC20` import remains used elsewhere in the file is a compile-level mechanical detail, not an owner question.

I did not run Forge.
