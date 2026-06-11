# Deployment Script Removal Candidates

Date: 2026-06-05
Companion to: `docs/DEPLOYMENT_SCRIPT_INVENTORY.md`, `docs/DEPLOYMENT_INVENTORY_DETAILED.md`, `docs/DEPLOYMENT_READINESS_REPORT.md`.

Goal: trim the script surface while preserving every active deployment and test scenario.

Active surfaces that must keep working after removal:

- `scripts/foundry/public_sepolia/` driven by `deploy_public_sepolia.sh` (Ethereum Sepolia + Base Sepolia public broadcast).
- `scripts/foundry/supersim/` driven by `deploy_mainnet_bridge_ui.sh` (local cross-chain SuperSim rehearsal).
- `scripts/foundry/anvil_base_main/` driven by `deploy_all.sh` (full Base mainnet fork local pipeline).
- `scripts/foundry/anvil_sepolia/` driven by `deploy_sepolia.sh` (full Sepolia fork local pipeline).
- `scripts/foundry/local_testing/` driven by `scripts/shell/local_testing.sh` and `scripts/shell/local_testing_supersim.sh` (scenario-based local-testing flow with Scenario 1–4 overlays).

The scenario-based path under `scripts/foundry/local_testing/` is the canonical surface for the "deploy several test scenarios" use case. Recommendations below preserve it.

Tiers are ordered by confidence — Tier 1 has zero live references and is safe to remove; Tier 2 has dead intra-script references that can be removed together; Tier 3 is on-disk artifact backups; Tier 4 is companion documentation cleanup that should follow the removals.

## Tier 1 — Safe to delete now (zero live references)

These have no active wrapper invoking them and no imports from any live script. Their only references are in archived task docs, the historical `REVIEW_REPORT.md`, or the legacy shell wrappers also listed for removal here.

### Legacy Foundry script tree under `scripts/foundry/local/`

Replaced in full by `scripts/foundry/local_testing/`. Documented as legacy in `docs/DEPLOYMENT_SCRIPT_INVENTORY.md` lines 31–32 and `docs/DEPLOYMENT_READINESS_REPORT.md`.

Delete:

- `scripts/foundry/local/Demo_01_Test_Tokens.s.sol`
- `scripts/foundry/local/Demo_02_External_Protocols.s.sol`
- `scripts/foundry/local/Local_Sepolia_01_Deploy.s.sol`
- `scripts/foundry/local/Local_Sepolia_01_Deploy_Factory_Test.s.sol`
- `scripts/foundry/local/Local_Sepolia_02_Test_Tokens.s.sol`
- `scripts/foundry/local/Local_Sepolia_02_Test_Tokens_and_Pools.s.sol`
- `scripts/foundry/local/Local_Sepolia_02_Test_Tokens_and_Pools_Factory_Test.s.sol`
- `scripts/foundry/local/Local_Sepolia_02_Test_Tokens_and_Pools_with_WETH.s.sol`
- `scripts/foundry/local/Local_Sepolia_03_Test_ERC4626.s.sol`
- `scripts/foundry/local/Local_Sepolia_04_Test_UniV2Pools.s.sol`
- `scripts/foundry/local/Sepolia_01_Deploy.s.sol`
- `scripts/foundry/local/Sepolia_02_Test_Tokens_and_Pools.s.sol`
- `scripts/foundry/local/segmented/Local_00_Init.s.sol`
- `scripts/foundry/local/segmented/Local_01_WETH9.s.sol`
- `scripts/foundry/local/segmented/Local_02_Permit2.s.sol`
- `scripts/foundry/local/segmented/Local_03_Balancer_V3.s.sol`
- `scripts/foundry/local/segmented/Local_04_Uniswap_V2.s.sol`
- `scripts/foundry/local/segmented/Local_05_Crane_Factories.s.sol`
- `scripts/foundry/local/segmented/Local_06_Crane_Access.s.sol`
- `scripts/foundry/local/segmented/Local_07_Crane_Components.s.sol`
- `scripts/foundry/local/segmented/Local_08_Indexedex_Components.s.sol`
- `scripts/foundry/local/segmented/Local_09_Indexedex_Core.s.sol`
- `scripts/foundry/local/segmented/Local_10_Indexedex_Components_2.s.sol`
- `scripts/foundry/local/segmented/Local_11_Indexedex_Platform.s.sol`
- `scripts/foundry/local/segmented/Local_12_Demo_Platform.s.sol`
- `scripts/foundry/local/segmented/Local_13_Test_Tokens.s.sol`
- `scripts/foundry/local/segmented/Local_14_Test_ERC4626.s.sol`

