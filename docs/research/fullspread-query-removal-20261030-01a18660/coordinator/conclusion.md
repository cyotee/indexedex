# Conclusion — drop PairToken queries and getRate?

Coordinator synthesis, 2026-10-30. Four originals settled. The published PRD was not edited. Astra, MiniMax, and Kimi tasks reported `child turn produced no assistant output` after writing complete response files. Those files are the originals. No retry was issued.

## Answer

Split the question. Keep the eleven PairToken query selectors. Do not install `getRate()` while the rate policy is unknown.

All four members reached that split. None recommended removing the eleven in order to avoid choosing a rate.

## Problems with removing the eleven queries

No admitted buffer-hook caller reads `poolManager`, `poolKey`, `wrappedNative`, `rateAsset`, `tickLower`, `tickUpper`, `positionLiquidity`, `localReserves`, `basket`, `maxZapBps`, or `maxZapTickMove` on the vault. The hook calls `previewExchangeIn`, `exchangeIn`, and `vaultTokens()`.

Removing the eleven therefore does not break deposit, exit, or the hook's conversion call. It does delete the family's public witness of its own pool, native binding, position, raw basket, and zap limits. Those values must remain in storage and in execution. `basket()` is the raw book, distinct from SY `exchangeRate`. `localReserves()` is the raw-currency book, distinct from the wrapped-face shared reserve view. A depositor cannot read `maxZapBps` or `maxZapTickMove` if those getters go. That is an ABI loss, not a reason the money functions fail.

## Problems with removing getRate

The owner's reason applies here. `getRate` was a one-share exit formula chosen before the rate policy was known. Keeping it does not answer how a vault should be rated at creation. `PkgArgs.rateAsset` is the creation-time denomination, and it stays even if `getRate` goes.

Removing it does not break `exchangeIn`. The hook does not call `getRate` on the vault. It calls a separately bound `IRateProvider` when the pool token is not the share.

What it does break is the published PRD's buffered-hook proof, which bound that provider to this vault's `getRate`. After removal, that proof is unresolved until a provider and a rate policy are chosen. Do not fill the gap with NAV, SY `exchangeRate`, a zero, a 1:1 bootstrap, or the existing full-book `StandardExchangeRateProvider`. That provider prices the whole book and, at zero supply, publishes an issuance invert. Using it would be a rate decision, not the absence of one.

## What must stay

`exchangeIn`, `previewExchangeIn`, the paired methods, exact-output rejection, SY `exchangeRate`, the five shared facets, and the internal pool key, ticks, wrapper, zap limits, and `rateAsset`. Do not remove those with the queries.

## Recommended PRD change, not applied

Record one new delta: this family does not install `IRateProvider`. Restore the inherited refusal in S1-API-04 for that one selector. Mark the buffered-hook fixture that required this vault's `getRate` as unresolved until the owner names a provider and a formula. Keep the eleven query selectors. Do not invent a replacement rate.
