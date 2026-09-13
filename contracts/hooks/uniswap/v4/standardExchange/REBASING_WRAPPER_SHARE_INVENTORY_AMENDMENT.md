# Static wrapper-share inventory binding (plan §8 companion)

**Status:** Owner-approved for implementation (2026-09-11). Completes the remaining RebasingAwareERC4626 SY/SE work after TokenStaking was dropped.  
**Amends:** `REBASING_AWARE_ERC4626_SY_SE_PRD.md` D-06 / API-16–18 / F-16 and `REBASING_AWARE_ERC4626_SY_SE_IMPLEMENTATION_AND_TEST_PLAN.md` §8.  
**Does not amend:** HDEC-2 (no ERC-20 calls on empty DETF self-leg), D60 Balancer-hosted DETFs, D66 unfinished Slipstream.

## 1. Binding

Pool currencies and persistent balances are **static wrapper shares**. The rebasing asset never sits in the pool.

| Role | Address | Decimals |
|---|---|---|
| Pool pair / inventory | wrapper diamond (`detfToken` is not this) | `assetDecimals + effectiveOffset` (default 19 or 28; allowed 19–36) |
| Bound Standard Exchange | same wrapper diamond | same |
| Wrapper underlying | `IERC4626(wrapper).asset()` | captured asset decimals |
| DETF self-leg (`rawToken` / `se == 0`) | predicted DETF | 18 (unchanged) |

Discriminator (no new PkgArgs field; ABI order unchanged):

`pairToken == standardExchange` **and** `IERC4626(pairToken).asset()` is a different non-zero address.

Ordinary bindings (`pair != se`) keep PairSeOverlap, `[6,18]` decimals, and existing SE `vaultTokens()` membership.

## 2. Disjoint-set rule

`UniswapV4SeBufferHookLegLib.addPairSe` allows `pair == se` only when the discriminator holds. Classify still returns `LegKind.Pair` first (pool custody is shares). `standardExchangeOf[pair] == pair`. Non-wrapper `pair == se` still reverts `PairSeOverlap`.

Weighted / orbital / curve / balancer `_requireSeOwnsToken` and dual `_requireTokenInVaultTokens` skip membership of shares in `vaultTokens()` for this discriminator (`vaultTokens()` is `[asset]`, not `[shares]`).

## 3. Quotes and rates

Quote units are wrapper shares. Rate providers used by a bound buffer must read `IStandardExchangeRateQuote.quoteRate` on projected `QuoteState`, not a stale live wrapper rate. Live snapshots after a settled rebase capture new backing; stale snapshots do not authorize execution.

## 4. Routing

- Join pair-side: pull existing wrapper shares. Do not call wrapper share→share SE (`API-04` forbids it). `_bufferPair` is identity.
- Exit pair-side: return wrapper shares. `_unwrapSeShares` is identity.
- Wrap/unwrap of the rebasing asset happens on the wrapper, atomically, **outside** pool custody (`deposit` / `redeem` / SE asset↔share). The hook does not take `pretransferred=true` on the raw asset.
- Raw-asset pretransfer into the buffer reverts (`AssetPretransferNotSupported` on the wrapper, or the hook never classifies the raw asset as pair inventory).
- Allowance cleanup: identity paths do not `forceApprove` the wrapper for share→share.

## 5. Fees and rounding

Wrapper fee type remains `bytes32(0)`. Outer buffer/DETF fees are unchanged. CP/weighted/orbital/quad math already wad-normalizes decimals `> 18` (`toWad` divides by `10^(d-18)`). That is the scaling equation for 19-/28-decimal inventory.

## 6. Family table

| Family | Package | TestBase | Routing | DETF |
|---|---|---|---|---|
| CP single | `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol` | `TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook` | identity buffer/unwrap; wrap outside via wrapper | composed join/quote/swap/exit; DETF issuance uses existing UniV4 DETF factory with this hook as reserve |
| Weighted | `weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol` | family TestBase | wrapper-eligible legs; mixed static legs allowed | same discriminator per SE leg |
| Orbital | `orbital/UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol` | family TestBase | each eligible SE leg | same |
| Curve quad | `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg.sol` | family TestBase | each eligible SE leg | same |
| Balancer quad V4 hook | `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg.sol` | family TestBase | V4 hook only; not Balancer-hosted DETF | same |
| Dual CP | `dual/UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol` | family TestBase | both legs may bind wrapper independently | standalone only; do not claim DETF factory binding |
| Legacy single | `single/` | existing | compile/regression only | no new DETF claim |

## 7. Required tests (every approved row except legacy)

Positive/negative rebase on wrapper backing, donation, zero reserve, stale quote, transfer-triggered settlement fail-closed, disabled inbound/live exits, zero wrapper fees with nonzero outer fees, rejected raw-asset pretransfer.
