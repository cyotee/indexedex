PermissionedGreeterDFPkg (example)

## Intent
- Example DFPkg used by Crane/daosys examples: deploys a simple permissioned greeter proxy to demonstrate DFPkg patterns and lifecycle hooks.

What this package configures
## Proxy
- example permissioned greeter proxy (not production-critical)
- Facets: simple greeter facet, access control facet demonstrating owner-only functions and `IMultiStepOwnable` usage.

## Trust boundaries
- Example packages often leave `processArgs()` ungated for simplicity, but maintainers should note this is acceptable only for example/test code and not a pattern for production packages.

## Initialization
- Sets owner and initial greeting message; demonstrates `initAccount()` delegatecall pattern.

Post-deploy behavior (`postDeploy()`)
- Minimal; constrained to factory lifecycle in example usage.

Runtime invariants & guidance
- Do NOT reuse example package patterns for production without hardening: gating `processArgs()`, proper owner timelocks, and audit of any external calls.

Repo-wide invariants to copy from PROMPT.md (note: example only — not prescriptive for examples)
- Deterministic deployments: production DFPkgs MUST use Crane Diamond Callback Factory; examples may be simplified for demos but should be clearly marked.
- Preview policy: production previews must be conservative vs execution; example preview helpers should not be used as production references.

## Required tests
- (documented, not implemented here)
- Example tests should validate lifecycle (deploy via factory, init called, owner set) and demonstrate loupe-driven selector enumeration.

## Validation
- 
- Inventory reference: `docs/components/PermissionedGreeterDFPkg.md`
- PROMPT.md placeholder: `PENDING-MAINTAINER-REVIEW` (example)

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW
