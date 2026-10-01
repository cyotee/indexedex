# EtherFi native rounding validation

Ready patch: `/tmp/apex-etherfi-native-rounding-overlay/READY.patch`.
Identical convenience copy: `/tmp/apex-etherfi-native-rounding.patch`.
Evidence manifest: `/tmp/apex-etherfi-native-rounding-manifest.json`.

Seven files: three production targets/common helpers, one corrected external hermetic dependency fixture, one external native pool/policy fixture, one new 21-test native suite, and two corrected cases in the existing nonunit prepaid suite. The native suite deploys the vendored EETH and WeETH implementations behind their real ERC1967 proxies and uses the existing production SE package/factory deployment.

The patch preserves public selectors and strict nominal pulls for other tokens. Native paths track canonical shares, delivered input credit and actual recipient output; exact-output quotes fund the native floors, and refunds remain within the call's available credit. The eETH-to-WETH sequential quote now matches the wrapped value retained by execution.

## Final evidence

Isolated root: `/private/tmp/apex-review-fullspread-validation`.
No shared source/artifact writes were made. `source-isolation.json`, `handler-source-identity.json` and the final manifest preserve source and artifact identity; shared/isolated artifact inodes differ.

- `etherfi-native-validation/red-002`: eight initial tests against the frozen original production sources; seven runtime failures and one passing control.
- `etherfi-native-validation/red-003`: final 21 native tests against the same three original production sources; 19 runtime failures and two passing controls. The external fixture migration is present, while the native suite itself uses real vendored EETH/WeETH. Original production hashes and original runtime artifacts are recorded.
- `etherfi-native-validation/family-003`: **100 passed, zero failed, zero skipped**, nine suites. All 21 native tests pass. Both `testFuzz_APEX_` properties pass **10,001 cases** (10,000 generated plus prior regression replay). Existing accounting invariant passes **256 runs × 64 depth = 16,384 calls, zero reverts and zero discards**. Seed: `0x20260917`.
- `forge fmt --check` passes all seven patch files. Read-only shared `git apply --check --whitespace=error READY.patch` passes against the frozen baselines.

`red-001` and `family-001` had compilation/setup failures and are not runtime evidence. `family-002` identified exactly two legacy tests assuming nominal eETH delivery; those tests now fund before quoting, declare actual native delivery for prepaid execution, and assert exact native shares in refunds and retained dust. No production assertion was weakened.

## Commands and artifacts

`run.py` records exact commands, environment, source hashes, Foundry version, log hashes and exit status in each run directory. Final command:

```sh
FOUNDRY_INVARIANT_RUNS=256 FOUNDRY_INVARIANT_DEPTH=64 python3 scripts/forge-artifacts.py test \
  contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeCommon.sol \
  contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeInTarget.sol \
  contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeOutTarget.sol \
  --test-root test/foundry/spec/protocol/staking/etherfi \
  -- -vv --fuzz-seed 0x20260917 --fuzz-runs 10000
```

The artifact tool refreshed 32 concrete build roots and 28 runtime artifact IDs before testing. Solc 0.8.35, optimizer runs 1, viaIR false. All affected concrete facet selectors match the original runtime. Runtime sizes:

| Facet | Bytes |
| --- | ---: |
| EtherFiWeETHStandardExchangeInFacet | 23,534 |
| EtherFiWeETHStandardExchangeOutFacet | 16,747 |
| EtherFiWeETHMarkerFacet | 8,016 |
| EtherFiWeETHRebalanceFacet | 6,684 |

All are below 24,576 bytes. The manifest includes final artifact hashes and selectors.

## Integration

Apply the entire `READY.patch`; `production.patch` and `tests-and-fixtures.patch` are also available. All diffs were generated against frozen `originals/`, not against corrected sources. Do not rerun the draft generator scripts; the formatted overlay Solidity files are the final source of truth.

The corrected hermetic fixture also feeds `SeMatrix_EtherFiFixture`. The parent has been notified to include the seven EtherFi hook matrix rows in the shared integration gate. Local validation above covers the complete EtherFi family; it does not claim a full-repository run.
