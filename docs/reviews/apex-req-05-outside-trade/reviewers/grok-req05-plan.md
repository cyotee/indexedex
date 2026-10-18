# Grok plan draft — REQ-05

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-17
- **Controlling text:** `docs/reviews/apex-req-05-outside-trade/REMEDIATION_PRD.md`

This draft does not authorize an edit. No implementer choice. Do not edit production. Do not restore `contracts/protocols/dexes/uniswap/v4`. Do not edit `UniswapV3FullSpreadLocalBook.t.sol`. Do not use an EOA. Do not treat `minted == preview` as the proof.

## Stop first

Stop and report if any of these book assertions is gone:

- Hookless `AttributionAndBooking.t.sol:40-42`
- Pons `AttributionAndBooking.t.sol:43-45`
- Wings `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol:34-36`

## The only edits

After those assertions, and before the existing preview lines, insert the same proof. Leave the preview lines. They do not satisfy this item.

The token is `token1`. It has 18 decimals in all three fixtures. The amount is `7 ether`. The caller is `address(this)`, the test contract. Do not `vm.prank` an EOA.

Record `unbooked` as `token1.balanceOf(vault) - reserveOfToken(token1)` before the transfer. Transfer `7 ether`. Then `credit` is that same balance minus book. Assert `credit == unbooked + 7 ether`. Expect `ISecurePullErrors.TransferDeltaInsufficient(credit + 1, credit)`. After the revert, that token balance, its booked reserve, and total supply are unchanged.

### Hookless

File: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/AttributionAndBooking.t.sol`

```solidity
token1.transfer(address(vault), 7 ether);
uint256 credit = token1.balanceOf(address(vault)) - IBasicVault(address(vault)).reserveOfToken(address(token1));
vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, credit + 1, credit));
vault.exchangeIn(token1, credit + 1, IERC20(address(vault)), 0, address(this), true, block.timestamp);
```

The `unbooked` read and the three unchanged assertions wrap that call as stated above.

### Pons

File: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/AttributionAndBooking.t.sol`

Use the same four lines. The token, caller, and call are the same as hookless.

### Wings

File: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol`

Do not use `token0`. It has 6 decimals.

```solidity
token1.transfer(address(wings0), 7 ether);
uint256 credit = token1.balanceOf(address(wings0)) - IBasicVault(address(wings0)).reserveOfToken(address(token1));
vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, credit + 1, credit));
IStandardExchangeIn(address(wings0)).exchangeIn(token1, credit + 1, IERC20(address(wings0)), 0, address(this), true, block.timestamp);
```

## Command

```bash
python3 scripts/forge-artifacts.py test --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/AttributionAndBooking.t.sol --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/AttributionAndBooking.t.sol --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol -- -vv
```

If that run reverts with different bytes, stop and report them. Do not broaden the expectation.

I did not run Forge.
