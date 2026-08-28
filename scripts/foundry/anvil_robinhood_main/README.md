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
| 06 | 06 | `Phase_06_Stage_06_CurveQuadBufferHookPkg.s.sol` | Curve Quad buffer hook DFPkg |
| 06 | 07 | `Phase_06_Stage_07_UniswapV4DetfPkg.s.sol` | Unified Uni V4 DETF DFPkg |
| 09 | 01 | `Phase_09_Stage_01_ExportFrontend.s.sol` | Frontend `chain/4663/` export. No txs |

Stage numbers match 46630. 05-04 (Uni V3 SE) and 06-05 (Orbital hook) stay unused.

Not in this catalog: minter facade, test tokens, Uni V3 rehearsal or SE package, Orbital hook, old family DETF packages, SE vault instances, Protocol DETF instances.

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

# Gas / funding quote (EIP-1559, no broadcast, EIP-170 on)
DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  bash scripts/shell/anvil_robinhood_main.sh simulate --restart-anvil
```

`simulate` is not `all`. Do not run it after a completed staged deploy on the same Anvil (CREATE3 collision).

**Package delta (unified DETF, R12a Bond NFT, optional SE pkgs):** do not re-run Phases 02–04. Follow [`DEPLOY_UNIFIED_DETF_PACKAGES.md`](./DEPLOY_UNIFIED_DETF_PACKAGES.md).
