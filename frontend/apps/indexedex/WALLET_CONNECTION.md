# Wallet connection

DTF uses RainbowKit 2 with Wagmi 2 and viem 2. `app/providers.tsx` owns the wallet list, provider nesting, session storage, and public-client transports. `Header.tsx` uses RainbowKit's custom ConnectButton; action buttons use `useConnectModal`. Do not choose `connectors[0]` or retry a different wallet after rejection.

## User flow

- Connect Wallet opens the RainbowKit picker. EIP-6963 discovery lists installed wallets by their own names. The generic injected connector supports older extensions.
- Selecting a wallet requests account access. Connecting does not sign a message, approve tokens, submit transactions, or navigate away.
- The account button opens RainbowKit's address/copy/disconnect menu. An approved session reconnects on reload; disconnect remains disconnected on reload.
- Network selection uses the same chain objects as Wagmi. A rejected switch leaves transaction network gates in place. Unsupported wallet networks show Switch network.
- The Playwright provider lives only under `e2e/` and announces itself as **Test Wallet**. No app code installs it or imports its signing keys.

## Configuration

Local rehearsal:

```dotenv
NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT=anvil_robinhood_main
NEXT_PUBLIC_DEFAULT_CHAIN_ID=4663
NEXT_PUBLIC_LOCAL_RPC_URL=http://127.0.0.1:8545
```

An explicit local RPC exposes only that fork in the wallet configuration. Disconnected browsing uses that HTTP endpoint. Once connected, reads, simulations, receipt polling and signing use the selected connector’s provider. Wallet RPC errors and network mismatches never fall back to HTTP. Account, connector and network changes reset cached readings. The header displays **Robinhood Local Anvil**, with **RPC: connected wallet** when connected and **Browsing RPC** otherwise. Local blocks/transactions do not link to the public explorer. A 46630 rehearsal uses its own configured chain ID and fork.

**Wallet setup:** configure the wallet's RPC to match the configured local URL. Robinhood mainnet and this fork share chain ID 4663; neither RainbowKit nor `wallet_switchEthereumChain` can verify or replace an existing wallet RPC merely from its chain ID. The displayed local label describes the app configuration, not verification of the wallet's endpoint.

Public networks: omit `NEXT_PUBLIC_LOCAL_RPC_URL`. Installed wallets work without a cloud project. Set `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID` to enable the MetaMask/Rainbow/Coinbase/WalletConnect list and mobile QR connections. The project ID is a public application identifier. Configure its allowed origins in WalletConnect Cloud. No placeholder project ID is used. Mobile/QR connectors are omitted for the local rehearsal because another device cannot reach the computer's loopback RPC.

Sessions use a new RainbowKit storage namespace, separated between local and public configurations. Previous Wagmi 3 sessions require a fresh connection once. Dependencies must remain within RainbowKit's supported Wagmi peer range; `useConnection` was migrated to Wagmi 2's `useAccount`.

RainbowKit is pinned to 2.2.11 with a checked-in `frontend/patches/` patch applied by the workspace's `postinstall` script. Two upstream connection issues are corrected:

- With an explicit `initialChain` (as DTF always supplies), connecting goes directly to Wagmi's account permission request. RainbowKit must not first wait for `eth_chainId` from a disconnected wallet. Wagmi still reads the actual chain after account access and performs the required network switch.
- Entering the connection screen must not clear an error that already arrived. Immediate rejection or an already-pending wallet request must show Retry instead of being overwritten by the delayed “Opening” screen. A new connection attempt resets the error.

When upgrading RainbowKit, review or remove this patch and rerun the wallet regressions. Keep lifecycle scripts enabled when installing dependencies (`npm install` or `npm ci` from `frontend/`). These browser tests use an EIP-1193 fixture; they do not verify the real MetaMask extension's popup behavior. If MetaMask reports a pending request, open its extension icon and approve or dismiss that request before retrying.

Next's webpack configuration resolves the Base wallet SDK to its published browser entry during SSR too. This keeps its unrelated Node payment SDK out of the wallet bundle. Wallet SDKs are no longer aliased to empty modules. The dev/typecheck scripts resolve npm's hoisted workspace packages without a `node_modules` symlink.

## Verification

From `frontend/`:

```sh
npm install
npm run typecheck
npm run test
E2E_SKIP_WEBSERVER=1 npm run test:e2e -w @indexedex/app-indexedex -- e2e/rainbowkit.spec.ts e2e/connected-wallet.spec.ts
```

Use the existing dev server on port 3002 and operator-provided Anvil. The connection suite covers discovery, explicit selection, rejection, account changes, reconnect/disconnect, network mismatch, ordinary browsers without test injection, and mobile layout. Contract money-path suites still require deployed contracts matching the exported artifacts; wallet tests do not deploy them.

For local UI verification against **Robinhood mainnet**, leave `NEXT_PUBLIC_LOCAL_RPC_URL` empty and retain chain ID 4663 and the `anvil_robinhood_main` address registry (the registry name is historical; staking discovers the active DETF from the mainnet staking contract). Run `npm run dev:indexedex` and `npm run dev:dtf` from `frontend/` for ports 3002 and 3003. Connected operations use the wallet's configured RPC.

The opt-in mainnet bond regression uses a read-only test provider. It checks the real oversized WETH/ETH quote, disabled payment buttons, and selection of a smaller positive quote. It cannot sign or broadcast; successful bond execution still needs separate simulation or user verification.

```sh
E2E_MAINNET_READONLY=1 E2E_SKIP_WEBSERVER=1 npm run test:e2e -w @indexedex/app-indexedex -- e2e/staking-bond-mainnet-readonly.spec.ts
E2E_MAINNET_READONLY=1 E2E_SKIP_WEBSERVER=1 E2E_BASE_URL=http://127.0.0.1:3003 npm run test:e2e -w @indexedex/app-indexedex -- e2e/staking-bond-mainnet-readonly.spec.ts
```

Bond quotes include the selected duration's bonus and the reserve input limit. Failed quotes must stop approval/wrapping, and fresh quotes are checked again before execution. “Find a smaller amount” only updates the amount field using contract previews; it never splits or submits a purchase. ETH wrapping and approval confirmations are separate from “Bond confirmed.”
