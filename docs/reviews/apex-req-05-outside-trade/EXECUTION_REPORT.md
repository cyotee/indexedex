# REQ-05 outside-trade credit — execution report

- Date: 2026-10-17
- Status: Complete. All 24 tests in the three selected files passed.
- Plan: [REMEDIATION_PRD.plan.md](./REMEDIATION_PRD.plan.md)
- Controlling PRD: [REMEDIATION_PRD.md](./REMEDIATION_PRD.md)
- Starting HEAD: `b8dbdf4102ccddedc3f46b6acf8f3d3006a378fe`

## Changes

Extended `test_outsidePoolTradeDoesNotRefreshVaultBook` in the hookless and Pons `AttributionAndBooking.t.sol` files and wings `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol`.

Each test now records token0 held immediately before the existing outside trade, proves the trade added no held tokens, transfers seven whole token0 units using the token's actual decimals, and checks available credit equals the prior unbooked balance plus that transfer. The contract test caller requests `credit + 1` through true-flag `exchangeIn`, expecting exactly `TransferDeltaInsufficient(credit + 1, credit)`. Each rejection is followed by unchanged token-balance, booked-reserve, and total-supply assertions. Existing outside trades, unchanged-book assertions, and preview/deposit checks remain.

The plan's literal `token0.decimals()` does not compile in hookless or Pons because their token0 fields use `IERC20`. Those two files import the existing `IERC20Metadata` interface and use `IERC20Metadata(address(token0)).decimals()`. Wings retains the literal expression. This is the only implementation adjustment to the plan; amount semantics and error expectations are unchanged.

## Existing V3 proof

`test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadLocalBook.t.sol:63-75` transfers seven ether of token0, executes the outside trade, verifies unchanged books, and rechecks the credit boundary. Its helper at lines 114-136 derives credit from held tokens minus the book, checks the exact overclaim revert bytes, and asserts unchanged balance, reserve, and supply. The file remains byte-for-byte identical to starting HEAD. V3 was inspected, not rerun by this task.

## Validation

Executed from the repository root, with output redirected to the linked logs:

```bash
python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/AttributionAndBooking.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/AttributionAndBooking.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol \
  -- -vv
```

- Initial invocation: exit 1. Artifact build passed; test compilation failed with Solidity error 9582, `Member "decimals" not found or not visible after argument-dependent lookup in contract IERC20`. No runtime tests ran. See [initial log](./forge-validation-initial.log).
- After the interface casts: compilation passed (three files, Solc 0.8.35, 68.84 seconds), then Forge crashed before runtime tests with `Attempted to create a NULL object` in macOS `system-configuration` / proxy discovery. The sandbox invocation exited 250. See [sandbox log](./forge-validation-sandbox.log).
- Approved retry outside the sandbox: the same command exited 0. Artifact build and test compilation reused current cached artifacts. **24 passed, 0 failed, 0 skipped** across three complete suites; test runtime 14.63 seconds. See [final log](./forge-validation.log).
  - Hookless attribution and booking: 5 passed.
  - Pons attribution and booking: 5 passed.
  - Wings money routes: 14 passed, including 16 configured fuzz runs for its fuzz test.
- All three `test_outsidePoolTradeDoesNotRefreshVaultBook` tests passed with the exact specified revert expectation and all three post-rejection assertions. No differing revert bytes were observed.
- `git diff --check`: passed.
- No production files, V3 LocalBook, Foundry configuration, or deployment helpers changed. Existing unrelated documentation edits were preserved. The legacy V4 family was not restored; `out/` and `cache_forge/` were retained.

These logs record the implementation session's runs, not an independent reviewer rerun.
