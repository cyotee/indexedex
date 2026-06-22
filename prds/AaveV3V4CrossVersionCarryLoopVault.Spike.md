# Spike: Aave V3.6 / V4 Cross-Version Carry Loop Vault

Pre-implementation research spike (PRD decision 5). This is the **first deliverable**; no
contract implementation begins until the BLOCKER workstreams (WS0–WS3) are answered and the
math workstreams (WS4–WS6) have a concrete proposal.

Each workstream lists: **Questions** (what we must answer), **Where to look** (contracts /
functions / skills / repo paths), and **Artifact** (the concrete output the spike must produce).

> Grounding note: the V3/V4 surfaces below were taken from the in-repo Aave skills
> (`aave-v3-configuration`, `aave-v3-emodes`, `aave-v4-architecture`, `aave-v4-spoke`).
> Confirm every function signature against the actual deployed/harness source before relying on it.

---

## Findings that may revise PRD decisions (resolve these explicitly)

- **F1 — V4 has no eMode (revises decision 24).** V4's correlation/efficiency analog is
  `DynamicReserveConfig.collateralFactor` (per `dynamicConfigKey`) + `collateralRisk`/risk-premium,
  not eMode. Decision 24 should become: *V3 = eMode when pair qualifies; V4 = dynamic-config
  collateral factor (no eMode).*
- **F2 — "LTV" is version-asymmetric (refines decisions 1, 24).** V3 has `ltv` + separate
  `liquidationThreshold`; V4 has only `collateralFactor` (used directly in HF). The
  `min(our cap, Aave native)` check must compare against the correct native param per version.
- **F3 — net carry is asymmetric (refines decision-level "net carry" definition).** V4 borrow cost
  = base `drawnRate` × (1 + user risk premium); V4 supply APY derives from utilization + liquidity
  fee + premium accrual. V3 is a single `currentVariableBorrowRate` / `currentLiquidityRate`. The
  unified formula (WS4) must reconcile these.
- **F4 — deployment reality unknown (gates everything).** Need to confirm what "Aave V3.6" is and
  whether **V4 is live on Base** or only available via Crane harness/local deploy (WS0).

---

## Verified against Crane source (2026-06-22)

Source roots (both versions vendored in Crane):
- V3.6: `lib/daosys/lib/crane/contracts/protocols/lending/aave/v3.6`
- V4:   `lib/daosys/lib/crane/contracts/protocols/lending/aave/v4`

**WS0 — resolved.** "Aave V3.6" = the current Ethereum/Base V3.x production deployment; expected to
match the Crane `v3.6` tree. Both V3.6 and V4 are present in Crane, so V4 fork tests can deploy via
the Crane V4 sources/harness if no live Base deployment exists (still confirm live addresses in WS0 follow-up).

**WS1 — V3.6 IPool confirmed** (`v3.6/interfaces/IPool.sol`, `DataTypes.ReserveDataLegacy`):
- `getUserAccountData(user)` → `(totalCollateralBase, totalDebtBase, availableBorrowsBase, currentLiquidationThreshold, ltv, healthFactor)`.
- `getReserveData(asset)` → `ReserveDataLegacy { configuration, liquidityIndex, currentLiquidityRate (ray, supply APR), variableBorrowIndex, currentVariableBorrowRate (ray), …, aTokenAddress, variableDebtTokenAddress }`.
- `getConfiguration(asset)` → `ReserveConfigurationMap` (bitmap → ltv/LT/flags/caps via `ReserveConfiguration`).
- `getReserveNormalizedIncome(asset)` / `getReserveNormalizedVariableDebt(asset)` → live index for aToken/debt-equiv balances (supports decision-2 live reconciliation).
- `getVirtualUnderlyingBalance(asset)` → for IR-strategy utilization in WS6 projection.
- `getReserveAToken(asset)` / `getReserveVariableDebtToken(asset)`; `setUserEMode` / `getUserEMode`.
- ⚠️ `interestRateStrategyAddress` in `ReserveDataLegacy` is **DEPRECATED (v3.4)**; use the Pool-level
  `RESERVE_INTEREST_RATE_STRATEGY` for WS6 rate projection.

