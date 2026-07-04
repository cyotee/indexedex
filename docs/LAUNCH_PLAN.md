# IndexedEx / DualLiquidityLinked DETF — Launch Plan

**Status:** Living document — research + decisions as of 2026-07-11  
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

Canonical economic home of the token contract is **Ethereum**. Day-1 sale liquidity and agent markets concentrate on **Base**.

### 1.2 Fee architecture (decided)

1. Strategy vaults and other DETFs generate fees (usage, swap routing, SE activity, etc.).  
2. Fees are directed into the **DualLiquidityLinked DETF**.  
3. The DETF exposes a **`donation` function** (to implement): donated assets are **deposited into the underlying strategy vaults**, which **buy into liquidity in the underlying pools**.  
4. That is explicitly a **buyback-and-make** strategy: fee value is used to deepen protocol-owned (or DETF-linked) liquidity rather than distributed as cash or burned.  
5. **RICH** and **RICHAI** are the **fee-distribution tokens** in the sense that their value is supported by this make/liquidity accumulation (and DETF share economics)—not by a classic claim-and-withdraw dividend, unless later extended.

```text
Vaults / DETFs / SE pools
        │  fees (assets / inventory)
        ▼
 DualLiquidityLinked DETF
        │  donation(assets)
        ▼
 Underlying strategy vaults
        │  exchangeIn / deposit
        ▼
 Underlying pools (LP / SE / reserve legs)
        │
        └── deeper liquidity + stronger DETF NAV
              → supports RICH / RICHAI as fee-distribution surface
```

**Naming note:** “Buyback and make” here means fee assets are **converted into protocol liquidity / reserve quality**, not necessarily “market-buy RICH then burn.” If fees arrive as non-RICH assets, the path is **make liquidity first**; market pressure on RICH/RICHAI is indirect via NAV and demand for fee-token exposure.

### 1.3 Token supply (RICH)

| Token | Supply | Notes |
|-------|--------|--------|
| **RICH** | **1,000,000,000** (1 billion) | Fixed launch supply (mint policy: no inflation after deploy unless explicitly decided later). CCA sells a **portion** of this; remainder = L1 treasury / ecosystem / optional later ETH CCA. |
| **RICHAI** | Bankr-fixed (**100B** platform default) | Not controlled by IndexedEx tokenomics the same way; treat as separate agent-market supply. |

### 1.4 Agent value proposition

Immediate benefits to agents (and agent operators):

1. **Outsource portfolio management** — Deploy strategy vaults and DETFs instead of continuously rebalancing positions themselves. Deposit assets into a chosen management strategy and walk away.
2. **Monitor for arbitrage** — Agents watch vaults, DETFs, and pools containing those tokens; close arb when mispricings appear.
3. **Volume → fees as protocol design** — Vaults present arb deliberately as a way to induce volume (fee generation) and as **market-driven automation** (arb bots keep links / reserves honest).
4. **Hold fee tokens** — RICH / RICHAI appreciate structurally as **donations deepen DETF-linked liquidity** (buyback-and-make), not only via speculative volume.

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
| Simultaneous RICH CCA + RICHAI Bankr | Still high messaging load; **sequencing optional** but both can live on Base without chain conflict. |

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

**Still recommended:** RICH as primary **reserve / common or linked** leg inside DualLiquidityLinked; RICHAI agent + secondary fee narrative unless later dual-reserve.
**Local testing gap (related):** Scenario3 registers Balancer pools without `initialize()` — production launch checklist must include **seed/init liquidity** for every public pool or quotes revert (`PoolNotInitialized`). Tracked separately in UI test plan; still a launch blocker.

---

## 4. Suggested changes to the draft plan

### 4.1 Strong recommendations (aligned with latest decisions)

