# Implementation & Test Plan: Unified DETF deprecation test coverage

**PRD (product law SoT):** [`UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_PRD.md`](./UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_PRD.md) (**§0 R-1..R-24** and **§7.0** win on IDs, ABI, layers)  
**This plan (implementor SoT):** `/goal` kickoff, DAG, worktree names, child prompts, file maps, forge match-paths, DoD. **No product choices.**  
**Date:** 2026-08-28  
**Status:** READY FOR EXECUTION (goal-command agent)  
**Worktree prefix:** `unified_detf_pl_`  
**Max concurrent implementers:** 3

| Layer | Role |
|-------|------|
| **PRD §0 / §7.0 / §5–§8** | Product law, ID × layer matrix, file names, ABI substitutes. Wins on any conflict with this plan |
| **This plan** | Orchestrator: `/goal` text, DAG waves, child `/goal` blocks, forge DoD |
| **CLAUDE.md / INDEXEDEX_AGENT_LAW** | Crane first; never `new` DFPkgs; DETF role names; no `via_ir`; production-first; forge patience; worktree seed |
| **Skills** | `crane-testing`, `indexedex-testing`, `indexedex-adversarial-testing`, `crane-adversarial-testing`, `crane-deployment`, `indexedex-uniswap-v4-hook-packages`, `indexedex-launch-scripts` |

**Process:** If this plan and the PRD disagree on IDs, ABI, or layers, **PRD wins** and this plan must be patched before coding continues. If a test name, layer, file stem, or ABI substitute is in neither, **STOP and ask**. Do not invent.

**Role names only:** `rateAsset`, `pairToken`, `standardExchangeVault`, `vaultShare`, `detfToken`, `reservePool` / `reserveHook`, `rebasingClaimToken`.

---

## Launch (paste into `/goal`)

```text
/goal Implement unified DETF deprecation test coverage from the locked PRD and this plan. No product choices. No half measures.

LAW (read fully before coding):
- contracts/vaults/detf/UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_PRD.md
  (§0 R-1..R-24 and §7.0 win on IDs, ABI, layers)
- contracts/vaults/detf/UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_IMPLEMENTATION_AND_TEST_PLAN.md (this file)
- Claude.md + docs/agent/INDEXEDEX_AGENT_LAW.md
- skills: crane-testing, indexedex-testing, indexedex-adversarial-testing,
  crane-adversarial-testing, crane-deployment, indexedex-uniswap-v4-hook-packages,
  indexedex-launch-scripts

YOU ARE THE ORCHESTRATOR. Execute WPs in DAG order. Max 3 concurrent implementers.
For each WP, either (a) implement it yourself from that WP section as sole scope, or
(b) spawn one subagent whose entire prompt is the matching “WP /goal” block in this plan.
Do not give a child the PRD alone. Do not let a child edit another WP’s files.
Do not split a WP across two agents.

START at wave 1 (IO + POLICY + DONATE). Do not start a WP whose Depends on WPs are not green.

DAG:
Wave 1 (parallel, max 3): WP-UDPL-IO | WP-UDPL-POLICY | WP-UDPL-DONATE
Wave 2 (parallel after deps): WP-UDPL-CLAIM (POLICY) | WP-UDPL-D25 (POLICY) | WP-UDPL-ADV (IO)
Wave 3 (after POLICY+D25+CLAIM+DONATE+ADV CP green): WP-UDPL-OR | WP-UDPL-WE | WP-UDPL-QD
Wave 4 (after OR+WE+QD gold green): WP-UDPL-SE-CP | WP-UDPL-SE-OR | WP-UDPL-SE-WE
         then WP-UDPL-SE-QD
Wave 5: WP-UDPL-DEPRECATE (all test WPs green)

SUT is UniswapV4DetfDFPkg only. Unified ABI is the standard.
Copy behavioral asserts from family standardExchange/** DETF tests.
Do not inherit those TestBases. Do not put sell/buyClaim/redeemClaim on IUniswapV4Detf.
Sell = Bond NFT. Redeem = RebasingClaimToken (pays DETF).

DO:
- Follow each WP file map and forge --match-path.
- Seed cache_forge/ + out/ if this is a new worktree (Claude.md worktree seed).
  After a green forge, copy them back to the warm seed.
- Wait for forge/solc exit. First compile 20-40+ minutes is normal. Timeout 2-4 hours.
  Never kill forge.
- Default hermetic profile only. No package-specific Foundry profile. via_ir forbidden.
- CREATE3 facets; vault/DETF DFPkgs via indexedexManager / registry. PkgInit/PkgArgs on the interface.
- Prefer --match-contract per WP file. Do not treat colliding extras as this change.
- On WP DONE: WP matcher green AND the three regression matchers:
  prod-se/**, pons/**, UniswapV4Detf_*.t.sol

DO NOT:
- Re-litigate PRD §0 / §7.0 (layers, D15 names, DN15 N/A, D18, E6 N/A, sibling files, H-CP-P2 pons TestBase).
- Restore family DETF function names onto IUniswapV4Detf.
- Edit TestBase_UniswapV4Detf.sol. Add §7 tests into existing Stage 11 firstBond files.
- Create TestBase_UniswapV4Detf_Cp_PonsV2Se.sol.
- Bind Dual as PkgArgs.hook. Touch Balancer DETFs. Touch frontend/**.
- new facets/DFPkgs. SUT mocks. via_ir. FoT success path.
- Patch production CODE on a red §7 test. Critical flaw: stop the WP, report §7 ID + matcher + selector + short trace, wait for go-ahead.
- Run the whole monorepo suite “to be safe.”
- Start DEPRECATE before every test WP is green.

DONE when every WP in this plan §8 is green, including WP-UDPL-DEPRECATE, and this plan §7 checkboxes pass.
```

