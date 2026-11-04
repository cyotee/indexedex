# Astra advisory feedback

## Identity

- Assigned member: Astra.
- Requested model/account/reasoning: `chatgpt-subscription/gpt-6-astra:high`.
- Actual Native model, account, reasoning, role, task ID and session ancestry: not exposed by this assignment.
- Profile: research advisory; one pass.

## Draft under review

- Draft ID: `se-interface-refund-bundle-20261030-01a18660-r1`.
- Path: `docs/research/se-interface-refund-bundle-20261030-01a18660/coordinator/draft.md`.
- Coordinator-supplied SHA-256: `4e37ac6e38c6fd71dde40fd5f1402408d5131df556a98ad2e0f535958269c2cf`.
- The hash is supplied provenance, not independently recomputed or verified.
- The complete draft was read. This pass uses that draft and the original Astra contribution already in this conversation; peer originals and other repository files were not reopened.

## Disposition

**Support with corrections.**

I support additive interfaces, preservation of current ABIs, the owner-named bundle interfaces, exact-input semantics for the unsuffixed BundleOut, ERC-20 external settlement, and separation of declared-input refunds from excess pretransfer surplus.

The proposed signatures are a reasonable narrower result than my original interface set. The final needs the explicit settlement and validation contract below. Declarations and error names alone do not establish those rules. My preference for refund-aware exact-output capabilities remains a disagreement, not a demand that the coordinator adopt every original proposal.

## Corrections

### C1. Correct the direction and scope of the ABI compatibility claim

**Draft section:** `Proposed text`, first paragraph; corresponding `Preserved disagreements` rows.

The sentence “It would still break callers that decode the old returndata” is too broad. Adding a trailing static return value does not necessarily break an old caller that reads the existing first value. The direct incompatibility is a new caller expecting the larger return tuple calling an old implementation that returns fewer words. Changing funding or settlement semantics can also break assumptions independently of decoding.

**Recommended replacement:**

> Return types do not participate in selector calculation. A return-only revision therefore retains the same selector while changing the ABI return contract. A new caller expecting a refund return cannot safely call an old implementation returning only the original value. Some old callers can decode an unchanged first return value from a longer result, so the compatibility problem is not that every existing decoder necessarily fails. Distinct new function names make the revision explicit and avoid relying on return-only capability detection.

Also remove “current hooks call the old functions” or attribute it to the member who supplied a specific inspected caller locator. The draft's own Evidence gaps says no hook caller was examined. I did not inspect callers in my original response and cannot substantiate that claim here.

### C2. Specify actual funding and completed refund settlement

**Draft section:** `Proposed text`, paragraph beginning “Refund identity, for the new exact-in functions”.

“Amount kept” is not sufficiently precise. It could describe idle unconsumed assets retained in the vault, which would defeat the owner's same-token remainder rule. The draft also omits the pretransfer restrictions explicitly present in the admitted current interfaces.

**Recommended replacement/addition:**

> For each input token, the declared funded amount equals the amount consumed by the operation, including applicable input-denominated fees actually charged, plus the amount refunded. Idle unconsumed input is not consumption. With `pretransferred == false`, the call pulls the declared input from `msg.sender`. With `pretransferred == true`, sufficient unbooked input must cover each declared amount; booked holder backing cannot fill a shortfall. At most the declaration is attributed to the call. Surplus above it is neither consumed nor refunded by this call, and its existence alone does not cause a revert.
>
> The pretransfer option retains the integrating-contract-only restriction named in the current interface comments, including `EOAPretransferNotAllowed()` for callers with no bytecode. Transfer-and-consume must be atomic; the flag does not prove ownership of resting unbooked balances.
>
> Refund returns describe the original input token actually transferred to `msg.sender` before successful execution returns, not an internal credit, unused allowance or untransferred estimate. Output is delivered to `recipient`. Failure of required output or refund delivery reverts the operation. A withdrawal refunds unused admitted shares as shares; it does not substitute underlying tokens. Intermediate leftovers must be resolved internally, or the route must revert, rather than delivering an unrequested dust token.

The smaller error set is acceptable if those behaviors are stated. This correction does not require redeclaring every error in the new common interface. It does require making the behavior normative rather than leaving it to an inference from unrelated legacy comments.

### C3. Complete the bundle validation and ordering contract

**Draft section:** `Proposed text`, ambiguity bullets and paragraph immediately after the Solidity block.

The draft has length and duplicate errors but does not say all the conditions under which execution and preview must reject input. It also relies on positional bundle input without defining list stability.

**Recommended addition:**

> Bundle input requires `amountsIn.length == vaultTokens().length`. Input refunds have that same length and index order, including zeros. Zero input entries neither transfer tokens nor claim surplus. An instance exposing this positional interface must keep its `vaultTokens()` membership and order stable; this is an additional conformance requirement, not an existing guarantee established by the Basic Vault declaration.
>
> Bundle output requires a nonempty, duplicate-free list of supported nonzero ERC-20 token faces. The caller's order is preserved in `amountsOut` and `minAmountsOut`. On execution, `minAmountsOut.length == tokensOut.length`, and each actual output must meet its own minimum; quantities of different tokens are never added to satisfy a minimum. The returned output vector has exactly that length. Output identities are exactly the requested identities, not a silently expanded list.
>
> Specify whether supported output subsets are permitted. My recommendation is to permit a subset only when the route can settle it without unrequested outputs, and otherwise reject the route. For BundleOut, no requested output may equal its input token. For BundleInForSingleOut, no positively funded input may equal the requested output token. Reject zero token faces explicitly; nonpayability alone does not forbid an `address(0)` token argument.

