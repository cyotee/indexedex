---
name: indexedex-launch-scripts
description: >
  Guides IndexedEx Foundry launch scripts: Phase/Stage file layout, two-shell Anvil vs public
  entrypoints, skip/pin/rehearsal, and Anvil configuration for accurate EIP-1559 gas and
  deployer funding quotes. Use when the user asks about "Phase_00_Stage", "anvil_robinhood",
  "4663", "46630", "simulate architecture", "gas estimate", "funding quote",
  "disable-code-size-limit", "disable-min-priority-fee", launch scripts, robinhood_testnet.sh,
  "platform.json", "tokenlist", or "chain/46630" export. DO NOT use for Foundry tests
  (indexedex-testing), SuperSim/Sepolia bridge rehearsal (indexedex-script-orchestration),
  or generic Anvil node setup (anvil-node).
license: MIT
---

# IndexedEx launch scripts

How to write **Foundry launch Stages** and how to start **Anvil** so a gas / funding quote
matches the live chain. Two jobs, two gold trees. Do not mix their Anvil flags.

**Read first:** `crane-deployment`, `crane-architecture`, this skill, then the matching reference.

| Job | Gold | Anvil |
|-----|------|-------|
| Live gas / funding quote | `scripts/foundry/anvil_robinhood_main/` | EIP-170 **on**; fork-source `baseFee` |
| Local / public staged deploy | `scripts/foundry/anvil_robinhood_testnet/` | Phase/Stage catalog; 46630 may turn EIP-170 **off** |

Generic `anvil-node` is not this law.

## Two Anvil modes (do not mix)

| Mode | EIP-170 | Fees | Forge | Output |
|------|---------|------|-------|--------|
| **Gas / funding quote** | **On.** Never `--disable-code-size-limit` on Anvil **or** `forge script`. | Pin fork-source `baseFee`. `--disable-min-priority-fee`. Restart Anvil so local `baseFee` has not decayed. | EIP-1559 `simulate`. No `--legacy`. No `--gas-price`. Unset `ETH_GAS_PRICE` / `ETH_PRIORITY_GAS_PRICE`. No `--broadcast` by default. | Dry-run **gas limits** × **live** `eth_gasPrice` + `FUND_ETH_BUFFER_BPS` (default 2500 = 25%). Ignore Foundry’s on-screen ETH total. |
| **Dev-complete staged deploy** | Chain-specific. 4663 **on**. 46630 **off** only so rehearsal `UniswapV3Factory` can deploy. | Anvil local. Staged `all` on 4663 may use `--legacy --gas-price 2gwei` as a `feeHistory` workaround. | Per-Stage simulate, then broadcast. Never `--skip-simulation`. | **Not** a live funding quote. |
| **Public** | n/a | Live chain | `--sender $DEPLOYER_ADDRESS`. No `--unlocked`. No Phase 00. | Real fees. |

`--disable-code-size-limit` is a **dev-complete** flag. On a 4663 estimate it hides EIP-170 failures and understates codesize-adjacent gas.

## Structure (Phases / Stages)

Shells choose **which Stages** and **which signer**. Foundry does not encode Anvil vs public as two trees.

| Term | Meaning |
|------|---------|
| **Phase** | Slice of environment init (`00` Anvil-only, `01` external pins/rehearsal, … `09` export) |
| **Stage** | One Foundry unit inside a Phase |
| **File** | `Phase_<PP>_Stage_<SS>_<PascalName>.s.sol` + same-name `.sol` library |
| **JSON** | `deployments/<tree>/phase<PP>_stage<SS>_<slug>.json` |

Thin script: skip-or-execute, serialize JSON, log. Body lives in the library `execute()`.

Two shells, same Foundry Stages:

1. **Anvil:** fork that chain, Dev 0, `--unlocked`, Phase 00 then 01–N.
2. **Public:** `DEPLOYER_ADDRESS` (cast wallet). No Phase 00.

Do not invent Stages. If a Stage is missing from the tree’s PRD **and** plan, stop and amend the PRD.

Full layout, skip/pin/rehearsal, catalog: [references/phase-stage-structure.md](references/phase-stage-structure.md).

## Gas quote (4663 gold)

