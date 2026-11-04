# Identity

- Member: astra
- Profile: research
- Phase: initial independent response
- Run: se-fullspread-prd-rewrite-20261103
- Owned path: members/astra/response.md
- Requested role: council-member
- Requested model: chatgpt-subscription/gpt-6-astra:high
- Actual runtime model, provider, account, reasoning setting, and role: not exposed
- Runtime ancestry and session identity: not exposed
- Peers read before submission: no

# Question and targets

What is the complete replacement text for the Uniswap V4 full-spread Standard Exchange vault PRD after applying every binding owner decision, with later overrides taking precedence?

The replacement is the whole text under Conclusions, from its document title through section 10. It retains the existing section order and requirement identifiers, including withdrawn identifiers that document absent surfaces. It does not edit the product PRD or authorize implementation.

# Evidence

All observations below are from admitted local documents. No public search, code inspection outside those documents, execution, or peer-original reading was performed.

| Source observation | Locator |
| --- | --- |
| The brief requires a complete replacement, not an amendment list; the members own only their response files. | `docs/research/se-fullspread-prd-rewrite-20261103/brief.md`, Authorization and Scope copied to every member |
| Later F1, F5, F6, F2, F7, and F12 overrides respectively settle overstated pretransfer maxima, one-sided sizing, complete one-token exit conversion, fee/booked apportioning, event emission, and live owner authority. | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md:17-39` |
| Fee shares are netted from gross newly minted shares, the applied fee is clamped at 30%, and pass-through swaps are exempt. | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md:60-84` |
| The sleeve is removed; entry and exit price limits remain unbounded; maintenance is restricted; batching with other V4 pools is allowed. | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md:88-116` |
| No-input compound is unchanged; positive supply with zero liquidity is unreachable; donation is restricted and rejects zero supply; views return computed values or zero, without coded vault reverts. | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md:118-170` |
| Both reusable aware facets are Crane inputs with Crane tests. Seven architecture addresses are package immutables; the complete pool key, ticks, and salt are instance storage. External rate-provider instances serve hook legs without a vault rate or provider registry. | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md:172-214` |
| Borrowed exits pull their position fraction directly. Share units are raw liquidity, not decimal-scaled. Booking and paired event signatures are settled. | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md:216-288` |
| The pretransfer rule excludes booked backing and parked shares. The quote rule introduces no step cap or spacing restriction. The wrapper argument is removed. The live integration matrix and audit regressions are required. | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md:290-412` |
| Pretransfer declares unbooked held input up to a caller maximum, refunds in that token, never pulls a shortfall, and forbids callers without bytecode. | `docs/vaults/PRETRANSFER_DIRECTIVE.md:3-15` |
| The current PRD supplies the retained structure, dispatch contract, package constraints, hook topology, gas ceilings, and FS-A01 through FS-A38. Its contradicted sentences require replacement throughout, not only in the owner section. | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md:1-451` |
| The consumer report names six fail-closed production sites and three one-word ABI bindings. The two sites in the ordinary rate-provider facet are counted separately. | `docs/research/se-fullspread-preview-consumers-20261103/REPORT.md:36-61` |
| The index records 1,626 occurrences in 618 files, including occurrences that do not decode a result. The read file has 629 physical lines, with multiple occurrence line numbers grouped per file. | `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md:1-629`; `docs/research/se-fullspread-preview-consumers-20261103/REPORT.md:63-79` |
| The accepted scalar ABI changes returns in place, keeps the existing parameters and selectors, accepts the written bundle interfaces, and leaves exact-output returns unchanged. | `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md:5-32,65-75,97-205` |

The assignment and brief additionally supply the binding filled readings: pre-burn, rounded-down share apportioning; fieldless `Donation()`; a both-token exit that pays the claim without swapping; exit preview as share valuation; and no existing-fee credit in a mint preview.

# Assumptions

- **Source precedence, not a new economic inference:** the dated F2 override replaces the stale principal-only sentence that remains in the blockers file's closing recap and the earlier consumer report's F14 summary. F7 replaces a conflicting generic no-event sentence for a successful `donate()` invocation. F12 replaces every stored-owner initialization/check sentence.
- **Source precedence:** the accepted interface report's older short-pretransfer revert is replaced by the binding directive and F1. Its older sibling recommendation is replaced by its own owner lock. Its general preview language does not weaken this family's later same-state exit-apportioning and swap requirement.
- **Editorial inference:** the former family-only protocol/position query responsibilities move to the two named reusable aware facets. The custom reserve view remains separate. No new family query selector is invented to preserve a now-empty responsibility.
- **Editorial inference:** reporting each fail-closed call site separately is the meaning of the report's six consumers: five production files contain six gates. The required migration extends to every actual one-word reader in the index, not every comment or occurrence.
- No numerical swap algorithm, new error, event field, selector, accounting scale, or fee source is inferred. The one-sided sizing rule states the required outcome and leaves its implementation to the engineer.

# Coverage

| Target | Coverage |
| --- | --- |
| Brief | Read in full; output ownership and required headings applied. |
| Blockers and dated overrides | Read in full; B-01 through B-13, N-01 through N-07, matrix and audit directives reconciled. |
| Current PRD | Read in full; sections 1 through 10 and all existing FS identifiers retained, with contradicted requirements replaced. |
| Pretransfer directive | Read in full; maximum/refund branches and booked/share exclusions included. |
| Consumer report | Read in full; six gates and three ABI bindings reproduced with its source locators. |
| Consumer index | All 618 file rows retrieved in bounded reads; used as the migration inventory. Individual source files were not opened or decoder-classified anew. |
| Accepted ABI report | Read in full; owner lock used over the preserved historical recommendation. |
| Filled readings | Applied explicitly to withdrawal accounting, both-token exits, event signatures, and previews. |
| Runtime implementation, tests, gas, and audit absence | Not examined or executed; these remain requirements, not claimed results. |

# Conclusions

# Uniswap V4 full-spread Standard Exchange vault PRD

Replacement revision **fullspread-se-prd-owner-locks-20261103-astra-proposal**. This text consolidates the owner locks through 2026-11-03. It is an independent drafting contribution, not member-approved council text, an implementation, or a safety clearance. The authority is `IMPLEMENTATION_PLAN_BLOCKERS.md` in this directory, with later overrides winning, together with `docs/vaults/PRETRANSFER_DIRECTIVE.md` and the accepted return ABI identified below.

## 1. Goal

Build `UniswapV4FullSpreadStandardExchangeVault`.

One registry-deployed Crane diamond owns one Uniswap V4 pool key, one full-range position, booked fee and remainder balances, and one ERC-20 share supply. The diamond is the position owner. Shares claim their proportional position principal, accrued fees, and booked balances under the withdrawal rules below. There is no local liquidity sleeve.

This family adapts the expressly retained money operations of `contracts/protocols/strategy/weir/WeirVaults.sol` to the tokenized Standard Exchange standard. It has one ERC-20 share, one pool, and one full-range position. It does not copy Weir's manager of many virtual vaults.

It is not a sibling of PairToken and does not inherit PairToken economics by requirement ID. A PairToken economic or package choice remains only where this PRD expressly retains it.

### 1.1 What this family is not

- Not a source copy of Weir's multi-vault manager or a wrapper around its internal share ledger.
- Not Upper/Lower Wings. No second range or rebalance facet.
- Not a singleton of many pools, a second share ledger, or a shares-of-shares wrapper.
- Not an ERC-4626 product. Do not install `asset()`. A rejected identity binding is not made valid by adding that selector.
- Not a hook-package redesign. A functional hook change requires FS-HOOK-04's cited rejecting consumer. The accepted Standard Exchange return-ABI migration is required.

### 1.2 Deltas

| ID | Delta |
| --- | --- |
| FS-X01 | Canonical exact-input `exchangeIn` executes while the bound PoolManager is already unlocked, without a nested `unlock`. Ordinary entry opens its own unlock once per planned manager action. |
| FS-X02 | Withdrawn by FS-OWN-03. Do not install `getRate`. There is no designated `rateAsset`. |
| FS-X03 | Tests compose this share with another SE vault share in the current buffer-hook families under FS-HOOK-02, using externally configured rate-provider instances where required. |
| FS-X04 | Entry does not require a swap to consume the entire declared input. There is no `IncompleteConversion` check. Unused declared input and caller-input credits are refunded to the payer in the provided token. Accrued holder fees are booked, not refunded as caller input. Issuance follows FS-MONEY-01. |
| FS-OWN-01 | `poolManager()` belongs to the Crane Uniswap V4 Protocol Aware Repo and Facet, not a family query. |
| FS-OWN-02 | Pool and position identity belong to the reusable Crane `UniswapV4SinglePositionAware` Repo and Facet. |
| FS-OWN-03 | Do not implement `rateAsset()` or `getRate()`. This vault designates no single valuation or operations token. |
| FS-OWN-04 | No local liquidity sleeve, target percentage, or `localReserves()` getter. |
| FS-OWN-05 | Do not install ERC-5115, `syMoneyFacet`, or `syQueryFacet`. |
| FS-OWN-06 | Store the full pool key, ticks, and salt per instance. `positionLiquidity()` wraps the position read on the PoolManager. |
| FS-OWN-07 | `reserves()` and `reserveOfToken` wrap live deployed token amounts plus unpaid fees. They add no local balance. |
| FS-OWN-08 | `previewExchangeIn` and `exchangeIn` keep their parameters and selectors and return `(uint256 amountOut, uint256 amountRefunded)`. No `WithRefund` sibling. |
| FS-OWN-09 | Replace the paired methods with the accepted bundle routes. Keep restricted `donate` and `compound`, with the booking and one-token/both-token rules below. |
| FS-OWN-10 | No `previewWithdrawalMode`, `wrappedNative()`, `previewZapCredit`, `maxZapBps`, or `maxZapTickMove`. No replacement cap or tick bound. |

