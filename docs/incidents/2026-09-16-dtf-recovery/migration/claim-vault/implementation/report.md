# Direct claim-vault surrender: source-admission blocker

Date: 2026-11-12.

**Disposition: blocked before implementation and controlled-wallet acquisition.**
The required exact archived deposit/source semantics could not be authenticated.
This is a concrete source-evidence blocker, not a finding that deposits are
disabled or that direct-share support is impossible. No Migration, test or
operator delta was made. No claim-vault support or runtime acceptance is claimed.

Only this `implementation/` evidence directory was authored. Modifications
stop after this report and its evidence seal. No owned runtime, impersonation,
subscription, transaction or pending operation remains.

## 1. Admission and controlling inputs

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-16-claim-vault`.
Branch: `work/dtf-migration-phase-16-claim-vault`.
Exact unchanged HEAD: `4a53299b490343ed904d70c92ecbc7360fcb7659`.

The complete phase16 brief, current main plan r5 and PRD r22, owner-first-bond
directive, complete phase15 independent runtime and commit reports, phase11
claims sections 1, 4, 5 and 8-9, and complete phase11 independent report/matrix
were read. `input-bindings.json` binds all 11 governing and historical
source/receipt inputs by absolute path and raw SHA-256. In particular:

| Input | Raw SHA-256 |
| --- | --- |
| Plan r5 | `60d02b608c8a10f19cffce7b99838146c205a98410641e9bce45944e620dc56d` |
| PRD r22 | `cfe1853f49de0dc41ae106f1cc1b94eacd24d4aa8f79477c66a5b7f24a4d67ed` |
| Phase15 independent runtime report | `77e67678c3180b4ef487fb40567131e9aea0e6c03f7f0f0f1f66003d1226669e` |
| Phase15 independent commit report | `8e5f291d701451e1df225078905391feb47a6d37edee5ca31b1c521e5d412b9e` |

Initial ordinary Git status failed because the prescribed `lib/crane` path
is a symlink. Read-only status with `--ignore-submodules=all` succeeded and
was empty. Branch and HEAD match the brief. Warm `out/` and configured
`cache_forge/` directories and the prescribed Crane/node_modules links exist.
They were not replaced or reseeded. These are present-state observations,
not a reconstruction of root's earlier copy operation or an artifact audit.
No first compile was attempted.

Stage2-only surrender, the genuine paid owner-first Stage1 purchase and its
on-chain activation prerequisite govern over historical wording. The admitted
phase15 W-SD evidence concerns a different source and cannot authenticate the
native19 claim-vault facet or establish acquisition of its shares.

## 2. Actual pinned source observations

Read-only Cast requests used the existing `robinhood_mainnet_alchemy` alias
through the existing login shell. No public transaction was submitted.
`source-admission.json` retains complete raw outputs and actual facet runtime.

| Observation | Actual result |
| --- | --- |
| Chain | 4663 |
| Historical block | 108944663 |
| Block hash | `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733` |
| Claim vault | `0xAf5C0cD3fDEdd10bee00Eff77Fa0429Bacdb41f0` |
| Native share decimals | 19 |
| Actual `asset()` | `0xB55604CF4dcdABB362078e106D20F98512391EdF` |
| Native asset decimals | 9 |
| `facetAddress(0x6e553f65)` | `0x517234F78A4BcAfc5F880024A3E45D49cF43b305` |
| Actual facet runtime keccak256 | `0x8c1ea71d607b09b21c4e78f850647a059dc7935b6772f7cd3aeaa700a995439f` |
| `maxDeposit(controlled development address)` | `2^256-1` |
| Embedded IPFS metadata CID | `QmUvEgKFCaE3MSSVJpQyDk1TsD9RJBWBjstrAEcPfNDDeM` |

The facet identity agrees with the admitted historical redemption facet.
The routed deposit selector and maximum are actual observations; neither
proves the deposit call's exact payment, caller, minting, rounding or
postcondition semantics. No generic ERC4626 signature was treated as proof.
The current local `RebasingAwareERC4626Target.sol` was read only as an
explanatory implementation, not substituted for authenticated deployed source.

The eval and non-login shell initially lacked `ALCHEMY_KEY`. The root notepad
records that divergence and the existing login-shell path. That path was
checked, the key was present, and the pinned reads succeeded. The initial
credential-blocker hypothesis was retracted. **Credentials are not the final
blocker**, and no new credential is requested.

## 3. Concrete source-authentication blocker

`archive-attempts.json` retains exact unsuccessful response bodies, statuses
and raw response hashes, plus the successful proxy-archive identity and
complete source-path inventory used to exclude it as implementation evidence.

1. Sourcify v2 exact-facet lookup for chain4663 returned HTTP404, with
   `match`, `creationMatch` and `runtimeMatch` all null. It supplied no
   implementation source or metadata.
2. Retained phase01 source evidence authenticates selectors and runtime
   hashes, but the inspected claim-vault ranges do not supply archived
   deposit implementation text. Its mechanical fixture holder is TokenStaking.
3. Full-match and partial-match legacy repository paths returned HTTP404
   describing removal of API v1. Those responses are not interpreted as
   proof that no source exists.
4. The vault proxy's v2 archive returned HTTP200/exact-match, but its
   compilation target is `MinimalDiamondCallBackProxy`, and its source
   inventory excludes the vault implementation. Proxy verification is not
   delegated-facet verification.
5. The exact-facet all-chains lookup returned HTTP404 with an empty results
   array.
6. The metadata CID extracted from the actual pinned runtime was requested
   through `ipfs.io`. It returned HTTP429 and a gateway service-worker
   migration notice, not the metadata. No retry, alternate gateway,
   service-worker workaround or provider bypass was attempted.

Thus exact archived deposit/source semantics are unavailable from the
checked admitted evidence and retrieval paths in this run. Implementation
cannot pass the brief's source gate on those observations alone.
The missing input is authenticated metadata/source for the runtime above
with its complete deposit/redeem implementation, or an already retained
equivalently authenticated archive. No product decision is substituted.

## 4. Acquisition, custody and receipt boundary

**No new acquisition, custody or redemption receipt exists.** No underlying
payment, controlled-wallet deposit, token transfer, surrender, configuration,
bond issuance, recovery or donation was attempted. No controlled direct holder
was substantiated. Consequently no positive direct-share support claim is made.

Historical phase01 receipt references remain historical:

| Historical operation | Receipt |
| --- | --- |
| Infrastructure-share custody | `0xbfd713f0ff0a1fd4250cf720489d9d427f75cc98901696a4630dc17e492f9ed7` |
| Own-share redemption | `0xd03b842118e15cfc252766d7c8150d8e099818f3c326143a1d181d5e95748ed1` |

Their source is
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/verification/other-metered.json`,
cases beginning at lines 8970 and 9099. The custody owner is TokenStaking
`0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00`, explicitly marked
`fixtureMayBeInfrastructure`. These are not original-user authorization,
new controlled acquisition, or this phase's execution. Their observed
2769125838408621163-share conversion is not a universal quote.

