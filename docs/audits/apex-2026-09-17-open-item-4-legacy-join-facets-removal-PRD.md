# PRD: Remove the legacy weighted and curve-quad join facets (APEX open item 4 follow-up)

- **Parent plan:** [apex-2026-09-17-remediation-and-regression-tests.plan.md](./apex-2026-09-17-remediation-and-regression-tests.plan.md) (D19, R12.2, R12.4)
- **Open-items file:** [apex-2026-09-17-review-open-items.md](./apex-2026-09-17-review-open-items.md) item 4
- **Created:** 2026-09-21
- **Status:** executed 2026-09-21; full hermetic run 4 green (32,714/32,714)
- **Execution boundary:** source deletion, factory-helper deletion, test and evidence updates. No behavior change on any installed diamond. No commit (D21); the owner stages and commits.

## 1. Objective

Leave exactly one artifact per selector set in the weighted and curve-quad Standard Exchange buffer-hook families by deleting the legacy `JoinFacet` and `JoinQueryFacet` sources and helpers that the launch path no longer installs, so the installed set (`LiquidityFacet` thinned plus `LiquidityFacetExt`) is the only set that compiles, is declared, is sized and is recorded.

## 2. Facts (verified 2026-09-20 and 2026-09-21)

| Fact | Evidence |
| --- | --- |
| Owner decision 2026-09-21: keep the remediation's facet set (`LiquidityFacet` thinned, `LiquidityFacetExt`) as the installed artifacts. | open-items item 4 |
| Installed by the launch scripts: weighted `joinFacet ← deployLiquidityFacet`, `joinQueryFacet ← deployLiquidityFacetExt`; curve-quad `liquidityFacet ← deployLiquidityFacet`, `joinQueryFacet ← deployLiquidityFacetExt`. | `scripts/foundry/anvil_robinhood_main/Phase_06_Stage_04_WeightedBufferHookPkg.sol:29,35`, `Phase_06_Stage_06_CurveQuadBufferHookPkg.sol:29,35`, and the `anvil_robinhood_testnet` twins |
| Legacy pair per family: weighted `JoinFacet` (24,262 B) and `JoinQueryFacet` (21,498 B); curve-quad `JoinFacet` (23,942 B) and `JoinQueryFacet` (24,058 B). Both tracked, unchanged since HEAD. | `contracts/hooks/uniswap/v4/standardExchange/{weighted,stable/quad/curve}/facets/` |
| Each legacy facet inherits the same Target as its installed counterpart (`JoinTarget`, `JoinQueryTarget`); runtime bytecode is identical apart from the facet-name string. | bytecode comparison 2026-09-20 (metadata stripped, name masked: 2 to 6 hex positions differ, equal lengths) |
| No Solidity caller of `deployJoinFacet` / `deployJoinQueryFacet` exists in `contracts/`, `test/` or `scripts/` other than the helper definitions. The curve-quad `PkgInit` has no `joinFacet` slot at all. | `rg` inventory 2026-09-21 |
| Non-code references: `docs/create3-release-salt-input-inventory.md`, `docs/CONTRACT_SIZE_REDUCTION_WAVE_RESULTS.md`, and two historical patches under `docs/security/universal-detf-audit/` (archival; not to be edited). | same inventory |
| The R12 baseline `docs/audits/apex-2026-09-17-evidence/initial-artifact-selectors-sizes.json` lists the four legacy artifacts; `selector-size-compare.json` compares against it. | evidence directory |
| `LiquidityFacetExt` sources for both families are untracked. | `git status` |

## 3. Locked decisions

