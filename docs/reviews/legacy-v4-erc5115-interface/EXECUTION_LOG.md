> **Superseded — legacy family deleted (2026-10-15).** Retained as historical evidence only. Do not execute this plan or restore its implementation. See the [removal report](../legacy-v4-removal/EXECUTION_REPORT.md).

# ERC-5115 remediation execution — 2026-10-15

Status: **Implementation and behavioral validation complete under the owner's explicit size waiver.** The legacy run passed all 136 behavioral/declaration tests, and the untouched V3 control passed all 9 tests. The two separate 24,576-byte tests still fail. Final sizes are IN 27,885 bytes and OUT 30,033 bytes; neither is EIP-170 deployable yet.

User authorization: execute `REMEDIATION_PRD.plan.md` in this session. Branch: `fix/legacy-v4-erc5115-interface`. Starting HEAD: `f35186e57ba8b23c5fca67c42b5ccbaa8fc0a5e2`.

The checkout already contained extensive uncommitted architecture and other changes. [Initial status](evidence/status-before.txt) and [resumption status](evidence/status-resume.txt) record that state. Existing changes were preserved. This execution edited the five authorized production files, the six named existing tests, the new ERC-5115 test, and this report/evidence. Shared SY code and other families were not edited by this execution.

## Production changes (steps 1–5)

- Removed Pendle inheritance from the legacy V4 query and money targets. Neither partial target inherits the full ERC-5115 interface.
- Implemented the six query reads locally, retaining zero returns for invalid preview tokens and the existing multi-token exit preview.
- Added non-payable five-argument ERC-5115 deposit. Both flag values go through the guarded `_exchangeIn` path without a new token pretransfer caller gate.
- Preserved redemption validation, the internal-balance caller gate, vault-held-share checks, named-holder settlement, minimum checks, and TWAP poke. Deposit and redeem emit the ERC-5115 events.
- Registered exactly three IN selectors and seven OUT multi-query selectors in the specified order. Replaced the two existing Pendle interface-id declarations in place; the IN facet's one-entry interface array remains unchanged.

Migration: legacy V4 callers must use `IERC5115_StandardizedYield`, supply the fifth deposit argument, and stop calling the removed Pendle-only methods. The six named legacy V4 test files now use that interface and signature.

## Toolchain and build

[Recorded toolchain](evidence/toolchain.json): Forge 1.5.1-stable (`b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2`), Solc 0.8.35, default Foundry profile, Prague EVM, optimizer enabled with one run, `via_ir = false`. Existing `out/` and `cache_forge/` were retained.

Executed from the repository root:

```sh
python3 scripts/forge-artifacts.py build \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol
```

Result: **exit 0**, compiler run successful; six files compiled with Solc 0.8.35 in 11.17 seconds. [Build output](evidence/build.log) includes the generated Forge command and compiler result. `git diff --check` for the five edited production files also passed.

## Runtime size gate

Executed the plan's measurement logic, recording stdout to [sizes.txt](evidence/sizes.txt):

```python
import subprocess, sys
names = ("UniswapV4StandardExchangeInFacet", "UniswapV4StandardExchangeOutFacet")
over = False
for name in names:
    raw = subprocess.check_output(["forge", "inspect", name, "deployedBytecode"], text=True).strip().strip('"')
    hex_ = raw[2:] if raw.startswith("0x") else raw
    if len(hex_) % 2:
        sys.exit(f"{name}: odd hex length")
    nbytes = len(hex_) // 2
    print(f"{name} {nbytes}")
    over = over or nbytes > 24576
sys.exit(2 if over else 0)
```

| Facet | Deployed bytecode (bytes) | Excess over 24,576 |
|---|---:|---:|
| `UniswapV4StandardExchangeInFacet` | 27,885 | 3,309 |
| `UniswapV4StandardExchangeOutFacet` | 30,033 | 5,457 |

Result: **exit 2**. These are runtime byte lengths, not creation bytecode lengths or hex-character counts.

## Initial stop and revised authorization

The first execution stopped at step 6 as instructed. The owner then explicitly directed: “Ignore ther size limitation for now. Complete the task. Our goal is to see if completing this plan reduces the size.” That instruction supersedes the size-based stop for this execution. It does not make either facet deployable under EIP-170.

No facet split, delegate hop, self-call, `via_ir` change, or size-assertion increase was introduced. The architecture and full-range tests now check size in separate `test_runtimeFacetSizes_withinEip170` cases, retaining the original 24,576-byte assertions while allowing all other assertions to execute. No commit, push, or PR was made.

