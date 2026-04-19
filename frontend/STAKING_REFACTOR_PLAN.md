# Staking Page Refactor Plan

**Status**: Draft — review before implementation  
**Scope**: `/staking` page, shared hooks/components reusable across `/swap`, `/batch-swap`, `/staking`  
**Guiding decisions** (from design review):
1. Staking is *simpler* than swap, but Mint CHIR and Burn CHIR must go through the Standard Exchange Router to get Permit2 + WETH wrapping for free.
2. All chain/telemetry debug info goes behind a collapsible `DebugPanel`.
3. Signed-mode uses the strict `intentKey` stale-signature check from swap (not the relaxed "has a stored sig" check in current staking).
4. Split into section components; extract shared logic into hooks and components reused across all three DeFi pages.

---

## 1. Bug Fixes (Required regardless of refactor scope)

These are production correctness issues that should be addressed in the first PR.

### 1a. `sellNft` does not await transaction receipt

**File**: `app/staking/StakingPageClient.tsx` line 904  
**Current problem**: After `writeContractAsync` succeeds, the handler only calls `setStatus(...)`. It never waits for the receipt, so DETF state is not refreshed and the user sees no confirmation.  
**Fix**: Replace the bare `setStatus` call with `await waitForReceiptAndRefresh(hash, 'Sell NFT')`.

```ts
// BEFORE (line 904)
setStatus(`sellNFT submitted: ${hash}`)

// AFTER
await waitForReceiptAndRefresh(hash, 'Sell NFT')
```

### 1b. Single `mintSlippage` state shared between Mint and Burn

**File**: `StakingPageClient.tsx` lines 561, 1164, 1188 (Burn CHIR slippage input binds to `mintSlippage`)  
**Current problem**: Setting slippage for mint unintentionally changes the burn slippage and vice versa.  
**Fix**: Add separate `burnSlippage` state; bind Burn CHIR slippage input to `burnSlippage`; create `computeMinBurnAmountOut(amount)` that uses `burnSlippage`.

```ts
const [mintSlippage, setMintSlippage] = useState<number>(0.5)
const [burnSlippage, setBurnSlippage] = useState<number>(0.5) // new
```

### 1c. Burn CHIR must go through the Standard Exchange Router

**Current problem**: `burnChirForWeth` calls `exchangeIn` directly on the DETF contract. This bypasses the router, so Permit2 signing is unavailable for burn and WETH unwrapping is not automatic.  
**Fix**: Route burn through `swapSingleTokenExactIn` on the router (CHIR→WETH, same as mint but swapped token direction). CHIR approval gate goes to Permit2 → Router instead of directly to DETF.  
**Notes**:
- `tokenIn` = DETF address (CHIR), `tokenOut` = WETH
- `wethIsEth` can be `true` to get native ETH back if the user has that option (future; default `false` for now)
- The approval flow hook (`useApprovalFlow`) needs `tokenAddress` = DETF address when in burn mode

---

## 2. New Shared Hooks

Extract these patterns that currently live inline in each page component into reusable hooks under `app/lib/hooks/`. This reduces duplication across swap, batch-swap, and staking.

### 2a. `useChainResolution` — `app/lib/hooks/useChainResolution.ts`

**What it does**: The multi-source chainId resolution (account / connection / walletClient / connectorClient / connectorHook / browser / config) is copy-pasted across swap, batch-swap, staking, and other pages with slight variation.

**Returns**:
```ts
type UseChainResolutionResult = {
  configChainId: number
  accountChainId: number | undefined
  attachedWalletChainId: number | undefined
  resolvedWalletChainId: number | null
  dataChainId: number               // selectedChainId ?? fallback chain
  walletMatchesDataChain: boolean
  isUnsupportedChain: boolean
  isConnected: boolean
  address: `0x${string}` | undefined
  targetChain: Chain                // resolveAppChain(dataChainId)
  // debug sources for DebugPanel
  chainSources: {
    account: number | undefined
    connection: number | undefined
    walletClient: number | undefined
    connectorClient: number | undefined
    connectorHook: number | undefined
    browser: number | undefined
    config: number
  }
}
```

**Inputs**: `{ fallbackChainId?: number }` (defaults to CHAIN_ID_SEPOLIA)

**Replaces** duplicated chain-setup code at the top of every page component.

---

### 2b. `useRouterBytecode` — `app/lib/hooks/useRouterBytecode.ts`