| ID | Decision |
| --- | --- |
| L1 | Delete the four legacy facet sources: `weighted/facets/UniswapV4StandardExchangeWeightedBufferHookJoinFacet.sol`, `weighted/facets/UniswapV4StandardExchangeWeightedBufferHookJoinQueryFacet.sol`, `stable/quad/curve/facets/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinFacet.sol`, `stable/quad/curve/facets/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinQueryFacet.sol`. |
| L2 | Delete the four helpers `deployJoinFacet` and `deployJoinQueryFacet` from `UniswapV4StandardExchangeWeightedBufferHook_FactoryService.sol` and `UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService.sol`. Leave every other helper and its salt unchanged. |
| L3 | Do not rename the installed artifacts. `LiquidityFacet` and `LiquidityFacetExt` keep their names and CREATE3 salts (`abi.encode("<contract name>")._hash()` through `ArtifactCreationCode.releaseSalt`). Renaming would change addresses on chains where they are already deployed. |
| L4 | `JoinTarget` and `JoinQueryTarget` stay. They are the logic; only the duplicate declaration contracts go. |
| L5 | The `PkgInit` field names (`joinFacet`, `joinQueryFacet` on weighted; `liquidityFacet`, `joinQueryFacet` on curve-quad) stay. Renaming fields changes the package interface and the DFPkg ABI, which R12 forbids for this program. Add a NatSpec line on each field naming the artifact that fills it. |
| L6 | Stage the two untracked `LiquidityFacetExt` sources so the installed set is tracked. Staging is not a commit; D21 still applies. |
| L7 | Update the R12 baseline: remove the four legacy entries from `initial-artifact-selectors-sizes.json`, re-run the selector and size comparison, and record the new `selector-size-compare.json` with zero missing artifacts and zero oversize. Proxy selector sets must be unchanged. |
| L8 | Update `docs/create3-release-salt-input-inventory.md` (drop the four legacy salt rows, keep the Ext rows) and add a one-line note to `docs/CONTRACT_SIZE_REDUCTION_WAVE_RESULTS.md` that the legacy pair was retired on 2026-09-21. Historical patches under `docs/security/universal-detf-audit/` are not edited. |
| L9 | No change to any Target, Core, DFPkg, script or test behavior. A test that only exists to declare a legacy facet is deleted with it; a test that exercises the installed set is kept and must still pass. |

## 4. Scope

**In.** The eight deletions in L1 and L2; NatSpec on four `PkgInit` fields; staging the two Ext sources; evidence and inventory updates in L7 and L8; a full build and the affected family suites.

**Out.** Slipstream's `InFacetExt` (a real split of an installed oversize facet, unchanged). The hook Targets. Package interfaces and salts. Any other family. Deployment.

## 5. Steps

1. Delete the four facet sources (L1) and the four helpers (L2).
2. `rg -n 'JoinFacet\b|JoinQueryFacet\b' contracts test scripts` must return no hits outside `JoinTarget` / `JoinQueryTarget` names and the untouched historical docs.
3. Add the L5 NatSpec on the four `PkgInit` fields.
4. `git add` the two `LiquidityFacetExt` sources.
5. `forge build`; then run the two families' declaration, liquidity and adversarial suites and the DETF suites that deploy these hooks:

   ```bash
   python3 scripts/forge-artifacts.py test \
     contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_FactoryService.sol \
     contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService.sol \
     --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted \
     --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve \
     --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf -- -vv
   ```

6. Re-run the R12 artifact selector and size comparison against the updated baseline (L7) and record `selector-size-compare.json`.
7. Update the inventory documents (L8) and the open-items file (item 4: "legacy pair removed").
8. `forge test -vv` full hermetic; `git diff --check`.

## 6. Acceptance criteria

- [x] A1. The four legacy facet sources and the four helpers no longer exist; `rg` in step 2 is clean.
- [x] A2. `forge build` succeeds; no artifact named `*JoinFacet` or `*JoinQueryFacet` for the weighted or curve-quad families is produced.
- [x] A3. The installed artifacts (`LiquidityFacet` thinned, `LiquidityFacetExt`, both families) keep their names, salts, selector sets and sizes: weighted 23,939 / 21,532 bytes, curve-quad 23,619 / 24,087 bytes at the time of writing, all under 24,576.
- [x] A4. Every hook diamond deployed by the launch scripts and TestBases exposes the same proxy selector set as before the deletion (loupe comparison in the family declaration tests).
- [x] A5. The updated `selector-size-compare.json` reports zero missing artifacts, zero oversize artifacts, and no proxy selector diff.
- [x] A6. Weighted, curve-quad and Uni V4 DETF suites pass; full hermetic suite stays green; `git diff --check` clean.
- [x] A7. Both `LiquidityFacetExt` sources are tracked (staged); nothing is committed by the executor.
- [x] A8. `docs/create3-release-salt-input-inventory.md` and `docs/CONTRACT_SIZE_REDUCTION_WAVE_RESULTS.md` reflect the retirement; historical audit patches are untouched.

## 7. Risks

- **Deployed-address expectations.** If any chain record or script outside this repository expects a `JoinFacet` / `JoinQueryFacet` address for these families, it will not find one after this change. The chain-4663 address records in `frontend/packages/protocol/src/addresses/chain/4663/` contain no such facet names; confirm the same for any external deployment notes before deleting.
- **Baseline drift.** The R12 comparison must be re-baselined deliberately (L7), not by silently ignoring "missing artifact" rows.
