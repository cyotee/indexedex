# Progress Log: IDXEX-081

## Current Checkpoint

**Last checkpoint:** Implementation complete (2026-02-11)
**Next step:** Cleanup and ship: ensure only source/test/PROGRESS changes are committed (exclude forge `out/` + caches)
**Build status:** ✅ Verified: `forge build`
**Test status:** ✅ Verified: `forge test --match-path test/foundry/spec/vaults/protocol/ProtocolDETF_Routes.t.sol`

---

## Session Log

### 2026-02-11 - Implementation

- Removed token-specific exchange helpers from public interfaces:
  - `IProtocolDETFBonding` (in `contracts/vaults/protocol/ProtocolDETFBondingTarget.sol`): removed `richToRichir`, `wethToRichir` and their preview variants from the interface surface.
  - `IProtocolDETF` (in `contracts/interfaces/IProtocolDETF.sol`): removed `richToRichir`, `wethToRichir`, `previewRichToRichir`, `previewWethToRichir`, `previewBptToWeth`.
- Verified diamond selector registration reflects the reduced surface:
  - `contracts/vaults/protocol/ProtocolDETFBondingFacet.sol` exposes only bonding ops + `claimLiquidity`.
  - `contracts/vaults/protocol/ProtocolDETFExchangeInFacet.sol` exposes `exchangeIn` only.
  - `contracts/vaults/protocol/ProtocolDETFExchangeInQueryFacet.sol` exposes `previewExchangeIn` only.
- Routed BPT->WETH valuation through canonical preview route:
  - Added/confirmed `previewExchangeIn(reservePoolToken, bptAmount, wethToken)` support in `contracts/vaults/protocol/ProtocolDETFExchangeInQueryTarget.sol` via internal `_previewBptToWeth`.
  - Updated `contracts/vaults/protocol/RICHIRTarget.sol` to call `IStandardExchangeIn(detf).previewExchangeIn(bpt, shares, weth)` (try/catch for uninitialized DETF).
- Updated tests to use `exchangeIn`/`previewExchangeIn` instead of removed functions:
  - `test/foundry/spec/vaults/protocol/ProtocolDETF_Routes.t.sol`
- Verification:
  - Build: `forge build`
  - Tests: `forge test --match-path test/foundry/spec/vaults/protocol/ProtocolDETF_Routes.t.sol`

### 2026-02-08 - Task Created

- Task designed via /pm:design
- Scope: Remove richToRichir, wethToRichir, previewRichToRichir, previewWethToRichir, previewBptToWeth from public interfaces
- Keep internal implementations as helpers for the generic exchange router
- previewBptToWeth to be routed through previewExchangeIn or made internal-only
- Depends on IDXEX-072 (preview accuracy fixes must land first)
- TASK.md populated with requirements
- Ready for agent assignment via /pm:launch

---

### 2026-02-10 - Task Launched

- Task launched via /launch
- Agent worktree created at: /Users/cyotee/Development/github-cyotee/indexedex-wt/feature/IDXEX-081-remove-token-specific-exchange-routes
- Ready to begin implementation
