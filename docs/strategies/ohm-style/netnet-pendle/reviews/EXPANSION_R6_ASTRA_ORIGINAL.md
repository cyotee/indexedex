# Astra — EXPANSION_R6 original first pass

**Bottom line:** Universal V4 uses **annualized, premium-dependent supply expansion**, not a flat 0.5% mint per epoch. The new selected custom gate (>1 NET/DETF), opening (1000 NET/DETF) and processed-NET-epoch clock do not automatically select its amount formula.

## Exact current calculation

Let `W=1e18`, `S` = actual outstanding DETF in native nine-decimal units, `P` = highest normalized synthetic price, `T` = resolved mint threshold, `r` = WAD annual closure rate, `n` = completed unsettled eight-hour epochs. The library computes, in this order:

```text
n = floor((now - lastTimestamp) / 28800)
c = floor(r * 28800 / 31536000)
b = floor(S * (P-W) / P)
e = floor(b * c / W)
mint = e * n
```

Eligibility requires live reserve, positive supply, completed time, **P > W AND P > T**. Equality fails. Aggregate mint <=1 raw unit becomes zero. Default `r=0.10e18` (10% annual closure parameter), selected when its argument is zero; this is not a 10% guaranteed supply APR. Threshold zero resolves to `T=1.05e18`; burn default is `0.95e18`. Package arguments set these values into storage. Sources: `DETFEpochNaturalExpansionLib.sol:9–57`; `DETFThresholdPolicy.sol:16–30`; `UniswapV4DetfDFPkg.sol:246–265`.

**Hand example:** `S=1000e9`, `P=2e18`, defaults, three completed epochs: `c=91,324,200,913,242`; `b=500e9`; `e=45,662,100` raw DETF. Aggregate = `136,986,300` raw = **0.136986300 DETF**. At price 1.05 exactly, default eligibility instead produces zero.

## Price, basis and opening

`UniswapV4DetfCommon.sol:308–340` supplies current ERC20 total supply, including pool/staking custody, not circulating-only or staked-only supply; sDETF supply is not added. It evaluates every non-DETF leg with the same actual protocol-owned LP and supply, normalizing each by its **creation** rate, then takes the maximum—not average or sum.

For the Weighted adapter, `previewSynthetic` marks non-DETF inventory at marginal weighted prices, scales by owned LP / projected fee-adjusted LP supply, divides by WAD-normalized DETF supply, then divides by the creation price. Direct DETF inventory is excluded from that external mark. This is **not a finite-size executable swap quote** (`UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget.sol:89–139`).

Opening price separately sizes the empty-book bond (`Common:258–289`). A 1000 opening versus a 1 creation reference can affect seeded balances, but does **not automatically establish P=1000**: issued supply, rewards, weights, ownership and creation normalization all matter. A NET-denominated market peg check is therefore not identical to Universal's highest normalized synthetic gate.

## Clock, triggers and funding

First successful bond anchors `lastExpansionTimestamp` (`UniswapV4DetfTarget.sol:581–599`). Universal observes wall-clock eight-hour boundaries, not Net staking's counter. Catch-up uses **one current S/P snapshot**, floors per epoch then multiplies by n: no historical price replay, hypothetical fee-receipt compounding or catch-up cap. Zero/ineligible/dust outcomes still advance all completed boundaries; partial time remains. Subsequent separately executed settlements naturally use changed actual supply.

Mint/burn, bond and composed staking paths trigger settlement (`Target:275,347,367,418,433,545`). `synchronizeRewards()` also settles when unlocked; locked callbacks are restricted to wired children (`UniswapV4DetfMaintenanceTarget.sol:16–27`). Staking transfers/exchanges and NFT claims/transfers synchronize through it.

Positive expansion mints DETF then transfers it into staking via `fundRewards` (`Common:343–379`). `StakedDETFTarget.sol:170–183` resolves fee/creator role-NFT owners; `DETFFundedStakingRepo.sol:185–201` allocates funded growth, rebases existing stake, then issues fee/creator receipts. No reserve-LP join or recursive seigniorage pot is created.

## Reuse recommendation and evidence limits

Reuse arithmetic/funding separation only after explicitly replacing the gate and clock with the selected custom rules. Discuss **premium-dependent closure versus flat supply-rate expansion**; do not translate 0.5% into the annual field without defining its meaning and catch-up basis.

Tests inspected, not run: `test/foundry/spec/vaults/detf/common/core/DETFEpochNaturalExpansionLib.t.sol:19–146` and `.../uniswap/v4/detf/UniswapV4Detf_HighestPriceExpansion.t.sol:63–108`. Alignment PRD `:977–1005` corroborates behavior. Custom PRD v0.15 §9 and matrix rows35–37 still leave amount mechanics open.

Paths abbreviated above belong to `contracts/vaults/detf/common/core/`, `.../protocols/dexes/uniswap/v4/detf/`, `.../common/claimToken/` and `contracts/hooks/uniswap/v4/standardExchange/weighted/`. Solidity `^0.8.0`, unpinned local snapshot; no deployed configuration certification. An initial lookup used nonexistent `StakedDETFRepo.sol`; the actual imported `DETFFundedStakingRepo.sol` was then inspected. No guard denial. Metadata: Astra, supplied `openai/gpt-6-astra`, not provider attestation.
