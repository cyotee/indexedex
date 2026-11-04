# Coordinator receipt of Grok's inline advisory feedback

Native task: st_01a17528, advisory continuation epoch 1. The member reported apply_patch was unavailable and returned the complete feedback inline. No alternate writer was used on this pass. The coordinator preserved the member-authored text below; the initial original remains unchanged.

---

# Member feedback

## Identity

- Run ID: v4-wings-complete-design-20261025-01a171a0
- Member label: grok
- Phase: advisory review
- Owned path: members/grok/feedback.md
- Requested role: council-member
- Actual role, model, reasoning, task ID, and session ID: continued council-member assignment. The session prompt exposes the model as Grok 4.7. Provider route, reasoning effort, task ID, and session ID are not exposed.
- Fresh or continued: continued
- Initial response path: members/grok/response.md
- Initial response preserved: yes

## Draft under review

- Draft ID: draft-v4-wings-complete-design-20261025-01a171a0-r1
- Path: docs/research/v4-wings-complete-design-20261025-01a171a0/coordinator/draft.md
- Fingerprint supplied by the coordinator: not computed
- Fingerprint independently computed: not computed
- Draft bytes opened: yes, the complete file, including the identity lines, sections 1–14, preserved disagreements, evidence gaps, coverage table, and limits

The draft's own identity lines match the assigned ID and path. This is not approval of the draft as written, and it is not council consensus.

## Disposition

- Disposition: requested-changes
- This file replaces a missing initial response: no

I support the selected machine: one fungible share; issuance from an independent reference applied to each range's own liquidity, not to live composition; credit from final retained increments after the entrant's costs; old fees, including fees earned on the entry swap, only in the denominator; exact one-whole-share execution getRate with no NAV clamp; explicit in-kind escape; no first-release portfolio-funded swap; no silent oracle-outage mode switch; foreign-unlock cash shortcuts removed. Those choices correctly reject MiniMax's live-composition mark and clamp, and Kimi's executed-swap denominator.

The draft is not yet safe to implement from the equation and integration sections alone. The corrections below do not replace the architecture. They stop three mis-implementations the current wording still permits: minting on spot principal or pre-placement token balances, treating pooled fee deltas as an entrant rebate, and serving getRate or NAV during a foreign unlock. They also pin 18-decimal and terminal accounting so those sections cannot be filled in later as a second, unlabeled rate.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| G-1 | §3 equations for E and C; §4 steps 7–9; §12 row "Fees and placement cut" | Final-increment credit is the right cut, but "liquidity increments" is not yet defined as (L, lower, upper) valued with the §3 reference composition. An implementer can still mark Inventory.principal(slot0) at P, which is MiniMax's spot-dependent numerator, or mint on post-swap tray tokens and then place, which is pre-placement minting. | In the mint equation, define each funded increment as liquidity added at fixed bounds and value it only as x0_ref/x1_ref at the frozen reference sqrt price. State that spot principal is custody and tray reconciliation only. If assets stay idle, C is the reference mark of that idle. If they are placed, C is the reference value of the resulting L plus residual idle, and any shortfall versus the tray's reference mark is the entrant's allocation cost: it is not refunded from old equity and not added back into C. |
| G-2 | §3 fee paragraph; §4 steps 2, 6, and 7; ExecutionDelegate settlement already in the originals | Old fees earned by the entry swap are correctly assigned to A in the illustration, but the add that follows collects the whole position's fees in the same caller delta as principal. The current delegate settles that combined delta. Netting it against the entrant tray rebates old fees to the entrant and shrinks C's token cost without putting those fees in A. A pre-swap checkpoint does not catch fees earned during the swap. | Require the final old-fee checkpoint after the entrant swap and before C is computed. The entrant tray pays the full principal delta. feesAccrued on that add are old equity, included in A, and are not a rebate. Reject an unexplained delta that cannot be split into principal, old fees, and entrant residual. |
| G-3 | §4 step 1; §6 step 1; §7; §11 foreign-unlock paragraph | Money entry, exit, and same-manager buffering are closed to a foreign unlock. Public getRate, preview, quoteRate, and NAV are not. V4 liquidity is visible before settlement, so a one-share execution quote read inside that unlock still sees unsettled depth. MiniMax's alternative, quoting a projected post-unlock state, would preserve that read. | Public economic views revert when the manager is already unlocked or the vault is busy. The only exception is the vault's own authenticated callback using internal accounting, not a public view selected by msg.sender. Do not add a foreign-unlock quote branch. |
| G-4 | §2 decimals; §5 seed and 10^12 atom minimum; §7 rate formula and SY paragraph | The getRate formula is the right 18-versus-target normalization: at q = 10^dS it reduces to floor(T(U) * 10^18 / 10^dT), not floor(T(U) * 1e18 / U) unless the decimals match. SY assetInfo currently returns share decimals beside the target address. After this decimal split that field would be 18, not target decimals. "NAV semantics" without a unit conversion will publish a 10^36-style N/S, or alias exchangeRate to getRate. Bootstrap can also satisfy a one-whole-target seed and the 10^12 atom minimum while leaving S < 10^18, so getRate stays unavailable after a "successful" seed. | Name assetInfo as target decimals, not share decimals. Publish any accounting rate as floor(N_targetRaw * 10^dS * 10^18 / (S * 10^dT)), in the same scale as getRate, and state that exchangeRate is that accounting rate or is removed. It is not getRate and not the old whole-book liquidation quote. Require successful bootstrap to leave S >= 10^dS, or state that getRate remains unavailable until it does and must not be replaced by the issuance-price query. |
| G-5 | §5 zero-supply surplus; §6 step 4 "take ALL equity" | Positive-supply donations are old equity. Zero-supply surplus is for an immutable recovery recipient. "ALL" on a terminal exit can be read as the raw token balance, which would pay segregated surplus to the last holder, or as shareholder equity, which would leave a donation received during the exit in dispute. | Terminal payout is the shareholder book only. Surplus already segregated at zero supply stays segregated. A donation observed while supply is positive is old equity and goes with the last holder. Define the observation point so the two claims cannot overlap. |
| G-6 | §8 reinvestment and wing replacement | Swap-free maintenance still needs the reference, gap, and non-replenishing epoch budget. That part is right. The same section can be misread as passing reference-composition amounts to modifyLiquidity. Those amounts are not what the pool at the live spot will accept. | Say that every liquidity add or removal uses live-spot principal math. The reference decides whether a replacement is allowed and prices the loss against the epoch budget. It does not supply the token quantities submitted to the manager. Entry must not initialize a new wing range at live spot; only the epoch-gated maintenance path may create or replace one. |

