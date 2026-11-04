# MiniMax — full-spread query and `getRate` removal advisory

Run `fullspread-query-removal-20261030-01a18660`. Council kind: full. This pass is an independent original.

## 1. Identity and assigned route

- Member: MiniMax, independent council member.
- Assigned route label: `minimax/MiniMax-M3`. That is the coordinator's requested route, not a runtime attestation. I do not claim, verify, or represent provider internals, and I do not represent any other member.
- Read scope actually used: the published full-spread PRD; the PairToken stage-one PRD (facet list, `S1-API-01` through `S1-API-05`, `S1-API-02` route table, `S1-NATIVE-01`, `S1-QUOTE-02`); and the current hook call pattern under `contracts/hooks/uniswap/v4/standardExchange/` plus the rate-provider package it binds. To answer the brief's caller question I also ran targeted repository searches over `contracts/`, `test/`, `frontend/`, `scripts/`, `lib/` for call sites of the eleven selectors. I read no peer originals, did not search the public web, did not edit the PRD, did not implement, did not run Forge, and did not delegate.
- The published PRD's `getRate` placement is a **coordinator disposition**, not an owner decision: PRD §2.1 records it as "Not adopted: Omit it. A thirteenth `RateFacet`. Return zero below one share", and PRD §9 records that Grok's omission of `getRate` "stays rejected". So the owner's question in this run is the first owner-level statement on the subject, and PRD §2.1 is not an answer to it.

## 2. Direct answer: **split** — and the split is not the owner's line

**Keep the eleven query selectors. Remove `getRate` from the vault only in the same change that re-points the buffered-hook fixture at the canonical `StandardExchangeRateProvider`, and record the rate policy as an open owner decision.** If the owner will not accept the canonical provider, keep `getRate` and record the open decision instead — do not remove the number and leave the rate unbound.

Three findings drive that, and the third one changes the shape of the answer.

1. **No production caller of the eleven exists.** Nothing in `contracts/` calls the eleven on a Standard Exchange vault. The hook reaches an SE vault only through `previewExchangeIn` / `exchangeIn` / `previewExchangeOut` / `exchangeOut` and the shared `IBasicVault.vaultTokens()`. So removing them breaks no caller — but it relieves no caller either, and it deletes the family's only public self-description. Removing them is not "free simplification"; it is a one-way ABI change that buys nothing operationally.
2. **The hook never required the vault to be the rate provider.** `IRateProvider` is read by `staticcall` from a *bound provider address*, not from the SE. The canonical `StandardExchangeRateProvider` package already serves every buffered leg in the current fixtures. So removing `getRate` does not break the hook plumbing.
3. **The owner's stated reason does not land on `getRate`.** Under FS-RATE-01, `getRate` is a runtime, state-derived one-share exit quote; it is not a creation-time rating and it needs no new `PkgArgs` field. The creation-time rating inputs are `PkgArgs.rateAsset` and the hook package's provider binding, and **both survive the removal**. Removing `getRate` therefore does not deliver "we will decide the rating later". It removes the family's own number and leaves the actual decision exactly where it was.

That third point has a hard consequence, and it is the most important thing in this advisory:

> With the vault's `getRate` gone, the only remaining provider for a buffered FullSpread leg is the generic full-book provider. Its zero-supply path publishes an **issuance** rate — "shares minted for one whole target token", inverted into "target per whole share". That is precisely a creation-time rating of a vault, expressed in a package the owner does not version with the family.

So there are exactly two outcomes of dropping `getRate`, and no third:

- **Displace** the rating decision into the canonical provider package, whose semantics the family then inherits without endorsing; or
- **Block** the canonical buffered-hook route for this family until a rate policy exists, recorded as an FS-HOOK-04 integration record.

The owner should be told this plainly. "We don't know how we would rate a vault at creation" is not resolved by removing `getRate`; it is resolved by deciding `rateAsset` per deployment and deciding who supplies the leg's rate.

## 3. Problems caused by removing the eleven queries

### 3.1 Per-selector caller finding

