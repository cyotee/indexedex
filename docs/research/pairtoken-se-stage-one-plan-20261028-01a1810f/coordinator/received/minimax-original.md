# MiniMax planning contribution: coordinator archival receipt

Verbatim final response from Native task `st_01a18423`, initial planning assignment. No content corrections were applied in this archive.

---

# PairToken SE Stage One — Independent Implementation & Testing Plan Contribution

##1. Identity

**Member:** MiniMax · **Role:** council-member (initial planning assignment) · **Route:** `minimax/MiniMax-M3`, existing host adaptive setting.

I am contributing an **independent implementation and testing plan** for the revised PairToken Standard Exchange stage-one PRD. This is planning only. I have written no files, run no tests/builds/Git/deployments, spawned no subagents, and read no peer contributions, prior council reports, or private memory. Everything below is derived from the immutable PRD snapshot plus the admitted repository sources I read directly.

**Statement of limits before the plan:** this contribution is a *plan*, not an implementation. No gas number, runtime size, fuzz pass, or economic outcome in it is measured. Where I assert a code behavior, I cite the file I read it in. Where I could not verify, I say so and give the verification step.

---

## 2. Inputs and coverage

### 2.1 Authorities read (complete, not truncated)

| Input | Length | Integrity check I ran (read-only) |
|---|---|---|
| `docs/research/pairtoken-se-stage-one-plan-20261028-01a1810f/brief.md` | 163 lines | `shasum -a 256` → `e042ba161ee352517ea135c767c4311ddc443c6b458d8c8dabda15af41979e08` |
| `docs/research/pairtoken-se-stage-one-plan-20261028-01a1810f/inputs/PRD.md` | 1212 lines | `shasum -a 256` → `574ce6c03c0bc62f79a816e5a7775c831cb932082e0dd4bfe414fc1945ed7a7f` — **matches the hash the brief supplies** |
| `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md` | — | `cmp` against the snapshot → **byte-identical** |

I read the PRD in two bounded chunks to EOF and confirmed the second chunk ended at the final line of §12. The 70 acceptance rows S1-A01…S1-A70, the revised attribution rules (S1-ACC-06/07), and the conditional fallback (S1-EXIT-01) are all present and are treated as governing.

### 2.2 Admitted repository sources read

- **Rules:** `CLAUDE.md`, `.github/ASSISTANT_RULES.md`, `.github/ASSISTANT_CODING.md`, `.github/ASSISTANT_DEPLOYMENT.md`, `.github/ASSISTANT_TESTS.md`; `docs/agent/INDEXEDEX_AGENT_LAW.md` §§ *Testing Philosophy*, *Test Patterns*, *Deployment in IndexedEx*, *Vault DFPkg Requirements*; `foundry.toml` (profile law, `via_ir = false`, `optimizer_runs = 1`, fuzz `runs=16`, invariant `runs=16 depth=8`, `sizes=false`, `cache_path='cache_forge'`).
- **Baseline (behavioral reference):** `contracts/pairtoken-baseline/PairToken.sol`, `PairTokenMath.sol`, `interfaces/IPairTokenDependencies.sol` (all complete).
- **Baseline harness:** `test/foundry/spec/pairtoken-baseline/harness/PairTokenTestBase.sol` (complete) and `ScriptedDependencies.sol` (**signature inventory only** — `TraceRecorder`, `ScriptedERC20`, `ScriptedFactory`, `ScriptedFeeManager`, `ScriptedPoolManager` incl. `queueModify/queueSwap/setSlot0/setPosition/setWord/setFailure/setDuringUnlock`, `NativeRecipient`; bodies not read).
- **Shared facets and repos:** `lib/crane/contracts/tokens/ERC20/ERC20Facet.sol`, `ERC20Repo.sol`, `lib/crane/contracts/tokens/ERC2612/ERC2612Facet.sol`, `ERC2612Repo.sol`, `lib/crane/contracts/utils/cryptography/ERC5267/ERC5267Facet.sol`, `contracts/vaults/basic/MultiAssetBasicVaultFacet.sol`, `MultiAssetBasicVaultRepo.sol`, `MultiAssetBasicVaultTarget.sol`, `contracts/vaults/standard/MultiAssetStandardVaultFacet.sol`, `StandardVaultRepo.sol`, `MultiAssetStandardVaultTarget.sol`, `contracts/utils/LocalCreditLib.sol`, `contracts/interfaces/ISecurePullErrors.sol`, `contracts/interfaces/IBasicVault.sol`, `contracts/vaults/basic/IBasicVault.sol`, `contracts/interfaces/IStandardVault.sol`.
- **SE / SY surfaces:** `lib/crane/contracts/interfaces/IStandardExchangeIn.sol`, `IStandardExchangeOut.sol`, `IStandardExchangeErrors.sol`, `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol`, `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol`, `NativeStandardYieldDiscoveryTarget.sol`, `NativeStandardYieldPreviewTarget.sol`, `NativeStandardYieldQuoteBase.sol`, `contracts/vaults/standard/exchange/StandardExchangeInExecutionBase.sol`.
- **V4 port (the decisive ones):** `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol` (`getAmount0Delta`, `getAmount1Delta`, `getNextSqrtPriceFromInput`), `LiquidityAmounts.sol`, `TickMath.sol` (`minUsableTick`/`maxUsableTick`, `MIN_SQRT_PRICE`/`MAX_SQRT_PRICE`), `StateLibrary.sol` (signature inventory), `TransientStateLibrary.sol` (`isUnlocked`), `types/PoolId.sol` (`toId`), `types/Currency.sol`, `interfaces/IPoolManager.sol`, `PoolManager.sol` (§§88–130), `libraries/Pool.sol` (§§140–230), `libraries/Position.sol` (§§60–115), `libraries/FullMath.sol` (signature inventory).
- **Packaging / registry (context only):** `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol`, `...Component_FactoryService.sol`, `...Repo.sol`, `test/bases/TestBase_UniswapV4UpperLowerWingsStandardExchangeVault.sol`, `contracts/test/IndexedexTest.sol`, `contracts/registries/vault/VaultTypeUtils.sol`, `contracts/registries/vault/VaultRegistryVaultQueryTarget.sol` (grep), `contracts/registries/vault/VaultRegistryVaultRepo.sol` (grep), `contracts/interfaces/IVaultRegistryDisableQuery.sol`, `lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol` (grep), `lib/crane/contracts/utils/collections/sets/AddressSetRepo.sol` (§§1–120), `lib/crane/contracts/utils/BetterEfficientHashLib.sol` (partial).

### 2.3 Four findings that change the implementation shape

These came out of reading the actual Crane V4 port and the registry. They are not in the PRD and they drive WP design.

**(F1) Crane's V4 port realizes LP fees on a zero-delta "poke", but only for a non-empty position.**
`Pool.modifyLiquidity` (`lib/crane/.../v4/libraries/Pool.sol:185-192`) calls `position.update(liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128)` **unconditionally** — outside the `if (liquidityDelta != 0)` tick-update block. `Position.update` (`Position.sol:77-101`) computes `feesOwed = mulDiv(feeGrowthInside - feeGrowthInsideLast, liquidity, 2^128)` using the position's **pre-update** liquidity, then advances `feeGrowthInsideXLastX128`. `Position.update` reverts `CannotUpdateEmptyPosition` when `liquidityDelta == 0 && self.liquidity == 0`.
⇒ A zero-delta `modifyLiquidity` is a genuine fee-collection operation that realizes **the whole position's** accrued fees. This is the mechanism S1-ACC-01 / S1-OP-05 / S1-X16 call a "fee checkpoint". It must be a *real* manager call, and it must never be issued against an empty position (the PRD's "Never poke an empty position" is enforced by the manager, but the family must not rely on that — it must check `L > 0` first).

**(F2) `callerDelta` is `principalDelta + feesAccrued`; the baseline computes the principal cost backwards.**
`PoolManager.modifyLiquidity` (`PoolManager.sol:108-120`): `(principalDelta, feesAccrued) = pool.modifyLiquidity(...)` then `callerDelta = principalDelta + feesAccrued`. The baseline's `_add` (`contracts/pairtoken-baseline/PairToken.sol`) derives the added cost as `feesAccrued - callerDelta`, which against Crane's manager is `-(principal)` → **always ≤ 0 → `used0 = used1 = 0`**. The baseline's zap then computes `shares = min(MD(used0,…), MD(used1,…))` = 0 and reverts `MinShares()`. The baseline is only exercised against `ScriptedPoolManager`, whose `queueModify(callerDelta, feesAccrued)` lets the two be set independently — so this divergence was invisible to the baseline suite.
⇒ The family must compute **actual principal cost** as `principalDelta = callerDelta - feesAccrued` (per currency, signed), and must never read `feesAccrued` as a cost. This is precisely S1-ACC-06's "Keep actual principal, manager fee deltas, and locally paid/received amounts distinct" and S1-ACC-03's "Split manager `callerDelta = principalDelta + feesAccrued`". It is a **mandatory intentional deviation** in the comparison ledger, and it is the single highest-value thing this plan contributes.

**(F3) The factory installs exactly four base facets, and removes the fourth.**
`DiamondPackageCallBackFactory` (`lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol`) wires `ERC165_FACET`, the **diamond loupe** facet, `ERC8109_INTROSPECTION_FACET`, and a **temporary** `POST_DEPLOY_HOOK_FACET`; `postDeploy(address)` (L425-432) applies `postDeployFacetCuts()` to remove the hook.
⇒ A68's "no `diamondCut`" is satisfiable — the factory does **not** install a `diamondCut` facet on proxies. The final persistent loupe surface = package-owned selectors ∪ {ERC-165, loupe, ERC-8109}, exactly as S1-A06/A57 assume. **No blocker here**; the assumption holds on the code I read.

**(F4) The shared basic-vault Repo preserves insertion order, so PoolKey face order is achievable.**
`AddressSetRepo._add` (`lib/crane/contracts/utils/collections/sets/AddressSetRepo.sol`) `push`es onto `values` and never sorts. `MultiAssetBasicVaultRepo._initialize(address[] tokens)` therefore stores `[C0, C1]` in the order given, and `_reserves()` returns reserves in that same order.
⇒ S1-ARCH-05's "Keep `vaultTokens`, `vaultConfig.tokens`, and reserve arrays in PoolKey face order; do not reorder their stored list to calculate registry identity" is satisfiable: initialize in face order, and compute `contentsId` from a **separately sorted copy** (`keccak256(abi.encode(sortedFaces))`), matching the registry's `VaultRegistryVaultQueryTarget.calcContentsId` which is `abi.encode(tokens_._sort())._hash()`. **No blocker.**

### 2.4 One arithmetic identity that de-risks a whole PRD clause

I checked the baseline math against canonical V4 math symbol by symbol, because S1-ACC-01 demands "Preserve baseline interior results only where equivalent to canonical manager math":

| Baseline | Canonical V4 (Crane port) | Verdict |
|---|---|---|
| `PairTokenMath.A0down(a,b,L) = MD(L·2^96, b−a, b)/a` | `SqrtPriceMath.getAmount0Delta(a,b,L,false)` = `mulDiv(L·2^96, b−a, b)/a` | **bit-identical** |
| `A0up(a,b,L) = MU(L·2^96, b−a, b)/a (+1 if remainder)` | `getAmount0Delta(...,true)` = `divRoundingUp(mulDivRoundingUp(...), a)` | **both equal `ceil` of the exact value** (`ceil(ceil(y)/a) = ceil(y/a)` for integer `a`) |
| `A1down(a,b,L) = MD(L, |b−a|, 2^96)` | `getAmount1Delta(a,b,L,false)` = `mulDiv(L, |b−a|, 2^96)` | **bit-identical** |
| `A1up` | `getAmount1Delta(...,true)` | **identical** |
| `L0(a,b,x) = MD(x, MD(a,b,2^96), b−a)` | `LiquidityAmounts.getLiquidityForAmount0` = `mulDiv(x, mulDiv(a,b,2^96), b−a)` | **bit-identical** |
| `L1(a,b,y) = MD(y, 2^96, b−a)` | `getLiquidityForAmount1` = `mulDiv(y, 2^96, b−a)` | **bit-identical** |
| `Fit(p,a,b,x,y)` | `getLiquidityForAmounts` | **identical branch structure** |

⇒ The baseline's *interior* arithmetic is already canonical. The only arithmetic defect is the one the PRD already names: **S1-X13**. The baseline's `basket()` computes `A0down(price, T(tickUpper), L)` and `A1down(T(tickLower), price, L)` — it substitutes the *live price* for the *range boundary*. At `P ≤ lower` the canonical amount0 is `getAmount0Delta(lower, upper, L)` and at `P ≥ upper` the canonical amount1 is `getAmount1Delta(lower, upper, L)`. The baseline uses `P` in the numerator instead of `lower`/`upper`. So the family must implement `N_i(P,L)` with **explicit clamping**:

```
if (P <= sqrtLower)  → N0 = getAmount0Delta(sqrtLower, sqrtUpper, L, down), N1 = 0
if (P >= sqrtUpper)  → N0 = 0, N1 = getAmount1Delta(sqrtLower, sqrtUpper, L, down)
else                 → N0 = getAmount0Delta(P, sqrtUpper, L, down), N1 = getAmount1Delta(sqrtLower, P, L, down)
```

This single table is the source of truth for S1-ACC-01, S1-ACC-03, S1-ACC-07's `G_i`, and S1-QUOTE-02's `A_i`. All four consume it.

---

## 3. File / component map

All paths below are **proposed**. Nothing below exists today; the new family has no implementation. Every `contracts/...` path is new; every `lib/crane/...` path is an existing canonical file to be **reused unchanged**.

### 3.1 Proposed production tree

Root: `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/` (per S1-ARCH-01). Type prefix `UniswapV4PairTokenStandardExchangeVault`.

