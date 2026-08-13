# IndexedEx security audit program

Stage 1 review (reports only) that uses the installed audit / adversarial / CROPS / sharp-edges / spec-compliance / incident skills, then hands a work-package backlog to a Stage 2 agent that writes a **parallel remediation PRD**.

| Document | Role |
|----------|------|
| [`SECURITY_AUDIT_PRD.md`](./SECURITY_AUDIT_PRD.md) | Process law (Stage 1). Finding + WP schemas. Locks **L-SEC-1…14**. Handoff to Stage 2/3. |
| [`SECURITY_AUDIT_EXECUTE_PLAN.md`](./SECURITY_AUDIT_EXECUTE_PLAN.md) | Orchestrator checklist, pilot/full partitions, subagent prompts, QA. |
| [`PROMPT_SECURITY_AUDIT_REMEDIATION_PRD.md`](./PROMPT_SECURITY_AUDIT_REMEDIATION_PRD.md) | **After** Stage 1 is accepted: prompt for the agent that writes the remediation PRD. |
| `audit/` | Stage 1 outputs (`AGGREGATE.md`, `WORK_PACKAGE_BACKLOG.md`, areas, specialists, repro). Created by the orchestrator. |

**Not this program:** test-coverage completeness lives under [`docs/testing/TEST_COVERAGE_AUDIT_PRD.md`](../testing/TEST_COVERAGE_AUDIT_PRD.md) (`TCA-*`, `gap_cover_*`). Security audit findings that share a touch-set are **OWNED_ELSEWHERE** — do not open a second `sec_fix_*` tree on those files.
