# Product Requirements Document (PRD)

## Title

**Unified DETF × production SE × hook matrix tests**: hermetic Foundry proof that `UniswapV4DetfDFPkg` works with every in-scope SE buffer hook and every in-scope Standard Exchange: Uni V3 SE, Uni V4 SE, Morpho Blue SE, pons v1 Uni V3 pools, and pons v2 graduated Uni V4 pools

---

## 1. Header

| Field | Value |
|-------|--------|
| **Status** | **DONE** (2026-08-27; tests only; no product-law reopen) |
| **Kind** | Test PRD. Authorizes tests + TestBases. Does **not** authorize Dual-as-hook, Balancer DETF I/O, native-ETH quote, or ERC-4626 as production proof |
| **Date** | 2026-08-27 |
| **Home** | `contracts/vaults/detf/UNIFIED_DETF_PRODUCTION_SE_HOOK_MATRIX_TEST_PRD.md` |
| **Product law** | [`DETF_INSTANCE_IO_ROUTING_PRD.md`](./DETF_INSTANCE_IO_ROUTING_PRD.md) **§16 wins**. R19 dust. R20 pons v2. §15.12 hook ABI. Dual cannot bind. Morpho SE: [`MorphoBlueStandardExchange_PRD.md`](../standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchange_PRD.md) D1–D37 (do not reopen) |
| **Unwrap incident** | [`docs/testing/UNIV4_SE_BUFFER_UNWRAP_COVERAGE_GAP_REPORT.md`](../../docs/testing/UNIV4_SE_BUFFER_UNWRAP_COVERAGE_GAP_REPORT.md). ERC-4626 unwrap is **not** proof of Uni V3 or Uni V4 SE share pull |
| **Skills** | `crane-testing`, `indexedex-testing`, `indexedex-uniswap-v4-hook-packages`, `pons-architecture`, `crane-deployment`, `crane-morpho` |
| **Law** | Root `Claude.md`; [`docs/agent/INDEXEDEX_AGENT_LAW.md`](../../docs/agent/INDEXEDEX_AGENT_LAW.md) |
| **Worktree prefix** | `unified_detf_se_` |
| **Execute** | This PRD is the implementor sheet. A separate execute-plan file is optional. Do not invent extra configurations |

**Short name:** unified DETF production SE/hook matrix.

---

## 2. Intent

The unified DETF (`UniswapV4DetfDFPkg`) is the v1 Uni V4 DETF product. Gold TestBases bind **ERC-4626 wrapper** SEs. That wrapper **burns `msg.sender`** on share redeem. Production Uni V3 SE and Uni V4 SE **`safeTransferFrom`** when `pretransferred=false`. Live 4663 CP DETF burn/close failed `TransferFromFailed` (`0x7939f424`) because the hook had SE-share allowance 0. ERC-4626 suites could not fail that.

Robinhood production legs are:

- pons **v1**: Uniswap **V3** pool from create, wrapped in **Uni V3 Standard Exchange**
- pons **v2**: bonding curve then Uniswap **V4** graduation (`fee == 0`, `PonsV2MemeHook`), wrapped in **Uni V4 Standard Exchange**
- the same two SE packages wrapping ordinary (non-pons) V3 / V4 pools
- **Morpho Blue Standard Exchange**: supply-only lend of one ERC-20 on one already-existing Morpho Blue market (`MorphoBlueStandardExchange`). Hook pair **is** that market’s `loanToken`. Not Morpho Vault V2 / MetaMorpho. Not a Morpho-loop DETF.

This PRD locks the **exact** fixtures, money paths, names, and matchers. Implementors do not pick hook families, SE types, SE-leg masks, threshold mode, route-table mode, or which token to mint/burn.

---

## 3. Product under test (LOCKED)

| Item | Value |
|------|--------|
| DETF DFPkg | `UniswapV4DetfDFPkg` at `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/` |
| Bond NFT | `contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/` (R12a) |
| Hook ABI | `IUniswapV4SeBufferHook` / §15.12 |
| Discovery | `hook.tokens()`, `hook.standardExchangeOf`, route-table getters. Not `IDetf.pairToken()` / `rateAsset()` / `underlyingVault()` |
| `reservePool()` | hook address |
| Deploy | Hook DFPkg first (predicted DETF as raw/owner). DETF via `indexedexManager.deploy*` / registry. Never `new` facets/DFPkgs. Never Dual as `PkgArgs.hook` |

**Not this PRD’s SUT:** old CP / Orbital / Weighted / Quad **DETF packages** under `…/standardExchange/**`. Leave them. Do not treat their ERC-4626 or Univ4Se suites as acceptance for this matrix.

---

## 4. In scope / out of scope (LOCKED)

### 4.1 In

1. Same unified DETF DFPkg bound to these **four** hooks:
   - CP single SE buffer (`UniswapV4SingleStandardExchangeBufferConstantProductHook*`)
   - Orbital SE buffer
   - Weighted SE buffer, **n = 3** (DETF + two pairs)
   - Curve quad stable SE buffer, **n = 4** (DETF + three pairs)
