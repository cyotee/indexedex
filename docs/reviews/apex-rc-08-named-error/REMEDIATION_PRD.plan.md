# Implementation plan — RC-08 named error

- **Date:** 2026-10-18
- **Status:** Executed and confirmed 2026-10-18. Confirmation: `docs/reviews/apex-rc-08-execution-confirmation/REMEDIATION_PRD.md`. The saved log was not rerun.
- **Controlling PRD:** [REMEDIATION_PRD.md](./REMEDIATION_PRD.md). Where this plan conflicts with that PRD, the PRD controls.
- **ID:** RC-08.
- **Council:** Astra `ses_ebdc505a9ffeLLIq4HBAh44TYi` does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Grok `ses_ec4128917ffeeVds3Y2p7xrVjp`. MiniMax is a fresh replacement `ses_eaf8a39c8ffe7fWCgGG7aiDLg9`. It does not recall `ses_eb8ab99f3ffe7suGF49ryUzI6t` or `ses_ebdf718feffemWQNf7wuTpapqX`. Kimi `ses_ec3d04e91ffeJa0is24e2jZv06` does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. Astra was not censored. No Forge run. Consensus is not proof.

## What to do

Declare `LPReserveMismatch(uint256 held, uint256 booked)` and use it at the two blank equality stops. Keep `held != booked`.

## What not to do

- Do not use `LpBackingMismatch`.
- Do not reuse `InsufficientLPBacking`.
- Do not change `held != booked` into `held < booked`.
- Do not add a helper. The two sites revert inline.
- Do not edit `UniswapV2StandardExchangeInTarget.sol:730`.
- Do not change `UniswapV2StandardExchange_SecRemediation.t.sol:425` or its decimals twin. Those tests call `exchangeIn`.
- Do not enable `via_ir`. Do not delete `out/` or `cache_forge/`.

## Step 1 — declare the error

File: `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol`.

Inside `UniswapV2LpBacking`, immediately after `InsufficientLPBacking`, add:

```solidity
    /// @notice Held LP is not exactly the booked LP reserve.
    /// @custom:signature LPReserveMismatch(uint256,uint256)
    error LPReserveMismatch(uint256 held, uint256 booked);
```

Leave `requireHeld` and its `held < required` check unchanged.

## Step 2 — vault zap-in stop

Replace the blank revert at lines 879-880 with:

```solidity
        if (indexSource.pool.balanceOf(address(this)) != vault.vaultLpReserve) {
            revert UniswapV2LpBacking.LPReserveMismatch(
                indexSource.pool.balanceOf(address(this)), vault.vaultLpReserve
            );
        }
```

## Step 3 — pass-through zap-in stop

Replace the blank revert at line 1007 with:

```solidity
        if (indexSource.pool.balanceOf(address(this)) != vault2.vaultLpReserve) {
            revert UniswapV2LpBacking.LPReserveMismatch(
                indexSource.pool.balanceOf(address(this)), vault2.vaultLpReserve
            );
        }
```

## Step 4 — one new test file

Create `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchangeOut_LPReserveMismatch.t.sol`.

Contract: `UniswapV2StandardExchangeOut_LPReserveMismatch_Test`. Inherit `TestBase_UniswapV2StandardExchange_MultiPool`. Import `UniswapV2LpBacking` from the OutTarget file.

Use the same balanced pool as the existing V2 tests. On a fresh vault, donate a small LP amount so the pool-token balance is not the booked reserve. Capture both numbers immediately before the call:

```solidity
uint256 heldBefore_ = pair_.balanceOf(address(vault_));
uint256 bookedBefore_ = 0;
vm.expectRevert(abi.encodeWithSelector(
    UniswapV2LpBacking.LPReserveMismatch.selector, heldBefore_, bookedBefore_
));
```

Call `exchangeOut` twice under that mismatch:

- Token in is the balanced pool token. Token out is the vault. This is the line 879 stop.
- Token in is the balanced pool token. Token out is the pair. This is the line 1007 stop.

Add two matched-book controls, with no donated LP, that do not expect this error. If a matched-book call fails for another reason, stop and report that error. Do not delete the control to make the file pass.

If either mismatch call reverts with different bytes, stop and report the file, the route, and the bytes. Do not weaken the comparison. Do not mock vault storage.

## Step 5 — one command

From the IndexedEx root:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchangeOut_LPReserveMismatch.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v2/decimals/UniswapV2StandardExchange_SecRemediation_Decimals.sol \
  -- -vv
```

Record the result in `EXECUTION_REPORT.md`. A saved log is not an independent reviewer rerun.

## Done when

- Both blank stops revert `LPReserveMismatch` with held first and booked second.
- The comparison is still `held != booked`.
- The `exchangeIn` blank assertion is unchanged.
- The one Forge command has been run and its result recorded.

## Dissent

Astra preferred a helper and the filename `UniswapV2StandardExchange_LPReserveMismatch.t.sol`. That helper is not in this plan. The filename above is the one used by Grok, Kimi, and the MiniMax replacement. Kimi withdrew the proposal to retarget the `exchangeIn` test.
