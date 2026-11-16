# F1 requirements and source coverage at 0856a5c5

Date: 2026-11-13. Read-only review; no implementation or operational authorization.

**Verdict: F1 all-requirements/all-source closure is not established.** Substantial, source-bound implementation and executed proof exist. The remaining work is not accurately described by a single global list of "unsupported native/WETH, archive equivalence, P1." E-S and the unadmitted claim domains are concrete source-coverage gaps; historical data preparation, selected production composition, disabled recovery routes, deployment feasibility and P1 have different roles.

The subject is `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-26-portable-operator`, HEAD `0856a5c56e5d09b81c669f59b613efef79133e19`. Requirements are the complete current main-checkout plan r5 and PRD r22, not the older source snapshots. Citation roots are defined in section 2; every `:line` locator refers to a file read, not an inferred symbol location.

## 1. Findings, ordered by consequence

### High - F1-01: Earlier SE shares remain a required but unimplemented source

**Requirement:** `PLAN:149-161,409-419,598,686-691`; `PRD:66,241-243,435`. Underlying SE shares explicitly include the earlier generation; no exposure may be assumed absent.

**Source:** `C/legacy/MigrationLegacyRecoveryLib.sol:25-41` admits exactly weighted WETH SE, earlier physical LP and weighted physical LP to the held-source path. Earlier SE `0xb7D4Bb379d361aD442Cddee53EA71A33957826A7` is not in that set. `C/UniswapV4DetfMigrationClaimVaultAllocationTarget.sol:14-41` applies that admission check before storing configuration. `T/MigrationHeldSeLpConfiguration.t.sol:228-236` deliberately proves earlier SE rejection. This is a real missing supported route, not a missing success label.

**Evidence limit:** `A20/source/contract.md:6-9,145-158` records no authenticated ordinary-user positive acquisition fixture. `A20/holder-followup-root/report.md:1-7` found zero balances in 31 additional purchaser wallets; that is not a census. Existing infrastructure-held transfers cannot establish an original user's eligibility. The disabled exit is a separate external constraint.

**Remaining action:** Establish the actual eligible original-wallet/unit dataset and an authentic positive acquisition/control case, or prove absence in the complete reviewed operational dataset. If exposure exists, add and execute the fixed E-S configuration/custody/credit/rollback path under the existing rules. Do not treat another native18 source as E-S, impersonate an infrastructure contract, restore a retired family, or infer absence from sampled zeros. Classification: **missing implementation + missing execution evidence + operational input**, with a distinct **external recovery constraint**.

### High - F1-02: Complete claimed SY closes a subset, not all TokenStaking rights

**Requirement:** `PLAN:25-33,48-64,149-161,290-302,462-471`; `PRD:278-284,433-435`. Actual claim extinguishment or custody, original-wallet configuration, proportional remaining credit and no duplicate underlying claim are required. A direct raw-weight approved pull is not the only permissible design: staged source preparation and later custody must be assessed on their actual boundaries.

**Source:** `O/schema.ts:61-95` accepts only complete-original TokenStaking certificates with known `priorDeliveredCredit: "0"`. `O/claimed-sy.ts:64-87` requires the sum of consumed eligible weights to equal the entire reviewed W0 and a positive measured SY sum equal to Q0. `C/UniswapV4DetfMigrationAllocationTarget.sol:189-218` initializes the configured SY quantity with the full once-quoted E0/D0 credit. It has no inherited-delivery/remaining-credit input. `C/UniswapV4DetfMigrationTarget.sol:127-180` then implements correct partial/terminal surrender of that configured SY.

**Executed positive subset:** `V26:86,110-114` establishes complete direct-signed-EOA, isolated-block preparation, exact outputs, partial/terminal SY custody and fresh bonds. Earlier raw claims stay consumed when a later SY funding transaction fails. `F/MigrationWeightedSy.t.sol:55-150` explicitly separates Foundry caller simulation from signed operator proof and ordinary-SY contract-receiver coverage.

**Unclosed domain:** Raw T `reassign`/`withdrawClaim` debit their caller, and approve/transferFrom are unbound (`A22:77-88`; `A11/verification/matrix.md:69-75`). No ordinary Migration approved raw pull/callback is established. Partial source preparation can become admissible under the shipped shortcut only after all eligible outputs and remaining W0 are accounted and controlled before loading. A partially prepared or previously delivered original cannot be loaded as a smaller Q0 with full C0. `A22:271-351` explains that exact incompatibility. Unknown originals/prior delivery are missing evidence, not amounts to fabricate.

**Remaining action:** Reconcile each real T original into already delivered, excluded, surviving raw rights and exact controlled descendants. Use the complete-original route where its actual conditions hold. For any still-eligible remainder outside that subset, establish and test source-unit/remaining-credit conservation without reducing and requoting nonlinear E0/D0, granting full C0 per slice, or adding arbitrary credit inputs. Current code does not demonstrate that broader mechanism. If the reviewed population contains no such remainder, document that result instead of claiming universal source support. Contract-wallet/non-isolated claim preparation is also outside the shipped validator, not disproved as a source capability. Classification: **bounded satisfaction; missing source/intake behavior and execution for other eligible forms; operational evidence unknown**. This is not a demand for an impossible ERC20-style raw pull or for transfer ancestry.

### High - F1-03: The real historical-to-loader preparation work is not complete

**Requirement:** `PLAN:117-127,493-503,674-691`; `PRD:349-353,397-408`. Exact original wallet, known original quantities, source units, disjoint economic origin, prior deliveries/recoveries and frozen quote must be reproducible.

**Source:** `O/preparation.ts:10-32` sorts already structured typed input; `:35-105` validates it, builds source-specific payloads and records `fullTask9: "open"`. `O/provenance.ts:40-93` verifies exact supplied raw files, reviewed JSON pointers and exposure partitions. Neither operation derives historical eligibility merely from a fingerprint. It does not turn the saved account ledger or the offline NFT join into approved loader records.

**Actual data boundary:** `DATA:250-257,263-296,302-310,345-364` records non-issuability, all 43 observed weighted purchase joins, different 41-NFT cohorts, unavailable older raw receipt archival, incomplete recovery histories and needed source mappings. Its older bearer sentence at `DATA:309` is superseded by `PLAN:56-64` and current `PRD:251`; it cannot override original-wallet eligibility. The root intake and 43-NFT observation JSON are orientation, not a shipped normalizer or award approval.

**Remaining action:** Produce a new versioned, reproducibly derived candidate dataset from exact saved raw sources, retaining unknowns and per-record exclusions. Complete missing observations through an independently authorized acquisition lane where necessary; do not rewrite frozen inputs. Reconcile/refresh original wallet, purchase inputs, current principal/control, units, recoveries, competing representations and previous delivery; independently review resulting full values. This is unfinished engineering/data preparation plus unsupplied operational approval, not a requirement to restore retired loss valuation fields or invent a new policy. Classification: **missing preparation/execution evidence + operational input/approval**.

### Medium - F1-04: Custody-and-hold passes do not prove eventual liquidation

