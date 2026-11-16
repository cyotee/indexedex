# Twelve-property closure matrix

This matrix describes the frozen r2 candidate. Final commands, exits, seeds,
selected calls and retained-state counters are in `execution-results.json`.
The original producer and independent reports remain immutable; their smaller
coverage and initial-only reward qualifications are not retroactively changed.

## Source abbreviations

Infrastructure prefix:
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/invariant/`.

- N: `MigrationNativeHandler.sol`; B: `MigrationNativeLedger.sol`.
- L: `MigrationLegacyHandler.sol`; LC: `MigrationLegacyClaimHandler.sol`;
  R: `MigrationLegacyRecoveryHandler.sol`.
- U: `MigrationSourceUnitsHandler.sol`; UB: `MigrationSourceUnitsLedger.sol`;
  UR: `MigrationSourceUnitsRecoveryHandler.sol`;
  UF: `TestBase_MigrationSourceUnits.sol`.
- NS: `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/invariant/MigrationNativeInvariant.t.sol`.
- LS: `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/invariant/MigrationLegacyInvariant.t.sol`.
- US: `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/invariant/MigrationSourceUnitsInvariant.t.sol`.

`source-locators.json` binds complete paths and declaration lines to the
lossless candidate. Every action checks the applicable complete ledger;
the four discovered invariant functions repeat those assertions.

| Plan property | Independent expected state | Actual mandatory witnesses and stateful actions | Scope |
| --- | --- | --- | --- |
| 1. Wallet-bound credit conserves Q/C | L:99,260; U:86; UB:185 maintain input Q0/C0, remaining Q/C, delivered credit, actual holdings and unbooked floors separately. Partial floor uses prior ghost Q/C; actual terminal takes the remaining C. | Ordinary SY and all nine added fixed sources surrender twice before randomization. Transfer-away/back cannot move configured identity. US:35 closes scalar balances and retains positive nonrepresentable WS/ER Q/C. | Source units below are separate; no gon/native/internal-share sum or rounding forgiveness. |
| 2. Configured original wallet and actual eligible asset | L:155,180 and U:113,121,145 require exact errors and unchanged economic digest. Actual ownerOf and source balances are independent of consumed bookkeeping. | Missing SY and both NFT records are mandatory; both NFTs exercise no approval, wrong holder and return to original. All nine units exercise missing records, no approval, real transfer-away/wrong-wallet/return, then successful custody. | Synthetic original inputs are disclosed; control and donations do not prove historical eligibility. |
| 3. Corrections preserve executed facts | N:57,285 separates configuration from issuance/configuration-ID/time; B:175 preserves each position. UR:39 builds independent issued-history hash before replacement. | Native already-issued recipient is corrected. Unit fixture issues an independent bond, replaces its configuration, then rejects every source alias of both old issued and new configured origins. These hashes persist through activation and subsequent actions. | Legacy surrender is Stage2-only, so no partly consumed mutable configuration is invented. |
| 4. Credit requires custody or independent authority | L:207,229,260; UB:185; UR:81 separate measured source units, whole NFT identity, explicit independent authorization, issued principal and actual backing. | Real registry independent issuance, both historical NFT surrenders, ordinary SY and nine added sources. Continuous ownerOf expects actual proxy custody, or zero only after modeled permitted weighted burn/earlier sale. | No current custody field supplies the expected NFT owner. |
| 5. Failed issuance restores all economics | N:98; L:119; U:158 preserve custody, allowances, Q/C, supply, funding and bond state. | Native late second-item issuance failure; ordinary-SY and each of nine sources reach actual receipt funding then reject the new NFT receiver. Successful retry follows. R:115 and UR:169 prove complete selected recovery rollback. | Earlier completed source acquisition/approval remains outside parent rollback. No claimed-origin callback is asserted. |
| 6. Every live funded position covers principal | B:95,103,111,138,175 independently models gons, index, weights, allocation dust, staking dust, backing, supply, holders and claims. L:260 and UB:185 model exact fresh escrow and later debits. | Two native machines include actual later ordinary paid bonds, nonzero later reward funding/index growth, all-position transfers and claims. Native linear paid terms remain distinct from migration cliffs. All source-funded positions participate in claim selection. | Initial legacy fixture totals are baseline observations; their later deltas are ghost-accounted. Native paid quotes are pre-action terms, not post-action staking values. |
| 7. Principal obeys its own fresh cliff | B:138; LC:45; UR:203 use stored ghost creation times, principal and claimed units. | NS:46, LS:149 and US:35 exercise later-issued/later-surrendered positions before, at and after their own 90-day cliffs. All-position selectors replace modulo-two selection. Holders really transfer. | Warps exercise economic clocks, not synchronization waits. Retired positions assert exact absence. |
| 8. No Stage1 reward payout | N:169,216 rejects actual funded position/role rewards; B preserves deferred gons/backing. | Native prelude has real first paid rewards, then exact closed reward calls. Deterministic activation releases them; active machine additionally funds and pays later growth. | Complete existing reward/egress/SY/RT suites supplement the direct stateful paths; no new randomized wrapper-surface claim. |
| 9. Stage2 cannot restore loading/issuance | N:120,275,285 checks all 14 interface-derived selectors after every action. U:182 verifies actual removed source loaders while preserving consumed and issued facts. | Actual owner-first activation, repeat activation/configuration/issuance rejection, all-source Stage1 surrender rejection, Stage2 partial/terminal surrender and owner changes. | Existing surface/package/init tests supplement the bounded stateful public selectors; no arbitrary-executor surface is invented. |
| 10. Live markets cannot reprice originals | N:238,259,285 fixes pre-mutation quote and snapshot anchors. UB:185 compares full input-derived entitlement hashes. UR:29 changes actual ER backing/rate. | Genuine pool trades, fee changes, reserve donations, real SE provider changes and later ER source-rate increases; subsequent source surrender retains original Q/C. | Initial nonlinear quote anchors establish immutability, not an independently reimplemented nonlinear pricing oracle. |
| 11. Recovery reconciles by asset/stage and destination | R:25-172; UR:95,122,137,169; UB:185 maintain separate SY, WS gons/native inventory, WD, DTF, ED, ER external E/internal B and protected floors. | SY/NFT recovery, standalone WS unstake, C redemption then SY recovery, W-SD redemption, weighted conversion, real fixed-reserve donation, earlier NFT mature sale, failed selected batches and owner transitions. | E*1e9+B is checked against actual internal ownership. Disabled/unadmitted conversions stay absent. Measured external receipts are not echoed parent inventory. |
| 12. Owner changes preserve pricing, registry, positions and consumption | N:130,285; B:217; R:131; UR:222; UB:185 retain independent current owner, registry owner, frozen snapshot, issued history, positions and source credit. | Distinct actual native parent/hook/children/snapshot instances; owner acceptance and old/pending-owner negatives; ongoing claims/market/recovery after changes. | Passive second-instance hash covers its own actual ledger/identities. Shared external SE valuations may change; full-world isolation is not asserted. |

## Exact added source-unit domains

Every row uses its own real fixed source and canonical original ID. Acquisition
is executed before configuration. Every row has mandatory successful partial
custody, late funded-receiver rollback, exact missing-record/approval/wallet
negatives, another later surrender, random actions and own-clock claims.
Quotes use complete synthetic E0=0.01 ETH/D0=0, never current source value.

| Row | Actual acquisition and units | Independent accounting / terminal boundary |
| --- | --- | --- |
| W-L | UF:97: actual personal WD donor transfer; native9, Q0=10000. | Exact native balance, allowance and inventory; recovery-derived WD merges only in physical inventory, never original Q/C. |
| E-L | UF:97: actual personal ED donor transfer; native18, Q0=10000. | Exact held native units; earlier NFT rewards enter separate recovery inventory, not this original. No ED conversion. |
| W-R | UF:106: genuine 110-native WD stake, measured original operation divisor, unrelated custody transfer. | Eligible Q0=101*kOriginal-1; q=n*kOperation. Native transfer/approval, gons and last-synchronized inventory remain separate. Positive nonrepresentable Q/C survives. |
| E-R | UF:120: genuine ER transfer at actual r=2197; native18 display is not ownership. | Q0=floor(10000*1e27/r)-1 internal shares. q=floor(n*1e27/rOperation); exact internal diagnostic read and external-floor checks. E from real NFT sale remains separate from B. Positive residue survives. |
| C | UF:130: actual 3000-SY deposit by the synthetic original wallet; minted native19 shares=29999999967592. | Q0=acquired-17; unrelated wallet/custody floors. Actual source redeem quote/output, exact share debit and native9 SY receipt. No infrastructure impersonation. |
| W-SD | UF:145: actual 1-DTF deposit by the synthetic original wallet; native28 shares. | Q0=acquired-1e20; unrelated floors. Exact native28 selected burn and native18 DTF receipt. |
| W-SW | UF:161: existing EOA's own personal WE transfer; native18, Q0=10000. | Distinct record, allowance, held inventory and terminal credit. Disabled exit is not exercised or claimed supported. |
| E-P | UF:161: actual existing EOA collector owner releases physical LP to itself, then makes a separate personal transfer. | Native18 physical LP, Q0=10000; not NFT accounting shares. Qualified local donor simulation, not public consent or general claimant authority. No conversion. |
| W-P | UF:161: same admitted owner-release/personal-transfer sequence on the distinct weighted LP. | Native18 physical LP, Q0=10000; not WD principal or SE shares. Owner-only recovery restriction remains. |

UB:159 uses `vm.load` only as a read-only diagnostic of the admitted external
ER layout. There is no source/SUT storage write, fictional internal getter,
mock, subclass, etch or impersonation of production custody. Other balances
and all SUT calls use actual public production surfaces.

The all-unit prelude also performs 72 directed competing fixed-source
enrollments, nine source-to-independent exclusions, and 18 exclusions of
current/previously-issued independent origins after replacement: 99 exact
canonical-origin rejections. Opaque documentary aliases remain reviewed-input
work, not a property that onchain canonical keys can establish.

## Canonical adversarial dispositions

| Catalog concern | Actual evidence and boundary |
| --- | --- |
| A0 | Real donation/bootstrap precedes independent principal in native fixture; bootstrap self-leg is accounted separately. |
| I1-I3 | New legacy APIs use measured approved pulls, not trusted pretransfer. Full current Migration and focused ordinary trust-flag regressions exercise inherited pretransfer negatives; they are supplements, not newly randomized selectors. |
| J1-J3 | All action calls target real registry proxies; actual 14-selector removal is checked continuously. Existing declaration/surface suites supply the full standard-interface matrix. |
| K1 | Every source has unbooked floors; donations and recovered balances never increase original Q/C. Native donations change no configured original credit. |
| E6 | No selectable surrender/recovery refund beneficiary exists. R bounds actual donation spend by selected recovery plus previously recorded protocol residual, preserving protected inventory. Ordinary exact-output/pretransfer regressions supplement. |
| N1 | Ordinary SY and all nine source contract originals reach funded receiver callbacks, assert exact nested lock/removed-activation errors and prove late rollback. No claimed-origin preparation admission follows. |
| Fee/creator nondilution | Native independent integer model includes later reward allocations, rebase-before-role receipts, top-up-only weights, role payout and both dust partitions. |
| Source spoofing / wrapper double-credit | Fixed nine-source dispatch and real pins; mandatory 99 canonical exclusions plus immutable issued/consumed facts. Existing unsupported-source suites supplement; no arbitrary source is admitted. |
| NFT claim/surrender races | Both real whole custodies and subsequent weighted claim/burn/earlier sale are stateful. Existing competing pre-custody claim, empty/burned and prior-claim cases supplement those sequences. |
| Activation reentrancy | New funded callbacks verify activation stays absent after activation. Current complete native callback/owner-first suites cover preactivation/partial-activation attempts; postactivation callback checks are not mislabeled as partial-activation tests. |
| Custody batch failure | Real valid first recovery item and exact failing second item roll back; earlier completed stages remain. Native independent issuance has its own failing second-item witness. |

## Unsupported and non-exhaustive boundaries

Complete-original claimed SY remains the admitted direct-signed-EOA,
canonical isolated-source-block preparation subset. Existing claimed-SY
Foundry tests are supplemental. No source preparation, certificate
authentication, CLI/resume replay or claimed contract-wallet witness occurred.
All new contract-wallet callbacks concern ordinary supported onchain custody.

Raw TokenStaking approved pull, E-S, ER/ED liquidation, disabled W-SW/E-P/W-P
conversions, partial/prior-delivered/unknown originals, standalone original
ETH/WETH consumption, operational eligibility and allocations remain outside
positive admission. No category is declared absent. Earlier source match versus
exact-match, optional missing facet, masked mature-close authorization,
EOA-owner LP release, host/archive portability and gas qualifications remain.

Four bounded action domains are not exhaustive-state or all-selector fuzzing.
The native threshold deliberately suppresses arbitrary epoch expansion; r2
does execute later ordinary paid funding and nonzero reward/index growth.
The legacy/unit parents use the same high-threshold bounded accounting domain.
This closes the requested supported-unit stateful candidate, not full-plan,
full-repository, operational or target-gas acceptance.
