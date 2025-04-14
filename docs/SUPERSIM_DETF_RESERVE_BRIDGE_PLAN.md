# Plan: SuperSim Deployment Script + UI Address Loading + Duplicate Pages

**Date**: 2026-03-21  
**Status**: Draft - awaiting user confirmation to proceed

---

## Issue 1: Duplicate Page Errors

### Problem
Next.js App Router detects both `.js` and `.tsx` files for the same route. Next.js cannot resolve which to use, causing duplicate page errors on startup.

### Affected Files
In `frontend/app/`:

| Route | .js file | .tsx file |
|-------|-----------|-----------|
| `/` | `page.js` | `page.tsx` |
| `/batch-swap` | `batch-swap/page.js` | `batch-swap/page.tsx` |
| `/create` | `create/page.js` | `create/page.tsx` |
| `/detf` | `detf/page.js` | `detf/page.tsx` |
| `/detfs` | `detfs/page.js` | `detfs/page.tsx` |
| `/insights` | `insights/page.js` | `insights/page.tsx` |
| `/mint` | `mint/page.js` | `mint/page.tsx` |
| `/portfolio` | `portfolio/page.js` | `portfolio/page.tsx` |
| `/seigniorage` | `seigniorage/page.js` | `seigniorage/page.tsx` |
| `/staking` | `staking/page.js` | `staking/page.tsx` |
| `/swap` | `swap/page.js` | `swap/page.tsx` |
| `/test` | `test/page.js` | `test/page.tsx` |
| `/token-info` | `token-info/page.js` | `token-info/page.tsx` |
| `/vaults` | `vaults/page.js` | `vaults/page.tsx` |

Also root layout and providers:
- `layout.js` / `layout.tsx`
- `providers.js` / `providers.tsx`

### Root Cause
Both `.js` and `.tsx` files exist for the same routes. Next.js App Router does not allow this.

### Solution Options

**Option A: Delete all .js files (keep .tsx)**
- Recommended if `.tsx` files have more complete TypeScript implementations
- Safer since TypeScript provides type safety
- Delete 16 .js files

**Option B: Delete all .tsx files (keep .js)**
- Only if `.js` files are more current and `.tsx` files are legacy
- Not recommended - TypeScript is project standard

**Option C: Investigate content differences first**
- Read each pair to determine which has better implementation
- More thorough but time-consuming

### Recommended Action
**Option A**: Delete all .js files, keep .tsx. The project uses TypeScript (see `generated.ts`, `tsconfig.json` references), so `.tsx` is the canonical format.

### Files to Delete (14 page .js files + 2 root .js files)
```bash
# Root files
rm frontend/app/page.js
rm frontend/app/layout.js
rm frontend/app/providers.js

# Subdirectory pages
rm frontend/app/batch-swap/page.js
rm frontend/app/create/page.js
rm frontend/app/detf/page.js
rm frontend/app/detfs/page.js
rm frontend/app/insights/page.js
rm frontend/app/mint/page.js
rm frontend/app/portfolio/page.js
rm frontend/app/seigniorage/page.js
rm frontend/app/staking/page.js
rm frontend/app/swap/page.js
rm frontend/app/test/page.js
rm frontend/app/token-info/page.js
rm frontend/app/vaults/page.js
```

---

## Issue 2: SuperSim Deployment Script for DETF Reserve Bridging

### Context
The repository already has comprehensive SuperSim deployment infrastructure:
- `scripts/foundry/supersim/deploy_mainnet_bridge_ui.sh` - main orchestrator
- `scripts/foundry/supersim/Script_24_DeploySuperchainBridgeInfra.s.sol` - deploys bridge infra
- `scripts/foundry/supersim/Script_25_ConfigureProtocolDetfBridge.s.sol` - configures DETF bridge

### Existing Flow (from deploy_mainnet_bridge_ui.sh)
1. Starts SuperSim (or reuses running instance)
2. Deploys Ethereum Sepolia contracts via `Script_DeployAll.s.sol`
3. Deploys Base Sepolia contracts via `Script_DeployAll.s.sol`
4. Deploys Superchain bridge infra on both chains (`Script_24`)
5. Configures Superchain bridge on both chains (`Script_25`)
6. Exports frontend artifacts

