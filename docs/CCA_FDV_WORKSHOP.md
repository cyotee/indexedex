# CCA FDV Workshop — Decision Record

**Status:** **LOCKED** (2026-07-22)  
**Scope:** Base public CCA for **RICH** (10% of 1B supply, ETH quote)  
**Normative launch plan:** [`LAUNCH_PLAN.md`](./LAUNCH_PLAN.md)  
**CCA configurator reference:** Uniswap CCA skills (floor Q96, tick spacing, supply schedule)

---

## 1. Purpose

Set an **independent** CCA floor and public FDV optics **before** RICHAI (Bankr), so:

1. Uniswap CCA can be configured with a real `floorPrice` + tick spacing.  
2. Announcement copy can cite **floor / implied FDV** without inventing a raise forecast.  
3. Proceeds allocation (ops vs liquidity) matches founder runway needs.

This record is the source of truth for pricing. Do not re-open without an explicit decision-log update.

---

## 2. Workshop inputs (accepted)

| Input | Value |
|-------|--------|
| ETH print (workshop) | **$1,900** — label in all USD optics as workshop assumption |
| Founder ops need | **≥ $12,000** until RICHAI vesting is useful |
| Max public FDV at floor | **Under ~$5M** (ceiling, not target) |
| Min raise / graduation | **`requiredCurrencyRaised = 0`** (always settle) |
| Auction supply | **100,000,000 RICH** (10% of **1,000,000,000**) |
| Quote asset | **ETH** (native / WETH as CCA requires) |
| Venue | **Base** public CCA |

---

## 3. Locked decisions

### 3.1 Floor and FDV

| Param | Locked value |
|-------|----------------|
| **Floor** | **\(5 \times 10^{-7}\) ETH per RICH** (0.0000005 ETH / RICH) |
| **Implied FDV at floor** | **500 ETH** ≈ **$950,000** @ $1,900 |
| **Public FDV language** | “FDV at floor ~**$1M**” (or “~$950k at workshop ETH $1,900”); ETH-primary numbers preferred in technical docs |
| **FDV ceiling (comfort)** | Stay **under ~$5M** at floor (floor max ≈ \(2.63 \times 10^{-6}\) ETH/RICH) — **not** the chosen floor |

**Identity (full sell of 100M at constant floor):**

\[
\text{raise} = \text{floor} \times 10^{8},\quad
\text{FDV} = \text{floor} \times 10^{9} = 10 \times \text{raise}
\]

| At locked floor, if… | ETH | ≈ USD @ $1,900 |
|----------------------|-----|----------------|
| Full 100M sells at floor | **50** raise | **~$95k** |
| FDV (1B × floor) | **500** | **~$950k** |
| 1M RICH at floor | **0.5** | **~$950** |

Clearing **above** floor raises more ETH and implies a higher mark; floor is min price + optics, not expected clear.

### 3.2 Raise planning bands (not promises)

| Band | ETH | ≈ USD @ $1,900 | Role |
|------|-----|----------------|------|
| **Success (planning)** | **50** | ~$95k | Aligns with full-sell-at-floor identity |
| **Stretch** | **100** | ~$190k | Upside; not a failure if missed |
| **Do not promise** | any | any | Public copy must not guarantee raise size |

### 3.3 Proceeds allocation

| Bucket | Locked | Notes |
|--------|--------|--------|
| **Founder ops** | **~6.5 ETH** (~$12.4k @ $1,900) | Supersedes prior **~15 ETH (~$20k)** ops line |
| **Liquidity / product** | **Remainder of proceeds** | Post-CCA Uni / DualLiquidity seed sized at **runtime** |
| **On-chain min raise** | **0** | Soft ops target only; thin auction may yield &lt; 6.5 ETH |

**Proceeds recipient (unchanged):** `0xeD1FA21329fc45860cAB5D5E26a5fafcCDAcd6D5`

### 3.4 CCA operational knobs (from workshop)

| Param | Locked / default |
|-------|------------------|
| Duration | **~5 days** public clearing (Base ~2s blocks → on the order of **~216,000** blocks; exact start/end at deploy) |
| Supply curve | **Back-loaded / convex** (Uniswap CCA configurator standard schedule OK) |
| Tick spacing | **1% of floor** (round floor down so floor % tickSpacing == 0) |
| `requiredCurrencyRaised` | **0** |
| Prebid | **0** unless launch-week marketing wants a short window (optional; not locked) |
| Tokens / funds recipient | Same proceeds wallet unless ops splits later |

