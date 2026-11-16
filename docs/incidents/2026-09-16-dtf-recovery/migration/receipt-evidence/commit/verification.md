# Phase28 immutable receipt-evidence delivery audit

Date: 2026-11-13. **Verdict: confirmed for the bounded ten-path local source delivery.**

No needs-fix defect was established in the immutable delivery, retained actual proof, or original preservation set. This is an independent audit of completed delivery, not a replay of its execution. It grants no operational, eligibility, full Task 9, or full-plan approval.

## 1. Exact subject and evidence binding

Worktree: /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-28-receipt-evidence.

Branch: work/dtf-migration-phase-28-receipt-evidence.

- Commit: `07d54b9a3d20d98aee24e75235bbf16b650a8028`.
- Sole parent: `789fced820ed494d9651c598fb8f75c646d727a7`. The actual rev-list parent record contains exactly these two hashes; no second parent exists.
- Tree: `edac46fc0506fc522a9409adc2b4917214544398`.
- Subject: Add verified bounded finite receipt evidence collector.
- Actual delta: exactly ten paths, two modifications and eight additions, 860 insertions and zero deletions. The path set equals the supplied commit-source index. Evidence and inputs are absent from the commit tree.
- Message contains exactly one trailer: Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>.
- Raw commit object: 1202 bytes, SHA-256 `2647508e86a5a742aece5b7aff0e5dc23731122ad6cae1149e9d52a254acb686`. The signature header is not a coauthor trailer. This audit did not sign, verify via an external key service, or change configuration. The producer's local signature-verification claim remains a recorded producer check, not an independently rerun check here.
- Actual receipt: commit/receipt.md, 16921 bytes, SHA-256 `d20df7303c5fb5f098385b848381d8f1cf9e054b85ad1d2e3c4709526a5cd548`.
- Actual source manifest: commit/source-manifest.json, 26806 bytes, SHA-256 `2a40960a0832506b208483bebae00e9433ab874461d94c10b362812550a91f2f`.
- Accepted independent report: verification/report.md, 20647 bytes, SHA-256 `77bb12de3b210f0091d4f7409fdb52eff81b1fec5d8cc11dce0db38897bfa5aa`, matching both the supplied index and verifier seal.

The complete supplied commit brief/index, original phase28 brief, actual receipt/source manifest, implementation and independent reports, manifests, seals, command records, raw streams, attempts, cleanup, independent proof and original precommit capture recipe were read. Large JSON/JSONL records were parsed from complete raw file buffers; tool-rendered/truncated text was never treated as JSON or byte evidence. Every manifest member was rehashed, not accepted from a summary count. The eight new source bodies and complete CLI/runbook tracked diff were inspected.

## 2. Immutable source, index, tested bytes and modes

All ten supplied raw length/SHA-256 identities match the current filesystem, committed blobs, current index blobs, producer tested manifest, independent source captures, and commit source manifest. All 70 frozen operator/runbook identities likewise match current, committed and index bytes; 60 are unchanged paths outside this commit. All 70 current filesystem modes equal their original precommit frozen-mode rows.

In this table, operator/ means scripts/recovery/dtf-migration/; migration/ means docs/incidents/2026-09-16-dtf-recovery/migration/.

| Path | Bytes | SHA-256 |
| --- | ---: | --- |
| `migration/operator-runbook.md` | 63759 | `f2c55a085028e6fb8e8c7eb54d78a6b041528ca012cdc2fe4ce80124423b3c1c` |
| `operator/cli.ts` | 13040 | `655227085f6dad1fceab01cd152366c5a8bb53fa6e629be0449a9f7b532db6c4` |
| `operator/receipt-input.ts` | 3498 | `24bd61407af078275decdfa4fd7d4cf948aae486866aa87a2548360e09fe4838` |
| `operator/receipt-evidence.ts` | 8030 | `19ff713d8268fa606e564adced389212a806f42a605c49c8add25850bf98af4c` |
| `operator/receipt-rpc.ts` | 6178 | `67281df0eba8c79a9f319ed932f1a640affacbf9a1dd42addf5adb74e6a45155` |
| `operator/receipt-association.ts` | 3491 | `ffe85fb5c09603a39377bdda08d4a7a3f2a399c92b2634fd4b32314824d09333` |
| `operator/receipt-reconciliation.ts` | 8602 | `11fa849afaa8ebeaca2b20f9b157242364b991b448c8b2d70b09b46f691cb1f0` |
| `operator/receipt.test.ts` | 8133 | `8dc3101301ce8369d20a3e66e8f09ece53dc94325ee9bb6be972132c34664536` |
| `operator/receipt-reconciliation.test.ts` | 5027 | `ac292360c69e8fabae5e9d537499a058460a115312cda1f8e314ec1e7ed24397` |
| `operator/receipt.fixture.ts` | 7985 | `edae27a4bf0600f1a09e94ed6756fe6b6fdbabe3570f5307d5976fec47bece80` |

