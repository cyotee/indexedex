# Astra original — legacy V4 ERC-5115 interface replacement notes

**Date:** 2026-10-15. **Status:** Independent PRD-authoring notes, not implementation authorization. No peer notes were read and no code or PRD was edited. The owner ruling selects the repository's `lib/crane/contracts/tokens/ERC5115/IERC5115_StandardizedYield.sol` as the exact interface to implement.

## 1. Required outcome and boundary

Replace legacy V4's Pendle standardized-yield ABI with the **eight functions actually declared in that local ERC-5115 file**. Do not substitute another version of ERC-5115, extend the interface, or retain Pendle-only compatibility selectors. Keep ERC-20/permit and Standard Exchange routes independently of the yield-interface change.

Keep current facet ownership boundaries for the surviving functions: yield money operations remain on `UniswapV4StandardExchangeInFacet`; yield queries remain on `UniswapV4StandardExchangeOutMultiQueryFacet`. Do not decide a later size-driven split, add another facet, restore an execution delegate, or modify the dedicated callback ownership. Measure sizes after this interface change; a remaining oversize result is reported rather than hidden by another architecture change.

**Other families stay unchanged in this item.** The owner's ruling identifies legacy V4, not a repository-wide Pendle removal. The shared Pendle adapters/selectors are active dependencies of V3, hookless, Pons, Wings, ERC-4626 and hook products. There is no need to ask whether to convert those families in order to implement this bounded change. No owner question remains for legacy V4; a broader conversion would require a separate instruction.

## 2. Interface comparison — exact function inventory

Read in full:

- `lib/crane/contracts/tokens/ERC5115/IERC5115_StandardizedYield.sol:4-60`: eight function declarations; no inherited ERC-20 interface, rewards surface, validity queries, or assetInfo.
- `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:28-166`: sixteen yield-specific functions plus inherited ERC-20 metadata/token interface.

Selectors are specified by canonical signatures and the actual interface member `.selector`; no numerical selector is guessed here. Return types and mutability do not enter selector hashing, but remain part of the implementation contract.

Let `V4/` mean `contracts/protocols/dexes/uniswap/v4/`.

### Remove these nine current selector identities from the legacy V4 proxy

