# FullSpread Standard Exchange requirements contribution

## 1. Identity and route, labeled as the assigned route, not a runtime attestation

- Member: Astra, independent original contribution.
- Assigned route: `chatgpt-subscription/gpt-6-astra:high`. This is the supplied route label, not an independent runtime, provider, account, or reasoning-effort attestation.
- Date: 2026-10-30.
- Run: `fullspread-se-prd-20261030-01a18660`.
- Deliverable: mergeable requirements for `UniswapV4FullSpreadStandardExchangeVault`, not implementation, a final council resolution, an audit, or implementation authorization.
- Owned artifact: `members/astra/response.md`.

The requirement language below is my proposed PRD text. Owner decisions in the brief and confirmed PairToken decisions are identified separately from new engineering choices. References in square brackets resolve to the local source register in section 9. Acceptance identifiers are normative obligations for a later implementation; none is a reported passing test.

## 2. Family boundary and deltas from PairToken and Wings

### FS-01 - Product identity and custody

Implement a new sibling family under:

`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`

One registered Crane diamond SHALL be one transferable ERC-20 share token, own one position in one immutable `PoolKey`, and account for that position plus its booked idle currencies. Position identity SHALL be `(address(diamond), minUsableTick(tickSpacing), maxUsableTick(tickSpacing), bytes32(0))`. Shares SHALL have 18 decimals. Canonical `ERC20Repo` SHALL be the only authoritative supply/balance ledger; PoolManager SHALL be the authoritative position-liquidity and position-fee-checkpoint ledger.

This is a new family, not restoration of either retired V4 FullSpread implementation. Do not copy retired code or overwrite PairToken/Wings sources, product documents, deployments, registry entries, or tests. The new request explicitly authorizes a sibling PRD despite the older router's retirement warning; it does not authorize implementation or migration. [B locked decisions 1-4; P S1-D02, S1-D04, S1-D05, S1-ARCH-01/02; L router retirement paragraph. Acceptance: FS-A01, FS-A03, FS-A10.]

### FS-02 - Inherited economics, with named integration deltas

The economics authority SHALL be PairToken stage one's current bounded-execution amendment, not the Weir import PRD or a prior recommendation report. Inherit the equations, custody categories, fee ownership, rounding, native mapping, conditional withdrawal maintenance, and limits identified in section 8.

The deliberate family deltas are:

| Delta | PairToken stage one | FullSpread requirement |
|---|---|---|
| Product identity | `pairToken` namespace and type prefix | New `fullSpread` namespace/type prefix; no migration. |
| Already-unlocked execution | S1-SEC-01 and S1-A40 reject an already-unlocked manager | FS-18/19 admit a narrowly defined, caller-funded exact-input standard entry in that context. Other ordinary entrypoints retain the rejection. |
| Rate Provider | S1-API-04 excludes provider installation from that stage | FS-21 installs `getRate()` on the family query facet, explicitly implementing the normalized executable one-whole-share exit quote. SY rate does not change. |
| Entry conversion completion | S1-OP-02 permits a partially filled selected entry swap | FS-12 requires complete consumption of the selected entry-swap amount, or atomic failure. This is an explicit narrowing of the zap domain, not a new issuance equation. |
| Integration release scope | S1-API-04 and section 12 exclude buffer/transition integration | FS-23/24 require existing-hook integration and identify the particular supported route/topology. No blanket claim of every optional hook liquidity/composition feature. |
| Package identity | Current PairToken hashes its bindings and arguments | FS-07 additionally domain-separates the sibling identity; current explicit facet fields and fixed links remain the template. |
| Test evidence | PairToken's own A01-A70 obligations | Reuse each applicable obligation with the explicit amendments in section 7, then add FullSpread rate/context/integration rows. |

No change is made to geometric-mean genesis, proportional basket ownership, post-swap attributable issuance, or the disclosed no-extra-shares entry remainder policy. In particular, entry remainder that becomes booked shared backing is not an unpaid exiting allocation. FS-12 makes that distinction testable rather than silently interpreting "complete consumption" as a different economic formula. [B locked decisions 3, 6, 8; P S1-ACC-01 through 07, S1-OP-02/04, S1-API-04; R2 required adaptations 3-5. Acceptance: FS-A11 through FS-A19, FS-A26 through FS-A39.]

### FS-03 - Explicit exclusions

FullSpread SHALL NOT introduce:

- Weir's multi-PoolId singleton, internal share ledger, performance fee, owner/treasury controls, or locked `MIN_SHARES`;
- PairToken baseline's permanent sink shares, redemption retention, or protocol-fee routing;
- a second share supply, an ERC-4626-only wrapper, external PairToken investment, or shares-of-shares;
- upper/lower wings, local sleeves, a rebalance strategy, an NFT position, or another backing pool;
- a new operational owner, backing rescue, user-selectable execution contract, mutable strategy configuration, queued exit, delayed settlement, or a partially successful single-token payout;
- a required Chainlink feed, peg, independently liquid market, or a promise of manipulation resistance;
- deployment, registry migration of existing vaults, or an audit claim.

Compared with Wings, the full-range basket and zero-salt position replace range-management behavior, and the explicit current PairToken facet bindings replace Wings' `IFacet[] facets`. Wings' open array, `permit2` binding, and `{poolKey,targetToken}` arguments are not this family's package contract. [B; W interface `PkgInit/PkgArgs`; P S1-D03, S1-X02/03/04, section 12; R1/R2; WI WI-07. Acceptance: FS-A01 through FS-A04, FS-A09.]

## 3. Standard and family facet inventory, each row sourced

### FS-04 - Exact package-owned facet composition

The live PairToken `PkgInit` was read and re-read. It contains **12 explicit facet fields**, five infrastructure bindings, and `address[6] linkedLibraries`. It does not contain an open facet array. The five shared fields are exactly `erc20Facet`, `erc2612Facet`, `erc5267Facet`, `basicVaultFacet`, and `standardVaultFacet`. The seven remaining fields are `moneyFacet`, `quoteFacet`, `outFacet`, `queryFacet`, `syMoneyFacet`, `syQueryFacet`, and `callbackFacet`. [PI `PkgInit`; PD constructor and `_expectedSelectors`; PTB `_packageInit`.]

Use the following package inputs. `F` in the table means the proposed full name prefix `UniswapV4FullSpreadStandardExchangeVault`; it is shorthand in this document only, not a Solidity type alias or filename.

| Field | Facet and interface contract | Ownership / reason / selector inventory | Source and acceptance |
|---|---|---|---|
| `erc20Facet` | Existing `lib/crane/contracts/tokens/ERC20/ERC20Facet.sol`; `IERC20`, `IERC20Metadata`, canonical additional declaration | Shared, unchanged. `name`, `symbol`, `decimals`, `totalSupply`, `balanceOf`, `allowance`, `approve`, `transfer`, `transferFrom`: 9. | P S1-ARCH-04; PD index 0; PTB. FS-A02/03/05. |
| `erc2612Facet` | Existing `lib/crane/contracts/tokens/ERC2612/ERC2612Facet.sol`; `IERC20Permit` | Shared, unchanged. `permit`, `nonces`, `DOMAIN_SEPARATOR`: 3. | P S1-ARCH-04; PD index 1; PTB. FS-A02/05. |
| `erc5267Facet` | Existing `lib/crane/contracts/utils/cryptography/ERC5267/ERC5267Facet.sol`; `IERC5267` | Shared, unchanged. `eip712Domain`: 1. | P S1-ARCH-04; PD index 2; PTB. FS-A02/05. |
| `basicVaultFacet` | Existing `contracts/vaults/basic/MultiAssetBasicVaultFacet.sol`; `IBasicVault` | Shared, unchanged. `vaultTokens`, `reserveOfToken`, `reserves`: 3. These report booked local reserves, not liquidation NAV. | P S1-ARCH-04/05, S1-API-01; PD index 3; PTB. FS-A02/06. |
| `standardVaultFacet` | Existing `contracts/vaults/standard/MultiAssetStandardVaultFacet.sol`; `IStandardVault` | Shared, unchanged. `vaultFeeTypeIds`, `contentsId`, `vaultTypes`, `vaultConfig`: 4. Use the functional multi-asset implementation, not the empty standard target. | P S1-ARCH-04/05, S1-API-01; PD index 4; PTB. FS-A02/06. |
| `moneyFacet` | Proposed `FMoneyFacet.sol` / `FMoneyTarget.sol`; mutating part of `IStandardExchangeIn` and family interface | Family. `exchangeIn`, `depositPair`, `redeemPair`, `donate`, `compound`: 5. `exchangeIn` contains the context dispatch required by FS-18; no duplicate hook money ABI is necessary. | PD index 5; PV; H1 `_seExchangeIn`; H3 `_buffer/_unwrap`. FS-A11-19/27-35. |
| `quoteFacet` | Proposed `FQuoteFacet.sol` / `FQuoteTarget.sol`; view part of `IStandardExchangeIn` and family interface | Family. `previewExchangeIn`, `previewDepositPair`, `previewRedeemPair`, `previewWithdrawalMode`, `previewZapCredit`: 5. Full-operation bounded planning. | PD index 6; PV; P S1-QUOTE-01. FS-A20/21/30/36. |
| `outFacet` | Proposed `FOutFacet.sol` / `FOutTarget.sol`; `IStandardExchangeOut` | Family. `previewExchangeOut`, `exchangeOut`: 2. Both deliberately revert without funds/state effects. | PD index 7; SO; P S1-P03. FS-A09/40. |
| `queryFacet` | Proposed `FQueryFacet.sol` / `FQueryTarget.sol`; family query interface and canonical `IRateProvider` | Family. Existing 11 queries plus `getRate`: 12. The added selector has a real consumer requirement and fits this responsibility; do not invent a thirteenth rate facet without a measured size reason. | PD index 8; PV; HC `_rate`; B decision 8. FS-A07/22-26. |
| `syMoneyFacet` | Proposed `FSYMoneyFacet.sol` / `FSYMoneyTarget.sol`; mutating `IStandardizedYield` | Family. `deposit`, `redeem`, `rewardIndexesCurrent`, `claimRewards`: 4. Native-capable boundary over the same shares/engine. | PD index 9; P S1-API-03. FS-A08/17/18. |
| `syQueryFacet` | Proposed `FSYQueryFacet.sol` / `FSYQueryTarget.sol`; view `IStandardizedYield` | Family. `previewDeposit`, `previewRedeem`, `getTokensIn`, `getTokensOut`, `yieldToken`, `assetInfo`, `exchangeRate`, `isValidTokenIn`, `isValidTokenOut`, `getRewardTokens`, `accruedRewards`, `rewardIndexesStored`: 12. | PD index 10; P S1-API-03, S1-QUOTE-02. FS-A08/20/22. |
| `callbackFacet` | Proposed `FCallbackFacet.sol` / `FCallbackTarget.sol`; `IUnlockCallback` | Family. `unlockCallback`: 1. Only the normal, committed manager callback; it is never the public borrowed-unlock entry. | PD index 11; PE `_action`; P S1-SEC-01. FS-A27/28/34. |