### 1.3 Owner-locked decisions

These are the consolidated requirements, including the later replacements of the original owner sentences.

**FS-OWN-01.** `poolManager()` is not a full-spread family query. Implement the Uniswap V4 Protocol Aware Repo and Facet under `lib/crane/contracts/protocols/dexes/uniswap/v4/aware`. One repo stores the protocol components. Its facet exposes them on the vault proxy. The package takes that facet as an input. The seven component addresses are package immutables, supplied at package deployment and written to the Protocol Aware Repo during vault initialization. Do not keep a second per-vault copy. Implement and test this facet in Crane.

**FS-OWN-02.** Pool and position information belong to the reusable Crane `UniswapV4SinglePositionAware` Repo and Facet. The repo stores the full `PoolKey`, `tickLower`, `tickUpper`, and position salt for each vault instance. A pool key alone is not a position identity. These values are instance storage, not package immutables. This family uses the full-range ticks and `bytes32(0)` salt. The facet is a package input and its getters are externally callable. Do not add a family-only `poolKey()` selector. Implement and test the pair in Crane.

**FS-OWN-03.** Do not implement `rateAsset()` or `getRate()`. `PkgArgs` has no `rateAsset`. Do not install rate-only errors or substitute NAV or another denomination. Externally deployed rate-provider instances used by hooks follow FS-OWN-29; they do not add a rate to this vault.

**FS-OWN-04.** There is no local liquidity sleeve. Do not read `liquidReservePercentageOfVault(address(this))` as a target, keep a target, or expose `localReserves()`. Booked fees and remainders are not a sleeve.

**FS-OWN-05.** Do not install ERC-5115. There is no underlying LP token. Drop `syMoneyFacet` and `syQueryFacet`, including `deposit`, `redeem`, `exchangeRate`, and all other Standardized Yield selectors. Do not replace the dropped rate with NAV or another denomination.

**FS-OWN-06.** Keep `tickLower()`, `tickUpper()`, and `positionLiquidity()` on the reusable position-aware facet. `positionLiquidity()` wraps `StateLibrary.getPositionInfo` against the PoolManager for this diamond, the stored ticks, and stored salt. It returns that position's `uint128` liquidity, not a token amount or the pool's whole liquidity. `StateView` is an off-chain wrapper, not the vault's on-chain position-read dependency. `PositionManager` reads NFT positions; this diamond owns its position directly.

**FS-OWN-07.** Do not implement `basket()`. Reuse `vaultTokens()` from `MultiAssetBasicVaultFacet`. A custom family facet exposes `reserveOfToken` and `reserves`; do not install the shared facet's stored-balance reserve functions. Both views wrap the existing deployed-reserve reads: token amounts implied by this position's liquidity, current price, and stored ticks, plus fees owed to this position and not yet collected. Use the existing position-amount and fee-owed reads, not a new conversion formula. There is no local term, booked-remainder term, or last-committed local snapshot. `reserves()` follows `vaultTokens()` order. `reserveOfToken` returns the corresponding amount or zero for an unknown token.

**FS-OWN-08.** The accepted Standard Exchange definition is `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md`, with its owner lock overriding the preserved recommendation. `previewExchangeIn` and `exchangeIn` keep their current parameters and return `(uint256 amountOut, uint256 amountRefunded)`. Selectors remain `0x89d61912` and `0xd02d3063`, respectively. There is no `WithRefund` sibling. Other vault implementations and consumers migrate to that return ABI. `exchangeOut` and `previewExchangeOut` do not gain a refund return. The bundle interfaces in that report are accepted. Section 6 identifies the mandatory preview consumers.

**FS-OWN-09.** Do not install `depositPair`, `previewDepositPair`, `redeemPair`, or `previewRedeemPair`. Deposit maps to `exchangeBundleInForSingleOut` and `previewExchangeBundleInForSingleOut`, with the share as `tokenOut`. Redeem maps to `exchangeBundleOut` and `previewExchangeBundleOut`, with the share as `tokenIn` and both underlying ERC-20 faces as outputs. A both-token exit pays the caller's principal, fee, and booked-balance claim in both tokens without a swap. Emit `PairDeposited(address indexed caller)` or `PairRedeemed(address indexed caller)` on the corresponding bundle execution; no other event arguments. Keep `donate` and `compound`. Neither inherits PairToken's ratio-swap or quarter-cap economics or Weir's treasury performance fee.

**FS-OWN-10.** Do not install `previewWithdrawalMode`, `wrappedNative()`, `previewZapCredit`, `maxZapBps`, or `maxZapTickMove`. Do not move a wrapper getter to the position-aware facet. Remove `PkgInit.wrappedNative`. Callers use the ERC-20 faces in `vaultTokens()`, with the network WETH constant for native currency. Do not add a replacement zap view, cap, tick bound, or hidden constant.

### 1.4 Owner answers locked 2026-11-01

The identifiers in this section retain their original order. Their text incorporates the later 2026-11-02 locks and 2026-11-03 overrides.

**FS-OWN-11.** The genesis floor is `MIN_SHARES` (`1_000`) minted to `address(0)` inside the first deposit. It is part of `totalSupply()`, never credited to the depositor, and not part of the fee base. There is no second share ledger or alternative floor holder.

**FS-OWN-12.** Do not move local balances toward a sleeve target after a deposit, withdrawal, or compound. There is no sleeve target, 5% deviation trigger, sleeve refill, or sleeve adjustment swap. Ordinary deposits, withdrawals, and `exchangeIn` do not invoke `compound()` or `donate()` and do not deploy booked remainders. Their fee collection, booking, and withdrawal payouts still follow the rules below.

**FS-OWN-13.** If nobody holds the PoolManager unlock, this vault uses its committed per-action unlock path. If another caller already holds it, canonical `exchangeIn` must not call `unlock()`; it calls `modifyLiquidity` and `swap` directly on that open manager under FS-UNLOCK-02. It never takes another caller's lock. The position fraction can be pulled; there is no sleeve fallback. This vault may participate in a batch swap with other Uniswap V4 pools.

**FS-OWN-14.** `compound()` is restricted to the current `feeTo()` address or an operator authorized in `OperableRepo`. It has no donation input. Collect fees and combine them with booked balances. If only one token is available, apply the one-sided rule in FS-OWN-33. If both tokens are available, add proportionally without swapping; determine the scarcer token relative to the position ratio, use it fully, and book the excess of the other token. Book the actual held balance after the deposit, including stray transfers. A failed step reverts; do not add retries, fallbacks, or swallowed failures. A remainder alone is not a revert. A call with no fees and no booked remainder returns unchanged and emits no event. Emit fieldless `Compounded()` when a deposit is made from collected fees or booked tokens. A call that deposits nothing does not emit `Compounded()`. Booked tokens count as fees, including a previously booked donation remainder; do not store fee origin.

**FS-OWN-15.** A redemption removes the caller's proportional deployed liquidity and pays the caller's proportional fees and booked balances. A one-token exit swaps only the unwanted side of that exiting claim. It does not sell other holders' inventory or use local backing as a shortfall top-up. The unbounded entry and redemption price limits remain; no price check, tick bound, or swap fee cap is added.

**FS-OWN-16.** `PkgInit.poolManager` remains an architecture address binding. All seven architecture addresses are supplied when deploying the package and become package immutables. Initialization writes them into the Protocol Aware Repo. The two aware facets are explicit package inputs. Owner authority is a live check against the address currently returned by `feeTo()`, not an owner snapshot taken at initialization. Implement new ownership and operable modifiers for that check; do not reuse existing facets for the owner check. Reuse `OperableRepo` for operator authorizations.

**FS-OWN-17.** Callers send and receive WETH only when the pool currency is native. They do not send or receive native ETH through these routes. Accept native ETH only from the pool, wrap it before holding it as ERC-20 backing or paying a caller, and unwrap WETH only to settle into a native-currency pool. The wrapper is the network WETH constant, `WETH9` on Robinhood. There is no `wrappedNative()` getter or `PkgInit.wrappedNative`.

