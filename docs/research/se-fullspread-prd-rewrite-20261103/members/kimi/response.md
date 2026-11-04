# Kimi initial independent response

## Identity

- Member: `kimi`
- Profile: research
- Phase: initial independent response
- Run: `se-fullspread-prd-rewrite-20261103`
- Owned path: `members/kimi/response.md`
- Requested role: `council-member`
- Requested model: `kimi-coding/k3.1-pro:high`, global route
- Runtime identity not supplied by the assignment: not exposed
- Peers read before submission: no

## Question and targets

What is the single complete replacement text for the Uniswap V4 full-spread Standard Exchange vault PRD, copied from the locked decisions?

The target is `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`. The replacement must preserve its section order and surviving requirement IDs, remove every sentence contradicted by a later lock, incorporate the binding pretransfer rule and accepted return ABI, and identify the required preview-consumer migration without reproducing the occurrence index.

## Evidence

Source observations:

- The current PRD supplies the section order, surviving requirement IDs, package structure, unlocked execution rules, hook fixtures, and acceptance rows.
- `IMPLEMENTATION_PLAN_BLOCKERS.md`, including its 2026-11-03 owner overrides, is the later authority. It removes the sleeve, nets the usage fee out of newly minted shares, caps this vault's applied usage fee at 30%, books deposit-accrued fees, apportions fees and booked balances on exit, restricts donation and compounding to the live `feeTo()` owner or an operator, and defines the locked events, views, share units, aware facets, rate-provider configuration, and pretransfer behavior.
- `docs/vaults/PRETRANSFER_DIRECTIVE.md` binds all Standard Exchange calls taking `pretransferred`: only unbooked held balances are available, booked balances are not pretransfer credit, and the overstated-maximum case refunds the unbooked balance without spending it or pulling a shortfall.
- `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md` accepts in-place tuple returns for `previewExchangeIn` and `exchangeIn`, with unchanged parameters and selectors, and does not add a refund return to `exchangeOut`.
- `docs/research/se-fullspread-preview-consumers-20261103/REPORT.md` names six production consumers that reject a non-32-byte successful preview and three ABI bindings that still declare one word. Its `INDEX.md` is the complete textual occurrence inventory, not a claim that every occurrence decodes the return.

Editorial inference is limited to placing those locked rules into the existing PRD structure and updating acceptance rows that would otherwise assert withdrawn behavior. No new economics, event, error, or selector is inferred.

## Assumptions

- A current PRD sentence remains only where no later lock contradicts it.
- References to Weir describe the expressly retained money operations, not the removed automatic compounding, sleeve, native payout, or treasury-fee behavior.
- The replacement records requirements only; it does not treat the old advisory participation table as a new vote on this revision.

## Coverage

The Conclusions section is the complete replacement PRD. It retains sections 1 through 10 and the surviving FS-X, FS-OWN, FS-FACET, FS-ARCH, FS-PKG, FS-MONEY, FS-UNLOCK, FS-RATE, FS-HOOK, FS-TEST, and FS-A identifiers. It integrates B-01 through B-13, the 2026-11-03 F1, F2, F5, F6, F7, and F12 overrides, the stated filled readings, the pretransfer directive, the tuple ABI, all six fail-closed consumers, all three one-word ABI bindings, the full `INDEX.md` migration rule, the integration matrix, and the audit-regression scope.

## Conclusions

# Uniswap V4 full-spread Standard Exchange vault PRD

Revision **fullspread-se-prd-locked-20261103-r1**. This revision replaces contradicted sentences with the locked decisions in `IMPLEMENTATION_PLAN_BLOCKERS.md`, including the 2026-11-03 overrides. It is not member-approved text, not an implementation, and not a safety clearance. The later locks override every conflicting earlier sentence. The pretransfer rule is `docs/vaults/PRETRANSFER_DIRECTIVE.md`.

## 1. Goal

Build `UniswapV4FullSpreadStandardExchangeVault`.

One registry-deployed Crane diamond owns one Uniswap V4 pool key, one full-range position, and one ERC-20 share supply. It accounts for collected fees and booked token balances without maintaining a local liquidity sleeve. The diamond is the position owner. Public shares are proportional claims on the deployed position and the holder's locked share of accrued fees and booked balances.

This family adapts the cited money operations of `contracts/protocols/strategy/weir/WeirVaults.sol` to the tokenized Standard Exchange standard, subject to the later locks. It has one ERC-20 share, one pool, and one full-range position. It does not copy Weir's manager of many virtual vaults.

It is not a sibling of PairToken and does not inherit PairToken economics by requirement ID. FS-OWN-01 through FS-OWN-33 stay locked as revised here. A PairToken economic or package choice stays only where one of those locks already keeps it.

### 1.1 What this family is not

- Not a source copy of Weir's multi-vault manager, and not a mechanical wrapper around its internal share ledger.
- Not Upper/Lower Wings. No second range and no rebalance facet.
- Not a singleton of many pools, a second share ledger, or a shares-of-shares wrapper.
- Not an ERC-4626 product. Do not install `asset()`. Current hooks treat that selector as wrapper-share inventory. Adding it to turn a rejected identity bind into a pass is forbidden.
- Not a hook-package redesign. A hook change is FS-HOOK-04, raised only with a cited rejecting function.
- Not a local-sleeve vault. It has no target local reserve percentage and no sleeve adjustment operation.

### 1.2 Deltas

| ID | Delta |
| --- | --- |
| FS-X01 | Canonical exact-input `exchangeIn` executes while the bound PoolManager is already unlocked, without a nested `unlock`. Ordinary user entry still opens its own unlock, once per planned manager action. |
| FS-X02 | Withdrawn by FS-OWN-03. Do not install `getRate`. There is no designated `rateAsset` to denominate it. |
| FS-X03 | Tests place this share with another SE vault share in the current buffer-hook families, using the fixture in FS-HOOK-02 and the external rate-provider configuration in FS-OWN-29. Those hook packages are not edited here. |
| FS-X04 | Single-token entry does not require the selected swap to consume its entire input. There is no `IncompleteConversion` check. Unused declared input is returned to the payer under FS-OWN-20 and FS-OWN-32. A positive credit is returned to the depositor and is not booked without shares. Issuance follows FS-MONEY-01, not S1-ACC-07. This row does not change the accepted one-token exit. |
| FS-OWN-01 | `poolManager()` is not a family query. The diamond uses a Uniswap V4 Protocol Aware Repo and Facet supplied as a Crane package input. |
| FS-OWN-02 | Pool-key and position identity live in the reusable Crane `UniswapV4SinglePositionAware` Repo and Facet, not a full-spread-only getter. |
| FS-OWN-03 | Do not implement `rateAsset()`. This family designates no single token for valuation or operations. |
| FS-OWN-04 | There is no local liquidity sleeve. Do not read `liquidReservePercentageOfVault` for this vault, maintain a target local balance, or install `localReserves()` as a sleeve getter. |
| FS-OWN-05 | Do not install ERC-5115. Drop `syMoneyFacet` and `syQueryFacet`. |
| FS-OWN-06 | Store `tickLower` and `tickUpper` in `UniswapV4SinglePositionAware`. Wrap PoolManager through `StateLibrary` for `positionLiquidity()`. |
| FS-OWN-07 | Do not implement `basket()`. `IBasicVault.reserves()` is the deployed-reserve view, including unpaid position fees and excluding local booked balances, on a custom facet. Its other semantics are not specified. |
| FS-OWN-08 | `previewExchangeIn` and `exchangeIn` keep their parameters and selectors and return `(uint256 amountOut, uint256 amountRefunded)`. No `WithRefund` sibling. The required consumer migration is specified below. |
| FS-OWN-09 | Do not keep `depositPair`, `previewDepositPair`, `redeemPair`, or `previewRedeemPair`. Map them to the accepted bundle routes. Keep `donate` and `compound`. `donate` is an explicit exception and is not a Weir function. `compound` is owner-or-operator harvest-and-reinvest, not a PairToken ratio swap. |
| FS-OWN-10 | Do not implement `previewWithdrawalMode` or a family `wrappedNative()` getter. `previewZapCredit`, `maxZapBps`, and `maxZapTickMove` are absent. No replacement view, cap, or tick bound is added. |

FS-OWN-08 requires the following six fail-closed consumers of the old 32-byte preview return to migrate to the 64-byte tuple. The paths and lines are from `docs/research/se-fullspread-preview-consumers-20261103/REPORT.md`:

1. `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:103-106`, the empty-supply preview, whose `data.length != 32` gate returns zero.
2. `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:121-125`, the live preview, with the same 32-byte gate and one-word decode.
3. `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/wrapped/WrappedStandardExchangeRateProviderTarget.sol:65-68`, whose gate returns `(false, 0)`.
4. `contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolHookTarget.sol:437-444`, whose `ret.length != 32` gate returns false before a one-word decode.
5. `contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolHookTarget.sol:463-470`, with the same gate.
6. `contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolHookTarget.sol:474-481`, with the same gate.

