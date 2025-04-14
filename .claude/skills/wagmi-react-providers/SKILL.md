---
name: wagmi-react-providers
description: WagmiProvider and QueryClientProvider setup for React. Use when configuring the React context for wallet and blockchain data.
---

# Wagmi-React Providers

Setup providers for React apps.

## Basic Setup

```typescript
import { WagmiProvider } from 'wagmi'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { config } from './config'

const queryClient = new QueryClient()

function App() {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <YourApp />
      </QueryClientProvider>
    </WagmiProvider>
  )
}
```

## WagmiProvider Options

```typescript
<WagmiProvider 
  config={config}
  reconnect={true}  // auto-reconnect on mount
>
```

## QueryClient Options

```typescript
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000, // 5 minutes
      refetchOnWindowFocus: false,
    },
  },
})
```

## With Initial State (SSR)

```typescript
import { cookieToInitialState } from 'wagmi'

const initialState = cookieToInitialState(config, cookies)

function App() {
  return (
    <WagmiProvider config={config} initialState={initialState}>
      <QueryClientProvider client={queryClient}>
        <YourApp />
      </QueryClientProvider>
    </WagmiProvider>
  )
}
```

## useConfig Hook

Access config from anywhere:

```typescript
import { useConfig } from 'wagmi'

function MyComponent() {
  const config = useConfig()
  
  // Access chains, connectors, etc.
  const chains = config.chains
}
```
