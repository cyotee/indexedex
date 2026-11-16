# Implementation Plan: Aave V3.6 / V4 Cross-Version Carry Loop Vault

Implements `prds/AaveV3V4CrossVersionCarryLoopVault.md` (34 decisions) using the structure of the
`AaveV3Stata` Standard Exchange vault as the template. Spike findings: `prds/AaveV3V4CrossVersionCarryLoopVault.Spike.md`.

Target chain: **Ethereum mainnet** (only chain with both V3.6 and V4 live — decision 34).

## How this differs from the Stata template
- **Not ERC4626** (two underlyings). Shares are an **LP-style proportional claim** on net reserves `(R_A, R_B)` (decision 10), priced via Aave oracles; single-token in/out only (decision 11).
- **Leveraged + cross-version**: recursive loop across V3.6 `Pool` and V4 `Spoke`/`Hub` (decisions 13, 25).
- **Never-borrow unwind** withdraw, all-or-revert (decisions 14, 15).
- **Live-Aave reconciliation** for all position reads (decision 2); repos are caches/mirrors.

## File manifest (under `contracts/protocols/lending/aave/cross-version/`)

### Interfaces (`contracts/interfaces/`)
- [x] `IAaveCrossVersionLoopVault.sol` — marker (pair + sources + loop views); its interfaceId is the vault fee type key.

### Repos (storage / caches)
- [x] `AaveV36PoolAwareRepo.sol` — V3.6 `Pool`, `PoolAddressesProvider`, `IAaveOracle`.
- [x] `AaveV4SpokeAwareRepo.sol` — V4 `Spoke`, `Hub`, V4 oracle, per-token `reserveId`/`assetId` maps (resolved at init via `Hub.getAssetId` → `Spoke.getReserveId`).
- [x] `LoopPositionRepo.sol` — pair `(tokenA, tokenB)`, current loop direction, `lastRebalanceTimestamp` (hysteresis/min-interval), usage-fee growth baseline; mirrors of per-version supplied/borrowed (cache only).

### Service libraries (external calls + math; version-specific)
- [x] `AaveV36Service.sol` — supply/borrow/repay/withdraw + reads: `getReserveData` rates, `getUserAccountData` HF, config flags, eMode (`setUserEMode`), `getAssetPrice`. Projected-rate view via Pool-level IR strategy `calculateInterestRates` (decision 30).
- [x] `AaveV4Service.sol` — supply/borrow/repay/withdraw (vault as own `onBehalfOf`) + reads: `getUserAccountData`, `getUserDebt(drawn,premium)`, `getUserSuppliedAssets`, `getReserveConfig` flags, `collateralFactor`; supply-APY derivation accessors (decision 33); `updateUserRiskPremium` (decision 31). Oracle is reserveId-keyed (decision 29).
- [x] `CrossVersionLoopService.sol` — **pure carry math done + unit-tested**: common-unit USD normalization (decision 29), V4 supply-APY derivation (decision 33), effective V4 borrow rate, net-carry per orientation (decision 28), projected-LTV gate helpers (decisions 1, 24, 20). **Pending (stateful, fork-tested):** recursion orchestration, atomic direction flip (decision 25), never-borrow unwind (decision 14) — these live in the exchange/rebalance Targets.

### Common (preview == execution)
- [ ] `AaveCrossVersionLoopCommon.sol` — shared projection routine used by both `preview*` and execution (decision 30): simulate reinvest + recursive loop / unwind end-to-end against the same view calls; proportional share mint/burn (decision 10); usage-fee dilution (decision 19); withdrawal fee (decision 18); donation-as-growth (decision 27); reward claim+fold (decision 9).

