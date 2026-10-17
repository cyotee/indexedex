# Grok — REQ-H03

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-16
- **Typed name:** RES-H03. Controlling text is REQ-H03.
- **File:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol:147`

No blocking question.

The route is ordinary `redeem(..., false)`. It names `msg.sender` as the holder and burns that balance in `ERC20Repo._burn`. There is no custom holder-balance error on that path. A short balance underflows `balanceOf[account] -= amount`. The error is exactly `Panic(uint256)` with argument `0x11`.

## Exact test change

Replace line 147 only:

```solidity
vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", uint256(0x11)));
```

Leave the call, the holder, and the three balance assertions. Do not change production. Do not add a `catch`. Do not edit the withdrawn V4 twin. Do not replace the code-less caller in the ordinary-success tests.

I did not run Forge.
