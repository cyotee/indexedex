# Assistant Coding Rules

These rules guide code layout, reuse, naming, and the assistant's edit behavior.

Repository-first policy
- Always prefer to reuse existing canonical files listed in the PRD and repository (e.g., `BalancerV38020WeightedPoolMath.sol`, `StandardExchangeDETFStorage.sol`) before creating new files.
- If a missing helper is required, add it to the closest existing file rather than creating a new helper library unless approved.

Edit etiquette
- Make smallest possible changes to satisfy the request. Avoid unrelated reformatting.
- When changing public interfaces, update tests and add migration notes in a single commit.

Naming & conventions
- Follow existing naming patterns for facets, packages, and storage helpers.
- Facet and package names should include `DETF` or `StandardExchange` where appropriate per PRD.

Deployment helper rules
- Do not introduce `new` contract instantiation in production code; use factory/package patterns.

Review & approval
- Propose changes via a branch and PR when modifying public APIs or adding new packages. Include tests demonstrating behavior.