**WS2 — V4 Spoke/Hub confirmed** (`v4/spoke/interfaces/ISpoke.sol`, `v4/hub/interfaces/IHubBase.sol`):
- `Spoke.getUserAccountData(user)` → `UserAccountData { riskPremium, avgCollateralFactor, healthFactor, totalCollateralValue, totalDebtValueRay, activeCollateralCount, borrowCount }` — the V4 analog of V3's `getUserAccountData` (HF + value totals in one call).
- `Spoke.getUserSuppliedAssets / getUserSuppliedShares / getUserDebt(→drawn,premium) / getUserTotalDebt / getUserPremiumDebtRay / getUserLastRiskPremium / getUserReserveStatus`.
- `Spoke.getReserve / getReserveConfig` (flags), `getReserveSuppliedAssets / getReserveDebt / getReserveTotalDebt`.
- `Hub` (IHubBase) preview surface: `previewAddByAssets/Shares`, `previewRemoveByAssets/Shares`, `previewDrawByAssets/Shares`, `previewRestoreByAssets/Shares` — strong support for preview==execution (WS6).
- `Hub.getAssetDrawnRate / getAssetDrawnIndex / getAssetLiquidity / getAssetOwed / getAssetTotalOwed / getAssetPremiumRay / getAssetPremiumData`; IR strategy `getInterestRateData / getOptimalUsageRatio / getBaseDrawnRate / getRateGrowthBeforeOptimal / getRateGrowthAfterOptimal / getMaxDrawnRate`.
- ⚠️ **No V4 supply-rate getter exists** — supply APY must be **derived** from `drawnRate` × utilization × (1 − `liquidityFee`) adjusted for premium accrual (feeds WS4).
- Position-manager: vault as its own `onBehalfOf` (the `user == manager` shortcut) — confirm no explicit `setUserPositionManager` needed when caller == user.

**WS3 — V4 source lookup confirmed tractable on-chain:**
`Hub.getAssetId(underlying)` → `assetId`; `Spoke.getReserveId(hub, assetId)` → `reserveId`;
`Hub.getAssetUnderlyingAndDecimals(assetId)`. The Package still must be **given which Hub + Spoke**
(no global registry found yet — confirm). V3 side: token → Pool via `PoolAddressesProvider`, flags via config bitmap.

**Updated finding status:**
- F1 (V4 has no eMode) — **still stands**; V4 efficiency is `DynamicReserveConfig.collateralFactor` + risk premium. Decision 24 rewrite still required.
- F2 — refined: both versions expose a `getUserAccountData` with HF, but the underlying params differ (V3 `ltv`/`LT`; V4 `avgCollateralFactor`). Service libs abstract this.
- F3 (asymmetric net carry) — **confirmed**: V4 has no supply-rate getter and a base-rate × risk-premium model; WS4 derivation is mandatory.

**Remaining gaps after this pass:** WS0 live-address confirmation; WS4 (derive V4 supply APY + unified carry); WS5 (oracle base-unit/decimals for both); WS6 (prove in-tx rate/HF projection is view-only for both); WS7/WS8/WS9 detail. Next concrete step: read the IR-strategy math + V4 oracle interface to draft WS4/WS5.

---

## Spike resolutions — second pass (2026-06-22): WS4–WS9

### WS6 — preview == execution is achievable view-only *(resolved)*
Both IR strategies are **pure views of (liquidity, debt)**, so a projected leg's rate can be
computed in-tx without state writes:
- **V3:** `IDefaultInterestRateStrategyV2.calculateInterestRates(CalculateInterestRatesParams{ liquidityAdded, liquidityTaken, totalDebt, reserveFactor, reserve, virtualUnderlyingBalance, … })` → `(liquidityRate, variableBorrowRate)`. Strategy address is the **Pool-level** `RESERVE_INTEREST_RATE_STRATEGY` (v3.4+), not per-reserve.
- **V4:** `IBasicInterestRateStrategy.calculateInterestRate(assetId, liquidity, drawn, deficit, swept)` → drawn rate (RAY). Project by passing post-leg `liquidity`/`drawn`.
- **HF projection:** `getUserAccountData` reflects *current* state, so the preview must **recompute HF itself** from projected balances × oracle prices × (V3 `liquidationThreshold` / V4 `collateralFactor`), mirroring Aave's account-data math (watch rounding). This shared "projection routine" is used by both `preview*` and execution.

