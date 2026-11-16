# Blockscout verification research — 2026-09-14

## Findings

The PRO API supports source verification, not only reads. Its documented route is `https://api.blockscout.com/v2/api?chain_id=4663&module=contract&action=verifysourcecode`. Authentication may be a query `apikey` or an Authorization header. Use the already configured `BLOCKSCOUT_API_KEY`; for automated requests prefer a header passed through stdin rather than credentials in process arguments or logs.

References: [verification API](https://docs.blockscout.com/devs/verification/blockscout-smart-contract-verification-api), [authentication and routes](https://docs.blockscout.com/devs/pro-api-responses-and-routes).

## Reproduced Forge 1.5.1 problem

A loopback-only HTTP server captured installed Forge requests with a dummy credential. Both `ETHERSCAN_API_KEY` and `VERIFIER_API_KEY` were populated. No external verifier or onchain writes were involved.

| Chain argument | API key in body | API key in query | Authorization header |
| --- | --- | --- | --- |
| 4663 | No | No | No |
| 1 (control only) | Yes, dummy value | No | No |

[Captured request shapes](forge-request-shape.json) contain field names and booleans only.

Forge v1.5.1 replaces its key using resolved chain configuration in `VerifyArgs::run`. Without a matching explicit explorer configuration, `ResolvedEtherscanConfig::create` returns `None` if the chain has no built-in Etherscan URLs. The installed version's chain 4663 behavior is reproduced above. This explains the unauthenticated Forge submission despite configured environment variables; the provider does not categorically discard all Blockscout keys.

A second compatibility concern remains after key resolution: `foundry-block-explorers` 0.22.0 serializes its verification API key into the POST form. Blockscout PRO documents query/header authentication. Therefore resolving the key alone does not prove gateway authentication will work. Do not fake chain 1 as a workaround; it was only a local control.

Source: [Forge key resolution](https://github.com/foundry-rs/foundry/blob/v1.5.1/crates/verify/src/verify.rs#L247-L250), [chain configuration](https://github.com/foundry-rs/foundry/blob/v1.5.1/crates/config/src/etherscan.rs#L265-L275), [exact HTTP-client crate](https://static.crates.io/crates/foundry-block-explorers/foundry-block-explorers-0.22.0.crate).

The error logger serializes the contract-verification object, not necessarily the complete HTTP request. Absence of an API key from that error payload alone was insufficient evidence; the loopback capture establishes actual behavior.

## Recommended procedure for this deployment

1. Preserve the original 58-contract inventory, compiler settings, source hashes, constructor arguments and creation receipts. Sourcify already confirms exact creation/runtime matches for all 58.
2. Use Forge to generate standard JSON with `--show-standard-json-input`; preserve original compiler settings and source identities. Do not flatten or modify deployed source to satisfy a verifier.
3. Submit multipart form data to the PRO route above, with the existing key in `Authorization: Bearer …`. Fields: `contractaddress`, `contractname` (`path:Name`), `compilerversion` (full version), `codeformat=solidity-standard-json-input`, `sourceCode` (JSON content), and optional `constructorArguments` (original encoded suffix). Capture HTTP status and selected response headers without logging credentials.
4. Wait for a submission GUID. Poll `action=checkverifystatus&guid=…` until the final result. A queued job is not verified.
5. Independently read the address's verification fields. Distinguish full verification, partial verification and a verified twin's source. Verify proxy shells and their newly deployed facets separately.
6. Validate one contract end-to-end before continuing the batch. If the request fails, preserve method, public URL, field names, HTTP status, rate/credit headers, request ID and sanitized body; change one request detail at a time.

The standard JSON field spelling is `constructorArguments` in Blockscout's current parser. One prior form retry used `constructorArguements` instead. This does not explain the other failed attempt, which used the documented spelling. [Blockscout parser](https://github.com/blockscout/blockscout/blob/master/apps/block_scout_web/lib/block_scout_web/controllers/api/rpc/contract_controller.ex).

## Errors and throttling

Blockscout documents HTTP 429 for exceeding request rate. Relevant headers are `x-ratelimit-limit`, `x-ratelimit-remaining`, `x-ratelimit-reset` and `x-credits-remaining`. The `source: internal` envelope describes PRO gateway processing/routing/configuration failures; `source: upstream` identifies upstream forwarding/response failures. An internal-error body is not evidence of throttling or a contract compiler mismatch.

The earlier direct HTTP attempts saved bodies but not HTTP status or rate-limit headers, so their root cause remains unresolved. Research did not establish a Blockscout service outage or produce a new successful Blockscout verification.

References: [rate limits](https://docs.blockscout.com/rate-limits), [error meanings](https://docs.blockscout.com/devs/error-responses).

## Other documented routes

Blockscout supports `verify_via_sourcify`, which can import an existing match or accept source and metadata files. Its UI also offers Sourcify verification. The direct explorer API route is intended for instance access; Robinhood's host can present a bot-protection challenge, so programmatic work should use authenticated PRO access. Do not bypass that challenge.

References: [Sourcify UI](https://docs.blockscout.com/devs/verification/contracts-verification-via-sourcify), [Foundry instructions](https://docs.blockscout.com/devs/verification/foundry-verification).