The three ABI bindings that still declare one word, also with paths and lines from that report, are:

- `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:45-48`, declaring `returns (uint256 amountOut)` for selector `0x89d61912`.
- `frontend/apps/indexedex/app/insights/lib/insightsAbi.ts:69-76`, declaring one `uint256` preview output.
- `frontend/packages/protocol/src/protocolDetfAbi.ts:33-40`, declaring one `uint256 amountOut` preview output.

Every other one-word reader of `previewExchangeIn` in `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md` migrates to `(uint256 amountOut, uint256 amountRefunded)`. This includes `contracts/test/bases/FundedThresholdAssertions.sol:60-63`, which decodes one word without a length check. The 1626-line index is the migration inventory; it is not copied into this PRD. A call that ignores the returned word still migrates if it remains bound to the old interface.

`previewExchangeIn(address,uint256,address)` keeps selector `0x89d61912`. `exchangeIn(address,uint256,address,uint256,address,bool,uint256)` keeps selector `0xd02d3063`. Both return `(uint256 amountOut, uint256 amountRefunded)`. `exchangeOut` and `previewExchangeOut` do not gain a refund return. The ERC-165 id of `IStandardExchangeIn` stays unchanged because the function selectors stay unchanged; return width is not represented by ERC-165.

### 1.3 Owner-locked decisions

These owner decisions are locked. They override every conflicting sentence in this file. They do not implement the repos.

**FS-OWN-01.** `poolManager()` is not a full-spread family query. It belongs to the Uniswap V4 Protocol Aware standard: one Repo and one Facet that store and expose the external components of one protocol. Implement that pair in the Crane submodule under `lib/crane/contracts/protocols/dexes/uniswap/v4/aware`. The facet exposes the stored components through externally callable getters. It is a package input on this vault, and this vault's package uses it to initialize vault instances. Do not implement a family `poolManager()` selector. Crane tests for that facet are part of this directive.

**FS-OWN-02.** `poolKey()` stays as information, not as a full-spread-only getter. It belongs to the reusable Crane `UniswapV4SinglePositionAware` Repo and Facet for one position in one pool. That pair is a package input on this vault, its getters are externally callable, and Crane tests for it are part of this directive. The repo stores the full `PoolKey`, `tickLower`, `tickUpper`, and the position salt per vault instance. This vault uses the full-range position and salt `bytes32(0)`. Do not put a family-only `poolKey()` selector on the full-spread query facet.

**FS-OWN-03.** Do not implement `rateAsset()`. This vault does not designate one token for valuation or for operations. `PkgArgs` has no `rateAsset`. Do not install `getRate` into a rate asset, and do not add the rate errors that existed only for that function. Do not install `StandardExchangeRateProviderFacet` on this vault and call its result this family's rate. External rate-provider instances are configured by hooks under FS-OWN-29.

**FS-OWN-04.** There is no local liquidity sleeve. Do not keep a target from `liquidReservePercentageOfVault(address(this))`. Do not move a local balance toward a target after a deposit, withdrawal, or `compound()`. `localReserves()` is not restored as a sleeve getter. Collected fees and booked remainders are accounted under FS-OWN-14, FS-OWN-20, FS-OWN-21, and FS-OWN-30; they are not a sleeve.

**FS-OWN-05.** Do not install ERC-5115. There is no underlying LP token, so `IStandardizedYield` is invalid here. Drop `syMoneyFacet` and `syQueryFacet`, including `deposit`, `redeem`, `exchangeRate`, and the other Standardized Yield selectors. This is an authorized divergence from the SE package. It confirms FS-OWN-03. Do not replace the dropped rate with NAV or another denomination.

**FS-OWN-06.** Keep `tickLower()` and `tickUpper()` in `UniswapV4SinglePositionAware`. Keep `positionLiquidity()`. It returns only the liquidity deployed in this vault's position. Wrap `StateLibrary.getPositionInfo` on the PoolManager for this diamond, the stored ticks, and salt `bytes32(0)`. That read returns `uint128` liquidity. It is not a token amount, not a local balance, and not the whole pool's liquidity. `StateView` is the off-chain wrapper of the same read and is not the vault's dependency. `PositionManager` reads an NFT position this vault does not hold.

**FS-OWN-07.** Do not implement `basket()`. `reserves()` returns the deployed amount of each vault token, in `vaultTokens()` order. `reserveOfToken(address)` returns that deployed amount for one token and returns zero for an unknown token. Reuse `vaultTokens()` from `MultiAssetBasicVaultFacet`. Do not reimplement it. The custom facet exposes only `reserveOfToken` and `reserves`. The cut maps `vaultTokens` to `MultiAssetBasicVaultFacet` and the other two selectors to the family facet. Do not install the multi-asset reserve functions. For each underlying token, the deployed amount is the amount implied by this position's liquidity, the current pool price, and the stored ticks, plus fees owed to this position in that token and not yet collected. Use the existing position-amount and fee-owed reads; do not add a new conversion formula. There is no local term and no last-committed snapshot. A booked local remainder is excluded until a later `donate()` or `compound()` deploys it.

**FS-OWN-08.** The accepted Standard Exchange definition is in `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md`. `previewExchangeIn` and `exchangeIn` keep their current parameters and return `(uint256 amountOut, uint256 amountRefunded)`. There is no `WithRefund` sibling. Selectors stay `0x89d61912` and `0xd02d3063`. Every other vault and every consumer identified in FS-OWN-08 of section 1.2 must be updated to that return ABI. `exchangeOut` and `previewExchangeOut` do not gain a refund return. The bundle interfaces in that report are accepted for the standard.

**FS-OWN-09.** Do not install `depositPair`, `previewDepositPair`, `redeemPair`, or `previewRedeemPair`. Map deposit to `exchangeBundleInForSingleOut` and `previewExchangeBundleInForSingleOut`, with `tokenOut` as the share. Map redeem to `exchangeBundleOut` and `previewExchangeBundleOut`, with `tokenIn` as the share and `tokensOut` as the two ERC-20 faces. Keep `donate` and `compound`. `donate` is an explicit exception. `compound()` harvests and reinvests collected fees and booked tokens under FS-OWN-14, without a PairToken ratio swap or quarter-cap and without Weir's treasury performance fee. The mapped both-token redeem removes both currencies proportionally, pays the caller's locked claim in both tokens, and does not sell one leg to pay the other. A bundle deposit emits `PairDeposited(address indexed caller)` and a bundle redeem emits `PairRedeemed(address indexed caller)`, with no other arguments. The ERC-20 `Transfer` records the share mint or burn, and PoolManager events record token amounts.

**FS-OWN-10.** Do not install `previewWithdrawalMode` and `wrappedNative()`. Payout quotes use the accepted previews. Do not move `wrappedNative()` to the Position Repo. The accepted routes use the ERC-20 face on `vaultTokens()`. `previewZapCredit`, `maxZapBps`, and `maxZapTickMove` are absent. No replacement view, cap, tick bound, or hidden constant is added.

### 1.4 Owner answers locked 2026-11-01 through 2026-11-03

These answers are locked. Later answers override earlier conflicting answers.

**FS-OWN-11.** The genesis floor is `MIN_SHARES` (`1_000`) minted to `address(0)` through the ERC-20 mint path that writes balance and supply directly. That balance is part of `totalSupply()`. There is no second share ledger and no other floor holder.

**FS-OWN-12.** There is no sleeve target and no post-operation sleeve adjustment. Do not attempt to move either token's local balance toward `liquidReservePercentageOfVault(address(this))` after a deposit, withdrawal, or compound. A remainder from `donate()` or `compound()` is booked under FS-OWN-14 and FS-OWN-21; it is not a target balance.

**FS-OWN-13.** If nobody holds the PoolManager unlock, this vault calls `unlock()` once per planned manager action and uses deployed liquidity. If another caller already holds it, this vault must not call `unlock()`. Canonical `exchangeIn`, including a one-token exit, may call `modifyLiquidity` and `swap` directly on that open unlock under FS-UNLOCK-02. It never takes another caller's lock, and it settles this diamond's own deltas before returning. This vault can be included in a batch swap with other Uniswap V4 pools; that composition is not a revert. There is no sleeve payment and no `UnderlyingUnavailable` case for an unpullable deployed fraction. The other unlocked public methods retain FS-UNLOCK-01's rejection.

**FS-OWN-14.** `compound()` is restricted by new ownership and operable modifiers to the address currently returned by `feeTo()`, checked live, or an operator authorized in `OperableRepo`. Do not reuse the existing facets for the owner check, and do not store the initial `feeTo()` as the owner. Any other caller reverts. `compound()` has no donation input. A deposit, withdrawal, and `exchangeIn` do not call `compound()`.

`compound()` takes collected fees and the booked remainder and processes that combined balance. Booked tokens are treated as fees, including a booked donation remainder; there is no fee-origin store. If there are no fees, no donation, and no booked remainder, the call returns with no state change and no event. A booked remainder is still processed.

