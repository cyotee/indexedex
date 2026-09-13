# CP deposit facet size remediation

Packaging change under `docs/CONTRACT_SIZE_REDUCTION_PRD.md`, 2026-09-05. Compile/runtime validation belongs to the parent; this reviewer ran no Forge commands.

| Component | Prior runtime | Current runtime | Selectors |
| --- | ---: | --- | ---: |
| `UniswapV4SingleStandardExchangeBufferConstantProductHookDepositFacet` | 31,506 bytes (parent measurement) | Pending compile | 6 |
| `UniswapV4SingleStandardExchangeBufferConstantProductHookDepositSingleFacet` | New | Pending compile | 5 |
| `UniswapV4SingleStandardExchangeBufferConstantProductHookDepositPreviewFacet` | New | Pending compile | 8 |

The old combined `DepositTarget` was partitioned into three sibling Targets. They inherit `UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon`, which contains only internal functions and existing shared modifiers; there is no inherited public/external deposit or preview dispatcher to emit in every sibling. Shared helpers are unchanged except making previously unrouted public getters internal. Preview self-calls use the unchanged diamond interface explicitly. Original bodies, storage layout, caller context, guard ordering, pre-intake fee accrual, the exact-out preview-before-accrual fix, and post-operation kLast behavior are preserved.

The package interface gains `depositSingleFacet` and `depositPreviewFacet` in `PkgInit` and corresponding immutable getters. Both fields are nonzero-validated. Production cuts grow from six to eight; staged finalization removes the bootstrap facet and installs all eight. Bootstrap cuts, product identity, PkgArgs, mining, registry deployment, and final immutability are unchanged. This changes package constructor encoding; deploy scripts and TestBase constructors were updated together.

The CP FactoryService directly imports and CREATE3-deploys both new components using `type(...).creationCode`, matching the existing linked-library facet deployment pattern. Component compilation does not depend on test imports. DFPkg artifact loading remains unchanged.

CP-only construction wiring was updated in both CP TestBases, the universal/decimal/orbital/PonsV2 SE TestBases, the two local liquid-buffer tests, the two Quad composition tests, Robinhood main/testnet CP package stages, and the fee-DETF package script. Cross-family files contain only additions of the two CP `PkgInit` facet fields; no universal DETF or claim production logic was edited.

Validation additions in the existing CP Surface suite cover interface-derived Crane `Behavior_IFacet` declarations for all three components, the disjoint 19-selector union, every selector's deployed loupe routing, and each component's actual runtime length against 24,576 bytes. StagedInit checks now expect eight production adds and verify the two new selector cuts. SeBufferAbi imports the common error declarations after extraction. Static checks confirmed the 6/5/8 partition, an internal-only common, complete identified CP struct-literal wiring, and clean whitespace.

Required parent validation: compile all affected factories/package constructors, measure all three runtimes, and run the CP Surface/StagedInit/FeeCapital/SwapReentrancy/Liquidity/Permit2/SeBufferAbi suites and selected universal CP deployment/lifecycle coverage. Until those pass, deployability and behavioral preservation remain unverified.

Focused matcher: `^UniswapV4SingleStandardExchangeBufferConstantProductHook_(Surface|StagedInit|FeeCapital|SwapReentrancy|Liquidity|Permit2|SeBufferAbi)(_Test)?$` (check exact suite names when composing the full run).
