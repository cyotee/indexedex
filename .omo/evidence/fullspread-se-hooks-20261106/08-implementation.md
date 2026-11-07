# Task 8 - dual component accounting

## Parent runtime receipt (2026-11-07)

The serialized full-family run in `08-dual.log` executed 576 cases: 563
passed and 13 failed. Twelve failures were superseded donation/floor
expectations; `08-donation-floor.log` records 17 passing targeted cases
after replacing those expectations with matched-control component accounting
and withdrawing protocol-owned LP before checking the locked floor.
`08-default-donation.log` records the remaining default donation case passing
after the same matched-control correction. Thus all 576 unique cases from
the full-family run have passing receipts. The original run also passed the
256-run, 16,384-call invariant campaign with zero reverts.

This is not task sign-off. Single-input paid internal swaps followed by
post-trade component acceptance remain a pending product interpretation.
The user did not answer the question before it timed out; silence does not
approve that interpretation. Cross-family surface, gas, size, acceptance,
and release gates also remain open.

Status: full family implementation and test sources ready for the parent's
serialized artifact build and runtime validation. Production is frozen at the
frontier below. This task ran no build or test, wrote no `out/` or
`cache_forge/` artifacts, and claims no runtime pass.

Authority: task 8 of
`docs/research/se-fullspread-remediation-plan-20261106/IMPLEMENTATION_AND_TEST_PLAN.md`,
the current FullSpread PRD FS-OWN-34 through FS-OWN-37 and FS-HOOK-05 through
FS-HOOK-10, and evidence notes 01, 03 and 05.

## Stable production frontier

All final production changes are these eleven files:

1. `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookRepo.sol`
2. `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol`
3. `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib.sol`
4. `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol`
5. `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDepositQuoteLib.sol`
6. `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDepositTarget.sol`
7. `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookInQuoteBase.sol`
8. `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawTarget.sol`
9. `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookHooksTarget.sol`
10. `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookSeTarget.sol`
11. `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookPullLib.sol`

The legacy aggregate `UniswapV4DualStandardExchangeBufferConstantProductHookTarget.sol`
has no final change. Its original inheritance order was retained and its final
LSP check reported no diagnostics. Installed facets continue to inherit the
family targets; the SE and native SY execution paths reach the same common
liquidity implementation. No selector was removed or added. The installed
`requiredFirstBondTokens()` metadata now reports the two bound SE shares in
currency order, matching actual genesis funding.

The existing linked ClaimLib, DepositQuoteLib and PullLib changed implementation,
not package configuration. ArtifactCreationCode remains the existing runtime
linking path. No new linked library, package field, live migration, shared
arithmetic helper, or universal hook engine was introduced.

## Implemented accounting

- Repo appends accepted SE-share books and the deployment registry address.
  Its existing local map now records paired-token inventory on buffered legs
  too. Existing storage positions, including the retired `kLast`, are retained.
  Physical ambient balances are never synchronized into either book.
- DFPkg records its existing `VAULT_REGISTRY_DEPLOYMENT` authority and rejects
  unknown underlying registrations. Disable checks query effective
  `isDisabled(se)`, including package disablement; query failures are not
  interpreted as enabled. Foreign/unregistered SE authorities remain an explicit
  integration limitation, rather than a fee-oracle fallback or new package field.
- Common accepts one gross LP fraction across S0/L0/S1/L1 using the shared
  full-width floor limits and ceil contribution helpers. It snapshots books
  untouched by funding, assembles only caller-owned inventory under the lock,
  accepts actual quantities, and returns both types of unused caller assets.
  Zero supported gross reverts without retaining caller assets.
- Pair-input assembly uses an ordinary forward quote to retain caller-owned
  local input before the selected SE deposit. Actual minted shares and input
  refunds control acceptance. Share-input assembly redeems only the caller's
  selected shares to assemble its local component. Later partial share refunds
  remain in the caller's available basket. There is no provider-valued ownership
  clamp or ambient dust reinvestment.
- Genesis requires preowned SE shares on both funded buffered legs, consumes
  exactly floor(A/20) on each, rejects zero/incomplete redemption or zero actual
  paired receipt, and books retained shares plus actual local proceeds. The
  geometric seed uses normalized retained share quantities. The 1,000 LP floor
  is allocated once, outside the configured mint-fee split.
- The fee recipient and WAD percentage still come from
  `dexSwapFeeAndFeeToOfVault(address(this))`. Fee LP is floor(gross*f/1e18);
  depositor LP is the remainder. Minima and previews use net LP. Growth issuance
  and projected growth-supply adjustments were removed. `kLast` remains a
  reserved, zero-valued installed getter.
- Withdrawals allocate each native component independently with floor(b*B/T),
  including locked and protocol LP in T. Both legs are debited and LP is burned
  before caller-only conversion. Pair payouts add allocated local tokens to
  actual redemption proceeds. Share payouts convert only allocated local tokens
  and reject a conversion that cannot deliver the requested share-only asset.
  Disabled share conversion fails atomically; permitted pair exits make no
  cleanup deposit.
