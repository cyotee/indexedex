# PRD: Remove invalid SingleVaultDetf (`detf/composed/single`)

| Field | Value |
|-------|--------|
| **Status** | READY FOR IMPLEMENT — research complete; open requirements **locked 2026-07-29** (see §0) |
| **Date** | 2026-07-29 |
| **Target** | Carve out and **delete** `contracts/vaults/detf/composed/single/` (SingleVaultDetf) and all exclusive dependents |
| **Superseded by** | `contracts/vaults/detf/standardExchange/single/` — **SingleStandardExchangeDETF** (any SE-compatible vault injected at instance deploy) |
| **Archive** | **Not required.** Do not copy to an archive tree; remove from the repo. Delete obsolete archive scripts that import this family. |
| **Risk posture** | High confidence of isolation for **production DETF families**; Scenario 3 retarget is the main non-delete workstream |

---

## 0. Locked product decisions (clarification 2026-07-29)

| Topic | Decision |
|-------|----------|
| **Scenario 3** (`Script_12_DeployScenario3Overlay.s.sol`) | **Retarget** to **SingleStandardExchangeDETF** (not delete Scenario 3; not leave broken). |
| **PR scope (non-code)** | **Contracts + tests + live scripts + AGENTS family table.** Full launch-plan / inventory doc retarget is **out of this PR** (may leave stale historical notes under `docs/` until a follow-up). |
| **`scripts/archive/foundry/protocol-detf/**`** | **Delete** archive scripts that depend on SingleVaultDetf (Script_16, SingleVault bridge configure/validate, etc.). No frozen non-compiling archive for this product. |

### Scenario 3 retarget — implementation defaults (unless later overridden)

Intent of Scenario 3 today: local inventory DETF + outer Balancer WETH/DETF pool for UI/dev. After removal:

1. **DETF package:** deploy facets/DFPkg for **SingleStandardExchangeDETF** via its `*_FactoryService` + manager registry path (same production pattern as gold TestBase).
2. **External SE leg:** keep a **Uniswap V4 Standard Exchange** vault as the attached `standardExchangeVault` (deploy Uni V4 SE separately, then inject address into Single SE DETF `PkgArgs`). Do **not** hardcode Uni V4 inside the DETF package.
3. **Liquidity seeder:** keep a seeder **only if** still needed for the Uni V4 SE leg; rename off `SingleVaultDetf*` (e.g. generic Uni V4 seeder under local_testing shared). Delete if unused after retarget.
4. **Superchain / bridge wiring** in Scenario 3 and SingleVault-only bridge scripts: **drop** (bridge was exclusive to SingleVaultDetf; SingleStandardExchangeDETF has no DetfSuperchainBridgeRepo). Scenario 3 becomes hermetic single-chain local overlay.
5. **Artifacts:** keep Scenario 3 stage number / `12_scenario_3.json` where practical; rename manifest keys from `inventoryDetf` / SingleVault naming only if local tooling requires — prefer stable keys with updated addresses if wrappers already read them.
6. **WeightedPool8020:** Single SE DETF uses general **WeightedPoolFactory** + configurable weights (defaults 80/20), not Crane 8020 factory. Drop Scenario 3’s exclusive 8020 factory deploy if it exists only for SingleVaultDetf.
7. **Docs for Scenario 3:** minimal edits in `scripts/foundry/local_testing/README.md` so the overlay description matches Single SE DETF. Full `docs/ANVIL_LOCAL_TESTING_SCENARIOS_PRD.md` rewrite is optional follow-up (out of “AGENTS-only” doc scope unless needed for the script to be usable).

---

## 1. Problem statement

`SingleVaultDetf` under `contracts/vaults/detf/composed/single/` was treated as a “composed single-vault DETF,” but it is **not** a generic single-SE DETF:

1. **Hardcoded SE package type.** `ISingleVaultDetfDFPkg.PkgInit` stores an immutable  
   `IUniswapV4StandardExchangeDFPkg underlyingVaultPkg` and post-deploy deploys that package via  
   `UNDERLYING_VAULT_PKG.deployVault(poolKey, widthMultiplier)`.  
   Instance args are Uni V4–shaped (`PoolKey`, `underlyingWidthMultiplier`), not an arbitrary `IStandardExchange` address.

2. **Violates DETF opacity / family rules.** AGENTS.md requires production DETFs to talk only to `IStandardExchange*` / share ERC-20 / Balancer and to accept **any** SE-compatible vault as a leg. This package imports and bakes **Uniswap V4 Standard Exchange DFPkg** into package init.

3. **Already product-deprecated.** Frontend research copy (`frontend/app/content/research/articles/detf-types.ts`) marks `composed/single` as **deprecated / out of product map**. The correct single-leg product is **Single Standard Exchange DETF**.

4. **Duplicate product surface.** Correct single-leg design is implemented and PRD’d as:

   | Correct family | Path | SE attachment |
   |----------------|------|---------------|
   | **SingleStandardExchangeDETF** | `detf/standardExchange/single/` | `PkgArgs.standardExchangeVault` (`IStandardExchangeProxy`) injected per instance; underlyings opaque |

---

## 2. Goals / non-goals

### Goals

- **Delete** the entire `SingleVaultDetf` production package and its exclusive interface, tests, and active deploy helpers that only exist for this family.
- **Prove non-breakage** of other DETF families (multi-vault weighted, composed stable, mixed-buffer, SingleStandardExchangeDETF) and shared `detf/core/*` / `detf/reusable/*` / claim / bond NFT packages.
- Leave a durable record (this PRD) of what was exclusive vs shared so implementers do not “save” dead family code or delete shared libs by mistake.
- Update product/agent maps so agents stop treating `composed/single` as a live family.

### Non-goals

- Rewriting SingleVaultDetf to accept arbitrary SE vaults (superseded; do not fix in place).
- Archiving the implementation under `scripts/archive` or a `_deprecated` path.
- Migrating live mainnet deployments of CHIR / Protocol DETF branding (if any historical deploys exist, they are out of this code-removal scope).
- Redesigning Superchain bridge for other DETFs (bridge was only wired into this family).
- Changing SingleStandardExchangeDETF product law except where docs wrongly point at SingleVaultDetf as the launch fee sink.

---

## 3. Root-cause evidence (hardcoding)

### 3.1 Package init locks Uni V4 SE DFPkg

`SingleVaultDetfDFPkg.sol` / `ISingleVaultDetfDFPkg.PkgInit`:

```solidity
IUniswapV4StandardExchangeDFPkg underlyingVaultPkg;
// ...
IUniswapV4StandardExchangeDFPkg immutable UNDERLYING_VAULT_PKG;
```

`_deployOwnedComposition` always:

```solidity
deployment_.underlyingVault = IStandardExchange(
    UNDERLYING_VAULT_PKG.deployVault(args.underlyingPoolKey, args.underlyingWidthMultiplier)
);
```

### 3.2 Instance args are pool geometry, not vault address

```solidity
struct PkgArgs {
    // ...
    PoolKey underlyingPoolKey;
    uint24 underlyingWidthMultiplier;
    // ...
}
```

Contrast **SingleStandardExchangeDETDFPkg**:

```solidity
struct PkgArgs {
    // ...
    IStandardExchangeProxy standardExchangeVault;
    IERC20 standardExchangeVaultShare; // optional; 0 → vault is share
    IERC20 rateTarget;
    // weights + thresholds + mode
}
```

### 3.3 Superchain bridge is family-private

`DetfSuperchainBridgeRepo` is initialized only from `SingleVaultDetfDFPkg.initAccount` and consumed only by:

- `SingleVaultDetfBondingTarget`
- `SingleVaultDetfExchangeInQueryTarget`

No other DETF production package imports it.

---

## 4. Dependency research summary

### 4.1 Method

