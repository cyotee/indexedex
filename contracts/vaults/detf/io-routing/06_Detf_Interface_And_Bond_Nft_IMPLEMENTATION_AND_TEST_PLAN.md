# Stage 06 — `IUniswapV4Detf` + Uni V4 Bond NFT (R12a)

## Agent execution header

| Field | Value |
|-------|--------|
| **Stage ID** | **06** |
| **This file is the sole implementation scope** | New DETF interface + new Bond NFT package. No hook family edits. No unified DETF DFPkg body (07) |
| **Depends on** | **00** (quote types only if the interface references `DetfQuoteCtx`; prefer not to) |
| **Blocks** | **07** |
| **Product law** | PRD §3.2 `PkgArgs`, R2/R4/R7, R12a, §5.5, §16.1, §16.6, §16.9 |

---

## 1. Goals

1. `IUniswapV4Detf` with `PkgArgs` **on the interface** (exact field order PRD §3.2), `IoRoute`, `RouteTableMode`, route getters, mint/burn/bond/close/donate signatures from §16.2–16.6.
2. New Bond NFT DFPkg at `contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/` copied from `contracts/vaults/detf/common/bondNft/` **except** donate booking:
   - `totalOriginalShares > 0`: join LP; **do not** `addToDETFNFT` / `_creditId0`.
   - `totalOriginalShares == 0`: credit id 0 1:1 (N14).
3. Do **not** change `DETFNFTVaultTarget._donate` / `_creditId0`.

Integration donate tests that need a live DETF wait for Stage 07. This stage: package deploys, surface selectors, and a **booking unit** that can be tested with the production NFT + a minimal **non-SUT** only if you extract booking to a lib. Prefer: deploy the real NFT DFPkg via manager; skip join until 07; test `_creditId0` is **not** called when O>0 by extracting the booking branch into an internal that 07 hits.

If booking cannot be tested without `joinDonatedCapital`, implement the NFT here and **list donate NAV tests as 07 T7.*** Do not mock a DETF.

---

## 2. Files to touch

| File | Action |
|------|--------|
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol` | **Create.** `PkgArgs`, `IoRoute`, `RouteTableMode`, getters, mint/burn/bond/close. |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/**` | **Create** package (DFPkg, Facet, Target, Repo, FactoryService) from common NFT. R12a in donate. |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/bondNft/**` | Deploy via `indexedexManager`; selector surface; ids 1–2 still zero originalShares; **do not** regress common `DETFNFTVault` tests |

Copy common NFT FactoryService/registry wiring. Fresh types: `UniswapV4DetfBondNFTVaultDFPkg` (full words; no product brands).

---

## 3. Test match

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/bondNft/**' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/common/bondNft/**' -vv
```

Second command is **regression**: common NFT donate still credits id 0 (N4). If you did not touch common files, it must still pass.

| # | Test |
|---|------|
| T6.1 | `IUniswapV4Detf.PkgArgs` compiles; field order matches §3.2 |
| T6.2 | NFT DFPkg deploys via manager/registry; no `new` DFPkg/facet |
| T6.3 | Surface includes `donate` / `addToDETFNFT` / ids 0/1/2 law (1–2 cannot close) |
| T6.4 | Common `DETFNFTVault` specs still green |

---

## 4. Acceptance

- [ ] Interface + NFT package exist at the paths above.
- [ ] Common bond NFT **unchanged** (diff empty on `common/bondNft/` except if a shared interface import is required; prefer empty).
- [ ] T6.1–T6.4 green.
