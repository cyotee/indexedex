# Coordinator draft

## Draft identity

- Draft ID: se-zap-relevance-20261031-01a18660-r1
- Path: docs/research/se-zap-relevance-20261031-01a18660/coordinator/draft.md
- Run ID: se-zap-relevance-20261031-01a18660
- Status: pending advisory review. This file is not the final.
- Fingerprint: not computed
- Sources: members/astra/response.md, members/grok/response.md, members/minimax/response.md, members/kimi/response.md

## Participation

- Council kind: full
- Requested members: Astra, Grok, MiniMax, Kimi
- Substantive initial responses: Astra st_01a192e9, Grok st_01a192ea, MiniMax st_01a192eb, Kimi st_01a192ec
- Missing initial responses: none
- Result label: full
- Coordinator mode: invoking agent
- Coordinator is an independent vote: no

## Question

Does the adopted design configure `maxZapBps` and `maxZapTickMove`, are those caps relevant, and is `previewZapCredit`'s per-currency split useful to a caller?

## Proposed text

These are recommendations. They do not lock the PRD and do not authorize implementation. No cap number is chosen.

All four originals agree that Weir does not configure `maxZapBps` or `maxZapTickMove`. Weir's zap controls are the deposit `zap` flag, withdrawal `zapTo` of 0, 1, or 2, at most one in-pool swap, the global square-root-price endpoints, output minima, and a refund of unused input. `perfFeeBps` cuts harvested fees. It is not an entry-size cap.

The full-spread PRD lists both fields in `PkgArgs` because that section says `PkgArgs` is the PairToken set. That is not a Weir configuration. The public getters remain open. A package field is not the same artifact as a getter.

All four originals agree that the two caps are not required to reproduce Weir, and that they do work Weir's own limits do not. A size cap is a reserve-relative bound. Weir's half-imbalance swap scales with the caller's deposit, not with pool reserve. A tick-move cap is a local bound on the entry swap. Weir's price limit is the pool extreme, so a partial fill can still move the tick a long way. `minShares` is not a substitute for either bound. Whether to keep that extra policy is an adaptation decision, not a Weir import requirement.

The per-currency split is not returned by `previewExchangeIn`. That preview returns shares and one same-token refund. A caller cannot reconstruct two credited amounts and two uncredited amounts from those two numbers, because the entry swap moves value between the currencies.

Whether that split is useful depends on the residual policy. See the disagreement table. Under a Weir-style refund of unused input, the reason to inspect a booked no-share remainder does not survive.

## Preserved disagreements

| Topic | Positions | Not resolved in this draft |
| --- | --- | --- |
| Compound use of the size cap | Kimi would not import PairToken's compound quarter-cap coupling. MiniMax says the size cap should be stated as entry-only, because that coupling was not adopted. Grok includes the inherited compound quarter-cap in the work the size ceiling still does. Astra does not decide the compound use. | Whether a retained size cap also bounds `compound()`. |
| Booked residual | MiniMax says the full-spread PRD already books `J_i` without extra shares and says previews disclose it, so the uncredited pair has a locked use. Astra, Grok, and Kimi say that booked-residual policy is not an owner lock. Grok says the decision use exists only under that written rule. | Whether the current PRD text is an owner lock of booked residual. |
| Split after a refund | Astra would not keep `previewZapCredit` solely for the booked-residual rationale if unused input is refunded. Grok says the decision use does not survive a Weir refund. MiniMax says the uncredited pair would be zero and the preview should be judged again. Kimi keeps a narrower execution-breakdown use, with refund-aware semantics, and rejects the preview if its fields only expose booked residuals. | Whether a refund-aware credit breakdown is still worth a public preview. |

## Evidence gaps

- No original executed a deposit. The cap comparison is a reading of the source.
- MiniMax also read a frozen upstream Weir snapshot. The other three verified the import PRD and `WeirVaults.sol`.
- Whether `previewExchangeBundleInForSingleOut` already returns a credit split was not checked.

## Coverage adopted from responses

| Target | Status | Adopted from | Conflict or gap |
| --- | --- | --- | --- |
| Weir has neither cap | Read | All four | No conflict. |
| Caps do work Weir's limits do not | Read | All four | No conflict on the distinction. Conflict on compound coupling. |
| Split versus `previewExchangeIn` | Read | All four | No conflict that the four fields are absent from that preview. Conflict on whether the use survives a refund. |

## Limits

- Static reading only. No execution was run for this draft.
- This draft does not claim permission confinement.
- Original response files were read and are preserved.
- No project code, configuration, or Git action is authorized by this draft.
- The coordinator did not vote on the two open splits.
