# Uniswap V4 full-spread Standard Exchange vault implementation and testing plan

- Plan ID: se-fullspread-implementation-plan-20261104
- Source draft: `docs/research/se-fullspread-implementation-plan-20261104/coordinator/draft.md`, draft ID `draft-se-fullspread-implementation-plan-20261104-r1`
- Council report: `docs/research/se-fullspread-implementation-plan-20261104/REPORT.md`
- This plan does not authorize implementation, tests, installs, deployment, or Git.

The advisory corrections that changed the draft are applied here. Names the PRD left open stay names, not new requirements.

## 1. Authority

Build and test `UniswapV4FullSpreadStandardExchangeVault` from `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`. A dated 2026-11-04 lock in that file and in `IMPLEMENTATION_PLAN_BLOCKERS.md` wins over an older sentence. Status lines that say the PRD has not been edited are not locks. `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md` is not an economics source. FS-TEST-04 wins over the November 1 report's blocked cells.

Do not start the work this plan describes until a later owner instruction authorizes implementation.

## 2. Adopted readings

- A pass-through is an exact-input swap of the declared input on the bound hookless pool. The price limit is `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`. It mints no shares, takes no usage fee, and does not call `modifyLiquidity`.
- FS-OWN-33 applies only to a one-sided share mint and to a one-token `donate` or `compound`. Owner instruction 2026-11-06: swap 49% of the processed input when the price is strictly inside the position. Do not iterate. Do not solve a closed-form root. Do not walk ticks to find a better split. If the price is not strictly inside the position, including exactly at either boundary, do not swap. A share mint refunds what the add does not take. A donate or compound books that dust and does not refund it. The swap output is consumed by the add. Rounding leaves any remainder in the original input token. The swap input is not the processed-token amount the add itself consumes.
- A planned manager action is one `swap` or one `modifyLiquidity`, not one public call.
- `Donation()` and `Compounded()` have no arguments. They are marker events. Do not add a Donation interface.
- The live `feeTo()` address is the owner. That owner appoints global operators with `setOperator(address,bool)` and function operators with `setOperatorFor(bytes4,address,bool)`.
- Disable blocks every execution route except a withdrawal, `donate`, and `compound`. A missed deadline reverts `DeadlineExceeded` before the disable check.
- Gas ceilings stay 12,000,000 and 5,000,000. A standalone public money or maintenance call passes only if its cold call body is at most 11,900,000, leaving 100,000 overhead. Fixture setup stays outside that body. Do not warm the measurement with a preview. A composed hook route passes only if the whole transaction, including hook work, is at most 12,000,000. Previews fit 5,000,000. An oversized route is unresolved, not passed. There is no `getRate` read in the measurement.

## 3. File map

Family root: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`.

Production files named by FS-ARCH-01, plus the two modifier files the PRD left unnamed:

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
- `UniswapV4FullSpreadStandardExchangeVaultOwnerModifiers.sol`
- `UniswapV4FullSpreadStandardExchangeVaultMaintenanceModifiers.sol`
- one facet and one target for money, quote, out, query, and callback

The six `linkedLibraries` entries stay Math, Projection, SwapProjection, Planner, Execution, ExecutionPreparation. `SwapProjection` and `ExecutionPreparation` are separate files. That split is an implementation name, recorded in section 14. It does not change the six-address order.

Crane files live under `lib/crane/contracts/protocols/dexes/uniswap/v4/aware/`, not in the family directory. Both the Protocol Aware pair and `UniswapV4SinglePositionAware` live there.

Tests use the seven filenames in FS-TEST-02, under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`. The matrix adapter is `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol`. It deploys this vault and exposes the two face tokens. Do not edit the other families' expected amounts inside the seven existing behavior contracts. A one-word `previewExchangeIn` or `exchangeIn` comparison in those files may be changed only to read `amountOut` when section 12 requires that migration. If the ABI decoder already ignores the trailing refund word, leave that comparison. Add the row files named in section 12 beside those behavior contracts. Do not add a sibling behavior contract.

## 4. Package and storage

`PkgInit` binding order:

1. `erc20Facet`, `erc2612Facet`, `erc5267Facet`
2. `basicVaultFacet`, whose address is `MultiAssetBasicVaultFacet`. The cut installs only `vaultTokens`.
3. `standardVaultFacet`, `moneyFacet`, `quoteFacet`, `outFacet`, `queryFacet`, `callbackFacet`
4. `uniswapV4ProtocolAwareFacet`, `uniswapV4SinglePositionAwareFacet`
5. `poolManager`, `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, `universalRouter`
6. `registry`, `oracle`, `weth`, `diamondFactory`
7. `linkedLibraries` as `address[6]`

No `syMoneyFacet`, `syQueryFacet`, `wrappedNative`, `operableFacet`, or `rateAsset`.

`PkgArgs` is `PoolKey poolKey`. Name and symbol are not arguments. Initialization generates the name and hardcodes the symbol `UV4X`. `bindingHash` covers every `PkgInit` field. `deployVault` goes through the bound IndexedEx vault registry. `processArgs` reverts `NotCalledByRegistry` unless `msg.sender` is the bound registry and `address(this)` is the bound `diamondFactory`.

Reject, with no partial diamond: a missing or code-empty component, a linked-component hash mismatch, or a cut that installs `getRate` or `rateAsset` (`InvalidComponent`); a pool key that is not initialized on the bound manager or whose hook is not `address(0)` (`InvalidPoolKey`); a second initialization (`AlreadyInitialized`); a proxy initialization that does not match the bound package (`InvalidInitializationContext`). Do not reject tick spacing.

Owner instruction 2026-11-05: `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, and `universalRouter` are components. Each must have code. A missing or code-empty value reverts `InvalidComponent` with no partial diamond. The owner called these the Uniswap V3 infrastructure and said the vault will not work if they are absent.

Initialization writes the seven architecture addresses into the Protocol Aware repo, writes `weth` through `WETHAwareRepo._setWeth`, stores the pool key, full-range ticks, and salt `bytes32(0)` in `UniswapV4SinglePositionAware`, generates the name, hardcodes the symbol `UV4X`, sets 18 decimals, and sets the EIP-712 domain to that generated name. The version is `"1"`. `vaultTokens()` is the PoolKey's two ERC-20 faces in currency0, currency1 order, with WETH substituted for native at the boundary. That order does not change after initialization. Initialization does not mint the floor and does not store `feeTo()` as an ownable owner.

Family slot: `keccak256(abi.encode("indexedex.vaults.standard.exchange.uniswap.v4.fullSpread")) - 1`. It must not equal the PairToken slot or the Wings slot.

Family storage:

