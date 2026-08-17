# Robinhood Stock Tokens — overlapping DETF grouping matrix

**Status:** Research note — 2026-08-15  
**Chain:** Robinhood Chain mainnet, chain id **4663**  
**Universe:** Official RHJ Stock Tokens from `GET https://api.robinhood.com/rhj/assets` (194 `ASSET_STATUS_ACTIVE`, all on 4663). Addresses in Crane `ROBINHOOD_MAIN.RH_*` / `RH_STOCK_TOKEN_COUNT`.  
**Purpose:** Reference groups for **base (leaf) DETFs** first, then later nesting. Groups are **not** mutually exclusive.  
**Not:** a locked product decision, token allowlist, or deploy plan.

**Related:** [`2026-08-15-robinhood-mainnet-usd-and-vault-tokens.md`](./2026-08-15-robinhood-mainnet-usd-and-vault-tokens.md), [`docs/ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_PRD.md`](../ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_PRD.md) (D26 is the dollar Curve Quad, not this set).

**Count rule:** `n` is **unique tickers in that row**. A token may appear in many rows; do **not** sum the `n` column and expect 194.

---

## 1. What these tokens are

They are **not shares**. Each official token is a **tokenised debt security** issued by Robinhood Assets (Jersey) Limited (RHJ). It tracks one US stock or ETF **economically**. It does **not** give voting rights, a claim on the company, or a claim against that company’s issuer.

| Fact | Detail |
|------|--------|
| Wrapper | ERC-20, 18 decimals, one contract per ticker |
| Economic claim | RHJ says each circulating token is **backed 1:1** by the underlier at a US custodian |
| Dividends | **Not cash.** `uiMultiplier()` (ERC-8056) rises; Chainlink on-chain price = equity price × multiplier (total return) |
| Primary mint/redeem | Authorised participants only (at launch, BBVI) |
| Secondary | DEX / CEX / wallet |
| Jurisdiction | Not for US / UK / Canada / Switzerland persons |
| Not this set | Classic Stock Tokens (EU-app derivatives with Robinhood Europe); explorer spoof tickers |

A nested DETF nests **RHJ credit + oracle + custody**, not “NVDA the company.” Every group below is the **same legal wrapper**, different underliers.

Pause / confiscate / upgrade sit on RH’s shared access registry. Weird-token law: pause accepted; confirm no FoT and that `uiMultiplier` is display/oracle only (balance is not rebasing).

---

## 2. Partition (the only exclusive cut)

| Class | n | What it is | Tickers |
|-------|---|------------|---------|
| **Official universe** | **194** | All ACTIVE RHJ Stock Tokens on 4663 | `ROBINHOOD_MAIN.RH_*` |
| **Single-name (base stocks)** | **177** | One company, ADS, or private/special class | Universe minus the 17 funds |
| **Fund / ETF** | **17** | Listed fund, not a company | `SPY` `VTI` `QQQ` `SPMO` `SCHD` `XLK` `SMH` `SOXX` `EWT` `EWY` `INDA` `BND` `SGOV` `SHY` `GLD` `SLV` `USO` |

`194 = 177 + 17`. Every later row may mix names from both sides (e.g. `NVDA` and `SMH` in Semiconductors).

---

## 3. How the underlier is packaged (overlapping)

| Class | n | Tickers | Notes |
|-------|---|---------|-------|
| **Broad equity index ETF** | **5** | `SPY` `VTI` `QQQ` `SPMO` `SCHD` | “The market.” Strong Curve Quad candidate: pick any 3 of `SPY`/`VTI`/`QQQ`. |
| **Sector / theme ETF** | **3** | `XLK` `SMH` `SOXX` | Already a bundle. Also members of Semiconductors / Tech. |
| **Country / region ETF** | **3** | `EWT` `EWY` `INDA` | Taiwan, Korea, India. Like-kind *geography funds*, not like-kind with `SPY`. |
| **Rates / bond ETF** | **3** | `SGOV` `SHY` `BND` | Duration, not equity beta. Curve Quad-shaped (three rates funds). |
| **Commodity fund** | **3** | `GLD` `SLV` `USO` | Metal / oil. Not a company. Mixed-vol vs equities → Weighted if mixed. |
| **Private / special class** | **3** | `SPCX` `INFQ` `XNDU` | SpaceX Class A; Infleqtion; Xanadu. Confirm listing status before treating as public beta. |

