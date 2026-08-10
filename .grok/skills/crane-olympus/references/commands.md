# Olympus port — commands & gotchas

## Contents

- [Profile](#profile)
- [Commands](#commands)
- [Quabi / FFI](#quabi--ffi)
- [Gotchas](#gotchas)

## Profile

`[profile.olympus_v3_port]` in repo `foundry.toml`:

| Setting | Value / why |
|---------|-------------|
| `src` | `contracts/protocols/tokens/stable/olympus/v3` |
| `test` | `test/foundry/spec/protocols/tokens/stable/olympus/v3` |
| `out` / `cache_path` | `out_olympus_v3_port` / `cache_olympus_v3_port` |
| `solc` | `0.8.35` (pragma relaxed to `>=` on sources) |
| `optimizer_runs` | `1` (Crane monorepo default; no viaIR) |
| `ffi` | `true` (Quabi) |
| `ast` | `true` (Quabi selectors from artifact AST) |
| OZ remap in profile | v4 primary for bare `@openzeppelin/contracts` |

## Commands

```bash
# From Crane repo root
export FOUNDRY_PROFILE=olympus_v3_port

forge build
forge test
forge test --match-path 'test/foundry/spec/protocols/tokens/stable/olympus/v3/Kernel.t.sol' -vv
forge test --match-test testCorrectness_InitializeKernel -vv
```

Expect on the order of **~740** hermetic tests green for the in-tree suite (count drifts with suite growth).

## Quabi / FFI

Module tests generate “godmode” policies via `ModuleTestFixtureGenerator.generateGodmodeFixture`, which:

1. Shells to `./src/test/lib/quabi/path.sh <Contract>.json` to find the forge artifact under `out_olympus_v3_port`.
2. Shells to `./src/test/lib/quabi/jq.sh` to extract `permissioned` function selectors from **AST**.

Requirements: `jq`, `cast`, scripts executable, rebuild after contract changes so AST is fresh.

Without `ast=true`, godmode fixtures get empty permissions → `Module_PolicyNotPermitted` on mint/burn tests.

## Gotchas

| Issue | Fix |
|-------|-----|
| Suite not found / wrong tree | Export `FOUNDRY_PROFILE=olympus_v3_port` |
| FFI disabled | Profile must have `ffi = true` |
| Godmode permissions empty | `ast = true` + rebuild |
| `TransferHelper` IERC20 conflict with Frax | Keep Uniswap TransferHelper on `openzeppelin-contracts` (not `-v4`) |
| Importing deferred products (bridges, deposits) | Not all upstream modules/policies are in-tree; see `VENDOR.md` exclusions |
| Default monorepo compile of *entire* `contracts/` | Heavy; use scoped profile for Olympus work |
