# IndexedEx launch-plan agent handoff

Paste the block below into a new agent session to get it up to speed on launch plans (RICH/CCA, BattleChain, L2-E).

---

## Prompt (copy from here)

```text
You are continuing work on IndexedEx (monorepo at repo root). Read the following in order before proposing or changing anything. Prefer existing docs and constants over inventing process.

### Required reading (order)

1. Root agent rules: `AGENTS.md` / `Agents.md` (esp. CREATE3, vault registry path, production-first tests, DETF role naming).
2. Living launch plan: `docs/LAUNCH_PLAN.md`
   - Dual-token RICH (ETH→Superchain→Base CCA) then RICHAI on Bankr after CCA clears
   - Fee model: other vaults/DETFs → Vault Fee Collector → donation into **RICH liquidity** via **SingleVault DETF (RICH)** (not DualLiquidity (removed) day-1)
   - CCA params / FDV: `docs/CCA_FDV_WORKSHOP.md`, `docs/CCA_PARAMETER_SHEET.md`, `docs/cca/base-rich-cca-config.json`
   - BattleChain as **promo + adversarial lab**, not the capital raise (§1.4b)
   - Expansion L2 (internal L2-E, chain **4663** / testnet **46630**) deploy BOM: **§2.9** — reuse Uni/Permit2; **we must deploy Balancer V3 + IndexedEx core + SE + DETFs**
   - Phase checklists §5 (incl. Phase L2-E); decision log §6; open questions §7
3. L2-E product track (narrative + product architecture): `docs/ROBINHOOD_LAUNCH_PLAN.md`
   - Public copy: Olympus / “launch your own OHM”; **avoid venue-chain and stock-token branding** in public posts
4. BattleChain greenfield (ops authority is Crane, not IndexedEx invent-as-you-go):
   - Master checklist: `lib/crane/docs/deployment/BC_GREENFIELD_MASTER_PLAN.md`
   - PRD / binds / research: `lib/crane/docs/deployment/BC_GREENFIELD_DEPLOYMENT_PRD.md`,
     `BC_GREENFIELD_DEPLOY_RESEARCH.md`, `BC_GREENFIELD_INVENTORY.md`,
     `BC_GREENFIELD_SCRIPT_GUIDE.md`, `BC_GREENFIELD_PHASE_DEPLOY_STEPS.md`
   - Promo public narrative: `docs/BATTLECHAIN_LAUNCH_PROMO.md`
   - Constants: `lib/crane/contracts/constants/networks/BC_TESTNET.sol` (chain 627), optionally `BC_MAIN.sol`
   - Policy: **bind BC-provided contracts; never redeploy them** (WETH, Uni V3, tokens, Chainlink mocks, Euler, Venus, **Morpho**, Safe, etc.)
5. Expansion L2 constants (already landed):
   - `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol` (4663)
   - `lib/crane/contracts/constants/networks/ROBINHOOD_TESTNET.sol` (46630)
   - Foundry aliases in root + Crane `foundry.toml`: `robinhood_mainnet`, `robinhood_testnet` (+ Alchemy variants)

### Locked / working decisions (do not re-litigate unless docs say Open)

- **Capital raise:** RICH 1B total; **10% (100M)** via **Uniswap CCA on Base** (ETH quote); deploy RICH on **Ethereum** (Crane ERC20 Permit DFPkg) → **canonical Superchain bridge** CCA tranche to Base.
- **Sequence:** CCA fully clears → **then** RICHAI on Bankr (~$100 ETH demo buy only; not LP seed theater).
- **Fee sink at launch:** `SingleVaultDetf` for RICH — fees **donate into RICH liquidity**; no cash-APR claims until measurable make.
- **BattleChain (627):** greenfield deploys Crane multi-protocol stack for **community + Safe Harbor / adversarial validation**; parallel to CCA; not a substitute raise.
- **BC Morpho / Euler / Venus / Uni V3:** **already on BC as mocks — bind only.** Morpho mock: `BC_TESTNET.MORPHO` (`0x102CdAF4B7097752f2Bb336c6cDf39f0aBBbb58c`). Do **not** add Morpho core deploy to BC scripts.
- **L2-E day-1:** Uni V2/V3/V4 + Permit2 + Multicall live on 4663; **Balancer V3 absent** → IndexedEx/Crane deploys Balancer + manager/registry + SE vaults + DETFs + seed pools.
- **Defer Aave** for L2-E initial launch (oracle-heavy). No Aave/lending SE vaults currently wired to Robinhood/L2-E.
- **Morpho skills** exist in Crane and are synced into IndexedEx `.claude/.opencode/.grok/skills` (`crane-morpho`, `morpho-*`). Use for Morpho SE work later; BC still binds BC’s Morpho mock.

### Deploy ladders (mental model)

**Base / ETH (capital):**
RICH on ETH → bridge → Base CCA → post-clear Uni v4 seed + SingleVault DETF (RICH) fee-make path on product chain(s).

**BattleChain (promo/adversarial):**
Phase scripts under Crane greenfield (factories → Balancer → Aave port phases on BC where in scope → bind Euler/Venus; Morpho bind-if-needed) → later IndexedEx product packages on top. Public narrative = open toolkit for builders/whitehats.

**L2-E product (4663):**
Crane CREATE3 → Balancer V3 Vault + Weighted factory + routers → IndexedEx manager/FeeCollector/registry/oracle → Uni SE vaults (WETH/USDG etc.) → seed Balancer pools → rate providers → DETF inert → first bond → live. Optional: bridge RICH + SingleVault DETF (RICH) fee sink after capital clear.

### Your first tasks when starting

1. Summarize current phase status from `LAUNCH_PLAN.md` §5 and BC master plan checkboxes (what is done vs open).
2. State whether your task is: Base CCA / RICH, BattleChain greenfield, or L2-E product — do not mix capital raise with BC promo narrative in public copy.
3. For any deploy: CREATE3 + FactoryService; vault/DETF DFPkgs only via **IndexedexManager vault registry**; never `new` facets/DFPkgs; production-first tests.
4. If changing launch decisions, update `docs/LAUNCH_PLAN.md` decision log (§6) rather than only chatting.

### Explicit non-goals unless reopened

- Using DualLiquidity (removed) as day-1 fee sink
- Day-1 Aave on L2-E
- Redeploying BC-provided Morpho/Uni V3/etc. on BattleChain
- Venue-chain or “stock token” framing in public launch marketing
- Treating BattleChain as the RICH capital raise venue

After reading, reply with: (A) 10-bullet status of the launch plan, (B) top 5 open blockers, (C) which track you will execute next and the first concrete file/script you will touch.
```

---

## Optional track suffixes

Append one line if the agent is track-specific:

- **BattleChain-only:** Focus on Crane `BC_GREENFIELD_*` + `BC_TESTNET` binds; do not plan Morpho redeploy.
- **L2-E-only:** Focus on `LAUNCH_PLAN` §2.9 + `ROBINHOOD_*` constants; Balancer deploy is the gate; defer Aave.
- **CCA/RICH-only:** Focus on ETH RICH + Superchain + Base CCA sheets; BC and L2-E are parallel, not blockers for CCA open unless docs say otherwise.