2. Every external hook pair has a bound `IStandardExchange` (`standardExchangeOf(t) != 0`). Bare pair legs **revert deploy** (§15.13). Do not test bare-pair binds.
3. Five **SE sources** (homogeneous fixtures: every external leg uses the same source class):
   - **G-V3:** Uni V3 Standard Exchange on a hermetic vanilla V3 pool
   - **G-V4:** Uni V4 Standard Exchange on a hermetic vanilla V4 pool (no IndexedEx buffer hook on that pool)
   - **P1-V3:** Uni V3 Standard Exchange on a **pons v1** launched Uni V3 pool
   - **P2-V4:** Uni V4 Standard Exchange on a **pons v2** graduated Uni V4 pool (R20)
   - **MB-BLUE:** Morpho Blue Standard Exchange on a hermetic Morpho Blue market (`loanToken` = that hook pair)
4. Six **mixed** fixtures. Exact maps in §6.2. Three pons v1+v2. Three Morpho + Uni (I/O Weighted Morpho/Uni host and peers).
5. Money paths in §7 on **every** fixture in §6.
6. Anti-theater: `IERC20(se).allowance(hook, se) == 0` for **every** bound SE before burn and before close.
7. R19: after each successful money path, diamond `balanceOf` hook LP, each `hook.tokens()` entry, and each bound SE share is 0 when a join of that residual was possible.

### 4.2 Out (do not add)

| Item | Reason |
|------|--------|
| Dual SE CP as `PkgArgs.hook` | §16 / T7.1 already reverts. Do not add Dual fixtures here |
| Balancer quad buffer hook | Not a v1 unified-DETF host |
| Balancer-hosted DETFs | I/O follow-on |
| ERC-4626 wrapper as production proof | Theater for V3/V4 share pull. Keep existing T7/T8 as **regression only** |
| Native ETH (`address(0)`) as SE pool currency | R20 v1: WETH quote only |
| ThresholdMode.Policy drive on these fixtures | Use **Open** so mint/burn are reachable. Policy remains T7.8 on ERC-4626 |
| Custom route tables on these fixtures | All five tables **Default**. Custom close remains T7.11 / T8.3 on ERC-4626 |
| FoT / rebasing underlyings | Token policy. T7.15 already exists |
| Fork 4663 pons v2 | No published v2 addresses. Hermetic Crane stack is the bar |
| Family DETF Univ4Se (CP single package) | Different DFPkg. Already has burn/close. Not this matrix |
| Morpho Vault V2 / MetaMorpho / Steakhouse wrap | Different package (`…/morpho/vault-v2/`). Not `MorphoBlueStandardExchange` |
| Morpho-loop DETF (borrow against `detfToken`) | Later package. This matrix binds Morpho SE as a **hook pair leg** only |
| Morpho-illiquid close (`InsufficientLiquidity` when Blue has no cash) | Later package. These fixtures keep Morpho cash (no borrow of vault supply) |
| Aave / Camelot / Aerodrome as bound SE | Not current production targets |
| Mixing SE sources except the six mixed rows in §6.2 | Do not invent extra mixes |
| `via_ir` | Forbidden |
| `vm.mockCall` of SUT | Forbidden |
| Live 4663 diamondCut | Abandoned instance |

---

## 5. Fixture constants (LOCKED)

Use these on every row unless a row overrides.

| Constant | Value |
|----------|--------|
| `thresholdMode` | `ThresholdMode.Open` |
| All five `RouteTableMode` | `Default` |
| Custom route arrays | empty (`new IoRoute[](0)`) |
| `creationPairPerDetfWad` | length `n-1`, each `1e18` |
| `openingPairPerDetfWad` | empty (resolves to creation) |
| Expansion fields | 0 |
| `DEFAULT_MIN_LOCK` | 30 days |
| `DEFAULT_MAX_LOCK` | 180 days |
| First-bond pair amount | `100 ether` of **each** non-DETF `hook.tokens()` entry (WAD 18). First bond still full `tokens()` including DETF self-leg (R9 / D16) |
| Live mint amount | `10 ether` of **mint token** (§7.2) |
| Live burn | `minted / 2` DETF, `tokenOut` = mint token |
| Close warp | `block.timestamp + DEFAULT_MIN_LOCK + 1` |
| Close `minAmountsOut` | `new uint256[](hook.tokens().length)` all zeros. DETF slot must stay 0 |
| Uni V4 SE liquid reserve type default | `0.2e18` |
| Uni V3 SE liquid reserve type default | `0.20e18` |
| Generic V3 pool fee | `3000` |
| Generic V4 pool | `fee = 3000`, `tickSpacing = 60`, `hooks = address(0)` |
| Generic V4 seed | `UniswapV4CpBufferSePoolSeeder` (or copy): ±120 ticks, `100_000 ether` each side |
| Generic V3 seed | `TestBase_UniswapV3StandardExchange._seedExternalLiquidity` / full-range ticks as that TestBase |
| Uni V4 SE TWAP | Required. Oracle `poolManager` **is** the hook’s `pm`. Missing TWAP reverts `ZeroTwapOracle()` (`0x994a506d`) |
| Uni V4 SE + hook PoolManager | **One** `PoolManager` for hook, every Uni V4 SE, and pons v2 graduation |
| Uni V3 factory | One hermetic `UniswapV3Factory` for every Uni V3 SE and pons v1 launch on that fixture |
| Morpho singleton | One hermetic Crane `Morpho` (`new Morpho`) per fixture that has an MB-BLUE leg. Shared by every Morpho SE on that fixture |
| Morpho IRM | `AdaptiveCurveIrm` enabled on that singleton |
| Morpho oracle | `OracleMock` at `ORACLE_PRICE_SCALE` (`1e36`) |
| Morpho LLTV | `0.8e18` (`TestBase_MorphoBlue.DEFAULT_LLTV`). Enable that LLTV on the singleton before `createMarket` |
| Morpho collateral | One dummy ERC-20 per fixture. **Not** in `hook.tokens()`. **Not** DETF. Reuse that dummy as `collateralToken` on every Morpho market on the fixture (loan tokens differ) |
| Morpho borrow | **Forbidden** on these fixtures. Do not call `_borrowFromMarket`. Morpho cash must stay available for unwrap |
| Morpho usage fee | `0` (package D30 default). Do not set a non-zero lending usage fee on these rows |
| Morpho `feeRecipient` | Crane TestBase `FEE_RECIPIENT`. **Never** the SE diamond (Blue `expectedSupplyAssets` is wrong for the market fee recipient) |
| SE other token (generic Uni) | New `SimpleMintableERC20("Rate", "RATE")` **per Uni V3/V4 SE**. Not a hook `tokens()` member. Not DETF. Morpho SE has **no** other vault token (`vaultTokens() = [loanToken]`) |
| Two pairs must not share one SE | §16.8. One SE vault per pair |
| Owner-only hook liquidity | `true`; owner = predicted DETF |

### 5.1 Mint token (LOCKED)

`mintToken` = the first address in `hook.tokens()` that is **not** `detf`.

Do not use a local `pair0` variable if it can disagree with `tokens()` order after CREATE2. Read `tokens()` after hook finalize.

Burn `tokenOut` = that same `mintToken`.

### 5.2 Share-pull anti-theater (LOCKED)

Before `burn` and before `closeBondMature`:

```solidity
for each bound SE address se:
    assertEq(IERC20(se).allowance(reserveHook, se), 0);
```

Do not `approve` from the hook in the test. Success on a generic ERC-4626 wrapper SE does not close a row.

Share pull by SE class when `pretransferred=false`:

| SE | Mechanism | Missing hook `forceApprove` |
|----|-----------|------------------------------|
| Uni V3 SE | `_secureShareDelivery` → `safeTransferFrom(hook, se)` | **Must revert** (`TransferFromFailed`) |
| Uni V4 SE | same | **Must revert** |
| Morpho Blue SE | `_burnSeShares(shareOwner)` with `shareOwner = msg.sender` (the hook). `_maybeSpendAllowance` is a no-op when `msg.sender == owner` | Unwrap **succeeds** without allowance. Still assert allowance 0. Do **not** drop Morpho rows as “ERC-4626 theater”: the SUT is `MorphoBlueStandardExchange` supplying Blue |

The hook production path still `forceApprove`s before unwrap. Tests must not pre-approve.

### 5.3 Deploy path (LOCKED)

1. `IndexedexTest` / vault components / Permit2 etch at `0x000000000022D473030F116dDEE9F6B43aC78BA3`.
2. Construct `pm` **before** any Uni V4 SE `deployVault`.
3. If the fixture has an MB-BLUE leg: construct Morpho singleton, enable IRM + LLTV, deploy dummy collateral + oracle, **`createMarket` for each Morpho pair** (D28), **then** `indexedexManager.deployMorphoBlueStandardExchangeDFPkg` and `pkg.deployVault({morpho, marketParams})`. The vault never `createMarket`.
4. Deploy Uni V3 and/or Uni V4 SE DFPkgs via `indexedexManager.deploy*DFPkg` then `pkg.deployVault`.
5. Hook package via registry + hook factory. `deployHookVault` / package `deployVault(..., mineNonce)`.
6. DETF `detfPkg.deployVault(args, nonce)` via manager. Predicted address matches.
7. `ensureReserveReady*` / staged doors + `finalizeInitialization` **before** DETF `processArgs` reads `hook.tokens()`.

Copy `_ensureUniv4SePkg` / seeder from `TestBase_UniswapV4CpBufferUniv4Se.sol`. Copy Uni V3 pkg init from `TestBase_UniswapV3StandardExchange`. Copy pons v2 manager injection from `TestBase_UniswapV4StandardExchange_PonsV2` / Stage 10. Copy Morpho facets + `PkgInit` / `deployVault` from `TestBase_MorphoBlueStandardExchange`. Copy Morpho singleton + `createMarket` from Crane `TestBase_MorphoBlue`, but **do not** use that TestBase’s `loanToken = new ERC20Mock()`: `loanToken` **is** the hook pair.

Do **not** diamond-inherit `TestBase_UniswapV4CpBufferUniv4Se`, `TestBase_MorphoBlueStandardExchange`, or `TestBase_MorphoBlue` together with `TestBase_UniswapV4Detf` (setUp / `_feeTo` / `loanToken` clash). Duplicate `_deployPairSideSe` / Morpho helpers or extract a library.

---

## 6. Exact configuration catalog

Each row is one TestBase (or one `setUp` variant). Names are mandatory.

Hook arity:

