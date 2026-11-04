# Uniswap V4 full-spread Standard Exchange vault PRD

Revision `fullspread-se-prd-rewrite-20261103`. Coordinator merge of the four independent responses in `docs/research/se-fullspread-prd-rewrite-20261103/members/`. The base text is the Grok conclusions. Astra, MiniMax, and Kimi were compared against the same locks. A contradicted sentence from `fullspread-se-prd-weir-align-r1` is replaced. It is not left beside the lock. This text is not an implementation, not a safety clearance, and not a member vote.

Precedence: a dated 2026-11-04 owner lock in this file, and the same dated override in `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`, wins over a 2026-11-03 override, over an earlier sentence in that file, over an undated recap in that file, and over an older sentence here. A dated 2026-11-03 override wins over an earlier sentence where the 2026-11-04 lock does not replace it. The operative withdrawal rule is FS-OWN-30, not a principal-only recap. `docs/vaults/PRETRANSFER_DIRECTIVE.md` is binding for calls that take `pretransferred`. An earlier owner lock remains where a later lock does not replace it. The accepted return ABI is `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md`, except where a later full-spread lock replaces a sentence in it.

## 1. Goal

Build `UniswapV4FullSpreadStandardExchangeVault`.

One registry-deployed Crane diamond owns one Uniswap V4 pool key, one full-range position, and one ERC-20 share supply. The diamond is the position owner. Public shares are claims under the issuance and exit rules in this file. There is no local liquidity sleeve. A staying holder's booked balance is held until `donate()` or `compound()` deploys it. It is not a reserve until then. An exit pays or converts only the exiting holder's claim under FS-OWN-30.

This family adapts the cited money operations of `contracts/protocols/strategy/weir/WeirVaults.sol` only where this file still states them. It has one ERC-20 share, one pool, and one full-range position. It does not copy Weir's manager of many virtual vaults.

It is not a sibling of PairToken and does not inherit PairToken economics by requirement ID. A PairToken economic or package choice stays only where a lock that remains in force already keeps it.

### 1.1 What this family is not

- Not a source copy of Weir's multi-vault manager, and not a mechanical wrapper around its internal share ledger.
- Not Upper/Lower Wings. No second range and no rebalance facet.
- Not a singleton of many pools, a second share ledger, or a shares-of-shares wrapper.
- Not an ERC-4626 product. Do not install `asset()`. Current hooks treat that selector as wrapper-share inventory. Adding it to turn a rejected identity bind into a pass is forbidden.
- Not a hook-package redesign. A hook change is FS-HOOK-04, raised only with a cited rejecting function. The preview-return migration in FS-OWN-08 is not that redesign.
- Not a local liquidity sleeve. Do not keep a `liquidReservePercentageOfVault` target, and do not restore `localReserves()`.

### 1.2 Deltas

| ID | Delta |
| --- | --- |
| FS-X01 | Canonical exact-input `exchangeIn` executes while the bound PoolManager is already unlocked, without a nested `unlock`. Ordinary user entry still opens its own unlock, once per planned manager action. Inclusion in a batch swap with other Uniswap V4 pools is not a revert. |
| FS-X02 | Withdrawn by FS-OWN-03. Do not install `getRate`. There is no designated `rateAsset`. An external rate-provider instance is FS-OWN-29. This vault does not know it. |
| FS-X03 | Tests place this share with another SE vault share in the current buffer-hook families, using the fixture in FS-HOOK-02. Those hook packages are not redesigned here. Consumers that still require a 32-byte `previewExchangeIn` success are migrated by FS-OWN-08. |
| FS-X04 | Single-token entry does not require the selected swap to consume its entire input. There is no `IncompleteConversion` check. Unused declared input is refunded to the payer under FS-OWN-32. It is not booked and it is not minted into shares. The one-sided swap shape is FS-OWN-33. The one-token exit is FS-OWN-30. |
| FS-OWN-01 | `poolManager()` is not a family query. The Uniswap V4 Protocol Aware facet is a Crane package input. Its getters are externally callable on this vault. |
| FS-OWN-02 | Pool key, ticks, and salt live in Crane `UniswapV4SinglePositionAware`, not in a full-spread-only getter. |
| FS-OWN-03 | Do not implement `rateAsset()` or `getRate()`. This family designates no single token for valuation or operations. |
| FS-OWN-04 | There is no local liquidity sleeve. Do not keep a target from `liquidReservePercentageOfVault`. Do not move a local balance toward a target after a deposit, a withdrawal, or `compound()`. Do not restore `localReserves()`. |
| FS-OWN-05 | Do not install ERC-5115. Drop `syMoneyFacet` and `syQueryFacet`. |
| FS-OWN-06 | `UniswapV4SinglePositionAware` stores `tickLower`, `tickUpper`, and the salt. `positionLiquidity()` wraps `StateLibrary.getPositionInfo`. |
| FS-OWN-07 | Do not implement `basket()`. `reserves()` and `reserveOfToken` wrap the deployed-reserve reads. There is no local term and no last-committed snapshot. A booked remainder is not in that read. Unpaid fees are. |
| FS-OWN-08 | `previewExchangeIn` and `exchangeIn` keep their parameters and selectors and return `(amountOut, amountRefunded)`. No `WithRefund` sibling. `exchangeOut` and `previewExchangeOut` do not gain a refund return. |
| FS-OWN-09 | Do not keep `depositPair`, `previewDepositPair`, `redeemPair`, or `previewRedeemPair`. Map them to the accepted bundle routes. Keep `donate` and `compound`. `donate` is an explicit exception and is not a Weir function. `compound` is owner-or-operator harvest-and-reinvest under the booking rule, not a PairToken ratio swap. |
| FS-OWN-10 | Do not implement `previewWithdrawalMode`, a family `wrappedNative()` getter, or `PkgInit.wrappedNative`. `previewZapCredit`, `maxZapBps`, and `maxZapTickMove` are absent. No replacement view, cap, or tick bound is added. |

### 1.3 Owner-locked decisions

These decisions are the current text of FS-OWN-01 through FS-OWN-10. A later lock in section 1.4 replaces a sentence here where it says so. They do not implement the repos.

**FS-OWN-01.** `poolManager()` is not a full-spread family query. Implement the Uniswap V4 Protocol Aware facet in Crane, under `lib/crane/contracts/protocols/dexes/uniswap/v4/aware`. The facet exposes the stored components. This vault's package takes that facet as a package input and uses it to initialize vault instances. The getters are externally callable on this vault. Do not implement a family `poolManager()` selector. The V2 aware repos are the storage example. V2 uses one repo per component. This standard keeps the protocol's components in one pair. Crane tests for that facet live in Crane and are part of this directive.

The Uniswap V4 architecture addresses are package immutables, set when that package is deployed, as the other package bindings are. They are the PoolManager, Position Descriptor, Position Manager, Quoter, State View, Reserves Lens, and Universal Router. A deployment on another chain uses the same package code and passes that chain's addresses. Do not hardcode `ROBINHOOD_MAIN.sol` into the package. Those constants are the Robinhood values, not the storage rule. When the package initializes a vault instance, it writes those immutable addresses into the Uniswap V4 Protocol Aware Repo. The repo is not given a second per-vault copy.

**FS-OWN-02.** `poolKey()` stays as information, not as a full-spread-only getter. The position getters are the Crane pair `UniswapV4SinglePositionAware`: one Repo and one Facet. It is reusable by other vaults with different position configurations. It is a package input on this vault, and its getters are externally callable. Do not put a family-only `poolKey()` selector on the full-spread query facet. `PkgArgs` may still carry the pool key used at initialization. Crane tests for this pair live in Crane and are part of this directive. The code is not written by this text.

**FS-OWN-03.** Do not implement `rateAsset()`. This vault does not designate one token for valuation or for operations. `PkgArgs` has no `rateAsset`. Do not install `getRate`. Do not install `StandardExchangeRateProviderFacet` on this vault, and do not bind that facet and call its result this family's rate. Do not add the rate errors that existed only for `getRate`. The external rate-provider rule is FS-OWN-29. This vault does not store a rate-provider address and exposes no rate-provider getter.

**FS-OWN-04.** There is no local liquidity sleeve. Do not keep a target from `IVaultFeeOracleQuery.liquidReservePercentageOfVault(address(this))`. Do not move a local balance toward that target after a deposit, a withdrawal, or `compound()`. `localReserves()` was the sleeve balance. `UniswapV4SinglePositionAware` does not restore that balance and does not grow a local-reserve getter. This replaces the requirement to keep a sleeve.

**FS-OWN-05.** Do not install ERC-5115. There is no underlying LP token, so `IStandardizedYield` is invalid here. Drop `syMoneyFacet` and `syQueryFacet`, including `deposit`, `redeem`, `exchangeRate`, and the other Standardized Yield selectors. Do not create those facet files. This is an authorized divergence from the SE package. It confirms FS-OWN-03. Do not replace the dropped rate with NAV or another denomination.

**FS-OWN-06.** Keep `tickLower()` and `tickUpper()`. PoolManager position state does not store them; they are inputs to the position key. Store them in `UniswapV4SinglePositionAware`, with the full `PoolKey` and the position salt. Those four values are instance storage, written when the package initializes the vault. They are not package immutables. This vault's range is the full-range position, `TickMath.minUsableTick` and `TickMath.maxUsableTick`, and its salt is `bytes32(0)`. Keep `positionLiquidity()`. It returns only the liquidity deployed in this vault's position. The read uses `StateLibrary` against the PoolManager. `positionLiquidity()` wraps `StateLibrary.getPositionInfo` for this diamond, the stored ticks, and the stored salt. It returns that position's liquidity, not a token amount and not the whole pool's liquidity. `StateView` is the off-chain wrapper of the same read, so it is not the vault's dependency for this read. `PositionManager` reads an NFT position this vault does not hold. Storing those two addresses under FS-OWN-01 does not make them the position read.

**FS-OWN-07.** Do not implement `basket()`. `reserves()` wraps the deployed-reserve reads. It does not add a local term. There is no last-committed snapshot. `reserveOfToken(address)` is that same read for one token. It returns zero for an address that is not in `vaultTokens()`. Reuse `vaultTokens()` from `MultiAssetBasicVaultFacet`. Do not reimplement it. The custom facet exposes only `reserveOfToken` and `reserves`. The cut maps `vaultTokens` to `MultiAssetBasicVaultFacet` and the other two selectors to the family facet. Do not install the multi-asset reserve functions. They read a stored balance in slot `indexedex.vaults.basic`, and that balance is not this view.

Deployed liquidity is the raw liquidity number used in mint and burn. Deployed token reserves are the token amounts plus unpaid fees returned by `reserves()` and `reserveOfToken`. For each underlying token the deployed read is the live position: the amount implied by this position's liquidity, the current pool price, and the stored ticks, plus fees owed to this position in that token and not yet collected, using the existing position-amount and fee-owed reads. Do not add a new conversion formula. A booked local remainder is not in that read until a later `donate()` or `compound()` deploys it. The Reserves Lens address is stored under FS-OWN-01. This file does not add a new formula that calls it.

