# Full-repository hermetic gate intake

Read the accepted cumulative foundry.toml, .github/ASSISTANT_TESTS.md, actual .github/workflows/foundry-ci.yml and docs/ci.md gate references. This is preparation only; no full-repository command has run in this assessment. The active invariant commit/immutable audit remains untouched.

## Actual repository gate

Default profile tests test/foundry/spec; fork profile tests test/foundry/fork. The actual CI performs three ordered commands, not only a focused Migration wrapper:

```sh
forge build --use solar
python3 scripts/forge-artifacts.py build --all-artifacts
env -u FOUNDRY_ETH_RPC_URL -u ETH_RPC_URL forge test --use solar -vv --no-match-path "**/fork/**" --no-match-contract "Fork"
```

The explicit runtime-artifact build is necessary for implementations loaded by FactoryService rather than reachable through imports. The profile is default, no viaIR, optimizer runs1. CI excludes misplaced network suites under spec as well as the separate fork directory; these exclusions are declared repository policy, not a way to hide failing hermetic tests.

CI supplies empty ALCHEMY_KEY and its listed RPC variables, then removes ETH_RPC_URL/FOUNDRY_ETH_RPC_URL because empty fork-URL overrides can be interpreted as filesystem paths. The local gate must start without fork overrides or RPC/signing credentials; do not print resolved secret-bearing URLs or infer a network fallback. Do not launch it in a login environment and accidentally retain the archive credentials used for explicit fork gates. Use the approved installed toolchain and current repository configuration, with no package install or new profile.

## Evidence and interpretation

Run on the next independently accepted cumulative source, with current dynamic artifacts and the exact full command, once. Preserve before-run source/dependency identity and complete exit codes/raw logs. Broad compilation changes ignored out/cache, so do not run it during their active immutable-preservation audit. Keep it separate from cold/portable reconstruction and from a public deployment.

Use actual repository CI fuzz/invariant settings for CI-equivalent results; the previously accepted stricter Migration32x16/fail-on-revert stateful proof remains separately bound. Do not silently force every unrelated old handler into a different contract and call resulting failures pre-existing CI failures. Conversely, do not lower a failing run or alter tests to report green. Any difference in invocation/settings must be explicit.

A failing full gate requires classification from actual evidence: new-test/SUT regression versus independently reproduced unchanged failure versus environment/dependency blocker. Repair in-scope new defects; preserve existing unrelated failures and report them. Do not edit an old failing test green or substitute focused passes for the full gate. Rerun only missing/failing/affected checks after a material correction.

The configured hermetic gas_limit is30000000000. This permissive execution setting is not the retained32000000 target-chain transaction limit; no deployment feasibility follows from full hermetic success. No held09 source, optimization or refusal workaround is included.

No code, ref/index, artifact/cache, provider or running process was changed by this read-only intake.
