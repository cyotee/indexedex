# F1 plan compliance audit

Date: 2026-11-15.

Disposition: **APPROVE**, under the requesting instruction's exception-relative rule. No additional unsupported source, conservation, manual-quote, or payout gap was found beyond the explicitly named incomplete rows. **Implementation completion is not approved.** Tasks 7, 10, 12, 13, 14 and 15 remain incomplete. This report does not change their checkboxes or authorize implementation, financial allocations, deployment, or public transactions.

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`.

## Scope and authority

Read the complete amended `docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` (P), the complete `/Users/cyotee/Projects/indexedex/.omo/plans/dtf-migration-conformance-remediation-20261114.md` (R), both referenced hyperplan insight bundles, and `migration/verification.md`. P section 1.10 and R's exact manual-pricing and operator contracts govern the superseded capture/live-composition wording.

The current audit instruction permits APPROVE when no additional economic/source gate is unsupported beyond the named exceptions. That is narrower than R's ordinary final-wave completion condition at lines 591-611 and P section 11. The result must not be reused as an unconditional sign-off on either plan.

Repository-relative aliases used below:

| Alias | Exact path |
| --- | --- |
| D | `docs/incidents/2026-09-16-dtf-recovery/migration` |
| E | `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114` |
| M | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration` |
| T | `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration` |
| K | `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration` |
| H | `E/task-13/hermetic-r2/04.log` |
| F | `E/task-13/fork/03.log` |
| O | `E/task-13/operator-r2/04.log` |

H, F and O line references below refer to actual raw log lines read in this audit. A passing case establishes its tested behavior, not missing operator integration or an approved operational dataset. The matrices are this audit's evidence assessment; they do not create the absent task 14 traceability deliverable.

## Named exceptions: all remain unmet

| Incomplete rows | Actual evidence and disposition |
| --- | --- |
| Tasks 7 and 13 | O:88-110 records the claimed-SY witness runtime-pin assertion failing. Expected `0x4ae06bcb278766df6529bcd60e05453fee6c853f6536b9f18d2a4d0dac8fd899`; actual compiled runtime `0x33a0fe038a5d441aa3d9fe48b841bcfc0d0f00f0b085e44b9c41b9b0a7aab2bc`. O:329-331 records **240 passed, 1 failed**. Its command sidecar records exit **1**, and `operator-r2/results.json` records `completed:false`. `task-13/repair-attempt-1/report.md:7-15` supplies no approved matching build recipe. The pin was not retuned. Passing source-conservation fixtures do not close this operator authentication failure. |
| Task 10 | `E/task-10/funding-blocker.json` records the absence of an admissible, bundle-bound donor covering **10,000 DTF**, zero transactions sent, and `nftThreePrincipalConsumedForSetup:false`. It explicitly identifies funded candidates outside the fixed authority bundle; this is a provenance-contract blocker, not proof of global token scarcity. No rehearsal location/runtime or required mixed-book, same-block, donation, or NFT 3 lifecycle receipts are available. NFT 3 was not spent for task 10 setup. |
| Task 12 | `E/task-12/README.md:1-17` and `portable-integrity.json` describe offline relocation into two directories, synthetic wire observations and transitive byte preservation. O:25-46 confirms the corresponding passing fixture cases. Real current-chain portability and actual owner-purchase/donation reconciliation remain missing. Offline completions are not mined transactions. |
| Task 14 | Opening `E/task-14/traceability-review.md` returned **ENOENT**. The required record is absent and was not written by this audit. Current runbook/quote/verification reconciliation remains blocked by task 13. |
| Task 15 | Opening `E/task-15/delivery/delivery.json` returned **ENOENT**. The required record is absent and was not written by this audit. No final delivery-completeness certification is inferred from earlier inventories. |

The narrower NFT 3 fork proof in F:4978,4981 is real test evidence, but it does not replace task 10's missing operator rehearsal. Likewise, task 11's signed gas experiments do not replace task 10 or task 12 lifecycle evidence.