**What it does**: The `useEffect` that calls `hasBytecode(publicClient, routerCandidate)` and sets `routerAddress`, `routerHasBytecode`, `routerBytecodeError` is duplicated between swap and staking.

**Returns**:
```ts
type UseRouterBytecodeResult = {
  routerAddress: `0x${string}` | null
  routerHasBytecode: boolean | null
  routerBytecodeError: string
}
```

**Inputs**: `{ publicClient, routerCandidate: string | undefined }`

---

### 2c. `usePermit2Nonce` — `app/lib/hooks/usePermit2Nonce.ts`

**What it does**: Fetches the `nonceBitmap(owner, wordIndex)` and exposes a helper to derive the next unused nonce from the bitmap. This pattern is used in both swap and staking.

**Returns**:
```ts
type UsePermit2NonceResult = {
  nonceBitmap: bigint | undefined
  refetchNonce: () => Promise<void>
  nextUnusedNonce: bigint | undefined  // derived from bitmap word 0
}
```

**Inputs**: `{ permit2Address: string | undefined, owner: string | undefined, chainId: number }`

---

## 3. New Shared UI Components

These live in `app/components/` and are reused across `/swap`, `/batch-swap`, and `/staking`.

### 3a. `WalletStatusBanner` — `app/components/WalletStatusBanner.tsx`

Already implemented ad-hoc in swap and batch-swap as inline JSX. Move to a proper component.

**Props**:
```ts
interface WalletStatusBannerProps {
  isConnected: boolean
  isUnsupportedChain: boolean
  walletMatchesDataChain: boolean
  attachedWalletChainId: number | undefined
  dataChainId: number
  environment: string
}
```

**Renders**:
- Not connected → amber banner: "Connect your wallet to interact"
- Connected but unsupported chain → rose banner: "Wallet chain X is not mapped for {environment}…"
- Connected to wrong chain → yellow banner: "Switch to chain {dataChainId}…"
- All good → `null`

---

### 3b. `ApprovalSettingsPanel` — `app/components/ApprovalSettingsPanel.tsx`

Currently each page has its own bespoke approval mode radios + collapsible settings. Extract to a shared component.

**Props**:
```ts
interface ApprovalSettingsPanelProps {
  approvalMode: 'explicit' | 'signed'
  onModeChange: (mode: 'explicit' | 'signed') => void
  showSettings: boolean
  onToggleSettings: () => void
  permit2SpendingLimit: string
  onSpendingLimitChange: (v: string) => void
  onIssuePermit2Approval: (limit?: bigint) => void
  onIssueRouterApproval: (limit?: bigint) => void
  onEnsureApprovals: () => void
  disabled?: boolean
}
```

**Renders** (matches the styled card-style toggle in swap):
- Gear icon + "Approval Settings" collapsible header
- Two styled radio cards: "Explicit (ERC20 → Permit2 → Router)" and "Signed Permit2 (gasless per-swap)"
- Collapsed spending-limit + action buttons panel

---

### 3c. `SlippageInput` — `app/components/SlippageInput.tsx`

**Props**:
```ts
interface SlippageInputProps {
  value: number              // percent
  onChange: (v: number) => void
  label?: string             // defaults to "Slippage (%)"
}
```

**Renders**: label + free-text input + quick-select buttons: 0.1% | 0.5% | 1%

---

## 4. New Staking-Specific Hooks

### 4a. `useStakingContractReads` — `app/lib/hooks/useStakingContractReads.ts`

Consolidates all the `useReadContract` calls that read state from the DETF contract. Currently these are scattered across ~100 lines of `StakingPageClient.tsx`.

**Returns**:
```ts
// Synthetic price & thresholds
syntheticPrice, syntheticPriceError, refetchSyntheticPrice
mintThreshold, mintThresholdError
burnThreshold, burnThresholdError
isMintingAllowed, refetchIsMintingAllowed
isBurningAllowed, refetchIsBurningAllowed
// Token addresses (resolved from DETF reads + platform fallbacks)
richToken, richirToken, wethToken, nftVault, reservePool
// Token metadata
richDecimals, wethDecimals
// User balances
chirBalance, refetchChirBalance
// Derived summaries
syntheticPriceDisplay, mintThresholdDisplay, burnThresholdDisplay
mintingAllowedNow, burningAllowedNow, availabilityMismatch
effectiveRichToken, effectiveRichirToken, effectiveWethToken
// Batch refresh
refreshDetfState: () => Promise<void>
```

**Inputs**: `{ detfAddress, dataChainId, platform, address }`

---

## 5. Staking Section Components

Split the monolithic `StakingPageClient.tsx` into focused section components. These live in `app/staking/sections/`.

### 5a. `DetfSelectorSection` — `app/staking/sections/DetfSelectorSection.tsx`

Renders the DETF dropdown + wallet status line. Receives `detfOptions`, `selectedDetf`, and `onSelect`.

---

### 5b. `PriceInfoSection` — `app/staking/sections/PriceInfoSection.tsx`

Renders the synthetic price panel, mint/burn thresholds, and availability indicators. Pure display — takes reads output from `useStakingContractReads`.

---

### 5c. `MintChirSection` — `app/staking/sections/MintChirSection.tsx`

Handles "Mint CHIR with WETH" using the Standard Exchange Router.

**Key behaviors**:
- Uses `useApprovalFlow` with `tokenAddress = effectiveWethToken`, `routerAddress`
- Uses `usePermit2Nonce` hook (new 2c)
- **intentKey stale-signature guard**: computes `intentKey` from `(chainId, user, detfAddress, amountIn, limit, deadline)`. If inputs change, clears `storedPermitSignature` automatically (same pattern as swap page lines 1331–1337).
- Two-step signed path: "Get Accurate Quote (Sign)" → "Mint (Signed)" — disabled if `intentKey !== storedPermitSignature.intentKey` or `storedPermitSignature.deadline <= now`
- Explicit path: single "Mint" button
- On quote sign: simulation-verifies via `publicClient.simulateContract` before storing
- Shows `SlippageInput` (component 3c) with separate `mintSlippage` state
- Shows `ApprovalSettingsPanel` (component 3b)
- Shows preview: WETH in → CHIR out

**Props**: receives addresses, contract reads, approval state, chain context, write function

---

### 5d. `BurnChirSection` — `app/staking/sections/BurnChirSection.tsx`

Handles "Burn CHIR for WETH" via the Standard Exchange Router.

**Key behaviors**:
- Token flow: CHIR → WETH via `swapSingleTokenExactIn` on router (not `exchangeIn` on DETF)
- `useApprovalFlow` with `tokenAddress = detfAddress` (approving CHIR → Permit2 → router)
- Separate `burnSlippage` state (fix 1b)
- Signed path available (same intentKey guard as MintChirSection)
- On confirmation: calls `waitForReceiptAndRefresh`
- Shows CHIR wallet balance
- Shows preview: CHIR in → WETH out

---

### 5e. `BondSection` — `app/staking/sections/BondSection.tsx`

Handles both "Bond with WETH" and "Bond with RICH" side by side.

**Key behaviors**:
- Shared `lockDays` state is lifted to this section (not per-card); single lock duration input rendered **once above both cards** (not duplicated, fixing issue 3 from assessment)
- Each card has its own amount input and action button
- Direct DETF approval (not router) — bond operations use `bondWithWeth`/`bondWithRich` which take the full WETH/RICH amount directly
- Approvals: standard `approveToken(token, detfAddress, amount)` before bond (no Permit2 needed here — these are simpler direct calls)
- Both buttons disabled if not connected, chain mismatch, pending write
- Receipt-aware: `waitForReceiptAndRefresh` on success

---

### 5f. `SellNftSection` — `app/staking/sections/SellNftSection.tsx`

Handles "Sell NFT for RICHIR".

**Key behaviors**:
- Token ID input
- On submit: calls `sellNFT(tokenId, recipient)` then `waitForReceiptAndRefresh` (fix 1a)
- Simple — no approval needed (DETF handles NFT ownership check internally)

---

### 5g. `StakingDebugPanel` — `app/staking/sections/StakingDebugPanel.tsx`

Wraps `DebugPanel` with all chain telemetry, router, approval, and DETF state.

**Renders inside `<DebugPanel title="🔍 Staking Debug">`:
- Chain sources (`chainSources` from `useChainResolution`)
- Router address, bytecode found / error
- Approval state (tokenAllowance, permit2Allowance, approvalState)
- Mint/burn preview values
- storedPermitSignature intentKey + deadline
- Raw contract addresses

---

## 6. Refactored `StakingPageClient.tsx`