### WS5 — oracles differ structurally; normalize to a common unit *(resolved)*
- **V3:** `IPriceOracleGetter` — `getAssetPrice(asset)`, `BASE_CURRENCY()` (address; `address(0)`/USD), `BASE_CURRENCY_UNIT()` (e.g. `1e8`). **Keyed by asset address.**
- **V4:** `Spoke.ORACLE()` → `IAaveOracle` — `getReserveSource(reserveId)`, `getReservesPrices(...)`; price feed exposes `IPriceOracle.getReservePrice(reserveId)` and **`decimals()`** for its own output scale. **Keyed by reserveId, not asset.**
- ⚠️ **Two different oracles, different keys and decimals.** Common-unit spec: read V3 `getAssetPrice(token)/BASE_CURRENCY_UNIT` and V4 `getReservePrice(reserveId)` scaled by its `decimals()`, normalize both (plus token decimals) to one common unit (USD recommended, since both are USD-denominated price feeds). Confirm both are USD-quoted on Base before relying on direct comparability.

### WS4 — unified net-carry formula *(resolved, one residual)*
Rate sources:
- **V3 supply APR** = `ReserveDataLegacy.currentLiquidityRate` (RAY); **V3 borrow APR** = `currentVariableBorrowRate` (RAY). Projected via the strategy view above.
- **V4 borrow APR (base)** = `Hub.getAssetDrawnRate(assetId)` or the strategy view (RAY). **User effective borrow rate** = base × (1 + `riskPremium`), `riskPremium` from `Spoke.getUserAccountData(user).riskPremium`.
- **V4 supply APR (DERIVED — no getter):** suppliers earn the growth of **total owed (drawn + premium)** net of `liquidityFee`. Per `AssetLogic.getUnrealizedFees`, fees = `(Δ aggregatedOwed) × liquidityFee`, where `aggregatedOwed = drawnShares·drawnIndex + premiumRay + deficitRay`; the remainder grows `totalAddedAssets` (supplier value). So:
  ```
  supplyAPY_v4 ≈ ( drawnInterest + premiumInterest ) × (1 − liquidityFee) / totalAddedAssets
  ```
  where `drawnInterest` from `drawnRate × drawn` and `premiumInterest` from `premiumShares·drawnIndex` growth. The earlier `drawnRate × utilization × (1−liquidityFee)` form **understates** it by omitting premium.
  - ✅ **Residual resolved:** risk-**premium** interest accrues to **suppliers** (net of `liquidityFee`); only `liquidityFee%` of total owed growth goes to the protocol fee receiver (`realizedFees`). Source: `v4/hub/libraries/AssetLogic.sol` (`getUnrealizedFees`, `_calculateAggregatedOwedRay`) + `Premium.calculatePremiumRay`.

Per-orientation net carry (orientation = supply X on version A, borrow Y on A, supply Y on B, borrow X on B):
```
netCarry = [ supplyAPY_A(X) − borrowAPY_B(X) ]      // X round-trip
         + [ supplyAPY_B(Y) − borrowAPY_A(Y) ]      // Y round-trip
```
weighted by each leg's notional in the common unit (WS5). Evaluate both orientations; pick the
higher `netCarry` that clears `minSpread + hysteresis` (decisions 7, 25). All getters are RAY/BPS;
the Service libs normalize to one fixed-point convention.

### WS7 — correlated efficiency reads *(resolved; matches decision-24 rewrite)*
- **V3:** `setUserEMode` / `getUserEMode`; eMode LTV/LT via the eMode category getters; pair membership via collateral/borrowable bitmaps.
- **V4:** `Spoke.getReserveConfig(reserveId)` → `ReserveConfig{ collateralRisk, paused, frozen, borrowable, receiveSharesEnabled }`; `DynamicReserveConfig{ collateralFactor (BPS), maxLiquidationBonus, liquidationFee }`; `getUserAccountData(user).avgCollateralFactor`. **No eMode** — borrow power is `collateralFactor`.

### WS8 — freeze/pause reads *(resolved)*
- **V3:** reserve config bitmap → `getActive` / `getFrozen` / `getPaused` / `getBorrowingEnabled`.
- **V4:** `Spoke.getReserveConfig(reserveId)` → `paused` / `frozen` / `borrowable` flags.
- Graceful-degradation branch (decision 23): on frozen/paused → allow unwind/withdraw, block new leverage, rebalance de-risks.

### WS9 — V4 premium refresh in rebalance *(resolved)*
- `Spoke.updateUserRiskPremium(onBehalfOf)` refreshes the position's risk premium (call before accurate HF/debt reads in rebalance).
- `Hub.refreshPremium(assetId, premiumDelta)`, `getAssetPremiumRay/getAssetPremiumData/getSpokePremiumRay`; `IHubBase.PremiumDelta` struct.
- Premium debt is the `premium` component of `Spoke.getUserDebt(reserveId, user)` and `getUserPremiumDebtRay` — it is **extra debt the never-borrow unwind (decision 14) must repay**, so unwind math must include premium debt, not just drawn debt.

