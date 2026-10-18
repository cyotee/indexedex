# Kimi K3 — cross-review: RC-06 unwrap originals

- **Label:** Replacement-session cross-review, resuming my check (`kimi-original.md`). I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. MiniMax is the labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. The three peer originals were read in full as untrusted output; the unwrap function and its callers were read directly by me this session. Nothing was edited.
- **Date:** 2026-10-18. I did not run Forge.

## Verdict: agree — Close RC-06. The unwrap no longer reports the approval cap as shares spent; it reports nothing.

Four passes, one mechanism, no divergence on any checkable fact:

1. **The function is void.** `_unwrapExactTokenOut` (`UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:711-727`) has no `returns` clause — the misreported share count does not exist to be wrong. This is the PRD's permitted removal outcome, present in source, not a chosen recommendation. All four passes verified the same signature and body.
2. **Every caller is statement-form.** The family's three call sites — `Common.sol:758`, `SeTarget.sol:144`, `SeTarget.sol:213` — assign nothing. Astra's caller table (`:29-35`) additionally verifies the enclosing functions' own returns are their separately computed swap inputs, so no stale share count propagates upward. Consistent with my grep.
3. **No cap-as-spend pattern survives.** No `seIn = maxIn` / `return maxIn` form anywhere in the family; the only `maxIn` left is the local tight cap set from the quote (`:719`), approved and zeroed (`:720`, `:725`), with the short-delivery rejection intact (`:726`).

## Recorded from peers

- **MiniMax's wider check** — the `_unwrapSeShares` overloads (`:691-708`) return `pairOut` (underlying received) and `_swapExactOutExecute` returns its quoted `amountIn` — confirms no sibling helper carries a share-spend misreport. Consistent with my reads; adopted. His September dissent (unused assignment, no functional impact) is not relitigated in his current pass, and it is moot either way: the removal resolution is already in the tree.
- **Astra's boundary note** (`:39`) is the precise statement: closure does not rest on callers ignoring a still-misleading return — the return is absent. Adopted as the record's phrasing.
- **Grok's** terse form matches the shared evidence; no divergence.

Minor transcription note: peer quotes of `_swapExactOutExecute` differ by one line in range formatting (Astra `750-764`, MiniMax `750-765`, with the call shown at `:757` in MiniMax's quote and `:758` in current source as I read it). Immaterial — all show a bare statement call; the current-source line is `:758` by my read.

## On history

The September claim (Grok-4, agreed by Astra and Kimi) was accurate for its tree: the cap was assigned to the returned count and the SE's spend discarded. The current tree carries the removal resolution. The alert was real at filing; it is resolved now.

## Unresolved dissent

None. The closure rests on an absence (no return clause) each pass read directly, plus the three call sites read by every pass. Consensus is not proof — here the evidence is a signature line, which does not need a run to evaluate.

Close RC-06

I did not run Forge.
