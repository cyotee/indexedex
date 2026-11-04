# Coordinator draft

## Draft identity

- Draft ID: draft-se-fullspread-owner-decisions-20261103-r1
- Path: `docs/research/se-fullspread-owner-decisions-20261103/coordinator/draft.md`
- Run ID: se-fullspread-owner-decisions-20261103
- Status: pending advisory review. This file is not the final.
- Fingerprint: not computed
- Sources: `members/astra/response.md`, `members/grok/response.md`, `members/minimax/response.md`, `members/kimi/response.md`

## Participation

- Council kind: full
- Requested members: astra, grok, minimax, kimi
- Substantive initial responses: astra, grok, minimax, kimi
- Missing initial responses: none
- Result label: full
- Coordinator mode: invoking-agent
- Coordinator is an independent vote: no

## Question

For each owner decision on F1 through F12, is there a problem with the decision, and did the owner misunderstand the recommendation?

## Proposed text

These are findings. They are not owner locks, and they do not authorize a PRD edit. A decision that changes a recommendation is recorded as a change. It is not called a defect for that reason alone.

### F1. Overstated maximum

Misunderstood: yes. Problem: yes. Changed the recommendation: yes.

The recommended snapshot is a read of the vault's unbooked balance before the call uses it. It is not an ERC-20 transfer alert, and it does not identify who sent the tokens. The stated reason answers a mechanism the recommendation did not propose.

The already locked rule still says: if the maximum is larger than the unbooked balance, refund that unbooked balance and do not pull the shortfall (`docs/vaults/PRETRANSFER_DIRECTIVE.md` lines 9-11; blockers file lines 282 and 390). The owner did not say that lock is replaced. Crediting another sitting balance when the declaration exceeds the unbooked total is a different call from refunding that total.

The non-atomic risk is already locked, and it covers a different case. If the declaration is within the aggregate unbooked balance, another party's staged tokens may be used. That party took the risk. The recommendation did not stop that case.

Missing fact: when a declared maximum exceeds the unbooked balance, does the call still refund that balance and process nothing, or does the caller get credit for another sitting balance?

### F2. Fees on a user route

Misunderstood: yes. Problem: yes. Changed the recommendation: no.

"Do not interleave `compound()`" matches the sentence that was accepted. "Leave fees untouched" does not. A deposit that calls `modifyLiquidity` cannot leave accrued fees in the position. `Position.update` computes the owed fees and advances the fee-growth cursor (`Position.sol` lines 94-102). `PoolManager.modifyLiquidity` adds that fee delta to the caller's delta (`PoolManager.sol` lines 119-120 and 132). The withdrawal lock already books fees collected that way (blockers file line 256). The owner did not replace that lock.

Kimi reads "untouched" as "not deployed and not compounded," and does not record a problem. That reading is preserved. It is not the only reading the words support.

Missing fact: on a deposit, a bundle deposit, and a share-minting `exchangeIn`, are collected fees booked and not deployed, or is the fee delta left unaccounted?

### F3. Booked total

Misunderstood: no. Problem: no. Changed the recommendation: no.

The acceptance is the actual held balance, the zero-size skip, and revert on a failed step.

### F4. Position ratio

Misunderstood: no. Problem: no. Changed the recommendation: no.

The accepted definition is the current pool price at the stored ticks, excluding unpaid fees and booked balances.

### F5. One-token swap size

Misunderstood: no. Problem: no, in the owner's acceptance. Changed the recommendation: no.

The owner accepted the greatest-integer-liquidity size and did not restate it. The 48% sentence is charged to F6, not read as a replacement of this acceptance.

Astra says the accepted sentence still equates two different amounts: the swap's input cost, and the processed-token amount the following add consumes. That is a gap in the recommendation's wording. It is not a misunderstanding by the owner. It is preserved, and it is not charged as a problem in the decision.

### F6. Unconverted exit principal

Misunderstood: yes. Problem: yes. Changed the recommendation: no, for the exit sentence itself.

The accepted sentence is an exit rule: convert all unwanted withdrawn principal into the selected token, or revert `AmountOutNotMet` and do not burn shares. The explanation is an entry-sizing rule: leave a remainder of the provided token, perhaps by swapping 48%, and find the algorithm by proof or fuzzing. That is the shape already locked for a one-token deposit and for `donate` or `compound` (blockers file line 252; pretransfer directive line 11). It is not the exit.

A sized remainder on the exit is the residual the accepted sentence forbids. Fuzzing does not name the amount. The 48% figure also conflicts with the F5 acceptance, and the owner did not say it replaces F5.

Astra records the qualification as a change of the F6 sentence. The other three keep the exit sentence accepted and charge the conflict to the explanation. The missing fact is the same either way.

Missing fact: does the 48% remainder apply only to a deposit or maintenance add, leaving the exit rule as accepted? Or does a one-token exit keep a remainder instead of reverting?

### F7. `Compounded()` and `Donation()`

Misunderstood: the reason is partly aimed at the wrong mechanism. Problem: yes. Changed the recommendation: yes.

The owner did not accept the council predicate. Emitting because fees are deposited, rather than claimed, is a reason the recommendation did not need. The recommendation was about which call emits, not about a claim.

The new rule is a real change: emit `Compounded()` when booked tokens are deployed, add `Donation()`, and emit both when a donation also collects accrued fees. Kimi treats "emit on every booked deploy" as copyable and records no problem. That reading is preserved.

The problem is that the words name more than one trigger, and they do not replace the locked sentence. Blockers lines 234 and 242 say `Compounded()` means fees were compounded into the reserve, and a call that compounds no fees does not emit. Line 254 says a booked balance includes a stray transfer and a non-atomic pretransfer, not only fees. "Deploy booked tokens" and "a donation that also collects accrued fees" are not the same predicate. One implementor emits on every booked deploy. Another emits only when that call collects a fee. The locked emission sentence is not replaced on the record.

`Donation()` is an intentional addition. It is not a defect because the recommendation declined to name one. It has no fields and no condition except the combined case. No `Donation()` event was found under `contracts/`.

Missing fact: does `Compounded()` fire for any deploy of the booked balance, or only for a deploy of tokens known to be fees?

### F8. Seven-address write

Misunderstood: no. Problem: no. Changed the recommendation: no.

### F9. Selector row

Misunderstood: no. Problem: no. Changed the recommendation: no.

### F10. `donate` signature

Misunderstood: no. Problem: no, in the signature. Changed the recommendation: no.

The three-argument signature, the false-only share donation, and the argument-free `compound()` are accepted. Grok records a problem only in the true branch, because that branch says it uses F1, and F1 is no longer the report's refund-only rule. That dependency is preserved under F1. It is not a second signature defect.

### F11. Batch-swap routes

Misunderstood: no. Problem: no. Changed the recommendation: no.

Acceptance adopts the stated assumption: the one-token exit is single-output `exchangeBundleOut`.

### F12. Live `feeTo()`

Misunderstood: no. Problem: yes. Changed the recommendation: yes.

The reconsideration is explicit. Current `feeTo()` is to have owner controls after that value changes. That replaces the report's freeze. It is not a misunderstanding of the freeze.

The existing `onlyOwnerOrOperator` guard compares the vault's stored owner, a global operator, or a function operator (`OperableRepo.sol` lines 213-216). It does not read `feeTo()`. The operator mappings can be reused. The stored-owner guard cannot, unchanged, follow a `feeTo()` change.

Astra and Kimi record no problem in the live-owner decision. MiniMax and Grok record two unnamed facts. Those facts remain, because the words do not settle them.

Missing facts: when live `feeTo()` is `address(0)`, who may call? After `feeTo()` changes, does the owner stored at initialization keep authority, or does only the current `feeTo()` have it? "If possible" does not say whether the Operable predicates are required.

### F13 through F15

Not decided. Silence is not acceptance.

## Preserved disagreements

| Finding | Draft | Not adopted as the only reading |
| --- | --- | --- |
| F2 | "Untouched" does not match the accepted booking sentence | Kimi's reading that it means not deployed |
| F5 | The owner's acceptance has no problem | Astra's wording gap in the accepted sentence |
| F6 | The exit sentence stays accepted; the explanation is the problem | Astra's reading that the qualification changes the exit sentence |
| F7 | Two triggers, and the emission lock is not replaced | Kimi's reading that every booked deploy is the rule |
| F10 | The signature stands | Grok's true-branch dependency, carried under F1 |
| F12 | The live-owner change is understood, and two facts are unnamed | Astra and Kimi recording no problem |

## Evidence gaps

- `Position.update` and `PoolManager.modifyLiquidity` were re-read for this draft. They were not executed.
- No `Donation()` event was found by the members under `contracts/`. That search was not repeated in this coordinator pass.
- F13 through F15 were not answered.
- This draft does not authorize implementation or a PRD edit.

## Coverage

| Finding | Misunderstood | Problem | Changed |
| --- | --- | --- | --- |
| F1 | yes | yes | yes |
| F2 | yes | yes | no |
| F3 | no | no | no |
| F4 | no | no | no |
| F5 | no | no | no |
| F6 | yes | yes | no |
| F7 | partly | yes | yes |
| F8 | no | no | no |
| F9 | no | no | no |
| F10 | no | no | no |
| F11 | no | no | no |
| F12 | no | yes | yes |

## Limits

- Static comparison of four research responses. The blockers file, the PRD, and the prior resolution draft were not edited.
- This draft does not claim permission confinement.
- Advisory review of this draft has not happened. Silence is not approval.
- This draft does not authorize implementation, a PRD edit, or an owner lock.
