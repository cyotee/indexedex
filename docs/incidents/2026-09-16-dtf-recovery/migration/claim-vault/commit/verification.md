# Independent claim-vault local delivery audit

Date: 2026-11-12. **Disposition: needs-fix for immutable local delivery commit `9c227900b280713305d4a1a1d1cdc3d8d273f23d`.**

The actual commit and delivery receipt exist. All 40 accepted source identities, parent, committed modes, attribution, exclusions and retained preservation checks reconcile. Local delivery nevertheless fails its whitespace gate: all nine added files contain a new blank line at EOF. Accepted runtime hashes do not waive that failure. This report does not accept any later corrected source.

## Finding D1: committed whitespace failure

Location: the nine added files listed below; delivery `receipt.md`, Source provenance, records the staged check exiting 2 but still labels local delivery complete.

The independent immutable reproduction was:

`GIT_MASTER=1 git diff --ignore-submodules=all --check 4a53299b490343ed904d70c92ecbc7360fcb7659 9c227900b280713305d4a1a1d1cdc3d8d273f23d`

It exited **2**, with exactly these diagnostics:

```text
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationClaimVaultAllocationFacet.sol:20: new blank line at EOF.
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationClaimVaultAllocationTarget.sol:58: new blank line at EOF.
scripts/recovery/dtf-migration/claim-vault.test.ts:83: new blank line at EOF.
scripts/recovery/dtf-migration/rehearsal-claim-vault-source.ts:110: new blank line at EOF.
scripts/recovery/dtf-migration/rehearsal-claim-vault.ts:298: new blank line at EOF.
test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationClaimVault.t.sol:201: new blank line at EOF.
test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationClaimVaultForkBase.sol:95: new blank line at EOF.
test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryClaimVault.t.sol:194: new blank line at EOF.
test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationClaimVaultConfiguration.t.sol:251: new blank line at EOF.
```

The current index has no staged delta, so rerunning only a present-day cached check would not test the original delivery. The parent-to-commit check above tests the actual committed bytes and reproduces the receipt's nine errors. This is an in-scope delivery failure, not a provenance exception. Root owns the minimal EOF-only correction in a subsequent increment; no source correction, amend, history rewrite or new commit was performed by this audit. A later correction requires its own exact bindings and validation; existing E1 evidence is not final corrected-source acceptance.

## Independent source and commit reconciliation

- Commit `9c227900b280713305d4a1a1d1cdc3d8d273f23d`, tree `d0729eb87d2ab3c5f22b12e2bef0549226ba4239`, has the single required parent `4a53299b490343ed904d70c92ecbc7360fcb7659` and is the only child in that range. Branch is `work/dtf-migration-phase-16-claim-vault`; no upstream is configured.
- The source set was derived from the independent verifier's actual `reviewed-summary.json:sourceSnapshots`, then matched one-to-one to producer final source bindings and byte-exact final snapshots. It was not derived from the expected count, broad directory, producer pass flag or delivery manifest.
- All **40** accepted/current/snapshot/producer/committed raw SHA-256 identities agree: **31 modifications, 9 additions**, **1726 insertions, 69 deletions**. Every delivery manifest candidate field, including parent blob, was independently reconciled. Full per-path results are in `audit-source-identities.json`.
- The complete 177324-byte committed diff, including every added file, was read. Its SHA-256 is `865909f6a01ac5fe4b7ff5983b47900057dd9f3c44c2ff629bbdb66e82268548`. The full parent and commit trees have 13028 and 13037 entries; no mode/blob/path outside the accepted set changes. Migration-only production/package/TestBase, neighboring tests, typed operator/stage integration and the existing runbook form the coherent increment. Evidence, archives, snapshots, probes, logs, journals, broadcasts, caches, dependency/configuration and root-control paths are absent from the source commit.
- All committed modes are `100644`. The 31 existing parent modes are also `100644`; all nine additions are currently regular, non-executable files. E1 historical bindings attest bytes, not historical file modes. Snapshot read-only permissions are evidence permissions, not claimed committed source modes.
- Exactly one coauthor trailer is present: `Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>`. Subject is `Add verified bounded direct claim-vault surrender and recovery`.
- Current staged and unstaged tracked diffs are empty. Retained precommit status has no staged entry and contains only accepted source changes plus excluded claim-vault evidence. No foreign tracked delta was included. No historical raw index-byte identity is asserted beyond those retained facts.
- Source inspection found only the loopback URL template and `https://example.invalid`, public Anvil mnemonic fixtures for derivation indices 104/105 behind the fixed loopback18566 guards, the fork holder `vm.addr(0xD7FC0570D1)`, and deletion of `PRIVATE_KEY` from the Forge environment. No resolved credential endpoint, PEM signing key or assigned production key was found. Fixture guards and their local scope remain unchanged.

## Accepted runtime evidence and limits

The complete actual delivery receipt, producer report, independent E1 report and binding objects were read. The independent E1 report recomputes to **`eeeb506d011189454c005adeb703b1ce7646d69ca79951116ea81cec833d9e81`**, as accepted by root. Producer report, corrected brief, main plan r5 and PRD r22 also match their bound raw hashes; exact paths/hashes are retained in `audit-preservation.json`.

