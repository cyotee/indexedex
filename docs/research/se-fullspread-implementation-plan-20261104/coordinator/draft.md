# Draft implementation and testing plan

- Draft ID: draft-se-fullspread-implementation-plan-20261104-r1
- Path: docs/research/se-fullspread-implementation-plan-20261104/coordinator/draft.md
- Run ID: se-fullspread-implementation-plan-20261104
- Status: coordinator draft, pending advisory review
- This draft is not an implementation and does not authorize one.

## Coordinator merge notes

The four originals were read. Agreement is not a vote and is not correctness. Where the originals named the same implementation identifier, this draft uses it. Where they split, this draft picks one name and records the others as not adopted.

Adopted from all four, or from three:

- Architecture `PkgInit` fields: `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, `universalRouter`.
- Crane facet fields: `uniswapV4ProtocolAwareFacet`, `uniswapV4SinglePositionAwareFacet`.
- Temporary-hook filename: `PostDeployAccountHookFacet`, cited from `lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol` line 31. The coordinator read that import.
- EIP-712 domain name is `PkgArgs.name`. Version string is `"1"`.
- Empty marker events `Donation()` and `Compounded()`. No Donation interface.
- Pass-through is an exact-input pool swap at the unbounded price limit, not the FS-OWN-33 shape.
- A planned manager action is one `swap` or one `modifyLiquidity`.

Not adopted:

- Astra's namespace spelling `fullspread`. This draft uses `fullSpread`, the spelling used by Grok, MiniMax, and Kimi, matching the family directory.
- Grok's extra `PkgInit` field `operableFacet` and the rename of `basicVaultFacet` to `multiAssetBasicVaultFacet`. The PRD table already names `basicVaultFacet`. The address stored there is `MultiAssetBasicVaultFacet`. Appointment selectors live on the money facet, as Astra and MiniMax placed them. The stock `OperableFacet` is not installed.
- Kimi's and Astra's placement of FS-OWN-33 sizing inside `SwapProjection`. This draft puts the unbounded exact-input swap in `SwapProjection` and the FS-OWN-33 amount selection in `Math`, as Grok separated them, so a pass-through cannot call the liquidity-targeting shape by using the swap library.
- Grok's quote-engine name `FullSpreadOperationQuote` and MiniMax's use of `SwapProjection` as the quote engine. This draft uses `UniswapV4FullSpreadStandardExchangeVaultPlanner`, the name chosen by Astra and Kimi. The stored Quoter, State View, and Reserves Lens are not called. That constraint is MiniMax's, and it is adopted.
- Modifier filenames differed. This draft uses `UniswapV4FullSpreadStandardExchangeVaultOwnerModifiers.sol` with `onlyLiveFeeToOwner`, and `UniswapV4FullSpreadStandardExchangeVaultMaintenanceModifiers.sol` with `onlyLiveFeeToOwnerOrOperator`.

Reading submitted for advisory check, not as a new product rule: a one-token pretransfer whose declared maximum exceeds the unbooked balance succeeds, spends nothing, pulls nothing, refunds that unbooked balance, and returns a zero output with that refund. A bundle in the same condition reverts before any leg and does not add an error. That is the literal text of FS-OWN-32 and the 2026-11-03 F1 override. MiniMax stated it as assumption A1. The other originals did not contradict that sentence.

## 1. Authority

This plan does not authorize implementation, tests, installs, deployment, or Git. It specifies how to build and test `UniswapV4FullSpreadStandardExchangeVault` from the current PRD. A later owner instruction is required before any of that work starts.

## 2. Sources and precedence

Operative requirements: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`.

A dated 2026-11-04 lock in that file and in `IMPLEMENTATION_PLAN_BLOCKERS.md` wins over an older sentence. Status lines that say the PRD has not been edited are not locks. `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md` is not an economics source. The November 1 plan-readiness report is provenance. FS-TEST-04 wins over its "expected result blocked" cells.

Also binding, where the PRD says so:

- `docs/vaults/PRETRANSFER_DIRECTIVE.md`
- `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md` for the accepted return ABI
- `docs/research/se-fullspread-preview-consumers-20261103/REPORT.md` and `INDEX.md` for the 64-byte preview migration
- Crane architecture, IndexedEx testing law, and the compiler rule in `CLAUDE.md`

