# Product Requirements Document (PRD): Aave V3.6 / V4 Cross-Version Carry Loop Vault

## 1. Overview

### Product Name
AaveCrossVersionLoopVault (or AaveV3V4CarryLoopDFPkg)

### Purpose
Create a multi-asset vault that performs recursive leveraged carry loops between Aave V3.6 and Aave V4 on configurable stablecoin pairs (e.g. USDG + USDC). 

The vault deposits one asset on the version offering the best net carry, borrows the paired asset, supplies the borrowed asset on the opposite version, borrows the original asset, and repeats. This captures rate differentials (supply yield on one version minus borrow cost on the other) while using strict on-chain gates to decide whether to extend the loop or repay debt legs.

The vault follows the standard IndexedEx CREATE3 + Vault Registry deployment pattern:
- Facets and the DFPkg are deployed via CREATE3Factory.
- The DFPkg is deployed via IndexedexManager.
- `deployVault(tokenA, tokenB)` on the DFPkg calls the VaultRegistry to create the actual proxy instance.
- All proxy deployment is forced through the Vault Registry (no direct `new` or bypass). Standard flow like AaveV3Stata: call registry to deploy, then initAccount on the proxy with the pair + source addresses.

The vault implements:
- MultiAssetBasicVault (for tracking the two base tokens).
- IStandardExchangeIn / IStandardExchangeOut (for composable entry/exit zaps; looping logic is integrated into the token route processing).
- Brand new dedicated AaveCrossVersionLoop facets for both versions + minimal standard facets.
- Looping uses version specific Service libraries for external calls. Repos (including new AaveV36AwareRepo, AaveV36PoolAwareRepo, AaveV4AwareRepo, AaveV4SpokeAwareRepo and LoopPositionRepo) are for mutable local state.

It is **not** an ERC4626 vault (no single underlying asset).

### Clarified Decisions (resolved 2026-06-21)

These supersede any conflicting wording elsewhere in this document:

1. **LTV gating is per-version only.** Each Aave version's LTV is gated independently using only that version's supplied/debt. There is **no cross-protocol aggregate LTV** for gating. Where this document previously said "aggregate effective LTV," that meant aggregating across assets *within a single version*, not across versions — any cross-version aggregate LTV requirement is removed.
2. **Accounting reconciles from live Aave.** `netBalanceOf` and all position math re-read live aToken / debt balances from Aave on each call. `LoopPositionRepo` and the aToken/supplyShare registrations in the MultiAsset repo are **caches/mirrors for composability, not the trusted source of truth.** No cached position value is trusted for gating or accounting.
3. **`forceRepay` is permissionless under low HF.** Anyone may repay the at-risk leg of a version whenever that version's Health Factor is below the safety threshold; below-threshold is the only condition under which the public path is enabled. There is no special owner-only path.
4. **The HF safety threshold comes from the Vault Fee Oracle**, served per source/asset, consistent with how LTV targets and min-spread thresholds are sourced. Aave-native liquidation thresholds are read on-chain for the HF calculation itself, but the *trigger* threshold is oracle-configured.
5. **A research spike is the first deliverable, before implementation.** It must resolve, at minimum: (a) Aave V3.6 `Pool` and Aave V4 `Spoke`/`Hub` interfaces and deployment addresses (chain TBD by spike); (b) the token → `Pool`/`Spoke` source-lookup used by `deployVault` validation; (c) the concrete set of Aave view calls that make `preview == execution` deterministic. It should also pin down the net-carry formula and common-unit aggregation (see Open Questions), which are load-bearing for gating.
6. **Deposit previews simulate the full combined flow.** `previewExchangeIn` must simulate reinvest-of-existing-positions **and** the recursive deposit loop end-to-end — including how each supply/borrow leg changes Aave rates and HF — and match execution exactly. Because truth is read live from Aave (decision 2), the preview must simulate against the same view calls execution uses, not replay cached numbers.

### Clarified Decisions — Economics & Shares (resolved 2026-06-22)

These also supersede any conflicting wording elsewhere. The vault must be **reusable for any valid pair, including volatile pairs (e.g. ETH/WBTC)** — no stable-peg assumption may be baked in.

**Economics**

7. **Permissionless rebalance has no caller reward.** Liveness relies on aligned shareholders/keepers. Add a **hysteresis band + minimum interval** between rebalances so the position cannot be churned back and forth (anti-griefing).
8. **No-carry fallback = unwind to safest state.** When net carry is not positive above threshold, actively unwind leveraged legs down toward flat/idle (de-risk over yield), rather than holding leverage.
9. **Aave incentive/reward tokens are claimed and folded into carry.** The vault claims them and compounds them into net value.

**Share accounting & exchange model**

