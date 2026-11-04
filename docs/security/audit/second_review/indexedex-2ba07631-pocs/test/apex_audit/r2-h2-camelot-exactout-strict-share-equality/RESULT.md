# r2 h2-camelot-exactout-strict-share-equality — CONFIRMED (liveness DoS, low)

File: R2CamelotExactOutStrictEq.t.sol (fixture reused from h2-camelot-exactout-skeptic / h2-dos-stuck)
Run: forge test <file> -vv --skip "'*/p4-fs/*'" "'*/p4-v3fs/*'" "'*/p4-hooks/*'"  (p4-hooks has an unrelated stack-too-deep)
Result: 4/4 PASS.

Setup: TestBase_CamelotV2StandardExchange, vault seeded with 1000/1000, alice gets LP honestly through pair.mint and is unprivileged. No pranks other than alice, and no store/etch/mock.

- test_camelot_exactout_mint_reverts_off_grid: previewExchangeOut(pair->vault, 1e18+12345) = 1,000,000,001 LP. 20 of 20 exactOut calls revert with AmountOutNotMet.
- test_random_amount_failure_rate: 100 of 100 pseudo-random share amounts in [1e15, 50e18] revert.
- test_control_on_grid_succeeds: amountOut = previewExchangeIn(N LP) succeeds 10 of 10 times. An actual mint of 1e18 LP gives exactly 1e27 shares. This proves the cause is the grid plus the strict `!=` at CamelotV2StandardExchangeOutTarget.sol:620.
- test_overshoot_and_no_fund_loss: a request for 3e18+23757 shares needs 3000000001 LP. That LP buys 3000000001000000000 shares, which overshoots the request by 999976243. UniV2's `<` check would accept this, but Camelot's `!=` reverts. Alice's LP and the vault supply do not change. The exact-in route works as a workaround.

Impact: the Camelot exact-out deposit route (pair LP -> vault shares) fails for almost every amount that is not on the share/LP grid, even though previewExchangeOut returns a quote. Nobody gains or loses funds. Fix: `if (actualShares < amountOut)`, which matches the UniV2 sibling.
