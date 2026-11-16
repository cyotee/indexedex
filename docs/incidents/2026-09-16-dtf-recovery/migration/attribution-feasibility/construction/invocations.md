# Construction evidence invocations

Date: 2026-11-11. All writes use apply_patch and remain under construction/.
No chain RPC, transaction, fork, compiler, test process or server was started
by this lane. The calculation below runs against previously recorded bytes.

## Read-only worktree checks

The first attempted shell command included this malformed find expression:

```sh
find lib -maxdepth 2 -type l -exec ls -ld {} ;
```

It was followed by `&&`; the unescaped terminator made the shell reject the
whole command before execution, exit 2:

```text
/bin/bash: -c: line 4: syntax error near unexpected token `&&'
```

The corrected command used `find ... -ls`. Its preceding identity checks
returned the expected HEAD and branch, then ordinary status exited 128:

```sh
cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-06-e2 &&
printf 'HEAD\n' && GIT_MASTER=1 git rev-parse HEAD &&
printf 'BRANCH\n' && GIT_MASTER=1 git branch --show-current &&
printf 'STATUS\n' && GIT_MASTER=1 git status --short
```

```text
HEAD
5021e8d4a62bcbddc555f580ef98f8666d993aab
BRANCH
work/dtf-migration-phase-06-e2
STATUS
error: expected submodule path 'lib/crane' not to be a symbolic link
```

The corrected scope command exited 0:

```sh
cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-06-e2 &&
GIT_MASTER=1 git status --short --ignore-submodules=all &&
printf 'LINKS\n' && ls -ld lib/crane node_modules &&
printf 'EVIDENCE_FILES\n' &&
find docs/incidents/2026-09-16-dtf-recovery/migration/attribution-feasibility \
  -maxdepth 3 -type f -print
```

Status showed only:

```text
?? docs/incidents/2026-09-16-dtf-recovery/migration/attribution-feasibility/
```

The two links resolve respectively to
`/Users/cyotee/Projects/indexedex/lib/crane` and
`/Users/cyotee/Projects/indexedex/node_modules`. The listing contained the
12 inherited anchor/freshness files recorded in evidence.json, not construction
files. No submodule repair, config override write or artifact copying occurred.

## Actual offline execution and replay

The actual execution was one resident JavaScript evaluation cell, Bun 1.4.4
on darwin arm64. It returned normally with 24 passing checks; an assertion
failure would throw. This was not a subprocess, so there is no invented
process exit code. Inputs were read completely with the evaluator's `read`
helper and parsed as JSON. No producer witness functions were imported.

The self-contained equivalent below uses the same encoders, bounded trie
construction, raw record indexes, state replay and assertions. Run it in the
same resident evaluation interface, where `read` and `print` are supplied.
It performs no file write, RPC, deployment or process creation. The import
uses the existing linked dependency; nothing is installed.

```javascript
const wt = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-06-e2";
const base = wt + "/docs/incidents/2026-09-16-dtf-recovery/migration/attribution-feasibility";
const viem = await import(wt + "/node_modules/viem/_esm/index.js");
const anchor = JSON.parse(await read(base + "/anchors/rpc.json"));
const fresh = JSON.parse(await read(base + "/freshness/runtime-evidence.json"));
const checks = [];
const check = (name, pass, details = {}) => {
  checks.push({ name, pass: Boolean(pass), details });
  if (!pass) throw Error(name);
};
const response = id => JSON.parse(
  anchor.requests.find(r => r.request.id === id).raw
);
const raw = i => JSON.parse(fresh.records[i].raw).result;
const integer = x => BigInt(x) === 0n ? "0x" : viem.toHex(BigInt(x));
const header = h => viem.toRlp([
  h.parentHash, h.sha3Uncles, h.miner, h.stateRoot, h.transactionsRoot,
  h.receiptsRoot, h.logsBloom, integer(h.difficulty), integer(h.number),
  integer(h.gasLimit), integer(h.gasUsed), integer(h.timestamp),
  h.extraData, h.mixHash, h.nonce, integer(h.baseFeePerGas),
]);
const receipt = r => {
  const body = viem.toRlp([
    r.root ?? integer(r.status), integer(r.cumulativeGasUsed),
    r.logsBloom, r.logs.map(l => [l.address, l.topics, l.data]),
  ]);
  return BigInt(r.type) === 0n
    ? body : viem.toHex(BigInt(r.type), { size: 1 }) + body.slice(2);
};
// Only the observed types 0, 0x02 and 0x6a are used here.
// This is deliberately not a general Nitro receipt codec or trie verifier.
const root = receipts => {
  if (receipts.length !== 2 && receipts.length !== 3) {
    throw Error("audit bounded to two or three leaves");
  }
  const values = receipts.map(receipt);
  const top = Array(17).fill("0x");
  top[8] = viem.keccak256(viem.toRlp(["0x30", values[0]]));
  if (receipts.length === 2) {
    top[0] = viem.keccak256(viem.toRlp(["0x31", values[1]]));
  } else {
    const children = Array(17).fill("0x");
    children[1] = viem.keccak256(viem.toRlp(["0x20", values[1]]));
    children[2] = viem.keccak256(viem.toRlp(["0x20", values[2]]));
    top[0] = viem.keccak256(viem.toRlp(children));
  }
  return viem.keccak256(viem.toRlp(top));
};
for (const id of [3, 5, 42]) {
  const h = response(id).result;
  check("header-" + id, viem.keccak256(header(h)) === h.hash);
}
check("parent-bound-to-native-hash",
  response(14).result === response(42).result.hash);
check("ArbSys-current-rejected",
  response(17).error?.data.startsWith("0xd5dc642d"));
