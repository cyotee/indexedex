# Contract Size Reduction — Wave Results

| Field | Value |
|-------|--------|
| **Program** | [`CONTRACT_SIZE_REDUCTION_IMPLEMENTATION_PLAN.md`](./CONTRACT_SIZE_REDUCTION_IMPLEMENTATION_PLAN.md) |
| **Law** | [`CONTRACT_SIZE_REDUCTION_PRD.md`](./CONTRACT_SIZE_REDUCTION_PRD.md) §1.1 |
| **Hard limit** | Runtime ≤ **24,576** bytes (EIP-170) |
| **Baseline** | `SIZES.log` 2026-08-11 (`yarn sizes` / forge compile --sizes) |
| **Final sizes** | Scratch `SIZES.log` 2026-08-12 post-program (`yarn sizes`) |
| **Parser** | `scripts/size_oversize_facets.py` — product Facet oversize **count=0**; G1 oversize **0/18** |

## G1 baseline freeze (before → after)

| # | Facet | Before RT | Before margin | Wave | After RT | After margin | Option | Notes |
|--:|-------|----------:|--------------:|:----:|---------:|-------------:|:------:|-------|
| 1 | `UniswapV4StandardExchangeOrbitalBufferHookHooksFacet` | 46,457 | −21,881 | W3 | 16,687 | +7,889 | 1a+2a | Role Target + external Math |
| 2 | `UniswapV4StandardExchangeOrbitalBufferHookDepositFacet` | 44,442 | −19,866 | W3 | 14,354 | +10,222 | 1a | Core addLiquidity only; Zap/Flexible split out |
| 3 | `UniswapV4StandardExchangeOrbitalBufferHookSeFacet` | 44,331 | −19,755 | W3 | 11,793 | +12,783 | 1a | Role Target |
| 4 | `UniswapV4StandardExchangeOrbitalBufferHookWithdrawFacet` | 44,278 | −19,702 | W3 | 13,030 | +11,546 | 1a | Role Target |
| 5 | `UniswapV4StandardExchangeWeightedBufferHookLiquidityFacet` | 41,471 | −16,895 | W4 | 575 | +24,001 | 1d | Empty stub; Join/Exit/JoinFlexible replace |
| 6 | `UniswapV4WeightedSwapHookHooksFacet` | 37,320 | −12,744 | W4 | 11,565 | +13,011 | 1a | Hooks Target only |
| 7 | `UniswapV4WeightedSwapHookLiquidityFacet` | 36,079 | −11,503 | W4 | 24,517 | +59 | 1a+2a | Liquidity Target + external Math |
| 8 | `UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacet` | 35,907 | −11,331 | W4 | 582 | +23,994 | 1d | Empty stub; Join/Exit replace |
| 9 | `UniswapV4DualStandardExchangeBufferConstantProductHookHooksFacet` | 32,905 | −8,329 | W2 | 12,546 | +12,030 | 1a | Role Target |
| 10 | `UniswapV4StandardExchangeWeightedDETFFacet` | 31,831 | −7,255 | W5 | 19,073 | +5,503 | 1e | Bonding only; CompoundFacet sibling |
| 11 | `UniswapV4DualStandardExchangeBufferConstantProductHookDepositFacet` | 31,437 | −6,861 | W2 | 19,088 | +5,488 | 1a | Role Target |
| 12 | `UniswapV4DualStandardExchangeBufferConstantProductHookSeFacet` | 31,145 | −6,569 | W2 | 7,021 | +17,555 | 1a | Role Target |
| 13 | `UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawFacet` | 31,054 | −6,478 | W2 | 8,299 | +16,277 | 1a | Role Target |
| 14 | `MultiVaultWeightedDetfExchangeInFacet` | 29,513 | −4,937 | W1 | 17,994 | +6,582 | 1c | Role Facets |
| 15 | `AerodromeStandardExchangeOutFacet` | 29,386 | −4,810 | W6 | 24,354 | +222 | 1b | Query/Execute split |
| 16 | `UniswapV4StandardExchangeOutFacet` | 28,547 | −3,971 | W6 | 23,815 | +761 | 1b+2b | OutQuery + OutExecutionDelegate zap |
| 17 | `MixedBufferMultiVaultStableDetfExchangeInFacet` | 28,438 | −3,862 | W1 | 17,213 | +7,363 | 1c | Role Facets |
| 18 | `UniswapV4StandardExchangeOrbitalDETFFacet` | 26,773 | −2,197 | W5 | 22,307 | +2,269 | 1e | Bonding/Exchange siblings |

## Replacement Facets (added by Option 1 splits)

