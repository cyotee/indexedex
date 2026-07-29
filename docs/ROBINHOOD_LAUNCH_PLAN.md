# IndexedEx — Product Expansion Launch Plan

**Status:** Discussion draft — 2026-07-26 (comms: no venue/asset-brand names in public copy)  
**Internal track code:** **L2-E** (expansion permissionless L2; chain id + RPCs live in eng constants only)  
**Supersedes for L2-E track:** day-1 *product* home; does **not** silently cancel locked Base CCA params unless §6 decisions say so  
**Related:** [`LAUNCH_PLAN.md`](./LAUNCH_PLAN.md) (Base CCA + RICHAI; fees → **SingleVault DETF (RICH)** donation), [`CCA_FDV_WORKSHOP.md`](./CCA_FDV_WORKSHOP.md), DETF PRDs under `contracts/vaults/detf/**`

### Comms rule (locked for this track)

| Layer | Names allowed |
|-------|----------------|
| **Public launch copy** | IndexedEx, Crane, DETF, OHM (category), Olympus (founder provenance), Balancer V3, RICH / RICHAI, Bankr, Uniswap CCA (Base raise), explorers/addresses |
| **Public launch copy — avoid** | Exchange-chain brand names; issuer “stock token” product names; equity ticker laundry lists as the hero story |
| **Internal eng / legal** | Full chain id, asset registries, compliance notes (this file §1 / §2.4 / §7) |

Public story = **Olympus → launch your own OHM → Balancer reserves → RICH**. Venue and underlying asset classes stay secondary (“permissionless L2,” “multi-asset reserves,” “market-linked ERC-20s”) unless a later decision re-opens brand co-marketing.

---

## 0. One-line thesis

> IndexedEx deploys **Balancer V3** and **DETFs** — the modern way to **launch your own OHM** against real multi-asset reserve liquidity — while **RICH** is the capital token whose **liquidity receives protocol fee-make**: fees from other vaults/DETFs **donate into RICH liquidity** through a **SingleVault DETF for RICH**.

**Founder line (use in launch materials):**

> IndexedEx is built by the **original developer of Olympus**. A **DETF** is how you **launch your own OHM** — seigniorage, bonding, and reserve-backed monetary policy as a **deployable product**, not a one-off protocol.

---

## 0.1 Olympus → DETF (launch narrative — core differentiator)

### Why this belongs front-and-center

Most launches are **tickers**. IndexedEx is **monetary infrastructure**: the same design family that made **OHM** a category (reserve-backed seigniorage currency, bonding into protocol-owned depth, policy around mint/burn) — generalized so **anyone** can stand up that pattern for **chosen reserves** (crypto pairs, multi-vault compositions, market-linked ERC-20 baskets).

| Audience | What they should hear |
|----------|------------------------|
| **DeFi natives (OHM-era)** | “Same *class* of system as Olympus — reserve, bond, seigniorage — productized as DETF factories.” |
| **Multi-asset / RWA builders** | “Launch a **reserve-backed basket currency**, not just LP a pair.” |
| **Agents** | “Deploy a DETF instead of rebalancing; hold RICH where fee-make deepens RICH liquidity.” |
| **Skeptics of (3,3)** | “Not a rehash of rebase memes: **immutable instances**, pool-priced mint/burn gates, transparent Balancer reserve, no fake APY.” |

### Conceptual map (OHM family → DETF — for *marketing*, not 1:1 code claims)

| Olympus-class idea | DETF / IndexedEx analogue | Launch wording |
|--------------------|---------------------------|----------------|
| **Protocol token as money** | DETF diamond **is** the share ERC-20 (`detfToken`) | “Your DETF *is* the currency of that reserve.” |
| **Treasury / reserves** | Balancer V3 **weighted reserve** (protocol-owned BPT path + legs) | “Reserve lives in a real AMM vault — not a black-box treasury multisig story alone.” |
| **Bonding → POL** | Bond NFT, first bond → **live**, principal into protocol reserve | “Bond in; deepen protocol-owned reserve; go live.” |
| **Seigniorage mint / redeem** | Mint when synthetic **> mintThreshold**; burn when **< burnThreshold** | “Policy bands on mint/burn — price from the pool, not a dashboard.” |
| **Staking / claim on treasury** | Rebasing claim token / NFT sale → claim redeem (family-dependent) | “Claim on protocol reserve — not free floating emissions.” |
| **One OHM for the world** | **Many DETFs** — each a self-contained monetary unit over its legs | “**Launch your own OHM** for *your* basket.” |
| **Runway via OHM sale** | **RICH** capital formation; long-term fees from the stack **donate into RICH liquidity** | “RICH funds the protocol; other DETFs’ fees make RICH liquidity.” |