- Enumerated all `*.sol` under `contracts/vaults/detf/composed/single/`.
- Grepped for `composed/single`, `SingleVaultDetf`, `ISingleVaultDetf`, `deploySingleVaultDetf`, `DetfSuperchainBridgeRepo` across `contracts/`, `test/`, `scripts/`, `frontend/`, `docs/`.
- Confirmed other families’ DFPkgs do **not** import `composed/single`.
- Confirmed registry/manager Solidity trees have **no** dedicated SingleVaultDetf types (deploy is via library extension `using SingleVaultDetf_Pkg_FactoryService for IVaultRegistryDeployment` at call sites only).

### 4.2 Critical isolation result

| Question | Answer |
|----------|--------|
| Does MultiVaultWeightedDetf import SingleVaultDetf? | **No** |
| Does ComposedStableCommonDetf import SingleVaultDetf? | **No** |
| Does MixedBufferMultiVaultStableDetf import SingleVaultDetf? | **No** |
| Does SingleStandardExchangeDETF import SingleVaultDetf? | **No** |
| Do Dual / Seigniorage packages import SingleVaultDetf? | **No** |
| Is `ISingleVaultDetf` implemented or registered outside this package? | **No** (only package facets + package tests/scripts) |
| Does vault registry hardcode SingleVault deploy methods in contracts? | **No** (CREATE3 + `deployPkg` via Pkg FactoryService) |

**Conclusion:** Removing this family is a **carve-out**, not a shared-lib refactor. Shared libs are **consumers of imports from SingleVaultDetf → shared**, never the reverse dependency of “shared code lives only for SingleVaultDetf” except `DetfSuperchainBridgeRepo` and `ISingleVaultDetf`.

---

## 5. KEEP — code reused by other DETFs (do **not** delete)

SingleVaultDetf **uses** these; they are **not owned** by the family. Other packages still require them.

### 5.1 DETF shared core (`contracts/vaults/detf/core/**`)

| Asset | Why keep |
|-------|----------|
| `DETFThresholdPolicy.sol` | Policy/Open + resolve/validate; all threshold-mode families |
| `DETFUsageFeeLib.sol` | Mint fee / seigniorage split helpers |
| `DETFBondLifecycleLib.sol` | Bond NFT lifecycle (other DETFs) |
| `DETFBondNFTMathLib.sol`, `DETFMintSplitLib.sol`, `DETFPreviewLib.sol`, `DETFSafeTransferLib.sol`, `DETFBalancerScaleLib.sol` | Shared math / transfers |
| Core threshold-mode plan docs under `core/` | Still apply to remaining families |

### 5.2 DETF reusable factories / NFT surface

| Asset | Why keep |
|-------|----------|
| `contracts/vaults/detf/reusable/**` | `Detf*FactoryService`, `IDetfSelfNftInventoryDFPkg` used by Single SE, MultiVaultWeighted, MixedBuffer, etc. |
| `contracts/vaults/detf/bondNft/**` | Shared DETF bond NFT package |
| `contracts/vaults/detf/claimToken/**` | Rebasing claim token package |
| `contracts/vaults/detf/inventory/**` | Bond / fee / self-NFT inventory policies |

### 5.3 DETF common base (other families)

| Asset | Why keep |
|-------|----------|
| `contracts/vaults/detf/DETFCommon.sol` | Imported by **ComposedStableCommonDetfCommon**, **DualDETFCommon** (and protocol dual embedded paths) |

### 5.4 Shared interfaces / vault stack

| Asset | Why keep |
|-------|----------|
| `contracts/interfaces/detf/IDetf.sol` (+ errors/proxy as applicable) | Universal DETF surface (F6 threshold-mode NatSpec lives here) |
| `IStandardExchange*`, `IStandardVault*`, vault component facets/repos | All vault/DETF packages |
| `StandardExchangeRateProviderDFPkg` | Single SE + multi-vault families |
| `IBalancerV3StandardExchangeRouter*` / prepay | Multiple DETFs |
| `VaultTypeUtils`, fee oracle interfaces | Registry + fee wiring |

### 5.5 Balancer 80/20 math (not exclusive)

| Asset | Why keep |
|-------|----------|
| `contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol` | **Also used by** `SeigniorageDETF*`, balancer seigniorage vaults, Crane tests |
| Crane `WeightedPool8020Factory` / related | Seigniorage and other 8020 products |

### 5.6 Superseding product (must remain)

| Asset | Why keep |
|-------|----------|
| Entire `contracts/vaults/detf/standardExchange/single/**` | Correct single-SE DETF |
| Its tests under `test/foundry/spec/vaults/detf/standardExchange/single/**` (and TestBase) | Gold matrix |
| Multi-vault / stable / mixed-buffer families | Unrelated product surface |

### 5.7 Do **not** delete because of name similarity

| Similar name | Not the same package |
|--------------|----------------------|
| `StandardExchangeSingleVaultSeigniorageDETF*` under `contracts/protocols/dexes/balancer/v3/vaults/` | Seigniorage / balancer protocol path — **out of this carve-out** |
| `SeigniorageDETF*` under `contracts/vaults/seigniorage/` | Separate product; F7 out of threshold-mode program |
| Dual-liquidity DETF-like vaults | Protocol-specific; not `composed/single` |

---

## 6. REMOVE — code exclusive to SingleVaultDetf

### 6.1 Production package (entire directory)

Delete **all** of:

```text
contracts/vaults/detf/composed/single/
```

Including (complete inventory as of 2026-07-29):

| File | Role |
|------|------|
| `SingleVaultDetfDFPkg.sol` | DFPkg + `ISingleVaultDetfDFPkg` |
| `SingleVaultDetfRepo.sol` | Family storage (`indexedex.vaults.detf.composed.single`) |
| `SingleVaultDetfCommon.sol` | Family math / gates |
| `SingleVaultDetfBondingTarget.sol` / `SingleVaultDetfBondingFacet.sol` | Bonding (+ `ISingleVaultDetfBonding`) |
| `SingleVaultDetfExchangeInTarget.sol` / `SingleVaultDetfExchangeInFacet.sol` | Mint paths |
| `SingleVaultDetfExchangeInQueryTarget.sol` / `SingleVaultDetfExchangeInQueryFacet.sol` | Previews / bridge query |
| `SingleVaultDetfExchangeOutTarget.sol` / `SingleVaultDetfExchangeOutFacet.sol` | Burn paths |
| `SingleVaultDetfInfoTarget.sol` / `SingleVaultDetfInfoFacet.sol` | Info (+ `ISingleVaultDetfInfo`) |
| `SingleVaultDetf_Component_FactoryService.sol` | PkgInit/PkgArgs builders |
| `SingleVaultDetf_Facet_FactoryService.sol` | CREATE3 facet deploy helpers |
| `SingleVaultDetf_Pkg_FactoryService.sol` | `deploySingleVaultDetfDFPkg` |
| `SingleVaultDetf_ADVERSARIAL_TEST_PLAN.md` | Family-only plan |
| `SingleVaultDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md` | Family-only plan (F5 historical) |
| `UNISWAP_V4_SINGLE_DETF_IMPLEMENTATION_PLAN.md` | Family-only plan |

**After removal:** `contracts/vaults/detf/composed/` should only contain `multi-vault-weighted/`, `stable/`, and this **removal PRD** (or the PRD may move under `docs/` if preferred).

### 6.2 Family-only top-level DETF asset

| File | Decision |
|------|----------|
| `contracts/interfaces/ISingleVaultDetf.sol` | **DELETE** — only consumers are SingleVaultDetf + its tests/scripts |
| `contracts/vaults/detf/DetfSuperchainBridgeRepo.sol` | **DELETE** — only production consumers are SingleVaultDetf targets/DFPkg |

### 6.3 Active scripts / helpers exclusive to this family

