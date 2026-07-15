# IndexedEx / DualLiquidityLinked DETF — Launch Plan

**Status:** Living document — research + decisions as of 2026-07-14  
**Owner discussion:** In progress (not frozen)  
**Primary product surface:** DualLiquidityLinked DETF + strategy vaults + agent portfolio tooling

---

## 1. Intent (working thesis)

### 1.1 Dual-token launch (updated)

| Token | Origin / venue | Stated purpose |
|-------|----------------|----------------|
| **RICH** | **Deploy on Ethereum mainnet** → **bridge to Base** → sell via **Uniswap CCA on Base** | Capital raise + price discovery + Base Uni v4 seed; **fee-distribution token** for the protocol flywheel |
| **RICHAI** | **Bankr** on Base (agent launchpad) | Agent/social traction; **fee-distribution token** alongside RICH |
| **Optional later** | Second **RICH CCA on Ethereum** | Additional capital only if needed — **not** day-1 |

Canonical economic home of the token contract is **Ethereum**. Day-1 sale liquidity and agent markets concentrate on **Base**. **Launch order:** Base **CCA for RICH first and fully clear**, then **RICHAI on Bankr after CCA ends** (see §1.3c).

### 1.2 Fee architecture (decided)

1. **All fees from other vaults / DETFs** flow into the **RICH/RICHAI DualLiquidityLinked DETF**.  
2. If fee inventory is **not** already WETH / RICH / RICHAI (or other tokens the DETF reserve accepts), it is **sold into WETH and/or RICH and/or RICHAI**, then donated.  
3. **`donation` is permissionless**: processes tokens into the reserve and **updates DETF state for consistency** (share/NAV accounting).  
4. Donation path deposits into underlying strategy vaults → **buy into liquidity in underlying pools** = **buyback-and-make**.  
5. **RICH** and **RICHAI** are fee-distribution tokens via deeper DETF-linked liquidity / NAV (not a classic cash dividend unless added later).

```text
Other vaults / DETFs
        │  fees (any assets)
        ▼
  [sell → WETH / RICH / RICHAI if needed]
        │
        ▼
 RICH/RICHAI DualLiquidityLinked DETF
        │  donation()  (permissionless)
        ▼
 Underlying strategy vaults → underlying pools
        └── make liquidity + consistent reserve state
```

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
| Pricing / floor offset | **Independent of RICHAI** — must set initial/floor price for realistic **fully diluted mcap** expectations (workshop still open; see §7) |
| Prior ideas (superseded) | ~~Floor = 0.5 × Bankr listing~~; ~~floor from RICHAI/WETH before CCA~~; ~~mid-CCA RICHAI stagger~~ |
| Duration | **~5 days** public clearing |
| Supply curve | **Back-loaded** over the window (more supply later in clearing) |
| Participation | **Open** — anyone + agents; market CCA during auction; RICHAI **after** CCA ends |
| Proceeds recipient | **`0xeD1FA21329fc45860cAB5D5E26a5fafcCDAcd6D5`** |
| Proceeds split | From that wallet: **~15 ETH (~$20k)** founder ops; **remainder → liquidity** |
| Bridge | **Canonical ETH→Base** for CCA tranche |

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

**CCA floor / initial price (open workshop):** Because CCA runs **before** RICHAI, floor cannot be derived from a Bankr print. Define independently so implied **fully diluted market cap** is a realistic expectation. Return before deploy (see §7).

**Messaging (RICHAI launch — post-CCA):**

1. Lead with **IndexedEx** + **RICH** (capital + fee-distribution; post-CCA market / Uni v4).  
2. State **RICH** role: L1-canonical capital + completed Base CCA + preferred DETF economic leg.  
3. State **RICHAI** role: agent-native fee-distribution + Bankr surface.  
4. Emphasize **agents can buy both** (RICH secondary/Uni; RICHAI Bankr/Uni).  
5. Cross-link Gitlawb Ads + product docs; do **not** frame RICHAI as the capital raise.

**Operational sequence (decided):**