`C/UniswapV4DetfMigrationRecoveryTarget.sol:324-357,424-448` exposes finite owner-selected stages and a fixed DTF donation destination. `C/legacy/MigrationLegacyRecoveryLib.sol:176-381` implements weighted claim/SY/receipt/liquid/DTF recovery and earlier reward-claim/mature-sale-and-hold. It does not contain a successful earlier-receipt/earlier-liquid/held-LP liquidation route.

`A11/verification/matrix.md:90-119` retains exact `VaultDisabled`, `NotOwner`, `UnsupportedRoute` and masked wrong-owner-close results. `I24:54-66,84` distinguishes successful custody from blocked conversion. E-L's later retained positive-LP-sizing-to-disabled-ES result is not a successful conversion (`A19/commit/verification.md:128`; `A19/verification/report.md:247-261`). The actual dispatch does not spend those held inventories or substitute Migration ownership for legacy ownership.

**Remaining action:** Keep each blocked asset and remaining right in its actual unit and custody ledger. Establish a source-authorized route and execute its complete rollback/conversion/donation proof before claiming recovery support. Do not require immediate liquidation for a successful surrender: staged custody is expressly permitted (`PLAN:30-31,334-350`; `PRD:307-311`). Do not silently promise eventual realizability, re-enable a source, fabricate a role, or reinterpret a failed call's return ABI. Classification: **external source-state/authority constraint + unexecuted downstream behavior**, not a demonstrated bug in admitted custody.

### Medium - F1-05: Frozen pricing and gas have bounded technical proof, not production acceptance

`C/UniswapV4DetfMigrationSnapshotLib.sol:20-88,120-183` captures and purely evaluates direct contribution-to-pair routes, recognized V3 deposit state and raw DETF output. `QUOTE:9-55,163-168` expressly excludes arbitrary receipts, buffered DETF output and unsupported nested/conversion models. Its current successful fixtures and phase26 replay do not identify an approved real recovery composition. E3 needs the selected composition's complete dependency/quote proof; unsupported optional models are not automatically new requirements.

Actual registration remains **45,116,678 > 32,000,000 gas** (`V26:130`; `K26:324-333`). EIP-170/runtime matching and permissive local gas do not repair that feasibility failure. `F/MigrationRecoveryGas.t.sol:16-62` measures selected harvest work at populations 2/26 and an eight-item selection; it is not a target-approved loading/issuance/harvest batch schedule.

**Remaining action:** Bind the actual proposed new package/oracle/reserve routes and funding snapshot, reproduce all original quotes inside supported domains, and select operational batch limits from actual measured transactions and the target limits. Target deployment feasibility remains unresolved technical work, separate from authorization. **No held09 retry, access or workaround is part of this review.** Classification: **operational composition + missing production-specific execution evidence + retained technical feasibility blocker**.

### Reporting corrections - F1-06: Three old global blocker labels overstate authority

1. **Standalone native ETH/WETH surrender:** No governing current clause requires repaying fresh ETH/WETH as a separate compensated surrender source. `PLAN:149-161` enumerates accepted legacy categories; `PLAN:132-134,206,359` identifies ETH/WETH as contribution/funding units. `PRD:317-319,345,402` requires donation/native handling and original-input accounting. Crucially, the original matrix itself labels both rows **"provenance coverage, not a surrender substitute"** (`A01/source-route-matrix.md:582-635`). Preserve both rows below as incomplete original-contribution/recovery coverage; do not silently delete them or add a new personal native/WETH mint path. A separately evidenced eligible legacy right would need its actual source mapping; no such right is established by a present balance.
2. **Exact historical archive/build equivalence:** `PLAN:50,159` expressly says authenticated execution-build provenance is not a prerequisite. `PLAN:145,149-153,411` still requires actual pinned deployed identity, relevant routing/ABI/units and demonstrated source behavior. `A20/source/contract.md:66-88` records archive `match`, not `exact_match`. `A20/owner-funding-verification/report.md:53-61` preserves a current-artifact/legacy-facet mismatch and instead authenticates the narrow actual executed release. Universal transitive source recompilation is not an F1 requirement. A missing identity for a *used* source selector remains a concrete E1 evidence gap; shared proxy bytecode or today's similarly named source is insufficient. Neither qualification may be silently converted into a blanket pass.
3. **P1:** `Q24:1-10,53-93,149-166` confirms current bounded immutable delivery **with** two unavailable first-producer raw JSON versions. P1 is unresolved historical raw preservation, not a current behavior defect or a reason to rerun current tests. Preserve original needs-fix history. Current artifact/runtime/metadata agreement does not reconstruct the missing bytes or prove all-history preservation.

These are scope/evidence corrections only. They neither amend the PRD nor authorize implementation or operational use.

## 2. Citation roots and evidence method

All current-code/test paths below are at the subject HEAD unless explicitly marked historical.

| Alias | Exact root/file |
| --- | --- |
| ROOT | `/Users/cyotee/Projects/indexedex` |
| WT | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-26-portable-operator` |
| PLAN | `ROOT/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` |
| PRD | `ROOT/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_DRAFT_PRD.md` |
| DATA | `ROOT/docs/incidents/2026-09-16-dtf-recovery/ENTITLEMENT_LEDGER_PROVENANCE.md` |
| C | `WT/contracts/vaults/detf/protocols/dexes/uniswap/v4/migration` |
| T | `WT/test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration` |
| F | `WT/test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration` |
| O | `WT/scripts/recovery/dtf-migration` |
| QUOTE | `WT/docs/incidents/2026-09-16-dtf-recovery/migration/quote-evidence.md` |
| A01 | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration` |
| A11 | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-11-same-wallet-sources/docs/incidents/2026-09-16-dtf-recovery/migration/same-wallet-sources` |
| A19 | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-19-earlier-liquid/docs/incidents/2026-09-16-dtf-recovery/migration/earlier-liquid` |
| A20 | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-20-se-lp-source/docs/incidents/2026-09-16-dtf-recovery/migration/se-lp-sources` |
| A22 | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-22-claimed-sy-source/docs/incidents/2026-09-16-dtf-recovery/migration/claimed-sy-source/verification/report.md` |
| I24 | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-24-stateful-invariants/docs/incidents/2026-09-16-dtf-recovery/migration/stateful-invariants/verification-r2/report.md` |
| Q24 | Same phase24 `stateful-invariants/commit/P1-followup.md` |
| H25 | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-25-full-hermetic/docs/incidents/2026-09-16-dtf-recovery/migration/full-hermetic` |
| V26 | `WT/docs/incidents/2026-09-16-dtf-recovery/migration/portable-operator/verification-r2/report.md` |
| K26 | Same `portable-operator/commit/verification.md` |

