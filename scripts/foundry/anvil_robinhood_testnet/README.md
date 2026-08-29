# Robinhood Testnet (46630) — Phases and Stages

**PRD:** [`docs/ANVIL_ROBINHOOD_TESTNET_LAUNCH_SCRIPTS_REWRITE_PRD.md`](../../../docs/ANVIL_ROBINHOOD_TESTNET_LAUNCH_SCRIPTS_REWRITE_PRD.md)  
**Plan:** [`docs/ANVIL_ROBINHOOD_TESTNET_LAUNCH_SCRIPTS_REWRITE_IMPLEMENTATION_AND_TEST_PLAN.md`](../../../docs/ANVIL_ROBINHOOD_TESTNET_LAUNCH_SCRIPTS_REWRITE_IMPLEMENTATION_AND_TEST_PLAN.md)

Same Foundry Stages. Two shells.

| | Value |
|--|--|
| Chain id | **46630** |
| Anvil shell | `scripts/shell/anvil_robinhood_testnet.sh` — fork 46630, Anvil Dev 0, `--unlocked`, Phase 00 then 01–09 |
| Public shell | `scripts/shell/robinhood_testnet.sh` — `--sender $DEPLOYER_ADDRESS`, no Phase 00, currently 01–09 |
| Anvil helper | `fresh_deploy.sh` — `--restart-anvil` then the Anvil shell |
| Anvil node | `--chain-id 46630 --disable-code-size-limit --unlocked` |
| Fork source | `robinhood_testnet_alchemy` → fallback `robinhood_testnet` |
| Artifacts | `deployments/anvil_robinhood_testnet/phase<PP>_stage<SS>_<slug>.json` |
| Frontend | `frontend/packages/protocol/src/addresses/chain/46630/` |

Each Stage simulates, then broadcasts. Never `--skip-simulation`. `FORCE=1` / `--force` re-runs. Resume: `--from-phase PP --from-stage SS`.

## Phases

| Phase | Stage | File | What |
|-------|-------|------|------|
| 00 | 01 | `Phase_00_Stage_01_AnvilEnv.s.sol` | Anvil-only: chain 46630, `deal` Dev 0 / Dev 1 if low |
| 01 | 01 | `Phase_01_Stage_01_Permit2.s.sol` | Pin Permit2. Fail if no code |
| 01 | 02 | `Phase_01_Stage_02_Weth.s.sol` | Pin WETH. Fail if no code |
| 01 | 03 | `Phase_01_Stage_03_UniswapV4.s.sol` | Pin live V4 cores. Never deploy V4 |
| 01 | 04 | `Phase_01_Stage_04_UniswapV3.s.sol` | Pin factory if code, else rehearsal `UniswapV3Factory` + `enableFeeAmount(100,1)` |
| 01 | 05 | `Phase_01_Stage_05_MorphoBlue.s.sol` | Pin Morpho if this-chain code, else rehearsal Morpho + IRM + OracleMock. No `createMarket` |
| 02 | 01 | `Phase_02_Stage_01_Create3Factory.s.sol` | New CREATE3 for this tree |
| 02 | 02 | `Phase_02_Stage_02_DiamondPackageFactory.s.sol` | Diamond Package Factory via CREATE3 |
| 02 | 03 | `Phase_02_Stage_03_HookFactory.s.sol` | Uni V4 Hook Diamond Package Factory |
| 03 | 01 | `Phase_03_Stage_01_CommonFacets.s.sol` | One Stage: ERC20, ERC2612, ERC5267, ERC4626, vault facets, MultiStepOwnable, Operable, DiamondCut |
| 04 | 01 | `Phase_04_Stage_01_FeeCollectorAndManager.s.sol` | FeeCollector + Manager facets, packages, diamonds, fee defaults |
| 04 | 02 | `Phase_04_Stage_02_Erc20MinterFacade.s.sol` | Minter facade only |
| 05 | 01 | `Phase_05_Stage_01_SeRateProviderPkg.s.sol` | SE rate-provider DFPkg |
| 05 | 02 | `Phase_05_Stage_02_UniswapV4TwapOracle.s.sol` | Uni V4 TWAP facet + DFPkg + canonical instance + adapter factory |
| 05 | 03 | `Phase_05_Stage_03_UniswapV4StandardExchangePkg.s.sol` | Uni V4 SE DFPkg (`PkgInit.twapOracle` from 05-02) |
| 05 | 04 | `Phase_05_Stage_04_UniswapV3StandardExchangePkg.s.sol` | Uni V3 SE DFPkg (no instances) |
| 05 | 05 | `Phase_05_Stage_05_MorphoBlueStandardExchangePkg.s.sol` | Morpho Blue SE DFPkg (no vaults) |
| 06 | 01 | `Phase_06_Stage_01_BondNftPkg.s.sol` | Bond NFT DFPkg |
| 06 | 02 | `Phase_06_Stage_02_RebasingClaimPkg.s.sol` | Rebasing claim DFPkg |
| 06 | 03 | `Phase_06_Stage_03_CpBufferHookPkg.s.sol` | CP buffer hook DFPkg |
| 06 | 04 | `Phase_06_Stage_04_WeightedBufferHookPkg.s.sol` | Weighted buffer hook DFPkg |
| 06 | 05 | `Phase_06_Stage_05_OrbitalBufferHookPkg.s.sol` | Orbital buffer hook DFPkg |
| 06 | 06 | `Phase_06_Stage_06_CurveQuadBufferHookPkg.s.sol` | Curve Quad buffer hook DFPkg |
| 06 | 07 | `Phase_06_Stage_07_UniswapV4DetfPkg.s.sol` | Unified Uni V4 DETF DFPkg |
| 07 | 01 | `Phase_07_Stage_01_CoreTestTokens.s.sol` | `DTF`, `TTUSDG`, `TTUSDE`, `TTWETH` |
| 07 | 02 | `Phase_07_Stage_02_Mag7TestTokens.s.sol` | Mag7 `TTNVDA`…`TTTSLA` |
| 07 | 03 | `Phase_07_Stage_03_UniV4SeDtfWeth.s.sol` | Uni V4 SE `DTF`/`TTWETH` |
| 07 | 04 | `Phase_07_Stage_04_UniV4SeUsd.s.sol` | Three Uni V4 USD SEs for `TTDOL-Q` |
| 08 | 01 | `Phase_08_Stage_01_FeeDetf.s.sol` | `DTF-DETF` / `DTF-CLAIM` |
| 08 | 02 | `Phase_08_Stage_02_TtDolQ.s.sol` | `TTDOL-Q` |
| 09 | 01 | `Phase_09_Stage_01_ExportFrontend.s.sol` | Frontend `chain/46630/` export. No txs |

## Shells

```bash
# Anvil: fork 46630, Dev 0, Phase 00 then 01–09
bash scripts/foundry/anvil_robinhood_testnet/fresh_deploy.sh
# or, if Anvil is already a 46630 fork on :8545:
bash scripts/shell/anvil_robinhood_testnet.sh all

# Public 46630 (no Phase 00)
export DEPLOYER_ADDRESS=0x...
bash scripts/shell/robinhood_testnet.sh all
```
