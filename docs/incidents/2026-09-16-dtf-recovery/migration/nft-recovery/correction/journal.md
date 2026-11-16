# R1 correction evidence journal

Scope: existing uncommitted recovery delta above
`6e7d8b8dc2cda313c7fb19ec051bfb84612f5f31`, in this worktree only.
Prior reports, witnesses and logs remain immutable.

The independent traces show W2 rejecting against the original native claim
inventory before calling the source, although actual attributed gons retain
whole redeemable units. The new regression will require positive W2 conversion
after the terminal NFT burns and its original claim amount has been spent.
It uses the existing real registry/pinned legacy fixture without SUT mutation.

Intended correction: reconcile native representation from tracked recovery
gons at the index synchronized by the admitted source operation, distinct from
new claim receipts. Retain actual gon debit, unbooked floor, measured outputs,
fixed destination and whole-selected-batch rollback. No new route or authority.

Owned artifacts: this journal, the new accrual fork regression, narrowly
necessary recovery accounting/interface edits, correction logs/bindings and
the final report. No node or port is required; Forge forks are in-process.
Warm `out/` and `cache_forge/` remain in place. No commits or public operations.

Initial inspection: HEAD matches. Plain Git status failed on the existing
Crane symlink; `--ignore-submodules=all` succeeded. An ancillary `find -exec`
listing failed; canonical skill paths were resolved without changing links.
No compiler has been started at this point.

Completed: fail-before exit 1 on the expected R1 error; unchanged regression
passing-after exit 0; current full forks 39/39 and specs 96/96, both exit 0;
setup-inclusive terminal trace exit 0. Full commands and outputs are bound in
evidence.json and the five local logs. All runs have ended.

Final source/artifact binding checks pass, prior evidence is unchanged, and
cleanup found only shared Forge LSP PID 16569. No owned runtime remains.
The report is ready for the separate independent verifier; no broader gate
or public operation is authorized.
