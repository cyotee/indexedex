# Member response

## Identity

- Member: minimax
- Profile: research
- Phase: initial independent response
- Owned path: `docs/research/se-fullspread-prd-rewrite-20261103/members/minimax/response.md`
- Requested role: council-member
- Requested model: `minimax/MiniMax-M3`
- Adaptive thinking: requested by the council skill; the runtime did not expose that setting here, so it is recorded as **not exposed** and the work continued.
- Runtime identity: **not exposed** for any runtime identity the assignment did not give me (provider, account, reasoning mode, task id, session id).
- Peers read before submission: **no**
- Writes performed: this file only. No PRD, blockers, directive, brief, or peer file was edited. No Forge, test, install, deploy, wallet, or Git action was run.

## Question and targets

Question: what is the single replacement text for the full-spread vault PRD, copied from the locked decisions?

Targets I worked from, in authority order (later override wins):

1. `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`, including its 2026-11-03 owner overrides (F1, F2, F5, F6, F7, F12).
2. `docs/vaults/PRETRANSFER_DIRECTIVE.md`.
3. `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` — the current PRD, whose section order and requirement IDs I keep.
4. `docs/research/se-fullspread-preview-consumers-20261103/REPORT.md` and `INDEX.md` — the preview-consumer inventory the PRD pass must carry.
5. `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md` — the accepted return ABI.

Conclusions below is the complete replacement PRD text, not an edit list.

## Evidence

### Source observation (what I read, and what it states)

| Source | What it states that the replacement text carries |
| --- | --- |
| `IMPLEMENTATION_PLAN_BLOCKERS.md`, 2026-11-03 owner overrides | F1: a caller's maximum larger than the unbooked balance refunds that unbooked balance, spends none of it, pulls no shortfall, and is not a revert. F2: a share-minting deposit books `feesAccrued` and does not deploy, swap, or credit them; on a withdrawal the caller owns `shares burned / total shares` of `feesAccrued` and of each booked balance, measured before the burn and rounded down; a one-token exit swaps the caller's opposing-token fee and booked claim with the withdrawn unwanted reserve and pays the requested-token fee and claim; the exit preview uses the same apportioning and the same swap; a mint preview credits no existing fees. F5: a one-sided deposit and a one-token `donate` or `compound` choose the greatest liquidity the following add can take; the swap output is the other token that liquidity consumes; the unswapped input is the processed token that liquidity consumes; rounding leaves a remainder in the input token; the swap input is not the processed-token amount the add consumes; the 48% remark is not a required refund and not an exit rule. F6: a one-token exit converts all unwanted withdrawn principal plus the caller's opposing-token fee and booked claim into the selected token, or reverts `AmountOutNotMet` without burning shares; it does not pay, book, or keep the residual. F7: emit `Donation()` on `donate()`, emit `Compounded()` when a deposit is made from collected fees or booked tokens, no fee-origin store, `Compounded()` has no fields. F12: owner authority is a live check that the caller is the address `feeTo()` currently returns, with new ownership and operable modifiers, `OperableRepo` reused for operator authorizations, and the stored-owner initialization sentence replaced. |
| `IMPLEMENTATION_PLAN_BLOCKERS.md`, B-01 | The usage fee is taken from the new deposit's gross shares, never minted on top; the floor mint to `address(0)` is separate; a resolved usage fee above 30% is used as 30% (`3e17` WAD); previews and `minAmountOut` use the depositor's net shares; a pass-through takes no fee; `mulDiv` against `1e18` is the calculation, with no minimum fee and no three-digit rounding. |
| `IMPLEMENTATION_PLAN_BLOCKERS.md`, B-02 | The sleeve is dropped: no `liquidReservePercentageOfVault` target, no local balance move, no `localReserves()`. `compound()` is restricted to the owner or an operator. A deposit, a withdrawal, and `exchangeIn` do not call `compound()`. Entry and redemption swap limits stay unbounded. A redemption swaps only the withdrawn net. The batch-swap exclusion is removed. |
| `IMPLEMENTATION_PLAN_BLOCKERS.md`, B-03, B-05, B-11, and the 2026-11-02 booking lock | A call with no fees, no donation, and no booked remainder returns with no state change and no event. `donate` is owner-or-operator, one-token donations swap only their own tokens into the position ratio, a two-token donation is a proportional deposit without a swap, a zero-supply donation reverts, a remainder is booked rather than returned, and booked total is the actual held balance with a zero-size add skipped and a failed step reverted. |
| `IMPLEMENTATION_PLAN_BLOCKERS.md`, B-06 | No view reverts by a vault error; an unsupported view route returns zero; `previewExchangeOut` returns zero while `exchangeOut` still reverts `ExchangeOutNotAvailable()`; a busy or unlocked manager is not a view revert; `reserves()` and `reserveOfToken` wrap the deployed-reserve reads with no local term and no last-committed snapshot. |
| `IMPLEMENTATION_PLAN_BLOCKERS.md`, B-07, B-08, B-09, B-10, B-12, B-13 | The seven Uniswap V4 addresses are package immutables written once into the instance Protocol Aware Repo, and the aware facet and the `UniswapV4SinglePositionAware` pair are Crane package inputs with externally callable getters. A hook leg uses an externally deployed rate-provider instance that this vault does not know. A borrowed unlock pulls the caller's deployed fraction, with no sleeve fallback and no `UnderlyingUnavailable`. The deployed reserve is one raw liquidity number: first-deposit shares are `added liquidity - 1,000`, later mints are `added liquidity * totalShares / existing liquidity`, burns are `liquidity * shares / totalSupply`, and token decimals do not enter the share formulas. Bundle routes emit `PairDeposited(address indexed caller)` and `PairRedeemed(address indexed caller)`. A pretransfer uses the unbooked balance up to the caller's maximum, under the directive's refund rules. |
| `docs/vaults/PRETRANSFER_DIRECTIVE.md` | A pretransfer uses the unbooked held balance, not a booked remainder; within the unbooked balance the refund is the maximum minus the amount used in the token provided; above it the refund is the unbooked balance, with no shortfall pull; a balance sitting on the vault is not credit beyond the declared maximum; the unbooked remainder is not sent to `msg.sender`; a burn uses the caller's shares; an address without bytecode cannot pretransfer. |
| `docs/research/se-fullspread-preview-consumers-20261103/REPORT.md` | Six production consumers reject a non-32-byte success, with the paths and lines named below; three ABI bindings still declare one word; `INDEX.md` holds 1626 occurrences across 618 files. |
| `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md` | `previewExchangeIn` and `exchangeIn` keep their parameters and selectors `0x89d61912` and `0xd02d3063` and return `(uint256 amountOut, uint256 amountRefunded)`; no `WithRefund` sibling exists; the bundle interfaces are accepted as written; `exchangeOut` is not given a refund return. |

### Direct verification I performed

I re-read each consumer the report names, so the paths and lines below are source observation, not citation of the report alone:

- `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol` lines 103-106 (`if (!ok || data.length != 32) return 0;`) and 121-125 (`if (!ok || data.length != 32) return (false, 0);`).
- `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/wrapped/WrappedStandardExchangeRateProviderTarget.sol` lines 65-68 (`if (!ok || data.length != 32) return (false, 0);`).
- `contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolHookTarget.sol` lines 437-444 (`if (!ok || ret.length != 32) return false;`).
- `contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolHookTarget.sol` lines 463-470 (same gate).
- `contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolHookTarget.sol` lines 474-481 (same gate).
- `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` lines 45-48 (`returns (uint256 amountOut);`).
- `frontend/apps/indexedex/app/insights/lib/insightsAbi.ts` lines 69-76 (`outputs: [{ type: 'uint256' }]`).
- `frontend/packages/protocol/src/protocolDetfAbi.ts` lines 33-40 (`outputs: [{ name: 'amountOut', type: 'uint256' }]`).
- `contracts/test/bases/FundedThresholdAssertions.sol` lines 60-63: a one-word `abi.decode` with no length check, so a 64-byte return is misread as the first word rather than rejected.

### Inference (my reading, stated as such)

- Inference: the "greatest liquidity the following add can take" wording in F5 and the "position ratio" wording in the 2026-11-02 booking lock describe one sizing rule — the add's consumption of each token, measured against the position ratio, with the swap supplying the other token and the processed token split between the swap and the add. I did not restate a ratio formula that the locks do not give.
- Inference: F6 scopes the old no-leftover-shortfall-revert sentence to the former sleeve, and the sleeve no longer exists, so that sentence has no home in the replacement text; the one-token exit instead reverts `AmountOutNotMet`.
- Inference: because B-07 makes the seven Uniswap V4 addresses package immutables, `PkgInit.poolManager` is no longer a per-instance field, and FS-OWN-16 is replaced accordingly.

## Assumptions

