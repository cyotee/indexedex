# Foundry artifact generation mismatch

Reported failures: 20. Reproduced unchanged: six named tests, plus 14 PairToken setup failures.
The PairToken reproduction also passed 76 tests in unaffected suites.

The current installed Solar compiler is a2b44354 (0.8.38-compatible).
The cache contains 6,454 a2b44354 artifact entries and 2,833 e7a91fc7 entries.
For FeeCollectorManagerFacet, the source-qualified lookup resolves the current
collector/FeeCollectorManagerFacet.sol artifact; the short lookup resolves the
older flat FeeCollectorManagerFacet.sol artifact. Both name the same source.
Their executable creation bytes are equal after removing their metadata trailers;
their full creation bytes differ. This reproduces test_fullSourceIdentifier.

Preserve the existing out and cache_forge directories under:
`/Users/cyotee/Projects/indexedex/.omo/verification/artifact-mismatch-20261116/before-rebuild-1794797375510`.
Then rebuild using one Solar compiler without changing contracts or assertions.
The other reported identity failures must pass unchanged before being marked fixed.

Before-run output: before-refresh.log and pairtoken-before-refresh.log.
Backup directories are preserved evidence, not temporary test fixtures to delete.
No source instrumentation, new test harness, public transaction or operator code is needed.

## Repair validation

The old directories were moved intact to the backup path above. A fresh
`forge build --use solar` compiled 5,896 files successfully (exit 0).
All current cached artifact entries now use 0.8.38+commit.a2b44354.solar.0.3.0-dev.
The affected-suite run passed 279 tests across 23 suites, with zero failures
and zero skips. All six named failing tests were observed passing, and every
one of the 14 previously failing PairToken suites ran successfully.
No Solidity or test source was changed to obtain these results.
The full hermetic regression passed: 28,641 tests across 2,691 suites,
zero failures and zero skips, exit 0.

Command:

```sh
forge test --use solar --no-match-path '**/fork/**' --no-match-contract Fork
```

The run used the existing Foundry nightly
`430523103f3e2f9ba432ffdd2031a9f966153d0d`, with
`$HOME/.foundry/bin` on PATH and RPC credentials unset.
Output is retained in `full-hermetic.log`.

Final Git inspection confirmed no edits to contracts, tests or scripts.
The only source-tree changes are the artifact workflow documentation and this
diagnostic record. `git diff --check` passed. No tests, checks or expected
hashes were removed or weakened. No public transactions or new commits were made.
The affected run and full hermetic run completed; no test process remains owned
by this task. Historical fork suites were not rerun because the repair changed
compiled artifact state rather than contract behavior.
