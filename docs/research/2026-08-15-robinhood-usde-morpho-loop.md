# Robinhood Chain mainnet — USDe / Morpho loop

**Status:** Research note — 2026-08-15  
**Chain:** Robinhood Chain mainnet, chain id **4663**  
**Purpose:** Record how the **USDe ↔ USDG Morpho loop** actually works (who lends, who borrows, who can mint), so we can revisit **strategy and integration** later (SE legs, DETF `pairToken`s, rate providers, Morpho as a host — none decided).  
**Not:** a locked product decision, deploy plan, token allowlist, or an instruction to loop.

**Related:**

- [`2026-08-15-robinhood-mainnet-usd-and-vault-tokens.md`](./2026-08-15-robinhood-mainnet-usd-and-vault-tokens.md) — USDG vs USDe vs receipts
- [`docs/ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_PRD.md`](../ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_PRD.md) — 46630 rehearsal (no official USDG / no this loop)
- Crane `ROBINHOOD_MAIN.sol` (Morpho Blue + Vault V2 + Bundler3 pins)
- Crane Morpho skills (`crane-morpho`, `morpho-blue-operations`, `morpho-vaults`)

Live sizes below are a **2026-08-15 Morpho Blue API snapshot**. Re-read on-chain before any integration.

---

## 1. One-line picture

Robinhood Earn is a **USDG lending vault**. The popular “USDe Morpho loop” is the **other side** of that vault: professional borrowers post **USDe** (and two USDG receipts) as collateral, borrow **USDG**, and — if they are Ethena mint users — **remint USDe at 0 fee** and repeat.

```text
Retail (Robinhood app)
    USDG  --deposit-->  steakUSDG  (Steakhouse Morpho Vault V2)
                              |
                              v
                    Morpho isolated markets
         USDe / USDG     syrupUSDG / USDG     spUSDG / USDG
                              ^
                              |
Looper (MM / AP / anyone with USDe)
    USDe  --collateral-->  borrow USDG  --mint/buy USDe-->  more collateral
```

That is why **USDe/USDG** is a real AMM and Morpho book, and why **USDe/WETH** is dust: the loop never needs ETH. See the USD-token note.

---

## 2. Two products, one credit book

Do not conflate the app product with the loop.

| Side | Who | What they hold | What they earn / pay | Can they mint USDe? |
|------|-----|----------------|----------------------|---------------------|
| **Earn (lender)** | Eligible Robinhood retail | `steakUSDG` vault share | Vault APY + (today) a **Merkl-style subsidy** toward the advertised ~7% | No |
| **Market (borrower / looper)** | Anyone who can post collateral; remint is **KYC/KYB mint users only** | USDe (or syrupUSDG / spUSDG) + a USDG debt | Pays Morpho **borrow APY**; hopes USDe carry / points / inventory > that rate | Only if they are an Ethena **mint user** |

Steakhouse (1 Jul 2026) listed the Earn vault’s three launch collateral markets as **USDe**, **syrupUSDG** (Maple), **spUSDG** (Spark). Other collaterals may be added under their published risk framework.

Robinhood’s ~**7% APY** is the **app headline for lenders**. On 2026-08-15 the **on-chain** Steakhouse USDG vault APY was ~**3.07%**. FalconX (20 Jul 2026) already noted the gap and a Merkl campaign estimated to support ~7% up to roughly **$2B** vault TVL. Treat 7% as **subsidized / variable**, not as Morpho’s natural borrow demand.

Lloyd’s / RELM cover advertised for Earn is **cyber / smart-contract exploit** (Robinhood as policyholder). It is **not** depeg, liquidation, utilization lockup, or “the 7% is guaranteed.”

---

## 3. On-chain map (4663, 2026-08-15)

### 3.1 Tokens (from the USD-token note)

| Role | Token | Address | Decimals |
|------|-------|---------|----------|
| Official chain cash / Morpho **loan asset** | **USDG** | `0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168` | 6 |
| Synthetic dollar / main **collateral** | **USDe** | `0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34` | 18 |
| Earn vault share | **steakUSDG** | `0xBeEff033F34C046626B8D0A041844C5d1A5409dd` | (vault share) |
| Maple receipt collateral | **syrupUSDG** | `0x40858070814a57FdF33a613ae84fE0a8b4a874f7` | 6 |
| Spark receipt collateral | **spUSDG** | `0xde770c84FE66E063336b31737cFE9790f18c4087` | 6 |
| Staked USDe (thin on 4663) | **sUSDe** | `0x211Cc4DD073734dA055fbF44a2b4667d5E5fE5d2` | 18 |

`steakUSDG` / `syrupUSDG` / `spUSDG` are **receipts**, not $1 cash.

