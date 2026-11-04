# Astra planning contribution: coordinator archival receipt

Verbatim final response from Native task `st_01a18421`, initial planning assignment. No content corrections were applied in this archive.

---

# Identity

**Astra — independent Native council planning contribution**

- Run: `pairtoken-se-stage-one-plan-20261028-01a1810f`.
- Native metadata reports provider `chatgpt-subscription` and model `gpt-6-astra`.
- Requested route: `chatgpt-subscription/gpt-6-astra:high`. The effort setting was not independently exposed in the inspected Native metadata.
- Assignment: implementation and testing planning against the revised requirements, not implementation or advisory review.

No files were written. No project commands, tests, builds, Git operations, deployments, external research, peer/prior-council reads, memory reads, or subagent delegation were performed.

# Inputs and coverage

## Authoritative input

I read the complete common brief and all 1,213 lines of the immutable `inputs/PRD.md` in this run.

The supplied admission hash is:

`574ce6c03c0bc62f79a816e5a7775c831cb932082e0dd4bfe414fc1945ed7a7f`

This identifies the coordinator’s admitted snapshot; I did not independently hash it.

This contribution preserves the revised requirements:

- One public 18-decimal share supply and one diamond-owned full-range position.
- No dead shares, retention, protocol-fee routing, or second reserve token.
- Caller-only entry funding and the exact S1-ACC-07 attribution equations.
- Full baseline compounding with explicit fee checkpoints.
- Withdrawal-only, preflight-selected conditional fallback.
- Native ETH and wrapped-native faces.
- Unsupported exact output.
- Exact economic projection with 512 swap iterations per candidate and at most two withdrawal candidates.
- Spot-accounting SY valuation with one floor per currency conversion and canonical raw-unit scaling.
- Five unchanged reusable facets, excluding factory-provided facets from package composition.
- Every acceptance obligation S1-A01–S1-A70.

## Admitted implementation evidence

I inspected the relevant repository rules and canonical architecture, deployment, and testing guidance; the standalone PairToken implementation, math, dependency interfaces, and complete characterization harness; the five reusable facets and relevant Repos; shared SE/SY interfaces and implementation seams; `LocalCreditLib`; registry registration and disable paths; artifact loading; the current Wings package, component factory, real-manager TestBase, and representative deployment/surface/size tests; and the canonical V4 manager, state, position, bitmap, liquidity, swap, protocol-fee, and settlement interfaces.

Important implementation consequences from those sources:

1. **Actual package lifecycle uses delegatecall.**  
   `DiamondFactoryPackageAdaptor._calcSalt` and `_processArgs` execute in the diamond factory’s context. Package storage must not be read as though `address(this)` were always the package. Immutable bindings and explicit calls to the immutable package address solve this.

2. **Native receipt already works at the proxy.**  
   `lib/crane/contracts/proxies/Proxy.sol` has an empty payable `receive()`. There is no receive selector to install. Attribution belongs in the active family engine.

3. **The shared SY execution seams are useful, but its preview wrapper is not directly sufficient.**  
   `NativeStandardYieldMoneyTarget` provides virtual `deposit`, `_standardRoute`, and `_redeemVaultHeld` seams. However, `NativeStandardYieldPreviewCallsTarget.previewDeposit/previewRedeem` are nonvirtual and return zero for invalid tokens before entering the quote engine. Family preview wrappers must put the operation-read guard first without modifying shared discovery behavior.

4. **Registry zero-fee declarations appear structurally supported.**  
   Package and vault registration decode zero fee-type IDs; the inspected `Bytes4SetRepo._add` does not reject zero. This supports proceeding without inventing a fee declaration, but A69 still requires a real deployment test.

5. **The generic package Behavior named in guidance was not found.**  
   `Behavior_IFacet.sol` exists. The referenced `Behavior_IDiamondFactoryPackage.sol` was absent from the inspected Crane tree. The plan therefore includes a small family-local package Behavior rather than assuming that import exists.

6. **Foundry’s configured gas limit is not a deployment feasibility result.**  
   `foundry.toml` currently specifies solc `0.8.35`, optimizer runs `1`, `via_ir = false`, fuzz runs `16`, invariant runs `16`, invariant depth `8`, and gas limit `30,000,000,000`. The last value provides test headroom; it cannot establish A70.

Source locators below use PRD IDs and local file/function names. Proposed files are explicitly labeled proposed.

# File/component map

## Proposed production layout

Let:

- **P** = `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/`
- **F** = `UniswapV4PairTokenStandardExchangeVault`

Every file in this table is **proposed**, not an existing implementation.

| Proposed file under P | Responsibility |
|---|---|
| `interfaces/IF.sol`, expanded as `interfaces/IUniswapV4PairTokenStandardExchangeVault.sol` | The 19 specified family functions, withdrawal enums, required family errors, and family events. |
| `interfaces/IFDFPkg.sol`, expanded with the same prefix | `PkgInit`, `PkgArgs`, typed deployment helper, package binding query, and package validation errors. Inherits the actual canonical package interfaces. |
| `FRepo.sol` | ERC1967-form family namespace; initialization flag, immutable instance configuration, committed booked balances, operation guard, callback commitment, and temporary reservations. No duplicate ERC-20 supply or balances. |
| `FMath.sol` | Clamped principal/cost calculations, share-credit calculations, baseline compound sizing, safe amount/liquidity classification, and exact multiword SY valuation. |
| `FProjection.sol` | Read-only loading, bounded memory overlays, canonical V4 swap/position transitions, and economic-state witnesses. |
| `FPlanner.sol` | Complete operation plans, fee-checkpoint sequencing, entry/exit arithmetic, and typed withdrawal fallback selection. |
| `FExecution.sol` | Internal execution engine: consume a selected plan, call the manager, validate deltas/state, update categorized custody, mint/burn, settle, and publish reserves. |
| `FMoneyTarget.sol`, `FMoneyFacet.sol` | `exchangeIn`, paired execution, donation, and compound entrypoints. |
| `FQuoteTarget.sol`, `FQuoteFacet.sol` | Standard exact-input preview and the four specified family previews. |
| `FOutTarget.sol`, `FOutFacet.sol` | Both canonical exact-output functions, always explicitly unsupported. |
| `FQueryTarget.sol`, `FQueryFacet.sol` | Eleven family configuration/economic queries, applying the required read policy. |
| `FSYMoneyTarget.sol`, `FSYMoneyFacet.sol` | SY deposit/redeem and the two state-changing empty-reward methods. Reuse shared execution/reward seams where compatible. |
| `FSYQueryTarget.sol`, `FSYQueryFacet.sol` | Twelve SY read methods, including guarded family preview wrappers and accounting rate. Reuse shared discovery/empty-reward semantics. |
| `FCallbackTarget.sol`, `FCallbackFacet.sol` | Only authenticated `unlockCallback(bytes)`. |
| `FDFPkg.sol` | Package composition, binding identity, argument processing, proxy initialization, and immutable lifecycle callbacks. |
| `FComponent_FactoryService.sol` | Artifact-based CREATE3 component deployment and typed manager-registry package deployment. |

The abbreviated filenames above are expanded mechanically with F; they are not additional short-named contracts.

Use ordinary internal helpers initially for the execution engine. Heavy projection/math routines should have deliberate library boundaries so they can be externally linked if runtime measurements require it. Do not solve size pressure by adding proxy self-calls or installing internal execution selectors.

If execution code remains oversized after separating the seven family facets, the prescribed next split is a **fixed, package-bound payable execution delegate**, not an arbitrary call router. Its entrypoints are not cut onto the proxy; direct invocation is rejected; delegate execution preserves caller/value and requires the active family operation. Include its address in package bindings and its runtime in A48/A70. This is a code-placement change, not a new product surface.

## Canonical reuse

Keep these five facets unchanged:

| Existing facet | Existing storage/implementation ownership |
|---|---|
| `lib/crane/contracts/tokens/ERC20/ERC20Facet.sol` | `ERC20Repo`; 9 selectors. |
| `lib/crane/contracts/tokens/ERC2612/ERC2612Facet.sol` | `ERC2612Repo`, `ERC20Repo`, `EIP712Repo`; 3 selectors. |
| `lib/crane/contracts/utils/cryptography/ERC5267/ERC5267Facet.sol` | `EIP712Repo`; 1 selector. |
| `contracts/vaults/basic/MultiAssetBasicVaultFacet.sol` | `MultiAssetBasicVaultRepo`; 3 selectors. |
| `contracts/vaults/standard/MultiAssetStandardVaultFacet.sol` | `StandardVaultRepo` and basic-vault token discovery; 4 selectors. |

Additional reuse:

- `contracts/utils/LocalCreditLib.sol`
- `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol`
- `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol`
- `contracts/vaults/standard/sy/NativeStandardYieldQuoteBase.sol`
- `contracts/vaults/standard/exchange/StandardExchangeInExecutionBase.sol`
- `contracts/utils/foundry/ArtifactCreationCode.sol`
- `contracts/interfaces/IVaultRegistryDisableQuery.sol`
- Crane V4 `IPoolManager`, `PoolKey`, `PoolIdLibrary`, `Currency`, `BalanceDelta`, `StateLibrary`, and `TransientStateLibrary`.
- Crane `TickMath`, `SqrtPriceMath`, `LiquidityAmounts`, `SwapMath`, `LiquidityMath`, `ProtocolFeeLibrary`, `FullMath`, and bitmap bit operations.

Do not inherit Wings’ vault, economic engine, target-token book, liquidation model, or local-sleeve behavior. Its admitted use here is package and test infrastructure.

## Initialization and identity

### Package bindings

`PkgInit` should bind:

- The five reusable facets and the family facets.
- Real PoolManager.
- Real registry.
- Canonical fee-oracle reference.
- Canonical wrapped-native contract.
- Canonical diamond callback factory, because initialization authentication uses it.
- Any actually deployed linked execution component.

Do not introduce Permit2 merely because Wings binds it. Stage one has no required Permit2 surface.

Validate component code and exact composition. Reject duplicate selectors, excluded factory selectors, the combined `ERC20PermitFacet`, and unexpected operational capabilities.

Use an immutable `bindingHash = keccak256(abi.encode(pkgInit))`. Instance salt should bind the canonical decoded `PkgArgs` and `bindingHash`; it must behave identically when called directly for prediction and through factory delegatecall.

Preserve the repository’s **name-based CREATE3 component/library salts**. Constructor arguments and bytecode are deployment payloads, not replacements for that salt policy. Reusing an occupied package/component identity must not be presented as deploying new bindings or updated code. Validate actual bindings/code before reuse.

Test binding sensitivity from a snapshot preceding package deployment, varying one binding at a time. That avoids pretending an occupied name-based CREATE3 deployment can be rebound.

### Instance initialization

In the authenticated proxy `initAccount` delegatecall:

1. Verify package/factory deployment context and reject repeat initialization.
2. Revalidate the decoded arguments.
3. Initialize family manager/key/pool ID, canonical usable ticks, zero salt, rate asset/decimals, zap parameters, registry, and wrapper binding.
4. Initialize `ERC20Repo` with configured name, symbol, and 18 decimals; supply remains zero.
5. Initialize `EIP712Repo` with the same name and version `"1"`. Leave canonical nonce storage initially zero.
6. Initialize `MultiAssetBasicVaultRepo` with `[C0,C1]` in PoolKey face order.
7. Initialize `StandardVaultRepo` with the actual fee oracle, `bytes32(0)` fee-type IDs, deduplicated package-owned types, and the hash of an independently sorted face copy.
8. Leave both booked local reserves zero.
9. Do not initialize or overwrite factory-owned introspection storage.

`processArgs` must authenticate the registry caller in the actual delegatecall context. `initAccount` should additionally verify that the bound callback factory records this proxy as belonging to this package with the expected arguments. Lifecycle callbacks must not create a post-deployment configuration path.

## Typed ABI and selector ownership

There are **60 package-owned product selectors**:

- 20 reused selectors.
- 19 family selectors.
- 4 SE selectors.
- 16 SY selectors.
- 1 callback selector.

Factory-owned persistent selectors are additional. Facet metadata functions and package lifecycle functions are not automatically product selectors.

### Reused selectors: 20

| Owner | Typed functions |
|---|---|
| ERC20Facet | `name() -> string`; `symbol() -> string`; `decimals() -> uint8`; `totalSupply() -> uint256`; `balanceOf(address) -> uint256`; `allowance(address,address) -> uint256`; `approve(address,uint256) -> bool`; `transfer(address,uint256) -> bool`; `transferFrom(address,address,uint256) -> bool`. |
| ERC2612Facet | `permit(address,address,uint256,uint256,uint8,bytes32,bytes32)`; `nonces(address) -> uint256`; `DOMAIN_SEPARATOR() -> bytes32`. |
| ERC5267Facet | `eip712Domain() -> (bytes1,string,string,uint256,address,bytes32,uint256[])`, using the canonical interface exactly. |
| MultiAssetBasicVaultFacet | `vaultTokens() -> address[]`; `reserveOfToken(address) -> uint256`; `reserves() -> uint256[]`. |
| MultiAssetStandardVaultFacet | `vaultFeeTypeIds() -> bytes32`; `contentsId() -> bytes32`; `vaultTypes() -> bytes4[]`; `vaultConfig() -> IStandardVault.VaultConfig`. |

### Family selectors: 19

```solidity
// MoneyFacet
depositPair(uint256,uint256,uint256,address,uint256)
    payable returns (uint256);
redeemPair(uint256,uint256,uint256,address,uint256)
    returns (uint256,uint256);
donate(address,uint256) payable;
compound() returns (uint256,uint256);

// QuoteFacet
previewDepositPair(uint256,uint256)
    view returns (uint256,uint256,uint256);
previewRedeemPair(uint256)
    view returns (uint256,uint256);
previewWithdrawalMode(uint256,bool,address)
    view returns (WithdrawalMode,MaintenanceReason);
previewZapCredit(address,uint256)
    view returns (uint256,uint256,uint256,uint256,uint256);

// QueryFacet
poolManager() view returns (IPoolManager);
poolKey() view returns (PoolKey memory);
wrappedNative() view returns (address);
rateAsset() view returns (address);
tickLower() view returns (int24);
tickUpper() view returns (int24);
positionLiquidity() view returns (uint128);
localReserves() view returns (uint256,uint256);
basket() view returns (uint256,uint256);
maxZapBps() view returns (uint16);
maxZapTickMove() view returns (int24);
```

Enums retain the specified order:

```solidity
WithdrawalMode {
    FullCompound,
    CollectOnly
}

MaintenanceReason {
    None,
    MaintenanceWorkLimit,
    MaintenancePriceLimit,
    MaintenanceLiquidityLimit,
    MaintenanceDeltaLimit
}
```

Preserve all eight explicitly required family errors:

```solidity
ReentrantOperation();
ManagerAlreadyUnlocked();
EconomicStateChanged();
InvalidAccountingState();
ZeroPayout();
QuoteWorkExceeded(uint256 steps, uint256 limit);
IssuanceDisabled();
```

The PRD lists seven signatures above; do not invent an eighth merely to satisfy a count. Additional configuration, callback-authentication, arithmetic-overflow, and incomplete-sale errors should be declared and recorded in the implementation comparison ledger.

### SE selectors: 4

```solidity
// QuoteFacet
previewExchangeIn(IERC20,uint256,IERC20)
    view returns (uint256);

// MoneyFacet
exchangeIn(IERC20,uint256,IERC20,uint256,address,bool,uint256)
    returns (uint256);

// OutFacet
previewExchangeOut(IERC20,IERC20,uint256)
    view returns (uint256);
exchangeOut(IERC20,uint256,IERC20,uint256,address,bool,uint256)
    returns (uint256);
```