**FS-OWN-18.** The Protocol Aware Repo stores the PoolManager, Position Descriptor, Position Manager, Quoter, State View, Reserves Lens, and Universal Router. Their addresses are package-deployment inputs and immutables, not hardcoded Robinhood values. Another chain uses the same package code with its own addresses. `ROBINHOOD_MAIN.sol` supplies Robinhood values only.

**FS-OWN-19.** No view reverts by a coded vault error. Unknown tokens and unsupported view routes return zero; `previewExchangeOut` returns zero. Busy-vault or unlocked-manager state is not a view revert. Economic views compute their specified result. The deployed-reserve views are live and include unpaid fees; they do not return a local snapshot. No quote-step-cap error is added. An EVM out-of-gas failure is not a new vault error.

**FS-OWN-20.** Unbooked held tokens are not reserves or holder credit. `pretransferred == true` declares use of held unbooked balance up to the caller's maximum; the vault does not investigate provenance. Booked balances are excluded. If the maximum is within the unbooked balance, process that declaration and refund maximum minus used, in the provided token; do not process or refund surplus beyond the maximum. If the maximum exceeds the unbooked balance, refund that unbooked balance, do not spend it, and do not pull the shortfall. The larger maximum is not itself a revert. A non-atomic pretransfer is the caller's risk. An address without bytecode cannot pretransfer. A burn uses the caller's shares; shares parked on the vault are not the caller's credit.

**FS-OWN-21.** `donate` accepts underlying `vaultTokens()` and the share, and is restricted by the live-owner/operator rule in FS-OWN-16. It reverts when `totalSupply` is zero, before any swap. A share donation burns the caller's shares without withdrawing or swapping them. An underlying donation uses the declared pretransferred input or pulls the directed amount, subject to FS-OWN-20. `donate()` also compounds: combine the accepted donation, collected fees, and booked remainder, then apply FS-OWN-14's one-token or both-token rule. Deploy the available matched liquidity before returning and book the actual held remainder; do not return the maintenance remainder to the donor. This does not change the explicit refund of an overstated pretransfer under FS-OWN-20. Emit fieldless `Donation()` on a successful `donate()` call. Also emit fieldless `Compounded()` if a deposit is made from collected fees or booked tokens. Failed calls leave no event.

**FS-OWN-22.** `vaultTokens()` is PoolKey `currency0`, then `currency1`, with WETH substituted for native. Keep membership and order stable for the positional bundle interface. The pool-key check is only that the pool is initialized on the bound manager and its hook is `address(0)`. There is no additional inherited-domain, minimum-spacing, or quote-cap restriction.

**FS-OWN-23.** The cut names exact installed selectors. `vaultTokens` belongs to `MultiAssetBasicVaultFacet`; `reserveOfToken` and `reserves` belong to the custom family facet. Do not install all selectors exposed by the shared basic-vault facet. Protocol and position getters come from their respective Crane aware facets and are callable through the proxy.

**FS-OWN-24.** Charge the usage fee only when this vault mints shares. If `feeTo()` is nonzero, let `grossShares` be the newly earned shares before the fee, resolve `usageFeeOfVault(address(this))`, clamp the applied value to at most `3e17`, and calculate `feeShares = mulDiv(grossShares, appliedFee, 1e18)`. Mint `feeShares` to `feeTo()` and `grossShares - feeShares` to the depositor's recipient, skipping a zero mint. Do not mint anything beyond `grossShares`, charge a fee on fee shares, or include the floor in the fee base. If `feeTo()` is zero, no fee shares are minted. The clamp is local to the vault read; it does not constrain or write the oracle. Preserve WAD precision, including `1e13` for 0.001%; do not round to three digits or impose a minimum. Previews and `minAmountOut` use the same clamped fee and net depositor shares. Pass-throughs, including underlying-to-underlying `exchangeIn`, mint no shares and take no usage fee. No exit fee, fee-increase delay, or exact-out gross-up is added.

**FS-OWN-25.** A bundle deposit adds declared amounts proportionally and refunds the rest to the payer without a balancing swap. Scalar `exchangeIn` supports an underlying-to-underlying swap on the bound pool as a pass-through.

**FS-OWN-26.** Inbound issuance checks `IVaultRegistryDisableQuery.isDisabled(address(this))` and reverts `VaultDisabled(address)`, following the existing Standard Exchange rule. Disabling issuance does not prohibit supported exits.

**FS-OWN-27.** Shares use the raw V4 liquidity number. Genesis gross shares are added liquidity minus `1_000`. Later gross shares are `added liquidity * totalShares / existing liquidity`, rounded down. A burn removes `liquidity * shares / totalSupply`, rounded down. Use the pre-operation supply and liquidity; supply includes the floor. Token amounts enter liquidity calculations in their own native decimals. Token decimals do not enter share mint/burn formulas. Share `decimals()` is 18 as metadata only: do not scale stored balances or the floor to match it. Positive supply with zero deployed liquidity is unreachable under the retained floor and no-sleeve rules; no special denominator is added.

**FS-OWN-28.** A missed deadline reverts `IStandardExchangeErrors.DeadlineExceeded(deadline, block.timestamp)` before any other execution work.

**FS-OWN-29.** This vault has no `getRate()` and stores or exposes no rate-provider address. A hook configures a provider for each Standard Exchange liquidity leg. Deploy each instance through `IStandardExchangeRateProviderDFPkg`, whose `PkgArgs` carries `reserveVault`, `rateSubject`, and `rateTarget`. For the required rows, the rate subject is this vault used as liquidity, and each underlying token is exercised as a rate target. The same vault may be held in two pools configured with different target-specific provider instances. The useful number of targets is `vaultTokens().length`; it is not an enforced deployment cap. Migrate the provider and all other old preview consumers to the accepted tuple.

**FS-OWN-30.** On withdrawal, take the caller's share as shares burned divided by total shares before the burn, rounded down for each apportioned amount. Remove the proportional deployed principal. From `feesAccrued` returned by the withdrawal and each pre-existing booked token balance, include that rounded-down share in the exit and book the rest for staying holders. Do not count the same fees twice. A one-token exit swaps all unwanted withdrawn principal plus the caller's opposing-token fees and booked claim into the selected token; the caller's selected-token fees and booked claim are paid directly. If that conversion cannot finish, revert `AmountOutNotMet` and do not burn shares. Do not pay an opposing residual, book it for later, or retain it. A both-token exit pays both token claims and does not swap. Caller-set minima remain binding. The former sleeve's no-shortfall-revert sentence does not excuse an incomplete one-token conversion.

**FS-OWN-31.** A borrowed-unlock exit pulls the same deployed fraction and pays the same fee and booked claim as an own-unlock exit. It calls `modifyLiquidity` and `swap` directly, without nested `unlock`, and settles its own deltas before return. There is no unpullable-position sleeve case and no `UnderlyingUnavailable` requirement for that case.

**FS-OWN-32.** User input that does not become liquidity is refunded to the payer in the provided token. It is not credited as shares or left for holders. Existing fees and booked backing are not user input. Share-minting deposits book `feesAccrued`; they do not add it to the deposit, share credit, or swap. A mint preview does not credit the new depositor with those fees. Donation and compound remainders instead follow their explicit booking rule.

**FS-OWN-33.** For a one-sided share deposit and a one-token `donate` or `compound`, choose the greatest liquidity the following add can take. The swap output is the other token that liquidity consumes; the unswapped input is the processed token that liquidity consumes. The swap input is not the amount of processed token consumed by the add itself. Rounding leaves any remainder in the provided or processed input token. Refund it on a user deposit and book it on donation/compound. No fixed 48% sizing rule or mandatory refund is added. A bundle deposit and a maintenance balance already containing both tokens add proportionally without swapping.

## 2. Authority and precedence

| Source | Role |
| --- | --- |
| `IMPLEMENTATION_PLAN_BLOCKERS.md` in this directory | Binding owner decisions, including the 2026-11-03 overrides. Later overrides win over earlier text, including stale recaps. |
| `docs/vaults/PRETRANSFER_DIRECTIVE.md` | Binding declaration, custody, caller, and refund rules. F1 confirms that overstated maxima are refunded without being spent. |
| `docs/research/se-fullspread-prd-rewrite-20261103/brief.md` | Binding filled readings for apportioning, fieldless donation events, both-token exits, and previews. |
| `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md` | Accepted scalar and bundle ABI; its owner lock overrides its historical sibling recommendation. The later pretransfer directive replaces its shortfall-revert wording. |
| `docs/research/se-fullspread-preview-consumers-20261103/REPORT.md` and `INDEX.md` | Required preview migration inventory, not economic authority over later F2. |
| `contracts/protocols/strategy/weir/WeirVaults.sol` | Source of only the money operations expressly retained here. No inherited multi-vault administration or treasury performance fee. |
| FS-FACET-01 and FS-PKG-01 | This family's package inputs; no implied PairToken economic inheritance. |
| `contracts/hooks/uniswap/v4/standardExchange/` | Current hook bindings and topology; functional changes require FS-HOOK-04. |
| `CLAUDE.md`, `docs/agent/INDEXEDEX_AGENT_LAW.md`, `.github/ASSISTANT_CODING.md`, `.github/ASSISTANT_TESTS.md` | Registry, token, compiler, and production-first test law, subject to the explicit owner scope for this family. |
| Crane architecture, IndexedEx testing, and Uniswap V4 hook-package skills | Packaging and test workflows. |

