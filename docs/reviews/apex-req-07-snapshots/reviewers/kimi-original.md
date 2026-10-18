# Kimi K3 — REQ-07 snapshots: does any vault take or keep them? (replacement-session original)

- **Label:** Replacement-session original, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read. Scope: `contracts/` in this repository. Controlling text: OD-02 and REQ-07 in `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` (`:99` area for OD-02; REQ-07 at `:291-306`, read in full). Nothing was edited. I did not run Forge.
- **Date:** 2026-10-18.

## Short answer: the owner's reading is correct — no vault keeps snapshots, and nothing self-snapshots anymore.

The snapshot bytes (`quoteState` output) are produced on demand by view functions, consumed within the same call or by a caller's own projection chain, and never written to contract storage anywhere in `contracts/`. The one production component that used to take its own snapshot — the rate provider's gas-gated probe — is already gone from current source. On this tree, the concern is a non-problem.

## 1. Does any vault or hook store snapshot bytes in contract storage? No.

A full sweep of `contracts/` for `bytes` state variables and `bytes` fields in storage structs found only:

- `contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory.sol:70` — `mapping(address => bytes) pkgArgsOfAccount` (deployment package arguments, unrelated to quote snapshots).
- `contracts/vaults/detf/protocols/dexes/balancer/v3/common/DETFBalancerReserveSwapRepo.sol:9` and `contracts/protocols/dexes/balancer/v3/pools/BalancerV3PoolStandardExchangeRepo.sol:9` — single `bytes32` pending-operation markers (hashes/flags, not snapshot payloads).

Everything else with `bytes` storage is a test stub/harness (`contracts/test/stubs/*`, protocol hermetic harnesses). **No snapshot bytes are stored anywhere.**

## 2. Who builds an ephemeral `quoteState` and passes it onward

Producers are all `external view` — they compute the snapshot from live state at call time and return it; nothing persists:

- SE/vault implementations: `UniswapV2StandardExchangeQuoteTarget.sol:31`, `CamelotV2StandardExchangeQuoteTarget.sol:32`, `AerodromeStandardExchangeQuoteTarget.sol:42`, `BalancerV3PoolStandardExchangeTransitionQuoteTarget.sol:161`, `ERC4626StandardExchangeQuoteTarget.sol:33`, `MorphoBlueStandardExchangeQuoteTarget.sol:32`, `RocketPoolRETHStandardExchangeInTarget.sol:144`, `LidoWstETHStandardExchangeInTarget.sol:194`, `EtherFiWeETHStandardExchangeInTarget.sol:133`, `AaveV3StataStandardExchangeInTarget.sol:115`, `AaveCrossVersionLoopStandardExchangeTransitionQuoteTarget.sol:58` (struct snapshot, memory), `RebasingAwareStandardExchangeQuoteTarget.sol:29` (via `RebasingAwareERC4626Common.snapshotQuoteState` at `:505`), V3 FullSpread `…VaultInQueryTarget.sol:43`, V4 hookless `…OutQueryTarget.sol:20`, V4 Pons `…OutQueryTarget.sol:20`, wings `…VaultTransitionTarget.sol:14` (which also implements the unlock-context projection at `:30`, as do hookless `:43` and Pons `:43`).

Ephemeral consumers (build a snapshot mid-call and pass it through a `quoteTransition` projection chain, all in memory — the D48 sequential-projection design the REQ-07 non-goals preserve):

- `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol:47,57`
- `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol:55,75`
- `…/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib.sol:257`, `…DepositQuoteLib.sol:100`, `…InQuoteBase.sol:125`
- `…/standardExchange/constantProduct/single/…InQuoteBase.sol:115`, `…ClaimLib.sol:37,191,490,580`
- `…/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol:62`

No other production caller exists; the remaining `quoteState` hits in the tree are the interface declarations and test bases.

## 3. Does the rate provider call `quoteState` itself on an empty state? No — and nothing reads `gasleft()`

Current `StandardExchangeRateProviderFacet.sol` (read in full this round):

- `getRate()` → `_getRate("")` (`:45-47`). On the empty state, `_getRate` reads the live book: `subject_.totalSupply()` (`:67`) and prices it through the live preview — `_safePreviewExchangeIn` selects `IStandardExchangeIn.previewExchangeIn` when `state.length == 0` (`:119-121`). A failed full-book quote returns 0 rather than falling back to a stale snapshot (`:77-81`).
- `quoteRate(exchange, asset, state)` with a caller-supplied snapshot remains and prices against it via `quoteTotalSupply(state)` / `quoteAssets(state, …)` (`:49-59`, `:67-68`, `:119-120`) — the non-goal's preserved path; a failed snapshot yields 0, never the live rate.
- `quoteState` appears nowhere in the file; `gasleft()` appears nowhere in `contracts/` at all (zero grep hits).

That is exactly OD-02/REQ-07's intended shape: the plain rate call is the live preview; the gas-gated self-snapshot branch the September PRD described is absent from current source.

## Verdict: No implementation gap.

No vault takes or keeps snapshots in storage; the ephemeral hook projections are the designed, non-goal-protected consumers; the rate provider's empty-state path is already live-preview-only. The defect REQ-07 described is absent from current source. No new product rule is proposed, and none is needed.

**Boundaries:** this is a source-presence/absence inventory (grep plus targeted reads of every production hit), not a runtime trace of deployed instances; per REQ-07's own non-goal, nothing here speaks to live deployed copies. I did not run Forge.

I did not run Forge.
