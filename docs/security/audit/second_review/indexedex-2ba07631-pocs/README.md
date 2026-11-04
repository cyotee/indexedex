# IndexedEx diff review PoCs (aca16198 → 2ba07631)

CONFIDENTIAL. These are Foundry PoCs for findings APEX-2026-010 … 054. Each group directory under `test/apex_audit/` has a `RESULT.md`.

To use them:
1. Check out `2ba07631` with submodules.
2. Extract this archive at the repo root.
3. Add the `[profile.audit]` block from Appendix B of the report to `foundry.toml`.
4. Run: `FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/<group>/<File>.t.sol -vvv`

The write-up for each finding names its test file. Live-fork tests fork `https://rpc.mainnet.chain.robinhood.com` and never broadcast. `prior/` contains the earlier APEX-2026-001…009 PoCs that were re-run at HEAD. `dz-*` directories are replays of deep-fuzz breaks that turned out to be harness false positives; they are kept as evidence.
