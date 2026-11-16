# Anchor evidence invocations

Date: 2026-11-11 UTC. All files created by this lane are under this directory.
The persistent evaluator is Bun 1.4.4, executable
`/Users/cyotee/.omo/binary-runtime/5.1.58/omo`, PID 16046, darwin arm64.
Its host cwd is the main checkout; the worker evaluator does not support
`process.chdir`. All shell project commands explicitly cd to the assigned
worktree. File writes use absolute owned paths through apply_patch only.
Read-only main-checkout brief/plan/router and phase01 evidence reads are the
explicitly admitted inputs, not worktree mutations.

## Worktree preflight

The first command stopped with exit 128 because Git tried to traverse the
intentionally linked submodule:

```sh
cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-06-e2 &&
GIT_MASTER=1 git status --porcelain=v1 &&
GIT_MASTER=1 git branch --show-current &&
GIT_MASTER=1 git rev-parse HEAD &&
ls -ld lib/crane node_modules frontend/node_modules out cache_forge 2>/dev/null
```

Actual error:
`error: expected submodule path 'lib/crane' not to be a symbolic link`.
No branch, dependency or configuration was changed to bypass it.

The read-only corrected command, background bash_2, exited 0:

```sh
cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-06-e2 &&
GIT_MASTER=1 git -c diff.ignoreSubmodules=all status --porcelain=v1 --ignore-submodules=all;
GIT_MASTER=1 git branch --show-current;
GIT_MASTER=1 git rev-parse HEAD;
ls -ld lib/crane node_modules frontend/node_modules out cache_forge 2>/dev/null;
find docs/incidents/2026-09-16-dtf-recovery/migration -maxdepth 3 -type f
```

The status output was empty. Branch and HEAD were the requested values.
Read-only `lstat`/`realpath` confirmed:

```text
lib/crane -> /Users/cyotee/Projects/indexedex/lib/crane
node_modules -> /Users/cyotee/Projects/indexedex/node_modules
frontend/node_modules: ENOENT
out: ENOENT
cache_forge: ENOENT
```

No artifact seeding, compile or local runtime was needed.

## Read-only remote probes

Actual execution was incremental JavaScript in the persistent evaluator, not
a shell script with redirected output. Every literal JSON-RPC method, parameter,
ID, timestamp, alias, HTTP status and response is retained in `rpc.json`.
R numbers in the report refer to `request.id`, not array position.

The existing `viem/_esm/index.js` from the main checkout's linked dependencies
provided selectors, hex/RLP encoding and Keccak. Nothing was installed.
The public alias is `robinhood_mainnet_public`; the archive alias is
`robinhood_mainnet_alchemy`, both read from the assigned foundry.toml.
Credential acquisition used this short-lived subprocess without printing its
stdout, arguments containing the key, or a resolved secret URL:

```text
Bun.spawn(['/bin/zsh','-lc','printf %s "$ALCHEMY_KEY"'],
  {env:process.env,stdin:'ignore',stdout:'pipe',stderr:'pipe'})
exit 0; loginKeyAvailable=true
```

The request transport was:

```js
const request = {jsonrpc: "2.0", id, method, params};
const response = await fetch(resolvedConfiguredAlias, {
  method: "POST",
  headers: {"content-type": "application/json"},
  body: JSON.stringify(request),
  signal: AbortSignal.timeout(25000),
});
const raw = await response.text();
```

Aliases, not credential-bearing URLs, were logged. Archive transport errors
would redact the key. RPC methods were only `eth_chainId`, `web3_clientVersion`,
`eth_getBlockByNumber`, `eth_call`, `eth_getCode`,
`eth_getTransactionReceipt` and `eth_getProof`. No signing or broadcast method
was invoked.

The `eth_call` objects without `to` execute hand-assembled initcode transiently.
They do not deploy a contract or submit a transaction. NUMBER uses
`0x4360005260206000f3`; BLOCKHASH code and both nested STATICCALL probes are
preserved verbatim in the requests. The NodeInterface probe returns call success
and returndata size. The history probe additionally returns the output hash.
They distinguish protocol-callable code from RPC-only interception without an
Anvil emulation or compiler.

## Local deterministic calculations actually executed

Header RLP field order and integer normalization are specified in contract.md.
`calculations.json.headerEncodings` preserves all three encoded headers. Actual
comparison was `keccak256(encodeHeader(header)) === expectedHash`.

For P's exactly two receipts, the calculation used:

```js
const canonicalInt = x => BigInt(x) === 0n ? "0x" : toHex(BigInt(x));
const body = toRlp([
  receipt.root ?? canonicalInt(receipt.status),
  canonicalInt(receipt.cumulativeGasUsed),
  receipt.logsBloom,
  receipt.logs.map(log => [log.address, log.topics, log.data]),
]);
// Prefix body with the receipt type except legacy/Arbitrum-legacy types.
const leaves = [
  toRlp(["0x30", encodedInternalReceipt]),
  toRlp(["0x31", encodedUserReceipt]),
];
const branch = new Array(17).fill("0x");
branch[8] = keccak256(leaves[0]); // RLP(0) = 0x80, remaining nibble 0
branch[0] = keccak256(leaves[1]); // RLP(1) = 0x01, remaining nibble 1
const root = keccak256(toRlp(branch));
```

Actual result:
`0xed4030c56b19861b12d407133d34d67e86eb659431133713cbdc126ba9f35a17`,
matching P. Encoded receipt values, leaves, branch and root are preserved.
This calculation is deliberately bounded to P's two receipts and is not
presented as an application verifier.

All 11 checks in `calculations.json.checks` returned true. Window boundary
responses are separately retained, including expected reverts.

## Primary sources and failed discovery

Sources were retrieved with `fetch(url)` and a 25-second request bound, decoded
as text, and hashed using
`new Bun.CryptoHasher('sha256').update(text).digest('hex')`.
`primary-sources.json.discovery` lists every such request URL, status, size and
SHA-256, including unsuccessful paths and the unresolvable public build.
Exact archive-build source excerpts are preserved with original line ranges.
Whole-file hashes refer to downloaded complete sources, not their excerpts.

The report was also checked against primary Arbitrum and Robinhood documentation.
No third-party chain summary, protocol mock, current repository lookalike,
search-result snippet or master branch is substituted for the deployed history
runtime. Documentation governs the stated finality model; RPC tags remain
observations rather than finality proofs.

Two evaluator setup errors caused no remote call or file mutation: a function
declaration did not persist to the next cell (`rpc is not defined`), corrected
by using a persistent arrow-function binding; and `process.chdir` was rejected
by the worker runtime. Neither was retried as a duplicate remote probe.

## Final scope check

The final read-only Git scope and port check, JSON parse/count checks and
ephemeral-runtime disposition are retained in `verification.json`.
All authored files used apply_patch. No file or directory was removed.