### WS3 — source lookup *(resolved on-chain, one config input)*
V4: `Hub.getAssetId(token)` → `assetId`; `Spoke.getReserveId(hub, assetId)` → `reserveId`. The Package
must be **given the Hub + Spoke addresses** (no global registry found); everything else is derivable.
V3: token → Pool via `PoolAddressesProvider`; flags via config bitmap.

### WS0 follow-up — deployment matrix *(resolved 2026-06-22 via aave-address-book)*
Confirmed from `bgd-labs/aave-address-book` (`src/`) and aave.com/docs/resources/addresses:
- **Aave V4 — Ethereum mainnet ONLY** (`AaveV4Ethereum.sol`; Hubs Core/Plus/Prime + many Spokes). No `AaveV4Base.sol`.
- **Base — Aave V3 only** (`AaveV3Base.sol`; plus BaseSepolia variants). No V4.
- Therefore **both versions are live together only on Ethereum.**

**Consequence (scope) — CONFIRMED:** the cross-version carry premise requires live V3 **and** V4,
which today exists only on **Ethereum**. The initial vault is **retargeted to Ethereum mainnet**
(PRD decision 34); fork tests fork **Ethereum** with real V3 + real V4 (no harness needed). Pull
concrete addresses from `AaveV3Ethereum.sol` / `AaveV4Ethereum.sol` in `bgd-labs/aave-address-book`.

### Net status
All math/interface workstreams (WS1–WS9) are **resolved** against the Crane source. WS4 residual
(premium accrues to suppliers) is now **resolved**. One external confirmation remains, not blocking
architecture: live V4 Base deployment existence (WS0 follow-up) — plan is fork-real-V3 +
Crane-harness-V4 until confirmed. Results have been folded back into the PRD.

---

## WS0 — Deployment reality & versioning  *(BLOCKER — do first)*

**Questions**
- What exactly is "Aave V3.6"? Is that a real release tag, or does the user mean the current
  V3.x on Base (V3.1/3.2/3.3/3.4 liquid-eMode line)? Which `Pool` interface version applies?
- Is **Aave V4 deployed on Base** (mainnet/testnet) with real liquidity, or only available via the
  Crane harness / local deployment? (Hub + Spoke addresses, or harness deploy scripts.)
- For fork testing (PRD §7): do we fork real Base deployments for both versions, or fork V3 real +
  deploy V4 via Crane harness? Confirm which Spoke(s) and Hub our pair would use.

**Where to look**
- Crane lib tree: `lib/daosys/lib/crane/...` for Aave V3 origin + any V4 harness/Spokes.
- Repo search for existing Aave V3/V4 addresses, fork block pins, and harness deploy scripts
  (`test/foundry/fork/`, deploy scripts, `foundry.toml` rpc/fork config).
- Aave governance/docs for the actual current Base version and any V4 testnet.

**Artifact**
- A short "deployment matrix": version → network → addresses (or harness deploy path) → fork block.
- Decision: real-fork vs harness-deploy per version, written back into PRD §7.

---

## WS1 — Aave V3 read & write surface

**Questions**
- Rate getters: confirm `Pool.getReserveData(asset)` fields — `currentLiquidityRate` (supply APR,
  ray), `currentVariableBorrowRate` (ray), `liquidityIndex`, `variableBorrowIndex`,
  `aTokenAddress`, `variableDebtTokenAddress`, `interestRateStrategyAddress`.
- Account/HF: `Pool.getUserAccountData(user)` → `totalCollateralBase`, `totalDebtBase`,
  `availableBorrowsBase`, `currentLiquidationThreshold`, `ltv`, `healthFactor`.
- Config: `Pool.getConfiguration(asset)` bitmap → `getLtv`, `getLiquidationThreshold`,
  `getActive/Frozen/Paused`, `getBorrowingEnabled`, `getBorrowCap`, `getSupplyCap`,
  `getReserveFactor` (via `ReserveConfiguration`).
- Prices: `AaveOracle.getAssetPrice(asset)` — base currency + decimals (USD 8dp?). Where is the
  oracle resolved from (`PoolAddressesProvider.getPriceOracle()`)?
