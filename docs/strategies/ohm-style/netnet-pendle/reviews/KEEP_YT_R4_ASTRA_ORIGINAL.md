# Astra — Keep-YT R4 original first pass

**Finding:** For an already seeded Pendle market, Keep YT is **tokenization plus a proportional PT/SY join, not a PT purchase followed by deposit**. That materially reduces the large-rollover price-impact concern, but does not make every conversion costless.

## Observed execution

Let `X` be SY input, `T` existing PT reserves, `S` existing SY reserves, and `a(S)` the current PY-index conversion into PT/asset units. The router allocates:

`SY_to_tokenize = floor(X*T / (T + a(S)))`.

It transfers that SY to YT, sends remaining SY to the market, invokes `YT.mintPY(market, receiver)` so PT goes directly to the pool and retained YT to the receiver, then calls `market.mint`. Both LP and YT outputs have minima. No Pendle swap occurs in this helper. Rounding still applies.

Local evidence: `lib/crane/contracts/protocols/perps/pendle/router/ActionAddRemoveLiqV3.sol:272–302`. In contrast, ordinary single-SY addition explicitly calls `swapSyForExactPt` (`:178–220`). The token-input Keep-YT wrapper first calls `_mintSyFromToken` (`:236–248`); `router/base/ActionBase.sol:26–64` permits either direct supported-token SY deposit or an external aggregator conversion. Thus **Keep-YT market entry has no PT/SY swap impact; arbitrary input conversion may**.

## Rollover implications

- **Expired source:** router removal burns LP into SY plus PT, sends PT to YT, and calls `redeemPY` (`ActionAddRemoveLiqV3.sol:410–432`). It does not sell expired PT through the AMM. Preserved interest/reward claims need separate reconciliation.
- **Same SY:** realized principal can enter the successor Keep-YT route directly, while maintaining separate accounting for preserved income.
- **Different SY:** redeem old SY into a mutually supported NET/sNET face, then deposit into new SY, if actually supported. This need not involve an exchange trade, but pause conditions, fees, taxes, synchronization, rounding and liquidity constraints require verification. Never treat old SY units as new SY units (PRD v0.14 `:469–505`).
- **Empty target:** the Keep-YT split divides by `T+a(S)`, which is zero for an empty market. It is not a bootstrap path. A separate controlled dual-asset seed can establish PT/SY balances; local `MarketMathCore.sol:110–126` supports initial liquidity with minimum-liquidity deduction. Target seed ratio/initial pricing and valid expiry need specification—not arbitrary caller selection.

## Recommendation and limits

Prefer investigating **one atomic expired-source realization → compatible SY conversion → seeded-target Keep-YT join**, with whole-transaction rollback and actual LP/YT/conversion minima. Atomicity remains a preference, not final authorization.

Splitting a swap into same-transaction chunks does not inherently erase aggregate price impact. Interleaving liquidity additions changes execution and must be compared at equal final exposure, including fees. With Keep YT there is no necessary PT swap to split; chunking mainly adds gas/rounding. Across transactions, replenishment may help but introduces price/MEV and intermediate-state risks.

Record the selected HLP proportional, subset/unbalanced and single-token NET/sNET/USDG/DETF modes and USDG-bond lock alignment. These custom-hook variants are distinct from Pendle router entry modes; preserve reused Weighted domain limits and report actual incompatibilities.

**Two economic clarifications:**
1. Is proposed opening **1 DETF = 1000 NET** launch pricing only, while the ongoing target remains **1 NET**?
2. Is proposed **0.5% per processed NET epoch** applied to which supply/base, with what premium gate and catch-up compounding convention?

**Evidence/limits:** Context7 attempted first; primary [router source](https://github.com/pendle-finance/pendle-core-v2-public/blob/main/contracts/router/ActionAddRemoveLiqV3.sol) corroborates these paths (accessed 2026-09-25). Solidity `^0.8.17`; local and upstream revisions differ elsewhere and are unpinned. High confidence in inspected flow; no live Robinhood equivalence, gas test or economic proof. Token-policy blocker remains. Metadata: Astra, supplied `openai/gpt-6-astra`, not provider attestation.
