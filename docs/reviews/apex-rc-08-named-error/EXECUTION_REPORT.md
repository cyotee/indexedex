# RC-08 named error — execution report

- Date: 2026-10-18.
- Scope: [implementation plan](./REMEDIATION_PRD.plan.md), authorized for execution by the owner in this session.
- Status: Implemented and validated. All 99 selected tests passed.

## Changes

Declared `UniswapV2LpBacking.LPReserveMismatch(uint256 held, uint256 booked)` immediately after `InsufficientLPBacking`. Both exact-out zap-in equality stops now revert inline with this error, reporting held LP first and booked LP second. Both comparisons remain `held != booked`; `requireHeld` and its less-than comparison are unchanged.

Added `UniswapV2StandardExchangeOut_LPReserveMismatch.t.sol`, inheriting the existing production-deployed multipool TestBase. The four cases cover token-to-vault and token-to-pair routes with donated LP and without it. Donation cases compare complete encoded error bytes and check rollback of held/booked LP, share supply, input/output balances, and pool supply. Matched-book controls use the same inputs and requested outputs without donation, require success, and reconcile input debit and output.

The `exchangeIn` target and the existing security remediation tests, including their abstract decimals base, were not edited. Existing unrelated worktree changes were preserved. No storage mocks, new production helper, compiler-setting changes, or cache deletion were introduced.

## Validation

The exact command specified in the plan was run:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchangeOut_LPReserveMismatch.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v2/decimals/UniswapV2StandardExchange_SecRemediation_Decimals.sol \
  -- -vv
```

It exited with code **2 before compilation** because the final root is an abstract `.sol` file. The helper requires an existing `.t.sol` file or directory. See [original command log](./forge-validation.log).

To execute the intended regression coverage, the retry replaces that abstract root with all eight concrete inheritors: `UniswapV2StandardExchange_SecRemediation_{H6,H9,P6_R9,P6_R18,P9_R6,P9_R18,P18_R6,P18_R9}.t.sol` in the same decimals directory. The production source, two other test roots, and `-vv` are unchanged. See [concrete-suite validation log](./forge-validation-concrete-decimals.log), which records the generated build and test commands.

The corrected sandboxed invocation compiled production artifacts and all selected tests successfully, then exited **250** before test execution. Forge panicked in macOS `system-configuration` with `Attempted to create a NULL object` while constructing its system proxy matcher. The same corrected command was retried outside the sandbox with approval; see [unsandboxed validation log](./forge-validation-unsandboxed.log).

The approved retry exited **0**: **99 passed, 0 failed, 0 skipped across 10 suites**. Both build and test compilation reused the successfully refreshed artifacts from the preceding invocation.

| Suite | Passed |
| --- | ---: |
| New LP reserve mismatch regression (two exact-error cases and two matched-book controls) | 4 |
| Existing V2 security remediation | 39 |
| Eight concrete decimals security remediation variants | 56 |
| Total | 99 |

Neither mismatch case returned unexpected revert bytes, and both matched-book controls succeeded. No test expectations were weakened or removed.

`git diff --check` passed. A scoped diff check confirmed the excluded `exchangeIn` target and existing regression sources remain unchanged.

These logs are local execution evidence, not an independent reviewer rerun. No deployment was performed. Error consumers should decode `LPReserveMismatch(uint256,uint256)` for the two formerly empty exact-out reverts; the function interfaces and equality conditions are unchanged.
