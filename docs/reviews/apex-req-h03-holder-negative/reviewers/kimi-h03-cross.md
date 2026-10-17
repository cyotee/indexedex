# Kimi K3 — cross-review: REQ-H03 holder negative

- **Label:** Replacement-session cross-review, resuming my REQ-H03 original (`kimi-h03.md`). I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. MiniMax is the labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. The coordinator's note was treated as untrusted instruction-level evidence and every line in it was re-read against current source before acceptance. The three peer originals were read in full. Nothing was edited.
- **Date:** 2026-10-16. I did not run Forge.

## Verdict: I dissent from my own original. The coordinator's note is confirmed on every point, and Astra and Grok are correct.

### Confirmed by my own re-reads this round

1. **Route:** `UniswapV3FullSpreadStandardYieldExecutionTarget.sol:18-24` — the override routes a self-share, non-internal redeem to `_settleNamedHolder(…, msg.sender)` at `:22`, which calls `_executeZapOutExactIn(…, holder_)` at `:29`. **`BasicVaultCommon._secureSelfBurn` is not this route** — my original's step 3 was wrong, and with it my error selection.
2. **Burn site:** `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:236` (sleeve branch) and `:257` (free branch) — both `ERC20Repo._burn(holder_, sharesBurned)` with no preceding holder-balance guard (the quote steps compute against the vault's book, not the holder's balance; verified `:215-261`).
3. **Burn semantics:** `ERC20Repo.sol:360-364` — the `_decreaseBalanceOf` call is commented out at `:361`; `:362` is the raw checked subtraction `layoutStruct.balanceOf[account] -= amount`. My original's citation of `:229` (`ERC20InsufficientBalance`) describes `_decreaseBalanceOf` (`:222-232`), which `_burn` does not call. Under Solidity 0.8 checked arithmetic, `0 - 1` reverts **`Panic(uint256)` with code `0x11`**. My original's named error was refuted by the very file I cited.

### The closed alternative (required since I dissent)

Replace `UniswapV3FullSpreadVaultHeldRedeem.t.sol:147` (`vm.expectRevert();`) with exactly:

```solidity
vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", uint256(0x11)));
```

No import is needed. Everything else in the test is untouched: the call at `:148`, and the holder/vault/recipient unchanged-balance assertions at `:149-151`. No production edit, no `catch`, no weakened burn, no substitute caller, nothing for the withdrawn V4 twin. This is Astra's and Grok's shared answer, and my re-trace independently lands on it.

### On MiniMax's original

MiniMax's headline names `ERC20InsufficientBalance(holder, 0, 1)` — but its own §3 (`:67-82`) documents that `_burn`'s guard is commented out and the actual revert is `Panic(0x11)`, and proposes restoring the guard as "a separate item." A test written to MiniMax's headline fails against current production: the PRD scopes REQ-H03 to the test oracle and forbids the production edit that would make MiniMax's expectation pass. The internal contradiction resolves against the headline: for this item, the expected error is the one current production actually raises. (If the owner later wants the named error restored, uncommenting `ERC20Repo.sol:361` is a separate, explicitly authorized production decision — not this item.)

### Carried limits

- Astra's stated limit is adopted: `Panic(0x11)` does not uniquely identify a source line — another arithmetic failure could match. The fixture's funded-holder twin (`:105-122`) passes the same route, so for this test the only step sensitive to holder balance is the burn; combined with the unchanged-balance assertions, the identification is adequate. If the implementation run shows different revert bytes, stop and report; do not substitute.
- My original's "corroborating precedent" (`TestBase_FullSpreadG5GuardClosure.sol:360` expecting `ERC20InsufficientBalance`) is consistent, not contradictory: that surface exercises the guarded transfer/decrease path, not `_burn`. It does not support my original's claim on this route.

## Corrections recorded

My `kimi-h03.md` named the wrong error on a wrong route (BasicVaultCommon + `ERC20Repo.sol:229`). The corrected trace above supersedes it; the original file stays as written for the record. Consensus is not proof — but here the mechanism was verified line-by-line in current source: `YieldExecutionTarget:22`, `InBase:236/:257`, `ERC20Repo:361-362`.

I did not run Forge.