| Path | Decision | Notes |
|------|----------|-------|
| `scripts/foundry/local_testing/anvil_single/Script_12_DeployScenario3Overlay.s.sol` | **RETARGET** | Rewrite to deploy **SingleStandardExchangeDETF** + injected Uni V4 SE vault + outer WETH/DETF pool. Drop Superchain bridge init. See §0 defaults. |
| `scripts/foundry/shared/SingleVaultDetfUniswapV4LiquiditySeeder.sol` | **RENAME or DELETE** | Keep only if Scenario 3 still seeds Uni V4 liquidity; rename off `SingleVaultDetf*`. Delete if seeder inlined or unused. |
| `scripts/foundry/local_testing/README.md` | **EDIT** | Describe Scenario 3 as SingleStandardExchangeDETF, not composed/single |

### 6.4 Archive scripts (already non-pipeline)

These already live under `scripts/archive/` and **will not compile** once the package is deleted. Either:

- **Delete** them in the same PR (preferred; user asked for full removal, no archive of this DETF), or  
- Leave broken archive references **only if** archive policy is “freeze as historical text” — **not recommended** for compileable `.sol`.

Inventory:

```text
scripts/archive/foundry/protocol-detf/anvil_sepolia/Script_16_DeployProtocolDETF.s.sol
scripts/archive/foundry/protocol-detf/anvil_base_main/Script_16_DeployProtocolDETF.s.sol
scripts/archive/foundry/protocol-detf/public_sepolia/ethereum/Script_16_DeployProtocolDETF.s.sol
scripts/archive/foundry/protocol-detf/public_sepolia/base/Script_16_DeployProtocolDETF.s.sol
scripts/archive/foundry/protocol-detf/local_testing/supersim/Script_22_ConfigureSingleVaultDetfBridge.s.sol
scripts/archive/foundry/protocol-detf/local_testing/supersim/Script_23_ValidateSingleVaultDetfBridge.s.sol
```

(Confirm supersim Script_22/23 paths with `rg` at implement time; inventory also appears in `docs/ANVIL_LOCAL_TESTING_SCENARIOS_PRD.md`.)

### 6.5 Explicitly **not** in remove list

- Manager / vault registry contracts (no typed SingleVault methods found).
- Uni V4 Standard Exchange package itself (still a valid SE vault for **other** DETFs to attach).
- WeightedPool8020Factory (still used elsewhere).

---

## 7. Tests — full inventory and deletion list

### 7.1 Isolation

All Foundry specs for this family live under one tree. **No other test tree imports** `contracts/vaults/detf/composed/single/*`.

### 7.2 DELETE entire tree

```text
test/foundry/spec/vaults/detf/composed/single/
```

#### Production / lifecycle / bridge

| File | Purpose (for audit) |
|------|---------------------|
| `SingleVaultDetf_ProductionBase.t.sol` | Shared deploy base for family tests |
| `SingleVaultDetfDFPkg_Deploy.t.sol` | Package deploy / registry guard |
| `SingleVaultDetfExchangeIn_MintWithWeth.t.sol` | Mint / donate / bond / seigniorage (legacy name) |
| `SingleVaultDetf_MintSellRedeem.t.sol` | Bond → sell NFT → claim redeem |
| `SingleVaultDetf_AuctionBondWithPosition.t.sol` | Auction / bond with position |
| `SingleVaultDetf_BridgeTransport.t.sol` | Superchain bridge transport |
| `SingleVaultDetf_ThresholdMode.t.sol` | Policy/Open T1–T19 map (F5) |

#### IFacet wiring

| File |
|------|
| `SingleVaultDetfBondingFacet_IFacet_Test.t.sol` |
| `SingleVaultDetfExchangeInFacet_IFacet_Test.t.sol` |
| `SingleVaultDetfExchangeInQueryFacet_IFacet_Test.t.sol` |
| `SingleVaultDetfExchangeOutFacet_IFacet_Test.t.sol` |
| `SingleVaultDetfInfoFacet_IFacet_Test.t.sol` |

#### Adversarial / fuzz

| File |
|------|
| `adversarial/Adversarial_SingleVaultDetf_P0.t.sol` |
| `fuzz/SingleVaultDetf_Fuzz.t.sol` |

**Count:** 14 `*.t.sol` files — **all deletable** with the package.

