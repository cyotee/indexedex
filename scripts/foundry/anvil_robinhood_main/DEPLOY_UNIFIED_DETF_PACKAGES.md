# Deploy unified Uni V4 DETF packages on Robinhood main (4663)

This is the runbook for the **package delta** after the hook-based DETF refactor. It is not a full architecture launch.

**Tree:** `scripts/foundry/anvil_robinhood_main/`  
**Chain:** Robinhood Chain mainnet, id **4663**  
**Catalog law:** [`docs/ANVIL_ROBINHOOD_MAIN_ARCHITECTURE_PHASE_STAGE_PRD.md`](../../../docs/ANVIL_ROBINHOOD_MAIN_ARCHITECTURE_PHASE_STAGE_PRD.md)  
**Full catalog / shells:** [`README.md`](./README.md)

This tree still deploys **packages only**. No SE vault instances. No Protocol DETF instances. A later Phase 08 (not in this catalog) deploys an instance from `uniV4DetfPkg` plus a hook after a pons `PoolKey` exists.

---

## What this deploy does

| Stage | Skip key | JSON | Action |
|-------|----------|------|--------|
| 05-03 | `uniV4SePkg` | `phase05_stage03_uniswap_v4_standard_exchange_pkg.json` | Redeploy Uni V4 Standard Exchange DFPkg if bytecode changed |
| 05-05 | `morphoBlueSePkg` | `phase05_stage05_morpho_blue_standard_exchange_pkg.json` | Redeploy Morpho Blue SE DFPkg if bytecode changed |
| 06-01 | `bondNftVaultPkg` | `phase06_stage01_bond_nft_pkg.json` | **Must run.** Replaces common `DETFNFTVaultDFPkg` with `UniswapV4DetfBondNFTVaultDFPkg` (R12a) |
| 06-07 | `uniV4DetfPkg` | `phase06_stage07_uniswap_v4_detf_pkg.json` | **Must run.** New `UniswapV4DetfDFPkg` |
| 09-01 | (none) | rewrite `chain/4663/platform.json` | Always rewrite. No txs |

Removed from the catalog (do not run):

- `Phase_06_Stage_07_CpDetfPkg`
- `Phase_06_Stage_08_WeightedDetfPkg`
- `Phase_06_Stage_10_CurveQuadDetfPkg`

---

## What not to redeploy

Do **not** run Phases **02, 03, or 04**. CREATE3, Diamond Package Factory, Hook Factory, common facets, FeeCollector, and Indexedex Manager stay as they are.

Do **not** run `simulate` after a completed staged deploy on the same Anvil (CREATE3 collision).

Do **not** pass `--force` across the whole catalog from 06-01. `--force` is process-wide. Hook packages (06-03 / 06-04 / 06-06) and rebasing (06-02) use the same CREATE3 salts as the live 4663 packages. Forcing them collides.

Do **not** use `--disable-code-size-limit` on 4663 Anvil or `forge script`. Never `--skip-simulation`. `via_ir` is forbidden.

---

## Skip vs FORCE (read this)

A Stage returns without broadcasting when its JSON skip key is a non-zero address with `code.length > 0`, unless `FORCE=1`.

| Stage | Existing JSON | Without FORCE | With FORCE |
|-------|---------------|---------------|------------|
| 06-01 Bond NFT | Old common NFT address, still has code | **Skips. You keep the wrong package.** | Deploys R12a Bond NFT at a **new** CREATE3 salt (`UniswapV4DetfBondNFTVaultDFPkg`) |
| 06-07 Unified DETF | File `phase06_stage07_uniswap_v4_detf_pkg.json` does not exist yet | **Deploys** (no skip key on disk) | Also deploys |
| 05-03 / 05-05 | Live SE pkg addresses | Skips; keeps current bytecode | Redeploys only if CREATE3 salt changed. Same salt reverts |
| 06-02 / 06-03 / 06-04 / 06-06 | Live packages | Skip (correct) | Likely CREATE3 collision |

FORCE **only** the Stages that would otherwise skip a package you intend to replace. For this delta that is **06-01**. Optionally 05-03 and 05-05 if those SE packages actually changed and their salts allow a new address.

