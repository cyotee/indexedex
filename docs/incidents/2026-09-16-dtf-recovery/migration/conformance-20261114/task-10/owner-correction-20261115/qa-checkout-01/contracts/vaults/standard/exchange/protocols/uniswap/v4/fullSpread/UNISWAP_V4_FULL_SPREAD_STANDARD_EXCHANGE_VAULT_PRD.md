# Uniswap V4 full-spread Standard Exchange vault PRD

Revision `fullspread-se-prd-hook-fees-bootstrap-20261106`. Owner amendment to `fullspread-se-prd-hook-accounting-20261106`. The latest owner decisions are FS-OWN-36 and FS-OWN-37: protocol fees come out of newly minted Hook LP, and an initial SE-backed liquidity deposit supplies SE shares and redeems 5% of them to seed local pair-token inventory. FS-OWN-34/35 still govern proportional component ownership and paired-token membership, with own-share processing recognized separately. This PRD is the single source of truth for these requirements. This text is not an implementation, not a safety clearance, and not a member vote.

The later 2026-11-06 hook-accounting amendment, FS-OWN-34/35 and FS-HOOK-05 through FS-HOOK-08, wins over conflicting earlier same-day text, the implementation-and-test plan, blocker recaps, and the failing-test council's prior scope exclusions. Those documents are implementation/evidence context, not competing requirements. The amendment replaces the hook-redesign exclusion and the `asset()` wrapper exception; it does not change FullSpread vault issuance, FS-OWN-30 exit apportionment, or the vault's own no-sleeve rule. The subsequent same-day clarification to FS-OWN-35 distinguishes the vault's implicit own-share processing from the hook's paired-token membership check. No vault must list its own share in `vaultTokens()`. The fixture and package requirements below are self-contained; no other named SE family is a prerequisite. The subsequent same-day FS-OWN-36/37 fee and bootstrap decisions supersede the earlier preservation of growth-based protocol LP minting and rate-dependent genesis. FS-HOOK-09/10 are their operative rules. They resolve the fee-policy and initial-denomination alternatives left open in the implementation-plan draft; those alternatives are not competing requirements. FullSpread vault fees and issuance remain FS-OWN-24/27.

Precedence: a dated 2026-11-06 owner lock in this file wins over a 2026-11-05 owner lock, over a 2026-11-04 owner lock, over the same dated override in `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`, over a 2026-11-03 override, over an earlier sentence in that file, over an undated recap in that file, and over an older sentence here. The 2026-11-05 FS-OWN-33 lock replaces the greatest-liquidity sentence and the "do not require a 48% swap" sentence, including those sentences in that blockers file at F5 and F6. It does not replace FS-OWN-30. The 2026-11-06 lock sets the FS-OWN-33 swap at 49% of the processed input and replaces the open testing ladder. It names the one-token `amountOut` as the recipient receipt in FS-OWN-30. It does not remove the booked-claim apportionment. It withdraws the FS-A16 exchangeRate test. A dated 2026-11-04 owner lock in this file, and the same dated override in that blockers file, wins over a 2026-11-03 override where the 2026-11-05 lock does not replace it. A dated 2026-11-03 override wins over an earlier sentence where a later lock does not replace it. The operative withdrawal rule is FS-OWN-30, not a principal-only recap. `docs/vaults/PRETRANSFER_DIRECTIVE.md` is binding for calls that take `pretransferred`. An earlier owner lock remains where a later lock does not replace it. The accepted return ABI is `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md`, except where a later full-spread lock replaces a sentence in it.

## 1. Goal

Build `UniswapV4FullSpreadStandardExchangeVault` and, as part of the broader failing-test remediation, refactor SE Vault Hooks under FS-OWN-34/35 and section 7.

One registry-deployed Crane diamond owns one Uniswap V4 pool key, one full-range position, and one ERC-20 share supply. The diamond is the position owner. Public shares are claims under the issuance and exit rules in this file. There is no local liquidity sleeve. A staying holder's booked balance is held until `donate()` or `compound()` deploys it. It is not a reserve until then. An exit pays or converts only the exiting holder's claim under FS-OWN-30.

This family adapts the cited money operations of `contracts/protocols/strategy/weir/WeirVaults.sol` only where this file still states them. It has one ERC-20 share, one pool, and one full-range position. It does not copy Weir's manager of many virtual vaults.

This family's economics and package requirements are specified here. Do not inherit another SE family's economics, package fields, or test fixtures by reference.

### 1.1 What this family is not

- Not a source copy of Weir's multi-vault manager, and not a mechanical wrapper around its internal share ledger.
- Not Upper/Lower Wings. No second range and no rebalance facet.
- Not a singleton of many pools, a second share ledger, or a shares-of-shares wrapper.
- Not an ERC-4626 product. Do not install `asset()`. Remove hook calls and probes of that selector for SE leg recognition. SE Vaults need not implement it or map naturally to one underlying token. FS-OWN-35.
- Not an unrestricted hook redesign. The proportional-book, refund, disabled-vault, and membership changes in FS-OWN-34/35 are in scope. Other hook changes remain subject to FS-HOOK-04. The preview-return migration in FS-OWN-08 also remains required.
- Not a local liquidity sleeve. Do not keep a `liquidReservePercentageOfVault` target, and do not restore `localReserves()`.

### 1.2 Deltas

| ID | Delta |
| --- | --- |
| FS-X01 | Canonical exact-input `exchangeIn` executes while the bound PoolManager is already unlocked, without a nested `unlock`. Ordinary user entry still opens its own unlock, once per planned manager action. Inclusion in a batch swap with other Uniswap V4 pools is not a revert. |
| FS-X02 | Withdrawn by FS-OWN-03. Do not install `getRate`. There is no designated `rateAsset`. An external rate-provider instance is FS-OWN-29. This vault does not know it. |
| FS-X03 | Tests place this share with another SE vault share in the buffer-hook families, using FS-HOOK-02 and membership-only validation under FS-OWN-35. The hook refactor in FS-OWN-34/35 is in scope. Consumers that still require a 32-byte `previewExchangeIn` success are migrated by FS-OWN-08. |
| FS-X04 | Single-token entry does not require the selected swap to consume its entire input. There is no `IncompleteConversion` check. Unused declared input is refunded to the payer under FS-OWN-32. It is not booked and it is not minted into shares. The one-sided swap shape is FS-OWN-33. The one-token exit is FS-OWN-30. |
| FS-OWN-01 | `poolManager()` is not a family query. The Uniswap V4 Protocol Aware facet is a Crane package input. Its getters are externally callable on this vault. |
| FS-OWN-02 | Pool key, ticks, and salt live in Crane `UniswapV4SinglePositionAware`, not in a full-spread-only getter. |
| FS-OWN-03 | Do not implement `rateAsset()` or `getRate()`. This family designates no single token for valuation or operations. |
| FS-OWN-04 | There is no local liquidity sleeve. Do not keep a target from `liquidReservePercentageOfVault`. Do not move a local balance toward a target after a deposit, a withdrawal, or `compound()`. Do not restore `localReserves()`. |
| FS-OWN-05 | Do not install ERC-5115. Drop `syMoneyFacet` and `syQueryFacet`. |
| FS-OWN-06 | `UniswapV4SinglePositionAware` stores `tickLower`, `tickUpper`, and the salt. `positionLiquidity()` wraps `StateLibrary.getPositionInfo`. |
| FS-OWN-07 | Do not implement `basket()`. `reserves()` and `reserveOfToken` wrap the deployed-reserve reads. There is no local term and no last-committed snapshot. A booked remainder is not in that read. Unpaid fees are. |
| FS-OWN-08 | `previewExchangeIn` and `exchangeIn` keep their parameters and selectors and return `(amountOut, amountRefunded)`. No `WithRefund` sibling. `exchangeOut` and `previewExchangeOut` do not gain a refund return. |
| FS-OWN-09 | Do not keep `depositPair`, `previewDepositPair`, `redeemPair`, or `previewRedeemPair`. Map them to the accepted bundle routes. Keep `donate` and `compound`. `donate` is an explicit exception and is not a Weir function. `compound` is owner-or-operator harvest-and-reinvest under the booking rule, not a ratio swap. |
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