---

## WP `/goal` blocks (paste one to a child agent)

Use the orchestrator block above for a new top-level agent. Use **one** block below for a worktree-isolated child.

Shared footer (append mentally to every child; already inlined in each block): seed `cache_forge/` + `out/` if new worktree; never kill forge; `via_ir` forbidden; no `new` DFPkgs; no SUT mocks; PRD §0 / §7.0 win; critical flaw = stop and report.

### WP-UDPL-IO

```text
/goal Execute WP-UDPL-IO from contracts/vaults/detf/UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_IMPLEMENTATION_AND_TEST_PLAN.md only.

Read that WP section, then PRD §0, §7.0, §7.1, §7.7, §8. Worktree unified_detf_pl_io.
SUT UniswapV4DetfDFPkg. Ship IoTables gold+Open abstracts AND CP concretes (not abstracts-only). CP T7.11 must call closeBondMature. CP owner-only. No Stage 11 siblings. No TestBase_UniswapV4Detf.sol edits.
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_IoTables.t.sol'
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_OwnerOnlyLiquidity.t.sol'
Then regression: prod-se/**, pons/**, UniswapV4Detf_*.t.sol
```

### WP-UDPL-POLICY

```text
/goal Execute WP-UDPL-POLICY from contracts/vaults/detf/UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_IMPLEMENTATION_AND_TEST_PLAN.md only.

Read that WP section, then PRD §0, §5.1, §7.0, §7.2, §8. Worktree unified_detf_pl_policy.
Create TestBase_UniswapV4Detf_Policy.sol with virtual _policyArgs(). Do not edit TestBase_UniswapV4Detf.sol.
CP gold Policy/D31/compound/opening. Fee oracle p=5e16 f=12e16 c=28e16. Launch-rich opening 1.1e18 then +0.05e18 max 24 steps. Do not prank(detf) to LP before first bond. lpOut==0 on compound is success when lazy path already consumed pending.
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Policy.t.sol'
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_OpeningPrice.t.sol'
Then regression: prod-se/**, pons/**, UniswapV4Detf_*.t.sol
```

### WP-UDPL-DONATE

```text
/goal Execute WP-UDPL-DONATE from contracts/vaults/detf/UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_IMPLEMENTATION_AND_TEST_PLAN.md only.

Read that WP section, then PRD §0 R-3, §7.0, §7.5, §8. Worktree unified_detf_pl_donate.
CP gold donation R12a. O>0 unassigned LP, convertToAssets rises. DN3 N/A NatSpec. DN15 N/A NatSpec. Include DN21 and DN22. Keep DN19/DN20. Do not restore family N10 convertToAssets stasis. Do not steal hook LP.
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_ReserveDonation.t.sol'
Then regression: prod-se/**, pons/**, UniswapV4Detf_*.t.sol
```

### WP-UDPL-CLAIM

```text
/goal Execute WP-UDPL-CLAIM from contracts/vaults/detf/UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_IMPLEMENTATION_AND_TEST_PLAN.md only.

Depends on WP-UDPL-POLICY green. Read that WP section, then PRD §0 R-2 R-8 R-9 R-16 R-21 R-22, §6, §7.0, §7.3, §8. Worktree unified_detf_pl_claim.
CP gold claim/D15/D28 via Bond NFT + IRebasingClaimToken. D15-1..4 and D15-6..9. D15-5 N/A NatSpec on CP. previewRedeem must equal redeem. D18 not tested. FC4 = later bond not buyClaim. FC names test_FC1_univ4Detf_cp_.... D22 on Policy instance only.
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Claim.t.sol'
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_RedeemD15.t.sol'
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_FeeCreatorClaim.t.sol'
Then regression: prod-se/**, pons/**, UniswapV4Detf_*.t.sol
```

