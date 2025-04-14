Per-Component Reviewer Requirements

Purpose
- Standardize what an automated or human reviewer must check for each component in `docs/components/` so another agent can reliably review code, tests, and runtime surfaces and produce actionable findings.

Required Sections (every component doc)
- Intent: short description of purpose and scope.
## Proxy
- intended proxy composite interface path (if applicable).
- Facets: list of facets (symbols/constants) added by the DFPkg.
- Trust boundaries: who may call `processArgs()`, `postDeploy()`, and deployment entrypoints.
- initAccount()/postDeploy(): clear description of initialization and callback lifecycle.
- Runtime invariants & mainnet requirements: immutable/upgradeable expectations, timelock delays, permission model.
- Required tests: concrete tests that must exist (names & brief assertions) to validate behavior.
- Validation status: enum `UNVALIDATED`, `CONFIRMED-WITH-MAINTAINER`, `PENDING-MAINTAINER-REVIEW`, or `REJECTED` and date.

Reviewer Checklist (must be automated where possible)
1. Documentation completeness: confirm all Required Sections exist.
2. Proxy surface match: loupe-driven selector enumeration must match the declared proxy interface(s). Tests: a loupe test that lists selectors and compares to `contracts/interfaces/proxies/*`.
3. Init/postDeploy safety: tests exist proving `initAccount()` sets required storage and `postDeploy()` cannot be executed by arbitrary EOAs to mutate state after lifecycle completes.
4. Deployment pattern: tests exercise the production CREATE3 + Diamond Package Callback Factory path for this package and any child deployments.
5. Access control matrix: generate a map of selectors -> auth (`Permissionless`/`OwnerOnly`/`Operator`/`RegistryOnly`/`InternalOnly`). If ambiguous, raise `MEDIUM`.
6. Critical invariants tests: for vaults/routers/protocols ensure preview<=execute, refund correctness, slippage bounds, and reentrancy guards are covered.
7. Test reproducibility: each required test must include the exact `forge test --match-test` command that runs it.

Finding Output Format (required)
- Component doc path (e.g., `docs/components/IndexedexManagerDFPkg.md`).
- Verdict: `COMPLIES` / `PARTIAL` / `NON-COMPLIANT`.
- Findings: numbered list using PROMPT.md Findings Format (ID, Severity, Category, Title, Evidence, Impact, Recommendation, Verification).
- Reproducer commands: exact forge commands and any minimal setup notes.

Minimal Automated Commands (examples)
- `forge build`
- `forge test --match-contract <ComponentName>Test`
- `forge test --match-test <testFunctionName>`
- Loupe enumeration helper (example): an included test that calls `diamondLoupeFacet.selectors()` and writes to the test output for comparison.

Notes
- Use this template to standardize reviewer output so downstream agents can aggregate findings uniformly.

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW
