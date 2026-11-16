# Prepared-range census A1

The frozen combined QA reports 305 tests and both strict typechecks passing.
A1 remains a source/fact advisory, so a new failing regression is required.

The root candidate is the full-range suffix filter in verifyConfiguration,
called by public verify and activate before planning/sending. The configure
completion branch is receipt-local and is not implicated. execution-state
already imports execution-domain; domain imports state only inside
authenticateHistory. A shared classifier export from domain adds no new
module dependency edge.

The regression will first authenticate the saved actual initialization receipt,
then replay its exact ThresholdsConfigured topics/data inside a separately
created synthetic deployment/preparation context. The synthetic log's emitter,
block, transaction and index are explicitly fixture metadata, not claimed real
historical facts. Original archived manifests/domains/receipts stay untouched.
The new preparation is loaded through the production source-bound loader.
The public verify and simulate-mode activation paths are the test boundary.

The existing fixtures lack mandatory deployment initialization in their
prepared-range queries. A suffix classifier therefore passes those old tests.
The new positive must fail on A1, while independent missing-origin/category,
canonical receipt/header, exact-input and duplicate-preparation probes must
reject after the classifier is fixed. No new test-only production seam is needed.

Only the four authorized modules and this evidence directory may change.
No full file restoration, transaction-local decoder change, pricing/history
rebinding, cutoff change, public RPC, Anvil, Forge, installation or commit.

Attempt 01 reproduced A1 in both public verify and activate (10 pass, 2 fail),
at the exact prepared-range omission error. Attempt 02 passed those same paths.
Attempt 03 passed 41 focused tests after adding ten-category omission probes at
deployment and later blocks plus receipt/header, malformed range, exact input,
missing issuance history, duplicate-original and stale-preparation negatives.

Temporary sensitivity probes will remove the represented-origin rejection,
move the range start past deployment, and bypass canonical receipt acquisition,
one at a time. Only the owned range code is mutated, and each mutation is
restored before the final focused/manual and combined checks.