| Hook | `n = hook.tokens().length` | External pairs | Bound SEs |
|------|----------------------------|----------------|-----------|
| CP | 2 | 1 | 1 |
| Orbital | 3 | 2 | 2 |
| Weighted | 3 | 2 | 2 |
| Quad | 4 | 3 | 3 |

`creationPairPerDetfWad.length == n - 1`.

### 6.1 Homogeneous rows (20)

Every external pair uses the **same** SE source class. Each pair has **its own** pool (Uni) or Morpho market (MB-BLUE) and **its own** SE vault.

| ID | Hook | SE source | Bound SEs | Pool / market |
|----|------|-----------|-----------|----------------|
| **H-CP-GV3** | CP | G-V3 | 1 Uni V3 SE | Vanilla V3: `mintToken` / Rate, fee 3000 |
| **H-CP-GV4** | CP | G-V4 | 1 Uni V4 SE | Vanilla V4: `mintToken` / Rate, fee 3000, no hook |
| **H-CP-P1** | CP | P1-V3 | 1 Uni V3 SE | One pons v1 launch; pool = launch token / WETH, fee 10000, tickSpacing 200 |
| **H-CP-P2** | CP | P2-V4 | 1 Uni V4 SE | One pons v2 WETH-quoted launch, graduated; `fee == 0`, hooks = `PonsV2MemeHook` |
| **H-CP-MB** | CP | MB-BLUE | 1 Morpho Blue SE | One Blue market: `loanToken = mintToken`. §8.3 |
| **H-OR-GV3** | Orbital | G-V3 | 2 Uni V3 SE | Two vanilla V3 pools |
| **H-OR-GV4** | Orbital | G-V4 | 2 Uni V4 SE | Two vanilla V4 pools |
| **H-OR-P1** | Orbital | P1-V3 | 2 Uni V3 SE | Two pons v1 launches (two launch tokens, both / WETH) |
| **H-OR-P2** | Orbital | P2-V4 | 2 Uni V4 SE | Two pons v2 WETH launches, both graduated |
| **H-OR-MB** | Orbital | MB-BLUE | 2 Morpho Blue SE | Two Blue markets, one per pair. Same Morpho singleton |
| **H-WE-GV3** | Weighted | G-V3 | 2 Uni V3 SE | Two vanilla V3 pools |
| **H-WE-GV4** | Weighted | G-V4 | 2 Uni V4 SE | Two vanilla V4 pools |
| **H-WE-P1** | Weighted | P1-V3 | 2 Uni V3 SE | Two pons v1 launches |
| **H-WE-P2** | Weighted | P2-V4 | 2 Uni V4 SE | Two pons v2 graduated pools |
| **H-WE-MB** | Weighted | MB-BLUE | 2 Morpho Blue SE | Two Blue markets, one per pair |
| **H-QD-GV3** | Quad | G-V3 | 3 Uni V3 SE | Three vanilla V3 pools |
| **H-QD-GV4** | Quad | G-V4 | 3 Uni V4 SE | Three vanilla V4 pools |
| **H-QD-P1** | Quad | P1-V3 | 3 Uni V3 SE | Three pons v1 launches |
| **H-QD-P2** | Quad | P2-V4 | 3 Uni V4 SE | Three pons v2 graduated pools |
| **H-QD-MB** | Quad | MB-BLUE | 3 Morpho Blue SE | Three Blue markets, one per pair |

Weighted equal weights: `0.5e18` / `0.5e18` on the two pairs (DETF self-leg has no weight). Quad `baseAmp = 100`.

Hook `standardExchangeOf(pair) =` that pair’s SE. DETF self-leg has no SE.

**H-CP-P2** extends `TestBase_UniswapV4Detf_PonsV2Se`. Add burn + close. Do not replace T10.8–T10.10.

### 6.2 Mixed rows (6)

Two production mixes. Do not invent others.

**Pons mix:** one DETF holds a pons v1 token and a pons v2 token.

| ID | Hook | Pair → SE (in `tokens()` order, skipping DETF) |
|----|------|-----------------------------------------------|
| **M-OR-P1P2** | Orbital | [0] pons v1 launch token → Uni V3 SE on that v1 pool; [1] pons v2 launch token → Uni V4 SE on that graduated pool |
| **M-WE-P1P2** | Weighted | Same map as M-OR-P1P2 |
| **M-QD-P1P2G4** | Quad | [0] pons v1 → Uni V3 SE; [1] pons v2 → Uni V4 SE; [2] generic vanilla V4 pair → Uni V4 SE |

`mintToken` on these three rows is the pons v1 launch token.

**Morpho + Uni mix:** I/O product host is Weighted with a Morpho-lent pair and a Uni V4 pair (`DETF_INSTANCE_IO_ROUTING_PRD.md` TT/Morpho). Default route tables still (this PRD does not turn on Custom). Morpho is always pair [0] so `mintToken` is the Morpho `loanToken`.

| ID | Hook | Pair → SE (in `tokens()` order, skipping DETF) |
|----|------|-----------------------------------------------|
| **M-OR-MBGV4** | Orbital | [0] Morpho Blue SE (`loanToken` = pair0); [1] G-V4 Uni V4 SE on pair1 / Rate |
| **M-WE-MBGV4** | Weighted | Same map as M-OR-MBGV4 |
| **M-QD-MBGV4P1** | Quad | [0] Morpho Blue SE (`loanToken` = pair0); [1] G-V4 Uni V4 SE; [2] pons v1 launch token → Uni V3 SE |

