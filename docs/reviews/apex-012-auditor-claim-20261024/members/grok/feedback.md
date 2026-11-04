# Member feedback

## Identity

- Run ID: apex-012-auditor-claim-20261024
- Member label: grok
- Phase: advisory review
- Owned path: `docs/reviews/apex-012-auditor-claim-20261024/members/grok/feedback.md`
- Requested role: council-member
- Requested model and reasoning: `xai/grok-4.7:xhigh`
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: continued
- Initial response path: `docs/reviews/apex-012-auditor-claim-20261024/members/grok/response.md`
- Initial response preserved: yes
- Peers read before this feedback: no
- Peer feedback read: no
- Unread members treated as support: no

## Draft reviewed

- Draft ID: draft-apex-012-auditor-claim-20261024-r1
- Path: `docs/reviews/apex-012-auditor-claim-20261024/coordinator/draft.md`
- Identity lines in the opened file match that ID and path.
- Fingerprint supplied by the coordinator: not supplied
- Fingerprint independently computed: not computed
- Draft bytes opened: the full draft was read. No byte count was computed.

## Disposition

- Disposition: requested-changes
- This file replaces a missing initial response: no
- Advisory only. Not a veto, not consensus, and not approval for any unread member.

The draft does not misstate the auditor's mechanism, the headline profit figures, who pays, or which fix the auditor calls partial.

Kept, and should stay:

- Both deposit and redeem are priced from `LiquidationQuote.quote()`, which reads live `slot0`, liquidity, and the tick bitmap, subtracts only the vault's own liquidity, and simulates a sale of opposing inventory.
- Issuance is `S*credit/V`. Entitlement is `shares*V/S`.
- The in-unlock sequence is permitted calls. Profit formula `D*(V1 - V0 - D)/(V0 + D)`. Stated result 70,634,405,953 raw token0, called 7.1% of a 1e12 vault, zero capital, paid from the local sleeve.
- Settled redeem pays through `_fund` with no sleeve cap. Stated result 74,704,386,253 raw token0, called 7.5% of TVL, flash-loanable depth.
- Incumbent holders lose what the attacker gains. `HolderValueLoss` does not catch it, because both quotes are of the same inflated state.
- The spot path is a separate channel: swap, deposit, swap back, redeem. The auditor states a profit there too.
- The unlock revert is the only fix the auditor calls partial, because settled depth and flash-loaned spot moves still work. The draft does not adopt the fix list.

The draft does misstate one comparison. Minting at honest `V0` and redeeming at inflated `V1` is the withdrawal story. It is not a way the report is broader than the owner's clarification.

It also drops distinctions stated in the initial response. Those drops are the concern rows below. They are local. They are not a request to redesign the vault or to adopt a fix.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| G1 | "Against the owner's clarification", third broader place | Misstates the comparison. "The deposit mints against `V0`, and the redeem pays against `V1`" is the liquidity-channel withdrawal, which the previous paragraph correctly says matches the clarification. The report is broader on pricing because the same quote also prices deposits, and because the spot sequence deposits after a swap. The auditor does not say which leg carries that spot profit. | Keep the spot channel and the unsettled-depth point. Replace the `V0` / `V1` sentence. Do not call the honest-deposit, inflated-redeem round trip broader than a withdrawal manipulation. |
| G2 | Settled-variant sentence | Drops the auditor's close of that sequence. The report says deposit normally, add settled liquidity, redeem, then remove the liquidity. Without the removal, the sentence is a different sequence. | Restore the normal deposit and the removal. |
| G3 | Claim section, after the settled profit | Drops the design note that a scripted 0% sleeve blocks the in-unlock variant with `InsufficientLocalTarget` and does not block the settled variant. That is how the auditor assigns the 7.5% figure to the production-scripted case. | Restore that sentence. Do not move the 7.5% figure onto the in-unlock path. |
| G4 | Design-note sentence | "That ruling does not waive SEC-08" drops the object. The auditor says the cited PRD line names temporary liquidity and JIT, and that the cited accounting note says O1 does not waive SEC-08, while the attack satisfies the tested bound. That is a specified-versus-tested bound, not an invalid call. | Add that the auditor says the cited SEC-08 text names temporary liquidity and JIT. Do not turn it into an invalid-call claim. |
| G5 | In-unlock profit sentence | Drops the cap. The auditor says that per-transaction profit is capped by the pre-attack local target sleeve, and that the attack repeats once the sleeve refills. The settled path is the one with no sleeve cap. | Restore the cap on the in-unlock path only. |

Rows G6 and G7 are reservations. They are not a second verdict.

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| G6 | Claim opening | Severity High and status "Latent: not deployed" are omitted. The draft does not say the finding is deployed. A reader can still take it as a live loss. | Restore the status clause. |
| G7 | Spot sentence and mechanism paragraph | Dropped detail, not a different channel. The auditor says "exact" original price, 0.3% swap fees, and profits 53,661,742,003 and 33,284,087,429. The auditor gives that variant no separate payer. The quote starts as `total0` or `total1` and then adds proceeds. The draft's "raises that simulated value" still points at the right inflation. | Optional. No change is required for the channel split to stand. |

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral.
- This file grants no implementation authority.
- `response.md` was not overwritten. The draft was not edited. Peer files were not read.
- The participation table in the draft was not checked. Task IDs there are not confirmed.
- Inherited parent permissions are not evidence of confinement.
- No vault redesign is proposed. None of the auditor's further fixes is adopted here.
