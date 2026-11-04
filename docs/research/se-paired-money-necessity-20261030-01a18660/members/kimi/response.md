# Kimi research response

## Identity

- Run: `se-paired-money-necessity-20261030-01a18660`
- Member: Kimi
- Role: `council-member`
- Profile: research
- Requested Native selection: `kimi-coding/k3.1-pro:high`, global route
- Native task ID, conversation ID, and other actual route metadata: not exposed

## Question and targets

Question: Does the accepted Standard Exchange redefinition fill the same need as the paired-money functions, and which of those functions should this family keep, drop, or map onto a named standard function?

Required targets read:

- The paired-money section of `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`.
- The owner lock and accepted interfaces in `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md`.
- The declarations of all six functions in `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol`.

The optional stage-one PRD was not needed for declarations because the current interface declares all six functions.

## Evidence

1. The review file defines `depositPair` as a payable two-currency deposit bounded by two maxima, `redeemPair` as a proportional two-currency withdrawal, their paired previews, `donate` as a contribution that mints no shares, and `compound` as fee collection and reinvestment with no share-supply change. It also states that the Standard Exchange lock does not decide these paired functions.
2. The accepted report defines the route by token identity: underlying inputs for the share are a deposit, and the share for underlying outputs is a withdrawal. The share may be the input or output even when it is absent from `vaultTokens()`.
3. `exchangeBundleInForSingleOut` accepts positional `amountsIn` in `vaultTokens()` order, one `tokenOut`, `minAmountOut`, `recipient`, `pretransferred`, and `deadline`. It returns `amountOut` and per-input `amountsRefunded`. For each input, declared amount equals consumed amount plus refund. Its preview returns the corresponding quote.
4. `exchangeBundleOut` accepts one `tokenIn` and `amountIn`, caller-ordered `tokensOut`, aligned `minAmountsOut`, `recipient`, `pretransferred`, and `deadline`. It returns `amountsOut` and the unkept pay-token `amountRefunded`. Its preview returns quoted output amounts and the refund.
5. The accepted bundle functions are nonpayable, reject `address(0)`, and use wrapped ERC-20 faces rather than raw native ETH. The report explicitly leaves raw ETH to product functions outside the redefinition.
6. The current PairToken interface confirms that `depositPair` is payable and returns shares; `previewDepositPair` returns shares plus `used0` and `used1`; `redeemPair` returns two payouts; `previewRedeemPair` quotes those payouts; `donate` pulls and books a contribution without minting; and `compound` returns realized fees while maintaining incumbent backing without changing supply.

## Assumptions

- This is an interface-necessity assessment, not a finding that a Standard Exchange implementation already reproduces every PairToken internal accounting or maintenance behavior.
- The share token address is available for use as `tokenOut` on deposits and `tokenIn` on withdrawals, as the accepted report permits.
- Recommendation: use `vaultTokens()` order as the canonical translation from PairToken's currency0/currency1 arguments to bundle arguments. On a native pool, use the wrapped ERC-20 face for these standard routes.
- No separate product requirement to preserve raw-native deposits or payouts was supplied beyond the current PairToken declarations.

## Coverage

This response decides all six named functions, names the standard function and route-defining arguments for every mapping, identifies behavior not covered by the standard, and separately addresses maxima versus declared-plus-refunded inputs, raw-native redemption, duplicate entry paths, and the need for paired previews. Donation and compounding are assessed on their actual no-share-mint and no-supply-change behavior rather than treated as bundle exchanges.

## Conclusions

The accepted Standard Exchange redefinition covers the economic need for paired deposits and paired withdrawals when the currencies use their ERC-20 faces. It does not cover donation, compounding, or raw-native ETH handling.

| Function | Decision | Named standard route and arguments | Behavior not covered or mapping note |
| --- | --- | --- | --- |
| `depositPair` | **Map** | `exchangeBundleInForSingleOut`; pass `[amount0Max, amount1Max]` as `amountsIn` in `vaultTokens()` order, the share as `tokenOut`, `minShares` as `minAmountOut`, and the existing recipient and deadline. | The standard returns the share amount plus refunds; consumed amounts are `amountsIn[i] - amountsRefunded[i]`. It does not accept the native side as `msg.value`; use the wrapped ERC-20 face. |
| `previewDepositPair` | **Map** | `previewExchangeBundleInForSingleOut`; pass the two maxima in `vaultTokens()` order and the share as `tokenOut`. | `amountOut` is the share quote. Derive `used0` and `used1` by subtracting each refund from its declared maximum. No standalone paired preview remains necessary. |
| `redeemPair` | **Map** | `exchangeBundleOut`; pass the share as `tokenIn`, `shares` as `amountIn`, both pool-currency faces as `tokensOut`, `[min0, min1]` as `minAmountsOut`, and the existing recipient and deadline. | The standard pays wrapped ERC-20 outputs, not raw ETH on a native pool. It can also return an unkept share refund, which the old paired signature did not expose. |
| `previewRedeemPair` | **Map** | `previewExchangeBundleOut`; pass the share, share amount, and both pool-currency faces as `tokensOut`. | `amountsOut` supplies the two payout quotes in caller-specified output order. The quote uses wrapped faces and also exposes any pay-token refund. |
| `donate` | **Keep** | No accepted standard function performs this operation. | A bundle deposit mints an output and refunds unkept input; it does not book a contribution while minting no shares. Donation is therefore a distinct operation. |
| `compound` | **Keep** | No accepted standard function performs this operation. | An exchange route does not collect position fees and reinvest them without changing share supply. Compounding is therefore a distinct operation. |

Recommended resolutions of the specified ambiguities:

1. **Maxima versus declared amounts:** the difference is not enough to keep `depositPair`. Declare the maxima as `amountsIn`; the accepted refund rule returns the unkept part of each maximum, and consumed amounts are recoverable by subtraction. This preserves the economic bounded-input behavior without a second deposit interface.
2. **Raw-native redemption:** recommendation: do not keep `redeemPair` solely for raw ETH and do not extend the owner-locked standard in this response. Map the economic withdrawal to `exchangeBundleOut` with wrapped faces. If raw-native payout remains a product requirement, it needs a separate explicit product-surface or standards decision; this response does not invent that extension.
3. **Duplicate entry paths:** recommendation: dropping the paired mutators in favor of their standard mappings removes a second deposit/withdrawal entry path that could disagree with `exchangeBundleInForSingleOut` or `exchangeBundleOut` on accounting, maintenance, refunds, or previews. Keeping `donate` and `compound` does not recreate those exchange paths.
4. **Paired previews:** recommendation: once the paired mutators are mapped, neither paired preview is necessary as a separate function. The standard previews quote the actual standard routes and avoid maintaining a second quoting path that could diverge.

Thus four functions map onto named accepted standard functions, and two functions—`donate` and `compound`—remain because the standard does not perform their work.

## Limits

This is independent research consultation only. It does not implement or authorize implementation, amend or lock the PRD, edit the function-review file, or define a raw-native extension. No tests, builds, public searches, or peer-response reads were performed. Interface coverage does not prove implementation equivalence, gas feasibility, or preservation of PairToken-specific events and internal maintenance semantics.
