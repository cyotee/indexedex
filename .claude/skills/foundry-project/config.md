# Foundry Configuration Reference

Complete foundry.toml configuration options.

## Basic Project Settings

```toml
[profile.default]
# Source directories
src = "src"
test = "test"
script = "script"
out = "out"
libs = ["lib"]
cache_path = "cache"

# Build cache
cache = true
force = false
```

## Solidity Compiler Settings

```toml
[profile.default]
# Compiler version
solc = "0.8.24"
# Or auto-detect
auto_detect_solc = true

# EVM version
evm_version = "cancun"

# Optimizer
optimizer = true
optimizer_runs = 200

# Via IR (for complex optimizations)
via_ir = false

# Extra output
extra_output = ["metadata", "storageLayout"]
extra_output_files = ["abi", "evm.bytecode"]
```

## Optimizer Details

```toml
[profile.default.optimizer_details]
# Enable specific optimizations
peephole = true
inliner = true
jumpdestRemover = true
orderLiterals = true
deduplicate = true
cse = true
constantOptimizer = true
yul = true

[profile.default.optimizer_details.yulDetails]
stackAllocation = true
optimizerSteps = "dhfoDgvulfnTUtnIf"
```

## Model Checker (Formal Verification)

```toml
[profile.default.model_checker]
contracts = { "src/MyContract.sol" = ["MyContract"] }
engine = "chc"
timeout = 10000
targets = ["assert"]
```

## Remappings

```toml
[profile.default]
remappings = [
    "forge-std/=lib/forge-std/src/",
    "@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/",
    "@openzeppelin/contracts-upgradeable/=lib/openzeppelin-contracts-upgradeable/contracts/",
    "solmate/=lib/solmate/src/",
    "solady/=lib/solady/src/"
]
```

## Testing Settings

### Basic Test Config

```toml
[profile.default]
# Test runner
verbosity = 2
ffi = false
sender = "0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38"
tx_origin = "0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38"
initial_balance = "0xffffffffffffffffffffffff"
block_number = 1
chain_id = 31337
gas_limit = 9223372036854775807
gas_price = 0
block_base_fee_per_gas = 0
block_coinbase = "0x0000000000000000000000000000000000000000"
block_timestamp = 1
block_difficulty = 0
block_prevrandao = "0x0000000000000000000000000000000000000000000000000000000000000000"
block_gas_limit = 30000000
```

### Fuzz Testing

```toml
[profile.default.fuzz]
runs = 256
max_test_rejects = 65536
seed = "0x3e8"
dictionary_weight = 40
include_storage = true
include_push_bytes = true
```

### Invariant Testing

```toml
[profile.default.invariant]
runs = 256
depth = 15
fail_on_revert = false
call_override = false
dictionary_weight = 80
include_storage = true
include_push_bytes = true
shrink_run_limit = 5000
```

## Fork Testing

```toml
[profile.default]
# Default fork URL
eth_rpc_url = "https://eth-mainnet.g.alchemy.com/v2/..."

# Fork block
fork_block_number = 18000000

# Fork retry settings
fork_retry_backoff = 3
```

## RPC Endpoints

```toml
[rpc_endpoints]
mainnet = "${MAINNET_RPC_URL}"
sepolia = "${SEPOLIA_RPC_URL}"
goerli = "${GOERLI_RPC_URL}"
arbitrum = "${ARBITRUM_RPC_URL}"
arbitrum_sepolia = "${ARBITRUM_SEPOLIA_RPC_URL}"
optimism = "${OPTIMISM_RPC_URL}"
base = "${BASE_RPC_URL}"
polygon = "${POLYGON_RPC_URL}"
bsc = "${BSC_RPC_URL}"
avalanche = "${AVALANCHE_RPC_URL}"
localhost = "http://localhost:8545"
```

## Etherscan Verification

