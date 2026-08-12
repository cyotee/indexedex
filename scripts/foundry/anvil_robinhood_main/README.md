# Anvil Robinhood mainnet fork — lab vaults/hooks/DETFs **+ fee-DETF (CHIR)**

**Chain id:** `4663` (Robinhood mainnet fork via Anvil)  
**PRD (lab):** `docs/ANVIL_ROBINHOOD_UNISWAP_V4_DETF_DEPLOY_PRD.md`  
**Fee-DETF product:** `docs/ROBINHOOD_PONS_SINGLE_SE_DETF_LAUNCH_TEST_SCENARIO_PRD.md`  
**UI runbook:** [`docs/ANVIL_ROBINHOOD_UI_AGENT_RUNBOOK.md`](../../../docs/ANVIL_ROBINHOOD_UI_AGENT_RUNBOOK.md)

This pipeline is the **unified** local stack:

1. **Lab path (stages 00–13)** — TT0–TT7, Uni V3/V4 SE, hooks, inert CP/Orbital/Weighted DETFs  
2. **Fee-DETF path (stages 14–21)** — pons RICH → Uni V3 SE → Buffer CP hook + **CHIR** (scripted first bond → live)  
3. **Export (stage 22)** — single `chain/4663` artifact set for the DTF UI  

Standalone `anvil_robinhood_fee_detf/` remains available for a fee-only deploy; prefer **this** tree when testing lab + staking + fee accrual together.

## Operator command

```bash
DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  bash scripts/shell/anvil_robinhood_main.sh all --restart-anvil
# wait for: [SUCCESS] Command 'all' completed
```

Resume fee-DETF only (after foundation + stage 11 children exist):

```bash
bash scripts/shell/anvil_robinhood_main.sh fee-detf
bash scripts/shell/anvil_robinhood_main.sh export
```

## Accounts

| Role | Address |
|------|---------|
| Deployer / bond actor (Anvil #0) | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` |
| UI wallet (Anvil #1) | `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` |

## Stages

| Stage | Script | Notes |
|-------|--------|--------|
| 00–03 | Preflight / Crane / IndexedEx core / hook factory | Shared foundation |
| 04–09 | TT0–TT7, Uni pools, SE, rate providers | Lab assets |
| 10–12 | Hook pkgs, DETF children, DETF pkgs | Children reused by fee-DETF |
| 13 | Inert demos | **No** scripted bond on lab DETFs |
| **14** | Pons launch RICH | Fee-DETF path starts |
| **15** | Uni V3 SE on RICH/WETH | |
| **16** | Rate provider SE→WETH | |
| **17** | Buffer CP hook + CHIR DETF packages | Uses `11_detf_children.json` |
| **18** | CHIR instance (inert) | |
| **19** | Large RICH market buy | Depth for SE mid |
| **20** | WETH first bond → **live** | Fee-DETF becomes live |
| **21** | Fund UI wallet ETH | |
| **22** | Frontend `chain/4663` | Lab + CHIR + featured-fee-detfs |

Artifacts: `deployments/anvil_robinhood_main/`  
Frontend: `frontend/packages/protocol/src/addresses/chain/4663/`

## Product notes

- Uni V3/V4 cores are **Robinhood-canonical** (`ROBINHOOD_MAIN`); never redeployed.  
- Lab DETFs stay **inert** until UI first bond.  
- **CHIR** is first-bonded by stage 20 (feeRecipient NFT path for protocol fees on the fee-DETF).  
- Fees on **strategy SE vaults** still route via **FeeCollector** / fee oracle; product seigniorage on CHIR uses the DETF fee-recipient bond NFT.  
- Env overrides for fee path (see `FixtureEconomics.sol`):
  - `CREATION_PAIR_PER_DETF_WAD` — peg rate (default 10e18 WETH/CHIR), not launch capital
  - `FIRST_BOND_WETH` — minimal first bond (default **0.1 ether**); S scales with supply → keep small
  - `LAUNCH_BUDGET_WETH` — soft total for bond + pair-only seed (default **2 ether**)
  - `LAUNCH_RICH_TARGET_SYNTHETIC_WAD` — target S (default **10e18**)
  - `LAUNCH_RICH_SEED_STEP_WETH` / `LAUNCH_RICH_SEED_MAX_WETH` — fine seed / hard seed cap
  - `LARGE_RICH_BUY_WETH` — pons market buy depth (stage 19; separate from DETF open)

## UI

1. Wallet RPC → `http://127.0.0.1:8545`, chain id **4663**  
2. Import Anvil **#1** (or e2e inject #0)  
3. `getAddressArtifacts(4663)` — **featured fee DETF = CHIR**; protocol-detfs also lists lab DETFs  
4. `/staking?detf=<chir>` for fee-DETF; Earn for strategy SE vaults; lab DETFs for first-bond experiments  
5. DTF e2e: skill `indexedex-ui-tx-testing` / `npm run test:e2e:dtf:live`
