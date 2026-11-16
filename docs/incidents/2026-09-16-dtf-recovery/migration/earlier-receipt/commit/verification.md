# Independent earlier ER immutable local delivery audit

Date: 2026-11-12. **Disposition: confirmed for bounded immutable local ER custody and frozen-credit delivery only.**

The actual completed receipt and manifest exist and agree with the actual source commit. No blocking delivery discrepancy was found. This confirms only the admitted measurement domain and local immutable custody/credit increment. ER liquidation and donation remain blocked. This is not full-plan/full-hermetic, operational allocation, portable execution, target feasibility or public-operation acceptance.

## Actual delivery and admitted proof

| Identity | Independently observed value |
| --- | --- |
| Worktree | /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-18-earlier-receipt |
| Existing branch | work/dtf-migration-phase-18-earlier-receipt |
| Actual commit | 1df9076c73b94a4f63172395763fa8cdd48fe060 |
| Required sole parent | acdbe319f3a20c3af6bea594c62461b6c7988717 |
| Tree / matching index tree | 5a7725f9569d35556669f9f485b06c629644234d |
| Subject | Add verified bounded earlier receipt custody and credit |
| Complete immutable delta | 34 paths: 30 modifications, 4 additions; 1376 insertions, 40 deletions |
| Actual receipt SHA-256 | 80808345335f19457c0dab16c41d3436b5c815a856577667d105b6fbd34f459f |
| Actual manifest SHA-256 | ae2567dee5302a918e4f95de8977705a9f1ec9f21fd1b519562c8c2eae71e58d |
| Admitted independent runtime report SHA-256 | 79d34b17e0b06b273c0350d450561650e09d312482efefd2effa01dbc7efe4bd |
| Producer implementation seal SHA-256 | 5ef85c26ab00282904ad27b47b151427d9018287bd91a9d10ae45e3d0c48c3b6 |
| Independent runtime seal SHA-256 | 6443692ae69afac6c8ea796a6934cd83cbfefc3df97ea11b76d61cb55945972f |

Read the complete commit/original/implementation briefs, actual source contract and producer/source-admission reports, stopped implementation report, admitted runtime report, actual complete receipt/manifest, binding algorithm, seals and cleanup. The preceding phase17 actual final runtime report and immutable receipt/audit were read as base context. Parsed and rehashed the full original baseline inventories and actual final bindings; no pending status or producer summary flag was accepted instead of evidence.

The admitted report raw hash independently matches the root-supplied identity. Raw commit content is 1203 bytes, SHA-256 20529f740fe555fc8bbd704f3112f5ddf243c2ce2eda2b18fccd5a025a17c3d7; independently recomputing its Git object framing reproduces the commit ID above. The raw commit has exactly the required parent, and rev-list required-parent..HEAD counts one commit.

There is exactly one Co-authored-by line in the final trailer paragraph: Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>. Independent verify-commit exits0 with a good RSA signature using key55EB42889513051267BC55A395206404A78FB7F3. Unknown local ownertrust/certification remains explicit; cryptographic validity is not independently certified human identity. No commit, amend, history rewrite, merge, push or PR was performed by this audit.

## Independent accepted-path, blob, mode and exclusion checks

Derived the 34 accepted source roles from the independently accepted audit-fresh-final.json runtimeBindings.preserved records under this worktree's contracts/, test/, scripts/ and exact operator-runbook.md path, not from the commit manifest or a directory listing. Cross-checked the complete set against the producer implementation seal.source, implementation/audit.json source, audit-producer-final.json preserved records, and precommit/source-identity-before.json. The independently derived set equals the entire actual parent-to-HEAD raw delta without omission, duplicate or extra path.

For every path, compared current raw SHA-256/length/permission, actual committed blob bytes, accepted runtime binding SHA-256/length/mode, both independent audits, producer final binding, producer audit, pre-stage identity and every manifest identity field. All 34 match. All current/accepted permissions are0644/decimal420, committed modes100644. All 30 parent modes remain100644; all four additions have no parent blob. Complete per-path hashes, lengths, parent/current blob IDs and modes are retained in audit-evidence.json:sourceComparisons.