Do not mix G-V3 with G-V4 except as pair [2] on **M-QD-P1P2G4**. Do not put Morpho on pair [1] or [2]. Do not bind two Morpho SEs on a mixed row.

### 6.3 Config count

26 fixtures. No others.

---

## 7. Money paths on every fixture (LOCKED)

Each fixture implements **all four**. Names: `test_<ID>_<path>` with `<ID>` from §6 (`H_CP_GV4` style in Solidity: `test_H_CP_GV4_firstBond`).

| Path | Function | Assert |
|------|----------|--------|
| **firstBond** | `_firstBond(100 ether)` (or equivalent full-book `bond` / `joinUnbalanced`) | `tokenId > 0`; shares > 0; `isReserveLive()`; R19 diamond clean |
| **mint** | After firstBond: `detfInfo.mint(mintToken, 10 ether, 0, detfUser, false, deadline)` | `out > 0`; `previewMint == exec`; R19; hook SE allowance still 0 after mint |
| **burn** | After mint: assert SE allowances 0; `burn(minted/2, mintToken, 0, detfUser, deadline)` | `previewBurn == exec`; user `mintToken` delta = out; DETF supply drops by burn-in; leftover LP on Bond NFT not diamond; R19 |
| **close** | After firstBond + mint (so hook stays live); warp min lock + 1; allowances 0; `closeBondMature(tokenId, minOut, detfUser, deadline)` | `paid.length == n`; `paid[detfIndex] == 0`; some non-DETF `paid[i] > 0`; user received that basket token; position `originalSharesOf(tokenId) == 0`; R19; hook pair balances `<= 10` wei |

`deadline` = `block.timestamp + 1 hours`.

Close uses **Default** basket (no leftover swaps). Do not set Custom close on these fixtures.

If firstBond needs per-leg arrays (orbital/quad), pass `100 ether` in `tokens()` order for every non-DETF pair; DETF self-leg amount is whatever the existing `_firstBond` helper already does on that hook TestBase. Do not change first-bond product law.

### 7.1 R19 numeric bound

After each path:

```text
IERC20(hook).balanceOf(detf) == 0
for t in hook.tokens(): IERC20(t).balanceOf(detf) == 0   // or <= 10 wei if a documented host min leftover; then public sweepDust() and re-assert 0 or host-min
for se in bound SEs: IERC20(se).balanceOf(detf) == 0
```

If a leftover cannot join (below host min), call `sweepDust()` then re-assert. Do not leave `>> 10` wei of pair on the DETF (live parking class). Cap: `pair.balanceOf(detf) < 0.01 ether` is **not** enough for this PRD. Target 0 or `<= 10` wei after sweep.

### 7.2 Existing Stage 07/08/10 tests

Keep T7.* / T8.* / T10.8–T10.10 on ERC-4626 (and current pons v2 mint). Do not delete them. They are **not** acceptance for §6.

---

## 8. Pons fixture law (LOCKED)

### 8.1 pons v1 (P1-V3)

| Item | Value |
|------|--------|
| Crane TestBase | `lib/crane/contracts/protocols/launchpads/ponsFamily/v1/test/bases/TestBase_PonsFamily.sol` |
| Factory / locker | Real `PonsLaunchFactory` + `PonsLaunchLocker` (hermetic, not 4663 addresses) |
| Quote | **WETH** only |
| Pool fee | `10000` (1%) |
| Tick spacing | `200` |
| Supply | `1_000_000_000 ether` (TestBase constant) unless a single test cannot fund it; if scaled, document the exact `PONS_SUPPLY` override in the TestBase NatSpec and keep real `launchToken` |
| Graduation | Not required for v1. The Uni V3 pool exists from create. SE wraps **that** pool |
| Hook pair | Launch token, **not** WETH |
| SE other token | WETH |
| SE package | `UniswapV3StandardExchangeDFPkg.deployVault(IUniswapV3Pool)` |
| Locker LP | Do not steal. SE opens **its own** V3 positions |

Same `uniswapV3Factory` as the Uni V3 SE DFPkg `PkgInit`.

### 8.2 pons v2 (P2-V4)

Stage 10 / R20 / §16.11. Do not re-litigate.

| Item | Value |
|------|--------|
| Crane TestBase | `TestBase_PonsFamilyV2` |
| Quote | WETH ERC-20. **Not** native ETH |
| Graduated `PoolKey` | launch token + WETH, `fee == 0`, `hooks == PonsV2MemeHook` |
| Phase | `PoolCreated` |
| SE | `UniswapV4StandardExchangeDFPkg.deployVault(poolKey)` |
| PoolManager | **Same** as IndexedEx hook + Uni V4 SE `PkgInit` |
| DETF reserve hook | IndexedEx SE buffer hook. **Never** `PonsV2MemeHook` |
| Hook pair | Launch token, **not** WETH |

Hermetic-sized launch config is allowed (smaller supply / threshold than live 1e9) so `readyToGraduate` is reachable. Still real `launchToken` + curve buys + graduate.