The sealed independent execution records 130 passing specs, 81 pinned forks, 64 operator tests, strict types, artifact preparation, both operator stages, actual fixed18566 CLI, exact ten-selector removal through the new allocation facet, and three independently decoded signed-transaction/receipt resumes. This audit counted 130 and 81 PASS log lines and inspected recorded operator/CLI conclusions, rather than copying a producer pass flag. Empty type-check output alone is not treated as new execution proof; the accepted report/check ledger remains its authority. No unchanged runtime suite was replayed and no runtime identity was newly recomputed here.

Unlinked artifact templates are not deployed runtime. The accepted E1 verifier distinguishes actual linked allocation runtime `0x1baf3f6df765aa47c65c37e54fbe275a6a63cf3485d13b5089cd2c8fe3380fc3` from its template and records recovery runtime `0xc0ca13b7e9d7eb488cd8a2eab5c0aa631feaac17f18d31181dcdcba2a51cef9d`. Seal and out-entry checks below preserve the witnesses; this source-delivery audit does not invent another runtime equality proof.

Historical repository source locates the legacy family but exact archived/deployed-source equivalence remains **unestablished**. Actual pinned E1 execution is the accepted route proof. Direct shares are not raw TokenStaking rights, infrastructure backing authority or proof of affected users' direct-share holdings. Synthetic originals remain synthetic; operational datasets and other source categories stay open.

This remains a workstation-local rehearsal, not portable/full-F3 acceptance. Foundry/authority paths are host-specific. The retained phase15 W-SD archive is:

`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-15-dtf-custody-se/docs/incidents/2026-09-16-dtf-recovery/migration/dtf-custody-se/implementation/source-archive.json`

It remains **1047506 bytes**, SHA-256 `600c072adccc5e624333fd3dfd511787a3d89868193b320efdb8cbfc912483e7`. It was hashed in place, not rewritten or removed. It must survive phase15 cleanup unless deliberately relocated with new bindings. Full-category/full-plan/hermetic completion and target-gas/public acceptance are not given. The accepted 44099850-gas permissive-local deployment observation does not close target feasibility.

## Preservation and cleanup

Every retained per-entry JSONL baseline was independently parsed and rechecked with lstat and raw-byte SHA-256, using `precommit/recipe.txt` (SHA-256 `45c2c071e55e759d45dae306ef15133cbf314a22af6a0ce80b9d28dc62924804`). Aggregate hashes identify the retained encodings; they were not used instead of per-entry comparisons.

| Retained baseline | Entries checked | Result |
| --- | ---: | --- |
| `docs-incidents.jsonl` | 996 | Zero missing or changed; only excluded commit evidence is new |
| `docs-incidents-perms.jsonl` | 1149 | Every sealed file/directory permission, size and hash preserved; only parent claim-vault directory size 192 -> 224 |
| `out.jsonl` | 7330 | Zero missing, changed or added |
| `cache_forge.jsonl` | 595 | Zero missing, changed or added |

The claim-vault parent directory remains `0o755`; its size change is explained by delivery's creation of `commit/`, not a sealed-child mutation. Producer `final-tree.json` has all **541** entries byte/size-identical; verifier `seal.json` has all **430** entries byte/size-identical. The nine earlier predecessor entries remain in the preserved docs baseline. Actual producer-e1 files retain `0o444/0o400` and directories `0o555`. Earlier implementation/verification history and verifier-e1 have their recorded writable modes; this audit does not falsely label every sealed tree read-only. No file was chmodded.

All **55** retained refs were compared. The only movement is this branch from the parent to `9c227900b280713305d4a1a1d1cdc3d8d273f23d`; no new ref exists. Both dependency links retain the receipt's targets, inode values and `0o755`; unavailable historical inode metadata is not invented. Complete raw git and preservation results, baseline hashes, exceptions and methods are in the supporting JSON files.

Port18566 has no listener (lsof exit1, empty output); recorded producer/verifier PIDs 57230,57324,48079,49746 are absent (ps exit1, empty output). The fixed checkpoint path is absent. No merge, cherry-pick, revert, rebase or index-lock state exists. The auditor started no runtime and left no pending operation. No held09 content was inspected/imported/replayed, no dependency/configuration/provider change was made, and no push, PR, merge or public action occurred.

## Audit artifacts

Only this new report and the following new audit evidence were written under `commit/`. Existing receipt, source manifest, baselines and all sealed history were preserved.

The configured JSON LSP could not run because `biome` is not installed. No dependency or configuration was changed. The supporting objects were serialized and parsed as JSON directly; no prose-pinning or runtime test was added.

| File | SHA-256 |
| --- | --- |
| `audit-source-identities.json` | `eb758c2d1db213a7cdc6bc93edc71fa6d880e908a3f15d40756fea9ec7f09cd9` |
| `audit-git-checks.json` | `6e0737b427288afe08d490b22cb649a5c4676bbb18b6cda09e11c7119782b71b` |
| `audit-preservation.json` | `cab1fc7ec27dddd4772e9f4c744397d296d021f9aa8198569a9094463224493f` |

**Bounded source-identity and preservation checks: confirmed. Overall local delivery: needs-fix (D1). Cleanup: confirmed. No corrected-source or broader acceptance.**
