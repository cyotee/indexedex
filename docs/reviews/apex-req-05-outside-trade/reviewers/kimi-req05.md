# Kimi K3 — REQ-05 outside-trade credit: completion verification (replacement-session original)

- **Label:** Replacement-session original, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read (a repo-wide grep incidentally showed peer fragments for this item; none were opened or used). Nothing was edited. I did not run Forge.
- **Controlling text:** `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` REQ-05 (`:255-270`, read in full). Scope discipline: the deleted tree `contracts/protocols/dexes/uniswap/v4` is not this item; the four supported families only.

## Verdict: REQ-05 complete.

All four families have a current test satisfying the three required properties. Verified by direct read this round; runtime green is not claimed by me (source-presence verification only — no Forge run).

## Per-family evidence

### V3 FullSpread — `release/v3/UniswapV3FullSpreadStandardExchangeVault_FeeCompound.t.sol:50-75`

- **Pool trade is not a vault call:** `_externalSwapExactIn(pool, true, 50_000 ether)` (`:64`) → the helper calls `pool.swap(...)` directly with the test contract as recipient (`test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol:161-175`), paying the pool in the callback. No vault touch.
- **Book not refreshed:** `reserveOfToken` unchanged for both tokens and total supply unchanged (`:65-67`).
- **Next credit uses only held tokens:** `minted == preview` and the caller receives only the funded credit (`:70-74`). The sibling D27 test (`:77-104`) additionally shows the incumbent is not diluted by post-trade tiny joins.

### V4 hookless FullSpread — `v4/fullSpread/hookless/AttributionAndBooking.t.sol:34-49`

- **Not a vault call:** `_externalSwap(false, 100e18)` (`:39`) → operation 2 in the test driver → `poolManager.swap(poolKey, …)` directly (`test/bases/…Hookless…_Acceptance.sol:95-124`); the vault-call operation (1) is a different path.
- **Book not refreshed:** `:40-42`.
- **Only held tokens:** `minted == preview`, caller receives only the funded credit (`:43-47`), plus `_assertBooked()` (`:48`). The companion `test_poolRepricingDoesNotCreatePretransferCredit` (`:51-56`) shows the repriced pool creates no phantom pretransfer credit.

### V4 Pons-family FullSpread — `v4/fullSpread/ponsFamilyV2Hook/AttributionAndBooking.t.sol:37-52`

- Identical structure to hookless: `_externalSwap(false, 100e18)` (`:42`) → direct `poolManager.swap` in the shared driver (`…PonsFamilyHook_Acceptance.sol:101-133`, same operation-2 shape); book-unchanged assertions (`:43-45`); exact preview credit (`:46-50`); `_assertBooked()` (`:51`); the same repricing-credit negative at `:54-59`.

### Wings — `v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol:26-40`

- **Not a vault call:** a separate `Actor` contract (`:21`, constructed against the pool) executes `trader.swapTo(key, false, 1e18, …)` (`:33`) against the pool key directly.
- **Book not refreshed:** `reserveOfToken` both tokens and supply unchanged (`:34-36`), with an added `quoteState` snapshot sanity check (`:28-29`).
- **Only held tokens:** preview-then-deposit with `minted == preview` (`:37-39`); the bootstrap (`:45-58`) pins the vault's 1:1 custody accounting the credit is measured against.

## The other two acceptance criteria

- **Reserve-reconcile supplement not cited as the proof:** current law docs label it exactly that — `docs/reviews/apex-2026-09-17-second-audit-readiness/STAGE1_EVIDENCE.md:22` ("remains a local-reserve supplement… not the outside-trade proof") and the stage-2 review manifests carry the same label. The four proofs above stand alone; no current document cites the supplement as the stale-reserve proof.
- **Historical evidence labeled historical:** the old-bug evidence lives in dated audit/review records that are labeled historical; the old tree is deleted, so nothing requires it to compile. Criterion satisfied.

## Boundaries

One family does not close another — each was verified from its own test and its own helper, listed above. This is a source-presence verdict: I did not run the tests, and no runtime claim is made. No repair is proposed; none is needed against the existing acceptance criteria.

I did not run Forge.