### 8.3 Morpho Blue SE (MB-BLUE)

Package law: [`MorphoBlueStandardExchange_PRD.md`](../standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchange_PRD.md). Do not reopen D1–D37 here. This matrix is the later Uni V4 hook consumer (Morpho D35).

| Item | Value |
|------|--------|
| Package | `contracts/vaults/standard/exchange/protocols/morpho/blue/` |
| Type name | `MorphoBlueStandardExchange` (no `MBSE` / `MorphoSE` types) |
| TestBase to copy | `…/morpho/blue/test/bases/TestBase_MorphoBlueStandardExchange.sol` + Crane `TestBase_MorphoBlue` |
| Protocol | Morpho Blue v1.0.0 isolated market. **Not** Vault V2 / MetaMorpho |
| Mode | Supply / lend only. No borrow, no `supplyCollateral`, no loop |
| `IERC4626.asset()` / hook pair | Market **`loanToken`**. Must ∈ `vaultTokens()` (`[loanToken]` only) |
| `collateralToken` | Market identity. Not held. Not a hook `tokens()` member |
| Market existence | `createMarket` in the **test** before `deployVault`. Vault `initAccount` reverts if `morpho.market(id).lastUpdate == 0` |
| Sleeve | **None.** Full inbound supply to Morpho after mint (D26) |
| Liquidity | Withdraw reverts when Blue cash is short (D23/D24). These rows keep utilization 0 (no borrower) |
| Opacity | DETF/hook production sources must not import Morpho types (D36). Tests may |
| `PkgArgs` | `{morpho: IMorpho, marketParams: MarketParams}` on `IMorphoBlueStandardExchangeDFPkg` |
| Deploy | CREATE3 facets + `indexedexManager.deployMorphoBlueStandardExchangeDFPkg` then `pkg.deployVault`. Never `new` the DFPkg |

Per Morpho-bound pair:

1. Pair ERC-20 already exists (DETF TestBase mintable). On Morpho mixed rows, pair [0] is that mintable, not a pons launch token.
2. `MarketParams({loanToken: pair, collateralToken: dummyCollateral, oracle: oracleMock, irm: adaptiveCurveIrm, lltv: 0.8e18})`.
3. `morpho.createMarket(params)` (test, as Morpho owner).
4. `morphoBlueStandardExchangeDFPkg.deployVault({morpho, marketParams: params})`.
5. `hook.standardExchangeOf(pair) =` that vault.

On mixed Morpho rows, pair [0] is the DETF TestBase first pair (same `mintToken` as §5.1 after `hook.tokens()`). It is **not** WETH and **not** a pons launch token.

Do not wrap WETH as the Morpho `loanToken` on these fixtures. The hook pair is the loan token; WETH is only the pons quote / Uni V4 SE other token on non-Morpho legs.

---

## 9. Files to create (LOCKED)

Do not put TestBases under `test/` if the gold unified DETF TestBase lives under `contracts/…/detf/`. Follow that.

### 9.1 TestBases

