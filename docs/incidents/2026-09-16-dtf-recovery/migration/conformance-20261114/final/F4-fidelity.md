# F4 ideal-state fidelity

Date: 2026-11-15.

Disposition: **APPROVE**, under this assignment's landed-evidence rule. No new fidelity gap was found beyond the named `[~]` gaps. This does **not** certify complete implementation, a successful full operator run, task 10's lifecycle, or complete final delivery.

The current assignment expressly says a known `[~]` gap alone is not a new defect. That governs this verdict rather than treating the original plan's all-tasks-complete prerequisite as satisfied. Tasks 7, 10, 12, 13, 14 and 15 remain incomplete. No plan checkbox is changed.

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`.

Plan: `/Users/cyotee/Projects/indexedex/.omo/plans/dtf-migration-conformance-remediation-20261114.md`. The seven ideal-state statements and their proving scenarios were read, including the success mapping at lines 619-629 and F4 at lines 605-609.

Paths below are relative to the worktree:

- `D`: `docs/incidents/2026-09-16-dtf-recovery/migration`.
- `E`: `D/conformance-20261114`.
- `M`: `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration`.
- `S`: `scripts/recovery/dtf-migration`.
- `T`: `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration`.
- `K`: `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration`.

## Findings

New gaps: **none**.

The inspected implementation and landed witnesses do not force old allocations to reload, impose global pricing freshness at activation, change an economic original when pricing changes, waive a required source category, or turn routine reward harvest into principal withdrawal. Missing integrated lifecycle proof remains missing; it is not supplied by passing lower-level tests.

## IS-1 through IS-7

| Row | Landed evidence and assessment | Remaining named boundary |
| --- | --- | --- |
| IS-1: original wallet, units, custody and conserved credit | `D/surrender-spec.md` was read completely. `E/task-3/source-observations.json` names fourteen fixed source/generation rows, and `E/task-6/source-results.json` has fourteen PASS rows with positive, atomic-rejection and conservation witnesses. The categories cover both NFTs, both liquid DETFs, both receipts, static SY, direct claim-vault rights, DTF-custody SE, both SE/LP generations, and TokenStaking preparation. The current all-K output records 183 passes with no failures or skips (`E/task-13/fork/03.log:5677`). Stable NFT identity is exactly chain/proxy/collection/token ID, without the book (`M/legacy/MigrationLegacyNftLib.sol:20-24`; `S/payloads.ts:65-67`). Original principal, receipt gons/internal shares, SY shares and physical LP remain distinct units. No category waiver was found. | Task 7/13's claimed-SY witness-pin failure remains an operator authentication gap. Source-specific external enablement/income/authority conditions remain explicit. This row does not approve a holder dataset or infer financial eligibility from current holdings. |
| IS-2: canonical manual Weighted calculation | The single evaluator reuses canonical Weighted, frozen V3 quote, claim-budget/output and mint-split functions (`M/UniswapV4DetfMigrationWeightedPricingLib.sol:89-145`). RawRate inflow floors before scaling; DisabledBuffer inflow remains net; V3 input is amount-dependent; separate originals reuse one unchanged book. `E/task-4/differential-vectors.json` contains four mode results, the doubled-V3-input vector and 6/18/24/36-decimal vectors. Current raw passes include differential endpoints, max-in, real-pool independence and V3 backing/supply (`E/task-13/hermetic-r2/04.log:6281-6299`), and manual modes/rounding/structural rollback (`:43734-43769`). No replacement pricing algorithm or live-state dependency was found. | `D/quote-evidence.md` exists but is the November 10 frozen-snapshot report, not the missing task-14 manual-book reconciliation. Its one-shot capture and live facet-recognition statements are historical. No numerical award or live reserve composition is approved. |
| IS-3: one current-owner setter until the existing cut | `administration` checks current ownership, Stage 1 and idle children; the setter validates and overwrites only pricing bytes (`M/UniswapV4DetfMigrationAllocationTarget.sol:37-56`). It has no paid-purchase freeze or separate readiness flag. Activation requires the paid owner-first bond and removes all sixteen administration selectors, including the setter (`:267-303`). The real-proxy test sets pricing after the paid purchase without changing its position (`T/MigrationWeightedPricing.t.sol:257-264`); its current pass is `E/task-13/hermetic-r2/04.log:43748`. Unset-pricing activation also passes at `:43734`. `E/task-4/proxy-census.json` and `D/package-evidence.md:48-92` retain the actual cut evidence. | Task 10's `unset-pricing-owner-bond-activation.json` is absent. Contract tests and source tracing do not replace that complete CLI receipt. |
| IS-4: registry/children, paid activation, fresh funded cliffs and reward gates | `D/package-evidence.md` was read completely, including its limits on public addresses and undecoded historical values. Current source separates configuration from issuance and funds the stored credit once (`M/UniswapV4DetfMigrationAllocationTarget.sol:59-103,105-127`). The final raw suite includes Stage 1 role retention and activated release (`E/task-13/hermetic-r2/04.log:38305`), real token-URI cliff boundaries (`:43608`), fresh-position/activation witnesses (`:39322,39728`), and cut/ordinary-package coverage described by `E/task-8/coverage.md:50-77`. The full hermetic result is 28,641 passes, zero failures/skips (`:64138`), with ordinary V4 and common bond/staking suites identified in task 13's report. No weakened money-path obligation was found. | Task 10's integrated paid purchase, activation and NFT 3 two-funded-bond/second-callback receipts remain absent. Aggregate suite success is not a substitute. |
| IS-5: repeated reward recovery retains principal/custody | The weighted reward stage calls `claimRewards`; principal and combined claims require different explicit stages (`M/legacy/MigrationLegacyRecoveryLib.sol:177-206`). Earlier reward recovery checks both retained NFT ownership and unchanged original shares (`:435-453`). The three-cycle maturity tests assert unchanged principal/claimedPrincipal, original shares, NFT ownership and protected compensation state (`K/MigrationRecoveryDonation.t.sol:110-195`). Both pass on the final tree (`E/task-13/fork/03.log:5018-5019`). `D/recovery-route-disposition.md` keeps conditional source enablement and the earlier physical LP's immutable owner-only permanent custody separate. No principal-withdrawing routine harvest was found. | Task 10's end-to-end recovery lifecycle remains unproved. Task 11's signed gas samples are bounded experiments; its WeightedClaim samples are explicit combined-claim operations, not evidence of reward-only harvesting. Snapshot-branch receipts do not all survive on one final chain. |
| IS-6: mixed A/B operation, B configuration/A issuance, two NFT 3 bonds | Current configuration and immutable issuance are verified independently (`S/execution-state.ts:285-353,388-408`). Historical execution/preparation/journal domains are reconstructed (`S/execution-domain.ts:163-225`); retained rows are not scheduled for configure (`S/execution-plan.ts:60-80`). Saved manifests authenticate evidence without reacquiring credits (`S/preparation.ts:223-250`; `S/quotes.ts:233-249`). The task-12 offline relocation passes and the separate differing-credit test support those branches, as detailed below. NFT identity and separate-contribution preparation remain intact. | Task 10's actual mixed/same-block/donation/NFT 3 lifecycle receipts and task 12's real portable current-chain proof remain absent. The offline fixture does not exercise actual activation or NFT 3 surrender. |
| IS-7: source-qualified results and complete task-owned delivery | Task 2's retained delivery receipt records `completed:true`, no failures and its explicit concurrent-scope qualification. Both required programs exist at `D/resumed-integration/record-verification.ts` and `verify-bounded-deployments.ts`. Surrender/package documents are present and candid about their evidence limits. Task 13 retains the failing operator result rather than claiming a full pass. No additional omitted program was identified in the inspected delivery scope. | Task 14's final traceability and current documentation reconciliation are missing; task 15's final inventory/receipt is absent. Complete final delivery, including final-wave additive closeout, is not certified. This is the existing task-14/15 gap, not a newly discovered omission. |

## Strongest counter-case: B configuration and immutable A issuance

The contract permits explicit replacement of an issued recipient's configuration without replacing its issuance. `configureIndependentAllocations` writes the allocation and configured-original index, permits an original already issued to the same recipient, and does not write `issuances` (`M/UniswapV4DetfMigrationAllocationTarget.sol:59-103`). Issuance rejects an already-issued recipient before creating another bond (`:111-127`). The real-proxy assertion sequence changes pricing, confirms A's stored configuration survives that setter, explicitly reloads B, and checks byte-identical issuance, position, staking state and supply, followed by rejection of a second issue (`T/MigrationWeightedPricing.t.sol:215-234`). Its final-tree PASS is `E/task-13/hermetic-r2/04.log:43749`.

The operator first verifies B's complete current allocation and per-original credits. It then obtains A's original accepted configuration through `issuedHistory`, compares the immutable issuance against A's ID/credit, authenticates A's independent issuance domain/receipt, and checks its bond ID and creation time (`S/execution-state.ts:388-408`). Bond verification preserves principal/start/90-day duration and checks canonical claims/retirement and current escrow solvency (`S/execution-owner-bond.ts:27-72`). `S/execution-state.test.ts:233-255` deliberately gives B one more unit of credit than A: B/A verifies, while mutating immutable issuance to B's larger credit is rejected. That is synthetic wire coverage, not an EVM receipt.

Activation invokes this per-record verification (`S/execution.ts:124-134`); its preflight imposes current-book equality on an **unsent configure** operation only (`:42-87`). Retained rows generate no load. Evidence-only rehydration does not call the current preview. The configured-origin census starts at the authenticated deployment block, so old A rows cannot disappear merely because B was later set (`S/execution-state.ts:364-386`). These checks distinguish complete configuration coverage from an all-records-current pricing rule.

**Task 12 is synthetic transport only.** `E/task-12/mixed-fixture.ts:64-118,120-160` supplies encoded reads, offline signed transactions, invented block entries and wire receipts. Lines 184-212 construct B for the same independent recipient while retaining an A SY row and A issuance. No fixture transaction was submitted to an EVM. B's quote entries are copied from A with B's ID at lines 193-195; that relocation fixture proves differing provenance, not differing numerical prices. The separate task-7 state test above supplies the differing-credit check.

Task 12's useful result remains real: actual bundle export/materialization and validation code relocates 27 archived files to two fresh locations while preserving four historical contexts per location. Preview responses are deliberately undecodable after setup (`mixed-fixture.ts:238-242`), so an accidental current-price re-quote fails. The raw output reports the mixed case, read-only validate/verify and tamper rejections, then 91 passes/zero failures (`E/task-12/final.log:1-110`). `audit.json:1-15` explicitly says `taskComplete:false`. Its archived completions are synthetic outputs, not task-10 lifecycle receipts.

Task 7's `attempt-5/forge.log:3357-3369` separately records a successful local Foundry mixed-record script and state trace. Its `historicalJournalImported:false` at line 3366 prevents treating it as the missing portable CLI rehearsal.

## Existing gaps and document presence

- Tasks 7 and 13: the fixed claimed-SY witness pin remains red. `E/task-13/operator-r2/04.log:88-110` records actual `0x33a0fe038a5d441aa3d9fe48b841bcfc0d0f00f0b085e44b9c41b9b0a7aab2bc` versus expected `0x4ae06bcb278766df6529bcd60e05453fee6c853f6536b9f18d2a4d0dac8fd899`. Lines 329-331 record 240 passes and one failure; `operator-r2/results.json` records exit 1 and `completed:false`. No pin was changed or source category waived.
- Task 10: its fixed authority bundle lacks admissible provenance for the 10,000 DTF donor budget. The recorded blocker is transport/provenance, not global token scarcity. The done claim explicitly lists missing `mixed-pricing.json`, `same-recipient-config-b-issuance-a.json`, `same-block-config-a-then-b.json`, `unset-pricing-owner-bond-activation.json`, `donation-identity-resume.json`, `nft-three-two-bonds.json`, `nft-three-rollback.json` and `rehearsal-location.json` (`.omo/ulw-execute/dtf-conformance/task-10-done.json:76-87`). Direct checks found none at the named task-10 locations. No such receipt is invented here.
- Task 12: real portable current-chain proof and real owner-purchase/donation reconciliation remain unmet.
- Task 14: `D/quote-evidence.md` is present, dated November 10, 2026; `D/verification.md` is present, dated November 13, 2026. Both were read completely. They retain historical snapshot-era/source-bound claims and are not current final-wave completion records. `E/task-14/traceability-review.md` is absent. The missing item is their final reconciliation, not the historical files themselves.
- Task 15: `E/task-15/delivery/delivery.json` is absent. Task 2's earlier delivery cannot certify later-created files or final-wave closeout.

These boundaries were already named in the plan and prior task evidence. None is relabeled as a new F4 defect or silently closed.

## Evidence consistency and review limits

Read-only raw-byte comparisons matched all 209 entries under the migration contract, operator, migration specification-test and migration fork-test paths selected from `E/task-13/source-final.json`. All ten source bindings in `E/task-12/final.argv.json` also matched current bytes. This checks the selected recorded sources; it is not a full delivery inventory or a fresh build.

The following raw SHA-256 fingerprints were computed during this review:

| Artifact under E | Bytes | SHA-256 |
| --- | ---: | --- |
| `task-3/source-observations.json` | 211316 | `82233f20f3eb4ba21ee927a4f421b75615e57f9ee0f426ad4a6a1cb93b5a465a` |
| `task-6/source-results.json` | 173171 | `18be4bf6765ca37b902ad85931117b41e50018efbf66218ce31d03e302493054` |
| `task-4/differential-vectors.json` | 22582 | `7848b46124546ecb368930dda750d41c491984406c7c4e92ef4d3898470f3ea6` |
| `task-12/portable-integrity.json` | 1768173 | `4d00449771af2ba9d6c05b898aa6b0ed641877145158eecb6f439368cfc632bc` |
| `task-13/source-final.json` | 3766536 | `489cab55f8c500ee85611d232a207aca30f5972cc4e0b4331ccc4dd4e890ae2b` |

This review used local file reads, JSON inspection and hashing. It ran no tests, builds, project scripts, Git commands, RPC calls or public transactions, and delegated nothing. Recorded test results are prior execution evidence. It made no implementation change. The only authorized writes are this report followed by `.omo/ulw-execute/dtf-conformance/F4-verdict.json`.

APPROVE means the landed evidence remains faithful under the user's scoped F4 decision rule. Full conformance and delivery remain incomplete until their existing owning tasks supply the missing results.