1. "Later override wins" is applied inside the blockers file, and the blockers file outranks the current PRD. Where a later lock contradicts an earlier sentence of the same lock, the later one is the text.
2. Requirement IDs are preserved wherever the requirement remains. A requirement whose subject is replaced keeps its ID and takes the replacement text (FS-OWN-04, FS-OWN-12, FS-OWN-13, FS-OWN-14, FS-OWN-15, FS-OWN-16, FS-OWN-17, FS-OWN-18, FS-OWN-19, FS-OWN-20, FS-OWN-21, FS-OWN-24, FS-OWN-25, FS-OWN-27, FS-OWN-29, FS-OWN-30, FS-OWN-31, FS-OWN-32, FS-OWN-33). FS-OWN-01, FS-OWN-02, FS-OWN-06, FS-OWN-07, FS-OWN-08, FS-OWN-09, FS-OWN-10 keep their IDs with the sentences a later lock contradicts replaced.
3. F12 is an owner answer, so it is stated as a requirement next to the other owner answers: I added FS-OWN-34 for the live `feeTo()` owner check and the operator authorization, and referenced it from FS-OWN-14 and FS-OWN-21.
4. The brief's filled readings are treated as lock text: `Donation()` has no fields; a both-token exit pays the caller's claim in both tokens and does not swap; an exit preview uses the same apportioning as execution and is the share valuation; a mint preview does not credit existing fees to the new depositor.
5. The F-items referenced by the blockers file but stated only in the owner-decisions chain (F11, and the accepted F3/F4/F8/F9/F10) are used only where the blockers file itself repeats their effect. F11's one-token exit on a borrowed unlock appears in the blockers file as B-09's borrowed-exit rule and in its already-locked list, so it is carried on that basis.
6. I did not restate a `donate` parameter list, because the current PRD never states one and no admitted lock gives one.
7. The stray fragment `good thing I had them` at the end of the FS-OWN-10 row of the current PRD's section 1.2 table is not a requirement and is dropped. No other wording outside a contradicted sentence was changed.
8. Three places in the current PRD contradict a lock rather than a single sentence, so I corrected them: the section 4 file list still named SY money and SY query facets after FS-OWN-05 dropped them; the section 4 validation list still named the wrapped-native argument after `PkgInit.wrappedNative` was removed; and the section 4 validation list still named "outside the inherited domain" after FS-OWN-22 deleted that phrase. All three are removed in the replacement text.
9. The two Crane package-input fields in FS-FACET-01 are named `uniswapV4ProtocolAwareFacet` and `uniswapV4SinglePositionAwareFacet`, derived from the locked pair names and the existing field-naming convention of that table. The locks fix the pairs and their role as package inputs; they do not name a `PkgInit` field.
10. The revision label `fullspread-se-prd-locked-r1` is my proposal for the coordinator's single edit. It is document metadata, not a product decision.
11. `localReserves()` disappears because the sleeve is dropped and B-07 says the position facet does not restore it. It is absent, not relocated.

## Coverage

| Target | Status | Note |
| --- | --- | --- |
| Current PRD section order and requirement IDs | covered | Sections 1 through 10 keep their order; IDs preserved where the requirement remains; one ID added (FS-OWN-34) for the F12 owner-authority answer, which had no home. |
| 2026-11-03 overrides F1, F2, F5, F6, F7, F12 | covered | F1 in FS-OWN-32 and FS-OWN-20; F2 in FS-OWN-30 and FS-MONEY-01 and section 6; F5 in FS-OWN-33, FS-OWN-25, FS-MONEY-01; F6 in FS-OWN-30 and FS-MONEY-01; F7 in FS-OWN-14 and FS-OWN-21; F12 in FS-OWN-34, referenced by FS-OWN-14 and FS-OWN-21. |
| Blocker decisions B-01 through B-13 and the 2026-11-02 booking lock | covered | Each lands in the requirement it replaces; the lock-to-requirement map is in the table under Evidence. |
| Pretransfer directive | covered | FS-OWN-20, FS-OWN-32, FS-MONEY-01, and the F1 refund rule in FS-OWN-32. |
| Six fail-closed preview consumers, with path and line | covered | FS-OWN-08, re-read at source. |
| Three one-word ABI bindings, with path and line | covered | FS-OWN-08, re-read at source. |
| Every other one-word reader of `previewExchangeIn` in `INDEX.md` | covered | FS-OWN-08 states the migration to `(uint256 amountOut, uint256 amountRefunded)`; the index itself is cited by path and count, not pasted. |
| `previewExchangeIn` and `exchangeIn` selectors and tuple return | covered | FS-OWN-08, FS-MONEY-01, section 6, FS-A39. |
| `exchangeOut` and `previewExchangeOut` gain no refund return | covered | FS-OWN-08, FS-FACET-01, FS-A09, section 6. |
| Peer responses | not read | Prohibited for this phase. |
| Public search | not used | No excerpt left the workspace. |
| Forge, tests, installs, deploys, wallets, Git | not run | Prohibited for this phase. |

## Conclusions

The complete replacement PRD text follows. It replaces the current PRD file in full.