For a one-token `compound()`, choose the greatest liquidity the following add can take. The swap output is the other token that liquidity consumes. The unswapped input is the processed token that liquidity consumes. Rounding leaves any remainder in the input token. The swap input is not the processed-token amount the add itself consumes. The swap uses the unbounded entry price limit. If the combined balance already holds both tokens, do not swap: deposit the matched pair, fully use the token that is scarcer relative to the position ratio, and book the excess of the other token. The scarcer token is not determined by comparing raw balances without the ratio.

Book the actual held balance after the deposit, not a calculated leftover. This also books a stray transfer and can book a non-atomic pretransfer; callers must keep a pretransfer atomic. Best-effort means the simplest secure process, with no extra attempt, fallback, or swallowed failure. A failed step reverts. A remainder from that simplest deposit is booked, not returned to the caller, and does not itself cause a revert. The deployed position is not swapped.

Emit `Compounded()` with no fields when a deposit is made from collected fees or booked tokens, including a `compound()` call that deposits. A call that deposits nothing does not emit `Compounded()`. The vault emits no substitute swap or liquidity-add event carrying amounts; PoolManager `Swap` and `ModifyLiquidity` events with the vault as `sender` carry those amounts, price, and liquidity. A caller deposit or withdrawal is correlated by the Standard Exchange event in the same transaction. Owner or operator restriction does not prevent a sandwich of that caller's own swap, and that exposure is accepted.

**FS-OWN-15.** A redemption takes the exiting holder's deployed fraction. A both-token exit pays the caller's principal, accrued-fee claim, and booked claim in both tokens and does not swap. A one-token exit converts all unwanted withdrawn principal plus the caller's opposing-token fee and booked claim into the selected token, or reverts `AmountOutNotMet` and does not burn shares. It does not pay, book, or keep that residual. It swaps only the exiting holder's claim, not other holders' booked fees or staying holders' inventory. Entry and redemption swap limits stay `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`. No new price check, tick bound, or fee cap is added.

**FS-OWN-16.** The PoolManager, Position Descriptor, Position Manager, Quoter, State View, Reserves Lens, and Universal Router are package immutables set when the package is deployed. When the package initializes a vault instance, it writes those immutable addresses into the Uniswap V4 Protocol Aware Repo. The repo is not given a second per-vault copy. Initialization does not store the current `feeTo()` as an owner.

**FS-OWN-17.** Do not install `wrappedNative()`, and remove `PkgInit.wrappedNative`. Callers send and receive WETH only. The vault does not accept or produce native ETH at its public token boundary. Native ETH is wrapped or unwrapped only at the pool boundary. The wrapper is the network `WETH` constant, `WETH9` on Robinhood, not a package input.

**FS-OWN-18.** The Protocol Aware Repo stores the PoolManager, Position Descriptor, Position Manager, Quoter, State View, Reserves Lens, and Universal Router supplied by the package immutables. A deployment on another chain uses the same package code and passes that chain's addresses. Do not hardcode `ROBINHOOD_MAIN.sol` into the package; its constants are Robinhood values, not the storage rule. The Protocol Aware Facet is implemented and tested in Crane and used as a package input.

**FS-OWN-19.** No view reverts by a vault error. An unsupported view route returns zero while the execution route still reverts. `reserveOfToken` returns zero for an address that is not in `vaultTokens()`, and `previewExchangeOut` returns zero. `exchangeOut` still reverts `ExchangeOutNotAvailable()` and moves no tokens. A zero preview is not a promise that execution succeeds. A busy or unlocked manager is not a view revert: economic views return the computed value. `reserves()` and `reserveOfToken` wrap the live deployed-reserve reads under FS-OWN-07, with no local term and no last-committed snapshot. There is no new quote step-cap error. An out-of-gas revert is an EVM error, not a vault error defined by this PRD.

**FS-OWN-20.** `docs/vaults/PRETRANSFER_DIRECTIVE.md` is binding. Unbooked token balances are not reserves, not a sleeve, and not redeemable idle. `pretransferred == true` declares use of a held unbooked balance up to the caller's maximum; it does not claim the whole sitting balance. A booked remainder is not that balance and is not spent as pretransfer credit. The vault does not ask where the tokens came from.

If the caller's maximum is within the unbooked balance, the refund is the maximum minus the amount used, paid in the provided token. The vault does not refund the whole remaining unbooked balance in that case. If the maximum is larger than the unbooked balance, refund that unbooked balance, do not spend it, and do not pull the shortfall. A larger maximum is not a revert. A balance sitting on the vault is not credit beyond the declared maximum, and the unbooked remainder is not sent to `msg.sender` merely because it exists. A non-atomic pretransfer is the caller's risk. An address without bytecode cannot pretransfer. A burn uses the caller's shares; shares parked on the vault are not pretransfer credit.

**FS-OWN-21.** `donate` accepts `vaultTokens()` and the share. It is restricted by the same live-`feeTo()` owner-or-`OperableRepo` operator modifiers as `compound()`. It reverts when `totalSupply` is zero, before any swap. A share donation burns the shares and does not withdraw or swap them. No shares are minted for an underlying donation. Emit `Donation()` with no fields when `donate()` is called.

`donate()` also compounds. It uses tokens already transferred when `pretransferred` is set and pulls the directed amount otherwise. It then takes collected fees and the booked remainder and processes that combined balance. A one-token donation swaps its own tokens toward the position's ratio and deploys that liquidity before returning, using the same greatest-liquidity rule and unbounded limit as FS-OWN-14. It does not take holders' opposite token or swap the deployed position. If the combined balance already holds both tokens, the call is a proportional deposit and does not swap. A remainder is the actual held balance after the deposit and is booked, not returned to the donor. A deposit, withdrawal, and `exchangeIn` do not call `donate()` or deploy and swap a booked remainder.

**FS-OWN-22.** `vaultTokens()` is PoolKey `currency0`, then `currency1`, with `WETH` substituted for native. The pool-key check is only that the pool is initialized on the bound manager and the hook is `address(0)`. There is no additional inherited-domain exclusion.

**FS-OWN-23.** The diamond cut names the installed selectors. Do not install every selector exposed by `MultiAssetBasicVaultFacet`. `vaultTokens` is that facet. `reserveOfToken` and `reserves` are the family facet. The Protocol Aware and `UniswapV4SinglePositionAware` getters are externally callable through their package-input facets. No family `poolManager()` or family-only `poolKey()` is installed.

**FS-OWN-24.** On a new share-minting deposit, take the usage fee from the new shares that deposit mints; do not mint fee shares on top. If `feeTo` is not `address(0)`, let `grossShares` be the shares the deposit would mint before the fee, and let `feeShares = mulDiv(grossShares, appliedUsageFee, 1e18)`. Mint `feeShares` to `feeTo` and `grossShares - feeShares` to the depositor. Skip either zero mint. Do not mint beyond `grossShares`, and do not mint a fee on the fee shares.

On the first deposit, `grossShares = added liquidity - 1,000`. The separate 1,000-share floor mint to `address(0)` is not part of `grossShares` and is not a fee mint. Supply grows by `grossShares` plus the floor. On a later deposit, supply grows only by `grossShares`. `previewExchangeIn` when minting shares, `previewExchangeBundleInForSingleOut`, and `minAmountOut` use the depositor's net shares.

The Fee Oracle is not restricted and may store any WAD percentage up to `1e18`, including a per-vault override. This vault clamps its resolved `usageFeeOfVault(address(this))`: a value above 30% is applied as 30%, and a value at or below 30% is applied as read. Thirty percent is `3e17` WAD. The clamp is in this vault's read and does not write the oracle. The same clamped value is used in netting and share previews. The existing `mulDiv` precision is retained, including the ability to charge 0.001% (`1e13` WAD). Do not round to three digits and do not add a minimum fee. A configured zero fee stays zero.

The usage fee is charged only when this vault mints shares. An underlying-to-underlying `exchangeIn` is a pass-through pool swap, mints no shares, and takes no usage fee. No exact-out gross-up, fee-increase delay, exit fee, or new 0% override is added. Existing-holder dilution through an additional unbacked mint is forbidden.

**FS-OWN-25.** A bundle deposit adds the declared amounts in proportion and returns the rest. It does not run a balancing swap. `exchangeIn` supports an underlying-to-underlying swap on the bound pool as a pass-through that mints no shares and takes no usage fee.

**FS-OWN-26.** Inbound issuance checks `IVaultRegistryDisableQuery.isDisabled(address(this))` and reverts `VaultDisabled(address)`, as `UniswapV2StandardExchangeCommon._requireNotDisabled` does.

**FS-OWN-27.** Share `decimals()` returns 18 as metadata only. The deployed reserve used for issuance is one raw V4 `liquidity` number. Token amounts stay in their own decimals when passed to `getLiquidityForAmounts`. Token-decimal scaling and `decimals()` do not enter the share formula, and stored share balances and the floor are not rescaled to `1e18`.

