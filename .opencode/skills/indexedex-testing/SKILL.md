---
name: indexedex-testing
description: This skill should be used when writing or reviewing IndexedEx Foundry tests, TestBases, mocks, vm.mockCall, IndexedexTest, vault DFPkg deploy, Standard Exchange tests, DETF tests, fork tests, or when an agent is tempted to mock vaults/manager/registry. Prefer production code over mocks.
license: MIT
---

# IndexedEx Testing Patterns

IndexedEx layers a **vault registry + manager** on Crane. Tests must use the same deploy paths as production and **prefer production code over mocks**.

**Read first:**

1. `lib/crane/AGENTS.md` and **canonical** `lib/crane/.claude/skills/crane-testing/` (production-first + LR-7).
2. `lib/crane/.claude/skills/crane-deployment/` (CREATE3, DFPkg, factories).
3. This skill + repo root `AGENTS.md`.

Generic Foundry skills (`forge-testing` mock sections) are **subordinate** to Crane + this skill.

## Production-first (IndexedEx)

### Ladder

1. Deploy **real** facets via `create3Factory` + `*FactoryService` / `*_Component_FactoryService`.
2. Deploy **core** packages (manager, fee collector) like `IndexedexTest` (Crane path).
3. Deploy **vault / Standard Exchange / DETF** DFPkgs via **`indexedexManager.deploy*DFPkg(...)`** (registry path), then `deployVault` / manager `deployVault`.
4. Inherit existing TestBases before inventing setup.
5. External protocols: Crane protocol ports (hermetic) or `test/foundry/fork/**` (live). Do not invent DEX/lending mocks when a TestBase exists.
6. Non-SUT doubles only: mintable ERC20, reentrancy token, etc.
7. `vm.mockCall` / `Mock*` only as last resort for **non-SUT** isolation — **never** for facets, DFPkgs, vaults, manager, fee oracle, or vault registry under test.

**Prefer real Standard Exchange vaults over `MockStandardExchange` for new work.**

### Forbidden

```solidity
// WRONG — mock SUT
MockStandardExchange se = new MockStandardExchange(...);
vm.mockCall(address(vault), ..., ...);

// WRONG — bypass factories / registry
SomeFacet f = new SomeFacet();
SomeDFPkg p = new SomeDFPkg(init);
diamondPackageFactory.deploy(IDiamondFactoryPackage(vaultPkg), args); // registered vault DFPkg
```

```solidity
// RIGHT — factory + registry path (see gold TestBases)
camelotV2InFacet = create3Factory.deployCamelotV2StandardExchangeInFacet();
vm.prank(owner);
pkg = indexedexManager.deployCamelotV2StandardExchangeDFPkg(pkgInit);
vault = pkg.deployVault(asset); // or indexedexManager.deployVault(...)
```

## Inheritance chain

```
CraneTest                         # create3Factory + diamondPackageFactory (InitDevService)
  └── IndexedexTest               # fee collector + indexedexManager + operator wiring
        └── TestBase_VaultComponents   # shared vault ERC20/ERC4626/multi-asset facets
              └── TestBase_*StandardExchange / protocol base
                    └── YourSpec.t.sol
```

Fork tests often combine `IndexedexTest` / vault components with `TestBase_*Fork` and network constants (e.g. Base main).

**Always call parent `setUp()` in the correct override order** (explicit parent names when multiple bases).

## Gold TestBases (copy these patterns)

| Base | Path | Notes |
|------|------|--------|
| Core stack | `contracts/test/IndexedexTest.sol` | Manager + fee collector via factories |
| Vault facets | `contracts/vaults/TestBase_VaultComponents.sol` | Shared vault components |
| Camelot SE | `contracts/protocols/dexes/camelot/v2/TestBase_CamelotV2StandardExchange.sol` | In/Out facets + `deployCamelotV2StandardExchangeDFPkg` |
| Aave Stata SE | `contracts/test/bases/TestBase_AaveV3StataStandardExchange.sol` | Registry path for lending SE |
| Aerodrome SE | `contracts/protocols/dexes/aerodrome/v1/TestBase_AerodromeStandardExchange.sol` | Same pattern as Camelot |
| Dual-liquidity (fork) | `test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol` | Full production deploy on Base fork |

## Two deploy paths (critical)

### 1. Pure Crane (facets + non-vault packages)

- Facets: `create3Factory.deploy*Facet()` via FactoryService.
- Generic DFPkgs: `create3Factory.deployPackageWithArgs(...)`.
- Instances: `diamondPackageFactory.deploy(pkg, args)` or package helper.

Used in `IndexedexTest` for fee collector + manager package construction.

