# Migration plan coverage

This maps the original plan's accepted requirements to inspected implementation
and executable witnesses. Execution results and remaining limits belong in
`verification.md`; a mapping row alone is not a passing-run claim.

Path prefixes:

- `M`: `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`
- `T`: `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/`
- `F`: `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/`
- `S`: `scripts/foundry/recovery/dtf-migration/`

## Accepted requirements and feasibility gates

| Requirement | Inspected implementation / witness |
| --- | --- |
| MIG-P01 | `M/UniswapV4DetfMigrationWeightedPricingLib.sol`; `T/MigrationWeightedPricing.t.sol`, `T/UniswapV4DetfMigrationSnapshot.t.sol` |
| MIG-P02 | Allocation/configuration records remain distinct from execution; `T/MigrationWeightedPricing.t.sol`, `T/MigrationAdministration.t.sol` |
| MIG-P03 | `M/legacy/MigrationLegacyNftLib.sol`; `F/MigrationLegacySources.t.sol` partial remaining-principal witness |
| MIG-P04 | Same library; nonexistent, burned, empty and reserved-role rejection in source/NFT suites |
| MIG-P05 | Whole NFT consumption and original indexes; `F/MigrationOriginalWallet.t.sol`, `F/MigrationNftLifecycle.t.sol` |
| MIG-P06 | `M/UniswapV4DetfMigrationRepo.sol` exact issuance; all source surrender suites and rollback witnesses |
| MIG-P07 | Migration bond child; `T/MigrationCore.t.sol`, `F/MigrationNftLifecycle.t.sol` distinct creation clocks |
| MIG-P08 | Receipt, bond, SY and reward-token gates; `T/MigrationEgress.t.sol`, `T/MigrationRetainedAccounting.t.sol` |
| MIG-P09 | Independent configuration and issuance records; `T/MigrationAdministration.t.sol` |
| MIG-P10 | Expected-book and full-replacement loaders; every source configuration suite plus legacy Book 2/Book 3 preservation |
| MIG-P11 | `M/UniswapV4DetfMigrationAllocationTarget.sol` actual 17-selector cut; surface and restoration tests |
| MIG-P12 | Proxy-local Ownable and retained current-owner checks; administration and owner-first-bond tests |
| MIG-P13 | Donation/bootstrap and native explicit funding stages; `T/MigrationGenesisCapital.t.sol`, `S/Phase_08_Stage_01_MigrationExecution.s.sol` |
| MIG-P14 | Typed selected recovery and isolated donation budget; recovery, gas and repeated-reward fork suites |
| MIG-P15 | Configured wallet and actual source custody before issuance; original-wallet and all fourteen source categories |
| E1 | `../source-route-matrix.md`, `../source-manifest.json`, current pinned source suites |
| E2 | Source-native measured custody/consumption and per-original credit conservation; current pinned surrender suites |
| E3 | Current observed Raw/RawRate/disabled/V3 comparisons; new real 18/6 pool differential and nonempty legacy normalization |
| E4 | Empty reserve bootstrap, separate self-leg supply and zero unclaimed issuance; core/genesis suites |
| E5 | Mature cliff principal, activation-gated rewards, role custody, both wrappers, callbacks and disabled-instance exit witnesses |

## All 53 acceptance dispositions