PairToken stage one is not an economics authority. Do not inherit S1-ACC-02, S1-ACC-07, S1-D03's dead-share sentence, S1-OP-02's zap caps, S1-OP-05's ratio swap and quarter-cap, S1-P05, S1-P07, S1-EXIT-01's collection-only fallback, S1-X15, or S1-X17.

The borrowed-unlock surface remains canonical `exchangeIn` only. `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` revert `ManagerAlreadyUnlocked` in that context. Paired and SY selectors are absent.

Do not install `IERC4626`, `IStandardExchangeRateQuote`, `IStandardExchangeTransitionQuote`, `IStandardExchangeUnlockContextQuote`, or `IStandardExchangeExactOutputQuantityQuote` unless a separately admitted FS-HOOK-04 change requires a quote extension. The normal exact-input hook path must demonstrate the existing ERC-165-gated fallback to standard previews. A stub returning live values for projected state is forbidden. No such extension adds this vault's withdrawn rate.

### 2.1 Dispositions retained from advisory

| Topic | Final choice | Not adopted |
| --- | --- | --- |
| Vault rate | No `getRate` or `rateAsset`. Hooks use independently deployed target-specific providers. | A vault rate facet, replacement NAV, or zero-rate fallback. |
| Supply below `1e18` | No vault rate-supply restriction. Raw-liquidity shares are not rescaled. | `InsufficientRateSupply` or a share-side decimal multiplier. |
| Unlocked surface | Canonical `exchangeIn`, including its mint, redeem, and swap routes. | Borrowed unlock on compound, donate, bundle routes, or SY. |
| Unlock count | One vault-started unlock per planned manager action. | A mandatory single unlock per public call. |
| Recipient | Supported output may go to the hook's recipient, including its unwrap user. | `recipient == msg.sender` as a hard rule or a hook allowlist. |
| Entry remainder | Refund unused declared caller input in that token; book separately accrued holder fees. | Donation-by-dust, `J_i` credit, or `IncompleteConversion`. |
| Identity `token == share` | Record a rejecting current hook binding under FS-HOOK-04. | Adding `asset()` to force a passing row. |
| Sleeve | Absent. Booked balances remain withdrawable pro rata and maintainable by authorized calls. | A target, refill rule, local snapshot, or locked-manager fallback. |
| Maintenance exposure | Restrict to live owner or operator; preserve the accepted live-price sandwich exposure. | An undisclosed price check, tick bound, or claim of complete APEX-2026-023 absence. |

## 3. Facets

### FS-FACET-01 - Package inputs

Use explicit facet inputs, not an open `IFacet[]`. Do not pass PairToken family facets into this package. Keep shared standard facets as shared implementations; use this family's implementations for its money, quotes, unsupported exact-output execution, callback, and reserve views. Protocol and position query responsibilities are supplied by the two named Crane aware facets rather than family-only copies.

| Input or responsibility | Installed selectors |
| --- | --- |
| `erc20Facet` | The nine canonical ERC-20 and metadata selectors. |
| `erc2612Facet` | `permit`, `nonces`, `DOMAIN_SEPARATOR`. |
| `erc5267Facet` | `eip712Domain`. |
| Shared `MultiAssetBasicVaultFacet` input | `vaultTokens` only. |
| `basicVaultFacet`, the custom family reserve facet | `reserveOfToken`, `reserves`. |
| `standardVaultFacet` | `vaultFeeTypeIds`, `contentsId`, `vaultTypes`, `vaultConfig`. |
| `moneyFacet` | `exchangeIn`, `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, `compound`. |
| `quoteFacet` | `previewExchangeIn`, `previewExchangeBundleInForSingleOut`, `previewExchangeBundleOut`. |
| `outFacet` | `previewExchangeOut`, which returns zero, and `exchangeOut`, which reverts `ExchangeOutNotAvailable()` without moving tokens. |
| Crane Uniswap V4 Protocol Aware Facet input | The stored protocol-component getters, including `poolManager()`. |
| Crane `UniswapV4SinglePositionAware` Facet input | The reusable pool and position getters, including `poolKey()`, `tickLower()`, `tickUpper()`, and `positionLiquidity()`. |
| `callbackFacet` | `unlockCallback`. |

Do not install `rateAsset`, `getRate`, `basket`, `localReserves`, `wrappedNative`, the dropped paired selectors/previews, zap views, or any Standardized Yield selector. `syMoneyFacet` and `syQueryFacet` are not package inputs. The ownership/operable checks use the new live-`feeTo()` modifiers, not stored-owner facets; operator authorizations remain in `OperableRepo`.

The old 61-selector count is not the manifest. Enumerate the exact expected selectors from the implemented package and test them through the registry-built proxy. `linkedComponents()` is facet metadata, not an installed proxy selector. Do not invent selector hex or install an otherwise unneeded family query selector.

The family interface declares the already specified `InvalidUnlockedContext()` and `SettlementMismatch()` errors. The latter covers inability to close the diamond's own touched deltas. Compute selectors during implementation. Do not declare withdrawn rate errors `InsufficientRateSupply`, `RateNormalizationOverflow`, or `RateUnavailable`.

### FS-FACET-02 - Factory-owned exclusions

Do not put ERC-165 introspection, ERC-8109 introspection, diamond loupe, or the factory-owned temporary-hook facet in `PkgInit`, family cuts, or the package interface aggregation. Name the temporary-hook implementation only from the current factory evidence, not by inventing a filename.

The finished proxy still exposes the surfaces installed by the factory. Excluding them from family package inputs does not remove them from the diamond.

## 4. Files and package

### FS-ARCH-01 - Files

Create the family under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`. Do not host it in PairToken or Wings.

Retain the structural split, using these full family names:

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
- Facet and target files for money, quote, out, callback, and the custom reserve-query responsibility. Use the full pattern, such as `UniswapV4FullSpreadStandardExchangeVaultMoneyTarget.sol`, not a shortened literal `MoneyTarget.sol`.

Do not create SY money/query implementations or family duplicates of the protocol/position getters. The six library slots remain; assign already specified operations to them without importing PairToken economics.

`TestBase_UniswapV4FullSpreadStandardExchangeVault.sol` goes under the family's `test/bases/`. Specs go under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`.

Use a new namespaced storage slot, `keccak256(abi.encode(namespace)) - 1`, distinct from PairToken and Wings. The protocol-aware and single-position-aware repos and facets live in Crane, not in this family. Their Crane tests are part of the directive.

### FS-PKG-01 - `PkgInit` and `PkgArgs`

`PkgInit` has the explicit facet inputs in FS-FACET-01, followed by the infrastructure bindings. Retain `poolManager`, `registry`, `oracle`, `diamondFactory`, and `linkedLibraries`. Add the other six named V4 architecture address bindings alongside PoolManager so all seven are supplied once at package deployment. They become package immutables. Do not hardcode a chain's architecture addresses.

Remove `wrappedNative`, both SY facet fields, and family-only protocol/position query bindings. The wrapper is the network constant. `linkedLibraries` remains `address[6]`, ordered Math, Projection, SwapProjection, Planner, Execution, ExecutionPreparation. Include the Protocol Aware Facet and `UniswapV4SinglePositionAware` Facet as explicit package inputs.

`PkgArgs` contains:

- `PoolKey poolKey`
- `string name`
- `string symbol`

Initialize the instance's position-aware storage with the full pool key, `TickMath.minUsableTick` and `TickMath.maxUsableTick` for its spacing, and `bytes32(0)` salt. Write the seven package-bound architecture addresses to the Protocol Aware Repo. There is no hook allowlist, designated rate asset, provider address, wrapper argument, `maxZapBps`, or `maxZapTickMove`.

`bindingHash` covers every `PkgInit` field. `calcSalt` and `processArgs` run by delegatecall and use immutable bindings and self calls.

`deployVault(PkgArgs) returns (address)` uses the bound IndexedEx vault registry, not a second factory. This package does not CREATE3 the PoolManager. Tests use the existing artifact-backed CREATE3 helper.

`processArgs` reverts `NotCalledByRegistry` unless both `msg.sender` is the bound registry and `address(this)` is the bound `diamondFactory`.

### FS-PKG-02 - Validation

Reject without leaving a partial usable diamond:

- Missing or code-empty required components, a family linked-component hash mismatch, or a forbidden `getRate`/`rateAsset` cut: `InvalidComponent`.
- A pool not initialized on the bound manager or a nonzero pool hook: `InvalidPoolKey`. Do not add an inherited-domain or minimum-spacing restriction.
- An incompatible native-wrapper boundary or collision with the other ERC-20 currency face: the existing `InvalidWrappedNative` case. The boundary uses the network WETH constant, not a removed package argument.
- The `processArgs` context failure: `NotCalledByRegistry`.
- Initialization inconsistent with the bound package and arguments: `InvalidInitializationContext`.
- A second initialization: `AlreadyInitialized`.

There is no rate-asset or zap-limit argument to validate. Initialize name, symbol, architecture repos, pool key, full-range ticks, and salt. Do not initialize a stored owner as the authority for restricted calls. The first depositor creates the position and floor through FS-MONEY-01. No treasury performance fee is added.

## 5. Money and unlocked entry

### FS-MONEY-01 - Weir-adapted money rules

Use the accepted Standard Exchange selectors plus `donate` and `compound`. Do not install Weir's `deposit`, `withdraw`, `zap`, or `zapTo` selectors.

**Funding and refunds.** A pull-path user deposit pulls the declared amounts from `msg.sender`, then refunds unused declared input to that payer. Output shares go to `recipient`, who need not be the payer. Refunds and caller-input credits are not booked without shares. Do not confuse `feesAccrued` with a depositor credit. Zero refunds transfer nothing. Failure to deliver a required output or refund reverts the call.

For pretransfer, apply FS-OWN-20 and the directive. A covered maximum refunds maximum minus used; an overstated maximum refunds the unbooked held balance without spending it or pulling a shortfall. Do not refund unrelated surplus, spend booked backing, or treat parked shares as burn authority. Ordinary route minima remain binding; the size of the maximum alone is not a revert.

**One-sided adds.** Choose the greatest liquidity the following add can take under FS-OWN-33. The swap output and unswapped input are the two amounts consumed by that add, with rounding remainder in the processed input token. No consumption-equality check, `IncompleteConversion`, fixed 48% swap, mandatory refund, zap cap, or hidden tick guard is added. Swaps use `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`.

**Bundle adds.** Add declared amounts proportionally without swapping and refund unused amounts to the payer in the corresponding input tokens. Bundle amounts and refund arrays use stable `vaultTokens()` order.

**Issuance.** Reject a first add of liquidity less than or equal to `1_000`. Mint the `1_000` floor to `address(0)`. Genesis `grossShares = addedLiquidity - 1_000`; later `grossShares = floor(addedLiquidity * totalSharesBefore / liquidityBefore)`. Neither fees nor booked balances enter that liquidity denominator. No compound runs before issuance. Apply FS-OWN-24's netting fee to gross shares, including genesis, and mint only the net depositor shares plus fee shares. The first deposit additionally mints the floor; later deposits increase total supply only by gross shares. Existing accrued fees returned by `modifyLiquidity` are booked, not deposited, swapped, or credited to the new depositor.

**Withdrawal.** With `S` equal to total supply before burn, `s` the caller's shares burned, and `L` existing liquidity, remove `floor(L * s / S)` liquidity. For each token, apportion `floor(feesAccrued_i * s / S)` and `floor(bookedBalance_i * s / S)` to the caller, measured before the burn, and book the rest. Combine that entitlement with withdrawn principal. Do not include unrelated unbooked transfers or another holder's share. Do not treat a newly booked fee as a second pre-existing booked claim.

A one-token exit converts all opposing principal, fee entitlement, and booked entitlement to the requested token, then pays the requested-token principal and entitlement plus conversion proceeds. Complete the conversion or revert `AmountOutNotMet`, restoring shares and all effects. No opposing-token residual is paid, booked, or retained. A both-token exit pays those two claims without a swap. Caller-set minima still apply. A successful full share-input exit has no unused share input to refund; this does not change the accepted function return ABI.

**Maintenance.** Only `donate()` and `compound()` perform the authorized collection/reinvestment process in FS-OWN-14 and FS-OWN-21. They operate on fees, donations, and booked balances, never by swapping the deployed position. One available token uses the one-sided sizing rule; two available tokens use a proportional add without a swap, exhausting the proportionally scarcer token and booking the actual held remainder. Do not add another attempt or swallow a failed step. A remainder does not itself revert or freeze a later route. Booked balances may be processed by a later authorized call and are withdrawable pro rata in the meantime.

The local booking operation uses actual held balances after maintenance and can include a stray transfer or non-atomic pretransfer. Atomic transfer-and-consume is the integrating caller's responsibility. This does not allow an ordinary deposit or withdrawal to sweep an unrelated balance.

`Donation()` and `Compounded()` have no fields. A successful donation emits `Donation()`. A deposit made from collected fees or booked tokens emits `Compounded()`, including a depositing `compound()` call. Booked donation remainders count as fees; no fee-origin store is maintained. A no-fee/no-booked-balance `compound()` is unchanged and emits nothing. The vault does not add its own swap or liquidity-add event: PoolManager `Swap` and `ModifyLiquidity` logs with the vault as sender provide those amounts. Bundle executions emit the paired events with only the indexed caller in FS-OWN-09, and standard exchange and ERC-20 events retain their existing roles.

**Native boundary.** The public routes use ERC-20 faces and are nonpayable. Native pools remain supported internally, but caller input and output use WETH. Wrap pool receipts and unwrap only for native pool settlement. Do not expose a wrapper getter or duplicate native and wrapped backing.

**Budgets.** Retain the 12,000,000 gas transaction ceiling and 5,000,000 preview ceiling. Hook-composed transactions include the hook work. An oversized composed route is an unresolved narrowed route, not a passing measurement or waiver. Do not invent a quote step cap, spacing rule, fallback, partial-fill quote, or new quote error to satisfy a budget.

### FS-UNLOCK-01 - Two dispatch paths, one engine

Current buffer and unwrap helpers call canonical `IStandardExchangeIn.exchangeIn` while the PoolManager is unlocked. Do not add `exchangeInUnlocked`. A hook may direct output to itself or its unwrap recipient.

Check the deadline first, then the applicable route, amount, funding, and authority requirements. `exchangeIn` reads `TransientStateLibrary.isUnlocked` on the bound manager:

- Locked: FS-UNLOCK-03.
- Unlocked: FS-UNLOCK-02.

The flag selects dispatch, not authorization. Allowance, minima, deadline, and caller share authority still apply. The PoolManager is not the depositor.

`exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` retain `ManagerAlreadyUnlocked()` in this context. There are no paired selectors or SY mutators. Permitted V4 batch composition does not enlarge this borrowed surface.

### FS-UNLOCK-02 - Borrowed unlock

When canonical `exchangeIn` takes the unlocked path:

1. The vault is initialized and idle, callback commitment is empty, reservations are zero, and this diamond's backing-currency deltas on the bound manager are zero. Otherwise use the specified `SettlementMismatch` or `ReentrantOperation`.
2. The caller has code, funds its own input, and owns the shares burned on exit. `pretransferred` is false. The function is nonpayable; value-bearing calls fail at the ABI boundary, not a new `msg.value` branch. `recipient` can be the caller or another supported recipient. Funding and route failures use their existing errors; borrowed-context failures use `InvalidUnlockedContext`.
3. Accept no alternate payer, callback payload, or foreign creditor. Burn only the caller's shares.
4. Use the same internal action, accounting, and settlement engine as the locked path. Do not call `unlock` or `unlockCallback`. Do not require the global nonzero-delta count to be zero; outer hook/router deltas may remain open.
5. Call `modifyLiquidity` and `swap` only for the diamond's hookless pool. The only position written is its stored full-range, salt-zero position. Pull a withdrawing caller's deployed fraction directly and apply the same fee and booked apportioning as on the own-unlock path.
6. Settle each debt atomically for its currency: sync, transfer or value, settle, then take credits. Do not `settleFor` a foreign address. The manager's sync checkpoint is global transient state; do not assume an outer checkpoint survives this work or clear foreign sync to conceal clobbering. If the diamond cannot close its own touched deltas without taking foreign credit, revert `SettlementMismatch`.
7. Before return, assert this diamond's touched currency deltas are zero. Do not close the hook's/router's deltas or require the global count to be zero.
8. Failure reverts the vault call and descendant effects. If the outer caller catches it, vault state is restored while the outer caller still owes its own settlement. Catching does not relock the manager.

There is no sleeve payment, no unavailable-position fallback, and no `UnderlyingUnavailable` requirement for this path.

### FS-UNLOCK-03 - Locked path

For each selected manager action needing an unlock, commit `keccak256(abi.encode(operation, payload))`, call `unlock` once for that action, accept the callback only from the bound manager while the guard is held and only once for that commitment, settle, and verify relocking before the next action. The public-operation guard remains active across all planned actions, token calls, and final payout.

