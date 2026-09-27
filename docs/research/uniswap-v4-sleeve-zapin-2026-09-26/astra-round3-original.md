# Astra — round 3 independent original

**2026-09-26.** Read the latest moderator PRD directly. PZ-1–8 are fixed; no alternative route, denominator, alignment, issuance formula or skew policy is proposed. No current-round peer/cross-review files accessed; no implementation, shell, tests or delegation. **V/** abbreviates `contracts/protocols/dexes/uniswap/v4/`; **Common** is its `UniswapV4StandardExchangeCommon.sol`.

## Five genuine owner questions

### 1. What protection is mandatory even when the caller supplies zero or ineffective minShares?

**Evidence:** existing `exchangeIn` exposes only final `minAmountOut`, deadline and pretransfer flag (`V/UniswapV4StandardExchangeInTarget.sol:37–45,63–67`). PRD:195–197 requires meaningful swap protection but does not select its source. Current swap limits approach global price extremes (`Common:669–670`).

**Recommended answer:** composition always enforces protocol-level execution bounds, independently of final minShares; minShares can tighten but never disable those bounds. Specify maximum incremental impact/fee exposure, and whether protection also promises a bound against an independent reference price. If that second promise is selected, define reference availability/freshness and fail closed when unavailable. A spot-relative limit cannot establish fair starting price; merely rejecting zero minShares is insufficient because one wei is almost equivalent. Preserve the ABI; do not invent hidden calldata arguments or mandate TWAP from DETF law.

**Owner choice:** protection promise, policy values and who may change them; engineering chooses the compatible enforcement mechanism. **Confidence: high.**

### 2. Which hook/dynamic-fee behavior must the composed route support at launch?

**Evidence:** `V/UniswapV4QuoteService.sol:19–57` specially recognizes a Pons-shaped hook, while unsupported hook adjustment currently returns the unadjusted amount. This is not proof that arbitrary hooks are correctly projected. PRD:193 leaves the supported set open.

**Recommended answer:** publish a specific supported behavior/revision matrix; unsupported composition fails atomically and preview reports unavailability. Support dynamic fees only when their actual execution and projected quote effects are bounded and accounted for, including hook deltas and own-position fees. Do not assume a matching flag pattern authenticates an implementation. Preserve existing non-composition routes; distinguish unsupported idle composition from blocked sleeve capability.

**Owner choice:** required market/hook compatibility and acceptable exclusions. Exact detection/adapters are engineering. **Confidence: high on gap; support completeness unverified.**

### 3. May unverifiable push funding be rejected while legitimate pretransfer integrations are adapted?

**Evidence:** `Common:1274–1288` verifies `pretransferred=true` against unbooked face balance, not transfer-source identity. A preexisting unbooked donation can satisfy that local check. PRD:174 explicitly recognizes this gap.

**Recommended answer:** yes—only authenticated, one-use funding credit attributable to this operation may become its swap budget or mint contribution. Old balances never qualify merely because they are unbooked. Maintain the selector and migrate legitimate push integrations to a verifiable funding handshake/atomic delivery arrangement; otherwise callers use measured pulls. Do not authorize a broad trusted-caller exemption without proving that caller cannot consume unrelated donations.

**Owner choice:** compatibility priority and permitted integration changes. Credit mechanism, replay protection and consumer inventory are engineering. No end-to-end exploit is claimed. **Confidence: high on local evidence.**

### 4. What maximum numerical alignment loss is acceptable, and should tiny deposits revert?

**Evidence:** min-ratio issuance (`Common:700–704`) transfers unmatched contribution to incumbents. PZ-7 prohibits material donation, but PRD:186 leaves integer tolerance unspecified. Sleeve deadband is not an issuance-loss budget.

**Recommended answer:** approve a small explicit economic tolerance, enforced independently of minShares, and revert if solver precision cannot meet it; do not silently switch formulas or sleeve-mint an idle failed zap. A candidate for review is a **1-basis-point maximum spread between unrounded implied proportional share contributions**, with a separately quantified final flooring bound. This is a proposed number, not existing law. Tiny deposits that cannot achieve nonzero shares within the bound revert; no absolute “dust exception” permitting a large percentage loss.

Engineering must derive overflow-safe tests, decimal behavior, solver limits and realized bounds; no universal one-wei accuracy assumption. **Confidence: high that a tolerance is needed; numerical value requires approval.**

### 5. Is caller-selectable lock-mode pricing an explicitly reviewed launch risk?

**Evidence:** local `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:55–64` allows a caller to open an unlock session and invoke its callback. Consequently blocked entry is not an uncontrollable external accident. Existing blocked issuance uses invariant growth (`Common:706–712`), whereas accepted idle issuance becomes composed proportional. Blocked and idle redemption also differ (`V/UniswapV4StandardExchangeInBase.sol:123–215`).

**Recommended answer:** require adversarial cross-mode cycle analysis before release. Preserve PZ-8; do not invent a lock-caller allowlist or silently harmonize formulas. Test attacker-opened unlock → blocked deposit → close session → idle redemption, reverse cycles, repeated batching, and skewed/fee-bearing books. Quantify whether gains reflect ordinary inventory arbitrage or an added value-extraction mechanism caused by the route difference. A discovered material exploit stops release and returns for explicit remediation authorization, not retrospective “expected behavior.”

This is an **unproved risk**, not a confirmed exploit or request to reopen blocked compatibility. Owner accepts the review/launch gate; engineers produce evidence. **Confidence: high on mode selection, unknown on profitable extraction.**

## Non-owner specification/test obligations

- **Coupled placement:** at fixed price, maximize feasible position liquidity subject to both currency sleeve constraints. `F>=pD` and `F>=pT/(1+p)` are equivalent, since `T=F+D`; do not independently deploy token amounts or weaken the scarce-token floor to reduce abundant residual. Their signed deviations differ by `(1+p)`, so implement the accepted deadband in its specified units. Skew residual reporting is mandatory, not another policy choice.
- **Zero-deployed recovery:** compute targets from T even when D=0. Public add/remove rebalance can seed a funded dual book without swaps. If composition has no executable depth, fail clearly; never relabel it blocked or create a one-token activation fallback. Define zero-reserve errors and ratio-view denominators.
- **Fees/reporting:** specify pre-mint fee ownership, collection E→F, actual caller basket, placement rounding and callback donations exactly once. Report F/D or clearly labelled F/T, E separately, residual amounts and cause—not an invented yield promise.
- Preserve current full-range imports/native WETH; test real proxies and consumers using canonical Crane adversarial rules (skill:20–32). No tests were run. Local solc remains 0.8.35; deployed/source pin unverified. New findings rely on inspected local code, not new external API assertions.