After the above work, `StakingPageClient.tsx` becomes a thin orchestrator:

```tsx
export default function StakingPageClient() {
  // 1. Chain resolution (new hook)
  const chain = useChainResolution()

  // 2. DETF selection
  const detfs = useMemo(() => getProtocolDetfsForChain(chain.dataChainId, environment), [...])
  const [selectedDetf, setSelectedDetf] = useState(...)

  // 3. Domain reads (new hook)
  const detfReads = useStakingContractReads({ detfAddress, dataChainId: chain.dataChainId, platform, address: chain.address })

  // 4. Router + Permit2
  const { routerAddress, routerHasBytecode, routerBytecodeError } = useRouterBytecode({ publicClient, routerCandidate })

  // 5. Shared write contract wrapper + status
  const { writeContractAsync, isPending } = useWriteContract()
  const [status, setStatus] = useState('')
  const waitForReceiptAndRefresh = useWaitForReceiptAndRefresh(publicClient, setStatus, detfReads.refreshDetfState)

  // 6. Approval mode
  const [approvalMode, setApprovalMode] = useState<'explicit' | 'signed'>('explicit')

  return (
    <div className="...">
      <h1>Staking</h1>

      <WalletStatusBanner {...chain} />

      {detfs.length === 0 ? <EmptyDetfNotice /> : (
        <>
          <DetfSelectorSection ... />
          <PriceInfoSection reads={detfReads} />
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <MintChirSection reads={detfReads} chain={chain} routerAddress={routerAddress} ... />
            <BurnChirSection reads={detfReads} chain={chain} routerAddress={routerAddress} ... />
          </div>
          <BondSection reads={detfReads} chain={chain} ... />
          <SellNftSection reads={detfReads} chain={chain} ... />
          <StakingStatusPanel status={status} />
          <StakingDebugPanel chain={chain} reads={detfReads} routerBytecodeError={routerBytecodeError} />
        </>
      )}
    </div>
  )
}
```

Target size: ~120 lines in the orchestrator, ~80–180 lines per section.

---

## 7. intentKey Stale-Signature Pattern (Signed Mode)

Both `MintChirSection` and `BurnChirSection` must use the same stale-signature guard as swap.

**Implementation**:

```ts
// In section components
const intentKey = useMemo(() => {
  if (approvalMode !== 'signed') return null
  if (!address || !chainId || !detfAddress || !tokenIn || !amountGiven) return null
  return buildPermitIntentKey({
    chainId,
    owner: address,
    spender: routerAddress,
    pool: detfAddress,
    tokenIn,
    tokenInVault: zeroAddress,
    tokenOut,
    tokenOutVault: zeroAddress,
    amountGiven,
    limit: minAmountOut,
    wethIsEth: false,
    userDataHash: keccak256('0x'),
    isExactIn: true,
  })
}, [approvalMode, address, chainId, detfAddress, tokenIn, tokenOut, amountGiven, minAmountOut, routerAddress])

// Auto-invalidate stored sig when intent changes
useEffect(() => {
  if (!storedPermitSignature) return
  if (!intentKey || storedPermitSignature.intentKey !== intentKey) {
    setStoredPermitSignature(null)
    setAccurateQuote(null)
  }
}, [storedPermitSignature, intentKey])
```

The `buildPermitIntentKey` utility already exists in the swap page; it should be extracted to `app/lib/permit2-signature.ts`.

**Swap button guards** (same rules as swap page):
- "Get Accurate Quote": enabled when `intentKey !== null` and `!storedPermitSignature`
- "Mint/Burn (Signed)": enabled only when `storedPermitSignature?.intentKey === intentKey && storedPermitSignature.deadline > nowSec`
- If deadline expired or intent changed, the signed button is disabled and quote button re-appears

---

## 8. File Structure After Refactor

