# Deployment Readiness Report — Sepolia + Battlechain

Date: 2026-06-04
Author: review pass against current `scripts/foundry/` tree

## TL;DR

- The **public Sepolia path is the only sanctioned deployment surface** that is wired end-to-end today (Ethereum Sepolia + Base Sepolia). It lives under `scripts/foundry/public_sepolia/` and is driven by `deploy_public_sepolia.sh`.
- The existing on-disk artifacts in `deployments/public_sepolia/` are from **2026-03-31** and are missing the Stage 24 (`24_superchain_bridge.json`) outputs on both chains. Treat the prior run as **partial / stale** and plan to redeploy from clean directories.
- The local SuperSim rehearsal artifacts in `deployments/public_sepolia_supersim/` are partial (Ethereum stopped at Stage 16, Base only got Stage 2A wrappers, no Stage 24 anywhere). A full local rehearsal against forked Sepolia + Base Sepolia is the right pre-flight gate before broadcasting publicly.
- There is **no Battlechain wiring in this repo today**: no `battlechain-lib` dependency, no `BCScript` usage, no `chainId 627` references, no agreement / attack-mode plumbing, no Battlechain RPC alias in `foundry.toml`. Battlechain is a follow-up implementation, not a switch-flip on the existing scripts.

## 1. What the deployment surface looks like today

### 1.1 Active surfaces

| Surface | Path | Status |
| --- | --- | --- |
| Public Sepolia (Eth Sepolia + Base Sepolia) | `scripts/foundry/public_sepolia/` | Active, drives `deploy_public_sepolia.sh` and the manual stage list in `EXECUTION.md` |
| Local Sepolia (Anvil fork) | `scripts/foundry/anvil_sepolia/` | Active stage library reused by public Sepolia |
| Local Base (Anvil fork) | `scripts/foundry/anvil_base_main/` | Active stage library reused by public Sepolia and SuperSim |
| Local two-chain SuperSim | `scripts/foundry/supersim/` | Local rehearsal harness, also owns Stage 24 / 25 / 26 bridge scripts |
| Standalone mainnet `RICH` | `scripts/foundry/ethereum_main/Script_DeployRichToken.s.sol` | Standalone helper, not part of Sepolia flow |
| Standalone Base mainnet | `scripts/foundry/base_main/Script_BaseMain_DeployIndexedex.s.sol` | Standalone helper, not part of Sepolia flow |

### 1.2 Disabled / reserved surfaces

The following `Script_DeployAll` entrypoints exist but explicitly `revert(...)` and must not be used:

- `scripts/foundry/sepolia/Script_DeploySepoliaEnvironment.s.sol`
- `scripts/foundry/sepolia/ethereum/Script_DeployAll.s.sol`
- `scripts/foundry/sepolia/base/Script_DeployAll.s.sol`

`scripts/foundry/sepolia/deploy_sepolia.sh` is the older single-chain Sepolia demo path. Per `docs/DEPLOYMENT_SCRIPT_INVENTORY.md` and `EXECUTION.md`, do not use it for the cross-chain demo.

### 1.3 Legacy

`scripts/foundry/local/` and `scripts/foundry/local/segmented/` are legacy bootstrap flows kept for reference. Skip for this deployment pass.

## 2. Public Sepolia flow (Ethereum Sepolia + Base Sepolia)

### 2.1 Wrapper

`scripts/foundry/public_sepolia/deploy_public_sepolia.sh`:

1. Ethereum Sepolia core deploy via `public_sepolia/ethereum/Script_DeployAll` with `PUBLIC_SEPOLIA_SKIP_STAGE16=true`.
2. Base Sepolia bridge-token wrapper creation (`base/Script_05_CreateBridgeTokens.s.sol`).
3. Manual checkpoint #1 (wrapper verification).
4. Ethereum-side token bridging (`ethereum/Script_17_BridgeTokensToBase.s.sol`).
5. Manual checkpoint #2 (bridged balance verification on Base Sepolia).
6. Base Sepolia core deploy via `public_sepolia/base/Script_DeployAll` with Stage 16 deferred.
7. Stage 24 bridge infra on both chains (`supersim/Script_24_DeploySuperchainBridgeInfra.s.sol`).
8. Stage 16 Protocol DETF on both chains (now that bridge infra exists).
9. Stage 25 Protocol DETF bridge config on both chains (`supersim/Script_25_ConfigureProtocolDetfBridge.s.sol`).
10. Generates `deployment_summary.json` for each chain and exports frontend artifacts.

### 2.2 Required env