- `uint256[2] booked`, in `vaultTokens()` order. There is no second ledger and no fee-origin store.
- `bytes32 callbackHash`
- `uint256[2] reserved`, in the same order. A reservation is the amount this operation has set aside for its own refund or payout. It is nonzero only while that operation is open. It is not pretransfer credit. It is zero before the call returns.
- the public-operation guard

At an idle boundary, with reservations zero, the unbooked balance of face `i` is `token.balanceOf(address(this)) - booked[i]`. During an operation, available unbooked balance is that amount minus `reserved[i]`. Use checked subtraction. Do not index `booked` by address.

`reserves()` and `reserveOfToken` do not add booked or unbooked local balances. They are the position amount implied by liquidity, the current price, and the stored ticks, plus unpaid fees owed to this position. `positionLiquidity()` uses `StateLibrary.getPositionInfo` on the bound PoolManager. An unknown `reserveOfToken` returns zero.

## 5. Selector cut

Do not install a family `poolManager()` or a family `poolKey()`. The Crane Protocol Aware facet's `poolManager()` and the other stored-component getters stay callable. `UniswapV4SinglePositionAware` exposes `poolKey()`, `positionLiquidity()`, `tickLower()`, `tickUpper()`, and `positionSalt()`.

Query facet installs only `reserveOfToken` and `reserves`.

