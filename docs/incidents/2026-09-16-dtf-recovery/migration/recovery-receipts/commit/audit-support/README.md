# Immutable audit proof procedure

All outputs here are new audit-owned evidence. Original `../support/` inventories remain the expected baseline; none was overwritten. Audit source is the completed local commit, not a candidate staging tree.

The six evidence/input inventory families and raw-ref family are JSON Lines, partitioned at 1,500 original rows, preserving original order. Each row retains `path`, the complete original `expected` row, observed `actual` values for its original fields, and `differences`. Missing original loose ref files have `actual.present=false`, not invented raw bytes or modes.

Resolve owned-evidence paths relative to the subject worktree. Resolve `phase27-frozen-input-recovery/...` relative to `/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration`. Resolve `.git/...` relative to `/Users/cyotee/Projects/indexedex`. Absolute artifact/link/scope paths retain their original locations.

Use lstat without following symlinks. Hash regular files as complete raw bytes with SHA-256. For a symlink, readlink and hash the UTF-8 target string; do not traverse its target. Record full mode and octal permission independently of Git's collapsed regular-file mode. For original directories, record actual size, nlink and child count. Sort child names by UTF-8 bytes and hash each followed by a newline. Compare every original field, except derived explanatory flags; expected/actual content hashes also authenticate small ref-file text.

The audit evaluated original rows directly, caching repeated identities within that observation pass; the same file's permission/content rows share the same observed identity. These are actual fresh observations against original baselines, not new baseline rows used as substitutes. The qualified differences are additive root directory bookkeeping, expected own-index commit change, and previously recorded ref packing. Every difference is retained.

Read-only Git command records carry exact arguments, exit code and full stdout/stderr. The common environment was GIT_MASTER=1, GIT_OPTIONAL_LOCKS=0, GIT_PAGER=cat and PAGER=cat, and every command used git --no-pager -C with the subject root. Source blobs were read through cat-file, index modes through ls-files --stage, and committed modes through ls-tree. SHA-256 and byte lengths were checked against both frozen manifests and accepted bindings; whitespace checked the whole immutable parent-to-HEAD diff.

Runtime authentication reads the original complete commands and streams, manifests, seals, proofs, HTTP manifests and saved entities. It does not import or execute the collector, test suite, compiler, oracle, secret scanner or provider bootstrap. Each retained request/response is length/hash/envelope checked; complete proof reviews are compared with saved reconciliation. This authenticates completed execution evidence without creating a new live gate.

The final seal is written after the report, support validation and final stopped boundary. It binds all audit artifacts except itself. Its report binding is not a self-referential report hash. Nothing outside `commit/verification.md` and this new directory was written by this audit.
