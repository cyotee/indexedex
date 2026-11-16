# Independent W-L verification: decision-gated handoff

Date: 2026-11-11.

**AdversarialVerify: needs-fix. Acceptance: not-ready.**

The sealed implementation is incomplete. The required
`configureWeightedLiquidEntitlements` production setter is absent, and the
owner's `partial_entitlement_correction` answer remains outstanding.
There are no W-L runtime receipts. This report verifies that concrete
prerequisite failure and the bounded source/evidence state; it does not
accept W-L surrender, recovery integration, or deployment.

The orchestrator explicitly directed this verifier not to invent a
correction rule or attempt configuration/rehearsal against incomplete code.
Accordingly, no new Forge build/test, operator test/typecheck, Anvil,
configuration, surrender, recovery, or interruption/resume run was attempted.
The runtime obligations below are **unrun**, not passing or waived.

## 1. Blocking finding and unresolved decision

### V1: the declared loading route has no production implementation

Locations relative to the assigned worktree:

- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol:294`
  declares the loading function.
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol:184`
  includes its selector in the seven-entry administration inventory.
- `UniswapV4DetfMigrationAllocationFacet.sol:6-10` inherits that target and
  publishes the inventory and allocation interface.
- `UniswapV4DetfMigrationDFPkg.sol:194-198` builds cuts from each facet's
  published inventory.
- `scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol:73-78`
  calls the declared setter; `scripts/recovery/dtf-migration/execution-plan.ts:60`
  schedules it.

The complete allocation target was read. An independent literal search
for `configureWeightedLiquidEntitlements` across `contracts/` returned
exactly two matches: the interface declaration and selector inventory
above. The target contains no setter body. The retained repository has
W-L configuration and execution mappings, but the inspected production
references do not populate a W-L configuration or initialize its Q/C
remainder.

Consequently, publishing a selector and compiling the interface/stage do
not establish callable configuration. The retained surrender preview
explicitly rejects `configured == false`
(`UniswapV4DetfMigrationTarget.sol:59-75`). A fresh, legitimately deployed
instance has no implemented loading path to make a positive W-L surrender
possible. This is a source-confirmed integration blocker, not an observed
failed transaction: no transaction was submitted to manufacture that result.

Required next work belongs to the producer after the actual owner answer:
implement the complete loader and its correction bookkeeping, then supply a
new immutable handoff with executed acceptance. This verifier made no fix,
temporary policy, no-op setter, or substitute state injection.

### Exact unresolved case

Main plan r3 section 5.3 preserves already surrendered units and delivered
credit, applies corrections only to the unconsumed portion, and prohibits
retroactive `newConfiguredTotal - oldPaidTotal` payouts.

The sealed producer example is Q0 = 3, C0 = 1,001; one unit delivers 333,
leaving Q = 2 and C = 668. Correcting the original components to quote C0 =
1,000 leaves the corrected remainder's rounding treatment unspecified.
Subtracting old delivered credit yields 667 but is expressly forbidden as
the payout rule; proportional re-apportionment would yield 666, without
being an approved rule. Replacement Q0 at or below consumed units is also
unresolved. No alternative is selected here. Silence and a question timeout
are not an owner answer.

## 2. Authority, exact state and independent checks

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-13-weighted-liquid`.
Branch: `work/dtf-migration-phase-13-weighted-liquid`.
HEAD and required base:
`2c2b3370ded30cae1662329025d4fb58f7197330`.

Read completely:

- Main-checkout `.omo/ulw-execute/dtf-migration/phase13-weighted-liquid-brief.md`.
- Main-checkout `docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`,
  revision `migration-detf-implementation-plan-r3-original-wallet-entitlement`.
- Phase11 worktree
  `docs/incidents/2026-09-16-dtf-recovery/migration/same-wallet-sources/verification/report.md`,
  `verification/matrix.md`, and `weighted/contract.md`.
- This worktree's `../implementation/report.md`, `bindings.json`,
  `cleanup.json`, and `seal.sha256`.

The root-supplied initial clean checkout and warm-seed exit 0 remain
root/producer evidence; they were not rerun or represented as this
verifier's observation. At verification time the checkout correctly
contains the producer's uncommitted delta, not a clean implementation tree.
Read-only status showed its 27 source/spec/operator/runbook paths plus
weighted-liquid evidence. No ordinary/common/Crane production, configuration
or dependency delta appeared in that status.

Executed independently, from the assigned worktree:

| Check | Result and boundary |
| --- | --- |
| `GIT_MASTER=1 git rev-parse HEAD` and `git branch --show-current` with the same prefix | Exact base and branch above |
| `GIT_MASTER=1 git status --short --ignore-submodules=all` | Existing producer delta retained; prescribed Crane symlink not changed |
| `GIT_MASTER=1 git diff --check --ignore-submodules=all` | Exit 0 |
| `shasum -a 256` on every path enumerated in producer `bindings.json` | All 48 hashes matched, both at admission and at verification close: 27 changed/new files, five authority/handoff inputs, eight artifacts and eight logs |
| `shasum -a 256 -c docs/incidents/2026-09-16-dtf-recovery/migration/weighted-liquid/implementation/seal.sha256` | All three entries OK; exit 0 |
| Literal source searches and direct code reads | Confirmed V1 and the bounded static observations in section 3; not behavioral test execution |
| `lsof -nP -iTCP:18563 -sTCP:LISTEN` | No rows; exit 1, meaning no listener found in this check |
| Checkpoint existence and warm-directory/link checks | Fixed checkpoint absent; `out/`, `cache_forge/` and linked `lib/crane` retained |

Verified producer seal identities:

| File | SHA-256 |
| --- | --- |
| `implementation/report.md` | `16e84b65ed405a1956be793da7b5e5b859f24b6c98cd81aaf151e38fd17c9334` |
| `implementation/bindings.json` | `eb964802171dd822133be5b6480b9aa6a4f10fab1545bc3f578c855b5c37c661` |
| `implementation/cleanup.json` | `039d96df2b853ba240df75e33108fe33b523f043c41a4a8a9281b0cb2a201f3f` |

The seal describes a deliberate immutable **incomplete** state, timestamped
`2026-11-11T12:12:14.681Z`, not a temporary-idle readiness signal. Its
`runtimeAcceptance` is false and `realTransactionReceipts` is empty.

## 3. Final source/runtime/operator parity

For this table, M denotes
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`
and O denotes `scripts/recovery/dtf-migration/`, both in this worktree.
These are static observations only.