Before the usage fee, first-deposit shares are `added liquidity - 1,000`. After the first deposit, gross shares are `added liquidity * totalShares / existing liquidity`. On a burn, remove `liquidity * shares / totalSupply`; `totalSupply` includes the floor. Integer division rounds down. Positive supply with zero deployed liquidity is unreachable after the sleeve removal, so no special zero-liquidity denominator is added.

**FS-OWN-28.** A missed deadline reverts `IStandardExchangeErrors.DeadlineExceeded(deadline, block.timestamp)` before any other work.

**FS-OWN-29.** This vault does not implement `getRate()` or `rateAsset()`, stores no rate-provider address, and exposes no rate-provider getter. A hook leg that needs a rate uses an external rate-provider instance deployed by `IStandardExchangeRateProviderDFPkg` for this vault and one rate target. `PkgArgs` for that provider carries `reserveVault`, `rateSubject`, and `rateTarget`. The hook configures the provider address; the vault does not know it.

One vault can have as many provider instances as it has `vaultTokens()`. That is the maximum useful number, not an enforced cap. Required hook rows use this vault as the rate subject and liquidity in the test pool, with one scenario for each underlying token so the integrated token can be token0 or token1. Separate pools may hold the same vault with providers whose `rateTarget` values differ, proving that two pools can value the same vault at different targets. Those rows are compatible requirements, not unresolved missing-rate records. The provider and all other old preview consumers migrate to the tuple return under FS-OWN-08.

**FS-OWN-30.** On the vault's own unlock, a redemption pays the caller's fraction of the deployed position and the caller's fraction of `feesAccrued` and each booked balance. The caller's share is `shares burned / total shares` measured before the burn, with each apportioning calculation rounded down. Book the remainder for other holders.

A both-token exit pays that claim in both tokens and does not swap. In a one-token exit, the caller's requested-token fees and requested booked claim are paid directly in the requested token. All unwanted withdrawn principal plus the caller's opposing-token fees and opposing booked claim are swapped into the requested token. If that conversion cannot meet the caller's minimum, revert `AmountOutNotMet` and do not burn shares. The old principal-only payment and no-leftover-shortfall-revert sentences do not apply.

An exit preview uses that same apportioning and the same swap as execution, so its quoted `amountOut` matches execution. That exit quote is the share valuation and includes accrued fees. A mint preview does not credit the new depositor with existing fees.

**FS-OWN-31.** If another caller holds the unlock, canonical `exchangeIn` does not call `unlock()`. A one-token exit calls `modifyLiquidity` and `swap` directly on that open flag, pulls the caller's deployed fraction, swaps only the exiting claim under FS-OWN-30, and settles this diamond's own deltas before returning. There is no sleeve fallback and no `UnderlyingUnavailable` for an unpullable fraction. The manager does not refuse that call merely because another caller holds the unlock.

**FS-OWN-32.** User input that does not become liquidity is refunded to the payer under FS-OWN-20. It is not minted into shares and is not left for other shareholders. A positive credit from settlement is returned to the depositor. This user-entry refund rule does not convert a `donate()` or `compound()` remainder into a caller refund; those remainders are booked under FS-OWN-14 and FS-OWN-21.

**FS-OWN-33.** A one-sided share mint chooses the greatest liquidity the following add can take. The swap output is the other token that liquidity consumes. The unswapped input is the processed token that liquidity consumes. Rounding leaves any remainder in the input token. The swap input is not the processed-token amount the add itself consumes. The swap uses the unbounded entry limit, and unused declared input is refunded under FS-OWN-20 and FS-OWN-32. A bundle deposit does not run that swap; it adds the declared amounts in proportion and returns the rest.

## 2. Authority and precedence

| Source | Role |
| --- | --- |
| `contracts/protocols/strategy/weir/WeirVaults.sol` | Source of the deposit, withdrawal, issuance, and compound rules expressly retained in this PRD. Its multi-vault manager, administration surface, automatic-compound ordering, idle-sleeve behavior, native payout, and treasury performance fee are not inherited where the locks replace them. |
| `IMPLEMENTATION_PLAN_BLOCKERS.md`, including the 2026-11-03 overrides | Later owner authority for the integrated fee, sleeve, fee-and-booked-claim, event, ownership, view, aware-facet, share-unit, pretransfer, and rate-provider rules. |
| `docs/vaults/PRETRANSFER_DIRECTIVE.md` | Binding pretransfer attribution and refund rule. |
| `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md` | Accepted exact-input tuple ABI and bundle interfaces. |
| FS-FACET-01 and FS-PKG-01 | This family's package inputs. No PairToken package field or economic rule is inherited. |
| `contracts/hooks/uniswap/v4/standardExchange/` | Current hook bindings. Do not redesign them here. |
| `CLAUDE.md`, `docs/agent/INDEXEDEX_AGENT_LAW.md`, `.github/ASSISTANT_CODING.md`, `.github/ASSISTANT_TESTS.md` | Registry, token, compiler, and test law. |
| Crane architecture, IndexedEx testing, and Uniswap V4 hook-package skills | Packaging and production-first tests. |

PairToken stage one is not an economics authority. Do not inherit S1-ACC-02, S1-ACC-07, S1-D03's dead-share sentence, S1-OP-02's zap caps, S1-OP-05's ratio swap and quarter-cap, S1-P05, S1-P07, S1-EXIT-01's collection-only fallback, S1-X15, or S1-X17. Issuance, entry settlement, compound, and booked balances are FS-MONEY-01 and the FS-OWN locks. An unnamed PairToken economic clause does not survive because this file used to inherit by ID.

These constraints stay, and they are not PairToken economics:

- FS-X01 permits the already-unlocked path only for canonical `exchangeIn`, including its one-token exit. `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` still revert `ManagerAlreadyUnlocked`. `depositPair` and `redeemPair` are not installed. There are no SY mutators.
- FS-OWN-05 removes every Standardized Yield selector. Do not replace `exchangeRate` with another denomination.
- FS-OWN-03 withdraws `getRate`. Do not install `IERC4626`, a transition quote, an external-state quote, or `IStandardExchangeRateQuote`. The external rate provider in FS-OWN-29 is hook configuration, not a rate facet on this vault.
- Hook bindings, compiler law, and registry law stay. Do not rewrite them to remove a PairToken filename reference.

Do not install `IStandardExchangeTransitionQuote`, `IStandardExchangeUnlockContextQuote`, or `IStandardExchangeExactOutputQuantityQuote` unless FS-HOOK-04 cites a consumer that rejects without one. The ordinary exact-input hook path must show the existing ERC-165-gated fallback to standard previews. A stub that returns live values for a projected state is forbidden.

### 2.1 Dispositions retained from advisory

| Topic | Final choice | Not adopted |
| --- | --- | --- |
| `getRate` | Withdrawn by FS-OWN-03. Not installed. Hooks use externally deployed providers under FS-OWN-29. | Keep the prior one-share formula. A thirteenth `RateFacet`. Return zero below one share. Store a provider on this vault. |
| Supply below `1e18` | Withdrawn with `getRate`. FS-OWN-03. | A live `InsufficientRateSupply` requirement. |
| Unlocked surface | Canonical `exchangeIn` only, including one-token exit. | Borrowed unlock on compound, donate, paired methods, or SY. |
| Locked unlock count | One vault-started unlock per planned manager action. | One unlock per public call. |
| Recipient | Output may be paid to the hook's `recipient`, including a user on unwrap. | `recipient == msg.sender` as a hard rule. A hook allowlist. |
| Entry remainder | Unused user input and a positive credit are returned to the payer under the pretransfer directive. Donation and compound remainders are booked instead. | `J_i` booking for user entry. `IncompleteConversion`. Every input wei becomes liquidity. Return a donation or compound remainder to its caller. |
| Identity `token == share` | Not a passing row. Current hooks reject it unless `asset()` exists. Do not add `asset()`. | Greening FS-A24 by adding `asset()` or editing the hook. |

## 3. Facets

### FS-FACET-01 — Package inputs

`PkgInit` uses this family's facet order. PairToken facet order is not inherited economics. FS-OWN-05 removes `syMoneyFacet` and `syQueryFacet`. It is not an open `IFacet[]`. Do not pass a PairToken facet address into this package. Family facets are this family's implementations. `basicVaultFacet` is the custom implementation in FS-OWN-07, not the shared facet. Package validation must not require `getRate`. FS-OWN-03 forbids installing it.

Shared facets stay the current shared implementations:

| Field | Selectors |
| --- | --- |
| `erc20Facet` | The nine canonical ERC-20 and metadata selectors. |
| `erc2612Facet` | `permit`, `nonces`, `DOMAIN_SEPARATOR`. |
| `erc5267Facet` | `eip712Domain`. |
| `basicVaultFacet` | Not one shared facet. `vaultTokens` is `MultiAssetBasicVaultFacet`. `reserveOfToken` and `reserves` are the family custom facet. FS-OWN-07. |
| `standardVaultFacet` | `vaultFeeTypeIds`, `contentsId`, `vaultTypes`, `vaultConfig`. |

