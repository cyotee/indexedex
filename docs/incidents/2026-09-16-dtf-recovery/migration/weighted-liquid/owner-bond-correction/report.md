# Paid owner-first-bond correction and activation prerequisite

Date: 2026-11-11.

**Producer result: passing bounded correction; D1 is closed under the approved
paid-first-bond rule.** The complete current Migration specs pass 109/109,
the pinned forks pass 52/52, operator tests pass 57/57, strict TypeScript
passes, and the actual fixed18563 CLI completes with exit 0. The ordinary
deposit assertion remains enabled and passes. No reward formula or synthetic
weight seed was introduced.

**Source modifications have stopped. No owned runtime remains.** Final
source snapshots were frozen at `2026-11-11T21:43:46.074Z`. This is the
completed producer handoff for independent verification, not the independent
verifier's verdict or permission for public execution.

## 1. Authority, preserved candidate and scope

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-13-weighted-liquid`.
Branch: `work/dtf-migration-phase-13-weighted-liquid`.
HEAD/base remains `2c2b3370ded30cae1662329025d4fb58f7197330`.

The complete owner-first-bond correction brief, original phase13 directives,
current main plan r5 section 1.5 and PRD r22 section 1.2, and complete sealed
Stage2 producer/verifier reports and D1 analysis governed this correction.
The current owner's approved genuine paid purchase and enforced on-chain
prerequisite supersede the earlier unresolved genesis-weight question.

| Current main input | Raw SHA-256 |
| --- | --- |
| `phase13-owner-first-bond-correction.md` | `29dca72edabe86612e98665a941d1f621cb7184e707bbfa841385fa779ccfb92` |
| `MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`, r5 | `60d02b608c8a10f19cffce7b99838146c205a98410641e9bce45944e620dc56d` |
| `MIGRATION_DETF_DRAFT_PRD.md`, r22 | `cfe1853f49de0dc41ae106f1cc1b94eacd24d4aa8f79477c66a5b7f24a4d67ed` |

All 39 admitted candidate source files matched the Stage2 producer's sealed
hashes before editing. The old incomplete and Stage2 producer seals still
validate: all nine sealed entries match. The Stage2 verifier report, D1
analysis, binding validation, artifact reconciliation and runtime index
remain unchanged and separately bound. Its recorded 13 rewritten artifact
JSON hashes are preserved historical reconciliation, not silently relabeled
as byte-identical artifacts.

The final candidate binds 54 source/test/operator/runbook files: 36 changed
or added since the Stage2 handoff and 18 preserved without further changes.
Exact bytes are in `source-snapshots/`; current main authority bytes are in
`input-snapshots/`. The complete paths and hashes are in `bindings.json`.
No ordinary/common/Crane production, dependencies, configuration or provider
routing changed. No held phase09 inspection, import or replay occurred.

## 2. Production correction

Paths below are relative to
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`.

| Surface | Correction |
| --- | --- |
| `UniswapV4DetfMigrationBondFacet.sol` | Reuses the existing `bond` selector and ordinary implementation. In Stage1, only the current Crane owner may make the first paid purchase. A fresh authorized pull is required; pretransferred inventory cannot satisfy this exception. Subsequent Stage1 purchases reject. Stage2 keeps normal purchase permissions. |
| `UniswapV4DetfMigrationRepo.sol` | Appends `ownerFirstBondTokenId`, an instance execution fact, not an owner-set switch or compensation entitlement. Only the completed ordinary purchase writes it. |
| Bond entry completion | Publishes the ID and `MigrationOwnerFirstBondPurchased` only after ordinary payment, reserve acquisition, nonzero principal funding, immediate reward distribution and budget settlement return successfully. Any revert rolls back the fact and the transaction's economic effects. |
| `bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol` | Removes the redundant activation-only creation restriction while retaining `onlyDetf`, synchronized accounting and the child lock. Only the fixed parent can create the ordinary position; its bond entry owns Stage1 authorization. Ordinary purchased positions remain unmarked and linearly vesting. |
| `UniswapV4DetfMigrationAllocationTarget.sol` | Rejects `MigrationOwnerFirstBondRequired()` before selector removal or stage publication when no qualifying purchase completed. Independent compensation cannot satisfy it. |
| Permanent interface/target/facet | Exposes `migrationOwnerFirstBondTokenId()` for actual receipt reconciliation. It persists across owner/NFT transfers and is not a setter. No new Stage1-only callable route was added. |