| Surface | Observed source | Acceptance boundary |
| --- | --- | --- |
| Original record | `M/interfaces/IUniswapV4DetfMigration.sol:137-161` separates explicit configured state, full wallet/source/origin/Q0/components/evidence input, configuration ID/C0, and consumed/delivered/remaining state | No loader enforces, computes or initializes these values |
| Admission and arithmetic | `M/UniswapV4DetfMigrationTarget.sol:59-113` checks configured state, chain 4663/fixed WD, positive bounded q, final remaining C or full-precision partial floor, positive credit, original wallet and minimum before transfer; deadline and parent/child admission guards surround the operation | Missing-config source guard is visible; wrong-wallet, custody and positive execution have no new runtime proof |
| Pull, booking and funding | The same target measures exact wallet decrease and Migration increase, increments consumed/delivered facts, decrements remainder, books only q as WD recovery inventory, settles expansion, then calls `M/UniswapV4DetfMigrationRepo.sol:66` `_fundBond` | The funding primitive mints credit, uses the fixed child's `createMigrationPosition`, and clears approval; exact backing, clock and rollback remain unexecuted for W-L |
| Known-origin collisions | Allocation target rejects configured W-L origins in independent configure/issue and NFT configure | Reverse W-L checks and replacement consistency belong to the missing setter. This is not a global proof against opaque aliases |
| Selected recovery | `M/legacy/MigrationLegacyRecoveryLib.sol`, `convertWeighted`, debits booked WD, approves WD itself, decodes the one-word exchange return, clears approval, checks exact input/positive DTF output, and books output | Existing finite primitive is present; direct W-L surrender-to-conversion integration has not run |
| Donation floors | `M/UniswapV4DetfMigrationRecoveryTarget.sol`, `recoverMigrationNfts`/`_donateRecovery`, retains current-owner selection, fixed DTF donation and booked debit. `M/UniswapV4DetfMigrationPolicy.sol` maintains operation floors | Unbooked holdings, other recovery, prior donation budgets and backing require actual new integration assertions, not a raw-balance inference |
| Activation | Allocation target removes its inventory and allocation interface; retained facet lists W-L queries/preview/surrender separately | Advertised removal is not evidence that the setter was callable before activation. Removal, restoration resistance and postactivation W-L success are unrun |
| Existing NFT path | Target still checks the configured original wallet and live holder before the safe pull, expected callback and post-custody checks | No final-source NFT regression was executed here; existing acceptance is retained historical evidence |
| Operator tuple/hash | `O/weighted-liquid.test.ts:58-86` compares interface and typed-stage tuples and computes full configuration hashes | The producer's passing ABI test does not compare against an implemented allocation target or execute a proxy call |
| Operator reconciliation | `O/execution-state.ts:125-144` checks configured identity, original wallet, credit and event fields, then queries surrender state | No actual configuration receipt/state pair exists; correction remainder reconciliation cannot be accepted before the owner rule and loader exist |
| Local witness | `O/rehearsal-weighted-liquid.ts` writes partial/final/source-binding observations only after actual checks; `O/rehearse.ts:199-203` places partial use before activation and final use after it | These are written scenarios, not receipts. The retained mined-interruption/resume scenarios were not executed on this source |

Thus source/interface/operator declarations are only partially aligned.
**Source-to-runtime parity is not established, and the missing loader makes
the advertised loading surface incomplete.** This review is not an
exhaustive defect audit of every unexecuted test or operator branch.

## 4. Executed coverage versus absent runtime acceptance

New verifier runtime coverage: **zero tests and zero transactions**.
The independently executed checks are the read-only identity, hash, source
and cleanup checks in section 2.

Producer evidence was read and hash-bound, not rerun:

| Evidence | Observed output / attributed result |
| --- | --- |
| `implementation/artifact-build-independent.log:1-8` | 142 roots, 900-source closure, 112 runtime artifact IDs; Solar 0.8.38 successful with warnings. Producer reports exit 0 |
| `implementation/operator-stage-build-solar-path.log` | One-file Solar build successful; producer reports exit 0 |
| `implementation/regression-compile.log` | Two W-L test files compile successfully; producer reports exit 0. No `forge test` result |
| `implementation/operator-tests.log` | 56 pass, 0 fail across three files; producer reports exit 0. Includes three W-L schema/payload/ABI tests, not EVM custody |
| `implementation/types-final.log` | Empty successful-output artifact; exit 0 is attributed to the sealed producer report, not inferred from emptiness |

Retained failures are explicit: initial stage build could not find Solar
without the corrected PATH; initial types invocation reported TS2688 for
missing Bun declarations. The producer records successful corrected commands.
Compiler/lint warnings remain in the bound build log; this verifier did not
review all 4,456 lines or certify every warning as harmless.

