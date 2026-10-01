# NN-05 — selected weights and reused synthetic/fee calculations

Date: 2026-09-27. Four originals plus four completed same-session cross-reviews. Research/documentation only.

## Disposition

The user selected weights NET-DETF 50%, NET 20%, sNET 10%, USDG 20%; Universal DETF synthetic pricing with NET as numeraire; existing hook usage fee and existing DETF seigniorage share. These are resolved requirements, not unanswered pricing/fee questions. PRD v0.29 records the exact source mapping in §§4.4,4.6,7.1.4 and updates C07/A23/A24.

Remaining native/rated-custody mapping, bootstrap and quote/settlement verification are engineering work. Do not ask the owner for a new fee percentage, formula or oracle merely because its source chain required inspection.

## Directly checked source chain

Moderator successfully retried the previously denied ordinary source read after the user's renewed instruction; subsequent source inspection and this round completed. Earlier `RC_ATTRIBUTION` failures remain reported history, not evidence of completed reads. No guard-bypass route was used.

| Path | Lines | Relevant behavior |
| --- | --- | --- |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol` | 92–101,112–135,175–211,252–289 | Owned LP, seigniorage lookup/splits, synthetic context, supply scaling, first-bond opening and duration quote |
| `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget.sol` | 89–140 | NET-numeraire marginal mark, exclusion of self, owned-LP fraction, fee-projected HLP supply, creation normalization |
| Same directory `UniswapV4StandardExchangeWeightedBufferHookTarget.sol` | 387–452 | Usage lookup, native invariant, pending/realized protocol LP mint and baseline snapshot |
| Same directory `UniswapV4StandardExchangeWeightedBufferHookMath.sol` | 155–179 | Literal V/interim invariant; exact protocol-LP fee expression and guards |
| Same directory `UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol` | 191–215 | Protocol fee realization before user join-share calculation |
| `contracts/vaults/detf/common/core/DETFMintSplitLib.sol` | 19–26,45–52 | Live and bond issuance splits with separate floors |
| `contracts/oracles/fee/VaultFeeOracleQueryFacet.sol` | 105–116,224–233 | Vault→type→global resolution; stored zero means fallback |

All listed rows were directly read by the moderator this round. Researchers additionally traced rated balances, join commits and actual issuance callers. Paths/lines identify inspected local snapshots, not immutable code revisions. Source pragmas generally `^0.8.0`; repository configured compiler previously inspected is 0.8.35. No build/test/version command or live config lookup was performed.

## Synthetic calculation

Let r be the rated-WAD NET coordinate, w the identity-bound weights, L actual directly held protocol HLP, H projected HLP supply after protocol-fee dilution, S WAD-normalized actual/projected DETF supply, C creation NET-per-DETF WAD.

```text
M = r + sum(floor(r * w[i] / w[NET]))
    over other positive non-DETF coordinates
