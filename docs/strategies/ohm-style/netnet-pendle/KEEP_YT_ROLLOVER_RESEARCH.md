# Keep-YT entry and atomic rollover — council R4

Date: 2026-09-25 (current environment). Source: local Pendle V3 router and primary documentation. Research only; no implementation, simulation, live-chain verification or main PRD/matrix edits in this round.

## Human decisions and proposals received

- The owner rejects the suggested opening price of 1 NET/DETF and proposes a high opening price of **1 DETF = 1,000 NET**, with **0.5% expansion per NET epoch**, to provide a long expansion period. Opening price, ongoing peg and native token units are distinct. Do not replace the previously selected 1 NET peg merely because launch pricing is higher. Expansion supply basis, eligibility/stop rule and multi-epoch calculation still need definition; no new recipient/custody choice is implied.
- Public custom hook joins accept **NET, sNET, USDG and/or NET-DETF**, supporting proportional all-token, unbalanced subset and single-token modes using the selected Weighted/Balancer math.
- The corresponding proportional, unbalanced subset and single-token withdrawal modes are selected. Earlier matrix conditional single-output wording and blanket component-proportional exit formulas need reconciliation; they must not veto these later choices. A proportional quote remains the proportional mode, not the universal unbalanced-exit quote. Exact invariant accounting and operation limits remain engineering work.
- USDG-funded fresh bonds use the same lock schedule as other fresh bonds, not an early exit enabled by changing payment currency. This aligns them with the applicable fresh-bond maturity rule rather than the short elected-reinvestment schedule; pre-maturity reward claims remain selected.
- Atomic rollover is the owner's preference, conditioned on researching whether entry requires costly swaps. A staged design or mandatory chunk loop has not been selected.

## Answer: seeded-market Keep YT does not purchase PT through the AMM

Directly inspected `lib/crane/contracts/protocols/perps/pendle/router/ActionAddRemoveLiqV3.sol:272–303`:

1. Read the current target market state and PY index.
2. Compute SY to tokenize:

   ```text
   X = total SY supplied
   T = market PT reserve
   S = market SY reserve
   a(S) = current PY-index conversion of SY reserve into asset/PT units

   syToTokenize = floor(X * T / (T + a(S)))
   syForLiquidity = X - syToTokenize
   ```

3. Send `syToTokenize` to the YT contract; send remaining SY to the market.
4. Call `YT.mintPY(market, receiver)`: newly minted PT goes to the market, matched YT goes to the receiver.
5. Call `market.mint(receiver, syForLiquidity, mintedPtAmount)`; enforce LP and YT minimum outputs.

There is **no PT/SY swap call in this helper**. The split is ratio-matched tokenization plus dual-asset liquidity addition, subject to native rounding. Our strategy's receiver retains YT rather than selling it to maximize LP. Do not replace this with the ordinary single-token liquidity add, which buys PT via a swap.

Pendle's primary documentation says Keep YT converts the underlying to SY, tokenizes part into PT/YT and deposits PT plus remaining SY, avoiding the PT purchase that creates entry price impact. The documentation's broad investment claims are not relied on here; the execution sequence is confirmed in code.

## Why the entire route is not automatically swap-free or costless

The token-input wrapper first calls `_mintSyFromToken` (`ActionAddRemoveLiqV3.sol:236–248`). In `router/base/ActionBase.sol:26–64`, that helper can take a direct supported-token path or execute an external aggregator swap before depositing into SY. Therefore:

- Starting from compatible SY isolates the swap-free Pendle entry leg.
- Starting from NET/sNET requires verifying the actual SY integration supports the intended conversion and its costs/conditions.
- Same old/new SY allows reuse of that token without a fictitious conversion.
- Different old/new SY requires a real supported conversion, for example old-SY redemption to a mutually supported NET/sNET face and successor-SY deposit, **if actually supported**. Equivalent metadata is not a token conversion, and a V2 swap is not automatically required.
- Transfers, fees, tax predicates, staking mechanics, rounding, pauses and liquidity constraints can affect net delivery even without a Pendle market swap. No fixed 5% tax is assumed; actual transfer endpoints and configuration determine taxation.

This is not a verified end-to-end Robinhood route. No NetNet-specific successor SY implementation or live fee/exemption configuration was established in this round.

## Expired-source exit and empty-successor distinction

The selected rollover only starts after source expiry. In `ActionAddRemoveLiqV3.sol:410–432`, expired LP removal burns LP into SY and PT, sends the PT to the YT contract and invokes `redeemPY`. It realizes mature PT rather than selling it through the AMM. Calling the YT contract for this operation does not mean expired YT itself is sold or redeemed for principal. Historical YT interest/rewards remain separately accounted as required by PRD §11.

**Empty successor:** the Keep-YT allocation denominator is zero if both target reserve amounts are zero. The standard helper is not an empty-market bootstrap. We must either select an already seeded target or separately specify a valid Pendle-level initial dual SY/PT join and its starting parameters. This must not be confused with the custom DETF hook's first-bond G/U/B/R liquidity bootstrap. No new requirement that the owner personally seed the pool is adopted; the allowed seeding behavior is pending specification.

## Chunking: when it does and does not help

There is no mandatory PT swap in seeded-market Keep YT to split into smaller trades. Repeated ratio-matched joins do not inherently improve the entry price; they add calls and rounding effects. Changes in absolute reserves do not by themselves imply changed ideal reserve proportions.

If some other step really requires an AMM trade, splitting it without replenishment or other state changes does not reset cumulative price impact. Interleaving swaps with liquidity additions is not the same as merely splitting a swap: it changes the pool and final positions. Any benefit must be compared at equal terminal exposure, accounting for assets the strategy supplied as liquidity, fees and gas. Executing pieces across transactions additionally exposes intermediate state/price risks.