```markdown
# Uniswap V4 full-spread Standard Exchange vault PRD

Revision **fullspread-se-prd-locked-r1**. Coordinator revision after the member replacements for run `se-fullspread-prd-rewrite-20261103`. It carries the owner locks of 2026-10-30, 2026-11-01, 2026-11-02, and the 2026-11-03 overrides. The prior revision `fullspread-se-prd-weir-align-r1` remains the history of the owner locks. This file is not member-approved text, not an implementation, and not a safety clearance. Owner locks FS-OWN-01 through FS-OWN-34 and the later owner answers in `IMPLEMENTATION_PLAN_BLOCKERS.md` override a conflicting sentence, and a later override wins over an earlier one. The alignment record is `docs/research/se-fullspread-prd-weir-align-20261031-01a18660/`.

## 1. Goal

Build `UniswapV4FullSpreadStandardExchangeVault`.

One registry-deployed Crane diamond owns one Uniswap V4 pool key, one full-range position, the booked balances of that position, and one ERC-20 share supply. The diamond is the position owner. Public shares are proportional claims on that basket.

This family adapts the cited money operations of `contracts/protocols/strategy/weir/WeirVaults.sol` to the tokenized Standard Exchange standard. It has one ERC-20 share, one pool, and one full-range position. It does not copy Weir's manager of many virtual vaults.

It is not a sibling of PairToken and does not inherit PairToken economics by requirement ID. FS-OWN-01 through FS-OWN-34 stay locked. A PairToken economic or package choice stays only where one of those locks already keeps it.

### 1.1 What this family is not

- Not a source copy of Weir's multi-vault manager, and not a mechanical wrapper around its internal share ledger.
- Not Upper/Lower Wings. No second range and no rebalance facet.
- Not a singleton of many pools, a second share ledger, or a shares-of-shares wrapper.
- Not an ERC-4626 product. Do not install `asset()`. Current hooks treat that selector as wrapper-share inventory. Adding it to turn a rejected identity bind into a pass is forbidden.
- Not a hook-package redesign. A hook change is FS-HOOK-04, raised only with a cited rejecting function.

### 1.2 Deltas

| ID | Delta |
| --- | --- |
| FS-X01 | Canonical exact-input `exchangeIn` executes while the bound PoolManager is already unlocked, without a nested `unlock`. Ordinary user entry still opens its own unlock, once per planned manager action. |
| FS-X02 | Withdrawn by FS-OWN-03. Do not install `getRate`. There is no designated `rateAsset` to denominate it. |
| FS-X03 | Tests place this share with another SE vault share in the current buffer-hook families, using the fixture in FS-HOOK-02. Those hook packages are not edited here. |
| FS-X04 | Single-token entry does not require the selected swap to consume its entire input. There is no `IncompleteConversion` check. Unused declared input is returned to the payer. A positive swap credit is returned to the depositor and is not booked without shares. Accrued fees collected by a share-minting deposit are booked, not credited to the depositor and not swapped into the deposit. Issuance follows FS-MONEY-01, not S1-ACC-07. This row does not change the accepted one-token exit. |
| FS-OWN-01 | `poolManager()` is not a family query. The diamond uses the Uniswap V4 Protocol Aware Repo and Facet, implemented and tested in Crane, as a package input. Its getters are externally callable on this vault. |
| FS-OWN-02 | Pool-key and position identity live in the reusable Crane pair `UniswapV4SinglePositionAware`, a Repo and a Facet, not a full-spread-only getter. Its getters are externally callable on this vault. |
| FS-OWN-03 | Do not implement `rateAsset()`. This family designates no single token for valuation or operations. |
| FS-OWN-04 | There is no local liquidity sleeve. No `liquidReservePercentageOfVault` target, no local balance move, and no `localReserves()` getter. |
| FS-OWN-05 | Do not install ERC-5115. Drop `syMoneyFacet` and `syQueryFacet`. |
| FS-OWN-06 | Store `tickLower`, `tickUpper`, and the position salt in the `UniswapV4SinglePositionAware` Repo. Wrap PoolManager for `positionLiquidity()`. |
| FS-OWN-07 | `IBasicVault.reserves()` is not installed. The family `reserves()` and `reserveOfToken` are deployed-only views: the position's token amounts plus unpaid fees, with no local term and no last-committed snapshot. |
| FS-OWN-08 | `previewExchangeIn` and `exchangeIn` keep their parameters and return `(amountOut, amountRefunded)`. No `WithRefund` sibling. The old 32-byte preview return is migrated in every consumer named below. |
| FS-OWN-09 | Do not keep `depositPair`, `previewDepositPair`, `redeemPair`, or `previewRedeemPair`. Map them to the accepted bundle routes. Keep `donate` and `compound`. `donate` is an explicit exception and is not a Weir function. `compound` is Weir harvest-and-reinvest, not a PairToken ratio swap. The bundle routes emit `PairDeposited(address indexed caller)` and `PairRedeemed(address indexed caller)`. |
| FS-OWN-10 | Do not implement `previewWithdrawalMode` or a family `wrappedNative()` getter. `previewZapCredit`, `maxZapBps`, and `maxZapTickMove` are absent. No replacement view, cap, or tick bound is added. `PkgInit.wrappedNative` is removed. |

### 1.3 Owner-locked decisions

These owner decisions are locked. They override every conflicting sentence in this file. They do not implement the repos. The previously open zap views are closed as absent by this revision. That is not a new design.

**FS-OWN-01.** `poolManager()` is not a full-spread family query. It belongs to a new Protocol Aware standard: one Repo and one Facet that store and expose the external components of one protocol. For Uniswap V4 that pair is created under `lib/crane/contracts/protocols/dexes/uniswap/v4/aware`. The V2 aware repos are the storage example. V2 uses one repo per component. This standard keeps the protocol's components in one pair, including the PoolManager, the Universal Router, and any other V4 component an integrator needs. The facet is implemented and tested in the Crane submodule, and this vault's package takes it as a package input and uses it to initialize the vault instances. The getters on that facet are externally callable on this vault. The seven Uniswap V4 addresses are package immutables, and one initialization write puts them into the instance Protocol Aware Repo. Do not implement a family `poolManager()` selector.

**FS-OWN-02.** `poolKey()` is not a family-only getter. It belongs to the reusable Crane pair `UniswapV4SinglePositionAware`: one Repo and one Facet for one position in one pool, usable by other vaults with a different pool or a different range. It is a package input on this vault and its getters are externally callable. The full-spread query facet carries no `poolKey()` selector. The Repo stores the full `PoolKey` for the vault instance, plus `tickLower`, `tickUpper`, and the position salt, because a `PoolKey` identifies the pool and not the position. Those four values are instance storage, written when the package initializes the vault. They are not package immutables, because another vault can use another pool or another range. This vault's range is the full-range position and its salt is `bytes32(0)`. `PkgArgs` still carries the pool key used at initialization.

**FS-OWN-03.** Do not implement `rateAsset()`. This vault does not designate one token for valuation or for operations. `PkgArgs` has no `rateAsset`. Do not install `getRate` into a rate asset, and do not add the rate errors that existed only for that function. A later decision may name a rate policy. This lock does not name one.

**FS-OWN-04.** There is no local liquidity sleeve. Do not keep a target from `IVaultFeeOracleQuery.liquidReservePercentageOfVault`, do not move a local balance toward such a target after a deposit, a withdrawal, or `compound()`, and do not install `localReserves()`. The sleeve, its target, its refill, its shortfall, and the question whether a locked caller may spend it are closed. This overrides the earlier sleeve lock. A local balance that exists is a booked balance, and it is governed by FS-OWN-20 and FS-MONEY-01.

**FS-OWN-05.** Do not install ERC-5115. There is no underlying LP token, so `IStandardizedYield` is invalid here. Drop `syMoneyFacet` and `syQueryFacet`, including `deposit`, `redeem`, `exchangeRate`, and the other Standardized Yield selectors. This is an authorized divergence from the SE package. It confirms FS-OWN-03. Do not replace the dropped rate with NAV or another denomination.

**FS-OWN-06.** Keep `tickLower()` and `tickUpper()`. PoolManager position state does not store them; they are inputs to the position key. Store them in the `UniswapV4SinglePositionAware` Repo of FS-OWN-02, with the position salt. Keep `positionLiquidity()`. It returns only the liquidity deployed in this vault's position. Wrap `StateLibrary.getPositionInfo` for this diamond, the stored ticks, and the stored salt. That read returns `uint128` liquidity. It is not a token amount, not a local balance, and not the whole pool's liquidity.

**FS-OWN-07.** Do not implement `basket()`. `reserves()` returns the deployed amount of each vault token, in `vaultTokens()` order. `reserveOfToken(address)` returns that same amount for one token. It is not a local balance. Reuse `vaultTokens()` from `MultiAssetBasicVaultFacet`. Do not reimplement it. The custom facet exposes only `reserveOfToken` and `reserves`. The cut maps `vaultTokens` to `MultiAssetBasicVaultFacet` and the other two selectors to the family facet. Do not install the multi-asset reserve functions. They read a stored balance in slot `indexedex.vaults.basic`, and that balance is not this view. The deployed term is locked. For each underlying token it is the amount implied by this position's liquidity, the current pool price, and the stored ticks, plus fees owed to this position in that token and not yet collected. PoolManager stores liquidity and fee growth, not those amounts. Do not add a new conversion formula. Use the existing position-amount and fee-owed reads. There is no local term and no last-committed snapshot. A booked local remainder is not in this read until a later `donate()` or `compound()` deploys it.

**FS-OWN-08.** The accepted Standard Exchange definition is in `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md`. `previewExchangeIn` and `exchangeIn` keep their current parameters and return `(uint256 amountOut, uint256 amountRefunded)`. There is no `WithRefund` sibling. Selectors stay `0x89d61912` and `0xd02d3063`. The other vaults must be updated to that return ABI. The bundle interfaces in that report are accepted for the standard. `exchangeOut` does not gain a refund return.

A successful `previewExchangeIn` return is 64 bytes. The following six production consumers treat a 64-byte success as failure. Each must read the tuple:

| Consumer | Path and lines | Current gate |
| --- | --- | --- |
| Standard Exchange rate provider, empty-supply preview | `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol` lines 103-106 | `staticcall`, then `data.length != 32` returns 0 |
| Standard Exchange rate provider, live preview | `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol` lines 121-125 | `data.length != 32` returns `(false, 0)`, then a one-word `abi.decode` |
| Wrapped Standard Exchange rate provider target | `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/wrapped/WrappedStandardExchangeRateProviderTarget.sol` lines 65-68 | `data.length != 32` returns `(false, 0)` |
| Stable common-buffer multi-vault hook target | `contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolHookTarget.sol` lines 437-444 | `ret.length != 32` returns false, then a one-word decode |
| Stable mixed-buffer multi-vault hook target | `contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolHookTarget.sol` lines 463-470 | same gate |
| Weighted common-buffer multi-vault hook target | `contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolHookTarget.sol` lines 474-481 | same gate |

The following three ABI bindings still declare one word and must declare `(uint256 amountOut, uint256 amountRefunded)`:

| Binding | Path and lines | Current declaration |
| --- | --- | --- |
| Crane Standard Exchange interface | `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` lines 45-48 | `returns (uint256 amountOut)`, comment selector `0x89d61912` |
| Insights frontend ABI | `frontend/apps/indexedex/app/insights/lib/insightsAbi.ts` lines 69-76 | one `uint256` output |
| Protocol DTF frontend ABI | `frontend/packages/protocol/src/protocolDetfAbi.ts` lines 33-40 | one `uint256` output named `amountOut` |

Every other one-word reader of `previewExchangeIn` in `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md` migrates to `(uint256 amountOut, uint256 amountRefunded)`. That index holds 1626 occurrences across 618 files and is the complete occurrence list, so it is wider than the decoder list. `contracts/test/bases/FundedThresholdAssertions.sol` lines 60-63 decode one word without a length check, so a 64-byte return is misread there as the first word rather than rejected; it migrates with the rest. This vault does not edit those consumers.

**FS-OWN-09.** The owner accepted the council recommendation in `docs/research/se-paired-money-necessity-20261030-01a18660/REPORT.md`. Do not install `depositPair`, `previewDepositPair`, `redeemPair`, or `previewRedeemPair`. Map deposit to `exchangeBundleInForSingleOut` and `previewExchangeBundleInForSingleOut`, with `tokenOut` as the share. Map redeem to `exchangeBundleOut` and `previewExchangeBundleOut`, with `tokenIn` as the share and `tokensOut` as the two ERC-20 faces. Keep `donate` and `compound`. `donate` is an explicit exception. `WeirVaults.sol` has no `donate`, and keeping it does not restore PairToken issuance. `compound()` stays this selector. Its behavior is harvest and reinvest, as in `_compound`, without a PairToken ratio swap or quarter-cap, and without Weir's treasury performance fee. The mapped redeem removes both currencies proportionally. It does not sell one leg to pay the other. A bundle deposit emits `PairDeposited(address indexed caller)`. A bundle redeem emits `PairRedeemed(address indexed caller)`. Those are the only arguments: the ERC-20 `Transfer` records the share mint or burn and the PoolManager events record the token amounts, so this vault does not repeat those amounts in the paired events. Paired events survive the selector drop. Raw ETH is not accepted or produced by this vault and no extension is added for it: callers send and receive WETH only, and native ETH is wrapped or unwrapped only at the pool boundary.

**FS-OWN-10.** The owner accepted the drop of `previewWithdrawalMode` and `wrappedNative()` from `docs/research/se-remaining-functions-20261030-01a18660/REPORT.md`. Do not install either selector. Payout quotes use the accepted previews. Do not move `wrappedNative()` to the Position Repo. The accepted routes use the ERC-20 face on `vaultTokens()`. `PkgInit.wrappedNative` is removed, so this lock does not decide where another package address binding is stored, and it does not publish an internal compound-or-collect branch. `previewZapCredit`, `maxZapBps`, and `maxZapTickMove` are absent. No replacement view, cap, tick bound, or hidden constant is added.

### 1.4 Owner answers locked 2026-11-01 through 2026-11-03

These answers are locked. They override every conflicting sentence in this file, including the raw-ETH sentence in FS-OWN-09 and the phrase "outside the inherited domain."

**FS-OWN-11.** The genesis floor is `MIN_SHARES` (`1_000`) minted to `address(0)`. That balance is part of `totalSupply()`. There is no second share ledger and no other holder.

**FS-OWN-12.** There is no local liquidity target and no post-operation balance move. After a deposit, a withdrawal, and a `compound()`, this vault does not move a local balance toward a percentage of an owned amount. FS-OWN-04.

**FS-OWN-13.** If nobody holds the PoolManager unlock, this vault calls `unlock()` and uses deployed liquidity first. If another caller already holds it, `unlock()` reverts `AlreadyUnlocked` and this vault must not call it. It may still call `swap` and `modifyLiquidity` on that open unlock. It never takes another caller's lock. On that open unlock it pulls the caller's deployed fraction directly and settles its own deltas before it returns. There is no sleeve fallback.

**FS-OWN-14.** `compound()` is restricted to the owner or an operator. Any other caller reverts. The owner check is a live read of the address `feeTo()` currently returns. FS-OWN-34. `compound()` has no donation input. It takes the collected fees and the booked remainder and processes that combined balance. FS-MONEY-01. A call with no fees, no donation, and no booked remainder returns with no state change and without an event. A booked remainder is still processed. When the call deposits from collected fees or from booked tokens, emit `Compounded()` once. `Compounded()` has no fields; the PoolManager events carry the amounts. A call that deposits nothing does not emit `Compounded()`. Booked tokens are treated as fees, including a donation remainder that was booked. There is no fee-origin store.

**FS-OWN-15.** A redemption takes deployed liquidity first and may swap through the pool. It swaps only the withdrawn net: the exiting holder's principal, plus that holder's share of the collected fees and of the booked claims of FS-OWN-30. It does not swap the other holders' booked fees, and it does not sell the staying holders' inventory. The swap limit stays unbounded. There is no new price check, tick bound, or fee cap.

**FS-OWN-16.** The seven Uniswap V4 architecture addresses are package immutables, set when that package is deployed, as the other package bindings are. They are the PoolManager, Position Descriptor, Position Manager, Quoter, State View, Reserves Lens, and Universal Router. `PkgInit.poolManager` is not a per-instance field. When the package initializes a vault instance, it writes those immutable addresses into the Uniswap V4 Protocol Aware Repo, in one write, and the repo is not given a second per-vault copy of the addresses. A deployment on another chain uses the same package code and passes that chain's addresses.

**FS-OWN-17.** Do not install `wrappedNative()`. Callers send and receive WETH only. The vault does not accept or produce native ETH. Native ETH is wrapped or unwrapped only at the pool boundary. The wrapper is the network `WETH` constant, `WETH9` on Robinhood. `PkgInit.wrappedNative` is removed.

**FS-OWN-18.** The Protocol Aware Repo stores the PoolManager, Position Descriptor, Position Manager, Quoter, State View, Reserves Lens, and Universal Router. Those seven addresses are the package immutables of FS-OWN-16. Do not hardcode them from `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol`; those constants are the Robinhood values, not the storage rule.

**FS-OWN-19.** `reserveOfToken` returns zero for an address that is not in `vaultTokens()`. No view reverts by a vault error, and an unsupported view route returns zero. A busy or unlocked manager is not a view revert. There is no local term and no last-committed snapshot. The deployed term uses the live position amount and unpaid fees.

**FS-OWN-20.** Unbooked token balances are not reserves and not redeemable idle. A pretransfer uses the unbooked held balance up to the caller's maximum. A booked remainder is not that balance. Redeemable idle is the booked counter, not `balanceOf`.

**FS-OWN-21.** `donate` accepts `vaultTokens()` and the share. `donate` is restricted to the owner or an operator, and the owner check is a live read of the address `feeTo()` currently returns. FS-OWN-34. A share donation burns the shares and does not withdraw, and it does not swap the shares. An underlying donation is deployed into the pool before `donate` returns. It is not left as idle. A one-token donation swaps its own tokens into the position's ratio and deploys that liquidity. It does not take the holders' opposite token. If the combined balance already holds both tokens, the call is a proportional deposit and does not swap. It uses the same unbounded price limit as the entry swap. It reverts when `totalSupply` is zero. No shares are minted. A remainder is booked, not returned to the donor. `donate()` also compounds: it uses tokens already transferred when `pretransferred` is set and pulls the directed amount otherwise, and then it processes the combined balance of collected fees and the booked remainder. FS-MONEY-01. Emit `Donation()` when `donate()` is called. `Donation()` has no fields.

**FS-OWN-22.** `vaultTokens()` is PoolKey `currency0`, then `currency1`, with `WETH` substituted for native. The pool-key check is only that the pool is initialized on the bound manager and the hook is `address(0)`. Delete "outside the inherited domain."

**FS-OWN-23.** The diamond cut names the installed selectors. Do not install every selector exposed by `MultiAssetBasicVaultFacet`. `vaultTokens` is that facet. `reserveOfToken` and `reserves` are the family facet. FS-OWN-07.

**FS-OWN-24.** A new deposit's usage fee is taken from the shares that deposit mints. It is not an extra mint. If `feeTo` is not `address(0)`, let `grossShares` be the shares the deposit would mint before the fee, and let `feeShares = mulDiv(grossShares, usageFeeOfVault(address(this)), 1e18)`. Mint `feeShares` to `feeTo` and `grossShares - feeShares` to the depositor. Do not mint any shares beyond `grossShares`. If either amount is zero, skip that mint. This applies to a one-sided deposit and a bundle deposit, including the first deposit. On the first deposit, `grossShares` is `added liquidity - 1,000`. The 1,000-share floor is a separate mint to `address(0)`. It is not part of `grossShares`, and it is not a fee mint. Do not mint a fee on the fee shares. On a later deposit, supply grows only by `grossShares`; on the first deposit, supply grows by `grossShares` plus the floor. This vault clamps the usage fee it applies: a resolved fee above 30% is used as 30%, and a resolved fee of 30% or less is used as read. 30% is `3e17` in the WAD unit, where `1e18` is 100%. The clamp is in this vault's read. It does not write the oracle, and the Fee Oracle is not restricted. `previewExchangeIn`, `previewExchangeBundleInForSingleOut`, and `minAmountOut` use the depositor's net shares. The usage fee is charged only when this vault mints shares. A pass-through takes no fee. The required precision is 0.001%. Use the existing `mulDiv` against `1e18`; do not round the fee to three digits and do not add a minimum fee. A configured fee of zero stays zero. This is the Vault Fee Oracle usage fee. It is not Weir's treasury performance fee.

**FS-OWN-25.** A bundle deposit adds the declared amounts in proportion and returns the rest. It does not run Weir's `_balance` swap. `exchangeIn` does support an underlying-to-underlying swap on the bound pool, and that route is a pass-through: it abstracts the pool swap, mints no shares, and takes no usage fee. A one-sided deposit runs the balancing swap, sized by FS-OWN-33.

**FS-OWN-26.** Inbound issuance checks `IVaultRegistryDisableQuery.isDisabled(address(this))` and reverts `VaultDisabled(address)`, as `UniswapV2StandardExchangeCommon._requireNotDisabled` does.

**FS-OWN-27.** Share `decimals()` is 18. That is metadata. It is not a scale, and it is not an input to the mint or the burn. The deployed reserve is accounted as one raw liquidity number, and token decimals do not enter the share formulas. No amount scaled to a token's decimals, and no use of `decimals()`, enters the share formula. The stored share balance is the liquidity number from the formulas below. Do not multiply it, or the floor, by a constant to match `decimals()`.

**FS-OWN-28.** A missed deadline reverts `IStandardExchangeErrors.DeadlineExceeded(deadline, block.timestamp)` before any other work.

**FS-OWN-29.** This vault does not implement `getRate()`, and it does not know its rate providers. FS-OWN-03 stays closed. Do not install `StandardExchangeRateProviderFacet` on this vault, and do not bind that facet and call its result this family's rate. Rate-provider instances are deployed by `IStandardExchangeRateProviderDFPkg` for a configured Standard Exchange vault and rate-target pair, and that package's `PkgArgs` carry `reserveVault`, `rateSubject`, and `rateTarget`. One vault can have as many of those instances as it has `vaultTokens()`; that count is the maximum useful number, not an enforced limit. This vault stores no rate-provider address and exposes no rate-provider getter. The hook configures a rate-provider address for each Standard Exchange liquidity leg, and the required hook rows use that configured instance. The rate provider reads the accepted 64-byte preview tuple. FS-OWN-08.

**FS-OWN-30.** On the vault's own unlock, a redemption pays the caller's fraction of the deployed position, the caller's fraction of the accrued fees, and the caller's fraction of each booked balance. The caller's share of `feesAccrued` and of each booked balance is `shares burned / total shares`, measured before the burn and rounded down. Include that portion in the exit and book the rest for the other holders. In a one-token exit, the caller's opposing-token fees and opposing booked claim are swapped with the withdrawn unwanted reserve, and the caller's requested-token fees and requested booked claim are paid to the caller. A one-token exit converts all unwanted withdrawn principal, plus that opposing-token fee and booked claim, into the selected token, or it reverts `AmountOutNotMet` and does not burn shares. It does not pay, book, or keep that residual. A both-token exit pays the caller's claim in both tokens and does not swap. A caller-set minimum still reverts `AmountOutNotMet` or `MinAmountNotMet`.

**FS-OWN-31.** If another caller holds the unlock, this vault does not call `unlock()`. It calls `modifyLiquidity` and `swap` directly, pulls the caller's deployed fraction, and swaps only the withdrawn net on that same open flag. There is no sleeve payment and no `UnderlyingUnavailable` for an unpullable fraction. The vault settles its own deltas before it returns. The manager does not refuse that call; it fails only if this vault calls `unlock()` again, or if the hook never calls the vault.

**FS-OWN-32.** Input that does not become liquidity is refunded to the payer. It is not minted into shares and it is not left for the other shareholders. A pretransfer uses the unbooked held balance up to the caller's maximum. If that maximum is within the unbooked balance, the refund is the maximum minus the amount used, in the token the caller provided. If the maximum is larger than the unbooked balance, refund that unbooked balance, do not spend it, and do not pull the shortfall. A larger maximum is not a revert, and the caller may declare any maximum. An address without bytecode cannot pretransfer, and a caller that pretransfers outside an atomic operation does so at its own risk. The unbooked remainder is not sent to `msg.sender`. A burn uses the caller's shares. Shares parked on the vault are not pretransfer credit.

**FS-OWN-33.** A one-sided share mint, a one-token `donate`, and a one-token `compound` size their swap by the greatest liquidity the following add can take. The swap output is the other token that liquidity consumes. The unswapped input is the processed token that liquidity consumes. Rounding leaves any remainder in the input token. The swap input is not the processed-token amount the add itself consumes. A bundle deposit does not run that swap. It adds the declared amounts in proportion and returns the rest.

**FS-OWN-34.** Owner authority is a live check that the caller is the address `feeTo()` currently returns. It replaces stored-owner checks. Implement new ownership and operable modifiers for that check, and do not reuse the existing facets for it. Reuse `OperableRepo` to store operator authorizations. `donate()` and `compound()` are callable by that owner or by an operator authorized in `OperableRepo`. The stored `feeTo()` address is not the owner, and initialization does not store it as one. This replaces the 2026-11-02 sentence that initialization stores `feeTo()` as the owner `onlyOwnerOrOperator` uses.

## 2. Authority and precedence

| Source | Role |
| --- | --- |
| `contracts/protocols/strategy/weir/WeirVaults.sol` | Source of the deposit, withdrawal, issuance, and compound rules expressly stated in this PRD. Its multi-vault manager, administration surface, and treasury performance fee are not inherited. |
| FS-FACET-01 and FS-PKG-01 | This family's package inputs. No PairToken package field or economic rule is inherited. |
| `contracts/hooks/uniswap/v4/standardExchange/` | Current hook bindings. Do not redesign them here. |
| `IMPLEMENTATION_PLAN_BLOCKERS.md` in this directory | The owner decisions of 2026-11-01, 2026-11-02, and the 2026-11-03 overrides. A later override wins over an earlier sentence in that file. |
| `docs/vaults/PRETRANSFER_DIRECTIVE.md` | The pretransfer attribution and refund rule. It is binding on this PRD. |
| `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md` | The accepted return ABI and the accepted bundle interfaces. |
| `docs/research/se-fullspread-preview-consumers-20261103/REPORT.md` and `INDEX.md` | The consumers of the old 32-byte preview return. FS-OWN-08. |
| `CLAUDE.md`, `docs/agent/INDEXEDEX_AGENT_LAW.md`, `.github/ASSISTANT_CODING.md`, `.github/ASSISTANT_TESTS.md` | Registry, token, compiler, and test law. |
| Crane architecture, IndexedEx testing, and Uniswap V4 hook-package skills | Packaging and production-first tests. |

PairToken stage one is not an economics authority. Do not inherit S1-ACC-02, S1-ACC-07, S1-D03's dead-share sentence, S1-OP-02's zap caps, S1-OP-05's ratio swap and quarter-cap, S1-P05, S1-P07, S1-EXIT-01's collection-only fallback, S1-X15, or S1-X17. Issuance, entry settlement, compound, and idle are FS-MONEY-01. An unnamed PairToken economic clause does not survive because this file used to inherit by ID.

These constraints stay, and they are not PairToken economics:

- FS-X01 permits the already-unlocked path only for canonical `exchangeIn` and for a one-token exit, which is single-output `exchangeBundleOut`. `exchangeBundleInForSingleOut`, a both-token redeem, `donate`, and `compound` still revert `ManagerAlreadyUnlocked`. `depositPair` and `redeemPair` are not installed. There are no SY mutators.
- FS-OWN-05 removes every Standardized Yield selector. Do not replace `exchangeRate` with another denomination.
- FS-OWN-03 withdraws `getRate`. Do not install `IERC4626`, a transition quote, an external-state quote, or `IStandardExchangeRateQuote`.
- There is no local liquidity sleeve, no `liquidReservePercentageOfVault` target, and no `localReserves()` getter.
- The usage fee is taken from the new shares of a deposit that mints them. A pass-through takes no fee.
- `compound()` and `donate()` are owner-or-operator routes, and the owner check is a live `feeTo()` read.
- Hook bindings, compiler law, and registry law stay. Do not rewrite them to remove a PairToken filename reference.

Do not install `IStandardExchangeTransitionQuote`, `IStandardExchangeUnlockContextQuote`, or `IStandardExchangeExactOutputQuantityQuote` unless FS-HOOK-04 cites a consumer that rejects without one. The ordinary exact-input hook path must show the existing ERC-165-gated fallback to standard previews. A stub that returns live values for a projected state is forbidden.

### 2.1 Dispositions retained from advisory

| Topic | Final choice | Not adopted |
| --- | --- | --- |
| `getRate` | Withdrawn by FS-OWN-03. Not installed. | Keep the prior one-share formula. A thirteenth `RateFacet`. Return zero below one share. |
| Supply below `1e18` | Withdrawn with `getRate`. FS-OWN-03. | A live `InsufficientRateSupply` requirement. |
| Unlocked surface | Canonical `exchangeIn` only, plus a one-token exit as single-output `exchangeBundleOut`. | Borrowed unlock on compound, donate, bundle-in, or a both-token redeem. |
| Locked unlock count | One vault-started unlock per planned manager action. | One unlock per public call. |
| Recipient | Output may be paid to the hook's `recipient`, including a user on unwrap. | `recipient == msg.sender` as a hard rule. A hook allowlist. |
| Entry remainder | Unused input and a positive credit are returned to the payer. They are not booked without shares. A pretransfer refund follows FS-OWN-32. | `J_i` booking. `IncompleteConversion`. Every input wei becomes liquidity. |
| Local liquidity sleeve | Dropped. No target, no balance move, no `localReserves()`. | A percentage target and a local reserve getter. |
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

Crane package inputs, implemented and tested in the Crane submodule:

| Field | Selectors |
| --- | --- |
| `uniswapV4ProtocolAwareFacet` | The stored Uniswap V4 components, including `poolManager()`. Externally callable on this vault. FS-OWN-01. |
| `uniswapV4SinglePositionAwareFacet` | The stored `PoolKey`, `tickLower`, `tickUpper`, the position salt, and `positionLiquidity()`. Externally callable on this vault. FS-OWN-02, FS-OWN-06. |

Family facets:

| Field | Selectors |
| --- | --- |
| `moneyFacet` | `exchangeIn`, `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, `compound`. FS-OWN-09. Do not install `depositPair` or `redeemPair`. |
| `quoteFacet` | `previewExchangeIn`, `previewExchangeBundleInForSingleOut`, `previewExchangeBundleOut`. Do not install `previewZapCredit`, `previewWithdrawalMode`, or the paired previews. |
| `outFacet` | `previewExchangeOut`, `exchangeOut`. `previewExchangeOut` returns zero. `exchangeOut` reverts `ExchangeOutNotAvailable()` without taking funds or changing state. |
| `queryFacet` | No family `poolManager()`, no family-only `poolKey()`, no `rateAsset()`, no `getRate()` (FS-OWN-03), and no family `wrappedNative()` (FS-OWN-10). The protocol and position getters come from the two Crane package inputs. |
| `callbackFacet` | `unlockCallback`. |

