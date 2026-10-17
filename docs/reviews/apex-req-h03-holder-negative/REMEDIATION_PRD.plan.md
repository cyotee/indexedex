# Implementation plan — REQ-H03 short-burn error

- **Date:** 2026-10-16
- **Status:** Source steps executed. The pointer step stopped at gate 3, which this plan allows. Confirmation: `docs/reviews/apex-req-h03-execution-confirmation/REMEDIATION_PRD.md`. Writing this plan did not authorize implementation.
- **Controlling PRD:** [REMEDIATION_PRD.md](./REMEDIATION_PRD.md). Where this plan conflicts with that PRD, the PRD controls.
- **ID:** REQ-H03.
- **Council:** Astra replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi` does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Grok `ses_ec4128917ffeeVds3Y2p7xrVjp`. MiniMax replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t` does not recall `ses_ebdf718feffemWQNf7wuTpapqX`. Kimi replacement `ses_ec3d04e91ffeJa0is24e2jZv06` does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. Astra was not censored. No Forge run. Consensus is not proof.

## What to do

Replace the storage `_burn` body so a short balance reverts `ERC20InsufficientBalance` before any write. Update the three existing short-burn expectations named below. Do not add a test file.

## What not to do

- Do not call `_decreaseBalanceOf`. Do not add an `address(0)` rejection.
- Do not change `_mint`, `_transfer`, `_decreaseBalanceOf`, or the address overload of `_burn`.
- Do not add a `catch` or a supply-short error. A later supply subtraction may still panic.
- Do not edit the withdrawn V4 twin.
- Do not add `lib/crane/test/foundry/spec/tokens/ERC20/ERC20Repo_Burn.t.sol` or any other new test.
- Do not change a panic or bare revert that is not a short `ERC20Repo` burn.
- Do not enable `via_ir`. Do not delete `out/` or `cache_forge/`.
- Do not run `scripts/sync-crane-skills.sh`.
- If another short-burn test fails, stop and report it. Do not add it to this change set.

## Step 1 — burn body

File: `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol`.

Stop if `_burn(Storage, address, uint256)` is not the commented `_decreaseBalanceOf` call plus `layoutStruct.balanceOf[account] -= amount`.

Replace that function with:

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

Keep the existing NatSpec and include tags. The `IERC20Errors` import at line 10 already exists. Do not add another import.

## Step 2 — three expectations

Add this import to each of the three files:

```solidity
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
```

### V3 holder

File: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol`.

Replace line 147 with:

```solidity
vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, holder, 0, 1));
```

Leave the redeem call and the three balance assertions unchanged.

### ERC-4626 owner burn

File: `test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol`.

`stdError` is used only at line 271. Remove `import {stdError} from "forge-std/StdError.sol";`.

Replace the comment phrase `` `ERC20Repo._burn` underflows: arithmetic panic `` with `` `ERC20Repo._burn` reverts `ERC20InsufficientBalance` ``.

Replace line 271 with:

```solidity
vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, seBal, seBal + 1));
```

Leave the call and the rollback assertions unchanged.

### Lido missing shares

File: `test/foundry/spec/protocol/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol`.

The false-flag exact-out burns the quoted amount, not `type(uint256).max`. Immediately before the `vm.prank(attacker)` that precedes line 237, add:

```solidity
uint256 requiredShares = seOut.previewExchangeOut(
    IERC20(seVault), IERC20(address(hermeticWeth)), 1 ether
);
assertGt(requiredShares, attackerBefore, "exact-output burn exceeds holder shares");
```

Replace line 237 with:

```solidity
vm.expectRevert(
    abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientBalance.selector, attacker, attackerBefore, requiredShares
    )
);
```

Replace the trailing comment with `named balance error rejects missing shares`. Leave the `exchangeOut` call and the later assertions unchanged. If the preview reverts, stop and report those bytes.

## Step 3 — pointer

`lib/crane` is a submodule. `scripts/submodule-commit.sh` runs `git add -A` and pushes submodules. It does not push IndexedEx. Run it only after all four gates pass:

1. `git -C lib/crane rev-parse --abbrev-ref HEAD` does not print `HEAD`. If it does, stop. Do not checkout a branch.
2. Crane status shows only `contracts/tokens/ERC20/ERC20Repo.sol`.
3. IndexedEx status shows only the three test files in Step 2 and the `lib/crane` gitlink.
4. Then run `./scripts/submodule-commit.sh -m "fix: name short ERC20 burn as ERC20InsufficientBalance"`.

If any gate fails, stop. Do not commit or push unrelated files.

## Step 4 — one Forge command

From the IndexedEx root:

```bash
python3 scripts/forge-artifacts.py test \
  lib/crane/contracts/tokens/ERC20/ERC20Repo.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol \
  --test-root test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol \
  --test-root test/foundry/spec/protocol/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol \
  -- -vv
```

Run the whole files. Do not filter to one test name. There is no Crane burn-test command. No Crane short-burn test was found.

If a named site reverts with different bytes, stop and report those bytes. Do not broaden the expectation and do not edit production beyond Step 1.

Record the command, exit status, and output in `EXECUTION_REPORT.md`. A saved log is not an independent reviewer rerun.

## Done when

- The storage burn reads the balance, reverts the named error when it is short, then decreases that balance once, decreases supply, and emits the existing burn transfer.
- The three named tests expect that error with the arguments in Step 2.
- The unused `stdError` import is gone.
- The one Forge command has been run and its result recorded.
- The Crane revision and the IndexedEx gitlink were delivered together, or the pointer step stopped on a named gate.
