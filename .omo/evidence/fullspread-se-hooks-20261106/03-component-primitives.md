# Task 3 - shared component and refund-result primitives

Date: 2026-11-06.

Status: implementation and test sources ready for parent-owned validation. No build or test was run by this task. No runtime success is claimed. LSP returned `No diagnostics found` for each of the three changed production files and the new test file. A prior LSP references request timed out; direct caller/source inspection supplied the compatibility review.

Authority: current FullSpread PRD FS-HOOK-05 through FS-HOOK-10 and task 3 of `docs/research/se-fullspread-remediation-plan-20261106/IMPLEMENTATION_AND_TEST_PLAN.md`.

## Owned changes

- `contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol`: internal pure component, mint-fee, exact-net and bootstrap arithmetic.
- `contracts/utils/ExchangeInAmount.sol`: internal refund-preserving results, consumed-input/local-credit arithmetic, and actual-delta receipt reconciliation. Existing `previewOut` and `exchangeOut` remain unchanged.
- `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol`: internal refund-preserving ordinary/projected quote variants. Existing `deposit`, `redeem`, and `redeemReceived` signatures and output-only return contracts remain intact.
- `test/foundry/spec/hooks/uniswap/v4/libs/UniswapV4HookComponentAccounting.t.sol`: 19 tests, including five fuzz properties, against the production libraries.
- This evidence note.

`UniswapV4BufferHookLiquidityExecutionBase.sol` required no edit: it contains routing/minimum checks, not growth-fee supply projection. No LegLib, DFPkg, family, other test, interface, deployment metadata, or storage file was edited.

All new library entrypoints are internal. Existing ContextQuote public/external linkage remains, with no new linked library or package component. Family owners must integrate the new primitives in their own tasks.

## Exact APIs

All parameters below are in native units unless explicitly called `feeWad`. `Result` is `ExchangeInAmount.Result { uint256 amountOut; uint256 amountRefunded; }`; the refund is denominated in the input token.

### UniswapV4BufferHookLiquidityRouteLib

All functions are `internal pure`.

```solidity
componentContribution(uint256 grossLp, uint256 booked, uint256 supply)
    returns (uint256 required);
componentMintLimit(uint256 available, uint256 booked, uint256 supply)
    returns (uint256 limit);
maxComponentMint(uint256[] memory available, uint256[] memory booked, uint256 supply)
    returns (uint256 grossLp);
componentAllocation(uint256 burnedLp, uint256 booked, uint256 supply)
    returns (uint256 allocated);
splitMintFee(uint256 grossLp, uint256 feeWad, address feeTo, bool active)
    returns (uint256 netLp, uint256 feeLp);
grossForNet(uint256 netLp, uint256 feeWad, address feeTo, bool active)
    returns (uint256 grossLp);
genesisGross(uint256 seedSupply, uint256 lockedFloor)
    returns (uint256 grossLp);
bootstrapSplit(uint256 suppliedShares)
    returns (uint256 redeemShares, uint256 retainedShares);
bootstrapReceipt(
    uint256 suppliedShares, ExchangeInAmount.Result memory result,
    uint256 sharesBefore, uint256 sharesAfter, uint256 pairBefore, uint256 pairAfter
) returns (uint256 retainedShares, uint256 localPair);
```

Contribution uses full-width ceil; allocation and positive-component limits use full-width floor. Supply zero is rejected, including a zero component: genesis is a different branch. A zero component's scalar limit is `uint256.max`; the basket helper skips zero components and returns zero for empty/all-zero books. Zero available inventory on a positive component limits the common mint to zero. It never accepts or moves tokens.

Unrepresentable positive-component quotients and ceil overflow revert instead of wrapping or saturating. Consequently an oversized input basket whose individual quotient cannot fit uint256 is rejected even if another component would limit the eventual mint. Supply/book updates and their checked overflow remain family-owned.

Inactive/zero-recipient fees return the entire gross mint, without interpreting an unused fee percentage. Active fees require `feeWad <= 1e18`. An active 100% fee can split a gross mint into zero net plus the entire fee, but cannot satisfy positive exact-net output. `grossForNet` checks uint256 feasibility and forward-checks both its result and its predecessor. No FullSpread-specific cap is imported.

`genesisGross` takes total family seed supply before floor allocation. Do not call it on a family seed function's already-floor-subtracted result. Bootstrap computes `suppliedShares / 20`, rejects a zero spend, requires the full supplied shares to have been present, requires zero refunded shares and positive pair output, then reconciles exact share consumption/output deltas.

### ExchangeInAmount