The package therefore supplies **61 distinct selectors**: 20 shared, 40 inherited family selectors, and `getRate`. The family operation/query interface retains the 19 existing named methods in PV and adds `getRate` through its declared rate capability. Its aggregate interface declarations must describe capabilities that are actually installed; individual split facets must not advertise unsupported unrelated interfaces.

`linkedComponents()` is implementation metadata, not a vault selector. Preserve PC's distinction: it may be called on a facet to validate compiler links but SHALL NOT enter `facetFuncs()` or proxy cuts. Do not install a combined `ERC20PermitFacet` alongside the three split token facets. [PC; PD; P S1-ARCH-04. Acceptance: FS-A02/03/07.]

### FS-05 - Factory-owned components excluded from inputs and cuts

ERC-165, diamond loupe, ERC-8109 introspection, and the temporary post-deployment hook are factory-owned. They SHALL NOT be constructor facet fields, product component deployments, `facetAddresses`, `facetCuts`, or package-owned interface aggregation. Their persistent selectors remain available on the deployed proxy. The temporary hook is removed/managed by the factory's lifecycle, not by new family code.

This exclusion is explicitly documented in PI and P S1-ARCH-04; HTB also resolves these factory facets from canonical registrations when constructing the separate hook factory. Hook flags are the consuming **hook** factory's responsibility; FullSpread is not itself a V4 hook and needs no mined hook address or HookFlags facet. [PI notice; P S1-ARCH-04, S1-A57; HTB setup; SK-H. Acceptance: FS-A03.]

## 4. Proposed file and package contract

### FS-06 - Files and division of responsibility

All files below are proposed, not created by this contribution. Production paths are relative to the new `fullSpread/` directory:

```text
interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol
interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol
UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol
UniswapV4FullSpreadStandardExchangeVaultComponent_FactoryService.sol
UniswapV4FullSpreadStandardExchangeVaultComponentBindings.sol
UniswapV4FullSpreadStandardExchangeVaultTypes.sol
UniswapV4FullSpreadStandardExchangeVaultRepo.sol
UniswapV4FullSpreadStandardExchangeVaultMath.sol
UniswapV4FullSpreadStandardExchangeVaultProjection.sol
UniswapV4FullSpreadStandardExchangeVaultPlanner.sol
UniswapV4FullSpreadStandardExchangeVaultExecution.sol
UniswapV4FullSpreadStandardExchangeVaultMoneyFacet.sol
UniswapV4FullSpreadStandardExchangeVaultMoneyTarget.sol
UniswapV4FullSpreadStandardExchangeVaultQuoteFacet.sol
UniswapV4FullSpreadStandardExchangeVaultQuoteTarget.sol
UniswapV4FullSpreadStandardExchangeVaultOutFacet.sol
UniswapV4FullSpreadStandardExchangeVaultOutTarget.sol
UniswapV4FullSpreadStandardExchangeVaultQueryFacet.sol
UniswapV4FullSpreadStandardExchangeVaultQueryTarget.sol
UniswapV4FullSpreadStandardExchangeVaultSYMoneyFacet.sol
UniswapV4FullSpreadStandardExchangeVaultSYMoneyTarget.sol
UniswapV4FullSpreadStandardExchangeVaultSYQueryFacet.sol
UniswapV4FullSpreadStandardExchangeVaultSYQueryTarget.sol
UniswapV4FullSpreadStandardExchangeVaultCallbackFacet.sol
UniswapV4FullSpreadStandardExchangeVaultCallbackTarget.sol
test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol
test/behaviors/Behavior_UniswapV4FullSpreadStandardExchangeVaultPackage.sol
```

Retain the current source-file versus linked-library distinction: `...SwapProjection` is a separately linked library defined in `...Projection.sol`; `...ExecutionPreparation` is a separately linked library defined in `...Execution.sol`. Do not create nonexistent extra source files merely because there are six links.

Responsibilities:

- **Facet:** canonical metadata and exact selector declaration only; inherit its target.
- **Target:** public validation and interface mapping, caller identity retained, no external self-call to fake internal delegation.
- **Repo:** family configuration, booked and reserved custody, initialized marker, operation/context guard, one-use callback commitment. Use `bytes32(uint256(keccak256(abi.encode("indexedex.vaults.standard.exchange.uniswap.v4.fullSpread"))) - 1)` with the dual layout accessors. No duplicate share supply or authoritative position checkpoint.
- **Types:** preserve `Config`, `Amounts`, `WrappedReservations`, `Inventory`, `OperationKind`, `Phase`, `ActionKind`, `FailureKind`, `Operation`, `PoolState`, `Snapshot`, `TickState`, `BitmapWord`, `ProjectedState`, `Witness`, `Action`, `Failure`, and `Plan` responsibilities from PT. Add an execution-context discriminator `OwnUnlock` / `BorrowedUnlock` and the original payer to the internal run/request contract; do not make either caller-selectable public calldata.
- **Math:** exact integer inventory, proportional issuance/removal, full-range clamps, normalization; no spot-NAV minting.
- **Projection/SwapProjection:** bounded canonical manager state simulation, including fee growth, active/owned liquidity, ticks and bitmap overlays.
- **Planner:** full candidate selection, precise domain errors, conditional withdrawal fallback; all read witnesses completed for the entire candidate before execution.
- **Execution/ExecutionPreparation:** funding, authority, ledger reservation, action dispatch, actual manager calls, fee/principal separation, settlement, native adaptation, payout, commit.
- **Callback target:** authenticates and consumes an expected payload once, then invokes the same action executor used by borrowed execution. It never authenticates a caller by a supplied `bool unlocked`.

Use canonical `Pool.TickInfo` and `Position.State` in memory overlays; initial and current cached values are distinct. A witness SHALL cover later-only reads as well as earlier actions; discovering a tick late does not excuse omitting its initial value from preflight state-change checks. Do not copy raw manager storage layout when canonical readers exist. [PT; PR; PC; PE; SK-A; P S1-QUOTE-01. Acceptance: FS-A03/07/20/21/27.]

### FS-07 - Complete package inputs and identity

Define both structs on `IUniswapV4FullSpreadStandardExchangeVaultDFPkg`, which extends `IDiamondFactoryPackage` and `IStandardVaultPkg`.

```solidity
struct PkgInit {
    IFacet erc20Facet;
    IFacet erc2612Facet;
    IFacet erc5267Facet;
    IFacet basicVaultFacet;
    IFacet standardVaultFacet;
    IFacet moneyFacet;
    IFacet quoteFacet;
    IFacet outFacet;
    IFacet queryFacet;
    IFacet syMoneyFacet;
    IFacet syQueryFacet;
    IFacet callbackFacet;
    IPoolManager poolManager;
    IVaultRegistryDeployment registry;
    IVaultFeeOracleQuery oracle;
    IWETH wrappedNative;
    IDiamondPackageCallBackFactory diamondFactory;
    address[6] linkedLibraries;
}

struct PkgArgs {
    PoolKey poolKey;
    address rateAsset;
    string name;
    string symbol;
    uint16 maxZapBps;
    int24 maxZapTickMove;
}
```

This preserves the current PairToken shape, not just its five common fields. The six links SHALL be, in order: Math, Projection, SwapProjection, Planner, Execution, ExecutionPreparation. Every family facet's implementation-only `linkedComponents()` result SHALL agree with those six fixed compiled links. No constructor address is a runtime-selected delegatecall destination.

Proposed identity:

```text
PRODUCT_ID = keccak256("UniswapV4FullSpreadStandardExchangeVault")
bindingHash = keccak256(abi.encode(PkgInit))
packageSalt = keccak256(abi.encode(PRODUCT_ID, bindingHash, canonicalPkgArgs))
```

The added product domain is a deliberate sibling distinction, not a claim that current PairToken uses that exact salt formula. All 12 facets, five infrastructure bindings, six links, and all instance arguments participate. Name/symbol and both zap limits are not silently excluded. Package arrays queried while delegated into the factory SHALL be retrieved through immutable `SELF`, as in PD, rather than reading foreign-context storage.

Expose `bindingHash()` and `deployVault(PkgArgs) returns (address vault)`. Implement the current package declaration, facet metadata/cuts, `diamondConfig`, `calcSalt`, `processArgs`, `initAccount`, `updatePkg`, and `postDeploy` signatures. Update/post-deploy validate the authentic package/account binding; they do not grant a normal-operation upgrade surface. [PI; PD; PC; SP. Acceptance: FS-A01/03/04/07.]

### FS-08 - Package validation and initialization errors

Retain these named package errors and assign them precisely:

| Error | Required rejection |
|---|---|
| `InvalidComponent()` | Missing code on required manager/registry/oracle/factory/facet/link, incompatible selector set, duplicated/foreign selectors, wrong fixed compiler links, or otherwise invalid required component. |
| `InvalidWrappedNative()` | Absent/incompatible wrapper, failed supported zero-unit interface probe, non-18-decimal wrapper, or duplicate ERC-20 faces caused by native/wrapper collision. A successful zero-unit probe is not a proof of all future wrapper behavior. |
| `InvalidPoolKey()` | Unordered/equal currencies, currency1 native/absent code, nonzero currency0 absent code, self-referential currency, nonzero hooks, illegal tick spacing/static fee, or uninitialized pool. |
| `InvalidRateAsset()` | Rate asset is neither declared ERC-20 face. |
| `InvalidZapLimits()` | `maxZapBps == 0`, above 10,000, or negative `maxZapTickMove`. |
| `NotCalledByRegistry()` | `processArgs` not entered with the bound registry as caller and bound diamond factory as delegatecall context. |
| `InvalidInitializationContext()` | Direct package initialization, wrong factory-account package association, mismatched recorded argument bytes, noncanonical encoding, or wrong lifecycle caller/context. |
| `AlreadyInitialized()` | Authentic instance initialization attempted again. |

