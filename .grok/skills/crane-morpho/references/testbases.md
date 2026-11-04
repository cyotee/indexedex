# Morpho TestBases

## Contents

- TestBase_MorphoBlue
- TestBase_MetaMorpho
- Behaviors
- Upstream suites

## TestBase_MorphoBlue

`contracts/protocols/lending/morpho/blue/test/bases/TestBase_MorphoBlue.sol`

Provides:

- `morpho`, `irm` (AdaptiveCurve), `oracle` (OracleMock), `loanToken` / `collateralToken` (ERC20Mock + decimals)
- Actors: OWNER, SUPPLIER, BORROWER, LIQUIDATOR, FEE_RECIPIENT
- Default market created at `DEFAULT_LLTV = 0.8e18`
- Helpers: `_fundSupplier`, `_fundBorrowerCollateral`, `_mintLoan`, `_approveAll`

## TestBase_MetaMorpho

Extends Blue base; deploys MetaMorpho factory + vault; enables cap + supply queue for the default market.

## Behavior

`Behavior_IMorpho` — exact market/position equality helpers for declaration and parity tests.

## Upstream

| Suite | Path | Status |
|-------|------|--------|
| Blue | `…/blue/upstream/` | Full portable suite green |
| MetaMorpho | `…/metamorpho/upstream/` | Portable suite green; see SKIPPED.md |
