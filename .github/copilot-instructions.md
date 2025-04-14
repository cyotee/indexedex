# Copilot Instructions for AI Coding Agents

Target workspace: the `indexedex` monorepo and its in-repo libraries (found under `lib/`). This file highlights the minimal, high-value knowledge an AI agent needs to be productive here.

## Quick orientation
- Primary project: `indexedex/` (see `indexedex/README.md`) — modular DeFi vault infra using the Diamond Pattern.
- Tooling: Foundry (`forge`) is the canonical tool for compile/test; Node/npm and Hardhat appear for auxiliary scripts and frontend tasks.

## Big-picture architecture (what to know)
- 3-tier Diamond deployment: Facets → Packages → Proxies. Facets are logic units, Packages bundle facets, Proxies are public interfaces.
- Deterministic deployments via CREATE3 factory are required across the repo. Search for `factory().create3` and `Script_Crane`/`Test_Crane` classes for canonical patterns.

## Must-follow conventions (do not deviate)
- NEVER use `new` for contracts. All deployments must be via `factory().create3(...)` (or equivalent factory wrappers). Introducing `new` will break tests and CI.
- Tests must inherit the provided TestBase classes (e.g., `TestBase_IFacet`, `TestBase_Indexedex`, `BetterBalancerV3BasePoolTest`). Follow the IFacet test pattern exactly: implement `facetTestInstance()`, `controlFacetInterfaces()`, and `controlFacetFuncs()`.
- Scripts should follow the `Script_*` pattern and cache per-chain instances (use `chainid` keys as seen in `Script_Crane`).

## Concrete developer workflows (commands to run)
- Setup:
```bash
npm install
git submodule update --init --recursive
forge install
```
- Build & run tests:
```bash
forge build
forge test              # run all tests
forge test -vvv         # verbose
forge test --match-path test/foundry/...   # run a folder
forge test --match-test TestName            # run a single test
```
- Run scripts against local Anvil fork:
```bash
anvil --fork-url <RPC_URL>
forge script scripts/foundry/UI_Dev_Anvil.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

## Integration points & remappings
- In-repo libraries live under `lib/` (e.g., `lib/balancer-v3-monorepo`, `lib/openzeppelin-contracts`). Note: the Crane runtime used by `indexedex` is currently in-repo at `contracts/crane` (not `lib/crane`). Remappings are managed in `remappings.txt` and `foundry.toml` — update both if you add a new in-repo lib.
- Tests and scripts reference `@crane`, `@permit2`, and other remapped names; keep imports consistent with `remappings.txt`.

## Files to inspect for patterns/examples
- `indexedex/README.md` — canonical architecture, CREATE3 rules, testing architecture.
- `test/foundry/` and `contracts/crane/test/...` — canonical IFacet and pool tests. (Crane helpers live at `contracts/crane`.)
- `scripts/foundry/`, `contracts/scripts/` — deployment scripts showing `create3` usage.
- `foundry.toml`, `remappings.txt`, `hardhat.config.ts` — tool configuration and compiler settings.

## Safety checklist for code changes
- No `new` contract deployments in code or scripts.
- Add/modify tests using provided TestBase patterns.
- Update `remappings.txt` and run `forge install` if you add new lib dependencies.
- Run `forge build` and `forge test` locally before opening PRs.

````instructions
# Copilot Instructions for AI Coding Agents

Target workspace: `indexedex/` (monorepo) and its in-repo libs under `lib/` and `contracts/`.

## Quick orientation
- Primary focus: modular DeFi vault infra using the Diamond Pattern (Facets → Packages → Proxies).
- Canonical tooling: Foundry (`forge`) for Solidity build/tests; Node/npm + Hardhat used for scripts/frontend tasks.

## Big-picture architecture (what to know)
- Diamond-style contracts: logic is split into small Facets, grouped into Packages, and exposed via Proxies. Changes often touch multiple facets instead of single large contracts.
- Deterministic deployments: this repo uses a CREATE3-based factory for deterministic addresses. Look for `factory().create3` and factory wrappers in `contracts/` and `scripts/`.

## Project-specific conventions (do not deviate)
- NEVER use `new` to deploy contracts. Always use the project factory (e.g., `factory().create3(...)`) or provided deployment helpers.
- Tests must inherit provided TestBase classes. Typical examples: `TestBase_IFacet`, `TestBase_Indexedex`, `BetterBalancerV3BasePoolTest`. Follow the IFacet test pattern: implement `facetTestInstance()`, `controlFacetInterfaces()`, and `controlFacetFuncs()`.
- Script pattern: name deployment/testing scripts `Script_*` (see `scripts/foundry/Script_Crane.s.sol`). Scripts should cache per-chain instances using `chainid` keys.
- Remappings: keep imports using remapped names (e.g., `@crane`, `@permit2`). If adding an in-repo lib update `remappings.txt` and `foundry.toml` together.

## Concrete developer workflows (commands)
- Setup (one-time):
```bash
npm install
git submodule update --init --recursive
forge install
```
- Build & tests:
```bash
forge build
forge test
forge test -vvv
forge test --match-path test/foundry/...
forge test --match-test TestName
```
- Run scripts locally (example):
```bash
anvil --fork-url <RPC_URL>
forge script scripts/foundry/Script_Crane.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

