# Pendle V2 protocol research

- Created: 2026-09-14
- Status: Protocol mechanics research for a future IndexedEx Standard Exchange package. Not product law. No locked `PkgArgs`, vault identity, or implementation plan.
- Package path: `contracts/vaults/standard/exchange/protocols/pendle/`
- Crane source: `lib/crane/contracts/protocols/perps/pendle/` (vendored Pendle V2 core, ~434 Solidity files)
- Official docs snapshot: [docs.pendle.finance](https://docs.pendle.finance/) and [llms-full.txt](https://docs.pendle.finance/llms-full.txt) (generated 2026-09-02)

This note explains how Pendle V2 works from the public documentation and from the Crane-vendored contracts. It is research, not a PRD. Observations of live markets, fee splits, and factory versions are dated. Re-read the deployment state and current docs before implementing or executing.

Pendle V2 is a yield-tokenization and yield-trading protocol. It is not a money market, not an ERC-4626 vault factory, and not Boros (Pendle's separate perpetual-yield product). The Crane tree lives under `protocols/perps/` because Crane promoted the vendored core out of `contracts/external/pendle/` during a categorization pass (Euler's PT/LP oracle adapters consume Pendle interfaces). That path name does not mean this tree is Boros.

Sibling context: the Morpho Blue Standard Exchange PRD at `../morpho/blue/MorphoBlueStandardExchange_PRD.md`. NET-specific Pendle market notes live in [`docs/detf/NET_MORPHO_PENDLE_STRATEGY_RESEARCH.md`](../../../../../../docs/detf/NET_MORPHO_PENDLE_STRATEGY_RESEARCH.md). Those files discuss compositions. This file describes the protocol itself.

---

## 1. What Pendle does

Yield on a lending market, LST, LRT, or similar source moves over time. Pendle splits a yield-bearing token into two ERC-20 claims with a shared expiry, then lets those claims trade.

1. Wrap the yield-bearing token into a Standardized Yield token (SY).
2. Split SY into a Principal Token (PT) and a Yield Token (YT) for one maturity.
3. Trade PT against SY in a dedicated AMM. YT trades through the same pool via flash mint/redeem.

Official product analogy: bond stripping. PT is the zero-coupon principal. YT is the detached coupon stream until expiry. Source: [Introduction](https://docs.pendle.finance/pendle-v2/Introduction), [Using Pendle](https://docs.pendle.finance/pendle-v2/AppGuide/UsingPendle).

On-chain market creation is permissionless. The official UI curates which markets it shows. Community listing is a separate portal ([listing.pendle.finance](https://listing.pendle.finance)).

A user who buys PT at a discount to the accounting asset and holds to expiry locks the implied APY as a fixed yield, provided the SY still redeems that accounting asset. A user who buys YT pays that discount up front and receives all interest, extra reward tokens, and (where applicable) off-chain points until expiry. Liquidity providers hold PT + SY and earn swap fees, SY yield, the PT discount, and PENDLE gauge emissions.

---

## 2. Units: accounting asset, SY, PT, YT

Pendle prices principal in an accounting asset, not in the yield-bearing token itself.

| Term | Meaning |
|---|---|
| Yield-bearing token / ibToken | The source token: wstETH, aUSDC, sUSDe, GLP, a Balancer LP staked in Aura, and so on |
| Accounting asset | The unit the ibToken is denominated in. Shown in brackets in market names. Example: PT-wstETH (stETH), PT-ezETH (ETH) |
| SY | ERC-20 wrapper that exposes one deposit/redeem/exchange-rate/rewards interface for every ibToken |
| PT | ERC-20 claim on 1 unit of accounting asset at expiry |
| YT | ERC-20 claim on the yield of 1 unit of accounting asset until expiry |
| PY index | Non-decreasing copy of `SY.exchangeRate()`, used to mint and redeem PT/YT |
| Market / LP | PT/SY AMM share token (`PENDLE-LPT`) |

`1 PT` redeems to enough SY that the SY unwraps to 1 accounting asset, not to 1 ibToken. Official example: if `1 wstETH = 1.2 stETH` on 1 Jan 2024, `1 PT-wstETH-01JAN2024` redeems to `1/1.2 ≈ 0.833` wstETH at that exchange rate, which is 1 stETH of value. Source: [High Level Architecture](https://docs.pendle.finance/pendle-v2-dev/HighLevelArchitecture).

Minting is also in accounting-asset units:

```
PY minted = SY deposited × current PY index
```

If `1 SY-sUSDe = 1.2 USDe` and a user deposits `100 SY-sUSDe`, the YT contract mints `120 PT` and `120 YT`. Source: [Yield Tokenization contracts](https://docs.pendle.finance/pendle-v2-dev/Contracts/YieldTokenization). Crane matches this in `PendleYieldToken._calcPYToMint` via `SYUtils.syToAsset`.

The no-arbitrage identity used for YT flash swaps:

```
P(PT) + P(YT) = P(accounting asset)
```

That identity holds because 1 accounting asset of SY mints 1 PT + 1 YT, and 1 PT + 1 YT (pre-expiry) redeem that same accounting-asset amount of SY. It is not `1 SY = 1 PT + 1 YT` except when the PY index is 1.

---

## 3. Standardized Yield (SY)

SY is the adapter layer. Every Pendle operation that holds inventory (mint PT/YT, AMM reserves, YT interest) holds SY, not the raw ibToken.

Interface: `IStandardizedYield` in Crane at `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol`. Base implementation: `core/StandardizedYield/SYBase.sol`.

Required surface:

| Function | Role |
|---|---|
| `deposit(receiver, tokenIn, amount, minSharesOut)` | Pull a listed input token, mint SY |
| `redeem(receiver, shares, tokenOut, minTokenOut, burnFromInternalBalance)` | Burn SY, pay a listed output token |
| `exchangeRate()` | `asset = sy × exchangeRate / 1e18` |
| `assetInfo()` | `(AssetType, assetAddress, assetDecimals)` for the accounting asset |
| `getTokensIn` / `getTokensOut` | Allowed wrap/unwrap tokens |
| `yieldToken()` | The wrapped ibToken |
| `claimRewards` / `getRewardTokens` / `accruedRewards` | Extra reward tokens that do not compound into `exchangeRate` |

`SYUtils` (`core/StandardizedYield/SYUtils.sol`) is the conversion library:

```
syToAsset(rate, sy)   = sy × rate / 1e18
assetToSy(rate, asset) = asset × 1e18 / rate
```

Ceil variants exist (`syToAssetUp`, `assetToSyUp`) and are used on the "protocol takes" side of swaps and redemptions.

### 3.1 How yield shows up in SY

Two forms, named in the architecture docs:

- Interest (compounding): the ibToken appreciates against the accounting asset. `exchangeRate` rises. wstETH vs stETH, sDAI vs DAI, ERC-4626 `totalAssets/totalSupply`.
- Rewards (non-compounding): a different token is paid out. GLP paying ETH. Aura/BAL on a staked Balancer LP. These flow through `claimRewards`.

Rebasing ibTokens (Aave aTokens, stETH in some setups) are wrapped so that SY itself does not rebase. `PendleAaveV3SY` deposits into the Aave pool and treats Aave scaled shares as SY shares. `exchangeRate()` returns Aave `normalizedIncome / 1e9`, so SY stays a non-rebasing ERC-20 while still tracking aUSDC interest.

ERC-4626 vaults use `PendleERC4626SY`: SY shares are 1:1 with the 4626 vault token, `exchangeRate()` is `totalAssets / totalSupply`, and `deposit`/`redeem` can take either the 4626 asset or the vault token.

Generic 1:1 wrappers (`PendleERC20SY`, `PendleWstEthSY`, Ethena `PendleSUSDESY`, ether.fi `PendleWEEthSY`, and many LST/LRT adapters) live under `core/StandardizedYield/implementations/`. That directory is a catalog of adapters, not a live list of markets.

### 3.2 SY properties that matter for integrators

- SY has no expiry. PT and YT do. One SY can back many (PT, YT, market) triples, one per expiry.
- Newer SYs are upgradeable proxies. Markets are immutable once deployed.
- Wrapping is usually 1 SY = 1 ibToken, but not always (docs call out mPendle and aUSDC-style exceptions). Always read `exchangeRate()` and `assetInfo()`.
- `burnFromInternalBalance` lets the router burn SY that already sits on the SY contract, which is how flash paths avoid an extra transfer.

Official SY page: [StandardizedYield](https://docs.pendle.finance/pendle-v2-dev/Contracts/StandardizedYield).

---

## 4. Yield contracts: PT, YT, PY index

Factory: `PendleYieldContractFactory`. Anyone may call `createYieldContract(SY, expiry, doCacheIndexSameBlock)` if `expiry` is in the future and `expiry % expiryDivisor == 0`. Expiry is `uint32` (year 2106 max). PT decimals equal `assetInfo().assetDecimals`, not SY decimals.

PT (`PendlePrincipalToken`) is a thin ERC-20. Only the paired YT may `mintByYT` / `burnByYT`. PT stores `SY`, `YT`, `factory`, and `expiry`.

YT (`PendleYieldToken`) is the accounting contract. It holds the SY reserve, mints and burns PT, accrues interest to YT holders, and forwards SY reward tokens.

### 4.1 Mint and redeem

Callers must transfer tokens into the YT contract, then call. The router does this; raw integrations must too.

| Call | Pre-expiry | Post-expiry |
|---|---|---|
| `mintPY(receiverPT, receiverYT)` | Burns floating SY, mints equal PT and YT | Reverts `YCExpired` |
| `redeemPY(receiver)` | Burns equal PT and YT from the YT contract, pays SY | Burns PT only, pays SY |
| `redeemDueInterestAndRewards(user, interest, rewards)` | Pays accrued SY interest and reward tokens | Pays leftover pre-expiry accruals only |

Redeem of PT/YT does not include accrued YT interest. Interest is a separate claim. That is explicit in the NatSpec on `redeemPY`.

Crane mint:

```
amountPY = SYUtils.syToAsset(index, amountSy)
```

Crane redeem:

```
syToUser = SYUtils.assetToSy(index, amountPY)
```

After expiry, if the live index has moved above the snapshotted `firstPYIndex`, the extra SY is `syInterestPostExpiry` and is credited to the treasury, not the redeemer.

### 4.2 PY index (watermark)

`PendleYieldToken._pyIndexCurrent()`:

```
index = max(SY.exchangeRate(), _pyIndexStored)
```

The index never falls. If `doCacheIndexSameBlock` is true, it updates at most once per block.

If the underlying exchange rate drops (negative yield, depeg, bad debt in the source protocol):

- New YT interest stops until `SY.exchangeRate()` recovers above the stored index.
- Pre-expiry PT+YT redeem still uses the (higher) stored index, so the user receives fewer SY per PY.
- At maturity, PT still claims `assetToSy(index, amountPT)` SY. If each SY is now worth less accounting asset, the PT holder receives less than 1 accounting asset.

Pendle documents this as Negative Yield / watermark rate. The highest recorded IBT-to-asset rate is the watermark. Below it, PT redeems short and YT stops earning. Source: glossary "Watermark Rate" in [llms-full.txt](https://docs.pendle.finance/llms-full.txt) and the [Yield Tokenization](https://docs.pendle.finance/pendle-v2-dev/Contracts/YieldTokenization) `pyIndexCurrent` notes.

### 4.3 YT interest math

`InterestManagerYT._distributeInterestPrivate`:

```
interestFromYT = YT_balance × (currentIndex − prevIndex) / (prevIndex × currentIndex)
```

That is the SY amount corresponding to the index jump on this user's YT. Accrual is stored, then `redeemDueInterestAndRewards` applies `interestFeeRate` (factory, max 20e16 = 20%) and sends the fee to the factory treasury. Docs state the live protocol fee on YT yield is 5%. Confirm the factory's current `interestFeeRate` on the target chain before quoting.

Rewards use a separate share that must be updated before interest is paid out. The comment in both YT and `InterestManagerYT` is the reason: reward shares are a function of the SY the YT still represents plus unclaimed interest. Paying interest first would change the share.

Post-expiry, `setPostExpiryData` (also triggered by the `updateData` modifier on the first post-expiry call) snapshots `firstPYIndex` and remaining reward indexes. All later SY interest and rewards on unredeemed principal go to the treasury.

YT of one (SY, expiry) is fully fungible. The contract cannot tell minted YT from swapped YT from LP-derived YT.

---

## 5. AMM: PT/SY market

Each market is one PT against its SY. There is no YT reserve. Contract: `PendleMarketV3`, math: `MarketMathCore`. LP token name/symbol: `Pendle Market` / `PENDLE-LPT`, 18 decimals.

Factory: `PendleMarketFactoryV3.createNewMarket(PT, scalarRoot, initialAnchor, lnFeeRateRoot)`. Anyone may create a market. Duplicate `(PT, scalarRoot, initialAnchor, lnFeeRateRoot)` reverts. `lnFeeRateRoot` is capped at `ln(1.05)`. `scalarRoot` must be > 0. Markets are immutable. If implied APY trades outside the configured band, a new market must be deployed and LPs must migrate.

### 5.1 Curve (Notional AMM)

Pendle V2 adapted Notional Finance's logit curve. Whitepaper: [V2_AMM.pdf](https://github.com/pendle-finance/pendle-v2-resources/tree/main/whitepapers). On-chain form in `MarketMathCore._getExchangeRate`:

```
proportion   = (totalPt − netPtToAccount) / (totalPt + totalAsset)
logit        = ln(proportion / (1 − proportion))
exchangeRate = logit / rateScalar + rateAnchor
```

`totalAsset = PYIndex.syToAsset(totalSy)`, so the curve is in accounting-asset units, not raw SY.

Time dependence, matching Crane:

```
rateScalar(t) = scalarRoot × 365 days / timeToExpiry
feeRate(t)    = exp(lnFeeRateRoot × timeToExpiry / 365 days)
impliedRate   from lastLnImpliedRate, with E = exp(lnImpliedRate × timeToExpiry / 365 days)
```

`rateAnchor` is recomputed before each trade so that, with no trade, implied rate does not drift as time passes. After the trade, `lastLnImpliedRate` is rewritten from the new reserves.

`scalarRoot` sets how tight the implied-APY band is. Higher scalar, narrower band, less slippage inside the band, thinner liquidity outside it. `initialAnchor` centers the first implied rate.

Hard limits in `MarketMathCore`:

- `MAX_MARKET_PROPORTION = 96/100`. PT cannot be more than 96% of `(totalPt + totalAsset)`. Trades that would push past this revert `MarketProportionTooHigh`.
- Exchange rate cannot fall below 1 (`MarketExchangeRateBelowOne`). PT never trades above 1 accounting asset on this curve.
- First mint locks `MINIMUM_LIQUIDITY = 10^3` LP to `address(1)`.

As expiry approaches, `rateScalar` rises and the tradeable PT price range collapses toward 1. That is the "dynamic curve tightening" in the [AMM docs](https://docs.pendle.finance/pendle-v2/ProtocolMechanics/LiquidityEngines/AMM). At expiry the market stops swapping (`notExpired` / `MarketExpired`). LP `burn` still works and returns residual PT and SY.

### 5.2 Swap surface on the market

The market itself only swaps PT against SY:

- `swapExactPtForSy(receiver, exactPtIn, data)`
- `swapSyForExactPt(receiver, exactPtOut, data)`

Both send a protocol slice of SY to `market.treasury`. If `data.length > 0`, they callback `IPMarketSwapCallback.swapCallback` on `msg.sender` before checking that the PT/SY balances cover the new reserves. That callback is how the router implements exact-SY-in, YT flash swaps, and PT/YT conversion.

Add/remove liquidity is proportional in PT and SY, Uniswap-V2 style (`addLiquidityCore` / `removeLiquidityCore`). First mint uses `sqrt(sy × pt) − MINIMUM_LIQUIDITY`.

### 5.3 Fees on swaps

Swap fee is a yield fee, not a principal fee. Crane: `feeRate = exp(lnFeeRateRoot × timeToExpiry / 365 days)`, then a slice of the asset delta is fee. `reserveFeePercent` (base 100, factory-set, max 100) of that fee goes to treasury SY; the rest stays in the pool for LPs.

Docs formula for the displayed trading fee:

```
Trading Fee = (Fee Tier / 365) × Days to Maturity
```

Same size trade costs more with a year to expiry than with a month to expiry. Redeeming PT after maturity has no protocol swap fee.

Docs fee split as of the 2026-09-02 dump: 20% of swap fees stay with LPs. Remaining swap fees plus all YT fees: 80% PENDLE buyback, 10% protocol treasury, 10% operations. YT yield fee (including points, which partners deduct off-chain) is stated as 5%. Confirm live factory `interestFeeRate`, `rewardFeeRate`, and `reserveFeePercent` per chain.

### 5.4 Implied APY

Market-consensus yield from PT and YT prices ([glossary](https://docs.pendle.finance/pendle-v2/ProtocolMechanics/Glossary)):

```
Implied APY = (1 + YT_price / PT_price) ^ (365 / days_to_expiry) − 1
```

Fixed APY for a PT buyer is the same number. Underlying APY in the app is a 7-day moving average of the source yield. Long-yield APY is the annualized YT return if underlying APY stays at that average; it can be negative when YT is expensive relative to expected remaining yield.

---

## 6. YT flash swaps (pseudo-AMM)

YT is not in the pool. The router uses the identity `PT + YT = asset` and the market's PT/SY swap plus YT `mintPY` / `redeemPY`.

Buy YT (`ActionSwapYTV3.swapExactSyForYt` → `ActionCallbackV3._callbackSwapExactSyForYt`):

1. User SY (or a token routed into SY) sits on YT.
2. Market flash-sends SY out (equivalently: router pulls extra SY from the pool by taking PT from the pool).
3. Callback mints PT + YT from all SY on the YT contract.
4. YT goes to the buyer.
5. PT is paid back to the market to settle the flash.

Sell YT (`swapExactYtForSy`):

1. User YT is on the YT contract.
2. Market flash-sends PT to the YT contract.
3. Callback `redeemPY` burns PT+YT for SY.
4. Enough SY is sold back to the market to return the PT.
5. Remainder SY goes to the seller.

PT↔YT swaps are the same machinery with different receivers (`swapExactPtForYt`, `swapExactYtForPt`). Exact-in SY/token routes that the market does not natively support are solved with `ApproxParams` binary search in `MarketApproxLib` (guess PT in/out). The hosted SDK narrows the guess off-chain to save gas.

---

## 7. Router

`PendleRouterV4` is an EIP-2535-style selector proxy (`PendleRouterV4` + `RouterStorage` + action contracts). It has no special rights on SY, PT, YT, or markets. Official docs still recommend it: markets can override `lnFeeRateRoot` down for the router, and the router is how limit orders and token aggregators attach.

Action contracts in Crane:

| File | Work |
|---|---|
| `ActionSwapPTV3.sol` | Token/SY ↔ PT |
| `ActionSwapYTV3.sol` | Token/SY ↔ YT, PT ↔ YT |
| `ActionAddRemoveLiqV3.sol` | Single-token and dual-sided LP |
| `ActionCallbackV3.sol` | Market and limit-order callbacks |
| `ActionMiscV3.sol` | Mint/redeem PY from tokens, claim interest/rewards |
| `ActionStorageV4.sol` | Selector → facet map |
| `swap-aggregator/PendleSwap.sol` | KyberSwap / 1inch hop before SY deposit |

`TokenInput` can be a no-op (token already mintable into SY), ETH wrapping, or an aggregator swap. Exact-token-in PT/YT therefore depends on off-chain routing data for the aggregator and for `ApproxParams`.

RouterV4 address on the documented deployments: `0x888888888889758F76e7103c6CbF23ABbF58F946` (Apr 29, 2024). Older V1–V3 addresses remain in the [Router overview](https://docs.pendle.finance/pendle-v2-dev/Contracts/PendleRouter/PendleRouterOverview). Use V4. Block explorers show only the proxy ABI; the callable surface is `IPAllActionV3`.

`PendleRouterStatic` is an off-chain helper diamond. Docs: not audited, do not use on-chain with funds.

---

## 8. Limit orders

Off-chain order book, on-chain settlement (`PendleLimitRouter`). Makers sign (EOA) or `preSign` (contracts). Takers fill through the router, which can mix book liquidity with AMM liquidity.

Order types in the docs: `SY_FOR_PT`, `PT_FOR_SY`, `SY_FOR_YT`, `YT_FOR_SY`. Flash mint/redeem means a buy-YT taker can fill a sell-PT maker and the reverse.

Settlement uses the same YT callback pattern as AMM flash swaps (`ActionCallbackV3.limitRouterCallback`). Cancels set remaining amount to a filled sentinel.

Limit orders exist only off-chain until fill. Pure on-chain integrations that skip the hosted SDK do not see that liquidity.

---

## 9. Oracles

Each `PendleMarketV3` stores a Uniswap-V3-style observation ring (`OracleLib.Observation[65535]`) of `lnImpliedRateCumulative`. `PendlePYLpOracle` (and the `PendlePYOracleLib` / `PendleLpOracleLib` libraries) turn a TWAP duration into:

- PT, YT, LP → SY
- PT, YT, LP → accounting asset

Docs prefer `getPtToSy` / `getLpToSy` when the consumer can work in SY, because that rate is native to the AMM. `getPtToAsset` also depends on `SY.exchangeRate()` and on whether SY can actually withdraw the asset.

Cardinality must be grown before a TWAP of length `duration` is safe. `PendlePYLpOracle` exposes a cardinality check. `blockCycleNumerator` converts duration to a required cardinality from a conservative seconds-per-block assumption (Ethereum example in code: 11000/1000 = 11s vs ~12s blocks).

PT and LP are used as Morpho / Euler / Silo collateral via these oracles. That is a consumer of Pendle, not part of Pendle's own risk engine.

---

## 10. vePENDLE, gauges, incentives

PENDLE locks into vePENDLE on the mainchain voting escrow.

Crane constants (`VotingEscrowTokenBase`):

- `WEEK = 1 weeks`
- `MIN_LOCK_TIME = 1 weeks`
- `MAX_LOCK_TIME = 104 weeks`

Balance is a linear decay (`VeBalanceLib`: slope = amount / MAX_LOCK_TIME). Expiry must be a week start (`WeekMath`). Mainchain broadcasts lock state to sidechains over Pendle's LayerZero message endpoints (`PendleMsgSendEndpointUpg` / `PendleMsgReceiveEndpointUpg`). Sidechain vePENDLE is a replica; it does not accept independent locks.

`PendleVotingControllerUpg` lets vePENDLE vote markets. Votes become next-week PENDLE emissions via `PendleGaugeController*`. Each `PendleMarketV3` is a `PendleGauge`.

Gauge boost (Curve-style, `TOKENLESS_PRODUCTION = 40`):

```
activeBalance = min(lpBalance,
                    0.40 × lpBalance + 0.60 × totalLp × ve_user / ve_supply)
```

LP without vePENDLE earns 40% of the per-token emission rate. Full boost needs vePENDLE proportional to the user's share of LP.

Gauges also `SY.claimRewards` so LP holders receive the underlying's extra reward tokens.

Fee distributors (`PendleFeeDistributor`, `PendleFeeDistributorV2`) pay protocol revenue to vePENDLE by week. Merkle distributor handles partner/campaign rewards.

Dynamic Incentive Controller (DIC) is a later campaign primitive: TVL-dependent PT and YT reward curves with a ratchet, funded cap, and Merkle payout. Described in the 2026-09-02 docs dump. It is not a separate contract in this Crane tree snapshot.

---

## 11. LP economics and "Keep YT"

A PT/SY LP earns:

1. Underlying yield on the SY leg
2. The PT discount as PT converges to 1 accounting asset
3. Swap fees from both PT and YT flow
4. PENDLE (and other) gauge rewards

Impermanent loss vs holding the accounting asset is mostly implied-APY movement, not spot-price movement of ETH/USDC, because both legs are claims on the same asset. If the LP is held to expiry, PT redeems to the asset and IL from time decay is designed to go to zero. IL from implied-APY leaving the configured band is still real, and in-range trading can halt (`MarketProportionTooHigh` / thin liquidity).

Zapping in: by default the router buys some PT from the pool and wraps the rest as SY, which moves implied APY. "Keep YT mode" mints PT+YT from SY instead, LPs the PT+remaining SY, and leaves YT with the user. That avoids buying PT from the pool and leaves the user long yield on the minted YT.

Matured LP: burn LP, redeem PT, unwrap SY, claim rewards. The app zaps that into one transaction.

---

## 12. Factory versions and Permit removal

From the architecture docs:

| Version | Notes |
|---|---|
| Pre-V3 | Early factories |
| V3 | Late 2023. Crane's `PendleMarketFactoryV3` / `PendleMarketV3` match this generation |
| V4/V5 | Mid-2024. New PT, YT, and LP tokens drop EIP-2612 `permit()` (phishing) |
| V6 | Late 2025. Current recommended factory for new markets |

This Crane tree is the V2 core with Market V3. Newer factory/token variants may exist upstream of this pin. Do not assume `permit()` on a live PT/YT/LP; check the token bytecode.

Cross-chain PTs (LayerZero OFT) let a mainnet PT be used as collateral on a chain without a full Pendle deployment. Liquidation is designed to bring the asset back from mainnet rather than rely on destination DEX liquidity. That path is not in the Crane tree's core market code.

---

## 13. User strategies (product, not vault design)

Official [Using Pendle](https://docs.pendle.finance/pendle-v2/AppGuide/UsingPendle) list:

| Action | Economic meaning |
|---|---|
| Buy PT | Lock implied APY. Short the variable yield. PT is a discount bond on the accounting asset |
| Buy YT | Long variable yield and points until expiry. YT price trends toward 0 as time passes if implied APY is unchanged. Profit if realized underlying APY beats the implied APY paid |
| Mint PT+YT and sell one side | Same as buying the other side, plus mint gas vs swap price |
| LP PT+SY | Earn fees + incentives + mixed fixed/variable yield, implied-APY inventory risk |
| Hold to expiry then redeem | PT → SY → ibToken/asset. Unredeemed post-expiry yield is redirected to treasury |

YT is often used to farm points because 1 YT receives the points of 1 accounting asset while costing a fraction of that asset. Points fees are deducted off-chain by the partner into Pendle fee wallets.

Discrete-yield markets (docs: STRCx is the first) replace continuous index accrual with time-weighted merkle claims: earn for time held, must still hold at payout, never earn more than the position generated. Forfeited yield goes to treasury, not to remaining holders. That is a product-level exception to the continuous YT index in `InterestManagerYT`.

---

## 14. Crane port map

Root: `lib/crane/contracts/protocols/perps/pendle/`.

Upstream: [pendle-core-v2-public](https://github.com/pendle-finance/pendle-core-v2-public), npm `@pendle/core-v2`. License on core files: GPL-3.0-or-later (some interface headers also carry MIT text). Whitepapers: [pendle-v2-resources/whitepapers](https://github.com/pendle-finance/pendle-v2-resources/tree/main/whitepapers). SY-only repo (newer adapters): [Pendle-SY-Public](https://github.com/pendle-finance/Pendle-SY-Public).

Crane inventory (`docs/roadmap/PUBLIC_RELEASE_INVENTORY.md`): vendored, KEEP, ~434 files. Promotion history: `contracts/external/pendle/` → `contracts/protocols/perps/pendle/` (commit notes in `docs/archive/internal-plans/DEDUPLICATION.md`). Euler v1 oracle adapters import Pendle interfaces from this tree.

There is no Crane `PendleService` / `PendleAwareRepo` / `TestBase_Pendle` in the Morpho/Aave sense. IndexedEx product code should treat this tree as upstream-faithful protocol source, not as an existing FactoryService.

Layout:

```
perps/pendle/
  core/
    StandardizedYield/     SYBase, SYUtils, PYIndex, implementations/*
    YieldContracts/        PT, YT, factory, InterestManagerYT
    Market/                MarketMathCore, OracleLib, PendleGauge
      v1/                  PendleMarket, PendleMarketFactory
      v3/                  PendleMarketV3, PendleMarketFactoryV3
    RewardManager/
    erc20/                 PendleERC20 / Permit / upgradeable variants
    libraries/             PMath, LogExpMath, Errors, TokenHelper, ...
  router/                  RouterV4 + action facets + aggregators
  limit/                   PendleLimitRouter, LimitMathCore
  LiquidityMining/         vePENDLE, voting, gauges, fee distributors, LZ messaging
  oracles/                 PendlePYLpOracle + libs
  offchain-helpers/        RouterStatic, multicall, governance proxy, deploy helper
  interfaces/              IP* protocol + third-party adapter interfaces
```

Import remaps in the port use `@crane/contracts/external/openzeppelin-contracts/...` (and upgradeable) rather than Pendle's original OZ paths. That is the Crane vendor rule. Behavior of mint, redeem, market math, and gauges should be compared to upstream at the pin, not rewritten.

SY implementations in this pin include Aave V3, ERC-4626, wstETH, sfrxETH, Ethena sUSDe/USDe, ether.fi weETH, Renzo ezETH, Kelp rsETH, Swell, Stader ETHx, Silo, Karak, Mellow, Convex/Curve LPs, Aura/Balancer LPs, GLP/HLP, and others. Many are historical. A live market may use a newer SY from Pendle-SY-Public that is not in this tree.

`RouterStatic` and `SDKErrorsDirectory` are off-chain helpers. Do not send user funds through them.

---

## 15. Deployments and integration entry points

Core addresses by chain: `deployments/{chainId}-core.json` in the core repo. Chains listed in the 2026-09 docs: Ethereum (1), Optimism (10), BNB (56), Sonic (146), HyperEVM (999), Mantle (5000), Base (8453), Arbitrum (42161), Berachain (80094), Monad (143), Katana (747474), Ink (57073).

Market/SY/PT/YT addresses: Pendle app market page, or `GET https://api-v2.pendle.finance/core/v2/markets/all`.

On-chain integration docs recommend:

1. Hosted SDK for calldata (approx guesses, Kyber route, limit orders).
2. RouterV4 with `IPAllActionV3` if staying on-chain.
3. Direct YT/market calls only when embedding the flash logic (the router has no whitelist, so this is allowed).

Developer channels named in the docs: Telegram `t.me/pendledevelopers`, Discord developer channel.

---

## 16. Notes for a future IndexedEx Standard Exchange

These are research implications, not decisions.

Pendle exposes several distinct positions, each with a different NAV story:

| Position | What the holder has | Share-price behavior | Exit |
|---|---|---|---|
| SY | Wrapped ibToken | Follows `exchangeRate` (interest) plus claimable extra rewards | `SY.redeem` to a `tokenOut` |
| PT | Discounted claim on 1 accounting asset at one expiry | Pulls toward 1 asset as time passes; market price can trade | Sell PT on the market, or redeem after expiry (or with YT before) |
| YT | Yield + rewards + points until expiry | Decays toward 0; separate `redeemDueInterestAndRewards` | Sell YT, or hold and claim; worthless as a principal claim after expiry |
| LP | PT + SY inventory | Mix of SY yield, PT pull-to-par, fees, emissions | `market.burn`, then optional PT redeem |

A Morpho Blue SE supplies one loan token and reports rising `totalAssets` from Morpho interest. A Pendle SE has to pick which of the four positions it is. They are not interchangeable:

- SY is the closest ERC-4626 analogue (especially `PendleERC4626SY`), but rewards may sit in `claimRewards` rather than in share price, and some SYs accept multiple `tokenIn`.
- PT is a fixed-yield instrument. Share price vs the accounting asset should rise toward 1 if marked to implied APY or held to expiry. Marking to SY (`getPtToSy`) is the AMM-native rate. Liquidity to sell before expiry is the PT/SY pool plus the limit book, and it vanishes at expiry except for `redeemPY`.
- YT is a decaying, separately claimable cashflow. IndexedEx token policy forbids rebasing underlyings; YT interest is claimable SY, not a rebase of YT itself. An SE that held YT would still need a claim schedule and a story for expiry (YT goes to zero).
- LP is a two-token inventory with gauge `activeBalance` and vePENDLE boost. Emissions and SY extra rewards are claimable, not automatic share-price. Boost for a protocol-owned vault without vePENDLE is the 40% tokenless floor.

Maturity is first-class. A vault bound to one market dies as a trading venue at `expiry` and becomes a redemption of PT + unwrap of SY. Rollover onto the next expiry is a new market, not a parameter change.

Weird-token law (IndexedEx): FoT forbidden; rebasing underlyings forbidden; pause/blacklist accepted. Pendle's SY layer is how Pendle itself absorbs rebasing aTokens. An SE that takes user funds as `rateAsset` still has to name that asset (accounting asset vs ibToken vs SY) and reject FoT on the user-facing token.

Production-first tests would fork a live SY + PT + YT + MarketV3 and talk to those contracts. Do not mock the Pendle SUT. Crane has no Pendle TestBase today; one would need to be written against this vendored tree plus a fork of a target chain (Ethereum, Arbitrum, Base, or Robinhood if a market exists there).

Router vs embed: FactoryServices in IndexedEx read creation bytecode from `out/` and deploy via CREATE3. They would not `new` Pendle markets. They would hold or call already-deployed SY/PT/YT/Market. If the vault zaps through swaps, the hosted SDK's off-chain approx/limit path conflicts with a fully on-chain SE unless the vault only uses `swapSyForExactPt` / `swapExactPtForSy` / `mintPY` / `redeemPY`.

Oracle: if a later hook or Morpho-style consumer needs a PT or LP rate, use `PendlePYLpOracle` with a grown cardinality, and prefer SY denomination unless the product law requires the accounting asset.

D60/D66 and DETF role names do not apply until a PRD exists. If a DETF later consumes this SE, `rateAsset` is the accounting asset or the ibToken according to that PRD, not "the Pendle token."

---

## 17. What this tree is not

- Not Boros. Boros is documented under `docs.pendle.finance/boros-docs`. It is a perpetual implied-APY product. This Crane directory is Pendle V2 SY/PT/YT/Market.
- Not a complete live SY catalog. Newer SYs ship in Pendle-SY-Public.
- Not Pendle's hosted SDK, backend API, or Socket.IO feeds. Those are off-chain.
- Not an IndexedEx vault, DFPkg, or rate provider.

---

## 18. Sources

Official:

- [Introduction](https://docs.pendle.finance/pendle-v2/Introduction)
- [High Level Architecture](https://docs.pendle.finance/pendle-v2-dev/HighLevelArchitecture)
- [StandardizedYield](https://docs.pendle.finance/pendle-v2-dev/Contracts/StandardizedYield)
- [Yield Tokenization contracts](https://docs.pendle.finance/pendle-v2-dev/Contracts/YieldTokenization)
- [Pendle Market contracts](https://docs.pendle.finance/pendle-v2-dev/Contracts/PendleMarket)
- [AMM](https://docs.pendle.finance/pendle-v2/ProtocolMechanics/LiquidityEngines/AMM)
- [Order Book](https://docs.pendle.finance/pendle-v2/ProtocolMechanics/LiquidityEngines/OrderBook)
- [Router overview](https://docs.pendle.finance/pendle-v2-dev/Contracts/PendleRouter/PendleRouterOverview)
- [Oracle overview](https://docs.pendle.finance/pendle-v2-dev/Oracles/OracleOverview)
- [Limit orders](https://docs.pendle.finance/pendle-v2-dev/LimitOrder/Overview)
- [Deployments](https://docs.pendle.finance/pendle-v2-dev/Deployments)
- [PT/YT/LP cheatsheet](https://docs.pendle.finance/pendle-academy/cheatsheet-for-the-impatient/pt-yt-lp-cheatsheet)
- [Using Pendle](https://docs.pendle.finance/pendle-v2/AppGuide/UsingPendle)
- [llms-full.txt](https://docs.pendle.finance/llms-full.txt) (2026-09-02 dump; includes fees, DIC, discrete-yield, factory versions)
- Whitepapers: [pendle-v2-resources/whitepapers](https://github.com/pendle-finance/pendle-v2-resources/tree/main/whitepapers) (`V2_AMM.pdf`)
- Core repo: [pendle-core-v2-public](https://github.com/pendle-finance/pendle-core-v2-public)

Crane (paths relative to `lib/crane/contracts/protocols/perps/pendle/`):

- `interfaces/IStandardizedYield.sol`
- `core/StandardizedYield/SYBase.sol`, `SYUtils.sol`, `PYIndex.sol`
- `core/StandardizedYield/implementations/PendleERC4626SY.sol`
- `core/StandardizedYield/implementations/AaveV3/PendleAaveV3SY.sol`
- `core/YieldContracts/PendleYieldToken.sol`, `PendlePrincipalToken.sol`, `PendleYieldContractFactory.sol`, `InterestManagerYT.sol`
- `core/Market/MarketMathCore.sol`, `PendleGauge.sol`
- `core/Market/v3/PendleMarketV3.sol`, `PendleMarketFactoryV3.sol`
- `router/PendleRouterV4.sol`, `ActionSwapYTV3.sol`, `ActionCallbackV3.sol`, `base/ActionBase.sol`
- `oracles/PendlePYLpOracle.sol`
- `limit/PendleLimitRouter.sol`
- `LiquidityMining/VotingEscrow/VotingEscrowTokenBase.sol`, `VotingEscrowPendleMainchain.sol`
- `README.md` (points at whitepapers and `@pendle/core-v2`)
