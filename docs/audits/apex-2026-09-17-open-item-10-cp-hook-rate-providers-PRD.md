# PRD: held-reserve valuation and rate providers across the seven buffer hooks (APEX open item 10, F2 / F7, D60)

- **Plan:** [apex-2026-09-17-remediation-and-regression-tests.plan.md](./apex-2026-09-17-remediation-and-regression-tests.plan.md), decisions D59 (locked 2026-09-21) and D60 (this PRD)
- **Ledger:** [apex-2026-09-17-review-open-items.md](./apex-2026-09-17-review-open-items.md) item 10
- **Status:** signed off by the owner on 2026-09-21 with the rule 3 correction. Work package 1 (four provider families) executed 2026-09-22; work packages 2 to 5 (single-CP, dual, DETF gate, tests, law) executed 2026-09-22; see the evidence file sections "D60 work package 1" and "D60 work packages 2 to 5". Open for the owner: F8 (loop borrow headroom after a partial unwind) and the interpretation that the first-mint scale and `kLast` stay on the rated book. Supersedes the 2026-09-21 two-hook draft of this file.

## 1. The rule (owner, 2026-09-21)

1. A hook values a held reserve as its **raw held balance** unless a **rate provider** is configured for that leg, in which case the value is `held x rate`. A hook never computes a rate for a configured vault itself: no `previewExchangeIn(se, heldBalance, token)`, no transition-quote `quoteAssets(state, heldShares)` as a valuation.
2. A rate provider may be configured for **any** leg. Package init does not reject a provider on a non-SE leg (`RateProviderWithoutSE` is removed). The deployer is responsible for the provider matching the bound token.
3. **A leg that declares a Standard Exchange must have a rate provider** (owner correction, 2026-09-21): the swap is executed in the leg's token while the reserve is held as SE shares, so a buffered leg valued by its raw share count would price the pair wrong. Package init reverts `RateProviderRequired` for an SE leg with `address(0)` as provider. Declaring an SE means the leg's token is **buffered into that SE** (deposited on inflow, withdrawn on outflow); the SE call sites that remain are buffering-operation quotes and executions.
4. **Two invariants (D59).** Liquidity operations, LP issuance and proportional exits use raw balances of the concrete reserve. The virtual swap invariant uses the rated reserves (raw, or raw x rate). This is the Balancer rate-scaled pool method.
5. Every pool exposes `rateProviders() -> address[]` and `rateProvider(address token) -> address`.

**Resolved consequence.** The 2026-09-21 draft noted that a buffered leg with no provider would be priced in SE share units while swaps execute in the pair token. The owner ruled that such a configuration is rejected instead (rule 3), so every buffered reserve is valued as `shares x rate` and every raw reserve as its balance (or `balance x rate` when the deployer configures a provider for a plain token).

## 2. Current state (verified 2026-09-21)

| Family | Provider field | Init rejects | Valuation fallback when no provider | Branch sites |
| --- | --- | --- | --- | --- |
| weighted | `rateProviders[]` | provider on non-SE leg | `previewExchangeIn(se, seBal, token)`, `ClaimLib.previewBufferClaimIn` claim delta, transition `quoteAssets` | 5: `ClaimLib.sol:38`, `HooksTarget.sol:282, 403`, `DFPkg.sol:398` |
| curve-quad | `rateProviders[]` | same | same shape | 6: `ClaimLib.sol:37`, `HooksTarget.sol:285, 329, 419`, `DFPkg.sol:372` |
| Balancer-quad | `rateProviders[]` | same | same shape | 5: `ClaimLib.sol`, `HooksTarget.sol:273, 317`, `DFPkg.sol:367` |
| orbital | `rp0..rp2` | same | `ClaimLib.seClaimOf`, claim deltas, transition `quoteAssets` | 8: `ClaimLib.sol:35, 51, 81, 101, 119`, `Common.sol:621, 795, 1482`, `DFPkg.sol:377` |
| single-CP | none | n/a | always `previewExchangeIn(se, seBal, pairToken)` (`_seClaim`, `_previewSeClaimOfBal`, `ClaimLib._claimOf`) | about 15 sites in `DepositCommon`, `DepositPreviewTarget`, `SeTarget`, `ClaimLib` |
| dual | none | n/a | always `_claimSupply` = full-balance exit quote | 12 sites in `DualStandardExchangeBufferConstantProductHookCommon.sol` |

Every hook-matrix row for the four provider families deploys with an all-zero provider array, so the fallback branch is the path all current evidence exercises. Existing getters: `rateProvider(uint256 index)` on weighted, curve-quad and Balancer-quad; none on orbital, single-CP or dual.

## 3. Site classification: what changes and what stays

**Valuation sites (change to raw held balance or `held x rate`):**