Money facet installs `exchangeIn`, `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, `compound`, `setOperator`, and `setOperatorFor`. Do not install `isOperator` or `isOperatorFor`. The cut is not a partial `IOperable`.

Quote facet installs the three preview selectors. `previewExchangeIn` returns `(uint256 amountOut, uint256 amountRefunded)`.

Out facet installs `previewExchangeOut` and `exchangeOut`. Derive those selectors from the current `IStandardExchangeOut` signatures at implementation time. Do not treat a copied hex literal as a second ABI source.

`vaultTokens` comes only from `MultiAssetBasicVaultFacet`. Shared ERC-20, ERC-2612, ERC-5267, and standard-vault selectors stay on their package facets. Do not install `getRate`, `rateAsset`, `asset`, `depositPair`, `redeemPair`, the paired previews, `previewZapCredit`, `previewWithdrawalMode`, `localReserves`, `basket`, `wrappedNative`, or any Standardized Yield selector.

ERC-165 for `IStandardExchangeIn` is `0x59fb2971`. Do not advertise `0x8c8035da` or `0x676ec907`. Recheck the bundle interface ids with `type(I).interfaceId` before registration. The accepted report's values are `0x2576ed1a` and `0xb40c1ba3`. ERC-165 does not detect the return-width migration.

`PostDeployAccountHookFacet` is the factory temporary hook, cited from `DiamondPackageCallBackFactory.sol` line 31. The factory removes it in `postDeploy`. The finished proxy must not keep those selectors. ERC-165, ERC-8109, and the loupe remain callable. They are not `PkgInit` fields.

Public money, maintenance, appointment, preview, and out functions are `nonpayable`. A call with value fails at that boundary. Native value is accepted only inside `unlockCallback` for PoolManager settlement.

## 6. Check order

On every route that takes `deadline`, a missed deadline reverts `DeadlineExceeded` before any other work, including disable.

Disable, after that deadline check, reverts `VaultDisabled(address(this))` unless the route is a withdrawal, `donate`, or `compound`. A withdrawal is `exchangeIn` with the share as `tokenIn`, or `exchangeBundleOut` with the share as `tokenIn` and `tokensOut` exactly the two faces in either caller order. A pass-through is not a withdrawal. A disabled `exchangeOut` reverts `VaultDisabled`, not `ExchangeOutNotAvailable`. The same predicate applies on a borrowed unlock. Views do not revert.

`exchangeIn`, after deadline and disable:

1. `tokenIn == tokenOut` reverts `InvalidRoute`.
2. `amountIn == 0` reverts `EmptyExchange`.
3. A zero address, or a token that is neither the share nor a face, reverts `TokenNotExchangeable`.
4. `recipient` of `address(0)` or this vault reverts `InvalidRecipient`.
5. A `pretransferred` caller with no bytecode reverts `EOAPretransferNotAllowed`.
6. Read `TransientStateLibrary.isUnlocked`. Locked follows section 8. Unlocked follows the borrowed path. `isUnlocked` is not authority.
7. Fund under section 7. Output goes to `recipient`. Refunds go to `msg.sender`.
8. Enforce the caller's minimum on the final output. A share mint uses the recipient's net shares. A pass-through uses the actual swap output. A one-token exit uses the recipient receipt: the swap proceeds plus the withdrawn amount sent to the recipient. That receipt is not the swap proceeds alone and it is not the pre-execution quote. A miss reverts `AmountOutNotMet`.

`exchangeBundleInForSingleOut`, after deadline and disable:

1. `amountsIn.length != vaultTokens().length` reverts `AmountsLengthMismatch`.
2. `tokenOut` must be the share. Any other combination reverts `ExchangeBundleInForSingleOutNotAvailable`. Do not turn it into a success path.
3. `recipient` of `address(0)` or this vault reverts `InvalidRecipient`.
4. A zero slot is not provided and does not require that token to be exchangeable.
5. If any pretransfer maximum exceeds that token's available unbooked balance, revert before any leg. Spend nothing. Mint nothing. Do not add an error and do not pin a selector.
6. This route reverts `ManagerAlreadyUnlocked` if the manager is unlocked. It has no borrowed path.
7. Enforce the net-share minimum. A miss reverts `MinAmountNotMetAt`.

`exchangeBundleOut`, after deadline and the withdrawal exception to disable:

1. `tokenIn` must be the share and `tokensOut` must be exactly the two faces, either order. Any other combination reverts `ExchangeBundleOutNotAvailable`.
2. A repeated output reverts `DuplicateOutput`. `tokenIn` in `tokensOut` reverts.
3. `tokensOut.length` must be 2. A mismatch reverts `TokenAmountsLengthMismatch`.
4. Burn only the caller's own shares. Parked shares are not burn credit.
5. This route reverts `ManagerAlreadyUnlocked` if the manager is unlocked.
6. A caller minimum fails with `MinAmountNotMetAt` at the caller's `tokensOut` index. Do not declare `MinAmountNotMet`.

`exchangeOut`: deadline, then disable, then `ExchangeOutNotAvailable` on an enabled vault. Move no tokens. `previewExchangeOut` returns zero and does not revert.

`donate` and `compound`: no deadline and no disable check. The three-arm modifier runs first. `donate` reverts when `totalSupply` is zero, before any swap. Then section 9.

`setOperator` and `setOperatorFor`: `onlyLiveFeeToOwner`, then the `OperableRepo` write. No deadline and no disable check.

`unlockCallback`: only the bound manager, only while the guard is held, only once for the committed payload. Then section 8.

## 7. Funding and refunds

Pull the full declared amount when `pretransferred` is false. Do not pull only the amount later consumed.

When `pretransferred` is true, use available unbooked balance up to the caller's maximum. If that maximum is within the available unbooked balance, the refund is the maximum minus the amount used, in the token the caller provided. Do not refund the whole remaining unbooked balance in that case. If the maximum is larger than the available unbooked balance on a one-token call, that comparison is not itself a revert. Spend nothing of that balance, pull nothing, and refund that unbooked balance. The route then continues with zero consumed input. The route's existing minimum and liquidity checks still apply. A positive `minAmountOut` still reverts `AmountOutNotMet`. A first deposit that does not add more than `1_000` liquidity still reverts `MinLiquidityNotMet()`. Do not invent a shortfall error.

A bundle whose declared maximum exceeds available unbooked balance on any leg reverts before any leg, as section 6 states.

Output goes to `recipient`. Refunds go to `msg.sender`. Share burns use the caller's own share balance or allowance. Parked shares are not that credit.

## 8. Unlock paths

Locked path. For each planned action, commit `keccak256(abi.encode(operation, payload))`, call `unlock` once, and accept `unlockCallback` only from the bound manager, only while the guard is held, and only once for that payload. Settle that action and require the manager to relock before the next action. Nested unlock and replay revert. The callback does not call `compound()`. An external unlock does not satisfy a committed hash. The guard stays active across the plan.

Settlement of a currency delta, in order: `sync` the currency, transfer or send value, `settle`, then `take` a credit. Do not call `settleFor`. Do not settle or take a foreign address's delta. For native currency, sync immediately before the value settle, and do not count the same backing as both wrapped and native. Clear the sync if the path reverts. At return, this diamond's touched per-address deltas are zero. An outer caller's unrelated deltas may remain.

Borrowed path, only for canonical `exchangeIn`. Do not call `unlock` or `unlockCallback`. Before dispatch, all of these must hold: the vault is initialized, the operation is idle, `callbackHash` is empty, `reserved` is zero, and this diamond's own backing-currency deltas on the bound manager are zero. A failure of any of those checks is a bare `revert()`. Do not use `ReentrantOperation` or `SettlementMismatch` for them. `guardHeld` already set is `ReentrantOperation`. A close that cannot settle this diamond's own deltas is `SettlementMismatch`. `pretransferred == true` is `InvalidUnlockedContext`. The caller must have code, must hold the input, and must pay it. There is no foreign payer. Share burns still require the caller's own shares. Use the same internal action, accounting, and settlement engine as the locked path. A propagated failure rolls the call back. A caught inner failure still rolls this vault's work back. The outer caller keeps its own settlement obligation. `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` revert `ManagerAlreadyUnlocked` on this path.

## 9. Money routes

`clampedFee` is the live `usageFeeOfVault` read, or `3e17` when that read is above `3e17`. The WAD denominator is `1e18`. If `feeTo()` is `address(0)`, `feeShares` is zero. Do not quantize the oracle and do not change it. `feeShares = mulDiv(grossShares, clampedFee, 1e18)`. Skip a zero mint. Otherwise mint `feeShares` to `feeTo` and `grossShares - feeShares` to `recipient`. The depositor is not charged a fee that is not minted. The floor mint is not part of `grossShares`.

Snapshot `totalSupply` and existing position liquidity before an addition. Do not include booked balances or collected fees in that denominator.

One-sided deposit. `Planner` computes the FS-OWN-33 amounts through `Math`, then the unbounded exact-input swap through `SwapProjection`. `Execution` applies those actions. It does not ask `SwapProjection` to perform the manager call by itself. The swap and the add are two planned actions in the same call, with settlement of the first and no other external call between them. On the first successful deposit, after added liquidity is greater than `1_000`, `ERC20Repo._mint` writes `1_000` shares to `address(0)`. That mint is not an initialization step. `grossShares` is `added liquidity - 1_000` on that deposit and `added liquidity * supplyBefore / liquidityBefore` later. Book `feesAccrued` from the add. Do not swap those fees into the deposit. Refund unused declared input. Do not book that refund. The minimum compares net recipient shares.

Bundle deposit. Add the proportional subset with the existing position-amount helper. Refund the unused declared input. Do not run the one-sided swap. Fee, floor, and fee booking follow the one-sided rules. Emit `PairDeposited(address indexed caller)`.

One-token exit. Measure before the burn. Remove `liquidity * sharesBurned / supplyBeforeBurn`. The fee claim is `floor(feesOwed * sharesBurned / supplyBeforeBurn)` and the booked claim is `floor(booked[i] * sharesBurned / supplyBeforeBurn)`, multiplied before dividing. Pay the requested-token fee and booked claim to `recipient`. Swap all unwanted withdrawn principal plus the opposing fee and opposing booked claim, or revert `AmountOutNotMet` and do not burn. Do not pay, book, or keep that residual. Book the other holders' remainder. Do not swap their inventory. Do not count a fee both as the pre-burn unpaid read and as an already booked balance. Owner instruction 2026-11-05: the caller minimum and the returned `amountOut` are the recipient receipt. That receipt is the swap proceeds plus the withdrawn amount sent to the recipient.

Both-token exit. Pay the same claim in both tokens. Do not swap. Emit `PairRedeemed(address indexed caller)`. The preview matches both outputs.

Pass-through. Exact-input swap through `Planner` and `SwapProjection` at the unbounded limit. No share mint, no usage fee, no `modifyLiquidity`, no fee booking. Refund unused input. The minimum compares the swap output.

`donate` and `compound`. If the unpaid fee-owed read is nonzero, collect it with one zero-liquidity `modifyLiquidity` before any FS-OWN-33 swap or proportional add. That collect is its own planned action. If the unpaid read is zero, do not call `modifyLiquidity` only to collect. A one-token maintenance call then swaps the combined one-token booked, collected-fee, and donation balance with the FS-OWN-33 shape. If both tokens are already held, do not swap. The scarcer token is the proportionally smaller amount relative to the position ratio. Deposit the matched pair and book the actual held balance after settlement. A share donation burns the caller's shares and does not withdraw or swap them, then follows the same compounding rule for held tokens. Any failed processing step reverts. A remainder alone does not. A later maintenance call may process it. Do not refund a donation or compound remainder.

`compound()` with no fees and no booked remainder returns with no state change and no event. A successful `donate()` emits `Donation()` even when it deposits nothing. Emit `Compounded()` only when a deposit is made from collected fees or booked tokens. A fresh donation that does not use collected fees or booked tokens emits `Donation()` and does not emit `Compounded()`. A reverting call emits neither.

## 10. Quotes

`UniswapV4FullSpreadStandardExchangeVaultPlanner` is the one engine. Preview and execution both call the same Planner function. Planner calls `Math` for FS-OWN-33 amounts and `SwapProjection` for the unbounded exact-input projection. It reads pool state. It does not call the stored Quoter, State View, or Reserves Lens for the quote. It has no step cap and no `QuoteWorkLimit`. Owner instruction 2026-11-06: sizing is 49% of the processed input, as section 2 defines it. Do not iterate. Do not solve a closed-form root.

A mint preview returns the depositor's net shares and does not credit existing fees. A one-token exit preview uses the post-removal state and the same pre-burn apportionment, so `amountOut` matches execution from the same state. A bundle-in preview returns net shares and a positional refund array in `vaultTokens()` order. A bundle-out preview returns the two caller-ordered outputs and a zero refund, matching execution. Refund-word inequality does not waive an output minimum or exit-output equality. An unsupported view returns zero and does not revert.

## 11. Operators and disable

`onlyLiveFeeToOwner` reads `VaultFeeOracleQueryFacet.feeTo()` on the bound oracle and compares `msg.sender` to that proxy address. `onlyLiveFeeToOwnerOrOperator` admits that address, a global operator in `OperableRepo`, or a function operator for `msg.sig`. Do not call `OperableModifiers.onlyOwnerOrOperator` or `MultiStepOwnableRepo._onlyOwner`. A stranger reverts the existing `IOperable.NotOperator(address)`. That is not a new family error.

A disabled vault follows section 6. A buffered withdrawal still succeeds. A buffered non-withdrawal reverts while the manager is unlocked. Run the enabled `exchangeOut` assertion on an enabled vault.

## 12. Hook integration and migration

Add the row files named below beside each live behavior, including the separately named larger-leg rows. Copy the Uniswap V3 full-spread row shape: one contract, `sharedPkg` where the V3 row uses it, and `_newFixture()` returning `new SeMatrix_FullSpreadV4Fixture(_ctx(), sharedPkg)`. Do not add a sibling behavior contract. Do not edit the seven behavior contracts to change another family's expected amounts. Do not weaken their other-family assertions. Do not copy V3 row comments that say full-spread exact-out delivers the previewed amount.

The one fixture file is `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol`. It follows `SeMatrix_FullSpreadV3Fixture.sol` except for this family's package, pool, and refund tuple.

- Package: deploy this vault through its production package and the bound IndexedEx registry. Not the V3 package. Not `exchangeInManyToOne`. Not `setLiquidReservePercentageOfVault`, `localReserve`, or `deployedReserve`. Bootstrap is one bundle deposit of both faces through this vault's public bundle route.
- Pool: one bound hookless PoolKey, hook `address(0)`, initialized on the bound PoolManager. Not a Uniswap V3 3000-fee pool.
- Refund tuple: `previewExchangeIn` and `exchangeIn` return `(uint256 amountOut, uint256 amountRefunded)`. The fixture and the rows read `amountOut`. The refund word is not output and is not shares. `previewExchangeOut` returns zero. An enabled `exchangeOut` reverts `ExchangeOutNotAvailable()`.

The fixture deploys this vault, that hookless pool, the two face tokens, and two external rate-provider instances against the same vault. The two faces are the backing PoolKey currencies in `currency0`, `currency1` order, with WETH substituted for native at the boundary. Hermetic mintable faces are sorted so `currency0` is the lower address. `faceToken()` on the primary rows is `currency0`. `otherToken()` is `currency1`.

- `currency0` provider: `reserveVault` and `rateSubject` are this vault. `rateTarget` is `currency0`.
- `currency1` provider: the same vault. `rateTarget` is `currency1`. It does not deploy a second vault.

This vault stores no provider and does not implement `getRate()` or `asset()`. `hasPartialCase()` returns false. `limitCapacity()` and `openCapacity()` are not part of this fixture. Do not add a sleeve capacity gate. Do not add a booked getter. Do not `vm.load`, etch, or mock this vault or the PoolManager.

Index rule. For a currency-sorted pair, `index(X)` is 0 when `X` is the lower address, otherwise 1. `zeroForOne` spends currency 0. `oneForZero` spends currency 1. For an ascending array, sort the whole token, SE, provider, and weight record together. `index(X)` is that record's rank. This vault's share is a PoolKey currency only in `single/`. In every other family the share is buffered inventory on the face leg. It is not a pool currency.

Backing currency order, rate-target selection, and product-pool index placement are three observations. Changing one is not evidence of the others. For each two-currency product pair that includes this vault's face, the row has two index cases besides the rate-target cases. One mints the counter-leg token at an address below the face, so the face is product index 1. One mints it above the face, so the face is product index 0. Assert that index before the swap.

PairToken identity record. Use this one record wherever a topology names another Standard Exchange. Deploy one PairToken vault through `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultDFPkg.sol`, using that family's existing package test setup. Do not construct it with `SeMatrix_FullSpreadV4Fixture` or `SeMatrix_FullSpreadV3Fixture`. Its faces `P0` and `P1` are address-sorted and disjoint from this vault's faces. Its share is the PairToken diamond. Acquire those shares before the outer unlock. Deploy its provider through `IStandardExchangeRateProviderDFPkg` with `reserveVault` and `rateSubject` equal to that vault and `rateTarget` equal to `P0`. Do not call `RateProviderFixtureLib.providerFor` for this leg. Do not call `asset()` or `rateAsset()` to build the instance. The leg token is the PairToken share. The SE argument is the PairToken vault. The provider argument is that instance. During the outer unlock the hook does not call that vault's `exchangeIn`, `exchangeOut`, or bundle routes. Do not treat the share as a peg equal to one face unit. Raw companion tokens are distinct 18-decimal mintable tokens. A stable row prices a share leg through its configured provider and does not infer a peg from share decimals.

That identity record is a passing transfer-only proof only if the package accepts `token == se` and the hook transfers the share without a PairToken money call. If the package rejects that bind without `asset()`, record the consumer, selector, arguments, and revert under FS-HOOK-04. Do not pass that variant. Do not add `asset()`. Do not replace the leg token with a raw token and call the same row FS-A26. A raw leg has no second backing PoolKey. The canonical proof stays open until the identity record itself runs. Do not substitute a second instance of this vault.

Setup. `single/` and `constantProduct/single/` do not override `setUp`. They use the inherited behavior setup. The constant-product `_rowPkgArgs` provider is the `currency0` provider only. The currency1 case is a separate test. It deploys its own hook pool and passes the `currency1` provider. It does not ask `_rowPkgArgs` to build that second provider.

Every other row overrides `setUp` and does not call the behavior `setUp`. It calls that family's existing TestBase `setUp` once, by the TestBase contract name, before its own bind. Then it constructs the fixture, binds the selected hook arguments, and funds the role-specific legs. It sets the state inherited assertions read: `fx`, `face`, `seUT`, `faceDec`, `rejectBytes`, `faceIdx`, `otherIdx`, the fixture array, and the leg decimals. It does not call the behavior's non-virtual `_bindRowHandles()`.

Mixed-leg and variable-count rows override every inherited public test that reaches a non-virtual helper fixed to the old leg count or to an all-fixture layout. That includes every public test that calls `_seed`, `_joinBoth`, `_joinAll`, or `_amounts` on the weighted 3-leg row and on both Balancer rows. Those helpers stay non-virtual. Do not edit them and do not make them virtual. The row's own seed builds a runtime-length amount array, funds the V4 face through the V4 fixture, mints each raw token, and transfers pre-acquired PairToken shares. It joins only that row's leg count. Curve stays at four legs, so it does not need a length override. It still overrides tests that assume four converting fixtures, and it funds the PairToken leg and the raw legs by role.

Common adaptation, every topology.

- Direct `previewExchangeOut` on this vault returns zero. Assert that on the vault.
- An enabled `exchangeOut` on this vault reverts `ExchangeOutNotAvailable()`. Assert that on the vault.
- `test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed` and `test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly` expect the hook call to revert and pay neither token. A zero vault preview is not a pass for those hook tests. The hook revert is not a pass for the direct preview assertion.
- The exact-out half of `test_row_poolManagerSwap_bothDirections_noFaceResidual` reverts and pays neither token. The exact-in half stays.
- Do not call `_mintSeSharesTo`. It uses `exchangeOut`. Seed shares with exact-input `exchangeIn`.
- In `test_row_previewMatchesExecution`, the `previewExchangeOut` equality cannot pass as a positive quote. The exact-in `previewExchangeIn` equality stays and reads `amountOut`.

`test_row_partialConsumption_bookedNotRefunded` is overridden. The inherited booked-not-refunded body does not run. `hasPartialCase()` false is not a way to skip the override. The override has two assertions. A fully consumed exact-input call has `amountRefunded == 0`. That is the no-refund control. It is not a donation case. A call the vault cannot fully consume refunds `amountRefunded` to `msg.sender`. When the hook calls `exchangeIn`, `msg.sender` is the hook. Assert the hook's balance of the input token increases by `amountRefunded`. Do not require the swapper's balance to increase by that amount. Do not count the hook increase as vault booked inventory.

Donation and compound remainders are booked in `Money.t.sol`. None of these seven behavior files contains `donate` or `compound`. Do not delete a booked-remainder assertion that is not in the file. Do not call `donate` or `compound` inside the outer unlock. Do not use the user's unspent input as that remainder.

`test_row_seFailure_rollsBack` cannot use the V3 `pool.mint` mock. The row overrides it. Force `AmountOutNotMet` on an exact-input call whose minimum is above the quote. Assert shares, face balances, and the vault's face balance unchanged.

One-word `previewExchangeIn` or `exchangeIn` comparisons in the seven behavior files may be changed only to read `amountOut` when the migration below lists that read. Do not change the expected amount. If the ABI decoder already ignores the trailing refund word, leave the comparison. The row's own new assertions decode the tuple.

Disjoint PoolKey rule, every topology. The hook product PoolKey and this vault's backing PoolKey are different keys. The backing key has hook `address(0)`. Where the currency1 test builds a second hook pool, that pool is a second product PoolKey, it holds the same vault, and it is not the backing PoolKey. PairToken's backing pool is not this vault's backing PoolKey. Same-backing-pool sequential composition stays unverified. These rows do not pass it.

The canonical cross-vault proof is the `dual/` row below. A PairToken leg on another topology does not replace it. `single/` is not a two-vault proof.

### Single

Behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol`