Nested unlock and replay remain forbidden. `unlockCallback` is not a deposit entry; an external unlock does not supply the committed hash. Deposits and withdrawals do not automatically compound.

## 6. Rate, quote, and issuance

| Surface | Meaning | Forbidden substitute |
| --- | --- | --- |
| Issuance | Raw-liquidity share formulas and net fee in FS-MONEY-01. | S1-ACC-07, `J_i` booking, a zap-credit view, or decimal-scaled shares. |
| SY `exchangeRate()` | Not installed. | Replacement denomination or NAV. |
| Deposit preview | Net depositor shares and same-token refund for the declared available input, excluding existing fees from new credit. | Crediting accrued holder fees or quoting a raw oracle fee while executing a clamp. |
| Exit preview | Amount-specific claim using the same pre-burn fee/booked apportioning as execution and, for a one-token exit, the same opposing-claim swap. This is the share valuation, including accrued fees. | Principal-only quote, reserve-view division by supply, or a quote that omits the required conversion. |
| `getRate()` | Not installed on the vault. | A vault rate facet or stored rate-provider binding. |
| Unsupported preview | Zero without a coded vault revert. | `ExchangeOutNotAvailable` from `previewExchangeOut`, a busy-vault error, or a quote-step-cap error. |

For the same state and inputs, exit `amountOut` follows the execution apportioning and swap. Preview does not transfer or inspect staged pretransfer funding; it assumes the declared input is available. State changes before execution may change the result, and execution minima remain binding. Neither a zero preview nor the no-view-error rule promises success for an unsupported execution route.

The accepted scalar signatures are:

```solidity
function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
    external view
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

Their selectors remain `0x89d61912` and `0xd02d3063`. Return width changes from one word to two; the unchanged ERC-165 selector identity cannot distinguish the widths. No `WithRefund` interface, function, or unavailable-error sibling is added.

The accepted bundle signatures are:

```solidity
function previewExchangeBundleInForSingleOut(
    uint256[] calldata amountsIn,
    address tokenOut
) external view returns (uint256 amountOut, uint256[] memory amountsRefunded);

function exchangeBundleInForSingleOut(
    uint256[] calldata amountsIn,
    address tokenOut,
    uint256 minAmountOut,
    address recipient,
    bool pretransferred,
    uint256 deadline
) external returns (uint256 amountOut, uint256[] memory amountsRefunded);

function previewExchangeBundleOut(
    address tokenIn,
    uint256 amountIn,
    address[] calldata tokensOut
) external view returns (uint256[] memory amountsOut, uint256 amountRefunded);

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

Bundle-in input/refund arrays follow `vaultTokens()` order and have that length. A zero input slot is not provided input and does not require that token to be exchangeable. Bundle-out is exact-input, uses caller output order, and takes aligned per-output minima, not exact output quantities. A zero minimum is allowed; an omitted minima array is not a substitute for an aligned array. This family's mapped paired exit requests both underlying ERC-20 faces. Pay no unrequested token.

For execution, zero scalar input, all-zero bundle input, and an empty output list use the accepted `EmptyExchange` rule. `address(0)` is not a caller currency face and rejects with `TokenNotExchangeable`, as does an unsupported input/output token for the route. Scalar `tokenIn == tokenOut`, a provided nonzero bundle-in slot equal to `tokenOut`, or bundle-out `tokenIn` appearing in `tokensOut` rejects `InvalidRoute`. A zero recipient or the vault itself as recipient rejects under the accepted recipient rule. Preserve the accepted length, duplicate-output, and indexed minimum errors: `AmountsLengthMismatch`, `TokenAmountsLengthMismatch`, `DuplicateOutput`, and `MinAmountNotMetAt`. A code-less pretransfer caller rejects `EOAPretransferNotAllowed`. Unsupported or invalid view routes return zero rather than these execution errors. The later pretransfer maximum rule takes precedence over the interface report's superseded short-declaration revert.

`exchangeOut` and `previewExchangeOut` keep their existing return shape without a refund word. Execution is unavailable and reverts `ExchangeOutNotAvailable()`; its preview returns zero. Existing many-to-one, exact-output one-to-many, multi-asset-liquidity, and aggregate interfaces are not redefined by this migration.

**Required preview consumer migration.** The following six fail-closed call sites must accept and decode `(uint256 amountOut, uint256 amountRefunded)` rather than reject a valid 64-byte result. These paths and line numbers are the source locators recorded in `docs/research/se-fullspread-preview-consumers-20261103/REPORT.md:42-47`; they are six sites in five files.

| Consumer | Source lines | Old gate |
| --- | --- | --- |
| `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol` | 103-106 | Empty-supply `staticcall` rejects a result whose length is not 32. |
| `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol` | 121-125 | Live preview uses the same length gate and one-word decode. |
| `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/wrapped/WrappedStandardExchangeRateProviderTarget.sol` | 65-68 | The length gate returns `(false, 0)`. |
| `contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolHookTarget.sol` | 437-444 | The length gate returns false before a one-word decode. |
| `contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolHookTarget.sol` | 463-470 | The same length gate rejects the tuple. |
| `contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolHookTarget.sol` | 474-481 | The same length gate rejects the tuple. |

The three one-word ABI bindings also migrate, as recorded in that report at lines 57-59:

| ABI binding | Source lines | Required return |
| --- | --- | --- |
| `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` | 45-48 | `(uint256 amountOut, uint256 amountRefunded)` |
| `frontend/apps/indexedex/app/insights/lib/insightsAbi.ts` | 69-76 | Two `uint256` outputs, `amountOut` and `amountRefunded`. |
| `frontend/packages/protocol/src/protocolDetfAbi.ts` | 33-40 | Two `uint256` outputs, `amountOut` and `amountRefunded`. |

Every other one-word reader of `previewExchangeIn` in `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md` migrates to `(uint256 amountOut, uint256 amountRefunded)`. This includes typed call sites, low-level decoders, adapters, scripts, tests, and maintained ABI/generated consumers that actually read the old return. `contracts/test/bases/FundedThresholdAssertions.sol:60-63` is specifically identified by the report as a one-word decoder without a length gate; accepting a first word is not completion of the migration.

The index inventories 1,626 occurrences in 618 files, not 1,626 distinct decoders. Comments and calls that do not read a return are not independent decode failures. Do not paste the index into this PRD or silently omit actual readers because they tolerate trailing bytes. Update all other Standard Exchange vault implementations and `exchangeIn` consumers to the accepted scalar tuple as required by FS-OWN-08; this preview index does not claim to enumerate execution decoders.

### FS-RATE-01 - Withdrawn

Do not install `getRate`, its former one-share formula, or its rate-only errors on this vault. Do not bind `StandardExchangeRateProviderFacet` to this diamond and call that the vault's rate.

The hook's separately deployed `IStandardExchangeRateProviderDFPkg` instance is the accepted integration mechanism, configured for this vault and one target. The vault neither stores nor discovers it. Requiring that external provider is not by itself an unresolved or incompatible hook row. Test each underlying target and distinct pools using the same vault at different targets.

## 7. Hook integration

### FS-HOOK-01 - Families and bindings

Use each current family's package interface.

| Family | Test binding | Required evidence |
| --- | --- | --- |
| `single/` | One `standardExchange` and one `pairToken`. | FullSpread borrowed `exchangeIn` through `beforeSwap` in both exact-input directions. This is not a two-vault proof. |
| `constantProduct/single/` | One buffered SE, one pair token, one raw token. | FullSpread is the buffered leg. Identify any leg that actually converts rather than transfers. |
| `dual/` | Two SE arguments and two tokens. | The canonical cross-vault proof in FS-HOOK-02. |
| `orbital/` | `se0`, `se1`, `se2` and `rp0`, `rp1`, `rp2`; the hook exposes indexed SE/provider views. | A valid three-leg binding with FullSpread on one leg and another SE share on another, with roles stated. |
| `weighted/` | Arrays with `n` from 2 through 8. | A 2-leg and a larger supported configuration. |
| `stable/quad/curve/` | Fixed four-leg arrays. | Four valid legs; do not assume a volatile share is pegged. |
| `stable/quad/balancer/` | Dynamic arrays with 2 through 5 legs. | A 2-leg and a 5-leg configuration, not a fixed-four constructor. |

No new hook-package field is authorized. Configure existing rate-provider fields with separately deployed instances for the appropriate vault and target. Required scenarios rate this vault used as liquidity against each underlying token, exercise the integrated token as token0 and token1, and include two pools holding the same vault with different rate targets.

### FS-HOOK-02 - Canonical cross-vault fixture