`D/verification.md` is a preserved November 13 report over an earlier worktree and source manifest. Its older test counts, capture terminology, bounded-rehearsal statements and pending labels are historical evidence, not final-tree approval. Their current reconciliation belongs to the already-incomplete task 14.

## Evidence integrity and observed verification

This audit executed no build, test, script, Git operation, RPC request, delegation or transaction. It used local file reads, JSON decoding, raw-byte SHA-256 comparisons, archived-byte Keccak comparisons and targeted source inspection. Only this report and the requested verdict are authored.

| Binding | Independently observed result |
| --- | --- |
| Amended P | 98,213 bytes; SHA-256 `93fdd2f045885e00304ec36aa62215127dc1a957f514605129751dd3ae45218e`. |
| R at audit time | SHA-256 `62f3506229cb78af4997038dd39df139a75a4c535ca169f659bad013ffaf4500`. |
| `E/task-13/source-final.json` | SHA-256 `489cab55f8c500ee85611d232a207aca30f5972cc4e0b4331ccc4dd4e890ae2b`. All **16,405 regular-file** entries match current raw lengths/hashes. The other **4 entries are symlinks**; their link text matches the manifest. Their external targets are unavailable, as the recorded link entries imply; no dependency repair was attempted. |
| `E/task-13/evidence-index.json` | SHA-256 `9a4a0a81fb8050bcb2b707c8280b18daece3620f040cef08c248bd961babe265`. All **63 indexed files** match raw lengths/hashes. This is not the absent task 15 delivery inventory. |
| Source archives | All **36 archive/live-evidence file bindings** in `E/task-3/source-observations.json` match their recorded lengths/hashes. |
| Source runtime identity | Recomputed Keccak for all **34** exact bytecode operands in `task-3/runtime-hash-checks.json`; all match. Each operand also occurs at its named archived JSON pointer or in its named raw log. Shared proxy runtime is not substituted for delegated-facet identity. |
| Source custody/rollback joins | All **14** task-6 category rows' positive and rejection lines match `fork-qa-1.log`; their named positive and negative cases also pass in the final F run. |

| Recorded command | Observed outcome |
| --- | --- |
| `forge build --use solar` | Exit 0 in `task-13/hermetic-r2/03.log.command.json`; retained build output records Solar compilation. |
| `forge test --use solar -vv --no-match-path '**/fork/**' --no-match-contract Fork` | H: **28,641 passed, 0 failed, 0 skipped**, 2,691 suites. Migration: 236 cases/34 suites. Ordinary V4 DETF: 9,560 cases/559 suites; common bond/staking: 372 cases/30 suites. The Weighted-named subset is 2,272 cases/103 suites, not an additive total. |
| All-K artifact-helper fork command | `task-13/fork/03.log.command.json` records exit 0. F records **183 passed, 0 failed, 0 skipped**, 30 suites covering all 26 K test files. |
| Strict operator TypeScript command | `task-13/operator-r2/results.json` records exit 0. |
| `bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts` | O and its sidecar record **exit 1**, 240/1, as preserved above. |
| Delivered-helper TypeScript command | Retained invocation and separate `HELPER_TYPECHECK_EXIT=0` receipt support the recorded exit. `task-13/repair-attempt-1/report.md:19-21` correctly retains the absence of contemporaneous native argv provenance. No new execution or manufactured stdout is claimed. |

The helper provenance limitation is recorded within the already-incomplete task 13 evidence, not used to turn the operator failure green or presented as a new source/conservation/quote/payout defect.

## Source coverage and conservation

`D/source-route-matrix.md:11-24` and `E/task-3/source-observations.json` retain fourteen explicit categories, fixed contracts, source-native units, source selectors, delegated facets, complete ABI shapes and conditional recovery restrictions. The source pin is chain 4663, block 108944663, hash `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`. It authenticates the recorded source observations, not manual compensation prices.