**FS-OWN-08.** The accepted Standard Exchange definition is in `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md`. `previewExchangeIn` and `exchangeIn` keep their current parameters and return `(uint256 amountOut, uint256 amountRefunded)`. There is no `WithRefund` sibling. Selectors stay `0x89d61912` and `0xd02d3063`. The ERC-165 id this vault advertises for `IStandardExchangeIn` is `0x59fb2971`, the XOR of the adopted selectors `0x89d61912` and `0xd02d3063`. The current Crane interface comment still implies `0x8c8035da`, the XOR of `0x89d61912` and the old `exchangeIn` selector `0x05562cc8`. Do not advertise `0x8c8035da`. ERC-165 cannot tell the old return width from the new one. Do not advertise `0x676ec907`. `IStandardExchangeInWithRefund`, `previewExchangeInWithRefund`, `exchangeInWithRefund`, and `ExchangeInWithRefundNotAvailable` are not part of the accepted definition. `ExchangeInNotAvailable` remains the unavailable error on that interface.

```solidity
function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
    external
    view
    returns (uint256 amountOut, uint256 amountRefunded);

function exchangeIn(
    IERC20 tokenIn,
    uint256 amountIn,
    IERC20 tokenOut,
    uint256 minAmountOut,
    address recipient,
    bool pretransferred,
    uint256 deadline
) external returns (uint256 amountOut, uint256 amountRefunded);
```

`exchangeOut` does not gain a refund return. `previewExchangeOut` does not gain a refund return. `previewExchangeOut` returns zero. `exchangeOut` still reverts `ExchangeOutNotAvailable()` and moves no tokens. A zero preview is not a promise that the execution route succeeds.

The other vaults must be updated to the tuple. This text enumerates the consumers. It does not implement the migration.

These six consumers reject a non-32-byte success. A successful `(uint256, uint256)` return is 64 bytes, so each treats that success as failure until it is migrated. Paths and lines are from `docs/research/se-fullspread-preview-consumers-20261103/REPORT.md`:

- `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol` lines 103-106. Empty-supply preview. `staticcall`, then `data.length != 32` returns 0.
- The same file, lines 121-125. Live preview. The same 32-byte gate, then a one-word decode.
- `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/wrapped/WrappedStandardExchangeRateProviderTarget.sol` lines 65-68. The same gate. Returns `(false, 0)`.
- `contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolHookTarget.sol` lines 437-444. `ret.length != 32` returns false, then a one-word decode.
- `contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolHookTarget.sol` lines 463-470. The same gate.
- `contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolHookTarget.sol` lines 474-481. The same gate.

These three ABI bindings still declare one word. Paths and lines are from that same report:

- `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` lines 45-48. `returns (uint256 amountOut)`. Comment selector `0x89d61912`.
- `frontend/apps/indexedex/app/insights/lib/insightsAbi.ts` lines 69-76. `previewExchangeIn` output is one `uint256`.
- `frontend/packages/protocol/src/protocolDetfAbi.ts` lines 33-40. `previewExchangeIn` output is one `uint256` named `amountOut`.

A typed Solidity call through the Crane interface reads that one word. Those call sites break when the interface return changes. They do not have their own length check.

`contracts/test/bases/FundedThresholdAssertions.sol` lines 60-63 decode one word and do not check the length. That helper is not one of the six gates. It migrates with the other one-word readers.

Every other one-word reader of `previewExchangeIn` in `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md` migrates to `(uint256 amountOut, uint256 amountRefunded)`. That index is the complete textual occurrence list: 1626 occurrences in 618 files. It includes comments and names, so it is wider than the decoder list. Do not paste it into this PRD. A call that ignores the returned word is still bound to the old interface and migrates with the other one-word readers.

`exchangeIn` keeps selector `0xd02d3063` and returns the same tuple. Callers that decode one word from `exchangeIn` must read the tuple. Do not adopt the comment selector `0x05562cc8`.

**FS-OWN-09.** Do not install `depositPair`, `previewDepositPair`, `redeemPair`, or `previewRedeemPair`. Map deposit to `exchangeBundleInForSingleOut` and `previewExchangeBundleInForSingleOut`, with `tokenOut` as the share. Map redeem to `exchangeBundleOut` and `previewExchangeBundleOut`, with `tokenIn` as the share and `tokensOut` as the two ERC-20 faces. Keep `donate` and `compound`. `donate` is an explicit exception. Keeping it does not restore PairToken issuance. `compound()` stays this selector. Its behavior is FS-OWN-14, not a PairToken ratio swap or quarter-cap, and not Weir's treasury performance fee.

The mapped redeem is the both-token exit. It pays the caller's claim in both tokens and does not swap. It does not sell one leg to pay the other. The one-token exit is canonical `exchangeIn`, with the share as `tokenIn` and one underlying as `tokenOut`. It is not `exchangeBundleOut` with one output. The amounts are the FS-OWN-30 exiting claim: unwanted withdrawn principal, plus the caller's opposing-token fee and opposing booked claim. A bundle argument combination that is not one of those two mappings is unsupported. It reverts the already-named `ExchangeBundleInForSingleOutNotAvailable` or `ExchangeBundleOutNotAvailable` for that function. Do not add a success path.

The accepted bundle signatures, from the accepted return-ABI report, are:

```solidity
function previewExchangeBundleInForSingleOut(uint256[] calldata amountsIn, address tokenOut)
    external
    view
    returns (uint256 amountOut, uint256[] memory amountsRefunded);

function exchangeBundleInForSingleOut(
    uint256[] calldata amountsIn,
    address tokenOut,
    uint256 minAmountOut,
    address recipient,
    bool pretransferred,
    uint256 deadline
) external returns (uint256 amountOut, uint256[] memory amountsRefunded);

function previewExchangeBundleOut(address tokenIn, uint256 amountIn, address[] calldata tokensOut)
    external
    view
    returns (uint256[] memory amountsOut, uint256 amountRefunded);

function exchangeBundleOut(
    address tokenIn,
    uint256 amountIn,
    address[] calldata tokensOut,
    uint256[] calldata minAmountsOut,
    address recipient,
    bool pretransferred,
    uint256 deadline
) external returns (uint256[] memory amountsOut, uint256 amountRefunded);
```

The accepted report's computed selectors are `0xc2fe8c7c`, `0xe7886166`, `0xa5952fc2`, and `0x11993461`. Its computed interface ids are `0x2576ed1a` and `0xb40c1ba3`. Recheck those ids with `type(I).interfaceId` before any ERC-165 registration. Do not invent further selector hex.

Paired events survive the selector drop. A bundle deposit emits `PairDeposited(address indexed caller)`. A bundle redeem emits `PairRedeemed(address indexed caller)`. No other arguments. Callers send and receive WETH only. Raw ETH is not a caller input or a caller payout. FS-OWN-17.

**FS-OWN-10.** Do not install `previewWithdrawalMode` or `wrappedNative()`. Remove `PkgInit.wrappedNative`. There is no `wrappedNative()` getter. Payout quotes use the accepted previews. The accepted routes use the ERC-20 face on `vaultTokens()`. `previewZapCredit`, `maxZapBps`, and `maxZapTickMove` are absent. No replacement view, cap, tick bound, or hidden constant is added. This lock does not publish an internal compound-or-collect branch.

### 1.4 Owner answers

These answers remain in force where a later sentence has not replaced them. The 2026-11-03 overrides are already applied in the sentences below. The 2026-11-04 locks are applied in FS-OWN-14, FS-OWN-26, FS-OWN-28, and FS-TEST-04.

**FS-OWN-11.** The genesis floor is `MIN_SHARES` (`1_000`) minted to `address(0)`. That balance is part of `totalSupply()`. There is no second share ledger and no other holder. The requirement is the balance: `MIN_SHARES` at `address(0)`, included in `totalSupply()`, and the mint does not revert. Use the Crane repo helper that writes `balanceOf` and `totalSupply` directly. Do not use `ERC20Repo._increaseBalanceOf`, and do not use the shared ERC-20 facet path. Both of those revert `ERC20InvalidReceiver` for `address(0)`. The floor mint is not part of `grossShares`, and it is not a fee mint.

**FS-OWN-12.** There is no sleeve target. Do not attempt to move a local balance toward `liquidReservePercentageOfVault` after a deposit, a withdrawal, or `compound()`. The 5% band is not a rule. FS-OWN-04.

**FS-OWN-13.** If nobody holds the PoolManager unlock, this vault calls `unlock()` and uses deployed liquidity. If another caller already holds it, `unlock()` reverts `AlreadyUnlocked` and this vault must not call it. Only canonical `exchangeIn` calls `modifyLiquidity` and `swap` directly on that open unlock. `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` still revert `ManagerAlreadyUnlocked`. It never takes another caller's lock. There is no sleeve. A borrowed one-token exit pulls the caller's deployed fraction and swaps only the FS-OWN-30 exiting claim, not principal alone, on that same open flag. The vault settles its own deltas before it returns. There is no sleeve payment and no `UnderlyingUnavailable` for an unpullable fraction. FS-OWN-31.

**FS-OWN-14.** `compound()` and `donate()` are authorized only for the current owner, a global operator, or a function operator for that selector. The owner check is a live read of `feeTo()` on the bound Vault Fee Oracle in `PkgInit.oracle`. The read is `VaultFeeOracleQueryFacet.feeTo()`, which returns `IFeeCollectorProxy`. The owner address is that proxy's address. This vault does not expose `feeTo()`. The owner may appoint both a global operator and a function-level operator. Follow the Crane operable model. `IOperable.setOperator(address,bool)` grants a global operator. `IOperable.setOperatorFor(bytes4,address,bool)` grants a function operator for one selector. Store those grants in `OperableRepo`. The maintenance comparison is a new modifier with that three-arm shape: the live `feeTo()` address, a global operator, or a function operator whose grant is for `msg.sig`. Do not reuse `OperableModifiers.onlyOwnerOrOperator` or another stored-owner facet for it. Do not store `feeTo()` at initialization as the owner a stored-owner modifier uses. Only that live owner may call `setOperator` and `setOperatorFor`. Do not gate those two calls with `MultiStepOwnableRepo._onlyOwner`. A function operator for another selector reverts. A global operator may call both maintenance functions. Any other caller reverts. A deposit, a withdrawal, and `exchangeIn` do not call `compound()` or `donate()`.

`compound()` has no donation input. `donate()` also compounds. Collected fees are the trading fees from providing liquidity, returned by `modifyLiquidity` as `feesAccrued`. A user deposit or withdrawal books those fees locally. It does not compound them. `compound()` later deploys the booked fees. Both maintenance calls then take those collected fees and the booked remainder and process that combined balance. A one-token call may swap fees or a booked remainder. A call that already holds both tokens is a proportional deposit and does not swap. Neither call swaps the deployed position. The one-token swap uses the FS-OWN-33 shape and the same unbounded price limit as the entry swap. There is no new price check, tick bound, or fee cap. A sandwich of the owner or operator's own call can still sell the fees or the booked remainder at a moved price. That exposure is accepted. It is not claimed absent.

