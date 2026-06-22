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
5. **A research spike is the first deliverable, before implementation.** It must resolve, at minimum: (a) Aave V3.6 `Pool` and Aave V4 `Spoke`/`Hub` interfaces and Base addresses (or whether V3.6/V4 are fork-only); (b) the token → `Pool`/`Spoke` source-lookup used by `deployVault` validation; (c) the concrete set of Aave view calls that make `preview == execution` deterministic. It should also pin down the net-carry formula and common-unit aggregation (see Open Questions), which are load-bearing for gating.
6. **Deposit previews simulate the full combined flow.** `previewExchangeIn` must simulate reinvest-of-existing-positions **and** the recursive deposit loop end-to-end — including how each supply/borrow leg changes Aave rates and HF — and match execution exactly. Because truth is read live from Aave (decision 2), the preview must simulate against the same view calls execution uses, not replay cached numbers.

### Key Goals
- Positive net carry via cross-version loops with dynamic direction selection (configurable pairs).
- Permissionless `rebalance()` with strict on-chain gates (rate spreads from Vault Fee Oracle + direct HF/rates).
- Full recursive looping on deposit until target LTV (per version/leg, within threshold from oracle).
- Accurate accounting: MultiAsset only for raw tokens the vault directly controls. **Aave supply and debt (both versions) are reconciled from live Aave reads on each call (decision 2)** — `LoopPositionRepo` and the registered aToken/supplyShare assets are caches/mirrors for composability, not the trusted source. Net balances for the two base tokens = sum of lending side on both versions minus sum of debt owed on both versions (computed from live aToken/debt balances combined with multi-asset raw state in the loop/exchange logic). Goal: accurately reflect the state after the loop is unwound by repaying the debt. Register aToken/supplyShare contracts as additional assets in the multi-asset repo (vault never holds them directly; Aave holds for vault address; loop logic updates the mirror after each Aave operation, but reads reconcile from live Aave).
- Per-version position tracking + direct integration: V3.6 via direct Pool; V4 via direct Spoke calls (vault as onBehalfOf/user; no PositionManager). Facet may call additional Spoke/Hub for premium/risk premium refresh as part of rebalance.
- Deployment validation: Package ensures both tokens exist, are usable as collateral, and borrowable on **both** Aave versions (reverts otherwise). Looks up pool/spoke from token if possible via Aave.
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
- Initial implementation targets Base (where both Aave versions have relevant liquidity).
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

The DFPkg's vaultDeclaration: lending + multiAsset, with usage fee via marker ID.

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
- Secure/confirm the actual deposit amount first (hold it aside; transfer to confirm).
- Reinvest any accrued interest on existing Aave positions first (using only existing positions, not touching the new deposit; via rebalance-like logic first).
- Then add the new deposit to the loop: take the token, deposit it as collateral on a version.
- Check if safe to borrow on that version of Aave (per-version LTV/HF gate).
- If so, borrow and deposit on the other version.
- Check the other version; if safe, borrow and deposit back on the previous.
- Full recursive loop until reach the target LTV (per protocol version / leg; within a threshold from the Vault Fee Oracle).
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
- Add key events (rebalance action, gate decision, direction flip).
- Add aggregate or per-version target HF, max iterations.

### Withdraw / Exit
- Via IStandardExchangeOut.
- May partially unwind (repay debt, withdraw supply) on versions to free tokens.
- Previews must match (in exchange previews).

### Dynamic Direction + Net Carry
- At every step, evaluate both possible loop directions using live rates + projected net carry + HF impact.
- Net carry = supply yield - borrow cost (per direction/version; from Service lib).
- Choose/act on the best that meets gates.

## 4. LTV, Parameters & Fee Oracle
- **LTV**: Per protocol, per version, per asset being borrowed. Via Vault Fee Oracle:
  - defaultLTV(address source, address asset)
  - defaultLTVOfTypeID(bytes4 vaultTypeID, address source, address asset)
  - defaultLTVofVault(address vault, address source, address asset)
- Source = actual Aave contract address (Pool for v3.6, primary Spoke for v4). Looked up by Package using token -> Aave reserve info (if possible via Aave APIs/contracts).
- Enforcement: Hard per-version LTV check, take min(our cap, Aave native). No cross-protocol aggregate LTV (decision 1).
- Oracle provides targetLTV + allowed deviation/threshold per source/asset.
- For recursion stop on deposit: stop when projected LTV after leg would exceed target - threshold (e.g. target - 1%). Check projected before each atomic leg.
- LTV gating per version independent (per leg).
- Effective LTV per version (no cross-protocol aggregate for gating). Use aToken equiv balances, priced via Aave oracles per side, aggregate in common unit.
- **Other (minimal + additions)**: Only LTV caps + min net carry / spread thresholds primarily. Add aggregate or per-version target HF, max iterations, key events. `forceRepay` is permissionless under low HF (decision 3): if any version's HF < safety threshold from the Fee Oracle (decision 4), anyone can repay that version's at-risk leg. No owner-only path.
- Thresholds/gates from Fee Oracle. Direct rates/HF for comparisons.
- No per-vault mutable rate thresholds beyond oracle.

## 5. Interfaces
- `IStandardVaultPkg` (via DFPkg) with lending + multiAsset, usage fee via marker ID.
- `IStandardExchangeIn` / `IStandardExchangeOut` (zaps + integrated looping/previews; full previews in previewExchangeIn/Out).
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
- Add events for decisions/actions. ForceRepay for emergencies.
- Use AwareRepos/Services for clean version abstraction. Package looks up sources.

## 7. Testing Requirements
- Full preview must match execution on all paths (deposit with full recursive loop, rebalance decisions/actions, partial/full repay, withdraw). Implemented in exchange previews.
- Fork tests on Base with **real Aave V3.6 + real Aave V4** (use Crane harnesses/Spokes).
- Rate manipulation, fork blocks, gating boundaries, direction flips, recursive deposit to stop condition.
- Multiple pairs; HF edges, caps, liquidity limits, interest accrual on supplies during loop.
- Deployment validation (Package reverts on bad pairs; source lookup).
- End-to-end unwind accounting accuracy. Events. ForceRepay.
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

**Sequencing (decision 5): a research spike is the first deliverable, before any implementation.** The spike must close the items marked _[SPIKE]_ below; the remaining items may be resolved during implementation or as follow-on.

- _[SPIKE]_ Aave V3.6 `Pool` and Aave V4 `Spoke`/`Hub` interfaces and Base addresses (or confirmation they are fork-only).
- _[SPIKE]_ Exact source lookup implementation in Package if Aave lookup not direct (token -> Pool/Spoke).
- _[SPIKE]_ The concrete set of Aave view calls that make `preview == execution` deterministic (decisions 2 and 6).
- _[SPIKE]_ Precise "net carry" formula and rate getters in Services (supplyAPY - borrowAPY per direction/version).
- _[SPIKE]_ How "common unit" aggregation works if oracles differ (e.g. exact USD conversion).
- V4 premium/risk premium refresh details in rebalance (which exact additional calls).
- Max practical iterations/gas for recursive deposit (rely on gas or hard limit?).
- Any V4 dynamic config / risk premium impact on accounting beyond premiums.
- Events granularity for "gate triggered with reason".
- Integration depth with V4 Hub features.
- Fee/performance share on positive carry (beyond usage fee via marker).
- Can a proxy be re-paired after full unwind (or always new deploy)?
- Exact test matrix for preview match + rate edge cases.

This PRD captures all answers so far. Next: implement DFPkg + facets per the deployment pattern and details above.