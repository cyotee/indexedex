# Robinhood mainnet source verification

## Existing credential and scope

**The owner has already configured `BLOCKSCOUT_API_KEY` in the inherited environment.** Confirmed on 2026-09-14. Use that variable; do not ask the owner to create, export, paste, or rename it again merely because it is absent from the repo's `.env`. Check presence without displaying the value in each new process. If the environment is not inherited in a future session, check the documented local secrets source before reporting that limitation.

Follow the shared [Forge source-verification procedure](../../../../lib/crane/.claude/skills/forge-deployment/references/source-verification.md) for safe credential handling, authenticated requests and completion criteria. This applies to Claude, Codex, Grok Build and OpenCode. Do not expose the key in shell arguments, traces, CLI help, logs or reports.

| Setting | Robinhood mainnet |
| --- | --- |
| Chain | `4663` |
| Foundry RPC alias | `robinhood_mainnet` |
| Explorer | `https://robinhoodchain.blockscout.com` |
| Authenticated compatibility API | `https://api.blockscout.com/v2/api?chain_id=4663` |
| Blockscout credential | Existing `BLOCKSCOUT_API_KEY`; pass as Bearer header for HTTP or through child-process verifier environment for compatible Forge versions |
| Sourcify | `forge verify-contract --verifier sourcify`; no Blockscout key required |

Source verification publishes the source of already deployed contracts. It does not authorize deployments, migrations, wallet signing, chain transactions or API payments.

## Inventory and original artifacts

Reuse `scripts/shell/lib/rh_4663_verify_inventory.py` for contract/source discovery. Inspect `scripts/shell/verify_robinhood_main.sh` before use: its legacy no-key guidance does not describe the authenticated PRO gateway, and its default broadcast scope is not the fee-accrual migration scope. Do not run it blindly or print commands containing credentials.

For the staking migration, include successful creations in both current and archived files under:

```text
deployments/robinhood_main_fee_accrual/*/broadcast/*/4663/run-*.json
```

Include factory `additionalContracts`, linked libraries, facets, packages, proxies and the constructor-deployed migration adapter. Deduplicate addresses and skip transient CREATE3 proxies. Reused core infrastructure is outside this inventory unless explicitly requested.

Use exact creation bytecode/constructor arguments and source hashes from the matching original artifact. The migration used Solidity `0.8.35+commit.47b9dedd`, optimizer enabled with 1 run, EVM Prague, no viaIR; verify those against each artifact rather than assuming future deployments use the same settings. No need to restart Anvil or rerun deployment scripts.

## Verified outcome and service limitations (2026-09-14)

Evidence: `deployments/robinhood_main_fee_accrual/verification/README.md` and `verification-status.json`, relative to repository root.

- Sourcify: 58 exact creation and runtime matches. Preserve this completed work; do not resubmit it unnecessarily.
- Blockscout: 9 partial proxy verifications and 2 unverified proxies displaying a verified twin's source. Source availability alone is not full verification.
- `BLOCKSCOUT_API_KEY` successfully authenticated PRO reads. Forge 1.5.1 submissions still failed authentication with either `VERIFIER_API_KEY` or `ETHERSCAN_API_KEY`; setting an environment option did not prove that this provider forwarded it.
- Explicitly authenticated standard JSON and Sourcify-file uploads returned internal-server errors. The cause was not established. The saved attempts did not capture HTTP status/rate-limit headers, and request-format or routing mistakes were not ruled out. These error bodies do not prove throttling, a service outage, or a missing key. Direct explorer API requests encountered a Cloudflare challenge.

These are dated observations, not permanent API behavior. On resumption, check pending contract statuses and retry the documented authenticated upload route. Poll returned job IDs/GUIDs and independently confirm source status; report pending/service errors honestly. Do not ask for replacement credentials when authenticated reads work, disable authentication, bypass challenges, or pay x402 to work around an upload failure.

For secure runnable HTTP/Forge patterns, standard JSON fields and official source links, use the shared procedure linked above.
