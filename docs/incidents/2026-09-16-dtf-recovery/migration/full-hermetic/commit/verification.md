# Independent completed metadata-correction delivery audit

Date: 2026-11-12.

**Verdict: confirmed for the bounded one-file immutable source delivery and the actual completed full default hermetic gate.** No source, commit, test-result, raw-evidence or foreign-index blocker was found. This is qualified acceptance: base P1 remains an unresolved historical raw-version limitation. It is not all-history preservation, full-plan acceptance, cold/portable reconstruction, operational approval, unsupported-source/conversion success or target-gas acceptance.

## 1. Actual delivery, not a proposed commit

Read the complete assigned commit brief, actual `receipt.md`, `source-manifest.json`, `preservation-compare.json`, `report.md`, both seals, all runners and launch commands, initial failure/diagnosis/history, pager incident, final source diff, Forge version, raw-log identities and every original precommit inventory and recipe. All six full build/artifact/test logs and the focused log were read completely. Their raw lengths and hashes were independently recomputed; no bounded search result was used as proof of absence.

The actual observed subject is:

| Field | Independently observed |
| --- | --- |
| Worktree | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-25-full-hermetic` |
| Branch | `work/dtf-migration-phase-25-full-hermetic` |
| Commit | `137fa0c8749165087c7d1d0156788f58a1dbf1b8` |
| Actual sole parent | `8db3f5ee6310e8a700dad2d6a33e21d0955e63ca` |
| Tree | `aa68a333c11d70e4c1952b5c095f046ad26cbf34` |
| Subject | `Fix frozen quote interface metadata expectations` |
| Raw commit object | 1196 bytes; SHA-256 `6a9f24d68555d1384ce2bbbbdef0555d5558696a5d8888408de6eaacceb8449f` |
| Changed paths | Exactly one modified test; 3 insertions, 1 deletion |

`rev-list --parents -n 1 HEAD`, raw `cat-file commit HEAD`, `diff-tree`, `ls-tree`, `ls-files --stage` and the complete parent-to-HEAD diff establish these values. The message contains exactly one `Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>` trailer. The original delivery transcript also shows the actual successful commit invocation using `--trailer` and `-c trailer.ifexists=addIfDifferent`, not a claimed invocation inferred from the message.

Independent `verify-commit` exited 0 using the one-command `/usr/local/bin/gpg` override and key `55EB42889513051267BC55A395206404A78FB7F3`. Unknown ownertrust remains a warning, not identity certification. No Git configuration was changed.

## 2. Exact committed/current/index/tested source

The sole authorized and actual path is:

```text
test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVaultDFPkg_Deploy.t.sol
```

Current raw file, committed blob and current stage-zero index blob are identical: **17776 bytes**, SHA-256 **`e8869bc93a199c7c35c97612b804cbb5fde94ef4df1c5661463670e0e0954fc1`**, full file mode **33188**, permission **0644**, Git mode **100644**. Parent blob is `2a806b5a411e61dade8b08dd2183e442a2c0ac8e`; committed/index blob is `075c1444c757188cd187fe8d63df947422bbaf8c`. The source is ASCII, so the separately checked textual comparisons do not conceal decoding changes; the current raw streaming hash also matches.

The complete diff exactly equals the diff embedded in sealed `final-source-diff.txt`. It adds the actual frozen-quote interface import, changes the expected interface count from 15 to 16 and checks `interfaces[15]` against that interface's exact `interfaceId`. The facet-count assertion remains 15 and all pre-existing facet-address assertions remain unchanged. No production file, test deletion/skip, unrelated cleanup or evidence file is in the commit.

This identity is tied to the actual test execution rather than merely to a later manifest. Original runner-session records show the accepted source hash before r2 at 20:40:44 UTC and again after completed r2 at 22:37:30 UTC. Both are the same accepted hash. The subsequent seal binds that path, size, hash and mode. The original delivery actor's stage/commit output independently records:

```text
STAGED_SHA e8869bc93a199c7c35c97612b804cbb5fde94ef4df1c5661463670e0e0954fc1 BYTES 17776 SAME true MODE_OK true
CHECK_PARENT 0 ""
CHECK 0 ""
UNSTAGED ""
COMMIT_EXIT 0
AFTER_HEAD 137fa0c8749165087c7d1d0156788f58a1dbf1b8
```

Independent full parent-to-HEAD `diff --check` and `show --check --format=` both exited 0 with empty output. Full staged and unstaged tracked diffs both exited 0 with empty output. All **13074** index entries match the complete HEAD tree by path, mode and object ID; no nonzero stage exists. This comparison used listings, not `write-tree` or any other index/object mutation. Status has only the local untracked full-hermetic evidence directory.

## 3. Actual full gate and real later progress

The executed commands are preserved in the original runners. R2 executes serially:

```text
forge build --use solar
python3 scripts/forge-artifacts.py build --all-artifacts
forge test --use solar --match-path <the exact authorized path> --match-test test_packageMetadata_matchesExpectedFacets -vv
env -u FOUNDRY_ETH_RPC_URL -u ETH_RPC_URL forge test --use solar -vv --no-match-path '**/fork/**' --no-match-contract Fork
```

The focused path placeholder above abbreviates only this report's display; `run-gate-r2.sh` contains the full literal authorized path. The exact safe launch uses `env -i`, installed-tool PATH, explicit HOME/USER/TMPDIR/locale, default profile, empty Alchemy/Infura keys, TERM=dumb and NO_COLOR. It does not forward RPC or signing variables. Both runners check absence of `.env`. The full-run fork exclusions exactly match the current repository CI workflow. No new exclusion or warning-suppression setting was introduced. Default fuzz runs are 16; invariant runs/depth are 16/8, not the separate Migration 32/16 proof.

| Actual run/stage | Command exit | Tee exit | Independently read result |
| --- | ---: | ---: | --- |
| Initial full build | 0 | 0 | Successful compilation with warnings |
| Initial all-runtime-artifacts refresh | 0 | 0 | Completed before initial tests |
| Initial full suite | 1 | 0 | 28575 passed, 1 failed, 0 skipped; 2687 suites |
| R2 full build | 0 | 0 | Successful compilation with warnings |
| R2 all-runtime-artifacts refresh | 0 | 0 | Completed before focused/full tests |
| R2 focused metadata regression | 0 | 0 | 1 passed, 0 failed, 0 skipped |
| R2 full suite | 0 | 0 | **28576 passed, 0 failed, 0 skipped; 2687 suites** |

Independently summing every suite-result row gives the same initial and final totals as the respective full-log summaries. Final duration is 390.30 seconds, 6680.93 seconds CPU time. Initial duration is 325.08 seconds, 6923.63 seconds CPU time. The per-suite emitted test-name multiset is unchanged between initial and r2 logs; the metadata test is the sole changed result. Emitted trace rows are not substituted for Forge's logical test totals.

The command/tee exits are printed after tee and are therefore not inside the tee files. I independently read the original runner-session monitor/tool records, not just the receipt's claims. `audit-records.json` retains exact origin paths, line numbers, event IDs/timestamps, raw-line hashes and extracted actual results. Relevant original records include initial exit event `db1fd2bb`; r2 build/artifact/focused exit events `8a806469`, `d83ed013`, `4ce92587`; and final event `05388d6b`. The latter records `HERMETIC_R2_TEST_EXIT=0 CAPTURE_EXIT=0`, `FULL_HERMETIC_R2_GATE_COMPLETE` and watcher completion exit 0. The later actual `bash_112` inspection, event `5a217055`, confirms completed exit code 0.

The terminal incident is real and remains preserved. Original event `9189848e` associates monitor `mon_HDNAACMXH77Z1SZ6` with `bash_112`, still running at `Press RETURN to continue`. The actual input call sends `keys: ['enter']` to that existing session; event `6e05d8d0` confirms one key sent. Event `0223e890` then shows the same runner's profile and build start, followed by the real stage exits above. This was a blocked pre-build runner resumed once, not a fabricated duplicate successful run. Earlier assertions that tests were already running remain incorrect history, as the sealed incident states.

The original failure still says `interface count: 16 != 15`. Its raw logs, diagnosis, introducing-change record and failed exit remain unchanged; later success does not reclassify that run.

## 4. Seal and actual receipt integrity

Final `seal.json` is 4627 bytes, SHA-256 `30e624d82df639fc1fc55bd862c9de12365d3c98090ec57a35539a15f16c927e`. All **21** declared members match their exact raw bytes, lengths and full modes. Actual top-level evidence membership has no missing or extra member after the explicit self and future `commit/` exclusions. Every one of the initial seal's 10 members also matches the independently checked current raw identity. All four raw-log-identity records and their complete summary arrays match the actual logs.

Actual incoming delivery records:

| Record | Bytes | SHA-256 |
| --- | ---: | --- |
| `commit/receipt.md` | 10671 | `c957e15f01a670640504e26052bf66e1b5c10b83917126052e8c129457062ae2` |
| `commit/source-manifest.json` | 3388 | `e5292ee44478fa64ce972ebbe9592709c8296a480e78e070b4bc47f1314fd9f4` |
| `commit/preservation-compare.json` | 2452 | `44c6fedc9a8fb78137efec3f1cb95f8757a1121f11de9d59681294882997663b` |

All have full mode 33188. No self-digest or aggregate was accepted as a substitute for actual member comparisons.

## 5. Every original preservation row reproduced

I read the complete original `precommit/capture.mjs` and `recipe.txt`, parsed all original per-entry inventories and verified their declared raw inventory lengths/hashes. Then I independently applied `lstat`, no symlink traversal, exact permission/mode/length comparison and SHA-256 of each regular file's raw byte stream or symlink target. Permission rows were compared against those same actually hashed observations, not against null hash placeholders. Path membership was also walked independently.

| Original inventory | Independent result now |
| --- | --- |
| Evidence content, 36 rows | All paths, kinds, Git modes, permissions, full modes, lengths, raw hashes and targets match |
| Evidence permissions, 41 rows | 40 exact rows; one authorized additive directory-size difference explained below; all original modes/permissions match |
| `out/` content, 7376 rows | Every field and raw hash matches |
| `out/` permissions, 13856 rows | Every field matches, including directory sizes |
| `cache_forge/` content, 6498 rows | Every field and raw hash matches |
| `cache_forge/` permissions, 12364 rows | Every field matches, including directory sizes |
| Foreign indexes, 26 rows | Every original raw hash, length, full mode and permission matches |
| Refs, 52 rows | 51 unchanged; only the owned branch ref has the expected commit transition |
| Host dependencies, 2 rows | Symlink targets, inode, raw target hashes, sizes, full modes and permissions all match |

There are no missing or extra `out/` or `cache_forge/` entries. Additional incident-evidence entries are only under the authorized excluded `full-hermetic/commit/` subtree.

**Directory-size qualification:** the original full-hermetic directory row has size 768; its current size before this audit's writes is 800. Its kind, permission 0755 and full mode 16877 are unchanged. The authorized addition of the `commit/` child accounts for this one directory-size change. The original producer's postcommit comparison preceded creation of the commit support subtree, so its before-support directory comparison is not a present-day unchanged-size claim. I do not repeat that claim as current. This is additive evidence bookkeeping, not a missing or changed original file. The original comparison's null-hash permission false positives are also not byte changes; independent actual rehashes settle all file rows.

The own index's expected delivery transition is from `d43d7e1a878ed266e0805f2502061ba52b0511f1704db2eddab86b70aa14d6ad` to `71bf551379036296f359bc66b9eaadfee6ded0c7574612847ddfeb107b75e771`, both 2076067 bytes/mode 33188. The current index matches that recorded delivered value.

The owned branch-ref raw SHA-256 transitions from `bbad16e5c6ca428ad8c6deeb8792560a9e2bf7c70aeb20c9b87b35f6fa3fb30c` to `9f631241fe1d82ef6d8e279442be85e640fd477ee94da3690c0ef01ba31e76c4`, both 41 bytes/mode 33188. Exact `show-ref` comparison changes only the owned branch's parent-to-delivery line. All foreign refs/indexes are preserved.

Both `lib/crane` and `node_modules` symlink targets were not opened. The Crane gitlink remains `160000 fc0618bf5c34d0564f4367130feff443bd4efc89`. The phase09 worktree/candidate was not opened; only its explicitly required foreign raw Git index was hashed in the common Git directory.

## 6. P1 and acceptance boundaries remain

Read the actual phase24 `stateful-invariants/commit/P1-followup.md`. Its qualified current immutable acceptance does not recover these two historical first-producer raw JSON versions:

| Historical version still unresolved | Bytes | Required SHA-256 |
| --- | ---: | --- |
| `out/TestBase_UniswapV4DetfMigrationSnapshot.sol/MigrationSnapshotConsumer.json` | 466441 | `e7e44f1c9dd1feae73302f69cc50182b084c3e156ff63108f9e1206f52b201bf` |
| `out/MigrationNativeHandler.sol/MigrationNativeHandler.json` | 266621 | `3628e086cdf17079f06aa157c414326519ba5de6d7a60df05e7deaa59e91d013` |

This audit neither reconstructs nor searches for those versions. The current phase25 per-entry baselines are current baselines, not replacements for P1 or proof of every historical artifact version.

The hermetic default gas limit is 30000000000, not the 32000000 target cap. Retained registration gas 45116678 still exceeds that cap. No gas measurement was replayed. Operational original datasets/approval, source/archive equivalence, unsupported E-S/raw/direct or partial/prior-delivered/native/WETH paths and disabled conversions are not accepted here. No provider, held09, cold/portable, public or full-plan work was performed or authorized by this report.

## 7. Owned outputs and stopped cleanup

Only this new `commit/verification.md` and new `commit/audit-records.json` are owned writes. The support is 127508 bytes, SHA-256 `e1c9e842afb44b024f60744d73804a15259aefa52d6169aaedced0fede775ac1`. It retains the actual comparisons and original record locators; it is not a second runtime execution log. Original evidence is not edited.

All audit Git calls used `GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0`, explicit `--no-pager`, GIT_PAGER=cat and PAGER=cat. Status/diff ignored submodules. No source edit, build/test/runtime/CLI replay, install, new commit, index/ref mutation, historical-evidence edit, relocation or external write was performed.

No common/own index lock, merge, cherry-pick or rebase state was found. The read-only process inspection found no Forge, Anvil or Solar process; port 18574 had no listener. All short inspection subprocesses completed, and this audit started no background process, monitor or child task. JSON editor diagnostics could not run because Biome is not installed; syntax is checked by parsing the actual written support instead, without installing anything.

The final owned-output check records preservation of all 40 incoming full-hermetic files, unchanged source/HEAD/index/ref identity and clean tracked/index diffs. No owned operation remains pending.

**Conclusion: confirmed bounded immutable metadata delivery and actual full-hermetic success, with the explicit additive-directory bookkeeping qualification and unresolved historical P1.**
