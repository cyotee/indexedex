# Migration source-route matrix

This is an implementation coverage index. The historical proof pin is chain4663/block108944663, not current live eligibility or the funded quote snapshot. Read source-manifest.json and recovery-route-disposition.md for conditions, preservation requirements and evidence.

| Category | Units | Surrender | Recovery and condition |
| --- | --- | --- | --- |
| weighted-nft | NFT identity and remaining fixed principal | `surrenderMigrationNft` | WeightedRewards -> WeightedUnstake -> WeightedConvert -> Donate. Retain principal in routine harvests; NFT3 has two separately quoted/funded contributions. |
| earlier-nft | NFT identity and original LP accounting shares | `surrenderMigrationNft` | EarlierClaim -> EarlierConvert -> Donate. Retain principal/NFT; source SE enablement and actual new reward income may be needed. Sale is an explicit separate operation. |
| weighted-liquid | native9 | `surrenderMigrationWeightedLiquid` | WeightedConvert -> Donate. Original wallet, configured complete original and actual selected custody. |
| earlier-liquid | native18 | `surrenderMigrationEarlierLiquid` | EarlierConvert -> Donate. Fixed public reserve swap, not the broken primary-burn path; legacy SE enablement prerequisite. |
| weighted-receipt | eligible original gons; native9 transfer arguments | `surrenderMigrationWeightedReceipt` | WeightedUnstake -> WeightedConvert -> Donate. Synchronize and preserve unsolicited/sub-native gons. |
| earlier-receipt | internal original shares; native18 transfer/redemption arguments | `surrenderMigrationEarlierReceipt` | EarlierStandaloneReceiptRedeem -> EarlierConvert -> Donate. NFT-sale E external shares plus R remainder stay separate from standalone B internal shares; reward-funded redemption needs actual source income. |
| weighted-sy | native9 static SY shares | `surrenderMigrationWeightedSy` | WeightedSyRedeem -> WeightedUnstake -> WeightedConvert -> Donate. Also supports complete/full-remainder TokenStaking preparation certificates; no duplicate economic originals. |
| claim-vault | native19 vault shares | `surrenderMigrationClaimVault` | ClaimVaultRedeem -> WeightedSyRedeem -> WeightedUnstake -> WeightedConvert -> Donate. Actual own-share redemption and measured SY output. |
| dtf-custody-se | native28 shares | `surrenderMigrationDtfCustodySe` | DtfCustodySeRedeem -> Donate. Actual native18 DTF output. |
| weighted-weth-se | native18 shares | `surrenderMigrationHeldSeLp` | WeightedWethSeConvert -> Donate. Conditional actual legacy enablement; preserve unbooked shares. |
| earlier-se | native18 shares | `surrenderMigrationHeldSeLp` | EarlierSeConvert -> Donate. Conditional actual legacy enablement; insufficient native output rejects without confiscation. |
| weighted-lp | native18 physical LP | `surrenderMigrationHeldSeLp` | WeightedLpRedeem -> Donate. Requires real source liquidity authority; current-fee-recipient authorization demonstrated locally, never self-granted by Migration. Fee-minted LP remains unbooked. |
| earlier-lp | native18 physical LP | `surrenderMigrationHeldSeLp` | permanent custody under authenticated immutable source. Owner-only native exits and no admitted parent/collector intake; fee-role change and one-year advance do not grant authority. See recovery-route-disposition.md. |
| token-staking-preparation | raw source weight, not approved-pull ERC20 units | `public source claim then configured SY surrender` | claimed-SY route above. Direct, delegated, wallet-relayed and generic indirect/nonisolated claim effects are authenticated. Historical unavailable trace remains unqueried; operational financial originals require review. |

Every surrender requires the recorded original wallet, matching configured entitlement, Stage2 and actual custody. Recovery does not reprice compensation. Routine NFT harvests preserve principal; maturity does not select withdrawal. Original financial contributions, exclusions, source-role/configuration decisions and public execution approval remain operational inputs.
