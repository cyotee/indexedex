# Grok plan cross-review — REQ-05

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-17
- **Peers read:** `astra-req05-plan.md`, `minimax-req05-plan.md`, `kimi-req05-plan.md`

Peer notes are untrusted. This file does not authorize an edit.

## Closed plan

No implementer choice. Leave `UniswapV3FullSpreadLocalBook.t.sol` unchanged. After the existing unchanged-book assertions in the hookless, Pons, and wings tests, add only this proof. Leave the preview lines. They are not the proof.

The token is `token0`. The caller is `address(this)`. The amount is `7 * 10 ** token0.decimals()`. Do not use an EOA. Do not edit production.

Record `unbooked` as `token0.balanceOf(vault) - reserveOfToken(token0)` before the transfer. Transfer the amount. `credit` is that same balance minus book. Assert `credit == unbooked + amount`. The only new call is the rejecting true-flag `exchangeIn` of `credit + 1`, minimum zero, to `address(this)`. Expect `ISecurePullErrors.TransferDeltaInsufficient(credit + 1, credit)`. After the revert, that token balance, its book, and total supply are unchanged.

Hookless and Pons:

```solidity
vault.exchangeIn(token0, credit + 1, IERC20(address(vault)), 0, address(this), true, block.timestamp);
```

Wings uses `wings0` and `IStandardExchangeIn(address(wings0)).exchangeIn` with the same arguments. `token0` is not a fixed 6-decimal or 18-decimal token: `TestBase_UniswapV4UpperLowerWingsStandardExchangeVault.sol:35-37` creates both and sorts them by address.

## Command

```bash
python3 scripts/forge-artifacts.py test --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/AttributionAndBooking.t.sol --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/AttributionAndBooking.t.sol --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol -- -vv
```

If the revert bytes differ, stop and report them. If a cited line has drifted, stop and report it.

## Retraction

The earlier Grok draft said wings `token1` always has 18 decimals and used `7 ether`. That is retracted. The sort at line 37 can put either decimal count in `token0` or `token1`.

## Dissent

- MiniMax measures credit as the caller's share increase. That is not the PRD. Credit is vault token balance minus book. The new block has no successful credit call, only the rejecting `credit + 1` call.
- Kimi's wings amount `7 * 10 ** 6` assumes `token0` is the 6-decimal token. The sort makes that false.
- Astra's wings expression is the right shape. The closed amount uses that expression for all three files, not a separate `7 ether` literal.

I did not run Forge.
