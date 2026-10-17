# Kimi K3 — notes: legacy V4 swaps Pendle SY for ERC-5115

- **Label:** Replacement-session review/notes, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No reviewers' notes were read. Nothing was edited; this is not a PRD.
- **Date:** 2026-10-14.
- **Owner ruling under review:** the legacy Uniswap V4 Standard Exchange vault implemented the Pendle `IStandardizedYield` interface; it must implement `lib/crane/contracts/tokens/ERC5115/IERC5115_StandardizedYield.sol` instead. No facet split is decided here. Size is measured after the interface change.
- I did not run Forge.

## 1. The two interfaces, read in full

**ERC-5115** (`IERC5115_StandardizedYield.sol`, 60 lines) declares exactly: events `Deposit(caller, receiver, tokenIn, amountDeposited, amountSyOut)` and `Redeem(caller, receiver, tokenOut, amountSyToRedeem, amountTokenOut)`; functions `deposit(receiver, tokenIn, amountTokenToDeposit, minSharesOut, depositFromInternalBalance)` (non-payable), `redeem(receiver, amountSharesToRedeem, tokenOut, minTokenOut, burnFromInternalBalance)`, `exchangeRate()`, `getTokensIn()`, `getTokensOut()`, `yieldToken()`, `previewDeposit(tokenIn, amount)`, `previewRedeem(tokenOut, shares)`. Metadata (`name`/`symbol`/`decimals`) is commented out (`:55-59`) — ERC-5115 expects the SY token to be an ERC-20 itself, which this vault already is through its existing `ERC20Facet`.

**Pendle** (`IStandardizedYield.sol`, 166 lines) carries the same two events with identical signatures, plus `ClaimRewards(user, rewardTokens, rewardAmounts)`; `deposit` with four arguments and `payable`; `redeem` with a signature identical to ERC-5115's; `exchangeRate`, `getTokensIn/Out`, `yieldToken`, `previewDeposit/Redeem` with identical signatures; and the Pendle-only surface: `claimRewards`, `accruedRewards`, `rewardIndexesCurrent`, `rewardIndexesStored`, `getRewardTokens`, `assetInfo`, `isValidTokenIn`, `isValidTokenOut`, and the `IERC20Metadata` inheritance.

## 2. Selector deltas and their owners (legacy V4 family only)

Current owners were read in the flattened tree: money selectors on `UniswapV4StandardExchangeInFacet.sol:22-26` (via `NativeStandardYieldSelectors._appendExecution`), the twelve query/discovery selectors on `UniswapV4StandardExchangeOutMultiQueryFacet.sol:23-27` (via `_appendQuery`), behavior in `UniswapV4StandardYieldExecutionTarget.sol` and `UniswapV4StandardExchangeOutMultiQueryTarget.sol`, interface advertisement at `UniswapV4StandardExchangeOutMultiQueryFacet.sol:20` and in the package at `UniswapV4StandardExchangeDFPkg.sol:162`.

### Removed from the legacy V4 proxy

| Selector (Pendle signature) | Current owner | Disposition |
| --- | --- | --- |
| `deposit(address,address,uint256,uint256)` (4-arg, payable) | InFacet | Replaced by the 5-arg ERC-5115 form; not kept as an alias |
| `claimRewards(address)` | InFacet | Removed; the current implementation is the shared empty-array stub (`NativeStandardYieldTarget.sol:79-82`) |
| `rewardIndexesCurrent()` | InFacet | Removed (empty stub, `:78`) |
| `getRewardTokens()` | OutMultiQueryFacet | Removed |
| `accruedRewards(address)` | OutMultiQueryFacet | Removed |
| `rewardIndexesStored()` | OutMultiQueryFacet | Removed |
| `assetInfo()` | OutMultiQueryFacet | Removed; its current answer (`LIQUIDITY, poolManager, 18`, `OutMultiQueryTarget.sol:40-44`) has no ERC-5115 successor |
| `isValidTokenIn(address)` / `isValidTokenOut(address)` | OutMultiQueryFacet | Removed from the public surface; the internal predicate `Config._isValidToken` (their current body) stays internal |
| `ClaimRewards` event | (emitted by the removed stub) | Removed with it |

### Added or signature-changed

| Selector | Owner (unchanged facet) | Note |
| --- | --- | --- |
| `deposit(address,address,uint256,uint256,bool)` | InFacet | New selector (added bool); non-payable |
| `redeem(address,uint256,address,uint256,bool)` | InFacet | Same selector as Pendle's; unchanged |
| `exchangeRate()` | OutMultiQueryFacet | Same selector; same computation (`OutMultiQueryTarget.sol:46-51`) |
| `getTokensIn()` / `getTokensOut()` | OutMultiQueryFacet | Same selectors; same two-token arrays (`:26-34`) |
| `yieldToken()` | OutMultiQueryFacet | Same selector; current answer `address(0)` is preserved behavior |
| `previewDeposit(address,uint256)` / `previewRedeem(address,uint256)` | OutMultiQueryFacet | Same selectors; same `_previewExchangeIn` route (`:76-83`) |
| `type(IERC5115_StandardizedYield).interfaceId` | advertised at `OutMultiQueryFacet.sol:20` and `DFPkg.sol:162` in place of `type(IStandardizedYield).interfaceId` | Computed from the eight ERC-5115 functions at build time; not hand-written |

