# Exact local operator rehearsal

Date: 2026-11-11.

**DoneClaim: the fixed local rehearsal completed against final script bytes,
with actual mined interruptions, fresh-process resume, meaningful remaining
issuance reordering, all admitted recovery stages, and cleanup.**
The final CLI exited 0. There are 264 unique successful receipts: 220
infrastructure, 33 operator-journal and 11 legacy funding/surrender receipts.
This is bounded local evidence, not all-category task 9 completion, approved
allocations, independent verifier acceptance or public execution authority.

**Deployment feasibility remains unresolved outside this script lane:**
the genuine parent deployment consumed 42,985,843 local gas, exceeding the
historically recorded 32,000,000 maximum transaction gas. The owned Anvil
allowed 100,000,000 per block. Its success is not a public-deployment proof.
No production/package/configuration change was made to hide that difference.

## Scope and accepted baseline

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-08-operator`.
Branch: `work/dtf-migration-phase-08-operator`.
HEAD remains `421072a7630a0d3d47a6f36e1062d9eae98c93e2`.

Read both complete phase08 contracts, original plan task 9 and
MIG-P03/P07/P11/P13/P14, the provenance preparation recipe, repository rules
and applicable canonical skills, preparation interface/report, execution
report and actual scripts. Read the predecessor source-verification,
implementation, correction-verification and commit reports in the phase07
worktree. The root notepad records independent commit acceptance,
`OPERATOR_WARM_SEED_READY` and `OPERATOR_WORKTREE_VERIFIED`; direct branch,
HEAD, warm-directory and dependency-link inspection agrees.

This lane changed only `rehearse.ts`, `rehearsal-data.ts`, the new
`rehearsal-proof.ts`, the operator runbook and owned operator evidence.
The inherited `_localInfrastructure` visibility change in
`MigrationCoreLocalQA.s.sol` was already present and was not changed here.
Production, TestBases, configuration and dependencies remain untouched.
No source commit, public transaction, push or merge occurred.

## Commands and observed exits

Both runs executed this exact application invocation from the worktree:

```sh
bun scripts/recovery/dtf-migration/cli.ts rehearse \
  --rpc-alias robinhood_mainnet_alchemy \
  --fork-block 108944663 \
  --port 18560 \
  --checkpoint .omo-runtime/dtf-migration-operator/checkpoints \
  --evidence docs/incidents/2026-09-16-dtf-recovery/migration/operator
```

The existing credential was inherited through `/bin/zsh -lic`; no resolved
private endpoint is retained. [commands.json](commands.json) records the
literal invocation, wrapper, cwd, every child argv/exit and cleanup command.

| Run under `operator/execution/` | Monitor / session | Exit and interpretation |
| --- | --- | --- |
| `rehearsal-1794375924619` | `mon_0QCBTFYDCZ47B1GJ` / `bash_4` | 0; original bounded flow passed, but subsequent coverage assertion found only one unsettled issuance |
| `rehearsal-1794376137494` | `mon_JSABT8WRNCWH7N31` / `bash_6` | 0; final strengthened flow passed |

All remaining relative run locators below refer to
`../execution/rehearsal-1794376137494/`.
The final run records 43 subprocess commands: 35 exits of 0, six deliberate
DOMAIN exits of 1 and two deliberate SIGKILL interruptions.

The actual node argv, with only the private alias value redacted:

```text
/Users/cyotee/.foundry/bin/anvil --host 127.0.0.1 --port 18560 \
  --chain-id 4663 --fork-url <resolved archive alias> \
  --fork-block-number 108944663 --gas-limit 100000000 \
  --disable-min-priority-fee --balance 1000000
```

The actual Solar environment stage:

```sh
/Users/cyotee/.foundry/bin/forge script --use solar \
  scripts/foundry/recovery/dtf-migration/Phase_08_Stage_00_OperatorEnvironment.s.sol:Phase_08_Stage_00_OperatorEnvironment \
  --sig 'prepareEnvironment()' --rpc-url http://127.0.0.1:18560/ \
  --sender 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 \
  --unlocked --broadcast --slow --legacy --gas-price 2000000000 \
  --gas-limit 1000000000 --gas-estimate-multiplier 200