| Selector | External caller found in this repo | Consequence of removal |
| --- | --- | --- |
| `poolManager()` | **No external caller found** | No caller breaks. Family loses the public route to its instance manager. |
| `poolKey()` | **No external caller found** | No caller breaks. Family loses the public route to its backing pool identity. |
| `wrappedNative()` | **No external caller found** | No caller breaks. Loses the public route to the native wrapper binding. |
| `rateAsset()` | **No external caller found** | No caller breaks. **Redundant**: SY `assetInfo()` already returns `config_.rateAsset` (`UniswapV4PairTokenStandardExchangeVaultSYQueryTarget.sol:62-65`). The only one of the eleven with a surviving duplicate. |
| `tickLower()` | **No external caller found** | No caller breaks. Loses the published full-range lower tick. |
| `tickUpper()` | **No external caller found** | No caller breaks. Loses the published full-range upper tick. |
| `positionLiquidity()` | **No external caller found** | No caller breaks. Loses manager-reported owned liquidity. |
| `localReserves()` | **No external caller found** | No caller breaks. `IBasicVault.reserves()` partially overlaps (booked local custody) but is not stated to exclude operation reservations identically. |
| `basket()` | **No external caller found** | No caller breaks. No substitute: clamped removable principal plus booked idle is family-specific. |
| `maxZapBps()` | **No external caller found** | No caller breaks. Loses the published zap size bound. |
| `maxZapTickMove()` | **No external caller found** | No caller breaks. Loses the published zap tick bound. |

Evidence behind "no external caller found":

- The eleven are the query facet's exact package manifest: `UniswapV4PairTokenStandardExchangeVaultDFPkg.sol:426-440` (`_expectedSelectors`, index 8, length 11), and the family interface `IUniswapV4PairTokenStandardExchangeVault.sol` pins each selector (`0xdc4c90d3`, `0x182148ef`, `0xeb6d3a11`, `0xcf77880f`, `0x59c4f905`, `0x55b812a8`, `0x7211dc36`, `0x765d889f`, `0xedc832b3`, `0x6e2abc14`, `0x67698371`).
- A production-wide scan of `contracts/` for call sites returns only: the family's own definitions (`UniswapV4PairTokenStandardExchangeVaultQueryTarget.sol`), the Wings sibling's own definitions, unrelated families' own `poolManager()` / `rateAsset()` (TWAP oracle, DETF rebasing token), and the `pairtoken-baseline` `PairToken.sol` contract's own internal `basket()` / `positionLiquidity()` use plus `IPairTokenFactory(factory).maxZapBps()` / `maxZapTickMove()` calls to a *factory*, not to a vault. **No contract calls these on an SE vault.**
- The hooks do not call them. `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol:73-140` reaches the vault only through `IStandardExchangeIn.previewExchangeIn`, `IStandardExchangeOut.previewExchangeOut`, and `exchangeIn`; `UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol:391-395` does leg-token discovery through `IBasicVault(se).vaultTokens()`; the rate comes from the provider address at `UniswapV4SeBufferHookContextQuoteLib.sol:27`.
- The family does not self-call them either. `IVault` inside the family is used only for enums, errors, events, and `facetFuncs()` manifests; all state reads go through `Repo` / `Projection`.
- No `frontend/`, `scripts/`, or `lib/` consumer of any of the eleven (the only hits were `node_modules` noise and audit JSON archives).

### 3.2 What breaks anyway, even with no caller