Row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`

The single package has no rate-provider field. The row does not add one. There is no currency1 hook row on this topology. FS-OWN-29's both-target proof is not this row. This row does not override `setUp`.

The PoolKey is the address-sorted pair of the face and this vault's share. `index(share)` is 0 when the share is the lower address, otherwise 1. The face is the other index. There is no raw leg and no second SE leg.

Exact-input face to share mints while unlocked. Exact-input share to face burns while unlocked. Those two calls are `zeroForOne` and `oneForZero`. Exact-out is not a direction. This vault is the only SE.

### Constant-product single

Behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol`

Row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`

This row does not override `setUp`. The fixture supplies one raw 18-decimal token that is neither face and is not this vault's share. Primary setup binds the `currency0` face as `pairToken` and the `currency0` provider as `rateProvider`. `test_row_rateTarget_currency1` in this same file keeps the same vault, uses the `currency1` provider, and deploys a second hook pool whose pair token is `currency1`. That second pool is not a second vault.

Currencies are the face and the raw token, address-sorted. This vault's share is not a pool currency. The share-bearing index is the currency index of the face. `standardExchangeOf(face)` is this vault and that leg is buffered. The other index is the raw token. `standardExchangeOf(raw)` is `address(0)`. The face leg is the leg that converted. The raw leg is a transfer.

Exact-input face to raw, and exact-input raw to face, are both required. Exact-out is not a direction. This is not the two-vault proof. The two index cases in the index rule apply to this pair.

### Dual

Behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol`