```

`environment-stage.log` records unchanged sources/compilation skipped,
successful script execution and completed onchain execution. Warm
Solar-produced artifacts were used; no new Solidity build is claimed.
The separate deploy CLI mines the genuine manager-registry parent after
the environment stage has computed its identity in simulation.
Subsequent stage transactions use the real CLI's typed ABI operations,
actual `eth_call` simulation, durable signed intent and RPC submission.
The shipped Stage 01 Solidity wrapper was not separately invoked by this run.
Neither EIP-170 nor simulation was bypassed.

## Chain, deployment and deterministic preparation

Historical chain 4663, RPC/L2 block 108944663:
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
Its header records L1/EVM block 26367659. The new funded snapshot is
`0xe3200c8866daf33122b2918e13c41e3284db13f0bf516d185b4060b582f99c11`,
captured at RPC block 108944894 with emitted EVM block 26367890.
Those are separate number spaces and separate historical/funded identities.

| Identity | Actual value |
| --- | --- |
| Anvil instance | `0x951d9bf63fab60ef3e0fd63a6a160e1a2036dda3dc3b88c7a853bd9e08bc6f28` |
| Migration proxy | `0xedf7d9f65b9e57d62a3c4278223170db1308f5f0` |
| Manager registry | `0xaa66038ae217b246f5bf7537104342672e56fed8` |
| Migration package | `0x642fa76f2f7a6b97ec0822d67a785379a92df347` |
| New bond vault | `0x76d3b85be8cc91df1e66cfd3c81681795555e58c` |
| Registry parent deployment transaction | `0xbc2ffc265391562244269342481d3d072e17e8fcec09e9f8d4938f69b10ee5ed` |

`prepared/` and `prepared-reordered/` were generated by distinct real CLI
processes against the actual frozen snapshot. Reversing sources, exposures,
independent/NFT rows, selected recipients and runtime bindings produced
byte-identical manifests and both replacement datasets:

| Output | Bytes | SHA-256 |
| --- | ---: | --- |
| `manifest.json` | 29405 | `adf67c2cbfbaa2641bc9e76c7ba2547d8ed6b40317144eeee36b433500cdd0db` |
| `independent.json` | 1502 | `ee23f0ba3ee6f4e68bc42ab8b4c03be13d79b4bb9e9d9ba09cb87d64c29b1b39` |
| `nfts.json` | 802 | `f458dffc7a422b9d2b06af993365edb4006f0b5e60f30f8611b744d100244974` |

Normalized input hash:
`c5aa52351a2eb988a7f5929c4ad57f1f246c734b8b475cff5615df818ae7d0a0`.
Payload hash:
`c11cbb5ff86fa0a9cc12ec769473b5842249f1b01d2f9f383e4ce79f61a2a8d9`.
Determinism is within this exact source/path/snapshot domain, not a promise
of identical fingerprints between distinct nodes or relocated evidence.
Every native original remains a decimal string. Quote evidence stores the
complete actual snapshot and independent ETH/DTF quote outputs.

## Interruption, replacement, reordering and negatives

The first run's two selected recipients left only one unsettled row after
the fault. Reversing one row is not a meaningful permutation.
`coverage-and-checks.json` preserves that failed coverage assertion.
The correction retains four synthetic recipients, selects three, and
leaves the fourth unclaimed. Actual account-code checks cover public Anvil
mnemonic indices 100-103. This extends the predecessor's code-empty
100-102 fixture; dev accounts 0-2 retain their historical EIP-7702 code.
No account was etched or storage-injected.

Both fault processes die only after a successful canonical receipt is
mined, before journal completion. `donation-before-resume.json` and
`issuance-before-resume.json` record that missing completion and the
actual transaction/receipt before starting resume.

| Interrupted operation | Same recovered transaction | Nonce | Actual result |
| --- | --- | ---: | --- |
| Donation | `0x47afe583e73c188af297cd0b447c0bd2ddffebb106c486ed863d0efe138e5413` | 2118 | One donation; no duplicate capital |
| Independent issuance | `0xab983cd14aebfb4daa0496a3c4d958671ab59bf2077c3ea155e105d19391216b` | 2128 | Same bond 3, principal 461 |

Fresh default resume processes did not change signer nonces. Explicit local
resume then recovered the identical canonical receipts, with the same
signed hash/nonce and actual bond state. The journal's fresh-process
receipt-block checks include principal, holder, creation timestamp and
7,776,000-second cliff. `*-resumed.json` retains those observations.
No RPC, journal, filesystem, receipt or state behavior was mocked.

The original issuance order was recipients `0x0e9971...`, `0x8c3229...`,
`0x9586a4...`. Actual nonce order was `0x0e9971...`, then `0x9586a4...`,
then `0x8c3229...`, producing bonds 3, 4 and 5 at nonces 2128-2130.
`reordered-issuance.json` checks that exact nonidentity permutation and
one bond per selected recipient.

Three received-capital events total exactly 1000e18 WETH and 1000e18
original DTF; the WETH total combines 900e18 transferred WETH with 100e18
wrapped native ETH. Genesis supply is 1000000000000. Configuration leaves
it unchanged. Three 461-unit independent issuances raise it to
1000000001383. The fourth configured recipient
`0xc4c81d5c1851702d27d602aa8ff830a7689f17cc` remains unissued with bond ID 0.

The complete replacement doubles the original ETH input for an already
issued recipient. Its existing bond 5, principal 461, issuance record and
total supply remain unchanged. It is a full setter payload, not a delta
or retroactive top-up.

Every negative is an actual fresh CLI process with exit 1 and `DOMAIN`,
not an unrelated crash. The six `*-rejection.json` records prove unchanged
signer nonces:

| Command log | Rejection |
| --- | --- |
| `006-resume.log` | Reversing funding is forbidden |
| `016-resume.log` | Wrong chain; preparation/execution domains disagree |
| `017-resume.log` | Wrong proxy; preparation/execution domains disagree |
| `018-resume.log` | Wrong package; checkpoint domain changed |
| `019-resume.log` | Wrong snapshot; preparation/execution domains disagree |
| `020-resume.log` | Tampered prepared payload; reconstructed manifest differs |

## Genuine surrender and admitted recovery

Real holders approved and surrendered weighted NFTs 4 and 26 and earlier
NFT 3 through the actual caller path. Their emitted delivered credits are
13872781, 22233172691 and 923391925, funding distinct bonds 6, 7 and 8.
`fixture-receipts.json` and [transactions.json](transactions.json) retain
the actual transaction hashes, holders, consumed source units and events.

Nine genuine harvest transactions exercise all eight admitted enum stages:
combined weighted claim, weighted principal, weighted rewards, original
unstake, accrued-value unstake, weighted conversion, fixed DTF donation,
earlier claim and earlier mature sale.

- Original measured weighted claim inventory: 103958040 native units.
- After advancing the real local chain eight hours and converting that
  entire original quantity, attributed gons remain
  10409878989840039859846493907006238294560.
- At the synchronized divisor 875381719530275893679866214021516565,
  a separate transaction converts 11891 accrued whole units.
- Actual total weighted DETF output is 103969931; conversion returns
  557319211137047451887 native original DTF.
- Exactly 1000000000000000000 DTF is donated to the fixed new reserve,
  producing 119458440568358912 reserve LP units.
- Earlier claim holds 124873542679524901 native earlier DETF rewards.
  Mature sale retires 562524912595035608166 original accounting shares
  and holds 485044501927175493321 external earlier receipt shares.
  Neither is represented as successful earlier liquidation.

Selection uses attributed gons and the genuine source divisor, followed by
bounded simulation. `MigrationRecoveryRevalued` is retained separately
from claims/conversions; no total-balance sweep or duplicated compensation
is inferred. Activation transaction
`0x46e82b433c5eb48fd8b1e0a3d9673d5607a30aaafc3f4dcd17c6f9c2ae903b94`
sets activation and removes all six allocation selectors. Final verify
again observes the fourth recipient unissued.

## Gas, final-source checks and bindings

[gas.json](gas.json) records every receipt's gas used and local effective
gas price, not a live funding quote. Operator-journal gas totals 86684977
across 33 distinct transactions. All 264 transactions total 399471704 gas,
including infrastructure; this aggregate is not a transaction budget.

| Operation | Actual gas used |
| --- | ---: |
| Registered parent deployment | 42985843 |
| Donation / genesis | 326609 / 2371766 |
| Snapshot capture | 3873844 |
| Singleton configuration | 718606-784830 |
| Independent issuance | 709922-832435 |
| Full replacement row | 540688-585830 |
| Weighted claim / principal / rewards | 489619 / 418929 / 398855 |
| Original / accrued unstake | 1592257 / 331270 |
| Weighted conversion | 1393725 |
| Recovered-DTF donation | 19512486 |
| Earlier claim / sale | 324901 / 991434 |
| Activation | 169304 |

The saved phase07 `implementation/chain-gas-limits.log` independently
records `getMaxTxGasLimit()` = 32000000, exit 0, at the same historical pin.
Only the parent deployment exceeds that limit among these local receipts.
The exact reproducer is the fixed invocation above and its `journal-deploy`
receipt. A real-chain deployment redesign or feasibility correction belongs
to the production/package lane; this task neither implements it nor
declares the public deployment executable. Selected recovery bounds remain
eight weighted claims or one other stage, not a universal maximum.

The neighboring suite ran once after all script changes:

```sh
./node_modules/.bin/tsc --noEmit --strict --noUncheckedIndexedAccess \
  --exactOptionalPropertyTypes --verbatimModuleSyntax \
  --module NodeNext --moduleResolution NodeNext --target ES2022 --types node \
  scripts/recovery/dtf-migration/*.ts &&
bun test --timeout 15000 \
  ./scripts/recovery/dtf-migration/preparation.test.ts \
  ./scripts/recovery/dtf-migration/execution.test.ts
```

Monitor `mon_VQH73RJ3H4HFHD7E`, `bash_5`: exit 0, **50 passed, zero failed**,
Bun 1.4.2. No script changed afterward. Fresh TypeScript LSP error checks
for all three changed scripts returned no diagnostics. JSON LSP cannot run
because Biome is absent; JSON is parsed directly without installing or
changing dependencies. Whitespace/scope/branch checks passed.

The modified orchestration, fixture data and proof modules contain 222,
151 and 76 nonblank/noncomment lines. The proof module owns real rehearsal
evidence assertions. No new dependency, receipt mock, type suppression,
sleep or timed polling was introduced. Existing neighboring unit tests
remain unchanged; the actual rehearsal owns the new integration assertions.

[source-evidence-bindings.json](source-evidence-bindings.json) binds final
script/runbook bytes, four artifact envelopes and executable objects,
20 actual runtime bindings, input reports and all final-run evidence.
All 25 script/stage files remained unchanged during the final run.
All 226 compiler/source comparisons match (108 package, 118 recovery);
the four artifact executable objects match the predecessor's accepted
objects. Runtime objects are distinguished from immutable-populated deployed
runtimes. Prior reports retain their original historical source identities.

The original successful-but-insufficient reordering run and all earlier
failed execution runs remain intact. The predecessor's bigint
serialization failure and historical EIP-7702 receiver failures are not
relabeled as passes. This lane's initial ordinary Git status rejected the
prescribed Crane symlink and was retried read-only with
`--ignore-submodules=all`. One evidence-patch argument and one runbook
patch-context error were corrected before writing; neither changed files.

## Cleanup and remaining gates

Both owned nodes exited (PIDs 65441 and 65935). Each run copied its raw
journal bytes into evidence before removing its checkpoint tree.
`cleanup.json` records the final independent shell receipt: checkpoint
absent, empty task-created runtime parent removed with `rmdir`, no listener
on port 18560 and final Anvil PID absent. Holder impersonation cleanup and
provider/subscription shutdown completed in the awaited CLI lifecycle.
Warm `out/` and `cache_forge/`, shared dependency links and historical
evidence remain. No owned runtime is pending.

All 13 category dispositions remain present: independent and both NFT
models are bounded; weighted/earlier liquid, weighted/earlier receipts,
weighted SY, TokenStaking, claim-vault rights, underlying SE shares,
fungible LP and earlier liquidation remain explicitly blocked at E1/E2
or SB-E1/E2/E3/E4. Zero configured rows do not prove zero exposure.
Synthetic originals and reserve/liquidity inputs are not approved
allocations. Earlier missing-source and masked-authorization limitations
remain as in the source reports.

The local rehearsal's in-scope correction is complete. Full original
task 9, all-category migration, operational allocation/funding provenance,
public deployment feasibility and release remain open. The separate
independent verifier must still execute both real interruption/resume
scenarios itself; this report does not replace that gate.
