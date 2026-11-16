# Attribution probe contract, recorded before execution

Worktree and command cwd:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01`.

Owned root, created with the required `mktemp -d` template:
`/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/attribution.cIEIBO`.
No shared Forge build, install, public mutation, or source alteration is required.

## Candidate checks

1. Current balance plus frozen per-wallet allowance: reject if two authenticated
   ordinary-transfer histories have equal final token observations but different
   credits under plan section 5.4.
2. NFT current-owner/remaining-position reads: inspect producer custody, partial
   claim, burn, and operator-redirection results. This can identify a surviving
   NFT; it cannot authenticate fungible descendants.
3. Receipt gons, wrapper shares, claim weights, SE and LP balances: compare actual
   producer conversion/custody probes with their attribution limitations. A
   mechanical transfer PASS is not provenance or user-authority PASS.
4. Frozen root, selected logs, RPC storage proof, nullifiers, fresh signatures,
   mandatory wrapper, and new history-verifier subsystem: evaluate separately
   for complete authenticated postactivation transition history. No candidate
   passes merely because its hash, signature, endpoint or token address exists.

## P1: bounded deployed-token witness

Literal invocation:

```sh
/bin/zsh -lc 'cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01 && export TMPDIR=/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/attribution.cIEIBO BUN_INSTALL_CACHE_DIR=$TMPDIR/bun-cache npm_config_cache=$TMPDIR/node-cache XDG_CACHE_HOME=$TMPDIR/cache && /opt/homebrew/bin/bun /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/attribution/witness.mjs'
```

Binary PASS observable: exit 0 and `ATTRIBUTION_COUNTEREXAMPLE_PASS`;
authenticated chain 4663/block 108944663/hash and both DETF transfer-facet
bindings; no token code/storage fabrication; ordinary mined transfers on an
owned Anvil fork; equal final balances, supply and allowances for both histories;
unequal prescribed credits (1666/2334 versus 1334/2666); distinct raw receipts;
source rollback, process exit and closed endpoint.

This is a PASS for the counterexample, **not E2 PASS**. Baseline credits are
synthetic admissible unequal-credit inputs, not asserted historical allocations.
The fork proves the real token admits the counterexample's transfer sequences.
Mathematical witnesses additionally cover zero-credit mixing, partial
consumption, residue, wrapper backing and NFT/descendant/independent overlap.
No Migration contract is implemented or tested.

Anvil is launched by the script with configured alias
`robinhood_mainnet_alchemy`, pinned block, chain 4663, loopback ephemeral port,
zero generated accounts, native throughput limit, EIP-170 retained, and isolated
HOME/cache. Its exact argument vector, PID, endpoint, receipts and sanitized
logs are retained. Readiness subscribes to its listening event; each transaction
uses explicit mining, not a timing delay.

Raw stdout/stderr: `witness.stdout.log`; structured raw RPC/receipt journal:
`witness.results.json`; node log: `witness.anvil.log`.
Producer result fingerprints, exact failure records, and source excerpts:
`producer-audit.json`. Invocation and binary observable are also recorded by
the executable before probes start. Failed attempts get separate filenames.

### P1 correction and second invocation

The initial arithmetic assertion failed before any RPC or Anvil launch:
reversing the same 50-unit roundtrip yields 1667/2333, not the erroneously
predicted 1334/2666. `witness.stdout.log` and `witness.results.json` preserve
that harness failure. It is not a product failure or an executed fork witness.

The corrected witness uses a 50-unit roundtrip for H1 and a reverse 25-unit
roundtrip for H2: equal end balances, 1666/2334 versus 1400/2600 credits.
This exposes a material ancestry difference, not only a rounding difference.

Literal second invocation, recorded before running:

```sh
/bin/zsh -lc 'cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01 && export TMPDIR=/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/attribution.cIEIBO BUN_INSTALL_CACHE_DIR=$TMPDIR/bun-cache npm_config_cache=$TMPDIR/node-cache XDG_CACHE_HOME=$TMPDIR/cache WITNESS_RUN=witness-r2 && /opt/homebrew/bin/bun /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/attribution/witness.mjs'
```

Binary PASS observable is P1 above with the corrected 1400/2600 H2 credit.
Output prefix: `witness-r2`; `witness-r2.producer-audit.json` records inputs,
exact producer checks and source excerpts. The original attempt remains intact.

### P1 cleanup-gate correction and third invocation

The second invocation executed all six real token transactions, authenticated
the source, passed the history comparison and 5902 arithmetic partitions, and
restored the source state. Anvil exited 0 and its PID was absent. The executable
nevertheless exited 2 because Bun fetch returned a generic connection TypeError,
not the `ECONNREFUSED` code assumed by the endpoint-closure assertion. Preserve
the entire `witness-r2.*` result; do not relabel its exit status.

The corrected closure check subscribes to a TCP socket's exact refusal event.
It does not treat every fetch exception as proof of a closed port. The third
invocation explicitly separates TMPDIR export from dependent cache exports and
records/asserts each cache path before execution:

```sh
/bin/zsh -lc 'cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01 && export TMPDIR=/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/attribution.cIEIBO && export BUN_INSTALL_CACHE_DIR=$TMPDIR/bun-cache npm_config_cache=$TMPDIR/node-cache XDG_CACHE_HOME=$TMPDIR/cache WITNESS_RUN=witness-r3 && /opt/homebrew/bin/bun /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/attribution/witness.mjs'
```

Binary PASS: corrected P1 observable, including explicit TCP refusal and
preserved input hashes. Raw output prefix: `witness-r3`.

## P2: cleanup and integrity

After P1, independently read the recorded child PID/endpoint, check that the PID
is absent and port closed, remove only the recorded owned run root, and confirm
ENOENT. Preserve `cleanup.json`. Binary PASS: every resource absent, every
producer/frozen-input fingerprint unchanged, and no files outside the named
attribution boundary authored by this lane.

Literal P2 invocation, recorded before running:

```sh
/bin/zsh -lc 'cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01 && export TMPDIR=/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/attribution.cIEIBO && export BUN_INSTALL_CACHE_DIR=$TMPDIR/bun-cache npm_config_cache=$TMPDIR/node-cache XDG_CACHE_HOME=$TMPDIR/cache && /opt/homebrew/bin/bun /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/attribution/verify-cleanup.mjs'
```

Binary PASS: exit 0 and `ATTRIBUTION_EVIDENCE_AND_CLEANUP_PASS`; final executed
script fingerprint matches, six successful local transfer receipts, 5902
arithmetic partitions, preserved producer verdict totals and input hashes,
both owned node PIDs absent, both endpoints refuse TCP connections, and owned
run root absent after removal. Stdout is retained as `cleanup.stdout.log`.
