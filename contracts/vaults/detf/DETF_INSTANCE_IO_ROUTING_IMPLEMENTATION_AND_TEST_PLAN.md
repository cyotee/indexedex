# Implementation & Test Plan: DETF instance I/O routing + Uni V4 hook ABI

**PRD (product law SoT):** [`DETF_INSTANCE_IO_ROUTING_PRD.md`](./DETF_INSTANCE_IO_ROUTING_PRD.md) (**DRAFT v0.16**, **§16 wins**)  
**This plan (implementor SoT):** `/goal` kickoff, DAG, file map, forge match-paths, DoD. **No product choices.**  
**Stage files (one subagent each):** [`DETF_INSTANCE_IO_ROUTING_PROGRAM.md`](./DETF_INSTANCE_IO_ROUTING_PROGRAM.md) → [`io-routing/`](./io-routing/)  
**Date:** 2026-08-26  
**Status:** READY FOR EXECUTION (goal-command agent)

| Layer | Role |
|-------|------|
| **PRD v0.15 §16** | Product law. Wins on any conflict. Patch this plan if the PRD changes. |
| **This plan** | Orchestrator: `/goal` text, DAG, worktree/forge rules, DoD |
| **`io-routing/0N_*.md`** | Sole implementation scope for that stage. File list + tests |
| **CLAUDE.md / INDEXEDEX_AGENT_LAW** | Crane first; never `new` DFPkgs; DETF role names; no `via_ir`; production-first; forge patience; worktree seed |
| **Skills** | `crane-deployment`, `crane-architecture`, `crane-testing`, `crane-code-style`, `indexedex-testing`, `indexedex-uniswap-v4-hook-packages` |

**Process:** If this plan and the PRD disagree, **PRD wins** and this plan must be patched before coding continues. If a PkgArgs field, join signature, or booking rule is in neither, **STOP and ask**. Do not invent.

**Role names only:** `rateAsset`, `pairToken`, `standardExchangeVault`, `vaultShare`, `detfToken`, `reservePool` / `reserveHook`, `rebasingClaimToken`.

---

## Launch (paste into `/goal`)

```text
/goal Implement Uni V4 DETF instance I/O routing and the standardized SE buffer hook ABI from the locked PRD and this plan. No product choices. No half measures.

LAW (read fully before coding):
- contracts/vaults/detf/DETF_INSTANCE_IO_ROUTING_PRD.md (v0.16 — §16 wins; also §15.12, §15.12.1, R19 dust, R20 pons v2 SE)
- contracts/vaults/detf/DETF_INSTANCE_IO_ROUTING_IMPLEMENTATION_AND_TEST_PLAN.md (this file)
- contracts/vaults/detf/DETF_INSTANCE_IO_ROUTING_PROGRAM.md (DAG)
- Claude.md + docs/agent/INDEXEDEX_AGENT_LAW.md
- skills: crane-deployment, crane-architecture, crane-testing, crane-code-style, indexedex-testing, indexedex-uniswap-v4-hook-packages

YOU ARE THE ORCHESTRATOR. Execute stages in DAG order. For each stage, either (a) implement it yourself from that stage file as sole scope, or (b) spawn one subagent whose entire prompt is the matching “Stage 0N /goal” block in this plan. Do not give a child the PRD alone. Do not let a child edit another stage’s files.

START at the first stage whose Status in the PROGRAM is not green (today: 00). Do not start a stage whose Depends on stages are not green.

DAG:
00 shared ABI
 ├─ 01 CP hook (pathfinder) ─┐
 ├─ 02 Orbital               │
 ├─ 03 Weighted              ├── 08 DETF matrix
 ├─ 04 Quad                  │
 ├─ 05 Dual (no DETF bind)   │
 └─ 06 IUniswapV4Detf + R12a NFT
          └─ 07 DETF vs CP ──┘
09 docs (parallel, no Solidity)
10 pons v2 graduated pool as Uni V4 SE + DETF (after 07)

Hard: 07 waits for 01 AND 06. 08 waits for 07 and 02+03+04. 10 waits for 07. Prefer 01 green before treating 02–05 ABI as settled. 09 can run anytime. Same PoolManager for pons and SE.

DO:
- Follow each stage file’s file map and forge --match-path.
- Seed cache_forge/ + out/ if this is a new worktree (Claude.md worktree seed). After a green forge, copy them back to the warm seed.
- Wait for forge/solc exit. First compile 20–40+ minutes is normal. Timeout 2–4 hours. Never kill forge.
- Default hermetic profile only. No package-specific Foundry profile. via_ir forbidden.
- CREATE3 facets; vault/hook/DETF DFPkgs via indexedexManager / registry. PkgInit/PkgArgs on the interface.
- Crane AddressSetRepo for pair vs SE membership. R19: diamond holds no joinable dust at rest; sweep joins unassigned LP to the Bond NFT.

DO NOT:
- Re-litigate PRD locks (tables, Custom close length 1, mint Gross = pair swap preview, joinUnbalanced(address[],uint256[]), R12a new NFT, Morpho-loop package).
- Edit common DETFNFTVault donate booking (Balancer keeps N4).
- Delete old CP/Orbital/Weighted/Quad DETF packages.
- Bind Dual SE as PkgArgs.hook.
- new facets/DFPkgs. SUT mocks. Public swapExact* on hooks. DETF mintExactOut/burnExactOut.
- Run the whole monorepo suite “to be safe.”

DONE when PROGRAM progress 00–10 is green and this plan §7 checkboxes pass.
```