## 3. Adopted readings

- A pass-through is an exact-input swap of the declared input on the bound hookless pool. The price limit is `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`. It mints no shares, takes no usage fee, and does not call `modifyLiquidity`. Unused input is refunded under FS-OWN-32.
- FS-OWN-33 applies only to a one-sided share mint and to a one-token `donate` or `compound`.
- A planned manager action is one `swap` or one `modifyLiquidity`, not one public call. A one-sided deposit that swaps and then adds liquidity opens two unlocks in the same call. The vault settles the first action and does not make an external call before the second, other than that settlement.
- Gas ceilings stay 12,000,000 for a transaction and 5,000,000 for a preview. The meter copied from the stage-one ceiling that the PRD says stays is 11,900,000 measured call body plus 100,000 overhead. A composed hook route is judged on the whole transaction under 12,000,000. An oversized route is unresolved, not passed.
- `Donation()` and `Compounded()` have no arguments. They are marker events. Do not add a Donation interface or an ERC-165 id for it.
- The live `feeTo()` address is the owner. That owner appoints global operators with `setOperator(address,bool)` and function operators with `setOperatorFor(bytes4,address,bool)`. Maintenance admits the live owner, a global operator, or a function operator for `msg.sig`.
- Disable blocks every execution route except a withdrawal, `donate`, and `compound`. A missed deadline reverts `DeadlineExceeded` before the disable check.

## 4. File map

Family root: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`.

Production files:

- `interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol`
- `interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol`
- `UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol`
- `UniswapV4FullSpreadStandardExchangeVaultComponent_FactoryService.sol`
- `UniswapV4FullSpreadStandardExchangeVaultComponentBindings.sol`
- `UniswapV4FullSpreadStandardExchangeVaultTypes.sol`
- `UniswapV4FullSpreadStandardExchangeVaultRepo.sol`
- `UniswapV4FullSpreadStandardExchangeVaultMath.sol`
- `UniswapV4FullSpreadStandardExchangeVaultProjection.sol`
- `UniswapV4FullSpreadStandardExchangeVaultSwapProjection.sol`
- `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol`
- `UniswapV4FullSpreadStandardExchangeVaultExecution.sol`
- `UniswapV4FullSpreadStandardExchangeVaultExecutionPreparation.sol`
- `UniswapV4FullSpreadStandardExchangeVaultOwnerModifiers.sol`
- `UniswapV4FullSpreadStandardExchangeVaultMaintenanceModifiers.sol`
- one facet and one target for money, quote, out, query, and callback. Target names use the full prefix, for example `UniswapV4FullSpreadStandardExchangeVaultMoneyTarget.sol`. Do not create SY facet files.

Crane, not inside the family directory:

- `lib/crane/contracts/protocols/dexes/uniswap/v4/aware/` for the Protocol Aware repo and facet and for `UniswapV4SinglePositionAware` repo and facet.
- Crane tests for both pairs live in Crane.

Tests:

- `TestBase_UniswapV4FullSpreadStandardExchangeVault.sol` under the family's `test/bases/`.
- Specs under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`, using the seven filenames in FS-TEST-02.

Do not edit PairToken or Wings to host this family.

## 5. Package, initialization, and validation

`PkgInit` and `PkgArgs` are declared on the package interface, not on the contract.

`PkgInit` binding order. Names the PRD left open are implementation names.

1. `erc20Facet`
2. `erc2612Facet`
3. `erc5267Facet`
4. `basicVaultFacet`, whose address is `MultiAssetBasicVaultFacet`. The cut installs only `vaultTokens` from it.
5. `standardVaultFacet`
6. `moneyFacet`
7. `quoteFacet`
8. `outFacet`
9. `queryFacet`
10. `callbackFacet`
11. `uniswapV4ProtocolAwareFacet`
12. `uniswapV4SinglePositionAwareFacet`
13. `poolManager`
14. `positionDescriptor`
15. `positionManager`
16. `quoter`
17. `stateView`
18. `reservesLens`
19. `universalRouter`
20. `registry`
21. `oracle`
22. `weth`
23. `diamondFactory`
24. `linkedLibraries` as `address[6]`: Math, Projection, SwapProjection, Planner, Execution, ExecutionPreparation

No `syMoneyFacet`, `syQueryFacet`, `wrappedNative`, `operableFacet`, or `rateAsset`.

