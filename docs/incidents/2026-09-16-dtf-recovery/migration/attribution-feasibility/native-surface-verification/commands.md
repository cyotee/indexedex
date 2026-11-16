# Independent verification operations

Date: 2026-11-11. Runtime: resident Bun JavaScript kernel on darwin arm64.
No shell command, build, test runner, local EVM, child or runtime process was
started. There is no subprocess exit code to report.

## Inputs and preservation

Read the explicitly named main-checkout native-surface brief, its referenced
phase06 E2 brief, the worktree CLAUDE router, the complete prior verification
report and native-surface scope, and producer contract and machine-readable
evidence. The original brief supplies the incident-directory prefix; three
initial lookups without that prefix returned ENOENT and were corrected.
No absence claim was made from those errors.

All text inspection used read. Independent source data was held in a resident
Map keyed by repository/path. Every family interface and handler was inspected,
with numbered ranges for relevant producers and opcode hooks. Large reads
were parsed in full in memory or displayed in bounded ranges; a clamped
tool-display summary was not used as a file fingerprint.

Inherited evidence files were enumerated and fingerprinted before edits.
The first glob omitted dotfiles, yielding 109 files and 78 raw source files.
Comparison against provenance identified `sources/nitro/.gitmodules`; it
was read and added before any edit. The complete preservation set is 110
files, with 79 source copies. Final preservation results are in cleanup.json.
No inherited file was intentionally changed.

## Independent read-only source requests

The exact pinned Nitro registration was also opened with the web tool.
Subsequent source requests ran directly in the resident kernel:

```js
const trees = await parallel(treeUrls.map(url => async () => {
  const response = await fetch(url);
  const text = await response.text();
  return {
    url,
    status: response.status,
    sha256: new Bun.CryptoHasher("sha256").update(text).digest("hex"),
    body: JSON.parse(text),
  };
}));
```

Exact URLs, status, full-response SHA-256, tree SHA, truncated flag, entry
counts and relevant raw entries are retained in audit.json
`independentSourceRequests`. All three responses were HTTP 200 and
nontruncated, with 3507 Nitro, 2807 Geth and 29 interface entries.
Full network tree bodies were processed in memory; the evidence retains
relevant raw entries, not a second full tree archive.

The Nitro response independently established both submodule gitlinks.
For each archived source, actual text bytes were checked:

```js
const sha256 = new Bun.CryptoHasher("sha256").update(text).digest("hex");
const gitBlob = new Bun.CryptoHasher("sha1")
  .update(`blob ${Buffer.byteLength(text)}\0`)
  .update(text)
  .digest("hex");
```

Required equality: computed SHA-256 equals producer recorded SHA-256;
computed Git blob equals producer recorded blob and the independently fetched
exact pinned tree entry. Result: 79/79 matches. The original finite-scope
registration/ArbInfo/ArbStatistics hashes also matched.

One new raw-source request obtained pinned Geth `core/state_processor.go`.
HTTP 200, computed Git blob equals the same pinned Geth tree entry.
`ProcessParentBlockHash` at lines 340-369 was read to verify the exact system
caller and previous-hash input. Its entire unchanged source response was
archived under this verifier's sources directory. Its URL, SHA-256 and blob
are in audit.json `additionalSource`.

These were source-service requests, not chain RPC calls. No source was fetched
from master/main or substituted for an unresolved executable revision.

## Enumeration and ABI reconciliation

Independent registration extraction:

```js
const registered = [...registration.matchAll(
  /MakePrecompile\(precompilesgen\.([A-Za-z0-9]+)MetaData/g
)].map(m => m[1]);
```

Every registered family was processed, including ArbBLS with zero functions.
For each pinned interface, comments were removed and every Solidity function
declaration was extracted through its semicolon. Whitespace was normalized
without changing types. The two resource structs were supplied to the
existing linked ABI parser after independently reading their definitions:

```js
const types = [
  "struct WeightedResource { uint8 resource; uint64 weight; }",
  "struct ResourceConstraint { WeightedResource[] resources; uint32 adjustmentWindowSecs; uint64 targetPerSec; uint64 backlog; }",
];
const declarations = [...stripComments(solidity).matchAll(
  /\bfunction\s+[\s\S]*?;/g
)].map(m => m[0].replace(/\s+/g, " ").trim());
const abi = viem.parseAbi([
  ...types,
  ...declarations.map(d => d.slice(0, -1).replaceAll(
    "ArbMultiGasConstraintsTypes.ResourceConstraint", "ResourceConstraint"
  )),
]);
```