### What we are **not** claiming

| Do say | Do not say |
|--------|------------|
| Original Olympus developer building the next generation of reserve-backed seigniorage products | “This is OlympusDAO” / “official OHM” / “OHM v3” |
| DETF = **launch-your-own-OHM pattern** (reserve + bond + seigniorage) | “Guaranteed rebase yield” / “(3,3) returns” / risk-free treasury |
| Pool-implied pricing + explicit thresholds | “Backed 1:1 like a stablecoin” (unless a specific stable-family PRD says so) |
| Immutable unowned DETF instances after deploy | Admin mint / discretionary policy after launch |
| Multi-asset / market-linked ERC-20s as reserve legs | “You own the offchain underlying via OHM/DETF” |

### Primary taglines (Olympus-forward)

Pick 1–2 for launch week; keep the rest as secondary:

1. **“Launch your own OHM.”** — DETF factories on IndexedEx.  
2. **“Olympus, productized.”** — Reserve-backed seigniorage as deployable DETFs.  
3. **“From one OHM to many.”** — Every basket can be its own monetary unit.  
4. **“Built by Olympus’s original developer.”** — DETFs for multi-asset reserves.  
5. **“Bond. Mint. Reserve.”** — DETF on Balancer V3.  
6. **“RICH funds the protocol that lets others launch OHMs — and their fees make RICH liquidity.”**

### Story arc with Olympus in the lead

```text
1. Provenance   →  Original Olympus developer; OHM was one seigniorage currency.
2. Product      →  DETF = launch your own OHM (reserve, bond, mint/burn policy).
3. Infra        →  Balancer V3 as multi-asset reserve / DEX engine (where missing).
4. Market       →  Multi-asset baskets as first-class reserve legs.
5. Capital      →  RICH sale — capital + center of fee-make liquidity (not "the next OHM ticker" alone).
6. Agents       →  Deploy / bond; hold RICH for fee-make depth; invited arb keeps reserves honest.
```

**RICH positioning relative to OHM language:**

- **Each DETF share** = the “OHM” of *that* reserve (seigniorage unit).  
- **RICH** = protocol capital token + **economic center of fee-make**: fees from **other** vaults/DETFs are routed to **`donation` into RICH liquidity**.  
- **Launch fee sink:** **SingleVault DETF for RICH** (`SingleVaultDetf`) — **accrues** those donations (reserve / make) — not a cash dividend on free-floating RICH. DualLiquidityLinked is **not** the day-1 fee sink.  
- Do **not** call RICH “the new OHM” (collapses platform capital with per-reserve seigniorage).

---

## 1. Why expansion L2 (working thesis) — internal

### 1.1 Target chain facts (eng only; not for public brand copy)

| Item | Fact |
|------|------|
| **What** | Permissionless EVM L2 (Orbit-class), ETH gas, settles to Ethereum |
| **Mainnet** | Live mid-2026 |
| **Chain ID** | **4663** (constants / Foundry alias only) |
| **Anchor assets** | Market-linked ERC-20s (economic exposure products; **not** legal ownership of offchain underlyings; **jurisdiction-gated** by issuer/venue) |
| **Day-1 DeFi** | Uniswap-class AMM present; lending/oracle stack partial; **no Balancer V3** as a default chain product |
| **Agent surface** | Multi-chain agent wallets; agent token launchpads on-chain |

### 1.2 Why this fits IndexedEx

| IndexedEx strength | L2-E fit |
|--------------------|---------|
| **DETF** (diamond = share ERC-20, seigniorage vs Balancer weighted reserve) | Multi-asset legs are **natural DETF reserves**: sector baskets, dual crypto+market exposure |
| **Standard Exchange vaults** | Wrap liquid pairs / lending legs; DETF stays opaque to concrete DEX types |
| **Balancer V3 dependency** | Chain gap → **we deploy the missing stack** and own multi-asset DEX narrative |
| **Fee-make / RICH** | Other vaults/DETFs → donate into **RICH liquidity** via **SingleVault DETF (RICH)** |
| **Agent thesis** | Agents deploy DETFs instead of continuous rebalancing; optional RICH for fee-make depth |

### 1.3 Strategic positioning (public narrative)

**Do not** launch as “another meme coin.”

**Do** launch as **four** stacked claims (Olympus first):

0. **Provenance / category:** Built by the **original Olympus developer**. A **DETF is how you launch your own OHM** — seigniorage currency over a real reserve, bonding into protocol-owned depth, mint/burn policy from pool pricing.  
1. **Infrastructure:** IndexedEx / Crane deploy **Balancer V3** (Vault + factories + routers) — the multi-asset reserve/DEX engine DETFs need where it is not already native.  
2. **Product:** **DETFs over multi-asset reserves** — basket “OHMs,” dual-liquidity units, multi-vault weighted reserves.  
3. **Capital:** **RICH** — transparent sale + post-sale markets; protocol fees from other vaults/DETFs **donate into RICH liquidity** via **SingleVault DETF (RICH)**.

**Tagline options (Olympus-forward preferred for launch week):**

- “**Launch your own OHM.**”  
- “Built by Olympus’s original developer. DETFs: seigniorage as a product.”  
- “Bond into reserve. Mint against the pool. Your basket, your OHM.”  
- “Balancer V3 + DETFs — fees make RICH liquidity.”  
- “Reserve-backed mint/burn. Multi-asset by design.”

### 1.4 Competitive context (honest)

| Player | Role | Our differentiation |
|--------|------|---------------------|
| **Uniswap-class AMMs** | Spot pairs | We are **not** trying to win single-hop meme swaps. We own **weighted multi-asset pools + vault-native routing**. |
| **Agent launchpads** | Meme / social tokens | Attention channel for **RICHAI-class** or satellite tokens; **not** the RICH capital raise mechanism. |
| **Lending protocols** | Yield / collateral | SE vaults can sit **beside** lending; DETFs compose reserves without becoming a bank. |
| **Issuer apps** | Gated asset UX | We serve **permissionless DeFi users + agents** holding onchain assets; we do not claim to be the issuer. |

---

## 2. Product architecture (L2-E)

### 2.1 Layer cake

