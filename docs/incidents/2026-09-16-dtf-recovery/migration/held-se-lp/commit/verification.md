# Independent held SE/LP immutable local delivery audit

Date: 2026-11-12. **Disposition: confirmed for bounded immutable local
W-SW, E-P and W-P original-wallet native18 custody and frozen-credit
delivery only. E-S remains unsupported; all three conversions remain blocked.**

No blocking immutable-delivery discrepancy was found. The actual completed
receipt and manifest match the immutable commit, current source and
independently accepted runtime source bindings. The LP fixture remains
external-EOA-owner-release and personal-donation dependent. One nonblocking
receipt typo and the expected excluded-directory size change are stated
below; neither replaces a missing baseline or requires a source fix.

This is not full-plan, full-hermetic, liquidation, operational-allocation,
archive-portability, target-gas or public-operation acceptance.

## 1. Actual delivered identity

| Identity | Independently observed value |
| --- | --- |
| Worktree | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-21-held-se-lp` |
| Branch | `work/dtf-migration-phase-21-held-se-lp` |
| Actual commit | `4eaa7decab80d24cf37cb3781eff5ffaf9362942` |
| Required sole parent | `3ec0912bafebf9c0aa66770a72f04501e5c11865` |
| Tree | `97240957d250487230589e445797e2d6610ceccf` |
| Subject | `Add verified bounded held SE/LP custody and credit` |
| Complete immutable delta | 35 paths: 30 modifications, 5 additions; 1528 insertions, 34 deletions |
| Actual receipt SHA-256 | `67a78523199d3cedae8f4c06270016c9417c9c3a2a76d04ce6677571140d58e4` |
| Actual delivery manifest SHA-256 | `a4290758cd58127a815c0538195d389b459008e1ad306d57ccc1324259f0f082` |
| Root-admitted runtime report SHA-256 | `989a09b0ea2a3b73863df3c3fa7c4ba89b54b70f7d7af22e534998c4809e2df4` |
| Producer seal SHA-256 | `2e84389b5604aff83f600fc727b7d904884462c366264e1afc67f5ddb8fb7459` |
| Independent runtime seal SHA-256 | `feac04e48c4231284f47b386cafe787993b87447ebc34705ef5ca247c1bcbeec` |

The admitted report's complete 25230 raw bytes reproduce the supplied hash.
The complete commit/implementation briefs, actual producer and independent
runtime reports, four phase20 source/funding contracts and admissions,
original preservation recipe, binding algorithms and cleanup were read.
Complete ED source contract/producer/admission, cumulative ED
producer/runtime/receipt/immutable reports preserve the accepted parent
context. Large manifests, seals, audit collections and original inventories
were fully parsed and their complete binding arrays checked.

Raw commit content is 1198 bytes, SHA-256
`bd4083eb8ddfaaecaf7c69021c1f1b40135a7c809fa1b79860384ad96a73f0a6`.
Independent Git-object framing reproduces the actual commit ID. There is
exactly one parent header, equal to the required parent, and parent..HEAD
contains exactly one commit. The actual message contains exactly once:

```text
Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>
```

Independent `verify-commit HEAD` exits 0 with a good RSA signature from key
`55EB42889513051267BC55A395206404A78FB7F3`. GnuPG's unknown ownertrust remains
explicit; signature validity does not independently certify human identity.
This audit created no commit and changed no ref or index.

## 2. All 35 accepted paths and complete exclusions

The accepted set was independently derived from the fresh accepted runtime
audit's `results[1].bound.preserved`: this worktree's source, script and test
roles plus the exact operator-runbook path. Required 35 unique paths, then
cross-checked the complete set against the producer manifest, both runtime
audit bindings, original precommit source identity, actual delivery manifest
and full immutable raw delta. The delivery manifest did not supply the set.

For every path, immutable blob bytes, current raw file bytes and accepted
runtime bytes have identical SHA-256 and length. Producer, both independent
runtime binding sets, precommit identity and every declared delivery-manifest
SHA-256 agree. All current permissions are 0644; producer accepted mode 420
means decimal permission 0644, not a disagreement with full regular-file mode
33188 or Git mode 100644. Every committed/index entry is stage0 mode 100644.
All 30 modified parent modes remain 100644; the five additions have no
parent blob. Every Git blob ID was independently recomputed and matched.
Complete per-path identities and parent/current/index entries are retained
in `audit-evidence.json:sources`, not reduced to a count-only assertion.

The complete delta is exactly eight Migration production roots, four adjacent
Solidity tests, 22 existing-home operator/stage files and the existing
runbook. Exact accepted-set equality excludes every other path, including
ordinary/common/Crane production, dependencies, configuration, provider,
held09 candidates and all source/producer/verifier/commit evidence. The five
additions are:

- `scripts/recovery/dtf-migration/held-se-lp.test.ts`
- `scripts/recovery/dtf-migration/rehearsal-held-se-lp-source.ts`
- `scripts/recovery/dtf-migration/rehearsal-held-se-lp.ts`
- `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationHeldSeLp.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationHeldSeLpConfiguration.t.sol`

The immutable/current/accepted identity binds the already independently
reviewed and executed candidate. This is a delivery audit, not a new
behavioral code review or an implementation change.

The full immutable whitespace check, including all five additions, was:

```text
GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 git -C /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-21-held-se-lp diff --ignore-submodules=all --check 3ec0912bafebf9c0aa66770a72f04501e5c11865 HEAD
```

Exit 0, empty stdout/stderr. Original staged parent-to-candidate and staged
gate records were also inspected. An empty-index check was not substituted
for immutable whitespace, and accepted hashes did not waive it. Staged and
unstaged tracked comparisons exit 0 with empty output. Status contains only
the excluded untracked held-se-lp evidence tree. Every Git call uses
`GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0`; status/diff ignore submodules.

## 3. Every original preservation row reproduced

All required original baselines exist. Their original field encodings,
non-link-following lstat rules, path order and exact JSONL serialization
were reproduced independently. Each original row is retained with its line
number, baseline fields, actual fields and changed field names in the new
support. No empty-index, new baseline or aggregate-only claim replaces an
original row.

| Original baseline | Entries | Independent result |
| --- | ---: | --- |
| `precommit/docs-incidents.jsonl` | 1268 | No missing or changed original file/link rows |
| `precommit/docs-incidents-perms.jsonl` | 1339 | No missing or file/link/permission changes; one directory-size change |
| `precommit/out.jsonl` | 7353 | No missing, changed or new entries |
| `precommit/cache_forge.jsonl` | 607 | No missing, changed or new entries |
| `precommit/host-dependencies.jsonl` | 2621 | Every original kind/mode/permission/length/hash/target/role matches |
| `precommit/indexes.json` foreign entries | 22 | Every original raw index hash/length/mode/permission matches |

Independently reproduced original and retained-current subset hashes:

```text
docs-incidents 363d87323065b135d9b58c0fd4bfc3cf7f539bd781d0d3284162bfac4bf96a99
out            a8ee22bfe6a9dc2a8b3d7945fce853250695ab1a2845752016b9f9c8c5a0a3b4
cache_forge    c47eb850636d9345741cd480f3ead9a10505941e7cc7c2b94e1e31e5ff9c6388
host           1fec2ce75aeb420b3269ea9ded81b88312d0b2061fcfd5ea4f01b379691337f4
```

The original permission inventory hash is
`5fbb993da1344951dad811dda4db01dedd908ae6bcd4a70399be728519b9391e`.
Its only changed original row is line 17, the enclosing
`migration/held-se-lp` directory: size 128 to 160 from creation of excluded
`commit/`. Kind dir, permission 0755 and null hash are unchanged. Its
honestly different current-original-subset hash is
`ed19611a7ba0665079f87d0cea8e80b45ff63d91c8010b6fff82442f4cedae57`.
Normalized Git mode alone is not read-only-mode proof; the separate original
permission rows supply that proof.

Before audit writes there were 19 new file/link rows and 21 new permission
rows, all at excluded `commit/` or below: 16 precommit files, actual
receipt/manifest/preservation comparison and two directories. This audit
adds exactly three further excluded files and no directory. No prior
report, seal, binding, capture, witness, journal, failed attempt or log
was edited, relocated, deleted or chmodded.

All 2621 external host rows match: 11 authority, 1224 external immutable and
1386 parent-preserved phase18 producer entries. There are 2615 unique paths;
six dual-role paths were compared twice with their roles retained. Membership
was independently derived from the producer manifest, not inferred from an
aggregate. The 13 in-worktree immutable inputs are covered by the evidence
walk. The 78 earlier-liquid source-only files remain within the external
immutable set.

All original refs remain identical except the allowed owned branch movement
from required parent to actual commit. The exact original ref baseline
retains SHA-256
`eea60689ef187361a0e74c6679a0bf5148a636e8a88e3c970a32ea32dbf2eb5a`.
No other ref is missing, added or moved. All 14 non-self
`extra.json:aggregates` bindings reproduce.

The original index inventory has 23 entries: 22 foreign and one owned.
The owned index alone changed from
`c7826a05a19e32d5027007602a91cac4941d7409cfde62502cd9923efb9ad6f8`
to `3062b9c9b66505c209450f11a7da5b25fc61de9a0f094722993631b7cca19286`.
Its stage0 blobs/modes match HEAD, with no staged or unstaged tracked
source difference. Held09 access was limited to its prescribed foreign
index hash and ref identity, not source inspection or replay.

Both dependency links retain their original target strings, target hashes,
lengths, permissions and inodes: `lib/crane` inode 19607440 points to
`/Users/cyotee/Projects/indexedex/lib/crane`; `node_modules` inode 19607441
points to `/Users/cyotee/Projects/indexedex/node_modules`. No host dependency
was cleaned up or relocated. This is preservation, not portability proof.

### Nonblocking receipt qualification

The receipt's Preservation bullet says **"undefined foreign worktree
indexes"**. That is a rendered count typo, not an absent original baseline.
The complete original `indexes.json` independently supplies all 22 foreign
records, and every one matches raw current bytes, size and modes. The
receipt is preserved unchanged. This audit's exact count and per-entry
evidence control the conclusion; no aggregate or empty-index substitute
was used.

## 4. Binding to actual already-executed runtime proof

All 35 source, 1237 immutable, 11 authority, 1386 parent-preserved, 645
producer-member and 607 independent-verifier-member bindings match raw
length, SHA-256 and available permissions. Exact implementation membership
is 645 files plus its self-excluded seal; independent runtime verification
membership is 607 files plus its self-excluded seal. No missing/extra member
was found.

The final independent audit is 21061917 bytes, SHA-256
`b3db9108d65b774436452b706c6f151d52e95133b956ff267af12d9fa937e64d`.
Source equality and unchanged sealed logs bind this delivery to the actual
167 specifications, 139 pinned forks and 88 operator tests in one invocation,
both stage builds, strict operator/probe types and actual fixed 18571 CLI.
The exact ordered `checks.sh` recipe and real PASS-line totals corroborate
those results. **This immutable audit ran no build, suite, CLI, RPC,
transaction, producer runner or runtime-verification runner.**

Accepted execution covers all 12 alternative origins in both directions per
source, including all six ordered pairs among the new three; complete
owner-only loading/replacement, original-wallet control, finite/max allowance,
partial/terminal/zero-credit cases, actual late child-funding/receiver rollback,
reentry and mixed positive old/new inventories. These remain executed
spec/fork proofs, not newly claimed executions here.

Offline artifact checks independently rebind each retained run's 75 runtime
capture records, 57 current artifact comparisons and 301 compiler-source
hashes. Repeated captures are not 75 distinct contracts. Both stage metadata
source sets, 545 and 68 entries, also match current source hashes. Only
declared immutable/link spans and compiler library self-address substitution
are allowed; named library bindings and actual code Keccaks match.
Actual registry deployment calldata and package creation initcode agree
with the current creation artifact. All 22 immutable values were independently
derived from decoded constructor inputs and SELF, not arbitrary masked bytes.

Actual activation receipt
`0x8f8c5ef8c2b4e6c6f4917be4997e1bc3c99ea3938e49c4fdc92bb11b1858499a`
contains exactly the current Allocation ABI's **14** administration-selector
removals, independently decoded from `DiamondFunctionRemoved` logs.
The new loader disappears; retained queries and surrender remain bound to
the accepted execution.

### Original HTTP, signatures and genuine resumes

For each run, independently parsed original HTTP body strings retain
**1999 responses, 663 canonical transactions and 663 receipts across
671 blocks**. Request/response IDs, block membership and every nested log's
transaction/block identity match. All **491 nonsynthetic signatures**
independently reconstruct to their actual hash, signer and chain4663.
The other **172** are explicitly Anvil synthetic r=s=1 fixture transactions,
not cryptographic original-wallet signatures.

Each run's **155 originally retained raw signed records** independently
decode and match their original containing files and complete canonical
receipts. Four separately labeled **offline deterministic reconstructed**
signed records also match actual hashes/signers and complete receipts.
These 155+4 records are subsets, not extra transactions; reconstructed
signing bytes are not original captures.

The fresh raw HTTP file remains 8608048 bytes, SHA-256
`f2e69c864b25f41bc15d49a66d3ef8530543430b3480e56f4e1709d375414be8`.
Raw file hashes, JSON-object serialization hashes and original HTTP body
bytes remain different provenance classes.

All three genuine fresh mined-before-checkpoint resumes independently match
the retained original transaction and before/after receipt against every
canonical field, including nested logs:

| Interrupted operation | Actual mined hash adopted by fresh-process resume |
| --- | --- |
| Funding donation | `0xe3c3d25c6f654d2d43049103959540c01a923e257a59549871d0a02bf1558f22` |
| Independent issuance | `0x5635828beb4c23bee076f05f0a116a4bda678e760a2df1cb269112835da0b7b1` |
| Paid owner-first ordinary bond | `0xee8b7bb0308538c1a9846ea8c353b998f5e6d0769affd30aa6b4bde8ace99833` |

Original SIGKILL/code-null interruption and new-process adoption witnesses
remain sealed. The producer's separate three original resume witnesses were
also preserved and reconciled; they were not substituted for the fresh ones.

### Original inputs, ID-only drift and economics

All **30 lossless original producer prepared-input captures** reproduce
original raw lengths, SHA-256 and terminal-newline states. Independent
structural comparison confirms only top-level `$.id` differences in three
current raw artifacts: Allocation/Migration 758 to 534 and package 760 to
536. All **36 repeated producer drift references** remain tied to exact
original captures. The producer's sealed original zero-drift observation
is not rewritten. Fresh execution has **zero input drift**, with four
separately losslessly captured current raw ABI inputs. No artifact restoration,
normalized JSON or recreated ABI is presented as original evidence.
Earlier ED 48-entry historical drift and ER four-ABI reconstruction limits
remain historical qualifications.

Independent signed-calldata arithmetic separately for W-SW, E-P and W-P in
both retained runs confirms Q0=10013 native18 and C0=2774608 native9:
partial q3337 delivers 924684; remaining Q/C=6676/1849924; terminal q6676
delivers all 1849924, ending Q=C=0 and delivered=2774608. Exact finite/max
allowance decrements, seven-unit raw/booked floors, same-wallet principal,
real funding and fresh 7776000-second cliffs remain in the accepted raw
receipt/state proof. Original ETH0.006/DTF0 components are synthetic
code-proof inputs, not operational historical allocations.

The existing external EOA collector owner releases E-P/W-P to itself before
personal donation; W-SW uses a personal holding transfer. **All five donor
operations are impersonated disposable-fork fixtures.** They prove no
donor-key control, public consent, production owner privilege, claimant
collector authority or general operator acquisition method. Actual users
must control their configured eligible source. Donated holdings are not
historical entitlement inputs.

## 5. Retained limits and stopped cleanup

Actual runtime bytes remain principal24408, Allocation24100,
Recovery22704, ClaimVaultAllocation11221 and package16714. All satisfy
EIP-170; principal headroom is only168 bytes. Solar
`0.8.38+commit.e7a91fc7.solar.0.3.0-dev`, optimizer runs1 and no viaIR
remain bound. Actual registration gas is **45,116,678**, above
**32,000,000**; prior44,863,086 remains historical. Local gas ceilings
are rehearsal settings, not target deployment acceptance.

E-S remains unsupported. W-SW retains VaultDisabled; E-P retains
UnsupportedRoute/native NotOwner; W-P retains ordinary NotOwner and
owner-only liquidity. All three conversions remain blocked. No conversion,
inventory debit/donation stage, success decoder, arbitrary executor, source
enablement or legacy ownership/role change is inferred or added.

Operational original Q0/ETH/DTF datasets/components, canonical/opaque-origin
reconciliation, raw TokenStaking/native/WETH exposure, optional missing ED
facet, masked earlier mature-close authorization, archive match/runtimeMatch
rather than exact complete transitive recompilation, host/archive portability,
full-hermetic/full-plan acceptance and target gas remain open. Root's
31-wallet/93-zero purchaser reads are not a census; the E-S read-only
VaultDisabled mint is not a funded positive fixture. The source20
`stopRecorded=false` summary discrepancy remains untouched; actual stop RPC
and stopped node control. Positive inherited ER/WS nonrepresentable residue
is accounted state, not an owned pending operation.

The independent empty-array display-conversion audit failure and later
evidence-only ABI-byte-comparison fix remain preserved. No suite was
replayed for that fix or by this audit. Existing strict typechecks passed;
Forge warnings remain visible. Some LSP freshness checks and Bash/JSON
diagnostics were unavailable. The new JSON support also cannot obtain
Biome LSP diagnostics because Biome is not installed; it was directly
parsed and raw-hashed instead. No dependency/configuration change was made.

Independent `lsof` for 18571 and `ps` for producer/verifier PIDs41253/62726
each exit1 with empty output. Exact checkpoint/runtime parent, index lock
and merge/cherry-pick/rebase state are absent. No service, monitor, runtime,
provider, subscription or impersonation was started or adopted by this
audit. No foreign resource was cleaned up.

`audit-evidence.json` is 16742176 bytes, actual raw SHA-256
`97aa9eff03c62c7274b8f93b3c6f43adb69bafe8d1afce250ee6ededf1595559`.
It retains every original per-entry comparison, complete source/ref/index/
host/link results, seal checks, exact Git exits, offline wire/signature/
runtime/constructor/selector/drift/economic results and cleanup.
`audit-method.md` is 11155 bytes, raw SHA-256
`18a781f4558c2f18b9117634d3c162304c4e9f1814c40c3dc70a59881a7bddc0`,
and supplies explicit reproduction recipes. Those two support files and
this verification are the only owned writes, all excluded from the source
commit. This report claims no raw-final-file self-digest.

**Bounded immutable local delivery is confirmed. No owned operation is
pending. All stated source, recovery, data, gas and portability limits remain.**