The existing linked utility resolved with
`Bun.resolveSync("viem", worktree + "/frontend")` to
`/Users/cyotee/Projects/indexedex/node_modules/viem/_esm/index.js`.
No package installation or repository change occurred.

For every function:

- Recompute `toFunctionSignature` and `toFunctionSelector`.
- Compare input/output types recursively, including tuple components.
- Compare ABI mutability and actual Geth address constants.
- Require the ABI-name capitalized form to exist in the complete exported
  Go receiver method set, and require no unmatched exported receiver.
- Compare the inventory's full handler body to its exact pinned source range.
- Check within-address selector uniqueness.

Actual results: 18 families, 191 functions, no extra or missing handlers,
no signature/selector/type/mutability/address/body mismatch, no collision.
Per-method results are retained, not just the totals.

## Version and access reconciliation

The check parsed exact numeric ArbOS constants and named aliases from
Geth config_arbitrum.go. Registration variable names were bound to their
metadata families, including ArbRetryable and lowercase arbDebug aliases.
It reconstructed:

- Default method and family minima of zero.
- Family minima for ArbWasm, ArbWasmCache, ArbNativeTokenManager and filtering.
- Both Stylus family-wide method loops and the owner's Stylus method list.
- All 65 explicit method min/max assignments in source order, preserving
  final assignment precedence.
- The single maximum-version exclusion, cacheCodehash at min=max=30.
- The additional minInitGas handler-body threshold of 32.

For each row, enabled-at-61 is `61 >= max(familyMin, methodMin)` and
`methodMax == null || 61 <= methodMax`. Result: 190 enabled and one inactive;
every inventory version value matched.

Access was classified from inspected bodies/wrappers independently of
producer disposition labels: ordinary; inactive; role-restricted;
debug-config; unconditional ordinary revert; zero-caller.
Only after that classification were producer labels compared.
Result: 109, 1, 68, 7, 5 and 1 respectively, with zero disagreements.
The empty ArbBLS family is explicitly retained.

Full handler inspection and writer traces supplied the semantic groups in
audit.json. Extracted return-expression lines are navigation evidence, not
the sole basis of semantic review; full handler bodies were reconciled and
read, including mutations, conditions, custom errors and helper calls.

## Native hooks, primitives and existing runtime evidence

Read map activation from NewEVM through Rules/IsElara to
StartingFromArbOS60, Nitro map population and Osaka's exact entries.
Read all 18 standard primitive Run bodies and BN256/point-codec helpers.
An initial enumeration using only parameter spelling `input` found 17;
the identity handler uses `in`. It was read directly, then the enumeration
was corrected to accept both spellings and returned 18. No missing-method
claim was inferred from this parser restriction.

Read relevant NUMBER/BLOCKHASH, selected balance/code/storage, frame/message,
fee, block-context and blob opcode bodies, Nitro hook implementations,
history bytecode/update path, and NodeInterface RPC interception.
Read actual completed-header root updates after transaction processing.
No native execution was emulated in this audit.

Existing raw requests and responses from anchors/rpc.json were parsed, not
reissued. In particular:

```js
const codeResult = id =>
  JSON.parse(requests.find(r => r.request.id === id).raw).result;
const observedPVersion = Number(BigInt(codeResult(12))) - 55;
const observedCVersion = Number(BigInt(codeResult(8))) - 55;
const exactRuntimeMatch = codeResult(20) === "0x" + historyConstant;
const historyCodeHash = viem.keccak256(codeResult(20));
```

Observed versions: 61 and 61. R20/R24 each exactly match the 133-byte pinned
history constant and Keccak
`0xceef1f6ad6c0cb7eb8fb15678abf11da3ce0d3a7c7106aa900c5930e556a43ff`.
R2/R56 advertise different builds. R48/R51 are creation-style eth_call
simulations of nested calls, not mined Nitro prefix probes.
The report preserves those limits.

## Writes, validation and cleanup

All authored files were created through apply_patch, only under
native-surface-verification. The method ledger contains exact source
references and individual structural results; the report contains the
independent semantic argument and binding verdict.

The write tool reported missing gopls and Biome. No installation or compiler
run was attempted; those unavailable diagnostics are explicitly disclosed.
JSON parse/structure checks and source byte identities are the actual checks,
not a claimed clean LSP run.

Final JSON validation, reference existence, preservation fingerprints, and
owned artifact inventory are recorded in cleanup.json. No fork, listener,
child, temporary root, pending runtime or monitor exists from this verifier.
No other lane's processes were inspected or stopped.