Table shorthand is exact filename abbreviation, not a different source:
`SnapshotLib`, `AllocationTarget`, `Target`, `RecoveryTarget`, `Repo`, `DFPkg`,
`Policy`, `ExchangeFacet` and `BondFacet` mean the corresponding
`C/UniswapV4DetfMigration<name>.sol`. `NftLib` means
`C/legacy/MigrationLegacyNftLib.sol`; `RecoveryLib`
means `C/legacy/MigrationLegacyRecoveryLib.sol`; `second loader` means
`C/UniswapV4DetfMigrationClaimVaultAllocationTarget.sol`.
`BondNFTVaultTarget` means
`C/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol`;
`StakedDETFTarget` means
`C/claimToken/UniswapV4DetfMigrationStakedDETFTarget.sol`;
`SYTarget` means `C/sy/UniswapV4DetfMigrationSYTarget.sol`;
`RewardTokenTarget` means
`C/sy/rewards/UniswapV4DetfMigrationRewardTokenTarget.sol`. `runbook` is
`WT/docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md`.
I24 raw logs are in the same `verification-r2/` directory as I24.

Read the entire assigned brief first and the complete current plan/PRD. Inspected actual current surrender/loaders, frozen evaluator, package/cut/restoration boundaries, parent money paths, bond/receipt/SY/reward-token policies, tests, source matrices/manifests and accepted proof reports. Historical matrices retain their original results; this report applies current precedence rather than rewriting them. `PLAN:35-44,48-64,66-84` overrides bearer/full-credit wording, Stage1 surrender, partly surrendered correction choices and the stale price-setting role.

This review reused executed checks. It did not run source, scripts, tests, builds, an operator, a signer, providers or a replay. Raw final totals and stage markers were read directly as listed below. Existing independent immutable audits supply their full artifact/signature/inventory checks; this review does not pretend to have repeated every historical byte audit. No completed-DAG label supplies proof.

Statuses: **S** = satisfied in the explicitly admitted/tested domain; **M** = missing implementation; **X** = missing execution/identity evidence; **O** = operational data/composition/approval; **E** = external source state/authority; **H** = historical provenance; **R** = reporting/scope correction. An S for shared mechanics does not close a universal requirement where a source row remains M/X/E/O.

## 3. Executed-proof ledger and cumulative identity

| Proof | Actual executed result and read location | Boundary |
| --- | --- | --- |
| Phase24 final r2 Migration specifications | 171 pass, 0 fail/skip, 30 suites; raw `stateful-invariants/verification-r2/specs-final-01.log:6498-6505`; `I24:109-126` records artifact-first commands, exits and settings | Not the earlier 169-spec first pass |
| Phase24 final r2 pinned Migration forks | 147 pass, 0 fail/skip, 26 suites; raw `forks-final-01.log:4815-4825`; `I24:109-126` | Real historical sources; synthetic reviewed allocations remain labeled |
| Phase24 ordinary regressions | 58 pass, 0 fail/skip, eight suites; raw `ordinary-final-01.log:4450-4520`; `I24:109-126` | Focused ordinary roots, not the whole repository |
| Stateful invariants | Four actual machines, each 32 runs/depth16/512 selected calls, fail-on-unexpected-revert; `I24:38-124` | Twelve properties over admitted units, not exhaustive states or unsupported source forms; guards/rejections are not positive-action counts |
| Phase24 immutable/P1 follow-up | Commit `8db3f5ee...`, 14 current/tested files and r2 identity confirmed with P1; `Q24:95-166` | Two historical raw JSON versions still absent |
| Phase25 full hermetic | `forge build --use solar`, all-runtime-artifact refresh, one focused metadata test, full default hermetic `forge test --use solar -vv --no-match-path '**/fork/**' --no-match-contract Fork`; all final exits 0; `H25/commit/verification.md:49-78` | Existing CI exclusions, default invariant settings; not pinned legacy forks |
| Phase25 raw full summary | 28,576 pass, 0 fail/skip, 2,687 suites; `H25/tests-r2.log:64005-64014` | Initial 28,575/1 failure preserved; existing interface metadata test corrected, not removed/weakened |
| Phase25 immutable delivery | Commit `137fa0c8...`, sole parent `8db3f5ee...`, exact one test path; `H25/commit/verification.md:13-66` | No production change |
| Phase26 operator gates | 109 pass, 0 fail, 11 files; raw `portable-operator/verification-r2/operator-tests.log:125-137`; artifact/stage exit-zero completion in `gate-session.log:2964-2971`; exact recipes `gates.sh:1-35` | Latest source-specific operator tests/types, not a replay of the full Solidity repository |
| Phase26 real independent workflow | Actual sandboxed 18575 cumulative workflow, canonical observer/audits exit 0; `V26:55-114` | Same-host saved-data relocation; installed source/dependencies/warm artifacts/archive bootstrap |
| Actual recovery, not counts alone | Same mined transaction/intent/signature/nonce/full receipt adopted after SIGKILL for funding nonce2139, issuance2163, owner-first bond2215; `V26:88-100`; `K26:153-197` | No second donation/issuance/paid purchase; changed domains reject |
| Current immutable source | `0856a5c5...` sole parent `137fa0c8...`, 24 paths (19 modified/5 new), all 60 frozen operator/stage/runbook identities; `K26:19-105` | Latest increment contains no production Solidity; prior cumulative Solidity/test proof remains applicable |
| Current deployed binding | `V26:102-114` binds 57 artifacts, 75 captures, 301 compiler-source identities, named links, constructor values and 22 immutables | Not blanket legacy archive equivalence or original historical allocation proof |

Both NFT models, all nine additional admitted unit rows, ordinary SY and complete claimed SY appear in actual proof, not only comments (`I24:54-66`; `V26:86,110-114`). Keep original controlled signatures, synthetic Anvil fixture signatures and offline reconstructed records separate (`V26:110`). The source pin is chain4663 block108944663/hash `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`, **not** the new funded mint snapshot.

## 4. Source category/generation coverage matrix

Address/unit controls come from actual code (`C/legacy/MigrationLegacyNftLib.sol:10-45`; `C/legacy/MigrationLegacyRecoveryLib.sol:25-41,51-160`), the actual source matrix (`A11/verification/matrix.md:10-121`) and executed admitted-unit table (`I24:54-66`). The sixteen historical exposure rows are retained; aggregation headings such as "underlying SE shares" are not extra source identities.

