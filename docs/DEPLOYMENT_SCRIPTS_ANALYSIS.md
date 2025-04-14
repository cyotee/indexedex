# SuperSim Sepolia Deployment Script Analysis

## Overview

`deploy_mainnet_bridge_ui.sh` orchestrates a full cross-chain deployment to a local SuperSim instance simulating Ethereum Sepolia + Base Sepolia. It deploys the complete IndexedEx protocol infrastructure including factories, facets, packages, proxies, DEX integrations (Uniswap V2, Balancer V3, Aerodrome), and the Superchain bridge for cross-L2 communication.

---

## Execution Flow

### Phase 1: Environment Setup (lines 225-231, 596-636)

1. **Create output directories** for both chains and frontend artifacts:
   - `deployments/supersim_sepolia/ethereum/`
   - `deployments/supersim_sepolia/base/`
   - `deployments/supersim_sepolia/shared/`
   - `frontend/app/addresses/supersim_sepolia/{ethereum,base}/`

2. **Resolve RPC sources** - either from explicit env vars or Foundry RPC aliases:
   - `SUPERSIM_RPC_URL_SEPOLIA` / `ETHEREUM_SEPOLIA_RPC_URL` / `FOUNDRY_ETHEREUM_SEPOLIA_RPC_ALIAS` (default: `ethereum_sepolia_alchemy`)
   - `SUPERSIM_RPC_URL_BASE` / `BASE_SEPOLIA_RPC_URL` / `FOUNDRY_BASE_SEPOLIA_RPC_ALIAS` (default: `base_sepolia_alchemy`)

3. **Derive fork height** from Crane network constants (`DEFAULT_FORK_BLOCK`) - must match between Ethereum and Base Sepolia

4. **Start SuperSim** if not running (or reuse existing):
   ```bash
   supersim fork \
     --network=sepolia \
     --chains=base \
     --l1.fork.height=<height> \
     --l1.port=8545 \
     --l2.starting.port=9545 \
     --admin.port=8420 \
     --l1.host=127.0.0.1 \
     --l2.host=127.0.0.1 \
     --logs.directory=<logs_dir> \
     --interop.autorelay
   ```

5. **Wait for both RPC endpoints** (60 second timeout each)

### Phase 2: Broadcast Identity Preparation (lines 641-648)

1. **Impersonate deployer** if not a default Anvil account (`anvil_impersonateAccount`)
2. **Sweep ETH** from 9 default Anvil accounts to `DEPLOYER_ADDRESS` on both forks:
   - Uses `Script_00_SweepEthToDev0.s.sol` via `forge script --broadcast --unlocked --sender <sender>`

### Phase 3: Ethereum Sepolia Deployment (lines 650-665)

Runs `Script_DeployAll` on the Ethereum fork, which executes sequentially:

| Stage | Script | Purpose |
|-------|--------|---------|
| 1 | `Script_01_DeployFactories` | CREATE3 factory, Diamond factory |
| 2 | `Script_02_DeploySharedFacets` | Ownable, Operable, Access facets |
| 3 | `Script_03_DeployCoreProxies` | Fee oracle, Vault registry proxies |
| 4 | `Script_04_DeployDEXPackages_BalancerV3` | Balancer V3 packages |
| 5 | `Script_05_DeployUniswapV2` | Uniswap V2 packages |
| 7 | `Script_07_DeployTestTokens` | Test ERC20 tokens |
| (local) | `Script_04_UniV2PoolsAndVaults` | Uniswap V2 pools + vaults |
| (local) | `Script_05_BalancerPools` | Balancer V3 pools |
| 14 | `Script_14_DeployERC4626PermitVaults` | ERC4626 vaults |
| 15 | `Script_15_DeploySeigniorageDETFS` | Seigniorage DETF tokens |
| 16 | `Script_16_DeployProtocolDETF` | Protocol DETF (Stage 16) |
| (local) | `Script_ExportTokenlists` | Export token lists |

After completion, generates `deployment_summary.json` merging all deployment manifests.

### Phase 4: Base Sepolia Deployment (lines 667-682)

Runs `Script_DeployAll` on the Base fork - significantly more extensive:

| Stage | Script | Purpose |
|-------|--------|---------|
| 1 | `Script_01_DeployFactories` | CREATE3 factory, Diamond factory |
| 2 | `Script_02_DeploySharedFacets` | Ownable, Operable, Access facets |
| 3 | `Script_03_DeployCoreProxies` | Fee oracle, Vault registry proxies |
| 3A | `Script_03A_DeployUniswapV2Core` | Uniswap V2 core (factory, router) |
| 3B | `Script_03B_DeployBalancerV3Core` | Balancer V3 core (Vault, pools) |
| 3C | `Script_03C_DeployAerodromeCore` | Aerodrome core |
| 4 | `Script_04_DeployDEXPackages` | All DEX packages |
| 5 | `Script_05_DeployTestTokens` | Test ERC20 tokens |
| 6 | `Script_06_DeployPools` | Deploy all pools |
| 7 | `Script_07_DeployStrategyVaults` | Strategy vaults |
| 8 | `Script_08_DeployAerodromeStrategyVaults` | Aerodrome-specific vaults |
| 9 | `Script_09_DeployBalancerConstProdPools` | Balancer constant product pools |
| 10 | `Script_10_DepositBaseLiquidity` | Seed initial liquidity |
| 11 | `Script_11_DeployStandardExchangeRateProviders` | Rate providers |
| 12 | `Script_12_DeployBalancerConstProdVaultTokenPools` | Vault token pools |
| 13 | `Script_13_SeedBalancerVaultTokenPoolLiquidity` | Seed vault token pool |
| 14 | `Script_14_DeployERC4626PermitVaults` | ERC4626 vaults |
| 15 | `Script_15_DeploySeigniorageDETFS` | Seigniorage DETFs |
| 16 | `Script_16_DeployProtocolDETF` | Protocol DETF (CHIR) |
| 17 | `Script_17_WethTtcPoolsAndVaults` | WETH/TTC specific |
| 18 | `Script_18_WethTtcBalancerPools` | WETH/TTC Balancer pools |
| (local) | `Script_ExportTokenlists` | Export token lists |

### Phase 5: Superchain Bridge Infrastructure (lines 684-706)

Deploys bridge infrastructure on **both chains** via `Script_24_DeploySuperchainBridgeInfra`:

- `SuperChainBridgeTokenRegistry` - Token registry for bridging
- `ApprovedMessageSenderRegistry` - Approved message senders
- `TokenTransferRelayer` - Relayer for token transfers

Uses Crane factory services with CREATE3 deterministic deployment.

### Phase 6: Bridge Configuration (lines 708-732)

Configures the bridge on **both chains** via `Script_25_ConfigureProtocolDetfBridge`:

On each chain:
1. Registers the remote DETF and richToken in `bridgeTokenRegistry`
2. Approves the peer DETF as sender in `approvedRegistry`
3. Calls `initBridge(bytes)` on the Protocol DETF

Cross-chain configuration reads from each other's deployment manifests (`24_superchain_bridge.json`, `16_protocol_detf.json`).

### Phase 7: Reserve Bridge Testing (lines 734-758)

Tests the DETF reserve bridge via `Script_26_TestProtocolDetfReserveBridge` on both chains.

### Phase 8: Frontend Artifact Export (lines 760-768)

Exports deployment addresses to frontend-readable JSON:

```python
# export_frontend_artifacts.py
- Copies *.tokenlist.json files
- Merges all *.json deployment files into base_deployments.json
- Adds chainId and exportedAt timestamp
- Renames keys: create3Factory→craneFactory, diamondPackageFactory→craneDiamondFactory
```

Output locations:
- `frontend/app/addresses/supersim_sepolia/ethereum/base_deployments.json` (chainId: 11155111)
- `frontend/app/addresses/supersim_sepolia/base/base_deployments.json` (chainId: 84532)

---

