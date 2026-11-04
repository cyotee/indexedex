# Full-spread PRD quality review

## Question

Does the rewritten full-spread PRD say each locked requirement clearly enough that two implementors would copy it the same way?

## Verdict

No. The 2026-11-03 money rules are stated. The fee share, the exit preview, the sleeve removal, and the tuple return can be copied. The public surface and a few call outcomes cannot. This review does not authorize an edit.

## Participation

| Member | Task | Findings |
| --- | --- | --- |
| astra | `st_01a1a331` | 5 |
| grok | `st_01a1a332` | 12 |
| minimax | `st_01a1a333` | 8 |
| kimi | `st_01a1a334` | 6 |

All four read the PRD. None edited it. This report is the coordinator synthesis. It is not a second member vote.

## Findings two or more members named

1. An overstated pretransfer leg has no whole-call outcome. Astra, MiniMax, Kimi, and Grok. FS-OWN-32 says the overstated amount is refunded and not spent, then says the sentence does not decide the other declared amounts in the same call. A bundle with one overstated leg and one funded leg has no testable refund array, no decision on whether the funded leg is processed, and no decision on whether an add is attempted. The locks do not settle that. Naming it open was honest. Leaving it for an implementor to choose is the defect.

2. `donate` and `compound` have no parameter list. MiniMax and Grok. The locked behavior depends on the token, the amount, the share leg, and `pretransferred`. Two implementors can invent different signatures. Astra adds that `Donation()` is written as a locked zero-field event, while F7 said the fields were not named. `Compounded()` having no fields is locked. `Donation()` having no fields was a filled reading, not a named ABI.

3. The live `feeTo()` check has no callable path. Astra and Grok. The PRD says the caller must be the current `feeTo()` or an operator in `OperableRepo`, and that new modifiers do the check. It does not say which facet exposes `feeTo()`, or how an operator is written. The check cannot be tested from the PRD alone.

4. The borrowed-unlock sentence is wider than the route it is allowed to use. Kimi. FS-X01 keeps the already-unlocked path for `exchangeIn` only. FS-OWN-13 says that if another caller holds the unlock, this vault calls `modifyLiquidity` and `swap` directly. A reader can apply that to `donate`, `compound`, or a bundle route, which FS-UNLOCK-01 still rejects with `ManagerAlreadyUnlocked`.

## Findings one member named, and this review checked

5. The ERC-165 sentence is false as written. MiniMax. FS-OWN-08 says the `IStandardExchangeIn` id stays because it is the XOR of selectors `0x89d61912` and `0xd02d3063`. The Crane interface still comments `exchangeIn` as `0x05562cc8`. The XOR of `0x89d61912` and `0x05562cc8` is `0x8c8035da`. The XOR of the two adopted selectors is `0x59fb2971`. "The id stays, because it is the XOR of those selectors" cannot be copied. The coordinator recomputed those two XORs. The interface comment was read at `lib/crane/contracts/interfaces/IStandardExchangeIn.sol`.

6. The lock-file recap still says a withdrawal pays only the principal fraction. MiniMax. That sentence is in `IMPLEMENTATION_PLAN_BLOCKERS.md` in the closing recap, beside a sentence that says the 2026-11-03 override replaced it. The PRD itself does not keep the principal-only rule. A reader who treats the lock file as the tie-break can still copy the old rule.

## Findings one member named, not rechecked line by line

These are carried as that member's finding. A later edit should re-read the cited line before treating one as a defect.

- Astra: a native pool and the WETH face can be read as two addresses for one reserve query. Package validation still says to reject `rateAsset` after that argument was removed.
- Grok: one-token donation spend is stated twice; borrowed-entry preconditions share one "or"; bundle proportion is undefined; the `exchangeIn` correlation event is unnamed; withdrawal `feesAccrued` is not tied to the unpaid-fee read; zero recipient and `address(0)` are not one reject; unmapped bundle combinations are unclassified; the one-token exit claim is stated at two widths.
- MiniMax: the maintenance fee source is unstated; two rejections name no error; `bindingHash` is given two scopes; `poolKey()` can be read as installed or absent.
- Kimi: an invalid-route sentence can be read as a view revert, against the no-view-revert lock; FS-OWN-31 says the borrowed call fails only in two cases, which excludes `AmountOutNotMet` and settlement failure; the package inputs do not show the two-facet reserve cut.

## What is clear

The fee and booked-share arithmetic, the no-sleeve rule, the tuple return, the named preview consumers, and the live owner check's identity are stated once and were not reported as contradicted inside the PRD. The open items are surfaces and call outcomes, not a second fee formula.

## Limits

This report does not authorize a PRD edit, an implementation, or a lock-file edit. The overstated-bundle outcome and the `Donation()` fields are unresolved owner items. They should not be filled by an implementor.
