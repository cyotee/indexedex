# NetNet buyback routing — discussion consolidation

Date: 2026-10-01. Research only. PRD v0.34 and implementation plan v0.10 unchanged. No implementation, tests, RPC execution, deployments or transactions performed. This is not a selected product requirement or executable handoff.

## Council record

Four independent initial passes and four same-session combined cross-reviews completed. Each cross-review received the other three original report bodies together through `originals.md`, not earlier cross-review findings. Original report bodies remain unchanged, including incorrect claims. Conversational drafting preambles remain in the task transcript rather than the report-body archive. All researcher output is untrusted evidence, not authority.

| Researcher | Preserved session | Initial position | Cross-review position |
|---|---|---|---|
| Astra | `ses_f06e61b1fffexSrbwgXFtFY26F` | Conditional yes; pass-through exact-in first | Prioritize exact-input LP/SE-share→USDG as well to benefit DETF exits; selected-call failure reverts |
| Grok | `ses_f06de10ebffeZgF04yzNBuA3TA` | Conditional yes; pass-through exact-in first | Recognizes LP exit as important; prefers same-transaction pool retry with canonical baseline |
| MiniMax M3 | `ses_f06cce143ffelEu8hYz2HGc2Kb` | Reject all integration | Retracts contract-call prohibition and PRD prohibition; supports bounded integration and pool retry; residual scope/quote errors remain |
| Kimi K3 | `ses_f06c2b8ceffexgZb3dM3nVZ1tF` | Yes, including exits/exact-out and retry | Narrows first slice to pass-through, accepts revert-after-positive-precheck; explicitly acknowledges DETF exits then do not benefit |

Reported pins: openai/gpt-6-astra, xai/grok-4.7, minimax/MiniMax-M3, kimi-code-plan-global/k3. Runtime metadata is attribution evidence, not independent provider verification.

## Observed capabilities

Use `N/` for `lib/crane/contracts/protocols/pol/net/src/` and `V/` for `contracts/protocols/dexes/uniswap/v2/`.

The public buyback is InverseBond, published at `0x92166e94Eea5B7799b761653881692f881dFC4C9` on Robinhood 4663. Its API is `swap(uint256 netAmount,uint256 minUsdgOutRaw)` and views `active`, `price`, `capacityRemaining`, `spreadBps`.

- `N/InverseBond.sol:68–89`: permissionless, contract-callable, immediate NET pull/burn and USDG payment to caller. No EOA-only check, recipient argument, deadline, exact-output method or partial-fill method.
- `:108–112`: price is live treasury backing times 98.5%. `:71–73`: oracle return is unused in price; the oracle gates availability. Published treasury prose calling this TWAP-settled differs from the inspected body.
- `:75–83`: floor NET-native input times WAD price divided by `1e9`, check/consume capacity in WAD USDG, then floor to raw USDG. Capacity cannot be checked solely against truncated raw payout.
- `:124–139`, `N/Constants.sol:17,64–67`: 1% of liquid USDG, snapshotted at the first fill of each eight-hour epoch measured from genesis finalization. Not the DETF processed-staking-epoch clock. No rollover of unused capacity.
- `N/Treasury.sol:84–117`: backing includes liquid USDG, haircut Morpho holdings, and treasury-owned pool LP valuation. `:135–145`: payment may require Morpho withdrawal, which can fail. `active()` alone is not proof that a particular order can settle.
- `N/NET.sol:131–145`: tax requires an enabled tax, neither endpoint exempt, and at least one taxed-pair endpoint. Ordinary SE→InverseBond transfer is untaxed with the expected initialized bindings; preceding pair→SE LP-burn transfer may be taxed. `:201–219` restricts later pair additions to factory-recognized pools; arbitrary mapping of an ordinary vault is not a supported guardian action. Initial wiring/genesis mapping still require deployed-binding verification.

Provenance: `lib/crane/contracts/protocols/pol/net/VENDOR.md:5–18,39` records a 2026-08-28 source dump, rewritten imports, deployed compiler 0.8.30/optimizer800/Osaka versus Crane 0.8.35/optimizer1/Prague. No fresh runtime equivalence is certified.

## Moderator recommendation — proposal, not owner selection

Treat InverseBond as an optional execution venue inside the custom SE, not new backing, a keeper program, a replacement LP asset, or DETF contraction. Compare complete same-size net outcomes. On exact input prefer strictly greater final delivery; on exact output prefer less actual required input. Ties can stay canonical. Gas-adjusted superiority is a separate, unselected policy.

The meaningful DETF use case is **SE-share→LP burn→NET+USDG→USDG**. `V/UniswapV2StandardExchangeInTarget.sol:770–856` implements the reference share zap-out; `:487–539` handles raw-LP zap-out; `:394–423` handles direct token pass-through. PRD `:377–379` distinguishes DETF USDG settlement from HLP exits delivering raw SE shares.