## Key Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `DEPLOYER_ADDRESS` | **required** | Unlocked account used as deployment sender |
| `FINAL_RECIPIENT_ADDRESS` | `=DEPLOYER_ADDRESS` | Future sweep recipient (unused in current script) |
| `SUPERSIM_L1_FORK_HEIGHT` | `DEFAULT_FORK_BLOCK` from constants | Fork block number |
| `SUPERSIM_HOST` | `127.0.0.1` | SuperSim host |
| `SUPERSIM_L1_PORT` | `8545` | Ethereum fork RPC port |
| `SUPERSIM_BASE_PORT` | `9545` | Base fork RPC port |
| `SUPERSIM_GAS_ESTIMATE_MULTIPLIER` | `110` | Gas multiplier for Ethereum |
| `SUPERSIM_BASE_GAS_ESTIMATE_MULTIPLIER` | `150` | Gas multiplier for Base (higher due to Aerodrome LP) |
| `SUPERSIM_ETHEREUM_OUT_DIR` | `deployments/supersim_sepolia/ethereum` | Ethereum deployment output |
| `SUPERSIM_BASE_OUT_DIR` | `deployments/supersim_sepolia/base` | Base deployment output |
| `SUPERSIM_SHARED_OUT_DIR` | `deployments/supersim_sepolia/shared` | Shared deployment output |
| `SUPERSIM_FRONTEND_ARTIFACTS_DIR` | `frontend/app/addresses/supersim_sepolia` | Frontend artifact output |

---

## Script Flags

| Flag | Action |
|------|--------|
| `--restart-supersim` | Stop existing SuperSim, start fresh |
| `--kill-supersim` | Stop SuperSim, exit |
| `-v` through `-vvvvv` | Forge verbosity (passed to all forge scripts) |

---

## Key Design Patterns

### 1. Shell Orchestration > Nested Solidity
The wrapper uses direct `forge script` invocations rather than one large Solidity orchestrator. This is more debuggable and allows individual script failures to be isolated.

### 2. Environment-Driven Configuration
Solidity scripts receive configuration via environment variables (`SENDER`, `OUT_DIR_OVERRIDE`, `NETWORK_PROFILE`, `PRIVATE_KEY`). The shell wrapper handles all RPC resolution and identity preparation.

### 3. Cross-Chain State Sharing
Bridge configuration reads deployment manifests from the remote chain's output directory (`REMOTE_OUT_DIR`). This allows each chain's script to access the other's deployed addresses.

### 4. Deterministic Deployment via CREATE3
All contracts use the CREATE3 factory for deterministic addresses across chains. The fork height must match between chains to ensure same addresses.

### 5. Broadcast Identity Handling
- Default Anvil accounts:可直接 broadcast with `--unlocked`
- Non-default accounts: Impersonated via `anvil_impersonateAccount` before broadcasting
- Private key: Used directly if provided

---

## Output Directory Structure

```
deployments/supersim_sepolia/
├── ethereum/
│   ├── chain_manifest.json          # Chain metadata
│   ├── deployment_summary.json      # Merged all deployment JSONs
│   ├── 01_factories.json
│   ├── 02_shared_facets.json
│   ├── ...
│   ├── 16_protocol_detf.json
│   ├── 24_superchain_bridge.json   # Bridge infra
│   ├── 25_superchain_bridge_config.json  # Bridge config
│   └── *.tokenlist.json
├── base/
│   └── (same structure)
└── shared/
    └── (shared state if any)

frontend/app/addresses/supersim_sepolia/
├── ethereum/
│   └── base_deployments.json       # Merged + chainId
└── base/
    └── base_deployments.json       # Merged + chainId
```

---

## Important Constants

From the script (line 330-339), the 9 default Anvil accounts used for ETH sweeping:
```
0x70997970C51812dc3A010C7d01b50e0d17dc79C8
0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
0x90F79bf6EB2c4f870365E785982E1f101E93b906
0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65
0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc
0x976EA74026E726554dB657fA54763abd0C3a0aa9
0x14dC79964da2C08b23698B3D3cc7Ca32193d9955
0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f
0xa0Ee7A142d267C1f36714E4a8F75612F20a79720
```

---

## Gas Multiplier Rationale

- **Ethereum**: `110` - Standard multiplier for Sepolia deployment
- **Base**: `150` - Higher because local Aerodrome LP mint flows underestimate gas on the Base fork during liquidity seeding stages

---

## Related Files

| File | Purpose |
|------|---------|
| `DeploymentBase.sol` | Abstract base providing output directory helpers |
| `SuperSimManifestLib.sol` | Library for manifest paths and file I/O |
| `Script_24_DeploySuperchainBridgeInfra.s.sol` | Bridge infrastructure deployment |
| `Script_25_ConfigureProtocolDetfBridge.s.sol` | Bridge configuration |
| `Script_26_TestProtocolDetfReserveBridge.s.sol` | Reserve bridge testing |
| `export_frontend_artifacts.py` | Frontend artifact export script |
| `scripts/foundry/supersim/ethereum/Script_DeployAll.s.sol` | Ethereum deployment orchestrator |
| `scripts/foundry/supersim/base/Script_DeployAll.s.sol` | Base deployment orchestrator |

---

## Public Sepolia Deployment Plan

### Objective

Create a new set of deployment scripts for the **public Ethereum Sepolia and Base Sepolia testnets** that deploy the same infrastructure as the SuperSim rehearsal, **excluding all WETH-containing pools and vaults**.

### Key Differences from SuperSim Deployment

| Aspect | SuperSim | Public Sepolia |
|--------|----------|----------------|
| RPC | Local SuperSim forks | Public Sepolia RPCs |
| Protocol addresses | Deploy from scratch | Use existing protocol addresses where available |
| ETH funding | Sweep from Anvil accounts | Use real Sepolia ETH from faucets |
| Broadcast identity | `--unlocked` with impersonation | `--private-key` or hardware wallet |
| WETH pools/vaults | Deployed | **Excluded** |
| Deterministic addresses | CREATE3 factory | CREATE3 factory (same pattern) |

### WETH Components to Exclude

**Ethereum Sepolia (from `supersim/ethereum/Script_DeployAll`):**

| Script | WETH Components to Exclude |
|--------|---------------------------|
| `Script_04_UniV2PoolsAndVaults` | `uniWethcPool`, `uniWethcVault`, `_wrapEth()`, `_seedUniVidity()` last line |
| `Script_05_BalancerPools` | `balancerWethcPool`, `balUniWethcWithWeth`, `balUniWethcWithC`, `uniWethcRpWeth`, `uniWethcRpC` |

**Base Sepolia (from `supersim/base/Script_DeployAll`):**

| Script | Action |
|--------|--------|
| `Script_17_WethTtcPoolsAndVaults` | **Exclude entirely** |
| `Script_18_WethTtcBalancerPools` | **Exclude entirely** |

### Implementation Plan

#### Phase 1: Create New Directory Structure

```
scripts/foundry/public_sepolia/
├── deploy_public_sepolia.sh              # Main wrapper script
├── DeploymentBase.sol                     # Base contract with directory helpers
├── SuperSimManifestLib.sol               # Manifest library (reuse from supersim)
├── ethereum/
│   ├── DeploymentBase.sol
│   ├── Script_DeployAll.s.sol            # Orchestrator
│   ├── Script_04_NonWethUniV2PoolsAndVaults.s.sol  # Modified
│   └── Script_05_NonWethBalancerPools.s.sol        # Modified
└── base/
    ├── DeploymentBase.sol
    ├── Script_DeployAll.s.sol            # Orchestrator (no Script_17/18)
    └── [Base-specific scripts reused from anvil_base_main]
```

#### Phase 2: Create Shell Wrapper (`deploy_public_sepolia.sh`)

**Key modifications from `deploy_mainnet_bridge_ui.sh`:**

1. **Remove SuperSim-specific logic:**
   - No `--restart-supersim`, `--kill-supersim` flags
   - No SuperSim startup/shutdown
   - No fork height derivation from constants

2. **Use public RPC endpoints:**
   ```bash
   ETHEREUM_SEPOLIA_RPC_URL="${ETHEREUM_SEPOLIA_RPC_URL:-https://eth-sepolia.public.blastapi.io}"
   BASE_SEPOLIA_RPC_URL="${BASE_SEPOLIA_RPC_URL:-https://base-sepolia.public.blastapi.io}"
   ```

3. **Remove ETH sweeping:**
   - No impersonation needed
   - No sweep script
   - Deployer must have real Sepolia ETH

4. **Broadcast identity:**
   - Use `--sender $DEPLOYER_ADDRESS --unlocked` for deployment
   - User unlocks the keystore locally to keep private key secure