### 3.2 Protocol pins (Crane `ROBINHOOD_MAIN`)

Morpho is **already listed** on 4663 (Blue + Vault V2 + Bundler3). No MetaMorpho V1 / URD on the Morpho docs tab Crane transcribed.

| Constant | Address |
|----------|---------|
| `MORPHO` / `MORPHO_BLUE` | `0x9D53d5E3bd5E8d4Cbfa6DB1ca238AEA02E651010` |
| `MORPHO_ADAPTIVE_CURVE_IRM` | `0x2BD3d5965B26B51814AC95127B2b80dD6CcC0fa1` |
| `MORPHO_VAULT_V2_FACTORY` | `0x0FBad98595e0186dA120E41f77C102beb49f803c` |
| `MORPHO_BUNDLER3` | `0x6478e9393d4C5bB4d53ee881d1DE78786A0344a6` |

### 3.3 Vaults that matter

| Vault | Address | Asset | TVL (USD) | On-chain APY | Idle / withdrawable liq. | Share price |
|-------|---------|-------|-----------|--------------|--------------------------|-------------|
| **Steakhouse USDG** (`steakUSDG`) — Earn | `0xBeEff033F34C046626B8D0A041844C5d1A5409dd` | USDG | **~$348.7M** | ~3.07% | idle ~$10.0M / liq. ~$36.9M | ~1.0040 |
| **Ethena × Steakhouse USDG** (`ethenaUSDG`) | `0xbEeFF0fb1Dc19344A87b8479dAb60A2e16160737` | USDG | **~$50.2M** | ~3.18% | idle ~$4.9k / liq. ~$26.9M | ~1.0035 |

Same curator (`0x9023FBD6A08C666491A2d1648737E400cF42D2Fb`). The Ethena-branded vault is a **second USDG lender** into the same USDe market shape, not a USDe vault.

### 3.4 Isolated Morpho markets (loan asset = USDG)

| Market id | Collateral | LLTV | Supply | Borrow | Util. | Supply APY | Borrow APY | Free liq. | Fed by |
|-----------|------------|------|--------|--------|-------|------------|------------|-----------|--------|
| `0xc845da65…ddd6` | **USDe** | **91.5%** | **~$272.0M** | **~$245.1M** | **90.1%** | ~3.18% | ~3.53% | ~$26.9M | Steakhouse USDG |
| `0x1cef8d4d…396b` | USDe | 96.5% | ~$1 | ~$0.91 | 91.0% | ~5.82% | ~6.42% | dust | — |
| `0x919a9b6b…61c7` | **syrupUSDG** | 91.5% | ~$83.2M | ~$75.1M | 90.2% | ~3.64% | ~4.04% | ~$8.2M | Steakhouse USDG |
| `0x0309c02d…4114` | **spUSDG** | 91.5% | ~$35.8M | ~$29.6M | 82.6% | ~1.98% | ~2.40% | ~$6.2M | Steakhouse USDG |
| `0x6c023a68…fbc0` | spUSDG | 91.5% | ~$2.71 | 0 | 0 | 0 | ~0.52% | dust | — |

**USDe is the dominant Earn collateral** (~$245M borrowed vs ~$75M Maple vs ~$30M Spark). That matches Ethena’s “primary collateral issuer” claim and FalconX’s July note that most on-chain USDe sat in Morpho.

WETH/USDG Morpho exists and is **tiny** (~$1.5M supply / ~$75k borrow). Confirms: USDG-for-ETH leverage is not this product.

---

## 4. The loop, step by step

### 4.1 What “looping” means here

A **like-kind leverage loop** on two dollars:

```text
1. Acquire USDe          (mint if AP, else buy USDe/USDG)
2. supplyCollateral      USDe into Morpho market 0xc845da65…
3. borrow                USDG up to LLTV (91.5% advertised max)
4. Turn USDG into USDe   (0-fee mint if AP; else swap on USDe/USDG)
5. Repeat 2–4            until health-factor buffer is hit
6. Optional              stake leftover free USDe as sUSDe (thin on 4663)
```

Theoretical max notional if they always remint at 1:1 and hit 91.5% LLTV:

\[
\frac{1}{1 - 0.915} \approx 11.8\times
\]

Nobody well-run sits on the LLTV. The live book is ~90% **utilization** (lenders almost fully lent), which is a different number from a given borrower’s LTV.

### 4.2 Why it became “popular” in July 2026

Three things stacked:

1. **Retail USDG supply** — Earn dumps hundreds of millions of USDG into Steakhouse Vault V2, which reallocates into the three markets. That is cheap, sticky borrowable cash.
2. **High LLTV on a dollar/dollar book** — 91.5% is only sane if the curator treats USDe ≈ USDG. That is a **peg / oracle** assumption, not a law of nature.
3. **0 bps mint/redeem** (9 Jul 2026) — Ethena set mint/redeem fees to **0** for stables including **USDC and USDG**, for **onboarded mint users** (KYC/KYB + Mint User Agreement). FalconX: looping Coinbase and Robinhood Morpho vaults is then **cost-free at mint and redemption**.