**FS-OWN-09.** Do not install `depositPair`, `previewDepositPair`, `redeemPair`, or `previewRedeemPair`. Map deposit to `exchangeBundleInForSingleOut` and `previewExchangeBundleInForSingleOut`, with `tokenOut` as the share. Map redeem to `exchangeBundleOut` and `previewExchangeBundleOut`, with `tokenIn` as the share and `tokensOut` as the two ERC-20 faces. Keep `donate` and `compound`. `donate` is an explicit exception. `compound()` stays this selector. Its behavior is FS-OWN-14, not a ratio swap or quarter-cap, and not Weir's treasury performance fee.

The mapped redeem is the both-token exit. It pays the caller's claim in both tokens and does not swap. It does not sell one leg to pay the other. The one-token exit is canonical `exchangeIn`, with the share as `tokenIn` and one underlying as `tokenOut`. It is not `exchangeBundleOut` with one output. The amounts are the FS-OWN-30 exiting claim: unwanted withdrawn principal, plus the caller's opposing-token fee and opposing booked claim. The one-token payment goes to `recipient`. A bundle argument combination that is not one of those two mappings is unsupported. It reverts the already-named `ExchangeBundleInForSingleOutNotAvailable` or `ExchangeBundleOutNotAvailable` for that function. Do not add a success path.

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

**FS-OWN-15.** A one-token redemption withdraws the exiting holder's portion of the deployed reserve, calculates that holder's portion of the accrued fees, and swaps all of the opposing token that holder owns. The payment to `recipient` is the FS-OWN-30 receipt. The swap converts all of that opposing token or reverts `AmountOutNotMet` and does not burn shares. The purpose of that swap is pool volume. It is a quantity rule, not a new cap. It does not swap the other holders' booked fees, and it does not sell the staying holders' inventory. A both-token exit does not swap. There is no sleeve to take first. The swap limit is FS-MONEY-01.

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

**FS-OWN-26.** A disabled vault reverts `IVaultRegistryDisableQuery.VaultDisabled(address(this))` on every execution route except a withdrawal, `donate`, and `compound`. The predicate follows the live V2 call site in `UniswapV2StandardExchangeInTarget`: a route whose input is not this vault's share is blocked. That predicate is widened from `exchangeIn` to every execution route. A withdrawal is share in and underlying out. That is canonical `exchangeIn` with the share as `tokenIn`, and `exchangeBundleOut` with the share as `tokenIn` and the two ERC-20 faces as `tokensOut`. A pass-through `exchangeIn` is not a withdrawal and reverts `VaultDisabled`. A bundle deposit reverts `VaultDisabled`. `donate` and `compound` are not in this block. They may run while the vault is disabled, under FS-OWN-14. Views do not revert `VaultDisabled`. FS-OWN-19. A missed deadline still reverts `DeadlineExceeded` before this check. FS-OWN-28. On an enabled vault, `exchangeOut` still reverts `ExchangeOutNotAvailable()`. A disabled `exchangeOut` is not a withdrawal, so it reverts `VaultDisabled`. The same predicate applies on a borrowed unlock. A buffered withdrawal still succeeds without a cleanup deposit into the disabled vault. A non-withdrawal call into that vault still reverts `VaultDisabled`; a hook operation that retains input locally or spends its local book without making that call is governed by FS-HOOK-06/07, not by a blanket hook-level disable revert. FS-A38.

**FS-OWN-27.** The deployed reserve is accounted as one value, `liquidity`. It is raw V4 liquidity. Share minting and burning use that number. Token amounts stay in their own decimals when they go into `getLiquidityForAmounts`. No amount scaled to a token's decimals, and no use of `decimals()`, enters the share formula. `decimals()` returns 18. That is metadata. It is not a scale, and it is not an input to the mint or burn. Do not multiply the stored share balance, or the floor, by a constant to match `decimals()`. A wallet that divides the balance by `1e18` is formatting the liquidity number. It is not reading a rescaled share.

**FS-OWN-28.** A missed deadline reverts `IStandardExchangeErrors.DeadlineExceeded(deadline, block.timestamp)` before any other work on a route that takes `deadline`, including the FS-OWN-26 disable check. This lock does not add a deadline argument to `donate` or `compound`.

**FS-OWN-29.** This vault does not implement `getRate()`. FS-OWN-03 stays closed. Rate-provider instances are deployed by `IStandardExchangeRateProviderDFPkg` for a configured Standard Exchange vault and rate-target pair. `PkgArgs` carries `reserveVault`, `rateSubject`, and `rateTarget`. One vault can have as many of those instances as it has `vaultTokens()`. That count is the maximum useful number, not an enforced limit. Do not add a cap. This vault stores no rate-provider address and exposes no rate-provider getter. The hook configures a rate-provider address for each Standard Exchange liquidity leg. The required hook rows use that configured instance. They do not derive a provider from this vault, and they are not recorded incompatible.

The rate subject is this vault, used as liquidity in the test pool. There is a scenario for each underlying token, so the rows test that this vault can be rated and that the integrated token can be token0 or token1. Separate pools may hold the same vault, each with a rate provider whose `rateTarget` is a different underlying token. That tests two pools valuing the same vault at different targets. The rate provider, and every other consumer of the old 32-byte preview return, must read the tuple in FS-OWN-08. This lock does not add a vault rate.

**FS-OWN-30.** On a share-minting deposit, `modifyLiquidity` returns `feesAccrued`. Book `feesAccrued`. Do not include those fees in the deposit, the caller's share credit, or a swap. Swapping them into the deposit is forbidden. A mint preview does not credit the new depositor with existing fees.

On a withdrawal, `feesAccrued` is the unpaid fee-owed read already named for `reserves()`. Tokens booked from an earlier `modifyLiquidity` return are only in the booked-balance term. They are not counted again. On a withdrawal, measure before the burn. `totalSupply()` before the burn is the total shares, including the floor. The caller's fee claim is `floor(feesAccrued * sharesBurned / supplyBeforeBurn)` for each token. The caller's booked claim is `floor(bookedBalance * sharesBurned / supplyBeforeBurn)` for each booked balance. Do not divide the share fraction before multiplying by the balance. Include that portion in the exit. Book the rest for the other holders. Principal removal is `liquidity * sharesBurned / supplyBeforeBurn`, rounded down by that same integer division.

A one-token exit withdraws the exiting holder's portion of the deployed reserve and calculates that holder's portion of the Uniswap V4 accrued fees. It swaps all of the opposing token owned by that holder into the requested token, or it reverts `AmountOutNotMet` and does not burn shares. It does not pay, book, or keep that opposing residual. It sends to `recipient` the swap proceeds, the withdrawn requested-token principal, and that holder's portion of the accrued fees in the requested token. The holder's booked claim stays in that exit: the opposing booked claim is part of the opposing token swapped, and the requested booked claim is paid to `recipient` with the requested-token fees. The returned `amountOut` is that payment: swap proceeds, withdrawn requested-token principal, requested-token fee portion, and requested booked claim. `minAmountOut` binds that receipt. It is not the swap proceeds alone, and it is not a stale preview. The other holders' shares of fees and booked balances are booked, not swapped. The exit does not sell the staying holders' inventory. The price limit is the unbounded entry limit. There is no new price check.

A both-token exit pays that same claim in both tokens and does not swap. It books the rest for the other holders.

An exit preview uses the same apportioning as the execution it quotes. A one-token exit preview quotes the same recipient receipt, so the quoted `amountOut` matches execution. A both-token exit preview does not swap, and its quoted outputs match that execution. That exit quote is the share valuation, and it includes accrued fees. It is not `getRate()`. A mint preview is not that valuation.

