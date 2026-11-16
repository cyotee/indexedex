# Independent execution notes

Date: 2026-11-11.

Final implementation report, source/artifact bindings, and cleanup were present
before this verification started. HEAD and branch matched the assigned base.
All 101 scoped source, five artifact, and six authority-input SHA-256 bindings
matched actual bytes. No upstream process using this worktree, listener on
18562, or implementation checkpoint root was observed.

The independent replay uses the unchanged CLI, fixed alias, block and port.
Its evidence argument is this verification directory, so the CLI's fixed
`implementation/rehearsal-*` suffix remains within verifier-owned evidence
instead of writing into the producer's evidence. The checkpoint remains the
brief's `.omo-runtime/dtf-migration-wallet-admission/checkpoints`.

This is a local behavior replay, not deployment-gas or full-category acceptance.
Synthetic originals remain synthetic and barred from public execution.
