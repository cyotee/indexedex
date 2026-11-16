# Phase33 retained attempts and diagnostic limits

- An initial layout probe attempted the absent primary-checkout
  docs/incidents/2026-09-16-dtf-recovery/migration directory and returned ENOENT.
  The actual current documents and accepted worktree archive paths were then
  read. No file or network effect occurred.
- Some tool-rendered large reads were truncated/elided. Full read-helper bodies
  were subsequently parsed before interpretation/authentication; rendered
  excerpts were not hash or schema oracles.
- validate-01 through validate-04 passed syntax. validate-05 exited 1 because
  the joined-recipient review manifest uses entries rather than files. Its
  complete stderr, stdout, actual argv, source hashes, PID, start/close and exit
  are retained in validate-05.*. The fix selected that actual manifest schema.
  No accepted artifact was changed.
- validate-r2-01 through validate-r2-05 all exited 0. The sole subsequent live
  collector exited 0; no receipt, provider or refused operation was retried.
- reconcile-01, prove-01, validate-final-01 through validate-final-09 and
  prove-final-01 all exited 0. The strengthened final proof rechecks original
  mint/purchase terms, actual source bodies, unknowns and comparison fields
  without rewriting the original proof.
- Fresh LSP diagnostics reported timeouts for inputs.mjs and record.mjs.
  Neither is represented as a passing diagnostic. Actual Node syntax and Bun
  behavior/proof execution passed. No installation or LSP configuration change
  was attempted.
- All actual RPC failures are explicitly retained in archive.json/failures and
  http-manifest.json; in this acquisition that failure list is empty.
- Every output is new under this source directory. No old evidence, frozen
  input, production, phase32 output or shared source was changed.