Without (3), each loop lap paid a mint fee and the carry died. With (3), the remaining cost is **Morpho borrow APY + any secondary-market slippage**.

### 4.3 Permissioned mint vs permissionless Morpho

This is easy to get wrong:

- **Morpho supply / borrow** is a normal on-chain market. Anyone with USDe can loop **if** they can get more USDe.
- **Ethena mint/redeem** is **not** public. Crypto Briefing (9 Jul 2026): only mint users who signed the agreement get 0-fee conversion. Everyone else buys/sells on **secondary** (CEX, Uniswap USDe/USDG, etc.).

So there are two loop qualities:

| Looper | USDG → USDe leg | Friction |
|--------|-----------------|----------|
| Ethena mint user (MM / desk) | Primary mint | ~0 bps + inventory / KYC |
| Permissionless user | USDe/USDG AMM | Slippage on a ~$1M Uni V4 book (plus thinner venues) |

The **size** of the $245M borrow book is the first group. The AMM exists so the second group and the peg can still move.

### 4.4 Sibling pattern (Coinbase / Base)

Same stack, different cash token:

- Coinbase **High Yield USDC** vault (Jun 2026): Morpho + Steakhouse, collateral includes Ethena-powered assets.
- Coinbase **Prime** vault: USDC vs BTC/ETH (blue-chip), lower yield.
- Ethena × Steakhouse **USDC** vault on Base is the named sibling of `ethenaUSDG` on 4663.

Robinhood Earn is closer to Coinbase **High Yield** (Ethena collateral) than to Prime. There is **no** large WETH-collateral Earn market on 4663.

---

## 5. Economics (do not invent a carry)

As of this snapshot, a **naked** USDe/USDG loop **pays** ~**3.53%** borrow APY. It is **not** automatically +7%.

A looper only makes money if some **other** cashflow exceeds that borrow rate, for example:

- sUSDe / Ethena funding carry (variable; negative-funding days exist — see USD-token note / Ethena funding-risk docs)
- Points / incentives (Ethena, Morpho, Merkl, campaign tokens)
- Inventory / market-making (they needed USDG or USDe anyway)
- Receipt loops: syrupUSDG yield (~Maple credit) minus ~4.04% borrow — **different** risk (institutional credit, not synthetic dollar)

**Do not** write UI copy that “the loop pays 7%.” The 7% is the **lender-side advertised** rate, and even that is above the ~3% on-chain vault APY.

Lender-side liquidity is already tight relative to TVL: Steakhouse USDG ~$349M TVL vs ~$37M withdrawable. High utilization is the design. Withdrawals can queue when loopers are fully drawn.

---

## 6. Risks (return here before any strategy)

| Risk | Where it sits | Notes |
|------|----------------|-------|
| **USDe peg / oracle** | Morpho LLTV 91.5% assumes USDe ≈ $1 vs USDG | Oct 2025 Binance printed $0.65 (CEX book; on-chain nearer $1). A bad oracle print **liquidates** the loop even if mint/redeem is fine. |
| **Synthetic / funding** | USDe backing | Delta-neutral basis trade. Breaks on crowded hedge unwind, not on a Paxos bank. |
| **Mint permissioning** | Unwind | If mint users cannot redeem USDG↔USDe in size, unwind hits the thin AMM. |
| **Utilization / exit** | Earn depositors **and** loopers | ~90% util. Lenders may not withdraw instantly. Loopers may not borrow more to roll. |
| **Bad debt** | Isolated market | If USDe collateral cannot cover USDG debt after liq, Steakhouse said the shortfall stays in the market and lender balances can fall. |
| **Receipt collateral** | syrupUSDG / spUSDG | Credit + share-price risk on top of USDG. Not the same as USDe. |
| **Subsidy fade** | 7% headline | Merkl / acquisition spend can stop. On-chain APY is the residual. |
| **Insurance mismatch** | Earn marketing | Lloyd’s/RELM ≠ loop solvency ≠ depeg. |
| **Bybit-class hedge venue** | USDe reserves | Feb 2025: Ethena said ~$30M derivatives exposure, solvent, off-exchange custody. |
| **Kelp-class collateral contagion** | If a listed collateral is the hacked asset | Apr 2026: Ethena **paused rsETH** in *its* vaults after KelpDAO. Different chain, same lesson. |

No USDe **protocol drain** is required to blow up a 91.5% LLTV dollar/dollar book. A short oracle dislocation is enough.

