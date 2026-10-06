# Upper/Lower Wings PRD council consolidation

Date: 2026-10-05. Four independent originals and four combined cross-reviews completed. Each researcher resumed its retained session, read the other three complete original artifacts together and was forbidden to read cross-reviews. Model findings remain untrusted evidence, not product authority.

## Artifacts and continuity

| Member | Retained session | Original | Cross-review |
|---|---|---|---|
| Astra | `ses_ef7c68835ffey58T5UT2G8JDZo` | [original](astra-original.md) | [review](astra-cross-review.md) |
| Grok | `ses_ef7c1c50fffe87e6QGupvs3xke` | [original](grok-original.md) | [review](grok-cross-review.md) |
| MiniMax M3 | `ses_ef7bc045effeTc96xsW5R2MidY` | [original](minimax-original.md) | [review](minimax-cross-review.md) |
| Kimi K3 | `ses_ef7b7b72fffe3JJ0CVG6FmBRGL` | [original](kimi-original.md) | [review](kimi-cross-review.md) |

Final moderator document: [PRD](../../plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md). No implementation plan.

## Initial positions

- Astra: three-position accounting, complete scalar/blocked route specification and broad consumer/transaction-gas evidence; geometry and economics require selection.
- Grok: separate identity, custody split and explicit economic choices; initially left even scalar admission and native SY too open.
- MiniMax: initially proposed full-range center, reversed wing orientation, deferred scalar entry and copied FullSpread protections. These were not owner-approved requirements.
- Kimi: found primary historical documentation of frozen finite center, 10% center budget and upper-token0/lower-token1 wings; emphasized sleeve and own-wing crossing economics.

## Corrections and unresolved dissent

1. **History:** all distinguish center-only `92cdf89a^` from the historical three-wing locator. No researcher retrieved the old commit in this round. Earlier gas figures cannot establish wing cost. Documentary restoration of intent is not byte-for-byte provenance.
2. **Orientation:** local `LiquidityAmounts.sol:67–76` establishes upper=token0 and lower=token1 at activation. MiniMax corrected its original inversion. Grok's cross-review introduced the inversion again and incorrectly called historical orientation wrong; the moderator rejects that conclusion.
3. **Geometry:** Astra's finite contiguous proposal is coherent. MiniMax's full-range center plus wings bounded by identical extrema produces zero-width wings and is rejected. Kimi's cross-review proposes a different gapped/extrema envelope and inconsistent width description; it is not silently merged with the contiguous design.
4. **Scalar entry:** banning useful single-token admission conflicts with the request. Composition versus direct invariant pricing remains unresolved. Reusing a proportional composition solver may reproduce the gas issue; direct one-sided placement alone is not a share-pricing rule.
5. **Sleeve:** Astra proposed historical percentage-of-total; Kimi recommended current `F=pD`. Grok's stated formula `p*D/(1+p)` mismatches its variables. Moderator proposes `T*p/(1+p)` with `T=F+D`, pending explicit owner approval. No false consensus.
6. **Gas:** reject portable 31M, stale block-limit figures and whole-test gas as transaction measurements. Runtime/dependency/fork identities and actual outer transaction evidence required. A proposed 90% cap margin is moderator policy for review, not measured capability.
7. **Weighted:** eight buffered standalone legs are valid; eight plus a raw self-leg exceeds eight total. MiniMax's claim that all eight-buffered is invalid is rejected. All legal configurations must be enumerated; no wrapper substitution or silent sampling.
8. **Safety parameters:** proposed TWAP windows/bands differ and were not calibrated. None is adopted as a proved safeguard. Native/import/hooked-underlying scope and numerical work bounds remain owner decisions.

## Confidence and limitations

High confidence in token orientation, distinct custody/backing, no nested unlock and need for honest transaction-gas evidence. Historical source closure, scalar pricing safety, exact inverses, manipulation bounds and useful eight-leg gas remain unverified. No production-readiness claim.

Grok and Kimi disclosed using their available write tool rather than requested apply_patch for assigned originals; document writes were within assigned allowed paths. Incidental LSP messages do not establish pre-existing compiler errors; MiniMax's attribution of those errors is not adopted. Earlier-session independence caveats remain in their prior records; no new peer-original exposure was reported before this round's cross-review.

## Human checkpoint and implementation handoff

Review PRD §15, especially scalar economics, frozen geometry and sleeve convention. Once selected, revise the PRD and only then commission the separate implementation plan. No implementation, tests, config, restoration or deployment occurred in this round; preserved FullSpread and existing restoration are untouched.