1. **Package shape.** The eleven occupy `PkgInit` field 8 of twelve (`IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol:22-43`), which FS-FACET-01 and FS-PKG-01 inherit. The field cannot simply be left in place with an empty facet: the package compares `facetFuncs().length` to `expected_.length` and reverts `InvalidComponent` on mismatch, then checks membership and rejects duplicates (`UniswapV4PairTokenStandardExchangeVaultDFPkg.sol:334-348`). A facet carrying a *different* selector set also fails, because the check is membership in the expected list, not a superset. So the removal either changes the inherited `PkgInit` shape from twelve fields to eleven (and with it `bindingHash`, `calcSalt`, and the package's registry identity), or it requires the family to define a replacement query facet and re-state its own expected manifest.
2. **Selector manifest and acceptance rows.** 61 distinct package-owned selectors (20 shared + 41 family) becomes 49 with eleven removed, or 60 with only `getRate` removed. FS-FACET-01's "61", FS-A01 ("All 61 selectors succeed through the proxy"), and FS-A06/FS-A24 ("this family's 61-selector manifest") all change. FS-PKG-02's "rejects a query facet that lacks `getRate`" loses its subject if the facet goes.
3. **Family ABI.** The interface ID `0x8be92db3` and the package's `declaredInterfaces` aggregation change; `S1-API-05`'s pinned-signature list loses eleven entries.
4. **Loss of external auditability — the real cost.** After the removal nothing outside the family can read the backing pool key, the full-range ticks, the owned position liquidity, the zap limits, or the family's own notion of removable principal. The Uniswap V4 position key requires the exact ticks (`Position.calculatePositionKey(owner, tickLower, tickUpper, salt)`), and once `tickLower()` / `tickUpper()` are gone the ticks are a *convention* (`TickMath.minUsableTick` / `maxUsableTick`) rather than a published fact. `IBasicVault.reserves()` and `vaultTokens()` do not replace `basket()` or `positionLiquidity()`. `rateAsset()` is the sole exception, because `assetInfo()` already publishes it.

**Recommendation on the eleven: keep them.** They cost no gas, no caller asks for their removal, and they are the only public description of the family's backing position. If the owner wants a smaller ABI regardless, `rateAsset()` is the single defensible trim, since `assetInfo()` already returns it.

## 4. Problems caused by removing `getRate`

### 4.1 Hook integration: the plumbing survives, the PRD's choice does not

- Crane's `IRateProvider` is a single-method interface: `getRate() external view returns (uint256)`.
- Every buffer-hook family reads the rate from a **bound provider address**, not from the SE: dual `UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib.sol:203`; orbital `UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol:406-408`; weighted `UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol:97`; constantProduct/single `UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:440`; stable/quad/balancer `UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib.sol:197-204`; stable/quad/curve `UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol:141-143`; and the shared `UniswapV4SeBufferHookContextQuoteLib.sol:27`.
- The provider is required only when the leg token is not the share: `UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol:387-388` and `UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol:400` (`RateProviderRequired()`). The provider is an *address in the hook package*, not "the SE".
- The production-proven binding for that address is a separately deployed `StandardExchangeRateProvider` package bound to `(reserveVault = the SE, rateTarget = the leg token)`, created through CREATE3 and the package factory; `RateProviderFixtureLib.providerForCp` (`contracts/test/libs/RateProviderFixtureLib.sol:41-49`) does exactly this for every buffered leg in today's fixtures.

Therefore the vault does not have to be the provider, and removing the vault's `getRate` does not by itself break the hook. What breaks is the PRD's *choice of provider*:

- FS-HOOK-02 step 1 and FS-A29 bind "the provider's `getRate` is this vault's `getRate`". With the vault's `getRate` gone, FS-A29 is unsatisfiable as written and FS-HOOK-02 must name the canonical provider instead.
- FS-RATE-01's definition and its `InsufficientRateSupply`, `RateNormalizationOverflow`, `RateUnavailable` errors become dead text, and FS-A12, FS-A13, FS-A14, FS-A15, FS-A29, FS-A32's rate clauses must be rewritten or dropped.

### 4.2 Behavior lost by falling back to the canonical provider

1. **The fallback rate is a different kind of number.** `StandardExchangeRateProviderFacet._getRate` prices the **entire book** through `previewExchangeIn(totalSupply, rateTarget)` and divides by supply (`StandardExchangeRateProviderFacet.sol:61-83`). FS-RATE-01 deliberately rejected this ("Do not bind that provider and call the result this family's one-share rate") because a whole-book liquidation is price-impact bearing and, for a full-range Uniswap V4 position, is a heavier preview than a one-share exit: it must fit the 5,000,000 preview ceiling (FS-MONEY-01) and can revert on the planner's work, tick-crossing, or bitmap budgets (`QuoteWorkExceeded`, `QuoteTickCrossingsExceeded`, `QuoteBitmapWordsExceeded`). I have not measured this; I flag it as the ceiling the family would be moving under, not as a demonstrated failure.
2. **A failed preview becomes a zero rate, and a zero rate is a hard hook failure.** `_getRate` swallows a failed whole-book preview and returns 0 (`StandardExchangeRateProviderFacet.sol:81`); the hook treats a zero rate as fatal (`RateProviderFailed()`, `UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:441-443`).
3. **On an unbootstrapped vault the canonical provider returns 0.** With `totalSupply == 0` the provider takes `_initialRate`, which static-calls `previewExchangeIn(rateTarget, one whole target token, share)`; an empty SE has no valid redemption (S1-API-02 route table: "V | C0 … Empty supply: No valid redemption"), so the preview reverts and `_initialRate` returns 0 (`StandardExchangeRateProviderFacet.sol:98-110`). The hook then reverts `RateProviderFailed()`. The vault's own FS-RATE-01 `getRate` would instead revert `InsufficientRateSupply(available, required)` — an explicit, specified reason. Same failure; worse diagnosis.
4. **The canonical provider's zero-supply path *is* a creation-time rating.** `_initialRate` is "shares minted for one whole target token", normalised into "target per whole share". The owner's objection — "we don't know how we would want to rate any given vault when it is created" — survives the removal and reappears inside a package the owner does not version with the family.
5. **The rate policy itself is untouched.** FS-RATE-01's `getRate` is endogenous and runtime: `E` is the `previewExchangeIn` planner result for one whole share into `rateAsset`, normalised by `rateAsset` decimals. It is not a creation-time input and introduces no new argument. The creation-time rating inputs are `PkgArgs.rateAsset` (carried in `IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol:48-55` and validated by `InvalidRateAsset` under FS-PKG-02) and the hook package's `rateProvider` binding. Both survive the removal untouched. Removing `getRate` removes the number; it does not remove the decision.

## 5. What must stay

If the eleven are removed:

- **The shared basic-vault views** `vaultTokens`, `reserveOfToken`, `reserves` — `vaultTokens()` is the hook's leg-token discovery (`UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol:391-395`). They are shared-facet selectors, outside the removal set, and they must stay installed and initialized (S1-ARCH-05).
- **The SE route surface** `previewExchangeIn`, `exchangeIn`, `previewExchangeOut`, `exchangeOut` — the only surfaces the hook calls on the vault (`UniswapV4SeBufferHookContextQuoteLib.sol:73-140`). `exchangeOut` keeps its `ExchangeOutNotAvailable()` revert (FS-HOOK-03); removing the query set does not touch it.
- **The family money and quote facets** (`depositPair`, `redeemPair`, `donate`, `compound`; `previewDepositPair`, `previewRedeemPair`, `previewWithdrawalMode`, `previewZapCredit`), the 16-method SY surface, and `unlockCallback` — outside the removal set and unaffected by it.
- **`rateAsset` as a stored and validated configuration value**, plus `assetInfo()` and `exchangeRate()` (S1-QUOTE-02), even if the `rateAsset()` selector goes. `assetInfo()` already publishes it.
- **The `PkgInit` field list and the package selector manifest**, re-specified rather than silently shrunk: if the query facet is emptied, FS-FACET-01 and FS-PKG-01 must state the new field list and count, and FS-PKG-02 must state what the package validates instead of "a query facet that lacks `getRate`".
- **A rate-provider address and an agreed rate semantics for it.** The hook package's `rateProvider` / `rateProviders` fields and the `RateProviderRequired()` rule stay whether or not the vault exposes `getRate`.

If `getRate` is removed, with or without the eleven:

- **The `queryFacet` slot must still exist** with the eleven selectors, so the manifest moves 61 → 60 and `PkgInit` keeps twelve fields. This is the smaller and cheaper change and the one I recommend.
- FS-PKG-02's "rejects a query facet that lacks `getRate`" and "rejects a cut that installs `getRate` twice" are deleted; FS-A29, FS-A12's `getRate` clause, FS-A13, FS-A14 and FS-A15 are rewritten or dropped; FS-A32's "and `getRate` revert" becomes "busy-vault economic views revert".
- **The prohibitions stay, re-pointed.** FS-RATE-01's "do not add a second `getRate`" and "do not retarget `rateAsset` per caller" become "the family installs no `getRate` and never retargets `rateAsset`". The family must also not advertise the `IRateProvider` interface ID — `StandardExchangeRateProviderFacet.facetInterfaces()` advertises it (`:148-153`), and a consumer that binds the vault as a provider would get a failing read.
- **A named owner for the rate policy**, so that "the family publishes no rate" is not later read as "the family needs no rate".

## 6. The smallest PRD change that records the owner's undecided rate without inventing a formula

Confined to FS-X02, FS-RATE-01, FS-FACET-01, FS-PKG-02, FS-HOOK-02, FS-A12/13/14/15/29/32, and one new open-decision record. No formula is written, and `rateAsset` is untouched.

(a) **Keep `rateAsset` in `PkgArgs` and keep `InvalidRateAsset`.** It is the only creation-time rating input, it is a face of the pool key rather than a formula, and SY `exchangeRate()` / `assetInfo()` need it regardless.

(b) **Replace FS-X02 with a deferred-rate clause** stating: the family installs no `IRateProvider`; `getRate` is not a package selector; the query facet is the eleven current PairToken query selectors; the manifest is 60 package-owned selectors across twelve package inputs.

(c) **Re-specify the buffered-hook provider.** FS-HOOK-02 step 1 and FS-A29 become: where the hook package requires a provider because the leg token is not the share, the bound provider is the canonical `StandardExchangeRateProvider` package deployed for `(reserveVault = this vault, rateTarget = the leg token)`; the family does not define, endorse, or reproduce that provider's rate semantics, and the provider's whole-book pricing and zero-supply issuance inversion are the provider's behavior, not this family's rating policy.

(d) **Record the open decision where a reader will find it.** One named open item in §2.1 or a new subsection, stating: the family has no owner-approved rating policy; the open questions are (i) whether the family will ever publish a vault-owned rate, (ii) if it does, whether it is the one-share executable exit or a spot mark, and (iii) which currency face is chosen per deployment and who chooses it; and that until (i) is answered the family publishes no rate, and any consumer pricing a buffered leg uses the canonical provider and inherits its semantics. Name the decision owner. This records the owner's undecided rate without inventing a formula.

(e) **State in one sentence what the removal did not decide**: removing `getRate` does not defer `rateAsset` selection or the hook provider binding; both remain live creation-time choices and must be answered before the first deployment.

(f) **Record the blocked alternative.** If the owner rejects the canonical provider's zero-supply issuance inversion, then the buffered-hook route for this family is blocked until a rate policy exists, and FS-HOOK-02 becomes an FS-HOOK-04 integration record naming the consumer, the selector, the arguments, and the revert. Do not stub a transition quote to paper over it (FS-HOOK-04).

**If the owner prefers not to churn the published PRD yet**, the smallest change of all is (d) alone: keep FS-RATE-01 and record the rate policy as an open owner decision with a named owner and a date. That is defensible, because FS-RATE-01's `getRate` is a runtime quote, not a creation-time rating — but it leaves the PRD asserting a rate the owner has not chosen, which is exactly the objection in this run, and PRD §2.1/§9 make clear that the existing placement was a coordinator disposition rather than an owner decision.

## 7. Limits

- This is a source-reading advisory. No Forge run, no deployment, no implementation, no PRD edit, no delegation.
- "No external caller found" covers `contracts/`, `test/`, `frontend/`, `scripts/`, `lib/` in this repository at read time. It does not cover off-chain consumers outside this repository, deployed instances, private integrations, or the audit-evidence archives. The only artifact-manifest hit for `rateAsset()` (`0xcf77880f`) in `docs/audits/apex-2026-09-17-evidence/initial-artifact-selectors-sizes.json` belongs to the DETF family, not to this SE family, so I make no shipped-artifact claim for the eleven.
- The hook provider-requirement reading comes from the current dual and constantProduct/single packages, with the orbital, weighted, stable/quad/balancer and stable/quad/curve families confirmed only for their `getRate` read path. I did not execute any hook package.
- The claim that the canonical provider returns 0 for an unbootstrapped vault is a reading of `StandardExchangeRateProviderFacet._getRate` / `_initialRate` against the S1-API-02 empty-supply route table. I did not run it.
- The gas argument for the whole-book preview is a constraint statement against the 5,000,000 preview and 12,000,000 transaction ceilings, not a measurement.
- `contracts/pairtoken-baseline/PairToken.sol` is a separate baseline contract; I used its internal `basket()` / `positionLiquidity()` uses only to exclude them as vault callers.
- Whether the canonical provider's semantics are acceptable to the owner is a product decision I cannot make. I can only state that the two outcomes are displacement or blockage, and that there is no outcome in which the rating decision disappears.
- I read no peer originals and make no claim about any other member's position.