1. FullSpread is the buffered leg and `standardExchange` is this vault. Where a rate provider is required, configure the accepted external instance for this vault and the selected underlying target. Do not use a nonexistent `rateAsset` or vault `getRate`.
2. The other SE is not required to mint or redeem inside the outer unlock if its family rejects that context. Its share may be an identity leg only where the current hook accepts that binding without adding `asset()`. Otherwise record that exact rejection under FS-HOOK-04. A supported raw-token or share-transfer leg does not prove conversion in that other vault.
3. The two backing pool keys differ. One direction mints FullSpread shares while the manager is unlocked; the reverse burns them. Assert balances, position owner, ticks, salt, and per-address deltas.
4. An identity-only share trade is a separate case, not proof of underlying entry or exit.
5. Both-buffered composition is optional and requires another family that already supports borrowed unlock.

A binding with two buffered legs that overwrite the same `standardExchangeOf[pair]` mapping is not the required fixture. If a package cannot represent that binding, record it rather than changing the hook silently.

This vault may participate in a batch swap with other V4 pools. Same-backing-pool sequential composition is not prohibited, but the disjoint-pool fixture does not prove it.

### FS-HOOK-03 - Exact output

`exchangeOut` reverts `ExchangeOutNotAvailable()` and `previewExchangeOut` returns zero. A hook route that invokes exact-output execution against this vault fails closed. An identity route that never invokes it is not forbidden by that rule. Exact-input `zeroForOne` and `oneForZero` are the two required directions, not exact-output support.

### FS-HOOK-04 - Separate hook-change gate

If a required route cannot run:

1. Correct a FullSpread money, preview, or context defect in this family.
2. Keep intentional exact-output unavailability and an unresolved over-budget route accurately labeled.
3. For a missing quote interface, `asset()` requirement, `SameToken`/pair-overlap rejection, or incompatible denomination, cite the consumer, selector, arguments, and rejection before proposing a separate functional hook change. Do not implement that change here or substitute a transition-quote stub.

Installing the accepted external provider and updating the accepted return ABI are required work, not reasons to label the row incompatible. A remaining cited topology rejection may close only the affected family's nonrepresentable row, not replace the canonical FS-HOOK-02 proof.

## 8. Testing

### FS-TEST-01 - Harness

Use the family TestBase, extending `IndexedexTest` and the canonical native-wrapper base in the current setup order. Deploy PoolManager through the existing artifact-backed CREATE3 helper. Deploy facets/package and vault instances through the current factory and IndexedEx manager/registry paths. The vault and hook must bind the same manager.

Bootstrap shares through public supported entry routes. Reuse non-SUT mintable funding tokens. Do not mock, etch, use `vm.mockCall`, or inject storage into the vault or PoolManager.

Use the default hermetic Foundry profile, no `viaIR`, and current runtime/initcode limits. Follow the current Solar compiler requirement. After production contract changes, build before tests because factory services read creation artifacts. These are future execution requirements, not evidence that this drafting pass ran them.

`recordLogs` alone is not a receipt. Before restoring a snapshot, assert the relevant pre-state/post-state equality. Include Crane tests for both new aware facet/repo pairs and proxy-level tests of their installed getters.

### FS-TEST-02 - Files

- `UniswapV4FullSpreadStandardExchangeVaultPackage.t.sol`
- `UniswapV4FullSpreadStandardExchangeVaultMoney.t.sol`
- `UniswapV4FullSpreadStandardExchangeVaultNative.t.sol`
- `UniswapV4FullSpreadStandardExchangeVaultQuotesAndRate.t.sol`
- `UniswapV4FullSpreadStandardExchangeVaultCallbacks.t.sol`
- `UniswapV4FullSpreadStandardExchangeVaultAlreadyUnlocked.t.sol`
- `UniswapV4FullSpreadStandardExchangeVaultBufferHookIntegration.t.sol`

The QuotesAndRate file tests previews, absence of a vault rate, and external-provider integration; its filename does not restore `getRate`.

Do not apply PairToken acceptance rows that assert removed economics, including S1-A10, S1-A13, S1-A15, S1-A19, S1-A46, S1-A62, S1-A64, and S1-A70 as issuance, zap-cap, remainder, or consumption-check requirements. S1-A40 is not an inherited borrowed-`exchangeIn` pass. Use FS-A19 through FS-A23.

Add this vault to the integration testing matrix and actual integration tests. Extend these live behavior contracts under `test/foundry/spec/hooks/uniswap/v4/standardExchange/` with this family's rows:

- `single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol`
- `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol`
- `dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol`
- `orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol`
- `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol`
- `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol`
- `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol`

Preserve other families' assertions and V3 rows. FullSpread exact-output success rows become the specified unavailable-execution/zero-preview expectations. Keep user-refund and donation/compound-remainder coverage; they have different custody rules.

Replace stale V4 FullSpread compatibility evidence rather than counting deletion-era tests as current proof. Update `docs/audits/apex-2026-09-17-evidence/hook-se-matrix.json`, `hook-se-matrix-findings.json`, `hook-se-matrix-finding-descriptions.json`, `docs/audits/apex-2026-09-17-evidence.md`, and `docs/audits/apex-2026-09-17-evidence/acceptance.json` item R10.3 as part of the implementation/testing work.

Test the vulnerabilities in `docs/security/audit/second_review` against this new vault. Closure by deletion of the previous FullSpread implementation is not evidence of absence here. A lock retaining a mechanism must not simultaneously be tested as if that mechanism were absent.

### FS-TEST-03 - Acceptance rows