```text
┌─────────────────────────────────────────────────────────────┐
│  Agents / UI / Bankr / agent launchpads (attention)         │
├─────────────────────────────────────────────────────────────┤
│  IndexedEx DETFs  (baskets, dual-liquidity, multi-SE)       │
│    — diamond share ERC-20, inert → live via first bond      │
├─────────────────────────────────────────────────────────────┤
│  Standard Exchange vaults  (pair legs, WETH, stables)       │
├─────────────────────────────────────────────────────────────┤
│  Balancer V3  (Vault + Weighted/Stable factories + SE Router)│  ← "we launch a DEX"
├─────────────────────────────────────────────────────────────┤
│  Existing Uni liquidity — SE legs / arb                     │
├─────────────────────────────────────────────────────────────┤
│  Market-linked ERC-20s + WETH/ETH + stables (base assets)   │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Day-1 product surface (recommended)

| Product | Role | Priority |
|---------|------|----------|
| **Balancer V3 core** | Vault, WeightedPoolFactory, routers, Permit2 wiring | **P0** — unlocks everything |
| **IndexedEx manager + registry + fee oracle** | Deploy path for vaults/DETFs | **P0** |
| **SE vaults on Uni legs** | Wrap liquid Uni pools | **P0** |
| **SE vaults on Balancer legs** | Once Balancer pools exist | **P1** |
| **Multi-vault weighted DETF** | Basket: multiple SE legs + weights | **P0 product** |
| **Single-SE DETF** | Simplest gold path if multi-vault not ready | **P0 fallback** |
| **SingleVault DETF (RICH)** | **Launch fee sink** — accrues donations; makes RICH-linked liquidity | **P0 product** (with RICH capital) |
| **DualLiquidityLinked** | Optional later multi-leg product — **not** day-1 fee sink | **P2** |
| **RICH** | Capital token + center of fee-make liquidity | **P0 capital** |

**Role names in code (mandatory):** `rateAsset`, `pairToken`, `underlyingVault`, `vaultShare`, `detfToken`, `reservePool` — never brand external product tickers into DETF interfaces.

### 2.3 Flagship DETF concepts (marketing + deploy matrix)

Ship **one** hero product; keep others as roadmap.  
**Marketing frame for every concept:** each live DETF is a **self-contained OHM-class unit** for that reserve — “launch your own OHM” for *this* basket.

| Concept | Composition (illustrative) | Why | Olympus-class pitch |
|---------|----------------------------|-----|---------------------|
| **Multi-asset basket DETF** | Weighted SE legs on liquid market-linked ERC-20s + rateAsset (WETH or USDC) | Clean “basket currency” story | “An OHM whose treasury is a multi-asset basket.” |
| **Market × ETH DETF** | Market-linked SE + WETH SE in weighted reserve | Bridges crypto capital to multi-asset exposure | “Seigniorage unit spanning ETH + market legs.” |
| **Single-leg vault DETF** | One SE → single SE DETF | Simplest demo | “Smallest OHM demo — one reserve leg.” |
| **SingleVault DETF (RICH)** | Single SE (RICH-linked) + weighted reserve | **Protocol fee sink at launch** | “OHM-class unit that accrues stack fees into RICH liquidity.” |

**Pricing engine remains the Balancer reserve pool** — no off-pool multi-asset FX ledger (AGENTS.md DETF rules).

### 2.4 Asset integration constraints (internal / legal)

| Constraint | Implication |
|------------|-------------|
| **Not legal ownership of offchain underlyings** | Public copy: **onchain economic exposure / reserve assets**, never “you own the offchain security via DETF.” |
| **Jurisdiction gates** | Eligibility of underlying assets is issuer/venue-defined; DETF does not change that. Prefer careful geo distribution for market-linked products. |
| **Transfer / compliance hooks** | Verify contracts for transfer restrictions, rebases, fee-on-transfer before SE/DETF wiring; fail closed in tests. |
| **Oracles / rates** | Prefer **pool-implied + rate providers** already in Balancer path; do not invent a bespoke offchain-price oracle product day-1. |
| **Liquidity reality** | Day-1 depth may be thin; size DETF thresholds for **illiquid legs**; invite arb, do not promise tight spreads. |

---

## 3. Balancer V3 as “DEX launch”

### 3.1 Why claim “we launch a DEX”

Target L2 already has **Uniswap-class** spot AMMs. Claiming “we launched *the* DEX” is false.

Claiming **“we brought Balancer V3 — multi-asset weighted and stable pools — to this chain”** is true and differentiated:

- DETF **requires** Balancer V3 reserves.  
- Builders get a second AMM family (weighted baskets, stable-like composition) without waiting for an official Balancer Labs deploy.  
- Narrative: **infra first, product second, token third** (after Olympus provenance).

### 3.2 Deploy scope (Balancer wave)

| Wave | Components | Notes |
|------|------------|--------|
| **B0 — Core Vault** | Balancer V3 Vault (Crane-vendored port), authorizer, protocol fee controller as required by port | Foundation; CREATE3 / Crane deploy path |
| **B1 — Pool factories** | WeightedPoolFactory (must); StablePoolFactory (nice-to-have) | DETF default = weighted |
| **B2 — Routers** | Vault routers + **IndexedEx BalancerV3 Standard Exchange Router** | User swaps + vault orchestration |
| **B3 — Rate providers** | StandardExchangeRateProvider DFPkg | DETF mint/burn pricing honesty |
| **B4 — Seed pools** | 2–5 reference pools (WETH/stable, 1–2 market/WETH, optional multi-asset) | Demo depth only; size at runtime |

**Anti-pattern:** ship Balancer Vault only and call it “DEX live.” Minimum public claim = Vault + **one** WeightedPoolFactory + router + **one** live pool with explorer links.

### 3.3 Crane / IndexedEx eng reality

- Balancer V3 is already vendored under `lib/crane/contracts/external/balancer/v3/`.  
- IndexedEx already integrates Vault + SE router + DETF families.  
- L2-E work is **chain constants + deploy scripts + fork/hermetic verification**, not a greenfield port — unless Orbit-specific quirks appear (gas token, precompiles, CREATE2 salts).  
- Follow **Crane CREATE3** + IndexedEx **manager vault registry** for vault/DETF packages; never `new` facets/DFPkgs.

### 3.4 DEX messaging rules

| Allowed | Forbidden |
|---------|-----------|
| “Balancer V3 deployed by IndexedEx” + chain explorer links | “Official Balancer Labs launch” (unless they co-announce) |
| “Multi-asset weighted pools for DETF reserves” | “We replace Uniswap” |
| “Primary liquidity engine for IndexedEx DETFs” | “Guaranteed APY” |
| Explorer addresses + pool list | Unverified “TVL soon” screenshots |
| Venue brand names in public launch posts | (per top-of-file comms rule) |

---

## 4. RICH token sale + L2-E seed

### 4.1 Tension with existing Base CCA plan

Locked Base plan ([`LAUNCH_PLAN.md`](./LAUNCH_PLAN.md)):

- RICH **1B** fixed, deploy **Ethereum** via Crane ERC20PermitDFPkg  
- **100M (10%)** sold via **Uniswap CCA on Base**  
- Floor **\(5\times10^{-7}\) ETH/RICH** (~$950k FDV at floor)  
- Then **RICHAI on Bankr** (Base)

**L2-E capital options** (pick in §6):

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| **A. L2-E product, Base capital (default dual-track)** | Keep Base CCA as **raise**; bridge/mint L2-E representation for product + fee legs | CCA tool already designed; L2-E focus is DETF/DEX | Two chains to operate; attention split |
| **B. L2-E-first capital** | Sell RICH primarily into L2-E liquidity; Base CCA deferred or smaller | Single “home” story | **No CCA** known on L2-E today; harder price discovery narrative |
| **C. Dual sale** | Base CCA 10% **and** separate L2-E tranche from 30% liquidity / 58% dry | More markets | Fragmented float; messaging complexity |

**Recommendation for discussion:** **Option A with L2-E-native RICH representation**, unless research shows CCA (or equivalent) is live on chain 4663 — then revisit Option B.

### 4.2 Capital-raise mechanisms on L2-E

| Mechanism | Fit for RICH capital raise | Notes |
|-----------|----------------------------|--------|
| **Uniswap CCA** | Best if available on 4663 | Confirm factory presence; if absent, **cannot** copy Base sheet as-is |
| **Manual Uni V3/V4 seed + gradual sell** | Weak capital raise | Looks like a dump; avoid as primary |
| **Agent launchpad deploy** | **Agent attention only** | Fixed meme mechanics; **do not** use as RICH capital raise |
| **LBP / custom auction** | Possible | High eng + legal cost |
| **OTC / private** | Bridge runway | Dilutes “permissionless launch” story |
| **Keep Base CCA; seed L2-E post-clear** | **Recommended default** | Raise on Base CCA → bridge RICH + ETH proceeds slice to L2-E → seed Balancer/DETF |

### 4.3 Recommended capital path (dual-track default)

```text
Ethereum:  Deploy RICH (1B, Permit DFPkg) — canonical supply
    │
    ├─► Base: Superchain-bridge 100M → Uniswap CCA (locked params)
    │         Clear → ops 6.5 ETH + liquidity remainder (LAUNCH_PLAN)
    │
    └─► L2-E (4663): bridge / canonical representation of RICH
              │
              ├─► Seed Balancer pools + **SingleVault DETF (RICH)** fee-sink
              ├─► Secondary market for agents (not the primary auction)
              └─► Optional later: L2-E-native secondary sale of a *new* tranche
                  only after Base CCA ends and L2-E product is live