| Row / source | Exact source unit and current custody/credit | Executed recovery / limits | Disposition and remaining action |
| --- | --- | --- | --- |
| W-L weighted liquid `0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7` | Native9; exact wallet debit/proxy receipt; wallet-bound Q/C. `C/UniswapV4DetfMigrationTarget.sol:63-118` | Weighted `exchangeIn` to DTF then fixed donation; `C/legacy/MigrationLegacyRecoveryLib.sol:320-338`; `F/MigrationWeightedLiquid.t.sol:82,240,271`; I24/V26 | **S/O**. Supply approved original units/E0/D0 and disjoint origin; current holdings are not originals |
| E-L earlier liquid `0xaf0E1967c8F755c747615c5427108Bc549CA1122` | Native18; separate record and measured custody; `C/UniswapV4DetfMigrationRecoveryTarget.sol:91-156` | Custody-and-hold; positive exit sizing reaches disabled ES, no successful conversion/donation; `F/MigrationEarlierLiquid.t.sol:94-320`; Q24 | **S/E/O** for custody; downstream recovery open, not a native9 substitute |
| W-N weighted NFT `0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E` | Native9 P0/Pc; whole ID; floor(C0*(P0-Pc)/P0), all still-locked principal included. `C/legacy/MigrationLegacyNftLib.sol:28-65`; `C/UniswapV4DetfMigrationTarget.sol:266-321` | Real principal/reward claims -> receipt gons -> WD -> DTF/donation; late growth and final burn retained. `F/MigrationLegacySources.t.sol:31-53,130-223`; `F/MigrationRecoveryWeighted.t.sol:18-118`; I24 | **S/O**. Purchase join and actual current owner/principal/burn refresh still needed; rewards never increase E0/D0 |
| E-N earlier LP-lock NFT `0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391` | Original LP accounting shares, not physical LP/effective reward weight; whole ID. `C/legacy/MigrationLegacyNftLib.sol:39-45`; `F/MigrationLegacySources.t.sol:75-128` | Repeated ED rewards; mature sale burns/retires lock, measures external ER shares. `C/legacy/MigrationLegacyRecoveryLib.sol:340-380`; disabled close/ER exits remain distinct | **S/E/O**. Claim/sale-and-hold supported, downstream conversion not certified; archive old purchase receipts |
| W-R sDETF `0x4Fa4974a8a09660258B8edD430B51C1620eBFE5c` | Approval/input native9; Q in original eligible gons; source synchronization precedes measured n*k debit. `C/UniswapV4DetfMigrationRecoveryTarget.sol:248-321`; `C/legacy/MigrationLegacyRecoveryLib.sol:134-160` | Actual unstake including full-account dust guard; growth/staged DTF recovery. I24 retains positive nonrepresentable Q/C, not false terminal payment | **S/O**. Original gon basis and principal/reward partition required; no confiscation or promise all gon residues become transferable |
| E-R earlier receipt `0x4AC89aD061A531FA62ddceED53520C2750113b01` | Native18 display; Q exact internal shares; external getter floors at 1e9. Singleton transfer-rate interval checked, no fictitious getter. `C/legacy/MigrationLegacyRecoveryLib.sol:51-128`; `C/UniswapV4DetfMigrationRecoveryTarget.sol:178-242` | Custody-and-hold; actual rate growth and retained nonrepresentable Q/C; NFT-sale external E separate from standalone internal B; ER conversion disabled | **S/E/O**. Reconcile actual original internal units and historical supply discrepancy; no decimal shortcut |
| W-Y ordinary SY `0xB55604CF4dcdABB362078e106D20F98512391EdF` | Native9 static shares; separate source-original record; `C/UniswapV4DetfMigrationTarget.sol:127-180` | Exact SY burn -> measured WS gons with two source floors -> WD -> DTF -> donation; `C/legacy/MigrationLegacyRecoveryLib.sol:202-239`; `F/MigrationRecoveryWeightedSy.t.sol:60-128` | **S/O**. Ordinary independent SY not automatically any raw-weight descendant; prohibit raw/backing/SY double allocation |
| T TokenStaking `0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00` | Native18 caller-owned weight; no approved pull or recipient callback. Complete consumed W0 -> measured Q0 claimed SY admitted by operator; `O/claimed-sy.ts:64-87`; A22 | Complete direct-signed-EOA subset integrated V26; prior source claim and later Migration rollback are separate transactions | **S subset / M/X/O broader eligible domain**. Reconcile raw remainder, partial/prior-delivered originals and excluded rewards; do not demand all ancestry or falsely mark direct raw custody supported |
| C vault `0xAf5C0cD3fDEdd10bee00Eff77Fa0429Bacdb41f0` | Direct shares native19, measured pull; indirect rights remain T, not a user's right to backing. `C/UniswapV4DetfMigrationRecoveryTarget.sol:359-422` | Direct share burn -> native9 SY -> weighted recovery, exact supply/source deltas; `C/legacy/MigrationLegacyRecoveryLib.sol:260-279`; `F/MigrationClaimVault.t.sol:43-99` | **S/O direct; T limits indirect**. No duplicate compensation for infrastructure backing |
| E-S earlier SE `0xb7D4Bb379d361aD442Cddee53EA71A33957826A7` | Native18; explicitly unsupported by fixed held set and tested loader rejection | Mechanical old infrastructure transfer not integrated original-user surrender; exits disabled | **M/X/E/O**, F1-01. Not proven absent |
| W-SW WETH SE `0x999DaE02D22E5FEe1c4508430D5196d31d631009` | Native18 source shares; measured approved pull/partial and terminal Q/C. `C/UniswapV4DetfMigrationRecoveryTarget.sol:25-89`; `F/MigrationHeldSeLp.t.sol:130-378` | Authentic funded acquisition/custody; no disabled SE liquidation. I24/V26 | **S/E/O** custody-and-hold; not WETH surrender, native28 DE or successful WETH recovery |
| W-SD DTF-custody SE `0x2E9C1F705aB967c5Af59249203d7495bDabb223b` | Native28 shares, DTF native18; `C/UniswapV4DetfMigrationTarget.sol:191-246` | Exact ERC4626 share burn/DTF delta -> donation; `C/legacy/MigrationLegacyRecoveryLib.sol:241-258`; `F/MigrationDtfCustodySe.t.sol:43-99` | **S/O**. Keep source archive/captures and original direct-user mapping; not W-SW evidence |
| E-P physical LP `0x923877336b14662cFb5B3A60b14e7d716d54A888` | Native18 physical token, not EN accounting shares; fixed held path | Genuine collector EOA-owner release to itself, separate donation then controlled custody; locally impersonated donor, not private-key/consent proof. A20 owner-funded report; I24 | **S/E/O** bounded custody. No claimant/Migration collector authority; native exit `NotOwner`, EX `UnsupportedRoute` retained |
| W-P physical LP `0x46E068c2393e189Fbc86632f67210aF253a42Aa8` | Native18 physical LP; separate source/inventory; same fixed held path, separately tested | Separate actual donor-dependent acquisition and signed controlled custody; WD owner/owner-only-liquidity exits remain restricted | **S/E/O** custody, not authority to unwind arbitrary WL or borrow WD's protocol-managed LP burn |
| ETH recorded exposure | Wei contribution/funding/recovery evidence, not an admitted standalone old token/claim | Actual payable donation wraps exactly received value and grants no personal credit; `C/UniswapV4DetfMigrationTarget.sol:323-383` | **R/O/X** provenance. Complete missing native histories/source-right mapping; no new surrender implementation mandated by current text |
| WETH recorded exposure `0x0bd7d308f8e1639fab988df18a8011f41eacad73` | Native18 historical purchase input/funding asset; NFT-backed purchase uses NFT surrender | Purchase input cannot be paid twice; W-SW disabled output not standalone WETH custody. A01:605-635 | **R/O/X** provenance. Complete inbound/outbound/recovery attribution without inventing a second award |

For every S/O source, supply historical original-wallet/E0/D0/Q0 records, not synthetic rehearsal originals. Actual source acquisition, signer control, original historical eligibility and operational approval are four different facts. WS/ER positive residues remain claims with retained credit, not paid terminal records (`I24:56-57`). No category is removed by a sampled balance or a passing aggregate test count.

## 5. MIG-P01 through MIG-P15 and E1-E5