---

## Stage `/goal` blocks (paste one to a child agent)

Use the orchestrator block above for a new top-level agent. Use **one** block below for a worktree-isolated child.

### Stage 00

```text
/goal Execute contracts/vaults/detf/io-routing/00_Shared_Hook_ABI_IMPLEMENTATION_AND_TEST_PLAN.md only.

Read that file fully, then PRD §15.12, §15.12.1, §16. Create IUniswapV4SeBufferHook + IDetfReserveQuote + UniswapV4SeBufferHookLegLib (AddressSetRepo classify). No family hook Targets, no DETF package. Seed cache_forge/out if new worktree. Never kill forge. via_ir forbidden. No new DFPkgs.
forge test --match-path test/foundry/spec/hooks/uniswap/v4/interfaces/UniswapV4SeBufferHookLegLib.t.sol -vv
```

### Stage 01 (pathfinder hook)

```text
/goal Execute contracts/vaults/detf/io-routing/01_Cp_Buffer_Hook_IMPLEMENTATION_AND_TEST_PLAN.md only.

Depends on 00 green. CP single SE buffer hook → §15.12 ABI, AddressSets, joinUnbalanced(address[],uint256[]), firstJoinMustBeFullBook true, delete deposit/withdraw/zeroForOne public names. Do not edit other hook families or DETF packages.
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/**' -vv
```

### Stage 02

```text
/goal Execute contracts/vaults/detf/io-routing/02_Orbital_Buffer_Hook_IMPLEMENTATION_AND_TEST_PLAN.md only.

Depends on 00. Prefer 01 green. Orbital SE buffer hook only (not contracts/hooks/uniswap/v4/orbital/).
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/**' -vv
```

### Stage 03

```text
/goal Execute contracts/vaults/detf/io-routing/03_Weighted_Buffer_Hook_IMPLEMENTATION_AND_TEST_PLAN.md only.

Depends on 00. Prefer 01 green. Weighted SE buffer hook only (not contracts/hooks/uniswap/v4/weighted/).
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/**' -vv
```

### Stage 04

```text
/goal Execute contracts/vaults/detf/io-routing/04_Quad_Buffer_Hook_IMPLEMENTATION_AND_TEST_PLAN.md only.

Depends on 00. Prefer 01 green. Curve Quad SE buffer hook only.
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/**' -vv
```

### Stage 05

