CounterDFPkg (example)

## Intent
- Example counter DFPkg used for demos/tests showing a minimal stateful package and lifecycle.

What this package configures
## Proxy
- example counter proxy
- Facets: counter increment/decrement, simple view accessors.

## Trust boundaries
- Example only; `processArgs()` may be ungated. Not intended as production pattern.

## Initialization
- Sets initial counter value and owner.

Post-deploy behavior (`postDeploy()`)
- None or minimal example wiring.

Runtime invariants & guidance
- Do not copy example patterns into production packages without adding timelocks, gating, and tests.

Repo-wide invariants to copy from PROMPT.md (note: example only — not prescriptive for examples)
- Deterministic deployments: production packages MUST use Crane Diamond Callback Factory; example packages may bypass this for demos but must not be used as templates for production.
- Preview policy: where examples implement preview helpers, they should follow exact-in/exact-out preview inequalities in production code.

## Validation
- 
- Inventory reference: `docs/components/CounterDFPkg.md`
- PROMPT.md placeholder: `PENDING-MAINTAINER-REVIEW`

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW
