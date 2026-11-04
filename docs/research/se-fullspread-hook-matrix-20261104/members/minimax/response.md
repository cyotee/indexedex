# Identity

- Member: `minimax`. Requested role: `council-member`. Profile: `research`. Phase: initial independent response.
- Run: `se-fullspread-hook-matrix-20261104`.
- Requested model: `minimax/MiniMax-M3` (adaptive thinking not selectable).
- Runtime identity (actual serving provider, route and task id) exposed to this member by Native: not exposed.
- Owned artifact written by this member: `docs/research/se-fullspread-hook-matrix-20261104/members/minimax/response.md`.
- Peers read before submission: no. No peer `response.md` or `feedback.md` was opened; no sub-agent was launched; no test, build, install, deploy, wallet or Git command was run.
- Advisory only. This response does not authorize implementation and does not replace the plan.

# Question and targets

Question: complete the hook-matrix of the published full-spread implementation plan so an implementer can add this vault's row to each of the seven hook topologies without inventing a binding.

Targets read:

- The published plan `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md`, read whole. The defect to complete is its section 12, "Hook integration and migration" (lines 200-216).
- The governing PRD sentences `FS-HOOK-01` (PRD line 480), `FS-HOOK-02` (496), `FS-HOOK-03` (510), `FS-HOOK-04` (514), `FS-OWN-29` (216), `FS-A24` (577), `FS-A25` (578), `FS-A26` (579), `FS-A27` (580), `FS-A28` (581), `FS-A29` (582), `FS-A30` (583), `FS-TEST-04` (596-608), and the PRD §6 row "`previewExchangeOut` | Returns zero. No refund word is added." (470).
- The seven real `*_SeMatrixBehavior.sol` files, the seven `*_SeMatrix_UniswapV3FullSpreadStandardExchangeVault.t.sol` row files, `SeMatrix_FullSpreadV3Fixture.sol` and `SeMatrixFixture.sol`.

The response's Conclusions is the replacement text for plan section 12.

# Evidence

## 1. The plan's section 12 cites seven paths that do not exist, and omits one family

Plan lines 204-210 list `contracts/hooks/uniswap/v4/standardExchange/{constantProduct,stable,dual,orbital,weighted,stable/quad/curve,stable/quad/balancer}/*.behavior.sol`. No file under `contracts/hooks/.../standardExchange/` carries a `.behavior.sol` suffix; the shared behaviors are Solidity test contracts under `test/foundry/spec/hooks/uniswap/v4/standardExchange/`. The plan's list also has no entry for the non-CP `single/` family, and its `stable/` entry (line 205) has no counterpart among the seven real behaviors.

The seven real behavior contracts are:

- `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol`

## 2. The row shape

Each of the seven V3 row files is the same thin shape: it extends the shared behavior, implements `_newFixture()` and caches the package in `sharedPkg` so later fixtures reuse it. Example, `single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV3FullSpreadStandardExchangeVault.t.sol` lines 12-20; the same three lines appear in the constant-product, dual, orbital, weighted, Curve and Balancer row files. The fixture type is always `SeMatrix_FullSpreadV3Fixture` and the package is shared per test contract.

`SeMatrixFixture` (`test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol`) is the adapter contract every behavior binds to. It exposes `faceToken()`, `se()`, `fund()`, `hasPartialCase()`, `limitCapacity()`, `openCapacity()`, `seBooked()`, `sweepsOnNextInvest()`, `operativeRevertReachable()`, `armOperativeRevert()`, `disarmOperativeRevert()`, `isAmm()`, `otherToken()`, `fundOther()`.

`SeMatrix_FullSpreadV3Fixture.sol` deploys: the V3 FullSpread package through the Crane factory, a hermetic Uniswap V3 3000-fee pool, two `SimpleMintableERC20` faces (`token0`, `token1`), the vault through `pkg_.deployVault(pool)`, a `FullSpreadLiquidityProvider` that seeds 50_000e18 full-range liquidity, and a 100/100 dual bootstrap deposit through `exchangeInManyToOne`. Its `familyName()` is `"UniswapV3FullSpreadStandardExchangeVault"`, `faceToken()` is `token0`, `se()` is the vault, `seBooked()` is `_lr().localReserve(address(token0))`, `hasPartialCase()` is `true`, and `armOperativeRevert()` mocks `IUniswapV3Pool.mint`.

## 3. Which packages carry a rate provider

Read from the seven package interfaces:

| Family | Rate-provider field in `PkgArgs` |
| --- | --- |
| `single/` | none (`poolManager`, `standardExchange`, `pairToken` only) |
| `constantProduct/single/` | `address rateProvider` |
| `dual/` | `address rateProvider0`, `address rateProvider1` |
| `orbital/` | `address rp0`, `rp1`, `rp2` |
| `weighted/` | `address[] rateProviders` |
| `stable/quad/curve/` | `address[4] rateProviders` |
| `stable/quad/balancer/` | `address[] rateProviders` |

Every behavior builds its provider through `contracts/test/libs/RateProviderFixtureLib.sol`: `providerFor(create3Factory, diamondPackageFactory, se, face)` for orbital (behavior lines 153-155), `providerForCp(..., seUT, face)` for the constant-product single (line 128) and `providerForCp(..., seUT, face)` / `providerForCp(..., seUT1, other)` for dual (lines 128-129), `providersFor(...)` for weighted (line 103), `providersFor4(...)` for Curve (line 145) and Balancer (line 173). The helper deploys the production `StandardExchangeRateProvider` through `IStandardExchangeRateProviderDFPkg.deployRateProvider(IStandardExchange(se), IERC20(rateTarget))`, and it special-cases a self-share leg with `if (se == rateTarget) rateTarget = IERC4626(se).asset();`.

## 4. Pool composition and leg counts, per behavior

- `single/` (non-CP): the hook's pool currencies are the leg face and the vault's own share token. Behavior lines 198-207: `buffer.wrapper() == seUT`, `buffer.pairToken() == face`, `{c0, c1} == {face, seUT}`, `c0 < c1`, and `IBasicVault(hook).vaultTokens() == [c0, c1]`. One SE leg, no raw leg.
- `constantProduct/single/`: `PkgArgs` binds `standardExchange: seUT`, `pairToken: face`, `rawToken: raw` (behavior lines 121-123); `faceIsCurrency0 = single.currency0() == args.pairToken` (line 140). Two pool legs: the vault leg and the base's raw 18-decimal token; `single.standardExchangeOf(raw) == address(0)` (line 213).
- `dual/`: two fixture instances (lines 87-88), `standardExchange0/token0` and `standardExchange1/token1` (lines 124-126), `faceIsC0 = dual.currency0() == face` (line 136). Two SE legs, both this family.
- `orbital/`: three fixture instances (lines 91-93); `token0/token1/token2 = face0/face1/face2` (143-145), `se0/se1/se2` (149-151), `rp0/rp1/rp2` (153-155); three product pool keys `poolKey01`, `poolKey12`, `poolKey02` built by `PairPoolLib.pairKey(faceI, faceJ, spacing 60, hook)`. Three SE legs, all this family.
- `weighted/`: one fixture (line 72); the two currencies are address-ordered (`if (face < other) { faceIdx = 0; otherIdx = 1; } else { faceIdx = 1; otherIdx = 0; }`, lines 87-96); `weighted.standardExchange(faceIdx) == seUT` and `weighted.standardExchange(otherIdx) == address(0)` (lines 152-154). One vault leg plus one raw leg (`token1` from the base).
- `stable/quad/curve/`: four fixture instances sorted ascending by face token (lines 96-115) because the package rejects `TokensNotAscending`; `faceIdx = 0`, `otherIdx = 1` (lines 119-120). Four SE legs, all this family.
- `stable/quad/balancer/`: `LEGS = 4` (line 37); `_seLegCount()` defaults to 4 and "a row may lower it, in which case the remaining legs are the TestBase's raw 18-decimal test tokens" (lines 30-31, 68-70); legs are sorted ascending by token address and `faceIdx` is the lowest-address SE leg (lines 106-155).

## 5. Where the hook reaches the vault, and what fails closed

- Exact-in: `UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol:360-368` (`_buffer`) and `:373-381` (`_unwrap`) call `IStandardExchangeIn(se).previewExchangeIn(...)` and `IStandardExchangeIn(se).exchangeIn(..., address(this), false, block.timestamp)`. The non-CP single hook is the same shape: `single/UniswapV4SingleStandardExchangeBufferHookCommon.sol:96` (`_previewWrap`), `:111` (`_previewUnwrap`), `:134` (`_seExchangeIn`).
- Exact-out: `dual/...HookCommon.sol:394` calls `IStandardExchangeOut(se).exchangeOut(...)`; `dual/...HookClaimLib.sol:118` and `:130` call `previewExchangeOut` and revert `IStandardExchangeOut.ExchangeOutNotAvailable()` when it returns zero; `single/...HookCommon.sol:103-104` and `:118-119` do the same; `single/...HookCommon.sol:147` calls `exchangeOut`.
- One-word readers that the plan's migration must cover: `dual/...HookClaimLib.sol:78`, `dual/...HookCommon.sol:360, 373, 443`, `dual/...HookDepositQuoteLib.sol:238`, `dual/...HookInQuoteBase.sol:40, 78`, `single/...HookCommon.sol:96, 111, 134`, and the two files the plan already names, `UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol` and `ComposedStableCommonDetfCommon.sol` (plan line 216).
- The hook's context-quote path is ERC-165 gated: `ClaimLib.previewOutputWithContext` and `previewInputWithContext` fall back to the standard previews when `ContextQuote.snapshot` returns empty, which is what a vault without a transition-quote interface gets (PRD line 273).

## 6. The vault-side rules the row must respect