Raw weights, infrastructure backing and direct shares remain distinct.
No weight/backing double award, synthetic contribution approval or implicit
authorization was introduced. Operational originals remain unapproved inputs.

## 5. Checks and deliberately unexecuted gates

The bounded checks actually performed were exact branch/HEAD/clean status,
warm-path/link presence, configured-provider pinned reads, facet-runtime
keccak256, archive-response inspection, raw input SHA-256 binding, empty
tracked/staged diffs, whitespace, and checkpoint/listener absence.
Final evidence JSON/hash/seal checks accompany this report.

No production/test/operator file changed. No compiling Forge command,
Migration spec/fork suite, operator tests, strict TypeScript, stage build or
pinned18566 CLI was run. Their required all-exit0 acceptance is **not met**,
not waived, and not borrowed from phase15. In particular, none of the three
mined interruption resumes was replayed in this phase.

There are no changed source/artifact/runtime or acquired-state snapshots
to bind. The evidence retains the complete actual pinned facet runtime and
raw read outputs, unsuccessful source response bodies and all governing
input identities. Empty acquisition/source-change/artifact sets explicitly
mean blocked-before-execution, not a completed implementation manifest.
The 1,208,585-byte successful proxy archive is hash-bound and summarized,
not retained or misrepresented as a complete claim-facet source snapshot.

Biome JSON LSP is not installed. No dependency or configuration installation
was made; evidence JSON was serialized and is checked by parsing instead.
Existing Forge nightly/unknown-fmt-key warnings remain visible.

## 6. Cleanup and final handoff

`cleanup.json` records the successful compound cleanup probe. There was no
listener on18566, the fixed
`.omo-runtime/dtf-migration-claim-vault/checkpoints` path was absent, tracked
and staged diffs were empty and whitespace validation passed. No owned
runtime, holder impersonation, receipt watcher or asynchronous run was started.

Only this new evidence directory is authored. Earlier evidence, all base
source routes, owner-first-bond behavior, warm artifacts/caches, dependency
links, ordinary/common/Crane production and configuration remain untouched.
No held09 inspection/import/replay, source role/storage/bytecode/balance
fabrication, public action, commit or merge occurred.

**Stopped at the brief's concrete source-blocker condition.** No implementation
completion, independent-verifier confirmation, full-category/full-plan or gas
acceptance follows. Source/test/operator modifications never began; evidence
modifications stop when the report and nonrecursive seal are finalized.
