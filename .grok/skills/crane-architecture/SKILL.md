---
name: crane-architecture
description: This skill should be used when the user asks about "facet", "target", "repo", "diamond pattern", "storage slot", "guard function", "DFPkg", "AwareRepo", "Service pattern", "Modifiers", "ERC2535", or needs guidance on Crane's core architectural patterns for building modular, upgradeable smart contracts.
license: MIT
---

# Crane Architecture Patterns

**LR-3 Alignment (Current Standards):** This skill is kept in sync with finalized PRD requirements. All NatSpec/@custom values in examples use **ONLY** entries from `docs/reports/gap/CENTRALLY_COMPUTED_NATSPEC_VALUES.md` (e.g. IFacet: 0x5b6f4d01/0x2ea80826/0x574a4cff/0xf10d7a75; IDiamondPackageCallBackFactory interfaceId 0x949da331 + selectors 0xe97fac05 etc.; IDiamondFactoryPackage 0xabc8b346/0x870d4838/0x70068fcf/0xa4b3ad35; deployCreate3Factory 0x34cb11b5). NatSpec verification requires the dedicated Foundry Script (`forge script scripts/foundry/ComputeNatSpecValues.s.sol --sig "run()" -vvv`), never ad-hoc cast. Storage examples use the ERC1967 form. DFPkg rules (structs on interface), LR-7 full-init/Behavior/declaration-tests, and GitBook-required content (Create3FactoryDFPkg bootstrap, reusable DiamondPackageCallBackFactory, registries, utilities/Sets, test patterns) are explicitly covered. See also AGENTS.md, PRD LR-1/LR-2/LR-3/LR-6/LR-7, `crane-natspec`, `crane-deployment`, `crane-testing`, and `crane-utilities` skills.

Crane is a Diamond-first (ERC2535) Solidity development framework for building modular, upgradeable smart contracts. This skill provides guidance on the core architectural patterns.

## Core Pattern: Facet-Target-Repo

Every feature in Crane follows a three-tier architecture:

| Layer | File Pattern | Purpose |
|-------|--------------|---------|
| **Repo** | `*Repo.sol` | Storage library with assembly-based slot binding. Defines `Storage` struct and dual `_layoutStruct()` functions. No state variables. |
| **Target** | `*Target.sol` | Implementation contract with business logic. Uses Repo for storage access. Inherits interfaces. |
| **Facet** | `*Facet.sol` | Diamond facet. Extends Target and implements `IFacet` for metadata (name, interfaces, selectors). |

### When to Create Each Layer

- **Repo**: Always create first. Contains all storage and internal helper functions.
- **Target**: Create when business logic needs to be shared or tested independently.
- **Facet**: Create when exposing functionality through the Diamond proxy.

## Storage Slot Pattern (ERC1967 Compliant)

All Repos use the Diamond storage pattern (ERC1967-derived) with dual `_layoutStruct()` overloads. Per LR-6, canonical form is:

```solidity
bytes32 internal constant DEFAULT_SLOT = bytes32(uint256(keccak256(abi.encode("your.hierarchical.slot.name"))) - 1);
```

(See `FacetRegistryRepo.sol`, `DiamondFactoryPackageRegistryRepo.sol` etc. for production examples using DEFAULT_SLOT + (keccak-1). Some legacy may still show STORAGE_SLOT; new code and audits use the ERC1967 DEFAULT_SLOT form.)

```solidity
library ExampleRepo {
    bytes32 internal constant DEFAULT_SLOT = bytes32(uint256(keccak256(abi.encode("crane.feature.name"))) - 1);

    struct Storage {
        mapping(address => bool) isOperator;
    }

    // Parameterized version - allows custom slot
    function _layoutStruct(bytes32 slot) internal pure returns (Storage storage layoutStruct) {
        assembly { layoutStruct.slot := slot }
    }

    // Default version - uses DEFAULT_SLOT
    function _layoutStruct() internal pure returns (Storage storage layoutStruct) {
        return _layoutStruct(DEFAULT_SLOT);
    }
}
```

