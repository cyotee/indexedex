# Grok — REQ-SEP-04 questions

Read `docs/reviews/apex-req-sep-04-amount-out-refund/REMEDIATION_PRD.md` only. No other reviewer notes.

No blocking question.

The owner answered what "the rest" is: only the unused part of the quantity this caller declared for this call. Exact-output refunds `min(unbooked, declared maximum) - used`. Exact-input processes declared `amountIn` and does not refund undeclared surplus. Vault paths that already have that shape are not changed. The README replacement sentences are written. DETF comments that still say an exact-input prepaid call refunds nothing, or that it reverts unless the declaration equals the whole surplus, get that same meaning, without signature changes. Legacy V4, Slipstream, and README lines 3 and 56 stay out. No ledger is added.

I did not run Forge.