Require `currency0 < currency1`, `0 < tickSpacing <= 32767`, hook address zero, static fee at most `1_000_000` including fee zero, and nonzero initialized sqrt price. Reject dynamic-fee flags. Validate the candidate proxy's self-currency condition during initialization as well as earlier processing. There are no default zap parameters, token-decimal allowlists, or issuer policy switches.

Initialize once on the proxy:

1. ERC-20 metadata, decimals 18, supply zero.
2. EIP-712 name and version `"1"`; canonical permit nonce storage untouched.
3. Family pool/configuration, full-range ticks, cached rate-asset decimals, empty reservations and idle guard.
4. Basic vault faces in actual PoolKey order, mapping native to wrapped-native only at the public ERC-20 boundary.
5. Standard vault oracle reference, zero fee-type IDs, truthful deduplicated package interfaces, and contents hash of a **sorted copy** of the faces. Keep stored discovery order unchanged.

`vaultFeeTypeIds()` SHALL be zero; binding the fee oracle does not enable a fee forbidden by S1-D03. [PI errors; PD constructor, `_validate`, `initAccount`, `processArgs`; P S1-ARCH-03/05. Acceptance: FS-A04/05/06/07/17.]

### FS-09 - Registry and factory delivery contract

Proposed `UniswapV4FullSpreadStandardExchangeVaultComponent_FactoryService` SHALL deploy facets through existing CREATE3/artifact helpers, construct/link the fixed libraries through the existing artifact loader, and provide the typed manager extension:

`deployUniswapV4FullSpreadStandardExchangeVaultDFPkg(indexedexManager, PkgInit)`.

That helper SHALL call the existing registry `deployPkg`, not invent an installed manager selector unless repository practice independently requires one. The new package's `deployVault` SHALL call its bound registry's existing `deployVault(this, abi.encode(args))`. Register and discover the resulting vault under both ERC-20 faces and its actual declared types. No migration of an existing type or vault is required.

The vault uses the ordinary diamond callback factory. Consuming hooks separately keep their existing `deployHookVault` / CREATE2 mining / staged initialization and finalization path. Never apply hook mining or the hook package salt policy to FullSpread vault instances. [RD; PD `deployVault`; PTB setup; SK-T/SK-H. Acceptance: FS-A01/03/07/32.]

## 5. Money, callback, and already-unlocked hook entry

### FS-10 - Single authoritative ownership model

Inherit P's S1-ACC-01 through S1-ACC-07 with no scalar replacement:

```text
S = ERC20 total supply
L = this diamond's manager position liquidity
B_i = booked shareholder idle, in actual pool-currency raw units
N_i(P,L) = clamped canonical removable principal, rounded down
R_i = N_i(P,L) + B_i at the prescribed incumbent checkpoint

raw local custody =
  incumbent booked idle
  + pending caller inventory
  + reserved exit allocation
  + reserved refund
  + unbooked excess
```

Wrapped reservations are alternate representations of native amounts, not an additional asset category. Shared basic-vault reserves are a published book snapshot, not a second reserve ledger. Only booked balances may remain among the operation's reservation categories at successful external return. Unsolicited token/ETH balances are excluded from issuance, compound, terminal payout, and rebootstrap.

Every entry checkpoint separates actual manager principal from informational fees. `callerDelta` already includes fees; do not add `feesAccrued` again as new custody. After maintenance, and after an entry swap, checkpoint incumbent fees once before attributable addition. Exit-sale fees on remaining liquidity belong to remaining holders. [P S1-ACC-01/04/06/07; PM `modifyLiquidity`; PE `_account`. Acceptance: FS-A12/13/15/16/19.]

### FS-11 - Paired methods and exact issuance

Retain PV's exact paired method signatures and return shapes:

```solidity
function depositPair(uint256 amount0Max, uint256 amount1Max, uint256 minShares,
    address recipient, uint256 deadline) external payable returns (uint256 shares);
function previewDepositPair(uint256 amount0Max, uint256 amount1Max)
    external view returns (uint256 shares, uint256 used0, uint256 used1);
function redeemPair(uint256 shares, uint256 min0, uint256 min1,
    address recipient, uint256 deadline) external returns (uint256 amount0, uint256 amount1);
function previewRedeemPair(uint256 shares)
    external view returns (uint256 amount0, uint256 amount1);
```

Genesis SHALL use paired entry, positive amounts and positive fundable liquidity, with `q=floor(sqrt(a0*a1))` under the inherited checked-product domain, all `q` to the recipient, no sink/virtual supply. For positive supply with both reserves positive:

```text
qQuote = min(floor(a0*S/R0), floor(a1*S/R1))
used_i = min(a_i, ceil(qQuote*R_i/S))
```

One-sided reserve branches use the one positive denominator and consume the full specified live-leg maximum, zero of the other. Positive supply with both reserves zero rejects.

At the post-checkpoint pre-addition price `P*`, freeze incumbent `S,L,B`. With actual added `dL` and accepted caller remainder `J_i`:

```text
G_i = N_i(P*,L+dL) - N_i(P*,L)
paired C_i = G_i + J_i
qCredit = min over positive R_i of floor(S*C_i/R_i)
paired q = min(qQuote, qCredit)
```

Use actual final `q` for minimum/output/events. Do not reselect accepted input after the final cap. Pull only accepted ERC-20 maxima; native paired entry reserves `msg.value == amount0Max` and refunds exactly unused ETH to the caller. [P S1-ACC-02/07, S1-OP-01, S1-NATIVE-01; PV. Acceptance: FS-A11/12/17.]

### FS-12 - Single-token issuance and complete selected conversion

Keep the seven-argument canonical nonpayable `exchangeIn` ABI in SI. Accepted ERC-20 routes are exactly `C0 -> V`, `C1 -> V`, `V -> C0`, `V -> C1`, where `V` is this diamond. No raw-zero SE token, currency-to-currency, identical-token, V-to-V, or unrelated-token route is added.

For zap entry, require existing positive supply and both prepared reserves positive; enforce the inherited cap `amountIn <= floor(inputReserve*maxZapBps/10000)`. Use caller-only input, selected swap amount `floor(amountIn/2)`, canonical directional price limit, the same entry-only tick-move bound, final incumbent fee checkpoint, and affordable full-range addition.

**Complete-conversion delta:** if the selected positive half-swap does not consume its entire specified input, planning and execution SHALL reject with a proposed family error `IncompleteConversion(uint256 expectedInput, uint256 consumedInput)`. A zero-sized swap retains the inherited no-swap handling; it does not excuse zero minted output. Do not silently accept a partially filled entry swap merely because later liquidity can still be added.

Issuance remains:

```text
zap C_i = G_i
zap q = min over positive R_i of floor(S*G_i/R_i)
```

Reject zero final shares. Accepted input not spent by the liquidity addition, `J_i`, SHALL be completely booked to shared backing at mint, with no extra shares, exactly as S1-ACC-07. `previewZapCredit` and `ZapCredit` SHALL disclose both `G_i` and this uncredited `J_i`. No second token is paid to the depositor, no caller reservation remains, and no remainder is put into unbooked custody. This is the inherited, explicit entry-residual contribution policy, **not** permission to donate an exiter's unsold allocation.

This reading preserves the brief's economic exemplar while narrowing selected swap execution. If the intended owner meaning is instead "entry may retain no uncredited `J_i` at all," that is a change to S1-ACC-07, not something an implementer may silently infer; section 8 identifies it for coordinator resolution. [B decision 6; P S1-ACC-07, S1-OP-02; PV `previewZapCredit`; R2 required adaptation 4. Acceptance: FS-A12/13/14/19/30.]

### FS-13 - Redemption, last share, and complete payout

After selected maintenance and final checkpoint, allocate for `s`:

```text
dL = floor(L*s/S)
idleAllocated_i = floor(B_i*s/S)
```

Burn the full submitted `s`, not a retained fraction. Principal removal plus allocated idle belongs only to the exiter. For paired exit pay both actual currencies. For single-token exit sell **all** unwanted allocated currency after removing `dL`, with no liquidity re-addition, then pay allocated desired currency plus actual proceeds. Full unwanted consumption is mandatory; partial sale SHALL produce `IncompleteConversion` or the planner's earlier exact domain error and roll back everything. `minAmountOut` applies to actual requested-token delivery, not a hypothetical linear rate.

No successful one-token exit may pay the other token, leave an exit allocation, mint an IOU, queue an unpaid part, or burn shares and donate the residual. A positive burn with zero total payout rejects `ZeroPayout()`.

Paired last-share exit removes all owned liquidity and pays all booked assets and operation-generated owned receipts; afterwards `S=L=B0=B1=0`. Old unbooked assets remain unbooked. Terminal single-token exit is conditional on actual remaining pool liquidity after removal and can revert even when paired exit is possible. A later paired bootstrap is allowed. [P S1-ACC-03/05, S1-OP-03/04; B decision 6. Acceptance: FS-A15/16/18/31.]

### FS-14 - Maintenance, donation, and withdrawal fallback

Retain permissionless `compound()` and `donate(address token,uint256 amount)` with their PV signatures, returns/events and native support. Compound uses the full incumbent book, collects fees, uses the inherited ratio-swap/quarter-cap and `DUST=1000` raw-unit rules, reinvests affordable amounts, then performs the nonrecursive final checkpoint. No vault-level fee, external fee-manager notification, or supply change.

Explicit donation requires positive live supply/amount, pulls only the same-call contribution, books exact receipt, and mints zero shares. It never adopts unrelated surplus. A clean empty compound is a no-op, never an empty-position poke.

`WithdrawalMode { FullCompound, CollectOnly }` and `MaintenanceReason { None, MaintenanceWorkLimit, MaintenancePriceLimit, MaintenanceLiquidityLimit, MaintenanceDeltaLimit }` retain their ordering and meaning. Full candidate wins when valid. Collection-only starts from fresh original state only on the four exact S1-EXIT-01 predicates, including whole-candidate work exhaustion. No catch-and-retry after manager mutation. Token/wrapper/payout failure, invalid custody, stale state, unavailable final sale, or missed user minimum is not an invented fallback reason.

The borrowed-unlock branch SHALL use this same economics and selection. Being in a hook does not mean skip compound, use only local idle, or force collection-only. [P S1-P01/P05/P07, S1-OP-05, S1-EXIT-01; PE. Acceptance: FS-A14/15/19/21/29.]

