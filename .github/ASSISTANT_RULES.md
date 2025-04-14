# Assistant Rules (canonical)

These files contain the canonical, repo-level directives that assistants and automation should follow when making code changes, running tests, or preparing deployments.

Scope & intent
- Files under `.github/` are authoritative for assistant behaviour. Read these at the start of any change session.
- If a rule conflicts with an explicit instruction from a repository owner/maintainer in an opened issue or PR, ask for clarification before proceeding.

Files (topic-scoped)
- `.github/ASSISTANT_DEPLOYMENT.md` — Deployment & packaging rules (CREATE3, Diamond Factory Packages, no `new` in production).
- `.github/ASSISTANT_CODING.md` — Coding & file layout rules (reuse canonical files, naming, approvals).
- `.github/ASSISTANT_TESTS.md` — Testing & CI rules (forge commands, required policy tests).

Enforcement
- Where feasible add small unit tests that assert critical project policies (for example token metadata, or that certain patterns are not present).
- If a requested edit would violate one of these rules, stop and ask for explicit approval before making the change.

How to use
- Start every task by reading these files.
- When proposing changes that affect policy (naming, packaging, or deployment), include a one-line reference to the relevant rule file in the commit message.

Maintainers may update these files by pull request; assistants must follow the latest committed version in the repo.
