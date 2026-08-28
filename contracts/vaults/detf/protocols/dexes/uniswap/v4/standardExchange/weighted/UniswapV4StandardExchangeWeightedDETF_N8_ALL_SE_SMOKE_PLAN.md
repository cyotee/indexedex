# Plan: Weighted DETF n=8 all-external-SE smoke (7 SE vaults)

**PRD (product law):** [`UniswapV4StandardExchangeWeightedDETF_PRD.md`](./UniswapV4StandardExchangeWeightedDETF_PRD.md)  
**Family impl plan:** [`UniswapV4StandardExchangeWeightedDETF_IMPLEMENTATION_AND_TEST_PLAN.md`](./UniswapV4StandardExchangeWeightedDETF_IMPLEMENTATION_AND_TEST_PLAN.md) §6  
**This file (implementor SoT for this slice):** n=8, seven distinct SEs, smoke only  
**Package root:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/`  
**Date:** 2026-08-28  
**Status:** Locked for `/goal`. Tests only. No product-law reopen.

---

## Launch (paste into `/goal`)

```text
/goal Implement the Weighted DETF n=8 all-external-SE smoke from the locked plan. No product choices. No half measures.

IMPLEMENTOR SOT (read fully first, then execute it):
- contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETF_N8_ALL_SE_SMOKE_PLAN.md

LAW (read after the plan, do not reopen locks):
- contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETF_PRD.md
- contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETF_IMPLEMENTATION_AND_TEST_PLAN.md §6
- Copy shape: test_n8_1SeBare_firstBond_smoke in test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETF_Core.t.sol
- Claude.md + docs/agent/INDEXEDEX_AGENT_LAW.md
- skills: crane-testing, crane-deployment, crane-architecture, indexedex-testing, indexedex-uniswap-v4-hook-packages

If this plan and a PRD disagree, this plan wins for file map and test list. Do not invent extra fixtures or reopen unified Weighted n=3.

Seed cache_forge/ + out/ if this is a new worktree. Wait for forge/solc exit. Never kill forge. via_ir forbidden.