---

## 7. How this maps to IndexedEx roles (for later)

Keep DETF role names. Do **not** call any of this RICH / “the stable.”

| External piece | Likely role if we touch it | Not |
|----------------|----------------------------|-----|
| USDG | `rateAsset` or `pairToken` (cash / loan asset) | Receipt |
| USDe | `pairToken` (second dollar-like leg) | Same risk as USDG |
| steakUSDG | Possible SE `vaultShare` or yield-bearing `pairToken` **after** ERC-4626 / pause / decimal review | `rateAsset` |
| syrupUSDG / spUSDG | Same as steakUSDG, plus Maple/Spark credit | “another stable” |
| Morpho USDe/USDG market | Isolated lending pair (collateral, debt) — **not** a Uni V4 pool | An SE host unless we deliberately wrap it |
| Morpho borrow position | A **strategy**, not a DETF reserve | Something we “just list” |

Weird-token law still applies. Receipts may be ERC-4626-like, have share-price drift, or pause. **Verify each contract** before wiring.

Crane already vendors Morpho Blue and has RH mainnet constants. That is **not** the same as “IndexedEx should loop.”

---

## 8. Integration / strategy potential (open — return later)

Not decided. Candidates to investigate, in increasing commitment:

1. **Do nothing on Morpho.** Use the loop only as **context**: why USDe/USDG exists, why USDe/WETH does not, why steakUSDG TVL is large.
2. **DETF legs** that list **USDG + USDe** as like-kind `pairToken`s (Curve Quad still needs a **third** like-kind dollar — a receipt or a demo faux stable). Fiat vs synthetic synergy, not ETH.
3. **SE wrapping steakUSDG** (or ethenaUSDG) so a DETF external leg is “Earn USDG” with a **rate provider** on share price. Token-policy + pause + liquidity review first.
4. **SE or strategy that is the looper** — supply USDe, borrow USDG, remint. This is a **levered basis / points** product. Needs its own PRD: health factor, oracle, unwind, who is the mint user, who holds the keys. **Out of scope** for the 46630 Uni V4 demo.
5. **Do not** promise Earn APY, loop APY, or Lloyd’s cover in IndexedEx UI.
6. **46630** cannot replay this loop: no official USDG, no official USDe mint, and this research did not confirm the Steakhouse vault on testnet. Demo faux stables ≠ this credit book.

---

## 9. Sources

- Steakhouse, [Robinhood Charts a New Course Onchain](https://kitchen.steakhouse.financial/p/robinhood-charts-a-new-course-onchain) (1 Jul 2026) — three launch collaterals; curator vs product; bad-debt and liquidity risks
- Morpho, [Robinhood Chooses Morpho to Power New Earn Product](https://morpho.org/blog/robinhood-chooses-morpho-to-power-new-earn-product) (1 Jul 2026)
- Robinhood, [Earn](https://robinhood.com/us/en/crypto/earn/) and [support](https://robinhood.com/us/en/support/articles/crypto-earn/) — 7% estimate, Privy wallet, Morpho independent, withdraw vs vault liquidity
- FalconX, [Robinhood Chain Primer](https://www.falconx.io/newsroom/robinhood-chain-primer-early-traction-and-protocols-to-watch) (20 Jul 2026) — USDe in Morpho; 0-fee mint; 7% vs ~2% on-chain; Merkl
- Ethena (9 Jul 2026) via FalconX / [Crypto Briefing](https://cryptobriefing.com/ethena-free-usde-usdc-minting-redemption/) — 0 bps mint/redeem for **mint users**; not public
- Morpho Blue API (2026-08-15) — vault and market sizes in §3
- Coinbase / Steakhouse High Yield USDC (Jun 2026) — sibling pattern on Base
- Crane `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol`
- Sibling note: [`2026-08-15-robinhood-mainnet-usd-and-vault-tokens.md`](./2026-08-15-robinhood-mainnet-usd-and-vault-tokens.md)

Re-verify addresses, LLTVs, utilization, and mint-user policy before any deploy or tokenlist pin.

---

## 10. Next time we open this

- Confirm steakUSDG / ethenaUSDG **ERC-4626** (or Vault V2 share) surface, decimals, pause, and whether either is rebasing.
- Read Steakhouse **caps / adapters** on `0xBeEff033…` (allocation to the three markets).
- Confirm the **oracle** on market `0xc845da65…` (what marks USDe vs USDG).
- Decide whether we care about **lender** (steakUSDG as `vaultShare`) or **borrower** (loop strategy) or **only the two dollars as DETF legs**.
- Check whether Morpho + these markets exist on **46630** (almost certainly not in this form).
- Do **not** hardcode the 7% or the 3.53% borrow rate.
