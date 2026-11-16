# Bounded Migration operator runbook

## Finite named receipt evidence

```sh
bun scripts/recovery/dtf-migration/cli.ts collect-receipts \
  --input "$COMPLETE_HISTORICAL_TREE" --output "$NEW_RECEIPT_DIRECTORY" \
  --rpc-alias robinhood_mainnet_alchemy
```

Use the existing login-shell archive credential bootstrap. The command reads
only `ALCHEMY_KEY` and the configured alias in `foundry.toml`; never place an
endpoint or credential in argv. There is no endpoint override, signer,
automatic retry, provider fallback or installation. Invalid historical bindings
fail before RPC configuration is read. Offline tests use a local wire server;
the live CLI accepts only the existing Robinhood Alchemy alias.

All manifest/source raw bindings authenticate before deriving the complete
S008 weighted purchases, S009 earlier CP purchases, and `legacy_weight_to_sy`
conversion references. Every original row is retained. Duplicate transaction
hashes share requests, not economic attribution. The observed full historical
population is 43 weighted, 16 earlier and 18 raw claims (77 distinct hashes);
these counts are derived, not a hardcoded request list.

Before named collection, authenticate chain 4663 and canonical block 108944663,
hash `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
Only `eth_chainId`, `eth_getTransactionByHash`, `eth_getTransactionReceipt`,
`eth_getBlockByHash`, and `eth_getBlockByNumber` are sent. Each distinct named
transaction and receipt is requested once. Exact blocks are cached by hash and
number, without range scans. A failed request stays failed; unaffected finite
requests continue. Wrong chain/anchor stops named requests and accounts for
every reference as unavailable. Provider refusal is evidence, never permission
to switch providers, methods, scan ranges or trace execution.

`http/` preserves request bytes and complete safe response entity bytes (not
HTTP framing or original signed transactions). `http-manifest.json` binds byte
lengths, SHA-256, request IDs/methods/parameters, HTTP status and response outcome.
Credential-bearing responses are sanitized, named `.response.redacted`, marked
`raw: false`, and rejected as successful observations. Transport failures retain
sanitized error details, never an endpoint-bearing exception. `archive.json`
records normalized successes, partial failures, canonical associations and exact
request links. `references.json` retains source rows and request deduplication;
`reconciliation.json` accounts for every reference, conflict and qualification.
Output creation and every file write are exclusive. Preserve any partial output
and command failure; never reuse an output directory.

Transaction/receipt/block identities, index membership, receipt endpoints,
every log identity/order, canonical block agreement, successful receipt status
and the anchor upper bound are checked. Purchase reconciliation requires both
the exact NFT mint/recipient and its generation-specific purchase event/basis.
Direct DTF/WETH and routed inputs stay separate. Shared/multiaction or indirect
purchases never attribute the whole transaction input to each original.
Claim reconciliation retains caller/callee/value/calldata, source/SY logs and
exact known output locators/amounts. Only a direct exact-length call to the fixed
TokenStaking address is decoded as `withdrawClaim`; arbitrary calldata is not.
Event signatures/layouts are local interface interpretation, not authenticated
historical build provenance.

The archive version is `dtf-finite-receipt-evidence-v1`, status
`NON-ISSUABLE-RECEIPT-OBSERVATIONS`; operational loaders reject it. Gross transfers,
mints and matching events do not establish net contribution or eligibility.
This is observed RPC JSON, not a trustless proof, historical storage, execution
prefix, current control, full W0/Q0, all prior claims or zero prior compensation.
It does not modify candidates or close all 1240 unresolved records, exhaustive
native/WETH/refund/recovery/source exposure, configuration, funding, C0 or credit.
Preserve recovered-input qualification and all source/external/gas/P1 limits.

## Offline historical review candidates

```sh
bun scripts/recovery/dtf-migration/cli.ts derive-candidates \
  --input "$COMPLETE_HISTORICAL_TREE" --output "$NEW_CANDIDATE_DIRECTORY"
