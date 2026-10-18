# Kimi K3 — REQ-06 plan draft (replacement session)

- **Label:** Replacement-session plan draft, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read. Controlling text: `docs/reviews/apex-req-06-max-redeem/REMEDIATION_PRD.md` (55 lines, read in full; owner ruling 2026-10-17 controls: `maxRedeem` is the account's share balance; no smaller-share search, no shortfall branch, no receipt cap). Nothing was edited. This is not `REMEDIATION_PRD.plan.md`.
- **Date:** 2026-10-17.

## Spot-checks (this round)

- `ReceiptBackedERC4626Target.sol:74-81` still runs the withdrawn search (`_redeemFitsReceipts` at `:79`, `_largestRedeemableShares` at `:80`); the helpers sit at `:173-196` and have **no caller except `maxRedeem`** (repo-wide grep) — deletion is compile-safe.
- `redeem` (`:153-171`) pays `previewRedeem(shares)` via `safeTransfer` from held receipts only — no unwind. This decides the receipt-limited test's edit (below).
- The two test files match the PRD's citations: `Behavior_ReceiptBackedERC4626_CrossInterface.sol:190-213` (`test_maxRedeem_capsWhenHeldReceiptsCannotPayFullBalance`) and `:216-235` (`test_maxRedeem_zeroPreviewIsNotAdvertised`); `ReceiptBackedERC4626_SharedFacet.t.sol:168-190` (`test_R14_18_localOnlyBacking_zeroReceiptExitCapacity_exactReverts`).

## Step 1 — production: the exact `maxRedeem` body

In `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol`, replace the body of `maxRedeem` (`:74-81`) with exactly:

```solidity
    function maxRedeem(address owner) public view virtual returns (uint256) {
        _requireFamily();
        return ERC20Repo._balanceOf(owner);
    }
```

Delete `_redeemFitsReceipts` (`:173-176`) and `_largestRedeemableShares` (`:178-196`, through its closing brace) — verify the exact end line at edit time from the current file, since the PRD cites the range `:173-196`. Do not touch `maxWithdraw` (`:67-70`), `previewRedeem`, `redeem`, `withdraw`, or the NatSpec. No new selector. If `IERC20` is unused after the edit, the compiler's warnings decide nothing — leave imports alone unless compilation fails; do not tidy.

## Step 2 — the exact test assertion changes

**T1 — `Behavior_ReceiptBackedERC4626_CrossInterface.sol`, `test_maxRedeem_capsWhenHeldReceiptsCannotPayFullBalance`.** Keep the fixture and premise (`:191-201`, including `:201`'s `fullPreview > held` assertion). Replace `:202-212` (the cap computation through the payout assertions — `:212` must go with them because it references the deleted `paid`) with exactly:

```solidity
        assertEq(IERC4626(_se()).maxRedeem(_actor()), balance, "maxRedeem is the share balance");
        assertEq(IERC4626(_se()).maxWithdraw(_actor()), fullPreview, "asset cap follows the share cap");
```

Rationale recorded so no one re-litigates it: with `maxRedeem` now the balance, the old `redeem(cap)` call would attempt a payout of `fullPreview > held` against a `safeTransfer` that draws held receipts only (`ReceiptBackedERC4626Target.sol:166-168`, read this round) — it cannot survive; the PRD's receipt-limited assertions (`:204-206`, `:211`) are the ordered deletions, and the redeem block shares their premise. `maxWithdraw == fullPreview` holds by construction (`previewRedeem(maxRedeem)`).

**T2 — same file, `test_maxRedeem_zeroPreviewIsNotAdvertised`.** Replace `:233` with:

```solidity
        assertEq(IERC4626(_se()).maxRedeem(_actor()), balance, "share cap is the balance even when the preview rounds to zero");
```

`:232` (preview rounds to 0) and `:234` (`maxWithdraw == 0`, still true: `previewRedeem(balance)` is 0) are unchanged. Nothing else in the file changes.

**T3 — `ReceiptBackedERC4626_SharedFacet.t.sol`, `test_R14_18_localOnlyBacking_zeroReceiptExitCapacity_exactReverts`.**
- After `:181`, add `uint256 bal_ = IERC20(se2).balanceOf(u);`.
- Replace `:183` with `assertEq(IERC4626(se2).maxRedeem(u), bal_, "maxRedeem is the share balance");`
- Delete `:187-188` (the `redeem(1)` → `ERC4626ExceededMaxRedeem(u, 1, 0)` expectation and call), per PRD `:44`.
- Keep `:182` and `:185-186`: `maxWithdraw` is still 0 in this fixture (zero held receipts → zero preview), so the withdraw cap assertions hold unchanged.

**Preserved (PRD `:45-46`):** `test_maxRedeem_fullBalancePayableAtNonIntegralRate` (`:176-187` — already expects the balance at `:185-186`) and `APEX_D46_CapacityFixtures.t.sol:83`. `ShortRedeemERC4626` untouched. No shortfall test is added anywhere.

**Recorded note, not an edit:** the two Behavior-file test names (`capsWhenHeldReceiptsCannotPayFullBalance`, `zeroPreviewIsNotAdvertised`) describe the withdrawn rule. The PRD orders no rename; leave them. Flagging for the coordinator as documentation debt, not scope.

## Step 3 — one command

The production file is the positional edited source; the erc4626 spec directory covers both edited test surfaces (the Behavior base runs through its concrete consumers). From the repository root, warm `out/`/`cache_forge/`, no `via_ir`:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol \
  --test-root test/foundry/spec/vaults/standard/erc4626 \
  -- -vv
```

The whole directory runs green. If the new `maxRedeem` assertions fail — or any existing test fails on the deleted helpers' disappearance — stop and report the test and the actual values; do not reintroduce a search, a cap, or a shortfall branch to make it pass.

## Stop rule

If any cited line (`ReceiptBackedERC4626Target.sol:74-81,:173-196`; Behavior `:190-213,:216-235`; SharedFacet `:168-190`) has drifted at edit time, stop and report the file and line. Choose nothing.

I did not run Forge.