| Path | Rows |
|------|------|
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Cp_Univ3Se.sol` | H-CP-GV3 |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Cp_Univ4Se.sol` | H-CP-GV4 |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Cp_PonsV1Se.sol` | H-CP-P1 |
| extend `contracts/test/bases/TestBase_UniswapV4Detf_PonsV2Se.sol` | H-CP-P2 (already exists) |
| `…/detf/TestBase_UniswapV4Detf_Cp_MorphoBlueSe.sol` | H-CP-MB |
| `…/detf/TestBase_UniswapV4Detf_Orbital_Univ3Se.sol` | H-OR-GV3 |
| `…/detf/TestBase_UniswapV4Detf_Orbital_Univ4Se.sol` | H-OR-GV4 |
| `…/detf/TestBase_UniswapV4Detf_Orbital_PonsV1Se.sol` | H-OR-P1 |
| `…/detf/TestBase_UniswapV4Detf_Orbital_PonsV2Se.sol` | H-OR-P2 |
| `…/detf/TestBase_UniswapV4Detf_Orbital_PonsMix.sol` | M-OR-P1P2 |
| `…/detf/TestBase_UniswapV4Detf_Orbital_MorphoBlueSe.sol` | H-OR-MB |
| `…/detf/TestBase_UniswapV4Detf_Orbital_MorphoMix.sol` | M-OR-MBGV4 |
| `…/detf/TestBase_UniswapV4Detf_Weighted_Univ3Se.sol` | H-WE-GV3 |
| `…/detf/TestBase_UniswapV4Detf_Weighted_Univ4Se.sol` | H-WE-GV4 |
| `…/detf/TestBase_UniswapV4Detf_Weighted_PonsV1Se.sol` | H-WE-P1 |
| `…/detf/TestBase_UniswapV4Detf_Weighted_PonsV2Se.sol` | H-WE-P2 |
| `…/detf/TestBase_UniswapV4Detf_Weighted_PonsMix.sol` | M-WE-P1P2 |
| `…/detf/TestBase_UniswapV4Detf_Weighted_MorphoBlueSe.sol` | H-WE-MB |
| `…/detf/TestBase_UniswapV4Detf_Weighted_MorphoMix.sol` | M-WE-MBGV4 |
| `…/detf/TestBase_UniswapV4Detf_Quad_Univ3Se.sol` | H-QD-GV3 |
| `…/detf/TestBase_UniswapV4Detf_Quad_Univ4Se.sol` | H-QD-GV4 |
| `…/detf/TestBase_UniswapV4Detf_Quad_PonsV1Se.sol` | H-QD-P1 |
| `…/detf/TestBase_UniswapV4Detf_Quad_PonsV2Se.sol` | H-QD-P2 |
| `…/detf/TestBase_UniswapV4Detf_Quad_PonsMix.sol` | M-QD-P1P2G4 |
| `…/detf/TestBase_UniswapV4Detf_Quad_MorphoBlueSe.sol` | H-QD-MB |
| `…/detf/TestBase_UniswapV4Detf_Quad_MorphoMix.sol` | M-QD-MBGV4P1 |

Shared SE deploy helpers (optional library, not a second SUT):

`contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol`

If created, it only: Uni V3 pkg+pool+vault, Uni V4 pkg+TWAP+pool+vault, pons v1 launch+V3 SE, pons v2 graduate+V4 SE, Morpho singleton+`createMarket`+Morpho Blue SE vault. No DETF logic.

### 9.2 Specs

| Path | Rows |
|------|------|
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Cp_Univ3Se.t.sol` | H-CP-GV3 |
| `…/prod-se/UniswapV4Detf_Cp_Univ4Se.t.sol` | H-CP-GV4 |
| `…/prod-se/UniswapV4Detf_Cp_PonsV1Se.t.sol` | H-CP-P1 |
| `…/detf/pons/UniswapV4Detf_PonsV2Se.t.sol` | add burn+close to existing file for H-CP-P2 |
| `…/prod-se/UniswapV4Detf_Cp_MorphoBlueSe.t.sol` | H-CP-MB |
| `…/prod-se/UniswapV4Detf_Orbital_Univ3Se.t.sol` | H-OR-GV3 |
| `…/prod-se/UniswapV4Detf_Orbital_Univ4Se.t.sol` | H-OR-GV4 |
| `…/prod-se/UniswapV4Detf_Orbital_PonsV1Se.t.sol` | H-OR-P1 |
| `…/prod-se/UniswapV4Detf_Orbital_PonsV2Se.t.sol` | H-OR-P2 |
| `…/prod-se/UniswapV4Detf_Orbital_PonsMix.t.sol` | M-OR-P1P2 |
| `…/prod-se/UniswapV4Detf_Orbital_MorphoBlueSe.t.sol` | H-OR-MB |
| `…/prod-se/UniswapV4Detf_Orbital_MorphoMix.t.sol` | M-OR-MBGV4 |
| `…/prod-se/UniswapV4Detf_Weighted_Univ3Se.t.sol` | H-WE-GV3 |
| `…/prod-se/UniswapV4Detf_Weighted_Univ4Se.t.sol` | H-WE-GV4 |
| `…/prod-se/UniswapV4Detf_Weighted_PonsV1Se.t.sol` | H-WE-P1 |
| `…/prod-se/UniswapV4Detf_Weighted_PonsV2Se.t.sol` | H-WE-P2 |
| `…/prod-se/UniswapV4Detf_Weighted_PonsMix.t.sol` | M-WE-P1P2 |
| `…/prod-se/UniswapV4Detf_Weighted_MorphoBlueSe.t.sol` | H-WE-MB |
| `…/prod-se/UniswapV4Detf_Weighted_MorphoMix.t.sol` | M-WE-MBGV4 |
| `…/prod-se/UniswapV4Detf_Quad_Univ3Se.t.sol` | H-QD-GV3 |
| `…/prod-se/UniswapV4Detf_Quad_Univ4Se.t.sol` | H-QD-GV4 |
| `…/prod-se/UniswapV4Detf_Quad_PonsV1Se.t.sol` | H-QD-P1 |
| `…/prod-se/UniswapV4Detf_Quad_PonsV2Se.t.sol` | H-QD-P2 |
| `…/prod-se/UniswapV4Detf_Quad_PonsMix.t.sol` | M-QD-P1P2G4 |
| `…/prod-se/UniswapV4Detf_Quad_MorphoBlueSe.t.sol` | H-QD-MB |
| `…/prod-se/UniswapV4Detf_Quad_MorphoMix.t.sol` | M-QD-MBGV4P1 |

One spec file per fixture. Four tests per file (§7). Do not merge hooks in one contract.

---

## 10. Work packages (LOCKED packing)

Max **3** concurrent implementers. Do not split a hook family across two agents.

| WP | Worktree | Fixtures | Depends on |
|----|----------|----------|------------|
| **WP-UDSM-CP** | `unified_detf_se_cp` | H-CP-GV3, H-CP-GV4, H-CP-P1, H-CP-P2, H-CP-MB | none (pathfinder) |
| **WP-UDSM-OR** | `unified_detf_se_orbital` | H-OR-* + M-OR-P1P2 + M-OR-MBGV4 | WP-UDSM-CP green (copy SE deploy helpers) |
| **WP-UDSM-WE** | `unified_detf_se_weighted` | H-WE-* + M-WE-P1P2 + M-WE-MBGV4 | WP-UDSM-CP green |
| **WP-UDSM-QD** | `unified_detf_se_quad` | H-QD-* + M-QD-P1P2G4 + M-QD-MBGV4P1 | WP-UDSM-CP green |

