# Full-repository hermetic execution

Base:8db3f5ee6310e8a700dad2d6a33e21d0955e63ca, qualified current immutable delivery. P1 remains2missing historical rawJSON versions; no all-history preservation claim. This separate worktree preserves phase24 out/cache/evidence.

The runner matches actual CI: default full spec build, all runtime artifacts, then full hermetic tests with declared network/fork exclusions. It uses a minimal subprocess environment with installed tool paths, HOME/USER/TMPDIR/locale, default profile and empty provider-key variables; no RPC override or signing credentials are forwarded. No .env is admitted. Parent session environment is unchanged.

Repository default fuzz/invariant settings apply for CI equivalence. The stronger32x16 Migration stateful proof remains separately accepted. Permissive hermetic gas_limit is not target-chain acceptance. No fork gate, old CLI/resume, public action, install, new profile, source fix or held09 work is included.

run-gate.sh records individual actual command and capture exit statuses and stops at the first failure. Raw logs retain all warnings/failures. No pass or failure classification is assigned until actual results are read. No new source commit is requested for evidence-only work.
