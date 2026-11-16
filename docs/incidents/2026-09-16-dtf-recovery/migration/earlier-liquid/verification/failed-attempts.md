# Retained verifier attempts

The initial monitor request rejected `timeout_ms=14400000` before execution:
the tool maximum is3600000. The warm run used the supported deadline and
completed. A Python adapter `await` error occurred after that monitor had
already started; its injected events confirmed the same run, so it was not
launched twice.

The initial evidence audit failed at `audit.ts:55` while trying to reconstruct
the signature of an Anvil-impersonated legacy source-holder transaction.
Actual raw canonical transaction fields contain synthetic `r=0x1,s=0x1`.
For transaction
`0x31ea1a256fd03b1a6d46b580c49674ca21c653f257d41dd25bd9da3dfae6caf5`,
naive RLP reconstruction hashes to
`0xaa17377bd8dc23fc953f43c5bb8f958d640dfad18126cbe6c7eee3b6d610ea03`.
This was a verifier assumption error, not an ED candidate failure.

The correction distinguishes these exact synthetic-signature acquisition/
fixture transactions from actual signed originals. It still requires every
actual signed payload and reconstructed acquisition to authenticate its exact
mined hash; every canonical receipt field remains independently compared.
The original empty `audit.json` from the failed output stream remains.
The corrected attempt writes a distinct `audit-02.json`.

Attempt02 next rejected an incorrect contiguous-substring assumption for
registry `deployPkg` calldata. `IVaultRegistryDeployment.sol:49` accepts
creation bytecode and constructor arguments as separate dynamic byte arrays.
Attempt03 decodes that actual ABI, checks exact creation-code equality,
concatenates its exact two decoded inputs against the CREATE record, and uses
the decoded argument bytes for immutable validation. No source, operator,
test, producer file or runtime evidence changed.

Attempt03 reached the fresh run and exposed an additional producer-auditor
input-schema assumption: canonical RPC signature scalars can have odd hex
digit counts. The frozen producer `receipts.ts` expects even-byte hex for
`transaction.s` in the interruption capture. It accepts the producer's own
values but rejects a legitimate fresh-run scalar. The owned `receipts.ts`
uses canonical quantity syntax and compares scalar integer values to the
actual decoded signed payload. This changes no candidate behavior or evidence.
Attempt04 retains a distinct final output, without rerunning the CLI/tests.

Bash LSP is unavailable (`bash-language-server` is not installed); no dependency
was installed. Shell syntax validation and actual execution both succeeded.
