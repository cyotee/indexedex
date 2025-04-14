# AGENTS.md

This file provides guidance to AI Agents when working with code in this repository.
If PROGRESS.md exists in the project root, read it for cross-session context before starting work.

## Required Reading

**Before working on this codebase, you MUST also read the Crane framework documentation:**
- `lib/daosys/lib/crane/CLAUDE.md` - Contains essential patterns for Repos, Facets, Targets, and the Diamond architecture that IndexedEx builds upon.

## Project Overview

IndexedEx is modular DeFi vault infrastructure using the Diamond Pattern (EIP-2535). It provides upgradeable vault strategies with integrated cross-protocol orchestration across Uniswap V2, Camelot V2, Aerodrome, and Balancer V3.

## Codebase Overview

IndexedEx is modular DeFi vault infrastructure using the Diamond Pattern (EIP-2535) with CREATE3 deterministic deployments. It provides upgradeable vault strategies with integrated cross-protocol orchestration.

**Stack**: Solidity 0.8.30, Foundry, Next.js 14, Wagmi/Viem, Balancer V3, Aerodrome, Uniswap V2, Camelot V2

**Structure**:
- `contracts/` - Smart contracts (manager, registries, vaults, protocols)
- `frontend/` - Next.js React application
- `scripts/` - Deployment scripts (Foundry + shell)
- `test/foundry/` - Spec tests (mocks) and fork tests (Base mainnet)
- `lib/daosys/lib/crane/` - Crane framework (Diamond + Factory infrastructure)

For detailed architecture, see [docs/CODEBASE_MAP.md](docs/CODEBASE_MAP.md).

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

## Critical: CREATE3 Factory Deployment

**NEVER use `new` to deploy contracts.** All deployments must go through the CREATE3 factory system for deterministic cross-chain addresses.

```solidity
// WRONG - will break tests and CI
MyContract c = new MyContract();

// CORRECT - use factory service pattern
myFacet = factory.deployFacet(
    type(MyFacet).creationCode,
    abi.encode(type(MyFacet).name)._hash()
);
```

FactoryService libraries encapsulate deployment logic:
- `contracts/fee/collector/FeeCollectorFactoryService.sol`
- `contracts/manager/IndexedexManagerFactoryService.sol`
- `contracts/protocols/dexes/*/...FactoryService.sol`

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

Tests inherit from base classes in Crane:
- `CraneTest` - base test with factory setup
- `TestBase_IFacet` - for testing individual facets

IndexedEx-specific test base:
- `contracts/test/IndexedexTest.sol` - sets up core infrastructure (owner, facets, packages, proxies)

Protocol-specific test bases:
- `contracts/protocols/dexes/uniswap/v2/TestBase_UniswapV2StandardExchange.sol`
- `contracts/protocols/dexes/camelot/v2/TestBase_CamelotV2StandardExchange.sol`
- `contracts/protocols/dexes/aerodrome/v1/TestBase_AerodromeStandardExchange.sol`
- `contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol`

IFacet tests must implement:
- `facetTestInstance()` - return the facet under test
- `controlFacetInterfaces()` - expected interface IDs
- `controlFacetFuncs()` - expected function selectors

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

Each DEX integration follows this structure:
- `*StandardExchangeInFacet.sol` - swap token in logic
- `*StandardExchangeOutFacet.sol` - swap token out logic
- `*StandardExchangeCommon.sol` - shared utilities
- `*_Component_FactoryService.sol` - CREATE3 deployment helpers
- `TestBase_*StandardExchange.sol` - test base class

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

## Vault Deployment Pattern

**All vault packages and instances MUST be deployed through the IndexedexManager proxy.**

### Why?

1. **Deterministic addresses** - CREATE3 ensures same addresses across chains
2. **Registry tracking** - Vaults are indexed by type, token, and package for discovery
3. **Fee oracle integration** - Vault fees configured through centralized oracle
4. **Access control** - Package deployment requires owner/operator permissions

### Deployment Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│ Step 1: Deploy Facets via CREATE3Factory                            │
│   factory.deployFacet(type(MyFacet).creationCode, salt)             │
└─────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│ Step 2: Deploy Vault DFPkg via IndexedexManager                     │
│   indexedexManager.deployPkg(creationCode, initArgs, salt)          │
│   → Package registers with VaultRegistryVaultPackageRepo            │
│   → Indexed by vault types and fee configuration                    │
└─────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│ Step 3: Deploy Vault Instances via DFPkg                            │
│   myVaultPkg.deployVault(poolOrAsset)                               │
│   → Internally calls indexedexManager.deployVault(pkg, args)        │
│   → Vault registers with VaultRegistryVaultRepo                     │
│   → Indexed by token, type, package for efficient queries           │
└─────────────────────────────────────────────────────────────────────┘
```

### Anti-Pattern: Direct Factory Deployment

```solidity
// WRONG - bypasses registry, breaks indexing
address vault = diamondFactory.deploy(myPkg, pkgArgs);

// CORRECT - goes through IndexedexManager
address vault = myVaultPkg.deployVault(pool);
// or
address vault = indexedexManager.deployVault(myPkg, pkgArgs);
```

### Vault DFPkg Requirements

Every vault DFPkg must implement `IStandardVaultPkg`:

```solidity
interface IStandardVaultPkg is IDiamondFactoryPackage {
    function vaultDeclaration() external view returns (VaultPkgDeclaration memory);
}

struct VaultPkgDeclaration {
    string name;           // Package name for registry
    bytes4[] feeTypeIds;   // Fee types this vault uses
    bytes4[] vaultTypeIds; // Interface IDs the vault implements
}
```

### Registry Queries

Once deployed, vaults can be discovered via:

```solidity
// All vaults accepting a token
address[] memory vaults = indexedexManager.vaultsOfToken(tokenAddress);

// All vaults of a specific type
address[] memory vaults = indexedexManager.vaultsOfType(IStandardExchange.interfaceId);

// Vaults accepting token AND implementing type
address[] memory vaults = indexedexManager.vaultsOfTokenOfTypeId(typeId, token);
```

### Key Files

| File | Purpose |
|------|---------|
| `contracts/interfaces/IVaultRegistryDeployment.sol` | Deployment interface |
| `contracts/registries/vault/VaultRegistryDeploymentTarget.sol` | Deployment logic |
| `contracts/registries/vault/VaultRegistryVaultPackageRepo.sol` | Package tracking |
| `contracts/registries/vault/VaultRegistryVaultRepo.sol` | Vault tracking |
| `contracts/manager/IndexedexManagerDFPkg.sol` | Manager composition |
| `contracts/test/IndexedexTest.sol` | Test setup example |

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
