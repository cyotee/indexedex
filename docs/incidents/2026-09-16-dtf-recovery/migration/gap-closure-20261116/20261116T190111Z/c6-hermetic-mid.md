# Hermetic suite, mid-run

The non-fork suite is still running. Do not kill it.

One suite has failed so far: ArtifactCreationCode_Test, 12 passed and 1 failed. The failing test is test_fullSourceIdentifier. It compares two lookups of FeeCollectorManagerFacet creation code. The mismatch is bytecode identity, not a migration assertion. Treat the final HERMETIC_EXIT as authoritative; do not repair artifacts while this forge process owns out/.