DONE when this plan’s “Done when” section is true.
```

---

## Goal

Ship a hermetic Foundry smoke that deploys the **Weighted SE buffer hook** as a DETF reserve with **seven distinct Standard Exchange vaults**: one SE per external pair, DETF self-leg raw. That is hook \(n = 8\) (DETF + 7 pairs), \(m = 7\), \(\binom{8}{2} = 28\) V4 doors.

## Product lock

Attach this to the **family** package `UniswapV4StandardExchangeWeightedDETF`, not the unified `UniswapV4DetfDFPkg` production-SE matrix.

| Product | Why this plan uses it |
|---------|------------------------|
| Family Weighted DETF (`…/standardExchange/weighted/`) | PRD already requires \(n \in \{2,3,4,8\}\) **and** all-external-SE. `PkgArgs` already has `MAX_M = 7`. Gold TestBase already deploys this DFPkg via `indexedexManager`. |
| Unified `UniswapV4DetfDFPkg` | Production-SE matrix **locks Weighted at \(n=3\)** (2 SEs). Bare pairs forbidden. Adding 7 production SEs would reopen that PRD and is a different, heavier program. |

Hook law still applies: ≥1 SE, SEs pairwise distinct, DETF self-leg `standardExchange = 0`, tokens address-ascending, each weight ≥ `1e16` (1%), sum = 1e18.

## Gap today

| Existing row | \(n\) | SEs bound |
|--------------|-------|-----------|
| `test_n3_allSe_firstBond` | 3 | **2** (all external SE) |
| `test_n8_1SeBare_firstBond_smoke` in `UniswapV4StandardExchangeWeightedDETF_Core.t.sol` | 8 | **1** SE + 6 bare |
| Hook `UniswapV4StandardExchangeWeightedBufferHook_N8.t.sol` | 8 | **1** SE (`standardExchanges[0]` only) |
| Unified Weighted prod-se (`H-WE-*`) | 3 | **2** production SEs |

All-external-SE at \(n \ge 3\) exists only at \(n=3\). n=8 all-SE is the missing DoD cell.

## Fixture (LOCKED)

Copy the n=8 1-SE smoke in `UniswapV4StandardExchangeWeightedDETF_Core.t.sol` (`test_n8_1SeBare_firstBond_smoke`) and fill every external SE slot.

- **Pairs (7):** TestBase `token0`–`token3` plus three new `SimpleMintableERC20` (same as the 1-SE n=8 smoke).
- **SEs (7):** reuse `se0`–`se3`; deploy three more with `_deployERC4626SE(address(new SimpleYieldERC4626(pair)))`. Gold Weighted TestBase is ERC-4626 wrapper SE. Do **not** use Uni V3/V4/Morpho production SEs here.
- **`standardExchanges[i]`:** all seven non-zero and pairwise distinct. DETF leg stays `address(0)` on the hook (package maps that).
- **Weights:** same shape as the 1-SE n=8 smoke: `detfWeight = 0.16e18`, six pairs `0.12e18`, last pair `1e18 - sum` so every \(w_i \ge 0.01e18\).
- **Rates:** `creationPairPerDetfWad[i] = 1e18` for all seven; empty opening (resolves to creation).
- **Threshold:** `ThresholdMode.Open` so a post-bond mint is reachable (the 1-SE n=8 smoke uses Policy and only first-bonds).
- **First bond:** `_firstBondOn` already loops `m()` pair tokens. Pass `uint256[]` length 7 (50 ether each, matching the 1-SE smoke).
- **Doors:** `_deployDetfWired` → `ensureReserveReadyWeighted` must open all 28 pairs then `finalizeInitialization`.

SE class is the gold ERC-4626 wrapper (`TestBase_ERC4626StandardExchange`). That is **not** production-SE proof (Uni V3/V4 transferFrom). It **is** proof the Weighted hook + family DETF can bind and join seven buffered legs.

## Tests (smoke, not full lifecycle matrix)

New file (do not dump this into `Core.t.sol` setUp; n=8 all-SE is heavy):

`test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETF_N8AllSe.t.sol`

Extend `TestBase_UniswapV4StandardExchangeWeightedDETF`. Helper `_argsN8_AllSe()` next to `_argsN3_AllSe()` in the TestBase (or private in the spec if stack-heavy).

| Test | Assert |
|------|--------|
| `test_n8_allSe_deploy_wiresSevenDistinctSes` | `n()==8`, `m()==7`; hook `numTokens()==8`, `pairDoorCount()==28`; for `i in 0..6` `standardExchange(i) != 0`, all distinct, `!= detf`; hook `standardExchange(pairToken(i))` matches; DETF raw (`standardExchange(detf)==0`) |
| `test_n8_allSe_firstBond_fullBook` | `_firstBondOn` all 7 legs; `isReserveLive()`; hook `isFullBook()`; every native reserve > 0; bond `tokenId>0`, shares > 0 |
| `test_n8_allSe_liveMint_onePair` | After firstBond: `exchangeIn` / `_mintOn` of `pairToken(0)`, `10 ether`; `out > 0`; Open so Policy does not block |
| `test_n8_allSe_oneDoorSwap` | After live: one V4 swap between two pair tokens (not DETF). Use existing hook TestBase `_swapExactIn` or `previewSwapExactIn` then swap. Proves 28-door book is live |

Do **not** require burn, close, claim, expansion, or all 28 door swaps in v1 of this file. Family plan already says n=8 smoke is enough if heavy.

Optional negative (cheap if deploy helper exists): same args with `ses_[1] = ses_[0]` must revert (duplicate SE). Skip if Core already covers same-SE-twice at smaller n.

## Implementation sequence

1. Add `_argsN8_AllSe()` on `TestBase_UniswapV4StandardExchangeWeightedDETF` (or a small lib if the TestBase hits stack limits). Mint/fund/approve the three extra pairs + SEs inside the helper or a `_prepareN8AllSe()` called from the spec `setUp` override that does **not** replace default n=2 deploy if tests still call `_deployDetfWired(customArgs)` like the 1-SE n=8 smoke.
2. Spec file with the four tests above. Follow the 1-SE n=8 smoke: custom args → `_deployDetfWired` → `_firstBondOn`. Unique `name`/`symbol` per deploy (CREATE2).
3. Fund `detfUser` on all seven pairs (`_firstBondOn` already `_fundPair`s). Approve DETF + each SE if mint uses shares; pair-face mint is allowed on buffered legs (family PRD).
4. Run:
   ```
   forge test --offline -vv --match-path test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETF_N8AllSe.t.sol
   ```
   First compile in a worktree: seed `cache_forge/` + `out/` from a warm checkout; wait for process exit (20–40+ minutes is normal). Do not kill `forge`.
5. Keep `test_n8_1SeBare_firstBond_smoke`. That row is the other n=8 config (1 SE + bare rest).

No production contract changes expected if deploy + firstBond already work at n=8 with one SE. If all-SE join hits gas, stack-too-deep, or door-init failures, fix the **package/hook path that n=8 all-SE exercises**, do not drop SE count.

## Non-goals

- Unified DETF `UniswapV4DetfDFPkg` n=8 / 7 production SEs (Uni V3, Uni V4, Morpho, pons). Separate PRD if wanted later.
- Binding SE on the DETF self-leg.
- All-bare n=8.
- Rate providers on all seven legs (optional later; 0 RPs for this smoke).
- Full money-path matrix (burn/close/claim/expansion) at n=8.
- Changing the unified production-SE catalog (26 fixtures).
- `via_ir`, SUT mocks, `new` facets/DFPkgs.

## Risks

| Risk | Mitigation |
|------|------------|
| Gas / time: 28 doors + 7 SE wraps on first join | Smoke only; 50 ether/leg like existing n=8; Foundry patience (hours, not 10 min) |
| Stack-too-deep in `_argsN8_AllSe` | Build arrays in an external helper lib (pattern: Weighted hook `TestDeployLib`) |
| CREATE2 name clash | Unique `name`/`symbol` per test |
| ERC-4626 unwrap vs production share-pull | Accept: this is family gold TestBase, not UNIFIED_DETF production-SE proof |
| Weights rounding last pair | Same remainder trick as 1-SE n=8 smoke |

## Done when

- Four tests in the new spec file pass hermetic `forge test --offline`.
- `test_n8_1SeBare_firstBond_smoke` still passes.
- Wiring asserts prove **seven** non-zero distinct SEs, not a 1-SE n=8 clone.
- No unified matrix files changed.