10. **Shares are an LP-style proportional claim on the net reserves `(R_A, R_B)`** (net = supplied − debt across both versions, read live per decision 2). Use the *proportional-claim* half of the constant-product model only — **never** the `xy=k` internal pricing curve (it is un-arbitraged and exploitable, fatal for volatile pairs). First mint uses the geometric mean with a permanently locked **`MINIMUM_LIQUIDITY`**, which also serves as first-depositor/inflation protection (decision 13).
11. **Single-token in / single-token out only** — mandated by `IStandardExchange`. There is **no proportional/multi-token withdraw** and it will not be added. Every `exchangeIn` accepts one token; every `exchangeOut` returns one token.
12. **All conversions are priced by the Aave oracle, never by a DEX.** No Aerodrome/external-swap dependency. The Aave oracle is already mandatory for HF/LTV/valuation, so it adds no new dependency; it is load-bearing on every entry and exit. A round-trip is value-neutral at the oracle instant; the residual risks (oracle-latency front-running; exposure shift onto remaining holders) are covered by the withdrawal fee (decision 14).
13. **Deposit (`exchangeIn`):** accept any one token of the pair, value it at the oracle, mint proportional shares; the deposited token enters the loop (supply it, borrow the other, recurse). Single-token deposit is always solvency-safe because it *adds* collateral and raises HF headroom.
14. **Withdraw (`exchangeOut`) mechanic — never borrow, always unwind:** to service a withdrawal of value `V = f·NAV` requested in token X, (a) apply the **withdrawal fee** (oracle-latency protection **and** compensation to remaining holders for the forced de-leverage + exposure shift), giving net `X_out = V·(1−fee)/p_X`; (b) **deleverage only** — peel loop layers (withdraw supply → repay debt → frees collateral → repeat), **never borrowing** — until ≥ `X_out` of token X is free on the supply side of either or both versions; (c) withdraw `X_out` from supply and send to the user; (d) any off-token and extra freed token remain as **idle raw tokens** (MultiAsset) for the next `rebalance()` to re-deploy/re-lever. Because servicing only ever deleverages, **HF is monotonically non-decreasing**, so there is no HF-gating and no partial fill.
15. **Withdrawals are all-or-revert.** The only revert conditions are (a) the requested value after fee exceeds the vault's net supply of token X (`X_out > ~R_X`), or (b) Aave-side available liquidity prevents withdrawing the needed supply. Both are deterministic and surfaced by `previewExchangeOut`. A user wanting more than the pool's X-side value must withdraw in the other token or a smaller amount.
16. **Invariant: net reserves stay non-negative (`R_A, R_B ≥ 0`).** Proportional-quantity claims require it; the loop/rebalance must maintain it.
17. **Known limitation — irreducible tail / no full DEX-free liquidation.** Because single-token-only + no-DEX means the off-token cannot be truly converted, the entire vault cannot be liquidated into one token without a DEX. The permanent `MINIMUM_LIQUIDITY` lock (decision 10) ensures the pool never fully drains; deep-drawdown exits become limited by net-supply/liquidity (decision 15) rather than HF.
    - **Finding (verified on local markets 2026-06-23):** a pure never-borrow unwind (decision 14) of a *fully maxed, symmetric* cross-collateralized loop **asymptotically stalls** — withdraw/repay frees only the HF buffer each pass and the mutual repays shrink faster than they free capacity, so the position cannot be fully closed by deleveraging alone (full closure would need flash loans, which are excluded). This is fine for the **actual withdraw path** (partial `X_out` ≤ freeable from the HF buffer, decisions 14/15), which deleverages and stays solvent. Implication: per-deposit leverage should leave headroom below max so withdrawals remain serviceable; treat "fully unwind a maxed position" as out of scope for the no-DEX core.

**Fees & bounds**

18. **Withdrawal fee = fixed bps, oracle-sourced.** A flat fee rate served by the Vault Fee Oracle (per source/asset or vault type), consistent with how LTV/HF/spread thresholds are sourced. Applied on exit per decision 14 (oracle-latency protection + exposure-shift compensation to remaining holders).
19. **Usage/performance fee = share-dilution on reserve growth (Uniswap-V2-style protocol mint).** This *is* the marker "usage fee," realized on carry — **not** on deposits or AUM. On accrual: (a) measure how much the net reserves have *earned* since the last accrual (carry/yield only, excluding deposit/withdraw-driven changes); (b) convert that earned value to its equivalent in vault shares at the current share price; (c) **mint `fee%` of those shares to the Vault Fee Oracle `feeTo()` address.** This dilutes all holders pro-rata, including a withdrawing user. The `fee%` and `feeTo()` come from the Fee Oracle/marker. Fee accrual must be reflected in `preview` (the dilution changes share price), and accrued at/around each interaction (deposit, withdraw, rebalance).
20. **Recursive deposit loop bound = target-LTV stop + hard max-iterations backstop.** Primary stop is target-LTV-within-threshold (per version/leg); a hard max-iterations cap is also enforced so gas and `preview == execution` stay bounded and deterministic.
21. **`MINIMUM_LIQUIDITY` is burned from the first deposit (Uniswap-V2 style).** A small portion of the first depositor's shares is permanently locked/burned — no separate seeding step. Serves both first-depositor/inflation protection (decision 10) and the never-fully-drains guarantee (decision 17).

**Governance, resilience & strategy**