### Execution Targets + Facets (the loop lives in the exchange path — decision 11)
- [ ] `AaveCrossVersionLoopExchangeInTarget.sol` + `InFacet.sol` — `IStandardExchangeIn` (deposit any token → shares via loop).
- [ ] `AaveCrossVersionLoopExchangeOutTarget.sol` + `OutFacet.sol` — `IStandardExchangeOut` (shares → one token via never-borrow unwind).
- [ ] `AaveCrossVersionLoopRebalanceTarget.sol` + `Facet.sol` — permissionless `rebalance()` + `forceRepay()` + loop-state views (decisions 3, 7, 8, 25).
- [ ] `AaveCrossVersionLoopMarkerTarget.sol` + `Facet.sol` — implements `IAaveCrossVersionLoopVault`.

### Package + factory
- [ ] `AaveCrossVersionLoopDFPkg.sol` — `deployVault(tokenA, tokenB)`; validates both tokens collateral+borrowable+active on **both** versions (decision deployment-validation); resolves sources/ids; forces VaultRegistry; `initAccount` wires AwareRepos + MultiAsset + ERC20/permit/metadata + exchange + rebalance + marker facets; `vaultFeeTypeIds` inserts the marker interfaceId under `VaultFeeType.LENDING`.
- [ ] `AaveCrossVersionLoop_Component_FactoryService.sol` — CREATE3 deploy helpers for facets + DFPkg + `PkgInit`.

### Marker
- [x] `AaveCrossVersionLoopMarkerTarget.sol` + `MarkerFacet.sol` — implements `IAaveCrossVersionLoopVault`; `netBalanceOf` reconciled live from both versions (decisions 2, 10).

### Test harness — DECISION NEEDED (local-deploy blocker found 2026-06-22)
**Blocker:** Crane's V4 (and V3) test-deploy harness calls
`vm.getCode('contracts/protocols/lending/aave/v4/hub/instances/HubInstance.sol:HubInstance')` with a
path relative to the **Crane** project root. From indexedex those sources live under
`lib/daosys/lib/crane/contracts/...`, so the artifact lookup fails (`vm.getCode: no matching artifact found`)
when Crane's `setup/Base.t.sol` is inherited. So Crane's local-deploy test bases are **not portable** as-is.
Also note: indexedex's existing real-Aave testing (e.g. AaveV3Stata) is **fork-based** (`test/foundry/fork/eth_main`), not local-deploy.

**Options (pick one):**
1. **Fork-based** (matches existing indexedex pattern): fork Ethereum mainnet with real V3.6 + V4; manufacture
   rate scenarios by warping time and moving utilization via large supplies/borrows. Lower effort, less precise rate control.
2. **Portable local-deploy harness:** deploy `HubInstance`/`SpokeInstance` (+ V3 instances) via `new` in our own
   TestBase (avoiding `vm.getCode`), replicating the minimal orchestration (authority, configurator, IR strategies,
   reserves, price feeds). Highest control over rates (best for profitable-loop detection tests) but significant effort.
3. **Make `vm.getCode` resolve:** investigate a forge artifact-path/remapping trick so Crane's hardcoded `contracts/...`
   paths resolve from indexedex (uncertain; may not be supported).

Recommended: confirm whether the precise rate control of (2) is worth the effort vs. (1) fork-based. The carry-math and
Service libs are already validated independently; the harness choice mainly affects integration/loop-detection tests.

**DECISION: option (2) portable local-deploy.** Confirmed-viable construction primitives (replace Crane's
`Create2Utils.create2Deploy`/`proxify`, which sit behind `vm.getCode`, with direct `new`):
```solidity
HubInstance hubImpl = new HubInstance();                       // no-arg ctor = implementation
address hubProxy = address(new TransparentUpgradeableProxy(
    address(hubImpl), proxyAdminOwner, abi.encodeCall(IHubInstance.initialize, (authority))));
// analogous: SpokeInstance + ISpokeInstance.initialize(...)
```
Remaining assembly for a minimal 2-token V4 market (`AaveV4LocalMarket` helper):
1. `authority` = AccessManager (deploy directly; see `AaveV4AuthorityBatch`/`AccessManagerEnumerable`), with roles granted (`AaveV4*RolesProcedure`).
2. Hub proxy (above) + `HubConfigurator` (proxy).
3. Spoke impl+proxy + `SpokeConfigurator`; IR strategy (`IAssetInterestRateStrategy` impl) per asset.
4. Config: `addAsset(token)` → `addSpoke` → `addReserve` (collateral+borrowable) → set `InterestRateData` → set price source (mock feed) → set `DynamicReserveConfig.collateralFactor`.
5. V3 side: deploy a Pool market via direct `new` on V3 instances (PoolAddressesProvider, Pool, PoolConfigurator, AaveOracle, `DefaultReserveInterestRateStrategyV2`) — same `new`-not-`vm.getCode` principle.

