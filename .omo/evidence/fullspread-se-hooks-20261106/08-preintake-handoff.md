# Task 8 - DUAL CP strict pre-intake source handoff

Date: 2026-11-07.

Source handoff only. No build, test, artifact writer, Git operation, install,
deployment, delegation, or memory operation was run. Parent owns artifact
refresh, compilation, runtime validation, size/gas checks, and task sign-off.
Earlier task-8 runtime receipts do not validate these new source changes.

## Authority and selected semantics

Read the repository router, assistant coding/deployment/testing rules, task 8
of `docs/research/se-fullspread-remediation-plan-20261106/IMPLEMENTATION_AND_TEST_PLAN.md`,
and the authoritative FullSpread PRD FS-HOOK-05 through FS-HOOK-10.
The explicit assignment selects the literal pre-intake snapshot and caller-only
assembly after the owner's clarification timed out. Silence was not treated
as approval of the former internal-swap interpretation.

For existing supply, `_joinComponents` reads T and S0/L0/S1/L1 before any
assembly, acceptance, or mint. Custody pulls do not credit these books.
An omitted leg with any positive incumbent component rejects with
`InsufficientLpOut()` before SE conversion. Positive supplied legs assemble
only their own caller-owned shares and local tokens. Forward pair conversion
may retain input, receive an SE refund, and redeem some of that operation's
new shares if actual local receipts need supplementing. No incumbent share
or local component funds this assembly.

The gross LP limit remains the minimum supported fraction over every positive
component, followed by ceil(gross * component / T) acceptance. Zero components
are not denominators. An entirely absent zero-book leg is allowed through the
existing-supply component engine; genesis still requires both positive legs.
Share inputs are no longer fully unwrapped before entering that engine.
Unused caller shares/local tokens remain outside the book and are refunded
by the existing post-acceptance settlement.

Single-input joins no longer execute a paid trade against the incumbent book.
If the other leg has positive components, their previews return zero without
SE conversion or rated-reserve evaluation. `previewZapSplit` reports no trade
and retains the declared input; this does not promise an acceptable LP basket.
Single-input eligibility uses outstanding supply above the locked floor,
rather than requiring both legs to be nonzero, so zero-book requirements do
not become an unconditional route rejection.

The fee split, share-funded genesis/actual 5% redemption, multi-input flag
combinations, proportional component exits, and actual CP swap engine were
retained. The quote library's `_swap` remains for single-asset exits, not joins.
No selector, interface, package configuration, or shared library was changed.

## Installed route inspection

- DepositFacet: ordinary/flexible/proportional joins and dual ERC20/Permit2
  inputs reach `_joinComponents`. Single ERC20/Permit2 inputs reach
  `_depositSingle`, which now delegates directly to that component engine.
- One-leg `joinUnbalanced` preserves whether the caller supplied a pair token
  or SE share. Its preview no longer has an unwrap-and-zap fallback.
- SE `exchangeIn(..., hook, ...)`, `joinSingleAssetExactIn`, and Native SY
  `deposit` reach `_joinLiquidityExactIn` and then the same single-input core.
  The shared pretransfer rejection remains unchanged.
- The installed SE facet has owner swap entrypoints, but no separate
  owner-only join implementation. An owner using a public join uses the
  same component core. Owner swaps and ordinary swaps were not rewritten.
- Unsupported exact-net single-asset joins remain unsupported; their
  selectors and zero previews were not replaced or fabricated.

## Changed paths in this follow-up

Production:

1. `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol`
2. `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDepositQuoteLib.sol`
3. `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDepositTarget.sol`
4. `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookInExecutionBase.sol`
5. `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookInQuoteBase.sol`

Tests:

1. `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol`
2. `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_ComponentAliases.t.sol`
3. `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_Core.t.sol`
4. `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeBufferAbi.t.sol`
5. `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol`

Evidence: this file only.

## Exact test changes for parent validation

- Core:
  `test_Z1_depositSingle_missingPreIntakeLeg_reverts` replaces the incumbent
  zap positive. It requires zero LP preview, zero trade split, exact
  `InsufficientLpOut()` and byte-equal rollback state.
- SeBufferAbi:
  `test_T5_3_afterLive_joinSingleAsset_pairAndShareRejectMissingLeg`
  replaces the pair/share single-join positive with zero previews, exact
  rejection, and byte-equal rollback for each supplied asset type.
  The pre-live `NotLive()` and first-full-book negative retain their errors.
- ComponentAliases:
  `test_H3_singleInputSeAndNativeSyAliasesRejectMissingLeg` replaces the
  eight-route join positive. Pair/share inputs through installed single,
  unbalanced, SE and SY routes require zero join/SE/SY previews, exact
  rejection and byte-equal rollback.
- ComponentAliases:
  `test_H3_singleAssetExitAliasesStillPayAllocatedBasket` retains the former
  positive exit assertions, funded by a valid complete bootstrap instead
  of the now-invalid single-input join. All six combinations of pair/share
  output and direct/SE/SY exit still require positive actual receipt,
  exact preview equality, and no new fee LP.
- ComponentAliases:
  `test_H3_permit2MultiInputMintsAndSingleInputRollsBack` retains both
  positive dual-input Permit2 issuance paths and their exact four-component
  contribution/fee checks. Both single-input Permit2 paths instead require
  exact rejection and rollback, including the signature nonce bitmap and
  finite Permit2 allowance/expiration/nonce.
- SeMatrixBehavior:
  `test_row_partialConsumption_bookedNotRefunded` retains its real
  partial-consumption branch. Its no-partial-case helper
  `_roundingToZeroControl` now checks the missing-leg rejection, not the
  superseded zap's rounding error. It asserts exact revert bytes and
  byte-equal rollback in addition to the existing caller/hook/book checks.

The shared rollback helper records token/share and fixture-vault ERC20
supplies, caller/hook/SE/vault custody, caller approvals and conversion
approvals, LP supply/caller/fee/hook/locked-floor balances, published
reserves, and both leg claim supplies. Assertions run before any snapshot
restore. The previous post-trade-boundary assertion helper was removed
because that boundary is no longer an authorized join snapshot.

The existing four flexible-input/output combinations, proportional and
two-input unbalanced positives, inactive-fee cases, vault-held SY exit,
protocol-LP withdrawal, and actual swap tests were not changed to rejects.
The original FullSpread swap-positive row files and
`test_H3_exactLocalEqualityLeavesMixedZeroComponent` were not edited.

## Static evidence and limitations

LSP diagnostics with severity `all` returned `No diagnostics found` for
each of the ten changed Solidity files. Source inspection confirmed direct
share forwarding and no join call to `_unwrap`, `_executeZapSwap`,
`_computeSaleAmt`, or `_proportionalAddAfterZap`. The latter three Common
helpers were removed. The unused historical math function and public
`ZapSwap` event declaration remain; neither is a join execution path.

These are static observations, not compile or runtime receipts. In particular,
the new rollback assertions and retained positives have not been executed.
No claim is made about runtime size, gas, full-family pass counts, or
cross-family acceptance.

The known advertised `IDetfReserveQuote` methods missing from the installed
implementation remain a separate parent audit issue. This change neither
implements them nor removes their interfaces or tests. Parent-owned
`HookComponentAccountingBehavior` was not edited. No other family, shared
behavior/library, PRD, plan, or configuration file was edited.
