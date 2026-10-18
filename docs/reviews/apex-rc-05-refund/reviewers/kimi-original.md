# Kimi K3 — RC-05 single-CP hook refund: close or keep? (replacement-session original)

- **Label:** Replacement-session original, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read. The controlling text (`docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md` RC-05 at `:133-144` and its resolution row at `:234`) was read fresh this round — no guard denial. Nothing was edited. I did not run Forge.
- **Date:** 2026-10-18.

## Verdict: Close RC-05. No such function remains in current source.

## The September claim, confirmed as historical and absent today

The claim: `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol:736-754` (September numbering) held an abstract `exchangeOut` that refunded `maxAmountIn - amountIn` on the true flag, with no `LocalCreditLib` budget and no `requirePretransferCaller`.

Current source, verified directly:

- **The named file no longer contains any `exchangeOut` implementation.** A full read-pattern grep of `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol` finds zero `exchangeOut`/`maxAmountIn` declarations; its only hit is an outbound *call* to the SE dependency (`IStandardExchangeOut(l.standardExchange).exchangeOut(...)` at `:349`). The pre-remediation function is deleted, not merely uninstalled.
- **The family has exactly one public `exchangeOut`**: `UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol:750`. No second public `exchangeOut` with the unguarded refund exists anywhere in the family tree (family-wide grep).

## The installed route is the guarded one

`SeTarget.sol:750-761` dispatches liquidity routes and the swap path. The swap path (`_swapExchangeOut`, `:763-792`) computes the exact-out quote, rejects over-max (`:775`), and takes input through `_pullExactOutInput` (`:778`). That helper (`:907-914`) is the guarded form, read in full:

- `_securePull(token, used, pretransferred)` — whose true-flag branch (`:885-890`) calls `LocalCreditLib.requirePretransferCaller(msg.sender)` and caps the claim at the unbooked balance;
- then refunds only `LocalCreditLib.budget(_unbookedBalance(token), maxAmountIn) - used` (`:912-913`) — the credit cap, exactly as D9/D15 require.

The refund is `credit - used`, never `maxAmountIn - amountIn` without the cap. The comment at `:905-906` states the same law.

## Acceptance criteria check

- The unused function is **deleted** — one of the PRD's two permitted resolutions; I do not choose between them, and none is left open. (The assignment's prohibition on choosing is about the residual decision; the source shows the deletion already happened.)
- Installed selectors/cut: untouched by the absence — the function was not on the cut, and the installed SE facet helper is unchanged.
- Source retains no second public money implementation with the unguarded refund — verified by family-wide search, not by a comment or the cut.

## On the alert's history

The September attribution (Grok-1, strengthened by Kimi's no-inheritor search) was accurate for its tree: the function existed and was unsafe. Today it is absent and the only remaining route is the guarded one. The alert was real at filing; it is resolved now. Source-presence verdict; no Forge run by me; nothing here speaks to deployed bytecode.

Close RC-05

I did not run Forge.