1. Deploy RICH on ETH (1B); allocate CCA / team / liquidity buckets.  
2. Bridge CCA tranche to Base via canonical bridge.  
3. Set CCA floor/initial price for realistic FDV optics; **back-loaded** supply over ~5 days; open Base CCA (ETH quote).  
4. Market CCA hard (docs, agents, Gitlawb small test): capital raise + DualLiquidityLinked fee-make + agent participation.  
5. CCA clears → proceeds → **`0xeD1FA21329fc45860cAB5D5E26a5fafcCDAcd6D5`** (~15 ETH ops, rest liquidity).  
6. Post-auction: seed Uni v4 / DualLiquidityLinked / vault graph — **size from runtime** (proceeds + chosen slice of 30%).  
7. **After CCA ends:** launch **RICHAI** on Bankr; fee recipient = **same proceeds wallet**; metadata **leads with RICH + IndexedEx**; agents can buy both.  
8. Optional: **~$100 ETH** buy of RICHAI for protocol wallet (demo only).

### 1.4 Agent value proposition

Immediate benefits to agents (and agent operators):

1. **Outsource portfolio management** — Deploy strategy vaults and DETFs instead of continuously rebalancing positions themselves. Deposit assets into a chosen management strategy and walk away.
2. **Monitor for arbitrage** — Agents watch vaults, DETFs, and pools containing those tokens; close arb when mispricings appear.
3. **Volume → fees as protocol design** — Vaults present arb deliberately as a way to induce volume (fee generation) and as **market-driven automation** (arb bots keep links / reserves honest).
4. **Hold fee tokens** — RICH / RICHAI appreciate structurally as **donations deepen DETF-linked liquidity** (buyback-and-make), not only via speculative volume.

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

1. **Primary (Phase 2):** RICH / IndexedEx sponsored tips **during CCA** — bid path, fee-make, product links.  
2. **Secondary (Phase 3, post-CCA):** RICHAI / dual fee-token tips; always **point to RICH market + product**, not Bankr-as-raise.  
3. **Cross-promote on Bankr:** Bankr launch metadata, X/agent prompts **lead with RICH + IndexedEx**, then RICHAI; **reference Gitlawb Ads** (and vice versa).  
4. **Budget (decided):** **Small test first** (low hundreds USDC); scale only if agents respond. Fund from protocol-controlled address (not Bankr agent wallets).  
5. **Creative (decided):** Draft tip copy **later**; landings = **docs + CCA URL (Phase 2) + Bankr when live (Phase 3)**. Themes: vault/DETF outsourcing · invited arb · fee-make · **RICH CCA** · RICHAI · **agents can buy both**.

**Anti-pattern:** Treating Gitlawb Ads as the capital raise. It is **attention + agent discovery** only; capital raise remains Base CCA for RICH.

### 1.5 Product framing (one sentence)

> IndexedEx turns agent capital into **managed vault positions**, routes protocol fees into a **DualLiquidityLinked DETF `donation` path that makes liquidity in underlying vaults/pools**, and surfaces that flywheel through **RICH** (1B, ETH→Base CCA) and **RICHAI** (Bankr)—with markets kept honest by invited arbitrage.

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
| **Proceeds currency** | Base CCA bids typically in ETH/WETH on Base. Plan: runway % vs seed DualLiquidityLinked DETF / vault graph on Base. |
| **Optional ETH CCA later** | **Decided:** reserve option for additional capital; **not** day-1. Keeps L1 powder dry. |
| **Regulatory / communications** | CCA is transparent but still a token sale. Legal review required. |
| **Post-auction liquidity shape** | Base CCA seeds **Uni v4 on Base**. DualLiquidityLinked still needs SE vaults + Balancer reserve wiring on the **product chain(s)** — not automatic from CCA alone. |

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
| **Both RICH and RICHAI as fee-distribution tokens** | **Viable if** value path is **measurable make** (donation → TVL/NAV), not vague dual claim rights. RICHAI’s link to DualLiquidityLinked make still needs a clear public sentence. |
| **DETF as fee sink** for all other vaults/DETFs | **Strong** — especially with **`donation` buyback-and-make**. Requires fee-oracle / `feeTo` wiring + donation routing. Not “guaranteed yield.” |
| Both tokens as DualLiquidityLinked **reserve legs** | Still **risky** for pricing math — fee-distribution role ≠ both must be in the weighted reserve. Prefer DETF reserve in **WETH + RICH** (or protocol design choice) while RICHAI is distribution/claim/side market. |
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

## 3. Fit with DualLiquidityLinked DETF (internal)

From internal plans (`docs/superpowers/plans/2026-07-05-dual-liquidity-linked-detf.md` and related):

- DualLiquidityLinked DETF is a **share-based DETF** whose Balancer V3 weighted **reserve** composes:
  - two **commonToken / linked-token** Uni v4 Standard Exchange vaults  
  - one **tokenA / tokenB** Uni v2 SE vault  
  - quote-and-pick-best routing, usage-fee share inflation, immutable diamond deploy  