One token: swap toward the position's ratio, as a one-sided user deposit does. The remainder must be in the token being processed. Book that remainder. Both tokens, from any mix of fees, donation, and an already booked balance: do not swap. Deposit the matched pair. The scarcer token is the proportionally smaller amount relative to the position ratio, not the smaller raw balance. That token is fully used. Book the excess of the other token. Book the actual held balance after the deposit, not a calculated leftover. That books a stray transfer as well. A non-atomic pretransfer can be booked too. Callers must keep a pretransfer atomic.

Best-effort means the simplest secure process. Do not invent an extra attempt, a fallback, or a swallowed failure to force a cleaner result. A failed step reverts. A remainder of that simplest deposit is booked. The call does not revert merely because a remainder remains. The size of a remainder does not matter. Call `compound()` again to process it.

`compound()` with no fees and no booked remainder returns with no state change and no event. A successful `donate()` emits `Donation()` even when it deposits nothing. A booked remainder is still processed by the maintenance call that holds it.

Emit `Donation()` when `donate()` is called. `Donation()` has no fields. It is a marker event, not an interface and not a field-bearing event. That empty argument list is final. Do not add a `Donation` interface or an ERC-165 id for it. Emit `Compounded()` when a deposit is made from collected fees or from booked tokens. A `compound()` call that deposits emits `Compounded()`. A `donate()` call that deposits collected fees or booked tokens also emits `Compounded()`. Booked tokens are treated as fees, including a donation remainder that was booked. There is no fee-origin store. `Compounded()` has no arguments. That empty argument list is final as of 2026-11-04. A call that deposits nothing does not emit `Compounded()`. A reverting call emits neither event. The vault does not emit its own swap or liquidity-add event. The PoolManager already emits `Swap` and `ModifyLiquidity` with the vault as `sender`. Filter on that sender for the amounts, price, and liquidity. `exchangeIn` emits no new vault event for that correlation. The events are `Transfer` and the PoolManager `Swap` and `ModifyLiquidity` events already named. `PairDeposited` and `PairRedeemed` stay on the bundle routes. This vault does not invent a second amount-bearing event.

**FS-OWN-15.** A one-token redemption withdraws the exiting holder's deployed fraction and swaps only that holder's FS-OWN-30 exiting claim. That claim is the unwanted principal plus the caller's opposing-token fee and opposing booked claim. The swap converts all of that unwanted side or reverts `AmountOutNotMet` and does not burn shares. The purpose of that swap is pool volume. It is a quantity rule, not a new cap. It does not swap the other holders' booked fees, and it does not sell the staying holders' inventory. A both-token exit does not swap. There is no sleeve to take first. The swap limit is FS-MONEY-01.

**FS-OWN-16.** `PkgInit.poolManager` stays as the PoolManager binding. The seven architecture addresses are immutables of the package deployment. Instance initialization writes those immutable addresses into the Uniswap V4 Protocol Aware Repo. It does not write only `poolManager`, and it does not write a second per-vault copy. FS-OWN-01.

**FS-OWN-17.** Do not install `wrappedNative()`. Remove `PkgInit.wrappedNative`. Callers send and receive WETH only. The vault does not accept or produce native ETH. Native ETH is wrapped or unwrapped only at the pool boundary. `vaultTokens()` substitutes the configured WETH address for native. That address is a `PkgInit` field. Initialization writes it with `WETHAwareRepo._setWeth`. The vault reads it from `WETHAwareRepo`. Do not install `wrappedNative()`. Do not hardcode the Robinhood `WETH9` constant. A Robinhood deployment passes that chain's WETH address. Another chain passes its own address at deploy. `bindingHash` covers this field.

**FS-OWN-18.** The Protocol Aware Repo stores the PoolManager, Position Descriptor, Position Manager, Quoter, State View, Reserves Lens, and Universal Router. They are package immutables, not hardcoded Robinhood constants. A deployment passes that chain's addresses. FS-OWN-01. Storing the Quoter address does not make a step-capped quoter the product quote. The quote rule is section 6.

**FS-OWN-19.** No view reverts by a vault error. An unsupported view route returns zero. `reserveOfToken` returns zero for an address that is not in `vaultTokens()`. `previewExchangeOut` returns zero. On an enabled vault, `exchangeOut` still reverts `ExchangeOutNotAvailable()` and moves no tokens. A disabled `exchangeOut` is FS-OWN-26. A zero preview is not a promise that execution succeeds. A busy or unlocked manager is not a view revert. Economic views return the computed value. `reserves()` and `reserveOfToken` wrap the deployed-reserve reads. There is no local term and no last-committed snapshot. There is no new step-cap error. An out-of-gas revert is an EVM error, not a vault error, and this lock does not define one.

**FS-OWN-20.** Unbooked token balances are not reserves and are not redeemable idle. A booked remainder is not a reserve until `donate()` or `compound()` deploys it. A pretransfer does not book the requested amount. `pretransferred == true` uses the unbooked held balance, up to the caller's maximum. A booked remainder is not that balance. The directive is `docs/vaults/PRETRANSFER_DIRECTIVE.md`. The refund amounts are FS-OWN-32. A balance sitting on the vault is not the caller's credit beyond that maximum. The unbooked remainder is not sent to `msg.sender` beyond the refund rule. A burn uses the caller's shares. Shares parked on the vault, including shares whose recipient was the vault, are not that credit. That is the absence of APEX-2026-039.

**FS-OWN-21.** `donate` uses the FS-OWN-14 authorization. The caller is the live `feeTo()` owner, a global operator, or a function operator for the `donate` selector. That check is the new three-arm modifier. It is not an existing owner facet. It accepts `vaultTokens()` and the share. It reverts when `totalSupply` is zero, before any swap. There is no donation before the first mint. A share donation burns the shares and does not withdraw, and it does not swap the shares. No shares are minted for an underlying donation. An underlying donation is deployed into the pool before `donate` returns. It is not left as idle. A one-token underlying donation swaps the combined one-token maintenance balance into the position's ratio and deploys that liquidity. It does not swap donated tokens only. If the combined balance already holds both tokens, the call is a proportional deposit and does not swap. The one-token swap spends the combined one-token maintenance balance from FS-OWN-14. It does not take an opposing token that is not part of that balance, and it does not swap the deployed position. It uses the same unbounded price limit as the entry swap. There is no new price check, tick bound, or fee cap. The existing position is not what gets sold. A remainder is booked, not returned to the donor. Held tokens processed because `donate()` also compounds follow the same one-token or both-token rule. `donate(address token, uint256 amount, bool pretransferred)` takes the three arguments the locks already name. `token` is one `vaultTokens()` entry or the share. `amount` is the directed amount. `pretransferred` is the existing flag. There is no recipient and no deadline. No selector hex is added. `compound()` takes no arguments. `donate()` uses tokens already transferred when `pretransferred` is set, and pulls the directed amount otherwise. The pretransfer maximum rule is FS-OWN-32. Emit `Donation()` with no fields when the call succeeds. FS-OWN-14.

**FS-OWN-22.** `vaultTokens()` is PoolKey `currency0`, then `currency1`, with `WETH` substituted for native. The address read for that substitution is the network `WETH` constant in FS-OWN-17. The pool-key check is only that the pool is initialized on the bound manager and the hook is `address(0)`. There is no inherited-domain check. Any initialized hookless pool is accepted. Do not add a minimum tick spacing.

**FS-OWN-23.** The diamond cut names the installed selectors. Do not install every selector exposed by `MultiAssetBasicVaultFacet`. `vaultTokens` is that facet. `reserveOfToken` and `reserves` are the family facet. FS-OWN-07. Protocol and position getters are the Crane facets in FS-OWN-01 and FS-OWN-02, not family query selectors.

**FS-OWN-24.** On a new deposit, take the fee shares from the new shares that deposit mints. Do not mint them on top. If `feeTo` is not `address(0)`, let `grossShares` be the shares that new deposit would mint before the fee, and let `feeShares = mulDiv(grossShares, clampedFee, 1e18)`. Mint `feeShares` to `feeTo` and `grossShares - feeShares` to the depositor. Do not mint any shares beyond `grossShares`. If either amount is zero, skip that mint. Do not mint a fee on the fee shares. This applies to a one-sided deposit and a bundle deposit, including the first deposit.

On the first deposit, `grossShares` is `added liquidity - 1,000`. The fee is taken from those minted shares, as it is on a later deposit. The 1,000-share floor is a separate mint to `address(0)`. It is not part of `grossShares`, and it is not a fee mint. On a later deposit, supply grows only by `grossShares`. On the first deposit, supply grows by `grossShares` plus the floor. On a later deposit, `grossShares = added liquidity * totalSupply / existing liquidity`, using `totalSupply` before the mint. The denominator is existing liquidity before this deposit is added. Idle balances, booked remainders, and `feesAccrued` are not in that denominator.

`previewExchangeIn`, `previewExchangeBundleInForSingleOut`, and `minAmountOut` use the depositor's net shares. The usage fee is charged only when this vault mints shares. A pass-through does not take that fee. An underlying-to-underlying `exchangeIn` is a pass-through: it abstracts the pool swap and mints no shares. This vault has no exact-out route, so an exact-out gross-up is not adopted. No delay on fee increases, no exit fee, and no new 0% override are added.

The Fee Oracle is not restricted. It may still store any WAD percentage up to `1e18`, including a per-vault override, because other vaults may need those values. This vault clamps the usage fee it applies. When it reads `usageFeeOfVault(address(this))`, a resolved fee above 30% is used as 30%. A resolved fee of 30% or less is used as read. 30% is `3e17` in the existing WAD unit, where `1e18` is 100%. The clamp is in this vault's read. It does not write the oracle. The same clamped fee is the fee in the netting formula and in the share previews named above. Do not preview the raw oracle fee and execute the clamp. Do not apply it to a pass-through.

The required precision is the ability to charge 0.001%. That is `1e13` in the WAD unit. The existing `mulDiv` against `1e18` already has finer precision, so use it. Do not round the fee to three digits. Do not add a minimum fee. A configured fee of zero stays zero. A configured fee above 30% does not give the depositor zero shares. This is not Weir's treasury performance fee.

A test that APEX-2026-044 is absent means this rule: no additional unbacked mint, and a round trip does not move existing holders' value to `feeTo`.

**FS-OWN-25.** A bundle deposit adds the declared amounts in proportion to the underlying pool. It books the fees `modifyLiquidity` returns. It refunds the remainder of the bundle. That remainder is not booked. It does not run the one-sided balancing swap. `exchangeIn` does support an underlying-to-underlying swap on the bound pool. That route is a pass-through and takes no usage fee. FS-OWN-24.

**FS-OWN-26.** A disabled vault reverts `IVaultRegistryDisableQuery.VaultDisabled(address(this))` on every execution route except a withdrawal, `donate`, and `compound`. The predicate follows the live V2 call site in `UniswapV2StandardExchangeInTarget`: a route whose input is not this vault's share is blocked. That predicate is widened from `exchangeIn` to every execution route. A withdrawal is share in and underlying out. That is canonical `exchangeIn` with the share as `tokenIn`, and `exchangeBundleOut` with the share as `tokenIn` and the two ERC-20 faces as `tokensOut`. A pass-through `exchangeIn` is not a withdrawal and reverts `VaultDisabled`. A bundle deposit reverts `VaultDisabled`. `donate` and `compound` are not in this block. They may run while the vault is disabled, under FS-OWN-14. Views do not revert `VaultDisabled`. FS-OWN-19. A missed deadline still reverts `DeadlineExceeded` before this check. FS-OWN-28. On an enabled vault, `exchangeOut` still reverts `ExchangeOutNotAvailable()`. A disabled `exchangeOut` is not a withdrawal, so it reverts `VaultDisabled`. The same predicate applies on a borrowed unlock. A buffered withdrawal still succeeds. A buffered non-withdrawal reverts `VaultDisabled`. FS-A38.

