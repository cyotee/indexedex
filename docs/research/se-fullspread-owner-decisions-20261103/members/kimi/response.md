# Owner-decision assessment

## Identity

- Run ID: `se-fullspread-owner-decisions-20261103`
- Member: `kimi`
- Profile: research
- Phase: initial independent response
- Requested role: council-member
- Requested model and reasoning: `kimi-coding/k3.1-pro:high`, global route
- Actual role, model, reasoning, and task ID: not exposed
- Peers read before submission: no
- Fresh context: yes

## Question and targets

For each owner decision on F1 through F12, determine whether the owner misunderstood the recommendation and whether the decision has one of the problems defined in the brief. The targets are the verbatim owner responses in `docs/research/se-fullspread-owner-decisions-20261103/brief.md` and the corresponding recommendation sentences in `docs/research/se-fullspread-blockers-resolutions-20261103/REPORT.md`.

## Evidence

### Source observation

- I read all owner responses F1-F12 in the brief and all recommendation sentences F1-F15 in the recommendation report.
- I read the locked pretransfer behavior in `docs/vaults/PRETRANSFER_DIRECTIVE.md`, particularly the over-maximum refund and no-shortfall-pull rules.
- I read the locked behavior in `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`, including B-02, B-11, B-13, the donation/compound booking rule, and the already-locked no-leftover-shortfall-revert sentence.
- I read Crane's operator guard in `lib/crane/contracts/access/operable/OperableRepo.sol`. Its `_onlyOwnerOrOperator` checks the stored `MultiStepOwnableRepo` owner, a global operator, or a function operator (`lib/crane/contracts/access/operable/OperableRepo.sol:211-217`).

### Inference rules

- An unqualified acceptance of a conclusion or proposed sentence adopts the complete recommendation, not merely its short-form locator.
- An explicit rejection or reconsideration may change a recommendation without being a defect.
- I treat the owner's F6 swap-sizing remarks as relevant to the decision because they reintroduce a candidate sizing rule after F5 was accepted. I do not treat them as changing the accepted F6 exit rule.
- No protocol behavior was executed.

## Assumptions

- The owner responses copied in the brief are the complete decisions to assess.
- The locked sources govern only where the brief's problem definition makes an existing lock relevant; a recommendation itself was not already an owner lock.
- The owner's F7 statement that `Compounded()` is emitted when booked tokens are deployed applies to every such deployment, without inferring an unstated fee-origin filter.

## Coverage

All decisions F1-F12 are assessed below. F13-F15 are recorded only as undecided. No peer response was read, and no unanswered product question is decided here.

## Conclusions

### F1

- Misunderstood: yes.
- Problem: yes.
- Changed the recommendation: yes.
- Source observation: The recommendation requires an internal unbooked-balance snapshot and a refund-only branch when a declared maximum exceeds that snapshot (`REPORT.md`, F1). The owner rejects that snapshot and instead discusses ERC-20 recipient notification, compatibility with existing tokens, and the risk of non-atomic pretransfers (`brief.md`, F1). The recommendation proposes neither an ERC-20 notification nor a new token standard. The existing lock specifies the refund and prohibits pulling the shortfall, but does not say whether any leg is processed in the over-maximum case (`docs/vaults/PRETRANSFER_DIRECTIVE.md`).
- Inference: The stated reason answers a mechanism the recommendation did not propose. Rejecting the snapshot without supplying the processing rule leaves two implementors able to choose different behavior for an over-maximum call.
- Missing fact: When the declared maximum exceeds the available unbooked balance, does the call process no leg, or does it process using the available balance?

### F2

- Misunderstood: no.
- Problem: no.
- Changed the recommendation: no.
- Source observation: The owner accepts the conclusion and says other operations do not interleave `compound`; fees remain untouched except for donation and compound (`brief.md`, F2). The recommendation books fees collected by the specified liquidity modifications but does not credit, refund, deploy, or compound them (`REPORT.md`, F2).
- Inference: In context, “leave fees untouched” describes the absence of deployment or compounding, not a rejection of the expressly accepted booking rule. The decision is copyable.

### F3

- Misunderstood: no.
- Problem: no.
- Changed the recommendation: no.
- Source observation: The owner unqualifiedly accepts the conclusion (`brief.md`, F3), which defines the post-call booked total, the zero-size skip, and revert-on-failure behavior (`REPORT.md`, F3).
- Inference: The accepted sentence is complete and copyable.

### F4

- Misunderstood: no.
- Problem: no.
- Changed the recommendation: no.
- Source observation: The owner accepts the definition (`brief.md`, F4). The recommendation defines the ratio from the current pool price and stored ticks, excluding unpaid fees and booked balances (`REPORT.md`, F4).
- Inference: The accepted definition is complete and copyable.