### WP-UDPL-D25

```text
/goal Execute WP-UDPL-D25 from contracts/vaults/detf/UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_IMPLEMENTATION_AND_TEST_PLAN.md only.

Depends on WP-UDPL-POLICY green. Read that WP section, then PRD §7.0, §7.4, §8. Worktree unified_detf_pl_d25.
CP gold D25-1..7 plus lastClose fee/creator pending. Close pays user DETF only via claimRewards; withdrawn DETF rejoined to id 0. Existing UniswapV4Detf_Close.t.sol T7.12 stays; it does not replace D25.
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_CloseD25.t.sol'
Then regression: prod-se/**, pons/**, UniswapV4Detf_*.t.sol
```

### WP-UDPL-ADV

```text
/goal Execute WP-UDPL-ADV from contracts/vaults/detf/UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_IMPLEMENTATION_AND_TEST_PLAN.md only.

Depends on WP-UDPL-IO green. Read that WP section, then PRD §0 R-10 R-11 R-15 R-20, §7.0, §7.6, §8. Worktree unified_detf_pl_adv.
CP gold adversarial. Create TestBase_UniswapV4Detf_Adversarial.sol. I1/I2/I3, A0, CROPS, J1-J3, K1=test_K1_donationNotMintCredit, F1=test_F1_satellitesUnowned, nested T-NEST-1..3 + T-LOCAL-I1 only (defer 4..8 NatSpec). E6 N/A NatSpec. L2 FoT is T7.15 on IO, not a second suite. Reentrancy IsLocked on mint; burn/bond only if family CP reentrancy already has those tests.
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/adversarial/**'
Then regression: prod-se/**, pons/**, UniswapV4Detf_*.t.sol
```

### WP-UDPL-OR

```text
/goal Execute WP-UDPL-OR from contracts/vaults/detf/UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_IMPLEMENTATION_AND_TEST_PLAN.md only.

Depends on POLICY+D25+CLAIM+DONATE+ADV CP green. Read that WP section, then PRD §7.0 gold Orbital row, §8. Worktree unified_detf_pl_or.
Orbital gold concretes only (inherit CP abstracts). Full gold §7 except T7.15 FoT and T7.11. D15-5 required. FC names test_FC*_univ4Detf_orbital_.... No Stage 11 siblings. No custom close execute.
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Orbital*.t.sol'
Then regression: prod-se/**, pons/**, UniswapV4Detf_*.t.sol
```

### WP-UDPL-WE

```text
/goal Execute WP-UDPL-WE from contracts/vaults/detf/UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_IMPLEMENTATION_AND_TEST_PLAN.md only.

Depends on POLICY+D25+CLAIM+DONATE+ADV CP green. Read that WP section, then PRD §7.0 gold Weighted row, R-13, §8. Worktree unified_detf_pl_we.
Weighted gold concretes only. Full gold §7 except T7.15 and T7.11. T6 opening length. T8.4 Policy instance via real reserve skew/donate, not Custom mint table. D15-5 required. FC names test_FC*_univ4Detf_weighted_....
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Weighted*.t.sol'
Then regression: prod-se/**, pons/**, UniswapV4Detf_*.t.sol
```

### WP-UDPL-QD

```text
/goal Execute WP-UDPL-QD from contracts/vaults/detf/UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_IMPLEMENTATION_AND_TEST_PLAN.md only.

Depends on POLICY+D25+CLAIM+DONATE+ADV CP green. Read that WP section, then PRD §7.0 gold Quad row, R-12, §8. Worktree unified_detf_pl_qd.
Quad gold concretes only. Full gold §7 except T7.15. Edit UniswapV4Detf_Quad.t.sol T8.3 to call closeBondMature (leftover ownerSwapExactIn; user receives close-route pair; DETF slot 0). T6 opening length. D15-5 required. FC names test_FC*_univ4Detf_quad_....
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Quad*.t.sol'
Then regression: prod-se/**, pons/**, UniswapV4Detf_*.t.sol
```

### WP-UDPL-SE-CP

