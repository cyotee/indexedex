# Kimi K3 — REQ-H03 holder negative: exact test change (replacement-session original)

- **Label:** Replacement-session original, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read. (The owner's message typed "RES-H03"; the controlling section is REQ-H03.) Nothing was edited. I did not run Forge.
- **Controlling text:** `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md` REQ-H03 (`:134-144`, re-read this round). Test read this round: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol:142-152` plus neighbors. The legacy V4 twin is withdrawn with that package; nothing below touches it.

## Answer: No blocking question.

The PRD's acceptance criteria are complete, and the production error is identifiable from current source with certainty sufficient to pin the edit. No product decision remains.

## The production error, named exactly

**`IERC20Errors.ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed)`** — for this test, `(holder, 0, 1)`.

Trace (all read this round):

1. The test's holder (`makeAddr("v3Short")`) holds zero shares and calls `IStandardizedYield(vault).redeem(recipient, 1, address(token0), 0, false)` (`:148`).
2. `NativeStandardYieldTarget.redeem` (`contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:30-45`): validation passes (receiver set, `shares_ = 1 ≠ 0`, `token0` valid); `internalBalance_ = false` routes to `_standardRoute` → `_exchangeIn(self-shares, 1, …, false)`.
3. The self-share input on a non-pretransferred call burns the holder directly — `BasicVaultCommon._secureSelfBurn` (`contracts/vaults/basic/BasicVaultCommon.sol:151-155`) calls `ERC20Repo._burn(owner, burnAmount)` on the false-flag branch. This is the documented ordinary-redemption shape ("ordinary redemption needs no share allowance", asserted at `:121`); there is no `transferFrom`, so no allowance error can fire first.
4. `ERC20Repo._burn` on an insufficient balance reverts at `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:229`: `revert IERC20Errors.ERC20InsufficientBalance(account, currentBalance, amount);` — declared at `lib/crane/contracts/tokens/ERC20/IERC20Errors.sol:16`.

Corroborating precedent in-repo: `contracts/test/bases/TestBase_FullSpreadG5GuardClosure.sol:360` already expects `IERC20Errors.ERC20InsufficientBalance.selector` on the FullSpread vault's share token, and Crane's own `TestBase_ERC20.sol:64,127` uses the same selector for burn negatives. (Note: `NativeStandardYieldTarget.sol:62`'s `TransferDeltaInsufficient` is the **vault-held** internal-balance path's guard — not this test's route; do not name that one.)

## The exact test change (closed; no implementer choice)

In `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol`:

1. Add the import: `import {IERC20Errors} from "@crane/contracts/tokens/ERC20/IERC20Errors.sol";` (the file already imports from `@crane`; no new dependency).
2. Replace the bare `vm.expectRevert();` at `:147` with:
   ```solidity
   vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, holder, 0, 1));
   ```
   `holder` is the variable already in scope at `:143`; `0` is its balance; `1` is the requested burn at `:148`.
3. Keep everything else byte-identical: the balance assertions at `:149-151` (holder, vault, recipient unchanged — now meaningful as post-revert state), the test name, the prank, and every other test in the file. The code-less ordinary-success tests (`:110-122`, `:124-140`) remain untouched, per the PRD's acceptance criteria.

## Guards

- No production file is touched; the burn is not weakened (PRD non-goal).
- No `catch` anywhere.
- If the run shows a different selector at this route, stop and report the actual revert bytes — do not substitute another named error, and do not "fix" production to match the expectation.
- One nuance the implementer must not paper over: if the vault's share token were ever swapped to a Solady-direct implementation, the error would become Solady's argument-less `InsufficientBalance()`. Today the vault diamond's share surface is Crane's `ERC20Repo`, as evidenced by `:229` and the two existing precedents; the named error above is correct for the current code.

## One-sentence closure for the plan

"At `UniswapV3FullSpreadVaultHeldRedeem.t.sol:147`, expect exactly `IERC20Errors.ERC20InsufficientBalance(holder, 0, 1)` (importing `IERC20Errors` from `@crane/contracts/tokens/ERC20/IERC20Errors.sol`), and change nothing else in the file or in production."

I did not run Forge.
