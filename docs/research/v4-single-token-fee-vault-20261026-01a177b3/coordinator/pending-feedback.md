# Pending feedback notes

Not the resolution. Astra and MiniMax had not settled when this note was updated. The draft bytes are unchanged.

Kimi: support-with-reservations. Hash matched. Does not ask the draft to change its pick.

| ID | Disposition if later feedback does not reverse it | Final change |
| --- | --- | --- |
| K1 | accept as dissent | Keep the settled-target pick. State that it chooses incomplete fee exposure over a single-token deposit break. Kimi weighs those the other way. |
| K2 | accept as a label disagreement | Keep Grok's label that a no-sale preview is not a withdrawal-and-sale preview. Also state Astra's and Kimi's reading that the sale leg is empty, not violated. Do not redefine getRate. |
| K3 | accept as a narrower ground | Do not say a movable live-sale rate violates the locked law. Say it is a disclosed property, and this question does not adopt it as the rate another hook should trust. |

Grok: requested-changes. The settled-target claim is not withdrawn.

| ID | Disposition | Final change |
| --- | --- | --- |
| C1 | accept | Map quote manipulation, executed-price allocation, and vault self-fill. Label the mapping as inference, not a re-execution. |
| C2 | accept | State that getRate returns `A * 1e18 / S`, reverts when supply is zero or idle target cannot pay, and can move from a same-transaction target credit or rounding, not from a tick. |
| C3 | accept | Say the fee credit is zero unless a non-share position that already holds both tokens exists. This design does not create it by swapping shareholder target. |
| C4 | accept | Split raw-balance holding from the rate-provider reading. |
| C5 | accept | Do not upgrade the missing same-capital design to an impossibility. |
| C6 | accept | Say the prior report is a reason not to adapt a pool-ratio mint. It did not name ICHI. |

MiniMax: support-with-reservations. Hash matched. Original recommendation preserved.

| ID | Disposition | Final change |
| --- | --- | --- |
| M1 | accept | Same mapping as Grok C1. Moving the pool principal outside the share is not a general solution of pool manipulation. |
| M2 | accept | Same movement statement as Grok C2. No market-price path moves the adopted rate. |
| M3 | accept | A buffered leg that holds this share requires a rate provider. Raw balance is the identity-leg case. |
| M4 | accept | Not established is not impossible. MiniMax's in-share design remains a different design, with a live sale preview and the prior mechanisms retained. |
| M5 | accept | The depositor's target stays idle. The deposit does not deploy fee-earning liquidity. |
| M6 | accept | `A` increases only on an authorized path that recognizes an actual target-token fee delta, not on a bare transfer. |
| M7 | accept | Keep both named breaks in the final. |
