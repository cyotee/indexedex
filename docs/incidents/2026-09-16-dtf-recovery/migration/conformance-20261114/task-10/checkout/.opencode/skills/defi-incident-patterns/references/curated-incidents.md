# Curated DeFiHackLabs incidents (≥25)

**Contents**

- How to use
- Submodule init
- Incident table (paths under `lib/DeFiHackLabs/`)

## How to use

1. Read root-cause one-liner and catalog IDs.
2. Implement **hermetic** production-path tests (not fork profit asserts).
3. Optionally open the POC only for attack-flow intuition.

**Relevance:** High = SE/DETF/vault/diamond-adjacent; Med = related middleware/AMM; Low = peripheral (bridge/AA) study only.

## Submodule init

```bash
git submodule update --init lib/DeFiHackLabs
```

If a path is missing, re-init the submodule; do not invent alternate paths.

## Incident table

| # | Path (under `lib/DeFiHackLabs/`) | Root cause (one-liner) | Catalog | Relevance |
|---|----------------------------------|------------------------|---------|-----------|
| 1 | `src/test/2026-06/Vault4626_exp.sol` | `totalAssets` quotes non-asset WETH; redeem transfers it | A, K | High |
| 2 | `src/test/2026-04/ThetanutsVaultShareRounding_exp.sol` | Residual WBTC with zero totalSupply; first minter drains | A0 | High |
| 3 | `src/test/2026-06/Thetanuts_exp.sol` | Related Thetanuts vault share / residual inventory class | A0 | High |
| 4 | `src/test/2026-06/ThetanutsFi_exp.sol` | Related ThetanutsFi vault accounting | A0, K | High |
| 5 | `src/test/2026-07/ExchangeIssuance_exp.sol` | Quote–settle TOCTOU via malicious SetToken / pre-issue hook | N1, composition | High |
| 6 | `src/test/2026-08/AIC_exp.sol` | FoT surplus + public pair `skim()` drain | L1, L2 | High |
| 7 | `src/test/2026-06/LixirPermitDrain_exp.sol` | Permit accepts dummy sig if ecrecover ≠ 0 | O1 | High |
| 8 | `src/test/2026-07/UnprotectedArbBot_exp.sol` | Public arbitrary call + pre-granted WETH allowance | M1, M3 | High |
| 9 | `src/test/2026-06/AmbientCrocSwapDex_exp.sol` | Native surplus accounting extraction | K, L | Med |
| 10 | `src/test/2026-07/CrowdRingCircle_exp.sol` | Burn-from-pair + sync reserve manip | L2, L3 | High |
| 11 | `src/test/2026-07/RWT_exp.sol` | Deflationary burn-from-pair price manip | L2, L3, B | High |
| 12 | `src/test/2026-07/SummerFi_exp.sol` | NAV inflation via depegged component (xUSD class) | A, K, B | High |
| 13 | `src/test/2026-06/WHALE_exp.sol` | Transfer accounting / reserve desync | K, L | High |
| 14 | `src/test/2026-06/DIP_exp.sol` | Fee-on-transfer reserve manipulation | L2 | High |
| 15 | `src/test/2026-06/OceanBPoolSideStaking_exp.sol` | BPool join/exit math + side-staking gulp accounting | L, K | Med |
| 16 | `src/test/2026-07/LienFinance_exp.sol` | Permissionless bond registration / payoff mispricing | D, N | Med |
| 17 | `src/test/2026-07/ProjektRewardVault_exp.sol` | Permissionless purchase tracking self-deal | D, reward | Med |
| 18 | `src/test/2026-07/ProToken_exp.sol` | Reward-on-transfer self-dealing winner drain | D, reward | Med |
| 19 | `src/test/2026-07/CompoundProvider_exp.sol` | Allowance sweep / missing access control | M3, F | High |
| 20 | `src/test/2026-07/PerpetualProtocol_exp.sol` | Access control / missing permission check | F | Med |
| 21 | `src/test/2026-07/MOKE_exp.sol` | Unprotected claim drained via EIP-7702 self-delegation | D, F | Low–Med |
| 22 | `src/test/2026-07/Sodium_exp.sol` | ERC-4337 session-key validation bypass | O, AA | Low |
| 23 | `src/test/2026-07/LumiFinance_exp.sol` | ERC-4337 validation-phase paymaster approval | O, AA | Low |
| 24 | `src/test/2026-08/Atomic_exp.sol` | Flash-loan price oracle manip of lending collateral | B | High |
| 25 | `src/test/2026-08/UnistreetLaunchpad_exp.sol` | Arbitrary call injection via unvalidated launch forward | M1, M2 | High |
| 26 | `src/test/2026-08/LpdFi_exp.sol` | Spot price manip + issue-boundary interest | B, L3 | High |
| 27 | `src/test/2026-04/SingularityDynaVault_exp.sol` | Dynamic vault accounting / share path | A, K | High |
| 28 | `src/test/2026-04/RWAVault_exp.sol` | RWA vault share / asset path abuse | A, K | High |
| 29 | `src/test/2026-04/SquidMulticallAllowanceDrain_exp.sol` | Multicall + allowance drain pattern | M1, M3 | High |
| 30 | `src/test/2026-05/Ekubo_exp.sol` | DEX / concentrated liquidity edge exploit class | B, L | Med |
| 31 | `src/test/2026-05/JoeAgent_exp.sol` | Reentrancy in removeLiquidityViaContract | C | High |
| 32 | `src/test/2026-05/LegendaryMoneyMonNft_exp.sol` | ecrecover address(0) signature bypass | O1 | High |
| 33 | `src/test/2026-05/AROS_exp.sol` | Signature replay | O2 | High |
| 34 | `src/test/2024-06/UwuLend_First_exp.sol` | First-deposit / lending empty-market class | A0, A | High |
| 35 | `src/test/2023-10/WiseLending_exp.sol` | Lending accounting / inflation-related class | A, K | High |
| 36 | `src/test/2021-10/Cream_2_exp.sol` | Classic lending / oracle-related incident study | B | Med |
| 37 | `src/test/2021-10/IndexedFinance_exp.sol` | Index / multi-asset composition study | N, composition | High |
| 38 | `src/test/2022-11/DFX_exp.sol` | Classic reentrancy (DEX pool) | C | High |
| 39 | `src/test/2026-03/WhalebitOracleManipulation_exp.sol` | Explicit oracle manipulation | B | High |
| 40 | `src/test/2026-03/Venus_THE_exp.sol` | Lending / market oracle-adjacent | B | Med |
| 41 | `academy/solidity/02_first_deposit/en/readme.md` | CompoundV2 first-deposit exchange-rate donation lesson | A0, A1 | High |
| 42 | `academy/onchain_debug/03_write_your_own_poc/en/readme.md` | Oracle manip PoC methodology | B | Med |
| 43 | `academy/onchain_debug/06_write_your_own_poc/en/readme.md` | Reentrancy classes + DFX-style PoC | C | Med |
| 44 | `academy/solidity/01_audit/en/readme.md` | Audit methodology / mental model | (process) | Low |

**Count:** 44 curated rows (≥25 required). Prefer High-relevance rows for SE/DETF work.
