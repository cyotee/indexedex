# Product Requirements Document (PRD)

## Title

Uniswap Continuous Clearing Auction (CCA) Rehearsal — Auction UX, Settlement, and Post-Clear Product Path Research

## Status

**PLANNED** — research + dry-run scenario family for **RICH Base CCA** launch readiness and **publishable auction advertising**.  
Normative launch context: [`docs/LAUNCH_PLAN.md`](../../../docs/LAUNCH_PLAN.md).  
Implementation plan: [`CCA_Rehearsal_IMPLEMENTATION_AND_TEST_PLAN.md`](./CCA_Rehearsal_IMPLEMENTATION_AND_TEST_PLAN.md).

## Purpose

Produce **reviewable, reconstructable evidence** that IndexedEx can:

1. Run a **CCA-style sale path** (or Uniswap CCA on Base fork / testnet) with a **fixed-supply Permit ERC-20** stand-in for RICH.  
2. Document **bidder participation** end-to-end (bid → clear → claim / receive tokens).  
3. Document **post-clear settlement** (proceeds custody shape + Uni v4 seed path at discovered price).  
4. Connect auction proceeds to a **minimal DualLiquidity / SE stack bootstrap playbook** (runtime-sized; no fake TVL promises).  
5. Feed **ad-safe claims** for CCA marketing (Gitlawb Ads, docs, agents) without inventing mainnet raise outcomes.

### Why this exists

IndexedEx already has strong **product research** (SE re-mark, fee-as-arb threshold, DualLiquidity deposit→nested volume, both linked legs). That supports *why the protocol exists*.  

Launch plan day-1 is **RICH Base CCA first** (then RICHAI on Bankr). Auction advertising needs *why bid this sale* and *what happens when it clears* — currently **not** covered by DualLiquidity/SE matrices.

| Audience need | Covered today? |
|---------------|----------------|
| Protocol thesis (SE / DualLiquidity) | **Yes** — marketing roll-up |
| CCA participation UX | **No** |
| Post-CCA pool seed + product wiring checklist | **Partial** (launch plan narrative only) |
| Fee-make `donation` demo | **No** (separate campaign; out of scope v1 of this PRD) |
| Live mainnet APY / raise forecast | **Never** this research family’s job |

### Research questions (normative)

| ID | Question |
|----|----------|
| **RQ1** | Can we deploy a **fixed-supply ERC-20 Permit** (Crane DFPkg path or gold test path) suitable as a RICH stand-in for auction research? |
| **RQ2** | Can we execute a **full CCA path** on Base (fork and/or public testnet): create auction → fund supply → bid with ETH/WETH → advance time through clearing → settle distributions? |
| **RQ3** | What is the **minimum bidder checklist** (wallet, assets, UI/CLI steps, failure modes) suitable for public “how to participate” docs? |
| **RQ4** | After clear, what is the **observable post-auction market state** (pool existence, price vs last clear, balances of seller / buyer)? |
| **RQ5** | Given a **fixed synthetic raise R** (ETH), what is a **minimal post-clear product deploy sequence** (SE legs + DualLiquidity bootstrap) that is operationally runnable and diagrammable for ads? |
| **RQ6** (stretch) | Can a **canonical Superchain bridge** step (ETH→Base for CCA tranche) be dry-run or documented with enough fidelity for launch ops without executing mainnet capital? |

Results update the marketing roll-up and launch plan workshop items; they do **not** claim Aztec-scale raises, guaranteed clearing prices, or mainnet fee APR.

---

## SUT and naming

### Subjects under test / rehearsal

| Item | Role |
|------|------|
| **Auction token (stand-in)** | Fixed-supply ERC-20 with permit; research name **`auctionToken`** (maps to RICH in launch plan; **do not** hardcode brand in production vault role names) |
| **Quote asset** | **ETH / WETH** on Base (launch plan) |
| **Auction mechanism** | **Uniswap CCA** (Continuous Clearing Auction) — live protocol on Base when available; fork/testnet ports if needed |
| **Optional product stack** | DualLiquidity Linked Cross-Version + Uni V4/V2 SE legs (existing gold TestBase / research fixture) for RQ5 only |
| **Launch plan** | `docs/LAUNCH_PLAN.md` — CCA first, RICHAI after clear |

### Role names (mandatory in research code/docs)

| Role | Meaning |
|------|---------|
| `auctionToken` | Fixed-supply token sold in the rehearsal CCA (RICH stand-in) |
| `quoteAsset` | ETH or WETH used to bid |
| `auctionContract` / `cca` | CCA instance under test |
| `proceedsRecipient` | Address receiving ETH proceeds (research may use a labeled research address; launch plan has a production wallet — **do not** require mainnet use in research) |
| `bidder` / `researchBidder` | Funded research wallet(s) |
| DualLiquidity roles | `commonToken`, `tokenA`, `tokenB`, `vaultA`, `vaultB`, `pairVault`, `reservePool` — only when RQ5 maps them |

**Anti-patterns:** claiming research stand-in is mainnet RICH; putting treasury keys in Bankr agent wallets; inventing floor prices as “research results” without labeling them as **workshop parameters**.

### What this is / is not

| Is | Is not |
|----|--------|
| Dry-run / fork / testnet **rehearsal** of CCA + post-clear path | Live mainnet capital raise |
| Evidence for **auction ads and ops checklists** | Prediction of raise size or FDV |
| Optional thin DualLiquidity bootstrap after a **synthetic** raise | Full fee-make `donation` implementation (sibling campaign) |
| Publishable “how to bid / what clears” narrative | Legal opinion or securities advice |

---

## Locked decisions

Do not re-open without an explicit PRD revision.

| Topic | Decision |
|-------|----------|
| Normative launch sequence | **CCA first, fully clear**, then RICHAI (Bankr) — cite launch plan §1.3c |
| Quote asset | **ETH** (WETH where contracts require) |
| Auction venue research default | **Base** (fork and/or Base Sepolia / equivalent public testnet) |
| Auction supply for research | Configurable; default **mirror launch shape**: 10% of stand-in total supply (e.g. 100M of 1B) unless meta documents otherwise |
| Duration / curve | Prefer **~5 days**, **back-loaded** supply when CCA config allows; compressed time via `vm.warp` on fork |
| Stand-in token | Crane **ERC20 Permit DFPkg** or existing production-first mintable path — **fixed supply**, no open mint after deploy |
| Brand names in product vault code | **Role names only**; RICH/RICHAI only in launch/marketing narrative layers |
| Environment ladder | **(1)** Base mainnet fork with CCA + Uni contracts if addresses known; **(2)** public testnet full UX; **(3)** hermetic only if CCA port exists in Crane stubs |
| Foundry | `FOUNDRY_PROFILE=default` for scripts; `fork` profile for fork tests; document RPC (`base_mainnet_alchemy` / testnet) |
| Proceeds | Research may use `makeAddr("ccaProceeds")` or documented test wallet; launch plan production address is **reference only** |
| DualLiquidity in this PRD | **RQ5 only** — bootstrap after synthetic raise; do not re-open residual/arb DualLiquidity research |
| Fee `donation` / kill-switch | **Out of scope v1** — separate campaigns; mention as blocked ad claims |
| Artifacts | New tree only: `research/out/cca/rehearsal/` |
| Tracked narrative | `research/scenarios/cca/` |
| Isolation | Do not overwrite `research/out/uniswapV2Se/**` or DualLiquidity `v1`/`v2` trees |
| Marketing rule | Every public claim must map to a **rehearsal artifact** or an explicit **workshop parameter** (floor/FDV), never a fabricated live raise |

### Clarifications vs launch plan (inherited, not re-litigated)

| Topic | Launch plan decision (inherited) |
|-------|----------------------------------|
| RICH supply | 1B fixed; Base CCA sells **10%** (100M) |
| Bridge | Canonical Superchain OP Stack ETH→Base for CCA tranche |
| Proceeds split (production) | ~15 ETH founder ops; remainder liquidity |
| Floor / initial price | **Locked 2026-07-22** — [`docs/CCA_FDV_WORKSHOP.md`](../../../docs/CCA_FDV_WORKSHOP.md): **\(5\times10^{-7}\) ETH/RICH**; FDV at floor ~500 ETH / ~$950k @ $1,900. Research uses same ratio; does not re-litigate public FDV |
| RICHAI | After CCA ends — **not** in CCA Rehearsal v1 success criteria |

---

## Scope

### In scope (v1)