| Source | Distinct units / conservation claim | Final positive and rejection witnesses |
| --- | --- | --- |
| Weighted NFT | Native9 original principal minus actual claimed principal; full-original quote multiplied by remaining fraction; whole NFT consumed. | F:4958-4968; actual assertions in `K/MigrationLegacySources.t.sol:31-52`. |
| Earlier NFT | Original accounting shares, distinct from effective reward weight and physical LP; locked principal remains eligible. | F:4960-4965; `K/MigrationLegacySources.t.sol:102-111`. |
| Weighted liquid DETF | Native9 Q/C with partial/final residue, exact custody and separate expansion accounting. | F:5630-5636; `K/MigrationWeightedLiquid.t.sol:82-132`. |
| Earlier liquid DETF | Native18 Q/C; same-wallet custody, fixed reserve conversion, conditional external enablement. | F:4051-4060; `K/MigrationEarlierLiquid.t.sol:96-146`. |
| Weighted receipt | Eligible original gons are distinct from native9 transfer quantities; nonrepresentable and unsolicited gons remain protected. | F:5640-5647; `K/MigrationWeightedReceipt.t.sol:36-48`. |
| Earlier receipt | Original internal shares, native18 transfer, and NFT-sale external-share/remainder buckets stay distinct. | F:4064-4074; `K/MigrationEarlierReceipt.t.sol:148-162`. |
| Weighted SY | Native9 static shares; backing does not create another original. | F:5660-5665; `K/MigrationWeightedSy.t.sol:284-334`. |
| Direct claim vault | Native19 shares; actual source redemption produces measured native9 SY. | F:4106-4111,5007-5010; `K/MigrationClaimVault.t.sol:43-74`. |
| W-SD | Native28 shares; measured native18 DTF output, no invented decimal divisor. | F:5669-5674,5025-5028; `K/MigrationDtfCustodySe.t.sol:43-74`. |
| W-SW | Native18 SE shares; selected recovery requires actual external enablement and protects unbooked inventory. | F:4129-4139; shared assertions in `K/MigrationHeldSeLp.t.sol:155-205`. |
| E-S | Native18 SE shares; original holder and actual child funding, disabled/dust exits reject without losing custody. | F:4091-4102; `K/MigrationHeldSeLp.t.sol:594-647`. |
| W-P | Native18 physical LP, distinct from NFT shares; actual current-fee-recipient exception is external authority. | F:4115-4125,4940; shared `MigrationHeldSeLp` assertions and source-specific recovery witness. |
| E-P | Native18 physical LP; surrender remains supported, with the narrowly evidenced permanent-custody disposition. | F:4078-4087,4939; `D/recovery-route-disposition.md:28-46` and pinned `task-3/source-custody-live.log`. |
| TokenStaking preparation | Original raw-weight denominator, eligible raw-weight numerator and measured SY are separate. Full-original credit is fractioned once; later SY failure does not restore earlier consumed weight. | F:5651-5656; `K/MigrationWeightedSy.t.sol:70-190`. Known claimed-SY operator-pin exception remains. |

Earlier IDs 0/1/2 are supported by pinned wired-role, ownership and position reads in `task-3/source-reserved-complete.log:7-30`, the runtime-bound initialization evidence, and the final reserved-role rejection F:4985. The supplemental reserved-mint transaction lookup was unavailable; that is not evidence that the IDs are qualifying user positions or that a whole wallet has no exposure.

E-P's conclusion remains source-specific: the recorded owner is the earlier DETF; three native withdrawal selectors resolve to the same owner-restricted facet; parent accepted inputs and forwarding/collector roles do not confer arbitrary LP withdrawal authority. W-P's fee-recipient exception is not imported into E-P. Temporary disablement, dust and absence of present rewards are not classified as permanent inability.

## MIG-P01-P15 and E1-E5

In this table, “witnessed” means the identified local contract/source behavior has evidence. It does not mark missing end-to-end acceptance complete.