## Integration points & common paths
- In-repo libs: `lib/` (e.g., `lib/balancer-v3-monorepo`, `lib/openzeppelin-contracts`) and sometimes mirrored under `contracts/` (e.g., `contracts/crane`). Search for `Script_Crane`/`Test_Crane` to find canonical runtime helpers.
- Remappings are declared in `remappings.txt` and `foundry.toml`. Tests and contracts use remapped imports (keep these in sync).

## Useful files to inspect (examples)
- `indexedex/README.md` — architecture, deployment guidelines.
- `foundry.toml`, `remappings.txt` — tool + import remapping rules.
- `scripts/foundry/` — scripted deployments; follow `Script_*` conventions.
- `test/foundry/` and `contracts/crane/test/` — test patterns and TestBase usages.
- Example contract factories: `contracts/protocols/.../factories/` (search for `PoolFactory.sol`) — these show how `create3` and packages are wired.

## Repository specifics (examples from codebase)
- Deterministic factory: see `contracts/factories/create3/Create3Factory.sol`. Always use Crane factory wrappers (CREATE3/CREATE2) for deployments — do not deploy with `new`.
- Package callback & proxy flow: see `contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol` and `contracts/proxies/MinimalDiamondCallBackProxy.sol`. Packages are wired using callback factories and post-deploy hooks (e.g., `contracts/factories/diamondPkg/PostDeployAccountHookFacet.sol`).
- Facet & Package metadata: facets and packages expose metadata used for programmatic wiring. Examples: `contracts/tokens/ERC20/ERC20Facet.sol` and `contracts/tokens/ERC20/ERC20PermitDFPkg.sol` (look for `facetName()`, `facetInterfaces()`, `facetFuncs()`, `packageName()`, `facetAddresses()`).
- Standards & helpers: permit and introspection helpers live in `contracts/tokens/ERC2612/ERC2612Facet.sol`, `contracts/utils/cryptography/ERC5267/ERC5267Facet.sol`, and EIP-712 utilities in `contracts/utils/cryptography/EIP712/EIP712Repo.sol`.
- Common helper repos: ownership/ops and collection patterns are implemented under `contracts/access/` and `contracts/utils/collections/` (e.g., `contracts/access/ERC8023/MultiStepOwnableRepo.sol`, `contracts/utils/collections/sets/AddressSetRepo.sol`, `contracts/utils/BetterEfficientHashLib.sol`).

## Safety checklist before PR
- Do not add direct `new` deployments anywhere.
- Add/modify tests via existing TestBase patterns; keep IFacet tests aligned with examples in `test/foundry/`.
- Update `remappings.txt` and `foundry.toml` if adding in-repo libraries, then run `forge install`.
- Run `forge build` and `forge test` locally before pushing changes.

## When to ask maintainers
- If a change might be a Facet vs Package vs Proxy — ask maintainers; deployment semantics are repository-level policy.
- If you need to change remappings, monorepo layout, or the Crane runtime location — confirm with maintainers.

---
Keep this file short and update when tooling or layout changes. Primary references: `indexedex/README.md`, `foundry.toml`, `remappings.txt`, `test/foundry/`, `scripts/foundry/`.

````
