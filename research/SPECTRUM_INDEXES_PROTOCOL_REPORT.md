# Spectrum Indexes vs IndexedEx DETF — protocol report

| Field | Value |
|-------|--------|
| **Status** | Research snapshot |
| **Date** | 2026-07-30 |
| **Primary site** | https://spectrumindexes.xyz/ |
| **X** | [@spectrumindexes](https://x.com/spectrumindexes) · powered by [@Prism_V4hook](https://x.com/Prism_V4hook) |
| **Public code reviewed** | `Irora-dev/Spectrum` (frontend kit), `Irora-dev/prismv2contracts` (PRISM token), `Irora-dev/prism-exploit-disclosure` |
| **Local clones (temporary)** | `tmp/spectrum-review/Spectrum`, `tmp/spectrum-review/prismv2contracts`, `tmp/spectrum-review/prism-exploit-disclosure` — **do not commit**; delete when done |
| **Not reviewed** | Full Spectrum **basket** Solidity sources (not published under Irora-dev as of this date; integration is via frontend ABIs + deployed addresses) |

**Sources:** live site (docs, FAQ, learn, integrate, risk), Spectrum Mini handover docs (`app/handover/01-BUSINESS.md`, `02-TECHNICAL.md`), fee model and deployments in the Spectrum frontend, PRISM V2 contract README, PRISM V1 fee-layer exploit disclosure, public posts from @spectrumindexes.

This report is **descriptive**, not legal or investment advice. Spectrum’s own docs emphasize the same.

---

## 1. Executive summary

**Spectrum** markets **permissionless onchain basket tokens**: one ERC-20 that holds a **fixed set of constituent tokens at fixed weights**, fully collateralized by those assets. Each basket **is its own Uniswap V4 hook** and its own **{basket, USDC} liquidity**. Users **mint** (typically USDC in → hook acquires legs → issues shares) and **redeem** (shares out for USDC via the hook, or **unconditional in-kind** exit of constituents). Baskets are **immutable after deploy** (no rebalancing, no admin). Fees on mint/redeem route partly to a **PRISM buy-and-burn**, partly to interface/launcher kickbacks, creator share, and holders.

**IndexedEx DETFs** are also “one share over a multi-asset onchain reserve” with permissionless-style **create-your-own** packaging and **immutable, unowned** instances — but the **economic engine is different**:

| Layer | Spectrum | IndexedEx DETF |
|-------|----------|----------------|
| Substrate | Uniswap **V4 hook** = token + self-pool | **Diamond share** + **Balancer V3** reserve pool |
| Settlement | **USDC** (mint/redeem numeraire) | **Vault shares / rate assets** (family-specific); pool-priced seigniorage |
| Primary market | Buy underlyings into a **static basket** | **Mint/burn DETF** against reserve under **Policy / Open** rules |
| Lifecycle | Live at deploy (auction + pool init) | **Closed (inert) → live** via **first bond** + protocol-owned depth |
| Rebalancing | **None** (fixed weights forever) | Weights live in the **reserve AMM**; trading/joins change composition continuously |
| Monetary policy | No mint/burn price bands | **Policy** (synthetic rich/cheap gates) or **Open** (no price gates) |
| “Earn” path | Fees to **holders** + **PRISM burn**; interface kickbacks | **Bond rewards**, optional **natural expansion** (Policy), **protocol compound**, **Protocol DETF** fee share |
| Exit | `redeemInKind` always | Bond/claim/reserve exits per family; not the same as pure pro-rata fund shares |

**Surface similarity is real** (basket-shaped ERC-20, permissionless creation, multi-chain including Robinhood Chain, immutable design, creator economy). **Core mechanism is not the same product.** Spectrum is closer to a **fixed-weight, fully collateralized basket ETF analogue on V4**. IndexedEx DETF is closer to a **seigniorage / reserve-currency unit** over a **live multi-asset AMM reserve**, with bonding and explicit mint/burn policy.

---

## 2. What Spectrum is (product)

### 2.1 Positioning (public)

- Site meta: *“onchain basket tokens. Each basket is a single token that holds a whole basket of assets.”*
- X bio: *“The first permissionless on-chain ETF… crypto & rwa in a single click… Built on @Prism_V4hook.”*
- Open-source kit wording is stricter: **always say “basket,” never “index,” “fund,” or “ETF”** in product copy (internal code still has Index-era names).

### 2.2 Chains and settlement

From `deployments.json` and site posts:

| Chain ID | Network | Factory (as shipped in frontend) |
|----------|---------|----------------------------------|
| 8453 | Base | `0x91ca52C4…ef7A6` |
| 1 | Ethereum | `0xEf520C7f…Ba01` |
| 4663 | Robinhood Chain | `0x07Bfce09…97e6f` |

- **Settlement asset:** canonical **USDC** on each chain.
- FAQ historically emphasizes Base; V2 marketing and configs show **ETH + Base + Robinhood**.
- Example community launch cited on X: NVDA-related basket on Robinhood (`chain=4663`).

### 2.3 How a basket works (mechanics)

From docs + FAQ + technical handover:

1. **Token identity**  
   - ERC-20, **18 decimals**.  
   - The token contract **is** the Uniswap V4 hook and owns a **self-pool** vs USDC.  
   - That self-pool’s spot is **not** used as NAV; mint/redeem are hook-mediated.

2. **Composition**  
   - Fixed list of constituents with **target weights in BPS** (sum 100%).  
   - Each leg stores routing metadata (V2/V3/V4 pool path toward ETH/WETH markets) so the hook can buy/sell legs on mint/redeem.  
   - Assets need Uniswap (or compatible) depth; **Aerodrome-only** legs are rejected (can’t host Spectrum’s V4 hook path).

3. **Create / deploy**  
   - Permissionless via **factory** `deployBasket(…)` with CREATE2 salt.  
   - Salt is mined so the address carries required **hook permission bits** (frontend targets low-bit mask `0x88`).  
   - **Dutch auction** deploy price in ETH/native (`currentDeployPrice()`); one deploy per auction slot.  
   - Fee config and basket composition are **CREATE2-committed** and **immutable** after launch.  
   - Opens the self-pool at a **$1-ish NAV start price** (decimal-aware sqrtPrice init) — **not** a standing peg.

4. **Mint (buy)**  
   - Modeled as a **V4 swap USDC → basket** through a first-party **swap router**, with mandatory `hookData`:  
     `abi.encode(minOut, legMins[], frontend)`.  
   - Hook takes USDC, charges fee, **acquires constituents** via routed pools, enforces **per-leg minimums**.  
   - Empty hookData reverts for safety; first mint especially requires real leg floors.  
   - Generic aggregators that send empty hookData **cannot** route mints.

5. **Redeem (sell)**  
   - Swap **basket → USDC** with hookData (aggregate `minOut` as binding protection).  
   - **Or** `redeemInKind(amount, legMask, to)`: pro-rata constituents, **no pool, no USDC path**, skip frozen legs via mask. Haircut on in-kind path stays in reserve for remaining holders (not the PRISM burn).

6. **NAV / pricing**  
   - Primary: on-chain `exchangeRate()` / `totalReserve()` → display NAV (USDC per share / AUM).  
   - Denominator: `effectiveSupply()` (excludes pending burn inventory) preferred over raw `totalSupply`.  
   - Reserves: `idleHeld(asset)` donation-immune tracked balances.  
   - Frontend **cross-checks** vs DexScreener aggregate spot; warns if divergence is large (~2% UI threshold).  
   - Explicit: static views are **spot marks, not oracles**; mint/redeem math is **execution-based**, not “trust the view.”

7. **No rebalancing**  
   - Weights are **targets at birth**. Live portfolio weights drift with prices. “New version” = new basket deploy.

### 2.4 Fee model

Per-basket **mint/redeem/swap fee** is set by creator at launch, immutable, within bounds **1.00%–3.00%** (`basketFeeBps` 100–300).

**Waterfall (fixed protocol constants; mirrored in frontend `fee-model.ts`):**

| Slice | Share | Notes |
|-------|-------|--------|
| League (optional lineage) | e.g. 5% off top | Only on chains/lineages with league config + creator payout |
| **PRISM burn** | **10%** of fee | Fixed; buy-and-burn path; residual sink for dust |
| Interface kickback | ~5.55% of post-burn | Only if tx tags a frontend address |
| Launcher | ~5.55% of post-burn | Per-basket launcher slot at deploy |
| Creator | 0–30% of remainder | Immutable payout address |
| Holders | Rest of remainder | Claimable fee reserve (`claimFees`) |

No management/subscription fee. Permissionless **cranks** flush PRISM burn / frontend accruals (small bounty).

### 2.5 PRISM (related token, not the basket)

**PRISM** is a separate product Spectrum “powers” fee sinks toward:

- Fixed-supply **Uniswap V4 hybrid** token (ERC-20 + DN404-style fee-share NFTs).  
- Source: `Irora-dev/prismv2contracts` (`PrismHookV2`, airdrop/migration tooling).  
- **V1** suffered a **fee-layer exploit** (helper contracts parked ~2,500 fee-share positions inside the pool; ~40% of fees diverted from holders; supply itself not inflated). Disclosed in `Irora-dev/prism-exploit-disclosure`.  
- **V2** relaunch: new PRISM, 1:1 airdrop to V1 snapshot holders (community messaging July 2026).  
- Basket fees’ burn leg is **PRISM buy-and-burn**, not IndexedEx-style protocol BPT compound.

### 2.6 Frontend / operator model

- **Spectrum Mini** (`Irora-dev/Spectrum`): CC0-style **self-hostable SPA** (React/Vite), no backend.  
- Anyone can host a themed site; factory enumeration lists **all** baskets (no per-site allowlist).  
- Revenue for operators: **interface tag** kickback only — no central registry.  
- Philosophy: **no Spectrum “team” as operator**; author of package claims no admin keys.

### 2.7 Code availability (important)

| Component | Public? |
|-----------|---------|
| Frontend + ABIs + handover docs | Yes — `Irora-dev/Spectrum` |
| PRISM V2 token contracts | Yes — `Irora-dev/prismv2contracts` |
| PRISM V1 exploit analysis | Yes — `Irora-dev/prism-exploit-disclosure` |
| **Spectrum basket / factory Solidity** | **Not found** as a public full source package under Irora-dev at review time; behavior reconstructed from docs, ABIs (`abis-v2.ts`), and addresses |

Deployed factories exist on Base / ETH / Robinhood per frontend config; bytecode can be verified on explorers independently.

---

## 3. What IndexedEx DETF is (brief, for contrast)

Canonical product law: `docs/marketing/DETF_NARRATIVE_SPINE.md` + DETF family PRDs under `contracts/vaults/detf/`.

**DETF (Decentralized ETF product pattern):**

- Diamond **is** the share ERC-20.  
- **Reserve** lives in a **Balancer V3** multi-asset pool (typically weighted), including DETF self-leg + external legs (often **Standard Exchange vault shares**).  
- **Pricing engine = reserve pool** (balances, weights, fees, rate providers) for synthetic valuation and primary mint/burn.  
- Deploy **inert**; **first bond** opens **live** market and builds **protocol-owned** reserve depth (bond NFT lifecycle).  
- **Policy** (default): mint only when synthetically **rich**, burn when **cheap** (deadband; defaults ~±5%). **Open**: no synthetic price restrictions on mint/burn; **no natural expansion**.  
- After deploy: **immutable, unowned** (no instance admin / diamondCut for normal ops).  
- **Premier product:** create **your own DETFs** (multiple families: single SE, multi-vault weighted, stable, mixed-buffer, …).  
- **Protocol DETF:** same design class as a path to **share protocol fees** (not guaranteed yield).  
- Additional mechanisms: **capital seigniorage**, **natural supply expansion** (Policy + mint-rich, bond holders only), **protocol compound** of protocol bond rewards into reserve BPT, optional **rebasing claim** on protocol reserve.

---

## 4. Similarity matrix (why they feel alike)

| Theme | Spectrum | IndexedEx |
|-------|----------|-----------|
| One transferable share over many assets | Yes (fixed basket) | Yes (reserve-backed DETF) |
| Permissionless creation | Factory `deployBasket` | Vault registry / DETF DFPkg deploy path |
| Immutable post-deploy | Yes | Yes (abandon + redeploy) |
| Creator economy | Creator fee share + issuer framing | Create-your-own DETFs; fee oracle on usage |
| Multi-chain incl. Robinhood | Yes (ETH, Base, RH) | Roadmap / product home includes RH Chain first |
| Honest disclaimers | Not fund/ETF/registered; risk pages | Not registered ETF; no peg/APY promises |
| Open frontend / docs | Self-host kit | Research site + monorepo |
| No discretionary portfolio manager | Fixed weights | Pool + modes, not PM rebalance |

These overlaps explain competitive perception in “onchain index / basket / ETF-shaped” narratives — especially on **Robinhood Chain** with stock-linked tokens.

---

## 5. Deep differences (where products diverge)

### 5.1 Economic primitive

| | Spectrum | IndexedEx DETF |
|--|----------|----------------|
| Core act | Hold **pro-rata claims** on a static multi-asset inventory; mint dilutes into more of those assets | Hold a **monetary unit** priced by a **live AMM reserve**; mint/burn is **seigniorage-style** primary market vs that reserve |
| Backing model | **Full collateralization** of constituents in the basket contract | **Reserve pool** with DETF self-leg + external legs; synthetic price can deviate; Policy gates seigniorage |
| Closest TradFi analogy | Static **unit investment trust / fixed basket ETF** | **Reserve-backed currency / OHM-class unit** productized as DETF (without claiming Olympus affiliation) |

### 5.2 Market structure & AMM choice

- **Spectrum:** Uniswap **V4 hook-as-product**. Primary liquidity is the basket’s own USDC pair; legs are acquired on external Uni V2/V3/V4 pools at mint/redeem time.  
- **IndexedEx:** **Balancer V3** as continuous multi-asset pricing and reserve; Standard Exchange vaults abstract Uni/Aero/Camelot/Aave legs; DETF talks SE + Balancer, not venue brands in product law.

### 5.3 Lifecycle and capital formation

- **Spectrum:** Deploy → Dutch auction fee → pool initialized → mint/redeem when live. No “inert until bond.”  
- **IndexedEx:** **Inert → first bond → live**. Bonding builds **protocol-owned depth** and unlocks seigniorage surfaces; free holders ≠ bond reward path.

### 5.4 Mint / burn policy

- **Spectrum:** Mint/redeem whenever markets and leg routes allow; fee applies; **no** Policy deadband on “rich/cheap synthetic.”  
- **IndexedEx:** **Policy** restricts primary mint/burn by **synthetic** vs thresholds; **Open** removes those restrictions but forbids natural expansion. First bond synthetically ungated.

### 5.5 Rebalancing and composition drift

- **Spectrum:** **Cannot rebalance**; weights fixed; live weights drift.  
- **IndexedEx:** Reserve **weights and balances evolve** with joins, exits, and secondary swaps; multi-vault families encode different composition goals (weighted, stable, mixed buffer).

### 5.6 Settlement and user routes

- **Spectrum:** User-facing settlement is **USDC** (plus in-kind legs).  
- **IndexedEx:** Preferred routes are **vault share ↔ DETF**; rate-asset mint often out of scope unless a zap family allows it; burn paths family-specific (e.g. mixed-buffer burns buffer only).

### 5.7 Fee sinks and protocol token

- **Spectrum:** Hard-wired **PRISM burn** + frontend launcher/creator/holder waterfall.  
- **IndexedEx:** **Vault fee oracle** / usage fees / seigniorage splits; protocol rewards **compound into reserve BPT**; Protocol DETF as **fee-share path** — not a fixed-supply V4 fee hybrid as the core sink.

### 5.8 Exit guarantees

- **Spectrum:** **Sacred in-kind** `redeemInKind` independent of pools.  
- **IndexedEx:** Exit via burn routes, bond sell → claim, reserve unwind toward rate asset(s) when claim package is wired — design differs by family; not marketed as a single universal in-kind of every leg.

### 5.9 Nested strategy vaults / yield legs

- **Spectrum:** Legs are **spot tokens** with Uni liquidity (RWA/stock tokens appear in marketing when those ERC-20s exist on chain).  
- **IndexedEx:** First-class **Standard Exchange** vault shares, rate providers for mark integrity, nested DETFs/DualLiquidity as composition matrix — strategy legs under the DETF.

### 5.10 Trust / security history (PRISM)

- Spectrum’s fee token **PRISM V1** had a documented **fee-layer design exploit** (not supply mint). V2 is a relaunch/airdrop.  
- IndexedEx DETF trust story centers on **immutable diamonds**, production-first tests, and synthetic gates — different attack surface (Balancer, diamond, bond NFT, SE opacity).

---

## 6. Feature-level comparison table

| Feature | Spectrum | IndexedEx DETF |
|---------|----------|----------------|
| Share token | ERC-20 basket (= V4 hook) | Diamond ERC-20 |
| Reserve engine | Inventory in basket + external leg swaps | Balancer V3 pool |
| Fixed weights at deploy | Yes | Deploy-time pool config; market can reweight balances |
| Rebalance | No | Via pool activity / family design |
| Bonding / POL | No | Yes (first bond + bond NFT) |
| Synthetic mint gates | No | Policy yes / Open no |
| Natural expansion | No | Policy + mint-rich only |
| Protocol compound | PRISM burn path | Compound protocol rewards → reserve BPT |
| In-kind redeem | Yes (`redeemInKind`) | Family-specific claim/unwind |
| Create your own | Yes (factory) | Yes (DETF packages / types) |
| Fee token | PRISM | Protocol DETF / fee oracle paths |
| Self-host frontend kit | Spectrum Mini (public) | Not the same product; IndexedEx app + research site |
| Basket Solidity public | Not found (ABI only) | Full monorepo contracts |

---

## 7. Competitive implications (internal)

1. **Do not treat Spectrum as a clone of DETF.** Shared category language (“onchain ETF / basket / one token many assets”) will confuse users; differentiation should stress **reserve-pool seigniorage + bonding + Policy/Open** vs **fixed-weight USDC-settled V4 baskets**.  
2. **Robinhood Chain is contested surface.** Both aim multi-asset / stock-linked narratives there. Spectrum already shows community basket launches on RH (2026-07-30 posts).  
3. **Immutability + permissionless create** is table stakes for both; compete on **mechanism honesty** (what mint does to backing), **exit paths**, and **strategy vault composition**.  
4. **PRISM risk narrative** is Spectrum-specific; IndexedEx should not inherit it, but can contrast **fee-to-reserve compound** vs **fee-to-external token burn**.  
5. **Open-source marketing:** Spectrum ships a strong “anyone hosts a frontend” story. IndexedEx’s public research site is education-first; product deploy UX is a separate maturity curve.  
6. **Engineering opacity:** Until Spectrum publishes basket Solidity, comparisons of edge cases (donation attacks, first-mint, fee cranks) rest on docs/ABIs — treat with appropriate uncertainty.

---

## 8. Source map

| Source | Use |
|--------|-----|
| https://spectrumindexes.xyz/docs | Basket definition, NAV, fees, hookData, discovery |
| https://spectrumindexes.xyz/faq | Plain-language mint/redeem, fees, exit |
| https://spectrumindexes.xyz/ (sitemap: launch, earn, learn, integrate, risk, …) | Product surface |
| `Irora-dev/Spectrum` README + `app/handover/*` | Architecture, invariants, deploy auction, operator model |
| `Spectrum/app/src/lib/spectrum/fee-model.ts` | Exact bps constants |
| `Spectrum/app/src/lib/chain/deployments.json` | Factory/router addresses per chain |
| `Irora-dev/prismv2contracts` | PRISM V2 design |
| `Irora-dev/prism-exploit-disclosure` | PRISM V1 fee-layer incident |
| X @spectrumindexes (2026-07) | V2 multi-chain launch, RH baskets, Prism relaunch |
| IndexedEx `docs/marketing/DETF_NARRATIVE_SPINE.md` | DETF product law for comparison |

---

## 9. Open questions / follow-ups

1. Publish or reverse-engineer **full basket + factory Solidity** (explorer verified source) for parity review.  
2. Confirm live **PRISM burn realization** (handover notes historically said burn path “wired / in-flight”).  
3. Measure actual **mint slippage and leg routing** on Base vs RH for multi-leg baskets.  
4. Legal/regulatory framing: Spectrum’s marketing says “ETF” on X while product docs forbid that word — IndexedEx should keep **Decentralized ETF product pattern** disclaimers consistent.  
5. Delete `tmp/spectrum-review/` when this research is done to avoid accidental commits of third-party trees.

---

## 10. One-paragraph differentiation (usable copy draft)

**Spectrum** lets anyone deploy a **fixed-weight basket token** that is its own Uniswap V4 market against USDC: mint by paying USDC while the hook buys the legs, redeem to USDC or **always** exit in-kind, with fees shared among holders, creators, frontends, and a **PRISM** burn. **IndexedEx DETFs** let anyone stand up a **reserve-backed decentralized ETF unit** whose share is priced by a **live Balancer multi-asset reserve**, opened by **bonding** into protocol-owned depth, with **Policy or Open** mint/burn rules, optional **bond-holder expansion**, and composition via **strategy vault legs** — not a static USDC-settled shopping list of tokens.
