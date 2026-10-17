# REQ-H03 execution report

- Date: 2026-10-17
- Plan: [REMEDIATION_PRD.plan.md](./REMEDIATION_PRD.plan.md)
- Status: prescribed source edits complete; all 69 selected tests passed; pointer step stopped at gate 3.

## Changes

The pre-edit storage `_burn` matched Step 1's required starting body. It now reads the holder balance, rejects an insufficient balance with `IERC20Errors.ERC20InsufficientBalance(account, currentBalance, amount)` before writing storage, subtracts the balance once, subtracts supply, and emits the existing transfer. NatSpec, include tags, the address overload, and other ERC-20 operations are unchanged. No zero-address rejection or supply-specific error was added.

The three existing tests now assert the full named error and arguments:

- V3 insufficient holder: `(holder, 0, 1)`.
- ERC-4626 owner burn: `(user, seBal, seBal + 1)`; removed the unused `stdError` import and updated the comment.
- Lido missing shares: `(attacker, attackerBefore, requiredShares)`; `requiredShares` comes from the exact-output preview, with an assertion that it exceeds the attacker's balance.

The existing calls and rollback assertions were preserved. No new tests or withdrawn V4 files were added. Existing unrelated edits, including the Lido REQ-C06 tests, were preserved.

## Pointer gate

1. Crane branch: `main` (pass).
2. Crane status: only ` M contracts/tokens/ERC20/ERC20Repo.sol` (pass).
3. IndexedEx status contains many unrelated modifications, deletions, and untracked files (fail). See [captured status](./pointer-gate-status.txt), recorded before this report was created. Examples present before this task include `CLAUDE.md`, `contracts/interfaces/IDetf.sol`, and the deleted legacy V4 family.
4. `scripts/submodule-commit.sh` was not run. No commit or push was performed.

The Crane checkout and existing IndexedEx index gitlink both reference `2d626b3663a22281587cb34ac0ac271e968ee3cd`. The burn change remains uncommitted in Crane; it is not contained in that revision. The parent already had a staged gitlink change when this task began; it was preserved.

The pointer step stopped at its named gate. The independent validation command below runs against the current workspace sources.

## Validation

Executed from the IndexedEx root, with stdout and stderr captured in [forge-execution.log](./forge-execution.log):

```bash
python3 scripts/forge-artifacts.py test \
  lib/crane/contracts/tokens/ERC20/ERC20Repo.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol \
  --test-root test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol \
  --test-root test/foundry/spec/protocol/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol \
  -- -vv
```

The helper selected 322 build roots, an import closure of 1,186 sources, and 46 runtime artifact IDs. No test-name filter was supplied.

| Attempt | Exit status | Result |
| --- | --- | --- |
| Initial sandbox run, [output](./forge-execution.log) | 250 | Production compilation passed: 462 files, Solc 0.8.35, 602.16 seconds. Test compilation passed: 3 files, 68.55 seconds. Forge then crashed in macOS system proxy configuration before reporting test results. |
| Approved retry outside the sandbox, [output](./forge-execution-retry.log) | 0 | Same command and test scope; both compilation stages reused the refreshed artifacts. All 69 tests passed, none failed or skipped. |

The initial crash reported `Attempted to create a NULL object` at `system-configuration-0.6.1/src/dynamic_store.rs:154`, with `hyper_util::client::proxy::matcher::mac::with_system` in the backtrace. It was a host tooling crash, not an EVM revert. The retry used the same prescribed command with output redirected to `forge-execution-retry.log`; no code, compiler settings, test filters, or expectations changed between attempts.

| Complete test file | Passed | Failed | Skipped |
| --- | ---: | ---: | ---: |
| `UniswapV3FullSpreadVaultHeldRedeem.t.sol` | 10 | 0 | 0 |
| `ERC4626StandardExchange_Routes.t.sol` | 20 | 0 | 0 |
| `Adversarial_LidoWstETH_P0.t.sol` | 39 | 0 | 0 |

All three named short-burn sites passed with the exact encoded error arguments. The Lido preview and its insufficient-share assertion passed. Existing successful burns and rollback assertions in these files also passed. No unexpected revert bytes or additional short-burn failures were observed in this selected scope.

Targeted `git diff --check` passed for the Crane edit and the three test files. This saved execution is not an independent reviewer rerun. No whole-repository or separate Crane test run is claimed.
