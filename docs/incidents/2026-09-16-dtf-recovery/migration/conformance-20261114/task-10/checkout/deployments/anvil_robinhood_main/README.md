# Anvil Robinhood Main (chain 4663)

Operator notes for the Anvil Robinhood-mainnet-fork **architecture** deploy.

No test tokens. No SE vault instances. No DETF instances. Stage JSON for factories, platform, Uni V4 / Morpho SE packages, and CP / Weighted / Curve Quad hook and DETF packages lands here. Phase 09 copies architecture keys to `frontend/packages/protocol/src/addresses/chain/4663/`.

## Accounts

| Role | Address |
|------|---------|
| Deployer / owner (Anvil #0) | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` |

## Gas estimate

EIP-1559 from the Robinhood fork source. No `--legacy` / `--gas-price`. The wrapper prints a deployer funding quote (dry-run gas limits × live `eth_gasPrice`, plus 25% buffer).

```bash
DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  bash scripts/shell/anvil_robinhood_main.sh simulate --restart-anvil
```

## Staged deploy

```bash
DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  bash scripts/shell/anvil_robinhood_main.sh all --restart-anvil
```

Anvil forks public Robinhood mainnet (`robinhood_mainnet`) at the remote tip, chain id 4663. EIP-170 stays on. Uni V4 cores are Robinhood-canonical (`ROBINHOOD_MAIN`); never redeployed here.