**FS-OWN-27.** The deployed reserve is accounted as one value, `liquidity`. It is raw V4 liquidity. Share minting and burning use that number. Token amounts stay in their own decimals when they go into `getLiquidityForAmounts`. No amount scaled to a token's decimals, and no use of `decimals()`, enters the share formula. `decimals()` returns 18. That is metadata. It is not a scale, and it is not an input to the mint or burn. Do not multiply the stored share balance, or the floor, by a constant to match `decimals()`. A wallet that divides the balance by `1e18` is formatting the liquidity number. It is not reading a rescaled share.

**FS-OWN-28.** A missed deadline reverts `IStandardExchangeErrors.DeadlineExceeded(deadline, block.timestamp)` before any other work on a route that takes `deadline`, including the FS-OWN-26 disable check. This lock does not add a deadline argument to `donate` or `compound`.

**FS-OWN-29.** This vault does not implement `getRate()`. FS-OWN-03 stays closed. Rate-provider instances are deployed by `IStandardExchangeRateProviderDFPkg` for a configured Standard Exchange vault and rate-target pair. `PkgArgs` carries `reserveVault`, `rateSubject`, and `rateTarget`. One vault can have as many of those instances as it has `vaultTokens()`. That count is the maximum useful number, not an enforced limit. Do not add a cap. This vault stores no rate-provider address and exposes no rate-provider getter. The hook configures a rate-provider address for each Standard Exchange liquidity leg. The required hook rows use that configured instance. They do not derive a provider from this vault, and they are not recorded incompatible.

The rate subject is this vault, used as liquidity in the test pool. There is a scenario for each underlying token, so the rows test that this vault can be rated and that the integrated token can be token0 or token1. Separate pools may hold the same vault, each with a rate provider whose `rateTarget` is a different underlying token. That tests two pools valuing the same vault at different targets. The rate provider, and every other consumer of the old 32-byte preview return, must read the tuple in FS-OWN-08. This lock does not add a vault rate.

**FS-OWN-30.** On a share-minting deposit, `modifyLiquidity` returns `feesAccrued`. Book `feesAccrued`. Do not include those fees in the deposit, the caller's share credit, or a swap. Swapping them into the deposit is forbidden. A mint preview does not credit the new depositor with existing fees.

On a withdrawal, `feesAccrued` is the unpaid fee-owed read already named for `reserves()`. Tokens booked from an earlier `modifyLiquidity` return are only in the booked-balance term. They are not counted again. On a withdrawal, measure before the burn. `totalSupply()` before the burn is the total shares, including the floor. The caller's fee claim is `floor(feesAccrued * sharesBurned / supplyBeforeBurn)` for each token. The caller's booked claim is `floor(bookedBalance * sharesBurned / supplyBeforeBurn)` for each booked balance. Do not divide the share fraction before multiplying by the balance. Include that portion in the exit. Book the rest for the other holders. Principal removal is `liquidity * sharesBurned / supplyBeforeBurn`, rounded down by that same integer division.

A one-token exit converts all unwanted withdrawn principal, plus the caller's opposing-token fee and opposing booked claim, into the selected token, or it reverts `AmountOutNotMet` and does not burn shares. It does not pay, book, or keep that residual. The caller's requested-token fees and requested booked claim are paid to the caller. The other holders' shares are booked, not swapped. The exit swaps only that exiting claim. It does not swap the other holders' booked fees, and it does not sell the staying holders' inventory. The price limit is the unbounded entry limit. There is no new price check.

A both-token exit pays that same claim in both tokens and does not swap. It books the rest for the other holders.

An exit preview uses the same apportioning as the execution it quotes. A one-token exit preview uses the same swap, so the quoted `amountOut` matches execution. A both-token exit preview does not swap, and its quoted outputs match that execution. That exit quote is the share valuation, and it includes accrued fees. It is not `getRate()`. A mint preview is not that valuation.

The old no-leftover-shortfall-revert sentence is scoped to the former sleeve. It is not an exit rule. A caller-set one-token minimum still reverts `AmountOutNotMet`. A caller-set bundle minimum reverts `MinAmountNotMetAt(uint256 index, uint256 minAmount, uint256 actualAmount)`. There is no sleeve top-up. Do not declare `MinAmountNotMet`.

**FS-OWN-31.** The unpullable borrowed exit does not occur. On a borrowed unlock the vault does not call `unlock()`. It calls `modifyLiquidity` and `swap` directly, pulls the caller's deployed fraction, swaps only the FS-OWN-30 exiting claim, not principal alone, and settles its own deltas before it returns. There is no sleeve payment and no `UnderlyingUnavailable` for an unpullable fraction. `required` and `available` have no case to measure. That sentence closes only the unpullable-fraction case. It does not remove `AmountOutNotMet`, a funding failure, or `SettlementMismatch`. The call is not a sleeve case if this vault's own code calls `unlock()` again, or if the hook never calls the vault.

**FS-OWN-32.** Input that does not become liquidity is not minted into shares and is not left for the other shareholders.

On the pull path, `pretransferred == false`, pull the declared amount from `msg.sender`, then refund the unkept amount of that same token to `msg.sender`. Pulling only the consumed amount is not the rule. Declared amount equals amount consumed plus amount refunded. Output goes to `recipient`. A zero refund transfers nothing. Refunded wei are not credited as a deposit.

On the pretransfer path, the vault does not ask where the tokens came from. It uses the unbooked held balance, up to the caller's maximum. If that maximum is within the unbooked balance, the refund is the maximum minus the amount used, in the token the caller provided. Do not refund the whole remaining unbooked balance in that case. That balance may be staged for another call. The vault has no instruction to process it. If the maximum is larger than the unbooked balance on a one-token call, refund that unbooked balance. Do not spend that unbooked balance. Do not pull the shortfall. Do not refund maximum minus used. A larger maximum is not a revert on that one-token call. The caller may declare any maximum. That unbooked balance is not minted into shares. A bundle is atomic. If any declared maximum exceeds that token's unbooked balance, the call reverts before any leg is processed. No declared amount is spent. No shares are minted. Do not add a new error for that revert. A non-atomic pretransfer is the caller's risk. An address without bytecode cannot pretransfer. The accepted report names that existing revert `EOAPretransferNotAllowed()` in current comments and does not redeclare it. This PRD does not declare a second error for the same rule.

A donation or compound remainder is booked, not refunded. That booking is not this refund rule. A share-minting deposit's `feesAccrued` is booked, not refunded.

These rejects are execution rejects. A view does not revert them. An unsupported view route returns zero. `recipient` may be the hook's recipient, including a user on unwrap. `recipient == msg.sender` is not a hard rule. A recipient of `address(0)` reverts `InvalidRecipient()`. The vault as recipient also reverts `InvalidRecipient()`. `tokenIn == tokenOut` reverts `InvalidRoute`. `amountIn == 0` reverts `EmptyExchange`. A token of `address(0)` reverts `TokenNotExchangeable`. That is not the zero-recipient reject. These functions are not payable. The caller passes the wrapped ERC-20 face. After WETH substitution, a reserve query uses that ERC-20 address. This PRD does not add a new pool exclusion for a collapsed face.

A preview of a refund does not transfer and does not read a balance. It assumes the declaration is available. Execution may refund a different amount. Bit-exact equality of the refund word is not required. The exit quote's output match is FS-OWN-30, and it is not waived by that refund sentence. `minAmountOut` and `minAmountsOut` bind.

**FS-OWN-33.** A one-sided share mint runs the balancing swap. A bundle deposit does not. For a one-sided deposit, and for a one-token `donate` or `compound`, choose the greatest liquidity the following add can take. The swap output is the other token that liquidity consumes. The unswapped input is the processed token that liquidity consumes. Rounding leaves any remainder in the input token. The swap input is not the processed-token amount the add itself consumes. The price limit is `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`. That is not `maxZapTickMove`, and no tighter cap is added.

The 48% remark was a possible starting point for sizing a deposit or donation swap so that a refund, if one is issued, is in the token the caller provided. It is not a required refund, and it is not an exit rule. Do not require a 48% swap. Do not require an "about half" swap. The remainder-in-input-token result is what lets a refund, when one is issued, be paid in the token the caller provided.

## 2. Authority and precedence

| Source | Role |
| --- | --- |
| `IMPLEMENTATION_PLAN_BLOCKERS.md`, including the 2026-11-03 overrides | Later lock. Wins over an earlier sentence in that file and over an older sentence in this PRD. |
| `docs/vaults/PRETRANSFER_DIRECTIVE.md` | Binding pretransfer rule. Wins over an older pretransfer sentence, including the accepted ABI report's short-declaration revert. |
| `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md` | Accepted return ABI and bundle interfaces. The owner lock in that report wins over its earlier council text. A later full-spread lock still wins over a sentence there. |
| `docs/research/se-fullspread-preview-consumers-20261103/REPORT.md` and `INDEX.md` | Consumer enumeration for the 64-byte preview return. F13 is accepted. F14's principal-only withdrawal sentence is not. |
| `contracts/protocols/strategy/weir/WeirVaults.sol` | Source of the deposit, withdrawal, issuance, and compound rules this PRD still states. Its multi-vault manager, administration surface, treasury performance fee, sleeve, auto-compound, and native caller payout are not inherited. |
| FS-FACET-01 and FS-PKG-01 | This family's package inputs. No PairToken package field or economic rule is inherited. |
| `contracts/hooks/uniswap/v4/standardExchange/` | Current hook bindings. Do not redesign them here. Migrate a 32-byte preview gate under FS-OWN-08. |
| `CLAUDE.md`, `docs/agent/INDEXEDEX_AGENT_LAW.md`, `.github/ASSISTANT_CODING.md`, `.github/ASSISTANT_TESTS.md` | Registry, token, compiler, and test law. |
| Crane architecture, IndexedEx testing, and Uniswap V4 hook-package skills | Packaging and production-first tests. |

PairToken stage one is not an economics authority. Do not inherit S1-ACC-02, S1-ACC-07, S1-D03's dead-share sentence, S1-OP-02's zap caps, S1-OP-05's ratio swap and quarter-cap, S1-P05, S1-P07, S1-EXIT-01's collection-only fallback, S1-X15, or S1-X17. Issuance, entry settlement, compound, and idle are FS-MONEY-01. An unnamed PairToken economic clause does not survive because this file used to inherit by ID.

These constraints stay, and they are not PairToken economics:

- FS-X01 permits the already-unlocked path only for canonical `exchangeIn`. `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` still revert `ManagerAlreadyUnlocked`. `depositPair` and `redeemPair` are not installed. There are no SY mutators.
- FS-OWN-05 removes every Standardized Yield selector. Do not replace `exchangeRate` with another denomination.
- FS-OWN-03 withdraws `getRate`. Do not install `IERC4626`, a transition quote, an external-state quote, or `IStandardExchangeRateQuote`. The external provider in FS-OWN-29 is not this vault's rate.
- Hook bindings, compiler law, and registry law stay. Do not rewrite them to remove a PairToken filename reference. The FS-OWN-08 return migration is required.

Do not install `IStandardExchangeTransitionQuote`, `IStandardExchangeUnlockContextQuote`, or `IStandardExchangeExactOutputQuantityQuote` unless FS-HOOK-04 cites a consumer that rejects without one. The ordinary exact-input hook path must show the existing ERC-165-gated fallback to standard previews. A stub that returns live values for a projected state is forbidden.

### 2.1 Dispositions retained from advisory

| Topic | Final choice | Not adopted |
| --- | --- | --- |
| `getRate` | Withdrawn by FS-OWN-03. Not installed. The hook configures an external provider. FS-OWN-29. | Keep the prior one-share formula. A thirteenth `RateFacet`. Return zero below one share. Bind the provider and call it this family's rate. |
| Supply below `1e18` | Withdrawn with `getRate`. FS-OWN-03. | A live `InsufficientRateSupply` requirement. |
| Unlocked surface | Canonical `exchangeIn` only. A batch that includes this vault is not a revert. | Borrowed unlock on compound, donate, paired methods, or SY. |
| Locked unlock count | One vault-started unlock per planned manager action. | One unlock per public call. |
| Recipient | Output may be paid to the hook's `recipient`, including a user on unwrap. Zero and the vault are rejected. | `recipient == msg.sender` as a hard rule. A hook allowlist. |
| Entry remainder | Unused declared input is refunded to the payer under FS-OWN-32. It is not booked and it is not minted. `feesAccrued` on a share-minting deposit is booked. A donation or compound remainder is booked. | `J_i` booking of unused entry input. `IncompleteConversion`. Every input wei becomes liquidity. Refunding a donation remainder. |
| Identity `token == share` | Not a passing row. Current hooks reject it unless `asset()` exists. Do not add `asset()`. | Greening FS-A24 by adding `asset()` or editing the hook. |
| Sleeve | Absent. FS-OWN-04. | A local target, a 5% band, or `localReserves()`. |
| Quote method | The mathematical result of the operation. Section 6. | A 64-step cap, a minimum tick spacing, a partial fill, or `QuoteWorkLimit`. |

## 3. Facets

### FS-FACET-01 — Package inputs

`PkgInit` uses this family's facet order. PairToken facet order is not inherited economics. FS-OWN-05 removes `syMoneyFacet` and `syQueryFacet`. It is not an open `IFacet[]`. Do not pass a PairToken facet address into this package. Family facets are this family's implementations. `vaultTokens` is `MultiAssetBasicVaultFacet`. `reserveOfToken` and `reserves` are the family custom facet. Those are two facet addresses. `basicVaultFacet` is not one facet that exposes all three. Package validation must not require `getRate`. FS-OWN-03 forbids installing it.

The Crane Uniswap V4 Protocol Aware facet and the Crane `UniswapV4SinglePositionAware` facet are package inputs. Their getters are externally callable on this vault. This text does not invent the `PkgInit` field names for those two inputs.

Shared facets stay the current shared implementations:

| Field | Selectors |
| --- | --- |
| `erc20Facet` | The nine canonical ERC-20 and metadata selectors. |
| `erc2612Facet` | `permit`, `nonces`, `DOMAIN_SEPARATOR`. |
| `erc5267Facet` | `eip712Domain`. |
| `basicVaultFacet` | Not one shared facet. `vaultTokens` is `MultiAssetBasicVaultFacet`. `reserveOfToken` and `reserves` are the family custom facet. FS-OWN-07. |
| `standardVaultFacet` | `vaultFeeTypeIds`, `contentsId`, `vaultTypes`, `vaultConfig`. |

Family facets:

| Field | Selectors |
| --- | --- |
| `moneyFacet` | `exchangeIn`, `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, `compound`. FS-OWN-09. Do not install `depositPair` or `redeemPair`. |
| `quoteFacet` | `previewExchangeIn`, `previewExchangeBundleInForSingleOut`, `previewExchangeBundleOut`. `previewExchangeIn` returns the tuple. Do not install `previewZapCredit`, `previewWithdrawalMode`, or the paired previews. |
| `outFacet` | `previewExchangeOut`, `exchangeOut`. `previewExchangeOut` returns zero and does not gain a refund return. `exchangeOut` reverts `ExchangeOutNotAvailable()` without taking funds or changing state, and does not gain a refund return. |
| `queryFacet` | Do not install `poolManager()` (FS-OWN-01), a family-only `poolKey()` (FS-OWN-02), `rateAsset()`, `getRate()` (FS-OWN-03), `wrappedNative()` (FS-OWN-10), or `localReserves()`. Those protocol and position getters live on the Crane facets. |
| `callbackFacet` | `unlockCallback`. |

`syMoneyFacet` and `syQueryFacet` are not package inputs. FS-OWN-05.

The old 61-selector count included `getRate` and is not the manifest. Recount from the current package when it is built. `linkedComponents()` is facet metadata, not an installed proxy selector. Cite the current package `_expectedSelectors` and S1-ARCH-04 when implementing. Do not invent selector hex in this PRD beyond the accepted selectors already named in FS-OWN-08 and FS-OWN-09.

Family errors, declared on the family interface, with selectors computed later:

- `InvalidUnlockedContext()`
- `SettlementMismatch()` where execution cannot close this diamond's own touched deltas
- `ManagerAlreadyUnlocked()`, the vault guard when a non-`exchangeIn` route finds the manager unlocked
- `ReentrantOperation()`, the vault guard in FS-UNLOCK-02
- `InvalidRoute()`, the vault guard when `tokenIn == tokenOut`
- `MinLiquidityNotMet()`, the first deposit that does not exceed `1_000` liquidity
- `InvalidRecipient()`, a recipient of `address(0)` or this vault

`AlreadyUnlocked` is the PoolManager error from `unlock()` while unlocked. It is not `ManagerAlreadyUnlocked`.

`InsufficientRateSupply`, `RateNormalizationOverflow`, and `RateUnavailable` are withdrawn with `getRate`. Do not declare them for this family. Do not declare `IncompleteConversion`, `QuoteWorkLimit`, or `ExchangeInWithRefundNotAvailable`. Do not use `UnderlyingUnavailable` for an unpullable borrowed fraction. Accepted interface errors stay on the accepted interfaces: `EmptyExchange`, `TokenNotExchangeable`, `ExchangeInNotAvailable`, `AmountsLengthMismatch`, `ExchangeBundleInForSingleOutNotAvailable`, `TokenAmountsLengthMismatch`, `DuplicateOutput`, `MinAmountNotMetAt`, and `ExchangeBundleOutNotAvailable`. This PRD does not redeclare them as new family errors.

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
- one facet and one target file for money, quote, out, query, and callback. The target filename is `UniswapV4FullSpreadStandardExchangeVaultMoneyTarget.sol` and the same pattern for the others. Do not use a shortened literal `MoneyTarget.sol`. Do not create SY money or SY query facet files.

`TestBase_UniswapV4FullSpreadStandardExchangeVault.sol` goes under the family's `test/bases/`. Specs go under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`.

Storage uses a new namespaced slot, `keccak256(abi.encode(namespace)) - 1`. It must not equal PairToken's slot or Wings' slot.

The Protocol Aware pair is created under `lib/crane/contracts/protocols/dexes/uniswap/v4/aware`. `UniswapV4SinglePositionAware` is a Crane repo and facet. This text does not assign it a directory beyond that Crane home. Do not put either pair inside the full-spread family directory. Both are part of this directive, including their Crane tests. This text does not write that code.

The new owner and operable modifiers are part of this directive. Their file names are not given. Do not reuse the existing owner facets for the live `feeTo()` check. Operator authorizations stay in `OperableRepo`.

### FS-PKG-01 — `PkgInit` and `PkgArgs`

`PkgInit`, in binding order: the facet fields above, including the two Crane facet inputs, then `poolManager`, `registry`, `oracle`, `diamondFactory`, and `linkedLibraries` as `address[6]` for Math, Projection, SwapProjection, Planner, Execution, and ExecutionPreparation. `weth` is a `PkgInit` field. `wrappedNative` is not a field. Initialization writes `weth` with `WETHAwareRepo._setWeth`. The two Standardized Yield facet fields are absent. The `poolManager` field is an address binding, not permission to install a family `poolManager()` selector. The other six architecture addresses are package immutables of the same deployment. They are infrastructure bindings and are covered by `bindingHash`, the same as `poolManager`. This text does not invent their struct field names. FS-OWN-01.

`PkgArgs` is this family's set. It is not the PairToken set. No hook allowlist:

- `PoolKey poolKey`, stored through `UniswapV4SinglePositionAware`, not as proof that `poolKey()` is a family-only selector
- `string name`
- `string symbol`

`maxZapBps` and `maxZapTickMove` are not fields. No replacement cap or tick bound is added. `rateAsset` is not a field.

`bindingHash` covers every `PkgInit` field. `calcSalt` and `processArgs` run by delegatecall and use immutable bindings and self calls.

`deployVault(PkgArgs) returns (address)` goes through the bound IndexedEx vault registry. No second factory. The PoolManager is not CREATE3'd by this package. Tests deploy it through the current artifact-backed CREATE3 helper, as FS-TEST-01 says.

`processArgs` reverts `NotCalledByRegistry` unless `msg.sender` is the bound registry and `address(this)` is the bound `diamondFactory`. Both conjuncts are required.

The package still lists `SwapProjection` and `ExecutionPreparation`. PairToken economics are not inherited. The slots stay. The engineer assigns already specified operations to them. This PRD does not design those libraries.

### FS-PKG-02 — Validation

Reject, without a partial diamond:

- A missing or code-empty component, a family facet whose linked-component hash does not match, or a cut that installs `getRate` or `rateAsset`. `InvalidComponent`.
- A pool key that is not initialized on the bound manager, or has a nonzero hook. `InvalidPoolKey`. Do not reject "outside the inherited domain."
- Do not reject a designated `rateAsset` argument. FS-OWN-03 removes that argument and that error. Rejecting an installed `rateAsset` selector remains the cut rule above.
- The `processArgs` context failure above.
- Proxy initialization that does not match the bound package and arguments. `InvalidInitializationContext`.
- A second initialization. `AlreadyInitialized`.

There is no wrapped-native package argument and no `InvalidWrappedNative` check on one. Initialization installs the name, symbol, pool key, full-range ticks, and salt `bytes32(0)`. It writes the seven package-immutable addresses into the Protocol Aware Repo. It does not store a designated rate token. It does not store `feeTo()` as a stored owner. The first depositor creates the position. Genesis issuance follows FS-MONEY-01 and FS-OWN-24. This update does not add Weir's treasury performance fee.

## 5. Money and unlocked entry