**NatSpec on Slots (per LR-1 + central values process):** Wrap with tags and document; central verification script used for any associated interface selectors.

### Dual Function Overload Pattern

Every Repo function has TWO overloads:

```solidity
// 1. Parameterized: takes Storage as first param
function _isOperator(Storage storage layoutStruct, address query) internal view returns (bool) {
    return layoutStruct.isOperator[query];
}

// 2. Default: calls parameterized with _layoutStruct()
function _isOperator(address query) internal view returns (bool) {
    return _isOperator(_layoutStruct(), query);
}
```

This enables:
- Default usage with standard storage slot
- Custom slot usage for multi-instance patterns
- Composability between Repos

## Guard Functions Pattern

Repos contain `_onlyXxx()` guard functions with access control logic. Modifiers are thin wrappers:

```solidity
// In Repo - contains the actual check logic
function _onlyOperator(Storage storage layoutStruct) internal view {
    if (!_isOperator(layoutStruct, msg.sender) && !_isFunctionOperator(layoutStruct, msg.sig, msg.sender)) {
        revert IOperable.NotOperator(msg.sender);
    }
}

function _onlyOperator() internal view {
    _onlyOperator(_layoutStruct());
}

// In Modifiers contract - thin delegation wrapper
modifier onlyOperator() {
    OperableRepo._onlyOperator();
    _;
}
```

## Additional Patterns

### Modifiers Contract (`*Modifiers.sol`)

Abstract contracts with reusable modifiers delegating to Repo guards:

```solidity
abstract contract OperableModifiers {
    modifier onlyOperator() {
        OperableRepo._onlyOperator();
        _;
    }
}
```

### Service Library (`*Service.sol`)

Stateless libraries for complex business logic. Use structs to avoid stack-too-deep:

```solidity
library CamelotV2Service {
    struct SwapParams {
        ICamelotV2Router router;
        uint256 amountIn;
        IERC20 tokenIn;
    }

    function _swap(SwapParams memory params) internal { ... }
}
```

### AwareRepo (`*AwareRepo.sol`)

Dependency injection for external contract references (uses ERC1967 DEFAULT_SLOT):

```solidity
library BalancerV3VaultAwareRepo {
    bytes32 internal constant DEFAULT_SLOT = bytes32(uint256(keccak256(abi.encode("protocols.dexes.balancer.v3.vault.aware"))) - 1);

    struct Storage {
        IVault balancerV3Vault;
    }

    function _initialize(IVault vault) internal { _layoutStruct().balancerV3Vault = vault; }
    function _balancerV3Vault() internal view returns (IVault) { return _layoutStruct().balancerV3Vault; }
}
```

### Diamond Factory Package (`*DFPkg.sol`)

Bundles facets into deployable packages (see `IDiamondFactoryPackage`).

**Critical Rule (LR-1/DFPkg, very common mistake)**: `PkgInit` and `PkgArgs` structs **MUST** be defined inside the `I*DFPkg` **interface**, never inside the contract. This enables `IMyDFPkg.PkgInit` typed usage in FactoryServices, tests, and `abi.encode`.

See `references/dfpkg-pattern.md` (in this skill) and AGENTS.md for full details + anti-pattern.

Example (using central NatSpec values from CENTRALLY_COMPUTED_NATSPEC_VALUES.md ONLY):

```solidity
// Interface defines structs
interface IMyDFPkg is IDiamondFactoryPackage {
    struct PkgInit { IFacet myFacet; ... }
    struct PkgArgs { string name; ... }
}

// packageName @custom:selector 0xabc8b346 (central ONLY)
// facetCuts @custom:selector 0xa4b3ad35
// initAccount(bytes) @custom:selector 0x870d4838
// postDeploy(address) @custom:selector 0x70068fcf
// diamondConfig @custom:selector 0x65d375b3
// calcSalt(bytes) @custom:selector 0xd82be56e
contract MyDFPkg is IMyDFPkg, IDiamondFactoryPackage { ... }
```

See the `crane-deployment` skill for FactoryService usage and deployment code.

## IFacet Interface

All facets implement `IFacet` (see contracts/interfaces/IFacet.sol and Behavior_IFacet).

Using ONLY central values from CENTRALLY_COMPUTED_NATSPEC_VALUES.md:

- facetName() : 0x5b6f4d01
- facetInterfaces() : 0x2ea80826
- facetFuncs() : 0x574a4cff
- facetMetadata() : 0xf10d7a75

```solidity
// tag::facetName()[]
// @custom:signature facetName()
// @custom:selector 0x5b6f4d01
function facetName() external view returns (string memory name);
// end::facetName()[]

// similar for others using central ONLY
function facetInterfaces() external view returns (bytes4[] memory interfaces); // 0x2ea80826
function facetFuncs() external view returns (bytes4[] memory funcs); // 0x574a4cff
function facetMetadata() external view returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions); // 0xf10d7a75
```

**LR-7:** Every Facet must be validated via Behavior_IFacet declaration tests that assert these return the expected central-verified values.

## Reusability of DiamondPackageCallBackFactory (LR-2 / LR-4 Required)

Per source (DiamondPackageCallBackFactory.sol NatSpec):

> "Deployed once via Create3Factory (see Create3Factory.diamondPackageFactory()). Safe and intended for reuse by any consumer on any chain."

- Do **NOT** redeploy the Diamond Package Factory per chain or per project.
- Obtain it via: `create3Factory.diamondPackageFactory()` (or CraneTest's `diamondFactory`).
- Interface: `IDiamondPackageCallBackFactory` with `@custom:interfaceid 0x949da331` (from CENTRALLY_COMPUTED_NATSPEC_VALUES.md ONLY).
- Key surface (central values): `deploy(address,bytes) 0xe97fac05`, `calcAddress 0x33a41d70`, `initAccount(address,bytes) 0x8e85783e`, `pkgOfAccount 0x8a648684`, `pkgConfig 0x8072e14e`, `facetCuts 0xa4b3ad35`, `postDeploy 0x70068fcf`, etc.
- Benefits: reuse already-deployed verified code (LR-4 security: avoids agent-induced bugs); save gas (no redeploy bytecode).

See `crane-deployment` skill, docs/deployment/create3.md, docs/deployment/dfpkg.md, and AGENTS.md "Diamond Package Deployment Pattern".

## Deploying Your Own Create3Factory via Package (Chain Bootstrap, LR-2 Required)

Use `Create3FactoryDFPkg` (implements `ICREATE3DFPkg`) to deploy a Create3Factory Diamond for a new chain:

- PkgInit / PkgArgs **on the interface** (see ICREATE3DFPkg in Create3FactoryDFPkg.sol).
- Central values (ONLY from CENTRALLY...): `packageName 0xabc8b346`, `deployCreate3Factory(address) 0x34cb11b5`, `initAccount 0x870d4838`.
- Bootstrap flow (from InitDevService + CraneTest): use canonical facets (via FacetRegistry on initial factory) to construct the Create3 DFPkg, deploy, then call `initFactory()`.
- After, the new `create3Factory` can be used to deploy facets/packages (they auto-register) and the shared `diamondFactory` (DiamondPackageCallBackFactory) for proxies.
- `deployCreate3Factory(owner)` returns the proxy configured with Cut + Ownable + Operable + Registries + Create3 facet + diamond callback factory wired.

See full steps in docs/getting-started.md, docs/deployment/create3.md, Create3FactoryDFPkg.sol, InitDevService.initEnv, and `crane-deployment` skill. This enables per-chain Create3 without redeploying the callback factory.

## Storage Slot Naming Convention

Use hierarchical dot-notation:

| Pattern | Example |
|---------|---------|
| Crane core | `"crane.access.operable"` |
| Protocol integrations | `"protocols.dexes.balancer.v3.vault.aware"` |
| EIP implementations | `"eip.erc.8023"` |
| Registries | `"crane.registries.facets"` (see FacetRegistryRepo DEFAULT_SLOT) |

## Registries (Facet / Package / CallTarget) - Detailed Usage (LR-2 Required)

**Purpose**: On-chain discovery, canonical resolution, and configuration. Core to Crane reuse model (LR-4): deploy facets/packages once via CREATE3, they auto-register, then discover/reuse via queries or `canonical*` instead of hardcoding addresses.

**Population (auto)**: Create3Factory's internal `_deploy*` and `_register*` (called on every `deployFacet` / `deployPackage` etc.):

- FacetRegistryRepo._registerFacet(facet, name, interfaces, functions) — populates by name/interfaces/funcs + allFacets.
- DiamondFactoryPackageRegistryRepo._registerPackage(...) — similar for packages.

**Consumer Interaction** (via IFacetRegistry, IDiamondFactoryPackageRegistry, ICallTarget* on the Create3Factory proxy or registry facets):

- `canonicalFacet(bytes4 interfaceId)` — preferred "official" facet for an interface.
- `facetsOfName(string)`, `facetsOfInterface(bytes4)`, `facetsOfFunction(bytes4)`, `allFacets()`.
- `nameOfFacet`, `interfacesOfFacet`, `functionsOfFacet`.
- Similar for packages: `canonicalPackage`, `packagesOfInterface`, `allPackages`.
- CallTarget registries for default targets per selector/caller (for diamond loupe/forwarding patterns).

Registries are populated during initial dev bootstrap (InitDevService) and any Create3 deploys. Consumers in TestBases often resolve via `IFacetRegistry(address(create3Factory)).canonicalFacet(...)`.

See AGENTS.md (registries), CODEBASE_MAP.md, docs/CODEBASE_MAP.md, docs/deployment/*, Create3Factory.sol _register*, FacetRegistryRepo.sol, and registry IFs. Ties to "deploy once, attach everywhere".

## Utility Library Patterns (Sets, Math, Collections)

Crane provides reusable general utilities (detailed in `crane-utilities` skill + docs/CODEBASE_MAP.md + AGENTS.md):

### Set Libraries + Repos (1-indexed pattern)
- `AddressSet` / `AddressSetRepo`, `Bytes4Set` / `Bytes4SetRepo`, `UInt256SetRepo`, etc.
- Struct: `mapping(value => uint256) indexes;` (0 = absent), `value[] values;` (1-indexed so 0 means "not present").
- Core ops (on Storage/Repo): `_add`, `_remove`, `_contains`, `_index`, `_indexOf`, `_length`, `_values`, `_page` (for pagination).
- Usage inside Repos: e.g. FacetRegistryRepo uses AddressSet for `allFacets`, `facetsOfInterface`, etc. (via `using AddressSetRepo for AddressSet;`).
- In tests/handlers: track seen addresses or selectors for invariants without dups.
- See: contracts/utils/collections/sets/*SetRepo.sol , used in registries, comparators, Behavior libs.

### Other
- Math: `ConstProdUtils` for constant-product AMM quote math (used in DEX services).
- Collections: BetterArrays, BetterAddress, BetterEfficientHashLib.
- Crypto: permit, signatures (cross-ref protocol skills).
- Always prefer these over ad-hoc to enable reuse + consistent Behavior/comparator testing.

See `crane-utilities` skill reference, AGENTS.md "General Utilities", docs/development/testing.md for handler usage of Sets.

## Key Reference Files

For complete implementations, examine these files in the Crane codebase:

- `contracts/access/operable/` - Complete Facet-Target-Repo example (incl. guards, modifiers, NatSpec)
- `contracts/registries/facet/FacetRegistryRepo.sol` - ERC1967 DEFAULT_SLOT + Sets usage + registration
- `contracts/introspection/ERC2535/ERC2535Repo.sol` - Diamond storage management
- `contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol` - Reusable proxy factory (interfaceId 0x949da331)
- `contracts/factories/create3/Create3FactoryDFPkg.sol` + `ICREATE3DFPkg` - Chain bootstrap package (deployCreate3Factory 0x34cb11b5)
- `contracts/access/ERC8023/` - Two-step ownership (EIP-8023) gold standard for NatSpec/tags
- `contracts/factories/create3/Create3Factory.sol` - Auto registry population + CREATE3 + diamondFactory()
- `contracts/test/CraneTest.sol` + `InitDevService.sol` - Correct test initialization
- `contracts/factories/diamondPkg/Behavior_IFacet.sol` + `TestBase_IFacet.sol` - LR-7 Behavior declaration testing
- `contracts/tokens/ERC20/ERC20DFPkg.sol` - DFPkg example (structs on interface)
- `contracts/utils/collections/sets/AddressSetRepo.sol` - Utility set pattern
- `contracts/protocols/dexes/camelot/v2/services/CamelotV2Service.sol` - Service pattern

Also consult: docs/CODEBASE_MAP.md, docs/deployment/*.md, AGENTS.md.

## Testing: Correct Initialization + Behavior Usage (LR-7)

**Full/Correct Init (mandatory):** Never test uninitialized state. Packages must receive real (non-zero) facet addresses. Use `CraneTest` (or inherit) which calls `InitDevService.initEnv` to wire real create3Factory + diamondFactory + canonicals. In setUp, deploy stubs/facets fully before attaching.

**Behavior Libraries (mandatory for interfaces):**
- Use `Behavior_IFacet` (expect_*/hasValid_*/areValid_*) for `facetInterfaces()`/`facetFuncs()` + metadata.
- Use `Behavior_IDiamondFactoryPackage` for pkg decl (facetCuts, packageName, diamondConfig, calcSalt etc.).
- Declaration tests (e.g. in `*.t.sol` or TestBase) assert against control values.
- All examples use central selectors (0x5b6f4d01 etc.).

**Other LR-7:**
- Exact value asserts (deltas, not just "changed").
- `vm.expectEmit` + precise post-state.
- Full init in handlers for fuzz.
- See `crane-testing` skill, AGENTS.md Testing section, docs/development/testing.md, protocol TestBase_* for inheritance (e.g. TestBase_CamelotV2).

**NatSpec on Test Surface:** TestBases/Behaviors/handlers/*.t.sol also carry tags + central @custom when documenting public test API.

## Additional Resources

### Reference Files

For detailed patterns and complete examples:
- **`references/dfpkg-pattern.md`** - Diamond Factory Package pattern in depth (structs rule)
- **`references/factory-service.md`** - FactoryService pattern for deployment (salts, labels, deploy* calls)

### Quick Decision Guide

| Need | Pattern |
|------|---------|
| Storage for a feature | Create `*Repo.sol` (ERC1967 DEFAULT_SLOT) |
| Business logic | Create `*Target.sol` or `*Service.sol` |
| Diamond-exposed functions | Create `*Facet.sol` (implement IFacet with central selectors) |
| External contract reference | Create `*AwareRepo.sol` |
| Reusable access control | Create `*Modifiers.sol` (delegate to Repo _onlyXxx) |
| Deployable package | Create `*DFPkg.sol` (structs in I* interface ONLY) |
| Reusable Diamond proxies | Use shared DiamondPackageCallBackFactory (0x949da331) via Create3 |
| Own Create3 on new chain | Use Create3FactoryDFPkg.deployCreate3Factory (0x34cb11b5) |
| Discovery / reuse of deployed facets | Query registries (canonicalFacet etc.) |
| General collections/sets | Use *Set / *SetRepo (1-indexed) |
| Test setup + validation | Inherit CraneTest; use Behavior_* + declaration tests |
