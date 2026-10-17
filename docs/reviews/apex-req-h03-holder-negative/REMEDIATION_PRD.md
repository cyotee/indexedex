# Remediation PRD — REQ-H03 insufficient-holder negative

- **Status:** DRAFT
- **Date:** 2026-10-16
- **ID:** REQ-H03
- **Review target:** `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:360-365` and `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol:147`
- **Inputs:** `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md` REQ-H03. Owner ruling, 2026-10-16: add a balance check and revert `ERC20InsufficientBalance` when the balance is insufficient. No separate implementation plan or audit report was supplied.
- **Astra participation:** Substantive first pass and cross-review on the earlier test-only reading. Labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi`. It does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored. This owner ruling was not sent back through the council.
- **Grok:** `ses_ec4128917ffeeVds3Y2p7xrVjp`.
- **MiniMax M3:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. It does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Kimi K3:** Labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`.
- **Runtime:** No Forge run. Source was read. Consensus is not proof.

Writing this PRD does not authorize implementation.

## Required outcome

A short burn raises the named ERC-20 balance error. The V3 insufficient-holder test expects that error. The burn still removes the shares and still reduces supply when the balance is sufficient.

## Owner ruling

On 2026-10-16 the owner rejected the panic-only test change. A vault share is an ERC-20. A short balance must revert `ERC20InsufficientBalance`. The earlier instruction to expect `Panic(uint256)` with argument `0x11`, and to leave `ERC20Repo._burn` unchanged, is withdrawn.

## REQ-H03-1 — Name the short-burn error

- **Severity:** Low
- **File and line:** `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:360-365`. The V3 route reaches this burn from `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:236` and `:257`.
- **Intended behavior:** If `balanceOf[account] < amount`, revert `IERC20Errors.ERC20InsufficientBalance(account, balance, amount)`. The error is the one declared at `lib/crane/contracts/tokens/ERC20/IERC20Errors.sol:16`. `ERC20Repo` already imports it through `@crane/contracts/interfaces/IERC20Errors.sol`.
- **Broken requirement or invariant:** `_burn` comments out `_decreaseBalanceOf` and uses `balanceOf[account] -= amount`. Solidity 0.8 turns a short balance into `Panic(uint256)` argument `0x11`. That is not the ERC-20 balance error.
- **Acceptance criteria:**
  - In `_burn(Storage, address, uint256)`, read `currentBalance` before changing storage.
  - If `currentBalance < amount`, revert `IERC20Errors.ERC20InsufficientBalance(account, currentBalance, amount)`.
  - If the check passes, set `balanceOf[account] = currentBalance - amount`, then subtract `amount` from `totalSupply`, then emit the existing `Transfer` to `address(0)`.
  - Delete the commented `_decreaseBalanceOf` call and the inline `balanceOf[account] -= amount`. Do not keep both, or the balance would be decreased twice.
  - Do not call `_decreaseBalanceOf`. That helper also reverts `ERC20InvalidSender` for `address(0)`. This item does not add that check.
  - Do not change `_mint`, `_transfer`, or `_decreaseBalanceOf`.
- **Non-goals:** Do not weaken the burn. Do not add a `catch`. Do not add a separate supply-short error. A supply subtraction that is shorter than the checked balance may still panic. Do not edit the withdrawn V4 twin. Do not treat this as evidence that the holder argument is wrong.

## REQ-H03-2 — Expect that error in the V3 test

- **Severity:** Low
- **File and line:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol:147`
- **Intended behavior:** The insufficient-holder test identifies this balance error. Holder, vault, and recipient balances stay unchanged.
- **Broken requirement or invariant:** Line 147 is bare `vm.expectRevert()`.
- **Acceptance criteria:**
  - Import `IERC20Errors` from `@crane/contracts/interfaces/IERC20Errors.sol`.
  - Replace line 147 with `vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, holder, 0, 1));`.
  - Leave the redeem call and the three balance assertions unchanged.
  - Leave the code-less ordinary-success tests unchanged. Do not substitute a contract caller.
  - If the run reverts with different bytes, stop and report those bytes. Do not broaden the expectation.
- **Non-goals:** Do not expect `Panic(uint256)`. Do not edit the withdrawn V4 twin.

## Dissent

The earlier council cross-review agreed on a test-only panic expectation because that matched the uncommented burn. The owner ruling supersedes that agreement. MiniMax and Kimi first named this ERC-20 error, then retracted it to match the current burn. That retraction does not survive this ruling.

## Unverified

This review did not run Forge. No trace confirmed that the funded fixture reaches the burn before another revert. If it does not, stop and report the actual bytes.
