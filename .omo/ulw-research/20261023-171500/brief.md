# ULW-Research Brief: Uniswap V3/V4 fee-earning single-token vaults

started: 2026-10-23T17:15:00
session: /Users/cyotee/Projects/indexedex/.omo/ulw-research/20261023-171500

## Analysis

Core question: Which existing Uniswap V3 and V4 vault designs hold a reserve that earns swap fees and can be quoted as one token through a Balancer-style rate provider, without pricing that quote off a same-pool spot liquidation?

Axes:
1. arrakis-family — Arrakis V1/G-UNI, V2, PALM, Modular, V4 modules. Deposit token, fee exposure, share quote, rate provider.
2. manager-vaults — Gamma, Charm, Steer, DefiEdge, Visor, Popsicle, Revert, Beefy CLM. Same four fields, plus whether the manager can move ranges without changing the share quote basis.
3. single-sided — ICHI, Teahouse, Orange, A51, and any vault that accepts one token and still earns fees.
4. v4-native — Bunni v2, Panoptic gRHO, Doppler, Angstrom, Ekubo, Arrakis UnderlyingV4, Pancake Infinity / Algebra Integral / Maverick vaults that still face a V3-like position.
5. rate-oracles — Balancer IRateProvider implementations for Uni LP or ALM shares, ERC-4626 convertToAssets, Chainlink NAV feeds, Gyroscope, and any getRate that is not a spot zap-out.
6. pricing-math — How each quote is computed: spot reserves, TWAP, principal plus fees, virtual reserves, external oracle. Which of these survive a same-transaction deposit-swap-withdraw.
7. incidents — Designs that were exploited or shut down because share price tracked manipulable pool state.
8. skeptic — Attack every "this quotes one token safely" claim. Demand the function that computes the rate and the pool it reads.

Codebase relevant: yes. External: yes. Collection: browser. Verification likely: yes, for any claim that a named function avoids spot. X/social signal: no. The question is mechanism and repository evidence, not sentiment.
Scale: 8 axes, many protocol repos, chat-length comparison with a source ledger. Precision demand: a wrong mechanism claim would send a vault redesign down a dead design. Lifecycle: one research team, then a skeptic pass inside that team. Debate need: whether any live vault both earns fees and quotes a rate that does not read the same pool's spot price.

## Product constraint (user, verbatim intent)

Hold a reserve exposed to trading volume so it earns fees, and quote that reserve as a single token so the vault token can be used as liquidity with a Rate Provider. Do not treat "use a reference price for some operations and the zap-out for others" as a solution. The user asked whether a redesign that liquidates the opposing wing into a single-sided target position would work. Prior analysis in this thread: a single-sided position earns nothing until price enters it, and once price enters it the position holds the other token.

IndexedEx rate interface, from lib/crane:

```solidity
interface IRateProvider {
    function getRate() external view returns (uint256);
}
```

A usable pattern must be able to implement that function. getRate is a view. It cannot simulate a swap that moves the pool.

## Deliverable

lane: no-format
state: none
formats: post (answered_by: request)
destination: chat answer the user can use to pick a vault design (answered_by: request)
audience: the user, design decision, deep (answered_by: request)
template: chat markdown comparison, no house template (answered_by: default)
format description: exhaustive comparison of deposit token, fee exposure, single-token quote method, rate-provider existence, and whether the quote reads same-pool spot
qa_tier: light

## Roster

| Member | Category | Axis |
| --- | --- | --- |
| arrakis-family | deep-low | Axis 1 |
| manager-vaults | deep-low | Axis 2 |
| single-sided | deep-low | Axis 3 |
| v4-native | unspecified-high | Axis 4 |
| rate-oracles | deep-low | Axis 5 |
| pricing-math | architect | Axis 6 |
| incidents | unspecified-low | Axis 7 |
| skeptic | ultrabrain | Axis 8 |

Lanes to spawn with the team: 2 explore (IndexedEx rate provider and Wings quote path), 6 web (GitHub NAV code, incident writeups, Balancer rate providers, V4 custody hooks, design papers, remaining ALMs), 1 librarian (Arrakis v2-core share math). Floor 17. x_search: not used.

## Expected truths

- E1. A fee-earning Uniswap position that contains both tokens cannot be redeemed into one token without either a swap or an external price.
- E2. A view rate that reads the same pool's spot reserves can be moved by a swap inside the same transaction as a deposit or withdrawal.
- E3. At least some production vaults already expose an ERC-20 share and a documented NAV method. Which ones avoid E2 is not yet known.
- E4. ICHI-style single-sided vaults are the closest public pattern to "one token in, fee exposure out," and their share price is documented as conservative relative to spot. Confirm or refute from primary code.
- E5. Bunni v2 was exploited and shut down. Do not recommend it. Confirm the failure mode from a primary postmortem.
