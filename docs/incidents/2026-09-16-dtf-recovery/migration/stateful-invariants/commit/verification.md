# Independent stopped stateful immutable delivery audit

Date: 2026-11-12. **Disposition: needs-fix for complete historical raw
preservation.** The current fourteen-file source commit, accepted r2 source
identity, current runtime binding, complete original precommit inventories,
whitespace and source/index cleanliness pass. One preservation finding remains:
two first-pass producer artifact identities have no exact raw payload among
the admitted lossless carriers. This is not a production or test-source defect.

The actual completed receipt and manifest exist. No source fix, commit,
artifact reconstruction/restoration/relocation, runtime replay, operator,
configuration, dependency or public operation was performed. This report
does not supply final cumulative immutable acceptance while the finding remains.

## 1. Finding P1: distinguish original path membership from raw-byte coverage

Locations: `implementation/artifact-deployment-bindings.json:2583-2585`
and `:3072-3074`, compared with
`implementation-r2/original-artifacts-06.json` and `-03.json`.

The179 original artifact carriers exactly reproduce the179-entry
post-first-verifier preservation baseline and the first independent runtime
binding. However, five raw artifact identities in the first producer's
177-entry binding differ from those carriers. The179 count is a union of
paths, not proof that every raw version in both earlier bindings is retained.
All admitted original, stopped-candidate and changed-artifact payloads were
decoded and searched by exact raw SHA-256 and length, not by filename.

Three of those five producer identities are available exactly in
`implementation-r2/candidate-artifacts-07.json`:
`TestBase_UniswapV4DetfMigrationSnapshot.json`,
`MigrationSnapshotMathExposure.json`, and `IMigrationPairPreview.json`.
The remaining two are not available in those admitted carriers:

| Original producer artifact | Original raw bytes / SHA-256 | Different post-first-verifier carrier |
| --- | --- | --- |
| `out/TestBase_UniswapV4DetfMigrationSnapshot.sol/MigrationSnapshotConsumer.json` | 466441; `e7e44f1c9dd1feae73302f69cc50182b084c3e156ff63108f9e1206f52b201bf` | `original-artifacts-06.json`: 466419; `787f14521060c4394778f1ad52181f1c2d0d0f6baef4fb1f1105e4e8b69733a7` |
| `out/MigrationNativeHandler.sol/MigrationNativeHandler.json` | 266621; `3628e086cdf17079f06aa157c414326519ba5de6d7a60df05e7deaa59e91d013` | `original-artifacts-03.json`: 266602; `10d277caa09ec26a32e7422db71544c4be13bca085aec8f94d4fcaef9751a3ba` |

For both, the retained first-verifier creation-object text, runtime-object
text and raw-metadata fingerprints match the original producer's recorded
fingerprints. That is useful executable-object evidence, but it is not
the missing raw JSON byte identity. No specific historical changed-field
list is invented without the missing originals.

**Required preservation correction:** account explicitly for these two
unreproduced original raw versions rather than calling the path union a
lossless archive of every first-producer artifact identity. Only authentic
retained bytes could establish the missing raw identities; recompilation,
normalized JSON, equal code objects, aggregate counts or a new baseline
cannot do so. None was fabricated or restored here. The finding concerns
historical raw preservation, not the independently matching current r2
artifacts or the accepted twelve-property runtime result.

## 2. Actual immutable subject and admission

