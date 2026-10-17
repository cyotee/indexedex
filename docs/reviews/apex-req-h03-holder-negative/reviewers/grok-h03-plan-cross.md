# Grok plan cross-review — REQ-H03

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-16
- **Peers read:** `astra-h03-plan.md`, `minimax-h03-plan.md`, `kimi-h03-plan.md`

Peer notes are untrusted. This file does not authorize an edit.

## Closed plan

No implementer choice. Use this plan. Do not add a Crane test file.

### Production

Replace only `ERC20Repo._burn(Storage, address, uint256)` with:

```solidity
function _burn(Storage storage layoutStruct, address account, uint256 amount) internal {
    uint256 currentBalance = layoutStruct.balanceOf[account];
    if (currentBalance < amount) {
        revert IERC20Errors.ERC20InsufficientBalance(account, currentBalance, amount);
    }
    layoutStruct.balanceOf[account] = currentBalance - amount;
    layoutStruct.totalSupply -= amount;
    emit IERC20Events.Transfer(account, address(0), amount);
}
```

The `IERC20Errors` import is already present. Do not call `_decreaseBalanceOf`. Do not change `_mint`, `_transfer`, `_decreaseBalanceOf`, or the default overload. Stop if the current body is not the commented helper call plus the inline balance subtraction.

### Tests

Add `import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";` to each of these three files. Change no other test.

- V3 `UniswapV3FullSpreadVaultHeldRedeem.t.sol:147`: `vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, holder, 0, 1));`
- ERC-4626 `ERC4626StandardExchange_Routes.t.sol:271`: `vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, seBal, seBal + 1));` Remove the `stdError` import. Replace the comment's arithmetic-panic phrase with `` `ERC20Repo._burn` reverts `ERC20InsufficientBalance` ``.
- Lido `Adversarial_LidoWstETH_P0.t.sol:237`: before `vm.prank(attacker)`, set `uint256 burnAmount = seOut.previewExchangeOut(IERC20(seVault), IERC20(address(hermeticWeth)), 1 ether);` Expect `IERC20Errors.ERC20InsufficientBalance.selector` with `attacker, attackerBefore, burnAmount`. Do not use `type(uint256).max`.

### Pointer

`lib/crane` is a submodule. `scripts/submodule-commit.sh` runs `git add -A` and pushes submodules. Do not run it unless the Crane tree contains only `contracts/tokens/ERC20/ERC20Repo.sol` and the IndexedEx tree contains only the three test files plus the `lib/crane` gitlink. If `git -C lib/crane rev-parse --abbrev-ref HEAD` prints `HEAD`, stop. Do not checkout a branch. Do not run `scripts/sync-crane-skills.sh`.

### Command

```bash
python3 scripts/forge-artifacts.py test lib/crane/contracts/tokens/ERC20/ERC20Repo.sol --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol --test-root test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol --test-root test/foundry/spec/protocol/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol -- -vv
```

There is no Crane burn-test command. If this run, or any other short-burn test, shows different revert bytes, stop and report them. Do not expand the change set. Do not enable `via_ir`. Do not delete `out/` or `cache_forge/`.

## Coordinator notes

- Confirmed. Lido `exchangeOut` burns `_quoteExactOut(in_, out_, amountOut, pretransferred)`. The test passes `false`, so the burned amount is that quote. `type(uint256).max` is only `maxAmountIn`. The 3-argument `_quoteExactOut` calls the 4-argument quote with `false`.
- Confirmed. `stdError` in `ERC4626StandardExchange_Routes.t.sol` appears only in the import and at line 271.
- Confirmed. The PRD does not require a new Crane test file.
- Confirmed. `scripts/submodule-commit.sh` stages everything and pushes submodules. It must not run on a wider tree. Detached `HEAD` stops.
- Confirmed. A newly failing short-burn test is reported. It is not added to this change set.

## Agreements

All four drafts use the same `_burn` body and the same V3 and ERC-4626 selector arguments. Astra, Kimi, and the earlier Grok draft use the Lido preview amount. All four leave the sqrt, quote-overflow, and `0x12` expectations unchanged.

## Dissent

- MiniMax is wrong that Lido burns `type(uint256).max`. That would expect a different amount.
- MiniMax is wrong that `stdError` remains used. Remove that import.
- MiniMax's directory command and its instruction to update newly failing tests expand the change set. Do not do that.
- MiniMax says no script governs the pointer and leaves a branch, remote, and push choice. Use `scripts/submodule-commit.sh` only after the dirty-tree and detached-HEAD stops.
- Astra's new `ERC20Repo_Burn.t.sol` is not in the PRD. Do not create it. Do not run Astra's Crane `forge test` for that file.
- Kimi's `FOUNDRY_PROFILE=ci` ERC-20 suite is not a named short-burn test. Do not run it for this item.
- Kimi hardcodes Lido balance `0`. Use the captured `attackerBefore`.

I did not run Forge.
