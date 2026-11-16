# PairToken functions proposed for the full-spread vault

Saved 2026-10-30 from the discussion of `UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`. Locked decisions below are also written into that PRD. Unmarked functions are still open.

**Locked basis.** This vault adapts WeirVaults to the tokenized Standard Exchange standard. It is not based on PairToken. PairToken package inputs and economics are not authorized by inheritance. A PairToken aspect stays only if the owner explicitly authorizes it after a stated case. The PRD was updated on 2026-10-31 to remove the sibling sentence and the unauthorized economics. The update record is `docs/research/se-fullspread-prd-weir-align-20261031-01a18660/`.

The council included these PairToken family functions on top of the ordinary share, vault, Standard Exchange, and SY surfaces. The five shared facets are not in this list. `exchangeIn` and `previewExchangeIn` are the standard exact-input routes, so they are not listed as PairToken functions either.

## Standard Exchange return

**Locked.** The accepted definition is in `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md`. `previewExchangeIn` and `exchangeIn` keep their parameters and return `(amountOut, amountRefunded)`. There is no `WithRefund` name. The bundle interfaces in that report are accepted. `exchangeOut` does not gain a refund return. Updating the other vaults is acknowledged and not started. ## Paired money

**Locked.** The owner accepted the council recommendation in `docs/research/se-paired-money-necessity-20261030-01a18660/REPORT.md`.

- `depositPair` is not kept. Map it to `exchangeBundleInForSingleOut`. `tokenOut` is the share. `amountsIn` follows `vaultTokens()` order.
- `previewDepositPair` is not kept. Map it to `previewExchangeBundleInForSingleOut`. `tokenOut` is the share.
- `redeemPair` is not kept. Map it to `exchangeBundleOut`. `tokenIn` is the share. `tokensOut` are the two ERC-20 faces. A native leg uses its wrapper.
- `previewRedeemPair` is not kept. Map it to `previewExchangeBundleOut`. `tokenIn` is the share.
- `donate(token, amount)` stays. It adds tokens to the vault's book and mints no shares. No accepted route does that.
- `compound()` stays. It collects fees and puts them back into the position. It does not change the share supply.

The mapping is of the route. A paired exit on `exchangeBundleOut` still removes both currencies proportionally. It does not sell one leg to pay the other. `PairDeposited` and `PairRedeemed`, or renamed equivalents, are still emitted by the mapped routes. `vaultTokens()` order must stay stable, with the wrapped face at a native leg's index. Raw ETH is not decided. Dropping these selectors removes the only raw-ETH entry and exit currently named for this family. That is not a reason to keep them, and no ETH extension is added.

## Zap accounting

These explain a single-token deposit that the vault balances with a swap.

- `previewZapCredit(tokenIn, amountIn)` would have returned the shares a single-token deposit would mint, how much of each currency funds those shares, and how much is left uncredited. **Locked: absent.** It is not a Weir view. No replacement is authorized.
- `previewWithdrawalMode(shares, paired, tokenOut)` would have said whether a withdrawal would fully compound or only collect fees, and why. **Locked: do not implement.** The owner accepted the drop. Payout quotes use the accepted previews. This lock does not publish an internal compound-or-collect branch.
- `maxZapBps()` would have been the configured cap on how large a single-token deposit or compound swap may be. **Locked: absent.** The field is not authorized. No replacement cap is added.
- `maxZapTickMove()` would have been the configured cap on how far that entry swap may move the pool's tick. **Locked: absent.** No replacement tick bound is added. The entry swap uses Weir's range-boundary price limit, not this cap.

## Pool and position identity

These do not move money. They tell a caller what this vault holds.

