---
project: IndexedEx
version: 1.0
created: 2026-01-12
last_updated: 2026-01-12
---

# IndexedEx - Product Requirements Document

## Vision

IndexedEx is modular DeFi vault infrastructure using the Diamond Pattern (EIP-2535). It provides upgradeable vault strategies with integrated cross-protocol orchestration, enabling seamless interaction across multiple DeFi protocols through a unified, deterministically-deployed architecture.

## Problem Statement

DeFi protocol fragmentation creates significant barriers for developers and users:

- **Protocol Fragmentation**: Each DEX/lending protocol has unique interfaces, requiring custom integration work for every combination
- **Upgradeability Challenges**: Traditional smart contracts are immutable, making bug fixes and improvements difficult
- **Cross-Chain Deployment Complexity**: Maintaining consistent addresses and behavior across multiple EVM chains requires careful coordination
- **Vault Strategy Composition**: Building strategies that span multiple protocols requires complex orchestration logic

IndexedEx solves these by providing a unified infrastructure layer with modular, upgradeable components and deterministic cross-chain deployments.

## Target Users

| User Type | Description | Primary Needs |
|-----------|-------------|---------------|
| DeFi Protocol Integrators | Teams building applications on top of IndexedEx | Stable APIs, comprehensive docs, protocol coverage |
| Vault Operators/Deployers | Entities deploying and managing vault strategies | Easy deployment, fee management, monitoring |
| End Users/LPs | Liquidity providers depositing into vaults | Reliable vaults, transparent fees, consistent UX |

## Goals

### Primary Goals

1. **Unified Protocol Interface**: Provide a single abstraction for interacting with multiple DEX protocols (Balancer V3, Aerodrome, Uniswap V2, Camelot V2)
2. **Modular Upgradeability**: Enable safe, granular upgrades via Diamond Pattern facets without disrupting deployed vaults
3. **Deterministic Cross-Chain Deployment**: Ensure identical contract addresses across all supported EVM chains via CREATE3
4. **Registry-Based Discovery**: Centralized vault and package tracking for efficient discovery and orchestration
5. **Flexible Fee Management**: Configurable fee oracles with per-vault, per-protocol, and per-operation granularity

### Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Protocol Integrations | 4+ DEX protocols | Active integrations with tests passing |
| Deployment Coverage | 3+ EVM chains | Deterministic addresses verified across networks |
| Test Coverage | 90%+ | Foundry coverage report |
| Facet Reusability | 70%+ shared | Facets used across multiple vault types |

## Non-Goals (Out of Scope)

- **Chain-Specific Optimizations**: IndexedEx is multi-chain by design; no single-chain specialized features
- **End-User Trading Frontend**: Infrastructure layer only; UIs are built by integrators
- **Yield Optimization Strategies**: Provides vault infrastructure, not active yield farming logic
- **Centralized Components**: No off-chain dependencies for core functionality
- **Non-EVM Chains**: Focus on EVM-compatible networks only

## Key Features

### Feature 1: 3-Tier Diamond Deployment Architecture

Modular deployment pattern separating concerns into Facets (logic), Packages (bundled facets), and Proxies (user interfaces).

```
Facets → Packages → Proxies
```

- **Facets**: Individual logic components (ERC20, swap, fee management)
- **Packages (DFPkg)**: Bundle related facets with initialization logic
- **Proxies**: Diamond proxy instances users interact with

### Feature 2: CREATE3 Factory System

Deterministic cross-chain addresses via CREATE3 deployment with factory-managed lifecycles.

- All deployments through `Create3Factory` and `DiamondPackageCallBackFactory`
- Salt derivation from type names: `abi.encode(type(X).name)._hash()`
- Never use `new` keyword for contract deployment

### Feature 3: Cross-Protocol Orchestration

Unified exchange interface supporting multiple DEX protocols with 10+ swap routes.

| Protocol | Status | Features |
|----------|--------|----------|
| Balancer V3 | Priority | Constant product pools, custom hooks, ERC4626 adaptation |
| Aerodrome V1 | Active | Velodrome-style AMM, gauge integration |
| Uniswap V2 | Active | Standard AMM, LP management |
| Camelot V2 | Active | Arbitrum-native DEX, LP management |

### Feature 4: Vault Registry System

Centralized tracking and discovery of vaults, packages, and their relationships.

- **VaultRegistryVaultPackageRepo**: Package tracking by type and fee configuration
- **VaultRegistryVaultRepo**: Vault instances indexed by token, type, package
- Query methods: `vaultsOfToken()`, `vaultsOfType()`, `vaultsOfTokenOfTypeId()`

### Feature 5: Fee Oracle System

Configurable fee management with oracle integration.

- Default fees by category (vault, dex, lending)
- Per-vault fee overrides
- Fee recipient management
- Integration with vault registry

## Technical Requirements

### Architecture

3-tier Diamond deployment with Crane framework patterns:

| Layer | Pattern | Purpose |
|-------|---------|---------|
| Repo | `*Repo.sol` | Storage with assembly slot binding |
| Target | `*Target.sol` | Business logic using Repo |
| Facet | `*Facet.sol` | Diamond facet implementing IFacet |

All vault packages and instances deployed through IndexedexManager proxy for registry tracking.

### Integrations

| System | Purpose | Type |
|--------|---------|------|
| Balancer V3 Vault | Pool registration, swaps, liquidity | Read/Write |
| Aerodrome Router | Swaps, liquidity provision | Read/Write |
| Uniswap V2 Pairs | LP token management | Read/Write |
| Camelot V2 Router | Swaps, liquidity provision | Read/Write |
| Permit2 | Token approvals | Read/Write |

