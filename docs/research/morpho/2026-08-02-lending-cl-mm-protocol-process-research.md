# Lending × Concentrated-Liquidity Market Making: Protocol Process Research

**Date:** 2026-08-02  
**Status:** Research reference (not a product PRD)  
**Audience:** IndexedEx engineering designing Morpho + Uniswap V3/V4 levered LP strategies  
**Goal:** Document **how existing protocols combine lending with CL market making** in enough process detail to **abstract** open / maintain / exit / liquidate flows onto Morpho Blue + IndexedEx Uni V4 SE (and related hosts).

**Companion docs:**

| Doc | Role |
|-----|------|
| [`2026-08-02-morpho-uniswap-lending-mm-strategies.md`](./2026-08-02-morpho-uniswap-lending-mm-strategies.md) | Strategy map S0–S6, decision tree |
| [`2026-08-02-morpho-uniswap-strategy-explanations.md`](./2026-08-02-morpho-uniswap-strategy-explanations.md) | Strategy primer |
| [`2026-08-02-morpho-v2-uniswap-v4-composition-diagram.md`](./2026-08-02-morpho-v2-uniswap-v4-composition-diagram.md) | S0 + V4 buffer composition sketch |
| Hook PRD | `contracts/hooks/uniswap/v4/standardExchange/single/UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_PRD.md` (S0 surface only — **not** levered LP) |

**IndexedEx building blocks this research maps onto:**

| Piece | Path / note |
|-------|-------------|
| Uni V4 SE (ERC-20 claim on managed CL position) | `contracts/protocols/dexes/uniswap/v4/` |
| Morpho Blue (supply/borrow/coll) | Crane `MorphoBlueService` / `external/morpho/blue` |
| Morpho Vault V2 + adapters | RH-native strategy host option (S5) |
| Generic ERC-4626 SE | Supply wrap only (S0) — insufficient alone for borrow/LP loop |

**Scope note:** “Looping” in retail DeFi often means **rate loops** (e.g. stETH coll → borrow ETH → more stETH). Those are documented only as contrast. This note focuses on **CL LP inventory coupled to borrow/lend**.

**Sources are time-sensitive** (docs, gov RFCs, product UIs as of research pass 2026-08-02). Re-verify contracts and live status before implementation.

---

## 1. Executive summary

1. **Lending × CL MM is a real product category** across Aave/Maker proposals, purpose-built LP lenders (Revert), account/margin systems (Arcadia, Gearbox), and classic leveraged yield farms (Alpha Homora, Extra Finance). Theory does **not** require Morpho; Morpho is one money-market backend.

2. **Three process families** cover almost every protocol:

| Family | Process sketch | Our map ID |
|--------|----------------|------------|
| **F1 Borrow→LP** | Post liquid coll → borrow → mint/increase CL LP | **S3** |
| **F2 LP→coll→borrow→LP** | CL position (or share) as coll → borrow → reinvest into same/new LP | **S4** |
| **F3 Unified inventory** | Same capital is coll *and* AMM depth (and sometimes debt is productive) | **S6** |

3. **Highest-signal process references for Morpho + Uni V4 SE:**

| Priority | Protocol | Steal |
|----------|----------|--------|
| P0 | **Revert Lend** | Atomic lever loop on live Uni V3/Aero LP coll; health; liquidations; LP stays manageable under loan |
| P0 | **Alpha Homora V2** | Position = debt + LP equity; open/close/liquidate accounting |
| P1 | **Arcadia** | Account shell + margin + Uni v3/v4 + automation bounds |
| P1 | **Gearbox** | Debt in account, LP as inventory (no LP listing on money market) |
| P2 | **Aave Labs Uni V4 CDP RFC** | Explicit Risk + Collateralization + BorrowableAsset modules |
| P2 | **Maker G-UNI history** | Stable-pair LP coll PMF; volatile LP harder |
| P3 | **Fluid** | Only if product thesis is unified liquidity, not Morpho+external Uni |
| P3 | **Extra Finance / YLDR** | L2 LYF and Uni V3 lever product shapes |

4. **Abstraction for IndexedEx (default recommendation):**

```text
v1 process target = F1 (S3), Homora/Gearbox-shaped:
  Strategy diamond holds Morpho debt + Uni V4 SE shares (inventory)
  Morpho coll = blue-chip (WETH, …) — existing markets / oracles

v2 process target = F2 (S4), Revert/Aave-RFC-shaped:
  Morpho coll = Uni V4 SE shares (or equivalent ERC-20 claim)
  Custom oracle + LLTV + liquidator redeem path on SE
```

5. **Buffer/pricing hook and pure Morpho supply wrap (S0) do not implement F1–F3.** They only make Morpho/SE claim rates tradeable on Uni V4.

---

## 2. Shared process model (abstract machine)

Every protocol in this note can be described with the same machine. Use this when mapping Morpho + Uni.

### 2.1 Objects