```text
/goal Execute WP-UDPL-SE-CP from contracts/vaults/detf/UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_IMPLEMENTATION_AND_TEST_PLAN.md only.

Depends on OR+WE+QD gold green. Read that WP section, then PRD §0 R-4 R-5, §5.2, §7.0 Open/Policy, §7.8, §8.3. Worktree unified_detf_pl_se_cp.
Siblings *_ProductLaw.t.sol and *_Policy.t.sol for H-CP-GV3, H-CP-GV4, H-CP-P1, H-CP-MB (prod-se/) and H-CP-P2 (pons/). Never edit existing firstBond/mint/burn/close contracts. Inherit Open/Policy layer abstracts, not gold-full abstracts.
H-CP-P2: fix contracts/test/bases/TestBase_UniswapV4Detf_PonsV2Se.sol pair and mintToken to pons v2 launch token; keep T10.8-T10.10 and H-CP-P2 four paths green. Do not create TestBase_UniswapV4Detf_Cp_PonsV2Se.
Anti-theater: allowance(hook, se)==0 before burn, close, I1 mint that pulls shares. compound lpOut==0 is OK when lazy mint/bond already compounded.
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Cp_*'
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/**'
Then regression: prod-se/**, pons/**, UniswapV4Detf_*.t.sol
```

### WP-UDPL-SE-OR

```text
/goal Execute WP-UDPL-SE-OR from contracts/vaults/detf/UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_IMPLEMENTATION_AND_TEST_PLAN.md only.

Depends on OR+WE+QD gold green. Read that WP section, then PRD §5.2, §7.0, §8.3. Worktree unified_detf_pl_se_or.
ProductLaw + Policy siblings for H-OR-* and M-OR-*. Never edit existing firstBond files. Open/Policy layer abstracts only. Nested T-NEST against that fixture’s bound SE. T8.4 is Weighted only; skip on Orbital. T6 skip on Orbital.
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Orbital_*'
Then regression: prod-se/**, pons/**, UniswapV4Detf_*.t.sol
```

### WP-UDPL-SE-WE

```text
/goal Execute WP-UDPL-SE-WE from contracts/vaults/detf/UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_IMPLEMENTATION_AND_TEST_PLAN.md only.

Depends on OR+WE+QD gold green. Read that WP section, then PRD §5.2, §7.0, R-13, §8.3. Worktree unified_detf_pl_se_we.
ProductLaw + Policy siblings for H-WE-* and M-WE-*. T8.4 on every Weighted Policy sibling via real reserve skew/donate. T6 on Weighted Policy siblings.
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Weighted_*'
Then regression: prod-se/**, pons/**, UniswapV4Detf_*.t.sol
```

### WP-UDPL-SE-QD

```text
/goal Execute WP-UDPL-SE-QD from contracts/vaults/detf/UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_IMPLEMENTATION_AND_TEST_PLAN.md only.

Depends on OR+WE+QD gold green. Read that WP section, then PRD §5.2, §7.0, §8.3. Worktree unified_detf_pl_se_qd.
ProductLaw + Policy siblings for H-QD-* and M-QD-*. T6 on Quad Policy siblings. Do not add T8.3 custom close execute on Stage 11. Do not add T8.4 (Weighted only).
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Quad_*'
Then regression: prod-se/**, pons/**, UniswapV4Detf_*.t.sol
```

### WP-UDPL-DEPRECATE

```text
/goal Execute WP-UDPL-DEPRECATE from contracts/vaults/detf/UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_IMPLEMENTATION_AND_TEST_PLAN.md only.

Depends on ALL test WPs green (IO POLICY DONATE CLAIM D25 ADV OR WE QD SE-CP SE-OR SE-WE SE-QD). Read PRD §11. Worktree unified_detf_pl_deprec.
Retarget testnet + fee_detf 08-13 + WireLib + ProtocolDetfInstanceLib to UniswapV4DetfDFPkg / IUniswapV4Detf.
Then delete family Uni V4 DETF packages, leftover common/nft and rebasing, SAF/fork/research that import family DETF TestBases.
Do not delete hooks, SE packages, detf/common/**, Balancer DETFs, Stage 11 prod-se files, or the pons H-CP-P2 TestBase.
Banner family co-located PRDs superseded. Point agent-law / nav / inventory at unified detf/. Add PROGRAM Stage 12 pointer if not already present.
```

---

## 0. Starting state

| Item | Status |
|------|--------|
| Unified `UniswapV4DetfDFPkg` | Exists. Robinhood main Stage 07 deploys it |
| Stage 11 26×4 firstBond/mint/burn/close | Green. Keep those files. Not this program’s acceptance |
| Gold ERC-4626 T7.1 Dual/custom-close-length, T7.5, T7.6, T7.9, T7.12, T7.13, T7.19, T7.20 | Exist. Keep. Do not delete |
| `UniswapV4Detf_Quad.t.sol` T8.3 | Table-only. QD must execute `closeBondMature` |
| H-CP-P2 pons TestBase | Pair is WETH. SE-CP must retarget to launch token |
| Product-law suites on unified (Policy, D15, D25, DN, FC, adversarial) | **Do not exist** on `UniswapV4DetfDFPkg` |
| Family hook-specific Uni V4 DETF packages | Still in-tree. Delete only in DEPRECATE |
| `TestBase_UniswapV4Detf_Policy.sol` / `_Adversarial.sol` | **Do not exist** |

