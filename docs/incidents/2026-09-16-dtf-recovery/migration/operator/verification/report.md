# Independent bounded operator verification

Date: 2026-11-11.

**AdversarialVerify: confirmed for the bounded operator implementation and
the exercised local resume contract.** A fresh, independently owned invocation
of the actual CLI completed both mined-before-checkpoint interruptions and
fresh-process resumes. The same donation and issuance transactions were
recovered without duplicate funding or bonds. All 264 recorded receipts are
successful and unique. The independent script check passed 50 tests with
zero failures.

**Full original task 9 and release remain open.** Ten required categories
remain explicitly blocked. Synthetic inputs are not approved allocations.
Public deployment feasibility remains unresolved: the genuine parent
deployment used 42,985,843 gas against the separately recorded historical
32,000,000 transaction limit. Local success does not close that gate.

## Scope and accepted source

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-08-operator`.
Branch: `work/dtf-migration-phase-08-operator`.
Initial and final HEAD: `421072a7630a0d3d47a6f36e1062d9eae98c93e2`.

Read both complete phase08 contracts, original plan task 9 and
MIG-P03/P07/P11/P13/P14, the provenance preparation recipe, repository rules
and applicable Bun, programming, Foundry and script skills. Read complete
preparation, execution and rehearsal reports and interface/runbook, plus
phase07 source-verification, implementation, correction-verification and
commit receipt/verification reports in their original worktree. Inspected
the actual CLI, preparation, quote, execution, journal, reconciliation,
rehearsal and stage code, and the production recovery/destination code.

Root's notepad records independent recovery commit acceptance and successful
`OPERATOR_WARM_SEED_READY` / `OPERATOR_WORKTREE_VERIFIED` before dispatch.
Direct branch, HEAD, dependency-link and warm-directory observations agree.
All 25 current operator script/stage hashes match the final predecessor
bindings and remain unchanged through this verification.

Authored only this verification directory's witness and evidence. No
production, shared TestBase, existing test, operator source, runbook,
configuration or dependency edit; no source commit, push or merge.
The inherited tracked change remains solely
`MigrationCoreLocalQA._localInfrastructure` from private to internal.
The final tracked/staged scope check reports no production/test/configuration
delta. Warm artifacts and shared links remain intact.

## Independent execution and exact commands

The independent driver is [witness.ts](witness.ts). It imports no operator
validation or assertion helper. It starts the actual CLI in a fresh process,
subscribes to the completed deployment-command file before launching, and
executes two additional real CLI rejection cases against the owned node.

Actual wrapper:

```sh
cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-08-operator
/bin/zsh -lic 'bun docs/incidents/2026-09-16-dtf-recovery/migration/operator/verification/witness.ts'
```

Actual application invocation:

```sh
bun scripts/recovery/dtf-migration/cli.ts rehearse \
  --rpc-alias robinhood_mainnet_alchemy \
  --fork-block 108944663 \
  --port 18560 \
  --checkpoint .omo-runtime/dtf-migration-operator/checkpoints \
  --evidence docs/incidents/2026-09-16-dtf-recovery/migration/operator/verification