### 7.3 Tests that must **keep** (do not confuse)

| Path | Why keep |
|------|----------|
| `test/foundry/spec/vaults/detf/standardExchange/single/**` | Correct single-SE product |
| `test/foundry/spec/vaults/detf/composed/multi-vault-weighted/**` | Unrelated family |
| `test/foundry/spec/vaults/detf/composed/stable/**` | Unrelated family |
| Seigniorage / DualLiquidity / protocol SE tests | Unrelated products |

### 7.4 Verification commands (post-removal)

```bash
# Must find zero hits (except this PRD / historical docs intentionally left)
rg -n 'SingleVaultDetf|composed/single|ISingleVaultDetf|DetfSuperchainBridgeRepo' contracts test scripts/foundry --glob '!**/archive/**'

# Build
forge build

# Remaining DETF families smoke (adjust paths if needed)
forge test --match-path 'test/foundry/spec/vaults/detf/standardExchange/single/**' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/composed/multi-vault-weighted/**' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/composed/stable/**' -vv
```

Optional: full `forge test` if CI time allows.

---

## 8. Docs / agent maps to update (same PR or follow-up)

These are **not** runtime breakages but will mislead agents if left as live family.

| Document | Action |
|----------|--------|
| `AGENTS.md` / `Agents.md` | **Remove** “Composed single \| `detf/composed/single/`” row from DETF families table; ensure only Single SE + multi-vault families remain. |
| `Claude.md` / `CLAUDE.md` | Only if they restate the family table; follow AGENTS. |
| `frontend/app/content/research/articles/detf-types.ts` | Already marks deprecated; **strip remaining “deprecated path” mentions** once code is gone (optional cleanup). |
| `docs/CODEBASE_MAP.md` | Remove `composed/single/` tree entry. |
| `docs/DETF_POOL_INTEGRATION_INVENTORY.md` | Mark F5 / SingleVault rows **removed** or delete rows. |
| `docs/LAUNCH_PLAN.md`, `docs/ROBINHOOD_LAUNCH_PLAN.md` | **Product decision:** replace “SingleVault DETF for RICH” fee-sink language with **SingleStandardExchangeDETF** (or another approved family). Do not leave launch docs pointing at deleted code. |
| `docs/ANVIL_LOCAL_TESTING_SCENARIOS_PRD.md`, `scripts/foundry/local_testing/README.md` | Remove Scenario3 / SingleVault bridge steps or retarget. |
| `docs/OPTIONAL_RATE_PROVIDERS_*.md`, `docs/DETF_CONSOLIDATION_*.md` | Historical plans — annotate “obsolete / package removed” or ignore; no implement obligation. |
| `contracts/vaults/detf/DETF_Threshold_Modes_*.md` | Historical program docs reference F5 SingleVaultDetf as **shipped** — add a short “F5 package later **removed** (2026-07-29 carve-out); product law still applies to remaining families” note on progress tracker **or** leave as historical (program complete). Do **not** re-open threshold-mode product law. |
| `docs/SCRIPT_REMOVAL_CANDIDATES.md` | Update seeder / Script_16 guidance (seeder becomes removable). |
| `PLAN_fix_dfpkg_and_package_deployment_in_tests.md` | Drop SingleVault test paths if still listed. |

**This PRD file** (`contracts/vaults/detf/composed/SingleVaultDetf_REMOVAL_PRD.md`) **stays** after the package directory is deleted so the carve-out remains documented.

---

## 9. Implementation plan (ordered, minimal risk)

### Phase 0 — Preflight (read-only)

1. Re-run greps from §4.1 on the implement branch tip (no new imports of SingleVaultDetf into other families).
2. Confirm `DetfSuperchainBridgeRepo` still has zero non–SingleVault production consumers.
3. Confirm `SingleVaultDetfUniswapV4LiquiditySeeder` importers.

### Phase 1 — Delete tests first (or with package)

1. Delete `test/foundry/spec/vaults/detf/composed/single/**` entirely.
2. Ensures no dangling test compiles when package vanishes.

