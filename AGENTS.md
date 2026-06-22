# AGENTS.md

This file provides guidance to AI Agents when working with code in this repository.
If PROGRESS.md exists in the project root, read it for cross-session context before starting work.

## Required Reading

**You MUST read in this order:**

1. Crane materials (Crane is independent):
   - `lib/daosys/lib/crane/AGENTS.md`
   - The Crane skills (in `lib/daosys/lib/crane/.claude/skills/`), especially:
     - `crane-deployment` — CREATE3, DFPkgs, FactoryService, proxy creation.
     - `crane-architecture` — core patterns, DFPkg.
     - `crane-testing` — `CraneTest`, factory bootstrap, TestBases.
   - Crane docs under `lib/daosys/lib/crane/docs/` (especially `docs/deployment/`).

2. This file (IndexedEx AGENTS.md) — explains how IndexedEx layers on Crane.

See also `CLAUDE.md` (points back to this file).

## Project Overview

IndexedEx is modular DeFi vault infrastructure using the Diamond Pattern (EIP-2535). It provides upgradeable vault strategies with integrated cross-protocol orchestration across Uniswap V2, Camelot V2, Aerodrome, and Balancer V3.

## Codebase Overview

IndexedEx is modular DeFi vault infrastructure using the Diamond Pattern (EIP-2535) with CREATE3 deterministic deployments. It provides upgradeable vault strategies with integrated cross-protocol orchestration.

**Stack**: Solidity 0.8.30, Foundry, Next.js 14, Wagmi/Viem, Balancer V3 (incl. Standard Exchange Buffer Pool), Aerodrome V1 + Slipstream, Uniswap V2 + V4, Camelot V2, Aave V3 Stata (ERC-4626).

**Structure**:
- `contracts/` - Smart contracts (manager, registries, oracles/fee, vaults, protocols/dexes + protocols/lending)
- `frontend/` - Next.js React app (list-driven, chain-keyed; swap auto-routes through Standard Exchange Vaults)
- `scripts/foundry/<env>/` - Staged deploy scripts (`Script_00..Script_99`); `scripts/node/` - Token List aggregator
- `test/foundry/` - Spec tests (mocks/invariant/comparative) and fork tests (Base mainnet)
- `lib/daosys/lib/crane/` - Crane framework (Diamond + Factory infrastructure)
- `.cartographer/` - Code-graph artifacts (`graph.sqlite`); query with `cartographer brief`/`slice`/`impact`

For detailed architecture, see [docs/CODEBASE_MAP.md](docs/CODEBASE_MAP.md) (refreshed 2026-06-21 from the Cartographer graph).

## Build & Test Commands

```bash
# Build
forge build
forge build --sizes         # with contract size output

# Run all tests
forge test
forge test -vvv             # verbose output
forge test -vvvv            # full stack trace

# Run specific tests
forge test --match-path test/foundry/spec/protocol/...
forge test --match-test testFunctionName
forge test --match-contract ContractNameTest

# Format Solidity
forge fmt

# Local development with Anvil fork
anvil --fork-url <RPC_URL>
forge script scripts/foundry/UI_Dev_Anvil.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

## Architecture: 3-Tier Diamond Deployment

**Facets -> Packages -> Proxies**

1. **Facets**: Individual logic components (e.g., `FeeCollectorManagerFacet`, `VaultRegistryDeploymentFacet`)
2. **Packages (DFPkg)**: Bundle related facets together (e.g., `FeeCollectorDFPkg`, `IndexedexManagerDFPkg`)
3. **Proxies**: Diamond proxy instances that users interact with (e.g., `IFeeCollectorProxy`, `IIndexedexManagerProxy`)

## Critical: CREATE3 Factory Deployment (Crane Foundation)

**NEVER use `new` to deploy contracts.** All deployments go through Crane's CREATE3 factory system. See the `crane-deployment` skill (in the Crane submodule) for the full detailed patterns, code examples, anti-patterns, and test setup.

High-level reminder:
```solidity
// WRONG
MyContract c = new MyContract();

