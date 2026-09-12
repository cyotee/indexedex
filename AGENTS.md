# IndexedEx agent instructions

Before working in this repository, read and follow [CLAUDE.md](CLAUDE.md).
It is the shared, maintained router for repo rules, canonical skills, product
law, codebase navigation, and task-specific documents. Load the referenced
skills and documents when the task calls for them.

Before code changes, also read [.github/ASSISTANT_RULES.md](.github/ASSISTANT_RULES.md)
and its coding, deployment, and testing documents. Use the current paths and
deployment/test workflows in `CLAUDE.md` when older examples differ.

Codex discovers shared skills through `.agents/skills/`. These are relative
symlinks to canonical skill folders; edit the source, not a separate Codex copy.
Run `python3 scripts/sync-codex-skills.py` after adding installed repo skills,
or use `--check` to verify the links without changing files.

For specialized work, the existing role instructions are available under
`.claude/agents/` (`detf-implementer`, `detf-adversarial`, `crane-porter`, and
`docs-skill-scribe`). Read a relevant role when needed; these files do not
automatically register Codex subagents or require delegation.