### Phase 2 — Delete production exclusives

1. Delete `contracts/vaults/detf/composed/single/**`.
2. Delete `contracts/interfaces/ISingleVaultDetf.sol`.
3. Delete `contracts/vaults/detf/DetfSuperchainBridgeRepo.sol`.

### Phase 3 — Live scripts: retarget Scenario 3 + drop exclusive helpers

1. Rewrite `Script_12_DeployScenario3Overlay.s.sol` per §0 (SingleStandardExchangeDETF + injected Uni V4 SE).
2. Rename/replace or delete `SingleVaultDetfUniswapV4LiquiditySeeder.sol`.
3. Edit `scripts/foundry/local_testing/README.md` Scenario 3 blurb.

### Phase 4 — Delete exclusive archive scripts

1. Delete `scripts/archive/foundry/protocol-detf/**` scripts that import SingleVaultDetf (Script_16, bridge configure/validate, and any only-child dirs left empty).

### Phase 5 — Agent map

1. AGENTS.md / Agents.md: remove “Composed single” family row; point single-leg work only at `standardExchange/single`.

### Phase 6 — Verify

1. `forge build` green.
2. Grep zero hits on exclusive symbols in live trees (`contracts/`, `test/`, `scripts/foundry/` non-archive).
3. Smoke remaining DETF family tests (§7.4).
4. Optional: dry-run Scenario 3 overlay on anvil if local env is up (not required for PR if build + static review of Script_12 is solid).

### Phase 7 — Stop

Do **not** in this PR: optional rate-provider work, DETF consolidation extractions, full `docs/LAUNCH_PLAN` / `ROBINHOOD` rewrite, or full ANVIL scenarios PRD rewrite (unless Script_12 cannot be understood without a one-line README fix).

---

## 10. Risk register

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Hidden import from another DETF | Low (researched 2026-07-29) | Re-grep at implement; `forge build` |
| Deleting shared core by mistake | Medium if agent over-prunes | **Only** §6 paths; never delete `core/`, `reusable/`, `claimToken/`, `bondNft/`, `DETFCommon.sol`, Single SE family |
| Confusing Seigniorage “SingleVault” names | Medium | §5.7 name table |
| Launch docs still prescribe SingleVault fee sink | High (docs currently stale) | Phase 4 doc rewrite to SingleStandardExchangeDETF |
| Local Scenario3 pipeline breaks | High if scripts kept | Delete Scenario3 or retarget to Single SE DETF |
| CI still matches deleted path globs | Low | Fix CI/docs match-path lists |
| Threshold-mode history cites F5 | Low (docs only) | Annotate removed; product law unchanged for remaining families |

---

## 11. Acceptance criteria

- [ ] No directory `contracts/vaults/detf/composed/single/`.
- [ ] No `ISingleVaultDetf.sol`; no `DetfSuperchainBridgeRepo.sol`.
- [ ] No `test/foundry/spec/vaults/detf/composed/single/`.
- [ ] No live `scripts/foundry/**` (non-archive) imports of SingleVaultDetf packages.
- [ ] `forge build` succeeds.
- [ ] Grep for `SingleVaultDetf` / `ISingleVaultDetf` / `DetfSuperchainBridgeRepo` under `contracts/` and live `scripts/foundry/` is empty (except intentional historical doc notes if any remain under `docs/` / this PRD).
- [ ] AGENTS.md DETF families table no longer lists Composed single / `composed/single`.
- [ ] SingleStandardExchangeDETF and other family tests still pass smoke set.
- [ ] This PRD remains in-repo as the carve-out record.

---

## 12. Decision log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Fix vs remove | **Remove** | Hardcoded Uni V4 SE package; superseded by SingleStandardExchangeDETF |
| Archive tree | **No** | User: no archive; full removal |
| Superchain bridge repo | **Delete with family** | No other production consumer |
| `ISingleVaultDetf` | **Delete** | Family-only interface |
| Shared core / reusable / claim / bond | **Keep** | Used by other DETFs |
| Scenario3 script | **Retarget to SingleStandardExchangeDETF** (locked) | Keep local inventory-DETF overlay; drop bridge |
| Archive protocol-detf scripts | **Delete** (locked) | No non-compiling archive of this DETF |
| AGENTS family table | **Update in PR** (locked) | Agents must not list composed/single |
| Launch fee-sink docs | **Out of this PR** | Follow-up; do not block removal |

