# IndexedEx Launch Plan — RICH CCA + SingleVault DETF (fee sink)

**Status:** Living document — research + decisions as of 2026-07-22  
**Owner discussion:** In progress (not frozen)  
**Primary product surface:** strategy vaults + DETFs; **launch fee-sink** = **SingleVault DETF for RICH** (not DualLiquidity (removed) day-1)

### Current work track (2026-07-22; RH addendum 2026-07-26)

1. **[x] CCA FDV workshop** — floor / FDV / ops split locked; record: [`docs/CCA_FDV_WORKSHOP.md`](./CCA_FDV_WORKSHOP.md).  
2. **[x] CCA parameter sheet** — [`docs/CCA_PARAMETER_SHEET.md`](./CCA_PARAMETER_SHEET.md) + [`docs/cca/base-rich-cca-config.json`](./cca/base-rich-cca-config.json) (token + absolute blocks still pending).  
3. **RICH deploy (ETH) → Superchain bridge 100M → Base CCA open** (public capital raise).  
4. **Announcement + bidder checklist** (RICH capital + **fee-make into RICH liquidity** via **SingleVault DETF (RICH)**; no cash-APR claims).  
5. **BattleChain greenfield + community promo** — Crane multi-protocol deploy on BC testnet (public: open toolkit for builders/whitehats; ops: greenfield master plan). Normative checklist: Crane [`BC_GREENFIELD_MASTER_PLAN.md`](../lib/crane/docs/deployment/BC_GREENFIELD_MASTER_PLAN.md); promo copy [`BATTLECHAIN_LAUNCH_PROMO.md`](./BATTLECHAIN_LAUNCH_PROMO.md).
6. **Implement fee → donation into RICH liquidity** (fee-sink = **SingleVault DETF for RICH** / `SingleVaultDetf`; parallel eng; does not block CCA open). Kill-switch vault/package: done; emergency withdraw deferred.  
7. **After CCA clears:** seed liquidity at runtime size; **RICHAI on Bankr**.  
8. **CCA Rehearsal research (optional confidence):** [`research/scenarios/cca/CCA_Rehearsal_PRD.md`](../research/scenarios/cca/CCA_Rehearsal_PRD.md).  
9. **Product expansion track / L2-E (draft):** multi-asset DETFs + **Balancer V3 as DEX claim** + RICH seed — normative product draft [`docs/ROBINHOOD_LAUNCH_PLAN.md`](./ROBINHOOD_LAUNCH_PLAN.md). **Eng deploy BOM (what we must ship on chain 4663 / testnet 46630):** §2.9 below. Constants: Crane `ROBINHOOD_MAIN.sol` / `ROBINHOOD_TESTNET.sol`; Foundry aliases `robinhood_mainnet` / `robinhood_testnet`. **Public copy:** Olympus / “launch your own OHM” (no venue-chain or issuer stock-token branding). Capital topology under discussion: **Base CCA raise + L2-E product/infra** (dual-track).

**Out of scope for now:** DAOSYS / Crane bounty-token launch (`daosys/BANKR_LAUNCH.md`). Revisit only **after** CCA + Bankr launches.

---

## 1. Intent (working thesis)

### 1.1 Dual-token launch (updated)

| Token | Origin / venue | Stated purpose |
|-------|----------------|----------------|
| **RICH** | **Deploy on Ethereum** (Crane **ERC20 Permit DFPkg**) → **canonical Superchain bridge to Base** → sell via **Uniswap CCA on Base** | Capital raise + price discovery + seed; long-term: protocol fees **donate into RICH liquidity** via **SingleVault DETF (RICH)** |
| **RICHAI** | **Bankr** on Base (agent launchpad) | Agent/social traction; may share DualLiquidity / reserve story with RICH when product wires both legs |
| **Optional later** | Second **RICH CCA on Ethereum** | Additional capital only if needed — **not** day-1 |

Canonical economic home of the token contract is **Ethereum**. Day-1 sale liquidity and agent markets concentrate on **Base**. **Launch order:** Base **CCA for RICH first and fully clear**, then **RICHAI on Bankr after CCA ends** (see §1.3c).

### 1.2 Fee architecture (clarified 2026-07-26)

**Normative model:**

1. **Fees from other vaults and DETFs** are routed (via **Vault Fee Collector**) to **`donation`** that **makes / deepens RICH liquidity**.  
2. **Launch fee-sink (decided 2026-07-26):** **SingleVault DETF for RICH** (`SingleVaultDetf` under `contracts/vaults/detf/composed/single/`) — **that DETF accrues** donated value (reserve quality / share NAV as designed).  
3. **Not** DualLiquidity (removed) as day-1 fee sink (DualLiquidity remains optional later product; do not block launch on it).  
4. **Not** a classic cash dividend paid to free-floating RICH balances. Value path = **buyback-and-make into RICH-linked liquidity** via the SingleVault DETF’s underlying SE vault / pool.  
5. **`donation` is permissionless** (process inventory into the SingleVault DETF / underlying → pools).  
6. If fee inventory is not already an accepted sink asset, **sell into WETH and/or RICH** (and RICHAI only if that instance is later wired), then donate.  
7. Per-DETF **usage / seigniorage** fees on non-sink instances still follow family PRDs; the **protocol routing target** for *other* vault/DETF fee inventory is the **RICH SingleVault DETF / RICH liquidity**.

```text
Other vaults / DETFs
        │  fees (any assets)
        ▼
 Vault Fee Collector  (exists; other vaults call it)
        │
        ▼
  [sell → WETH / RICH if needed]
        │
        ▼
 SingleVault DETF (RICH)   ← launch fee-accrual DETF
        │  donation()  → make RICH-linked liquidity
        ▼
 Underlying SE vault → underlying pool (RICH leg)
        └── deeper RICH liquidity + consistent DETF reserve state
```

**Copy split (do not collapse):**

| Say | Do not say |
|-----|------------|
| Protocol fees **donate into RICH liquidity** via **SingleVault DETF** | “RICH pays you a dividend from DETF fees” |
| The **RICH SingleVault DETF accrues** those donations | “Every DETF’s fees are a claim right on free RICH” |
| Fee-make deepens reserve / POL around RICH | Guaranteed APR or fixed cash yield |

### 1.3 Token supply (RICH)

| Token | Supply | Notes |
|-------|--------|--------|
| **RICH** | **1,000,000,000** (1 billion) | Fixed. **Base CCA sells 10% (100M)**. Remainder: liquidity, team vest, treasury, optional later ETH CCA. |
| **RICHAI** | Bankr default **100B** | 85% to LP (tradeable); **15% creator vest** (2y / 30d cliff) — **vested RICHAI is not available until unlock**. Day-1 protocol RICHAI inventory is **optional and minimal** (~$100 ETH buy) for demo/ops, **not** LP seed depth. |

### 1.3a Remaining supply of RICH (working allocation)

| Bucket | % of 1B | Tokens | Status |
|--------|---------|--------|--------|
| **Base CCA sale** | **10%** | 100M | Decided |
| **Immediate liquidity reserve** | **30%** | 300M | Hold for post-CCA Uni v4 / DETF legs / later dual-token pools (not day-1 RICH/RICHAI seed). |
| **Team** | **2%** | **20M** | Vest = Bankr schedule (2y / 30d cliff) |
| **Other / unallocated** | **58%** | 580M | Hold; use TBD |

### 1.3b Base CCA parameters (decided direction)

| Param | Decision |
|-------|----------|
| Supply sold | **10%** = **100M RICH** |
| Quote asset | **ETH** |
| Floor / FDV | **Locked 2026-07-22** — see [`CCA_FDV_WORKSHOP.md`](./CCA_FDV_WORKSHOP.md): floor **\(5\times10^{-7}\) ETH/RICH**; FDV at floor **~500 ETH / ~$950k** (workshop ETH **$1,900**); public language “~$1M at floor”; ceiling comfort **&lt;$5M** |
| Prior ideas (superseded) | ~~Floor = 0.5 × Bankr listing~~; ~~floor from RICHAI/WETH before CCA~~; ~~mid-CCA RICHAI stagger~~; ~~FDV workshop open~~ |
| Duration | **~5 days** public clearing |
| Supply curve | **Back-loaded** over the window (more supply later in clearing) |
| Tick spacing | **1% of floor** (round floor to multiple of tick spacing at config time) |
| Min raise (`requiredCurrencyRaised`) | **0** (always settle) |
| Planning bands | Success raise **50 ETH** (full-sell-at-floor identity); stretch **100 ETH** — **not public promises** |
| Participation | **Open** — anyone + agents; market CCA during auction; RICHAI **after** CCA ends |
| Proceeds recipient | **`0xeD1FA21329fc45860cAB5D5E26a5fafcCDAcd6D5`** |
| Proceeds split | From that wallet: **~6.5 ETH (~$12k @ $1,900)** founder ops; **remainder → liquidity** (supersedes ~15 ETH ops) |
| Bridge | **Canonical Superchain (OP Stack) ETH→Base** for CCA tranche |

### 1.3c Launch market structure (CCA first → RICHAI after CCA ends)

**Sequence decision (2026-07-14):** **RICH Base CCA first and fully clear**, then launch **RICHAI on Bankr after the CCA ends**. Mid-CCA and same-T0 dual launch are **not** preferred — capital raise gets undivided attention.

**Why CCA first / RICHAI after:**

| Rationale | Notes |
|-----------|--------|
| **Capital raise stands alone** | CCA does transparent price discovery; does not need a Bankr book to set floor. |
| **No auction attention split** | Bankr/meme flow does not compete with CCA bidding during the ~5 days. |
| **~$100 RICHAI buy is symbolic** | Cannot seed a serious RICH/RICHAI pool or produce a reliable reference spot. |
| **Agent discovery still works** | Post-CCA RICHAI announcement teaches agents that **RICH exists**, where to buy it (post-CCA Uni / secondary), and that **agents can buy both**. |
| **Avoids pricing theater** | Day-1 dual seed at “aligned spot” with dust RICHAI would invent a premium/depth that arb would erase. |

**RICHAI buy budget (decided):** **~$100 worth of ETH** — protocol ops/demo inventory only. **Not** LP seed depth. Optional after Bankr LP exists; skip if not needed for demo.

**30% RICH liquidity reserve:** **Size seed at post-CCA runtime only** from actual raise + market conditions — no preset % of the 300M committed in advance.