| Requirement | Code and executed evidence | Disposition |
| --- | --- | --- |
| P01 original quote once, two components | SnapshotLib:135-183; AllocationTarget:55-99,148-218; QUOTE:67-92; I24/V26 | **S/O** supported composition; no supply on quote/configure |
| P02 consume prequoted credit, sum distinct credits | Target:63-118,127-180; AllocationTarget:72-92; `T/MigrationAdministration.t.sol:64-83`; claimed totals V26:112 | **S**, broader T mapping still F1-02 |
| P03 actual remaining fixed principal fraction | NftLib:28-45,47-65; `F/MigrationLegacySources.t.sol:31-53,130-147` | **S**; don't re-quote smaller E0/D0 |
| P04 absent/burned/empty earns none | NftLib:47-65; `F/MigrationLegacySources.t.sol:149-223` | **S** |
| P05 whole NFT consumed; no duplicate descendant credit | Target:276-305; AllocationTarget:148-185,253-267; I24:74-78,99; source-origin tests | **S/O**, opaque aliases and broader T originals remain open |
| P06 matching original wallet, custody before fresh funded bond | Target:83-118,148-180,266-305; RecoveryTarget:187-222,265-302,385-422; Repo:81-90; F original-wallet/late-failure tests; I24/V26 | **S admitted / M/X E-S and broader T** |
| P07 own full 90-day clock, no expiry | BondNFTVaultTarget:29-43,60-71; `F/MigrationNftLifecycle.t.sol:96`; I24:41,80 | **S** |
| P08 creation-time rewards, activation-gated payout | BondNFTVaultTarget:74-88; StakedDETFTarget:354-420; I24:27,79-81,97; V26 | **S**, including long Stage1 and deferred roles |
| P09 independent disjoint recipient path | AllocationTarget:55-146; Repo:81-90; `T/MigrationCore.t.sol:74-98`; I24 native book; V26 canonical three-recipient issuance | **S/O** data disjointness |
| P10 complete replacement separate from delivered facts | AllocationTarget:55-99,101-146; second loader:14-41,43-73; `T/MigrationCore.t.sol:74-98`; I24:76 | **S** reachable lifecycle; partly surrendered amendment is unreachable |
| P11 atomic opening/removal, no restoration | AllocationTarget:269-303; DFPkg:233-280; `T/MigrationSurface.t.sol:42-81`; V26 actual14 cuts | **S**, completed paid-purchase prerequisite included |
| P12 proxy current owner, explicit args, no rate setter | DFPkg:239-253,282-286; AllocationTarget:37-42; RecoveryTarget:324-329; `T/MigrationAdministration.t.sol:33-63`; I24 owner transitions | **S**; no invented Ownable acceptance delay |
| P13 scripted funding then snapshot/configuration, no new flags | Target:323-383; AllocationTarget:44-53,305-367; O/preparation/execution; V26:82-100 | **S/O** actual funding and dataset approval remain unsupplied |
| P14 bounded atomic/staged fixed-destination harvest | RecoveryTarget:324-357,424-448; RecoveryLib:176-381; `F/MigrationRecoveryGas.t.sol:16-62`; I24 property11 | **S admitted / E blocked downstream routes** |
| P15 every category/generation, original wallet and actual control | Fixed adapters and matrix section4; `F/MigrationOriginalWallet.t.sol:12-96`; I24/V26 | **M/X/O/E overall**, not closed by admitted subset |

| Gate | Current assessment | Exact remaining closure |
| --- | --- | --- |
| E1 source route closure | **Not fully closed.** Source rows above have actual fixed identities and bounded execution, except E-S and broader raw/claim domains; downstream disabled routes remain E. Actual ABI must follow deployed generation, including one-word legacy EX returns, native19/native28 and receipt fractions | Resolve F1-01/02, relevant used-selector identity gaps and per-source recoverability; no mandatory all-history build pedigree |
| E2 original-wallet surrender/conservation | **S for admitted paths**, all Stage2-only with configured wallet/control and negative rollback; `I24:74-85`, `V26:86-114` | Prove same conservation for remaining required forms; reconcile documentary aliases/previous deliveries. No ancestry ledger or transfer notification |
| E3 frozen quote closure | **S bounded evaluator**, **O/X selected real composition**; SnapshotLib:20-88,135-183; QUOTE:9-55,163-168 | Pin actual new reserve/oracle/routes, complete dependency capture and quote/domain vectors; don't split originals to evade limits |
| E4 empty-instance donation bootstrap | **S technical**; AllocationTarget:305-367; Target:323-383; `T/MigrationGenesisCapital.t.sol:110-186`; `T/MigrationCore.t.sol:43-72`; V26 workflow | Operational actual reserve funding/receipts and feasible deployment remain separate |
| E5 complete payout closure | **S for installed composition and executed gates**; BondNFTVaultTarget:60-88; StakedDETFTarget:143-243,354-420; SYTarget:77-145,196-220; RewardTokenTarget:75-116; I24/H25 | No new current payout defect established. Retain mature principal exits, deferred reward rights, ordinary purchased-bond terms and ordinary regressions |

## 6. All 53 PRD acceptance dispositions

`PLAN:577-636` supplies the current disposition of every original AC ID. The table uses that precedence, not conflicting unrevised bearer/full-credit sentences. Test names/declarations were read alongside relevant production mechanisms; executed coverage is the ledger in section3, not a claim of new execution.

