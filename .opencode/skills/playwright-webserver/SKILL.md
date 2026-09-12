---
name: playwright-webserver
description: This skill should be used when orchestrating Anvil, Hardhat node, or frontend servers from Playwright webServer config for DeFi E2E tests.
license: MIT
---

# Playwright webServer Orchestration

`webServer` starts dependencies before tests and can run **multiple services**.

## Multi-service pattern (Anvil + app)

```ts
// playwright.config.ts
webServer: [
  {
    command: 'anvil --block-time 1',
    url: 'http://127.0.0.1:8545',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
  {
    command: 'npm run dev',
    url: 'http://127.0.0.1:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    env: {
      // Point frontend RPC at local Anvil
      VITE_RPC_URL: 'http://127.0.0.1:8545',
      NEXT_PUBLIC_RPC_URL: 'http://127.0.0.1:8545',
    },
  },
],
```

## Why this matters for DeFi

| Need | How webServer helps |
|------|---------------------|
| Idempotent chain | Fresh Anvil each CI run |
| No manual terminals | One `playwright test` boots stack |
| Local iteration | `reuseExistingServer: !CI` keeps your dev Anvil/app |
| Forked mainnet | `anvil --fork-url $RPC --fork-block-number N` |

## Fork mode example

```ts
{
  command: `anvil --fork-url ${process.env.MAINNET_RPC_URL} --fork-block-number 19000000`,
  url: 'http://127.0.0.1:8545',
  reuseExistingServer: !process.env.CI,
}
```

## Health checks

Playwright waits until `url` returns success. For Anvil, `http://127.0.0.1:8545` works with JSON-RPC. For apps, use the homepage or a `/health` route.

## Hardhat alternative

```ts
{
  command: 'npx hardhat node',
  url: 'http://127.0.0.1:8545',
  reuseExistingServer: !process.env.CI,
}
```

Same fixture patterns apply; prefer Anvil for speed and Foundry cheatcode parity with Solidity tests.

## CI tips

- Set `reuseExistingServer: false` in CI (default via `!process.env.CI`)
- Install Foundry in CI before Playwright
- Export deterministic env: chain id `31337`, fixed mnemonic accounts

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Port in use | Kill stale anvil/node or enable reuse locally |
| App connects to wrong RPC | Pass RPC via webServer `env` |
| Timeout starting server | Raise `timeout`, check command logs with `DEBUG=pw:webserver` |

## See also

- `anvil-node` (foundry plugin)
- `defi-ui-testing-overview` — full stack layout