check("history-current-rejected-both-pins",
  response(34).error?.code === 3 && response(38).error?.code === 3);
check("history-runtime-same", response(20).result === response(24).result);
check("native-receipt-root",
  root([response(54).result, response(52).result]) ===
  response(3).result.receiptsRoot);

const subjects = fresh.result.subjects;
const branches = [];
for (const [name, indexes, blockIndex, preIndex] of [
  ["control", [62, 64, 63], 65, 66],
  ["mixing", [84, 83, 85], 86, 87],
]) {
  const receipts = indexes.map(raw);
  const block = raw(blockIndex);
  const computed = root(receipts);
  check(name + "-root-from-raw-receipts", computed === block.receiptsRoot);
  check(name + "-ordered-success", receipts.every((r, i) =>
    r.status === "0x1" && BigInt(r.transactionIndex) === BigInt(i) &&
    r.blockHash === block.hash &&
    r.transactionHash === block.transactions[i]));
  check(name + "-reordered-root-rejected",
    root([receipts[1], receipts[0], receipts[2]]) !== computed);
  const ledger = new Map([
    [subjects.alice, { q: 100n, c: 1000n }],
    [subjects.bob, { q: 100n, c: 3000n }],
    [subjects.custody, { q: 0n, c: 0n }],
  ]);
  const transitions = [];
  for (const r of receipts) {
    for (const log of r.logs) {
      if (log.topics[0] !==
          "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef") {
        continue;
      }
      if (log.address !== subjects.token) throw Error("wrong source");
      const from = "0x" + log.topics[1].slice(-40);
      const to = "0x" + log.topics[2].slice(-40);
      const q = BigInt(log.data);
      const sender = ledger.get(from);
      const receiver = ledger.get(to);
      if (!sender || !receiver || q > sender.q) throw Error("unclosed ancestry");
      let credit = 0n;
      if (from !== to) {
        credit = q === sender.q ? sender.c : sender.c * q / sender.q;
        sender.q -= q;
        sender.c -= credit;
        receiver.q += q;
        receiver.c += credit;
      }
      transitions.push({ from, to, q: String(q), credit: String(credit) });
    }
  }
  const award = ledger.get(subjects.custody).c;
  check(name + "-credit-replay", award === (name === "control" ? 500n : 833n),
    { award: String(award), transitions });
  check(name + "-conservation",
    [...ledger.values()].reduce((sum, entry) => sum + entry.c, 0n) === 4000n);
  branches.push({
    award, block, custody: receipts[2],
    prestate: raw(preIndex)[subjects.token].storage,
  });
}
check("same-custody-token-prestate",
  Bun.deepEquals(branches[0].prestate, branches[1].prestate));
check("different-required-awards", branches[0].award !== branches[1].award);
const events = branch => branch.custody.logs.map(
  ({ address, topics, data }) => ({ address, topics, data })
);
check("same-custody-event", Bun.deepEquals(events(branches[0]), events(branches[1])));
check("different-full-consensus-custody-receipts",
  receipt(branches[0].custody) !== receipt(branches[1].custody),
  { cumulativeGas: branches.map(b => BigInt(b.custody.cumulativeGasUsed).toString()) });
check("same-parent", branches[0].block.parentHash === branches[1].block.parentHash);
check("raw-snapshots-restored", [76, 97, 98].every(i => raw(i) === true));
print(JSON.stringify({ count: checks.length, checks }, null, 2));
```

Actual output: count 24, every `pass` true. Detailed actual computed hashes,
ordered transitions, awards and cumulative gas are retained in evidence.json.
The reproduction block is reformatted and uses shorter variable names; it is
not described as a separately executed second run.

The leaf paths above correspond to `RLP(0)=0x80`, `RLP(1)=0x01`,
`RLP(2)=0x02`. The full encoded receipts in these fixtures are long enough that
the relevant child nodes use hash references. A generic arbitrary-size proof
verifier, arbitrary receipt types, and future header codecs are out of this
calculation's scope.

## Primary source acquisition and setup failures

The upstream lanes already preserve the pinned protocol sources and exact
runtime observations. This lane read those sources directly from their raw
archives. It also retrieved the complete primary finality document with:

```text
webfetch(
  url="https://docs.arbitrum.io/how-arbitrum-works/reference/finality-and-reorgs.md",
  format="text"
)
```

The returned complete document agrees with the distinctions relied upon:
sequencer soft confirmation, parent-batch safe/finalized status, and rollback
to a common ancestor. It is general protocol documentation, not an independent
audit of Robinhood's settlement contracts.

An earlier `web.run` open of the pinned primary ArbSys raw-source URL returned
no usable text. Its result is not cited as a successful source fetch. The
already archived exact excerpts supply the source evidence:

```text
https://raw.githubusercontent.com/OffchainLabs/nitro/70fa99a6e711f09eedd96a907290c3df0f3bcf7d/precompiles/ArbSys.go
```

One evaluator printing helper failed with `showText is not defined` after
the independent file reads had completed. A persistent arrow-function binding
was used to display the retained results; no remote probe was duplicated.
Smart read-tool elision and long-line truncation were corrected by full raw
`read` plus bounded parsed-field inspection before drawing conclusions.

JSON LSP diagnostics were unavailable because `biome` is not installed.
The explicit no-dependency/config-change scope governs; no installation or
configuration change was attempted. JSON parsing and actual calculations,
not a fabricated LSP pass, provide the local executable checks.

## Resources

Allocated construction ports: none. Assigned but unused port: 18553.
Allocated runtime directories: none. Long-running processes: none.
There was nothing to kill or delete. Final read-only scope, fingerprint and
port observations are recorded in verification.json.