Row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`

This is the canonical cross-vault proof. The row overrides `setUp` as stated above. `_deployRowHook` is not virtual. The row does not edit the behavior to make it virtual. It deploys through the same package factory with these arguments:

- Package index 0: this vault and its `currency0` face. This is the converting buffered leg. `rateProvider0` is the `currency0` provider.
- Package index 1: the PairToken identity record. `rateProvider1` is that record's provider, not this vault's `currency1` provider.

`test_row_rateTarget_currency1` in this same file keeps the same vault and the same PairToken record. It deploys a second hook pool. This vault's face on that pool is `currency1`. `rateProvider0` is the `currency1` provider. The two hook pools are the two FS-OWN-29 pools. They are not the two index cases. The index rule still requires the face at product index 0 and at product index 1.

The hook pool currencies are the face and the PairToken share, address-sorted. This vault's share is not a pool currency. The share-bearing index is the currency index of this vault's face. The other index is the PairToken share.

Exact-input `zeroForOne` and `oneForZero` are both required. One direction mints this vault's shares while the manager is unlocked. The reverse burns them. Assert balances, position owner, ticks, salt, and per-address deltas. Assert PairToken `totalSupply` does not change by a mint or redeem during the hook transaction. Exact-out is not part of this row.

This row passes FS-A26 only when the PairToken identity record is accepted and executes without a PairToken money call, and the two backing PoolKeys differ. If that record is rejected, the row records FS-HOOK-04 and FS-A26 stays open. Inherited assertions that require leg 1 to be minted by a call cannot pass as conversion proofs. The row overrides those assertions. Leg 1's share balance changes only by transfer.

`test_row_identity_thisVault` in this same file attempts `token == this vault` on one leg. If the package rejects that bind without `asset()`, record the consumer, selector, arguments, and revert under FS-HOOK-04. Do not pass. Do not add `asset()`. This test is FS-A24. It is not the canonical FS-A26 proof.

### Orbital

Behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol`