| # | Proposed file | Layer | Responsibility |
|---|---|---|---|
| 1 | `interfaces/IUniswapV4PairTokenStandardExchangeVault.sol` | interface | The S1-API-05 typed ABI verbatim (16 family methods + `depositPair`/`previewDepositPair`/`redeemPair`/`previewRedeemPair`/`donate`/`compound`/queries/`previewWithdrawalMode`/`previewZapCredit`), the enums `WithdrawalMode {FullCompound, CollectOnly}` and `MaintenanceReason {None, MaintenanceWorkLimit, MaintenancePriceLimit, MaintenanceLiquidityLimit, MaintenanceDeltaLimit}`, and the family errors `ReentrantOperation()`, `ManagerAlreadyUnlocked()`, `EconomicStateChanged()`, `InvalidAccountingState()`, `ZeroPayout()`, `QuoteWorkExceeded(uint256,uint256)`, `IssuanceDisabled()`. |
| 2 | `interfaces/IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol` | interface | `PkgInit` and `PkgArgs` **on the interface** (Crane rule; `lib/crane/contracts/factories/diamondPkg/IDiamondFactoryPackage.sol` + `CLAUDE.md` §"Deploy path reminder"), plus the package surface (`packageName`, `facetInterfaces`, `facetAddresses`, `facetCuts`, `diamondConfig`, `calcSalt`, `processArgs`, `initAccount`, `postDeploy`, `deployVault`). `PkgArgs` = `{PoolKey poolKey, address rateAsset, string name, string symbol, uint16 maxZapBps, int24 maxZapTickMove}`. `PkgInit` = `{IFacet[] facets, IPoolManager poolManager, IVaultRegistryDeployment registry, IVaultFeeOracleQuery oracle, address wrappedNative}`. |
| 3 | `UniswapV4PairTokenStandardExchangeVaultTypes.sol` | lib | Internal structs: `Plan`, `Candidate`, `Snapshot`, `LedgerState`, `SwapStep`, `FeeCheckpoint`. Enums live in the interface (S1-API-05) and are re-exported, not redefined. |
| 4 | `UniswapV4PairTokenStandardExchangeVaultRepo.sol` | repo | Family storage. `STORAGE_SLOT = keccak256(abi.encode("indexedex.vaults.standard.exchange.uniswap.v4.pairToken"))` (ERC1967-form, distinct from Wings' `keccak256("indexedex.vaults.standard.exchange.uniswap.v4.upperLowerWings")`). Fields: `initialized`, `busy`, `callbackCommitment`, `callbackKind`, `poolManager`, `poolKey`, `rateAsset`, `wrappedNative`, `tickLower`, `tickUpper`, `maxZapBps`, `maxZapTickMove`, `rateAssetDecimals`, `supply`-adjacent share state stays in `ERC20Repo`, `booked0/booked1`, `pending0/pending1`, `reservedExit0/reservedExit1`, `reservedRefund0/reservedRefund1`, `positionFeeGrowthInside0Last/1Last`, `planNonce`. |
| 5 | `UniswapV4PairTokenStandardExchangeVaultMath.sol` | lib | (a) `mulDivFloor/mulDivCeil` with **explicit** overflow error; (b) clamped `removablePrincipal(P, L)` per §2.4; (c) `affordableLiquidity(...)` (canonical `LiquidityAmounts`); (d) the S1-QUOTE-02 exact single-floor valuation (§5.4); (e) `genesisShares(a0,a1)` = `floor(sqrt(a0·a1))` with checked product. |
| 6 | `UniswapV4PairTokenStandardExchangeVaultAccounting.sol` | lib | S1-ACC-06 ledger: custody categories, fee checkpoints (F1), `G_i` growth, `qCredit` (S1-ACC-07), proportional allocation (S1-ACC-03), share/non-dilution predicate. |
| 7 | `UniswapV4PairTokenStandardExchangeVaultPlanner.sol` | lib | S1-QUOTE-01 exact-view projector (§5). |
| 8 | `UniswapV4PairTokenStandardExchangeVaultManager.sol` | lib | V4 interaction: `unlock`-wrapped swap / modify / fee-checkpoint poke; settlement (ERC-20 `sync`/`transfer`/`settle`, native `sync`/`settle{value}`/`take`); principal-vs-fee split (F2); `StateLibrary` reads. |
| 9 | `UniswapV4PairTokenStandardExchangeVaultNative.sol` | lib | Wrapped-native adapter + native custody: `IWETH` (`lib/crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol`) `deposit`/`withdraw`; native `sync(Currency.wrap(address(0)))` before every native debt (S1-X18); checked value transfer without a fixed stipend (S1-NATIVE-01). |
| 10 | `UniswapV4PairTokenStandardExchangeVaultExecutionTarget.sol` | target | All money methods + internal seams (`_standardRoute`, `_redeemVaultHeld`, `_entryCore`, `_exitCore`, `_compoundCore`). |
| 11 | `UniswapV4PairTokenStandardExchangeVaultCallbackTarget.sol` | target | `unlockCallback` with payload commitment + operation-kind + pool-manager authentication (S1-SEC-01, S1-X11). |
| 12 | `UniswapV4PairTokenStandardExchangeVaultQueryTarget.sol` | target | Family queries + all previews + `previewWithdrawalMode` + `previewZapCredit` + the read-class guard (S1-SEC-01). |
| 13 | `UniswapV4PairTokenStandardExchangeVaultSYTarget.sol` | target | SY adapter over `NativeStandardYieldTarget` / `NativeStandardYieldDiscoveryTarget` / `NativeStandardYieldPreviewTarget` seams, overriding the blanket nonzero-`msg.value` rejection for native only (S1-API-03). |
| 14 | `UniswapV4PairTokenStandardExchangeVaultExecutionFacet.sol` | facet | `depositPair`, `redeemPair`, `donate`, `compound`, SE `exchangeIn`, SE `exchangeOut` (reverting). |
| 15 | `UniswapV4PairTokenStandardExchangeVaultSingleTokenFacet.sol` | facet | The two zap directions + the two single-token exits, split out of #14 purely for code size. |
| 16 | `UniswapV4PairTokenStandardExchangeVaultCallbackFacet.sol` | facet | `unlockCallback` only. |
| 17 | `UniswapV4PairTokenStandardExchangeVaultQueryFacet.sol` | facet | Queries + previews + `previewWithdrawalMode` + `previewZapCredit`. |
| 18 | `UniswapV4PairTokenStandardExchangeVaultSYFacet.sol` | facet | The 16 SY methods; **inherits** the token interfaces without reinstalling their selectors. |
| 19 | `UniswapV4PairTokenStandardExchangeVaultDFPkg.sol` | pkg | `IDiamondFactoryPackage` + `IStandardVaultPkg`. `initAccount` performs all Repo initialization (§3.4). |
| 20 | `UniswapV4PairTokenStandardExchangeVaultComponent_FactoryService.sol` | service | CREATE3 deploys of facets #14–#18 via `ArtifactCreationCode.creationCode(...)`, mirroring the Wings `*_Component_FactoryService`. |

**Facet-split rule (code-size strategy).** Five family facets + five reused canonical facets = the package cut. `forge build --sizes` is the gate (the repo sets `sizes = false`, so the gate must pass `--sizes` explicitly). If any facet exceeds EIP-170's 24,576 bytes, the relief valve is the **query facet** (previews are pure and can move wholesale); the second relief is the SY facet; the execution facet is the last thing to split, because splitting it changes the internal-call graph that S1-ARCH-01 forbids ("Keep shared accounting/settlement logic internal to the family rather than self-calling public proxy methods with changed caller semantics").

### 3.2 Canonical reuse map (verified against the files)

**Package-owned reused facets — exactly 20 selectors (S1-ARCH-04), verified from each `facetFuncs()`:**

| Facet | Path | Interfaces | Selectors |
|---|---|---|---|
| ERC-20 | `lib/crane/contracts/tokens/ERC20/ERC20Facet.sol` | `IERC20`, `IERC20Metadata`, `IERC20Metadata ^ IERC20` (3) | 9: `name symbol decimals totalSupply balanceOf allowance approve transfer transferFrom` |
| ERC-2612 | `lib/crane/contracts/tokens/ERC2612/ERC2612Facet.sol` | `IERC20Permit` (1) | 3: `permit nonces DOMAIN_SEPARATOR` |
| ERC-5267 | `lib/crane/contracts/utils/cryptography/ERC5267/ERC5267Facet.sol` | `IERC5267` (1) | 1: `eip712Domain` |
| Basic vault | `contracts/vaults/basic/MultiAssetBasicVaultFacet.sol` | `IBasicVault` (1) | 3: `vaultTokens reserveOfToken reserves` |
| Standard vault | `contracts/vaults/standard/MultiAssetStandardVaultFacet.sol` | `IStandardVault` (1) | 4: `vaultFeeTypeIds contentsId vaultTypes vaultConfig` |
| | | | **9+3+1+3+4 = 20** |

`ERC20PermitFacet` is **not** installed (its combined selectors overlap). `StandardVaultTarget` (the empty implementation) is **not** installed — the functional shared implementation is `MultiAssetStandardVaultTarget` via its facet.

**Factory-owned — excluded from package inputs, addresses, cuts, and `facetInterfaces()`:** ERC-165, diamond loupe, ERC-8109, and the temporary post-deploy hook (F3). The final proxy's persistent selector set is the **disjoint union** of package-owned and factory-owned sets.

**Other canonical code to reuse unchanged (not facets, no selectors):**

| Need | Path | Note |
|---|---|---|
| V4 state reads | `lib/crane/.../v4/libraries/StateLibrary.sol` | `getSlot0`, `getLiquidity`, `getPositionLiquidity`, `getFeeGrowthInside`, `getTickInfo` — use instead of raw `extsload` offsets (S1-ACC-01) |
| Tick bounds | `lib/crane/.../v4/libraries/TickMath.sol` | `minUsableTick(spacing)`/`maxUsableTick(spacing)`; `MIN_SQRT_PRICE + 1` / `MAX_SQRT_PRICE − 1` for swap limits |
| Pool id | `lib/crane/.../v4/types/PoolId.sol` | `toId` |
| Amount math | `lib/crane/.../v4/libraries/SqrtPriceMath.sol`, `LiquidityAmounts.sol`, `FullMath.sol` | §2.4 |
| Swap stepping | `lib/crane/.../v4/libraries/SqrtPriceMath.sol::getNextSqrtPriceFromInput` | planner step |
| Unlock state | `lib/crane/.../v4/libraries/TransientStateLibrary.sol` | `isUnlocked(manager)` → `ManagerAlreadyUnlocked()` |
| Currency | `lib/crane/.../v4/types/Currency.sol` | `Currency.wrap/unwrap` |
| Manager ABI | `lib/crane/.../v4/interfaces/IPoolManager.sol` | `unlock/modifyLiquidity/swap/sync/settle/take` |
| Wrapped native | `lib/crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol` | `deposit`/`withdraw` |
| Unbooked credit | `contracts/utils/LocalCreditLib.sol` | `available(balance, booked)`, `budget(available, max)`, `requirePretransferCaller` |
| Pretransfer errors | `contracts/interfaces/ISecurePullErrors.sol` | `TransferDeltaInsufficient`, `EOAPretransferNotAllowed` |
| SE errors | `lib/crane/contracts/interfaces/IStandardExchangeErrors.sol` | `DeadlineExceeded`, `MinAmountNotMet`, `InvalidRoute` |
| SE Out errors | `lib/crane/contracts/interfaces/IStandardExchangeOut.sol` | `ExchangeOutNotAvailable()` |
| SY ABI + events | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol` | 16 methods + `Deposit`/`Redeem`/`ClaimRewards` |
| SY seams | `contracts/vaults/standard/sy/NativeStandardYield*.sol`, `contracts/vaults/standard/exchange/StandardExchangeInExecutionBase.sol` | `_standardRoute`, `_redeemVaultHeld`, `_previewExchangeIn` |
| Share/repo | `ERC20Repo`, `ERC2612Repo`, `EIP712Repo`, `MultiAssetBasicVaultRepo`, `StandardVaultRepo` | §3.4 |
| Registry identity | `contracts/registries/vault/VaultRegistryVaultQueryTarget.sol::calcContentsId` | `abi.encode(sortedTokens)._hash()` |
| Fee-type packing | `contracts/registries/vault/VaultTypeUtils.sol` | **not used for ids**; stage one declares `bytes32(0)` |

### 3.3 Proposed test tree

`test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/pairToken/`

- `harness/TestBase_UniswapV4PairTokenStandardExchangeVault.sol` — real fixture (below).
- `harness/PairTokenSEOracle.sol` — independent wide-integer control (Python-generated vectors, mirrored in Solidity *without* copying the implementation's formulas).
- `harness/PairTokenSEComparisonLedger.sol` — the four-bucket ledger (preserved / intentional deviation / unsupported scope / new capability).
- Suites `T1`…`T20` as tabulated in §6.
- `fixtures/math/` — JSON vectors (shape mirrors `test/foundry/spec/pairtoken-baseline/fixtures/math.json`).
- `math-oracle.py` — Python wide-integer oracle (independent of Solidity).

The baseline harness stays **untouched** and separate: `test/foundry/spec/pairtoken-baseline/harness/PairTokenTestBase.sol` + `ScriptedDependencies.sol` are read-only inputs for comparison tests. The family never subclasses, injects storage into, or etches the SUT.

### 3.4 Initialization ownership (single, explicit owner: `DFPkg.initAccount`, delegatecall on the proxy)

`initAccount` runs once; `Repo.initialized` guards re-entry (`AlreadyInitialized`).

| Target | Call | Value |
|---|---|---|
| `ERC20Repo` | `ERC20Repo._initialize(name, symbol, 18)` | configured name/symbol; **18** decimals; supply starts 0 |
| `EIP712Repo` | `EIP712Repo._initialize(name, "1")` | domain version `"1"`; permit and `eip712Domain` must resolve to the **diamond** |
| `ERC2612Repo` | *(none)* | nonces start at 0; never seeded |
| `MultiAssetBasicVaultRepo` | `_initialize([C0, C1])` | PoolKey face order (F4) |
| `StandardVaultRepo` | `_initialize(oracle, bytes32(0), facetInterfaces(), keccak256(abi.encode(sortedFaces)))` | **zero** fee-type ids; deduped package-owned interface ids; contents id from the **sorted copy** |
| `VaultFeeOracleQueryAwareRepo` | `_initialize(oracle)` | mirrors the Wings package; needed for registry/fee-oracle reads |
| Family `Repo` | `_initialize(...)` | manager, key, rateAsset, wrappedNative, ticks (`TickMath.minUsableTick/maxUsableTick`), `maxZapBps`, `maxZapTickMove`, cached `rateAssetDecimals`, `initialized = true` |

**Not** initialized here: anything on a facet address; anything owned by the factory (ERC-165, loupe, ERC-8109, post-deploy hook).

**Validation performed in `processArgs`/`initAccount`** (S1-ARCH-03): ordered distinct currencies (`c0 < c1`); `currency0` may be `address(0)`; every nonzero currency has code; `currency1` nonzero; `0 < tickSpacing <= 32767`; `fee <= 1_000_000` and static (no dynamic-fee flag); `hooks == address(0)`; pool initialized with nonzero sqrt price; `rateAsset ∈ {C0, C1}`; the two ERC-20 faces **distinct** (so a native/that-same-wrapper pool is rejected explicitly); wrapped-native binding valid when used and 18-decimal 1:1; `maxZapBps ∈ [1, 10000]`; `maxZapTickMove >= 0`; no self-referential currencies; required nonzero infrastructure and facets. **No** token-decimals allowlist, no token-behavior allowlist, no issuer-blacklist detector.

---

## 4. Implementation stages (dependency-ordered)

Each package is a minimal coherent increment with a prerequisite, concrete actions, and an **observable** exit criterion.

| WP | Title | Prereq | Implementation actions | Observable exit evidence |
|---|---|---|---|---|
| **WP0** | Precondition verification (read-only) | PRD | Verify, in the implementer's checkout, the four items this plan could not settle: (i) `Pool.sol` swap-step extraction viability for the planner (§5.1); (ii) canonical `positionId` derivation (`Position.getPositionId` vs the baseline's `keccak256(abi.encodePacked(owner,tickLower,tickUpper,salt))`); (iii) the registry's exact `calcContentsId` byte-for-byte equality with `keccak256(abi.encode(sortedFaces))`; (iv) `DiamondPackageCallBackFactory` base-facet set (already read, F3) and the `IVaultRegistryDeployment.deployVault` signature. | A one-page "Preconditions" note attached to the implementation report, with the exact file/line for each of (i)–(iv) and a go/no-go. **Any "no-go" on (i) is a stop-and-raise, not a design pivot.** |
| **WP1** | Math library + independent oracle | WP0 | `UniswapV4PairTokenStandardExchangeVaultMath.sol`: `mulDivFloor/mulDivCeil` (explicit `MathOverflow()`), clamped `removablePrincipal`, `affordableLiquidity`, `genesisShares`, and the §5.4 valuation primitives. Write `math-oracle.py` (Python `int`, no Solidity formulas) and `fixtures/math/*.json`. | `T17` green: family math == oracle on ≥2000 adversarial vectors (P at `MIN_SQRT_PRICE`, `MAX_SQRT_PRICE`, exact boundaries; `A0/A1 ∈ {0,1,max}`; `S ∈ {1, 1e18}`); family `mulDivFloor` == `PairTokenMath.MD` on all baseline vectors; a differential test asserts family `removablePrincipal` == the manager's own `getAmount0Delta/getAmount1Delta` receipts on a live pool. |
| **WP2** | Family Repo, types, error surface | WP1 | Repo #4, Types #3, family interface #1 (ABI + enums + errors), DFPkg interface #2. | `T3` manifest test green: every S1-API-05 signature present with the exact signature strings; enum ordinals asserted (`FullCompound=0`, `CollectOnly=1`; `None=0`, `MaintenanceWorkLimit=1`, `MaintenancePriceLimit=2`, `MaintenanceLiquidityLimit=3`, `MaintenanceDeltaLimit=4`); all seven family errors declared. |
| **WP3** | Manager interaction + native adapter | WP1, WP2 | Manager lib #8 (swap/modify/poke, principal-vs-fee split per F2, settlement), native lib #9 (`sync` reset before every native debt, `settle{value}`, `take`, checked value transfer). | `T11` native settlement tests green against the **real** `PoolManager`: deltas close to zero, no ERC-20 call targets `address(0)`, native sync explicitly reset after an outstanding ERC-20 sync, `settle` reported amount validated. |
| **WP4** | Ledger + accounting | WP2, WP3 | Accounting lib #6: custody categories, the category invariant `booked + pending + reservedExit + reservedRefund + unbooked == rawCustody` per currency, fee checkpoint (F1), `G_i`, `qCredit`, proportional allocation, non-dilution predicate. | `T18` invariant green at every operation boundary; `T6` non-dilution fuzz green with an independent wide-integer control. |
| **WP5** | Exact-view planner | WP1, WP4 | Planner lib #7 (§5). | `T9` parity green: for every route and both compound modes, the preview's integer output equals the executed output **exactly** from identical state; `T9` step-budget tests green at 512/513; differential test vs the real manager green (§5.1). |
| **WP6** | Execution + callback targets | WP3, WP4, WP5 | Targets #10, #11. S1-SEC-01 guard; callback payload commitment `keccak256(abi.encode(operation, payload))` committed before each unlock and consumed once at callback entry; `TransientStateLibrary.isUnlocked` pre-check → `ManagerAlreadyUnlocked()`. | `T14` green: authentic callback succeeds; wrong manager, unsolicited payload, replay, nested/cross-facet callback all revert; already-unlocked context reverts before any nested unlock. |
| **WP7** | Facets + query + SY | WP6 | Facets #14–#18, query target #12, SY target #13. Read-class policy: economic queries revert `ReentrantOperation()` during an operation; `IBasicVault` returns the last committed snapshot; canonical token/domain reads keep canonical behavior. | `T3`/`T15` green:20 reused selectors + all family selectors callable on the live proxy; loupe == disjoint union; all 16 SY methods installed; no duplicate selectors; no second receipt token. |
| **WP8** | Package + factory service | WP2, WP7 | DFPkg #19 (with `initAccount` per §3.4, `calcSalt`, `processArgs` restricted to the registry, `deployVault` via the registry), factory service #20. | `T1`/`T2` green: registered deploy works through `indexedexManager.deployPkg`; identical args predict the same address; each immutable argument changes identity; re-init, direct misuse, wrong-registry processing, and invalid components all revert. |
| **WP9** | Real fixture + behaviors | WP8 | `TestBase_UniswapV4PairTokenStandardExchangeVault` (§5.5), `Behavior_*` libraries for the package/facet/standard declarations. | The fixture deploys a real `PoolManager` via `create3Factory.create3WithArgs(ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"), abi.encode(address(this)), keccak256("PairTokenSE.PoolManager"))` and a real registered package; a smoke test proves the diamond answers `name()/decimals()/poolKey()/localReserves()`. |
| **WP10** | Acceptance suites T1–T20 | WP9 | All suites in §6, including the baseline comparison ledger suite and the 70-row mapping. | Every S1-A01…S1-A70 row has a **green, named** test; the run log records the test name for each row. |
| **WP11** | Gates, adversarial pass, report | WP10 | Run §7 gates; run the family against the `indexedex-adversarial-testing` catalog (donation, reentrancy, pretransfer, proxy-surface); produce the implementation report. | Report records: deviations (four-bucket ledger), runtime sizes, exact commands and outputs, remaining integration limits, and the reusable paths for later stages (§11). |

**Sequencing note.** WP4 (ledger) does **not** depend on WP5 (planner) — the accounting is executable without the projector. WP5 depends on WP4 only for the snapshot type. This lets the accounting and the non-dilution proof (S1-A15/S1-A46) land before the highest-risk component (the planner), so a planner failure cannot block the ownership proof.

---

## 5. Exact implementation approach for the five hard parts

### 5.1 Operation ledger (S1-ACC-06) — storage and invariant

Per pool currency `i ∈ {0,1}`, four stored quantities plus one derived:

```
stored: booked_i        // incumbent idle attributable to shareholders pending_i      // caller inventory reserved for the active operation
         reservedExit_i // exit allocation reserved to the withdrawing holder
         reservedRefund_i
derived: unbooked_i = rawCustody_i - (booked_i + pending_i + reservedExit_i + reservedRefund_i)
rawCustody_0 = (native leg) ? address(this).balance : IERC20(c0).balanceOf(address(this))
rawCustody_1 = IERC20(c1).balanceOf(address(this))
```

Invariant asserted at every commit boundary: `booked + pending + reservedExit + reservedRefund + unbooked == rawCustody`. Categories are disjoint; moving a payout out of the book decrements `booked_i` **and** the corresponding reservation in the same step.

Wrapped-native handling: the wrapper is a **presentation adapter**, never an extra asset. When the native leg is wrapped for an SE route, `rawCustody` for that leg is *replaced* by the wrapped balance one-for-one — the count is not incremented. `vaultTokens()`/`vaultConfig.tokens` report `[C0, C1]` (the ERC-20 faces) while `localReserves()`/`basket()`/`poolKey()` keep raw-currency identity.

Transition table (each row is exactly one ledger mutation):

| Transition | Ledger effect | Manager effect |
|---|---|---|
| Pull / authenticated pretransfer | `pending_i += observed receipt` | none |
| Fee checkpoint (F1) | `booked_i += realized fee_i` | 0-delta `modifyLiquidity` → `take` |
| Compound swap | `pending`/`booked` debit the spent leg; `booked_i += swap credit` | `swap` |
| Compound add | `booked_i -= principal cost`, `booked_i += residual` | `modifyLiquidity(+dL)` |
| Entry swap | spends and receives **only** `pending` | `swap` |
| Entry add | `pending_i -= principal cost` (F2: `principalDelta = callerDelta − feesAccrued`) | `modifyLiquidity(+dL)` |
| Mint | `ERC20Repo._mint(recipient, q)`; `booked_i += accepted principal + residual` | — |
| Exit allocation | `booked_i -= allocated idle`; `reservedExit_i = allocation` | — |
| Exit removal | `reservedExit_i += principal proceeds` | `modifyLiquidity(−dL)` |
| Exit sale | spends **only** `reservedExit`; output stays in `reservedExit` | `swap` |
| Native unwrap/wrap | replace reserved representation one-for-one | `IWETH.withdraw`/`deposit` |
| Payout/refund | spend the matching reservation | — |
| Commit | publish `MultiAssetBasicVaultRepo._updateReserve` for both faces; clear reservations; release guard | — |

### 5.2 Fee checkpoints (S1-ACC-01, S1-OP-05, S1-X16)

A **fee checkpoint** is a real zero-delta `modifyLiquidity` (F1). It:
1. is issued only when `positionLiquidity() > 0` (the manager reverts `CannotUpdateEmptyPosition` otherwise);
2. realizes the **whole position's** accrued fees (F1: `Position.update` computes fees on the pre-update liquidity);
3. advances `feeGrowthInsideXLast`, so any **subsequent** removal returns `feesAccrued == 0`.

Required checkpoint order per operation:

- **Deposit / zap / standalone compound**: checkpoint → ratio swap → *final* checkpoint (only if the position is non-empty and fees grew during the swap) → reuse; the final checkpoint is **non-recursive** (no re-swap).
- **Zap entry**: checkpoint (pre-entry) → caller's swap → **checkpoint again** (entry-swap fees belong to incumbents) → freeze the post-swap incumbent snapshot for S1-ACC-07 → caller's add → mint.
- **Exit**: checkpoint → allocate → remove (now `feesAccrued == 0`, so no whole-position fee receipt can be mistaken for the partial holder's principal, per S1-ACC-03) → optional sale.

Because the checkpoint realizes the *whole* position's fees into custody as incumbent idle, S1-ACC-03's proportional split is automatic: `idle_iAllocated = floor(B_i · s / S)` distributes the checkpointed fees pro rata.

Independent read of the same quantity, used by S1-QUOTE-02 and by the planner, is
`F_i = floor(L · (insideGrowth_i − insideGrowthInsideLast_i) / 2^128)` with modular subtraction — exactly `Position.update`'s formula (`Position.sol:94-97`). The family stores `insideGrowthInsideLast_i` itself so that both the manager path and the view path agree.

**Deliverable correction this forces (F2).** The family's principal cost on an add is `principalDelta = callerDelta − feesAccrued` per currency (signed). The baseline's `fees − callerDelta` is inverted for Crane's manager. This must appear in the comparison ledger as an **intentional deviation**, and the ledger must state that the baseline's own suite never exercised it because `ScriptedPoolManager.queueModify` allows the two deltas to be set independently.

### 5.3 Caller-attributed issuance (S1-ACC-07) and proportional exits (S1-ACC-03)

**S1-ACC-07**, evaluated at the frozen post-checkpoint snapshot `(S*, P*, L*, B*_0, B*_1)`:

```
R_i = removablePrincipal_i(P*, L*) + B*_i          // per §2.4 clamping
G_i = removablePrincipal_i(P*, L* + dL) − removablePrincipal_i(P*, L*)
paired:  C_i = G_i + J_i        (J_i = caller inventory left after paying actual principal costs)
zap:     C_i = G_i             (J_i = leftover caller inventory, booked with no extra shares)
qCredit = min over i with R_i > 0 of floor(S* · C_i / R_i)
paired q = min(qQuote, qCredit); zap q = qCredit
```

Implementation notes:
- `G_i` is computed at the **frozen** price `P*` using the *same* clamping table as `removablePrincipal`, with `L* + dL` — so `G_i ≥ 0` always, and `G_i` is the removable-principal growth, **not** the gross tokens spent. The manager charges `ceil` amounts (F1: `getAmount0Delta(..., roundUp=true)`); the difference between the charged principal and `G_i` is the entrant's rounding cost, borne by the entrant (S1-ACC-07: "addition rounding costs are borne by the entrant rather than hidden in incumbent reserves"). The residual `J_i` captures exactly the caller's unspent inventory.
- The acceptance predicate is checked with exact rationals: `q·R_i ≤ S·C_i` for every `i` with `R_i > 0`, using a wide-integer control (`T6`), never a truncated display value.
- `qQuote` is **not** re-selected after the cap: "Do not rerun accepted-input selection after the final rounding cap." The final minimum is checked against `q`, never `qQuote` (S1-A64).
- A zero-`R_i` leg imposes no denominator constraint and earns no share credit; if both `R_i` are zero → `InvalidAccountingState()`.

**S1-ACC-03** (proportional exit), after the selected maintenance and the final checkpoint:

```
liquidityRemoved = floor(L · s / S)
idle0Allocated   = floor(B0 · s / S)
idle1Allocated   = floor(B1 · s / S)
```

- Burn `s` **before** removal.
- `principal` proceeds come from the manager delta **after** subtracting fees (F2); with the checkpoint already taken, `feesAccrued == 0` and `callerDelta` is pure principal.
- Payout = allocated idle + principal proceeds; a positive-share burn with zero total payout → `ZeroPayout()`.
- One-sided positive payout is valid; both-sided zero is not.
- Terminal (`s == S`): remove all liquidity, pay **all** booked assets, and assert `S == 0`, `L == 0`, `booked0 == booked1 == 0` afterwards; every receipt generated by the terminal operation is paid to that holder; unbooked balances are neither paid nor adopted.

### 5.4 S1-QUOTE-02 — exact single-floor rational valuation (no unsafe intermediate overflow)

**Target quantities** (raw units; `r = P / 2^96`):

```
value in token1 units: V1 = A1 + floor(A0 · r²) = A1 + floor(A0 · P² / 2^192)
value in token0 units: V0 = A0 + floor(A1 / r²) = A0 + floor(A1 · 2^192 / P²)
exchangeRate           = floor(V · 1e18 / S)          (raw rate-asset units per 1e18 raw share units)
```
where `A_i = N_i(P,L) + B_i + F_i` (removable principal + booked idle + current claimable fee, each included once).

**The overflow problem.** `P²` is up to 2^320 and `A0 · P²` up to 2^576 — a naive `P*P` overflows `uint256` at `P > 2^128`. The PRD forbids substituting two sequential floors.

**Lemma that makes one primitive sufficient.** If the final value is representable (`V < 2^256`), then `A0 · P² < 2^448` and `A1 · 2^192 < 2^448`. *Proof:* `V ≤ A0·P²/2^192` ⇒ `A0·P² ≥ V·2^192`; representability bounds the numerator only from below, so instead reason directly: `V = floor(A0·P²/2^192) < 2^256` ⇒ `A0·P²/2^192 < 2^256 + 1` ⇒ `A0·P² < 2^448 + 2^192 < 2^449`. ∎ So **both numerators fit in 512 bits whenever the answer fits in 256 bits**. One 512/512 → 256 division primitive therefore serves both directions, and the overflow case is exactly the "mathematically unrepresentable" case the PRD says must revert explicitly.

**Recommended implementation** — a small `WideMath` inside the family math library (or a new `contracts/utils/math/WideMath.sol` if the coordinator prefers a shared location):

```
mul512x256(uint256[2] a, uint256 b) -> uint256[3]   // 512 x 256 -> 768, schoolbook + carry
div512by512(uint256[2] num, uint256[2] den) -> (uint256 q, bool overflow)   // one restoring long division
mulDivFloor(uint256 a, uint256 b, uint256 c) -> uint256   // 512-bit mulDiv with EXPLICIT overflow error
```

Direction 1 (token1 units):
```
p2 = mul512x256(mul512x256([A0,0], P), P) // 768-bit product; limbs 2 must be 0 else overflow
num  = [p2[1], p2[0]]                             // low 512 bits
den  = [0, 1 << 192]                              // 2^192
(q, ov) = div512by512(num, den) // q = floor(A0·P²/2^192)
V1 = A1 + q
```
Direction 2 (token0 units):
```
num  = [A1 >> 64, (A1 << 192)]                    // A1 · 2^192, exactly 2 limbs
den  = [P2hi, P2lo]                               // P², 2 limbs (P² < 2^320)
(q, ov) = div512by512(num, den)                   // q = floor(A1·2^192/P²)
V0 = A0 + q
```
Then `exchangeRate = mulDivFloor(V, 1e18, S)`, reverting `ValueOverflow()` if the rate does not fit.

**Why this satisfies "single floor, no sequential floors".** The numerator is an **exact** integer product (no truncation anywhere in the multiply), and exactly one division with truncation is applied at the end. `floor(floor(A0·P/2^96)·P/2^96)` is never computed; the discarded bits are carried in the exact numerator.

**Alternative (offered, with proof, not recommended as primary).** A cheaper token1-direction-only formulation using the existing 512-bit `mulDiv`: let `q1 = floor(A0·P/2^96)`, `r1 = (A0·P) mod 2^96`, `q2 = floor(q1·P/2^96)`, `r2 = (q1·P) mod 2^96`, `s = (r1·P) >> 96`, `t = (r1·P) mod 2^96`. Then
`floor(A0·P²/2^192) = q2 + ((r2 + s) >> 96)`, because the residual fraction `(u mod 2^96)/2^96 + t/2^192 < 1` with `u = r2 + s`. This is exact, but it serves only the token1 direction and needs a remainder-carrying `mulDiv` variant; the `div512by512` route covers both directions with one primitive and one proof, so it is the recommendation.

**Controls required.**
- An independent Python wide-integer oracle (`math-oracle.py`) that computes `floor(A0·P²/2^192)` and `floor(A1·2^192/P²)` with Python `int` — no Solidity formula is copied.
- A property test asserting family == oracle on adversarial vectors: `P ∈ {MIN_SQRT_PRICE, MAX_SQRT_PRICE, exact lower/upper boundary, interior}`; `A0,A1 ∈ {0,1,2,1e18,2^200,2^255}`; `S ∈ {1, 1e18}`; and rate assets with 6/8/18 decimals.
- The PRD's own worked example asserted literally: `Vraw = 1e6`, `S = 1e18`, 6-decimal rate asset ⇒ `exchangeRate == 1e6`, and `syToAsset(rate, shares)` returns **raw** asset units (`1e6`), never `1e18`.
- Zero supply ⇒ `exchangeRate == 0`; no 1:1 bootstrap price is invented.
- The rate is **never** an input to S1-ACC-02 or S1-OP-02 issuance. The public query interface must state the distinction (accounting value vs withdrawal-and-sale proceeds).

### 5.5 Exact-view projector (S1-QUOTE-01)

**Architecture — copied state, never storage mutation.**

`PlannerState` is a memory struct seeded from live reads:

| Copied field | Source |
|---|---|
| `slot0` (sqrtPriceX96, tick, protocolFee, lpFee) | `StateLibrary.getSlot0` |
| active `liquidity` | `StateLibrary.getLiquidity` |
| tick bitmap words + per-tick `liquidityGross/liquidityNet/feeGrowthOutside` | `StateLibrary.getTickInfo` + `Extsload` word reads |
| global `feeGrowthGlobal0/1` | `StateLibrary` |
| position info (liquidity, `feeGrowthInside0/1LastX128`) | `StateLibrary.getPositionInfo` / `getPositionLiquidity` |
| local ledger (booked idle, supply, checkpoints) | family Repo |
| pool config (fee, tickSpacing, currencies) | family Repo |

Transitions implemented as pure functions on the copy: `applySwap`, `applyModifyLiquidity`, `applyFeeCheckpoint`, `applyTickCross`, `applyFeeGrowth`, `applyDonate`.

**The swap loop.** One step = one canonical `Pool.swap` loop iteration, including zero-liquidity / uninitialized-word progress. Stepping uses `SqrtPriceMath.getNextSqrtPriceFromInput` and the V4 fee-growth semantics (LP fee, directional protocol fee, global/inside/outside growth). `QUOTE_MAX_SWAP_STEPS = 512` **per candidate**; all swaps inside one candidate share the counter; a required step 513 terminates the candidate.

**Candidates.**
- Entry and standalone compound: **one** full-compound candidate; exhaustion ⇒ `QuoteWorkExceeded(steps, 512)`.
- Withdrawal: **at most two** candidates — full, then (only under S1-EXIT-01) collection-only, **recomputed from the original state**. Worst case 1,024 executed planning steps. A failed full candidate yields **no** state/output to the second. A failed collection-only candidate returns its own economic-domain error; **never** a partial quote.
- A paired collection-only candidate contains **no swaps**.

**Classification (S1-EXIT-01).** The planner *classifies*, it does not catch. Predicates are evaluated on the plan, never on a caught exception:

| Reason | Predicate |
|---|---|
| `MaintenanceWorkLimit` | the full candidate needs another swap-loop step beyond 512 while the collection-only candidate plans fully within budget |
| `MaintenancePriceLimit` | the planned nonzero ratio swap has no legal directional price interval at the protocol boundary (a zero-swap branch is **not** a failure) |
| `MaintenanceLiquidityLimit` | the computed addition exceeds owned signed liquidity, per-tick gross capacity, or manager principal-delta limits |
| `MaintenanceDeltaLimit` | a planned swap quantity or settlement delta does not fit the manager's amount/delta types |

**Not** fallback triggers: insufficient custody, invalid accounting/configuration, inability to collect fees, an already-unlocked manager, unexpected price/fee changes, transfer/wrapper/payout failure, actual manager revert, unmet caller minima, or an unavailable final sale. Implementation rule: the fallback decision is taken **before any manager mutation**, from the plan; the execution path then re-validates the selected mode and reverts `EconomicStateChanged()` if the state moved.

**Native / wrapped isolation.** The planner works entirely in **raw pool currency**. Native is a delivery-form mapping applied after planning: `msg.value` is reserved before any balance-derived quote (S1-OP-01, S1-API-03); a native preview uses the same amounts as the wrapped face and never requires value in a view call. `address(0)` is never passed to an ERC-20 function.

**Invalidation.** The plan carries a snapshot commitment: `slot0` (sqrtPrice, tick), active liquidity, global fee growth, and the position's `feeGrowthInsideXLast`. At execution start, after the preflight, the family re-reads those and compares; any mismatch ⇒ `EconomicStateChanged()` — never a stale execution, never a mid-execution mode change, never reallocation of unexpected fees.

**Highest-risk component (WP0 (i)).** Exact fidelity to V4's swap (fee growth, tick crossings, protocol fees, empty-word progress) is the hard requirement of S1-QUOTE-01/S1-A27/S1-A67. Two options:
- **(a)** reuse Crane's vendored `lib/crane/.../v4/libraries/Pool.sol` swap routine against a **copied** state — preferred if its state access can be redirected to memory;
- **(b)** re-derive the step in the family and prove equivalence by a **differential test**: run the identical swap sequence against the real `PoolManager` and assert the planner's predicted slot0/tick/amounts/deltas match the manager's receipts exactly.

The differential test is mandatory under either option and is the gate for WP5.

---

## 6. Testing plan and the S1-A01 → S1-A70 mapping

### 6.1 Fixture design (production-first)

`harness/TestBase_UniswapV4PairTokenStandardExchangeVault.sol` extends `contracts/test/IndexedexTest.sol` (which extends Crane's `CraneTest`), following the Wings TestBase shape but **not** subclassing any Wings vault:

- **Real `PoolManager`** via `create3Factory.create3WithArgs(ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"), abi.encode(address(this)), keccak256("PairTokenSE.PoolManager"))` — the production-faithful port, not a mock.
- **Real currencies:** `ERC20PermitMintableStub` at 6/8/18 decimals (the existing Crane harness stub, permitted because it is outside the SUT); a native leg via `Currency.wrap(address(0))`.
- **Real wrapped native:** the canonical `IWETH` implementation bound at package init.
- **Real package + registry:** `vm.prank(owner); indexedexManager.deployPkg(creationCode, abi.encode(init), keccak256("PairTokenSE.Package"))`, then `package.deployVault(PkgArgs(...))`. **Never** `diamondPackageFactory.deploy` directly (registry path is mandatory for vault packages).
- **Five reused facets** deployed through `create3Factory` exactly as the Wings TestBase does, plus the five family facets through the family `*_Component_FactoryService`.
- **Behavior libraries** for facet/package/standard declarations, following the `Behavior_IERC165` pattern (`expect_*` / `isValid_*` / `hasValid_*`).
- **Handlers** for fuzz/invariants: `PairTokenSEHandler` wrapping the real diamond with bounded valid domains; a second handler for adversarial sequences.
- **Independent math control:** `PairTokenSEOracle` reads Python-generated JSON vectors; it must not call the family's own formulas.
- **Baseline comparison:** `test/foundry/spec/pairtoken-baseline/harness/PairTokenTestBase.sol` + `ScriptedDependencies.sol` are used **as-is** for characterization only (fresh real `PairToken` instances, no subclassing, no storage injection, no etching). Scripted-manager results are **never** new-family acceptance.

**Comparison ledger buckets** (four, exactly as S1-TEST-01 requires): *preserved*, *intentional deviation*, *unsupported scope*, *new capability (no baseline counterpart)*. The F2 principal-delta inversion, the S1-X13 boundary clamping, the removal of dead shares/retention/protocol fees, the caller-only entry inventory, the conditional fallback, the ledger, and the planner are recorded in their buckets with the PRD row that authorizes them.

### 6.2 Suite index

| Suite | File (proposed) | Focus |
|---|---|---|
| T1 | `...PairTokenSEIdentity.t.sol` | config validation, instance isolation, zap-parameter no-defaults |
| T2 | `...PairTokenSEDeployment.t.sol` | package lifecycle, identity, misuse rejection, disable |
| T3 | `...PairTokenSESurface.t.sol` | selector/interface/Repo manifest, permit, domain, read policy, no-excluded-selectors |
| T4 | `...PairTokenSEGenesis.t.sol` | paired genesis, genesis rejections, tiny-value genesis |
| T5 | `...PairTokenSEEntry.t.sol` | paired entry, zap both directions, boundary cases, four routes |
| T6 | `...PairTokenSEIssuance.t.sol` | S1-ACC-07 non-dilution, credit components, rounding attribution |
| T7 | `...PairTokenSEExit.t.sol` | paired/single-token redemption, terminal, rollback, minima |
| T8 | `...PairTokenSECompound.t.sol` | compound branches, DUST, fee checkpoints, no-op |
| T9 | `...PairTokenSEQuote.t.sol` | preview/execution parity, step budget, plan invalidation, model fidelity |
| T10 | `...PairTokenSEFallback.t.sol` | maintenance-mode classification and its exclusions |
| T11 | `...PairTokenSENative.t.sol` | native custody, wrapper adapter, settlement, receivers |
| T12 | `...PairTokenSEDonation.t.sol` | donation, unbooked isolation across the lifecycle |
| T13 | `...PairTokenSEPretransfer.t.sol` | false/true-flag input, local credit, excess |
| T14 | `...PairTokenSECallback.t.sol` | callback authentication, replay, reentrancy, read policy |
| T15 | `...PairTokenSESY.t.sol` | 16 SY methods, rate, rewards, internal balance |
| T16 | `...PairTokenSERegistry.t.sol` | registry discovery, contents id, disable semantics |
| T17 | `...PairTokenSEMath.t.sol` | math unit + oracle parity + manager-receipt parity |
| T18 | `...PairTokenSESequence.t.sol` | sequences, invariants, custody reconciliation, non-dilution under sequences |
| T19 | `...PairTokenSESize.t.sol` | runtime size + worst-case gas feasibility |
| T20 | `...PairTokenSEComparison.t.sol` | baseline comparison ledger, four buckets |

### 6.3 Full S1-A01 → S1-A70 coverage mapping

Every row is mapped to a proposed suite, a named case, and the assertion that discharges it. No row is grouped away.

| ID | Suite | Proposed case | Assertion that discharges the row |
|---|---|---|---|
| A01 | T16 | `test_registryDiscoversVaultByBothFacesAndTypes` (+ native variant) | `indexedexManager.vaultsOfToken(C0)`, `vaultsOfToken(C1)`, `vaultsOfType(...)` each return the deployed vault; native variant discovers by the wrapped face |
| A02 | T2 | `test_pkgIdentityDeterministic`, `test_pkgIdentityChangesPerImmutableArg` | identical `PkgInit`/`PkgArgs` ⇒ predicted == actual address; mutating poolKey, rateAsset, name, symbol, maxZapBps, maxZapTickMove, wrappedNative each changes identity |
| A03 | T1 | `test_invalidPoolKeyReverts`, `test_uninitializedPoolReverts`, `test_hookedPoolReverts`, `test_invalidRateAssetReverts`, `test_invalidZapBpsReverts`, `test_invalidZapTickMoveReverts`, `test_invalidWrappedNativeReverts`, `test_duplicateCurrencyFacesRevert`, `test_validNativePoolDeploys`, `test_validErc20PoolDeploys` | each rejects with the named family error; the two valid cases deploy and answer queries |
| A04 | T2 | `test_reinitializeReverts`, `test_processArgsFromNonRegistryReverts`, `test_directPackageDeployReverts`, `test_invalidFacetComponentRejects` | `AlreadyInitialized`; `NotCalledByRegistry`; direct deployment attempt rejected; `InvalidComponent` for zero-code facet |
| A05 | T3 | `test_metadataAndDecimalsOnProxy`, `test_permitAndDomainOnProxy`, `test_domainIsolationAcrossInstances` | `name()/symbol()/decimals()==18` on the proxy; permit spends an allowance and advances the nonce; `DOMAIN_SEPARATOR`/`eip712Domain` resolve to the **diamond** with the current chain id; two instances have different domains |
| A06 | T3 | `test_facetDeclarationsMatchControls`, `test_everyPackageSelectorCallable`, `test_loupeEqualsDisjointUnion` | each package facet's `facetInterfaces()`/`facetFuncs()` equals the interface-derived control; every package selector answers on the live proxy; loupe surface == package ∪ factory, not the package cut alone |
| A07 | T3/T16 | `test_basicVaultDiscovery`, `test_standardVaultDiscovery`, `test_bookedReservesDifferFromPrincipal` | `vaultTokens()` == `[C0,C1]` in face order; `reserves()` aligned; `vaultConfig()` truthful; booked idle ≠ whole-position liquidation value |
| A08 | T4 | `test_genesisMintsFullGeometricMean` | recipient balance == `floor(sqrt(a0·a1))` exactly; total supply == that; no1,000-share sink, no virtual shares/assets |
| A09 | T4 | `test_genesisRejectsZeroInput`, `test_genesisRejectsZeroMint`, `test_genesisRejectsZeroFundableLiquidity`, `test_genesisRejectsProductOverflow`, `test_genesisRejectsUnmetMinimum` | each reverts atomically (state unchanged); the overflow case reverts on the checked product, not on a wraparound |
| A10 | T5 | `test_pairedEntryUsesLimitingReserveRatio`, `test_pairedEntryAppliesCreditCap`, `test_unusedErc20MaximaRemainWithCaller`, `test_nativeUnusedMaximumRefunded` | `used_i == min(a_i, ceil(qQuote·R_i/S))`; minted `q == min(qQuote, qCredit)`; unused ERC-20 maxima stay with the caller; native excess refunded |
| A11 | T5 | `test_oneSidedReserveBranchConsumesOnlyLiveLeg`, `test_bothReservesZeroRejects` | only the live leg is consumed; positive supply with both reserves zero reverts `InvalidAccountingState()` |
| A12 | T5 | `test_entryCompoundsBeforeSnapshot`, `test_callerInputExcludedFromCompound` | the fee checkpoint precedes the snapshot; the caller's pending inventory is absent from the compounded book |
| A13 | T5 | `test_zapToken0Direction`, `test_zapToken1Direction` | half-swap then post-swap checkpoint then caller-only add then `G_i`/`qCredit` issuance, in that order, observed via the manager trace and the ledger |
| A14 | T5 | `test_zapRejectsEmptySupply`, `test_zapRejectsEmptyBasket`, `test_zapRejectsZeroInput`, `test_zapSizeCapBoundary`, `test_zapTickMoveBoundary` | boundary values accepted/rejected exactly at the limit (`≤ floor(inputReserve·maxZapBps/10000)`, `≤ maxZapTickMove`) |
| A15 | T6 | `test_nonDilutionInvariant` (fuzz), `test_creditExcludesIncumbentInventory` | for every admitted entry and every positive reserve, `q·R_i ≤ S·C_i` at the same `P*` **using the independent wide-integer control**; incumbent idle and fees are absent from `C_i`; exercised with imbalanced idle, partial fills, residuals, and addition rounding; no tolerance |
| A16 | T7 | `test_pairedRedemptionFullAmountNoRetention` | the full submitted share amount is redeemed; payout == proportional principal + idle; no 10-bps retention |
| A17 | T7 | `test_partialRedemptionDustStaysWithHolders`, `test_noDoubleFeeAllocation` | residual dust remains booked to remaining holders; fee growth is allocated once |
| A18 | T7 | `test_singleTokenExitToken0Direction`, `test_singleTokenExitToken1Direction` | only the withdrawing allocation is sold; the payout equals allocated desired currency + actual swap output; the actual minimum is enforced |
| A19 | T7 | `test_partialFinalSaleRevertsAtomically`, `test_pairedExitSucceedsUnderCollectOnly`, `test_unexpectedFailureStillReverts` | partial sale ⇒ whole transaction reverts (shares not burned, state unchanged); a paired exit succeeds through a valid collection-only plan when a listed obstacle blocks full compounding; an injected manager failure still reverts |
| A20 | T7 | `test_lastSharePairedExitEmptiesBasket`, `test_rebootstrapAfterTerminalIgnoresUnbooked` | after the terminal exit: supply 0, liquidity 0, booked 0/0; a later genesis succeeds and the unbooked balance is not captured |
| A21 | T7 | `test_lastShareSingleTokenExitWithExternalLiquidity`, `test_lastShareSingleTokenExitInsufficientLiquidityRevertsNoBurn` | with external liquidity the exit succeeds; without it the exit reverts and **no** shares are burned |
| A22 | T8 | `test_compoundRetainsAllFees`, `test_compoundMakesNoFeeManagerCall`, `test_compoundDoesNotChangeSupply` | 100% of fees booked to the incumbent book; no fee-manager call and no approval; supply unchanged |
| A23 | T8 | `test_dustEqualityBranch`, `test_leftoverTieChoosesToken0`, `test_zeroActiveLiquidityBranch`, `test_quarterCapBranch`, `test_noSwapCompoundBranch` | `idle == DUST` is not "exceeds DUST"; a tie sells token0; zero active liquidity ⇒ no swap; the swap is capped at `reserve·maxZapBps/10000/4`; the ≤DUST leftover ⇒ no swap |
| A24 | T8/T7 | `test_compoundSwapFeesCheckpointedPositiveAdd`, `test_compoundSwapFeesCheckpointedZeroAdd`, `test_entrySwapFeesRemainIncumbent`, `test_exitSaleFeesRemainWithRemainingLiquidity`, `test_wholePositionFeesNeverPartialExiterPrincipal` | the final checkpoint includes swap-generated fees in both add branches; entry-swap fees are incumbent; exit-sale fees belong to remaining liquidity; a partial exiter's principal excludes any whole-position fee receipt |
| A25 | T5/T7 | `test_fourExactInputRoutesExecute`, `test_unsupportedRoutesReject` | C0→V, C1→V, V→C0, V→C1 execute; currency-to-currency, V→V, identical-currency, and unrelated-token routes revert `InvalidRoute` |
| A26 | T3/T7 | `test_exactOutputSelectorsInstalledAndReject` | both `previewExchangeOut` and `exchangeOut` are installed and revert `ExchangeOutNotAvailable()` with no transfer, burn, mint, or manager mutation |
| A27 | T9 | `test_previewMatchesExecution` (4 routes + paired + terminal) | from identical state the preview's integer output **equals** the executed output exactly, including fees, compounding, tick crossings, and terminal branches |
| A28 | T9 | `test_stepBudgetBoundary512`, `test_stepBudgetBoundary513`, `test_atMostTwoWithdrawalCandidates`, `test_rejectedFullPlanDoesNotLeakIntoCollectOnly` | step 512 succeeds and step 513 terminates identically in preview and execution; ≤2 candidates and ≤1024 executed steps; a rejected full plan contributes no state to the collect-only projection; no partial quote is ever returned |
| A29 | T15 | `test_allSixteenSyMethodsInstalled`, `test_syExecutionMatchesSe`, `test_noSecondReceiptToken` | all 16 SY selectors answer; SY and SE produce equal economics for equal states; `yieldToken() == address(diamond)` and no additional share/receipt token exists |
| A30 | T15 | `test_internalBalanceRequiresContractCaller`, `test_internalBalanceValidatesVaultHeldShares`, `test_invalidTokenAndNativePaymentBehavior` | EOA internal-balance redemption reverts `EOAPretransferNotAllowed()`; a shortfall reverts `TransferDeltaInsufficient`; unsupported-token preview returns 0 while execution reverts |
| A31 | T15 | `test_emptyRewardArraysAndEvents` | `getRewardTokens()`/`accruedRewards()`/`rewardIndexesCurrent()`/`rewardIndexesStored()` are empty and `ClaimRewards` emits empty arrays; LP fees are not claimable as external rewards |
| A32 | T15/T17 | `test_syToAssetReturnsRawUnits`, `test_exchangeRateMatchesExactRational` (6/8/18-decimal variants) | `floor(Vraw·1e18/S)` per the canonical helper, returning **raw** units; the rate equals the independent exact-rational valuation; no extra decimal scale |
| A33 | T15 | `test_zeroSupplyRateIsZero` | zero supply ⇒ `exchangeRate() == 0`; no 1:1 bootstrap value appears |
| A34 | T13 | `test_falseFlagRequiresExactReceipt`, `test_bookedReservesDoNotFillShortfall` | a short delivery reverts; existing booked reserves and unrelated transfers never fill it |
| A35 | T13 | `test_trueFlagEoaReverts`, `test_trueFlagConstructorCallerReverts` | a code-less caller (and a constructor-time caller) reverts `EOAPretransferNotAllowed()` |
| A36 | T13 | `test_trueFlagShortCreditReverts`, `test_trueFlagCannotSpendBookedBacking` | no mint without unbooked funds; a shortfall reverts; booked backing is untouched |
| A37 | T13 | `test_excessPretransferNotRefundedAndUnbooked` | exactly the declared input is processed; nothing is refunded; the excess stays unbooked |
| A38 | T12 | `test_donationAddsBackingNoShares`, `test_unsolicitedBalancesRemainUnbookedAcrossLifecycle` | donation raises booked reserves and mints nothing; an unsolicited transfer is absent from the book through compound, entry, exit, and restart |
| A39 | T14 | `test_authenticCallbackSucceeds`, `test_wrongManagerRejects`, `test_unsolicitedPayloadRejects`, `test_replayRejects`, `test_reentrancyRejects`, `test_crossFacetCallbackRejects` | only the bound manager with the committed payload and the active operation kind succeeds; each attack reverts |
| A40 | T14 | `test_alreadyUnlockedRejects` | `TransientStateLibrary.isUnlocked(manager)` ⇒ `ManagerAlreadyUnlocked()` before any nested unlock; no local-sleeve path exists |
| A41 | T18 | `test_invariant_managerAndCustodyReconcile` | after every operation: manager position liquidity, actual custody, booked balances, total supply, and emitted amounts all reconcile |
| A42 | T16 | `test_disabledRejectsIssuanceAndDonation`, `test_disabledAllowsCompound`, `test_disabledAllowsPairedAndSingleTokenExits` | disabled ⇒ issuance and donation revert; standalone compound still works; paired and executable single-token/SY exits still work with the same fallback rules |
| A43 | T7/T11 | `test_payoutFailureRollsBack`, `test_unmetMinimaRollsBack` | a rejecting receiver or an unmet minimum reverts the whole transaction: no surviving swap, removal, burn, or transfer |
| A44 | T17/T18 | `test_mixedDecimalsOperate`, `test_feeOnTransferUnderlyingDoesNotMintUnsupportedShares` | 6/8/18-decimal mixes work; with a real FoT token the observed-delivery rule makes the operation revert rather than mint shares for undelivered input |
| A45 | T17/T10 | `test_basketMatchesManagerAtInteriorAndBoundaries`, `test_outOfRangeClampedToCanonical`, `test_capacityLimitSelectsFallback`, `test_otherInvalidQuantitiesReject` | `N_i` matches the manager's own receipts at interior, at both exact boundaries, and outside the range; capacity/signed-limit failures select the fallback only for listed withdrawal-maintenance reasons; other invalid quantities revert; no silent clamping |
| A46 | T18 | `test_sequence_supplyConservation`, `test_sequence_noUnbookedAdoption`, `test_sequence_donationWithoutMint`, `test_sequence_perLegNonDilution`, `test_sequence_exiterProportionalAllocation` | exact supply conservation; no unbooked adoption; donation without mint; per-leg `q·R_i ≤ S·C_i`; each exiter's exact proportional allocation before sale; external price/fee effects and entrant residual donations reported separately (measured trading profit is **not** offered as evidence) |
| A47 | T1 | `test_instanceIsolation` | two instances sharing facets have independent state, balances, approvals, position keys, and initialization |
| A48 | T19 | `test_runtimeSizeWithinLimit`, `test_buildConfigurationUnchanged` | every deployed facet is under EIP-170; `foundry.toml` still has `via_ir = false`, `optimizer_runs = 1`, `[fuzz] runs = 16`, `[invariant] runs = 16 depth = 8`; the deployed bytecode equals the freshly built artifact (no stale `out/`) |
| A49 | T11 | `test_nativePairedGenesisRefundsUnused`, `test_nativeValueExcludedFromPreEntryCompound`, `test_wrongNativeValueReverts`, `test_refundFailureRollsBack` | `msg.value == amount0Max` exactly; the incoming ETH is excluded from the pre-entry compound; only the unused part is refunded; a wrong value or a failing refund reverts everything |
| A50 | T11 | `test_nativeAndWrappedEconomicsEqual` | from equal states the native and wrapped routes produce equal economic outputs; only the delivery form differs |
| A51 | T11 | `test_nativeSettlementThroughRealDiamond`, `test_noErc20CallTargetsZeroAddress` | real registered diamonds settle natively (sync → settle{value} → validate), wrapper callbacks and ETH receipts work, and the manager trace shows no ERC-20 call to `address(0)` |
| A52 | T11 | `test_unsolicitedEthStaysUnbooked`, `test_pendingValueNotCredited`, `test_wrappedRepresentationNotDoubleCounted` | forced/unsolicited ETH, pending value, refunds, and the temporary wrapped balance never become backing or deposit credit; the custody invariant holds |
| A53 | T11 | `test_rejectingReceiverRollsBack`, `test_reentrantReceiverRollsBack`, `test_contractReceiverGetsFullGas` | rejecting and reentrant receivers roll the operation back; a legitimate contract receiver is not limited to a 2,300-gas stipend |
| A54 | T11 | `test_nativeTerminalExitEmptiesReserves`, `test_nativeRebootstrapExcludesUnbookedEth` | after the native terminal exit: booked ETH/token reserves and owned liquidity are zero; a rebootstrap excludes the old unbooked ETH |
| A55 | T11 | `test_nativeAndWrappedDonationCreditSameReserve`, `test_donationWrongValueReverts`, `test_nativeCallOnErc20OnlyPoolReverts`, `test_standardSeRejectsZeroAddressRoute` | both donation forms credit the same reserve exactly once; wrong `msg.value` reverts; a native call on an ERC-20-only pool reverts; standard SE routes reject `address(0)` |
| A56 | T3 | `test_packageOwnsExactlyTwentyReusedSelectors`, `test_noCombinedPermitFacet`, `test_noDuplicateSelectorInPackage`, `test_noFactoryFacetInPackage` | the package's reused-selector set == the 20 canonical selectors with their canonical interface ids; `ERC20PermitFacet` is absent; no selector is installed twice; no factory-owned facet appears in the package's inputs, addresses, or cuts |
| A57 | T3 | `test_factoryFacetsRemainCallable`, `test_temporaryDeployHookLifecycle`, `test_sharedRepoInitializationPerProxy`, `test_permitNonceLifecycle` | ERC-165, loupe, and ERC-8109 answer on the proxy without package cuts; the temporary hook follows the factory lifecycle (present during deploy, removed after `postDeploy`); shared Repos are initialized on each proxy; permit executes, the nonce advances, replay is rejected, and domains are isolated |
| A58 | T16 | `test_nativeDiscoveryWithWrappedFaceSortingAfter`, `test_viewsRetainPoolKeyFaceOrder` | the registry hash uses the **sorted** copy and finds the vault; `vaultTokens()`/`vaultConfig.tokens`/`reserves()` retain PoolKey face order |
| A59 | T14 | `test_economicReadsRevertDuringOperation`, `test_basicReservesReturnCommittedSnapshot`, `test_tokenReadsUnaffectedDuringOperation` | during an operation the family's economic queries revert `ReentrantOperation()`; `IBasicVault` returns the last committed snapshot; token/domain/allowance reads keep canonical behavior |
| A60 | T11 | `test_nativeSyncResetBeforeSettlement`, `test_managerDeltasCloseToZero`, `test_emptyCalldataReceiptNotAttributed` | an explicit native `sync` precedes settlement even after an outstanding ERC-20 sync; actual manager deltas net to zero; an empty-calldata ETH receipt bypasses the family facets and is attributed only by the active engine |
| A61 | T10 | `test_fallbackReasonWorkLimit`, `test_fallbackReasonPriceLimit`, `test_fallbackReasonLiquidityLimit`, `test_fallbackReasonDeltaLimit`, `test_validFullCandidateAlwaysWins` | each reason is either reachable on a real manager or accompanied by an independently demonstrated unreachable-domain proof; mode and reason agree across `previewWithdrawalMode`, the `WithdrawalMaintenanceSelected` event, and execution; a valid full candidate always wins |
| A62 | T10 | `test_managerErrorNotCaught`, `test_tokenErrorNotCaught`, `test_wrapperErrorNotCaught`, `test_feeCollectionErrorNotCaught`, `test_stateChangeRevertsEconomicStateChanged`, `test_failedCollectOnlyRevertsAtomically` | none of these is converted into a fallback; a failed collection-only plan reverts atomically with no partial compound |
| A63 | T10 | `test_minimaDoNotSelectFallback`, `test_unavailableSaleDoesNotSelectFallback`, `test_modeQueryDisambiguation` | unmet minima and an unavailable final sale never change the mode; the paired mode requires `tokenOut == address(0)` and the boolean disambiguates paired vs single-token ETH |
| A64 | T6 | `test_creditComponentsDistinguished`, `test_roundingCostBorneByEntrant`, `test_minimumUsesFinalShares` | `G_i`, paired `J_i`, zap uncredited `J_i`, and incumbent fees are separately observable; the entrant bears the addition rounding cost; the minimum is checked against `q`, not `qQuote` |
| A65 | T18 | `test_invariant_custodyCategoriesReconcile`, `test_invariant_reservationsZeroAtBoundaries`, `test_terminalReceiptsPaidToLastHolder` | at every stable boundary all categories sum to raw custody and reservations are zero; terminal receipts are paid to the last holder; unsolicited funds are neither paid nor adopted |
| A66 | T8/T7/T4/T12 | `test_emptyCompoundIsNoOp`, `test_zeroTotalOutputBurnRejects`, `test_oneSidedPositiveOutputSucceeds`, `test_tinyGenesisHasNoDeadShares`, `test_tinyDonationSequencePreservesPredicates` | empty compound succeeds as a no-op; a zero-total-output burn reverts; a one-sided positive payout succeeds; tiny sequences keep the exact predicates with no dead or virtual shares |
| A67 | T9 | `test_protocolFeeModeled`, `test_tickCrossingModeled`, `test_emptyWordProgressModeled`, `test_positionCheckpointChangeModeled`, `test_tokenInducedPlanChangeRevertsEconomicStateChanged` | the projection matches the real manager with nonzero protocol fees, initialized crossings, empty-word progress, and checkpoint changes across compound/entry/exit; a token- or wrapper-induced plan change reverts `EconomicStateChanged()` rather than executing stale |
| A68 | T3 | `test_noExcludedSelectorsOnProxy`, `test_selectorManifestComplete`, `test_repoInitializationComplete`, `test_packageBindingsInIdentity` | the final proxy exposes no ownership, `diamondCut`, rescue, ERC-4626, or excluded integration selector; the manifest covers every family ABI entry, the 20 shared selectors, the interface ids, and Repo initialization; package bindings participate in the deterministic identity |
| A69 | T16/T8/T1/T3 | `test_zeroFeeTypeIdsThroughRegistry`, `test_dustIsOneThousandRawUnits`, `test_zapParametersHaveNoSilentDefaults`, `test_assetInfoUsesCachedDecimals` | the registry registers and discovers the vault with `vaultFeeTypeIds == bytes32(0)` and no invented fallback; `DUST` is 1,000 **raw** units; an unset zap parameter is rejected rather than defaulted; `assetInfo()` returns the validated, initialization-time cached decimals |
| A70 | T19 | `test_worstCaseCandidateWorkWithinGasLimit`, `test_nativePathGasWithinLimit`, `test_collectOnlyPairedGasWithinLimit`, `test_runtimeSizeGate` | measured worst-case candidate work, native/wrapped paths, and collection-only paired exits fit the deployment's normal gas and code-size limits; a failed feasibility gate is reported as a **design revision** requirement, not relaxed |

---

## 7. Validation and release gates

### 7.1 Commands (current repo workflow — no package profile, no `via_ir`, no cache clearing)

```bash
# 1. Artifact-first build for the edited sources (per CLAUDE.md §10 and the PRD §11)
python3 scripts/forge-artifacts.py test \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultExecutionFacet.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/pairToken
# repeat with --test-root for each additional suite directory/file

# 2. Focused family suite
forge test --match-path "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/pairToken/**"

# 3. Baseline characterization (unchanged; must stay green)
forge test --match-path "test/foundry/spec/pairtoken-baseline/*"

# 4. Registry + shared-facet regression
forge test --match-path "test/foundry/spec/registries/vault/*"

# 5. Runtime sizes (the repo sets sizes=false, so ask explicitly)
forge build --sizes
python3 scripts/size_oversize_facets.py     # existing repo helper

# 6. Full hermetic gate before handoff
forge build && forge test
```

**Cold-compile patience (CLAUDE.md §8, non-negotiable):** the monorepo cold-compile is 20–40+ minutes with little output; wait for process exit, never kill `forge`/`solc`; use hours-long timeouts in a fresh worktree.

**Worktree cache seeding (CLAUDE.md §9):** before the first `forge` command in a new worktree, `rsync -a "${WARM}/cache_forge/" "${WT}/cache_forge/"` and `rsync -a "${WARM}/out/" "${WT}/out/"`, and symlink `lib/crane` to avoid nested-submodule reinstall thrash. Never delete `out/` or `cache_forge/` mid-program — `out/` is load-bearing because `ArtifactCreationCode` and the FactoryServices read creation bytecode from it.

### 7.2 Release gates (all must pass; a failure is a design revision, not a relaxed test)

| Gate | Criterion |
|---|---|
| G1 Compile | `forge build` exit 0 with no new error/warning in family sources |
| G2 Focused suite | every family test green in a **single** `forge test` run |
| G3 Baseline integrity | `test/foundry/spec/pairtoken-baseline/*` still green and **unmodified** |
| G4 Acceptance completeness | all 70 rows have a green named test recorded in the run log |
| G5 Code size | every deployed facet `< 24,576` bytes runtime (`forge build --sizes`) |
| G6 Configuration | `via_ir = false`; `optimizer_runs = 1`; `[fuzz] runs = 16`; `[invariant] runs = 16, depth = 8` unchanged; no new Foundry profile |
| G7 Fresh artifact | the deployed bytecode hash equals the freshly built artifact hash (no stale `out/`) |
| G8 Gas feasibility | measured worst-case candidate work, native path, and collect-only paired exit fit the deployment's normal gas limits |
| G9 Manager fidelity | the planner's projections match real `PoolManager` receipts exactly (differential test) |
| G10 Ownership proof | `q·R_i ≤ S·C_i` holds under fuzz and under sequences, with an independent wide-integer control |
| G11 Policy | no `new` in production deployment code; facets via CREATE3/`*_Component_FactoryService`; instances via `indexedexManager.deployPkg` + `package.deployVault`; no SUT mocking |
| G12 Report | the implementation report records the four-bucket comparison ledger, runtime sizes, exact commands and outputs, remaining integration limits, and the reusable paths for later stages |

### 7.3 Evidence and handoff format

The implementation report (co-located with the family, not in the PRD) must contain:

1. **Deviation ledger** — four buckets (preserved / intentional deviation / unsupported scope / new capability), each row citing the PRD ID that authorizes it (e.g. F2 → S1-ACC-03 + S1-ACC-06; S1-X13 → the clamped `N_i` table).
2. **Acceptance matrix** — for each of S1-A01…S1-A70: the test file, the test name, and the pass/fail result.
3. **Runtime sizes** — a table of every deployed facet's runtime byte size.
4. **Gas measurements** — worst-case candidate work, native path, collect-only paired exit, and the largest single operation.
5. **Commands run** — verbatim commands and their outcomes, with pre-existing failures called out separately and not repaired.
6. **Remaining integration limits** — including any limit inherited from the baseline comparison (e.g. the baseline's zap path cannot be executed against the real Crane manager because of F2; the baseline remains a scripted characterization only).
7. **Reusable paths for later stages** — the family Repo, math, accounting, planner, and fixture paths that stage two should extend rather than fork.

---

## 8. Blockers, assumptions, and limits

###8.1 Blocker-level items requiring an owner decision

**B1 (highest severity) — the PRD's fee *collection* language and its fee *accounting* definition are two different mechanisms, and only one is realizable as written.**

- Requirement references: S1-ACC-01 ("collect/project all fees"), S1-OP-05 ("Collect the position's accrued fees"), S1-X16 ("A final nonrecursive fee checkpoint includes all earned incumbent fees"), against S1-QUOTE-02's definition `F_i` = "the current claimable position fee from canonical fee-growth-inside minus the stored position checkpoint".
- Evidence: Crane's port realizes fees on a zero-delta `modifyLiquidity` (`Pool.sol:185-192` → `Position.sol:77-101`) and reverts `CannotUpdateEmptyPosition` for an empty position; the same computation defines `F_i` exactly.
- Assessment: these are **consistent** once read as "checkpoint = a zero-delta poke that realizes the whole position's fees into custody and advances the checkpoint". The PRD's prose is compatible with this, but it never states that the checkpoint is a *manager mutation* that realizes fees for the **entire** position, and S1-ACC-03's warning ("never treat a whole-position fee receipt as the partial holder's principal") only makes sense if the implementation knows this.
- Proposed resolution (no PRD change required, but the PRD owner should confirm): state in the implementation report — and, if the owner prefers explicitness, in a one-line PRD clarification — that "fee checkpoint" means *a zero-delta `modifyLiquidity` on a non-empty position, realizing the whole position's accrued fees into the incumbent book, advancing `feeGrowthInsideLast`, and executed before every removal*. Consequence to accept: after a checkpoint, a removal returns `feesAccrued == 0`, so the partial exiter's principal can never contain another holder's fees.
- If the owner instead intends fees to remain an un-realized accounting claim, the checkpoint must become a pure accounting update with no manager call, and S1-OP-05's "collect" and the "never poke an empty position" rule become vestigial. **This is a decision, not an implementation detail.**

**B2 — the PRD does not say whether the final fee checkpoint may mutate the manager before the caller-funded operation.**

- Requirement references: S1-OP-01's order ("compound incumbent book and checkpoint fees"), S1-ACC-07 ("Freeze incumbent supply S, price P*, owned liquidity L, and book B_i after the final incumbent-fee checkpoint"), S1-X16.
- Assessment: under B1's resolution the checkpoint *is* a manager mutation, so an entry that reverts after the checkpoint leaves the pool's position checkpoint advanced but the position unchanged — economically neutral, but it is a manager write that a strict reading of "the family performs no manager mutation before the caller-funded operation" would forbid.
- Proposed resolution: confirm that a fee checkpoint is an incumbent-book operation that may precede the caller's funding, and that it is rolled back with the transaction on any later revert (it is — the whole transaction reverts). No PRD change needed; recorded as an implementation note.

**B3 — unrepresentable valuation needs an error the PRD's error list does not name.**

- Requirement reference: S1-QUOTE-02 ("a mathematically unrepresentable final value reverts explicitly"), S1-OBS-01 (which enumerates the family errors to define).
- Assessment: `floor(A0·P²/2^192)` can exceed `uint256`; the PRD requires an explicit revert but names no error for it, and `InvalidAccountingState()` would be misleading.
- Proposed resolution: add a family error `ValueOverflow()` (or `MathOverflow()`) to the family interface and record it in the comparison ledger as a deliberate addition under S1-OBS-01's "Record every deliberate error/validation change in the implementation's comparison ledger". If the owner prefers strict adherence to the named list, map it to `InvalidAccountingState()` and document that choice.

**B4 — the preview's worst-case cost may exceed a public RPC's `eth_call` budget.**

- Requirement references: S1-QUOTE-01 (`QUOTE_MAX_SWAP_STEPS = 512`, up to 1,024 executed planning steps for withdrawals), S1-A70 (gas feasibility), S1-EXIT-01 (two-candidate planning).
- Assessment: a `view` performing up to 1,024 V4 swap steps is expensive. The bound is a *planning* bound, not a measured gas bound, and the PRD says so; but a consumer RPC may cap `eth_call` gas below the worst case, making `previewWithdrawalMode` / `previewRedeemPair` unreachable for adversarial states.
- Proposed resolution: measure the worst case in WP11/G8 and report it. If it exceeds a realistic RPC budget, the PRD's 512 bound — not the test thresholds — is what must change (a PRD revision, explicitly permitted by S1-QUOTE-01: "a different bound requires a PRD change, never a silent implementation default"). Mitigation available without a PRD change: expose the step counter in the `QuoteWorkExceeded` error so a consumer can distinguish "budget exhausted" from "economically invalid".

**B5 — the PRD requires both "the five canonical facets provide exactly their 20 selectors" and "the final persistent loupe surface equals the disjoint union"; the package's `vaultTypes()` must be the deduped *package-owned* interface set.**

- Requirement references: S1-ARCH-04, S1-ARCH-05, S1-A06, S1-A56, S1-A68.
- Assessment: I verified the 20 selectors and the factory's four base facets (F3). The one remaining coupling is `StandardVaultRepo._initialize(oracle, vaultFeeTypeIds, vaultTypes, contentsId)`: `vaultTypes` must be the **deduplicated package-owned** interface declaration set, and `vaultFeeTypeIds` must be `bytes32(0)` (stage one has no fee types) — whereas the Wings package uses `VaultTypeUtils._insertFeeTypeId(bytes32(0), VaultFeeType.USAGE, interfaceId)`. Following Wings here would register a USAGE fee type the family never charges, contradicting S1-D03 and S1-A69.
- Proposed resolution: package `vaultFeeTypeIds()` returns `bytes32(0)`; `vaultTypes()` returns the deduped package-owned interface ids; both the package and `initAccount` must agree, or registry registration and the proxy's `vaultConfig()` diverge.

### 8.2 Assumptions (each with the verification step that must precede reliance)

| # | Assumption | Verification |
|---|---|---|
| A-1 | Crane's `Pool.sol` swap routine can be reused over a copied state; otherwise the family re-derives it and proves equivalence by differential test | WP0 (i) |
| A-2 | The canonical `positionId` for `StateLibrary.getPositionLiquidity` is `keccak256(abi.encodePacked(owner, tickLower, tickUpper, salt))`; the baseline uses this form, and `Position.sol` builds a 58-byte key | WP0 (ii) + a live round-trip test |
| A-3 | `keccak256(abi.encode(sortedFaces))` equals the registry's `calcContentsId([C0,C1])` byte-for-byte | WP0 (iii) + T16 A58 |
| A-4 | `IPoolManager.unlock` returns the callback's return bytes to the caller so `unlock` can be decoded as a result (the baseline relies on this) | T11/T14 |
| A-5 | `Position.update`'s fee computation uses the **pre-update** liquidity (read at `Position.sol:88` before the delta is applied) — this is what makes an add forfeit the new liquidity's share of past fees and a removal realize the whole position's fees | WP4 + T8 |
| A-6 | The `IERC20`/`IERC20Metadata` used by `MultiAssetBasicVaultRepo._updateReserve(IERC20,uint256)` accepts the wrapped-native face as an ordinary ERC-20 (it does — it is just an address) | T11 |
| A-7 | `IVaultRegistryDeployment.deployVault(pkg, args)` is the only sanctioned instance path and `processArgs` must be callable only by the registry | WP0 (iv) + T2 |
| A-8 | The 16-method SY surface can be delivered by inheriting `NativeStandardYield*` seams while overriding the blanket nonzero-`msg.value` rejection **for this family only** (the PRD requires other families' policy to be unchanged) | WP7 + T15 |
| A-9 | `ERC20Repo`/`ERC2612Repo`/`EIP712Repo`/`MultiAssetBasicVaultRepo`/`StandardVaultRepo` are per-proxy storage (they are diamond storage bound by fixed slots, so per-proxy by construction) — two instances sharing facets stay isolated | T1 A47 |

### 8.3 What this plan does *not* establish

- **No measured gas, no measured runtime size, no executed test.** Every quantitative statement here is a design target or a bound taken from the PRD. A48 and A70 remain open until WP11.
- **No economic validation of the S1-ACC-07 equation against live pool behavior.** The equation is implemented as specified; whether it behaves well under adversarial price movement is an economic question the PRD explicitly declines to claim immunity against (S1-ACC-07's closing paragraph). The plan tests the *predicate*, not manipulation resistance.
- **No characterization of the baseline's real-manager path.** Because of F2, the baseline's zap issuance appears unable to mint against Crane's actual `PoolManager` (its `used0/used1` derive to zero). I have **not** executed that path; it is an inference from `PoolManager.sol:120` and `PairToken.sol::_add`. The comparison suite must record it as an observation with a **failing-on-real-manager** characterization, and the baseline must not be modified to make it pass.
- **The planner's swap fidelity is the largest open risk.** S1-QUOTE-01/S1-A27/S1-A67 demand exact agreement with the real manager across fees, crossings, protocol fees, and empty-word progress. WP0(i) and the mandatory differential test (G9) are the gate; if the vendored `Pool.sol` cannot be redirected to memory and the re-derivation cannot be proven equal, the PRD's preview-parity requirement is not implementable as specified and must return to the owner.
- **The 512-step bound is unmeasured.** B4 above.
- **I read only the parts of `docs/agent/INDEXEDEX_AGENT_LAW.md`, `Position.sol`, `Pool.sol`, `PoolManager.sol`, `BetterEfficientHashLib.sol`, and `DiamondPackageCallBackFactory.sol` that I cite.** Other sections of those files may contain additional constraints an implementer must honour.
- **This contribution reopens no settled product choice.** S1-D01…S1-D05, S1-P01…S1-P06, the issuance equation, the fallback predicates, the single share supply, the five-facet reuse list, and the 70 acceptance rows are treated as fixed. B1–B5 are implementation clarifications and error-surface gaps, not alternative economics.

---

**Now:** all nine planning tasks are closed; the complete contribution is delivered above.
**Next:** none on my side — this is the complete independent initial assignment, returned inline for the coordinator to archive as `coordinator/received/minimax-original.md`. Advisory review of the coordinator's frozen draft is a separate, later assignment that I have not performed.
