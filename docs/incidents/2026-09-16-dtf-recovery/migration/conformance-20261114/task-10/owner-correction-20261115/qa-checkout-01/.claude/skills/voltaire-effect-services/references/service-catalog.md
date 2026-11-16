# Service Catalog

## Provider Service Methods

### Block Queries
- `getBlockNumber()` → `Effect<bigint, ProviderResponseError, ProviderService>`
- `getBlock({ blockNumber | blockHash })` → `Effect<Block, ProviderResponseError, ProviderService>`
- `getBlockReceipts({ blockNumber })` → `Effect<Receipt[], ProviderResponseError, ProviderService>`
- `getUncleCount({ blockNumber })` → `Effect<number, ProviderResponseError, ProviderService>`

### Account State
- `getBalance(address)` → `Effect<bigint, GetBalanceError, ProviderService>`
- `getTransactionCount(address)` → `Effect<number, ProviderResponseError, ProviderService>`
- `getCode(address)` → `Effect<Uint8Array, ProviderResponseError, ProviderService>`
- `getStorageAt(address, slot)` → `Effect<Uint8Array, ProviderResponseError, ProviderService>`

### Transaction Queries
- `getTransaction(hash)` → `Effect<Transaction, ProviderResponseError, ProviderService>`
- `getTransactionReceipt(hash)` → `Effect<Receipt, ProviderResponseError | ProviderReceiptPendingError, ProviderService>`
- `waitForTransactionReceipt(hash)` → `Effect<Receipt, ProviderResponseError | ProviderConfirmationsPendingError, ProviderService>`

### Contract Reads
- `readContract({ address, abi, functionName, args })` → `Effect<Result, ContractCallError, ProviderService>`
- `multicall({ contracts, allowFailure })` → `Effect<Result[] | Either[], ContractCallError, ProviderService>`
- `simulateContract({ address, abi, functionName, args })` → `Effect<{ result, request }, ContractCallError, ProviderService>`

### Gas
- `getGasPrice()` → `Effect<bigint, ProviderResponseError, ProviderService>`
- `getMaxPriorityFeePerGas()` → `Effect<bigint, ProviderResponseError, ProviderService>`
- `getFeeHistory({ blockCount, newestBlock, rewardPercentiles })` → `Effect<FeeHistory, ProviderResponseError, ProviderService>`

### Events
- `getLogs({ fromBlock, toBlock, address?, topics? })` → `Effect<Log[], ProviderResponseError, ProviderService>`

### Streaming
- `watchBlocks(callback)` → `Effect<Unsubscribe, ProviderStreamError, ProviderService>`

## Transport Options

| Transport | Constructor | Use Case |
|-----------|-------------|----------|
| `HttpTransport` | `HttpTransport(url \| config)` | Standard HTTP JSON-RPC |
| `WebSocketTransport` | `WebSocketTransport(url)` | Subscriptions, low latency |
| `BrowserTransport` | `BrowserTransport()` | Browser `window.ethereum` |
| `TestTransport` | `TestTransport(responses)` | Unit testing |

## Additional Services

| Service | Purpose | Docs |
|---------|---------|------|
| `AccountService` | Manage accounts | /services/account |
| `CacheService` | Response caching | /services/cache |
| `FeeEstimatorService` | Gas estimation | /services/fee-estimator |
| `NonceManagerService` | Nonce tracking | /services/nonce-manager |
| `RpcBatchService` | Request batching | /services/rpc-batch |
| `RateLimiterService` | Rate limiting | /services/rate-limiter |
| `ChainService` | Chain metadata | /services/chain |
| `CCIPService` | Cross-chain reads | /services/ccip |
| `ContractRegistryService` | Contract management | /services/contract-registry |
| `DebugService` | Debug namespace | /services/debug |
| `EngineApiService` | Engine API | /services/engine-api |
| `FormatterService` | Data formatting | /services/formatter |
| `BlockExplorerApiService` | Explorer APIs | /services/block-explorer-api |
