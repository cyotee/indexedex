# Execution baseline

Date: 2026-11-06. Execution is authorized by the current user request to execute
`docs/research/se-fullspread-remediation-plan-20261106/IMPLEMENTATION_AND_TEST_PLAN.md`.
No commit, deployment, migration, or destructive Git operation is authorized.

## Requirements

The requirements source is FullSpread PRD revision
`fullspread-se-prd-hook-fees-bootstrap-20261106`, including FS-OWN-34 through
FS-OWN-37 and FS-HOOK-05 through FS-HOOK-10. All 24 tasks are tracked in the
session task ledger. The plan's 48-row acceptance and 36-instance migration
ledgers are the initial verification inventory; no row is claimed executed yet.
FS-A12 through FS-A16 are withdrawn, not passing tests.

The root router's historical October 23 FullSpread removal sentence does not
override the explicit request to execute this current plan on the existing
FullSpread implementation. No deprecated implementation will be restored.

## Workspace

HEAD at entry: `2655665c632d2c4fcc7416f48e8ac487e25a2137`.
The checkout is already dirty. All changes present at entry are preserved.
In particular, shared LegLib, all seven family packages, the FullSpread PRD,
implementation and TestBase, shared FullSpread fixture, family matrix rows,
FullSpread regression suites, and audit evidence already contain modifications.
The untracked FullSpread WithV3 and OneSidedFuzz suites are pre-existing.
Existing research, review, draft, and plan directories are not execution edits.

The complete initial `git status --short` receipt is recorded in session
`01a1b2e8-bdd5-77a2-b519-ddeb2a1f8df8`, terminal `bash_1`, exit code 0.
Read-only status and HEAD inspection changed no repository files.

## Toolchain

The default PATH resolves `/opt/homebrew/bin/forge`, version 1.9.0-Homebrew.
It is not the required compiler driver.

The already-installed `$HOME/.foundry/bin/forge` is 1.9.1-nightly, commit
`430523103f3e2f9ba432ffdd2031a9f966153d0d`, built November 3, 2026.
The already-installed `$HOME/.foundry/bin/solar` is
`0.3.0-dev+commit.e7a91fc7`, Solidity 0.8.38.
Execution commands prepend `$HOME/.foundry/bin` to PATH and compile with
`--use solar`; no toolchain installation or project compiler-setting edit is
needed. Use the existing default profile, `out/`, and `cache_forge/`.

## Ownership and validation

The parent owns the baseline, requirements ledger, shared membership changes,
and serialized builds/tests. A read-only inventory worker owns only
`01-surface-map.md` and `01-superseded-tests.md`. Family implementation ownership
will be assigned after the common foundation gate.

No build or test has run at this baseline. Route inventory is static until
explicitly supplemented by deployed-proxy execution receipts. Never treat
test discovery or existing artifact presence as a passing runtime check.
