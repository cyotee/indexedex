# Testing Uniswap V4 Hook Packages

## Contents

- Profile and commands
- TestBase ladder
- What to cover
- Gold files
- Fork notes

## Profile and commands

Default monorepo `forge test` may be stack-heavy; use the narrow profile for factory + hook package work:

```bash
FOUNDRY_PROFILE=hook_factory forge test \
  --match-path 'test/foundry/spec/hooks/uniswap/v4/factory/*' -vv

# Product package suite (add paths as packages land)
FOUNDRY_PROFILE=hook_factory forge test \
  --match-path 'test/foundry/spec/hooks/uniswap/v4/**' -vv
```

Profile definition: `foundry.toml` → `[profile.hook_factory]`.

## TestBase ladder

```text
CraneTest
  └── IndexedexTest
        └── TestBase_UniswapV4HookDiamondPackageCallBackFactory   # factory gold
              └── TestBase_MyHookProduct                           # product setup
                    └── MyHook_*.t.sol
```

Factory TestBase:

- CREATE3 HookFlags facet + factory
- `setHookDiamondPackageFactory` on manager
- Stub package wired with registry for `deployVault`

Path: `test/foundry/spec/hooks/uniswap/v4/factory/TestBase_UniswapV4HookDiamondPackageCallBackFactory.sol`

## Production-first (indexedex-testing)

- Real factory, real registry, real package — **no** mock of SUT.
- Never `new` facets/factory/DFPkg for production path (stub may use CREATE3/`new` only as non-SUT double when intentional).
- Prefer package `deployVault` for product lifecycle tests; factory-direct only for factory isolation (H1–H14 style).

## Minimum coverage for a new hook package

| Area | Assert |
|------|--------|
| Deploy | `deployPkg` + `deployVault(args, mineNonce)` succeeds |
| Registry | `isVault(proxy)`; listed under `vaultsOfPackage` |
| Flags | `uint160(proxy) & FLAG_MASK == requiredHookFlags() & FLAG_MASK` |
| Flags view | Instance `requiredHookFlags()` matches package pure |
| Salt | `calcAddress` == deployed; package address not in salt |
| Idempotent | Second `deployVault` same args/nonce returns same address |
| Immutable | No `diamondCut` after deploy; PostDeploy gone |
| Product | Preview/exec, PoolManager interactions per family PRD |
| Routes | Invalid closed-form reverts with family error |

Factory suite already maps H1–H15; product suites extend with protocol behavior.

## Gold files

| Asset | Path |
|-------|------|
| Stub package + deployVault | `test/.../factory/stubs/UniswapV4HookDiamondFactoryStubPackage.sol` |
| Registry H15 | `test/.../factory/UniswapV4HookDiamondFactory_Registry.t.sol` |
| Factory PRD/plan | `contracts/hooks/uniswap/v4/factory/UNISWAP_V4_*` |

## Fork notes

- FK-style smokes: real RPC when available; skip/opt-in on 429 (see factory `*Fork.t.sol`).
- FK1 Ethereum may require `RUN_ETH_FORK_SMOKE=true`.
- On forks, CREATE3 addresses may collide with live code — prefer hermetic for deploy-path proofs; fork for PoolManager integration.

## Gas

Auto-mine can cost hundreds of millions of gas even for sparse flags. Hermetic suites may include one auto-mine smoke; production and CI product tests should **premine**.