`syMoneyFacet` and `syQueryFacet` are not package inputs. FS-OWN-05.

The old 61-selector count included `getRate` and is not the manifest. Recount from the current package after the function review closes. `linkedComponents()` is facet metadata, not an installed proxy selector. Cite the current package `_expectedSelectors` and S1-ARCH-04 when implementing. Do not invent selector hex in this PRD.

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
- one facet and one target file for money, quote, out, query, and callback. The target filename is `UniswapV4FullSpreadStandardExchangeVaultMoneyTarget.sol` and the same pattern for the others. Do not use a shortened literal `MoneyTarget.sol`.

`TestBase_UniswapV4FullSpreadStandardExchangeVault.sol` goes under the family's `test/bases/`. Specs go under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`.

Storage uses a new namespaced slot, `keccak256(abi.encode(namespace)) - 1`. It must not equal PairToken's slot or Wings' slot.

FS-OWN-01 adds a Crane pair under `lib/crane/contracts/protocols/dexes/uniswap/v4/aware`: one Uniswap V4 Protocol Aware Repo and one Facet. FS-OWN-02 adds the reusable Crane pair `UniswapV4SinglePositionAware`: one Repo and one Facet. Both are implemented and tested in the Crane submodule, and neither file set is created by this PRD revision. Do not put those repos inside the full-spread family directory.