| ID | Current witness |
| --- | --- |
| MIG-AC01 | `T/MigrationOwnerFirstBond.t.sol`: narrow paid-owner exception and rejection of other Stage 1 acquisitions |
| MIG-AC02 | Source fork suites: Stage 1 rejects before custody; Stage 2 configured surrender succeeds |
| MIG-AC03 | Owner-first-bond, egress and surface tests exercise alternate acquisition/callback routes |
| MIG-AC04 | `T/MigrationWeightedPricing.t.sol` and source configuration suites: overwrite, replay, stale book and cutoff |
| MIG-AC05 | `T/MigrationAdministration.t.sol`: current, pending and former owner with rollback |
| MIG-AC06 | Source surrender tests: late receiver/funding failure restores custody and credit |
| MIG-AC07 | `F/MigrationLegacySources.t.sol`: full-original credit times actual remaining principal |
| MIG-AC08 | NFT source reads exclude rewards from eligible principal |
| MIG-AC09 | Original enrollment indexes, wrapper/receipt conservation and repeated recovery tests |
| MIG-AC10 | Recovery protected-state assertions retain funded bond position and backing |
| MIG-AC11 | Separate earlier NFT accounting shares, physical LP, native9/native18 tokens and receipt gon/share tests |
| MIG-AC12 | `T/MigrationSurface.t.sol`: ordinary package lacks migration authority; ordinary suite results reported separately |
| MIG-AC13 | Independent and surrender records plus original overlap rejection |
| MIG-AC14 | `T/MigrationCore.t.sol`, `T/MigrationEgress.t.sol`: cliff positions versus ordinary purchased positions |
| MIG-AC15 | Current-owner pricing setters; both removed at activation; feeTo maintenance is a separate later owner rule |
| MIG-AC16 | `T/MigrationGenesisCapital.t.sol`: measured all-leg receipts and backed reserve initialization |
| MIG-AC17 | `F/MigrationRecoveryDonation.t.sol`: selected recovered capital enters reserve LP without a bond purchase |
| MIG-AC18 | All fourteen rows in the source-route matrix; earlier physical LP has the admitted immutable-custody disposition |
| MIG-AC19 | `T/MigrationCore.t.sol`, `T/MigrationSurface.t.sol`: cliff minus one, unlock, unlock plus one |
| MIG-AC20 | `T/MigrationEgress.t.sol`: actual reward payout and repeat-claim zero |
| MIG-AC21 | Frozen pricing differential suites: complete original, single hook fee and canonical user split |
| MIG-AC22 | Stored original credit and eligible fraction; later live/book changes do not reprice it |
| MIG-AC23 | Fixed source identities and original enrollment exclusions across represented claims |
| MIG-AC24 | Expected-book and live-independence tests; immutable postactivation manual read |
| MIG-AC25 | `F/MigrationNftLifecycle.t.sol`: delayed surrenders receive different fresh cliffs |
| MIG-AC26 | Activation guard and actual Remove cuts; failed-cut rollback test |
| MIG-AC27 | `T/MigrationDeploymentGas.t.sol`: package, registry, initializer, factory and callback restoration attempts fail |
| MIG-AC28 | Removed activation selector cannot be called again |
| MIG-AC29 | Persistent read, surrender, donation, recovery and claim surfaces after activation |
| MIG-AC30 | `T/MigrationRegistryDisable.t.sol`: address/package disable closes new capital while supported mature exits remain usable |
| MIG-AC31 | Retained native funding/configuration/issuance stages; no new pricing-readiness or funding-certification gate |
| MIG-AC32 | Recovery current-owner dispatch; unauthorized callers fail before mutation |
| MIG-AC33 | `F/MigrationRecoveryGas.t.sol`: selected work against small/large unrelated custody populations |
| MIG-AC34 | Repeated reward-only and overlapping selected recovery reconciliation |
| MIG-AC35 | Original-wallet identity and actual holding/custody checks |
| MIG-AC36 | Principal withdrawal changes eligible fraction, not frozen credit; rewards are excluded |
| MIG-AC37 | Actual postactivation removal of every loader and source/configuration route |
| MIG-AC38 | Same-recipient B configuration retains immutable A issuance, bond and history |
| MIG-AC39 | Source-unit conservation without transfer ancestry or mutable postactivation approvals |
| MIG-AC40 | Whole-remainder and late failure rollback witnesses across source classes |
| MIG-AC41 | Partial fungibles and atomic whole-NFT surrender, including two-contribution NFT 3 |
| MIG-AC42 | Bond recipient is the configured surrendering wallet; approved NFT operator cannot redirect it |
| MIG-AC43 | Transfer preserves position clocks; current cliff JSON/SVG and ordinary linear-position checks |
| MIG-AC44 | Failing later selected recovery stage rolls the whole selected transaction back |
| MIG-AC45 | Earlier committed stages remain in custody; fixed eventual donation destination |
| MIG-AC46 | Per-proxy owner and two-instance initialization/deployment isolation |
| MIG-AC47 | Actual Crane pending/current/former-owner behavior; no invented acceptance-delay guarantee |
| MIG-AC48 | Registry-deployed real facets, children, interfaces and complete selector census |
| MIG-AC49 | Expected-book NFT loading without minting, then authoritative remaining-principal read |
| MIG-AC50 | Collection plus token ID and configured wallet plus actual owner |
| MIG-AC51 | Distinct original quotes summed without nonlinear regrouping; overlap indexes retained |
| MIG-AC52 | `T/MigrationMixedRecords.t.sol`: complete A/B simulation with immutable issuance, stable NFT contributions and terminal activation; separate native lifecycle receipts; removed operator application is not reinstated |
| MIG-AC53 | Bond, receipt, SY, reward-token, role and callback Stage 1 reward gates |

## Source and operational limits

Earlier physical LP has no admitted Migration-authorized exit under its
authenticated immutable source. The owner explicitly allowed permanent custody
where that restriction is proven. Other legacy enablement and fee-recipient
requirements are conditional external authority, not a claim of permanent
unrecoverability.

Fork fixtures demonstrate behavior with configured originals. They do not
approve financial eligibility, a live manual book, compensation amounts or
public governance actions.