- Reserve views: `ratedPairUnits(i)` in the three ClaimLibs, orbital `ClaimLib:81`, single-CP `_seClaim()` / `_reserveOfCurrency` / `_updateReserve`, dual `_claimSupply` reserve views (131 to 146). Buffered leg: `ratedPairUnits(shares, rate, invScale, ratedScale)` (a provider is guaranteed by init). Raw leg: the raw balance, times the rate when a provider is configured.
- Exact-in swap inflow: weighted `HooksTarget:282`, curve-quad `:285`, Balancer-quad `:273`, orbital `ClaimLib:51, 101`, single-CP `_quoteExactIn` (405), dual 494 to 510, 618. The buffering quote `sharesOut = previewExchangeIn(token, amountIn, se)` stays; the inflow becomes `sharesOut x rate`. The claim-delta computations (`afterClaim - heldClaim`) go.
- Exact-out shares needed: curve-quad `:329`, Balancer-quad `:317`, orbital `ClaimLib:119`, `Common:795`, single-CP exact-out (795), dual 1221. `sharesNeeded = descaleUp(pairUnits, rate)`; the SE exact-out fallback goes. The following buffering quote (`bufferInputForShares`, `invertUnwrapExactTokenOut`) stays.
- Transition-quote swap paths: weighted `:403`, curve-quad `:419`, orbital `Common:621`, `:1482`. `held` and `inflow` become `shares x rate`; `q.heldAssets` / `quoteAssets(...)` are no longer used as values.
- Single-CP liquidity math (`_reservesBeforeDualPull` 531, single-token deposit 840, withdraw 945 and the LP share math they feed) moves to raw balances per D59.4.

**Buffering sites (unchanged):** deposit quotes `previewExchangeIn(token, amount, se)`, `previewExchangeOut(token, se, shares)` and the quad `bufferInputForShares` search, `invertUnwrapExactTokenOut`, `previewUnwrapShares` for the actual unwrap amount paid out, every `exchangeIn` / `exchangeOut` execution, D15 credit and refund logic, D41 / D48 rate-provider probes (`rateAfterExchange` keeps reading the provider when one is set).

**Validation (change):** delete `RateProviderWithoutSE` in the four DFPkgs and add `RateProviderRequired` (SE leg with zero provider) on all seven; keep array-length checks; single-CP and dual gain `rateProvider` / `rateProvider0, rateProvider1` fields.

**Getters (add):** `rateProviders()` and `rateProvider(address token)` on all seven; keep `rateProvider(uint256)` where it exists. R12 records the new selectors with new facet salts.

## 4. Work packages

| WP | Scope |
| --- | --- |
| 1 | Four provider families: delete the valuation fallbacks at the 24 branch sites (the rated branch becomes the only branch for a buffered leg; a raw leg keeps its balance, times an optional rate), replace `RateProviderWithoutSE` with `RateProviderRequired`, add getters. |
| 2 | Single-CP and dual: `PkgArgs` fields, Repo slots, rated or raw valuation at every site, raw-balance liquidity math, getters. |
| 3 | DETF: V4 DETF packages accept the SE vaults' rate providers in `PkgArgs` (mirroring `vaultShareRateProviders` on the Balancer-hosted packages) and the premine library passes them to the reserve hook. |
| 4 | Tests: every `PkgArgs` construction site (20 single-CP, 7 dual, all family TestBases); per family one boundary suite: an SE leg without a provider is rejected at init (`RateProviderRequired`); a plain leg accepts a provider and values as `balance x rate`; a buffered leg values as `shares x rate` through a `StandardExchangeRateProvider`; a provider that reverts, replies short or returns zero fails the swap closed. Every existing fixture that binds an SE leg (the 84 matrix rows of the four families, the family TestBases, the DETF suites) deploys a `StandardExchangeRateProvider` per SE leg; matrix rows for F2 and F7 restored to gold and re-run in both modes; DETF reserve-pool suites; R12 re-cut with `scripts/r12_selector_size_compare.py`. |
| 5 | Law and NatSpec: the valuation rule, the buffering meaning of an SE declaration, the getters. |

Order: WP1, then WP2, then WP3, WP4 alongside each, WP5 last. Each WP ends with `forge build`, the family suites, the matrix path and a full hermetic run.

## 5. Acceptance criteria

- [ ] A1. `rg -n 'previewExchangeIn\(IERC20\((se|l\.standardExchange|quote\.se)\), (seBal|heldShares|shares|quote\.heldShares)' contracts/hooks/uniswap/v4/standardExchange` finds no valuation site; remaining SE previews are buffering quotes named in section 3.
- [ ] A2. No hook reads `quoteAssets` to value a held reserve.
- [ ] A3. Package init on all seven hooks accepts a provider on any leg and requires one on every SE leg (`RateProviderRequired`).
- [ ] A4. A raw leg's reserve view equals its balance (times the rate when a provider is set); a buffered leg's equals `shares x rate`; a failing provider fails closed on every family (boundary suites).
- [ ] A5. Liquidity operations on single-CP and dual use raw balances; proportional exits return proportional raw amounts.
- [ ] A6. `rateProviders()` and `rateProvider(address)` answer on all seven; R12: 0 missing, 0 oversize, selector additions classified.
- [ ] A7. F2 and F7 rows COMPATIBLE on single-CP with a `StandardExchangeRateProvider` per leg, and the same SE families written on dual.
- [ ] A8. DETF suites pass with providers supplied through `PkgArgs`.
- [ ] A9. Full hermetic `forge test -vv` green.

## 6. Non-goals

- No Standard Exchange changes.
- No migration of deployed instances.
- No rate-provider deployments in production launch scripts beyond what a DETF supplies through its own `PkgArgs`.
