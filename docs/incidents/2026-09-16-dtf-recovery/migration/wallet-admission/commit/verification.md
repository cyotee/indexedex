# Independent bounded wallet-admission source-delivery verification

Date: 2026-11-11. Verdict: **confirmed**, for local source delivery only.

The actual local commit is exactly the accepted bounded H1/H2/H7 original-wallet NFT admission/operator source set, plus the two explicitly reviewed post-runtime documentation exceptions. No source fix or additional commit is needed for this delivery. Full categories/task 9 and target-gas feasibility remain open. This is a packaging/source-binding audit, not a fresh runtime audit or public-release approval.

## Authority and method

Read the complete phase12-wallet-admission-commit-brief.md and phase12-original-wallet-admission-brief.md, current main plan revision migration-detf-implementation-plan-r3-original-wallet-entitlement section 1.3, repository router and assistant coding/deployment/testing rules, and the complete implementation/report.md and verification/report.md. All inspected delivery state and the only output are in /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-12-wallet-admission. Explicit authority inputs outside that worktree were read only. No held phase09 candidate was read, imported, changed or tested; only its protected ref identity was compared.

All Git commands ran with GIT_MASTER=1. Actual repository data came from rev-parse HEAD, show -s --format=%H%n%P%n%B HEAD, diff-tree --no-commit-id --raw -r --no-abbrev HEAD, ls-tree -r -z for parent and HEAD, ls-files --stage -z, for-each-ref --format=%(refname) %(objectname), ls-files --others --exclude-standard -z, and show HEAD:<each changed path>. File reads, SHA-256 computations and lstat checks independently compared the actual filesystem, index, committed blobs and historical verifier fingerprints. Producer booleans were not treated as proof.

The first ordinary git status --short exited 128 because lib/crane is the prescribed symlink (error: expected submodule path 'lib/crane' not to be a symbolic link). The corrected git status --short --ignore-submodules=all exited 0. This did not change the link or configuration.

## Actual commit identity

- HEAD: 2c2b3370ded30cae1662329025d4fb58f7197330
- Only parent: 3f577eeca049c1bd70a812d130941c8a38dd4781
- Branch: work/dtf-migration-phase-12-wallet-admission
- rev-list --count 3f577eeca049c1bd70a812d130941c8a38dd4781..HEAD: 1
- Subject: Add verified bounded original-wallet Migration admission
- Exactly one required trailer, with exact value: Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>
- Exactly 24 paths: 22 modified, two added; no deleted paths. All are regular files, mode 100644. Existing paths retain parent modes. The new files are rehearsal-admission.ts and MigrationOriginalWallet.t.sol, both nonexecutable regular files. Historical runtime fingerprints attest bytes, not modes; modes were independently checked against parent/tree/index and filesystem executable bits.
- No evidence, logs, reports, caches, dependency links, configuration, generated artifacts or held phase09 paths are committed.

## Independent accepted-set derivation and exact source binding

The accepted identities were independently taken from verification/source-artifact-parity.json handoff.sources, not from commit/source-manifest.json candidates. For each of all 101 historical source records, read current bytes and, only for the two documented exceptions below, reverse the exact reviewed wording corrections. All 101 reconstructed SHA-256 values equal the historical verifier's expected values. Computing Git blob identities from those accepted bytes and comparing them to the parent tree independently yields exactly 23 changed/new accepted paths. Adding the sole cli.ts help correction yields exactly the actual 24-path commit set, with no extra or omitted path. Only runbook and CLI current hashes differ from historical runtime hashes.

For each actual changed path, read its current body and git show HEAD:<path>, compare both SHA-256 values, check its full ls-tree blob/mode, current regular-file executable bits, and manifest entries. All 24 committed/current byte identities and modes agree; all 22 nonexception source hashes are byte-identical to runtime-audited sources. All 24 also match the producer manifest, checked only after independent derivation.

The table records actual committed/current identities. Accepted SHA-256 is the historical independent runtime identity; it is deliberately different for the two exceptions.