```
frontend/app/
├── lib/
│   ├── hooks/
│   │   ├── useApprovalFlow.ts          (existing, no change)
│   │   ├── useChainResolution.ts        (NEW — 2a)
│   │   ├── useRouterBytecode.ts         (NEW — 2b)
│   │   └── usePermit2Nonce.ts           (NEW — 2c)
│   ├── permit2-signature.ts            (existing; add buildPermitIntentKey export)
│   └── ...
├── components/
│   ├── DebugPanel.tsx                   (existing, no change)
│   ├── WalletStatusBanner.tsx           (NEW — 3a)
│   ├── ApprovalSettingsPanel.tsx        (NEW — 3b)
│   └── SlippageInput.tsx                (NEW — 3c)
└── staking/
    ├── page.tsx                         (existing thin shell, no change)
    ├── StakingPageClient.tsx            (refactored to orchestrator, ~120 lines)
    └── sections/
        ├── DetfSelectorSection.tsx      (NEW — 5a)
        ├── PriceInfoSection.tsx         (NEW — 5b)
        ├── MintChirSection.tsx          (NEW — 5c)
        ├── BurnChirSection.tsx          (NEW — 5d)
        ├── BondSection.tsx              (NEW — 5e)
        ├── SellNftSection.tsx           (NEW — 5f)
        └── StakingDebugPanel.tsx        (NEW — 5g)
```

---

## 9. Implementation Order

Work in this sequence to keep the page functional at every step.

| Step | Description | Risk |
|------|-------------|------|
| **P1** | Apply bug fixes 1a (`sellNft` receipt) and 1b (separate `burnSlippage`) directly to current `StakingPageClient.tsx` | Low |
| **P2** | Extract `buildPermitIntentKey` to `permit2-signature.ts` and add intentKey guard to staking (signed mode only) | Medium |
| **P3** | Create `WalletStatusBanner`, `SlippageInput`, `ApprovalSettingsPanel` components | Low |
| **P4** | Create `useChainResolution`, `useRouterBytecode`, `usePermit2Nonce` hooks | Medium |
| **P5** | Create `useStakingContractReads` hook; plumb into existing `StakingPageClient.tsx` | Medium |
| **P6** | Create section components `DetfSelectorSection`, `PriceInfoSection` | Low |
| **P7** | Create `MintChirSection` (router path, intentKey, ApprovalSettingsPanel) | High |
| **P8** | Create `BurnChirSection` (router path, router approval, intentKey) | High |
| **P9** | Create `BondSection` (shared lock days, receipt-ready) | Low |
| **P10** | Create `SellNftSection`, `StakingDebugPanel` | Low |
| **P11** | Slim down `StakingPageClient.tsx` to orchestrator shell | Medium |
| **P12** | Update `/swap` and `/batch-swap` to use `WalletStatusBanner`, `ApprovalSettingsPanel`, `SlippageInput` | Low |

Each step should be its own PR or at minimum a self-contained commit that passes `forge build` (frontend build) without regression.

---

## 10. What Changes in the UX

| Area | Before | After |
|------|--------|-------|
| Chain debug telemetry | Always rendered inline | Hidden in collapsible DebugPanel |
| Disconnected wallet | Yellow "wrong chain" warning only | Full amber "connect wallet" banner |
| Unsupported chain | Yellow banner | Rose banner (matches swap) |
| Approval settings | Bare HTML radios + underline-link toggle | Styled card-style panel with gear icon |
| Mint slippage | Shared with burn | Independent |
| Burn CHIR path | Direct `exchangeIn` on DETF | `swapSingleTokenExactIn` via router |
| Burn approval gate | CHIR → DETF | CHIR → Permit2 → Router |
| Signed mode (staking) | No stale-sig check | intentKey guard, auto-invalidate |
| Lock days input | Duplicated per bond card | Single input above both cards |
| sellNft | No receipt wait | Receipt-awaited, state refreshed |
| Debug info | Always-on telemetry | Collapsible DebugPanel |

---

## 11. Open Questions Before Implementation

1. **Burn WETH handling**: Should `burnChirForWeth` set `wethIsEth: true` to unwrap to native ETH, or always return WETH? (Recommendation: default `false`/WETH, add a checkbox later)
2. **Bond operations + Permit2**: Bond with WETH currently does a raw ERC20 `approve → DETF.bondWithWeth`. Should bonds also go through Permit2/router, or keep the direct ERC20 approval path? (Recommendation: keep direct ERC20 for now — bond is not a swap)
3. **Lock days placement**: Single input above both bond cards, or a shared "Bond Settings" collapsible section? (Recommendation: single input rendered between the price info and the bond grid)
4. **Swap/batch-swap retrofit**: For P12 (replacing inline approval UX in swap/batch-swap with shared components), are style changes in those pages in scope for this pass, or strictly additive (not changing behaviour)?

---

*Last updated: 2026-04-11*