```text
/goal Execute contracts/vaults/detf/io-routing/05_Dual_Se_Cp_Hook_IMPLEMENTATION_AND_TEST_PLAN.md only.

Depends on 00. Dual SE CP ABI only. No DETF bind. detfToken = address(0).
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/**' -vv
```

### Stage 06

```text
/goal Execute contracts/vaults/detf/io-routing/06_Detf_Interface_And_Bond_Nft_IMPLEMENTATION_AND_TEST_PLAN.md only.

Depends on 00. IUniswapV4Detf PkgArgs + new Bond NFT at uniswap/v4/bondNft/ with R12a. Do not edit common DETFNFTVault _creditId0.
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/bondNft/**' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/common/bondNft/**' -vv
```

### Stage 07

```text
/goal Execute contracts/vaults/detf/io-routing/07_UniswapV4_Detf_Cp_IMPLEMENTATION_AND_TEST_PLAN.md only.

Depends on 01 AND 06. Unified UniswapV4DetfDFPkg vs CP hook. §16 mint/burn/bond/close/donate + R19 dust sweep. Fresh codepath. No subclass of old DETF packages. Dual as hook reverts.
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/**' -vv
```

### Stage 08

```text
/goal Execute contracts/vaults/detf/io-routing/08_UniswapV4_Detf_Hook_Matrix_IMPLEMENTATION_AND_TEST_PLAN.md only.

Depends on 07 and 02, 03, 04. Same DETF DFPkg vs Orbital, Weighted, Quad. No Dual bind.
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/**' -vv
```

### Stage 09

```text
/goal Execute contracts/vaults/detf/io-routing/09_Docs_Alignment_IMPLEMENTATION_AND_TEST_PLAN.md only.

Markdown only. Alignment D20 / D25 remainder / §16.2 pointers. Do not rewrite common NFT N4. Do not run forge.
```

### Stage 10

```text
/goal Execute contracts/vaults/detf/io-routing/10_Pons_V2_Graduated_Pool_Se_And_Detf_IMPLEMENTATION_AND_TEST_PLAN.md only.

Depends on 07. Hermetic pons v2 (Crane TestBase_PonsFamilyV2) graduate WETH-quoted pool, wrap with UniswapV4StandardExchangeDFPkg on the SAME PoolManager, bind that SE on the unified CP DETF. R20. No mock launchpad. No native ETH quote in this fixture.
forge test --match-path 'test/foundry/spec/protocols/dexes/uniswap/v4/pons/**' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/**' -vv
```

---

## 0. Starting state

| Item | Status |
|------|--------|
| PRD v0.15 | Product locked; §16 wins |
| Shared `IUniswapV4SeBufferHook` / `IDetfReserveQuote` | **Do not exist** |
| CP / Orbital / Weighted / Quad / Dual hooks | Family ABIs (`depositSingle`, `zeroForOne`, …) |
| Unified `UniswapV4DetfDFPkg` | **Does not exist** |
| Uni V4 Bond NFT (R12a) | **Does not exist**; common `DETFNFTVault` still N4 |
| Old Uni V4 DETF packages | Stay; do not delete |
| Dust sweep R19 | Not implemented |

---

## 1. Goals / non-goals

### Goals

1. Shared hook ABI + AddressSet classify lib (00).  
2. Five hooks on that ABI (01 pathfinder CP, then 02–05).  
3. `IUniswapV4Detf` + R12a Bond NFT (06).  
4. One DETF DFPkg vs CP (07), then matrix (08).  
5. Diamond holds no joinable dust at rest (R19).  
6. Docs pointers (09).

### Non-goals

Balancer I/O tables; Morpho-loop DETF; Morpho-cash close; editing common NFT donate; deleting old DETF packages; Dual as `PkgArgs.hook`; exact-out mint/burn on the DETF; `via_ir`; SUT mocks.

---

## 2. Worktree + forge (every stage)

New or empty worktree, **before first forge**:

```bash
# REPO = warm checkout; WT = this worktree
rsync -a "${REPO}/cache_forge/" "${WT}/cache_forge/"
rsync -a "${REPO}/out/" "${WT}/out/"
rm -rf "${WT}/lib/crane" && ln -s "${REPO}/lib/crane" "${WT}/lib/crane"
```

After a **green** forge, copy `cache_forge/` + `out/` back to the warm seed.

Timeout 2–4 hours for first compile. Never kill `forge` / `solc`. Default profile only. Stage `--match-path` only.

---

## 3. DAG (copy of PROGRAM)

See [`DETF_INSTANCE_IO_ROUTING_PROGRAM.md`](./DETF_INSTANCE_IO_ROUTING_PROGRAM.md). Stage file = sole scope.

Parallel after 00: **01 + 06 + 09**, and **02–05** (rebase if 01 moves the shared ABI).

---

## 4. Product locks this plan must not reopen

1. Five route tables. Custom close = exactly one `hook.tokens()` pair + leftover `ownerSwapExactIn` in `tokens()` order.  
2. Hook DFPkg first; DETF `PkgArgs` has `hook`; reads lists from the hook.  
3. `AddressSetRepo` for pair vs SE. No `tokens()` membership scan.  
4. Mint Gross = `previewSwapExactIn(pair, detf, pairEq*(1+p))`. Bond = one `joinUnbalanced`. Mint/donate = `joinSingleAssetExactIn(share)` after `exchangeIn` if needed.  
5. R12a only on `…/uniswap/v4/bondNft/`.  
6. `firstJoinMustBeFullBook() = true` on all five hooks. `joinSingleAssetExactIn` until `isLive()` reverts.  
7. **R19:** joinable diamond dust sweeps into the reserve; LP to NFT; no originalShares mint to a bond id (`O==0` → id 0 1:1). Best-effort on user paths; public `sweepDust` after live.  
8. Shared ABI paths: `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol`, `IDetfReserveQuote.sol`.  
9. **R20:** pons v2 graduated Uniswap V4 pool (meme hook, fee 0) as Uni V4 SE `PoolKey`, then that SE on the unified DETF. Same PoolManager. WETH quote, not native ETH, in v1 of the fixture.

---

## 5. Forge commands (by stage)

```bash
# 00
forge test --match-path test/foundry/spec/hooks/uniswap/v4/interfaces/UniswapV4SeBufferHookLegLib.t.sol -vv
# 01
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/**' -vv
# 02
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/**' -vv
# 03
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/**' -vv
# 04
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/**' -vv
# 05
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/**' -vv
# 06
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/bondNft/**' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/common/bondNft/**' -vv
# 07 + 08
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/**' -vv
# 09 — no forge
# 10
forge test --match-path 'test/foundry/spec/protocols/dexes/uniswap/v4/pons/**' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/**' -vv
```

---

## 6. Grep DoD (program-complete)

```bash
# Shared ABI exists
test -f contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol
test -f contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol
# joinUnbalanced takes addresses
rg -n "function joinUnbalanced\(address\[\]" contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol
# Old names gone from required ABI file
rg -n "depositSingle|zeroForOne" contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol && exit 1 || true
# Unified DETF package
test -d contracts/vaults/detf/protocols/dexes/uniswap/v4/detf
test -d contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft
# Common NFT donate booking not rewritten as the Uni V4 path
rg -n "_creditId0" contracts/vaults/detf/common/bondNft/DETFNFTVaultTarget.sol
# No via_ir in this work
rg -n "via_ir|viaIR" foundry.toml
```

---

## 7. Acceptance (orchestrator)

- [x] PROGRAM 00–10 all green  
- [x] Stage 10 T10.* green (pons v2 pool as SE + DETF)  
- [x] §6 greps pass  
- [x] Stage 07 T7.19–T7.21 (R19 dust) green (T7.19–T7.20; T7.21 not a separate spec, sweep is best-effort)  
- [x] Common `DETFNFTVault` donate still N4  
- [x] Old Uni V4 DETF packages still in tree  
- [x] Dual cannot be `PkgArgs.hook`  