- Existing protocol vocabulary already includes **RICH**, **RICHIR**, **CHIR**, WETH legs, reserve pools.

**Launch implications (updated):**

| Decision | Implication for engineering |
|----------|----------------------------|
| DETF = **fee sink** for other vaults/DETFs | Wire fee oracle / `feeTo` (or equivalent) so fees land where `donation` can consume them. |
| **`donation` = buyback-and-make** | Implement DETF `donation` → deposit underlying strategy vaults → liquidity in underlying pools. Events for indexers/agents. Donation-resistant share accounting. |
| RICH + RICHAI = **fee-distribution tokens** | Value accrual via **deeper DETF-linked liquidity / NAV**, not necessarily a claimable dividend. Still need public wording for how each ticker benefits. |
| RICH **1B** fixed supply | Token constructor / mint-once; CCA + L1 allocations as % of 1B. |
| RICH L1 canonical, Base CCA | Deploy on **Ethereum**; bridge CCA tranche to Base; CCA uses Base address. |
| RICHAI Bankr Base | Fee recipient → protocol-controlled path. |
| Optional ETH CCA later | L1 holdback of 1B supply. |

**Reserve legs (decided 2026-07-14):** DualLiquidityLinked day-1 reserve includes **WETH + RICH + RICHAI**. Eng must design weighted reserve / donation routing for all three (not RICH-only).
**Local testing gap (related):** Scenario3 registers Balancer pools without `initialize()` — production launch checklist must include **seed/init liquidity** for every public pool or quotes revert (`PoolNotInitialized`). Tracked separately in UI test plan; still a launch blocker.

---

## 4. Suggested changes to the draft plan

### 4.1 Strong recommendations (aligned with latest decisions)

1. **Chain topology (decided shape)**  

   ```text
   Ethereum:  deploy RICH (canonical supply control, treasury, optional later CCA)
        │ bridge (chosen standard)
        ▼
   Base:      RICH (bridged) ──► CCA sale (FIRST, ~5d back-loaded) ──► Uni v4 seed
                         │
                         └── after CCA ends ──► RICHAI (Bankr) agent market
              DualLiquidityLinked DETF (WETH + RICH + RICHAI reserve) + strategy vaults
   ```

2. **Token roles (public one-pager)**  

   | Token | Role | Not |
   |-------|------|-----|
   | RICH | L1-canonical capital + Base CCA asset + **fee-distribution** + preferred DETF economic leg | Not “only a meme” |
   | RICHAI | Agent-native **fee-distribution** + social/Bankr traction | Not the L1 canonical capital raise; not necessarily DETF reserve math |
   | DualLiquidityLinked DETF | **Fee sink** + **`donation` buyback-and-make** into underlying vaults/pools | Not a claim-and-withdraw dividend vault (unless later added) |

3. **Fee path is buyback-and-make via `donation` (decided mechanism)**  
   Still open for eng spec:  
   - Which fees enter the DETF (list by facet/oracle).  
   - `donation` interface: assets accepted, routing to which underlying vaults, min amounts, reentrancy.  
   - Share/NAV accounting under donation (no unfair dilution).  
   - Keeper vs permissionless donation.  
   - How **RICHAI** shares the story if make only hits RICH-linked legs.
4. **Bridge selection is a launch-critical decision**  
   Options to evaluate: Superchain / native Base bridge for ETH↔Base ERC20; third-party (riskier for canonical narrative). Document **one** Base RICH address as “the” CCA and pool asset.

5. **Do not put protocol treasury, DETF admin, or fee-claim authority in Bankr agent wallets**  
   Multisig / diamond owner on ETH and Base; Bankr creator fee recipient = same controlled address or distribution contract.

6. **Agent product remains the moat**  
   Agent Launch Kit still required before or with CCA (deploy vault/DETF, deposit, monitor arb, claim fee-token story).

7. **RICH CCA params (Base auction)** — supply base **1,000,000,000**:

   | Param | Open | Starter suggestion |
   |-------|------|--------------------|
   | Total supply | **1B** | Decided |
   | % of **total** supply for Base CCA | **10%** | **Decided** → **100,000,000 RICH**; keep L1 reserve for optional ETH CCA |
   | Floor / initial price | **Independent; FDV workshop open** | Must imply realistic fully diluted mcap (see §7) |
   | Duration | **~5 days** | Peer Aztec ~4–5d; soft-decided |
   | Supply curve | **Back-loaded** | Decided |
   | Quote asset | **ETH** | Confirmed Bankr-aligned |
   | Proceeds split | **~15 ETH ops; rest liquidity** | Decided |
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
   - Cross-chain RICH: disclose bridge risk.

