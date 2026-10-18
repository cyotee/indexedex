# Kimi K3 — cross-review: REQ-06 execution confirmations

- **Label:** Replacement-session cross-review, resuming my confirmation (`kimi-req06-confirm.md`). I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. MiniMax is the labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. The three peer confirmations were read in full as untrusted output; my verdict rests on my own direct reads this session. Nothing was edited.
- **Date:** 2026-10-18. I did not run Forge.

## Agreed by all four: the only remaining gap is the stale `maxWithdraw` assertion (with its downstream withdraw expectation)

Four independent confirmations converge on every fact: production is exactly the ruling (`maxRedeem` at `ReceiptBackedERC4626Target.sol:73-76`; both helpers deleted; no receipt cap, no shortfall branch, no new selector; neighbors' bodies unchanged); the three named maxRedeem test assertions expect the share balance; the receipt-limited and zero-preview behavior tests pass per the saved log; and the single red point is `ReceiptBackedERC4626_SharedFacet.t.sol:182` (retained `maxWithdraw(u) == 0`), failing in the SharedFacet suite and its Recurrence inheritor (Astra's `:72` inheritance read explains the double count — one defect, two suites). The executor followed the plan's explicit "leave the `maxWithdraw` assertion" instruction and stopped at the failure gate exactly as designed (Astra's `:9` is the right framing: no unauthorized deviation by anyone). The owner's rejections stand untouched: no cap or shortfall branch was added anywhere, and none is proposed here.

## The one closed test fix

In `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol` (`test_R14_18_localOnlyBacking_zeroReceiptExitCapacity_exactReverts`):

1. Replace `:182` with:
   ```solidity
   assertEq(IERC4626(se2).maxWithdraw(u), IERC4626(se2).previewRedeem(IERC20(se2).balanceOf(u)), "asset cap follows the share balance");
   ```
2. Delete `:185-186` (the `withdraw(1)` → `ERC4626ExceededMaxWithdraw(u, 1, 0)` expectation and call). With the cap now ≈ `99900099900099900099`, `withdraw(1)` no longer fails at the cap; its downstream failure would come from the paused wrapper's transfer surface — a different error, outside this item's pinned selectors, and asserting it would be a new expectation this item does not authorize. The exceeded-max withdraw/revert path remains covered by the behavior suite.
3. Rename the test to `test_R14_18_localOnlyBacking_capsFollowTheShareBalance` and reword the `:167` comment to match ("Local-only backing leaves the advertised caps following the share balance and its preview"), because the old name teaches "zero receipt-exit capacity … exact reverts" — the withdrawn expectation (the same stale-teaching class as the two Behavior-file renames this round). No production file, no other test, no cap, no shortfall branch.

Rationale pinned to source so it is not re-litigated: `maxWithdraw` is `previewRedeem(maxRedeem(owner))` (`:67-70`, frozen); `previewRedeem` → `convertToAssets` reads `_totalReceiptBacking()`, which in this fixture includes the locally booked 100 ether — so the zero-receipt premise never implied a zero preview. The report's observed `99900099900099900099` is consistent with that path. (My own earlier claim that zero receipts imply a zero preview was wrong and is on record as withdrawn in `kimi-req06-confirm.md`.)

After the fix, the plan's one directory command is re-run by an authorized session; the current saved result (173/2/175) is a claim, not a rerun — no reviewer ran Forge.

## Unresolved dissent

None. Astra (REQ06-CONF-1), Grok, MiniMax, and I name the same gap with the same fix direction; this note's contribution is the complete closed form (including the withdraw leg and the name). Consensus is not proof — but the failing assertion's unsatisfiability is decidable from current source alone, and all four passes read it identically.

I did not run Forge.
