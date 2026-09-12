# Robinhood mainnet (4663) — architecture Phases and Stages

**PRD:** [`docs/ANVIL_ROBINHOOD_MAIN_ARCHITECTURE_PHASE_STAGE_PRD.md`](../../../docs/ANVIL_ROBINHOOD_MAIN_ARCHITECTURE_PHASE_STAGE_PRD.md)

**Chain id:** **4663**. Packages only. No test tokens. No SE vault instances. No Protocol DETF instances.

Same Foundry Stages. Two shells plus a gas-quote `simulate`.

| | Value |
|--|--|
| Chain id | **4663** |
| Anvil shell | `scripts/shell/anvil_robinhood_main.sh` — fork 4663, Anvil Dev 0, `--unlocked`, Phase 00 then 01–06 |
| Public shell | `scripts/shell/robinhood_main.sh` — `--sender $DEPLOYER_ADDRESS`, no Phase 00 |
| Anvil node | `--chain-id 4663`. EIP-170 **on**. Never `--disable-code-size-limit` |
| Fork source | `robinhood_mainnet` (public tip; not archive) |
| Artifacts | `deployments/anvil_robinhood_main/phase<PP>_stage<SS>_<slug>.json` |

Each Stage simulates, then broadcasts. Never `--skip-simulation`. `FORCE=1` / `--force` re-runs. Resume: `--from-phase PP --from-stage SS`.

After a pons Family sale, add a **later** Stage that deploys the Protocol DETF instance from that pool’s `PoolKey`. Do not put instances in this catalog.

## Phases

| Phase | Stage | File | What |
|-------|-------|------|------|
| 00 | 01 | `Phase_00_Stage_01_AnvilEnv.s.sol` | Anvil-only: chain 4663, `deal` Dev 0 / Dev 1 if low |
| 01 | 01 | `Phase_01_Stage_01_Permit2.s.sol` | Pin Permit2. Fail if no code |
| 01 | 02 | `Phase_01_Stage_02_Weth.s.sol` | Pin WETH. Fail if no code |
| 01 | 03 | `Phase_01_Stage_03_UniswapV4.s.sol` | Pin live V4 cores. Never deploy V4 |
| 02 | 01 | `Phase_02_Stage_01_Create3Factory.s.sol` | New CREATE3 for this tree |
| 02 | 02 | `Phase_02_Stage_02_DiamondPackageFactory.s.sol` | Diamond Package Factory via CREATE3 |
| 02 | 03 | `Phase_02_Stage_03_HookFactory.s.sol` | Uni V4 Hook Diamond Package Factory |
| 03 | 01 | `Phase_03_Stage_01_CommonFacets.s.sol` | Shared ERC20 / vault / ownable / DiamondCut facets |
| 04 | 01 | `Phase_04_Stage_01_FeeCollectorAndManager.s.sol` | FeeCollector + Manager diamonds, fee defaults |
| 05 | 01 | `Phase_05_Stage_01_SeRateProviderPkg.s.sol` | SE rate-provider DFPkg |
| 05 | 02 | `Phase_05_Stage_02_UniswapV4TwapOracle.s.sol` | TWAP facet + DFPkg + canonical instance + adapter factory |
| 05 | 03 | `Phase_05_Stage_03_UniswapV4StandardExchangePkg.s.sol` | Uni V4 SE DFPkg (`PkgInit.twapOracle` from 05-02) |
| 05 | 05 | `Phase_05_Stage_05_MorphoBlueStandardExchangePkg.s.sol` | Morpho Blue SE DFPkg (no vaults; Morpho is `PkgArgs`) |
| 06 | 01 | `Phase_06_Stage_01_BondNftPkg.s.sol` | Uni V4 Bond NFT DFPkg (R12a) |
| 06 | 02 | `Phase_06_Stage_02_RebasingClaimPkg.s.sol` | Rebasing claim DFPkg |
| 06 | 03 | `Phase_06_Stage_03_CpBufferHookPkg.s.sol` | CP buffer hook DFPkg |
| 06 | 04 | `Phase_06_Stage_04_WeightedBufferHookPkg.s.sol` | Weighted buffer hook DFPkg |
| 06 | 05 | `Phase_06_Stage_05_OrbitalBufferHookPkg.s.sol` | Orbital buffer hook DFPkg |
| 06 | 06 | `Phase_06_Stage_06_CurveQuadBufferHookPkg.s.sol` | Curve Quad buffer hook DFPkg |
| 06 | 07 | `Phase_06_Stage_07_UniswapV4DetfPkg.s.sol` | Unified Uni V4 DETF DFPkg |
| 06 | 10 | `Phase_06_Stage_10_RebasingAwareERC4626Pkg.s.sol` | Rebasing-aware ERC4626 facet + DFPkg; reuses shared ERC20 facet. No vault instance |
| 09 | 01 | `Phase_09_Stage_01_ExportFrontend.s.sol` | Frontend `chain/4663/` export. No txs. Set `FRONTEND_ADDRESS_EXPORT_DIR` to an isolated directory for local release rehearsals. |

Opt-in (not in `all`): TokenStaking DFPkg + `$DTF` instance. Commands: [`TOKEN_STAKING.md`](./TOKEN_STAKING.md).

The rebasing-aware ERC4626 package is included independently in default stage 06-10, the architecture quote, and `rehearse-packages`. Its address is exported as `rebasingAwareErc4626Pkg`. Optional stage 06-08 uses the same enhanced registered package (`indexedex.rebasing-aware-erc4626.sy-se.v1`) with ERC20, ERC4626, Standard Exchange, Standardized Yield, metadata, and sequential quotes. Old two-address ERC4626-only manifests fail enhanced-release freshness.

| Phase | Stage | File | What |
|-------|-------|------|------|
| 06 | 08 | `Phase_06_Stage_08_TokenStakingPkg.s.sol` | TokenStaking + rebasing-aware ERC-4626 DFPkgs via live CREATE3 |
| 08 | 01 | `Phase_08_Stage_01_TokenStakingDtf.s.sol` | `$DTF` staking instance, 7-day duration, owner=`DEPLOYER_ADDRESS`. No `notifyRewardAmount` |
| 08 | 02 | `Phase_08_Stage_02_TokenStakingNotifyRewards.s.sol` | `notifyRewardAmount` of sender `$DTF` balance |

```bash
bash scripts/shell/robinhood_main.sh token-staking
bash scripts/shell/robinhood_main.sh token-staking --broadcast
bash scripts/shell/robinhood_main.sh token-staking-fund
bash scripts/shell/robinhood_main.sh token-staking-fund --broadcast
```

Stage numbers match 46630. V2/V3/V4 SE packages and all four V4 DETF reserve-hook families have current package stages.

Not in this catalog: minter facade, test tokens, old family DETF packages, SE vault instances, Protocol DETF instances.

## Shells

```bash
# Anvil: fork 4663, Dev 0, Phase 00 then architecture catalog
DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  bash scripts/shell/anvil_robinhood_main.sh all --restart-anvil

# Resume after TWAP (example)
bash scripts/shell/anvil_robinhood_main.sh all --from-phase 05 --from-stage 03

# Public 4663 (no Phase 00)
export DEPLOYER_ADDRESS=0x...
bash scripts/shell/robinhood_main.sh all

# Opt-in TokenStaking ($DTF): simulate (add --broadcast to send)
bash scripts/shell/robinhood_main.sh token-staking

# Gas / funding quote (EIP-1559, no broadcast, EIP-170 on)
DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  bash scripts/shell/anvil_robinhood_main.sh simulate --restart-anvil
```

`simulate` is not `all`. Do not run it after a completed staged deploy on the same Anvil (CREATE3 collision).

**Package delta (unified DETF, R12a Bond NFT, optional SE pkgs):** do not re-run Phases 02–04. Follow [`DEPLOY_UNIFIED_DETF_PACKAGES.md`](./DEPLOY_UNIFIED_DETF_PACKAGES.md).

## Opt-in fee-accrual composition and staking migration

The Solidity deployment and migration stages are shared with public mainnet: they accept the configured RPC and signer, validate contract identities/roles, and contain no Anvil detection or local-key restrictions. Fork identity, impersonation and local-only execution checks live in the Anvil shell, not in those stages.

The local `fee-accrual-*` commands use the existing local Anvil instance and reuse the recorded CREATE3 factory, diamond and hook factories, manager, fee collector and staking contract. They do not enter the general runner's node-start/reset path. Public RPCs, RPC redirects, `--force` and `--restart-anvil` are rejected. The existing architecture-only `all` catalog retains its scope.

`fee_accrual_config.example.json` records discovered infrastructure and the confirmed 60% DETF / 20% WETH / 20% DTF weights. **It is an incomplete template, not an executable launch configuration.** Nulls identify values to resolve before execution. The run configuration must pin the registered package addresses, custody decimal offset, creation/opening prices, permissions, funding actor/budgets, first-bond limits and migration limits. The DTF custody product is a separate instance of the fee-free SY/SE rebasing-aware ERC4626 wrapper, with the approved +10 offset (28-decimal shares). The weighted hook normalizes whole-share provider rates across share decimals 6–36 and ordinary pair-token decimals 6–18.

