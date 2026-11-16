# Phase 23 bounded claimed-SY integration: implementation handoff

## Disposition

**Complete bounded implementation candidate, producer-audited and stopped.**
The amended brief's source-admission decision is implemented: direct signed
EOA preparations against the actual pinned `TokenStaking.withdrawClaim` source
normalize into the existing weighted-SY intake and surrender mechanism.
There is no remaining source-admission or owner product question for this
bounded task. This report is not independent verification or an operational
award authorization. Full Task 9 remains open.

The audited base remains `4eaa7decab80d24cf37cb3781eff5ffaf9362942`.
Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-23-claimed-sy-integration`.
Branch: `work/dtf-migration-phase-23-claimed-sy-integration`.
There is no new commit or staged change. Production contract edits: **0**.
The existing ABI, credit accounting, source controls and custody rules are
unchanged; no production mechanism gap required escalation.

The final source manifest binds 28 changed/new source paths by exact bytes,
SHA-256 and mode. It also retains 33 immutable baseline bindings covering
the complete source22 producer tree and the two pre-existing phase23
verification files. The original `needs-fix` verification remains preserved,
not overwritten or relabeled. `additional-input-bindings.json` records the
actual required phase22 inputs and historical source contract read.

## Implemented intake and identity contract

The ordinary weighted-SY row now optionally carries a strict, versioned
`claimedOrigin` certificate. It contains reviewed original eligibility
(original identity, original wallet, original raw weight W0, complete original
E0/D0, known zero prior delivery), canonical members, exact requested raw
units, measured SY and underlying-vault-share deltas, block/transaction
positions, source evidence and the original signed raw preparations.
Missing or unknown fields do not become zero. Negative, excess, duplicate or
incomplete partitions fail.

`claimedSyEvidenceId(domain, original, certificate)` commits the complete
certificate and original tuple to the existing `original.evidenceId`.
`claimed-sy.ts` validates coverage, identity and actual chain observations;
`rehearsal-claimed-sy-source.ts` constructs the admitted real-source fixture.
Authentication verifies the supported fixed
source identities/runtime, signer recovered from raw bytes, canonical
transaction/hash/block/receipt linkage, successful direct call and calldata,
original wallet as sender and SY recipient, pre/post raw-weight consumption,
the actual `ClaimWithdrawn` event, returned output, vault redemption call and
measured token/share changes. SY supply remains unchanged by source redemption.
Preparations must be canonical isolated transactions included by the
preparation domain. Member consumption must sum exactly to reviewed W0;
zero-output members remain mandatory. A separate parent configuration-event
census, starting at the authenticated snapshot-capture RPC block, prevents
omitting previously configured SY origins from a later manifest. This is not
an automatic historical source-claim census.

Preparation and persisted-manifest validation perform this authentication
before configuration broadcast. The complete certificate survives
normalization, source fingerprints, frozen quotes, batches, manifest
fingerprints, loading and durable journal identity. Changed evidence,
members, results or source files invalidate that binding. Duplicate members
within or across claimed originals, and reuse of the canonical original in
competing representations, are rejected.

Reviewed owner-input proofs point to `{original, claimedOrigin}`, not merely
the original tuple, and must be file-provenance inputs rather than pretending
that chain observations establish historical E0/D0 eligibility. Classification
is also reconciled across every referenced reviewed JSON document.
Removing the certificate and repointing to a nested or separately copied
original tuple cannot downgrade it to ordinary SY. A concrete pre-fix
reproduction accepted that downgrade; the same reproduction now rejects it
with `PROVENANCE`. Both outputs remain retained, and the regression and fresh
CLI exercise both pointer variants.

The certificate produces one ordinary `WeightedSyEntitlement`: Q0 is the
exact sum of eligible measured native SY; E0 and D0 remain the complete
reviewed original components; C0 is the existing frozen
`U(E0) + U(D0)` quote. No credit is calculated from raw claim fractions,
current wallet balances, reward balances, fixture backing, donated SY or
observed conversion ratios. The existing loader and surrender facets perform
the work; there is no parallel live claim bridge.

## Actual-source integration and rejection coverage

The final runtime is `runtime-03/rehearsal-1794496225193/` on fresh
`127.0.0.1:18573`, chain 4663, fork alias `robinhood_mainnet_alchemy`, pinned
block 108944663. It did not reuse source22's 18572.

Two controlled EOA originals each use W0 = `10013000000000000000017`,
E0 = `10000000000000000`, D0 = `1000000000000000000`.
One original claims once. The other claims raw weights
`3337000000000000000005`, `1`, and `6676000000000000000011`.
The middle positive-weight transaction succeeds with measured SY and vault
shares both zero. Its raw signature, successful canonical receipt, request
and consumption are required evidence, not an omitted zero. Each original
has Q0 = `18077396` native SY and C0 = `466690583` integer quote-credit units.

The fixture first makes separately excluded source claims, and retains
pre-existing SY `5416` and unrelated raw weight `7000000000000000000` in each
wallet. The claimed-original evidence excludes those seeds and unrelated
weight. Source rewards, source inventory and funding/backing are not added
to E0/D0. The runtime records before/after source and wallet states, full
receipts and traces rather than assigning fabricated source balances or
deploying replacement source code.

Before any configuration transaction, the actual `prepareDomain` path
rejects eight malformed cases: incomplete coverage; duplicate member;
wrong measured output; noncanonical block; tampered signature; missing
certificate; nested-proof downgrade; copied-tuple downgrade.
`claimed-intake-rejections.json` records each reason and unchanged owner
nonce `0x85e`. Missing claimed evidence does not fall back to ordinary SY.

New real-source fork tests cover normalization/evidence binding for full,
split and zero-output members; partial/terminal closure for both originals;
and source, original-wallet, approval, minimum, stage and clock controls.
The fresh CLI also checks minimum failure and a late funding failure after
earlier transfer work would have occurred. Reverts preserve parent and
original eligibility, budgets, balances, supply and bond state. Already
consumed raw claim weight remains consumed because source preparation was
an earlier completed transaction; the failed parent call creates no award.

The final four successful surrender operations were:

| Original | Native SY | Credit | Bond | Start | Remaining SY / credit |
| --- | ---: | ---: | ---: | ---: | --- |
| full, partial | 6025798 | 155563510 | 16 | 1825762742 | 12051598 / 311127073 |
| split, partial | 6025798 | 155563510 | 17 | 1825762747 | 12051598 / 311127073 |
| full, terminal | 12051598 | 311127073 | 18 | 1825849150 | 0 / 0 |
| split, terminal | 12051598 | 311127073 | 19 | 1825849153 | 0 / 0 |

Every bond has its own recorded start and duration `7776000`. Terminal
credit is the exact residual, not another independently rounded pro-rata
estimate. The stopped audit recomputes eligible Q0, partial/terminal credit,
rollback, SY bookkeeping/custody, supply changes, fully funded bond
partitions, exact depletion and absence of double award from raw receipt and
state evidence. Unrelated pre-existing SY and raw weight remain excluded.

## Required cumulative workflow

The final CLI also completed configure, every existing category loader,
finalize, exact funding, reconcile, custody settlement, the corrected
ordinary-independent SY wallet and native quantity, W-L, W-Y, ED, ER,
claim-vault, held-LP, full raw-weight W-SD and the rest of the existing
cumulative path. Claimed SY did not replace or weaken those paths.
New source operations use actual signed EOA transactions. Gas funding for
these local participants uses real funding transactions, not gas-balance
injection. No new source role, governance or storage fabrication,
contract-owner/SUT impersonation, provider/IPFS workaround, alternate custody
receiver, source replacement or private endpoint was introduced.

Three real CLI interruptions and resumptions retain the same durable intent,
nonce and canonical receipt, without replay:

| Operation | Nonce | Canonical transaction |
| --- | ---: | --- |
| donation | 2139 | `0xb2e4c211f75bceacb5dbaf04bfba3c22752bff3888d2d439e2bb4a160046c1b6` |
| issuance | 2163 | `0x3658ec56c383042a1cee4c33521cace594a4ce65519ea6fc22af45dda708112e` |
| owner first bond | 2215 | `0x016367feb7873fad8148b0a9bce5ec0c249f89ea830c2f0111e31c812c1110ed` |

## Checks and actual evidence

All final required checks passed:

| Check | Result | Retained output |
| --- | --- | --- |
| Artifact-first currentMigration specs | 167 passed, 0 failed | `specs.log` |
| Artifact-first currentMigration forks | 142 passed, 0 failed | `forks-01.log` |
| Both current operator stages, Solar | exit 0 | `stages.log` |
| Strict operator/probe TypeScript | exit 0 | `types-final-02.log`, `probe-types-final.log` |
| Complete final operator suite | 91 passed, 0 failed | `operator-tests-final-02.log` |
| Final fresh cumulative CLI | exit 0, bounded complete | `cli-03.log`, `runtime-03/` |
| Stopped raw/source/economic audit | exit 0 | `audit-final.json`, empty stderr log |
| Read-only Git whitespace/index and owned cleanup | exit 0 | `cleanup-final-02.log` |

The final complete operator suite was one invocation on the final hardened
source. The earlier complete invocation remains retained; it was repeated
because the concrete downgrade fix changed behavior. Solidity source and
deployment scripts did not change after the passing specs/forks/stage builds.
No test was weakened, skipped or suppressed. `commands.md` supplies the
actual command recipes. Failed shell/probe/runtime attempts and their fixes
are described in `failed-attempts.md`; attempts 01 and 02 remain separate
from final attempt 03.

Native JSON diagnostics were unavailable because Biome is absent, and some
fresh TypeScript language-server requests timed out. Nothing was installed.
Strict command-line typechecks passed. Existing Foundry nightly/config and
Solar warnings remain visible in the retained logs; they were not suppressed.

The stopped audit binds 57 compiled artifacts and compiler metadata,
75 deployed runtime captures, constructor/deployment inputs and canonical
receipt/trace code identities. Solar identity is retained as
`0.8.38+commit.e7a91fc7.solar.0.3.0-dev`. Main migration runtime sizes are
24408 bytes (migration), 24100 (allocation), 22704 (recovery), 11221
(claim-vault allocation), and 16714 (migration package), all below EIP-170.

It also reconciles 68 exact original preparation-input references across 35
unique paths, with zero prepared-input drift; 184 originally captured signed
raw transactions; **four explicitly identified canonical reconstructions,
not original HTTP captures**; three canonical resumptions; 2531 original
local HTTP bodies; 840 canonical receipts; and 849 blocks. Every eligible
claimed-SY preparation has original signed raw bytes. The wire observer was
armed before the final CLI. Base64 input captures retain original bytes;
structured parsed input equality is not substituted for byte identity.
The audit checks source fingerprints, metadata source hashes, parsed
constructor arguments, receipt/header/transaction correspondence, runtime
hashes, stage ABI identity, clocks and conservation.

Actual local registry-registration gas was **45116678**. This is a current
bounded observation, not a new gas-budget acceptance or optimization verdict.
The historical gas conclusion and old raw-pull source failure remain
unchanged and bound. The unchanged old raw-pull failure was not replayed.

## Trust boundary and stopped handoff

Canonical direct-call observations authenticate how SY was produced and its
measured results. They do not establish historical original economic
eligibility, prove an owner-reviewed zero-delivery statement, or enumerate
opaque aliases outside supplied reviewed records. Those remain explicit
reviewed owner inputs. Complete current-member coverage is checked against
the supplied reviewed W0 and authenticated canonical members; the separate
configuration census covers retained parent origins, not universal historical
discovery. The fixture's original eligibility is synthetic local
test data, not an operational compensation entitlement.

The final audit file is SHA-256
`c8ab29bdd1f36f1bfe815453862b6458a996872bf61df6d9a607bad5f6f30829`.
The final source manifest is SHA-256
`712421fc20a28931542887604e45a0138db0cce7354e2cabb59e275e839a2390`.
`seal.json` binds the complete owned evidence membership and these source
identities without a self-hash. Source22, the original phase23 verification,
historical source witnesses and failed/pre-hardening attempts remain intact.

All owned nodes, watchers and CLI/probe operations have exited. Port 18573 has
no listener; the live checkpoint and owned runtime parent are absent. Journal
copies inside evidence are archived observations, not pending checkpoints.
No node, provider, key, custody or configuration operation is pending.
No common-tree file, provider configuration, lockfile, Git ref or production
contract was changed. The root can now perform the independent stopped-state
review against this complete bounded candidate.
