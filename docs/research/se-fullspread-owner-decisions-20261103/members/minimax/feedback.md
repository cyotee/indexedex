# Advisory feedback on draft-se-fullspread-owner-decisions-20261103-r1

## Identity

- Member: minimax
- Run ID: se-fullspread-owner-decisions-20261103
- Profile: research
- Phase: advisory feedback on the coordinator draft (second pass)
- Requested role: council-member
- Requested model and reasoning: `minimax/MiniMax-M3` (admitted adaptive thinking)
- Runtime identity beyond the assignment: not exposed
- Peers read before submission: no
- Draft reviewed: `docs/research/se-fullspread-owner-decisions-20261103/coordinator/draft.md`, ID `draft-se-fullspread-owner-decisions-20261103-r1`. Fingerprint not computed. The draft was opened; it is the only draft reviewed.
- Owned artifact: `docs/research/se-fullspread-owner-decisions-20261103/members/minimax/feedback.md`
- Disposition: requested-changes

## What I read

Only the coordinator draft named above. My own prior artifact `members/minimax/response.md` is mine and is the reference for "my proposal". I did not read peer feedback, did not edit the draft, my response, the blockers file, the PRD, or any other member's file, and ran no Forge, test, install, or Git command.

## Disposition

**requested-changes.**

The draft is accurate in substance on eleven of the twelve findings and preserves peer disagreements without adopting them as the only reading. Two changes are needed before this becomes the final record: one finding states my recorded verdict incorrectly (F7), and two load-bearing parts of my proposal are absent (F6, F12). None of these changes the draft's structure or its per-finding conclusions for F1–F6 and F8–F11; one of them changes a label in the coverage table, and that label is the answer to the question the run asked.

## Does the draft state my proposal accurately?

Mostly yes, with one material exception.

- F1, F2, F3, F4, F5, F6, F8, F9, F10, F11: my verdicts (Misunderstood / Problem / Changed the recommendation) and my missing facts are carried accurately. The F1, F2 and F6 reasoning in the draft is a faithful compression of mine, including the points I made about the lock not being replaced and the scope of "untouched" reaching a withdrawal.
- F12: my verdict and the zero-address and "if possible" gaps are carried accurately. The draft's F12 lists three missing facts; my response named the zero-address case, the operator path, and the lock interaction. The draft's third item ("If possible" does not say whether the Operable predicates are required) is my second item, restated. This is a superset of my response, not a distortion of it.
- **F7: no.** My response records `Misunderstood: no`. The draft records "partly" in the F7 heading and in the coverage table, and its F7 reasoning states that the owner's reason "answers a mechanism the recommendation did not need". That is a different finding from mine, and the draft presents it as the consolidated record without marking it as the coordinator's own view. This is the correction I ask for.

I do not contest the draft's structural choices: preserving Kimi's reading on F2 and F7, Astra's wording gap on F5, Astra's F6 variant, Grok's F10 true-branch dependency, and the Astra and Kimi "no problem" view on F12 is the right handling, and the draft does not charge any of those readings to me.

## Corrections by draft section

### F7 section — set Misunderstood to "no"

The draft's F7 heading and its coverage table read "Misunderstood: partly". My response records `Misunderstood: no`, for a stated reason: the owner's rationale — emitting because fees are deposited rather than claimed — is consistent with the accepted sentence's own trigger, which fires when a call "adds positive liquidity and that call's liquidity modification collects a nonzero fee". Nothing in the owner's wording restates the accepted sentence incorrectly. The two departures the owner makes, emitting when booked tokens are deployed and adding `Donation()`, are changes the owner is entitled to make; the report itself reserved the previously booked half of F7 for the owner's choice. My F7 problem is therefore ambiguity and an unreplaced lock, not a misreading.

Correction: in the F7 section and in the coverage table, "partly" becomes "no", and the sentence "The owner did not accept the council predicate… a reason the recommendation did not need" becomes a statement that the owner changed the predicate rather than misread it. The problem and change flags stay as they are.

### F7 section — citation correction

The draft cites "Blockers lines 234 and 242" for the rule that a call which compounds no fees does not emit. Line 234 is the B-11 decision line. The sentence "It is not emitted for a maintenance call that compounds no fees" is on line 240. Line 242 is the B-03 restatement, "A call with no fees, no donation, and no booked remainder returns with no state change and no event", which is a different rule. Correction: cite 234 and 240.

### F1 section — the missing fact should name the cross-reference the draft parks under it

The draft's F10 section preserves Grok's true-branch dependency "under F1", but the draft's F1 missing fact does not mention it. The accepted F10 sentence says "`pretransferred` true is an underlying-token donation and uses F1", and the owner affirmed that sentence on F10. After the owner's F1 answer, the accepted F10 sentence points at a rule that no longer states the over-maximum behavior.