```bash
export RPC_URL=http://127.0.0.1:8545
export FEE_ACCRUAL_CONFIG="$PWD/.scratch/fee-accrual/run.json"
export FEE_ACCRUAL_RUN_DIR="$PWD/.scratch/fee-accrual/deployments"
bash scripts/shell/anvil_robinhood_main.sh fee-accrual-preflight
bash scripts/shell/anvil_robinhood_main.sh fee-accrual-packages --broadcast
# Pin the resulting package addresses in the final config; use a fresh run directory
# when changing its contents. Package source changes likewise invalidate the journal.
bash scripts/shell/anvil_robinhood_main.sh fee-accrual-prepare --broadcast
bash scripts/shell/anvil_robinhood_main.sh fee-accrual-migrate --broadcast
bash scripts/shell/anvil_robinhood_main.sh fee-accrual-verify
```

The package command copies and checks existing core/common-facet/TWAP manifests, builds current artifacts, then runs only 05-01, 05-03, 06-01, 06-02, 06-04, 06-07 and 06-10. It never runs core deployment stages. All signer accounts are impersonated on Anvil; ERC20 funding must already be present. A gas-only ETH top-up is permitted for an empty signer account.

Prepare deploys registered SEs and rate providers, initializes the liquidity SE in 07-04 with both WETH and DTF, then deploys the three-leg weighted reserve and unified `DTF-DETF` and executes the first bond. This seed is required for the WETH route to produce a positive preview during DETF construction. Its actual token inputs are deducted from the configured total bootstrap budgets; it does not increase them. The funding actor receives the seed SE shares. WETH and DTF mint/bond/donation routes are explicit; the burn route outputs DTF through custody. Initial provider rates may be zero before the SEs hold shares; post-bootstrap validation requires positive rates. Bootstrap limits are simulated and checked afterward; the existing `bond` ABI does not accept an atomic minimum-share parameter. Do not describe that script check as an onchain slippage guarantee.

Stage 08-05 deploys the owner-approved standalone `TokenStakingMigrationAdapter` with `new` and constructor arguments, reusing actual DETF and its existing static staking SY. It sets that adapter as the historical staking target while phase remains Staking, or validates an already configured adapter. It exports `phase08_stage05_staking_migration_adapter.json`; the protocol DETF address remains unchanged.

Migration snapshots allocation weights and **the whole actual DTF balance**, then invokes `migrateToClaimVault` in a bounded batch. Each chunk is capped by the remaining staking balance, `maxChunkInput`, and 25% of the weighted hook's current rated DTF reserve. This stays below the hook's 30% swap input limit when the DETF uses its price-gate fallback. The shared stage simulates the complete native call before each broadcast and derives a nonzero minimum. At most `maxChunks` transactions are prepared per invocation; an unfinished migration remains resumable. Rewards and deposits enter the same claim vault backed by static staking SY. Native migration minimums and outputs use SY units. Users call `withdrawClaim` to receive SY, then redeem it through the existing SY for real sDETF; pending rebases and delays before redemption preserve their static ownership. The runner never rescues rewards, donates migration funds, replaces the staking claim-vault package, or calls `completeWrap`. It requires ordinary Wrapped completion with zero remaining DTF and verifies every ordered migration event against its actual adapter target, quote, preceding reserve balance and receipt. The shared runner checks adapter bindings, receipt exhaustion and allowance cleanup. The frontend candidate exports actual DETF, real sDETF, staking SY and migration target separately.

For already-built stages, set `FOUNDRY_OFFLINE=true` to avoid optional external source/trace-label lookups. Local RPC simulation and broadcasting remain enabled; this does not skip transaction simulation.

`fee-accrual-journal.json` binds receipts to the node instance, fork hash, core code, script source and exact config. Prior deployment stages rerun their deterministic checks; recorded bootstrap is verified without a second first bond. Each migration invocation resumes from the live remaining balance and obeys `maxChunks`. An unexplained reserve/principal change stops reconciliation. A reset or configuration/source change requires a fresh run directory and explicit reconciliation of any previous migration history.

Stage JSON files and `phase09_stage02_fee_accrual_frontend_candidate.json` are **candidate exports from Forge simulation** (`receiptVerified=false`). The journal independently confirms submitted transactions. This version does not automatically replace the frontend address bundle or certify browser money paths. The complete three-leg integration, economics/runway, fork migration and browser tests remain release gates in the [deployment plan](../../../docs/FEE_ACCRUAL_DETF_DEPLOYMENT_AND_STAKING_MIGRATION_PLAN.md).