### F5

- Misunderstood: no.
- Problem: no.
- Changed the recommendation: no.
- Source observation: The owner accepts the conclusion (`brief.md`, F5). The recommendation sizes the swap to the greatest integer liquidity the following add can take and expressly rejects “about half” (`REPORT.md`, F5).
- Inference: F5 itself is accepted without qualification. The conflicting remarks under F6 are assessed there rather than treated as an F5 misunderstanding.

### F6

- Misunderstood: yes.
- Problem: yes.
- Changed the recommendation: no.
- Source observation: The owner expressly accepts F6's proposed sentence, which concerns converting unwanted one-token exit principal or reverting `AmountOutNotMet` without burning shares (`brief.md`, F6; `REPORT.md`, F6). The explanation instead discusses sizing an entry/donation/compound swap, says it should be as easy as swapping 48%, and leaves the correct algorithm to later proof or fuzzing. F5 expressly rejects “about half” in favor of the greatest-integer-liquidity target (`REPORT.md`, F5), and the owner accepted F5 (`brief.md`, F5).
- Inference: The explanation addresses F5's mechanism rather than the F6 exit residual, so it misunderstands the recommendation it is explaining. It also gives conflicting swap-sizing directions: one implementor could use 48%, while another could follow the already accepted greatest-integer-liquidity rule. The F6 exit sentence itself remains accepted and copyable; the problem is the decision's unexplained conflict with F5, not a missing F6 exit fact.

### F7

- Misunderstood: no.
- Problem: no.
- Changed the recommendation: yes.
- Source observation: The recommendation emits `Compounded()` only for a positive liquidity add whose own modification collects a nonzero fee, excludes a donation-only deploy and a later deploy of previously booked fees, and does not add a donation event (`REPORT.md`, F7). The owner instead ties `Compounded()` to deploying booked tokens, requests `Donation()`, and requires both events for a donation that also collects accrued fees (`brief.md`, F7).
- Inference: This is an intentional change of event semantics, not a restatement of the recommendation. Emitting `Compounded()` on every booked-token deployment is executable without inferring a fee-origin store, and the requested combination with `Donation()` is stated. The new rule is copyable.

### F8

- Misunderstood: no.
- Problem: no.
- Changed the recommendation: no.
- Source observation: The owner accepts the conclusion (`brief.md`, F8), which requires the one-time initialization write of all seven package addresses into the instance Protocol Aware Repo (`REPORT.md`, F8).
- Inference: The accepted sentence is complete and copyable.

### F9

- Misunderstood: no.
- Problem: no.
- Changed the recommendation: no.
- Source observation: The owner accepts the conclusion (`brief.md`, F9). The recommendation assigns `poolManager()` to the Crane Protocol Aware facet and the position getters to `UniswapV4SinglePositionAware`, with no family-only duplicate (`REPORT.md`, F9).
- Inference: The accepted selector allocation is complete and copyable.

### F10

- Misunderstood: no.
- Problem: no.
- Changed the recommendation: no.
- Source observation: The owner accepts the conclusion (`brief.md`, F10), including the three-argument nonpayable `donate` signature, no return value, and the false flag for share donation (`REPORT.md`, F10).
- Inference: The accepted interface rule is complete and copyable.

### F11

- Misunderstood: no.
- Problem: no.
- Changed the recommendation: no.
- Source observation: The owner accepts the conclusion (`brief.md`, F11). The recommendation permits borrowed-path `exchangeIn` and only the single-output `exchangeBundleOut` one-token exit, while retaining `ManagerAlreadyUnlocked` for the other named routes (`REPORT.md`, F11).
- Inference: The accepted route and error rules are complete and copyable.

### F12

- Misunderstood: no.
- Problem: no.
- Changed the recommendation: yes.
- Source observation: The recommendation stores the initialization-time `feeTo()` owner and forbids later live reads (`REPORT.md`, F12). The owner expressly says they have reconsidered and instead wants each authorization check to use the currently configured `feeTo()`, while retaining global and function-level operator authorization (`brief.md`, F12). Crane's existing combined guard already supplies the two operator checks, although its owner side reads stored ownership (`lib/crane/contracts/access/operable/OperableRepo.sol:211-217`).
- Inference: This is an express replacement, not a silent reversal or a mismatched restatement. A new live-`feeTo()` owner check combined with the existing operator checks is executable against the code read; the change does not introduce an unresolved product rule.

F13, F14, and F15 were not decided; their silence is not acceptance.

## Limits

This assessment used only the admitted documents and local Crane source. It did not read peer responses, run code or tests, or inspect any runtime behavior. It neither authorizes implementation or a PRD edit nor supplies replacement locks for unanswered product choices.
