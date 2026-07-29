# CCA Rehearsal — Implementation and Execution Plan

## Purpose

Execute the [CCA Rehearsal PRD](./CCA_Rehearsal_PRD.md): ship a **reconstructable dry-run** of Uniswap Continuous Clearing Auction mechanics (Base fork and/or testnet), a public **bidder checklist**, and a **post-clear DualLiquidity + SE bootstrap** playbook sized from a **synthetic** ETH raise — so auction advertising can cite evidence without live mainnet capital.

## Status

**PLANNED** — ready for execution after PRD acceptance.

### Locked decisions (summary)

| Topic | Decision |
|-------|----------|
| Normative PRD | [`CCA_Rehearsal_PRD.md`](./CCA_Rehearsal_PRD.md) |
| Launch context | [`docs/LAUNCH_PLAN.md`](../../../docs/LAUNCH_PLAN.md) — CCA first, RICHAI after clear |
| Quote asset | **ETH / WETH** |
| Venue | **Base** (prefer mainnet **fork** first; testnet for UI) |
| Token under sale | Research role **`auctionToken`** — fixed-supply stand-in (not mainnet RICH capital) |
| Auction supply shape | Default **10%** of stand-in total supply (mirror launch 100M/1B) |
| Duration / curve | Prefer **~5 days**, **back-loaded** when config allows; `vm.warp` on fork |
| Floor / start price | Launch floor **locked** in [`docs/CCA_FDV_WORKSHOP.md`](../../../docs/CCA_FDV_WORKSHOP.md): **\(5\times10^{-7}\) ETH/RICH** (~$950k FDV at floor). Research may still label stand-in runs `workshop`/`launch_floor` in meta — do not invent a different public FDV |
| Mode order | **A → B → C**; **D** stretch |
| DualLiquidity in Mode C | Rates-**off** default; reuse existing fixture patterns; thin sample only |
| Out root | `research/out/cca/rehearsal/` only |
| Isolation | Do not overwrite SE / DualLiquidity research trees |
| Profile | Scripts: `FOUNDRY_PROFILE=default`; fork tests: `fork` if needed |
| Live capital | **Out of scope** |

---

## 1. Goals and non-goals

### Goals

1. Pin Uniswap CCA factory / entrypoint addresses and interfaces for Base.  
2. Deploy fixed-supply `auctionToken` via production-first path (Crane ERC20 Permit DFPkg preferred).  
3. Mode A: create CCA → fund supply → bid → warp/clear → settle → record artifacts.  
4. Mode B: `BIDDER_CHECKLIST.md` (script + UI notes + failure modes).  
5. Mode C: synthetic raise **R** → SE legs + DualLiquidity bootstrap + one inventory sample.  
6. FINDINGS + agent report + marketing roll-up / launch-plan cross-links.  
7. Runner: `research/run_cca_rehearsal.sh`.

### Non-goals

- Mainnet RICH mint, bridge of real 100M, or public CCA.  
- Implementing DualLiquidity `donation` / fee-collector routing.  
- Kill-switch implementation.  
- RICHAI Bankr rehearsal.  
- Re-running DualLiquidity residual / rateProviderCompare matrices.  
- Predicting raise size or secondary market performance.

---

## 2. Naming and layout

### Source (new only)

```text
scripts/foundry/research/cca/
  ResearchFixture_CcaRehearsal.sol          # bootstrap: token + CCA helpers + telemetry
  Script_ModeA_AuctionMechanics.s.sol
  Script_ModeB_BidderMulti.s.sol            # optional second bidder
  Script_ModeC_PostClearProduct.s.sol       # synthetic R → DualLiquidity
  # stretch:
  Script_ModeD_BridgeNotes.s.sol            # or docs-only if no safe dry-run
research/run_cca_rehearsal.sh
```

### Tracked narrative

```text
research/scenarios/cca/
  CCA_Rehearsal_PRD.md
  CCA_Rehearsal_IMPLEMENTATION_AND_TEST_PLAN.md   # this file
  FINDINGS.md                                       # after runs
  AGENT_RESEARCH_REPORT.md
  BIDDER_CHECKLIST.md                               # after Mode B
```

### Artifacts (gitignored under `research/out/`)

```text
research/out/cca/rehearsal/
  modeA_auctionMechanics/
    meta.json
    runbook.jsonl          # or series.jsonl
    NOTES.md               # human summary for that run
  modeB_bidderUx/
  modeC_postClearProduct/
  modeD_bridge/            # stretch
  ui/                      # optional screenshots
```

### Inheritance / composition sketch

```text
CraneTest / InitDevService (CREATE3)
        │
        ├─ auctionToken via ERC20 Permit DFPkg (or gold Permit path)
        │
ResearchFixture_CcaRehearsal
        ├─ deployAuctionToken(supply)
        ├─ createAndFundCca(params)
        ├─ bid(bidder, amountQuote)
        ├─ warpToClear() / settle()
        ├─ recordPhase(...)
        └─ (Mode C) compose DualLiquidity research fixture OR thin bootstrap helpers
```

**Anti-pattern:** `new` facets/DFPkgs outside factory path for IndexedEx vaults.  
**CCA contracts:** call **live** Uniswap CCA deployments on fork (or documented testnet addresses) — not mocked CCA SUT.

---

## 3. Environment and address pinning (Phase 0 gate)

### 3.1 Environment ladder

| Priority | Environment | Use for |
|----------|-------------|---------|
| **1** | Base mainnet **fork** (`base_mainnet_alchemy`) | Mode A mechanics, Mode C product bootstrap |
| **2** | Base **Sepolia** (or current Uniswap CCA testnet) | Mode B UI checklist, optional full public dry-run |
| **3** | Hermetic CCA port | Only if fork/testnet CCA unavailable — document as degraded |

### 3.2 External references (pin at execution time)

Record in Mode A `meta.json` and FINDINGS:

| Resource | URL / note |
|----------|------------|
| CCA concepts | https://developers.uniswap.org/docs/liquidity/liquidity-launchpad/concepts/cca |
| CCA contracts repo | https://github.com/Uniswap/continuous-clearing-auction |
| Technical reference | repo `docs/TechnicalDocumentation.md` |
| Deployment table | repo README / releases (e.g. v2.1.0 factory class addresses — **verify per chain**) |
| Product site | https://cca.uniswap.org/ |
| Launch plan | `docs/LAUNCH_PLAN.md` |

**Phase 0 deliverable:** a short `research/scenarios/cca/ADDRESSES.md` (or section in FINDINGS) with:

```text
chainId: 8453 (or testnet)
ccaFactoryOrEntrypoint: 0x...
blockPinned (if fork): N
uniswapV4PoolManager (if needed for post-seed): 0x...
sourceCommitOrVersion: ...
verifiedAtUtc: ...
```

If addresses cannot be verified, **stop** and record blocker — do not invent.

### 3.3 Default research parameters (overridable in meta)

| Param | Default | Notes |
|-------|---------|-------|
| `supplyTotal` | `1_000_000_000e18` | Mirror RICH 1B |
| `supplyForAuction` | `100_000_000e18` | 10% |
| `quoteAsset` | ETH/WETH | As CCA requires |
| `duration` | ~5 days in seconds | Warp on fork |
| `curve` | back-loaded if API allows | Else document closest supported |
| `floorOrStartPrice` | `5e-7` ETH per token | Launch lock; meta may label `launch_floor_2026-07-22` |
| `syntheticRaiseR` (Mode C) | e.g. `100 ether` research default | Not a forecast |
| DualLiquidity rates | `useRateProviders: false` | Product default |

---

## 4. Telemetry schema

### 4.1 `meta.json` (required fields)

```json
{
  "product": "ccaRehearsal",
  "scenarioFamily": "cca",
  "researchVersion": 1,
  "mode": "A_auctionMechanics",
  "environment": "base_fork",
  "chainId": 8453,
  "auctionToken": "0x...",
  "quoteAsset": "ETH",
  "cca": "0x...",
  "supplyTotal": "...",
  "supplyForAuction": "...",
  "durationSeconds": 0,
  "curveNote": "back-loaded|...",
  "floorOrStartPrice": "...",
  "floorLabel": "workshop_placeholder",
  "proceedsRecipient": "0x...",
  "runId": "modeA_auctionMechanics",
  "ccaVersionOrCommit": "...",
  "gitCommit": "stamp"
}
```

### 4.2 `runbook.jsonl` (one object per phase)

```text
phase, t, block, action, txOrNote, amountQuote, amountToken, priceField, balances..., ok, error
```

