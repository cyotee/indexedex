# Base CCA Parameter Sheet — RICH

**Status:** Draft ready for deploy (token address **placeholder**)  
**Date:** 2026-07-22  
**Pricing source:** [`CCA_FDV_WORKSHOP.md`](./CCA_FDV_WORKSHOP.md)  
**Launch plan:** [`LAUNCH_PLAN.md`](./LAUNCH_PLAN.md)  
**Machine config:** [`cca/base-rich-cca-config.json`](./cca/base-rich-cca-config.json)

---

## 1. Intent

Configure a **public Uniswap Continuous Clearing Auction on Base** for **100M RICH** (10% of 1B), ETH quote, ~5-day back-loaded supply, floor locked in the FDV workshop.

**Do not broadcast until:**

1. RICH is deployed on Ethereum via Crane `ERC20PermitDFPkg` (1B fixed).  
2. **100M** is bridged to Base (canonical Superchain).  
3. `token` in the JSON is the **Base** RICH address.  
4. `startBlock` / `endBlock` / `claimBlock` are filled from live Base tip + chosen open buffer.

---

## 2. Network and factory

| Item | Value |
|------|--------|
| Chain | **Base** |
| Chain ID | **8453** |
| Block time (assumed) | **~2s** |
| CCA factory (v1.1.0, recommended) | **`0xCCccCcCAE7503Cac057829BF2811De42E16e0bD5`** |
| Factory bytecode on Base | **Verified non-empty** (2026-07-22 smoke) |
| Quote currency | **Native ETH** → `0x0000000000000000000000000000000000000000` |
| Auction UI | https://cca.uniswap.org/ · Uniswap Web App |

---

## 3. Token and supply

| Param | Value |
|-------|--------|
| Token (Base) | **`TBD_AFTER_BRIDGE`** — set to Superchain-bridged RICH |
| L1 canonical RICH | Deploy on Ethereum first; not the CCA token address |
| Auction amount (`totalSupply` in config) | **100,000,000 × 10¹⁸** = `100000000000000000000000000` |
| Token decimals | **18** (Permit ERC-20) |
| Symbol / name (expected) | RICH / as deployed metadata |

---

## 4. Pricing (locked)

| Param | Human | On-chain (Q96 integer) |
|-------|--------|-------------------------|
| Floor ratio | **\(5 \times 10^{-7}\) ETH per RICH** | — |
| `floorPrice` (rounded) | implies same ratio | **`39614081257132168796700`** |
| `tickSpacing` (1% of raw floor) | 1% of floor | **`396140812571321687967`** |
| FDV at floor | ~500 ETH / ~$950k @ ETH $1,900 | — |
| Full-sell raise at floor | ~50 ETH / ~$95k | planning band only |

**Rounding rule applied:**

```text
floor_raw = (2^96 * 5) // 10_000_000
tickSpacing = floor_raw // 100
floorPrice = (floor_raw // tickSpacing) * tickSpacing
assert floorPrice % tickSpacing == 0
```

---

## 5. Timing

| Param | Value |
|-------|--------|
| Auction duration | **5 days** |
| Auction blocks | **216,000** (= 5 × 24 × 3600 / 2) |
| Prebid | **0 blocks** (no prebid; optional later) |
| `startBlock` | **FILL AT DEPLOY** = Base tip + open buffer (suggest **+1,800** ≈ 1 hour, or **+43,200** ≈ 24h marketing) |
| `endBlock` | `startBlock + 216000` |
| `claimBlock` | **= endBlock** (claim when auction ends; can delay if desired) |

**Do not hardcode absolute blocks in git as final** until open day. JSON uses `null` + relative fields.

---

## 6. Recipients and graduation

| Param | Value |
|-------|--------|
| `fundsRecipient` | **`0xeD1FA21329fc45860cAB5D5E26a5fafcCDAcd6D5`** |
| `tokensRecipient` | **same** (unsold auction tokens) |
| `validationHook` | **`0x0000000000000000000000000000000000000000`** |
| `requiredCurrencyRaised` | **0** (always settle) |
| Post-clear ops split (off-chain) | **~6.5 ETH** founder ops; **rest liquidity** |

---

## 7. Supply schedule (back-loaded / convex)

Generated to match Uniswap CCA configurator defaults:

- **α = 1.2** convex time boundaries  
- **12** gradual steps (~70% of MPS mass over decreasing block windows)  
- **Final block ~31%** of total MPS (back-loaded dump)  
- **Σ (mps × blockDelta) = 10,000,000** MPS  
- **Σ blockDelta = 216,000**

| # | mps (per block) | blockDelta |
|---|-----------------|------------|
| 1 | 21 | 27234 |
| 2 | 27 | 21293 |
| 3 | 29 | 19507 |
| 4 | 31 | 18432 |
| 5 | 33 | 17671 |
| 6 | 34 | 17087 |
| 7 | 35 | 16617 |
| 8 | 35 | 16225 |
| 9 | 36 | 15889 |
| 10 | 37 | 15597 |
| 11 | 38 | 15339 |
| 12 | 38 | 15108 |
| 13 (final) | 3096430 | 1 |

**Encoded `auctionStepsData` (SSTORE2 / factory bytes):**

```text
0x0000150000006a6200001b000000532d00001d0000004c3300001f0000004800000021000000450700002200000042bf00002300000040e90000230000003f610000240000003e110000250000003ced0000260000003beb0000260000003b042f3f6e0000000001
```

(104 bytes = 13 × uint64 packed: mps 24 bits \| blockDelta 40 bits)

---

## 8. Deploy checklist (when token is live)

1. [ ] Deploy RICH on **Ethereum** (1B, `ERC20PermitDFPkg`).  
2. [ ] Bridge **100M** to Base; record Base address.  
3. [ ] Patch `docs/cca/base-rich-cca-config.json` → `token`, `startBlock`, `endBlock`, `claimBlock`.  
4. [ ] Approve factory for **100M** RICH (Base).  
5. [ ] `initializeDistribution(token, amount, configData, salt)` on factory.  
6. [ ] Call **`onTokensReceived()`** on auction (required before bids).  
7. [ ] Publish CCA URL + bidder checklist; market (Gitlawb, agents, BattleChain promo).  
8. [ ] After clear: sweep currency / unsold per CCA API; apply ops/liquidity split.

**Factory (reference):** `0xCCccCcCAE7503Cac057829BF2811De42E16e0bD5`

---

## 9. Validation checklist

- [x] Floor multiple of tick spacing  
- [x] Tick spacing = 1% of floor (raw)  
- [x] Duration 5d / 216000 Base blocks  
- [x] Schedule totals 10M MPS and 216000 blocks; final step ~30%+  
- [x] Recipients = proceeds wallet  
- [x] Min raise = 0  
- [ ] Token address = Base RICH (pending deploy/bridge)  
- [ ] Absolute start/end/claim blocks (pending open window)  
- [ ] Live approve + initialize + onTokensReceived  

---

## 10. Related promotion (not CCA params)

**BattleChain testnet** deployment of Crane + ported DeFi protocols is part of **launch marketing** (security theater + open infra for others). See launch plan §1.4b / decision log 2026-07-22. Does **not** change CCA floor or Base auction config.

---

*Parameter sheet generated 2026-07-22. Update JSON when Base RICH address and open block are known.*