```

The input directory contains the original `manifest.json`, `sources.json` and
every declared file. Preserve relative paths, including the pre-exploit sibling.
Supply paths explicitly; there is no default workstation path, network lookup,
RPC, signer or acquisition fallback. Every declared byte length and SHA-256,
including Markdown, must match before any raw CSV is parsed. The manifest is
the explicit trust root; its binding authenticates `sources.json` before that
index is parsed. Missing, altered or symlinked inputs reject. A supplied
hash-authenticated recovered historical body is not an original capture:
retain its recovery provenance separately, never change a binding to accept
later annotations. The annotated primary tree remains a negative case.

`candidates.json` has version `dtf-historical-review-candidates-v1` and status
`NON-ISSUABLE-REVIEW-CANDIDATES`. It is rejected by preparation, prepared-manifest
validation and execution schemas. It supplies no configuration IDs, C0,
approved flags, invented economic origins, Q0 or known-zero prior credit.
Existing `prepare`/`validate`/execution and journal semantics are unchanged.
Only the new offline command accepts this historical tree.

The weighted NFT join uses S008 purchases, S011 mint/input transfers and S006
pre-incident DTF details, retaining chain/collection/ID, recipient/payer,
purchase/mint/input locators and separate observed DTF/WETH. Transaction sharing,
mint and payer conflicts prohibit unique input attribution. An observed zero
means zero in the saved inbound subset, not zero native cost, refund or net
contribution. The 41 pre-incident and two later purchases are observations, not
eligibility decisions. S009 retains all earlier LP-accounting-lock observations,
direct DTF/WETH and routed intermediate DTF separately. Its unavailable original
raw receipts remain a qualification; routed DTF is not another contribution.

The complete CSV census retains original fields as `historicalFields` alongside
parsed integer/unknown quantities and review links. Blank quantities become
null; only the original signed `gons_delta` column accepts negative integers.
LP-accounting shares, physical LP, gons, raw weights and native9/18/19/28 remain
distinct. No sums across those units are produced. Position/exclusion,
account/position/holding/recovery/exception, index-subset, NFT funding/claim
and observed-output relations are checked. Machine-readable unresolved records
identify missing basis, aliases, previous delivery, incomplete receipts/native/
WETH/recoveries, stale control and unobserved accepted categories. Historical
look-through/held totals are diagnostics, never Q0, contribution inputs or awards.
Unrecomputed reported fields are listed explicitly, not accepted as proven.

All historical policy fields are retained only as history. Current plan r5 and
PRD r22 govern, especially MIG-R42 configured original-wallet/control and
Stage2-only surrender. Old bearer, loss-formula, no-credit-after-custody and
upfront-zero wording supplies no authority. Do not require intermediate-holder
ancestry as a surrender prerequisite. Independent recipient observations remain
separate from asset-surrender candidates; both need disjoint-original review.
Standalone native/WETH observations are contribution/recovery provenance, not
new compensated surrender routes.

Writes are exclusive to a new output directory. Retain every failed output and
command. Repeated runs and a complete byte-preserving relocation from another
CWD produce identical canonical bytes. No wall clock or absolute input paths
enter candidates. To verify the new source boundary locally:

```sh
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext \
  --moduleResolution Bundler --strict --noUncheckedIndexedAccess \
  --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck \
  --types node scripts/recovery/dtf-migration/*.ts
bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts
```

Before any live preparation, separately acquire missing original data/receipts,
refresh pinned current control and recoveries, reconcile exact original units
and contribution components, remaining rights, aliases and previous delivery,
independently review disjoint values, then arrange actual funding and capture
the supported immutable mint-preview snapshot. Only separately reviewed
originals may enter the existing loader preparation. This command does not
close E-S, broader TokenStaking conservation, disabled conversions, operational
dataset approval, selected reserve composition, deployment gas or missing P1
historical artifacts, and does not authorize acquisition or public execution.

## Saved-evidence bundles and fresh relocation

Every rehearsal requires `--bundle "$AUTHORITY_BUNDLE"`, naming a supplied
complete authority bundle's `bundle.json`. There is no default host inventory
or old-worktree fallback. A strict `dtf-operator-authorities-v1` export input
supplies all 22 distinct `authorityRoles` in `bundle.ts`, with original raw
SHA-256, byte length and provenance. Preserve every source qualification.
Runtime acquisition records and four actual ABI artifacts are additional
bound inputs, not substitutes for those authorities.

```sh
bun scripts/recovery/dtf-migration/cli.ts bundle-export \
  --input "$NATIVE_INPUT" --output "$NEW_BUNDLE_DIRECTORY"
bun scripts/recovery/dtf-migration/cli.ts bundle-materialize \
  --input "$BUNDLE_MANIFEST" --output "$NEW_MATERIALIZATION_DIRECTORY"
```

Export accepts a native authority input, preparation input, prepared manifest
or execution manifest. Its raw template, explicitly referenced sources,
snapshot ABI and bound prepared manifest are saved without changing bytes.
Nothing else is discovered or downloaded. Do not include secrets, environment
files or keystores in source lists. Export is offline integrity/transport,
not chain authentication or historical eligibility. Duplicate/conflicting
source identities, ambiguous references and missing inputs reject.

Copy the complete bundle directory to another owned data root, then materialize.
The loader reads every declared regular file, checks raw hash/byte length,
requires exact data membership and rejects traversal and symlinks, including
symlinked roots/ancestors. Original paths are metadata lookup keys, never
alternate filesystem locations. Missing or changed data fails while the old
host file still exists. Do not merge partial exports.

Materialization creates new local templates/manifests, not original captures.
Preparation retains live canonical verification. Post-capture execution
materialization rebuilds preparation against the actual chain and compares
all original saved payloads, configuration IDs, quotes and dispositions.
Prepare and execution revalidate their complete bound bundle. Native absolute
inputs and their existing hash/domain rules remain supported.

Two locations on the same chain/snapshot/originals must produce identical
onchain payload bytes, configuration IDs and frozen quotes. Normalized hashes
and execution domains intentionally differ: locations remain hashed.
Use fresh preparation and checkpoints after relocation. Never migrate an
already signed journal; changed-domain resume rejects. Each genuine resume
uses unchanged inputs in one location. Full replacements and new harvest
selections use fresh templates/domains, not edits to prior bundles/journals.

The complete portable workflow uses only owned loopback18575:

```sh
bun scripts/recovery/dtf-migration/cli.ts rehearse \
  --bundle "$AUTHORITY_BUNDLE" \
  --rpc-alias robinhood_mainnet_alchemy --fork-block 108944663 --port 18575 \
  --checkpoint .omo-runtime/dtf-migration-portable/checkpoints \
  --evidence docs/incidents/2026-09-16-dtf-recovery/migration/portable-operator/implementation/runtime
```

Forge/Anvil resolve from `PATH` or explicit `FORGE_BIN`/`ANVIL_BIN` executables.
Select a Solar-capable installation; no install or compiler fallback occurs.
Installed source, dependencies and Foundry artifacts are prerequisites.
The existing login-shell archive bootstrap remains; never print its resolved
credential URL. Same-host relocation is not cold dependency reconstruction or
cross-platform proof. P1's two historical artifact JSON versions remain
unrecovered. Operational originals, source limits and target gas stay open.

## Complete-original TokenStaking claims prepared into SY

This intake admits only a reviewed original whose entire eligible native18
weight W0 was consumed by direct signed EOA `withdrawClaim` operations before
its Stage1 loading. The source is fixed to chain4663 TokenStaking
`0xe4c9ff4cfd17ae73ecb3825ebdf7db113c146d00`, Wrapped phase2, claim vault
`0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0`, and native9 SY
`0xb55604cf4dcdabb362078e106d20f98512391edf`. Vault shares are native19.
This is prior holder preparation, not an approved Migration pull of raw weight.

Add `claimedOrigin` to the existing `weightedSy` row. Its typed schema is
`claimedSyCertificate` in the existing operator schema. Keep the canonical
wallet-independent `originalId`, original wallet and complete known E0/D0.
The reviewed record explicitly supplies positive `eligibleWeight`, known
`priorDeliveredCredit: "0"`, principal-only eligibility, reward exclusions,
reconciled aliases, no competing representation, and unrelated weight/SY
floors. Unknown or nonzero prior delivery, incomplete original components,
partial preparation and aggregate zero SY are rejected. No allocation here
approves operational historical records.

Each member contains original raw signed bytes, transaction/block identities,
positive native18 `consumedWeight`, exact native9 `receivedSy`, and measured
native19 `redeemedVaultShares`. The admitted execution form is a direct
code-less EOA transaction in an isolated canonical block. Contract wallets,
delegation, special execution and multi-transaction preparation blocks are
not admitted by this validator. A different form needs source admission,
not a guessed trace interpretation.

Preparation checks exact `sum(consumedWeight) == W0` and positive
`Q0 = sum(receivedSy)`, including every actually committed zero-output slice.
Set `originalUnits = Q0`. Never use total wallet balance, an old weight/SY
ratio, a scaled nonlinear input, or a separate full quote for each split.
The existing frozen evaluator quotes complete E0/D0 once; partial and terminal
SY surrender use the existing remaining-Q/C arithmetic unchanged.

The row's `proof` points at the entire reviewed
`{ original, claimedOrigin }` object, not its `original` child. A stripped
certificate therefore cannot validate against that same evidence as ordinary
SY. `claimedSyEvidenceId(domain, original, certificate)` computes the required
nonzero commitment, excluding only the commitment's own field. It binds chain,
Migration proxy, frozen snapshot, complete original inputs, review and every
member. The ordinary-independent SY proof form remains unchanged.
Classification is also reconciled across all referenced reviewed JSON
documents. Selecting a nested or separately copied original tuple does not
erase a claimed-origin marker elsewhere in those reviewed records.
The certificate also binds the actual `snapshotCapture` transaction, RPC
block number and block hash. Its successful canonical receipt must contain
the parent's matching `MigrationSnapshotCaptured` event. The event's EVM
`block.number` is not substituted for the RPC height: those differ on the
admitted Robinhood fork.

The actual RPC, not an uploaded receipt, authenticates canonical block/receipt/
transaction identity, signed caller and calldata, return and claim event,
same-wallet vault redemption, source phase/asset/decimals and admitted proxy/
facet runtimes. Historical source weight/supply/vault/SY deltas must match
the exact member quantities. Unique transactions cannot appear twice within
or across originals. Historical and current aggregate wallet budgets protect
measured descendants and unrelated SY; current consumed units come only from
the real Migration record. Current control at surrender remains mandatory.
Previously configured SY origins must remain in the complete manifest census,
including on subsequent preparation, execution and resume.

Reviewed owner inputs establish historical eligibility, original contributions,
known-zero prior delivery and semantic origin disjointness. Chain observations
establish execution and quantities, not those historical facts. An opaque alias
still requires owner reconciliation. The unchanged onchain loader trusts owner
loading and the evidence commitment; it does not independently authenticate
offchain certificates. Its canonical origin guards exclude other backed,
receipt, liquid, SY, vault-share, LP, NFT and independent representations.
Configuration and resume reconstruct and reauthenticate the prepared manifest
before any signing, so changed evidence, domain or payload cannot be adopted.

The new cumulative rehearsal is:

```sh
/bin/zsh -lc 'bun scripts/recovery/dtf-migration/cli.ts rehearse \
  --bundle "$AUTHORITY_BUNDLE" \
  --rpc-alias robinhood_mainnet_alchemy --fork-block 108944663 --port 18573 \
  --checkpoint .omo-runtime/dtf-migration-claimed-sy/checkpoints \
  --evidence docs/incidents/2026-09-16-dtf-recovery/migration/claimed-sy-integration/implementation/runtime'
```

All earlier loopback gates/routes and three genuine mined-before-checkpoint
resumes remain. The new full/split originals use controlled direct signatures,
actual donor reassignments, real gas transfers and positive excluded weight/SY
floors. Donor impersonation and synthetic historical partitions are labeled
separately. Lossless raw input captures distinguish original bytes from JSON
serialization or later reconstruction. No gas/code/storage/token injection,
source governance or public operation is needed.

Stage1 still rejects surrender. The paid owner-first bond precedes permanent
loader removal and Stage2 opening. Each successful same-wallet SY surrender
creates an exactly funded fresh90-day bond. A later child-funding failure
restores that later SY/Migration transaction, not the earlier source claim:
consumed raw weight stays consumed and the prepared SY stays with its wallet.
Unchanged ordinary-SY contract-receiver/reentry tests are shared-path coverage,
not claimed-origin callback witnesses. EOA-only admission is not broadened.

Direct raw pull, partial/prior-delivered mappings, operational awards, full raw
category closure, other unadmitted sources, blocked conversions, public action,
host portability and target deployment gas remain outside this bounded intake.

## Three fixed native18 SE/LP custody and credit paths

`heldSeLp` contains complete `original` and raw `proof` objects. Originals
require `originalId`, `originalWallet`, `source`, positive `originalUnits`,
known `originalEth` and `originalDtf`, `evidenceId`, and
`contributionsKnown: true`. The three supported chain4663 sources are:

| Source | Fixed token | Eligible units |
| --- | --- | --- |
| W-SW | `0x999dae02d22e5fee1c4508430d5196d31d631009` | native18 weighted WETH/DTF SE shares |
| E-P | `0x923877336b14662cfb5b3a60b14e7d716d54a888` | native18 physical earlier LP |
| W-P | `0x46e068c2393e189fbc86632f67210af253a42aa8` | native18 physical weighted LP |

These are not native28 W-SD, native9 receipt/SY units, ER internal shares,
NFT accounting shares, funded principal, or arbitrary ERC20s. E-S
`0xb7d4bb379d361ad442cddee53ea71a33957826a7` remains unsupported.
Preparation emits a separate `held-se-lp.json` review mirror. Configuration
quotes each complete original separately through the frozen evaluator,
without issuance or merging nonlinear inputs. The canonical wallet-independent
origin excludes all other representations and independent current/issued
history in both directions. A source cannot replace another source under the
same origin; Stage1 same-source wallet/input corrections remain idempotent.
Opaque alias reconciliation and approved historical originals remain
operational inputs, not facts established by token possession.

The existing paid owner-first ordinary bond precedes activation. Activation
permanently removes all14 administration selectors, including
`configureHeldSeLpEntitlements`; queries and `surrenderMigrationHeldSeLp`
remain. Stage1 surrender rejects before effects. Stage2 requires the
configured original wallet's actual native source allowance and control.
Both its debit and Migration's receipt must equal requested positive native18
q. Partial credit is full-precision floor(C*q/Q); exact terminal q==Q delivers
all remaining C. Reject zero credit, failed minimum/deadline, source or
funding/receiver failure atomically. Each successful surrender creates one
exactly funded same-wallet bond with its own fresh90-day principal cliff.
Transfer-away/back neither moves configured compensation nor resets it.
Source maximum allowances decrement too.

Only measured new q enters `migrationRecoveryInventory(source)`, in that
source's native18 units. Preexisting/unsolicited holdings, other held sources,
NFT rewards, ED, ER external E/internal B, WS gons, reserve/donor budgets
and new-bond backing remain separate. There is no new conversion, debit,
donation stage, successful-exit decoder, source enablement, or owner executor.
W-SW exits remain VaultDisabled; E-P retains UnsupportedRoute/native NotOwner;
W-P retains ordinary NotOwner and owner-only liquidity. Custody/credit
acceptance does not accept their liquidation.

The new cumulative local rehearsal uses only loopback18571 and
`.omo-runtime/dtf-migration-held-se-lp/checkpoints`, with the existing
`/bin/zsh -lc` archive bootstrap. It retains all earlier routes and all three
real mined-before-checkpoint/fresh-process resumes. Earlier18567/18568/18569
signer gates remain; there is no public fallback.

Fixture acquisition is explicitly separate from production/operator authority.
W-SW uses an authenticated existing EOA's personal transfer. E-P/W-P use only
the separately admitted disposable-fork simulation: authenticate the existing
EOA collector owner and deployed `pullFee` routing; that owner releases a
small actual collector holding to itself, then separately donates its personal
holding to the controlled original. Both donor operations are impersonated,
not donor-key control, public consent, or a historical allocation. The
controlled original signs its own approval and surrender. Its original
ETH/DTF components are disclosed synthetic code-proof inputs, quoted by the
real evaluator. General execution and Migration gain neither an ability nor
a requirement to call the collector owner method. Actual users must already
control their eligible tokens.

## Earlier liquid ED: custody and credit, not conversion

`earlierLiquid` accepts complete known original records with the same
`originalId`, `originalWallet`, `source`, `originalUnits`, `originalEth`,
`originalDtf`, `evidenceId`, `contributionsKnown: true` and raw proof fields.
The only source is ED `0xaf0E1967c8F755c747615c5427108Bc549CA1122`,
chain4663. All Q0/Q/q are ED native18; credit C is new-DETF native9.
Neither current holdings nor another NFT purchase establishes these originals.
Unknown ETH or DTF rejects; explicitly known zero is valid. Operational
original allocations remain unapproved. Synthetic rehearsal inputs are labeled.

Stage1 owner-only loading and full replacement compute C0 with the complete
frozen original evaluator and issue nothing. The real paid owner-first bond
remains required. Activation permanently removes the ED loader together with
all existing loaders; moving WD loading to the smaller Migration allocation
facet changes no selector or authorization. Stage2 requires the recorded
original wallet's actual approved exact ED transfer, positive proportional
remaining credit, and one exactly funded fresh90-day-cliff bond.
Partial delivery is floor(C*q/Q); terminal q==Q pays all remaining C.
Transfer-back does not reset consumption. ED recovery inventory adds only
measured surrendered ED to the same native18 ledger as existing NFT rewards;
unrelated raw ED is not newly booked. ER internal B and external E remain
separate, in their existing units.

ED conversion is structurally blocked at the historical pin: the positive
source attempt `0x32fef16e3be33c26d73ab92174023ddc65be4266765a66774a54bc8b0455a9fc`
reaches disabled ES `0xb7D4Bb379d361aD442Cddee53EA71A33957826A7`
after positive LP sizing, then rolls back. The original receipt and trace
remain in the immutable source-only worktree. No ED conversion/debit/donation
stage or successful return decoder is installed. Earlier NFT reward holding
and ER custody admission do not change this disposition.

The retained18567 and18568 rehearsals remain accepted. The cumulative ED
rehearsal uses18569 and `.omo-runtime/dtf-migration-earlier-liquid/checkpoints`;
it retains all three real mined-before-checkpoint interruption/resume cases.
Use the existing login-shell archive bootstrap. No source enablement or public
operation is part of this rehearsal. Preparation also emits `earlier-liquid.json`.

## Preparation and read-only validation

Entrypoint: `bun scripts/recovery/dtf-migration/cli.ts`.
Use `--help` for the implemented command domain.

```text
bun scripts/recovery/dtf-migration/cli.ts prepare --input <file> --output <directory>
bun scripts/recovery/dtf-migration/cli.ts validate --manifest <file>
```

Supply real paths and set the environment variable named by `domain.rpcEnv`
outside the command line. Never put a private endpoint or signer in evidence.
The complete input and execution-consumer contracts are in
`operator/preparation/interface.md`; the runtime schemas are in
`scripts/recovery/dtf-migration/schema.ts`.

Preparation requires an actual funded and captured snapshot. It verifies raw
source SHA-256 and byte lengths, full original proof objects, origin
partitions, code/domain identities, the complete immutable snapshot and
separate ETH/DTF frozen quotes. It writes full `independent.json` and
`nfts.json`, `weighted-liquid.json`, `weighted-sy.json`, `dtf-custody-se.json`,
`claim-vault.json`, `weighted-receipt.json` and `earlier-receipt.json` review mirrors plus the accepted `manifest.json`. These contain
configuration, not issued bonds. Every write is exclusive; retain a failed
directory as failed evidence and select a fresh output directory.

Validation reconstructs the manifest from its pinned sources and read-only
RPC calls. Execution must consume the typed return of `validateManifest`,
not the review mirrors or a manually edited payload. `blocked.json` is
rejected evidence, never an executable manifest. Unknown original inputs
remain errors. No unimplemented fungible or TokenStaking allocation is
generated, and earlier claim/sale holding is not earlier liquidation.

Every NFT original now requires a nonzero `originalWallet` from its explicit
acquisition record. The full source proof must match that field; omission,
zero, or a changed wallet without matching recorded proof rejects preparation.
The configuration ABI and hash include it immediately after `tokenId`.
The wallet-independent economic-origin key does not change. Existing payloads
without this field must be regenerated, not filled from live `ownerOf`.
The retained surrender caller must equal this wallet and the live owner;
approval alone is insufficient. Stage 1 rejects surrender before custody;
Stage 2 permits transfer-back surrender without transfer-history proof.
All configuration is removed before any surrender can consume credit.

Weighted liquid inputs use `weightedLiquid`, with full `original` and `proof`
objects. Required original fields are `originalId`, `originalWallet`, `source`,
`originalUnits`, `originalEth`, `originalDtf`, `evidenceId` and
`contributionsKnown: true`. The source is only WD
`0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7` on chain 4663, in native
nine-decimal units. A verified zero contribution is valid; unknown is not zero.
The wallet-independent canonical economic origin must be shared with any
overlapping independent or NFT allocation, not replaced by a fresh alias.
No global alias proof or approved real-user Q0 allocation is supplied here.
Current balances establish custody only, never original quantity or price.

The W-L rehearsal first loads a labeled synthetic original record, Q0
21,225,531, original ETH 10,000,000,000,000,000 wei and original DTF zero.
Its Stage 1 full replacement sets Q0 to 21,225,530 and original ETH to
6,000,000,000,000,000 wei before activation. Neither is an approved historical
allocation. The final correction report is `weighted-liquid/stage2-correction/report.md`.
The sealed incomplete `implementation/report.md` and needs-fix
`verification/report.md` remain historical evidence, not passing acceptance.

Local script checks:

```sh
bun test --timeout 15000 ./scripts/recovery/dtf-migration/preparation.test.ts
```

`operator/preparation/deterministic-fixture.json` records exact synthetic
wire-fixture replacements, IDs and quote outputs. It is not an EVM
execution, real pricing evidence, approved allocation or public loader input.

## Execution and recovery

The fixed stage names remain `deploy`, `fund`, `capture`, `configure`,
`independent-issue`, `owner-bond`, `verify`, `activate`, `harvest`, `resume`, and `rehearse`.
The execution schema is `scripts/recovery/dtf-migration/execution-schema.ts`.
An execution manifest is a strict `dtf-operator-execution-v1` object. It binds
chain, RPC environment-variable name, signer, proxy, registry, package, every
installed facet runtime, raw source/ABI fingerprints, optional exact local
instance/fork identity, typed package arguments and funding inputs. It accepts
no arbitrary target/calldata. The `sources` array must include the genuine
`migration-abi`, `allocation-abi`, `recovery-abi` and `package-abi` artifacts.
All source paths are absolute, quantities decimal strings and unknown values
invalid.

Before capture, `snapshotId` and `preparedManifest` are null. Deployment
receives complete `IUniswapV4DetfMigrationDFPkg.PkgArgs` as `deployment`;
the package calls the actual manager registry. `funding.donations` contains
unique identities and complete token/amount/native/minimum/deadline values.
`funding.genesis` is the optional complete external-leg bootstrap. After
capture, create the preparation input from the actual snapshot, run `prepare`,
and bind its path and snapshot ID in a new execution manifest. The execution
lane always calls `validateManifest`; it never trusts a payload hash alone.

Before `activate`, execute the current proxy owner's first genuine paid
ordinary bond using `owner-bond`. Supply `ownerBond` with explicit decimal
`amount`, ordinary `duration`, `deadline`, and the payment `token`; no public
amount or duration is approved by this runbook. The operator approves that
exact payment and calls the existing `bond` with the signer as recipient and
`pretransferred=false`. It reconciles the canonical receipt, completed
instance bond ID, actual payment debit, funded principal/gons, ordinary
position marker, funded rewards, backing and retained fee/creator rewards.
Independent compensation does not satisfy activation. An absent completed
purchase rejects on-chain before any selector removal.

The purchase's journal is separate from compensation issuance. Resume that
same checkpoint after interruption: a mined purchase is reconciled from its
original transaction and receipt, not purchased again. Ownership or NFT
transfer does not erase the instance's completed purchase. No second Stage1
purchase or other acquisition route is opened; Stage1 rewards stay retained.
The fixed18567 rehearsal uses a clearly synthetic 1 ETH-unit payment and
90-day ordinary linear bond, tests a mined-before-checkpoint purchase and
fresh-process resumes, then activates and performs an actual nonowner
ordinary deposit. This is not a compensation cliff or a public execution
recommendation.

Historical owner-bond evidence is retained under
`weighted-liquid/owner-bond-correction/`; new bounded WY evidence is under
`weighted-sy/implementation/`; previous Stage2 producer/verifier
reports and receipts remain immutable history. Runtime manifests bind the
current main plan r5, PRD r22 and owner-first-bond directive, not stale
worktree requirement copies.

```text
bun scripts/recovery/dtf-migration/cli.ts <stage> --manifest <file> --checkpoint <directory>
bun scripts/recovery/dtf-migration/cli.ts resume --manifest <file> --checkpoint <directory>
```

Each checkpoint directory belongs to one complete manifest and one stage.
Use a new directory for a new stage or changed full replacement. Defaults are
read-only domain/plan validation, not a stateful EVM simulation and not a
receipt. Nothing inherits execution mode from an earlier process.

For an owned local fork, explicitly add
`--execute-local --instance-id <observed anvil_metadata.instanceId>`.
The RPC must be loopback and the manifest's chain, instance, fork height and
fork hash must all match. Only the public Anvil development account is selected.
Public mode requires fresh `--broadcast`, `--confirm-chain`,
`--confirm-proxy`, `--confirm-snapshot` and `--signer-key-env`; synthetic-local
inputs reject it. Public execution has not been authorized for this task.
For the typed pre-capture domain, the fresh snapshot confirmation is the
literal `uncaptured`; it is not a bytes32 snapshot or a quote. After capture
the actual snapshot ID is mandatory.

The journal publishes a fully signed transaction intent and hash, nonce,
starting block, complete typed operation and domain fingerprint before sending.
Files are exclusively created and synced before publication, then the directory
is synced. A crash before a receipt checkpoint leaves the same signed hash
available for reconciliation. Resume checks the canonical receipt, exact
transaction and receipt-block contract state, including actual bond IDs,
principal, recipient, issuance clock and 90-day cliff. A reverted transaction,
missing completed receipt, changed nonce without a known receipt, pending
transaction or conflicting domain fails closed. There is no blanket retry.

Configuration and issuance use bounded singleton rows. `--reverse` may reorder
only their unsettled rows; prior intents are reconciled first. Donations,
genesis and selected recovery stages preserve their order and identity.
Complete configuration replacements do not change prior issued bonds.
`--fault-after-mined` is synthetic-local only and interrupts a donation or
independent issuance after its actual mined receipt and before completion.

`verify` reads complete configurations and issuance independently of transaction
submission. `activate` checks those configurations before executing and records
the atomic removal of every allocation selector. `harvest` uses only the
admitted enum tuples from preparation. Weighted receipt amounts are selected
from attributed gons and a source index, then the actual operation is simulated
before signing. Stored native inventory is not treated as a live quote;
unrelated balances never expand its budget.

## Local rehearsal

The fixed rehearsal invocation is:

```sh
bun scripts/recovery/dtf-migration/cli.ts rehearse \
  --bundle "$AUTHORITY_BUNDLE" \
  --rpc-alias robinhood_mainnet_alchemy \
  --fork-block 108944663 \
  --port 18567 \
  --checkpoint .omo-runtime/dtf-migration-weighted-receipt/checkpoints \
  --evidence docs/incidents/2026-09-16-dtf-recovery/migration/weighted-receipt/implementation/runtime
```

The source pin is chain4663, L2 block108944663, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
not the post-funding snapshot. Rehearsal retains actual registry
deployment and mined receipts, all three mined-before-checkpoint interruptions,
fresh-process resume, no duplicate funding/issuance, unchanged unclaimed
supply, reordered remaining work, domain rejections, accrued attributed-gon
recovery and owned runtime cleanup. Current original-wallet implementation
and independent verification evidence are in
`wallet-admission/implementation/report.md` and
`wallet-admission/verification/report.md`. Historical baseline evidence
remains in `operator/execution/report.md` and `operator/rehearsal/report.md`;
the presence of a command is not proof that its rehearsal passed.

The environment stage is
`Phase_08_Stage_00_OperatorEnvironment.s.sol`; typed transaction simulations
are in `Phase_08_Stage_01_MigrationExecution.s.sol`. Both compile with Solar.
The local environment uses real holder-funded historical DTF and genuine
production packages; its new WETH/rate/liquidity configuration is synthetic
and not a proposed public deployment. The environment computes a proxy in
simulation; the `deploy` CLI separately mines its actual registry deployment.
Every local command and receipt is retained under an exclusive rehearsal
evidence directory. Journals are copied there before the owned node exits
and its temporary checkpoint root is removed.

Run these invocations with the current bundle-capable operator. The historical
weighted-receipt evidence was produced on `work/dtf-migration-phase-17-weighted-receipt`,
based on audited `a96f0fd26c1a1fdba35750cff74d866afa3a9796`; that old checkout is
not the executable for the updated commands above. The existing archive alias is
resolved through `forge config --json`. On this workstation its credential
is in the existing login environment; `/bin/zsh -lc` wraps
the exact command above. Do not print the resolved endpoint. The wrapper
uses explicitly configured or PATH-resolved Solar-capable Forge and Anvil,
and the existing warm `out/`, `cache_forge/` and dependency links.

Port 18567 must be unused and the chosen checkpoint directory absent before
starting. The command creates its own node and checkpoint directory; it
does not adopt an existing node or overwrite an old checkpoint. EIP-170
remains enabled. The local 100-million block gas cap, one-billion Forge
simulation budget and legacy fee selection are rehearsal parameters, not
target-chain transaction limits or a live funding quote.

The independently verified original-wallet local parent deployment consumed
**42,985,865 gas** (the prior operator baseline used **42,985,843**), exceeding
the separately recorded historical `getMaxTxGasLimit()` value of
**32,000,000**. The permissive local fork mined it; this does not establish
that the same deployment can run publicly. Preserve this deployment
feasibility issue for the separately authorized production/package lane.

### Stage and evidence order

| Step | Required input | Recorded result |
| --- | --- | --- |
| `deploy` | Complete pre-capture execution manifest and genuine registered package | Registry membership, runtime/facet bindings and actual owner |
| `fund` | Distinct donation identities, full values and optional all-leg genesis | Actual received-capital events, protected inventory and genesis supply |
| `capture` | Actually funded reserve | Immutable snapshot ID and both RPC block and emitted EVM block provenance |
| `prepare`, `validate` | Pinned source originals and actual captured snapshot | Separate whole independent/NFT replacements, native quotes and fingerprints |
| `configure` | Validated post-capture manifest | Actual replacement IDs/credits; unchanged supply |
| `independent-issue` | Explicit selected recipients | Actual new funded bond IDs, principal, recipient and fresh cliff |
| `verify`, `activate` | Final replacement manifest and completed selected issuance | Effective configurations, atomic selector removal and postactivation verification |
| Original-wallet surrender | Finalized activation, configured original wallet, actual ownership and approval | Actual NFT/W-L custody/consumption and a separate exactly funded fresh bond |
| `harvest` | Consumed custody or attributed inventory; bounded typed selection | Measured claim/conversion/sale/donation and separate revaluation events |

The rehearsal completes Stage 1 configuration/correction and independent
issuance, proves NFT/W-L surrender rejection without custody, allowance,
consumption or funding changes, and then activates. Only afterward does it
execute partial/final W-L surrender, both NFT generations and bounded recovery.
Postactivation negatives cover unconfigured, wrong-holder, approved-operator
and original-wallet-without-ownership calls. Removed W-L loaders reject both
identical and changed inputs after partial surrender without changing Q/C.
Transfer-back succeeds only for the configured original wallet. Weighted ID26
starts with its real transferred holder and is returned by an actual local
source transaction to the explicitly recorded purchaser. No live owner is
substituted into configuration. Recovery remains a separate retained API.
Earlier sale is sale-and-hold, not receipt redemption or DTF liquidation.

### Interruption and recovery procedure

1. Keep the original manifest, its raw source files and checkpoint directory.
   Start `resume` without execution flags to validate the domain without
   selecting a signer or sending a transaction.
2. For the same owned local instance, explicitly repeat `--execute-local`
   and its exact `--instance-id`. The dead writer's lock is released only
   after its process is proven absent.
3. The journal first reconciles every existing signed intent against the
   canonical transaction, receipt and receipt-block state. A mined donation
   or issuance uses the same hash/nonce; it is not sent again.
4. Only independent unsettled configuration/issuance rows may use
   `--reverse`. Funding, genesis and recovery order cannot be reversed.
   A changed manifest, snapshot, proxy, package, source or payload requires
   review and a new domain, not editing an old checkpoint to bypass rejection.
5. Stop on ambiguity, a canonical revert or a domain mismatch. Preserve the
   failed files and diagnose the exact intent; there is no automatic retry,
   rollback of already mined transactions or permission to duplicate a
   donation under a new identity.

The real rehearsal retains `donation-before-resume.json` and
`issuance-before-resume.json` while the successful receipt exists but its
completion file does not. Matching `*-resumed.json` files bind that same
receipt to the fresh-process completion, including emitted bond identity.
Four synthetic independent recipients leave three selected and one
unclaimed. After the first selected issuance is interrupted, two unsettled
rows remain; `reordered-issuance.json` checks their actual nonce order is
reversed, with exactly one bond per selected recipient.

The original and reordered preparation inputs must produce byte-identical
`manifest.json`, `independent.json` and `nfts.json` within the same pinned
domain. `deterministic-preparation.json` records their SHA-256 and sizes.
Different node instances, evidence paths or snapshot domains legitimately
change domain-bound fingerprints; they are not claimed byte-identical.

Every deliberate rejection must exit 1 with `DOMAIN` and leave the signer
nonce unchanged. The five wrong-domain cases are chain, proxy, package,
snapshot and prepared payload. A sixth case rejects reversing funding.
Default resumes are separately checked to leave the nonce unchanged.

### Reading receipts and cleanup

Each `dtf-custody-se/implementation/rehearsal-<run>/` retains the redacted Anvil argv, Solar
environment command, numbered CLI command/exit records and logs, actual
infrastructure/fixture receipts, deterministic data and `journal-*`
directories. `.intent.json` contains signed local-development transaction
bytes; `.receipt.json` contains canonical receipt and checked state.
Simulation/read-only output is never counted as a mined receipt.

Use `wallet-admission/verification/report.md` and its referenced
`execution-index.json`, `source-artifact-parity.json`, `cleanup.json` and
independent rehearsal evidence to join commands, nonces, actual bond IDs,
native gas used, executable artifacts and source/evidence fingerprints.
The earlier `operator/rehearsal/` records remain historical baseline evidence.
Receipt gas describes these specific local transactions only. Retain the
admitted bound of at most eight weighted claims or one other recovery step,
and estimate each exact selected operation against actual chain limits
before any separately authorized operation.

The CLI awaits node exit, closes receipt subscriptions/providers, stops
holder impersonation in `finally`, copies checkpoint bytes into evidence,
then removes its owned checkpoint root. `cleanup.json` records that sequence.
The rehearsal report also records port/PID absence and removal of the empty
task-created runtime parent. Preserve evidence, shared services, warm
artifacts and dependency links.

### Required categories still blocked

| Category | Unclosed gate |
| --- | --- |
| Weighted liquid DETF | Approved original-wallet Q0/component allocation required; Stage2 correction report records bounded synthetic-input integration |
| Earlier liquid DETF | H3/H6 original native-unit configuration/surrender absent; ED liquidation unproved |
| Weighted receipt | Bounded admitted eligible-original-gon mapping and synchronized Stage2 custody; approved operational original allocations remain absent |
| Earlier receipt | Bounded exact internal-share custody/frozen credit within the singleton-rate measurement domain; liquidation remains blocked by disabled ES; operational originals unapproved |
| Weighted SY | Fixed WY integration is bounded to synthetic original-wallet/static-share/component inputs; approved operational allocations remain absent |
| TokenStaking raw weight | `reassign` debits caller, with no approved pull or recipient callback; ordinary Migration atomic surrender unsupported |
| Claim-vault direct shares | Bounded configured direct native19 share support; approved operational original-wallet records remain absent. Indirect weights retain the separate caller restriction |
| Underlying SE shares | Direct-user records/integration absent; earlier and weighted WETH SE disabled; fixed W-SD is admitted separately with synthetic allocation inputs only |
| Fungible LP | Original records/integration absent; owner-restricted exits and earlier `UnsupportedRoute` remain |
| Earlier liquidation | SB-E1/E2/E3 disabled exits; SB-E4 unproved liquid conversion |

These categories remain in every disposition matrix, even with zero input
rows. None obtains invented credit, an executable substitute or a no-op
success. Synthetic originals, external liquidity and local funding are
operational test data, not approved allocations. Full original task 9 and
release remain open.

## Weighted SY increment

The required `weightedSy` input array uses the same original fields as
`weightedLiquid`, but only WY `0xB55604CF4dcdABB362078e106D20F98512391EdF`
on chain4663 is accepted. Q0/Q/q are native nine-decimal **static shares**.
The canonical origin must be shared across WY, WD, either NFT and independent
compensation for the same exposure. No wrapper/backing second award is allowed.
Both ETH and DTF components must be explicitly known. C0 uses the frozen quote;
partial credit floors C*q/Q and final surrender receives all remaining credit.

Stage1 loading is full-value replacement without issuance. Stage1 surrender
rejects. The owner-paid first ordinary bond still precedes activation, whose
atomic cut removes all eleven administration selectors across both removable facets. Only the configured
original wallet with actual WY allowance and shares can surrender in Stage2;
each successful pull creates one fresh exactly funded 90-day cliff bond.

Append-only recovery enum `WeightedSyRedeem` is ordinal8. Select `tokenId=0`,
`amount` in WY shares and `minimum` in native WS units. The fixed legacy
`redeem(MIG,shares,WS,minimum,false)` call burns only booked WY. Actual WS gons,
source synchronization and conversion dust are reconciled before existing
`WeightedUnstake`, `WeightedConvert` and fixed-destination `Donate` stages.
Unsolicited WY/WS and preexisting attributed NFT gons never create compensation.
A failed selected batch rolls back its burn and all downstream changes.

The fixed18566 rehearsal preserves the prior NFT/W-L sequence and donation,
independent-issuance and owner-purchase interruption resumes. It adds synthetic
WY Q0=8094, then replaces Q0 with8087 and ETH with6000000000000000 wei in
Stage1, leaving seven shares for an unsolicited-custody witness. Actual
partial/final surrenders and selected redemption/unstake/conversion/donation
receipts are recorded in `weighted-sy-{stage1,partial,final}.json`; final
bond IDs and outputs come from receipts, not the historical8094-to9245 quote.
The final surrender occurs one simulated day later. Source bindings and failed
whole-batch rollback receipts are retained beside those observations.

Other categories remain required with their recorded source/input limitations.
This increment supplies neither an operational allocation dataset nor a
full-category, target-gas or public-execution acceptance.

## Fixed DTF-custody SE increment

The required `dtfCustodySe` array uses the same complete original-input tuple,
but accepts only W-SD `0x2E9C1F705aB967c5Af59249203d7495bDabb223b`
on chain 4663. Q0/Q/q are native **28-decimal shares**; the fixed asset DTF
is 18 decimals. Both original components must be explicitly known. Current
holdings and live redemption rates supply neither original eligibility nor C0.
The canonical economic origin is shared with independent compensation, both
NFT families, WD and WY. Opaque keys still require operational partition review.

The local rehearsal verifies authenticated deposit/redeem facet code and ABI,
then signs an actual `deposit(uint256,address)` acquisition from development
wallet derivation index 104. Its DTF is transferred from the existing real
legacy-claim-funded developer inventory, not minted or taken from a hook's
share holdings. The wallet pays 1 DTF; the actual minted shares establish
custody, not approved historical compensation. The labeled synthetic original
allocation is replaced before activation with Q0 reduced by seven native
shares and original DTF set to 0.6 DTF. All quantities remain integer strings.

Stage1 rejects every surrender. Stage2 measures the original wallet's exact
share debit and Migration receipt, consumes remaining C*q/Q with final residue,
and creates one fresh exact-funded 90-day cliff bond per surrender. New loading
is permanently removed by activation, including identical and corrected calls.

Append-only `DtfCustodySeRedeem` is recovery ordinal 9: tokenId is zero,
amount is booked native shares and minimum is actual native DTF output. The
fixed call is `redeem(q,MIG,MIG)`; no own-share allowance is required.
Only exact selected share burn and positive measured DTF equal to the returned
assets are booked. Output minimum and selected-batch failure revert the whole
transaction; later failures cannot undo earlier committed receipts. Donate
remains the fixed new-DETF route and cannot buy an ordinary bond or issue credit.

Acquisition, Stage1 negatives, partial/final funded surrender, exact redemption,
minimum/batch rollback and protected inventories have separate receipt evidence.
The current rehearsal preserves all earlier positive routes and all three mined
interruption resumes. No W-SW, earlier SE, LP, operational allocation, full-plan
or target-gas acceptance follows from W-SD success.

## Direct claim-vault increment

The required `claimVault` array carries explicit original wallet, canonical
economic origin, fixed source, native19 original units, both known ETH/DTF
components and evidence identity. Only chain4663 vault
`0xAf5C0cD3fDEdd10bee00Eff77Fa0429Bacdb41f0` is accepted. Its asset is
native9 static WY `0xB55604CF4dcdABB362078e106D20F98512391EdF`.
No TokenStaking weight or infrastructure backing authority is implied.

E1 is pinned runtime/selector identity and executed controlled-wallet payment,
share mint, custody, redemption and rollback, not a metadata-download gate.
The actual routed facet is `0x517234F78A4BcAfc5F880024A3E45D49cF43b305`,
runtime keccak256 `0x8c1ea71d607b09b21c4e78f850647a059dc7935b6772f7cd3aeaa700a995439f`.
The executed layouts are `deposit(uint256,address) -> uint256` and
`redeem(uint256,address,address) -> uint256`. Archived-source equivalence
is not established. Zero-share redemption succeeds with zero output at this
pin; Migration therefore rejects zero selections and nonpositive output itself.

The18566 rehearsal signs its own acquisition from development derivation105,
funded with3000 real SY from the existing EOA holder, never infrastructure
share custody. The synthetic original DTF input is replaced with0.6 DTF and
Q0 reduced by seven native shares in Stage1. Those inputs are deliberately
not derived from the source rate or presented as approved historical awards.
Stage2 exact approved surrender conserves remaining Q/C and exact terminal
residue, creating a new exact-backed90-day cliff per operation.

The separate ClaimVaultAllocation facet now contains direct-share and weighted-receipt loaders.
Activation removes both selectors and all nine existing administration selectors
atomically. Direct-share reads/surrender live on the retained Recovery facet,
keeping the deployed facets within EIP170 without changing ordinary production.

Recovery ordinal10 `ClaimVaultRedeem` selects booked native19 shares only,
with tokenId zero and minimum in native9 SY. Fixed `redeem(q,MIG,MIG)` must
burn exactly q, reduce source supply by q, and pay positive measured SY equal
to both its return and the source debit. The output is booked once into WY
inventory, then existing ordinal8/3/4/7 stages redeem to WS gons, unstake WD,
convert DTF and donate to the fixed new reserve. No additional personal credit
or ordinary bond is issued. Prior WY/NFT/WD/W-SD, unbooked shares/SY/gons/DTF,
donation/residual budgets and funded new bonds remain separate protected domains.

Evidence is disjoint under `claim-vault/implementation-e1/`; sealed
`implementation/` and `verification/` reports retain their former gate and
no-support handoff unchanged. All three mined interruption resumes and earlier
source scenarios remain mandatory. Operational original datasets, raw weights,
other blocked SE/LP exits, full-plan completion and public gas feasibility are
not closed by this increment.

## Weighted receipt increment

The required `weightedReceipt` array has the complete original-input tuple used
by the other fungible configurations, but `originalUnits` is **Q0 eligible
original ownership gons**, not native9 WS. Only chain4663 WS
`0x4Fa4974a8a09660258B8edD430B51C1620eBFE5c` is admitted. Original allocation
evidence supplies Q0 and both explicitly known original ETH/DTF components in
their original economic grouping. Where principal receipt acquisition proves
Q0=P0*kOriginal, retain its actual original-operation divisor; neither a live
balance nor the incident-pin divisor supplies missing historical quantities.
Principal and reward allocations are separate, including NFT descendants.
Current possession cannot enlarge configured original eligibility.

`configureWeightedReceiptEntitlements` is owner-only, complete/idempotent Stage1
replacement on the frozen snapshot, without issuance. Activation permanently
removes this eleventh administration selector with the other ten. Canonical
economic-origin exclusions apply both ways across independent compensation,
both NFT families, WD, WY, W-SD and direct claim-vault shares. The retained
query and surrender methods live on Recovery; the removable loader shares the
smaller ClaimVaultAllocation facet. Real EIP170 checks remain enabled.

`surrenderMigrationWeightedReceipt(originalId,nativeAmount,minimumCredit,deadline)`
requires Stage2 and the configured original wallet. It settles old WD rewards
inside the guarded operation before either WS endpoint baseline. It then uses
the wallet's actual native9 allowance and requires unchanged transfer divisor k,
exact n*k wallet gon debit/custody credit and consistent floor(gons/k) native
balances. Role allocations, prior inventory and unsolicited balances are not
new custody. Any source, credit, funding or callback failure reverts the entire
operation, including old-source synchronization.

Consume q=n*k only when 0<q<=Q. Deliver C on actual q==Q, otherwise floor(C*q/Q)
with full precision; positive credit and minimum protection are mandatory.
One successful operation creates one exactly funded fresh90-day cliff bond to
that original wallet. Neither rewards nor later source growth reprice C0.
Preserve residual Q/C, including a positive Q smaller than one transferable
native unit's k gons. Such a record does not promise future representability.
There is no alternate native pricing mode, invented original divisor, ceiling
custody, clamp, excess donation, forfeiture or display-zero clearing.

Only measured transfer gons join existing recovery. The fixed route remains
WS -> WD -> DTF -> this new reserve, using existing recovery ordinals3/4/7.
Source growth is recovery value, never another personal award. Actual
full-account gon retirement, mixed NFT/WY inventory, role gons, unbooked whole
units/fractions, donation/residual budgets and new-bond backing remain separate.

The fixed18567 CLI genuinely acquires101 native WS through signed WD approval
and staking from public development derivation117. Its initial Q0 is that
actual operation's acquired gons; synthetic original ETH0.01 is replaced by
ETH0.006 in Stage1, with known DTF0 and unchanged documented Q0. These are
code-proof originals, not operational historical awards. All WS signed bytes
and raw receipts are retained as `ws-signed-<signer>-<nonce>.json`.
The runtime binds the admitted source contract, actual independent admission,
implementation authority, current main plan/PRD and source acquisition.
It retains the entire prior-category sequence and all three genuine mined
donation/issuance/owner-purchase checkpoint interruptions and resumes.
`weighted-receipt-{stage1,partial,residual}.json` records custody/credit/bonds;
the two recovery files record selected late rollback and fixed donation.

Keep source/ and source-verification/ immutable and historical failures intact.
Producer implementation evidence and independent runtime verification use
disjoint `weighted-receipt/implementation/` and `weighted-receipt/verification/`.
The phase15 W-SD archive remains a retained host dependency. Operational
originals, other source categories, portability, full hermetic/full-plan
acceptance and target deployment gas remain open; a permissive local node
does not establish the historical32-million transaction limit is met.

## Earlier ER receipt increment

`earlierReceipt` supplies complete `original` and raw-bound `proof` objects.
Its original tuple has `originalId`, `originalWallet`, fixed `source`,
`originalUnits`, explicitly known `originalEth` and `originalDtf`,
`evidenceId`, and `contributionsKnown: true`. Only chain4663 ER
`0x4AC89aD061A531FA62ddceED53520C2750113b01` is admitted. Q0/Q/q are exact
internal ER ownership shares, never displayed native18 or external floor
shares. Preserve original acquisition input/rate or authenticated mint
evidence and the eligible/excluded allocation; current holdings cannot
supply missing originals. Each original's components are quoted once on
the frozen evaluator, with no supplied award or selectable pricing mode.

Stage1 configuration is owner-only full replacement and idempotent replay,
without issuance. Canonical origins exclude independent compensation, both
NFTs, WD, WY, W-SD, direct claim-vault and WS in both directions, including
wallet corrections. Activation requires the genuine paid first owner bond
and permanently removes all twelve administration selectors across the two
removable facets. No Stage1 surrender or Stage2 amendment is available.

`surrenderMigrationEarlierReceipt(originalId,nativeAmount,minimumCredit,deadline)`
requires the configured original caller and actual displayed-unit allowance.
Under the shared parent lock, the actual fixed-source approved pull observes
both endpoints' external shares and displayed balances, positive unchanged
rate and unchanged total external shares. Full-precision interval inversion
must prove `rLow == rHigh == r`; equal pre/post rate alone is insufficient.
Both floor carries are valid, but unresolved, inconsistent, zero and
overflow measurements revert. There is no exact internal-share getter in
production and no displayed-balance absolute input cap.

Only measured q consumes remaining frozen Q/C: actual q==Q takes all C,
otherwise floor(C*q/Q). Positive credit and minimum/deadline protection are
required. Preserve nonrepresentable Q/C without rounding up, clamping,
forgiving, clearing display-zero balances or promising future rate movement.
Each success atomically funds one fresh same-wallet90-day cliff bond.
Source, credit, funding or receiver failure restores the enclosing transaction;
an earlier independent approval remains. Later callback donations are unbooked.

`migrationRecoveryInventory(ER)` retains NFT-sale external-share inventory E.
`migrationEarlierReceiptInternalShares()` separately returns standalone B.
Its whole external representation is B/1e9 and fractional internal
representation is B%1e9. Total booked internal ownership is checked E*1e9+B.
Never add B directly to E. Both NFT/standalone arrival orders retain unrelated
internal fractions.

Custody/credit is available; liquidation is blocked. There is no new ER
conversion, debit or donation recovery stage. Retain the actual direct ER
and parent ED `VaultDisabled(ES)` failures and historical labels. No
governance enablement, arbitrary executor or success decoder is supplied.

Run this retained scenario with the current bundle-capable operator and a
complete authority bundle. Its historical phase18 evidence used base
`acdbe319f3a20c3af6bea594c62461b6c7988717`:

```sh
bun scripts/recovery/dtf-migration/cli.ts rehearse \
  --bundle "$AUTHORITY_BUNDLE" \
  --rpc-alias robinhood_mainnet_alchemy --fork-block 108944663 --port 18568 \
  --checkpoint .omo-runtime/dtf-migration-earlier-receipt/checkpoints \
  --evidence docs/incidents/2026-09-16-dtf-recovery/migration/earlier-receipt/implementation/runtime
```

The prior18567 invocation and all previous routes/resumes remain accepted.
New signing remains restricted to the owned fixed loopback rehearsals.
The CLI binds both immutable admission documents and genuine ER acquisition;
its original ETH0.01 then ETH0.006 replacement and known DTF0 are synthetic
code-proof components, not operational awards. It retains signed ER bytes,
raw receipts, actual Migration Q/C/B/E and fresh bond observations together
with all three mined-before-checkpoint donation/issuance/owner-purchase resumes.
Keep failed attempts and source/admission evidence unchanged.

The retained phase15 archive dependency, legacy source-match qualifications,
operational originals, opaque-origin reconciliation, other blocked sources,
host portability, full hermetic/full-plan acceptance and target gas remain
open. Prior parent deployment44,353,454 gas exceeds32million; the new
rehearsal's permissive node does not convert that finding into target acceptance.