**RICH/RICHAI pool seed:** **Deferred** until both markets exist and inventory is intentional (CCA proceeds / runtime-sized slice of 30% / later). **Not** a pre-CCA step.

**CCA floor / initial price (locked 2026-07-22):** Independent of RICHAI. Floor **\(5\times10^{-7}\) ETH per RICH**; implied FDV at floor **~500 ETH (~$950k @ workshop ETH $1,900)**. Full detail: [`CCA_FDV_WORKSHOP.md`](./CCA_FDV_WORKSHOP.md).

**Messaging (RICHAI launch — post-CCA):**

1. Lead with **IndexedEx** + **RICH** (capital + fee-make into RICH liquidity; post-CCA market / Uni v4).  
2. State **RICH** role: L1-canonical capital + completed Base CCA + **fees from the stack donate into RICH liquidity** via **SingleVault DETF (RICH)**.  
3. State **RICHAI** role: agent-native companion on Bankr; dual-token markets when wired.  
4. Emphasize **agents can buy both** (RICH secondary/Uni; RICHAI Bankr/Uni).  
5. Cross-link Gitlawb Ads + product docs; do **not** frame RICHAI as the capital raise.

**Operational sequence (decided):**

1. Deploy RICH on ETH (1B) via Crane ERC20 Permit DFPkg; allocate CCA / team / liquidity buckets.  
2. Bridge CCA tranche to Base via canonical Superchain (OP Stack) bridge.  
3. Configure CCA with locked floor **\(5\times10^{-7}\) ETH/RICH** ([`CCA_FDV_WORKSHOP.md`](./CCA_FDV_WORKSHOP.md)); **back-loaded** supply over ~5 days; open Base CCA (ETH quote).  
4. Market CCA hard (docs, agents, Gitlawb small test): capital raise + DETF product thesis (launch your own OHM) + **fee-make into RICH liquidity** (**roadmap** until donation live) + agent participation.  
5. CCA clears → proceeds → **`0xeD1FA21329fc45860cAB5D5E26a5fafcCDAcd6D5`** (~6.5 ETH ops, rest liquidity).  
6. Post-auction: seed Uni v4 / **SingleVault DETF (RICH)** underlying / vault graph — **size from runtime** (proceeds + chosen slice of 30%).  
7. **After CCA ends:** launch **RICHAI** on Bankr; fee recipient = **same proceeds wallet**; metadata **leads with RICH + IndexedEx**; agents can buy both.  
8. Optional: **~$100 ETH** buy of RICHAI for protocol wallet (demo only).

### 1.4 Agent value proposition

Immediate benefits to agents (and agent operators):

1. **Outsource portfolio management** — Deploy strategy vaults and DETFs instead of continuously rebalancing positions themselves. Deposit assets into a chosen management strategy and walk away.
2. **Monitor for arbitrage** — Agents watch vaults, DETFs, and pools containing those tokens; close arb when mispricings appear.
3. **Volume → fees as protocol design** — Vaults present arb deliberately as a way to induce volume (fee generation) and as **market-driven automation** (arb bots keep links / reserves honest).
4. **Hold RICH** as capital + structural support from **protocol fees donated into RICH liquidity** (via **SingleVault DETF for RICH**) — not a cash dividend.

### 1.4b BattleChain greenfield (community gift + launch parallel — refined 2026-07-26)