| Object | Meaning | Morpho + IndexedEx candidate |
|--------|---------|------------------------------|
| **User equity share** | User’s claim on residual value | Strategy ERC-20 / position NFT / account ownership |
| **CL inventory** | Live concentrated liquidity (range, fees) | Uni V4 SE shares; vault owns `PoolKey` + ticks + salt |
| **Debt** | Borrowed loan asset, interest-accruing | Morpho Blue borrow shares/assets |
| **Money-market coll** | What the lending protocol accepts as coll | S3: WETH etc. / S4: SE shares |
| **Valuator / oracle** | Maps coll → loan-value for HF | Morpho `IOracle`; plus internal equity NAV |
| **Risk limits** | LTV / LLTV / coll factor / buffer | Morpho LLTV; strategy min HF |
| **Executor** | Atomic multicall / flash / adapter | Bundler3, strategy Target, flash loan callback |
| **Liquidator path** | Who closes unhealthy debt and how LP exits | Morpho liquidate + SE redeem, or strategy-only |

### 2.2 Lifecycle (canonical steps)

```text
OPEN
  1. Intake capital (user tokens and/or flash loan)
  2. (Optional) mint/increase CL inventory
  3. Post money-market coll
  4. Borrow loan asset up to risk limit
  5. Deploy borrowed funds into CL (swap to range ratio + add liquidity)
  6. Repeat 3–5 until target leverage / headroom (F2 loop) or stop after one deploy (simple F1)
  7. Mint user equity / record position

MAINTAIN
  - Accrue debt interest
  - Accrue LP fees / IL / OOR inventory shift
  - Optional: rebalance range, compound fees, partial repay, top-up coll
  - Monitor HF (money market) and equity NAV (strategy)

DE-LEVER / EXIT
  1. Remove CL liquidity (or burn SE shares → underlyings)
  2. Swap residuals as needed to loan asset
  3. Repay debt (partial or full)
  4. Withdraw remaining coll
  5. Return residual equity to user
  (Often flash-loan assisted so intermediate HF stays valid)

LIQUIDATE (if HF breached)
  - Money-market liquidator seizes coll and repays debt  OR
  - Strategy liquidator / public delever closes LP then repays
  - Residual to user if any; shortfall = bad debt / socialized
```

### 2.3 Economics identity (always true)

```text
equity ≈ max( NAV(CL inventory) + idle_tokens + coll_value_if_distinct − debt_accrued , 0 )

levered_fee_exposure ≈ fee_APR × (CL_notional / equity)
borrow_cost          ≈ borrow_APR × (debt / equity)
il_exposure          ≈ f(range, price path, leverage)
```

Carry works while **fee income + other inventory yield** exceed **borrow cost + rebalance drag**, after IL. Leverage moves the position closer to liquidation **by construction**.

### 2.4 Two HF planes

| Plane | Who computes | What it sees |
|-------|--------------|--------------|
| **Money-market HF** | Morpho / Aave / Revert pool | Only **accepted coll** vs debt |
| **Strategy equity HF** | Product / account | Full book: LP + idle − debt (and any coll not on money market) |

**F1/S3 trap:** Morpho can show healthy while strategy equity is insolvent (LP crashed, coll still fine) — or the reverse if coll is volatile and LP is fine. Product law must define **which plane gates user actions**.

**F2/S4:** Planes couple more tightly because coll **is** the LP claim — but internal range/OOR still affects oracle quality.

---

## 3. Protocol process dossiers

Each dossier: role, process, risk objects, abstraction to Morpho + Uni V4 SE.

---

### 3.1 Revert Lend — LP is collateral; atomic lever loop (F2)

