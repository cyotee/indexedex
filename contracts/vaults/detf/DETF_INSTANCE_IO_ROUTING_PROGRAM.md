# DETF instance I/O routing + Uni V4 hook ABI — Program Index

## Status

| Field | Value |
|-------|--------|
| **Product law** | [`DETF_INSTANCE_IO_ROUTING_PRD.md`](./DETF_INSTANCE_IO_ROUTING_PRD.md) — **DRAFT v0.16**. **§16 wins** on conflict. |
| **`/goal` kickoff** | [`DETF_INSTANCE_IO_ROUTING_IMPLEMENTATION_AND_TEST_PLAN.md`](./DETF_INSTANCE_IO_ROUTING_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **Plans** | Stages **00–09** in [`io-routing/`](./io-routing/) |
| **Implementation** | Not started |

**Do not re-litigate product law in stage plans.** If conflict: PRD §16 wins; open a PRD revision before changing law.

This PROGRAM is the **slice map**. The PRD is not. Do not spawn a subagent with only the PRD and “implement v1.”

---

## How to run an agent on one stage

1. Give the agent **only one** stage plan path.
2. Instruct: read that plan fully, then the PRD sections it cites (§16 always; §15.12 for hook stages), then implement **that stage only**.
3. Do **not** start a stage whose **Depends on** stages are not green.
4. Stage **Definition of Done** must pass before dependents start.

Example goal prompt:

```text
Execute the implementation plan at:
contracts/vaults/detf/io-routing/00_Shared_Hook_ABI_IMPLEMENTATION_AND_TEST_PLAN.md

Normative product law:
contracts/vaults/detf/DETF_INSTANCE_IO_ROUTING_PRD.md
(§16 wins; for this stage also §15.12 and §15.12.1)

Implement only this stage. Do not start other stages.
Production-first tests; no SUT mocks; via_ir forbidden.
Seed cache_forge/ + out/ from a warm checkout before the first forge in a new worktree.
Never kill forge/solc for “no progress.” Wait for process exit.
```

### Worktree + forge (every stage)

- **New or empty worktree:** copy `cache_forge/` and `out/` from the warm repo before the first `forge`. Prefer `ln -s` for `lib/crane` rather than a nested reinstall. After a green forge, copy `cache_forge/` + `out/` back to the warm seed.
- **Timeout:** hours (2–4h) for first compile, not 10–20 minutes. One long command; wait for exit.
- **Profiles:** default hermetic `forge test` only in these stages. `FOUNDRY_PROFILE=fork` only if a stage explicitly lists a fork spec (none do in 00–09). **No** `hook_factory` or other package profile. **`via_ir` forbidden.**
- **Selective tests:** use the stage’s `--match-path` / `--match-contract` only. Do not run the whole monorepo suite “to be safe.”
- **Deploy:** never `new` facets/DFPkgs. Facets CREATE3 / FactoryService. Vault/hook/DETF DFPkgs via `indexedexManager.deploy*DFPkg` / registry. `PkgInit` / `PkgArgs` on the **interface**.

---

## Execution order (mandatory DAG)

```text
Stage 00  Shared hook ABI + AddressSet classify lib
    │
    ├─► Stage 01  CP single SE buffer hook          [pathfinder]
    ├─► Stage 02  Orbital SE buffer hook            (after 00; prefer 01 green)
    ├─► Stage 03  Weighted SE buffer hook
    ├─► Stage 04  Curve Quad SE buffer hook
    └─► Stage 05  Dual SE CP hook (ABI only; no DETF bind)
              │
Stage 06  IUniswapV4Detf interface + Uni V4 Bond NFT (R12a)
    │         (after 00; parallel with hooks)
    ▼
Stage 07  Unified Uni V4 DETF DFPkg vs CP hook
    │         (after 01 AND 06)
    ▼
Stage 08  DETF matrix vs Orbital / Weighted / Quad
              (after 07 AND 02, 03, 04)
Stage 09  Docs only: alignment D20 / D25 remainder / agent-law pointer
              (after 00; no Solidity; parallel with any stage)
Stage 10  pons v2 graduated V4 pool → Uni V4 SE → DETF bound leg (R20)
              (after 07; hermetic TestBase_PonsFamilyV2, same PoolManager)
Stage 11  Production SE × hook matrix tests (this PROGRAM index only)
              (after 07+08+10). Law: UNIFIED_DETF_PRODUCTION_SE_HOOK_MATRIX_TEST_PRD.md
```

**Hard rules:**

- Stage 00 before any hook stage (01–05).
- Pathfinder: **01 green before treating 02–05 ABI as settled.** 02–05 may start after 00; if 01 changes a shared signature, 02–05 rebase.
- Stage 07 (DETF) waits for **01 + 06**. Do not implement DETF against Orbital first.
- Stage 08 waits for 07 and the matching hook stages.
- Stage 05 (Dual) never binds as `PkgArgs.hook`.
- Do **not** delete old CP/Orbital/Weighted/Quad **DETF** packages in this program.
- Do **not** edit common `DETFNFTVault` donate booking.
- Stage **10** waits for **07**. Same `PoolManager` for pons graduation and Uni V4 SE `PkgInit`.

Parallel after 00 is legal: **01 + 06 + 09**, and **02–05** (rebase if 01 moves the shared ABI).

---

## Stage catalog

| Stage | Scope | Plan |
|-------|--------|------|
| **00** | Shared `IUniswapV4SeBufferHook` + `IDetfReserveQuote` + classify lib | [`io-routing/00_Shared_Hook_ABI_IMPLEMENTATION_AND_TEST_PLAN.md`](./io-routing/00_Shared_Hook_ABI_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **01** | CP single SE buffer hook → §15.12 (pathfinder) | [`io-routing/01_Cp_Buffer_Hook_IMPLEMENTATION_AND_TEST_PLAN.md`](./io-routing/01_Cp_Buffer_Hook_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **02** | Orbital SE buffer hook → §15.12 | [`io-routing/02_Orbital_Buffer_Hook_IMPLEMENTATION_AND_TEST_PLAN.md`](./io-routing/02_Orbital_Buffer_Hook_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **03** | Weighted SE buffer hook → §15.12 | [`io-routing/03_Weighted_Buffer_Hook_IMPLEMENTATION_AND_TEST_PLAN.md`](./io-routing/03_Weighted_Buffer_Hook_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **04** | Curve Quad SE buffer hook → §15.12 | [`io-routing/04_Quad_Buffer_Hook_IMPLEMENTATION_AND_TEST_PLAN.md`](./io-routing/04_Quad_Buffer_Hook_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **05** | Dual SE CP hook → §15.12; DETF bind still reverts | [`io-routing/05_Dual_Se_Cp_Hook_IMPLEMENTATION_AND_TEST_PLAN.md`](./io-routing/05_Dual_Se_Cp_Hook_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **06** | `IUniswapV4Detf` + Bond NFT R12a package | [`io-routing/06_Detf_Interface_And_Bond_Nft_IMPLEMENTATION_AND_TEST_PLAN.md`](./io-routing/06_Detf_Interface_And_Bond_Nft_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **07** | Unified DETF DFPkg vs CP hook | [`io-routing/07_UniswapV4_Detf_Cp_IMPLEMENTATION_AND_TEST_PLAN.md`](./io-routing/07_UniswapV4_Detf_Cp_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **08** | DETF vs Orbital / Weighted / Quad | [`io-routing/08_UniswapV4_Detf_Hook_Matrix_IMPLEMENTATION_AND_TEST_PLAN.md`](./io-routing/08_UniswapV4_Detf_Hook_Matrix_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **09** | Alignment / donation / agent-law pointers | [`io-routing/09_Docs_Alignment_IMPLEMENTATION_AND_TEST_PLAN.md`](./io-routing/09_Docs_Alignment_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **10** | pons v2 graduated pool as Uni V4 SE + DETF (R20) | [`io-routing/10_Pons_V2_Graduated_Pool_Se_And_Detf_IMPLEMENTATION_AND_TEST_PLAN.md`](./io-routing/10_Pons_V2_Graduated_Pool_Se_And_Detf_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **11** | Unified DETF × Uni V3/V4 SE × Morpho Blue SE × CP/Orbital/Weighted/Quad, including pons v1 and v2 | [`UNIFIED_DETF_PRODUCTION_SE_HOOK_MATRIX_TEST_PRD.md`](./UNIFIED_DETF_PRODUCTION_SE_HOOK_MATRIX_TEST_PRD.md) |

---

## Out of scope (never assign as stages)

| Item | Reason |
|------|--------|
| Balancer DETF I/O tables | PRD follow-on |
| Morpho-loop DETF | Later package. Morpho Blue SE as a **hook pair leg** is Stage 11 |
| Morpho-cash close | Later package. Stage 11 Morpho rows keep Blue cash (no borrow) |
| Editing `DETFNFTVault` `_creditId0` | Balancer keeps N4 |
| Deleting old Uni V4 DETF packages | Instances stay |
| Public `swapExact*` on hooks | Deleted |
| DETF `mintExactOut` / `burnExactOut` | Exact-in only |
| Dual SE as DETF `PkgArgs.hook` | processArgs revert |
| `via_ir`; SUT mocks | Always-on law |

---

## Progress checklist

| Stage | Status | Notes |
|-------|--------|-------|
| 00 Shared ABI | green | |
| 01 CP hook | green | pathfinder |
| 02 Orbital hook | green | |
| 03 Weighted hook | green | |
| 04 Quad hook | green | |
| 05 Dual SE CP hook | green | |
| 06 DETF iface + NFT | green | |
| 07 Unified DETF vs CP | green | Dual as hook reverts; R19 T7.19–T7.20 |
| 08 DETF hook matrix | green | same UniswapV4DetfDFPkg vs Orbital/Weighted/Quad |
| 09 Docs | green | D20/D25 remainder / §16.2 pointers |
| 10 pons v2 SE + DETF | green | unified DETF bound to pons Uni V4 SE; Open threshold |
| 11 production SE/hook matrix tests | PRD ready | [`UNIFIED_DETF_PRODUCTION_SE_HOOK_MATRIX_TEST_PRD.md`](./UNIFIED_DETF_PRODUCTION_SE_HOOK_MATRIX_TEST_PRD.md); Uni V3/V4 + Morpho Blue SE; ERC-4626 T7/T8 is not production SE proof |

---

## Product locks agents must not reopen

1. §16 wins. Five route tables. Custom close = exactly one `hook.tokens()` pair + leftover `ownerSwapExactIn` in `tokens()` order.
2. Hook DFPkg first; DETF reads `tokens()` / `standardExchangeOf` from the hook.
3. Crane `AddressSetRepo` for pair vs SE membership. No `tokens()` scan. No OZ EnumerableSet.
4. Mint Gross = `previewSwapExactIn(pair, detf, pairEq*(1+p))`. Bond = one `joinUnbalanced`. Mint/donate = `joinSingleAssetExactIn(share)` after `exchangeIn` if needed.
5. R12a only on `…/uniswap/v4/bondNft/`.
6. `firstJoinMustBeFullBook() = true` on all five hooks. `joinSingleAssetExactIn` until `isLive()` reverts.
7. DETF role names only. Token policy unchanged. Opacity: no Morpho/Uni vault types in DETF production sources.
8. **R19:** diamond holds no joinable dust at rest. Sweep joins LP to the Bond NFT with **no** originalShares mint to a bond id (unassigned; `O==0` uses N14).
9. **R20:** hermetic pons v2 graduated V4 pool (Crane `TestBase_PonsFamilyV2`) wrapped as Uni V4 SE and bound on the unified DETF. Not optional.