// CORRECT (via FactoryService or directly on create3Factory)
myFacet = create3Factory.deployFacet(
    type(MyFacet).creationCode,
    abi.encode(type(MyFacet).name)._hash()
);
```

FactoryService libraries (Crane + IndexedEx):
- Crane core: `AccessFacetFactoryService`, `IntrospectionFacetFactoryService` (in Crane).
- IndexedEx core: `IndexedexManagerFactoryService`, `FeeCollectorFactoryService`, `VaultComponentFactoryService`.
- Protocol: `*_Component_FactoryService.sol` (e.g. `CamelotV2_Component_FactoryService`).

**Always start with the Crane `crane-deployment` skill + `CraneTest` / `InitDevService`.**

## Key Import Remappings

```
@crane/          -> lib/daosys/lib/crane/
@solady/         -> lib/daosys/lib/crane/lib/solady/src/
@openzeppelin/   -> lib/daosys/lib/crane/lib/openzeppelin-contracts/
@balancer-labs/  -> lib/daosys/lib/crane/lib/balancer-v3-monorepo/pkg/...
forge-std/       -> lib/daosys/lib/crane/lib/forge-std/src/
permit2/         -> lib/daosys/lib/crane/lib/permit2/
```

Update both `remappings.txt` and `foundry.toml` when adding new libraries.

## Test Patterns

**See `crane-testing` skill + `crane-deployment` skill first.**

- Inherit `CraneTest` (provides `create3Factory` + `diamondPackageFactory` via `InitDevService`).
- Then `IndexedexTest` (builds the core manager, fee collector, etc. using Crane factories + registers the manager as operator).
- Then `TestBase_VaultComponents` (deploys shared vault facets via Crane factories + `VaultComponentFactoryService`).
- Then protocol TestBases (e.g. `TestBase_CamelotV2StandardExchange`).

Protocol test base examples (follow these exactly):
- `contracts/protocols/dexes/camelot/v2/TestBase_CamelotV2StandardExchange.sol`
- `contracts/test/bases/TestBase_AaveV3StataStandardExchange.sol`
- `contracts/protocols/dexes/aerodrome/v1/TestBase_AerodromeStandardExchange.sol`

**Key rule in IndexedEx**: Facets use the Crane path (`create3Factory`). Vault/StandardExchange *DFPkgs* use the manager/registry path. See the section below.

IFacet / behavior tests implement the usual virtuals (`facetTestInstance()`, etc.).

## Project Structure

```
contracts/
├── constants/          # Deployment constants
├── fee/collector/      # Fee collection system
├── interfaces/         # Contract interfaces & proxies
├── manager/            # IndexedexManager (main orchestrator)
├── oracles/fee/        # Fee oracle system
├── protocols/dexes/    # DEX integrations
│   ├── aerodrome/v1/
│   ├── balancer/v3/
│   ├── camelot/v2/
│   └── uniswap/v2/
├── registries/vault/   # Vault registry system
├── script/             # Foundry scripts
├── test/               # Test bases and helpers
└── vaults/             # Vault implementations
```

## Solidity Version & Compiler Settings

- Solidity: `0.8.30`
- Optimizer: enabled, max runs (`4294967295`)
- FFI: enabled (required for some tests)

## Protocol Integration Pattern

Each DEX/lending integration follows this structure (see `crane-deployment` for Crane base + the Component_FactoryService for the IndexedEx manager path):
- `*StandardExchangeInFacet.sol` / `...OutFacet.sol` / Marker — deployed via `create3Factory` (Crane).
- `*_Component_FactoryService.sol` — provides the typed `deploy*Facet` (on create3Factory) and `deploy*DFPkg` (on indexedexManager) helpers.
- `TestBase_*StandardExchange.sol` — correct test setup (follow these).
- The DFPkg itself and instance creation go through the VaultRegistry path on the manager (see Deployment section above).

## Permit2 Witness Canonical Source (Balancer Router)

For Permit2 signed swap flows, treat the router as the source of truth for witness schema values.

- The router proxy already includes `BalancerV3StandardExchangeRouterPermit2WitnessFacet` in its package wiring.
- Read canonical values from the router via:
  - `WITNESS_TYPE_STRING()`
  - `WITNESS_TYPEHASH()`

Current canonical witness values (from router constants):

```text
WITNESS_TYPE_STRING = "Witness witness)TokenPermissions(address token,uint256 amount)Witness(address owner,address pool,address tokenIn,address tokenInVault,address tokenOut,address tokenOutVault,uint256 amountIn,uint256 limit,uint256 deadline,bool wethIsEth,bytes32 userData)"
WITNESS_TYPEHASH   = keccak256("Witness(address owner,address pool,address tokenIn,address tokenInVault,address tokenOut,address tokenOutVault,uint256 amountIn,uint256 limit,uint256 deadline,bool wethIsEth,bytes32 userData)")
```

Practical rules:
- Do not hardcode alternate witness strings in clients if router getters are available.
- Use EIP-712 typed-data signatures (`signTypedData`), not `signMessage`.
- In signed mode, if quote-time signature is missing/expired, re-sign at swap click and execute `*WithPermit` paths.

## Deployment in IndexedEx (Crane + Registry Layer)

**Foundational mechanics come from Crane.** Read the Crane `crane-deployment` skill first for facets, DFPkgs, FactoryService, and `CraneTest` bootstrap.

IndexedEx adds a registry layer **only** for vault-style packages (StandardExchangeDFPkgs, DETF pkgs, etc.). Core foundation packages (IndexedexManagerDFPkg, FeeCollectorDFPkg) use the direct Crane path.

### Two Paths

**1. Pure Crane path (facets + generic packages)**
- Facets: `create3Factory.deployXXXFacet()` (or via `*FactoryService`).
- Generic DFPkgs: `create3Factory.deployPackageWithArgs(...)`.
- Instances: `diamondPackageFactory.deploy(pkg, args)` or package helper.

See `IndexedexTest` for how the core manager + feeCollector are created this way.

**2. IndexedEx vault package path (the one that trips people up)**
- Facets (In/Out/Marker, vault components): still pure Crane via `create3Factory` + `VaultComponentFactoryService` / `XXX_Component_FactoryService`.
- DFPkg for the vault package: **must** go through the manager:
  ```solidity
  vm.prank(owner);
  myVaultDFPkg = indexedexManager.deployCamelotV2StandardExchangeDFPkg(pkgInit);
  // (or deployAaveV3Stata..., deployAerodrome..., etc.)
  ```
  This calls `IVaultRegistryDeployment.deployPkg(...)`, which does CREATE3 + registers in `VaultRegistryVaultPackageRepo`.
- Instance: `myVaultDFPkg.deployVault(asset)`.
  The DFPkg calls the registry's `deployVault`, which does the actual `diamondPackageFactory` step + registers the resulting vault.

See concrete examples:
- `contracts/protocols/dexes/camelot/v2/TestBase_CamelotV2StandardExchange.sol`
- `contracts/test/bases/TestBase_AaveV3StataStandardExchange.sol`

### Why the registry path for vault packages?

- Discovery via `indexedexManager.vaultsOfToken(...)` / `vaultsOfType(...)`.
- Authorization (`_onlyOwnerOrOperatorOrPkg` in `VaultRegistryDeploymentTarget`).
- Consistent fee oracle + manager wiring.

### Anti-Patterns (these are the errors the other agent made)

```solidity
// WRONG
SomeFacet f = new SomeFacet();
SomeDFPkg p = new SomeDFPkg(init);
address v = diamondPackageFactory.deploy(IDiamondFactoryPackage(myVaultPkg), args);
create3Factory.deployPackageWithArgs(...); // for a registered vault DFPkg
```

**Always**:
- Use the factories from `CraneTest` / `IndexedexTest`.
- For vault DFPkgs, use the typed `indexedexManager.deploy*DFPkg(...)` (requires `vm.prank(owner)`).
- Let the DFPkg's `deployVault(...)` (or manager) create instances.

### Vault DFPkg Requirements

Every vault DFPkg must implement `IStandardVaultPkg`.

**Additionally (Crane rule)**: `PkgInit` and `PkgArgs` structs **must** be defined inside the package's interface (`interface IMyVaultDFPkg { struct PkgInit ... }`), never inside the contract.

This is a very common error. Full explanation and correct vs. incorrect examples are in the Crane `crane-architecture` skill → `references/dfpkg-pattern.md`.

### Key Files

See the table in the original "Vault Deployment Pattern" area and the files listed in `contracts/registries/vault/` and protocol `*_Component_FactoryService.sol` files.

Consult the Crane `crane-deployment` skill for the underlying mechanics, then follow the patterns in IndexedEx's good TestBases.

## Submodules

The main dependency is `lib/daosys` which contains the Crane framework. Initialize with:
```bash
git submodule update --init --recursive
```

## Git Worktree Workflow (git-wt)

This project uses `git-wt` to simplify working with multiple branches simultaneously via git worktrees. Each worktree is an independent working directory with its own branch.

### Commands

```bash
# List all worktrees
git wt

# Create new worktree for a branch (or switch to existing)
git wt <branch-name>

# Delete worktree and branch (with safety checks)
git wt -d <branch-name>

# Force delete worktree and branch
git wt -D <branch-name>
```

### Configuration

Configure via `git config`:

```bash
# Set custom worktree base directory (default: ../{repo}-wt)
git config wt.basedir /path/to/worktrees

# Copy .gitignore-excluded files to new worktrees
git config wt.copyignored true

# Copy untracked files to new worktrees
git config wt.copyuntracked true

# Copy uncommitted changes to new worktrees
git config wt.copymodified true

# Run hook after creating worktree (e.g., install deps)
git config wt.hook "forge build"
```

### Recommended Workflow

When working on a feature or fix that requires isolation:

```bash
# Create worktree for feature branch
git wt feature/new-vault-strategy

# Work in the new worktree directory
# Changes are isolated from main worktree

# When done, delete the worktree
git wt -d feature/new-vault-strategy
```

This is useful for:
- Running long tests in one worktree while developing in another
- Comparing behavior between branches side-by-side
- Isolating experimental changes without stashing

### Submodule-Aware Worktree Scripts

Due to nested submodules (indexedex → daosys → crane), standard `git worktree` commands can fail. Use these scripts instead:

```bash
# Create worktree with proper submodule initialization
./scripts/wt-create.sh feature/my-feature