- `previewExchangeIn` returns `(uint256 amountOut, uint256 amountRefunded)` (plan line 94); `exchangeIn` is migrated to the same tuple (plan line 216). The refund goes to `msg.sender` (plan lines 120, 158), and the output goes to `recipient` (plan line 120).
- `exchangeOut` reverts `ExchangeOutNotAvailable` on an enabled vault and `previewExchangeOut` returns zero (plan line 142; PRD line 470).
- `reserves()` / `reserveOfToken` report the position-implied amount, not booked or local balances (plan §4). The vault exposes no booked getter: `uint256[2] booked` is family storage (plan line 77) and no query selector surfaces it (plan §5).
- The vault's backing pool key must be initialized on the bound manager and its hook must be `address(0)` (plan line 69), and the vault holds one full-range salt-zero position (plan §4).
- `donate` and `compound` book the held remainder and do not refund it (plan line 184).

# Assumptions

1. The plan is the artifact under review; the PRD's `FS-HOOK-01`-`FS-HOOK-04` and `FS-TEST-04` govern the row, and the PRD wins where the two differ.
2. The seven shared behavior contracts are the harness and are not edited for this family (plan line 51; PRD line 608). The adaptation seam is the `public virtual` test functions and the `internal virtual` hooks already present in the behaviors (`_residualTolerance`, `_previewSwapProbe`, `_oneUnitDepositControl`, `_positiveOneUnitDepositControl`, `_seedAmmReserve`, `_seLegCount`).
3. The row file is a subclass of the shared behavior and of a per-topology sibling behavior file; the sibling file is where this family's overrides live, the row file is where the fixture binding lives. This keeps plan section 13's reference to "the seven sibling behavior files" (plan line 230) true and keeps the seven shared behaviors untouched.
4. The `SeMatrix_FullSpreadV4Fixture` measurements of "booked" and "deployed" are fixture-side definitions, not new vault selectors: the vault installs no booked getter, so the fixture measures the local face balance as `IERC20(face).balanceOf(vault) - IBasicVault(vault).reserveOfToken(face)` and the deployed face as the position-implied `reserveOfToken(face)` delta. A Uniswap V4 pool has no separate address, so the V3 fixture's `token0.balanceOf(address(pool))` has no direct counterpart on a shared PoolManager.
5. "This vault's share" in the pool-currency sense means the vault's own ERC-20 share token, which is the vault diamond address. Only the non-CP `single/` family puts it into the hook's pool.
6. I read `contracts/test/libs/RateProviderFixtureLib.sol` and the hook package interfaces and the two hook `Common`/`ClaimLib` files in addition to the admitted targets, because the seven behaviors import the rate-provider helper directly and the matrix cannot name a rate-target binding without them. I did not read any peer member file, the coordinator draft, the plan blockers file, or any evidence file under `docs/audits/`.

# Coverage

| Required matrix item | Where it is answered |
| --- | --- |
| 1. Real behavior path and new row filename beside it | Conclusions 12.3, one block per topology |
| 2. Fixture filename and what it deploys | Conclusions 12.2, restated per topology |
| 3. Rate-target face and the second row | Conclusions 12.2 and 12.3 |
| 4. Token indices in the hook's pool | Conclusions 12.3, "Pool currencies and indices" |
| 5. Exact-input directions, leg count, leg roles | Conclusions 12.3, "Directions and legs" |
| 6. Inherited assertions that cannot pass and the adaptation | Conclusions 12.4 (rules A-G), referenced per topology |
| 7. Disjoint backing PoolKey rule; same-backing-pool sequential composition unverified | Conclusions 12.5 |
| 8. Canonical dual cross-vault case | Conclusions 12.6 and the `dual/` block |
| The one fixture file name and its three differences from the V3 fixture | Conclusions 12.2 |
| The plan sentence that blocks the matrix | Conclusions 12.7 |

Seven topologies, seven behavior paths, seven existing row files and the V3 fixture were read in full. The seven hook package interfaces were read for the rate-provider and leg shape. No test was run and no code was modified.

# Conclusions

The text below replaces plan section 12, "Hook integration and migration". It completes the hook-matrix for `UniswapV4FullSpreadStandardExchangeVault` across the seven topologies of the D20 matrix, with one binding and no options.

## 12. Hook integration and migration

### 12.1 The one binding

This vault is the buffered leg of every hook it is bound to. The hook's leg token is one of this vault's two face tokens; the hook's rate provider for that leg is an external `StandardExchangeRateProvider` instance deployed for this vault and that face as the rate target; the vault itself stores no rate-provider address, exposes no rate getter and designates no `rateAsset` (PRD `FS-OWN-29`, line 216; PRD `FS-HOOK-02` item 1). The hook reaches the vault only through its exact-input route, `exchangeIn`, which is the one route this vault supports while the PoolManager is unlocked (plan section 8; PRD `FS-A19`). The hook's exact-output route reaches `exchangeOut`, which this vault does not have, so that route fails closed.

The canonical cross-vault proof is the `dual/` topology with this vault on leg 0. Every other family proves the one-vault borrowed `exchangeIn` its own topology can express.

### 12.2 The one adapter fixture

`test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol`.

It follows `SeMatrix_FullSpreadV3Fixture.sol` except for this family's **package**, **pool**, and **refund tuple**, and for nothing else:

- **package**: the `UniswapV4FullSpreadStandardExchangeVault` production package and its bound IndexedEx vault registry deployment, instead of the Uniswap V3 FullSpread package. The vault is deployed through the registry path (plan section 4).
- **pool**: a Uniswap V4 pool on the bound PoolManager whose `hook` is `address(0)` and whose tick range is full, instead of a Uniswap V3 3000-fee pool. The two face tokens are that pool's `currency0` and `currency1`.
- **refund tuple**: the vault's `previewExchangeIn` and `exchangeIn` decode as `(uint256 amountOut, uint256 amountRefunded)`; `previewExchangeOut` returns zero and `exchangeOut` reverts `ExchangeOutNotAvailable`.

It deploys, in this order:

1. the vault, through its production package and the bound IndexedEx vault registry;
2. the bound hookless Uniswap V4 pool, initialized on the bound PoolManager with `hook == address(0)`;
3. the two face tokens, `SimpleMintableERC20` instances at `currency0` and `currency1` of that pool;
4. the external rate-provider instance, `IStandardExchangeRateProviderDFPkg.deployRateProvider(IStandardExchange(vault), IERC20(rateTarget))`, for the chosen rate target.

Fixture surface, mirroring `SeMatrixFixture`:

- `faceToken()` returns the face bound to the hook leg. `otherToken()` returns the vault's other face. `se()` returns the vault.
- `familyName()` returns `"UniswapV4FullSpreadStandardExchangeVault"`.
- `seBooked()` returns the vault's local face balance, `IERC20(face).balanceOf(vault) - IBasicVault(vault).reserveOfToken(face)`. The vault installs no booked getter (plan section 5), so this is the only non-invasive measurement; it is a fixture-side definition, not a vault requirement.
- `partialDeploymentBalance()` returns `(true, reserveOfToken(face))`, because a Uniswap V4 pool has no separate address and the V3 fixture's `token0.balanceOf(address(pool))` has no counterpart on a shared PoolManager.
- `armOperativeRevert()` makes the vault's operative PoolManager call revert with `rejectBytes()`. The V3 fixture mocks `IUniswapV3Pool.mint`; this vault's operative calls are the PoolManager `swap` and `modifyLiquidity` inside its own unlock (plan sections 8 and 9), so the injection point moves to the bound manager.
- `limitCapacity()` / `openCapacity()` express the capacity gate on the vault's consumable face balance; `hasPartialCase()` is `true`, because a donation or compound remainder is booked rather than refunded (PRD `FS-TEST-04`, line 608; plan line 184).

**The two rate-target rows.** The vault has two underlyings, `vaultTokens()[0]` and `vaultTokens()[1]`.

- Row A: the hook leg's token is the vault's `currency0` face; the leg's rate provider is the external instance for `(vault, currency0)`. The rate target is `currency0`.
- Row B: the hook leg's token is the vault's `currency1` face; the same vault instance; the leg's rate provider is the external instance for `(vault, currency1)`. The rate target is `currency1`. Row B is a second hook product PoolKey holding the same vault at a different rate target (PRD `FS-A29`, line 582; plan line 212).

Both rows exist only in the families whose package carries a rate-provider field. The `single/` package has no such field, so no second row exists there and the family proves only its own one-vault route (PRD `FS-HOOK-01`).

### 12.3 The seven topologies

Each block states: the real behavior path; the two new files beside it; the fixture and what it deploys; the rate target and the second row; the pool currencies and their indices; the exact-input directions and the leg roles; and the inherited assertions that cannot pass, by rule letter from 12.4.

#### 12.3.1 `single/` (non-CP single)

- Behavior path: `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol`.
- New files beside it:
  - sibling behavior `single/UniswapV4FullSpreadStandardExchangeVault_single.behavior.sol`;
  - row `single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- Fixture: `SeMatrix_FullSpreadV4Fixture.sol` — this vault, its bound hookless Uniswap V4 pool, the two face tokens, and the external rate-provider instance (12.2).
- Rate target: none in this family. `IUniswapV4SingleStandardExchangeBufferHookPackage.PkgArgs` has no rate-provider field, so the external provider cannot be configured on this leg. The family row proves the one-vault borrowed `exchangeIn` through the hook's `beforeSwap` in both exact-input directions, which is what PRD `FS-HOOK-01` assigns to `single/`. There is no Row B.
- Pool currencies and indices: two. The pool holds the leg face and **this vault's share token**. The share occupies the lower address index: `currency0` is the share when `seUT < face`, otherwise `currency1` is the share and `currency0` is the face, because the pool's currencies are address-sorted and the behavior asserts `c0 < c1` (behavior line 202). The share index is the one that is not the leg face; the other index is the leg face. This is the only one of the seven families whose pool contains the vault's share.
- Directions and legs: one SE leg (this vault) and no raw leg. Two directed exact-input swaps on the single pair: share→face and face→share. The direction flag follows the share index, not a hard-coded `zeroForOne`.
- Inherited assertions that cannot pass: rules A, B, C, D, E and F. Specifically `test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed` and `test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly` cannot pass; the exact-out half of `test_row_previewMatchesExecution` cannot pass; the helper `_mintSeSharesTo` (behavior line 186) mints through the vault's exact-out route, is `internal` and not `virtual`, and is reachable only from the replaced exact-out test, so the replacement test must not call it.

#### 12.3.2 `constantProduct/single/`

- Behavior path: `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol`.
- New files beside it:
  - sibling behavior `constantProduct/single/UniswapV4FullSpreadStandardExchangeVault_constantProductSingle.behavior.sol`;
  - row `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- Fixture: `SeMatrix_FullSpreadV4Fixture.sol` — this vault, its bound hookless Uniswap V4 pool, the two face tokens, and the external rate-provider instance (12.2).