Row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`

Three legs. The row overrides `setUp` and does not use the inherited three `_newFixture()` calls.

- Package index 0, `se0` / `token0` / `rp0`: this vault, converting buffered leg. Primary `token0` is the `currency0` face. Primary `rp0` is the `currency0` provider.
- Package index 1, `se1` / `token1` / `rp1`: the PairToken identity record.
- Package index 2, `se2` / `token2` / `rp2`: one raw 18-decimal token. `se2` is `address(0)`. `rp2` is `address(0)`.

`test_row_rateTarget_currency1` keeps the same vault. `token0` on that second hook is `currency1`. `rp0` is the `currency1` provider. Legs 1 and 2 stay the PairToken record and the raw token.

This vault's share is not a pair-key currency. The share-bearing leg is package index 0. Index 1 is the PairToken share. Index 2 is raw. The behavior builds `poolKey01`, `poolKey12`, and `poolKey02` at spacing 60. Run both exact-input directions on `poolKey01` and `poolKey02`. `poolKey12` is a transfer control. It is not a conversion of this vault. Use `standardExchange(uint8)` and `rateProvider(uint8)`. Do not invent `standardExchange0()` getters.

The two index cases apply to `poolKey01` and to `poolKey02`. Inherited assertions that all three legs are converting instances of this family cannot pass. The row overrides those checks. If the PairToken identity record is rejected, record FS-HOOK-04 for leg 1 and still run the raw-leg directions on `poolKey02`. That raw-leg result does not close FS-A26.

### Weighted

Behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol`

2-leg row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`

Owner instruction 2026-11-05: this file overrides `setUp`. It calls the weighted test base, then `_initializeWeighted(2)`. Do not delete that override to satisfy the older sentence that this file does not override `setUp`. The three-leg file remains the file that overrides `setUp` for `n == 3`. After ascending sort, the face index is this vault and is buffered. The other index is raw, `standardExchange == address(0)`, and is not buffered. Weights stay `0.5e18` and `0.5e18`, traveling with the sorted records. The primary provider is the `currency0` instance. `test_row_rateTarget_currency1` in this file keeps the same vault, uses a second hook pool, binds pair token `currency1`, uses the `currency1` provider, and leaves the raw leg unchanged. The two index cases apply to this pair.

3-leg row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol`

`n` is 3. This is the one larger supported setup. The row overrides `setUp` and does not use the 2-length constructor as this proof. After ascending sort of the whole record: the face index is this vault, buffered, `currency0` rate target, weight `0.5e18`; one index is the PairToken identity record, weight `0.25e18`; the remaining index is raw, weight `0.25e18`. The weights sum to `1e18`. This file does not repeat the currency1 pool. The 2-leg file holds the two rate-target pools.

This vault's share is not a pool currency. On the 3-leg file, run exact-input both ways on the face/raw pair and the face/PairToken pair. The raw leg is a transfer. The PairToken leg uses the identity record and is not asked to convert. If that record is rejected, record FS-HOOK-04 for that leg and still run the face/raw directions. That result does not close FS-A26. Override every inherited public test that calls `_seed`, `_joinBoth`, `_joinAll`, or `_amounts`, as stated above.

### Curve quad

Behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol`

Row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`

Four legs. Tokens are sorted ascending, as the package requires. The row overrides `setUp` and does not use the inherited four `_newFixture()` calls. Exactly one leg is this vault: the sorted index of its bound face. That index is the leg under test. It is not hard-coded to 0 unless that face is the lowest address. One other index is the PairToken identity record. The other two indices are two distinct raw tokens, `raw0` and `raw1`, in ascending address order. Do not treat this vault's share as a peg. Do not bind four instances of this vault.

The provider on this vault's leg is the `currency0` instance. The PairToken leg uses the identity record's provider. The raw legs use `address(0)`. `test_row_rateTarget_currency1` keeps the same vault. This vault's leg token on that second hook pool is `currency1`. The `currency1` provider is the provider on that leg. The other three legs stay the PairToken record and the two raw tokens.

This vault's share is not a pool currency. Exact-input both ways between this vault's face and the PairToken share, and both ways between this vault's face and `raw0`. `raw0` is the first raw token in the ascending sorted record. Do not bind those directions to `raw1`. Exact-out is not a direction. Any hook path that reaches `exchangeOut` on this vault is a negative, not a pass. A failed seed is not a passed row. Do not manufacture shares or patch the hook. If the PairToken identity record is rejected, record FS-HOOK-04 for that leg and still run the face/`raw0` directions. That result does not close FS-A26.

### Balancer quad

Behavior: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol`

Do not copy the fixed-four constructor. `LEGS` is 4. `_buildLegs` reverts above 4. `_rowPkgArgs` builds `address[4]`. Overriding `_seLegCount()` to 2 still deploys that four-token constructor. These rows do not call `_buildLegs` or `_rowPkgArgs`. They also do not call `_seed`, `_joinBoth`, `_joinAll`, or `_amounts`. Those helpers allocate length 4 and are not virtual. The row overrides every inherited public test that calls them and seeds with a runtime-length array, as stated above.

2-leg row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`

The row overrides `setUp` and deploys through the package's dynamic arrays of length 2. After ascending sort, the face index is this vault, buffered, converting, `currency0` rate target. The other index is raw, `standardExchange == address(0)`, not buffered. No other SE is on this pool. `test_row_rateTarget_currency1` keeps the same vault, uses a second hook pool, binds this vault's leg token to `currency1`, uses the `currency1` provider, and leaves the other leg raw. The two index cases apply to this pair. `test_row_bind_deploysThroughPackage` asserts `numTokens() == 2`.

