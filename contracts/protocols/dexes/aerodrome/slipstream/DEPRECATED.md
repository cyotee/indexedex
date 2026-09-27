# Slipstream Standard Exchange: deprecated

Owner ruling 2026-09-21, recorded as APEX decision D57 in `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md`.

The Slipstream SE supports token-to-token swaps and single-token deposits into shares, but has no share-to-token route, so every buffer hook fails its first unwrap with `ExchangeInNotAvailable`. Adding the route would amount to a rewrite. The package is not wired into any launch script or vault registry path. Its seven hook-matrix rows are `DEPRECATED`. Sources and tests stay compiling only until a separate deletion request.