```

**If pure L2-E-first is required:** freeze a decision workshop (floor, % sold, venue) analogous to [`CCA_FDV_WORKSHOP.md`](./CCA_FDV_WORKSHOP.md), and treat Base CCA as superseded in the decision log.

### 4.4 Supply allocation (inherit unless revised)

| Bucket | % of 1B | L2-E usage |
|--------|---------|------------|
| Base CCA | 10% | Capital raise (default track) |
| Liquidity reserve | 30% | **Primary L2-E seed source** post-raise (runtime-sized) |
| Team | 2% | Vest unchanged (2y / 30d cliff) |
| Unallocated | 58% | Hold dry; optional later ETH or L2-E tranche |

### 4.5 RICH value prop (Olympus-aware copy)

**Publishable:**

> **RICH** is IndexedEx’s capital token. The CCA is capital formation and price discovery. Long-term, **fees from other vaults and DETFs are routed to donate into RICH liquidity** through a **SingleVault DETF for RICH** — that DETF **accrues** the make (buyback-and-make), not a fixed cash dividend on free-floating RICH.

**Clarify in the same breath:**

> Each **DETF share** is the seigniorage currency of *its* reserve. **RICH** is not “OHM rebranded.” Fee-make supports **RICH liquidity** and the **SingleVault DETF** reserve — do not promise APR until donation → depth is live and measurable.

**Do not claim until live:** measured fee → donation → RICH pool/DETF TVL, or any APR; “(3,3)” returns; cash dividends.

### 4.6 RICHAI / agents

| Token / channel | Role on L2-E track |
|-----------------|--------------------|
| **RICHAI** | Still **after** primary capital clear (Base CCA or L2-E auction); agent surface — Bankr and/or on-chain agent launchpads as a *second* agent ticker, not a second capital raise |
| **Agent launchpads** | Announce DEX + DETF + “how agents hold RICH”; optional satellite memes **not** branded as RICH |
| **Gitlawb Ads** | Tips point to explorer addresses + DETF/OHM docs during launch week |

---

## 5. Phased launch plan

```text
Phase R0 — Research & decisions (1–2 weeks calendar, parallel eng)
  [ ] Confirm chain 4663 RPC, explorer, WETH, Multicall, Permit2 addresses
  [ ] Inventory market-linked asset registry (canonical contracts) + transfer rules matrix
  [ ] Confirm presence/absence of: Balancer V3, Uni V2/V3/V4, CCA factory, official bridges
  [ ] Legal/comms: asset eligibility + non-ownership disclaimer; public copy avoids venue brands
  [ ] Lock topology: dual-track (A) vs L2-E-first capital (B) — §6
  [ ] Write L2-E chain constants + Foundry RPC alias (internal name only)

