# Stage 01 — CP single SE buffer hook → §15.12 (pathfinder)

## Agent execution header

| Field | Value |
|-------|--------|
| **Stage ID** | **01** |
| **This file is the sole implementation scope** | This hook tree only + tests under its match-path |
| **Depends on** | **00** green |
| **Blocks** | **07** (DETF vs CP). Prefer green before 02–05 treat ABI as settled |
| **Product law** | PRD §15.12, §15.12.1, H2, H4, H5, H10, H11, H19, §16 |
| **Package** | `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/` |

**Conforms to product law; no re-litigation.**

---

## 1. Goals / non-goals

### Goals

1. This hook **is** `IUniswapV4SeBufferHook` + `IDetfReserveQuote`.
2. AddressSets + maps in the Repo; classify via Stage 00 lib.
3. `joinUnbalanced(address[] tokens, uint256[] amounts, …)` executes CP join; pair **or** SE share per slot.
4. `firstJoinMustBeFullBook() == true`. `requiredFirstBondTokens()` = `tokens()` (DETF raw + pair). `joinSingleAssetExactIn` reverts until `isLive()`.
5. Delete public old names: `deposit`, `depositSingle`, `withdraw`, `withdrawSingle`, `zeroForOne` swap preview, `*Flexible`, `*WithPermit2*` on this ABI.
6. `previewSynthetic` / `previewBurnToToken` / `previewSwapExactIn(address,address,uint256)` / `ownerSwapExactIn` wired to existing CP math. Views return **0** on empty/unquotable (H2).
7. Existing TestBase still deploys via hook DFPkg / registry / `deployHookVault`. Rewrite callers off deleted names.

### Non-goals

- Other hook families (02–05).
- DETF package (07).
- Dual SE. Bare pair (`standardExchangeOf == 0`) remains illegal for DETF bind; this package always has one SE.

---

## 2. Files to touch (this stage only)

Under `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/`:

- Repo: add `AddressSet pairTokens`, `standardExchanges`, maps, `detfToken`, init via Stage 00 helper.
- Targets/facets that currently expose `deposit*` / `withdraw*`: replace with join/exit names; keep math internal.
- Interface: `is IUniswapV4SeBufferHook`, `is IDetfReserveQuote`. Family extras (`pairToken()`, `rawToken()`, `standardExchange()`) may remain as **views that delegate** to `tokens()` / `standardExchangeOf`; do not keep `depositSingle` on the interface.
- DFPkg `diamondConfig` / facet cuts: drop deleted selectors; add new ones. Shared ERC20Permit + MultiAsset vault facets stay.
- Tests: `TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol` and `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/**`.

**Do not** edit Orbital/Weighted/Quad/Dual trees. **Do not** edit DETF packages.

---

## 3. Behavior locks

- Classify join/swap `tokenIn` with AddressSets. Unknown → `InvalidRoute`.
- Pair + that pair’s share in one `joinUnbalanced` → revert (same `tokens()` index).
- `previewBurnToToken`: prop exit, rejoin DETF, residual to `tokenOut`. No `exitSingleAsset*` on that path (H10). `exitSingleAsset*` may exist for ordinary LP.
- Owner swap: `ownerSwapExactIn` / `ownerSwapExactOut` only. No public `swapExact*`. Public trading remains PoolManager doors.
- Fee getter: `tradingFeeWad()` only.
- LP at rest: not this stage’s DETF inventory test; hook still must not require LP on arbitrary wallets for quotes (owned LP is an argument on `DetfQuoteCtx`).

---

## 4. Test plan

```bash
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/**' -vv
```

Also any co-located TestBase tests discovered by that path. If tests live next to the package under `contracts/hooks/.../TestBase_*.sol`, they compile with the spec via import; still `--match-path` the spec dir. Add new specs in that spec directory:

| # | Test | Expect |
|---|------|--------|
| T1.1 | `tokens()` length 2; contains DETF raw + pair | |
| T1.2 | `standardExchangeOf(pair) != 0`; `pairTokens`/`standardExchanges` disjoint | |
| T1.3 | `firstJoinMustBeFullBook() == true` | |
| T1.4 | `joinSingleAssetExactIn` before live | revert |
| T1.5 | First `joinUnbalanced` missing a `tokens()` leg | revert |
| T1.6 | First join full book (pair or share + DETF) | `isLive()` | LP to `to` |
| T1.7 | After live, `joinSingleAssetExactIn(pair)` and `(share)` both succeed | |
| T1.8 | `joinUnbalanced` pair+share same leg | revert |
| T1.9 | `previewSwapExactIn(pair, detf, x)` closed form; preview==execute on `ownerSwapExactIn` | |
| T1.10 | Empty book `previewSynthetic` / swap preview | `0` |
| T1.11 | `previewBurnToToken` after live | preview==execute; not `exitSingleAsset*` |
| T1.12 | Deleted selectors (`depositSingle`, `previewSwapExactIn(bool,uint256)`) absent from loupe | |
| T1.13 | Unknown token on join | `InvalidRoute` |
| T1.14 | Registry deploy path still: `indexedexManager` / `deployHookVault`; no `new` DFPkg | |

---

## 5. Acceptance

- [x] Hook compiles with IUniswapV4SeBufferHook + IDetfReserveQuote; joinUnbalanced on DepositFacet loupe.
- [x] T1.1–T1.14 green on the match-path above (family deposit/withdraw wrappers kept so old CP DETF still type-checks).
- [x] Stage 00 tests still green.
- [x] No files outside this hook tree + its spec path (Surface/OwnerDuringLock selector fixes only).