- Rate target: Row A uses the vault's `currency0` face as both the leg token and the rate target, through `IStandardExchangeIn`-compatible external provider `deployRateProvider(vault, currency0)`. Row B uses `currency1` as both the leg token and the rate target, against the same vault instance, in a second hook product PoolKey. The package field is `rateProvider` (single field, one per hook).
- Pool currencies and indices: two. The leg face and the raw leg token; **no pool currency is this vault's share**. The face's index is determined at runtime, not assumed: `faceIsCurrency0 = single.currency0() == args.pairToken` (behavior line 140), so the face is `currency0` when `face < raw` and `currency1` otherwise, and the raw leg takes the other index. The raw leg is the base's 18-decimal raw token and has no SE and no rate provider.
- Directions and legs: two pool legs — the vault leg (buffered) and the raw leg (transfer only). Two directed exact-input swaps on the pair: face→raw and raw→face, with `zeroForOne` resolved by currency order, not by token name.
- Inherited assertions that cannot pass: rules A, B, C, D, E and F. Additionally `test_row_previewMatchesExecution`'s deposit and withdraw halves use the hook's own preview and do pass; only the exact-out comparisons fail.

#### 12.3.3 `dual/`

- Behavior path: `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol`.
- New files beside it:
  - sibling behavior `dual/UniswapV4FullSpreadStandardExchangeVault_dual.behavior.sol`;
  - row `dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- Fixture: `SeMatrix_FullSpreadV4Fixture.sol` — this vault, its bound hookless Uniswap V4 pool, the two face tokens, and the external rate-provider instance (12.2). The behavior calls `_newFixture()` twice (lines 87-88), so the row deploys two instances of this fixture, one per SE leg, and caches the package in `sharedPkg` exactly as the V3 row does.
- Rate target: Row A binds leg 0 to the first instance's `currency0` face with `rateProvider0 = deployRateProvider(vault0, currency0)`; Row B binds leg 0 to the first instance's `currency1` face with `rateProvider0 = deployRateProvider(vault0, currency1)`. Leg 1 keeps its own instance and `rateProvider1 = deployRateProvider(vault1, itsFace)`. The two rows are two hook product PoolKeys holding the same vault at different rate targets.
- Pool currencies and indices: two. `token0` (leg 0's face) and `token1` (leg 1's face), address-sorted; `faceIsC0 = dual.currency0() == face` (behavior line 136). **No pool currency is this vault's share**: the share is held off-pool by the hook as its buffered inventory.
- Directions and legs: two SE legs, both of this family. Two directed exact-input swaps on the pair: leg 0 face→leg 1 face and leg 1 face→leg 0 face.
- Inherited assertions that cannot pass: rules A, B, C, D, E and F. The canonical cross-vault case is in 12.6 and is the reason this family carries the proof.

#### 12.3.4 `orbital/`

- Behavior path: `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol`.
- New files beside it:
  - sibling behavior `orbital/UniswapV4FullSpreadStandardExchangeVault_orbital.behavior.sol`;
  - row `orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- Fixture: `SeMatrix_FullSpreadV4Fixture.sol`, instantiated three times (behavior lines 91-93). Each instance deploys this vault, its own bound hookless Uniswap V4 pool, its own two face tokens, and its own external rate-provider instance.
- Rate target: Row A binds leg 0's token to instance 0's `currency0` face with `rp0 = deployRateProvider(vault0, currency0)`; Row B binds leg 0's token to instance 0's `currency1` face with `rp0 = deployRateProvider(vault0, currency1)`. `rp1` and `rp2` are the corresponding providers for instances 1 and 2. The package fields are `rp0`, `rp1`, `rp2`.
- Pool currencies and indices: three legs. The leg tokens are `token0`, `token1`, `token2` in package order, not address order (behavior lines 143-145). **No leg token is this vault's share.** Each product pool is a currency-sorted pair built by `PairPoolLib.pairKey(faceI, faceJ, spacing 60, hook)`: `poolKey01` over legs 0-1, `poolKey12` over legs 1-2, `poolKey02` over legs 0-2. The share index inside each pair is none.
- Directions and legs: three legs, all of this vault — leg 0 is the leg under test, legs 1 and 2 are second and third instances of the same family. Six directed exact-input swaps: both directions on each of the three pair pools. The family row's role naming is leg 0 = this vault under test, legs 1 and 2 = the same family in the other roles (PRD `FS-HOOK-01`: "A valid three-leg bind with FullSpread buffered on one leg and another SE share on another, roles named").
- Inherited assertions that cannot pass: rules A, B, C, D, E and F. The residual assertion on the leg swapped into is unchanged; the booked-remainder row uses leg 0's fixture only.

#### 12.3.5 `weighted/`