### FS-15 - Native, SY, and unsupported exact output

Preserve native ETH as actual currency0, canonical wrapper as its ERC-20 face, raw units, wrapper validation, native sync immediately before native value settlement, exact receipts, and no ERC-20 call to zero. Native SY deposit and redemption remain real payable/native-output operations. SE remains nonpayable and uses wrapped faces. A wrapper that is an actual currency in an ERC-20 pool is not a native alias.

The 16 SY methods operate on the same shares. `yieldToken() == address(this)`. Native pools expose `[address(0), C0, C1]` as input/output alternatives; ordinary pools expose `[C0,C1]`. Empty reward arrays are truthful; accrued LP fees cannot be claimed twice as a separate reward.

Both installed exact-output methods SHALL always revert `ExchangeOutNotAvailable()` before token/share/manager effects. Do not emulate exact output by binary-searching and overspending exact input, including in the hook-context branch. [P S1-P02/P03, S1-NATIVE-01, S1-API-02/03; SI/SO. Acceptance: FS-A08/09/17/18/40.]

### FS-16 - Trust flags, disable, and stable read boundaries

Preserve normal-context false-flag exact receipt and contract-only true-flag unbooked-credit rules from SI/P:

- EOA and construction-time `pretransferred=true`: canonical `EOAPretransferNotAllowed()`.
- Booked inventory cannot cover a pretransfer shortfall: exact `TransferDeltaInsufficient(claimed,available)`.
- Process exactly declared exact input; surplus is unbooked and not refunded.
- Ordinary redemption burns caller-owned shares; internal/pretransferred-share paths use the canonical guarded vault-held-share contract. A hook's redundant approval to the vault does not create a right to burn another holder's balance.
- Disabled vaults reject issuance and explicit donations, but permit compound and supported exits with normal maintenance.

All family money methods and callbacks share a cross-facet guard through external payouts and final book commit. Family economic queries/previews, SY rate, and `getRate` SHALL reject while this vault is busy. Shared basic reserve queries return the last committed snapshot; canonical token/domain queries retain their existing behavior. Manager-unlocked is not vault-busy: idle-vault economic reads may run while another actor owns the outer unlock.

Deadlines allow equality. Zero/self recipients, zero inputs, missed minima, failed delivery and reentry reject atomically. [SI; P S1-SEC-01/02, S1-ACC-04; SK-T. Acceptance: FS-A18/19/23/27/28/34/35.]

### FS-17 - Exact bounded planning

Carry forward all three shared-candidate bounds: 64 swap iterations, 12 initialized crossings, 16 distinct bitmap words including owned boundary words. Equality succeeds; the next admission fails with the exact inherited budget error. Repeated crossing counts again, repeated cached word does not. At most 14 distinct tick records are needed for the inherited candidate domain. Counters span maintenance and entry/final sale, not each individual swap.

Entry/compound have one full candidate. Withdrawals have at most two independently initialized candidates. The full failed candidate contributes no overlay/output to the fallback. Preflight the entire operation before ERC-20 pulls, burns, or manager mutation. Check actual actions/deltas and complete read witnesses after callbacks/interactions; changed economic state gives `EconomicStateChanged()`.

The manager lock state only chooses settlement execution context, not the economic plan. Idle `previewExchangeIn` while unlocked must quote from the actual current manager state using the same plan as the following admitted execution. No gasleft-based domain, fake quote blob, spot substitute, or unbounded inversion. [P S1-QUOTE-01, S1-GAS-01; PT `Witness/ProjectedState`; PE. Acceptance: FS-A20/21/30/36/41.]

### FS-18 - Already-unlocked entry without changing current hooks

**Proposed implementation choice:** make the already-unlocked entry a narrow branch of the existing canonical `exchangeIn`, not a new public selector that current hooks never call.

Sources show current hooks call `IStandardExchangeIn.exchangeIn(..., recipient=address(hook), pretransferred=false, deadline=block.timestamp)` after taking or otherwise owning input. H1 handles wrap/unwrap this way; H3 `_buffer`, `_unwrap`, and `_executePlannedSwap` do the same. A standalone new `exchangeInUnlocked` selector would not integrate those hooks unless their code changed.

Define an internal execution entry `_executeAlreadyUnlocked` with these rules:

1. Called only by the standard `exchangeIn` dispatch after route/deadline/amount validation; manager state selects it, never a caller-provided flag.
2. Vault must be initialized and idle, callback commitment and reservations empty, and its own backing-currency manager deltas zero at entry.
3. Bound PoolManager must currently be unlocked.
4. Caller must have code; recipient must equal `msg.sender`; `pretransferred` must be false; native `msg.value` is unavailable on this ABI. Otherwise revert proposed `InvalidUnlockedContext()`.
5. Caller is the sole payer/share owner. Token entry pulls exactly the requested input from that caller under allowance and observes exact receipt. Share exit burns only that caller's actual shares. No `payer`, arbitrary holder, callback payload, PoolKey, external execution address, or manager creditor can be supplied.
6. Record the original caller and context internally for the complete guarded operation; no external self-call, `tx.origin`, delegated signature, or hook impersonation.
7. Validate immutable pool identity, normal issuance disable, amount/size/tick limits, selected plan, actual receipts, minimum and recipient exactly as in the ordinary path.

This is deliberately a **permissionless, self-funded contract integration** boundary, not a claim to authenticate that a caller is an active hook on a particular consuming PoolId. Its authorization is ownership/allowance of the caller's input plus fixed route/recipient/custody rules. The unlocked flag confers no authority over incumbent backing or third-party shares. A random unlocked caller without those funds/authority fails; a funded contract satisfying the same rules is allowed. No mutable hook allowlist or circular vault/hook deployment binding is needed.

That distinction is important: current hook ABI calls do not furnish an authenticated active `H/Q` context. If the coordinator chooses a hook-exclusive policy, it must explicitly specify how to prove that context and acknowledge the separate hook integration change; it cannot claim the manager's global unlocked flag identifies a locker. My selected boundary needs no such privileged role and leaves current hook packages untouched.

Locked standard calls retain ordinary payer/recipient/pretransfer semantics and the authenticated unlock callback. Direct paired methods, standalone compound/donation, and SY entrypoints retain `ManagerAlreadyUnlocked()` rather than gaining additional undocumented context variants. Hook deposits/withdrawals use the four standard exact-input routes. [H1; H2; H3; SI; PE `_start/_action`; P S1-SEC-01; B money/hook requirements. Acceptance: FS-A27-35.]

### FS-19 - Dual-context action execution and delta closure

Current PE opens a separate authenticated unlock for each selected manager action, not merely once at public entry. Therefore removing the `_start` rejection alone is insufficient: `_action` also rejects/opens unlock. FullSpread SHALL deliberately share the actual manager-action executor beneath two dispatch paths:

- **OwnUnlock:** preserve the current action commitment, `PoolManager.unlock(payload)`, callback validation/consumption, return-data verification, and relocked check.
- **BorrowedUnlock:** directly invoke the same internal action/account/settlement code in the diamond's context. Never call `unlock`, the public `unlockCallback`, or pretend `msg.sender` is the manager. No callback commitment is fabricated. Verify the manager remains unlocked while borrowed actions execute.

For each action, execute `modifyLiquidity`/`swap` as the vault diamond, validate actual callerDelta/fees and planned state, settle the vault's debts, take its credits into the correct reservation, and return its **own** currency deltas to zero. Initial nonzero own deltas reject with `SettlementMismatch()`; they are not a gift, loan budget, or authorization. The position remains owned by the diamond, never hook/router/library.

After payout and book publication, borrowed execution clears its reservations/guard, returns only the actual requested output, and leaves the outer manager unlocked. The hook/router retain their own address/currency debts until the outer unlock finishes. Do not demand the manager's global nonzero-delta count be zero inside the vault return, and do not settle another actor's debt on its behalf.

Every debt resets sync for its own currency immediately before payment; native always calls native sync before value settle. Do not save/restore arbitrary transient slots or rely on an outer actor's old sync snapshot. Current hook calls in H1/H3 take/buffer before their final `_settle`, whose own sync is performed after vault return. Regression-test this ordering.

A vault failure reverts the vault invocation and its descendant effects. If the outer hook propagates it, the whole swap rolls back; if a separate real test router catches it, earlier independent outer effects remain, the vault is unchanged, and the router must still close its own deltas. No false assertion that a caught inner error relocked the manager. [PE `_action/_managerAction/_settle`; PM `unlock`, `settle`, `settleFor`, `take`; H1/H3; R2 hook integration. Acceptance: FS-A27/28/31/33/34/35.]

### FS-20 - Events and operational error contract

Retain the semantic payloads of PV's `PairDeposited`, `PairRedeemed`, `WithdrawalSale`, `Donated`, `Compounded`, `ZapCredit`, and `WithdrawalMaintenanceSelected`; retain canonical ERC-20/SY events. Context branches must report the actual hook/integrator as caller, not the PoolManager or an external self-call.

Retain inherited operation errors including `ReentrantOperation`, `ManagerAlreadyUnlocked`, `EconomicStateChanged`, `InvalidAccountingState`, `ZeroPayout`, the three budget errors, and `IssuanceDisabled`, plus the actual execution errors `InvalidCallback`, `InvalidNativeValue`, `NativeTransferFailed`, and `SettlementMismatch` where applicable. Add the precisely defined `InvalidUnlockedContext`, `IncompleteConversion`, and rate errors in FS-21. Preserve canonical route/deadline/minimum/SY errors instead of generic `require(false)` failures.

No special event is necessary merely because the same operation used borrowed execution; trace context in tests rather than adding redundant public state. Compute new selectors/topics/interface IDs through the repository's canonical later verification workflow; this document invents no hexadecimal constants. [PV; PE; P S1-OBS-01; SK-A. Acceptance: FS-A02/09/14/27/34.]

## 6. Rate, quote, and issuance separation

### FS-21 - Executable normalized `getRate`

Install canonical `IRateProvider.getRate()` on `QueryFacet`. Its one immutable denomination is `PkgArgs.rateAsset`, an ERC-20 face. It SHALL return:

```text
oneShareRaw = 1e18
E(q) = complete supported single-token redemption payout of q raw shares
       into rateAsset, from the current state, including selected maintenance,
       fee attribution, removal, remaining-liquidity sale and all integer rules

getRate = floor(E(oneShareRaw) * 1e18 / 10^rateAssetDecimals)
```

