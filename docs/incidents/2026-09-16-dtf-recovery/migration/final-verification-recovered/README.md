# Recovered first-gate verification evidence

These are recovered records of commands already executed on November 13, 2026, not reruns and not evidence for subsequent B1/B2 remediation. The raw source is the parent session JSONL identified in execution-records.json. Each extracted event retains its original ID, timestamp and transcript line. Omitted-output notices are preserved; no missing stdout was synthesized.

## Source identity

Base commit: 1694e68a4bd66dd67d3b5e3f145f1da23074ff48.
source-snapshot.json contains all 64 task-specific replacements/additions copied into the frozen first review checkout, including complete source text and per-file SHA-256. Unmodified tracked sources come from the base. The snapshot includes the final TypeScript/fixture changes made after the hermetic run; those later files were covered by the subsequent typecheck/rehearsal, not retroactively by Forge.

The production Solidity and Foundry tests were unchanged between the final hermetic run and this review snapshot. The actual compiled recovery artifact identifies Solar 0.3.0-dev / Solidity 0.8.38+commit.e7a91fc7.solar.0.3.0-dev, Osaka EVM, optimizer enabled with one run. All 117 source hashes from its metadata match source in the review checkout; source-bindings.json records each comparison. This establishes the corrected donation code and its compiled dependencies, not a claim that every historical artifact has been recovered.

## Commands, results and reconciliation

execution-records.json includes exact expanded shell commands and original result events:

| Launch transcript line | Command purpose | Result |
| --- | --- | --- |
| 18576 | Artifact-first Migration specs followed by fork suite | Specs: 199/199; fork aggregate: 164 passed, one HTTP 429 setup failure; combined exit 1 |
| 18641 | Only the failed fork case, strict typecheck of bounded driver, then two complete signed deployments | Exit 0; missing fork case passed; 242 bounded transactions passed |
| 18707 | Default-profile full Solar build then hermetic Forge tests excluding fork paths/contracts | Exit 0; 28,604 passed, zero failed/skipped, 2,691 suites |
| 18802 | Strict operator types, delegated fixture build, operator unit tests, expanded rehearsal | Types/build/tests passed (180 tests); later rehearsal failed authentic donor sizing, so combined exit 1 |
| 18828 | Strict operator types then corrected real-source rehearsal | Exit 0; bounded-rehearsal-complete; retained runtime1794605887095 |

The exact failed case was MigrationRecoveryClaimVaultTest::test_minimumSelectedBatchAndLaterFailurePreserveCommittedReceipts, gas 0, pinned block108944663, HTTP429 fetching storage of0xAf5C0cD3fDEdd10bee00Eff77Fa0429Bacdb41f0. Its isolated retry used -j 1 --compute-units-per-second 10 --rpc-timeout 120 -vv and passed with gas4939961. This produces 165 distinct passing fork cases; it does not make the original aggregate exit0. No failing test was skipped or weakened.

The full hermetic command was forge build --use solar followed by forge test --use solar -vv --no-match-path "**/fork/**" --no-match-contract Fork with FOUNDRY_PROFILE=default. Full commands, working directories and sequential set-e semantics are in the JSON, not inferred from these shortened descriptions. The operator command was bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts. The final strict typecheck passed because the same set-e command subsequently executed and completed its rehearsal.

## Environment

Host: Darwin arm64, Apple M5 Max,18 CPU cores. Eval/runtime Bun1.4.4. Foundry binaries: /Users/cyotee/.foundry/bin. Forge1.9.1-nightly commit430523103f3e2f9ba432ffdd2031a9f966153d0d (build2026-11-03). Solar0.3.0-dev commite7a91fc70f29dc8d0c236d56a2aa7706dc2555cf (build2026-11-03). Version binaries were checked during evidence recovery; compiler metadata independently pins the compiled artifact's version. Login shell supplied existing archive credentials; no credential is included here. Loopback Anvil was chain4663, fork108944663, no public broadcast.

## Integrity

- source-snapshot.json: SHA-256 c7a6d8d4699f48c0bb668f8fb9fd21027da99784d3da8799d4181686ed6b02e6; 1102664 bytes.
- execution-records.json: SHA-256 a8f544fa8ee13c5a7849e45f0659bf31309f2b9529573c0b846c4495d90e97a4; 144870 bytes.
- compiled-recovery-inputs.json: SHA-256 3faea150aebda1abba5f81a4d405acac69fd313849954dc99268bb99144dd5b6; 51423 bytes.

These artifacts supplement verification.md and address missing command/source/result provenance. They do not change the REJECT disposition for B1/B2, prove financial eligibility, or turn custody-only routes into recoverable assets. The final remediation tree must receive its own affected checks and source binding.