```

Only the caller-supplied evidence destination differs from the fixed
rehearsal example, to obey this lane's exclusive write ownership. The driver
passes that destination as an absolute path. Entrypoint, fork, alias, port,
checkpoint and real execution logic are unchanged.

Monitor `mon_MRNVMBBCPKPH7RTD` / `bash_2`: **exit 0**, with
`INDEPENDENT_REHEARSAL_COMPLETE`. The fresh run is
`execution/rehearsal-1794377054937/` beneath this directory, abbreviated **R**
below. [independent-command.json](independent-command.json) retains the
literal argv, process identity, exit and output.

- 220 infrastructure receipts, 33 operator-journal receipts and 11 genuine
  legacy funding/surrender receipts: **264 unique successful receipts**.
- 42 numbered CLI subprocesses: 34 exits of 0, six deliberate DOMAIN exits
  of 1, and two deliberate SIGKILL interruptions.
- One successful Solar environment-stage subprocess, plus two independent
  rejection subprocesses. These are not added as transaction receipts.
- Anvil readiness, WebSocket subscription acknowledgement, canonical receipt
  observation and process exit are exact signals. Receipt waits are bounded
  at 60 seconds, RPC requests at 15 seconds, node readiness at 30 seconds
  and stage processes at one hour. No sleeps or timed polling were added.

`R/anvil-command.json` and `R/environment-stage.log.command.json` retain
the redacted Anvil argv and exact `forge script --use solar` command.
The environment log reports compilation skipped for unchanged sources and
successful onchain execution. It uses genuine manager-registry packages,
with a separate actual CLI parent deployment. No EIP-170 or simulation
bypass occurred. The shipped Stage 01 wrapper was source-inspected but not
separately invoked; the CLI submits its typed ABI transactions directly.
Only public Anvil development signing and local holder impersonation were
used. The archive endpoint was resolved internally, not recorded.

## Chain, snapshot and executable identity

| Identity | Independently observed value |
| --- | --- |
| Historical chain / RPC block | 4663 / 108944663 |
| Historical block hash | `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733` |
| Fresh Anvil instance | `0xaac27e7a12e971c25e2963d91f7dd1de80b809e84425cbc85b8263bf840c28d6` |
| Migration proxy | `0xedf7d9f65b9e57d62a3c4278223170db1308f5f0` |
| Manager registry | `0xaa66038ae217b246f5bf7537104342672e56fed8` |
| Migration package | `0x642fa76f2f7a6b97ec0822d67a785379a92df347` |
| New bond vault | `0x76d3b85be8cc91df1e66cfd3c81681795555e58c` |
| Actual captured snapshot | `0x0c714d0a1aae0748c6a999943342deeb825e2dd27a647f544dee481f6d3576cb` |
| Capture RPC block / emitted EVM block | 108944894 / 26367890 |

The historical header's L1/EVM block is 26367659. It is neither the capture
block nor the RPC/L2 number. The snapshot seal was independently recomputed
from the complete ABI-decoded snapshot with its ID cleared; chain, consumer,
subject and the captured ID agree.

[baseline.json](baseline.json) and [evidence.json](evidence.json) distinguish
raw source SHA-256, artifact-envelope SHA-256, compiler-source Keccak-256,
creation-bytecode Keccak-256 and immutable-populated runtime bindings.
All four artifact envelopes/executables remained identical. All **226**
package/recovery compiler-source comparisons match current source.
The CLI validated 20 actual proxy/registry/package/facet runtime bindings.

The actual successful factory transactions contain the accepted creation
bytes, also recorded in their `additionalContracts.initCode`:

| Contract | Creation Keccak-256 | Actual factory transaction |
| --- | --- | --- |
| Migration package | `0xf9a8cc0c49ddc52cd96274b7354c089f66462f33243654970986e0d844a426c3` | `0xf1285cacf175341f26921cce0b026dc2b897291455647f53599436c0588963a4` |
| Recovery facet | `0xb5c728e1d786308228f9d92388fc5483226229b9207f27d36dbde5f8f0ef1c02` | `0xcd2c78c208ce0c121a32998992932418cbaba73fa273f51a49077ae48ea11362` |

The package creation prefix has its genuine 640-byte constructor suffix;
the recovery facet has no constructor suffix. The separately mined parent
deployment is
`0xbc2ffc265391562244269342481d3d072e17e8fcec09e9f8d4938f69b10ee5ed`,
nonce 2115. Deterministic transaction hashes can equal predecessor hashes;
the independently owned node identity, new receipt blocks and this run's
command/evidence chain establish the fresh execution.

## Interruption, resume and nonduplication

| Scenario | Same recovered transaction | Nonce / mined RPC block | Result |
| --- | --- | --- | --- |
| Donation | `0xf71dd562dc1b517823ad5b0bc2449c706b6d98f991ce2b8ea110e9735d0f326b` | 2118 / 108944892 | One donation, identical canonical receipt recovered |
| Independent issuance | `0x1b945ebd67551ec40864abd1408ed4f2295c3ceed661ce09f06c58d6ce7344af` | 2128 / 108944902 | Same bond 3, principal 461, creation timestamp 1794111155, cliff 7776000 seconds |

`R/donation-before-resume.json` and `R/issuance-before-resume.json` record
successful mined receipts while the completion files are absent. The actual
fault logs and SIGKILL exits corroborate that boundary. Fresh default resume
processes returned read-only plans and left signer nonces unchanged; fresh
explicit-local resumes reconciled the receipts and receipt-block state.
The retained completion receipts are byte-equivalent as parsed objects to
the interrupted receipts, with exact intent fingerprints.

The independent offline audit parsed every signed operator transaction and
checked hash, signer, target, calldata, value, nonce and chain, then joined
its actual receipt and decoded events. All 33 hashes and signer nonces are
unique. Completed operations were not resent.

Three received-capital events total exactly 1000e18 WETH and 1000e18 original
DTF. WETH is 900e18 transferred plus 100e18 wrapped native ETH. Exactly one
`donateMigrationCapital` intent/receipt exists. Configuration leaves genesis
supply at 1000000000000. Three 461-unit independent bonds raise supply to
1000000001383.

Original selected order was `0x0e9971...`, `0x8c3229...`, `0x9586a4...`.
Actual nonce order is `0x0e9971...`, `0x9586a4...`, `0x8c3229...`, producing
bonds 3, 4, 5 at nonces 2128, 2129, 2130. Thus two genuinely unsettled rows
were reversed, not a one-row identity permutation.

The fourth configured recipient,
`0xc4c81d5c1851702d27d602aa8ff830a7689f17cc`, remains unissued with bond ID 0
both before and after activation. Full replacement doubles an already
issued recipient's original ETH input while preserving its bond 5,
461-unit principal, issuance record and total supply. No delta or retroactive
top-up is generated.

## Preparation, quotes and rejection coverage

Distinct real CLI preparations against the actual snapshot reverse sources,
exposures, configuration rows, issuance selection and bindings. Independent
byte comparisons confirm identical outputs:

| Output | Bytes | SHA-256 |
| --- | ---: | --- |
| manifest.json | 29431 | `defd986e33181f8ea9e41cf2ec1f53b67e16a0c0a06da52506652ba7420aa814` |
| independent.json | 1502 | `ee23f0ba3ee6f4e68bc42ab8b4c03be13d79b4bb9e9d9ba09cb87d64c29b1b39` |
| nfts.json | 802 | `f458dffc7a422b9d2b06af993365edb4006f0b5e60f30f8611b744d100244974` |

Normalized and complete-payload fingerprints were recomputed independently.
Every referenced raw source hash and byte length matches. Configuration
payloads contain complete original setter values, not arbitrary C0 credit.

Actual frozen quote pairs include 1e12 ETH units -> 461, 3e16 ETH units ->
13872781, 2e18 ETH units -> 923391925, and 50e18 original DTF units ->
22233172691. Each pair independently evaluates ETH-only, DTF-only and
combined inputs against the same pinned snapshot; component sums match.
This real fixture has no original with both components nonzero. That
combined-input case is covered by the explicitly synthetic wire fixture,
not misrepresented as another real-chain case.

Six real resume negatives exit 1 with `DOMAIN` and unchanged signer nonces:
funding reversal, wrong chain, proxy, package, snapshot and tampered prepared
payload. See `R/006-rejection.json` and `R/016-rejection.json` through
`R/020-rejection.json`, with matching numbered command logs.

The independent driver additionally executed:

- **Synthetic public mode:** complete fresh confirmation flags and an
  explicitly named unused signer variable still reject at the local/synthetic
  domain guard, before signer loading or journal creation.
  [synthetic-public-mode.json](synthetic-public-mode.json).
- **Wrong explicit instance:** actual local metadata with an incorrect
  confirmation rejects at the exact-local-identity guard.
  [wrong-instance.json](wrong-instance.json).

These two calls used the owned loopback endpoint; no public transaction or
production signer was used. They ran alongside legitimate rehearsal work,
so no isolated signer-nonce comparison is claimed for those two additional
cases. Their specific guard errors and absence of journals establish their
rejections.

## Genuine surrender, recovery and fixed destinations

Actual holders approve and surrender weighted NFTs 4 and 26 and earlier
NFT 3, producing bonds 6, 7 and 8 with credits 13872781, 22233172691 and
923391925. Exact hashes, holders and consumed source units are in
`R/fixture-receipts.json` and the independent ledger's `nftSurrenders`.

Nine actual harvest transactions exercise enum stages
`0,1,2,3,3,4,7,5,6`: combined weighted claim, principal, rewards, original
unstake, accrued-value unstake, conversion, donation, earlier claim and sale.

- Original claimed weighted inventory: **103956882** native units.
- After that entire quantity is converted, attributed gons are
  **10409763033057185597048179296227270999448** at synchronized divisor
  **875381719530275893679866214021516565**.
- A separate genuine transaction converts the remaining **11891** whole
  accrued units. Total weighted DETF output is **103968773**.
- Weighted conversion receives **557313002092495862260** original DTF units
  at the Migration proxy.
- Exactly **1e18 DTF** is selected for the fixed new reserve. The measured
  net LP output is **119458440568358912**, minted to the new bond vault.
- Earlier claim holds **124873542679524901** earlier DETF units. Sale retires
  **562524912595035608166** original accounting shares and holds
  **485044501927175493321** external receipt shares. The displayed ERC20
  receipt transfer is a different unit, not substituted for those shares.

Actual token transfers corroborate the fixed Migration recipients. Recovery
calldata has only typed stage/ID/amount/minimum/deadline fields, no recipient
or arbitrary executor. Source inspection confirms current-owner authority,
attributed-gon protection, fixed legacy endpoints and the same reserve path.
No recovery receipt contains compensation issuance or new Migration DETF
minting. Final supply **1023170438780** equals genesis plus exactly the three
independent and three surrender credits.

The normal hook also mints **119578018586943** fee LP units to the configured
fee collector `0xc02c5970bc54eb54442c421c7de43eec12481c5d`. These match actual
`ProtocolFeeMinted` events and the unchanged `_finishJoin` fee flow. They are
separate from net recovery LP; fixed destination does not erase ordinary fees.

Activation transaction
`0x46e82b433c5eb48fd8b1e0a3d9673d5607a30aaafc3f4dcd17c6f9c2ae903b94`
sets activation and removes exactly the six interface-derived allocation
selectors. The independent audit matched actual removal events to the ABI;
the real CLI also checked receipt-block loupe state and postactivation
configuration/unclaimed issuance.

## Checks, preservation and limits

Independent final-source command:

```sh
./node_modules/.bin/tsc --noEmit --strict --noUncheckedIndexedAccess \
  --exactOptionalPropertyTypes --verbatimModuleSyntax \
  --module NodeNext --moduleResolution NodeNext --target ES2022 --types node \
  scripts/recovery/dtf-migration/*.ts \
  docs/incidents/2026-09-16-dtf-recovery/migration/operator/verification/witness.ts &&
bun test --timeout 15000 \
  ./scripts/recovery/dtf-migration/preparation.test.ts \
  ./scripts/recovery/dtf-migration/execution.test.ts
```

Monitor `mon_W0BCYQ782PVXHW3R`: **exit 0**, strict types pass, **50 pass /
0 fail**, Bun 1.4.2. [script-checks.log](script-checks.log) retains output.
Tests include unknown/overflow integers, source/proof tampering, overlap,
nonconserving partitions, mismatched component quotes, unsupported categories,
no executable manifest on blocked input, exclusive writes, journal locking,
foreign/partial intents and ambiguous CLI authority. The preparation test
server is a wire fixture, not an EVM. Witness TypeScript LSP reports no
errors. JSON LSP remains unavailable because Biome is absent; JSON evidence
is parsed directly without installing dependencies.

All 25 operator files, four artifact envelopes, 21 prerequisite/report/
runbook bindings and all 276 files of the predecessor's final rehearsal
remain unchanged. This run's 276 evidence files are separately fingerprinted.
The 226 compiler-source comparisons and clean production/test scope retain
ordinary code. No ordinary/common Forge suite was rerun: phase07's 9,932
passes remain historical, source-bound evidence, not this verifier's count.
Generated local Foundry broadcast/cache receipts are expected runtime output;
no claim is made that every cache byte stayed unchanged.

All 13 disposition rows remain present. Independent and both NFT models are
bounded. Weighted/earlier liquid, weighted/earlier receipts, weighted SY,
TokenStaking, claim-vault rights, underlying SE shares, fungible LP and earlier
liquidation retain explicit E1/E2 or SB-E1/E2/E3/E4 blocks. No unsupported
payload or no-op success is accepted. Zero rows do not prove zero exposure.

The verdict does not establish approved funding/beneficiaries, E2 ancestry,
earlier liquidation or missing-source closure, public deployment feasibility,
all-category task 9, full integration/invariants or release. Earlier
masked-authorization and source-archive qualifications remain. Recovery here
executes before activation; retained postactivation recovery coverage belongs
to the earlier accepted tests. This run does not independently exercise
reorgs, pending-transaction ambiguity, loss of the send response before its
return, concurrent dead-writer races or crash points inside filesystem sync.
It specifically proves the two required mined-before-completion boundaries.

Audit issues were preserved, not source fixes: an overlarge monitor timeout
was rejected before launch; an offline expression had an unclosed brace; the
first factory-bytecode lookup assumed decoded arguments rather than actual
`additionalContracts.initCode`; and an initial LP assertion incorrectly
included protocol fee mints in net bond-custody LP. Corrected offline checks
and actual source/events resolve those audit assumptions. No product test
was weakened and no production/script change was made.

## Cleanup and final disposition

`R/cleanup.json` records awaited exit of owned Anvil PID **67831**, raw
journal preservation and removal of its checkpoint tree. Holder impersonation,
providers and receipt subscriptions close in the actual CLI lifecycle.
The independent driver awaits its CLI children and closes its file watcher.

Monitor `mon_4T5H35NG4B8KDCN8`: **exit 0**.
[cleanup.log](cleanup.log) independently records checkpoint absence,
successful `rmdir` of the empty owned runtime parent, PID 67831 absence,
no listener on port 18560, no rejected-mode journal, unchanged branch/HEAD,
clean whitespace and the preserved tracked scope. Shared `.omo-runtime`,
warm `out/` and `cache_forge/`, dependencies and predecessor evidence remain.

**Final disposition: AdversarialVerify confirmed for this bounded local
operator/resume contract. No pending owned process. Full task 9 and public
release remain open.**