Both Out functions revert `ExchangeOutNotAvailable()` without funding or mutation.

### SY selectors: 16

```solidity
// SYMoneyFacet
deposit(address,address,uint256,uint256)
    payable returns (uint256);
redeem(address,uint256,address,uint256,bool)
    returns (uint256);
rewardIndexesCurrent() returns (uint256[] memory);
claimRewards(address) returns (uint256[] memory);

// SYQueryFacet
previewDeposit(address,uint256) view returns (uint256);
previewRedeem(address,uint256) view returns (uint256);
getTokensIn() view returns (address[] memory);
getTokensOut() view returns (address[] memory);
yieldToken() view returns (address);
assetInfo() view returns (IStandardizedYield.AssetType,address,uint8);
exchangeRate() view returns (uint256);
isValidTokenIn(address) view returns (bool);
isValidTokenOut(address) view returns (bool);
getRewardTokens() view returns (address[] memory);
accruedRewards(address) view returns (uint256[] memory);
rewardIndexesStored() view returns (uint256[] memory);
```

### Callback selector: 1

```solidity
// CallbackFacet
unlockCallback(bytes calldata) returns (bytes memory);
```

### Manifest requirements

Build the manifest from actual typed interfaces and Target entrypoints, independently of `facetFuncs()`:

`signature -> selector -> owning facet -> interface IDs -> Repo/dependency -> initialization owner -> callback read policy -> test`

Preserve the canonical ERC-20 facet’s additional XOR interface declaration. Declare concrete In and Out IDs, not an empty inheritance-only aggregate ID. Advertise the complete family and SY capabilities only when their full composed selector sets are installed.

The package-owned aggregate must exclude factory-owned ERC-165, loupe, ERC-8109, and the temporary post-deployment hook. The final proxy must retain the persistent factory interfaces and lose the temporary hook through the factory’s own lifecycle.

# Implementation stages

## Dependency-ordered work packages

Each increment must be buildable and verified when implementation is authorized. Intermediate incomplete fixtures are development scaffolding, not a completed product.

| Work package | Prerequisites | Implementation actions | Observable exit evidence |
|---|---|---|---|
| **WP0 — Contract and verification boundaries** | Revised PRD | Freeze the typed ABI inventory, storage ownership, error precedence, comparison categories, deployment bindings, and target gas envelope. Establish proposed test names and selector verification script. | Complete 60-selector manifest specification; all 70 acceptance rows assigned; no unresolved economic substitution. Deployment gas limits either recorded or explicitly release-blocked. |
| **WP1 — Exact math and accounting model** | WP0 | Implement clamped principal/cost math, candidate/credit issuance, proportional allocations, safe casts, compound sizing, and exact rational valuation. Add independent wide-integer controls. | Exact vectors/fuzz properties for arithmetic, endpoints, overflow, genesis, one-sided branches, and non-dilution. |
| **WP2 — Package and real fixture foundation** | WP0 | Implement package interface/Repo/lifecycle, canonical facet reuse, component factory, and family TestBase from `IndexedexTest`. Register real packages and instances. | Real initialized proxy; sorted contents discovery; permit/domain isolation; zero-fee declaration; no factory-facet duplication. |
| **WP3 — Exact V4 projector and complete planner** | WP1, WP2 | Implement copied state, overlays, position changes, swaps, fees, shared step counters, operation plans, and typed fallback classification. | Differential transitions against real manager actors; independent 512/513 controls; no writes in view execution; original-state isolation between candidates. |
| **WP4 — Guarded settlement and maintenance** | WP3 | Implement callback commitments, manager-unlocked rejection, categorized custody, ERC-20/native settlement, donation, compound, and final fee checkpoints. | Actual manager deltas close to zero; no unbooked adoption; share supply unchanged; fees counted once; native sync reset demonstrated. |
| **WP5 — Paired entry and paired exit** | WP4 | Implement exact accepted-input pulls, caller-only additions, final credit cap, native refunds, proportional exits, fallback, zero-payout rejection, terminal reset, and restart. | Genesis-to-terminal public lifecycle; exact preview parity; rollback; non-dilution; no dead shares or retention. |
| **WP6 — Zaps and scalar SE routes** | WP5 | Implement both entry swaps, post-swap fee checkpoint, credited growth/uncredited residuals, both exit sales, full-consumption checks, and pretransfer share/token paths. | Four routes; exact output explicitly unavailable; exact state/output parity; no claimant access to booked backing. |
| **WP7 — Native SY, rate, and complete proxy surface** | WP6 | Implement native/wrapped adapters, SY execution seams, guarded previews, cached asset metadata, wide rational rate, empty rewards, and full selector installation. | All 60 package selectors reachable on registered proxies; native/wrapped economic equivalence; canonical SY events/errors and permit behavior. |
| **WP8 — Adversarial integration and release evidence** | WP7 | Finish all acceptance subcases, independent reachability/proof obligations, handlers, comparison ledger, runtime-size and gas measurements, regression and hermetic integration gates. | A01–A70 evidence ledger complete; production deployment limits met; no unexplained failures or unverified completion claims. |

Math and package foundation can be developed independently after WP0. Their interfaces must settle before integrating the projector. Economic execution must not precede a complete-plan architecture and authoritative custody classification.

## Operation ledger

Use one family-owned book for actual pool currencies. The basic-vault Repo is only its published snapshot.

For each currency, distinguish:

- Incumbent booked idle.
- Pending caller inventory.
- Reserved exit allocation.
- Reserved refund.
- Unbooked excess.

Keep native-versus-wrapped representation explicit during adaptation. At stable return, owned native inventory is ETH; the wrapper is not a third managed asset.

### Entry funding

- **Paired ERC-20 entry:** preflight with hypothetical accepted inputs; after incumbent maintenance, pull exactly the accepted amounts. Do not pull maxima.
- **Native paired entry:** reserve all `msg.value` immediately, before planning or maintenance. Later partition it into accepted input and refund.
- **False-flag scalar entry:** require exact observed delivery into caller inventory.
- **True-flag scalar entry:** require a code-bearing caller and enough unbooked custody; reserve only the declared amount.
- **Wrapped-native input:** reserve the wrapper units first, unwrap exactly those units, and replace that reservation with ETH. Resting ETH does not fund the claim.
- **Share pretransfer:** burn only authenticated vault-held shares; excess held shares remain held. Do not treat ordinary holder balances as internal credit.

Before using `LocalCreditLib.available`, separately check custody solvency. Its saturating subtraction must not disguise a book shortfall as merely zero available credit.

For a native alias, wrapper pretransfer availability is calculated against **wrapper-represented reservations**, not by subtracting ETH booked backing from the wrapper balance. For an ERC-20-only pool containing WETH as an actual currency, use ordinary ERC-20 accounting.

### Manager deltas

For every liquidity modification:

1. Decode actual `callerDelta` and `feesAccrued`.
2. Derive principal delta separately.
3. Debit/credit the correct owner category.
4. Settle the net actual manager delta.
5. Verify local receipts/payments and expected manager state.

A fee included in `callerDelta` is not a second transfer. Conversely, netting fees against an addition’s debt does not make those incumbent fees entrant principal.

### Final commit

After payouts and refunds:

- All operation reservations are zero.
- Raw custody covers booked idle.
- Unbooked assets remain unbooked.
- Both shared reserve values are published together in face order.
- Callback expectation is consumed/cleared.
- The family guard is released last.

Terminal operations must allocate all owned receipts to the last holder. Unsolicited receipts remain separate; they must not be used to conceal a stranded owned remainder.

## Fee checkpoints and compound

Implement one maintenance engine used by explicit compound and mandatory maintenance.