- Cross-leg exits first remove the caller's basket, then trade its residual
  against the remaining books. The returned amount is explicitly tracked rather
  than inferred from an absolute balance containing existing local inventory.
- Swap reserves are local pair tokens plus provider-rated booked shares.
  Output plans record local payment separately from rounded SE-share spend;
  execution consumes local output first and reconciles actual conversion tuples
  and token deltas. Disabled input is booked locally without calling the SE mint.
  Local-only fixed output never invokes unavailable SE `exchangeOut`; deficit
  exact output retains the family's existing supported-operation requirements.
- All ERC20 and Permit2 pulls verify actual transfer deltas. Pretransfer credit
  subtracts both booked pair and share quantities. Receipt reconciliation
  verifies net input consumption, output deltas and refund bounds, then clears
  conversion approvals.
- Join books and LP mints are complete before refund callbacks. Published basic
  reserves are calculated before either reserve slot is updated. Public money
  previews and rated reserve queries reject during the operation lock, so a
  callback cannot obtain a usable partially completed accounting quote.

Dual's existing exact-net single-asset join and exact-token single-asset exit
rejections remain unchanged. Trading fees, CP curve, pool-manager checks,
deadline/minimum checks, token ordering, staged initialization and immutable
deployment topology remain in place.

## Family test frontier

Changed or added under
`test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/`:

- `TestBase_UniswapV4DualSEBCPHook.sol`
- `TestBase_UniswapV4DualSEBCPHook_Decimals.sol`
- `UniswapV4DualSEBCPHook_SeBufferAbi.t.sol`
- `UniswapV4DualSEBCPHook_Core.t.sol`
- `UniswapV4DualSEBCPHook_B6M3.t.sol`
- `decimals/UniswapV4DualSEBCPHook_Core_Decimals.sol`
- `UniswapV4DualSEBCPHook_ComponentAccounting.t.sol`
- `UniswapV4DualSEBCPHook_SeMatrixBehavior.sol`
- `UniswapV4DualSEBCPHook_Adversarial.t.sol`
- `decimals/UniswapV4DualSEBCPHook_Adversarial_Decimals.sol`
- `invariant/UniswapV4DualSEBCPHook_Invariant.t.sol`
- `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`
- `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpread_WithV3.t.sol`
- `UniswapV4DualSEBCPHook_SeMatrix_ERC4626StandardExchange.t.sol`
- `UniswapV4DualSEBCPHook_SeMatrix_RebasingAwareERC4626.t.sol`
- `UniswapV4DualSEBCPHook_ComponentAliases.t.sol` (new)

The shared fixtures, shared component behaviors, shared invariant handler, H2,
FullSpread vault sources, VT tests and configuration files were not edited.
Within the dual FullSpread row, the shared `FullSpreadV4MatrixChecks` library was
left intact; changes are in the owned dual test contract.

### Updated existing positive paths

Standard, decimal, matrix, hostile-token, shared-ABI, mixed V4/V3 and invariant
fixtures now acquire genuine SE shares before the Hook LP bootstrap. The
invariant fixture seeds before the unchanged handler captures initial supply.
Pair-only tests that exercise a later join are genuinely seeded, not converted
into expected reverts.

Superseded fee tests assert exact new gross/net/fee conservation and no mint
from yield alone. Reserve-view assertions include actual local inventory.
Existing exact-output debit assertions subtract local payment before consulting
the SE. Capacity assertions measure actual tokens forwarded to the SE, excluding
caller tokens retained locally by the hook. The prior invalid identity binding
in the rebasing-aware regression is replaced by a valid member-pair binding;
the unfunded/funded pretransfer protection is still exercised positively.

The real FullSpread exact-output rows now execute local-only true-flag and
false-flag calls successfully, including exact refunds/pulls and unchanged
underlying output shares. Their separate deficit cases continue to reject
unavailable FullSpread exact output. No failing positive became a revert test.

### Added concrete coverage

`ComponentAliases` uses registry-deployed hooks and real ERC4626 SEs to cover:

- all four flexible input and output flag combinations;
- proportional and reversed-order unbalanced joins and proportional exits;
- direct single input, one-leg unbalanced, SE and native SY pair/share joins;
- pair/share single-token exits through direct, SE and native SY selectors;
- all four Permit2 signature/allowance, dual/single paths with genuine signatures;
- native SY redemption of actual LP held by the hook;
- inactive fee, zero fee recipient, protocol LP withdrawal, and zero-refund swaps.

Multi-leg joins retain independent ceil-component assertions. Single-input
aliases do **not** compare acceptance to the pre-trade book. Their independent
oracle reconstructs actual token custody at `ZapSwap`, removes the caller's
pending kept input and received output, and uses that post-trade incumbent book
for ceil backing, non-dilution and limiting-component maximality. Gross/net/fee,
input/output receipts and exact sequential preview checks remain separate.
This follows the parent's correction to the shared exact-net oracle.

The real FullSpread component adapter additionally covers:

- real partial refunds credited once to pool local input;
- a real one-wei full refund with positive swap output from an imbalanced book;
- exact local equality, leaving a mixed zero-local component, followed by a
  positive proportional share join;
- disabled requested-share exit rollback followed by a positive pair exit;
- disabled pair-only join rejection and direct disabled-SE rejection;
- a zero-rounded second genesis redemption restoring the first leg;
- later-join minimum and deadline rollback;
- unfunded and short pretransfer against existing local backing;
- ambient SE shares excluded from a later join;
- actual two-vault execution in one outer unlock, a propagated outer failure,
  a caught inner failure followed by success, and cleared participant deltas.

The existing hostile-token tests also assert that nested accounting previews
reject with `Reentrancy()`. Existing independent negative suites remain in the
family test command.

## Static verification receipt

The final on-disk inspection compared 28 owned source/test files with the
intended source frontier: zero mismatches. This includes the unchanged aggregate.

Final LSP results:

- All eleven changed production files: `No diagnostics found`.
- Unchanged aggregate `UniswapV4DualStandardExchangeBufferConstantProductHookTarget.sol`:
  `No diagnostics found`.
- Fifteen of sixteen changed/new family test files: `No diagnostics found`.
- `UniswapV4DualSEBCPHook_SeMatrixBehavior.sol`:
  `Timed out waiting for fresh diagnostics ... within 3000ms.`

Earlier LSP reference requests timed out. Fresh diagnostics also exposed
misplaced insertion-only hunks; those placements were corrected and every owned
file was reconciled before this frontier was frozen. The aggregate required no
final inheritance change. Earlier errors are not reported as clean receipts;
the final results above supersede them.

LSP is not a build, deployed-code-size check or runtime receipt. No test success,
gas number, bytecode size, artifact freshness or release gate is claimed here.

## Parent-owned validation commands

Run from `/Users/cyotee/Projects/indexedex`, with no concurrent writer to `out/`
or `cache_forge/`. The helper supplies Solar and builds affected runtime artifacts
before deploying them in tests.

```bash
DUAL=contracts/hooks/uniswap/v4/standardExchange/dual
PREFIX=UniswapV4DualStandardExchangeBufferConstantProductHook
DUAL_SOURCES=(
  "$DUAL/${PREFIX}Repo.sol"
  "$DUAL/${PREFIX}DFPkg.sol"
  "$DUAL/${PREFIX}ClaimLib.sol"
  "$DUAL/${PREFIX}Common.sol"
  "$DUAL/${PREFIX}DepositQuoteLib.sol"
  "$DUAL/${PREFIX}DepositTarget.sol"
  "$DUAL/${PREFIX}InQuoteBase.sol"
  "$DUAL/${PREFIX}WithdrawTarget.sol"
  "$DUAL/${PREFIX}HooksTarget.sol"
  "$DUAL/${PREFIX}SeTarget.sol"
  "$DUAL/${PREFIX}PullLib.sol"
)
DUAL_TEST=test/foundry/spec/hooks/uniswap/v4/standardExchange/dual

python3 scripts/forge-artifacts.py test "${DUAL_SOURCES[@]}" \
  --test-root "$DUAL_TEST/UniswapV4DualSEBCPHook_ComponentAccounting.t.sol" \
  --test-root "$DUAL_TEST/UniswapV4DualSEBCPHook_ComponentAliases.t.sol" \
  --test-root "$DUAL_TEST/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol" \
  --test-root "$DUAL_TEST/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpread_WithV3.t.sol" \
  -- --isolate -vv

python3 scripts/forge-artifacts.py test "${DUAL_SOURCES[@]}" \
  --test-root "$DUAL_TEST" -- --isolate -vv
```

Record the actual parent receipts as `08-dual.log` and `08-dual-negative.log`,
or reference one complete run from both entries. Those receipts do not yet
exist as outputs of this task.

## Remaining validation risks and boundaries

1. Runtime parity, family-wide matrix behavior, linked facet/library sizes and
   the cold gas ceiling remain unverified until the parent's serialized run.
   The unresolved direct matrix-behavior LSP freshness timeout also needs that
   compiler receipt.
2. For an SE without optional sequential state quotes, composed previews use
   ordinary forward quotes; they do not fabricate a post-conversion SE state.
   Actual receipts and final net minima control execution. The conversion split
   is bounded and ownership-safe, not a claim of globally optimal conversion.
3. A share-only payout that cannot consume its allocated local component without
   returning a different asset rejects atomically. It never drops the local
   claim or silently returns an unrequested mixed basket.
4. Dual preserves its two positive-leg topology and swap share-spend guard.
   Artificial all-zero backing with outstanding supply is not manufactured by
   SUT storage injection; the shared arithmetic tests cover that impossible-mint
   boundary, and dual exercises a reachable zero-local component explicitly.
5. The ClaimLib still uses the existing H2 transition-support probe and rated
   arithmetic APIs. The parent owns that shared cross-family validation frontier.
   No addition to those APIs was needed or made here.

No commits, installs, live deployments, delegation, or unrelated workspace
edits were performed.
