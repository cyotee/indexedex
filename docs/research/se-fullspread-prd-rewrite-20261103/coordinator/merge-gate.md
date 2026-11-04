# Merge gate

This is not the draft and not the PRD. A later override wins. The merged PRD must contain each row and must not leave the contradicted sentence beside it.

| Lock | Must say | Must not keep |
| --- | --- | --- |
| F1 | If the maximum is larger than the unbooked balance, refund that unbooked balance. Do not spend it. Do not pull the shortfall. A larger maximum is not a revert. | A sentence that pulls the shortfall or reverts on an overstated maximum. |
| F2 deposit | A share-minting deposit books `feesAccrued`. It does not credit those fees to the new depositor and does not swap them into the deposit. | Principal-only silence, or swapping collected fees into the deposit. |
| F2 exit | The caller owns `shares burned / total shares` of `feesAccrued` and of each booked balance, before the burn, rounded down. The rest stays booked. A one-token exit swaps the caller's opposing-token fee and booked claim with the unwanted reserve. Requested-token fees and booked claim are paid out. | Pay only the principal fraction. Do not pay the booked remainder. |
| F2 preview | The exit preview uses that same apportioning. Its `amountOut` matches execution and is the share valuation, including accrued fees. A mint preview does not credit existing fees. | An exit quote that omits the fee share. |
| F5 | A one-sided deposit and a one-token `donate` or `compound` choose the greatest liquidity the following add can take. Swap output is the other token that liquidity consumes. Unswapped input is the processed token that liquidity consumes. | A sentence that sizes the swap input as the processed-token amount the add itself consumes. |
| F6 | A one-token exit converts all unwanted principal plus the caller's opposing fee and booked claim, or reverts `AmountOutNotMet` and does not burn shares. The 48% remark is not an exit rule. | Pay, book, or keep that residual. A no-shortfall-revert on the former sleeve. |
| F7 | `Donation()` on `donate()`, no fields. `Compounded()` when a deposit is made from fees or booked tokens, no fields. Booked tokens are treated as fees. No fee-origin store. | `Compounded(address indexed token, uint256 amount)`. |
| F12 | Owner authority is a live `feeTo()` check. New modifiers. Reuse `OperableRepo`. Do not reuse the existing facets for that check. | Initialization stores `feeTo()` as the owner. |
| Sleeve | There is no local liquidity sleeve and no `liquidReservePercentageOfVault` target. | FS-OWN-04 and FS-OWN-12 as live sleeve rules. |
| Unlock | If another caller holds the unlock, do not call `unlock()`. Call `modifyLiquidity` and `swap` directly. No `UnderlyingUnavailable` for an unpullable fraction. | FS-OWN-31 as a live exit rule. |
| Batch | This vault can be included in a batch swap. That is not a revert. | An exclusion of this vault from a batch swap. |
| ETH | Callers send and receive WETH only. The vault does not accept or produce native ETH. `PkgInit.wrappedNative` is removed. FS-OWN-22 still substitutes WETH for native in `vaultTokens()`. The lock does not name the address read. Do not add an address source. | Wrap or unwrap at the vault boundary. A new WETH address binding. |
| Rate | Do not implement `getRate()` or `rateAsset()`. | A vault rate function. |
| Genesis | Initial shares are the liquidity value minus the 1,000 floor. `decimals()` is 18 and does not scale stored balances. | A rescaled genesis mint. |
| Pretransfer | `pretransferred == true` declares a held unbooked balance. Book local balances so a parking lot is distinct. Refund the difference between the maximum and the amount used. Do not refund the whole remaining unbooked balance. | A refund of the entire unbooked balance after a normal call. |
| Preview ABI | `previewExchangeIn` and `exchangeIn` keep selectors `0x89d61912` and `0xd02d3063` and return `(uint256 amountOut, uint256 amountRefunded)`. `exchangeOut` and `previewExchangeOut` do not gain a refund return. | A `WithRefund` sibling. |
| Consumers | Name the six fail-closed gates and the three one-word ABI bindings with path and line from the consumer report. Every other one-word reader in `INDEX.md` migrates. Do not paste the 1626-line index. | A claim that the consumer list is still missing. |
| Both-token exit | Pay the caller's claim in both tokens. Do not swap. | A swap on a both-token exit. |

Fail-closed gates to name:

- `StandardExchangeRateProviderFacet.sol` lines 103-106 and 121-125
- `WrappedStandardExchangeRateProviderTarget.sol` lines 65-68
- `CommonBufferMultiVaultStablePoolHookTarget.sol` lines 437-444
- `MixedBufferMultiVaultStablePoolHookTarget.sol` lines 463-470
- `CommonBufferMultiVaultWeightedPoolHookTarget.sol` lines 474-481

ABI bindings to name:

- `IStandardExchangeIn.sol` lines 45-48
- `insightsAbi.ts` lines 69-76
- `protocolDetfAbi.ts` lines 33-40