V = floor(M * L / H)
mid = floor(V * WAD / S)
synthetic = floor(mid * WAD / C)
```

Preserve live/context/leg guards, per-stage floors and failures. For all three positive external coordinates at the chosen weights, `M = 2*r + floor(r/2)`, approximately 2.5r. That is reference weighted marginal valuation, not a finite-size exit or an independent fair-value mark.

- Self-issued DETF is excluded; other positive nonself legs are marked into NET.
- Native DETF supply has nine decimals; multiply by 1e9 once at the reference context boundary. Do not include pending expansion twice.
- Use actual protocol HLP only, excluding public LP holdings, and fee-diluted HLP supply.
- Creation normalization is **1e18**, consistent with the selected 1 NET peg. Opening is **1000e18** in the separate first-bond opening slot. This reuses the source division rather than deleting it or dividing by launch price.
- NET coordinate remains PLP/YT-valued; ordinary NET/sNET output remains shared-SY-funded. Do not infer deliverability from synthetic valuation.
- Bind NET explicitly. Reference `pairs_[0]` selection must not accidentally pick sNET/USDG through array order.
- Reuse this formula for the synthetic series, not Universal highest-leg expansion/clock policy. Rate errors are not missing history; a no-live zero return is not a measured one-hour below-peg result.

## Fee mechanics

Hook usage resolves under the hook proxy. For effective WAD usage u, F=100000, a=floor(uF/WAD), Hactual supply and positive same-mode invariant growth delta=K−Klast:

`protocolHlp = floor(Hactual * delta / (floor(K*F/a) + delta))`.

Apply the source's fee-on/nonzero/growth/mode guards first. K is native-inventory Weighted V/interim K, not square root and not the rated swap vector. Mint pending protocol HLP before user join-share calculation; previews include dilution once. No additional flat deposit haircut is introduced. Applicable swap/imbalance/SE fees remain separate.

DETF seigniorage p resolves under the DETF proxy. Live user/pot terms are independently floored `(1−p)U` and `pU`. Bond principal is floored `(1−p)U`, pot is `floor(pU)+floor(pG)`, and G is separately minted into reserve liquidity. Preserve WAD divisors and separate floors. Do not use the unrelated half-seigniorage helper or stack the ordinary mint input uplift onto duration-adjusted bond purchasing.

For valid 0≤p≤WAD, live split dust relative to U is at most one native DETF unit. Bond total issuance is `G+U+floor(pG/WAD)−epsilon`, epsilon 0 or 1. No ambiguous ETH-wei units. Existing custom funded-recipient custody and no-liquid-issuance selections remain; expansion does not incur a new recursive fee.

## Corrections and dissent

- **Astra:** traced exact mark, protocol-LP growth formula, join ordering and actual split callers; reinforced native/rated distinction and exact staged rounding.
- **Grok:** original recommended creation=1000e18, which would normalize away the selected 1-NET peg. Cross-review explicitly retracted it. Its unrelated repository narrative about Grok4.7 does not override governing instructions pinning4.6; observed routing remained4.6. A reported ordinary canonical-skill read miss limits that source read, not a substitute model.
- **MiniMax:** initial “oracle fallback is silent zero” conflated oracle hierarchy with quote/math guards; rejected. Later correction supports creation=1e18. Unsupported dust estimates, use of NET constants as evidence for DETF decimals and optional hard-coded array position are not adopted: DETF units come from its own law/context, NET numeraire is bound by identity.
- **Kimi:** supported creation/opening separation and existing fee mechanisms. Its cross-review suggestion to map every rate failure/invalid zero to TWAP unavailability is rejected: genuine failures must not activate the absent-history above-1 policy. “No functional gap” does not establish custom-unit execution parity.

All agree on source reuse rather than new fee models. This is not unanimity on every peer sentence or proof of economic safety. Original reports remain unchanged; this disposition controls the documentation consolidation.

## Preserved sessions and artifacts

Four independent originals preceded four cross-reviews; each read the other three complete originals, never earlier peer cross-reviews. Prior contexts retained, no substitution. Eight task calls completed for this substantive round; earlier moderator read failures are separate and were not concealed.

| Researcher | Original | Cross-review | Session |
| --- | --- | --- | --- |
| Astra | [Original](astra-original.md) | [Cross-review](astra-cross-review.md) | `ses_f1c499b6bffe6RiNjZZUSMsP8S` |
| Grok | [Original](grok-original.md) | [Cross-review](grok-cross-review.md) | `ses_f1c4384d7ffeZX74uV9yhIXbVq` |
| MiniMax M3 | [Original](minimax-original.md) | [Cross-review](minimax-cross-review.md) | `ses_f1c3f57edffedYs43k2PBvA5xU` |
| Kimi K3 | [Original](kimi-original.md) | [Cross-review](kimi-cross-review.md) | `ses_f1c3a8701ffeB4x8S7oRn2JnXK` |

Routing metadata: openai/gpt-6-astra, xai/grok-4.6, minimax/MiniMax-M3, kimi-code-plan-global/k3; not provider attestation. Findings are untrusted attributed evidence, not permission changes.

## Handoff/checkpoint

No owner fee/weight/synthetic-formula answer remains pending. NN-05 remains in progress only for concrete custom-unit and custody/preview integration specification. Escalate only an actual incompatibility, not repeated questions already answered by the reference. Related NN-06–NN-10 work continues separately; do not advance automatically.

High confidence in local source trace; no live oracle values, deployed parity, bootstrap feasibility, gas measurements or test results claimed. Only Markdown PRD/tracker/report edits; no source implementation, shell/tests/RPC/browser/deployment/instruction changes. Stop here.