| Variable | Required | Default | Notes |
| --- | --- | --- | --- |
| `DEPLOYER_ADDRESS` | yes | — | Used as `--sender` and threaded into Solidity via `SENDER` |
| `ETHEREUM_SEPOLIA_RPC_URL` | no | `sepolia_alchemy` alias | Foundry RPC alias resolved from `foundry.toml` |
| `BASE_SEPOLIA_RPC_URL` | no | `base_sepolia_alchemy` alias | Foundry RPC alias resolved from `foundry.toml` |
| `PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR` | no | `deployments/public_sepolia/ethereum` | |
| `PUBLIC_SEPOLIA_BASE_OUT_DIR` | no | `deployments/public_sepolia/base` | |
| `PUBLIC_SEPOLIA_SHARED_OUT_DIR` | no | `deployments/public_sepolia/shared` | |
| `PUBLIC_SEPOLIA_FRONTEND_ARTIFACTS_DIR` | no | `frontend/app/addresses/public_sepolia` | |
| `PUBLIC_SEPOLIA_SKIP_STAGE16` | injected by wrapper | `true` for Stage 1/3 | Re-enabled before Stage 5A/5B |
| `PUBLIC_SEPOLIA_SKIP_CHECKPOINTS` | no | `0` | Set to `1` only after manual verification |
| `ALCHEMY_KEY` | yes (when using default aliases) | — | Required by `foundry.toml` RPC interpolation |

### 2.3 Signer assumption

The wrapper passes `--sender $DEPLOYER_ADDRESS --unlocked`. On public Sepolia this only works if your Foundry signer setup actually backs that address (cast keystore, env-based signer, hardware wallet, or a local-RPC impersonation in a forked-Sepolia rehearsal). The wrapper **does not** know how you sign — picking `--sender` does not imply a signer is available. See the Sender vs signer note in `EXECUTION.md` and in `.claude/skills/indexedex-script-orchestration/SKILL.md`.

For a real public Sepolia broadcast we will need either:

- a `cast wallet import ...` keystore account that resolves to `$DEPLOYER_ADDRESS`, or
- an explicit `PRIVATE_KEY` plus `--private-key` switch in the wrapper (currently the wrapper does **not** forward a private key, so a keystore is the simpler path), or
- a remote signer configured for that address.

### 2.4 Funded deployer requirement

The same `$DEPLOYER_ADDRESS` must have ETH on **both** Ethereum Sepolia and Base Sepolia before broadcast. The Ethereum side also performs L1→L2 bridges (`Script_17_BridgeTokensToBase.s.sol`) using the Base Sepolia L1 Standard Bridge `0xfd0Bf71F60660E2f608ed56e1659C450eB113120`.

### 2.5 On-disk artifact state

`deployments/public_sepolia/`:

- `ethereum/` and `base/` have full Stage 01–16 artifacts plus `deployment_summary.json` (timestamps 2026-03-31).
- `ethereum/24_superchain_bridge.json` and `base/24_superchain_bridge.json` are **not present**. Either the run stopped early or the Stage 24 outputs were lost. In any case the registry / relayer state cannot be re-derived from the current files.
- `shared/` is empty.
- Frontend artifacts in `frontend/app/addresses/public_sepolia/` likely match the same partial run.

Recommendation: **rerun from clean output directories**, do not try to `--resume` against this set. Several substantive contract changes have landed since 2026-03-31 (buffer pool refactor, exchange route fixes, etc.), so the chain-side bytecode may not match local bytecode anyway.

`deployments/public_sepolia_supersim/`:

- `ethereum/` ran through Stage 16 and stopped (no Stage 24).
- `base/` only has `05_bridge_tokens.json` (Stage 2A). No core Base deployment, no Stage 24.

The local rehearsal was never finished end-to-end. We need a clean rehearsal pass before we trust a public broadcast.

## 3. Pre-Sepolia checklist

Run in order. None of these are skippable.

1. **Code freeze sanity**:
   - Working tree is dirty (`StandardExchangeBufferHookTarget.sol`, two test files, one plan doc). Resolve / commit before any broadcast so the deployed bytecode is reproducible from a known commit.
   - 52 unpushed commits on `main` vs `origin/main`. Confirm intent before broadcasting from an unpushed local revision.
2. **Build + test green**:
   - `forge build --sizes` and `forge test` (spec). Spec test runtime is non-trivial; budget for it.
   - Fork tests (`forge test --profile fork`) optional but desirable since they exercise live Base mainnet wiring.
3. **Local rehearsal against forked Sepolia + Base Sepolia via SuperSim**:
   - Follow `scripts/foundry/public_sepolia/EXECUTION.md` "SuperSim Testing" section.
   - Write to `deployments/public_sepolia_supersim/` and `frontend/app/addresses/supersim_sepolia/`.
   - Drive the full wrapper to completion, including Stages 24, 16-after-24, and 25.
   - Verify `24_superchain_bridge.json` and `25_*` artifacts land on **both** chains.
   - If Stage 2B causes the Base anvil fork to crash, use `scripts/foundry/public_sepolia/finalize_bridge_tokens_on_base.sh` per `EXECUTION.md`.
4. **Frontend smoke**:
   - Frontend can load `frontend/app/addresses/public_sepolia_supersim/` via the deployment-environment toggle (see `.claude/skills/indexedex-ui-refactor/SKILL.md` for the toggle wiring).
   - Confirm Sepolia → Base bridge UX surfaces still operate against the freshly exported artifacts.
5. **Signer + funding**:
   - `cast wallet import ...` (or another supported signer flow) for the intended `$DEPLOYER_ADDRESS`.
   - Confirm balance on both Ethereum Sepolia and Base Sepolia. The Stage 17 bridge transfers and pool seeds eat noticeably more ETH than a typical single-chain demo run.
   - Ensure `ALCHEMY_KEY` (or whichever provider key the RPC alias resolves) is exported in the deployment shell.
6. **Manifest hygiene**:
   - Move existing `deployments/public_sepolia/` content out of the way (e.g. `deployments/public_sepolia.20260331.bak/`) so the next run writes to a clean slate. Do not delete blindly: the existing artifacts may still be needed for forensic comparison.
7. **Run the wrapper**:
   ```bash
   DEPLOYER_ADDRESS=0x... \
   scripts/foundry/public_sepolia/deploy_public_sepolia.sh --broadcast -vvvv
   ```
   Drive both manual checkpoints in person; do not pre-set `PUBLIC_SEPOLIA_SKIP_CHECKPOINTS=1` on the first real broadcast.
8. **Post-broadcast**:
   - Verify presence of all expected files in `deployments/public_sepolia/ethereum/` and `deployments/public_sepolia/base/`, especially `24_superchain_bridge.json` and `deployment_summary.json`.
   - Verify `frontend/app/addresses/public_sepolia/` is updated.
   - Commit (or tag) the deployments directory so the broadcast is traceable from git.

## 4. Battlechain readiness

Today the repo has **zero Battlechain wiring**:

- No `battlechain-lib` dependency, no remapping for `battlechain-lib/`.
- No `BCScript`, no `bcDeployCreate*`, no `requestAttackMode`, no agreement plumbing.
- No `chainId 627` reference, no `https://testnet.battlechain.com` RPC alias in `foundry.toml`.
- No Battlechain target subdirectory under `scripts/foundry/`.
- No Battlechain documentation under `docs/` (only the three `battlechain-*` skills under `.claude/skills/`).

To make the existing protocol Battlechain-ready we need at minimum:

1. **Dependency + config**:
   - `forge install cyfrin/battlechain-lib` and add `"battlechain-lib/=lib/battlechain-lib/src/"` to `foundry.toml` remappings.
   - Add a `battlechain_testnet` RPC alias to `[rpc_endpoints]` pointing at `https://testnet.battlechain.com`.
   - Add a `BATTLECHAIN_TESTNET` network constant under `lib/daosys/lib/crane/contracts/constants/networks/` (chainId 627) if we will reference it from Solidity scripts. Alternatively, gate behavior off `block.chainid == 627` in a small adapter to avoid touching Crane.
2. **Script surface decision** (open):
   - Option A — **fork the public Sepolia flow** into `scripts/foundry/battlechain/` and replace the Optimism-mintable bridge step with whatever bridging is appropriate (likely none, since Battlechain is a single-chain pre-mainnet stage).
   - Option B — **reuse the local anvil Base flow** (`anvil_base_main/`) verbatim against the Battlechain RPC, drop the cross-chain bridge stages entirely, and only deploy what corresponds to one chain. This is closer to how Battlechain is normally used.
   - Option B is likely correct because Battlechain is a single-chain stage. The Stage 24/25 bridge plumbing would have nothing to talk to and should be omitted on Battlechain.
3. **BCScript orchestration**:
   - A new `scripts/foundry/battlechain/Script_DeployAll.s.sol` should extend `BCScript`, deploy via `bcDeployCreate2(...)` or `bcDeployCreate3(...)`, call `createAndAdoptAgreement(...)`, and `requestAttackMode(agreement)` on the testnet path.
   - Because the project deploys hundreds of contracts via Crane factories and Diamond packages, we will need to either (a) wrap each create with `bcDeployCreate*` (intrusive), or (b) deploy the Crane factories themselves with `bcDeployCreate*` and let the rest run through the existing factory plumbing — and accept that the inner contracts are not directly tracked by the Battlechain agreement.
   - Decision needed on whether Battlechain's `getDeployedContracts()` needs to enumerate every diamond/facet/proxy, or whether registering the top-level entrypoints (`IndexedexManager`, `FeeCollector`, `ProtocolDETF`, registries) is sufficient.
4. **Broadcast specifics**:
   - All `forge script` invocations on Battlechain must use `--skip-simulation` per the Battlechain workflow.
   - Plan for `-g 300` / fallback `-g 200` / `-g 150` if gas-limit issues appear.
   - Use a `cast wallet import battlechain --interactive` keystore identity, not a plaintext key.
5. **Verification**:
   - Wire a `bc-verify-broadcast`-style script for post-deploy verification against `https://block-explorer-api.testnet.battlechain.com/api`.
6. **Lifecycle promotion**:
   - Document who calls `requestUnderAttack` / `approveAttack` / `promote` and when. None of this exists in the repo today.

Net: **Battlechain deployment is a green-field implementation pass**, not a configuration toggle. It should be planned in its own dedicated PRD/plan after the public Sepolia broadcast is on chain.

## 5. Blockers and risks (ordered)

1. **Dirty working tree + 52 unpushed commits** — must be resolved before any deterministic broadcast.
2. **Existing `deployments/public_sepolia/` is partial** — missing Stage 24, so cannot serve as a continuation point.
3. **No completed SuperSim rehearsal** of the post-March script changes — risk of broadcast-time stalls on Sepolia.
4. **Signer flow not pre-configured** — wrapper assumes `--sender ... --unlocked`, which on a public RPC only works if you have a Foundry signer wired for that address.
5. **`ALCHEMY_KEY` must be set in the deployment shell** — failure mode is the RPC alias resolving to a URL with an empty key segment.
6. **Battlechain wiring is absent** — needs a separate implementation plan, dependency install, RPC alias, BCScript-based entrypoint, agreement creation, and post-deploy verification flow.

## 6. Recommended sequence

1. Clean tree (commit/stash), confirm 52 ahead-of-origin commits are intentional, push or rebase as needed.
2. `forge build` + `forge test` (spec) green on the final HEAD.
3. SuperSim end-to-end rehearsal against forked Sepolia + Base Sepolia, with full Stages 1 → 25 producing artifacts.
4. Frontend smoke against the rehearsal artifacts.
5. Move-aside the stale `deployments/public_sepolia/` directory.
6. Broadcast public Sepolia via `deploy_public_sepolia.sh --broadcast` with a real signer and adequate balance on both chains.
7. Commit the new `deployments/public_sepolia/` artifacts and `frontend/app/addresses/public_sepolia/` for traceability.
8. Open a dedicated Battlechain implementation plan: dependency install, `scripts/foundry/battlechain/` surface, BCScript-based entrypoint, agreement adoption, attack-mode request, verifier wiring.
9. Deploy on Battlechain testnet under that plan, drive through `requestAttackMode` → `approveAttack` → eventual `promote` once stress testing is satisfied.
10. Only after Battlechain promotion is complete, plan the corresponding mainnet broadcasts.

## 7. Open questions

- Does the broadcast identity already exist as a keystore account, or do we need to provision one before the next session?
- Is the published Alchemy key the one we want associated with the public broadcast, or do we need a separate dedicated key for the deployment shell?
- For Battlechain, do we want a single-chain Base-equivalent deployment (no bridge stages) or a parallel cross-chain story (which Battlechain does not currently support natively)?
- For Battlechain agreement scope, which top-level contracts should be registered with `createAndAdoptAgreement(...)` — only `IndexedexManager` + `FeeCollector` + `ProtocolDETF`, or also the registries, the bridge relayer, and every strategy/Seigniorage DETF?

## 8. References

- `scripts/foundry/public_sepolia/deploy_public_sepolia.sh`
- `scripts/foundry/public_sepolia/EXECUTION.md`
- `scripts/foundry/public_sepolia/{ethereum,base}/Script_DeployAll.s.sol`
- `scripts/foundry/anvil_sepolia/DeploymentBase.sol`
- `scripts/foundry/anvil_base_main/DeploymentBase.sol`
- `scripts/foundry/supersim/Script_24_DeploySuperchainBridgeInfra.s.sol`
- `scripts/foundry/supersim/Script_25_ConfigureProtocolDetfBridge.s.sol`
- `docs/DEPLOYMENT_SCRIPT_INVENTORY.md`
- `docs/DEPLOYMENT_SCRIPTS_ANALYSIS.md`
- `docs/SCRIPT_STAGE_RECOMMENDATIONS.md`
- `docs/BASE_SEPOLIA_PUBLIC_DEPLOYMENT_PLAN.md`
- `.claude/skills/indexedex-script-orchestration/SKILL.md`
- `.claude/skills/battlechain-dev-workflow/SKILL.md`
- `.claude/skills/battlechain-safe-harbor/SKILL.md`
- `.claude/skills/battlechain-ai-tooling/SKILL.md`
