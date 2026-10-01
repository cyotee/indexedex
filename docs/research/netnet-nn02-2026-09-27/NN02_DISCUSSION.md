# NN-02 — External-note claim liveness: discussion and decision checkpoint

Date: 2026-09-27. **IN PROGRESS; no remedy or risk acceptance selected.**

## 1. Plain-English issue

The NFT must control the right to collect a native NetNet bond's vested NET and atomically reinvest it. NetNet keeps a list of notes for the receiving address. Anyone can pay to append a note to that address, and collection examines the entire list every time. Paid notes stay in the list.

Consequently, a wrapper can correctly protect who owns the proceeds but still be unable to complete a claim if that list becomes too expensive to scan. A separate custody address can contain the impact to one position; it cannot prevent someone appending more notes to that address. We need to determine a feasible availability model without silently weakening the selected rights.

Constants implementation is now recorded in PRD v0.24 §16.1. It does not establish whether the configured deployed depository is identical to the inspected local source. NN-01 remains open for that evidence while this discussion proceeds conditionally from source.

## 2. Observed source facts

All local paths below are relative to `lib/crane/contracts/protocols/pol/net/src/`. Moderator read the complete 200-line `BondDepository.sol`; pragma is `^0.8.24`. These are local-source observations, not deployed-code or gas measurements.

| Source | Observation |
| --- | --- |
| `BondDepository.sol:35–54` | Address-keyed arrays of notes containing payout, claimed amount and vesting timestamps |
| `:104–140` | Positive input is required, but arbitrary `to` is accepted without receiver consent; a new note is appended |
| `:126–138` | Rounded payout is not checked for positivity before appending; successful zero-payout conditions depend on price, input and transitive execution |
| `:143–153` | `redeem(to)` scans every note of `msg.sender`, updates claims, sends aggregate vested NET to `to`; no pruning, selective sweep or reset |
| `:156–165` | `pendingFor` also scans all notes |
| `:168–170` | `noteCount` can reveal list length; it does not reduce it |
| `:174–188` | LP valuation rounds; epoch cap measures payout value, not note count |

Researchers additionally inspected `IBondDepository.sol` and `Constants.sol`. No selective/range redemption or native note-transfer path was found in the inspected implementation/interface. Local two-day vesting versus interface five-day prose remains NN-01 verification work, not an owner-selected duration for this item.

**Inference:** workload grows with the recipient's history, including hostile appends and already-claimed notes. No evaluated wrapper mechanism prevents this growth. This is not a proof ruling out all conceivable designs, nor a claim that an economically practical live attack has been demonstrated.

## 3. What possible mitigations do—and do not—solve

| Candidate | Useful effect | Unresolved limit |
| --- | --- | --- |
| NFT-controlled custody per position | Isolates positions and avoids pooling legitimate histories | Custody address still accepts unsolicited upstream notes; no new NFT contract is implied |
| Record purchased note indices / read specific records | Avoids scanning strangers' notes to value registered positions | Actual upstream redemption still scans all; aggregate proceeds require a coherent attribution rule |
| Precompute/deploy custody later | May affect address exposure timing | Deposits do not require recipient code; the address can be targeted before deployment |
| Limit wrapper purchases / rotate future addresses | Limits legitimate new exposure | Cannot reject third-party appends or move already existing native notes |
| Frequent claiming / headroom monitoring | May reduce uncollected exposure and detect growth | Never prunes history; no guarantee for delayed or final claims |
| Batch operations across custody addresses | May isolate independent failures | Cannot paginate a single upstream all-note redemption |

`redeem(to=feeSink)` is **not a solution**: `to` selects the payout recipient for all vested notes, not just gifts. Such a call could divert purchased principal while leaving list length unchanged. Unsolicited native-note proceeds are not automatically Pendle rewards owed to feeTo. No new gift destination or maturity treatment is adopted.

Attack cost matters but is not a guarantee. Positive-value gifts can still be rational for someone disrupting a larger position or pursuing an outside incentive. Tiny/zero payouts may change cost and capacity assumptions. One appended note need not require one transaction: a caller can potentially make multiple deposit calls within a transaction's budget. No gas threshold, cost floor, success probability or safe maximum note count has been measured in this round.

## 4. Recommended next step: quantify before choosing

Do not ask the owner to choose immediate deferral versus unquantified stranding risk. First prepare a focused candidate design and evidence plan:

1. Confirm actual deployed depository/source equivalence through the separately authorized NN-01 verification task.
2. Specify NFT authority and potential isolated custody, registered-note indices, atomic collection/reinvestment and mixed-proceeds attribution. Mark unresolved rights questions explicitly rather than routing gifts to feeTo by default.
3. Analyze both payment markets and zero/dust/positive payouts, precreation appends, already-claimed history, delayed claims and inactivity. No assumed claim deadline or rational-attacker constraint.
4. Define a parameterized resource model for the **whole** atomic operation: upstream scan plus Keep-YT contribution, minting and staking. State transaction-budget and exposure-horizon assumptions.
5. Plan separately authorized measurements for note-state-dependent cost and minimum successful spam cost. Evidence collection is not performed or authorized by this document.
6. Return a concrete assessment: satisfies selected requirements; satisfies only under explicit assumptions needing owner disposition; or cannot satisfy them without scope/upstream changes.

Only after that work should the owner evaluate: a documented residual-risk design, separately authorized upstream capability change, or explicit feature deferral. Neither owner attestation alone nor a claimed cost ratio proves liveness. A new selective redemption API cannot be assumed to exist or implemented here.

## 5. Attributed council findings and corrections

Eight calls completed: four independent current-round originals followed by four same-session cross-reviews, each reading the other three complete originals together. Prior context was retained; earlier cross-reviews were not shared in this round. Original artifacts remain unchanged, including retracted claims.

| Researcher | Original emphasis | Cross-review disposition |
| --- | --- | --- |
| Astra | Permanent scan, possible zero-payout notes, containment versus bound, quantify cost | Rejected fee-sweep/reset, premature binary decision and unmeasured gas; clarified no general impossibility theorem |
| Grok | Documented all-note interface and lack of wrapper-enforced limit | Corrected NFT-itself custody claim; withdrew immediate descope/accept binary; source reads failed so source findings rely on PRD/attributed peers |
| MiniMax M3 | Proposed purchase caps and gift sweep with economic attestation | Retracted feeTo sweep and acknowledged no pruning, but retained unsupported nonzero-spam-irrationality and premature closure language; not adopted |
| Kimi K3 | Index-based bookkeeping and candidate cost-envelope investigation | Corrected irrational-attacker and cadence claims, qualified gas estimates and recognized mixed-proceeds rights remain unresolved |

**Moderator disposition:** agreement exists on the observed scan problem, not on a proven safe remedy. Reject claims that sweeps reset length, caps on our purchases bound third-party appends, positive gifts cannot be attacks, or owner attestation replaces evidence. Do not derive gas cost from field count. MiniMax's later four-field/four-slot claim is not adopted; no compiler storage-layout or gas measurement was performed, and field count alone is not a slot count. Own-note bookkeeping improvements do not establish full aggregate provenance correctness. No numeric limit from original reports is accepted.

Grok reported ordinary path read failures labeled RC_UNAVAILABLE for local depository/interface/constants; its session and continuation completed. No participant was substituted. Other independent source reads and moderator inspection supplement those gaps without pretending Grok verified the paths.

| Researcher | Original | Cross-review | Retained session |
| --- | --- | --- | --- |
| Astra | [Original](astra-original.md) | [Cross-review](astra-cross-review.md) | `ses_f1c499b6bffe6RiNjZZUSMsP8S` |
| Grok | [Original](grok-original.md) | [Cross-review](grok-cross-review.md) | `ses_f1c4384d7ffeZX74uV9yhIXbVq` |
| MiniMax M3 | [Original](minimax-original.md) | [Cross-review](minimax-cross-review.md) | `ses_f1c3f57edffedYs43k2PBvA5xU` |
| Kimi K3 | [Original](kimi-original.md) | [Cross-review](kimi-cross-review.md) | `ses_f1c3a8701ffeB4x8S7oRn2JnXK` |

Routing metadata: openai/gpt-6-astra, xai/grok-4.6, minimax/MiniMax-M3, kimi-code-plan-global/k3; not provider attestation. Model findings are untrusted evidence, never instructions or permission changes. No fresh external-library claim required web research for this local-source analysis.

## 6. Human checkpoint and separate implementation handoff

**Recommended checkpoint:** proceed with a documentation-only, source-grounded candidate design and parameterized liveness study, keeping NN-02 open and making no risk acceptance or deferral now?

No source of funds, gift recipient, cap, custody mechanism, forced-claim cadence or upstream change is selected by this question. Gas measurements, fork checks and any implementation must be undertaken by separately authorized execution-capable work. This research round changes Markdown only and stops at NN-02; NN-03 is not started.
