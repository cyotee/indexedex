# Independent immutable ER audit reproduction

Date: 2026-11-12. This is a read-only local audit recipe, not a runtime-suite command or permission to alter source, artifacts, indexes, refs, or prior evidence. The actual observations are in audit-evidence.json. Run from the retained phase18 worktree with its existing dependencies. Do not execute the producer/verifier runners or seal writers.

## Inputs and inventory encoding

Use commit/precommit/recipe.txt verbatim for field/key order, lstat, symlink handling, raw-byte hashing, permissions, POSIX sorting and compact JSONL serialization. Its raw SHA-256 is 2e746e82453156799fd6fb6b10694a43b4ce97433f090c001a4730031a146dc2. All 13 hashes in precommit/extra.json:aggregates were independently recomputed and match. No absent original baseline was replaced by a present-day aggregate.

The following are the exact inventory helpers executed in the resident Bun evaluation kernel. The session read(path) helper reads text; when reproducing outside that kernel, supply read = p => Bun.file(p).text(). fs is node:fs/promises. Hashing operates on raw bytes. These helpers neither write nor chmod.


audit-evidence.json records the initial comparison before the three audit-owned files existed: 2126 original incident file/link rows, 2283 permission rows including directories, 7340 out rows and 603 cache rows. Compare every original record by path and all fields; do not compare only counts or hashes. New rows are allowed only at the exact commit exclusion root or below it. The sole original directory-size difference is earlier-receipt 192 -> 224, kind dir, permission 0755, null hash unchanged. No original file/link difference is allowed.


```js
const fs = await import("node:fs/promises");
const wt = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-18-earlier-receipt";
const sha = b=>new Bun.CryptoHasher('sha256').update(b).digest('hex');
const hash = async p=>new Bun.CryptoHasher('sha256').update(await Bun.file(p).arrayBuffer()).digest('hex');
const entry = async p=>{const st=await fs.lstat(p), target=st.isSymbolicLink()?await fs.readlink(p):null;return {path:p.startsWith(wt+'/')?p.slice(wt.length+1):p,kind:st.isSymbolicLink()?'symlink':st.isFile()?'file':st.isDirectory()?'dir':'other',mode:st.isSymbolicLink()?'120000':st.isFile()?(st.mode&73?'100755':'100644'):'000000',perm:'0o'+(st.mode&511).toString(8),size:st.size,sha256:st.isSymbolicLink()?sha(target):st.isFile()?await hash(p):null,target};};
const walk = async(root,perms=false)=>{const arr=[];async function visit(p){const e=await entry(p); if(e.kind==='dir'){if(perms)arr.push({path:e.path,kind:e.kind,perm:e.perm,size:e.size,sha256:e.sha256}); for(const name of await fs.readdir(p))await visit(p+'/'+name);}else arr.push(perms?{path:e.path,kind:e.kind,perm:e.perm,size:e.size,sha256:e.sha256}:{path:e.path,kind:e.kind,mode:e.mode,size:e.size,sha256:e.sha256,target:e.target});}await visit(root);return arr.sort((a,b)=>a.path<b.path?-1:a.path>b.path?1:0);};
```

For each of [docs-incidents.jsonl, docs-incidents-perms.jsonl, out.jsonl, cache_forge.jsonl], parse every original JSONL row, rewalk the corresponding root (docs/incidents, docs/incidents, out, cache_forge), and build maps by path. Missing = original paths absent now; changed = original rows whose complete JSON.stringify serialization differs; added = current paths absent originally. Serialize current rows as JSON.stringify(row) + newline in sorted order. Permission mode is 0o plus octal bits, not Git's collapsed 100644. The helpers implement those exact field orders. Compare every added path to the explicit commit/ exclusion; future audit files are new excluded evidence, not historical rows.

For refs, parse the complete original show-ref.txt and actual GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 git show-ref by refname, comparing the union. Only refs/heads/work/dtf-migration-phase-18-earlier-receipt may change, from required parent acdbe319f3a20c3af6bea594c62461b6c7988717 to 1df9076c73b94a4f63172395763fa8cdd48fe060. Missing/new foreign refs are differences, not ignored.

For every original precommit/indexes.json row, lstat the exact indexPath and compare size, normalized Git mode, actual octal permission and raw SHA-256. All 19 foreign rows must match. This worktree's original index may differ due to the one source commit; compare its current raw hash to a2c5742f0e9c18b5ce04298b218b0fb82fb77ec3f00ff5ee6d3dc53be1422057 and prove its tracked entries equal HEAD. A foreign index/hash observation, including the held09 index, is not inspection of that worktree's candidate source.

For every precommit/host-dependencies.jsonl row, use its absolute path and compare every original path/kind/mode/perm/size/sha256/target field. All 28 rows must match. Independently compare extra.json:links target, inode, size, permission and raw target SHA-256. Never descend those dependency symlinks as inventory roots.

## Accepted paths and immutable Git checks

Read complete actual receipt.md, source-manifest.json and admitted verification/report.md; hash raw bytes. Report admission requires SHA-256 79d34b17e0b06b273c0350d450561650e09d312482efefd2effa01dbc7efe4bd. Complete receipt/manifest are required, not an absent/pending promise.

Derive the accepted set from verification/audit-fresh-final.json:runtimeBindings.preserved: select current-worktree contracts/, test/, scripts/ and the exact migration/operator-runbook.md source roles, excluding all evidence and external authority paths. Exactly 34 remain. Cross-check paths/hashes/lengths/modes against audit-producer-final.json preserved records, implementation/seal.json source and implementation/audit.json source, and precommit/source-identity-before.json. Then compare the complete actual required-parent-to-HEAD raw delta to that set. The commit manifest is checked after derivation, not used as acceptance authority.

