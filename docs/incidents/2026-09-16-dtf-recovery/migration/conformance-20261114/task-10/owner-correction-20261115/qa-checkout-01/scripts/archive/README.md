# scripts/archive

Staging area for deployment scripts that have been removed from active use but are
kept on disk so we can refer back to them while validating the canonical test
scenarios under `scripts/foundry/local_testing/` and the public Sepolia broadcast
path under `scripts/foundry/public_sepolia/`.

Once the canonical scenarios are re-validated end-to-end, this entire directory
can be deleted. Selection criteria and provenance are documented in
[`docs/SCRIPT_REMOVAL_CANDIDATES.md`](../../docs/SCRIPT_REMOVAL_CANDIDATES.md).

Files were moved with `git mv` so history is preserved — `git log --follow
<archived-path>` will show the full history of each script.

## Contents

### Tier 1 — Legacy local bootstrap surface

Replaced by `scripts/foundry/local_testing/` and `scripts/shell/local_testing.sh`.
No live wrapper invokes anything below.

- `foundry/local/` — older monolithic `Demo_*`, `Local_Sepolia_*`, and `Sepolia_*`
  bootstrap scripts.
- `foundry/local/segmented/` — segmented local environment bring-up stages
  (`Local_00_Init.s.sol` through `Local_14_Test_ERC4626.s.sol`).
- `shell/local.sh`, `shell/local_segments.sh`, `shell/local_with_weth.sh`,
  `shell/sepolia.sh` — shell wrappers that drove the legacy `foundry/local/`
  tree.
- `contracts/script/IndexedexScript.sol` — empty abstract base, "Deprecated
  placeholder kept for backwards-compatibility with old file paths."

### Tier 2 — Reserved or unreachable cross-chain orchestrators

- `foundry/sepolia/` — the older single-chain Sepolia demo plus the three
  reserved `Script_DeployAll`-style files that explicitly
  `revert("... reserved for the second implementation pass.")`.
  Superseded by the `scripts/foundry/anvil_sepolia/` stage library and the
  `scripts/foundry/public_sepolia/` cross-chain wrapper. The Sepolia
  `EXECUTION.md` already tells operators not to use this directory for the
  cross-chain demo.
- `foundry/supersim/ethereum/Script_DeployAll.s.sol` and
  `foundry/supersim/base/Script_DeployAll.s.sol` — unreached Solidity
  orchestrators. The SuperSim shell wrapper (`deploy_mainnet_bridge_ui.sh`)
  invokes `Script_DeployProtocolDetfMinimal` instead.
- The helpers imported only by those `Script_DeployAll` files:
  - `foundry/supersim/ethereum/Script_04_UniV2PoolsAndVaults.s.sol`
  - `foundry/supersim/ethereum/Script_05_BalancerPools.s.sol`
  - `foundry/supersim/ethereum/Script_ExportTokenlists.s.sol`
  - `foundry/supersim/base/Script_17_WethTtcPoolsAndVaults.s.sol`
  - `foundry/supersim/base/Script_18_WethTtcBalancerPools.s.sol`
  - `foundry/supersim/base/Script_ExportTokenlists.s.sol`

  The two `Script_ExportTokenlists.s.sol` files are superseded by
  `scripts/foundry/supersim/export_frontend_artifacts.py`, which the live
  wrapper uses.

## What was intentionally NOT archived

Per the removal-candidates report, these stay in their original location:

- `scripts/foundry/anvil_sepolia/Script_06_DeployAerodrome.s.sol` — still
  invoked by `anvil_sepolia/deploy_sepolia.sh` Stage 06.
- `scripts/foundry/anvil_sepolia/Script_17_*.sol` through `Script_23_*.sol`
  (WETH/TTC stages) — still invoked by the local Sepolia harness.
- `scripts/foundry/base_main/`, `scripts/foundry/ethereum_main/` — standalone
  mainnet helpers (RICH token, Base mainnet core).
- `scripts/foundry/shared/SingleVaultDetfUniswapV4LiquiditySeeder.sol` —
  imported by the live Stage 16 Protocol DETF script.
- `scripts/foundry/local_testing/` — the canonical scenario-based local-test
  surface.

## When it is safe to delete this directory

When all of the following are green against the post-archive tree:

1. `forge build` (default profile and `--profile fork`).
2. `scripts/shell/local_testing.sh foundation` and each scenario (`scenario1`,
   `scenario2`, `scenario3`).
3. `scripts/shell/local_testing_supersim.sh scenario4`.
4. `scripts/foundry/anvil_sepolia/deploy_sepolia.sh --dry-run` against a fresh
   local fork.
5. `scripts/foundry/anvil_base_main/deploy_all.sh --dry-run` against a fresh
   local fork.
6. `scripts/foundry/public_sepolia/deploy_public_sepolia.sh` simulate run
   (without `--broadcast`).

After those pass, delete `scripts/archive/` in a single dedicated commit so
the history search is easy if we ever need to dig something out of it.
