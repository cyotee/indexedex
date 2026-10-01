# FullSpread G3 route/funding closure

## Additional exact predicates — pending parent validation

The parent's 16-green G3 checkpoint below is preserved. The acceptance
reconciler subsequently requested two additional predicates; each is now
implemented in the owned G3 helper and inherited by both ordinary family leaves:

- `test_unbalancedMultiJoinRetainsExcessBothFaces`: starts with a real deployed
  book, restores the same state for each dominant face, and supplies positive
  9:1 / 1:9 dual inputs during a real blocked-manager session. Independently
  computes `min(floor(S*C0/B0), floor(S*C1/B1))`, identifies material excess,
  and asserts exact quote/mint, supply/recipient shares, both payer debits,
  both local custody and total-backing additions, no refund, unchanged
  pool/position/fees, exact allowance consumption and full booking. Deliberate
  Multi excess is accepted under F0; no single-input F5 1 bp loss test is imposed.
- `test_SYMetadataAndGeometricExchangeRateExact`: checks LIQUIDITY asset type,
  PoolManager asset identifier, asset decimals 18, zero `yieldToken`, exact
  ordered input/output arrays, valid underlying/invalid self/native faces, and
  empty reward arrays with unchanged ledger. Checks empty rate `1e18` and exact
  idle/blocked rates for deployed balanced and then deliberately unequal books.
  Expected backing comes from ERC20 custody plus directly observed core
  position principal and inside-fee-growth entitlement; it does not use SUT
  quote snapshots, reserve getters or the production geometric-mean helper.
  A bounded test-side binary integer square root supplies
  `floor(floor(sqrt(B0*B1))*1e18/S)`. The excess-funded case must increase rate.

These add **four H/P instances**, bringing G3 to ten definitions / **20 instances**
across its four existing contracts. The family leaves only supply their PoolKey
to the independent observer; deployment fixtures and production are unchanged.
This extension ran no Forge/compiler, node or delegation. The four new instances
and the updated compilation remain unverified until the parent's serialized run;
the earlier 16-green result does not certify this extension. Aggregate family
counts elsewhere below describe their earlier checkpoints.

## Reconciled parent execution checkpoint — 2026-09-30

**G3's eight definitions / 16 H/P instances passed in the parent full-family
436-test run**, `tool_0f28e99a80017hutLncSKOzlpl`, with 128 fuzz runs for that
family selection, zero failures and zero skips. This supersedes the initial
6-pass/10-fail allowance checkpoint and the pending-rerun statements below.
The corrected allowance predicates and both natural-linear orientations are
present in the inspected source. This documentation task ran no tests.

The 436 checkpoint predates the later native DFPkg contents-ID correction and
test enhancements. Final combined validation is still pending; expected family
count is 450. G3 is a closed scoped implementation/predicate package, not a
standalone audit-readiness or retirement verdict. Its bounded fixture dimensions
are disclosures, not a requirement to instantiate an additional full Cartesian
product. See the reconciled acceptance map and draft readiness record.

The following sections preserve the earlier worker checkpoints chronologically.

## Scoped G3 status — 2026-09-30

**Parent checkpoint: compiled; 6 G3 passed / 10 G3 failed. Allowance-expectation
correction prepared; corrected source awaits parent compilation/execution.** The parent
owns the serialized compiler/artifact writer. This task ran no Forge, compiler,
LSP compilation, node, delegation or commit. It changes only the following new
files and does not update the acceptance map:

- `contracts/test/bases/TestBase_UniswapV4FullSpreadG3RouteFunding.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/RouteFundingClosure.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/RouteFundingClosure.t.sol`
- This scoped status file.

### Inspection and exact unresolved cells

The source inspection used the current PRD, implementation/test plan, context
addendum, acceptance map G3 and the existing family acceptance fixtures. Existing
assertions were retained as references rather than copied into new standalone
happy-path cases:

| Existing evidence in each family | Exact additional G3 assertion |
|---|---|
| `NestedAndConsumer::test_blockedDirectSwapAndTwoLegExactOutRejected` calls EO | Actual blocked **EI**, both directions, ordinary preview and atomic push/pull failure |
| `NestedAndConsumer::test_realOuterUnlockDualJoinAndF3Payout` joins after bootstrap | First-ever blocked dual activation, dead sink and zero position, then idle placement without another issuance |
| `NestedAndConsumer::test_blockedExactOutputRefundOnlyCallerCredit` covers token0 push | Both F1 faces, independent input reference, prior unprepaid quote and restored-state full-ledger push/pull comparison with exact funding-mode allowance adjustment |
| `OneBackedLeg` has a token0 natural linear positive | Both natural one-sided orientations with exact payout/burn, booked-share reserve and bounded-credit budget matrix |
| `FormulaDomains::test_idleF3ExactDualPayout` and the nested dual test cover pull | F3 idle/blocked push/pull budgets, equal-ceil reference, recipient and self-share custody |
| Existing F2/SY cover shortages | F3 isolates each local leg's shortage; quote and atomic pushed/pulled execution restore the full observed ledger |
| Existing canonical dual successes | Reversed, duplicate, nonpool, wrong share face, wrong amount length and each zero-leg vector; missing second pushed credit restores the first transfer |
| `EquivalentInterfaces` covers token0 external aliases and a token1 internal burn | Both faces, restored-state idle deposit/external redemption/internal redemption equality, distinct recipient and retained internal surplus |

### Exact new test cases