5-leg row: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.t.sol`

The row overrides `setUp` and deploys through the package's dynamic arrays of length 5. After ascending sort: the face index is this vault, converting, `currency0` rate target; one index is the PairToken identity record; the other three indices are raw. `test_row_bind_deploysThroughPackage` asserts `numTokens() == 5`. This file does not repeat the currency1 pool. The 2-leg file holds the two rate-target pools.

This vault's share is not a pool currency. On the 5-leg row, run exact-input both ways between this vault's face and the PairToken share, and both ways between this vault's face and the first raw token in the ascending sorted record. Do not bind those raw directions to either of the other two raw tokens. If the PairToken identity record is rejected, record FS-HOOK-04 for that leg and still run the face/first-raw directions. That result does not close FS-A26. A seed or join path that reaches `exchangeOut` is an `ExchangeOutNotAvailable` record with unchanged balances. It is not a pass.

### Migration

Migrate every one-word reader of `previewExchangeIn` listed in `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md` to `(uint256 amountOut, uint256 amountRefunded)`. Also migrate every one-word decoder of `exchangeIn`, including implementations, overrides, typed ignored-return callers, low-level decoders, the six length gates, the three ABI bindings, helpers, tests, scripts, and generated ABI artifacts. Do not paste the index. Consumers that value the result use `amountOut`, not the refund word. The migration must compile repo-wide. Known production assignments that will not compile against the widened return are `UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol` and `ComposedStableCommonDetfCommon.sol`. Those two lines are examples, not the whole set.

A one-word comparison inside the seven behavior files is in that migration only when the index lists it. The change reads `amountOut` and does not change another family's expected amount. If the ABI decoder already ignores the trailing refund word, leave that comparison.

Preserve all current V3 matrix rows. Replace stale historical V4 FullSpread evidence only with results from the newly named V4 rows. The evidence destinations are `docs/audits/apex-2026-09-17-evidence/hook-se-matrix.json`, `hook-se-matrix-findings.json`, `hook-se-matrix-finding-descriptions.json`, `docs/audits/apex-2026-09-17-evidence.md`, and `docs/audits/apex-2026-09-17-evidence/acceptance.json` item R10.3. Neither the historical compatibility label nor the existence of this matrix is runtime evidence.

## 13. Test plan

Extend `IndexedexTest` and the current native-wrapper base. Deploy facets and the package through the factory and manager paths. Build production artifacts before the tests, because FactoryServices read creation bytecode from `out/`. Bootstrap shares only through the accepted public routes. Do not mock, etch, or inject storage into this vault or the PoolManager. Hermetic tests use `forge test --use solar`. `via_ir` is forbidden.

| Assertion | File |
| --- | --- |
| FS-A01 to FS-A04, FS-A16, package cut, permit domain | `Package.t.sol` |
| FS-A05 to FS-A08, FS-A11, FS-A39, standalone gas for the seven economic money and maintenance routes | `Money.t.sol` |
| FS-A09, FS-A12 to FS-A15 as withdrawn rows, FS-A32, preview gas | `QuotesAndRate.t.sol` |
| FS-A10, FS-A35, native boundary | `Native.t.sol` |
| FS-A17, FS-A18 | `Callbacks.t.sol` |
| FS-A19 to FS-A23, FS-A33, FS-A34, FS-A36, FS-A37 | `AlreadyUnlocked.t.sol` |
| FS-A24 | the dual row file in section 12, `test_row_identity_thisVault` |
| FS-A25 to FS-A30, FS-A38, composed gas | `BufferHookIntegration.t.sol` and the row files named in section 12 |
| FS-A31 standalone body | `Money.t.sol` |
| FS-A31 preview ceiling | `QuotesAndRate.t.sol` |
| FS-A31 composed transaction | `BufferHookIntegration.t.sol` |

FS-A12 through FS-A15 stay withdrawn. They are not ordinary rate tests. FS-A38 and inventory row 045 use the same files: `Money.t.sol` for the vault-level disable matrix, and `BufferHookIntegration.t.sol` for the buffered hook cases.

Owner instruction 2026-11-05: `getRate` and `exchangeRate` are not components of this vault. They were left over from an earlier design. Do not add or keep an `exchangeRate` test. Do not add a test whose only point is that issuance does not read `exchangeRate`. Rate rows use `IStandardExchangeRateProvider` from `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/`. FS-A16's `exchangeRate` half is not a test requirement. `getRate` stays uninstalled. That absence is not a new `exchangeRate` test.

Owner instruction 2026-11-05, amended when the gas list was named: every supported economic money and maintenance route has a gas test. A sampled route is not coverage. The count of six is withdrawn. The standalone routes are `exchangeIn` one-sided share mint, `exchangeIn` one-token exit, `exchangeIn` pass-through, `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound`. `setOperator` and `setOperatorFor` are not in this set. Each section 12 row this plan names is a supported composed route and has its own composed measurement. The ceilings in section 2 stay. The measurement shows whether that route can be included in a mainnet transaction under that ceiling. An oversized route is unresolved, not passed.

Audit inventory. A `no` row is an exclusion record. Do not reproduce the excluded mechanism.

| ID | Mark | File | Assert |
| --- | --- | --- | --- |
| 010 | yes | Money | A direct transfer is not redeemable idle or caller credit. |
| 011 | yes | Money and AlreadyUnlocked | Neither path over-mints. |
| 012 | no | Package | Wings liquidation-quote pricing is absent. |
| 013 | yes | Package | ERC-4626 `deposit` and `asset` are absent. A pre-existing balance does not mint shares. |
| 014 | integration only | BufferHookIntegration | Do not count the matrix row as a vault fix. |
| 015 | integration only | BufferHookIntegration | Curve quad accounting is hook code. |
| 016 | no | Package | Weighted partial-book dust seed is hook code. |
| 017 | no | Package | Balancer caller-supplied router callback is absent. |
| 018 | no | Package | Balancer `computeBalance` is absent. |
| 019 | yes, negative | QuotesAndRate, enabled vault | `exchangeOut` reverts `ExchangeOutNotAvailable`. |
| 020 | no | Package | DETF mint and bond pricing is absent. |
| 021 | no | Package | Balancer DETF bond pricing is absent. |
| 022 | yes | Money and AlreadyUnlocked | Same borrowed-path loop as 011. |
| 023 | yes | Money | No permissionless sleeve placement. Do not claim an authorized sandwich is gone. |
| 024 | yes | Money and AlreadyUnlocked | One-token exit swaps the FS-OWN-30 exiting claim only, on both unlock paths. |
| 025 | no | Package | Wings rebalance and loss cap are absent. |
| 026 | no separate Wings test | QuotesAndRate | Dust-tick liveness is 041. Do not reopen spacing. |
| 027 | no | Package | Staking withdrawal queues are absent. |
| 028 | yes | BufferHookIntegration | An identity-leg attempt does not burn the caller's position and pay zero. |
| 029 | yes, negative | Package and BufferHookIntegration | `getRate` is absent. The external provider reads the tuple. |
| 030 | integration only | BufferHookIntegration | Balancer quad phantom fee LP is pool code. |
| 031 | no | Package | Balancer virtual-TTA join is absent. |
| 032 | yes | Package | No unprivileged post-deploy selector remains. |
| 033 | no | Package | DETF primary redemption is absent. |
| 034 | yes | Money | Direct transfers and the 1,000-share floor prevent first-deposit inflation. |
| 035 | no | Package | Aave cross-version loop is absent. |
| 036 | yes | Money and BufferHookIntegration | A staged pretransfer is not credited to a later caller, including through a hook. |
| 037 | no | Package | Re-enabling a named frozen legacy vault is absent. |
| 038 | no | Package | sDETF staking weights are absent. |
| 039 | yes | Money | Pretransfer uses available unbooked balance up to the maximum. A bundle over-max reverts with no new error. |
| 040 | yes | Money | A pool donation followed by `compound` does not round a later deposit to dust shares. |
| 041 | yes | Money and QuotesAndRate | Dust ticks do not freeze a normal deposit and redeem through an undocumented cap. |
| 042 | yes | Package | A token whose `approve` returns no bool can be used. |
| 043 | integration only | BufferHookIntegration | Orbital radius pinning is hook code. |
| 044 | yes | Money and QuotesAndRate | Fee shares come out of the new shares. Clamp at 30%. No extra mint. A round trip does not move existing holders' value to `feeTo`. Previews and minima use net shares. `1e13` precision holds. |
| 045 | yes | Money and BufferHookIntegration | The section 6 disable predicate, including deadline before disable. |
| 046 | no | Package | Balancer composite-router settlement is absent. |
| 047 | no | Package | Stata one-wei donation freeze is absent. The nearest vault case is 040. |
| 048 | yes | Money | Empty `compound` emits nothing. A qualifying deposit emits `Compounded()` with no arguments. Every successful `donate()` emits `Donation()` with no arguments. A booked remainder does not freeze a later route. |
| 049 | yes, negative | QuotesAndRate, enabled vault | Exact-out is absent. |
| 050 | no | Package | Do not add the truncated TWAP oracle. |
| 051 | yes | Money and QuotesAndRate | A preview amount is not rejected by a check execution does not run. |
| 052 | yes | Package | `permit` works. Domain name is `PkgArgs.name`. Version is `"1"`. |
| 053 | no | Package | Crane ownership-transfer buffering is not changed here. |
| 054 | yes | BufferHookIntegration | Each required unwrap hook approves the vault and completes the exit. |

## 14. Implementation names

Each line is a name, not a new requirement.

| Item | Name |
| --- | --- |
| Six architecture fields | `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, `universalRouter` |
| Crane facet fields | `uniswapV4ProtocolAwareFacet`, `uniswapV4SinglePositionAwareFacet` |
| Basic facet field | `basicVaultFacet`, value is `MultiAssetBasicVaultFacet` |
| Owner modifier | `UniswapV4FullSpreadStandardExchangeVaultOwnerModifiers.sol`, `onlyLiveFeeToOwner` |
| Maintenance modifier | `UniswapV4FullSpreadStandardExchangeVaultMaintenanceModifiers.sol`, `onlyLiveFeeToOwnerOrOperator` |
| Storage namespace | `indexedex.vaults.standard.exchange.uniswap.v4.fullSpread` |
| Booked and reserved layout | `uint256[2]` in `vaultTokens()` order |
| SwapProjection file | separate file; unbounded exact-input swap only |
| ExecutionPreparation file | separate file; per-action payload commitment and that action's settlement preparation |
| Math | FS-OWN-33 amount selection |
| Quote engine | `UniswapV4FullSpreadStandardExchangeVaultPlanner` |
| Temporary-hook facet | `PostDeployAccountHookFacet` |
| Salt getter | `positionSalt()` |
| EIP-712 version | `"1"` |
| Appointment home | money facet |
| Maintenance failure | existing `IOperable.NotOperator(address)` |
| Unnamed borrowed checks | bare `revert()` |
| Matrix adapter | `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol` |

