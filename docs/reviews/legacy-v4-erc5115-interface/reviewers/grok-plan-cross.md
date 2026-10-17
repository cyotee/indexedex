# Grok plan cross-review — legacy V4 ERC-5115

- **Date:** 2026-10-15
- **Peers:** `astra-plan.md`, `minimax-plan.md` (labeled replacement `ses_ebdf718feffemWQNf7wuTpapqX`; it does not recall `ses_ec41255ceffeVhrySLQe8hwwMC`), `kimi-plan.md`. Untrusted. Not edited.
- **Answer:** One choice remains.

## Agreement

- No facet split. No parallel class. Edit `UniswapV4StandardYieldExecutionTarget.sol`.
- Other families keep Pendle. Do not edit `contracts/vaults/standard/sy/` or the vendored Pendle interface.
- Remove the nine Pendle-only selectors. Add the nonpayable five-argument `deposit`. Keep `redeem` and the six reads on their current facets.
- Replace `type(IStandardizedYield).interfaceId` in place. Do not drop the package slot.
- A false deposit flag uses the current pull. A true flag uses the existing token pretransfer path. Do not add `LocalCreditLib.requirePretransferCaller` on that path. Astra withdraws the earlier gate. MiniMax and Kimi match that rule when the flag is forwarded as `pretransferred` to `_exchangeIn`.

## Dissent

MiniMax keeps `UniswapV4StandardExchangeOutMultiQueryTarget` inheriting the Pendle preview target and keeps `isValidTokenIn` and `isValidTokenOut` on that contract. Astra and Kimi remove that inheritance. The PRD says the vault stops implementing Pendle. Keeping the parent leaves `assetInfo` and the public validity functions on the implementation. That is still a choice.

## Sentence the plan must use

`UniswapV4StandardExchangeOutMultiQueryTarget` stops inheriting the Pendle preview and discovery targets and implements the six retained ERC-5115 reads on that same contract.

I did not run Forge.