Result: the entire `scripts/foundry/local/` subtree can be removed.

### Legacy shell wrappers under `scripts/shell/`

Each one drives only the legacy `scripts/foundry/local/` tree above and references no active script:

- `scripts/shell/local.sh`
- `scripts/shell/local_segments.sh`
- `scripts/shell/local_with_weth.sh`
- `scripts/shell/sepolia.sh`

Keep the rest of `scripts/shell/`:

- `scripts/shell/local_testing.sh` (active — drives the scenario-based local flow)
- `scripts/shell/local_testing_supersim.sh` (active — dual-chain scenario flow)
- `scripts/shell/dev_anvil_bg.sh` (active — background Anvil helper)
- `scripts/shell/dev_daosys_frontend_bg.sh` (active — background frontend helper)

### Deprecated compatibility shim

- `contracts/script/IndexedexScript.sol`

The file is an empty abstract `IndexedexScript is Script {}` explicitly tagged "Deprecated placeholder kept for backwards-compatibility with old file paths." Inventory doc already calls it deprecated. No production contract imports it. The whole `contracts/script/` directory becomes empty and can be removed.

## Tier 2 — Safe to delete together (dead older Foundry trees with intra-tree references only)

### `scripts/foundry/sepolia/` — entire directory

The directory has been frozen out:

- `Script_DeploySepoliaEnvironment.s.sol`, `ethereum/Script_DeployAll.s.sol`, and `base/Script_DeployAll.s.sol` all explicitly `revert("... reserved for the second implementation pass.")`. They cannot deploy anything by design.
- `Script_00_DeploySepoliaDemo.s.sol` plus `Script_01-15_*.sol` plus `Script_ExportTokenlists.s.sol` is the old single-chain Sepolia demo pipeline. It duplicates `scripts/foundry/anvil_sepolia/` Stages 01–15 in source form.
- `deploy_sepolia.sh` is the older single-chain wrapper. `scripts/foundry/public_sepolia/EXECUTION.md` explicitly tells users not to use this for the cross-chain demo, and the cross-chain demo is now the only sanctioned Sepolia broadcast path.
- `DeploymentBase.sol` is local to this dir; nothing outside `scripts/foundry/sepolia/` imports it.

Delete the whole subtree:

- `scripts/foundry/sepolia/DeploymentBase.sol`
- `scripts/foundry/sepolia/Script_00_DeploySepoliaDemo.s.sol`
- `scripts/foundry/sepolia/Script_01_DeployFactories.s.sol` through `Script_15_DeploySeigniorageDETFS.s.sol`
- `scripts/foundry/sepolia/Script_DeploySepoliaEnvironment.s.sol`
- `scripts/foundry/sepolia/Script_ExportTokenlists.s.sol`
- `scripts/foundry/sepolia/deploy_sepolia.sh`
- `scripts/foundry/sepolia/ethereum/Script_DeployAll.s.sol`
- `scripts/foundry/sepolia/base/Script_DeployAll.s.sol`

The Stage library this used to host now lives in `scripts/foundry/anvil_sepolia/` and is consumed by both `anvil_sepolia/deploy_sepolia.sh` (full local rehearsal) and `public_sepolia/ethereum/Script_DeployAll` (the cross-chain demo). No functional regression from deleting `scripts/foundry/sepolia/`.

### Dead SuperSim Solidity orchestrators

`scripts/foundry/supersim/deploy_mainnet_bridge_ui.sh` does **not** invoke `Script_DeployAll`. It invokes `Script_DeployProtocolDetfMinimal` per chain (lines 655 and 672). Likewise `public_sepolia/deploy_public_sepolia.sh` only invokes `Script_24` and `Script_25` from the supersim directory and runs `public_sepolia/{ethereum,base}/Script_DeployAll` for the chain-side work.