- Behavior path: `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol`.
- New files beside it:
  - sibling behavior `weighted/UniswapV4FullSpreadStandardExchangeVault_weighted.behavior.sol`;
  - row `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- Fixture: `SeMatrix_FullSpreadV4Fixture.sol` — this vault, its bound hookless Uniswap V4 pool, the two face tokens, and the external rate-provider instance (12.2).
- Rate target: Row A binds the vault to the currency that holds the vault's `currency0` face, with the leg's `rateProviders[faceIdx] = deployRateProvider(vault, currency0)`; Row B binds the vault to the currency that holds the vault's `currency1` face, with `rateProviders[faceIdx] = deployRateProvider(vault, currency1)`. `rateProviders[otherIdx]` is `address(0)`, because the raw leg has no SE (the package's `providersFor` helper already yields zero for a zero-SE leg).
- Pool currencies and indices: two. The vault's face and the base's raw `token1`. **No pool currency is this vault's share.** The indices are address-ordered and are computed, not assumed: `faceIdx = 0` when `face < other`, else `faceIdx = 1` (behavior lines 87-96). The raw leg takes `otherIdx` and has no SE and is not buffered.
- Directions and legs: two legs — the vault leg (buffered, with a provider) and the raw leg (transfer only). Two directed exact-input swaps on the pair: face→raw and raw→face.
- Inherited assertions that cannot pass: rules A, B, C, D, E and F. One family-level addition is required by PRD `FS-HOOK-01` for this family: "At least a 2-leg setup and one larger supported setup." The inherited behavior builds exactly two currencies inside `setUp()` (lines 80-102), and `setUp()` is `public virtual override`, so the sibling behavior file overrides `setUp()` to add the larger setup with `n > 2` against the package's `n` in 2 through 8. The larger setup binds additional legs of the same family, each with its own instance of the fixture and its own provider.

#### 12.3.6 `stable/quad/curve/`

- Behavior path: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol`.
- New files beside it:
  - sibling behavior `stable/quad/curve/UniswapV4FullSpreadStandardExchangeVault_curveQuadStable.behavior.sol`;
  - row `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- Fixture: `SeMatrix_FullSpreadV4Fixture.sol`, instantiated four times and sorted ascending by face token (behavior lines 96-115), because the package rejects `TokensNotAscending`. Each instance deploys this vault, its own bound hookless Uniswap V4 pool, its own two face tokens, and its own external rate-provider instance.
- Rate target: Row A binds leg 0 to instance 0's `currency0` face with `rateProviders[0] = deployRateProvider(vault0, currency0)`; Row B binds leg 0 to instance 0's `currency1` face with `rateProviders[0] = deployRateProvider(vault0, currency1)`. The other three legs keep their own instance and their own provider.
- Pool currencies and indices: four legs, in the ascending face-token order produced by the sort. `faceIdx = 0` is the leg under test and `otherIdx = 1` (behavior lines 119-120). **No leg token is this vault's share**: the four pool currencies are four distinct face tokens of four vault instances.
- Directions and legs: four legs, all of this vault — leg 0 under test, legs 1 to 3 the same family in the other roles. The four-currency pool has six pairs; the family row exercises both directions on the leg-0/leg-1 pair, and the sibling behavior file extends that to the remaining pairs, because PRD `FS-HOOK-01` requires four valid legs and "Do not treat a volatile share as a peg".
- Inherited assertions that cannot pass: rules A, B, C, D, E and F.

#### 12.3.7 `stable/quad/balancer/`

- Behavior path: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol`.
- New files beside it:
  - sibling behavior `stable/quad/balancer/UniswapV4FullSpreadStandardExchangeVault_balancerQuadStable.behavior.sol`;
  - row `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
- Fixture: `SeMatrix_FullSpreadV4Fixture.sol`, instantiated once per SE leg. The default is four SE legs; `_seLegCount()` may lower it, and the remaining legs are the base's raw 18-decimal tokens `token0` through `token3` with no SE, no provider and not buffered (behavior lines 30-31, 68-70, 106-115). Each SE-leg instance deploys this vault, its own bound hookless Uniswap V4 pool, its own two face tokens, and its own external rate-provider instance.
- Rate target: Row A binds the leg under test to its instance's `currency0` face with `rateProviders[faceIdx] = deployRateProvider(vault, currency0)`; Row B binds the same leg to that instance's `currency1` face with `rateProviders[faceIdx] = deployRateProvider(vault, currency1)`. Raw legs take `address(0)`.
- Pool currencies and indices: four legs, sorted ascending by token address (behavior lines 106-155). `faceIdx` is the lowest-address SE leg; `otherIdx` is the first raw leg, or the next SE leg when every leg is an SE leg (line 148). **No leg token is this vault's share.**
- Directions and legs: four legs. At the default, all four are this vault; at a lowered `_seLegCount()`, the remainder are raw legs. Six pairs; the family row exercises both directions on the leg-under-test/leg-`otherIdx` pair, and the sibling behavior extends that to the remaining pairs.
- Inherited assertions that cannot pass: rules A, B, C, D, E and F. One family-level addition is required by PRD `FS-HOOK-01` for this family: "A 2-leg setup and a 5-leg setup. Do not copy a fixed-four constructor." The inherited behavior fixes `LEGS = 4` as a constant (line 37) and builds the legs in a non-virtual `_buildLegs()` (line 104), so neither can be changed by overriding a virtual hook. The sibling behavior file therefore overrides `setUp()` to add the 2-leg and 5-leg setups against the package's dynamic arrays (`tokens[]`, `standardExchanges[]`, `rateProviders[]`, 2 through 5 legs). The V4 row does not inherit the fixed-four shape as its only coverage.

### 12.4 Inherited assertions that cannot pass, and the adaptation

Rule A — **exact output fails closed.** This vault has no exact-out route: `exchangeOut` reverts `ExchangeOutNotAvailable` on an enabled vault and `previewExchangeOut` returns zero (plan line 142; PRD `FS-HOOK-03`, line 510; PRD line 470). The hooks reach that route at `dual/...HookCommon.sol:394`, `dual/...HookClaimLib.sol:118` and `:130`, `single/...HookCommon.sol:103-104`, `:118-119` and `:147`. Adaptation: `test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed` and `test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly` cannot pass and are replaced by fail-closed assertions — the call reverts, neither token is paid, and no input is taken (PRD `FS-A28`, line 581). The exact-out half of `test_row_previewMatchesExecution` is replaced by an assertion that the vault's exact-out preview is zero and that the hook's exact-out path reverts. The exact-in halves are kept unchanged.

Rule B — **unused user input is refunded, and the refund tuple is the assertion.** This vault returns `(amountOut, amountRefunded)` and refunds the unused declared input to `msg.sender` (plan lines 94, 120, 158, 216). The hook calls `exchangeIn(..., address(this), false, block.timestamp)`, so `msg.sender` is the hook, not the end user. Adaptation: the D33 booked-remainder row's "no refund of the unconsumed part" assertion becomes: the caller is debited the declared amount, the vault returns the unconsumed part as `amountRefunded`, and that refund is credited to `msg.sender` — the hook — where the hook either re-buffers it or keeps it as resting credit (`dual/...HookCommon.sol` `_refundPairDust`). A donation or compound remainder is booked and is not refunded (plan line 184; PRD `FS-TEST-04`, line 608), so the booked-remainder rows stay.

Rule C — **the one-word decode.** Every read of `previewExchangeIn` or `exchangeIn` against this vault decodes `(amountOut, amountRefunded)`; `amountOut` is the compared value and the refund word is asserted separately where it matters. The shared behaviors read through `IStandardExchangeIn`, which keeps a one-word signature; the ABI decoder ignores the trailing return word, so the inherited exact-in comparisons keep working unchanged, but the row's own new assertions read the tuple through this family's interface.

Rule D — **`reserveOfToken` is not a local-balance view.** `reserves()` and `reserveOfToken` report the position-implied amount (plan section 4). `test_row_ammCallerFundSeparation` compares `reserveOfToken(face)` before and after an other-token caller; for this family the position changes when the other face is deposited, so that comparison cannot hold as written. Adaptation: compare the per-face local balance and the per-face booked amount instead, and assert that the other-face caller did not consume the first face's local balance.

Rule E — **the operative-failure injection point moves.** The V3 fixture mocks `IUniswapV3Pool.mint`; this vault's operative calls are the PoolManager `swap` and `modifyLiquidity` inside its own unlock (plan sections 8 and 9). Adaptation: `SeMatrix_FullSpreadV4Fixture.armOperativeRevert()` makes the bound PoolManager call revert with `rejectBytes()`. The expected revert bytes are per family: the `single/` hook wraps a hook revert in `CustomRevert.WrappedError` (behavior lines 172-181), while the constant-product, dual, orbital, weighted, Curve and Balancer rows surface `rejectBytes()` directly.

Rule F — **the identity bind is a record, not a pass.** An identity bind of `token == this vault` makes the rate-provider package price the vault against `IERC4626(se).asset()` (`contracts/test/libs/RateProviderFixtureLib.sol`, `providerFor`). This vault has no `asset()` (plan section 5) and none may be added (PRD `FS-A24`, line 577; PRD `FS-HOOK-04` item 3, line 519). Adaptation: the row attempts the identity bind, records the rejection under `FS-HOOK-04`, and does not pass on it. That record does not close the canonical proof in 12.6 and does not close the `FS-OWN-29` rate rows.

Rule G — **the booked-remainder rows stay.** A donation or compound remainder is booked, so the D22/D31 booked-remainder rows are not withdrawn for this family (PRD `FS-TEST-04`, line 608). This replaces the earlier sentence that said booked-remainder rows cannot pass.

### 12.5 The disjoint backing PoolKey rule

The canonical cross-vault fixture uses **two different backing pool keys**. The vault's own backing pool key is the hookless pool it holds its position in (`hook == address(0)`, plan line 69); the hook's product pool key always carries a hook address, so it is a different PoolKey by construction. One direction mints this vault's shares while the manager is unlocked; the reverse burns them. The row asserts balances, position owner, ticks, salt, and per-address deltas — not only that no tokens moved (PRD `FS-HOOK-02` item 3; PRD `FS-A26`, line 579).

**Same-backing-pool sequential composition stays unverified.** It is neither impossible nor passed, and the disjoint-pool fixture does not report it as passed (PRD `FS-HOOK-02`, closing paragraph; PRD `FS-A30`, line 583). No row in this matrix may be cited as evidence for a sequential composition against one and the same backing PoolKey.

### 12.6 The canonical dual cross-vault case

The canonical proof is the `dual/` topology, and its binding is fixed:

- Leg 0 is this vault, the buffered leg. `standardExchange0` is the vault, `token0` is the vault's face, and `rateProvider0` is the external instance for that vault and that face.
- Leg 1 is a second Standard Exchange, and it is **not asked to convert under an unlock it does not support**. The hook must never call leg 1's vault to mint or redeem inside the outer unlock, because the current PairToken family rejects that context. Leg 1's leg token is therefore a plain ERC-20 face of a second instance of this family, not leg 1's share: the hook accepts it as a transfer without calling that vault (PRD `FS-HOOK-02` item 2). The row asserts that leg 1's vault's balances and share count are unchanged across the leg-0 operation.
- The identity variant — leg 1's token being leg 1's share — is attempted only if the current package accepts `token == se` without `asset()`. For this family the rate-provider package needs `asset()`, so the identity bind is rejected. It is recorded under `FS-HOOK-04` and is not a pass, and `asset()` is not added (Rule F).
- `single/` is not a two-vault proof (PRD `FS-HOOK-01`). Its family row proves the one-vault borrowed `exchangeIn` through the hook's `beforeSwap` in both exact-input directions, and nothing about the cross-vault case.

### 12.7 The plan sentence that blocks this matrix

**Section 3, line 51.** The sentence reads: "The matrix adapter is `SeMatrix_FullSpreadV4Fixture.sol` in that directory." "That directory" is `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`. The adapter must instead be `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol`, beside `SeMatrix_FullSpreadV3Fixture.sol` and `SeMatrixFixture.sol`, because all seven shared behaviors import `SeMatrixFixture` from that directory and the row files import the family fixture from there. That one sentence must change; the rest of section 3 stands.

Two further sentences inside the replaced section 12 are corrected by the text above: the seven cited behavior paths at plan lines 204-210 become the seven real paths in 12.3, which also restores the omitted non-CP `single/` family and drops the `stable/` entry that has no counterpart; and the sentence at plan line 212 naming the sibling files is made concrete by the seven sibling behavior names and the seven row names in 12.3. Plan section 13's reference to "the seven sibling behavior files" (line 230) stays true and needs no change.

Everything else in the plan — the return-width migration at line 216, the gas ceilings, the selector cut, the disable predicate, the audit inventory — is unchanged by this matrix and is not reopened here.

# Limits

- This is a research advisory. It does not authorize implementation, tests, installs, deployment, wallet use, configuration changes or Git.
- No test, build, lint or compile was run. Every statement about behaviour is read from the cited source, not observed at runtime.
- The vault family does not exist yet: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/` holds only the PRD, the plan, `IMPLEMENTATION_PLAN_BLOCKERS.md` and `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`. The matrix therefore binds to the plan's and the PRD's written rules for a vault that is not yet built, and it cannot be checked against a running artifact.
- The sibling behavior and row file names in 12.3 apply the plan's own pattern `UniswapV4FullSpreadStandardExchangeVault_<topology>.behavior.sol` with `<topology>` bound to the PRD `FS-HOOK-01` family key. The row names follow the existing V3 row names with the family token changed from `UniswapV3` to `UniswapV4`. Both are naming decisions the coordinator may reset; the bindings they carry are not.
- The fixture's `seBooked()` and `partialDeploymentBalance()` definitions in 12.2 are derived from the plan's statement that no booked getter is installed. If the implementation exposes a booked or local-reserve getter, those two definitions should be re-pointed at it and the row's booked assertions tightened. No new vault selector is requested here.
- The `weighted/` larger-setup and the Balancer 2-leg and 5-leg setups required by PRD `FS-HOOK-01` are not expressible by overriding the inherited virtual hooks, because the inherited behaviors fix the leg arrays in `setUp()` and in a non-virtual `_buildLegs()`. The matrix binds them to the sibling behavior file's `setUp()` override; if the coordinator prefers a different file split, that binding moves with it.
- I did not read the coordinator's draft, `IMPLEMENTATION_PLAN_BLOCKERS.md`, `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`, the evidence files under `docs/audits/`, `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md`, or any peer member file. Where the plan's sentence at line 216 points at the preview-consumer index, I named the hook call sites I read directly and did not enumerate the index.
- The `FS-HOOK-04` record for the identity bind is a fixture-construction rejection in the rate-provider helper, not a hook-package rejection. The matrix states it as such and does not claim the hook packages reject it.
- I read the seven hook package interfaces, the rate-provider helper, and the dual and non-CP single hook `Common` and `ClaimLib` files in addition to the admitted targets, because the seven behaviors import the helper and the matrix cannot name a rate-target or an exact-out binding without them. No other production hook source was read.