### 4.2 Optional / later

- **Bridge RICHAI → utility:** e.g. fee discounts, agent registry stake, or points toward vault strategies — only if it doesn’t pollute DETF accounting.  
- **Second CCA tranche** after product traction.  
- **Incentivized arb season** (small bounty pool) to bootstrap agent monitors.

### 4.3 Anti-patterns to avoid

- Treating Bankr launch as the capital raise (it is not).  
- Pricing CCA floor off a dust RICHAI print / day-1 dual seed theater.  
- Launching RICHAI **during** CCA (attention split) or same-T0 dual launch.  
- Setting CCA floor/FDV with no realistic fully diluted mcap story.  
- DualLiquidityLinked **WETH + RICH + RICHAI** reserve without explicit weights, donation routing, and share accounting.  
- Launching tokens before factory/registry deploys are **mainnet-ready and seeded**.  
- Overclaiming “agents will manage billions” before one public demo vault has real deposits.

---

## 5. Proposed phased launch (discussion draft)

```text
Phase 0 — Foundations (now)
  [ ] DualLiquidityLinked + strategy vault deploy path on Base (product home)
  [ ] Fee-oracle / feeTo path: other vaults/DETFs → DualLiquidityLinked DETF
  [ ] Implement DETF **donation** → underlying vaults → pool liquidity (buyback-and-make)
  [ ] Donation resistance + fee-path integration tests (fees → donation → TVL/NAV)
  [ ] RICH **1B** token (ETH) + bridge + audit scope
  [ ] Seed/init all public pools (no PoolNotInitialized)
  [ ] Agent docs + CLI/API (include donation / fee-make monitoring)
  [ ] Multisig treasury (ETH + Base) + fee recipients
Phase 1 — Soft product launch (testnet / limited mainnet)
  [ ] Public demo: deploy vault, deposit, show arb surface, show fee flow into DETF
  [ ] Agent onboarding guide + Bankr-friendly scripts

Phase 2 — RICH: Ethereum deploy → Base bridge → Base CCA (FIRST; fully clear)
  [ ] Deploy RICH on Ethereum (canonical)
  [ ] Bridge CCA tranche to Base
  [ ] Configure Base CCA: **back-loaded** supply, ~5d, ETH quote, **independent floor** (FDV workshop)
  [ ] **Open + clear CCA**; market hard: fee-token + DETF utility + agent bid path
  [ ] **Gitlawb Ads:** small USDC test campaign (CCA window + product links)
  [ ] Post-auction: seed Uni v4 / DualLiquidityLinked / vault graph — **size at runtime** from proceeds + 30% slice as needed
  [ ] Hold remaining L1 RICH (incl. most of 30% + **58% dry**) for treasury / later ETH CCA / ecosystem

Phase 3 — RICHAI Bankr (Base) — AFTER CCA ends
  [ ] Deploy RICHAI; fee recipient = **`0xeD1FA21329fc45860cAB5D5E26a5fafcCDAcd6D5`** (same as CCA proceeds)
  [ ] Metadata + launch posts **lead with RICH + IndexedEx**; dual fee-token; agents can buy both
  [ ] Optional: **~$100 ETH** buy of RICHAI for protocol demo wallet (not LP seed)
  [ ] Agent campaigns: vaults, arb, hold fee tokens
  [ ] **Bankr campaign copy references Gitlawb Ads** (and Gitlawb tips point to RICH market + RICHAI)
  [ ] **Gitlawb Ads:** RICHAI / dual fee-token tips (scale only if Phase 2 test worked)

Phase 4 — Flywheel
  [ ] DualLiquidityLinked reserve live: **WETH + RICH + RICHAI**; donation make measurable
  [ ] Agents deposit; arb volume; fee-make TVL dashboards
  [ ] Optional Phase 5: Ethereum CCA for additional RICH supply if capital needed
```

---

## 6. Decision log

