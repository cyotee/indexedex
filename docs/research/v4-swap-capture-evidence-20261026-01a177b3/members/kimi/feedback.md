# Kimi advisory feedback — draft-v4-swap-capture-evidence-20261026-01a177b3-r1

## Identity

Kimi council member, advisory pass. Requested model: kimi-coding/k3:high, global route; other Native identity not exposed. This pass reviewed only the coordinator draft. Peer responses and peer feedback files were not opened on this pass either; peer numbers discussed below are the ones quoted inside the draft itself. Advisory only: not a veto, not implementation authority.

## Draft under review

- Draft ID: draft-v4-swap-capture-evidence-20261026-01a177b3-r1
- Path: docs/research/v4-swap-capture-evidence-20261026-01a177b3/coordinator/draft.md
- sha256 verified against the bytes sent: 1813119f975b657c0214503b252bd9760f6d815f5305747c473f6baeaa078efe — match.

## Disposition

support-with-reservations

The draft's direct answer ("No", with the narrow price-free-vector carve-out) matches my response's conclusions on every rule: quote rules 1–2 fail with closed ledgers; executed-price rule 3 fails with a parameter-dependent boundary, not a threshold; the same-pool TWAP (rule 5) fails as written and only reprices the attack even idealized; the price-free proportional rule 4 is the only variant that removes the conversion hole. The draft's preserved-disagreements table represents my positions accurately (the `alpha < omega` boundary, the 51%-on-80%-opposing-book witness, the rule-4 componentwise claim). All Kimi numbers quoted in the draft match my model's prints.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| KF-1 | "Rechecked closed rows", executed-price paragraph | "The response prose rounded that last row to `3,128,200,000`. Use the print." is stale. The current members/kimi/response.md carries the exact printed value `+3,128,158,354.82`; the rounded string is not in the file. The draft's own Evidence-gaps section flags the pre-settlement read timing, so this reads as a resolved instance of that gap rather than a defect in my response. | Re-read the current response.md and remove or correct the rounding remark. |
| KF-2 | "Rechecked closed rows", slice-exit paragraph ("still made `22.199955` target, because the quote had valued unsold opposing at zero") | The mechanism attribution is too narrow. Independent re-check in my exact-rational ledger (single interval, idle book, fee 0.3%, conservation closed): quote-mint + realized slice exit with NO manipulation and the marketLimited cutoff NEVER triggered yields attacker net `+15068798773.084002` target on a 1e11 deposit (book 5e11/5e11, L = 1e12); with a 50% entry swap, `+13843644552.857296`. The whole-book liquidation basis (mint) versus per-slice realized basis (exit) slippage asymmetry alone produces the hole; unsold-valued-at-zero is sufficient in the coordinator's row but not necessary. | Reword the mechanism to cover any mint/exit valuation mismatch of untraded inventory (zero cutoff or whole-book-vs-slice size asymmetry). The conclusion ("an exit swap is not a repair of a quote mint") stands and is strengthened. |
| KF-3 | "Rules, stated separately", rule 3 | "The fee-aware post-swap form ... collapses to marking the pre-swap book at `p_exec`" omits the retained deposit remainder. The exact identity is `(A_T + D − αD) + p_exec·(A_O + ΔO) = A_T + D + p_exec·A_O`, because `p_exec·ΔO = αD` by construction. The `+D` in the denominator is exactly what shifts (without closing) the attack boundary — my post-swap witness needed α = 30% where the pre-swap form fails at 51% on the same book. | State the identity including the retained `D`, and note it shifts rather than closes the boundary. |

## What was not adopted from others

Not applicable in the strong sense: the draft's synthesis is compatible with my response and I ask for no adoption of peer positions. Two narrow items where the draft adopted LESS than my response, and where I preserve my original position rather than dropping it:

1. Rule 4 scope. The draft adopts only "the vector rule removes the pool-price conversion" and explicitly does not adopt "eliminates every loss." My response's claim is stronger and I stand by it: inside the stated domain (custody-verified contribution vector, exact in-kind refunds, per-range liquidity components, slice-bounded realized exit, disclosed market-limited residual policy), the componentwise per-share conservation invariant — weakly increasing on entry, exactly preserved on exit — is proven algebraically and was verified with exact rational equality on the binding component. That is an elimination claim for the APEX-2026-012 extraction channel inside that domain, not merely a conversion-removal claim. It is not a claim of immunity to adverse trading, griefing of the entry conversion, or ordinary market risk, all of which my response's Limits disclose.
2. Balanced-book 49/50/51. The draft's coordinator rows (all positive at 49/50/51, full interval ownership, 200-unit deposit) and MiniMax's negative half-swap row sit in different machines than mine (vault-as-LP self-fill, different ω). My preserved position: the boundary is α* = ω = q0·A_O/V0 (asymptotic, first order in the manipulation), with my exact grid's finite-displacement crossover between 44% and 46% on a balanced book at fee 0; the residual gap to 50% is second-order manipulation cost that shrinks with displacement. Nothing in the draft contradicts this; the disagreement is correctly preserved as machine differences, and I do not average it away.

## Limits

- The KF-2 numbers are standalone exact-rational arithmetic in my single-interval idle-book model, not Forge traces; the marketLimited haircut and multi-interval bitmap walks are absent from that model by construction, which is precisely what makes KF-2 an independence statement (the hole appears without them).
- I did not independently re-execute the Grok, MiniMax, or Astra rows quoted in the draft; my support for the shared conclusions rests on my own witnesses plus the draft's internal consistency.
- My review is of the hashed bytes only; any draft edit after that hash is outside this feedback.
- This feedback is advisory. It does not authorize production edits, tests, deployment, or any change to `getRate`.