```solidity
previewResult(IStandardExchangeIn exchange, IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
    internal view returns (Result memory result);
exchangeResult(
    IStandardExchangeIn exchange, IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut,
    uint256 minAmountOut, address recipient, bool pretransferred, uint256 deadline
) internal returns (Result memory result);
fromConsumedInput(uint256 supplied, uint256 consumed, uint256 output)
    internal pure returns (Result memory result);
consumedInput(uint256 supplied, uint256 refunded)
    internal pure returns (uint256 consumed);
localCredit(uint256 supplied, uint256 forwarded, uint256 refunded)
    internal pure returns (uint256 retainedInput);
requireReceipt(
    uint256 supplied, Result memory result,
    uint256 inputBefore, uint256 inputAfter, uint256 outputBefore, uint256 outputAfter
) internal pure returns (uint256 consumed);
```

`previewResult`/`exchangeResult` reject refunds larger than supplied input. They do not attribute custody or automatically inspect token balances. `localCredit` implements `supplied - forwarded + refunded`, validating forwarded/refunded bounds before arithmetic, and never adds output-token units.

`requireReceipt` expects distinct input/output tokens and same-holder snapshots taken after funding and before the exchange, then immediately after the exchange before payouts. Both input refund and output must belong to that snapshot holder. It checks enough input was present, exact net input consumption, and exact output delta. It is not a substitute for caller-attribution or operation locking.

### UniswapV4SeBufferHookContextQuoteLib

All additions are `internal view`.

```solidity
depositResult(address exchange, address pair, address holder, uint256 amount, address unavailableManager)
    returns (ExchangeInAmount.Result memory result, bytes memory next);
redeemResult(address exchange, address pair, address holder, uint256 shares, address unavailableManager)
    returns (ExchangeInAmount.Result memory result, bytes memory next);
redeemReceivedResult(address exchange, address pair, uint256 shares, address unavailableManager)
    returns (ExchangeInAmount.Result memory result);
```

Unsupported optional context uses ordinary `previewExchangeIn`, preserving both tuple words. Advertised context retains existing failure propagation and next-state handling. Projected exact-input quotes use the transition's consumed-input word to derive `supplied - consumed`; overconsumption reverts. The received-share variant retains the prior `ReceiveShares` transition. Zero/identity routes have zero refund.

## Test evidence and limits

The authored tests cover:

- T=7, components `[11,5,13]`, available `[5,2,8]`, limits `[3,2,4]`, gross=2, accepted `[4,2,4]`, refunded `[1,0,4]`.
- Independent bounded integer products for per-component backing, no incumbent dilution, common-mint maximality, and refunds.
- Independent base-2^128 decomposition for full-width floor/ceil and limit arithmetic, without calling the production mulDiv oracle.
- Separate-component burns and split-burn rounding that cannot increase total entitlement.
- Empty/all-zero/all-local books, zero supply, dimensions, zero mint, impossible quotients, and ceil overflow.
- Gross=100 at 2% gives net=98/fee=2; exact net=100 minimally requires gross=102; genesis floor excluded once; protocol LP receives its ordinary withdrawal fraction.
- Fee conservation, inverse minimality, inactive/zero-recipient behavior, 100% and uint256 feasibility boundaries.
- 5% share rounding at 20, 101 and uint256.max; ambient custody excluded from seeds; partial/zero/short receipts rejected.
- Input-forward/refund conservation without double-counting; short funding and inconsistent balance deltas rejected.
- Existing one-word helpers, new execution/preview tuples, ordinary fallback, projected refunds and next-state compatibility.

The test contract provides a controlled non-SUT external SE dependency for tuple plumbing only. Those tests do not prove live token settlement, real SE deployment, family integration, lock safety or package linkage. Family tasks own those production-first tests.

No unresolved product decision remains in this task. Integration preconditions: adapters provide actual caller-owned quantities, pre-intake supply/books, valid distinct-token snapshots, existing fee activation/recipient, and the family's seed function. Optional transition implementations must report consumed input in `quoteTransition`'s second word. Normal FullSpread fallback requires no transition interface. Out-of-range scalar quotients fail closed as documented above.

## Parent validation request

Ready for the parent's serialized build/test window. Sources are frozen from this handoff until a failure requires a coordinated change. Please run:

```sh
python3 scripts/forge-artifacts.py test \
  contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol \
  contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol \
  contracts/utils/ExchangeInAmount.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/libs/UniswapV4HookComponentAccounting.t.sol \
  -- --isolate -vv
```

The helper supplies Solar and builds affected artifacts before tests. The broad reverse closure of shared helpers is expected; the parent may combine these three source arguments and this exact test root with its coordinated task-02 validation. Capture the happy-path output in `03-components.log` and boundary assertions in `03-component-boundaries.log`, or reference one complete run from both ledger entries. No such logs are asserted to exist yet.