| Path | Mode | Actual Git blob | Committed/current SHA-256 | Accepted runtime SHA-256 |
| --- | --- | --- | --- | --- |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol` | 100644 | 6027f70f0ed50cbd2c571d792964bfb44dce9ede | fd0b55698db6f5ee8d0f6b1a8bf8b090ae871f693bfc34ed43b20922493a43d7 | fd0b55698db6f5ee8d0f6b1a8bf8b090ae871f693bfc34ed43b20922493a43d7 |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationTarget.sol` | 100644 | f44eb8841dbc37ae6b79fce3236a8f05d14cf1b1 | 5403895223e5d742bf39ceb0b0f9e6c000956fc5c55f833b080714b7b1e1ce73 | 5403895223e5d742bf39ceb0b0f9e6c000956fc5c55f833b080714b7b1e1ce73 |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol` | 100644 | a01924fb56a71a3129226d99167b625dee22873d | 27d646c4ac9297b0ec236dafd165c1687e13f7d61fbe02f8f258e924a811164c | 27d646c4ac9297b0ec236dafd165c1687e13f7d61fbe02f8f258e924a811164c |
| `docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md` | 100644 | 6320ce5f118a9eb8dcd256796609cfb11c315359 | 8a528053067d253f438c63ee201d3caa56638854a6fa255703cb525e3c0c4e81 | f9f910e0a7258caba782f8d36e9315bdbf158f3e16d33692b16f493cb8bc2a88 |
| `scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol` | 100644 | 8d129b37ad62ce81cd016f1e2161fb25669a46c0 | a524bf9943ff72ee225ade84e96c2b624c14f2316ff018886408463f3f6c0443 | a524bf9943ff72ee225ade84e96c2b624c14f2316ff018886408463f3f6c0443 |
| `scripts/recovery/dtf-migration/cli.ts` | 100644 | ab2e06a9887fbf1a82c47c779485cb9c29d27030 | f7ef8752b523fbcb4420b0cc0a95720e3a0037e7eee2993a8b54c4d295678bab | 09670f4bd3f18d0d89b040fcd985dde97a9c22d19ac0c050de93c1822571a90a |
| `scripts/recovery/dtf-migration/execution-state.ts` | 100644 | 3931831632409e557b238a782f4ee36448afd056 | 28f647053d97412ad94006b0d872d78dc47768fa43cc27ffc46416098285ee27 | 28f647053d97412ad94006b0d872d78dc47768fa43cc27ffc46416098285ee27 |
| `scripts/recovery/dtf-migration/payloads.ts` | 100644 | 01d5ae93ff75c7cc2b2ca417e7578edc03401cc9 | e00b53f30fb9433d637306d713313a0d2f79256cecfc9f343d4a8c3eb659c44e | e00b53f30fb9433d637306d713313a0d2f79256cecfc9f343d4a8c3eb659c44e |
| `scripts/recovery/dtf-migration/preparation.fixture.ts` | 100644 | b0934117773831a851885d2a3055b779350845c7 | 9bcc67b497f5a4c97ebfbf568148c5b3cab28b2fe1597e8e239bed21cc9f4731 | 9bcc67b497f5a4c97ebfbf568148c5b3cab28b2fe1597e8e239bed21cc9f4731 |
| `scripts/recovery/dtf-migration/preparation.test.ts` | 100644 | 3a8d1a045f5e658b103a296049e28c22d9e139b2 | 6a9fd84383ae2a33ccee8b15c87f398aa4b96f52ae9587012551e136546e1d9b | 6a9fd84383ae2a33ccee8b15c87f398aa4b96f52ae9587012551e136546e1d9b |
| `scripts/recovery/dtf-migration/rehearsal-admission.ts` | 100644 | 921f41fc353541bbc6bfc6c8fa0e51a989825d52 | c79417c4b288a42ab0683ec7e3e1f8acfed4346f05dce5c873727202ee15dc3e | c79417c4b288a42ab0683ec7e3e1f8acfed4346f05dce5c873727202ee15dc3e |
| `scripts/recovery/dtf-migration/rehearsal-chain.ts` | 100644 | d84882e78877a2f944be859b42890912c16480a6 | 36974f60166a645bd54bfe7ce991f58a48656ca3d5d4fe8aec98189d7add8f94 | 36974f60166a645bd54bfe7ce991f58a48656ca3d5d4fe8aec98189d7add8f94 |
| `scripts/recovery/dtf-migration/rehearsal-data.ts` | 100644 | 29ef159f53cb986cdfa4096e500dab6d142617a0 | 89779cf145f35f789b8515b62c2442772ea0560021485ebcbdb479df580d2c21 | 89779cf145f35f789b8515b62c2442772ea0560021485ebcbdb479df580d2c21 |
| `scripts/recovery/dtf-migration/rehearsal-recovery.ts` | 100644 | 1328c9a476fb7d79f12b81a5aa128742f17c85ee | bb5d1249f1941e93a78067443d94ca70d420ccf0a8c6ed59d1cd50671212f633 | bb5d1249f1941e93a78067443d94ca70d420ccf0a8c6ed59d1cd50671212f633 |
| `scripts/recovery/dtf-migration/rehearse.ts` | 100644 | a93156670e463f9345193a2b3459d01a60a97668 | 15698210f6a257d359105afed65113f184ab5d5962a4574b5953dec21533ee26 | 15698210f6a257d359105afed65113f184ab5d5962a4574b5953dec21533ee26 |
| `scripts/recovery/dtf-migration/schema.ts` | 100644 | 5bdf67f72ec735bd85a3e33890193d89c66dce6b | cff51105a677d1d0a7115181878db71bdda239f1b89e2d2628e151a553d9421e | cff51105a677d1d0a7115181878db71bdda239f1b89e2d2628e151a553d9421e |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationLegacySources.t.sol` | 100644 | e7df3467c8128c038ab658169dcf56df4def1d56 | 1c26db3b5bf473c089e81d6d84594d38a7fb67708d9daabec7dd904c937ec713 | 1c26db3b5bf473c089e81d6d84594d38a7fb67708d9daabec7dd904c937ec713 |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationNftForkBase.sol` | 100644 | 686770817329261472c42309e5b3be89765a5818 | 65be9375389cad686649192a2afe3ab7de70596fa204d403451bd01136d775fa | 65be9375389cad686649192a2afe3ab7de70596fa204d403451bd01136d775fa |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationNftLifecycle.t.sol` | 100644 | 8fd59d5054192e2cd637340cf66ef4075d336902 | ad64a823b44faf61fe50a2540a0be81cafe75cb8467c078e760d8782f8c53057 | ad64a823b44faf61fe50a2540a0be81cafe75cb8467c078e760d8782f8c53057 |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationOriginalWallet.t.sol` | 100644 | 5d4c1ec72e79fa1e9b2261887490bca604e92c6d | 01ff726305372a09414c5180ba14f40d9489b629b0d78a77b59a9d43929c6a38 | 01ff726305372a09414c5180ba14f40d9489b629b0d78a77b59a9d43929c6a38 |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryGas.t.sol` | 100644 | 37c1b86b2531067b7ffbcb1632e65e4cbaa06bd0 | bf4c05a2b5dbb7a1360bb746c6b5b2db378f98e89f050ca4a7f1e14f81fe5381 | bf4c05a2b5dbb7a1360bb746c6b5b2db378f98e89f050ca4a7f1e14f81fe5381 |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryWeighted.t.sol` | 100644 | 767caf3e0db00498cb7cb5c3ece3a5c53f652293 | 41f77e12a9b986a51e828d20865a1f70724c385f4bc749e9acbe5e5cfbce4551 | 41f77e12a9b986a51e828d20865a1f70724c385f4bc749e9acbe5e5cfbce4551 |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationGenesisCapital.t.sol` | 100644 | 814796e76bdf8372254ff0828d887ae95a09821c | b6290e2d78cac3a21c349262ac32bd977d7132d7657ac546e8d9f0edb85cb743 | b6290e2d78cac3a21c349262ac32bd977d7132d7657ac546e8d9f0edb85cb743 |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationNftConfiguration.t.sol` | 100644 | c929c404274b34b62fa9770b6b80caa7e760b442 | d2db6fa07ab5afddac5b47d750d3c274879ad7805ab6a7e3c93a35c6fc9403f1 | d2db6fa07ab5afddac5b47d750d3c274879ad7805ab6a7e3c93a35c6fc9403f1 |

## Exactly reviewed post-runtime exceptions

### CLI help

scripts/recovery/dtf-migration/cli.ts:30 changes only the literal port 18560 to 18562 inside the exported help template. The complete parent-to-HEAD CLI diff was inspected. Reversing that one unique literal reproduces historical accepted SHA-256 09670f4bd3f18d0d89b040fcd985dde97a9c22d19ac0c050de93c1822571a90a. Every other byte, including imports, argument parser, dispatch, signer-mode checks and execution calls, is unchanged. No executable logic change is hidden in this correction.

The actual required runtime guard in scripts/recovery/dtf-migration/rehearse.ts:36 rejects any options.port other than 18562. That file remains byte-identical to accepted runtime SHA-256 15698210f6a257d359105afed65113f184ab5d5962a4574b5953dec21533ee26. The corrected help and runbook invocation therefore agree with the exercised runtime contract.

Independently executed in the assigned worktree:

```sh
bun --version
bun scripts/recovery/dtf-migration/cli.ts --help
```

The combined command exited 0; Bun reported 1.4.2. The actual help output was:

```text
Bounded Migration operator
  bun scripts/recovery/dtf-migration/cli.ts prepare --input <file> --output <directory>
  bun scripts/recovery/dtf-migration/cli.ts validate --manifest <file>
  bun scripts/recovery/dtf-migration/cli.ts <stage> --manifest <file> --checkpoint <directory>
  bun scripts/recovery/dtf-migration/cli.ts resume --manifest <file> --checkpoint <directory>