`PkgArgs`: `PoolKey poolKey`, `string name`, `string symbol`. No zap caps and no hook allowlist.

`bindingHash` covers every `PkgInit` field. `calcSalt` and `processArgs` run by delegatecall. `deployVault` goes through the bound IndexedEx vault registry. Tests deploy the PoolManager through the current artifact-backed CREATE3 helper. The hook under test binds that same manager.

`processArgs` reverts `NotCalledByRegistry` unless `msg.sender` is the bound registry and `address(this)` is the bound `diamondFactory`.

Reject, with no partial diamond:

- Missing or code-empty component, linked-component hash mismatch, or a cut that installs `getRate` or `rateAsset`. `InvalidComponent`.
- Pool key not initialized on the bound manager, or hook not `address(0)`. `InvalidPoolKey`. Do not reject tick spacing or an inherited domain.
- Wrong `processArgs` caller. `NotCalledByRegistry`.
- Proxy initialization that does not match the bound package and arguments. `InvalidInitializationContext`.
- A second initialization. `AlreadyInitialized`.

Initialization writes the seven architecture addresses into the Protocol Aware repo, writes `weth` through `WETHAwareRepo._setWeth`, stores the pool key, full-range ticks, and salt `bytes32(0)` in `UniswapV4SinglePositionAware`, and sets name, symbol, and 18 decimals. It does not store `feeTo()` as an ownable owner. The first depositor creates the position. Genesis follows FS-MONEY-01 and FS-OWN-24. The floor mint calls `ERC20Repo._mint`, which writes `balanceOf` and `totalSupply` directly.

## 6. Storage

Family slot: `keccak256(abi.encode("indexedex.vaults.standard.exchange.uniswap.v4.fullSpread")) - 1`. It must not equal the PairToken slot or the Wings slot.

Family storage, implementation layout, not a new economic rule:

- `uint256[2] booked`, in `vaultTokens()` order. This is the only local booked ledger. There is no fee-origin store.
- Callback hash, reservations, and the public-operation guard used by FS-UNLOCK-02 and FS-UNLOCK-03.

Unbooked balance of a vault token is `token.balanceOf(address(this)) - booked[token]`. A booked remainder is not a reserve and is not pretransfer credit. `reserves()` and `reserveOfToken` do not add this local term.

Position storage stays in `UniswapV4SinglePositionAware`: full `PoolKey`, `tickLower`, `tickUpper`, and salt. Protocol addresses stay in the Protocol Aware repo as package immutables written once at instance initialization. No second per-vault copy.

## 7. Selector cut

Install only the selectors the PRD names. Do not install `getRate`, `rateAsset`, `poolManager`, a family-only `poolKey`, `basket`, `wrappedNative`, `localReserves`, `asset`, `depositPair`, `redeemPair`, the paired previews, `previewZapCredit`, `previewWithdrawalMode`, or any Standardized Yield selector.

Money facet: `exchangeIn` `0xd02d3063`, `exchangeBundleInForSingleOut` `0xe7886166`, `exchangeBundleOut` `0x11993461`, `donate`, `compound`, `setOperator` `0x558a7297`, `setOperatorFor` `0x755dbe7c`. The appointment selectors are placed here so they can use `onlyLiveFeeToOwner`. Recheck `donate` and `compound` selectors from the signatures in FS-OWN-21. Do not invent other selector hex.

Quote facet: `previewExchangeIn` `0x89d61912`, `previewExchangeBundleInForSingleOut` `0xc2fe8c7c`, `previewExchangeBundleOut` `0xa5952fc2`. `previewExchangeIn` returns `(uint256,uint256)`.

Out facet: `previewExchangeOut` `0xdb149bc5`, `exchangeOut` `0x612d4427`. No refund word.

Query facet: no family selector. Protocol and position getters are the Crane facets.

Callback facet: `unlockCallback`.

`vaultTokens` is `MultiAssetBasicVaultFacet`. `reserveOfToken` and `reserves` are the family facet. `positionLiquidity`, `tickLower`, `tickUpper`, and `positionSalt` are `UniswapV4SinglePositionAware`.

ERC-165 for `IStandardExchangeIn` is `0x59fb2971`. Do not advertise `0x8c8035da` or `0x676ec907`. Recheck the bundle interface ids with `type(I).interfaceId` before registration. The accepted report's values are `0x2576ed1a` and `0xb40c1ba3`.