| Date | Decision | Status |
|------|----------|--------|
| 2026-07-11 | Dual-token thesis (RICH capital + RICHAI agents) as working plan | Accepted for discussion |
| 2026-07-11 | Research: CCA viable for capital; Bankr for agent attention | Confirmed |
| 2026-07-11 | **RICH: deploy on Ethereum, bring to Base, sell in CCA on Base** | **Decided** |
| 2026-07-11 | **Optional additional RICH CCA on Ethereum later** if more capital needed | **Decided** (deferred) |
| 2026-07-11 | **DualLiquidityLinked DETF is fee sink** for other strategy vaults and DETFs | **Decided** (direction) |
| 2026-07-11 | **Both RICH and RICHAI are fee-distribution tokens** | **Decided** (direction) |
| 2026-07-11 | Prefer RICH as DETF reserve economic leg; RICHAI primarily distribution only | **Superseded** 2026-07-14 (all three in reserve) |
| 2026-07-14 | DualLiquidityLinked day-1 reserve legs: **WETH + RICH + RICHAI** | **Decided** |
| 2026-07-11 | Product / agent / CCA / Bankr day-1 liquidity home: **Base**; RICH canonical: **Ethereum** | **Decided** |
| 2026-07-11 | **RICH total supply = 1,000,000,000** | **Decided** |
| 2026-07-11 | Fee “distribution” = DETF **`donation`** → underlying vaults → pool liquidity = **buyback-and-make** | **Decided** |
| 2026-07-11 | **Base CCA sells 10% of RICH** (100M of 1B); rest held for treasury / ecosystem / optional later ETH CCA | **Decided** |
| 2026-07-12 | Remaining supply: **30% liquidity**, **2% team**, **10% CCA**, **58% unallocated** | **Decided** |
| 2026-07-14 | **58% residual hold dry** (treasury / later ETH CCA / ecosystem) — no public sub-buckets yet | **Decided** |
| 2026-07-12 | **Team = 2%** (20M); vest = Bankr schedule (2y / 30d cliff) | **Decided** |
| 2026-07-11 | CCA **quote asset = ETH** | **Decided** |
| 2026-07-12 | CCA floor offset **definable at deploy-script runtime** (not hard-coded ½ Bankr) | **Decided** |
| 2026-07-13 | CCA floor **independent of RICHAI/WETH** — RICHAI does not set CCA floor | **Decided** |
| 2026-07-14 | CCA floor/initial price → **FDV workshop** (realistic fully diluted mcap); numbers not locked yet | **Open** (return before deploy) |
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
| 2026-07-11 | Proceeds: **~15 ETH (~$20k)** founder ops; **rest → liquidity** | **Decided** |
| 2026-07-12 | CCA proceeds recipient: **`0xeD1FA21329fc45860cAB5D5E26a5fafcCDAcd6D5`** | **Decided** |
| 2026-07-11 | **Canonical ETH→Base bridge** for RICH CCA tranche | **Decided** |
| 2026-07-11 | Cross-pool arb allowed as discovery; **not** designed as forced drain of locked Bankr LP | **Decided** |
| 2026-07-11 | All vault fees → RICH/RICHAI DETF; convert to WETH/RICH/RICHAI then donate; **donation permissionless** | **Decided** |
| 2026-07-12 | External third-token pairing deferred; **omit from launch materials** | **Decided** |
| 2026-07-13 | **Gitlawb Ads** as launch distribution; Bankr campaign cross-references Gitlawb | **Decided** (direction) |
| 2026-07-14 | Gitlawb budget: **small test first** (low hundreds USDC); creative draft later; landings = docs + CCA + Bankr when live | **Decided** |
| 2026-07-14 | Tickers locked **RICH** + **RICHAI**; formal **audit + calendar still open** | **Decided** (partial) |

---

## 7. Open questions for next discussion

### Locked / decided (summary)

- RICH 1B: **10% CCA**, **30% liquidity**, **2% team**, **58% unallocated (hold dry)**  
- Team vest = Bankr (2y / 30d cliff); tickers **RICH** + **RICHAI**  
- ETH quote; CCA floor **independent of RICHAI**; supply curve **back-loaded** ~5d  
- **Sequence:** **CCA fully clears** → **then RICHAI Bankr**  
- **30% seed:** size **at post-CCA runtime only**  
- DualLiquidityLinked reserve: **WETH + RICH + RICHAI**  
- **RICHAI buy ~$100 ETH** (demo only); **no day-1 dual seed theater**  
- RICHAI messaging **leads with RICH + IndexedEx**; agents can buy both  
- CCA proceeds + Bankr fee recipient → **`0xeD1FA21329fc45860cAB5D5E26a5fafcCDAcd6D5`** (~15 ETH ops, rest LP)  
- Open agents+humans; canonical bridge; donation fee path  
- **Gitlawb:** small USDC test first; creative later; landings = docs + CCA + Bankr when live  

