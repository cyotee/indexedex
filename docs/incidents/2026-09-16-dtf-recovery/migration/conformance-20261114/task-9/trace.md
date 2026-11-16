# Task 9 source-to-document trace

Date: 2026-11-15. Every SHA-256 below was recomputed from the current file bytes. A required record that cites a missing file, or a digest that was not recomputed, fails this check.

Result: PASS. All 32 required records cite an existing file. Unresolved facts are labeled in the record and still cite the file that shows the limit.

| Required record | Artifact | SHA-256 | Bytes | Use |
| --- | --- | --- | --- | --- |
| configured-wallet and Stage 2 entry | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationWeightedHookTarget.sol` | `e5d34dd8726b31faba071a8b6c264e85a903ef4f6ca8c729f4a26332a78b0e29` | 22719 | surrender common entry; activated gate |
| surrender arguments | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryTarget.sol` | `a7db3e687205d4e38e668e889286c0e847a13b9669fccd6a01a2ae83a138914d` | 27213 | recovery and hook entry signatures |
| unit equation | `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-3/source-observations.json` | `82233f20f3eb4ba21ee927a4f421b75615e57f9ee0f426ad4a6a1cb93b5a465a` | 211316 | fourteen observation equations copied into the spec |
| live remaining-unit read | `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-3/source-observations.json` | `82233f20f3eb4ba21ee927a4f421b75615e57f9ee0f426ad4a6a1cb93b5a465a` | 211316 | remainingUnit and unit-read selectors |
| custody and control transition | `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-6/source-results.json` | `18be4bf6765ca37b902ad85931117b41e50018efbf66218ce31d03e302493054` | 173171 | task 6 custody notes; log lines separated from source lines |
| source and economic identity | `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-3/source-observations.json` | `82233f20f3eb4ba21ee927a4f421b75615e57f9ee0f426ad4a6a1cb93b5a465a` | 211316 | address, category, chain 4663, block 108944663 |
| consumed and remainder accounting | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationWeightedHookTarget.sol` | `e5d34dd8726b31faba071a8b6c264e85a903ef4f6ca8c729f4a26332a78b0e29` | 22719 | consumed and remaining fields in the read bodies |
| rounding | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyNftLib.sol` | `98e01a423cf543c09386fb205c796944c124251f462fbe1de5ca0d333936f045` | 4315 | Math.mulDiv floor; terminal slice keeps remaining credit |
| zero-credit rejection | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol` | `514fb54a14f0fde6d43622694d167f0c36528ae647de85823d8b6ba96881a920` | 25265 | claimed-SY store and NFT component credit |
| callbacks | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationWeightedHookTarget.sol` | `e5d34dd8726b31faba071a8b6c264e85a903ef4f6ca8c729f4a26332a78b0e29` | 22719 | onERC721Received at lines 314-325; bond receiver at lines 35-36 |
| errors | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryTarget.sol` | `a7db3e687205d4e38e668e889286c0e847a13b9669fccd6a01a2ae83a138914d` | 27213 | errors named from the read bodies |
| atomic rollback | `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-6/fork-qa-1.log` | `ec59e2ca0e0f6c936b848ed226571e303cd9a37a7d9fc674b22c3eeca7cee238` | 3884899 | task 6 rejection log lines |
| recovery condition | `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-3/source-observations.json` | `82233f20f3eb4ba21ee927a4f421b75615e57f9ee0f426ad4a6a1cb93b5a465a` | 211316 | observation recovery route and availability limit |
| NFT 3 two originals | `docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` | `93fdd2f045885e00304ec36aa62215127dc1a957f514605129751dd3ae45218e` | 98213 | section 1.7 lines 96-102; two-bond execution unresolved |
| earlier reserved-role conclusion | `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-3/source-observations.json` | `82233f20f3eb4ba21ee927a4f421b75615e57f9ee0f426ad4a6a1cb93b5a465a` | 211316 | earlierReservedIds; task 6 log line 7148 |
| complete and remainder claimed SY | `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-6/source-results.json` | `18be4bf6765ca37b902ad85931117b41e50018efbf66218ce31d03e302493054` | 173171 | token-staking row and claimed-SY store |
| cross-representation exclusion | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol` | `514fb54a14f0fde6d43622694d167f0c36528ae647de85823d8b6ba96881a920` | 25265 | _requireUnallocatedOrigin lines 251-265 |
| registry and CREATE3 wiring | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigration_Component_FactoryService.sol` | `bca895a9e049f8c952bdd8d05b2f3564a957b5d05edba05f268e6da345d829ba` | 1660 | deployFacet lines 15-21 |
| owner roles | `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-4/repair-attempt-1/failures.log` | `b58ca87e782c3f1e9c64279587975a58c689dd70de699449113ddfb043aec131` | 9474596 | unauthorized-pricing pass at line 50147; library unread |
| name-derived artifacts and salts | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigration_Pkg_FactoryService.sol` | `a2695d87fda6ba7424c30674b15f6a200c251e4584544a0a07a18668a5e1b4d9` | 3251 | factory lines 18-60 |
| facet, interface, and cut declarations | `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-4/proxy-census.json` | `5f8816dbce2b2442ba34de5bb6089bfef0cb9afe0b58ae6e045fcd06d21b9a18` | 5737 | census selectors matched to repair happy.log line 6119 |
| real children | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigration_Pkg_FactoryService.sol` | `a2695d87fda6ba7424c30674b15f6a200c251e4584544a0a07a18668a5e1b4d9` | 3251 | package names; deployed addresses unresolved |
| bootstrap receipts | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol` | `514fb54a14f0fde6d43622694d167f0c36528ae647de85823d8b6ba96881a920` | 25265 | bootstrapMigrationReserve lines 305-367; decoded amounts unresolved |
| external capital versus reserve self-mint | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationWeightedHookTarget.sol` | `e5d34dd8726b31faba071a8b6c264e85a903ef4f6ca8c729f4a26332a78b0e29` | 22719 | donateMigrationCapital lines 327-358 and self-mint in bootstrap |
| donation and refund inventories | `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-6/source-results.json` | `18be4bf6765ca37b902ad85931117b41e50018efbf66218ce31d03e302493054` | 173171 | fixture descriptions only; operational inventory unresolved |
| zero issuance on configuration | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol` | `514fb54a14f0fde6d43622694d167f0c36528ae647de85823d8b6ba96881a920` | 25265 | claimed-SY store lines 166-217; other loader deltas unresolved |
| paid first ordinary bond | `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-4/repair-attempt-1/failures.log` | `b58ca87e782c3f1e9c64279587975a58c689dd70de699449113ddfb043aec131` | 9474596 | lines 12374 and 40259; amount unresolved |
| funded compensation supply and gons | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRepo.sol` | `294492b0045f05ef4106d203ba78e55aa534099218f006cb80de44576421d373` | 5536 | _fundBond lines 92-101 plus task 6 assertions |
| post-activation retained routes | `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-4/proxy-census.json` | `5f8816dbce2b2442ba34de5bb6089bfef0cb9afe0b58ae6e045fcd06d21b9a18` | 5737 | two retained census selectors |
| setter and expected-book selectors | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRepo.sol` | `294492b0045f05ef4106d203ba78e55aa534099218f006cb80de44576421d373` | 5536 | book loader lines 83-88; setter 0x43d1e0cc |
| lack of restoration paths | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationDFPkg.sol` | `69ea9feb701ef20eaaea00e57531069bcade94a96668439286a30e1bc316964b` | 22464 | facetCuts lines 230-234 are initial Add cuts; activation lines 267-283 only remove |
| source fingerprint binding | `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-6/fork-qa-1.log` | `ec59e2ca0e0f6c936b848ed226571e303cd9a37a7d9fc674b22c3eeca7cee238` | 3884899 | recomputed fork log digest matches source-results |

## Deliverable hashes

| Deliverable | SHA-256 | Bytes |
| --- | --- | --- |
| `docs/incidents/2026-09-16-dtf-recovery/migration/surrender-spec.md` | `9995fd4dfb9db089883241d24a617aa95caf0c7d964fa66dff38a3d6603091b9` | 62663 |
| `docs/incidents/2026-09-16-dtf-recovery/migration/package-evidence.md` | `cd9e62951d4e635db2bb482908a20b53b0c0b97a3c7f130c8e23f46822723f5f` | 21926 |
| `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-9/traceability-disposition.md` | `afd81c16d9072d0fff03f4dd41a6e3632567aef47363b2e52c8015789669df08` | 1552 |

## Negative row

This row must report a mismatch. It is not a confirmed artifact.

| Check | Path | Expected | Actual | Reported |
| --- | --- | --- | --- | --- |
| mismatched hash | `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-9/negative/proxy-census.one-byte-off.json` | `5f8816dbce2b2442ba34de5bb6089bfef0cb9afe0b58ae6e045fcd06d21b9a18` | `019496421514ea3bff4b26dbe12a58bf658939423a037b66747d39fe5788fadb` | mismatch |

The temp file is a one-byte alteration of a copy. The confirmed census was hashed again afterward and still matches `5f8816dbce2b2442ba34de5bb6089bfef0cb9afe0b58ae6e045fcd06d21b9a18`. Checker reported mismatch: true. Original untouched: true.
