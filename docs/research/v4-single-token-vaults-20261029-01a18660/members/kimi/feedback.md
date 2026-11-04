Ask: Conduct one advisory on frozen draft v4-vault-comparison-r1 - wanted: one disposition, substantive corrections, peer dispositions, and limits. For you: **SUPPORT**, with no substantive corrections. `apply_patch` remains inactive, so `/members/kimi/feedback.md` was not written; the complete advisory follows inline without substituting another write mechanism. Now: none - all tasks closed. Next: none.

# Kimi advisory on frozen draft v4-vault-comparison-r1

## Disposition: SUPPORT

I support the frozen draft without requesting substantive correction. It preserves the brief's distinction between actual single-token entry and actual single-token exit, does not inflate seven useful architecture families into seven equally established production products, and gives the decisive output and deployment caveats unusual prominence.

The seven-family comparison is fair: six shared-capital designs and ZapVault's separately accounted per-user design are accurately distinguished, while conditional, asynchronous, prototype, verified-source, and publisher-deployment evidence are not collapsed into one maturity claim.

## Substantive concerns and proposed corrections

**None.** I found no factual or scope error material enough to request a change.

The draft specifically gets the disputed points right:

- **ZapVault fee semantics:** canonical `PoolManager.modifyLiquidity` computes `callerDelta = principalDelta + feesAccrued`. Ignoring the second return value therefore does not, by itself, establish lost fees. The draft correctly replaces MiniMax's unresolved-fee concern with the canonical accounting fact while retaining ZapVault's real min-out, deadline, residual-accounting, same-pool conversion, and owner-power limitations.
- **Weir output semantics:** verified-source evidence supports native selected-leg withdrawal, but settling both deltas without a full-spend postcondition can leave residual unwanted currency. The draft correctly avoids calling it an unconditional one-output exit. It also properly limits the zero-vault UI observation rather than turning it into an RPC claim that no instances exist.
- **The Pool:** actual V4 position plumbing and fixed-asset zap entry/exit are separated from the unverified current adapter configuration, funding, and operation. That is the right qualification strength; verified source is not treated as proof of a working current route.
- **ALPS:** the actual `UniV4Adapter.getTwapSqrtPriceX96` returns zero, and the unwind guard skips automatic V4 non-base conversion. The draft correctly makes USDC exit conditional on idle/realizable proceeds and keeps `redeemInKind` separate rather than calling it single-token withdrawal.
- **USDa/Ascnt:** automatic dual-token payout on conversion failure, including relaxation of the requested aggregate one-token `minOut`, is explicitly disclosed. The conditional classification is correct.
- **Unoxi:** individual one-token orders are not misrepresented as on-demand atomic entry; two-sided round requirements, asynchronous exit, possible refusal/refund, and confidential-computation dependencies are clear. The example's `PinnedReference` is properly not promoted to a proven independent market oracle.
- **Deployment and audit evidence:** publisher manifests, Sourcify matches, testnet receipts, current operation, funded positions, and audits remain separate evidence axes throughout.

## Overlooked candidates from my original

These are optional near-match additions, not reasons to change the seven main families:

1. **CuratedLP** is a useful negative control: ERC-20 shares over a V4 hook, but paired wstETH+USDC entry and proportional two-token withdrawal. **UniSD** is the complementary output control: one-stable entry but proportional basket withdrawal. If the coordinator wants the near-match table to cover more output shapes, add one compact row for both.
2. **RangePilot** could be distinguished explicitly from generic Range/wallet-position products: its documented owner deposit takes `amount0` and `amount1`, and single-sided LP is roadmap. This is nonessential but would avoid conflating the AI-managed `UserLPVault` with the separate Range lead.
3. **MaxFi** is another wrong-AMM exclusion alongside Topaz: its official supported venues are V3, Aerodrome, and PancakeSwap. Adding it is optional breadth, not a substantive omission.

The draft already preserves my more important Unoxi candidate and the unresolved unisafe/BTR/Grimoire leads. It also appropriately includes The Pool from Astra and corrects my earlier Weir description by adding the residual-output caveat.

## What I did not adopt from peers

- **MiniMax's unconditional “confirmed match” labels:** I do not adopt them for Weir, ALPS, or USDa. Weir can leave a second token; ALPS can skip necessary V4 conversion; USDa can automatically pay two tokens. The draft's conditional wording is stronger and more accurate.
- **MiniMax's unresolved ZapVault fee concern:** I do not retain it after checking canonical PoolManager. The unused `feesAccrued` return is not evidence that principal-plus-fee `callerDelta` excludes fees.
- **Grok's earlier evidence limitations:** I do not carry forward “Weir source not obtained” after the verified-source record, or its narrower treatment of OpenZaps as merely swap infrastructure. The draft reasonably reflects the later verified Weir source and OpenZaps' documented-but-unconfigured LP routes.
- **Any production-safety implication:** I do not adopt repository popularity, test counts, verification records, hackathon deployment claims, or self-review as an audit or present operational endorsement.

## Limits of this advisory

I read the complete frozen draft and all four original responses, including the truncated remainder of MiniMax's original. I did not read peer feedback. I made no new broad search and consulted only the cited canonical PoolManager source for the concrete fee-delta question:

https://raw.githubusercontent.com/Uniswap/v4-core/main/src/PoolManager.sol

I did not re-verify every cited source, execute transactions, query current chain state, reconcile deployed bytecode, or perform an audit. Observations about The Pool, Weir, ALPS, USDa, and Unoxi otherwise rely on the admitted draft/originals and their cited primary evidence.

This is one advisory pass only; it neither replaces my original nor authorizes implementation.
