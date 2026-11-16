# Retained producer attempts and tool limits

These are summaries of session tool events, not original wire or compiler bytes.
All recorded command stdout/stderr remain separate files.

Before any live RPC:

1. A proposed read-only parallel archive-reading child was refused by the
   harness nesting limit. No child started. The producer read the archives
   itself; no independent verification is claimed.
2. A source-inspection eval referenced an undefined `LOUPE` local after
   printing worksheet flow keys. No file or RPC changed.
3. Initial offline intake tried JSON parsing a seal-bound Markdown report
   and failed with `JSON Parse error: Unrecognized token '#'`. Intake now
   authenticates every binding but parses JSON only for JSON bodies.
4. The next intake attempted a current-plan path in the cumulative worktree
   and received ENOENT. That ignored authority file is in the primary checkout.
   Current plan and PRD are read and bound there; cumulative source is bound
   in the specified worktree. No plan was invented or copied.
5. Corrected offline intake authenticated 36 declarations / 28 bodies,
   116 evidence/source bindings and all 59 individual purchase/mint/worksheet
   joins, including exactly one recipient-flow row per purchase.
6. The first recorded validation ran six Node syntax checks and the complete
   offline intake, all with exit 0. Fresh LSP diagnostics then reported one
   unused `keccak256` import in `evidence.mjs`; it was removed.
   `record.mjs` gained a safe command label so later validations preserve
   the first records, and the seal's expected command inventory was updated.
   The final validation is separately retained as `validate-final-*`.

Some large tool-rendered archive reads were elided. Complete raw-file reads
and JSON parsing were used for the actual archive, ABI/source, table and
worksheet inspection and authentication; displayed excerpts were not the
input to RPC construction.

The LSP returned clean diagnostics for `rpc.mjs`, `record.mjs`, `prove.mjs`
and `seal.mjs` in the explicit diagnostic wave. Fresh diagnostics timed out
for `observe.mjs`; patch-time diagnostics also timed out for some later
edits. These are unavailable fresh diagnostic results, not passing checks.
Actual recorded syntax validation and the executed observer/raw proof are
the owned-script checks. No dependency/configuration workaround or old suite,
Forge, collector replay, phase29 retry or provider substitution was used.
