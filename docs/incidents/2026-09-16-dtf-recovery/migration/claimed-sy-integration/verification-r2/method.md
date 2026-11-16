# Independent verification r2

Started 2026-11-12 against the stopped producer candidate at audited base
`4eaa7decab80d24cf37cb3781eff5ffaf9362942`.

The producer's 1465 evidence-member hashes and 64 source/preservation bindings
were independently checked before runtime: all matched. Port 18573 had no
listener, the live claimed-SY checkpoint was absent, and no producer CLI,
observer or Anvil process matched the owned lane.

Only this directory is verifier-owned. Implementation, source22, earlier
verification and original producer evidence remain immutable. New execution
uses the existing candidate, with fresh local runtime and signatures, not
replayed producer receipts. Historical eligibility remains reviewed synthetic
fixture data, never inferred from signatures or review flags.

The amended direct-EOA receiver resolution controls. Ordinary-SY contract
receiver/reentry tests are shared-path coverage, not claimed-origin callback
witnesses.