The old no-leftover-shortfall-revert sentence is scoped to the former sleeve. It is not an exit rule. A caller-set one-token minimum still reverts `AmountOutNotMet`. A caller-set bundle minimum reverts `MinAmountNotMetAt(uint256 index, uint256 minAmount, uint256 actualAmount)`. There is no sleeve top-up. Do not declare `MinAmountNotMet`.

**FS-OWN-31.** The unpullable borrowed exit does not occur. On a borrowed unlock the vault does not call `unlock()`. It calls `modifyLiquidity` and `swap` directly, pulls the caller's deployed fraction, swaps only the FS-OWN-30 exiting claim, not principal alone, and settles its own deltas before it returns. There is no sleeve payment and no `UnderlyingUnavailable` for an unpullable fraction. `required` and `available` have no case to measure. That sentence closes only the unpullable-fraction case. It does not remove `AmountOutNotMet`, a funding failure, or `SettlementMismatch`. The call is not a sleeve case if this vault's own code calls `unlock()` again, or if the hook never calls the vault.

**FS-OWN-32.** Input that does not become liquidity is not minted into shares and is not left for the other shareholders.

On the pull path, `pretransferred == false`, pull the declared amount from `msg.sender`, then refund the unkept amount of that same token to `msg.sender`. Pulling only the consumed amount is not the rule. Declared amount equals amount consumed plus amount refunded. Output goes to `recipient`. A zero refund transfers nothing. Refunded wei are not credited as a deposit.

On the pretransfer path, the vault does not ask where the tokens came from. It uses the unbooked held balance, up to the caller's maximum. If that maximum is within the unbooked balance, the refund is the maximum minus the amount used, in the token the caller provided. Do not refund the whole remaining unbooked balance in that case. That balance may be staged for another call. The vault has no instruction to process it. If the maximum is larger than the unbooked balance on a one-token call, refund that unbooked balance. Do not spend that unbooked balance. Do not pull the shortfall. Do not refund maximum minus used. A larger maximum is not a revert on that one-token call. The caller may declare any maximum. That unbooked balance is not minted into shares. A bundle is atomic. If any declared maximum exceeds that token's unbooked balance, the call reverts before any leg is processed. No declared amount is spent. No shares are minted. Do not add a new error for that revert. A non-atomic pretransfer is the caller's risk. An address without bytecode cannot pretransfer. The accepted report names that existing revert `EOAPretransferNotAllowed()` in current comments and does not redeclare it. This PRD does not declare a second error for the same rule.

A donation or compound remainder is booked, not refunded. That booking is not this refund rule. A share-minting deposit's `feesAccrued` is booked, not refunded.

These rejects are execution rejects. A view does not revert them. An unsupported view route returns zero. `recipient` may be the hook's recipient, including a user on unwrap. `recipient == msg.sender` is not a hard rule. A recipient of `address(0)` reverts `InvalidRecipient()`. The vault as recipient also reverts `InvalidRecipient()`. `tokenIn == tokenOut` reverts `InvalidRoute`. `amountIn == 0` reverts `EmptyExchange`. A token of `address(0)` reverts `TokenNotExchangeable`. That is not the zero-recipient reject. These functions are not payable. The caller passes the wrapped ERC-20 face. After WETH substitution, a reserve query uses that ERC-20 address. This PRD does not add a new pool exclusion for a collapsed face.

A preview of a refund does not transfer and does not read a balance. It assumes the declaration is available. Execution may refund a different amount. Bit-exact equality of the refund word is not required. The exit quote's output match is FS-OWN-30, and it is not waived by that refund sentence. `minAmountOut` and `minAmountsOut` bind.

**FS-OWN-33.** Locked 2026-11-06. A one-sided share mint runs one balancing swap. A bundle deposit does not. For a one-sided deposit, and for a one-token `donate` or `compound`, swap 49% of the processed input, then deposit, when the price is strictly inside the position. That fixed fraction is the adaptation of the Weir process. Do not iterate. Do not solve a closed-form root. Do not walk ticks to find a better split. If the price is not strictly inside the position, including exactly at either boundary, do not swap. The position wants only one token. If the caller provided that token, add it with no swap. A share mint refunds what the add does not take. A donate or compound books that dust and does not refund it. If the caller provided the other token, do not swap it. A share mint refunds it. A donate or compound books it. No new error. Zero active liquidity is not that boundary case. If the 49% swap cannot be formed, or the following add cannot consume its output, return the input and keep no swap. A share mint refunds that input and mints nothing. A donate or compound books that input and does not refund it. The swap output is consumed by the add. Rounding leaves any remainder in the input token. A user-deposit remainder is refunded under FS-OWN-32. A donate or compound remainder is booked. The price limit is `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`. That is not `maxZapTickMove`, and no tighter cap is added. This is not an exit rule. The one-token exit is FS-OWN-30.

**FS-OWN-34.** Locked 2026-11-06, later hook-accounting decision. Refactor all SE Vault Hooks to keep, for each leg, a book of local `pairToken` separately from the book of SE Vault shares. This includes every family in FS-HOOK-01 and their shared execution, preview, liquidity, and settlement paths. The refactor is part of the broader failing-test remediation, not an out-of-scope hook-economics change. A hook books pool-owned SE refunds and amounts it cannot redeposit because the SE Vault is disabled. For swap calculations only, include the booked local amount alongside the rated SE shares in pair-token units; pay swap output from the local book first and redeem SE shares only for the deficit. Hook LP ownership is not a claim on that rated sum. Mint and burn Hook LP against proportional quantities of the actual SE shares and local pair tokens across all legs under FS-HOOK-07/08. Do not use the rate provider, a spot valuation, NAV, or a change in rated reserve to determine LP entitlement. Conversion to assemble a join or settle an exit uses only that caller's assets and actual results. No existing holder's assets fund another caller's contribution, fees, losses, or shortfall.

This is hook accounting. FullSpread vault issuance remains proportional to its raw deployed liquidity under FS-OWN-24/27, and its booked-claim withdrawal remains FS-OWN-30. Its own unused user input remains refunded under FS-OWN-32. That refund can become the receiving hook's booked property only under the ownership rules in FS-HOOK-05/07. Do not restore a vault sleeve, a target percentage, or a vault `getRate()` under this amendment.

**FS-OWN-35.** Locked 2026-11-06, with the later same-day own-share clarification. Remove `asset()` calls, static probes, and wrapper-share exceptions from SE Vault Hook validation and classification. SE Vaults need not implement ERC-4626 or map naturally to one underlying token. The standard recognizes an SE Vault's own ERC-20 share implicitly: that vault can mint and redeem its share through its supported routes without declaring itself in `vaultTokens()`. Do not require the vault/share address to occur in that list, reject a vault because its own address is absent, or classify its own-share processing as an unsupported identity bind.

The separate hook binding is `(standardExchange, pairToken)`. Validate that the configured `pairToken` occurs in that SE Vault's `vaultTokens()`. Reject that binding when the configured paired token is not a member; a missing or reverting list is not a membership hit. The membership test is on the paired token, not on the separately held SE-share inventory or the share-side input/output of a supported vault operation. In particular, do not populate the `pairToken` field with the vault's share address merely to describe its own-share processing. Own-share recognition does not waive the membership check on the configured paired token.

Keep other independent package, route, funding, and execution checks. Do not substitute an `asset()` answer, a provider result, or an inferred single-underlying relationship for paired-token membership. This clarification does not add a same-token `exchangeIn` route: the existing `tokenIn == tokenOut` rejection remains. Raw transfer legs remain raw; they are not SE-share conversion proofs. These rules apply to every SE Vault Hook and its previews and execution paths.