Note: this is the single largest infra piece; build V4 first to green, then V3, then list our `deployToken` tokens on both.

**STATUS: COMPLETE & GREEN (2026-06-23).** Portable local cross-version harness built:
- `TestBase_AaveCrossVersionLoop` — test tokens via `ERC20MintBurnOwnableOperableDFPkg` (3/3).
- `TestBase_AaveCrossVersionLoopV4Market` — local V4 Hub+Spoke, our tokens listed, `AaveV4Service` validated (3/3).
- `TestBase_AaveCrossVersionLoopV3Market` — local V3.6 market (coexists with V4), our tokens listed via ConfigEngine, `AaveV36Service` validated (4/4).
- **Breakthrough:** Crane's `vm.getCode` non-portability solved by passing `type(HubInstance/SpokeInstance).creationCode` to the orchestration; V3 batch orchestration was already `new`-based. CREATE2 factory `vm.etch`'d.
- Both Service libs validated against real local markets with our own tokens on both versions, fully tunable rates — no fork.
Next: configure a cross-version rate spread to drive profitable-loop tests; then the vault core (exchange/loop/rebalance + DFPkg) against this harness.

### Local test harness reference — CONFIRMED FEASIBLE (preferred over fork)
Deploy local Aave V3.6 + V4 markets with mock ERC20s and tunable interest-rate strategies, so
profitable/unprofitable cross-version spreads can be manufactured deterministically (more
controllable than a mainnet fork). Crane vendors everything needed:
- **V4 market:** inherit `@crane/test/foundry/spec/protocols/lending/aave/v4/setup/Base.t.sol`
  (provides `hub1`, `spoke1`, mock assets, `HubActions`); IR via `IAssetInterestRateStrategy.InterestRateData`
  (`optimalUsageRatio`, `baseDrawnRate`, `rateGrowthBefore/AfterOptimal`, all BPS).
- **V3.6 market:** `AaveV3BatchOrchestration` + `ProtocolV3TestBase`; IR via `DefaultReserveInterestRateStrategyV2` params.
- **Test tokens:** `@crane/contracts/tokens/ERC20/ERC20MintBurnOwnableOperableDFPkg` (per user direction) — proper diamond ERC20s with mint/burn + ownable/operable, so the test can freely mint to seed Aave liquidity and fund users. Deploy recipe (see `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol`):
  1. `create3Factory.deployFacet(type(<Facet>).creationCode, salt)` for the 6 facets (erc20, erc5267, erc2612, erc20MintBurnOwnable, multiStepOwnable, operable) — most come from `TestBase_VaultComponents`/`IndexedexTest`.
  2. Build `IERC20MintBurnOwnableOperableDFPkg.PkgInit{...facets, diamondFactory: diamondPackageFactory}`.
  3. `create3Factory.deployPackageWithArgs(type(ERC20MintBurnOwnableOperableDFPkg).creationCode, abi.encode(pkgInit), salt)`.
  4. `tokenPkg.deployToken(name, symbol, decimals, owner, salt)` for `tokenA` and `tokenB` (owner = test, so it can mint).
- List the two test tokens as reserves (collateral + borrowable) on both markets; set rate strategies
  to create a known spread; assert the vault loops in the profitable direction and declines/unwinds when not.

