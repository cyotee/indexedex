# Grok cross-review — legacy V4 ERC-5115

- **Date:** 2026-10-15
- **Peers:** `astra-original.md`, `minimax-original.md` (labeled replacement, not continuity of `ses_ec41255ceffeVhrySLQe8hwwMC`), `kimi-original.md`. Untrusted. Not edited.
- **Answer:** Selector changes and the Pendle boundary are closed. The deposit flag is not, until the PRD uses the sentence below.

## Agreement

- Remove the nine Pendle-only identities: the payable four-argument `deposit`, `rewardIndexesCurrent`, `claimRewards`, `assetInfo`, `isValidTokenIn`, `isValidTokenOut`, `getRewardTokens`, `accruedRewards`, and `rewardIndexesStored`.
- Add only `deposit(address,address,uint256,uint256,bool)`, nonpayable. Keep `redeem` and the six retained views on their current facets. Do not install `name`, `symbol`, or `decimals` from the ERC-5115 file.
- Other families stay on Pendle. Do not edit the shared SY targets or `NativeStandardYieldSelectors.sol`.
- Replace `type(IStandardizedYield).interfaceId` with `type(IERC5115_StandardizedYield).interfaceId` in the package slot at `UniswapV4StandardExchangeDFPkg.sol:162`. MiniMax's earlier sentence that drops that slot is not adopted.

## Dissent

Astra and Kimi add `LocalCreditLib.requirePretransferCaller` to a true `depositFromInternalBalance`. The existing token pretransfer path does not do that. `UniswapV4StandardExchangeCustody._secureTokenTransfer` at lines 23-41 measures unbooked token credit and reverts `TransferDeltaInsufficient`. The contract-caller gate is only on share delivery, at line 72. Adding it to token deposit is a new rule.

MiniMax is right that the flag maps to the token pretransfer flag, not to `_redeemVaultHeld` or the share-side `internal_` flag. MiniMax is wrong that the implementer may later choose a facet split. This item does not.

## Sentence the PRD must use

When `depositFromInternalBalance` is false, use the current token pull; when it is true, call `UniswapV4StandardExchangeCustody._secureTokenTransfer` with `pretransferred` true and do not call `LocalCreditLib.requirePretransferCaller` on that token path.

I did not run Forge.