| AC | Requirement-to-code / test owner | Disposition |
| --- | --- | --- |
| 01 | ExchangeFacet:57-64; BondFacet:38-57; `T/MigrationCore.t.sol:151-159` | **S**, paid owner-first exception only |
| 02 | Target:83-118,148-180,266-305; RecoveryTarget surrender entries; `F/MigrationOriginalWallet.t.sol:12-96` | **S admitted; M/X required missing forms** |
| 03 | Policy:74-103; ExchangeFacet:57-64; `T/MigrationOwnerFirstBond.t.sol:143-157`; `T/MigrationEgress.t.sol:244-265` | **S** installed direct/indirect acquisition gates |
| 04 | AllocationTarget:55-99,101-146; `T/MigrationCore.t.sol:74-98`; V26 replacements/resume | **S/O** full values, no duplicate payout |
| 05 | AllocationTarget:37-42; second loader:74-79; `T/MigrationAdministration.t.sol:33-63` | **S** authorization/rollback |
| 06 | Repo:81-90; Target/RecoveryTarget measured pulls; `F/MigrationNftLifecycle.t.sol:127-191`; I24 property5 | **S admitted** late issuance failure |
| 07 | NftLib:28-65; `F/MigrationLegacySources.t.sol:31-53` | **S revised** original quote times remaining fraction |
| 08 | NftLib:28-45; SnapshotLib:177-183; `F/MigrationLegacySources.t.sol:75-100,149-176` | **S** old rewards excluded |
| 09 | AllocationTarget:253-267; second loader:81-97; `T/MigrationClaimVaultConfiguration.t.sol:123-245`; I24 property4 | **S keys / O aliases / M/X broader T** |
| 10 | RecoveryLib:176-201,340-380; `F/MigrationRecoveryAccrual.t.sol:19-137` | **S** recovery not a second personal mint |
| 11 | NftLib:28-45; RecoveryLib:51-160; `F/MigrationLegacySources.t.sol:102-128`; I24 units table | **S admitted / M/X E-S and claim remainder / O originals** |
| 12 | Distinct DFPkg and policy classes; I24:23-36; H25 full gate | **S** ordinary package isolation/regression |
| 13 | AllocationTarget:55-146 versus Target surrender; `T/MigrationCore.t.sol:74-98`; V26 independent/NFT/SY flows | **S/O** distinct eligible exposure |
| 14 | Repo:81-90; BondNFTVaultTarget:29-88; `T/MigrationCore.t.sol:116-149`; I24 | **S** common cliff class |
| 15 | DFPkg:239-253; AllocationTarget:37-42; RecoveryTarget:324-329; `T/MigrationOwnerBondCallbacks.t.sol:56`; I24 | **S**, actual current-owner semantics, no price setter |
| 16 | Target:323-383; AllocationTarget:305-367; `T/MigrationGenesisCapital.t.sol:110-186`; V26 funding | **S/O** no personal donation credit |
| 17 | RecoveryLib:202-338; RecoveryTarget:424-448; `F/MigrationRecoveryDonation.t.sol:107-238` | **S reachable / E disabled downstream**, no ordinary bond |
| 18 | All source rows section4; explicit E-S rejection test | **M/X/O/E overall**; cannot close by deferred/unsupported row |
| 19 | BondNFTVaultTarget:60-71; `T/MigrationCore.t.sol:130-149`; I24 own-cliff witnesses | **S** principal boundaries and no linear migration vesting |
| 20 | BondNFTVaultTarget:74-88; StakedDETFTarget:354-420; `T/MigrationEgress.t.sol:287-301`; I24 | **S** accrual preserved, no Stage1 payout |
| 21 | SnapshotLib:135-183; `T/UniswapV4DetfMigrationSnapshot.t.sol:39-91`; QUOTE:67-92 | **S supported / O/X selected operational composition** |
| 22 | SnapshotLib pure evaluation; `T/MigrationCore.t.sol:100-114`; QUOTE unchanged frozen/live changed | **S revised**, same eligible fraction required for same delivered award |
| 23 | Separate original components/canonical keys; DATA:291-296; I24 property4; V26 claimed transitions | **S mechanics / O reconciliation / M/X broader claim mapping** |
| 24 | AllocationTarget:44-53; SnapshotLib:25-62,135-183; `T/MigrationCore.t.sol:100-114`; I24 property10 | **S** no recapture/setter/live reprice |
| 25 | BondNFTVaultTarget:29-43; `F/MigrationNftLifecycle.t.sol:96-125`; I24 property7 | **S** fresh per-operation start/unlock |
| 26 | BondFacet:38-57; AllocationTarget:269-284; `T/MigrationCore.t.sol:161-238`; V26 actual paid purchase and cuts | **S**, independent compensation alone insufficient |
| 27 | AllocationTarget:287-303; DFPkg:233-280; `T/MigrationSurface.t.sol:42-81`; V26/K26 actual14 removals | **S** actual routing, no restoration authority |
| 28 | Same cut; `T/MigrationCore.t.sol:185-238`; I24 property9 | **S**, absent activation selector acceptable |
| 29 | Persistent Target/RecoveryTarget; `F/MigrationNftLifecycle.t.sol:96-125`; V26 post-cut sources/donations | **S admitted; M/X missing forms; E blocked conversions** |
| 30 | Target:86-88 and recovery donation registry checks; `F/MigrationRecoveryDonation.t.sol:147-158`; I24 property9 | **S** applicable registry rules, no second pause switch |
| 31 | O/preparation.ts:35-105; V26:82-100; runbook:18-47 | **S bounded workflow / O/X real dataset pipeline** |
| 32 | RecoveryTarget:324-329; `F/MigrationRecoveryWeighted.t.sol:120-159`; source-specific current-owner tests | **S** owner-only before/after activation |
| 33 | RecoveryTarget selected loop:329-355; `F/MigrationRecoveryGas.t.sol:16-62` | **S bounded independence / X/O operational gas schedule** |
| 34 | RecoveryLib operation-local inventories; `F/MigrationRecoveryWeighted.t.sol:54-75`; `F/MigrationRecoveryAccrual.t.sol:19-137` | **S admitted**, real later accrual not recounted |
| 35 | Configured original wallet unchanged by transfer; Target:93-95,158-160,280-283; `F/MigrationWeightedLiquid.t.sol:180-197`; I24 | **S revised / O origins**; not bearer entitlement |
| 36 | NftLib:28-65; `F/MigrationLegacySources.t.sol:31-53`; RecoveryLib separate reward inventory | **S revised**, principal fraction changes award, not quote |
| 37 | Complete14-selector removal; `T/MigrationSurface.t.sol:42-81`; I24 property9/V26 | **S** no source/root/approval mutation after cut |
| 38 | AllocationTarget:55-99; second loader full replacement; `T/MigrationCore.t.sol:74-98`; I24 property3 | **S**, issued facts preserved; no Stage1 partial surrender |
| 39 | Remaining Q/C recurrence Target:63-118,127-180; I24 property1 | **S revised admitted / M/X broader T / O original mapping**; no transfer ancestry |
| 40 | No return/cancel selector; Target guarded custody/funding; `F/MigrationNftLifecycle.t.sol:127-191`; I24 property5 | **S** final successful surrender, atomic failure |
| 41 | Fungible partial/terminal versus NFT whole identity; Target and RecoveryTarget; I24 unit table/own-cliff tests | **S admitted / M/X missing forms**, source residue retained |
| 42 | Target:93-95,115,158-160,178,280-305; `F/MigrationLegacySources.t.sol:16-29,55-73` | **S** configured surrenderer receives bond, no relayer/beneficiary |
| 43 | BondNFTVaultTarget inherited synchronized transfers; `T/MigrationEgress.t.sol:64-148`; I24:41,79-80 | **S** all tracked positions retain lock/principal/rewards |
| 44 | RecoveryTarget whole selected loop under one transaction; `F/MigrationRecoveryWeighted.t.sol:77-118`; `F/MigrationRecoveryEarlier.t.sol:79-107` | **S** failed selected batch, smaller retry |
| 45 | RecoveryLib inventories, fixed `_donateRecovery`; `F/MigrationRecoveryAccrualRollback.t.sol:16`; V26 staged recovery | **S/E**, held disabled routes not falsely donated |
| 46 | DFPkg:215-219,239-253,282-286; `T/MigrationCore.t.sol:21-41`; `T/MigrationAdministration.t.sol:53-63` | **S** isolated proxy owners and no reinitialization |
| 47 | Current Crane owner checks; `T/MigrationOwnerFirstBond.t.sol:107-141`; `F/MigrationRecoveryWeighted.t.sol:120-159`; I24 property12 | **S** pending/former lose authority, no fictional buffer delay |
| 48 | DFPkg:147-206,239-280; `T/MigrationSurface.t.sol:22-40`; I24 real SUT and H25 ordinary regressions | **S** composition/installed surfaces, not target gas |
| 49 | AllocationTarget:148-185; NftLib:28-65; `T/MigrationNftConfiguration.t.sol:35-109`; F legacy source tests | **S revised / O verified purchase inputs** |
| 50 | Collection+ID config and wallet-independent origin; NftLib:20-23; `T/MigrationNftConfiguration.t.sol:53-91`; `F/MigrationLegacySources.t.sol:114-128` | **S revised** transferee doesn't inherit configured compensation |
| 51 | AllocationTarget:55-99,101-146; `T/MigrationAdministration.t.sol:64-98`; V26 canonical three-recipient issuance | **S/O** sum separately quoted originals, exclude held exposure |
| 52 | Configuration tests plus actual14-cut workflow; `T/MigrationCore.t.sol:74-114,185-238`; V26 replacements/activation | **S** reachable overwrite/replay/cut/surrender scenario |
| 53 | BondNFTVaultTarget:74-88; StakedDETFTarget/SY/RT guards; Policy:74-103; `T/MigrationEgress.t.sol:64-301`; I24/H25 | **S** installed payout/callback closure; legacy harvest is distinct |

