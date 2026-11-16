# Stage 2 surrender correction: implementation and runtime evidence

Date: 2026-11-11.

**The missing W-L loader and Stage2-only NFT/W-L surrender correction are
implemented and exercised through real registry-deployed contracts.
The final fixed18563 rehearsal completed with exit 0. Overall acceptance
is not clean: D1 below remains an executed, failing ordinary-deposit case.**
This is the completed producer evidence handoff, not an independent
AdversarialVerify verdict or full-category Migration acceptance.

## 1. Remaining concrete defect

### D1: ordinary deposit after activation with no funded participant

`test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationCore.t.sol`,
`test_activationRemovesEntireAdministrationAndKeepsQueries`, passes its failed-cut
rollback, closed-gate, successful activation, selector-removal and retained-query
assertions, then fails on the first ordinary `exchangeIn` with
`MissingRewardWeight()`.

Reproduction: deploy the genuine Migration package, fund and bootstrap the
reserve, capture the snapshot, activate without issuing an independent bond
or surrendering an asset, then deposit 1 ETH-equivalent through ordinary
`exchangeIn`. The ordinary mint creates a nonzero reward allocation before
any funded participation exists. The observed call chain reaches
`UniswapV4DetfMigrationStakedDETFTarget.fundRewards` at
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/claimToken/UniswapV4DetfMigrationStakedDETFTarget.sol:103`,
then `_distributeRewards` at line 354, and the zero-total-weight rejection in
`contracts/vaults/detf/common/core/DETFFundedStakingMath.sol:79-88`.

`activation-cut-trace.log` retains the final actual trace; `specs-sealed.log`
retains the final-source failure. The companion
`test_ordinaryDepositOpensWithFundedIndependentParticipation` passes an
actual ordinary deposit after independent issuance and activation, without
changing that bond's start time.

The reward path and ordinary/common production files were not changed.
The failure is located in that existing path; it was not independently
replayed on a clean base. No reward-allocation policy, first-participant
requirement, retained-reward workaround or shared-code fix was invented.
The failing test remains enabled and its assertion remains intact. This
finding prevents claiming unconditional ordinary-deposit success or an
all-green Migration suite. It does not reopen the obsolete
partial-entitlement-correction question.

## 2. Authority, worktree and sealed history

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-13-weighted-liquid`.

Branch: `work/dtf-migration-phase-13-weighted-liquid`.
HEAD/base stayed `2c2b3370ded30cae1662329025d4fb58f7197330`.
The preserved incomplete delta was present at admission and was not reset.

The complete correction brief and original phase13 brief, current main plan
r4 and PRD r21, old implementation and independent needs-fix reports, and
the phase11 weighted source contract and independent report/matrix were
read. The approved Stage2-only law supersedes the old preactivation-success
and partial-amendment wording.

Final main authority fingerprints:

| Input | SHA-256 |
| --- | --- |
| `.omo/ulw-execute/dtf-migration/phase13-stage2-surrender-correction.md` | `eaeb2a971f16dd28eeff74125c08565a643a96e3ee383c8952c60b6e5a69fd25` |
| Original `phase13-weighted-liquid-brief.md` | `28a20cf28b2b47da3d4581f872c3d871043fa2e4f215f9025d1a62aad91f4f0a` |
| Main `MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`, r4 | `c9eff8e498d1483b0166346099a15ab0930740a9febcfd727774cf2b4506ef2a` |
| Main `MIGRATION_DETF_DRAFT_PRD.md`, updated r21 | `d4b12a742c74c08e862bf02a9315cfd706e3d117e4878bd99092b071c3c48ba3` |

The r21 hash includes the root's five residual-clause corrections to
MIG-R34, MIG-R13, the NFT original-wallet paragraph, MIG-O03 and AC38.
Earlier r21 fingerprints are historical, not the authority bound here.

The old `../implementation/` report, bindings, cleanup, logs and seal and
`../verification/report.md` were left untouched. Checking the producer's
three-entry `seal.sha256` returned all entries OK. That seal still describes
an incomplete setter-less state and no W-L runtime acceptance; this report
does not relabel it as a pass. Its bound mutable source/artifact paths have
necessarily changed under this authorized correction.

`bindings.json` enumerates the exact 39 source/test/operator/runbook paths
in the total uncommitted delta from base, distinguishing 23 changed or added
since the incomplete handoff from 16 preserved without further changes.
Exact final text is retained in `source-snapshots/<repository-path>.txt`.
Final artifact, compiled-input, receipt and command bindings accompany it.

## 3. Exact implementation delta

For this section, M is
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`.

| Surface | Final change |
| --- | --- |
| `M/UniswapV4DetfMigrationAllocationTarget.sol` | Implements the advertised `configureWeightedLiquidEntitlements` body. Current owner and Stage1 only; validates fixed chain/source, nonzero canonical origin, original wallet, Q0, evidence and known components; evaluates C0 on the existing frozen snapshot; stores the full configuration/hash and sets remaining Q/C to the complete owner-supplied Q0/computed C0. |
| Same loader | Identical replay and corrected full replacement issue nothing. Configured or issued independent origins and configured NFT origins reject overlap. Nonzero consumed units or delivered credit reject instead of clearing execution facts. There is no consumed-remainder amendment formula. |
| Existing NFT loader | Rejects an already consumed identity as an invariant violation instead of overwriting its configuration. Normal Stage1 full replacement remains available; no valid surrender can precede it. |
| `M/UniswapV4DetfMigrationTarget.sol` | Both surrender entrypoints reject `MigrationSurrenderClosed()` before child queries, registry/source checks, external custody, allowance spending, consumption or funding when the shared finalized activation flag is false. Read-only previews remain available. |
| `M/interfaces/IUniswapV4DetfMigration.sol` | Declares the explicit closed-stage error and documents the Stage2 surrender/Stage1 replacement contract. |
| Preserved W-L facet/repo/schema delta | Retains the configured flag, full original tuple, domain-bound configuration ID, separate consumed/delivered/remaining state, public queries, partial/final surrender and original overlap protection. The now-implemented setter makes this surface callable rather than merely advertised. |
| Existing custody/funding/recovery | Retains exact WD wallet debit and proxy receipt, full-precision remaining-credit division, final residue, booked inventory only, exact principal mint and funded fresh bond, current-owner selected conversion/donation, fixed receiver and allowance clearing. No recovery production code changed. |

Activation retains its existing protected implementation: current owner,
Stage1 and idle fixed children; resolve all seven actual removable selectors;
perform ERC2535 Remove cuts using their owning facets; remove Allocation
interface support; only then set `activated = true`. There is no external
callback in the cut or between removal and final state publication. The same
state already gates ordinary acquisition and reward payout and now gates
both NFT families and W-L surrender. No extra flag, switch, initializer or
restoration route was added.

The seven removed selectors include bootstrap, snapshot capture,
independent configuration, independent issuance, activation, NFT configuration
and W-L configuration. Persistent quote, custody, surrender and recovery
surfaces remain installed. Existing actual proxy declaration, restoration,
current-owner, registry and callback negatives remain exercised.

## 4. Tests and operator delta

The neighboring suites now configure all needed records before activation.
Former Stage1-success cases became explicit closed-stage/no-side-effect
cases followed by Stage2 eligibility tests. Former post-consumption
configuration-success cases now execute removed-loader negatives and prove
configuration, Q/C, custody and funded bonds unchanged. Neither unrelated
assertions nor tests were skipped.

W-L configuration tests execute real owner loading, idempotence, complete
Q0 and contribution replacement, no issuance, wrong/pending/former owner,
unknown fields, unsupported source/chain, atomic bad-second-row rollback
and canonical overlap in both directions. Fork cases cover actual WD
approval/balance failures, dust/minimum/deadline, transfer-back, exact
partial/final consumption, original wallet, child receiver/funding rollback,
fresh clocks, selected recovery and protected inventory.

NFT forks retain both authenticated position layouts, withdrawn-principal
fractions, burned/reward-only/reserved failures, original-wallet/current-holder
and operator negatives, real transfer-back, callback rejection/reentry,
funding rollback, separate instances, registry checks and both existing
recovery generations.

The new delayed W-L test initially exposed two fixture assumptions:
cached `block.timestamp` across `vm.warp`, and an unsupported assumption
that the funded book had zero elapsed expansion. It now uses
`vm.getBlockTimestamp()` and reconciles the exact existing
`pendingExpansionDetf`/`synchronizeRewards` result separately from delivered
credit. Exact supply, backing and bond assertions remain.

Operator changes stay under `scripts/recovery/dtf-migration/`, its existing
typed Foundry stage, and `migration/operator-runbook.md`:

- The fixed18563 rehearsal writes new evidence under `stage2-correction/`,
  never over the old sealed `implementation/` report.
- Configure, issue independent compensation, make full Stage1 corrections,
  prove closed-stage NFT/W-L calls, then activate. Only afterward perform
  W-L partial surrender, NFT surrender/recovery, late NFT surrender and final
  W-L surrender/recovery. No configuration follows partial surrender.
- Configuration receipt reconciliation requires zero consumed/delivered
  facts and exact full remaining Q0/C0 at the loading receipt block.
- The synthetic W-L correction changes Q0 and original ETH; it does not
  calculate an output credit or amendment delta.
- Actual identical and corrected W-L loader calls after partial and final
  surrender are mined failures with unchanged remaining Q/C.
- Source binding fixes a missing `f` in the previously unrun exchange-facet
  literal. `source-binding-diagnostic.json` records the actual pinned RPC
  identity, not a substituted source.
- Wrong-wallet probes transfer and approve a quantity with positive quoted
  credit, so zero-credit dust cannot mask the wallet guard.
- Donation proof distinguishes spendable reserve residuals from booked
  recovery, donation budgets and an independently transferred 1 ETH-unit
  DTF unbooked floor. It still checks exact recovery debit and unchanged
  compensation. No production recovery check was relaxed.
- Both real mined-before-checkpoint crashes, fresh-process resumes, meaningful
  remaining-row reversal, unclaimed zero issuance, missing-wallet inputs,
  domain rejections and unsupported category dispositions remain.

## 5. Exact executed checks

All commands ran in the assigned worktree. Logged shell pipelines used
`set -o pipefail`. Forge commands used the installed Solar-capable
`/Users/cyotee/.foundry/bin` on PATH. Login-shell wrapping supplied the
existing archive credential without printing it.

| Check | Final result | Evidence |
| --- | --- | --- |
| Artifact-first Solar build and all current Migration hermetic specs | Build succeeds; 102 pass, 1 fail, 0 skipped; exit 1 for D1 | `specs-sealed.log` |
| Artifact-first pinned Migration forks | 52 pass, 0 fail, 0 skipped; exit 0 | `forks-verified.log` |
| Both existing operator Foundry stages | Solar build exit 0 | `operator-stages.log` |
| Final-source operator tests | 56 pass, 0 fail across three files in one run | `rehearsal-accepted.log` |
| Final-source strict TypeScript | Exit 0, chained before the successful rehearsal | `rehearsal-accepted.log` |
| Fixed18563 actual CLI | Exit 0, `bounded-rehearsal-complete` | Same log and final rehearsal directory below |
| Changed Solidity diagnostics | No errors on loader target, surrender target and activation spec | Tool diagnostics; compiled runs above are the runtime evidence |
| Scope/whitespace | `git diff --check --ignore-submodules=all` exit 0; no ordinary/common/config delta | `cleanup.json` |

The artifact-first commands were:

```sh
PATH=/Users/cyotee/.foundry/bin:$PATH \
python3 scripts/forge-artifacts.py test \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationTarget.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/ \
  --consumer scripts/foundry/recovery/dtf-migration/Phase_08_Stage_00_OperatorEnvironment.s.sol \
  --consumer scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol \
  -- -vv

