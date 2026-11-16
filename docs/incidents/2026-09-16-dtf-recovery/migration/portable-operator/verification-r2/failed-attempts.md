# Verifier-only retained attempts

- The first gate-monitor construction failed in the eval kernel with `PIPESTATUS is not defined` before spawning any command. The corrected monitor used shell pipefail. The actual operator/types/artifact/stage gate then ran once and completed with exit 0.
- The physical-access support import was corrected before execution from seven parent segments to six. No candidate source or runtime was changed.
- The first extra-negative recorder handled the expected conflicting-reference failure, then incorrectly required a `message` field on the expected unsafe-path `INPUT` response, which instead carries `issues`. Its own Zod parse failed. Both actual rejection logs and fixtures remain under `extra-negatives/`.
- The owned recorder was corrected to parse both actual error variants and used a new exclusive `extra-negatives-r2/` root. Its strict types and all three real CLI rejections completed. No operator test or cumulative runtime was repeated for this support-only correction.
- Some editor diagnostic requests timed out; Biome and the shell language server are absent. Nothing was installed. Completed strict types, JSON parsing, shell syntax and actual commands supply the stated checks.

The producer's earlier failed candidates and original missing-handoff verification remain immutable and distinct. No failure was suppressed, relabeled or edited away.