Every accepted path has actual filesystem st_mode 33188, permission 0o644, committed Git mode 100644 and stage-0 index mode 100644. All 70 tracked frozen paths have actual Git and index mode 100644. **These are actual precommit/current filesystem and Git observations, not historical tested modes.** The tested source manifests omit filesystem/Git modes and permission bits; that historical information is unavailable and is not invented.

The complete immutable diff is byte-identical to the original precommit/staged.diff: 60758 bytes, SHA-256 `0dc99cf2d51910fd855e20b20505dc518c14e9de6668feacdaf8fb2e15d41f54`. The eight additions have no parent body; only the runbook and CLI modify existing paths. Their changes are the additive finite-receipt section, command import/help, and narrow command case. There is no financial/source-policy edit.

Actual read-only Git gates all exited 0 with empty failure output:

- Full parent-to-commit diff --check, with --ignore-submodules=all.
- Full git show --check --format= HEAD.
- Unstaged tracked diff --exit-code and staged diff --cached --exit-code, both ignoring submodules.

The incoming original staged set was empty; the delivered current staged set is empty. The current index's stage-0 blob IDs and modes match HEAD for all 70 identities. No git write-tree was rerun because it writes Git objects. Status contains only the pre-existing untracked receipt-evidence directory, including additive audit outputs. The receipt-evidence subtree has no committed tree entry.

All audit Git invocations used GIT_MASTER=1, GIT_OPTIONAL_LOCKS=0, GIT_PAGER=cat, PAGER=cat and git --no-pager; status/diff ignored submodules. No Git write or config change occurred.

## 3. Actual stopped execution and proof, authenticated rather than replayed

Both lane manifests authenticate in full: implementation 731 member rows, verification 733 member rows. Every one of the 17 direct seal bindings matches raw lengths/hashes. Command stdout/stderr hashes match each actual record. All 36 original input declarations and the additional manifest identity reauthenticate from the recovered input root. All original input-tree preservation rows also match.

The producer final strict check and final complete suite exited 0. The separate verifier strict check and one complete suite exited 0. Each retained final stderr contains exactly 159 passing test records and zero failed test records, with the actual summary 159 pass, 0 fail, 15 files; runtime version is recorded as Bun 1.4.2. These checks were **not rerun** by this audit.

The producer collection ran 2026-11-13T05:08:52.279Z to 05:09:23.398Z; the separate verifier collection ran 05:22:10.413Z to 05:22:41.478Z. Both actual command records show exit 0, null signal and stopped timestamps. The Python verifier oracle ran 05:24:45.408Z to 05:24:45.886Z and exited 0. Its independent raw.py/independent.py bodies authenticate and were read; neither imports producer reconciliation or CSV parsing. They authenticate all raw declarations, independently decode full CSV tables, reconstruct canonical associations and source/asset observations, and compare recorded results. They were not executed again here.

For **each lane**, authentication of the actual records establishes:

| Retained actual population | Count |
| --- | ---: |
| References: 43 weighted, 16 earlier CP, 18 raw claims | 77 |
| Distinct transactions / canonical rows / standalone transaction files | 77 each |
| Raw request/response pairs and proof envelopes | 310 |
| Receipt logs accounted for by all 77 canonical proof rows | 2368 |
| Selected saved Transfer locators, individually retained and matched | 568 |
| Conservative reference flags | 20 |
| Actual HTTP/RPC/transport failures or redactions | 0 |

Every actual request/response file was raw-hashed against its manifest. Each complete raw response envelope equals the existing independent-proof envelope; request identities/methods/parameters and recorded HTTP/outcome metadata agree. All 77 standalone files equal their archive result; canonical metadata and log counts equal the recorded proof. Every retained reference's raw fields, caller/callee/value/calldata context, source event/log observations and flag set agrees with the independent proof and producer review. Every one of 568 locator observations agrees with its retained exact input fields in both lanes. The existing independent oracle is the evidence for full semantic/canonical/event validation; this audit authenticates that proof and actual records rather than claiming a fresh oracle execution.

The schedule per lane is 1 eth_chainId, 78 eth_getBlockByNumber including the anchor, and 77 each of eth_getTransactionByHash, eth_getTransactionReceipt and eth_getBlockByHash. No range, getLogs, debug trace, send, signer or alternate-provider method appears. Chain 4663 and anchor 108944663/hash 0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733 authenticate before named requests. Transaction blocks are 45652334 through 87421203, at or before that anchor.

All 310 corresponding raw requests and all 310 raw responses are byte-identical between the two actual calls. Main output bytes also match:

| Actual output, in each lane | Bytes | SHA-256 |
| --- | ---: | --- |
| actual/archive.json | 3848804 | e390e13162b566cd4c138a4342e4e1186dc3053526e9743454db3d92d637839b |
| actual/reconciliation.json | 251139 | c1717f1e35984ff03aeddd16c6a7571439e8066f4160fdeec2f7f844ced1577e |
| actual/http-manifest.json | 154633 | 6feab989ce86fe70e1b70ad37acb42a775131c5e46a848b575689436f88d0731 |

This is two actual calls through the **same existing provider**, not independent-provider consensus or a trustless proof. Safe raw captures are response entity bytes, not HTTP framing, raw signed transactions, historical storage, execution-prefix traces, or authenticated historical build pedigree. Failure lists remain explicitly present and empty; no failed real collection was replaced or concealed.

## 4. Complete twenty-flag disposition

Every row below remains flagged in both actual reconciliations and independent reviews. Exact transactions and locator authentication remain in audit-support/actual-proof-audit.json; complete contexts, source events and output observations remain in the original sealed proof.

| Original locator | NFT or claim | Retained flag |
| --- | --- | --- |
| `conversions.csv#row=21` | T claim | `indirect-or-unexpected-claim-call` |
| `evidence/earlier-cp-bonds.csv#row=10` | 11 | `routed-dtf` |
| `evidence/earlier-cp-bonds.csv#row=11` | 12 | `routed-dtf` |
| `evidence/earlier-cp-bonds.csv#row=12` | 13 | `routed-dtf` |
| `evidence/earlier-cp-bonds.csv#row=13` | 14 | `routed-dtf` |
| `evidence/earlier-cp-bonds.csv#row=14` | 15 | `routed-dtf` |
| `evidence/earlier-cp-bonds.csv#row=15` | 16 | `routed-dtf` |
| `evidence/earlier-cp-bonds.csv#row=16` | 17 | `routed-dtf` |
| `evidence/earlier-cp-bonds.csv#row=17` | 18 | `routed-dtf` |
| `evidence/earlier-cp-bonds.csv#row=3` | 4 | `routed-dtf` |
| `evidence/earlier-cp-bonds.csv#row=4` | 5 | `routed-dtf` |
| `evidence/earlier-cp-bonds.csv#row=5` | 6 | `routed-dtf` |
| `evidence/earlier-cp-bonds.csv#row=6` | 7 | `routed-dtf` |
| `evidence/earlier-cp-bonds.csv#row=7` | 8 | `routed-dtf` |
| `evidence/earlier-cp-bonds.csv#row=8` | 9 | `routed-dtf` |
| `evidence/earlier-cp-bonds.csv#row=9` | 10 | `routed-dtf` |
| `evidence/weighted-bonds.csv#row=18` | 19 | `indirect-purchase-or-different-caller` |
| `evidence/weighted-bonds.csv#row=19` | 20 | `indirect-purchase-or-different-caller` |
| `evidence/weighted-bonds.csv#row=22` | 23 | `indirect-purchase-or-different-caller` |
| `evidence/weighted-bonds.csv#row=41` | 42 | `indirect-purchase-or-different-caller` |