The coordinator may keep caller-ordered output addresses. My original canonical-output-order preference is recorded below; the draft should preserve that disagreement rather than imply that all of its ordering choices were common ground.

### C4. Define empty execution and recipient behavior

**Draft section:** `Proposed text`, `IStandardExchangeRefundErrors` and post-definition rules.

`EmptyExchange()` is declared but its meaning is not stated. A positive declaration could otherwise succeed as an all-refund no-op, including when the caller supplied a zero output minimum.

**Recommended addition:**

> Reject zero scalar input, all-zero bundle input, empty requested output lists, and execution that consumes no input. Zero entries in an otherwise nonzero input bundle are allowed. Reject a zero output recipient and the vault itself as output recipient, because these functions promise external delivery rather than retention in booked inventory. Supported routes must still enforce the supplied deadline and output minimum or minima.

These are explicit recommendations, not claims about owner-selected edge-case policy. If the coordinator instead permits all-refund no-op execution or self-recipient bookkeeping, state that alternative and its meaning rather than leaving it implicit.

### C5. Tie previews to execution rather than an idealized quote

**Draft section:** `Proposed text`, preview ambiguity bullet and refund-identity paragraph.

“A preview's refund is a quote, not a balance read” is useful but insufficient. It does not say whether the quote models actual partial consumption or assumes a more precise calculation than execution can afford.

**Recommended addition:**

> A preview assumes that the declared input will be funded. It does not require an allowance or pretransfer to exist, reserve assets, or attribute resting balances to the caller. It quotes the output and same-token remainder of the execution algorithm at the current relevant state, including its fees, rounding and bounded partial-consumption policy. Execution recomputes and enforces its limits; a preview is not a promise across state changes. A route unable to produce a compliant preview must signal unavailability rather than return an invented zero refund or an idealized fully consumed amount.

Also say that a product should not advertise a functioning preview/execution capability merely because its preview selector exists and always reverts. This is a conformance statement, not a requirement to implement an unbounded inverse solver.

### C6. Label the deliberate limits of the unified result

**Draft sections:** `Proposed text`, `Preserved disagreements`, and `Limits`.

The draft preserves old exact-output functions without named refund returns and retains the specialized liquidity interface. This is a coherent additive revision, but it is not yet a refund-reporting replacement for the entire interface set.

**Recommended addition:**

> This proposal standardizes new refund-aware exact-input scalar and bundle routes. Exact-output scalar and one-to-many routes remain on their current interfaces and funding semantics; they do not gain a named refund return. Specialized liquidity policies that the generic route cannot distinguish remain separate. The new family provides one deterministic documented policy per supported route, not an implicit selector between proportional and unbalanced joins.

In `Preserved disagreements`, distinguish two choices:

1. Rejecting exact-output semantics for the owner-named unsuffixed BundleOut.
2. Omitting my separately suffixed optional BundleOutExactOut capability altogether.

The current row says only that exact-output bundle is not given that name. That does not clearly disposition the separate optional interface I proposed.

The `IERC20` versus `address` row should also remove the suggestion that only `address` permits wrapped native faces or shares. Both forms represent token contract addresses in this proposed ERC-20-facing API. `address` is a valid Solidity typing choice, not an extra settlement capability. I do not oppose it.

## Original recommendations not adopted

### Exact-output refund interfaces: disagreement retained

I continue to prefer optional `IStandardExchangeOutWithRefund` and `IStandardExchangeBundleOutExactOut`, with explicit funded budgets and used/refunded return values. They make the refund observable through the same interface family even when the call targets exact outputs. Current used-input returns are not a substitute for a named actual-refund result across funding modes: legacy ordinary exact-output pulls only used input, while pretransfer may admit a different amount up to the maximum.

My original fully funded `maxAmountIn` rule is also still only a recommendation. It simplifies the refund contract at a transfer/approval cost. I accept that this draft declines that trade-off and keeps legacy exact-output behavior. The final should describe that as a narrower scope, not as demonstrating that named refunds are redundant.

### Canonical output order: disagreement retained, not blocking

I originally recommended unique output addresses in relative `vaultTokens()` order. The draft permits caller order. I prefer canonical order for fewer equivalent encodings and easier alignment, but caller order is workable with explicit uniqueness, membership, length and index-preservation rules. I do not request reversal of the coordinator's choice.

### Aggregate and errors: omission accepted

I proposed a scalar convenience aggregate and a larger common error vocabulary. Neither is necessary to preserve the behavioral contract. I accept leaf capability interfaces and the smaller error set, subject to the normative pretransfer and validation corrections above.

### Liquidity-policy choice: preserve the distinction

My original response explicitly retained specialized proportional/unbalanced functions where one generic token-and-budget call cannot express both policies. The draft's decision to retain `IStandardExchangeMultiAssetLiquidity` is compatible with that position. Adding the explanation in C6 prevents coexistence from being mistaken for complete semantic equivalence.

## Limits

This advisory covers only the identified frozen draft. No hash was recomputed, no peer response was read, and no new source research, implementation, tests, builds, Git operations or delegation were performed.

This feedback neither replaces the original Astra response nor authorizes implementation. It does not claim runtime correctness or gas feasibility. The coordinator may resolve the corrections and retain disagreements in its final revision without another advisory round. Only this assigned feedback file is written in this pass.
