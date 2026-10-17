# Kimi K3 — REQ-H03 plan draft (replacement session)

- **Label:** Replacement-session plan draft, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read. Controlling text: `docs/reviews/apex-req-h03-holder-negative/REMEDIATION_PRD.md` (owner ruling 2026-10-16 controls: restore the named ERC-20 error in `_burn`; the panic-expectation reading is withdrawn). Nothing was edited. This is not `REMEDIATION_PRD.plan.md` and authorizes nothing.
- **Date:** 2026-10-16.

## 1. Production edit — `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:360-365`

Replace the whole `_burn(Storage, address, uint256)` body with exactly (PRD `:31-36`):

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

The commented `_decreaseBalanceOf` line and the inline `-=` are deleted; `_decreaseBalanceOf` is **not** called (it would add an `ERC20InvalidSender` check this item excludes); `_mint`, `_transfer`, `_decreaseBalanceOf` untouched; the supply subtraction stays as-is (the supply-short panic residual is the PRD's stated non-goal). `IERC20Errors` already resolves in this file (`:229` uses it). The `address` overload at `:376` delegates — no edit.

**Crane mechanics:** `lib/crane` is a submodule. Edit the Crane source repository, land the change there, then update the IndexedEx `lib/crane` gitlink with the repository's existing submodule process (`scripts/submodule-commit.sh`, as used for REQ-SEP-04's C8). Do not run `sync-crane-skills.sh`. Do not enable `via_ir`. Do not delete `out/` or `cache_forge/`.

## 2. The swept test edits — every short-`ERC20Repo._burn` panic/bare-revert expectation

Sweep method: repo-wide greps for `Panic(uint256)` 0x11, `stdError.arithmeticError`, and bare `vm.expectRevert();`, then context reads of every hit. Of all hits, exactly three are short-burn negatives; the rest are a sqrt-overflow harness (Aerodrome `Fuzz.t.sol:339`, `Fuzz_Decimals.sol:343`), a quote-propagation harness (`…_ResidualPreview.t.sol:101,117,160`), fail-closed deposit/disable/deploy negatives (the 20 rebasingVault/factory/oracle bare reverts), transfer/allowance negatives on the guarded path (Crane `TestBase_ERC20.sol:64,127` — unaffected), and a 0x12 conversion panic (Wings reference). None of those is edited.

**T1 (the PRD target)** — `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol`:
- Add `import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";`.
- `:147` → `vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, holder, 0, 1));`
- Nothing else in the file changes.

**T2 (sweep)** — `test/foundry/spec/protocol/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol:237` ("checked burn rejects missing shares"): a false-flag share-input exact-out burns the quoted `used` from `attacker`, who holds 0 SE shares. Edit:
- Add the same `IERC20Errors` import.
- Before `vm.prank(attacker);` at `:236`, capture the quoted burn: `uint256 used_ = seOut.previewExchangeOut(IERC20(seVault), IERC20(address(hermeticWeth)), 1 ether);` (false-flag exact-out burns exactly the quoted used; all names are already in scope).
- `:237` → `vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, attacker, 0, used_));` and reword the trailing comment to "named balance error rejects missing shares".

**T3 (sweep)** — `test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol:271` (R7.5, documented as an arithmetic panic at `:262-264`): the owner burn of `seBal + 1` against balance `seBal`. Edit:
- Add the same `IERC20Errors` import.
- `:271` → `vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, seBal, seBal + 1));`
- Update the `:262-264` comment: replace "`ERC20Repo._burn` underflows: arithmetic panic" with "`ERC20Repo._burn` reverts `ERC20InsufficientBalance`". If `stdError` is then unused in the file, remove that now-dead reference; otherwise leave it.

No other test file is touched. Tests for a different error are untouched, per the assignment.

## 3. The two commands

**IndexedEx (the V3 file, plus the two swept files — same item, same production edit):** from the IndexedEx repository root, warm `out/` and `cache_forge/`:

```bash
python3 scripts/forge-artifacts.py test \
  lib/crane/contracts/tokens/ERC20/ERC20Repo.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol \
  --test-root test/foundry/spec/protocol/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol \
  --test-root test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol \
  -- -vv
```

(The positional is the edited source, per the REQ-SEP-01 command ruling; each `--test-root` is auto-treated as a consumer.)

**Crane burn tests:** the sweep found **no** Crane-side short-burn negative (Crane's `TestBase_ERC20` balance negatives are transfer/transferFrom on the guarded path; `ERC20Target_EdgeCases.t.sol` has no burn case). So no Crane test is edited; the named Crane command is the ERC20 regression suite, run from the Crane repository root:

```bash
FOUNDRY_PROFILE=ci forge test --match-path 'test/foundry/spec/tokens/ERC20/*' -vv
```

## 4. Stop rules

- If any run reverts with bytes other than `ERC20InsufficientBalance(...)` at a named site — including a Lido `used_` mismatch between preview and actual burn — stop and report the actual bytes. Do not broaden an expectation, do not substitute another error, do not edit production beyond §1.
- If any cited line no longer matches the cited text at edit time, stop and report the file and line.

I did not run Forge.