Compute `E` using the same planner as `previewExchangeIn(V,1e18,rateAsset)`. No actual holder is required for a view, but total supply must cover the hypothetical redemption. Do not divide whole-book liquidation value by total supply, use SY `exchangeRate`, substitute NAV, scale a smaller redemption, cache a previous rate, or synthesize a 1:1 bootstrap.

Proposed exact rate failures:

- `InsufficientRateSupply(uint256 available,uint256 required)` if `S < 1e18`, including zero supply;
- propagated complete planner/conversion/budget error if the hypothetical one-share exit cannot execute;
- `RateUnavailable()` if otherwise valid proceeds normalize to zero;
- `RateNormalizationOverflow()` if the mathematically normalized result cannot fit `uint256`.

Normalize without an unnecessary `10^d` overflow. With `d<=18`, multiply by `10^(18-d)` with explicit final-result overflow handling; with `d>18`, divide by `10^(d-18)`, treating an exponent whose divisor exceeds all possible uint256 proceeds as zero followed by `RateUnavailable`. This is a mathematical result, not a token-decimal allowlist. Examples: 2,400,000 raw units of a six-decimal target gives `2.4e18`; 18-decimal targets need no numeric decimal correction.

An idle vault may answer while the manager is already unlocked; a busy vault rejects `ReentrantOperation`. It must not return half-updated rates to a token callback. [B decision 8; R2 Rate Provider section; P S1-API-04, S1-QUOTE-01; HC `_rate`. Acceptance: FS-A22-26/36.]

### FS-22 - Three separate numerical contracts

| Surface | Required meaning | Forbidden substitution |
|---|---|---|
| Paired and zap issuance / `previewZapCredit` | S1-ACC-02/07 attributable per-currency share credit at the prescribed checkpoint | Neither SY spot value nor `getRate` is an issuance denominator. |
| SY `exchangeRate` | `floor(Vraw*1e18/S)` with raw-denominated spot-marked principal, booked idle, and pending owned fees; zero at zero supply | Not a normalized whole-token WAD oracle and not withdrawal proceeds. |
| `previewExchangeIn(V,q,Ci)` / SY redemption preview | Amount-specific executable exit `E_i(q)` | Not `q*getRate`, not whole-book value prorated. |
| `getRate` | Normalized `E_rateAsset(1e18)` only | No NAV/spot-accounting alias and no general finite-trade guarantee. |

For SY, retain P's exact-rational one-floor conversion of `A0/A1` at current sqrt price, then final supply division. `A_i=N_i+B_i+F_i`, with pending fee counted once. Avoid `P*P` overflow and do not silently replace exact rational conversion with two floors. Retain cached asset decimals only as metadata/normalization context.

The consuming hook's D60 held-reserve book is `heldShares * configuredRate` with its established scaling. Its actual deposit and withdrawal settlement still uses amount-specific SE calls and observed receipts. Nonlinearity of `E(q)` does not alone make a rate-aware pool impossible; neither does it make its scalar valuation economically safe.

No independent market is assumed. A same-backing-pool historical/TWAP observation, if separately supplied, is endogenous and not a manipulation proof. This contribution selects live executable rate semantics and does not introduce an observation oracle, external price gate, or a different accounting provider. Production economic safety of the consuming invariant is not established by ABI/settlement acceptance. [P S1-P06, S1-QUOTE-02, S1-ACC-07; L held-reserve valuation; R2. Acceptance: FS-A12/22-26/39.]

## 7. Test and acceptance requirements, including cross-vault hook integration

### FS-23 - Existing hook families and the exact compatibility claim

The current tree contains these seven package families, all with typed package interfaces read in this assignment:

| Directory under `contracts/hooks/uniswap/v4/standardExchange/` | Interface basename / actual binding shape | Required FullSpread exercise |
|---|---|---|
| `single/` | `IUniswapV4SingleStandardExchangeBufferHookPackage`; one SE and one pair token; no reserve-holding LP product | Exact-input wrap and unwrap through V4 `beforeSwap`, FullSpread called while manager unlocked. Exact output rejects. |
| `constantProduct/single/` | `IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage`; one SE/pair leg, raw leg, provider, decimals, liquidity-owner settings | FullSpread buffered leg and another SE share as the raw token; both directions. Also identity-share configuration where valid. |
| `dual/` | `IUniswapV4DualStandardExchangeBufferConstantProductHookPackage`; two distinct SEs/tokens, provider per buffered leg | Primary two-vault proof: both shares as identity currencies; separately both underlying-token legs buffered into real vaults. |
| `orbital/` | `IUniswapV4StandardExchangeOrbitalBufferHookPackage`; three token/decimal/SE/provider slots | FullSpread plus another real SE and the required remaining leg; test all relevant FullSpread input/output positions. |
| `weighted/` | `IUniswapV4StandardExchangeWeightedBufferHookPackage`; arrays, `n` in 2-8, weights, SEs, providers, token/share decimals | Two real SE legs and valid configured weights; at least the minimal 2-leg setup and a supported larger setup. |
| `stable/quad/curve/` | `IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage`; exactly four legs, fixed arrays, baseAmp | Four valid legs including FullSpread and another SE; no false inference that a volatile basket has a peg. |
| `stable/quad/balancer/` | `IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage`; **dynamic arrays, 2-5 tokens**, schema v2, baseAmp | At least 2-leg and 5-leg valid setups; do not copy an obsolete fixed-four constructor. |

The package interface source is the file named above in each directory's `interfaces/` subdirectory. Buffered legs require the provider when pair token differs from SE; configure FullSpread itself as provider only when the bound pair token equals its `rateAsset`. A different denomination needs a deliberately different binding, not context-sensitive `getRate`. Identity legs require no provider and value raw held shares under D60.

No new hook-package field or FullSpread whitelist is supported by the inspected evidence. H4 `_validateArgs` accepts distinct SEs with eligible declared tokens and the required providers; it does not demand a particular vault family. H1/H3 use the existing standard ABI. Consequently the proposed FullSpread changes, not hook edits, solve the demonstrated nested-unlock incompatibility.

This compatibility claim is **route-specific**:

- In an identity configuration `token=SE=V`, trading V shares is ordinary share custody; it does not prove V's underlying entry/exit works inside the unlock.
- In a buffered configuration `token=rateAsset`, `SE=V`, the hook really mints/burns V through standard methods and requires FS-18/19.
- Exact-output hook routes that delegate to FullSpread Out are intentionally unavailable. A hook exact-output route that never converts FullSpread, such as a pure identity-share route, is not falsely prohibited by that statement.
- Optional multi-step hook LP joins/exits or external-transition quoting are not automatically proved by one exact-input swap. H5 explicitly has transition and fallback quote branches. Do not advertise `IStandardExchangeTransitionQuote`, `IStandardExchangeExternalQuote`, or `IStandardExchangeRateQuote` with a placeholder blob merely to make interface discovery succeed.

The minimum supported buffered cross-vault topology SHALL use independently owned vaults whose backing PoolIds differ, even when they share a currency and use the same manager. This is not a second backing/conversion venue for FullSpread; V still operates only its own pool. Two vaults that modify the same backing PoolId within one composed route can change each other's planned output and require a separate exact sequential proof. They SHALL be reported as unverified rather than quietly counted as covered by disjoint-pool fixtures.

If implementation reveals a particular existing hook requires a transition capability for an advertised route, raise **FS-24**, the separate integration-change requirement below, with the rejecting function and concrete failing path. Do not invent a package change in advance or label all integration impossible. [H1-H5; HP1-HP7; L D60; B hook requirements. Acceptance: FS-A32-40.]

### FS-24 - Separate integration-change gate, not authorization to redesign hooks

No hook change is proposed for the required identity-share and disjoint-backed exact-input buffered routes. A discovered blocker SHALL be classified:

1. FullSpread money/preview/context defect: fix within the new family.
2. Intentional exact-output or budget limitation: preserve atomic rejection and document unsupported route.
3. Existing consumer contract requiring a genuinely absent stateful quote or incompatible denomination: record the exact consumer, selector, arguments, reason, and smallest separate requirement before changing that hook.

A later added quote facet must implement real transitions, including holder/supply bookkeeping, manager overlays, fee attribution and projected rate, with explicit selector/field/test additions. Merely returning live values for projected states is forbidden. The current original does not authorize that extension, enlarge hook package inputs, or commit to support same-backing-pool sequential composition without evidence. [B scope and hook requirement; P S1-API-04; TQ; HC transition detection; H5. Acceptance: FS-A03/36/42.]

### FS-25 - Production-first fixtures and test files

The proposed `TestBase_UniswapV4FullSpreadStandardExchangeVault` SHALL follow the current PTB harness pattern: `IndexedexTest` plus `TestBase_Weth9`, each parent setup invoked correctly, real artifact-deployed PoolManager, canonical shared facets, full family components and links, manager registry package deployment, and public paired bootstrap. Do not subclass a concrete PairToken/Wings vault or use another family's storage as the new family.

Use real consuming hook diamonds and their real hook factory/registry/flag-mining/staged-finalization workflow. Preserve existing successful fixture patterns but ensure the **same PoolManager** is supplied for the tested vault/hook composition. Two different managers do not demonstrate the requested borrowed-unlock path. Another real SE may be a second separately configured FullSpread instance; additionally exercise an established non-FullSpread SE via its current production-first base. A canned `MockStandardExchange` is not acceptable.

No vault, facet, package, manager, fee oracle, or registry mock; no SUT/PoolManager `etch`, storage injection, fake return deltas, or impersonation of the SUT as a funding shortcut. Minimal peripheral tokens, actors, rejecting receivers and real unlock routers are permitted. Bootstrap shares through actual public entry. Baseline comparisons use fresh real fixtures and remain separate from acceptance tests.

