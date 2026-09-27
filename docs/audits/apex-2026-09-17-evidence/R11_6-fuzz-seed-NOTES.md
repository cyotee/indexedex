# APEX 2026-09-17 R11.6 — pinned fuzz/invariant seed

- Pinned seed: `0x4150455832303236` (ASCII "APEX2026"), exported as `FOUNDRY_FUZZ_SEED` by
  `scripts/apex_fuzz_seed.sh`. Default `forge test` stays UNSEEDED (rotating) so hermetic runs
  keep exploring; the seed is pinned only at this script's invocation, never in `foundry.toml`.
- The script (forge 1.5.1 rejects repeated `--match-path`) runs one match-path glob per
  invocation, under the same seed:
  - `test/foundry/spec/hooks/uniswap/v4/standardExchange/**/invariant/*_Invariant.t.sol` (7 suites)
  - `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/invariants/*_Invariant.t.sol` (2 suites)
- Counterexample retention: on any failure the gitignored `cache/fuzz/` and `cache/invariant/`
  replay trees are rsynced into `fuzz-counterexamples/`. All suites currently pass under the
  pinned seed, so there are no counterexamples to retain.
- Reproducibility spot-check (this file's authoring run), seed `0x4150455832303236`:
  `UniswapV4SingleSEBufferHook_Invariant::invariant_inSucceeded()` PASS (runs: 256,
  calls: 16384, reverts: 0).