The entire actual immutable diff was inspected, including all four additions. Production changes are the 11 Migration-specific interfaces/storage/allocation/recovery facets/targets and legacy interface/helper. Remaining changes are adjacent Migration specs/forks, the existing operator/stage home and runbook. No ordinary/common/Crane production, dependency/configuration, evidence, held09 candidate or other excluded path is committed. Signing transport changes retain only fixed loopback18567/18568; the public development mnemonic is fixture material, not a resolved archive credential.

The four actual additions are:

- scripts/recovery/dtf-migration/earlier-receipt.test.ts
- scripts/recovery/dtf-migration/rehearsal-earlier-receipt.ts
- test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationEarlierReceipt.t.sol
- test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationEarlierReceiptConfiguration.t.sol

The actual full immutable whitespace gate was independently executed:

```text
GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 git -C /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-18-earlier-receipt diff --ignore-submodules=all --check acdbe319f3a20c3af6bea594c62461b6c7988717 HEAD
```

Exit0 with empty stdout/stderr. This includes all formerly untracked additions and is not replaced by an empty-index check or hash-based waiver. The retained pre-stage/staged gates were also read; no source whitespace correction was made. Final staged and unstaged tracked comparisons are clean. Status contains only the pre-existing untracked earlier-receipt evidence tree, now including this audit's three excluded files. Every Git call used GIT_MASTER=1 and every status/diff ignored submodules; read-only queries also set GIT_OPTIONAL_LOCKS=0.

## Independently reproduced original preservation comparisons

Reproduced original precommit/recipe.txt, SHA-256 2e746e82453156799fd6fb6b10694a43b4ce97433f090c001a4730031a146dc2, using raw-byte SHA-256, lstat, no descent into symlink directories, exact per-field records, sorted POSIX paths and compact UTF-8 JSONL with a newline per record. Compared every original entry to current data; aggregate hashes are additional evidence, not replacements for unavailable original rows. All required original baselines are available. All 13 original aggregate bindings match.

| Original baseline | Entries | Independent result |
| --- | ---: | --- |
| docs-incidents.jsonl | 2126 | No missing/changed original file/link rows; retained-current subset SHA-256 b0f13a36c69056b1287bb25df38b729ec39ef97ed3a15b0f49010cff69001082 |
| docs-incidents-perms.jsonl | 2283 | No missing rows or changed file/link bytes/permissions; only the documented enclosing directory-size change |
| out.jsonl | 7340 | No missing, changed or new rows; SHA-256 da29a6cc29d8bd75aac8b9cb56a033b7e1bbea9c6fe9660d8f73c847cade97b0 |
| cache_forge.jsonl | 603 | No missing, changed or new rows; SHA-256 59e469d1708c72b13852d0eb5e95664d3f4ba8aa022c7dd1163213c81ca36212 |

Permission baseline SHA-256 is55bc0a5445e77a9e670509e9dfa445653ad1bb8529da2b4238ea0b3bef0a6b60. Its sole changed original row is directory migration/earlier-receipt, size192 ->224 from creation of excluded commit/; kind dir, permission0755 and null hash are unchanged. Retained-current original permission subset SHA-256 is065df9d333e61d511b302abae51457374ff8eccd6bb9981440c1abaff53afdae, honestly different rather than falsely labeled equal. Git's100644 field alone is not proof of read-only permissions; the distinct original permission inventory supplies that proof.

Before audit writes there were18 new file/link rows and20 new permission rows, all at excluded commit/ or below it: the15 retained precommit files, receipt, manifest, postcommit summary and two directories. This report, audit-evidence.json and audit-method.md add only three explicitly excluded evidence files. They are not retroactively made original preservation members. No original report, failure, snapshot, log, journal, witness or seal was rewritten or chmodded.

All19 foreign worktree indexes retain exact original raw SHA-256, size, normalized mode and actual permission. The phase18 index alone changed as expected from37ced8a155fa31fbd9dbd3c69c1a2b882b7341a4b6d891b0a2fce521096ad857 to a2c5742f0e9c18b5ce04298b218b0fb82fb77ec3f00ff5ee6d3dc53be1422057; it matches the committed tree and clean tracked/index source. Held09 preservation was limited to its required foreign-index hash and ref identity, without reading its candidate source.