| Requirement | Assessment and opened witness |
| --- | --- |
| MIG-P01 | Witnessed. One full-original quote at explicit load, separate components, no configuration mint: H:37052,36733,43754; `M/UniswapV4DetfMigrationWeightedPricingLib.sol:103-145`. |
| MIG-P02 | Witnessed. Stored-credit proportional surrender and final residue: F:4755,5633,5662; source assertions above. No partial nonlinear re-quote. |
| MIG-P03 | Witnessed. Actual remaining fixed principal and original-quote fraction: F:4959,4967; `MigrationLegacySources.t.sol:31-52`. |
| MIG-P04 | Witnessed. Burned/nonexistent/reserved/zero/reward-only positions reject: F:4958,4964. |
| MIG-P05 | Witnessed. Whole identity, replay and cross-representation exclusion: F:4977-4981; H:40140-40141,43763. |
| MIG-P06 | Contract behavior witnessed. Exact custody/funding rollback across categories and both NFT contribution bonds: F:4973-4978,4981. Task 10's operator proof remains absent. |
| MIG-P07 | Witnessed. Fresh actual creation timestamps and 90-day principal cliffs: F:4373,4972; H:36732,43608; `MigrationNftLifecycle.t.sol:98-129`. |
| MIG-P08 | Witnessed. Accrual preserved while reward payout is closed, including mature principal, receipt/SY egress and roles: H:36732,38302-38310,42690-42692. |
| MIG-P09 | Witnessed. Independent configuration/issuance separate from surrender; duplicate originals excluded: H:36733,37051-37052,40140-40141. |
| MIG-P10 | Contract and wire-fixture behavior witnessed: H:43749 and O:152. `MigrationWeightedPricing.t.sol:211-234` preserves issuance, bond, staking and supply after B reload. Task 10's actual operator B/A lifecycle remains absent. |
| MIG-P11 | Contract cut and unset-book activation witnessed: H:43734,42771,37494; `MigrationWeightedPricing.t.sol:287-319`. Mixed-record operator completion remains task 10's known gap. |
| MIG-P12 | Witnessed. Current-owner boundary, real paid purchase and setter after purchase: H:37054,42667-42671,43748,43768. |
| MIG-P13 | Contract bootstrap/no-readiness behavior witnessed: H:36740,37986-37992,43734. Full funding-first operator rehearsal remains the task 10 exception. |
| MIG-P14 | Witnessed for typed contracts and measured selected shapes: F:4997-5021,5032-5058; repeated reward-only assertions at `MigrationRecoveryDonation.t.sol:110-195`; task 11 gas evidence. |
| MIG-P15 | All fourteen category rows have original-wallet/custody witnesses above; F:4985-4989 and category wrong-wallet/Stage 1 tests preserve no-ancestry admission. Claimed-SY operator authentication remains explicitly incomplete. |
| E1 | Source routes, identities, units, custody/rejection and conditional recovery are evidenced by the fourteen rows and 34 runtime checks. No additional unindexed source category found. The known claimed-SY operator defect is not waived. |
| E2 | Contract/source conservation witnessed across all categories, including late child failure, original-wallet restriction, exact Q/C and no raw-weight pull. Missing full operator lifecycle remains task 10. |
| E3, amended | Witnessed for the declared manual models. H:6279-6299,43744-43770 covers canonical differential behavior, adjustment, rounding, limits and unsupported domains. Pure library `:18-145` reuses canonical helpers. No production reserve composition is inferred. |
| E4 | Witnessed by actual registry fixture bootstrap, separately accounted self-leg, zero receipt backing before issuance and funding guards: `MigrationCore.t.sol:43-71`, H:36735,36740,37986-37992. Full CLI bootstrap lifecycle remains unrun under task 10. |
| E5 | Witnessed at contract level by mature-principal/cliff, receipt/SY retention, role release, callback rejection, metadata and ordinary regression tests: H:36732,38302-38310,38464-38468,42660-42663,42690-42692,43608-43609. No additional payout gap found. |