```toml
[etherscan]
mainnet = { key = "${ETHERSCAN_API_KEY}" }
sepolia = { key = "${ETHERSCAN_API_KEY}" }
goerli = { key = "${ETHERSCAN_API_KEY}" }
arbitrum = { key = "${ARBISCAN_API_KEY}" }
optimism = { key = "${OPTIMISM_ETHERSCAN_API_KEY}" }
base = { key = "${BASESCAN_API_KEY}" }
polygon = { key = "${POLYGONSCAN_API_KEY}" }
bsc = { key = "${BSCSCAN_API_KEY}" }
avalanche = { key = "${SNOWTRACE_API_KEY}" }

# Custom explorer
[etherscan.custom_chain]
key = "${CUSTOM_API_KEY}"
url = "https://api.custom-explorer.io/api"
```

## Formatter Settings

```toml
[fmt]
# Line settings
line_length = 120
tab_width = 4
bracket_spacing = false
int_types = "long"
multiline_func_header = "attributes_first"
quote_style = "double"
number_underscore = "preserve"
single_line_statement_blocks = "preserve"
override_spacing = false
wrap_comments = false
ignore = ["src/legacy/**"]
```

## Documentation

```toml
[doc]
out = "docs"
title = "My Project"
book = "book.toml"
homepage = "README.md"
ignore = ["src/test/**", "src/scripts/**"]
```

## Profiles

### Development Profile

```toml
[profile.default]
optimizer = true
optimizer_runs = 200
```

### CI Profile

```toml
[profile.ci]
optimizer = true
optimizer_runs = 200
fuzz = { runs = 1000 }
invariant = { runs = 500, depth = 20 }
verbosity = 2
```

### Production Profile

```toml
[profile.production]
optimizer = true
optimizer_runs = 10000
via_ir = true
```

### Lite Profile (Fast Compilation)

```toml
[profile.lite]
optimizer = false
via_ir = false
```

### Deep Fuzz Profile

```toml
[profile.deep]
fuzz = { runs = 10000 }
invariant = { runs = 1000, depth = 50 }
```

## Environment Variable Expansion

```toml
[profile.default]
# Environment variables are expanded
eth_rpc_url = "${MAINNET_RPC_URL}"

[rpc_endpoints]
# Can use in any string field
mainnet = "${MAINNET_RPC_URL}"
custom = "https://rpc.example.com/${API_KEY}"
```

## Complete Example

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc = "0.8.24"
evm_version = "cancun"
optimizer = true
optimizer_runs = 200
ffi = false
fs_permissions = [{ access = "read", path = "./config" }]

remappings = [
    "forge-std/=lib/forge-std/src/",
    "@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/",
    "@openzeppelin/contracts-upgradeable/=lib/openzeppelin-contracts-upgradeable/contracts/"
]

[profile.default.fuzz]
runs = 256
max_test_rejects = 65536

[profile.default.invariant]
runs = 256
depth = 15
fail_on_revert = false

[profile.ci]
fuzz = { runs = 1000 }
invariant = { runs = 500, depth = 25 }

[profile.production]
optimizer = true
optimizer_runs = 10000
via_ir = true

[rpc_endpoints]
mainnet = "${MAINNET_RPC_URL}"
sepolia = "${SEPOLIA_RPC_URL}"
arbitrum = "${ARBITRUM_RPC_URL}"
base = "${BASE_RPC_URL}"

[etherscan]
mainnet = { key = "${ETHERSCAN_API_KEY}" }
sepolia = { key = "${ETHERSCAN_API_KEY}" }
arbitrum = { key = "${ARBISCAN_API_KEY}" }
base = { key = "${BASESCAN_API_KEY}" }

[fmt]
line_length = 120
tab_width = 4
bracket_spacing = false
int_types = "long"
quote_style = "double"
```

## CLI Overrides

Most settings can be overridden via CLI flags:

```bash
# Override optimizer
forge build --optimizer-runs 10000

# Override solc version
forge build --use solc:0.8.20

# Override fuzz runs
forge test --fuzz-runs 1000

# Override verbosity
forge test -vvvv
```