The complete original ref map, baseline SHA-2567abe2969d8a94df50f87277963bbe6c5f7f7068ff2f669a59793be19030e5859, has exactly one change: this phase18 branch from the required parent to the audited commit. No other ref was missing, added or moved. All28 original external host-dependency entries match every original byte-length/hash/kind/mode/permission/target field. lib/crane and node_modules retain their target, inode, length, mode and raw target hash (inodes19330661/19330663). No cache/artifact restoration, cleanup or relocation occurred.

Exact evidence membership is unchanged: source171 entries plus its self-excluded seal; source-verification63 plus seal; implementation1386 plus its declared seal.json/seal.log exclusions; verification487 plus seal. Rehashed all complete seal records and both final audit binding collections: producer implementation1678 records, verifier seal489 records, and1770 records per final audit including checks/preserved/artifacts/stages/prepared inputs/producer seal. Their raw identities and available modes match.

The original source-admission seal also contains six historical source inputs deliberately changed by this accepted implementation (rehearsal-data.ts, provenance.ts, schema.ts, MigrationLegacyRecoveryLib.sol, MigrationRecoveryRepo and Recovery interface). Each old hash/length independently equals the exact required-parent blob; current bytes equal accepted implementation. These are historical inputs, not allegedly unchanged current sources. Their complete old/current pairs and resolution remain in audit-evidence.json. Original source/admission evidence itself is unchanged.

## Binding to actual executed runtime proof, without replay

The immutable/current/accepted source equality binds this delivery to the actual independently executed142 specs,101 pinned forks,72 operator tests in one invocation, both stage builds, strict operator/probe types and actual pinned18568 CLI. Sealed raw execution logs and ordered exit-success gates corroborate those totals. This audit ran no build, unchanged suite, CLI or producer/verifier runner, and made no RPC transaction or source/governance call.

Both final audits' static bindings were independently rechecked:75 runtime capture entries,57 artifact/runtime comparisons across29 distinct artifacts, linked libraries and198-byte proxies;301 runtime-artifact compiler source hashes; two separately checked stage artifacts with545/68 source hashes;23 prepared inputs. Repeated captures are not75 distinct contracts. Actual runtime lengths/hashes and compiled bytes agree outside only re-derived compiler-declared immutable/link spans and checked library self-address guards. Actual linked values/library identities are checked, not arbitrarily masked. Current source metadata agrees, Solar0.8.38/optimizer runs1/no viaIR remains retained, and every captured deployment respects EIP170.

For each final runtime, independently decoded72 retained raw signed payloads and four explicitly offline-reconstructed payloads, checking hashes, recovered signers, chain4663, nonce and recorded transaction/receipt fields. All three genuine mined-before-checkpoint/fresh-process resumes retain actual SIGKILL/code-null command receipts, pre-resume absent completions and the same signed hash/nonce. All15 raw canonical receipt fields, including every nested log, compare recursively before/after; raw gas/gasPrice/r/s/v also match signed bytes. Fresh resumed transaction hashes are:

- Donation nonce2128: 0xc5615d8e3fe8a2026b05e83d92ce5dffdf1e7e296c4a52c1f45f26accfe0e370.
- Independent issuance nonce2146: 0x21a88fb1c04f2b52f2e00ab6a7eb417e7b1b9622ee4faabff52cd7134d35a90a.
- Paid owner-first bond nonce2166: 0x1ee45128e1363fd1c7bc4505e619105779ede71c0922c03469b3762b90f42466.

Exact observed ER q and frozen-credit recurrence were independently recomputed from retained observations. At rate2197 input4 moves1820664542558033682294037 internal shares for1109 credit; at rate4046 input1 moves247157686604053386060306 for150. Final Q4549593534165922118666738966/C2773349 remains recorded. Delivered1259 + remaining2773349 = original2774608. E485044501927175493321 remains external NFT-sale shares, B2067822229162087068354343 internal standalone shares; actual custody equals E*1e9+B. Original components are disclosed synthetic code-proof records, not operational awards.

### Exact retained ABI and signature qualifications

