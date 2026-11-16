# Operator host-dependency inventory

Read-only snapshot of the runtime-accepted ED candidate while its commit audit runs. Literal path search and code inspection found14 absolute source inputs in rehearsal-data.ts and a hardcoded Foundry executable directory in rehearsal-process.ts. The JSON inventory records every ID, current actual raw byte length/SHA-256 and code line.

sourceFile resolves its supplied path and directly reads it; bootstrapManifest requires these entries through Promise.all. They include5 root execution-authority documents,2 current main product documents and7 retained-worktree inputs, including the phase15 source archive and phase17/18/19 source contracts/admissions. Relative out ABI files and per-run acquisition/environment inputs are separate runtime-generated dependencies, not included in that14. The launcher joins its hardcoded Foundry directory with anvil; changing the working directory does not remove that host dependency.

This makes the already disclosed portability limit concrete. Do not delete the referenced worktrees/documents just because their source commits are accepted. A future portable bundle must preserve the actual authority/source bytes and deliberately bind their new locations and consumers; do not substitute stale worktree plan/PRD copies or assume path changes preserve existing preparation/domain identities. Executable discovery also needs an explicit portable contract. No such code change or policy is selected by this inventory.

No source/input relocation, edit, permission change, build, test, RPC, Git write or runtime was performed. Full portable/full-F3 acceptance remains open.
