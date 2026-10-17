# Grok cross-review — REQ-03

- **Date:** 2026-10-14
- **Originals read:** Astra, MiniMax M3, Kimi K3. Untrusted. Stage-1 REQ-03 controls.
- **Own first pass:** the reentrancy bullet is revised from already satisfied to partial. The fuzz and scanner positions are narrowed below.

## 1. Reentrancy bullet is partial

**Agree with Astra, MiniMax, and Kimi. Dissent from my first-pass "already satisfied."**

`observeNestedDeposit` asserts `IsLocked` and then reverts (`RebasingAwareERC4626_Adversarial.t.sol:28-32`). The file's own comment says a wrong nested error fails inside the reverted frame and the vault then reports `TransferFromFailed` (`:26-27`). The outer test expects that same selector (`:140`). The harness bubbles the callback failure (`ReentrantERC20Harness.sol:68-74`). A wrong nested reason, or a failed assertion about that reason, can still become the outer error the test accepts. The no-partial-credit assertions at `:143-146` do not repair that.

The Crane `SafeTransferLib` lines Astra cites were not re-read. The tool denied that path. The test comment and the harness bubble are enough for this conclusion.

**Dissent from MiniMax G2's fix.** Do not change the harness so `transferFrom` succeeds and the outer `expectRevert` pins `IsLocked`. The production pull wraps the token failure. Keep that outer error. Record the nested `(ok, reason)` where the wrap cannot erase it, and assert `IsLocked` after the outer call. That is Astra's and Kimi's repair. Do not weaken the bytecode check. Do not use a broader `expectRevert()`.

## 2. Fuzz success must also assert total supply

**Agree with Astra. Dissent from MiniMax and Kimi that the success half is already complete.**

REQ-03 requires exact shares, balances, and reserves on success. The rejection half already asserts total supply (`RebasingAwareERC4626_Fuzz.t.sol:81`). The success half asserts the recipient's shares, the paid amount, both asset balances, and the reserve (`:96-100`). It does not assert total supply, although `supplyBefore` was captured at `:65`. Recipient credit alone does not constrain an extra mint. Add `totalSupply == supplyBefore + shares` on the success path. Do not rewrite the rejection half or the existing exact assertions.

## 3. Scanner gap is confirmed for the cited files, not a full inventory

**Agree with Kimi that the cited files escape the current selection. Agree with Astra that this is not a complete missing-file list. Dissent from treating the gap as unverified only. Dissent from MiniMax G4's demand to enumerate every D16 family before the inventory is defined.**

The script selects two roots, two named custody files, and APEX-marked files (`apex_bare_expectrevert_scan.sh:14-26`). Re-read confirms bare `vm.expectRevert()` at `ERC4626StandardExchange_Routes.t.sol:332` and `:335`, and at `RebasingAwareERC4626_Accounting.t.sol:131` and `:143`. Those paths are outside the two roots and are not the two named custody files. That confirms the selection rule misses those files. It does not define the full D16 R2.4 inventory. Do not invent that list. The locked plan and the R2.4 evidence bundle are the documents that would define it. A later repair may add only files that inventory names.

## Unresolved

Whether a failed nested assertion is actually swallowed by the installed Forge runner was not executed. The source shape and the test comment are enough to keep the bullet partial. No Forge run settles it here.

I did not run Forge.
