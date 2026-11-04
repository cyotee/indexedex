# r2-h2tb-fullspread-dfpkg-raw-approve: CONFIRMED (informational, token-compatibility DoS)

File: RawApprove.t.sol (7 tests, all PASS on the audit runner slot4)
Run: forge test .../RawApprove.t.sol -vvvv --skip V3FS --skip HookValue --skip FSInv --skip Wings --skip StakingSEInvariant --skip P4Common --skip DebugLido
(The --skip flags only work around stale, stack-too-deep p4-* invariant copies on remote slots 1, 2, 4, 5 and 7. They have nothing to do with this PoC.)

## What it shows
- Hookless DFPkg `test_noReturnToken_hookless_deployReverts`: a USDT-style token (approve/transfer/transferFrom return no data) is paired with a standard ERC20. The hookless V4 pool is initialized, and an honest full-range LP is seeded successfully through low-level transfer (PM holds about 1000e18 NRT). An unprivileged EOA (0xA11CE) then calls `deployVault(key)`, which REVERTS. The factory wraps the inner revert as `FailedCall()` (0xd6bda275), and the backtrace ends in `UniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.initAccount`. A retry also reverts, so the failure is permanent.
- PonsFamily DFPkg `test_noReturnToken_pons_deployReverts`: the same result for a registered Pons-hook pool. The backtrace ends in `UniswapV4FullSpreadPonsFamilyHookDFPkg.initAccount`.
- Controls: deploying with two standard tokens succeeds for both packages.
- Differential isolating the cause, `test_diff_onlyApproveReturnsBool_deployOk`: the token keeps no-return transfer/transferFrom, and ONLY `approve` returns bool. With that one change, deployVault SUCCEEDS. So the raw `IERC20(token).approve(PERMIT2, max)` in `_approvePoolManagerIfErc20` (hookless L378-384, Pons L387-393) is the only blocker at deploy time.

## Impact
No attacker and no victim, so no funds are at risk. A FullSpread vault cannot be created for any V4 pool that contains a no-return-bool token such as mainnet-style USDT, BNB or OMG. The approval is also unnecessary, because settlement uses currency.transfer + settle, not Permit2. Fix: use SafeERC20.forceApprove, or drop the Permit2 approval entirely.
Severity: info/low (availability and compatibility only).
