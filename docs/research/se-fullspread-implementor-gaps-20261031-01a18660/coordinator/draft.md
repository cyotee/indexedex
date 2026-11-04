# Coordinator draft

## Draft identity

- Draft ID: se-fullspread-implementor-gaps-20261031-01a18660-r1
- Path: docs/research/se-fullspread-implementor-gaps-20261031-01a18660/coordinator/draft.md
- Run ID: se-fullspread-implementor-gaps-20261031-01a18660
- Status: pending advisory review. This file is not the PRD and not the final.
- Sources: members/astra/response.md, members/grok/response.md, members/minimax/response.md, members/kimi/response.md

## Participation

- Council kind: full
- Requested members: Astra st_01a19393, Grok st_01a19394, MiniMax st_01a19395, Kimi st_01a19396
- Missing initial responses: none
- Coordinator mode: invoking agent
- Coordinator is an independent vote: no

## Question

Which sentences in the updated full-spread PRD still force an implementor to choose a product behavior, and what owner question or closing recommendation removes that choice?

## Not a current gap

A later rate policy is not an open implementation choice. FS-OWN-03 already forbids installing one. Do not ask the implementor to pick a rate.

The FS-OWN-07 sentence that other reserve semantics are unspecified is stale. `IBasicVault` has three members, and the lock already assigns them. Two narrower questions remain: an unknown token, and when the reserve snapshot is written.

## Questions for the owner

These are not recommendations. Answering one writes a requirement. It does not authorize a cap, a fee, a holder, a new return field, or a new selector.

1. How is the unredeemable `MIN_SHARES` floor of `1_000` represented in the one ERC-20, given the source leaves it in supply and in no balance, and the PRD forbids a second ledger and a holder address?
2. After which operations must each token's local balance be brought to `liquidReservePercentageOfVault(address(this))` of that token's owned amount, what rounding applies, and if the target cannot be met, does the operation revert or finish short?
3. May a call received while the PoolManager is locked spend local sleeve balances without opening an unlock?
4. After compound harvests and reinvests, is the sleeve target withheld from reinvestment, or does compound deploy idle the way Weir does and leave the target unmet?
5. On redemption, is the user paid from local balances even if that drops the sleeve below target, or is the target retained and the payout reduced?
6. Does `PkgInit.poolManager` stay, and which initialization step writes that address into the Protocol Aware Repo?
7. Which already-named repo stores `wrappedNative`, and which step writes it?
8. Which components besides PoolManager must the Protocol Aware pair store, including the Universal Router, and what binding supplies each address?
9. Does "native ETH stays" mean only a native pool settled through the wrapped face on `vaultTokens()`, or must an accepted route pay raw ETH to the user? Raw user entry is already nonpayable. No extension was added.
10. Which selectors does `queryFacet` install after the locked omissions, and does a Position facet expose `poolKey` or is that repo storage-only?
11. What does `reserveOfToken` return for an address not in `vaultTokens()`: zero, or a revert?
12. Which views revert while the operation guard is held, and when is the committed reserve snapshot written?
13. Which existing position-amount read and fee-owed read implement the deployed term?
14. Which accepted selector is the one-token exit? If the unselected currency's pro-rata liquidity or idle is nonzero, does that call revert, or pay only the selected token and leave the rest in the vault?
15. Which tokens may `donate` accept, does the amount stay local or get deployed, does it increase the idle a withdrawal pays, and may it run before the first share deposit or while the PoolManager is locked?
16. Is idle the stored Weir counters, or the vault's actual local balance?
17. Is `vaultTokens()` PoolKey `currency0` then `currency1`, with `wrappedNative` substituted for native?
18. What does "outside the inherited domain" check beyond an uninitialized pool and a nonzero hook?
19. What makes `wrappedNative` incompatible, other than colliding with a currency face?
20. How does one `PkgInit` field bind both `MultiAssetBasicVaultFacet` and the custom reserve facet?
21. Is any existing fee policy authorized to deduct value on these routes? Weir's treasury fee is not added. That absence is not a fee policy.
22. Must an imbalanced bundle deposit run Weir's balancing swap, or add liquidity from the declared amounts and return the unused input?
23. Does canonical `exchangeIn` support an underlying-to-underlying swap, or only underlying-to-share entry and share-to-underlying exit?
24. What existing state disables inbound issuance in FS-A38?
25. What value does the share's existing `decimals()` selector return?
26. May any address call `compound()`?
27. On the locked path, does `pretransferred == true` revert?
28. Does `block.timestamp > deadline` revert on the accepted routes?
29. Is the one-token entry swap amount the amount `_balance` computes before `_swap`, or a different amount?

## Recommendations that close a gap

These are coordinator text for advisory. They are not owner decisions and not a PRD edit.

- On entry, `amountRefunded` is unused declared input in that input currency only. A positive credit in the other currency is transferred to the payer, as `_deposit` settles a positive net to the depositor. It is not a new return field, not booked without shares, and not an exit payout. Astra and Grok close this from the accepted refund rule and Weir. Kimi asked it as a question. The draft does not vote that split closed.
- Pro-rata idle paid on withdrawal is Weir's stored idle counters, not `balanceOf(vault)`. `localReserves()` remains the actual local balances. This does not set the sleeve refill rule.
- The preview row that requires full unwanted-leg consumption is not an entry rule and is not authority to install `zapTo`. The one-token exit question above still has to be answered.

## Preserved disagreements

| Topic | Positions | Not resolved |
| --- | --- | --- |
| Other-currency entry credit | Astra and Grok: close it from Weir and the accepted refund rule. Kimi: ask whether to pay it outside `amountRefunded` or revert. | The draft carries both. |
| Raw ETH entry | Grok: already closed as nonpayable, no extension. Astra and MiniMax: the PRD still says actual ETH payout, which conflicts with that lock. | The question is payout, not a new entry selector. |

## Limits

- No PRD edit. No implementation. No new cap, fee, holder, return field, or selector.
- The coordinator did not vote the preserved splits.
