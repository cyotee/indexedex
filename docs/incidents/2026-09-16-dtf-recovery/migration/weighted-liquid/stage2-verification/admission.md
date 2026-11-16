# Independent verification admission

The root confirmed the producer completed, stopped modifications, and left no
owned runtime. This verifier did not start runtime replay before that handoff.

Producer seal timestamp: 2026-11-11T20:13:50.953Z.
Worktree HEAD: 2c2b3370ded30cae1662329025d4fb58f7197330.
Branch: work/dtf-migration-phase-13-weighted-liquid.

Independent raw SHA-256 validation matched all 1,096 manifest entries:
4 authority inputs, 8 historical inputs, 39 candidate source/test/operator
files, 9 production artifacts, 16 test artifacts, and 1,020 evidence files.
No mismatches or unreadable entries were found.

Read-only status retained the producer's uncommitted delta. Whitespace checking
reported no errors. Port 18563 had no listener and the fixed checkpoint directory
was absent. No producer source, historical evidence, configuration, dependency,
or held phase09 work was changed.

The admitted candidate explicitly retains D1, MissingRewardWeight() on an
ordinary deposit after activation without any funded participant. Neither a
clean-suite claim nor a pre-existing-defect attribution is accepted. The
owner's genesis-weight question remains pending; this verifier implements
no weight seed.