## 7. Every plan task, supplementary gate and final-wave obligation

| Plan item | Implementation / actual proof | Remaining disposition |
| --- | --- | --- |
| Task1 source/custody/conservation | Finite adapters, source-specific original-wallet tests, I24 forks and V26 signed workflows | **M/X/O/E**, F1-01/02 and source matrix. Historical ancestry investigations not blockers |
| Task2 exact original pricing | SnapshotLib, canonical captured V3/weighted math, original sum; QUOTE and executed snapshot specs | **S bounded / O/X actual composition**. No invented linear rate or fallback |
| Task3 owner package/donation/bootstrap/TestBase | DFPkg, CREATE3/registry real TestBase, GenesisCapital/Core, V26 deploy/funding | **S technical / O deployment inputs / unresolved gas** |
| Task4 config versus consumption | Both allocation facets, independent issuance history, source Q/C and canonical origin exclusion; I24 native ledger/V26 replacements | **S reachable implemented domain**. Obsolete partially surrendered amendment QA superseded by sections1.4/5.3, not a new policy option |
| Task5 funded cliff/reward closure | Bond child exact funding, receipt retained gons, SY/RT policy; Core/Egress/RetainedAccounting/Surface; I24/H25 | **S installed domain**, no payout defect found |
| Task6 atomic source surrender | Actual measured pulls/whole NFT checks, original wallet, fresh funded bond; I24/V26 | **S admitted / M/X required missing forms** |
| Task7 gate/cut/restore audit | Both removable facets,14 interface selectors, actual nonzero former-facet removals, no proxy/package restore; V26/K26 | **S**, actual owner-paid prerequisite not compensation fixture substitute |
| Task8 bounded staged harvest | RecoveryTarget/Lib and source-specific recovery tests, selected-work gas, I24 property11/V26 | **S demonstrated / E disabled routes / X eventual route evidence** |
| Task9 deterministic preparation/operator | Typed integer schemas, raw-bound evidence, payload/quote authentication, domain-bound journal and genuine recoveries; phase26 bundles | **S bounded / O/X real historical derivation**. `fullTask9` remains open, no shipped 43-NFT historical normalizer inferred |
| Task10 integrated/adversarial/invariant/fork/ordinary/full gate/gas | I24 171/147/58 and four32x16 machines; H25 actual28,576; V26 actual109 and complete local workflow | **S executed domains / M/X source gaps / X/O target batch/gas/composition**. No all-category completion |
| F1 policy/source coverage | This report maps P01-P15, AC01-53, E1-E5 and every source row | Review delivered; **all-source completion not established** |
| F2 production proxy/money-path verification | Actual loupe/child/runtime/canonical receipts, pinned forks, shared regressions/invariants | **S bounded**, subject to source/external/gas limits; no new F2 run claimed |
| F3 reconstruction/operator recovery | V26/K26 same-host relocated evidence and three actual recovery cases, exact payload/quote equality, old absolute-domain compatibility | **S bounded / O/X operational dataset**. Not cold dependencies, another platform or relocation of an existing signed journal |
| F4 completion/deployment limits | Current immutable K26 proof and this explicit remaining-work ledger | Do not report whole implementation complete while E1/source/composition limits persist; no deployment/issuance approval |

### Exact examples, invariant and adversarial obligations

All thirteen arithmetic/lifecycle examples in `PLAN:540-556` are accounted for:

| Example | Code/proof and qualification |
| --- | --- |
| 1,3 original quote times remaining fixed principal | NftLib:28-65; actual `F/MigrationLegacySources.t.sol:31-53` contrasts smaller-input requote. 1,000/100/40 is explanatory, not a requirement for those literal fixture values |
| 2 empty NFT | NftLib:44-45; F legacy source burned/reward-only/nonexistent tests |
| 4 fungible residue | Target:76-79,107-110; RecoveryTarget receipt recurrence; I24 independent Q/C ledgers and actual terminal flows. Code gives 333,334,334 for C=1001/Q=3; no new runtime calculation claimed |
| 5 original grouping | AllocationTarget:72-92; `T/MigrationHeldSeLpConfiguration.t.sol:202-226`; no merged nonlinear requote |
| 6 zero component/zero delivery | SnapshotLib:142-143; Target preview zero-credit checks; executed Snapshot and source dust tests |
| 7 configured supply versus delivered supply | Repo:81-90; `T/MigrationCore.t.sol:74-98`; F source supply/backing assertions |
| 8 fresh later surrender clock | BondNFTVaultTarget:29-43; I24 actual later own-cliff witnesses |
| 9 mature Stage1 principal, no rewards | `T/MigrationCore.t.sol:130-149`, actual receipt principal exit while activation false |
| 10 delayed first funding/no backdating | Policy:105-122; `T/MigrationCore.t.sol:116-128`; OwnerFirstBond:24-75; later participants settled first |
| 11 deferred fee/creator rights | StakedDETFTarget:354-371; `T/MigrationEgress.t.sol:287-301`; I24 independent role/gon book |
| 12 missing entitlement | Actual every-admitted-source negative preludes, I24:40,50,75; not merely Stage1 closed rejection |
| 13 transfer away/back | Target wallet check and actual source ownership; F original-wallet/source transfer tests; I24 positive/negative witnesses |

All twelve `PLAN:560-571` invariant rows have an executed bounded disposition in `I24:74-85`: (1) frozen Q/C, (2) missing/wrong-wallet rollback, (3) delivered-fact preservation, (4) credit requires custody/allocation, (5) failed issuance rollback, (6) all-position solvency, (7) own cliff, (8) no Stage1 rewards, (9) no restored loaders, (10) quote immutability, (11) recovery conservation/fixed beneficiary, and (12) owner transition preserves protected facts. These are the final expanded r2 machines, not the first two-machine pass. Native reward/index growth and source-unit growth have explicit different domains; WS/ER residues and blocked held conversions remain retained. Complete claimed SY signed execution is separate evidence, not a new raw-weight invariant.

