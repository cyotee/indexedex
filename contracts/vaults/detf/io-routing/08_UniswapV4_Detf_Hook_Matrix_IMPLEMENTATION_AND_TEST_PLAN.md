# Stage 08 — Unified DETF vs Orbital / Weighted / Quad hooks

## Agent execution header

| Field | Value |
|-------|--------|
| **Stage ID** | **08** |
| **This file is the sole implementation scope** | TestBase rows + DETF-only fixes required for n>2. Do not re-open Stage 01 CP unless a shared DETF bug |
| **Depends on** | **07** and **02**, **03**, **04** |
| **Blocks** | Program complete (hooks+DETF) |
| **Product law** | PRD §16, H8 per-path synthetic, all-legs-rich expansion when `syntheticNumeraires().length > 1` |

---

## Goals

Same DETF DFPkg as Stage 07. New TestBase fixtures: Orbital hook, Weighted hook (at least 2 external pairs), Quad hook. Assert processArgs, Default tables, first bond full book, live mint/burn on one pair, Custom close one token, AddressSets.

Do **not** bind Dual (already T7.1).

If DETF code must change for n>2 (creation/opening array length, H8 numeraire), keep changes inside `…/uniswap/v4/detf/` and re-run Stage 07 match-path.

---

## Test match

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/**' -vv
```

Add contracts e.g. `UniswapV4Detf_Orbital.t.sol`, `_Weighted.t.sol`, `_Quad.t.sol` so `--match-contract UniswapV4Detf_Orbital` can run one family in a worktree.

| # | Test |
|---|------|
| T8.1 | Orbital: Default mint rows = two pairs + two shares; first bond three legs |
| T8.2 | Weighted: `creationPairPerDetfWad.length == n-1`; Custom mint one pair only |
| T8.3 | Quad: first bond four legs; Custom close one pair; leftovers swap in `tokens()` order |
| T8.4 | H8: mint allowed on pair A and not B is possible (drive synthetics via real trades, not only Open mode) |
| T8.5 | CP Stage 07 tests still green |

---

## Acceptance

- [x] Three hook kinds + CP all deploy the **same** DETF DFPkg.
- [x] Match-path green. No Dual bind.
