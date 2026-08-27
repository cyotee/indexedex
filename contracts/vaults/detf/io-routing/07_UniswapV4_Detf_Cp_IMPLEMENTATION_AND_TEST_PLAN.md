# Stage 07 — Unified Uni V4 DETF DFPkg vs CP hook

## Agent execution header

| Field | Value |
|-------|--------|
| **Stage ID** | **07** |
| **This file is the sole implementation scope** | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/` + tests under that spec path. May **wire** Stage 06 NFT. Must not edit hook families except imports |
| **Depends on** | **01** green **and** **06** green |
| **Blocks** | **08** |
| **Product law** | PRD **§16** (entire), §3.3, §5, §6, §15.13, §16.9 |
| **Package** | `UniswapV4DetfDFPkg` at `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/` |

**Fresh codepath.** Do not subclass old CP/Orbital/Weighted/Quad DETF contracts. Reuse `detf/common/core/*` libs (thresholds, expansion, compound, bond math).

---

## 1. Goals

1. Hook DFPkg first (Stage 01 instance). DETF `PkgArgs.hook` = that address. CREATE3-predicted DETF address was hook owner + DETF currency at hook deploy.
2. `processArgs` as PRD §3.3. Dual hook → revert (`address(this)` not in `tokens()`).
3. Default tables: pairs + SE shares only (§15.13). AddressSets §16.9.
4. Live mint/burn/bond/close/donate per §16.2–16.6. Exact-in only.
5. Bond NFT is Stage 06 package (R12a).
6. Opacity: DETF sources import quote + SE + Bond NFT + hook ABI. No ConstProd in the DETF.

---

## 2. Files to touch

`contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/**` (DFPkg, facets, targets, repos, FactoryService).

`test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/**` including `TestBase_UniswapV4Detf.sol`.

Do **not** edit old `…/uniswap/v4/standardExchange/constantProduct/single/` **DETF** package except if a test import must stay compiling (leave it).

---

## 3. Deploy in TestBase

```text
IndexedexTest → deploy CP buffer hook DFPkg (Stage 01) with predicted DETF
             → deploy UniswapV4DetfDFPkg via indexedexManager
             → postDeploy Bond NFT (06) + claim as peers
```

Never `new` the DETF DFPkg. Never `diamondPackageFactory.deploy` for this registered package.

---

## 4. Test match

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/**' -vv
```

Implement PRD §16.8 on **CP** (`n=2`) at least:

| # | Test |
|---|------|
| T7.1 | processArgs: Dual as hook reverts; bare `standardExchangeOf == 0` reverts; Custom close length != 1 reverts |
| T7.2 | Default mint/burn/bond = pair + share; no SE underlyings |
| T7.3 | Custom mint SE underlying not in `hook.tokens()` with vault a hook SE; Default still omits it |
| T7.4 | Custom vault not in hook SE set reverts |
| T7.5 | First bond `joinUnbalanced` full book; ungated; then live |
| T7.6 | Live mint: Gross = `previewSwapExactIn(pair, detf, pairEq*(1+p))`; LP delta = join preview; D11 no DETF into reserve |
| T7.7 | Live mint with share: pairEq from `previewExchangeOut`; still swap-quote the pair |
| T7.8 | Policy gate `isMintingAllowed(token)` per H8; no-arg true iff some mintRoutes token passes |
| T7.9 | Live burn `previewBurnToToken`; DETF burned; leftover LP back to NFT |
| T7.10 | Later bond one `joinUnbalanced` G+capital; G unboosted mix |
| T7.11 | Custom close length 1: leftover `ownerSwapExactIn` in `tokens()` order |
| T7.12 | Default close: basket, no swaps; `minAmountsOut[DETF]=0` |
| T7.13 | Donate R12a: O>0 no originalShares mint; user `convertToAssets` rises; O==0 credits id 0 |
| T7.14 | Common NFT not used; diamond+claim `balanceOf(hook LP)==0` after money paths |
| T7.15 | `test_L2_FoT_forbidden` real FoT as configured pair |
| T7.16 | Exact-out mint/burn omitted or `InvalidRoute` |
| T7.17 | `joinUnbalanced` pair+share same leg reverts (via first bond or later) |
| T7.18 | `IDetf.pairToken()` / `rateAsset()` / `underlyingVault()` not relied on; `reservePool()` = hook |
| T7.19 | After mint/burn/bond/close/donate/compound: diamond `balanceOf` hook LP, each `tokens()` entry, and each bound SE share is 0 when a join was possible (R19) |
| T7.20 | Transfer pair dust onto the live diamond; `sweepDust()` joins it; NFT LP up; no originalShares mint when `O > 0`; user `convertToAssets` rises |
| T7.21 | Failed dust join does not revert the mint that triggered the sweep; public `sweepDust` later clears it or no-ops |

---

## 5. Acceptance

- [x] DETF DFPkg deploys only via manager/registry.
- [x] Match-path T7.* green. Stages 00, 01, 06 still green on their match-paths (run if you touched shared files; 07 should not have).
- [x] Old Uni V4 DETF packages untouched.