Crane aware package inputs:

| Field | Surface |
| --- | --- |
| `protocolAwareFacet` | Externally callable getters for the seven stored Uniswap V4 architecture components. No family `poolManager()` selector. |
| `singlePositionAwareFacet` | Externally callable getters for the instance `PoolKey`, ticks, salt, and `positionLiquidity()` through `StateLibrary`. No family-only `poolKey()` selector and no `localReserves()` sleeve getter. |

Family facets:

| Field | Selectors |
| --- | --- |
| `moneyFacet` | `exchangeIn`, `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, `compound`. FS-OWN-09. Do not install `depositPair` or `redeemPair`. |
| `quoteFacet` | `previewExchangeIn`, `previewExchangeBundleInForSingleOut`, `previewExchangeBundleOut`. Do not install `previewZapCredit`, `previewWithdrawalMode`, or the paired previews. |
| `outFacet` | `previewExchangeOut`, `exchangeOut`. `previewExchangeOut` returns zero without a vault-error revert. `exchangeOut` reverts `ExchangeOutNotAvailable()` without taking funds or changing state. |
| `queryFacet` | Do not install `poolManager()` (FS-OWN-01), a family-only `poolKey()` (FS-OWN-02), `rateAsset()`, `getRate()` (FS-OWN-03), `wrappedNative()` (FS-OWN-10), or `localReserves()` as a sleeve getter. Protocol and position queries use the aware package inputs. |
| `callbackFacet` | `unlockCallback`. |

`syMoneyFacet` and `syQueryFacet` are not package inputs. FS-OWN-05.

The old 61-selector count included `getRate` and is not the manifest. Recount from the current package after the aware inputs and final function surface are applied. `linkedComponents()` is facet metadata, not an installed proxy selector. Cite the current package `_expectedSelectors` and S1-ARCH-04 when implementing. Do not invent selector hex in this PRD beyond the accepted selectors expressly locked in FS-OWN-08.

New errors, declared on the family interface, with selectors computed later:

- `InvalidUnlockedContext()`
- `SettlementMismatch()` where execution cannot close this diamond's own touched deltas

`InsufficientRateSupply`, `RateNormalizationOverflow`, and `RateUnavailable` are withdrawn with `getRate`. Do not declare them for this family.

### FS-FACET-02 — Factory-owned exclusions

Do not put these in `PkgInit`, `facetCuts`, or the package interface aggregation:

- ERC-165 introspection.
- ERC-8109 introspection.
- Diamond loupe.
- The factory-owned temporary-hook facet. The PairToken interface excludes it. This PRD does not invent its filename. Name it only after citing the factory file.

The finished proxy still exposes those factory-installed surfaces. Exclusion from `PkgInit` is not removal from the diamond.

## 4. Files and package

### FS-ARCH-01 — Files

Create the family under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`. Do not edit PairToken or Wings to host it.

Production files mirror the PairToken split, with `FullSpread` in the name:

- `interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol`
- `interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol`
- `UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol`
- `UniswapV4FullSpreadStandardExchangeVaultComponent_FactoryService.sol`
- `UniswapV4FullSpreadStandardExchangeVaultComponentBindings.sol`
- `UniswapV4FullSpreadStandardExchangeVaultTypes.sol`
- `UniswapV4FullSpreadStandardExchangeVaultRepo.sol`
- `UniswapV4FullSpreadStandardExchangeVaultMath.sol`
- `UniswapV4FullSpreadStandardExchangeVaultProjection.sol`
- `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol`
- `UniswapV4FullSpreadStandardExchangeVaultExecution.sol`
- one facet and one target file for money, quote, out, query, and callback. The target filename is `UniswapV4FullSpreadStandardExchangeVaultMoneyTarget.sol` and the same pattern for the others. Do not use a shortened literal `MoneyTarget.sol`. Do not create SY money or SY query facets and targets.

`TestBase_UniswapV4FullSpreadStandardExchangeVault.sol` goes under the family's `test/bases/`. Specs go under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`.

Storage uses a new namespaced slot, `keccak256(abi.encode(namespace)) - 1`. It must not equal PairToken's slot or Wings' slot.

FS-OWN-01 adds the Protocol Aware Repo and Facet under `lib/crane/contracts/protocols/dexes/uniswap/v4/aware`. FS-OWN-02 adds the reusable `UniswapV4SinglePositionAware` Repo and Facet in Crane. Both have Crane tests and are package inputs. Do not put those repos inside the full-spread family directory.

### FS-PKG-01 — `PkgInit` and `PkgArgs`