5. **Gas configuration:**
   - Remove `SUPERSIM_GAS_ESTIMATE_MULTIPLIER` (use forge defaults)
   - Keep `SUPERSIM_BASE_GAS_ESTIMATE_MULTIPLIER` if still needed for Base

6. **Output directories:**
   ```bash
   PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR="${PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR:-deployments/public_sepolia/ethereum}"
   PUBLIC_SEPOLIA_BASE_OUT_DIR="${PUBLIC_SEPOLIA_BASE_OUT_DIR:-deployments/public_sepolia/base}"
   PUBLIC_SEPOLIA_SHARED_OUT_DIR="${PUBLIC_SEPOLIA_SHARED_OUT_DIR:-deployments/public_sepolia/shared}"
   ```

**Execution flow:**
```
1. Validate deployer has sufficient ETH balance
2. Run Ethereum deployment via forge script (--sender --unlocked)
3. Run Base deployment via forge script (--sender --unlocked)
4. Deploy Superchain bridge infra on both chains
5. Configure Superchain bridge on both chains
6. Test DETF reserve bridge on both chains
7. Export frontend artifacts
```

**Note:** The `--unlocked` flag requires the deployer's keystore account to be unlocked via `cast wallet unlock --unlocked`. The private key never leaves the local machine.

#### Phase 3: Create Ethereum Deployment Scripts

**Option A: Modify existing supersim scripts**
- Create `Script_04_NonWethUniV2PoolsAndVaults` by copying `Script_04_UniV2PoolsAndVaults` and removing:
  - `uniWethcPool` declaration
  - `uniWethcVault` declaration
  - `_deployPools()` WETH/TTC line
  - `_deployStrategyVaults()` WETH vault line
  - `_wrapEth()` function
  - WETH approval in `_approveRouter()`
  - WETH liquidity in `_seedUniV2()`
  - Export fields for WETH items

**Option B: Create new scripts that exclude WETH from design**
- Preferred for clarity
- Deploy only `abPool`, `acPool`, `bcPool` and their vaults

**For `Script_05_NonWethBalancerPools`:**
- Remove `balancerWethcPool`
- Remove `balUniWethcWithWeth`, `balUniWethcWithC`
- Remove `uniWethcRpWeth`, `uniWethcRpC`
- Remove all WETH-related rate providers and pool initializations

#### Phase 4: Create Base Deployment Scripts

**Reuse existing anvil_base_main scripts directly** since they already don't include WETH-specific pools (those are in supersim-specific `Script_17_*` and `Script_18_*`).

The `Script_DeployAll` for Base public Sepolia should:
1. Import from `anvil_base_main` (same as supersim/base)
2. **Exclude** `Script_17_WethTtcPoolsAndVaults` and `Script_18_WethTtcBalancerPools`
3. Keep all other stages (1-16, plus local stage 18 for tokenlists)

#### Phase 5: Adapt Bridge Infrastructure Scripts

**Script_24_DeploySuperchainBridgeInfra** - Likely no changes needed:
- Reads factories from deployment manifests
- Deploys bridge contracts deterministically
- Works on any chain with sufficient functionality

**Script_25_ConfigureProtocolDetfBridge** - Likely no changes needed:
- Reads local and remote deployment manifests
- Configures cross-chain bridge
- Works as long as both chains are Sepolia/Base

**Script_26_TestProtocolDetfReserveBridge** - Likely no changes needed:
- Tests reserve bridge functionality
- No WETH dependencies expected

#### Phase 6: Update Frontend Artifact Export

**Modify `export_frontend_artifacts.py`** or create new variant:
- Update output directory path pattern: `deployments/public_sepolia/`
- Update chain IDs: Ethereum Sepolia = 11155111, Base Sepolia = 84532
- Same merging logic applies

---

### Implementation Steps

#### Step 1: Create directory structure and base files

- [ ] Create `scripts/foundry/public_sepolia/` directory
- [ ] Copy `DeploymentBase.sol` from `supersim/`
- [ ] Copy `SuperSimManifestLib.sol` from `supersim/` (or create symlink)
- [ ] Create `deploy_public_sepolia.sh` wrapper

#### Step 2: Create Ethereum deployment scripts

