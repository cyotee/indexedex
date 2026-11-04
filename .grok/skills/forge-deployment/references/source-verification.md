# Post-deployment source verification

Verify existing deployed bytecode using its original build and creation evidence. This task does not require a signing key, a deployment, or an onchain transaction. Source publication is distinct from a security audit.

Contents: [Credentials](#credential-preflight) · [Inventory](#inventory-and-build-identity) · [Sourcify](#sourcify) · [Blockscout authentication](#blockscout-pro-authentication) · [Standard JSON](#standard-json-fallback) · [Evidence](#completion-evidence) · [Sources](#official-references)

## Credential preflight

1. Read the consumer repository's verification instructions. They may specify an already-configured credential name (IndexedEx uses `BLOCKSCOUT_API_KEY`).
2. Check the **inherited process environment first**, before project-local secrets files. An absent entry in `.env` does not imply an absent credential. Print presence only:

   ```python
   import os
   print("BLOCKSCOUT_API_KEY is set" if os.environ.get("BLOCKSCOUT_API_KEY")
         else "BLOCKSCOUT_API_KEY is not present in this process")
   ```

3. Use the existing credential without asking the user to configure it again. If absent from this process, check the documented local secrets source without printing its contents; only then ask about availability. Do not silently overwrite an inherited key by loading `.env`.
4. Never print keys, dump the environment, use shell tracing, place keys in command arguments, or save them in verification reports. Some CLI help and error output includes environment values or request payloads: capture and redact before displaying. Never ask the user to paste a key into chat.

## Inventory and build identity

- Scope the inventory to the requested deployment. Include archived successful broadcasts, factory-created contracts, facets, packages, libraries and persistent proxies. Deduplicate addresses; exclude ephemeral CREATE3 proxies and reused infrastructure unless requested.
- Confirm successful creation receipts, creation transaction hashes, deployed code, constructor suffixes and link-reference addresses. Reuse the repository's inventory helper where available.
- Match original compiler version, optimizer, EVM version, metadata, source paths and source hashes. Preserve original artifacts; do not rebuild changed source and present it as the deployment's source.
- For dynamically linked deployments, recover actual link addresses from creation bytecode. Do not blindly change metadata library settings: Sourcify can recognize link substitutions while retaining exact metadata.

## Sourcify

Use the repository's RPC alias and values from the matched artifact/broadcast:

```bash
forge verify-contract "$VERIFY_ADDRESS" "$VERIFY_CONTRACT" \
  --chain "$VERIFY_CHAIN_ID" --rpc-url "$VERIFY_RPC_ALIAS" \
  --verifier sourcify --compiler-version "$VERIFY_COMPILER" \
  --num-of-optimizations "$VERIFY_OPTIMIZER_RUNS" \
  --creation-transaction-hash "$VERIFY_CREATION_TX" \
  --constructor-args "$VERIFY_CONSTRUCTOR_ARGS" --watch
```

Omit constructor arguments when empty. A queued job is not a successful verification. Check `https://sourcify.dev/server/v2/contract/<chain_id>/<address>`; record `creationMatch`, `runtimeMatch`, and `verifiedAt`. Claim exact verification only when both matches are `exact_match`.

## Blockscout PRO authentication

Read the configured `BLOCKSCOUT_API_KEY` into the **child process environment** for Forge's custom-verifier credential. Do not interpolate its value into a command string:

```python
import os, subprocess
key = os.environ["BLOCKSCOUT_API_KEY"]
child_env = os.environ.copy()
child_env["VERIFIER_API_KEY"] = key
# verify_args contains only public address/build/constructor arguments.
result = subprocess.run(verify_args, env=child_env, capture_output=True, text=True)
# Redact before persisting any output; avoid printing full compiler payloads.
output = (result.stdout + result.stderr).replace(key, "[REDACTED]")
```

Use `forge verify-contract`, `--verifier blockscout`, and the currently documented `--verifier-url`. The PRO compatibility endpoint is `https://api.blockscout.com/v2/api?chain_id=<chain_id>`. Check installed Forge behavior: a supported environment option does not prove that the provider transmitted authentication. The IndexedEx 2026-09-14 run with Forge 1.5.1 failed submission authentication despite `VERIFIER_API_KEY` and `ETHERSCAN_API_KEY`; do not repeat that indefinitely or infer the key is missing.

For authenticated API access, send `Authorization: Bearer <key>` to `https://api.blockscout.com`. Keep the header in stdin, not curl arguments. Example for a source-status read (public `url` contains chain and address):

```python
import json, os, subprocess
key = os.environ["BLOCKSCOUT_API_KEY"]
config = (
    "url = " + json.dumps(url) + "\n"
    + "header = " + json.dumps("Authorization: Bearer " + key) + "\n"
    + 'header = "Accept: application/json"\n'
    + 'user-agent = "indexedex-verification/1.0"\n'
)
result = subprocess.run(
    ["curl", "--silent", "--show-error", "--max-time", "45", "--config", "-"],
    input=config, capture_output=True, text=True,
)
response = json.loads(result.stdout)
# Print only selected status fields, never config or request headers.
```

Use a descriptive User-Agent and JSON Accept header. Python's default urllib client may receive a CDN rejection even when curl with the same credential succeeds. Distinguish CDN challenges from API authentication errors. Do not bypass a challenge or make x402 payments as a verification workaround.

## Standard JSON fallback

If Forge does not transmit the credential correctly, use its standard JSON output with the documented authenticated API. This is source submission, not deployment:

```bash
forge verify-contract "$VERIFY_ADDRESS" "$VERIFY_CONTRACT" \
  --chain "$VERIFY_CHAIN_ID" --compiler-version "$VERIFY_COMPILER" \
  --num-of-optimizations "$VERIFY_OPTIMIZER_RUNS" \
  --show-standard-json-input > verification-standard.json
```

Validate that the output is JSON with the expected source hashes and build settings. POST to `https://api.blockscout.com/v2/api?chain_id=<chain_id>&module=contract&action=verifysourcecode`, using the header configuration above and these multipart fields:

| Field | Value |
| --- | --- |
| `contractaddress` | Deployed address |
| `contractname` | Original `path:ContractName` |
| `compilerversion` | Full `v0.x.y+commit.…` version |
| `codeformat` | `solidity-standard-json-input` |
| `sourceCode` | Standard JSON content |
| `constructorArguments` | Original constructor suffix without `0x`, if any |

Append `--form sourceCode=<verification-standard.json` as one subprocess argument pair; pass the public scalar fields using `--form-string`. Keep the key only in stdin. A successful submission returns a GUID: poll `module=contract&action=checkverifystatus&guid=<guid>`, then independently read the contract's verification status.

Blockscout also documents `action=verify_via_sourcify&addressHash=<address>` and file uploads. An exact Sourcify match does not guarantee this import is available on a particular explorer. Record a failed submission as incomplete. An internal-error body alone does not identify the cause: request formatting, routing, authentication forwarding, throttling and upstream faults require separate diagnosis.

## Completion evidence

- Sourcify and Blockscout statuses must be checked independently.
- Blockscout `getsourcecode` may return a verified twin's source for an unverified address. Read `https://api.blockscout.com/<chain_id>/api/v2/smart-contracts/<address>`: inspect `is_verified`, `is_fully_verified`, `is_partially_verified`, and `verified_twin_address_hash`.
- Report partial matches and twin-source results explicitly. Do not equate a proxy's verified shell with verification of all its facets.
- Save chain, addresses, source identities, compiler settings, constructor/link evidence, creation receipts, final statuses and public links. Exclude secrets and sensitive Foundry cache files.
- For HTTP/server errors, capture the HTTP status, sanitized response, `Retry-After` and rate-limit headers, and request IDs. An error body alone does not establish throttling or a service outage. Compare the method, route, encoding and field names against the documented endpoint before attributing fault. Report endpoint, status and sanitized response. Preserve successful verification evidence; retry pending addresses when the service recovers. Do not ask for a replacement key when authenticated reads work.

## Official references

Checked 2026-09-14; recheck endpoint/version guidance when behavior changes:

- [Blockscout Foundry verification](https://docs.blockscout.com/devs/verification/foundry-verification)
- [Blockscout standard JSON, Sourcify import and polling](https://docs.blockscout.com/devs/apis/rpc/contract)
- [Blockscout PRO routing](https://docs.blockscout.com/devs/migrate-from-etherscan)
- [Blockscout API client headers](https://github.com/blockscout/agent-skills/blob/main/web3-dev/SKILL.md)
- [Sourcify verification](https://docs.sourcify.dev/docs/how-to-verify/)