Independent compilation changed only the terminal top-level Solar source-unit ID in four raw ABI JSON files: Allocation/Migration2442 ->534, MigrationDFPkg2444 ->536, Recovery2457 ->543. This audit independently reproduced all48 repeated producer hash-recovery records across those four paths by ID substitution in memory, including exact recoveredRaw/length/SHA-256. These recovered strings are **not original captured files**. Original/current raw ABI hashes do **not** match. No file was restored or seal edited. Fresh prepared inputs match current raw artifacts directly, with zero fresh reconstruction exceptions. The preservation baseline is the current post-verification out/cache_forge, not the old producer outputs.

Four inherited claim-vault/W-SD acquisition signatures (two nonces each) were **reconstructed offline from disclosed development keys and exact recorded transaction parameters**, with hashes matching actual mined receipts. Their bytes are **not originally captured raw signed bytes**. The final audits retain the qualification 'offline deterministic reconstruction; actual mined hash equality'; this audit verifies their decoded identity without relabeling their provenance or sending transactions.

## Retained limits, audit evidence and cleanup

Final strict typechecks passed in the admitted execution. TypeScript LSP freshness was unreliable; Bash LSP was unavailable, not clean. This audit's JSON patch additionally reports absent Biome JSON LSP. The evidence JSON was constructed/parsed directly; no server/dependency/configuration installation was attempted. Existing Foundry/nightly/compiler/lint warnings and earlier failed auditor attempts remain retained, unsuppressed. Audit inspection/schema mistakes are recorded in supporting evidence, not concealed as source failures.

Fresh actual signed parent deployment transaction0x79b37c8f8d6274380acb04c0d2f6af7b000ab1de236ba1e340a0a23a30238ab4 uses **44,653,392 gas**, above the retained **32,000,000** limit. Prior44,353,454 is historical, not a current gas pass. Allocation runtime is **24510 bytes**, only **66 bytes** below EIP170; enforcement stayed enabled. The permissive local100-million node proves no target-chain feasibility.

Archived ER source qualification remains **match, not exact_match** or full transitive historical recompilation. Historical parent ED redeemClaim transaction0xe4359e06c585390d0c6e33cfb105c2384f58c4f9b44d75e1e0c566a2a97109e9 remains FAIL; direct ER redeem transaction0x22fb95c8bfd0b3f7c58faa20f4672371f4740ffb8a3276cccb3ff2a731880a0d remains UNPROVEN, with actual status0/VaultDisabled at ES0xb7D4Bb379d361aD442Cddee53EA71A33957826A7 and unchanged state. They were not replayed or promoted to successful conversion. No ER conversion/debit/donation stage is admitted.

Operational original-wallet/origin/unit/component datasets, opaque-origin reconciliation, other source categories, native/WETH/raw-claim limits, host/archive portability and full hermetic/full-plan/target acceptance remain open. Positive remaining Q/C is preserved state, not an owned pending operation or promise of future representability. Earlier NFT claim-and-hold/sale-and-hold remain distinct. No category or historic source qualification was removed.

The phase15 archive remains at /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-15-dtf-custody-se/docs/incidents/2026-09-16-dtf-recovery/migration/dtf-custody-se/implementation/source-archive.json,1047506 bytes,0644,SHA-256600c072adccc5e624333fd3dfd511787a3d89868193b320efdb8cbfc912483e7. Phase17 contract/admission remain at their exact retained worktree paths in audit-evidence.json:hostDependencies (contract18779 bytes/hash8505a56f2b9dec9a34d9fb322d1a9cd78aa7e151678008427143cce9ff782bd6; admission15387 bytes/hashb39dd7edeb5f0250ffd257744df2304eb18485c195f121ec64f058eebb077c56). None was relocated, rewritten or re-admitted.

Supporting audit-evidence.json is110252 raw bytes, SHA-25669b1d8acc8151355cc8bde615040523fd450995fa336d3cbf0460d7fb5d9b381. It retains actual Git commands/exits, every source comparison, original-inventory comparisons/exclusions, every foreign index and host-dependency comparison, ref changes, seal/membership results, runtime/signature/resume/economic bindings and cleanup. audit-method.md retains the exact inventory helpers and full reproduction recipe. These two new evidence files and this report are the only audit-owned files; all are excluded from source delivery.

Independent lsof port18568 and ps on historical owned PIDs each exit1 with empty output. The fixed runtime parent/checkpoint and Git operation/index locks are absent. No runtime, monitor or background service was started or adopted by this audit. All audit comparisons completed. **No owned operation remains pending.**
