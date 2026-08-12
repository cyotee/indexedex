# Anvil Robinhood fee-DETF launch (CHIR + pons RICH)

**Chain id:** `4663` (Robinhood mainnet fork via Anvil)  
**Plan:** [`docs/ANVIL_ROBINHOOD_FEE_DETF_LAUNCH_IMPLEMENTATION_AND_TEST_PLAN.md`](../../../docs/ANVIL_ROBINHOOD_FEE_DETF_LAUNCH_IMPLEMENTATION_AND_TEST_PLAN.md)  
**Product PRD:** [`docs/ROBINHOOD_PONS_SINGLE_SE_DETF_LAUNCH_TEST_SCENARIO_PRD.md`](../../../docs/ROBINHOOD_PONS_SINGLE_SE_DETF_LAUNCH_TEST_SCENARIO_PRD.md)

This family remains a **fee-DETF-only** path. For a **unified** stack (lab vaults/hooks/inert DETFs **+** CHIR fee-DETF), prefer:

```bash
bash scripts/shell/anvil_robinhood_main.sh all --restart-anvil
```

(`anvil_robinhood_main` stages 14–22 embed this fee-DETF topology.)

## Topology

```text
pons v1 RICH + Uni V3 pool (RICH ↔ WETH)
  → Uni V3 SE (vaultTokens = RICH, WETH)
  → Buffer CP Hook reserve (CHIR ↔ WETH pool currencies)
  → CHIR fee-DETF (pairToken = WETH, creation ≈ 10 WETH / 1 CHIR)
```

## Operator command

```bash
export ALCHEMY_KEY=...   # or ANVIL_FORK_URL=https://rpc.mainnet.chain.robinhood.com
export DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

bash scripts/shell/anvil_robinhood_fee_detf.sh all --restart-anvil
# wait for: [SUCCESS] Command 'all' completed
```

## Accounts

| Role | Address |
|------|---------|
| Deployer / bond actor (Anvil #0) | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` |
| UI wallet (Anvil #1) | `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` |

## Stages

| Stage | Script | Output |
|-------|--------|--------|
| 00 | Preflight RH pins | `00_preflight.json` |
| 01 | Crane foundation | `01_crane_foundation.json` |
| 02 | IndexedEx core | `02_indexedex_core.json` |
| 03 | Hook diamond factory | `03_hook_factory.json` |
| 04 | pons launch RICH | `04_pons_rich.json` |
| 05 | Uni V3 SE on RICH pool | `05_univ3_se_rich.json` |
| 06 | Rate provider SE→WETH | `06_rate_provider.json` |
| 07 | DETF children pkgs | `07_detf_children.json` |
| 08 | Buffer CP hook + CP DETF pkgs | `08_fee_detf_packages.json` |
| 09 | CHIR inert launch-rich | `09_chir_instance.json` |
| 10 | Large RICH market buy | `10_market_buy_rich.json` |
| 11 | WETH first bond → live | `11_first_bond.json` |
| 12 | UI wallet ETH | `12_ui_wallet.json` |
| 13 | Frontend `chain/4663` | `13_frontend_export.json` |

Artifacts: `deployments/anvil_robinhood_fee_detf/`  
Frontend: `frontend/packages/protocol/src/addresses/chain/4663/`

## Env overrides

| Env | Default |
|-----|---------|
| `CREATION_PAIR_PER_DETF_WAD` | `10e18` (10 WETH per CHIR) |
| `LARGE_RICH_BUY_WETH` | `50 ether` |
| `FIRST_BOND_WETH` | `0.1 ether` |
| `ANVIL_FORK_BLOCK_NUMBER` | `20714383` |

## Product notes

- **No Balancer** deploys or imports.
- Fee-DETF package: `…/uniswap/v4/standardExchange/constantProduct/single/` (not listing DETF).
- Scripts **do** first-bond (unlike lab inert rule).
- Do **not** `deal` RICH to UI wallet — buy on pool.

## UI next steps

1. Leave Anvil running (`http://127.0.0.1:8545`, chain id **4663**).
2. Import Anvil account **#1** in MetaMask / wallet.
3. Load addresses via `@indexedex/protocol` `getAddressArtifacts(4663)` — featured fee-DETF = **CHIR**.
4. Journeys:
   - Buy **RICH** via Universal Router / V3 router on the pons pool
   - Open `/staking?detf=<chir>` for bond / fee-DETF IA
   - Second bond, sell→rebasing, fee deposits: **manual / UI** (not scripted here)
