# CP-single owned test migration source frontier

Date: 2026-11-07.

Status: the nine directly owned suites below are migrated and frozen for the
parent's serialized artifact build/test pass. This is a source handoff, not a
runtime-green receipt. The two allowed decimal leaf files remain unchanged
because their failing tests are inherited from an excluded, non-virtual shared
suite; that ownership blocker is detailed below.

## Authority and inputs

- Execution authority is the user-requested
  `docs/research/se-fullspread-remediation-plan-20261106/IMPLEMENTATION_AND_TEST_PLAN.md`
  and the PRD below. The worker also consulted
  `.omo/plans/fullspread-se-hooks-implementation-testing-20261106.md` as context;
  that separate plan does not override the requested artifact.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`,
  FS-HOOK-05 through FS-HOOK-10.
- `CLAUDE.md`, `.github/ASSISTANT_RULES.md`, its coding/deployment/testing
  documents, and the IndexedEx/Crane testing, code-style and adversarial rules.
- `07-implementation-progress.md` and `07-cp-single.log` in this directory.
- Installed split-target routing, ClaimLib `_singleTrade`, `_accepted`,
  `singleComponentJoin`, `singleComponentExit`, and the actual fee-manager and
  fee-query interfaces. The old aggregate Target is not a runtime oracle.

## Changed paths

All test paths have this prefix:

`test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/`

1. `UniswapV4SingleStandardExchangeBufferConstantProductHook_SeBufferAbi.t.sol`
2. `UniswapV4SingleStandardExchangeBufferConstantProductHook_OwnerDuringLock.t.sol`
3. `UniswapV4SingleStandardExchangeBufferConstantProductHook_OwnerOnlyLiquidity.t.sol`
4. `UniswapV4SingleStandardExchangeBufferConstantProductHook_Fees.t.sol`
5. `UniswapV4SingleStandardExchangeBufferConstantProductHook_FeeCapital.t.sol`
6. `UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol`
7. `UniswapV4SingleStandardExchangeBufferConstantProductHook_Liquidity.t.sol`
8. `UniswapV4SingleStandardExchangeBufferConstantProductHook_Adversarial.t.sol`
9. `UniswapV4SingleStandardExchangeBufferConstantProductHook_ZapReserveOrder.t.sol`

The only additional write is this evidence file:
`.omo/evidence/fullspread-se-hooks-20261106/07-test-migration.md`.

No production, TestBase, Deploy/Swap, SeMatrix, shared behavior, invariant,
other-family or configuration file was edited. Existing edits were preserved.

## Migrated expectations

- Explicit owner and hostile-token seeds first acquire real SE shares, approve
  them and call the installed `depositWithSeShares`. ABI setup uses the same
  selector. The generic pair-funded genesis case now asserts `InvalidRoute`
  and unchanged caller funding/supply, then proves a valid share-funded seed.
- The ordinary/share liquidity suites independently check native raw/share/local
  ceil contributions against actual gross supply growth. Pair exits independently
  floor each component and redeem only the allocated shares. Share exits convert
  only the floored local claim, preserving remaining holders' native components.
  Genesis checks retained shares and the actual 5% redemption quote/receipt.
- Only-floor guard cases remove both depositor and treasury LP before expecting
  supply 1000. The subsequent-mint case instead explicitly retains treasury LP
  and includes it in remaining supply.
- Fees are exactly `floor(gross * f / 1e18)` and depositor net is gross minus fee.
  Ordinary, share, generic, Permit2 and single-input entries retain exact
  preview/execution checks. Larger backed deposits pay larger fees after the same
  yield state. Yield alone issues nothing and withdrawals only burn.
- Inactive fee coverage clears every actual fallback tier; zero-recipient coverage
  uses the real `IVaultFeeOracleManager.setFeeTo(IFeeCollectorProxy)` interface.
  Positive exact-net coverage checks the minimal integer gross inverse, input
  maximum, fee split, and infeasibility before funding at an active 100% fee.
- Residual cases no longer require ambient sweeps. Zero-quoted and independently
  overflowing ambient transfers remain outside the operation's native local
  change. Exact zero-call expectations prohibit quoting those ambient amounts.
  Failed join/exit minima retain full rollback assertions, including protocol LP.
- Adversarial I1/I3 witnesses now use genuinely booked assets. A real join replaces
  the old donation-then-assumed-sync exact-output setup. The recurrence witness
  consumes a real contract-wallet exact-input pretransfer before rejecting a second
  free credit with the original exact error. Positive booked local pair inventory
  is explicitly present in the pair-side I1 case. Donation checks snapshot after
  the donor's SE acquisition, separating its conversion-rate dilution from the
  subsequent ambient share transfer.
- ZapReserveOrder independently sizes the CP trade using the existing pure curve
  math, then derives purchased native components, post-trade books, component
  limits, ceil acceptance, refunds and mint-fee split. It does not use a hook
  preview or observed event output as the expected component oracle. It tests both
  currency orders and both input directions, plus four independent single-token
  exits that floor allocations before trading against remaining backing.
  `ZapSwap`'s buffered counter is the pair-unit value of purchased native
  components, not a promised underlying liquidation. This fixture explicitly
  disables SE conversion fees and verifies its one-to-one native value; ordinary
  fee-bearing conversion cases remain separate from ownership arithmetic.

Original test names remain where their meaning survives. FeeCapital growth/no-fee
names and ambient-quote-panic names were renamed where their old wording would
describe the opposite requirement. No test was skipped or deleted.

## Remaining classifications

### Ownership blocker: shared decimal tests

The allowed leaves
`decimals/UniswapV4SingleStandardExchangeBufferConstantProductHook_P6_R18.t.sol`
and
`decimals/UniswapV4SingleStandardExchangeBufferConstantProductHook_P9_R18.t.sol`
only inherit
`decimals/UniswapV4SingleStandardExchangeBufferConstantProductHook_Decimals.sol`.
That shared file is outside the allowlist and its `test_*` methods are not
virtual. Solidity cannot override those failing methods in the leaf files.
Replacing inheritance would duplicate or remove the shared suite rather than
migrate it. No such workaround was made.

The supplied log has 12 failures in each leaf: native-local-as-dust assumptions
in P1/P3/W1/B6/Zi1/Zo1/SE1, the hostile pair-funded genesis, the retired growth
checkpoint, and the donation check conflating SE acquisition dilution with the
later ambient transfer. These are classified test migrations, not evidence that
the component implementation violates the new ownership contract. Parent needs
to own that shared-file migration or explicitly extend the allowed touch set.
The blocker was sent to the parent session.

Parent resolution: the shared decimal suite has now been migrated under parent
ownership. Its positive single-input calls execute without catch/early-return
escapes; native ceil/floor component, fee, custody and hostile-callback assertions
are retained. Both decimal leaves passed in `07-cp-single-r2.log`.

### Production concerns and parent-owned failures

No new production defect is established by this static migration. It cannot
exclude runtime defects: no build or test was run. Keep exact component,
refund, fee, event and rollback assertions as failing witnesses if the parent's
run exposes a mismatch; do not relax them to obtain a pass.

The supplied full-suite failures in SeMatrix/shared behavior, D60, APEX008,
under-consumption and invariant/lifecycle files are outside this touch set and
are not resolved by this handoff. In particular, an existing booked local
balance is not a stranded user prepayment or free dust. The under-consumption
`TransferFromFailed` remains unclassified here; parent must trace its actual
funding/receipt path rather than infer an implementation defect from that error
alone.

## Verification and commands

- Source inspection used read/grep/glob and actual installed source interfaces.
- Final native LSP requests used `severity: all` on all nine changed Solidity
  files: every result was `No diagnostics found`.
- Both unchanged decimal leaves also received clean LSP diagnostics. That only
  addresses source diagnostics, not their inherited runtime expectations.
- No shell commands, builds, tests, artifact/cache writes, commits, installs,
  deploys or delegation were performed.

Parent-only runtime command, **not executed here**, after the parent's current
artifact build and shared-decimal migration:

```sh
forge test --use solar --isolate --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/**' -vv
```

Use the parent's artifact-helper closure before that command so the installed
facets are not stale. This note does not update the prior checkpoint or claim
that the 359-pass/189-fail baseline has changed.