### FS-MONEY-01 — Weir-adapted money rules

The public selectors stay the accepted Standard Exchange routes, plus locked `donate` and `compound`. Do not install Weir's `deposit`, `withdraw`, `zap`, or `zapTo` selectors. Citations below are the Weir operations the current PRD named. They survive only as restated here.

- A pull-path entry pulls the declared amounts from `msg.sender`, then sends the unkept amount of each declared token back to that payer. FS-OWN-32.
- A positive PoolManager token credit on entry settlement is returned to the payer under FS-OWN-32. It is not booked without shares. `feesAccrued` is not that credit. Share credit to `recipient`, who need not be the payer, is the depositor's net shares under FS-OWN-24. Those are different amounts.
- There is no consumption-equality check and no `IncompleteConversion` error.
- The entry swap, when one is needed, uses the FS-OWN-33 shape. Its price limit is `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`. That is not `maxZapTickMove`, and no tighter cap is added. The redemption swap uses that same unbounded limit. There is no new price check, tick bound, or fee cap. A caller who sets no minimum can sell their own input at the live price. That sale does not spend the staying holders' inventory.
- On the first deposit, reject added liquidity less than or equal to `MIN_SHARES` with `MinLiquidityNotMet()`. The first add must exceed `1_000`. Before the fee, the minted shares are `added liquidity - 1,000`. `MIN_SHARES` is `1_000`. The floor is minted to `address(0)` and stays in `totalSupply`. It is not credited to the depositor. The fee is taken from the pre-fee shares under FS-OWN-24. The depositor receives the net. The source's intermediate `totalShares = MIN_SHARES` step is not a second ledger.
- For an existing supply, `grossShares = added liquidity * totalSupply / existing liquidity`. The denominator is existing liquidity before this deposit is added. Idle balances are not in that denominator. The fee is taken from `grossShares`. A share-minting deposit books `feesAccrued` and does not include it in the share credit or in a swap.
- A deposit, a withdrawal, and `exchangeIn` do not call `compound()` and do not deploy the staying holders' booked balance. A withdrawal does pay and, on a one-token exit, convert the caller's FS-OWN-30 booked claim.
- `compound()` is FS-OWN-14. It is not permissionless. Leftover after the simplest deposit is booked. It is not a sleeve. The source's `perfFeeBps` cut to `treasury` is not added. This is not PairToken's no-fee rule. It is the absence of an unauthorized fee.
- A withdrawal removes `liquidity * sharesBurned / supplyBeforeBurn` and pays the caller's FS-OWN-30 claim. It does not pay another holder's booked balance or an unbooked balance. This family does not install `zapTo`. A one-token exit pays only the selected token or reverts `AmountOutNotMet` without burning. A both-token exit pays the claim in both tokens and does not swap.
- Unused declared input is refunded under FS-OWN-32. `previewExchangeIn` and `exchangeIn` already return the refund word. Do not add a refund return to `exchangeOut` or `previewExchangeOut`.

Callers send and receive WETH only. Native ETH is wrapped or unwrapped only at the pool boundary. A wrapped-native boundary does not make the vault accept or produce native ETH.

The 12,000,000 gas transaction ceiling and the 5,000,000 preview ceiling stay. A hook-composed transaction must fit the 12,000,000 ceiling or be recorded as an unresolved narrowed route. It is not a passing measurement and not a waiver.

### FS-UNLOCK-01 — Two dispatch paths, one engine

Current buffer and unwrap helpers call `IStandardExchangeIn.exchangeIn` while the PoolManager is already unlocked. Buffer helpers observed in the dual and weighted claim code pay `address(this)`. Weighted `unwrap` pays the hook's `to` argument, which can be a user. A new selector would not be called. Do not add `exchangeInUnlocked`.

After ordinary route, deadline, amount, and authority checks, `exchangeIn` reads `TransientStateLibrary.isUnlocked` on the bound manager:

- Locked: FS-UNLOCK-03.
- Unlocked: FS-UNLOCK-02.

`isUnlocked` selects the path. It is not authorization. Allowance, minima, deadline, and share authority still apply. The PoolManager is not the depositor. Inclusion of this vault in a batch swap with other Uniswap V4 pools is not a revert. The earlier exclusion is removed. The borrowed-unlock path stays.

`exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` keep `ManagerAlreadyUnlocked()` on this path. There are no paired selectors and no SY mutators.

### FS-UNLOCK-02 — Borrowed unlock

When `exchangeIn` takes the unlocked path:

1. The vault is initialized and idle. The callback hash is empty. Reservations are zero. This diamond's own backing-currency deltas on the bound manager are zero. A reentrant borrowed entry reverts `ReentrantOperation`. A close that cannot settle this diamond's own deltas reverts `SettlementMismatch`. The initialized, idle, callback-hash, and reservation checks have no separately named error. Do not treat either named error as a free choice for every failed check.
2. The caller has code, pays the input, and is the share owner burned on exit. `pretransferred` is false. The function is nonpayable, so a value-bearing call fails at the ABI boundary. Do not specify `InvalidUnlockedContext` for `msg.value != 0`. `recipient` may be the caller or another address, but not zero and not the vault. Output is paid to `recipient`. Otherwise, a failed funding or route check uses the inherited error, and a borrowed-path context miss uses `InvalidUnlockedContext`.
3. No payer, callback payload, or foreign creditor is accepted. Burn only the caller's shares.
4. Dispatch each selected action to the same internal action, account, and settlement code used by the locked path. Do not call `unlock`. Do not call `unlockCallback`. Do not copy the locked callback's final `getNonzeroDeltaCount` check. That count is global. The hook and router may hold open deltas. Do not call `compound()`.
5. `modifyLiquidity` and `swap` run only on this diamond's hookless pool key. The position owner remains this diamond. The only position written is the full-range salt-zero position. A one-token exit pulls the caller's deployed fraction and swaps only the FS-OWN-30 exiting claim, not principal alone. It does not sell the staying holders' inventory.
6. Settlement of a debt is atomic for that currency: sync, transfer or value, settle, then take credits. Do not `settleFor` a foreign address. `PoolManager.sync` writes the global transient `CURRENCY_SLOT` and `RESERVES_OF_SLOT` in `CurrencyReserves`. Do not assume an outer actor's sync checkpoint remains valid. Do not clear another address's sync to hide a clobber. If the sequence cannot close this diamond's own touched deltas without taking a foreign credit, revert `SettlementMismatch`. The vault settles its own deltas before it returns.
7. Before return, this diamond's touched currency deltas are zero. Assert that per address. Do not require the global nonzero-delta count to be zero. Do not settle the hook's or the router's deltas.
8. A failure reverts the vault call and its descendant effects. If the outer caller catches it, the vault state is restored and the caller still owes its own settlement. The catch does not relock the manager. There is no sleeve fallback.

### FS-UNLOCK-03 — Locked path

Ordinary entry keeps the inherited per-action dispatcher. For each selected manager action that needs an unlock, commit `keccak256(abi.encode(operation, payload))`, call `unlock` once for that action, accept the callback only from the bound manager, only while the guard is held, and only once for that payload. Then settle that action and verify the manager has relocked before the next action. Nested unlock and replay stay forbidden. The public-operation guard stays active across the plan, token calls, and final payout. The callback does not call `compound()` before deposit or withdrawal.

`unlockCallback` remains unusable as a deposit. An external unlock does not satisfy a committed hash.

## 6. Rate, quote, and issuance

| Surface | Meaning | Forbidden substitute |
| --- | --- | --- |
| Issuance | FS-MONEY-01 and FS-OWN-24. `previewZapCredit` is absent. A mint preview does not credit existing fees to the new depositor. | S1-ACC-07. `J_i` booking. A replacement zap-credit view. |
| SY `exchangeRate()` | Not installed. FS-OWN-05. | A replacement denomination. NAV. |
| Exit preview | The same apportioning as execution, including accrued fees. That quote is the share valuation. A one-token quote includes the same swap, so `amountOut` matches execution. A both-token quote does not swap. | `getRate()`. Whole-book value divided by supply. A sleeve-maintenance term. |
| Mint preview | Net shares under the clamped fee. Existing fees are not credited to the new depositor. | A preview that adds `feesAccrued` to the new depositor's shares. |
| `getRate()` | Not installed. FS-OWN-03. | The withdrawn one-share formula. NAV. The external provider's result called this family's rate. |
| `previewExchangeOut` | Returns zero. No refund word is added. | A coded vault revert. A refund return. |

The quote is the mathematical result of the operation. Do not choose a V4 quoter against an analytic planner as the product rule. The plan names the one engine shared by preview and execution. That name is an implementation note, not a new product rule and not a step cap. Do not invent a 64-step cap, a minimum tick spacing, a partial fill, or a failure mode for a quote that cannot finish. Do not declare `QuoteWorkLimit`. Dust-tick liveness is the APEX-2026-041 regression: a normal deposit and redeem must not depend on an undocumented cap. That is a test, not a new spacing rule. Storing the Quoter address does not change this rule.

### FS-RATE-01 — Withdrawn

Do not implement `getRate`. The prior formula, `InsufficientRateSupply`, `RateNormalizationOverflow`, and `RateUnavailable` are not requirements. Do not bind `StandardExchangeRateProviderFacet` and call its result this family's rate. The hook rows in FS-OWN-29 use a configured external instance. A missing provider on one of those required rows is not closed by installing `getRate`, and it is not recorded as an incompatible hook row. A different cited reject remains FS-HOOK-04.

## 7. Hook integration

### FS-HOOK-01 — Families and bindings

Use the package interface in each family's `interfaces/` directory.

| Family | What the test binds | What a pass proves |
| --- | --- | --- |
| `single/` | One `standardExchange` and one `pairToken`. | One-vault borrowed `exchangeIn` through the hook's `beforeSwap`, both exact-input directions. Not a two-vault proof. |
| `constantProduct/single/` | One buffered SE, one pair token, one raw token. | FullSpread as the buffered leg. The raw leg is a transfer unless the fixture shows a conversion. Name which leg converted. |
| `dual/` | Two SE arguments and two tokens. | The canonical cross-vault proof in FS-HOOK-02. |
| `orbital/` | Package fields `se0`, `se1`, `se2` and `rp0`, `rp1`, `rp2`. The hook view is `standardExchange(uint8)` and `rateProvider(uint8)`. | A valid three-leg bind with FullSpread buffered on one leg and another SE share on another, roles named. |
| `weighted/` | Arrays, `n` in 2 through 8. | At least a 2-leg setup and one larger supported setup. |
| `stable/quad/curve/` | Fixed four-leg arrays. | Four valid legs. Do not treat a volatile share as a peg. |
| `stable/quad/balancer/` | Dynamic arrays, 2 through 5 legs. | A 2-leg setup and a 5-leg setup. Do not copy a fixed-four constructor. |

No new hook-package field is authorized. The hook configures an already supported rate-provider address per Standard Exchange liquidity leg. FS-OWN-29.

### FS-HOOK-02 — Canonical cross-vault fixture

The passing cross-vault proof is:

1. FullSpread is the buffered leg. `standardExchange` is this vault. The hook is configured with an `IStandardExchangeRateProviderDFPkg` instance for this vault and one rate target. The required rows are FS-OWN-29. Do not name a `rateAsset`. Do not bind this vault's `getRate`. Do not invent a provider inside this vault to make the row pass.
2. The other SE is not asked to mint or redeem inside the outer unlock. Current PairToken rejects that context. Its share may be an identity leg only if the current package accepts `token == se` without `asset()`. If it rejects, that identity bind is FS-HOOK-04, not a pass. The other leg can still be a raw token or a share transfer that the hook accepts without calling that vault.
3. The two backing pool keys differ. One direction mints FullSpread shares while the manager is unlocked. The reverse burns them. Assert balances, position owner, ticks, salt, and per-address deltas.
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
3. A missing quote interface, an `asset()` requirement, a `SameToken` or pair-overlap reject, or an incompatible denomination other than the FS-OWN-29 rows is a separate requirement. Name the consumer, selector, arguments, and revert. Do not implement that change here, and do not stub a transition quote.

A cited reject is an unresolved integration record. It does not close the canonical FS-HOOK-02 proof. It may close a family row only when that family's topology cannot express the canonical fixture, and the record says so. The FS-OWN-29 rows are not that record.

## 8. Testing

### FS-TEST-01 — Harness

Place the TestBase under the family's `test/bases/`. Follow the current PairToken setup: extend `IndexedexTest` and the canonical native-wrapper base, call parent setups in the current order, and deploy the PoolManager through the existing artifact-backed CREATE3 helper. Deploy facets and the package through the current factory and manager paths. The hook under test and this vault bind that same manager. Two managers do not prove FS-UNLOCK-02.

Bootstrap shares only through the accepted public entry routes. `depositPair` is not installed. Reuse the current non-SUT mintable funding tokens. That is not permission to mock, etch, `vm.mockCall`, or inject storage into this vault or the PoolManager.

Hermetic tests use the default Foundry profile, `viaIR=false`, and the current runtime and initcode limits. `recordLogs` is not a receipt. A snapshot restore asserts pre-state and post-state equality before restore.

Crane tests for the Protocol Aware facet and for `UniswapV4SinglePositionAware` live in Crane. They are part of this directive.

### FS-TEST-02 — Files

- `UniswapV4FullSpreadStandardExchangeVaultPackage.t.sol`
- `UniswapV4FullSpreadStandardExchangeVaultMoney.t.sol`
- `UniswapV4FullSpreadStandardExchangeVaultNative.t.sol`
- `UniswapV4FullSpreadStandardExchangeVaultQuotesAndRate.t.sol`
- `UniswapV4FullSpreadStandardExchangeVaultCallbacks.t.sol`
- `UniswapV4FullSpreadStandardExchangeVaultAlreadyUnlocked.t.sol`
- `UniswapV4FullSpreadStandardExchangeVaultBufferHookIntegration.t.sol`

`UniswapV4FullSpreadStandardExchangeVaultNative.t.sol` asserts the FS-OWN-17 boundary. It does not assert that a caller may send or receive native ETH. `UniswapV4FullSpreadStandardExchangeVaultQuotesAndRate.t.sol` asserts the previews and the absence of `getRate`. It does not assert a vault rate.

Do not apply an inherited PairToken acceptance row that asserts removed economics. In particular, do not apply S1-A10, S1-A13, S1-A15, S1-A19, S1-A46, S1-A62, S1-A64, or S1-A70 as issuance, zap-cap, remainder, or consumption-check rows. Use the FS-A rows below. S1-A40 is not an inherited pass for `exchangeIn`; FS-A19 through FS-A23 cover that path, and FS-A22 still rejects the other unlocked methods.

### FS-TEST-03 — Acceptance rows

| ID | Assertion |
| --- | --- |
| FS-A01 | Package inputs follow FS-FACET-01. ERC-165, ERC-8109, loupe, and the cited temporary-hook facet are absent from cuts and still callable on the factory-built proxy where the factory installs them. The reviewed selector manifest succeeds through the proxy. Family `poolManager()`, family-only `poolKey()`, `rateAsset()`, `getRate()`, `basket()`, `wrappedNative()`, `localReserves()`, and every Standardized Yield selector are absent. The Crane Protocol Aware getters and `UniswapV4SinglePositionAware` getters are callable. Factory selectors stay disjoint. |
| FS-A02 | `bindingHash` changes if any facet, library, or infrastructure binding changes. |
| FS-A03 | Invalid component, uninitialized or hooked pool key, double initialization, wrong `processArgs` caller, and right registry in the wrong account all revert and leave no usable vault. There is no rate-asset argument, no wrapped-native argument, and no zap-limit argument to reject. There is no inherited-domain reject. |
| FS-A04 | Storage slot is not PairToken's and not Wings'. |
| FS-A05 | First deposit creates one full-range salt-zero position owned by the diamond. Added liquidity less than or equal to `1_000` is rejected. Genesis issuance follows FS-MONEY-01 and FS-OWN-24. The floor is `MIN_SHARES` of supply, minted to `address(0)` through `_mint`. The depositor receives gross shares minus fee shares. No performance fee is added. |
| FS-A06 | Paired deposit and redeem follow the mapped bundle routes and FS-MONEY-01. They do not follow S1-ACC-02 or S1-ACC-07. The bundle redeem pays both tokens and does not swap. |
| FS-A07 | Unused declared entry input is refunded to the payer under FS-OWN-32. It is not booked and it is not minted. There is no `IncompleteConversion` revert. `feesAccrued` on a share-minting deposit is booked and is not share credit. The one-token exit is FS-A08. |
| FS-A08 | A one-token exit pays only the selected token, or reverts `AmountOutNotMet` and does not burn shares. It converts the unwanted withdrawn principal plus the caller's opposing fee and booked claim, and it does not pay, book, or keep that residual. A both-token exit pays the claim in both tokens and does not swap. |
| FS-A09 | `previewExchangeOut` returns zero and does not change balances. On an enabled vault, `exchangeOut` reverts `ExchangeOutNotAvailable` with unchanged balances. A disabled `exchangeOut` is FS-A38, not this row. Neither gains a refund return. A zero preview is not a promise that `exchangeOut` succeeds. |
| FS-A10 | Callers send and receive WETH only. Native wrap or unwrap happens only at the pool boundary. The vault does not accept or produce native ETH. |
| FS-A11 | A deposit, a withdrawal, and `exchangeIn` do not call `compound()`. A withdrawal pays the FS-OWN-30 claim and books the rest. It does not pay another holder's booked balance. There is no collection-only fallback. |
| FS-A12 | Withdrawn. `exchangeRate` is not installed. FS-OWN-05. |
| FS-A13 | Withdrawn. `getRate` is not installed. |
| FS-A14 | Withdrawn. `InsufficientRateSupply` is not declared. |
| FS-A15 | Withdrawn. A planner failure is not observed through `getRate`. |
| FS-A16 | Issuance does not read `exchangeRate`. There is no `getRate` to read. |
| FS-A17 | A multi-action locked deposit and a multi-action locked withdrawal perform one unlock and one consumed callback per planned action. Replay after each callback reverts. The guard stays active between actions. The borrowed equivalent performs zero unlocks. |
| FS-A18 | `unlockCallback` from any caller but the bound manager reverts and moves no tokens. |
| FS-A19 | While the manager is unlocked, `exchangeIn` does not call `unlock`. This diamond's touched deltas are zero before return. The global delta count may be nonzero. Position owner, ticks, and salt are unchanged. Liquidity may change. |
| FS-A20 | A borrowed `exchangeIn` that is not self-funded, or that sets `pretransferred`, reverts `InvalidUnlockedContext` or the inherited funding error. A call with value fails at the nonpayable boundary, not as a specified internal `msg.value` check. |
| FS-A21 | An unlocked caller who does not hold the input or the shares does not mint. The unlocked flag is not authority. |
| FS-A22 | `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` revert `ManagerAlreadyUnlocked` while the manager is unlocked. `depositPair` and `redeemPair` are absent. There are no SY mutators. |
| FS-A23 | A reverting borrowed `exchangeIn` restores shares, liquidity, and token balances. |
| FS-A24 | An identity bind of `token == this vault` is attempted. If the current package rejects it without `asset()`, the row records that reject under FS-HOOK-04 and does not pass. Do not add `asset()`. |
| FS-A25 | Buffered configuration mints and burns through `exchangeIn` while unlocked. Recipient may be the hook or the hook's unwrap recipient. Position owner, ticks, and salt hold. Fee handling follows FS-OWN-24 and FS-OWN-30. No performance fee is added. Do not require `token == rateAsset`. The required rate rows use the configured external provider. FS-OWN-29. |
| FS-A26 | The FS-HOOK-02 fixture completes exact-input `zeroForOne` and `oneForZero` on two different backing pool keys. Exact-out is not part of this row. |
| FS-A27 | Each family in FS-HOOK-01 has the proof that its topology can express, or a cited FS-HOOK-04 record that says why it cannot. A cited reject does not replace FS-A26. The FS-OWN-29 rows are not closed by an FS-HOOK-04 incompatibility record. |
| FS-A28 | A hook path that calls `exchangeOut` on this vault reverts and pays neither token. |
| FS-A29 | `getRate` is not installed. The required hook rows use a configured external rate-provider instance for this vault and one rate target, including one row per underlying token and two pools that hold the same vault at different `rateTarget` values. The provider reads the tuple. Do not bind the full-book provider and call it this family's rate. |
| FS-A30 | A same-backing-pool sequential composition is not reported as passed by FS-A26. |
| FS-A31 | Every claimed composed fixture, including both vault operations and hook work, fits 12,000,000 gas. Previews fit 5,000,000. An oversized route is unresolved, not passed. There is no `getRate` read in the measurement. |
| FS-A32 | No economic view reverts by a vault error, including while the manager is busy or unlocked. `reserves()` wraps the deployed-reserve reads, including unpaid fees, and has no local snapshot. `getRate` is not part of this row. |
| FS-A33 | Borrowed execution uses the same settlement as the locked path from the same economic state. It does not call `compound()`. There is no collection-only fallback, no sleeve fallback, and no performance fee. |
| FS-A34 | A nonzero own delta at borrowed entry reverts. Each action closes only this diamond's deltas. Outer debts remain until the outer unlock returns. |
| FS-A35 | Native borrowed settlement syncs native currency immediately before value settle, does not double-count wrapped and native backing, and does not spend another actor's sync credit. Caller-facing amounts stay on the WETH face. |
| FS-A36 | A propagated outer failure restores the swap. A caller that catches a rejected vault call keeps only its own prior effects, sees the vault restored, and still settles its own deltas. |
| FS-A37 | A funded non-hook contract that meets FS-UNLOCK-02 succeeds. The missing allowlist is the specified permissionless funding rule. |
| FS-A38 | A disabled vault reverts `VaultDisabled` on every execution route except a withdrawal, `donate`, and `compound`. A withdrawal is `exchangeIn` with the share as `tokenIn`, or `exchangeBundleOut` with the share as `tokenIn`. A pass-through and a bundle deposit revert `VaultDisabled`. `donate` and `compound` do not. Views do not. A missed deadline reverts `DeadlineExceeded` before the disable check. A buffered withdrawal still succeeds. A buffered non-withdrawal reverts `VaultDisabled` while the manager is unlocked. Run the enabled `exchangeOut` revert on an enabled vault. |
| FS-A39 | The live `feeTo()` owner may appoint a global operator through `setOperator` and a function operator through `setOperatorFor`. A global operator may call `donate` and `compound`. A function operator may call only the granted selector. A stranger reverts. Appointment is not gated by a stored owner. `feeTo()` is not stored as that owner at initialization. The maintenance modifier is not `OperableModifiers.onlyOwnerOrOperator`. |