1. Research PRD (this file) + implementation plan + FINDINGS + agent handoff after runs.  
2. Stand-in `auctionToken` deploy path (production-first).  
3. CCA create / fund / bid / time-advance / settle on **Base fork and/or testnet**.  
4. Telemetry: meta.json + step log (JSONL or structured markdown runbook) for each phase.  
5. Bidder checklist suitable for public docs.  
6. Post-clear observations (pool / balances / price notes).  
7. RQ5: **one** post-clear DualLiquidity (+ SE) bootstrap using a **synthetic ETH budget R** and stand-in mapping (document token roles).  
8. Marketing claim → evidence map for auction ads.  
9. Runner script(s) under `research/run_cca_rehearsal.sh` (or equivalent).

### Out of scope (v1)

- Live mainnet RICH deploy, bridge of real supply, or real CCA with public capital.  
- RICHAI Bankr launch rehearsal (Phase 3 of launch plan).  
- Implementing DualLiquidity `donation` / fee-collector routing (sibling PRD).  
- Vault Registry kill-switch implementation (engineering track; note dependency for full launch announce).  
- Multi-protocol SE Mode A twins; DualLiquidity Mode C arb fills.  
- Legal review, securities classification, or exchange listing.  
- Guaranteeing raise size, FDV, or post-auction secondary market performance.  
- Re-running SE / DualLiquidity residual matrices.

### Stretch (v1 optional)

| ID | Stretch |
|----|---------|
| S1 | Superchain bridge dry-run (testnet) for auctionToken tranche |
| S2 | Multi-bidder stress (N research bidders, concurrent bids) |
| S3 | Compressed vs wall-clock testnet CCA (document gas / UX friction) |
| S4 | UI screenshots from Uniswap Web App CCA flow (manual; store under `research/out/cca/rehearsal/ui/`) |

---

## Topology under test

### Auction path (primary)

```text
deploy auctionToken (fixed supply)
        │
        ▼
   [optional bridge ETH → Base]     # stretch / ops doc
        │
        ▼
 create + fund Uniswap CCA (Base)
        │
        ├─► bid(quoteAsset) from researchBidder(s)
        ├─► warp / wait through clearing blocks
        ▼
 settle / claim auctionToken + route proceeds
        │
        ▼
 post-clear Uni v4 pool seed (CCA mechanism or manual)
```

### Post-clear product path (RQ5)

```text
synthetic raise R (ETH)
        │
        ▼
 deploy / attach SE legs (common/tokenA, common/tokenB, pair)
        │
        ▼
 DualLiquidity DFPkg deploy + bootstrap reserve + book deposit
        │
        ▼
 volume / inventory snapshot (reuse DualLiquidity v2 attribution fields if cheap)
```

Weights: DualLiquidity package defaults **20 / 20 / 60** unless meta overrides. Mapping of `commonToken`/`tokenA`/`tokenB` to WETH/auctionToken/… is **documented in meta** for each run (launch plan targets WETH+RICH+RICHAI for day-1 product — research may use stand-ins).

---

## Scenario modes

### Mode A — Auction mechanics dry-run (priority 1)

**Drive:** Create CCA, fund with auctionToken supply slice, place ≥1 successful bid, advance to clear, settle.

**Goals:**

- Prove tooling + addresses + time control work on chosen environment.  
- Capture clearing-relevant fields (block, price, filled amount, proceeds).  
- List failure modes (insufficient approval, wrong chain, expired auction, underfunded supply).

**Success signals:**

- At least one full path without manual debugger intervention beyond documented steps.  
- Artifacts sufficient to rewrite a public “how to bid” checklist.

### Mode B — Bidder multi-path / UX (priority 2)

**Drive:** Second bidder, partial fills, late-window bid if config allows; document UI vs script paths.

**Goals:**

- Agent- and human-readable participation steps.  
- Gas / timing notes for ~5 day narrative vs warp.

**Success signals:**

- Checklist covers both “scripted bid” and “Uniswap UI bid” when UI is available.  
- Explicit “what can go wrong” section.

### Mode C — Post-clear product bootstrap (priority 3)

**Drive:** After Mode A (or with synthetic R injected), stand up SE + DualLiquidity stack and sample inventory.

**Goals:**

- Ad diagram: *proceeds → liquidity / product stack*.  
- One successful DualLiquidity deposit path post-bootstrap (reuse v2 lessons; rates-off default).

**Success signals:**