Factory-installed ERC-165, ERC-8109, loupe, and `PostDeployAccountHookFacet` stay off `PkgInit` and off the package cut. They remain callable where the factory installs them.

## 8. Check order

On every route that takes `deadline`, a missed deadline reverts `IStandardExchangeErrors.DeadlineExceeded(deadline, block.timestamp)` before any other work, including the disable check.

Disable, after the deadline check, reverts `VaultDisabled(address(this))` unless the route is a withdrawal, `donate`, or `compound`. A withdrawal is `exchangeIn` with the share as `tokenIn`, or `exchangeBundleOut` with the share as `tokenIn` and `tokensOut` exactly the two `vaultTokens()` faces in either caller order. A pass-through is not a withdrawal. A disabled `exchangeOut` reverts `VaultDisabled`, not `ExchangeOutNotAvailable`. The same predicate applies on a borrowed unlock.

Then, for `exchangeIn`:

1. `tokenIn == tokenOut` reverts `InvalidRoute`.
2. `amountIn == 0` reverts `EmptyExchange`.
3. A token of `address(0)`, or a token that is neither the share nor a `vaultTokens()` entry, reverts `TokenNotExchangeable`.
4. `recipient` of `address(0)` or this vault reverts `InvalidRecipient`.
5. Read `TransientStateLibrary.isUnlocked`. Locked follows section 11. Unlocked follows the borrowed path. `isUnlocked` is not authority.

`donate` and `compound` have no deadline and no disable check. The three-arm maintenance modifier runs before any swap or liquidity change. `donate` reverts when `totalSupply` is zero, before any swap.

`exchangeOut` on an enabled vault reverts `ExchangeOutNotAvailable()` and moves no tokens. `previewExchangeOut` returns zero and does not revert.

Views do not revert by a vault error. An unsupported view route returns zero.

## 9. Money routes

One-sided deposit. `tokenIn` is one underlying and `tokenOut` is the share. Pull or use the pretransfer under FS-OWN-32. Run the FS-OWN-33 sizing in `Math`. Swap through `SwapProjection` at the unbounded limit. Add the resulting liquidity in a second planned action. On the first deposit, reject added liquidity less than or equal to `1_000` with `MinLiquidityNotMet()`. `grossShares` is `added liquidity - 1_000` on the first deposit and `added liquidity * totalSupply / existing liquidity` later. Take `feeShares = mulDiv(grossShares, clampedFee, 1e18)` from those shares. Mint `feeShares` to `feeTo` when nonzero and the rest to `recipient`. Skip a zero mint. Floor mint is a separate `ERC20Repo._mint` of `1_000` to `address(0)` and is not part of `grossShares`. Book `feesAccrued`. Do not swap those fees into the deposit. Refund unused declared input. Do not book that refund.

Bundle deposit. `tokenOut` is the share and `amountsIn` follows `vaultTokens()` order. If any pretransfer maximum exceeds that token's unbooked balance, revert before any leg, spend nothing, and mint nothing. Do not add an error. Otherwise add in proportion to the pool with `getLiquidityForAmounts`, refund the unused declared input, and do not run the one-sided swap. Fee, floor, and `feesAccrued` booking follow the one-sided rules. Emit `PairDeposited(address indexed caller)` with no other arguments.

One-token exit. `tokenIn` is the share and `tokenOut` is one underlying. Measure before the burn. Remove `liquidity * sharesBurned / supplyBeforeBurn`. The caller's fee claim is `floor(feesOwed * sharesBurned / supplyBeforeBurn)` and the booked claim is `floor(booked * sharesBurned / supplyBeforeBurn)`, multiplied before dividing. Pay the requested-token fee and booked claim to `recipient`. Swap all unwanted withdrawn principal plus the opposing fee and opposing booked claim at the unbounded limit, or revert `AmountOutNotMet` and do not burn. Do not pay, book, or keep that residual. Book the other holders' remainder. Do not swap their inventory.

Both-token exit. `exchangeBundleOut` with the share as `tokenIn` and the two faces as `tokensOut`, either order. Pay the same claim in both tokens. Do not swap. Emit `PairRedeemed(address indexed caller)`. A caller minimum fails with `MinAmountNotMetAt`. Do not declare `MinAmountNotMet`.

