# Stage 00 — Shared Uni V4 SE buffer hook ABI

## Agent execution header

| Field | Value |
|-------|--------|
| **Stage ID** | **00** |
| **This file is the sole implementation scope** | Do not edit family hook Targets/DFPkgs or any DETF package |
| **Depends on** | None |
| **Blocks** | 01–05 (hooks), 06 (imports), 07–08 |
| **Product law** | PRD §15.12, §15.12.1, §15.11 J1–J3, H18, §16.1. **§16 wins.** |
| **Program** | [`../DETF_INSTANCE_IO_ROUTING_PROGRAM.md`](../DETF_INSTANCE_IO_ROUTING_PROGRAM.md) |

**Conforms to product law; no re-litigation.**

---

## 1. Goals / non-goals

### Goals

1. One copy of the DETF-facing hook ABI (liquidity + swap + discovery).
2. One copy of the DETF quote ABI (`DetfQuoteCtx`, `previewSynthetic`, `previewBurnToToken`).
3. One classify helper over Crane `AddressSet` so stages 01–05 do not each invent membership.

### Non-goals

- Curve math (CP/Orbital/Weighted/Quad).
- Wiring `joinUnbalanced` execution on a live hook.
- DETF or Bond NFT packages.
- Changing family hook `PkgArgs` (except that later stages will `is` the new interfaces).

---

## 2. Files to touch (this stage only)

| File | Action |
|------|--------|
| `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol` | **Create.** Discovery, `ownerSwap*`, `previewSwap*`, join/exit including `joinUnbalanced(address[] tokens, uint256[] amounts, …)`, `tradingFeeWad`. Solidity as PRD §15.12. |
| `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol` | **Create.** `struct DetfQuoteCtx`, `previewSynthetic`, `previewBurnToToken`. |
| `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol` | **Create.** Pure/storage helpers: given `AddressSet pairTokens`, `AddressSet standardExchanges`, `address detfToken`, classify `addr` → `{Detf, Pair, StandardExchange, Unknown}`. No OZ EnumerableSet. Import `AddressSetRepo`. |
| `test/foundry/spec/hooks/uniswap/v4/interfaces/UniswapV4SeBufferHookLegLib.t.sol` | **Create.** Pure tests of classify + disjoint-set rules using a tiny harness that holds two `AddressSet`s (harness is not a hook SUT). |

**Do not** modify `contracts/hooks/uniswap/v4/standardExchange/**` product files in this stage.

---

## 3. Target design

### 3.1 Interfaces

Copy function signatures from PRD §15.12. Do not add aliases (`depositSingle`, `zeroForOne`, `*Flexible`, `*WithPermit2*`). NatSpec: `@custom:signature` / `@custom:selector` per Crane natspec skill if the file already uses them in this tree; otherwise match neighboring hook interfaces.

`IUniswapV4SeBufferHook` does **not** include `IStandardExchangeIn/Out`. Quote lives on `IDetfReserveQuote`.

### 3.2 Classify lib (normative)

```text
enum LegKind { Unknown, Detf, Pair, StandardExchange }

function classify(detfToken, pairTokens, standardExchanges, addr) → LegKind
  detfToken != 0 && addr == detfToken → Detf
  pairTokens._contains(addr) → Pair
  standardExchanges._contains(addr) → StandardExchange
  else → Unknown
```

Init helper (used by later stages, tested here with a harness):

- `_addPairSe(pair, se)` adds to both sets and both maps; reverts if `pair == se`, either is `detfToken`, `pair` already in `standardExchanges`, `se` already in `pairTokens`, or `pairOfStandardExchange[se]` already set to a different pair.

No public `isPair` on the ABI. Later stages call classify internally.

---

## 4. Test plan

| # | Test | Expect |
|---|------|--------|
| T0.1 | classify DETF address | `Detf` |
| T0.2 | classify pair | `Pair` |
| T0.3 | classify SE | `StandardExchange` |
| T0.4 | classify unknown | `Unknown` |
| T0.5 | `_addPairSe` overlap pair/SE | revert |
| T0.6 | two pairs one SE | revert |
| T0.7 | `detfToken` added as pair | revert |
| T0.8 | Interfaces compile; selectors unique (no duplicate names) | `forge build` of these files |

```bash
# Seed cache_forge/ + out/ first if this is a new worktree.
forge test --match-path test/foundry/spec/hooks/uniswap/v4/interfaces/UniswapV4SeBufferHookLegLib.t.sol -vv
```

Default hermetic profile only. Wait for forge exit.

---

## 5. Acceptance

- [ ] Both interfaces exist at the paths above and match PRD §15.12 (including `joinUnbalanced(address[],uint256[],…)`).
- [ ] Classify lib uses `AddressSetRepo._contains` / `_add` only for membership.
- [ ] T0.1–T0.8 green.
- [ ] No family hook or DETF files changed.