| Required acceptance | This handoff |
| --- | --- |
| Real registry package plus pinned actual WD source/routing | Not deployed or exercised by this verifier; phase11 legacy evidence only |
| Missing configuration, wrong wallet despite control/approval, insufficient balance/allowance | Unrun; no new failed-call receipts or rollback measurements |
| Owner/Stage1 configuration, known Q0/components, frozen C0, idempotence and correction | Blocked by absent loader and unanswered correction rule |
| Partial/final rounding, residue, consumption, zero-credit dust and prior consumption | Formula inspected; runtime unrun |
| No personal supply at configuration/unclaimed records | Unrun for W-L; absence of a setter is not a passing no-mint test |
| Exact fresh funded 90-day bonds and separate creation clocks | Unrun |
| Callback, transfer, minimum/deadline and funding rollback | Unrun |
| Book-only WD admission; selected conversion/donation; unbooked/reserved/backing floors | Retained source inspected; new integration unrun |
| Recovery does not issue additional personal credit; staged failure preserves prior committed stages | Unrun for the new direct-surrender composition |
| Stage1, activation removal, restoration negatives and postactivation surrender | Unrun |
| Preserved NFT, independent-allocation and ordinary behavior | No final-source regression run; unchanged ordinary/common production was not broadly retested |
| Real CLI partial/final, negatives and recovery | Unrun; no W-L transaction receipts |
| Actual donation/issuance mined interruption, fresh-process resume, meaningful remaining-row reordering and unclaimed zero supply | Unrun on this final source; prior-phase receipts are not substituted |

The fixed `rehearse` invocation in the brief/runbook remains unrun: archive
alias `robinhood_mainnet_alchemy`, fork block `108944663`, port `18563`,
checkpoint `.omo-runtime/dtf-migration-weighted-liquid/checkpoints`.
It was not launched merely to fail at known-missing configuration.

## 5. Retained original-allocation and deployment limits

W-L here is only native nine-decimal nonrebasing WD at
`0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7`. No DTF conversion rate
is inferred for compensation.

The fixture record in `O/rehearsal-data.ts:129-135` uses wallet
`0x082cb14f04d9c485473dedc00d604d7e9abca303`, Q0 `21225531`,
original ETH `10000000000000000` wei and original DTF `0`.
These are explicitly synthetic original inputs, not approved real records.
Holdings prove at most a custody bound, never original wallet eligibility,
Q0, contribution allocation or a frozen compensation quote. Unknown
components/quantities may not be filled with zero or live balances.
Canonical-origin partitions and real operational allocations remain
separate prerequisites even after code and local tests become complete.

Phase11's historical source domain remains chain 4663, block 108944663,
hash `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
state root
`0xb1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071`.
Those are retained evidence identities, not fresh RPC results or the new
funded Migration snapshot. No such snapshot was created in this verification.

The original-wallet baseline's **42,985,865-gas** local parent deployment
and historical **32,000,000** maximum transaction gas limit remain
attributed qualifications in the producer report/runbook. They were not
remeasured for W-L. Even successful execution on the permissive local
approximately-43-million-gas deployment would not prove target-chain
feasibility. The held phase09 candidate was neither inspected nor reused.

No other category is accepted by this report. Weighted receipts/SY,
earlier assets, claim/TokenStaking rights, SEs and fungible LPs retain the
phase11 configuration, unit, integration, caller or disabled-route gaps.
No full-category migration, public deployment, funding, activation or
approved compensation execution is claimed or authorized.

## 6. Cleanup and final disposition

Only this verification `report.md` was authored. Producer source, tests,
scripts, runbook, seal and historical evidence were left untouched.
No fixes, commits, merges, model/provider changes, dependency/configuration
changes, external messages to people or public actions were performed.

This verifier started zero nodes, zero impersonations and zero runtime
tests/rehearsals. All read-only shell checks completed. Port 18563 had no
listener and the fixed checkpoint was absent at cleanup. No verification
runtime or subscription is pending; no other task's processes were stopped.
Warm artifacts and dependency links remain in place.

**Final bounded verdict: needs-fix / not-ready.** The immutable incomplete
handoff is accurately labeled, but W-L acceptance is not complete. The next
prerequisites are an actual relayed owner correction decision, the producer's
implemented loader with matching tests/operator bookkeeping, and a new
sealed handoff after real local acceptance. This report closes the authorized
missing-prerequisite verification; it does not choose that decision or turn
the absent runtime coverage into a pass.