**FS-OWN-36.** Locked 2026-11-06, later Hook LP mint-fee decision. Replace growth-based protocol LP issuance with a configured percentage taken from the gross LP tokens backed by a new depositor's accepted liquidity contribution. Mint the fee portion to the existing fee recipient and the remainder to the depositor; do not mint the fee on top. This is a liquidity deposit/mint fee, not a fee on withdrawals, rate changes, unrealized SE yield, or measured invariant growth. Ordinary swap trading fees remain in the pool; the protocol's LP participates in them like any other LP holding. Do not additionally retain the former growth-fee mint or introduce separate protocol swap-fee token accumulation, basket conversion, or deferred fee crystallization. Apply the same split through every LP-bearing hook's deposit aliases and previews under FS-HOOK-09. The conversion-only single hook has no Hook LP supply and does not acquire one under this lock.

**FS-OWN-37.** Locked 2026-11-06, later initial-liquidity decision. For the first liquidity deposit into an LP-bearing hook, accept only SE Vault shares as the incoming asset for each funded SE-backed leg. Redeem 5% of the actual supplied shares into that leg's paired token and book the actual redemption proceeds locally; retain the other shares as the SE-share component. This is an actual redemption, not a price sample, not 5% of rated value, and not a continuing local-reserve target. Raw legs still accept their raw token. Preserve each family's supported seed topology, rate-free seed-function shape and locked minimum-liquidity floor; calculate its SE-leg seed coordinate from the retained shares after redemption, not their rated value. Book the complete resulting basket as backing for that initial LP supply, excluding the locked floor from the FS-OWN-36 fee base. Later joins and exits use the existing component proportions, not another automatic 5% redemption. FS-HOOK-10 specifies rounding, actual receipts, minima, and atomic failure. This is not a change to the FullSpread vault's own genesis or 49% one-sided entry rule.

## 2. Authority and precedence

| Source | Role |
| --- | --- |
| This PRD, including FS-OWN-34 through FS-OWN-37 | Single source of truth for the expanded hook remediation. Its latest 2026-11-06 component-accounting, membership, LP mint-fee, and share-funded bootstrap decisions replace conflicting earlier scope and economics in plans, blockers, and council reports. |
| `IMPLEMENTATION_PLAN_BLOCKERS.md`, including the 2026-11-03 overrides | Historical owner-decision context. Its dated locks apply only where not replaced by a later lock in this PRD. |
| `docs/vaults/PRETRANSFER_DIRECTIVE.md` | Binding pretransfer rule. Wins over an older pretransfer sentence, including the accepted ABI report's short-declaration revert. |
| `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md` | Accepted return ABI and bundle interfaces. The owner lock in that report wins over its earlier council text. A later full-spread lock still wins over a sentence there. |
| `docs/research/se-fullspread-preview-consumers-20261103/REPORT.md` and `INDEX.md` | Consumer enumeration for the 64-byte preview return. F13 is accepted. F14's principal-only withdrawal sentence is not. |
| `contracts/protocols/strategy/weir/WeirVaults.sol` | Source of the deposit, withdrawal, issuance, and compound rules this PRD still states. Its multi-vault manager, administration surface, treasury performance fee, sleeve, auto-compound, and native caller payout are not inherited. |
| FS-FACET-01 and FS-PKG-01 | This family's self-contained package inputs. No package field or economic rule from another vault family is inherited. |
| `contracts/hooks/uniswap/v4/standardExchange/` | Current implementation context, not authority over the new requirements. Refactor under FS-OWN-34 through FS-OWN-37 and FS-HOOK-05 through FS-HOOK-10. Migrate a 32-byte preview gate under FS-OWN-08. |
| `CLAUDE.md`, `docs/agent/INDEXEDEX_AGENT_LAW.md`, `.github/ASSISTANT_CODING.md`, `.github/ASSISTANT_TESTS.md` | Registry, token, compiler, and test law. |
| Crane architecture, IndexedEx testing, and Uniswap V4 hook-package skills | Packaging and production-first tests. |

Issuance, entry settlement, compound, and idle follow FS-MONEY-01 and the owner locks in this PRD. Do not inherit a different issuance formula, dead-share rule, zap cap, ratio swap, quarter-cap, collection-only fallback, or package dependency from an earlier specification.

These constraints stay:

- FS-X01 permits the already-unlocked path only for canonical `exchangeIn`. `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` still revert `ManagerAlreadyUnlocked`. `depositPair` and `redeemPair` are not installed. There are no SY mutators.
- FS-OWN-05 removes every Standardized Yield selector. Do not replace `exchangeRate` with another denomination.
- FS-OWN-03 withdraws `getRate`. Do not install `IERC4626`, a transition quote, an external-state quote, or `IStandardExchangeRateQuote`. The external provider in FS-OWN-29 is not this vault's rate.
- Compiler and registry law stay. Hook bindings now follow FS-OWN-35, and hook liquidity/refund accounting follows FS-OWN-34. The FS-OWN-08 return migration is required.

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
| Own-share processing and paired-token binding | An SE Vault implicitly processes its own shares without listing itself in `vaultTokens()`. Separately, the configured hook `pairToken` must occur in that list. FS-OWN-35. | Requiring the vault's own address in its list, probing `asset()`, or using share recognition to waive paired-token membership. |
| Hook LP ownership | Proportional actual SE-share and local pair-token quantities, FS-OWN-34 and FS-HOOK-07/08. Rated reserves remain swap inputs only. | Rate-valued LP issuance or exits; paying a whole LP exit local-first from the other holders' cash. |
| Sleeve | Absent. FS-OWN-04. | A local target, a 5% band, or `localReserves()`. |
| Quote method | The mathematical result of the operation. Section 6. | A 64-step cap, a minimum tick spacing, a partial fill, or `QuoteWorkLimit`. |

## 3. Facets

### FS-FACET-01 — Package inputs

`PkgInit` uses this family's facet order. FS-OWN-05 removes `syMoneyFacet` and `syQueryFacet`. It is not an open `IFacet[]`. Do not substitute a different vault family's facet implementations into this package. Family facets are this family's implementations. `vaultTokens` is `MultiAssetBasicVaultFacet`. `reserveOfToken` and `reserves` are the family custom facet. Those are two facet addresses. `basicVaultFacet` is not one facet that exposes all three. Package validation must not require `getRate`. FS-OWN-03 forbids installing it.

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

The old 61-selector count included `getRate` and is not the manifest. Recount from the current package when it is built. `linkedComponents()` is facet metadata, not an installed proxy selector. Cite the current package `_expectedSelectors` and the factory-owned exclusions in FS-FACET-02 when implementing. Do not invent selector hex in this PRD beyond the accepted selectors already named in FS-OWN-08 and FS-OWN-09.

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
- The factory-owned temporary-hook facet. Exclude it from this package's inputs and cuts. This PRD does not invent its filename. Name it only after citing the factory file.

The finished proxy still exposes those factory-installed surfaces. Exclusion from `PkgInit` is not removal from the diamond.

## 4. Files and package

### FS-ARCH-01 — Files