---

## Prerequisites

Factories and IndexedEx core already live on 4663. JSON under `deployments/anvil_robinhood_main/` must already contain:

- `create3Factory`, `diamondPackageFactory`, `hookFactory`
- common facets (`erc20Facet`, `multiAssetBasicVaultFacet`, `multiAssetStandardVaultFacet`, `erc4626BasicVaultFacet`, `erc4626StandardVaultFacet`, …)
- `indexedexManager`, `feeCollector`
- `twapOracle` / `twapOraclePkg` / `twapAdapterFactory` (required by 05-03)

Confirm:

```bash
cast chain-id --rpc-url "$RPC_URL"
# expect 4663
```

First `forge script` compile in a cold or near-cold tree often takes **20–40+ minutes** with little output. Wait for process exit. Do not kill `forge` / `solc`.

---

## Public 4663 (recommended)

Signer is `DEPLOYER_ADDRESS` (cast wallet). No Phase 00.

```bash
export DEPLOYER_ADDRESS=0x...          # must match the IndexedEx owner / deployer
export SENDER="$DEPLOYER_ADDRESS" \
export DEV_ADDRESS="$DEPLOYER_ADDRESS" \
export OWNER="$DEPLOYER_ADDRESS" \
export UI_WALLET="$DEPLOYER_ADDRESS" \
export OUT_DIR_OVERRIDE=deployments/anvil_robinhood_main \
export NETWORK_PROFILE=anvil_robinhood_main \
export CHAIN_ID=4663 \
export RPC_URL="${RPC_URL:-https://rpc.mainnet.chain.robinhood.com}"
```

Each Stage: simulate, then broadcast. Never `--skip-simulation`.

### 1. Optional: Uni V4 SE package

Only if Uni V4 SE bytecode changed and the CREATE3 salt is new (script NatSpec: salts include `wethWrap`).

```bash
FORCE=1 forge script scripts/foundry/anvil_robinhood_main/Phase_05_Stage_03_UniswapV4StandardExchangePkg.s.sol \
  --rpc-url "$RPC_URL" --sender "$DEPLOYER_ADDRESS"
FORCE=1 forge script scripts/foundry/anvil_robinhood_main/Phase_05_Stage_03_UniswapV4StandardExchangePkg.s.sol \
  --rpc-url "$RPC_URL" --sender "$DEPLOYER_ADDRESS" --broadcast --slow --gas-estimate-multiplier 300
```

### 2. Optional: Morpho Blue SE package

Same rule as 05-03.

```bash
FORCE=1 forge script scripts/foundry/anvil_robinhood_main/Phase_05_Stage_05_MorphoBlueStandardExchangePkg.s.sol \
  --rpc-url "$RPC_URL" --sender "$DEPLOYER_ADDRESS"
FORCE=1 forge script scripts/foundry/anvil_robinhood_main/Phase_05_Stage_05_MorphoBlueStandardExchangePkg.s.sol \
  --rpc-url "$RPC_URL" --sender "$DEPLOYER_ADDRESS" --broadcast --slow --gas-estimate-multiplier 300
```

### 3. Required: R12a Bond NFT package

Must FORCE. Existing `bondNftVaultPkg` skip would keep the common NFT.

```bash
FORCE=1 forge script scripts/foundry/anvil_robinhood_main/Phase_06_Stage_01_BondNftPkg.s.sol \
  --rpc-url "$RPC_URL" --sender "$DEPLOYER_ADDRESS"
FORCE=1 forge script scripts/foundry/anvil_robinhood_main/Phase_06_Stage_01_BondNftPkg.s.sol \
  --rpc-url "$RPC_URL" --sender "$DEPLOYER_ADDRESS" --broadcast --slow --gas-estimate-multiplier 300
```

JSON `bondNftVaultPkg` must now be `UniswapV4DetfBondNFTVaultDFPkg`, not `DETFNFTVaultDFPkg`.

### 4. Required: unified DETF package

Do **not** FORCE. New skip file, so it deploys. Needs 06-01 and 06-02 already live.

