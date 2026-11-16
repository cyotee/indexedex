# PairToken baseline execution evidence

Behavioral authority: `docs/research/pairtoken-unified-prd-r2-20261027/handoff/PRD.md`.
Raw-file SHA-256: `088ba325456c1ce4a93cbe0fc9625e1119352dbb8b209455460322b11d052d8d`.
Execution date: October 27, 2026.

## Scope

This is a standalone PairToken-local implementation tested against scripted
dependencies, not a pool engine, deployed factory, hook, or token-safety claim.
The implementation used the pinned PRD's formulas and behavioral contracts.
The original PairToken source and Sourcify output were not consulted during this
implementation. This is not a certification of source nonexposure or legal
clearance. There is no claim of bytecode identity or factory-clone parity.
No deployment or registry integration was performed. Deliberate deviations: none.

The implementation plan's section 8 maps all 182 tagged PRD identifiers to work
packages and evidence. `check-coverage.py` verifies the raw PRD hash and fails if
any tagged ID is missing from that map; it passed. Planning constraints remain
planning evidence, not runtime assertions.

## Compiler and runner

- Forge 1.8.5-Homebrew, commit `51a52c59cffd940f76eddd0b4bb1791aa4b5ac7f`.
- Solc 0.8.35, repository default profile, Osaka EVM, optimizer enabled with one
  run, `via_ir = false`. No profile or compiler configuration was added.
- The artifact helper builds production before running tests. Configured
  source/test/cache/output paths remain unchanged.
- Forge's dynamic test linking produced `vm.deployCode: no matching artifact
  found` during test setup with filtered roots, despite the production artifact
  being present. The supported `--no-dynamic-test-linking` test option runs
  ordinary creation and resolves that runner failure. This is a test-runner
  setting, not a different PairToken compiler profile.

### D-SOLC observable comparison

`test_PT_ERROR_compiler_encodings` passed and emitted the following actual
returndata. These match the Solidity 0.8.26 ABI/panic contract specified in
PT-ERROR-03. This compares observable encodings, not bytecode or a second
0.8.26 build.

```text
checked overflow: 0x4e487b710000000000000000000000000000000000000000000000000000000000000011
initialization division: 0x4e487b710000000000000000000000000000000000000000000000000000000000000012
custom error: 0xd92e233d
out-of-range enum decode: 0x
MD zero denominator: 0x
MU upward overflow: 0x
```

The custom error is `ZeroAddress()`. The arithmetic failure is checked share
balance subtraction; the division failure is actual initialization with zero
spacing. The enum failure is a manager-authorized callback carrying operation 5.
MD/MU execute the production math through external test frames.

## Public manager-interface pin

Compared with public Uniswap v4-core tag `v4.0.0`, commit
`e50237c43811bd9b526eff40f26772152a42daba`, specifically
`src/interfaces/IPoolManager.sol`, `src/interfaces/IExtsload.sol`, and
`src/types/PoolKey.sol`. Reference:
`https://github.com/Uniswap/v4-core/tree/e50237c43811bd9b526eff40f26772152a42daba`.

`test_PT_DEPENDS_manager_selectors` passed for all seven consumed selectors:

| Method | Selector |
| --- | --- |
| unlock(bytes) | `0x48c89491` |
| modifyLiquidity(PoolKey,ModifyLiquidityParams,bytes) | `0x5a6bcfda` |
| swap(PoolKey,SwapParams,bytes) | `0xf3cd914c` |
| sync(address) | `0xa5841194` |
| settle() | `0x11da60b4` |
| take(address,address,uint256) | `0x0b0d9c09` |
| extsload(bytes32) | `0x1e2eaeaf` |

The tuple types are independently transcribed from that public interface and
match D-ABI. Selector agreement does not establish deployed manager layout,
swap mathematics, unlock enforcement, hook behavior, or whole-system equivalence.

## Static-call evidence

`test_PT_VIEW_slots` passed. Its state-diff assertions independently derive the
manager slots, verify the low-128-bit position read, and check four ordered
STATICCALLs from the instance: slot0, position, token0 balance, token1 balance.
The following is an excerpt from the successful `-vvvv` execution trace:

```text
    ├─ [35242] 0x1d1499e622D69689cdf9004d05Ec547d650Ff211::basket() [staticcall]
    │   ├─ [4858] 0x2e234DAe75C793f67A35089C9d99245E1C58470b::extsload(0x35d130b151cb2ac770d9564d948a654cbcacd5c5cff10ade971e8eb55488e885) [staticcall]
    │   │   └─ ← [Return] 0x0000000000000000000000000000000000000001000000000000000000000000
    │   ├─ [2858] 0x2e234DAe75C793f67A35089C9d99245E1C58470b::extsload(0xa5e47b5e9ad41e15875ebb1a4a57d33b4155073df7cb7dab69b8c32395d5bc28) [staticcall]
    │   │   └─ ← [Return] 0x0000000000000000000000000000000000000000000000000000000000000000
    │   ├─ [2735] 0xc7183455a4C133Ae270771860664b6B7ec320bB1::balanceOf(0x1d1499e622D69689cdf9004d05Ec547d650Ff211) [staticcall]
    │   │   └─ ← [Return] 71
    │   ├─ [2735] 0xa0Cb889707d426A7A386870A03bc70d1b0697598::balanceOf(0x1d1499e622D69689cdf9004d05Ec547d650Ff211) [staticcall]
    │   │   └─ ← [Return] 83
```

Gas annotations are runner observations, not a gas guarantee. Native gas
forwarding is instead tested using recipients whose receive functions write
storage. The production contract contains no guard added to detect STATICCALL.


## Final combined result

The final combined run passed **151 tests across seven suites**, with zero
failures and zero skips, exit code 0. The 68 acceptance IDs and all 15 additional
section 7.4 test names are represented. The exact executed test names and suite
summaries are archived in `TEST_RESULTS.txt`. The numerical suite also ran 16
fuzz cases against Python's independent wide-integer oracle. Deterministic
fixtures cover tick boundaries, coefficient bits, random samples, full-width
products, nested rounding, cast failures, and square roots.

Reproduce from the repository root:

```sh
python3 test/foundry/spec/pairtoken-baseline/check-coverage.py
python3 test/foundry/spec/pairtoken-baseline/math-oracle.py
python3 scripts/forge-artifacts.py test   contracts/pairtoken-baseline/PairToken.sol   contracts/pairtoken-baseline/PairTokenMath.sol   --test-root test/foundry/spec/pairtoken-baseline   --no-consumer-artifacts -- --no-dynamic-test-linking -vv
```

For the archived static-call/compiler trace, select `test_PT_VIEW_slots|test_PT_ERROR_compiler_encodings`
with `--match-test` and use `-vvvv` after the final `--`.

### Implementation responsibilities

| Work package | Concrete implementation | Executed evidence |
| --- | --- | --- |
| WP-MATH | PairTokenMath.sol | PairTokenMath.t.sol; Compiler; AC22/33/47/55/56 |
| WP-TOKEN | PairToken.sol share methods | Identity, Surface, Exit; AC05-07/57 |
| WP-INIT | PairToken.sol initialize and stored getters | Identity; AC01-04, negative spacing |
| WP-READ | PairToken.sol basket and previews | Surface, Entry, Exit; slots, AC08-12/29-33/62 |
| WP-FUNDS | PairToken.sol idle/pull/pay/approval/refund helpers | Entry, Exit, Callbacks; AC13-16/38-39/49/52-54/59-65/68 |
| WP-CB | PairToken.sol unlockCallback and settlement | Callbacks, Surface; AC44-51/56/62 |
| WP-COMP | PairToken.sol compound and protocol routing | Callbacks; AC34-44/66-68 |
| WP-ENTRY | PairToken.sol deposit and zapDeposit | Entry; AC08-22/59-63 |
| WP-EXIT | PairToken.sol redeem and redeemZap | Exit; AC23-33/52-54/64-65, skip-add reset |
| WP-SURFACE | PairToken.sol ABI/errors/events/guards | Identity ABI artifact check, Compiler, Surface, Entry, Exit, Callbacks |
| WP-HARNESS | harness/ScriptedDependencies.sol and PairTokenTestBase.sol | Actual instance deployment; scripted external dependencies only |
| WP-PLAN | Pinned plan sections 1-10 | 182-ID coverage check and the scope/pin/limits in this index |

