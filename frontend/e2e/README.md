# Connected-wallet UI tests (Playwright + injected wallet)

We **do not** automate MetaMask. We inject a real EIP-1193 `window.ethereum` that:

- reports Anvil account `#0` (`0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`)
- signs txs with the standard Foundry private key
- forwards RPC to `http://127.0.0.1:8545` (or `E2E_RPC_URL`)

That matches production: wagmi’s **injected** connector + your UI.

## Prerequisites

1. **Build** the Next app at least once: `npm run build`
2. Optional but recommended for on-chain reads: **Anvil** (or full `local_testing` stack) on `127.0.0.1:8545` with chain id `11155111`
3. Chromium for Playwright: `npx playwright install chromium`

## Run

```bash
cd frontend
npm run build          # if not already built
npm run test:e2e       # starts `next start` unless a server is already on :3000
```

Reuse an already-running UI:

```bash
npm run dev            # terminal 1
E2E_SKIP_WEBSERVER=1 npm run test:e2e   # terminal 2
```

## Layout

| Path | Role |
|------|------|
| `e2e/wallet/injectWallet.ts` | EIP-1193 bridge (viem + Anvil key) |
| `e2e/wallet/fixture.ts` | Playwright fixture `walletPage` |
| `e2e/connected-wallet.spec.ts` | Connect UI + Earn/Portfolio smoke |
| `playwright.config.ts` | Config + webServer |

## Extending

- Prefer `test` from `./wallet/fixture` so every test gets the injected provider.
- For deposit flows, ensure Anvil has the vault deployed (`local_testing.sh`) and assert UI status / portfolio text after click — still no MetaMask popup.