1. Collect accrued fees only when the owned position is nonempty.
2. Book all actual collected fees for incumbents.
3. Apply the baseline `B_i > 1000` trigger.
4. Compute the baseline affordable addition and clamped, rounded-up costs.
5. Derive leftovers.
6. Preserve the baseline **sequential-floor** token0-leftover comparison and token0 tie direction.
7. Swap half the chosen leftover, capped by the active-pool reserve estimate and the specified quarter-cap.
8. Reinvest affordable incumbent inventory.
9. Complete the final nonrecursive fee checkpoint:
   - A positive addition may already realize the maintenance-swap fees.
   - Otherwise poke the nonempty position once.
   - Book those fees idle; do not recursively reinvest them.

`compound()` returns the sum of fees realized at its checkpoints, once. It does not mint/burn or call a fee manager.

`S = L = B0 = B1 = 0` is a no-op even if raw unbooked custody is nonzero.

Use owned liquidity for the position and basket. Use active pool liquidity only where the baseline compound cap requires it. These quantities are not interchangeable.

## Caller-attributed issuance

### Paired entry

First compute `qQuote` and accepted inputs exactly as S1-ACC-02 specifies. Preserve ceiling acceptance and the full-live-leg one-sided branch.

After maintenance and before the caller-only addition:

- Freeze `S`, `P*`, `L`, and `B`.
- Compute `R_i = N_i(P*,L) + B_i`.
- Add from accepted caller inventory only.
- Use actual principal costs to obtain remaining caller inventory `J_i`.
- Compute `G_i = N_i(P*,L+dL) - N_i(P*,L)` at unchanged `P*`.
- Credit `C_i = G_i + J_i`.
- Mint `min(qQuote, min floor(S*C_i/R_i))` over positive reserve legs.

Do not recompute accepted amounts after the final cap. Enforce the minimum against final minted shares.

At genesis, use checked `a0*a1`, floor square root, positive inputs and fundable positive liquidity. Mint all `qQuote` to the recipient. Do not apply the positive-supply cap or introduce a hidden minimum.

A positive-supply paired entry need not be rejected merely because its addition is zero if its specified idle credit otherwise produces a valid positive final result. The positive-add requirement is explicit for genesis.

### Zap entry

After maintenance:

1. Freeze the pre-entry-swap reserves for the size check.
2. Validate positive supply, both reserves positive, and the configured input cap.
3. Swap exactly `floor(received/2)` as the requested exact-input amount; retain partial-fill remainder in caller inventory.
4. Enforce tick movement around this swap only.
5. Collect incumbent fees earned through this swap.
6. Freeze the post-swap incumbent snapshot.
7. Add from caller inventory only.
8. Credit only `G_i`.
9. Mint final `qCredit`, then book `J_i` as the explicit no-extra-shares contribution.

`previewZapCredit` and `ZapCredit` must expose the same credit/residual decomposition as execution. Include actual input, both credits, both residuals, and actual shares in the event; identify caller/recipient/input representation as useful indexed fields.

Test the exact inequalities using wide products:

`q * R_i <= S * C_i`

Do not compare truncated “per-share” displays, allow epsilon dilution, include incumbent maintenance deployment in `C_i`, or use SY valuation to price issuance.

## Withdrawal and fallback

### Proportional allocation

After selected maintenance and its final checkpoint:

- Snapshot `S`, `L`, and `B`.
- Compute floor proportional liquidity and idle allocations.
- Validate the actual burn authority.
- Burn the submitted shares.
- Remove the selected liquidity.
- Allocate actual principal proceeds plus reserved idle.
- Reject zero total actual paired payout.

Removal fees should already be checkpointed. Unexpected fee/price mutation between snapshot and removal invalidates the plan; it is not another holder allocation.

Single-token withdrawal sells only the unwanted exit allocation. No re-addition occurs. Require full unwanted-input consumption and a positive final requested-token payout, then enforce the minimum.

For the last holder, paired withdrawal removes all owned liquidity and pays all owned assets. A single-token exit must use actual remaining external liquidity after removal or revert.

### Typed planner classification

The planner returns either:

- A valid complete `FullCompound/None` plan.
- A specifically classified maintenance obstacle.
- A terminal economic-domain failure.

Only the four specified obstacles allow another candidate:

| Reason | Implementation classification |
|---|---|
| `MaintenanceWorkLimit` | The complete normal withdrawal requires another swap-loop iteration after 512 executed iterations. The exhaustion may occur in the full candidate’s final sale; selection still requires a valid complete collection-only candidate. |
| `MaintenancePriceLimit` | A **nonzero maintenance swap** lacks a legal directional interval. A calculated zero swap is not this failure. |
| `MaintenanceLiquidityLimit` | The maintenance addition cannot fit the prescribed owned/signed/per-tick/principal-delta limits. |
| `MaintenanceDeltaLimit` | A maintenance swap quantity or settlement delta cannot fit the manager’s supported types. |

Attach operation phase to failures so an entry addition, final exit sale, fee collection, or general arithmetic failure is not mislabeled as a maintenance obstacle.

On an eligible failure, rebuild collection-only planning from the original state with a fresh 512-step counter. Do not carry over price, fees, liquidity, ticks, bitmap changes, or inventory from the rejected candidate.

If the second candidate fails, return its actual domain failure. Never execute a partial first candidate, catch an external failure to retry, or select fallback solely because a minimum or final sale fails.

A valid full candidate always wins. Emit exactly one successful `WithdrawalMaintenanceSelected` event.

## Exact projector

### State loading and overlays

Load canonical state using `StateLibrary`, not private offset copies:

- Pool slot0: price, stored tick, directional protocol fees, LP fee.
- Active liquidity.
- Global fee growth.
- Owned position liquidity and inside-fee checkpoints.
- Full-range boundary tick gross/net liquidity and outside fee growth.
- Tick bitmap words and crossed ticks fetched on demand.
- Supply, committed book, immutable configuration, and hypothetical operation inventories.

Use bounded memory caches/overlays keyed by bitmap word and tick. The first read captures live state; later simulated reads use overlay values.

A candidate can visit at most 512 swap iterations plus its fixed full-range boundary data. Allocate cache capacity from that proof, with no new externally visible “cache full” rejection inside the admitted 512-step domain. Avoid a scan of every initialized tick in the pool.

Keep the original snapshot immutable. Each withdrawal candidate gets independent mutable overlays.

### Swap transitions

Mirror the admitted canonical `Pool.swap` behavior:

- Directional protocol-fee extraction and combined fee calculation.
- Negative exact-input amount semantics.
- Legal price limits.
- One-word bitmap progress, including negative tick compression.
- Canonical next price target and `SwapMath.computeSwapStep`.
- Actual consumed input and output.
- Protocol-fee deduction before LP fee growth.
- Modular fee-growth accumulation.
- Initialized-tick crossing and outside-fee updates.
- Directional liquidity-net application.
- Stored tick behavior at exact boundaries, including `tickNext - 1`.

Do not replace the stored tick with `getTickAtSqrtPrice(P)` everywhere. The admitted canonical implementation intentionally allows a boundary price with the tick already advanced to the adjacent interval.

### Liquidity and position transitions

Model the actual `Pool.modifyLiquidity` order:

1. Update boundary gross/net liquidity.
2. Enforce per-tick capacity.
3. Flip bitmap bits when required.
4. Calculate inside fee growth.
5. Realize fees using pre-change owned liquidity.
6. Update owned liquidity and position checkpoints.
7. Clear removed boundary state when appropriate.
8. Calculate signed principal costs/proceeds.
9. Update active liquidity according to the stored tick’s interval.

Reuse canonical pure math. Storage-bound functions such as `Pool.swap` and `TickBitmap.nextInitializedTickWithinOneWord` cannot simply operate on a memory copy; implement the small memory-state adapter with explicit source correspondence and differential tests.

### Work budgets

- Check loop termination before charging a step.
- Permit iteration 512.
- If another iteration is required, fail with `QuoteWorkExceeded(513,512)` without executing it.
- Share the counter across every swap in that candidate.
- Entries and explicit compound get one candidate.
- Withdrawals get at most two, each independent.
- Do not repeat planning inside execution callbacks and accidentally exceed the declared total.
- Budget exhaustion returns no partial valid output.

### Execution witnesses and invalidation

