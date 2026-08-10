# deployments/anvil_robinhood_fee_detf

Stage JSON and runtime logs for the **fee-DETF** Anvil Robinhood launch path.

## Operator

```bash
export DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
export ALCHEMY_KEY=...   # or ANVIL_FORK_URL

bash scripts/shell/anvil_robinhood_fee_detf.sh all --restart-anvil
```

## Accounts

| Role | Address |
|------|---------|
| Deployer #0 | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` |
| UI wallet #1 | `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` |

## UI next steps

1. **Anvil still running** at `http://127.0.0.1:8545`, chain id **4663**.
2. Import wallet **#1**; set custom RPC 4663 → Anvil.
3. Artifacts:
   - Stage JSON: this directory (`00_*.json` … `13_*.json`, `platform.json`)
   - Frontend: `frontend/packages/protocol/src/addresses/chain/4663/`
     - `platform.json` — RICH, CHIR, SE, hook, core
     - `base-tokens.tokenlist.json` — WETH + RICH
     - `strategy-vaults.tokenlist.json` — Uni V3 SE
     - `protocol-detfs.tokenlist.json` — CHIR
     - `featured-fee-detfs.tokenlist.json` — **CHIR only**
4. Suggested journeys:
   - Buy RICH on the pons pool (UR / V3 router) with #1 ETH
   - `/staking` featured fee-DETF = CHIR
   - Second bond / sell rebasing: not scripted — use UI

## Kill Anvil

```bash
bash scripts/shell/anvil_robinhood_fee_detf.sh --kill-anvil
```