1. **Chain topology (decided shape)**  

   ```text
   Ethereum:  deploy RICH (canonical supply control, treasury, optional later CCA)
        │ bridge (chosen standard)
        ▼
   Base:      RICH (bridged) ──► CCA sale ──► Uni v4 seed
              RICHAI (Bankr) ──► agent market
              DualLiquidityLinked DETF + strategy vaults (product home for fees)
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
   | % of **total** supply bridged to Base CCA | ☐ | 15–35% day-1 (150–350M RICH); keep L1 reserve for optional ETH CCA |
   | Floor price | ☐ | Conservative; publish FDV = floor × 1B carefully |
   | Duration | ☐ | Multi-day continuous clear |
   | Quote asset | ☐ | ETH/WETH on Base |
   | Proceeds split | ☐ | Runway % / DualLiquidityLinked seed % / ops |
   | L1 treasury / team vest | ☐ | Transparent; no surprise unlocks |
   | Optional ETH CCA | **Later only** | Trigger if capital gap or L1 market demand |

8. **RICHAI Bankr params**

   | Param | Open | Notes |
   |-------|------|-------|
   | Fee recipient | ☐ | Protocol distribution contract / multisig |
   | Metadata | ☐ | Link IndexedEx + RICH Base CCA + fee-token story |
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
- Using RICH and RICHAI as interchangeable legs in DualLiquidityLinked without a math redesign.  
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

Phase 2 — RICH: Ethereum deploy → Base bridge → Base CCA
  [ ] Deploy RICH on Ethereum (canonical)
  [ ] Bridge CCA tranche to Base
  [ ] Configure Base CCA (supply, floor, duration)
  [ ] Market CCA + fee-token + DETF utility (not pure FDV)
  [ ] Post-auction: seed DualLiquidityLinked / vault graph with proceeds + Base RICH
  [ ] Hold remaining L1 RICH for treasury + optional future ETH CCA

Phase 3 — RICHAI Bankr (Base)
  [ ] Deploy RICHAI; fee recipient = protocol distribution path
  [ ] Metadata → IndexedEx + RICH + dual fee-token story
  [ ] Agent campaigns: vaults, arb, hold fee tokens

Phase 4 — Flywheel
  [ ] Fees → DETF → donation → underlying vaults → pool make (live, measurable)
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
| 2026-07-11 | Prefer RICH as DETF reserve economic leg; RICHAI primarily distribution + agent market | Suggested |
| 2026-07-11 | Product / agent / CCA / Bankr day-1 liquidity home: **Base**; RICH canonical: **Ethereum** | **Decided** |
| 2026-07-11 | **RICH total supply = 1,000,000,000** | **Decided** |
| 2026-07-11 | Fee “distribution” = DETF **`donation`** → underlying vaults → pool liquidity = **buyback-and-make** | **Decided** |

---

## 7. Open questions for next discussion

1. **Bridge:** which ETH→Base path for RICH? Who controls Base representation?  
2. **DualLiquidityLinked legs:** RICH as common vs linked; pair with WETH?  
3. **`donation` routing:** which fee assets → which underlying vaults/pools? Permissionless?  
4. **RICHAI benefit path:** pure narrative on make, or explicit later inclusion?  
5. **% of 1B RICH** for Base CCA vs L1 reserve vs team/ecosystem?  
6. **Target raise / min viable proceeds** for Base CCA?  
7. **Timeline** to Phase 2?  
8. **Audit bar** before public donation + CCA?  
9. **Brand:** Pachira vs IndexedEx on CCA/Bankr metadata?  
10. **RICHIR / CHIR** naming vs RICH / RICHAI?


## 8. Sources (research)

- Uniswap CCA product: https://cca.uniswap.org/  
- Uniswap blog — CCA: https://blog.uniswap.org/continuous-clearing-auctions  
- Uniswap blog — token auctions in app: https://blog.uniswap.org/token-auctions-are-coming-to-the-uniswap-web-app  
- Aztec CCA case study: https://blog.uniswap.org/aztec-cca  
- Uniswap CCA docs / launchpad: http://docs.uniswap.org/contracts/liquidity-launchpad/Overview  
- Bankr: https://bankr.bot/ · docs: https://docs.bankr.bot/ · token launching: https://docs.bankr.bot/token-launching/overview/  
- Bankr skills / deploy notes (GitHub): https://github.com/BankrBot/skills  
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

*Last updated: 2026-07-11 — RICH 1B supply; DETF donation buyback-and-make into underlying vaults/pools.*