prepare reads caller-pinned evidence and the actual immutable snapshot.
validate rereads evidence, code identities, snapshot and independent ETH/DTF quotes.
RPC comes only from the manifest's rpcEnv environment variable. No signer is loaded.
All integers are decimal strings. Inputs are full replacements, not deltas.
Unsupported categories fail closed. Synthetic datasets are loopback-only.
Stages: deploy, fund, capture, configure, independent-issue, verify, activate, harvest.
Every stage and resume defaults to read-only validation; no signer is loaded.
Local execution: --execute-local --instance-id <exact observed Anvil instance ID>.
Public execution: --broadcast --confirm-chain <id> --confirm-proxy <address>
  --confirm-snapshot <id> --signer-key-env <selected environment variable name>.
--reverse reorders only independent unsettled configuration/issuance rows.
--fault-after-mined is restricted to synthetic-local interruption rehearsal.
  bun scripts/recovery/dtf-migration/cli.ts rehearse --rpc-alias robinhood_mainnet_alchemy
    --fork-block 108944663 --port 18562 --checkpoint <directory> --evidence <directory>
```

No rehearsal command was executed by this audit. The --help branch returns before command dispatch, so no node, signing or transaction is required. Current CLI SHA-256 f7ef8752b523fbcb4420b0cc0a95720e3a0037e7eee2993a8b54c4d295678bab is a post-runtime help-only source identity, not a falsely matching historical runtime identity.

### Runbook wording

The four exact reverse replacements below uniquely reconstruct the accepted runbook SHA-256 f9f910e0a7258caba782f8d36e9315bdbf158f3e16d33692b16f493cb8bc2a88 from current 8a528053067d253f438c63ee201d3caa56638854a6fa255703cb525e3c0c4e81. They change evidence locators and baseline/current gas wording only. The rest of the already runtime-reviewed runbook is identical, including synthetic/public-use restrictions, pinned invocation and blocked categories. The complete implementation and independent runtime reports substantiate these corrections: both distinguish current 42,985,865 from baseline 42,985,843; verification/report.md sections 6-8 identify the original documentation findings, current independent receipts and cleanup. The current deployment transaction is 0x9eceab6b54600e3668de39793899dffeef405e20d28fe7a7fcb1bca930d51540. Referenced current report, execution-index.json, source-artifact-parity.json, cleanup.json and independent rehearsal evidence exist in the preserved evidence inventory. Historical operator pointers remain explicitly historical, not rewritten evidence.

These exact replacements are source reconstruction evidence, not tests pinned to prose:

```json
[
  {
    "path": "scripts/recovery/dtf-migration/cli.ts",
    "reverseReplacements": [
      {
        "current": "--fork-block 108944663 --port 18562 --checkpoint",
        "accepted": "--fork-block 108944663 --port 18560 --checkpoint"
      }
    ]
  },
  {
    "path": "docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md",
    "reverseReplacements": [
      {
        "current": "recovery and owned runtime cleanup. Current original-wallet implementation\nand independent verification evidence are in\n`wallet-admission/implementation/report.md` and\n`wallet-admission/verification/report.md`. Historical baseline evidence\nremains in `operator/execution/report.md` and `operator/rehearsal/report.md`;",
        "accepted": "recovery and owned runtime cleanup. Implementation evidence remains in\n`operator/execution/report.md`. The subsequent fixed-command rehearsal,\ncorrections, gas, source bindings and cleanup are in `operator/rehearsal/report.md`;"
      },
      {
        "current": "The independently verified original-wallet local parent deployment consumed\n**42,985,865 gas** (the prior operator baseline used **42,985,843**), exceeding",
        "accepted": "The final local parent deployment consumed **42,985,843 gas**, exceeding"
      },
      {
        "current": "Use `wallet-admission/verification/report.md` and its referenced\n`execution-index.json`, `source-artifact-parity.json`, `cleanup.json` and\nindependent rehearsal evidence to join commands, nonces, actual bond IDs,",
        "accepted": "Use `operator/rehearsal/transactions.json`, `gas.json` and\n`source-evidence-bindings.json` to join commands, nonces, actual bond IDs,"
      },
      {
        "current": "The earlier `operator/rehearsal/` records remain historical baseline evidence.\n",
        "accepted": ""
      }
    ]
  }
]
```

The current runbook hash is explicitly a post-runtime wording exception. Neither corrected document hash is represented as having run the historical transaction suites.

## Provenance checked against actual bytes

All ten source-manifest provenance paths were independently rehashed with no mismatch. Key anchors:

| Evidence | Actual SHA-256 |
| --- | --- |
| `docs/incidents/2026-09-16-dtf-recovery/migration/wallet-admission/implementation/report.md` | 558ac9358eb4c8c7f8356326f599a87fbbdb58a441a489b3310452825903cea2 |
| `docs/incidents/2026-09-16-dtf-recovery/migration/wallet-admission/implementation/source-artifact-bindings.json` | e911566cbcc865410aa8f64af8759cc4a6b2b55bc7147774f97d515969316a1a |
| `docs/incidents/2026-09-16-dtf-recovery/migration/wallet-admission/verification/report.md` | 00d477fb0643d4c412ae62ab45b9f62290ffb711d3c2cf5b92c87743ed1126d2 |
| `docs/incidents/2026-09-16-dtf-recovery/migration/wallet-admission/verification/source-artifact-parity.json` | 9c724c6ac1607b148999af2bafeb87e9ae2c672d601ce8df9fa3bd60800243ba |
| `docs/incidents/2026-09-16-dtf-recovery/migration/wallet-admission/verification/cleanup.json` | 68fe66b1d6f22646ec4f9ec1b07b1c726cfe28c0166d6c0f5897b40d51e483a5 |
| `docs/incidents/2026-09-16-dtf-recovery/migration/wallet-admission/verification/spec-independent.log` | 5c9d0bbab40301d409231ae66d173acad6c7421d5ab987ab22b670a5fabdcde4 |
| `docs/incidents/2026-09-16-dtf-recovery/migration/wallet-admission/verification/fork-independent.log` | 673daac80eb351f84f33f2b66bb6dedf26270fa641dac5610797d2c9eb625458 |
| `docs/incidents/2026-09-16-dtf-recovery/migration/wallet-admission/verification/operator-independent.log` | 9d5cd75a0bd19b810567d87780492b75160e5259d50c81daa6ece441e3bf7306 |
| `docs/incidents/2026-09-16-dtf-recovery/migration/wallet-admission/verification/types-independent.log` | e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 |
| `docs/incidents/2026-09-16-dtf-recovery/migration/wallet-admission/verification/cli-independent.log` | 828bdd28deaaba808fd73bedf0a074a4e86154ceaa9d79705fecc02dcff3d624 |
| commit/source-manifest.json | aacbb8737c755ada9a223faec67de55e046ff3052d92914ebaf253d2c83f2fe7 |
| commit/preservation-baseline.json | 0d612d332f6ceb95203e6265ba369ec4575bfe65776a70591e939530a137a46c |

All five final independent artifact files match parity.finalArtifacts, not the obsolete pre-refresh full-file hashes in parity.handoff.artifacts. This preserves the runtime verifier's explicit distinction: compiler metadata bookkeeping changed three artifact files while ABI/creation/runtime objects remained equivalent in its independent parity proof. This audit rehashes the final artifact files; it does not claim to have rerun that runtime/link proof.

| Current final artifact | Actual SHA-256 |
| --- | --- |
| `out/UniswapV4DetfMigrationFacet.sol/UniswapV4DetfMigrationFacet.json` | 1f8cc9a44501d37f82dd7868db1ba795df335b79d0a42f7deeb8c58934d4e1de |
| `out/UniswapV4DetfMigrationAllocationFacet.sol/UniswapV4DetfMigrationAllocationFacet.json` | 3f3f6f59aa94cf37e4f9d3184eae863c1bc23a28012a350c849ea4c548644e16 |
| `out/UniswapV4DetfMigrationDFPkg.sol/UniswapV4DetfMigrationDFPkg.json` | c33c0ac86ce2dbef7ea373fd4effffc7e1597dbbd736a4150bdfacb4928359df |
| `out/Phase_08_Stage_00_OperatorEnvironment.s.sol/Phase_08_Stage_00_OperatorEnvironment.json` | 9009c536012df3da729c4f00e138fe23b35aa447b50641f7c627ac9171bb54c0 |
| `out/Phase_08_Stage_01_MigrationExecution.s.sol/Phase_08_Stage_01_MigrationExecution.json` | 58ecb69628fb93f0e5d1e33ea46b7c4d7f35cecad3e0963551fe964a679d21c8 |

The historical independent verifier reported 97 specs, 47 pinned forks, 54 operator tests, strict TypeScript, real local admission/resume checks and cleanup. Those runs remain attributed to verification/report.md and its preserved evidence. This audit did not rerun unchanged transaction suites, add prose-pinning tests or copy producer pass flags as fresh execution proof.

## Preservation evidence

- Actual parent index reconstruction (13006 entries, mode/blob/stage/path NUL records) SHA-256 equals the producer's incoming index fingerprint: e56d1d448118e54aabc5a19462b741143c60a4372efc4a649ee96f96fd28df32. Thus the recorded incoming index is exactly the parent tree, with no foreign staged changes. All 12984 noncandidate index entries still equal parent entries. Current index has 13008 entries and SHA-256 318556c4eae674a19d0bcb4cfe76fb78ac454ef95291b5f404404bc0371ca849. It remained identical across this audit.
- Actual staged and unstaged tracked path sets are empty. diff --check parent HEAD, diff --check, and diff --cached --check all exited 0. Only local wallet-admission evidence is untracked.
- Reconstructing the original untracked set by removing the seven subsequently added commit-evidence files from the current untracked paths and restoring the two now-committed new source paths yields exactly 504 paths. SHA-256 of the sorted compact JSON path array is 521f0b1dca72a85d45f1cd63a54980cf733d2c0674a24174df97b17d722aa32b, exactly the incoming baseline. No prior noncandidate untracked path was lost.
- All 614 prior migration evidence entries were independently checked twice against preservation-baseline.json historicalInventory: identical relative path, mode, byte size, mtimeMs and SHA-256, zero differences. Ordered compact inventory SHA-256 is b52cd5d152b45f97cee8669008f8075a4ff62ecf50232712ff6becce1f2313fb. This includes the current runbook and all historical reports, witnesses, logs, journals and receipts; prior evidence was not corrected or rewritten.
- Cache inventories independently reproduce the producer baseline using recursive per-directory locale ordering and compact JSON records with path/mode/bytes/mtimeMs. out: 7302 entries, SHA-256 1913dde08d946fa28fb1de5c8f5e23426ed3f4bb506d931c8c9540c782062a8c. cache_forge: 512 entries, SHA-256 fcb71ccfdf460f3f2eef3ce1e5c8c42237db2d711af8a75de5c7dce2b2f96ebf. Initial lexical-order calculations differed only because ordering differed; the correct recursive locale ordering reproduces both exact historical fingerprints. Cache metadata, not all cache bytes, was exhaustively checked. No build, cache deletion or artifact generation occurred.
- lib/crane remains mode 41453, inode 18413130, target /Users/cyotee/Projects/indexedex/lib/crane. node_modules remains mode 41453, inode 18413131, target /Users/cyotee/Projects/indexedex/node_modules. Both exactly match the baseline.
- All 50 refs other than the authorized source branch match the incoming baseline, including main and origin/main at 90ff0307a7a8e084aa073e02eff125e9c7973933, held phase09 at 421072a7630a0d3d47a6f36e1062d9eae98c93e2 and stash at 7321b70c984423699475cfb45907b6dd70bb8ef4. SHA-256 of the exact ordered compact JSON protected-ref array is b34c0248c02ba418810a2987348042845a1c43a841c240ee90d5b0d190fdd149. The full exact array remains in the preserved baseline; no fetch, ref mutation, push or merge occurred.
- The seven existing commit-evidence files were fingerprinted separately before this report and preserved. This audit creates only this verification.md, with all supporting observations inline; it does not modify source-manifest.json, receipt.md or any prior evidence.

## Cleanup and retained exclusions

Independent lsof -nP -iTCP:18562 -sTCP:LISTEN returned exit 1 with empty stdout/stderr (no listener). ps -p 71170,75636 -o pid= returned exit 1 with empty stdout/stderr (prior producer/verifier nodes absent). lstat confirms .omo-runtime/dtf-migration-wallet-admission is absent. The help process completed, and all three background command handles from this audit have terminal exit results. No owned runtime, node, impersonation, test/build, child or monitor is pending.

Only bounded H1/H2/H7 original-wallet NFT admission and operator propagation are confirmed. General fungible/claim surrender, original native-unit/gon/share mappings, earlier fractional receipt attribution, raw TokenStaking atomic composition, direct-user claim-vault/SE authority, disabled earlier/weighted WETH SE exits, restricted/unsupported LP exits, unproved earlier liquid conversion, and complete native/WETH exposure remain excluded. Full categories/task 9, operational award approval and complete-source/public-release acceptance remain open. Both current 42,985,865 and baseline 42,985,843 parent-deployment gas exceed the historical 32,000,000 target transaction limit; permissive local rehearsal is not target-gas acceptance. The held phase09 candidate remains untouched.

**Final verdict: confirmed for exact bounded local source delivery only, with the two explicitly qualified post-runtime documentation exceptions and no owned runtime.**

