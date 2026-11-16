# Full-repository hermetic verification

Date: 2026-11-12. **Result: passed after one in-scope stale-test correction.** Full default hermetic suite:28,576passed,0failed,0skipped across2,687suites. This is the actual repository-wide gate, not a renamed focused Migration run. No operational deployment, cold portability or target-gas acceptance follows.

## Subject and correction

Worktree `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-25-full-hermetic`, branch work/dtf-migration-phase-25-full-hermetic, unchanged committed base8db3f5ee6310e8a700dad2d6a33e21d0955e63ca plus exactly one tested file modification: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVaultDFPkg_Deploy.t.sol`. Tested raw SHA256 `e8869bc93a199c7c35c97612b804cbb5fde94ef4df1c5661463670e0e0954fc1`. Full final Git diff and whitespace checks show only that file, empty staged set and no other tracked change.

Initial full gate passed build and runtime-artifact refresh, then reported28,575pass/1fail/0skip. Failure: test_packageMetadata_matchesExpectedFacets expected15interfaces but received16. Actual history shows Migration phase2 commit215c2bba6aa75e3e79bf68b7980b730927a85817 appended the frozen-quote interface without updating this test. This is our stale expectation, not unrelated debt waived to pass.

The fix imports the actual IStandardExchangeFrozenQuoteInputs type, expects16interfaces and checks that exact advertised interface identity. All15facet expectations remain. No production behavior, additional test seam, removed/skipped test or weaker assertion was introduced. This remains the existing metadata owner test. The changed file has192nonblank/noncomment lines; no new helper or test family was needed. Solidity diagnostics reported no diagnostics and diff--check passed. No production mutation experiment was run or claimed.

## Actual final commands and outcomes

The exact runner and safe launch environment are retained in run-gate-r2.sh and launch-command-r2.txt. Commands execute serially and capture command and tee exit statuses separately:

1. forge build --use solar: exit0, capture0.
2. python3 scripts/forge-artifacts.py build --all-artifacts: exit0, capture0.
3. The affected metadata test, same file/test name:1pass,0fail,0skip, exit0/capture0.
4. Full forge test --use solar -vv under default, --no-match-path **/fork/** and --no-match-contract Fork:28,576pass,0fail,0skip, exit0/capture0.

Full final summary: Ran2687test suites in390.30s (6680.93s CPU time). The monitor emitted FULL_HERMETIC_R2_GATE_COMPLETE and exited0. The current source hash was checked after completion.

These are the actual .github/workflows/foundry-ci.yml hermetic exclusions, not exclusions added to conceal the failure. Default profile targets test/foundry/spec; fork/remote cases remain separate. Runtime-artifact compilation precedes tests because FactoryServices may load creation bytecode not reachable through imports. No custom profile, viaIR, dependency install or warning suppression was added. The ordinary repository default fuzz/invariant settings apply here; the separately verified32x16 Migration stateful proof remains stronger, distinct evidence.

The runner uses env-i with explicit installed-tool paths, HOME/USER/TMPDIR/locale, default profile and empty provider-key variables. RPC overrides and signing credentials were not forwarded; no .env was admitted. Parent environment was unchanged. No public operation or explicit archive fork was started. This does not assert network-sandbox isolation or a cold dependency reconstruction.

## Terminal interruption and provenance

The r2 process initially blocked before build at a terminal Press RETURN prompt. Earlier status messages incorrectly called tests running. A single Enter unblocked the existing session; no duplicate gate was started and the executed recipe was not edited. terminal-prompt-incident.json preserves this error and recovery. Subsequent real build/artifact/focused/full events supply the actual result. Future noninteractive Git operations explicitly disable paging.

Initial failed logs, the introducing-change history, diagnosis and initial-run-seal.json remain unchanged. Final r2 logs are separate. raw-log-identities.json binds their exact byte lengths/hashes. Evidence hashes do not turn the initial failure into a pass. Bash/JSON editor servers were unavailable; runner syntax checks and actual process exits are separate checks, not claimed editor passes.

## Remaining boundary

The base8db3f5ee has qualified current immutable acceptance: P1 still records2unrecovered first-pass historical raw artifact JSON versions. This full gate does not recover them or establish all-history preservation. Current source and r2 runtime evidence remain accepted with that limitation.

Operational original datasets/approval, unsupported E-S/raw/direct or partial/prior-delivered/native/WETH paths, disabled conversions, source/archive equivalence, portable/cold reconstruction, safe evidence relocation/cleanup, and target gas remain open. Hermetic gas_limit30000000000 is not the target32000000 cap; retained registration45116678 still exceeds it. The held phase09 lane was not inspected or retried. No code commit is claimed in this report; scoped delivery follows the verified one-file change.