The seven actual administration selectors remain the irreversible removal
set. Activation still requires current-owner authority and idle fixed
children, performs the real cuts, removes Allocation interface support and
only then publishes activation. Ordinary acquisitions outside the exception,
legacy surrender and every reward payout remain closed during Stage1.

The ordinary purchase's nonzero funded gons drive the existing standing-weight
top-ups and reward allocation. No bootstrap self-leg seed, first-reward seed,
invented stake, retained-reward redesign, percentage change or shared-code
edit was used. The existing empty-participation expansion policy remains
unchanged. The purchased bond is paid capital, not compensation, does not
consume an entitlement and does not spend booked recovery inventory.
Frozen snapshot/configured credit is unchanged.

## 3. Runtime coverage and operator correction

`MigrationOwnerFirstBond.t.sol` exercises immediate and delayed purchases
through the genuine registry package. It checks exact previewed principal,
reward and self-leg issuance, actual payment, funded gons/backing, canonical
weight top-ups and allocation dust, retained fee/creator rewards, cleared
funding allowances, frozen configuration and ordinary linear principal
vesting. It covers nonowner, pending/former/current-owner authorization,
second-purchase and other-acquisition rejection, payment failure, child
mint rejection and persistent completion across both ownership and NFT
transfers. Stage2 ordinary purchase remains permissionless.

`MigrationOwnerBondCallbacks.t.sol` uses a controllable external payment
token and a genuine contract owner, not a substituted parent or child.
Payment callbacks cannot activate, buy again, mint through another route
or release rewards. A short receipt rolls back payment, allowance,
callback effects, supply, funding and the completion fact. A valid real
contract-owner purchase succeeds afterward. Ordinary NFT mint semantics
are preserved; no new receiver callback was invented for that path.

The original D1 test now first proves activation rejects without purchase
and leaves routing unchanged, then makes the real paid purchase, exercises
the gas-limited cut rollback, activates and executes the original ordinary
deposit assertion. The separate independent-compensation case proves that
compensation alone still cannot activate and preserves that bond's clock
through the paid purchase and activation.

Existing NFT/W-L configuration, original-wallet admission, custody,
partial/final rounding, recovery, child-funding/callback rollback and
restoration checks remain enabled. Their fixtures now fund the required
paid owner position. Assertions account for its measured backing/gons and
derive the next bond ID instead of pretending the instance has no
participation. No test was skipped or weakened to accept a failing suite.

The typed operator adds `owner-bond`, explicit payment/duration/deadline
inputs, a matching Foundry stage and receipt-block reconciliation. It checks
the actual signer payment debit, purchased position, exact principal/gons,
funded reward/backing deltas, fee/creator retention and cleared allowances.
The original journal reconciles a confirmed purchase instead of replaying
it. Rehearsal manifests bind the exact current main authority files above.

The real fixed18563 sequence retains donation and independent-issuance
mined-before-checkpoint interruptions, meaningful outstanding-row reversal
and an unclaimed recipient. It additionally interrupts the mined owner
purchase, resumes it in fresh processes without another nonce, rejects
Stage1 reward payout and a second purchase, activates, and executes an
actual ordinary deposit from a nonowner. All earlier NFT/W-L scenarios
continue after this sequence.

## 4. Actual executed checks

All final commands ran in the designated worktree with pipeline failure
propagation. Solar used `/Users/cyotee/.foundry/bin` on PATH. The existing
archive credential was inherited through `/bin/zsh -lc` without disclosure
or a provider change.

| Final check | Result | Evidence |
| --- | --- | --- |
| Artifact-first Solar complete current Migration specs | 109 passed, 0 failed, 0 skipped; exit 0 | `specs.log` |
| Artifact-first pinned complete Migration forks | 52 passed, 0 failed, 0 skipped; exit 0 | `forks-final.log` |
| Explicit build of both operator Foundry stages | Exit 0 | `operator-stages.log` |
| Three operator test files, single final run | 57 passed, 0 failed; exit 0 | `operator-tests-runtime.log` |
| Strict TypeScript | Exit 0 | `operator-types-runtime.log` |
| Actual block108944663/port18563 CLI | `bounded-rehearsal-complete`; exit 0 | `rehearsal.log` and run directory |
| Source/artifact/runtime reconciliation | 641 compiled inputs match; 43 test artifact source checks match; 10 deployed runtime matches | `source-artifact-parity.json` |
| Whitespace and cleanup | Diff check exit 0; owned PID/listener absent; checkpoint absent | `cleanup.json` |