22. **Immutable logic, oracle-driven params.** No facet upgrades and **no pause** after deploy; logic is fixed. The only mutable surface is the Vault Fee Oracle (LTV/HF targets, fees, hysteresis, max-iterations, thresholds). Safety relies on permissionless `rebalance()` + `forceRepay` (decisions 3, 7). Consequence: the Fee Oracle is the **sole trusted governance surface** — its own trust/governance matters (tracked as a risk).
23. **Graceful degradation on Aave reserve freeze/pause.** Each leg must check the reserve's frozen/paused/active flags (per version) before acting. If a reserve is frozen/paused: still allow **unwind/withdraw** on the available side, **block new leverage** on the affected side, and have rebalance **de-risk**. Previews must reflect blocked operations (so `preview == execution` holds during degradation).
24. **Maximize correlated-asset efficiency per version, by each version's own mechanism (revised per spike finding F1 — V4 has no eMode).**
    - **V3.6:** opt into **eMode** when both tokens share an eMode category (`setUserEMode`); this raises the Aave-native LTV/liquidation-threshold used in `min(our cap, Aave native)` (decision 1). Fall back to normal (category 0) otherwise. Package validation resolves category membership via the eMode collateral/borrowable bitmaps.
    - **V4:** there is **no eMode**. The efficiency analog is the reserve's **`DynamicReserveConfig.collateralFactor`** (per `dynamicConfigKey`) plus the **`collateralRisk` / risk-premium** system. The vault reads the applicable `collateralFactor` (V4's borrow-power param; there is no separate "LTV") and uses it in the per-version gate; it does not "opt into" a mode.
    - Service libs abstract this version asymmetry behind a common "effective borrow-power" read (V3 `ltv`/`LT` vs V4 `avgCollateralFactor`/`collateralFactor`). The spike (WS7) pins the exact reads.
25. **Direction flip = atomic full flip.** When the best carry direction reverses (and hysteresis + min-interval gates pass), a single rebalance call **fully unwinds the old orientation to flat, then re-levers the opposite direction**. Routing through flat keeps it HF-safe (deleverage then rebuild under per-leg gates). The rebuild is still bounded by the max-iterations cap (decision 20), and the flip must be preview-exact. (This is the one rebalance action that is *not* "one leg per call.")

**Parameter sourcing & donations**

26. **All tunable params are served by the Vault Fee Oracle via the 3-scope override pattern** (`default(source, asset)` / `…OfTypeID(vaultTypeID, source, asset)` / `…ofVault(vault, source, asset)`), same as LTV. Full set: LTV target + allowed deviation, HF safety threshold, withdrawal-fee bps, usage/performance `fee%` + `feeTo()`, min net-carry spread, rebalance hysteresis band, min rebalance interval, max iterations. This is consistent and fully tunable; it also concentrates trust in the Fee Oracle (decision 22 risk).
27. **Direct token donations / untracked raw balances are treated as reserve growth.** Any raw balance not produced by a tracked vault op is absorbed into NAV on the next interaction (and re-deployed by rebalance), and — because it reads as reserve growth — is subject to usage/performance-fee dilution (decision 19). The first-depositor/inflation case is already guarded by `MINIMUM_LIQUIDITY` (decision 21).

### Spike-resolved Decisions (resolved 2026-06-22; see `AaveV3V4CrossVersionCarryLoopVault.Spike.md`)

Verified against the Crane sources at `lib/.../aave/v3.6` and `lib/.../aave/v4`.

28. **Net-carry formula.** Rates: V3 supply = `ReserveDataLegacy.currentLiquidityRate` (RAY), V3 borrow = `currentVariableBorrowRate` (RAY); V4 borrow = base `Hub.getAssetDrawnRate` × (1 + `riskPremium`); V4 supply is **derived** (decision 33). Per loop orientation (supply X on version A, borrow Y on A, supply Y on B, borrow X on B): `netCarry = [supplyAPY_A(X) − borrowAPY_B(X)] + [supplyAPY_B(Y) − borrowAPY_A(Y)]`, weighted by leg notional in the common unit. Both orientations evaluated; pick the higher that clears `minSpread + hysteresis` (decisions 7, 25). Service libs normalize RAY/BPS to one fixed-point convention.
29. **Common-unit normalization (two distinct oracles).** V3 oracle is **asset-keyed** (`getAssetPrice(asset)`, `BASE_CURRENCY_UNIT` e.g. 1e8). V4 oracle (`Spoke.ORACLE()`) is **reserveId-keyed** (`getReservePrice(reserveId)` with its own `decimals()`). Normalize both prices (plus token decimals) to a common **USD** unit before any cross-version LTV/HF/carry comparison. Confirm both are USD-quoted on Ethereum.
30. **Shared projection routine makes preview == execution view-only.** Both IR strategies are pure views of (liquidity, debt): V3 `calculateInterestRates(params)` on the **Pool-level** strategy (v3.4+); V4 `calculateInterestRate(assetId, liquidity, drawn, …)`. HF is **recomputed by the preview itself** from projected balances × oracle prices × (V3 `liquidationThreshold` / V4 `collateralFactor`) — the getters reflect current, not projected, state. One routine is shared by `preview*` and execution (decisions 2, 6).
31. **V4 premium debt is included in the never-borrow unwind.** A V4 position's debt = drawn + **premium** (`Spoke.getUserDebt` → `(drawn, premium)`, `getUserPremiumDebtRay`). The unwind (decision 14) must repay premium debt too. Rebalance calls `Spoke.updateUserRiskPremium(vault)` before HF/debt reads so they are accurate.
32. **Source lookup (WS3).** V4: `Hub.getAssetId(token)` → `Spoke.getReserveId(hub, assetId)`; the Package must be **given the Hub + Spoke addresses** at deploy (no global registry). V3: token → Pool via `PoolAddressesProvider`. Stored as immutables in the AwareRepos (decision: AwareRepos).
33. **V4 supply APY accrues premium interest to suppliers.** Per `AssetLogic.getUnrealizedFees`, only `liquidityFee%` of total-owed growth (drawn + premium) goes to the protocol fee receiver; the remainder grows supplier value. So `supplyAPY_v4 ≈ (drawnInterest + premiumInterest) × (1 − liquidityFee) / totalAddedAssets` — the premium term must not be omitted.
34. **Target chain = Ethereum mainnet (deployment matrix).** Confirmed via `bgd-labs/aave-address-book`: **Aave V4 is Ethereum-only** (`AaveV4Ethereum.sol`; Hubs Core/Plus/Prime + Spokes), **Base has V3 only** (`AaveV3Base.sol`). The cross-version premise needs both live → initial target and fork tests are **Ethereum** (real V3 + real V4). Pull concrete addresses from `AaveV3Ethereum.sol` / `AaveV4Ethereum.sol` at implementation time. Design stays chain-agnostic for when V4 reaches Base/other chains. Supersedes the earlier "targets Base" wording.