Phases: `deploy_token`, `cca_create`, `cca_fund`, `bid`, `warp`, `clear`, `settle`, `post_pool`, `product_bootstrap`, `product_sample`.

Reuse `ResearchTelemetry` if convenient; otherwise simple `vm.writeLine` JSONL is fine.

---

## 5. Phases

### Phase 0 — Pin CCA surface (½–1 day)

1. Read Uniswap CCA technical docs + Base deployment addresses; write `ADDRESSES.md`.  
2. Import or generate minimal interfaces for create/fund/bid/claim/settle used by scripts.  
3. Smoke: `cast call` / tiny forge script that **reads** factory code on fork (non-empty bytecode).  
4. Decide Mode A path: **scripted only** first; UI later in Mode B.

**Exit:** verified addresses + interface stubs compile.

**Blocker handling:** if Base fork has no CCA, switch primary to testnet and document; Mode C may still run DualLiquidity on Base fork independently with synthetic R.

---

### Phase 1 — Mode A auction mechanics (**primary**)

1. Implement `ResearchFixture_CcaRehearsal` + `Script_ModeA_AuctionMechanics.s.sol`.  
2. Deploy `auctionToken` (fixed supply).  
3. Create CCA with research params; fund `supplyForAuction`.  
4. Fund `researchBidder` with quote; approve/bid.  
5. `vm.warp` through auction window; clear/settle per CCA API.  
6. Write `research/out/cca/rehearsal/modeA_auctionMechanics/{meta.json,runbook.jsonl,NOTES.md}`.  
7. Record H1, H2, H4 pass/fail.

**Exit:** one green Mode A path **or** honest environment failure with logs in `NOTES.md`.

**Suggested forge invocation:**

```bash
FOUNDRY_PROFILE=default forge script \
  scripts/foundry/research/cca/Script_ModeA_AuctionMechanics.s.sol:Script_ModeA_AuctionMechanics \
  -vv --fork-url base_mainnet_alchemy
```

---

### Phase 2 — Mode B bidder UX

1. Expand NOTES into public draft `BIDDER_CHECKLIST.md`:  
   - Prerequisites (wallet, ETH on Base, chain id)  
   - Script path (research) vs Uniswap Web App path (when available)  
   - Approvals, bid, claim  
   - Failure modes table  
2. Optional: second bidder script (`Script_ModeB_BidderMulti`).  
3. Optional: store UI screenshots under `out/cca/rehearsal/ui/` (manual).  
4. H3 pass when checklist is reviewable without private secrets.

**Exit:** `BIDDER_CHECKLIST.md` merged under `research/scenarios/cca/`.

---

### Phase 3 — Mode C post-clear product bootstrap

1. `Script_ModeC_PostClearProduct.s.sol`:  
   - Inject synthetic **R** ETH (research funded account).  
   - Deploy DualLiquidity stack via existing gold TestBase / research fixture patterns (rates-off).  
   - Map roles in meta (e.g. commonToken↔WETH stand-in, tokenA↔auctionToken, tokenB↔second stand-in — **document mapping**; launch plan day-1 is WETH+RICH+RICHAI).  
   - Bootstrap reserve + one `deposit_common` or linked deposit.  
   - Sample DualLiquidity v2-style volume fields once (BPT + SE live) if cheap.  
2. Artifacts under `modeC_postClearProduct/`.  
3. Write ASCII diagram for ads: `CCA proceeds → SE legs → DualLiquidity`.

**Exit:** H5 pass/fail; sequence copyable by ops without re-deriving.

**Do not:** full DualLiquidity Mode A residual matrix; Mode C arb closer.

---

### Phase 4 — Narrative + roll-up

1. `FINDINGS.md` — H1–H5, environment, addresses, claim map.  
2. `AGENT_RESEARCH_REPORT.md` — do-not-re-run, paths, ad-safe claims.  
3. Update:  
   - `research/MARKETING_AND_PERFORMANCE_FINDINGS.md` (§5 ready claims, §6 status, changelog)  
   - `research/SCENARIO_LOG.md`  
   - `research/README.md`  
   - `docs/LAUNCH_PLAN.md` (pointer to FINDINGS; floor workshop still open)  
4. Stamp meta with `gitCommit`.

**Exit:** v1 marked complete without live CCA capital.

---

### Phase 5 — Stretch only

