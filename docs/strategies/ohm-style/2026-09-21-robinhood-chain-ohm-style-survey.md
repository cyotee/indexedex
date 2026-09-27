# Robinhood Chain Olympus-style protocol survey

**Status:** Research note. Not a PRD, deploy plan, token allowlist, or investment recommendation.  
**Researched:** 2026-09-21  
**Chain:** Robinhood Chain mainnet, chain ID **4663** (Arbitrum Orbit L2, public mainnet 2026-07-01)  
**Purpose:** Save a first-pass map of OlympusDAO-like reserve protocols and nearby designs on Robinhood Chain, including protocols that do **not** issue a rebasing staking token.

Figures below are snapshots from public sites (DeFiLlama, project docs, explorers, press) on or around 2026-09-21. Re-read contracts and live state before any integration. Several treasury and revenue numbers are project-reported; HoodScan notes that some NetNet game-desk figures are not independently verifiable on chain.

IndexedEx already has a deeper NET / Morpho / Pendle strategy catalog: [`docs/detf/NET_MORPHO_PENDLE_STRATEGY_RESEARCH.md`](../../detf/NET_MORPHO_PENDLE_STRATEGY_RESEARCH.md). This note is the wider chain survey that that catalog does not try to be.

---

## 1. Chain context

Robinhood Chain is an Ethereum Layer 2 on the Arbitrum Orbit stack. Gas is ETH. There is no native chain token and no protocol-level staking of the chain itself. The sequencer is Robinhood-operated. Stock Tokens are ERC-20 tokenized debt securities issued by Robinhood Assets (Jersey) Limited; they give economic exposure, not legal share ownership. Corporate actions use an ERC-8056 `uiMultiplier()`; raw `balanceOf` does not rebase.

Canonical cash on the chain is **USDG** (Paxos Global Dollar). DeFiLlama around 2026-09-21 showed roughly:

| Metric | Snapshot |
|---|---|
| DeFi TVL | ~$991m |
| Stablecoin market cap | ~$1.045b (USDG ~66% dominance) |
| RWA active AUM | ~$296m |
| DEX volume 24h | ~$1.02b |
| Perps volume 24h | ~$444m |
| App fees 24h | ~$4.75m |
| App revenue 24h | ~$869k |
| Chain fees / revenue 24h | ~$207k / ~$186k |

Lending TVL was dominated by Morpho Blue (~$555m). Uniswap (v2/v3/v4) was the main DEX. Pons was the leading launchpad by retained revenue.

Official launch stack (July 2026): Uniswap, Pleiades, Chainlink, Alchemy, BitGo, Morpho (Robinhood Earn), plus later venues such as Rialto, Lighter, Arcus.

---

## 2. What "Olympus-style" means here

OlympusDAO v1 (2021) combined:

1. A free-floating reserve token (OHM, 9 decimals) minted only against treasury assets.
2. **Bonds:** sell the reserve token at a discount for reserve assets or LP, which become protocol-owned.
3. **Staking + rebase:** stake OHM, receive **sOHM** 1:1. Every ~8 hours a rebase increases sOHM balances (gons / `gonsPerFragment`). Unstaked OHM is diluted.
4. A non-rebasing wrapper (wsOHM, later gOHM) for DeFi composability.
5. RFV / backing as an internal floor, distinct from market price.
6. Later Olympus pieces (Cooler loans, Yield Repurchase Facility, Convertible Deposits, Range Bound Stability) that some Robinhood forks copy and some do not.

The **essential staking criterion** used in section 3 is a **rebasing receipt token**: `stake(TOKEN) → sTOKEN` whose `balanceOf` increases each epoch without a claim. Vote-escrow NFTs, ERC-4626 shares, and "claim rewards" staking fail that test even if they are otherwise DeFi staking.

Olympus later **stopped rebasing**. Current OHM staking is gOHM for votes and Cooler, not sOHM inflation. The Robinhood copies below are mostly the 2021 v1 machine, not 2026 Olympus Association policy.

**(3,3)** in marketing is overloaded:

- Original Olympus game theory: stake vs bond vs sell.
- **ve(3,3)** (Solidly → Velodrome / Aerodrome): lock into a veNFT, vote gauges, take fees. That is a DEX tokenomic, not a rebasing s-token.

---

## 3. Filter: rebasing s-token or not