Production paths above are relative to `contracts/pairtoken-baseline/`.
Test paths are relative to this evidence index. The plan's section 8 supplies
the per-requirement mapping; this table binds its work packages to actual files
and the following tables bind its scenario/test references to executed results.

### Acceptance results

Names are prefixes: all suffixed subcases in `TEST_RESULTS.txt` are included.
Each row passed in the final combined run, not merely in an earlier focused run.

| Acceptance ID / test prefix | Result | Executed tests | Test files |
| --- | --- | ---: | --- |
| PT-AC-01 / `test_PT_AC_01` | PASS | 1 | PairTokenIdentity.t.sol |
| PT-AC-02 / `test_PT_AC_02` | PASS | 1 | PairTokenIdentity.t.sol |
| PT-AC-03 / `test_PT_AC_03` | PASS | 1 | PairTokenIdentity.t.sol |
| PT-AC-04 / `test_PT_AC_04` | PASS | 1 | PairTokenIdentity.t.sol |
| PT-AC-05 / `test_PT_AC_05` | PASS | 1 | PairTokenSurface.t.sol |
| PT-AC-06 / `test_PT_AC_06` | PASS | 1 | PairTokenSurface.t.sol |
| PT-AC-07 / `test_PT_AC_07` | PASS | 1 | PairTokenSurface.t.sol |
| PT-AC-08 / `test_PT_AC_08` | PASS | 2 | PairTokenEntry.t.sol |
| PT-AC-09 / `test_PT_AC_09` | PASS | 3 | PairTokenEntry.t.sol |
| PT-AC-10 / `test_PT_AC_10` | PASS | 2 | PairTokenEntry.t.sol |
| PT-AC-11 / `test_PT_AC_11` | PASS | 2 | PairTokenEntry.t.sol |
| PT-AC-12 / `test_PT_AC_12` | PASS | 1 | PairTokenEntry.t.sol |
| PT-AC-13 / `test_PT_AC_13` | PASS | 2 | PairTokenEntry.t.sol |
| PT-AC-14 / `test_PT_AC_14` | PASS | 2 | PairTokenEntry.t.sol |
| PT-AC-15 / `test_PT_AC_15` | PASS | 2 | PairTokenEntry.t.sol |
| PT-AC-16 / `test_PT_AC_16` | PASS | 2 | PairTokenEntry.t.sol |
| PT-AC-17 / `test_PT_AC_17` | PASS | 4 | PairTokenEntry.t.sol |
| PT-AC-18 / `test_PT_AC_18` | PASS | 3 | PairTokenEntry.t.sol |
| PT-AC-19 / `test_PT_AC_19` | PASS | 2 | PairTokenEntry.t.sol |
| PT-AC-20 / `test_PT_AC_20` | PASS | 5 | PairTokenEntry.t.sol |
| PT-AC-21 / `test_PT_AC_21` | PASS | 1 | PairTokenEntry.t.sol |
| PT-AC-22 / `test_PT_AC_22` | PASS | 2 | PairTokenEntry.t.sol, PairTokenMath.t.sol |
| PT-AC-23 / `test_PT_AC_23` | PASS | 1 | PairTokenExit.t.sol |
| PT-AC-24 / `test_PT_AC_24` | PASS | 1 | PairTokenExit.t.sol |
| PT-AC-25 / `test_PT_AC_25` | PASS | 1 | PairTokenExit.t.sol |
| PT-AC-26 / `test_PT_AC_26` | PASS | 1 | PairTokenExit.t.sol |
| PT-AC-27 / `test_PT_AC_27` | PASS | 1 | PairTokenExit.t.sol |
| PT-AC-28 / `test_PT_AC_28` | PASS | 3 | PairTokenExit.t.sol |
| PT-AC-29 / `test_PT_AC_29` | PASS | 2 | PairTokenExit.t.sol |
| PT-AC-30 / `test_PT_AC_30` | PASS | 1 | PairTokenExit.t.sol |
| PT-AC-31 / `test_PT_AC_31` | PASS | 1 | PairTokenExit.t.sol |
| PT-AC-32 / `test_PT_AC_32` | PASS | 1 | PairTokenExit.t.sol |
| PT-AC-33 / `test_PT_AC_33` | PASS | 2 | PairTokenExit.t.sol, PairTokenMath.t.sol |
| PT-AC-34 / `test_PT_AC_34` | PASS | 2 | PairTokenCallbacks.t.sol |
| PT-AC-35 / `test_PT_AC_35` | PASS | 1 | PairTokenCallbacks.t.sol |
| PT-AC-36 / `test_PT_AC_36` | PASS | 2 | PairTokenCallbacks.t.sol |
| PT-AC-37 / `test_PT_AC_37` | PASS | 1 | PairTokenCallbacks.t.sol |
| PT-AC-38 / `test_PT_AC_38` | PASS | 3 | PairTokenCallbacks.t.sol |
| PT-AC-39 / `test_PT_AC_39` | PASS | 3 | PairTokenCallbacks.t.sol |
| PT-AC-40 / `test_PT_AC_40` | PASS | 1 | PairTokenCallbacks.t.sol |
| PT-AC-41 / `test_PT_AC_41` | PASS | 2 | PairTokenCallbacks.t.sol |
| PT-AC-42 / `test_PT_AC_42` | PASS | 2 | PairTokenCallbacks.t.sol |
| PT-AC-43 / `test_PT_AC_43` | PASS | 1 | PairTokenCallbacks.t.sol |
| PT-AC-44 / `test_PT_AC_44` | PASS | 2 | PairTokenCallbacks.t.sol |
| PT-AC-45 / `test_PT_AC_45` | PASS | 1 | PairTokenCallbacks.t.sol |
| PT-AC-46 / `test_PT_AC_46` | PASS | 4 | PairTokenCallbacks.t.sol |
| PT-AC-47 / `test_PT_AC_47` | PASS | 2 | PairTokenCallbacks.t.sol |
| PT-AC-48 / `test_PT_AC_48` | PASS | 1 | PairTokenCallbacks.t.sol |
| PT-AC-49 / `test_PT_AC_49` | PASS | 3 | PairTokenCallbacks.t.sol |
| PT-AC-50 / `test_PT_AC_50` | PASS | 2 | PairTokenCallbacks.t.sol |
| PT-AC-51 / `test_PT_AC_51` | PASS | 2 | PairTokenCallbacks.t.sol |
| PT-AC-52 / `test_PT_AC_52` | PASS | 3 | PairTokenExit.t.sol |
| PT-AC-53 / `test_PT_AC_53` | PASS | 1 | PairTokenExit.t.sol |
| PT-AC-54 / `test_PT_AC_54` | PASS | 4 | PairTokenExit.t.sol |
| PT-AC-55 / `test_PT_AC_55` | PASS | 2 | PairTokenMath.t.sol |
| PT-AC-56 / `test_PT_AC_56` | PASS | 1 | PairTokenSurface.t.sol |
| PT-AC-57 / `test_PT_AC_57` | PASS | 5 | PairTokenExit.t.sol |
| PT-AC-58 / `test_PT_AC_58` | PASS | 1 | PairTokenIdentity.t.sol |
| PT-AC-59 / `test_PT_AC_59` | PASS | 2 | PairTokenEntry.t.sol |
| PT-AC-60 / `test_PT_AC_60` | PASS | 1 | PairTokenEntry.t.sol |
| PT-AC-61 / `test_PT_AC_61` | PASS | 1 | PairTokenEntry.t.sol |
| PT-AC-62 / `test_PT_AC_62` | PASS | 2 | PairTokenSurface.t.sol |
| PT-AC-63 / `test_PT_AC_63` | PASS | 1 | PairTokenEntry.t.sol |
| PT-AC-64 / `test_PT_AC_64` | PASS | 4 | PairTokenExit.t.sol |
| PT-AC-65 / `test_PT_AC_65` | PASS | 1 | PairTokenExit.t.sol |
| PT-AC-66 / `test_PT_AC_66` | PASS | 1 | PairTokenCallbacks.t.sol |
| PT-AC-67 / `test_PT_AC_67` | PASS | 1 | PairTokenCallbacks.t.sol |
| PT-AC-68 / `test_PT_AC_68` | PASS | 1 | PairTokenCallbacks.t.sol |