- Documented sequence with addresses in meta.  
- At least one nested volume or BPT mark observation (not a full DualLiquidity research re-run).

### Mode D — Bridge ops (stretch)

**Drive:** Mint/deploy on L1-like env and bridge auctionToken slice to Base testnet/fork if infrastructure allows.

**Goals:**

- Reduce launch-day bridge surprise.  
- Document canonical Superchain steps for ops.

**Not required** for v1 “auction ad ready” gate if Mode A–C complete on Base-native stand-in.

---

## Hypotheses (pre-registered)

| ID | Claim | Primary mode |
|----|--------|--------------|
| **H1** | Fixed-supply auctionToken can be deployed via production-first path and funded into a CCA instance | Mode A |
| **H2** | ≥1 bid + clear + settle is reconstructable from artifacts alone | Mode A |
| **H3** | A public bidder checklist can be written without private keys or undisclosed RPCs | Mode B |
| **H4** | Post-clear pool/settlement state is observable and documentable | Mode A |
| **H5** | Synthetic raise R can bootstrap DualLiquidity (+ SE legs) on Base fork without mocks of SUT vaults | Mode C |
| **H6** (stretch) | Bridge path for CCA tranche is documentable with testnet evidence | Mode D |

---

## Metrics and artifacts

### Meta (every run)

```text
product: ccaRehearsal
scenarioFamily: cca
researchVersion: 1
environment: base_fork | base_sepolia | ...
auctionToken, quoteAsset, cca address
supplyTotal, supplyForAuction, durationParams, curveNote
floorOrStartPrice (label: workshop_placeholder | cca_config)
proceedsRecipient (research)
gitCommit, runId
```

### Series / runbook (minimum)

| Phase | Record |
|-------|--------|
| deploy | token address, supply, owner |
| cca_create | auction id/address, params |
| bid | bidder, amountIn quote, tx/hash or forge log |
| clear | time/block, clearing price fields available on-chain |
| settle | token received, proceeds balance |
| post_pool | pool id/address if any, spot note |
| product_bootstrap (Mode C) | vault addresses, reserve BPT, sample deposit |

### Layout

```text
research/scenarios/cca/
  CCA_Rehearsal_PRD.md                              # this file
  CCA_Rehearsal_IMPLEMENTATION_AND_TEST_PLAN.md     # next
  FINDINGS.md
  AGENT_RESEARCH_REPORT.md
  BIDDER_CHECKLIST.md                               # public-facing draft after Mode B

research/out/cca/rehearsal/
  modeA_auctionMechanics/
  modeB_bidderUx/
  modeC_postClearProduct/
  modeD_bridge/                                     # stretch
  ui/                                               # optional screenshots
```

### Charts (optional)

CCA is ops/UX heavy; plots are secondary. If useful:

- bid cumulative fill vs time (if series exists)  
- Mode C DualLiquidity volume_by_leg one-shot after bootstrap  

Do not invent price charts for mainnet marketing from fork-only data without labeling environment.

---

## Success criteria (v1 research done)

### Structural

- [ ] PRD + implementation plan under `research/scenarios/cca/`  
- [ ] Artifacts only under `research/out/cca/rehearsal/`  
- [ ] No overwrites of SE / DualLiquidity research trees  
- [ ] Runner documented; meta stamped with git commit  

### Empirical

- [ ] Mode A: full auction path H1–H2–H4 supported or honest environment blocker captured  
- [ ] Mode B: `BIDDER_CHECKLIST.md` draft exists  
- [ ] Mode C: H5 supported or blocked with explicit missing dependency list  
- [ ] FINDINGS.md with H1–H5 pass/fail  

### Marketing / launch

- [ ] Claim → evidence map filled (§ below)  
- [ ] `MARKETING_AND_PERFORMANCE_FINDINGS.md` §6 next-campaign + ready claims updated  
- [ ] Launch plan open items that research can feed (floor workshop) listed, not silently “decided”  
- [ ] Agent handoff: do not re-run unless params/environment change  

### Explicit non-goals for “done”

- Live CCA with public capital  
- Frozen FDV / floor as research output  
- `donation` fee-make measured demo  

---

## Marketing claim → evidence map

