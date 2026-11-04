# Advisory feedback

## Identity

- Member: kimi
- Profile: research
- Phase: advisory review
- Role: council-member
- Requested model: `kimi-coding/k3.1-pro:high`
- Route: global
- Actual runtime model, task ID, and conversation ID: not exposed

## Draft under review

- Draft ID: `draft-t31-reentrancy-diagnosis-20261104-r1`
- Exact path: `docs/research/t31-reentrancy-diagnosis-20261104/coordinator/draft.md`
- Opened and reviewed: yes
- Hash: not recomputed
- This feedback does not replace the draft and does not authorize implementation.

## Disposition

requested-changes

The draft states my proposal accurately in **Member positions** and **Conclusions**: the assertion fails because the test expects a marker from the reverted outer frame to survive in Foundry's recorded-log buffer, not because the shared lock is missing. The requested changes are narrow evidence and precision corrections; they do not change that central diagnosis.

## Concerns

| Draft section | Concern | Requested correction |
| --- | --- | --- |
| Conclusions | `The diamond forwards facet revert data unchanged` is a behavioral assertion with no supporting citation in **Evidence**. The cited lock and modifier sources establish the shared lock and `IsLocked`, but not the diamond fallback's propagation of revert data. | Remove that sentence, qualify it as unexamined, or add the exact diamond-fallback source path and lines that establish revert-data propagation. Do not present it as something all four members read without that evidence. |
| Conclusions | `What it does not prove: ... that the nested query failed to revert IsLocked()` is a double-negative and narrower than my proposal. The message alone proves neither an `IsLocked` revert nor its absence. | Use `whether the nested query reverted IsLocked()` (or explicitly state both directions) so the limitation remains neutral between lock operation and lock bypass. |
| Evidence; Conclusions | MiniMax's `MinAmountOutNotMet` is carried as a later fallback and then as part of an unsettled-selector alternative without stating its reachability in the reviewed source. In that source, empty `data` must fail the adapter decode before route execution can reach the later payout check. Runtime selector uncertainty does not make that later check an alternative path through the reviewed source. | Separate supplied-runtime provenance uncertainty from current-source reachability: identify empty-data decoding as the source-inferred revert and state that `MinAmountOutNotMet` is not reachable on the reviewed empty-data path, or remove it as an alternative. Retain the supplied message's lack of a selector as a runtime limit. |

## What was not adopted from others

No substantive part of my proposal was omitted. The **Member positions** row accurately preserves my test-oracle/log-lifetime diagnosis, the pull-before-route ordering, the empty-data revert, and Foundry's failed-frame truncation. The **Conclusions** also preserve my distinction between the source-supported mechanism and what the supplied message proves, subject to the wording correction above.

The draft adds Grok's commit-specific source and regression-test citation and MiniMax's version-specific citation. I did not independently re-check those peer claims in this advisory pass. Their treatment of `MinAmountOutNotMet` is qualified in **Concerns**.

## Limits

- I reviewed only the exact identified draft against my existing original response; I did not open peer files or substitute another draft.
- I did not recompute a hash, run forge or other project tests, use Git, install dependencies, deploy, or launch sub-agents.
- The commit-specific and test-specific claims attributed to other members are coordinator representations in the draft, not independently verified evidence in this feedback.
- This is one advisory pass. It does not authorize implementation, replace the draft, or request another advisory round.
