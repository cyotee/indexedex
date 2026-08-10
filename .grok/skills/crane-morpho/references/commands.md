# Morpho path-scoped commands

```bash
# From Crane repo root
export FOUNDRY_PROFILE=morpho_port

forge build

# Full Morpho suite (profile match_path = "**/morpho/**" — no monorepo Aave/CCA/etc.)
forge test --ffi

# Blue: upstream + Crane hermetic
forge test --match-path 'test/foundry/spec/protocols/lending/morpho/blue/**' -vv

# MetaMorpho
forge test --match-path 'test/foundry/spec/protocols/lending/morpho/metamorpho/**' -vv

# Forks (needs RPC keys)
forge test --match-path 'test/foundry/fork/ethereum_main/morpho/**' -vv
forge test --match-path 'test/foundry/fork/base_main/morpho/**' -vv
```

`morpho_port` compiles Morpho domain into `out_morpho_port` and **only executes** tests under `**/morpho/**`. Bare `forge test` under this profile must not pull Aave/CCA/BC monorepo suites (those need default `out/`).

Do not claim Morpho work green without path-scoped evidence (or recorded RPC skip with hermetic still green).
