# Remediation PRD readiness response

## Identity

- Member: kimi
- Phase: initial independent response
- Role: council-member
- Profile: research
- Requested model: `kimi-coding/k3.1-pro:high`, global route
- Runtime identity: not exposed

## Target and fingerprint

- Target: `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`
- Coordinator-supplied SHA-256: `93907efa35b135f33f3c893390fcc2154bae1f011d1f74718f1a245a51853d07`
- Independent fingerprint: not computed

## Verdict

ready

## Basis

The current remediation PRD supplies a closed basis for one remediation implementation plan. It does not leave a product choice that requires another owner decision.

- **Owner lock, 2026-11-06 — Scope, Rule, Boundary, and Collapsed candidate.** The one-sided sizing method is fixed at 49% of the processed input, followed by the add. The lock expressly withdraws iteration, exact-output sizing, closed-form solving, and tick walking. It also fixes behavior strictly inside versus at or outside the position boundaries, the token in which rounding remainder remains, refund versus booked treatment, collapsed-candidate handling, and the first-deposit `MinLiquidityNotMet` exception. F3 and F4 must be read through this lock; the removed sizing method is not still required.
- **Owner lock — Exit receipt; F1 and F2.** An incomplete one-token exit raises `AmountOutNotMet` and does not burn. The caller minimum and returned `amountOut` bind the recipient receipt: swap proceeds, withdrawn requested-token principal, the requested-token fee portion, and the requested booked claim. This closes the error and payment-basis choices without requiring a payout shortfall to have been observed.
- **Owner answers 1–5; F5–F11.** The six infrastructure bindings require code checks and `InvalidComponent`; the weighted two-leg row keeps its specified `setUp` override; the `exchangeRate` test is withdrawn while `getRate` remains absent; and the package, money, standalone-gas, and composed-gas additions are assigned to their named surfaces. The standalone routes, composed-row coverage rule, and ceilings are explicit.
- **F7 — Fixture capacity functions.** Checking the parent requirement before deleting the empty capacity overrides is an engineering check already assigned by the text, not an owner product choice. The booked getter removal is explicit.
- **Migration scope.** This remediation does not walk or certify the preview-consumer migration, while the family plan continues to require that migration. The remediation plan can therefore state its scope without deciding whether the family migration requirement still exists.
- **Unresolved, not adopted and not rejected.** These entries are expressly not adopted findings or new requirements. They do not create product choices that a remediation plan author must resolve. Where they call for source inspection or classification, that is engineering work against the existing family requirements, not a request for an owner decision.

Two careful authors can apply these locks and recommendations to the family plan and family PRD without selecting between contradictory product sentences. No section of the current remediation PRD names an open owner product choice.

## Optional context

- Family PRD: examined only to test whether the current remediation PRD still needs an owner choice.
- Family plan: examined only to test whether the current remediation PRD still needs an owner choice.
- Prior readiness report: not examined.

## Limits

This verdict concerns readiness to write the remediation implementation plan. It is not a verdict that the code is ready, runtime behavior is verified, or implementation is authorized. No tests, Git operations, installs, or implementation edits were performed.