```bash
DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  bash scripts/shell/anvil_robinhood_main.sh simulate --restart-anvil
```

That path is `deploy_all.sh`: `launch_anvil` (no codesize cheat), `prepare_simulate_fees`,
`Script_SimulateArchitecture.s.sol` (one `startBroadcast` window, no broadcast),
`quote_simulate_funding` from `broadcast/…/dry-run/run-latest.json`.

`simulate` is **not** `all`. Do not run it after a completed staged deploy on the same Anvil
(CREATE3 / CREATE2 collision).

Procedure: [references/anvil-gas-estimate.md](references/anvil-gas-estimate.md).

## Dev-complete Anvil (46630 gold)

```bash
bash scripts/shell/anvil_robinhood_testnet.sh all
# public (no Phase 00):
export DEPLOYER_ADDRESS=0x...
bash scripts/shell/robinhood_testnet.sh all
```

`--chain-id 46630 --disable-code-size-limit --unlocked`. Forge also gets
`--disable-code-size-limit --non-interactive`. That run is a local lab, not a funding quote.

When EIP-170 may be off: [references/anvil-dev-complete.md](references/anvil-dev-complete.md).

## Progressive disclosure

| Reference | Load when |
|-----------|-----------|
| [references/phase-stage-structure.md](references/phase-stage-structure.md) | New Stage, rename, skip keys, shells, JSON |
| [references/frontend-export.md](references/frontend-export.md) | Stage JSON keys, `platform.json`, tokenlists, UI consumers |
| [references/anvil-gas-estimate.md](references/anvil-gas-estimate.md) | `simulate`, gas estimate, funding quote, 4663 Anvil flags |
| [references/anvil-dev-complete.md](references/anvil-dev-complete.md) | 46630 Anvil, `--disable-code-size-limit`, staged `all` |

## Constraints (do not violate)

- Never `new` facets or DFPkgs. Vault/DETF packages: manager / vault registry. `PkgInit` / `PkgArgs` on the **interface**.
- `new Morpho` / `new UniswapV3Factory` only in **Phase 01 rehearsal** Stages.
- Pin Stages (Permit2, WETH, Uni V4) **fail** if the pin has no code. Never deploy those.
- Skip: all catalog skip keys in JSON are non-zero with `code.length > 0`, unless `FORCE=1`. Skipped Stage still rewrites JSON.
- Snapshot `FORCE` in `_loadConfig`. Do not re-read process env on every skip check (parallel tests share `FORCE`).
- Never `--skip-simulation`. Never `via_ir`. DETF **role names** only (`rateAsset`, `pairToken`, `underlyingVault`, `detfToken`, `rebasingClaimToken`).
- Do not treat Foundry’s simulated ETH cost as the deployer fund amount.
- Do not copy 46630 `--disable-code-size-limit` onto a 4663 gas quote.
- Do not resurrect a second **deploy** orchestrator (`Script_SimulateLaunch`, `deploy_all.sh` on 46630). Optional `simulate` may compose library `execute()` calls for a quote only.
- Do not edit `anvil_robinhood_main`, `anvil_robinhood_fee_detf`, or `chain/4663` unless the task names that tree.
- Stage numbers `08` / `09` are decimal: `printf '%02d' "$((10#$n))"`, never `printf '%02d' 08`.

## See also

- `skill:crane-deployment`: CREATE3 / DFPkg / FactoryService
- `skill:indexedex-testing`: tests, not launch shells
- `skill:indexedex-script-orchestration`: SuperSim / Sepolia bridge wrappers only
- `skill:indexedex-uniswap-v4-hook-packages`: hook DFPkg deploy path used by Phase 02/06
- PRD (46630 lab): `docs/ANVIL_ROBINHOOD_TESTNET_LAUNCH_SCRIPTS_REWRITE_PRD.md`
- PRD (4663 architecture): `docs/ANVIL_ROBINHOOD_MAIN_ARCHITECTURE_PHASE_STAGE_PRD.md`
- Plan: `docs/ANVIL_ROBINHOOD_TESTNET_LAUNCH_SCRIPTS_REWRITE_IMPLEMENTATION_AND_TEST_PLAN.md`
- 4663 README: `scripts/foundry/anvil_robinhood_main/README.md`