### FS-PKG-01 — `PkgInit` and `PkgArgs`

`PkgInit`, in binding order: the facet fields above, then `registry`, `oracle`, `diamondFactory`, and `linkedLibraries` as `address[6]` for Math, Projection, SwapProjection, Planner, Execution, and ExecutionPreparation. The two Standardized Yield facet fields are absent. The seven Uniswap V4 architecture addresses are package immutables of the package deployment, not `PkgInit` fields, so there is no `poolManager` field and no `wrappedNative` field. FS-OWN-16, FS-OWN-17.

`PkgArgs` is this family's set. It is not the PairToken set. No hook allowlist:

- `PoolKey poolKey`, stored through the `UniswapV4SinglePositionAware` Repo in FS-OWN-02, not as proof that `poolKey()` is a family-only selector
- `string name`
- `string symbol`

`maxZapBps` and `maxZapTickMove` are not fields. No replacement cap or tick bound is added.

`bindingHash` covers every `PkgInit` field. `calcSalt` and `processArgs` run by delegatecall and use immutable bindings and self calls.

`deployVault(PkgArgs) returns (address)` goes through the bound IndexedEx vault registry. No second factory. The PoolManager is not CREATE3'd by this package. Tests deploy it through the current artifact-backed CREATE3 helper, as FS-TEST-01 says.