Phase R1 — Balancer V3 + Crane foundation (DEX claim)
  [ ] Deploy Crane CREATE3 + diamond package factory
  [ ] Deploy Balancer V3 Vault + WeightedPoolFactory (+ Stable if in scope)
  [ ] Deploy Permit2 if missing; wire routers
  [ ] Deploy IndexedEx Balancer SE Router DFPkg path
  [ ] Seed ≥1 Weighted pool (WETH/stable or WETH/market-leg); publish addresses
  [ ] Hermetic + L2-E fork tests: swap, join/exit, rate provider smoke
  [ ] Public: “Balancer V3 is live” + address book (no venue-brand requirement)

Phase R2 — IndexedEx core + SE vaults
  [ ] IndexedexManager, FeeCollector, Vault Registry, fee oracle
  [ ] SE vault packages for available AMMs (Uni first; Balancer SE second)
  [ ] StandardExchangeRateProvider packages for DETF legs
  [ ] Kill-switch path verified on L2-E deploy
  [ ] Tokenlists + frontend chain artifacts for 4663

Phase R3 — Flagship DETF (product)
  [ ] Choose hero: Multi-vault weighted basket OR single-SE gold path
  [ ] Deploy inert DETF → first bond bootstrap → live mint/burn under thresholds
  [ ] Preview == execution tests on L2-E fork
  [ ] Agent docs: deposit vault shares → mint DETF; bond/claim if in scope
  [ ] Public: “DETF live — launch your own OHM” (demo links)

Phase R4 — RICH capital (timing depends on §6 topology)
  Dual-track A (recommended):
    [ ] Execute Base CCA path per LAUNCH_PLAN (deploy ETH → bridge → CCA)
    [ ] Post-clear: bridge RICH + liquidity slice to L2-E
    [ ] Seed L2-E Balancer / **SingleVault DETF (RICH)** fee-sink; size at runtime
  L2-E-first B (only if decided):
    [ ] Workshop floor / % / venue
    [ ] Deploy + sell + seed without relying on Base CCA

Phase R5 — Attention & agents
  [ ] Announcement stack: Olympus provenance → OHM category → DEX addresses → DETF → RICH
  [ ] Bankr / agent channels (product links, not fake APY)
  [ ] Optional RICHAI after capital clear
  [ ] Gitlawb small USDC test pointing at DETF/OHM docs

Phase R6 — Flywheel
  [ ] Fee collector → donation into **SingleVault DETF (RICH)** → RICH liquidity measurable
  [ ] Arb invitation docs for SE mispricings
  [ ] Expand basket DETFs; more Balancer pool types
