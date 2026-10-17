# Astra — replacement-session targeted answer

This is a labeled replacement session, not continuity. I do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. I read the current `docs/reviews/apex-req-sep-04-amount-out-refund/REMEDIATION_PRD.md` in full. No other reviewers' notes were read for this targeted answer.

The owner answer closes the earlier exact-input mapping and refund-cap questions: exact-input processes declared `amountIn`; exact-output refunds unused credit bounded by the declared maximum; undeclared surplus is not refunded; no attribution ledger is introduced. My earlier full-unbooked-remainder interpretation is superseded by this later answer and must not guide implementation.

**One blocking clarification remains in the prescribed documentation wording.** Lines 18 and 22 allow present unbooked tokens to count toward the declaration without identifying their sender, then refund the unused bounded credit. But the exact replacement at line 38 says unsolicited transfers “are not refunded to a later caller,” without limiting that statement to tokens outside the declaration. Those statements can prescribe different outcomes for the same unattributed balance. The implementer must not decide which sentence to qualify.

**One owner question:** Does “They are not refunded to a later caller” mean only unsolicited tokens **outside that caller's declared bound**, rather than prohibiting a refund of unused credit within the bound merely because someone else originally supplied it?

**One sentence that would close it, for owner confirmation and replacement of line 38's wording:**

> Unsolicited transfers remain donor risk and may count toward a later caller's declared bound without attribution; only the unused portion of that bounded credit is refundable to that caller, while unbooked tokens outside the declaration are not refunded and booked inventory is never used as input credit or refunded.

This is a clarification of the prescribed text, not a new findings round or a request to reopen the settled cap/exact-input rule. No implementer search, new ledger, or code change is proposed. Only this assigned Markdown answer was written; no code or PRD was edited.

I did not run Forge.
