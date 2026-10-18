# Grok plan — RC-08 named error

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-18
- **Controlling text:** `docs/reviews/apex-rc-08-named-error/REMEDIATION_PRD.md`

This draft does not authorize an edit. No implementer choice. Do not reuse `InsufficientLPBacking`. Do not change `held != booked` to `held < booked`.

## Stop first

Stop and report if line 880 or line 1007 is not an empty `revert()` on `pool.balanceOf(address(this)) != vaultLpReserve`.

## Error

In `UniswapV2LpBacking`, next to `InsufficientLPBacking`, add:

```solidity
error LPReserveMismatch(uint256 held, uint256 booked);

function requireEqual(uint256 held, uint256 booked) internal pure {
    if (held != booked) revert LPReserveMismatch(held, booked);
}
```

Leave `requireHeld` unchanged.

## Sites

Replace lines 879–880 with:

```solidity
        UniswapV2LpBacking.requireEqual(indexSource.pool.balanceOf(address(this)), vault.vaultLpReserve);
```

Replace line 1007 with:

```solidity
        UniswapV2LpBacking.requireEqual(indexSource.pool.balanceOf(address(this)), vault2.vaultLpReserve);
```

## Test

No existing test expects these two blank reverts. `UniswapV2StandardExchange_SecRemediation.t.sol:425` expects a blank revert on `exchangeIn`. Do not change it.

Add `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_LPReserveMismatch.t.sol`:

```solidity
function test_RC08_lpReserveMismatch_reportsHeldAndBooked() public {
    vm.expectRevert(abi.encodeWithSelector(UniswapV2LpBacking.LPReserveMismatch.selector, uint256(3), uint256(2)));
    this.exposeLpReserveMismatch(3, 2);
    vm.expectRevert(abi.encodeWithSelector(UniswapV2LpBacking.LPReserveMismatch.selector, uint256(1), uint256(2)));
    this.exposeLpReserveMismatch(1, 2);
    this.exposeLpReserveMismatch(2, 2);
}

function exposeLpReserveMismatch(uint256 held, uint256 booked) external pure {
    UniswapV2LpBacking.requireEqual(held, booked);
}
```

## Command

```bash
python3 scripts/forge-artifacts.py test contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol --test-root test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_LPReserveMismatch.t.sol --test-root test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol -- -vv
```

If the revert bytes differ, stop and report them. Do not weaken the comparison.

I did not run Forge.