The artifact-first commands used these actual edited production roots,
with the current spec or fork directory as `--test-root`:

```text
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRepo.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationTarget.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationFacet.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationBondFacet.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol
```

`commands.json` retains the complete exact invocations, including
`python3 scripts/forge-artifacts.py test`, `FOUNDRY_PROFILE=fork`, both
operator consumers and `-vv`. The explicit stage and script commands were:

```sh
PATH=/Users/cyotee/.foundry/bin:$PATH forge build --use solar \
  scripts/foundry/recovery/dtf-migration/Phase_08_Stage_00_OperatorEnvironment.s.sol \
  scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol

bun test --timeout 15000 \
  ./scripts/recovery/dtf-migration/preparation.test.ts \
  ./scripts/recovery/dtf-migration/execution.test.ts \
  ./scripts/recovery/dtf-migration/weighted-liquid.test.ts

bun node_modules/typescript/bin/tsc --noEmit --target ES2022 \
  --module ESNext --moduleResolution Bundler --strict \
  --noUncheckedIndexedAccess --exactOptionalPropertyTypes \
  --skipLibCheck --types node scripts/recovery/dtf-migration/*.ts

bun scripts/recovery/dtf-migration/cli.ts rehearse \
  --rpc-alias robinhood_mainnet_alchemy --fork-block 108944663 --port 18563 \
  --checkpoint .omo-runtime/dtf-migration-weighted-liquid/checkpoints \
  --evidence docs/incidents/2026-09-16-dtf-recovery/migration/weighted-liquid
```

Existing compiler warnings remain in the logs. Final Solidity diagnostics
for both changed purchase targets and both new specs found no errors.
`execution-owner-bond.ts` diagnostics found no errors. Fresh diagnostics for
the rehearsal helper timed out; strict TypeScript is its final type evidence.
JSON LSP was unavailable because Biome is not installed; nothing was
installed or reconfigured.

Retained failed attempts are not acceptance: the first spec run was 105/109
because of a next-call getter in two new revert assertions, the wrapper's
distinct acquisition error and an oversized payment in the existing extreme
index fixture. These were corrected without changing reward math. The
extreme-index fixture uses a real `10,000,000`-wei purchase rather than the
ordinary synthetic 1 ETH-unit purchase. One fork attempt lacked the
credential in bash; the next was 50/52 because two W-L assertions omitted
the new backing/residual baseline. One operator run was 56/57 before the
new Foundry stage ABI had been explicitly rebuilt. The final complete runs
above all pass. Earlier successful operator runs also remain recorded.

## 5. Actual receipt sequence

Successful run: `rehearsal-1794433089985/`.
Proxy: `0xedf7d9f65b9e57d62a3c4278223170db1308f5f0`.
Frozen funded snapshot:
`0x990fc4a8d0871532186bb994b27a889c71085b7ef8e542e660bb35d887136aa4`.
The historical source pin remains chain 4663, L2 block 108944663, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.

The actual owner purchase is bond **6**, transaction
`0x837fecf0c13c873c1860911fbb718b81f70558391989ebfe49178c2cee521417`,
block **108944937**, nonce **2146**. Synthetic authorized payment is
1,000,000,000,000,000,000 native WETH units. Purchased principal is
**465,583,908** native nine-decimal DETF units; funded rewards are
**84,489,332**. Staking backing moves from **1,383** to **550,074,623**,
exactly prior backing plus principal and funded rewards. The ordinary
position starts at simulated timestamp 1794111193 and lasts 7,776,000
seconds; it is not marked as a migration-cliff position.

Before this purchase, activation transaction
`0xa2eb210890c6f63b1ed1b1f05df33330be4d3e2ac8d72cc9a0721a95f20fe050`
is an actual mined failure with `MigrationOwnerFirstBondRequired()`, despite
the three independently issued bonds. Stage1 and all seven routes remain
unchanged. Reward, fee/creator release and second-purchase failures are
also actual mined receipts in `owner-bond-observation.json`.

Activation transaction
`0x4c1ca5ff27913c6d844e51d20938eafe0f414af97cf52e3c0e8ff3cec78858b5`
succeeds at block **108944941**, using 182,796 gas. The nonowner ordinary
deposit then succeeds at block **108944944**, transaction
`0x4d9b92b7f8603b8ef1bc7d78096df60f690f9d7c60e7e9ab685554acb601af6a`.
Its 1 ETH-unit payment returns **462,096,413** raw DETF units, zero refund,
and that exact recipient balance increase.