### Additional required tests

| Required test | Result | File |
| --- | --- | --- |
| `test_PT_MATH_md_mu` | PASS | PairTokenMath.t.sol |
| `test_PT_MATH_amounts` | PASS | PairTokenMath.t.sol |
| `test_PT_MATH_fit` | PASS | PairTokenMath.t.sol |
| `test_PT_MATH_tick_oracle` | PASS | PairTokenMath.t.sol |
| `test_PT_CONST_01` | PASS | PairTokenIdentity.t.sol |
| `test_PT_GET_all` | PASS | PairTokenIdentity.t.sol |
| `test_PT_API_mutability` | PASS | PairTokenIdentity.t.sol |
| `test_PT_VIEW_slots` | PASS | PairTokenSurface.t.sol |
| `test_PT_ERROR_selectors` | PASS | PairTokenIdentity.t.sol |
| `test_PT_ERROR_precedence` | PASS | PairTokenIdentity.t.sol |
| `test_PT_ABSENT_surface` | PASS | PairTokenIdentity.t.sol |
| `test_PT_GAS_forwarding` | PASS | PairTokenEntry.t.sol |
| `test_PT_INIT_negative_spacing` | PASS | PairTokenIdentity.t.sol |
| `test_PT_ZAP_equal_currencies` | PASS | PairTokenEntry.t.sol |
| `test_PT_EXIT_skip_add` | PASS | PairTokenExit.t.sol |