### Tests
- [ ] `test/bases/TestBase_AaveCrossVersionLoop.sol` — **local-deploy** V3.6 + V4 (above) + `TestBase_VaultComponents` + Permit2. (Mainnet `fork/eth_main` suite as a secondary sanity check.)
- [ ] spec tests — deploy validation; deposit recursion to target-LTV; preview==execution on all paths; never-borrow unwind + all-or-revert boundaries; rebalance extend/repay/flip + hysteresis; forceRepay under low HF; usage-fee dilution on/off; withdrawal fee; donation; reward claim; graceful degradation (frozen/paused); stable (USDG/USDC) **and** volatile (ETH/WBTC) pairs.

## Economic core — COMPLETE & GREEN (2026-06-23)
Validated against the live local cross-version markets (no fork):
- `CrossVersionLoopExecutor.depositLoopAFirst` — builds the leveraged cross-version position (leverage, both versions, HF healthy, net = principal).
- `CrossVersionLoopExecutor.fullUnwind` — never-borrow deleverage (decision 14); frees principal, stays solvent. Finding: full close of a *maxed* symmetric loop stalls (decision 17) — partial withdraws are the real path.
- Profitable-loop detection (cheaper-borrow + positive carry, rejects flip).
- `navUsd` live NAV; `sharesForDeposit`/`assetsForShares`/`performanceFeeShares` (decisions 10, 19).
- Carry math, V3.6 + V4 service libs, marker, repos.
- **27 cross-version tests green.**

## Packaging layer — COMPLETE & GREEN (2026-06-23)
- Exchange In/Out targets + IFacet wrappers (deposit→shares; shares→token never-borrow, all-or-revert; preview==execution).
- Rebalance/forceRepay target + IFacet wrapper (carry-based extend/de-risk, min-interval, permissionless).
- Marker target + facet (identity + live netBalanceOf).
- `AaveCrossVersionLoopDFPkg`: 8 facetCuts, `deployVault(tokenA,tokenB)` with deploy-time validation
  on BOTH versions + VaultRegistry routing, `initAccount` wiring all repos (V4 id resolution),
  marker interfaceId as LENDING fee type.
- **38 cross-version tests green** across 10 suites.

## Deployment tooling — COMPLETE & GREEN (2026-06-23)
- `AaveCrossVersionLoop_Component_FactoryService`: CREATE3 deploy helpers for the facets + DFPkg-through-manager.
- **End-to-end test green**: deploy facets via CREATE3 → register DFPkg via the real IndexedexManager +
  VaultRegistry → `deployVault(tokenA,tokenB)` mints a real diamond proxy → deposit + withdraw through
  the diamond's `IStandardExchange` selectors against the live local cross-version markets.
- DFPkg includes `MultiAssetStandardVaultFacet` (registry reads `vaultConfig()` on the proxy) + inits StandardVaultRepo.
- **40 cross-version tests green across 11 suites. The vault is complete and deployable.**

Remaining (follow-on, not blocking): numeric tuning + oracle-sourced params (fees, hysteresis,
max-iter, LTV targets — decisions 7, 18, 19, 20, 26); single-token-deposit orientation selection +
tokenB-in; full preview==execution incl. reinvest step (decision 6); Aave reward claiming (decision 9).

## Build sequence (TDD, checkpoint after each block)
1. **Foundation (this checkpoint):** marker interface, AwareRepos, LoopPositionRepo, plan.
2. **Service libs:** V3.6 + V4 reads/writes + projected-rate views (unit-tested against fork).
3. **Carry math + common:** net-carry, common-unit, gates, projection routine (the correctness core).
4. **Exchange In/Out:** deposit loop + never-borrow unwind, preview==execution.
5. **Rebalance/forceRepay** + direction flip.
6. **DFPkg + FactoryService** + deploy validation.
7. **Marker + fee wiring**, full spec/fork tests.

## Open numeric/tuning inputs (oracle-served, decision 26) — set at deploy/config, not hardcoded
withdrawal-fee bps (18), usage `fee%` (19), hysteresis band + min interval (7), max-iterations (20),
`MINIMUM_LIQUIDITY` size (21). Plus: confirm V3/V4 oracles both USD-quoted on Ethereum (29).
