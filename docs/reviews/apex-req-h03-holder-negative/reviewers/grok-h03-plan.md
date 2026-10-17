# Grok plan draft — REQ-H03

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-16
- **Controlling text:** `docs/reviews/apex-req-h03-holder-negative/REMEDIATION_PRD.md`
- **Headline:** No implementer choice.

This draft does not authorize an edit. Do not edit the withdrawn V4 twin. Do not enable `via_ir`. Do not delete `out/` or `cache_forge/`. Do not run `scripts/sync-crane-skills.sh`.

## 1. Production burn

Edit only `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol` function `_burn(Storage storage, address, uint256)` at lines 360–365. The import of `IERC20Errors` at line 10 already exists. Do not add another import. Do not change `_mint`, `_transfer`, `_decreaseBalanceOf`, or the default `_burn(address, uint256)` at line 376.

Replace the whole function with:

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

Delete the commented `_decreaseBalanceOf` call and the inline `balanceOf[account] -= amount`. Do not call `_decreaseBalanceOf`. That helper also reverts `ERC20InvalidSender` for `address(0)`, and this item does not add that check. Do not add a `catch` or a supply-short error. A later supply subtraction may still panic. Stop if the current body is not the commented helper call plus `layoutStruct.balanceOf[account] -= amount`.

## 2. Tests that expect a short `ERC20Repo` burn

These three tests expect a panic or a bare revert for a short `ERC20Repo._burn`. Change only those expectations. Do not change a test whose revert is a different error.

### 2.1 V3 insufficient holder

File: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol`

Add this import after the existing `IERC20` import:

```solidity
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
```

Replace line 147 with:

```solidity
vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, holder, 0, 1));
```

Leave the redeem call and the three balance assertions unchanged. Leave the code-less ordinary-success tests unchanged.

### 2.2 ERC-4626 owner burn

File: `test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol`

`test_O7_ownerBurn_insufficientBalance_revertsAndRollsBack` burns `seBal + 1` from `user` through `ERC20Repo._burn`. Line 271 expects `stdError.arithmeticError`. `stdError` is imported only for that line.

Add:

```solidity
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
```

Remove `import {stdError} from "forge-std/StdError.sol";`.

Replace the comment's phrase `` `ERC20Repo._burn` underflows: arithmetic panic `` with `` `ERC20Repo._burn` reverts `ERC20InsufficientBalance` ``.

Replace line 271 with:

```solidity
vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, seBal, seBal + 1));
```

Leave the call and the three rollback assertions unchanged.

### 2.3 Lido missing shares

File: `test/foundry/spec/protocol/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol`

Line 237 expects `Panic(uint256)` argument `0x11` for a burn. `LidoWstETHStandardExchangeCommon._burnShares` calls `ERC20Repo._burn(msg.sender, shares)`. The burned amount is the exact-out quote, not `type(uint256).max`.

Add:

```solidity
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
```

Immediately before the existing `vm.prank(attacker)` that precedes line 237, add:

```solidity
uint256 burnAmount = seOut.previewExchangeOut(IERC20(seVault), IERC20(address(hermeticWeth)), 1 ether);
```

Replace line 237 with:

```solidity
vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, attacker, attackerBefore, burnAmount));
```

`previewExchangeOut` uses `_quoteExactOut(..., false)`, the same quote `exchangeOut` uses when `pretransferred` is false. Use the existing `attackerBefore`. Do not substitute `type(uint256).max` or a guessed share amount. If that preview reverts, stop and report those bytes.

## 3. Tests left unchanged

No Crane test expects `Panic(uint256)` `0x11` or a bare revert for a short `ERC20Repo` burn. Do not add one. Do not run a Crane burn suite.

Leave these expectations. They are not a short `ERC20Repo` burn:

- Aerodrome `test_sqrt_maxUint256_reverts` arithmetic panic.
- Residual-preview quote panic.
- Wings reference `Panic(uint256)` `0x12`.
- V4 held-redeem `EOAPretransferNotAllowed`.
- ERC-4626 decimals bare reverts for zero amount, free mint, and slippage.
- Crane permit bare reverts.

## 4. Crane pointer

`lib/crane` is the submodule in `.gitmodules`. After the source edit:

1. If `git -C lib/crane rev-parse --abbrev-ref HEAD` prints `HEAD`, stop. Do not checkout a branch.
2. If the Crane status shows any path other than `contracts/tokens/ERC20/ERC20Repo.sol`, stop.
3. If the IndexedEx status shows any path other than the three test files in section 2 and the `lib/crane` gitlink, stop.
4. Otherwise run `./scripts/submodule-commit.sh -m "fix: name short ERC20 burn as ERC20InsufficientBalance"`.

That script commits and pushes the Crane change, then commits the IndexedEx pointer. It does not push IndexedEx. Do not run `scripts/sync-crane-skills.sh`.

## 5. Commands

Run these from the IndexedEx root, in this order. If a run reverts with different bytes, stop and report those bytes. Do not broaden the expectation.

```bash
python3 scripts/forge-artifacts.py test lib/crane/contracts/tokens/ERC20/ERC20Repo.sol --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol -- -vv
```

```bash
python3 scripts/forge-artifacts.py test lib/crane/contracts/tokens/ERC20/ERC20Repo.sol --test-root test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol -- -vv
```

```bash
python3 scripts/forge-artifacts.py test lib/crane/contracts/tokens/ERC20/ERC20Repo.sol --test-root test/foundry/spec/protocol/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol -- -vv
```

There is no Crane burn-test command. None was found.

I did not run Forge.