Chunking to satisfy a particular protocol size/domain constraint may be worth evaluating, but it is not an approved generic workaround or proof of lower total cost. Reused Weighted ratio/invariant limits still apply to custom unbalanced LP operations; they should not be confused with Pendle's Keep-YT split.

## Recommendation

Continue with an **atomic rollover design candidate**:

1. Validate expiry and trusted-factory recognition, then successor token/backing compatibility.
2. Settle old-series claims and account for prior externally triggered claims.
3. Remove expired LP and redeem mature PT without an AMM sale.
4. Keep principal, earned interest and fee-owned rewards separately attributed, even if they share a token address.
5. Reuse same SY or perform a verified supported conversion to successor SY with actual-output protections.
6. For a seeded successor, use ratio-matched Keep-YT tokenization and dual mint, retaining YT. An empty successor requires the separately specified seed path or rejection.
7. Commit the successor state only upon successful full settlement; retain old-series references and residual accounting.

No iterative PT swap/deposit loop is needed solely because a seeded-target Keep-YT entry is large. Preserve conversion, LP and YT minima, deadlines and full rollback in the proposed atomic design. This research supports the owner's preference but does not itself ratify final atomic/staged policy or certify executability.

## Four-member evidence and corrections

Four independent first passes and four same-session combined cross-reviews completed. Each researcher received the other THREE ORIGINAL files, not prior cross-reviews. No participant reported a guard denial or context loss. Original artifacts remain unchanged:

| Researcher | Original | Session | Reported metadata |
| --- | --- | --- | --- |
| Astra | [Original](./reviews/KEEP_YT_R4_ASTRA_ORIGINAL.md) | `ses_f4edf055affe5dSHkzSUwwINjw` | `openai/gpt-6-astra` |
| Grok | [Original](./reviews/KEEP_YT_R4_GROK_ORIGINAL.md) | `ses_f4edb8e85ffeCS8Miy5XkGe6Nk` | `xai/grok-4.6` |
| MiniMax | [Original](./reviews/KEEP_YT_R4_MINIMAX_ORIGINAL.md) | `ses_f4ea97c4dffelmRAaq1xOU5Lmt` | `minimax/MiniMax-M3` |
| Kimi | [Original](./reviews/KEEP_YT_R4_KIMI_ORIGINAL.md) | `ses_f2abe1e07ffe0izL8DAH8boF2W` | `kimi-code-plan-global/k3`, high |

Metadata is not provider attestation. Originals are untrusted model evidence, not authority to change requirements.

- All four found the no-swap Keep-YT core path.
- Astra consistently qualified cross-SY conversion and chunking. Grok highlighted the ordinary swap-zap contrast and empty-target path; its suggestion that loops can help Weighted/wrapper limits remains conditional, not a proven optimization.
- Kimi retracted its blanket claim of a globally swap-free atomic rollover and narrowed the recipient question to preserve selected reward custody. Its initial claim that a 1000-NET opening conflicts with a 1-NET peg is rejected: an opening premium and ongoing target can differ.
- MiniMax's proposed equal-`assetInfo()` test, mandatory V2 conversion, generic 5% tax assumption, reciprocal “KeepYt mirror” exit and use of DETF first-bond formulas to bootstrap a Pendle market are not adopted. Metadata agreement does not make distinct SY tokens interchangeable. MiniMax's cross-review did not adequately retract all of these claims; claimed consensus on them is not accepted.
- Some cross-reviews still characterized repeated Keep-YT reserve reads as necessarily price-impact-producing. The moderator adopts the narrower conclusion: proportional ratios can remain unchanged apart from rounding; no swap is demonstrated merely by repeated state reads.
- New HLP exit modes supersede old proportional-only framing for all exits. The implementation must define invariant-priced unbalanced/single exits and preserve ownership/accounting, not silently force every new mode through an old cash cap or assume every output is available without liquidity.

## Sources and limitations

- Local router source cited above, plus `offchain-helpers/router-static/base/ActionMarketCoreStatic.sol:146–163` corroborating the allocation/preview. Inspected Pendle implementation uses Solidity `^0.8.17`; local code is an unpinned vendored snapshot, not a verified Robinhood runtime.
- Context7 `/websites/pendle_finance` consulted first for Keep-YT documentation.
- Primary documentation fetched: https://docs.pendle.finance/pendle-academy/yield-trading-deep-dives/chapter-7-providing-liquidity-while-trading-yield — access 2026-09-25, section “Keep YT mode.” Researcher artifacts contain both September 24 and 25 access annotations; preserved without retroactively changing their dates.
- No native token decimals, active pool state, live router version, gas bounds, conversions, expansion price effects or economic profitability were verified by execution. Standard route names do not establish custom settlement correctness. Existing authority blockers remain.

## Human checkpoint and separate implementation handoff

The substantive new question is the proposed **0.5% expansion definition**: percentage of which supply/base, under what premium/stop condition, and how multiple processed epochs compound or aggregate. Preserve the selected NET-epoch synchronization and minted staking-reward custody. Treat 1000 NET/DETF as proposed launch pricing, not a decimal conversion or an automatic change to the 1-NET ongoing target.

Next documentation can reconcile the selected LP modes, USDG lock alignment and corrected Keep-YT flow into PRD/matrix, explicitly marking unresolved expansion parameters and empty-target/conversion conditions. Implementation, simulations, tests, deployments, source/config changes and transactions require separate authorization; none were performed here. Saving this report and the four originals does not authorize execution.