---

## 4. Single-name / theme books (overlapping)

Operator groupings from the underlier’s business, not a GICS audit. Move a ticker when we lock a book.

| Class | n | Tickers | Notes |
|-------|---|---------|-------|
| **Magnificent 7-style mega cap** | **7** | `AAPL` `MSFT` `GOOGL` `AMZN` `META` `NVDA` `TSLA` | Distinct names → Weighted (or Orbital pairs). Not Curve Quad. |
| **Semiconductors & equipment** | **38** | `NVDA` `AVGO` `TSM` `AMD` `INTC` `MU` `AMAT` `LRCX` `KLAC` `ASML` `MRVL` `QCOM` `ON` `MPWR` `SMCI` `SNDK` `WDC` `TER` `ONTO` `ALAB` `CRDO` `AEIS` `AMKR` `AMBA` `COHR` `AEHR` `AXTI` `SIMO` `TSEM` `UMC` `SKHY` `MTSI` `MXL` `NVTS` `PENG` `POET` `CLS` `JBL` | Largest single-name theme. Add `SMH`/`SOXX` if the book may include ETFs (`n` becomes 40). |
| **Software / cloud / cybersecurity** | **26** | `MSFT` `ORCL` `NOW` `CRM` `ADBE` `INTU` `WDAY` `TEAM` `SNOW` `DDOG` `NET` `PANW` `CRWD` `ZS` `FTNT` `PATH` `MDB` `IBM` `CSCO` `CTSH` `FISV` `DOCN` `SHOP` `FIG` `ZM` `PLTR` | Weighted. |
| **Internet / platforms / consumer tech** | **14** | `AAPL` `GOOGL` `AMZN` `META` `NFLX` `SNAP` `RDDT` `RBLX` `APP` `TTD` `TTWO` `NU` `SOFI` `FUTU` | Overlaps Mag7. |
| **AI infrastructure** | **17** | `NVDA` `AVGO` `TSM` `AMD` `SMCI` `CRWV` `CBRS` `PLTR` `MSFT` `GOOGL` `AMZN` `ORCL` `SNOW` `NET` `APP` `SOUN` `TEM` | Overlaps Mag7 + semis + software. |
| **Quantum** | **6** | `IONQ` `RGTI` `QBTS` `QUBT` `INFQ` `XNDU` | Includes two specials (`INFQ` `XNDU`). |
| **Defense, aero, space** | **21** | `LMT` `LHX` `HII` `KTOS` `AXON` `BA` `GE` `HWM` `AVAV` `RKLB` `RDW` `LUNR` `JOBY` `ASTS` `SATS` `VSAT` `FLY` `RCAT` `OUST` `PL` `SPCX` | Includes `SPCX`. |
| **Autos / EV** | **4** | `TSLA` `RIVN` `F` `CVNA` | Small; Orbital/Weighted, not a 38-name dump. |
| **Energy / power / nuclear** | **14** | `XOM` `PR` `CEG` `VST` `GEV` `BE` `FLNC` `RUN` `SMR` `OKLO` `NNE` `TE` `VRT` `PWR` | Add `USO` if the book may include the oil fund (`n` becomes 15). |
| **Healthcare / biopharma** | **10** | `LLY` `JNJ` `PFE` `UNH` `MRNA` `ABCL` `IBRX` `SLS` `HIMS` `CELH` | `CELH` is stretch (consumer). |
| **Crypto-adjacent corporates** | **8** | `COIN` `MSTR` `CRCL` `IREN` `CLSK` `WULF` `GLXY` `BULL` | Equity beta to crypto, **not** USDe/USDG. |
| **Retail / consumer brands** | **7** | `COST` `LULU` `ELF` `CCL` `KSS` `AMC` `GME` | |
| **Non-US / ADR single names** | **8** | `BABA` `TSM` `ASML` `UMC` `SKHY` `FUTU` `TSEM` `NBIS` | Listing/HQ mix (NL, IL, TW, KR, CN). Not a clean “Asia only” book. |
| **High-narrative / retail flow** | **7** | `GME` `AMC` `DJT` `TSLA` `PLTR` `NVDA` `MSTR` | Flow cluster, not a sector. |

**Semiconductors + the two semi ETFs** (optional overlay): **40** = 38 names + `SMH` + `SOXX`.  
**Energy + `USO`:** **15**.

---

## 5. Count rollup (quick scan)

| Class | n |
|-------|---|
| Official universe | 194 |
| Single-name (base stocks) | 177 |
| Fund / ETF | 17 |
| Broad equity index ETF | 5 |
| Sector / theme ETF | 3 |
| Country / region ETF | 3 |
| Rates / bond ETF | 3 |
| Commodity fund | 3 |
| Private / special class | 3 |
| Magnificent 7-style mega cap | 7 |
| Semiconductors & equipment | 38 |
| Semiconductors + `SMH`/`SOXX` | 40 |
| Software / cloud / cybersecurity | 26 |
| Internet / platforms / consumer tech | 14 |
| AI infrastructure | 17 |
| Quantum | 6 |
| Defense, aero, space | 21 |
| Autos / EV | 4 |
| Energy / power / nuclear | 14 |
| Energy + `USO` | 15 |
| Healthcare / biopharma | 10 |
| Crypto-adjacent corporates | 8 |
| Retail / consumer brands | 7 |
| Non-US / ADR single names | 8 |
| High-narrative / retail flow | 7 |

---

## 6. Base (leaf) DETFs — suggested instances

**Leaf** means the `pairToken`s are **RHJ Stock Tokens** (or a fund token from this set), not another DETF. Nesting comes later.

These suggestions are **not locked**. Family law still applies:

| Family | External legs \(m\) | Valuation | All-bare? |
|--------|---------------------|-----------|-----------|
| Uni V4 SE **Weighted** | **1–7** | Distinct names / weights | **No** — ≥1 SE required |
| Uni V4 SE **Curve Quad** | **exactly 3** | Like-kind | **No** — ≥1 SE required |
| Uni V4 SE **Orbital** | **exactly 2** | Two distinct doors | **No** — ≥1 SE required |
| Uni V4 SE **CP Single** | **exactly 1** | One door | The one leg **is** the SE |

Weighted **cannot** list 8+ names. Themes with \(n > 7\) (semis 38, software 26, …) become a **core-7 subset** here. The leftover names are for later books or nesting, not one giant DETF.

### 6.1 “Bare book” pattern (what you asked for)

A Mag7-style Weighted instance is **seven stock tokens as the book**, not seven SE vaults. Product law still forbids **all-external-bare**.

**Default leaf pattern:** **1 SE + the rest bare.**

- `pairToken`s = the stock/ETF tokens themselves.
- **One** leg is SE-buffered: Uni V4 SE on that token vs **USDG** (the deep RH cash book). Optional rate provider: shares → that `pairToken`.
- Other legs: bare ERC-20 inventory on the hook.

That is the family’s first-class config (`1 SE + bare rest`). It is still a true Standard Exchange DETF. It is **not** “wrap every name.”

Pick the SE leg as the **most liquid name vs USDG** on 4663 (re-check before deploy). Working defaults below.

Do **not** use native ETH as a pool currency. Do **not** use explorer spoof tickers.

### 6.2 Sets of 7 — Weighted, 1 SE + 6 bare

Equal weights to start unless we later lock market-cap weights.

| Book | Family | m | pairTokens | SE on | Why |
|------|--------|---|------------|-------|-----|
| **Mag7** | Weighted | 7 | `AAPL` `MSFT` `GOOGL` `AMZN` `META` `NVDA` `TSLA` | `NVDA` or `AAPL` vs USDG | The obvious mega-cap book. Distinct names. |
| **High-narrative** | Weighted | 7 | `GME` `AMC` `DJT` `TSLA` `PLTR` `NVDA` `MSTR` | `NVDA` or `TSLA` vs USDG | Retail-flow cluster. Same family, different story. Overlaps Mag7 on `NVDA`/`TSLA`. |
| **Semi core-7** | Weighted | 7 | `NVDA` `AVGO` `TSM` `AMD` `INTC` `AMAT` `ASML` | `NVDA` vs USDG | Cannot list all 38 semis. These are the liquid mega/equipment names. |
| **Software core-7** | Weighted | 7 | `MSFT` `ORCL` `NOW` `CRM` `CRWD` `SNOW` `PLTR` | `MSFT` or `PLTR` vs USDG | Platform + SaaS + cyber + data. |
| **AI infra core-7** | Weighted | 7 | `NVDA` `AVGO` `TSM` `SMCI` `CRWV` `PLTR` `MSFT` | `NVDA` vs USDG | Overlaps Mag7/semis on purpose. |
| **Internet core-7** | Weighted | 7 | `AAPL` `GOOGL` `AMZN` `META` `NFLX` `SNAP` `RDDT` | `AAPL` or `GOOGL` vs USDG | Platforms + media. Drop `RBLX`/`APP`/`TTD` to hit 7. |
| **Defense core-7** | Weighted | 7 | `LMT` `LHX` `HII` `KTOS` `BA` `GE` `AXON` | `BA` or `LMT` vs USDG | Primes + defense-tech. Space names stay in a smaller book. |
| **Energy core-7** | Weighted | 7 | `XOM` `CEG` `VST` `GEV` `SMR` `OKLO` `BE` | `XOM` vs USDG | Oil + power + nuclear + fuel cells. |
| **Healthcare core-7** | Weighted | 7 | `LLY` `JNJ` `PFE` `UNH` `MRNA` `HIMS` `ABCL` | `LLY` or `UNH` vs USDG | Drop micro `IBRX`/`SLS` and stretch `CELH`. |
| **Crypto-adjacent core-7** | Weighted | 7 | `COIN` `MSTR` `CRCL` `GLXY` `IREN` `CLSK` `WULF` | `COIN` vs USDG | Drop `BULL`. Equity beta to crypto, **not** USDe. |
| **Retail-7** | Weighted | 7 | `COST` `LULU` `ELF` `CCL` `KSS` `AMC` `GME` | `COST` vs USDG | Theme is already size 7. |
| **Asia / ADR core-7** | Weighted | 7 | `BABA` `TSM` `ASML` `UMC` `SKHY` `FUTU` `TSEM` | `TSM` or `BABA` vs USDG | Drop `NBIS`. Mixed HQ; still one “non-US names” book. |

### 6.3 Sets of 6 / 4 / 3 distinct names — Weighted

| Book | Family | m | pairTokens | SE on | Why |
|------|--------|---|------------|-------|-----|
| **Quantum public-4** | Weighted | 4 | `IONQ` `RGTI` `QBTS` `QUBT` | `IONQ` vs USDG | Leave `INFQ`/`XNDU` out until listing is confirmed. |
| **Quantum-6** (if we accept specials) | Weighted | 6 | `IONQ` `RGTI` `QBTS` `QUBT` `INFQ` `XNDU` | `IONQ` vs USDG | Only if specials stay ACTIVE and transferable. |
| **Autos-4** | Weighted | 4 | `TSLA` `RIVN` `F` `CVNA` | `TSLA` vs USDG | Whole theme fits under 7. |
| **Tech fund-3** | Weighted | 3 | `XLK` `SMH` `SOXX` | `SMH` or `XLK` vs USDG | Same “tech funds” shelf, **not** like-kind enough for Curve Quad (`XLK` ≠ semi ETF). |
| **Commodity-3** | Weighted | 3 | `GLD` `SLV` `USO` | `GLD` vs USDG | Gold / silver / oil are distinct. Not Curve Quad. |
| **Private/special-3** | Weighted | 3 | `SPCX` `INFQ` `XNDU` | one vs USDG **if** a pool exists | Mixed stories (space + two quantum). Prefer skip until liquidity exists. |

### 6.4 Sets of 3 like-kind funds — Curve Quad, 1 SE + 2 bare

Only when the three underliers are the **same kind of object**.

| Book | Family | m | pairTokens | SE on | Why |
|------|--------|---|------------|-------|-----|
| **US equity index-3** | Curve Quad | 3 | `SPY` `VTI` `QQQ` | `SPY` vs USDG | Best like-kind fund book on the chain. |
| **Rates-3** | Curve Quad | 3 | `SGOV` `SHY` `BND` | `SGOV` vs USDG | Same object: USD duration. |
| **Country fund-3** | Curve Quad | 3 | `EWT` `EWY` `INDA` | `EWT` vs USDG | Same object: single-country equity ETF. |

Do **not** Curve-Quad `SPY`+`NVDA`+anything. Do **not** Curve-Quad Mag7 names (distinct companies).

Optional later: a **semi name-3** Curve Quad (`NVDA` `TSM` `AVGO`) only if we accept “same sector ≈ like-kind.” Default: keep those names in **Semi core-7 Weighted**.

### 6.5 Sets of 2 — Orbital, 1 SE + 1 bare

| Book | Family | m | pairTokens | SE on | Why |
|------|--------|---|------------|-------|-----|
| **Name + its ETF** | Orbital | 2 | `NVDA` `SMH` | `NVDA` vs USDG | Single name vs the sector fund. |
| **Two index funds** | Orbital | 2 | `SPY` `QQQ` | `SPY` vs USDG | If we do not want the third (`VTI`) in the index Curve Quad. |
| **Precious metals** | Orbital | 2 | `GLD` `SLV` | `GLD` vs USDG | Tighter than adding `USO`. |
| **Two crypto equities** | Orbital | 2 | `COIN` `MSTR` | `COIN` vs USDG | Exchange vs treasury-proxy. |
| **Two autos** | Orbital | 2 | `TSLA` `RIVN` | `TSLA` vs USDG | If Autos-4 is too wide. |
| **Two defense** | Orbital | 2 | `LMT` `KTOS` | `LMT` vs USDG | Prime vs defense-tech. |

### 6.6 Sets of 1 — CP Single

The one external leg **is** the SE (DETF raw ↔ that `pairToken`).

| Book | Family | m | pairToken | SE | Why |
|------|--------|---|-----------|-----|-----|
| **NVDA single** | CP Single | 1 | `NVDA` | Uni V4 SE `NVDA`/USDG | Hero single-name. |
| **SPY single** | CP Single | 1 | `SPY` | Uni V4 SE `SPY`/USDG | Hero index. |
| **TSLA single** | CP Single | 1 | `TSLA` | Uni V4 SE `TSLA`/USDG | Hero consumer/EV. |
| **COIN single** | CP Single | 1 | `COIN` | Uni V4 SE `COIN`/USDG | Hero crypto-equity. |

Useful as **demo atoms** and later as nestable leaves. Not a substitute for Mag7.

### 6.6a First-cut priority (if we only ship a few)

Ship these first; they teach every family without exploding combinatorial books:

1. **Mag7 Weighted** (7 bare-style names, 1 SE)
2. **US equity index-3 Curve Quad** (`SPY` `VTI` `QQQ`)
3. **Rates-3 Curve Quad** (`SGOV` `SHY` `BND`)
4. **NVDA + SMH Orbital**
5. **NVDA CP Single** and/or **SPY CP Single**

Then Semi core-7 / Software core-7 / High-narrative if we want more Weighted skins.

### 6.6b Do not make a single base DETF

| Theme | n | Why not one instance |
|-------|---|----------------------|
| All single-names | 177 | Weighted max \(m=7\) |
| All funds | 17 | Same cap; also mixed kinds (equity vs bonds vs oil) |
| Full semis / software / defense / AI | 38 / 26 / 21 / 17 | Subset to core-7 (or later nest several core books) |

---

## 7. Nesting over the locked showcase DETFs

**Leaves (PRD D27, inert):**

| Id | Family | Stand-in book |
|----|--------|----------------|
| **S** | CP Single | `TTNVDA` |
| **O** | Orbital | `TTNVDA` + `TTSMH` |
| **Q** | Curve Quad | `TTSPY` `TTVTI` `TTQQQ` |
| **W** | Weighted | Mag7 `TTAAPL`…`TTTSLA` |

An outer DETF’s `pairToken`s are those inner **`detfToken`s** (the diamonds), not the leaf `TT*` again. Nested SE / DETF-as-vault is allowed and must stay opaque (`IStandardExchange*` only).

These four inners are **not like-kind**. They are four different books (one name, name+ETF, three index funds, seven stocks). So:

- **Weighted or Orbital** over them — yes.
- **Curve Quad** of {S, O, Q} or any three of the four — **no** (operator like-kind convention).
- Same **≥1 SE** rule: 1 SE + rest bare. Default SE = Uni V4 pool of the most liquid inner `detfToken` vs `TTUSDG` (or bind that inner as the SE if we use DETF-as-vault).

