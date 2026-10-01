# Prompt: resume the APEX remediation program (IndexedEx)

Copy everything below this line into the agent's first message.

---

You are continuing a security remediation program in the IndexedEx monorepo at `/Users/cyotee/Development/projects-defi/daosys/lib/indexedex` (branch `fix/uniswap-se-v2-delivery`, working tree dirty and uncommitted by design). Read these in order before doing anything else:

1. `CLAUDE.md` at the repository root (agent law: Crane first, no SUT mocks, `forge build` before `forge test`, forge patience, no `via_ir`).
2. The audit report: `docs/audits/APEX-IndexedEx-Audit-2026-09-17.pdf` (findings 001-M, 001-M2, 003, 004B, 005, 008, 009 plus two retractions).
3. The remediation PRD: `docs/audits/apex-2026-09-17-remediation-and-regression-tests.md` (requirements R1 to R14, the "why").
4. The implementation plan: `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md`. Its locked decisions (D1 to D60) are binding. Read the section **"Status and handoff (2026-09-23)"** first: it holds the gate table, the per-step status, the ordered list of remaining gaps, how the hook × SE matrix is built, and the commands.
5. The open-items ledger: `docs/audits/apex-2026-09-17-review-open-items.md` (items 1 to 10; item 10 lists production findings F1 to F7 from the matrix).
6. The evidence narrative and ledger: `docs/audits/apex-2026-09-17-evidence.md`, `docs/audits/apex-2026-09-17-evidence/acceptance.json` (108 criteria: 43 EVIDENCED, 64 REPORTED, 1 PARTIAL), `hook-se-matrix.json`, `hook-se-matrix-findings.json`, `hook-se-matrix-finding-descriptions.json`, and the run logs under `docs/audits/apex-2026-09-17-evidence/review-20260921/`.
7. The per-item PRDs next to the plan: `apex-2026-09-17-open-item-1-hook-se-matrix-PRD.md`, `...-open-item-4-legacy-join-facets-removal-PRD.md`, `...-open-item-5-buffer-hook-staticcall-exception-PRD.md` (both executed), and `...-open-item-3-etherfi-interface-research-PRD.md` (parked by the owner; do not start it unless asked).

State when you start (2026-09-23): every production correction in the plan is implemented, D60 work packages 1 to 5 are executed on all seven hooks, full hermetic `forge test -vv` run 16 is green (3,003 suites, 33,986 tests), the hook × SE matrix has 175 rows (147 base plus 28 M14 decimal rows) and 1,235 green tests (114 COMPATIBLE, 1 BLOCKED on F8, 11 INCOMPATIBLE on named production checks, 7 DEPRECATED under D57, 42 DEFERRED under M13), R12 is 565 compared / 0 missing / 0 oversize with every diff classified, and `acceptance.json` reads 91 EVIDENCED, 17 PARTIAL, 0 REPORTED. What is left for the owner: rulings on the remaining INCOMPATIBLE groups (FullSpread exact-out mint, above-18-decimal SE shares on the quad packages), findings F8 (Aave loop borrow headroom after a partial unwind) and F9 (ERC-4626 SE sequential projection rounding, a few wei), the rated first-mint / `kLast` interpretation on the CP hooks, and the 17 PARTIAL criteria each named in `acceptance.json` (three of them, R4.2 / R4.3 / R4.5, need a fork session). The plan's "Remaining gaps" subsection records each item's state.

Your task is to work through those gaps in that order, one at a time, treating each as its own PRD the way items 1, 4 and 5 were done:

1. Findings F1 to F7 need the owner's ruling before code changes. Present each finding with its site, the rule it violates, the fix you propose and its blast radius, then wait for the decision. F1, F2, F3 and F7 look like defects against D15, R14.6, D30 and preview/execute agreement; F4, F5 and F6 need a product decision. After a fix, restore the row assertion that was pinned to the finding (the `test_row_*` override in the affected row file, or for F1 the orbital `_SeMatrixBehavior.sol` itself), re-run the matrix, update the two findings JSON files and regenerate `hook-se-matrix.json` with `scripts/hook_se_matrix_evidence.py`.
2. The 17 INCOMPATIBLE rows each assert a named production check; ask the owner whether the check or the package changes before touching either.
3. Re-evidence the 64 REPORTED acceptance criteria to named passing tests and logs; flip each to EVIDENCED only with that proof. Historical fork evidence (R4) runs under `FOUNDRY_PROFILE=fork` with the `robinhood_mainnet_alchemy` alias; never write an RPC key into any file.
4. Write the M14 decimal-combination matrix rows and record per-leg SE addresses per row.
5. Then items 9 and 6 of the open-items ledger.

Standing rules that do not change: no `git commit`, `reset`, `push` or Crane pointer bump (staging is allowed; the owner commits); no `via_ir`; never kill `forge` or `solc` for lack of output (cold compiles take 20 to 40 minutes); never run two `forge` processes that write `out/` at once; do not delete `out/` or `cache_forge/`; no mocks of the SUT (vaults, SEs, hooks, packages, registry, fee oracle); do not edit the preserved `contracts/protocols/dexes/uniswap/{v3,v4}/` trees or Crane implementation; every production fix needs a red test before and a green test after, recorded in the evidence; a finding you cannot resolve is reported, not patched around. Keep the plan's "Status and handoff" section, the open-items ledger and the evidence file current as you go, so the next agent can resume from them the same way you did.

Start by reading the seven references above, then report a short plan for gap 1 before making any change.