```

### 5.1 Suggested calendar shape (not locked)

| Week | Theme |
|------|--------|
| **W0** | R0 research lock + eng bootstrap scripts |
| **W1–W2** | R1 Balancer + Crane live |
| **W2–W3** | R2 manager + SE vaults |
| **W3–W4** | R3 hero DETF bootstrap + public demo |
| **Parallel or W4+** | R4 RICH sale (Base CCA and/or L2-E seed) |
| **Post-clear** | R5–R6 marketing + fee-make flywheel |

Do **not** open a capital auction before R1 addresses are public and R3 demo path is dry-runnable (even if donation is still roadmap).

### 5.2 Success criteria

| Phase | Done means |
|-------|------------|
| R1 | Explorers show Vault + factory + ≥1 pool; external user can swap |
| R2 | Manager deploys a vault via registry; SE deposit/withdraw works |
| R3 | DETF inert → live via first bond; mint/burn with preview match under thresholds |
| R4 | RICH tradeable with disclosed supply; L2-E seed sized from real proceeds |
| R5 | Agents can find addresses via docs/Bankr; no APR fabrications; public copy follows comms rule |
| R6 | At least one fee → make event observed onchain |

---

## 6. Decision log (L2-E track)

| Date | Decision | Status |
|------|----------|--------|
| 2026-07-26 | Product expansion on permissionless L2 **4663** (internal: L2-E) | **Proposed** |
| 2026-07-26 | Deploy **Balancer V3** as IndexedEx-led **DEX/infra** claim | **Proposed** |
| 2026-07-26 | Flagship product = **DETF over multi-asset reserves**, not meme launchpad | **Proposed** |
| 2026-07-26 | Capital topology default = **dual-track A** (Base CCA raise + L2-E product/seed) | **Proposed** — open |
| 2026-07-26 | Agent launchpads / Bankr = **attention**, not RICH capital raise | **Proposed** |
| 2026-07-26 | Inherit RICH 1B / 10% CCA / floor workshop **unless L2-E-first workshop supersedes** | **Proposed** |
| 2026-07-26 | **Launch narrative lead:** founder = **original Olympus developer**; DETF = **“launch your own OHM”**. RICH = capital + fee-make center, not OHM rebrand. | **Proposed** — ready to lock |
| 2026-07-26 | **Fee model:** fees from other vaults/DETFs **donate into RICH liquidity**; fee-sink DETF **accrues** (not free-RICH cash dividend). | **Decided** |
| 2026-07-26 | **Launch fee-accrual DETF = SingleVault DETF for RICH** (`SingleVaultDetf`) — DualLiquidityLinked not day-1 fee sink | **Decided** |
| 2026-07-26 | **Public copy avoids** venue-chain brand names and issuer “stock token” product framing; use multi-asset / OHM language | **Proposed** — ready to lock |
| — | Exact hero DETF composition (legs, weights, rateAsset) | **Open** |
| — | Bridge design for RICH L1 ↔ L2-E | **Open** |
| — | Whether Balancer Labs co-announce or silent community deploy | **Open** |
| — | Geo / eligibility policy for market-linked asset products | **Open (legal)** |

---

## 7. Engineering workstreams (checklist)

### 7.1 Chain integration

- [ ] `foundry.toml` RPC + block explorer verify config for 4663  
- [ ] Constants file: WETH, Permit2, Uni factories, asset registry  
- [ ] Deploy scripts under `scripts/foundry/` staged for L2-E  
- [ ] Frontend: chain 4663 in wagmi + address artifacts  

### 7.2 Balancer deploy pack

- [ ] Script sequence: Vault → factories → routers → sample pool  
- [ ] Address book `docs/l2e/deploy_addresses.md` (or private ops sheet) when live  
- [ ] Fork tests: `test/foundry/fork/...` for L2-E  

### 7.3 DETF product pack

- [ ] SE TestBase matrix for market-linked asset transfer quirks  
- [ ] Multi-vault weighted DETF PkgArgs for N legs  
- [ ] Bond NFT + rebasing claim only if family PRD requires v1  

### 7.4 RICH ops

- [ ] Canonical ETH deploy scripts (already planned)  
- [ ] L2-E representation path + liquidity seed runbook  
- [ ] Comms: multi-chain token addresses (ETH / Base / L2-E) — one canonical story  

---

## 8. Marketing & launch week narrative

### 8.1 Story arc (order of announcements)

1. **Provenance:** “Built by the original Olympus developer.”  
2. **Category:** “A DETF is how you **launch your own OHM**.”  
3. **Infra:** “Balancer V3 is live.” (addresses)  
4. **Product:** “First DETF(s) live — bond, mint, reserve.” (demo)  
5. **Capital:** “RICH market / sale open — capital for the protocol; fees from the stack make RICH liquidity.”  
6. **Agents:** “Deploy your own OHM-class unit; optional RICH for fee-make depth.”  

Do **not** open with ticker-only memes. Do **not** lead public posts with venue-chain or issuer product brands.

### 8.2 Channels

| Channel | Use |
|---------|-----|
| Docs + explorer | Canonical addresses + DETF/OHM explainer |
| X / CT | Olympus lineage + “launch your own OHM” + demos |
| OHM / seigniorage diaspora | Founder credibility; invite technical readers |
| Bankr / agent surfaces | Agent discovery; same OHM framing, short form |
| Gitlawb Ads | Tips: “launch your own OHM” + product links |
| BattleChain | Security promo (testnet), not L2-E substitute |

### 8.3 Copy constraints

- **Public:** no venue-chain brand names; no issuer “stock token” product framing.  
- Onchain assets in reserves ≠ legal ownership of offchain underlyings.  
- **Olympus / OHM language** = category + founder provenance; **not** affiliation with OlympusDAO governance or the OHM token.  
- DETF ≠ guaranteed rebase yield; no “(3,3)” performance claims.  
- RICH ≠ “the only OHM”; RICH = capital + fee-make liquidity center; DETF shares = per-reserve monetary units.  
- Fee-make: **donate into RICH liquidity** via **SingleVault DETF (RICH)** — not a cash dividend on free RICH; no APR until live.  
- Floor FDV language only for configured auctions; no raise guarantees.  
- Uniswap-class AMMs remain ecosystem partners; we add Balancer multi-asset reserves for seigniorage.

---

## 9. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| **Regulatory / market-linked asset messaging** | High | Non-ownership + eligibility honesty; legal review before geo-broad ads |
| **Thin leg liquidity** | High | Conservative thresholds; small hero basket; invite arb |
| **Balancer deploy bugs on Orbit L2** | High | Production-first tests; start weighted-only |
| **Attention captured by memecoins** | Medium | Own “launch your own OHM” niche; do not compete as meme |
| **Base CCA vs L2-E attention split** | Medium | Dual-track sequencing: product live *before or during* CCA marketing |
| **RICH address fragmentation** | Medium | One canonical L1; explicit bridge table in docs |
| **No CCA on L2-E** | Medium | Dual-track A; or dedicated L2-E auction workshop |
| **Balancer Labs branding conflict** | Low–Med | “Community / IndexedEx deployment of Balancer V3 contracts” |
| **Accidental brand name leaks in copy** | Medium | Comms rule at top of this file; review all launch posts |
| **Fee-make overclaim** | Medium | Roadmap until donation → RICH liquidity measurable; no cash APR |

---

## 10. Open questions (next discussion)

1. **Capital topology:** lock **A dual-track** vs **B L2-E-first** this week?  
2. **Hero DETF:** which liquid legs and rateAsset (WETH vs USDC)?  
3. **Is CCA deployable on 4663?** If yes, does it change Option B?  
4. **Bridge:** official L2-E bridge vs third-party for RICH and ETH?  
5. **Balancer co-marketing:** silent deploy vs reach out to Balancer?  
6. **RICHAI** on agent launchpads on L2-E in addition to Bankr Base — yes/no?  
7. **Legal:** any underlying asset ToS that forbids wrapping into vaults/DETFs?  
8. **Timeline:** target public R1 date relative to Base CCA open?  
9. **Comms:** any later exception for venue co-marketing, or keep brand-silent permanently?

---

## 11. Relationship to existing docs

| Doc | Relationship |
|-----|----------------|
| [`LAUNCH_PLAN.md`](./LAUNCH_PLAN.md) | Normative for **Base CCA + RICHAI + BattleChain + fee → SingleVault DETF (RICH)** |
| [`CCA_FDV_WORKSHOP.md`](./CCA_FDV_WORKSHOP.md) | Floor/FDV for **Base CCA** remain locked under dual-track A |
| This file | Normative for **L2-E product + Balancer DEX + multi-asset DETF** track; **public narrative = Olympus/OHM** |
| DETF AGENTS.md rules | Apply unchanged (role names, inert→live, production-first tests) |

---

## 12. How to use this file

1. Lock §6 decisions in a short working session (including **comms rule**).  
2. Open eng tickets from §7 (R0→R1 first).  
3. Update [`LAUNCH_PLAN.md`](./LAUNCH_PLAN.md) work track when L2-E is accepted as parallel or primary product home.  
4. After first deploys, add an address book (path optional) and link from §3.  
5. Before any public post: check against **comms rule** — Olympus/DETF/RICH/Balancer only unless an exception is logged.

---

*Draft created 2026-07-26. Revised same day: public copy de-brands venue/assets; narrative lead remains Olympus → launch your own OHM.*