The extra payout forwarding variant, compiler encoding test, public manager
selector comparison, and supplemental scenario subcases also passed.

## Review notes and remaining limits

- `NotFactory` appears only in its declaration in production source. The ABI
  test verifies its declaration; execution alone cannot prove universal absence
  of a producing path. Source review supplies that bounded observation.
- Reservation, entered, and skip-add are ordinary private storage fields. No
  transient-storage operation or extra public state getter was introduced.
- The ABI artifact check covers the exact 34 named functions/getters, receiver,
  absence of fallback, tuple widths, mutability, return types, all declared error
  signatures, and five non-anonymous event schemas/indexing. Runtime tests cover
  error bytes, ordering, actual balances, finite allowances, rollback, and native
  recipient storage writes.
- Production LSP checks reported no errors for all three Solidity source files.
  Some test-file LSP requests timed out; solc compiled the complete test suite
  successfully. Python LSP was unavailable because basedpyright is not installed;
  the scripts were instead exercised directly and by the passing Foundry FFI tests.
- The existing root `fmt.skip` key produces an unknown-config-key warning under
  this Forge version. Repository configuration was not changed for it.
- Forge lint still reports `reentrancy-no-eth`, `reentrancy-eth`,
  `reentrancy-events`, `arbitrary-send-eth`, and `unused-return` on the
  prescribed interaction sequences. No warning was suppressed. The five public
  money-changing methods share the entered guard; share methods and callbacks
  remain deliberately outside it. Refund/payout gas forwarding, post-call event
  order, initializer-selected dependencies, and unused Add/settle return values
  are specified behavior (PT-PERM-01, PT-CB-01/06/07, PT-DEP-03/05, PT-BAL-05/06,
  PT-EVENT-03), not permission to add stronger restrictions. The tests exercise
  these boundaries; they do not establish safety of arbitrary external contracts.
- Only the requested hermetic baseline suite was run. The unrelated monorepo
  runtime suite and network forks were not run. No unresolved local scenario
  mismatch remains in this executed suite.
- Whole-system manager equivalence, factory-clone parity, live fee-manager
  behavior, hook safety, nonstandard-token safety, and legal clearance remain
  outside the local claim. No live outputs, default factory parameters, or
  independent pricing source were invented.