The executed applicability table at `I24:87-103` covers A0 donation, I1-I3 booked-inventory/pretransfer, J1-J3 real proxy, K1 theft, E6 inherited refund bounds, N1 callback mutation, fee/creator nondilution, spoofing, wrapper double-credit, NFT claim races, activation reentrancy and selected-batch rollback. E6 has no new migration-zap/refund path to fuzz; ordinary inherited tests remain its evidence. Guarded handlers and zero claims are not relabeled successful nominal actions. Unsupported domains stay unsupported.

### Actual installed parent/child/receiver boundary

The package composes15 facets and publishes17 interfaces (`C/UniswapV4DetfMigrationDFPkg.sol:147-206`). The two administration facets jointly contribute14 removed selectors; counts of8 or11 in older individual tests are not the full current census. `T/MigrationSurface.t.sol:42-81` inspects both facet declarations; V26/K26 independently observes all14 actual cut events and routing.

The retained graph is parent exchange/bond/maintenance/claim/query, migration surrender/recovery/read/expected NFT receipt, ordinary ERC20/permit/vault/Ownable functions, and real bond/receipt/raw-SY/staking-SY/reward-token children. `T/MigrationSurface.t.sol:22-40` checks actual parent cuts, child loupe, no installed initializer/postDeploy and EIP170 sizes. DFPkg:233-280 rejects existing-account update/reinitialization and does not install generic upgrade authority.

Parent bond entry checks the current owner only for the first closed-stage ordinary purchase, forbids pretransferred recovery inventory and publishes the completion ID only after inherited actual payment/funding returns (`C/UniswapV4DetfMigrationBondFacet.sol:38-57`). Activation checks that fact before the cut. The purchased bond remains ordinary/unmarked and can vest linearly; migration principal remains a full cliff. No continuing owner/NFT-holder requirement is invented after a valid purchase.

Expected old-NFT receiver acceptance requires the parent's active lock, exact collection/operator/from/ID, empty data and a single expected callback; actual ownership/position is checked after return (`C/UniswapV4DetfMigrationTarget.sol:286-321`). A successful callback alone is not custody. Children expose accounting phases, and Policy:74-103 admits only fixed synchronized graphs, not an arbitrary callback exemption.

Bond rewards/combined requests require activation even for zero computed reward; cliff principal uses live canonical funded claim arithmetic (`C/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol:60-88`). Receipt principal packets cannot convey latent Stage1 rewards; fee/creator distributions stay under protocol custody with their original beneficiaries (`C/claimToken/UniswapV4DetfMigrationStakedDETFTarget.sol:143-243,354-420`). SY retains principal and old reward ownership across redeem/transfer; reward issuance/redemption is gated (`C/sy/UniswapV4DetfMigrationSYTarget.sol:77-145,196-220`; `C/sy/rewards/UniswapV4DetfMigrationRewardTokenTarget.sol:75-116`). Mature principal is not blanket-disabled to make Stage1 reward tests pass.

## 8. Exact remaining actions, separated by owner and type

1. **Source engineering/evidence:** Close the E-S positive original-user source route or prove absence from the complete reviewed dataset. Do not reuse infrastructure custody as user proof. Implement/test only if actual exposure requires it; preserve a concrete blocker otherwise.
2. **Claim data and source engineering:** Partition each T original, retain exact preparation members including committed zero outputs and previous delivery, and identify controlled surviving descendants/raw rights. Admit complete uncredited originals through the shipped route. For any eligible remainder the shortcut cannot express, establish conserved remaining-unit/credit behavior and execute it, without requoting reduced E0/D0 or adding free awards. Do not assume that population is empty.
3. **Data preparation/review:** Build a new raw-bound, reproducible candidate independent/NFT/fungible dataset with explicit original wallet, canonical economic origin, Q0/E0/D0, source generation, direct-versus-routed input locators, exclusions, recoveries and prior credit. Archive missing older receipt observations when separately authorized; preserve incomplete WETH/native coverage and receipt-supply discrepancy as unresolved. The 43 offline NFT observations and equal41 counts do not approve eligibility.
4. **Quote/composition evidence:** Identify proposed new package/oracle/actual reserve routes, reproduce its full capture and user split with all nested dependencies, confirm original quote domains and funding receipt order. Unsupported quote models fail concretely; no live fallback or entitlement chunking.
5. **Recovery evidence/external state:** Keep E-L/ER/W-SW/E-P/W-P inventory held in its real units until a genuinely source-authorized recovery exists. Demonstrate any newly proposed exit before declaring conversion/donation support; do not alter legacy source governance or ownership under this review.
6. **Technical feasibility/operator sizing:** Resolve the retained over-cap registration in a separately authorized engineering lane, without held09 access here. Supply real target-cap-based configuration/issuance/harvest limits; selected-harvest scaling alone is insufficient. A local permissive run is neither target feasibility nor permission to deploy.
7. **Reporting:** Apply the native/WETH and archive-provenance scope corrections in future summaries without modifying historical reports. Preserve P1 as the exact two missing raw versions and never claim complete historical preservation. Keep same-host relocation, cold reconstruction, cross-platform support and live-journal migration separate.
8. **Operational authority, last:** Obtain reviewed actual allocations, funding split, deployment identities and explicit authorization for deployment/funding/configuration/issuance/activation/harvest. None is supplied by this F1 report, a bundle flag, test signatures, donor impersonation, commit, or plan checkbox.

P1 exact missing first-producer records (`Q24:53-70`):

| Historical raw JSON | Required bytes | Required SHA-256 |
| --- | ---: | --- |
| `out/TestBase_UniswapV4DetfMigrationSnapshot.sol/MigrationSnapshotConsumer.json` | 466441 | `e7e44f1c9dd1feae73302f69cc50182b084c3e156ff63108f9e1206f52b201bf` |
| `out/MigrationNativeHandler.sol/MigrationNativeHandler.json` | 266621 | `3628e086cdf17079f06aa157c414326519ba5de6d7a60df05e7deaa59e91d013` |

No reconstruction or search for those bytes was performed. Optional missing legacy archive facets remain their own source locators/qualifications; they are not these P1 artifacts.

## 9. Review limits and stopped closure

This is requirements/source-coverage review, not a new security audit or a fresh execution of F2/F3. The current plan/PRD were read completely; source and selected tests/raw proof were read directly, with complete accepted reports reused for their already executed detailed audits. Large raw logs were read at relevant final summaries, not claimed fully re-audited. Source matrices/manifests were interpreted with current precedence; no old failed source capability was relabeled successful by an aggregate.

No source edit, Git write, test/build, runtime/operator/provider replay, install, public action or held09 candidate/worktree access occurred. No product choice was made. The only authored files are this report and its same-named support directory. Support `requirements-coverage-0856a5c5/repository-boundary.md` records before/after HEAD, tracked/index diffs, raw index and ref fingerprints. No owned background operation was started; the attempted evidence delegation was refused before spawning, and the review was completed directly.

**The review deliverable is complete; whole Migration implementation and operational readiness are not asserted. P1 remains unresolved, real datasets remain non-issuable, and registration remains 45,116,678 > 32,000,000.**
