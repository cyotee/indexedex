# Binding and reproduction method

`execution-evidence.json` contains the literal completed outer shell recipes
and every expanded build/test command extracted from the three final logs.
The fork shell argument is single-quoted as one literal argument to
`/bin/zsh -lc`; do not expand the caller's PATH into it first. The configured
RPC alias and block are in the unchanged real fork TestBase. No local node is
required. Run from the recorded worktree with its retained warm artifacts
and unchanged dependency links. No prior CLI/resume or held09 operation is
part of these commands.

The final spec command selects the complete Migration specification directory,
including `invariant/`; the fork command selects its complete fork counterpart.
Both supply concrete migration facets/packages and the corresponding concrete
handler as artifact build roots. The artifact helper adds Solar to both phases.
Handlers use explicit Foundry `targetInterface` plus `targetSelector`, following
the existing repository pattern. The ordinary command selects exactly the six
files recorded in its expanded command. Do not substitute the very broad
`DETFFundedStakingSuite.t.sol` aggregation root.

## Source and raw file identity

For each new Solidity source, read the complete raw UTF-8 file, require its
UTF-8 byte length equals the filesystem length, and compute SHA-256 of those
bytes. `candidate-01.json` retains that text, hash, length and regular-file
mode. Its complete diff is in `candidate-01.patch`. Original tracked source
is unchanged against the recorded Git HEAD; all added code is inside the
three permitted invariant directories.

Authority report bindings are raw SHA-256/length/mode, not hashes of parsed
Markdown. No report or historical input was rewritten. Source22/claimed-SY
limits are retained from the complete actual phase23 producer, r2 and
immutable audit; this increment performs no claimed-source authentication.

## Compiler and artifact audit

Take the union of explicit `.sol` roots before the first `--skip` in each
final `forge build` command. Inspect artifacts in the matching `out/<file>.sol/`
directory only when `metadata.settings.compilationTarget` names that source.
Add the nine already-built core deployment artifacts named in
`artifact-deployment-bindings.json` to bind the captured foundational facets
and minimal proxy. No build, cache or source is changed by this audit.

For every selected artifact, retain raw file SHA-256/length, compiler,
optimizer, viaIR, creation-object SHA-256, runtime-object SHA-256, runtime
length, link references and raw-metadata SHA-256. Take the union of
`metadata.sources`; repeated paths must have identical declared keccak256.
Read each actual source file through its recorded worktree-relative path
(including retained symlinks), compute Keccak-256 of its raw bytes, and require
equality to the declared value. Record its SHA-256 and byte length as well.
Result: 177 artifacts, 966 unique source paths, zero conflicts or mismatches.

This uses the installed viem 2.57.7 Keccak/ABI routines and Node SHA-256 from
the Bun eval kernel. No library was installed or modified.

## Actual deployment captures

Each `STATEFUL_SUBJECT` log is followed by ABI encoding of nine addresses
(parent, hook, bond, receipt, raw SY, staking SY, reward token, package,
registry) and the actual snapshot ID. Each `STATEFUL_RUNTIME` log is followed
by ABI encoding of `(address,bytes)` read from that deployed address's code.
`MigrationStatefulBindings` reads the actual eight diamond roots, all of their
loupe facets, and the package. Captures are in final test logs, not reconstructed
from artifacts.

Decode every capture, retaining its log and 1-based line locator. Hash the
actual code and retain its exact length. There are 522 repeated captures over
66 unique address/runtime pairs and six subject captures. The six captures
represent two native subjects repeated for the invariant/deterministic tests,
and one fork subject repeated for its two tests.

Match each actual runtime against selected artifact `deployedBytecode.object`.
Exact byte equality is checked first. Where the compiler reports link or
immutable references, substitute only the exact reported start/length spans
with their actual captured bytes, retaining each span, name/ID and value.
Require whole-bytecode equality, including metadata. Repeated occurrences of
one link or immutable must contain the same value. Every captured runtime has
a match; no wildcard, metadata stripping or arbitrary difference masking is
accepted. The actual 22 package immutable values remain recorded.

This does not independently authenticate the constructor transaction or
separately capture every linked library's code. Those are explicit evidence
limits, not substituted zero bytes. Named libraries and actual link values
remain visible. The native `native submitted package arguments` logs are the
same memory tuple passed by the real fixture to `deployVault`; decode with the
current package method ABI, and compare the owner/hook to captured identities.
Do not describe an ABI decode as a signed transaction or receipt.

## Execution counts and preservation

Final literal PASS lines independently count 169 specs, 144 forks and 58
ordinary tests, matching the suite summaries. The two invariant selector
tables each sum to 128 calls at runs=16/depth=8. Their reverted/discarded
columns are all zero. Exact expected SUT rejections occur inside successful
handler invocations and are separately counted.

Foundry prints the retained sequence's handler counters, not the sum of
all 16 states. Preserve that distinction when reproducing the report.
Deterministic prelude calls are not included in the 128 generated-call table.
Never infer missing aggregate success/rejection counts from a single retained
sequence. Zero-output claims are explicitly not positive action witnesses.

All failed logs remain under their original names. `seal.json` enumerates
every owned regular evidence file by raw bytes/SHA-256/mode, excluding only
itself; it also repeats candidate source bindings. It is written after final
cleanup and reporting. No self-hash or claim that a seal proves its own
historical truth is made.