| Wave | Facet | After RT | After margin | Option | Replaces / role |
|------|-------|---------:|-------------:|:------:|-----------------|
| W3 | `UniswapV4StandardExchangeOrbitalBufferHookDepositZapFacet` | 17,435 | +7,141 | 1a | Orbital depositSingle / zap previews |
| W3 | `UniswapV4StandardExchangeOrbitalBufferHookDepositFlexibleFacet` | 18,081 | +6,495 | 1a | Orbital depositFlexible |
| W4 | `UniswapV4StandardExchangeWeightedBufferHookJoinFacet` | 20,329 | +4,247 | 1d | Weighted join core |
| W4 | `UniswapV4StandardExchangeWeightedBufferHookJoinFlexibleFacet` | 18,543 | +6,033 | 1d | Weighted join flexible SE-share |
| W4 | `UniswapV4StandardExchangeWeightedBufferHookExitFacet` | 21,339 | +3,237 | 1d | Weighted exit / withdraw |
| W4 | `UniswapV4StandardExchangeCurveQuadStableBufferHookJoinFacet` | 22,284 | +2,292 | 1d | Curve join / deposit |
| W4 | `UniswapV4StandardExchangeCurveQuadStableBufferHookExitFacet` | 20,559 | +4,017 | 1d | Curve exit / withdraw |
| W5 | `UniswapV4StandardExchangeWeightedDETFExchangeFacet` | 20,209 | +4,367 | 1e | Weighted DETF exchange In |
| W5 | `UniswapV4StandardExchangeWeightedDETFCompoundFacet` | 18,007 | +6,569 | 1e | Claim / compound / expansion |
| W5 | `UniswapV4StandardExchangeWeightedDETFInfoFacet` | 13,306 | +11,270 | 1e | Info views |
| W6 | `UniswapV4StandardExchangeOutQueryFacet` | 14,831 | +9,745 | 1b | previewExchangeOut |
| W6 | `AerodromeStandardExchangeOutQueryFacet` | 13,716 | +10,860 | 1b | previewExchangeOut |
| W6 | `UniswapV4StandardExchangeOutExecutionDelegate` | 18,159 | +6,417 | 2b | CREATE3 zap-out delegate (not a Facet) |

## Wave notes

### W0 — Inventory tooling

- Confirmed G1 list against baseline `SIZES.log` (18/18 present, all negative margin).
- Added `scripts/size_oversize_facets.py`.
- Created this results log.

### W1 — MultiVault + MixedBuffer DETF

- **Option 1c:** Split mega `ExchangeInFacet` → Exchange / Bonding / Info Facets (CREATE3).
- DFPkg PkgInit + facetCuts expanded; TestBases + IFacet declaration tests updated.
- **Final:** both packages under limit.

### W2 — Dual SE CP Buffer

- **Option 1a:** Monotarget → Common + Hooks/Deposit/Withdraw/Se Targets; Facets inherit role Targets only.
- Dual Math already external pure (reference for W3/W4 Option 2a).
- **Final:** all four Dual Facets under limit.

### W3 — Orbital Buffer

- **Option 1a:** Common + role Targets; Deposit further split Core / Zap / Flexible Facets.
- **Option 2a:** Orbital Math pure leaf functions → `external pure` (small helpers stay internal).
- **Final:** all Orbital product Facets under limit.

### W4 — Liquidity-heavy hooks

- **Weighted Buffer:** Join / JoinFlexible / Exit Facets; old LiquidityFacet empty stub; Math external hot paths + LiquidityLib.
- **Weighted Swap:** Hooks + Liquidity Targets; Math external; LiquidityFacet +59 margin.
- **Curve Quad:** Join / Exit Facets; old LiquidityFacet empty stub; Math external.
- **Final:** G1 liquidity set cleared.

### W5 — Weighted + Orbital DETF

- **Option 1e:** Bonding / Exchange / Info / Compound siblings of Common (no Bonding→In→Out tower).
- Weighted: compound self-calls via `IWeightedDetfCompoundSelf` diamond routes so Bonding Facet does not carry compound bytecode.
- **Final:** Weighted DETF Facet 19,073; Orbital DETF Facet 22,307.

### W6 — Aerodrome Out + Uni V4 SE Out

- **Aerodrome:** OutQuery + execute Out Facets (Option 1b); PkgInit-only DFPkg deploy (stack-too-deep avoidance).
- **Uni V4:** OutBase + OutQueryFacet + OutFacet; CREATE3 `OutExecutionDelegate` for zap-out (Option 2b); direct swap + rebalance on Out Facet.
- **Final:** Aerodrome Out +222; Uni V4 Out +761.

### W7 — Gate

- `yarn sizes` → product Facet oversize inventory **empty** (`scripts/size_oversize_facets.py` count=0).
- G1 inventory **0/18 oversize**.
- No `via_ir`; no Option 3; no `new` Facet/DFPkg deploys.

## Deviations

| Item | Detail |
|------|--------|
| Deprecated LiquidityFacets | Weighted Buffer + Curve keep empty IFacet stubs (CREATE3 name salts / G1 list continuity) rather than delete files. |
| Uni V4 OutExecutionDelegate | CREATE3 helper contract (not Facet) for zap-out body; still ≤ EIP-170. |
| Weighted DETF compound self-calls | `IWeightedDetfCompoundSelf(address(this))` instead of `this.fn()` so Common does not declare external compound entrypoints. |
| Stack-too-deep | Aerodrome DFPkg multi-arg deploy path removed; PkgInit-only. Nested external Math call sites use temps / keep tiny helpers `internal`. |