Pass-through. Both tokens are the two underlyings. Exact-input swap through `SwapProjection` at the unbounded limit. No share mint, no usage fee, no `modifyLiquidity`, no `feesAccrued` booking. Refund unused input.

One-token pretransfer shortfall. If the declared maximum exceeds the unbooked balance, spend nothing, pull nothing, refund that unbooked balance, and return zero output with that refund. Do not revert. A bundle in the same condition reverts before any leg.

## 10. donate and compound

Both use the three-arm modifier. `compound()` takes no arguments. `donate(address token, uint256 amount, bool pretransferred)` accepts one `vaultTokens()` entry or the share. A share donation burns the shares and does not withdraw or swap them. An underlying donation is deployed before return. A one-token maintenance call swaps the combined one-token booked-plus-fee-plus-donation balance with the FS-OWN-33 shape. If both tokens are already held, deposit the matched pair and do not swap. Book the actual held balance after the deposit. Do not refund a donation or compound remainder.

`compound()` with no fees and no booked remainder returns with no state change and no event. A successful `donate()` emits `Donation()` even when it deposits nothing. Emit `Compounded()` only when a deposit is made from collected fees or booked tokens. A reverting call emits neither.

## 11. Unlock paths

Locked path. For each planned action, commit `keccak256(abi.encode(operation, payload))`, call `unlock` once, accept `unlockCallback` only from the bound manager, only while the guard is held, and only once for that payload. Settle that action and require the manager to relock before the next action. Nested unlock and replay revert. The public-operation guard stays active across the plan. The callback does not call `compound()`. An external unlock does not satisfy a committed hash.

Borrowed path, only for canonical `exchangeIn`. Do not call `unlock` or `unlockCallback`. `pretransferred` must be false. The caller must have code and must pay the input. A reentrant borrowed entry reverts `ReentrantOperation`. A close that cannot settle this diamond's own deltas reverts `SettlementMismatch`. The initialized, idle, callback-hash, and reservation checks revert with a bare `revert()`. Do not use `ReentrantOperation` or `SettlementMismatch` for those four checks. Do not require the global nonzero-delta count to be zero. Settle only this diamond's touched deltas. `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` revert `ManagerAlreadyUnlocked` on this path.

## 12. Quotes and previews

`UniswapV4FullSpreadStandardExchangeVaultPlanner` is the one quote engine. Preview and execution both call it. It reads pool state. It does not call the stored Quoter, State View, or Reserves Lens. It has no step cap and no `QuoteWorkLimit`. A mint preview returns the depositor's net shares and does not credit existing fees. A one-token exit preview uses the same swap, so `amountOut` matches execution. Refund-word equality is not required. `previewExchangeOut` returns zero. No view reverts by a vault error, including while the manager is unlocked or disabled.

## 13. Events and errors

Events: `Donation()`, `Compounded()`, `PairDeposited(address indexed caller)`, `PairRedeemed(address indexed caller)`. No extra fields. PoolManager `Swap` and `ModifyLiquidity` carry amounts. `exchangeIn` adds no vault event.

Family errors: `InvalidUnlockedContext`, `SettlementMismatch`, `ManagerAlreadyUnlocked`, `ReentrantOperation`, `InvalidRoute`, `MinLiquidityNotMet`, `InvalidRecipient`. Maintenance failure uses the existing `IOperable.NotOperator(address)`. That is not a new family error. Do not declare `IncompleteConversion`, `QuoteWorkLimit`, `UnderlyingUnavailable` for an unpullable fraction, or the withdrawn rate errors.

## 14. Operators

`onlyLiveFeeToOwner` reads `VaultFeeOracleQueryFacet.feeTo()` on the bound oracle and compares `msg.sender` to that proxy address. `onlyLiveFeeToOwnerOrOperator` admits that address, a global operator in `OperableRepo`, or a function operator for `msg.sig`. Do not call `OperableModifiers.onlyOwnerOrOperator` or `MultiStepOwnableRepo._onlyOwner`. Do not store `feeTo()` at initialization.

`setOperator` and `setOperatorFor` sit on the money facet and use `onlyLiveFeeToOwner`. They write `OperableRepo`. A function operator for another selector cannot call `donate` or `compound`. A stranger reverts `NotOperator`.