The pricing source inspection specifically confirms fee subtraction once, RawRate floor before scaling, disabled-buffer inventory rating without inflow rating, amount-dependent V3 evaluation, canonical budget/output checks and one final user split. `MigrationWeightedPricing.t.sol:338-408` exercises those distinctions and seigniorage at 100% without allowing zero-credit issuance.

## All 53 acceptance dispositions

Each inherited ID is retained. The status qualification in the final column is part of the assessment; no “known gap” row is represented as satisfied.

| ID | Opened witness | Assessment |
| --- | --- | --- |
| MIG-AC01 | H:36737,42668-42671 | Ordinary Stage 1 acquisition closed except genuine first owner purchase. |
| MIG-AC02 | F:4056,4085,4099,4109,4122,4136,4986-4989,5634,5646,5663,5672 | Stage 1 surrender rejection and postactivation configured admission witnessed. |
| MIG-AC03 | H:36737,42324,43609 | Indirect acquisition/callback/child-authority negatives witnessed. |
| MIG-AC04 | H:36733,42351; task-11 batch limits | Complete replacement/replay and measured batches witnessed; full operator flow remains task 10. |
| MIG-AC05 | H:37054,43768 | Current-owner authorization and rollback witnessed. |
| MIG-AC06 | F:4106,4973-4978,5631,5642,5653-5654,5661,5669 | Source custody and exact issuance rollback witnessed. |
| MIG-AC07 | F:4958-4959,4964,4967 | Original quote times actual remaining fraction; empty fails. |
| MIG-AC08 | F:4961,4964,4967 | Rewards excluded from compensable principal. |
| MIG-AC09 | H:40140-40141,43763; F:4997-4999,5055-5058 | Cross-representation and recovery duplicate protection witnessed. |
| MIG-AC10 | F:5014-5020; `MigrationRecoveryDonation.t.sol:110-195` | Protected new bond unchanged during recovery. |
| MIG-AC11 | Source matrix; F:4960,4064-4074,5640-5647,5651-5656 | LP accounting, fixed principal, gons, shares and weights remain distinct. |
| MIG-AC12 | H:43607 and ordinary/common final suite summaries | Ordinary registered package isolation and regressions witnessed. |
| MIG-AC13 | H:36733,37051; F category surrenders | Separate independent issuance and surrender paths witnessed. |
| MIG-AC14 | H:36732; F:4981,4373 | Compensation cliff and reward-gate class witnessed. |
| MIG-AC15 | P:648; H:43748,43768,43734 | Amended current-owner pricing permission and removal witnessed. |
| MIG-AC16 | `MigrationCore.t.sol:43-71`; H:37986-37992 | Closed-stage capital and separate self-leg backing witnessed. |
| MIG-AC17 | F:5014-5020,5032-5058 | Recovered assets use fixed conversion/donation paths, not ordinary purchase. |
| MIG-AC18 | Fourteen-source table and F | Every required category has source-specific witnesses; claimed-SY operator exception remains. |
| MIG-AC19 | H:36732,43608; F:4373,5365 | Own cliff boundaries and principal timing witnessed. |
| MIG-AC20 | H:38308,38310,42661,42690-42692 | Accrued rights, residue and repeat-claim behavior witnessed. |
| MIG-AC21 | H:37052,6279-6299,43754; pricing library | Full-original canonical fee/split at explicit load witnessed. |
| MIG-AC22 | F:4967,5633,5662; H:43749 | Stored credit/fraction without live or partial-input re-quote witnessed. |
| MIG-AC23 | O:57,60-63,257-265; H origin exclusions | Routed inputs and prior claims do not invent additional originals. |
| MIG-AC24 | H:6287,36736,43749,43734 | Live independence, keep-until-reloaded and post-cut immutability witnessed. |
| MIG-AC25 | F:4373,4972; actual source surrender assertions | Separate actual creation clocks witnessed. |
| MIG-AC26 | `MigrationCore.t.sol:184-214`; H:36731,42771 | Failed-cut rollback and successful removal witnessed. |
| MIG-AC27 | H:42771,37494,43734 | Actual removed selectors and restoration rejection witnessed. |
| MIG-AC28 | H:40134 native lifecycle suite,42771 | Repeated administration cannot alter final lifecycle; absent-selector behavior is admitted. |
| MIG-AC29 | F:4972,5014-5021,5032; H:42576 | Retained surrender, claims, donation and recovery work after cut. |
| MIG-AC30 | H:37488; F:5021; ordinary/common regression summaries | Existing registry boundaries preserved; no separate migration pause introduced by the audited pricing change. |
| MIG-AC31 | H:43734; O:135-165 | No new pricing/finalization prerequisite at contract/wire boundaries. Full resumable funding-first lifecycle remains task 10. |
| MIG-AC32 | F:5008,5026,5047 | Current owner alone selects recovery. |
| MIG-AC33 | F:5040-5043; task-11 signed gas records | Selected-work independence and bounded measured shapes witnessed. |
| MIG-AC34 | F:4997-4999,5018-5019,5034,5048-5050 | Repeat/new-income recovery and overlap accounting witnessed. |
| MIG-AC35 | F:4987,4966,5635,5664 | Original wallet plus actual custody; transfer does not convey configuration. |
| MIG-AC36 | F:4959,4967,4980 | Live principal changes fraction, not stored quote. |
| MIG-AC37 | F:4977,4988; H:43734,42771 | No postactivation configuration/pricing route restored. |
| MIG-AC38 | `MigrationWeightedPricing.t.sol:211-234`; O:152 | B configuration/A issuance preserved in contract and wire fixtures; task 10 proof missing. |
| MIG-AC39 | F category terminal/residue cases; O:236,244 | Wallet-bound credit and source partitions conserved; claimed-SY operator exception remains. |
| MIG-AC40 | F:4755,4978,5631-5633,5653-5656 | Terminal surrender and failed-issuance rollback witnessed. |
| MIG-AC41 | F:5633,5662,4981 | Partial fungibles and whole NFT identity witnessed. |
| MIG-AC42 | `MigrationNftLifecycle.t.sol:98-105`; `MigrationWeightedSy.t.sol:140-157` | Same eligible surrendering wallet receives funded bond. |
| MIG-AC43 | F:4373; H native lifecycle and `MigrationSurface` metadata cases | Transfer preserves own clock and cliff; no Stage 1 reward shortcut. |
| MIG-AC44 | F:5003,5017,5036,5049,5056 | Whole selected batch rollback witnessed. |
| MIG-AC45 | F:5003,5016,5033,5046 | Earlier committed custody remains after later failure; fixed donation destination. |
| MIG-AC46 | H:36739,37498; task-11 construction receipts | Two isolated owners/parents and initialization behavior witnessed. |
| MIG-AC47 | H:37054,42671,43768; F:5047 | Current, pending and former-owner semantics witnessed without invented delay. |
| MIG-AC48 | H:42771,42830,43607,37494 | Real package declarations/routing and reuse checked; not only a copied selector count. |
| MIG-AC49 | H:40139,40215; F:4980-4981; O:185-210 | No configuration mint, proportional NFT credit and two contribution bonds witnessed in narrower tests. Task 10 remains unrun. |
| MIG-AC50 | H:40213,40218,43763; F:4965-4968 | Collection/token identity, stable original and original-wallet ownership witnessed. |
| MIG-AC51 | H:37051-37052,43749; O:152,236 | Distinct-original consolidation and immutable issuance history witnessed; real mixed operator lifecycle missing. |
| MIG-AC52 | O:135-152; H:43749,42771 | Replacement, exact historical domain and same-block completion fixtures pass. Real mined-A/B resume and portable lifecycle remain tasks 10/12. |
| MIG-AC53 | H:36732,38302-38310,38465,38468,42690-42692 | New-instance Stage 1 reward-payout closure and retained rights witnessed. |

