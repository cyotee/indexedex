# Identity

- Member: astra, independent council member.
- Run: `se-fullspread-plan-readiness-20261101`.
- Requested route: `chatgpt-subscription/gpt-6-astra:high`.
- Actual Native model, reasoning setting, and task identity: not exposed; not independently attested.
- Round: one advisory pass.
- Peer feedback read: no. Other members' positions are known here only through the coordinator draft.

# Draft under review

- Draft ID: `draft-se-fullspread-plan-readiness-20261101-r1`.
- Path: `docs/research/se-fullspread-plan-readiness-20261101/coordinator/draft.md`.
- Coordinator-supplied SHA-256: `3ed7a08203e0cb077ad442a4b2e8538cd315f13bd2a132ee46627f51cce5e2b3`.
- The complete named draft was readable and reviewed. Its internal fingerprint field says `not computed`.
- I did not recompute the hash, independently attest the supplied fingerprint, or substitute another draft.

# Disposition

**Request changes to the synthesis; retain the not-ready verdict.**

The draft preserves the central fee, issuance, donation, provider, and borrowed-redemption issues. It nevertheless omits a load-bearing pretransfer question, defers two expressly required deliverables, and treats several already locked outcomes or implementation mechanics as new product choices. Correcting those distinctions matters: the owner should receive the decisions that actually require an answer, not a mixture of product questions, source incompatibilities, and file-layout work.

This advisory neither replaces the draft nor authorizes implementation. The corrections below do not supply owner answers or request another advisory round.

# Concerns

## 1. Proposed text: include the current matrix extension points

The sentence that the plan "can name the live hook-by-SE matrix" does not satisfy the request to identify the current files. The final synthesis needs the concrete matrix inventory, not only its root directory.

Carry forward the seven current behavior files under `test/foundry/spec/hooks/uniswap/v4/standardExchange/`:

- `single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol`
- `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol`
- `dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol`
- `orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol`
- `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol`
- `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol`
- `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol`

Also identify `SeMatrixFixture.sol`, the seven concrete-row and decimal directories, the existing same-manager fixture adapters, `scripts/hook_se_matrix_evidence.py`, `docs/audits/apex-2026-09-17-evidence/hook-se-matrix.json`, its findings inputs, `docs/audits/apex-2026-09-17-evidence.md`, and `docs/audits/apex-2026-09-17-evidence/acceptance.json` R10.3.

Preserve the evidence distinction from my original: the historical JSON includes V4 FullSpread compatibility records, but my targeted current-file search found no corresponding V4 FullSpread matrix rows. Those historical records cannot establish compatibility of the new family. Preserve V3 rows rather than repurposing them.

Explain the two concrete adaptation needs: existing partial-consumption controls assume booked remainder, while this family refunds it; existing exact-output success controls cannot override this family's intentional rejection. These are requirements reconciliation tasks, not permission to weaken other families' tests.

## 2. What is not a new product choice; Preserved disagreements: finish the per-finding inventory

"The final inventory waits for the advisory pass" is an explicit missing deliverable, not a completed research answer. The final must contain one disposition for every APEX-2026-010 through APEX-2026-054: whether a test is required, the mechanism, and its connection or exclusion under the locked PRD.

Keep direct vault tests, analogous mechanism tests, shared-dependency tests, required-composition tests, and genuine exclusions distinct. Do not resolve applicability by counting member votes.

The blanket sentence about findings "only in ... a DETF minter, or the Crane ownership library" also needs correction. A foreign filename does not establish exclusion. The question is whether the required deployment or composition reaches that mechanism. Conversely, inclusion in a regression inventory does not authorize repairing every upstream product. A failing integration or shared-dependency regression remains visible as such.

The counts attributed to MiniMax total 44, not 45: `12 + 6 + 26`. Resolve the missing or differently counted ID explicitly before publishing totals. I have not inspected that member's original and cannot identify the missing ID from this draft.

## 3. Preserved disagreements, Pretransfer and APEX-2026-039: restore the omitted blocking question

The draft accurately reports my position but then drops its consequence. "Booking only the requested amount" limits quantity; it does not establish who supplied it. An unrelated contract can request the unattributed balance. Rejecting borrowed pretransfer does not specify the ordinary path or prevent shares being minted to the vault itself.

Add the blocking question against FS-OWN-20 and ordinary-route authority:

> What ordinary-pretransfer and self-recipient policy should the new vault enforce so that APEX-2026-039 is actually excluded, or explicitly recorded as an accepted unsupported-use exception?

The audit distinguishes non-atomic-pretransfer risk from its additional self-recipient path. Do not merge those cases or call the finding absent merely because exact-output is unavailable. This is a load-bearing omission from my original, not an answer to an owner question.

## 4. Decisions that block the plan, item 1: avoid choosing the replacement fee model

Retain the conflict between FS-OWN-24 and APEX-2026-044. Replace the forced choice between acceptance and deducting the fee from depositor shares with:

> Is the existing-holder dilution an explicit accepted exception to the audit-absence objective, or what replacement fee rule is authorized?

Net-of-fee minting is the audit's proposed remedy, not the only owner-authorized alternative. It may be described as a proposal, not embedded as the assumed replacement.

Keep the genesis fee-base question separate if the synthesis establishes that it remains unresolved. The draft should distinguish that additional question from the already sufficient 044 contradiction.

## 5. Decisions that block the plan, item 2: do not require an unauthorized price bound

