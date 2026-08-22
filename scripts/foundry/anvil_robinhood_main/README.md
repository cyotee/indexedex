# Anvil Robinhood mainnet fork — IndexedEx architecture (4663)

**Chain id:** `4663` (Robinhood mainnet fork via Anvil)

These scripts stand up Crane factories, the IndexedEx manager, and the Uni V4 packages needed later to deploy:

- Protocol DETF (constant-product single) from `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single`
- Curve Quad Stable DETF from `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve`

They do **not** deploy test tokens, pools, Standard Exchange vaults, or DETF instances.

Uni V4 PoolManager, PositionManager, Permit2, WETH, and Universal Router are Robinhood-canonical (`ROBINHOOD_MAIN`). They are never redeployed.

## Gas estimate (one Foundry script, no broadcast)

`Script_SimulateArchitecture` runs groups 01–03 inside a single `startBroadcast` / `stopBroadcast` window so `forge script` without `--broadcast` collects one dry-run.

`simulate` is EIP-1559 only: it does **not** pass `--legacy` or `--gas-price`. Anvil is started with the fork-source `baseFee` and `--disable-min-priority-fee`. After the dry-run, the wrapper re-reads **live** 4663 `baseFee` / `maxPriorityFeePerGas` / `eth_gasPrice` from the fork RPC and quotes deployer funding from dry-run **gas limits** × current `eth_gasPrice`, plus `FUND_ETH_BUFFER_BPS` (default 2500 = 25%). Use that quote to fund a live deployer, not Foundry's on-screen ETH total (Anvil's local fee market can still diverge).

```bash
DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  bash scripts/shell/anvil_robinhood_main.sh simulate --restart-anvil
```

`--restart-anvil` forks **public** Robinhood mainnet (`https://rpc.mainnet.chain.robinhood.com`) at the remote tip, chain id 4663. EIP-170 stays on. No stub pins. If the fork RPC cannot start, the command fails. Restarting Anvil is recommended so the node is not carrying a decayed local `baseFee`.

Or call forge directly (no funding quote):

```bash
forge script scripts/foundry/anvil_robinhood_main/Script_SimulateArchitecture.s.sol \
  --rpc-url http://127.0.0.1:8545 \
  --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --unlocked
```

Do not run `simulate` after a completed staged `all` on the same Anvil (CREATE3 / CREATE2 collision).

`simulate` defaults to no broadcast. Pass `--broadcast` only if you want 01–03 sent as one script (still EIP-1559, no forced gas price). Staged `all` still uses legacy 2 gwei on Anvil.

## Staged deploy (broadcast)

```bash
DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  bash scripts/shell/anvil_robinhood_main.sh all --restart-anvil
```

Anvil forks public Robinhood mainnet at the remote tip (`--chain-id 4663`). EIP-170 stays on. Broadcast is localhost-only.

## Groups

| Group | Script | What |
|-------|--------|------|
| 00 | `Script_00_Preflight.s.sol` | Chain 4663 + required V4 / Permit2 / WETH pins |
| 01 | `Script_01_Factories.s.sol` | CREATE3, diamond factory, hook factory, shared facets |
| 02 | `Script_02_Platform.s.sol` | FeeCollector, IndexedexManager, SE rate-provider package, fee/bond defaults |
| 03 | `Script_03_UniV4Packages.s.sol` | Uni V4 SE DFPkg, CP hook + DETF DFPkg, Curve Quad hook + DETF DFPkg, bond NFT + rebasing claim packages. No instances. |
| Sim | `Script_SimulateArchitecture.s.sol` | Groups 01–03 in one script for a gas estimate |

Shell entry: `scripts/shell/anvil_robinhood_main.sh` → `deploy_all.sh`.

Artifacts: `deployments/anvil_robinhood_main/` (`00_preflight.json`, `01_factories.json`, `02_platform.json`, `03_univ4_packages.json`).

## Accounts

| Role | Address |
|------|---------|
| Deployer / owner (Anvil #0) | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` |

Override with `SENDER`, `DEV_ADDRESS`, or `DEPLOYER_ADDRESS`.