## Owner clarifications, arithmetic examples and invariants

| Owner section | Disposition |
| --- | --- |
| 1.1 | Remaining-principal proportionality and amended manual-book precedence are retained; no full-credit-after-withdrawal or partial nonlinear re-quote. F:4959,4967. |
| 1.2 | Actual surrender is required; source conservation replaces transfer-ancestry reconstruction. Category custody tests and O:236,244 support the boundary. |
| 1.3 | Configured original wallet and current control both required. F:4987,4966-4968 and source-specific wrong-wallet tests. |
| 1.4 | Stage 2-only surrender and shared atomic cut witnessed; independent Stage 1 issuance remains separate. H:42771; F category Stage 1 tests. |
| 1.5 | Genuine paid current-owner first bond is required; independent compensation does not substitute. `MigrationCore.t.sol:160-181`, H:42667-42671,43748. Real operator purchase/resume remains task 10. |
| 1.6 | TokenStaking is included through measured claimed SY; plain DTF remains ordinary money. F:5651-5656; O:319-324. Known witness-pin failure is retained. |
| 1.7 | Exact NFT 3 raw18 amounts, two separate quotes, one consumption/two funded bonds and second-callback rollback: O:185-210; F:4978,4981; `MigrationNftLifecycle.t.sol:65-205`. No task 10 or public execution inferred. |
| 1.8 | One full original, original/eligible weight distinction and final SY residue: `MigrationWeightedSy.t.sol:103-190`; F:5653-5656. Known operator authentication gap remains. |
| 1.9 | Three reward-only cycles retain unlocked principal and custody; genuine earlier income and external enablement are explicit. `MigrationRecoveryDonation.t.sol:110-195`; F:5018-5019. E-P exception remains bounded to its authenticated source. |
| 1.10 | Complete manual operands, canonical math, no live dependency, explicit reload only and activation removal: pricing source and H:43734-43770. Mixed operator proof remains the known task 10 gap. |

| P section 8.1 example | Opened witness |
| --- | --- |
| 1 | Actual fixed-principal fraction, `MigrationLegacySources.t.sol:31-52`; F:4967. The test uses the actual source ratio, not the prose's illustrative 100/40. |
| 2 | Invalid/burned/empty and reward-only rejection, F:4958,4964. |
| 3 | Explicit inequality against partial-contribution re-quote, `MigrationLegacySources.t.sol:41-42`. |
| 4 | Exact **333/334/334** actual-proxy test, F:4755. |
| 5 | Separate original quotation/consolidation, H:37052,6296, with wallet exclusion F:4966. |
| 6 | Zero components and zero-output/zero-credit rejection, H:6296,43754,43770; F:5636. |
| 7 | Zero supply/backing on configuration and exact delivered funding, `MigrationCore.t.sol:74-97` and source funding assertions. |
| 8 | Thirty-day-separated source surrenders, `MigrationWeightedLiquid.t.sol:105-117`; F:5633. |
| 9 | Mature principal while Stage 1 rewards stay closed, `MigrationCore.t.sol:129-147`; H:36732. |
| 10 | Delayed first issue and later participant no backdating, H:36734,37053,42667. |
| 11 | Fee/creator retained gons and exact once-only release, `MigrationEgress.t.sol:287-299`; H:38305,42690-42692. |
| 12 | Missing configured entitlement rejects before movement, F:4987 and category missing-wallet tests. |
| 13 | Transferred holder rejection and return without ancestry, F:4966,5635,5664. |

P section 8.2's twelve invariant obligations were checked against the following evidence:

| Invariant obligation | Evidence |
| --- | --- |
| Remaining/delivered wallet credit and residue | F:4143,4755,5068,5365; terminal source assertions above. |
| Matching original wallet and actual assets | F:4987,4966-4968 and category rejection/rollback cases. |
| Correction/setter cannot change execution or old bonds | H:43749,38881; actual B reload assertion at `MigrationWeightedPricing.t.sol:211-234`. |
| Credit requires custody or authorized independent issuance | Source category funding/custody assertions and H:36733,37051. |
| Failed issuance leaves no custody or consumption | F:4978,5642,5653-5654; H:38466. |
| Funded position solvency | Native/active and source-unit invariant runs; `MigrationEgress.t.sol:55-61`; source funding/gon assertions. |
| Own-cliff principal only | H:36732; F:4373,5365. |
| No Stage 1 reward payout | H:38302-38310,38468,42690-42692 and native ledger role-reward actions. |
| No restored Stage 2 administration | H:42771,37494,43734; F:4977-4988. |
| Live movement/book set does not mutate loaded credit | H:6287,36736,43749,38881. |
| Recovery conservation and fixed beneficiary | F:4997-5021,5032-5064; repeated-harvest exact balance equations. |
| Owner change does not alter economic records | Native owner-transition counters and invariants H:39307-39318,40119-40130; H:37054,43768. |

`E/task-8/coverage.md:119-130` maps A0, I1-I3, J1-J3, K1, E6, N1, source spoofing, wrapper overlap, claim races and batch failure. Its E6 limitation is a concrete argument-shape distinction, with old inventory protection still exercised. The named adversarial base has two reported substantive consumers, and the final H run executes their donation, callback, pretransfer and second-child rollback cases. Successful actions, not just handler calls, appear in H:39307-39318 and H:41933-41940; the source invariant results are in F:4143,5068. No new catalog/source waiver is inferred.

## Original tasks, final obligations and residual limits

| Original obligation | F1 disposition |
| --- | --- |
| Tasks 1-2 | Source and pure manual-pricing witnesses available; known claimed-SY operator authentication exception retained. |
| Task 3 | Registry fixture, bootstrap, isolated owners and real children evidenced by H and task 11. Public deployment addresses are not required or approved by this local implementation audit. |
| Task 4 | Expected-book configuration, full replacement and separate immutable issuance evidenced; task 10 real operator proof remains missing. |
| Task 5 | Funded cliff, reward retention/egress and ordinary behavior evidenced in H/F. |
| Task 6 | Fourteen-source surrender/conservation and atomic rejection witnesses available, including NFT 3's narrower fork tests. |
| Task 7 | Actual cut and no-restoration tests pass; real CLI lifecycle remains the task 10 exception. |
| Task 8 | Typed recovery, repeated reward-only harvest, conditional source authority and gas experiments available. |
| Task 9 | Incomplete: known claimed-SY pin, real rehearsal and portable current-chain proof remain open. |
| Task 10 | Final build/hermetic/fork evidence exists; operator aggregate remains red and complete real rehearsal is absent. |
| Original F1-F4 / P section 11 / R final wave | No unconditional closure: task 14 and task 15 records are absent, and known runtime gaps remain. This scoped F1 does not certify other verifier outputs or additive final delivery. |

Task 11's `batch-limits.md` and source-qualified task-13 reuse audit retain two bounded constructions and measured loading/issuance/recovery shapes. Loading 64 one-original recipients, issuance 32 one-original recipients, and one recipient with 64 originals are separate tested axes; they do not approve the Cartesian product. Recovery snapshot-branch receipts are historical experiment receipts, not simultaneous final-chain state. None is used to close the donor/rehearsal exception.

`D/package-evidence.md` and `D/surrender-spec.md` exist. The package record explicitly limits several of its own reads and labels some operational-address or trace details unresolved. Those statements do not by themselves establish a new economic defect: the concrete bootstrap, owner, cut, source custody and funded-payout witnesses examined above supply the narrower local behavior evidence. Complete documentary reconciliation and delivery remain task 14/15 obligations, not silently completed by this report.

No additional blocker was established within the requested source/conservation/quote/payout audit. This is evidence-based approval relative to the named exceptions, not proof of absence of every possible code defect. No fresh chain state, operational eligibility dataset, numerical compensation award, public execution, or complete delivery inventory is certified.