`PkgInit`, in binding order: the facet fields above, then `poolManager`, `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, `universalRouter`, `registry`, `oracle`, `diamondFactory`, and `linkedLibraries` as `address[6]` for Math, Projection, SwapProjection, Planner, Execution, and ExecutionPreparation. The two Standardized Yield facet fields and `wrappedNative` are absent. The seven Uniswap V4 architecture addresses are package immutables used to initialize the Protocol Aware Repo, not permission to install family query selectors.

`PkgArgs` is this family's set. It is not the PairToken set. No hook allowlist:

- `PoolKey poolKey`, stored through `UniswapV4SinglePositionAware` in FS-OWN-02, not as proof that `poolKey()` is a family-only selector
- `string name`
- `string symbol`

`maxZapBps` and `maxZapTickMove` are not fields. No replacement cap or tick bound is added.

`bindingHash` covers every `PkgInit` field. `calcSalt` and `processArgs` run by delegatecall and use immutable bindings and self calls.

`deployVault(PkgArgs) returns (address)` goes through the bound IndexedEx vault registry. No second factory. The PoolManager is not CREATE3'd by this package. Tests deploy it through the current artifact-backed CREATE3 helper, as FS-TEST-01 says.

`processArgs` reverts `NotCalledByRegistry` unless `msg.sender` is the bound registry and `address(this)` is the bound `diamondFactory`. Both conjuncts are required.

### FS-PKG-02 — Validation

Reject, without a partial diamond:

- A missing or code-empty component, a family facet whose linked-component hash does not match, or a cut that installs `getRate` or `rateAsset`. `InvalidComponent`.
- A pool key that is not initialized on the bound manager or has a nonzero hook. `InvalidPoolKey`.
- The `processArgs` context failure above.
- Proxy initialization that does not match the bound package and arguments. `InvalidInitializationContext`.
- A second initialization. `AlreadyInitialized`.

There is no designated rate-asset argument, wrapped-native package input, zap-limit argument, or additional inherited-domain pool restriction to validate.

Initialization installs the name and symbol, writes all seven architecture immutables into the Protocol Aware Repo, and stores the pool key, full-range ticks, and salt `bytes32(0)` in `UniswapV4SinglePositionAware`. It does not store a designated rate token, a rate-provider address, or a stored owner. Owner authority remains the live `feeTo()` check. The first depositor creates the position. Genesis issuance follows FS-MONEY-01. This update does not add Weir's treasury performance fee.

## 5. Money and unlocked entry

### FS-MONEY-01 — Weir-adapted money rules

The public selectors stay the accepted Standard Exchange routes, plus locked `donate` and `compound`. Do not install Weir's `deposit`, `withdraw`, `zap`, or `zapTo` selectors. The following rules combine the expressly retained source operations with the later locks.

- A share-minting deposit pulls the declared amounts from `msg.sender`, then sends `amount - used` of each currency back to that payer, subject to the pretransfer directive. Shares are credited to `p.recipient`, who need not be the payer, after the usage-fee netting in FS-OWN-24.
- Settlement uses each currency's net delta. A positive credit goes back to the depositor. There is no consumption-equality check and no `IncompleteConversion` error.
- The entry swap, when one is needed, uses `_swap`. Its price limit is `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`. That is not `maxZapTickMove`, and no tighter cap is added. The same unbounded limit applies to a one-token redemption and to a one-token `donate()` or `compound()`.
- On a share-minting deposit, book `feesAccrued`. Do not include those fees in the deposit, the caller's share credit, or a swap. Swapping them into the deposit is forbidden. A mint preview does not credit existing fees to the new depositor.
- `frame.liq` is the deposit's added raw V4 liquidity. When `v.totalShares == 0`, reject `frame.liq <= MIN_SHARES`; `grossShares = frame.liq - MIN_SHARES`, and mint `MIN_SHARES` (`1_000`) separately to `address(0)`. Apply FS-OWN-24's fee netting to `grossShares`. Credit only `grossShares - feeShares` to the recipient. The floor remains in `totalSupply` and is not credited to that recipient or included in the fee base.
- For an existing supply, `grossShares = (uint256(frame.liq) * v.totalShares) / v.liquidity`. The denominator is existing deployed liquidity before this deposit is added. Booked balances and `feesAccrued` are not in that denominator. Apply the same usage-fee netting to `grossShares`.
- A deposit, withdrawal, and `exchangeIn` do not call `_compound` or `compound()`. Fees booked on a share-minting deposit are not automatically reinvested. Only an authorized explicit `compound()` or `donate()` processes collected fees and booked tokens under FS-OWN-14 and FS-OWN-21.
- On withdrawal, remove `liquidity * shares / totalSupply`, using supply before the burn and including the floor. The caller owns `shares burned / total shares` of `feesAccrued` and of each booked balance, measured before the burn and rounded down. Include those portions in the exit and book the rest for other holders.
- A both-token exit pays the caller's principal, fee, and booked claim in both tokens and does not swap. A one-token exit pays the requested-token fee and booked claim directly and swaps all unwanted withdrawn principal plus opposing-token fees and booked claims into the selected token. It reverts `AmountOutNotMet` without burning shares if the conversion cannot meet the minimum. No other holder's claim is swapped.
- An exit preview uses the same apportioning and swap as execution. Its `amountOut` is the share valuation and includes accrued fees. A bundle exit returns the accepted amounts array and refund field; a scalar exact-input exit returns `(amountOut, amountRefunded)`.
- `donate()` and `compound()` book the actual held remainder after the simplest secure deposit. They do not return that remainder to the caller, revert merely because it remains, or treat it as a sleeve. The size of a remainder does not matter; call `compound()` again to process it. User entry unused input and positive credits are instead refunded under FS-OWN-32.
- Native ETH is confined to the pool boundary. Callers send and receive WETH only; there is no native-ETH caller payout and no `wrappedNative()` package input or getter.

The 12,000,000 gas transaction ceiling and the 5,000,000 preview ceiling stay. A hook-composed transaction must fit the 12,000,000 ceiling or be recorded as an unresolved narrowed route. It is not a passing measurement and not a waiver. Quotes are the mathematical result of the operation; do not add a 64-step cap, minimum tick spacing, partial fill, or undocumented failure mode.

### FS-UNLOCK-01 — Two dispatch paths, one engine

Current buffer and unwrap helpers call `IStandardExchangeIn.exchangeIn` while the PoolManager is already unlocked. Buffer helpers observed in the dual and weighted claim code pay `address(this)`. Weighted `unwrap` pays the hook's `to` argument, which can be a user. A new selector would not be called. Do not add `exchangeInUnlocked`.

After ordinary route, deadline, amount, and authority checks, `exchangeIn` reads `TransientStateLibrary.isUnlocked` on the bound manager:

- Locked: FS-UNLOCK-03.
- Unlocked: FS-UNLOCK-02.

`isUnlocked` selects the path. It is not authorization. Allowance, minima, deadline, and share authority still apply. The PoolManager is not the depositor.

`exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` keep `ManagerAlreadyUnlocked()` on this path. There are no paired selectors and no SY mutators.

### FS-UNLOCK-02 — Borrowed unlock

When `exchangeIn` takes the unlocked path:

1. The vault is initialized and idle. The callback hash is empty. Reservations are zero. This diamond's own backing-currency deltas on the bound manager are zero. Otherwise revert `SettlementMismatch` or `ReentrantOperation`.
2. The caller has code, pays the input, and is the share owner burned on exit. `pretransferred` is false. The function is nonpayable, so a value-bearing call fails at the ABI boundary. Do not specify `InvalidUnlockedContext` for `msg.value != 0`. `recipient` may be the caller or another address. Output is paid to `recipient`. Otherwise, a failed funding or route check uses the inherited error, and a borrowed-path context miss uses `InvalidUnlockedContext`.
3. No payer, callback payload, or foreign creditor is accepted. Burn only the caller's shares.
4. Dispatch each selected action to the same internal action, account, and settlement code used by the locked path. Do not call `unlock`. Do not call `unlockCallback`. Do not copy the locked callback's final `getNonzeroDeltaCount` check. That count is global. The hook and router may hold open deltas.
5. `modifyLiquidity` and `swap` run only on this diamond's hookless pool key. The position owner remains this diamond. The only position written is the full-range salt-zero position: `tickLower` and `tickUpper` from `TickMath.minUsableTick` and `maxUsableTick`, salt `bytes32(0)`. A one-token exit pulls the caller's deployed fraction on this same open flag.
6. Settlement of a debt is atomic for that currency: sync, transfer or value, settle, then take credits. Do not `settleFor` a foreign address. `PoolManager.sync` writes the global transient `CURRENCY_SLOT` and `RESERVES_OF_SLOT` in `CurrencyReserves`. Do not assume an outer actor's sync checkpoint remains valid. Do not clear another address's sync to hide a clobber. If the sequence cannot close this diamond's own touched deltas without taking a foreign credit, revert `SettlementMismatch`.
7. Before return, this diamond's touched currency deltas are zero. Assert that per address. Do not require the global nonzero-delta count to be zero. Do not settle the hook's or the router's deltas.
8. A failure reverts the vault call and its descendant effects. If the outer caller catches it, the vault state is restored and the caller still owes its own settlement. The catch does not relock the manager.

### FS-UNLOCK-03 — Locked path

Ordinary entry keeps the inherited per-action dispatcher. For each selected manager action that needs an unlock, commit `keccak256(abi.encode(operation, payload))`, call `unlock` once for that action, accept the callback only from the bound manager, only while the guard is held, and only once for that payload. Then settle that action and verify the manager has relocked before the next action. Nested unlock and replay stay forbidden. The public-operation guard stays active across the plan, token calls, and final payout.

`unlockCallback` remains unusable as a deposit. An external unlock does not satisfy a committed hash.

## 6. Rate, quote, and issuance

| Surface | Meaning | Forbidden substitute |
| --- | --- | --- |
| Issuance | FS-MONEY-01 and net-of-usage-fee shares under FS-OWN-24. `previewZapCredit` is absent. | S1-ACC-07. `J_i` booking. A replacement zap-credit view. Crediting existing fees to a new depositor. |
| SY `exchangeRate()` | Not installed. FS-OWN-05. | A replacement denomination. NAV. |
| `previewExchangeIn` | Amount-specific executable quote with `(amountOut, amountRefunded)`. A mint quote uses net shares and excludes existing fees from the new depositor's credit. An exit quote uses execution's fee and booked-balance apportioning and the same swap, and is the share valuation. | Whole-book value divided by supply. Principal-only exit value. Automatic maintenance or compounding not performed by execution. |
| `getRate()` | Not installed. FS-OWN-03. Hooks configure external providers under FS-OWN-29. | The withdrawn one-share formula. NAV. A provider address or rate facet stored on this vault. |

### FS-RATE-01 — Withdrawn

Do not implement `getRate`. The prior formula, `InsufficientRateSupply`, `RateNormalizationOverflow`, and `RateUnavailable` are not requirements. Do not bind `StandardExchangeRateProviderFacet` and call its result this family's rate. A hook that requires a provider for this share configures an external `IStandardExchangeRateProviderDFPkg` instance under FS-OWN-29. This vault does not know that provider. The provider migrates to the accepted two-word preview return under FS-OWN-08.

## 7. Hook integration

### FS-HOOK-01 — Families and bindings

Use the package interface in each family's `interfaces/` directory.

| Family | What the test binds | What a pass proves |
| --- | --- | --- |
| `single/` | One `standardExchange` and one `pairToken`. | One-vault borrowed `exchangeIn` through the hook's `beforeSwap`, both exact-input directions. Not a two-vault proof. |
| `constantProduct/single/` | One buffered SE, one pair token, one raw token. | FullSpread as the buffered leg. The raw leg is a transfer unless the fixture shows a conversion. Name which leg converted. |
| `dual/` | Two SE arguments and two tokens. | The canonical cross-vault proof in FS-HOOK-02. |
| `orbital/` | Package fields `se0`, `se1`, `se2` and `rp0`, `rp1`, `rp2`. The hook view is `standardExchange(uint8)` and `rateProvider(uint8)`. | A valid three-leg bind with FullSpread buffered on one leg and another SE share on another, roles named. The FullSpread provider is external under FS-OWN-29. |
| `weighted/` | Arrays, `n` in 2 through 8. | At least a 2-leg setup and one larger supported setup. |
| `stable/quad/curve/` | Fixed four-leg arrays. | Four valid legs. Do not treat a volatile share as a peg. |
| `stable/quad/balancer/` | Dynamic arrays, 2 through 5 legs. | A 2-leg setup and a 5-leg setup. Do not copy a fixed-four constructor. |

No new hook-package field is authorized. Required rate-provider rows configure existing provider fields with externally deployed instances; they do not derive a provider from this vault.

### FS-HOOK-02 — Canonical cross-vault fixture

The passing cross-vault proof is:

1. FullSpread is the buffered leg. `standardExchange` is this vault. FS-OWN-03 removes `rateAsset` and this vault's `getRate`. Where the package requires a provider because the token is not the share, configure an external provider deployed for this vault and the selected `rateTarget` under FS-OWN-29. Include each underlying-token target, token0 and token1 placement, and two pools holding the same vault at different targets.
2. The other SE is not asked to mint or redeem inside the outer unlock. Current PairToken rejects that context. Its share may be an identity leg only if the current package accepts `token == se` without `asset()`. If it rejects, that identity bind is FS-HOOK-04, not a pass. The other leg can still be a raw token or a share transfer that the hook accepts without calling that vault.
3. The two backing pool keys differ. One direction mints FullSpread shares while the manager is unlocked. The reverse burns them. Assert balances, position owner, ticks, salt, net usage-fee shares, fee and booked-balance apportioning, and per-address deltas.
4. An identity-only share trade is a separate case. It does not prove underlying entry or exit.
5. A both-buffered composition is optional, and only for another family that already supports the same borrowed unlock. It is not the required proof.

Two buffered legs that share one pair token and overwrite `standardExchangeOf[pair]` are not a required fixture. If the package cannot represent that bind, record it. Do not edit the hook to create it.

Same-backing-pool sequential composition is unverified, not impossible, and not passed by the disjoint-pool fixture.

### FS-HOOK-03 — Exact output

`exchangeOut` reverts `ExchangeOutNotAvailable()`. `previewExchangeOut` returns zero and does not gain a refund return. A hook path that calls `exchangeOut` against this vault fails closed. An identity route that never calls `exchangeOut` is not forbidden by that sentence. Exact-input both directions means `zeroForOne` and `oneForZero`. Exact-out is not one of those directions.

### FS-HOOK-04 — Separate hook-change gate

If a required route cannot run:

1. A full-spread money, preview, or context defect is fixed in this family.
2. An intentional exact-output or budget rejection stays a rejection.
3. A missing quote interface, an `asset()` requirement, a `SameToken` or pair-overlap reject, or an incompatible denomination is a separate requirement. Name the consumer, selector, arguments, and revert. Do not implement that change here, and do not stub a transition quote.

A cited reject is an unresolved integration record. It does not close the canonical FS-HOOK-02 proof. It may close a family row only when that family's topology cannot express the canonical fixture, and the record says so. A required rate-provider bind is not an unresolved record merely because this vault has no `getRate`; configure the external provider under FS-OWN-29.

## 8. Testing

### FS-TEST-01 — Harness

Place the TestBase under the family's `test/bases/`. Follow the current PairToken setup: extend `IndexedexTest` and the canonical native-wrapper base, call parent setups in the current order, and deploy the PoolManager through the existing artifact-backed CREATE3 helper. Deploy facets and the package through the current factory and manager paths. The hook under test and this vault bind that same manager. Two managers do not prove FS-UNLOCK-02.

Bootstrap shares only through the accepted public entry routes. `depositPair` is not installed. Reuse the current non-SUT mintable funding tokens. That is not permission to mock, etch, `vm.mockCall`, or inject storage into this vault or the PoolManager.

Hermetic tests use the default Foundry profile, `viaIR=false`, and the current runtime and initcode limits. `recordLogs` is not a receipt. A snapshot restore asserts pre-state and post-state equality before restore. Crane tests for the Protocol Aware and `UniswapV4SinglePositionAware` pairs live in Crane and are required package-input evidence.

### FS-TEST-02 — Files

- `UniswapV4FullSpreadStandardExchangeVaultPackage.t.sol`
- `UniswapV4FullSpreadStandardExchangeVaultMoney.t.sol`
- `UniswapV4FullSpreadStandardExchangeVaultNative.t.sol`
- `UniswapV4FullSpreadStandardExchangeVaultQuotesAndRate.t.sol`
- `UniswapV4FullSpreadStandardExchangeVaultCallbacks.t.sol`
- `UniswapV4FullSpreadStandardExchangeVaultAlreadyUnlocked.t.sol`
- `UniswapV4FullSpreadStandardExchangeVaultBufferHookIntegration.t.sol`

Do not apply an inherited PairToken acceptance row that asserts removed economics. In particular, do not apply S1-A10, S1-A13, S1-A15, S1-A19, S1-A46, S1-A62, S1-A64, or S1-A70 as issuance, zap-cap, remainder, or consumption-check rows. Use the FS-A rows below. S1-A40 is not an inherited pass for `exchangeIn`; FS-A19 through FS-A23 cover that path, and FS-A22 still rejects the other unlocked methods.

### FS-TEST-03 — Acceptance rows

| ID | Assertion |
| --- | --- |
| FS-A01 | Package inputs follow FS-FACET-01. ERC-165, ERC-8109, loupe, and the cited temporary-hook facet are absent from cuts and still callable on the factory-built proxy where the factory installs them. The reviewed selector manifest succeeds through the proxy. `poolManager()`, family-only `poolKey()`, `rateAsset()`, `getRate()`, `basket()`, `localReserves()`, `wrappedNative()`, and every Standardized Yield selector are absent from the family surface; aware getters remain callable through their package-input facets. Factory selectors stay disjoint. |
| FS-A02 | `bindingHash` changes if any facet, library, aware component, or infrastructure binding changes. |
| FS-A03 | Invalid component, invalid pool key, double initialization, wrong `processArgs` caller, and right registry in the wrong account all revert and leave no usable vault. There is no rate-asset, wrapped-native package, or zap-limit argument to reject. |
| FS-A04 | Storage slot is not PairToken's and not Wings'. |
| FS-A05 | First deposit creates one full-range salt-zero position owned by the diamond. Gross shares are raw added liquidity minus `MIN_SHARES`; the floor is minted separately to `address(0)` and included in supply. Usage-fee shares come out of gross shares, the recipient gets the net, and no additional unbacked or performance-fee mint occurs. |
| FS-A06 | Paired deposit and redeem follow the mapped bundle routes and FS-MONEY-01. Deposit emits `PairDeposited(address indexed caller)` and redeem emits `PairRedeemed(address indexed caller)`, with no other arguments. A both-token exit pays both sides of the caller's claim and does not swap. |
| FS-A07 | Unused declared entry input is returned to the payer. A positive credit is returned to the depositor and is not booked without shares. There is no `IncompleteConversion` revert. Pretransfer cases follow FS-OWN-20, including no spend and no pull when the declared maximum exceeds the unbooked balance. |
| FS-A08 | Single-token exit pays only the selected token after converting the entire unwanted principal, opposing fee, and opposing booked claim, or reverts `AmountOutNotMet`. Shares are not burned if it reverts. Other holders' claims are not swapped. |
| FS-A09 | `previewExchangeOut` returns zero without a vault-error revert. `exchangeOut` reverts `ExchangeOutNotAvailable` with unchanged balances. Neither gains a refund return. |
| FS-A10 | Native-currency pool operations wrap or unwrap only at the pool boundary. Callers send and receive WETH only, and no native ETH is accepted or produced at the caller boundary. |
| FS-A11 | A share-minting deposit books `feesAccrued` and does not deploy, swap, or credit it to the new depositor. Withdrawal includes the caller's rounded-down share of accrued fees and each booked balance and books the rest. Deposit, withdrawal, and `exchangeIn` do not auto-compound. |
| FS-A12 | Withdrawn. `exchangeRate` is not installed. FS-OWN-05. |
| FS-A13 | Withdrawn. `getRate` is not installed. |
| FS-A14 | Withdrawn. `InsufficientRateSupply` is not declared. |
| FS-A15 | Withdrawn. A planner failure is not observed through `getRate`. |
| FS-A16 | Issuance does not read `exchangeRate`. There is no `getRate` to read. Raw liquidity, not token-decimal scaling, determines gross shares and burns. |
| FS-A17 | A multi-action locked deposit and a multi-action locked withdrawal perform one unlock and one consumed callback per planned action. Replay after each callback reverts. The guard stays active between actions. The borrowed equivalent performs zero unlocks. |
| FS-A18 | `unlockCallback` from any caller but the bound manager reverts and moves no tokens. |
| FS-A19 | While the manager is unlocked, `exchangeIn` does not call `unlock`. This diamond's touched deltas are zero before return. The global delta count may be nonzero. Position owner, ticks, and salt are unchanged. Liquidity may change. |
| FS-A20 | A borrowed `exchangeIn` that is not self-funded, or that sets `pretransferred`, reverts `InvalidUnlockedContext` or the inherited funding error. A call with value fails at the nonpayable boundary, not as a specified internal `msg.value` check. |
| FS-A21 | An unlocked caller who does not hold the input or the shares does not mint. The unlocked flag is not authority. |
| FS-A22 | `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` revert `ManagerAlreadyUnlocked` while the manager is unlocked. `depositPair` and `redeemPair` are absent. There are no SY mutators. |
| FS-A23 | A reverting borrowed `exchangeIn` restores shares, liquidity, and token balances. |
| FS-A24 | An identity bind of `token == this vault` is attempted. If the current package rejects it without `asset()`, the row records that reject under FS-HOOK-04 and does not pass. Do not add `asset()`. |
| FS-A25 | Buffered configuration mints and burns through `exchangeIn` while unlocked. Recipient may be the hook or the hook's unwrap recipient. Position owner, ticks, and salt hold. Fee handling follows FS-MONEY-01 and FS-OWN-24. No performance fee is added. Required provider binds use external instances under FS-OWN-29. |
| FS-A26 | The FS-HOOK-02 fixture completes exact-input `zeroForOne` and `oneForZero` on two different backing pool keys. Exact-out is not part of this row. |
| FS-A27 | Each family in FS-HOOK-01 has the proof that its topology can express, or a cited FS-HOOK-04 record that says why it cannot. A cited reject does not replace FS-A26. The required external rate-provider scenarios in FS-OWN-29 pass without installing a vault rate facet. |
| FS-A28 | A hook path that calls `exchangeOut` on this vault reverts and pays neither token. |
| FS-A29 | This vault exposes no `getRate`, `rateAsset`, provider storage, or provider getter. External provider rows rate this vault against each underlying token, cover token0 and token1, and value the same vault at different targets in separate pools. Providers consume `(amountOut, amountRefunded)`. |
| FS-A30 | A same-backing-pool sequential composition is not reported as passed by FS-A26. |
| FS-A31 | Every claimed composed fixture, including both vault operations and hook work, fits 12,000,000 gas. Previews fit 5,000,000. An oversized route is unresolved, not passed. There is no `getRate` read in the measurement and no undocumented quote step cap. |
| FS-A32 | Busy or unlocked economic views return computed values rather than reverting by a vault error. Unsupported view routes and unknown reserve tokens return zero. Reserves are live deployed amounts plus unpaid fees, with no local term or last-committed snapshot. `getRate` is not part of this row. |
| FS-A33 | Borrowed execution uses the same action, accounting, apportioning, and settlement as the locked path from the same economic state. It does not auto-compound, use a collection-only fallback, or charge a performance fee. A one-token exit swaps only the exiting claim. |
| FS-A34 | A nonzero own delta at borrowed entry reverts. Each action closes only this diamond's deltas. Outer debts remain until the outer unlock returns. |
| FS-A35 | Native borrowed settlement syncs native currency immediately before value settle, does not double-count wrapped and native backing, and does not spend another actor's sync credit. Caller-facing value remains WETH-only. |
| FS-A36 | A propagated outer failure restores the swap. A caller that catches a rejected vault call keeps only its own prior effects, sees the vault restored, and still settles its own deltas. |
| FS-A37 | A funded non-hook contract that meets FS-UNLOCK-02 succeeds. The missing allowlist is the specified permissionless funding rule. |
| FS-A38 | Disabled inbound issuance still allows a supported exit through a buffered hook route. |
| FS-A39 | For one-sided and bundle deposits, including genesis, `feeShares` is netted from gross shares using the clamped fee. Values above 30% apply as 30%, 0.001% remains representable, zero stays zero, previews and `minAmountOut` use net shares, and an underlying-to-underlying pass-through takes no usage fee. A deposit-and-redeem round trip does not move existing holders' value to `feeTo` through an additional unbacked mint. |
| FS-A40 | Only the current `feeTo()` or an operator in `OperableRepo` can call `donate()` and `compound()`. Changing `feeTo()` changes owner authority without reinitialization. New modifiers perform the live check rather than reusing a stored-owner facet check. |
| FS-A41 | `donate()` reverts at zero supply, burns donated shares without withdrawal, emits fieldless `Donation()`, and deploys underlying donations. One-token donation and compound use the greatest-liquidity rule; a combined balance holding both tokens deposits proportionally without swapping. Actual remainders are booked. |
| FS-A42 | `compound()` with no fees, donation, or booked remainder returns with no state change and no event. A deposit from collected fees or booked tokens emits fieldless `Compounded()`, including a `compound()` call that deposits. No fee-origin store is added, and PoolManager events supply amounts. |
| FS-A43 | Exit previews use execution's apportioning and swap, include accrued fees, and match execution's `amountOut`. Mint previews do not credit existing fees to the new depositor. `previewExchangeIn` and `exchangeIn` return the tuple with unchanged selectors; all consumers named in FS-OWN-08 migrate. |
| FS-A44 | A normal deposit and redeem do not depend on an undocumented quote step cap, minimum tick spacing, partial fill, or fallback. No replacement zap cap or tick guard is introduced. |

Compare supply, holder balances, both positions, `feesAccrued`, booked and unbooked custody, wrapper balances, events, and per-address deltas. Do not assert only that no tokens moved.

### FS-TEST-04 — Integration matrix and audit regressions

Add this vault to the integration testing matrix and to the integration tests. Extend these live behavior contracts under `test/foundry/spec/hooks/uniswap/v4/standardExchange/` with a row for this vault, without editing assertions for other families:

- `single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol`
- `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol`
- `dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol`
- `orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol`
- `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol`
- `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol`
- `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol`

Exact-output success rows cannot pass here: `exchangeOut` reverts and `previewExchangeOut` returns zero. A user's unused input is refunded. A donation or compound remainder is booked, so those rows stay. These adaptations do not weaken other families' rows.

`docs/audits/apex-2026-09-17-evidence/hook-se-matrix.json` historical V4 FullSpread rows are not current proof. Preserve V3 rows and replace stale V4 FullSpread rows rather than treating them as passed. Update, rather than treat as passed, the relevant evidence in `hook-se-matrix.json`, `hook-se-matrix-findings.json`, `hook-se-matrix-finding-descriptions.json`, `docs/audits/apex-2026-09-17-evidence.md`, and `docs/audits/apex-2026-09-17-evidence/acceptance.json` item R10.3.

Test that the vulnerabilities in `docs/security/audit/second_review` are not present in this new vault, subject to the expressly accepted residual exposure. In particular:

- APEX-2026-023: permissionless sleeve placement is absent because there is no sleeve. Do not claim that a sandwich of the live owner or operator's own `compound()` is impossible; that exposure is accepted.
- APEX-2026-024: a one-token redemption swaps only the exiting holder's claim, not staying holders' inventory. The unbounded price limit remains.
- APEX-2026-039: pretransfer uses only unbooked held balances up to the declared maximum and never treats parked shares or the whole sitting balance as caller credit.
- APEX-2026-044: fee shares come out of the new deposit's gross shares, with no additional unbacked mint, and previews and minima use net shares.
- APEX-2026-048: an empty compound returns unchanged, and a booked remainder does not freeze a later route.
- APEX-2026-041: a normal deposit and redeem do not depend on an undocumented quote cap.

A locked mechanism retained by this PRD is not tested as absent unless its finding is accepted or the rule is replaced.

## 9. Non-goals and limits

This PRD does not authorize implementation, deployment, a registry migration, a hook edit, a Weir copy, a wings range, a second pool, a transition-quote facet, a zap cap, a tick guard, a local liquidity sleeve, a stored-owner authorization model, a vault-resident rate provider, or Weir's treasury performance fee.

No audit is claimed. Disjoint-pool hook tests do not prove same-pool sequential safety. Compiler, gas, and fork results are future evidence. The accepted owner-or-operator sandwich exposure is not represented as eliminated.

Advisory outcomes recorded in the prior revision: Astra and Kimi requested changes. Grok and MiniMax supported with corrections. The corrections in the r2 revision were coordinator choices, not a new member vote. MiniMax withdrew the thirteenth facet. Kimi withdrew the zero rate. The proposal to unlock compound and paired methods stays rejected. The owner later locked FS-OWN-03, which withdraws `getRate`, and FS-OWN-29, which configures external rate providers without restoring a vault rate.

## 10. Participation

The following table records participation in the prior PRD revision, not a vote on this locked replacement.

| Member | Requested route | Original task | Advisory |
| --- | --- | --- | --- |
| Astra | `chatgpt-subscription/gpt-6-astra:high` | `st_01a18d05` | REQUEST CHANGES |
| Grok | `xai/grok-4.7:xhigh` | `st_01a18d06` | SUPPORT WITH CORRECTIONS |
| MiniMax | `minimax/MiniMax-M3` | `st_01a18d07` | SUPPORT WITH CORRECTIONS |
| Kimi | `kimi-coding/k3.1-pro:high` | `st_01a18d08` | REQUEST CHANGES |

Coordinator mode was invoking-agent. The coordinator is not a fifth vote. Runtime provider internals are not independently attested beyond the task records.

## Limits

This response is a drafting contribution only. It does not edit the current PRD or authorize implementation, testing, deployment, a hook change, or consumer migration. No Forge, tests, installs, wallets, deployment, Git, peer reading, or sub-agents were used. The complete occurrence index was read as the migration inventory and deliberately not reproduced. No source execution or independent selector recomputation was performed; selectors and consumer line references are copied from the admitted authority documents.