### Still open

1. **CCA floor / initial price → realistic FDV workshop** — pick floor and implied fully diluted mcap before deploy (CCA runs before RICHAI, so no Bankr reference).  
2. **Audit scope** — token + product path; required before CCA?  
3. **Launch calendar** — target window / month.  
4. **DualLiquidityLinked weights** among WETH / RICH / RICHAI + donation routing details.  
5. **Bankr metadata final copy** + partner key vs 85/15.  
6. **Exact Gitlawb tip copy** when URLs exist (budget approach already locked).

## 8. Sources (research)

- Uniswap CCA product: https://cca.uniswap.org/  
- Uniswap blog — CCA: https://blog.uniswap.org/continuous-clearing-auctions  
- Uniswap blog — token auctions in app: https://blog.uniswap.org/token-auctions-are-coming-to-the-uniswap-web-app  
- Aztec CCA case study: https://blog.uniswap.org/aztec-cca  
- Uniswap CCA docs / launchpad: http://docs.uniswap.org/contracts/liquidity-launchpad/Overview  
- Bankr: https://bankr.bot/ · docs: https://docs.bankr.bot/ · token launching: https://docs.bankr.bot/token-launching/overview/  
- Bankr skills / deploy notes (GitHub): https://github.com/BankrBot/skills  
- Gitlawb Ads (agent-economy sponsored tips): https://ads.gitlawb.com/ · stack: https://gitlawb.com/  
- Internal: `docs/superpowers/plans/2026-07-05-dual-liquidity-linked-detf.md`, Scenario3 pool init gap (UI test plan)

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
### 2.7 Addendum — donation / buyback-and-make (2026-07-11)

**Mechanism (decided):**

| Step | Behavior |
|------|----------|
| 1 | Fees / assets arrive at DualLiquidityLinked DETF (fee sink). |
| 2 | Caller or keeper invokes **`donation`** on the DETF. |
| 3 | DETF **deposits into underlying strategy vaults**. |
| 4 | Those vaults **buy into / add liquidity** in underlying pools. |
| 5 | Result: more protocol-aligned liquidity + higher DETF reserve quality / NAV support for fee tokens. |

**Why this is viable:**

- Aligns with IndexedEx’s nested SE vault + pool graph (fees become **depth**, which improves product UX and can increase volume).  
- “Make” rather than “burn” matches a **liquidity protocol** narrative better than pure deflationary meme tokens.  
- Composable with agent thesis: more depth → better arb + deposit experience → more fees → more make.

**Design risks / engineering requirements:**

| Topic | Notes |
|-------|--------|
| **Who may call `donation`?** | Permissionless (anyone can push value in) vs keeper/operator only for routing logic. Permissionless donation is classic and donation-resistant share math matters. |
| **Share inflation / donation resistance** | Donating into vaults that mint shares to the DETF (or protocol) must not let attackers dilute user DETF shares unfairly. DualLiquidityLinked already has USAGE fee share splits; donation path needs explicit tests (first depositor, sandwich, dust). |
| **Asset mix** | Fees may arrive as WETH, vault shares, BPT dust, etc. `donation` must define accepted tokens and routing (which underlying vault / pool leg). |
| **RICH buy pressure** | Pure make does **not** automatically buy RICH on the open market unless fees are swapped to RICH first or RICH is a pool leg being filled. Messaging should say **liquidity make / NAV support**, not “forced daily RICH buyback,” unless that step is added. |
| **RICHAI** | Bankr token is separate; fee-make on DualLiquidityLinked primarily supports **RICH + DETF**. Clarify how RICHAI holders benefit (narrative only vs later inclusion in donation graph). |
| **1B supply optics** | Common round number; CCA % of 1B sets float. E.g. 20% CCA = 200M sold day-1. Document FDV carefully with floor price. |

**Industry parallel:** Protocol-owned liquidity / “buyback and make” (or “make and LP”) is established in DeFi as an alternative to buyback-and-burn; success depends on **measurable onchain make** (public donation events, growing vault/pool TVL attributable to fees).

---

*Last updated: 2026-07-14 — Open Q batch closed: CCA fully first then RICHAI; back-loaded CCA; 30% runtime seed; WETH+RICH+RICHAI reserve; 58% dry; Gitlawb small test; FDV floor workshop still open.*
