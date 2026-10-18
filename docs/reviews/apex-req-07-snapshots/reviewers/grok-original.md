# Grok — REQ-07 snapshots

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-18
- **Controlling text:** OD-02 and REQ-07 in `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md`

No implementation gap.

No vault stores the snapshot bytes discussed for REQ-07. A vault or hook builds those bytes only for the current call, then returns or passes them. The rate provider does not take one for a plain rate.

## 1. Stored snapshot bytes

None found. `StandardExchangeRateProviderRepo.sol:19-25` stores the vault, subject, target, and decimals. It has no snapshot field. No `bytes state` storage field was found under `contracts/vaults/`.

`Harvest.snapshot` and FullSpread `_snapshot` are view reads of the current book. They do not write quote-state bytes.

## 2. Ephemeral quote state

These calls build bytes during the call and pass them onward. They do not keep them.

- Wings `UniswapV4UpperLowerWingsStandardExchangeVaultTransitionTarget.sol:14-16` encodes the current projection and returns it.
- ERC-4626 `ERC4626StandardExchangeQuoteTarget.sol:51-60` reads a nested `quoteState` and returns it inside the encoded quote.
- Rebasing `RebasingAwareERC4626Common.sol:505-516` fills a memory quote from the live book.
- Hook library `UniswapV4SeBufferHookContextQuoteLib.sol:43-48` calls `quoteState` and returns the projected bytes. The same pattern is at `UniswapV4SeBufferHookLegLib.sol:55` and `:75`, the dual hook quote files at `DepositQuoteLib.sol:100` and `InQuoteBase.sol:125`, the single-hook quote at `InQuoteBase.sol:115`, and the orbital exit quote at `ExitQuoteLib.sol:62`.

OD-02 keeps this path. A caller that already holds those bytes may pass them to `quoteRate`.

## 3. Rate provider

`StandardExchangeRateProviderFacet.sol:45-46` calls `_getRate("")`. The empty path at lines 67–68 and 119–121 uses `totalSupply` and `previewExchangeIn`. It does not call `quoteState`. It does not read `gasleft`. A supplied snapshot is used only by `quoteRate` at lines 49–58 when the subject matches.

The wrapped provider at `WrappedStandardExchangeRateProviderTarget.sol:25-26` also starts from an empty state. It does not call `quoteState`.

I did not run Forge.
