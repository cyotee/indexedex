# Anvil Robinhood mainnet fork — Uni V4 DETF + hooks

**Chain id:** `4663` (Robinhood mainnet fork via Anvil)  
**PRD:** `docs/ANVIL_ROBINHOOD_UNISWAP_V4_DETF_DEPLOY_PRD.md`  
**Plan:** `docs/ANVIL_ROBINHOOD_UNISWAP_V4_DETF_DEPLOY_IMPLEMENTATION_AND_TEST_PLAN.md`  
**Agent / UI runbook (full):** [`docs/ANVIL_ROBINHOOD_UI_AGENT_RUNBOOK.md`](../../../docs/ANVIL_ROBINHOOD_UI_AGENT_RUNBOOK.md) — fork via Foundry RPC aliases, deploy, point wallet + frontend at chain 4663.

## Prerequisites

- Foundry (`forge`, `cast`, `anvil`)
- Alchemy key or public RH RPC in `foundry.toml` (`robinhood_mainnet_alchemy` / `robinhood_mainnet`)
- `jq`, `lsof`

## Operator command

```bash
DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  bash scripts/shell/anvil_robinhood_main.sh all --restart-anvil
```

## Accounts

| Role | Address |
|------|---------|
| Deployer (Anvil #0) | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` |
| UI wallet (Anvil #1) | `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` |

## Stages

| Stage | Script | Output |
|-------|--------|--------|
| 00 | Preflight RH pins | `00_preflight.json` |
| 01 | Crane foundation | `01_crane_foundation.json` |
| 02 | IndexedEx core | `02_indexedex_core.json` |
| 03 | Hook diamond factory | `03_hook_factory.json` |
| 04 | TT0–TT7 + mint | `04_test_tokens.json` |
| 05 | Uni V3 pools + seed | `05_univ3_pools.json` |
| 06 | Uni V4 pools + seed | `06_univ4_pools.json` |
| 07 | Uni V3 SE | `07_univ3_se.json` |
| 08 | Uni V4 SE | `08_univ4_se.json` |
| 09 | Rate providers | `09_rate_providers.json` |
| 10 | Hook packages | `10_hook_packages.json` |
| 11 | DETF children | `11_detf_children.json` |
| 12 | DETF packages | `12_detf_packages.json` |
| 13 | Inert demos (no bond) | `13_inert_demos.json` |
| 14 | Frontend `chain/4663` | `14_frontend_export.json` |

Artifacts: `deployments/anvil_robinhood_main/`  
Frontend: `frontend/packages/protocol/src/addresses/chain/4663/`

## Product notes

- **DETFs are inert** after deploy — scripts never call `bond`. First bond is UI-only.
- Uni V3/V4 cores are **Robinhood-canonical** (`ROBINHOOD_MAIN`); never redeployed.
- Weighted Buffer + Weighted DETF are **n=8** with ≥1 V3 SE and ≥1 V4 SE leg.
- Weighted n=8 door seeding may take several minutes and high gas — expect `--slow`.

## UI

1. Wallet RPC → `http://127.0.0.1:8545`, chain id **4663**
2. Import Anvil account #1
3. Load addresses via `@indexedex/protocol` `getAddressArtifacts(4663)`
4. Bond on a gentle DETF in the UI