---

## 1. Goals / non-goals

### Goals

1. Gold CP pathfinder of PRD §7, then Orbital/Weighted/Quad gold concretes.
2. Same Open + Policy ID sets on every Stage 11 fixture via siblings (PRD §7.0).
3. H-CP-P2 launch-token pair fix on the existing pons TestBase.
4. After tests green: retarget launch scripts, then delete family Uni V4 DETF diamonds and leftover NFT/claim packages.

### Non-goals

Balancer DETFs; Dual as `PkgArgs.hook`; Morpho-loop / Vault V2 DETF; native ETH quote; FoT success; fork 4663; fuzz/invariant handlers; restoring family DETF ABI; D18 tests; E6 refund path; T-NEST-4..8; editing `TestBase_UniswapV4Detf.sol`; adding §7 tests into existing Stage 11 firstBond files; `via_ir`; SUT mocks; frontend.

---

## 2. Worktree + forge (every WP)

New or empty worktree, **before first forge**:

```bash
# REPO = warm checkout; WT = this worktree
rsync -a "${REPO}/cache_forge/" "${WT}/cache_forge/"
rsync -a "${REPO}/out/" "${WT}/out/"
rm -rf "${WT}/lib/crane" && ln -s "${REPO}/lib/crane" "${WT}/lib/crane"
```

After a **green** forge, copy `cache_forge/` + `out/` back to the warm seed.

Timeout 2–4 hours for first compile. Never kill `forge` / `solc`. Default hermetic profile only. WP `--match-path` / `--match-contract` only.

`--offline` on the matchers in this plan. Do not add `FOUNDRY_PROFILE=fork`.

---

## 3. DAG (mandatory)

```text
Wave 1 (parallel, max 3)
  WP-UDPL-IO
  WP-UDPL-POLICY
  WP-UDPL-DONATE

Wave 2 (parallel after deps)
  WP-UDPL-CLAIM   (after POLICY)
  WP-UDPL-D25     (after POLICY)
  WP-UDPL-ADV     (after IO)

Wave 3 (after POLICY + D25 + CLAIM + DONATE + ADV CP green)
  WP-UDPL-OR
  WP-UDPL-WE
  WP-UDPL-QD

Wave 4 (after OR + WE + QD gold green)
  WP-UDPL-SE-CP
  WP-UDPL-SE-OR
  WP-UDPL-SE-WE
  then WP-UDPL-SE-QD

Wave 5
  WP-UDPL-DEPRECATE  (all test WPs green)
```

Hard rules:

- Max 3 live implementers.
- Do not start CLAIM or D25 before POLICY is green.
- Do not start ADV before IO is green.
- Do not start n-leg gold before CP pathfinder WPs in wave 1+2 are green.
- Do not start SE WPs before all three n-leg gold WPs are green (abstracts stable).
- Do not start DEPRECATE before every test WP is green.
- Do not split a WP across two agents.
- Do not edit Dual Common, Balancer DETFs, or `frontend/**`.

---

## 4. Product locks this plan must not reopen

Copy of PRD §0. Do not re-argue them.

1. Layered catalog (§7.0). Gold-only IDs never run on Stage 11.
2. D15 family names. D15-5 n-leg gold only. Stage 11 D15 subset only.
3. DN3 N/A. DN15 N/A. DN21 and DN22 required.
4. Stage 11 always sibling ProductLaw + Policy files.
5. H-CP-P2 stays pons TestBase. Launch token, not WETH.
6. No edits to `TestBase_UniswapV4Detf.sol`.
7. Each CP WP ships abstract + CP concrete.
8. CLAIM waits for POLICY.
9. D18 not tested. E6 N/A.
10. Nested four IDs only.
11. Custom close execute: CP T7.11 + Quad T8.3 only.
12. Weighted T8.4 = Policy reserve skew, not Custom mint table.
13. `compound` `lpOut==0` is success when lazy compound already consumed protocol pending.
14. K1 and F1 named tests as in PRD R-15.
15. FC4 = later `bond`. FC name suffixes per R-16.
16. Fee oracle `p=5e16`, `f=12e16`, `c=28e16`.
17. Launch-rich opening max 24 steps from `1.1e18`.
18. Regression matchers are exactly `prod-se/**`, `pons/**`, `UniswapV4Detf_*.t.sol`.
19. D22 on Policy instances only.
20. `previewRedeem` exists; D15-1 must `assertEq` preview and exec.