### 2. IndexedEx vault package path

- Facets still via `create3Factory`.
- **DFPkg must** go through manager:

```solidity
vm.prank(owner);
myVaultDFPkg = indexedexManager.deployCamelotV2StandardExchangeDFPkg(pkgInit);
// deployAaveV3Stata..., deployUniswapV4..., DualLiquidity Component_FactoryService, etc.
```

- Instance:

```solidity
// Often:
vault = myVaultDFPkg.deployVault(...);
// Or:
vault = indexedexManager.deployVault(IStandardVaultPkg(address(pkg)), abi.encode(pkgArgs));
```

Why: registry discovery (`vaultsOfToken` / `vaultsOfType`), authorization, fee oracle + manager wiring.

## Directory layout

```
contracts/                 # Production + TestBase_* next to features
contracts/test/            # IndexedexTest, shared bases, rare harness stubs
test/foundry/spec/         # Hermetic / unit / integration / invariant / comparative
test/foundry/fork/         # Live-network forks (base_main, eth_main, ...)
lib/crane/                 # Crane (canonical crane-* skills under lib/crane/.claude/skills/)
```

## Before writing a mock

1. Search for `TestBase_*` and `*_FactoryService` for the feature.
2. Check gold bases in the table above.
3. If only need a token: use mintable ERC20 / `ERC20PermitMintableStub`, not a mock vault.
4. If only need a failure mode: reentrancy token or controlled caller — keep SUT real.
5. Only then consider `vm.mockCall` on a **non-SUT** dependency, and document why.

## Spec vs fork

| Mode | When | How |
|------|------|-----|
| **Hermetic / spec** | Fast unit + integration without RPC | Crane protocol ports + factories + IndexedexTest |
| **Fork** | Live pools, mainnet state, parity | `vm.createSelectFork` + network constants + same factory/registry path for *IndexedEx* deploys |

Do not mix live addresses with hermetic protocol ports in one base without an explicit mode.

## Assertions & Behaviors

- Prefer exact `assertEq` / deltas (Crane LR-7), not “something changed”.
- Facet/package declaration: use Crane `Behavior_*` + control virtuals where applicable.
- Preview/execute parity for vault exchange paths when the feature has preview functions.

## Anti-pattern checklist

- [ ] No `new` for IndexedEx/Crane facets or vault DFPkgs under test
- [ ] Vault DFPkg via `indexedexManager.deploy*DFPkg` (or Component_FactoryService registry helper), not raw diamond factory alone
- [ ] No mock of manager / registry / vault / SE package under test
- [ ] Parent `setUp()` called; factories non-zero before deploy
- [ ] PkgInit uses real facet addresses (never `address(0)`)
- [ ] `PkgInit` / `PkgArgs` defined on the **interface**, not the contract (Crane rule)
- [ ] **Facet surface:** `controlFacetFuncs` from Target/product interface; every product selector on live proxy after registry deploy
- [ ] **Trust flags:** negative tests for `pretransferred=true` without transfer (vault already funded) — not only happy path
- [ ] Inbound credit uses measured **delta**, not absolute balance + claimed amount

## Mandatory negative paths (SE / vault / DETF)

When implementing or reviewing tests for any path that mints shares or credits deposits:

| Case | Assert |
|------|--------|
| `pretransferred=true`, no tokens sent, vault holds inventory | Revert **or** zero shares minted; attacker product balance unchanged |
| `pretransferred=true`, short delivery | Exact transfer-not-received / insufficient selector |
| Donation then deposit | No free mint from donation (or documented beneficiary + no victim loss) |
| Product fn only on Target/Facet impl | Must also succeed on **deployed vault/DETF proxy** |

Happy-path `pretransferred=true` with a real prior `transfer` does **not** cover free-mint from reserves.

Reference: `docs/NEGATIVE_TEST_COVERAGE_REPORT.md`, Crane adversarial **I/J/K**, ship gate `lib/crane/.claude/skills/crane-adversarial-testing/references/implementation-test-dod.md`.

## Related skills

- `crane-testing`, `crane-deployment`, `crane-architecture`, `crane-adversarial-testing` — **canonical** under `lib/crane/.claude/skills/`
- `indexedex-adversarial-testing` — DETF/SE abuse suites + I/J/K extensions
- `indexedex-uniswap-v4-hook-packages` — V4 hook DFPkgs, `deployHookVault`, flag mining (not monomorph CREATE3 hooks)
- `forge-testing` — Foundry cheatcodes only; ignore its mock-first examples for IndexedEx
- `permit2-*` — signature flows; still use real router + Permit2, not mocks
