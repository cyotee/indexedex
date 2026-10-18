# Kimi K3 — remaining queue: RC-06, RC-07, RC-08 (replacement-session original)

- **Label:** Replacement-session original, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read, including `docs/reviews/apex-rc-06-unwrap/reviewers/`. The controlling text (`docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`: RC-06 at `:146-157`, RC-07 at `:159-171`, RC-08 at `:173-186`) was read fresh this round — no guard denial. Nothing was edited. I did not run Forge.
- **Date:** 2026-10-18.

## RC-06 — orbital capped unwrap

The September claim: after `exchangeOut`, the unwrap assigned the approval cap to a returned share count and discarded the SE's reported spend. Current source: `_unwrapExactTokenOut` (`UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:711`) has no `returns` clause — verified by direct grep this round; there is no share count to misreport. The cap that remains (`maxIn = quotedIn`) is the quote, approved and zeroed, with a short-delivery revert. Callers use statement form. The PRD's removal resolution is what the tree contains.

## RC-07 — availability math on a book deficit

The September claim: `BasicVaultCommon._unbookedSurplus` panics when balance is below book. Current source, read this round:

- **The base helper still panics** — `BasicVaultCommon.sol:37-39` keeps the checked subtraction, now explicitly documented as the historical default ("Active D16 families override this with `LocalCreditLib.available`… Historical consumers outside that override set keep this panic", `:33-36`). That matches the PRD's own preservation requirement, so the base panic is intended, not residual.
- **Every active D16 family returns zero on deficit.** Overrides verified line-by-line this round, each `LocalCreditLib.available(balance, booked)`: Uniswap V2 (`UniswapV2StandardExchangeCommon.sol:63-65`), Camelot (`CamelotV2StandardExchangeCommon.sol:50-52`), Aerodrome (`AerodromeStandardExchangeCommon.sol:62-64`), Aave Stata (`AaveV3StataStandardExchangeCommon.sol:114-116`), and Balancer single-pool's equivalent standalone (`BalancerV3SinglePoolStandardExchange.sol:227-229`). The FullSpread/staking/Morpho/ERC4626 families do not call `_unbookedSurplus` at all — they read `LocalCreditLib.available` inline at their credit sites.
- **Callers found:** the shared `_refundExcess` (`BasicVaultCommon.sol:131`) calls `_unbookedSurplus` virtually, so the overrides govern on D16 paths; Camelot's OutTarget `:437` dispatches to Camelot's override; the Balancer single-pool's own three call sites use its safe local copy. No active path reaches the panicking base body with a deficit.

## RC-08 — Uniswap V2 zap-out backing check

The September claim: an empty `revert()` at `UniswapV2StandardExchangeOutTarget.sol:578-580` when pool-token balance fell below `vaultLpReserve`. Current source: the check now lives in `UniswapV2LpBacking.requireHeld` (`UniswapV2StandardExchangeOutTarget.sol:1011-1020`) and reverts **`InsufficientLPBacking(uint256 held, uint256 required)`** — a named error carrying both compared values (`:1015`, `:1018`). The comparison (`held < required`) is unchanged, not weakened; the old line range now holds an unrelated transfer. The named-error edit the PRD required is present; per the owner's note this was optional, and it is done.

## Item lines

Close RC-06
Close RC-07
Close RC-08

I did not run Forge.
