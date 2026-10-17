# REQ-SEP-01 execution report

- Date: 2026-10-16
- Status: Complete. Implemented at the user's explicit request.
- Plan: [REMEDIATION_PRD.plan.md](./REMEDIATION_PRD.plan.md)
- Controlling PRD: [REMEDIATION_PRD.md](./REMEDIATION_PRD.md)

## Changes

Updated only `test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol` plus this report.

All pre-edit line checks matched: the helper at line 108, its five fixture-address references at lines 110/114/118/120/121, the only five calls at lines 330/341/374/388/520, and the existing `IStandardExchange` import.

The helper now accepts `IStandardExchange subject_` and `IERC20 token_`. All allowance reads use `subject_`; all six assertions remain unchanged. The callback success test at line 520 passes `locked_` and the probe token. The other four calls pass the fixture `adapter`.

A byte-for-byte comparison against the pre-edit snapshot verified that the helper and five calls are the entire test diff. The rollback twin, probe contract, fixture assignment, lock assertions, in-flight budget assertions, outer success assertion, and consumed-input assertion are unchanged. No production file was edited in this execution. No catch, nonce, or expiry check was added.

## Validation

Ran the entire file from the repository root with the exact planned command, without a test-name filter:

```bash
python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol \
  -- -vv
```

The helper selected three runtime artifact build roots and then ran the selected test file. The initial sandboxed attempt successfully compiled one file with Solc 0.8.35 in 50.52 seconds, then Forge crashed in macOS system proxy configuration (`system-configuration` / `dynamic_store.rs`: `Attempted to create a NULL object`; command exit 250). That attempt produced no test result.

The same command was rerun outside the sandbox with approval. Artifact and test compilation used the existing cache; the command exited 0:

```text
[PASS] test_RC01_callback_nestedMoneyEntry_hitsAdapterLock_outerSucceeds()
[PASS] test_RC01_callback_propagatedLock_rollsBack()
Suite result: ok. 20 passed; 0 failed; 0 skipped
Ran 1 test suite: 20 tests passed, 0 failed, 0 skipped (20 total tests)
```

The corrected callback test therefore passed its zero ERC-20 router allowance, zero ERC-20 Permit2 allowance, and zero Permit2 packed amount assertions on `locked_`. This closes the test-oracle gap; it does not establish a production allowance leak.

`git diff --check` passed for the edited test; a separate whitespace check passed for the untracked report. No Foundry configuration was changed, no fork profile or `via_ir` was enabled, and `out/` and `cache_forge/` were preserved.

## Worktree record

Pre-edit `git status --short` contained 295 entries; the target test was clean. All pre-existing status entries were retained. The only added short-status entry is the modified test; this new report is inside the already-untracked review directory, which short status collapses into one entry. Unrelated changes were preserved; nothing was committed or staged.

Local session evidence: `/tmp/req-sep-01-status-before.txt`, `/tmp/req-sep-01-before.sol`, `/tmp/req-sep-01-forge.log`, and `/tmp/req-sep-01-forge-retry.log`. These temporary files are not repository artifacts; the command and results are recorded above.