| ID | Assertion |
| --- | --- |
| FS-A01 | Exact package cuts match FS-FACET-01 and succeed through the registry-built proxy. Factory introspection/loupe/temporary-hook selectors remain disjoint. Protocol and position getters are present through the Crane aware facets; family-only copies are absent. `rateAsset`, `getRate`, `basket`, `localReserves`, `wrappedNative`, dropped paired selectors, and SY selectors are absent. |
| FS-A02 | Changing any facet, library, or architecture/infrastructure binding changes `bindingHash`. Seven package immutable architecture addresses initialize the one Protocol Aware Repo; per-instance pool key/ticks/salt initialize the position repo. |
| FS-A03 | Invalid components, uninitialized or hooked pools, incompatible wrapper boundaries, double initialization, wrong registry caller, and correct registry in the wrong account reject without a usable partial vault. No removed wrapper/rate/zap argument or inherited-domain restriction is reintroduced. |
| FS-A04 | The family storage slot differs from PairToken and Wings; reusable aware repos are not duplicated in the family. |
| FS-A05 | Genesis creates one full-range salt-zero position owned by the diamond, rejects liquidity at or below `1_000`, mints the raw `1_000` floor to `address(0)`, and nets the fee from gross shares above that floor. The floor belongs to supply, not the fee base or depositor. No share rescaling or treasury performance fee occurs. |
| FS-A06 | Mapped bundle deposit adds proportionally without swapping and refunds unused declared inputs. Mapped both-token redemption pays the principal, accrued-fee, and booked claims without swapping. Preview arrays and execution agree in the same state. Emit `PairDeposited(address indexed caller)` and `PairRedeemed(address indexed caller)` with no additional fields. |
| FS-A07 | A one-sided add obeys FS-OWN-33 and leaves rounding remainder in the input token. Refund unused declared user input, never existing holder fees. Covered pretransfer refunds maximum minus used and preserves unrelated surplus; overstated maximum refunds unbooked balance without spending it or pulling a shortfall. No `IncompleteConversion` or fixed 48% rule. |
| FS-A08 | One-token exit swaps all opposing principal and the caller's opposing fee/booked claim, pays only the selected token, and leaves no opposing residual. Failure reverts `AmountOutNotMet` with shares and state restored. Other holders' fee and booked portions are not swapped or paid. |
| FS-A09 | `exchangeOut` reverts `ExchangeOutNotAvailable` without moving tokens; `previewExchangeOut` returns zero. Neither gains a refund return. |
| FS-A10 | Native pools work with WETH caller input/output only. Native ETH occurs solely at the pool boundary and is not double-counted with WETH. There is no wrapper argument or getter. |
| FS-A11 | Deposits book `feesAccrued` without deploying, swapping, or crediting it. Withdrawals apportion accrued fees and booked balances using pre-burn supply and rounded-down amounts, and book the remainder. No deposit, withdrawal, or `exchangeIn` calls compound or deploys booked remainder. |
| FS-A12 | Withdrawn rate surface remains absent: no SY `exchangeRate`. |
| FS-A13 | No vault `getRate` is installed. |
| FS-A14 | No `InsufficientRateSupply` is declared. |
| FS-A15 | No planner failure is exposed through a nonexistent vault rate. |
| FS-A16 | Issuance reads neither `exchangeRate` nor `getRate`; mint/burn formulas use raw liquidity, pre-operation supply, and no token-decimal or share-side scaling. |
| FS-A17 | Multi-action locked entry/exit uses one unlock and one consumed callback per planned action. Replay rejects and the guard spans actions. Borrowed equivalents use zero unlocks. |
| FS-A18 | `unlockCallback` rejects every caller except the bound manager and rejects missing/replayed commitments without moving tokens. |
| FS-A19 | Borrowed `exchangeIn` calls `modifyLiquidity`/`swap` directly, pulls the exit fraction, and closes only the diamond's touched deltas. Global delta count may remain nonzero. Position owner, ticks, and salt remain fixed. |
| FS-A20 | Borrowed input is self-funded, `pretransferred` is false, and code-less/context-invalid callers reject with the specified context or funding error. Value fails at the nonpayable boundary. |
| FS-A21 | An unlocked caller lacking input or share ownership cannot mint or burn another holder's shares. The unlock flag and parked vault shares confer no authority. |
| FS-A22 | Bundle-in, bundle-out, donate, and compound reject borrowed unlock with `ManagerAlreadyUnlocked`. Paired and SY mutators remain absent. |
| FS-A23 | A reverting borrowed operation restores shares, liquidity, fee/booked accounting, and token balances. |
| FS-A24 | Attempt identity `token == this vault` binding. If the hook rejects without `asset()`, record the cited FS-HOOK-04 rejection rather than add the selector or claim success. |
| FS-A25 | Buffered mint/redeem works while unlocked with the hook or unwrap user as recipient. Test the accepted external provider for each underlying target and token0/token1 placement. Fee and booked claims follow FS-MONEY-01; provider requirement alone is not an incompatibility. |
| FS-A26 | The canonical disjoint-backing-pool fixture completes exact-input `zeroForOne` and `oneForZero`. No exact-output success is claimed. |
| FS-A27 | Every FS-HOOK-01 family has its representable proof or a cited topology rejection. Integration matrix rows and executable tests are added without weakening other families. Rejection does not replace FS-A26. |
| FS-A28 | A hook path invoking `exchangeOut` reverts and pays neither token. Its zero preview is not a success promise. |
| FS-A29 | Deploy target-specific external rate-provider instances via the accepted DFPkg. Two pools can hold the same vault with different underlying targets. No provider cap, vault provider storage/getter, or vault rate facet is added. |
| FS-A30 | Batching with other V4 pools is permitted. Disjoint-pool evidence does not falsely certify same-backing-pool sequential composition. |
| FS-A31 | Claimed transactions, including hook composition, fit 12,000,000 gas; previews fit 5,000,000. Oversized routes remain unresolved. No undocumented quote-step cap, spacing restriction, or partial quote is introduced. |
| FS-A32 | Busy/unlocked economic views compute values without coded vault reverts. Unsupported/unknown routes return zero. Reserve views read live deployed amounts plus unpaid fees, with no local term or snapshot. Exit previews use execution's fee/booked apportioning and swap; mint previews exclude existing-fee credit. |
| FS-A33 | Locked and borrowed executions from the same economic state use identical accounting and settlement, with no automatic compound, sleeve, or collection-only fallback. Authorized maintenance processes one token by the required swap/add and two tokens by a proportional no-swap add, booking actual held remainder. |
| FS-A34 | A nonzero own delta at borrowed entry rejects. Each action closes only this diamond's deltas; outer debts remain the outer caller's responsibility. |
| FS-A35 | Native borrowed settlement syncs immediately before value settlement, does not double-count backing, and does not spend another actor's sync credit. |
| FS-A36 | Propagated outer failure restores the operation. A caught rejected vault call restores the vault while preserving only the outer caller's prior effects and settlement obligations. |
| FS-A37 | A funded non-hook contract meeting borrowed-context rules succeeds without an allowlist. Separately, maintenance accepts only current live `feeTo()` or an authorized `OperableRepo` operator; a stale stored owner gains no authority. |
| FS-A38 | Disabled issuance still permits supported exits. Fee previews/minima use net shares and the same 30% clamp as execution; pass-through swaps take no usage fee. Zero and `1e13` WAD fees preserve their configured meaning. |

The acceptance suite also covers the following locked cases within the corresponding rows:

- For FS-A07 and FS-A21, cover APEX-2026-039 exclusions: no whole-balance sweep beyond the declaration, no booked-backing pretransfer, no parked-share burn, and no EOA pretransfer.
- For FS-A05, FS-A11, and FS-A38, cover APEX-2026-044: supply increases by gross new shares only, plus genesis floor when applicable; a deposit/redeem round trip does not transfer existing holders' value to `feeTo`. Do not add an oracle fee restriction or exit fee as the remedy.
- For FS-A08 and FS-A19, cover APEX-2026-024 by proving the swap quantity is only the exiting claim, not the whole opposing vault balance. The unbounded price limit remains.
- For FS-A33 and FS-A37, show absence of permissionless sleeve placement from APEX-2026-023, while preserving and disclosing the accepted sandwich exposure on an owner/operator maintenance call. Do not assert that all live-price exposure is absent.
- For FS-A31, cover APEX-2026-041 dust-tick liveness with normal deposit and redeem and no undocumented step limit. For FS-A32, check quote/execution alignment rather than introduce a quote-only promise that execution rejects.
- For FS-A33, cover APEX-2026-048: a no-fee/no-booked-balance compound returns unchanged without events; an undeployable remainder is booked without freezing a later route; a failed step still reverts.
- For FS-A06, FS-A11, and FS-A33, test the exact event signatures and triggers: successful donate emits `Donation()`; collected-fee/booked-token deposits emit `Compounded()`; a pure fresh donation is not mislabeled fee-origin storage; a booked donation remainder qualifies on later deposit. No swap/liquidity event is duplicated by the vault.
- For FS-A33 and FS-A37, test zero-supply donation rejection, caller-authorized share burning without withdrawal, no deployment-position swap, ratio-relative scarcity, actual-balance booking including stray transfers, and live owner changes with persistent operator authorization storage.
- For FS-A25, FS-A29, and FS-A32, exercise the six fail-closed sites and three ABI bindings from section 6 and migrate every other actual one-word reader in the index. A valid tuple must not be rejected merely for having 64 bytes. Do not change the selectors or exact-output return width.

Compare total supply, holder balances, position state, booked and reserved custody, wrapper balances, and per-address deltas. A claim of no token movement alone is insufficient. Audit dispositions must distinguish a removed mechanism, a tested invariant, an accepted residual exposure, and an unverified result.

## 9. Non-goals and limits

This PRD does not itself authorize implementation, deployment, a registry migration, a functional hook redesign, a Weir source copy, a Wings range, a second pool, a transition-quote facet, a zap cap, a tick guard, a sleeve, a vault rate, or Weir's treasury performance fee.

No audit result or gas measurement is claimed. Tests of the deleted family do not certify this implementation. Disjoint-pool hook tests do not establish same-pool sequential safety.

Owner/operator maintenance remains exposed to live-price sandwiching of fees, donations, or booked remainder; the deployed position is not sold by that maintenance. Entry and exit limits remain unbounded. Caller minima and the exiting-claim quantity restriction do not become a new price guard. Do not claim an accepted residual mechanism is absent.

This replacement records owner requirements, not new council unanimity. Historical advisory disagreements do not override later locks.

## 10. Participation

This replacement is the independent Astra contribution to `se-fullspread-prd-rewrite-20261103`. Requested role: `council-member`; requested route: `chatgpt-subscription/gpt-6-astra:high`; actual runtime identity: not exposed. No peer response was read before submission. No advisory pass on this replacement is claimed.

For provenance, the prior PRD recorded the following earlier drafting/advisory participation; these are historical records, not approval of this replacement:

| Member | Requested route | Original task | Historical advisory |
| --- | --- | --- | --- |
| Astra | `chatgpt-subscription/gpt-6-astra:high` | `st_01a18d05` | REQUEST CHANGES |
| Grok | `xai/grok-4.7:xhigh` | `st_01a18d06` | SUPPORT WITH CORRECTIONS |
| MiniMax | `minimax/MiniMax-M3` | `st_01a18d07` | SUPPORT WITH CORRECTIONS |
| Kimi | `kimi-coding/k3.1-pro:high` | `st_01a18d08` | REQUEST CHANGES |

The earlier coordinator used invoking-agent mode and was not a fifth independent vote. Runtime provider internals were not independently attested in the supplied document. The current coordinator alone compares originals and controls any later PRD publication.

# Limits

- Only this assigned response file was written. The current PRD, blockers, directive, brief, and other members' files were not edited.
- This is a document-based proposal. No Forge, tests, installation, deployment, wallet operation, Git command, or sub-agent was used.
- The complete index was retrieved, but its source files were not re-audited. Consumer locators and behavior are attributed to the admitted consumer report, not to independent source inspection.
- Required source files were readable. Index reads beyond its actual 629 physical lines returned end-of-file errors; the complete index was already available from the bounded reads covering lines 1-629. The 1,626 figure is an occurrence count.
- No new economics, event fields, error signatures, or selector values were computed. The named wrapper-boundary validation and retained dispatch restrictions come from the current PRD where no later lock removes them.
- The response neither replaces the current PRD by itself nor authorizes implementation. It ends this initial independent drafting assignment.
