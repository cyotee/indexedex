# Paired-money necessity

Revision **se-paired-money-necessity-20261030-01a18660-final**, with an owner lock. The owner accepted the recommendation below. It is recorded in the full-spread PRD as FS-OWN-09 and in `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`. It is not an implementation.

## Question

Does the accepted Standard Exchange redefinition fill the same need as the paired-money functions?

## Participation

| Member | Advisory |
| --- | --- |
| Astra | SUPPORT WITH CORRECTIONS |
| Grok | SUPPORT WITH CORRECTIONS |
| MiniMax | SUPPORT WITH CORRECTIONS |
| Kimi | SUPPORT |

The six keep-or-map decisions were not disputed.

## Answer

The redefinition fills the paired deposit and paired redeem need. It does not fill `donate` or `compound`.

| Function | Recommendation | Standard function |
| --- | --- | --- |
| `depositPair` | Map. Do not keep the selector. | `exchangeBundleInForSingleOut`. `tokenOut` is the share. `amountsIn` follows `vaultTokens()` order. |
| `previewDepositPair` | Map. Do not keep the selector. | `previewExchangeBundleInForSingleOut`. `tokenOut` is the share. |
| `redeemPair` | Map. Do not keep the selector. | `exchangeBundleOut`. `tokenIn` is the share. `tokensOut` are the two underlying ERC-20 faces. A native leg uses its wrapper. |
| `previewRedeemPair` | Map. Do not keep the selector. | `previewExchangeBundleOut`. `tokenIn` is the share. |
| `donate` | Keep. | None. It books tokens and mints no shares. |
| `compound` | Keep. | None. It collects fees and reinvests them without changing supply. |

Maxima versus a declared amount plus a same-token refund is not enough to keep `depositPair`. The caller is made whole either way. The difference is temporary custody, not a missing capability. Keeping both entry paths would let them disagree. The same rule applies to a second exit path.

The mapping is of the route, not permission to change the economics. Bundle-in for this family still has to use the paired acceptance and share-credit rules. Bundle-out for a paired redeem has to remove both currencies proportionally. It must not become a sale of one leg into the other. The standard previews cover the quotes, so the paired preview selectors are not also required.

`vaultTokens()` order must stay stable for the positional bundle, with the wrapped face at a native leg's index. `address(0)` is not a bundle input. That stability is a conformance requirement of this mapping. It is not an existing Basic Vault guarantee.

Dropping the selectors does not drop the events. `PairDeposited` and `PairRedeemed`, or their renamed equivalents, are still emitted by the mapped routes.

## Raw ETH

The accepted bundle functions do not take or pay raw ETH. This family has no ERC-5115 surface, so mapping away `depositPair` and `redeemPair` removes the only raw-ETH entry and exit currently named for it. That is not a reason to keep those selectors. It is also not authority to extend the standard. If this family must still move raw ETH, that is a separate owner decision. This recommendation does not add that function.

## Limits

No implementation was run. This report does not edit the full-spread PRD. It does not authorize code changes.