### What "Protocol DETF Reserve Bridging" Tests
The reserve bridging flow (`bridgeRichir` / `receiveBridgedRich`):
1. User calls `DETF.bridgeRichir()` on source chain
2. RICHIR shares are burned locally
3. Reserve pool exits to BPT, then to RICH
4. RICH is bridged via `StandardBridge.bridgeERC20To()` to peer chain
5. Cross-chain message sent via `CrossDomainMessenger` to peer relayer
6. On destination, relayer calls `DETF.receiveBridgedRich()`
7. RICH is deposited into `richChirVault`, shares added to reserve pool
8. RICHIR minted to recipient

### Required SuperSim Components for Reserve Bridging Test

**Per Chain:**
- DETF proxy (IProtocolDETF) with:
  - CHIR, RICH, RICHIR tokens
  - Reserve pool (80/20 Balancer pool with BPT)
  - Protocol NFT vault with initial shares
  - `chirWethVault` and `richChirVault`
- SuperChainBridgeTokenRegistry (register remote tokens)
- StandardBridge (bridge ERC20 RICH to peer)
- CrossDomainMessenger (send relay message to peer relayer)
- Configured localRelayer address

**Configuration:**
- `DETF.initBridge(InitData)` called with bridge repo config
- Registry entries for DETF↔remoteDETF and RICH↔remoteRICH tokens

### Existing Scripts to Use
1. **Script_24_DeploySuperchainBridgeInfra** - deploys bridge infra (registry, relayer)
2. **Script_25_ConfigureProtocolDetfBridge** - wires DETF to bridge repo

### New Script Needed: Script_26_TestProtocolDetfReserveBridge

**Purpose**: Deploy test DETF instances with initialized reserve pools and execute bridge flow tests.

**Location**: `scripts/foundry/supersim/Script_26_TestProtocolDetfReserveBridge.s.sol`

**What it should do**:
1. Deploy a test DETF with initialized reserve pool
2. Seed the reserve pool with liquidity (BPT)
3. Set up protocol NFT with initial shares
4. Execute `bridgeRichir` flow
5. Simulate `receiveBridgedRich` on peer chain
6. Verify balances and token amounts

**Reference files**:
- `test/foundry/spec/vaults/protocol/ProtocolDETFRichBridge_Superchain.t.sol` - existing superchain test
- `test/foundry/spec/vaults/protocol/ProtocolDETFRichBridge_UnitTestBase.t.sol` - unit test base

**Integration with existing shell wrapper**:
Add `run_reserve_bridge_script()` function to `deploy_mainnet_bridge_ui.sh`:
```bash
run_reserve_bridge_script() {
  local rpc_url="$1"
  local out_dir="$2"
  local remote_out_dir="$3"
  
  SENDER="$DEPLOYER_ADDRESS" \
  OUT_DIR_OVERRIDE="$out_dir" \
  REMOTE_OUT_DIR="$remote_out_dir" \
    run_forge_script "scripts/foundry/supersim/Script_26_TestProtocolDetfReserveBridge.s.sol:Script_26_TestProtocolDetfReserveBridge" "$rpc_url"
}
```

---

## Issue 3: UI Address Loading Update

### Current Architecture

**Build-time static loading**:
- `frontend/app/addresses/index.ts` - ARTIFACT_REGISTRY, imports JSON per environment at build time
- `frontend/app/addresses/supersim_sepolia/` - JSON artifacts for SuperSim

**Runtime resolution**:
- `frontend/app/lib/addressArtifacts.ts`:
  - `resolveArtifactsChainId()` - maps chain IDs for environments
  - `getAddressArtifacts()` - returns ArtifactBundle synchronously
  - `setDefaultDeploymentEnvironment()` / `getDefaultDeploymentEnvironment()`
- Module-level `defaultDeploymentEnvironment` variable acts as global default

**Environment toggle**:
- `frontend/app/lib/deploymentEnvironment.tsx` - React context, toggle UI, localStorage persistence
- Key: `indexedex:deployment-environment`

**Wagmi alignment**:
- `frontend/app/providers.tsx`:
  - Reads localStorage on mount
  - Sets wagmi transports based on environment
  - `supersim_sepolia` → uses local RPC URLs