### Key Goals
- Positive net carry via cross-version loops with dynamic direction selection (configurable pairs).
- Permissionless `rebalance()` with strict on-chain gates (rate spreads from Vault Fee Oracle + direct HF/rates).
- Full recursive looping on deposit until target LTV (per version/leg, within threshold from oracle).
- Accurate accounting: MultiAsset only for raw tokens the vault directly controls. **Aave supply and debt (both versions) are reconciled from live Aave reads on each call (decision 2)** — `LoopPositionRepo` and the registered aToken/supplyShare assets are caches/mirrors for composability, not the trusted source. Net balances for the two base tokens = sum of lending side on both versions minus sum of debt owed on both versions (computed from live aToken/debt balances combined with multi-asset raw state in the loop/exchange logic). Goal: accurately reflect the state after the loop is unwound by repaying the debt. Register aToken/supplyShare contracts as additional assets in the multi-asset repo (vault never holds them directly; Aave holds for vault address; loop logic updates the mirror after each Aave operation, but reads reconcile from live Aave).
- Per-version position tracking + direct integration: V3.6 via direct Pool; V4 via direct Spoke calls (vault as onBehalfOf/user; no PositionManager). Facet may call additional Spoke/Hub for premium/risk premium refresh as part of rebalance.
- Deployment validation: Package ensures both tokens exist, are usable as collateral, and borrowable on **both** Aave versions (reverts otherwise). Looks up pool/spoke from token if possible via Aave. Also resolves **per-version correlated-efficiency settings** (decision 24): V3.6 eMode category membership (opt-in via `setUserEMode`); V4 the applicable `collateralFactor` / risk config (no eMode).
- Full previews must match execution (implemented in IStandardExchangeIn/Out previewExchangeIn/Out functions).
- Max LTV per version/protocol/asset-being-borrowed defined via Vault Fee Oracle (new functions: defaultLTV(address source, address asset), defaultLTVOfTypeID(bytes4 vaultTypeID, address source, address asset), defaultLTVofVault(address vault, address source, address asset)). Source = actual Aave contract (Pool for v3.6, primary Spoke for v4). Enforcement: hard per-version LTV check (per version, no cross-protocol aggregate — decision 1), take min(our cap, Aave native). Oracle provides targetLTV and allowed deviation/threshold per source/asset. LTV gating per version (independent); check per leg of the loop.
- Use each version's Aave oracle prices for its positions (supplied value = aToken equiv balances = supplied * current rate; debt = debt shares * rate), sum in common unit (e.g. USD or base asset of pair). Rebalance always re-queries current balances/rates before deciding.
- Composable with the rest of IndexedEx.
- Safe, auditable, using existing patterns (CREATE3, registry, fee oracle, multi-asset + exchange, Repo/Service libs, version-specific Services for external calls).
- Looping integrated with exchangeIn/Out token route processing.
- On deposit via exchange: secure/confirm deposit amount first (hold aside), reinvest on existing (using only existing positions, not touching new deposit; via rebalance-like first), then add the new deposit to the loop. Deposit as collateral on a version; check safe to borrow on that version (per-version LTV/HF), if so borrow and deposit on other; check other, borrow and deposit back. Full recursive until target LTV (per version/leg) within threshold from oracle.
- Rebalance: permissionless. Always compute projected net carry and HF for 'extend this direction' vs 'repay this leg' vs 'do nothing', pick the best that meets gates. Evaluates both directions, picks the one with positive net carry above threshold; extends if possible or repays the worse leg if overall carry negative or HF low. Use Fee Oracle for minSpread/thresholds + direct for rates/HF.
- Add aggregate or per-version target HF, max iterations, and key events (rebalance action, gate decision, direction flip). **`forceRepay` is permissionless under low HF (decision 3): anyone may repay a version's at-risk leg only when that version's HF is below the safety threshold (decision 4: threshold from the Vault Fee Oracle).**
- Use Aware Repos (initialized in Package initAccount from immutable values in Package; look up pool/spoke from token if possible).