Outers stay **inert** until the inners are live (D5). First bond of an outer needs all listed inner `detfToken`s in size.

### 7.1 Recommended outers (over D27 only)

| Book | Outer family | m | Inner legs | SE on | Why |
|------|--------------|---|------------|-------|-----|
| **Showcase nest** | Weighted | 4 | S + O + Q + W | W vs `TTUSDG` | One book that *is* the type exhibit: all four families as doors. Distinct valuations. |
| **Beta nest** | Orbital | 2 | W + Q | W vs `TTUSDG` | Mag7 names vs the US index basket. The cleanest two-door story. |
| **Name-in-basket** | Orbital | 2 | S + W | S vs `TTUSDG` | `TTNVDA` Single vs the Mag7 book that already contains `TTNVDA`. Teaches overlap without Quad. |
| **Index wrap** | CP Single | 1 | Q | Q **is** the SE (or Q / `TTUSDG`) | DETF-of-a-DETF atom. Simplest nest. |
| **Mag7 wrap** | CP Single | 1 | W | W **is** the SE | Same atom on the stock book. |

**46630 locked (PRD D30, group 07):** Showcase nest, Beta nest, Index wrap, Mag7 wrap. Name-in-basket is **not** in that set. No nested Quad.

### 7.2 What we cannot nest yet (need more leaves)

| Wanted outer | Family | Missing inners |
|--------------|--------|----------------|
| Fund-DETF Quad | Curve Quad | Two more like-kind Quads, e.g. Rates-3 (`TT` SGOV/SHY/BND) + Country-3 (`TT` EWT/EWY/INDA) |
| Theme Weighted of Weighteds | Weighted | Semi core-7, Software core-7, … as extra W-leaves |
| Name + its ETF at DETF layer | Orbital | Already have O; nesting S + a **SMH Single** would need a fifth leaf |

### 7.3 Copy / law reminders

- Outer copy: exposure to **inner DETF shares**, which themselves are exposure to stand-in underliers — not “you own the Mag7.”
- Do not treat inner `detfToken` as `rateAsset` of the whole outer book (Weighted/Quad are per-route).
- Do not list the same inner DETF twice. Do not list an outer as a leg of itself.
- Pair tokens pairwise distinct; ≥1 SE; no native ETH.

**Copy:** economic exposure to the underlier via an RHJ debt token — not “you own Apple.” (Leaf copy.) Outer copy names the **inner DETF**, not the leaf tickers.

---

## 8. Sources

- [RHJ Stock Tokens](https://robinhood.com/rhj/stocktokens/) — 1:1 custody claim, multiplier dividends, AP/secondary, insolvency agent
- [Stock Tokens (dev docs)](https://docs.robinhood.com/chain/stock-tokens/) — ERC-20, no rights in the equity issuer, AP mint
- [Stock Token APIs](https://docs.robinhood.com/chain/stock-token-apis/) — `GET https://api.robinhood.com/rhj/assets`
- Crane `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol` (`RH_*`, `RH_STOCK_TOKEN_COUNT = 194`)

Re-fetch `/rhj/assets` before pinning a book. Tickers above are operator labels on that 2026-08-15 snapshot.

---

## 9. Next time we open this

- **46630 showcase locked** in [`docs/ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_PRD.md`](../ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_PRD.md) **D27–D29** (v1.2): Single `TTNVDA`, Orbital `TTNVDA`+`TTSMH`, Index Quad `TTSPY`/`TTVTI`/`TTQQQ`, Mag7 Weighted. Other §6 books stay mainnet *could*.
- Confirm which name vs USDG actually has a Uni V4 pool for the single SE leg.
- Confirm `SPCX` / `INFQ` / `XNDU` listing status before Quantum-6 or Private-3.
- Confirm `uiMultiplier` / pause / confiscate on a sample token before wiring as `pairToken`.
- **Then** nest base DETFs. Do not design outer books until Mag7 + Index-3 + one Single exist as leaves.
- 46630 has **no** official RHJ Stock Tokens — any demo of this matrix needs stand-ins or a 4663 fork, not the 46630 faux-dollar path (D26).
