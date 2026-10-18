# Kimi K3 — RC-07: the one recommended fix (replacement-session original)

- **Label:** Replacement-session original, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read, including `docs/reviews/apex-remaining-close/reviewers/`. The controlling text (`docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md` RC-07 at `:159-171`) was read fresh this round — no guard denial. Nothing was edited. I did not run Forge.
- **Date:** 2026-10-18.

## The assigned facts, confirmed against current source

- `BasicVaultCommon.sol:37-38` still uses checked subtraction (`balanceOf - reserveOfToken`), so the base body panics on a book deficit. Confirmed by direct read this round.
- Its NatSpec at `:33-36` now records the intended split explicitly: "Active D16 families override this with `LocalCreditLib.available`, which returns zero when balance is below book. Historical consumers outside that override set keep this panic."
- The overrides exist and return zero on deficit, each verified this round: Uniswap V2 (`UniswapV2StandardExchangeCommon.sol:63-65`), Camelot (`CamelotV2StandardExchangeCommon.sol:50-52`), Aerodrome (`AerodromeStandardExchangeCommon.sol:62-64`), Aave Stata (`AaveV3StataStandardExchangeCommon.sol:114-116`), and the Balancer single-pool's equivalent standalone (`BalancerV3SinglePoolStandardExchange.sol:227-229`).

## Every production caller of the base body (complete, this round's grep)

Only three call sites invoke `_unbookedSurplus(...)` anywhere in `contracts/`:

1. `BasicVaultCommon.sol:131` — the shared base `_refundExcess` (`:123-138`). The call is **virtual**: on V2, Camelot, and Aerodrome (the families that call the base `_refundExcess` — V2 `Common.sol:506`, Camelot `Common.sol:245`, Aerodrome's eight OutExecuteTarget sites plus `Common.sol:1030`) it dispatches to those families' zero-on-deficit overrides.
2. `CamelotV2StandardExchangeOutTarget.sol:437` — dispatches to Camelot's own override.
3. `BalancerV3SinglePoolStandardExchange.sol:165, :239, :262` — call that family's own standalone `LocalCreditLib.available` copy, not the base body.

Every other active family never touches the base helper: ERC4626 has its own `_refundExcess(token, to, excess)` (`ERC4626StandardExchangeCommon.sol:282-285`, fed by the budget-bounded `_prepaidCredit` at `:293-302`); FullSpread hookless/Pons have their own frame-based `_refundExcess` (`…OutExecuteTarget.sol:147-152` each, guarded by `AccountingMismatch` and fed by `_pretransferCredit`); Wings, the staking families, Morpho, and the DETF families use their own `available`-bounded credit/refund forms. None reaches the panicking base body.

## Conclusion

No active D16 path reaches the panic: a book deficit yields zero credit on every in-scope family, either through the override or through an `available`-bounded family-local path. The base panic survives only for historical consumers outside the D16 set — which is the PRD's stated preservation requirement, not a residual defect. The item's acceptance criteria are satisfied in current source, and nothing remains to repair.

**No production change. Close RC-07.**

I did not run Forge.