A plan contains ordered manager actions, categorized funding, expected deltas, fee checkpoint results, expected state transitions, and its read set.

Revalidate relevant state after token/wrapper interactions and before consuming the next planned manager action. Validate actual deltas and post-action state against the plan.

The witness must cover more than slot0: include active liquidity, fee globals, owned checkpoints, full-range boundaries, and bitmap/tick records that determine the remaining plan. A callback can change a future tick without leaving the current price changed.

A changed witness produces `EconomicStateChanged()`. Do not recompute a replacement plan after mutation or accept unexpected fee receipts.

The projector excludes authorization, allowances, staged credit availability, receiver acceptance, attached value, and deadlines from economic parity. Execution validates those independently.

## Exact SY arithmetic

The compound leftover comparator and the SY accounting converter intentionally use different rounding rules.

For SY valuation, let `D = P²` as a **320-bit integer**, not a `uint256` multiplication.

### Conversion into token1

Compute:

`floor(A0 * D / 2^192)`

Implementation:

1. Form the exact two-limb square of the 160-bit price.
2. Multiply by `A0` into three 256-bit limbs; the product needs at most 576 bits.
3. Shift the complete product right by 192.
4. Retain the resulting wide integer and discard only the actual fractional remainder.

### Conversion into token0

Compute:

`floor((A1 << 192) / D)`

Implementation:

1. Represent the numerator in two limbs; it needs at most 448 bits.
2. Divide by the complete two-limb square.
3. Use normalized shift/compare/subtract division, starting at the difference in significant-bit positions.
4. Set quotient bits only after exact multiword comparison/subtraction.

This has a fixed width-derived bound, not an amount-dependent unbounded loop. A 512-bit divider requires at most 512 bit positions; this inverse numerator needs no more than 448.

### Final rate

Keep converted value and the subsequent addition wide. Multiply the wide `Vraw` by `1e18`, then divide by `S`. Narrow only the final rate after checking representability.

For the relevant operand widths, the valuation and final-rate intermediates fit the planned multiword representation. Do not reject a representable final rate merely because an intermediate converted basket value exceeds one word.

At zero supply, return zero before division.

Use explicit overflow errors for mathematically unrepresentable final results. For ordinary mulDiv/ceil operations, reuse canonical full-precision arithmetic where it matches; do not let an overflowing non-limiting intermediate ratio incorrectly decide a minimum that is representable.

A simple exact control demonstrates why sequential floors are unsuitable here:

- `P = 3 * 2^96 / 2`
- `A0 = 1`
- Single-floor conversion: `floor(9/4) = 2`
- Sequential floors: `floor(floor(3/2) * 3/2) = 1`

Asset decimals affect `assetInfo` only. Test the six-decimal example exactly: `Vraw=1e6`, `S=1e18`, rate `1e6`.

The existing `SYUtils.syToAsset` itself uses checked one-word multiplication. Exercise it within its representable multiplication domain; separately test the vault’s wide rate calculation. Do not silently alter that shared library or introduce a decimals multiplier.

## Native handling and callback policy

- Native value is reserved before maintenance.
- SE remains nonpayable and rejects address-zero routes.
- SY raw-native and wrapped-native routes use the same economic planner.
- Paired methods use actual PoolKey currencies.
- Wrapping/unwrapping replaces a reservation one-for-one.
- Before **every** native debt settlement, execute `sync(native)`, then `settle{value: exactDebt}()`, and verify the returned amount.
- ERC-20 debt uses canonical sync/transfer/settle with observed receipt checks.
- Credits use `take`; validate what the vault actually receives.
- Payout/refund uses checked value transfer without a fixed stipend.

All family money entrypoints share one guard. Before unlock, commit the operation kind and payload hash. Callback entry authenticates manager, active operation, expected kind, and commitment, then consumes that commitment before making external calls.

Check `TransientStateLibrary.isUnlocked` before starting an unlock. Reject rather than entering a local-sleeve mode.

During an operation:

- Family economic reads and supported economic previews revert `ReentrantOperation`.
- Shared basic-vault reserves return the previous committed snapshot.
- Token/domain and static configuration/discovery retain canonical behavior.
- Empty-calldata ETH receipt performs no attribution by itself.

For SY invalid-token previews, check the family read guard first, then preserve the ordinary idle-state zero result.

For exact-output previews, apply the specific S1-P03/S1-OBS-01 rule: `ExchangeOutNotAvailable()` remains the unconditional unsupported result. This treats the general economic-preview guard as applying to supported economic planning, not as changing the specifically mandated Out error.

# Testing plan and A01-A70 matrix

## Proposed test infrastructure

Under P:

- `test/bases/TestBase_UniswapV4PairTokenStandardExchangeVault.sol`
- `test/behaviors/Behavior_UniswapV4PairTokenStandardExchangeVaultPackage.sol`
- `test/handlers/UniswapV4PairTokenStandardExchangeVaultHandler.sol`
- `test/helpers/UniswapV4PairTokenStandardExchangeVaultPoolActor.sol`
- Focused non-SUT token, receiver, and atomic-pretransfer helpers where existing helpers do not suffice.

Under:

`test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/pairToken/`

use these proposed suites:

- `FDeployment.t.sol`
- `FSurfaces.t.sol`
- `FMath.t.sol`
- `FEntry.t.sol`
- `FExit.t.sol`
- `FMaintenance.t.sol`
- `FProjection.t.sol`
- `FFallback.t.sol`
- `FSY.t.sol`
- `FCredit.t.sol`
- `FNative.t.sol`
- `FSecurity.t.sol`
- `FLedger.t.sol`
- `FInvariant.t.sol`
- `FArtifactSizes.t.sol`
- `FExecutionCost.t.sol`

F expands to the full family prefix. Use test names beginning `test_S1_Axx_` or `testFuzz_S1_Axx_` so acceptance evidence is mechanically discoverable.

Put independent arithmetic vectors/oracle code in that test directory’s `reference/` subdirectory. Keep comparison-only tests separate from new-family acceptance.

## Production-first fixture

Build from `CraneTest -> IndexedexTest -> family TestBase`, reusing shared component helpers as appropriate.

The fixture must deploy:

- Real CREATE3 and diamond factories.
- Real IndexedEx manager, registry, and fee oracle.
- Real production-faithful PoolManager.
- The five canonical facets and new family components.
- A package registered through `indexedexManager.deployPkg`.
- Instances through the registered package’s `deployVault`.
- A real canonical wrapped-native implementation for native cases.
- Mintable supported tokens with 6/8/18 decimals.

Fund actors, then obtain all vault shares through public paired genesis/deposits. Do not inject shares, subclass the vault, write its storage, or etch any SUT.

Use independent PoolManager actors to create external liquidity, initialize dense ticks, trade, donate to pool fee growth, remove liquidity, and exercise actual unlocked-manager contexts.

Non-SUT adversarial tokens/receivers may provide short delivery, actual FoT behavior, reentrancy, rejection, or pool mutation. They must interact with the real vault and manager.

Maintain two-instance fixtures sharing facets but owning distinct position keys.

## Independent controls and invariants

### Arithmetic controls

Use an independent arbitrary-precision oracle for:

- Single-floor currency valuation.
- Wide products in non-dilution.
- Genesis square root and overflow boundaries.
- Floor/ceiling accepted amounts.
- Actual removable-principal growth.
- Proportional liquidity and idle allocation.
- Modular fee-growth subtraction.

The oracle must not call the production family math function to calculate its expected result. Fixed vectors should include remainder-sensitive and overflow-sensitive cases, not only round numbers.

For V4 transitions, use actual manager execution as a differential oracle. Compare intermediate slot0, active/owned liquidity, tick/bitmap state, fee checkpoints, principal deltas, fee deltas, and custody, not only final shares.

### Sequence handler

Expose actual public operations to multiple actors:

- Paired deposits and zaps.
- SE/SY native and wrapped forms.
- Paired and single-token withdrawals.
- Donation and compound.
- Share transfers and authenticated pretransfers.
- External pool swaps, liquidity changes, and fee generation.
- Unsolicited ERC-20/ETH transfers.
- Disable/enable actions through legitimate registry authority.
- Terminal exit and rebootstrap.

Track a ghost ownership ledger independently from production storage. Assert:

- Supply equals tracked balances, including vault-held shares.
- Manager-owned liquidity equals the real position.
- Custody categories reconcile.
- Reservations are zero at successful external return.
- Unbooked balances are never adopted.
- Donations do not mint.
- Entry inequalities hold exactly at `P*`.
- Exit allocations equal their pre-sale proportional entitlement.
- External swap effects and entrant residual donations are reported separately.

Do not assert an unsupported monotonic NAV, manipulation immunity, or absence of profitable trading.

## Acceptance matrix

Each row names its primary proposed suite and concrete assertion. Additional suites may cover the same obligation.

| ID | Proposed case and required evidence |
|---|---|
| **S1-A01** | **Deployment — RegisteredDiscovery:** deploy through manager/package/registry; discover the actual proxy by each face, both-token contents, and declared types, including native wrapped-face discovery. |
| **S1-A02** | **Deployment — IdentitySensitivity:** prediction equals deployment; identical identity reuses the address; vary each valid immutable argument/binding independently and prove intended salt/address sensitivity. |
| **S1-A03** | **Deployment — ConfigurationDomain:** reject invalid currency order/code/self-reference, spacing, static fee, hook, initialization, rate asset, zap parameters, wrapper, and face collision; deploy valid native/ERC-20 pools. |
| **S1-A04** | **Deployment — LifecycleAuthority:** reject direct initializer misuse, wrong-registry processing, repeat initialization, invalid component code, duplicate/forbidden cuts, and forged deployment context. |
| **S1-A05** | **Surfaces — MetadataAndPermitDomain:** exact configured metadata and 18 decimals; real signatures authorize only the correct proxy/domain. |
| **S1-A06** | **Surfaces — CompleteSelectorUnion:** independent Target/interface controls match declarations/cuts; call every product selector on the proxy; final loupe equals package plus persistent factory selectors, disjointly. |
| **S1-A07** | **Surfaces — BookedReserveDiscovery:** verify initialized config/order/types/contents and unknown-token zero; deployed principal is not reported as local custody. |
| **S1-A08** | **Entry — FullGenesisMint:** public paired genesis mints the complete floor geometric mean to the recipient; total supply has no hidden sink. |
| **S1-A09** | **Entry — GenesisFailures:** zero inputs/output, checked product overflow, no fundable addition, and final minimum failure revert all transfers, liquidity, book, and supply. |
| **S1-A10** | **Entry — PairedAcceptanceAndCreditCap:** independently compute limiting ratio and ceiling accepted inputs; assert final credit cap, unchanged unused ERC-20 maxima, and exact native refund. |
| **S1-A11** | **Entry — OneSidedAndEmptyBacking:** exercise each live-leg-only branch and positive-supply/both-zero rejection without synthetic share issuance. |
| **S1-A12** | **Entry — IncumbentMaintenanceIsolation:** accrued fees and idle compound before snapshot; pending caller ERC-20/pretransfer/ETH inventory is excluded. |
| **S1-A13** | **Entry — BothZapDirections:** verify half-input request, actual partial fill, post-swap incumbent checkpoint, caller-only addition, `G`, and final shares in both directions. |
| **S1-A14** | **Entry — ZapDomainBoundaries:** empty supply/basket, zero input, cap equality/one-above, and tick-limit equality/one-above have exact preview/execution behavior. |
| **S1-A15** | **Entry — ExactNonDilution:** arbitrary-precision products prove `qR_i <= SC_i` for every positive leg, including imbalanced idle, partial fills, residuals, and addition rounding. |
| **S1-A16** | **Exit — FullShareProportion:** exact floor liquidity/idle allocation and actual principal proceeds for submitted shares; no 9990/10000 reduction. |
| **S1-A17** | **Exit — PartialDustOwnership:** exact residual book/liquidity remain with surviving holders; no extra shares and no duplicate whole-position fee allocation. |
| **S1-A18** | **Exit — AllocationOnlySales:** each output direction sells only its reserved unwanted allocation; returned amount equals recipient receipt and meets the actual minimum. |
| **S1-A19** | **Exit — PartialSaleAndPairedFallback:** unavailable full sale reverts completely; paired exit succeeds under a valid listed-obstacle fallback; unexpected failure still reverts. |
| **S1-A20** | **Exit — TerminalResetAndRestart:** last paired exit zeros supply, owned liquidity, and booked balances; next genesis excludes old unsolicited funds. |
| **S1-A21** | **Exit — TerminalSaleLiquidity:** external LP liquidity permits a full terminal sale; insufficient remaining liquidity restores shares and all prior state. |
| **S1-A22** | **Maintenance — AllFeesRetained:** exact LP-fee receipts stay backing; supply unchanged; no fee-manager call or allowance appears in traces. |
| **S1-A23** | **Maintenance — BaselineBranches:** DUST equality, just-above trigger, leftover tie, zero active liquidity, quarter-cap, and zero-swap branches use exact expected amounts. |
| **S1-A24** | **Maintenance — CheckpointOwnership:** positive-add and zero-add maintenance branches include swap fees once; entry-swap fees are incumbent-owned; exit-sale fees belong to surviving liquidity; principal is separate. |
| **S1-A25** | **Surfaces — RouteTable:** execute all four currency/share routes; reject currency-to-currency, self, identical, unrelated, and zero-address SE routes. |
| **S1-A26** | **Surfaces — ExactOutputUnavailable:** both Out selectors revert the required error, even with balances/allowances/pretransfers present; assert no manager or token mutation. |
| **S1-A27** | **Projection — ExactEconomicParity:** from identical snapshots compare every SE/paired preview with actual output and state, including accrued fees, maintenance, crossings, and terminal cases. |
| **S1-A28** | **Projection — CandidateWorkBoundaries:** independent fixtures require exactly 512 or 513 iterations; verify error/mode parity, counters across swaps, at most two candidates/1,024 executed steps, and pristine fallback state. |
| **S1-A29** | **Surfaces — CompleteSY:** all 16 SY selectors installed; execution/preview equivalence with corresponding SE routes; `yieldToken` is the same diamond and no second supply exists. |
| **S1-A30** | **SY — InternalSharesAndValidation:** code-less/construction-time internal redemption rejects; contract-held share consumption is exact; unsupported token and native-value errors preserve shared semantics. |
| **S1-A31** | **SY — EmptyRewards:** arrays are empty and canonical claim event is truthful; no token transfer or double LP-fee claim occurs. |
| **S1-A32** | **SY — RawUnitRationalRate:** independent wide valuation for both rate assets and 6/8/18 decimals; canonical helper returns raw units within its domain; sequential-floor counterexamples are included. |
| **S1-A33** | **SY — ZeroSupplyRate:** fresh and reset vault rates are zero; neither genesis nor later issuance consults a synthetic bootstrap price. |
| **S1-A34** | **Credit — ExactPullReceipt:** short/no/incorrect delivery fails even with abundant booked and unrelated raw balances; observed receipt alone establishes caller input. |
| **S1-A35** | **Credit — CallerClass:** EOA and constructor-time true-flag calls return the canonical pretransfer error without state changes. |
| **S1-A36** | **Credit — NoBackingClaims:** contract claimant with no/short unbooked funds cannot mint or spend existing backing; exact insufficient-credit data is asserted. |
| **S1-A37** | **Credit — ExcessPretransfer:** process exactly the declaration, refund nothing, and preserve excess unbooked custody through subsequent operations. |
| **S1-A38** | **Credit — DonationVsUnsolicited:** exact same-call donation increases book with no shares; unrelated transfers survive compound/entry/exit/restart without adoption. |
| **S1-A39** | **Security — CallbackAuthentication:** real callback succeeds; wrong sender, absent operation, wrong kind/hash, replay, nested callback, and cross-facet money reentry fail. |
| **S1-A40** | **Security — AlreadyUnlocked:** invoke via a real manager actor’s unlock; reject before nested unlock, including entry, exit, and explicit maintenance paths. |
| **S1-A41** | **Ledger — StateReconciliation:** after every operation reconcile manager position, raw custody, book, supply, recipient deltas, and event amounts independently. |
| **S1-A42** | **Security — DisableMatrix:** effective address/package disable stops all issuance and donation; compound and executable SE/SY/paired exits remain available under unchanged maintenance rules. |
| **S1-A43** | **Security — AtomicRollback:** token transfer, wrapper, receiver, or minimum failure restores earlier swaps, fee checkpoints, liquidity, burns, allowances where consumed, and balances. |
| **S1-A44** | **Security — DecimalAndFoTBoundary:** real mixed-decimal pools operate; a real FoT configured token cannot produce unsupported shares/payouts or consume existing book to cover its shortfall. |
| **S1-A45** | **Projection — ClampAndCapacity:** interior, exact lower/upper, and outside-range math match manager receipts; classify maintenance capacity failures correctly and reject other overflows without clamping. |
| **S1-A46** | **Ledger/Invariant — OwnershipSequences:** public-route sequences establish exact supply, unbooked separation, donation/no-mint, per-leg non-dilution, and pre-sale exit allocation; separate market effects from ownership accounting. |
| **S1-A47** | **Deployment — SharedFacetIsolation:** two proxies sharing all facets have isolated metadata, books, approvals, permits, positions, guard state, and initialization. |
| **S1-A48** | **ArtifactSizes — CurrentCodeWithinLimits:** every actually deployed component fits normal runtime limits; artifact deployment uses current bytecode; compiler and fuzz/invariant settings are not weakened. |
| **S1-A49** | **Native — PairedInputAndRefund:** exact maximum value accepted/reserved; only unused native maximum refunded; wrong value or rejecting refund receiver rolls everything back. |
| **S1-A50** | **Native — RawWrappedEquivalence:** restore equal state for raw-native SY and wrapped SE/SY operations; shares/allocations match exactly while only delivery representation differs. |
| **S1-A51** | **Native — RealProxySettlement:** real payable proxy selectors, wrapper withdraw/deposit, manager take/settle, and empty-calldata receipts work; traces contain no ERC-20 call to address zero. |
| **S1-A52** | **Native — RepresentationIsolation:** forced ETH, unsolicited wrapper balances, pending input, and refunds remain separate; unwrap/wrap never doubles backing or claimable input. |
| **S1-A53** | **Native — ReceiverBehavior:** rejecting/reentrant receivers cannot escape the guard; legitimate storage-writing receivers receive ETH without a fixed stipend restriction. |
| **S1-A54** | **Native — TerminalAndRestart:** terminal paired exit empties owned ETH/token backing and position; rebootstrap excludes previously forced/unbooked ETH. |
| **S1-A55** | **Native — DonationForms:** raw/wrapped donation credits the native leg exactly once; ordinary ERC-20 WETH remains ordinary; wrong value, invalid raw-native use, and zero-address SE routes reject. |
| **S1-A56** | **Surfaces — CanonicalTwenty:** exact 9+3+1+3+4 selector ownership and canonical IDs; no combined permit facet, duplicate selector, or factory facet in package inputs/cuts. |
| **S1-A57** | **Surfaces — FactoryAndPermitLifecycle:** persistent factory interfaces work; temporary hook disappears; actual permit advances nonce, rejects replay/wrong instance, and uses initialized proxy Repos. |
| **S1-A58** | **Deployment — ReversedFaceSort:** choose wrapper address above the other token; views preserve face order while registry pair queries resolve the sorted-copy contents hash. |
| **S1-A59** | **Security — CallbackReadMatrix:** invoke every read class during token/receiver callbacks; economic reads reject, shared reserves return the pre-operation snapshot, canonical token/domain/static reads work. |
| **S1-A60** | **Native — SyncResetAndReceive:** arrange outstanding ERC-20 sync before native debt; prove explicit native sync and zero closed deltas; empty-calldata receipt is attributed only by the engine. |
| **S1-A61** | **Fallback — FourReasonEvidence:** each reason gets a reachable real-manager witness or an independent unreachable-domain proof; preview/event/execution agree; valid full candidate wins. |
| **S1-A62** | **Fallback — NoExceptionRecovery:** real token/wrapper/custody/collection/state-change/manager/payout failures never select fallback; invalid collection-only planning performs no partial maintenance. |
| **S1-A63** | **Fallback — NonTriggersAndModeABI:** minimum failure or unavailable final sale alone never changes mode; paired sentinel and raw-ETH single output are unambiguous. |
| **S1-A64** | **Entry — CreditDecomposition:** distinguish costs, `G`, paired `J`, zap uncredited `J`, and incumbent fees; final minima use `q`, not `qQuote`; rounding losses are entrant-borne. |
| **S1-A65** | **Ledger — StableReservationsAndTerminalReceipts:** every successful return has zero reservations and reconciled custody; terminal owned receipts are paid, while unsolicited funds remain excluded. |
| **S1-A66** | **Exit — EmptyAndTinyStates:** clean empty compound is a no-op; positive-share zero-total-output burn rejects; one-sided payout succeeds; tiny genesis/donation sequences use no hidden sink/minimum. |
| **S1-A67** | **Projection — FullV4StateAndInvalidation:** nonzero directional protocol fees, initialized crossings, empty-word progress, and checkpoint changes match manager execution; token/wrapper mutations produce `EconomicStateChanged`. |
| **S1-A68** | **Surfaces — ImmutableCapabilityBoundary:** final manifest is complete; no ownership, diamondCut, rescue, ERC-4626, rate-provider, transition-quote, or excluded integration selectors are present; bindings affect identity. |
| **S1-A69** | **Deployment — ZeroFeesAndRawConfiguration:** real registry accepts zero fee IDs; DUST is exactly 1,000 raw units; zap bounds are explicit; asset decimals are validated/cached, not used as a rate multiplier. |
| **S1-A70** | **ExecutionCost — DeploymentFeasibility:** measure worst candidate planning, native/wrapped execution, fallback paired exits, linked components, and runtime/initcode against recorded deployment limits; failure blocks release. |