- `poolManager()` is the Uniswap V4 manager this vault uses. **Locked: do not keep this as a full-spread family query.** It belongs to a new Protocol Aware standard: one Repo and Facet pair that stores and exposes the external components of one protocol. For Uniswap V4 that pair lives at `lib/crane/contracts/protocols/dexes/uniswap/v4/aware`. The V2 aware repos are the storage example, but V2 splits one component per repo. This standard keeps the protocol's components together, including the PoolManager and the Universal Router, and any other V4 component an integrator needs. The `v4/aware` directory exists and is empty. This decision does not implement that pair.
- `poolKey()` is the pool: both currencies, fee, tick spacing, and hook. Native ETH stays `address(0)` here. **Locked: keep the information, but not as a full-spread-only query.** It belongs to a reusable Uniswap V4 Position Repo that holds the relevant state of one position in one pool, so another contract can use the same repo.
- `wrappedNative()` would have been the wrapper used when a standard nonpayable call has to represent ETH. **Locked: do not implement the family getter.** The owner accepted the drop. Do not move the getter to the Position Repo. The accepted routes use the ERC-20 face already on `vaultTokens()`. This lock does not remove a package address binding, and it does not decide where that binding is stored.
- `rateAsset()` is the currency face used to denominate the SY accounting value. It is not `getRate`. **Locked: do not implement.** This vault does not designate one token for valuation or for operations. The ERC-5115 drop below is the same decision.
- `tickLower()` and `tickUpper()` are the full-range bounds of the one position. **Locked: keep them, and store them in the Uniswap V4 Position Repo.** PoolManager position state stores liquidity and fee growth, not the ticks. The ticks are inputs to the position key, so there is no PoolManager read to wrap.
- `positionLiquidity()` is the liquidity this vault has deployed in its position, not the local sleeve and not the whole pool's liquidity. **Locked: keep it, and wrap the PoolManager read.** `StateLibrary.getPositionInfo` returns that position's `uint128` liquidity when called with this diamond, the stored ticks, and salt `bytes32(0)`. It does not return token amounts.
- `localReserves()` returns the local balances of the underlying tokens. **Locked.** These are the liquidity-sleeve balances held in the vault, not the target percentage and not the deployed position.
- `basket()` would have been the removable position principal plus idle balances. **Locked: do not implement.** `IBasicVault.reserves()` is the replacement. Its meaning is below, and the custom facet wiring is not guessed.

## Liquidity sleeve

**Locked.** This family keeps a local liquidity sleeve so value can sit in the vault when the PoolManager is locked. The target percentage comes from `IVaultFeeOracleQuery.liquidReservePercentageOfVault(address vault)`. That oracle value is WAD: `1e18` is 100%. Apply that same percentage to each underlying token's owned amount. Do not price the two tokens into one combined value. `localReserves()` returns the actual local balances, not that target. Owned amount is the same per-token sum as `reserveOfToken`: local plus deployed. Refill, shortfall, and whether a locked caller may spend the sleeve are not specified.

## ERC-5115

**Locked: do not install ERC-5115.** There is no underlying LP token, so Standardized Yield is invalid for this vault. That drops `syMoneyFacet`, `syQueryFacet`, and `rateAsset()`. This is an authorized divergence from the SE package standard.

## Custom Basic Vault reserves

**Locked: drop `basket()`.** `IBasicVault.reserves()` and `reserveOfToken(address)` wrap the deployed-reserve reads, in `vaultTokens()` order for `reserves()`. There is no local term. The owner replaced the local-plus-deployed specification on 2026-11-02.

**Locked: reuse `vaultTokens()` from `MultiAssetBasicVaultFacet`.** Do not reimplement that getter. The custom facet exposes `reserveOfToken` and `reserves` only. The diamond cut maps `vaultTokens` to `MultiAssetBasicVaultFacet` and the other two selectors to the family facet. Do not install the multi-asset `reserveOfToken` or `reserves` implementations. Those read `MultiAssetBasicVaultRepo._reserveOfToken`, a stored balance in slot `indexedex.vaults.basic`. That stored balance is not the local-plus-deployed view.