### Scope / Non-Goals
- Focus on stable / low-vol pairs where carry is reliable.
- Single pair per vault proxy (DFPkg supports any valid tokenA/tokenB at deploy time).
- Permissionless rebalance only.
- Direct Aave calls inside rebalance (no extra oracles for rates).
- V3.6: direct Pool. V4: direct Spoke (vault as onBehalfOf).
- No on-chain flash loans across versions (rebalance not required atomic across V3/V4).
- Not for high-leverage volatile assets.
- **Initial implementation targets Ethereum mainnet** — the only chain where both Aave V3.6 and Aave V4 are live (decision 34; V4 is Ethereum-only, Base has V3 only). Design stays chain-agnostic for when V4 reaches other chains.
- Repos for local mutable state; Service libs for external protocol calls.
- Full recursive on deposit; rebalance for ongoing optimization.
- LTV gating per version independent (no aggregate LTV across protocols). Gating around each leg.
- Effective LTV uses aToken equiv balances, priced via Aave oracles per side, aggregate in common unit.
- MultiAsset only raw tokens; Aave in LoopPositionRepo; net by combining in loop facet. Update multi-asset repo after Aave ops with new actual balance (ERC20 balanceOf(vault)). Register a/supply positions as additional assets in repo (updated internally by loop logic).

## 2. Architecture & Deployment Pattern

### Deployment Flow (Standard IndexedEx + Vault Registry)
1. CREATE3Factory deploys all Facets (brand new dedicated AaveCrossVersionLoopV3Facet + V4Facet + minimal standard: MultiAssetBasicVaultFacet, exchange in/out facets, ERC20/2612/etc.) and the DFPkg.
2. IndexedexManager deploys the DFPkg.
3. Call `dfpkg.deployVault(tokenA, tokenB)` on the Package.
4. The Package:
   - Validates both tokens are listed, usable as collateral, and borrowable on **both** Aave V3.6 and V4 (reverts otherwise). Looks up pool/spoke from token if possible via Aave.
   - Calls into the VaultRegistry to deploy the actual Diamond proxy instance.
5. InitAccount on the proxy with the pair + source addresses (standard like AaveV3Stata).
6. The resulting proxy is registered in the VaultRegistry.
7. **Strict Restriction**: All production proxy instances **must** come through the Vault Registry path. Direct deployment or bypass is prohibited.

The DFPkg's vaultDeclaration: lending + multiAsset, with usage fee via marker ID. The usage fee is realized as **share-dilution on reserve growth** (decision 19), not on deposits/AUM.

Aware Repos (AaveV36AwareRepo, AaveV36PoolAwareRepo, AaveV4AwareRepo, AaveV4SpokeAwareRepo) initialized in Package initAccount from immutable values in the Package.

### Facets (DFPkg Composition)
- **Dedicated custom** (brand new AaveCrossVersionLoop facets for both versions):
  - Logic for cross-version looping integrated into IStandardExchangeIn/Out token route processing.
  - No special standalone "Loop Facet"; use Repo + Service libraries (version specific Services for external Aave calls).
  - Direct integration: V3.6 Pool, V4 Spoke (vault as onBehalfOf). May call additional Spoke/Hub for premium/risk premium refresh in rebalance.
  - Custom overriding views (e.g. netBalanceOf(token)) that adjust by internal debt positions from repo.
- **Minimal standard** (reuse):
  - MultiAssetBasicVaultFacet (only raw tokens the vault directly controls).
  - IStandardExchangeIn/Out facets (looping integrated here).
  - Basic ERC20, permit, metadata, etc. facets.
- Supporting: LoopPositionRepo (per-version supplied/borrowed + dynamic state). Repos always mutable for local state.

The DFPkg wires custom loop logic (in exchange) + standard multi-asset + exchange facets. Use Service libs for external calls (not repos).

### State & Accounting
- MultiAssetBasicVault tracks only the two raw/base tokens the vault directly controls.
- Aave supply and debt (both versions) are reconciled from **live Aave reads on each call** (decision 2). `LoopPositionRepo` mirrors per-version supplied/borrowed for composability and convenience, but is not the trusted source for gating or accounting.
- Net balances for the two base tokens = sum of lending side on both versions minus sum of debt owed on both versions. Always computed from live aToken/debt balances combined with multi-asset raw state in the loop/exchange logic.
- Register aToken (v3.6) / supplyShare (v4) contracts as additional assets in the multi-asset repo. The vault never 'holds' them directly (Aave holds for the vault address); the loop logic updates the repo's internal balances after each Aave operation.
- Goal: accurately reflect the state after the loop is unwound by repaying the debt.
- Per-version tracking in LoopPositionRepo.
- Dynamic direction selection based on rates.
- After every Aave op that changes raw token balance (e.g. supply moves token to Aave), call multi-asset repo's update with new actual balance (ERC20 balanceOf(vault)).

## 3. Core Mechanics

### Deposit Flow (via IStandardExchangeIn / token route processing)
- **Single token in** (decisions 11, 13): accept any one token of the pair, value it at the Aave oracle, mint **proportional LP-style shares** (claim on net reserves; decision 10). Single-token deposit is always solvency-safe (adds collateral, raises HF headroom).
- Secure/confirm the actual deposit amount first (hold it aside; transfer to confirm).
- Reinvest any accrued interest on existing Aave positions first (using only existing positions, not touching the new deposit; via rebalance-like logic first).
- Then add the new deposit to the loop: take the token, deposit it as collateral on a version.
- Check if safe to borrow on that version of Aave (per-version LTV/HF gate).
- If so, borrow and deposit on the other version.
- Check the other version; if safe, borrow and deposit back on the previous.
- Full recursive loop until reach the target LTV (per protocol version / leg; within a threshold from the Vault Fee Oracle), **with a hard max-iterations backstop (decision 20)** so gas and preview stay bounded.
- LTV gating per version (independent; no aggregate LTV across protocols). Gating around each leg.
- Use 'aToken' equivalent balances (supplied * current rate) for supplied value; debt shares * rate for debt value. Priced via each version's Aave oracle per side, aggregated in common unit (e.g. USD or base asset of pair).
- Previews (in exchangeIn/Out) must match execution (decision 6): `previewExchangeIn` simulates the **full combined flow** — reinvest-of-existing-positions then the recursive deposit loop end-to-end, including how each leg changes Aave rates and HF — and matches execution exactly. Because position state reconciles from live Aave (decision 2), the preview simulates against the same Aave view calls execution uses, not cached numbers.

