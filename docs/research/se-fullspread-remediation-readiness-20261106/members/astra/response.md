# Independent readiness response

## Identity

- Run: `se-fullspread-remediation-readiness-20261106`
- Member: astra
- Profile: research
- Phase: initial independent response
- Role: council-member
- Requested model: `chatgpt-subscription/gpt-6-astra:high`
- Runtime model, reasoning level, and task identity: not exposed

## Question and targets

Can one remediation implementation plan file be written from the current `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`, using the family plan and family PRD only as the base it amends, without another owner product decision?

I read the whole current remediation PRD, including its 2026-11-06 owner lock.

- Coordinator-supplied specification fingerprint: `93907efa35b135f33f3c893390fcc2154bae1f011d1f74718f1a245a51853d07`
- Independent fingerprint: not computed
- The supplied fingerprint is provenance, not independent verification.

## Verdict

not ready

## Evidence

### One contradictory product choice: maintenance remainder at the wanted-token boundary

Location: remediation PRD, **Owner lock, 2026-11-06**, paragraphs **Scope**, **Rule**, and **Boundary**.

The scope includes a one-token `donate` or `compound`. Rule says:

> A user-deposit remainder is refunded. A donate or compound remainder is booked.

Boundary then says, for a price not strictly inside the position:

> If the caller provided that token, add it with no swap and refund what the add does not take.

That sentence does not restrict its refund instruction to a share mint. The next branch, for the other token, expressly distinguishes routes:

> A share mint refunds it. A donate or compound books it.

**Observation:** Within this same current lock, the wanted-token branch commands a refund without a route qualification, while Rule commands booking for maintenance remainders. Neither sentence expressly identifies the wanted-token maintenance branch as an exception to the other.

**Inference:** Two careful plan authors can specify different observable behavior for an authorized one-token donation of the token the boundary position accepts, where the add leaves a remainder. One follows Boundary's specific refund instruction; the other follows Rule's maintenance booking instruction and reads Boundary's refund as applying only to a user share mint. Their tests would disagree about whether the remainder leaves the vault or stays booked. This is a product accounting choice, not a choice of helper, rounding implementation, or test fixture.

The admitted base does not remove the split:

- The family PRD, `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`, **FS-OWN-33**, repeats both the unqualified wanted-token refund sentence and the maintenance-booking sentence.
- The family plan, `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md`, **section 9, donate and compound**, says: "Do not refund a donation or compound remainder." That supplies the base behavior, but it cannot decide whether the newer remediation boundary sentence intentionally amends it.

The needed clarification is confined to **Owner lock, 2026-11-06 / Boundary**: state the maintenance remainder disposition for the accepted-token, no-swap addition and make it consistent with Rule. I am identifying the conflicting instructions, not choosing an owner outcome or proposing alternative products.

### Decisions that do not remain open

- **Sizing:** The current lock and F4 replace the earlier sizing method with 49% of processed input. No iteration, closed-form root, exact-output sizing, or search for a better split remains required.
- **Collapsed candidate and genesis:** The lock distinguishes zero active liquidity from a boundary price, rejects a candidate without retaining its swap, separates user refunds from maintenance booking, and preserves `MinLiquidityNotMet` for a first deposit that does not add more than 1,000 liquidity.
- **Exit receipt:** The lock and F2 enumerate the recipient receipt, including requested-token principal, fees, and booked claim. F1 fixes the incomplete-exit error and no-burn outcome. An implementation still needs to establish the actual receipt; that is not another product question.
- **Infrastructure, weighted setup, rates, and gas:** Owner items 1-5 settle the six component checks, the weighted two-leg override, the excluded `exchangeRate` test, the named standalone routes, composed-row coverage, and the ceilings.
- **Fixture and package coverage:** F6 directs removal of the booked getter. F7 assigns a parent-requirement check before deleting capacity overrides; it does not require an owner to choose a new sleeve policy. F9 and F10 identify the required missing assertions.
- **Migration and unresolved observations:** Migration scope explicitly excludes walking or certifying the index in this remediation while retaining the family obligation. The unresolved list records unadjudicated observations, not additional product decisions or permission to mark unverified behavior passed.

## Assumptions

The current dated lock controls older sizing and setup statements. Historical findings retain their stated evidence limits. The base documents do not override a current remediation amendment. An engineering check or unexecuted acceptance test does not, by itself, make the source unsuitable for planning.

## Coverage

| Admitted source | Examination |
| --- | --- |
| Current run brief | Read in full |
| Current remediation PRD | Read in full |
| Family PRD | Partially examined, including owner rules and FS-OWN-33, to test the remainder conflict against the base |
| Family implementation and testing plan | Partially examined, including sections 2, 6-10, and the section 12 fixture rules, to distinguish product choices from assigned engineering checks |
| Prior readiness report | Not examined |

## Conclusions

The accepted-token boundary remainder is the one product choice I find contradictory in the current remediation PRD. The other examined decisions are sufficient to direct planning without reopening their owner locks. The verdict concerns the text as currently written, not a prior readiness report and not whether implementation or tests already conform.

## Limits

This was a static, independent reading of admitted documents. I did not inspect production code, historical question files, or peer responses; run tests, Git, or installs; recompute the fingerprint; or launch sub-agents. This response does not write or replace the implementation plan, amend the PRD, or authorize implementation.