Critical flaw (PRD §6.1): leave the test red; stop the WP; no production CODE until an explicit go-ahead.

---

## 5. WP file maps (sole scope)

Spec root: `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/`  
Pkg root: `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/`

Do not put TestBases under `test/` if the gold unified TestBase lives under `contracts/…/detf/`.

### 5.1 WP-UDPL-IO

**Create**

| Path |
|------|
| `…/detf/UniswapV4Detf_IoTablesGoldBase.sol` |
| `…/detf/UniswapV4Detf_IoTablesOpenBase.sol` |
| `…/detf/UniswapV4Detf_IoTables.t.sol` |
| `…/detf/UniswapV4Detf_OwnerOnlyLiquidityBase.sol` |
| `…/detf/UniswapV4Detf_OwnerOnlyLiquidityOpenBase.sol` |
| `…/detf/UniswapV4Detf_OwnerOnlyLiquidity.t.sol` |

**IDs:** PRD §7.1 gold CP + Open-layer T7.2/T7.10/T7.14/T7.19; T7.11 execute; §7.7 CP owner-only.

**Do not:** Stage 11 siblings; Quad T8.3; `TestBase_UniswapV4Detf.sol`.

### 5.2 WP-UDPL-POLICY

**Create**

| Path |
|------|
| `pkg/TestBase_UniswapV4Detf_Policy.sol` |
| `…/detf/UniswapV4Detf_PolicyBase.sol` |
| `…/detf/UniswapV4Detf_PolicyLayerBase.sol` |
| `…/detf/UniswapV4Detf_Policy.t.sol` |
| `…/detf/UniswapV4Detf_OpeningPriceBase.sol` |
| `…/detf/UniswapV4Detf_OpeningPriceLayerBase.sol` |
| `…/detf/UniswapV4Detf_OpeningPrice.t.sol` |

`_policyArgs()` virtual on the TestBase. Constants: PRD §5.1 (Policy 1.05/0.95, expansion fields, fee D6, launch-rich max 24 steps).

**IDs:** PRD §7.2 CP gold, including D31-1..4, compound, T1/T2/T5. T6 is Weighted/Quad (later WPs).

### 5.3 WP-UDPL-DONATE

**Create**

| Path |
|------|
| `…/detf/UniswapV4Detf_ReserveDonationBase.sol` |
| `…/detf/UniswapV4Detf_ReserveDonationOpenBase.sol` |
| `…/detf/UniswapV4Detf_ReserveDonation.t.sol` |

Keep existing `UniswapV4Detf_Donate.t.sol` T7.13.

**IDs:** PRD §7.5 CP gold. NatSpec DN3 and DN15.

### 5.4 WP-UDPL-CLAIM

**Create**

| Path |
|------|
| `…/detf/UniswapV4Detf_ClaimBase.sol` |
| `…/detf/UniswapV4Detf_ClaimOpenBase.sol` |
| `…/detf/UniswapV4Detf_Claim.t.sol` |
| `…/detf/UniswapV4Detf_Alignment_RedeemD15Base.sol` |
| `…/detf/UniswapV4Detf_Alignment_RedeemD15OpenBase.sol` |
| `…/detf/UniswapV4Detf_Alignment_RedeemD15PolicyBase.sol` |
| `…/detf/UniswapV4Detf_Alignment_RedeemD15.t.sol` |
| `…/detf/UniswapV4Detf_Alignment_FeeCreatorClaimBase.sol` |
| `…/detf/UniswapV4Detf_Alignment_FeeCreatorClaimPolicyBase.sol` |
| `…/detf/UniswapV4Detf_Alignment_FeeCreatorClaim.t.sol` |

**IDs:** PRD §7.3 CP gold. Copy logic from `UniswapV4SingleStandardExchangeDETF_Alignment_RedeemD15.t.sol` and `…_FeeCreatorClaim.t.sol`. Rewrite sell/redeem/claimRewards onto NFT + claim token. FC4 later `bond`.

### 5.5 WP-UDPL-D25

**Create**

| Path |
|------|
| `…/detf/UniswapV4Detf_Alignment_CloseD25Base.sol` |
| `…/detf/UniswapV4Detf_Alignment_CloseD25OpenBase.sol` |
| `…/detf/UniswapV4Detf_Alignment_CloseD25.t.sol` |

**IDs:** PRD §7.4 CP gold.

### 5.6 WP-UDPL-ADV

**Create**

