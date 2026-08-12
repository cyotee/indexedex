# Stacks and wallets

## Contents

- Fee DETF vs main lab
- Accounts
- Wallet inject behavior
- Pointing MetaMask (human only)

## Two deploy families (do not merge)

| Family | Shell | DETF state | UI focus |
|--------|-------|------------|----------|
| **fee_detf** | `scripts/shell/anvil_robinhood_fee_detf.sh` | CHIR **live** after scripted first bond | `/staking`, second bond, sell/claim |
| **main** | `scripts/shell/anvil_robinhood_main.sh` | **Inert** demos (no script bond) | Multi SE/hooks/DETFs; UI first bond |

Both write `frontend/packages/protocol/src/addresses/chain/4663/` — **last export wins**.

Docs: `scripts/foundry/anvil_robinhood_*/README.md`, `docs/ANVIL_ROBINHOOD_UI_AGENT_RUNBOOK.md`.

## Accounts

| Role | Address | Key note |
|------|---------|----------|
| Deployer / e2e inject #0 | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` | Foundry default |
| UI wallet #1 | `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` | Human MetaMask import |

E2E uses **#0** so inject private key is standard Anvil #0.

## Injected wallet (Playwright)

- File: `frontend/apps/dtf/e2e/wallet/injectWallet.ts`
- Sets `window.ethereum` **before** app scripts (`addInitScript`)
- Reports `eth_chainId` = `E2E_CHAIN_ID` (default 4663)
- `eth_sendTransaction` → viem wallet client → local RPC
- Supports `personal_sign` / `eth_signTypedData_v4` (Permit2)

## Human MetaMask (manual only)

1. Network: RPC `http://127.0.0.1:8545`, chain id **4663**, symbol ETH  
2. Import Anvil #1 private key for “public user” flows  
3. Do not use chain id 31337 while scripts require 4663  

## Sanity

```bash
cast chain-id --rpc-url http://127.0.0.1:8545
test -f frontend/packages/protocol/src/addresses/chain/4663/platform.json
jq '{chainId, chir, feeDetf, networkProfile, weth}' \
  frontend/packages/protocol/src/addresses/chain/4663/platform.json
```