Create the family under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`. Do not host it in another vault family.

Production files use this family's explicit split:

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

Storage uses a new namespaced slot, `keccak256(abi.encode(namespace)) - 1`. It must not collide with any other vault family's storage slot.

The Protocol Aware pair is created under `lib/crane/contracts/protocols/dexes/uniswap/v4/aware`. `UniswapV4SinglePositionAware` is a Crane repo and facet. This text does not assign it a directory beyond that Crane home. Do not put either pair inside the full-spread family directory. Both are part of this directive, including their Crane tests. This text does not write that code.

The new owner and operable modifiers are part of this directive. Their file names are not given. Do not reuse the existing owner facets for the live `feeTo()` check. Operator authorizations stay in `OperableRepo`.

### FS-PKG-01 — `PkgInit` and `PkgArgs`

`PkgInit`, in binding order: the facet fields above, including the two Crane facet inputs, then `poolManager`, `registry`, `oracle`, `diamondFactory`, and `linkedLibraries` as `address[6]` for Math, Projection, SwapProjection, Planner, Execution, and ExecutionPreparation. `weth` is a `PkgInit` field. `wrappedNative` is not a field. Initialization writes `weth` with `WETHAwareRepo._setWeth`. The two Standardized Yield facet fields are absent. The `poolManager` field is an address binding, not permission to install a family `poolManager()` selector. The other six architecture addresses are package immutables of the same deployment. They are infrastructure bindings and are covered by `bindingHash`, the same as `poolManager`. This text does not invent their struct field names. FS-OWN-01.

`PkgArgs` is this family's set. No hook allowlist:

- `PoolKey poolKey`, stored through `UniswapV4SinglePositionAware`, not as proof that `poolKey()` is a family-only selector. Locked 2026-11-05. `name` and `symbol` are not fields. The salt is this pool key. Initialization generates the name from the two faces and the fee, and hardcodes the symbol `UV4X`. That symbol is 4 characters, inside the 11-character symbol limit. A second deploy of the same pool key returns the existing vault.

`maxZapBps` and `maxZapTickMove` are not fields. No replacement cap or tick bound is added. `rateAsset` is not a field.

`bindingHash` covers every `PkgInit` field. `calcSalt` and `processArgs` run by delegatecall and use immutable bindings and self calls.

`deployVault(PkgArgs) returns (address)` goes through the bound IndexedEx vault registry. No second factory. The PoolManager is not CREATE3'd by this package. Tests deploy it through the current artifact-backed CREATE3 helper, as FS-TEST-01 says.

`processArgs` reverts `NotCalledByRegistry` unless `msg.sender` is the bound registry and `address(this)` is the bound `diamondFactory`. Both conjuncts are required.

The package still lists `SwapProjection` and `ExecutionPreparation`. No other family's economics are inherited. The slots stay. The engineer assigns already specified operations to them. This PRD does not design those libraries.

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
- `compound()` is FS-OWN-14. It is not permissionless. Leftover after the simplest deposit is booked. It is not a sleeve. The source's `perfFeeBps` cut to `treasury` is not added. No additional fee is authorized by that source.
- A withdrawal removes `liquidity * sharesBurned / supplyBeforeBurn` and pays the caller's FS-OWN-30 claim to `recipient`. It does not pay another holder's booked balance or an unbooked balance. This family does not install `zapTo`. A one-token exit pays only the selected token or reverts `AmountOutNotMet` without burning. A both-token exit pays the claim in both tokens and does not swap.
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

### FS-UNLOCK-02 — Already-unlocked execution (borrowed unlock)

"Borrowed unlock" means that a router or other outer caller already opened the bound PoolManager's unlock, and the vault executes within that existing context. It is not a loan, borrowing a token, or borrowing another vault's funds. The vault does not call `unlock()` again. It spends only authorized caller inputs or shares, settles its own per-address deltas, and leaves the outer caller responsible for completing the outer operation.

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
| Issuance | FS-MONEY-01 and FS-OWN-24. `previewZapCredit` is absent. A mint preview does not credit existing fees to the new depositor. | An inherited issuance formula. `J_i` booking. A replacement zap-credit view. |
| SY `exchangeRate()` | Not installed. FS-OWN-05. | A replacement denomination. NAV. |
| Exit preview | The same apportioning as execution, including accrued fees. That quote is the share valuation. A one-token quote is the FS-OWN-30 recipient receipt, so `amountOut` matches execution. A both-token quote does not swap. | `getRate()`. Whole-book value divided by supply. A sleeve-maintenance term. |
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
2. Use supported SE Vault instances with disjoint backing pool keys. Each SE-backed hook leg binds a `pairToken` contained in that vault's `vaultTokens()` and accounts for that vault's shares as separate reserve inventory. The vault implicitly processes its own shares under FS-OWN-35; its share address need not and must not be added to its token list to make the test work. The fixture may use two independently deployed instances of this FullSpread family. It has no dependency on a different named SE contract.
3. The two backing pool keys differ. One direction mints FullSpread shares while the manager is unlocked. The reverse burns them. Assert balances, position owner, ticks, salt, and per-address deltas.
4. A transfer-only share trade is a separate control. It does not prove underlying entry or exit. A valid paired-token binding plus minting or redeeming the vault's own share is not that transfer-only case.
5. Any vault actually called while the PoolManager is already unlocked must execute the already-unlocked path described in FS-UNLOCK-02 without opening another unlock. Do not inherit an unsupported-context restriction from an out-of-scope vault contract or leave the canonical proof dependent on that contract.

Two buffered legs that share one pair token and overwrite `standardExchangeOf[pair]` are not a required fixture. If the package cannot represent that bind, record it. Do not edit the hook to create it.

Same-backing-pool sequential composition is unverified, not impossible, and not passed by the disjoint-pool fixture.

### FS-HOOK-03 — Exact output

`exchangeOut` reverts `ExchangeOutNotAvailable()`. `previewExchangeOut` returns zero and does not gain a refund return. A hook path that calls `exchangeOut` against this vault fails closed. A transfer-only route that never calls `exchangeOut` is not forbidden by that sentence. Exact-input both directions means `zeroForOne` and `oneForZero`. Exact-out is not one of those directions.

### FS-HOOK-04 — Integration records and remaining hook-change gate

If a required route cannot run:

1. A full-spread money, preview, or context defect is fixed in this family.
2. An intentional exact-output or budget rejection stays a rejection.
3. Hook local-book, proportional-liquidity, refund, disabled-vault, and membership changes are required by FS-OWN-34/35, not deferred by this gate. Remove an `asset()` dependency rather than adding that interface to an SE Vault. An invalid membership bind remains invalid after removal; do not treat its rejection as permission to bypass FS-OWN-35.
4. A missing quote interface, a `SameToken` or pair-overlap reject, or an incompatible denomination other than the FS-OWN-29 rows remains a separate requirement unless this amendment explicitly addresses it. Name the consumer, selector, arguments, and revert. Do not invent that change here, and do not stub a transition quote.

A cited reject is an unresolved integration record. It does not close the canonical FS-HOOK-02 proof. It may close a family row only when that family's topology cannot express the canonical fixture, and the record says so. The FS-OWN-29 rows are not that record.

### FS-HOOK-05 — Separate books and ownership

For each SE-backed leg `i`, `S_i` is the hook-owned booked quantity of SE shares and `L_i` is the hook-owned booked quantity of local `pairToken`. These are separate asset quantities, not a summed LP valuation. Raw legs have only their booked token quantity. Do not count one physical holding twice, including an address that appears in multiple roles. Pending caller inputs, amounts owed back to callers, unbooked transfers, and another leg's holdings are not available book credit.

When a hook-owned deposit into an SE Vault returns shares and refunds input, credit the shares to `S_i` and the actual retained refund to `L_i`. Count the refund once, not both as spent input and as local backing. A disabled SE causes pool-owned input or residual that cannot be redeposited to remain booked locally; it is not gifted to the next caller and does not force a cleanup deposit. Accounting follows actual received, spent, and returned quantities and the return tuple in FS-OWN-08. A failed operation rolls back transfers, bookings, share changes, and settlement.

Hook LP joins are different from reinvesting hook-owned inventory: incoming assets and SE refunds stay attributed to that incoming caller until the proportional basket in FS-HOOK-07 is accepted. Book only the accepted portion. Return unaccepted assets to that caller. An SE refund to the hook is not automatically an additional refund to the user, nor automatically existing LP property before the join is settled.

### FS-HOOK-06 — Swap reserves and disabled-vault execution

For swap pricing, each SE-backed leg contributes `L_i + ratedPairTokenUnits(S_i)` using the configured provider and correct token-unit normalization. This rated sum is a swap reserve, never the Hook LP mint/burn denominator or entitlement. Preserve the hook family's swap curve and applicable fees; include the local book consistently in swap execution, previews, reserve updates, and related fee accounting.

For token output, debit and use the booked local pair-token balance first. If it covers the output, do not withdraw from the SE Vault. Otherwise redeem only to cover the deficit using actual execution and the route's existing rounding and minima; book any hook-owned remainder without claiming the rated amount is guaranteed redemption proceeds.

When the bound SE is disabled, do not make a prohibited deposit or pass-through call to buffer incoming tokens or residuals. Keep hook-owned amounts local. Permitted SE withdrawals may still cover output deficits. Thus a hook swap can proceed using local input booking, local output, and permitted redemption even though directly calling a disabled SE's non-withdrawal route would revert. Do not weaken the SE disable predicate, swallow arbitrary execution failures, or claim success where balances, minima, or settlement cannot be satisfied. Re-enabling the SE does not retroactively give a new depositor ownership of the existing local book.

This swap use of a rated reserve is not a claim that price manipulation in swaps or the underlying conversion is solved. The new LP ownership rules specifically remove rate-valued issuance and exits.

### FS-HOOK-07 — Proportional Hook LP deposits

For an existing Hook LP supply `T > 0`, snapshot every booked component and the actual supply before crediting incoming assets or minting any of this join's LP. Do not first mint protocol LP from prior rate/invariant growth; FS-OWN-36 replaces that mechanism. The incoming caller's assets must not enter the incumbent snapshot. Use one common fraction across every leg, not an independently selected fraction for each leg.

For `m` gross new Hook LP tokens before the FS-HOOK-09 fee split, the accepted contribution on every SE-backed leg is:

```text
requiredSeShares_i = ceil(m * S_i / T)
requiredLocalPair_i = ceil(m * L_i / T)
```

For a raw leg, require `ceil(m * bookedRaw_i / T)`. Multiply before division with overflow-safe arithmetic. A zero component requires zero contribution; do not divide by that component or use it to value another component. The depositor and fee recipient split the total backed mint `m` under FS-HOOK-09. Size the contribution for `m`, not just for the depositor's smaller net receipt; fee LP is not an additional mint on top.

LP entitlement depends on these actual quantities only. Do not use `getRate`, spot price, NAV, or the change in a rated reserve to determine `m`. A rate movement without a change in component quantities cannot enlarge the incoming caller's LP entitlement. At acceptance, existing holders' per-LP backing in each component must not decrease through the mint.

To assemble the required basket from pair-token input, keep the incoming assets separate; acquire SE shares with that input; count actual SE refunds toward that caller's local contribution; and, if needed, redeem some of that caller's newly acquired SE shares to obtain the missing local pair tokens. Do not redeem existing holders' SE shares or use their local balances to assemble the new contribution. Retaining incoming pair tokens or using an SE refund can avoid a needless deposit/redemption round trip. Only SE shares remaining after any such redemption count toward `requiredSeShares_i`; count actual local proceeds, not a rated estimate.

Choose a gross LP amount supported by the assembled basket on all legs, accept its required quantities, return unused assets, and split that backed mint under FS-HOOK-09. Conversion fees, losses, and rounding belong to the incoming operation. Use the caller's input/output bounds; obtain no extra input beyond them. If the required basket cannot be assembled within those bounds, revert rather than subsidize it from the existing book. Previews use the same apportionment and fee split and disclose the required components; actual results control settlement.

If an SE is disabled and the existing book requires a nonzero SE-share contribution, fresh pair tokens alone do not justify LP issuance without those shares. Already-owned SE shares may supply that component without calling the disabled mint path. Otherwise the join cannot proceed. An entirely local contribution is sufficient only where the proportional requirements themselves require no SE shares, not because a disabled vault is treated as having a zero rated value.

For initial supply `T == 0`, use the SE-share-funded bootstrap and 5% redemption in FS-HOOK-10, not these existing-supply ratios. The new initial LP denomination is rate-free and follows the retained per-family seed function and locked floor. Do not preserve a legacy rate-valued genesis calculation or accept pair-token input for a funded SE-backed leg on that first join.

### FS-HOOK-08 — Proportional Hook LP withdrawals

For a holder burning `b` Hook LP tokens, snapshot the booked components and applicable supply `T` before the burn. Allocate on each SE-backed leg:

```text
seSharesOut_i = floor(b * S_i / T)
localPairOut_i = floor(b * L_i / T)
```

Allocate each raw leg by the same fraction. Multiply before dividing. Existing locked/minimum LP supply remains in `T`; rounding residue remains in the book for its continuing owners. Do not calculate a rated total and then satisfy the whole LP exit local-first: that is the swap settlement rule, not LP ownership.

For a pair-token payout, redeem only the exiting holder's allocated SE shares and add that holder's allocated local pair tokens. Pay actual proceeds subject to minima. For a requested single-token exit across legs, first allocate the proportional asset basket, then convert only that holder's allocated assets under the family's applicable swap/fee rules. Do not sell remaining holders' inventory or make them absorb conversion loss. A failed conversion or minimum check reverts the whole exit.

A disabled SE does not trigger a post-withdrawal deposit. Keep remaining holders' local book intact and accounted for; execute permitted redemption for the exiting holder. Any residual reinvestment must not make an otherwise permitted disabled withdrawal fail. Previews, all withdrawal entrypoints, and the remaining-holder book use the same allocation. This mirrors the separate principal/booked-claim ownership principle in FS-OWN-30, but does not replace this vault's own liquidity-based issuance or exit formulas.

### FS-HOOK-09 — Protocol fee from the backed LP mint

Let `grossLp` be the Hook LP supported by the accepted contribution before the deposit fee and after any separate genesis-floor allocation. Let `f` be the configured Hook LP mint-fee percentage in WAD precision. Resolve the existing fee recipient through the hook's fee configuration. When the fee is active and the recipient is nonzero:

```text
feeLp = floor(grossLp * f / 1e18)
netLp = grossLp - feeLp
mintedToDepositor + mintedToFeeRecipient = grossLp
```

Use full-width multiply/divide. Mint `feeLp` to `feeTo` and `netLp` to the depositor's recipient. If the fee is inactive or `feeTo` is zero, the fee portion is zero and the backed mint goes to the depositor. Skip zero-amount mints. Do not charge a fee on the fee LP itself. The configured percentage is applied to new LP issuance, not to swap output, reserve value, or prior growth; this lock does not choose a new numerical percentage or import the FullSpread vault's 30% cap into hooks.

For example, a contribution backing 100 LP at a 2% fee mints 98 to the depositor and 2 to the fee recipient, never 102 in total. Existing holders receive the complete proportional component contribution for those 100 new LP. The protocol's LP remains invested and has the same proportional backing and participation in subsequent trading fees as other LP.

Apply the fee only to caller-funded liquidity issuance, including genesis and supported proportional, single-token, flexible, SE, SY, and Permit2 deposit aliases. Do not charge it on withdrawals, transfers, rate changes, or yield growth without a deposit. Swap trading fees and any conversion costs remain governed by their existing rules; do not also run the replaced growth-based protocol LP mint. Remove growth checkpoints used only for that retired fee calculation, without removing invariants still required for swap pricing or correctness.

Hook deposit previews and minimum-LP checks use `netLp`. Exact-net-LP requests must size a gross contribution whose rounded fee split delivers the requested net amount within the caller's maximum input; preview and execution use identical integer rounding. A requested net output that cannot be satisfied fails atomically. Do not reuse an exact-output path that depends on an unavailable SE operation merely to perform this gross-up.

On genesis, the permanently locked minimum-liquidity floor is a separate allocation included in total supply, not a depositor fee and not part of `grossLp`. Exclude it exactly once. The initial supply increase is the floor plus `grossLp`; on later deposits it is `grossLp` only. Fee mint, depositor mint, component booking, caller refunds, and settlement are atomic. This rule does not change the FullSpread vault's separate FS-OWN-24 usage fee, and it adds no LP fee to a hook that has no LP token.

### FS-HOOK-10 — SE-share-only initial liquidity and 5% local seed

This rule applies only when a liquidity-bearing hook has no prior LP supply. For each funded SE-backed leg, accept the caller's SE Vault shares, not its underlying `pairToken`, as initial input. A pair-input or single-token alias cannot silently bypass this rule by depositing to the SE inside the bootstrap. The caller may acquire shares before the hook call. Raw legs still take their raw token. Keep each family's existing required positive-leg count and supported initial topology; this lock does not require nonexistent SE shares for a raw leg or create an LP product for the conversion-only single hook.

For actual received shares `A_i` on each funded SE-backed leg, compute and execute:

```text
sharesToRedeem_i = floor(A_i * 5 / 100)
retainedSeShares_i = A_i - sharesToRedeem_i
localPairSeed_i = actual pairToken proceeds from redeeming sharesToRedeem_i
```

Use the supported share-in/pair-out SE redemption route and the configured member `pairToken`. Verify that the selected share amount was actually consumed; a quote or partial share refund is not a completed 5% redemption. Require a nonzero redemption amount and positive actual pair-token proceeds for every funded SE leg, as well as the family's minimum-liquidity condition. Enforce the depositor's minimum outputs and deadline. If any required redemption fails, is incomplete, or cannot seed its component within those bounds, revert the entire initial join without leaving a partial book or LP mint. Permitted redemption can run while the SE is disabled; bootstrap does not require an SE deposit or a cleanup redeposit.

Book the retained SE shares and actual local proceeds separately. The local amount is not calculated from `getRate`, a price sample, or an assumed one-to-one share conversion. SE redemption fees, price impact, and rounding are borne by this incoming bootstrap operation, never by staged or unbooked funds. Ambient token balances do not become the seed contribution.

Determine the initial LP quantity with each family's existing seed-function shape and minimum-liquidity floor, using normalized retained SE-share quantities as its SE-leg inputs and normalized accepted raw quantities for raw legs. Do not feed rated reserves into the seed function. The local redemption proceeds belong to the same initial backing basket; do not add a separate rate-valued mint for them. Allocate the locked floor once, then split the remaining gross LP between the depositor and protocol under FS-HOOK-09. If the seed cannot exceed the required floor, revert.

The 5% is a fraction of supplied SE shares rounded down, not a promise that 5% of economic value is local or that the final value ratio is 95:5. It is only the initial seeding operation. Subsequent swaps may change the mixture, subsequent deposits match the current actual component proportions under FS-HOOK-07, and withdrawals allocate those components under FS-HOOK-08. Do not maintain a 5% target, automatically redeem 5% on later joins, or restore the FullSpread vault's removed sleeve policy.

## 8. Testing

### FS-TEST-01 — Harness

Place the TestBase under the family's `test/bases/`. Use this family's production-first setup: extend `IndexedexTest` and the canonical native-wrapper base, call parent setups in the current order, and deploy the PoolManager through the existing artifact-backed CREATE3 helper. Deploy facets and the package through the current factory and manager paths. The hook under test and this vault bind that same manager. Two managers do not prove FS-UNLOCK-02.

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

Use the FS-A acceptance rows below rather than inherited tests of removed economics. FS-A19 through FS-A23 cover already-unlocked `exchangeIn`; FS-A22 still rejects the other unlocked methods. Rebuild fixtures around the in-scope family and standard interfaces, not another named vault implementation.

### FS-TEST-03 — Acceptance rows

| ID | Assertion |
| --- | --- |
| FS-A01 | Package inputs follow FS-FACET-01. ERC-165, ERC-8109, loupe, and the cited temporary-hook facet are absent from cuts and still callable on the factory-built proxy where the factory installs them. The reviewed selector manifest succeeds through the proxy. Family `poolManager()`, family-only `poolKey()`, `rateAsset()`, `getRate()`, `basket()`, `wrappedNative()`, `localReserves()`, and every Standardized Yield selector are absent. The Crane Protocol Aware getters and `UniswapV4SinglePositionAware` getters are callable. Factory selectors stay disjoint. |
| FS-A02 | `bindingHash` changes if any facet, library, or infrastructure binding changes. |
| FS-A03 | Invalid component, uninitialized or hooked pool key, double initialization, wrong `processArgs` caller, and right registry in the wrong account all revert and leave no usable vault. There is no rate-asset argument, no wrapped-native argument, and no zap-limit argument to reject. There is no inherited-domain reject. |
| FS-A04 | The family storage slot does not collide with another vault family's slot. |
| FS-A05 | First deposit creates one full-range salt-zero position owned by the diamond. Added liquidity less than or equal to `1_000` is rejected. Genesis issuance follows FS-MONEY-01 and FS-OWN-24. The floor is `MIN_SHARES` of supply, minted to `address(0)` through `_mint`. The depositor receives gross shares minus fee shares. No performance fee is added. |
| FS-A06 | Paired deposit and redeem follow the mapped bundle routes and FS-MONEY-01. The bundle redeem pays both tokens and does not swap. |
| FS-A07 | Unused declared entry input is refunded to the payer under FS-OWN-32. It is not booked and it is not minted. There is no `IncompleteConversion` revert. `feesAccrued` on a share-minting deposit is booked and is not share credit. The one-token exit is FS-A08. |
| FS-A08 | A one-token exit pays `recipient` the FS-OWN-30 receipt, or reverts `AmountOutNotMet` and does not burn shares. That receipt is the swap proceeds, the withdrawn requested-token principal, the holder's requested-token fee portion, and the holder's requested booked claim. It swaps all of the holder's opposing token and does not pay, book, or keep that residual. A both-token exit pays the claim in both tokens and does not swap. |
| FS-A09 | `previewExchangeOut` returns zero and does not change balances. On an enabled vault, `exchangeOut` reverts `ExchangeOutNotAvailable` with unchanged balances. A disabled `exchangeOut` is FS-A38, not this row. Neither gains a refund return. A zero preview is not a promise that `exchangeOut` succeeds. |
| FS-A10 | Callers send and receive WETH only. Native wrap or unwrap happens only at the pool boundary. The vault does not accept or produce native ETH. |
| FS-A11 | A deposit, a withdrawal, and `exchangeIn` do not call `compound()`. A withdrawal pays the FS-OWN-30 claim and books the rest. It does not pay another holder's booked balance. There is no collection-only fallback. |
| FS-A12 | Withdrawn. `exchangeRate` is not installed. FS-OWN-05. |
| FS-A13 | Withdrawn. `getRate` is not installed. |
| FS-A14 | Withdrawn. `InsufficientRateSupply` is not declared. |
| FS-A15 | Withdrawn. A planner failure is not observed through `getRate`. |
| FS-A16 | Withdrawn 2026-11-06. Do not add a test that issuance does not read `exchangeRate`. `getRate` stays absent under FS-OWN-03. That absence is not this row. |
| FS-A17 | A multi-action locked deposit and a multi-action locked withdrawal perform one unlock and one consumed callback per planned action. Replay after each callback reverts. The guard stays active between actions. The borrowed equivalent performs zero unlocks. |
| FS-A18 | `unlockCallback` from any caller but the bound manager reverts and moves no tokens. |
| FS-A19 | While the manager is unlocked, `exchangeIn` does not call `unlock`. This diamond's touched deltas are zero before return. The global delta count may be nonzero. Position owner, ticks, and salt are unchanged. Liquidity may change. |
| FS-A20 | A borrowed `exchangeIn` that is not self-funded, or that sets `pretransferred`, reverts `InvalidUnlockedContext` or the inherited funding error. A call with value fails at the nonpayable boundary, not as a specified internal `msg.value` check. |
| FS-A21 | An unlocked caller who does not hold the input or the shares does not mint. The unlocked flag is not authority. |
| FS-A22 | `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` revert `ManagerAlreadyUnlocked` while the manager is unlocked. `depositPair` and `redeemPair` are absent. There are no SY mutators. |
| FS-A23 | A reverting borrowed `exchangeIn` restores shares, liquidity, and token balances. |
| FS-A24 | An SE Vault whose `vaultTokens()` omits its own share still supports its own-share mint and redemption through the supported routes. The hook binds a valid member `pairToken` separately from the SE-share inventory. Do not require self-membership, call `asset()`, or leave this positive own-share proof failing solely because the vault does not list itself. Invalid paired-token bindings are the separate negative in FS-A40. |
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
| FS-A38 | A disabled vault reverts `VaultDisabled` on every execution route except a withdrawal, `donate`, and `compound`. A withdrawal is `exchangeIn` with the share as `tokenIn`, or `exchangeBundleOut` with the share as `tokenIn`. A pass-through and a bundle deposit revert `VaultDisabled`. `donate` and `compound` do not. Views do not. A missed deadline reverts `DeadlineExceeded` before the disable check. A buffered withdrawal succeeds without a forbidden cleanup deposit. A non-withdrawal call into the disabled vault still reverts while the manager is unlocked; hook-local operations instead follow FS-HOOK-06. Run the enabled `exchangeOut` revert on an enabled vault. |
| FS-A39 | The live `feeTo()` owner may appoint a global operator through `setOperator` and a function operator through `setOperatorFor`. A global operator may call `donate` and `compound`. A function operator may call only the granted selector. A stranger reverts. Appointment is not gated by a stored owner. `feeTo()` is not stored as that owner at initialization. The maintenance modifier is not `OperableModifiers.onlyOwnerOrOperator`. |

The following additional acceptance rows lock the 2026-11-06 hook amendment. They supplement the existing vault rows and do not renumber audit IDs.

| ID | Assertion |
| --- | --- |
| FS-A40 | Every FS-HOOK-01 family and shared SE-leg helper validates the configured `pairToken` through `vaultTokens()` without calling or probing `asset()`. A member paired token is not rejected because `asset()` is absent, reverts, or cannot identify a single underlying. A nonmember configured paired token is rejected even if `asset()` answers. Separately, omission of the vault's own share from the list never rejects the vault or its supported own-share processing; those operations are covered by FS-A24. |
| FS-A41 | Each leg separately books SE shares and local pair tokens. SE refunds and disabled-vault residuals are counted once. Pending inputs, user refunds, unbooked transfers, and other legs' holdings cannot be spent or credited as this leg's LP backing. Verify conservation and rollback across booking, settlement, and failure. |
| FS-A42 | Swap previews and execution include the local book plus rated SE backing in the same pair-token units. Output below, equal to, and above the local book uses local tokens first; only a deficit triggers permitted SE redemption. A disabled input SE is not called for buffering: accepted hook-owned input remains local. Existing pricing, fees, minima, and manager settlement still apply. |
| FS-A43 | A join on an existing supply supplies the same LP fraction of every SE-share, local-pair, and raw component, rounding required inputs up. With component quantities held fixed, a changed rate or underlying spot price does not change the component requirements or the gross LP entitlement. Conversion and SE refunds use the incoming caller's assets only; only shares remaining after conversion count. Existing holders' per-LP component backing is not diluted. The new gross mint is split under FS-A47; the net receipt is not the quantity used to size backing. |
| FS-A44 | A burn receives its fraction of each component, rounding payouts down against pre-burn supply including any locked floor. Redeem or convert only the exiting holder's allocated assets. A minimum-output or conversion failure rolls back. Multiple exits preserve remaining holders' local and SE-share claims; no first exiter receives others' local inventory through rated local-first LP settlement. |
| FS-A45 | Disabled-vault exits complete without cleanup deposits; direct prohibited SE calls still revert. A join requiring SE shares cannot mint from pair tokens alone when those shares cannot be acquired, but can use already-owned shares without a disabled mint. Cover zero local, zero SE-share, mixed live books, the FS-A48 share-funded bootstrap, rounding dust, and disable/re-enable transitions without treating disabled backing as valueless. |
| FS-A46 | Reproduce the proposed Hook join, underlying-pool price/liquidity change, Hook exit, and underlying-position unwind sequence. Assert quantity-based LP issuance and proportional claims, with no additional claim on existing holders' SE shares or local pair tokens from a rate change. Separate actual conversion PnL and swap pricing from LP accounting; do not claim the wider swap-manipulation problem solved by this test. Exercise each family's entrypoints and previews using production instances. |
| FS-A47 | On every LP-bearing hook deposit path, gross LP is fully backed by the accepted component basket and is split into fee LP plus depositor net LP, never supplemented by fee LP on top. Previews/minima use net LP; exact-net requests gross up consistently. Cover zero fee, inactive/zero recipient, integer fee dust, genesis-floor exclusion, and ordinary/share/flexible/SE/SY/Permit2 aliases. Rate or yield growth without a deposit mints no protocol LP. Withdrawals and the fee mint itself incur no mint fee. Existing swap fees still accrue to LP holdings. Verify no legacy growth-fee mint or separate protocol swap-fee accumulation remains active alongside the replacement. |
| FS-A48 | Initial liquidity accepts only SE shares for each funded SE-backed leg and raw tokens for raw legs. Redeem floor(receivedShares * 5 / 100), verify actual share consumption and positive pair-token receipt, and book retained shares and actual local proceeds separately. Initial pair-token inputs on SE legs, zero/dust redemption, unmet minima, incomplete redemption, or any failing leg revert atomically. Seed LP from rate-free retained-share/raw quantities using the family seed function and floor; apply FS-A47 only after the floor is allocated. Cover permitted bootstrap redemption while disabled, varying redemption proceeds, unbooked transfers, mixed decimals, and first/subsequent joins to prove 5% is not a continuing target. The conversion-only single hook has no LP genesis and is not given one. |

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

It adds a row for this vault beside those contracts and updates shared hook assertions where FS-OWN-34 through FS-OWN-37 changes the behavior of all SE legs. Preserve unrelated assertions for other families; do not weaken a failing test to claim compatibility. Exact-output success rows cannot pass for a call into this vault. On an enabled vault, `exchangeOut` reverts `ExchangeOutNotAvailable()`, and `previewExchangeOut` returns zero. This vault refunds unused user input; hook receipt and booking follow FS-HOOK-05/07. A vault donation or compound remainder is booked, so those rows stay. This replaces the November 1 report sentence that said booked-remainder rows cannot pass. Run FS-A40 through FS-A48 across the seven named hook families and relevant shared paths; the pre-amendment implementation plan's no-hook-edits instruction is superseded for this scope.

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
| 024 | yes | A one-token exit swaps the FS-OWN-30 exiting claim only and pays that receipt to `recipient`. It does not sell the staying holders' inventory. The unbounded limit stays. The absence test is the quantity, not a price check. Do not copy "withdrawn net." |
| 025 | no | Wings rebalance and loss cap are absent. |
| 026 | no separate Wings test | The 512-step liquidation quote is absent. Dust-tick liveness of this vault's own quote is the 041 test. Do not reopen a spacing rule. |
| 027 | no | Staking withdrawal queues are absent. |
| 028 | yes | A dual-hook own-share exit on a valid SE/paired-token binding must not burn the caller's position and pay zero. The vault's own share need not appear in `vaultTokens()`. |
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

The hook accounting, refund, disabled-vault, membership, LP mint-fee, and initial-liquidity refactor in FS-OWN-34 through FS-OWN-37 is required scope of the broader failing-test fix. This document update records requirements, not execution authorization. It does not itself perform implementation, deployment, or a registry migration. It does not add unrelated hook economics, a Weir copy, a wings range, a second vault pool, a transition-quote facet, a zap cap, a tick guard, a swap price check, a quote step cap, a minimum tick spacing, a fee-origin store, an exit fee, a fee-increase delay, a new 0% override, a vault rate, a `WithRefund` sibling, a refund return on `exchangeOut` or `previewExchangeOut`, or Weir's treasury performance fee.

It does not add a local liquidity sleeve to the FullSpread vault. The hook-local books required by FS-OWN-34 are distinct from that vault's booked balances and do not restore a target percentage. It does not restore `PkgInit.wrappedNative` or a `wrappedNative()` getter. The WETH address is the `PkgInit.weth` field written through `WETHAwareRepo`. It does not invent paired-event arguments. `Donation()` and `Compounded()` have no arguments. Both empty lists are owner locks, not invented field lists. `Donation()` is a marker event, not an interface.

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