Both `HooklessRouteFundingClosureTest` and `PonsRouteFundingClosureTest` inherit:

1. `test_blockedDirectExactInputRejectsBothDirections`
2. `test_blockedFirstDualActivationThenIdlePlacement`
3. `test_blockedF1AtomicPushEqualsPullOnRestoredState`
4. `test_F3PushAndPullBudgetMatrix`
5. `test_F3EachLocalLegShortageRollsBack`
6. `test_multiMalformedVectorsAndMissingSecondCredit`
7. `test_idleSYAliasesBothFaces`

`HooklessLinearRouteFundingClosureTest` and
`PonsLinearRouteFundingClosureTest` each inherit:

8. `test_linearExactOutRefundMatrixBothOrientations`

This is **16 added test entrypoints across four concrete contracts**. The parent
checkpoint below executed all 16; matrix cases expand internally.

The F3 and linear matrices cover pull exact/fat maximum; push exact funding,
used-only funding under fat maximum, refundable excess, over-maximum delivery
with retained surplus, short delivery and short maximum. Short maximum is also
checked separately for pull. Each matrix starts with 31 genuinely transferred
and booked self-shares to distinguish caller credit from existing custody.

The rollback digest includes both asset-face quote snapshots, issued supply,
caller/recipient/vault/manager balances, durable token and self-share reserves,
ERC20 and Permit2 approvals, native vault balance and the P fee/tax ledger.
Success paths check exact supply/share effects, recipient payments, payer
debits, allowances, full local booking and relevant quotes. Blocked payouts
add exact free-inventory subtraction and unchanged position, pool and own fees.

The exact blocked R1 error is the existing
`UniswapV4Exchange_PoolManagerInteractionBlocked()` on EI preview and execution.
It is not the EO `InvalidRoute` error. F3/linear max, delivery and local-cover
negatives assert their exact existing error payloads.

### Parent checkpoint and allowance correction

Evidence: `/Users/cyotee/.local/share/opencode/tool-output/tool_0f26ab3a3001DPPOuSul0nxQod`.
Solc 0.8.35 compiled successfully. Both families passed blocked direct EI,
each-leg F3 shortage rollback, and malformed-vectors/missing-second-credit tests
(six passes). Each family's other five cases failed a max-uint allowance
assertion (ten failures). This is a failed checkpoint, not closure evidence.

The correction is limited to the G3 helper and this document:

- Crane `ERC20Repo._spendAllowance` subtracts the exact transfer amount even
  from `type(uint256).max`; it has no OpenZeppelin-style infinite exemption.
- Capture actual allowances immediately before each funded operation. Pull
  activation consumes each declared input; F1 pull consumes exactly quoted
  `used`, not its maximum; direct push consumes no payer allowance; share
  exits consume no underlying payer allowance.
- Idle SE/SY deposit aliases each consume exactly the selected `1e18` input.
  The snapshot is **after bootstrap and prior test cells**, and is restored
  before the alternate alias. Bootstrap expenditure is already reflected in
  that baseline and must neither be ignored nor subtracted a second time.
  External/internal redemption aliases consume no underlying payer allowance.
- F1 push and pull legitimately leave different payer allowances. Both are
  asserted exactly against their respective pre-call baseline. For full-ledger
  comparison only, the observed push allowance is reduced by the known `used`
  amount in the hash; no live allowance is changed. All other fields compare
  exactly. Rollback and SE/SY alias hashes remain unadjusted.
- Configured ERC20-to-Permit2 allowance and Permit2 amount/expiry/nonce are
  compared with actual pre-operation values, not assumed maxima. Current H/P
  ERC20 settlement calls `Currency.transfer` (ERC20 `transfer`) rather than
  Permit2 `transferFrom`, so their exact consumption in these operations is zero.
  Configuring Permit2 approvals does not itself imply a Permit2-funded route.
- All comparisons remain exact `assertEq`; no allowance `<=` relaxation or
  approval reset was introduced. The linear activation helper was split to
  keep the extra snapshot out of its basket-enumeration stack frame.

The corrected source has not been rerun by this worker. Later fixture/domain
failures may still have been masked by the original allowance assertions.

### Domains and remaining unverified work

- Family adapters reuse their existing real acceptance proxy/registry/manager
  fixtures; P retains real registered Pons hook behavior and pending fees/taxes.
- Linear tests use six-decimal tokens and real additional full-range pools at
  ticks -60/+60. Their exact-basket fixture extends the existing P one-sided
  fixture symmetrically; actual core trades and public maintenance create the
  one-backed-leg state. A nonzero opposite book fails the test explicitly.
- No idle token-to-exact-shares success, two-backed-leg exact-output inverse,
  mock SUT or EVM storage writes were introduced.
- **Parent still must recompile and execute all four corrected contracts.** In particular,
  verify non-viaIR stack/code generation, both reverse one-sided fixtures,
  Permit2 approval expectations, and exact error/rounding assertions. Source
  inspection is not a pass and does not close the acceptance-map readiness gate.
- The linear refund matrix intentionally exercises the supported **blocked**
  linear domain. Existing idle closed-placement positives remain the prior
  evidence; this addition does not claim an idle linear refund matrix.
- These bounded ERC20 fixtures do not certify the full native/mixed-decimal
  cross-product, all legacy E6 variants, idle failed-minimum retries, ordinary
  unauthorized SY callers, or other G1/G2/G4+ work. The main acceptance map and
  its broader retirement blockers remain authoritative.
