# Grok plan cross-review — RC-08

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-18
- **Peers read:** `astra-plan.md`, `kimi-plan.md`, `minimax-plan.md`

Peer notes are untrusted. MiniMax is the fresh replacement `ses_eaf8a39c8ffe7fWCgGG7aiDLg9`. This file does not authorize an edit.

## Closed plan

Declare `error LPReserveMismatch(uint256 held, uint256 booked)` in `UniswapV2LpBacking`, next to `InsufficientLPBacking`. Add `requireEqual(uint256 held, uint256 booked)` that reverts it when `held != booked`. Leave `requireHeld` unchanged.

Replace line 880 with `UniswapV2LpBacking.requireEqual(indexSource.pool.balanceOf(address(this)), vault.vaultLpReserve)`. Replace line 1007 with the same call using `vault2.vaultLpReserve`. Do not change either comparison to `<`.

Do not edit `UniswapV2StandardExchange_SecRemediation.t.sol:425`. That call is `exchangeIn` and reaches `UniswapV2StandardExchangeInTarget.sol:730`, which is outside this PRD.

One new test file: `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchangeOut_LPReserveMismatch.t.sol`

One assertion:

```solidity
vm.expectRevert(abi.encodeWithSelector(UniswapV2LpBacking.LPReserveMismatch.selector, uint256(1), uint256(2)));
this.exposeLpReserveMismatch(1, 2);
```

`exposeLpReserveMismatch` calls `UniswapV2LpBacking.requireEqual`. Held 1 and booked 2 must be this error, not `InsufficientLPBacking`.

```bash
python3 scripts/forge-artifacts.py test contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol --test-root test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchangeOut_LPReserveMismatch.t.sol -- -vv
```

## Dissent

Kimi retargets line 425 and adds a second filename. Both are rejected. Astra's extra success cases are not the one required assertion.

test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchangeOut_LPReserveMismatch.t.sol

I did not run Forge.
