# Bounded Migration operator runbook

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
`nfts.json`, `weighted-liquid.json`, `weighted-sy.json`, `dtf-custody-se.json` and `claim-vault.json` review mirrors plus the accepted `manifest.json`. These contain
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
The fixed18566 rehearsal uses a clearly synthetic 1 ETH-unit payment and
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
  --rpc-alias robinhood_mainnet_alchemy \
  --fork-block 108944663 \
  --port 18566 \
  --checkpoint .omo-runtime/dtf-migration-claim-vault/checkpoints \
  --evidence docs/incidents/2026-09-16-dtf-recovery/migration/claim-vault/implementation-e1
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

Run from the claim-vault worktree on
`work/dtf-migration-phase-16-claim-vault`, based on audited
`4a53299b490343ed904d70c92ecbc7360fcb7659`. The existing archive alias is
resolved through `forge config --json`. On this workstation its credential
is in the existing interactive login environment; `/bin/zsh -lic` can wrap
the exact command above. Do not print the resolved endpoint. The wrapper
uses the installed Solar-capable `/Users/cyotee/.foundry/bin/forge` and Anvil,
and the existing warm `out/`, `cache_forge/` and dependency links.

Port 18566 must be unused and the chosen checkpoint directory absent before
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
| Weighted receipt | H3/H4 original gon/credit mapping and synchronized fungible surrender absent |
| Earlier receipt | H3/H6 original share denominator/fractional attribution unproved; earlier SE exits disabled |
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
atomic cut removes all ten administration selectors across both removable facets. Only the configured
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

The separate ClaimVaultAllocation facet contains only the new loader.
Activation removes its selector and all nine existing administration selectors
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