**Locked: the deployed term is the position's current token amounts plus unpaid fees.** For each underlying token, that is the amount implied by this position's liquidity, the current pool price, and the stored ticks, plus fees owed to this position in that token and not yet collected. PoolManager does not store those amounts. `reserves()` wraps those existing reads. This lock does not add a new formula. A booked local remainder is not part of the wrapped read.

## Rate

The council added this. It is not a PairToken function. This section is not separately locked.

- `getRate()` would return the executable value of one whole share in `rateAsset`. The later council said not to install it until a rate policy is chosen. The locked `rateAsset` decision makes that definition impossible: there is no designated token to denominate it. The PRD now withdraws `getRate` for that reason. A replacement rate is not authorized.

## Owner answers locked 2026-11-01

**Locked.** These answers are also written into the PRD as FS-OWN-11 through FS-OWN-28. They override conflicting sentences.

- The 1,000-share floor is minted to `address(0)` and is part of `totalSupply()`.
- Sleeve adjustment is best-effort after deposit, withdrawal, and compound, and only when local balance differs from target by more than 5% of target. A shortfall does not revert.
- Deployed liquidity is used whenever it is accessible. The sleeve is used only when deployed liquidity is inaccessible or insufficient.
- `compound()` deploys booked idle, is permissionless, and returns without reverting when there are no fees. A nonzero compound emits `Compounded(address indexed token, uint256 amount)` per token.
- Redemptions take deployed liquidity first and may swap through the pool.
- `PkgInit.poolManager` is written into the Protocol Aware Repo at initialization.
- There is no `wrappedNative()` getter. Callers use WETH. Native ETH is wrapped or unwrapped only at the pool boundary.
- The Robinhood aware set is the seven named constants in `ROBINHOOD_MAIN.sol`.
- Unknown `reserveOfToken` returns zero. Views do not revert. Sleeve uses the local snapshot. Deployed value is live.
- Unbooked balances are ignored. Redeemable idle is the booked counter.
- Share `donate` burns shares and does not withdraw. Underlying `donate` is booked as local idle.
- `vaultTokens()` is currency0, then currency1, with WETH substituted for native.
- "Outside the inherited domain" is deleted. The pool must be initialized and hookless.
- Facet cuts name selectors. The usage fee is `usageFeeOfVault` minted to `feeTo` when shares are minted.
- Bundle deposit does not run `_balance`. `exchangeIn` can swap underlying to underlying.
- Disablement is `VaultDisabled` from `IVaultRegistryDisableQuery.isDisabled`.
- Share decimals are 18. A missed deadline reverts `DeadlineExceeded(deadline, block.timestamp)` first.

## Owner answers locked 2026-11-01, second pass

**Locked.** These answers are also written into the PRD as FS-OWN-29 through FS-OWN-31. They override the earlier claim that this vault can take a PoolManager lock held by another caller.

- If nobody holds the unlock, the vault calls `unlock()` and uses deployed liquidity first.
- If another caller holds the unlock, the vault does not call `unlock()`. It may `swap` and `modifyLiquidity` on that open unlock.
- If that call still cannot fill the order, revert the shared error `UnderlyingUnavailable(address protocol, uint256 required, uint256 available)`.
- On the vault's own unlock, a pool shortfall is filled from the sleeve.
- This vault does not implement `getRate()`. The DETF hooks use another rate provider.

## Owner answers locked 2026-11-01, third pass

**Locked.** These answers are also written into the PRD as the FS-OWN-21 replacement and FS-OWN-30 through FS-OWN-33.

- A redemption on the vault's own unlock pays the caller's fraction of the reserve. It does not have a leftover shortfall, and it does not revert for one.
- Unused deposit input is refunded to the payer. It does not become shares and it is not given to other shareholders.
- A one-sided share mint runs the balancing swap. A bundle deposit does not.
- An underlying donation is deployed into the pool before `donate` returns. A share donation still burns shares and does not withdraw.
