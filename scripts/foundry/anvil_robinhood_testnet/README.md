# Anvil Robinhood Testnet (46630) — live + launch-rich demo

**PRD:** [`docs/ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_PRD.md`](../../../docs/ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_PRD.md) v2.0  
**Plan:** [`docs/ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_IMPLEMENTATION_AND_TEST_PLAN.md`](../../../docs/ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_IMPLEMENTATION_AND_TEST_PLAN.md)

| | Value |
|--|--|
| Chain id | **46630** |
| Fork alias | `robinhood_testnet_alchemy` → fallback `robinhood_testnet` |
| Fork pin (D35) | Crane `ROBINHOOD_TESTNET.DEFAULT_FORK_BLOCK` (override with `ANVIL_FORK_BLOCK_NUMBER`) |
| Anvil flags | `--chain-id 46630 --disable-code-size-limit` |
| Broadcast | localhost only (`http://127.0.0.1:8545`) |
| Artifacts | `deployments/anvil_robinhood_testnet/` |
| Frontend | `frontend/packages/protocol/src/addresses/chain/46630/` |

No Balancer. No pons. No Uni V3. No `vm.warp`. No fee push into `TTRICH-S`.

## Groups

| Group | Script | What |
|-------|--------|------|
| 00 | `Script_00_Preflight.s.sol` | Required RH pins only |
| 01 | `Script_01_Factories.s.sol` | CREATE3, diamond factory, hook factory, shared facets |
| 02 | `Script_02_Platform.s.sol` | FeeCollector, manager, RP pkg, D46/D52/bond terms |
| 03 | `Script_03_UniV4Packages.s.sol` | Uni V4 hook / SE / DETF **packages** (incl. Curve Quad) |
| 04 | `Script_04_Tokens.s.sol` | 13 `TT*` + facade + 1e12 to #0 and #1 |
| 05 | `Script_05_LeafPoolsAndSEs.s.sol` | Five seeded pools + SEs + RPs |
| 06 | `Script_06_LeafDETFs.s.sol` | Four leaf DETFs + first-bond + D47 (`TTNVDA-S`, `TTNVDA-SMH-O`, `TTIDX-Q`, `TTDOL-Q`) |
| 06a–c, 06e | `Script_06a`…`06c`, `06e` | Same work, one leaf each (resume) |
| 06d | `Script_06d_M7W.s.sol` | **Skipped** — `TTM7-W` weighted n=8 dropped from this demo |
| 07 | `Script_07_NestDETFs.s.sol` | `TTBETA-O` + `TTIDX-WRAP` (no `TTNEST-W` / `TTM7-WRAP`) |
| 08 | `Script_08_FeeSink.s.sol` | `TTRICH` + `TTRICH-S` + first-bond + D47 |
| Sim | `Script_SimulateLaunch.s.sol` | **01–08** in one broadcast (mandatory; `all` runs it) |
| 09 | `Script_09_ExportFrontend.s.sol` | `chain/46630/` export (no on-chain txs) |

## One-shot

```bash
export ALCHEMY_KEY=...
export DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

bash scripts/shell/anvil_robinhood_testnet.sh all --restart-anvil
# wait for [SUCCESS]

cast chain-id --rpc-url http://127.0.0.1:8545   # must print 46630
```

`all` / `fresh_deploy.sh` runs `00`–`05`, `06a`–`06c`, `06e`, `Script_06`, `07`, `08`, `Script_SimulateLaunch`, `09`. **`TTM7-W` / `TTNEST-W` / `TTM7-WRAP` are not deployed** (weighted n=8 stalls on this fork).

Replay after reset: `--restart-anvil` then `all` again. Resume one leaf with `stage06a`…`stage06c` or `stage06e`. Each leaf / nest / fee-sink script premines via `UniswapV4DetfHookPremineLib` **before** `startBroadcast` (Foundry otherwise folds `findMineNonce` into `eth_estimateGas`), then `deployVault(args, mineNonce)` (nonce is not in PkgArgs; `0` is a legal nonce), first-bonds, and does **one** closed-form richness deposit.

## Gas estimate (no broadcast)

Anvil must already be 46630:

```bash
forge script scripts/foundry/anvil_robinhood_testnet/Script_SimulateLaunch.s.sol \
  --rpc-url http://127.0.0.1:8545 \
  --sender "$DEV_ADDRESS" \
  --unlocked
# omit --broadcast
```

## DTF (port 3002)

```bash
cd frontend
NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT=anvil_robinhood_testnet \
NEXT_PUBLIC_LOCAL_RPC_URL=http://127.0.0.1:8545 \
npm run dev -w @indexedex/app-dtf
```

Wallet: RPC `http://127.0.0.1:8545`, chain id **46630**, currency ETH.  
Lists the remaining demo DETFs (no Mag7 weighted / nest-W / Mag7 wrap). `/mint` offers the stand-in tokens (not WETH, not faucet stocks).