## Difficult fixture obligations

Do not replace these with scripted acceptance:

- **Work limit:** construct dense initialized ticks and empty-word traversal with real manager actors. Determine boundary input amounts from an independent transition control, not trial-and-error timing. Count iterations across maintenance and final swaps.
- **Liquidity limit:** occupy full-range boundary capacity using external positions, then create booked maintenance inventory through legitimate donations/fees. The normal addition must exceed remaining capacity without being silently reduced.
- **Price limit:** target a protocol-boundary state with a genuinely nonzero calculated maintenance swap. If active-liquidity/cap rules make a proposed witness a zero-swap branch, it is not a fallback witness.
- **Delta limit:** construct real extreme-price/quantity states through valid manager operations, or prove the specific subdomain unreachable from those operations. A synthetic planner input alone does not satisfy A61.
- **Invalidation:** mutate pool state from a non-SUT token/wrapper interaction before the next planned action. Include a future bitmap/tick mutation, not only a changed spot price.
- **Tiny accounting states:** exercise very small public genesis values. A valid small genesis may have principal rounding effects; do not “repair” them with dead shares or a new minimum. Prove the specified invalid-accounting and zero-payout responses.

Use pure planner/math harnesses for impossible or synthetic domain validation, but label them separately from real-manager acceptance and reachability evidence.

## Baseline comparison discipline

Keep `contracts/pairtoken-baseline/**` and its existing tests unchanged.

Comparison-only tests may reuse the inspected `PairTokenTestBase` API:

- `_deploy`
- `_bootstrap`
- `_position`
- `_idle`
- `_callback`
- `_delta`

and the existing scripting methods such as `queueModify`, `queueSwap`, factory configuration, token return modes, and trace entries.

