# Anvil Robinhood Main (chain 4663)

Operator notes for the Anvil Robinhood-mainnet-fork Uni V4 DETF + hook deploy pipeline.

## Accounts

| Role | Address | Key |
|------|---------|-----|
| Deployer / owner (Anvil #0) | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` | Anvil default #0 |
| UI wallet (Anvil #1) | `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` | Anvil default #1 |

## Run

```bash
# From repo root (Alchemy or public RH RPC via foundry.toml)
DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  bash scripts/shell/anvil_robinhood_main.sh all --restart-anvil
```

Anvil starts with `--chain-id 4663` forking Robinhood mainnet. Stage JSON lands here.

## Product notes

- DETFs are **inert** after deploy — no scripted first bond. Bond in the UI.
- Uni V3/V4 cores are **Robinhood-canonical** (`ROBINHOOD_MAIN`); never redeployed here.
- Weighted Buffer + Weighted DETF targets are **n=8** with mixed V3 SE + V4 SE legs.

## Frontend

Artifacts export to `frontend/packages/protocol/src/addresses/chain/4663/`.

Point wallet RPC at `http://127.0.0.1:8545` with chain id **4663**.