The ERC-5115 `Deposit`/`Redeem` events are byte-identical to Pendle's; the emit sites keep their arguments and are re-typed to the ERC-5115 interface's declarations.

## 3. File-by-file notes (legacy V4 only)

1. **`UniswapV4StandardYieldExecutionTarget.sol`** — rewrite the two SY overrides to the ERC-5115 signatures. `redeem`'s body is unchanged (the signatures match, including `burnFromInternalBalance`; the `_requireNotDisabled` at `:32`, the `_redeemVaultHeld`/`_standardRoute` overrides at `:44-64`, and `_settleNamedHolder` at `:66-75` all stay). `deposit` gains `depositFromInternalBalance` (mapping closed in §4). The target stops inheriting `NativeStandardYieldExecutionTarget` and implements `IERC5115_StandardizedYield`'s money functions directly over the Config/PoolOps/Custody libraries; the validation sequence (zero receiver, zero amount, token validity, minimum enforcement, events) is preserved with the existing `NativeStandardYieldErrors` declarations. Since ERC-5115 `deposit` is non-payable, the current `UnsupportedNativePayment` check (`NativeStandardYieldTarget.sol:21`) has no successor — a non-payable function rejects value at the ABI level; the error declaration itself is shared and stays.
2. **`UniswapV4StandardExchangeInFacet.sol`** — `facetFuncs` becomes exactly `IStandardExchangeIn.exchangeIn.selector`, `IERC5115_StandardizedYield.deposit.selector`, `IERC5115_StandardizedYield.redeem.selector`; the `NativeStandardYieldSelectors._appendExecution` import/call is removed. No `rewardIndexesCurrent`/`claimRewards`.
3. **`UniswapV4StandardExchangeOutMultiQueryTarget.sol`** — drop `assetInfo` and the Pendle import; keep `getTokensIn`, `getTokensOut`, `yieldToken`, `exchangeRate`, and `_previewExchangeIn` as they are. It stops inheriting the Pendle preview/discovery targets and implements the six ERC-5115 reads directly.
4. **`UniswapV4StandardExchangeOutMultiQueryFacet.sol`** — `facetFuncs` becomes `previewExchangeOutOneToMany` plus the six ERC-5115 read selectors, enumerated explicitly (no `_appendQuery`); `facetInterfaces` swaps `type(IStandardizedYield).interfaceId` (`:20`) for `type(IERC5115_StandardizedYield).interfaceId`.
5. **`UniswapV4StandardExchangeDFPkg.sol`** — the package interface registration at `:162` swaps to `type(IERC5115_StandardizedYield).interfaceId`. No cut changes; no selector moves between facets.
6. **Tests** — `contracts/vaults/standard/sy/Behavior_NativeStandardYieldExecution.sol` and the legacy V4 suites under `test/foundry/spec/protocol/dexes/uniswap/v4/` that drive `IStandardizedYield(address(vault))` are mechanically re-pointed at `IERC5115_StandardizedYield`; every `deposit(...)` call gains the `false` argument except the pretransfer-flag cases (§4). The assertion semantics are unchanged.

## 4. The one mapping the notes must close so the implementer does not choose

ERC-5115's `depositFromInternalBalance` has no Pendle counterpart. Closed against existing family law, not invented: when `true`, the deposit follows the vault's existing pretransfer rule for the same economic route — the exact-in zap deposit that `exchangeIn(tokenIn → shares, pretransferred=true)` already supports: `LocalCreditLib.requirePretransferCaller(msg.sender)` first (a code-less caller reverts `EOAPretransferNotAllowed`), then the unbooked-surplus credit is measured, exactly `amountTokenToDeposit` is consumed with no refund, and a short credit reverts `TransferDeltaInsufficient`. When `false`, the current measured pull runs unchanged. This adds no new money path; it wires the new flag to a route the vault already supports. If the owner would rather reject the flag outright, that is the one sentence to amend — but no owner ruling is required to write the PRD, because the mapping above is the existing law applied to the new parameter, not a new behavior.

## 5. Shared files and other families — untouched

Everything under `contracts/vaults/standard/sy/` (`NativeStandardYieldTarget.sol`, `NativeStandardYieldErrors.sol`, `NativeStandardYieldPreviewTarget.sol`, `NativeStandardYieldDiscoveryTarget.sol`, `NativeStandardYieldQuoteBase.sol`, `NativeStandardYieldSelectors.sol`, `ConstantProductStandardYieldTarget.sol`, `Behavior_NativeStandardYieldExecution.sol`) serves the other SY families — V3 FullSpread, hookless, Pons, Wings, ERC-4626, constant-product, the staking families, and the hook families — which keep the Pendle interface. None of those files is edited, and no other family's selectors change. The legacy V4 family's exit from the shared targets is one-directional: it stops inheriting them; they do not change.

## 6. Owner question

**None.** The ruling scopes the change to the legacy V4 vault; whether other families keep Pendle is answered by that scope — they keep it. No file name, error name, selector set, or layout is left open: §2-3 name them. Size is measured after the change per the standing rule, with no hop or self-call permitted to pass the gate.

I did not run Forge.
