# Native-surface evidence operations

Date: 2026-11-11. All execution was in the resident Bun 1.4.4 JS kernel.
No shell, Forge, Nitro, compiler, test runner, installer or local EVM was run.
There is therefore no subprocess exit code to report. Each completed
evaluation returned normally except the discovery/parser errors recorded below.
All writes used apply_patch and were confined to this native-surface directory.

## Inputs and ownership

Read the absolute main-checkout native-surface and phase06 E2 briefs, the
worktree CLAUDE router, complete verification/report.md, and
verification/native-surface-scope.json. Read the relevant inherited anchor
contract, actual RPC records, official configuration excerpt and source
provenance. No prior completed-parent balance witness or producer probe
function was invoked.

The first report lookup mistakenly omitted the incident-directory prefix and
returned ENOENT. The original phase06 brief supplied the correct evidence
prefix, which is used throughout the delivered artifacts. This was a path
correction, not evidence that the report was absent.

The existing evidence directory had 21 files before this lane authored
native-surface/. Raw byte lengths/SHA-256 values were taken before edits.
Content inspection used read; raw-byte fingerprinting used Bun.file and
CryptoHasher. Default large-file reads can return elided representations;
those representations were not used as file fingerprints. The complete
prior report was read in bounded ranges, including its final cleanup section.

Worktree identity was inspected with read on these existing metadata files:

```text
<worktree>/.git
  gitdir: /Users/cyotee/Projects/indexedex/.git/worktrees/dtf-migration-phase-06-e2
<gitdir>/HEAD
  ref: refs/heads/work/dtf-migration-phase-06-e2
<common gitdir>/refs/heads/work/dtf-migration-phase-06-e2
  5021e8d4a62bcbddc555f580ef98f8666d993aab
```

No Git command, index operation or commit occurred.

## Read-only pinned network acquisition

The initial web open of the exact pinned Nitro precompile.go was followed by
raw HTTPS fetches in the resident kernel. These were source-service requests,
not chain RPC calls or transactions.

The source-fetch operation, with resident caching, was:

```js
var loadSource = async (path, repo = "nitro", ref = rev) => {
  const key = repo + "/" + path;
  if (src.has(key)) return src.get(key);
  const url =
    `https://raw.githubusercontent.com/OffchainLabs/${repo}/${ref}/${path}`;
  const res = await fetch(url);
  const text = await res.text();
  requests.push({
    url,
    status: res.status,
    bytes: Buffer.byteLength(text),
    sha256: new Bun.CryptoHasher("sha256").update(text).digest("hex"),
  });
  if (!res.ok) throw Error(`${res.status} ${url}`);
  src.set(key, text);
  return text;
};
```

Source paths, exact URLs, response status, byte counts and hashes, including
unsuccessful discovery, are retained in source-provenance.json. Its `archived`
flag distinguishes the 79 relevant full source files from successful
exploratory files not relied on in the contract. The three recursive Git tree
queries and their response hashes, truncated flags and exact gitlink entries
are recorded there as well. All three trees were nontruncated.

The pinned Nitro tree determined the Geth and interface gitlinks. The pinned
Geth tree corrected guessed filenames: core/types/arbitrum_types.go,
params/arbitrum_params.go and core/types/addresses.go each returned HTTP 404
with body `404: Not Found`. Actual files are core/types/arb_types.go,
params/config_arbitrum.go and core/types/arbitrum_signer.go respectively.
No absence conclusion was drawn from a guessed path.

An initial helper declared as a function was unavailable in the subsequent
resident cell (`getsrc is not defined`); the cached source map survived.
The reusable `loadSource` variable above replaced it. No side effect was
duplicated. A first ABI parse rejected multiline formatting; whitespace was
collapsed before parsing without changing signatures. A first opcode lookup
for opSelfBalance in instructions.go failed; the pinned eips.go supplies it,
opTload and the blob/base-fee implementations. All these corrections used the
same pinned revisions, not a fallback current source tree.

## Finite enumeration and calculations actually performed

1. Enumerated every MakePrecompile metadata registration in Precompiles().
   Compared that exact set with all 18 prior-scope names, not just a subset.
2. Read every full family interface and full Go handler body. Removed Solidity
   comments for declaration enumeration while preserving line positions.
   Parsed every function declaration and canonicalized nested tuple types.
   ArbBLS's interface and exported-handler sets are both empty.
3. Used the already linked viem dependency, resolved from the worktree frontend
   path, without install. parseAbi processed the interface functions and
   explicit WeightedResource/ResourceConstraint definitions; toFunctionSignature
   and toFunctionSelector computed all canonical signatures/selectors.
   The known arbBlockNumber() control produced 0xa3b1b31d.
4. Independently enumerated the exported Go receiver methods in each family.
   Required exact name-set equality with its ABI method rows and unique
   selectors within each address. MakePrecompile's own reflection checks were
   read, not executed by a forbidden build.
5. Read raw Geth address constants and params/config_arbitrum.go. Resolved
   ArbOS constant aliases, all 65 explicit method-version assignments,
   last-write precedence, family minima and Stylus loops. Applied the
   cacheCodehash maximum and minInitGas body condition separately.
6. Read the relevant producer bodies and update points for all return classes.
   Recorded individual row dataflows and access conditions, including public
   filter membership, public owner-map repair, selected ticket hashes,
   outbox-only commitments and before/after-transaction fee accounting.
   These semantic classifications are source reasoning, not proof generated
   by asserting the resulting label.
7. Read relevant Geth opcode bodies, Nitro hooks, history runtime constant,
   node-interface interception and standard-primitive registration. Traced
   NewEVM -> Rules(ArbOSVersion) -> IsElara -> StartingFromArbOS60 to close
   actual map activation at source 61 rather than presuming the map choice.
8. Checked each archived source's exact Git blob identity against its pinned
   tree entry and its SHA-256. The raw blob calculation was:

```js
const actual = new Bun.CryptoHasher("sha1")
  .update(`blob ${Buffer.byteLength(text)}\0`)
  .update(text)
  .digest("hex");
```

9. Compared the prior scope's three source SHA-256 values with the exact
   acquired files. Compared inherited R20/R24 history runtime bytes with
   HistoryStorageCodeArbitrum; both match, 133 bytes, with the recorded Keccak.
   Parsed existing selected RPC responses without sending them again.
10. Wrote the method rows, full source copies and report through apply_patch.
    An attempted two-hunk wording/locator correction failed because one
    expected line omitted its paragraph prefix; no hunks were applied.
    Read the required affected range, corrected the context and applied it.
    No other file or earlier evidence was reverted.
11. Validated JSON serialization, method/handler source ranges, selectors,
    version records, dataflow references, written artifact fingerprints and
    inherited before/after fingerprints. Actual outcomes are in
    completeness.json and cleanup.json.

Structural assertions check machine-consumed inventory values and byte
identities. They are not tests of prose and not a substitute for native-runtime
proof. The assertions are producer-local checks, not a separate independent
verifier's acceptance.

## No runtime work to clean up

No new chain RPC query, historical balance/receipt probe, local fork, Nitro
environment, execution transaction, owned port/listener, subprocess, monitor,
child or temporary filesystem root was created. There is no candidate whose
faithful native runtime probe is pending. The exact remaining provenance
binding is documented, rather than replaced with an assumption.