First wave: CP only, or CP + Orbital + Weighted if three agents. Quad after CP helpers exist.

Do not edit Dual Common, family DETF packages, or frontend in these worktrees.

If production CODE must change (missing `forceApprove` on a hook copy, Uni V3 SE cannot wrap a pons v1 pool, Uni V4 SE cannot wrap meme-hook `fee==0`):

1. Stop the test-only claim.
2. Minimal CODE on that package.
3. Add a fixture that **fails on pre-fix** and passes after.
4. Do not convert leftover-pretransfer spend (L-GAPS-11).

---

## 11. Acceptance matchers

```bash
# Pathfinder
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Cp_*'
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/UniswapV4Detf_PonsV2Se.t.sol'

# After all WPs
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/**'
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/**'

# Regression (must stay green)
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_*.t.sol'
```

A row is **DONE** only when its four tests pass **and** ERC-4626 T7/T8 files above still pass.

This PRD is **closed** when all 26 fixtures × 4 paths are green (104 tests), plus H-CP-P2 burn/close added to the existing pons file.

---

## 12. Constraints (copy onto every implementer prompt)

1. Production-first. No `MockStandardExchange`. No `new` facets/DFPkgs. No `vm.mockCall` of SUT.
2. `via_ir` forbidden.
3. DETF role names only (`rateAsset` not used as a product API here; pairs are `hook.tokens()` minus DETF).
4. TWAP required on every Uni V4 SE. Same `pm` as the buffer hook.
5. pons v2 and Uni V4 SE and buffer hook share one `PoolManager`.
6. pons v1 and Uni V3 SE share one `UniswapV3Factory`.
7. Do not diamond-inherit both Univ4Se hook TestBase and unified DETF TestBase.
8. Seed `cache_forge/` + `out/` in a new worktree. Do not kill `forge`/`solc`. Timeout hours.
9. Anti-theater: `allowance(hook, se)==0` before burn and close. ERC-4626 green is not acceptance.
10. Dual is not a DETF hook.
11. Do not set `PonsV2MemeHook` as the DETF reserve hook.
12. Live 4663 instance is unpatchable.
13. Morpho SE `loanToken` = hook pair. `createMarket` in the test before `deployVault`. Do not borrow. Do not wrap Vault V2. Do not import Morpho types into DETF/hook **production** sources.
14. Do not skip Morpho rows because unwrap burns `msg.sender`. They are production Morpho Blue supply, not ERC-4626 theater.

---

## 13. Ready-to-paste implementer prompt

```text
Implement contracts/vaults/detf/UNIFIED_DETF_PRODUCTION_SE_HOOK_MATRIX_TEST_PRD.md
for worktree assignment: <WP-UDSM-CP | WP-UDSM-OR | WP-UDSM-WE | WP-UDSM-QD>.

Do not invent extra hooks, SE types, mixed maps, Policy mode, or Custom routes.
Do not treat ERC-4626 T7/T8 as production SE proof.
Do not bind Dual as PkgArgs.hook.
Copy Uni V4 SE deploy from TestBase_UniswapV4CpBufferUniv4Se.
Copy Uni V3 SE deploy from TestBase_UniswapV3StandardExchange.
Copy pons v2 from TestBase_UniswapV4Detf_PonsV2Se / Stage 10.
Copy pons v1 from Crane TestBase_PonsFamily.
Copy Morpho Blue SE from TestBase_MorphoBlueStandardExchange.
Hermetic Morpho: Crane TestBase_MorphoBlue singleton + createMarket before deployVault.
loanToken = hook pair. Dummy collateral not in hook.tokens(). Do not borrow.
Do not diamond-inherit TestBase_MorphoBlue with the DETF TestBase.

Each assigned fixture: firstBond, mint, burn, close as §7.
allowance(hook, se)==0 before burn and close.
R19 after each path.

When done: paste forge match-path results; keep UniswapV4Detf_Mint/Burn/Close/Orbital/Weighted/Quad green.
```

---

## 14. Status table (update when a WP lands)

| WP | Status |
|----|--------|
| WP-UDSM-CP | done |
| WP-UDSM-OR | done |
| WP-UDSM-WE | done |
| WP-UDSM-QD | done |

Parent merge 2026-08-27 (`forge test --offline -vv`):

| Matcher | Result |
|---------|--------|
| `prod-se/**` | 100 passed, 0 failed (25 files × 4 paths) |
| `pons/**` | 7 passed, 0 failed (H-CP-P2 firstBond/mint/burn/close + T10_8/9/10) |
| `UniswapV4Detf_*.t.sol` | 24 passed, 0 failed (Mint/Burn/Close/Orbital/Weighted/Quad plus Bond/Deploy/Donate/Dust) |

26 fixtures × 4 = 104 money paths green. Dual not bound. ERC-4626 T7/T8 not used as production SE proof. `foundry.toml` `via_ir = false`.

Close/mint rejoin into a keep-10 remainder pool: CP hook zap never sells 100% of `tokenIn` (`saleAmt >= amountIn` → `amountIn / 2`); owner-only clamp uses 1 wei instead of `ZeroAmount` when a leg would floor to 0.