## 15. Disable

After the deadline check, every execution route except a withdrawal, `donate`, and `compound` reverts `VaultDisabled(address(this))` when `IVaultRegistryDisableQuery.isDisabled(address(this))` is true. Views do not revert. A buffered withdrawal still succeeds. A buffered non-withdrawal reverts while the manager is unlocked. Run the enabled `exchangeOut` assertion on an enabled vault.

## 16. Hook integration and preview migration

Add a row for this vault beside the seven behavior contracts named in FS-TEST-04. Do not edit their assertions for other families. Exact-output success cannot pass. Unused user input is refunded. A donation or compound remainder is booked, so those rows stay.

The required cross-vault proof is FS-HOOK-02. FullSpread is the buffered leg. The hook is configured with an external `IStandardExchangeRateProviderDFPkg` instance for this vault and one rate target. Do not bind `getRate`. Required rows cover each underlying as `rateTarget`, and two pools that hold the same vault at different targets. An identity bind that the current hook rejects without `asset()` is an FS-HOOK-04 record, not a pass. Do not add `asset()`.

Migrate every one-word reader of `previewExchangeIn` listed in `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md` to `(uint256 amountOut, uint256 amountRefunded)`. Do not paste that index. The six 32-byte gates and three ABI bindings named in FS-OWN-08 are the minimum named set. Crane's `IStandardExchangeIn` return type changes with them. Do not advertise the old interface id.

## 17. Test plan

Harness: extend `IndexedexTest` and the current native-wrapper base. Deploy facets and the package through the factory and manager paths. Bootstrap shares only through the accepted public routes. Do not mock, etch, or inject storage into this vault or the PoolManager. Hermetic tests use the default profile and `forge test --use solar`. `via_ir` is forbidden.

Files: the seven FS-TEST-02 specs, plus Crane tests for the two aware pairs, plus one new row in each of the seven matrix behavior contracts.

Map:

- FS-A01 through FS-A04, FS-A16: `Package.t.sol`
- FS-A05 through FS-A08, FS-A11, FS-A39: `Money.t.sol`
- FS-A09, FS-A12 through FS-A15, FS-A32: `QuotesAndRate.t.sol`
- FS-A10, FS-A35: `Native.t.sol`
- FS-A17, FS-A18: `Callbacks.t.sol`
- FS-A19 through FS-A23, FS-A33, FS-A34, FS-A36, FS-A37: `AlreadyUnlocked.t.sol`
- FS-A24 through FS-A31, FS-A38: `BufferHookIntegration.t.sol` and the seven matrix rows

Audit inventory, copied from FS-TEST-04. Do not reopen a no row.

| ID | File | Expected result to assert |
| --- | --- | --- |
| 010 | Money | A direct transfer is not redeemable idle or caller credit. |
| 011, 022 | Money and AlreadyUnlocked | Borrowed and own-unlock entry and exit do not over-mint. |
| 012, 016, 017, 018, 020, 021, 025, 027, 031, 033, 035, 037, 038, 046, 047, 050, 053 | Package | The named mechanism is absent. No separate behavioral reproduction. |
| 013 | Package | ERC-4626 `deposit` and `asset` are absent. A pre-existing balance does not mint shares. |
| 014, 015, 030, 043 | BufferHookIntegration | Integration only. Do not count the matrix row as a vault fix. |
| 019, 049 | QuotesAndRate | Enabled vault. `exchangeOut` reverts `ExchangeOutNotAvailable`. |
| 023 | Money | No permissionless sleeve placement. An authorized `compound` sandwich is not claimed absent. |
| 024 | Money | One-token exit swaps the FS-OWN-30 exiting claim only. |
| 026 | QuotesAndRate | No separate Wings test. Dust-tick liveness is 041. |
| 028 | BufferHookIntegration | An identity-leg attempt does not burn the caller's position and pay zero. |
| 029 | Package and BufferHookIntegration | `getRate` is absent. The external provider reads the tuple. |
| 032 | Package | No unprivileged post-deploy selector remains. |
| 034 | Money | Direct transfers and the 1,000-share floor prevent first-deposit inflation. |
| 036 | AlreadyUnlocked | A staged pretransfer is not credited to a later caller. |
| 039 | Money | Pretransfer uses unbooked balance up to the maximum. A bundle over-max reverts with no new error. |
| 040 | Money | A pool donation followed by `compound` does not round a later deposit to dust shares. |
| 041 | QuotesAndRate | Dust ticks do not freeze a normal deposit and redeem through an undocumented cap. |
| 042 | Package | A token whose `approve` returns no bool can be used. |
| 044 | Money | Fee shares come out of the new shares. Clamp at 30%. No extra mint. |
| 045 | Money and BufferHookIntegration | Disable predicate in section 15. |
| 048 | Money | Empty `compound` is a no-op with no event. `Donation()` and `Compounded()` have no arguments. |
| 051 | QuotesAndRate | A preview amount is not rejected by a check execution does not run. |
| 052 | Package | `permit` works. Domain name is `PkgArgs.name`. Version is `"1"`. |
| 054 | BufferHookIntegration | Each required unwrap hook approves the vault and completes the exit. |