## Test implementation and validation (steps 7–9)

The six existing test files were retargeted exactly within the named family. [Migration diff](evidence/test-migration.diff) records the changes relative to the pre-resumption working-tree content, including separate size tests. `single.deposit` tests and other families were not retargeted.

The new `UniswapV4StandardExchange_ERC5115.t.sol` reuses the architecture suite's vault-held-redeem setup: real facets, manager/registry package deployment, production vault proxy, and real PoolManager. Its six new tests verify:

- All nine Pendle-only selectors are absent; the eight ERC-5115 selectors resolve to their assigned facets; ERC-5115 support is true and Pendle support is false.
- The six proxy reads work, and invalid preview tokens return zero.
- False-flag deposit pulls approved tokens once, mints the returned shares to the receiver, and emits the exact `Deposit` fields.
- True-flag deposit from a code-less EOA succeeds after pretransfer, without approval or a second pull, and emits the exact `Deposit` fields.
- A value-bearing five-argument deposit fails as a low-level call without changing token/share/native balances.
- Internal-balance redemption burns only the requested vault-held shares, preserves caller shares, pays the receiver, and emits the exact `Redeem` fields.

The new file contains no bare `vm.expectRevert()`.

### Legacy V4 run

The literal plan command first failed before compilation because `--test-root` accepts a `.t.sol` file or directory, while `UniswapV4StandardExchange_FullRangeBook_Decimals.sol` is an abstract `.sol` file. [Original attempt](evidence/legacy-tests.log), exit 2. The corrected command selects its eight concrete full-range decimals suites instead; no additional test sources were edited.

[Exact corrected command](evidence/legacy-tests-command.txt). The helper refreshed 40 production roots/41 runtime artifact IDs, then compiled 14 test files successfully in 137.51 seconds. The sandboxed Forge process subsequently crashed while accessing macOS system proxy configuration, before executing tests: [sandbox attempt](evidence/legacy-tests-expanded.log), wrapper exit 250 (child signal abort).

The authorized retry outside the sandbox reused the artifacts and completed: **136 passed, 2 failed, 0 skipped across 14 suites**, exit 1. [Full output](evidence/legacy-tests-unsandboxed.log). The only failures are the two preserved `test_runtimeFacetSizes_withinEip170` assertions (`27,885 > 24,576`). All selector, interface, custody, event, architecture, full-range, decimals, and no-self-call behavior tests passed. The new ERC-5115 suite passed all 15 tests (six new plus nine inherited redemption regressions). Each of the eight decimals suites passed seven tests, including the configured 16-run fuzz test.

### Untouched Pendle control

```sh
python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/vaults/standard/sy/V3FullRangeNativeSY.t.sol \
  -- -vv
```

Run outside the sandbox with approval after the macOS Forge crash above. Result: **9 passed, 0 failed, 0 skipped**, exit 0. [Full output](evidence/v3-control.log). The helper refreshed the V3 runtime artifacts before testing. Hash checks confirm the V3 test and eight shared SY files remained unchanged through validation: [check](evidence/pendle-control-hashes-check.txt).

Across both completed runs: **145 passed, 2 failed, 0 skipped**. The only failures are the acknowledged legacy V4 size gates. The [scoped whitespace check](evidence/diff-check.txt) passed; pre-existing whitespace issues outside this task were preserved.

## Final size comparison

After both test runs, repeated `forge inspect <facet> deployedBytecode` for the IN and OUT facets, removed the `0x` prefix, verified even hex length, and measured decoded byte length. [Final measurement](evidence/sizes-final.json), size-gate exit 2. No optimizer, profile, or `via_ir` settings were changed.

| Facet | Recorded before ERC-5115 | Final measured bytes | Reduction |
|---|---:|---:|---:|
| `UniswapV4StandardExchangeInFacet` | 28,818 | 27,885 | 933 bytes (3.24%) |
| `UniswapV4StandardExchangeOutFacet` | 30,033 | 30,033 | 0 bytes |

The before values come from the preceding architecture execution's [saved size evidence](../legacy-v4-architecture-redesign-prd-review/execution/sizes.json), not a newly reconstructed baseline build. The after values are fresh measurements from this execution.

Finishing the test migration and validation caused no further runtime reduction beyond the production interface change already measured at step 6. The IN facet remains 3,309 bytes over the deployment limit, and OUT remains 5,457 bytes over. Size remediation is deferred by the owner; all remaining steps of this interface plan have been implemented and exercised.