Replace "what exact pre-operation bound must the plan enforce?" with:

> Is placement loss in the external-push and self-moved-price maintenance cases an accepted trade-off, or which change to the locked maintenance behavior is authorized?

The original audit discussion includes placement timing and burn/refill-only trailing maintenance, not only a price bound. The PRD forbids silently adding a cap or tick guard. The research must identify the conflict without turning one possible remedy into the owner's required answer.

Continue labeling this as a mechanism exposure requiring tests, not an executed exploit against a new implementation.

## 6. Decisions that block the plan, item 3: honor the explicit no-fee exception

FS-OWN-14 explicitly specifies no state change and no event when fees are zero. Its general statement that compound deploys idle does not require reopening that specific exception. Move item 3 out of the blocking owner decisions and state that the no-fee branch returns unchanged.

Keep the consequential sleeve/issuance problem in item 5: the plan cannot assume that a no-fee compound eliminates booked idle before pricing the next deposit. The event-amount question in item 13 is also separate and remains material.

## 7. Decisions that block the plan, item 4; Coverage adopted from responses: distinguish implementation conflict from a new holder choice

Accept the zero-address rejection as a **coordinator-checked source observation**, not as a verification I performed in this advisory.

Do not ask "which holder" without saying that changing the holder would reopen FS-OWN-11. The owner already chose `address(0)`. Installing the shared ERC-20 facet and using a family-specific initialization path are different matters; a restriction in the usual balance-increase helper does not, by itself, prove that the locked public facet and locked floor holder are incompatible.

Recast this as a concrete implementation compatibility requirement: preserve the fixed holder, total supply, and shared public ERC-20 behavior while identifying a compliant initialization path. If the admitted engineering constraints truly prohibit every such path, state the exact conflicting restriction and ask which constraint may change. The draft currently establishes the helper rejection, not that stronger impossibility.

## 8. Decisions that block the plan, items 8, 14, and 15: separate public behavior from storage and code organization

Keep item 8's public-selector question, particularly the distinction between removing a family-only `poolManager()` getter and excluding the selector from the proxy altogether.

Do not treat the six other Robinhood component addresses as unspecified values: the owner lock names the corresponding network constants. If initialization on other networks is an actual required scope, identify that missing network rule rather than presenting the known Robinhood values as undecided.

For item 14, the wrapper's network identity is already locked. Whether an internal binding lives in a repo or an immutable component is ordinarily implementation mechanics. Keep a product question only if the draft can name a genuinely unresolved observable binding or validation requirement; do not ask the owner to choose a storage location merely because a getter was removed.

Split item 15. Paired event names and arguments are externally observable ABI and merit a precise unresolved-contract statement if not already fixed by an accepted interface. What `SwapProjection` and `ExecutionPreparation` compute is code decomposition, not automatically a product choice. Their required binding slots cannot simply be removed, but an engineer can allocate already specified operations to libraries without asking the owner to design them.

## 9. Decisions that block the plan, items 9 and 10: preserve the dependency and best-effort boundaries

For item 9, retain both provider economics and the observed return-decoder incompatibility. The latter is a concrete dependency once the provider is chosen, not evidence that the vault should regain `getRate()` or a one-word preview sibling. Name the current full-supply provider behavior; do not rely on the fixture helper's one-share comment.

For item 10, explain that exact attainment of both per-token targets is not required: FS-OWN-12 is expressly best-effort. An out-of-ratio book alone does not require introducing a swap. If the question remains, narrow it to authorization for a maintenance swap, rather than implying that the locked target requires one or that failure to hit the target is a revert condition.

## 10. Preserved disagreements, Quote step cap and tick spacing: keep implementation choice distinct from product restriction

Retain the current refusal to invent a new spacing or cap question merely because a quoter must be selected. Choosing a correct implementation is not itself a product decision. An added minimum spacing, changed payout fallback, or new rejection domain would be.

The final audit inventory must still cover the dust-tick/empty-word mechanism behind 026 and 041. Absence of Wings' exact liquidation implementation does not remove analogous liveness obligations from a new executable preview and swap planner. Preserve one-token-or-revert exits, the independent proportional bundle route, and the locked gas ceilings.

# What was not adopted from others

These dispositions concern positions attributed in the draft, not independently read peer submissions:

- I do not adopt the attributed conclusion that the unbooked-balance rule alone resolves 039. It does not establish payer attribution or settle the self-recipient case.
- I do not adopt a new step-cap, minimum-spacing, or fallback requirement merely to select a quoter. Such restrictions need a demonstrated product conflict and owner authorization.
- I do not adopt the proposition that immediate donation custody alone settles one-token donation execution. Conversion, funding, and unplaceable input remain separate.
- I accept the coordinator's zero-address-helper observation as a dependency concern, but not the inferred need to choose a different floor holder.
- I do not adopt any numerical consensus on audit coverage. The final needs a traceable 45-ID inventory, including composition and shared-dependency mechanisms, not a negotiated count.

# Limits

I read only the complete named draft during this advisory and used the existing conversation context. I did not reopen the PRD, function review, audit, tracker, original responses, memory, peer files, or source code. The coordinator's added source observation remains attributed to the coordinator.

No hash was recomputed. No tests, implementation, project commands, or sub-agents were run. Only this feedback file was written; `response.md` is preserved.

This is the single requested advisory round. It neither replaces the draft nor authorizes implementation, and it does not answer the owner's unresolved product questions.