**Status / surface:** Live product docs for Uni v3 LP coll and Aerodrome positions on Base; USDC borrow; integrated into Revert LP management UI.  
**Docs:** [Revert Lend](https://docs.revert.finance/revert/revert-lend), [Leverage](https://docs.revert.finance/revert/revert-lend/leverage), [Liquidations](https://docs.revert.finance/revert/revert-lend/liquidations).

#### Role in taxonomy

- Primary reference for **F2 / S4**: productive CL coll + borrow + reinvest.
- Also shows **maintain under loan** (auto-range / auto-compound still work on collateralized positions).

#### Objects

| Object | Revert shape |
|--------|----------------|
| CL inventory | Uni V3 NFT (or Aero position); remains the live LP |
| Coll | Same position (still earning fees) |
| Debt | USDC from Revert Lend pool |
| Risk | Pair **collateral factor**; health = coll value (after CF) vs debt |
| Leverage open | Single tx: borrow → swap to range ratio → add liquidity |
| Liquidation | Permissionless; liquidator repays debt, takes coll + **penalty 2–10%** scaling with underwater depth; residual to borrower if any |

#### Process — open leverage (documented loop)

```text
1. Position already exists (or is created) as Uni V3 / Aero LP
2. Position is recognized as coll under pair collateral factor
3. LEVERAGE TX (atomic):
   a. Borrow USDC up to CF headroom
   b. Swap USDC into the two (or one) tokens at the ratio the current range needs
   c. Increase liquidity on the SAME position
4. Each pass increases position size AND debt → headroom shrinks
5. Loop stops at CF limit (maxed loop can sit near liquidation immediately)
```

#### Process — unwind / repay

```text
Atomic reverse (documented as same style as lever):
  remove liquidity → swap to USDC → repay
Partial repay with outside funds also supported
```

#### Process — liquidate

```text
IF debt > coll_value (after CF / health rules):
  any account may:
    repay debt
    receive coll worth debt + penalty (2–10%, scales with shortfall depth)
  IF position value > debt + penalty:
    remainder returned to borrower
  ELSE:
    liquidator takes whole position; shortfall → reserves / lenders (bad debt)
```

#### What to abstract for Morpho + Uni V4 SE

| Revert step | IndexedEx abstraction |
|-------------|------------------------|
| “Position is coll” | Morpho `collateralToken` = **Uni V4 SE share** (ERC-20), not raw NFT |
| Borrow USDC | `Morpho.borrow` loan asset (USDC/USDG/WETH per market) |
| Swap to range ratio | Strategy swaps via PoolManager / router using SE zap semantics |
| Reinvest into same position | `SE.exchangeIn` / mint more SE shares → `supplyCollateral` more shares |
| Atomic loop | Flash loan (Morpho `flashLoan` or external) + multicall Target; or iterative with HF checks |
| Auto-range while coll | Rebalance **must** keep Morpho HF valid; may need withdraw coll → rebalance → re-supply (or SE-internal rebalance that preserves share NAV rules) |
| Liquidation | Morpho liquidate seizes **SE shares**; liquidators need **SE redeem** liquidity or market |

**Product lessons:**

1. **Single-tx lever** is table stakes UX for F2.  
2. **Max CF lever = edge of liquidation** — deploy-time max leverage must leave a buffer (Revert: direct borrow uses ~95% safety buffer; full lever can ignore that).  
3. **LP management under loan** is a product differentiator; for Morpho, SE must support ops that do not brick coll accounting.  
4. Publish / expect **permissionless liquidator bots**.

---

### 3.2 Arcadia Finance — account + margin + CL strategies (F1/F2 hybrid)

**Status / surface:** User-facing app on Arcadia Protocol; Base, Optimism, Unichain; Uni and Aerodrome; claims Uni **v3 and v4**; built-in margin; automation within onchain bounds.  
**Docs:** [Arcadia overview](https://docs.arcadia.finance/introduction/overview).

#### Role in taxonomy

- **Account shell** model: user-owned DeFi account holds assets + margin; strategies (CL MM) run inside risk bounds.
- Closer to **Gearbox-style isolation** than to listing LP on Aave main market.
- Cited in Uniswap gov discussion as already providing **borrow against liquidity positions** without a new PositionManager fork.

#### Objects

| Object | Arcadia shape |
|--------|----------------|
| Shell | User-owned account (asset management + margin) |
| CL inventory | Virtual and concentrated AMM positions (Uni/Aero) |
| Debt / margin | Built into account protocol |
| Automation | Asset/risk management within enforceable bounds |
| UX | One-click strategies normally reserved for pros |

#### Process (abstracted from product model)

```text
OPEN
  1. Open / fund account
  2. Enable margin / borrow capacity under account risk engine
  3. Deploy CL strategy (mint/increase Uni/Aero position)
  4. Optionally increase leverage via account margin (borrow → more LP)

MAINTAIN
  - Automation rebalances / compounds within onchain policy
  - Account risk engine monitors liquidation bounds

EXIT
  - Close strategy legs, repay margin, withdraw residual
```

#### What to abstract

| Arcadia idea | IndexedEx abstraction |
|--------------|------------------------|
| Account | Strategy diamond **or** per-user position vault |
| Margin engine | Morpho position **or** internal credit line against diamond equity |
| Enforceable automation bounds | Keepers only call functions that enforce min HF + max leverage immutables |
| Uni v3 + v4 support | Prefer **one** SE package (V4) first; don’t dual-path in v1 |

**Product lessons:**

1. **Shell-first design** (account owns everything) simplifies multi-leg HF vs pure Morpho coll listing.  
2. **Onchain bounds for automation** are product law, not just offchain keeper config.  
3. Good template if IndexedEx chooses **S3 Gearbox-like** host before S4 Morpho coll.

---

### 3.3 Alpha Homora V2 — leveraged yield farm position (F1, partial F2)

**Status / surface:** Historical flagship LYF; Ethereum / Avalanche / Optimism eras; Uni V2/V3 and other AMMs; “spells” as strategy modules; BYOLP (bring-your-own LP) as coll path in later messaging.

#### Role in taxonomy

- Canonical **F1** process: integrated bank + farm position.
- Teaching reference for **position accounting** (collateral value, debt, work factor / kill factor).

#### Objects

| Object | Homora shape |
|--------|----------------|
| Position | Per-user position id (often NFT-like) holding farm LP + debt |
| Bank | Protocol lending of base tokens |
| Spell | Strategy module: which LP, how to add/remove, swap paths |
| Risk | Work factor / kill factor style limits per pool |

#### Process — open levered LP (classic)

```text
1. User selects pool + leverage target
2. User supplies equity (one or both tokens; protocol may zap)
3. Protocol borrows remaining base tokens from Bank
4. Spell: swap/add liquidity into target AMM LP (or Uni V3 position shape)
5. LP held in position; debt recorded against position
6. Optional farm stake for reward tokens
```

#### Process — close / liquidate

```text
CLOSE:
  1. Unstake LP if farmed
  2. Remove liquidity → tokens
  3. Swap as needed to debt asset
  4. Repay Bank
  5. Return residual equity to user

LIQUIDATE (equity / work factor breached):
  - Liquidator (or keeper) runs close path
  - Incentive from residual or fixed bonus
  - Position debt cleared; underwater handling per protocol rules
```

#### BYOLP (F2-adjacent)

```text
User already holds LP
  → supply LP as coll to Bank-like module
  → borrow more base
  → (optional) add more LP
```

Same abstract F2 loop; valuation is on **fungible LP or managed LP**, not always raw Uni V3 NFT.

#### What to abstract

| Homora | IndexedEx |
|--------|-----------|
| Position id | Strategy user shares **or** ERC-721 position |
| Bank | Morpho Blue market(s) |
| Spell | Strategy Target + Uni V4 SE routes (closed-form only where possible) |
| Work factor | min HF / max LTV immutables on strategy |
| Liquidate = force close | Public `liquidatePosition` that de-levers via SE out + Morpho repay |

**Product lessons:**

1. **Spell modularity** = adapter/strategy facet pattern.  
2. User mental model is **one position**, not two apps (Morpho + Uni).  
3. Liquidation is **close the strategy**, not only seize an ERC-20 on a money market — unless coll is the LP share on Morpho (S4).

---

### 3.4 Extra Finance — L2 leveraged yield farming (F1)

**Status / surface:** Optimism / Base-class LYF; lending pools + leverage into DEX LPs (historically Velodrome-class pairs).

#### Role in taxonomy

- Modern L2 **F1** with retail listing of many pairs.
- Weaker Uni V4 specificity; strong on **ops**: listing, utilization caps, liquidation bots.

#### Process (same F1 skeleton as Homora)

```text
supply equity → borrow from Extra lending pool → LP into DEX farm
  → harvest rewards → optional compound
  → delever / liquidate when HF low
```

#### What to abstract

- **Per-pair risk params** (max leverage, borrow caps).  
- **Utilization bottleneck**: borrow APR and available liquidity gate strategy APR.  
- For Morpho: isolated Blue markets + supply of loan asset matter as much as LP fee APR.

---

### 3.5 Gearbox — credit account + adapters (F1 toolkit, not LP coll market)

**Status / surface:** Credit accounts as isolated smart wallets; lenders supply pools; borrowers open accounts with coll + debt; **whitelisted adapters** call external protocols (Uniswap, etc.).

#### Role in taxonomy

- **Does not require** Uni LP to be listed as Morpho/Aave coll.
- Debt lives on the **account**; LP is **inventory inside the account**.
- Closest mental model to: **IndexedEx strategy diamond holds Morpho debt authorization + Uni V4 SE shares**.

#### Objects

| Object | Gearbox shape |
|--------|----------------|
| Credit Account | Isolated contract wallet |
| Coll + debt | Inside account; HF on account multi-asset portfolio |
| Adapter | Permissioned call surface to Uni, etc. |
| Liquidation | Close account; sell assets per liquidation rules |

#### Process — levered Uni LP (conceptual)

```text
1. Open credit account, deposit coll
2. Borrow loan assets into account (up to HF)
3. Adapter: swap / mint Uni V3 position or deposit into LP vault
4. Account NAV = coll-like assets + LP mark − debt
5. Liquidation if account HF fails — liquidator unwinds LP via adapters
```

#### What to abstract

| Gearbox | IndexedEx S3 design |
|---------|---------------------|
| Credit account | Strategy diamond (pooled) **or** per-user clone |
| Adapter whitelist | Only Uni V4 SE + Morpho + approved routers |
| Account HF | Internal equity NAV oracle (mark SE via convert + token oracles) |
| Liquidation | Force SE redeem + Morpho repay; Morpho HF separate if coll is WETH on Morpho |

**Two sub-architectures both Gearbox-inspired:**

```text
A) Morpho coll = WETH on Morpho; diamond authorized; SE shares free inventory
   Morpho HF on WETH; strategy must still track equity

B) No Morpho coll until debt needed; flash + temporary coll patterns
   More complex; usually A is clearer for v1
```

**Product lessons:**

1. **F1 without S4 oracle** is a full product — Revert is optional.  
2. Adapter whitelist is a **security product**, not just DX.  
3. Liquidators must be able to call the same unwind paths as users.

---

### 3.6 Fluid — smart collateral / smart debt (F3 / S6)

**Status / surface:** Liquidity Layer + Vault + DEX; smart coll and smart debt make lending inventory dual-purpose as AMM liquidity.

#### Role in taxonomy

- **Not** “Morpho + external Uni.” Own stack unifies lend + swap.
- Reference only if product thesis is **capital efficiency / unified book**.

#### Process (conceptual)

```text
User posts pair-like / range inventory as smart coll
  → can borrow against it while inventory earns swap fees
Smart debt:
  → debt side can also act as trading liquidity; fees reduce effective borrow cost
Liquidations / risk couple AMM state and vault state continuously
```

#### What to abstract

- Do **not** pretend Morpho Blue + Uni V4 SE is Fluid without redesigning both.  
- Steal **vocabulary**: productive coll, productive debt, shared liquidity layer.  
- IndexedEx path to F3 would be a **new product class** (research map S6), not a DFPkg flag.

---

### 3.7 YLDR — Uni V3 multi-x / LP coll product (F2)

**Status / surface:** Marketed as leverage Uni V3 LP up to multi-x and/or use LP as coll to borrow; CertiK-audited narrative in third-party listings. **Re-verify live status before depending on it.**

#### Process (marketing-level; confirm onchain)

```text
OPEN levered LP:
  deposit / create Uni V3 position
  protocol borrows against it and expands liquidity (F2 loop)
OR:
  post LP as coll → borrow assets for other use (coll-only mode)
```

#### What to abstract

- Product packaging of **two modes**: pure coll borrow vs recursive LP expand.  
- For IndexedEx: separate **S4-borrow-only** from **S4-loop** in PRD (different max LTV and UX).

---

### 3.8 Aave Labs RFC — Uni V4 Position Manager CDP (F2 design doc)

**Status / surface:** Uniswap governance RFC (2025): specialized Uni V4 Position Manager + GHO facilitator / later Aave V4 spoke; community debate cited **Revert** and **Arcadia** as existing competitors.  
**Source:** [RFC: Aave’s CDP for Uniswap V4 Positions](https://gov.uniswap.org/t/rfc-aave-s-cdp-for-uniswap-v4-positions/25568).

#### Role in taxonomy

- Best **modular breakdown** of F2 from a major lending team — even if grant/politics stall shipping.
- Evolved from Uni V3 prototype → V4.

#### Modules (as proposed)

| Module | Responsibility |
|--------|----------------|
| **UniV4PositionManager (extended)** | Own/manage LP; expose borrow-against-position |
| **Risk Module** | Reuse Aave V3/V4 risk configuration for underlyings |
| **Collateralization Module** | Value position via external oracles; enforce coll limits; liquidations |
| **BorrowableAssetManager** | Draw GHO (facilitator bucket) or later Aave V4 hub liquidity |

#### Process (abstract)

```text
1. LP uses extended Position Manager to hold Uni V4 position
2. Collateralization Module marks position (composition × asset oracles)
3. Risk Module applies Aave-style params for those assets
4. User borrows GHO / other assets up to limits
5. Optional later: reinvestment / compound features
6. Liquidation path when coll rules fail
```

#### What to abstract

| Aave RFC | Morpho + IndexedEx |
|----------|-------------------|
| Extended PositionManager | **Uni V4 SE diamond** already owns position; don’t fork PM if SE is coll |
| Risk Module | Morpho LLTV + IRM enablement; plus strategy caps |
| Collateralization Module | **Morpho oracle** over SE share NAV (underlyings × rates) |
| BorrowableAssetManager | Morpho `borrow` of loan token; loan liquidity = Blue suppliers |
| GHO facilitator bucket | Morpho market liquidity / supply cap analogue |

**Community process lessons (design constraints):**

- Addressable TVL limited to pools whose **both legs** have risk configs.  
- Volatile LP coll historically weaker PMF than **stable–stable** (Maker G-UNI).  
- Existing Revert/Arcadia show F2 can ship without DAO grants — competition exists.

---

### 3.9 Maker / Oasis + G-UNI — stable LP coll at scale (F2 historical)

**Shape:** Managed Uni V3-style LP vault tokens (G-UNI / Gelato-class) as **DAI coll**.

#### Process

```text
1. User deposits into managed LP vault → ERC-20 vault shares
2. Shares accepted as Maker coll (vault type)
3. User mints DAI against shares
4. Liquidation via Maker auction if ratio fails
```

#### What to abstract

1. **Fungible share wrapping CL** is the proven coll form (matches Uni V4 SE).  
2. **Stable–stable** ranges dominate successful LP coll TVL.  
3. High setup fees / stability fees can kill retail PMF even when TVL exists.  
4. For Morpho S4 v1, prefer **stable or tightly correlated pairs** before volatile ETH/USDC recursive loops.

---

### 3.10 Contango / DeFi Saver / Instadapp — looping automation (rate loops + leverage UX)

**Shape:** Automate recursive lend/borrow/swap (classic looping) into a trading UX; money markets Aave/Maker/etc.

#### Process (classic rate loop — **not** CL MM)

```text
deposit ETH → borrow DAI → swap DAI→ETH → deposit ETH → … until target leverage
```

#### What to abstract **for CL products** (UX only)

- Target leverage / HF as primary UX knobs.  
- One-click open/close via flash loans.  
- Do **not** copy the economic loop as if it were LP fee farming — different risk (no IL range, different oracle).

---

### 3.11 Governance / experimental: Aave V3 NFT coll, Compound Nextosi

**Aave threads (2022–23):** Uni V3 NFT as GHO coll / facilitator ideas.  
**Compound Nextosi (2025 discussion):** contracts to enable Uni LP as Compound coll; skepticism from weak Aave V2 Uni V2 LP PMF.

#### Process lesson

Proposals repeatedly rediscover the same checklist:

1. Which pools allowed (both assets listed / oracled)?  
2. How to mark NFT / range NAV safely (manipulation, OOR)?  
3. Can liquidators exit without crushing the pool?  
4. Is PMF real vs just capital efficiency narrative?

Use as **threat-model checklist**, not as shipping templates.

---

## 4. Cross-protocol process comparison

### 4.1 Open leverage

| Protocol | Coll source | Debt source | LP venue | Atomic lever? |
|----------|-------------|-------------|----------|---------------|
| Revert Lend | Live Uni/Aero LP | Own USDC pool | Same LP | Yes (borrow→swap→add) |
| Homora | Equity + bank borrow | Own bank | Spell AMM | Typically yes |
| Extra | Equity + pool | Own pools | DEX farm | Yes |
| Gearbox | Account coll | Credit account debt | Adapter Uni | Via multicall adapters |
| Arcadia | Account | Margin | Uni/Aero | One-click strategies |
| Fluid | Smart coll inventory | Vault debt | Own DEX | Native |
| Aave V4 RFC | Uni V4 position | GHO / Aave hub | Same PM | Designed |
| Maker G-UNI | Vault shares | DAI mint | Managed Uni | User-driven |

### 4.2 Liquidation

| Protocol | Trigger | Coll seized | LP unwind |
|----------|---------|-------------|-----------|
| Revert | Debt > coll health | LP position + penalty | Liquidator receives position value path |
| Morpho Blue (generic) | LLTV breach | ERC-20 coll | **Caller must sell coll** — design SE redeem |
| Homora | Work/kill factor | Position closed | Spell remove LP |
| Gearbox | Account HF | Account assets | Adapter unwind |
| Aave RFC | Coll module rules | Position-backed debt | Module liquidations |

### 4.3 Who prices the LP?

| Approach | Protocols | Morpho fit |
|----------|-----------|------------|
| Dedicated LP lender valuator | Revert | Custom Morpho oracle |
| Account multi-asset mark | Gearbox, Arcadia | Internal strategy NAV; Morpho may use blue-chip only |
| Money market risk config on underlyings | Aave RFC | Oracle composes token oracles × amounts |
| Managed vault share oracle | Maker G-UNI | SE `convertToAssets`-style + token prices |
| Unified layer internal | Fluid | N/A to external Morpho |

---

## 5. Abstracted process templates for IndexedEx

### 5.1 Template T1 — S3 Borrow→LP (recommended v1)

**Peers:** Homora open, Extra Finance, Gearbox with WETH coll, DeFi Saver boost into LP.

```text
STATE
  strategy: holds UniV4 SE shares + optional idle tokens
  morpho:  supplyCollateral(WETH) + borrow(USDC)  // example pair
  user:    holds strategy shares

OPEN (atomic preferred)
  1. User transfers equity (WETH and/or USDC)
  2. Flash loan USDC if needed for target leverage
  3. Morpho.supplyCollateral(WETH)
  4. Morpho.borrow(USDC)
  5. Zap USDC (+ WETH) → Uni V4 SE shares via SE exchangeIn routes
  6. Repay flash if used
  7. Mint strategy shares = f(equity)

MAINTAIN
  - accrue Morpho interest (view + optional poke)
  - optional: compound SE fees if SE supports
  - optional: rebalance Uni range ONLY if strategy equity HF and Morpho HF remain above buffers
  - public or keeper: deleverIfBelow(minHf)

EXIT
  1. Burn user strategy shares
  2. SE redeem → underlyings
  3. Swap to USDC as needed
  4. Morpho.repay
  5. Morpho.withdrawCollateral
  6. Return residuals

LIQUIDATE (strategy-defined)
  IF strategyEquityHf < liqThreshold OR morphoHf < buffer:
    force EXIT path; incentive to caller from residual
  Morpho liquidate may still hit WETH coll independently — design for both planes
```

**Design locks required:** pair, target leverage, min HF, pooled vs per-user, fee model, which plane is authoritative for user withdraw.

### 5.2 Template T2 — S4 LP-coll recursive lever (Revert-shaped v2)

**Peers:** Revert Lend leverage, YLDR, Aave V4 CDP RFC, Maker G-UNI mint against shares.

```text
STATE
  strategy or user: Uni V4 SE shares
  morpho market: collateral = SE, loan = USDC, oracle = SE NAV, lltv = conservative
  user: strategy shares OR direct SE + Morpho position

OPEN LEVER LOOP (atomic)
  1. User SE shares (or mint SE from underlyings)
  2. Morpho.supplyCollateral(SE)
  3. Morpho.borrow(USDC) up to LLTV * buffer
  4. USDC → underlyings → mint more SE
  5. Morpho.supplyCollateral(new SE)
  6. Repeat 3–5 until target HF or max iterations
  7. Record equity

CRITICAL INVARIANT
  After each iteration: morpho health holds with oracle(SE) update
  Oracle must not be manipulable by the same swap that mints SE in-tx without TWAP/guard

EXIT / DELEVER
  reverse: withdraw coll SE (if free) OR remove via flash:
    flash USDC → repay → withdraw SE → redeem SE → swap → repay flash

LIQUIDATE
  Morpho liquidator seizes SE shares
  MUST: SE.exchangeOut / redeem works for liquidator at fair rate under stress
  Optional: strategy helper multicall for liquidators
```

**Design locks required:** oracle spec, LLTV, max loop iterations, allowed pools (stable vs volatile), liquidator UX, SE fee behavior on liquidator redeem.

### 5.3 Template T3 — Account/adapter shell (Gearbox/Arcadia-shaped)

```text
STATE
  account/diamond: all tokens + SE shares + Morpho auth
  risk: single account HF over marked assets

OPEN
  deposit → borrow into account → adapter mint SE

Same economics as T1; difference is packaging and liquidation surface
```

Use when multi-strategy adapters matter more than a single Morpho market.

### 5.4 Template T4 — Unified (Fluid-shaped) — out of Morpho+Uni scope

Document only as non-goal unless PRD revises to S6.

---

## 6. Oracle and coll representation patterns (process detail)

### 6.1 Coll representation ladder (easiest → hardest on Morpho)

| Rank | Representation | Example | Morpho readiness |
|------|----------------|---------|------------------|
| 1 | Blue-chip ERC-20 | WETH on Morpho | Ready (S3) |
| 2 | Managed LP ERC-20 share | G-UNI, Uni V4 SE share | Need oracle (S4) |
| 3 | Uni V3/V4 NFT | Raw position NFT | Poor fit; wrap first |
| 4 | Internal account inventory | Gearbox account | No Morpho coll listing |

**IndexedEx advantage:** Uni V4 SE already produces **(2)**.

### 6.2 Valuator patterns

| Pattern | How | Risks |
|---------|-----|-------|
| **Composition mark** | Read position amounts → price each leg with trusted oracles → sum − debt | Spot oracle manip; fee tokens ignored or not |
| **Share convert** | `SE` pro-rata claim × leg oracles | Donation/inflation; empty SE; must match production SE law |
| **TWAP / capped** | Bound per-block change | Latency; OOR inventory lag |
| **Account simulation** | Simulate remove liquidity then mark | Gas; hook effects on V4 |

**Aave RFC pattern:** reuse risk config of **underlying assets**, then composition module.  
**Morpho pattern:** single `oracle.price()` for coll→loan; composition must live **inside** that oracle contract.

### 6.3 Liquidator exit (non-negotiable process step)

```text
IF coll = SE shares:
  liquidator receives SE
  liquidator must:
    SE.redeem / exchangeOut → underlyings → sell to loan asset
  OR secondary market for SE (usually too thin under stress)

IF coll = WETH and LP is inventory:
  Morpho liquidator only seizes WETH
  strategy may be left with LP and residual debt handling — define explicit cleanup
```

Revert’s lesson: liquidation defends **pool solvency**, not borrower residual. Same for Morpho suppliers.

---

## 7. Maintain / rebalance under leverage (process)

| Protocol behavior | Rule to abstract |
|-------------------|------------------|
| Revert: auto-range works on collaterized LP | Rebalance allowed only if post-rebalance HF ≥ buffer |
| Arcadia: automation within bounds | Encode bounds onchain |
| Homora: often manual / spell rebalance | Prefer explicit `rebalance` with preview |
| Fluid: rebalance is inventory physics | N/A |

**Recommended process gate for IndexedEx:**

```text
function rebalance(...) external {
  hfBefore = health();
  _doRangeOrSwap();
  require(health() >= minHf, "HF");
  require(morphoHealth() >= minMorphoHf, "MORPHO_HF");
}
```

Never treat rebalance as pure APR optimization under leverage.

---

## 8. Mapping to IndexedEx Morpho + Uni V4 decision forks

### 8.1 Host fork

| Host | Process template | Peer |
|------|------------------|------|
| IndexedEx strategy DFPkg/diamond | T1 or T2 | Homora / Revert |
| Morpho V2 + Uni adapter (S5) | T2 inside adapter `realAssets` | Steakhouse Box/Turbo class |
| Gearbox-like account only | T3 | Gearbox / Arcadia |

### 8.2 Coll fork

| Choice | Template | Oracle burden |
|--------|----------|---------------|
| Blue-chip Morpho coll + SE inventory | **T1 / S3** | Low on Morpho; medium internal NAV |
| SE shares as Morpho coll | **T2 / S4** | High (new oracle + LLTV) |

### 8.3 Pair fork

| Pair type | Historical signal |
|-----------|-------------------|
| Stable–stable CL | Maker G-UNI success path |
| Correlated (ETH/LST) | Easier oracles; some IL |
| Volatile (ETH/USDC) | Highest fee narrative; hardest HF/IL |

### 8.4 What not to confuse with this product

| Product | Process | Not F1–F3 |
|---------|---------|-----------|
| Uni Earn → Morpho vault | Deposit UX only | Distribution |
| V4 buffer/pricing hook | Wrap/unwrap SE↔underlying | No CL, no borrow |
| Morpho Turbo rate loop | Coll→borrow→more coll | No Uni CL MM |
| Pure Uni V4 SE | LP shares only | No Morpho debt |

---

## 9. Recommended research → design sequence

1. **Pick template T1 vs T2** (S3 vs S4). Default: **T1**.  
2. **Walk T1 against Homora + Gearbox** process checklists (open/close/liq).  
3. **If T2:** walk Revert leverage + liquidations + Aave RFC modules; write oracle PRD first.  
4. **Simulate** IL × borrow rate × liquidation penalty on candidate pair (stable first).  
5. **Write product PRD** with: state machine, both HF planes, atomic open/close, liquidator path, rebalance gates.  
6. **Implement** on real Uni V4 SE + Morpho Blue TestBase/fork — no mock SUT.

---

## 10. Field checklist (copy into PRD)

Use this to ensure abstraction is complete:

- [ ] Family: F1 / F2 / F3  
- [ ] Shell: pooled diamond / per-user position / Morpho V2 adapter  
- [ ] Money market: Morpho Blue market params (loan, coll, oracle, irm, lltv)  
- [ ] CL venue: Uni V4 SE instance (pool key, ticks policy)  
- [ ] Open: atomic? flash? max iterations? target HF?  
- [ ] Equity share math + fees  
- [ ] Maintain: who calls, rebalance gates, interest accrual  
- [ ] Exit: order of redeem/repay/withdraw; dust policy  
- [ ] Liquidation: Morpho plane + strategy plane; liquidator incentive  
- [ ] Oracle: composition, manipulation bounds, OOR behavior  
- [ ] Emergency: pause new leverage, force delever  
- [ ] Test matrix: open, accrue, price crash, liquidate, preview≈exec on SE legs  

---

## 11. Source sketch (non-exhaustive)

| Source | Use |
|--------|-----|
| Revert Lend docs (borrow, leverage, liquidations) | F2 atomic loop + HF + penalty model |
| Arcadia Finance docs | Account + margin + Uni v3/v4 |
| Alpha Homora V2 docs / Alpha Venture blogs | F1 position + spell + BYOLP |
| Extra Finance docs / explainers | L2 LYF ops |
| Gearbox docs | Credit account + adapters |
| Fluid docs / Messari / MixBytes | F3 smart coll/debt |
| Uniswap gov RFC: Aave CDP for Uni V4 (2025) | Module split Risk/Coll/Borrowable |
| Aave gov: Uni V3 NFT coll / GHO facilitator threads | NFT coll problem statement |
| Compound forum: Nextosi LP coll discussion | PMF skepticism |
| Maker / G-UNI historical coverage | Stable LP coll at scale |
| Contango docs: “what is looping” | Rate-loop contrast + UX |
| Galaxy Aave e-mode leverage research | Rate-loop systemic risk (contrast) |
| IndexedEx Uni V4 SE plan | Managed position → ERC-20 shares |

---

## 12. Changelog

| Date | Change |
|------|--------|
| 2026-08-02 | Initial process research: shared abstract machine; dossiers for Revert, Arcadia, Homora, Extra, Gearbox, Fluid, YLDR, Aave V4 RFC, Maker G-UNI, automation layers; T1–T4 templates for Morpho + Uni V4 SE |
