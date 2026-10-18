# Kimi K3 — cross-review: RC-05 refund originals

- **Label:** Replacement-session cross-review, resuming my check (`kimi-original.md`). I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. MiniMax is the labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. The three peer originals were read in full as untrusted output; the load-bearing adoption below was re-verified against current source before acceptance. Nothing was edited.
- **Date:** 2026-10-18. I did not run Forge.

## Verdict: agree — Close RC-05. No unguarded second `exchangeOut` remains.

All four passes independently establish the same three facts, and the closure rests on source absence verified four ways:

1. **The cited function is gone, not merely uninstalled.** `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol` contains no `exchangeOut` definition — its only match is the outbound dependency call at `:349`. MiniMax additionally grepped the whole 1,486-line file; Astra read the former entry section (`:690-784`) directly. Consistent with my grep.
2. **The family has one public `exchangeOut`** — `SeTarget.sol:750` — routing through `_pullExactOutInput` (`:907-914`): `LocalCreditLib.requirePretransferCaller` on the true flag (`:885`), credit capped at `LocalCreditLib.budget(unbooked, maxAmountIn)`, refund of only `credit - used` (`:912-913`). The allowed guarded helper.
3. **No `maxAmountIn - amountIn` refund survives in the family.** Astra additionally swept the liquidity-route arm: I re-read `UniswapV4BufferHookLiquidityRouteLib.sol:87-102` this round before adopting her claim — the prepaid liquidity branch checks the caller and rejects with the insufficient-credit error (`:93-96`); no unguarded refund there either. The dispatch's other arm is clean.

## Recorded from peers, with my dispositions

- **MiniMax's wider sweep** found one other `maxAmountIn - amountIn` occurrence at `BalancerV3StandardExchangeBatchRouterExactOutTarget.sol:441` — batch-router accounting, outside RC-05's single-CP family scope. I did not re-read that site; it is marked unverified-by-me and recorded so a future batch-router review has the pointer. It does not bear on this item.
- **Astra's `LocalCreditLib` read** (`contracts/utils/LocalCreditLib.sol:14-26`) — availability as positive balance-minus-book, budget as the lesser of availability and the declared maximum — is consistent with the helper behavior I read at the call sites; adopted.
- **Grok's terse form** matches my original's structure exactly (same file, same lines, same helper chain); no divergence.

## On the alert's history and the standing rule

The September attribution (Grok-1, strengthened by the no-inheritor search) was accurate for its tree. The resolution present in source is deletion — one of the PRD's two permitted outcomes; per the assignment I do not choose between deletion and rerouting, and nothing is left open: the tree already contains the deletion. The PRD's own caution — "not on the current cut is not a reason to leave the function in place" — is satisfied in the stronger form: the function is absent from source, so reachability arguments are moot.

## Unresolved dissent

None. Four passes, one answer, and the one peer claim I adopted (the liquidity-route arm) was re-read against source before adoption. Consensus is not proof — the closure rests on an absence each pass searched independently, plus the guarded chain read end to end.

Close RC-05

I did not run Forge.