---

## 13. Appendix — quick reference tables

### A. Production Solidity exclusive vs shared

| Path | Exclusive? |
|------|------------|
| `contracts/vaults/detf/composed/single/**` | **Yes — delete** |
| `contracts/interfaces/ISingleVaultDetf.sol` | **Yes — delete** |
| `contracts/vaults/detf/DetfSuperchainBridgeRepo.sol` | **Yes — delete** |
| `contracts/vaults/detf/core/**` | Shared — keep |
| `contracts/vaults/detf/reusable/**` | Shared — keep |
| `contracts/vaults/detf/claimToken/**` | Shared — keep |
| `contracts/vaults/detf/bondNft/**` | Shared — keep |
| `contracts/vaults/detf/DETFCommon.sol` | Shared — keep |
| `contracts/vaults/detf/standardExchange/single/**` | Superseding product — keep |
| `contracts/vaults/detf/composed/multi-vault-weighted/**` | Keep |
| `contracts/vaults/detf/composed/stable/**` | Keep |

### B. Test delete list (complete)

```text
test/foundry/spec/vaults/detf/composed/single/SingleVaultDetf_ProductionBase.t.sol
test/foundry/spec/vaults/detf/composed/single/SingleVaultDetfDFPkg_Deploy.t.sol
test/foundry/spec/vaults/detf/composed/single/SingleVaultDetfExchangeIn_MintWithWeth.t.sol
test/foundry/spec/vaults/detf/composed/single/SingleVaultDetf_MintSellRedeem.t.sol
test/foundry/spec/vaults/detf/composed/single/SingleVaultDetf_AuctionBondWithPosition.t.sol
test/foundry/spec/vaults/detf/composed/single/SingleVaultDetf_BridgeTransport.t.sol
test/foundry/spec/vaults/detf/composed/single/SingleVaultDetf_ThresholdMode.t.sol
test/foundry/spec/vaults/detf/composed/single/SingleVaultDetfBondingFacet_IFacet_Test.t.sol
test/foundry/spec/vaults/detf/composed/single/SingleVaultDetfExchangeInFacet_IFacet_Test.t.sol
test/foundry/spec/vaults/detf/composed/single/SingleVaultDetfExchangeInQueryFacet_IFacet_Test.t.sol
test/foundry/spec/vaults/detf/composed/single/SingleVaultDetfExchangeOutFacet_IFacet_Test.t.sol
test/foundry/spec/vaults/detf/composed/single/SingleVaultDetfInfoFacet_IFacet_Test.t.sol
test/foundry/spec/vaults/detf/composed/single/adversarial/Adversarial_SingleVaultDetf_P0.t.sol
test/foundry/spec/vaults/detf/composed/single/fuzz/SingleVaultDetf_Fuzz.t.sol
```

### C. Why other DETFs stay green

Other families never subclass or import SingleVault targets/repos/factory services. They only share:

- Crane deploy patterns  
- `detf/core` policy libs  
- bond NFT / claim packages  
- Balancer vault/router infra  
- optional 8020 math (via their own imports, not via SingleVaultDetfCommon)

Removing SingleVaultDetf does not unlink those symbols.

---

## 14. Suggested implement commit message (after PRD approval)

```text
chore(detf): remove invalid SingleVaultDetf (composed/single)

Delete the Uni-V4-hardcoded composed/single DETF package, exclusive
interface and Superchain bridge repo, family tests, and live Scenario3
helpers. Single-leg product remains SingleStandardExchangeDETF under
standardExchange/single. Shared detf/core, reusable, claim, and bond
packages are retained.
```

---

*End of PRD. Implementation is intentionally gated on human approval of this document.*