- Write surface used by the loop: `supply / borrow / repay / withdraw`, `setUserEMode`.

**Where to look**
- `aave-v3-pool`, `aave-v3-configuration`, `aave-v3-tokens` skills; Crane aave-v3-origin sources.

**Artifact**
- A V3 Service-lib call map: every read/write the loop/preview needs, with exact signatures,
  return units (ray/wad/bps/base-ccy), and index-vs-rate semantics.

---

## WS2 — Aave V4 read & write surface (Hub + Spoke)

**Questions**
- Supplied/debt reads: `Spoke.getUserSuppliedAssets(reserveId, user)`,
  `Spoke.getUserDebt(reserveId, user)` → `(drawn, premium)`, `Spoke.getUserTotalDebt(...)`,
  `Spoke.getUserHealthFactor(user)`. Confirm these are the canonical view getters.
- Share↔asset conversions: `Hub.previewAddByAssets`, `Hub.previewRemoveByShares`,
  `Hub.previewRestoreByShares` (and any `previewRemoveByAssets`) — for preview==execution.
- Rates: `Asset.drawnRate` (borrow), `irStrategy`, `liquidityFee`, utilization from
  `Asset.liquidity / drawnShares / drawnIndex`. How is **supply APY** computed for LPs?
- Risk premium: how to read a user's current risk premium and `collateralRisk`; how
  `premiumShares`/`premiumOffsetRay` affect debt and rate (`aave-v4-risk-premium`).
- Dynamic config: `Spoke._dynamicConfig[reserveId][configKey]` → `collateralFactor`,
  `maxLiquidationBonus`, `liquidationFee`; how `dynamicConfigKey` snapshots bind to a position and
  when they refresh on borrow/withdraw (`aave-v4-dynamic-config`).
- Flags: `Reserve.flags` → paused / frozen / borrowable / liquidatable reads.
- Write surface as `onBehalfOf` = vault: `supply/withdraw/borrow/repay`; auto-collateral on first
  supply; whether the vault must call `setUserPositionManager` (we are our own manager → likely
  `user == manager` shortcut, confirm).

**Where to look**
- `aave-v4-hub`, `aave-v4-spoke`, `aave-v4-risk-premium`, `aave-v4-dynamic-config`,
  `aave-v4-liquidation`, `aave-v4-position-manager` skills; `src/hub/`, `src/spoke/` in the V4 source.

**Artifact**
- A V4 Service-lib call map mirroring WS1, plus an explicit note on the **risk-premium and
  dynamic-config refresh calls** the rebalance must make (resolves PRD §9 "V4 premium refresh").

---

## WS3 — Source lookup for `deployVault` validation (decisions 24, deployment validation)

**Questions**
- V3: token → `Pool` (from `PoolAddressesProvider`), and read collateral/borrowable/active flags;
  resolve eMode category membership for the pair (`getEModeCategoryCollateralBitmap` /
  `BorrowableBitmap`, `reserve.id`).
- V4: token → which **Spoke + Hub + reserveId + assetId**? Is there a registry/lookup, or must the
  Package be given the Spoke/reserveId at deploy? (`Hub.getAssetUnderlyingAndDecimals`, Spoke
  reserve enumeration.)
- Validation rule: both tokens must be collateral-usable + borrowable + active on **both** versions
  (PRD). Confirm the exact flags per version and the revert conditions.

**Where to look**
- V3 `PoolAddressesProvider`, `PoolDataProvider`; V4 Hub/Spoke reserve registry + harness wiring.

**Artifact**
- A concrete `deployVault` validation algorithm per version (immutable values the Package stores +
  what it must be passed vs what it can look up). Resolves PRD §9 source-lookup `[SPIKE]`.

---

## WS4 — Unified net-carry formula (decisions 7, 8, 25; finding F3)

**Questions**
- Define `supplyAPY(version, asset)` and `borrowCost(version, asset, user)` for each version in a
  common rate convention (handle V4 base × (1 + risk premium) and premium accrual).
- Define `netCarry(direction)` = supply yield on the supplied legs − borrow cost on the borrowed
  legs, across both versions, for a given loop orientation.
- Define the `minSpread` comparison and the hysteresis band semantics (decision 7) in that
  convention.

**Where to look**
- WS1/WS2 rate outputs; `aave-v3-configuration` IR strategy; `aave-v4-risk-premium`.