| Path |
|------|
| `pkg/TestBase_UniswapV4Detf_Adversarial.sol` |
| `…/detf/UniswapV4Detf_AdversarialOpenBase.sol` |
| `…/detf/adversarial/Adversarial_A0Crops.t.sol` |
| `…/detf/adversarial/Adversarial_TrustFlags.t.sol` |
| `…/detf/adversarial/Adversarial_Surface.t.sol` |
| `…/detf/adversarial/Adversarial_Reentrancy.t.sol` |
| `…/detf/adversarial/Adversarial_NestedSe.t.sol` |

**IDs:** PRD §7.6 CP gold. Do not add `Adversarial_ProdSe_TrustFlags.t.sol` here (SE WPs attach Open base).

### 5.7 WP-UDPL-OR / WE / QD (n-leg gold)

**Create** (same stems, hook infix)

| Stem | OR | WE | QD extra |
|------|----|----|----------|
| Policy | `UniswapV4Detf_Orbital_Policy.t.sol` | `_Weighted_Policy.t.sol` | `_Quad_Policy.t.sol` |
| OpeningPrice | `_Orbital_OpeningPrice.t.sol` | `_Weighted_OpeningPrice.t.sol` (T6) | `_Quad_OpeningPrice.t.sol` (T6) |
| Claim | `_Orbital_Claim.t.sol` | `_Weighted_Claim.t.sol` | `_Quad_Claim.t.sol` |
| RedeemD15 | `_Orbital_Alignment_RedeemD15.t.sol` (D15-5) | Weighted + D15-5 | Quad + D15-5 |
| FeeCreatorClaim | `_Orbital_Alignment_FeeCreatorClaim.t.sol` | Weighted | Quad |
| CloseD25 | `_Orbital_Alignment_CloseD25.t.sol` | Weighted | Quad |
| ReserveDonation | `_Orbital_ReserveDonation.t.sol` | Weighted | Quad |
| OwnerOnly | `_Orbital_OwnerOnlyLiquidity.t.sol` | Weighted | Quad |
| adversarial concretes | inherit CP abstracts | inherit | inherit |

**QD also edits** existing `UniswapV4Detf_Quad.t.sol` `test_T8_3_customClose_onePair`: call `closeBondMature`.

**WE also adds** `test_T8_4_policy_pairA_not_pairB_via_trades` on Weighted Policy gold.

No Stage 11 files in these WPs.

### 5.8 Stage 11 siblings (SE WPs)

Always two files per fixture. Never edit the existing money-path contract.

**WP-UDPL-SE-CP**

| Fixture | ProductLaw | Policy |
|---------|------------|--------|
| H-CP-GV3 | `prod-se/UniswapV4Detf_Cp_Univ3Se_ProductLaw.t.sol` | `…_Policy.t.sol` |
| H-CP-GV4 | `prod-se/UniswapV4Detf_Cp_Univ4Se_ProductLaw.t.sol` | `…_Policy.t.sol` |
| H-CP-P1 | `prod-se/UniswapV4Detf_Cp_PonsV1Se_ProductLaw.t.sol` | `…_Policy.t.sol` |
| H-CP-MB | `prod-se/UniswapV4Detf_Cp_MorphoBlueSe_ProductLaw.t.sol` | `…_Policy.t.sol` |
| H-CP-P2 | `pons/UniswapV4Detf_PonsV2Se_ProductLaw.t.sol` | `pons/UniswapV4Detf_PonsV2Se_Policy.t.sol` |

**Also edit:** `contracts/test/bases/TestBase_UniswapV4Detf_PonsV2Se.sol` and `pons/UniswapV4Detf_PonsV2Se.t.sol` (launch token). Keep T10.8–T10.10.

**WP-UDPL-SE-OR** (7 fixtures): `UniswapV4Detf_Orbital_{Univ3Se,Univ4Se,PonsV1Se,PonsV2Se,MorphoBlueSe,PonsMix,MorphoMix}_{ProductLaw,Policy}.t.sol` under `prod-se/`.

**WP-UDPL-SE-WE** (7 fixtures): same stems with `Weighted`. Include T8.4 and T6 on Policy siblings.

**WP-UDPL-SE-QD** (7 fixtures): same stems with `Quad`. Include T6 on Policy siblings. No T8.3 execute. No T8.4.

Inherit the matching Stage 11 TestBase + Open or Policy **layer** abstracts (PRD R-24). Shared assert bodies live on internal helpers or gold abstract internals. No empty `test_*` stubs.

### 5.9 WP-UDPL-DEPRECATE

PRD §11 is the file list. Order:

1. Confirm §10 this-PRD matchers and Stage 11 regression green.
2. Retarget scripts/instances (PRD §11.1).
3. After no script imports family DETF: delete Solidity listed in §11.2.
4. Docs §11.3, including PROGRAM Stage 12 if missing.

