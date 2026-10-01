# Astra / Grok Research Council Implementation Plan

**Goal:** Add a project-local, human-led OpenCode research council using Astra and Grok 4.6 without changing existing coding-agent routing.

**Architecture:** An Astra primary moderator coordinates two independent researcher subagents, explicitly pinned to Astra and Grok. The moderator relays attributed findings and resumes researcher sessions for cross-review. This is a bounded, prompt-orchestrated discussion, not an autonomous group-chat service.

**Tech stack:** Installed OpenCode 1.18.31, existing Oh My OpenAgent plugin, Markdown agent/command definitions, existing Context7 and websearch MCP tools.

**Approved design:** The user approved the three-agent design described in this conversation and explicitly authorized Context7 and web research. The council must remain research-only; implementation and deployment are separate tasks.

## Constraints

- Use `openai/gpt-6-astra` for `council` and `council-astra`, and `xai/grok-4.6` for `council-grok`.
- Do not alter global configuration, existing model routing, contracts, or the user's unrelated audit-document edit.
- Default-deny tools, with explicit research allowances. Do not grant shell, source edits, arbitrary delegation, or mutating MCP tools.
- Verify installed plugin behavior before relying on native task permission filtering or session continuation.
- Keep first analyses independent; exchange original attributed findings for one cross-review round; return control to the human.
- Preserve dissent, factual provenance, missing evidence, and failures. Never simulate a missing model's answer or silently substitute a model.
- Use repo `CLAUDE.md` and current family PRDs for domain constraints. Do not treat investment narratives, consensus, or passing tests as proof of economic soundness.
- No commits, package upgrades, or new hosted services.

## Work sequence

### 1. Resolve runtime compatibility

- [x] Inspect installed agent registration and task/resume behavior.
- [x] Confirm exact Context7/websearch tool names and permission semantics.
- [x] Identify a safe runtime diagnostic for resolved agents and models.

### 2. Implement and test the configuration

- [x] Add focused policy/configuration tests first and confirm they fail before council definitions exist.
- [x] Create `.opencode/agents/council.md`, `council-astra.md`, and `council-grok.md`.
- [x] Create `.opencode/commands/council.md`, explicitly selecting the primary moderator.
- [x] Add only the compatibility support demonstrated necessary by installed runtime evidence.
- [x] Add `docs/agent/RESEARCH_COUNCIL.md` with launch, follow-up, safety, failure, and validation instructions.
- [x] Validate parsed definitions, exact models, research allowances, mutation denials, and delegation boundaries.

### 3. Verify and review

- [x] Run focused automated checks and diagnostics on changed executable files, if any.
- [x] Check runtime registration and a minimal live conversation when available; distinguish offline checks from provider-backed results.
- [x] Review correctness, permissions, scope, documentation, and continuity limitations.
- [x] Inspect final diff and report exact usage, evidence, and any unverified behavior.

Implementation evidence: initial `bun test ./.opencode/tests/research-council.test.ts`
ran 130 failing tests before definitions/plugin existed. Focused tests subsequently
passed; the expanded regression suite has 154 passing tests. Strict TypeScript,
LSP diagnostics, the in-memory plugin build, and whitespace checks pass.
Independent reviews identified regression-test gaps, a continuation-schema
compatibility gap, and a skill-path documentation gap; these were addressed.
The correctness reviewer rechecked and accepted the continuation fix and scoped
read-protection guarantee. See `docs/agent/RESEARCH_COUNCIL.md` for live evidence:
both models replied in distinct sessions and resumed for cross-review, Context7
and websearch calls completed, the guard rejected a harmless read probe, and a
normal coding-agent read passed. No production contracts or deployments changed.

## Acceptance scenarios

1. `/council <topic>` selects `council`, not an implementation agent or an unintended child-only command.
2. Both researchers are registered with the exact configured models.
3. Context7 resolution/query and web research are allowed for all three agents.
4. Edit, shell, mutating custom tools, mutating MCP tools, and researcher delegation are denied.
5. Moderator delegation cannot launch an unrestricted coding agent.
6. Researcher continuation preserves identity and context or explicitly reports a continuity failure.
7. Missing input prompts for a topic; follow-up input continues the existing discussion.
8. An unavailable participant is reported as unavailable, not impersonated.
9. A request to implement, save files, sign, or deploy is handed off rather than executed by the council.
10. After independent analyses and one cross-review, the moderator presents disagreements and a human checkpoint rather than looping.