The two unreached `Script_DeployAll` files and everything imported only by them can go:

- `scripts/foundry/supersim/ethereum/Script_DeployAll.s.sol` (unreached entrypoint)
- `scripts/foundry/supersim/base/Script_DeployAll.s.sol` (unreached entrypoint)
- `scripts/foundry/supersim/ethereum/Script_04_UniV2PoolsAndVaults.s.sol` (imported only by Ethereum `Script_DeployAll`)
- `scripts/foundry/supersim/ethereum/Script_05_BalancerPools.s.sol` (imported only by Ethereum `Script_DeployAll`)
- `scripts/foundry/supersim/ethereum/Script_ExportTokenlists.s.sol` (imported only by Ethereum `Script_DeployAll`; the live wrapper exports artifacts via `scripts/foundry/supersim/export_frontend_artifacts.py` instead)
- `scripts/foundry/supersim/base/Script_17_WethTtcPoolsAndVaults.s.sol` (imported only by Base `Script_DeployAll`)
- `scripts/foundry/supersim/base/Script_18_WethTtcBalancerPools.s.sol` (imported only by Base `Script_DeployAll`)
- `scripts/foundry/supersim/base/Script_ExportTokenlists.s.sol` (imported only by Base `Script_DeployAll`; same artifact path as above)

Kept (still active):

- `scripts/foundry/supersim/Script_24_DeploySuperchainBridgeInfra.s.sol`
- `scripts/foundry/supersim/Script_25_ConfigureProtocolDetfBridge.s.sol`
- `scripts/foundry/supersim/Script_26_TestProtocolDetfReserveBridge.s.sol` (extended by `local_testing/supersim/Script_23_ValidateSingleVaultDetfBridge`)
- `scripts/foundry/supersim/SuperSimManifestLib.sol`
- `scripts/foundry/supersim/export_frontend_artifacts.py`
- `scripts/foundry/supersim/deploy_mainnet_bridge_ui.sh`
- `scripts/foundry/supersim/{ethereum,base}/DeploymentBase.sol`
- `scripts/foundry/supersim/{ethereum,base}/Script_DeployProtocolDetfMinimal.s.sol`
- `scripts/foundry/supersim/base/Script_03A_DeployUniswapV2Core.s.sol`
- `scripts/foundry/supersim/base/Script_03B_DeployBalancerV3Core.s.sol`
- `scripts/foundry/supersim/base/Script_03C_DeployAerodromeCore.s.sol`

After Tier 2 removals there is one entrypoint per chain on the SuperSim side (`Script_DeployProtocolDetfMinimal`), which matches the surface the wrapper actually drives.

## Tier 3 — Stale artifact backups under `deployments/` and `frontend/`

These were created when the SuperSim flow was switched to the minimal path on 2026-03-24. They are not consumed by any current script and they bloat the repo.

- `deployments/supersim_sepolia.pre_minimal_backup_20260324_1/`
- `frontend/app/addresses/supersim_sepolia.pre_minimal_backup_20260324_1/`

If they are still wanted as a forensic snapshot, keep them outside the repo (e.g., in cold storage). Otherwise delete.

Also consider:

- `scripts/foundry/supersim/__pycache__/` — Python bytecode cache. Should be `.gitignore`'d rather than committed. If tracked, untrack and remove.

## Tier 4 — Documentation cleanups that should follow the deletions

Not removals, but companion edits so the surviving docs do not reference deleted files:

- `docs/CODEBASE_MAP.md` line 484 currently says *"Run deployment: `scripts/shell/local.sh`"* — update to point at `scripts/shell/local_testing.sh`.
- `docs/SCRIPT_STAGE_RECOMMENDATIONS.md` references the legacy `scripts/foundry/local/` and `local/segmented/` trees and `local_segments.sh`; drop those bullets after Tier 1 deletions.
- `docs/DEPLOYMENT_SCRIPTS_ANALYSIS.md` documents `supersim/{ethereum,base}/Script_DeployAll`; rewrite to describe `Script_DeployProtocolDetfMinimal` instead.
- `docs/BASE_SEPOLIA_PUBLIC_DEPLOYMENT_PLAN.md` references `scripts/foundry/sepolia/Script_04_DeployDEXPackages_BalancerV3.s.sol`; redirect to the `anvil_sepolia/` equivalent.
- `docs/DEPLOYMENT_SCRIPT_INVENTORY.md` lists every removed file; trim the corresponding sections.
- `docs/DEPLOYMENT_READINESS_REPORT.md` and `docs/DEPLOYMENT_INVENTORY_DETAILED.md` already flag these trees as legacy/reserved; light edits to remove the now-deleted file paths.
- `.claude/skills/indexedex-script-orchestration/SKILL.md` (and the `.opencode/` mirror) mentions `supersim/{ethereum,base}/Script_DeployAll.s.sol`; update to `Script_DeployProtocolDetfMinimal.s.sol`.
- Repo-root planning artifacts (`PROMPT.md`, `PRD.md`, `PLAN_supersim_protocol_detf_minimal.md`, `REVIEW_REPORT.md`) reference the deleted scripts. If those documents are still active inputs, update them; if they are completed-task scratch space, move them under `tasks/archive/` so they stop polluting the repo root.

## What we are **not** removing

- `scripts/foundry/anvil_sepolia/Script_06_DeployAerodrome.s.sol` — actively run by `anvil_sepolia/deploy_sepolia.sh` as part of the Sepolia-fork local harness. The inventory describes it as a "compatibility or placeholder" stage, but it is still wired in. Only remove if you also drop Stage 06 from the harness.
- `scripts/foundry/anvil_sepolia/Script_17_*.sol` through `Script_23_*.sol` (WETH/TTC stages) — also wired into `anvil_sepolia/deploy_sepolia.sh` even though the public Sepolia path skips them. They define the "Scenario WETH/TTC" local-rehearsal coverage and are not redundant with anything else in the tree.
- `scripts/foundry/base_main/Script_BaseMain_DeployIndexedex.s.sol` and `scripts/foundry/ethereum_main/Script_DeployRichToken.s.sol` — standalone mainnet helpers. They are not part of the Sepolia flow, but they are the only path to mainnet RICH and the only path to a Base mainnet core deploy. Keep.
- `scripts/foundry/shared/SingleVaultDetfUniswapV4LiquiditySeeder.sol` — imported by `Script_16_DeployProtocolDETF`. Keep.
- `scripts/foundry/local_testing/` — this is the canonical scenario-based test flow. Keep.

## Pre-deletion safety checklist

Before deleting any file in Tier 1 or Tier 2:

1. `forge build` — confirm baseline build is green.
2. `grep -rn "<filename>" --include="*.sol" --include="*.sh" --include="*.py" --include="*.md" .` for each file you plan to delete. Ignore matches under `node_modules/`, `lib/daosys/`, `.claude/skills/`, `tasks/archive/`, `REVIEW_REPORT.md`, `cache_forge/`, `out/`, `deployments/`. If anything else points at the file, treat it as a Tier-4 doc edit before deletion.
3. After deletion, `forge build` again. Any broken import surfaces the missing file by path.
4. Smoke-run the active wrappers in `--dry-run` / simulate mode:
   - `scripts/foundry/public_sepolia/deploy_public_sepolia.sh` without `--broadcast` (will exit early at the broadcast gate, but exercise script discovery).
   - `scripts/foundry/anvil_sepolia/deploy_sepolia.sh --dry-run`.
   - `scripts/foundry/anvil_base_main/deploy_all.sh --dry-run`.
   - `scripts/shell/local_testing.sh foundation --dry-run`.

## Suggested removal order

1. Tier 4 doc edits for files that still mention Tier 1/2 paths so docs don't ship a broken state mid-removal.
2. Tier 1 deletions (legacy `local/`, four shell wrappers, `IndexedexScript.sol`).
3. Run `forge build` + smoke tests.
4. Tier 2 deletions (`scripts/foundry/sepolia/`, dead SuperSim `Script_DeployAll` graph).
5. Run `forge build` + smoke tests again.
6. Tier 3 deletions (artifact backup directories).
7. Final pass on `docs/DEPLOYMENT_SCRIPT_INVENTORY.md`, `DEPLOYMENT_INVENTORY_DETAILED.md`, and `DEPLOYMENT_READINESS_REPORT.md` to drop references to anything just removed.