Gas. Measure the call body. A standalone route passes only if that body is at most 11,900,000, leaving 100,000 overhead under the 12,000,000 ceiling. A composed fixture passes only if the whole transaction, vault work plus hook work, is at most 12,000,000. Previews must fit 5,000,000. There is no `getRate` read in the measurement.

## 18. Traceability

| Requirement | Section |
| --- | --- |
| FS-OWN-01, FS-OWN-02, FS-OWN-06, FS-OWN-16, FS-OWN-18 | 4, 5, 7 |
| FS-OWN-03, FS-OWN-05, FS-OWN-29, FS-RATE-01 | 7, 12, 16 |
| FS-OWN-04, FS-OWN-12 | 9, 10 |
| FS-OWN-07, FS-OWN-19, FS-OWN-23 | 6, 7, 12 |
| FS-OWN-08, FS-OWN-09, FS-OWN-10 | 7, 9, 13 |
| FS-OWN-11, FS-OWN-24, FS-OWN-27 | 5, 9 |
| FS-OWN-14, FS-OWN-21 | 10, 14 |
| FS-OWN-15, FS-OWN-30, FS-OWN-31, FS-OWN-33 | 9, 11 |
| FS-OWN-17 | 5, 17 Native |
| FS-OWN-20, FS-OWN-32 | 6, 8, 9 |
| FS-OWN-22, FS-OWN-25, FS-OWN-26, FS-OWN-28 | 8, 9, 15 |
| FS-FACET-01, FS-FACET-02, FS-ARCH-01, FS-PKG-01, FS-PKG-02 | 4, 5, 7 |
| FS-MONEY-01, FS-UNLOCK-01, FS-UNLOCK-02, FS-UNLOCK-03 | 9, 11 |
| FS-HOOK-01 through FS-HOOK-04 | 16 |
| FS-TEST-01 through FS-TEST-04, FS-A01 through FS-A39 | 17 |

## 19. Implementation names

Each line is a name, not a new requirement.

| Item | Name |
| --- | --- |
| Six architecture fields | `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, `universalRouter` |
| Crane facet fields | `uniswapV4ProtocolAwareFacet`, `uniswapV4SinglePositionAwareFacet` |
| Basic facet field | `basicVaultFacet`, value is `MultiAssetBasicVaultFacet` |
| Owner modifier file and modifier | `UniswapV4FullSpreadStandardExchangeVaultOwnerModifiers.sol`, `onlyLiveFeeToOwner` |
| Maintenance modifier file and modifier | `UniswapV4FullSpreadStandardExchangeVaultMaintenanceModifiers.sol`, `onlyLiveFeeToOwnerOrOperator` |
| Storage namespace | `indexedex.vaults.standard.exchange.uniswap.v4.fullSpread` |
| Booked layout | `uint256[2] booked` in `vaultTokens()` order |
| SwapProjection | unbounded exact-input swap only |
| Math | FS-OWN-33 amount selection |
| ExecutionPreparation | per-action payload commitment and that action's settlement preparation |
| Quote engine | `UniswapV4FullSpreadStandardExchangeVaultPlanner` |
| Temporary-hook facet | `PostDeployAccountHookFacet` |
| Salt getter | `positionSalt()` |
| EIP-712 version | `"1"` |
| Appointment home | money facet |
| Maintenance failure | existing `IOperable.NotOperator(address)` |
| Unnamed borrowed checks | bare `revert()` |
