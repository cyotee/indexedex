# NetNet/Pendle remaining requirements — council R7

Date: 2026-09-25. Based on NetNet PRD v0.16, current operation matrix and Universal compounded-expansion PRD v0.1. Research only; controlling product documents unchanged.

## Verdict

**Ready to write a conditional milestone plan.** Three economic definition clusters should be resolved before freezing the expansion implementation. Remaining technical UNKNOWNs should become explicit engineering tasks and acceptance gates, not requests for the owner to redesign selected formulas or APIs.

Settled: opening 1,000 NET/DETF; strict expansion gate above 1 NET/DETF; processed NET epochs; premium-dependent compounded pending supply; pre-transaction display followed by actual mint/funding; funded staking custody; atomic market rollover; full Weighted HLP modes; USDG/fresh-bond lock alignment; deployment configuration, singleton intent and factory-first recognition; first bond supplies initial hook liquidity. Neither linear catch-up nor flat supply-rate expansion is an alternative in this review.

## 1. Coefficient: define the remaining meaning of 0.5%

Sources: `NETNET_PENDLE_DETF_PRD.md:26,368–372,460,595`; `docs/plans/detf/UNIVERSAL_V4_DETF_COMPOUNDED_EXPANSION_PRD.md:70–101`.

The selected recurrence uses projected DETF supply Si and a premium base:

```text
W = 1e18
premiumBase_i = floor(Si * (Pi - W) / Pi)
Ei = floor(premiumBase_i * c / W)
Si+1 = Si + Ei
```

**Proposal for owner confirmation:** interpret the earlier 0.5% as `c=0.005e18` per processed NET epoch on that premium base, not annually and not directly on all supply.

Ignoring native-unit rounding, P=2 NET/DETF then yields 0.25% supply expansion for that epoch; near P=1 the amount is much smaller. This preserves the chosen premium dependence. No token-recipient change, different supply basis or interpretation as a percentage of the final catch-up delta is selected.

The old Universal annual parameter is not a reason to reinterpret the human's per-epoch proposal as annual. An implementation representation must preserve the selected economic units, not determine them by convenience.

## 2. Price policy: which NET price, and what really changes in projection?

Sources: custom §9/O05; compounded PRD U01 at lines 92–103. Prior source trace: `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget.sol:89–139` and `UniswapV4DetfCommon.sol:324–340`.

Two different measures must not be conflated:

- **NET/DETF trading spot:** based on actual pool balances, weights and rates. A mint delivered solely to staking does not mechanically add DETF to the pool or change that ratio.
- **NET-denominated marked reserve value per outstanding DETF:** a supply-denominated synthetic measure. Increasing projected total supply can reduce this measure even when the pool balances are unchanged.

**Question:** which measure expresses the owner's selected “price above 1 NET per DETF” condition and supplies the premium? The one-NET threshold itself is settled; this question defines the observable being compared.

**Proposal:** use one explicitly documented NET price function, freeze external snapshot inputs rather than inventing historical prices, and reevaluate inputs genuinely affected by each virtual epoch. If the selected measure is supply-dependent, this can reduce premium and stop later expansion. If it is unchanged trading spot, recomputing it does not create artificial price feedback. Do not normalize the ongoing one-NET threshold by the 1,000-NET opening price.

Frozen-price versus updated-price projection must not be selected as a mere optimization. Conversely, do not claim that every form of price must decrease because supply was minted to staking.

## 3. Reward allocation: as-if-sequential entitlements or one final split?

Sources: compounded PRD U02 (`:105–111`) and U04 (`:134–145`).

Both alternatives can compound total pending DETF supply:

1. Project each epoch's staking distribution and index changes as if settled then; later virtual epochs account for the resulting positions under the chosen policy.
2. Calculate the compounded total issuance, then allocate it once using the realization-time allocation state.

They need not give identical user/fee/creator entitlements. Dust and gons rounding are not the only possible difference: intermediate fee/creator receipts and weight updates can affect later allocation.

**Question:** should each holder's final reward entitlement match the as-if-each-epoch-settled reference, or should only token supply compound while the resulting mint is allocated once?

**Moderator recommendation:** evaluate as-if-sequential entitlements as the fidelity reference, consistent with the stated motivation for lazy realization, but obtain an explicit decision rather than claiming that the owner already selected fee/creator virtual participation. Physical minting/funding may still be aggregated into one transaction if it preserves the selected final ledger. One physical mint does not require one economic allocation.

Display ABI can be addressed alongside this: a proposed approach is to expose clearly named projected values while keeping actual issued supply and backing separately identifiable. The UI can show projected accrued value without claiming it was physically minted. This is a proposal, not an adopted selector change; existing staking `balanceOf` semantics versus additional getters still need the plan's compatibility decision.

## Engineering work to include in the plan

- Derive custom Weighted reserve/rate mappings and owned-reserve exact-input/output calculations; preserve selected join/exit modes and accrued-value accounting.
- Reconcile initial zero earned interest with the reference first-bond full-book join. Do not call contributed capital yield.
- Specify supported atomic rollover conversions, historical claim access and empty-target treatment. An empty **Pendle** market seed is not the DETF first-bond G/U/B/R bootstrap. Any new seed path needs explicit specification; otherwise unsupported entry must revert atomically.
- Design bounded-complexity compounded projection/realization without silently skipping epochs, reintroducing caps, or pretending unavailable historical prices are known.
- Specify native rounding, dust retention/suppression and zero-result processing. Per-epoch suppression is not inherently required for monotonicity; neither it nor aggregate suppression is automatically equivalent.
- Trace the bond reference's duration assumptions against short next-epoch and already-matured native-note contributions; preserve chosen release rules.
- Complete custom V2 SE supported-surface parity and taxed/untaxed execution proofs, real dependency pins, singleton enforcement, and native-note ownership/gas-liveness analysis.
- Specify pending display and actual execution across staking transfers, claims, SY/SE views and reserve quotes; no double inclusion of pending supply or paying projected rewards from someone else's principal.

These tasks can be written into a plan now. They remain execution/deployment gates, not claims that the model is already feasible or safe. Unspecified PENDLE forwarding-failure and residual policies should be proposed explicitly if they affect user rights or availability rather than silently treated as harmless implementation choices.

## Authority and documentation

The owner has reversed the earlier noncompounding rule; the new compounded PRD records this. Canonical alignment text/comments/tests still need coordinated reconciliation in separately authorized work. FoT/rebasing-underlying policy conflicts remain recorded authority gates, not a repeated request to reconsider the economic preference.

Verified documentary drift:
- Matrix line 85 still labels opening and compounding as proposed/unresolved despite custom v0.16 selection.
- Matrix row 24 correctly has the fresh-bond USDG maturity, but policy 9 at line 88 still calls it UNKNOWN.
- Matrix row 36 still has broad UNKNOWN cells requiring the selected behaviors to be reconciled, without inventing the unresolved detailed formula.
- The tracker still reports reconciliation only through v0.12.

**False positives:** matrix rows 08/10 already contain the selected HLP inputs, outputs and modes. Do not report those as newly unanswered. A historical amendment's old wording is not a live product choice when the controlling later decision is explicit.

## Council record

Eight synchronous calls completed: four independent first passes and four same-session combined cross-reviews. Every continuation received the other THREE ORIGINAL artifacts together as untrusted model evidence, never earlier cross-review answers. No participant reported a denial or lost context this round. The originals remain unchanged:

| Researcher | Original | Session | Reported model metadata |
| --- | --- | --- | --- |
| Astra | [Original](./OPEN_ITEMS_R7_ASTRA_ORIGINAL.md) | `ses_f4edf055affe5dSHkzSUwwINjw` | `openai/gpt-6-astra` |
| Grok | [Original](./OPEN_ITEMS_R7_GROK_ORIGINAL.md) | `ses_f4edb8e85ffeCS8Miy5XkGe6Nk` | `xai/grok-4.6` |
| MiniMax M3 | [Original](./OPEN_ITEMS_R7_MINIMAX_ORIGINAL.md) | `ses_f4ea97c4dffelmRAaq1xOU5Lmt` | `minimax/MiniMax-M3` |
| Kimi K3 | [Original](./OPEN_ITEMS_R7_KIMI_ORIGINAL.md) | `ses_f2abe1e07ffe0izL8DAH8boF2W` | `kimi-code-plan-global/k3`, high |

Metadata is not independent provider attestation. Cross-review answers remain in the task transcript/sessions. No source/source-code artifact permissions are changed by their findings.

### Agreements, corrections and dissent

- All four identify coefficient, price/projection and reward allocation/display as the primary remaining definition clusters. Agreement on the questions is not agreement on defaults.
- Astra emphasizes correct price feedback and sequential entitlement comparison. Grok favors frozen-price projection in its initial proposal and final aggregate allocation. Kimi favors a recomputed owned-inventory synthetic, initially with aggregate allocation, then qualifies that recommendation. These alternatives remain unresolved.
- The moderator does not adopt MiniMax's statement that the price **must** be the owned-reserve synthetic. The selected NET threshold does not choose that measure, and the council cannot substitute it for the owner's intended trading price without confirmation.
- MiniMax retracts its initial annual 0.5% recommendation, but its subsequent consensus/annualized-return statements contain unsupported arithmetic and overstate agreement. They are not retained as conclusions. Kimi's cross-review annual-slot coefficient estimate is also tenfold wrong: under the Universal eight-hour reference, `0.005 / 1095` is approximately `4.5662e-6`, not `4.6e-7`; neither value is the proposed per-epoch coefficient 0.005. No annual return illustration is used to justify a product choice.
- Reject MiniMax's R51-based Pendle successor seeding suggestion and unsupported dust-loss claims. No new public seed/purge/maintenance API is selected.
- Several participants described all remaining operational gaps as engineering. The moderator qualifies this: technical recommendations belong in the plan, but any newly proposed change to rights, eligibility or failure availability must still receive explicit disposition.

## Confidence and handoff

High confidence in the current selections and the three remaining semantic clusters; no claim that the list exhausts future discoveries. No new external library/API claims or web retrieval were required for this document review. References are local snapshots accessed 2026-09-25, not new dependency/runtime release or live-deployment verification. No tests, simulations, code/configuration changes or transactions occurred.

**Human checkpoint:** answer the three semantic questions, or authorize a conditional plan that presents them as early decision gates. The plan can contain the remaining proof work without asserting that it has passed. This review does not authorize implementing the plan. Only the four researcher originals and this consolidated report were authored; the PRD, matrix and tracker are unchanged.