Proposed specs under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`:

```text
UniswapV4FullSpreadStandardExchangeVault_Package.t.sol
UniswapV4FullSpreadStandardExchangeVault_Surface.t.sol
UniswapV4FullSpreadStandardExchangeVault_Accounting.t.sol
UniswapV4FullSpreadStandardExchangeVault_Money.t.sol
UniswapV4FullSpreadStandardExchangeVault_Compound.t.sol
UniswapV4FullSpreadStandardExchangeVault_Previews.t.sol
UniswapV4FullSpreadStandardExchangeVault_Native.t.sol
UniswapV4FullSpreadStandardExchangeVault_Callbacks.t.sol
UniswapV4FullSpreadStandardExchangeVault_Rate.t.sol
UniswapV4FullSpreadStandardExchangeVault_Invariants.t.sol
UniswapV4FullSpreadStandardExchangeVault_Gas.t.sol
```

Proposed integration specs in the same directory:

```text
UniswapV4FullSpreadStandardExchangeVault_HookSingle.t.sol
UniswapV4FullSpreadStandardExchangeVault_HookSingleConstantProduct.t.sol
UniswapV4FullSpreadStandardExchangeVault_HookDualConstantProduct.t.sol
UniswapV4FullSpreadStandardExchangeVault_HookOrbital.t.sol
UniswapV4FullSpreadStandardExchangeVault_HookWeighted.t.sol
UniswapV4FullSpreadStandardExchangeVault_HookCurveQuad.t.sol
UniswapV4FullSpreadStandardExchangeVault_HookBalancerStable.t.sol
```

Reusable integration helpers may live under the family's `test/bases/`, behavior assertions under `test/behaviors/`, and actual public-route invariant handlers under `test/handlers/`. Do not add a separate production strategy framework or tests that pin PRD prose. [PTB; HTB; SK-T; P S1-TEST-01. Acceptance: FS-A01/32/41/42.]

### FS-26 - Preserve all inherited acceptance obligations

The following is the explicit inherited acceptance ledger. Each `S1-Axx` remains a separately traceable row; listed changes apply only to FullSpread tests, not edits to PairToken's requirements or expectations.

| Inherited ID | FullSpread disposition / primary spec |
|---|---|
| S1-A01 | Registry discovery of real new-family diamond; Package. |
| S1-A02 | Identity includes FS-07 domain and all bindings; Package. |
| S1-A03 | Invalid and valid pool/native/rate/zap cases retained; Package. |
| S1-A04 | Context/reinitialization/component failures retained; Package. |
| S1-A05 | Metadata/permit/domain retained; Surface. |
| S1-A06 | Manifest becomes 61 package selectors, separate factory union; Surface. |
| S1-A07 | Ordered discovery and booked-versus-principal retained; Surface. |
| S1-A08 | Full no-sink genesis output retained; Money. |
| S1-A09 | Genesis zero/overflow/minimum/fundable-liquidity failures retained; Money. |
| S1-A10 | Paired limiting ratio and final cap retained; Accounting. |
| S1-A11 | One-sided reserve branches and invalid empty positive-supply state retained; Accounting. |
| S1-A12 | Incumbent pre-entry maintenance and input isolation retained; Accounting. |
| S1-A13 | Both corrected zap directions retained; selected partial swap now rejects under FS-12; Money. |
| S1-A14 | Bootstrap/size/tick/zero boundaries retained; Money. |
| S1-A15 | Exact independent per-leg non-dilution proof retained; partial-fill success case becomes rejection, residual/add-rounding cases remain; Accounting. |
| S1-A16 | Full proportional redemption without retention retained; Money. |
| S1-A17 | Partial withdrawal dust/fee attribution retained; Accounting. |
| S1-A18 | Both one-token exit directions/minima retained; Money. |
| S1-A19 | Partial sale atomic failure and paired fallback retained; Money/Compound. |
| S1-A20 | Last-share paired reset/restart retained; Money. |
| S1-A21 | Terminal conversion with/without external liquidity retained; Money. |
| S1-A22 | Fee-retaining supply-neutral compound retained; Compound. |
| S1-A23 | Raw DUST/tie/quarter-cap/zero-liquidity branches retained; Compound. |
| S1-A24 | All checkpoint and partial-fee ownership cases retained; Accounting. |
| S1-A25 | Four canonical routes and unsupported directions retained in both admitted contexts; Money/Callbacks. |
| S1-A26 | Both exact-output selectors reject before effects; Surface/Money. |
| S1-A27 | Exact unchanged-state preview parity retained, also borrowed context; Previews. |
| S1-A28 | 64/65, 12/13, 16/17, shared counters and two-candidate cases retained; Previews/Gas. |
| S1-A29 | All 16 SY methods and same-share identity retained; Surface. |
| S1-A30 | SY internal-share/native/token validation retained; Money/Native. |
| S1-A31 | Empty rewards and no double claim retained; Surface/Compound. |
| S1-A32 | Raw SY units and independent rational 6/8/18-decimal valuation retained; Rate. |
| S1-A33 | Zero SY rate at empty supply retained; new getRate separately rejects; Rate. |
| S1-A34 | Exact observed false-flag receipt retained; Accounting. |
| S1-A35 | EOA/construction-time true flag rejection retained in ordinary context; borrowed true flag is explicitly rejected; Callbacks. |
| S1-A36 | Booked-inventory free-mint and short-credit negatives retained; Accounting. |
| S1-A37 | Exact declared pretransfer/no refund/unbooked excess retained in ordinary context; Accounting. |
| S1-A38 | Same-call donation and unsolicited isolation retained; Accounting. |
| S1-A39 | Authentic callback/forgery/replay/cross-facet cases retained; Callbacks. |
| S1-A40 | Deliberately replaced by FS-18/19: admitted caller-funded exchangeIn succeeds; other contexts reject before nested unlock; Callbacks. |
| S1-A41 | Manager/token/book/supply/event reconciliation retained; Accounting/Invariants. |
| S1-A42 | Disable stops inflow/donation, preserves compound/exit retained, including buffered routes; Money/Hook suites. |
| S1-A43 | Transfer/payout/minimum rollback retained; Callbacks. |
| S1-A44 | Decimal domain and forbidden-token behavior retained; Accounting/Native. |
| S1-A45 | Interior/boundary/outside principal, capacity and signed limits retained; Accounting/Previews. |
| S1-A46 | Public-route sequence ownership invariants retained, external trading effects separately reported; Invariants. |
| S1-A47 | Instance state/approval/position isolation retained; Package/Invariants. |
| S1-A48 | Normal size limits, viaIR=false, fresh artifacts, unchanged campaign strength retained; Package/Gas. |
| S1-A49 | Native paired value reservation/refund failures retained; Native. |
| S1-A50 | Native/wrapped delivery economic parity retained; Native. |
| S1-A51 | Real proxy native callback/settlement retained; Native. |
| S1-A52 | Forced ETH and temporary wrapper duplicate-credit negatives retained; Native. |
| S1-A53 | Rejecting/reentrant/legitimate native receivers retained; Native/Callbacks. |
| S1-A54 | Native terminal reset/rebootstrap retained; Native. |
| S1-A55 | Native/wrapped donation and invalid value/native route cases retained; Native. |
| S1-A56 | Exactly five common facets/20 selectors and no duplicate/factory inputs retained; Surface. |
| S1-A57 | Factory introspection and actual permit nonce/replay/domain retained; Surface. |
| S1-A58 | Wrapped face reverse-sort contents-hash test retained; Package. |
| S1-A59 | In-flight economic/shared/token read policy retained; getRate joins economic reads; Callbacks/Rate. |
| S1-A60 | Outstanding ERC-20 sync before native debt and zero own deltas retained; borrowed outer deltas remain separate; Native/Callbacks. |
| S1-A61 | Exact reachable fallback reasons or explicit reachability proof retained; Compound. |
| S1-A62 | No catch-and-fallback for actual failures retained; Callbacks/Compound. |
| S1-A63 | Minima/final-sale availability do not invent fallback; mode disambiguation retained; Previews. |
| S1-A64 | G/paired J/zap uncredited J/incumbent fee separation retained; Accounting. |
| S1-A65 | Custody categories and terminal-generated receipt allocation retained; Accounting/Invariants. |
| S1-A66 | Empty compound, zero-payout reject, one-sided positive exit, tiny genesis retained; Money. |
| S1-A67 | Protocol fees/tick/bitmap/fee checkpoints and changed-state rejection retained; Previews/Callbacks. |
| S1-A68 | No owner/cut/rescue/ERC4626; explicit getRate/context delta replaces excluded-integration assumption; Surface. |
| S1-A69 | Zero fee declarations, DUST, explicit zap arguments/cached decimals retained; Package/Compound. |
| S1-A70 | 12M transaction/11.9M local body and 5M local preview ceilings retained; composed routes get separate whole-transaction evidence; Gas. |

### FS-27 - Additional acceptance matrix

All success rows require exact independent balances, minted/burned supply, position key/liquidity, booked/reserved custody, returned amounts, event fields and relevant manager deltas. All failure rows require exact errors and complete state comparison at the actual reverted-call boundary. Do not use the production quote as the only arithmetic oracle.

| ID | Required setup/action and exact evidence | Requirements |
|---|---|---|
| FS-A01 | Deploy two real sibling packages/instances through registry and discover each by faces/types; prove no PairToken/Wings registry or position mutation. | FS-01/03/07/09/25 |
| FS-A02 | Interface/target-derived control manifest lists all 61 package selectors. Declaration tests plus proxy loupe and smoke calls prove each is installed exactly once. Reverting Out selectors count as installed only with their specified error. | FS-04/20 |
| FS-A03 | Final proxy is package/factory disjoint union; factory temporary hook lifecycle is correct; no factory inputs, combined permit facet, `linkedComponents`, owner/cut/rescue/ERC4626 or fake transition capability. | FS-03/04/05/06/24 |
| FS-A04 | Vary each facet, infrastructure/link and each argument in identity tests; invalid/mismatched components, direct initialization, wrong context, noncanonical args and reinitialization fail. | FS-07/08 |
| FS-A05 | Permit signed for one diamond fails on another; valid signature increments only that account's nonce; replay fails; EIP-712 chain/verifying contract are correct. | FS-04/08 |
| FS-A06 | Shared local reserves exclude principal, unbooked transfers and reservations; native wrapper sorting changes contents hash order, not discovery order. | FS-08/10/16 |
| FS-A07 | Six component links equal facet compiler links; library state remains diamond-local; `getRate` adds only one selector to QueryFacet, and its interface is truthful. | FS-04/06/07/21 |
| FS-A08 | Full SY proxy surface and reward events/arrays are exercised, including raw ETH and wrapped faces without another share token. | FS-04/15/22 |
| FS-A09 | Both Out methods reject with exact `ExchangeOutNotAvailable` before transfer/approval expenditure/mint/burn/manager work, even while unlocked. | FS-03/15/20 |
| FS-A10 | Real manager observes the diamond as caller/owner and zero salt for all changes; unrelated router/hook positions and another diamond's storage are unchanged. | FS-01/06/19 |
| FS-A11 | Genesis, tiny positive genesis, positive-supply paired ratios, ceiling accepted amounts, final q cap, one-sided state and native refund exactly match independent equations. | FS-10/11 |
| FS-A12 | At frozen P*, independently prove `q*R_i <= S*C_i` for each positive reserve; distinguish actual cost, removable growth, paired J, zap J and incumbent fees. | FS-10/11/12/22 |
| FS-A13 | Both zap directions use selected half input, all selected input consumed, caller-only addition; both fees and uncredited J exactly reconciled. No second-token payout or remaining caller reservation. | FS-12 |
| FS-A14 | Real limited-liquidity/price-bound entry and exit swaps require incomplete conversion; exact failure occurs before accepted partial success; whole invocation state is restored. | FS-12/13/20 |
| FS-A15 | Partial paired/single exits include only proportional principal/idle after checkpoint; final sale cannot spend remaining-holder backing; fees after burn remain with remaining liquidity. | FS-10/13/14 |
| FS-A16 | Last-share pair exits and rebootstrap retain no old booked claims; single exit succeeds only with actual post-removal market depth; unbooked old balances are excluded. | FS-10/13 |
| FS-A17 | Native and wrapped routes start from equivalent state and match economic amounts; wrong value, wrapper mismatch, reverse-sorted faces and native sync after ERC-20 sync are covered. | FS-08/11/15 |
| FS-A18 | Rejecting/reentrant token/native receivers and failed wrapper delivery roll back compound, pulls, burns and payouts; legitimate contract receiver works without fixed stipend. | FS-13/15/16 |
| FS-A19 | Contract pretransfer without receipt, booked-inventory theft, short receipt, excess credit, direct donation and forced ETH sequences preserve the categorical ledger. | FS-10/12/14/16 |
| FS-A20 | Every valid SE/SY/paired preview equals execution exactly from restored identical state; full tick/fee/bitmap and later-read witness mutations fail closed. | FS-06/17/22 |
| FS-A21 | Each candidate budget boundary/error, guard precedence, fallback predicate and fresh overlay is exercised; no execution exception is reclassified as fallback. | FS-14/17 |
| FS-A22 | SY raw rate and normalized executable rate are independently checked for 6/8/18-decimal assets. Equal numerical results in a special fixture are allowed; never require a difference simply to distinguish semantics. | FS-21/22 |
| FS-A23 | Idle unlocked getRate/preview succeeds where executable; busy-vault reentrant rate/preview fails; basic snapshots and canonical token views retain their specified behavior. | FS-16/21 |
| FS-A24 | `S=0`, `0<S<1e18`, `S=1e18`, insufficient post-removal sale depth, zero normalized proceeds, overflow and budget failures follow FS-21 exactly. No smaller-share extrapolation. | FS-21 |
| FS-A25 | Compare getRate with an independent one-whole-share actual exit from identical state. Also measure E(q) for larger/smaller q without assuming linearity or monotonic target value. | FS-21/22 |
| FS-A26 | A provider bound to FullSpread rateAsset is accepted by real buffered hooks; missing provider fails their current error. Failed/zero/reverting provider fails closed; no replacement with SY. | FS-21/22/23 |
| FS-A27 | A real external router opens the common manager; funded contract calls standard entry. Trace proves zero nested unlocks, no forged public callback, actual V-owned manager position and zero V deltas on return, while outer unlock remains open. | FS-18/19/20 |
| FS-A28 | Wrong manager callback, unsolicited/replayed payload, nested cross-facet operation, already-active operation and borrowed callback impersonation all fail with specified errors. | FS-16/18/19 |
| FS-A29 | Borrowed deposit and borrowed withdrawal produce the same maintenance mode/economics as ordinary entry from the same pool/book state. No sleeve or forced collection-only shortcut. | FS-14/17/18 |
| FS-A30 | Unlocked contract with no input allowance/balance, false receipt, wrong recipient, true pretransfer flag, or unsupported route cannot consume backing. Properly funded non-hook contract satisfying FS-18 is explicitly allowed. | FS-12/16/17/18 |
| FS-A31 | Borrowed full last-share sale failure restores shares/position/book and outer snapshot as appropriate; paired ordinary exit remains independently executable where specified. | FS-13/19 |
| FS-A32 | Deploy/finalize all seven real hook packages with their actual current argument schemas and normal address flags. Obtain usable routes, not only constructor success. | FS-09/23/25 |
| FS-A33 | Dual identity configuration uses `token0=SE0=V`, `token1=SE1=W` for distinct real vault shares; one real V4 swap trades V to W, then reverse. Shares move, neither underlying position/supply changes; all outer deltas close. | FS-19/23 |
| FS-A34 | Dual buffered configuration binds distinct underlying faces to V and W and providers. One same-manager V4 swap actually deposits into one vault and redeems the other; reverse direction reverses those roles. Verify both vaults' position owners, fees, actual minted/burned shares, no nested unlock, and final outer closure. | FS-10/13/18/19/23 |
| FS-A35 | Before and after each inner call, snapshot V, W, hook and router deltas separately; V's zero-delta return must not erase hook/router debts. A caught rejected inner call leaves outer state only as real EVM rollback allows. | FS-16/19/23 |
| FS-A36 | Real nonreserve single hook quotes and executes wrap/unwrap while unlocked. Dual/weighted/multi-leg quote versus execution is checked from equal disjoint-pool state, including current per-leg rate reads and changed-state rejection. No ordinary locked-context quote is passed off as projected state. | FS-17/21/23/24 |
| FS-A37 | Single CP binds FullSpread buffered leg plus another SE share as raw asset; each multi-leg hook binds FullSpread and another SE. Both direction and leg-order variants deliver exactly requested denomination and no stranded FullSpread allocation. | FS-12/13/23 |
| FS-A38 | Repeat borrowed buffered cases for native-backed FullSpread using wrapped-native faces, mixed decimals, nonzero LP/protocol fees, maintenance fallback, and disabled inbound versus still-open exit. | FS-14/15/16/23 |
| FS-A39 | Adversarial real backing-pool trades before/after consuming-hook swaps record rate movement, actual conversion, hook reserve changes and user profit/loss separately from ownership invariants. No off-pool feed/peg assumption and no passing "manipulation-proof" assertion. | FS-21/22/23 |
| FS-A40 | Existing hook exact-output path touching FullSpread propagates unavailable conversion atomically; direct identity-share paths are classified separately. No prepayment remains in a reverted outer swap. | FS-15/19/23 |
| FS-A41 | Measure complete ordinary and composed transactions with cold relevant accounts/storage, plus view calls. Include both vault operations, hook work, rates, crossings, native wrapper and fallback costs; an inner call below 12M is not enough. | FS-17/25/28 |
| FS-A42 | Every inherited/new row maps to a concrete test/static evidence or an explicit unresolved gate; report shared-backing-pool sequential topology and optional transition-dependent routes separately. No mock pass, skipped required integration, unrun green claim or safety/audit assertion. | FS-24/25/26/27/28 |

### FS-28 - Release verification and bounded claims

Future implementation SHALL run diagnostics, current artifact-first builds, focused family and seven-hook integration suites, then repository-required hermetic verification. Retain `viaIR=false`, normal runtime/initcode limits, default/fork profile law, existing fuzz/invariant strength and the warm-artifact workflow. No tests/builds were run for this original.

Use P's 12,000,000-gas engineering transaction ceiling, 11,900,000 measured call-body allowance with 100,000 overhead for its fixed standalone methods, and 5,000,000 local preview ceiling. For composed hook/router calldata, account for its actual overhead rather than blindly reusing the standalone 100,000 allowance. The **whole composed transaction** must fit 12M. If two individually admissible vault plans exceed that total, do not claim compositional gas admission; document and narrow the concrete supported integration envelope explicitly before release. Do not silently change the 64/12/16 per-vault economics domain or raise chain limits.

Fork verification, if separately chosen, is local-only and does not replace real hermetic common-manager proof. Static source reads, a successful deployment, and matching interface IDs are insufficient evidence of usable rate economics or atomic cross-vault settlement. [P S1-GAS-01, S1-TEST-01, completion criteria; L; .github/ASSISTANT_TESTS.md. Acceptance: FS-A41/42.]

## 8. Inherited IDs, new `FS-` IDs, and owner decisions still open

### Confirmed owner decisions inherited by exact ID

| ID | Disposition |
|---|---|
| S1-D01 | PRD first; this task does not authorize implementation. |
| S1-D02 | Full-range strategy, not wings. |
| S1-D03 | Ownership logic only; no dead shares, redemption retention or vault/protocol fees. |
| S1-D04 | Diamond Package and standard SE conventions. |
| S1-D05 | One present public share layer; no prebuilt second reserve-share layer. |
| S1-P01 | Collect/ratio-swap/reinvest and permissionless compound, subject to confirmed withdrawal fallback. |
| S1-P02 | Native ETH retained, not replaced by wrapper-only support. |
| S1-P03 | Installed but reverting exact output. |
| S1-P04 | Correct complete reserve and fee attribution. |
| S1-P05 | Conditional, not unconditional, collection-only withdrawal fallback. |
| S1-P06 | SY spot accounting separate from issuance and liquidation. |
| S1-P07 | Conservative deterministic candidate budgets and engineering gas ceilings. |

### Complete inherited requirement register

| IDs | Disposition in this contribution |
|---|---|
| S1-X01, S1-X02, S1-X03, S1-X04, S1-X05, S1-X06, S1-X07, S1-X08, S1-X09, S1-X10, S1-X11, S1-X12, S1-X13, S1-X14, S1-X15, S1-X16, S1-X17, S1-X18, S1-X19 | All preserved as baseline-to-family departures; FS-18/19 additionally extend context, and FS-12 narrows partial entry fills. No Weir equation replaces them. |
| S1-ARCH-01 | New sibling prefix/path under FS-01/06; same architectural discipline. |
| S1-ARCH-02 | Same 18-decimal share, position, immutable/unowned identity. |
| S1-ARCH-03 | Same configuration/domain, current PI explicit fields and links. |
| S1-ARCH-04 | All five shared facets and factory exclusions retained. |
| S1-ARCH-05 | Shared proxy initialization retained. |
| S1-ACC-01, S1-ACC-02, S1-ACC-03, S1-ACC-04, S1-ACC-05, S1-ACC-06, S1-ACC-07 | All accounting equations/checkpoints/ownership categories retained. |
| S1-OP-01 | Paired maximum-input deposit retained. |
| S1-OP-02 | Half-swap/credit economics retained; selected entry partial fill explicitly becomes failure. |
| S1-OP-03 | Paired share-input exit retained. |
| S1-OP-04 | Strict complete unwanted-allocation sale retained. |
| S1-OP-05 | Compound unchanged economically; manager-context rejection qualifies only for FS-18 standard exact-input execution. |
| S1-EXIT-01 | Exact four fallback predicates retained. |
| S1-NATIVE-01 | All native/wrapped custody and settlement rules retained. |
| S1-API-01 | Shared/SE/SY/callback surfaces retained, plus actual rate provider capability. |
| S1-API-02 | Four directional exact-input routes retained. |
| S1-API-03 | All 16 SY methods retained. |
| S1-API-04 | No ERC4626 or fake transition capability; provider exclusion deliberately superseded by FS-21, limited hook integration by FS-23. |
| S1-API-05 | 19 family methods and enum/event meanings retained; rate selector added. |
| S1-QUOTE-01 | Exact candidate planning retained, usable at an idle borrowed-unlock boundary. |
| S1-GAS-01 | Standalone ceiling retained and complete composed envelope explicitly measured. |
| S1-QUOTE-02 | Raw SY accounting formula unchanged. |
| S1-PKG-01 | Registry lifecycle retained with new product identity. |
| S1-SEC-01 | Guard/read/callback rules retained; blanket unlocked rejection narrowed only by FS-18/19. |
| S1-SEC-02 | Disable, token boundaries, deadlines and recipient constraints retained. |
| S1-OBS-01 | Canonical semantic events/errors retained with explicit new context/conversion/rate errors. |
| S1-TEST-01 | Real production-first tests and separate comparison ledger retained. |
| S1-A01 through S1-A70 | Each individually mapped in FS-26; none silently deleted. |

### New requirement inventory

`FS-01` custody/identity; `FS-02` inheritance/deltas; `FS-03` exclusions; `FS-04` explicit facet composition; `FS-05` factory exclusions; `FS-06` files/data/engine split; `FS-07` package inputs/identity; `FS-08` validation/init; `FS-09` registry delivery; `FS-10` ownership model; `FS-11` paired issuance; `FS-12` complete selected entry conversion; `FS-13` exit/full payout; `FS-14` maintenance/donation/fallback; `FS-15` native/SY/exact-output; `FS-16` trust/disable/reads; `FS-17` bounded plans; `FS-18` self-funded unlocked entry; `FS-19` dual-context actions/settlement; `FS-20` events/errors; `FS-21` executable normalized rate; `FS-22` numerical separation; `FS-23` existing-hook scope; `FS-24` separate integration-change gate; `FS-25` fixtures/files; `FS-26` inherited acceptance ledger; `FS-27` new acceptance rows; `FS-28` release verification. Acceptance IDs are `FS-A01` through `FS-A42`.

### Choices requiring explicit coordinator disposition, not invented owner approval

1. **Unlocked authorization policy.** I propose the self-funded, recipient-is-caller, false-pretransfer standard branch in FS-18. It is fully specified and avoids hook modifications. It intentionally authorizes any contract satisfying that funding contract, not just a registered hook. The owner did not explicitly choose hook-exclusive ACLs. If exclusivity is required, the PRD must specify actual registry/type/context evidence and compatibility with existing callers; no imaginary active-locker getter or bare unlocked check is sufficient.
2. **Entry remainder interpretation.** FS-12 requires full selected half-swap consumption and retains inherited disclosed `J_i` booking. It forbids stranded or second-token payout, but does not promise full NAV credit for every input unit. If "consume the selected leg completely" means zero uncredited entry remainder rather than complete selected conversion and complete accounting, that conflicts with the inherited zap-credit policy and must be resolved explicitly. Do not silently replace `C_i=G_i` with `C_i=G_i+J_i`.
3. **Rate-consumer economic policy.** The requested executable one-share rate is retained and concretely specified. I do not propose NAV substitution, queues, another price source, or a new redemption restriction. Using that live rate in an existing hook's rated invariant is mechanically testable but not proved manipulation-safe. Any observation/guard/exposure policy beyond existing hooks is a separately named economic decision, not a hidden implementation TODO.
4. **Broader composition.** This contribution supplies a complete required route for passive share trading and disjoint-backed exact-input buffering in the current hooks. Same-backing-PoolId cross-vault sequential paths and optional transition-dependent hook LP routes need their own explicit coverage/requirements if the coordinator includes them. Do not label them impossible, silently ship a fake projector, or count them as proven by different-pool tests.

These are design dispositions for the coordinator's authorized synthesis/advisory process. They do not reopen the locked one-pool, one-position, one-share, native, zero-vault-fee, exact-output-unsupported, complete-exit, or executable-rate goals, and they do not authorize implementation.

## 9. Limits and sources

### Local source register

Paths are repository-relative. All evidence is working-tree source/document inspection, not an atomic repository snapshot or a runtime proof.

| Label | Source and locators read |
|---|---|
| B | `docs/research/fullspread-se-prd-20261030-01a18660/brief.md`, complete. |
| PI | `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol`, complete; current facet/linked-library fields explicitly re-read before composition. |
| PV | Same family `interfaces/IUniswapV4PairTokenStandardExchangeVault.sol`, complete. |
| PD | Same family `UniswapV4PairTokenStandardExchangeVaultDFPkg.sol`, complete; constructor, validation, lifecycle, selector manifest. |
| P | `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`, complete current bounded-execution amendment, including sections 1-3 and all facet/package/rate/acceptance sections. |
| W | `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol`, complete; package-shape comparison only. |
| PE | PairToken `UniswapV4PairTokenStandardExchangeVaultExecution.sol`, targeted reads of public/internal entry, `prepare`, `_start`, `_reserveInitial`, `_action`, `_managerAction`, `_account`, `_record`, `_settle`; not a complete execution-code audit. |
| PT / PR / PC | PairToken `UniswapV4PairTokenStandardExchangeVaultTypes.sol`, `...Repo.sol`, `...ComponentBindings.sol`, complete. |
| PTB | PairToken `test/bases/TestBase_UniswapV4PairTokenStandardExchangeVault.sol`, complete. |
| SI / SO | `lib/crane/contracts/interfaces/IStandardExchangeIn.sol`, `IStandardExchangeOut.sol`, complete. The seven-argument actual ABI overrides the stale six-argument illustrative command in the user-flow topic. |
| SP / RD | `contracts/interfaces/IStandardVaultPkg.sol`, `contracts/interfaces/IVaultRegistryDeployment.sol`, complete. |
| PM | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol`, complete. |
| TQ | `contracts/interfaces/IStandardExchangeTransitionQuote.sol`, complete, including ExternalQuote and RateQuote definitions. |
| H1 | `contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookTarget.sol`, complete. |
| H2 | Same directory `UniswapV4SingleStandardExchangeBufferHookCommon.sol`, complete. |
| H3 | `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol`, targeted buffer/unwrap, take/settle, exact-input/output plan, execution, deposit and withdrawal reads, including `_executePlannedSwap`. |
| H4 | Same dual directory `UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol`, complete. |
| H5 | Same dual directory `...HookInQuoteBase.sol`, `...HookInExecutionBase.sol`, complete; `...HookSeTarget.sol` relevant exact-input/output portion; `...HookHooksTarget.sol` relevant beforeSwap/discovery portion. |
| HC | Same dual directory `...HookClaimLib.sol`, rate/transition/context reads through `projectedBufferClaimIn`; single-CP `...HookClaimLib.sol` transition capability probe; weighted `...HookHooksTarget.sol` targeted quote/output execution. |
| HP1 | `standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferHookPackage.sol`, complete. |
| HP2 | `standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol`, complete. |
| HP3 | `standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.sol`, complete. |
| HP4 | `standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol`, complete. |
| HP5 | `standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol`, complete. |
| HP6 | `standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol`, complete. |
| HP7 | `standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.sol`, complete. |
| HTB | `standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol`, setup and package/manager/factory initialization portion. |
| HD | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol`, complete discovery and route interface. |
| L | `CLAUDE.md`, `docs/agent/INDEXEDEX_AGENT_LAW.md`, `.github/ASSISTANT_CODING.md`, `.github/ASSISTANT_TESTS.md`; required router/law/coding/testing text read. |
| SK-A | `.agents/skills/crane-architecture/SKILL.md`, resolved Crane architecture content. |
| SK-T | `.agents/skills/indexedex-testing/SKILL.md`, complete. |
| SK-H | `.agents/skills/indexedex-uniswap-v4-hook-packages/SKILL.md`, complete. Current source and router override its older monomorph/profile examples. |
| SK-U | `.agents/skills/indexedex-user-flows/SKILL.md` and its Standard Exchange topic `.opencode/skills/indexedex-standard-exchange/SKILL.md`. |
| R1 | `docs/research/v4-single-token-vaults-20261029-01a18660/REPORT.md`, complete admitted background report, not new independent external verification. |
| R2 | `docs/research/v4-vault-adaptation-20261029-01a18660/REPORT.md`, complete admitted background report; prior alternatives are not current owner decisions. |
| WI | `contracts/protocols/strategy/weir/WEIR_VAULT_SOURCE_IMPORT_PRD.md`, complete admitted background PRD; none of its import/fidelity economics is adopted here. |

The hook inventory and empty `fullSpread/` directory were inspected by bounded file discovery. References abbreviated `standardExchange/...` in this table are under `contracts/hooks/uniswap/v4/`.

### Evidence limits

- No peer original, peer feedback, current council draft, or resolution was read. The explicitly admitted prior final reports were read as background only.
- No public source was fetched, and no private source was sent to a public search/documentation service. Prior reports' external deployment, license and maturity claims were not reverified and are not FullSpread acceptance evidence.
- No code/configuration implementation, test execution, build, installation, Git operation, deployment, wallet operation, or sub-agent launch occurred.
- Hook-family package interfaces were all read; this was not an exhaustive audit of every hook implementation or its transitive library body. Claims about actual dispatch are limited to the cited inspected functions. All seven integration suites remain required future evidence.
- The selected original is executable requirements text with explicit coordinator choices, not proof that every admitted worst-case composed route fits the gas ceiling or that the consuming invariant is economically safe.
- Only the owned original-response file is authored. No PairToken, Wings, Weir, hook, registry, source, test, configuration, or final publication document is changed.

Stop after this original contribution.