The 15 CP routed-dtf rows are **comparison-scope differences**: their saved routed DTF equals the earlier SE component from 0xb7d4bb379d361ad442cddee53ea71a33957826a7, while the broader non-payer inbound sum also contains a separate LP-address inflow from 0x923877336b14662cfb5b3a60b14e7d716d54a888. They are neither demonstrated historical-field errors nor new user contributions. NFT3 has no extra LP inflow; its direct WETH 2000000000000000000, direct DTF 0 and separate SE-routed DTF 1778859964387451305574664 remain distinct.

Weighted IDs 19, 20, 23 and 42 retain matching event/payment observations but indirect outer calls or different callers. Their outer callee is 0x5ff137d4b0fdcd49dca30c7cf57e578a026d2789 with selector 0x1fad948c; no arbitrary outer-call decoding or original-wallet attribution is substituted.

For conversions.csv#row=21, transaction 0x6ece614ad85798eef4244cc58262b3edafce211f135a66f68e0354bbf57a12bb, the real source event names wallet 0x2c0400cf47e5ea01364e44c237aed22d7ae86199, weight 20000000000000000000000 and SY output 36107853. The outer caller is 0x5512144047c2d55297c8470b93e8da87864617cd, with the same indirect callee/selector and zero value. decodedDirectWeight remains null. This real event does **not** admit the claim under the current direct signed-EOA claimed-SY validator (claimed-sy.ts:132-140). No source policy changed. Gross transfers and event/recipient matches do not establish net contribution, direct-call proof or eligibility. The remaining 57 unflagged references are not eligibility approvals.

## 5. Raw failures, summary-only history and credential boundary

The actual attempt history remains intact:

- Pre-recorder TS2345 is a **diagnostic summary with locator mon_T4G7GK10M7H8XCRS**, in implementation/attempts.json. Original compiler bytes are not retained in that evidence file and are not invented here.
- types01 has actual raw stdout containing TS7022 at receipt.test.ts(71,11), actual empty stderr, and child exit 2. The enclosing recorded monitor exited 1; those exits are not conflated.
- focused01 records 30 pass/0 fail.
- mutation01 deliberately broke response-ID, receipt block-hash, source-purchase-event and shared-reference guards. Raw output records 26 pass/4 fail, exit 1. The four failed names appear again in its summary; eight textual '(fail)' lines are not eight distinct failures. Its historical source capture differs on five paths from the final freeze, including the later-added regression/test state. It is not relabeled final-source failure. All four final producer command captures (276 operator rows) and six independent command captures (414 rows) match final source bytes.
- Final types, final tests, collect and independent commands are retained separately and exit 0. The producer rendered-read JSON parse failure remains a display-truncation failure with its original locator/summary, not an HTTP failure or raw-data defect. No file was replaced to hide it.

Actual selected-credential scan records show 727 then-present producer evidence files and, separately, 1531 verifier scan files, zero matches. The latter scan checks literal and URL-encoded ALCHEMY_KEY values without emitting them and makes zero network requests. The audited collector selects only that existing alias's one RPC credential; no wallet credential or environment dump is selected. Subsequent report/seal additions contain public identities and safe observations. This audit neither loaded a credential nor reran a secret scan or provider operation. Its new outputs contain paths, public observations, exact hashes/modes and safe recorded argv, not an endpoint value or wallet secret. The unchanged suite's public Anvil development-key synthetic signing test remains offline, not operational signing.

Native TypeScript LSP timeouts and unavailable Biome/basedpyright are retained qualifications, not passing diagnostics. Biome is also unavailable for this audit's JSON support; the tool's suggested installation was not performed because this task prohibits dependency/configuration changes. JSON support is raw-parsed at closure, not described as LSP-clean.