`processArgs` reverts `NotCalledByRegistry` unless `msg.sender` is the bound registry and `address(this)` is the bound `diamondFactory`. Both conjuncts are required.

### FS-PKG-02 — Validation

Reject, without a partial diamond:

- A missing or code-empty component, a family facet whose linked-component hash does not match, or a cut that installs `getRate` or `rateAsset`. `InvalidComponent`.
- A pool key that is not initialized on the bound manager, or that has a nonzero hook. `InvalidPoolKey`.
- A designated `rateAsset`. FS-OWN-03 removes that argument and that error.
- The `processArgs` context failure above.
- Proxy initialization that does not match the bound package and arguments. `InvalidInitializationContext`.
- A second initialization. `AlreadyInitialized`.

Initialization installs the name, symbol, pool key, and full-range ticks, writes the package immutables into the Protocol Aware Repo, and stores the `PoolKey`, `tickLower`, `tickUpper`, and the position salt in the `UniswapV4SinglePositionAware` Repo. It does not store a designated rate token. The PoolManager binding comes from the Protocol Aware pair in FS-OWN-01, not from a family `poolManager()` selector. The first depositor creates the position. Genesis issuance follows FS-MONEY-01. This update does not add Weir's treasury performance fee.

## 5. Money and unlocked entry

### FS-MONEY-01 — Weir-adapted money rules

The public selectors stay the accepted Standard Exchange routes, plus locked `donate` and `compound`. Do not install Weir's `deposit`, `withdraw`, `zap`, or `zapTo` selectors. Citations below are the current `WeirVaults.sol`.

- `deposit` pulls the declared amounts from `msg.sender`, then sends `amount - used` of each currency back to that payer. A pretransfer call instead uses the unbooked held balance up to the caller's maximum, under the refund rules of FS-OWN-32.
- `_deposit` settles each currency from the net delta. A positive credit goes back to the depositor. Shares are credited to `p.recipient`, who need not be the payer.
- There is no consumption-equality check and no `IncompleteConversion` error.
- The entry swap, when one is needed, uses `_swap`. Its price limit is `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`. That is not `maxZapTickMove`, and no tighter cap is added. Its size is the greatest liquidity the following add can take. FS-OWN-33.
- In `_deposit`, `frame.liq` is the deposit's added liquidity. When `v.totalShares == 0`, the source rejects `frame.liq <= MIN_SHARES`, assigns `frame.shares = frame.liq - MIN_SHARES`, and sets `v.totalShares = MIN_SHARES`. `MIN_SHARES` is `1_000`. The source marks that minimum as never redeemable. After the liquidity modification, the function adds `frame.liq` to `v.liquidity` and `frame.shares` to `v.totalShares`. The minimum is an intermediate step, not the final total. `deposit` credits only `frame.shares` to `p.recipient`, less the usage fee taken from those shares. FS-OWN-24. The floor is supply that is not credited to that recipient. This update does not add a second share ledger, pick a holder address, or rescale the constant.
- For an existing supply, `frame.shares = (uint256(frame.liq) * v.totalShares) / v.liquidity`. The denominator is existing liquidity after the preceding compound and before this deposit is added. Idle balances are not in that denominator.
- The share formulas use one raw liquidity number and no token decimals. On a first deposit the pre-fee minted shares are `added liquidity - 1,000`. On a later deposit the minted shares are `added liquidity * totalShares / existing liquidity`, and a burn removes `liquidity * shares / totalSupply`, where `totalSupply` includes the floor. FS-OWN-27.
- A share-minting deposit books the `feesAccrued` its liquidity modification collects. Those fees are not included in the deposit, not included in the caller's share credit, and not swapped into the deposit. Swapping them into the deposit is forbidden.
- `unlockCallback` does not call `_compound` before `_deposit` or before `_withdraw`. A deposit, a withdrawal, and `exchangeIn` do not call `compound()`.
- `_compound` and `donate()` process the combined balance of the collected fees and the booked remainder. With one token, the call swaps toward the position's ratio, as a one-sided user deposit does, and the remainder must be in the token being processed; that remainder is booked. With both tokens, from any mix of fees, a donation, and an already booked balance, the call does not swap and deposits the matched pair; the scarcer token is the proportionally smaller amount relative to the position ratio, not the smaller raw balance, and that token is fully used, while the excess of the other token is booked. The booked total is the actual held balance after the deposit, so a stray transfer is booked as well. A zero-size add is skipped. A failed step reverts. A remainder after the deposit is booked, not returned to the caller, and the call does not revert merely because a remainder remains.
- `_withdraw` removes liquidity in proportion to shares. The caller's share of the accrued fees and of each booked balance is `shares burned / total shares`, measured before the burn and rounded down, and it is included in the exit. The rest is booked for the other holders. FS-OWN-30. This family does not install `zapTo`. A one-token exit converts all unwanted withdrawn principal, plus the caller's opposing-token fee and booked claim, into the selected token, or it reverts `AmountOutNotMet` and does not burn shares; it does not pay, book, or keep that residual. A both-token exit pays the caller's claim in both tokens and does not swap. Unused input and a positive credit are returned to the payer. They are not booked without shares. The refund is reported through the accepted return of the route, and no other route gains a refund return. FS-OWN-08.

Callers send and receive WETH only. The vault does not accept or produce native ETH. Native ETH is wrapped or unwrapped only at the pool boundary. FS-OWN-17.

The 12,000,000 gas transaction ceiling and the 5,000,000 preview ceiling stay. A hook-composed transaction must fit the 12,000,000 ceiling or be recorded as an unresolved narrowed route. It is not a passing measurement and not a waiver.

### FS-UNLOCK-01 — Two dispatch paths, one engine

Current buffer and unwrap helpers call `IStandardExchangeIn.exchangeIn` while the PoolManager is already unlocked. Buffer helpers observed in the dual and weighted claim code pay `address(this)`. Weighted `unwrap` pays the hook's `to` argument, which can be a user. A new selector would not be called. Do not add `exchangeInUnlocked`.

After ordinary route, deadline, amount, and authority checks, `exchangeIn` reads `TransientStateLibrary.isUnlocked` on the bound manager:

- Locked: FS-UNLOCK-03.
- Unlocked: FS-UNLOCK-02.

`isUnlocked` selects the path. It is not authorization. Allowance, minima, deadline, and share authority still apply. The PoolManager is not the depositor.

`exchangeBundleInForSingleOut`, a both-token `exchangeBundleOut`, `donate`, and `compound` keep `ManagerAlreadyUnlocked()` on this path. A one-token exit, which is single-output `exchangeBundleOut`, proceeds on that open unlock. There are no paired selectors and no SY mutators.

### FS-UNLOCK-02 — Borrowed unlock

When `exchangeIn` takes the unlocked path:

