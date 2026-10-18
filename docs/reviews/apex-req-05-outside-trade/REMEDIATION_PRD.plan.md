# Implementation plan — REQ-05 outside-trade credit

- **Date:** 2026-10-17
- **Status:** Source steps executed. Confirmation: `docs/reviews/apex-req-05-execution-confirmation/REMEDIATION_PRD.md`. Writing this plan did not authorize implementation.
- **Controlling PRD:** [REMEDIATION_PRD.md](./REMEDIATION_PRD.md). Where this plan conflicts with that PRD, the PRD controls.
- **ID:** REQ-05.
- **Council:** Astra replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi` does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Grok `ses_ec4128917ffeeVds3Y2p7xrVjp`. MiniMax replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t` does not recall `ses_ebdf718feffemWQNf7wuTpapqX`. Kimi replacement `ses_ec3d04e91ffeJa0is24e2jZv06` does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. Astra was not censored. No Forge run. Consensus is not proof.

## What to do

Add the held-token credit check to hookless, Pons, and wings. Cite the existing V3 sequence. Do not edit it.

## What not to do

- Do not edit `UniswapV3FullSpreadLocalBook.t.sol`.
- Do not edit production. Do not restore `contracts/protocols/dexes/uniswap/v4`.
- Do not use an EOA. Do not `vm.prank` the caller.
- Do not treat `minted == preview` as this proof. Leave those lines. They do not satisfy this item.
- Do not succeed a deposit and treat the share delta as credit.
- Do not hardcode `7 ether` or `7 * 10 ** 6`. Wings sorts a 6-decimal token and an 18-decimal token by address.
- Do not enable `via_ir`. Do not delete `out/` or `cache_forge/`.

## Step 1 — anchors

Stop and report if any of these is gone:

- Hookless `AttributionAndBooking.t.sol:34-42`
- Pons `AttributionAndBooking.t.sol:37-45`
- Wings `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol:26-36`
- V3 `UniswapV3FullSpreadLocalBook.t.sol:68-75` and `:114-136`

If `ISecurePullErrors` is not already imported in one of the three edited files, stop and report. Do not choose another error.

## Step 2 — the three edits

The token is `token0`. The caller is `address(this)`. The amount is:

```solidity
uint256 transferAmount = 7 * 10 ** uint256(token0.decimals());
```

Immediately before the existing outside-trade call, record:

```solidity
uint256 heldBefore = token0.balanceOf(address(subject));
```

`subject` is `vault` for hookless and Pons, and `wings0` for wings.

After the existing unchanged-book assertions, and before the existing preview or deposit lines, insert:

```solidity
assertEq(token0.balanceOf(address(subject)), heldBefore, "outside trade adds no held tokens");
uint256 unbookedBefore = heldBefore - IBasicVault(address(subject)).reserveOfToken(address(token0));
assertTrue(token0.transfer(address(subject), transferAmount));
uint256 credit = token0.balanceOf(address(subject)) - IBasicVault(address(subject)).reserveOfToken(address(token0));
assertEq(credit, unbookedBefore + transferAmount, "credit is held tokens only");
uint256 balanceAfter = token0.balanceOf(address(subject));
uint256 bookAfter = IBasicVault(address(subject)).reserveOfToken(address(token0));
uint256 supplyAfter = IERC20(address(subject)).totalSupply();
vm.expectRevert(abi.encodeWithSelector(
    ISecurePullErrors.TransferDeltaInsufficient.selector, credit + 1, credit
));
```

Then the rejecting call. Hookless and Pons:

```solidity
vault.exchangeIn(token0, credit + 1, IERC20(address(vault)), 0, address(this), true, block.timestamp);
```

Wings:

```solidity
IStandardExchangeIn(address(wings0)).exchangeIn(
    token0, credit + 1, IERC20(address(wings0)), 0, address(this), true, block.timestamp
);
```

Then:

```solidity
assertEq(token0.balanceOf(address(subject)), balanceAfter, "rejected credit moves no tokens");
assertEq(IBasicVault(address(subject)).reserveOfToken(address(token0)), bookAfter, "rejected credit books nothing");
assertEq(IERC20(address(subject)).totalSupply(), supplyAfter, "rejected credit mints nothing");
```

Leave the existing preview-echo lines after this block.

## Step 3 — one command

From the IndexedEx root:

```bash
python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/AttributionAndBooking.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/AttributionAndBooking.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol \
  -- -vv
```

Run the whole files. If a rejecting call returns different bytes, stop and report those bytes. Do not change the expectation and do not edit production.

Record the command and result in `EXECUTION_REPORT.md`. A saved log is not an independent reviewer rerun.

## Done when

- V3 LocalBook is unchanged and still contains the cited sequence.
- Hookless, Pons, and wings each record held tokens before the outside trade, show that trade added none, transfer `7 * 10 ** token0.decimals()`, and reject `credit + 1` with `TransferDeltaInsufficient(credit + 1, credit)`.
- The three post-rejection assertions are present.
- No production file changed.
- The one Forge command has been run and its result recorded.