- [ ] Create `ethereum/DeploymentBase.sol`
- [ ] Create `ethereum/Script_DeployAll.s.sol`
- [ ] Create `ethereum/Script_04_NonWethUniV2PoolsAndVaults.s.sol`
- [ ] Create `ethereum/Script_05_NonWethBalancerPools.s.sol`

#### Step 3: Create Base deployment scripts

- [ ] Create `base/DeploymentBase.sol`
- [ ] Create `base/Script_DeployAll.s.sol` (reuses anvil_base_main scripts)

#### Step 4: Test Ethereum deployment

- [ ] Run Ethereum deployment with `--dry-run` to verify script compilation
- [ ] Run full Ethereum deployment on public Sepolia
- [ ] Verify deployment manifests are written correctly

#### Step 5: Test Base deployment

- [ ] Run full Base deployment on public Sepolia
- [ ] Verify deployment manifests are written correctly

#### Step 6: Run bridge deployment and configuration

- [ ] Run `Script_24_DeploySuperchainBridgeInfra` on both chains
- [ ] Run `Script_25_ConfigureProtocolDetfBridge` on both chains
- [ ] Run `Script_26_TestProtocolDetfReserveBridge` on both chains

#### Step 7: Export and verify frontend artifacts

- [ ] Run artifact export script
- [ ] Verify `base_deployments.json` files are correct
- [ ] Verify frontend can load the addresses

---

### Environment Variables for Public Sepolia Deployment

| Variable | Required | Default | Purpose |
|----------|----------|---------|---------|
| `DEPLOYER_ADDRESS` | Yes | - | Deployment sender address (keystore must be unlocked) |
| `ETHEREUM_SEPOLIA_RPC_URL` | No | Public RPC | Ethereum Sepolia RPC |
| `BASE_SEPOLIA_RPC_URL` | No | Public RPC | Base Sepolia RPC |
| `PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR` | No | `deployments/public_sepolia/ethereum` | Output directory |
| `PUBLIC_SEPOLIA_BASE_OUT_DIR` | No | `deployments/public_sepolia/base` | Output directory |
| `PUBLIC_SEPOLIA_SHARED_OUT_DIR` | No | `deployments/public_sepolia/shared` | Output directory |
| `PUBLIC_SEPOLIA_FRONTEND_ARTIFACTS_DIR` | No | `frontend/app/addresses/public_sepolia` | Frontend artifacts |

### Files to Create/Modify

#### New Files

| File | Purpose |
|------|---------|
| `scripts/foundry/public_sepolia/deploy_public_sepolia.sh` | Main wrapper script |
| `scripts/foundry/public_sepolia/DeploymentBase.sol` | Base contract for shared logic |
| `scripts/foundry/public_sepolia/ethereum/DeploymentBase.sol` | Ethereum-specific base |
| `scripts/foundry/public_sepolia/ethereum/Script_DeployAll.s.sol` | Ethereum orchestrator |
| `scripts/foundry/public_sepolia/ethereum/Script_04_NonWethUniV2PoolsAndVaults.s.sol` | Non-WETH Uniswap V2 |
| `scripts/foundry/public_sepolia/ethereum/Script_05_NonWethBalancerPools.s.sol` | Non-WETH Balancer |
| `scripts/foundry/public_sepolia/base/DeploymentBase.sol` | Base-specific base |
| `scripts/foundry/public_sepolia/base/Script_DeployAll.s.sol` | Base orchestrator |

#### Files to Reuse (import from anvil_*)

- `Script_01_DeployFactories`
- `Script_02_DeploySharedFacets`
- `Script_03_DeployCoreProxies`
- `Script_04_DeployDEXPackages` / `Script_04_DeployDEXPackages_BalancerV3`
- `Script_05_DeployUniswapV2`
- `Script_07_DeployTestTokens`
- `Script_14_DeployERC4626PermitVaults`
- `Script_15_DeploySeigniorageDETFS`
- `Script_16_DeployProtocolDETF`
- All `anvil_base_main` scripts for Base deployment

---

### Risk Considerations

1. **Public RPC rate limits** - May need to implement retry logic or use premium RPC
2. **Real token interactions** - Test tokens on public Sepolia may have existing liquidity
3. **Sequencing pressure** - Bridge config reads remote manifests; ensure correct order
4. **Gas estimation** - Real testnet gas estimates may differ from SuperSim