### Rebalance / Gating (Permissionless)
- `rebalance()` (integrated in exchange logic) is fully permissionless — anyone can call.
- On-chain gate (strict):
  - Direct Aave calls for current rates + HF (V3 Pool.getReserveData etc.; V4 Spoke.getUserAccountData etc.).
  - Use Vault Fee Oracle for minSpread/thresholds.
  - Always compute projected net carry and HF for 'extend this direction' vs 'repay this leg' vs 'do nothing'; pick the best that meets gates.
  - Evaluates both directions; picks the one with positive net carry above threshold.
  - Extends if possible or repays the worse leg if overall carry negative or HF low.
  - May call additional Spoke/Hub for premium/risk premium refresh.
  - Use version-specific Service library to abstract all calls (including rate calcs).
- Rebalance always re-queries current balances/rates before deciding.
- **No caller reward (decision 7).** Liveness relies on aligned shareholders/keepers. Enforce a **hysteresis band + minimum interval** between rebalances to prevent churn/griefing.
- **No-carry fallback (decision 8):** when net carry is not positive above threshold, actively **unwind to safest state** (toward flat/idle) rather than holding leverage.
- **Re-deploy idle tokens (decision 14):** raw tokens left idle by withdrawals are re-levered to target on rebalance.
- **Claim Aave incentive/reward tokens and fold into carry (decision 9).**
- **Graceful degradation (decision 23):** check each reserve's frozen/paused/active flags per version before a leg; if frozen/paused, allow unwind/withdraw, block new leverage, de-risk.
- Add key events (rebalance action, gate decision, direction flip).
- Add aggregate or per-version target HF, max iterations.

### Withdraw / Exit (single token, never-borrow unwind — decisions 11–17)
- Via IStandardExchangeOut; **single token out only** (no proportional/multi-token withdraw — decision 11).
- Burner's claim = fraction `f` of net reserves, valued at the Aave oracle. For a withdrawal of value `V = f·NAV` requested in token X:
  1. Apply the **withdrawal fee** → net `X_out = V·(1−fee)/p_X` (decision 14).
  2. **Deleverage only — never borrow.** Peel loop layers (withdraw supply → repay debt → frees collateral → repeat) until ≥ `X_out` of token X is free on the supply side of either or both versions.
  3. Withdraw `X_out` from supply, send to user.
  4. Off-token and any extra freed token remain as **idle raw tokens** (MultiAsset) for the next `rebalance()` to re-deploy/re-lever.
- Because servicing only ever deleverages, **HF is monotonically non-decreasing** → no HF-gating, no partial fills.
- **All-or-revert** (decision 15). Revert only if `X_out` exceeds the vault's net supply of token X, or Aave-side liquidity prevents the needed supply withdrawal. Both surfaced by `previewExchangeOut`.
- Single-token exit shifts remaining holders toward the off-token and temporarily de-levers the pool (idle tokens until rebalance); the withdrawal fee compensates remaining holders, and rebalance re-levers to target.
- Previews must match execution (oracle-priced, deterministic, no DEX quote).

### Dynamic Direction + Net Carry
- At every step, evaluate both possible loop directions using live rates + projected net carry + HF impact.
- Net carry = supply yield - borrow cost (per direction/version; from Service lib).
- Choose/act on the best that meets gates.
- **Direction flip = atomic full flip (decision 25):** when the best direction reverses and hysteresis + min-interval gates pass, one call fully unwinds the old orientation to flat then re-levers the opposite (HF-safe via flat; rebuild bounded by max-iterations; preview-exact). This is the exception to "one leg per call."

## 4. LTV, Parameters & Fee Oracle
- **LTV**: Per protocol, per version, per asset being borrowed. Via Vault Fee Oracle:
  - defaultLTV(address source, address asset)
  - defaultLTVOfTypeID(bytes4 vaultTypeID, address source, address asset)
  - defaultLTVofVault(address vault, address source, address asset)
