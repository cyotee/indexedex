# IDXEX-009 Deployment Scripts Review (2026-01-21)

## Summary
The repo now has a dedicated Anvil Base-main fork script, but it does **not** meet IDXEX-009 requirements for staged, idempotent, full deployment (core + all packages + fixtures) with complete UI artifacts. It also contains a compile-breaking token deployment block and missing required outputs. Legacy local scripts still include forbidden `new` deployments.

## Scope
Reviewed:
- [scripts/foundry/anvil_base_main/Script_AnvilBaseMain_DeployAll.s.sol](scripts/foundry/anvil_base_main/Script_AnvilBaseMain_DeployAll.s.sol)
- [scripts/foundry/base_main/Script_BaseMain_DeployIndexedex.s.sol](scripts/foundry/base_main/Script_BaseMain_DeployIndexedex.s.sol)
- [scripts/foundry/local/segmented/Local_04_Uniswap_V2.s.sol](scripts/foundry/local/segmented/Local_04_Uniswap_V2.s.sol)
- [foundry.toml](foundry.toml)

## Checklist (IDXEX-009)
- [ ] **Staged and independently runnable**
  - Current Anvil Base-main script is monolithic (single `run()` flow). No stage boundaries.
- [ ] **Each stage reads JSON state and skips already-complete work**
  - No JSON state is read; only writes UI artifacts.
- [ ] **Deterministic salts per repo convention**
  - Mixed: some facets use type-name hashing; package deploys rely on helpers but no explicit idempotent reuse checks.
- [x] **Foundry fs permissions**
  - `fs_permissions = [{ access = "read-write", path = "./"}]` set in [foundry.toml](foundry.toml).
- [ ] **Base-main fork uses `BASE_MAIN.sol` and produces UI artifacts**
  - Script binds Base addresses, but output is incomplete per required fields.
- [ ] **Required package list for Base-main fork**
  - Missing multiple required packages (see Findings).
- [ ] **Required instances/fixtures deployed**
  - None are deployed (no vaults, seigniorage, protocol instances).
- [ ] **No `new` deployments**
  - Local segmented scripts still deploy `UniV2Router02` via `new`.

## Findings

### 1) Blocker — Missing required packages + fixtures on Anvil Base-main fork
The Anvil script only deploys core + Uniswap V2, Aerodrome, optional Camelot, and Balancer router packages, plus test tokens. It does **not** deploy the required seigniorage packages, protocol packages, Balancer constant-product vault package, StandardExchangeRateProvider package, or any vault/instance fixtures.
- Evidence: [Script_AnvilBaseMain_DeployAll.s.sol](scripts/foundry/anvil_base_main/Script_AnvilBaseMain_DeployAll.s.sol#L123-L132)

**Impact:** UI cannot test the full stack, and IDXEX-009 requirements are not met.

### 2) Blocker — No staged/idempotent state management
IDXEX-009 requires staged scripts with JSON state read/write and “skip already deployed” behavior. The Anvil script is a single execution path with no state reads and no stage boundaries.
- Evidence: [Script_AnvilBaseMain_DeployAll.s.sol](scripts/foundry/anvil_base_main/Script_AnvilBaseMain_DeployAll.s.sol#L108-L156) and [Script_AnvilBaseMain_DeployAll.s.sol](scripts/foundry/anvil_base_main/Script_AnvilBaseMain_DeployAll.s.sol#L440-L523)

**Impact:** Reruns are not guaranteed to be safe or idempotent.

### 3) High — UI export missing required core addresses and artifacts
`base_deployments.json` only includes `chainId`, `permit2`, `weth9`, and Balancer router addresses. It omits required fields like `create3Factory`, `diamondPackageFactory`, `indexedexManager`, registry/oracle addresses, and fee collector. There are no exports for deployed packages/instances beyond a minimal `factories` list.
- Evidence: [Script_AnvilBaseMain_DeployAll.s.sol](scripts/foundry/anvil_base_main/Script_AnvilBaseMain_DeployAll.s.sol#L454-L523)

**Impact:** Frontend lacks required data for core contracts and fixtures.

### 4) High — Token deployment block mismatches `ERC20MintBurnOwnableOperableDFPkg`
The Anvil script’s `_deployTestTokens()` block appears incompatible with the current package interface:
- Uses `ERC20MintBurnOwnableFacet` without importing it.
- Constructs `PkgInit` without the required `diamondFactory` field and uses `multiStepOwnableFacet` field name that does not match the package’s `mutiStepOwnableFacet`.
- Calls `deployToken()` with 4 args, but the package interface requires 5 args including `optionalSalt`.

Evidence: [Script_AnvilBaseMain_DeployAll.s.sol](scripts/foundry/anvil_base_main/Script_AnvilBaseMain_DeployAll.s.sol#L404-L437)

**Impact:** The script does not compile against the current Crane package interface, blocking Anvil deployment.

### 5) Medium — Legacy local scripts use forbidden `new` deployments
The segmented local script deploys `UniV2Router02` with `new`, violating the CREATE3-only rule for production components and contradicting the task requirements.
- Evidence: [Local_04_Uniswap_V2.s.sol](scripts/foundry/local/segmented/Local_04_Uniswap_V2.s.sol#L87-L92)

**Impact:** These scripts are non-compliant and likely stale (also use legacy import paths).

## Recommendations
1. Split the Anvil Base-main deployment into staged scripts (factories/core → packages → instances → export) with JSON state reads/writes for idempotency.
2. Add missing package deployments and required fixture instances for all DEX, Seigniorage, and Protocol packages listed in IDXEX-009.
3. Expand UI export files to include full core and instance addresses (factories, manager, registry, oracle, fee collector, packages, instances, tokenlists).
4. Fix `_deployTestTokens()` to match `ERC20MintBurnOwnableOperableDFPkg` interface and add missing imports.
5. Remove or refactor legacy local scripts that use `new` or outdated import paths.

## Status
**IDXEX-009 not satisfied.** Blockers remain until full staged Anvil Base-main deployment + UI artifacts + fixtures are implemented.