1. The vault is initialized and idle. The callback hash is empty. Reservations are zero. This diamond's own backing-currency deltas on the bound manager are zero. Otherwise revert `SettlementMismatch` or `ReentrantOperation`.
2. The caller has code, pays the input, and is the share owner burned on exit. `pretransferred` is false. The function is nonpayable, so a value-bearing call fails at the ABI boundary. Do not specify `InvalidUnlockedContext` for `msg.value != 0`. `recipient` may be the caller or another address. Output is paid to `recipient`. Otherwise, a failed funding or route check uses the inherited error, and a borrowed-path context miss uses `InvalidUnlockedContext`.
3. No payer, callback payload, or foreign creditor is accepted. Burn only the caller's shares.
4. Dispatch each selected action to the same internal action, account, and settlement code used by the locked path. Do not call `unlock`. Do not call `unlockCallback`. Do not copy the locked callback's final `getNonzeroDeltaCount` check. That count is global. The hook and router may hold open deltas.
5. `modifyLiquidity` and `swap` run only on this diamond's hookless pool key. The position owner remains this diamond. The only position written is the full-range salt-zero position: `tickLower` and `tickUpper` from `TickMath.minUsableTick` and `maxUsableTick`, salt `bytes32(0)`.
6. Settlement of a debt is atomic for that currency: sync, transfer or value, settle, then take credits. Do not `settleFor` a foreign address. `PoolManager.sync` writes the global transient `CURRENCY_SLOT` and `RESERVES_OF_SLOT` in `CurrencyReserves`. Do not assume an outer actor's sync checkpoint remains valid. Do not clear another address's sync to hide a clobber. If the sequence cannot close this diamond's own touched deltas without taking a foreign credit, revert `SettlementMismatch`.
7. Before return, this diamond's touched currency deltas are zero. Assert that per address. Do not require the global nonzero-delta count to be zero. Do not settle the hook's or the router's deltas.
8. A failure reverts the vault call and its descendant effects. If the outer caller catches it, the vault state is restored and the caller still owes its own settlement. The catch does not relock the manager.

A one-token exit on that open unlock uses the same internal action, account, and settlement code, pulls the caller's deployed fraction, and swaps only the withdrawn net. FS-OWN-31.

### FS-UNLOCK-03 — Locked path

Ordinary entry keeps the inherited per-action dispatcher. For each selected manager action that needs an unlock, commit `keccak256(abi.encode(operation, payload))`, call `unlock` once for that action, accept the callback only from the bound manager, only while the guard is held, and only once for that payload. Then settle that action and verify the manager has relocked before the next action. Nested unlock and replay stay forbidden. The public-operation guard stays active across the plan, token calls, and final payout.

`unlockCallback` remains unusable as a deposit. An external unlock does not satisfy a committed hash.

## 6. Rate, quote, and issuance

| Surface | Meaning | Forbidden substitute |
| --- | --- | --- |
| Issuance | FS-MONEY-01. `previewZapCredit` is absent. | S1-ACC-07. `J_i` booking. A replacement zap-credit view. |
| Mint preview | The share credit a mint quote shows. It does not credit existing fees to the new depositor. | Crediting accrued fees to a new depositor. |
| Exit preview | The share valuation. It uses the same apportioning and the same swap as execution, so the quoted `amountOut` matches execution, and it includes accrued fees. | A principal-only quote. A quote that omits accrued fees. |
| SY `exchangeRate()` | Not installed. FS-OWN-05. | A replacement denomination. NAV. |
| `previewExchangeIn` | Amount-specific executable quote for the exact-input route, including maintenance and full unwanted-leg consumption. It returns `(amountOut, amountRefunded)`. | Not whole-book value divided by supply. |
| `getRate()` | Not installed. FS-OWN-03. | The withdrawn one-share formula. NAV. The external full-book provider. |

`previewExchangeIn` and `exchangeIn` keep their selectors `0x89d61912` and `0xd02d3063` and return the tuple. `exchangeOut` and `previewExchangeOut` do not gain a refund return. FS-OWN-08.

### FS-RATE-01 — Withdrawn

Do not implement `getRate`. The prior formula, `InsufficientRateSupply`, `RateNormalizationOverflow`, and `RateUnavailable` are not requirements. Do not bind `StandardExchangeRateProviderFacet` and call its result this family's rate. The hook's rate leg uses a rate-provider instance deployed for this vault and one rate target, and this vault does not know that provider. FS-OWN-29. A hook that requires a provider for this share is not an unresolved FS-HOOK-04 record on that ground alone.

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

No new hook-package field is authorized.

### FS-HOOK-02 — Canonical cross-vault fixture

The passing cross-vault proof is:

1. FullSpread is the buffered leg. `standardExchange` is this vault. FS-OWN-03 removes `rateAsset`, so this step cannot name the pool token as `rateAsset` or bind this vault's `getRate`. The hook configures a rate-provider address for each Standard Exchange liquidity leg, and that address points at an instance deployed by `IStandardExchangeRateProviderDFPkg` for this vault and one rate target. This vault stores no provider address and exposes no provider getter. FS-OWN-29. The required rows use that configured instance, and they are not recorded incompatible for want of a provider. The rate subject is this vault used as liquidity in the test pool, with one scenario for each underlying token, so the integrated token can be token0 or token1, and separate pools may hold the same vault with a provider whose `rateTarget` is a different underlying token.
2. The other SE is not asked to mint or redeem inside the outer unlock. Current PairToken rejects that context. Its share may be an identity leg only if the current package accepts `token == se` without `asset()`. If it rejects, that identity bind is FS-HOOK-04, not a pass. The other leg can still be a raw token or a share transfer that the hook accepts without calling that vault.
3. The two backing pool keys differ. One direction mints FullSpread shares while the manager is unlocked. The reverse burns them. Assert balances, position owner, ticks, salt, and per-address deltas.
4. An identity-only share trade is a separate case. It does not prove underlying entry or exit.
5. A both-buffered composition is optional, and only for another family that already supports the same borrowed unlock. It is not the required proof.

Two buffered legs that share one pair token and overwrite `standardExchangeOf[pair]` are not a required fixture. If the package cannot represent that bind, record it. Do not edit the hook to create it.

Same-backing-pool sequential composition is unverified, not impossible, and not passed by the disjoint-pool fixture.

### FS-HOOK-03 — Exact output

`exchangeOut` reverts. A hook path that calls it against this vault fails closed. An identity route that never calls `exchangeOut` is not forbidden by that sentence. Exact-input both directions means `zeroForOne` and `oneForZero`. Exact-out is not one of those directions.

### FS-HOOK-04 — Separate hook-change gate

If a required route cannot run:

1. A full-spread money, preview, or context defect is fixed in this family.
2. An intentional exact-output or budget rejection stays a rejection.
3. A missing quote interface, an `asset()` requirement, a `SameToken` or pair-overlap reject, or an incompatible denomination is a separate requirement. Name the consumer, selector, arguments, and revert. Do not implement that change here, and do not stub a transition quote. A rate-provider requirement is not one of these cases; the hook's configured provider instance supplies it. FS-OWN-29.

A cited reject is an unresolved integration record. It does not close the canonical FS-HOOK-02 proof. It may close a family row only when that family's topology cannot express the canonical fixture, and the record says so.

## 8. Testing

### FS-TEST-01 — Harness

Place the TestBase under the family's `test/bases/`. Follow the current PairToken setup: extend `IndexedexTest` and the canonical native-wrapper base, call parent setups in the current order, and deploy the PoolManager through the existing artifact-backed CREATE3 helper. Deploy facets and the package through the current factory and manager paths. The hook under test and this vault bind that same manager. Two managers do not prove FS-UNLOCK-02.

Bootstrap shares only through the accepted public entry routes. `depositPair` is not installed. Reuse the current non-SUT mintable funding tokens. That is not permission to mock, etch, `vm.mockCall`, or inject storage into this vault or the PoolManager.