| Publishable claim (draft language) | Evidence required | When |
|------------------------------------|-------------------|------|
| We can run a Continuous Clearing Auction-style sale for a fixed-supply token on Base | Mode A artifacts | After Mode A |
| Here is how a bidder participates (steps + assets) | `BIDDER_CHECKLIST.md` + Mode B | After Mode B |
| Clearing is transparent / time-distributed (mechanism description + our dry-run) | Mode A clear logs + Uniswap CCA docs cite | After Mode A |
| After the auction we can stand up linked SE + DualLiquidity liquidity infrastructure | Mode C sequence + addresses | After Mode C |
| Protocol product thesis (SE + DualLiquidity volume) | Existing marketing roll-up graphs | **Already available** |
| Fees buy into liquidity via donation | **Not this PRD** — donation campaign | Later |
| Expected raise / FDV / APY | **Never from this research alone** | Workshop + legal |

**Do not publish:** Aztec-comparable raise assumptions; “arb yields for auction buyers”; Bankr as the capital raise; unbridged L1/Base dual RICH confusion.

---

## Dependencies

| Dependency | Status assumption |
|------------|-------------------|
| `docs/LAUNCH_PLAN.md` | Normative product/launch sequence |
| Uniswap CCA contracts + docs on Base | Available mid-2026; implementation plan pins addresses |
| Crane ERC20 Permit DFPkg / CREATE3 | Available |
| DualLiquidity gold TestBase + research fixture | Available for Mode C |
| SE / DualLiquidity marketing findings | Cite; do not re-run |
| Base RPC (`ALCHEMY_KEY` / testnet) | Required for empirical modes |
| `donation` / kill-switch | **Not** required for this PRD’s success; required for fuller launch announce |

---

## Implementation plan

**Normative execution plan:** [`CCA_Rehearsal_IMPLEMENTATION_AND_TEST_PLAN.md`](./CCA_Rehearsal_IMPLEMENTATION_AND_TEST_PLAN.md)

Phases (summary):

0. Pin CCA addresses, interfaces, and environment choice (fork vs testnet)  
1. auctionToken deploy + Mode A mechanics script  
2. Mode B checklist + multi-bidder optional  
3. Mode C synthetic raise → DualLiquidity bootstrap  
4. FINDINGS + agent report + marketing/launch plan cross-links  
5. Stretch: bridge dry-run  

---

## Risks

| Risk | Mitigation |
|------|------------|
| CCA interface / address drift | Pin versions in plan; record chain id + bytecode hash if possible |
| Fork lacks CCA deployment | Fall back to testnet; document blocker honestly |
| Warp vs real 5-day UX | Document both; UI screenshots on testnet if possible |
| Confusing stand-in with mainnet RICH | Role name `auctionToken`; disclaimers on all public drafts |
| Scope creep into donation / Bankr | Hard out-of-scope; separate PRDs |
| Overclaim post-clear TVL | Mode C is sequence proof, not market forecast |
| Parallel agent conflicts | Touch only `research/scenarios/cca/`, `research/out/cca/`, new scripts under `scripts/foundry/research/cca/` |

---

## Related paths

| Path | Role |
|------|------|
| [`docs/LAUNCH_PLAN.md`](../../../docs/LAUNCH_PLAN.md) | CCA-first launch decisions |
| [`research/MARKETING_AND_PERFORMANCE_FINDINGS.md`](../../MARKETING_AND_PERFORMANCE_FINDINGS.md) | Product research roll-up |
| [`research/scenarios/dualLiquidityLinkedCrossVersion/FINDINGS_v2.md`](../dualLiquidityLinkedCrossVersion/FINDINGS_v2.md) | DualLiquidity volume evidence to cite under ads |
| [`research/scenarios/uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md`](../uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md) | Fee-threshold / SE arb theory |
| Uniswap CCA docs | Mechanism source of truth for public “how CCA works” copy |

---

## Acceptance of this PRD

This PRD is **accepted for implementation planning** when:

1. Product owner agrees Mode A → B → C priority (D stretch).  
2. Research uses **stand-in `auctionToken`**, not mainnet RICH capital.  
3. Floor/FDV remain **workshop parameters**, not research “results.”  
4. Success does **not** require live public auction or `donation` implementation.  

---

*Next action: execute Phase 0 of [`CCA_Rehearsal_IMPLEMENTATION_AND_TEST_PLAN.md`](./CCA_Rehearsal_IMPLEMENTATION_AND_TEST_PLAN.md) (pin Base CCA addresses + interface smoke).*