No other correction is requested. The following were checked and should be preserved, not softened.

Final-position credit, once G-1 and G-2 are pinned, is the correct rejection of pre-placement minting. Reference value is linear in L at fixed bounds and P, so old equity is unchanged by the entrant's add only if old ranges are not removed or recentered during entry. The draft already forbids that. Keep the prohibition next to the mint equation.

Independent reference-evaluated L is the right numerator and denominator. MiniMax's own equation values removable principal at the live price and then multiplies opposing units by p_ref. MiniMax states that this V is not spot-independent. Adopting it would let a spot move change issuance even with a perfect feed. The §12 rejection is correct.

Kimi's executed price is not a release numeraire. Kimi's numerator identity C = D credits gross target input, including swap fees and impact, and the denominator V_pre = A0 + A1*p_e still moves when spot changes the old book's composition and the fill price. Kimi labels the resulting self-deal round trip argued, not proved. A small self-trade does not price unsold old inventory. Do not reopen that denominator in the final.

Exact getRate must remain rate(U) from the strict one-share execution, with no clamp to NAV. MiniMax's clamp replaces the exit quote with the reference mark whenever the band binds, and MiniMax's claim that the clamp makes the rate safe to pay without redeeming is not established. In-band extraction remains possible. The unclamped size-specific preview is the arbitrary-size quote. Do not substitute it for getRate.

Nonlinear quotes are acknowledged correctly: T(q)/q is not T(U)/U, and the current full-book quote removes all owned liquidity, so it cannot be divided by supply. A small-slice preview must leave staying liquidity in the pool. Strict target mode reverts on unsold opposing. A residual-return route must be explicit and must return both outputs, never retain or zero the residual. Stayer in-range liquidity may still take the other side of the tray sale. That is an intended trade, not a top-up from stayer idle and not a sale of stayer opposing as the swap input. Do not reintroduce a same-state HolderValueLoss check, and do not promise constant stayer token composition.

Canonical getRate uses a finite movement and full consumption. If that sale cannot complete, getRate reverts. It must not publish a partial fill, a cached value, zero, or synthetic par. S < U, including zero supply, is unavailable. That is consistent with an executable whole-share quote. It is a behavior change from the current empty-vault 1e18 and from Kimi's zero-supply 1e18. Keep the separate issuance-price query unlabeled as getRate.

Tick-walk fidelity: do not skip dust ticks, or cap by price distance, and still call the quote exact. Kimi's price-distance bound does not bound attacker-created ticks. Work-limit failure and market-liquidity failure stay distinct. Incomplete target sales are not successful quotes. I did not re-read LiquidationQuote._sell on this pass. This support is of the draft's requirement, not a claim that the current walker already matches PoolManager.swap.

Rate consumers: I found no sentence that claims actual-size settlement, deviation bands, or epoch budgets make every consumer safe. Section 9 says caps reduce exposure, not oracle truthfulness. Section 11 says actual-size settlement does not validate every other rated reserve that informed the price, and that an IRateProvider assignment does not create parity. Keep those sentences. The Balancer facet's full-supply preview is a different quote size. Pointing it at the new getRate, or mapping a getRate revert to 0, is a new integration and is not authorized by this draft.

Static argument is not tested security. Nothing here closes APEX-012, 024, 025, 026, or 040. The audit figures cited in the originals remain the audit's reported PoCs. I did not rerun them.

## What was not adopted from others

- Peer responses read: members/astra/response.md, members/grok/response.md, members/minimax/response.md, members/kimi/response.md
- Peer feedback read: no
- Unread members treated as support: no

From my original, the same-instance unpriced mode should not be revived. A silent switch when the reference fails mixes two ownership rules. If a proportional product is specified later, match the position vector (each L and both idles), not aggregate token balances followed by a different placement. That is Astra's correction of my original, and the draft's §12 alternative already says it.

From my original, forcing exchangeRate to equal getRate should not be revived. They are different objects. Astra's split is the one the draft should keep, with G-4's scale written down.

From MiniMax, do not adopt live-composition marking, the getRate clamp, re-pointing exchangeRate to that clamp, or a foreign-unlock path that still quotes. From Kimi, do not adopt p_e as the issuance denominator, C = D gross-input credit, dust-skip exactness, or zero-supply getRate = 1e18.

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral.
- This file grants no implementation authority.
- Inherited parent permissions are not evidence of confinement.
- apply_patch was not exposed. No feedback file was written. The coordinator may preserve this text verbatim. members/grok/response.md was not modified.
- No project tests, shell, Git, or new source investigation beyond the draft and the four originals. LiquidationQuote._sell was not re-read on this pass. No fingerprint was computed. No security proof and no closure of any finding.

Now: no task remains. Next: no task remains.