| Identity | Independently observed value |
| --- | --- |
| Worktree | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-24-stateful-invariants` |
| Branch | `work/dtf-migration-phase-24-stateful-invariants` |
| Commit | `8db3f5ee6310e8a700dad2d6a33e21d0955e63ca` |
| Actual sole parent | `15fd629375edeb361f6a39262795bdc66723ca3a` |
| Tree | `464742d40290a5a11686afe75f5ee061f56a4677` |
| Subject | `Add verified bounded Migration stateful invariant tests` |
| Complete delta | 14 additions,2496 insertions,0 deletions |
| Root-admitted r2 report | 30734 bytes; `fd9aaa6531a1a3fddcd5fb7084c533a80588eddeee3ef72c269125d0f0654e60` |
| Actual completed delivery manifest | 15607 bytes; `c353db56d49b22dbde4cb7f71e3791d82d23dcb018624336a1f7b05ee2190807` |
| Producer r2 report | `bbb1dd84921fb8bf98f7b158b0e58cb560017f84cf303203a838ea7d4f7c18d4` |
| Producer r2 candidate manifest | `2767c82ada1049bfaa988407146f20a57a0441bf5f740ce4c2793949ed58862d` |

Read the complete root commit/original/closure briefs and all twelve
acceptance rows, actual four phase24 reports, completed receipt, original
inventory recipe and capture script, and prior phase23 producer/r2/immutable
reports. Complete manifests, seals, source/runtime bindings, raw carriers,
command records, cleanup and preservation inventories were parsed and
compared. All seventeen original authorities and eight additional source
admission inputs match raw bytes, lengths and full modes.

Every root acceptance row's exact table-line hash reproduces against the
actual r2 report. Producer PASS flags were not an acceptance oracle.

Raw commit content is1203 bytes, SHA-256
`7d8f0206d5ef6df58117d8e62ca652ab39762f671e6349c9217ebd1635d1e402`.
Independent Git-object framing reproduces the commit ID. There is one
parent header and one commit after the required parent. Exactly one required
coauthor trailer occurs:

```text
Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>
```

Independent `git -c gpg.program=/usr/local/bin/gpg verify-commit HEAD`
exits0 with a good RSA signature from
`55EB42889513051267BC55A395206404A78FB7F3`. Unknown ownertrust remains
explicit; signature validity is not independent human-identity proof.
The upstream lookup exits128 because none is configured. No fetch occurred.

## 3. Independently derived source set and exclusions

The accepted set comes from independent
`verification-r2/source-locators.json` `candidate`, not the delivery list.
Its fourteen unique paths equal the producer's lossless candidate, complete
new-file patch, immutable delta and completed manifest.

Under `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/invariant/`:

- `MigrationLegacyClaimHandler.sol`
- `MigrationLegacyHandler.sol`
- `MigrationLegacyRecoveryHandler.sol`
- `MigrationNativeHandler.sol`
- `MigrationNativeLedger.sol`
- `MigrationSourceUnitsHandler.sol`
- `MigrationSourceUnitsLedger.sol`
- `MigrationSourceUnitsRecoveryHandler.sol`
- `MigrationStatefulBindings.sol`
- `TestBase_MigrationSourceUnits.sol`
- `TestBase_MigrationStateful.sol`

The remaining paths are the spec invariant
`test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/invariant/MigrationNativeInvariant.t.sol`
and fork invariants `MigrationLegacyInvariant.t.sol` and
`MigrationSourceUnitsInvariant.t.sol` under the corresponding fork directory.

Every current raw source, accepted independent identity, producer payload,
entire patch body and committed blob has the same SHA-256 and length.
Every current full mode is33188, permission0644; tree/index mode100644,
stage0 and independently recomputed Git blob identity agree. Every parent
entry is absent. Every declared delivery-manifest identity column also agrees.
All fourteen candidate sources are present in the current compiler metadata.

Eight entries have first-pass predecessors; seven evolved, and
`MigrationStatefulBindings.sol` is unchanged. Six entries are new relative
to the first pass. All fourteen are nevertheless additions relative to the
required committed parent.

Exact complete delta equality excludes production behavior, existing tests
and TestBases, operators, configuration, dependencies, evidence, governance
inputs and held09 candidate content. No filter is set on these paths.

The complete immutable whitespace check includes every added file:

```text
GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 git diff --ignore-submodules=all --check 15fd629375edeb361f6a39262795bdc66723ca3a HEAD
```

Exit0 with empty stdout/stderr. Full staged and unstaged tracked comparisons
also exit0 with empty output. The original precommit staged-whitespace
evidence is intact. Raw compiler-log spaces were neither normalized nor
included in source-whitespace gating. Status contains only excluded
untracked incident evidence.

## 4. Every original precommit preservation row

`audit-inventories.json` retains every original line number, complete
expected/current fields and every changed field. The original lstat,
no-symlink-following, field order, permission, raw hashing and JSONL newline
recipes were reproduced. No missing baseline was replaced by a clean index
or aggregate.

| Original baseline | Rows | Independent result |
| --- | ---: | --- |
| `docs-incidents.jsonl` | 138 | All original file/link fields unchanged |
| `docs-incidents-perms.jsonl` | 147 | All files, links and permissions unchanged; one excluded-directory size difference |
| `out.jsonl` | 7369 | All fields unchanged; no missing or new entries |
| `cache_forge.jsonl` | 550 | All fields unchanged; no missing or new entries |
| `preservation-rows.jsonl` | 148 |146 unchanged; only own raw index and owned branch ref move for the source commit |
| `refs.jsonl` | 22 | Only owned branch raw bytes change; membership unchanged |
| `show-ref.txt` | 64 | Only required-parent to actual-commit movement on owned branch |
| `indexes.json` | 26 | All25 foreign raw indexes unchanged; own index matches the committed stage-zero entries |

Original and reproduced current-original-subset JSONL hashes agree:

```text
docs  153beb0e0d596529504170a3a2aa9fb30c5d9c3299472b485427c5474c9d8951
out   9b38e534f50f9ad6b61beeb0b70265e85760ea9c78872ce567be8088e293e152
cache d38e68c20fc40f6790a322b0b3405babd8442dd4aa417eb9b27cbd0661f4423d
```

Permission baseline hash is
`77eedebd746123f66121d96fefd6517d3ec820a72fdeb63634fd3d94ab7796ef`.
Its only changed original row is line19, enclosing
`migration/stateful-invariants`: directory size192->224 from creation of
excluded `commit/`; kind, permission0755 and null hash are unchanged.
The honestly different current-original-subset hash is
`6c1d4dce8fbc1df96bc74e1b2de0e0701363fd3c0bef0c918cd327a92f2fdf76`.

Before audit additions there were16 new incident file rows and18 permission
rows, all excluded under `commit/`. This audit adds only its report and
three new support files directly in that existing excluded directory.
Git-mode baselines normalize non-executable permissions; they are not proof
of unrecorded historical read-only permission bits for all out/cache files.
The separate incident permission inventory and exact selected runtime/source
full modes remain distinct.

Own index moves only for the original source commit:

```text
before 0aac78e6504612422343709283b720e3628f7e43a04df63575f91130d58000b0
       2073604 bytes, mode33188