## 6. Original per-entry preservation reproduced

The comparison starts from **the original commit/precommit inventories**, never a newer manifest or an aggregate substitute. baseline-bindings.json binds all 15 original inventory byte bodies and their root mapping. New per-root JSONL support retains an actual observation for every distinct original path and 1-based locators into each original content/permission/directory row. Full SHA-256, raw length, kind, full st_mode, permission, Git-mode collapse and symlink target are explicit; directories additionally retain size, nlink, child count and child-set hash. Every original field is compared.

| Original root | Content rows | Permission rows | Directory rows | Result |
| --- | ---: | ---: | ---: | --- |
| docs/incidents | 1482 | 1493 | 11 | Original content and modes unchanged; one expected directory bookkeeping change |
| out | 7376 | 13856 | 6480 | Every original row unchanged |
| cache_forge | 6502 | 12368 | 5866 | Every original row unchanged |
| recovered-input | 30 | 35 | 5 | Every original row unchanged |
| original-incident | 25 | 27 | 2 | Every original row unchanged |

All 80 cache_forge regular-file rows with permission 0o600/full st_mode 33152 remain unchanged. Other walked regular files retain 0o644/full st_mode 33188; directories retain 0o755/full st_mode 16877. Git mode 100644 was not used as a substitute for filesystem permissions. cache/ remains absent; cache_forge is the actual Foundry cache root. There was no artifact regeneration, relocation, deletion, restoration or build.

All 29 original foreign Git indexes retain exact raw SHA-256, byte length, full mode and permission. The index path set still matches all 30 original rows. Only this worktree's own index differs as expected from the source commit: 2077579 bytes / 47760b282e13f83c77f8be9a22b49b06bb5f9fd92bf21239728341cbb6c8b570 becomes 2078515 bytes / 64f80d782c15e24157675abb4b0057a32bd7e46001789077028743aa60ac391d, still 33188/0o644. This audit leaves that delivered index unchanged.

All 56 original raw ref/HEAD/packed-ref rows are compared individually. Only refs/heads/work/dtf-migration-phase-28-receipt-evidence changes, from parent to delivered commit, both 41 bytes and mode 33188/0o644. Both show-ref captures are 6579 bytes/68 lines; only that branch line differs. Reflogs were not in the original preservation set and are not silently included in this claim.

Both host dependency symlinks retain target text, target-text hash, length, full mode 41453/0o755 and inode: lib/crane inode 20472031 targets /Users/cyotee/Projects/indexedex/lib/crane; node_modules inode 20472032 targets /Users/cyotee/Projects/indexedex/node_modules. Neither target was opened. The Crane gitlink remains 160000 fc0618bf5c34d0564f4367130feff443bd4efc89. All ten original named authority files retain hashes, lengths, modes and inodes. No held09/phase09 worktree was opened; its foreign index, where present, was read only as raw bytes in the common Git metadata directory.

The original 48 delivery-support files are separately captured before audit writes and reauthenticated at closure, including the receipt, source manifest, original inventories, recipe, staged diff and preservation comparisons. New support never overwrites those files.

### Honest additive bookkeeping

The original baseline predates commit/. Its sole changed original directory row is receipt-evidence: size 128 to 160, nlink 4 to 5, children 2 to 3, because commit was added. Full mode/permission/kind remain 16877/0o755/dir; SHA-256 remains null. The child-set hash changes from 6427893862c3486e1889c0f3958e78f4e1423eaf68bdb0c670238d58b2430259 to c7fc894590f20266a5c6109144443da05e87deae03aa23b777e5132c15e9af1d.

The receipt accurately distinguishes its 46-file intermediate support rewalk from its two later files, receipt.md and preservation-compare.json. This audit begins with all 48 present; it does not pretend they were in the original baseline. Its verification.md and audit-support/ are further additions under the same commit/ subtree. They do not change the original receipt-evidence child set again, but do change bookkeeping of the newly added commit/ subtree. Closure records the exact additive paths. No unexpected addition outside that subtree is accepted as preservation.

## 7. New audit artifacts and stopped closure