| Preserved Stage2 surrender | New bond | Exact credit |
| --- | ---: | ---: |
| W-L partial: 7,075,176 WD units | 7 | 924,869 |
| Weighted NFT 4 | 8 | 13,872,781 |
| Weighted NFT 26, returned to original wallet | 9 | 22,233,172,691 |
| Earlier NFT 3 | 10 | 923,391,925 |
| Weighted NFT 6, late | 11 | 36,992,599 |
| Earlier NFT 9, late | 12 | 46,243 |
| W-L final: 14,150,354 WD units | 13 | 1,849,739 |

All seven positive surrenders occur after activation. W-L aggregate credit
remains exactly 2,774,608; final remaining quantity/credit is zero.
The actual five NFT receipts, partial/final W-L custody and funding,
postactivation loader failures and selected recovery observations are
retained with their exact transaction identities in `execution-index.json`
and the run directory.

| Mined interruption | Transaction | Nonce |
| --- | --- | ---: |
| Donation | `0x997f7a1aaf6566ef78629e4aef31ee70b6bc83dc32bd4b3c44e8ce66d61b5399` | 2118 |
| Independent issuance | `0x1ad4429e039e711bf8e674264ced0c8145d3f7f4c2f63109f00be6acab350d16` | 2131 |
| Paid owner purchase | `0x837fecf0c13c873c1860911fbb718b81f70558391989ebfe49178c2cee521417` | 2146 |

Each interruption has a successful canonical receipt while its completion
checkpoint is absent; fresh-process resume preserves the identical receipt.
Two genuinely outstanding independent rows reverse order, producing bonds
4 and 5 after bond 3. Each independent principal is 461. The unselected
fourth recipient remains unissued with bond ID zero. Independent supply
moves from 1,000,000,000,000 to 1,000,000,001,383 before the paid purchase.
The later ordinary deposit to that recipient does not create independent
compensation.

The run retains **41 operator receipts**, **127 fixture receipts** and
**47 command records**. The 47 deliberate failed fixture transactions, six
controlled CLI domain rejections and three intentional SIGKILL interruption
processes are expected negative witnesses, not failed final checks.

## 6. Bindings, limits and cleanup

`source-artifact-parity.json` binds 16 production/operator/ABI artifacts,
43 compiled test artifacts and 641 matching compiled-source inputs.
All ten captured relevant parent/package/child runtimes match their artifact
bytes after masking only compiler-declared library-link and immutable
spans. Observed span values are retained. This includes the changed parent
bond facet and real bond-child facet, not just the parent proxy address.
`bindings.json` hashes raw evidence and exact source/input snapshots.
`seal.sha256` seals this report and the final binding, command, execution,
parity and cleanup records. No earlier report, seal, snapshot or receipt
was overwritten.

The local parent deployment used **43,263,865 gas**, transaction
`0x78479d09e968252e83fad3f99c09bfc55657b48e3d24013489de9bbaa9e306b3`.
The permissive 100-million-gas node proves integration, not feasibility
against the retained historical 32,000,000 transaction limit. The earlier
42,985,865-gas baseline and 43,217,538-gas Stage2 result remain historical.
The held gas lane was not reopened.

All owner-purchase and allocation fixture amounts are synthetic. No public
payment amount, duration, recipient allocation or transaction is approved
here. Real original-wallet/origin/Q0/component records remain operational
inputs. Opaque aliases are not proven globally disjoint. Other legacy
source categories retain their previously reported mapping, unit, caller,
disabled-route and integration limitations. Earlier sale-and-hold is not
proven liquidation. No full ordinary/common shared-suite replay was run:
no shared production input changed.

Owned Anvil PID **52090** exited through the rehearsal's cleanup. External
`ps` and port18563 `lsof` probes found no process/listener (both exit 1).
The fixed checkpoint is absent (test exit 0); its empty task-specific parent
was removed (exit 0). Impersonations ended in `finally` blocks; providers
and subscriptions closed. All owned compile/test/type/rehearsal commands
and monitors have exited. Warm `out/` and `cache_forge/` remain local; no
artifacts were copied to main.

No public action, commit, push or merge occurred. **Source modifications
are stopped and no owned runtime remains.** The bounded correction is ready
for the separately owned independent verification.