Hermetic tests use the default Foundry profile, `viaIR=false`, and the current runtime and initcode limits. `recordLogs` is not a receipt. A snapshot restore asserts pre-state and post-state equality before restore.

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
| FS-A01 | Package inputs follow FS-FACET-01. ERC-165, ERC-8109, loupe, and the cited temporary-hook facet are absent from cuts and still callable on the factory-built proxy where the factory installs them. The reviewed selector manifest succeeds through the proxy. `poolManager()` and the position getters are callable through the two Crane package inputs and are not installed as family selectors; `rateAsset()`, `getRate()`, `basket()`, `localReserves()`, and every Standardized Yield selector are absent. Factory selectors stay disjoint. |
| FS-A02 | `bindingHash` changes if any facet, library, or infrastructure binding changes. |
| FS-A03 | Invalid component, pool key, double initialization, wrong `processArgs` caller, and right registry in the wrong account all revert and leave no usable vault. There is no rate-asset argument, no zap-limit argument, and no wrapped-native argument to reject. |
| FS-A04 | Storage slot is not PairToken's and not Wings'. |
| FS-A05 | First deposit creates one full-range salt-zero position owned by the diamond. Genesis issuance follows FS-MONEY-01. The unredeemable floor is `MIN_SHARES` of supply, and only the minted shares are credited to the recipient. The usage fee is taken from those minted shares, the floor mint is separate, and the resolved fee is clamped to 30%. No performance fee is added. |
| FS-A06 | Paired deposit and redeem follow the mapped bundle routes and FS-MONEY-01. They do not follow S1-ACC-02 or S1-ACC-07. The bundle deposit emits `PairDeposited(address indexed caller)` and the bundle redeem emits `PairRedeemed(address indexed caller)`, with no other arguments. |
| FS-A07 | Unused declared entry input is returned to the payer. A positive credit is returned to the depositor and is not booked without shares. There is no `IncompleteConversion` revert. A pretransfer refunds the maximum minus the amount used when the maximum is within the unbooked balance, and refunds the unbooked balance without pulling a shortfall when it is larger. The one-token exit is FS-A08. |
| FS-A08 | Single-token exit pays only the selected token or reverts. It converts the unwanted withdrawn principal and the caller's opposing-token fee and booked claim into the selected token, or it reverts `AmountOutNotMet` and does not burn shares. It does not pay, book, or keep that residual. |
| FS-A09 | `previewExchangeOut` returns zero. `exchangeOut` reverts `ExchangeOutNotAvailable` with unchanged balances. |
| FS-A10 | Callers send and receive WETH only. The vault does not accept or produce native ETH, and native ETH is wrapped or unwrapped only at the pool boundary. There is no `wrappedNative()` getter and no `PkgInit.wrappedNative` field. |
| FS-A11 | A withdrawal pays the caller `shares burned / total shares` of the accrued fees and of each booked balance, measured before the burn and rounded down, and books the rest. There is no collection-only fallback. A deposit, a withdrawal, and `exchangeIn` do not call `compound()`. |
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
| FS-A22 | `exchangeBundleInForSingleOut`, a both-token `exchangeBundleOut`, `donate`, and `compound` revert `ManagerAlreadyUnlocked` while the manager is unlocked. A one-token exit as single-output `exchangeBundleOut` proceeds on that open unlock. `depositPair` and `redeemPair` are absent. There are no SY mutators. |
| FS-A23 | A reverting borrowed `exchangeIn` restores shares, liquidity, and token balances. |
| FS-A24 | An identity bind of `token == this vault` is attempted. If the current package rejects it without `asset()`, the row records that reject under FS-HOOK-04 and does not pass. Do not add `asset()`. |
| FS-A25 | Buffered configuration mints and burns through `exchangeIn` while unlocked. Recipient may be the hook or the hook's unwrap recipient. Position owner, ticks, and salt hold. Fee handling follows FS-MONEY-01. No performance fee is added. The rate leg uses the hook's configured rate-provider instance for this vault and one rate target, with one scenario for each underlying token and two pools holding the same vault at different targets. |
| FS-A26 | The FS-HOOK-02 fixture completes exact-input `zeroForOne` and `oneForZero` on two different backing pool keys. Exact-out is not part of this row. |
| FS-A27 | Each family in FS-HOOK-01 has the proof that its topology can express, or a cited FS-HOOK-04 record that says why it cannot. A cited reject does not replace FS-A26. |
| FS-A28 | A hook path that calls `exchangeOut` on this vault reverts and pays neither token. |
| FS-A29 | This vault exposes no rate and knows no rate provider. The rate-provider instance for this vault and one rate target is deployed by `IStandardExchangeRateProviderDFPkg` and configured on the hook. The provider reads the accepted 64-byte preview tuple. The useful count of instances is `vaultTokens().length`, and it is not a cap. |
| FS-A30 | A same-backing-pool sequential composition is not reported as passed by FS-A26. |
| FS-A31 | Every claimed composed fixture, including both vault operations and hook work, fits 12,000,000 gas. Previews fit 5,000,000. An oversized route is unresolved, not passed. There is no `getRate` read in the measurement. |
| FS-A32 | No view reverts by a vault error. An unsupported view route returns zero, and `previewExchangeOut` returns zero. A busy or unlocked manager is not a view revert. `reserves()` and `reserveOfToken` wrap the deployed-reserve reads, with no local term and no last-committed snapshot. `getRate` is not part of this row. |
| FS-A33 | Borrowed execution uses the same booking and settlement as the locked path from the same economic state. There is no collection-only fallback and no performance fee. |
| FS-A34 | A nonzero own delta at borrowed entry reverts. Each action closes only this diamond's deltas. Outer debts remain until the outer unlock returns. |
| FS-A35 | Native borrowed settlement syncs native currency immediately before value settle, does not double-count wrapped and native backing, and does not spend another actor's sync credit. |
| FS-A36 | A propagated outer failure restores the swap. A caller that catches a rejected vault call keeps only its own prior effects, sees the vault restored, and still settles its own deltas. |
| FS-A37 | A funded non-hook contract that meets FS-UNLOCK-02 succeeds. The missing allowlist is the specified permissionless funding rule. |
| FS-A38 | Disabled inbound issuance still allows a supported exit through a buffered hook route. |
| FS-A39 | `previewExchangeIn` and `exchangeIn` keep the selectors `0x89d61912` and `0xd02d3063` and return `(uint256 amountOut, uint256 amountRefunded)`. `exchangeOut` and `previewExchangeOut` gain no refund return. |
| FS-A40 | The six fail-closed consumers named in FS-OWN-08 reject a 64-byte preview success until their own migration lands, and the three one-word ABI bindings are migrated to the tuple. This vault does not change them. |
| FS-A41 | A one-sided deposit, a one-token `donate`, and a one-token `compound` size their swap by the greatest liquidity the following add can take. The remainder stays in the input token, and the swap input is not the processed-token amount the add consumes. |
| FS-A42 | A share-minting deposit books `feesAccrued` and neither deploys nor swaps them, and a mint preview credits no existing fees to the new depositor. The exit preview matches the executed exit amount and includes accrued fees. |
| FS-A43 | `donate` and `compound` revert for a caller that is neither the current `feeTo()` nor an operator in `OperableRepo`. The owner check reads `feeTo()` live, and a `feeTo()` change moves the authority. |
| FS-A44 | `donate` emits `Donation()` and a deposit from collected fees or booked tokens emits `Compounded()`. Neither event carries an amount. A call with no fees, no donation, and no booked remainder returns with no state change and no event. |
| FS-A45 | The seven Uniswap V4 addresses are package immutables. One initialization write places them in the instance Protocol Aware Repo, and the package does not hardcode `ROBINHOOD_MAIN.sol`. The Crane aware getters and the `UniswapV4SinglePositionAware` getters are externally callable on this vault, and `localReserves()` is absent. |

Compare supply, holder balances, both positions, booked and reserved custody, wrapper balances, and per-address deltas. Do not assert only that no tokens moved.

## 9. Non-goals and limits

This PRD does not authorize implementation, deployment, a registry migration, a hook edit, a Weir copy, a wings range, a second pool, a transition-quote facet, a zap cap, a tick guard, a local liquidity sleeve, a native-ETH route, or Weir's treasury performance fee.

No audit is claimed. Disjoint-pool hook tests do not prove same-pool sequential safety. Compiler, gas, and fork results are future evidence.

Advisory outcomes for the prior revision `fullspread-se-prd-weir-align-r1`: Astra and Kimi requested changes. Grok and MiniMax supported with corrections. The corrections in that revision were coordinator choices, not a new member vote. MiniMax withdrew the thirteenth facet. Kimi withdrew the zero rate. The proposal to unlock compound and paired methods stays rejected. The owner later locked FS-OWN-03, which withdraws `getRate`. That owner lock overrides the earlier rejection of Grok's omission. The owner locks of 2026-11-01 through 2026-11-03, and the pretransfer directive, are carried in this revision.

## 10. Participation

| Member | Requested route | Original task | Advisory |
| --- | --- | --- | --- |
| Astra | `chatgpt-subscription/gpt-6-astra:high` | `st_01a18d05` | REQUEST CHANGES |
| Grok | `xai/grok-4.7:xhigh` | `st_01a18d06` | SUPPORT WITH CORRECTIONS |
| MiniMax | `minimax/MiniMax-M3` | `st_01a18d07` | SUPPORT WITH CORRECTIONS |
| Kimi | `kimi-coding/k3.1-pro:high` | `st_01a18d08` | REQUEST CHANGES |

Coordinator mode was invoking-agent. The coordinator is not a fifth vote. Runtime provider internals are not independently attested beyond the task records. The table above records the advisory round for the prior revision. The replacements for this revision are the member responses of run `se-fullspread-prd-rewrite-20261103`, under `docs/research/se-fullspread-prd-rewrite-20261103/members/`, and this file is not member-approved text.
```

## Limits

- No Forge run, no test, no build, no install, no deploy, no wallet action, and no Git command. Every behavioral statement in the replacement text is a restatement of a lock, not an observed execution.
- The consumer line numbers in FS-OWN-08 were re-read at source by me. The 1626-occurrence, 618-file index was read as a generated listing only; it is cited by path and count and not pasted into the PRD.
- F11's one-token exit on a borrowed unlock is carried on the strength of B-09 and the blockers file's already-locked list, which state the borrowed-exit rule in substance. If the coordinator holds F11 to be uncarried, FS-UNLOCK-01, FS-A22, and the sentence in FS-UNLOCK-02 are the three places that change.
- F2's exit apportioning and F6's one-token exit conversion are stated in the PRD at the rule level the overrides give. No formula, rounding rule, or price bound beyond the locked text is added, and the "position ratio" is not defined beyond what the booking lock states.
- F1 leaves one branch open: whether a call whose declared maximum exceeds the unbooked balance processes no leg at all. The PRD carries only the locked refund behavior and does not decide that branch.
- `Donation()` is written as having no fields, per the brief's filled reading. The blockers file says the F7 owner text did not name its fields, so if the coordinator reads that as undetermined, one sentence in FS-OWN-21 changes.
- The `donate` parameter list is not stated, because no admitted lock states one and the current PRD states none.
- The members' responses for this run were not read, and no peer file was written.
