# Grok cross-review — REQ-H03

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-16
- **Peers read:** `astra-h03.md`, `minimax-h03.md`, `kimi-h03.md`

Peer notes are untrusted. This file does not authorize an edit.

## Verdict

Agree with Astra. No blocking question. The test must expect `Panic(uint256)` with argument `0x11`.

Dissent from MiniMax and Kimi. `ERC20InsufficientBalance` is not the error this route raises. Do not leave that as an alternative.

## Lines confirmed

- `UniswapV3FullSpreadStandardYieldExecutionTarget.sol:22` passes `msg.sender` into `_settleNamedHolder`, which calls `_executeZapOutExactIn`.
- The burn is `ERC20Repo._burn` at `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:236` or `:257`.
- `ERC20Repo.sol:361` comments out `_decreaseBalanceOf`. Line 362 is `layoutStruct.balanceOf[account] -= amount`. That statement is not inside `unchecked`.
- Solidity 0.8.37 documents panic code `0x11` for arithmetic underflow outside `unchecked`. Source: https://docs.soliditylang.org/en/v0.8.37/control-structures.html
- `BasicVaultCommon._secureSelfBurn` is not this route. `_executeZapOutExactIn` burns the named holder directly.

`_decreaseBalanceOf` at line 229 would raise `IERC20Errors.ERC20InsufficientBalance`. `_burn` does not call it.

## Closed test change

Replace line 147 of `UniswapV3FullSpreadVaultHeldRedeem.t.sol` with:

```solidity
vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", uint256(0x11)));
```

Leave the call and the three balance assertions. Do not add an import. Do not change production. Do not uncomment `_decreaseBalanceOf`. Do not add a `catch`. Do not edit the withdrawn V4 twin.

## Dissent

MiniMax and Kimi tell the test to expect `ERC20InsufficientBalance(holder, 0, 1)`. That is the error in the unused helper, not the error in `_burn`. Expecting it would fail against current production or force a production edit. The application PRD forbids both. Kimi's trace through `_secureSelfBurn` is also wrong for this call. That function is not on this route, and it calls the same `_burn`.

I did not run Forge.