| Protocol | Rebasing s-token? | Live on 4663? | Category |
|---|---|---|---|
| **NetNet Capital Management** | Yes: **sNET** (wsNET wrapper) | Yes | Reserve currency (OHM v1 lineage) |
| **NUKES.FUN** | Yes: **sNUKE** (wsNUKE wrapper) | Yes | Reserve currency; NNE accumulation |
| **Hoodz** | Yes by design: **sHOOD** / **gHOOD** | Code + Pons launch; treat as unaudited clone | Literal Olympus reimplementation |
| **Hoodlympus DAO** | Yes by design: **sthOHM** | **No.** Contracts "coming soon" | Equity-backed OHM fork (docs only) |
| **Rubicullus** | Yes: **sRHM** | Early July 2026; liquidity incident + redemption | Early OHM fork, likely wound down |
| **Root Rebase** | Yes: **sROOT** | Claims live | Rebase token **without** treasury/bond machine |
| **erc.fun** | **No.** Explicitly no rebase | Yes (Pons launch) | Bond-to-maturity, stock treasury |
| **up / UponRH** | **No.** veUP NFT | Yes | ve(3,3) DEX |
| **Fables** | **No.** ve-style / V4 hooks | Yes | Stock-token DEX |
| **Ramses, Raphael** | **No.** ve(3,3) | Yes | DEXs |
| **Pons** | **No** | Yes | Launchpad (POL comparison only) |
| **Longbow, Twofold, Morpho** | **No** | Yes | Credit / dual-yield |
| **Robinpool rhETH** | **No.** Exchange-rate LST | Product site exists | ETH liquid staking, not OHM |

Live protocols that match both "Olympus-like reserve" and "rebasing s-token": **NetNet** and **NUKES.FUN**. Hoodz is the named contract clone. Hoodlympus is design-only. Rubicullus was first-to-market and then offered backing redemption. Root Rebase is a rebase token, not a reserve protocol.

---

## 4. Protocols with a rebasing staking token

### 4.1 NetNet Capital Management ($NET)

The largest and best-documented OHM-style protocol on the chain.

- Sites: [netnet.capital](https://netnet.capital/), [docs.netnet.capital](https://docs.netnet.capital/), staking UI [app.netnet.ink](https://app.netnet.ink/), [vfat.tools/robinhood/netnet](https://vfat.tools/robinhood/netnet/)
- X: [@NetNetCap](https://x.com/NetNetCap)
- DeFiLlama: [protocol](https://defillama.com/protocol/netnet-capital-management), [RWA asset](https://defillama.com/rwa/asset/net)
- Prospectus claim: NET is "a reserve-backed token in the architectural lineage of OlympusDAO v1," rebuilt without a policy committee. Emissions, buybacks, premium sales, and bond pricing are formulas. Operational entrypoints are permissionless.

**Token mapping**

| Olympus v1 | NetNet |
|---|---|
| OHM (9 decimals) | NET (9 decimals) |
| sOHM | sNET |
| wsOHM / gOHM | wsNET |
| Treasury | Treasury (USDG RFV) |
| Bond depository | BondDepository + GenesisBond |
| Inverse bonds | InverseBond (buyback below NAV) |
| Distributor | Distributor (immutable rate formula) |
| Policy DAO | Claimed none on the emissions path |

**Staking / rebase**

- Stake NET → sNET 1:1. Epoch = **8 hours** (3 per day).
- sNET uses the OHM v1 **gons** model: fixed total gons, rebase scales `gonsPerFragment`.
- Rebase call is permissionless after the epoch elapses.
- Dividend rate is a function of market premium over NAV:

```
P    = marketPrice / NAV
rate = R_MAX × clamp((P − 1) / (K − 1), 0, 1)
```

| Constant | Value |
|---|---|
| `EPOCH_LENGTH` | 8 hours |
| `R_MAX` | 0.45% per epoch |
| `K` | 1.75 |

At or below NAV: 0%. At ≥1.75× premium: full 0.45%/epoch (~1.356%/day in NET units; theoretical max APY ~13,552% if premium held a year). Docs state that APY column is arithmetic, not a promise, and that the RFV cap binds first.

**Reserve cap:** Distributor cannot mint if `totalSupply × 1 USDG` would exceed Treasury RFV. Stated invariant: every NET is backed by at least **1 USDG** of risk-free value. That floor is not current NAV.

**Oracle:** TWAP from the canonical Uniswap v2 NET/USDG pair. `checkpoint()` is permissionless, minimum 30 minutes between checkpoints. Valid TWAP window 30 minutes–4 hours. Stale oracle pauses minting, buybacks, and PremiumSeller.

**Bonds:** `price = max(TWAP × (1 − BOND_DISCOUNT_BPS), NAV)`. Never sold below NAV. Capacity capped per epoch. LP valued `2·sqrt(x·y)` with the NET leg at the 1 USDG floor.

**Buyback:** standing bid below NAV (docs: NAV − 1.5%). Live since market open, per the project.

**Reserves:** liquid USDG, USDG lent on Morpho (Steakhouse position, 2% haircut in RFV; idle USDG capped around 70% in Morpho in press writeups, 30% liquid for redemptions/buybacks), protocol-owned NET/USDG v2 LP. **RWA Sleeve** (tokenized NVDA, AAPL, SPCX, etc. via Rialto / Real World Bonds desk, live since 24 July 2026) is **not** counted in RFV or NAV.

**Extra surface (not Olympus):** "RW-play" desks (coinflip, blackjack, climb, packs, SpaceX Invaders, MSFT Flight Simulator, Turbo, WinNET, CLIMB INC., The Button, Board Meeting, baskets). HoodScan: treasury/revenue on some desks self-reported. Test futures desk uses faucet **tNET**, not NET.

**Dated snapshots (around 2026-09-21)**

Project terminal (netnet.capital, 21 Sept 2026 ~08:07 UTC): market ~759.95 USDG, NAV ~169.11 USDG, premium ~4.49×, reserves ~16.82m USDG, ~99,435 NET in issue, ~91,933 staked.

DeFiLlama: market cap ~$3.63m on a small circulating figure vs FDV ~$74.8m; NET ~$753; staked ~$67.9m at market; treasury ~$21.7m (~$18.0m stables, ~$3.8m other). TVL listed $0 because the adapter is staking/treasury, not classic TVL. ATH $1,887.55 on 29 Aug 2026.

Genesis (project posts): July 2026 founding subscription 3 USDG/NET vs day-one NAV ~2.41 USDG; ~$52k reserves at genesis. Deployed 2026-07-16, block 11439688, from `0xCfBd7e12A0f154a45576a73C1E409200068507B9`.

Press: Ansem ~$57.6k NET purchase reported 26 Aug 2026. Founder interviews cited NBA Top Shot / Dapper background and claimed Robinhood-team discussions (unverified here).

**Contracts (Robinhood Chain, from DeFiLlama notes, docs, HoodScan)**

| Role | Address |
|---|---|
| NET | `0xCA9c78Dd337A67F6e0077F65F5E9218719d30eDf` |
| Treasury | `0x04822ea321a0dee6f40656172f29312104855d66` |
| Staking | `0xb078cc304a0b264c5f3680dc0488954accd02e87` |
| sNET | `0xb773ec2C326B7f98a5a83fc098825492F020a4c7` |
| BondDepository | `0xff32a969a0c567129eecd926d04657728e1980c1` |
| GenesisBond | `0x575b7b7c97ef3e21c82daeb427899d583e1e913f` |
| TaxCollector | `0x086c58400b8708ef993f256e12e752dcf0ac918e` |
| Guardian Safe | `0x3bb7a23316f82c0e984fa2e784846d8928a35f42` |
| TWAP oracle | `0x929631b33f4070d6f54477fba3fd27566567daca` |
| NET/USDG Uniswap v2 | `0x59F95461E68e0c77605299791E1449f175165B54` |
| NET/USDG Uniswap v4 pool id (press) | `0x04263541986025755033c507d2c02863354abe64236878f3455b7d72ad9cce27` |
| wsNET | `0x63C12667638f2Ae6fC6ae09B43D98Ec84a8586eA` |
| Blackjack desk | `0x712f52fd42d7b89fd444e0cc4430020faa9cfb26` |
| Coin flip desk | `0xa99d15dace9aede816600a31c3e4158926000f3c` |
| Climb desk | `0x21089cfcdbf47902a2f3950200ce9ea66bf79ee4` |
| RWA desk | `0xa84efc3136bf1bb89ade9e5be6ab32cb1a04f08d` |
| Jackpot pool | `0xf125ad8abde2591609a982e0b6a51309fdf7db37` |
| tNET (test) | `0xCeF73866b088766DeD46Ba71d9Bd7591B5e931d2` |
| PerpOracle | `0xc8a11E8793F8714a159061369173dc86A0A5E23F` |
| FuturesClearinghouse | `0xf6ec124ca62C841384ABD0e128552cF9Eb446205` |
| UnderwritingVault | `0x3a7Dce19447f9028C360592fDfdb3f27c50daE29` |
| PerpFeeRouter | `0x8d8A68884134b49EC8549f6F5D7b43b8Ca327814` |
| FeeSink | `0x82d04c79424FA36BD252Aa0D031de512f5F7aeFa` |
| Zap | `0xA1ee052EC32532304a7522bd9A4b594eC28fF1b1` |

Do not confuse NET the protocol token with Cloudflare's tokenized stock, also ticker NET (`0x116f00968269b7bfbad4109ce591d6e74c0601d4` on hoodfi.io).

### 4.2 NUKES.FUN ($NUKE)

Reserve protocol whose stated mandate is to accumulate tokenized **Nano Nuclear Energy (NASDAQ: NNE)**.

- Sites: [nukes.fun](https://nukes.fun/), [manual](https://nukes.fun/manual)
- X: [@nukesfun](https://x.com/nukesfun)
- DeFiLlama: [protocol](https://defillama.com/protocol/nukes.fun) (category: Reserve Currency)

**Mechanics (from protocol manual)**

- Buy NUKE, or bond USDG for vested NUKE.
- Stake NUKE → **rebasing sNUKE**. Rebases every **eight hours**, compound automatically. No lock period claimed.
- Dynamic bonds: 30-minute TWAP minus 3%, backing floor, hourly capacity inside each 8-hour epoch, linear vest (manual: two days; some posts said five days).
- Treasury: USDG reserves, NNE accumulation via authorized venue during US hours (avoids thin on-chain NNE pools), protocol-owned liquidity. LP fees to backing or burns.
- Team: no ongoing fee stream claimed. Incentives Bond only above $33m NUKE market cap, cap 10% of supply.
- Genesis bond: $2.00 USDG per NUKE, three-day window, five-day vest (manual).
- sNUKE listed on Pendle (second Robinhood pool, ~24 Sep 2026 maturity, announced 8 Sep 2026).

**Dated snapshots**

Site mission control (research window): NUKE ~$23.63, circ ~125k, mcap ~$3.0m, backing/circ ~$5.64, staked ~59.4k NUKE, staking APY ~114%, epoch 14. DeFiLlama: treasury ~$502k (~$287k stables, ~$209k other, ~$6k own tokens), staked ~$14–15k. Uniswap/GeckoTerminal also showed much lower spot (~$6) on some pools; treat price as venue-specific until re-read.

**Contracts (from nukes.fun/manual)**

| Role | Address |
|---|---|
| NUKE | `0x0000000005aCa17e8bd5779Fc87E13cb433aEd24` |
| sNUKE | `0x4BEF5C76A50bc68f63B8E2628CDB3b33cB445934` |
| wsNUKE | `0x34b824a94790Aab057125Bb7eD9fE06e12f0871b` |
| Staking | `0x9c648d57e929f59b483b2903390725449F990CB8` |
| Distributor | `0xcc7C542c2e3Ad3Fa2BF939c1F92260f86C5b8F9E` |
| Dynamic Bond Depository | `0x468201e4Ab5a63c569957A37F5abdAA952984a83` |
| Dynamic Bond Valuation | `0x85b6431da5972fc087fF4f10423906549c23ADad` |
| Legacy Bond Depository | `0x29D450FEFb79D2b252F027883fE69Af97978F834` |
| Incentives Bond | `0x2A55E636d70dA1ab4de9349d4FF7E24863e2b1fD` |

### 4.3 Hoodz ($HOOD)

GitHub [averageballer13/Hoodz](https://github.com/averageballer13/Hoodz): "A faithful, rebranded re-implementation of the Olympus DAO protocol" on chain 4663, HOOD launched through Pons. Authors: unaudited educational clone. Names, chain, and launch venue changed; mechanism not.

| Olympus | Hoodz |
|---|---|
| OHM / sOHM / gOHM | HOOD / **sHOOD** / **gHOOD** |
| Cooler Loans | Hoodz Loans |
| YRF | YRF |
| Convertible Deposits | Convertible Deposits |
| Emissions Manager | Emissions Manager |

Staking is the gons rebase. Site hoodz.finance / @Hoodzfinance. Confirm whether staking contracts are actually deployed before treating as live; the repo includes a live.js loader keyed off `assets/deployments.json`.

Do not confuse with hoodz.gg (Bomb Brawl game), SwapHood's HOOD/h33, or Robinhood Markets ticker HOOD.

### 4.4 Hoodlympus DAO ($hOHM) — not deployed

[hoodlympus.biz](https://hoodlympus.biz/docs.html): Olympus-style POL / bonding / staking with tokenized US equities (TSLA, NVDA, AAPL) and Uniswap v4 hook fee capture. Staking: **$hOHM → $sthOHM** 1:1; sthOHM balance grows each epoch. Rebase rate described as `f(Excess Reserves, Hook Trading Fees, Vesting Penalties)`, not a fixed high APY.

Docs: "Hoodlympus DAO is coming soon." Balance page: contracts not deployed, wallets correctly show 0. Address table is "Coming soon" for hOHM, sthOHM, bonding, treasury, staking, V4 hook.

### 4.5 Rubicullus ($RHM) — early fork, incident

Claimed "first treasury-backed reserve protocol on Robinhood Chain" / "OlympusDAO model rebuilt" in July 2026. Stake RHM → **sRHM**, 8-hour rebases, 3 epochs/day, 1,095/year. Bonds for discounted RHM, POL from fees.

Token CA posted: `0xe6de2c3494faf13af24f325fdbf585c1da443007`. Site rubicullus.com.

On or about 13 July 2026 the project posted that LP was not drained, paused bonds, and opened a trustless backing redemption: ~0.0274 WETH per RHM. Redemption contract posted `0x1f0f0f3e76a62b80bc4ddc83cbacd0a280c3bc51`. Locker `0x61b9cB76e625beF85929066dEC9606Ad99Fe4cB2`. Treat as wound down unless a later on-chain revival is verified.

### 4.6 Root Rebase ($ROOT)

[rootrebase.com](https://rootrebase.com/): "A rebase protocol on Robinhood Chain." Stake ROOT → **sROOT** 1:1. Epoch **8 minutes** (180/day). Fixed 0.0056875% per epoch, advertised 4,096% APY. No claim that it has a treasury, bonds, or RFV. Not an Olympus reserve protocol; it only shares the rebasing s-token shape.

How-to-stake address fragment on the site: `0xd521...8f95` (incomplete in the crawl; re-read the live page before use). FAQ denies affiliation with OlympusDAO or Robinhood.

---

## 5. Olympus-like without a rebasing s-token

### 5.1 erc.fun ($ERC)

[erc.fun](https://erc.fun/): "This is the last OHM fork." Treasury is **tokenized stocks**, not crypto. Launched on Pons.

Explicitly **not** a rebase protocol:

- ERC is a standard ERC-20: "no transfer tax, no rebasing balance, no hidden fee on ordinary transfers."
- Supply grows once per bonded position, at **maturity mint**. No continuous inflation, no timer emission.
- UI: "There's no rebase to track and no balance that changes day to day." Described as a deliberate departure from classic OHM staking.

Flow: bond liquidity → lock → wait for maturity → mint. Early redemption tax only.

Token: `0xD25610f1C9eE40C3322d498D58ac6C9A512d3765`. Site snapshot: treasury ~$1.86m, backing ~$18.42/token, "0% APY at maturity" on the hero (re-read live), diversified across 16 stock tokens (TSLA 12%, NVDA 11%, AAPL 10%, MSFT 9%, SPY 8%, AMZN 8%, GOOGL 7%, META 7%, COIN 5%, QQQ/MSTR/NFLX/AMD 4%, GME 3%, SPCX/CRCL 2%).

### 5.2 Pons as POL analogy (not a reserve protocol)

Pons is the native launchpad (v1 Uniswap V3 locked pool; v2 bonding curve then Uniswap V4 graduation). Lex Substack (8 Sep 2026) compared Pons meme/stock-token LPs to Olympus bonding: a high-quality Stock Token is locked next to a meme, protocol-owned liquidity prices the meme. That is a liquidity structure comment, not an s-token.

DeFiLlama around 2026-09-21: Pons ~$296k revenue / 24h, ~$24.6m / 30d. Earlier peaks reported ~$4.7m daily fees vs Pump.fun.

### 5.3 HoodScan / other "reserve-backed" labels

HoodScan listed NetNetCap as "OHM-style reserve token" with 60-second minigames. Other RWA names on the same directory (Prism, The Index, Hood Index M7) are tax-and-buy or 1:1 index products, not sOHM clones.

---

## 6. ve(3,3) DEX layer (Olympus game-theory cousin, not s-tokens)

These lock tokens into vote-escrow NFTs, vote gauges, and take fees. Balances do not rebase.

### 6.1 up / UponRH ($UP)

Native ve(3,3) DEX. Sites: [up33.xyz](http://up33.xyz). X: [@uponrh](https://x.com/uponrh). Bio: "The native (3,3) exchange and liquidity layer of Robinhood Chain."

Lock UP → **veUP** NFT. Weekly gauges. Fees to voters. V2 AMM + CL (Slipstream-style) pools, auto-compound vaults. **Gauge Cap:** emissions above a pool's fee capacity are burned. Integrated with StonkBrokers launchpad (locked LP + emissions). CandyDrops capture (2 Sep 2026): ~$12m TVL, ~$77m 24h volume; ~3.8% of supply circulating, FDV ~26× mcap. Dune: uponrh ~0.87% of decoded raw DEX volume vs Uniswap dominance.

DeFiLlama "up" on Robinhood: v3 TVL ~$8m in one CLMM table; holders revenue ~$38k/24h in another snapshot.

### 6.2 Fables

Uniswap v4 hooks DEX for stock tokens. Dynamic fees when US markets are closed / toxic flow. PROLOGUE placeholder, 1:1 to future governance token claimed. Alphix Association (Zug) per CandyDrops. DeFiLlama: Fables TVL ~$31.7m, fees ~$166k/24h (snapshot). TechFlow listed PROLOGUE as the live ticker.

### 6.3 Ramses ($RAM)

ve(3,3) with CL, DLMM, legacy pools. Ramses CL V2 TVL ~$6.5m, 7d volume ~$497m in the CLMM table.

### 6.4 Raphael Exchange ($RAPH)

ve(3,3) DEX, vote-escrowed RAPH directs emissions across equity and native pairs (HoodScan).

### 6.5 GIGA, Alandale

DEX fee share to veGIGA / veLUTE voters (DeFiLlama holders-revenue definitions). Not reserve currencies.

---

## 7. Adjacent utility protocols (TechFlow / blocmates, 9 Sep 2026)

Source: [Robinhood Chain Gold Rush Guide: 15 Utility Protocols](https://www.techflowpost.com/en-US/article/33853) (Emiri / blocmates, compiled by TechFlow). Watchlist, not a safety ranking.

**Named "giants" in that article (not the 15):**

| Name | Note |
|---|---|
| **Pons** | Native launchpad; article: mcap briefly near $900m |
| **AI** | Meme paired with tokenized NVDA; ~80% of buy fee buys NVDA into a community treasury |
| **CASHCAT** | Leading meme; Galaxy: peaked >$200m mcap, later ~80% drawdown |

**Earlier watchlist names in the same article:** Index (V4 hook tax buys NVDA/AAPL/MSFT basket), SLVR (5×5 grid mining; DeFiLlama staked ~$300k, 24h holders revenue ~$53–57k), Arcus (Robinhood + dYdX joint, stock/crypto spot+futures, public beta), Rialto (propAMM).

**The 15:**

| # | Protocol | What the article said | Rebase s-token? |
|---|---|---|---|
| 1 | **Longdotxyz** | Launchpad pairing memes with stock tokens (AI/NVDA, BONER/HIMS, MEME/AMC, NUDES/SNAP, MOO/MU) | No |
| 2 | **Netnet** | Hardcoded OHM, USDG RFV/NAV, Morpho on idle USDG, RW-play games | **Yes, sNET** |
| 3 | **Longbow** | Overcollateralized money market; lend USDG, borrow vs memes/RWA/stocks; BOW staked for USDG revenue | No (DeFiLlama lending TVL ~$4.8m) |
| 4 | **Twofold** | Uniswap v4 DualPool: same dollars in Steakhouse lending + swap fees | No (~$34k staked on DeFiLlama) |
| 5 | **Mancer** | Aggregator (limit, TP/SL, DCA); NFT activation burns MANCER | No |
| 6 | **Quotron** | 4,444 NFTs as terminals accruing stock tokens; burn 1 QUOTRON to hardwire | No |
| 7 | **Hookr** | V4-hook launchpad (anti-snipe, fee, burn rules); HOOKR buyback from ETH-paired fees | No |
| 8 | **Fables** | V4 hook DEX, dynamic fees, PROLOGUE | No |
| 9 | **Statics** | Baskets → BasketToken, loans, USDstx; 5,555 Operators NFTs "reserve-backed" at 180k STATICS each | No (NFT/stake, not sOHM) |
| 10 | **Arrow Finance** | Lending aUSD, ArrowPad, aggregator; veARROW votes LTV/oracles/fees | No |
| 11 | **Shroom** | Liquidity layer pairing SHROOM with stock tokens; MU stock rewards; buyback/burn plan | No |
| 12 | **Clutch / StonkBrokers** | 4,444 ERC-6551 broker NFTs, Anvil NFT AMM, Clock In, Broker Box, Stonk Launcher, vDEX | No (DeFiLlama staked ~$13–14m; launchpad revenue material) |
| 13 | **Orbio** | OpenRouter API + compute quota market; 1.5% trade fee, 50% to OpenRouter credits for holders ≥1,000 ORBIO | No |
| 14 | **Earn (EARNONHOOD)** | Stock+USDG LP vaults routed to highest-yield pools. Separate EARN stake/claim (not rebase): staking `0xeE7abf…0bD051`, token `0xA3b6AE…917ba3` | No |
| 15 | **Pare** | Pendle-like split of a stock token into pTOKEN (price) and yTOKEN (dividends); PARE buyback/burn | No |

WEEX (17 Sep 2026) mapped some of those tickers to CEX rows: PONS, CASHCAT, NET had spot+contract; AI, INDEX, HOOKR, SHROOM, STONKBROKER, ORBIO had spot.

---

## 8. Other staking that is not sOHM

| Name | Mechanism | Why it fails the rebase filter |
|---|---|---|
| **Robinpool rhETH** | Deposit ETH, mint rhETH | Redemption value rises; `balanceOf` does not rebase |
| **StakeHood** | ETH staking product site | PoS-style lock APY; not a reserve s-token |
| **EARN staking** | Stake EARN, claim rewards | Continuous accrual + claim, no s-token rebase |
| **HoodMarket NFT Stake** | Lock ERC-721, earn ERC-20 | NFT lock, not rebasing ERC-20 |
| **SLVR / gamified mining** | veNFT + grid lottery | Emissions and buybacks, not sOHM |
| **Ripe Protocol** | Lending + some staked figure | Credit, not reserve rebase |
| **Morpho / steakUSDG / syrupUSDG / spUSDG / sUSDe** | Vault / savings receipts | ERC-4626-like share price drift; see [`docs/research/2026-08-15-robinhood-mainnet-usd-and-vault-tokens.md`](../../research/2026-08-15-robinhood-mainnet-usd-and-vault-tokens.md) |
| **Robinhood app ETH/SOL/ADA staking** | Brokerage product | Unrelated to chain 4663 DeFi |

DeFiLlama "Total Staked" on Robinhood Chain (~$80–83m in the research window) is dominated by **NetNet** (~$65–68m at **market** price of staked NET), then StonkBrokers, What The Hook, STONX, SLVR. That table is not a list of rebasing s-tokens.

---

## 9. How 2021 OHM differs on this chain

1. Backing is **USDG** and/or **Stock Tokens**, not DAI/FRAX/ETH. USDG is Paxos cash. Stock Tokens are Jersey debt securities, not shares.
2. Several protocols **hardcode** levers Olympus left to a DAO (NetNet's prospectus is the clearest statement).
3. NetNet and NUKES.FUN add games or a **single-name equity mandate** on top of the reserve loop.
4. High APY is still **dilution in token units**. If premium → 1×, NetNet's formula pays 0%. The 1 USDG RFV floor is not current NAV; a collapse toward the floor can still wipe most of the market price.
5. Rebasing s-tokens break naive ERC-20 assumptions (tax lots, AMM balances, lockers). HoodLock docs warn that positive rebase leftovers stick in the locker and negative rebase can insolvent the last unlocker. IndexedEx DETF `rebasingClaimToken` / sDETF is a **protocol product**, not an allowed underlying (agent law: rebasing underlyings forbidden).

---

## 10. Risks recorded during research

- Unaudited clones (Hoodz self-describes as such).
- Rubicullus: launch-week liquidity incident and redemption.
- HoodScan: some NetNet game treasury/revenue not independently verifiable.
- DeFiLlama vs project terminals disagree on NET circulating, TVL ($0 vs large staked), and NUKE price across venues.
- Stock Token legal wrapper: economic exposure only.
- Classic OHM death spiral: rebase funded by premium; premium collapse → rate collapse → exit race. NetNet's 0% at NAV and RFV mint cap are mitigations, not a guarantee of USDG price.
- FoT / rebase / locker incompatibilities for any future vault integration.

This note does not evaluate solvency, audits, or team identity beyond what public pages stated.

---

## 11. IndexedEx relevance (pointer only)

IndexedEx funded DETF staking uses `rebasingClaimToken` / `IStakedDETF` (9 decimals, 1:1 in held DETF). That is the in-house analog of sOHM, not an integration with NET/sNET.

If a later task considers wrapping these external protocols:

- Rebasing sNET / sNUKE are poor underlyings; prefer **wsNET** / **wsNUKE** if anything, and still treat them as weird tokens.
- NET already has Morpho Loopback and Pendle work in the DETF strategy docs.
- Do not put FoT or rebasing tokens in SE/DETF underlyings.

No product decision is made here.

---

## 12. Sources

**Primary / project**

- [NetNet prospectus](https://docs.netnet.capital/), [mechanism](https://docs.netnet.capital/mechanism), [treasury](https://docs.netnet.capital/treasury), [futures test desk](https://docs.netnet.capital/futures), [netnet.capital](https://netnet.capital/), [app.netnet.ink](https://app.netnet.ink/)
- [NUKES.FUN manual](https://nukes.fun/manual), [nukes.fun](https://nukes.fun/)
- [Hoodlympus docs](https://hoodlympus.biz/docs.html), [hOHM page](https://hoodlympus.biz/hohm.html), [treasury preview](https://hoodlympus.biz/treasury.html)
- [erc.fun](https://erc.fun/)
- [Hoodz README](https://github.com/averageballer13/Hoodz)
- [rootrebase.com](https://rootrebase.com/)
- Rubicullus X (@Rubicullus) threads 2026-07-11 through 2026-07-13
- [up33.xyz](http://up33.xyz) / @uponrh
- [earnonhood.com/docs](https://earnonhood.com/docs)

**Data / directories**

- [DeFiLlama Robinhood Chain](https://defillama.com/chain/robinhood-chain)
- [DeFiLlama NetNet](https://defillama.com/protocol/netnet-capital-management), [NET RWA](https://defillama.com/rwa/asset/net)
- [DeFiLlama NUKES.FUN](https://defillama.com/protocol/nukes.fun)
- [DeFiLlama total staked](https://defillama.com/total-staked/chain/robinhood-chain)
- [DeFiLlama lending](https://defillama.com/protocols/lending/robinhood-chain), [revenue](https://defillama.com/revenue/chain/robinhood-chain)
- [hoodl2.com](https://hoodl2.com/), [hoodscan.co/projects](https://hoodscan.co/projects), [hoodscan NetNetCap](https://hoodscan.co/project/netnetcap)
- [vfat NetNet](https://vfat.tools/robinhood/netnet/)

**Press / roundups**

- [TechFlow gold rush guide, 9 Sep 2026](https://www.techflowpost.com/en-US/article/33853)
- [PANews / Bit.Fan: ve(3,3) + OHM on Robinhood Chain, 27 Aug 2026](https://www.panews.io/articles/01a042c1-c158-759d-a3c8-186d75063b03)
- [Lex Substack on Pons vs Olympus POL, 8 Sep 2026](https://lex.substack.com/p/defi-robinhood-stock-tokens-power)
- [Forbes chain launch, 1 Jul 2026](https://www.forbes.com/sites/ninabambysheva/2026/07/01/robinhood-launches-its-own-blockchain-new-stock-tokens-and-defi-products/)
- [CertiK on-chain capital market, 24 Aug 2026](https://www.certik.com/blog/robinhood-chain-onchain-capital-market)
- [Galaxy launch analysis, 15 Sep 2026](https://www.galaxy.com/insights/research/robinhood-chain-launch-analysis-base-comparison-memecoins-distribution-thesis)
- [BTCC / TechFlow on Ansem NET purchase, 26 Aug 2026](https://www.btcc.com/en-IN/news/flash-article/108482)
- [WEEX mapping of the 15, 17 Sep 2026](https://www.weex.com/learn/articles/15-notable-robinhood-chain-protocols-which-assets-trade-on-weex-laeerboxame0ge7sghy2skdk)
- [TrustSwap: chain staking vs app staking](https://trustswap.com/robinhood/staking)
- [Robinhood Stock Tokens docs](https://docs.robinhood.com/chain/stock-tokens/)

**IndexedEx**

- [`docs/detf/NET_MORPHO_PENDLE_STRATEGY_RESEARCH.md`](../../detf/NET_MORPHO_PENDLE_STRATEGY_RESEARCH.md)
- [`docs/research/2026-08-15-robinhood-mainnet-usd-and-vault-tokens.md`](../../research/2026-08-15-robinhood-mainnet-usd-and-vault-tokens.md)
- [`docs/agent/INDEXEDEX_AGENT_LAW.md`](../../agent/INDEXEDEX_AGENT_LAW.md) (token policy: FoT and rebasing underlyings forbidden)

---

## 13. What this survey did not do

- Did not verify bytecode against Olympus v1, did not run fork tests, did not read every NetNet desk page.
- Did not confirm Hoodz `deployments.json` against Blockscout.
- Did not resolve DeFiLlama vs project-terminal disagreements.
- Did not enumerate every meme, launchpad, or lending market on 4663.
- Did not interview teams or check audits beyond what pages claimed.

A follow-up that needs on-chain truth should start with NetNet and NUKES.FUN verified contracts, then Hoodz deployment manifest, then ignore marketing "OHM fork" labels that lack a rebasing s-token.
