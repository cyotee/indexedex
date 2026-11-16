# Retained attempts and diagnostics

All recorded commands preserve complete stdout/stderr, argv, CWD, start/stop,
exit code and operator source identities in their named sibling files.

1. The initial primary-checkout source glob failed because that checkout does
   not contain the operator directory. Inspection continued in the accepted
   phase28 worktree and the requested exact-base phase30 worktree. No source
   was written in the parent.
2. An LSP diagnostic identified TS2322: the old unparsed claimReceipt fixture
   inferred `removed: boolean`, incompatible with parsed log `removed: false`.
   Parsing the existing fixture with its existing receipt schema fixed this
   without assertions or suppression. This entry is a diagnostic summary, not
   a claim to retain original compiler stdout.
3. `types01` exited 0. `focused01` exited 0, 44 tests passed.
4. `mutation01` deliberately removed exact output amount/index checking and
   multiple-match detection. It exited 1 with exactly three intended failures:
   conversion ambiguity, recovery exact amount, recovery exact log index.
   It had 41 passes and 3 failures. All production guards were restored.
5. `types-final` exited 0 after production-source freeze. The first complete
   operator suite (`operator-tests-final`) exited 1 with 87 pass/85 fail because
   the fresh worktree lacked the existing warm Migration ABI under out/.
   Nothing was skipped or weakened. These full diagnostics remain retained.
6. The existing phase28 out/ was read-linked, not copied or built. No cache
   was seeded; no Forge command ran. The unchanged frozen-source suite
   (`operator-tests-complete`) exited 0 with 172 pass/0 fail across 15 files.
   All 69 operator TypeScript identities match both final suite and collection.
7. `collect` is the only actual new collection. It exited 0 with 319/319
   associations, no reference conflicts and empty stderr. No alternate provider,
   retry, trace, old77 replay or phase29 action occurred.
8. `support-types` exited 0 for the final recorder, oracle and sealer.
   `reconcile` exited 0 after all 319 records and all 1,278 raw responses.
   An earlier separate sealer compiler monitor also exited 0. No failed
   collection, failed oracle, install or provider workaround exists.
9. Fresh TypeScript LSP diagnostics repeatedly timed out at 3,000 ms on
   touched files. This is unavailable LSP evidence, not a clean LSP verdict.
   The actual strict compiler passed. No tool installation/configuration fix
   was attempted.
10. `boundary.command.json` exited 0 and retains the complete source diff and
    working-tree boundary. `finalize.ts inventory` exited 0. It removed only
    84 empty dtf-prepare-test directories born during the recorded failed-suite
    interval; every exact path is preserved in temporary-cleanup-selection.json.
    The failed fixture creates these before reading its missing artifact.
    Successful tests completed their own awaited server/temp cleanup.
11. The owned temporary out symlink was unlinked after all checks. A final
    read-only status, whitespace check and staged-stat command exited0.
    `final-boundary.md` retains that stopped final boundary. No warm artifact
    body was changed or removed.
12. JSON LSP diagnostics on cleanup.json were unavailable because Biome is
    not installed. No installation or configuration change was made, as the
    task explicitly forbids those. The file remains generated/parsed JSON;
    this unavailable diagnostic is not reported as a pass.

Initial tool-rendered broad read output exceeded display limits. Exact brief
and complete current PRD/plan were subsequently read in bounded sections;
neither observations nor a copied hash list supplied economic authority.
No failed display is classified as an RPC or historical-input defect.