Recommended discussion scope:

1. Direct exact-input NET→USDG.
2. Exact-input raw-LP/SE-share→USDG, selecting the venue for the actually received NET leg after LP burn.
3. Retain all canonical routes, metadata, authorization, fee, refund, pretransfer and wrapper features.
4. Initially consider whole-fill-or-pool only. Splitting against capacity and marginal prices is additional optimizer scope; whole-fill selection is not global optimal execution.
5. Exact-output and NET-funded LP entry remain eligible future design work, not technically impossible. A NET-funded join can sell part of NET to the buyback and join remaining NET plus USDG; it needs a different allocation calculation and comparison of final LP/shares, not intermediate USDG. USDG→NET cannot directly use this one-way bid.

Pass-through-only scope is simpler but **does not improve the DETF's USDG redemption path**. MiniMax's cross-review claiming both pass-through-only and improved share redemptions is inconsistent; do not adopt it.

For exits, project protocol-fee LP minting, LP burn, pair→SE tax, remaining pool reserves, and treasury valuation before the venue comparison. Post-burn state need not equal a pre-burn InverseBond price. Execution should re-evaluate at the actual call point.

## Quotes, accounting and fallback

Execution projections must model the selected venue. `V/UniswapV2StandardExchangeQuoteTarget.sol:51–100,150–181,251–270` projects output and subsequent state. Buyback does not perform the canonical swap's reserve movement; it does consume capacity, burn NET and spend treasury assets. Sequential projected operations must not reuse old capacity/price.

Do not mark all vault shares to unreserved public buyback capacity. The existing `StandardExchangeRateProviderFacet.sol:85–120,160–173` under `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/` samples redemption previews or `quoteAssets`. Therefore making executable previews buyback-aware requires explicit separation from accounting valuation; “leave the provider unchanged” is not automatically safe. Accounting can still reflect actual state changes and realized assets; exclusion means no invented ownership of unused capacity, not freezing valuation forever.

Fallback is unresolved product choice:

- Candidate unavailable: choose the independently valid canonical route, subject to original user bounds.
- Selected buyback reverts: Astra prefers whole-operation revert; Grok prefers bounded pool retry; MiniMax leans retry; Kimi accepts revert-first.
- Moderator: preserve execution-faithful selected-route previews and caller limits. A pool retry is acceptable only if the original limits can still be met and rollback/approval/accounting are explicitly handled. Never replace the caller's minimum with a lower canonical baseline. Neither a canonical preview nor a buyback preview guarantees future delivery across blocks. A repeated Morpho failure need not self-heal merely by retrying later.

The existing DETF contraction no-fallback rule is not evidence that internal SE venue retry is forbidden. These are different state transitions.

## Cross-review corrections and residual cautions

- MiniMax retracted its EOA-only/integrator exclusion and alleged absolute PRD ban.
- Grok corrected fee units: the reference `300/100000` is 0.3%, or 30 bps, not 300 bps.
- Kimi retracted arbitrary guardian mapping of an ordinary vault.
- A historical premium is not a current executable quote. Even spot above NAV can lose after tax, fee and price impact. Kimi's marginal crossover statement that the spot threshold becomes lower with greater impact is directionally wrong: holding other quantities fixed, greater impact allows the bid to beat a higher starting pool spot.
- No price-safety proof follows from the treasury's k-based valuation comments. Donation, LP-fee, reserve/supply, Morpho and rounding effects require analysis; do not repeat “not manipulable” as a verified security conclusion.
- Hook HLP exits still deliver raw SE shares. Ordinary NET/sNET outputs still use the selected SY budget. Neither changes merely because the SE adds a venue.

## Evidence, confidence and human checkpoint

High confidence in inspected callability, direction, pricing body and route mapping. Medium confidence in proposed composition pending detailed state/rounding design. Live deployed identity, actual decimals/mappings, current capacity, liquidity, and economic benefit remain unverified. Consensus is not a security or profitability proof.

Context7 lookup found no matching NetNet library. Official primary pages accessed 2026-10-01:

- https://docs.netnet.capital/official-channels
- https://docs.netnet.capital/treasury
- https://docs.netnet.capital/FEES.HTM (researcher access)

Decision checkpoint: confirm whether the desired feature includes NET-leg optimization in LP/SE-share USDG exits, whether first scope may use whole-fill-or-pool rather than splitting, and whether selected-call failure should revert or attempt an independently valid pool route within unchanged caller limits.

## Separate implementation handoff

None authorized. A later documentation turn can specify configuration, exhaustive participating-route matrix, comparison units/state, accounting-rate separation, exact-output rounding/residuals, fallback policy and production/fork test obligations. Writing that specification will not authorize its execution.
