# Kimi advisory feedback

## Identity

- Run: `se-fullspread-remediation-plan-20261106`
- Member: `kimi`
- Profile: research
- Phase: advisory review
- Requested role: council-member
- Requested model: `kimi-coding/k3.1-pro:high`, global route
- Runtime identity: not exposed

## Draft under review

- Draft ID: `draft-se-fullspread-remediation-plan-20261106-r1`
- Path: `docs/research/se-fullspread-remediation-plan-20261106/coordinator/draft.md`
- Coordinator-supplied SHA-256: `b2738a3b21c993f0e13153cdf7aefa4e27cd113f318f75c3d0adf54d3de74fba`
- The hash was recorded as supplied and was not recomputed.

## Disposition

requested-changes

## Concerns

| Draft section | Why two readers could diverge | Requested change |
| --- | --- | --- |
| Sections 4, 6, and 10: one-token exit receipt | The draft assigns the four-part `amountOut` to `Planner._exit` and says the minimum binds the receipt, but its `Execution.exchangeIn` row names only the failed-plan error. One reader could pay and return the pre-execution planned quote; another could use the actual settled requested-token proceeds. The owner lock excludes a stale preview, and the exit test does not explicitly compare the recipient's balance delta with the returned receipt. | Advise naming `Execution.exchangeIn` as the seam that derives the actual post-execution four-component receipt, enforces the minimum on that receipt before burning, and returns and pays that same amount. Advise extending the exit test to assert returned `amountOut`, recipient balance delta, actual swap proceeds, and the three direct components together, including a state where the settled proceeds differ from the preview. |
| Sections 4 and 5: one-sided arithmetic and maintenance booking | `Planner._size` is the only sizing edit seam named, although the adopted collapse arithmetic is in `Math.sizeOneSided`. The draft also does not explicitly require the projection to spend the complete 49%, so one reader could accept a partial quote and size from `quote.spent`; another could reject it as an unformable 49% swap. `Planner.planMaintenance` says it does not refund dust, but no execution function is named for booking that dust or a collapsed input. | Advise naming `Math.sizeOneSided` and requiring complete expenditure of the 49% input, complete add consumption of the received output, sufficient unswapped input for the add, and input-token-only remainder. On every rejected candidate, advise clearing the swap and add and returning the full processed input. Advise naming `Execution.maintain` as the seam that books actual post-settlement boundary dust and collapsed maintenance input without a refund. |
| Section 7: `seBooked()` | The draft makes `SeMatrix_FullSpreadV4Fixture.seBooked()` return zero. F6's adopted fix direction is to remove the booked getter, while the closed law also prohibits reporting a balance. One reader could retain a booked-named stub forever; another could read F6 as requiring its removal. A zero stub also leaves row dependencies on a getter the family plan says not to add. | Advise removing `seBooked()` and its test-row consumers rather than replacing its balance expression with zero. Reiterate that neither a raw-balance substitute nor a production booked view is required. |
| Section 7: capacity overrides | “Keep the empty overrides if the parent declares them” treats every parent declaration as requiring an override. A parent can declare a virtual function with a body, for which an override is optional. One reader would retain declarations the closed law says to remove when not required; another would remove only abstract requirements. | Advise using the parent-requirement test from the closed law: retain empty overrides when the parent requires the concrete fixture to provide them; otherwise remove the overrides. In either case, keep them free of capacity-gate logic. |
| Sections 4 and 10: removed sizing helpers | The production table inventories removed helper names, and the test table adds a `QuotesAndRate.t.sol` row whose assertion is only that no assertion requires those helpers. That is a meta-test about test contents, not an adopted economic assertion. One reader could add absence tests or preserve dead helpers for reference; another could treat the fixed 49% behavior as the entire requirement. | Advise removing the helper-name inventory and the `QuotesAndRate.t.sol` meta-row. Keep the prohibition on restoring removed methods without creating a new absence-test requirement; rely on the inside, boundary, collapsed, and first-deposit behavior rows to prove the adopted method. |
| Sections 7 and 10: package rejection cases and binding sensitivity | “`InvalidComponent` for each of the six addresses” does not say that each address needs both a missing-value case and a nonzero code-empty case. Likewise, “a `bindingHash` change” can be read as one representative mutation rather than FS-A02's sensitivity to every facet, library, and infrastructure binding. Two readers could therefore write materially different coverage while both citing these rows. | Advise requiring zero/missing and code-empty nonzero cases for each of the six addresses, with `InvalidComponent` and no usable diamond for each case. Advise stating that `bindingHash` changes for a mutation to any facet, linked library, or infrastructure binding, including each named infrastructure address. |
| Sections 8 and 12: gas coverage and completion gate | Section 8 assigns standalone gas to “the money or maintenance file,” preview gas to “the quote file,” and composed gas generically to each section 12 row file. This does not name the assigned files or enumerate the rows as the brief requires. Section 12 then stops when section 10 alone is true, although section 10 contains no gas rows, so an implementer could finish without any section 8 measurement. | Advise naming `Money.t.sol` for all seven standalone routes, `QuotesAndRate.t.sol` for each preview, `BufferHookIntegration.t.sol` for existing composed integration, and every family-plan section 12 row file for its own composed measurement. Advise making completion conditional on the package/fixture requirements and every section 8 and section 10 row, with each oversized route reported unresolved rather than passed. |

## What was not adopted from others

No peer response or peer feedback was read. No outside concern was adopted. This review uses the named draft and the already admitted remediation law only.

## Limits

This is advisory feedback only. It does not replace the draft, authorize implementation, or claim any test result. No draft, remediation PRD, peer file, response file, project code, or other artifact was edited. No tests, builds, installs, Git operations, or sub-agents were used. No further review round is requested.
