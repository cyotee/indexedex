# Freshness witness invocations

## Actual execution

The resident evaluation kernel ran Bun 1.4.4 at
`/Users/cyotee/.omo/binary-runtime/5.1.58/omo`. The witness was imported by
absolute path from this worktree; there was no build or child test process.
An assertion failure would throw. The run returned `pass: true` and
`restored: true`; no process exit code is invented for that in-process call.

The literal Anvil shell command is `runtime-evidence.json.command`.
It used `/opt/homebrew/bin/anvil` 1.9.0-Homebrew, commit
`6056c5845d34205a83cf7108042adb137325c9df`, historical block 108944663,
chain 4663, `--no-mining --order fifo --accounts 0`, loopback port 18552,
`--compute-units-per-second 10 --no-storage-caching`, and the configured
`robinhood_mainnet_alchemy` alias. Login-shell credentials were consumed but
never persisted. HOME/TMPDIR and cache environment paths were scoped to
`freshness/runtime/`.

Readiness was subscribed before execution using `tool.monitor` with
`Listening on|Error|error`. Monitor `mon_M9AAFWVG6RK3Z86X`, session `bash_1`,
emitted `Listening on 127.0.0.1:18552`. No sleep/poll loop was used.

The executed witness call was:

```javascript
const local = "http://127.0.0.1:18552";
const rpc = async (method, params = []) => {
  const r = await rpcAt(local, method, params);
  assert.ok(!r.error, JSON.stringify(r.error));
  return r.result;
};
const witness = await import(prefix + "/witness.mjs");
const witnessResult = await witness.runWitness(rpc);
```

`rpcAt` issued JSON-RPC POST with sequential request IDs and a 120-second
AbortSignal timeout, recorded endpoint alias/method/params/HTTP status/raw
response, required HTTP 200, and returned the parsed envelope. The evidence
file retains those raw requests/results, including the historical pin and
precompile calls made separately against the public read-only endpoint.
No RPC mutation was sent to a public endpoint.

The decisive observations were:

```text
pass: true
self-transfer-control: block 108944665, award 500, remainder 500
balance-restoring-prefix: block 108944665, award 833, remainder 833
sameSelectedCustodyEvent: true
distinctHistoryCommitments: true
restored: true
```

All nine local receipts have status 1. Both branch receipt-index lists are
`[0,1,2]`. The custody prestate proves Alice's balance 100 and custody balance
0 in both branches. Call traces show no call beyond the source's facet.
The arithmetic is an oracle for the required synthetic credit, not a
production credit implementation.

## Standalone replay procedure

First confirm port 18552 is free; do not stop a listener belonging to another
session. In this worktree, start the exact recorded Anvil command in an owned
monitored terminal, wait for its readiness event, then run the following from
this directory with the existing Bun and dependencies:

```bash
bun --eval '
import assert from "node:assert/strict";
import { runWitness } from "./witness.mjs";
let id = 0;
const rpc = async (method, params = []) => {
  const response = await fetch("http://127.0.0.1:18552", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: ++id, method, params }),
    signal: AbortSignal.timeout(120000),
  });
  const raw = await response.text();
  console.log(JSON.stringify({ method, params, status: response.status, raw }));
  assert.equal(response.status, 200);
  const envelope = JSON.parse(raw);
  assert.ok(!envelope.error, JSON.stringify(envelope.error));
  return envelope.result;
};
const result = await runWitness(rpc);
console.log(JSON.stringify(result, (_, v) => typeof v === "bigint" ? String(v) : v));
assert.equal(result.pass, true);
assert.equal(result.restored, true);
console.log("FRESHNESS_SOURCE_WITNESS_PASS");
'
```

This equivalent shell wrapper is a reproduction recipe, not the originally
executed command. The actual execution is the resident-kernel call above.
Use a caller-owned log capture and preserve failures. After execution, stop
only the owned server and remove only its recorded runtime directory.
The module restores snapshots but does not own/start/stop the server.

The setup timestamp follows Anvil's local clock, so derived local block hashes
can change on replay. The public pin, exact branch transaction order,
same-parent relation, state/credit results and assertions are the invariants.
These are local fork blocks, never claimed canonical public history.

## Failures and limits retained

* Initial ordinary `git status --porcelain=v1` exited 128:
  `error: expected submodule path 'lib/crane' not to be a symbolic link`.
  `git status --porcelain=v1 --ignore-submodules=all`, HEAD and branch checks
  exited 0. Dependency targets were resolved read-only.
* An exploratory literal search of `contracts/tokens` returned path-not-found;
  it was not used as absence evidence. Deployed archive/routing evidence,
  not that nonexistent directory, determines the transfer finding.
* Two evaluation setup cells failed before the public precompile queries:
  a parsing error and a nonpersisted function declaration. The successful
  invocation used a persistent `const` RPC function. These were host setup
  failures, not failed source transactions.
* The optional public Multicall `debug_traceCall` returned HTTP 400:
  `debug_traceCall is not available on the Free tier - upgrade to Pay As You Go, or Enterprise for access.`
  Exact request/result is retained in `protocol-sources.json`. Actual
  `eth_call`/runtime bytes and local custody traces succeeded.
* A broad Solidity contracts-document fetch was truncated; it was not used.
  The complete dedicated `events.rst` was fetched instead.
* Automatic diagnostics reported Biome not installed. Dependencies/config
  were not changed to install it; no LSP PASS is claimed.

These failures did not require a public transaction, compilation, SUT mock,
state injection, alternate historical pin or policy change.

## Cleanup

The witness reverted both branch snapshots and its initial outer snapshot.
Then `kill_bash({bash_id:"bash_1"})` terminated only the owned Anvil monitor;
its completion notification reported exit 0. A TCP connection to 18552
returned `ECONNREFUSED`. The exact owned `freshness/runtime` directory was
removed with `rm -rf <that absolute directory>` (exit 0); no wildcard or
shared-cache cleanup was performed. Final independent read-back is in
`verification.json`.
