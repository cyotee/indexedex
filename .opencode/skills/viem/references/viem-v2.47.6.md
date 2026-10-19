# Archived Viem API reference, adapted for IndexedEx

Snapshot content below claims v2.47.6. It is reference material, not verified
against the installed frontend lockfile. Use the entry skill and current library
types for executable work. Public Anvil test keys are local-fixture-only.
Known nonce/fee-example errors and unrelated ManaMesh routing were corrected.


# viem v2.47.6 — TypeScript Ethereum Library

> **Source**: `https://github.com/wevm/viem` (main branch)  
> **Docs**: `https://viem.sh`  
> **Version**: 2.47.6  
> **Package**: `viem`

viem is a lightweight, TypeScript-first Ethereum library. It provides Clients (Public, Wallet, Test), Transports (HTTP, WebSocket, Custom, Fallback), Accounts (private key, mnemonic, HD, JSON-RPC), and typed Actions for every Ethereum RPC method.

IndexedEx uses its existing frontend client/chain configuration; the original ManaMesh-specific routing is not applicable here.

---

# Quick Start

## Public Client

```typescript
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const publicClient = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const blockNumber = await publicClient.getBlockNumber()
// 69420n
```

## Wallet Client

```typescript
import { createWalletClient, custom, http } from 'viem'
import { mainnet } from 'viem/chains'

const walletClient = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum!),
})
const [address] = await walletClient.getAddresses()
const hash = await walletClient.sendTransaction({
  account: address,
  to: '0xa5cc3c03994DB5b0d9A5eEdD10CabaB0813678AC',
  value: parseEther('0.001'),
})
```

## Local Account (Private Key)

```typescript
import { createWalletClient, http, parseEther } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { foundry } from 'viem/chains'

const account = privateKeyToAccount('0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80')
const walletClient = createWalletClient({ account, chain: foundry, transport: http('http://127.0.0.1:8545') })
const hash = await walletClient.sendTransaction({
  to: '0xa5cc3c03994DB5b0d9A5eEdD10CabaB0813678AC',
  value: parseEther('0.001'),
})
```

## Wallet + Public Actions Combined

```typescript
import { createWalletClient, http, publicActions } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  account: privateKeyToAccount('0x...'),
  chain: mainnet,
  transport: http(),
}).extend(publicActions) // adds public actions to wallet client

const { request } = await client.simulateContract({ ... })  // public action
const hash = await client.writeContract(request)              // wallet action
```

## Test Client

```typescript
import { createTestClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const testClient = createTestClient({
  chain: mainnet,
  transport: http(),
  mode: 'anvil', // or 'hardhat', 'ganache'
})
```

---

# Public Actions

## Table of Contents