PATH=/Users/cyotee/.foundry/bin:$PATH FOUNDRY_PROFILE=fork \
python3 scripts/forge-artifacts.py test \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationTarget.sol \
  --test-root test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/ \
  -- -vv

PATH=/Users/cyotee/.foundry/bin:$PATH forge build --use solar \
  scripts/foundry/recovery/dtf-migration/Phase_08_Stage_00_OperatorEnvironment.s.sol \
  scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol
```

The final script and actual CLI commands, chained with `&&`, were:

```sh
bun test --timeout 15000 \
  ./scripts/recovery/dtf-migration/preparation.test.ts \
  ./scripts/recovery/dtf-migration/execution.test.ts \
  ./scripts/recovery/dtf-migration/weighted-liquid.test.ts

bun node_modules/typescript/bin/tsc --noEmit --target ES2022 \
  --module ESNext --moduleResolution Bundler --strict \
  --noUncheckedIndexedAccess --exactOptionalPropertyTypes \
  --skipLibCheck --types node scripts/recovery/dtf-migration/*.ts

bun scripts/recovery/dtf-migration/cli.ts rehearse \
  --rpc-alias robinhood_mainnet_alchemy \
  --fork-block 108944663 \
  --port 18563 \
  --checkpoint .omo-runtime/dtf-migration-weighted-liquid/checkpoints \
  --evidence docs/incidents/2026-09-16-dtf-recovery/migration/weighted-liquid
```

Observed tools: Bun 1.4.2; Forge 1.9.1-nightly
`430523103f3e2f9ba432ffdd2031a9f966153d0d`;
compiled metadata identifies
`0.8.38+commit.e7a91fc7.solar.0.3.0-dev`.
Existing compiler warnings remain in the logs. TypeScript LSP fresh
diagnostics timed out; the strict compiler is the type evidence. JSON LSP
was unavailable because Biome is not installed; no dependency was installed.

No full ordinary/common suite was repeated because no shared production
input changed. Historical ordinary/common evidence remains historical,
not newly executed acceptance. The retained failing ordinary-deposit
regression is not hidden by that scope choice.

## 6. Final-source actual runtime

Final successful directory:
`rehearsal-1794427310218/`.

Actual Migration proxy:
`0xedf7d9f65b9e57d62a3c4278223170db1308f5f0`.
Funded snapshot:
`0x0c714d0a1aae0748c6a999943342deeb825e2dd27a647f544dee481f6d3576cb`.

The historical source domain is chain 4663, L2 block 108944663,
hash `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
state root
`0xb1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071`.
The actual captured header is retained. This historical pin is distinct
from the new reserve's funded snapshot and the later simulated timestamps.

### W-L exact credit and custody

Original synthetic loading used Q0 21,225,531 and original ETH
10,000,000,000,000,000 wei. Full Stage1 correction used Q0 **21,225,530**,
original ETH **6,000,000,000,000,000 wei**, original DTF zero. On-chain frozen
C0 was **2,774,608 native nine-decimal DETF units**.

| Actual operation | WD quantity | Delivered credit | Bond | Remaining Q / C |
| --- | ---: | ---: | ---: | --- |
| Stage1 configured and missing-record surrender | Rejected | 0 | None | 21,225,530 / 2,774,608 |
| Stage2 partial | 7,075,176 | 924,869 | 6 | 14,150,354 / 1,849,739 |
| Stage2 final, after the later recovery/clock scenario | 14,150,354 | 1,849,739 | 12 | 0 / 0 |

Partial transaction:
`0xd78d5b5d6aec019531934e439caeca456a49da52491c0585c53b8d028455d290`.
Final transaction:
`0xd93dd8e24d8a1c7f3f0c13ca315a57d58e9cda3e51ea127131d8054b3bc8bd6e`.

Bond 6 starts at 1794111198; bond 12 starts at 1825676092.
Each has duration 7,776,000 seconds and exact measured funded gons.
These are local simulated chain times, not public issuance dates.
Wallet debit, proxy receipt, booked inventory, principal and supply/backing
deltas were checked in the actual scenario. Aggregate credit is exactly
2,774,608; no partial contribution was re-quoted.

After partial surrender, both identical and altered loader transactions
revert `NoTargetFor(0x256c417b)` and preserve Q/C:
`0x0fad89dda53168f9e2e2af2ee37c0330b7c10d589f53e2617f40d7c3a7da43c3`
and
`0x0ee1853ba0a1dd3ace44d9b293aaec67e4ac2c28d446a204dc9e1a8354ba0943`.
Final exhaustion and postactivation missing-record/wrong-wallet calls are
also actual mined failures.

Selected partial WD conversion receives 37,926,535,439,701,004,167 DTF units
and donates 18,963,267,719,850,502,083. Final conversion receives
75,849,094,827,246,623,469 and donates 37,924,547,413,623,311,734.
Exact booked debits, zero self-allowance, unchanged personal compensation,
seven unbooked WD units and the independently transferred
1,000,000,000,000,000,000 unbooked DTF floor are checked. Spendable reserve
residuals remain a separate domain.

### Both NFT generations and atomic activation

`admission-before-activation.json` contains seven mined Stage1 rejections:
configured and unconfigured weighted/earlier identities, with unchanged
owner, approval, configuration, consumption, custody, supply and funding.
The two postactivation admission files contain actual missing-record,
wrong-wallet, approved-operator, original-wallet-without-control and
already-consumed rejections plus these positive surrenders:

| Source / ID | New bond | Native credit | Actual surrender transaction |
| --- | ---: | ---: | --- |
| Weighted / 4 | 7 | 13,872,781 | `0x3f62955437c1b3ca5084af2444f41d17cac055f0fc163735a19246cf3550f73e` |
| Weighted / 26 | 8 | 22,233,172,691 | `0x2981a419b5588c2117e13faf2e3f5c88dfeb0ea402a6a31f45636bfbc80ac9cd` |
| Earlier / 3 | 9 | 923,391,925 | `0x3ab45bec5fc62277a458c181f438f494fb4d2c7b82d6770abcab87e63bdb2bc4` |
| Weighted / 6, late | 10 | 36,992,599 | `0x5e48a008f721250cc33e6c9f57405a87dde634da14c315871245384f1556cd4b` |
| Earlier / 9, late | 11 | 46,243 | `0x7076d1b71a9abfdb73733104f4f705ff9d3b5e47394e9c7a276ce4b9b7d544ff` |

Weighted ID26 was returned by a genuine local source transfer to its
recorded original wallet; configuration was not changed to its current
holder. Each positive operation checks custody and a distinct exactly
funded fresh 90-day bond.

`journal-activate/` binds the actual activation transaction, seven removal
events and receipt-block state. `023-activate.log` and `042-verify.log`
record activation and final validation. Activation transaction
`0x0ee958d7e91516160a7365b73ea0dd9225abde29fb469ec917353a0d374a63d5`
used 181,100 gas at block 108944935. Last configuration was block 108944917;
first successful surrender was block 108944945.

The final 150,000-gas hermetic failure witness reaches three actual
`DiamondFunctionRemoved` writes before `ReentrancySentryOOG`. It then proves
all seven original routes and interface support restored, activation false,
and ordinary/NFT/W-L entry gates still closed. The earlier 50,000-gas probe
failed during child admission and was not sufficient cut-rollback evidence;
its trace is retained, not substituted for the strengthened witness.
Hermetic callback,
restoration and registry tests supplement these actual CLI receipts; no
failed activation or callback-intermediate success is claimed from a
mere Boolean read.

### Preserved real interruption/resume

- Donation transaction
  `0x761c01bf0f2eba319cc61fd2995ba083f4cee9e60c8cbf0da1403308e6f3ed18`,
  nonce 2118, was mined while its completion checkpoint was absent.
  A fresh resume reconciled that same canonical receipt without donation
  replay.
- Independent issuance transaction
  `0x1acca87dd57bf1a207aa856e531391ae299475fe0ee9c33554a1a56c325469e2`,
  nonce 2131, created bond 3 for 461 native units before checkpoint
  completion. Fresh resume reconciled that exact receipt. Two genuinely
  outstanding rows were reversed, creating bonds 4 and 5 at nonces 2132
  and 2133, each for 461.
- The fourth configured recipient stayed unissued with bond ID zero.
  Supply was 1,000,000,000,000 before selected issuance and
  1,000,000,001,383 afterward. Correcting a previously issued independent
  configuration left its actual issuance and supply unchanged.
- The NFT recovery path spent the original 103,958,239 attributed receipt
  units, then recovered 11,891 additional accrued units from remaining
  attributed gons. Actual total WD output was 103,970,130. Earlier sale
  remains sale-and-hold, not liquidation.

There are 39 operator journal receipts and 120 fixture receipts, including
43 deliberate mined failures. Seven positive surrender receipts comprise
five NFTs and two W-L operations, all strictly after activation.
Raw infrastructure/fixture receipts, command exit records and copied
`journal-*` files remain in the final directory. `execution-index.json`
provides the bounded receipt/order index. `source-artifact-parity.json`
joins compiled source metadata and captured deployed facet bytes;
`bindings.json` hashes these evidence files and the final source snapshots.

## 7. Retained failed attempts and limits

The first shell invocation failed before compilation because PATH expansion
was quoted incorrectly; `specs.log` retains exit 127. Correct literal
login-shell quoting fixed execution without changing configuration.

Three earlier actual rehearsal directories remain failed evidence:

| Directory | Captured stopping condition | Correction |
| --- | --- | --- |
| `rehearsal-1794426697254` | Pinned W-L source identity mismatch | Corrected the truncated exchange-facet address from actual pinned read-only observations |
| `rehearsal-1794426969363` | Wrong-wallet probe expected the wallet error on a zero-credit one-unit quantity | Selected, transferred and approved a positive-credit quantity; no production guard changed |
| `rehearsal-1794427106781` | Final donation assertion treated previously spendable residual DTF as protected | Checked the actual protected accounting domains and an independently received unbooked DTF sentinel |

Their nodes were stopped, journals/receipts and failure records retained.
Only `rehearsal-1794427310218` is the final successful source-bound CLI run.

All W-L original quantities/components here are synthetic fixtures, not
approved historical allocations. Actual operational original-wallet,
canonical-origin and Q0/component records remain required. Opaque aliases
are not proven globally disjoint.

No other source category is newly accepted. Weighted receipts/SY,
earlier liquid/receipt, TokenStaking/claim-vault, standalone SE and fungible
LP paths retain their phase11 mapping/integration/caller/disabled-route
limitations. In particular earlier liquidation, disabled SE exits and
owner-restricted LP exits remain unsupported. No native original amount
was filled from a balance or replaced by zero.

The final actual parent deployment used **43,217,538 gas**, transaction
`0x32d91d2442cbf6221ecf24c367ade104d5f53c60a116d8ef41d903261fd6cbd1`.
The baseline's previously reported 42,985,865-gas parent deployment versus
the historical 32,000,000 maximum transaction limit remains an explicit
public-deployment limitation. Final local receipt gas is bound separately;
the permissive 100-million-gas local node proves integration, not target-gas
feasibility. No held phase09 candidate, routing change or gas correction was
inspected or imported.

## 8. Cleanup and final disposition

All four owned Anvil runs completed cleanup. Final owned PID 24046 exited;
earlier owned PIDs 22169, 22780 and 23133 also exited. The final external
`lsof` check found no listener on 18563; `ps` found none of those PIDs.
The checkpoint root was absent and its empty task-specific parent was
removed. Holder impersonations were stopped in the scenario's `finally`
paths before node shutdown; providers/subscriptions were closed.

Warm `out/` and `cache_forge/` remain in the assigned worktree, and the
existing Crane dependency symlink is unchanged. No artifact copying to main,
dependency/configuration edit, public transaction, commit, push or merge
was performed. No code or tests from the held phase09 lane were used.

**Final producer disposition:** V1's missing loading route is closed by
actual successful loading and surrender. The approved Stage2-only
NFT/W-L lifecycle, bounded recovery and real operator resumes are
implemented and runtime-proven. D1 remains a concrete failing ordinary
zero-participation case, so this is not an all-green acceptance claim.
Independent verification of this immutable handoff is still required and
is not supplied by this producer report.