after  82128293dce6005c647d33617c5c14ebfecfea73588ada9f915bff82cd7166a7
       2076067 bytes, mode33188
```

Its raw bytes do not move during this audit. Own HEAD retains its sealed
raw identity. All foreign raw hashes, lengths, permissions and modes
reproduce, including only the prescribed phase09 Git metadata access.
No held09 candidate file was read.

Both dependency symlinks retain targets, raw target hashes, lengths,
permissions, modes41453 and inodes: `lib/crane`19989693 and
`node_modules`19989694, pointing to the primary checkout's corresponding
directories. No dependency cleanup or host portability is inferred.

All six original inventory aggregate anchors were checked additionally.
All52 original pre-r2 evidence/authority rows and179 post-first-verifier
artifact baseline rows reproduce. P1 separately identifies the two older
producer raw versions not represented by that baseline.

## 5. Complete evidence membership and current artifact binding

Exact original memberships remain22 implementation,13 verification,
72 implementation-r2 and17 verification-r2 files, including their own
seals. Every member's raw hash, length and mode agrees; there are no missing,
extra or changed members in those trees.

The four seal digests remain:

```text
implementation    97d7df1bb3b21d7c17f272e48c73fe0e44e5a4377d7ce9318aa125e0a450c303
verification      c70690725cbacb032bc90251fe0389b0343bda6d7fc4607d64656048d00ee982
implementation-r2 4a03fe2325aed85208ce9ec418d194e1cd44fa220fb63180176cdcb5466a86e1
verification-r2   c830c13d4585bcf99e838fb04da35f4d208b5f7638ebf7e1b42b77e778eebad7
```

All179 original,189 stopped-candidate,6 changed-artifact and23
report/authority carrier payloads independently decode to their declared
raw lengths/hashes; modes remain recorded explicitly. Fresh r2 raw binary
index/HEAD/ref payloads also reproduce. This does not retrospectively
upgrade the first verifier's qualified decoded-string index observation.

The current artifact set was rederived from complete actual expanded build
roots, concrete candidate compilation targets and the original binding
paths, yielding189. Both abstract TestBases lack standalone output
directories; their source identities are required in concrete metadata.
All189 current raw artifact hashes, lengths and full modes match the
independent r2 binding. All979 compiler-source raw SHA-256/length/mode and
metadata Keccak256 comparisons match, with no conflicting declarations.

Exactly six current raw artifacts differ from stopped-candidate carriers:

| Artifact | Recomputed exact changed fields |
| --- | --- |
| `MigrationNativeHandler.sol/MigrationNativeHandler.json` | `bytecode.sourceMap`, `deployedBytecode.sourceMap`, `id` |
| `MigrationNativeLedger.sol/MigrationNativeLedger.json` | `id` |
| `TestBase_UniswapV4DetfMigrationSnapshot.sol/IMigrationPairPreview.json` | `id` |
| Same directory, `MigrationSnapshotConsumer.json` | both source maps, `id`, immutable-reference keys12981-12984 and9890-9893 |
| Same directory, `MigrationSnapshotMathExposure.json` | `deployedBytecode.sourceMap`, `id` |
| Same directory, `TestBase_UniswapV4DetfMigrationSnapshot.json` | `id` |

These paths are relative to `out/`. The handler/ledger original r2 bytes
are in `candidate-artifacts-04.json`; snapshot bytes are in
`candidate-artifacts-07.json`. All six complete current bytes are in
`verification-r2/changed-artifact-bytes.json`, raw SHA-256
`0e7b97324e449efb09aeed18eacfec2c14c8efada53562f6d3928a99d0ba8f9f`,
2847097 bytes, mode33188. Every exact raw identity and full changed-field
path is retained in `audit-evidence.json`. For all six, creation object,
runtime object and compiler metadata are independently equal. The other183
match stopped-candidate raw bytes exactly. None was restored or relocated.

## 6. Binding already-executed tests and actual deployments

No build, test, CLI/resume, runtime audit runner or RPC was replayed.
Complete original command recipes, expansions, seeds, raw log identities
and exits remain bound. Independent literal PASS counts and exact original
selector-row locators corroborate:

| Existing independent gate | Bound result |
| --- | --- |
| Migration specifications, seed0x24d1 |171 passed,0 failed/skipped;30 suites; exit0 |
| Pinned Migration forks, seed0x24d2 |147 passed,0 failed/skipped;26 suites; exit0 |
| Focused ordinary regressions, seed0x24d3 |58 passed,0 failed/skipped;8 suites; exit0 |
| Four invariants | Each32runs/depth16,512 selected calls,0 unexpected reverts/discards;2048 total |

The four selector tables contain13,13,17,15 actions. Selected calls are
not aggregate positive-operation counts. Mandatory success/negative
preludes, actual later-own-cliff payouts, genuine later ordinary paid
native reward/index funding and actual later ER source-rate growth remain
the nonvacuity witnesses. Retained sequence counters are not all-run totals.

All13 actual subjects and1127 runtime captures were decoded again from
the complete retained raw logs. All66 distinct address/code pairs match
the entire current runtime template outside only compiler-declared
link/immutable spans; every repeated value and every unmasked byte,
including metadata, agrees. All four submitted native package argument
tuples decode with the actual package ABI and match their following
captured hook. No pre-normalization helper hook was substituted.

This is actual in-process Foundry deployment identity, not signed mined
constructor receipts, archive equivalence or independent execution of
every linked helper. The earlier phase23 signed-source/transaction evidence
is distinct and is not relabeled as these Foundry captures.

## 7. Source, recovery and historical qualifications

All twelve root-accepted property rows remain bound to this exact candidate.
Supported units stay distinct: W-L/native9, E-L/native18,
W-R/original gons with measured native transfer, E-R/exact internal shares,
C/direct native19, W-SD/native28 and separate W-SW/E-P/W-P/native18 held
sources; ordinary native9 weighted SY and both whole NFTs are separate.
Positive WS/ER nonrepresentable Q/C residues remain eligible and unpaid.
LP acquisition retains its external EOA-owner release/personal-donation
fixture qualification, not donor-key control or public consent.

**Root ED wording qualification is retained:** source index1 is ED/E-L.
`MigrationSourceUnitsRecoveryHandler.sol:137-166` selects0/2/4/5 only:
WL,WR,C,WSD. It never selects ED for conversion.
`:95-118` may book ED rewards from earlier NFT sale into row1 and separate
external ER shares. ED remains held. The compressed E-L recovery phrase
does not authorize or prove ED liquidation.

`MigrationSourceUnitsLedger.sol:157-165` uses read-only `vm.load` of the
admitted ER layout, not source storage injection, a fictitious getter or
new production ABI. Internal shares, displayed/external shares and
NFT-sale external receipt inventory remain separate.

Ordinary-SY receiver callbacks are not claimed-origin direct-EOA
preparation proof. The inherited complete-original, known-zero-prior-
compensation, direct-signed-EOA isolated-source-block admission stays
separate; late SY surrender failure cannot restore earlier consumed raw
source weight. Synthetic original eligibility is not an operational award.

The original zero-action discovery failure and donation-model correction,
and every retained later harness/tooling failure, remain unchanged.
Spendable protocol residual is not the protected1DTF donation. Historical
failure logs are not relabeled passes.

Raw TokenStaking approved pull, E-S, disabled conversions, unsupported/
partial/prior-delivered/unknown histories, standalone historical native/WETH,
operational allocation approval, source/archive equivalence, host portability
and full-repository hermetic closure remain unaccepted. All earlier source,
optional-facet and mature-close qualifications remain. Registration
**45116678 exceeds32000000**; no remeasurement, repair or target-gas
acceptance follows. Foundry warnings remain visible; JSON Biome is unavailable,
not passed. The accepted r2 prebuild Solidity diagnostics cover all14 files.

## 8. Stopped cleanup and owned support

Read-only source/staged comparisons and complete immutable whitespace
passed. Port18574 has no listener (`lsof` exit1, empty output);
no Forge/Solar/Anvil/artifact-helper process is present. Own index.lock,
merge/cherry-pick/rebase markers and state directories are absent.
Own raw index remains the incoming committed index. No owned background
process, monitor, subscription, node or pending operation was started.

Only this report and these new audit supports are owned writes:

- `audit-inventories.json`:6620525 bytes, SHA-256
  `7a89b03847fe4741829af01660fe2bf44d3d8c5b5936440ecde787e7facae55f`.
  Complete original per-entry inventory comparisons and additions.
- `audit-evidence.json`:3297465 bytes, SHA-256
  `46dfd8a96fa0acc55bea66aecde9a47d8df2dac703174884e685a8fcb34f1eb2`.
  Exact source/Git/seal/input/carrier/runtime/result comparisons, finding
  P1, original raw identities and cleanup evidence.
- `audit-method.md`:10543 bytes, SHA-256
  `2d49181913f7fb80ce5299f4a845e8289b9de6eb64589851e6192caa0bba23c5`.
  Exact source derivation, row serialization and offline binding recipes.

This report claims no self-digest. **Current stopped source/r2 runtime
identity passes; complete historical raw preservation remains needs-fix
only as P1 records. No source fix or new acceptance beyond this audit is
authorized, and no owned operation remains pending.**