- [Block](#block)
  - [getBlock](#getblock) · [getBlockNumber](#getblocknumber) · [getBlockTransactionCount](#getblocktransactioncount) · [watchBlockNumber](#watchblocknumber) · [watchBlocks](#watchblocks)
- [Transaction](#transaction)
  - [getTransaction](#gettransaction) · [getTransactionReceipt](#gettransactionreceipt) · [getTransactionConfirmations](#gettransactionconfirmations) · [sendRawTransaction](#sendrawtransaction-public) · [waitForTransactionReceipt](#waitfortransactionreceipt) · [watchPendingTransactions](#watchpendingtransactions)
- [State](#state)
  - [getBalance](#getbalance) · [getCode](#getcode-contract) · [getStorageAt](#getstorageat-contract) · [getProof](#getproof)
- [Fees & Gas](#fees--gas)
  - [getGasPrice](#getgasprice) · [getFeeHistory](#getfeehistory) · [estimateGas](#estimategas) · [estimateFeesPerGas](#estimatefeespergas) · [estimateMaxPriorityFeePerGas](#estimatemaxpriorityfeepergas) · [getBlobBaseFee](#getblobbasefee)
- [Chain & Network](#chain--network)
  - [getChainId](#getchainid) · [getEip712Domain](#geteip712domain) · [getDelegation](#getdelegation)
- [Logs & Events](#logs--events)
  - [getLogs](#getlogs) · [createEventFilter](#createeventfilter) · [createBlockFilter](#createblockfilter) · [createPendingTransactionFilter](#creatependingtransactionfilter) · [getFilterChanges](#getfilterchanges) · [getFilterLogs](#getfilterlogs) · [watchEvent](#watchevent) · [uninstallFilter](#uninstallfilter)
- [Execution](#execution)
  - [call](#call) · [createAccessList](#createaccesslist) · [simulateCalls](#simulatecalls) · [simulateBlocks](#simulateblocks)
- [Verification](#verification)
  - [verifyMessage](#verifymessage) · [verifyTypedData](#verifytypeddata)

---

## Block

### getBlock

**Docs**: `https://viem.sh/docs/actions/public/getBlock`  
**JSON-RPC**: `eth_getBlockByNumber` / `eth_getBlockByHash`  
**Source**: `src/actions/public/getBlock.ts`

```typescript
// Signature
export async function getBlock<
  chain extends Chain | undefined,
  account extends Account | undefined,
  includeTransactions extends boolean = false,
  blockTag extends BlockTag = 'latest',
>(
  client: Client<Transport, chain, account>,
  {
    blockHash,
    blockNumber,
    blockTag = client.experimental_blockTag ?? 'latest',
    includeTransactions: includeTransactions_,
  }: GetBlockParameters<includeTransactions, blockTag> = {},
): Promise<GetBlockReturnType<chain, includeTransactions, blockTag>>
```

**Code Examples**:

```typescript
// Latest block (no transactions)
const block = await publicClient.getBlock()

// Specific block number with transactions
const fullBlock = await publicClient.getBlock({
  blockNumber: 69420n,
  includeTransactions: true,
})

// By block hash
const block = await publicClient.getBlock({
  blockHash: '0x4ca7ee652d57678f26e887c149ab0735f41de37bcad58c9f6d3ed5824f15b74d',
})

// Block tag
const block = await publicClient.getBlock({ blockTag: 'safe' })
```

---

### getBlockNumber

**Docs**: `https://viem.sh/docs/actions/public/getBlockNumber`  
**JSON-RPC**: `eth_blockNumber`  
**Source**: `src/actions/public/getBlockNumber.ts`

```typescript
// Signature
export async function getBlockNumber<chain extends Chain | undefined>(
  client: Client<Transport, chain>,
  { cacheTime = client.cacheTime }: GetBlockNumberParameters = {},
): Promise<GetBlockNumberReturnType>  // Returns: bigint
```

**Code Examples**:

```typescript
const blockNumber = await publicClient.getBlockNumber()
// 69420n

// With cache override
const blockNumber = await publicClient.getBlockNumber({ cacheTime: 0 })
```

---

### getBlockTransactionCount

**Docs**: `https://viem.sh/docs/actions/public/getBlockTransactionCount`  
**JSON-RPC**: `eth_getBlockTransactionCountByNumber` / `eth_getBlockTransactionCountByHash`  
**Source**: `src/actions/public/getBlockTransactionCount.ts`

```typescript
// Signature
export async function getBlockTransactionCount<chain extends Chain | undefined>(
  client: Client<Transport, chain>,
  {
    blockHash,
    blockNumber,
    blockTag = 'latest',
  }: GetBlockTransactionCountParameters = {},
): Promise<GetBlockTransactionCountReturnType>  // Returns: number
```

**Code Examples**:

```typescript
const count = await publicClient.getBlockTransactionCount({ blockNumber: 69420n })
const count = await publicClient.getBlockTransactionCount({ blockTag: 'safe' })
const count = await publicClient.getBlockTransactionCount({
  blockHash: '0x4ca7ee652d57678f26e887c149ab0735f41de37bcad58c9f6d3ed5824f15b74d',
})
```

---

### watchBlockNumber

**Docs**: `https://viem.sh/docs/actions/public/watchBlockNumber`  
**Source**: `src/actions/public/watchBlockNumber.ts`

```typescript
// Signature
export function watchBlockNumber<
  chain extends Chain | undefined,
  transport extends Transport,
>(
  client: Client<transport, chain>,
  {
    emitOnBegin = false,
    emitMissed = false,
    onBlockNumber,
    onError,
    poll: poll_,
    pollingInterval = client.pollingInterval,
  }: WatchBlockNumberParameters<transport>,
): WatchBlockNumberReturnType  // Returns: () => void (unwatch fn)
```

**Code Examples**:

```typescript
const unwatch = publicClient.watchBlockNumber({
  onBlockNumber: (blockNumber) => console.log(blockNumber),
  onError: (error) => console.error(error),
})
// > 69420n
// > 69421n
// > 69422n

// Polling interval
const unwatch = publicClient.watchBlockNumber({
  pollingInterval: 1_000, // 1 second
  onBlockNumber: (blockNumber) => console.log(blockNumber),
})

// Emit on begin (fire immediately)
const unwatch = publicClient.watchBlockNumber({
  emitOnBegin: true,
  onBlockNumber: (blockNumber) => console.log(blockNumber),
})
```

---

### watchBlocks

**Docs**: `https://viem.sh/docs/actions/public/watchBlocks`  
**Source**: `src/actions/public/watchBlocks.ts`

```typescript
// Signature
export function watchBlocks<
  transport extends Transport,
  chain extends Chain | undefined,
  includeTransactions extends boolean = false,
  blockTag extends BlockTag = 'latest',
>(
  client: Client<transport, chain>,
  {
    blockTag = client.experimental_blockTag ?? 'latest',
    emitMissed = false,
    emitOnBegin = false,
    onBlock,
    onError,
    includeTransactions: includeTransactions_,
    poll: poll_,
    pollingInterval = client.pollingInterval,
  }: WatchBlocksParameters<transport, chain, includeTransactions, blockTag>,
): WatchBlocksReturnType  // Returns: () => void
```

**Code Examples**:

```typescript
const unwatch = publicClient.watchBlocks({
  onBlock: (block) => console.log(block),
})
// > { number: 69420n, ... }
// > { number: 69421n, ... }

// With transactions
const unwatch = publicClient.watchBlocks({
  includeTransactions: true,
  onBlock: (block) => console.log(block.transactions),
})
```

---

## Transaction

### getTransaction

**Docs**: `https://viem.sh/docs/actions/public/getTransaction`  
**JSON-RPC**: `eth_getTransactionByHash`  
**Source**: `src/actions/public/getTransaction.ts`

```typescript
// Signature
export async function getTransaction<chain extends Chain | undefined>(
  client: Client<Transport, chain>,
  { hash }: GetTransactionParameters,
): Promise<GetTransactionReturnType<chain>>
```

**Code Examples**:

```typescript
const tx = await publicClient.getTransaction({ hash: '0x4ca7ee652d57678f26e887c149ab0735f41de37bcad58c9f6d3ed5824f15b74d' })
// { hash, blockNumber, from, to, value, gas, gasPrice, nonce, input, ... }
```

---

### getTransactionReceipt

**Docs**: `https://viem.sh/docs/actions/public/getTransactionReceipt`  
**JSON-RPC**: `eth_getTransactionReceipt`  
**Source**: `src/actions/public/getTransactionReceipt.ts`

```typescript
// Signature
export async function getTransactionReceipt<chain extends Chain | undefined>(
  client: Client<Transport, chain>,
  { hash }: GetTransactionReceiptParameters,
): Promise<FormattedTransactionReceipt<chain>>
```

**Code Examples**:

```typescript
const receipt = await publicClient.getTransactionReceipt({ hash: '0x...' })
// { transactionHash, blockNumber, blockHash, status, gasUsed, logs, ... }

// Check status
if (receipt.status === 'success') {
  console.log('Transaction succeeded')
} else {
  console.log('Transaction reverted')
}
```

---

### getTransactionConfirmations

**Docs**: `https://viem.sh/docs/actions/public/getTransactionConfirmations`  
**JSON-RPC**: `eth_blockNumber` + transaction receipt  
**Source**: `src/actions/public/getTransactionConfirmations.ts`

```typescript
// Signature
export async function getTransactionConfirmations<
  chain extends Chain | undefined,
>(
  client: Client<Transport, chain>,
  { hash, transactionReceipt }: GetTransactionConfirmationsParameters<chain>,
): Promise<GetTransactionConfirmationsReturnType>  // Returns: bigint
```

**Code Examples**:

```typescript
const confirmations = await publicClient.getTransactionConfirmations({
  hash: '0x...',
  transactionReceipt: await publicClient.getTransactionReceipt({ hash: '0x...' }),
})
console.log(`Confirmed: ${confirmations} blocks`)
```

---

### sendRawTransaction (Public)

**Docs**: `https://viem.sh/docs/actions/public/sendRawTransaction`  
**JSON-RPC**: `eth_sendRawTransaction`  
**Source**: `src/actions/public/sendRawTransaction.ts`  
**Note**: Source file is in `src/actions/wallet/` — categorized as wallet action in source tree. Listed under public actions in viem.sh sidebar.

```typescript
// Signature (wallet action source)
export async function sendRawTransaction<chain extends Chain | undefined>(
  client: Client<Transport, chain>,
  { serializedTransaction }: SendRawTransactionParameters,
): Promise<SendRawTransactionReturnType>  // Returns: Hash
```

**Code Examples**:

```typescript
const hash = await walletClient.sendRawTransaction({
  serializedTransaction: '0x02f850018203118080825208808080c080a04012522854168b27e5dc3d5839bab5e6b39e1a0ffd343901ce1622e3d64b48f1a04e00902ae0502c4728cbf12156290df99c3ed7de85b1dbfe20b5c36931733a33',
})
```

---

### waitForTransactionReceipt

**Docs**: `https://viem.sh/docs/actions/public/waitForTransactionReceipt`  
**JSON-RPC**: Polls `eth_getTransactionReceipt`  
**Source**: `src/actions/public/waitForTransactionReceipt.ts`

```typescript
// Signature
export async function waitForTransactionReceipt<
  chain extends Chain | undefined,
>(
  client: Client<Transport, chain>,
  parameters: WaitForTransactionReceiptParameters<chain>,
): Promise<WaitForTransactionReceiptReturnType<chain>>
// WaitForTransactionReceiptReturnType = GetTransactionReceiptReturnType<chain>
```

**Code Examples**:

```typescript
const receipt = await publicClient.waitForTransactionReceipt({
  hash: '0x...',
})
// Waits for transaction to be mined

// With polling interval
const receipt = await publicClient.waitForTransactionReceipt({
  hash: '0x...',
  pollingInterval: 1_000,
})

// With timeout
const receipt = await publicClient.waitForTransactionReceipt({
  hash: '0x...',
  timeout: 30_000, // 30 seconds
})
```

---

### watchPendingTransactions

**Docs**: `https://viem.sh/docs/actions/public/watchPendingTransactions`  
**Source**: `src/actions/public/watchPendingTransactions.ts`

```typescript
// Signature
export function watchPendingTransactions<
  transport extends Transport,
  chain extends Chain | undefined,
>(
  client: Client<transport, chain>,
  {
    batch = true,
    onError,
    onTransactions,
    poll: poll_,
    pollingInterval = client.pollingInterval,
  }: WatchPendingTransactionsParameters<transport>,
): WatchPendingTransactionsReturnType  // Returns: () => void
```

**Code Examples**:

```typescript
const unwatch = publicClient.watchPendingTransactions({
  onTransactions: (hashes) => console.log(hashes),
})
// > ['0x...', '0x...']
// > ['0x...']
```

---

## State

### getBalance

**Docs**: `https://viem.sh/docs/actions/public/getBalance`  
**JSON-RPC**: `eth_getBalance`  
**Source**: `src/actions/public/getBalance.ts`

```typescript
// Signature
export async function getBalance<
  chain extends Chain | undefined,
  account extends Account | undefined,
>(
  client: Client<Transport, chain, account>,
  { address, blockNumber, blockTag = 'latest' }: GetBalanceParameters,
): Promise<GetBalanceReturnType>  // Returns: bigint
```

**Code Examples**:

```typescript
const balance = await publicClient.getBalance({
  address: '0x...',
})
// 1000000000000000000n  (wei — 1 ETH)

// At specific block
const balance = await publicClient.getBalance({
  address: '0x...',
  blockNumber: 69420n,
})

// Using block tag
const balance = await publicClient.getBalance({
  address: '0x...',
  blockTag: 'safe',
})
```

---

### getCode (Contract)

**Docs**: `https://viem.sh/docs/contract/getCode`  
**JSON-RPC**: `eth_getCode`  
**Source**: `src/actions/public/getCode.ts`

```typescript
// Signature
export async function getCode<chain extends Chain | undefined>(
  client: Client<Transport, chain>,
  { address, blockNumber, blockTag = 'latest' }: GetCodeParameters,
): Promise<GetCodeReturnType>  // Returns: Hex | undefined
```

**Code Examples**:

```typescript
const code = await publicClient.getCode({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
})
// '0x608060405260405161083e38038061083e833981016040819052610...'

// At specific block
const code = await publicClient.getCode({
  address: '0x...',
  blockNumber: 15121123n,
})

// Returns undefined if no code at address
const code = await publicClient.getCode({ address: '0x...' })
if (code === undefined) {
  console.log('No contract deployed at this address')
}
```

---

### getStorageAt (Contract)

**Docs**: `https://viem.sh/docs/contract/getStorageAt`  
**JSON-RPC**: `eth_getStorageAt`  
**Source**: `src/actions/public/getStorageAt.ts`

```typescript
// Signature
export async function getStorageAt<chain extends Chain | undefined>(
  client: Client<Transport, chain>,
  { address, blockNumber, blockTag = 'latest', slot }: GetStorageAtParameters,
): Promise<GetStorageAtReturnType>  // Returns: Hex | undefined
```

**Code Examples**:

```typescript
import { toHex } from 'viem'

const data = await publicClient.getStorageAt({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  slot: toHex(0),
})
// '0x0000000000000000000000000000000000000000000000000000000000000420'

// At specific block
const data = await publicClient.getStorageAt({
  address: '0x...',
  slot: toHex(0),
  blockNumber: 15121123n,
})
```

---

### getProof

**Docs**: `https://viem.sh/docs/actions/public/getProof`  
**JSON-RPC**: `eth_getProof`  
**Source**: `src/actions/public/getProof.ts`

```typescript
// Signature
export async function getProof<chain extends Chain | undefined>(
  client: Client<Transport, chain>,
  {
    address,
    blockNumber,
    blockTag: blockTag_,
    storageKeys,
  }: GetProofParameters,
): Promise<GetProofReturnType>  // Returns: Proof
```

**Code Examples**:

```typescript
const proof = await publicClient.getProof({
  address: '0x...',
  storageKeys: ['0x...', '0x...'],
})
// { accountProof: [...], storageProof: [...] }
```

---

## Fees & Gas

### getGasPrice

**Docs**: `https://viem.sh/docs/actions/public/getGasPrice`  
**JSON-RPC**: `eth_gasPrice`  
**Source**: `src/actions/public/getGasPrice.ts`

```typescript
// Signature
export async function getGasPrice<chain extends Chain | undefined>(
  client: Client<Transport, chain>,
): Promise<GetGasPriceReturnType>  // Returns: bigint
```

**Code Examples**:

```typescript
const gasPrice = await publicClient.getGasPrice()
// 20000000000n  (20 Gwei)

// Legacy transaction gas price
const txHash = await walletClient.sendTransaction({
  to: '0x...',
  gasPrice: await publicClient.getGasPrice(),
})
```

---

### getFeeHistory

**Docs**: `https://viem.sh/docs/actions/public/getFeeHistory`  
**JSON-RPC**: `eth_feeHistory`  
**Source**: `src/actions/public/getFeeHistory.ts`

```typescript
// Signature
export async function getFeeHistory<
  chain extends Chain | undefined,
>(
  client: Client<Transport, chain>,
  {
    blockCount,
    blockNumber,
    blockTag = 'latest',
    rewardPercentiles,
  }: GetFeeHistoryParameters,
): Promise<GetFeeHistoryReturnType>
// Returns: { oldestBlock: bigint, baseFeePerGas: bigint[], gasUsedRatio: number[], reward: bigint[][] }
```

**Code Examples**:

```typescript
const feeHistory = await publicClient.getFeeHistory({
  blockCount: 4,
  rewardPercentiles: [25, 75],
})
// { oldestBlock: 69420n, baseFeePerGas: [...], gasUsedRatio: [...], reward: [[...], [...]] }

// Get average priority fee
const avgPriorityFee = feeHistory.reward
  .flat()
  .reduce((a, b) => a + b, 0n) / BigInt(feeHistory.reward.flat().length)
```

---

### estimateGas

**Docs**: `https://viem.sh/docs/actions/public/estimateGas`  
**JSON-RPC**: `eth_estimateGas`  
**Source**: `src/actions/public/estimateGas.ts`

```typescript
// Signature
export async function estimateGas<
  chain extends Chain | undefined,
  account extends Account | undefined,
>(
  client: Client<Transport, chain, account>,
  args: EstimateGasParameters<chain, account>,
): Promise<EstimateGasReturnType>  // Returns: bigint
```

**Code Examples**:

```typescript
const gas = await publicClient.estimateGas({
  account: '0x...',
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
  value: parseEther('1'),
})
// 21000n

// With data
const gas = await publicClient.estimateGas({
  account: '0x...',
  to: '0x...',
  data: '0x...',
  value: parseEther('0.1'),
})

// With access list
const gas = await publicClient.estimateGas({
  account: '0x...',
  to: '0x...',
  accessList: [{ address: '0x...', storageKeys: ['0x...'] }],
})
```

---

### estimateFeesPerGas

**Docs**: `https://viem.sh/docs/actions/public/estimateFeesPerGas`  
**JSON-RPC**: `eth_maxPriorityFeePerGas`, `eth_call` (for fee history)  
**Source**: `src/actions/public/estimateFeesPerGas.ts`

```typescript
// Signature
export async function estimateFeesPerGas<
  chain extends Chain | undefined,
  chainOverride extends Chain | undefined,
  type extends FeeValuesType = 'eip1559',
>(
  client: Client<Transport, chain>,
  args?: EstimateFeesPerGasParameters<chain, chainOverride, type> | undefined,
): Promise<EstimateFeesPerGasReturnType<type>>
// Returns FeeValuesLegacy | FeeValuesEIP1559 depending on type
```

**Code Examples**:

```typescript
// EIP-1559 fees (default)
const fees = await publicClient.estimateFeesPerGas()
// { maxFeePerGas: 100n, maxPriorityFeePerGas: 5n }

// Legacy fees
const legacyFees = await publicClient.estimateFeesPerGas({ type: 'legacy' })
// { gasPrice: 20n }

// EIP-4844 blob fees
const blobFees = await publicClient.estimateFeesPerGas({ type: 'eip4844' })
// { maxFeePerGas: 100n, maxPriorityFeePerGas: 5n, blobBaseFee: 10n, priorityFeePerBlobGas: 2n }
```

---

### estimateMaxPriorityFeePerGas

**Docs**: `https://viem.sh/docs/actions/public/estimateMaxPriorityFeePerGas`  
**JSON-RPC**: `eth_maxPriorityFeePerGas`  
**Source**: `src/actions/public/estimateMaxPriorityFeePerGas.ts`

```typescript
// Signature
export async function estimateMaxPriorityFeePerGas<
  chain extends Chain | undefined,
  chainOverride extends Chain | undefined,
>(
  client: Client<Transport, chain>,
  args?: EstimateMaxPriorityFeePerGasParameters<chain, chainOverride> | undefined,
): Promise<EstimateMaxPriorityFeePerGasReturnType>  // Returns: bigint
```

**Code Examples**:

```typescript
const maxPriorityFee = await publicClient.estimateMaxPriorityFeePerGas()
// 5000000000n  (5 Gwei)

// With chain override
const maxPriorityFee = await publicClient.estimateMaxPriorityFeePerGas({
  chain: mainnet,
})
```

---

### getBlobBaseFee

**Docs**: `https://viem.sh/docs/actions/public/getBlobBaseFee`  
**JSON-RPC**: `eth_getBlobBaseFee` (EIP-4844)  
**Source**: `src/actions/public/getBlobBaseFee.ts`

```typescript
// Signature
export async function getBlobBaseFee<
  chain extends Chain | undefined,
  account extends Account | undefined,
>(
  client: Client<Transport, chain, account>,
): Promise<GetBlobBaseFeeReturnType>  // Returns: bigint
```

**Code Examples**:

```typescript
const blobBaseFee = await publicClient.getBlobBaseFee()
// 100000000n
```

---

## Chain & Network

### getChainId

**Docs**: `https://viem.sh/docs/actions/public/getChainId`  
**JSON-RPC**: `eth_chainId`  
**Source**: `src/actions/public/getChainId.ts`

```typescript
// Signature
export async function getChainId<
  chain extends Chain | undefined,
  account extends Account | undefined,
>(client: Client<Transport, chain, account>): Promise<GetChainIdReturnType>  // Returns: number
```

**Code Examples**:

```typescript
const chainId = await publicClient.getChainId()
// 1 (mainnet), 11155111 (Sepolia), etc.

if (chainId === 1) {
  console.log('Connected to mainnet')
}
```

---

### getEip712Domain

**Docs**: `https://viem.sh/docs/actions/public/getEip712Domain`  
**JSON-RPC**: `eth_call` (reads EIP-712 domain separator from contract)  
**Source**: `src/actions/public/getEip712Domain.ts`

```typescript
// Signature
export async function getEip712Domain(
  client: Client<Transport>,
  parameters: GetEip712DomainParameters,
): Promise<GetEip712DomainReturnType>
// Returns: { domain: RequiredBy<TypedDataDomain, 'chainId'|'name'|'verifyingContract'|'salt'|'version'>, fields: Hex, extensions: readonly bigint[] }
```

**Code Examples**:

```typescript
const domain = await publicClient.getEip712Domain({
  address: '0x...', // ERC-712 compliant contract
})
// { domain: { chainId: 1, name: '...', verifyingContract: '0x...', ... }, fields: '0x...', extensions: [...] }
```

---

## Logs & Events

### getLogs

**Docs**: `https://viem.sh/docs/actions/public/getLogs`  
**JSON-RPC**: `eth_getLogs`  
**Source**: `src/actions/public/getLogs.ts`

```typescript
// Signature
export async function getLogs<
  chain extends Chain | undefined,
  const abiEvent extends AbiEvent | undefined = undefined,
  const abiEvents extends readonly AbiEvent[] | readonly unknown[] | undefined =
    abiEvent extends AbiEvent ? [abiEvent] : undefined,
  strict extends boolean | undefined = undefined,
  fromBlock extends BlockNumber | BlockTag | undefined = undefined,
  toBlock extends BlockNumber | BlockTag | undefined = undefined,
>(
  client: Client<Transport, chain>,
  {
    address,
    blockHash,
    fromBlock,
    toBlock,
    event,
    events: events_,
    args,
    strict: strict_,
  }: GetLogsParameters<abiEvent, abiEvents, strict, fromBlock, toBlock> = {},
): Promise<GetLogsReturnType<abiEvent, abiEvents, strict, fromBlock, toBlock>>
```

**Code Examples**:

```typescript
// All logs from a contract
const logs = await publicClient.getLogs({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
})

// Filter by event
const logs = await publicClient.getLogs({
  address: '0x...',
  event: { name: 'Transfer', type: 'event', inputs: [
    { type: 'address', name: 'from', indexed: true },
    { type: 'address', name: 'to', indexed: true },
    { type: 'uint256', name: 'value' },
  ]},
})

// With args filter
const logs = await publicClient.getLogs({
  address: '0x...',
  event: 'Transfer',
  args: {
    from: '0xd8da6bf26964af9d7eed9e03e53415d37aa96045',
    to: '0xa5cc3c03994db5b0d9a5eedd10cabab0813678ac',
  },
  fromBlock: 16330000n,
  toBlock: 16330050n,
})

// By block hash (mutually exclusive with fromBlock/toBlock)
const logs = await publicClient.getLogs({
  address: '0x...',
  blockHash: '0x4ca7ee652d57678f26e887c149ab0735f41de37bcad58c9f6d3ed5824f15b74d',
})
```

---

### createEventFilter

**Docs**: `https://viem.sh/docs/actions/public/createEventFilter`  
**JSON-RPC**: `eth_newFilter`  
**Source**: `src/actions/public/createEventFilter.ts`

```typescript
// Signature
export async function createEventFilter<
  chain extends Chain | undefined,
  const abiEvent extends AbiEvent | undefined = undefined,
  const abiEvents extends readonly AbiEvent[] | readonly unknown[] | undefined =
    abiEvent extends AbiEvent ? [abiEvent] : undefined,
  strict extends boolean | undefined = undefined,
  fromBlock extends BlockNumber<bigint> | BlockTag | undefined = undefined,
  toBlock extends BlockNumber<bigint> | BlockTag | undefined = undefined,
  _eventName extends string | undefined = MaybeAbiEventName<abiEvent>,
  _args extends MaybeExtractEventArgsFromAbi<abiEvents, _eventName> | undefined = undefined,
>(
  client: Client<Transport, chain>,
  {
    address,
    args,
    event,
    events: events_,
    fromBlock,
    strict,
    toBlock,
  }: CreateEventFilterParameters<...> = {} as any,
): Promise<CreateEventFilterReturnType<...>>
```

**Code Examples**:

```typescript
const filter = await publicClient.createEventFilter({
  address: '0x...',
  event: 'Transfer',
  args: { from: '0x...' },
  fromBlock: 16330000n,
})
// { id: '0x...', type: 'event', ... }

// Use with getFilterChanges or getFilterLogs
const changes = await publicClient.getFilterChanges({ filter })
```

---

### createBlockFilter

**Docs**: `https://viem.sh/docs/actions/public/createBlockFilter`  
**JSON-RPC**: `eth_newFilter`  
**Source**: `src/actions/public/createBlockFilter.ts`

```typescript
// Signature
export async function createBlockFilter<chain extends Chain | undefined>(
  client: Client<Transport, chain>,
): Promise<CreateBlockFilterReturnType>  // Returns: Filter<'block'>
```

**Code Examples**:

```typescript
const filter = await publicClient.createBlockFilter()
// { id: '0x...', type: 'block' }

const blockHashes = await publicClient.getFilterChanges({ filter })
// ['0x...', '0x...']
```

---

### createPendingTransactionFilter

**Docs**: `https://viem.sh/docs/actions/public/createPendingTransactionFilter`  
**JSON-RPC**: `eth_newPendingTransactionFilter`  
**Source**: `src/actions/public/createPendingTransactionFilter.ts`

```typescript
// Signature
export async function createPendingTransactionFilter<
  transport extends Transport,
  chain extends Chain | undefined,
>(
  client: Client<transport, chain>,
): Promise<CreatePendingTransactionFilterReturnType>  // Returns: Filter<'transaction'>
```

**Code Examples**:

```typescript
const filter = await publicClient.createPendingTransactionFilter()
// { id: '0x345a6572337856574a76364e457a4366', type: 'transaction' }

const txHashes = await publicClient.getFilterChanges({ filter })
// ['0x...', '0x...']
```

---

### getFilterChanges

**Docs**: `https://viem.sh/docs/actions/public/getFilterChanges`  
**JSON-RPC**: `eth_getFilterChanges`  
**Source**: `src/actions/public/getFilterChanges.ts`

```typescript
// Signature
export async function getFilterChanges<
  transport extends Transport,
  chain extends Chain | undefined,
  filterType extends FilterType,
  const abi extends Abi | readonly unknown[] | undefined,
  eventName extends string | undefined,
  strict extends boolean | undefined = undefined,
  fromBlock extends BlockNumber | BlockTag | undefined = undefined,
  toBlock extends BlockNumber | BlockTag | undefined = undefined,
>(
  _client: Client<transport, chain>,
  { filter }: GetFilterChangesParameters<...>,
): Promise<GetFilterChangesReturnType<...>>
```

**Code Examples**:

```typescript
// With event filter
const logs = await publicClient.getFilterChanges({ filter })
// [{ address: '0x...', topics: [...], data: '0x...', ... }]

// With block filter
const blockHashes = await publicClient.getFilterChanges({ filter })
// ['0x...', '0x...']

// With pending transaction filter
const txHashes = await publicClient.getFilterChanges({ filter })
// ['0x...']
```

---

### getFilterLogs

**Docs**: `https://viem.sh/docs/actions/public/getFilterLogs`  
**JSON-RPC**: `eth_getFilterLogs`  
**Source**: `src/actions/public/getFilterLogs.ts`

```typescript
// Signature
export async function getFilterLogs<
  chain extends Chain | undefined,
  const abi extends Abi | readonly unknown[] | undefined,
  eventName extends string | undefined,
  strict extends boolean | undefined = undefined,
  fromBlock extends BlockNumber | BlockTag | undefined = undefined,
  toBlock extends BlockNumber | BlockTag | undefined = undefined,
>(
  _client: Client<Transport, chain>,
  { filter }: GetFilterLogsParameters<abi, eventName, strict, fromBlock, toBlock>,
): Promise<GetFilterLogsReturnType<...>>
```

**Code Examples**:

```typescript
const logs = await publicClient.getFilterLogs({ filter })
// [{ address: '0x...', topics: [...], data: '0x...', blockNumber: 69420n, ... }]
```

---

### watchEvent

**Docs**: `https://viem.sh/docs/actions/public/watchEvent`  
**Source**: `src/actions/public/watchEvent.ts`

```typescript
// Signature
export function watchEvent<
  chain extends Chain | undefined,
  const abiEvent extends AbiEvent | undefined = undefined,
  const abiEvents extends readonly AbiEvent[] | readonly unknown[] | undefined =
    abiEvent extends AbiEvent ? [abiEvent] : undefined,
  strict extends boolean | undefined = undefined,
  transport extends Transport = Transport,
  _eventName extends string | undefined = undefined,
>(
  client: Client<transport, chain>,
  {
    address,
    args,
    batch = true,
    event,
    events,
    fromBlock,
    onError,
    onLogs,
    poll: poll_,
    pollingInterval = client.pollingInterval,
    strict: strict_,
  }: WatchEventParameters<abiEvent, abiEvents, strict, transport>,
): WatchEventReturnType  // Returns: () => void
```

**Code Examples**:

```typescript
const unwatch = publicClient.watchEvent({
  address: '0x...',
  event: 'Transfer',
  onLogs: (logs) => console.log(logs),
})
// > [{ address: '0x...', topics: [...], args: { from: '0x...', to: '0x...', value: 1000n } }]
// > [{ ... }]

// With args filter
const unwatch = publicClient.watchEvent({
  address: '0x...',
  event: 'Transfer',
  args: { from: '0xd8da6bf26964af9d7eed9e03e53415d37aa96045' },
  onLogs: (logs) => console.log(logs),
})

// Batch mode (default)
const unwatch = publicClient.watchEvent({
  address: '0x...',
  event: 'Transfer',
  batch: true, // default
  onLogs: (logs) => console.log(logs), // fires with array of logs
})
```

---

### uninstallFilter

**Docs**: `https://viem.sh/docs/actions/public/uninstallFilter`  
**JSON-RPC**: `eth_uninstallFilter`  
**Source**: `src/actions/public/uninstallFilter.ts`

```typescript
// Signature
export async function uninstallFilter<
  transport extends Transport,
  chain extends Chain | undefined,
>(
  _client: Client<transport, chain>,
  { filter }: UninstallFilterParameters,
): Promise<UninstallFilterReturnType>  // Returns: boolean
```

**Code Examples**:

```typescript
const success = await publicClient.uninstallFilter({ filter })
// true if filter was uninstalled
```

---

## Execution

### call

**Docs**: `https://viem.sh/docs/actions/public/call`  
**JSON-RPC**: `eth_call`  
**Source**: `src/actions/public/call.ts`

```typescript
// Signature
export async function call<chain extends Chain | undefined>(
  client: Client<Transport, chain>,
  args: CallParameters<chain>,
): Promise<CallReturnType>  // Returns: { data: Hex | undefined }
```

**Code Examples**:

```typescript
const result = await publicClient.call({
  to: '0xContractAddress',
  data: '0x...',
})
// { data: '0x0000000000000000000000000000000000000000000000000000000000000420' }

// With value
const result = await publicClient.call({
  to: '0x...',
  value: parseEther('1'),
  data: '0x...',
})
```

---

### createAccessList

**Docs**: `https://viem.sh/docs/actions/public/createAccessList`  
**JSON-RPC**: `eth_createAccessList`  
**Source**: `src/actions/public/createAccessList.ts`

```typescript
// Signature
export async function createAccessList<chain extends Chain | undefined>(
  client: Client<Transport, chain>,
  args: CreateAccessListParameters<chain>,
): Promise<CreateAccessListReturnType>
// Returns: Prettify<{ accessList: AccessList; gasUsed: bigint }>
```

**Code Examples**:

```typescript
const { accessList, gasUsed } = await publicClient.createAccessList({
  account: '0x...',
  to: '0x...',
  data: '0x...',
})
// { accessList: [{ address: '0x...', storageKeys: ['0x...'] }], gasUsed: 21000n }
```

---

### simulateCalls

**Docs**: `https://viem.sh/docs/actions/public/simulateCalls`  
**JSON-RPC**: `eth_call` (bundled)  
**Source**: `src/actions/public/simulateCalls.ts`

```typescript
// Signature
export async function simulateCalls<
  const calls extends readonly unknown[],
  chain extends Chain | undefined,
  account extends Account | Address | undefined = undefined,
>(
  client: Client<Transport, chain>,
  parameters: SimulateCallsParameters<calls, account>,
): Promise<SimulateCallsReturnType<calls>>
// Returns: { assetChanges: readonly { token, value }[], block: Block, results: MulticallResults<...> }
```

**Code Examples**:

```typescript
const result = await publicClient.simulateCalls({
  calls: [
    { to: '0x...', data: '0x...', value: 0n },
    { to: '0x...', data: '0x...', value: 0n },
  ],
  account: '0x...',
})
// { assetChanges: [...], block: {...}, results: [...] }
```

---

### simulateBlocks

**Docs**: `https://viem.sh/docs/actions/public/simulateBlocks`  
**Source**: `src/actions/public/simulateBlocks.ts`

```typescript
// Signature
export async function simulateBlocks<
  chain extends Chain | undefined,
  const calls extends readonly unknown[],
>(
  client: Client<Transport, chain>,
  parameters: SimulateBlocksParameters<calls>,
): Promise<SimulateBlocksReturnType<calls>>
// Returns: readonly (Block & { calls: MulticallResults<...> })[]
```

**Code Examples**:

```typescript
const result = await publicClient.simulateBlocks({
  calls: [
    { to: '0x...', data: '0x...' },
  ],
})
// [{ number: 69420n, calls: [...], ... }]
```

---

## Verification

### verifyMessage

**Docs**: `https://viem.sh/docs/actions/public/verifyMessage`  
**Source**: `src/actions/public/verifyMessage.ts`

```typescript
// Signature
export async function verifyMessage<chain extends Chain | undefined>(
  client: Client<Transport, chain>,
  {
    address,
    message,
    factory,
    factoryData,
    signature,
    ...callRequest
  }: VerifyMessageParameters,
): Promise<VerifyMessageReturnType>  // Returns: boolean
```

**Code Examples**:

```typescript
const isValid = await publicClient.verifyMessage({
  address: '0x...',
  message: 'hello world',
  signature: '0x...',
})
// true

// With ERC-1271 factory (Smart Contract Wallet)
const isValid = await publicClient.verifyMessage({
  address: '0x...', // Smart contract wallet address
  message: 'hello world',
  signature: '0x...',
  factory: '0x...', // ERC-1271 factory address
  factoryData: '0x...',
})
```

---

### verifyTypedData

**Docs**: `https://viem.sh/docs/actions/public/verifyTypedData`  
**Source**: `src/actions/public/verifyTypedData.ts`

```typescript
// Signature
export async function verifyTypedData<
  const typedData extends TypedData | Record<string, unknown>,
  primaryType extends keyof typedData | 'EIP712Domain',
  chain extends Chain | undefined,
>(
  client: Client<Transport, chain>,
  parameters: VerifyTypedDataParameters<typedData, primaryType>,
): Promise<VerifyTypedDataReturnType>  // Returns: boolean
```

**Code Examples**:

```typescript
const isValid = await publicClient.verifyTypedData({
  address: '0x...',
  domain: {
    name: 'Ether Mail',
    version: '1',
    chainId: 1,
    verifyingContract: '0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC',
  },
  types: {
    Person: [
      { name: 'name', type: 'string' },
      { name: 'wallet', type: 'address' },
    ],
    Mail: [
      { name: 'from', type: 'Person' },
      { name: 'to', type: 'Person' },
      { name: 'contents', type: 'string' },
    ],
  },
  primaryType: 'Mail',
  message: {
    from: { name: 'Cow', wallet: '0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826' },
    to: { name: 'Bob', wallet: '0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB' },
    contents: 'Hello, Bob!',
  },
  signature: '0x...',
})
// true
```

---

# Wallet Actions

## Table of Contents

- [Account](#account)
  - [getAddresses](#getaddresses) · [requestAddresses](#requestaddresses) · [getPermissions](#getpermissions) · [requestPermissions](#requestpermissions)
- [Chain](#chain)
  - [addChain](#addchain) · [switchChain](#switchchain) · [watchAsset](#watchasset)
- [Transaction](#transaction-1)
  - [sendTransaction](#sendtransaction) · [signTransaction](#signtransaction) · [sendRawTransaction](#sendrawtransaction-wallet) · [sendRawTransactionSync](#sendrawtransactionsync) · [sendTransactionSync](#sendtransactionsync) · [prepareTransactionRequest](#preparetransactionrequest)
- [Signing](#signing)
  - [signMessage](#signmessage) · [signTypedData](#signtypeddata)
- [EIP-5792 Bundle Calls (Account Abstraction)](#eip-5792-bundle-calls-account-abstraction)
  - [getCapabilities](#getcapabilities) · [sendCalls](#sendcalls) · [sendCallsSync](#sendcallssync) · [getCallsStatus](#getcallsstatus) · [waitForCallsStatus](#waitforcallsstatus) · [showCallsStatus](#showcallsstatus)

---

## Account

### getAddresses

**Docs**: `https://viem.sh/docs/actions/wallet/getAddresses`  
**Source**: `src/actions/wallet/getAddresses.ts`

```typescript
// Signature
export async function getAddresses<
  chain extends Chain | undefined,
  account extends Account | undefined = undefined,
>(client: Client<Transport, chain, account>): Promise<GetAddressesReturnType>  // Returns: Address[]
```

**Code Examples**:

```typescript
const addresses = await walletClient.getAddresses()
// ['0x...']

// With multiple accounts (JSON-RPC)
const addresses = await walletClient.getAddresses()
```

---

### requestAddresses

**Docs**: `https://viem.sh/docs/actions/wallet/requestAddresses`  
**Source**: `src/actions/wallet/requestAddresses.ts`

```typescript
// Signature
export async function requestAddresses<
  chain extends Chain | undefined,
  account extends Account | undefined = undefined,
>(client: Client<Transport, chain, account>): Promise<RequestAddressesReturnType>  // Returns: Address[]
```

**Code Examples**:

```typescript
const addresses = await walletClient.requestAddresses()
// Prompts user to connect in wallet
// ['0x...']
```

---

### getPermissions

**Docs**: `https://viem.sh/docs/actions/wallet/getPermissions`  
**Source**: `src/actions/wallet/getPermissions.ts`

```typescript
// Signature
export async function getPermissions<
  chain extends Chain | undefined,
  account extends Account | undefined = undefined,
>(client: Client<Transport, chain, account>)
```

**Code Examples**:

```typescript
const permissions = await walletClient.getPermissions()
// [{ id: '0x...', entity: { type: 'address', address: '0x...' }, context: '0x...', ... }]
```

---

### requestPermissions

**Docs**: `https://viem.sh/docs/actions/wallet/requestPermissions`  
**Source**: `src/actions/wallet/requestPermissions.ts`

```typescript
// Signature
export async function requestPermissions<
  chain extends Chain | undefined,
  account extends Account | undefined = undefined,
>(client: Client<Transport, chain, account>, permissions: RequestPermissionsParameters)
```

**Code Examples**:

```typescript
const permissions = await walletClient.requestPermissions({
  eth_accounts: {},
})
// Prompts user to grant permissions
// [{ id: '0x...', entity: { type: 'address', ... }, context: '0x...', ... }]
```

---

## Chain

### addChain

**Docs**: `https://viem.sh/docs/actions/wallet/addChain`  
**Source**: `src/actions/wallet/addChain.ts`

```typescript
// Signature
export async function addChain<
  chain extends Chain | undefined,
  account extends Account | undefined,
>(client: Client<Transport, chain, account>, { chain }: AddChainParameters)  // Returns: void
```

**Code Examples**:

```typescript
import { polygon } from 'viem/chains'

await walletClient.addChain({ chain: polygon })
```

---

### switchChain

**Docs**: `https://viem.sh/docs/actions/wallet/switchChain`  
**Source**: `src/actions/wallet/switchChain.ts`

```typescript
// Signature
export async function switchChain<
  chain extends Chain | undefined,
  account extends Account | undefined = undefined,
>(client: Client<Transport, chain, account>, { id }: SwitchChainParameters)  // Returns: void
```

**Code Examples**:

```typescript
await walletClient.switchChain({ id: 137 })  // Polygon
await walletClient.switchChain({ id: 1 })       // Mainnet
```

---

### watchAsset

**Docs**: `https://viem.sh/docs/actions/wallet/watchAsset`  
**Source**: `src/actions/wallet/watchAsset.ts`

```typescript
// Signature
export async function watchAsset<
  chain extends Chain | undefined,
  account extends Account | undefined = undefined,
>(client: Client<Transport, chain, account>, params: WatchAssetParameters): Promise<WatchAssetReturnType>  // Returns: boolean
```

**Code Examples**:

```typescript
const success = await walletClient.watchAsset({
  type: 'ERC20',
  options: {
    address: '0x...',   // Token contract address
    symbol: 'DAI',
    decimals: 18,
  },
})
// Prompts user to add token to wallet
// true
```

---

## Transaction

### sendTransaction

**Docs**: `https://viem.sh/docs/actions/wallet/sendTransaction`  
**JSON-RPC**: `eth_sendTransaction`  
**Source**: `src/actions/wallet/sendTransaction.ts`

```typescript
// Signature
export async function sendTransaction<
  chain extends Chain | undefined,
  account extends Account | undefined,
  chainOverride extends Chain | undefined = undefined,
>(
  client: Client<Transport, chain, account>,
  args: SendTransactionParameters<chain, account, chainOverride>,
): Promise<SendTransactionReturnType>  // Returns: Hash
```

**Code Examples**:

```typescript
const hash = await walletClient.sendTransaction({
  account: '0x...',
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
  value: parseEther('1'),
})

// With full options
const hash = await walletClient.sendTransaction({
  account: '0x...',
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
  value: parseEther('1'),
  gas: 21000n,
  // gasPrice is for legacy transactions; do not combine it with EIP-1559 fees.
  maxFeePerGas: parseGwei('100'),
  maxPriorityFeePerGas: parseGwei('2'),
  nonce: 69,
  data: '0x...',
  accessList: [{ address: '0x...', storageKeys: ['0x...'] }],
  authorizationList: [signedAuthorization],  // EIP-7702
  chain: mainnet,
})
```

---

### signTransaction

**Docs**: `https://viem.sh/docs/actions/wallet/signTransaction`  
**Source**: `src/actions/wallet/signTransaction.ts`

```typescript
// Signature
export async function signTransaction<
  chain extends Chain | undefined,
  account extends Account | undefined,
>(
  client: Client<Transport, chain, account>,
  args: SignTransactionParameters<chain, account>,
): Promise<SignTransactionReturnType>  // Returns: Hex
```

**Code Examples**:

```typescript
const signedTx = await walletClient.signTransaction({
  account: '0x...',
  to: '0x...',
  value: parseEther('1'),
  gas: 21000n,
  nonce: 0,
  gasPrice: parseGwei('20'),
})
// '0x02f850018203118080825208808080c080a04...'

// Then broadcast with sendRawTransaction
const hash = await walletClient.sendRawTransaction({ serializedTransaction: signedTx })
```

---

### sendRawTransaction (Wallet)

**Docs**: `https://viem.sh/docs/actions/wallet/sendRawTransaction`  
**JSON-RPC**: `eth_sendRawTransaction`  
**Source**: `src/actions/wallet/sendRawTransaction.ts`

```typescript
// Signature
export async function sendRawTransaction<chain extends Chain | undefined>(
  client: Client<Transport, chain>,
  { serializedTransaction }: SendRawTransactionParameters,
): Promise<SendRawTransactionReturnType>  // Returns: Hash
```

**Code Examples**:

```typescript
const signedTx = await walletClient.signTransaction({ ... })
const hash = await walletClient.sendRawTransaction({
  serializedTransaction: signedTx,
})
```

---

### sendRawTransactionSync

**Docs**: `https://viem.sh/docs/actions/wallet/sendRawTransactionSync`  
**JSON-RPC**: `eth_sendRawTransaction` + `eth_getTransactionReceipt`  
**Source**: `src/actions/wallet/sendRawTransactionSync.ts`

```typescript
// Signature
export async function sendRawTransactionSync<chain extends Chain | undefined>(
  client: Client<Transport, chain>,
  { serializedTransaction, throwOnReceiptRevert, timeout }: SendRawTransactionSyncParameters,
): Promise<SendRawTransactionSyncReturnType<chain>>  // Returns: FormattedTransactionReceipt<chain>
```

**Code Examples**:

```typescript
const signedTx = await walletClient.signTransaction({ ... })
const receipt = await walletClient.sendRawTransactionSync({
  serializedTransaction: signedTx,
  throwOnReceiptRevert: true,  // throws if transaction reverts
  timeout: 30_000,             // 30 second timeout
})
// Returns the transaction receipt immediately
// { transactionHash, status, gasUsed, logs, ... }
```

---

### sendTransactionSync

**Docs**: `https://viem.sh/docs/actions/wallet/sendTransactionSync`  
**Source**: `src/actions/wallet/sendTransactionSync.ts`

```typescript
// Signature
export async function sendTransactionSync<
  chain extends Chain | undefined,
  account extends Account | undefined,
  const request extends SendTransactionSyncRequest<chain, chainOverride>,
  chainOverride extends Chain | undefined = undefined,
>(
  client: Client<Transport, chain, account>,
  parameters: SendTransactionSyncParameters<chain, account, chainOverride, request>,
): Promise<SendTransactionSyncReturnType<chain>>
// Returns: FormattedTransactionReceipt<chain>
```

**Code Examples**:

```typescript
// Combines signTransaction + sendRawTransactionSync in one step
const receipt = await walletClient.sendTransactionSync({
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
  value: parseEther('1'),
  throwOnReceiptRevert: true,
})
// { transactionHash, status: 'success', gasUsed: 21000n, ... }
```

---

### prepareTransactionRequest

**Docs**: `https://viem.sh/docs/actions/wallet/prepareTransactionRequest`  
**Source**: `src/actions/wallet/prepareTransactionRequest.ts`

```typescript
// Signature
export async function prepareTransactionRequest<
  chain extends Chain | undefined,
  account extends Account | undefined,
  const request extends PrepareTransactionRequestRequest<chain, chainOverride>,
  accountOverride extends Account | Address | undefined = undefined,
  chainOverride extends Chain | undefined = undefined,
>(
  client: Client<Transport, chain, account>,
  args: PrepareTransactionRequestParameters<chain, account, chainOverride, accountOverride, request>,
): Promise<PrepareTransactionRequestReturnType<chain, account, chainOverride, accountOverride, request>>
```

**Code Examples**:

```typescript
const request = await walletClient.prepareTransactionRequest({
  account: '0x...',
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
  value: parseEther('1'),
})
// Returns populated transaction request with gas, nonce, chainId, etc.
// { account: '0x...', to: '0x...', value: 1000000000000000000n, gas: 21000n, nonce: 69, chainId: 1, data: '0x...', ... }
```

---

## Signing

### signMessage

**Docs**: `https://viem.sh/docs/actions/wallet/signMessage`  
**Source**: `src/actions/wallet/signMessage.ts`

```typescript
// Signature
export async function signMessage<
  chain extends Chain | undefined,
  account extends Account | undefined,
>(
  client: Client<Transport, chain, account>,
  args: SignMessageParameters<account>,
): Promise<SignMessageReturnType>  // Returns: Hex
```

**Code Examples**:

```typescript
// String message
const signature = await walletClient.signMessage({
  account: '0x...',
  message: 'hello world',
})
// '0x...'

// Raw bytes
const signature = await walletClient.signMessage({
  account: '0x...',
  message: { raw: '0x48656c6c6f20576f726c64' },  // "Hello World" in hex
})

// Unicode string
const signature = await walletClient.signMessage({
  account: '0x...',
  message: 'こんにちは世界',
})
```

---

### signTypedData

**Docs**: `https://viem.sh/docs/actions/wallet/signTypedData`  
**Source**: `src/actions/wallet/signTypedData.ts`

```typescript
// Signature
export async function signTypedData<
  const typedData extends TypedData | Record<string, unknown>,
  primaryType extends keyof typedData | 'EIP712Domain',
  chain extends Chain | undefined,
  account extends Account | undefined,
>(
  client: Client<Transport, chain, account>,
  args: SignTypedDataParameters<typedData, primaryType, account>,
): Promise<SignTypedDataReturnType>  // Returns: Hex
```

**Code Examples**:

```typescript
const signature = await walletClient.signTypedData({
  account: '0x...',
  domain: {
    name: 'Ether Mail',
    version: '1',
    chainId: 1,
    verifyingContract: '0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC',
  },
  types: {
    Person: [
      { name: 'name', type: 'string' },
      { name: 'wallet', type: 'address' },
    ],
    Mail: [
      { name: 'from', type: 'Person' },
      { name: 'to', type: 'Person' },
      { name: 'contents', type: 'string' },
    ],
  },
  primaryType: 'Mail',
  message: {
    from: { name: 'Cow', wallet: '0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826' },
    to: { name: 'Bob', wallet: '0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB' },
    contents: 'Hello, Bob!',
  },
})
// '0x...'
```

---

## EIP-5792 Bundle Calls (Account Abstraction)

### getCapabilities

**Docs**: `https://viem.sh/docs/actions/wallet/getCapabilities`  
**Source**: `src/actions/wallet/getCapabilities.ts`

```typescript
// Signature
export async function getCapabilities<
  chainId extends number | undefined = undefined,
>(client: Client<Transport>, parameters: GetCapabilitiesParameters<chainId> = {}): Promise<GetCapabilitiesReturnType<chainId>>
```

**Code Examples**:

```typescript
const capabilities = await walletClient.getCapabilities()
// { paymaster: '0x...', signTypedData: '0.1', ... }

// For specific chain
const capabilities = await walletClient.getCapabilities({ chainId: 1 })
```

---

### sendCalls

**Docs**: `https://viem.sh/docs/actions/wallet/sendCalls`  
**JSON-RPC**: `eth_sendCalls` (EIP-5792)  
**Source**: `src/actions/wallet/sendCalls.ts`

```typescript
// Signature
export async function sendCalls<
  const calls extends readonly unknown[],
  chain extends Chain | undefined,
  account extends Account | undefined = undefined,
  chainOverride extends Chain | undefined = undefined,
>(
  client: Client<Transport, chain, account>,
  parameters: SendCallsParameters<chain, account, chainOverride, calls>,
): Promise<SendCallsReturnType>
// Returns: Prettify<{ capabilities?: ExtractCapabilities<'sendCalls', 'ReturnType'> | undefined; id: string }>
```

**Code Examples**:

```typescript
const result = await walletClient.sendCalls({
  account: '0x...',
  calls: [
    { to: '0x...', value: parseEther('0.1') },
    { to: '0x...', data: '0x...', value: 0n },
  ],
})
// { id: '0x...', capabilities: {...} }
```

---

### sendCallsSync

**Docs**: `https://viem.sh/docs/actions/wallet/sendCallsSync`  
**JSON-RPC**: `eth_sendCalls` + waits for receipt  
**Source**: `src/actions/wallet/sendCallsSync.ts`

```typescript
// Signature
export async function sendCallsSync<
  const calls extends readonly unknown[],
  chain extends Chain | undefined,
  account extends Account | undefined = undefined,
  chainOverride extends Chain | undefined = undefined,
>(
  client: Client<Transport, chain, account>,
  parameters: SendCallsSyncParameters<chain, account, chainOverride, calls>,
): Promise<SendCallsSyncReturnType>  // Returns: GetCallsStatusReturnType
```

**Code Examples**:

```typescript
const status = await walletClient.sendCallsSync({
  account: '0x...',
  calls: [{ to: '0x...', value: parseEther('0.1') }],
})
// Waits for all calls to be included, returns status
```

---

### getCallsStatus

**Docs**: `https://viem.sh/docs/actions/wallet/getCallsStatus`  
**JSON-RPC**: `eth_getCallsStatus` (EIP-5792)  
**Source**: `src/actions/wallet/getCallsStatus.ts`

```typescript
// Signature
export async function getCallsStatus<
  chain extends Chain | undefined,
  account extends Account | undefined = undefined,
>(
  client: Client<Transport, chain, account>,
  parameters: GetCallsStatusParameters,
): Promise<GetCallsStatusReturnType>
```

**Code Examples**:

```typescript
const status = await walletClient.getCallsStatus({
  account: '0x...',
  id: '0x...',  // from sendCalls result
})
// { status: 'confirmed', receipts: [...] }
```

---

### waitForCallsStatus

**Docs**: `https://viem.sh/docs/actions/wallet/waitForCallsStatus`  
**JSON-RPC**: Polls `eth_getCallsStatus`  
**Source**: `src/actions/wallet/waitForCallsStatus.ts`

```typescript
// Signature
export async function waitForCallsStatus<
  chain extends Chain | undefined,
>(
  client: Client<Transport, chain>,
  parameters: WaitForCallsStatusParameters,
): Promise<WaitForCallsStatusReturnType>  // Returns: GetCallsStatusReturnType
```

**Code Examples**:

```typescript
const status = await walletClient.waitForCallsStatus({
  id: '0x...',
  timeout: 30_000,
})
```

---

### showCallsStatus

**Docs**: `https://viem.sh/docs/actions/wallet/showCallsStatus`  
**JSON-RPC**: `eth_showCallsStatus` (EIP-5792)  
**Source**: `src/actions/wallet/showCallsStatus.ts`

```typescript
// Signature
export async function showCallsStatus<
  chain extends Chain | undefined,
  account extends Account | undefined = undefined,
>(
  client: Client<Transport, chain, account>,
  parameters: ShowCallsStatusParameters,
): Promise<ShowCallsStatusReturnType>  // Returns: void
```

**Code Examples**:

```typescript
await walletClient.showCallsStatus({
  account: '0x...',
  id: '0x...',  // from sendCalls result
})
// Shows UI in wallet showing status of bundle calls
```

---

# Contract Actions

> Contract actions are callable on Public Clients (read-only) or Wallet Clients (write).  
> Docs base: `https://viem.sh/docs/contract/<actionName>`

## Table of Contents

- [Contract Instance](#contract-instance-getcontract)
- [Reading & Estimating](#reading--estimating)
  - [readContract](#readcontract) · [estimateContractGas](#estimatecontractgas)
- [Writing](#writing)
  - [writeContract](#writecontract) · [writeContractSync](#writecontractsync) · [deployContract](#deploycontract)
- [Simulating](#simulating)
  - [simulateContract](#simulatecontract)
- [Batching](#batching)
  - [multicall](#multicall)
- [Events](#events-contract)
  - [getContractEvents](#getcontractevents) · [watchContractEvent](#watchcontractevent) · [createContractEventFilter](#createcontracteventfilter)

---

## Contract Instance (getContract)

**Docs**: `https://viem.sh/docs/contract/getContract`  
**Source**: `src/actions/getContract.ts`

```typescript
// Creates a typed contract instance. Not a viem action function per se — a utility.
// But the contract instance exposes these methods as callable functions:
// With Public Client: read, estimateGas, createEventFilter, getEvents, watchEvent, simulate
// With Wallet Client: write, estimateGas
```

**Code Examples**:

```typescript
import { getContract } from 'viem'
import { wagmiAbi } from './abi'
import { publicClient, walletClient } from './client'

// Create contract instance with both clients
const contract = getContract({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: wagmiAbi,
  client: { public: publicClient, wallet: walletClient },
})

// Read (public action)
const totalSupply = await contract.read.totalSupply()
// const balance = await contract.read.balanceOf(['0xa5cc3c03994DB5b0d9A5eEdD10CabaB0813678AC'])

// Write (wallet action)
const hash = await contract.write.mint([69420n])

// Read events
const logs = await contract.getEvents.Transfer({ fromBlock: 16330000n })

// Watch events (returns unwatch fn)
const unwatch = contract.watchEvent.Transfer(
  { from: '0xd8da6bf26964af9d7eed9e03e53415d37aa96045' },
  { onLogs: (logs) => console.log(logs) }
)

// Filter events
const filter = await contract.createEventFilter.Transfer({ from: '0x...' })
```

---

## Reading & Estimating

### readContract

**Docs**: `https://viem.sh/docs/contract/readContract`  
**JSON-RPC**: `eth_call`  
**Source**: `src/actions/public/readContract.ts`

```typescript
// Signature (via contract method call via getContract)
const result = await contract.read.totalSupply()
// Or standalone:
const totalSupply = await publicClient.readContract({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: wagmiAbi,
  functionName: 'totalSupply',
})

const balance = await publicClient.readContract({
  address: '0x...',
  abi: wagmiAbi,
  functionName: 'balanceOf',
  args: ['0xa5cc3c03994DB5b0d9A5eEdD10CabaB0813678AC'],
})
```

**Parameters**:

| Name | Type | Description |
|------|------|-------------|
| `address` | Address | Contract address |
| `abi` | Abi | Contract ABI |
| `functionName` | string | Function name |
| `args` | inferred | Function arguments |
| `account` | Account \| Address (optional) | Sender override |
| `blockNumber` | bigint (optional) | Block number |
| `blockTag` | BlockTag (optional) | Block tag |
| `factory` | Address (optional) | Deploy factory for deployless calls |
| `factoryData` | Hex (optional) | Calldata for factory |
| `stateOverride` | StateOverride[] (optional) | Mock contract state |

**Code Examples**:

```typescript
// Basic read
const totalSupply = await publicClient.readContract({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: wagmiAbi,
  functionName: 'totalSupply',
})
// 69420n

// With args
const balance = await publicClient.readContract({
  address: '0x...',
  abi: wagmiAbi,
  functionName: 'balanceOf',
  args: ['0xa5cc3c03994DB5b0d9A5eEdD10CabaB0813678AC'],
})

// Deployless call (no contract deployed)
const name = await publicClient.readContract({
  abi: parseAbi(['function name() view returns (string)']),
  code: '0x...',  // bytecode of undeployed contract
  functionName: 'name',
})

// State override (mock storage)
const result = await publicClient.readContract({
  address: tokenAddress,
  abi: tokenAbi,
  functionName: 'balanceOf',
  args: [userAddress],
  stateOverride: [{
    address: tokenAddress,
    stateDiff: [{
      slot: '0x...',
      value: '0x0000000000000000000000000000000000000000000000000000000000000420',
    }],
  }],
})
```

---

### estimateContractGas

**Docs**: `https://viem.sh/docs/contract/estimateContractGas`  
**JSON-RPC**: `eth_estimateGas`  
**Source**: `src/actions/public/estimateContractGas.ts`

```typescript
// Signature
export async function estimateContractGas<
  const abi extends Abi | readonly unknown[],
  functionName extends ContractFunctionName<abi, 'nonpayable' | 'payable'>,
  args extends ContractFunctionArgs<abi, 'pure' | 'view', functionName>,
  chain extends Chain | undefined,
  account extends Account | undefined = undefined,
>(
  client: Client<Transport, chain>,
  parameters: EstimateContractGasParameters<abi, functionName, args, chain, account>,
): Promise<EstimateContractGasReturnType>  // Returns: bigint
```

**Code Examples**:

```typescript
const gas = await publicClient.estimateContractGas({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: wagmiAbi,
  functionName: 'mint',
  args: [69420n],
  account: '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266',
})
// 69420n
```

---

## Writing

### writeContract

**Docs**: `https://viem.sh/docs/contract/writeContract`  
**JSON-RPC**: `eth_sendTransaction` (via sendTransaction internally)  
**Source**: `src/actions/wallet/writeContract.ts`

```typescript
// Signature
export async function writeContract<
  chain extends Chain | undefined,
  account extends Account | undefined,
  const abi extends Abi | readonly unknown[],
  functionName extends ContractFunctionName<abi, 'nonpayable' | 'payable'>,
  args extends ContractFunctionArgs<abi, 'nonpayable' | 'payable', functionName>,
  chainOverride extends Chain | undefined,
>(
  client: Client<Transport, chain, account>,
  parameters: WriteContractParameters<abi, functionName, args, chain, account, chainOverride>,
): Promise<WriteContractReturnType>  // Returns: Hash
```

**Code Examples**:

```typescript
// Standalone
const hash = await walletClient.writeContract({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: wagmiAbi,
  functionName: 'mint',
  args: [69420],
})
// '0x...'

// Recommended: simulate first
const { request } = await publicClient.simulateContract({
  address: '0x...',
  abi: wagmiAbi,
  functionName: 'mint',
  args: [69420],
  account: '0x...',
})
const hash = await walletClient.writeContract(request)

// With full options
const hash = await walletClient.writeContract({
  address: '0x...',
  abi: wagmiAbi,
  functionName: 'mint',
  args: [69420],
  account: '0x...',
  value: parseEther('1'),         // msg.value
  gas: 100000n,                     // skip estimation
  maxFeePerGas: parseGwei('100'),
  maxPriorityFeePerGas: parseGwei('2'),
  nonce: 69,
  accessList: [{ address: '0x...', storageKeys: ['0x...'] }],
  authorizationList: [signedAuthorization],  // EIP-7702
  dataSuffix: '0xdeadbeef',       // append to calldata
})
```

---

### writeContractSync

**Docs**: `https://viem.sh/docs/contract/writeContractSync`  
**JSON-RPC**: `eth_sendTransaction` + waits for receipt  
**Source**: `src/actions/wallet/writeContractSync.ts`

```typescript
// Signature
export async function writeContractSync<
  chain extends Chain | undefined,
  account extends Account | undefined,
  const abi extends Abi | readonly unknown[],
  functionName extends ContractFunctionName<abi, 'nonpayable' | 'payable'>,
  args extends ContractFunctionArgs<abi, 'nonpayable' | 'payable', functionName>,
  chainOverride extends Chain | undefined,
>(
  client: Client<Transport, chain, account>,
  parameters: WriteContractSyncParameters<...>,
): Promise<WriteContractSyncReturnType<chain>>  // Returns: FormattedTransactionReceipt<chain>
```

**Code Examples**:

```typescript
// Writes and waits for receipt — returns receipt instead of hash
const receipt = await walletClient.writeContractSync({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: wagmiAbi,
  functionName: 'mint',
  args: [69420],
  throwOnReceiptRevert: true,  // throws if transaction reverts
  timeout: 30_000,
})
// { transactionHash, status: 'success', gasUsed: 69420n, logs: [...], ... }
```

---

### deployContract

**Docs**: `https://viem.sh/docs/contract/deployContract`  
**JSON-RPC**: `eth_sendTransaction`  
**Source**: `src/actions/wallet/deployContract.ts`

```typescript
// Signature
export function deployContract<
  const abi extends Abi | readonly unknown[],
  chain extends Chain | undefined,
  account extends Account | undefined,
  chainOverride extends Chain | undefined,
>(
  walletClient: Client<Transport, chain, account>,
  parameters: DeployContractParameters<abi, chain, account, chainOverride>,
): Promise<DeployContractReturnType>  // Returns: Hash (transaction hash)
```

**Code Examples**:

```typescript
import { deployContract } from 'viem'

// Basic deployment
const hash = await walletClient.deployContract({
  abi: [],
  account: '0x...',
  bytecode: '0x608060405260405161083e38038061083e833981016040819052610...',
})
// '0x...'

// With constructor args
const hash = await walletClient.deployContract({
  abi: [
    'constructor(address owner)',
    'function mint(uint32 tokenId) nonpayable',
  ],
  account: '0x...',
  bytecode: '0x608060405260405161083e38038061083e833981016040819052610...',
  args: ['0xOwnerAddress'],
})

// With Wagmi-style config
const hash = await walletClient.deployContract({
  abi: wagmiAbi,
  account: '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266',
  bytecode: '0x608060405260405161083e38038061083e833981016040819052610...',
  args: [69420],
})
```

---

## Simulating

### simulateContract

**Docs**: `https://viem.sh/docs/contract/simulateContract`  
**JSON-RPC**: `eth_call`  
**Source**: `src/actions/public/simulateContract.ts`

```typescript
// Signature (returns { result, ... } + a request object for writeContract)
const { result, ... } = await publicClient.simulateContract({
  address: '0x...',
  abi: wagmiAbi,
  functionName: 'mint',
  args: [69420],
  account: '0x...',
})
// Returns { result: ..., request: ReadyTransactionRequest } for use with writeContract
```

**Code Examples**:

```typescript
// Basic simulation
const { result } = await publicClient.simulateContract({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: wagmiAbi,
  functionName: 'mint',
  account: '0x...',
  args: [69420],
})
// result: 0n (no return value for mint)

// Pair with writeContract (recommended pattern)
const { request } = await publicClient.simulateContract({
  address: '0x...',
  abi: wagmiAbi,
  functionName: 'mint',
  args: [69420],
  account: '0x...',
})
const hash = await walletClient.writeContract(request)

// With state override
const { result } = await publicClient.simulateContract({
  address: tokenAddress,
  abi: tokenAbi,
  functionName: 'transferFrom',
  args: [from, to, 69420n],
  stateOverride: [{
    address: tokenAddress,
    stateDiff: [{
      slot: allowanceSlot,
      value: maxAllowance,
    }],
  }],
})

// Handling custom errors
try {
  await publicClient.simulateContract({ ... })
} catch (err) {
  if (err instanceof BaseError) {
    const revert = err.walk(e => e instanceof ContractFunctionRevertedError)
    if (revert instanceof ContractFunctionRevertedError) {
      console.log(revert.data?.errorName)  // e.g. 'Unauthorized'
    }
  }
}
```

---

## Batching

### multicall

**Docs**: `https://viem.sh/docs/contract/multicall`  
**JSON-RPC**: `eth_call` (via multicall3 contract)  
**Source**: `src/actions/public/multicall.ts`

```typescript
// Signature (via publicClient)
const results = await publicClient.multicall({
  contracts: [
    { address: '0x...', abi: wagmiAbi, functionName: 'totalSupply' },
    { address: '0x...', abi: wagmiAbi, functionName: 'ownerOf', args: [69420n] },
    { address: '0x...', abi: wagmiAbi, functionName: 'mint' },
  ],
  allowFailure: true,  // default: true — continues if one call fails
})
// [{ result: 424122n, status: 'success' }, { result: '0xc961...', status: 'success' }, { error: [...], status: 'failure' }]
```

**Parameters**:

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `contracts` | Array | required | Array of {address, abi, functionName, args?} |
| `allowFailure` | boolean | `true` | Don't throw if a call reverts |
| `account` | Address (optional) | — | Account for the call |
| `batchSize` | number (optional) | 1024 | Max bytes per calldata chunk |
| `blockNumber` | bigint (optional) | — | Block number |
| `deployless` | boolean (optional) | `false` | Enable deployless multicall |
| `multicallAddress` | Address (optional) | chain's multicall3 | Custom multicall contract |
| `stateOverride` | StateOverride[] (optional) | — | Mock state |

**Code Examples**:

```typescript
// Basic batching
const [totalSupply, owner] = await publicClient.multicall({
  contracts: [
    { address: '0x...', abi: wagmiAbi, functionName: 'totalSupply' },
    { address: '0x...', abi: wagmiAbi, functionName: 'ownerOf', args: [69420n] },
  ],
})
// [424122n, '0xc961145a54C96E3aE9bAA048c4F4D6b04C13916b']

// Strict mode (throws on any failure)
const results = await publicClient.multicall({
  contracts: [...],
  allowFailure: false,
})

// With custom multicall address
const results = await publicClient.multicall({
  contracts: [...],
  multicallAddress: '0xca11bde05977b3631167028862be2a173976ca11',
})
```

---

## Events (Contract)

### getContractEvents

**Docs**: `https://viem.sh/docs/contract/getContractEvents`  
**JSON-RPC**: `eth_getLogs`  
**Source**: `src/actions/public/getContractEvents.ts`

```typescript
// Signature — similar to getLogs but contract-specific
const logs = await publicClient.getContractEvents({
  abi: erc20Abi,
  address: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',  // USDC
  eventName: 'Transfer',
  args: {
    from: '0xd8da6bf26964af9d7eed9e03e53415d37aa96045',
    to: '0xa5cc3c03994db5b0d9a5eedd10cabab0813678ac',
  },
  fromBlock: 16330000n,
  toBlock: 16330050n,
})
// Returns: Log[]
```

**Code Examples**:

```typescript
// All events on a contract
const logs = await publicClient.getContractEvents({ abi: erc20Abi })

// Filtered by event name
const logs = await publicClient.getContractEvents({
  abi: erc20Abi,
  eventName: 'Transfer',
})

// With indexed args filter
const logs = await publicClient.getContractEvents({
  abi: erc20Abi,
  eventName: 'Transfer',
  args: {
    from: '0xd8da6bf26964af9d7eed9e03e53415d37aa96045',
    to: ['0xa5cc3c03994db5b0d9a5eedd10cabab0813678ac', '0xa152f8bb749c55e9943a3a0a3111d18ee2b3f94e'],
  },
  fromBlock: 16330000n,
  toBlock: 16330050n,
})

// By block hash
const logs = await publicClient.getContractEvents({
  abi: erc20Abi,
  blockHash: '0x4ca7ee652d57678f26e887c149ab0735f41de37bcad58c9f6d3ed5824f15b74d',
})

// Strict mode (only conforming logs)
const logs = await publicClient.getContractEvents({
  abi: erc20Abi,
  eventName: 'Transfer',
  strict: true,
})
```

---

### watchContractEvent

**Docs**: `https://viem.sh/docs/contract/watchContractEvent`  
**Source**: `src/actions/public/watchContractEvent.ts`

```typescript
// Signature — similar to watchEvent but contract-specific
export function watchContractEvent(
  client: Client<Transport, chain>,
  parameters: WatchContractEventParameters,
): WatchContractEventReturnType  // Returns: () => void
```

**Code Examples**:

```typescript
const unwatch = publicClient.watchContractEvent({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: wagmiAbi,
  onLogs: (logs) => console.log(logs),
})
// > [{ ... }]
// > [{ ... }, { ... }]

// Scoped to event name
const unwatch = publicClient.watchContractEvent({
  address: '0x...',
  abi: wagmiAbi,
  eventName: 'Transfer',
  onLogs: (logs) => console.log(logs),
})

// Scoped to indexed args
const unwatch = publicClient.watchContractEvent({
  address: '0x...',
  abi: wagmiAbi,
  eventName: 'Transfer',
  args: { from: '0xc961145a54C96E3aE9bAA048c4F4D6b04C13916b' },
  onLogs: (logs) => console.log(logs),
})
// Stops watching
unwatch()
```

---

### createContractEventFilter

**Docs**: `https://viem.sh/docs/contract/createContractEventFilter`  
**JSON-RPC**: `eth_newFilter`  
**Source**: `src/actions/public/createContractEventFilter.ts`

```typescript
// Signature
export async function createContractEventFilter<
  chain extends Chain | undefined,
  const abi extends Abi | readonly unknown[],
  eventName extends ContractEventName<abi> | undefined,
  args extends MaybeExtractEventArgsFromAbi<abi, eventName> | undefined,
  strict extends boolean | undefined = undefined,
  fromBlock extends BlockNumber | BlockTag | undefined = undefined,
  toBlock extends BlockNumber | BlockTag | undefined = undefined,
>(
  client: Client<Transport, chain>,
  parameters: CreateContractEventFilterParameters<...>,
): Promise<CreateContractEventFilterReturnType<...>>
```

**Code Examples**:

```typescript
const filter = await publicClient.createContractEventFilter({
  abi: parseAbi(['event Transfer(address indexed, address indexed, uint256)']),
})
// { abi: [...], id: '0x345a6572337856574a76364e457a4366', type: 'event' }

// With address
const filter = await publicClient.createContractEventFilter({
  abi: wagmiAbi,
  address: '0xfba3912ca04dd458c843e2ee08967fc04f3579c2',
})

// With event name
const filter = await publicClient.createContractEventFilter({
  abi: wagmiAbi,
  eventName: 'Transfer',
})

// With indexed args filter
const filter = await publicClient.createContractEventFilter({
  abi: wagmiAbi,
  eventName: 'Transfer',
  args: {
    from: '0xd8da6bf26964af9d7eed9e03e53415d37aa96045',
    to: '0xa5cc3c03994db5b0d9a5eedd10cabab0813678ac',
  },
})

// With block range
const filter = await publicClient.createContractEventFilter({
  abi: wagmiAbi,
  eventName: 'Transfer',
  fromBlock: 16330000n,
  toBlock: 16330050n,
})

// Strict mode
const filter = await publicClient.createContractEventFilter({
  abi: wagmiAbi,
  eventName: 'Transfer',
  strict: true,
})

// Use with getFilterChanges / getFilterLogs
const logs = await publicClient.getFilterLogs({ filter })
```

---

# EIP-7702 Actions

> EIP-7702 enables EOAs to act as smart contracts by setting code via authorization.  
> Docs base: `https://viem.sh/docs/eip7702/<actionName>`

## getDelegation

**Docs**: `https://viem.sh/docs/eip7702/getDelegation`  
**Source**: `src/actions/public/getDelegation.ts`

```typescript
// Signature
export async function getDelegation<chain extends Chain | undefined>(
  client: Client<Transport, chain>,
  { address, blockNumber, blockTag = 'latest' }: GetDelegationParameters,
): Promise<GetDelegationReturnType>  // Returns: Address | undefined
```

**Code Examples**:

```typescript
const delegation = await publicClient.getDelegation({
  address: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
// '0x1234...5678' or undefined

// At specific block
const delegation = await publicClient.getDelegation({
  address: '0x...',
  blockNumber: 15121123n,
})
// Returns the delegated address if EIP-7702 delegation is set at that block
```

---

## prepareAuthorization

**Docs**: `https://viem.sh/docs/eip7702/prepareAuthorization`  
**Source**: `src/actions/wallet/prepareAuthorization.ts`

```typescript
// Signature
export async function prepareAuthorization<
  chain extends Chain | undefined,
  account extends Account | undefined,
>(
  client: Client<Transport, chain, account>,
  parameters: PrepareAuthorizationParameters<account>,
): Promise<PrepareAuthorizationReturnType>  // Returns: Authorization
```

**Code Examples**:

```typescript
import { prepareAuthorization } from 'viem/experimental'

// Basic usage
const authorization = await walletClient.prepareAuthorization({
  account: privateKeyToAccount('0x...'),
  contractAddress: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
// { address: '0xA0Cf...', chainId: 1, nonce: 69, ... }

// With explicit chainId
const authorization = await walletClient.prepareAuthorization({
  account: privateKeyToAccount('0x...'),
  contractAddress: '0x...',
  chainId: 10,  // Optimism
})

// With nonce
const authorization = await walletClient.prepareAuthorization({
  account: privateKeyToAccount('0x...'),
  contractAddress: '0x...',
  nonce: 69,
})

// With executor (who will execute the EIP-7702 transaction)
const authorization = await walletClient.prepareAuthorization({
  account: privateKeyToAccount('0x...'),
  contractAddress: '0x...',
  executor: 'self',  // EOA signs and executes itself
})

// Then sign and send
const signedAuthorization = await walletClient.signAuthorization(authorization)
```

---

# ABI Utilities

## parseAbi

```typescript
import { parseAbi } from 'viem'

const abi = parseAbi([
  'function balanceOf(address owner) view returns (uint256)',
  'event Transfer(address indexed from, address indexed to, uint256 value)',
])
// Parses ABI from array of strings
```

## encodeFunctionData

```typescript
import { encodeFunctionData, parseAbi } from 'viem'

const data = encodeFunctionData({
  abi: parseAbi(['function transfer(address to, uint256 amount)']),
  functionName: 'transfer',
  args: ['0x...', 1000000n],
})
// '0xa9059cbb0000000000000000000000...'
```

## decodeFunctionData

```typescript
import { decodeFunctionData } from 'viem'

const { functionName, args } = decodeFunctionData({
  abi: wagmiAbi,
  data: '0xa9059cbb0000000000000000000000...',
})
// { functionName: 'transfer', args: ['0x...', 1000000n] }
```

## decodeFunctionResult

```typescript
import { decodeFunctionResult } from 'viem'

const value = decodeFunctionResult({
  abi: wagmiAbi,
  functionName: 'ownerOf',
  data: '0x...',
})
```

## decodeErrorResult

```typescript
import { decodeErrorResult } from 'viem'

const { errorName, args } = decodeErrorResult({
  abi: wagmiAbi,
  data: '0xb758934b...',
})
// { errorName: 'InvalidTokenError', args: ['sold out'] }
```

## decodeEventLog

```typescript
import { decodeEventLog } from 'viem'

const decoded = decodeEventLog({
  abi: wagmiAbi,
  topics: ['0x406dade3...', '0x0000...f39f...', '0x0000...7099...'],
  data: '0x0000000000000000000000000000000000000000000000000000000000000001',
})
// { eventName: 'Transfer', args: { from: '0x...', to: '0x...', value: 1n } }
```

## parseEventLogs

```typescript
import { parseEventLogs } from 'viem'

const receipt = await publicClient.getTransactionReceipt({ hash: '0x...' })
const logs = parseEventLogs({ abi: erc20Abi, logs: receipt.logs })
// All events

const transferLogs = parseEventLogs({ abi: erc20Abi, eventName: 'Transfer', logs: receipt.logs })
// Only Transfer events
```

## encodeEventTopics

```typescript
import { encodeEventTopics } from 'viem'

const topics = encodeEventTopics({
  abi: wagmiAbi,
  eventName: 'Transfer',
  args: { from: '0xf39f...', to: '0x7099...' },
})
```

## encodeDeployData

```typescript
import { encodeDeployData } from 'viem'

const data = encodeDeployData({
  abi: [...],
  bytecode: '0x...',
  args: ['constructor arg'],
})
```

---

# Utilities

## Hex & Bytes

```typescript
import { toHex, fromHex, bytesToHex, hexToBytes } from 'viem'

toHex(420)                              // '0x1a4'
toHex('hello world')                    // '0x68656c6c6f20776f726c64'
toHex(new Uint8Array([1, 2, 3]))        // '0x010203'
toHex(true)                             // '0x1'

fromHex('0x1a4', 'number')             // 420
fromHex('0x48656c6c6f', 'string')        // 'Hello'

bytesToHex(new Uint8Array([72, 101]))    // '0x4865'
hexToBytes('0x4865')                    // Uint8Array([72, 101])
```

## Ether Formatting

```typescript
import { formatEther, parseEther, formatUnits, parseUnits } from 'viem'

formatEther(1000000000000000000n)       // '1.0'
parseEther('1')                         // 1000000000000000000n

formatUnits(420000000000n, 9)          // '420'
parseUnits('420', 9)                   // 420000000000n
```

## Address Utilities

```typescript
import { isAddress, getAddress, isAddressEqual } from 'viem'

isAddress('0x...')                      // boolean
getAddress('0x...')                    // checksummed address
isAddressEqual('0x...', '0x...')        // boolean
```

## Keccak256

```typescript
import { keccak256 } from 'viem'

keccak256('0x48656c6c6f')              // '0x1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36de10'
```

## Other Utilities

```typescript
import { concat, pad, slice, recoverAddress, recoverPublicKey } from 'viem'

concat(['0x12', '0x34'])               // '0x1234'
pad('0x1234', { left: true, size: 32 }) // zero-padded to 32 bytes
slice('0x123456', 0, 2)               // '0x12'
recoverAddress({ message, signature })  // Address
recoverPublicKey({ message, signature }) // Hex
```

---

# Constraints / Gotchas

1. **Numeric types follow the API** — amounts and gas/fee quantities use `bigint`; transaction nonce and several counts use `number`. Follow the locked library types.
2. **`parseEther` / `parseUnits`** — converts human-readable to wei/native. `formatEther` / `formatUnits` do the reverse.
3. **Simulate before write** — always `simulateContract` before `writeContract` to catch revert reasons early.
4. **`extend(publicActions)`** — wallet clients don't have public actions by default; call `.extend(publicActions)` to add them.
5. **Chain must match network** — the `chain` option on clients must match the actual network, or RPC calls may fail silently.
6. **Account types** — `privateKeyToAccount` is local signing; `address` string is a JSON-RPC account that defers to an external wallet.
7. **State override for testing** — `simulateContract` and `readContract` support `stateOverride` to mock contract storage locally.
8. **Batch multicall** — enable with `batch: { multicall: true }` on public client for reads; reduces RPC calls.
9. **Strict event mode** — `createEventFilter`, `getContractEvents`, `watchContractEvent` support `strict: true` to filter out non-conforming logs.
10. **ERC-1271 verification** — `verifyMessage` and `verifyTypedData` support smart contract wallets via `factory` + `factoryData` params.
11. **`writeContractSync`** — returns a receipt immediately instead of a hash; useful for low-latency chains.
12. **EIP-7702** — requires `prepareAuthorization` + `signAuthorization` workflow before setting delegation code.
13. **Authorization list** — `sendTransaction` and `writeContract` accept `authorizationList: Authorization[]` for EIP-7702 transactions.

---

# Key Source Files

| File | Purpose |
|------|---------|
| `src/clients/createClient.ts` | `createPublicClient`, `createWalletClient`, `createTestClient` |
| `src/clients/transports/` | HTTP, WebSocket, Custom, Fallback transports |
| `src/actions/public/` | All public actions (38 actions) |
| `src/actions/wallet/` | All wallet actions (26 actions) |
| `src/actions/getContract.ts` | `getContract` Contract Instance |
| `src/accounts/` | `privateKeyToAccount`, `mnemonicToAccount`, `hdKeyToAccount` |
| `src/utils/` | All utilities (toHex, keccak256, formatUnits, isAddress, etc.) |
| `src/types/` | TypeScript type definitions |
| `src/utils/abi/` | ABI encoding/decoding utilities |
| `site/pages/docs/` | Full documentation source at https://viem.sh/docs |
| `https://viem.sh` | Official docs (v2.47.6) |
| `https://github.com/wevm/viem` | GitHub (main branch) |