Keep: hooks, SE packages, `detf/common/**`, Balancer DETFs, Stage 11 prod-se tests, pons H-CP-P2 TestBase.

---

## 6. Forge commands

```bash
# IO
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_IoTables.t.sol'
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_OwnerOnlyLiquidity.t.sol'

# POLICY
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Policy.t.sol'
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_OpeningPrice.t.sol'

# DONATE
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_ReserveDonation.t.sol'

# CLAIM
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Claim.t.sol'
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_RedeemD15.t.sol'
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_FeeCreatorClaim.t.sol'

# D25
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_CloseD25.t.sol'

# ADV
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/adversarial/**'

# n-leg gold
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Orbital*.t.sol'
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Weighted*.t.sol'
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Quad*.t.sol'

# Stage 11 money paths + siblings
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/**'
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/**'

# Regression (every WP DONE)
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/**'
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/**'
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_*.t.sol'
```

Prefer `--match-contract` the WP concrete when `--match-path` would pull extras.

---

## 7. Definition of done

A WP is **DONE** only when:

- [ ] Every ID in PRD §7.0 for that WP’s layer exists as a `test_*` function with that exact name
- [ ] That WP’s matcher in §6 is green
- [ ] The three regression matchers in §6 are green
- [ ] No production CODE was patched on a red §7 test without an explicit go-ahead
- [ ] Status row in §8 updated

This program is **closed** when:

- [x] All 14 WPs including **WP-UDPL-DEPRECATE** are green
- [x] `rg "UniswapV4SingleStandardExchangeDETFDFPkg|IUniswapV4SingleStandardExchangeDETF" scripts/foundry/anvil_robinhood_{testnet,fee_detf,main} scripts/foundry/UniswapV4DetfScriptWireLib.sol scripts/foundry/anvil_robinhood_testnet/ProtocolDetfInstanceLib.sol` is empty (or only comments in superseded banners)
- [x] Family Uni V4 DETF package dirs listed in PRD §11.2 are gone (superseded `*_PRD.md` banners only)
- [x] Agent-law Uni V4 rows point at `…/uniswap/v4/detf/`
- [x] `foundry.toml` still has `via_ir = false`

---

## 8. Status table (update when a WP lands)

| WP | Worktree | Status |
|----|----------|--------|
| WP-UDPL-IO | `unified_detf_pl_io` | go-ahead applied: T7.15 NatSpec N/A |
| WP-UDPL-POLICY | `unified_detf_pl_policy` | go-ahead applied: R-18 max 24; R-14 lpOut==0 OK |
| WP-UDPL-DONATE | `unified_detf_pl_donate` | go-ahead applied: cut claimLiquidity / previewClaimLiquidity |
| WP-UDPL-CLAIM | `unified_detf_pl_claim` | green: D15 11/11, Claim 3/3, FC 12/12 |
| WP-UDPL-D25 | `unified_detf_pl_d25` | green (8/8 + R-19) |
| WP-UDPL-ADV | `unified_detf_pl_adv` | green 21/21. I1 donate = DETF-booked pair; J1–J3 cut `claimLiquidity` |
| WP-UDPL-OR | `unified_detf_pl_or` | green: Orbital gold 109/109. D15-1 hint+dust, D15-5 largest-first, D25-6 |
| WP-UDPL-WE | `unified_detf_pl_we` | green: Weighted gold 111/111. T8.4, T6, D15-5 |
| WP-UDPL-QD | `unified_detf_pl_qd` | green: Quad gold 108/108. T8.3 execute, T6, D15-5, FC `test_FC*_univ4Detf_quad_*`. No T7.15. Skip R-19 |
| WP-UDPL-SE-CP | `unified_detf_pl_se_cp` | green: Stage 11 CP Open+Policy siblings; H-CP-P2 launch token T10.8–T10.10; pons 14/0 |
| WP-UDPL-SE-OR | `unified_detf_pl_se_or` | green: 7 Orbital fixtures Open+Policy |
| WP-UDPL-SE-WE | `unified_detf_pl_se_we` | green: 7 Weighted fixtures Open+Policy; T8.4; T6 |
| WP-UDPL-SE-QD | `unified_detf_pl_se_qd` | green: 7 Quad fixtures Open+Policy; T6 |
| WP-UDPL-DEPRECATE | `unified_detf_pl_deprec` | green: scripts on `IUniswapV4Detf`; family DETF diamonds deleted; agent-law at `…/uniswap/v4/detf/`; family PRDs superseded banners; `via_ir = false`; R-19 prod-se 2221/0, pons 14/0, gold 427/0 |

Family Uni V4 DETF diamonds deleted in WP-UDPL-DEPRECATE. Buffer hooks stay.

`foundry.toml` `via_ir = false`.