**Channel / venue:** [BattleChain](https://docs.battlechain.com/) (Cyfrin) — **testnet only** today (chain id **627**, RPC `https://testnet.battlechain.com`). **Not** a capital raise; **not** a substitute for Base CCA / RICH sale.

#### Public story (what we say)

Frame BattleChain work as **community infrastructure**, not self-promo:

| Message | Tone |
|---------|------|
| **“We’re putting Crane + a full DeFi toolkit on BattleChain for the community.”** | Gift to builders, agents, and whitehats |
| **Open composable stack** | Factories, Balancer V3, Aave-class, Uni-class, lending binds — usable by **anyone** on the adversarial testnet |
| **Safe Harbor + attack mode** | Ethical hackers welcome; addresses on docs, not hex spam in tweets |
| **Come build or break it** | Security theater that is *also* real shared infra |
| **RICH CCA stays on Base** | BattleChain is **not** where you buy RICH |

**Do not lead with:** “we need this for our own deploy path / IndexedEx product matrix.” That is internal (below).

#### Internal story (do not look behind the curtain)

| Reality | Why we still ship greenfield |
|---------|------------------------------|
| **Promotion requires surface area** | Credible BC promo needs more than a sample ERC20 — multi-protocol greenfield is the stage set |
| **Our stack must run somewhere adversarial** | Crane CREATE3, Balancer V3, SE/DETF paths get fork + live testnet proof without mainnet capital at risk |
| **No external audit budget** | BattleChain Safe Harbor is the public substitute narrative; greenfield is the substrate we attack/compose on |
| **IndexedEx / SingleVault DETF later waves** | Product packages sit *on top* of greenfield phases; do not announce product as the *reason* for Balancer/Aave/etc. |

Public copy = **community DeFi lab**. Ops truth = **we need this deployed for launch promo + our own validation**.

#### Normative deploy authority (Crane greenfield)

| Doc | Role |
|-----|------|
| **Master checklist** | Crane [`lib/crane/docs/deployment/BC_GREENFIELD_MASTER_PLAN.md`](../lib/crane/docs/deployment/BC_GREENFIELD_MASTER_PLAN.md) |
| **PRD (what to deploy)** | Crane `docs/deployment/BC_GREENFIELD_DEPLOYMENT_PRD.md` |
| **Gap report** | Crane `docs/deployment/BC_GREENFIELD_GAP_REPORT.md` |
| **Commands** | Crane `docs/deployment/BC_GREENFIELD_COMMANDS.md` |
| **Script guide** | Crane `docs/deployment/BC_GREENFIELD_SCRIPT_GUIDE.md` |
| **X drafts (community voice)** | Crane `docs/deployment/BC_GREENFIELD_X_POSTS.md` |
| **IndexedEx promo wrapper** | [`BATTLECHAIN_LAUNCH_PROMO.md`](./BATTLECHAIN_LAUNCH_PROMO.md) |

**Live-broadcast policy (locked in master plan):** **no** live BC greenfield broadcast until **all** phase scripts are written **and** locally tested — not phase-by-phase live. Then: one phase live → update docs/addresses → post matching X draft.

#### Phase map (public gift framing → eng phases)

| Public beat | Greenfield phase (ops) | Status cue (see master plan) |
|-------------|------------------------|------------------------------|
| Crane factories + core stubs live; Safe Harbor lineage | **Phase 1** | Local verify done; live after §0 gate |
| **Balancer V3** ready to use on BC (community DEX surface) | **Phase 2** | Local verify done; live after §0 |
| **Aave** supply/borrow surface for agents/whitehats | **Phase 3** | Local verify done; live after §0 |
| Lending binds (Euler / Venus) | **Phases 4–5** | Local smoke; live after §0 |
| Aerodrome, Uni extras, Camelot, Liquity, Sky, Reliquary, Pendle, Frax, … | **Phases 6–13** | Partial / GAP — expand after core gift ships |
| IndexedEx product (e.g. SingleVault DETF) on BC | **After greenfield base** | Optional Wave B product; not the public *reason* for greenfield |

#### Why it sits in the RICH launch calendar

| Fit | Notes |
|-----|--------|
| **Parallel attention** | Security + builder graph during CCA window; does not compete for auction bids if framed as community infra |
| **Crane brand** | “We ship open DeFi tooling” before/with “we sell RICH” |
| **Olympus / DETF launch** | Quiet proof that the same org builds serious modular infra |
| **Does not block CCA** | If greenfield live gate slips, still open Base CCA; promote what is already verified locally |

#### Anti-patterns

- Framing BattleChain as the **token sale** or as **mainnet audit complete**.  
- Parking RICH CCA proceeds or treasury keys on BattleChain.  
- **Public posts that say** “we deployed this so IndexedEx can launch” or “required for our promo deploy.”  
- Hex addresses in X posts (docs links only — see greenfield X drafts).  
- Live BC broadcast before master-plan §0 (all phases written + local tested).  
- Blocking Base CCA open on full multi-protocol matrix (ship gated core; expand).

#### Execution pack

| Artifact | Path |
|----------|------|
| **Greenfield master checklist** | Crane `docs/deployment/BC_GREENFIELD_MASTER_PLAN.md` |
| **X community drafts** | Crane `docs/deployment/BC_GREENFIELD_X_POSTS.md` |
| IndexedEx promo + dual narrative | [`docs/BATTLECHAIN_LAUNCH_PROMO.md`](./BATTLECHAIN_LAUNCH_PROMO.md) |
| Address book (fill post-deploy) | [`docs/battlechain/promo_addresses.md`](./battlechain/promo_addresses.md) |
| Operator CWD | **Crane** (`lib/crane`) for all BC forge commands |
| Sepolia→BC ETH bridge | Crane `scripts/foundry/Script_Bridge_SepoliaToBattleChain.s.sol` |
| Legacy Wave A (minimal) | Crane `scripts/foundry/Script_Promo_BC_Launch.s.sol` — **prefer greenfield phase scripts** once §0 opens |
| RPC alias | `battlechain-sepolia` → `https://testnet.battlechain.com` |
| Skills | `battlechain-dev-workflow`, `battlechain-safe-harbor` |

### 1.4a Distribution / ads — Gitlawb Ads (decided direction)

**Channel:** [Gitlawb Ads](https://ads.gitlawb.com/) — USDC-funded **sponsored tips** in the gitlawb agent stack (OpenClaude / Playground / OpenGateway surfaces). Viewers opt in and earn inference credits; sponsors fund campaigns permissionlessly.

**Why it fits RICH / RICHAI launch:**

| Fit | Notes |
|-----|--------|
| **Audience** | Agent economy + coding agents + Base-native builders — same ICP as Bankr agents and IndexedEx vault/DETF operators |
| **Peer presence** | **Bankr already campaigns** on Gitlawb Ads (live board as of 2026-07) — shared distribution graph, not a cold channel |
| **Narrative** | “Agents manage capital / arb vaults / hold fee tokens” lands next to agent wallets, skills, and token launches |
| **Campaign style** | Short sponsored tips (not long-form ads); good for CCA dates, Bankr ticker, fee-make one-liners, demo vault links |

**How we use it (working plan):**

1. **Primary (Phase 2):** RICH / IndexedEx sponsored tips **during CCA** — bid path, DETF/OHM product, fee-make → RICH liquidity (roadmap).  
2. **Secondary (Phase 3, post-CCA):** RICHAI tips; always **point to RICH market + product**, not Bankr-as-raise.  
3. **Cross-promote on Bankr:** Bankr launch metadata, X/agent prompts **lead with RICH + IndexedEx**, then RICHAI; **reference Gitlawb Ads** (and vice versa).  
4. **Budget (decided):** **Small test first** (low hundreds USDC); scale only if agents respond. Fund from protocol-controlled address (not Bankr agent wallets).  
5. **Creative (decided):** Draft tip copy **later**; landings = **docs + CCA URL (Phase 2) + Bankr when live (Phase 3)**. Themes: vault/DETF outsourcing · launch your own OHM · invited arb · fee-make **donates to RICH liquidity** · **RICH CCA** · RICHAI · **agents can buy both**.

**Anti-pattern:** Treating Gitlawb Ads as the capital raise. It is **attention + agent discovery** only; capital raise remains Base CCA for RICH.

### 1.5 Product framing (one sentence)

> IndexedEx turns agent capital into **managed vault / DETF positions** (“launch your own OHM”), raises **RICH** (1B, ETH→Base CCA) for capital and markets, and routes **fees from other vaults/DETFs into donation that makes RICH liquidity** through a **SingleVault DETF for RICH**—with **RICHAI** (Bankr) as an agent-native companion and markets kept honest by invited arbitrage.

### 1.5a Olympus / “launch your own OHM” (launch narrative — 2026-07-26)

**Founder provenance (public):** IndexedEx is led by the **original developer of Olympus**.  

**Category claim:** A **DETF** is the productized form of an **OHM-class system** — reserve-backed seigniorage currency, bonding into protocol-owned depth, mint/burn policy — so builders and agents can **launch their own OHM** over chosen multi-asset reserves.  

**Token split (do not collapse):**

| Token | Role in this story |
|-------|--------------------|
| **DETF share** | The “OHM” of *that* reserve instance |
| **RICH** | Capital token + economic center of **fee-make into RICH liquidity** — **not** “OHM rebranded” |
| **RICHAI** | Agent-native companion (post-CCA) |
| **SingleVault DETF (RICH)** | **Launch fee sink** — accrues donations from other vaults/DETFs into RICH liquidity |

**Public comms:** lead with Olympus / DETF / Balancer / RICH. Avoid venue-chain brand names and issuer “stock token” product framing in launch posts (internal L2-E ops only).  

**Normative long-form:** [`ROBINHOOD_LAUNCH_PLAN.md`](./ROBINHOOD_LAUNCH_PLAN.md) §0.1 + top-of-file comms rule.  

**Anti-claims:** not OlympusDAO official; no guaranteed rebase / “(3,3)” yield; onchain reserve assets ≠ legal ownership of offchain underlyings.

---

## 2. Research notes (external viability)

### 2.1 Uniswap CCA for $RICH

**What CCA is (as of mid-2026):**

- Permissionless **Continuous Clearing Auction** for bootstrapping liquidity and finding a market price for new / low-liquidity tokens.  
- Supply sold over time in blocks; each block clears at a single market-clearing price; reduces sniping vs pure LBP/sniper launches.  
- At auction end: tokens distributed + **Uniswap v4 pool seeded** at discovered price.  
- Live on **Ethereum, Unichain, Arbitrum, Base**. Self-serve auction creation available in Uniswap Web App (announced 2026).  
- Reference outcome: Aztec CCA sale (Nov 2025) ~$59–60M, 17k+ bidders; post-analysis claimed limited sniping / automated manipulation.  
- Resources: [cca.uniswap.org](https://cca.uniswap.org/), [blog post](https://blog.uniswap.org/continuous-clearing-auctions), [docs / liquidity launchpad](http://docs.uniswap.org/contracts/liquidity-launchpad/Overview), [whitepaper PDF](https://docs.uniswap.org/whitepaper_cca.pdf).

**Viability for RICH (capital raise):** **High**, if goals are:

- Credible, transparent price discovery  
- Day-1 Uniswap v4 liquidity  
- Narrative alignment with “serious DeFi” rather than pure meme deploy  

**Caveats / risks:**

| Risk | Notes |
|------|--------|
| **Expectations vs Aztec** | Aztec was a large, known L2 with brand; most CCA sales will raise far less. Do not plan runway on Aztec-scale numbers. |
| **ETH deploy → Base CCA** | **Chosen path:** mint/deploy RICH on Ethereum, bridge supply to Base, run **CCA on Base**. Uniswap UI supports CCA with **existing tokens** and Base is a first-class CCA chain. |
| **Bridge risk** | Canonical RICH lives on L1; Base is a representation (native mint + lock/burn bridge, Superchain, or third-party). Wrong bridge choice creates permanent fragmentation. Prefer **official OP Stack / Superchain-standard path** if Base is the L2 home. |
| **Token already exists?** | Local/test deployments already use symbol `RICH`. Mainnet launch needs a **clean Ethereum address**, fixed supply/mint policy, and clear distinction from CHIR / RICHIR protocol assets. |
| **CCA supply %** | Only a **portion** of supply goes to Base CCA; rest stays on ETH (treasury, later optional ETH CCA, ecosystem). Must be designed before auction params. |
| **Proceeds currency** | Base CCA bids typically in ETH/WETH on Base. Plan: runway % vs seed **SingleVault DETF (RICH)** / vault graph on Base. |
| **Optional ETH CCA later** | **Decided:** reserve option for additional capital; **not** day-1. Keeps L1 powder dry. |
| **Regulatory / communications** | CCA is transparent but still a token sale. Legal review required. |
| **Post-auction liquidity shape** | Base CCA seeds **Uni v4 on Base**. **SingleVault DETF (RICH)** still needs SE vault + Balancer reserve wiring on the **product chain(s)** — not automatic from CCA alone. |

### 2.2 Bankr for $RICHAI

**What Bankr is (as of mid-2026):**

- AI agent / social trading stack: natural-language trade, wallets, **token launch** for agents.  
- Default launch chain: **Base**; also Solana/Raydium path, Robinhood Chain option, multi-chain agent wallets.  
- Launch mechanics (Doppler path, current docs):  
  - Fixed **100B** supply (not mintable after deploy)  
  - **85%** to Uni v4 liquidity pool immediately  
  - **15%** creator vesting over **2 years**, **30-day cliff** (unless partner-key full-pool mode)  
  - **0.7%** swap fee → **95% creator / 5% protocol (Doppler)**  
  - Fees claimable to fund agent compute  
- Deploy via chat, `@bankrbot` on X, CLI (`@bankr/cli`), API.  
- Social virality is the product: mention → deploy → tradeable in seconds.  
- Docs: [docs.bankr.bot/token-launching](https://docs.bankr.bot/token-launching/overview/), site: [bankr.bot](https://bankr.bot/).

**Viability for RICHAI (agent traction):** **Medium–High for attention**, **low–medium for serious capital**.

| Strength | Concern |
|----------|---------|
| Native agent / X distribution | Token parameters are **largely fixed** by Bankr (100B, 85/15, 0.7% fee) — limited custom tokenomics |
| Instant tradeable pool | **Not** a CCA-style capital raise; liquidity is thin and meme-market structured |
| Creator fee stream for agents / ops | **Security history**: social/prompt-injection incidents around agent wallets (community reports of agent-to-agent exploits) — do not park large treasury behind Bankr-managed agent wallets |
| Fits “AI agents trade our stack” narrative | Ticker **RICHAI** can be read as meme/agent-coin; must be carefully linked to IndexedEx utility or it dilutes RICH |
| Doppler Uni v4 on Base | **Aligned** with Base CCA for RICH — both fee tokens and primary sale market on Base |

### 2.3 Dual-token + fee-sink architecture — research judgment

| Approach | Assessment |
|----------|------------|
| **ETH canonical RICH + Base CCA** | **Viable and common** — Uniswap CCA supports existing tokens; Base is live for CCA. Engineering focus: bridge + which address CCA commits. |
| **Fees → RICH liquidity** | **Decided** — other vaults/DETFs route fees to **donate into RICH liquidity**; the fee-sink DETF **accrues** those donations. |
| **Launch fee sink** | **SingleVault DETF for RICH** (`SingleVaultDetf`) + `donation` buyback-and-make. Not a cash dividend on free RICH. |
| DualLiquidity (removed) as fee sink | **Deferred** — not day-1 launch fee accrual vehicle. |
| Optional second CCA on Ethereum later | **Sensible** — don’t compete two CCAs on day 1; use L1 CCA only if Base raise underdelivers or expansion needs L1 depth. |
| Simultaneous / mid-CCA RICHAI | High messaging load; competes with auction. **Decided (2026-07-14):** CCA **fully ends**, then RICHAI — agents still learn RICH exists and can buy both. |

### 2.4 Agent thesis — research judgment

| Claim | Viability | Notes |
|-------|-----------|--------|
| Agents deploy vaults/DETFs as portfolio management | **Strong product fit** for IndexedEx | Needs: agent-readable docs, factory APIs, deterministic deploy, fee/oracle transparency, monitoring endpoints |
| Agents arb vaults/DETFs/pools | **Strong** if mispricings are real and liquid enough | Needs: public quote surfaces, route docs, known pool graph, possibly small bounties / first-mover fees |
| Arb induces volume → fees as automation | **Core protocol design** | Already aligned with SE vault + nested pool architecture; must be explicit in launch messaging so arb is **invited**, not framed as “exploit” |
| Agents prefer Bankr-only tokens | **Incomplete** | Serious AUM agents need deeper liquidity (RICH CCA + protocol pools), not only Bankr meme books |

---

## 3. Fit with launch fee-sink DETF (internal)

### 3.0 Launch fee-accrual DETF (decided 2026-07-26)

| Item | Decision |
|------|----------|
| **Family** | **SingleVault DETF** (`SingleVaultDetf`, `contracts/vaults/detf/composed/single/`) |
| **Role** | **Fee-accrual DETF for RICH** — protocol fees from other vaults/DETFs **donate into RICH liquidity** through this instance |
| **Shape** | Single underlying SE vault + Balancer weighted reserve (self-leg + external leg(s) per package); diamond = DETF share ERC-20 |
| **Not day-1 fee sink** | DualLiquidity (removed) (three-leg) — remains optional later product surface |

**Eng path:** facets / DFPkg via Crane CREATE3 + manager vault registry; implement / wire **`donation`** on SingleVault DETF; Fee Collector → this package instance; first bond bootstrap before live mint/burn.

**Naming:** product/marketing may say “SingleVault DETF (RICH)” or “RICH fee-accrual DETF.” Role names in code stay `rateAsset` / `vaultShare` / `underlyingVault` / etc. (no brand leakage into generic interfaces).

### 3.1 DualLiquidity (removed) (deferred relative to fee sink)

From internal plans (`docs/superpowers/plans/2026-07-05-dual-liquidity-linked-detf.md` and related): DualLiquidity (removed) is a multi-leg DETF (two V4 SE vaults + one V2 pair SE). **Prior “day-1 fee sink = DualLiquidity (removed)” is superseded** for launch — DualLiquidity may still ship later as a product, not as the RICH fee-accrual vehicle at launch.

**Launch implications (updated):**

| Decision | Implication for engineering |
|----------|----------------------------|
| DETF fee sink | **SingleVault DETF for RICH**. Other vaults/DETFs → collector → **donation into RICH liquidity**. That DETF **accrues** the make. |
| **`donation`** | Permissionless path: fee inventory → SingleVault DETF / underlying SE → **RICH-linked pools**. Primary long-term RICH structural VP (roadmap until live). |
| RICH / RICHAI | RICH = capital + beneficiary of **liquidity make** via SingleVault DETF; RICHAI = companion. Not cash dividends. |
| RICH **1B** fixed supply | Deploy via Crane **ERC20 Permit DFPkg** (mint-once / fixed supply); CCA + L1 allocations as % of 1B. |
| RICH L1 canonical, Base CCA | Deploy on **Ethereum**; bridge CCA tranche to Base via **canonical Superchain (OP Stack) bridge**; CCA uses Base address. |
| RICHAI Bankr Base | Fee recipient → protocol-controlled path. |
| Optional ETH CCA later | L1 holdback of 1B supply. |
| **Kill-switch** | Owner-controlled disable via **Vault Registry**; vaults/DETFs query registry. |

**Bootstrap:** DETF deploy is **inert by design** until **first bond / bootstrap** makes the reserve live. Demo checklist: **deploy SingleVault DETF (RICH) → bootstrap/first bond → fee collector → donation → RICH liquidity up**.

---

## 4. Suggested changes to the draft plan

### 4.1 Strong recommendations (aligned with latest decisions)

1. **Chain topology (decided shape)**  

   ```text
   Ethereum:  deploy RICH via Crane ERC20 Permit DFPkg (canonical supply, treasury, optional later CCA)
        │ canonical Superchain (OP Stack) bridge ETH → Base
        ▼
   Base:      RICH (bridged) ──► CCA sale (FIRST, ~5d back-loaded) ──► Uni v4 seed
                         │
                         └── after CCA ends ──► RICHAI (Bankr) agent market
              SingleVault DETF (RICH)  ← launch fee-accrual / donation sink
              + strategy vaults / other DETFs
   ```

2. **Token roles (public one-pager)**  

   | Token / product | Role | Not |
   |-----------------|------|-----|
   | RICH | L1-canonical capital + Base CCA + **center of fee-make liquidity** | Not “only a meme”; not a cash dividend |
   | RICHAI | Agent-native social/Bankr companion | Not the L1 capital raise alone |
   | **SingleVault DETF (RICH)** | **Launch fee sink** — accrues donations; **`donation` buyback-and-make** into RICH-linked vault/pool | Not DualLiquidity (removed) day-1; not a cash claim vault |

3. **Fee path = donate to RICH liquidity via SingleVault DETF (decided 2026-07-26)**  
   - Fees from **other vaults and DETFs** → Vault Fee Collector → sell if needed → **`donation`** into **SingleVault DETF for RICH**.  
   - That DETF **accrues** the value; effect is **deeper RICH liquidity** (buyback-and-make), not a free-RICH cash claim.  
   Still open for eng: exact accepted assets, underlying SE (e.g. RICH/WETH), share/NAV under donation, reentrancy.

4. **Bridge (decided 2026-07-17)**  
   **Canonical Superchain (OP Stack) ETH→Base bridge** for the RICH CCA tranche. Document **one** Base RICH address as “the” CCA and pool asset. Do not use third-party bridges for the canonical launch narrative.

5. **Do not put protocol treasury, DETF admin, or fee-claim authority in Bankr agent wallets**  
   Multisig / diamond owner on ETH and Base; Bankr creator fee recipient = same controlled address or distribution contract.

6. **Agent product remains the moat**  
   Agent Launch Kit still required before or with CCA (deploy vault/DETF, deposit, monitor arb, claim fee-token story).

7. **RICH CCA params (Base auction)** — supply base **1,000,000,000**:

   | Param | Open | Starter suggestion |
   |-------|------|--------------------|
   | Total supply | **1B** | Decided |
   | % of **total** supply for Base CCA | **10%** | **Decided** → **100,000,000 RICH**; keep L1 reserve for optional ETH CCA |
   | Floor / initial price | **\(5\times10^{-7}\) ETH/RICH** (~$950k FDV at floor) | **Locked** 2026-07-22 — [`CCA_FDV_WORKSHOP.md`](./CCA_FDV_WORKSHOP.md) |
   | Duration | **~5 days** | Peer Aztec ~4–5d; soft-decided |
   | Supply curve | **Back-loaded** | Decided |
   | Quote asset | **ETH** | Confirmed Bankr-aligned |
   | Proceeds split | **~6.5 ETH ops; rest liquidity** | **Locked** 2026-07-22 (was ~15 ETH) |
   | Sequence vs RICHAI | **CCA fully first** | RICHAI **after CCA ends** |
   | L1 treasury / team vest | ☐ | Transparent; no surprise unlocks |
   | Optional ETH CCA | **Later only** | Trigger if capital gap or L1 market demand |

8. **RICHAI Bankr params**

   | Param | Open | Notes |
   |-------|------|-------|
   | Timing | **After CCA ends** | Decided |
   | Fee recipient | **Same as CCA proceeds** `0xeD1…6D5` | Decided; re-route later if needed |
   | Metadata | ☐ | **Lead with RICH + IndexedEx**; dual fee-token; agents can buy both |
   | Protocol RICHAI buy | **~$100 ETH** optional | Demo only; not LP seed |
   | Partner key vs 85/15 | ☐ | Prefer controlled fee routing into same fee system as RICH if possible |
   | Relation to DETF fees | ☐ | Document how Bankr trading fees vs protocol vault fees both support holders |

9. **Legal / disclosure**  
   - Fee tokens ≠ guaranteed yield; DETF accumulation can lose value; arb extracts from LPs.  
   - Cross-chain RICH: disclose Superchain bridge risk.

10. **Security posture (decided 2026-07-17)**  
    - **No external audit budget** for now. Self-audit with multiple models continues.  
    - **BattleChain** (Cyfrin) for safe-harbor / ethical-hacker testing before relying on mainnet capital.  
    - Implement **Vault Registry kill-switch**: owner disables a vault address and/or vault type ID; vaults and DETFs **must query the registry** before sensitive ops; includes a **disabled emergency withdraw** feature. Registry is the source of truth for active vs disabled.

11. **RICH token deploy path (decided 2026-07-17)**  
    Deploy RICH on Ethereum with Crane’s **ERC20 Permit DFPkg**, then bridge to Base for CCA.

### 4.2 Optional / later

- **Bridge RICHAI → utility:** e.g. fee discounts, agent registry stake, or points toward vault strategies — only if it doesn’t pollute DETF accounting.  
- **Second CCA tranche** after product traction.  
- **Incentivized arb season** (small bounty pool) to bootstrap agent monitors.

### 4.3 Anti-patterns to avoid

- Treating Bankr launch as the capital raise (it is not).  
- Pricing CCA floor off a dust RICHAI print / day-1 dual seed theater.  
- Launching RICHAI **during** CCA (attention split) or same-T0 dual launch.  
- Setting CCA floor/FDV with no realistic fully diluted mcap story.  
- Using DualLiquidity (removed) as day-1 fee sink when **SingleVault DETF (RICH)** is the locked launch vehicle.  
- Treating pre-bootstrap `ReservePoolNotInitialized` as a deploy-script bug instead of running first bond/bootstrap.  
- Launching tokens before SingleVault DETF (RICH) is **testnet-demoable** (bootstrap + fee → donation → RICH liquidity).  
- Overclaiming “agents will manage billions” before one public demo vault has real deposits.  
- Parking protocol treasury or kill-switch owner keys in Bankr agent wallets.

---

## 5. Proposed phased launch (discussion draft)

```text
Phase 0 — Foundations (now) — plan review + missing features
  [x] Vault Fee Collector exists (other vaults call it)
  [ ] **SingleVault DETF (RICH)** package deploy path for fee sink
  [ ] Implement **donation** on SingleVault DETF → underlying SE → RICH liquidity (buyback-and-make)
  [ ] Wire Fee Collector inventory → SingleVault DETF (RICH) donation
  [ ] Donation resistance + fee-path integration tests (fees → collector → donation → RICH depth/TVL)
  [x] Vault Registry **kill-switch**: owner disable vault and/or package; vaults/DETFs query registry (type-ID axis dropped)
  [ ] **Disabled emergency withdraw** path gated by registry disable state (deferred until kill-switch proven)
  [ ] BattleChain greenfield §0 gate (all phase scripts local-tested) then phased live + X (community gift narrative)
  [ ] RICH **1B** via Crane ERC20 Permit DFPkg on ETH + Superchain bridge path (scripts)
  [ ] Demo path: deploy → **bootstrap / first bond** (initialize reserve via BPR from underlying vault deposits)
  [ ] Agent docs + CLI/API (include donation / fee-make monitoring)
  [ ] Multisig treasury (ETH + Base) + fee recipients
  [ ] Draft CCA + Bankr announcement text (after demo path works)

Phase 1 — Soft product launch (testnet demo)
  [ ] Public testnet demo: deploy **SingleVault DETF (RICH)**, bootstrap/first bond, deposit, arb surface
  [ ] Show fee flow: vault action → Fee Collector → donation → **RICH liquidity**
  [ ] Exercise kill-switch + emergency withdraw on testnet
  [ ] Agent onboarding guide + Bankr-friendly scripts

Phase 2 — RICH: Ethereum deploy → Superchain bridge → Base CCA (FIRST; fully clear)
  [ ] Deploy RICH on Ethereum (Crane ERC20 Permit DFPkg, canonical)
  [ ] Bridge CCA tranche to Base (canonical Superchain bridge)
  [x] CCA params drafted ([`CCA_PARAMETER_SHEET.md`](./CCA_PARAMETER_SHEET.md)); patch token + blocks at open
  [ ] Configure Base CCA: **back-loaded** supply, ~5d, ETH quote, floor **\(5\times10^{-7}\) ETH/RICH** ([`CCA_FDV_WORKSHOP.md`](./CCA_FDV_WORKSHOP.md))
  [ ] **Open + clear CCA**; market hard: fee-token + DETF utility + agent bid path
  [ ] **Announcement copy** for CCA launch (product + OHM/DETF thesis + fee-make → RICH liquidity + agent bid path)
  [ ] **BattleChain greenfield:** finish open phases per Crane master plan; live only after §0; fill address books; **community X** from `BC_GREENFIELD_X_POSTS.md` during CCA window (§1.4b)
  [ ] **Gitlawb Ads:** small USDC test campaign (CCA window + product links)
  [ ] Post-auction: seed Uni v4 / **SingleVault DETF (RICH)** underlying / vault graph — **size at runtime** from proceeds + 30% slice as needed
  [ ] Hold remaining L1 RICH (incl. most of 30% + **58% dry**) for treasury / later ETH CCA / ecosystem

Phase 3 — RICHAI Bankr (Base) — AFTER CCA ends
  [ ] Deploy RICHAI; fee recipient = **`0xeD1FA21329fc45860cAB5D5E26a5fafcCDAcd6D5`** (same as CCA proceeds)
  [ ] Metadata + launch posts **lead with RICH + IndexedEx**; dual fee-token; agents can buy both
  [ ] **Announcement copy** for Bankr / RICHAI (post-CCA; agents can buy both)
  [ ] Optional: **~$100 ETH** buy of RICHAI for protocol demo wallet (not LP seed)
  [ ] Agent campaigns: vaults, arb, hold fee tokens
  [ ] **Bankr campaign copy references Gitlawb Ads** (and Gitlawb tips point to RICH market + RICHAI)
  [ ] **Gitlawb Ads:** RICHAI / dual fee-token tips (scale only if Phase 2 test worked)

Phase 4 — Flywheel
  [ ] **SingleVault DETF (RICH)** live as fee sink; donation → RICH liquidity measurable
  [ ] Agents deposit; arb volume; fee-make TVL / depth dashboards
  [ ] Optional later: DualLiquidity (removed) as additional product (not required for fee-make launch)
  [ ] Optional Phase 5: Ethereum CCA for additional RICH supply if capital needed
  [ ] Optional later: revisit **DAOSYS** token / bounty launch (explicitly deferred)

Phase L2-E — Expansion L2 (chain 4663) product + Balancer (parallel after / with soft product; see §2.9)
  [x] Chain constants + Foundry RPC aliases (Crane `ROBINHOOD_MAIN` / `ROBINHOOD_TESTNET`)
  [ ] L2-E testnet (46630) fork smoke: WETH, Permit2, Uni V4, faucet stock tokens
  [ ] Deploy Crane CREATE3 + DiamondPackageCallBackFactory on 46630, then 4663
  [ ] Deploy **Balancer V3** B0–B2 (Vault + Weighted factory + routers) — **required** (not on chain today)
  [ ] Deploy IndexedEx manager / FeeCollector / Vault Registry / fee oracle
  [ ] Deploy Uni SE vault DFPkg(s) + at least one live vault on WETH/USDG (or WETH/market leg)
  [ ] Deploy Balancer SE router + SE vault on first Balancer pool
  [ ] Deploy StandardExchangeRateProvider packages for DETF legs
  [ ] Deploy hero DETF (Single SE or Multi-vault weighted) → first bond → live mint/burn
  [ ] (With RICH capital) bridge RICH representation → seed SingleVault DETF (RICH) fee sink on L2-E
  [ ] Frontend tokenlists + wagmi chain 4663/46630 address artifacts
  [ ] Address book + public “Balancer V3 + DETF live” post (no venue-brand requirement)
```

---

## 6. Decision log

| Date | Decision | Status |
|------|----------|--------|
| 2026-07-11 | Dual-token thesis (RICH capital + RICHAI agents) as working plan | Accepted for discussion |
| 2026-07-11 | Research: CCA viable for capital; Bankr for agent attention | Confirmed |
| 2026-07-11 | **RICH: deploy on Ethereum, bring to Base, sell in CCA on Base** | **Decided** |
| 2026-07-11 | **Optional additional RICH CCA on Ethereum later** if more capital needed | **Decided** (deferred) |
| 2026-07-11 | **DualLiquidity (removed) DETF is fee sink** for other strategy vaults and DETFs | **Superseded for launch** 2026-07-26 → **SingleVault DETF (RICH)** |
| 2026-07-11 | **Both RICH and RICHAI are fee-distribution tokens** | **Refined** 2026-07-26 — not cash dividends; **fees donate into RICH liquidity**; sink DETF accrues |
| 2026-07-11 | Prefer RICH as DETF reserve economic leg; RICHAI primarily distribution only | **Superseded** 2026-07-14 (all three in reserve) |
| 2026-07-14 | DualLiquidity (removed) day-1 reserve legs: **WETH + RICH + RICHAI** | **Deferred** as fee-sink shape; DualLiquidity not launch fee accrual vehicle |
| 2026-07-26 | **Launch fee-accrual DETF = SingleVault DETF for RICH** (`SingleVaultDetf`) | **Decided** |
| 2026-07-11 | Product / agent / CCA / Bankr day-1 liquidity home: **Base**; RICH canonical: **Ethereum** | **Decided** |
| 2026-07-11 | **RICH total supply = 1,000,000,000** | **Decided** |
| 2026-07-11 | Fee “distribution” = DETF **`donation`** → underlying vaults → pool liquidity = **buyback-and-make** | **Reaffirmed** — target is **RICH liquidity** via **SingleVault DETF (RICH)** |
| 2026-07-11 | **Base CCA sells 10% of RICH** (100M of 1B); rest held for treasury / ecosystem / optional later ETH CCA | **Decided** |
| 2026-07-12 | Remaining supply: **30% liquidity**, **2% team**, **10% CCA**, **58% unallocated** | **Decided** |
| 2026-07-14 | **58% residual hold dry** (treasury / later ETH CCA / ecosystem) — no public sub-buckets yet | **Decided** |
| 2026-07-12 | **Team = 2%** (20M); vest = Bankr schedule (2y / 30d cliff) | **Decided** |
| 2026-07-11 | CCA **quote asset = ETH** | **Decided** |
| 2026-07-12 | CCA floor offset **definable at deploy-script runtime** (not hard-coded ½ Bankr) | **Decided** |
| 2026-07-13 | CCA floor **independent of RICHAI/WETH** — RICHAI does not set CCA floor | **Decided** |
| 2026-07-14 | CCA floor/initial price → **FDV workshop** (realistic fully diluted mcap); numbers not locked yet | **Superseded** 2026-07-22 |
| 2026-07-11 | **Hold 30% RICH** for potential immediate liquidity with other tokens | **Decided** |
| 2026-07-14 | **30% seed sizing at post-CCA runtime only** (from raise + market conditions) | **Decided** |
| 2026-07-12 | ~~Must buy RICHAI before CCA; seed RICH/RICHAI + CCA aligned to RICHAI/WETH spot~~ | **Superseded** 2026-07-13 |
| 2026-07-13 | ~~RICHAI mid-CCA (~1–3 days into CCA)~~ | **Superseded** 2026-07-14 |
| 2026-07-14 | **Launch order: RICH Base CCA fully clears → then RICHAI Bankr** | **Decided** |
| 2026-07-14 | CCA supply curve **back-loaded** over ~5-day window | **Decided** |
| 2026-07-13 | **RICHAI buy budget ~$100 ETH** — symbolic/demo only; **not** day-1 LP seed | **Decided** |
| 2026-07-13 | **Day-1 RICH/RICHAI pool seed deferred** until real inventory (post-CCA / later) | **Decided** |
| 2026-07-13/14 | RICHAI launch messaging **leads with RICH + IndexedEx**; emphasize agents can buy both | **Decided** |
| 2026-07-14 | Bankr RICHAI fee recipient = **same as CCA proceeds** `0xeD1FA21329fc45860cAB5D5E26a5fafcCDAcd6D5` | **Decided** |
| 2026-07-11 | CCA duration peer **~4–5 days** (Aztec); working pick **5 days** open clearing | **Suggested / soft-decided** |
| 2026-07-11 | Open bidding (humans + agents); market CCA to **Bankr agents** | **Decided** |
| 2026-07-11 | Proceeds: **~15 ETH (~$20k)** founder ops; **rest → liquidity** | **Superseded** 2026-07-22 (~6.5 ETH ops) |
| 2026-07-12 | CCA proceeds recipient: **`0xeD1FA21329fc45860cAB5D5E26a5fafcCDAcd6D5`** | **Decided** |
| 2026-07-11 | **Canonical ETH→Base bridge** for RICH CCA tranche | **Decided** (refined 2026-07-17: Superchain) |
| 2026-07-11 | Cross-pool arb allowed as discovery; **not** designed as forced drain of locked Bankr LP | **Decided** |
| 2026-07-11 | All vault fees → RICH/RICHAI DETF; convert to WETH/RICH/RICHAI then donate; **donation permissionless** | **Refined** 2026-07-26 → **SingleVault DETF (RICH)** / RICH liquidity |
| 2026-07-12 | External third-token pairing deferred; **omit from launch materials** | **Decided** |
| 2026-07-13 | **Gitlawb Ads** as launch distribution; Bankr campaign cross-references Gitlawb | **Decided** (direction) |
| 2026-07-14 | Gitlawb budget: **small test first** (low hundreds USDC); creative draft later; landings = docs + CCA + Bankr when live | **Decided** |
| 2026-07-14 | Tickers locked **RICH** + **RICHAI**; formal **audit + calendar still open** | **Superseded in part** 2026-07-17 (no external audit budget) |
| 2026-07-17 | **Current work track:** review plan → implement gaps (donation, kill-switch) → **testnet protocol demo** → write **CCA + Bankr announcement** copy | **Decided** |
| 2026-07-17 | DualLiquidity (removed) is **ready** for **`donation`** implementation | **Superseded for launch sink** — implement donation on **SingleVault DETF (RICH)** first |
| 2026-07-17 | CCA floor / FDV **not set**; requires dedicated **research** before CCA deploy | **Superseded** 2026-07-22 |
| 2026-07-22 | **FDV workshop locked** — full record [`CCA_FDV_WORKSHOP.md`](./CCA_FDV_WORKSHOP.md) | **Decided** |
| 2026-07-22 | CCA floor = **\(5\times10^{-7}\) ETH per RICH**; FDV at floor **~500 ETH (~$950k @ ETH $1,900)**; public “~$1M at floor”; max comfort **&lt;$5M FDV** | **Decided** |
| 2026-07-22 | Planning: success raise **50 ETH**, stretch **100 ETH** (not public guarantees); `requiredCurrencyRaised` = **0** | **Decided** |
| 2026-07-22 | Proceeds ops = **~6.5 ETH (~$12k @ $1,900)**; remainder liquidity (was ~15 ETH) | **Decided** |
| 2026-07-22 | Tick spacing **1% of floor**; ~5d back-loaded CCA unchanged | **Decided** |
| 2026-07-22 | Fee-make (`donation`) = **primary roadmap VP for RICH**; CCA open not gated on donation live; no APR claims until live | **Reaffirmed** 2026-07-26 with precise wording |
| 2026-07-26 | **Clarified fee model:** fees from other vaults/DETFs **donate into RICH liquidity**; fee-sink DETF **accrues** (not free-RICH cash dividend) | **Decided** |
| 2026-07-26 | Launch fee-sink instance family = **SingleVault DETF for RICH** | **Decided** |
| 2026-07-26 | Brief wrong turn (“RICH does not accrue fees…”) **withdrawn** same day — superseded by clarification above | **Superseded** |
| 2026-07-22 | Launch = **public Base CCA**; RICH via Crane **ERC20PermitDFPkg** on ETH → Superchain bridge CCA tranche to Base | **Decided** (reaffirm) |
| 2026-07-22 | **BattleChain testnet** as **launch promotion**: deploy **Crane** + **multiple DeFi protocol ports**; announce with CCA; not a capital raise; testnet-only (627) | **Decided** |
| 2026-07-22 | BattleChain Wave A pack: `Script_Promo_BC_Launch` + promo docs | **Superseded in part** by full greenfield phase scripts (still useful as minimal fallback) |
| 2026-07-26 | **BC greenfield master plan** is normative deploy checklist (Crane `BC_GREENFIELD_MASTER_PLAN.md`); no live until all phases written+local tested | **Decided** (ops) |
| 2026-07-26 | **Public BC narrative** = community gift (open toolkit + Safe Harbor); **internal** = required stage for promo + our stack validation — do not lead public copy with self-serving deploy need | **Decided** |
| 2026-07-22 | **CCA parameter sheet** drafted — [`CCA_PARAMETER_SHEET.md`](./CCA_PARAMETER_SHEET.md), config [`cca/base-rich-cca-config.json`](./cca/base-rich-cca-config.json); token + absolute blocks pending | **Decided** (draft) |
| 2026-07-17 | Bridge = **canonical Superchain (OP Stack)** ETH→Base for RICH CCA tranche | **Decided** |
| 2026-07-17 | DualLiquidity (removed) **weights** set in DFPkg `PkgArgs` (defaults **20/20/60** for weightA/B/pair over SE vault-share legs) | **Decided** (clarification) |
| 2026-07-17 | Scenario3 / pre-bootstrap uninitialized reserve is **expected**; live via **first bond/bootstrap** (external deposits → BPR leg shares → init weighted reserve), not a deploy-script seed-all-pools blocker | **Decided** (clarification) |
| 2026-07-17 | **No external audit budget**; multi-model self-audit continues; use **BattleChain** safe harbor for ethical hacker testing | **Decided** |
| 2026-07-17 | Implement owner-controlled **Vault Registry kill-switch**: disable by vault and/or vault type ID; vaults/DETFs query registry as source of truth; includes **disabled emergency withdraw** | **Decided** (to implement) |
| 2026-07-17 | Deploy **RICH** on Ethereum via Crane **ERC20 Permit DFPkg**, then Superchain-bridge to Base for CCA | **Decided** |
| 2026-07-17 | **DAOSYS** token / bounty launch **dropped for now**; consider only **after** CCA + Bankr launches | **Decided** (deferred) |
| 2026-07-26 | **L2-E product track** drafted: Balancer V3 + multi-asset DETFs + RICH seed; public narrative = Olympus / launch-your-own-OHM; see [`ROBINHOOD_LAUNCH_PLAN.md`](./ROBINHOOD_LAUNCH_PLAN.md) | **Proposed** (not frozen) |
| 2026-07-26 | L2-E capital default under discussion: **dual-track** (Base CCA remains raise; L2-E is product + post-clear seed) vs pure L2-E-first sale | **Open** |
| 2026-07-26 | **Public launch copy:** avoid venue-chain brand names and issuer stock-token framing | **Proposed** |
| 2026-07-27 | L2-E eng constants landed: Crane `ROBINHOOD_MAIN` (4663) / `ROBINHOOD_TESTNET` (46630); Foundry `robinhood_mainnet` / `robinhood_testnet` (+ Alchemy templates) | **Done** (ops) |
| 2026-07-27 | L2-E on-chain inventory: **Uniswap V2/V3/V4 + Permit2 + Multicall3 live on mainnet**; **Balancer V3 absent** → we deploy; testnet has V4 CREATE2 + faucet stock mocks, **not** mainnet Uni V2/V3 factories | **Confirmed** (research) |
| 2026-07-27 | L2-E deploy BOM for vaults/DETFs/pools documented in **§2.9** (must-deploy vs reuse) | **Proposed** (ops checklist) |

---

## 7. Open questions for next discussion

### Locked / decided (summary)

- RICH 1B: **10% CCA**, **30% liquidity**, **2% team**, **58% unallocated (hold dry)**  
- Team vest = Bankr (2y / 30d cliff); tickers **RICH** + **RICHAI**  
- ETH quote; CCA floor **independent of RICHAI**; supply curve **back-loaded** ~5d  
- **CCA floor / FDV (2026-07-22):** **\(5\times10^{-7}\) ETH/RICH**; ~**$950k–$1M** FDV at floor (workshop ETH **$1,900**); [`CCA_FDV_WORKSHOP.md`](./CCA_FDV_WORKSHOP.md)  
- **Proceeds:** **~6.5 ETH ops**, rest liquidity; min raise **0**; planning success **50 ETH** / stretch **100 ETH** (not promises)  
- **Sequence:** **CCA fully clears** → **then RICHAI Bankr**  
- **30% seed:** size **at post-CCA runtime only**  
- **Launch fee sink:** **SingleVault DETF (RICH)** — DualLiquidity (removed) fee-sink deferred  
- **RICHAI buy ~$100 ETH** (demo only); **no day-1 dual seed theater**  
- RICHAI messaging **leads with RICH + IndexedEx**; agents can buy both  
- CCA proceeds + Bankr fee recipient → **`0xeD1FA21329fc45860cAB5D5E26a5fafcCDAcd6D5`**  
- Open agents+humans; **Superchain** bridge; donation fee path via **Vault Fee Collector**  
- **RICH fee model:** other vaults/DETFs → **donate into RICH liquidity** via **SingleVault DETF (RICH)**; capital raise still CCA; no cash APR claims until measurable make  
- **BattleChain (627):** greenfield = **community DeFi lab** publicly; ops per Crane master plan; parallel to CCA; not the raise  
- **CCA params:** sheet + JSON drafted; Base factory `0xCCcc…0bD5`; floor Q96 locked; token/blocks pending  
- **Gitlawb:** small USDC test first; creative later; landings = docs + CCA + Bankr when live  
- **Work track:** RICH deploy/bridge/CCA open → announcement; BattleChain promo parallel; donation in parallel  
- **Security:** no external audit budget; BattleChain + self-audit; Registry kill-switch (vault/package done; emergency withdraw deferred)  
- **RICH deploy:** Crane ERC20 Permit DFPkg on ETH  
- **DAOSYS launch:** deferred until after CCA + Bankr  
- **Bootstrap:** first bond / BPR path initializes reserve (Scenario3 pre-init is expected)  
- **L2-E eng (2026-07-27):** chain constants + RPC aliases landed; **Uniswap live / Balancer absent** on 4663; deploy BOM in **§2.9** (we ship Balancer + IndexedEx stack + DETFs)

### Still open

1. **Launch calendar** — exact open window / `startBlock` on Base (within 1–4 day execution).  
2. **Base RICH address** — after ETH deploy + Superchain bridge (patch CCA JSON).  
3. **BattleChain greenfield §0** — close remaining phase scripts/local tests; security contact; X draft review; then phased live + community posts.  
4. **BattleChain product wave** — IndexedEx / SingleVault DETF on BC only *after* greenfield base; never the public *reason* for greenfield.
5. **Donation eng details** — accepted assets, collector→donation call path, share/NAV rules (mechanism decided; interface TBD).  
6. **Emergency withdraw** — gated by registry disable (kill-switch query path done).  
7. **Bankr metadata final copy** + partner key vs 85/15.  
8. **Exact Gitlawb tip copy** when URLs exist (budget approach already locked).  
9. **SingleVault DETF (RICH) deploy args** — underlying SE (e.g. RICH/WETH vault), rateAsset, thresholds, bond terms.  
10. **L2-E hero DETF composition** — which SE legs (WETH/USDG, WETH/market, multi-leg weighted) and rateAsset.  
11. **L2-E RICH representation** — bridge design for fee-sink seed (dual-track A vs L2-E-first B).  
12. **L2-E testnet Uni V2/V3** — wait for official deploys vs self-deploy hermetic factories for SE tests only.  
13. **CCA on 4663** — factory presence / whether L2-E-first capital is even possible without Base.

## 8. Sources (research)

- Uniswap CCA product: https://cca.uniswap.org/  
- Uniswap blog — CCA: https://blog.uniswap.org/continuous-clearing-auctions  
- Uniswap blog — token auctions in app: https://blog.uniswap.org/token-auctions-are-coming-to-the-uniswap-web-app  
- Aztec CCA case study: https://blog.uniswap.org/aztec-cca  
- Uniswap CCA docs / launchpad: http://docs.uniswap.org/contracts/liquidity-launchpad/Overview  
- Bankr: https://bankr.bot/ · docs: https://docs.bankr.bot/ · token launching: https://docs.bankr.bot/token-launching/overview/  
- Bankr skills / deploy notes (GitHub): https://github.com/BankrBot/skills  
- Gitlawb Ads (agent-economy sponsored tips): https://ads.gitlawb.com/ · stack: https://gitlawb.com/  
- Internal: `docs/superpowers/plans/2026-07-05-dual-liquidity-linked-detf.md`, DualLiquidity (removed) DFPkg/PRD (bootstrap / first bond; weights 20/20/60)
- Internal: Vault Fee Collector (`contracts/fee/collector/`), Vault Registry (`contracts/registries/vault/`)
- Internal: CCA FDV workshop decisions — [`docs/CCA_FDV_WORKSHOP.md`](./CCA_FDV_WORKSHOP.md)
- BattleChain: https://docs.battlechain.com/ (safe harbor; no external audit budget for now)
- Expansion L2 connecting / protocol contracts / deploy: https://docs.robinhood.com/chain/connecting/ · https://docs.robinhood.com/chain/protocol-contracts/ · https://docs.robinhood.com/chain/deploy-smart-contracts/
- Uniswap V3/V4 Robinhood (4663) deploys: https://developers.uniswap.org/docs/protocols/v3/deployments/v3-robinhood-chain-deployments · https://developers.uniswap.org/docs/protocols/v4/deployments
- Crane constants: `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol`, `ROBINHOOD_TESTNET.sol`
- Product-track draft: [`docs/ROBINHOOD_LAUNCH_PLAN.md`](./ROBINHOOD_LAUNCH_PLAN.md)

---

## 9. How we will use this file

- Update **§6 Decision log** whenever we lock a choice.  
- Move items from **§7 Open questions** into decisions.  
- Keep **§2 Research** additive (date new findings; don’t erase old).  
- Engineering workstreams (deploy scripts, seed stages, agent APIs) should link back to **§5 phases**.

### 2.5 Addendum — ETH deploy + Base CCA (2026-07-11)

- Uniswap CCA is live on **Base** and **Ethereum**; web app supports **import existing token** or create new, then configure auction + post-auction pool.  
- Therefore “deploy on ETH, auction on Base” is **supported as a product path** provided the **Base token address** is what the auction commits and bidders receive.  
- Operational sequence that matches Uniswap’s model:  
  1. Deploy RICH on Ethereum.  
  2. Bridge (or mint representation of) the auction tranche to Base.  
  3. Launch CCA against the **Base** token address.  
  4. Settlement seeds **Base Uni v4**.  
  5. Keep non-auction L1 supply for treasury + optional later ETH CCA.  
- Risk to document publicly: bridge failure / incorrect representation = wrong token in the auction.

### 2.6 Addendum — dual fee tokens + DETF sink

- Separating **accumulation** (DETF) from **distribution** (RICH + RICHAI) is a clean systems design.  
- Failure mode: if fees never hit the DETF or **`donation` never makes liquidity**, fee tokens are narrative-only. Day-1 tests: vault action → fee inventory → `donation` → underlying vault/pool TVL up.  
- Dual fee tokens: publish that value is **make/NAV**, not a dual cash claim, unless you add one later.

### 2.9 Addendum — L2-E deploy BOM for vaults, DETFs, and pools (2026-07-27)

**Normative product narrative:** [`ROBINHOOD_LAUNCH_PLAN.md`](./ROBINHOOD_LAUNCH_PLAN.md).  
**This section is eng-only:** what already exists on expansion L2 **mainnet (chain id 4663)** and **testnet (46630)**, and what **IndexedEx / Crane must deploy** so Standard Exchange vaults, DETFs, and Balancer/Uni pools work. Public posts still follow the Olympus / DETF / Balancer / RICH story (no venue-chain brand requirement).

#### 2.9.1 Network facts (constants + RPC)

| | Mainnet | Testnet |
|--|---------|---------|
| **Chain ID** | **4663** | **46630** |
| **Stack** | Arbitrum Orbit L2, ETH gas | Same; settles to **Ethereum Sepolia** |
| **Public RPC** | `https://rpc.mainnet.chain.robinhood.com` | `https://rpc.testnet.chain.robinhood.com` |
| **Foundry aliases** | `robinhood_mainnet`, `robinhood_mainnet_alchemy` | `robinhood_testnet`, `robinhood_testnet_alchemy` |
| **Explorer / verify** | Blockscout `robinhoodchain.blockscout.com` (+ `/api/`) | `explorer.testnet.chain.robinhood.com` (+ `/api/`) |
| **Solidity libs** | Crane `ROBINHOOD_MAIN.sol` | Crane `ROBINHOOD_TESTNET.sol` |
| **Faucet** | n/a | `https://faucet.testnet.chain.robinhood.com/` (0.01 ETH + mock stock tokens / 24h) |

#### 2.9.2 Already live (reuse — do not redeploy)

**Mainnet (4663) — verified via public RPC + Uniswap / RH protocol docs:**

| Component | Role for IndexedEx | Status |
|-----------|--------------------|--------|
| **WETH** (`ROBINHOOD_MAIN.WETH9`) | rateAsset / wrap gas / pool leg | Live |
| **USDG** (6 dec) | Primary USD stable (not USDC) | Live |
| **Permit2** (canonical CREATE2) | SE router / Universal Router permits | Live |
| **Multicall3** + L2 Multicall | Batch reads / frontend | Live |
| **Uniswap V2** factory + Router02 | Optional SE vault pair legs | Live |
| **Uniswap V3** factory, NPM, QuoterV2, SwapRouter02 | Primary Uni SE legs | Live |
| **Uniswap V4** PoolManager + PositionManager + Quoter + StateView | V4 SE / LP surface | Live |
| **Universal Router** | Swaps / agent routing | Live |
| **Orbit bridges + precompiles** | ETH/ERC-20 deposit; L1↔L2 scripts | Live (L1 Ethereum + L2) |
| **Market-linked ERC-20s** | Optional DETF / SE legs | Live registry (spoof tickers exist — use `• Robinhood Token` / official registry only) |

**Testnet (46630):**

| Component | Status |
|-----------|--------|
| WETH, Permit2, Multicall3, L2 multicall, Orbit bridges | Live |
| Uni **V4** PoolManager + periphery + Universal Router | Live at **same CREATE2 addresses as mainnet** |
| Uni **V2 / V3** factories at mainnet addresses | **No code** — do not assume mainnet Uni addresses on testnet |
| Faucet mock stock tokens (TSLA, AMZN, PLTR, NFLX, AMD) | Live (simulation only) |
| USDG / mainnet stock registry | Not mirrored 1:1 |

#### 2.9.3 Missing (we must deploy) — critical for vaults + DETFs

**Balancer V3 is not on either network** (including common Vault address `0xbA13…`). DETF families require a **Balancer weighted (or family-specific) reserve**. Without deploying Balancer, we cannot ship true DETFs on L2-E.

| Wave | What we deploy | Why |
|------|----------------|-----|
| **C0 — Crane factories** | CREATE3 factory, DiamondPackageCallBackFactory, BetterPermit2 only if needed | All facets / packages; never `new` |
| **B0 — Balancer V3 Vault** | Vault + admin/extension/fee controller as required by Crane port | Pricing engine for DETF reserves |
| **B1 — Pool factories** | **WeightedPoolFactory** (must); StablePoolFactory (nice-to-have) | DETF default = weighted reserve |
| **B2 — Routers** | Balancer routers + **IndexedEx Balancer V3 SE Router** DFPkg | Swaps + vault orchestration |
| **B3 — Rate providers** | `StandardExchangeRateProvider` DFPkg instances per SE leg | Honest mint/burn quotes |
| **I0 — IndexedEx core** | IndexedexManager, FeeCollector, Vault Registry, Vault Fee Oracle | Registry deploy path for vaults/DETFs; kill-switch; fee routing |
| **S0 — SE vault packages** | Uni V2 and/or V3 (and V4 if package ready) Standard Exchange DFPkgs via **manager registry** | Wrap liquid Uni pools as vault shares |
| **S1 — SE instances** | ≥1 vault on liquid pair (e.g. **WETH/USDG** or WETH/market-leg) | Deposit path before DETF mint |
| **S2 — Balancer SE** | SE vault(s) on our seeded Balancer pools | Nested / Balancer-native legs |
| **D0 — DETF packages** | Facets + DFPkg(s): Single SE and/or Multi-vault weighted; **SingleVault DETF (RICH)** when RICH is present | Product surface |
| **D1 — DETF instances** | Inert deploy → **first bond** → live mint/burn under thresholds | Preview == execution on L2-E fork |
| **P0 — Seed pools** | ≥1 **Balancer Weighted** pool (WETH/USDG or WETH + SE share legs); optional Uni LP seed for SE depth | Public “DEX + product” claim minimum |
| **F0 — Frontend** | wagmi chain 4663/46630, tokenlists, address artifacts | Earn / swap / seigniorage UX |
| **R0 — RICH on L2-E** (post–Base CCA dual-track) | Bridged RICH representation + SE (RICH/WETH) + **SingleVault DETF (RICH)** fee sink | Fee-make center on product chain |

**Deploy rules (same as monorepo):** CREATE3 facets; vault/DETF DFPkgs only via **IndexedexManager vault registry**; production-first tests; role names only (`rateAsset`, `pairToken`, `underlyingVault`, …).

#### 2.9.4 Dependency order (minimum path to “vaults + DETFs + pools”)

```text
1. Crane CREATE3 + diamond package factory
2. Balancer V3 Vault + WeightedPoolFactory + routers
3. IndexedEx manager + FeeCollector + Vault Registry + fee oracle
4. Uni SE DFPkg + deploy vault on existing Uni pool (WETH/USDG recommended)
5. Seed Balancer Weighted pool (tokens / vault shares as designed)
6. StandardExchangeRateProvider(s) for each SE leg
7. DETF DFPkg → inert instance → first bond → live
8. (Optional / post-RICH) SingleVault DETF (RICH) + fee collector donation wiring
9. Frontend artifacts + public address book
```

**Definition of “live on L2-E” for launch claims:**

| Claim | Minimum on-chain proof |
|-------|------------------------|
| “Balancer V3 is live” | Vault + WeightedPoolFactory + **one** pool + explorer links |
| “SE vaults work” | Deposit/withdraw on a production Uni (or Balancer) SE instance |
| “DETF live” | Inert → first bond → mint/burn with **preview == execution** under default thresholds |
| “Fee-make works” | Fee inventory → collector → donation → measurable RICH liquidity (needs RICH + SingleVault DETF) |

#### 2.9.5 What we do *not* need to deploy day-1

| Item | Reason |
|------|--------|
| Uniswap V2/V3/V4 core on **mainnet** | Already present |
| Permit2 / Multicall3 | Canonical addresses live |
| Full stock-token laundry list as DETF legs | Legal/transfer matrix + thin liquidity; pick legs deliberately |
| DualLiquidity (removed) as fee sink | Launch fee sink remains **SingleVault DETF (RICH)** |
| CCA on 4663 | Not required for dual-track A (Base CCA remains capital raise) |
| Replacing Uni as “the” spot DEX | We own **weighted multi-asset + vault-native** narrative |

#### 2.9.6 Test plan surface

| Env | Goal |
|-----|------|
| **Hermetic** | Crane/IndexedEx Balancer + DETF gold TestBases (existing) |
| **Fork 4663** | `forge test --fork-url robinhood_mainnet` — WETH/Permit2/Uni code; Balancer absent; SE/DETF after our deploy scripts |
| **Fork / live 46630** | Rehearse full BOM with faucet ETH; Uni V4 only for native Uni legs until V2/V3 exist |
| **Post-deploy verify** | Blockscout `forge verify-contract --verifier blockscout` |

#### 2.9.7 Risks specific to this chain

| Risk | Mitigation |
|------|------------|
| **No Balancer until we ship it** | Treat B0–B2 as hard gate before DETF hero |
| **Stock-token spoofs** | Constants only for registry / `• Robinhood Token` names; re-verify at deploy |
| **Transfer / jurisdiction hooks** | SE + DETF transfer tests on chosen legs; fail closed |
| **Thin market-leg liquidity** | Thresholds / pool sizing for illiquid legs; invite arb |
| **Testnet Uni V2/V3 gap** | Prefer mainnet fork for Uni SE; or hermetic Uni ports on testnet |
| **Public RPC rate limits** | Alchemy aliases for CI / long forks |
| **RICH bridge to L2-E** | Document one representation; dual-track A keeps Base CCA as raise |

**Cross-links:** product phases R0–R6 in [`ROBINHOOD_LAUNCH_PLAN.md`](./ROBINHOOD_LAUNCH_PLAN.md) §5; launch checklist Phase **L2-E** in §5 above.

### 2.8 Addendum — typical % of supply sold (research 2026-07-11)

| Context | Typical public-sale share of total supply | Notes |
|---------|-------------------------------------------|--------|
| **Modern VC-style launches (2022–2023 benchmarks)** | **~4–5%** public sale | Tokenomist / Unlocks “standard allocation”: public investors ~**4.6%**; industry narrative is public sale shrank from ~**35% (2018 ICO era)** to ~**5% (2023)**. Community often largest bucket (~35–50%), treasury ~25–30%, team ~15–25%, private ~15–20%. |
| **Tokenomist glossary ranges** | **~1–5%** public investors | Common quoted band for “public investors” category. |
| **Historical ICO era (2017–2018)** | **~30–50%+** often crowdsale | Academic sample: average ICO offered ~**47%** of supply in the crowdsale; Ethereum famously ~**83%** public ICO (outlier by modern standards). |
| **Uniswap CCA reference (Aztec, Nov 2025)** | **up to 14.95%** open auction | Official terms: **1.547B / 10.35B** AZTEC for the Open Auction ≈ **14.95%** of initial total supply. Sold via CCA; raised ~$59M. This is a **high-end public CCA** vs today’s ~5% public norms, but still far below classic ICO floats. |
| **Fair-launch / LBP / meme launches** | **Often 50–100%** of circulating float into liquidity | Bankr-style: **85% to LP**, **15% creator vest** — not a “sold %” in the VC public-sale sense; almost all free float is market-tradable day one. |
| **IDO launchpads** | Often **small absolute raise**, **low single-digit %** of supply | Many IDOs raise modest $ and sell a thin slice; not standardized. |

**Practical bands for planning RICH Base CCA (of 1B):**

| Band | % of 1B | Tokens | When it fits |
|------|---------|--------|--------------|
| **Conservative / modern public** | **5–10%** | 50–100M | Aligns with post-2022 public-sale norms; less free-float pressure. |
| **→ RICH day-1 Base CCA (decided)** | **10%** | **100M** | Upper end of modern public band; leaves 90% for treasury / make / later ETH CCA. |
| **CCA-comparable (Aztec-like)** | **~12–20%** | 120–200M | Matches Aztec-scale public auction ambition. |
| **Aggressive public float** | **25–40%** | 250–400M | Closer to early ICO ethos; higher raise potential and dump risk. |
| **Hold for later ETH CCA** | Keep **≥20–40%** unallocated to day-1 sale | — | Compatible with 10% day-1 decision. |

Sources: [Tokenomist standard allocation](https://insights.unlocks.app/tokenunlocks-standard-allocation/), [Aztec auction terms](https://aztec.network/auction-terms-conditions) (14.95%), [Uniswap Aztec CCA writeup](https://blog.uniswap.org/aztec-cca), historical ICO averages (~47% sold in sample studies).

### 2.9 Addendum — Bankr quote asset, vesting, CCA duration (2026-07-11)

**Bankr quote / trading asset**

- Bankr docs: fees accumulate in **token + WETH**; creator claims in that pair.  
- Base agent plugin / buy flow: purchase Bankr launches with **`ETH` or `USDC`** via swap (`fromAsset` ETH or USDC).  
- Live BankrCoin pools are commonly **BNKR/WETH**.  
- **Conclusion:** User is **correct that ETH is the natural quote** for Bankr-aligned markets. CCA **quote asset = ETH** is consistent. USDC is also possible on Bankr buys but not required.  
- **Launch planning update (2026-07-14):** Creator vest still locked; optional **~$100 ETH** RICHAI buy for demo only. CCA runs **first and fully clears**; RICHAI **after**. Floor set independently for realistic FDV (workshop open).

**Bankr creator unlock (team vest mirror)**

- **15%** of Bankr token supply to creator.  
- **2 years total** vesting, **30-day cliff**, then continuous until fully unlocked at **2 years** (cliff inside the 2y window).  
- **RICH team vest:** same schedule (**2%** of RICH = 20M decided).  
- **RICHAI Bankr fee recipient:** same as CCA proceeds wallet.

**CCA duration peers**

| Auction | Duration |
|---------|----------|
| **Aztec CCA** | Public bidding **~4–5 calendar days** (reported Dec 2–6, 2025) plus earlier registration / pre-bid window |
| CCA product | Duration is a **configurable parameter** (no single mandated default) |

**Recommendation for this launch:** **5 days** open continuous clearing, **back-loaded** supply (more tokens later in the window). RICHAI launches **after** clearing ends. Optional short pre-bid / marketing window before clearing starts.

**Pricing / arb / sequence (updated 2026-07-14)**

- **Superseded:** half Bankr list; buy RICHAI first for spot; mid-CCA RICHAI stagger.  
- **Current:** set independent CCA floor/FDV → **back-loaded CCA** (~5d) → post-CCA seed **sized at runtime** → **RICHAI after CCA ends** → optional **~$100 ETH** RICHAI buy → dual LP only with real size.  
- **30% RICH reserve:** not pre-committed %; size when settling post-CCA.
### 2.7 Addendum — donation / buyback-and-make (2026-07-11; wording refined 2026-07-26)

> **Normative:** Fees from other vaults/DETFs are routed to **`donation` into RICH liquidity**. The launch fee sink is **SingleVault DETF for RICH** — it **accrues** those donations. Not a cash dividend on free-floating RICH.

**Mechanism (decided):**

| Step | Behavior |
|------|----------|
| 1 | Fees / assets arrive at **SingleVault DETF (RICH)** (fee sink). |
| 2 | Caller or keeper invokes **`donation`** on that DETF. |
| 3 | DETF **deposits into underlying SE vault** (RICH-linked as designed). |
| 4 | Vault **buys into / adds liquidity** in the underlying pool → **deeper RICH liquidity**. |
| 5 | Result: protocol-aligned **RICH liquidity make** + higher sink-DETF reserve quality / NAV. |

**Why this is viable:**

- Aligns with IndexedEx’s nested SE vault + pool graph (fees become **depth**, which improves product UX and can increase volume).  
- “Make” rather than “burn” matches a **liquidity protocol** narrative better than pure deflationary meme tokens.  
- Composable with agent thesis: more depth → better arb + deposit experience → more fees → more make.

**Design risks / engineering requirements:**

| Topic | Notes |
|-------|--------|
| **Who may call `donation`?** | Permissionless (anyone can push value in) vs keeper/operator only for routing logic. Permissionless donation is classic and donation-resistant share math matters. |
| **Share inflation / donation resistance** | Donating into vaults that mint shares to the DETF (or protocol) must not let attackers dilute user DETF shares unfairly. SingleVault DETF usage-fee splits + donation path need explicit tests (first depositor, sandwich, dust). |
| **Asset mix** | Fees may arrive as WETH, vault shares, BPT dust, etc. `donation` must define accepted tokens and routing (which underlying vault / pool leg). |
| **RICH** | Structural beneficiary of **liquidity make** (pools / sink DETF reserve), not a cash fee claim. |
| **RICHAI** | Companion; include in sink legs only if product maps RICHAI into the same DETF. |
| **1B supply optics** | Common round number; CCA % of 1B sets float. E.g. 20% CCA = 200M sold day-1. Document FDV carefully with floor price. |

**Industry parallel:** Protocol-owned liquidity / “buyback and make” (or “make and LP”) is established in DeFi as an alternative to buyback-and-burn; success depends on **measurable onchain make** (public donation events, growing vault/pool TVL attributable to fees).

---

*Last updated: 2026-07-27 — L2-E deploy BOM (§2.9): Balancer + IndexedEx core + SE/DETF/pools on chain 4663/46630; Crane `ROBINHOOD_*` constants + Foundry aliases. Next: greenfield §0 + RICH ETH deploy → bridge → CCA open; L2-E B0 Balancer after constants.*
