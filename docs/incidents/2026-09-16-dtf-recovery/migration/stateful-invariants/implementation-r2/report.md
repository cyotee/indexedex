# Stateful invariant closure candidate

Date: 2026-11-12.
Base remains `15fd629375edeb361f6a39262795bdc66723ca3a`.
Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-24-stateful-invariants`.
Branch: `work/dtf-migration-phase-24-stateful-invariants`.

**Disposition: complete bounded twelve-property/supported-unit closure
candidate, verified by the producer and stopped for independent r2
verification.** All six numbered closure gaps have executable coverage.
No genuine SUT defect was established. This is not an independent verifier's
verdict, a commit, or broad/full-plan acceptance.

The candidate contains 14 source files: seven prior owned files extended,
six new files, and the unchanged capture library. Every source is within the
three permitted invariant directories. No production, existing non-owned
test/TestBase, operator, configuration or dependency source changed.
Source writes stopped at **2026-11-12T18:23:41.924Z**, before final gates.

## Final executed checks

| Gate | Result |
| --- | --- |
| Complete current Migration specifications, including native invariant directory | 171 passed, 0 failed/skipped; 30 suites; exit 0 |
| Complete pinned Migration forks, including both invariant targets | 147 passed, 0 failed/skipped; 26 suites; exit 0 |
| Required focused ordinary regressions | 58 passed, 0 failed/skipped; 8 suites; exit 0 |
| Native lifecycle invariant | 32 runs, depth 16, 512 selected calls, zero unexpected reverts/discards |
| Native active/later-funding invariant | 32 runs, depth 16, 512 selected calls, zero unexpected reverts/discards |
| Legacy SY/NFT/recovery invariant | 32 runs, depth 16, 512 selected calls, zero unexpected reverts/discards |
| Nine-source-unit invariant | 32 runs, depth 16, 512 selected calls, zero unexpected reverts/discards |

The complete final gates ran once each against the stopped candidate:
**376 tests and 2,048 generated invariant calls**. Fail-on-revert is explicit.
Native seed is `0x24c1`, fork seed `0x24c2`, ordinary seed `0x24c3`.
Both native fixtures deliberately share the reproducible native seed but have
different lifecycle/funding starting states; independent random seeds are not
claimed for those two fixtures.

Every gate used `python3 scripts/forge-artifacts.py test`, with the expanded
artifact-first `forge build --use solar` preceding `forge test --use solar`.
The fork command explicitly names the concrete added unit handler and the
complete Migration directory, not just old top-level tests.
`final-execution-plan.json`, `execution-results.json` and the three
`*-final-01.log` files retain literal commands, expanded commands, exits,
all results and full raw output. The six ordinary roots are the same focused
staking math, staking sequence, V4 bindings, weighted production SE,
fee/creator and trust-flag roots required by the original verification.

Compiler metadata is `0.8.38+commit.e7a91fc7.solar.0.3.0-dev`,
optimizer enabled/runs 1, viaIR false. No size override was supplied.
Existing compiler/nightly/configuration warnings remain in raw logs.

Fresh final Solidity diagnostics were clean for 11 files. Three fresh
requests timed out: `MigrationSourceUnitsLedger.sol`,
`TestBase_MigrationSourceUnits.sol`, and `MigrationLegacyInvariant.t.sol`.
Their final Solar compilation and execution passed. The earlier checksum
diagnostic was corrected before final compilation. Biome is unavailable;
JSON was parsed and byte-audited without installing anything.

## Closure of the six required gaps

1. **Persistent actual NFT custody.**
   `MigrationLegacyHandler.assertAll` checks actual legacy `ownerOf` for both
   whole sources after every action and at invariant boundaries. Expected
   ownership comes from original identity, successful custody and an explicit
   permitted-burn model, not the Migration custody record. The added unit
   machine also checks actual earlier NFT custody until its real mature sale,
   then actual absence and preserved consumed identity.

2. **Mandatory missing records and actual control.**
   Missing ordinary-SY and both NFT records reject before randomization,
   independently of exhaustion. Both NFT sources exercise actual no-approval,
   transfer-away/wrong-wallet/lost-control and return-to-original witnesses.
   Each added unit executes missing-record, no-approval and real
   transfer-away/wrong-wallet/return checks, with exact source-specific errors
   and unchanged economic state. Every row then successfully surrenders.

3. **All-position claims and later fresh clocks.**
   Native selection now ranges over every tracked position, including later
   independent allocations, the owner-paid bond and later paid bonds.
   Ordinary purchased positions retain linear terms; compensation/surrender
   positions retain their own cliffs. Legacy and all-unit machines track
   holders, claimed principal, remaining gons and retirement for every new
   position. Dedicated successful sequences exercise later creations before,
   at and after their own cliffs, rather than only reading start fields.
   The deterministic legacy sequence pays **1,292,280,890 native new-DETF
   principal units**. The mixed all-unit sequence pays **1,330,910,174**,
   including its separately tracked independent and NFT positions.

4. **Every missing admitted source-unit ledger.**
   The new fixed-unit machine executes W-L/native9, E-L/native18,
   W-R/original gons with native transfer, E-R/exact internal shares,
   C/direct native19 shares, W-SD/native28, and distinct W-SW/E-P/W-P/native18
   sources. It preserves original Q/C, actual holdings, exact allowance
   spending, unbooked floors, custody, recovery and new escrow separately.
   Acquisition reuses actual admitted donor/staking/deposit/collector-release
   fixtures; no source balance, code, role or storage is fabricated.

   Every deterministic source row has three actual successful surrenders and
   one actual late funded-receiver rollback. Seven scalar rows finish Q=C=0.
   W-R retains Q=`419661796441813012824673292252566920` gons and C=`30578`;
   E-R retains Q=`392519172024864887958474` internal shares and C=`556`.
   Both reject a positive over-cap transfer rather than confiscating residue.
   These are actual final bounded witness values, not a promise of future
   representability.

   Real C redemption/SY recovery mixes with standalone WS gons. A real earlier
   NFT sale produces **485044501927175493321 external ER shares**, kept
   separate from standalone internal B and protected fractions; the actual
   ownership check uses E*1e9+B. ED rewards do not enlarge E-L originals.

5. **Later paid capital and nonzero reward/index growth.**
   The active native prelude makes two later genuine paid ordinary purchases.
   Further purchases are stateful actions. The independent ledger credits
   principal before the purchase's reward distribution, computes both integer
   allocation/rebase stages, retains both dust partitions and top-up-only
   standing weights, and distinguishes deferred Stage1 role gons from active
   role delivery. It never copies the asserted post-funding staking result.
   The retained native lifecycle sequence records two later paid bonds and
   **33003 native reward units**; the active sequence records four and
   **53930**. Actual funded index decreases are asserted.

6. **Complete property and canonical-origin matrix.**
   `coverage-matrix.md` contains all twelve plan rows, source/assertion
   locations, independent expectations, mandatory witnesses, source-unit
   distinctions and precise limits. The all-unit prelude makes **99 exact
   canonical-origin exclusion checks**: 72 directed competing source pairs,
   nine source-to-independent collisions, and 18 current/issued independent
   origin exclusions after a real issuance and configuration replacement.
   Input-derived configuration and immutable issued-history hashes survive
   activation, consumption, claims, rate changes and ownership transitions.
   Ordinary ownership transfers never move configured original compensation.

## What the counters mean

`execution-results.json` retains every generated selector count and named
metric with its raw-log line. Each invariant table sums to exactly 512.
Those tables aggregate generated calls; handler success/rejection counters
include mandatory setup/prelude and describe only retained sequences or
explicit deterministic tests. They are **not** all-run success totals.

The retained legacy sequence records 27 successful actions, 18 exact
rejections, five committed funded callbacks, one late issuance rollback,
one recovery-batch rollback and nine recovery stages. Its retained principal
payout is zero; the separately executed cliff witness supplies the actual
positive payout above. The retained unit sequence has at least two successful
surrenders and one late funding rollback for each of the nine sources,
12 recovery stages, 99 enrollment rejections and an actual ER rate increase.
Its positive cliff payouts likewise belong to the named deterministic sequence.
Zero claims, exhausted-record rejections and prerequisite fallbacks are not
misrepresented as positive nominal-action witnesses.

## Model decisions and limits

The selected design uses explicit original-unit inputs, fixed pre-mutation
quote anchors and independent transition ledgers. It rejects scalar
normalization across gons/internal/native units, current-SUT-value echoes,
revert-only coverage and lucky-selector prerequisites.

Initial nonlinear quote anchors prove subsequent immutability, not an
independently reimplemented nonlinear pricing oracle. Current complete
snapshot tests remain the separate pricing supplement. High native mint
thresholds bound automatic expansion at zero while allowing the required
real later paid/reward funding; arbitrary epoch-expansion modeling is not
claimed. Legacy fixture starting supply/backing/index are observed baselines;
subsequent custody/issuance/claim deltas are independently tracked.

Four bounded state machines are not exhaustive state exploration or
all-selector fuzzing. The full existing reward/SY/RT/egress, pretransfer,
package/surface, preactivation callback, NFT pre-custody race and source
negative suites are honestly identified as supplements in the catalog matrix.
They are not relabeled as new randomized transitions.

## Preservation and executable identity

Original `implementation/` and `verification/` remain byte-identical, with
exact original memberships of 22 and 13 files. All 17 original authorities
match. Complete original reports, seals, candidate manifest/patch and authority
bytes are losslessly preserved. Before any r2 build, all **179** artifacts
in the union of the first producer/independent binding collections were
captured: **34,108,200 raw bytes**, with hashes, lengths and modes.
Every one matched its prior binding. The old failure logs and qualifications
remain intact.

The new raw owned-index baseline and final comparison agree at
`0aac78e6504612422343709283b720e3628f7e43a04df63575f91130d58000b0`,
2,073,604 bytes, mode 33188. This is not a retrospective raw-byte attestation
of the first verifier's explicitly qualified decoded-string digest.
HEAD/ref bytes and both dependency link targets/modes/inodes are unchanged.

Final binding covers **189 artifacts**, **979 distinct compiler-source
comparisons with zero mismatch**, all 14 candidate files, **13 actual
subject records**, **1127 repeated runtime captures** and **66 unique
address/runtime pairs**. Every runtime matches current artifact bytes,
permitting only compiler-declared link/immutable spans and requiring repeated
values to agree. No metadata stripping or arbitrary masking occurred.
Four native submitted package tuples decode through the actual deployVault
ABI and bind to their captured hooks. Actual initial ownership is asserted
by the handlers.

Final artifact carriers preserve **37,806,889 raw bytes**. The carrier audit
validates 413 lossless source/evidence/artifact payloads and reconciles all
376 test results. `binding-method.md` distinguishes raw artifact hashes,
literal artifact-object text fingerprints and actual runtime-byte Keccak.
These are actual in-process Foundry deployments, not independently signed
constructor transaction archives. Not every linked-library runtime is
separately captured; no cold or portable reconstruction claim follows.

Key final identities:

- `candidate-r2-01.json`:
  `2767c82ada1049bfaa988407146f20a57a0441bf5f740ce4c2793949ed58862d`.
- `source-artifact-deployment.json`:
  `1a6f61706ed057ce2ba926575ee3d958d7194f0cd0ad949231319228a65a97dc`.
- `coverage-matrix.md`:
  `f424d3ca0e1a36cc408b3be07685fc4eefc3d7229fdc5d565da98a9102f81f53`.

## Preserved source and broader gates

The actual fork pin remains chain 4663, L2 block 108944663, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
through only the approved login-shell `robinhood_mainnet_alchemy` alias.
Inherited fixtures verify header/state-root, Orbit L1 number and actual
source proxy/facet routing. No alternative provider or local node was used.

Complete-original claimed SY remains direct-signed-EOA,
canonical-isolated-source-block preparation evidence only. The current
claimed-SY Foundry tests passed as part of the complete gate; no preparation,
certificate authentication, CLI/resume replay or claimed-origin
contract-wallet callback was performed. New receiver callbacks are ordinary
onchain custody witnesses only.

Raw TokenStaking atomic approved pull, E-S, blocked ER/ED/held-source
conversions, partial/prior-delivered/unknown originals, standalone original
ETH/WETH consumption, operational-original datasets and opaque aliases remain
unaccepted. No category is declared absent. LP acquisition retains its
existing external-EOA-owner release/personal-donation qualification, not donor
key control, public consent or generic Migration authority. Synthetic original
components and eligible partitions are code fixtures, not historical awards.

Earlier archive match/exact-match, optional missing facet, masked mature-close
authorization and host/archive dependencies remain qualified. Full-repository
hermetic testing, portability, operational approval and target gas remain
separate. The prior 45,116,678 registration-gas observation still exceeds
32,000,000; this gate makes no gas solution or full-plan claim.

## Stop and handoff

`failed-attempts.md` preserves harness/compiler/evidence-tooling failures and
their scoped corrections. No genuine SUT failure was patched or weakened.
The final source candidate was unchanged through all required final tests.
Two coherent existing handler files retain explicit SIZE_OK explanations;
accounting/recovery/claim helpers are otherwise separated by responsibility.
No new framework, production seam or dependency was introduced.

`cleanup-final-03.log` records exact audited HEAD/branch, empty tracked and
cached comparisons, clean authored-source/evidence whitespace and no listener
on 18574. All owned build/test/cleanup monitors exited. No Anvil, observer,
receipt subscription, checkpoint, delegated child or other operation remains.
Warm out/cache and dependency links are retained; nothing was copied back
or removed. All Git reads used GIT_MASTER=1 and GIT_OPTIONAL_LOCKS=0, with
status/diff ignoring submodules.

All new evidence is exclusively under `implementation-r2/`.
`seal.json` binds complete final evidence membership, excluding only its own
bytes. Independent verification belongs to `verification-r2/` and is not
claimed here. No commit, ref/index change, held09 access, public operation,
operator replay or broad acceptance occurred.