Correction: in the F1 section, extend the missing fact to the `pretransferred == true` branch of `donate`, so that a branch which depends on the declined F1 mechanism is named in the same place the draft parks it. The substance is Grok's reading, which I do not contest; the correction is that the F1 missing fact and the F10 dependency must cover the same branch.

## Omitted load-bearing parts by draft section

### F6 section — the scoping clause must travel with the accepted sentence

My response treated the accepted F6 sentence's first clause, "The no-leftover-shortfall-revert sentence removes only the former sleeve top-up", as load-bearing, and the draft does not mention it at all.

The reason it is load-bearing: both the lock and the PRD state the no-revert rule without that scope. `IMPLEMENTATION_PLAN_BLOCKERS.md:380` reads "It does not have a leftover shortfall revert", and `UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md:108` reads "There is no residual shortfall after that payment, and no revert for one." An implementor who reads either text without the scoping clause implements no revert at all. The draft's F6 section establishes that the added explanation conflicts with the accepted exit sentence, but it does not carry the clause that decides whether the lock and the PRD text can coexist with the accepted sentence.

Correction: add to the F6 section that the scoping clause is part of the sentence to be locked, with the two unsourced readings of the no-revert rule cited at `IMPLEMENTATION_PLAN_BLOCKERS.md:380` and `UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md:108`.

### F12 section — the decision supersedes a locked sentence and does not say so

My response recorded that the live-owner decision replaces the locked initialization mechanism — `IMPLEMENTATION_PLAN_BLOCKERS.md:80`, "When a new proxy is initialized, set its owner to the address returned by `feeTo()` on the Vault Fee Oracle. That is the owner `onlyOwnerOrOperator` uses", and the summary at `:385` — without the decision saying that it replaces that lock. The draft's F12 section carries the related mechanism facts (`OperableRepo.sol` lines 213-216, and that the stored-owner guard cannot follow a `feeTo()` change) and asks, as a missing fact, whether the owner stored at initialization keeps authority. That is close, but it leaves the lock-side statement of the change unrecorded.

Correction: in the F12 section, state that the decision changes the locked initialization rule and must say so on the record, citing `IMPLEMENTATION_PLAN_BLOCKERS.md:80` and `:385`.

## Non-load-bearing omissions

Recorded for completeness; none of these changes a verdict.

- F1 section: my response named three possible implementations under "no snapshot" — refund the unbooked balance and pull no shortfall, pull the shortfall, or credit another sitting balance. The draft records two of them. The dropped reading is the one that would pull what the declaration exceeds.
- F2 section: my response's consequence for the divergence — unbooked collected fees stay in the unbooked held balance and are therefore pretransfer credit for the next caller (`docs/vaults/PRETRANSFER_DIRECTIVE.md:7` and `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:56`, "Booked holder backing is never pretransfer credit") — is not carried. It is the reason the F2 divergence is a credit path and not only a bookkeeping difference.
- F2 section: my evidence for the fee collection came from `Pool.sol` lines 146-149 and 193 and `Position.sol` lines 83 and 94. The draft cites `Position.sol` lines 94-102 and `PoolManager.sol` lines 119-120 and 132 for the same facts. The `PoolManager.sol` lines were not in my evidence set, so I did not verify them; I did not check them in this pass because this pass is limited to the draft. They should be confirmed before the final record relies on them.
- F7 section: my response recorded the same `Donation()` addition as an intentional change with no fields, which the draft also records, and that the owner added it against the accepted sentence "Do not… name a donation event". The draft carries the addition; the "against the accepted sentence" framing is mine and is not stated, though the draft's own text makes it clear.
- F10 section: my response noted one repository observation the draft does not carry — an unrelated family already declares `donate(IERC20 token, uint256 amount, bool prepaid)` at `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfBonding.sol:37`, the same ABI shape and therefore the same selector as the accepted `donate(address token, uint256 amount, bool pretransferred)`, under a differently named flag. Different vaults, so no functional collision; the flag now carries two names in the repository.
- F12 section: my response noted the consequence that a live read gives the current fee recipient owner authority over the vault's owner-gated functions, and that the fee recipient is the address that receives the B-01 usage-fee shares (`IMPLEMENTATION_PLAN_BLOCKERS.md:46`). I recorded it as the meaning of the change, not as a question for the council. The draft does not carry it.
- F7 section: the draft's evidence gap says no `Donation()` event was found under `contracts/` and that the search was not repeated in the coordinator pass. I did not run that search either, so I neither confirm nor dispute it.

## Limits

- This feedback covers the accuracy of the draft as a record of my proposal and the completeness of what it carries from that proposal. It does not re-adjudicate the owner's decisions.
- Peer positions are known to me only through the draft's own "Preserved disagreements" table. I took no position on those, except for the F1 and F10 cross-reference noted above, which rests on the report's F10 sentence that the owner accepted.
- This feedback does not authorize implementation, does not authorize a PRD edit, and does not replace the draft. The draft is not an owner lock.