For each path obtain committed bytes with GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 git cat-file blob HEAD:path; compare raw SHA-256 and length with current bytes and independently accepted bindings. Compare committed/parent blob IDs and both modes from the raw delta, and index mode/blob/stage0 from ls-files --stage. All current permissions and accepted modes are 0644/420, committed modes 100644; four additions have no parent blob. Check every source-manifest hash/mode/blob field too.

Exact executed commands, exits and output are retained under audit-evidence.json:gitCommands. Each command used git -C at the phase18 worktree and GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0. Every status/diff included --ignore-submodules=all. Required observations include:

- rev-list --parents -1 HEAD: exactly the required sole parent.
- rev-list --count required-parent..HEAD: 1.
- diff --raw --no-abbrev required-parent HEAD: exactly 34 paths, 30 M and 4 A.
- diff --numstat required-parent HEAD: 1376 insertions and 40 deletions.
- diff --check required-parent HEAD: exit0, empty output, including all four additions.
- diff --exit-code and diff --cached --exit-code: both exit0, empty tracked diffs.
- show -s --format=%B HEAD: exactly one required Co-authored-by line in the final trailer paragraph.
- verify-commit HEAD: exit0, good RSA signature, with unknown ownertrust retained.
- cat-file commit HEAD: 1203 raw bytes; SHA-256 20529f740fe555fc8bbd704f3112f5ddf243c2ce2eda2b18fccd5a025a17c3d7. SHA-1 of Git commit framing reproduces the exact commit ID.

No source whitespace fixes or commit writes form part of this recipe. The original staged whitespace gates are retained evidence; the actual immutable parent-to-HEAD whitespace check was independently executed, not replaced with an empty-index check.

## Seals and prior executed proof

Rehash each complete source/admission/implementation/verifier seal record at its exact path, byte length and available permission. Compare exact evidence memberships, allowing only each seal's declared self-exclusions. Independently rehash final fresh and producer audits, their 1678 preserved records each, artifacts, stages, prepared inputs, checks and producer-seal binding. Original source-admission inputs include six files deliberately changed by the accepted implementation: compare those old input hashes/lengths to exact required-parent blobs, not to current bytes; audit-evidence.json records every such historical/current pair and resolution. No other mismatch is allowed.

Both final audits carry 75 capture entries, not 75 distinct contracts; 57 artifact/runtime comparisons across 29 distinct artifacts; 301 compiler-source hashes; 2 separately checked stage artifacts with 545/68 source hashes; and 23 prepared inputs. Hash current artifact/source bytes, recompute runtime keccak256 and length, and compare code outside exactly compiler-declared immutable/link spans plus the checked library self-address guard. Re-derive allowed spans from the current artifact; do not trust an arbitrary recorded mask. Check linked target identity against actual captured libraries; 198-byte proxies have no excluded spans. This audit independently performed those static comparisons without compiling or making RPC calls.

Decode 72 retained raw signed payloads and 4 explicitly offline-reconstructed inherited payloads per final audit with the installed ethers Transaction.from. Compare transaction hash, recovered signer, nonce, chain4663, target, calldata/value where recorded, and actual mined receipt identities. Reconstructed bytes remain reconstructed, never original captures. For each of the three real resumes compare all 15 actual receipt fields recursively, including nested raw logs, and signed hash/nonce plus gas/gasPrice/r/s/v against raw RPC transaction. Require actual child SIGKILL/code null and the pre-resume missing completion. Never accept the producer sameCanonicalReceipt flag instead of raw equality.

Four raw ABI JSON files have ID-only differences after required independent Solar compilation: Allocation/Migration 2442 -> 534, MigrationDFPkg 2444 -> 536, Recovery 2457 -> 543. Read current raw JSON; substitute only its terminal top-level id in memory with originalId. Require recovered raw length and SHA-256 to equal the original sealed record and recoveredRaw. There are 48 repeated producer reconstruction records across those same four paths, zero fresh exceptions. These strings are not original captured files. Do not restore artifacts; current post-verification out/cache are the original commit-preservation baseline.

Prior execution proof, not a new execution here: 142 specs, 101 forks, 72 operator tests in one invocation, both stage builds, strict types and actual18568 CLI. Raw sealed execution.log/individual logs contain ordered PASS gates and passing totals. Recompute exact ER q/credit/Q/C/B/E arithmetic from the final retained observations; current source/commit identity binds that runtime proof to this immutable delivery.

## Cleanup and limits

Read-only lsof port18568 and ps on historical owned PIDs both exit1 with empty output. Fixed checkpoint/runtime parent and Git operation/index locks are absent. No owned service, monitor or runtime was started. No dependency/config installation, history rewrite, commit, push/PR/merge, held09 source inspection, source/governance action, public operation or unchanged-suite replay occurred.

Retain final strict typechecks versus unreliable LSP freshness, unavailable Bash LSP and absent Biome JSON LSP. Actual fresh parent gas 44,653,392 exceeds 32,000,000; Allocation 24510 bytes has only 66 bytes EIP170 headroom, enforcement enabled. Archived source match is not exact_match. ER conversion/donation, operational originals, opaque-origin reconciliation, other categories, host/archive portability and full hermetic/full-plan/target feasibility remain open.