## 15. Traceability

| Requirement | Section |
| --- | --- |
| FS-OWN-01, FS-OWN-02, FS-OWN-06, FS-OWN-16, FS-OWN-18 | 3, 4, 5 |
| FS-OWN-03, FS-OWN-05, FS-OWN-29, FS-RATE-01 | 5, 10, 12 |
| FS-OWN-04, FS-OWN-12 | 9 |
| FS-OWN-07, FS-OWN-19, FS-OWN-23 | 4, 5, 10 |
| FS-OWN-08, FS-OWN-09, FS-OWN-10 | 5, 6, 9, 12 |
| FS-OWN-11, FS-OWN-24, FS-OWN-27 | 4, 9 |
| FS-OWN-13 | 6, 8, 13 |
| FS-OWN-14, FS-OWN-21 | 9, 11 |
| FS-OWN-15, FS-OWN-30, FS-OWN-31, FS-OWN-33 | 2, 9 |
| FS-OWN-17 | 5, 13 Native |
| FS-OWN-20, FS-OWN-32 | 4, 6, 7 |
| FS-OWN-22, FS-OWN-25, FS-OWN-26, FS-OWN-28 | 6, 9, 11 |
| FS-FACET-01, FS-FACET-02, FS-ARCH-01, FS-PKG-01, FS-PKG-02 | 3, 4, 5 |
| FS-MONEY-01, FS-UNLOCK-01, FS-UNLOCK-02, FS-UNLOCK-03 | 8, 9 |
| FS-HOOK-01 through FS-HOOK-04 | 12 |
| FS-TEST-01 through FS-TEST-04, FS-A01 through FS-A39 | 13 |

## 16. Owner answers, 2026-11-05

These sentences resolve council questions on `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`. They do not, by themselves, authorize implementation.

1. The six infrastructure bindings in section 4 are components. Check each for code. Revert `InvalidComponent` if none is present.
2. The weighted two-leg row overrides `setUp`, as section 12 now says. The older prohibition is withdrawn.
3. The one-token exit minimum is the recipient receipt: swap proceeds, withdrawn requested-token principal, requested-token fee portion, and requested booked claim.
4. The one-sided swap is 49% of the processed input when the price is strictly inside the position. Do not iterate. Do not solve a closed-form root. If the price is not strictly inside the position, do not swap. A donate or compound books the dust and does not refund it.
5. Do not test `exchangeRate`. Rate tests use `IStandardExchangeRateProvider`.
6. Gas tests cover the seven standalone economic routes named in section 13, plus each section 12 row, so a later reader can see whether the route fits a mainnet transaction under the section 2 ceilings.