| Trigger | Action |
|---------|--------|
| Bridge ops risk high | Mode D Superchain dry-run or ops-only doc |
| UI gaps | Base Sepolia + Uniswap App screenshots |
| Multi-bidder needed for ads | Mode B multi script |

---

## 6. Runner sketch

```bash
# research/run_cca_rehearsal.sh
# Usage:
#   ./research/run_cca_rehearsal.sh              # Mode A then C (data)
#   ./research/run_cca_rehearsal.sh --mode-a-only
#   ./research/run_cca_rehearsal.sh --mode-c-only
#   ./research/run_cca_rehearsal.sh --checklist-only  # no forge; regenerate checklist stub
FOUNDRY_PROFILE=default
# requires ALCHEMY_KEY / base_mainnet_alchemy for fork modes
```

Order default: Mode A → Mode C → stamp. Mode B is mostly documentation (may not need forge).

Do **not** gate on full monorepo `forge test`.

---

## 7. Testing strategy

| Layer | What |
|-------|------|
| **Research scripts** | Primary proof (Mode A/C) — production CCA + production DualLiquidity paths |
| **Unit/interface** | Compile-time interfaces; optional pure param validation helpers |
| **Fork tests** | Optional thin test wrapping Mode A if stable; prefer scripts for long warps |
| **No mocks of** | CCA protocol, DualLiquidity DFPkg, SE vaults, manager/registry under Mode C |

Production-first rules from AGENTS.md / indexedex-testing apply to Mode C.

---

## 8. Verification checklist

### Structural

- [ ] Scripts only under `scripts/foundry/research/cca/`  
- [ ] Artifacts only under `research/out/cca/rehearsal/`  
- [ ] SE / DualLiquidity `out/` trees untouched  
- [ ] `ADDRESSES.md` or FINDINGS address section filled  

### Empirical

- [ ] Mode A runbook reconstructs bid→clear→settle  
- [ ] Mode B checklist exists  
- [ ] Mode C bootstrap addresses + one product sample  
- [ ] H1–H5 recorded  

### Marketing

- [ ] Auction-ready claims listed with evidence paths  
- [ ] Explicit non-claims: raise size, FDV, APY, Aztec comps  
- [ ] Roll-up §6 marks CCA Rehearsal complete or blocked  

---

## 9. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| CCA API complexity / version skew | Phase 0 pin version; thin interface surface |
| Warp hides real UX friction | Mode B UI notes + optional testnet |
| DualLiquidity Mode C stack-too-deep / fork time | Reuse DualLiquidity research fixture; single deposit sample |
| Stand-in confused with RICH | Role names + disclaimers on every public draft |
| Scope creep to donation | Refuse; open sibling PRD |
| Secret keys in checklist | Checklist uses placeholders only |

---

## 10. Execution order (checklist)

0. [ ] Phase 0 address pin + interface smoke  
1. [ ] Phase 1 Mode A mechanics  
2. [ ] Phase 2 BIDDER_CHECKLIST  
3. [ ] Phase 3 Mode C product bootstrap  
4. [ ] Phase 4 FINDINGS + roll-up  
5. [ ] Phase 5 stretch only if needed  

---

## 11. Ad copy inputs (fill after FINDINGS)

After v1 complete, marketing can draft (examples — **not** final):

| Message | Source |
|---------|--------|
| How CCA works + how to bid | BIDDER_CHECKLIST + Uniswap CCA docs |
| We dry-ran create/fund/bid/settle on Base fork/testnet | Mode A NOTES |
| After clear we stand up linked Uni SE + DualLiquidity infrastructure | Mode C diagram |
| Why the product exists (SE re-mark, DualLiquidity volume) | Existing marketing roll-up graphs |

Still blocked until other campaigns: fee-make donation demo; kill-switch; live CCA dates.

---

## Related

| Doc | Role |
|-----|------|
| [PRD](./CCA_Rehearsal_PRD.md) | Normative questions / success |
| [Launch plan](../../../docs/LAUNCH_PLAN.md) | CCA-first product decisions |
| [DualLiquidity FINDINGS_v2](../dualLiquidityLinkedCrossVersion/FINDINGS_v2.md) | Nested volume evidence to cite under ads |
| [Marketing roll-up](../../MARKETING_AND_PERFORMANCE_FINDINGS.md) | Campaign index |

---

*Ready to implement when PRD accepted. First code touch: Phase 0 `ADDRESSES.md` + CCA interface pin + Mode A fixture skeleton.*
