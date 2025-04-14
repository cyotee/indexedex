# Plan: Split Oversized Protocol DETF Facets

## Context

Two Protocol DETF facets exceed the EIP-170 contract size limit (24,576 bytes), causing Stage 16 deployment to fail with 3 transaction failures:

| Facet | Size | Over By |
|-------|------|---------|
| `ProtocolDETFExchangeInFacet` | 24,668 bytes | 92 bytes |
| `ProtocolDETFBondingFacet` | 26,370 bytes | 1,794 bytes |

**Cascade**: Both facet deployments fail -> CHIR vault deployment fails (depends on facets) -> CHIR has no code on-chain -> Staking page and CHIR preview are broken.

## Approach: View/Execute Split (Matching Existing Pattern)

The codebase already uses this pattern in Balancer V3 routers:
- `BalancerV3StandardExchangeRouterExactInQueryFacet` (view)
- `BalancerV3StandardExchangeRouterExactInSwapFacet` (execute)

### Split 1: ProtocolDETFExchangeInFacet -> Two Facets

**Current**: 3 external functions (`previewExchangeIn`, `exchangeIn`, `previewBptToWeth`)

**New `ProtocolDETFExchangeInQueryFacet`** (estimated ~12KB):
- `previewExchangeIn` (view) -- 8 route previews
- `previewBptToWeth` (view) -- BPT->WETH price preview

**Modified `ProtocolDETFExchangeInFacet`** (estimated ~13KB):
- `exchangeIn` (state-changing) -- 8 route executions

### Split 2: ProtocolDETFBondingFacet -> Two Facets

**Current**: 21 external functions (15 view, 6 state-changing)

**New `ProtocolDETFBondingQueryFacet`** (estimated ~10KB):
- 17 view functions: `syntheticPrice`, `isMintingAllowed`, `isBurningAllowed`, `chirWethVault`, `richChirVault`, `reservePool`, `protocolNFTVault`, `richToken`, `richirToken`, `chirToken`, `protocolNFTId`, `mintThreshold`, `burnThreshold`, `wethToken`, `previewClaimLiquidity`, `previewRichToRichir`, `previewWethToRichir`

**Modified `ProtocolDETFBondingFacet`** (estimated ~16KB):
- 8 state-changing functions: `bondWithWeth`, `bondWithRich`, `captureSeigniorage`, `sellNFT`, `donate`, `claimLiquidity`, `richToRichir`, `wethToRichir`

## Files to Create

1. **`contracts/vaults/protocol/ProtocolDETFExchangeInQueryTarget.sol`** [DONE]
   - Extends `ProtocolDETFCommon`
   - Contains: `previewExchangeIn`, `previewBptToWeth`, and all `_preview*` internal view helpers

2. **`contracts/vaults/protocol/ProtocolDETFExchangeInQueryFacet.sol`** [DONE]
   - Extends `ProtocolDETFExchangeInQueryTarget`, `IFacet`
   - `facetFuncs()` returns: `[previewExchangeIn.selector, previewBptToWeth.selector]`

3. **`contracts/vaults/protocol/ProtocolDETFBondingQueryTarget.sol`** [DONE]
   - Extends `ProtocolDETFCommon`
   - Contains: all view functions from BondingTarget + previewRichToRichir, previewWethToRichir

4. **`contracts/vaults/protocol/ProtocolDETFBondingQueryFacet.sol`** [DONE]
   - Extends `ProtocolDETFBondingQueryTarget`, `IFacet`
   - `facetFuncs()` returns: all 17 view selectors

## Files to Modify

5. **`contracts/vaults/protocol/ProtocolDETFExchangeInTarget.sol`** [DONE]
   - Remove all `_preview*` functions (except `_previewChirRedemptionBptIn` needed by execute path)
   - Remove `previewExchangeIn` and `previewBptToWeth`
   - Remove `is IStandardExchangeIn` (no longer fully implements interface)
   - Keep: `exchangeIn`, all `_execute*` functions, all internal state-changing helpers

6. **`contracts/vaults/protocol/ProtocolDETFExchangeInFacet.sol`** [DONE]
   - Update `facetFuncs()` to only return `[exchangeIn.selector]`
   - Update `facetInterfaces()` -- keep `IStandardExchangeIn`
   - Update `facetMetadata()` to match

7. **`contracts/vaults/protocol/ProtocolDETFBondingTarget.sol`** [DONE]
   - Remove all view/getter functions
   - Remove `previewRichToRichir`, `previewWethToRichir`
   - Remove `is IProtocolDETFBonding` (no longer fully implements interface)
   - Keep: `bondWithWeth`, `bondWithRich`, `captureSeigniorage`, `sellNFT`, `donate`, `claimLiquidity`, `richToRichir`, `wethToRichir` and internal helpers

8. **`contracts/vaults/protocol/ProtocolDETFBondingFacet.sol`** [DONE]
   - Update `facetFuncs()` to return 8 state-changing selectors
   - Update `facetInterfaces()`
   - Update `facetMetadata()` to match

9. **`contracts/vaults/protocol/ProtocolDETF_Facet_FactoryService.sol`** [DONE]
   - Add: `deployProtocolDETFExchangeInQueryFacet(ICreate3FactoryProxy)`
   - Add: `deployProtocolDETFBondingQueryFacet(ICreate3FactoryProxy)`

10. **`contracts/vaults/protocol/ProtocolDETFDFPkg.sol`** [DONE]
    - Add 2 new immutable facet references to PkgInit and constructor
    - Increase `facetAddresses()` array size from 8 -> 10
    - Add 2 new `FacetCut` entries in `facetCuts()`

11. **`contracts/vaults/protocol/Protocol_Component_FactoryService.sol`** [DONE]
    - Add 2 new facet fields to `ProtocolDETFFacets` struct
    - Update `buildProtocolDETFPkgInit` to pass new facets

12. **`scripts/foundry/anvil_base_main/Script_16_DeployProtocolDETF.s.sol`** [DONE]
    - Deploy the 2 new query facets
    - Pass them to the package constructor

## Shared Internal Functions

Functions needed by BOTH ExchangeIn targets (duplicated in bytecode, not an issue):
- `_previewChirRedemptionBptIn` -- called by `_executeChirRedemption` (execute path) and `_previewChirRedemption` (view path)
- `_loadReservePoolData` -- from `ProtocolDETFCommon` (inherited by both)

## Verification

1. **Compile and check sizes**: `forge build` then check `out/` artifacts for all 4 facets < 24,576 bytes
2. **Run existing tests**: `forge test --match-path test/foundry/spec/vaults/protocol/` -- all tests go through Diamond proxy so should pass without changes
3. **Redeploy Stage 16**: Run deployment, verify 0 transaction failures
4. **Verify CHIR on-chain**: `cast call 0xc279... "richToken()(address)" --rpc-url http://127.0.0.1:8545`
5. **Test frontend**: CHIR preview and staking page should work
