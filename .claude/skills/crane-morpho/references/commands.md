# Morpho path-scoped commands

```bash
# From Crane repo root
export FOUNDRY_PROFILE=morpho_port

forge build

# Blue: upstream + Crane hermetic
forge test --match-path 'test/foundry/spec/protocols/lending/morpho/blue/**' -vv

# MetaMorpho
forge test --match-path 'test/foundry/spec/protocols/lending/morpho/metamorpho/**' -vv

# Forks (needs RPC keys)
forge test --match-path 'test/foundry/fork/ethereum_main/morpho/**' -vv
forge test --match-path 'test/foundry/fork/base_main/morpho/**' -vv
```

Do not claim Morpho work green without path-scoped evidence (or recorded RPC skip with hermetic still green).