```bash
forge script scripts/foundry/anvil_robinhood_main/Phase_06_Stage_07_UniswapV4DetfPkg.s.sol \
  --rpc-url "$RPC_URL" --sender "$DEPLOYER_ADDRESS"
forge script scripts/foundry/anvil_robinhood_main/Phase_06_Stage_07_UniswapV4DetfPkg.s.sol \
  --rpc-url "$RPC_URL" --sender "$DEPLOYER_ADDRESS" --broadcast --slow --gas-estimate-multiplier 300
```

### 5. Export frontend artifacts

No txs. Always rewrites.

```bash
forge script scripts/foundry/anvil_robinhood_main/Phase_09_Stage_01_ExportFrontend.s.sol \
  --rpc-url "$RPC_URL" --sender "$DEPLOYER_ADDRESS"
```

Writes:

- `deployments/anvil_robinhood_main/phase09_stage01_export_frontend.json`
- `frontend/packages/protocol/src/addresses/chain/4663/platform.json` (key `uniV4DetfPkg`)

Does **not** overwrite `pons-launch.json`. Does **not** write `cpDetfPkg` / `weightedDetfPkg` / `curveQuadDetfPkg`.

If the DTF app reads 4663 platform JSON, rebuild tokenlists after export:

```bash
cd scripts/node && npm run build-tokenlists
```

The create wizard still looks up `cpDetfPkg` / `weightedDetfPkg` / `curveQuadDetfPkg`. That UI change is separate.

---

## Anvil fork (lab)

EIP-170 **on**. Same Stages, Anvil Dev 0, `--unlocked`.

Do **not** start from Phase 00 / 02. Resume at the first Stage you need:

```bash
# Bond NFT + unified DETF + export. Does not FORCE, so 06-01 will skip unless you
# already cleared bondNftVaultPkg from JSON or you run 06-01 as a single FORCE script (step 3 above).
DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  bash scripts/shell/anvil_robinhood_main.sh all --from-phase 06 --from-stage 07
```

That catalog path from 06-07 is safe: it deploys `uniV4DetfPkg` then Phase 09. It does **not** replace Bond NFT.

To replace Bond NFT on Anvil, run the same FORCE `forge script` for 06-01 as public (RPC `http://127.0.0.1:8545`), then the catalog from 06-07.

---

## Check

```bash
# New Bond NFT package has code
cast code "$(jq -r .bondNftVaultPkg deployments/anvil_robinhood_main/phase06_stage01_bond_nft_pkg.json)" --rpc-url "$RPC_URL" | head -c 20

# Unified DETF package has code
cast code "$(jq -r .uniV4DetfPkg deployments/anvil_robinhood_main/phase06_stage07_uniswap_v4_detf_pkg.json)" --rpc-url "$RPC_URL" | head -c 20

# platform.json has uniV4DetfPkg, not family DETF pkgs
jq '{uniV4DetfPkg, bondNftVaultPkg, uniV4SePkg, morphoBlueSePkg, cpHookPkg, cpDetfPkg}' \
  frontend/packages/protocol/src/addresses/chain/4663/platform.json
```

`cpDetfPkg` should be absent. `uniV4DetfPkg` and `bondNftVaultPkg` must be non-zero with bytecode.

---

## Failure notes

| Symptom | Cause |
|---------|--------|
| 06-01 completes instantly, address unchanged | Skip. Need `FORCE=1` on **that Stage only** |
| CREATE3 revert on 06-03 / 06-04 / 06-06 | You set process-wide `FORCE` and retried an existing salt |
| 06-07 reverts `Phase 06-07: bondNftVaultPkg` | 06-01 still the old package or JSON not rewritten |
| 05-03 reverts `Phase 05-03: twapOracle` | TWAP instance missing; do not redeploy 05-02 unless it is actually gone |
| Compile sits at high CPU for 30+ minutes | Normal first solc. Wait for exit |

Old JSON files `phase06_stage07_cp_detf_pkg.json`, `phase06_stage08_weighted_detf_pkg.json`, and `phase06_stage10_curve_quad_detf_pkg.json` can stay on disk. The catalog no longer reads them.