| Current canonical signature | Current installed owner | Current implementation origin | Required disposition |
|---|---|---|---|
| `deposit(address,address,uint256,uint256)` | `V4/UniswapV4StandardExchangeInFacet.sol:22-25` | Legacy `UniswapV4StandardYieldExecutionTarget.sol:17-25`, delegating internally to shared MoneyTarget | Remove this old payable overload; no compatibility alias |
| `rewardIndexesCurrent()` | Same InFacet | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:77-78` | Remove from legacy V4 cut and inheritance surface |
| `claimRewards(address)` | Same InFacet | Shared target `:79-82` | Remove; do not retain an empty legacy stub or ClaimRewards emission |
| `assetInfo()` | `V4/UniswapV4StandardExchangeOutMultiQueryFacet.sol:23-26` | `V4/UniswapV4StandardExchangeOutMultiQueryTarget.sol:40-44` | Remove local body and Pendle AssetType dependency |
| `isValidTokenIn(address)` | Same OutMultiQueryFacet | Query target `:85-92`, shared Discovery/Validation declarations | Remove public legacy ABI/body; keep internal configured-token validation |
| `isValidTokenOut(address)` | Same OutMultiQueryFacet | Query target `:94-101`, shared Discovery/Validation declarations | Same disposition |
| `getRewardTokens()` | Same OutMultiQueryFacet | `NativeStandardYieldDiscoveryTarget.sol:27` | Remove from legacy V4 ABI/inheritance |
| `accruedRewards(address)` | Same OutMultiQueryFacet | Shared DiscoveryTarget `:28` | Remove from legacy V4 ABI/inheritance |
| `rewardIndexesStored()` | Same OutMultiQueryFacet | Shared DiscoveryTarget `:29` | Remove from legacy V4 ABI/inheritance |

The two shared selector appenders causing these installations are `NativeStandardYieldSelectors.sol:48-55` and `:58-73`. Stop using those Pendle appenders in the two legacy V4 facets. **Do not modify the appenders globally.**

### Add this one replacement selector

| Canonical signature | Required owner | Interface contract |
|---|---|---|
| `deposit(address,address,uint256,uint256,bool)` | `V4/UniswapV4StandardExchangeInFacet.sol`, implemented by the existing legacy `UniswapV4StandardYieldExecutionTarget.sol` | `IERC5115_StandardizedYield.deposit`, declared at `:21-27`; nonpayable; last argument is `depositFromInternalBalance` |

This is not merely changing an interface ID. The fifth argument changes the function selector and introduces an input mode. The local interface declares this function nonpayable, unlike Pendle's four-argument payable deposit at `IStandardizedYield.sol:68-71`. Implement the new overload nonpayable; do not retain the old overload through inherited code. Nonzero native value is rejected by the new nonpayable surface; continue using the configured WETH ERC-20 face where applicable.

### Retain these seven selectors with unchanged signatures

| Canonical signature | Required owner | Behavior retained |
|---|---|---|
| `redeem(address,uint256,address,uint256,bool)` | InFacet / legacy YieldExecutionTarget | Same explicit-holder redemption, minimum, and caller/receiver semantics |
| `exchangeRate()` | OutMultiQueryFacet / OutMultiQueryTarget | Existing complete-book rate and existing zero-supply rate |
| `getTokensIn()` | Same query owner | Existing configured currency faces/order |
| `getTokensOut()` | Same query owner | Existing configured currency faces/order |
| `yieldToken()` | Same query owner | Existing return value; no new underlying-yield-token model |
| `previewDeposit(address,uint256)` | Same query owner | Existing route arithmetic and invalid-token/zero handling |
| `previewRedeem(address,uint256)` | Same query owner | Existing route arithmetic and invalid-token/zero handling |

ERC-5115 declares these at lines 29-53. Only the interface reference changes for these selectors; do not manufacture changed signatures or a new share token.

`name`, `symbol`, `decimals`, `totalSupply`, `balanceOf`, `allowance`, `approve`, `transfer`, `transferFrom`, permit and EIP-712 selectors **remain** on their existing independent shared facets. Their presence is not a reason to claim Pendle support, nor does removing Pendle's inherited interface justify removing them. The commented-out metadata declarations in ERC-5115 lines 55-59 are not additional selectors to install.

## 3. Closed resulting declarations

The legacy IN facet's `facetFuncs` becomes exactly three entries, in this order:

1. `IStandardExchangeIn.exchangeIn.selector`
2. `IERC5115_StandardizedYield.deposit.selector`
3. `IERC5115_StandardizedYield.redeem.selector`

The legacy OUT multi-query facet's `facetFuncs` becomes exactly seven entries, in this order:

1. `IStandardExchangeOutMulti.previewExchangeOutOneToMany.selector`
2. `IERC5115_StandardizedYield.exchangeRate.selector`
3. `IERC5115_StandardizedYield.yieldToken.selector`
4. `IERC5115_StandardizedYield.getTokensIn.selector`
5. `IERC5115_StandardizedYield.getTokensOut.selector`
6. `IERC5115_StandardizedYield.previewDeposit.selector`
7. `IERC5115_StandardizedYield.previewRedeem.selector`

Write these arrays explicitly in the two existing facets; do not create a shared adapter that changes other products. Other facet selector lists and the existing sixteen package cuts remain unchanged. Against the presently inspected sixty product selectors, nine identities are removed and one added: **52 product selectors remain**. Factory infrastructure selectors are separate and unchanged.

`V4/UniswapV4StandardExchangeDFPkg.sol:147-163` currently registers Pendle at `interfaces[13]`. Replace that entry with `type(IERC5115_StandardizedYield).interfaceId`; retain the other fourteen entries and existing package identity/arguments. In OutMultiQueryFacet `:17-20`, replace the Pendle declaration with the ERC-5115 interface ID while retaining the existing multi-output interface declaration. Keep the IN facet's existing SE declaration. The proxy/package is the composite implementation; no new selector owner is implied by declaring its interface.

On the freshly deployed proxy, ERC-165 must report the repository ERC-5115 interface and must not advertise the Pendle interface. Derive both IDs from their respective Solidity interface types in tests; do not hardcode a guessed ID or merely rename an import alias.

## 4. Legacy implementation ownership and shared-file isolation

### Legacy money target

Change `V4/UniswapV4StandardYieldExecutionTarget.sol` locally. Stop inheriting `NativeStandardYieldExecutionTarget` from the shared `NativeStandardYieldTarget.sol`: that inheritance presently brings the old deposit and reward functions into the implementation (`legacy target:10-15`; shared target `:17-45,77-85`).

Keep the existing SE InTarget inheritance and internal PoolOps/Custody integration needed by the current family. Implement the new five-argument deposit and existing redeem locally. Remove legacy-only generic `_standardRoute` and public validity overrides made unnecessary by removing that shared parent. Use `Config._isValidToken` directly; retain the existing independent `NativeStandardYieldErrors` declarations where their errors still apply. Do not restore the deleted shim or create a duplicate settlement engine.

### Legacy query target

Change `V4/UniswapV4StandardExchangeOutMultiQueryTarget.sol` locally. Stop inheriting the shared Pendle `NativeStandardYieldPreviewTarget` alias (`:4-14,25`), so removed discovery/reward functions cannot survive indirectly.

Keep the existing SE multi-output preview and six retained yield queries. Implement the two yield previews directly against the current `Accounting._previewExchangeIn`, using the existing internal validity predicate and preserving the current invalid-token return behavior from `NativeStandardYieldPreviewTarget.sol:10-17`. Remove assetInfo and public validity methods; internal validity remains required. Preserve current rate math (`query target:46-50`), currency ordering (`:26-33`), and yieldToken result (`:36-38`).

### Shared consumers remain Pendle in this bounded item

Leave these shared files' functionality and Pendle selector inventories unchanged:

- `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol`
- `NativeStandardYieldPreviewTarget.sol`
- `NativeStandardYieldDiscoveryTarget.sol`
- `NativeStandardYieldSelectors.sol`
- The canonical Pendle interface file itself.

Examples establishing active sharing include V3's `UniswapV3FullSpreadStandardYieldExecutionTarget.sol`, hookless/Pons execution and OUT multi-query targets/facets, and the Wings SY target. Current production searches found their imports of these same shared files. Replacing a shared appender's deposit selector or deleting its reward selectors would silently alter those other families and is not this task.

No owner question is required to leave those existing implementations untouched: this is scope preservation, not an assertion that their product-interface choices have been re-approved or audited.

## 5. Deposit flag and preserved execution contract

The PRD must fix the new flag's semantics rather than letting an implementer ignore it:

- **False:** ordinary allowance-based input from the original caller, using the existing legacy SE funding path. A code-less caller may use this ordinary route. Preserve exact-output minimum-on-shares, receiver/token/amount validation, disable policy, settlement, reserve handling and TWAP completion.
- **True:** no in-call pull; consume the requested input from the existing legacy SE pretransfer-credit path for the configured input face, with the existing insufficient-credit error and no refund of unrelated excess. Authenticate the external starter through `LocalCreditLib.requirePretransferCaller` before credit-sensitive work. This is a contract-only internal-balance privilege, not permission to consume the entire held balance or another wallet's assets.
- Forward the boolean to the existing internal token→share SE path, preserving `msg.sender`, rather than converting a false-funded operation to true after a synthetic transfer. Do not use a public `exchangeIn` call on `address(this)`.
- The current token credit helper (`V4/internal/UniswapV4StandardExchangeCustody.sol:23-41`) does not itself contain the starter-bytecode gate. The new ERC-5115 true-flag entry must explicitly enforce that gate. Do not assume the share-delivery guard at `:72` covers token deposits.
- Preserve the existing stored-reserve/deployed calculation for this interface-only item. No new local-credit storage, account attribution, or broader residual repair is authorized. Tests of the new mode must not be represented as closure of that separately documented accounting residual.

`redeem` keeps its current distinction: false burns the original caller; true authenticates the starter and burns exactly the requested vault-held shares. Preserve the disabled-vault checks already present in the legacy yield target (`:23,32`), and one effective operation-wide reentrancy lock. Internal reuse must not double-lock or remove the lock.

Deposit/Redeem event signatures, indexed parameters and data order are identical in both interfaces (`ERC-5115:5-19`; Pendle `:30-45`). Emit through the ERC-5115 declaration with the original caller and requested receiver; event ABI must not change. `ClaimRewards` has no ERC-5115 counterpart and no legacy reward endpoint remains to emit it. This does not change economic fee/reward forwarding elsewhere in the vault.

## 6. Required source/test changes and acceptance evidence

The mandatory legacy source edit set is the existing YieldExecutionTarget, InFacet, OutMultiQueryTarget, OutMultiQueryFacet, and DFPkg. Remove their Pendle imports/dependencies where no longer used. Do not introduce a later facet split or shared-family conversion. Factory/TestBase deployment continues to use the same facet/package owner structure and existing internal operations.

Update the legacy-only declaration controls:

- `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet_IFacet_Test.t.sol:39-45` — current five-entry Pendle array becomes the three-entry array above.
- The sibling `UniswapV4StandardExchangeOutMultiQueryFacet_IFacet_Test.t.sol:34-54` — current Pendle ID and thirteen-entry array become the ERC-5115 ID and seven-entry array above.
- `UniswapV4StandardExchange_Architecture.t.sol:54-58` — cut counts and selector-owner expectations change; disabled-SY calls at 77-88 and deposit call at 92 must use the correct interface and new deposit flag.
- Migrate legacy-only SY calls in `UniswapV4StandardExchangeVaultHeldRedeem.t.sol`, full-range book tests, local-buffer H2 tests and their decimals variants. Changing their ABI calls must not weaken holder, no-self-call, minimum, lock-context, disable or balance assertions. Do not rewrite a shared Pendle behavior helper for every family merely to adapt legacy V4.

Acceptance must show on the production registry-deployed proxy:

1. All eight ERC-5115 functions are installed on the specified two existing facets; all nine removed selector identities have no facet owner; the old four-argument deposit is absent, not an alias.
2. ERC-165 reports ERC-5115 and not Pendle, while existing ERC-20/permit/SE interface support remains.
3. Ordinary five-argument deposit succeeds with the false flag; real funded contract pretransfer succeeds with true; a code-less true-flag starter is rejected before input use; short credited funding is rejected precisely. Both valid modes enforce the same share minimum and receiver behavior.
4. New nonpayable deposit rejects native value; valid WETH-face deposits still use the ERC-20 route. Do not require the old payable-overload custom-error behavior on the new nonpayable selector.
5. Redeem preserves both holder modes, exact burn, payouts, insufficient-balance/minimum rollback, disable checks and lock-context behavior. Event ABI and caller/receiver fields remain exact.
6. The retained six queries produce the existing results. Removed asset/reward/validity ABI functions are not reintroduced to make an old Pendle-oriented test pass.
7. No shared Pendle target/helper is converted globally and other families' declared surfaces remain unchanged.

Refresh affected artifacts before tests and then measure the affected deployed facets and package dependencies using the repository workflow. Record commands, toolchain, actual sizes and results. The prior size-blocked redesign report is not a passing test of this interface change; a present assertion is not a pass. If a facet remains above the hard runtime limit after this change, stop and report it. Do not decide a split or restore a hop in this item.

## Owner question and evidence boundary

**No owner question remains for the legacy-only interface replacement.** The ruling names the exact local interface and the current code supplies the existing settlement and scope boundaries. Other families keep their present Pendle behavior unchanged in this item; global conversion is neither required nor authorized.

These notes specify repository-interface conformance, not a claim that every variant of the published ERC-5115 standard has been evaluated. No new standard interface file or numerical selector calculation is required. All requested source/interface reads succeeded. Only this assigned reviewer report was written.

I did not run Forge.
