---
name: wagmi-react-connect
description: Wallet connection hooks for React. Use when connecting wallets and managing connection state.
---

# Wagmi-React Connect

Wallet connection hooks.

## useConnect

```typescript
import { useConnect } from 'wagmi'

function ConnectButton() {
  const { connectors, connect, isPending, error } = useConnect()

  return (
    <div>
      {connectors.map((connector) => (
        <button
          key={connector.uid}
          onClick={() => connect({ connector })}
          disabled={isPending}
        >
          Connect {connector.name}
        </button>
      ))}
      {error && <div>Error: {error.message}</div>}
    </div>
  )
}
```

## useConnection

```typescript
import { useConnection } from 'wagmi'

function Profile() {
  const { address, chainId, connector } = useConnection()

  if (!address) return <div>Not connected</div>

  return (
    <div>
      <p>Address: {address}</p>
      <p>Chain: {chainId}</p>
      <p>Connector: {connector.name}</p>
    </div>
  )
}
```

## useDisconnect

```typescript
import { useDisconnect } from 'wagmi'

function DisconnectButton() {
  const { disconnect, isPending } = useDisconnect()

  return (
    <button onClick={() => disconnect()} disabled={isPending}>
      Disconnect
    </button>
  )
}
```

## useAccount (Preferred)

```typescript
import { useAccount } from 'wagmi'

function Profile() {
  const { address, isConnected, chainId, status } = useAccount()

  if (status === 'connecting') return <div>Connecting...</div>
  if (!isConnected) return <div>Not connected</div>

  return (
    <div>
      <p>Address: {address}</p>
      <p>Chain ID: {chainId}</p>
    </div>
  )
}
```

## useSwitchChain

```typescript
import { useSwitchChain, useChainId } from 'wagmi'
import { base, mainnet } from 'wagmi/chains'

function ChainSwitcher() {
  const { chains } = useSwitchChain()
  const chainId = useChainId()

  return (
    <select
      value={chainId}
      onChange={(e) => switchChain({ chainId: Number(e.target.value) })}
    >
      {chains.map((chain) => (
        <option key={chain.id} value={chain.id}>
          {chain.name}
        </option>
      ))}
    </select>
  )
}
```

## Auto Reconnect

```typescript
// In WagmiProvider
<WagmiProvider config={config} reconnect>
```

This automatically reconnects on mount if previously connected.