### Chains & Networks

| Network | Purpose | Priority |
|---------|---------|----------|
| Sepolia | Primary testnet | P0 |
| Arbitrum Sepolia | Secondary testnet | P0 |
| Base Sepolia | Tertiary testnet | P1 |
| Ethereum Mainnet | Production | P1 |
| Arbitrum One | Production | P1 |
| Base | Production | P2 |

### Security Requirements

- **Diamond Pattern Upgrades**: Owner-controlled facet additions/replacements via DiamondCut
- **Access Control**: Role-based permissions (Owner, Operator) via Operable pattern
- **Reentrancy Guards**: Standard reentrancy protection on state-modifying functions
- **EIP-8023 Ownership**: Two-step ownership transfer preventing accidental transfers
- **Audit Requirements**: External audit before mainnet deployment
- **CREATE3 Only**: All deployments via factory to prevent address manipulation

### Constraints

- Solidity 0.8.30
- No `viaIR` compilation (use structs for stack-too-deep)
- Optimizer: enabled with max runs (4294967295)
- EVM version: Prague
- FFI enabled for tests

## Development Approach

### Repository Structure

```
indexedex/
├── contracts/
│   ├── constants/           # Deployment constants
│   ├── fee/collector/       # Fee collection system
│   ├── interfaces/          # Contract interfaces & proxies
│   ├── manager/             # IndexedexManager (main orchestrator)
│   ├── oracles/fee/         # Fee oracle system
│   ├── protocols/dexes/     # DEX integrations
│   │   ├── aerodrome/v1/
│   │   ├── balancer/v3/
│   │   ├── camelot/v2/
│   │   └── uniswap/v2/
│   ├── registries/vault/    # Vault registry system
│   ├── script/              # Foundry scripts
│   ├── test/                # Test bases and helpers
│   └── vaults/              # Vault implementations
├── lib/
│   └── daosys/              # Crane framework (submodule)
│       └── lib/crane/
├── scripts/                 # Deployment scripts
├── tasks/                   # Task management
└── test/                    # Test suites
```

### Layers

| Layer | Location | Purpose |
|-------|----------|---------|
| Crane Framework | `lib/daosys/lib/crane/` | Diamond infrastructure, factory system |
| Core Infrastructure | `contracts/manager/`, `contracts/registries/` | IndexedexManager, vault registry |
| Protocol Integrations | `contracts/protocols/dexes/` | DEX-specific facets and services |
| Vault Implementations | `contracts/vaults/` | Strategy vault packages |

### Key Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| Solidity | 0.8.30 | Smart contract language |
| Foundry | Latest | Build, test, deploy tooling |
| Solady | Latest | Gas-optimized utilities |
| OpenZeppelin | 5.x | Standard implementations |
| Balancer V3 | Latest | Pool integration |
| Permit2 | Latest | Token approval management |

### Testing Requirements

4-tier testing architecture:

1. **IFacet Tests**: Interface compliance validation for each facet
2. **Infrastructure Tests**: Factory setup, vault deployment, registry
3. **Pool Foundation Tests**: Standard pool functionality (liquidity, swaps, fees)
4. **Integration Tests**: Cross-protocol orchestration, end-to-end flows

Requirements:
- All tests use CREATE3 factory (never `new`)
- Foundry fuzz testing for math-heavy functions
- Invariant testing for token/balance properties
- Fork tests against live protocols

### Documentation Standards

- NatSpec with AsciiDoc include-tags
- Custom tags: `@custom:signature`, `@custom:selector`, `@custom:interfaceid`
- CLAUDE.md for AI assistant guidance
- Inline code comments for complex logic only

## Milestones

| Milestone | Description | Status |
|-----------|-------------|--------|
| M1: Core Infrastructure | IndexedexManager, VaultRegistry, FeeOracle, CREATE3 factory | 🔄 In Progress |
| M2: Balancer V3 Integration | Complete Balancer V3 pool support with hooks | 🔄 In Progress |
| M3: Additional Protocols | Aerodrome, UniswapV2, CamelotV2 integrations | 🆕 Not Started |
| M4: Testnet Deployment | Sepolia + Arbitrum Sepolia deployment and verification | 🆕 Not Started |
| M5: Audit & Mainnet | Security audit, mainnet deployment | 🆕 Not Started |

## Appendix

### Glossary

| Term | Definition |
|------|------------|
| Facet | Individual logic component in Diamond Pattern |
| DFPkg | Diamond Factory Package - bundles facets for deployment |
| CREATE3 | Deterministic address deployment independent of deployer nonce |
| Repo | Storage library with assembly-based slot binding |
| Target | Implementation contract with business logic |
| IFacet | Interface for Diamond facet metadata |

### References

- [EIP-2535: Diamond Standard](https://eips.ethereum.org/EIPS/eip-2535)
- [Crane Framework CLAUDE.md](lib/daosys/lib/crane/CLAUDE.md)
- [Balancer V3 Docs](https://docs.balancer.fi/)
- [CREATE3 Pattern](https://github.com/Vectorized/solady/blob/main/src/utils/CREATE3.sol)
- [Permit2](https://github.com/Uniswap/permit2)

### Import Remappings

```
@crane/          -> lib/daosys/lib/crane/
@solady/         -> lib/daosys/lib/crane/lib/solady/src/
@openzeppelin/   -> lib/daosys/lib/crane/lib/openzeppelin-contracts/
@balancer-labs/  -> lib/daosys/lib/crane/lib/balancer-v3-monorepo/pkg/...
forge-std/       -> lib/daosys/lib/crane/lib/forge-std/src/
permit2/         -> lib/daosys/lib/crane/lib/permit2/
```