**Artifact**
- A written net-carry formula + worked numeric example for one direction, in fixed-point units the
  Service libs will use. Resolves PRD §9 net-carry `[SPIKE]`.

---

## WS5 — Common-unit aggregation (decisions 1, 10–16; finding F2)

**Questions**
- V3 oracle base currency/decimals vs V4 oracle (`Spoke.ORACLE`) base/decimals — are they the same
  unit? How to convert both sides to one common unit (USD or the pair's base asset)?
- Token decimal normalization between tokenA/tokenB and each oracle.
- Confirm the net-reserve `(R_A, R_B)` computation reads (V3 aToken-equiv via index; V4
  supplied/debt via `previewRemoveByShares`/`getUserDebt`).

**Where to look**
- V3 `AaveOracle`, V4 `Spoke.ORACLE` price source; `crane-utilities` math libs (`BetterMath`,
  fixed-point).

**Artifact**
- A common-unit conversion spec (which oracle, what decimals, rounding direction). Resolves PRD §9
  common-unit `[SPIKE]`.

---

## WS6 — Preview == execution view-call set (decisions 2, 6, 14)

**Questions**
- Enumerate the exact deterministic view calls that let the preview reproduce execution for:
  deposit recursion, rebalance extend/repay/flip, and the never-borrow unwind withdraw.
- Crucially: how does a **projected** supply/borrow change the rate and HF *within the same tx*?
  (V3: re-run IR strategy with adjusted utilization; V4: Hub `preview*` + recompute HF from CF.)
  Can these be simulated purely from view calls without state writes?
- Confirm there is no path that requires a non-view call to know the result (which would break
  preview==execution).

**Where to look**
- WS1/WS2 preview getters; V3 `DefaultReserveInterestRateStrategyV2.calculateInterestRates`;
  V4 Hub preview functions.

**Artifact**
- The canonical "projection" routine spec used by both `preview*` and execution, proving they
  share the same math. Resolves PRD §9 view-call `[SPIKE]`.

---

## WS7 — Efficiency-mode mapping (decision 24; finding F1)

**Questions**
- V3: how the vault opts into eMode (`setUserEMode`), category resolution for the pair, and the
  eMode `ltv`/`liquidationThreshold` that feed `min(our cap, Aave native)`.
- V4: confirm there is **no eMode**; define the analog (which `dynamicConfigKey` /
  `collateralFactor` applies, and whether the vault influences it or just reads it).
- Rewrite decision 24 to the version-correct mechanism.

**Where to look**
- `aave-v3-emodes`, `aave-v4-dynamic-config`, `aave-v4-risk-premium`.

**Artifact**
- A per-version efficiency-mode handling spec + a proposed decision-24 rewrite.

---

## WS8 — Freeze / pause flag reads (decision 23)

**Questions**
- V3: read `getActive/Frozen/Paused` from the reserve config bitmap per asset.
- V4: read `Reserve.flags` (paused/frozen/borrowable/liquidatable) per reserve.
- Define the graceful-degradation branch per flag (allow unwind/withdraw, block new leverage).

**Where to look**
- `aave-v3-configuration` (ReserveConfiguration flags), `aave-v4-spoke` (ReserveFlags).

**Artifact**
- A flag→behavior table per version for the loop/preview to follow.

---

## WS9 — V4 premium / risk-premium refresh in rebalance (PRD §9)

**Questions**
- Which exact Spoke/Hub calls refresh a position's premium/risk premium, and when must rebalance
  call them so HF/debt reads are accurate?
- Do premium shares change the never-borrow unwind math (extra debt to repay)?

**Where to look**
- `aave-v4-risk-premium`, `aave-v4-spoke` (`_updateUserRiskPremium`, `restore`, `PremiumDelta`).

**Artifact**
- The rebalance premium-refresh call sequence + its effect on unwind accounting.

---

## Suggested sequencing

1. **WS0** (deployment reality) — gates everything; may change fork-test strategy.
2. **WS1 + WS2** (read/write surfaces) — in parallel; feed everything below.
3. **WS3** (source lookup) — unblocks `deployVault`.
4. **WS4 + WS5 + WS6** (carry math, common unit, preview projection) — the core correctness trio.
5. **WS7 + WS8 + WS9** (efficiency mode, flags, premium refresh) — refine decisions 23, 24 + rebalance.

Outputs feed back into the PRD: revise decision 24 (F1), refine decisions 1/24 (F2), fill the net-carry
and common-unit definitions, and pin the §7 fork-test strategy.
