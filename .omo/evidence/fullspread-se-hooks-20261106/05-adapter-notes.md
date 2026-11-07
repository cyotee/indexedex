# Task 5 concrete adapter source frontier

Date: 2026-11-06.

This contribution adds six adapters only. The parent owns
`HookComponentAccountingBehavior.sol`, the H2 adapter, and serialized artifact
builds/test execution. No production, shared fixture, shared behavior, or existing
test files were edited. No builds, tests, Git operations, installs, or delegation
were performed. Runtime red-before/green-after evidence is not claimed.

## Added adapters

All Solidity paths below are relative to
`test/foundry/spec/hooks/uniswap/v4/standardExchange/`.

| Family | Added file | Behavior |
| --- | --- | --- |
| H1 | `single/UniswapV4SingleSEBufferHook_ComponentAccounting.t.sol` | `HookComponentCustodyBehavior` only |
| H3 | `dual/UniswapV4DualSEBCPHook_ComponentAccounting.t.sol` | `HookComponentAccountingBehavior` |
| H4 | `orbital/UniswapV4StandardExchangeOrbitalBufferHook_ComponentAccounting.t.sol` | `HookComponentAccountingBehavior` |
| H5 | `weighted/UniswapV4StandardExchangeWeightedBufferHook_ComponentAccounting.t.sol` | `HookExactNetComponentAccountingBehavior` |
| H6 | `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_ComponentAccounting.t.sol` | `HookExactNetComponentAccountingBehavior` |
| H7 | `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_ComponentAccounting.t.sol` | `HookExactNetComponentAccountingBehavior` |

Each adapter inherits its migrated real FullSpread matrix row. Funding mints
only fixture underlying tokens; buffered-share funding calls the fixture's
`acquireShares`, which executes the actual FullSpread vault. No SE shares or LP
balances are injected.

H3 uses `depositFlexible` for share joins, `deposit` for pair joins, and
`withdraw` for pair exits. H4 uses `depositFlexible`, `addLiquidity`, and
`removeLiquidity`. H5/H6 use their installed proportional flexible selectors;
H7 uses the installed `IUniswapV4BalancerStableLiquidityUnits` selectors, including
its actual runtime-length arrays rather than the old fixed-four helpers.

All LP adapters trade through the real hook's `IStandardExchangeIn.exchangeIn`.
The shared behavior receives primary buffered leg at index 0 and counter leg at
index 1. Dual converts canonical amounts to currency order. Weighted, Curve,
and Balancer map the complete token/SE records and corresponding amounts/flags
between canonical behavior order and native family order, preserving every
remaining leg. Orbital keeps its explicit three-record order.

H3 fees use the existing dex-swap-fee configuration helper. H4-H7 use the
existing usage-fee helper. Fee recipients are read from the actual hook's
`feeTo`. Disable tests call the IndexedEx manager's address/package switches;
the package address is read before arming the owner prank. Shared-family
assertions retain the 1,000 locked floor.

## Exact errors and unsupported routes

| Family | LP minimum error | Initial pair-funded buffered genesis error | Exact-net disposition |
| --- | --- | --- | --- |
| H1 | No LP API | No LP genesis | Structurally inapplicable; no LP behavior inherited |
| H3 | `InsufficientLpOut()` | `InvalidRoute()` | Deliberately unsupported |
| H4 | `InsufficientSharesOut()` | `InvalidRoute(address,address)` | Deliberately unsupported |
| H5 | `Slippage()` | `InvalidRoute(address,address)` | Positive test through raw counter leg |
| H6 | `Slippage()` | `InvalidRoute()` | Positive test through raw counter leg |
| H7 | `Slippage()` | `InvalidRoute()` | Positive test through raw counter leg |

Minimum signatures follow the actual family Common/Target declarations.
Initial pair-funded genesis rejection is the new positive accounting contract's
negative boundary, not an expectation that ordinary funded share joins fail.

H3's `UniswapV4DualStandardExchangeBufferConstantProductHookDepositTarget.sol`
deliberately reverts `InvalidRoute()` from `joinSingleAssetExactOut` and returns
zero from its preview. H4's
`UniswapV4StandardExchangeOrbitalBufferHookDepositCore.sol` similarly reverts
`InvalidRoute(tokenIn,address(0))` and returns zero. Each adapter adds
`test_HB47_exactNetRejectedAndRollsBack`: an exact error assertion plus a complete
shared component/supply/caller/allowance snapshot comparison. Neither inherits
the positive exact-net extension or returns early from a passing LP test.

H5-H7 size the requested net LP using a forward exact-input quote for a 1 ether
raw-token caller budget, then execute the installed exact-net selector with
that maximum. They do not call FullSpread's unavailable `previewExchangeOut`.
Existing positive exact-net execution contracts are preserved; their fee and
component correctness remains a positive assertion, not an expected revert.
H2's parent-owned forward-budget adapter was left untouched.

## H1 conversion and custody assertions

H1 retains the inherited real wrap/unwrap and refund cases and adds:

- A real wrap and unwrap with ambient pair/share custody; actual caller
  receipts, share mint/burn, retained mint refund, and unchanged unrelated hook
  balances are reconciled.
- Address-disabled and package-disabled positive share redemptions, checking
  actual paired-token receipt and share burn without cleanup deposits.
- Atomic failure of disabled wrapping with custody and allowance rollback,
  followed by successful share delivery after re-enable.

There is no synthetic Hook LP, LP test exclusion by early return, or invented
exact-output support.

## Static check and parent validation command

The Solidity LSP was checked on each of the six new files after the final
Solidity edit. Each returned `No diagnostics found`. This is static evidence
only; no compiler exit code or test count exists for this contribution.
The parent can run, after its serialized artifact preparation:

```sh
forge test --use solar --isolate \
  --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/**/*_ComponentAccounting.t.sol' -vv
```

This command includes the parent-owned H2 adapter. Production source changes
must receive the parent's artifact-first build before execution. Old accounting
is expected to fail the positive ownership, fee-split, bootstrap, local-first,
and disablement obligations until the family implementation tasks land.

No shared API addition was required. The six adapter sources are ready for the
parent's stable-frontier validation; this contribution makes no runtime pass
claim and performs no additional source changes beyond that frontier.