# Remove worktree (handles submodules, cleans locks)
./scripts/wt-remove.sh feature/my-feature

# Manually init submodules in existing worktree
./scripts/wt-post-create.sh /path/to/worktree
```

**Why scripts instead of `git wt`?**

1. **Submodule pointer corruption** - Worktrees can reference commits that no longer exist
2. **Lock file contention** - Multiple worktrees share `.git/modules/` and can deadlock
3. **Force removal required** - `git worktree remove` fails on submodule worktrees
4. **Fallback copying** - Scripts copy submodules from main repo when git init fails

The `wt.hook` is configured to run `./scripts/wt-post-create.sh` automatically when using `git wt`.

**Troubleshooting:**

```bash
# Clear stale lock files
find .git/modules -name "*.lock" -delete

# Prune stale worktree references
git worktree prune

# Manual submodule copy (if all else fails)
cp -R /path/to/main/lib/daosys /path/to/worktree/lib/daosys
```

## Librarian (Documentation Search)

Librarian is a local CLI tool that fetches and searches up-to-date developer documentation. Use it to get real context from official docs instead of relying on potentially outdated training data.

### Core Commands

```bash
# Search documentation (hybrid keyword + semantic search)
librarian search --library vercel/next.js "middleware"
librarian search --library openzeppelin/contracts "ERC20"
librarian search --library balancer/docs "swap"

# Search modes
librarian search --library <lib> --mode word "query"    # keyword only
librarian search --library <lib> --mode vector "query"  # semantic only
librarian search --library <lib> --version 5.x "query"  # specific version

# Get full document content
librarian get --library <lib> docs/path/to/file.md
librarian get --library <lib> --doc 69 --slice 19:73    # specific lines

# Find library and list available versions
librarian library "solidity"
librarian library "foundry"
```

### Managing Documentation Sources

```bash
# Add GitHub repo as source
librarian add https://github.com/owner/repo --docs docs --ref main
librarian add https://github.com/foundry-rs/foundry --version 1.x

# Add website documentation
librarian add https://docs.soliditylang.org
librarian add https://docs.balancer.fi --depth 3 --pages 500

# Ingest/update documentation
librarian ingest                    # process all sources
librarian ingest --force            # re-process existing
librarian ingest --embed            # generate semantic embeddings

# Manage sources
librarian source list               # view configured sources
librarian source remove 1           # delete a source
librarian seed                      # add built-in seed libraries
```

### Utility Commands

```bash
librarian detect      # identify project versions in current directory
librarian status      # show document counts and statistics
librarian cleanup     # remove inactive documentation
librarian mcp         # run as MCP server for AI agent integration
```

### Recommended Sources for This Project

```bash
# Solidity & Foundry
librarian add https://github.com/foundry-rs/foundry --docs docs
librarian add https://docs.soliditylang.org

# OpenZeppelin
librarian add https://github.com/OpenZeppelin/openzeppelin-contracts --docs docs

# Balancer V3
librarian add https://github.com/balancer/docs --docs docs

# Uniswap
librarian add https://github.com/Uniswap/docs --docs docs
```

### Configuration

Config file: `~/.config/librarian/config.yml`

```yaml
github:
  token: ghp_xxx              # for private repos

crawl:
  concurrency: 5

ingest:
  maxMajorVersions: 3
```
