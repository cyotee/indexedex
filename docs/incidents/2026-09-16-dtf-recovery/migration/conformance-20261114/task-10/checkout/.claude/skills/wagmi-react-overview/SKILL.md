---
name: wagmi-react-overview
description: React hooks library for Ethereum built on viem and TanStack Query. Use when building React apps with wallet connections and contract interactions.
---

# Wagmi-React Overview

React hooks for Ethereum.

## Install

```bash
pnpm add wagmi viem@2.x @tanstack/react-query
```

## Quick Start

```typescript
// config.ts
import { createConfig, http } from 'wagmi'
import { mainnet, sepolia } from 'wagmi/chains'

export const config = createConfig({
  chains: [mainnet, sepolia],
  transports: {
    [mainnet.id]: http(),
    [sepolia.id]: http(),
  },
})
```

```typescript
// App.tsx
import { WagmiProvider } from 'wagmi'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { config } from './config'

const queryClient = new QueryClient()

function App() {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <YourComponents />
      </QueryClientProvider>
    </WagmiProvider>
  )
}
```

## Skills

- **Providers**: `wagmi-react-providers` - WagmiProvider setup
- **Connect**: `wagmi-react-connect` - Wallet connection hooks
- **Read**: `wagmi-react-read` - useReadContract
- **Write**: `wagmi-react-write` - useWriteContract
- **Hooks**: `wagmi-react-hooks` - All hooks overview

## TypeScript Registration

```typescript
import { useBlockNumber } from 'wagmi'

declare module 'wagmi' {
  interface Register {
    config: typeof config
  }
}

// Now chainId is typed
useBlockNumber({ chainId: mainnet.id }) // ✅
useBlockNumber({ chainId: 123 })        // ❌ type error
```
