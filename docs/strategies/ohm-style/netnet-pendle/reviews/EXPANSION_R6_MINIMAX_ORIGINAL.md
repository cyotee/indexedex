# MiniMax M3 — EXPANSION_R6 first pass

- Identity: `minimax/MiniMax-M3` (council-minimax, independent). Provider attestation: not claimed.
- Source: PRD v0.15, REQUIREMENTS_QUESTIONS.md (A11–A18), `NETNET_PENDLE_OPERATION_MATRIX.md`, `CLAUDE.md`, `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol` (lines 308–380), `contracts/vaults/detf/common/core/DETFEpochNaturalExpansionLib.sol`, `contracts/vaults/detf/common/core/DETFThresholdPolicy.sol`, `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProcessArgsLib.sol`, `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DFPkg.sol`, `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget.sol` (lines 89–140). No peer artifacts read. No shell/tests/delegation.

## Verified Universal V4 expansion mechanics (in-code)

**Per-epoch mint formula** — `DETFEpochNaturalExpansionLib.sol:33–46` `previewPendingExpansionMint`:

```
ONE                 = 1e18
EPOCH               = 8 hours
YEAR                = 365 days
DEFAULT_CLOSURE     = 0.10e18   (10%/yr)
DEFAULT_DUST        = 1
epochs_             = (now - lastExpansionTimestamp) / EPOCH         // floor div
closurePerEpoch_    = mulDiv(expansionClosureRatePerYearWad, EPOCH, YEAR)  // ~9.13e-5 at default rate
perEpoch_           = mulDiv(
                        mulDiv(totalDetfSupply, spotPrice - ONE, spotPrice),
                        closurePerEpoch_, ONE)
mint_               = perEpoch_ * epochs_
```

**Eligibility** (line 33–38, must all hold): `isLive == true`; `nowTimestamp > lastExpansionTimestamp`; `(now - lastExpansionTimestamp) >= EPOCH`; `totalDetfSupply > 0`; `spotSyntheticPrice > ONE` (= 1.0 normalized); `spotSyntheticPrice > mintThreshold`. **Skipped** when `mint_ <= DEFAULT_DUST` (1).

**Realization** (line 50–58, `computeRealization`): always consumes all completed 8h boundaries even when mint=0; sets `newLastTimestamp = lastExpansionTimestamp + epochs*EPOCH`. **No caps; no historical compounding; no missing-epoch replay** — `lastExpansionTimestamp` advances by exactly `epochs*EPOCH` per call.

**Highest-of-legs** (`UniswapV4DetfCommon.sol:324–341` `_highestSyntheticPrice`): iterates **all** `s.hookPairTokens`, calls `quote.previewSynthetic(ctx, pair)` on each, picks `max`. Single expansion uses the single highest.

**Synthetic price formula** (`WeightedBufferHookExitQueryTarget.sol:89–140`):
```
marked             = Σ over non-DETF legs i of rated[j] * w_i / w_out  (Balancer weighted mark)
pairWad           = marked * ctx.ownedLp / lpSupplyAfterProtocolMint
mid_              = pairWad * 1e18 / (detfTotalSupply + pendingExpansion)
syntheticPrice    = (mid_ * 1e18) / ctx.creationPairPerDetfWad
```
Returns 0 if any denominator is zero. Uses **creationPairPerDetfWad** (per-pair WAD rate), NOT opening rate. `mid_` is the live inventory mark; the synthetic price is normalized by the **creation rate** so synthetic = 1.0 at the opening ratio.

**Funding destination** (`UniswapV4DetfCommon.sol:373–380` `_fundStakingRewards`): `_mintDetf(address(this), mintAmount_)` → `IERC20(address(this)).forceApprove(staking_, amount_)` → `IStakedDETF(staking_).fundRewards(amount_)`. Minted DETF lands in **DETF proxy**, then transferred to **sNET-DETF contract** to back staking rewards (R43 selected).

**Defaults & config** (`DETFThresholdPolicy.sol:16-30` and `DETFEpochNaturalExpansionLib.sol:11-13`):
- `DEFAULT_MINT_THRESHOLD = 1.05e18`
- `DEFAULT_BURN_THRESHOLD = 0.95e18`
- `DEFAULT_CLOSURE_RATE_PER_YEAR_WAD = 0.10e18`
- `DEFAULT_EXPANSION_DUST = 1`

**Creation vs opening rate** (`UniswapV4DetfProcessArgsLib.sol:82-127` `resolveOpening`, `UniswapV4DetfCommon.sol:259-263` `_openingBondQuote`):
- `creationPairPerDetfWad[i]`: required per-pair WAD rate; sets the synthetic-price denominator.
- `openingPairPerDetfWad[i]`: optional override; if non-zero, used for first bond quote; if zero, falls back to `creationPairPerDetfWad[i]`.
- `openingPrice = floor(nativeToWad(pair, x) * 1e9 / P0)`. For 9-decimal NET/DETF, `P0 = 1000e18` opens at 1:1 if `x = 1000 raw NET`; `Q(1000e9) = floor(1000e18 * 1e9 / 1000e18) = 1e9 = 1 raw DETF`.

**Epoch anchor** (`UniswapV4DetfCommon.sol:367–370` `_hasCompletedExpansionEpoch` + PRD §24.3.2): anchor = `firstSuccessfulBond.timestamp`; 8h boundaries advance from anchor. NET-state sync per §24.3.2 (selected).

## View price vs executable swap

`previewPendingExpansionMint` (line 33) is **view-only**. The actual mint path is `_realizeExpansionIfNeeded` (line 343). The former reports the prospective mint; the latter updates `lastExpansionTimestamp` and mints. **View price alone cannot mint** — only an invocation that survives `whenNotPaused`, `_hasCompletedExpansionEpoch`, and the eligibility preconditions produces an actual mint.