- **All tunable params follow this same 3-scope override pattern (decision 26):** LTV target + deviation, HF safety threshold, withdrawal-fee bps, usage/perf `fee%` + `feeTo()`, min net-carry spread, hysteresis band, min rebalance interval, max iterations. Each exposes `default…` / `…OfTypeID` / `…ofVault` resolution.
- Source = actual Aave contract address (Pool for v3.6, primary Spoke for v4). Looked up by Package using token -> Aave reserve info (if possible via Aave APIs/contracts).
- Enforcement: Hard per-version LTV check, take min(our cap, Aave native). No cross-protocol aggregate LTV (decision 1). The "Aave native" borrow-power used in `min(...)` is version-specific (decision 24): on **V3.6** it is the eMode LTV when the pair qualifies (else the asset's normal LTV); on **V4** it is the reserve's `collateralFactor` (no eMode).
- Oracle provides targetLTV + allowed deviation/threshold per source/asset.
- For recursion stop on deposit: stop when projected LTV after leg would exceed target - threshold (e.g. target - 1%). Check projected before each atomic leg.
- LTV gating per version independent (per leg).
- Effective LTV per version (no cross-protocol aggregate for gating). Use aToken equiv balances, priced via Aave oracles per side, aggregate in common unit.
- **Other (minimal + additions)**: Only LTV caps + min net carry / spread thresholds primarily. Add aggregate or per-version target HF, max iterations, key events. `forceRepay` is permissionless under low HF (decision 3): if any version's HF < safety threshold from the Fee Oracle (decision 4), anyone can repay that version's at-risk leg. No owner-only path.
- **Share/exchange parameters (decisions 7, 10, 18–21):** withdrawal fee = fixed bps oracle-sourced (decision 18); usage/performance fee = share-dilution on reserve growth minted to Fee Oracle `feeTo()` (decision 19); permanent `MINIMUM_LIQUIDITY` burned from first deposit (decision 21); rebalance hysteresis band + minimum interval (decision 7); hard max-iterations backstop (decision 20). Source tunable values from the Fee Oracle where applicable.
- Thresholds/gates from Fee Oracle. Direct rates/HF for comparisons.
- No per-vault mutable rate thresholds beyond oracle.

## 5. Interfaces
- `IStandardVaultPkg` (via DFPkg) with lending + multiAsset, usage fee via marker ID.
- `IStandardExchangeIn` / `IStandardExchangeOut` (zaps + integrated looping/previews; full previews in previewExchangeIn/Out). **Single token in / single token out only — no proportional withdraw (decision 11).** Shares are an LP-style proportional claim on net reserves, oracle-priced on entry/exit (decisions 10, 12); withdraw uses the never-borrow unwind mechanic and is all-or-revert (decisions 14, 15).
- MultiAssetBasicVault interfaces (raw tokens).
- Custom views in exchange/loop logic: rebalance, getCurrentLoopState, getBestDirection, netBalanceOf, etc.
- Package exposes `deployVault(tokenA, tokenB)` (validates + forces registry; standard flow).

## 6. Risks & Mitigations
- Rate/liquidity flip: re-check rates + HF inside rebalance before every leg; gates; re-query always.
- Dual HF/liquidation (separate per version): per-version LTV/HF checks + gates; conservative margins; rebalance prefers de-risk.
- Oracle/rate staleness: direct on-chain Aave calls (per version's oracles for pricing).
- Cross-version desync / unwind accuracy: explicit per-version tracking in repo; net accounting matches unwind value.
- Over-leverage: per-leg LTV gates from oracle; target LTV stop; max iterations.
- Gas: bounded work per call (one direction + one leg); max iterations for deposit loop.
- Composability: vault shares represent net position; can be used elsewhere.
- **Single-token-exit exposure shift (decisions 12, 14):** each exit pushes remaining holders toward the off-token and temporarily de-levers the pool; mitigated by the withdrawal fee (compensation) + prompt rebalance re-levering. For volatile pairs size the fee conservatively.
- **Oracle-latency front-running (decision 12):** entry/exit priced at the Aave oracle is exposed to timing around oracle ticks; mitigated by the withdrawal fee/spread (and optionally a minimum holding period).
- **Share-inflation / first depositor (decisions 10, 13):** permanent `MINIMUM_LIQUIDITY` lock + geometric-mean first mint.
- **Net-reserve negativity (decision 16):** loop/rebalance must keep `R_A, R_B ≥ 0`; otherwise proportional-quantity claims break.
- **Fee Oracle is the sole governance surface (decisions 22, 26):** immutable logic + no pause + all params oracle-served means a compromised/misconfigured oracle is the main centralization risk; depends on the oracle's own governance. No code upgrade or pause fallback.
- **Donation / untracked balance (decision 27):** absorbed as reserve growth (benign — gifts value to holders, taxed by usage-fee dilution); first-depositor inflation guarded by `MINIMUM_LIQUIDITY`.
- **Aave reserve freeze/pause (decision 23):** handled by graceful degradation (unwind/withdraw allowed, new leverage blocked, rebalance de-risks); previews reflect blocked ops.
- **Correlated-efficiency param changes (decision 24):** Aave can change V3 eMode category/LTV or V4 `collateralFactor`/risk config; the loop reads the native borrow-power live per version and `min`s with our cap, so a downgrade tightens gating automatically.
- **Atomic full flip cost (decision 25):** large one-shot position change; bounded by max-iterations + hysteresis/min-interval to prevent thrash; must be preview-exact.
- Add events for decisions/actions. ForceRepay for emergencies.
- Use AwareRepos/Services for clean version abstraction. Package looks up sources.

## 7. Testing Requirements
- Full preview must match execution on all paths (deposit with full recursive loop, rebalance decisions/actions, partial/full repay, withdraw). Implemented in exchange previews.
- Fork tests on **Ethereum mainnet** with **real Aave V3.6 + real Aave V4** (both live there; no harness needed). Crane harnesses/Spokes only as a fallback for non-Ethereum chains.
- Rate manipulation, fork blocks, gating boundaries, direction flips, recursive deposit to stop condition.
- Multiple pairs; HF edges, caps, liquidity limits, interest accrual on supplies during loop.
- Deployment validation (Package reverts on bad pairs; source lookup).
- End-to-end unwind accounting accuracy. Events. ForceRepay.
- **Share mint/burn:** single-token deposit minting proportional shares; single-token withdraw via never-borrow unwind (decision 14); all-or-revert boundaries (insufficient net-supply of requested token; Aave liquidity limits — decision 15); withdrawal-fee correctness; `MINIMUM_LIQUIDITY` lock + first-depositor/inflation resistance; round-trip is value-neutral (no extraction) net of fee; oracle-latency timing covered by fee; exposure-shift + re-lever after exit; volatile-pair (e.g. ETH/WBTC) parity, not just stables.
- **Usage/performance fee:** dilution mint to `feeTo()` matches measured reserve growth × `fee%`; no fee on deposit/withdraw principal; preview reflects the dilution (decision 19).
- **Graceful degradation:** frozen/paused Aave reserve → unwind/withdraw still work, new leverage blocked, rebalance de-risks; previews match under degradation (decision 23).
- **Correlated efficiency (decision 24):** V3.6 eMode opt-in (qualifying pair uses eMode LTV, else normal); V4 uses reserve `collateralFactor` (no eMode); native downgrade tightens gating.
- **Atomic direction flip:** full unwind-to-flat then re-lever opposite in one call; HF-safe through flat; hysteresis prevents flip-flop; preview-exact (decision 25).
- Integration with exchange token routes.

## 8. Implementation Notes
- Follow all IndexedEx/Crane rules: CREATE3 only, no `new`, vaults through manager/registry, preview==execution, etc.
- New dedicated loop logic (in exchange facets) keeps V3/V4 separated via version-specific Services + AwareRepos.
- MultiAsset + LoopPositionRepo combination for accounting.
- Looping fully integrated into IStandardExchangeIn/Out processing.
- Use version-specific Service libraries for all external Aave calls (rates, supply, borrow, repay, HF, etc.). Get addresses from AwareRepos.
- Repos mutable for local/positions state.
- Package initAccount sets up AwareRepos from immutables (lookup pool/spoke from token if possible).
- Start from AaveV3Stata pattern for structure, marker, fee oracle, registry flow, deploy/init.
- Aggregate LTV per version (independent gates); use aToken equivs + Aave oracles.
- On deposit/exchange: secure first, reinvest on existing only, then user's deposit + recursive per-leg loop.
- Rebalance: projected projections for decisions; permissionless + gates from oracle + direct data.
- V4: direct Spoke (as onBehalfOf); additional Hub/Spoke calls if needed for premium/risk.
- No PositionManager for V4 in this design.

## 9. Open Questions / Future (to resolve in impl or follow-on)

**Sequencing (decision 5): the research spike is complete** (`AaveV3V4CrossVersionCarryLoopVault.Spike.md`). The `[SPIKE]` items below are now **resolved** (folded into decisions 24, 28–33); only the items without `[SPIKE]` remain open for implementation / follow-on.

- ✅ _[SPIKE→done]_ Aave V3.6 `Pool` and Aave V4 `Spoke`/`Hub` **interfaces** verified in Crane; **deployment matrix confirmed** — both live together on Ethereum (decision 34).
- ✅ _[SPIKE→done]_ Source lookup — decision 32 (`Hub.getAssetId` → `Spoke.getReserveId`; Package given Hub+Spoke).
- ✅ _[SPIKE→done]_ Preview view-call set — decision 30 (IR-strategy views + self-computed HF).
- ✅ _[SPIKE→done]_ Net-carry formula — decision 28; V4 supply-APY derivation — decision 33.
- ✅ _[SPIKE→done]_ Common-unit aggregation — decision 29 (two oracles, normalize to USD).
- ✅ _[SPIKE→done]_ Correlated-efficiency reads — decision 24 + spike WS7 (V4 has no eMode; uses `collateralFactor`).
- ✅ _[SPIKE→done]_ Reserve frozen/paused/active reads — spike WS8 (V3 config bitmap; V4 `getReserveConfig`).
- ✅ _[SPIKE→done]_ V4 premium/risk-premium refresh — decision 31 (`updateUserRiskPremium`; premium debt in unwind).
- Any V4 dynamic config / risk premium impact on accounting beyond premiums.
- Events granularity for "gate triggered with reason".
- Integration depth with V4 Hub features.
- Exact **withdrawal-fee bps value** (sourcing decided: oracle fixed bps, decision 18), plus optional minimum-holding-period.
- Exact **usage/performance fee `fee%`** and the precise reserve-growth baseline/accrual method (mechanism decided, decision 19; e.g. Uniswap-V2 `kLast`-style tracking adapted to net-value).
- Exact **hysteresis band + minimum-interval** values for rebalance (mechanism + oracle-sourcing decided, decisions 7, 26).
- Exact **max-iterations cap** value (mechanism decided as backstop, decision 20).
- `MINIMUM_LIQUIDITY` size (seeder decided: burn from first deposit, decision 21).
- Proxy re-pairing: **always a new deploy** (immutable logic, no facet upgrades — decision 22; and the `MINIMUM_LIQUIDITY` lock means full unwind never occurs — decision 17). Listed for completeness; effectively resolved.
- Exact test matrix for preview match + rate edge cases.

This PRD captures all answers so far. Next: implement DFPkg + facets per the deployment pattern and details above.