### 3.5 Fee-make / RICH value proposition (messaging) — clarified 2026-07-26

**Primary long-term VP for RICH (alongside CCA capital formation):** protocol design routes **fees from other vaults and DETFs** into **`donation` that makes RICH liquidity**. Launch fee sink = **SingleVault DETF for RICH** — that DETF **accrues** those donations (buyback-and-make) — not a fixed cash dividend on free-floating RICH.

**Publishable now (roadmap until donation live):**

> **RICH** is IndexedEx’s capital token. The Base CCA is **capital formation and price discovery** for 10% of supply. Long-term, fees from other vaults and DETFs are **donated into RICH liquidity** through a **SingleVault DETF** for RICH — value as **liquidity make**, not a fixed cash dividend.

**Do not claim until live:** measured on-chain fee → donation → RICH pool / sink-DETF TVL, or any APR.

CCA open is **not** gated on `donation` shipping; fee-make remains the primary **roadmap** structural story for RICH after the raise.

---

## 4. Human-scale floor table

| Unit | At floor |
|------|----------|
| 1 RICH | \(5 \times 10^{-7}\) ETH ≈ **$0.00000095** |
| 1M RICH | **0.5 ETH** ≈ **$950** |
| 100M RICH (full CCA tranche at floor) | **50 ETH** ≈ **$95k** |
| 1B RICH (FDV) | **500 ETH** ≈ **$950k** |

---

## 5. Q96 notes (for configurator / deploy)

ETH and RICH both **18 decimals** → no decimal adjustment:

\[
\text{floorPrice}_{\mathrm{raw}} = 2^{96} \times 5 \times 10^{-7}
\]

\[
2^{96} = 79228162514264337593543950336
\]

\[
\text{floorPrice}_{\mathrm{raw}} = 39614081257132168796771975.168\ \text{(not integer — use floor of product in integer math)}
\]

**Deploy rule:** compute with integer math, set `tickSpacing = floorPrice / 100` (1%), then:

```text
roundedFloorPrice = (floorPrice // tickSpacing) * tickSpacing
assert roundedFloorPrice % tickSpacing == 0
```

Exact on-chain integers are generated at CCA config time (Uniswap CCA configurator skill); this workshop locks the **human ratio**, not a hand-copied Q96 blob.

---

## 6. Risks and copy rules

| Risk | Mitigation |
|------|------------|
| Thin demand, raise &lt; 6.5 ETH | Min raise = 0; ops allocation is soft; do not promise $12k in public |
| USD optics drift if ETH moves | Prefer ETH numbers; refresh USD only as “at ETH=$X” |
| Confusing floor FDV with expected mcap | Always say “at floor” / “implied fully diluted at floor” |
| Fee-make overclaim | Roadmap language only until `donation` → RICH liquidity is live; no cash APR |
| Aztec-scale expectations | Explicit non-goal; success band is tens of ETH, not tens of millions USD |

---

## 7. Next steps (after this record)

1. **[x] CCA parameter sheet** — [`CCA_PARAMETER_SHEET.md`](./CCA_PARAMETER_SHEET.md) + [`cca/base-rich-cca-config.json`](./cca/base-rich-cca-config.json).  
2. **RICH deploy** on Ethereum via Crane `ERC20PermitDFPkg` (1B fixed).  
3. **Bridge 100M** to Base (canonical Superchain); patch config `token`.  
4. Fill `startBlock` / `endBlock` / `claimBlock`; configure + open **Base CCA**.  
5. Announcement + bidder checklist; Gitlawb small test; **BattleChain testnet** Crane + protocol-port promo (parallel).  
6. Parallel eng: `donation` fee-make for roadmap delivery.

---

## 8. Supersessions

| Prior | New |
|-------|-----|
| Proceeds ops **~15 ETH (~$20k)** | **~6.5 ETH (~$12k @ $1,900)**; rest liquidity |
| CCA floor / FDV **open workshop** | Floor **\(5\times10^{-7}\) ETH/RICH**; FDV at floor **~500 ETH / ~$950k** |
| FDV “not set” (2026-07-17) | **Set** 2026-07-22 |

---

*Workshop completed 2026-07-22. Update this file and `LAUNCH_PLAN.md` §6 if any pricing decision changes.*