Always create a fresh real baseline instance. Do not subclass, etch, or inject storage into it. Do not modify the shared harness to accommodate the new family.

Maintain four comparison categories:

1. **Preserved:** baseline compound sizing/branches, half-zap request, tick guard, compatible interior arithmetic.
2. **Intentional deviation:** all S1-X01–S1-X19, including attribution, checkpoints, native sync, terminal behavior, and error changes.
3. **Unsupported scope:** exact output, fee-manager routing, hooks, retired families, and optional integration surfaces.
4. **New capability:** registry packaging, canonical permit/domain, complete SY/native faces, exact projector, and conditional withdrawal planning.

Changed end-state economics must be checked against the revised equations and real manager receipts, not forced into baseline equality.

# Validation/release gates

All commands below are **prospective**. None was run during this assignment.

## Artifact-first workflow

After each production edit, pass every edited production source to the repository helper. For example, after adding the proposed family files:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultMath.sol \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultProjection.sol \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultPlanner.sol \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultExecution.sol \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultDFPkg.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/pairToken \
  -- -vv
```

Add other changed Targets/interfaces/facets to that invocation rather than assuming a stale artifact will be rebuilt.

For artifact preparation without executing tests:

```bash
python3 scripts/forge-artifacts.py build \
  --consumer 'test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/pairToken/*.t.sol'
```

For release:

```bash
python3 scripts/forge-artifacts.py build --all-artifacts
forge build --sizes
forge test
```

Use focused regressions during development and the required full hermetic/integration gate before declaring completion. No fork dependency is required for this family’s acceptance. Any later fork run uses the existing `fork` profile and is reported separately.

## Compiler, cache, and execution discipline

- Run language-server diagnostics on touched Solidity before compilation.
- Keep solc/settings from the actual repository configuration.
- Do not enable `via_ir`, raise deployment size limits, lower fuzz/invariant settings, or introduce a package profile.
- Keep configured `src`, `test`, `out`, and `cache_forge` paths stable.
- Seed both `out/` and `cache_forge/` from a warm checkout before compiling in a new/empty worktree.
- Do not clear shared caches or run competing artifact writers.
- Allow cold compilation to finish; use background completion notification and an hours-scale deadline if required.
- A build passes only with exit code zero. Test evidence must contain actual passing output or a precisely separated pre-existing failure.

Fresh artifacts do not update an already occupied CREATE3 address. Acceptance fixtures must use a fresh deployment environment, and artifact/code checks must prove that the runtime under test is the intended build.

## Selector verification

The existing core script is:

`lib/crane/scripts/foundry/ComputeNatSpecValues.s.sol`

It does not enumerate this future family. Add a **proposed** scoped verifier:

`scripts/foundry/ComputePairTokenStageOneNatSpecValues.s.sol`

It should import the real family/canonical interfaces, compute selectors/interface IDs/event topics through compiled Solidity, and verify the manifest. Do not handwrite hex selectors or copy incomplete facet declarations into the controls.

Build its artifacts before running:

```bash
python3 scripts/forge-artifacts.py build \
  --consumer scripts/foundry/ComputePairTokenStageOneNatSpecValues.s.sol

forge script \
  scripts/foundry/ComputePairTokenStageOneNatSpecValues.s.sol \
  --sig "run()" -vvv
```

This is a local verification script with no broadcast.

## Release gates

| Gate | Required evidence |
|---|---|
| Requirements | Every acceptance row and relevant S1-X deviation linked to concrete tests and implementation symbols. |
| Deployment | Real registered deployment, all initialization checks, binding identity, zero-fee registration, sorted contents discovery, and factory lifecycle. |
| ABI | All 60 package selectors installed exactly once; persistent factory union correct; forbidden capabilities absent; canonical IDs preserved. |
| Math | Independent exact controls for attribution, rounding, fee growth, allocations, and wide rational rate; no tolerance-based ownership assertions. |
| Projection | Complete output/state/domain parity, 512/513 boundaries, candidate isolation, protocol fees, tick transitions, and invalidation. |
| Custody | Native/ERC-20 receipts, reservations, settlement, payout/refund, terminal reset, and unbooked separation reconcile exactly. |
| Fallback | Every reason evidenced or independently proved unreachable; all nontriggers and second-candidate failures verified. |
| Security | Cross-facet callback/read matrix, actual pretransfer negatives, real FoT failure, disable behavior, and atomic rollback. |
| Runtime size | Every deployed facet, package, linked library, and optional fixed delegate fits the normal 24,576-byte runtime limit; constructor/initcode also meets the target’s normal limits. |
| Gas | Recorded target transaction and view-call budgets; actual worst-case measurements, including witness validation and two-candidate planning, satisfy them. |
| Regression | Focused shared/native/baseline compatibility checks and required hermetic integration pass; pre-existing failures remain separately identified. |

A 512-step algorithm is not automatically cheap enough to execute. Measure the planner, overlay management, state-witness validation, actual manager work, wrapper operations, and registry deployment separately and together.

## Evidence and implementation handoff

The later implementation report should contain:

- Changed production/test paths.
- Actual compiler configuration and artifact identities.
- Selector/interface/facet/Repo initialization manifest.
- A01–A70 ledger with suite, test, subcases, command, and result.
- Exact independent accounting/vector evidence.
- Fallback reachability witnesses or proofs.
- Runtime and initcode sizes for every deployed component.
- Gas results with target limits and fixture construction.
- Baseline comparison ledger.
- Unrun commands, pre-existing failures, and remaining integration limits.
- Reusable paths for subsequent stages: family TestBase, ledger, math, projector, planner, and declaration Behaviors.

Do not describe the family as complete while any required row is only planned, mocked, or inferred.

# Blockers and limits

## Release blocker: deployment gas envelope is not specified

**Requirement:** S1-QUOTE-01, S1-A48, S1-A70, completion criterion 6.  
**Evidence:** the admitted PRD requires deployment-normal gas/size feasibility, while the current default Foundry gas limit is `30,000,000,000`.

The implementation can proceed, but A70 cannot be approved against that test-headroom value. Before the release gate, record the intended deployment environment’s normal transaction/initcode/runtime limits and the supported view-call budget. Measure against those values without changing the 512/1,024 work bounds.

This is a release prerequisite, not a request to reopen the product’s economic choices.

## Engineering prerequisite: package Behavior helper

**Requirement:** S1-TEST-01 and canonical LR-7 testing guidance.  
**Evidence:** `Behavior_IFacet` exists; the named generic `Behavior_IDiamondFactoryPackage.sol` was not found in the inspected admitted trees.

Implement the proposed family-local package Behavior using actual canonical interfaces and independent controls. This is bounded test infrastructure, not a reason to bypass package declaration tests or modify unrelated Crane code.

## Explicit interpretation: unsupported preview precedence

**Requirements:** S1-SEC-01 versus the specific S1-P03/S1-OBS-01 mandate.

The plan gives both exact-output methods the unconditional `ExchangeOutNotAvailable()` result. Supported economic previews use `ReentrantOperation()` during an active family operation. Record this precedence in the implementation’s error manifest and tests; do not accidentally change unsupported Out behavior by applying a generic quote modifier.

## Unproved feasibility and reachability

No gas measurement, runtime compilation, projector differential test, or fallback reachability proof was performed here.

In particular:

- The multiword arithmetic approach is exact by construction but still requires implementation tests and gas measurement.
- The projector must be validated against the admitted canonical manager, including its precise modular arithmetic and cast behavior.
- A61’s four reasons must not be marked covered merely because a synthetic planner input can produce the enum.
- Code splitting is an implementation mechanism, not proof that all components already fit.
- Wrapper code/metadata validation cannot prove arbitrary wrapper behavior; use the canonical bound implementation and verify each actual one-for-one conversion.

I found no demonstrated contradiction requiring a new issuance equation, fee policy, genesis sink, fallback policy, route set, or oracle. The plan is executable within the revised product choices, subject to the explicit implementation and release evidence above.