All support paths below are relative to commit/. They retain full rows rather than only these summary identities.

| New support | Bytes | SHA-256 |
| --- | ---: | --- |
| `audit-support/docs-incidents.jsonl` | 700288 | `2c67bcc38d7bec95f9fb88c29ca0b0981496a975af523ccbdf36542aa0848124` |
| `audit-support/out.jsonl` | 5750847 | `19008402cb8501ac124002a5d8822d1350f54600be9f581c7cf66b6b33a2195a` |
| `audit-support/cache_forge.jsonl` | 6426625 | `44a360f50f764e56978d0ccf3130e8c582e24ca779fc1792b37732fae5e42847` |
| `audit-support/recovered-input.jsonl` | 15396 | `5c9e563a96f8626408a05d7be3d7ca7aabed00c3c0c929bea9d66d10b6391633` |
| `audit-support/original-incident.jsonl` | 11026 | `9295f187b6831eba75fefc9168fc7cd8c8134642d6f3ec62ae256bfd70824046` |
| `audit-support/baseline-bindings.json` | 6395 | `5cdb046eef48ac9dc0c887bae594c8f4135813ab91ac984d7b8a8c55d8f9421d` |
| `audit-support/metadata.json` | 95996 | `c792f85906283adcb2583b78e28f7cb4b7e258cf8734c7a37ff303fc6e8b59b9` |
| `audit-support/sources.json` | 170783 | `4a8f182833b99baa347b4662b8cce502d45d7d962d38f29a47312d49d947c2cf` |
| `audit-support/evidence-bindings.jsonl` | 1237855 | `40f2777bc2abc43389f69aef45126b94f6113010ae0bacec817e0deabaceb24f` |
| `audit-support/actual-proof-audit.json` | 1339163 | `49446b5b8543506a28da662a3e142dc4ea8c25de24b24cb9a7a4d4200155f24f` |
| `audit-support/git-read-proof.json` | 59947 | `9a14bd054481112baa350aed6a7d8b22df2081c7381f0c83d87dd725627d7bb8` |

The final audit-support/closure.json binds this report and the actual written support bytes, records original-support reauthentication, additive bookkeeping and stopped status. It is published last and excludes its own self-digest. This report does not claim its own raw hash. No pending audit child, monitor, collector, oracle, test, server, signer, chain or cleanup remains. Existing implementation/verification cleanup records remain STOPPED; command records contain actual stops, not a running handle reported as completion. No evidence was removed.

## 8. Limits preserved, without operational or plan acceptance

Hash-authenticated recovered historical bodies remain **recovered**, not located original captures. The annotated primary tree's two historical Markdown mismatches remain negative evidence, not repaired input. No economic value was reconstructed. This named archive does not automatically close the old 1240 unresolved candidate records or establish exhaustive history, refunds, native/WETH recovery, holder/source exposure, full W0/Q0, all prior claims, zero prior compensation, original eligibility or current control. Unknown values remain unknown. No configuration, C0, credit, award, allowance or source admission is produced. Recorded full-archive operational loader rejections remain false/false/false and were not rerun.

E-S, broader eligible T claim conservation, disabled downstream conversions, approved operational originals, current control, recovery coverage, actual funding/composition/snapshot and target registration gas remain separate. **45116678 > 32000000 gas** is not resolved. ETH/WETH remain provenance/funding/recovery assets, not invented standalone compensated surrender requirements.

P1 remains missing historical raw bytes, separate from this bounded delivery:

| Historical artifact | Bytes | Required SHA-256 |
| --- | ---: | --- |
| out/TestBase_UniswapV4DetfMigrationSnapshot.sol/MigrationSnapshotConsumer.json | 466441 | e7e44f1c9dd1feae73302f69cc50182b084c3e156ff63108f9e1206f52b201bf |
| out/MigrationNativeHandler.sol/MigrationNativeHandler.json | 266621 | 3628e086cdf17079f06aa157c414326519ba5de6d7a60df05e7deaa59e91d013 |

No reconstruction, universal historical build pedigree, eligibility, operational, full Task 9, or full-plan acceptance follows. **Confirmed, bounded and stopped.**