Compare supply, holder balances, both positions, booked and reserved custody, wrapper balances, and per-address deltas. Do not assert only that no tokens moved.

### FS-TEST-04 — Matrix, integration, and audit absence

Add this vault to the integration testing matrix and to the integration tests. The plan extends these live behavior contracts under `test/foundry/spec/hooks/uniswap/v4/standardExchange/`:

- `single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol`
- `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol`
- `dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol`
- `orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol`
- `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol`
- `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol`
- `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol`

It adds a row for this vault beside those contracts. It does not edit their assertions for other families. Exact-output success rows cannot pass here. On an enabled vault, `exchangeOut` reverts `ExchangeOutNotAvailable()`, and `previewExchangeOut` returns zero. A user's unused input is refunded. A donation or compound remainder is booked, so those rows stay. This replaces the November 1 report sentence that said booked-remainder rows cannot pass. These are adaptations of this family's rows, not permission to weaken the other families.

`docs/audits/apex-2026-09-17-evidence/hook-se-matrix.json` has historical V4 FullSpread compatibility rows. Their cited tests are not current proof of this family. The followup-review snapshots are not the current matrix. Preserve the V3 rows. Replace the stale V4 FullSpread rows rather than treating them as passed. Evidence files named for the plan to update, rather than treat as passed, are `hook-se-matrix.json`, `hook-se-matrix-findings.json`, `hook-se-matrix-finding-descriptions.json`, `docs/audits/apex-2026-09-17-evidence.md`, and `docs/audits/apex-2026-09-17-evidence/acceptance.json` item R10.3.

Test that the vulnerabilities in `docs/security/audit/second_review` are not present in this new vault. A locked sentence that keeps a reported mechanism cannot also be tested as absent unless that finding is accepted or the rule is replaced. The tracker closes APEX-2026-011, 041, 042, and 051 by deleting the old FullSpread code. That deletion does not certify this vault.

The testing inventory is the 45-ID table in `docs/research/se-fullspread-plan-readiness-20261101/REPORT.md`, APEX-2026-010 through APEX-2026-054. Copy each row's yes, no, or integration-only mark. Do not read the audit again to invent a second disposition. Do not add an audit ID. A member-count disagreement in that report is not a second inventory. The table below is that inventory with the six expected results a later lock replaced. A "no" stays no. An "integration only" stays integration only.

| ID | In this plan | Expected result |
| --- | --- | --- |
| 010 | yes | A direct transfer must not become redeemable idle or caller credit. Disabling the retired vaults is not a test of this vault. |
| 011 | yes | Borrowed and own-unlock entry and exit must not over-mint. Deletion of the old family is not evidence. |
| 012 | no | Wings liquidation-quote pricing is absent. Borrowed-path parity is the 011 test. |
| 013 | yes | The generic ERC-4626 `deposit` selector must be absent. A pre-existing balance must not mint shares. |
| 014 | integration only | The rated-versus-face drain is in the hook, not this vault. The weighted, Curve, Balancer, and orbital rows must not treat this share as an unrated raw leg. |
| 015 | integration only | Curve quad join and exit accounting is hook code. The matrix row must not be counted as a vault fix. |
| 016 | no | Weighted partial-book dust seed is hook code. This vault's first deposit is the 034 test. |
| 017 | no | Balancer caller-supplied router callback. Not this vault. |
| 018 | no | Balancer `computeBalance`. Not this vault. |
| 019 | yes, as a negative | This vault has no exact-out route. On an enabled vault, the test is `ExchangeOutNotAvailable`, not a Balancer router regression. Do not use a disabled vault as this fixture. |
| 020 | no | DETF mint and bond pricing. Not this vault. |
| 021 | no | Balancer DETF bond pricing. Not this vault. |
| 022 | yes | Same borrowed-path loop as 011, named against both IDs. |
| 023 | yes | Permissionless sleeve placement is absent. Do not claim the authorized sandwich is gone. The authorized callers are the current `feeTo()` and an operator that owner appointed, either global or function-level for that selector. A stranger still reverts. |
| 024 | yes | A one-token exit swaps the FS-OWN-30 exiting claim only. It does not sell the staying holders' inventory. The unbounded limit stays. The absence test is the quantity, not a price check. Do not copy "withdrawn net." |
| 025 | no | Wings rebalance and loss cap are absent. |
| 026 | no separate Wings test | The 512-step liquidation quote is absent. Dust-tick liveness of this vault's own quote is the 041 test. Do not reopen a spacing rule. |
| 027 | no | Staking withdrawal queues are absent. |
| 028 | yes | A dual identity-leg attempt must not burn the caller's position and pay zero. |
| 029 | yes, as a negative | This vault exposes no `getRate()` and is not bound to the full-book provider. A pumped external provider is not a vault rate. |
| 030 | integration only | Balancer quad phantom fee LP is pool code. The quad row must not be counted as a vault fix. |
| 031 | no | Balancer virtual-TTA join. Not this vault. |
| 032 | yes | Deployment through the shared factory must not leave an unprivileged post-deploy selector. |
| 033 | no | DETF primary redemption. Not this vault. |
| 034 | yes | Direct transfers and the 1,000-share floor must prevent first-deposit inflation. |
| 035 | no | Aave cross-version loop. Not this vault. |
| 036 | yes | Hook integration must not credit a staged pretransfer to a later caller. |
| 037 | no | Re-enabling a named frozen legacy vault. Not this vault. |
| 038 | no | sDETF staking weights. Not this vault. |
| 039 | yes | A pretransfer uses the unbooked balance up to the caller's maximum. It does not take parked shares or the whole sitting balance. A bundle whose declared maximum exceeds that token's unbooked balance reverts before any leg, spends nothing, and mints nothing. Do not add an error for that revert, and do not pin a new selector. |
| 040 | yes | A pool donation followed by `compound` must not round a later deposit to dust shares. |
| 041 | yes | Seed dust ticks and show that a normal deposit and redeem are not frozen by an undocumented step cap. The plan must not add a cap or a minimum spacing. |
| 042 | yes | Deployment must succeed for a token whose `approve` returns no bool. No typed Permit2 approval is required. |
| 043 | integration only | Orbital radius pinning is hook code. The orbital row must not be counted as a vault fix. |
| 044 | yes | Fee shares come out of the new shares. There is no extra mint. The vault clamps the fee at 30%. A round trip does not move existing holders' value to `feeTo`. `previewExchangeIn` and `minAmountOut` use the net shares. The old "fails if FS-OWN-24 stands" sentence is stale. |
| 045 | yes | A disabled vault reverts `VaultDisabled` on every execution route except a withdrawal, `donate`, and `compound`. A withdrawal is share in, underlying out. A pass-through is not a withdrawal and reverts `VaultDisabled`. A bundle deposit reverts `VaultDisabled`. `donate` and `compound` do not. Views do not revert. A missed deadline reverts `DeadlineExceeded` before the disable check. A disabled `exchangeOut` is this revert, not the 019 fixture. FS-OWN-26. |
| 046 | no | Balancer composite-router settlement. Not this vault. |
| 047 | no | Stata one-wei donation freeze. Not this vault. The nearest vault case is 040. |
| 048 | yes | `compound()` with no fees and no booked remainder returns unchanged and emits nothing. A deposit from collected fees or booked tokens emits `Compounded()` with no arguments. That empty argument list is final. A successful `donate()` emits `Donation()` with no arguments. That empty event is final. It is a marker, not an interface. A booked remainder does not freeze a later route. |
| 049 | yes, as a negative | Exact-out is absent. On an enabled vault, the test is the locked revert, not a Camelot equality check. |
| 050 | no | This vault does not read the truncated TWAP oracle. Do not add one. |
| 051 | yes | A preview that returns an amount must not be rejected by an impact check that does not run. The plan names the one quote engine shared by preview and execution. That name is an implementation note, not a new audit ID and not permission to add a step cap. |
| 052 | yes | `permit` must work for a standard signer after initialization. The plan states the EIP-712 domain name and version it initializes. That statement is an implementation note, not a new token. |
| 053 | no | Crane ownership-transfer buffering. This PRD does not change the manager. |
| 054 | yes | Each required hook that unwraps this share must approve the vault and complete the exit. A missing approval must not freeze the user. |

Operator appointment is FS-A39. It is not a new audit ID. Do not treat a "no" row as reopened.

## 9. Non-goals and limits

This PRD does not authorize implementation, deployment, a registry migration, a hook-economics edit, a Weir copy, a wings range, a second pool, a transition-quote facet, a zap cap, a tick guard, a swap price check, a quote step cap, a minimum tick spacing, a fee-origin store, an exit fee, a fee-increase delay, a new 0% override, a vault rate, a `WithRefund` sibling, a refund return on `exchangeOut` or `previewExchangeOut`, or Weir's treasury performance fee.

It does not add a local liquidity sleeve. It does not restore `PkgInit.wrappedNative` or a `wrappedNative()` getter. The WETH address is the `PkgInit.weth` field written through `WETHAwareRepo`. It does not invent paired-event arguments. `Donation()` and `Compounded()` have no arguments. Both empty lists are owner locks, not invented field lists. `Donation()` is a marker event, not an interface.

No audit is claimed. Disjoint-pool hook tests do not prove same-pool sequential safety. Compiler, gas, and fork results are future evidence. The accepted sandwich of an owner or operator `compound()` or `donate()` remains. This PRD does not add a disclosure function for that exposure.

The prior revision `fullspread-se-prd-weir-align-r1` recorded an advisory outcome on a different question. That outcome does not approve this replacement. The owner lock FS-OWN-03 withdraws `getRate`. That lock remains.

## 10. Participation

The table below is the participation record of revision `fullspread-se-prd-weir-align-r1`. It is history. It is not approval of this replacement text, and it is not a vote on the 2026-11-03 locks.

| Member | Requested route | Original task | Advisory |
| --- | --- | --- | --- |
| Astra | `chatgpt-subscription/gpt-6-astra:high` | `st_01a18d05` | REQUEST CHANGES |
| Grok | `xai/grok-4.7:xhigh` | `st_01a18d06` | SUPPORT WITH CORRECTIONS |
| MiniMax | `minimax/MiniMax-M3` | `st_01a18d07` | SUPPORT WITH CORRECTIONS |
| Kimi | `kimi-coding/k3.1-pro:high` | `st_01a18d08` | REQUEST CHANGES |

Coordinator mode for that prior revision was invoking-agent. The coordinator was not a fifth vote. Runtime provider internals were not independently attested beyond the task records in that revision.
