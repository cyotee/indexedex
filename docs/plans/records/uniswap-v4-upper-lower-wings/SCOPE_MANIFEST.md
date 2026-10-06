# Execution scope

Product prefix: `UniswapV4UpperLowerWingsStandardExchangeVault`.

Authorized production root: `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`.
Authorized tests: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`.
Evidence: this directory.

The initial checkpoint covered policy-independent geometry, position inventory arithmetic and test-local accounting references. PRD v0.4 resolves the owner policy questions and authorizes continued work in the original planned roots. Real PoolManager reference harnesses under T/reference are now selected for valuation/invariant verification. No issuance policy, fee constant, deployment parameter, live money route or public package is inferred from an unresolved proposal. Package identity and custody storage must wait for the immutable policy fields to be ratified; the generic manager registry path will be inspected before requesting shared-code changes.

All existing shared production, restored protocol-tree sources, FullSpread/Pons families, manager/registry, fee oracle, rate providers, configuration and consumer tests remain read-only. Consumer fixture edits must be listed here by concrete path before implementation. No consumer edits are presently selected.

No deployment, migration, commit or push is part of this execution checkpoint. Preserve the existing index. The new helpers have no external ABI or storage and are not a deployed package.

## Owner-ruling continuation

- PRD and plan top-level precedence updated to v0.4 O1–O6; these edits are authorized by the owner's corrective instructions.
- New W `UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol`: effective oracle-sourced sleeve arithmetic only, no new money ABI.
- New T `UniswapV4UpperLowerWingsStandardExchangeVaultSleeve.t.sol`: actual IndexedEx manager/fee-oracle tests.
- New T `UniswapV4UpperLowerWingsStandardExchangeVaultRecoveryValue.t.sol` and T/reference `UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor.sol`: actual PoolManager portfolio-state witnesses and recovery controls; not replacement vault implementations.
- Accounting reference bootstrap witness updated to owner-directed first-depositor residual benefit.
- No existing shared production, registry, oracle, FullSpread/Pons or restored family code edited.

## Continued implementation (owner instruction: finish all tests)

W now includes immutable DFPkg identity, storage, query facet, authenticated callback,
bounded liquidation quote, shared harvest projection and target-only money orchestration.
The family-local Money library is split out to keep facets small and share exact orchestration
between scalar routes. All package tests deploy through the existing IndexedEx registry;
all facets and linked libraries use CREATE3 runtime artifacts. No shared production amendment.
The selected production TestBase lives at W/test/bases/TestBase_UniswapV4UpperLowerWingsStandardExchangeVault.sol.
New T suites: LiquidationQuote, Deployment, Harvest, Money. These are implementation work;
the original helper-only checkpoint descriptions above are historical, not current completion claims.

The family-local linked Money and Harvest libraries, exact-output Out facet, native SY
facet, RebalancePlanner and Rebalance facet are selected under W. These do not alter any
shared protocol or consumer code. Native SY delegates to installed standard routes.

## Sequential quotes and consumer fixture selection

Additional W components: Projection linked library, TransitionTarget/Facet,
EconomicFacet and its Economic interface; the liquidation library exposes linked
projected traversal entrypoints. Full Q128 growth is carried in the shared
Harvest portfolio. New family tests include Transition, Security, Tokens,
Invariant and WeightedConsumer. Hostile tokens and an invariant handler are
non-SUT test actors; all vaults and dependencies are production deployments.

The exact selected consumer fixture is
`test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultWeightedConsumer.t.sol`.
It imports the unchanged production weighted package and its canonical test
DeployLib. No existing consumer source or test has been edited. Initial cells
are two-token masks 1, 2, 3, same/different PoolManager, opposite targets on the
same Wings PoolKey, asymmetric weights and 6/18 token decimals. This initial
fixture is explicitly not the exhaustive Phase 8 matrix.
`family-suite-after-sec08.log` later passed that fixture plus alternating
arities 3-7 and homogeneous eight. Those passes do not authorize Orbital, quad,
constant-product, mixed-family or funded-DETF source edits.