## High opening 1000 NET/DETF: does it create synthetic expansion premium?

**No — opening 1000 creates the normalization, not premium.** `syntheticPrice = mid / creationPairPerDetfWad`. If `creationPairPerDetfWad = 1000e18` and current spot mid = 1000 pair/DETF, then `syntheticPrice = 1.0`. Above 1.0 requires mid > 1000 pair/DETF. **Equal to opening 1.0 is NOT expansion-eligible**; line 36 `spotSyntheticPrice <= ONE` returns 0. The opening price sets the `creationPairPerDetfWad` denominator; it does not start the synthetic price above 1.0.

## User's "strictly above 1 NET/DETF" — verified

Reading the eligibility condition `spotSyntheticPrice > ONE` (line 36): the **normalized** synthetic price must be strictly above 1.0. With `creationPairPerDetfWad = 1000e18` (1 DETF pegged to 1000 NET), the only way to satisfy `spotSyntheticPrice > 1.0` is **mid > 1000 NET/DETF** at the V4 hook level. The user requirement ("custom expansion price gate strictly above 1 NET/DETF") is therefore satisfied by the existing `spotSyntheticPrice > ONE` predicate and the explicit mintThreshold; **no new mint-gate logic is required** to express this preference — set `mintThreshold = 1.0e18` (the "strictly above 1.0" gate) or any higher value. Note: default `mintThreshold = 1.05e18` is **5% premium above opening**, which the user can keep or override via PkgArgs.

## Defaults owner override path (no source change required)

To express "0.5% per processed NET epoch" via existing parameters:
- `expansionClosureRatePerYearWad` is **annual**. 0.5%/epoch × 3 epochs/day × 365 days/year ≈ **547% annual**. Configure `expansionClosureRatePerYearWad = 547e18 / 10 = 54.7e18`? **No** — the formula is `closurePerEpoch_ = rate * EPOCH / YEAR = rate * 8/8760 ≈ rate * 9.13e-5`. To get 0.5% per epoch, set `rate * 9.13e-5 = 0.005`, so `rate ≈ 54.75`. WAD-encoding: `expansionClosureRatePerYearWad = 54.75e18`. Verify via `previewPendingExpansionMint`. **Do not blindly encode**; the user-selected 0.5%/epoch is a **rate, basis, and gate** that the human must confirm — selection is owner economic choice.

## Hand-calculated worked example

Inputs: lead payment `A = 1000 raw NET` (9-dec, nativeToWad → `1000e18`); opening `P0 = 1000 NET/DETF = 1000e18`; duration multiplier `M = 1.10e18`; seigniorage `p = 0.10e18`; WAD=1e18.

```
Q(x) = floor(1000e18 * 1e9 / 1000e18) = floor(1e9) = 1e9 = 1 raw DETF
G   = Q(A) = 1 raw DETF
U   = Q(floor(1000e18 * 1.10e18 / 1e18)) = Q(floor(1100e18)) = floor(1100e18 * 1e9 / 1000e18) = 1.1e9 = 1 raw DETF (after floor)
B   = floor(1.1e9 * (1e18 - 0.10e18) / 1e18) = floor(0.99e9) = 990e6 raw DETF
R   = floor(1.1e9 * 0.10e18 / 1e18) + floor(1e9 * 0.10e18 / 1e18) = 110e6 + 100e6 = 110e6 raw DETF (plus dust)
total = G + B + R = 1 + 990 + 110 = 1101 raw DETF
```

Expansion-eligible test (8h later, mid = 1100 pair/DETF, supply = 1101e9):
```
syntheticPrice = (1100e18 * 1e18 / 1101e9) / 1000e18 = (1.0001e9) / 1e21 = 1.0001
```
**Just above 1.0** → eligible. With default 10%/yr rate and 1 epoch passed:
```
perEpoch_ = mulDiv(mulDiv(1101e9, 0.0001e18, 1.0001e18), 9.13e-5, 1e18)
         ≈ 1101e9 * 1e-13 * 9.13e-5 ≈ 1.006e-5 raw DETF minted
```
Trivial dust; **no mint** under `DEFAULT_DUST = 1`. Higher premium (mid = 1500 pair/DETF) gives synthetic = 1.5, premium = 0.333; perEpoch ≈ 1101e9 * 0.222 * 9.13e-5 ≈ 2.23e7 raw DETF minted → not dust.

## What requires owner economic choice (not engineering)

**Three owner clarifications:**
1. **0.5%/epoch** — confirm basis (per `totalDetfSupply`), gate (default `mintThreshold` predicate or override to `ONE` for strict-above-1), and reward destination (default R43 sNET-DETF custody).
2. **`creationPairPerDetfWad` / `openingPairPerDetfWad`** for NET pair and any other configured pair (matrix rows 02–03 inputs are `UNKNOWN`).
3. **`mintThreshold`** — keep default `1.05e18` or set to `1.0e18` for the user's strict-above-1 preference (no source change required).

## Uncertainties / known engineering gates

- Live Robinhood implementation not verified; references are local Crane pin.
- `MarketMathCore.addLiquidity` optimal-split internals not traced.
- NetNet V2 SE selector inventory still UNKNOWN.
- Rollover atomic-vs-staged execution engine remains engineering.
- External-note liveness design still engineering.
- Whether user's `openingPrice = 1000 NET/DETF` is **bootstrap-only** or **ongoing peg** (PRD §10.4 last paragraph notes "remains a proposal, not a selected numeric parameter") is OPEN from prior rounds.

## Saved
- `docs/strategies/ohm-style/netnet-pendle/reviews/EXPANSION_R6_MINIMAX_ORIGINAL.md`
- Originals unchanged. No shell/tests/delegation. No peer artifacts read.