**Consumers**:
- Pages call `getAddressArtifacts(resolvedChainId)` synchronously
- Probe on-chain bytecode to verify deployment
- Examples: `swap/page.tsx`, `batch-swap/page.tsx`, `token-info/page.tsx`, `mint/page.tsx`

### Problem with Current System
- Artifacts are **static at build time** - no runtime addition/updating
- No mechanism to add custom addresses or load from external sources
- Changes require rebuild and redeploy

### Proposed New Address Loading Process

**Goal**: Enable runtime addition and loading of addresses without rebuild.

**New Components**:

1. **Runtime Artifact Registry** (`frontend/app/lib/runtimeArtifactRegistry.ts`)
   - `registerArtifactBundle(environment, chainId, bundle)` 
   - `getRuntimeArtifactBundle(environment, chainId)` 
   - `clearRuntimeOverrides()`
   - Merge runtime overrides with static ARTIFACT_REGISTRY

2. **Address Artifacts Hook** (`frontend/app/lib/useAddressArtifacts.ts`)
   - React hook wrapping `getAddressArtifacts`
   - Reads from runtime registry first, falls back to static
   - Triggers re-render on environment changes

3. **Address Upload/Dialog Component** (`frontend/app/components/AddressManager.tsx`)
   - UI to add custom addresses
   - JSON upload or manual entry
   - Saves to localStorage runtime registry

4. **Updated Providers** (`frontend/app/providers.tsx`)
   - Load runtime artifacts from localStorage on mount
   - Register them with runtime registry
   - Continue setting wagmi transports as before

### Implementation Steps

**Step 1**: Modify `addressArtifacts.ts`
- Add `runtimeOverrides: Map<string, ArtifactBundle>` 
- Update `getAddressArtifacts()` to check runtimeOverrides first
- Add `registerArtifactBundle()`, `clearRuntimeOverrides()`

**Step 2**: Create `useAddressArtifacts.ts` hook
```typescript
export function useAddressArtifacts(chainId: number) {
  const { environment } = useDeploymentEnvironment();
  const bundle = useMemo(() => 
    getAddressArtifacts(chainId, environment), 
    [chainId, environment]
  );
  return bundle;
}
```

**Step 3**: Create `AddressManager` component
- Modal/dialog for address entry
- JSON file upload
- Form fields for platform.* addresses
- Persist to localStorage

**Step 4**: Update `providers.tsx`
- On mount, load runtime artifacts from localStorage
- Register with `registerArtifactBundle()`

**Step 5**: Update consumer pages
- Replace `getAddressArtifacts()` calls with `useAddressArtifacts()` hook
- Start with `swap/page.tsx` as example

### Files to Create/Modify

| File | Action |
|------|--------|
| `frontend/app/lib/addressArtifacts.ts` | Modify - add runtime registry |
| `frontend/app/lib/useAddressArtifacts.ts` | Create - new hook |
| `frontend/app/components/AddressManager.tsx` | Create - new component |
| `frontend/app/providers.tsx` | Modify - load runtime artifacts |
| `frontend/app/swap/page.tsx` | Modify - use new hook |
| `frontend/app/lib/deploymentEnvironment.tsx` | Possibly extend |

---

## Summary of Actions

### 1. Fix Duplicate Pages
- [ ] Delete 16 `.js` files, keep `.tsx` versions
- [ ] Verify UI starts without duplicate page errors

### 2. SuperSim Deployment Script
- [ ] Create `Script_26_TestProtocolDetfReserveBridge.s.sol`
- [ ] Add `run_reserve_bridge_script()` to `deploy_mainnet_bridge_ui.sh`
- [ ] Test deployment runs successfully

### 3. UI Address Loading
- [ ] Modify `addressArtifacts.ts` for runtime registry
- [ ] Create `useAddressArtifacts.ts` hook
- [ ] Create `AddressManager.tsx` component
- [ ] Update `providers.tsx` for runtime loading
- [ ] Update `swap/page.tsx` as example consumer

---

## Dependencies
- SuperSim script depends on: existing Script_24, Script_25 infrastructure
- UI address loading is independent of SuperSim script work

## Next Steps
1. User confirms plan direction
2. Begin implementation (suggest starting with duplicate page fix as it's blocking)
3. Test each piece incrementally
